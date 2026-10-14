-- Run in EVERY database DMS migrates, including postgres. A missing
-- pglogical extension in any one of them fails the migration job test.
CREATE EXTENSION IF NOT EXISTS pglogical;

GRANT USAGE ON SCHEMA pglogical TO PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA pglogical TO :"dms_user";

GRANT USAGE ON SCHEMA public TO :"dms_user";
GRANT SELECT ON ALL TABLES IN SCHEMA public TO :"dms_user";
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO :"dms_user";
