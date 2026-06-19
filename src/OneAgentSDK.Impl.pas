unit OneAgentSDK.Impl;

{
  Dynatrace OneAgent SDK for Delphi — Live implementation.
  Wraps the C SDK (onesdk_shared.dll) with Delphi-idiomatic classes.
  Returned by CreateOneAgentSDK when initialization succeeds.
}

interface

uses
  System.SysUtils,
  System.SyncObjs,
  OneAgentSDK,
  OneAgentSDK.Types,
  OneAgentSDK.Native,
  OneAgentSDK.NullImpl;

type
  // Internal interface used to retrieve the native handle from a TDatabaseInfoImpl
  // instance without exposing it through the public IDatabaseInfo interface.
  IDatabaseInfoHandle = interface
    ['{1A2B3C4D-5E6F-7890-A1B2-C3D4E5F60007}']
    function GetNativeHandle: TOnesdk_databaseinfo_handle_t;
  end;

  // Base class for all tracer implementations. Manages the native handle lifetime.
  TTracerBase = class(TInterfacedObject, ITracer)
  private
    FHandle: TOnesdk_tracer_handle_t;
  protected
    property Handle: TOnesdk_tracer_handle_t read FHandle;
  public
    constructor Create(AHandle: TOnesdk_tracer_handle_t);
    // Safety net: calls onesdk_tracer_end if Finish was never called.
    destructor Destroy; override;

    procedure Start;
    procedure SetError(const AMessage: string); overload;
    procedure SetError(const AErrorClass, AMessage: string); overload;
    procedure Finish;
  end;

  TOutgoingRemoteCallTracerImpl = class(TTracerBase, IOutgoingRemoteCallTracer)
  public
    function  GetDynatraceStringTag: string;
    procedure SetProtocolName(const AProtocolName: string);
  end;

  TIncomingRemoteCallTracerImpl = class(TTracerBase, IIncomingRemoteCallTracer)
  public
    procedure SetDynatraceStringTag(const ATag: string);
    procedure SetProtocolName(const AProtocolName: string);
  end;

  TOutgoingWebRequestTracerImpl = class(TTracerBase, IOutgoingWebRequestTracer)
  public
    function  GetDynatraceStringTag: string;
    procedure AddRequestHeader(const AName, AValue: string);
    procedure AddResponseHeader(const AName, AValue: string);
    procedure SetStatusCode(AStatusCode: Integer);
  end;

  TDatabaseInfoImpl = class(TInterfacedObject, IDatabaseInfo, IDatabaseInfoHandle)
  private
    FHandle: TOnesdk_databaseinfo_handle_t;
  public
    constructor Create(AHandle: TOnesdk_databaseinfo_handle_t);
    destructor Destroy; override;
    function GetNativeHandle: TOnesdk_databaseinfo_handle_t;
  end;

  TDatabaseRequestTracerImpl = class(TTracerBase, IDatabaseRequestTracer)
  public
    procedure SetReturnedRowCount(ACount: Integer);
    procedure SetRoundTripCount(ACount: Integer);
  end;

  TOneAgentSDKImpl = class(TInterfacedObject, IOneAgentSDK)
  private
    FLoggingCallback : TOneAgentSDKLoggingCallback;
    FCallbackLock    : TCriticalSection;
    FInitialized     : Boolean;
  public
    constructor Create(AInitialized: Boolean);
    destructor Destroy; override;

    function  GetCurrentState: TSdkState;
    function  GetTraceContextInfo: TTraceContextInfo;
    procedure SetLoggingCallback(ACallback: TOneAgentSDKLoggingCallback);
    function  CreateDatabaseInfo(
      const AName, AVendor: string;
      AChannelType: TChannelType;
      const AChannelEndpoint: string): IDatabaseInfo;
    function  TraceCustomService(
      const AServiceMethod, AServiceName: string): ITracer;
    function  TraceOutgoingRemoteCall(
      const AServiceMethod, AServiceName, AServiceEndpoint: string;
      AChannelType: TChannelType;
      const AChannelEndpoint: string): IOutgoingRemoteCallTracer;
    function  TraceIncomingRemoteCall(
      const AServiceMethod, AServiceName, AServiceEndpoint: string
    ): IIncomingRemoteCallTracer;
    function  TraceOutgoingWebRequest(
      const AUrl, AMethod: string): IOutgoingWebRequestTracer;
    function  TraceSQLDatabaseRequest(
      ADatabaseInfo: IDatabaseInfo;
      const AStatement: string): IDatabaseRequestTracer;
    procedure AddCustomRequestAttribute(const AKey, AValue: string); overload;
    procedure AddCustomRequestAttribute(const AKey: string; AValue: Int64); overload;
    procedure AddCustomRequestAttribute(const AKey: string; AValue: Double); overload;
  end;

