CREATE OR REPLACE PROCEDURE RPTVIEWER.MERGE_FILE(file_name VARCHAR2) IS
 vSFile   utl_file.file_type;
 f1            utl_file.file_type;
 vNewLine VARCHAR2(400);
 V_FILENAME VARCHAR2(30):='NJ_WCRIB.TXT';
 TRANSMITTAL_REC  VARCHAR2(300);
 SUBMISSION_REC   VARCHAR2(300);
 COUNT_REC        NUMBER;
 COUNT_HEADER     NUMBER;
 TRANS_MIN_DT     VARCHAR2(8);
 TRANS_MAX_DT     VARCHAR2(8);
 cnt              Number;
 file_failed  exception;
 V_ERR_MSSG        VARCHAR2(100);
 V_PROCNAME        VARCHAR2(30):='PEEP.MERGE_FILE';
 
 CURSOR FILE_LIST IS
   SELECT * 
      FROM PEEP_NJ_WCRIB 
      WHERE MERGE='Y';
 
 
BEGIN

rptviewer.rpt_util.write_log(v_procname,'Nj File Merged STARTED');
Select count(*) into cnt 
from PEEP_NJ_WCRIB 
WHERE MERGE='Y';

if cnt=0 then
raise file_failed;
end if;

F1        := utl_file.fopen( 'ORASHARE', V_filename,'w', 32000);
TRANSMITTAL_REC:='$!+WORKCOMP+!$'||RPAD('WC_Bureau_Reporting@ndgroup.com',31)||LPAD(' ',2,' ')||'WCP'||'00029'||TO_CHAR(SYSDATE,'YYDDD')||'V01'||'T'||LPAD(' ',8,' ')||LPAD('21083',5,'0')||RPAD('KeriAnn Wells',25)||'E'||'8006881825'||'1191'||LPAD(' ',2,' ')||'7814077198'||TO_CHAR(SYSDATE,'YYYYMMDD')||RPAD('222  AMES STREET',60)||RPAD('DEDHAM',30)||'MA'||RPAD('02026',9)||'C'||LPAD(' ',9,' ')||LPAD(' ',1,' ')||LPAD(' ',51,' ');
 utl_file.put_line( f1,TRANSMITTAL_REC,FALSE );
FOR I IN FILE_LIST
LOOP
  vSFile := utl_file.fopen('ORASHARE', I.file_name,'r');
  

  IF utl_file.is_open(vSFile) THEN
    LOOP
      BEGIN
        utl_file.get_line(vSFile, vNewLine);

        IF vNewLine IS NULL THEN
          EXIT;
        END IF;
        
        
        
        --TRANSMITTAL_REC:='$!+WORKCOMP+!$'||RPAD('WC_Bureau_Reporting@ndgroup.com',31)||LPAD(' ',2,' ')||'WCP'||'00029'||TO_CHAR(SYSDATE,'YYDDD')||'V01'||'T'||LPAD(' ',8,' ')||LPAD(I.NAME,5,'0')||RPAD('KeriAnn Wells',25)||'E'||'8006881825'||'1191'||LPAD(' ',2,' ')||'7814077198'||TO_CHAR(SYSDATE,'YYYYMMDD')||RPAD('222  AMES STREET',60)||RPAD('DEDHAM',30)||'MA'||RPAD('02026',9)||'C'||LPAD(' ',9,' ')||LPAD(' ',1,' ')||LPAD(' ',51,' ');
        utl_file.put_line( f1,vNewLine,FALSE );
        
