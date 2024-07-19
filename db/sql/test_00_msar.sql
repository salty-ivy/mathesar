DROP EXTENSION IF EXISTS pgtap CASCADE;
CREATE EXTENSION IF NOT EXISTS pgtap;

-- msar.drop_columns -------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION __setup_drop_columns() RETURNS SETOF TEXT AS $$
BEGIN
  CREATE TABLE atable (dodrop1 integer, dodrop2 integer, dontdrop text);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_drop_columns_oid() RETURNS SETOF TEXT AS $$
DECLARE
  rel_id oid;
BEGIN
  PERFORM __setup_drop_columns();
  rel_id := 'atable'::regclass::oid;
  PERFORM msar.drop_columns(rel_id, 1, 2);
  RETURN NEXT has_column(
    'atable', 'dontdrop', 'Keeps correct columns'
  );
  RETURN NEXT hasnt_column(
    'atable', 'dodrop1', 'Drops correct columns 1'
  );
  RETURN NEXT hasnt_column(
    'atable', 'dodrop2', 'Drops correct columns 2'
  );
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_drop_columns_ne_oid() RETURNS SETOF TEXT AS $$
BEGIN
  CREATE TABLE "12345" (bleh text, bleh2 numeric);
  PERFORM msar.drop_columns(12345, 1);
  RETURN NEXT has_column(
    '12345', 'bleh', 'Doesn''t drop columns of stupidly-named table'
  );
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_drop_columns_names() RETURNS SETOF TEXT AS $$
BEGIN
  PERFORM __setup_drop_columns();
  PERFORM msar.drop_columns('public', 'atable', 'dodrop1', 'dodrop2');
  RETURN NEXT has_column(
    'atable', 'dontdrop', 'Dropper keeps correct columns'
  );
  RETURN NEXT hasnt_column(
    'atable', 'dodrop1', 'Dropper drops correct columns 1'
  );
  RETURN NEXT hasnt_column(
    'atable', 'dodrop2', 'Dropper drops correct columns 2'
  );
END;
$$ LANGUAGE plpgsql;


-- msar.drop_table ---------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION __setup_drop_tables() RETURNS SETOF TEXT AS $$
BEGIN
  CREATE TABLE dropme (id SERIAL PRIMARY KEY, col1 integer);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION test_drop_table_oid() RETURNS SETOF TEXT AS $$
DECLARE
  rel_id oid;
BEGIN
  PERFORM __setup_drop_tables();
  rel_id := 'dropme'::regclass::oid;
  PERFORM msar.drop_table(tab_id => rel_id, cascade_ => false);
  RETURN NEXT hasnt_table('dropme', 'Drops table');
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_drop_table_oid_restricted_fkey() RETURNS SETOF TEXT AS $$
DECLARE
  rel_id oid;
BEGIN
  PERFORM __setup_drop_tables();
  rel_id := 'dropme'::regclass::oid;
  CREATE TABLE
    dependent (id SERIAL PRIMARY KEY, col1 integer REFERENCES dropme);
  RETURN NEXT throws_ok(
    format('SELECT msar.drop_table(tab_id => %s, cascade_ => false);', rel_id),
    '2BP01',
    'cannot drop table dropme because other objects depend on it',
    'Table dropper throws for dependent objects'
  );
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_drop_table_oid_cascade_fkey() RETURNS SETOF TEXT AS $$
DECLARE
  rel_id oid;
BEGIN
  PERFORM __setup_drop_tables();
  rel_id := 'dropme'::regclass::oid;
  CREATE TABLE
    dependent (id SERIAL PRIMARY KEY, col1 integer REFERENCES dropme);
  PERFORM msar.drop_table(tab_id => rel_id, cascade_ => true);
  RETURN NEXT hasnt_table('dropme', 'Drops table with dependent using CASCADE');
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_drop_table_name() RETURNS SETOF TEXT AS $$
BEGIN
  PERFORM __setup_drop_tables();
  PERFORM msar.drop_table(
    sch_name => 'public',
    tab_name => 'dropme',
    cascade_ => false,
    if_exists => false
  );
  RETURN NEXT hasnt_table('dropme', 'Drops table');
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_drop_table_name_missing_if_exists() RETURNS SETOF TEXT AS $$
BEGIN
  PERFORM __setup_drop_tables();
  PERFORM msar.drop_table(
    sch_name => 'public',
    tab_name => 'dropmenew',
    cascade_ => false,
    if_exists => true
  );
  RETURN NEXT has_table('dropme', 'Drops table with IF EXISTS');
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_drop_table_name_missing_no_if_exists() RETURNS SETOF TEXT AS $$
BEGIN
  RETURN NEXT throws_ok(
    'SELECT msar.drop_table(''public'', ''doesntexist'', false, false);',
    '42P01',
    'table "doesntexist" does not exist',
    'Table dropper throws for missing table'
  );
END;
$$ LANGUAGE plpgsql;


-- msar.build_type_text ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION test_build_type_text() RETURNS SETOF TEXT AS $$/*
Note that many type building tests are in the column adding section, to make sure the strings the
function writes are as expected, and also valid type definitions.
*/

BEGIN
  RETURN NEXT is(msar.build_type_text('{}'), 'text');
  RETURN NEXT is(msar.build_type_text(null), 'text');
  RETURN NEXT is(msar.build_type_text('{"name": "varchar"}'), 'character varying');
  CREATE DOMAIN msar.testtype AS text CHECK (value LIKE '%test');
  RETURN NEXT is(
    msar.build_type_text('{"schema": "msar", "name": "testtype"}'), 'msar.testtype'
  );
END;
$$ LANGUAGE plpgsql;


-- __msar.process_col_def_jsonb ----------------------------------------------------------------------

CREATE OR REPLACE FUNCTION test_process_col_def_jsonb() RETURNS SETOF TEXT AS $f$
BEGIN
  RETURN NEXT is(
    __msar.process_col_def_jsonb(0, '[{}, {}]'::jsonb, false),
    ARRAY[
      ('"Column 1"', 'text', null, null, false, null),
      ('"Column 2"', 'text', null, null, false, null)
    ]::__msar.col_def[],
    'Empty columns should result in defaults'
  );
  RETURN NEXT is(
    __msar.process_col_def_jsonb(0, '[{"name": "id"}]'::jsonb, false),
    null,
    'Column definition processing should ignore "id" column'
  );
  RETURN NEXT is(
    __msar.process_col_def_jsonb(0, '[{}, {}]'::jsonb, false, true),
    ARRAY[
      ('id', 'integer', true, null, true, 'Mathesar default ID column'),
      ('"Column 1"', 'text', null, null, false, null),
      ('"Column 2"', 'text', null, null, false, null)
    ]::__msar.col_def[],
    'Column definition processing add "id" column'
  );
  RETURN NEXT is(
    __msar.process_col_def_jsonb(0, '[{"description": "Some comment"}]'::jsonb, false),
    ARRAY[
      ('"Column 1"', 'text', null, null, false, '''Some comment''')
    ]::__msar.col_def[],
    'Comments should be sanitized'
  );
END;
$f$ LANGUAGE plpgsql;


-- msar.add_columns --------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION __setup_add_columns() RETURNS SETOF TEXT AS $$
BEGIN
  CREATE TABLE add_col_testable (id serial primary key, col1 integer, col2 varchar);
END;
$$ LANGUAGE plpgsql;


-- TODO: Figure out a way to parameterize these
CREATE OR REPLACE FUNCTION test_add_columns_fullspec_text() RETURNS SETOF TEXT AS $f$
DECLARE
  col_create_arr jsonb := $j$[
      {"name": "tcol", "type": {"name": "text"}, "not_null": true, "default": "my super default"}
    ]$j$;
BEGIN
  PERFORM __setup_add_columns();
  RETURN NEXT is(
    msar.add_columns('add_col_testable'::regclass::oid, col_create_arr), '{4}'::smallint[]
  );
  RETURN NEXT col_not_null('add_col_testable', 'tcol');
  RETURN NEXT col_type_is('add_col_testable', 'tcol', 'text');
  RETURN NEXT col_default_is('add_col_testable', 'tcol', 'my super default');
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_columns_minspec_text() RETURNS SETOF TEXT AS $f$
/*
This tests the default settings. When not given, the defautl column should be nullable and have no
default value. The name should be "Column <n>", where <n> is the attnum of the added column.
*/
DECLARE
  col_create_arr jsonb := '[{"type": {"name": "text"}}]';
BEGIN
  PERFORM __setup_add_columns();
  PERFORM msar.add_columns('add_col_testable'::regclass::oid, col_create_arr);
  RETURN NEXT col_is_null('add_col_testable', 'Column 4');
  RETURN NEXT col_type_is('add_col_testable', 'Column 4', 'text');
  RETURN NEXT col_hasnt_default('add_col_testable', 'Column 4');
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_columns_comment() RETURNS SETOF TEXT AS $f$
DECLARE
  col_name text := 'tcol';
  description text := 'Some; comment with a semicolon';
  tab_id integer;
  col_id integer;
  col_create_arr jsonb;
BEGIN
  PERFORM __setup_add_columns();
  tab_id := 'add_col_testable'::regclass::oid;
  col_create_arr := format('[{"name": "%s", "description": "%s"}]', col_name, description);
  PERFORM msar.add_columns(tab_id, col_create_arr);
  col_id := msar.get_attnum(tab_id, col_name);
  RETURN NEXT is(
    msar.col_description(tab_id, col_id),
    description
  );
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_columns_multi_default_name() RETURNS SETOF TEXT AS $f$
/*
This tests the default settings. When not given, the defautl column should be nullable and have no
default value. The name should be "Column <n>", where <n> is the attnum of the added column.
*/
DECLARE
  col_create_arr jsonb := '[{"type": {"name": "text"}}, {"type": {"name": "numeric"}}]';
BEGIN
  PERFORM __setup_add_columns();
  RETURN NEXT is(
    msar.add_columns('add_col_testable'::regclass::oid, col_create_arr), '{4, 5}'::smallint[]
  );
  RETURN NEXT col_type_is('add_col_testable', 'Column 4', 'text');
  RETURN NEXT col_type_is('add_col_testable', 'Column 5', 'numeric');
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_columns_numeric_def() RETURNS SETOF TEXT AS $f$
DECLARE
  col_create_arr jsonb := '[{"type": {"name": "numeric"}, "default": 3.14159}]';
BEGIN
  PERFORM __setup_add_columns();
  PERFORM msar.add_columns('add_col_testable'::regclass::oid, col_create_arr);
  RETURN NEXT col_type_is('add_col_testable', 'Column 4', 'numeric');
  RETURN NEXT col_default_is('add_col_testable', 'Column 4', 3.14159);
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_columns_numeric_prec() RETURNS SETOF TEXT AS $f$
DECLARE
  col_create_arr jsonb := '[{"type": {"name": "numeric", "options": {"precision": 3}}}]';
BEGIN
  PERFORM __setup_add_columns();
  PERFORM msar.add_columns('add_col_testable'::regclass::oid, col_create_arr);
  RETURN NEXT col_type_is('add_col_testable', 'Column 4', 'numeric(3,0)');
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_columns_numeric_prec_scale() RETURNS SETOF TEXT AS $f$
DECLARE
  col_create_arr jsonb := $j$[
    {"type": {"name": "numeric", "options": {"precision": 3, "scale": 2}}}
  ]$j$;
BEGIN
  PERFORM __setup_add_columns();
  PERFORM msar.add_columns('add_col_testable'::regclass::oid, col_create_arr);
  RETURN NEXT col_type_is('add_col_testable', 'Column 4', 'numeric(3,2)');
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_columns_caps_numeric() RETURNS SETOF TEXT AS $f$
DECLARE
  col_create_arr jsonb := '[{"type": {"name": "NUMERIC"}}]';
BEGIN
  PERFORM __setup_add_columns();
  PERFORM msar.add_columns('add_col_testable'::regclass::oid, col_create_arr);
  RETURN NEXT col_type_is('add_col_testable', 'Column 4', 'numeric');
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_columns_varchar_length() RETURNS SETOF TEXT AS $f$
DECLARE
  col_create_arr jsonb := '[{"type": {"name": "varchar", "options": {"length": 128}}}]';
BEGIN
  PERFORM __setup_add_columns();
  PERFORM msar.add_columns('add_col_testable'::regclass::oid, col_create_arr);
  RETURN NEXT col_type_is('add_col_testable', 'Column 4', 'character varying(128)');
END;
$f$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION test_add_columns_interval_precision() RETURNS SETOF TEXT AS $f$
DECLARE
  col_create_arr jsonb := '[{"type": {"name": "interval", "options": {"precision": 6}}}]';
BEGIN
  PERFORM __setup_add_columns();
  PERFORM msar.add_columns('add_col_testable'::regclass::oid, col_create_arr);
  RETURN NEXT col_type_is('add_col_testable', 'Column 4', 'interval(6)');
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_columns_interval_fields() RETURNS SETOF TEXT AS $f$
DECLARE
  col_create_arr jsonb := '[{"type": {"name": "interval", "options": {"fields": "year"}}}]';
BEGIN
  PERFORM __setup_add_columns();
  PERFORM msar.add_columns('add_col_testable'::regclass::oid, col_create_arr);
  RETURN NEXT col_type_is('add_col_testable', 'Column 4', 'interval year');
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_columns_interval_fields_prec() RETURNS SETOF TEXT AS $f$
DECLARE
  col_create_arr jsonb := $j$
    [{"type": {"name": "interval", "options": {"fields": "second", "precision": 3}}}]
  $j$;
BEGIN
  PERFORM __setup_add_columns();
  PERFORM msar.add_columns('add_col_testable'::regclass::oid, col_create_arr);
  RETURN NEXT col_type_is('add_col_testable', 'Column 4', 'interval second(3)');
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_columns_timestamp_prec() RETURNS SETOF TEXT AS $f$
DECLARE
  col_create_arr jsonb := $j$
    [{"type": {"name": "timestamp", "options": {"precision": 3}}}]
  $j$;
BEGIN
  PERFORM __setup_add_columns();
  PERFORM msar.add_columns('add_col_testable'::regclass::oid, col_create_arr);
  RETURN NEXT col_type_is('add_col_testable', 'Column 4', 'timestamp(3) without time zone');
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_columns_timestamp_raw_default() RETURNS SETOF TEXT AS $f$
/*
This test will fail if the default is being sanitized, but will succeed if it's not.
*/
DECLARE
  col_create_arr jsonb := '[{"type": {"name": "timestamp"}, "default": "now()::timestamp"}]';
BEGIN
  PERFORM __setup_add_columns();
  PERFORM msar.add_columns('add_col_testable'::regclass::oid, col_create_arr, raw_default => true);
  RETURN NEXT col_type_is('add_col_testable', 'Column 4', 'timestamp without time zone');
  RETURN NEXT col_default_is(
    'add_col_testable', 'Column 4', '(now())::timestamp without time zone'
  );
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_columns_sanitize_default() RETURNS SETOF TEXT AS $f$
/*
This test will succeed if the default is being sanitized, but will fail if it's not.

It's important to check that we're careful with SQL submitted from python.
*/
DECLARE
  col_create_arr jsonb := $j$
    [{"type": {"name": "text"}, "default": "null; drop table add_col_testable"}]
  $j$;
BEGIN
  PERFORM __setup_add_columns();
  PERFORM msar.add_columns('add_col_testable'::regclass::oid, col_create_arr, raw_default => false);
  RETURN NEXT has_table('add_col_testable');
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_columns_errors() RETURNS SETOF TEXT AS $f$
BEGIN
  PERFORM __setup_add_columns();
  RETURN NEXT throws_ok(
    format(
      'SELECT msar.add_columns(tab_id => %s, col_defs => ''%s'');',
      'add_col_testable'::regclass::oid,
      '[{"type": {"name": "taxt"}}]'::jsonb
    ),
    '42704',
    'type "taxt" does not exist'
  );
  RETURN NEXT CASE WHEN pg_version_num() < 150000
    THEN throws_ok(
      format(
        'SELECT msar.add_columns(tab_id => %s, col_defs => ''%s'');',
        'add_col_testable'::regclass::oid,
        '[{"type": {"name": "numeric", "options": {"scale": 23, "precision": 3}}}]'::jsonb
      ),
      '22023',
      'NUMERIC scale 23 must be between 0 and precision 3'
    )
    ELSE skip('Numeric scale can be negative or greater than precision as of v15')
  END;