// Process-global state for bridging the C logging callback to a Delphi method.
// Protected by GSDKCallbackLock.
var
  GSDKImplForCallback : TOneAgentSDKImpl = nil;
  GSDKCallbackLock    : TCriticalSection = nil;

implementation

// ---------------------------------------------------------------------------
// Native logging bridge — called by the C SDK (cdecl), forwards to Delphi method.
// ---------------------------------------------------------------------------
procedure NativeLoggingBridge(message: PAnsiChar); cdecl;
var
  Callback : TOneAgentSDKLoggingCallback;
begin
  GSDKCallbackLock.Enter;
  try
    if Assigned(GSDKImplForCallback) then
      Callback := GSDKImplForCallback.FLoggingCallback
    else
      Callback := nil;
  finally
    GSDKCallbackLock.Leave;
  end;
  if Assigned(Callback) then
    Callback(string(UTF8String(message)));
end;

// ---------------------------------------------------------------------------
// TTracerBase
// ---------------------------------------------------------------------------

constructor TTracerBase.Create(AHandle: TOnesdk_tracer_handle_t);
begin
  inherited Create;
  FHandle := AHandle;
end;

destructor TTracerBase.Destroy;
begin
  if FHandle <> ONESDK_INVALID_HANDLE then
    onesdk_tracer_end(FHandle);
  inherited;
end;

procedure TTracerBase.Start;
begin
  if FHandle <> ONESDK_INVALID_HANDLE then
    onesdk_tracer_start(FHandle);
end;

procedure TTracerBase.SetError(const AMessage: string);
var
  NullStr, MsgStr: TOnesdk_string;
begin
  if FHandle <> ONESDK_INVALID_HANDLE then
  begin
    MakeNullStr(NullStr);
    MakeWStr(MsgStr, AMessage);
    onesdk_tracer_error_p(FHandle, @NullStr, @MsgStr);
  end;
end;

procedure TTracerBase.SetError(const AErrorClass, AMessage: string);
var
  ClassStr, MsgStr: TOnesdk_string;
begin
  if FHandle <> ONESDK_INVALID_HANDLE then
  begin
    MakeWStr(ClassStr, AErrorClass);
    MakeWStr(MsgStr, AMessage);
    onesdk_tracer_error_p(FHandle, @ClassStr, @MsgStr);
  end;
end;

procedure TTracerBase.Finish;
begin
  if FHandle <> ONESDK_INVALID_HANDLE then
  begin
    onesdk_tracer_end(FHandle);
    FHandle := ONESDK_INVALID_HANDLE;
  end;
end;

// ---------------------------------------------------------------------------
// TOutgoingRemoteCallTracerImpl
// ---------------------------------------------------------------------------

function TOutgoingRemoteCallTracerImpl.GetDynatraceStringTag: string;
var
  RequiredSize : NativeUInt;
  Buffer       : AnsiString;
  Copied       : NativeUInt;
begin
  Result := '';
  if Handle = ONESDK_INVALID_HANDLE then
    Exit;
  // First call: query required buffer size.
  RequiredSize := 0;
  onesdk_tracer_get_outgoing_dynatrace_string_tag(Handle, nil, 0, @RequiredSize);
  if RequiredSize = 0 then
    Exit;
  // Second call: fill the buffer (includes null terminator in RequiredSize).
  SetLength(Buffer, RequiredSize);
  Copied := onesdk_tracer_get_outgoing_dynatrace_string_tag(
    Handle, PAnsiChar(Buffer), RequiredSize, nil);
  if Copied > 0 then
    Result := string(AnsiString(PAnsiChar(Buffer)));
end;

procedure TOutgoingRemoteCallTracerImpl.SetProtocolName(const AProtocolName: string);
var
  S: TOnesdk_string;
begin
  if Handle <> ONESDK_INVALID_HANDLE then
  begin
    MakeWStr(S, AProtocolName);
    onesdk_outgoingremotecalltracer_set_protocol_name_p(Handle, @S);
  end;
end;

// ---------------------------------------------------------------------------
// TIncomingRemoteCallTracerImpl
// ---------------------------------------------------------------------------

procedure TIncomingRemoteCallTracerImpl.SetDynatraceStringTag(const ATag: string);
var
  TagAnsi : AnsiString;
  S       : TOnesdk_string;