--        INSERT INTO test 
--        (fld1, fld2)
--        VALUES
--        (vNewLine, file_name);
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          EXIT;
      END;
    END LOOP;
    COMMIT;
  END IF;
  END LOOP;
  
  utl_file.fclose(vSFile);
  
  SELECT SUM(P.NUM_REC),SUM(P.NUM_HEADER),TO_CHAR(MIN(MIN_RUN_DATE),'YYYYMMDD'),TO_CHAR(MAX(MAX_RUN_DATE),'YYYYMMDD')
  INTO COUNT_REC,COUNT_HEADER,TRANS_MIN_DT,TRANS_MAX_DT
  FROM PEEP_NJ_WCRIB P
  WHERE MERGE='Y';
  
  UPDATE PEEP_NJ_WCRIB SET MERGE='N',MERGE_DATE=SYSDATE,MERGE_FILE_NAME=V_FILENAME
  WHERE MERGE='Y';
  
  COMMIT;
  
  SUBMISSION_REC:=LPAD(' ',45,' ')||'99'||LPAD(COUNT_REC+1,10,'0')||LPAD(COUNT_HEADER,8,'0')||TRANS_MIN_DT||TRANS_MAX_DT||LPAD(' ',219,' ');
   utl_file.put_line( f1,SUBMISSION_REC,FALSE );
  utl_file.fclose( f1 );
  
  
  UPDATE PEEP_NJ_LOG SET CURRENT_FLAG='N'
  WHERE CURRENT_FLAG='Y';
  
  COMMIT;
  
  INSERT INTO PEEP_NJ_LOG(
     MIN_RUN_DATE,
     MAX_RUN_DATE,
     NO_OF_RECORDS,
     NO_OF_HEADER,
     FILE_NAME,
     SUBMIT_DATE,
     CURRENT_FLAG)
     VALUES
     (TRANS_MIN_DT,
      TRANS_MAX_DT,
      COUNT_REC+1,
      COUNT_HEADER,
      V_filename,
      SYSDATE,
      'Y');
      
      COMMIT;
      

  --utl_file.frename('ORALOAD', 'test.txt', 'ORALOAD', 'x.txt', TRUE);
EXCEPTION
 WHEN file_failed THEN
  V_ERR_MSSG:='NO FILES FOUND TO MERGE FOR NJ WEEKLY SUBMISSION';
  rptviewer.rpt_util.write_error(v_procname,V_ERR_MSSG);
  rptviewer.rpt_util.update_status(V_PROCNAME,'File Creation Failed :');
  WHEN utl_file.invalid_mode THEN
    RAISE_APPLICATION_ERROR (-20051, 'Invalid Mode Parameter');
  WHEN utl_file.invalid_path THEN
    RAISE_APPLICATION_ERROR (-20052, 'Invalid File Location');
  WHEN utl_file.invalid_filehandle THEN
    RAISE_APPLICATION_ERROR (-20053, 'Invalid Filehandle');
  WHEN utl_file.invalid_operation THEN
    RAISE_APPLICATION_ERROR (-20054, 'Invalid Operation');
  WHEN utl_file.read_error THEN
    RAISE_APPLICATION_ERROR (-20055, 'Read Error');
  WHEN utl_file.internal_error THEN
    RAISE_APPLICATION_ERROR (-20057, 'Internal Error');
  WHEN utl_file.charsetmismatch THEN
    RAISE_APPLICATION_ERROR (-20058, 'Opened With FOPEN_NCHAR
    But Later I/O Inconsistent');
  WHEN utl_file.file_open THEN
    RAISE_APPLICATION_ERROR (-20059, 'File Already Opened');
  WHEN utl_file.invalid_maxlinesize THEN
    RAISE_APPLICATION_ERROR(-20060,'Line Size Exceeds 32K');
  WHEN utl_file.invalid_filename THEN
    RAISE_APPLICATION_ERROR (-20061, 'Invalid File Name');
  WHEN utl_file.access_denied THEN
    RAISE_APPLICATION_ERROR (-20062, 'File Access Denied By');
  WHEN utl_file.invalid_offset THEN
    RAISE_APPLICATION_ERROR (-20063,'FSEEK Param Less Than 0');
  WHEN others THEN
    --RAISE_APPLICATION_ERROR (-20099, 'Unknown UTL_FILE Error');
    DBMS_OUTPUT.PUT_LINE(SQLERRM(SQLCODE));
END MERGE_FILE; 
/
