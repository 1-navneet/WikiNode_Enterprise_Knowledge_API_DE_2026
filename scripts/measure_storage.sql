\set ON_ERROR_STOP on
-- CSV for the nine gpay tables: PostgreSQL table and index byte sizes.
COPY (
 SELECT c.relname AS table_name,
        pg_total_relation_size(c.oid) AS total_bytes,
        pg_relation_size(c.oid) AS heap_bytes,
        pg_indexes_size(c.oid) AS index_bytes
 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='gpay' AND c.relkind IN ('r','p')
 ORDER BY c.relname
) TO STDOUT WITH CSV HEADER;
