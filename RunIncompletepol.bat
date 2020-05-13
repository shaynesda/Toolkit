ping 1.1.1.1 -n 1 -w 300000 > NUL
cls
g:
cd g:\agentpak\!Daily_Load\deletes\wf_load
sqlplus apdev/ellen@ORACLE1 @run_incomplete_policies.sql 
rem g:\AgentPak\!Daily_Load\Deletes\WF_LOAD\bmail -s nd-mx2 -t "dgilmore@ndgroup.com,nneenan@ndgroup.com,woconnell@ndgroup.com,cveerabomma@ndgroup.com,gboncek@ndgroup.com,dlattin@ndgroup.com,jIarrobino@ndgroup.com" -f "ND-WEBHOLD1" -a "Apdev Incomplete policies not loaded"  -m "G:\AgentPak\!Daily_Load\Deletes\WF_LOAD\daily_incompletes.txt" 
REM del g:\agentpak\!Daily_Load\deletes\wf_load\incomplete.txt

sqlplus apdev/ellen@ORACLE1 @run_Endorsement_pending.sql 
rem g:\AgentPak\!Daily_Load\Deletes\WF_LOAD\bmail -s nd-mx2 -t "dgilmore@ndgroup.com,nneenan@ndgroup.com,woconnell@ndgroup.com,cveerabomma@ndgroup.com,gboncek@ndgroup.com,mmeehan@ndgroup.com,speterson@ndgroup.com,ecollins@ndgroup.com" -f "ND-WEBHOLD1" -a "Apdev Morning Load Policies in Endorsement Pending Status"  -m "G:\AgentPak\!Daily_Load\Deletes\WF_LOAD\daily_End_Pending.txt" 

exit