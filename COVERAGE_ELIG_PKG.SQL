CREATE OR REPLACE PACKAGE NEW_APDEV.COVERAGE_ELIG_PKG
AS
  TYPE cov_elig_list IS REF CURSOR;

  PROCEDURE get_valid_coverages(  --  ref cursor that returns eligible endorsements. Endorsements existing on the policy are always considered eligible.
    cov_list_arg          OUT  cov_elig_list,
    state_arg             IN   COVERAGE_GROUP_STATE.STATE_ALPHA_CODE%TYPE,
    group_line_code_arg   IN   COVERAGE_GROUP_STATE.GROUP_LINE_CODE%TYPE,
    form_arg              IN   COVERAGE_GROUP_STATE.FORM%TYPE,
    number_of_families_arg IN  IAR_PERSONAL_DWELLING.NUMBER_OF_FAMILIES%TYPE,
    construction_year_arg IN   IAR_PERSONAL_DWELLING.CONSTRUCTION_YEAR%TYPE,
    company_arg           IN   POLICY.ISSUE_COMPANY_CODE%TYPE,
    terr_arg              IN   IAR_PERSONAL_DWELLING.TERRITORY_CODE%TYPE,
    construction_type_arg IN   IAR_PERSONAL_DWELLING.CONSTRUCTION_CODE%TYPE,
    residence_type_arg    IN   IAR_PERSONAL_DWELLING.DWELLING_CODE%TYPE,
    policy_number_arg     IN   POLICY.POLICY_NUMBER%TYPE,
    num_rental_br_arg     IN   IAR_COVERAGE_ENDT_DETAIL.NO_RENTAL_BR%TYPE,
    roof_repl_age_arg     IN   IAR_COVERAGE_ENDT_DETAIL.ROOF_REPLACED_AGE%TYPE,
    electric_amps_arg     IN   IAR_COVERAGE_ENDT_DETAIL.ELECTRIC_AMPS%TYPE,
    plumbing_age_arg      IN   IAR_COVERAGE_ENDT_DETAIL.PLUMBING_AGE%TYPE,
    plumbing_type_arg     IN   IAR_COVERAGE_ENDT_DETAIL.PLUMBING_TYPE%TYPE,
    central_age_arg       IN   IAR_COVERAGE_ENDT_DETAIL.CENTRAL_AGE%TYPE,
    tot_val_struct_arg    IN   IAR_COVERAGE_ENDT_DETAIL.TOT_VAL_STRUCT%TYPE,
    nd_auto_pol_num_arg   IN   IAR_COVERAGE_ENDT_DETAIL.ND_AUTO_POL_NUM%TYPE,
    nd_auto_date_arg      IN   IAR_COVERAGE_ENDT_DETAIL.ND_AUTO_DATE%TYPE,
    frz_alarm_arg         IN   IAR_COVERAGE_ENDT_DETAIL.FRZ_ALARM%TYPE,
    winter_plumb_arg      IN   IAR_COVERAGE_ENDT_DETAIL.WINTERIZED_PLUMBING%TYPE,
    heat_sys_serv_arg     IN   IAR_COVERAGE_ENDT_DETAIL.ANNUAL_SERVICE_HEAT%TYPE,
    hs_pgm_arg            IN   IAR_COVERAGE_ENDT_DETAIL.HS_PGM_SUBMITTED%TYPE,
    ni_dob_arg            IN   NAME.DATE_OF_BIRTH%TYPE,
    ni2_dob_arg           IN   NAME.NI2_DOB%TYPE,
    res_unoc_3_mon_arg    IN   IAR_COVERAGE_ENDT_DETAIL.RES_UNOC_3_CON_MON%TYPE,
    cov_a_arg             IN   ITEM_AT_RISK_COVERAGE_LIMIT.LIMIT%TYPE,
    purch_date_arg        IN   IAR_PERSONAL_DWELLING.PURCHASE_DATE%TYPE,
    loss_free_year_arg    IN   IAR_COVERAGE_ENDT_DETAIL.LOSS_FREE_YEARS%TYPE,
    nd_com_pol_num_arg    IN   IAR_COVERAGE_ENDT_DETAIL.ND_COM_POL_NUM%TYPE,
    nd_com_date_arg       IN   IAR_COVERAGE_ENDT_DETAIL.ND_COM_DATE%TYPE,
    ins_score_arg         IN   UNDERWRITING_INFO.NI_CR_SCORE%TYPE,
    dist_to_coast_arg     IN   IAR_PERSONAL_DWELLING.DISTANCE_TO_COAST%TYPE,
    loss_free_arg         IN   UNDERWRITING_INFO.PRIOR_LOSSES_LST_5_YRS%TYPE,
    smoke_det_arg         IN   IAR_PERSONAL_DWELLING.NB_LOSSES%TYPE,
    pol_eff_dt_arg        IN   POLICY.POLICY_EFFECTIVE_DATE%TYPE,
    electric_age_arg      IN   IAR_COVERAGE_ENDT_DETAIL.ELECT_APARATUS%TYPE,
    ibc_arg               IN   IAR_PERSONAL_DWELLING.IBC%TYPE,
    wind_arg              IN   IAR_PERSONAL_DWELLING.WIND_ZONE%TYPE,
    agency_arg            IN   POLICY.AGENCY_NUMBER%TYPE,
    ownership_arg         IN   IAR_PERSONAL_DWELLING.IBC%TYPE,
    loc_struct_arg        IN   IAR_PERSONAL_DWELLING.IBC%TYPE,
    num_of_emp_arg        IN   IAR_PERSONAL_DWELLING.NUMBER_OF_FAMILIES%TYPE,
    bus_type_arg          IN   IAR_COVERAGE_ENDT_DETAIL.RATE_GROUP%TYPE,
    gross_receipts_arg    IN   IAR_COVERAGE_ENDT_DETAIL.MONEY%TYPE,
    cov_e_arg             IN   ITEM_AT_RISK_COVERAGE_LIMIT.LIMIT%TYPE,
    no_yrs_with_agy       IN   IAR_COVERAGE_ENDT_DETAIL.NEW_CONST_AGE%TYPE,
    oil_cert_arg          IN   IAR_COVERAGE_ENDT_DETAIL.TRUST_OPREM%TYPE,
    oil_leak_arg          IN   IAR_COVERAGE_ENDT_DETAIL.TRUST_OPREM%TYPE,
    zip_code_arg          IN   NAME.POSTAL_CODE%TYPE,
    flood_zone_arg        IN   IAR_PERSONAL_DWELLING.FLOOD_ZONE%TYPE,
    non_nd_auto_policy IN varchar,
    non_nd_auto_carrier IN varchar);

  PROCEDURE get_valid_coverages_api(    --  ref cursor that returns eligible endorsements regardless if the endorsements are on the policy or not.
    cov_list_arg          OUT  cov_elig_list,
    state_arg             IN   COVERAGE_GROUP_STATE.STATE_ALPHA_CODE%TYPE,
    group_line_code_arg   IN   COVERAGE_GROUP_STATE.GROUP_LINE_CODE%TYPE,
    form_arg              IN   COVERAGE_GROUP_STATE.FORM%TYPE,
    number_of_families_arg IN  IAR_PERSONAL_DWELLING.NUMBER_OF_FAMILIES%TYPE,
    construction_year_arg IN   IAR_PERSONAL_DWELLING.CONSTRUCTION_YEAR%TYPE,
    company_arg           IN   POLICY.ISSUE_COMPANY_CODE%TYPE,
    terr_arg              IN   IAR_PERSONAL_DWELLING.TERRITORY_CODE%TYPE,
    construction_type_arg IN   IAR_PERSONAL_DWELLING.CONSTRUCTION_CODE%TYPE,
    residence_type_arg    IN   IAR_PERSONAL_DWELLING.DWELLING_CODE%TYPE,
    policy_number_arg     IN   POLICY.POLICY_NUMBER%TYPE,
    num_rental_br_arg     IN   IAR_COVERAGE_ENDT_DETAIL.NO_RENTAL_BR%TYPE,
    roof_repl_age_arg     IN   IAR_COVERAGE_ENDT_DETAIL.ROOF_REPLACED_AGE%TYPE,
    electric_amps_arg     IN   IAR_COVERAGE_ENDT_DETAIL.ELECTRIC_AMPS%TYPE,
    plumbing_age_arg      IN   IAR_COVERAGE_ENDT_DETAIL.PLUMBING_AGE%TYPE,
    plumbing_type_arg     IN   IAR_COVERAGE_ENDT_DETAIL.PLUMBING_TYPE%TYPE,
    central_age_arg       IN   IAR_COVERAGE_ENDT_DETAIL.CENTRAL_AGE%TYPE,
    tot_val_struct_arg    IN   IAR_COVERAGE_ENDT_DETAIL.TOT_VAL_STRUCT%TYPE,
    nd_auto_pol_num_arg   IN   IAR_COVERAGE_ENDT_DETAIL.ND_AUTO_POL_NUM%TYPE,
    nd_auto_date_arg      IN   IAR_COVERAGE_ENDT_DETAIL.ND_AUTO_DATE%TYPE,
    frz_alarm_arg         IN   IAR_COVERAGE_ENDT_DETAIL.FRZ_ALARM%TYPE,
    winter_plumb_arg      IN   IAR_COVERAGE_ENDT_DETAIL.WINTERIZED_PLUMBING%TYPE,
    heat_sys_serv_arg     IN   IAR_COVERAGE_ENDT_DETAIL.ANNUAL_SERVICE_HEAT%TYPE,
    hs_pgm_arg            IN   IAR_COVERAGE_ENDT_DETAIL.HS_PGM_SUBMITTED%TYPE,
    ni_dob_arg            IN   NAME.DATE_OF_BIRTH%TYPE,
    ni2_dob_arg           IN   NAME.NI2_DOB%TYPE,
    res_unoc_3_mon_arg    IN   IAR_COVERAGE_ENDT_DETAIL.RES_UNOC_3_CON_MON%TYPE,
    cov_a_arg             IN   ITEM_AT_RISK_COVERAGE_LIMIT.LIMIT%TYPE,
    purch_date_arg        IN   IAR_PERSONAL_DWELLING.PURCHASE_DATE%TYPE,
    loss_free_year_arg    IN   IAR_COVERAGE_ENDT_DETAIL.LOSS_FREE_YEARS%TYPE,
    nd_com_pol_num_arg    IN   IAR_COVERAGE_ENDT_DETAIL.ND_COM_POL_NUM%TYPE,
    nd_com_date_arg       IN   IAR_COVERAGE_ENDT_DETAIL.ND_COM_DATE%TYPE,
    ins_score_arg         IN   UNDERWRITING_INFO.NI_CR_SCORE%TYPE,
    dist_to_coast_arg     IN   IAR_PERSONAL_DWELLING.DISTANCE_TO_COAST%TYPE,
    loss_free_arg         IN   UNDERWRITING_INFO.PRIOR_LOSSES_LST_5_YRS%TYPE,
    smoke_det_arg         IN   IAR_PERSONAL_DWELLING.NB_LOSSES%TYPE,
    pol_eff_dt_arg        IN   POLICY.POLICY_EFFECTIVE_DATE%TYPE,
    electric_age_arg      IN   IAR_COVERAGE_ENDT_DETAIL.ELECT_APARATUS%TYPE,
    ibc_arg               IN   IAR_PERSONAL_DWELLING.IBC%TYPE,
    wind_arg              IN   IAR_PERSONAL_DWELLING.WIND_ZONE%TYPE,
    agency_arg            IN   POLICY.AGENCY_NUMBER%TYPE,
    ownership_arg         IN   IAR_PERSONAL_DWELLING.IBC%TYPE,
    loc_struct_arg        IN   IAR_PERSONAL_DWELLING.IBC%TYPE,
    num_of_emp_arg        IN   IAR_PERSONAL_DWELLING.NUMBER_OF_FAMILIES%TYPE,
    bus_type_arg          IN   IAR_COVERAGE_ENDT_DETAIL.RATE_GROUP%TYPE,
    gross_receipts_arg    IN   IAR_COVERAGE_ENDT_DETAIL.MONEY%TYPE,
    cov_e_arg             IN   ITEM_AT_RISK_COVERAGE_LIMIT.LIMIT%TYPE,
    no_yrs_with_agy       IN   IAR_COVERAGE_ENDT_DETAIL.NEW_CONST_AGE%TYPE,
    oil_cert_arg          IN   IAR_COVERAGE_ENDT_DETAIL.TRUST_OPREM%TYPE,
    oil_leak_arg          IN   IAR_COVERAGE_ENDT_DETAIL.TRUST_OPREM%TYPE,
    zip_code_arg          IN   NAME.POSTAL_CODE%TYPE,
    flood_zone_arg        IN   IAR_PERSONAL_DWELLING.FLOOD_ZONE%TYPE,
    non_nd_auto_policy IN varchar,
    non_nd_auto_carrier IN varchar);