END;
$f$ LANGUAGE plpgsql;


-- msar.copy_column --------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION __setup_copy_column() RETURNS SETOF TEXT AS $$
BEGIN
  CREATE TABLE copy_coltest (
    id SERIAL PRIMARY KEY,
    col1 varchar,
    col2 varchar NOT NULL,
    col3 numeric(5, 3) DEFAULT 5,
    col4 timestamp without time zone DEFAULT NOW(),
    col5 timestamp without time zone NOT NULL DEFAULT NOW(),
    col6 interval second(3),
    "col space" varchar
  );
  ALTER TABLE copy_coltest ADD UNIQUE (col1, col2);
  INSERT INTO copy_coltest VALUES
    (DEFAULT, 'abc', 'def', 5.234, '1999-01-08 04:05:06', '1999-01-09 04:05:06', '4:05:06', 'ghi'),
    (DEFAULT, 'jkl', 'mno', null, null, '1999-02-08 04:05:06', '3 4:05:07', 'pqr'),
    (DEFAULT, null,  'stu', DEFAULT, DEFAULT, DEFAULT, null, 'vwx')
  ;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_copy_column_copies_unique() RETURNS SETOF TEXT AS $f$
BEGIN
  PERFORM __setup_copy_column();
  PERFORM msar.copy_column(
    'copy_coltest'::regclass::oid, 2::smallint, 'col1 supercopy', true, true
  );
  RETURN NEXT col_type_is('copy_coltest', 'col1 supercopy', 'character varying');
  RETURN NEXT col_is_null('copy_coltest', 'col1 supercopy');
  RETURN NEXT col_is_unique('copy_coltest', ARRAY['col1', 'col2']);
  RETURN NEXT col_is_unique('copy_coltest', ARRAY['col1 supercopy', 'col2']);
  RETURN NEXT results_eq(
    'SELECT "col1 supercopy" FROM copy_coltest ORDER BY id',
    $v$VALUES ('abc'::varchar), ('jkl'::varchar), (null)$v$
  );
  RETURN NEXT lives_ok(
    $u$UPDATE copy_coltest SET "col1 supercopy"='abc' WHERE "col1 supercopy"='jkl'$u$,
    'Copied col should not have a single column unique constraint'
  );
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_copy_column_copies_unique_and_nnull() RETURNS SETOF TEXT AS $f$
BEGIN
  PERFORM __setup_copy_column();
  PERFORM msar.copy_column(
    'copy_coltest'::regclass::oid, 3::smallint, null, true, true
  );
  RETURN NEXT col_type_is('copy_coltest', 'col2 1', 'character varying');
  RETURN NEXT col_not_null('copy_coltest', 'col2 1');
  RETURN NEXT col_is_unique('copy_coltest', ARRAY['col1', 'col2']);
  RETURN NEXT col_is_unique('copy_coltest', ARRAY['col1', 'col2 1']);
  RETURN NEXT results_eq(
    'SELECT "col2 1" FROM copy_coltest',
    $v$VALUES ('def'::varchar), ('mno'::varchar), ('stu'::varchar)$v$
  );
  RETURN NEXT lives_ok(
    $u$UPDATE copy_coltest SET "col2 1"='def' WHERE "col2 1"='mno'$u$,
    'Copied col should not have a single column unique constraint'
  );
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_copy_column_false_copy_data_and_con() RETURNS SETOF TEXT AS $f$
BEGIN
  PERFORM __setup_copy_column();
  PERFORM msar.copy_column(
    'copy_coltest'::regclass::oid, 3::smallint, null, false, false
  );
  RETURN NEXT col_type_is('copy_coltest', 'col2 1', 'character varying');
  RETURN NEXT col_is_null('copy_coltest', 'col2 1');
  RETURN NEXT col_is_unique('copy_coltest', ARRAY['col1', 'col2']);
  RETURN NEXT results_eq(
    'SELECT "col2 1" FROM copy_coltest',
    $v$VALUES (null::varchar), (null::varchar), (null::varchar)$v$
  );
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_copy_column_num_options_static_default() RETURNS SETOF TEXT AS $f$
BEGIN
  PERFORM __setup_copy_column();
  PERFORM msar.copy_column(
    'copy_coltest'::regclass::oid, 4::smallint, null, true, false
  );
  RETURN NEXT col_type_is('copy_coltest', 'col3 1', 'numeric(5,3)');
  RETURN NEXT col_is_null('copy_coltest', 'col3 1');
  RETURN NEXT col_default_is('copy_coltest', 'col3 1', '5');
  RETURN NEXT results_eq(
    'SELECT "col3 1" FROM copy_coltest',
    $v$VALUES (5.234), (null), (5)$v$
  );
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_copy_column_nullable_dynamic_default() RETURNS SETOF TEXT AS $f$
BEGIN
  PERFORM __setup_copy_column();
  PERFORM msar.copy_column(
    'copy_coltest'::regclass::oid, 5::smallint, null, true, false
  );
  RETURN NEXT col_type_is('copy_coltest', 'col4 1', 'timestamp without time zone');
  RETURN NEXT col_is_null('copy_coltest', 'col4 1');
  RETURN NEXT col_default_is('copy_coltest', 'col4 1', 'now()');
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_copy_column_non_null_dynamic_default() RETURNS SETOF TEXT AS $f$
BEGIN
  PERFORM __setup_copy_column();
  PERFORM msar.copy_column(
    'copy_coltest'::regclass::oid, 6::smallint, null, true, true
  );
  RETURN NEXT col_type_is('copy_coltest', 'col5 1', 'timestamp without time zone');
  RETURN NEXT col_not_null('copy_coltest', 'col5 1');
  RETURN NEXT col_default_is('copy_coltest', 'col5 1', 'now()');
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_copy_column_interval_notation() RETURNS SETOF TEXT AS $f$
BEGIN
  PERFORM __setup_copy_column();
  PERFORM msar.copy_column(
    'copy_coltest'::regclass::oid, 7::smallint, null, false, false
  );
  RETURN NEXT col_type_is('copy_coltest', 'col6 1', 'interval second(3)');
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_copy_column_space_name() RETURNS SETOF TEXT AS $f$
BEGIN
  PERFORM __setup_copy_column();
  PERFORM msar.copy_column(
    'copy_coltest'::regclass::oid, 8::smallint, null, false, false
  );
  RETURN NEXT col_type_is('copy_coltest', 'col space 1', 'character varying');
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_copy_column_pkey() RETURNS SETOF TEXT AS $f$
BEGIN
  PERFORM __setup_copy_column();
  PERFORM msar.copy_column(
    'copy_coltest'::regclass::oid, 1::smallint, null, true, true
  );
  RETURN NEXT col_type_is('copy_coltest', 'id 1', 'integer');
  RETURN NEXT col_not_null('copy_coltest', 'id 1');
  RETURN NEXT col_default_is(
    'copy_coltest', 'id 1', $d$nextval('copy_coltest_id_seq'::regclass)$d$
  );
  RETURN NEXT col_is_pk('copy_coltest', 'id');
  RETURN NEXT col_isnt_pk('copy_coltest', 'id 1');
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_copy_column_increment_name() RETURNS SETOF TEXT AS $f$
BEGIN
  PERFORM __setup_copy_column();
  PERFORM msar.copy_column(
    'copy_coltest'::regclass::oid, 2::smallint, null, true, true
  );
  RETURN NEXT has_column('copy_coltest', 'col1 1');
  PERFORM msar.copy_column(
    'copy_coltest'::regclass::oid, 2::smallint, null, true, true
  );
  RETURN NEXT has_column('copy_coltest', 'col1 2');
END;
$f$ LANGUAGE plpgsql;

-- msar.add_constraints ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION __setup_add_pkey() RETURNS SETOF TEXT AS $$
BEGIN
  CREATE TABLE add_pkeytest (col1 serial, col2 serial, col3 text);
  INSERT INTO add_pkeytest (col1, col2, col3) VALUES
    (DEFAULT, DEFAULT, 'abc'),
    (DEFAULT, DEFAULT, 'def'),
    (DEFAULT, DEFAULT, 'abc'),
    (DEFAULT, DEFAULT, 'def'),
    (DEFAULT, DEFAULT, 'abc'),
    (DEFAULT, DEFAULT, 'def'),
    (DEFAULT, DEFAULT, 'abc');
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_constraint_pkey_id_fullspec() RETURNS SETOF TEXT AS $f$
DECLARE
  con_create_arr jsonb := $j$[
    {"name": "mysuperkey", "type": "p", "columns": [1], "deferrable": true}
  ]$j$;
  created_name text;
  deferrable_ boolean;
BEGIN
  PERFORM __setup_add_pkey();
  PERFORM msar.add_constraints('add_pkeytest'::regclass::oid, con_create_arr);
  RETURN NEXT col_is_pk('add_pkeytest', 'col1');
  created_name := conname FROM pg_constraint
    WHERE conrelid='add_pkeytest'::regclass::oid AND conkey='{1}';
  RETURN NEXT is(created_name, 'mysuperkey');
  deferrable_ := condeferrable FROM pg_constraint WHERE conname='mysuperkey';
  RETURN NEXT is(deferrable_, true);
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_constraint_pkey_id_defname() RETURNS SETOF TEXT AS $f$
DECLARE
  con_create_arr jsonb := '[{"type": "p", "columns": [1]}]';
  created_name text;
BEGIN
  PERFORM __setup_add_pkey();
  PERFORM msar.add_constraints('add_pkeytest'::regclass::oid, con_create_arr);
  RETURN NEXT col_is_pk('add_pkeytest', 'col1');
  created_name := conname FROM pg_constraint
    WHERE conrelid='add_pkeytest'::regclass::oid AND conkey='{1}';
  RETURN NEXT is(created_name, 'add_pkeytest_pkey');
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_constraint_pkey_id_multicol() RETURNS SETOF TEXT AS $f$
DECLARE
  con_create_arr jsonb := '[{"type": "p", "columns": [1, 2]}]';
  created_name text;
BEGIN
  PERFORM __setup_add_pkey();
  PERFORM msar.add_constraints('add_pkeytest'::regclass::oid, con_create_arr);
  RETURN NEXT col_is_pk('add_pkeytest', ARRAY['col1', 'col2']);
  created_name := conname FROM pg_constraint
    WHERE conrelid='add_pkeytest'::regclass::oid AND conkey='{1, 2}';
  RETURN NEXT is(created_name, 'add_pkeytest_pkey');
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_constraint_pkey_tab_name_singlecol() RETURNS SETOF TEXT AS $f$
DECLARE
  con_create_arr jsonb := '[{"type": "p", "columns": [1]}]';
BEGIN
  PERFORM __setup_add_pkey();
  PERFORM msar.add_constraints('public', 'add_pkeytest', con_create_arr);
  RETURN NEXT col_is_pk('add_pkeytest', 'col1');
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_constraint_pkey_col_name_singlecol() RETURNS SETOF TEXT AS $f$
DECLARE
  con_create_arr jsonb := '[{"type": "p", "columns": ["col1"]}]';
BEGIN
  PERFORM __setup_add_pkey();
  PERFORM msar.add_constraints('add_pkeytest'::regclass::oid, con_create_arr);
  RETURN NEXT col_is_pk('add_pkeytest', 'col1');
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_constraint_pkey_col_name_multicol() RETURNS SETOF TEXT AS $f$
DECLARE
  con_create_arr jsonb := '[{"type": "p", "columns": ["col1", "col2"]}]';
BEGIN
  PERFORM __setup_add_pkey();
  PERFORM msar.add_constraints('add_pkeytest'::regclass::oid, con_create_arr);
  RETURN NEXT col_is_pk('add_pkeytest', ARRAY['col1', 'col2']);
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_constraint_pkey_col_mix_multicol() RETURNS SETOF TEXT AS $f$
DECLARE
  con_create_arr jsonb := '[{"type": "p", "columns": [1, "col2"]}]';
BEGIN
  PERFORM __setup_add_pkey();
  PERFORM msar.add_constraints('add_pkeytest'::regclass::oid, con_create_arr);
  RETURN NEXT col_is_pk('add_pkeytest', ARRAY['col1', 'col2']);
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION __setup_add_fkey() RETURNS SETOF TEXT AS $$
BEGIN
  CREATE TABLE add_fk_users (id serial primary key, fname TEXT, lname TEXT, phoneno TEXT);
  INSERT INTO add_fk_users (fname, lname, phoneno) VALUES
    ('alice', 'smith', '123 4567'),
    ('bob', 'jones', '234 5678'),
    ('eve', 'smith', '345 6789');
  CREATE TABLE add_fk_comments (id serial primary key, user_id integer, comment text);
  INSERT INTO add_fk_comments (user_id, comment) VALUES
    (1, 'aslfkjasfdlkjasdfl'),
    (2, 'aslfkjasfdlkjasfl'),
    (3, 'aslfkjasfdlkjsfl'),
    (1, 'aslfkjasfdlkasdfl'),
    (2, 'aslfkjasfkjasdfl'),
    (2, 'aslfkjasflkjasdfl'),
    (3, 'aslfkjasfdjasdfl'),
    (1, 'aslfkjasfkjasdfl'),
    (1, 'fkjasfkjasdfl');
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_constraint_fkey_id_fullspec() RETURNS SETOF TEXT AS $f$
DECLARE
  con_create_arr jsonb;
BEGIN
  PERFORM __setup_add_fkey();
  con_create_arr := format(
    $j$[
      {
        "name": "superfkey",
        "type": "f",
        "columns": [2],
        "fkey_relation_id": %s,
        "fkey_columns": [1],
        "fkey_update_action": "a",
        "fkey_delete_action": "a",
        "fkey_match_type": "f"
      }
    ]$j$, 'add_fk_users'::regclass::oid
  );
  PERFORM msar.add_constraints('add_fk_comments'::regclass::oid, con_create_arr);
  RETURN NEXT fk_ok(
    'public', 'add_fk_comments', 'user_id', 'public', 'add_fk_users', 'id'
  );
  RETURN NEXT results_eq(
    $h$
    SELECT conname, confupdtype, confdeltype, confmatchtype
    FROM pg_constraint WHERE conname='superfkey'
    $h$,
    $w$VALUES ('superfkey'::name, 'a'::"char", 'a'::"char", 'f'::"char")$w$
  );
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION fkey_options_eq("char", "char", "char") RETURNS TEXT AS $f$
DECLARE
  con_create_arr jsonb;
BEGIN
  PERFORM __setup_add_fkey();
  con_create_arr := format(
    $j$[
      {
        "name": "superfkey",
        "type": "f",
        "columns": [2],
        "fkey_relation_id": %s,
        "fkey_update_action": "%s",
        "fkey_delete_action": "%s",
        "fkey_match_type": "%s"
      }
    ]$j$,
    'add_fk_users'::regclass::oid, $1, $2, $3
  );
  PERFORM msar.add_constraints('add_fk_comments'::regclass::oid, con_create_arr);
  RETURN results_eq(
    $h$
    SELECT conname, confupdtype, confdeltype, confmatchtype
    FROM pg_constraint WHERE conname='superfkey'
    $h$,
    format(
      $w$VALUES ('superfkey'::name, '%s'::"char", '%s'::"char", '%s'::"char")$w$,
      $1, $2, $3
    ),
    format('Should have confupdtype %s, confdeltype %s, and confmatchtype %s', $1, $2, $3)
  );
END;
$f$ LANGUAGE plpgsql;


-- Options for fkey delete, update action and match type
-- a = no action, r = restrict, c = cascade, n = set null, d = set default
-- f = full, s = simple
-- Note that partial match is not implemented.


