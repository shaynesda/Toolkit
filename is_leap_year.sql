CREATE OR REPLACE FUNCTION APDEV.IS_LEAP_YEAR (nYr IN NUMBER)
    RETURN NUMBER
IS
    v_day          VARCHAR2 (2);
BEGIN
    SELECT TO_CHAR (
               LAST_DAY (TO_DATE ('01-FEB-' || TO_CHAR (nYr), 'DD-MON-YYYY')),
               'DD')
    INTO v_day
    FROM DUAL;

    IF v_day = '29'
    THEN
        RETURN 1;
    ELSE
        RETURN 0;
    END IF;
END;
/
