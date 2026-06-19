program DatabaseSample;

{$APPTYPE CONSOLE}
{$R *.res}

{
  Demonstrates tracing SQL database requests with the Dynatrace OneAgent SDK.

  Create an IDatabaseInfo descriptor once (e.g. at application startup) and
  reuse it for all requests to that database. Release it by letting the
  interface reference go out of scope.

  Note: database traces only appear in the Dynatrace UI when they occur within
  an active PurePath (e.g. inside an incoming remote call or custom service trace).
}

uses
  System.SysUtils,
  OneAgentSDK in '..\..\src\OneAgentSDK.pas',
  OneAgentSDK.Types in '..\..\src\OneAgentSDK.Types.pas',
  OneAgentSDK.Native in '..\..\src\OneAgentSDK.Native.pas',
  OneAgentSDK.Impl in '..\..\src\OneAgentSDK.Impl.pas',
  OneAgentSDK.NullImpl in '..\..\src\OneAgentSDK.NullImpl.pas';

procedure OnSDKWarning(const AMessage: string);
begin
  WriteLn('[SDK Warning] ', AMessage);
end;

procedure SimulateDatabaseWork(const SDK: IOneAgentSDK; const DbInfo: IDatabaseInfo);
var
  Tracer : IDatabaseRequestTracer;
begin
  // Trace a SELECT query.
  Tracer := SDK.TraceSQLDatabaseRequest(
    DbInfo,
    'SELECT id, name, email FROM users WHERE active = 1');
  Tracer.Start;
  try
    WriteLn('  Executing query...');
    Sleep(10); // simulate query execution
    // Report metadata after the query completes.
    Tracer.SetReturnedRowCount(42);
    Tracer.SetRoundTripCount(1);
    WriteLn('  Query returned 42 rows.');
  except
    on E: Exception do
    begin
      Tracer.SetError(E.ClassName, E.Message);
      raise;
    end;
  end;
  Tracer.Finish;

  // Trace an INSERT query.
  Tracer := SDK.TraceSQLDatabaseRequest(
    DbInfo,
    'INSERT INTO audit_log (user_id, action, ts) VALUES (?, ?, ?)');
  Tracer.Start;
  try
    WriteLn('  Executing insert...');
    Sleep(5);
    Tracer.SetReturnedRowCount(1);
    Tracer.SetRoundTripCount(1);
    WriteLn('  Insert completed.');
  except
    on E: Exception do
    begin
      Tracer.SetError(E.ClassName, E.Message);
      raise;
    end;
  end;
  Tracer.Finish;
end;

var
  SDK      : IOneAgentSDK;
  DbInfo   : IDatabaseInfo;
  Wrapper  : ITracer;

begin
  try
    SDK := CreateOneAgentSDK;
    SDK.SetLoggingCallback(OnSDKWarning);

    WriteLn('SDK state: ', Ord(SDK.GetCurrentState));
    WriteLn;

    // Create the database descriptor once; reuse across multiple requests.
    DbInfo := SDK.CreateDatabaseInfo(
      'prod-users-db',          // logical database name
      DB_VENDOR_POSTGRESQL,     // vendor string (from OneAgentSDK.Types)
      ctTcpIp,                  // channel type
      'db.internal.corp:5432'   // channel endpoint
    );

    WriteLn('--- Database Tracing (inside a custom service span) ---');

    // Wrap DB calls in a custom service so the traces appear in the Dynatrace UI.
    Wrapper := SDK.TraceCustomService('loadUsers', 'UserRepository');
    Wrapper.Start;
    try
      SimulateDatabaseWork(SDK, DbInfo);
    except
      on E: Exception do
      begin
        Wrapper.SetError(E.ClassName, E.Message);
        raise;
      end;
    end;
    Wrapper.Finish;

    WriteLn;
    WriteLn('Sample complete.');
  except
    on E: Exception do
      WriteLn(E.ClassName, ': ', E.Message);
  end;
end.
