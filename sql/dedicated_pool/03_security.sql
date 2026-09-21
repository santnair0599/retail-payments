-- RLS + Dynamic Data Masking on the star schema, same mechanism as synapse-practice
-- Module 08, applied to real project tables this time.

CREATE SCHEMA Security;
GO

-- Row-Level Security: a regional analyst role only sees their own country's customers.
CREATE FUNCTION Security.fn_country_predicate(@Country AS VARCHAR(50))
    RETURNS TABLE
WITH SCHEMABINDING
AS
    RETURN SELECT 1 AS fn_result
    WHERE @Country = 'AE' OR IS_MEMBER('db_owner') = 1;
GO

CREATE SECURITY POLICY CustomerCountryFilter
ADD FILTER PREDICATE Security.fn_country_predicate(country)
ON dbo.dim_customer
WITH (STATE = ON);

-- Dynamic Data Masking on customer email — non-privileged users see a masked value.
ALTER TABLE dim_customer
ALTER COLUMN email ADD MASKED WITH (FUNCTION = 'email()');

-- Column-level restriction example: a reporting-only role shouldn't see raw email at all.
-- (Create the role/user first if you want to actually test this end to end.)
-- DENY SELECT ON dim_customer(email) TO [reporting_role];
