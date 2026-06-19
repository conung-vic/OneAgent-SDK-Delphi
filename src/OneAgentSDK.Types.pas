unit OneAgentSDK.Types;

{
  Dynatrace OneAgent SDK for Delphi
  Common types, enumerations, and well-known vendor string constants.
}

interface

type
  TSdkState = (
    sdkActive              = 0,
    sdkTemporarilyInactive = 1,
    sdkPermanentlyInactive = 2,
    sdkNotInitialized      = 3,
    sdkError               = 4
  );

  TChannelType = (
    ctOther            = 0,
    ctTcpIp            = 1,
    ctUnixDomainSocket = 2,
    ctNamedPipe        = 3,
    ctInProcess        = 4
  );

  TTraceContextInfo = record
    TraceId : string;   // W3C trace ID: 32 lowercase hex chars, or all-zeros when inactive
    SpanId  : string;   // W3C span ID: 16 lowercase hex chars, or all-zeros when inactive
    IsValid : Boolean;  // True when an active PurePath node was present
  end;

  TOneAgentSDKLoggingCallback = reference to procedure(const AMessage: string);

const
  // Well-known database vendor strings (use with CreateDatabaseInfo).
  // Using these values ensures correct service naming in the Dynatrace UI.
  DB_VENDOR_APACHE_HIVE    = 'ApacheHive';
  DB_VENDOR_CLOUDSCAPE     = 'Cloudscape';
  DB_VENDOR_HSQLDB         = 'HSQLDB';
  DB_VENDOR_PROGRESS       = 'Progress';
  DB_VENDOR_MAXDB          = 'MaxDB';
  DB_VENDOR_HANADB         = 'HanaDB';
  DB_VENDOR_INGRES         = 'Ingres';
  DB_VENDOR_FIRST_SQL      = 'FirstSQL';
  DB_VENDOR_ENTERPRISE_DB  = 'EnterpriseDB';
  DB_VENDOR_CACHE          = 'Cache';
  DB_VENDOR_ADABAS         = 'Adabas';
  DB_VENDOR_FIREBIRD       = 'Firebird';
  DB_VENDOR_DB2            = 'DB2';
  DB_VENDOR_DERBY_CLIENT   = 'Derby Client';
  DB_VENDOR_DERBY_EMBEDDED = 'Derby Embedded';
  DB_VENDOR_FILEMAKER      = 'Filemaker';
  DB_VENDOR_INFORMIX       = 'Informix';
  DB_VENDOR_INSTANT_DB     = 'InstantDb';
  DB_VENDOR_INTERBASE      = 'Interbase';
  DB_VENDOR_MYSQL          = 'MySQL';
  DB_VENDOR_MARIADB        = 'MariaDB';
  DB_VENDOR_NETEZZA        = 'Netezza';
  DB_VENDOR_ORACLE         = 'Oracle';
  DB_VENDOR_PERVASIVE      = 'Pervasive';
  DB_VENDOR_POINTBASE      = 'Pointbase';
  DB_VENDOR_POSTGRESQL     = 'PostgreSQL';
  DB_VENDOR_SQLSERVER      = 'SQL Server';
  DB_VENDOR_SQLITE         = 'sqlite';
  DB_VENDOR_SYBASE         = 'Sybase';
  DB_VENDOR_TERADATA       = 'Teradata';
  DB_VENDOR_VERTICA        = 'Vertica';
  DB_VENDOR_CASSANDRA      = 'Cassandra';
  DB_VENDOR_H2             = 'H2';
  DB_VENDOR_COLDFUSION_IMQ = 'ColdFusion IMQ';
  DB_VENDOR_REDSHIFT       = 'Amazon Redshift';
  DB_VENDOR_COUCHBASE      = 'Couchbase';

implementation

end.
