CREATE OR REPLACE PACKAGE NEW_APDEV.mail_pkg
AS

  TYPE array is table of varchar2(255);
  
  PROCEDURE send( p_sender_email in varchar2,
                p_from         in varchar2 default NULL,
                p_to           in array default array(),
                p_cc           in array default array(),
                p_bcc          in array default array(),
                p_subject      in varchar2 default NULL,
                p_body         in long  default NULL );

END mail_pkg;
/


CREATE OR REPLACE package body NEW_APDEV.mail_pkg
  AS

  g_crlf        char(2) default chr(13)||chr(10);
  g_mail_conn   utl_smtp.connection;
  g_mailhost    varchar2(255) := '10.159.6.150';--'10.159.6.108'; -- new proofpoint ip address 'nd-mx2.newburycorp.com';

-- ==========================<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
-- FUNCTION mail_pkg.address_email 
-- ==========================<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
FUNCTION address_email( p_string in varchar2,
                        p_recipients in array ) return varchar2
IS
 l_recipients long;
 
 BEGIN
/*
Author: D. O'Sullivan
Date: 12/16/03
Overview: builds the addressee strings for populating utl_smtp.rcpt


Modifications
-------------

*/

     for i in 1 .. p_recipients.count
     loop
        utl_smtp.rcpt(g_mail_conn, p_recipients(i) );
        if ( l_recipients is null )
       then
            l_recipients := p_string || p_recipients(i) ;
       else
            l_recipients := l_recipients || ', ' || p_recipients(i);
        end if;
    end loop;
     return l_recipients;
  end address_email;

PROCEDURE send( p_sender_email in varchar2,
                 p_from         in varchar2 default NULL,
                 p_to           in array default array(),
                 p_cc           in array default array(),
                 p_bcc          in array default array(),
                 p_subject      in varchar2 default NULL,
                 p_body         in long  default NULL )
is
     l_to_list   long;
     l_cc_list   long;
     l_bcc_list  long;
     l_date      varchar2(255) default to_char( SYSDATE, 'dd Mon yy hh24:mi:ss' );

  -- ==========================<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
  -- FUNCTION mail_pkg.send.writeData 
  -- ==========================<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
  PROCEDURE writeData( p_text in varchar2 )
  AS
  BEGIN
    /*
  Author: D. O'Sullivan
  Date: 12/16/03
  Overview: writes text content to the email connection.
  
  Modifications
  -------------
  
  */

      if ( p_text is not null )
      then
          utl_smtp.write_data( g_mail_conn, p_text || g_crlf );
      end if;
  end;

BEGIN
  /*
Author: D. O'Sullivan
Date: 12/16/03
Overview: builds the email structure and executes the send

Modifications
-------------

*/

     g_mail_conn := utl_smtp.open_connection(g_mailhost, 25);

     utl_smtp.helo(g_mail_conn, g_mailhost);
     utl_smtp.mail(g_mail_conn, p_sender_email);



     l_to_list  := address_email( 'To: ', p_to );
     l_cc_list  := address_email( 'Cc: ', p_cc );
     l_bcc_list := address_email( 'Bcc: ', p_bcc );


     utl_smtp.open_data(g_mail_conn );

     writeData( 'Date: ' || l_date );
     writeData( 'From: ' || nvl( p_from, p_sender_email ) );
     writeData( 'Subject: ' || nvl( p_subject, '(no subject)' ) );

     writeData( l_to_list );
     writeData( l_cc_list );

     utl_smtp.write_data( g_mail_conn, '' || g_crlf );
     utl_smtp.write_data(g_mail_conn, p_body );
     utl_smtp.close_data(g_mail_conn );
     utl_smtp.quit(g_mail_conn);
END send;


END mail_pkg;
/
