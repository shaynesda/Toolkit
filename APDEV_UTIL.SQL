CREATE OR REPLACE PACKAGE APDEV.apdev_util
AS
   PROCEDURE update_status(
      p_proc_name    IN   new_apdev.load_status.build_proc%TYPE,
      p_build_notes   IN   new_apdev.load_status.build_notes%TYPE);

   PROCEDURE update_status(
      p_proc_name    IN   new_apdev.load_status.build_proc%TYPE,
      p_build_notes   IN   new_apdev.load_status.build_notes%TYPE,
      p_start_time    IN   new_apdev.load_status.last_build_start_date%TYPE);

   PROCEDURE write_error(
      p_err_proc   IN   apdev.load_log.event_routine%TYPE,
      p_err_msg    IN   apdev.load_log.event_message%TYPE);

   PROCEDURE Send_mail(
      p_err_proc   IN   apdev.load_log.event_routine%TYPE,
      p_to         IN   mail_pkg.array,
      p_msg        IN   apdev.load_log.event_message%TYPE); 
      
      PROCEDURE Send_html_email (
      p_subject   IN   load_log.event_routine%TYPE,
      p_to   IN   mail_pkg.array,
      p_txt_msg_before_table     varchar2,
      p_html_query    IN   varchar2,
      p_txt_msg_after_table     varchar2);    

-- Date constants for reloading tables
   v_default_reload_date    DATE        := TO_DATE('01012004', 'MMDDYYYY');
-- Table name constants (must match tables in schema)

-- Misc. variables
   v_count                     NUMBER;
   v_sql_stmt                  VARCHAR2(200);
   v_build_notes               new_apdev.load_status.build_notes%TYPE;
END apdev_util;
/


CREATE OR REPLACE PACKAGE BODY APDEV.apdev_util
AS
-- ==========================<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
-- PROCEDURE new_apdev.apdev_util.UPDATE_STATUS
-- ==========================<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
   PROCEDURE update_status(
      p_proc_name    IN   new_apdev.load_status.build_proc%TYPE,
      p_build_notes   IN   new_apdev.load_status.build_notes%TYPE)
   IS
   BEGIN
/*
Author: D. O'Sullivan
Date: 12/16/03
Overview: status update proc for posting load results


Modifications
-------------

*/
      UPDATE new_apdev.load_status
         SET last_build_end_date = SYSDATE,
             last_built_by = (SELECT USER
                                FROM DUAL),
             build_notes = p_build_notes
         WHERE UPPER(build_proc) = UPPER(p_proc_name);

      COMMIT;
   END update_status;

-- ==========================<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
-- PROCEDURE new_apdev.apdev_util.UPDATE_STATUS(2)
-- ==========================<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
   PROCEDURE update_status(
      p_proc_name    IN   new_apdev.load_status.build_proc%TYPE,
      p_build_notes   IN   new_apdev.load_status.build_notes%TYPE,
      p_start_time    IN   new_apdev.load_status.last_build_start_date%TYPE)
   IS
      v_proc_runtime        new_apdev.load_status.build_time%TYPE;
   v_proc_runtime_secs   new_apdev.load_status.build_time_secs%TYPE;
   v_inc     NUMBER :=0;   

   BEGIN
/*
Author: D. O'Sullivan
Date: 8/10/04
Overview: status update overload proc for posting load results w/extra info
Modifications
-------------
*/
      v_proc_runtime :=
         FLOOR(((SYSDATE - p_start_time) * 24 * 60 * 60) / 3600) ||
         ' HOURS '                                      ||
         FLOOR((((SYSDATE - p_start_time) * 24 * 60 * 60)                   -
                FLOOR(((SYSDATE - p_start_time) * 24 * 60 * 60) / 3600)
                * 3600)                     /
               60)                                      ||
         ' MINUTES '                                    ||
         ROUND((((SYSDATE - p_start_time) * 24 * 60 * 60)                   -
                FLOOR(((SYSDATE - p_start_time) * 24 * 60 * 60) / 3600)
                * 3600                                                      -
                (FLOOR((((SYSDATE - p_start_time) * 24 * 60 * 60) -
                        FLOOR(((SYSDATE - p_start_time) * 24 * 60 * 60)
                              / 3600)                                     *
                        3600)                       /
                       60)                            *
                 60)))                                  ||
         ' SECS ';

   v_proc_runtime_secs := (SYSDATE - p_start_time) * 24 * 60 * 60;
   
   -- only increment build counter for successful runs
   --IF INSTR(UPPER(p_build_notes),'SUCCESS') > 0 THEN
   --  v_inc := 1;
   --END IF;
   
      
      UPDATE new_apdev.load_status
         SET last_build_end_date = SYSDATE,
             last_built_by = (SELECT USER
                                FROM DUAL),
             build_notes = p_build_notes,
             last_build_start_date = p_start_time,
             build_time = v_proc_runtime,
    build_time_secs = v_proc_runtime_secs 
       WHERE UPPER(build_proc) = UPPER(p_proc_name);

      COMMIT;
   END update_status;

