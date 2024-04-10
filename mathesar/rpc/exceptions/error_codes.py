"""
This file holds mappings recording a unique error code for (hopefully)
all exceptions that Mathesar could possibly throw.

The purpose is to let us send a code with an error response in case an
RPC function call fails. The codes are organized by the underlying
code section that could throw the exception:

- builtins: -31xxx
- psycopg or psycopg2: -30xxx
- django: -29xxx
- mathesar (our code): -28xxx
- db (our code): -27xxx
- SQLAlchemy: -26xxx
- other: -25xxx

Unknown errors return a "round number" code, so an unknown builtin error
gets the code 31000.

THESE ENUMs ARE INITIALLY AUTO-GENERATED!
"""
from frozendict import frozendict

UNKNOWN_KEY = "UNKNOWN"


def get_error_code(err):
    err_module = err.__class__.__module__
    err_name = err.__class__.__name__
    if err_module.startswith("builtin"):
        return builtin_error_map.get(err_name, builtin_error_map["UNKNOWN"])
    elif err_module.startswith("psycopg"):
        return psycopg_error_map.get(err_name, psycopg_error_map["UNKNOWN"])
    elif err_module.startswith("django"):
        return django_error_map.get(err_name, django_error_map["UNKNOWN"])
    elif err_module.startswith("mathesar"):
        return mathesar_error_map.get(err_name, mathesar_error_map["UNKNOWN"])
    elif err_module.startswith("db."):
        return dblib_error_map.get(err_name, dblib_error_map["UNKNOWN"])
    elif err_module.startswith("sqlalchemy"):
        return sqlalch_error_map.get(err_name, sqlalch_error_map["UNKNOWN"])
    else:
        return other_error_map.get(err_name)


builtin_error_map = frozendict({
    UNKNOWN_KEY: -31000,
    "ArithmeticError": -31001,
    "AssertionError": -31002,
    "AttributeError": -31003,
    "BlockingIOError": -31004,
    "BrokenPipeError": -31005,
    "BufferError": -31006,
    "BytesWarning": -31007,
    "ChildProcessError": -31008,
    "ConnectionAbortedError": -31009,
    "ConnectionError": -31010,
    "ConnectionRefusedError": -31011,
    "ConnectionResetError": -31012,
    "DeprecationWarning": -31013,
    "EOFError": -31014,
    "FileExistsError": -31015,
    "FileNotFoundError": -31016,
    "FloatingPointError": -31017,
    "FutureWarning": -31018,
    "ImportError": -31019,
    "ImportWarning": -31020,
    "IndentationError": -31021,
    "IndexError": -31022,
    "InterruptedError": -31023,
    "IsADirectoryError": -31024,
    "KeyError": -31025,
    "LookupError": -31026,
    "MemoryError": -31027,
    "ModuleNotFoundError": -31028,
    "NameError": -31029,
    "NotADirectoryError": -31030,
    "NotImplementedError": -31031,
    "OSError": -31032,
    "OverflowError": -31033,
    "PendingDeprecationWarning": -31034,
    "PermissionError": -31035,
    "ProcessLookupError": -31036,
    "RecursionError": -31037,
    "ReferenceError": -31038,
    "ResourceWarning": -31039,
    "RuntimeError": -31040,
    "RuntimeWarning": -31041,
    "StopAsyncIteration": -31042,
    "StopIteration": -31043,
    "SyntaxError": -31044,
    "SyntaxWarning": -31045,
    "SystemError": -31046,
    "TabError": -31047,
    "TimeoutError": -31048,
    "TypeError": -31049,
    "UnboundLocalError": -31050,
    "UnicodeDecodeError": -31051,
    "UnicodeEncodeError": -31052,
    "UnicodeError": -31053,
    "UnicodeTranslateError": -31054,
    "UnicodeWarning": -31055,
    "UserWarning": -31056,
    "ValueError": -31057,
    "Warning": -31058,
    "ZeroDivisionError": -31059,
})

