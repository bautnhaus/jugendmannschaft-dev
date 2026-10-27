-- AP03 DEV hardening: anonymous clients have no public-table RLS policies; remove direct table grants.
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM anon;
-- The application has no legitimate need to truncate tables. RLS does not constrain TRUNCATE.
REVOKE TRUNCATE ON ALL TABLES IN SCHEMA public FROM authenticated;