CREATE OR REPLACE FUNCTION test_add_constraints_fkey_opts_aas() RETURNS SETOF TEXT AS $f$
BEGIN
  PERFORM fkey_options_eq('a', 'a', 's');
  RETURN NEXT fk_ok(
    'public', 'add_fk_comments', 'user_id', 'public', 'add_fk_users', 'id'
  );
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_constraints_fkey_opts_arf() RETURNS SETOF TEXT AS $f$
BEGIN
  PERFORM fkey_options_eq('a', 'r', 'f');
  RETURN NEXT fk_ok(
    'public', 'add_fk_comments', 'user_id', 'public', 'add_fk_users', 'id'
  );
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_constraints_fkey_opts_rrf() RETURNS SETOF TEXT AS $f$
BEGIN
  PERFORM fkey_options_eq('r', 'r', 'f');
  RETURN NEXT fk_ok(
    'public', 'add_fk_comments', 'user_id', 'public', 'add_fk_users', 'id'
  );
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_constraints_fkey_opts_rrf() RETURNS SETOF TEXT AS $f$
BEGIN
  PERFORM fkey_options_eq('r', 'r', 'f');
  RETURN NEXT fk_ok(
    'public', 'add_fk_comments', 'user_id', 'public', 'add_fk_users', 'id'
  );
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_constraints_fkey_opts_ccf() RETURNS SETOF TEXT AS $f$
BEGIN
  PERFORM fkey_options_eq('c', 'c', 'f');
  RETURN NEXT fk_ok(
    'public', 'add_fk_comments', 'user_id', 'public', 'add_fk_users', 'id'
  );
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_constraints_fkey_opts_nnf() RETURNS SETOF TEXT AS $f$
BEGIN
  PERFORM fkey_options_eq('n', 'n', 'f');
  RETURN NEXT fk_ok(
    'public', 'add_fk_comments', 'user_id', 'public', 'add_fk_users', 'id'
  );
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_constraints_fkey_opts_ddf() RETURNS SETOF TEXT AS $f$
BEGIN
  PERFORM fkey_options_eq('d', 'd', 'f');
  RETURN NEXT fk_ok(
    'public', 'add_fk_comments', 'user_id', 'public', 'add_fk_users', 'id'
  );
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION __setup_add_unique() RETURNS SETOF TEXT AS $$
BEGIN
  CREATE TABLE add_unique_con (id serial primary key, col1 integer, col2 integer, col3 integer);
  INSERT INTO add_unique_con (col1, col2, col3) VALUES
    (1, 1, 1),
    (2, 2, 3),
    (3, 3, 3);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION  test_add_constraints_unique_single() RETURNS SETOF TEXT AS $f$
DECLARE
  con_create_arr jsonb := '[{"name": "myuniqcons", "type": "u", "columns": [2]}]';
BEGIN
  PERFORM __setup_add_unique();
  PERFORM msar.add_constraints('add_unique_con'::regclass::oid, con_create_arr);
  RETURN NEXT col_is_unique('add_unique_con', ARRAY['col1']);
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION  test_add_constraints_unique_multicol() RETURNS SETOF TEXT AS $f$
DECLARE
  con_create_arr jsonb := '[{"name": "myuniqcons", "type": "u", "columns": [2, 3]}]';
BEGIN
  PERFORM __setup_add_unique();
  PERFORM msar.add_constraints('add_unique_con'::regclass::oid, con_create_arr);
  RETURN NEXT col_is_unique('add_unique_con', ARRAY['col1', 'col2']);
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_constraint_duplicate_name() RETURNS SETOF TEXT AS $f$
DECLARE
  con_create_arr jsonb := '[{"name": "myuniqcons", "type": "u", "columns": [2]}]';
  con_create_arr2 jsonb := '[{"name": "myuniqcons", "type": "u", "columns": [3]}]';
BEGIN
  PERFORM __setup_add_unique();
  PERFORM msar.add_constraints('add_unique_con'::regclass::oid, con_create_arr);
  RETURN NEXT throws_ok(
    format(
      'SELECT msar.add_constraints(%s, ''%s'');', 'add_unique_con'::regclass::oid, con_create_arr
    ),
    '42P07',
    'relation "myuniqcons" already exists',
    'Throws error for duplicate constraint name'
  );
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION __setup_copy_unique() RETURNS SETOF TEXT AS $$
BEGIN
  CREATE TABLE copy_unique_con
    (id serial primary key, col1 integer, col2 integer, col3 integer, col4 integer);
  ALTER TABLE copy_unique_con ADD CONSTRAINT olduniqcon UNIQUE (col1, col2, col3);
  INSERT INTO copy_unique_con (col1, col2, col3, col4) VALUES
    (1, 2, 5, 9),
    (2, 3, 6, 0),
    (3, 4, 8, 1);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_copy_constraint() RETURNS SETOF TEXT AS $f$
DECLARE
  orig_oid oid;
BEGIN
  PERFORM __setup_copy_unique();
  orig_oid := oid
    FROM pg_constraint
    WHERE conrelid='copy_unique_con'::regclass::oid AND conname='olduniqcon';
  PERFORM msar.copy_constraint(orig_oid, 4::smallint, 5::smallint);
  RETURN NEXT col_is_unique('copy_unique_con', ARRAY['col1', 'col2', 'col4']);
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_constraint_errors() RETURNS SETOF TEXT AS $f$
DECLARE
  con_create_arr jsonb := '[{"type": "p", "columns": [7]}]'::jsonb;
BEGIN
  PERFORM __setup_add_pkey();
  RETURN NEXT throws_ok(
    format(
      'SELECT msar.add_constraints(%s, ''%s'');',
      'add_pkeytest'::regclass::oid,
      '[{"type": "p", "columns": [7]}]'::jsonb
    ),
    '42601',
    'syntax error at end of input',
    'Throws error for nonexistent attnum'
  );
  RETURN NEXT throws_ok(
    format(
      'SELECT msar.add_constraints(%s, ''%s'');', 234, '[{"type": "p", "columns": [1]}]'::jsonb
    ),
    '42601',
    'syntax error at or near "234"',
    'Throws error for nonexistent table ID'
  );
  RETURN NEXT throws_ok(
    format(
      'SELECT msar.add_constraints(%s, ''%s'');',
      'add_pkeytest'::regclass::oid,
      '[{"type": "k", "columns": [1]}]'::jsonb
    ),
    '42601',
    'syntax error at end of input',
    'Throws error for nonexistent constraint type'
  );
  RETURN NEXT throws_ok(
    format(
      'SELECT msar.add_constraints(%s, ''%s'');',
      'add_pkeytest'::regclass::oid,
      '[{"type": "p", "columns": [1, "col1"]}]'::jsonb
    ),
    '42701',
    'column "col1" appears twice in primary key constraint',
    'Throws error for nonexistent duplicate pkey col'
  );
END;
$f$ LANGUAGE plpgsql;


-- msar.drop_constraint ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION __setup_drop_constraint() RETURNS SETOF TEXT AS $$
BEGIN
  CREATE TABLE category(
    id serial primary key,
    item_category text,
    CONSTRAINT uq_cat UNIQUE(item_category)
  );
  CREATE TABLE orders (
    id serial primary key,
    item_name text,
    price integer,
    category_id integer,
    CONSTRAINT fk_cat FOREIGN KEY(category_id) REFERENCES category(id)
  );
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_drop_constraint() RETURNS SETOF TEXT AS $$
BEGIN
  PERFORM __setup_drop_constraint();
  PERFORM msar.drop_constraint(
    sch_name => 'public',
    tab_name => 'category',
    con_name => 'uq_cat'
  );
  PERFORM msar.drop_constraint(
    sch_name => 'public',
    tab_name => 'orders',
    con_name => 'fk_cat'
  );
  /* There isn't a col_isnt_unique function in pgTAP so we are improvising
  by adding 2 same values here.*/
  INSERT INTO category(item_category) VALUES ('tech'),('tech');
  RETURN NEXT col_isnt_fk('orders', 'category_id');
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_drop_constraint_using_oid() RETURNS SETOF TEXT AS $$
DECLARE
  uq_cat_oid oid;
  fk_cat_oid oid;
BEGIN
  PERFORM __setup_drop_constraint();
  uq_cat_oid := oid FROM pg_constraint WHERE conname='uq_cat';
  fk_cat_oid := oid FROM pg_constraint WHERE conname='fk_cat';
  PERFORM msar.drop_constraint(
    tab_id => 'category'::regclass::oid,
    con_id => uq_cat_oid
  );
  PERFORM msar.drop_constraint(
    tab_id => 'orders'::regclass::oid,
    con_id => fk_cat_oid
  );
  /* There isn't a col_isnt_unique function in pgTAP so we are improvising
  by adding 2 same values here.*/
  INSERT INTO category(item_category) VALUES ('tech'),('tech');
  RETURN NEXT col_isnt_fk('orders', 'category_id');
END;
$$ LANGUAGE plpgsql;


-- msar.create_link -------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION __setup_link_tables() RETURNS SETOF TEXT AS $$
BEGIN
  CREATE TABLE actors (id SERIAL PRIMARY KEY, actor_name text);
  INSERT INTO actors(actor_name) VALUES 
  ('Cillian Murphy'),
  ('Leonardo DiCaprio'),
  ('Margot Robbie'),
  ('Ryan Gosling'),
  ('Ana de Armas'); 
  CREATE TABLE movies (id SERIAL PRIMARY KEY, movie_name text);
  INSERT INTO movies(movie_name) VALUES
  ('The Wolf of Wall Street'),
  ('Inception'),
  ('Oppenheimer'),
  ('Barbie'),
  ('Blade Runner 2049');
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_create_many_to_one_link() RETURNS SETOF TEXT AS $$
BEGIN
  PERFORM __setup_link_tables();
  PERFORM msar.create_many_to_one_link(
    frel_id => 'actors'::regclass::oid,
    rel_id => 'movies'::regclass::oid,
    col_name => 'act_id'
  );
  RETURN NEXT has_column('movies', 'act_id');
  RETURN NEXT col_type_is('movies', 'act_id', 'integer');
  RETURN NEXT col_is_fk('movies', 'act_id');
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_create_one_to_one_link() RETURNS SETOF TEXT AS $$
BEGIN
  PERFORM __setup_link_tables();
  PERFORM msar.create_many_to_one_link(
    frel_id => 'actors'::regclass::oid,
    rel_id => 'movies'::regclass::oid,
    col_name => 'act_id',
    unique_link => true
  );
  RETURN NEXT has_column('movies', 'act_id');
  RETURN NEXT col_type_is('movies', 'act_id', 'integer');
  RETURN NEXT col_is_fk('movies', 'act_id');
  RETURN NEXT col_is_unique('movies', 'act_id');
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_create_many_to_many_link() RETURNS SETOF TEXT AS $$
BEGIN
  PERFORM __setup_link_tables();
  PERFORM msar.create_many_to_many_link(
    sch_id => 'public'::regnamespace::oid,
    tab_name => 'movies_actors',
    from_rel_ids => '{}'::oid[] || 'movies'::regclass::oid || 'actors'::regclass::oid,
    col_names => '{"movie_id", "actor_id"}'::text[]
  );
  RETURN NEXT has_table('public'::name, 'movies_actors'::name);
  RETURN NEXT has_column('movies_actors', 'movie_id');
  RETURN NEXT col_type_is('movies_actors', 'movie_id', 'integer');
  RETURN NEXT col_is_fk('movies_actors', 'movie_id');
  RETURN NEXT has_column('movies_actors', 'actor_id');
  RETURN NEXT col_type_is('movies_actors', 'actor_id', 'integer');
  RETURN NEXT col_is_fk('movies_actors', 'actor_id');
END;
$$ LANGUAGE plpgsql;


-- msar.schema_ddl --------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION test_create_schema_without_description() RETURNS SETOF TEXT AS $$
DECLARE sch_oid oid;
BEGIN
  SELECT msar.create_schema('foo bar') INTO sch_oid;
  RETURN NEXT has_schema('foo bar');
  RETURN NEXT is(sch_oid, msar.get_schema_oid('foo bar'));
  RETURN NEXT is(obj_description(sch_oid), NULL);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_create_schema_with_description() RETURNS SETOF TEXT AS $$
DECLARE sch_oid oid;
BEGIN
  SELECT msar.create_schema('foo bar', 'yay') INTO sch_oid;
  RETURN NEXT has_schema('foo bar');
  RETURN NEXT is(sch_oid, msar.get_schema_oid('foo bar'));
  RETURN NEXT is(obj_description(sch_oid), 'yay');
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_create_schema_that_already_exists() RETURNS SETOF TEXT AS $t$
DECLARE sch_oid oid;
BEGIN
  SELECT msar.create_schema('foo bar') INTO sch_oid;
  RETURN NEXT throws_ok($$SELECT msar.create_schema('foo bar')$$, '42P06');
  RETURN NEXT is(msar.create_schema_if_not_exists('foo bar'), sch_oid);
END;
$t$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION __setup_drop_schema() RETURNS SETOF TEXT AS $$
BEGIN
  CREATE SCHEMA drop_test_schema;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_drop_schema_using_name() RETURNS SETOF TEXT AS $$
BEGIN
  PERFORM __setup_drop_schema();
  PERFORM msar.drop_schema(
    sch_name => 'drop_test_schema', 
    cascade_ => false
  );
  RETURN NEXT hasnt_schema('drop_test_schema');
  RETURN NEXT throws_ok(
    $d$
      SELECT msar.drop_schema(
        sch_name => 'drop_non_existing_schema',
        cascade_ => false
      )
    $d$, 
    '3F000'
  );
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_drop_schema_using_oid() RETURNS SETOF TEXT AS $$
BEGIN
  PERFORM __setup_drop_schema();
  PERFORM msar.drop_schema(
    sch_id => 'drop_test_schema'::regnamespace::oid,
    cascade_ => false
  );
  RETURN NEXT hasnt_schema('drop_test_schema');
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_drop_schema_using_invalid_oid() RETURNS SETOF TEXT AS $$
BEGIN
  PERFORM __setup_drop_schema();
  RETURN NEXT throws_ok(
    $d$
      SELECT msar.drop_schema(
        sch_id => 0,
        cascade_ => false
      )
    $d$,
    '3F000'
  );
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION __setup_schema_with_dependent_obj() RETURNS SETOF TEXT AS $$
BEGIN
  CREATE SCHEMA schema1;
  CREATE TABLE schema1.actors (
    id SERIAL PRIMARY KEY,
    actor_name TEXT
  );
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_drop_schema_cascade() RETURNS SETOF TEXT AS $$
BEGIN
  PERFORM __setup_schema_with_dependent_obj();
  PERFORM msar.drop_schema(
    sch_name => 'schema1',
    cascade_ => true
  );
  RETURN NEXT hasnt_schema('schema1');
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_drop_schema_restricted() RETURNS SETOF TEXT AS $$
BEGIN
  PERFORM __setup_schema_with_dependent_obj();
  RETURN NEXT throws_ok(
    $d$
      SELECT msar.drop_schema(
        sch_name => 'schema1',
        cascade_ => false
      )
    $d$,
    '2BP01'
  );
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_patch_schema() RETURNS SETOF TEXT AS $$
DECLARE sch_oid oid;
BEGIN
  CREATE SCHEMA foo;
  SELECT msar.get_schema_oid('foo') INTO sch_oid;

  PERFORM msar.patch_schema('foo', '{"name": "altered"}');
  RETURN NEXT hasnt_schema('foo');
  RETURN NEXT has_schema('altered');
  RETURN NEXT is(obj_description(sch_oid), NULL);
  RETURN NEXT is(msar.get_schema_name(sch_oid), 'altered');

  PERFORM msar.patch_schema(sch_oid, '{"description": "yay"}');
  RETURN NEXT is(obj_description(sch_oid), 'yay');

  -- Description is removed when NULL is passed.
  PERFORM msar.patch_schema(sch_oid, '{"description": null}');
  RETURN NEXT is(obj_description(sch_oid), NULL);

  -- Description is removed when an empty string is passed.
  PERFORM msar.patch_schema(sch_oid, '{"description": ""}');
  RETURN NEXT is(obj_description(sch_oid), NULL);

  PERFORM msar.patch_schema(sch_oid, '{"name": "NEW", "description": "WOW"}');
  RETURN NEXT has_schema('NEW');
  RETURN NEXT is(msar.get_schema_name(sch_oid), 'NEW');
  RETURN NEXT is(obj_description(sch_oid), 'WOW');

  -- Patching should be idempotent
  PERFORM msar.patch_schema(sch_oid, '{"name": "NEW", "description": "WOW"}');
  RETURN NEXT has_schema('NEW');
  RETURN NEXT is(msar.get_schema_name(sch_oid), 'NEW');
  RETURN NEXT is(obj_description(sch_oid), 'WOW');
END;
$$ LANGUAGE plpgsql;


-- msar.alter_table

CREATE OR REPLACE FUNCTION __setup_alter_table() RETURNS SETOF TEXT AS $$
BEGIN
  CREATE TABLE alter_this_table(id INT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY, col1 TEXT);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_rename_table() RETURNS SETOF TEXT AS $$