psycopg_error_map = frozendict({
    UNKNOWN_KEY: -30000,
    "ActiveSqlTransaction": -30001,
    "AdminShutdown": -30002,
    "AmbiguousAlias": -30003,
    "AmbiguousColumn": -30004,
    "AmbiguousFunction": -30005,
    "AmbiguousParameter": -30006,
    "ArraySubscriptError": -30007,
    "AssertFailure": -30008,
    "BadCopyFileFormat": -30009,
    "BranchTransactionAlreadyActive": -30010,
    "CannotCoerce": -30011,
    "CannotConnectNow": -30012,
    "CantChangeRuntimeParam": -30013,
    "CardinalityViolation": -30014,
    "CaseNotFound": -30015,
    "CharacterNotInRepertoire": -30016,
    "CheckViolation": -30017,
    "CollationMismatch": -30018,
    "ConfigFileError": -30019,
    "ConfigurationLimitExceeded": -30020,
    "ConnectionDoesNotExist": -30021,
    "ConnectionException": -30022,
    "ConnectionFailure": -30023,
    "ConnectionTimeout": -30024,
    "ContainingSqlNotPermitted": -30025,
    "CrashShutdown": -30026,
    "DataCorrupted": -30027,
    "DataError": -30028,
    "DataException": -30029,
    "DatabaseDropped": -30030,
    "DatabaseError": -30031,
    "DatatypeMismatch": -30032,
    "DatetimeFieldOverflow": -30033,
    "DeadlockDetected": -30034,
    "DependentObjectsStillExist": -30035,
    "DependentPrivilegeDescriptorsStillExist": -30036,
    "DiagnosticsException": -30037,
    "DiskFull": -30038,
    "DivisionByZero": -30039,
    "DuplicateAlias": -30040,
    "DuplicateColumn": -30041,
    "DuplicateCursor": -30042,
    "DuplicateDatabase": -30043,
    "DuplicateFile": -30044,
    "DuplicateFunction": -30045,
    "DuplicateJsonObjectKeyValue": -30046,
    "DuplicateObject": -30047,
    "DuplicatePreparedStatement": -30048,
    "DuplicateSchema": -30049,
    "DuplicateTable": -30050,
    "Error": -30051,
    "ErrorInAssignment": -30052,
    "EscapeCharacterConflict": -30053,
    "EventTriggerProtocolViolated": -30054,
    "ExclusionViolation": -30055,
    "ExternalRoutineException": -30056,
    "ExternalRoutineInvocationException": -30057,
    "FdwColumnNameNotFound": -30058,
    "FdwDynamicParameterValueNeeded": -30059,
    "FdwError": -30060,
    "FdwFunctionSequenceError": -30061,
    "FdwInconsistentDescriptorInformation": -30062,
    "FdwInvalidAttributeValue": -30063,
    "FdwInvalidColumnName": -30064,
    "FdwInvalidColumnNumber": -30065,
    "FdwInvalidDataType": -30066,
    "FdwInvalidDataTypeDescriptors": -30067,
    "FdwInvalidDescriptorFieldIdentifier": -30068,
    "FdwInvalidHandle": -30069,
    "FdwInvalidOptionIndex": -30070,
    "FdwInvalidOptionName": -30071,
    "FdwInvalidStringFormat": -30072,
    "FdwInvalidStringLengthOrBufferLength": -30073,
    "FdwInvalidUseOfNullPointer": -30074,
    "FdwNoSchemas": -30075,
    "FdwOptionNameNotFound": -30076,
    "FdwOutOfMemory": -30077,
    "FdwReplyHandle": -30078,
    "FdwSchemaNotFound": -30079,
    "FdwTableNotFound": -30080,
    "FdwTooManyHandles": -30081,
    "FdwUnableToCreateExecution": -30082,
    "FdwUnableToCreateReply": -30083,
    "FdwUnableToEstablishConnection": -30084,
    "FeatureNotSupported": -30085,
    "FloatingPointException": -30086,
    "ForeignKeyViolation": -30087,
    "FunctionExecutedNoReturnStatement": -30088,
    "GeneratedAlways": -30089,
    "GroupingError": -30090,
    "HeldCursorRequiresSameIsolationLevel": -30091,
    "IdleInTransactionSessionTimeout": -30092,
    "IdleSessionTimeout": -30093,
    "InFailedSqlTransaction": -30094,
    "InappropriateAccessModeForBranchTransaction": -30095,
    "InappropriateIsolationLevelForBranchTransaction": -30096,
    "IndeterminateCollation": -30097,
    "IndeterminateDatatype": -30098,
    "IndexCorrupted": -30099,
    "IndicatorOverflow": -30100,
    "InsufficientPrivilege": -30101,
    "InsufficientResources": -30102,
    "IntegrityConstraintViolation": -30103,
    "IntegrityError": -30104,
    "InterfaceError": -30105,
    "InternalError": -30106,
    "InternalError_": -30107,
    "IntervalFieldOverflow": -30108,
    "InvalidArgumentForLogarithm": -30109,
    "InvalidArgumentForNthValueFunction": -30110,
    "InvalidArgumentForNtileFunction": -30111,
    "InvalidArgumentForPowerFunction": -30112,
    "InvalidArgumentForSqlJsonDatetimeFunction": -30113,
    "InvalidArgumentForWidthBucketFunction": -30114,
    "InvalidAuthorizationSpecification": -30115,
    "InvalidBinaryRepresentation": -30116,
    "InvalidCatalogName": -30117,
    "InvalidCharacterValueForCast": -30118,
    "InvalidColumnDefinition": -30119,
    "InvalidColumnReference": -30120,
    "InvalidCursorDefinition": -30121,
    "InvalidCursorName": -30122,
    "InvalidCursorState": -30123,
    "InvalidDatabaseDefinition": -30124,
    "InvalidDatetimeFormat": -30125,
    "InvalidEscapeCharacter": -30126,
    "InvalidEscapeOctet": -30127,
    "InvalidEscapeSequence": -30128,
    "InvalidForeignKey": -30129,
    "InvalidFunctionDefinition": -30130,
    "InvalidGrantOperation": -30131,
    "InvalidGrantor": -30132,
    "InvalidIndicatorParameterValue": -30133,
    "InvalidJsonText": -30134,
    "InvalidLocatorSpecification": -30135,
    "InvalidName": -30136,
    "InvalidObjectDefinition": -30137,
    "InvalidParameterValue": -30138,
    "InvalidPassword": -30139,
    "InvalidPrecedingOrFollowingSize": -30140,
    "InvalidPreparedStatementDefinition": -30141,
    "InvalidRecursion": -30142,
    "InvalidRegularExpression": -30143,
    "InvalidRoleSpecification": -30144,
    "InvalidRowCountInLimitClause": -30145,
    "InvalidRowCountInResultOffsetClause": -30146,
    "InvalidSavepointSpecification": -30147,
    "InvalidSchemaDefinition": -30148,
    "InvalidSchemaName": -30149,
    "InvalidSqlJsonSubscript": -30150,
    "InvalidSqlStatementName": -30151,
    "InvalidSqlstateReturned": -30152,
    "InvalidTableDefinition": -30153,
    "InvalidTablesampleArgument": -30154,
    "InvalidTablesampleRepeat": -30155,
    "InvalidTextRepresentation": -30156,
    "InvalidTimeZoneDisplacementValue": -30157,
    "InvalidTransactionInitiation": -30158,
    "InvalidTransactionState": -30159,
    "InvalidTransactionTermination": -30160,
    "InvalidUseOfEscapeCharacter": -30161,
    "InvalidXmlComment": -30162,
    "InvalidXmlContent": -30163,
    "InvalidXmlDocument": -30164,
    "InvalidXmlProcessingInstruction": -30165,
    "IoError": -30166,
    "LocatorException": -30167,
    "LockFileExists": -30168,
    "LockNotAvailable": -30169,
    "ModifyingSqlDataNotPermitted": -30170,
    "ModifyingSqlDataNotPermittedExt": -30171,
    "MoreThanOneSqlJsonItem": -30172,
    "MostSpecificTypeMismatch": -30173,
    "NameTooLong": -30174,
    "NoActiveSqlTransaction": -30175,
    "NoActiveSqlTransactionForBranchTransaction": -30176,
    "NoAdditionalDynamicResultSetsReturned": -30177,
    "NoData": -30178,
    "NoDataFound": -30179,
    "NoSqlJsonItem": -30180,
    "NonNumericSqlJsonItem": -30181,
    "NonUniqueKeysInAJsonObject": -30182,
    "NonstandardUseOfEscapeCharacter": -30183,
    "NotAnXmlDocument": -30184,
    "NotNullViolation": -30185,
    "NotSupportedError": -30186,
    "NullValueNoIndicatorParameter": -30187,
    "NullValueNotAllowed": -30188,
    "NullValueNotAllowedExt": -30189,
    "NumericValueOutOfRange": -30190,
    "ObjectInUse": -30191,
    "ObjectNotInPrerequisiteState": -30192,
    "OperationalError": -30193,
    "OperatorIntervention": -30194,
    "OutOfMemory": -30195,
    "OutOfOrderTransactionNesting": -30196,
    "PipelineAborted": -30197,
    "PlpgsqlError": -30198,
    "ProgramLimitExceeded": -30199,
    "ProgrammingError": -30200,
    "ProhibitedSqlStatementAttempted": -30201,
    "ProhibitedSqlStatementAttemptedExt": -30202,
    "ProtocolViolation": -30203,
    "QueryCanceled": -30204,
    "QueryCanceledError": -30205,
    "RaiseException": -30206,
    "ReadOnlySqlTransaction": -30207,
    "ReadingSqlDataNotPermitted": -30208,
    "ReadingSqlDataNotPermittedExt": -30209,
    "ReservedName": -30210,
    "RestrictViolation": -30211,
    "Rollback": -30212,
    "SavepointException": -30213,
    "SchemaAndDataStatementMixingNotSupported": -30214,
    "SequenceGeneratorLimitExceeded": -30215,
    "SerializationFailure": -30216,
    "SingletonSqlJsonItemRequired": -30217,
    "SnapshotTooOld": -30218,
    "SqlJsonArrayNotFound": -30219,
    "SqlJsonItemCannotBeCastToTargetType": -30220,
    "SqlJsonMemberNotFound": -30221,
    "SqlJsonNumberNotFound": -30222,
    "SqlJsonObjectNotFound": -30223,
    "SqlJsonScalarRequired": -30224,
    "SqlRoutineException": -30225,
    "SqlStatementNotYetComplete": -30226,
    "SqlclientUnableToEstablishSqlconnection": -30227,
    "SqlserverRejectedEstablishmentOfSqlconnection": -30228,
    "SrfProtocolViolated": -30229,
    "StackedDiagnosticsAccessedWithoutActiveHandler": -30230,
    "StatementCompletionUnknown": -30231,
    "StatementTooComplex": -30232,
    "StopReplication": -30233,
    "StringDataLengthMismatch": -30234,
    "StringDataRightTruncation": -30235,
    "SubstringError": -30236,
    "SyntaxError": -30237,
    "SyntaxErrorOrAccessRuleViolation": -30238,
    "SystemError": -30239,
    "TooManyArguments": -30240,
    "TooManyColumns": -30241,
    "TooManyConnections": -30242,
    "TooManyJsonArrayElements": -30243,
    "TooManyJsonObjectMembers": -30244,
    "TooManyRows": -30245,
    "TransactionIntegrityConstraintViolation": -30246,
    "TransactionResolutionUnknown": -30247,
    "TransactionRollback": -30248,
    "TransactionRollbackError": -30249,
    "TriggerProtocolViolated": -30250,
    "TriggeredActionException": -30251,
    "TriggeredDataChangeViolation": -30252,
    "TrimError": -30253,
    "UndefinedColumn": -30254,
    "UndefinedFile": -30255,
    "UndefinedFunction": -30256,
    "UndefinedObject": -30257,
    "UndefinedParameter": -30258,
    "UndefinedTable": -30259,
    "UniqueViolation": -30260,
    "UnsafeNewEnumValueUsage": -30261,
    "UnterminatedCString": -30262,
    "UntranslatableCharacter": -30263,
    "Warning": -30264,
    "WindowingError": -30265,
    "WithCheckOptionViolation": -30266,
    "WrongObjectType": -30267,
    "ZeroLengthCharacterString": -30268,
})


