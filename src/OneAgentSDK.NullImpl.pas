unit OneAgentSDK.NullImpl;

{
  Dynatrace OneAgent SDK for Delphi — No-op implementation.
  Returned by CreateOneAgentSDK when the Dynatrace OneAgent is not present.
  All methods are safe to call and return sensible defaults.
}

interface

uses
  OneAgentSDK,
  OneAgentSDK.Types;

type
  // Shared no-op tracer. Implements all tracer interfaces so it can be returned
  // from any factory method in TOneAgentSDKNullImpl.
  TNullTracer = class(TInterfacedObject,
    ITracer,
    IOutgoingRemoteCallTracer,
    IIncomingRemoteCallTracer,
    IOutgoingWebRequestTracer,
    IDatabaseRequestTracer)
  public
    // ITracer
    procedure Start;
    procedure SetError(const AMessage: string); overload;
    procedure SetError(const AErrorClass, AMessage: string); overload;
    procedure Finish;
    // IOutgoingRemoteCallTracer
    function  GetDynatraceStringTag: string;
    procedure SetProtocolName(const AProtocolName: string);
    // IIncomingRemoteCallTracer
    procedure SetDynatraceStringTag(const ATag: string);
    // IOutgoingWebRequestTracer
    procedure AddRequestHeader(const AName, AValue: string);
    procedure AddResponseHeader(const AName, AValue: string);
    procedure SetStatusCode(AStatusCode: Integer);
    // IDatabaseRequestTracer
    procedure SetReturnedRowCount(ACount: Integer);
    procedure SetRoundTripCount(ACount: Integer);
  end;

  TNullDatabaseInfo = class(TInterfacedObject, IDatabaseInfo);

  TOneAgentSDKNullImpl = class(TInterfacedObject, IOneAgentSDK)
  public
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

implementation

// ---------------------------------------------------------------------------
// TNullTracer
// ---------------------------------------------------------------------------

procedure TNullTracer.Start;
begin
end;

procedure TNullTracer.SetError(const AMessage: string);
begin
end;

procedure TNullTracer.SetError(const AErrorClass, AMessage: string);
begin
end;

procedure TNullTracer.Finish;
begin
end;

function TNullTracer.GetDynatraceStringTag: string;
begin
  Result := '';
end;

procedure TNullTracer.SetProtocolName(const AProtocolName: string);
begin
end;

procedure TNullTracer.SetDynatraceStringTag(const ATag: string);
begin
end;

procedure TNullTracer.AddRequestHeader(const AName, AValue: string);
begin
end;

procedure TNullTracer.AddResponseHeader(const AName, AValue: string);
begin
end;

procedure TNullTracer.SetStatusCode(AStatusCode: Integer);
begin
end;

procedure TNullTracer.SetReturnedRowCount(ACount: Integer);
begin
end;

procedure TNullTracer.SetRoundTripCount(ACount: Integer);
begin
end;

// ---------------------------------------------------------------------------
// TOneAgentSDKNullImpl
// ---------------------------------------------------------------------------

function TOneAgentSDKNullImpl.GetCurrentState: TSdkState;
begin
  Result := sdkPermanentlyInactive;
end;

function TOneAgentSDKNullImpl.GetTraceContextInfo: TTraceContextInfo;
begin
  Result.TraceId := '00000000000000000000000000000000';
  Result.SpanId  := '0000000000000000';
  Result.IsValid := False;
end;

procedure TOneAgentSDKNullImpl.SetLoggingCallback(ACallback: TOneAgentSDKLoggingCallback);
begin
end;

function TOneAgentSDKNullImpl.CreateDatabaseInfo(
  const AName, AVendor: string;
  AChannelType: TChannelType;
  const AChannelEndpoint: string): IDatabaseInfo;
begin
  Result := TNullDatabaseInfo.Create;
end;

function TOneAgentSDKNullImpl.TraceCustomService(
  const AServiceMethod, AServiceName: string): ITracer;
begin
  Result := TNullTracer.Create;
end;

function TOneAgentSDKNullImpl.TraceOutgoingRemoteCall(
  const AServiceMethod, AServiceName, AServiceEndpoint: string;
  AChannelType: TChannelType;
  const AChannelEndpoint: string): IOutgoingRemoteCallTracer;
begin
  Result := TNullTracer.Create;
end;

function TOneAgentSDKNullImpl.TraceIncomingRemoteCall(
  const AServiceMethod, AServiceName, AServiceEndpoint: string
): IIncomingRemoteCallTracer;
begin
  Result := TNullTracer.Create;
end;

function TOneAgentSDKNullImpl.TraceOutgoingWebRequest(
  const AUrl, AMethod: string): IOutgoingWebRequestTracer;
begin
  Result := TNullTracer.Create;
end;

function TOneAgentSDKNullImpl.TraceSQLDatabaseRequest(
  ADatabaseInfo: IDatabaseInfo;
  const AStatement: string): IDatabaseRequestTracer;
begin
  Result := TNullTracer.Create;
end;

procedure TOneAgentSDKNullImpl.AddCustomRequestAttribute(const AKey, AValue: string);
begin
end;

procedure TOneAgentSDKNullImpl.AddCustomRequestAttribute(const AKey: string; AValue: Int64);
begin
end;

procedure TOneAgentSDKNullImpl.AddCustomRequestAttribute(const AKey: string; AValue: Double);
begin
end;

end.