END COVERAGE_ELIG_PKG;
/


CREATE OR REPLACE PACKAGE BODY NEW_APDEV.COVERAGE_ELIG_PKG
AS

   PROCEDURE get_valid_coverages(
    cov_list_arg          OUT  cov_elig_list,
    state_arg             IN   COVERAGE_GROUP_STATE.STATE_ALPHA_CODE%TYPE,
    group_line_code_arg   IN   COVERAGE_GROUP_STATE.GROUP_LINE_CODE%TYPE,
    form_arg              IN   COVERAGE_GROUP_STATE.FORM%TYPE,
    number_of_families_arg IN  IAR_PERSONAL_DWELLING.NUMBER_OF_FAMILIES%TYPE,
    construction_year_arg IN   IAR_PERSONAL_DWELLING.CONSTRUCTION_YEAR%TYPE,
    company_arg           IN   POLICY.ISSUE_COMPANY_CODE%TYPE,
    terr_arg              IN   IAR_PERSONAL_DWELLING.TERRITORY_CODE%TYPE,
    construction_type_arg IN   IAR_PERSONAL_DWELLING.CONSTRUCTION_CODE%TYPE,
    residence_type_arg    IN   IAR_PERSONAL_DWELLING.DWELLING_CODE%TYPE,
    policy_number_arg     IN   POLICY.POLICY_NUMBER%TYPE,
    num_rental_br_arg     IN   IAR_COVERAGE_ENDT_DETAIL.NO_RENTAL_BR%TYPE,
    roof_repl_age_arg     IN   IAR_COVERAGE_ENDT_DETAIL.ROOF_REPLACED_AGE%TYPE,
    electric_amps_arg     IN   IAR_COVERAGE_ENDT_DETAIL.ELECTRIC_AMPS%TYPE,
    plumbing_age_arg      IN   IAR_COVERAGE_ENDT_DETAIL.PLUMBING_AGE%TYPE,
    plumbing_type_arg     IN   IAR_COVERAGE_ENDT_DETAIL.PLUMBING_TYPE%TYPE,
    central_age_arg       IN   IAR_COVERAGE_ENDT_DETAIL.CENTRAL_AGE%TYPE,
    tot_val_struct_arg    IN   IAR_COVERAGE_ENDT_DETAIL.TOT_VAL_STRUCT%TYPE,
    nd_auto_pol_num_arg   IN   IAR_COVERAGE_ENDT_DETAIL.ND_AUTO_POL_NUM%TYPE,
    nd_auto_date_arg      IN   IAR_COVERAGE_ENDT_DETAIL.ND_AUTO_DATE%TYPE,
    frz_alarm_arg         IN   IAR_COVERAGE_ENDT_DETAIL.FRZ_ALARM%TYPE,
    winter_plumb_arg      IN   IAR_COVERAGE_ENDT_DETAIL.WINTERIZED_PLUMBING%TYPE,
    heat_sys_serv_arg     IN   IAR_COVERAGE_ENDT_DETAIL.ANNUAL_SERVICE_HEAT%TYPE,
    hs_pgm_arg            IN   IAR_COVERAGE_ENDT_DETAIL.HS_PGM_SUBMITTED%TYPE,
    ni_dob_arg            IN   NAME.DATE_OF_BIRTH%TYPE,
    ni2_dob_arg           IN   NAME.NI2_DOB%TYPE,
    res_unoc_3_mon_arg    IN   IAR_COVERAGE_ENDT_DETAIL.RES_UNOC_3_CON_MON%TYPE,
    cov_a_arg             IN   ITEM_AT_RISK_COVERAGE_LIMIT.LIMIT%TYPE,
    purch_date_arg        IN   IAR_PERSONAL_DWELLING.PURCHASE_DATE%TYPE,
    loss_free_year_arg    IN   IAR_COVERAGE_ENDT_DETAIL.LOSS_FREE_YEARS%TYPE,
    nd_com_pol_num_arg    IN   IAR_COVERAGE_ENDT_DETAIL.ND_COM_POL_NUM%TYPE,
    nd_com_date_arg       IN   IAR_COVERAGE_ENDT_DETAIL.ND_COM_DATE%TYPE,
    ins_score_arg         IN   UNDERWRITING_INFO.NI_CR_SCORE%TYPE,
    dist_to_coast_arg     IN   IAR_PERSONAL_DWELLING.DISTANCE_TO_COAST%TYPE,
    loss_free_arg         IN   UNDERWRITING_INFO.PRIOR_LOSSES_LST_5_YRS%TYPE,
    smoke_det_arg         IN   IAR_PERSONAL_DWELLING.NB_LOSSES%TYPE,
    pol_eff_dt_arg        IN   POLICY.POLICY_EFFECTIVE_DATE%TYPE,
    electric_age_arg      IN   IAR_COVERAGE_ENDT_DETAIL.ELECT_APARATUS%TYPE,
    ibc_arg               IN   IAR_PERSONAL_DWELLING.IBC%TYPE,
    wind_arg              IN   IAR_PERSONAL_DWELLING.WIND_ZONE%TYPE,
    agency_arg            IN   POLICY.AGENCY_NUMBER%TYPE,
    ownership_arg         IN   IAR_PERSONAL_DWELLING.IBC%TYPE,
    loc_struct_arg        IN   IAR_PERSONAL_DWELLING.IBC%TYPE,
    num_of_emp_arg        IN   IAR_PERSONAL_DWELLING.NUMBER_OF_FAMILIES%TYPE,
    bus_type_arg          IN   IAR_COVERAGE_ENDT_DETAIL.RATE_GROUP%TYPE,
    gross_receipts_arg    IN   IAR_COVERAGE_ENDT_DETAIL.MONEY%TYPE,
    cov_e_arg             IN   ITEM_AT_RISK_COVERAGE_LIMIT.LIMIT%TYPE,
    no_yrs_with_agy       IN   IAR_COVERAGE_ENDT_DETAIL.NEW_CONST_AGE%TYPE,
    oil_cert_arg          IN   IAR_COVERAGE_ENDT_DETAIL.TRUST_OPREM%TYPE,
    oil_leak_arg          IN   IAR_COVERAGE_ENDT_DETAIL.TRUST_OPREM%TYPE,
    zip_code_arg          IN   NAME.POSTAL_CODE%TYPE,
    flood_zone_arg        IN   IAR_PERSONAL_DWELLING.FLOOD_ZONE%TYPE,
    non_nd_auto_policy IN varchar,
    non_nd_auto_carrier IN varchar)

     IS
        cov_list_cur   cov_elig_list;

     BEGIN
      OPEN cov_list_cur FOR
      SELECT DISTINCT CD.COVERAGE_CODE, CD.COVERAGE_DESCRIPTION, CD.PACKAGE, CD.PACKAGE_CODE, CD.FORM
        FROM VW_COVERAGE_DISPLAY CD,
  TABLE(COVERAGE_ELIG(CD.COVERAGE_CODE, form_arg, number_of_families_arg, construction_year_arg, terr_arg,
       construction_type_arg, residence_type_arg, policy_number_arg , num_rental_br_arg, roof_repl_age_arg,
       electric_amps_arg, plumbing_age_arg, plumbing_type_arg, central_age_arg, tot_val_struct_arg,
       nd_auto_pol_num_arg, nd_auto_date_arg, frz_alarm_arg, winter_plumb_arg, heat_sys_serv_arg,
       hs_pgm_arg,  ni_dob_arg, ni2_dob_arg, res_unoc_3_mon_arg, cov_a_arg, purch_date_arg, loss_free_year_arg,
       nd_com_pol_num_arg, nd_com_date_arg, state_arg, ins_score_arg, dist_to_coast_arg, loss_free_arg,
       smoke_det_arg, pol_eff_dt_arg, electric_age_arg, ibc_arg, wind_arg, agency_arg, ownership_arg,
       loc_struct_arg, num_of_emp_arg, bus_type_arg, gross_receipts_arg, cov_e_arg, no_yrs_with_agy, oil_cert_arg, oil_leak_arg, zip_code_arg, flood_zone_arg,non_nd_auto_policy,non_nd_auto_carrier)) A
       WHERE CD.STATE_ALPHA_CODE = state_arg
         AND CD.GROUP_LINE_CODE = group_line_code_arg
         AND CD.FORM = form_arg
         AND CD.COMPANY = company_arg
         AND A.P_INCLUDE_IND = 'Y'
         AND pol_eff_dt_arg >= CD.EFFECTIVE_DATE
         AND pol_eff_dt_arg <= CD.EXPIRATION_DATE
    UNION
        select iarc.coverage_code, cd.coverage_description, cd.package, cd.package_code, cd.form
          from item_at_risk iar, item_at_risk_coverage iarc, VW_COVERAGE_DISPLAY CD
         where iar.item_at_risk_id = iarc.item_at_risk_id
           and iar.policy_number = policy_number_arg
           and iarc.COVERAGE_CODE = CD.COVERAGE_CODE
           and CD.STATE_ALPHA_CODE = state_arg
           and CD.GROUP_LINE_CODE = group_line_code_arg
           and CD.FORM = form_arg
           and CD.COMPANY = company_arg
           and pol_eff_dt_arg >= CD.EFFECTIVE_DATE
           and pol_eff_dt_arg <= CD.EXPIRATION_DATE
           and iarc.coverage_code != 'PRFD';

  cov_list_arg  := cov_list_cur;

   END get_valid_coverages;