django_error_map = frozendict({
    UNKNOWN_KEY: -29000,
    "AlreadyRegistered": -29001,
    "AmbiguityError": -29002,
    "AppRegistryNotReady": -29003,
    "BadHeaderError": -29004,
    "BadMigrationError": -29005,
    "BadRequest": -29006,
    "BadSignature": -29007,
    "CacheKeyWarning": -29008,
    "CircularDependencyError": -29009,
    "CommandError": -29010,
    "ConnectionDoesNotExist": -29011,
    "ContentNotRenderedError": -29012,
    "ContextPopException": -29013,
    "CyclicDependencyError": -29014,
    "DataError": -29015,
    "DatabaseError": -29016,
    "DatabaseOperationForbidden": -29017,
    "DeleteViewCustomDeleteWarning": -29018,
    "DeserializationError": -29019,
    "DisallowedHost": -29020,
    "DisallowedModelAdminLookup": -29021,
    "DisallowedModelAdminToField": -29022,
    "DisallowedRedirect": -29023,
    "DjangoUnicodeDecodeError": -29024,
    "DoesNotExist": -29025,
    "EmptyPage": -29026,
    "EmptyResultSet": -29027,
    "Error": -29028,
    "ExceptionCycleWarning": -29029,
    "FieldDoesNotExist": -29030,
    "FieldError": -29031,
    "FieldIsAForeignKeyColumnName": -29032,
    "FieldLookupError": -29033,
    "FullResultSet": -29034,
    "GenericViewError": -29035,
    "HTMLParseError": -29036,
    "Http404": -29037,
    "ImproperlyConfigured": -29038,
    "InconsistentMigrationHistory": -29039,
    "IncorrectLookupParameters": -29040,
    "InputStreamExhausted": -29041,
    "IntegrityError": -29042,
    "InterfaceError": -29043,
    "InternalError": -29044,
    "InvalidAlgorithm": -29045,
    "InvalidBasesError": -29046,
    "InvalidCacheBackendError": -29047,
    "InvalidCacheKey": -29048,
    "InvalidMigrationPlan": -29049,
    "InvalidPage": -29050,
    "InvalidStorageError": -29051,
    "InvalidTemplateEngineError": -29052,
    "InvalidTemplateLibrary": -29053,
    "InvalidTokenFormat": -29054,
    "IrreversibleError": -29055,
    "M2MDeserializationError": -29056,
    "MediaOrderConflictWarning": -29057,
    "MessageFailure": -29058,
    "MiddlewareNotUsed": -29059,
    "MigrationNotice": -29060,
    "MigrationSchemaMissing": -29061,
    "MultiJoin": -29062,
    "MultiPartParserError": -29063,
    "MultiValueDictKeyError": -29064,
    "MultipleObjectsReturned": -29065,
    "NoReverseMatch": -29066,
    "NodeNotFoundError": -29067,
    "NotRegistered": -29068,
    "NotRelationField": -29069,
    "NotSupportedError": -29070,
    "ObjectDoesNotExist": -29071,
    "OperationalError": -29072,
    "PageNotAnInteger": -29073,
    "PermissionDenied": -29074,
    "ProgrammingError": -29075,
    "ProtectedError": -29076,
    "RawPostDataException": -29077,
    "RedirectCycleError": -29078,
    "RejectRequest": -29079,
    "RemovedInDjango50Warning": -29080,
    "RemovedInDjango51Warning": -29081,
    "RemovedInDjangoFilter25Warning": -29082,
    "RequestAborted": -29083,
    "RequestDataTooBig": -29084,
    "Resolver404": -29085,
    "RestrictedError": -29086,
    "SerializationError": -29087,
    "SerializerDoesNotExist": -29088,
    "SignatureExpired": -29089,
    "SkipFile": -29090,
    "StopFutureHandlers": -29091,
    "StopUpload": -29092,
    "SuspiciousFileOperation": -29093,
    "SuspiciousMultipartForm": -29094,
    "SuspiciousOperation": -29095,
    "SynchronousOnlyOperation": -29096,
    "SystemCheckError": -29097,
    "TemplateDoesNotExist": -29098,
    "TemplateSyntaxError": -29099,
    "TooManyFieldsSent": -29100,
    "TooManyFilesSent": -29101,
    "TransactionManagementError": -29102,
    "TranslatorCommentWarning": -29103,
    "UnorderedObjectListWarning": -29104,
    "UnreadablePostError": -29105,
    "UploadFileException": -29106,
    "ValidationError": -29107,
    "VariableDoesNotExist": -29108,
    "ViewDoesNotExist": -29109,
    "WatchmanUnavailable": -29110,
})