BEGIN
  PERFORM __setup_alter_table();
  PERFORM msar.rename_table(
    sch_name =>'public',
    old_tab_name => 'alter_this_table',
    new_tab_name => 'renamed_table'
  );
  RETURN NEXT hasnt_table('alter_this_table');
  RETURN NEXT has_table('renamed_table');
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_rename_table_using_oid() RETURNS SETOF TEXT AS $$
BEGIN
  PERFORM __setup_alter_table();
  PERFORM msar.rename_table(
    tab_id => 'alter_this_table'::regclass::oid,
    new_tab_name => 'renamed_table'
  );
  RETURN NEXT hasnt_table('alter_this_table');
  RETURN NEXT has_table('renamed_table');
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_comment_on_table() RETURNS SETOF TEXT AS $$
BEGIN
  PERFORM __setup_alter_table();
  PERFORM msar.comment_on_table(
    sch_name =>'public',
    tab_name => 'alter_this_table',
    comment_ => 'This is a comment!'
  );
  RETURN NEXT is(obj_description('alter_this_table'::regclass::oid), 'This is a comment!');
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_comment_on_table_using_oid() RETURNS SETOF TEXT AS $$
BEGIN
  PERFORM __setup_alter_table();
  PERFORM msar.comment_on_table(
    tab_id => 'alter_this_table'::regclass::oid,
    comment_ => 'This is a comment!'
  );
  RETURN NEXT is(obj_description('alter_this_table'::regclass::oid), 'This is a comment!');
END;
$$ LANGUAGE plpgsql;


-- msar.add_mathesar_table

CREATE OR REPLACE FUNCTION __setup_create_table() RETURNS SETOF TEXT AS $f$
BEGIN
  CREATE SCHEMA tab_create_schema;
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_mathesar_table_minimal_id_col() RETURNS SETOF TEXT AS $f$
BEGIN
  PERFORM __setup_create_table();
  PERFORM msar.add_mathesar_table(
    'tab_create_schema'::regnamespace::oid, 'anewtable', null, null, null
  );
  RETURN NEXT col_is_pk(
    'tab_create_schema', 'anewtable', 'id', 'id column should be pkey'
  );
  RETURN NEXT results_eq(
    $q$SELECT attidentity
    FROM pg_attribute
    WHERE attrelid='tab_create_schema.anewtable'::regclass::oid and attname='id'$q$,
    $v$VALUES ('d'::"char")$v$,
    'id column should be generated always as identity'
  );
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_mathesar_table_badname() RETURNS SETOF TEXT AS $f$
DECLARE
  badname text := '"new"''dsf'' \t"';
BEGIN
  PERFORM __setup_create_table();
  PERFORM msar.add_mathesar_table(
    'tab_create_schema'::regnamespace::oid, badname, null, null, null
  );
  RETURN NEXT has_table('tab_create_schema'::name, badname::name);
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_mathesar_table_noname() RETURNS SETOF TEXT AS $f$
DECLARE
  generated_name text := 'Table 1';
BEGIN
  PERFORM __setup_create_table();
  PERFORM msar.add_mathesar_table(
    'tab_create_schema'::regnamespace::oid, null, null, null, null
  );
  RETURN NEXT has_table('tab_create_schema'::name, generated_name::name);
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_mathesar_table_noname_avoid_collision()
RETURNS SETOF TEXT AS $f$
DECLARE
  generated_name text := 'Table 3';
BEGIN
  PERFORM __setup_create_table();
  PERFORM msar.add_mathesar_table(
    'tab_create_schema'::regnamespace::oid, null, null, null, null
  );
  PERFORM msar.add_mathesar_table(
    'tab_create_schema'::regnamespace::oid, null, null, null, null
  );
  RETURN NEXT has_table('tab_create_schema'::name, 'Table 1'::name);
  RETURN NEXT has_table('tab_create_schema'::name, 'Table 2'::name);
  PERFORM msar.drop_table(
    sch_name => 'tab_create_schema',
    tab_name => 'Table 1',
    cascade_ => false,
    if_exists => false
  );
  RETURN NEXT hasnt_table('tab_create_schema'::name, 'Table 1'::name);
  PERFORM msar.add_mathesar_table(
    'tab_create_schema'::regnamespace::oid, null, null, null, null
  );
  RETURN NEXT has_table('tab_create_schema'::name, generated_name::name);
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_mathesar_table_columns() RETURNS SETOF TEXT AS $f$
DECLARE
  col_defs jsonb := $j$[
    {"name": "mycolumn", "type": {"name": "numeric"}},
    {},
    {"type": {"name": "varchar", "options": {"length": 128}}}
  ]$j$;
BEGIN
  PERFORM __setup_create_table();
  PERFORM msar.add_mathesar_table(
    'tab_create_schema'::regnamespace::oid,
    'cols_table',
    col_defs,
    null, null
  );
  RETURN NEXT col_is_pk(
    'tab_create_schema', 'cols_table', 'id', 'id column should be pkey'
  );
  RETURN NEXT col_type_is(
    'tab_create_schema'::name, 'cols_table'::name, 'mycolumn'::name, 'numeric'
  );
  RETURN NEXT col_type_is(
    'tab_create_schema'::name, 'cols_table'::name, 'Column 3'::name, 'character varying(128)'
  );
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_get_preview() RETURNS SETOF TEXT AS $f$
DECLARE
  col_cast_def jsonb := $j$[
    {
      "attnum": 1,
      "type": {"name": "integer"}
    },
    {
      "attnum":2,
      "type": {"name": "numeric", "options": {"precision":5, "scale":2}}
    }
  ]$j$;
  want_records jsonb := $j$[
    {"id": 1, "length": 2.00},
    {"id": 2, "length": 3.00},
    {"id": 3, "length": 4.00},
    {"id": 4, "length": 5.22}
  ]
  $j$;
  have_records jsonb;
BEGIN
  PERFORM __setup_create_table();
  CREATE TABLE tab_create_schema.foo(id INTEGER GENERATED BY DEFAULT AS IDENTITY, length FLOAT8);
  INSERT INTO tab_create_schema.foo(length) VALUES (2), (3), (4), (5.2225);
  have_records := msar.get_preview(
    tab_id => 'tab_create_schema.foo'::regclass::oid,
    col_cast_def => col_cast_def,
    rec_limit => NULL
  );
  RETURN NEXT is(have_records, want_records);
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_add_mathesar_table_comment() RETURNS SETOF TEXT AS $f$
DECLARE
  comment_ text := $c$my "Super;";'; DROP SCHEMA tab_create_schema;'$c$;
BEGIN
  PERFORM __setup_create_table();
  PERFORM msar.add_mathesar_table(
    'tab_create_schema'::regnamespace::oid, 'cols_table', null, null, comment_
  );
  RETURN NEXT col_is_pk(
    'tab_create_schema', 'cols_table', 'id', 'id column should be pkey'
  );
  RETURN NEXT is(
    obj_description('tab_create_schema.cols_table'::regclass::oid),
    comment_,
    'created table should have specified description (comment)'
  );
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION __setup_column_alter() RETURNS SETOF TEXT AS $$
BEGIN
  CREATE TABLE col_alters (
    id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    col1 text NOT NULL,
    col2 numeric DEFAULT 5,
    "Col sp" text,
    col_opts numeric(5, 3),
    coltim timestamp DEFAULT now()
  );
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_process_col_alter_jsonb() RETURNS SETOF TEXT AS $f$/*
These don't actually modify the table, so we can run multiple tests in the same test.

Only need to test null/empty behavior here, since main functionality is tested by testing
msar.alter_columns

It's debatable whether this test should continue to exist, but it was useful for initial
development, and runs quickly.
*/
DECLARE
  tab_id oid;
BEGIN
  PERFORM __setup_column_alter();
  tab_id := 'col_alters'::regclass::oid;
  RETURN NEXT is(msar.process_col_alter_jsonb(tab_id, '[{"attnum": 2}]'), null);
  RETURN NEXT is(msar.process_col_alter_jsonb(tab_id, '[{"attnum": 2, "name": "blah"}]'), null);
  RETURN NEXT is(msar.process_col_alter_jsonb(tab_id, '[]'), null);
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_alter_columns_single_name() RETURNS SETOF TEXT AS $f$
DECLARE
  col_alters_jsonb jsonb := '[{"attnum": 2, "name": "blah"}]';
BEGIN
  PERFORM __setup_column_alter();
  RETURN NEXT is(msar.alter_columns('col_alters'::regclass::oid, col_alters_jsonb), ARRAY[2]);
  RETURN NEXT columns_are(
    'col_alters',
    ARRAY['id', 'blah', 'col2', 'Col sp', 'col_opts', 'coltim']
  );
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_alter_columns_multi_names() RETURNS SETOF TEXT AS $f$
DECLARE
  col_alters_jsonb jsonb := $j$[
    {"attnum": 2, "name": "new space"},
    {"attnum": 4, "name": "nospace"}
  ]$j$;
BEGIN
  PERFORM __setup_column_alter();
  RETURN NEXT is(msar.alter_columns('col_alters'::regclass::oid, col_alters_jsonb), ARRAY[2, 4]);
  RETURN NEXT columns_are(
    'col_alters',
    ARRAY['id', 'new space', 'col2', 'nospace', 'col_opts', 'coltim']
  );
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_alter_columns_type() RETURNS SETOF TEXT AS $f$
DECLARE
  col_alters_jsonb jsonb := $j$[
    {"attnum": 2, "type": {"name": "varchar", "options": {"length": 48}}},
    {"attnum": 3, "type": {"name": "integer"}},
    {"attnum": 4, "type": {"name": "integer"}}
  ]$j$;
BEGIN
  PERFORM __setup_column_alter();
  RETURN NEXT is(msar.alter_columns('col_alters'::regclass::oid, col_alters_jsonb), ARRAY[2, 3, 4]);
  RETURN NEXT col_type_is('col_alters', 'col1', 'character varying(48)');
  RETURN NEXT col_type_is('col_alters', 'col2', 'integer');
  RETURN NEXT col_default_is('col_alters', 'col2', 5);
  RETURN NEXT col_type_is('col_alters', 'Col sp', 'integer');
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_alter_columns_type_options() RETURNS SETOF TEXT AS $f$
DECLARE
  col_alters_jsonb jsonb := $j$[
    {"attnum": 5, "type": {"options": {"precision": 4}}}
  ]$j$;
BEGIN
  PERFORM __setup_column_alter();
  RETURN NEXT is(msar.alter_columns('col_alters'::regclass::oid, col_alters_jsonb), ARRAY[5]);
  RETURN NEXT col_type_is('col_alters', 'col_opts', 'numeric(4,0)');
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_alter_columns_drop() RETURNS SETOF TEXT AS $f$
DECLARE
  col_alters_jsonb jsonb := $j$[
    {"attnum": 2, "delete": true},
    {"attnum": 5, "delete": true}
  ]$j$;
BEGIN
  PERFORM __setup_column_alter();
  RETURN NEXT is(msar.alter_columns('col_alters'::regclass::oid, col_alters_jsonb), ARRAY[2, 5]);
  RETURN NEXT columns_are('col_alters', ARRAY['id', 'col2', 'Col sp', 'coltim']);
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_alter_columns_nullable() RETURNS SETOF TEXT AS $f$
DECLARE
  col_alters_jsonb jsonb := $j$[
    {"attnum": 2, "not_null": false},
    {"attnum": 5, "not_null": true}
  ]$j$;
BEGIN
  PERFORM __setup_column_alter();
  RETURN NEXT is(msar.alter_columns('col_alters'::regclass::oid, col_alters_jsonb), ARRAY[2, 5]);
  RETURN NEXT col_is_null('col_alters', 'col1');
  RETURN NEXT col_not_null('col_alters', 'col_opts');
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_alter_columns_leaves_defaults() RETURNS SETOF TEXT AS $f$
DECLARE
  col_alters_jsonb jsonb := $j$[
    {"attnum": 3, "type": {"name": "integer"}},
    {"attnum": 6, "type": {"name": "date"}}
  ]$j$;
BEGIN
  PERFORM __setup_column_alter();
  RETURN NEXT is(msar.alter_columns('col_alters'::regclass::oid, col_alters_jsonb), ARRAY[3, 6]);
  RETURN NEXT col_default_is('col_alters', 'col2', '5');
  RETURN NEXT col_default_is('col_alters', 'coltim', '(now())::date');
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_alter_columns_drops_defaults() RETURNS SETOF TEXT AS $f$
DECLARE
  col_alters_jsonb jsonb := $j$[
    {"attnum": 3, "default": null},
    {"attnum": 6, "type": {"name": "date"}, "default": null}
  ]$j$;
BEGIN
  PERFORM __setup_column_alter();
  RETURN NEXT is(msar.alter_columns('col_alters'::regclass::oid, col_alters_jsonb), ARRAY[3, 6]);
  RETURN NEXT col_hasnt_default('col_alters', 'col2');
  RETURN NEXT col_hasnt_default('col_alters', 'coltim');
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_alter_columns_sets_defaults() RETURNS SETOF TEXT AS $f$
DECLARE
  col_alters_jsonb jsonb := $j$[
    {"attnum": 2, "default": "test34"},
    {"attnum": 3, "default": 8},
    {"attnum": 5, "type": {"name": "integer"}, "default": 7},
    {"attnum": 6, "type": {"name": "text"}, "default": "test12"}
  ]$j$;
BEGIN
  PERFORM __setup_column_alter();
  RETURN NEXT is(
    msar.alter_columns('col_alters'::regclass::oid, col_alters_jsonb),
    ARRAY[2, 3, 5, 6]
  );
  RETURN NEXT col_default_is('col_alters', 'col1', 'test34');
  RETURN NEXT col_default_is('col_alters', 'col2', '8');
  RETURN NEXT col_default_is('col_alters', 'col_opts', '7');
  RETURN NEXT col_default_is('col_alters', 'coltim', 'test12');
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_alter_columns_combo() RETURNS SETOF TEXT AS $f$
DECLARE
  col_alters_jsonb jsonb := $j$[
    {
      "attnum": 2,
      "name": "nullab numeric",
      "not_null": false,
      "type": {"name": "numeric", "options": {"precision": 8, "scale": 4}},
      "description": "This is; a comment with a semicolon!"
    },
    {"attnum": 3, "name": "newcol2"},
    {"attnum": 4, "delete": true},
    {"attnum": 5, "not_null": true},
    {"attnum": 6, "name": "timecol", "not_null": true}
  ]$j$;
BEGIN
  PERFORM __setup_column_alter();
  RETURN NEXT is(
    msar.alter_columns('col_alters'::regclass::oid, col_alters_jsonb), ARRAY[2, 3, 4, 5, 6]
  );
  RETURN NEXT columns_are(
    'col_alters', ARRAY['id', 'nullab numeric', 'newcol2', 'col_opts', 'timecol']
  );
  RETURN NEXT col_is_null('col_alters', 'nullab numeric');
  RETURN NEXT col_type_is('col_alters', 'nullab numeric', 'numeric(8,4)');
  -- This test checks that nothing funny happened when dropping column 4
  RETURN NEXT col_type_is('col_alters', 'col_opts', 'numeric(5,3)');
  RETURN NEXT col_not_null('col_alters', 'col_opts');
  RETURN NEXT col_not_null('col_alters', 'timecol');
  RETURN NEXT is(msar.col_description('col_alters'::regclass::oid, 2), 'This is; a comment with a semicolon!');
  RETURN NEXT is(msar.col_description('col_alters'::regclass::oid, 3), NULL);
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_comment_on_column() RETURNS SETOF TEXT AS $$
DECLARE
  change1 jsonb := $j$[
    {
      "attnum": 2,
      "description": "change1col2description"
    },
    {
      "attnum": 3,
      "name": "change1col3name"
    }
  ]$j$;
  change2 jsonb := $j$[
    {
      "attnum": 2,
      "description": "change2col2description"
    },
    {
      "attnum": 3,
      "description": "change2col3description"
    }
  ]$j$;
  -- Below change should not affect the description.
  change3 jsonb := $j$[
    {
      "attnum": 2,
      "name": "change3col2name"
    },
    {
      "attnum": 3,
      "name": "change3col3name"
    }
  ]$j$;
  change4 jsonb := $j$[
    {
      "attnum": 2,
      "name": "change4col2name",
      "description": null
    },
    {
      "attnum": 3,
      "name": "change4col3name"
    }
  ]$j$;