-- ==========================<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
-- PROCEDURE new_apdev.apdev_util.WRITE_ERROR
-- ==========================<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
   PROCEDURE write_error(
      p_err_proc   IN   apdev.load_log.event_routine%TYPE,
      p_err_msg    IN   apdev.load_log.event_message%TYPE)
   IS
   
   v_EmailMsg    long;
   v_user     varchar2(50);
   
   BEGIN
/*
Author: D. O'Sullivan
Date: 12/18/03
Overview: error logging for productivity schema objects
Modifications
-------------
*/
      INSERT INTO apdev.load_log (event_date, 
                event_routine, 
           event_message)
                  VALUES (SYSDATE,
                            p_err_proc,
           p_err_msg);
           

      COMMIT;
/*  
 
   SELECT USER
   INTO v_user
   FROM DUAL;
   
   v_EmailMsg := 'The following error was written to the error log at ' || TO_CHAR(sysdate,'MM/DD/YYYY HH24:MI:SS'); 
   v_EmailMsg := v_EmailMsg || ' * USER: ' || v_user;
   v_EmailMsg := v_EmailMsg || ' * ROUTINE: ' || p_err_proc;
   v_EmailMsg := v_EmailMsg || ' * MESSAGE: ' || p_err_msg;
   
   BEGIN
       mail_pkg.send ( p_sender_email => 'oracle@ndgroup.com',
                   p_from => 'Oracle NEW_APDEV@ORACLE1 Database',
                   p_to => mail_pkg.array( 'Ora_Loadalerts@ndgroup.com'),
                   p_subject => 'Error Written to NEW_APDEV Error Log',
                   p_body => v_EmailMsg);

   EXCEPTION
    WHEN OTHERS THEN
    NULL; -- do nothing as we presume the email pkg is not available.
   END;
*/  
   END write_error;
   

  PROCEDURE send_mail(
       p_err_proc   IN   apdev.load_log.event_routine%TYPE,
      p_to   IN   mail_pkg.array,
      p_msg    IN   apdev.load_log.event_message%TYPE)
   IS
   
   v_EmailMsg       long;
   v_user           varchar2(50);
   v_from          varchar2(50);
   v_db            varchar2(30);
   V_PROCNAME              varchar2(30) := 'APDEV_UTIL.SEND_MAIL';
V_ERR_MSSG               varchar2(2000);
   
   BEGIN
/*
Author: Chandu
Date: 03/02/10
Overview: error logging for schema processing
Modifications
-------------
*/
     
                                      

      COMMIT;
      
      SELECT USER
      INTO v_user
      FROM DUAL;

--      SELECT NAME 
--      INTO v_db
--      FROM v$database;
      
      v_from := 'Oracle ' || v_user || '@' || 'QA1' || ' Database';
             
     /* v_EmailMsg := 'The following error was written to the error log at ' || TO_CHAR(sysdate,'MM/DD/YYYY HH24:MI:SS') || v_crlf; 
      v_EmailMsg := v_EmailMsg || ' * USER: ' || v_user || v_crlf;
      v_EmailMsg := v_EmailMsg || ' * DB: ' || v_db || v_crlf;      
      v_EmailMsg := v_EmailMsg || ' * ROUTINE: ' || p_err_proc || v_crlf;
      v_EmailMsg := v_EmailMsg || ' * MESSAGE: ' || p_err_msg;*/
      
      v_EmailMsg := p_msg;
      
      BEGIN
         mail_pkg.send ( p_sender_email => 'oracle@ndgroup.com',
                            p_from => 'Oracle APDEV@ORACLE1 Database',
                            p_to => p_to,--mail_pkg.array( p_to),
                            p_subject => p_err_proc,
                            p_body => v_EmailMsg);

      EXCEPTION
          WHEN OTHERS THEN
           v_err_MSSG:='FAILED:'||SQLCODE||':'||SQLERRM(SQLCODE)||v_procname;
          -- new_apdev.apdev_util.write_log(v_procname, v_err_msSg  );
             NULL; -- do nothing as we presume the email pkg is not available.
      END;
      
   END send_mail;
    PROCEDURE  Send_html_email (
 p_subject   IN   load_log.event_routine%TYPE,
      p_to   IN   mail_pkg.array,
      p_txt_msg_before_table     varchar2,
      p_html_query    IN   varchar2,
      p_txt_msg_after_table     varchar2)
IS
/******************************************************************************
   NAME:       WRITE_DELIM_FILE
   PURPOSE:    

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        9/12/2013    CHANDU     1. Created this procedure.( Generates the Delimited text files like CSV)

   NOTES:

   Automatically available Auto Replace Keywords:
      Object Name:     WRITE_DELIM_FILE
      Sysdate:         9/12/2013
     
******************************************************************************/