begin
  if Handle <> ONESDK_INVALID_HANDLE then
  begin
    // The incoming tag is ASCII; convert and pass as ASCII to the C SDK.
    TagAnsi       := AnsiString(ATag);
    S.data        := PAnsiChar(TagAnsi);
    S.byte_length := NativeUInt(Length(TagAnsi));
    S.ccsid       := ONESDK_CCSID_ASCII;
    onesdk_tracer_set_incoming_dynatrace_string_tag_p(Handle, @S);
  end;
end;

procedure TIncomingRemoteCallTracerImpl.SetProtocolName(const AProtocolName: string);
var
  S: TOnesdk_string;
begin
  if Handle <> ONESDK_INVALID_HANDLE then
  begin
    MakeWStr(S, AProtocolName);
    onesdk_incomingremotecalltracer_set_protocol_name_p(Handle, @S);
  end;
end;

// ---------------------------------------------------------------------------
// TOutgoingWebRequestTracerImpl
// ---------------------------------------------------------------------------

function TOutgoingWebRequestTracerImpl.GetDynatraceStringTag: string;
var
  RequiredSize : NativeUInt;
  Buffer       : AnsiString;
  Copied       : NativeUInt;
begin
  Result := '';
  if Handle = ONESDK_INVALID_HANDLE then
    Exit;
  RequiredSize := 0;
  onesdk_tracer_get_outgoing_dynatrace_string_tag(Handle, nil, 0, @RequiredSize);
  if RequiredSize = 0 then
    Exit;
  SetLength(Buffer, RequiredSize);
  Copied := onesdk_tracer_get_outgoing_dynatrace_string_tag(
    Handle, PAnsiChar(Buffer), RequiredSize, nil);
  if Copied > 0 then
    Result := string(AnsiString(PAnsiChar(Buffer)));
end;

procedure TOutgoingWebRequestTracerImpl.AddRequestHeader(const AName, AValue: string);
var
  SName, SValue: TOnesdk_string;
begin
  if Handle <> ONESDK_INVALID_HANDLE then
  begin
    MakeWStr(SName, AName);
    MakeWStr(SValue, AValue);
    onesdk_outgoingwebrequesttracer_add_request_headers_p(Handle, @SName, @SValue, 1);
  end;
end;

procedure TOutgoingWebRequestTracerImpl.AddResponseHeader(const AName, AValue: string);
var
  SName, SValue: TOnesdk_string;
begin
  if Handle <> ONESDK_INVALID_HANDLE then
  begin
    MakeWStr(SName, AName);
    MakeWStr(SValue, AValue);
    onesdk_outgoingwebrequesttracer_add_response_headers_p(Handle, @SName, @SValue, 1);
  end;
end;

procedure TOutgoingWebRequestTracerImpl.SetStatusCode(AStatusCode: Integer);
begin
  if Handle <> ONESDK_INVALID_HANDLE then
    onesdk_outgoingwebrequesttracer_set_status_code(Handle, AStatusCode);
end;

// ---------------------------------------------------------------------------
// TDatabaseInfoImpl
// ---------------------------------------------------------------------------

constructor TDatabaseInfoImpl.Create(AHandle: TOnesdk_databaseinfo_handle_t);
begin
  inherited Create;
  FHandle := AHandle;
end;

destructor TDatabaseInfoImpl.Destroy;
begin
  if FHandle <> ONESDK_INVALID_HANDLE then
    onesdk_databaseinfo_delete(FHandle);
  inherited;
end;

function TDatabaseInfoImpl.GetNativeHandle: TOnesdk_databaseinfo_handle_t;
begin
  Result := FHandle;
end;

// ---------------------------------------------------------------------------
// TDatabaseRequestTracerImpl
// ---------------------------------------------------------------------------

procedure TDatabaseRequestTracerImpl.SetReturnedRowCount(ACount: Integer);
begin
  if Handle <> ONESDK_INVALID_HANDLE then
    onesdk_databaserequesttracer_set_returned_row_count(Handle, ACount);
end;

procedure TDatabaseRequestTracerImpl.SetRoundTripCount(ACount: Integer);
begin
  if Handle <> ONESDK_INVALID_HANDLE then
    onesdk_databaserequesttracer_set_round_trip_count(Handle, ACount);
end;

// ---------------------------------------------------------------------------
// TOneAgentSDKImpl
// ---------------------------------------------------------------------------