mathesar_error_map = frozendict({
    UNKNOWN_KEY: -28000,
    "BadDBCredentials": -28001,
    "ColumnSizeMismatchAPIException": -28002,
    "ConstraintColumnEmptyAPIException": -28003,
    "DeletedColumnAccess": -28004,
    "DeletedColumnAccessAPIException": -28005,
    "DictHasBadKeys": -28006,
    "DistinctColumnRequiredAPIException": -28007,
    "DoesNotExist": -28008,
    "DuplicateUIQueryInSchemaAPIException": -28009,
    "EditingPublicSchemaIsDisallowed": -28010,
    "GenericAPIException": -28011,
    "IncompatibleFractionDigitValuesAPIException": -28012,
    "IncorrectOldPassword": -28013,
    "IntegrityAPIException": -28014,
    "InvalidColumnOrder": -28015,
    "InvalidDBConnection": -28016,
    "InvalidLinkChoiceAPIException": -28017,
    "InvalidPrefetch": -28018,
    "InvalidTableName": -28019,
    "InvalidValueType": -28020,
    "MathesarAPIException": -28021,
    "MathesarValidationException": -28022,
    "MethodNotAllowedAPIException": -28023,
    "MoneyDisplayOptionValueConflictAPIException": -28024,
    "MultipleDataFileAPIException": -28025,
    "MultipleObjectsReturned": -28026,
    "NetworkException": -28027,
    "NotFoundAPIException": -28028,
    "ProgrammingAPIException": -28029,
    "TypeErrorAPIException": -28030,
    "UnknownDatabaseTypeIdentifier": -28031,
    "UnsupportedConstraintAPIException": -28032,
    "UnsupportedInstallationDatabase": -28033,
    "ValueAPIException": -28034,
})