PROCEDURE get_valid_coverages_api (
    cov_list_arg          OUT  cov_elig_list,
    state_arg             IN   COVERAGE_GROUP_STATE.STATE_ALPHA_CODE%TYPE,
    group_line_code_arg   IN   COVERAGE_GROUP_STATE.GROUP_LINE_CODE%TYPE,
    form_arg              IN   COVERAGE_GROUP_STATE.FORM%TYPE,
    number_of_families_arg IN  IAR_PERSONAL_DWELLING.NUMBER_OF_FAMILIES%TYPE,
    construction_year_arg IN   IAR_PERSONAL_DWELLING.CONSTRUCTION_YEAR%TYPE,
    company_arg           IN   POLICY.ISSUE_COMPANY_CODE%TYPE,
    terr_arg              IN   IAR_PERSONAL_DWELLING.TERRITORY_CODE%TYPE,
    construction_type_arg IN   IAR_PERSONAL_DWELLING.CONSTRUCTION_CODE%TYPE,
    residence_type_arg    IN   IAR_PERSONAL_DWELLING.DWELLING_CODE%TYPE,
    policy_number_arg     IN   POLICY.POLICY_NUMBER%TYPE,
    num_rental_br_arg     IN   IAR_COVERAGE_ENDT_DETAIL.NO_RENTAL_BR%TYPE,
    roof_repl_age_arg     IN   IAR_COVERAGE_ENDT_DETAIL.ROOF_REPLACED_AGE%TYPE,
    electric_amps_arg     IN   IAR_COVERAGE_ENDT_DETAIL.ELECTRIC_AMPS%TYPE,
    plumbing_age_arg      IN   IAR_COVERAGE_ENDT_DETAIL.PLUMBING_AGE%TYPE,
    plumbing_type_arg     IN   IAR_COVERAGE_ENDT_DETAIL.PLUMBING_TYPE%TYPE,
    central_age_arg       IN   IAR_COVERAGE_ENDT_DETAIL.CENTRAL_AGE%TYPE,
    tot_val_struct_arg    IN   IAR_COVERAGE_ENDT_DETAIL.TOT_VAL_STRUCT%TYPE,
    nd_auto_pol_num_arg   IN   IAR_COVERAGE_ENDT_DETAIL.ND_AUTO_POL_NUM%TYPE,
    nd_auto_date_arg      IN   IAR_COVERAGE_ENDT_DETAIL.ND_AUTO_DATE%TYPE,
    frz_alarm_arg         IN   IAR_COVERAGE_ENDT_DETAIL.FRZ_ALARM%TYPE,
    winter_plumb_arg      IN   IAR_COVERAGE_ENDT_DETAIL.WINTERIZED_PLUMBING%TYPE,
    heat_sys_serv_arg     IN   IAR_COVERAGE_ENDT_DETAIL.ANNUAL_SERVICE_HEAT%TYPE,
    hs_pgm_arg            IN   IAR_COVERAGE_ENDT_DETAIL.HS_PGM_SUBMITTED%TYPE,
    ni_dob_arg            IN   NAME.DATE_OF_BIRTH%TYPE,
    ni2_dob_arg           IN   NAME.NI2_DOB%TYPE,
    res_unoc_3_mon_arg    IN   IAR_COVERAGE_ENDT_DETAIL.RES_UNOC_3_CON_MON%TYPE,
    cov_a_arg             IN   ITEM_AT_RISK_COVERAGE_LIMIT.LIMIT%TYPE,
    purch_date_arg        IN   IAR_PERSONAL_DWELLING.PURCHASE_DATE%TYPE,
    loss_free_year_arg    IN   IAR_COVERAGE_ENDT_DETAIL.LOSS_FREE_YEARS%TYPE,
    nd_com_pol_num_arg    IN   IAR_COVERAGE_ENDT_DETAIL.ND_COM_POL_NUM%TYPE,
    nd_com_date_arg       IN   IAR_COVERAGE_ENDT_DETAIL.ND_COM_DATE%TYPE,
    ins_score_arg         IN   UNDERWRITING_INFO.NI_CR_SCORE%TYPE,
    dist_to_coast_arg     IN   IAR_PERSONAL_DWELLING.DISTANCE_TO_COAST%TYPE,
    loss_free_arg         IN   UNDERWRITING_INFO.PRIOR_LOSSES_LST_5_YRS%TYPE,
    smoke_det_arg         IN   IAR_PERSONAL_DWELLING.NB_LOSSES%TYPE,
    pol_eff_dt_arg        IN   POLICY.POLICY_EFFECTIVE_DATE%TYPE,
    electric_age_arg      IN   IAR_COVERAGE_ENDT_DETAIL.ELECT_APARATUS%TYPE,
    ibc_arg               IN   IAR_PERSONAL_DWELLING.IBC%TYPE,
    wind_arg              IN   IAR_PERSONAL_DWELLING.WIND_ZONE%TYPE,
    agency_arg            IN   POLICY.AGENCY_NUMBER%TYPE,
    ownership_arg         IN   IAR_PERSONAL_DWELLING.IBC%TYPE,
    loc_struct_arg        IN   IAR_PERSONAL_DWELLING.IBC%TYPE,
    num_of_emp_arg        IN   IAR_PERSONAL_DWELLING.NUMBER_OF_FAMILIES%TYPE,
    bus_type_arg          IN   IAR_COVERAGE_ENDT_DETAIL.RATE_GROUP%TYPE,
    gross_receipts_arg    IN   IAR_COVERAGE_ENDT_DETAIL.MONEY%TYPE,
    cov_e_arg             IN   ITEM_AT_RISK_COVERAGE_LIMIT.LIMIT%TYPE,
    no_yrs_with_agy       IN   IAR_COVERAGE_ENDT_DETAIL.NEW_CONST_AGE%TYPE,
    oil_cert_arg          IN   IAR_COVERAGE_ENDT_DETAIL.TRUST_OPREM%TYPE,
    oil_leak_arg          IN   IAR_COVERAGE_ENDT_DETAIL.TRUST_OPREM%TYPE,
    zip_code_arg          IN   NAME.POSTAL_CODE%TYPE,
    flood_zone_arg        IN   IAR_PERSONAL_DWELLING.FLOOD_ZONE%TYPE,
    non_nd_auto_policy IN varchar,
    non_nd_auto_carrier IN varchar)

     IS
        cov_list_cur   cov_elig_list;

     BEGIN
      OPEN cov_list_cur FOR
      SELECT DISTINCT CD.COVERAGE_CODE, CD.COVERAGE_DESCRIPTION, CD.PACKAGE, CD.PACKAGE_CODE, CD.FORM
        FROM VW_COVERAGE_DISPLAY CD,
  TABLE(COVERAGE_ELIG(CD.COVERAGE_CODE, form_arg, number_of_families_arg, construction_year_arg, terr_arg,
       construction_type_arg, residence_type_arg, policy_number_arg , num_rental_br_arg, roof_repl_age_arg,
       electric_amps_arg, plumbing_age_arg, plumbing_type_arg, central_age_arg, tot_val_struct_arg,
       nd_auto_pol_num_arg, nd_auto_date_arg, frz_alarm_arg, winter_plumb_arg, heat_sys_serv_arg,
       hs_pgm_arg,  ni_dob_arg, ni2_dob_arg, res_unoc_3_mon_arg, cov_a_arg, purch_date_arg, loss_free_year_arg,
       nd_com_pol_num_arg, nd_com_date_arg, state_arg, ins_score_arg, dist_to_coast_arg, loss_free_arg,
       smoke_det_arg, pol_eff_dt_arg, electric_age_arg, ibc_arg, wind_arg, agency_arg, ownership_arg,
       loc_struct_arg, num_of_emp_arg, bus_type_arg, gross_receipts_arg, cov_e_arg, no_yrs_with_agy, oil_cert_arg, oil_leak_arg, zip_code_arg, flood_zone_arg,non_nd_auto_policy,non_nd_auto_carrier)) A
       WHERE CD.STATE_ALPHA_CODE = state_arg
         AND CD.GROUP_LINE_CODE = group_line_code_arg
         AND CD.FORM = form_arg
         AND CD.COMPANY = company_arg
         AND A.P_INCLUDE_IND = 'Y'
         AND pol_eff_dt_arg >= CD.EFFECTIVE_DATE
         AND pol_eff_dt_arg <= CD.EXPIRATION_DATE;

  cov_list_arg  := cov_list_cur;

   END get_valid_coverages_api;

END COVERAGE_ELIG_PKG;
/
