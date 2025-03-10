"""
Classes and functions exposed to the RPC endpoint for managing tables in a database.
"""
from typing import Literal, Optional, TypedDict

from modernrpc.core import rpc_method, REQUEST_KEY
from modernrpc.auth.basic import http_basic_auth_login_required

from db.tables.operations.select import get_table_info, get_table, list_joinable_tables
from db.tables.operations.drop import drop_table_from_database
from db.tables.operations.create import create_table_on_database
from db.tables.operations.alter import alter_table_on_database
from db.tables.operations.import_ import import_csv, get_preview
from mathesar.rpc.columns import CreatableColumnInfo, SettableColumnInfo, PreviewableColumnInfo
from mathesar.rpc.constraints import CreatableConstraintInfo
from mathesar.rpc.exceptions.handlers import handle_rpc_exceptions
from mathesar.rpc.tables.metadata import TableMetaDataBlob
from mathesar.rpc.utils import connect
from mathesar.utils.tables import list_tables_meta_data, get_table_meta_data


class TableInfo(TypedDict):
    """
    Information about a table.

    Attributes:
        oid: The `oid` of the table in the schema.
        name: The name of the table.
        schema: The `oid` of the schema where the table lives.
        description: The description of the table.
        owner_oid: The OID of the direct owner of the table.
        current_role_priv: The privileges available to the user on the table.
        current_role_owns: Whether the current role owns the table.
    """
    oid: int
    name: str
    schema: int
    description: Optional[str]
    owner_oid: int
    current_role_priv: list[
        Literal[
            'SELECT',
            'INSERT',
            'UPDATE',
            'DELETE',
            'TRUNCATE',
            'REFERENCES',
            'TRIGGER'
        ]
    ]
    current_role_owns: bool


class AddedTableInfo(TypedDict):
    """
    Information about a newly created table.

    Attributes:
        oid: The `oid` of the table in the schema.
        name: The name of the table.
    """
    oid: int
    name: str


class SettableTableInfo(TypedDict):
    """
    Information about a table, restricted to settable fields.

    When possible, Passing `null` for a key will clear the underlying
    setting. E.g.,

    - `description = null` clears the table description.

    Setting any of `name`, `columns` to `null` is a noop.

    Attributes:
        name: The new name of the table.
        description: The description of the table.
        columns: A list describing desired column alterations.
    """
    name: Optional[str]
    description: Optional[str]
    columns: Optional[list[SettableColumnInfo]]


class JoinableTableRecord(TypedDict):
    """
    Information about a singular joinable table.

    Attributes:
        base: The OID of the table from which the paths start
        target: The OID of the table where the paths end.
        join_path: A list describing joinable paths in the following form:
            [
              [[L_oid0, L_attnum0], [R_oid0, R_attnum0]],
              [[L_oid1, L_attnum1], [R_oid1, R_attnum1]],
              [[L_oid2, L_attnum2], [R_oid2, R_attnum2]],
              ...
            ]

            Here, [L_oidN, L_attnumN] represents the left column of a join, and [R_oidN, R_attnumN] the right.
        fkey_path: Same as `join_path` expressed in terms of foreign key constraints in the following form:
            [
                [constraint_id0, reversed],
                [constraint_id1, reversed],
            ]

            In this form, `constraint_idN` is a foreign key constraint, and `reversed` is a boolean giving
            whether to travel from referrer to referant (when False) or from referant to referrer (when True).
        depth: Specifies how far to search for joinable tables.
        multiple_results: Specifies whether the path included is reversed.
    """
    base: int
    target: int
    join_path: list
    fkey_path: list
    depth: int
    multiple_results: bool

    @classmethod
    def from_dict(cls, joinables):
        return cls(
            base=joinables["base"],
            target=joinables["target"],
            join_path=joinables["join_path"],
            fkey_path=joinables["fkey_path"],
            depth=joinables["depth"],
            multiple_results=joinables["multiple_results"]
        )