BEGIN
  PERFORM __setup_column_alter();
  RETURN NEXT is(msar.col_description('col_alters'::regclass::oid, 2), NULL);
  PERFORM msar.alter_columns('col_alters'::regclass::oid, change1);
  RETURN NEXT is(msar.col_description('col_alters'::regclass::oid, 2), 'change1col2description');
  PERFORM msar.alter_columns('col_alters'::regclass::oid, change2);
  RETURN NEXT is(msar.col_description('col_alters'::regclass::oid, 2), 'change2col2description');
  PERFORM msar.alter_columns('col_alters'::regclass::oid, change3);
  RETURN NEXT is(msar.col_description('col_alters'::regclass::oid, 2), 'change2col2description');
  RETURN NEXT is(msar.col_description('col_alters'::regclass::oid, 3), 'change2col3description');
  PERFORM msar.alter_columns('col_alters'::regclass::oid, change4);
  RETURN NEXT is(msar.col_description('col_alters'::regclass::oid, 2), NULL);
  RETURN NEXT is(msar.col_description('col_alters'::regclass::oid, 3), 'change2col3description');
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION __setup_roster() RETURNS SETOF TEXT AS $$
BEGIN
CREATE TABLE "Roster" (
    id integer PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
    "Student Name" text,
    "Teacher" text,
    "Teacher Email" text,
    "Subject" varchar(20),
    "Grade" integer
);
INSERT INTO "Roster"
  ("Student Name", "Teacher", "Teacher Email", "Subject", "Grade")
VALUES
  ('Stephanie Norris', 'James Jones', 'jamesjones@gmail.com', 'Physics', 43),
  ('Stephanie Norris', 'Brooke Bowen', 'brookebowen@yahoo.com', 'P.E.', 37),
  ('Stephanie Norris', 'Deanna Juarez', 'deannajuarez@hotmail.com', 'Chemistry', 55),
  ('Stephanie Norris', 'Joseph Hill', 'josephhill@gmail.com', 'Biology', 41),
  ('Stephanie Norris', 'Julie Garza', 'juliegarza@yahoo.com', 'Physics', 62),
  ('Shannon Ramos', 'James Jones', 'jamesjones@gmail.com', 'Math', 44),
  ('Shannon Ramos', 'Anna Cortez', 'annacortez@yahoo.com', 'Reading', 56),
  ('Shannon Ramos', 'Jennifer Anderson', 'jenniferanderson@yahoo.com', 'Art', 31),
  ('Shannon Ramos', 'Amber Hudson', 'amberhudson@hotmail.com', 'Art', 77),
  ('Shannon Ramos', 'Michael Harding', 'michaelharding@yahoo.com', 'Music', 40),
  ('Tyler Harris', 'James Jones', 'jamesjones@gmail.com', 'Math', 92),
  ('Tyler Harris', 'James Mccarthy', 'jamesmccarthy@yahoo.com', 'History', 87),
  ('Tyler Harris', 'Brett Bennett', 'brettbennett@gmail.com', 'Reading', 30),
  ('Tyler Harris', 'Stephanie Ross', 'stephanieross@yahoo.com', 'Art', 66),
  ('Tyler Harris', 'Barbara Riley', 'barbarariley@hotmail.com', 'Chemistry', 81),
  ('Lee Henderson', 'Barbara Riley', 'barbarariley@hotmail.com', 'Chemistry', 59),
  ('Lee Henderson', 'Krista Ramirez', 'kristaramirez@yahoo.com', 'History', 33),
  ('Lee Henderson', 'Brett Bennett', 'brettbennett@gmail.com', 'Reading', 82),
  ('Lee Henderson', 'Michael Harding', 'michaelharding@yahoo.com', 'Art', 95),
  ('Lee Henderson', 'Danny Davis', 'dannydavis@yahoo.com', 'Reading', 93),
  ('Amber Swanson', 'Whitney Figueroa', 'whitneyfigueroa@gmail.com', 'Math', 67),
  ('Amber Swanson', 'Michael Harding', 'michaelharding@yahoo.com', 'Art', 62),
  ('Amber Swanson', 'Julie Garza', 'juliegarza@yahoo.com', 'Math', 65),
  ('Amber Swanson', 'Brooke Bowen', 'brookebowen@yahoo.com', 'History', 47),
  ('Amber Swanson', 'Jason Aguilar', 'jasonaguilar@gmail.com', 'Chemistry', 44),
  ('Jeffrey Juarez', 'Brett Bennett', 'brettbennett@gmail.com', 'Writing', 65),
  ('Jeffrey Juarez', 'Amber Hudson', 'amberhudson@hotmail.com', 'Art', 57),
  ('Jeffrey Juarez', 'Jason Aguilar', 'jasonaguilar@gmail.com', 'Chemistry', 47),
  ('Jeffrey Juarez', 'Deanna Juarez', 'deannajuarez@hotmail.com', 'Biology', 73),
  ('Jeffrey Juarez', 'Danny Davis', 'dannydavis@yahoo.com', 'Reading', 49),
  ('Jennifer Carlson', 'Barbara Riley', 'barbarariley@hotmail.com', 'Biology', 61),
  ('Jennifer Carlson', 'Jennifer Anderson', 'jenniferanderson@yahoo.com', 'Art', 68),
  ('Jennifer Carlson', 'Brooke Bowen', 'brookebowen@yahoo.com', 'History', 68),
  ('Jennifer Carlson', 'Whitney Figueroa', 'whitneyfigueroa@gmail.com', 'Physics', 43),
  ('Jennifer Carlson', 'James Mccarthy', 'jamesmccarthy@yahoo.com', 'History', 80),
  ('Chelsea Smith', 'Barbara Riley', 'barbarariley@hotmail.com', 'Chemistry', 37),
  ('Chelsea Smith', 'Whitney Figueroa', 'whitneyfigueroa@gmail.com', 'Physics', 95),
  ('Chelsea Smith', 'Stephanie Ross', 'stephanieross@yahoo.com', 'Art', 49),
  ('Chelsea Smith', 'Joseph Hill', 'josephhill@gmail.com', 'Biology', 75),
  ('Chelsea Smith', 'Brooke Bowen', 'brookebowen@yahoo.com', 'P.E.', 100),
  ('Dana Webb', 'Deanna Juarez', 'deannajuarez@hotmail.com', 'Biology', 87),
  ('Dana Webb', 'Michael Harding', 'michaelharding@yahoo.com', 'Music', 87),
  ('Dana Webb', 'Barbara Riley', 'barbarariley@hotmail.com', 'Chemistry', 78),
  ('Dana Webb', 'Teresa Chambers', 'teresachambers@hotmail.com', 'Math', 34),
  ('Dana Webb', 'Danny Davis', 'dannydavis@yahoo.com', 'Reading', 83),
  ('Philip Taylor', 'Amber Hudson', 'amberhudson@hotmail.com', 'Music', 39),
  ('Philip Taylor', 'Brett Bennett', 'brettbennett@gmail.com', 'Reading', 48),
  ('Philip Taylor', 'Joseph Hill', 'josephhill@gmail.com', 'Biology', 84),
  ('Philip Taylor', 'Joseph Hill', 'josephhill@gmail.com', 'Chemistry', 26),
  ('Philip Taylor', 'Teresa Chambers', 'teresachambers@hotmail.com', 'Math', 92),
  ('Christopher Bell', 'Danny Davis', 'dannydavis@hotmail.com', 'Writing', 96),
  ('Christopher Bell', 'James Mccarthy', 'jamesmccarthy@yahoo.com', 'History', 74),
  ('Christopher Bell', 'Barbara Riley', 'barbarariley@hotmail.com', 'Biology', 64),
  ('Christopher Bell', 'Amber Hudson', 'amberhudson@hotmail.com', 'Music', 83),
  ('Christopher Bell', 'Stephanie Ross', 'stephanieross@yahoo.com', 'Art', 90),
  ('Stacy Barnett', 'Barbara Riley', 'barbarariley@hotmail.com', 'Biology', 55),
  ('Stacy Barnett', 'Danny Davis', 'dannydavis@yahoo.com', 'Reading', 99),
  ('Stacy Barnett', 'Stephanie Ross', 'stephanieross@yahoo.com', 'Art', 70),
  ('Stacy Barnett', 'Teresa Chambers', 'teresachambers@gmail.com', 'Physics', 78),
  ('Stacy Barnett', 'Jean Hayes DVM', 'jeanhayesdvm@hotmail.com', 'P.E.', 72),
  ('Mary Carroll', 'Brooke Bowen', 'brookebowen@yahoo.com', 'History', 73),
  ('Mary Carroll', 'Stephanie Ross', 'stephanieross@yahoo.com', 'Art', 87),
  ('Mary Carroll', 'Grant Mcdonald', 'grantmcdonald@gmail.com', 'Writing', 37),
  ('Mary Carroll', 'Krista Ramirez', 'kristaramirez@yahoo.com', 'P.E.', 98),
  ('Mary Carroll', 'Brett Bennett', 'brettbennett@gmail.com', 'Writing', 57),
  ('Susan Hoover', 'Deanna Juarez', 'deannajuarez@hotmail.com', 'Chemistry', 41),
  ('Susan Hoover', 'Brett Bennett', 'brettbennett@gmail.com', 'Reading', 77),
  ('Susan Hoover', 'Amber Hudson', 'amberhudson@hotmail.com', 'Music', 48),
  ('Susan Hoover', 'Krista Ramirez', 'kristaramirez@yahoo.com', 'History', 41),
  ('Susan Hoover', 'Stephanie Ross', 'stephanieross@yahoo.com', 'Art', 89),
  ('Jennifer Park', 'Danny Davis', 'dannydavis@yahoo.com', 'Reading', 96),
  ('Jennifer Park', 'James Mccarthy', 'jamesmccarthy@yahoo.com', 'History', 25),
  ('Jennifer Park', 'Deanna Juarez', 'deannajuarez@hotmail.com', 'Chemistry', 43),
  ('Jennifer Park', 'Jason Aguilar', 'jasonaguilar@gmail.com', 'Biology', 50),
  ('Jennifer Park', 'Barbara Riley', 'barbarariley@hotmail.com', 'Chemistry', 82),
  ('Jennifer Ortiz', 'Barbara Riley', 'barbarariley@hotmail.com', 'Chemistry', 94),
  ('Jennifer Ortiz', 'Jason Aguilar', 'jasonaguilar@gmail.com', 'Chemistry', 26),
  ('Jennifer Ortiz', 'Teresa Chambers', 'teresachambers@hotmail.com', 'Math', 28),
  ('Jennifer Ortiz', 'Barbara Riley', 'barbarariley@hotmail.com', 'Biology', 33),
  ('Jennifer Ortiz', 'Anna Cortez', 'annacortez@yahoo.com', 'Writing', 98),
  ('Robert Lamb', 'Krista Ramirez', 'kristaramirez@yahoo.com', 'History', 89),
  ('Robert Lamb', 'Deanna Juarez', 'deannajuarez@hotmail.com', 'Chemistry', 99),
  ('Robert Lamb', 'Barbara Riley', 'barbarariley@hotmail.com', 'Chemistry', 55),
  ('Robert Lamb', 'Anna Cortez', 'annacortez@yahoo.com', 'Writing', 32),
  ('Robert Lamb', 'Jason Aguilar', 'jasonaguilar@gmail.com', 'Biology', 83),
  ('Judy Martinez', 'Danny Davis', 'dannydavis@hotmail.com', 'Writing', 99),
  ('Judy Martinez', 'Grant Mcdonald', 'grantmcdonald@gmail.com', 'Writing', 59),
  ('Judy Martinez', 'Grant Mcdonald', 'grantmcdonald@hotmail.com', 'Reading', 66),
  ('Judy Martinez', 'Jean Hayes DVM', 'jeanhayesdvm@hotmail.com', 'P.E.', 83),
  ('Judy Martinez', 'Teresa Chambers', 'teresachambers@hotmail.com', 'Math', 75),
  ('Christy Meyer', 'Teresa Chambers', 'teresachambers@hotmail.com', 'Math', 60),
  ('Christy Meyer', 'Barbara Riley', 'barbarariley@hotmail.com', 'Chemistry', 90),
  ('Christy Meyer', 'Brett Bennett', 'brettbennett@gmail.com', 'Writing', 72),
  ('Christy Meyer', 'Joseph Hill', 'josephhill@gmail.com', 'Biology', 37),
  ('Christy Meyer', 'Stephanie Ross', 'stephanieross@yahoo.com', 'Art', 78),
  ('Evelyn Anderson', 'Brett Bennett', 'brettbennett@gmail.com', 'Writing', 64),
  ('Evelyn Anderson', 'Jean Hayes DVM', 'jeanhayesdvm@hotmail.com', 'History', 68),
  ('Evelyn Anderson', 'Danny Davis', 'dannydavis@yahoo.com', 'Reading', 49),
  ('Evelyn Anderson', 'Amber Hudson', 'amberhudson@hotmail.com', 'Art', 42),
  ('Evelyn Anderson', 'Krista Ramirez', 'kristaramirez@yahoo.com', 'History', 95),
  ('Bethany Bell', 'Michael Harding', 'michaelharding@yahoo.com', 'Art', 36),
  ('Bethany Bell', 'Julie Garza', 'juliegarza@yahoo.com', 'Physics', 62),
  ('Bethany Bell', 'James Mccarthy', 'jamesmccarthy@yahoo.com', 'History', 50),
  ('Bethany Bell', 'Grant Mcdonald', 'grantmcdonald@gmail.com', 'Writing', 93),
  ('Bethany Bell', 'Deanna Juarez', 'deannajuarez@hotmail.com', 'Chemistry', 73),
  ('Leslie Hart', 'Grant Mcdonald', 'grantmcdonald@gmail.com', 'Writing', 45),
  ('Leslie Hart', 'Amber Hudson', 'amberhudson@hotmail.com', 'Music', 79),
  ('Leslie Hart', 'Krista Ramirez', 'kristaramirez@yahoo.com', 'P.E.', 57),
  ('Leslie Hart', 'Stephanie Ross', 'stephanieross@yahoo.com', 'Music', 76),
  ('Leslie Hart', 'James Jones', 'jamesjones@gmail.com', 'Math', 75),
  ('Carolyn Durham', 'James Mccarthy', 'jamesmccarthy@yahoo.com', 'P.E.', 60),
  ('Carolyn Durham', 'Stephanie Ross', 'stephanieross@yahoo.com', 'Music', 28),
  ('Carolyn Durham', 'Barbara Riley', 'barbarariley@hotmail.com', 'Biology', 25),
  ('Carolyn Durham', 'Grant Mcdonald', 'grantmcdonald@hotmail.com', 'Reading', 49),
  ('Carolyn Durham', 'Whitney Figueroa', 'whitneyfigueroa@gmail.com', 'Physics', 69),
  ('Daniel Martin', 'Michael Harding', 'michaelharding@yahoo.com', 'Music', 60),
  ('Daniel Martin', 'Krista Ramirez', 'kristaramirez@yahoo.com', 'P.E.', 32),
  ('Daniel Martin', 'Anna Cortez', 'annacortez@yahoo.com', 'Reading', 75),
  ('Daniel Martin', 'Julie Garza', 'juliegarza@yahoo.com', 'Physics', 78),
  ('Daniel Martin', 'Barbara Riley', 'barbarariley@hotmail.com', 'Biology', 74),
  ('Jessica Jackson', 'Danny Davis', 'dannydavis@hotmail.com', 'Writing', 34),
  ('Jessica Jackson', 'Whitney Figueroa', 'whitneyfigueroa@gmail.com', 'Math', 78),
  ('Jessica Jackson', 'Jason Aguilar', 'jasonaguilar@gmail.com', 'Chemistry', 67),
  ('Jessica Jackson', 'Joseph Hill', 'josephhill@gmail.com', 'Biology', 68),
  ('Jessica Jackson', 'James Mccarthy', 'jamesmccarthy@yahoo.com', 'History', 88),
  ('Stephanie Mendez', 'Brooke Bowen', 'brookebowen@yahoo.com', 'History', 93),
  ('Stephanie Mendez', 'Michael Harding', 'michaelharding@yahoo.com', 'Art', 73),
  ('Stephanie Mendez', 'Jennifer Anderson', 'jenniferanderson@yahoo.com', 'Art', 27),
  ('Stephanie Mendez', 'Teresa Chambers', 'teresachambers@gmail.com', 'Physics', 41),
  ('Stephanie Mendez', 'Grant Mcdonald', 'grantmcdonald@hotmail.com', 'Reading', 98),
  ('Kevin Griffith', 'Joseph Hill', 'josephhill@gmail.com', 'Chemistry', 54),
  ('Kevin Griffith', 'Michael Harding', 'michaelharding@yahoo.com', 'Music', 57),
  ('Kevin Griffith', 'Barbara Riley', 'barbarariley@hotmail.com', 'Chemistry', 92),
  ('Kevin Griffith', 'Stephanie Ross', 'stephanieross@yahoo.com', 'Art', 82),
  ('Kevin Griffith', 'Krista Ramirez', 'kristaramirez@yahoo.com', 'History', 48),
  ('Debra Johnson', 'Barbara Riley', 'barbarariley@hotmail.com', 'Biology', 38),
  ('Debra Johnson', 'Krista Ramirez', 'kristaramirez@yahoo.com', 'P.E.', 44),
  ('Debra Johnson', 'Jean Hayes DVM', 'jeanhayesdvm@hotmail.com', 'History', 32),
  ('Debra Johnson', 'Teresa Chambers', 'teresachambers@hotmail.com', 'Math', 32),
  ('Debra Johnson', 'Michael Harding', 'michaelharding@yahoo.com', 'Art', 41),
  ('Mark Frazier', 'Joseph Hill', 'josephhill@gmail.com', 'Biology', 78),
  ('Mark Frazier', 'Amber Hudson', 'amberhudson@hotmail.com', 'Art', 25),
  ('Mark Frazier', 'Julie Garza', 'juliegarza@yahoo.com', 'Math', 93),
  ('Mark Frazier', 'Danny Davis', 'dannydavis@yahoo.com', 'Reading', 98),
  ('Mark Frazier', 'Jennifer Anderson', 'jenniferanderson@yahoo.com', 'Music', 75),
  ('Jessica Jones', 'Anna Cortez', 'annacortez@yahoo.com', 'Reading', 34),
  ('Jessica Jones', 'Michael Harding', 'michaelharding@yahoo.com', 'Art', 46),
  ('Jessica Jones', 'Grant Mcdonald', 'grantmcdonald@gmail.com', 'Writing', 95),
  ('Jessica Jones', 'James Mccarthy', 'jamesmccarthy@yahoo.com', 'History', 41),
  ('Jessica Jones', 'Deanna Juarez', 'deannajuarez@hotmail.com', 'Chemistry', 97),
  ('Brandon Robinson', 'James Mccarthy', 'jamesmccarthy@yahoo.com', 'P.E.', 38),
  ('Brandon Robinson', 'Jason Aguilar', 'jasonaguilar@gmail.com', 'Chemistry', 64),
  ('Brandon Robinson', 'Grant Mcdonald', 'grantmcdonald@gmail.com', 'Writing', 53),
  ('Brandon Robinson', 'Joseph Hill', 'josephhill@gmail.com', 'Chemistry', 56),
  ('Brandon Robinson', 'Anna Cortez', 'annacortez@yahoo.com', 'Reading', 39),
  ('Timothy Lowe', 'Krista Ramirez', 'kristaramirez@yahoo.com', 'P.E.', 43),
  ('Timothy Lowe', 'Stephanie Ross', 'stephanieross@yahoo.com', 'Music', 74),
  ('Timothy Lowe', 'James Mccarthy', 'jamesmccarthy@yahoo.com', 'History', 62),
  ('Timothy Lowe', 'Teresa Chambers', 'teresachambers@hotmail.com', 'Math', 99),
  ('Timothy Lowe', 'Grant Mcdonald', 'grantmcdonald@gmail.com', 'Writing', 76),
  ('Samantha Rivera', 'James Jones', 'jamesjones@gmail.com', 'Math', 38),
  ('Samantha Rivera', 'Joseph Hill', 'josephhill@gmail.com', 'Biology', 34),
  ('Samantha Rivera', 'Stephanie Ross', 'stephanieross@yahoo.com', 'Art', 55),
  ('Samantha Rivera', 'Jean Hayes DVM', 'jeanhayesdvm@hotmail.com', 'P.E.', 91),
  ('Samantha Rivera', 'Danny Davis', 'dannydavis@yahoo.com', 'Reading', 35),
  ('Matthew Brown', 'Jennifer Anderson', 'jenniferanderson@yahoo.com', 'Art', 37),
  ('Matthew Brown', 'Whitney Figueroa', 'whitneyfigueroa@gmail.com', 'Math', 59),
  ('Matthew Brown', 'James Jones', 'jamesjones@gmail.com', 'Math', 83),
  ('Matthew Brown', 'Jason Aguilar', 'jasonaguilar@gmail.com', 'Chemistry', 100),
  ('Matthew Brown', 'Michael Harding', 'michaelharding@yahoo.com', 'Music', 40),
  ('Mary Gonzalez', 'Deanna Juarez', 'deannajuarez@hotmail.com', 'Chemistry', 30),
  ('Mary Gonzalez', 'Krista Ramirez', 'kristaramirez@yahoo.com', 'P.E.', 50),
  ('Mary Gonzalez', 'Jean Hayes DVM', 'jeanhayesdvm@hotmail.com', 'History', 52),
  ('Mary Gonzalez', 'Brooke Bowen', 'brookebowen@yahoo.com', 'P.E.', 94),
  ('Mary Gonzalez', 'James Jones', 'jamesjones@gmail.com', 'Physics', 39),
  ('Mr. Patrick Weber MD', 'James Mccarthy', 'jamesmccarthy@yahoo.com', 'P.E.', 58),
  ('Mr. Patrick Weber MD', 'Brooke Bowen', 'brookebowen@yahoo.com', 'History', 31),
  ('Mr. Patrick Weber MD', 'Jennifer Anderson', 'jenniferanderson@yahoo.com', 'Art', 73),
  ('Mr. Patrick Weber MD', 'Michael Harding', 'michaelharding@yahoo.com', 'Music', 72),
  ('Mr. Patrick Weber MD', 'Julie Garza', 'juliegarza@yahoo.com', 'Math', 51),
  ('Jill Walker', 'Stephanie Ross', 'stephanieross@yahoo.com', 'Music', 43),
  ('Jill Walker', 'Brett Bennett', 'brettbennett@gmail.com', 'Writing', 80),
  ('Jill Walker', 'Michael Harding', 'michaelharding@yahoo.com', 'Art', 25),
  ('Jill Walker', 'Whitney Figueroa', 'whitneyfigueroa@gmail.com', 'Math', 39),
  ('Jill Walker', 'James Mccarthy', 'jamesmccarthy@yahoo.com', 'History', 70),
  ('Jacob Higgins', 'Teresa Chambers', 'teresachambers@gmail.com', 'Physics', 95),
  ('Jacob Higgins', 'Barbara Riley', 'barbarariley@hotmail.com', 'Chemistry', 88),
  ('Jacob Higgins', 'Brooke Bowen', 'brookebowen@yahoo.com', 'History', 47),
  ('Jacob Higgins', 'Grant Mcdonald', 'grantmcdonald@hotmail.com', 'Reading', 59),
  ('Jacob Higgins', 'Jason Aguilar', 'jasonaguilar@gmail.com', 'Chemistry', 53),
  ('Paula Thompson', 'Jason Aguilar', 'jasonaguilar@gmail.com', 'Biology', 52),
  ('Paula Thompson', 'Anna Cortez', 'annacortez@yahoo.com', 'Reading', 42),
  ('Paula Thompson', 'Whitney Figueroa', 'whitneyfigueroa@gmail.com', 'Physics', 98),
  ('Paula Thompson', 'Amber Hudson', 'amberhudson@hotmail.com', 'Art', 28),
  ('Paula Thompson', 'Deanna Juarez', 'deannajuarez@hotmail.com', 'Chemistry', 53),
  ('Tyler Phelps', 'Amber Hudson', 'amberhudson@hotmail.com', 'Music', 33),
  ('Tyler Phelps', 'Brett Bennett', 'brettbennett@gmail.com', 'Writing', 91),
  ('Tyler Phelps', 'Deanna Juarez', 'deannajuarez@hotmail.com', 'Chemistry', 81),
  ('Tyler Phelps', 'Joseph Hill', 'josephhill@gmail.com', 'Chemistry', 30),
  ('Tyler Phelps', 'James Mccarthy', 'jamesmccarthy@yahoo.com', 'History', 86),
  ('John Schaefer', 'Whitney Figueroa', 'whitneyfigueroa@gmail.com', 'Physics', 44),
  ('John Schaefer', 'Joseph Hill', 'josephhill@gmail.com', 'Biology', 69),
  ('John Schaefer', 'Anna Cortez', 'annacortez@yahoo.com', 'Writing', 80),
  ('John Schaefer', 'Danny Davis', 'dannydavis@yahoo.com', 'Reading', 69),
  ('John Schaefer', 'Joseph Hill', 'josephhill@gmail.com', 'Chemistry', 45),
  ('Eric Kerr', 'Brooke Bowen', 'brookebowen@yahoo.com', 'P.E.', 45),
  ('Eric Kerr', 'Teresa Chambers', 'teresachambers@hotmail.com', 'Math', 90),
  ('Eric Kerr', 'Krista Ramirez', 'kristaramirez@yahoo.com', 'P.E.', 50),
  ('Eric Kerr', 'Anna Cortez', 'annacortez@yahoo.com', 'Writing', 92),
  ('Eric Kerr', 'Stephanie Ross', 'stephanieross@yahoo.com', 'Art', 77),
  ('Mikayla Miller', 'Julie Garza', 'juliegarza@yahoo.com', 'Physics', 61),
  ('Mikayla Miller', 'Brett Bennett', 'brettbennett@gmail.com', 'Writing', 30),
  ('Mikayla Miller', 'Jennifer Anderson', 'jenniferanderson@yahoo.com', 'Art', 88),
  ('Mikayla Miller', 'Deanna Juarez', 'deannajuarez@hotmail.com', 'Biology', 68),
  ('Mikayla Miller', 'Anna Cortez', 'annacortez@yahoo.com', 'Writing', 41),
  ('Alejandro Lam', 'Stephanie Ross', 'stephanieross@yahoo.com', 'Music', 48),
  ('Alejandro Lam', 'Michael Harding', 'michaelharding@yahoo.com', 'Art', 40),
  ('Alejandro Lam', 'Krista Ramirez', 'kristaramirez@yahoo.com', 'P.E.', 40),
  ('Alejandro Lam', 'Deanna Juarez', 'deannajuarez@hotmail.com', 'Chemistry', 49),
  ('Alejandro Lam', 'Barbara Riley', 'barbarariley@hotmail.com', 'Chemistry', 49),
  ('Katelyn Ray', 'Danny Davis', 'dannydavis@yahoo.com', 'Reading', 60),
  ('Katelyn Ray', 'Grant Mcdonald', 'grantmcdonald@hotmail.com', 'Reading', 65),
  ('Katelyn Ray', 'Julie Garza', 'juliegarza@yahoo.com', 'Math', 82),
  ('Katelyn Ray', 'Barbara Riley', 'barbarariley@hotmail.com', 'Chemistry', 70),
  ('Katelyn Ray', 'Jason Aguilar', 'jasonaguilar@gmail.com', 'Biology', 59),
  ('Carla Rivera', 'Amber Hudson', 'amberhudson@hotmail.com', 'Music', 67),
  ('Carla Rivera', 'Julie Garza', 'juliegarza@yahoo.com', 'Physics', 70),
  ('Carla Rivera', 'Amber Hudson', 'amberhudson@hotmail.com', 'Art', 94),
  ('Carla Rivera', 'Anna Cortez', 'annacortez@yahoo.com', 'Reading', 36),
  ('Carla Rivera', 'Michael Harding', 'michaelharding@yahoo.com', 'Art', 51),
  ('Larry Alexander', 'Krista Ramirez', 'kristaramirez@yahoo.com', 'History', 57),
  ('Larry Alexander', 'Joseph Hill', 'josephhill@gmail.com', 'Chemistry', 97),
  ('Larry Alexander', 'Jennifer Anderson', 'jenniferanderson@yahoo.com', 'Art', 89),
  ('Larry Alexander', 'Teresa Chambers', 'teresachambers@hotmail.com', 'Math', 66),
  ('Larry Alexander', 'Brooke Bowen', 'brookebowen@yahoo.com', 'History', 92),
  ('Michael Knox', 'Stephanie Ross', 'stephanieross@yahoo.com', 'Art', 72),
  ('Michael Knox', 'Krista Ramirez', 'kristaramirez@yahoo.com', 'History', 65),
  ('Michael Knox', 'James Mccarthy', 'jamesmccarthy@yahoo.com', 'History', 49),
  ('Michael Knox', 'Barbara Riley', 'barbarariley@hotmail.com', 'Chemistry', 29),
  ('Michael Knox', 'Jason Aguilar', 'jasonaguilar@gmail.com', 'Chemistry', 83),
  ('Alexander Brown', 'Jennifer Anderson', 'jenniferanderson@yahoo.com', 'Music', 89),
  ('Alexander Brown', 'Deanna Juarez', 'deannajuarez@hotmail.com', 'Chemistry', 94),
  ('Alexander Brown', 'Anna Cortez', 'annacortez@yahoo.com', 'Writing', 93),
  ('Alexander Brown', 'Whitney Figueroa', 'whitneyfigueroa@gmail.com', 'Math', 35),
  ('Alexander Brown', 'Whitney Figueroa', 'whitneyfigueroa@gmail.com', 'Physics', 71),
  ('Anne Sloan', 'Jennifer Anderson', 'jenniferanderson@yahoo.com', 'Art', 38),
  ('Anne Sloan', 'Brooke Bowen', 'brookebowen@yahoo.com', 'P.E.', 69),
  ('Anne Sloan', 'Danny Davis', 'dannydavis@yahoo.com', 'Reading', 86),
  ('Anne Sloan', 'Anna Cortez', 'annacortez@yahoo.com', 'Writing', 39),
  ('Anne Sloan', 'James Mccarthy', 'jamesmccarthy@yahoo.com', 'P.E.', 96);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_extract_columns_data() RETURNS SETOF TEXT AS $f$
