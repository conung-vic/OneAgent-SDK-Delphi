unit UMain;

{
  Full-chain tracing sample: Client -> Server -> Database
  Demonstrates three linked SDK tracers in a single PurePath:
    1. Outgoing Web Request  (HTTP client side)
    2. Incoming Remote Call  (HTTP server handler)
    3. SQL Database Request  (simulated DB query inside the handler)

  Uses Indy TIdHTTPServer as the embedded HTTP server.
  The Dynatrace tag is propagated via the X-dynaTrace header.
}

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Classes, System.JSON,
  System.Net.HttpClient, System.Net.URLClient,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.ExtCtrls,
  IdHTTPServer, IdContext, IdCustomHTTPServer,
  OneAgentSDK, OneAgentSDK.Types;

type
  TfrmMain = class(TForm)
    btnStartServer: TButton;
    btnSendRequest: TButton;
    btnClear: TButton;
    edPort: TEdit;
    lblPort: TLabel;
    mmLog: TMemo;
    shIndicator: TShape;
    procedure btnStartServerClick(Sender: TObject);
    procedure btnSendRequestClick(Sender: TObject);
    procedure btnClearClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    SDK: IOneAgentSDK;
    Server: TIdHTTPServer;
    DatabaseInfo: IDatabaseInfo;
    procedure Log(const AMsg: string);
    procedure OnSDKWarning(const AMessage: string);
    procedure OnServerCommand(AContext: TIdContext;
      ARequestInfo: TIdHTTPRequestInfo;
      AResponseInfo: TIdHTTPResponseInfo);
    procedure HandleGetOrders(const ADynatraceTag: string;
      AResponseInfo: TIdHTTPResponseInfo);
    procedure SimulateDatabaseQuery;
    procedure SendClientRequest;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

procedure TfrmMain.Log(const AMsg: string);
begin
  // Thread-safe: Indy handlers run on worker threads
  TThread.Queue(nil,
    procedure
    begin
      mmLog.Lines.Add(AMsg);
    end);
end;

procedure TfrmMain.OnSDKWarning(const AMessage: string);
begin
  Log('[SDK Warning] ' + AMessage);
end;

// ---------------------------------------------------------------------------
// Form lifecycle
// ---------------------------------------------------------------------------

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  SDK := CreateOneAgentSDK;
  SDK.SetLoggingCallback(OnSDKWarning);

  // Pre-create a reusable database descriptor (thread-safe, immutable)
  DatabaseInfo := SDK.CreateDatabaseInfo(
    'OrdersDB', DB_VENDOR_POSTGRESQL, ctTcpIp, 'localhost:5432');

  Server := TIdHTTPServer.Create(nil);
  Server.OnCommandGet := OnServerCommand;

  case SDK.GetCurrentState of
    sdkActive:
    begin
      shIndicator.Brush.Color := clGreen;
      Log('SDK is ACTIVE');
    end;
    sdkTemporarilyInactive:
    begin
      shIndicator.Brush.Color := clYellow;
      Log('SDK is TEMPORARILY INACTIVE');
    end;
  else
    begin
      shIndicator.Brush.Color := clRed;
      Log('SDK is INACTIVE');
    end;
  end;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  if Server.Active then
    Server.Active := False;
  Server.Free;
  DatabaseInfo := nil;
  SDK := nil;
end;

// ---------------------------------------------------------------------------
// UI handlers
// ---------------------------------------------------------------------------

procedure TfrmMain.btnStartServerClick(Sender: TObject);
var
  Port: Integer;
begin
  if Server.Active then
  begin
    Server.Active := False;
    btnStartServer.Caption := 'Start Server';
    Log('Server stopped');
    Exit;
  end;

  Port := StrToIntDef(edPort.Text, 8080);
  Server.DefaultPort := Port;
  try
    Server.Active := True;
    btnStartServer.Caption := 'Stop Server';
    Log('Server listening on port ' + IntToStr(Port));
  except
    on E: Exception do
      Log('Server start failed: ' + E.Message);
  end;
end;

procedure TfrmMain.btnSendRequestClick(Sender: TObject);
begin
  SendClientRequest;
end;

procedure TfrmMain.btnClearClick(Sender: TObject);
begin
  mmLog.Lines.Clear;
end;

// ---------------------------------------------------------------------------
// 1. CLIENT — Outgoing Web Request tracer
// ---------------------------------------------------------------------------

procedure TfrmMain.SendClientRequest;
var
  Tracer   : IOutgoingWebRequestTracer;
  Http     : THTTPClient;
  Response : IHTTPResponse;
  Url, Tag : string;
  Ctx      : TTraceContextInfo;
  I        : Integer;
  Header   : TNameValuePair;
