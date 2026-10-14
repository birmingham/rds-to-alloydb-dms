-- Run in the postgres database. Password comes from the DMS_PW environment
-- variable (\getenv, psql 15+), so it never appears in argv.
\getenv dms_pw DMS_PW

SELECT format('CREATE ROLE %I LOGIN', :'dms_user')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'dms_user')
\gexec

SELECT format('ALTER ROLE %I PASSWORD %L', :'dms_user', :'dms_pw')
\gexec

-- RDS's equivalent of the REPLICATION attribute.
GRANT rds_replication TO :"dms_user";