BEGIN
  PERFORM __setup_roster();
  CREATE TABLE roster_snapshot AS SELECT * FROM "Roster" ORDER BY id;
  PERFORM msar.extract_columns_from_table('"Roster"'::regclass::oid, ARRAY[3, 4], 'Teachers', null);
  RETURN NEXT columns_are('Teachers', ARRAY['id', 'Teacher', 'Teacher Email']);
  RETURN NEXT columns_are('Roster', ARRAY['id', 'Student Name', 'Subject', 'Grade', 'Teachers_id']);
  RETURN NEXT fk_ok('Roster', 'Teachers_id', 'Teachers', 'id');
  RETURN NEXT set_eq(
    'SELECT "Teacher", "Teacher Email" FROM "Teachers"',
    'SELECT DISTINCT "Teacher", "Teacher Email" FROM roster_snapshot',
    'Extracted data should be unique tuples'
  );
  RETURN NEXT results_eq(
    'SELECT "Student Name", "Subject", "Grade" FROM "Roster" ORDER BY id',
    'SELECT "Student Name", "Subject", "Grade" FROM roster_snapshot ORDER BY id',
    'Remainder data should be unchanged'
  );
  RETURN NEXT results_eq(
    $q$
    SELECT r.id, "Student Name", "Teacher", "Teacher Email", "Subject", "Grade"
    FROM "Roster" r LEFT JOIN "Teachers" t ON r."Teachers_id"=t.id ORDER BY r.id
    $q$,
    'SELECT * FROM roster_snapshot ORDER BY id',
    'Joining extracted data should recover original'
  );
  RETURN NEXT lives_ok(
    $i$
    INSERT INTO "Teachers" ("Teacher", "Teacher Email") VALUES ('Miyagi', 'miyagi@karatekid.com')
    $i$,
    'The new id column should be incremented to avoid collision'
  );
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION __setup_extract_fkey_cols() RETURNS SETOF TEXT AS $$
BEGIN
CREATE TABLE "Referent" (
    id integer PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
    "Teacher" text,
    "Teacher Email" text
);
CREATE TABLE "Referrer" (
    id integer PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
    "Student Name" text,
    "Subject" varchar(20),
    "Grade" integer,
    "Referent_id" integer REFERENCES "Referent" (id)
);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_extract_columns_keeps_fkey() RETURNS SETOF TEXT AS $f$
BEGIN
  PERFORM __setup_extract_fkey_cols();
  PERFORM msar.extract_columns_from_table(
    '"Referrer"'::regclass::oid, ARRAY[3, 5], 'Classes', 'Class'
  );
  RETURN NEXT columns_are('Referent', ARRAY['id', 'Teacher', 'Teacher Email']);
  RETURN NEXT columns_are('Referrer', ARRAY['id', 'Student Name', 'Grade', 'Class']);
  RETURN NEXT columns_are('Classes', ARRAY['id', 'Subject', 'Referent_id']);
  RETURN NEXT fk_ok('Referrer', 'Class', 'Classes', 'id');
  RETURN NEXT fk_ok('Classes', 'Referent_id', 'Referent', 'id');