begin
  Url := 'http://localhost:' + edPort.Text + '/api/orders';
  Log('');
  Log('=== CLIENT: GET ' + Url + ' ===');

  Tracer := SDK.TraceOutgoingWebRequest(Url, 'GET');

  Http := THTTPClient.Create;
  try
    Tracer.AddRequestHeader('Accept', 'application/json');
    Tracer.Start;
    try
      // Propagate Dynatrace tag
      Tag := Tracer.GetDynatraceStringTag;
      if Tag <> '' then
      begin
        Http.CustomHeaders[DYNATRACE_HTTP_HEADERNAME] := Tag;
        Log('CLIENT: DT tag sent');
      end;

      // Propagate W3C traceparent
      Ctx := SDK.GetTraceContextInfo;
      if Ctx.IsValid then
      begin
        Http.CustomHeaders[DYNATRACE_HTTP_W3C_PARENT] :=
          '00-' + Ctx.TraceId + '-' + Ctx.SpanId + '-01';
        Log('CLIENT: traceId=' + Ctx.TraceId);
      end;

      Response := Http.Get(Url);

      // Capture response headers
      for I := 0 to Length(Response.Headers) - 1 do
      begin
        Header := Response.Headers[I];
        Tracer.AddResponseHeader(Header.Name, Header.Value);
      end;
      Tracer.SetStatusCode(Response.StatusCode);

      Log('CLIENT: HTTP ' + IntToStr(Response.StatusCode));
      Log('CLIENT: ' + Response.ContentAsString(TEncoding.UTF8));
    except
      on E: Exception do
      begin
        Tracer.SetError(E.ClassName, E.Message);
        Log('CLIENT ERROR: ' + E.Message);
      end;
    end;
  finally
    Tracer.Finish;
    Http.Free;
  end;
end;

// ---------------------------------------------------------------------------
// 2. SERVER — Incoming Remote Call tracer
// ---------------------------------------------------------------------------

procedure TfrmMain.OnServerCommand(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo;
  AResponseInfo: TIdHTTPResponseInfo);
var
  DtTag: string;
begin
  Log('');
  Log('=== SERVER: ' + ARequestInfo.Command + ' '
    + ARequestInfo.Document + ' ===');

  DtTag := ARequestInfo.RawHeaders.Values[DYNATRACE_HTTP_HEADERNAME];
  if DtTag <> '' then
    Log('SERVER: received DT tag')
  else
    Log('SERVER: no DT tag in request');

  if ARequestInfo.Document = '/api/orders' then
    HandleGetOrders(DtTag, AResponseInfo)
  else
  begin
    AResponseInfo.ResponseNo := 404;
    AResponseInfo.ContentText := '{"error":"not found"}';
    AResponseInfo.ContentType := 'application/json';
  end;
end;

procedure TfrmMain.HandleGetOrders(const ADynatraceTag: string;
  AResponseInfo: TIdHTTPResponseInfo);
var
  Tracer : IIncomingRemoteCallTracer;
  Json   : TJSONObject;
  Arr    : TJSONArray;
begin
  Tracer := SDK.TraceIncomingRemoteCall(
    'HandleGetOrders', 'OrderService', '/api/orders');

  // Inject the tag received from the caller BEFORE Start
  if ADynatraceTag <> '' then
    Tracer.SetDynatraceStringTag(ADynatraceTag);
  Tracer.SetProtocolName('HTTP');

  Tracer.Start;
  try
    Log('SERVER: processing request...');

    // 3. Nested database call
    SimulateDatabaseQuery;

    // Build JSON response
    Arr := TJSONArray.Create;
    Arr.Add(TJSONObject.Create
      .AddPair('id', TJSONNumber.Create(1))
      .AddPair('product', 'Delphi Enterprise')
      .AddPair('status', 'active'));
    Arr.Add(TJSONObject.Create
      .AddPair('id', TJSONNumber.Create(2))
      .AddPair('product', 'RAD Studio')
      .AddPair('status', 'active'));

    Json := TJSONObject.Create;
    try
      Json.AddPair('orders', Arr);
      Json.AddPair('count', TJSONNumber.Create(2));

      AResponseInfo.ResponseNo := 200;
      AResponseInfo.ContentType := 'application/json';
      AResponseInfo.ContentText := Json.ToJSON;
    finally
      Json.Free;
    end;

    Log('SERVER: response sent');
  except
    on E: Exception do
    begin
      Tracer.SetError(E.ClassName, E.Message);
      AResponseInfo.ResponseNo := 500;
      AResponseInfo.ContentText := '{"error":"' + E.Message + '"}';
      AResponseInfo.ContentType := 'application/json';
      Log('SERVER ERROR: ' + E.Message);
    end;
  end;
  Tracer.Finish;
end;

// ---------------------------------------------------------------------------
// 3. DATABASE — SQL Database Request tracer
// ---------------------------------------------------------------------------

procedure TfrmMain.SimulateDatabaseQuery;
var
  Tracer: IDatabaseRequestTracer;
begin
  Log('  DB: SELECT * FROM orders ...');

  Tracer := SDK.TraceSQLDatabaseRequest(DatabaseInfo,
    'SELECT id, product, status FROM orders WHERE status = ''active''');

  Tracer.Start;
  try
    // Simulate database latency
    Sleep(50);

    Tracer.SetReturnedRowCount(2);
    Tracer.SetRoundTripCount(1);
    Log('  DB: 2 rows returned');
  except
    on E: Exception do
    begin
      Tracer.SetError(E.ClassName, E.Message);
      Log('  DB ERROR: ' + E.Message);
    end;
  end;
  Tracer.Finish;
end;

end.
