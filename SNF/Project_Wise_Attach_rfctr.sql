/********************************************************************
**  Name: Project Wise Attach
**  Refactored Date: 6/19/2026 
**  
**  Tables Used:
**  BENTLEYPROD (REPORTING_DB.EDW)  ->  BIRD_PROD (PRESENTATION.MART,
**                                                 PRESENTATION.EDW_TABLES,
**                                                 PRESENTATION.EDW)
**   CONSUMPTION_METRICS = OBT_CONSUMPTION_DAILY
**              PRODUCTS = DIM_PRODUCT
**                 SITES = DIM_ULTIMATE
**    **
**  Description: 
**
********************************************************************/


--------------------------
--DATABASE SETTINGS
--------------------------
USE DATABASE PRESENTATION;
USE SCHEMA EDW_TABLES;

USE SCHEMA MART;

---------------------
--QUESTION 1
---------------------
--Number of ProjectWise users in 26Q1 in each of the ENR and BI500 top firms 

--Distinct PW users (& all users) in 26Q1 for the ENR top firms by Ultimate
select
    cm."Ultimate ID" as ultimateid,
    s."Ultimate Name"as ultimate,
    s."Rank ENR Composite" as rank_enr_composite,
    count(distinct case when p."Brand" in ('ProjectWise', 'Connect') then cm."Unique User" end) as "Distinct PW Users",
    count(distinct cm."Unique User") as "Total Distinct Users",
    count(distinct case when p."Brand" in ('ProjectWise', 'Connect') then cm."Unique User" end) / nullif(count(distinct case when 1 = 1 then cm."Unique User" end), 0) as "Percent PW Users", 
 from MART.OBT_CONSUMPTION_DAILY cm
    join MART.DIM_ULTIMATE s on cm."Ultimate ID" = s."Ultimate ID"
    join MART.DIM_PRODUCT p ON cm."Product ID" = p."Product ID"
where cm."Year Quarter" = 20261
  and s."Rank ENR Composite" > 0  --none of the Rank ENR Composite were > 0?
group by all
order by s."Rank ENR Composite";


--Distinct PW users (& all users) in 26Q1 for the BI500 top firms by Ultimate 
select
    cm."Ultimate ID" as ultimateid,
    s."Ultimate Name"as ultimate,
    s."Rank Bentley Infrastructure 500" as RANK_BENTLEY_INFRASTRUCTURE_500,
    count(distinct case when p."Brand" in ('ProjectWise', 'Connect') then cm."Unique User" end) as "Distinct PW Users",
    count(distinct cm."Unique User" ) as "Total Distinct Users",
    count(distinct case when p."Brand" in ('ProjectWise', 'Connect') then cm."Unique User" end) / nullif(count(distinct case when 1 = 1 then cm."Unique User" end), 0) as "Percent PW Users", 
from MART.OBT_CONSUMPTION_DAILY cm
    join MART.DIM_ULTIMATE s on cm."Ultimate ID" = s."Ultimate ID" 
    join MART.DIM_PRODUCT p ON cm."Product ID" = p."Product ID"
where cm."Year Quarter" = 20261
  and s."Rank Bentley Infrastructure 500" > 0 --none of the Rank ENR Composite were > 0?
group by all
order by s."Rank Bentley Infrastructure 500";

select "Ultimate ID", "Rank Bentley Infrastructure 500" from MART.DIM_ULTIMATE where "Rank Bentley Infrastructure 500" > 0;

--Validation
select count(distinct cm."Unique User") from MART.OBT_CONSUMPTION_DAILY cm join MART.DIM_PRODUCT p on cm."Product ID" = p."Product ID" where p."Brand" in ('ProjectWise', 'Connect') and cm."Year Quarter"=20261 and cm."Ultimate ID"=1001381641;
select count(distinct cm."Unique User") from MART.OBT_CONSUMPTION_DAILY cm join MART.DIM_PRODUCT p on cm."Product ID" = p."Product ID" where cm."Year Quarter"=20261 and cm."Ultimate ID"=1001381641;



-------------------
--QUESTION 2
-------------------
--% of Cat A app users that used ProjectWise in 26Q1 & % of consumption (+ trending back to 25Q1)
    
--Stage all Cat A users by quarter
create or replace temporary table SANDBOX.FPANDA.cata_users_by_qtr as
select distinct
    cm."Year Quarter" as year_quarter,
    cm."Unique User" as unique_user
from MART.OBT_CONSUMPTION_DAILY cm
where cm."In Contracts" = 'Yes' 
  and cm."Year Quarter" between 20251 and 20261
  and cm."E365 Category" = 'Category A';

  select distinct
    cm."Year Quarter" as year_quarter,
    cm."Unique User" as unique_user