constructor TOneAgentSDKImpl.Create(AInitialized: Boolean);
begin
  inherited Create;
  FInitialized := AInitialized;
  FCallbackLock := TCriticalSection.Create;
  GSDKCallbackLock.Enter;
  try
    GSDKImplForCallback := Self;
  finally
    GSDKCallbackLock.Leave;
  end;
end;

destructor TOneAgentSDKImpl.Destroy;
begin
  // Uninstall the native callback before clearing the global pointer.
  onesdk_agent_set_warning_callback(nil);
  GSDKCallbackLock.Enter;
  try
    if GSDKImplForCallback = Self then
      GSDKImplForCallback := nil;
  finally
    GSDKCallbackLock.Leave;
  end;
  if FInitialized then
    onesdk_shutdown;
  FCallbackLock.Free;
  inherited;
end;

function TOneAgentSDKImpl.GetCurrentState: TSdkState;
begin
  case onesdk_agent_get_current_state of
    ONESDK_AGENT_STATE_ACTIVE               : Result := sdkActive;
    ONESDK_AGENT_STATE_TEMPORARILY_INACTIVE : Result := sdkTemporarilyInactive;
    ONESDK_AGENT_STATE_PERMANENTLY_INACTIVE : Result := sdkPermanentlyInactive;
    ONESDK_AGENT_STATE_NOT_INITIALIZED      : Result := sdkNotInitialized;
  else
    Result := sdkError;
  end;
end;

function TOneAgentSDKImpl.GetTraceContextInfo: TTraceContextInfo;
var
  TraceIdBuf : array[0..ONESDK_TRACE_ID_BUFFER_SIZE - 1] of AnsiChar;
  SpanIdBuf  : array[0..ONESDK_SPAN_ID_BUFFER_SIZE  - 1] of AnsiChar;
  Ret        : TOnesdk_result_t;
begin
  FillChar(TraceIdBuf, SizeOf(TraceIdBuf), 0);
  FillChar(SpanIdBuf,  SizeOf(SpanIdBuf),  0);
  Ret := onesdk_tracecontext_get_current(
    @TraceIdBuf[0], SizeOf(TraceIdBuf),
    @SpanIdBuf[0],  SizeOf(SpanIdBuf));
  Result.TraceId := string(AnsiString(PAnsiChar(@TraceIdBuf[0])));
  Result.SpanId  := string(AnsiString(PAnsiChar(@SpanIdBuf[0])));
  Result.IsValid := (Ret = ONESDK_SUCCESS);
end;

procedure TOneAgentSDKImpl.SetLoggingCallback(ACallback: TOneAgentSDKLoggingCallback);
begin
  FCallbackLock.Enter;
  try
    FLoggingCallback := ACallback;
  finally
    FCallbackLock.Leave;
  end;
  if Assigned(ACallback) then
    onesdk_agent_set_warning_callback(@NativeLoggingBridge)
  else
    onesdk_agent_set_warning_callback(nil);
end;

function TOneAgentSDKImpl.CreateDatabaseInfo(
  const AName, AVendor: string;
  AChannelType: TChannelType;
  const AChannelEndpoint: string): IDatabaseInfo;
var
  SName, SVendor, SEndpoint : TOnesdk_string;
  H                         : TOnesdk_databaseinfo_handle_t;
begin
  MakeWStr(SName, AName);
  MakeWStr(SVendor, AVendor);
  if AChannelEndpoint <> '' then
    MakeWStr(SEndpoint, AChannelEndpoint)
  else
    MakeNullStr(SEndpoint);
  H := onesdk_databaseinfo_create_p(@SName, @SVendor, Int32(AChannelType), @SEndpoint);
  if H <> ONESDK_INVALID_HANDLE then
    Result := TDatabaseInfoImpl.Create(H)
  else
    Result := TNullDatabaseInfo.Create;
end;

function TOneAgentSDKImpl.TraceCustomService(
  const AServiceMethod, AServiceName: string): ITracer;
var
  SMethod, SName : TOnesdk_string;
  H              : TOnesdk_tracer_handle_t;
begin
  MakeWStr(SMethod, AServiceMethod);
  MakeWStr(SName, AServiceName);
  H := onesdk_customservicetracer_create_p(@SMethod, @SName);
  if H <> ONESDK_INVALID_HANDLE then
    Result := TTracerBase.Create(H)
  else
    Result := TNullTracer.Create;
end;

function TOneAgentSDKImpl.TraceOutgoingRemoteCall(
  const AServiceMethod, AServiceName, AServiceEndpoint: string;
  AChannelType: TChannelType;
  const AChannelEndpoint: string): IOutgoingRemoteCallTracer;
