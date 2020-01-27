CREATE OR REPLACE FUNCTION NEW_APDEV.CheckDiff(
in_pol_num   in POLICY.POLICY_NUMBER%TYPE,
in_iar_id    in ITEM_AT_RISK.ITEM_AT_RISK_ID%TYPE,
in_comp_type in NAME.ADDRESS_1%type,
in_attrib_1  in NAME.ADDRESS_1%TYPE,
in_attrib_2  in NAME.ADDRESS_1%TYPE,
in_attrib_3  in NAME.ADDRESS_1%TYPE,
in_attrib_4  in NAME.ADDRESS_1%TYPE,
in_attrib_5  in NAME.ADDRESS_1%TYPE)

RETURN number is

Diff number;
max_issue_date date;


v_attrib_1 varchar2(50);
v_attrib_2 varchar2(50);
v_attrib_3 varchar2(50);
v_attrib_4 varchar2(50);
v_attrib_5 varchar2(50);

/* As of 4/27/2010 only the mailing address or NI address
   is being compared for difference - shaynes */

BEGIN

--if in_comp_type = 'NI'

/* When comparison type = 'NI' then
   in_attrib_1 = ADDRESS_1
   in_attrib_2 = ADDRESS_2
   in_attrib_3 = CITY
   in_attrib_4 = STATE_ALPHA_CODE
   in_attrib_5 = POSTAL_CODE
*/

--then
-- SET VARIABLES WITH VALUES TO COMPARE.

select max(dc.date_entered)
  into max_issue_date
  from NEW_APDEV.policy_do_version dc
 where dc.policy_number = in_pol_num;



/*XML Query that extracts all of the name objects out of the PolicyDo XML from the POLICY_DO_VERSION table
  and retrieves the full address from the named insured record and stores the components of the address in
  the predefined internal variables.
*/
select nvl(extractValue(pdv.NAME_OBJECT, '/name/fields/field[@name="ADDRESS_1"]/val'), ' ') ADDRESS_1,
       nvl(extractValue(pdv.NAME_OBJECT, '/name/fields/field[@name="ADDRESS_2"]/val'), ' ') ADDRESS_2,
       nvl(extractValue(pdv.NAME_OBJECT, '/name/fields/field[@name="CITY"]/val'), ' ') CITY,
       nvl(extractValue(pdv.NAME_OBJECT, '/name/fields/field[@name="STATE_ALPHA_CODE"]/val'), ' ') STATE,
       nvl(extractValue(pdv.NAME_OBJECT, '/name/fields/field[@name="POSTAL_CODE"]/val'), ' ') POSTAL_CODE
  into v_attrib_1,
       v_attrib_2,
       v_attrib_3,
       v_attrib_4,
       v_attrib_5
  from NEW_APDEV.ITEM_NAME itn,
     (select VALUE(NAMES) NAME_OBJECT, extractValue(value(NAMES), '/name/fields/field[@name="NAME_ID"]/val') name_ID
        from NEW_APDEV.POLICY_DO_VERSION i,
       table(XMLSequence(extract(i.policy_do_xml, '/com.nd.data.PolicyDO/names/name'))) NAMES
       where policy_number = in_pol_num
         and date_entered = max_issue_date
         and existsNode(i.policy_do_xml, '/com.nd.data.PolicyDO/names/name') = 1) pdv
where pdv.NAME_ID = itn.NAME_ID
  and itn.ITEM_NAME_TYPE_CODE = in_comp_type
  and itn.ITEM_AT_RISK_ID = in_iar_id;


--Compare the input variables with those retrieved from source of origin. Return 1 or 0
-- 1= Diff does not exist; 0 = Diff exist

select count(*)
  into Diff
  from dual
 where nvl(in_attrib_1, ' ') = v_attrib_1   -- ADDRESS_1
   and nvl(in_attrib_2, ' ') = v_attrib_2   -- ADDRESS_2
   and nvl(in_attrib_3, ' ') = v_attrib_3   -- CITY
   and nvl(in_attrib_4, ' ') = v_attrib_4   -- STATE_ALPHA_CODE
   and nvl(in_attrib_5, ' ') = v_attrib_5;  -- POSTAL_CODE

RETURN Diff;

END CheckDiff;
/