END;
$f$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION __setup_dynamic_defaults() RETURNS SETOF TEXT AS $$
BEGIN
  CREATE TABLE defaults_test (
    id integer PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
    col1 integer DEFAULT 5,
    col2 integer DEFAULT 3::integer,
    col3 timestamp DEFAULT NOW(),
    col4 date DEFAULT '2023-01-01',
    col5 date DEFAULT CURRENT_DATE
  );
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_is_possibly_dynamic() RETURNS SETOF TEXT AS $$
DECLARE
  tab_id oid;
BEGIN
  PERFORM __setup_dynamic_defaults();
  tab_id := 'defaults_test'::regclass::oid;
  RETURN NEXT is(msar.is_default_possibly_dynamic(tab_id, 1), true);
  RETURN NEXT is(msar.is_default_possibly_dynamic(tab_id, 2), false);
  RETURN NEXT is(msar.is_default_possibly_dynamic(tab_id, 3), false);
  RETURN NEXT is(msar.is_default_possibly_dynamic(tab_id, 4), true);
  RETURN NEXT is(msar.is_default_possibly_dynamic(tab_id, 5), false);
  RETURN NEXT is(msar.is_default_possibly_dynamic(tab_id, 6), true);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_create_basic_mathesar_user() RETURNS SETOF TEXT AS $$
BEGIN
  PERFORM msar.create_basic_mathesar_user('testuser', 'mypass1234');
  RETURN NEXT database_privs_are (
    'mathesar_testing', 'testuser', ARRAY['CREATE', 'CONNECT', 'TEMPORARY']
  );
  RETURN NEXT schema_privs_are ('msar', 'testuser', ARRAY['USAGE']);
  RETURN NEXT schema_privs_are ('__msar', 'testuser', ARRAY['USAGE']);
  PERFORM msar.create_basic_mathesar_user(
    'Ro"\bert''); DROP SCHEMA public;', 'my''pass1234"; DROP SCHEMA public;'
  );
  RETURN NEXT has_schema('public');
  RETURN NEXT has_user('Ro"\bert''); DROP SCHEMA public;');
  RETURN NEXT database_privs_are (
    'mathesar_testing', 'Ro"\bert''); DROP SCHEMA public;', ARRAY['CREATE', 'CONNECT', 'TEMPORARY']
  );
  RETURN NEXT schema_privs_are ('msar', 'Ro"\bert''); DROP SCHEMA public;', ARRAY['USAGE']);
  RETURN NEXT schema_privs_are ('__msar', 'Ro"\bert''); DROP SCHEMA public;', ARRAY['USAGE']);
END;
$$ LANGUAGE plpgsql;


-- msar.get_column_info (and related) --------------------------------------------------------------

CREATE OR REPLACE FUNCTION __setup_manytypes() RETURNS SETOF TEXT AS $$
BEGIN
CREATE TABLE manytypes (
    id integer PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
    -- To fend off likely typos, we check many combinations of field and precision settings.
    ivl_plain interval,
    ivl_yr interval year,
    ivl_mo interval month,
    ivl_dy interval day,
    ivl_hr interval hour,
    ivl_mi interval minute,
    ivl_se interval second,
    ivl_ye_mo interval year to month,
    ivl_dy_hr interval day to hour,
    ivl_dy_mi interval day to minute,
    ivl_dy_se interval day to second,
    ivl_hr_mi interval hour to minute,
    ivl_hr_se interval hour to second,
    ivl_mi_se interval minute to second,
    ivl_se_0 interval second(0),
    ivl_se_3 interval second(3),
    ivl_se_6 interval second(6),
    ivl_dy_se0 interval day to second(0),
    ivl_dy_se3 interval day to second(3),
    ivl_dy_se6 interval day to second(6),
    ivl_hr_se0 interval hour to second(0),
    ivl_hr_se3 interval hour to second(3),
    ivl_hr_se6 interval hour to second(6),
    ivl_mi_se0 interval minute to second(0),
    ivl_mi_se3 interval minute to second(3),
    ivl_mi_se6 interval minute to second(6),
    -- Below here is less throrough, more ad-hoc
    ivl_plain_arr interval[],
    ivl_mi_se6_arr interval minute to second(6)[2][2],
    num_plain numeric,
    num_8 numeric(8),
    num_17_2 numeric(17, 2),
    num_plain_arr numeric[],
    num_17_2_arr numeric(17, 2)[],
    var_plain varchar,
    var_16 varchar(16),
    var_255 varchar(255),
    cha_1 character,
    cha_20 character(20),
    var_16_arr varchar(16)[],
    cha_20_arr character(20)[][],
    bit_8 bit(8),
    vbt_8 varbit(8),
    tim_2 time(2),
    ttz_3 timetz(3),
    tsp_4 timestamp(4),
    tsz_5 timestamptz(5)
);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_get_interval_fields() RETURNS SETOF TEXT AS $$
BEGIN
  PERFORM __setup_manytypes();
  RETURN NEXT results_eq(
    $h$
    SELECT msar.get_interval_fields(atttypmod)
    FROM pg_attribute
    WHERE attrelid='manytypes'::regclass AND atttypid='interval'::regtype
    ORDER BY attnum;
    $h$,
    $w$
    VALUES
      (NULL),
      ('year'),
      ('month'),
      ('day'),
      ('hour'),
      ('minute'),
      ('second'),
      ('year to month'),
      ('day to hour'),
      ('day to minute'),
      ('day to second'),
      ('hour to minute'),
      ('hour to second'),
      ('minute to second'),
      ('second'),
      ('second'),
      ('second'),
      ('day to second'),
      ('day to second'),
      ('day to second'),
      ('hour to second'),
      ('hour to second'),
      ('hour to second'),
      ('minute to second'),
      ('minute to second'),
      ('minute to second')
    $w$
  );
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_get_type_options() RETURNS SETOF TEXT AS $$
BEGIN
  PERFORM __setup_manytypes();
  RETURN NEXT is(msar.get_type_options(atttypid, atttypmod, attndims), NULL)
  FROM pg_attribute WHERE attrelid='manytypes'::regclass AND attname='id';
  RETURN NEXT is(
    msar.get_type_options(atttypid, atttypmod, attndims),
    '{"fields": null, "precision": null}'::jsonb
  )
  FROM pg_attribute WHERE attrelid='manytypes'::regclass AND attname='ivl_plain';
  RETURN NEXT is(
    msar.get_type_options(atttypid, atttypmod, attndims),
    '{"fields": "day to second", "precision": null}'::jsonb
  )
  FROM pg_attribute WHERE attrelid='manytypes'::regclass AND attname='ivl_dy_se';
  RETURN NEXT is(
    msar.get_type_options(atttypid, atttypmod, attndims),
    '{"fields": "second", "precision": 3}'::jsonb
  )
  FROM pg_attribute WHERE attrelid='manytypes'::regclass AND attname='ivl_se_3';
  RETURN NEXT is(
    msar.get_type_options(atttypid, atttypmod, attndims),
    '{"fields": "hour to second", "precision": 0}'::jsonb
  )
  FROM pg_attribute WHERE attrelid='manytypes'::regclass AND attname='ivl_hr_se_0';
  RETURN NEXT is(
    msar.get_type_options(atttypid, atttypmod, attndims),
    '{"fields": null, "precision": null, "item_type": "interval"}'::jsonb
  )
  FROM pg_attribute WHERE attrelid='manytypes'::regclass AND attname='ivl_plain_arr';
  RETURN NEXT is(
    msar.get_type_options(atttypid, atttypmod, attndims),
    '{"fields": "minute to second", "precision": 6, "item_type": "interval"}'::jsonb
  )
  FROM pg_attribute WHERE attrelid='manytypes'::regclass AND attname='ivl_mi_se6_arr';
  RETURN NEXT is(
    msar.get_type_options(atttypid, atttypmod, attndims),
    '{"precision": null, "scale": null}'::jsonb
  )
  FROM pg_attribute WHERE attrelid='manytypes'::regclass AND attname='num_plain';
  RETURN NEXT is(
    msar.get_type_options(atttypid, atttypmod, attndims),
    '{"precision": 8, "scale": 0}'::jsonb
  )
  FROM pg_attribute WHERE attrelid='manytypes'::regclass AND attname='num_8';
  RETURN NEXT is(
    msar.get_type_options(atttypid, atttypmod, attndims),
    '{"precision": 17, "scale": 2}'::jsonb
  )
  FROM pg_attribute WHERE attrelid='manytypes'::regclass AND attname='num_17_2';
  RETURN NEXT is(
    msar.get_type_options(atttypid, atttypmod, attndims),
    '{"precision": null, "scale": null, "item_type": "numeric"}'::jsonb
  )
  FROM pg_attribute WHERE attrelid='manytypes'::regclass AND attname='num_plain_arr';
  RETURN NEXT is(
    msar.get_type_options(atttypid, atttypmod, attndims),
    '{"precision": 17, "scale": 2, "item_type": "numeric"}'::jsonb
  )
  FROM pg_attribute WHERE attrelid='manytypes'::regclass AND attname='num_17_2_arr';
  RETURN NEXT is(
    msar.get_type_options(atttypid, atttypmod, attndims),
    '{"length": null}'::jsonb
  )
  FROM pg_attribute WHERE attrelid='manytypes'::regclass AND attname='var_plain';
  RETURN NEXT is(
    msar.get_type_options(atttypid, atttypmod, attndims),
    '{"length": 16}'::jsonb
  )
  FROM pg_attribute WHERE attrelid='manytypes'::regclass AND attname='var_16';
  RETURN NEXT is(
    msar.get_type_options(atttypid, atttypmod, attndims),
    '{"length": 255}'::jsonb
  )
  FROM pg_attribute WHERE attrelid='manytypes'::regclass AND attname='var_255';
  RETURN NEXT is(
    msar.get_type_options(atttypid, atttypmod, attndims),
    '{"length": 1}'::jsonb
  )
  FROM pg_attribute WHERE attrelid='manytypes'::regclass AND attname='cha_1';
  RETURN NEXT is(
    msar.get_type_options(atttypid, atttypmod, attndims),
    '{"length": 20}'::jsonb
  )
  FROM pg_attribute WHERE attrelid='manytypes'::regclass AND attname='cha_20';
  RETURN NEXT is(
    msar.get_type_options(atttypid, atttypmod, attndims),
    '{"length": 16, "item_type": "character varying"}'::jsonb
  )
  FROM pg_attribute WHERE attrelid='manytypes'::regclass AND attname='var_16_arr';
  RETURN NEXT is(
    msar.get_type_options(atttypid, atttypmod, attndims),
    '{"length": 20, "item_type": "character"}'::jsonb
  )
  FROM pg_attribute WHERE attrelid='manytypes'::regclass AND attname='cha_20_arr';
  RETURN NEXT is(
    msar.get_type_options(atttypid, atttypmod, attndims),
    '{"precision": 8}'::jsonb
  )
  FROM pg_attribute WHERE attrelid='manytypes'::regclass AND attname='bit_8';
  RETURN NEXT is(
    msar.get_type_options(atttypid, atttypmod, attndims),
    '{"precision": 8}'::jsonb
  )
  FROM pg_attribute WHERE attrelid='manytypes'::regclass AND attname='vbt_8';
  RETURN NEXT is(
    msar.get_type_options(atttypid, atttypmod, attndims),
    '{"precision": 2}'::jsonb
  )
  FROM pg_attribute WHERE attrelid='manytypes'::regclass AND attname='tim_2';
  RETURN NEXT is(
    msar.get_type_options(atttypid, atttypmod, attndims),
    '{"precision": 3}'::jsonb
  )
  FROM pg_attribute WHERE attrelid='manytypes'::regclass AND attname='ttz_3';
  RETURN NEXT is(
    msar.get_type_options(atttypid, atttypmod, attndims),
    '{"precision": 4}'::jsonb
  )
  FROM pg_attribute WHERE attrelid='manytypes'::regclass AND attname='tsp_4';
  RETURN NEXT is(
    msar.get_type_options(atttypid, atttypmod, attndims),
    '{"precision": 5}'::jsonb
  )
  FROM pg_attribute WHERE attrelid='manytypes'::regclass AND attname='tsz_5';
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION __setup_cast_functions() RETURNS SETOF TEXT AS $$
BEGIN
  CREATE SCHEMA mathesar_types;
  CREATE FUNCTION mathesar_types.cast_to_numeric(text) RETURNS numeric AS 'SELECT 5' LANGUAGE SQL;
  CREATE FUNCTION mathesar_types.cast_to_text(text) RETURNS text AS 'SELECT ''5''' LANGUAGE SQL;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_get_valid_target_type_strings() RETURNS SETOF TEXT AS $$
BEGIN
  PERFORM __setup_cast_functions();

  RETURN NEXT ok(msar.get_valid_target_type_strings('text') @> '["numeric", "text"]');
  RETURN NEXT is(jsonb_array_length(msar.get_valid_target_type_strings('text')), 2);

  RETURN NEXT ok(msar.get_valid_target_type_strings('text'::regtype::oid) @> '["numeric", "text"]');
  RETURN NEXT is(jsonb_array_length(msar.get_valid_target_type_strings('text'::regtype::oid)), 2);
  
  RETURN NEXT is(msar.get_valid_target_type_strings('interval'), NULL);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_has_dependents() RETURNS SETOF TEXT AS $$
BEGIN
  PERFORM __setup_extract_fkey_cols();
  RETURN NEXT is(msar.has_dependents('"Referent"'::regclass::oid, 1::smallint), true);
  RETURN NEXT is(msar.has_dependents('"Referent"'::regclass::oid, 2::smallint), false);
  RETURN NEXT is(msar.has_dependents('"Referrer"'::regclass::oid, 1::smallint), false);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION __setup_get_column_info() RETURNS SETOF TEXT AS $$
