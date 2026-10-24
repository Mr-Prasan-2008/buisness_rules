\set ON_ERROR_STOP on
\echo 'Step 1/3: Applying database schema...'
\ir ../migrations/001_initial_schema.sql
\echo 'Step 2/3: Loading clean demonstration fixtures...'
\ir ../fixtures/001_seed_data.sql
\echo 'Step 3/3: Running negative SQL tests...'
\ir negative_sql_tests.sql
\echo 'SUCCESS: Schema, fixtures, and negative SQL tests completed.'