class JoinableTableInfo(TypedDict):
    """
    Information about joinable table(s).

    Attributes:
        joinable_tables: List of reachable joinable table(s) from a base table.
        target_table_info: Additional info about target table(s) and its column(s).
    """
    joinable_tables: list[JoinableTableRecord]
    target_table_info: list

    @classmethod
    def from_dict(cls, joinable_dict):
        return cls(
            joinable_tables=[JoinableTableRecord.from_dict(j) for j in joinable_dict["joinable_tables"]],
            target_table_info=joinable_dict["target_table_info"]
        )


@rpc_method(name="tables.list")
@http_basic_auth_login_required
@handle_rpc_exceptions
def list_(*, schema_oid: int, database_id: int, **kwargs) -> list[TableInfo]:
    """
    List information about tables for a schema. Exposed as `list`.

    Args:
        schema_oid: Identity of the schema in the user's database.
        database_id: The Django id of the database containing the table.

    Returns:
        A list of table details.
    """
    user = kwargs.get(REQUEST_KEY).user
    with connect(database_id, user) as conn:
        raw_table_info = get_table_info(schema_oid, conn)
    return [
        TableInfo(tab) for tab in raw_table_info
    ]


@rpc_method(name="tables.get")
@http_basic_auth_login_required
@handle_rpc_exceptions
def get(*, table_oid: int, database_id: int, **kwargs) -> TableInfo:
    """
    List information about a table for a schema.

    Args:
        table_oid: Identity of the table in the user's database.
        database_id: The Django id of the database containing the table.

    Returns:
        Table details for a given table oid.
    """
    user = kwargs.get(REQUEST_KEY).user
    with connect(database_id, user) as conn:
        raw_table_info = get_table(table_oid, conn)
    return TableInfo(raw_table_info)


@rpc_method(name="tables.add")
@http_basic_auth_login_required
@handle_rpc_exceptions
def add(
    *,
    schema_oid: int,
    database_id: int,
    table_name: str = None,
    column_data_list: list[CreatableColumnInfo] = [],
    constraint_data_list: list[CreatableConstraintInfo] = [],
    comment: str = None,
    **kwargs
) -> AddedTableInfo:
    """
    Add a table with a default id column.

    Args:
        schema_oid: Identity of the schema in the user's database.
        database_id: The Django id of the database containing the table.
        table_name: Name of the table to be created.
        column_data_list: A list describing columns to be created for the new table, in order.
        constraint_data_list: A list describing constraints to be created for the new table.
        comment: The comment for the new table.

    Returns:
        The `oid` & `name` of the created table.
    """
    user = kwargs.get(REQUEST_KEY).user
    with connect(database_id, user) as conn:
        created_table_oid = create_table_on_database(
            table_name, schema_oid, conn, column_data_list, constraint_data_list, comment
        )
    return created_table_oid


@rpc_method(name="tables.delete")
@http_basic_auth_login_required
@handle_rpc_exceptions
def delete(
    *, table_oid: int, database_id: int, cascade: bool = False, **kwargs
) -> str:
    """
    Delete a table from a schema.

    Args:
        table_oid: Identity of the table in the user's database.
        database_id: The Django id of the database containing the table.
        cascade: Whether to drop the dependent objects.

    Returns:
        The name of the dropped table.
    """
    user = kwargs.get(REQUEST_KEY).user
    with connect(database_id, user) as conn:
        return drop_table_from_database(table_oid, conn, cascade)


@rpc_method(name="tables.patch")
@http_basic_auth_login_required
@handle_rpc_exceptions
def patch(
    *, table_oid: str, table_data_dict: SettableTableInfo, database_id: int, **kwargs
) -> str:
    """
    Alter details of a preexisting table in a database.

    Args:
        table_oid: Identity of the table whose name, description or columns we'll modify.
        table_data_dict: A list describing desired table alterations.
        database_id: The Django id of the database containing the table.

    Returns:
        The name of the altered table.
    """
    user = kwargs.get(REQUEST_KEY).user
    with connect(database_id, user) as conn:
        return alter_table_on_database(table_oid, table_data_dict, conn)