dblib_error_map = frozendict({
    UNKNOWN_KEY: -27000,
    "BadDBFunctionFormat": -27001,
    "BadGroupFormat": -27002,
    "BadSortFormat": -27003,
    "ColumnMappingsNotFound": -27004,
    "DBFunctionException": -27005,
    "DagCycleError": -27006,
    "DynamicDefaultWarning": -27007,
    "ExclusionError": -27008,
    "ForeignKeyError": -27009,
    "GroupFieldNotFound": -27010,
    "InvalidDate": -27011,
    "InvalidDateFormat": -27012,
    "InvalidDefaultError": -27013,
    "InvalidGroupType": -27014,
    "InvalidTypeError": -27015,
    "InvalidTypeOptionError": -27016,
    "InvalidTypeParameters": -27017,
    "NotNullError": -27018,
    "ReferencedColumnsDontExist": -27019,
    "SortFieldNotFound": -27020,
    "TypeMismatchError": -27021,
    "UndefinedFunction": -27022,
    "UniqueValueError": -27023,
    "UnknownDBFunctionID": -27024,
    "UnsupportedTypeException": -27025,
})

sqlalch_error_map = frozendict({
    UNKNOWN_KEY: -26000,
    "AmbiguousForeignKeysError": -26001,
    "ArgumentError": -26002,
    "AwaitRequired": -26003,
    "CircularDependencyError": -26004,
    "CompileError": -26005,
    "DBAPIError": -26006,
    "DataError": -26007,
    "DatabaseError": -26008,
    "DisconnectionError": -26009,
    "Empty": -26010,
    "Error": -26011,
    "Full": -26012,
    "IdentifierError": -26013,
    "IntegrityError": -26014,
    "InterfaceError": -26015,
    "InternalError": -26016,
    "InternalServerError": -26017,
    "InvalidCachedStatementError": -26018,
    "InvalidRequestError": -26019,
    "InvalidatePoolError": -26020,
    "MissingGreenlet": -26021,
    "MovedIn20Warning": -26022,
    "MultipleResultsFound": -26023,
    "NoForeignKeysError": -26024,
    "NoInspectionAvailable": -26025,
    "NoReferenceError": -26026,
    "NoReferencedColumnError": -26027,
    "NoReferencedTableError": -26028,
    "NoResultFound": -26029,
    "NoSuchColumnError": -26030,
    "NoSuchModuleError": -26031,
    "NoSuchTableError": -26032,
    "NotSupportedError": -26033,
    "ObjectNotExecutableError": -26034,
    "OperationalError": -26035,
    "PendingRollbackError": -26036,
    "ProgrammingError": -26037,
    "RemovedIn20Warning": -26038,
    "ResourceClosedError": -26039,
    "SADeprecationWarning": -26040,
    "SAPendingDeprecationWarning": -26041,
    "SAWarning": -26042,
    "SQLAlchemyError": -26043,
    "StatementError": -26044,
    "TimeoutError": -26045,
    "UnboundExecutionError": -26046,
    "UnreflectableTableError": -26047,
    "UnsupportedCompilationError": -26048,
    "Warning": -26049,
})

