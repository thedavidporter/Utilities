# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
#[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[00;36m\][\D{%Y-%m-%d %H:%M:%S}]\[\033[00m\] \[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}[\D{%Y-%m-%d %H:%M:%S}] \u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    #alias grep='grep --color=auto'
    #alias fgrep='fgrep --color=auto'
    #alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
#alias ll='ls -l'
#alias la='ls -A'
#alias l='ls -CF'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi
export PATH="$PATH:/opt/mssql-tools18/bin"
export BROWSER="/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"

# ---------------------------------------------------------------------------
# Claude Code — Databricks proxy (claude-work) / personal account (claude-api-personal)
# Proxy script: ~/anthropic_databricks_proxy.py  (port 8082)
# Token file:   ~/.databricks_app_token
# ---------------------------------------------------------------------------

claude-work() {
    if [ ! -f "$HOME/.databricks_app_token" ]; then
        echo "ERROR: ~/.databricks_app_token not found"
        return 1
    fi
    pkill -f "anthropic_databricks_proxy.py" 2>/dev/null && sleep 0.3

    python3 ~/anthropic_databricks_proxy.py > /tmp/claude_proxy.log 2>&1 &
    local pid=$!

    local i=0
    until (exec 3<>/dev/tcp/localhost/8082) 2>/dev/null; do
        sleep 0.3; i=$((i+1))
        if [ $i -gt 20 ]; then
            echo "ERROR: Proxy failed to start. Check /tmp/claude_proxy.log"
            return 1
        fi
    done
    if ! kill -0 "$pid" 2>/dev/null; then
        echo "ERROR: Proxy exited immediately. Check /tmp/claude_proxy.log"
        return 1
    fi

    export ANTHROPIC_BASE_URL="http://localhost:8082"
    export ANTHROPIC_API_KEY="databricks-proxy"
    local model
    model=$(grep -oP '(?<=DATABRICKS_MODEL = ")[^"]+' "$HOME/anthropic_databricks_proxy.py")
    echo "Proxy started (pid $pid) → ${model:-unknown model}"
    echo "Run: claude"
}

claude-api-personal() {
    pkill -f "anthropic_databricks_proxy.py" 2>/dev/null && echo "Proxy stopped." || true
    unset ANTHROPIC_BASE_URL
    export ANTHROPIC_API_KEY=$(cat "$HOME/.anthropic_key" 2>/dev/null)
    if [ -z "$ANTHROPIC_API_KEY" ]; then
        echo "WARN: ~/.anthropic_key not found — Claude Code will use stored credentials"
    else
        echo "Switched to personal Anthropic account."
    fi
}

claude-status() {
    echo "--- Claude Code status ---"
    if [ -n "$ANTHROPIC_BASE_URL" ]; then
        echo "Mode  : Databricks proxy"
        echo "URL   : $ANTHROPIC_BASE_URL"
        if pgrep -f "anthropic_databricks_proxy.py" > /dev/null 2>&1; then
            echo "Proxy : RUNNING (pid $(pgrep -f anthropic_databricks_proxy.py))"
        else
            echo "Proxy : NOT RUNNING — run claude-work to restart"
        fi
    else
        echo "Mode  : Personal Anthropic account"
        echo "Key   : ${ANTHROPIC_API_KEY:0:12}..."
    fi
}

alias net='~/network-select.sh'
alias chrome='nohup chromium --no-sandbox &>/dev/null &'
alias marketplace-update='bash ~/marketplace_update.sh'

echo ""
echo "  claude-work          start Databricks proxy → run claude (work billing)"
echo "  claude-api-personal  stop proxy → switch to personal Anthropic account"
echo "  claude-status        show which account/proxy is active"
echo "  marketplace-update   executes old school marketplace update batch program"
echo "  net                  switch network (work / home WireGuard)"
echo "  chrome               chromium"
echo ""

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
