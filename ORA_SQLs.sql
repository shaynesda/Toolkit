-- Check Restore Point
select * from v$restore_point

--Check Shared Pool Free Space
SELECT POOL,NAME, ROUND(BYTES/(1024*1024),2) FREE_MB FROM V$SGASTAT WHERE POOL='shared pool'AND NAME='free memory'ORDER BY BYTES DESC

-- DB Scheduler Jobs
select * from dba_scheduler_jobs

-- DBLing Open Cursors
select db_link,logged_on,open_cursors,in_transaction from v$dblink

-- Reset Password
alter user SROSENSTEIN identified by nietsnesors

-- RMAN ACTIVE STATE
SELECT SID, SERIAL#, CONTEXT, SOFAR, TOTALWORK, 
ROUND (SOFAR/TOTALWORK*100, 2) "% COMPLETE"
FROM V$SESSION_LONGOPS
WHERE OPNAME LIKE 'RMAN%' AND OPNAME NOT LIKE '%aggregate%'
AND TOTALWORK! = 0 AND SOFAR <> TOTALWORK

-- RMAN Status
select SESSION_KEY, INPUT_TYPE, STATUS,
       to_char(START_TIME,'mm/dd/yy hh24:mi') start_time,
       to_char(END_TIME,'mm/dd/yy hh24:mi') end_time,
       elapsed_seconds/3600 hrs 
from V$RMAN_BACKUP_JOB_DETAILS
order by session_key desc

--Size of DB
-- RMAN Status
select SESSION_KEY, INPUT_TYPE, STATUS,
       to_char(START_TIME,'mm/dd/yy hh24:mi') start_time,
       to_char(END_TIME,'mm/dd/yy hh24:mi') end_time,
       elapsed_seconds/3600 hrs 
from V$RMAN_BACKUP_JOB_DETAILS
order by session_key desc

-- SQL Audit
 SELECT ss.OSUSER,  sa.MODULE,  sa.SQL_TEXT, sa.last_active_time, sa.last_load_time
  FROM V$SQL V, V$SQLAREA sa, V$SESSION ss
 WHERE V.SQL_ID = sa.SQL_ID 
   AND V.SQL_ID = ss.SQL_ID
   
-- Top SQL
select a.sid, a.serial#, a.username, a.osuser, a.machine, a.terminal, a.program, b.sql_text 
  from v$session a, (select sid, serial#, sql_text, cpu_time, elapsed_time, cpu_time/elapsed_time as ctime from v$sql a, v$session b where a.sql_id=b.sql_id and b.status = 'ACTIVE') b 
 where a.sid=b.sid 
   and a.serial#=b.serial# 
   and cpu_time > 0
 order by b.ctime desc
 
-- Unlock User
alter user SHAYNES account unlock