from MART.OBT_CONSUMPTION_DAILY cm
where cm."In Contracts" = 'Yes' 
  and cm."Year Quarter" between 20251 and 20261
  and cm."E365 Category" = 'Category A';


--Stage all ProjectWise users by quarter (by brand)
create or replace temporary table SANDBOX.FPANDA.pw_users_by_qtr as
select distinct
    cm."Year Quarter" as year_quarter,
    cm."Unique User" as unique_user
from MART.OBT_CONSUMPTION_DAILY cm
join MART.DIM_PRODUCT p on p."Product ID" = cm."Product ID"
where cm."In Contracts" = 'Yes' 
  and cm."Year Quarter" between 20251 and 20261
  and p."Brand" in ('ProjectWise', 'Connect'); 
--and brand = 'ProjectWise';

--Stage overlap (Cat A users who also used PW in that same quarter)
create or replace temporary table SANDBOX.FPANDA.cata_pw_users_by_qtr as
select distinct
    c.year_quarter,
    c.unique_user
from SANDBOX.FPANDA.cata_users_by_qtr c
join SANDBOX.FPANDA.pw_users_by_qtr pw on c.year_quarter = pw.year_quarter
   and c.unique_user = pw.unique_user;


--Total count of Cat A distinct users by quarter
create or replace temporary table SANDBOX.FPANDA.cata_user_counts_by_qtr as
select
    year_quarter,
    count(distinct unique_user) as total_cata_users
from SANDBOX.FPANDA.cata_users_by_qtr
group by 1 order by 1;


--Total Count Cat A users who also used PW by quarter
create or replace temporary table SANDBOX.FPANDA.cata_pw_user_counts_by_qtr as
select
    year_quarter,
    count(distinct unique_user) as cata_users_using_pw
from SANDBOX.FPANDA.cata_pw_users_by_qtr
group by 1 order by 1;


--Total PW consumption by quarter
create or replace temporary table SANDBOX.FPANDA.total_pw_consumption_by_qtr as
select
    cm."Year Quarter" as year_quarter,
    sum(cm."Normalized Consumption") as total_pw_consumption
from MART.OBT_CONSUMPTION_DAILY cm
join MART.DIM_PRODUCT p on p."Product ID" = cm."Product ID"
where cm."In Contracts" = 'Yes'
  and cm."Year Quarter" between 20251 and 20261
  and p."Brand"  in ('ProjectWise', 'Connect') 
group by 1 order by 1;


--PW consumption from Cat A users who also used PW
create or replace temporary table SANDBOX.FPANDA.cata_pw_consumption_by_qtr as
 select
      cm."Year Quarter" as year_quarter,
      sum(cm."Normalized Consumption") as cata_pw_consumption
   from MART.OBT_CONSUMPTION_DAILY cm
   join MART.DIM_PRODUCT p
     on p."Product ID" = cm."Product ID"
   join SANDBOX.FPANDA.cata_pw_users_by_qtr u on cm."Year Quarter" = u.year_quarter
    and cm."Unique User" = u.unique_user
  where cm."In Contracts" = 'Yes'
    and cm."Year Quarter" between 20251 and 20261
    and p."Brand" in ('ProjectWise', 'Connect') 
  group by 1 order by 1;


--Final output
select
    a.year_quarter,
    a.total_cata_users,
    coalesce(b.cata_users_using_pw, 0) as cata_users_using_pw,
    coalesce(b.cata_users_using_pw, 0) * 1.0 / nullif(a.total_cata_users, 0) as pct_cata_users_using_pw,
    coalesce(c.cata_pw_consumption, 0) as cata_user_pw_consumption,
    d.total_pw_consumption,
    coalesce(c.cata_pw_consumption, 0) * 1.0 / nullif(d.total_pw_consumption, 0) as pct_pw_consumption_from_cata_pw_users
from SANDBOX.FPANDA.cata_user_counts_by_qtr a
left join SANDBOX.FPANDA.cata_pw_user_counts_by_qtr b on a.year_quarter = b.year_quarter
left join SANDBOX.FPANDA.cata_pw_consumption_by_qtr c on a.year_quarter = c.year_quarter
left join SANDBOX.FPANDA.total_pw_consumption_by_qtr d on a.year_quarter = d.year_quarter
order by 1;



--Single CTE (for Sigma)
with cata_users_by_qtr as (
    select distinct
           cm."Year Quarter" as year_quarter,
           cm."Unique User" as unique_user
      from MART.OBT_CONSUMPTION_DAILY cm
     where cm."In Contracts" = 'Yes'
       and cm."Year Quarter" between 20251 and 20261
       and cm."E365 Category" = 'Category A'),