other_error_map = frozendict({
    UNKNOWN_KEY: -25000,
    "APIException": -25001,
    "AbsoluteLinkError": -25002,
    "AbsolutePathError": -25003,
    "AbstractMethodError": -25004,
    "AccessorRegistrationWarning": -25005,
    "AddressValueError": -25006,
    "AlreadyFinalized": -25007,
    "AlreadyUpdated": -25008,
    "AmbiguousTimeError": -25009,
    "ApplyTypeError": -25010,
    "ArgumentError": -25011,
    "ArgumentTypeError": -25012,
    "AttributeConflictWarning": -25013,
    "AuthenticationFailed": -25014,
    "AxisError": -25015,
    "BadGzipFile": -25016,
    "BadStatusLine": -25017,
    "BadZipFile": -25018,
    "BidictException": -25019,
    "BodyNotHttplibCompatible": -25020,
    "BoundaryError": -25021,
    "BrokenBarrierError": -25022,
    "BrokenExecutor": -25023,
    "BrokenThreadPool": -25024,
    "BuiltinSignatureError": -25025,
    "CCompilerError": -25026,
    "CSSWarning": -25027,
    "CalledProcessError": -25028,
    "CancelledError": -25029,
    "CannotSendHeader": -25030,
    "CannotSendRequest": -25031,
    "CategoricalConversionWarning": -25032,
    "CertificateError": -25033,
    "ChainedAssignmentError": -25034,
    "CharsetError": -25035,
    "ChunkedEncodingError": -25036,
    "Clamped": -25037,
    "ClassFoundException": -25038,
    "CloseBoundaryNotFoundDefect": -25039,
    "ClosedFileError": -25040,
    "ClosedPoolError": -25041,
    "CodecRegistryError": -25042,
    "CommandError": -25043,
    "CompileError": -25044,
    "CompileException": -25045,
    "ComplexWarning": -25046,
    "ComposerError": -25047,
    "CompressionError": -25048,
    "ConnectTimeout": -25049,
    "ConnectTimeoutError": -25050,
    "ConnectionError": -25051,
    "ConstructorError": -25052,
    "ContentDecodingError": -25053,
    "ContentTooShortError": -25054,
    "ConversionSyntax": -25055,
    "ConversionWarning": -25056,
    "ConverterError": -25057,
    "ConverterLockError": -25058,
    "CookieConflictError": -25059,
    "CookieError": -25060,
    "CryptographyDeprecationWarning": -25061,
    "DOMException": -25062,
    "DTypePromotionError": -25063,
    "DataError": -25064,
    "DatabaseError": -25065,
    "DateParseError": -25066,
    "DecimalException": -25067,
    "DecodeError": -25068,
    "DependencyWarning": -25069,
    "DeprecatedTzFormatWarning": -25070,
    "DistutilsArgError": -25071,
    "DistutilsByteCompileError": -25072,
    "DistutilsClassError": -25073,
    "DistutilsError": -25074,
    "DistutilsExecError": -25075,
    "DistutilsFileError": -25076,
    "DistutilsGetoptError": -25077,
    "DistutilsInternalError": -25078,
    "DistutilsModuleError": -25079,
    "DistutilsOptionError": -25080,
    "DistutilsPlatformError": -25081,
    "DistutilsSetupError": -25082,
    "DistutilsTemplateError": -25083,
    "DivisionByZero": -25084,
    "DivisionImpossible": -25085,
    "DivisionUndefined": -25086,
    "DomstringSizeErr": -25087,
    "DtypeWarning": -25088,
    "DuplicateLabelError": -25089,
    "DuplicateOptionError": -25090,
    "DuplicateSectionError": -25091,
    "DuplicationError": -25092,
    "EOFHeaderError": -25093,
    "EmitterError": -25094,
    "Empty": -25095,
    "EmptyDataError": -25096,
    "EmptyHeaderError": -25097,
    "EmptyPoolError": -25098,
    "EndOfBlock": -25099,
    "Error": -25100,
    "ExecError": -25101,
    "ExtractError": -25102,
    "FileModeWarning": -25103,
    "FilterError": -25104,
    "FirstHeaderLineIsContinuationDefect": -25105,
    "FloatOperation": -25106,
    "FrozenInstanceError": -25107,
    "Full": -25108,
    "FullPoolError": -25109,
    "GetPassWarning": -25110,
    "HTTPError": -25111,
    "HTTPException": -25112,
    "HTTPWarning": -25113,
    "HeaderDefect": -25114,
    "HeaderError": -25115,
    "HeaderMissingRequiredValue": -25116,
    "HeaderParseError": -25117,
    "HeaderParsingError": -25118,
    "HierarchyRequestErr": -25119,
    "HostChangedError": -25120,
    "IDNABidiError": -25121,
    "IDNAError": -25122,
    "IllegalMonthError": -25123,
    "IllegalWeekdayError": -25124,
    "ImproperConnectionState": -25125,
    "IncompatibilityWarning": -25126,
    "IncompatibleFrequency": -25127,
    "Incomplete": -25128,
    "IncompleteRead": -25129,
    "IncompleteReadError": -25130,
    "IndexSizeErr": -25131,
    "IndexingError": -25132,
    "Inexact": -25133,
    "InsecurePlatformWarning": -25134,
    "InsecureRequestWarning": -25135,
    "IntCastingNaNError": -25136,
    "IntegrityError": -25137,
    "InterfaceError": -25138,
    "InterfaceNotImplemented": -25139,
    "InternalError": -25140,
    "InterpolationDepthError": -25141,
    "InterpolationError": -25142,
    "InterpolationMissingOptionError": -25143,
    "InterpolationSyntaxError": -25144,
    "InuseAttributeErr": -25145,
    "InvalidAccessErr": -25146,
    "InvalidBase64CharactersDefect": -25147,
    "InvalidBase64LengthDefect": -25148,
    "InvalidBase64PaddingDefect": -25149,
    "InvalidCharacterErr": -25150,
    "InvalidChunkLength": -25151,
    "InvalidCodepoint": -25152,
    "InvalidCodepointContext": -25153,
    "InvalidColumnName": -25154,
    "InvalidComparison": -25155,
    "InvalidContext": -25156,
    "InvalidHeader": -25157,
    "InvalidHeaderDefect": -25158,
    "InvalidHeaderError": -25159,
    "InvalidIndexError": -25160,
    "InvalidJSONError": -25161,
    "InvalidKey": -25162,
    "InvalidModificationErr": -25163,
    "InvalidMultipartContentTransferEncodingDefect": -25164,
    "InvalidOperation": -25165,
    "InvalidProxyURL": -25166,
    "InvalidSchema": -25167,
    "InvalidSignature": -25168,
    "InvalidStateErr": -25169,
    "InvalidStateError": -25170,
    "InvalidTZPathWarning": -25171,
    "InvalidTag": -25172,
    "InvalidTimeError": -25173,
    "InvalidToken": -25174,
    "InvalidURL": -25175,
    "InvalidVersion": -25176,
    "IsDirectoryError": -25177,
    "ItimerError": -25178,
    "JSONDecodeError": -25179,
    "KeyAndValueDuplicationError": -25180,
    "KeyDuplicationError": -25181,
    "LZMAError": -25182,
    "LargeZipFile": -25183,
    "LibError": -25184,
    "LimitOverrunError": -25185,
    "LinAlgError": -25186,
    "LineTooLong": -25187,
    "LinkError": -25188,
    "LinkOutsideDestinationError": -25189,
    "LoadError": -25190,
    "LocationParseError": -25191,
    "LocationValueError": -25192,
    "LossySetitemError": -25193,
    "MAError": -25194,
    "MakoException": -25195,
    "MarkedYAMLError": -25196,
    "MaskError": -25197,
    "MaskedArrayFutureWarning": -25198,
    "MaxRetryError": -25199,
    "MemoryError": -25200,
    "MergeError": -25201,
    "MessageDefect": -25202,
    "MessageError": -25203,
    "MessageParseError": -25204,
    "MethodNotAllowed": -25205,
    "MisplacedEnvelopeHeaderDefect": -25206,
    "MissingFileError": -25207,
    "MissingHeaderBodySeparatorDefect": -25208,
    "MissingSchema": -25209,
    "MissingSectionHeaderError": -25210,
    "ModuleDeprecationWarning": -25211,
    "MultipartConversionError": -25212,
    "MultipartInvariantViolationDefect": -25213,
    "NameConflictError": -25214,
    "NameResolutionError": -25215,
    "NamespaceErr": -25216,
    "NetmaskValueError": -25217,
    "NewConnectionError": -25218,
    "NoBoundaryInMultipartDefect": -25219,
    "NoBufferPresent": -25220,
    "NoDataAllowedErr": -25221,
    "NoModificationAllowedErr": -25222,
    "NoOptionError": -25223,
    "NoSectionError": -25224,
    "NonASCIILocalPartDefect": -25225,
    "NonExistentTimeError": -25226,
    "NonPrintableDefect": -25227,
    "NotARegularFileError": -25228,
    "NotAcceptable": -25229,
    "NotAuthenticated": -25230,
    "NotConnected": -25231,
    "NotFound": -25232,
    "NotFoundErr": -25233,
    "NotOpenSSLWarning": -25234,
    "NotSupportedErr": -25235,
    "NotSupportedError": -25236,
    "NotYetFinalized": -25237,
    "NullFrequencyError": -25238,
    "NumExprClobberingError": -25239,
    "NumbaUtilError": -25240,
    "ObjectTypeError": -25241,
    "ObjectValueError": -25242,
    "ObsoleteHeaderDefect": -25243,
    "OperationalError": -25244,
    "OptionError": -25245,
    "OutOfBoundsDatetime": -25246,
    "OutOfBoundsTimedelta": -25247,
    "OutsideDestinationError": -25248,
    "Overflow": -25249,
    "PackageNotFoundError": -25250,
    "ParseError": -25251,
    "ParserError": -25252,
    "ParserWarning": -25253,
    "ParsingError": -25254,
    "PerformanceWarning": -25255,
    "PermissionDenied": -25256,
    "PickleError": -25257,
    "PicklingError": -25258,
    "PoolError": -25259,
    "PossibleDataLossError": -25260,
    "PossiblePrecisionLoss": -25261,
    "PreprocessError": -25262,
    "ProgrammingError": -25263,
    "ProtocolError": -25264,
    "ProxyError": -25265,
    "ProxySchemeUnknown": -25266,
    "ProxySchemeUnsupported": -25267,
    "PyperclipException": -25268,
    "PyperclipWindowsException": -25269,
    "QueueEmpty": -25270,
    "QueueFull": -25271,
    "RankWarning": -25272,
    "ReadError": -25273,
    "ReadTimeout": -25274,
    "ReadTimeoutError": -25275,
    "ReaderError": -25276,
    "RegistryError": -25277,
    "RemoteDisconnected": -25278,
    "RemovedInDRF315Warning": -25279,
    "RepresenterError": -25280,
    "RequestError": -25281,
    "RequestException": -25282,
    "RequestsDependencyWarning": -25283,
    "RequestsWarning": -25284,
    "ResolverError": -25285,
    "ResponseError": -25286,
    "ResponseNotChunked": -25287,
    "ResponseNotReady": -25288,
    "RetryError": -25289,
    "Rounded": -25290,
    "RuntimeException": -25291,
    "SQLParseError": -25292,
    "SSLCertVerificationError": -25293,
    "SSLEOFError": -25294,
    "SSLError": -25295,
    "SSLSyscallError": -25296,
    "SSLWantReadError": -25297,
    "SSLWantWriteError": -25298,
    "SSLZeroReturnError": -25299,
    "SameFileError": -25300,
    "ScannerError": -25301,
    "SecurityWarning": -25302,
    "SendfileNotAvailableError": -25303,
    "SerializerError": -25304,
    "SettingWithCopyError": -25305,
    "SettingWithCopyWarning": -25306,
    "SkipField": -25307,
    "SkipTest": -25308,
    "SpecialFileError": -25309,
    "SpecificationError": -25310,
    "StartBoundaryNotFoundDefect": -25311,
    "StopTokenizing": -25312,
    "StreamConsumedError": -25313,
    "StreamError": -25314,
    "Subnormal": -25315,
    "SubprocessError": -25316,
    "SubsequentHeaderError": -25317,
    "SyntaxErr": -25318,
    "SyntaxException": -25319,
    "SystemTimeWarning": -25320,
    "TarError": -25321,
    "TemplateLookupException": -25322,
    "Throttled": -25323,
    "Timeout": -25324,
    "TimeoutError": -25325,
    "TimeoutExpired": -25326,
    "TimeoutStateError": -25327,
    "TokenError": -25328,
    "TooHardError": -25329,
    "TooManyRedirects": -25330,
    "TopLevelLookupException": -25331,
    "TruncatedHeaderError": -25332,
    "UFuncTypeError": -25333,
    "URLError": -25334,
    "URLRequired": -25335,
    "URLSchemeUnknown": -25336,
    "UndecodableBytesDefect": -25337,
    "UndefinedValueError": -25338,
    "UndefinedVariableError": -25339,
    "Underflow": -25340,
    "UnimplementedFileMode": -25341,
    "UnknownFileError": -25342,
    "UnknownProtocol": -25343,
    "UnknownTimeZoneError": -25344,
    "UnknownTimezoneWarning": -25345,
    "UnknownTransferEncoding": -25346,
    "UnpicklingError": -25347,
    "UnrewindableBodyError": -25348,
    "UnsortedIndexError": -25349,
    "UnsupportedAlgorithm": -25350,
    "UnsupportedError": -25351,
    "UnsupportedFunctionCall": -25352,
    "UnsupportedMediaType": -25353,
    "UnsupportedOperation": -25354,
    "ValidationErr": -25355,
    "ValidationError": -25356,
    "ValueDuplicationError": -25357,
    "ValueLabelTypeMismatch": -25358,
    "Verbose": -25359,
    "VerificationError": -25360,
    "VisibleDeprecationWarning": -25361,
    "Warning": -25362,
    "WrongDocumentErr": -25363,
    "YAMLError": -25364,
    "ZipImportError": -25365,
    "ZoneInfoNotFoundError": -25366,
    "_DeadlockError": -25367,
    "_GiveupOnFastCopy": -25368,
    "_GiveupOnSendfile": -25369,
    "_InvalidEwError": -25370,
    "_OptionError": -25371,
    "_ShouldStop": -25372,
    "_Stop": -25373,
    "_UnexpectedSuccess": -25374,
    "error": -25375,
    "gaierror": -25376,
    "herror": -25377,
    "timeout": -25378,
})