@rpc_method(name="tables.import")
@http_basic_auth_login_required
@handle_rpc_exceptions
def import_(
    *,
    data_file_id: int,
    schema_oid: int,
    database_id: int,
    table_name: str = None,
    comment: str = None,
    **kwargs
) -> AddedTableInfo:
    """
    Import a CSV/TSV into a table.

    Args:
        data_file_id: The Django id of the DataFile containing desired CSV/TSV.
        schema_oid: Identity of the schema in the user's database.
        database_id: The Django id of the database containing the table.
        table_name: Name of the table to be imported.
        comment: The comment for the new table.

    Returns:
        The `oid` and `name` of the created table.
    """
    user = kwargs.get(REQUEST_KEY).user
    with connect(database_id, user) as conn:
        return import_csv(data_file_id, table_name, schema_oid, conn, comment)


@rpc_method(name="tables.get_import_preview")
@http_basic_auth_login_required
@handle_rpc_exceptions
def get_import_preview(
    *,
    table_oid: int,
    columns: list[PreviewableColumnInfo],
    database_id: int,
    limit: int = 20,
    **kwargs
) -> list[dict]:
    """
    Preview an imported table.

    Args:
        table_oid: Identity of the imported table in the user's database.
        columns: List of settings describing the casts to be applied to the columns.
        database_id: The Django id of the database containing the table.
        limit: The upper limit for the number of records to return.

    Returns:
        The records from the specified columns of the table.
    """
    user = kwargs.get(REQUEST_KEY).user
    with connect(database_id, user) as conn:
        return get_preview(table_oid, columns, conn, limit)


@rpc_method(name="tables.list_joinable")
@http_basic_auth_login_required
@handle_rpc_exceptions
def list_joinable(
    *,
    table_oid: int,
    database_id: int,
    max_depth: int = 3,
    **kwargs
) -> JoinableTableInfo:
    """
    List details for joinable tables.

    Args:
        table_oid: Identity of the table to get joinable tables for.
        database_id: The Django id of the database containing the table.
        max_depth: Specifies how far to search for joinable tables.

    Returns:
        Joinable table details for a given table.
    """
    user = kwargs.get(REQUEST_KEY).user
    with connect(database_id, user) as conn:
        joinable_dict = list_joinable_tables(table_oid, conn, max_depth)
        return JoinableTableInfo.from_dict(joinable_dict)


@rpc_method(name="tables.list_with_metadata")
@http_basic_auth_login_required
@handle_rpc_exceptions
def list_with_metadata(*, schema_oid: int, database_id: int, **kwargs) -> list:
    """
    List tables in a schema, along with the metadata associated with each table

    Args:
        schema_oid: PostgreSQL OID of the schema containing the tables.
        database_id: The Django id of the database containing the table.

    Returns:
        A list of table details along with metadata.
    """
    user = kwargs.get(REQUEST_KEY).user
    with connect(database_id, user) as conn:
        tables = get_table_info(schema_oid, conn)

    metadata_records = list_tables_meta_data(database_id)
    metadata_map = {
        r.table_oid: TableMetaDataBlob.from_model(r) for r in metadata_records
    }

    return [table | {"metadata": metadata_map.get(table["oid"])} for table in tables]


@rpc_method(name="tables.get_with_metadata")
@http_basic_auth_login_required
@handle_rpc_exceptions
def get_with_metadata(*, table_oid: int, database_id: int, **kwargs) -> dict:
    """
    Get information about a table in a schema, along with the associated table metadata.

    Args:
        table_oid: The OID of the table in the user's database.
        database_id: The Django id of the database containing the table.

    Returns:
        A dict describing table details along with its metadata.
    """
    user = kwargs.get(REQUEST_KEY).user
    with connect(database_id, user) as conn:
        table = get_table(table_oid, conn)

    raw_metadata = get_table_meta_data(table_oid, database_id)
    return TableInfo(table) | {"metadata": TableMetaDataBlob.from_model(raw_metadata)}