pw_users_by_qtr as (
    select distinct
           cm."Year Quarter" as year_quarter,
           cm."Unique User" as unique_user
      from MART.OBT_CONSUMPTION_DAILY cm
      join MART.DIM_PRODUCT p
        on p."Product ID" = cm."Product ID"
     where cm."In Contracts" = 'Yes'
       and cm."Year Quarter" between 20251 and 20261
       and p."Brand" in ('ProjectWise', 'Connect')), 
cata_pw_users_by_qtr as (
    select distinct
          c.year_quarter,
          c.unique_user
      from cata_users_by_qtr c
      join pw_users_by_qtr pw on c.year_quarter = pw.year_quarter
       and c.unique_user = pw.unique_user),
cata_user_counts_by_qtr as (
    select
           year_quarter,
           count(distinct unique_user) as total_cata_users
      from cata_users_by_qtr
      group by year_quarter),
cata_pw_user_counts_by_qtr as (
    select
        year_quarter,
        count(distinct unique_user) as cata_users_using_pw
    from cata_pw_users_by_qtr
    group by year_quarter),
total_pw_consumption_by_qtr as (
    select
        cm."Year Quarter" as year_quarter,
        sum(cm."Normalized Consumption") as total_pw_consumption
    from MART.OBT_CONSUMPTION_DAILY cm
    join MART.DIM_PRODUCT p
      on p."Product ID" = cm."Product ID"
   where cm."In Contracts" = 'Yes'
     and cm."Year Quarter" between 20251 and 20261
     and p."Brand" in ('ProjectWise', 'Connect') 
   group by cm."Year Quarter"),
cata_pw_consumption_by_qtr as (
    select
          cm."Year Quarter" as year_quarter,
          sum(cm."Normalized Consumption") as cata_pw_consumption
      from MART.OBT_CONSUMPTION_DAILY cm
      join MART.DIM_PRODUCT p on p."Product ID" = cm."Product ID"
      join cata_pw_users_by_qtr u on cm."Year Quarter" = u.year_quarter
       and cm."Unique User" = u.unique_user
     where cm."In Contracts" = 'Yes'
       and cm."Year Quarter" between 20251 and 20261
       and p."Brand" in ('ProjectWise', 'Connect') 
     group by cm."Year Quarter")
select
    a.year_quarter,
    a.total_cata_users,
    coalesce(b.cata_users_using_pw, 0) as cata_users_using_pw,
    coalesce(b.cata_users_using_pw, 0) * 1.0 / nullif(a.total_cata_users, 0) as pct_cata_users_using_pw,
    coalesce(c.cata_pw_consumption, 0) as cata_pw_consumption,
    d.total_pw_consumption,
    coalesce(c.cata_pw_consumption, 0) * 1.0 / nullif(d.total_pw_consumption, 0) as pct_pw_consumption_from_cata_pw_users
from cata_user_counts_by_qtr a
left join cata_pw_user_counts_by_qtr b on a.year_quarter = b.year_quarter
left join cata_pw_consumption_by_qtr c on a.year_quarter = c.year_quarter
left join total_pw_consumption_by_qtr d on a.year_quarter = d.year_quarter
order by 1;



---------------------
--QUESTION 3
---------------------

/*
based on the Global Ultimate ID column in Sites:
Count of Distinct ProjectWise brand users for 26Q1 by Global UltimateID
Count of Distinct Connect brand users for 26Q1 by Global UltimateID
Count of Distinct Connect OR ProjectWise brand users for 26Q1 by Global UltimaetID
*/

select 
s."Ultimate ID" as global_ultimateiD, 
s."Ultimate Name" as ultimate, 
count(distinct case when p."Brand" ='ProjectWise' then cm."Unique User" end) as Distinct_PW_Users_26Q1,
count(distinct case when p."Brand" ='Connect'     then cm."Unique User" end) as Distinct_Connect_Users_26Q1,
count(distinct case when p."Brand" in ('ProjectWise', 'Connect') then cm."Unique User" end) as Distinct_Connect_Or_PW_Users_26Q1, 
from MART.OBT_CONSUMPTION_DAILY cm 
join MART.DIM_ULTIMATE s on cm."Ultimate ID" = s."Ultimate ID"
join MART.DIM_PRODUCT p ON cm."Product ID" = p."Product ID"
where cm."In Contracts" = 'Yes' and p."Brand" in ('ProjectWise','Connect') and cm."Year Quarter"=20261
group by all;