var
  SMethod, SName, SEndpoint, SChanEndpoint : TOnesdk_string;
  H                                        : TOnesdk_tracer_handle_t;
begin
  MakeWStr(SMethod, AServiceMethod);
  MakeWStr(SName, AServiceName);
  MakeWStr(SEndpoint, AServiceEndpoint);
  if AChannelEndpoint <> '' then
    MakeWStr(SChanEndpoint, AChannelEndpoint)
  else
    MakeNullStr(SChanEndpoint);
  H := onesdk_outgoingremotecalltracer_create_p(
    @SMethod, @SName, @SEndpoint, Int32(AChannelType), @SChanEndpoint);
  if H <> ONESDK_INVALID_HANDLE then
    Result := TOutgoingRemoteCallTracerImpl.Create(H)
  else
    Result := TNullTracer.Create;
end;

function TOneAgentSDKImpl.TraceIncomingRemoteCall(
  const AServiceMethod, AServiceName, AServiceEndpoint: string
): IIncomingRemoteCallTracer;
var
  SMethod, SName, SEndpoint : TOnesdk_string;
  H                         : TOnesdk_tracer_handle_t;
begin
  MakeWStr(SMethod, AServiceMethod);
  MakeWStr(SName, AServiceName);
  MakeWStr(SEndpoint, AServiceEndpoint);
  H := onesdk_incomingremotecalltracer_create_p(@SMethod, @SName, @SEndpoint);
  if H <> ONESDK_INVALID_HANDLE then
    Result := TIncomingRemoteCallTracerImpl.Create(H)
  else
    Result := TNullTracer.Create;
end;

function TOneAgentSDKImpl.TraceOutgoingWebRequest(
  const AUrl, AMethod: string): IOutgoingWebRequestTracer;
var
  SUrl, SMethod : TOnesdk_string;
  H             : TOnesdk_tracer_handle_t;
begin
  MakeWStr(SUrl, AUrl);
  MakeWStr(SMethod, AMethod);
  H := onesdk_outgoingwebrequesttracer_create_p(@SUrl, @SMethod);
  if H <> ONESDK_INVALID_HANDLE then
    Result := TOutgoingWebRequestTracerImpl.Create(H)
  else
    Result := TNullTracer.Create;
end;

function TOneAgentSDKImpl.TraceSQLDatabaseRequest(
  ADatabaseInfo: IDatabaseInfo;
  const AStatement: string): IDatabaseRequestTracer;
var
  InfoHandle : IDatabaseInfoHandle;
  DbH        : TOnesdk_databaseinfo_handle_t;
  SStmt      : TOnesdk_string;
  H          : TOnesdk_tracer_handle_t;
begin
  // Retrieve the native handle through the internal IDatabaseInfoHandle interface.
  if Supports(ADatabaseInfo, IDatabaseInfoHandle, InfoHandle) then
    DbH := InfoHandle.GetNativeHandle
  else
    DbH := ONESDK_INVALID_HANDLE;

  if DbH = ONESDK_INVALID_HANDLE then
  begin
    Result := TNullTracer.Create;
    Exit;
  end;

  MakeWStr(SStmt, AStatement);
  H := onesdk_databaserequesttracer_create_sql_p(DbH, @SStmt);
  if H <> ONESDK_INVALID_HANDLE then
    Result := TDatabaseRequestTracerImpl.Create(H)
  else
    Result := TNullTracer.Create;
end;

procedure TOneAgentSDKImpl.AddCustomRequestAttribute(const AKey, AValue: string);
var
  KStr, VStr: TOnesdk_string;
begin
  MakeWStr(KStr, AKey);
  MakeWStr(VStr, AValue);
  onesdk_customrequestattribute_add_strings_p(@KStr, @VStr, 1);
end;

procedure TOneAgentSDKImpl.AddCustomRequestAttribute(const AKey: string; AValue: Int64);
var
  KStr : TOnesdk_string;
  V    : Int64;
begin
  MakeWStr(KStr, AKey);
  V := AValue;
  onesdk_customrequestattribute_add_integers_p(@KStr, @V, 1);
end;

procedure TOneAgentSDKImpl.AddCustomRequestAttribute(const AKey: string; AValue: Double);
var
  KStr : TOnesdk_string;
  V    : Double;
begin
  MakeWStr(KStr, AKey);
  V := AValue;
  onesdk_customrequestattribute_add_floats_p(@KStr, @V, 1);
end;

initialization
  GSDKCallbackLock := TCriticalSection.Create;

finalization
  GSDKCallbackLock.Free;
  GSDKCallbackLock := nil;

end.
