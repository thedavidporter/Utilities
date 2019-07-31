/*
Creation: 10 June 2019
Author:   David Porter
Purpose:
When your sql databases do not shutdown properly you will potentially see them in the "Recoery Pending" mode.
Under databases in SSMS you may see something like <database name>(Recovery Pending).
Execute this script then take the output and execute the output to restore DB's to normal.
*/
select concat('alter database ', name, ' set emergency; ', 'alter database ', name, ' set single_user; ' , 'dbcc checkdb (', name, ', repair_allow_data_loss) with all_errormsgs; ', 'alter database ', name, ' set multi_user;') 
from sys.databases
where state_desc = 'RECOVERY_PENDING';
