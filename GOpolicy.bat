g:
cd g:\agentpak\!new_apdev\sds to staging
sqlldr userid=staging/etl@oracle1 control=controlfilepolicy.txt log=logfilepolicy.txt errors=100
--sqlplus apdev/ellen@oracle1 @set_loads_finished_to_null.sql 
exit