v_cursor INTEGER DEFAULT DBMS_SQL.open_cursor;
v_colval VARCHAR2 (4000);
v_rc INTEGER;
V_colcnt NUMBER DEFAULT 0;
v_numRecs NUMBER DEFAULT 0;
tbl_Column DBMS_SQL.desc_tab;
v_extract_date date     := SYSDATE;
v_html_message  Long;
v_html_query    Long;


 v_user           varchar2(50);
   v_from          varchar2(50);
   v_db            varchar2(30);

 -- debugging/exception variables
   v_procname        VARCHAR2(20)                      := 'Send_formatted_email';
   v_err_loc         VARCHAR2(100);
   v_err_number      NUMBER;
   v_err_msg         VARCHAR2(1500);
   v_log_msg      load_log.event_message%TYPE;  

BEGIN

 SELECT USER
      INTO v_user
      FROM DUAL;

     

      V_DB:='ORACLE1';

      v_from := 'Oracle ' || v_user || '@' || v_db || ' Database';


   if p_html_query is not null then
   
   v_html_query:=replace(p_html_query,';','');
   
     v_html_message:='<html> <body> <table border="1"  ><tr>'; 

        DBMS_SQL.parse (v_cursor, v_html_query, DBMS_SQL.native);

        DBMS_SQL.describe_columns (v_cursor, V_colcnt, tbl_Column);

        FOR i IN 1 .. V_colcnt
        LOOP

        DBMS_SQL.define_column (v_cursor, i, v_colval, 4000);

        IF (tbl_Column (i).col_type = 2) /* number type */
        THEN
        tbl_Column (i).col_max_len := tbl_Column (i).col_precision+ 2;

        ELSIF (tbl_Column (i).col_type = 12) /* date type */
        THEN
        /* length of my date format */
        tbl_Column (i).col_max_len := 20;
        ELSIF (tbl_Column (i).col_type = 8) /* LONG type */
        THEN
        tbl_Column (i).col_max_len := 2000;
        END IF;

        
        v_html_message:=v_html_message||'<th style="border-right:2px;"  bgcolor="#CDE6EA" align="center"><font size ="2" face="Times New roman" color="RED">'||tbl_Column (i).col_name||'</font></Th>';
                
        END LOOP;

        v_html_message:=v_html_message||'</tr>';


        v_rc := DBMS_SQL.EXECUTE (v_cursor);

        LOOP
        EXIT WHEN (DBMS_SQL.fetch_rows (v_cursor) <= 0);
        v_html_message:=v_html_message||'<tr>';
        FOR i IN 1 .. V_colcnt
        LOOP
        DBMS_SQL.column_value (v_cursor, i, v_colval);

        v_html_message:=v_html_message||'<td>'||v_colval||'</td>';
        
        END LOOP;
         v_html_message:=v_html_message||'</tr>';
        
        v_numRecs := v_numRecs+ 1;
        END LOOP;

       v_html_message:=v_html_message||'</table></body></html> ';
       
       else 

       v_html_message:=null;

      end if;


DBMS_SQL.close_cursor (v_cursor);


v_html_message:='<br><font size ="3" font face="calibri" color="black">'|| p_txt_msg_before_table||'</font>'||chr(10)||chr(13)||v_html_message||chr(10)||chr(13)||'<br><font size ="3" font face="calibri" color="black">'||p_txt_msg_after_table||'</font>';

BEGIN
          mail_pkg.send_html ( p_sender_email => 'oracle@ndgroup.com',
                            p_from => v_from,
                            p_to => p_to,--mail_pkg.array( p_to),
                            p_subject => p_subject,
                           -- p_text_msg_before_table =>p_txt_msg_before_table,
                            p_html_msg  =>v_html_message
                           -- p_text_msg_after_table=>p_txt_msg_after_table
                            );

      EXCEPTION
          WHEN OTHERS THEN
           v_err_MSG:='FAILED:'||SQLCODE||':'||SQLERRM(SQLCODE)||v_procname;
           APDEV.APDEV_UTIL.SEND_MAIL('ERROR1',apdev.MAIL_PKG.ARRAY('cveerabomma@ndgroup.com' ),v_err_MSG);
           --rpt_util.write_log(v_procname, v_err_msg  );
             NULL; -- do nothing as we presume the email pkg is not available.
      END;

EXCEPTION

WHEN OTHERS
THEN
v_err_number := SQLCODE;
         v_err_msg := SQLERRM(SQLCODE);
         v_err_msg :=
            'FAILED: ' || v_err_number || ' * ' || v_err_loc || ' * '
            || v_err_msg;
          DBMS_OUTPUT.put_line(v_err_msg);
          APDEV.APDEV_UTIL.SEND_MAIL('ERROR2',apdev.MAIL_PKG.ARRAY('cveerabomma@ndgroup.com' ),v_err_loc||':'||v_err_MSG);
      --rptviewer.rpt_util.write_log(v_procname,v_err_msg);            

END Send_html_email;

END apdev_util;
/