BEGIN
  PERFORM __setup_cast_functions();
  CREATE TABLE column_variety (
    id integer PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
    num_plain numeric NOT NULL,
    var_128 varchar(128),
    txt text DEFAULT 'abc',
    tst timestamp DEFAULT NOW(),
    int_arr integer[4][3],
    num_opt_arr numeric(15, 10)[]
  );
  COMMENT ON COLUMN column_variety.txt IS 'A super comment ;';
  CREATE TABLE needs_cv (
    id integer PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY,
    cv_id integer REFERENCES column_variety(id)
  );
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_get_column_info() RETURNS SETOF TEXT AS $$
BEGIN
  PERFORM __setup_get_column_info();
  RETURN NEXT is(
    msar.get_column_info('column_variety'),
    $j$[
      {
        "id": 1,
        "name": "id",
        "type": "integer",
        "default": {
          "value": "identity",
          "is_dynamic": true
        },
        "nullable": false,
        "description": null,
        "primary_key": true,
        "type_options": null,
        "has_dependents": true
      },
      {
        "id": 2,
        "name": "num_plain",
        "type": "numeric",
        "default": null,
        "nullable": false,
        "description": null,
        "primary_key": false,
        "type_options": {
          "scale": null,
          "precision": null
        },
        "has_dependents": false
      },
      {
        "id": 3,
        "name": "var_128",
        "type": "character varying",
        "default": null,
        "nullable": true,
        "description": null,
        "primary_key": false,
        "type_options": {
          "length": 128
        },
        "has_dependents": false
      },
      {
        "id": 4,
        "name": "txt",
        "type": "text",
        "default": {
          "value": "'abc'::text",
          "is_dynamic": false
        },
        "nullable": true,
        "description": "A super comment ;",
        "primary_key": false,
        "type_options": null,
        "has_dependents": false
      },
      {
        "id": 5,
        "name": "tst",
        "type": "timestamp without time zone",
        "default": {
          "value": "now()",
          "is_dynamic": true
        },
        "nullable": true,
        "description": null,
        "primary_key": false,
        "type_options": {
          "precision": null
        },
        "has_dependents": false
      },
      {
        "id": 6,
        "name": "int_arr",
        "type": "_array",
        "default": null,
        "nullable": true,
        "description": null,
        "primary_key": false,
        "type_options": {
          "item_type": "integer"
        },
        "has_dependents": false
      },
      {
        "id": 7,
        "name": "num_opt_arr",
        "type": "_array",
        "default": null,
        "nullable": true,
        "description": null,
        "primary_key": false,
        "type_options": {
          "scale": 10,
          "item_type": "numeric",
          "precision": 15
        },
        "has_dependents": false
      }
    ]$j$::jsonb
  );
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION __setup_get_table_info() RETURNS SETOF TEXT AS $$
BEGIN
  CREATE SCHEMA pi;
  -- Two tables with one having description
  CREATE TABLE pi.three(id INT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY);
  CREATE TABLE pi.one(id INT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY);
  COMMENT ON TABLE pi.one IS 'first decimal digit of pi';

  CREATE SCHEMA alice;
  -- No tables in the schema  
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_get_table_info() RETURNS SETOF TEXT AS $$
DECLARE
 pi_table_info jsonb;
 alice_table_info jsonb;
BEGIN
  PERFORM __setup_get_table_info();
  SELECT msar.get_table_info('pi') INTO pi_table_info;
  SELECT msar.get_table_info('alice') INTO alice_table_info;

  -- Test table info for schema 'pi'
    -- Check if all the required keys exist in the json blob
    -- Check whether the correct name is returned
    -- Check whether the correct description is returned
  RETURN NEXT is(
    pi_table_info->0 ?& array['oid', 'name', 'schema', 'description'], true
  );
  RETURN NEXT is(
    pi_table_info->0->>'name', 'three'
  );
  RETURN NEXT is(
    pi_table_info->0->>'description', null
  );

  RETURN NEXT is(
    pi_table_info->1 ?& array['oid', 'name', 'schema', 'description'], true
  );
  RETURN NEXT is(
    pi_table_info->1->>'name', 'one'
  );
  RETURN NEXT is(
    pi_table_info->1->>'description', 'first decimal digit of pi'
  );

  -- Test table info for schema 'alice' that contains no tables
  RETURN NEXT is(
    alice_table_info, null
  );
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_get_schemas() RETURNS SETOF TEXT AS $$
DECLARE
  initial_schema_count int;
  foo_schema jsonb;
BEGIN
  -- Get the initial schema count
  SELECT jsonb_array_length(msar.get_schemas()) INTO initial_schema_count;

  -- Create a schema
  CREATE SCHEMA foo;
  -- We should now have one additional schema
  RETURN NEXT is(jsonb_array_length(msar.get_schemas()), initial_schema_count + 1);
  -- Reflect the "foo" schema
  SELECT jsonb_path_query(msar.get_schemas(), '$[*] ? (@.name == "foo")') INTO foo_schema;
  -- We should have a foo schema object
  RETURN NEXT is(jsonb_typeof(foo_schema), 'object');
  -- It should have no description
  RETURN NEXT is(jsonb_typeof(foo_schema->'description'), 'null');
  -- It should have no tables
  RETURN NEXT is((foo_schema->'table_count')::int, 0);

  -- And comment
  COMMENT ON SCHEMA foo IS 'A test schema';
  -- Create two tables
  CREATE TABLE foo.test_table_1 (id serial PRIMARY KEY);
  CREATE TABLE foo.test_table_2 (id serial PRIMARY KEY);
  -- Reflect again
  SELECT jsonb_path_query(msar.get_schemas(), '$[*] ? (@.name == "foo")') INTO foo_schema;
  -- We should see the description we set
  RETURN NEXT is(foo_schema->'description'#>>'{}', 'A test schema');
  -- We should see two tables
  RETURN NEXT is((foo_schema->'table_count')::int, 2);

  -- Drop the tables we created
  DROP TABLE foo.test_table_1;
  DROP TABLE foo.test_table_2;
  -- Reflect the "foo" schema
  SELECT jsonb_path_query(msar.get_schemas(), '$[*] ? (@.name == "foo")') INTO foo_schema;
  -- The "foo" schema should now have no tables
  RETURN NEXT is((foo_schema->'table_count')::int, 0);

  -- Drop the "foo" schema
  DROP SCHEMA foo;
  -- We should now have no "foo" schema
  RETURN NEXT ok(NOT jsonb_path_exists(msar.get_schemas(), '$[*] ? (@.name == "foo")'));
  -- We should see the initial schema count again
  RETURN NEXT is(jsonb_array_length(msar.get_schemas()), initial_schema_count);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_get_roles() RETURNS SETOF TEXT AS $$
DECLARE
  initial_role_count int;
  foo_role jsonb;
  bar_role jsonb;
BEGIN
  SELECT jsonb_array_length(msar.get_roles()) INTO initial_role_count;

  -- Create role and check if role is present in response & count is increased
  CREATE ROLE foo;
  RETURN NEXT is(jsonb_array_length(msar.get_roles()), initial_role_count + 1);
  SELECT jsonb_path_query(msar.get_roles(), '$[*] ? (@.name == "foo")') INTO foo_role;

  -- Check if role has expected properties
  RETURN NEXT is(jsonb_typeof(foo_role), 'object');
  RETURN NEXT is((foo_role->>'super')::boolean, false);
  RETURN NEXT is((foo_role->>'inherits')::boolean, true);
  RETURN NEXT is((foo_role->>'create_role')::boolean, false);
  RETURN NEXT is((foo_role->>'create_db')::boolean, false);
  RETURN NEXT is((foo_role->>'login')::boolean, false);
  RETURN NEXT is(jsonb_typeof(foo_role->'description'), 'null');
  RETURN NEXT is(jsonb_typeof(foo_role->'members'), 'null');

  -- Modify properties and check role again
  ALTER ROLE foo WITH CREATEDB CREATEROLE LOGIN NOINHERIT;
  SELECT jsonb_path_query(msar.get_roles(), '$[*] ? (@.name == "foo")') INTO foo_role;
  RETURN NEXT is((foo_role->>'super')::boolean, false);
  RETURN NEXT is((foo_role->>'inherits')::boolean, false);
  RETURN NEXT is((foo_role->>'create_role')::boolean, true);
  RETURN NEXT is((foo_role->>'create_db')::boolean, true);
  RETURN NEXT is((foo_role->>'login')::boolean, true);

  -- Add comment and check if comment is present
  COMMENT ON ROLE foo IS 'A test role';
  SELECT jsonb_path_query(msar.get_roles(), '$[*] ? (@.name == "foo")') INTO foo_role;
  RETURN NEXT is(foo_role->'description'#>>'{}', 'A test role');

  -- Add members and check result
  CREATE ROLE bar;
  GRANT foo TO bar;
  RETURN NEXT is(jsonb_array_length(msar.get_roles()), initial_role_count + 2);
  SELECT jsonb_path_query(msar.get_roles(), '$[*] ? (@.name == "foo")') INTO foo_role;
  SELECT jsonb_path_query(msar.get_roles(), '$[*] ? (@.name == "bar")') INTO bar_role;
  RETURN NEXT is(jsonb_typeof(foo_role->'members'), 'array');
  RETURN NEXT is(
    foo_role->'members'->0->>'oid', bar_role->>'oid'
  );
  DROP ROLE bar;

  -- Drop role and ensure role is not present in response
  DROP ROLE foo;
  RETURN NEXT ok(NOT jsonb_path_exists(msar.get_roles(), '$[*] ? (@.name == "foo")'));
END;
$$ LANGUAGE plpgsql;


-- msar.format_data --------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION test_format_data() RETURNS SETOF TEXT AS $$
BEGIN
  RETURN NEXT is(msar.format_data('3 Jan, 2021'::date), '2021-01-03 AD');
  RETURN NEXT is(msar.format_data('3 Jan, 23 BC'::date), '0023-01-03 BC');
  RETURN NEXT is(msar.format_data('1 day'::interval), 'P0Y0M1DT0H0M0S');
  RETURN NEXT is(
    msar.format_data('1 year 2 months 3 days 4 hours 5 minutes 6 seconds'::interval),
    'P1Y2M3DT4H5M6S'
  );
  RETURN NEXT is(msar.format_data('1 day 3 hours ago'::interval), 'P0Y0M-1DT-3H0M0S');
  RETURN NEXT is(msar.format_data('1 day -3 hours'::interval), 'P0Y0M1DT-3H0M0S');
  RETURN NEXT is(
    msar.format_data('1 year -1 month 3 days 14 hours -10 minutes 30.4 seconds'::interval),
    'P0Y11M3DT13H50M30.4S'
  );
  RETURN NEXT is(
    msar.format_data('1 year -1 month 3 days 14 hours -10 minutes 30.4 seconds ago'::interval),
    'P0Y-11M-3DT-13H-50M-30.4S'
  );
  RETURN NEXT is(msar.format_data('45 hours 70 seconds'::interval), 'P0Y0M0DT45H1M10S');
  RETURN NEXT is(
    msar.format_data('5 decades 22 years 14 months 1 week 3 days'::interval),
    'P73Y2M10DT0H0M0S'
  );
  RETURN NEXT is(msar.format_data('1 century'::interval), 'P100Y0M0DT0H0M0S');
  RETURN NEXT is(msar.format_data('2 millennia'::interval), 'P2000Y0M0DT0H0M0S');
  RETURN NEXT is(msar.format_data('12:30:45+05:30'::time with time zone), '12:30:45.0+05:30');
  RETURN NEXT is(msar.format_data('12:30:45'::time with time zone), '12:30:45.0Z');
  RETURN NEXT is(
    msar.format_data('12:30:45.123456-08'::time with time zone), '12:30:45.123456-08:00'
  );
  RETURN NEXT is(msar.format_data('12:30'::time without time zone), '12:30:00.0');
  RETURN NEXT is(
    msar.format_data('30 July, 2000 19:15:03.65'::timestamp with time zone),
    '2000-07-30T19:15:03.65Z AD'
  );
  RETURN NEXT is(
    msar.format_data('10000-01-01 00:00:00'::timestamp with time zone),
    '10000-01-01T00:00:00.0Z AD'
  );
  RETURN NEXT is(
    msar.format_data('3 March, 25 BC, 17:30:15+01'::timestamp with time zone),
    '0025-03-03T16:30:15.0Z BC'
  );
  RETURN NEXT is(
    msar.format_data('17654-03-02 01:00:00'::timestamp without time zone),
    '17654-03-02T01:00:00.0 AD'
  );
END;
$$ LANGUAGE plpgsql;

-- msar.list_records_from_table --------------------------------------------------------------------

CREATE OR REPLACE FUNCTION __setup_list_records_table() RETURNS SETOF TEXT AS $$
BEGIN
  CREATE TABLE atable (
    id integer PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    col1 integer,
    col2 varchar,
    col3 json,
    col4 jsonb,
    coltodrop integer
  );
  ALTER TABLE atable DROP COLUMN coltodrop;
  INSERT INTO atable (col1, col2, col3, col4) VALUES
    (5, 'sdflkj', '"s"', '{"a": "val"}'),
    (34, 'sdflfflsk', null, '[1, 2, 3, 4]'),
    (2, 'abcde', '{"k": 3242348}', 'true');
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION test_list_records_from_table() RETURNS SETOF TEXT AS $$
DECLARE
  rel_id oid;
BEGIN
  PERFORM __setup_list_records_table();
  rel_id := 'atable'::regclass::oid;
  RETURN NEXT is(
    msar.list_records_from_table(rel_id, null, null, null, null, null, null),
    $j${
      "count": 3,
      "results": [
        {"1": 1, "2": 5, "3": "sdflkj", "4": "s", "5": {"a": "val"}},
        {"1": 2, "2": 34, "3": "sdflfflsk", "4": null, "5": [1, 2, 3, 4]},
        {"1": 3, "2": 2, "3": "abcde", "4": {"k": 3242348}, "5": true}
      ]
    }$j$
  );
  RETURN NEXT is(
    msar.list_records_from_table(
      rel_id, 2, null, '[{"attnum": 2, "direction": "desc"}]', null, null, null
    ),
    $j${
      "count": 3,
      "results": [
        {"1": 2, "2": 34, "3": "sdflfflsk", "4": null, "5": [1, 2, 3, 4]},
        {"1": 1, "2": 5, "3": "sdflkj", "4": "s", "5": {"a": "val"}}
      ]
    }$j$
  );
  RETURN NEXT is(
    msar.list_records_from_table(
      rel_id, null, 1, '[{"attnum": 1, "direction": "desc"}]', null, null, null
    ),
    $j${
      "count": 3,
      "results": [
        {"1": 2, "2": 34, "3": "sdflfflsk", "4": null, "5": [1, 2, 3, 4]},
        {"1": 1, "2": 5, "3": "sdflkj", "4": "s", "5": {"a": "val"}}
      ]
    }$j$
  );
  CREATE ROLE intern_no_pkey;
  GRANT USAGE ON SCHEMA msar, __msar TO intern_no_pkey;
  GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA msar, __msar TO intern_no_pkey;
  GRANT SELECT (col1, col2, col3, col4) ON TABLE atable TO intern_no_pkey;
  SET ROLE intern_no_pkey;
  RETURN NEXT is(
    msar.list_records_from_table(rel_id, null, null, null, null, null, null),
    $j${
      "count": 3,
      "results": [
        {"2": 2, "3": "abcde", "4": {"k": 3242348}, "5": true},
        {"2": 5, "3": "sdflkj", "4": "s", "5": {"a": "val"}},
        {"2": 34, "3": "sdflfflsk", "4": null, "5": [1, 2, 3, 4]}
      ]
    }$j$
  );
  RETURN NEXT is(
    msar.list_records_from_table(
      rel_id, null, null, '[{"attnum": 3, "direction": "desc"}]', null, null, null
    ),
    $j${
      "count": 3,
      "results": [
        {"2": 5, "3": "sdflkj", "4": "s", "5": {"a": "val"}},
        {"2": 34, "3": "sdflfflsk", "4": null, "5": [1, 2, 3, 4]},
        {"2": 2, "3": "abcde", "4": {"k": 3242348}, "5": true}
      ]
    }$j$
  );
END;
$$ LANGUAGE plpgsql;


-- msar.build_order_by_expr ------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION test_build_order_by_expr() RETURNS SETOF TEXT AS $$
DECLARE
  rel_id oid;
BEGIN
  PERFORM __setup_list_records_table();
  rel_id := 'atable'::regclass::oid;
  RETURN NEXT is(msar.build_order_by_expr(rel_id, null), 'ORDER BY "1" ASC');
  RETURN NEXT is(
    msar.build_order_by_expr(rel_id, '[{"attnum": 1, "direction": "desc"}]'),
    'ORDER BY "1" DESC, "1" ASC'
  );
  RETURN NEXT is(
    msar.build_order_by_expr(
      rel_id, '[{"attnum": 3, "direction": "asc"}, {"attnum": 5, "direction": "DESC"}]'
    ),
    'ORDER BY "3" ASC, "5" DESC, "1" ASC'
  );
  CREATE ROLE intern_no_pkey;
  GRANT USAGE ON SCHEMA msar, __msar TO intern_no_pkey;
  GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA msar, __msar TO intern_no_pkey;
  GRANT SELECT (col1, col2, col3, col4) ON TABLE atable TO intern_no_pkey;
  SET ROLE intern_no_pkey;
  RETURN NEXT is(
    msar.build_order_by_expr(rel_id, null), 'ORDER BY "2" ASC, "3" ASC, "5" ASC'
  );
  SET ROLE NONE;
  REVOKE ALL ON TABLE atable FROM intern_no_pkey;
  SET ROLE intern_no_pkey;
  RETURN NEXT is(msar.build_order_by_expr(rel_id, null), null);
END;
$$ LANGUAGE plpgsql;
