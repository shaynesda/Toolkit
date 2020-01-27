CREATE OR REPLACE PROCEDURE RPTVIEWER.blob_DB(table_name VARCHAR2, colName VARCHAR2, error_name VARCHAR2, fileName VARCHAR2, ID VARCHAR2)
  AS LANGUAGE JAVA NAME 'StoreBlob.blobToDB(java.lang.String, java.lang.String,java.lang.String, java.lang.String, java.lang.String)';
/
