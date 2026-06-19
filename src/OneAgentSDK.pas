unit OneAgentSDK;

{
  Dynatrace OneAgent SDK for Delphi — Public API
  Interfaces, factory function, and propagation header/property name constants.

  Quick start:
    SDK := CreateOneAgentSDK;
    Tracer := SDK.TraceCustomService('MyMethod', 'MyService');
    Tracer.Start;
    try
      // ... do work ...
    except on E: Exception do begin
      Tracer.SetError(E.ClassName, E.Message);
      raise;
    end;
    end;
    Tracer.Finish;

  IMPORTANT — thread affinity:
    All tracer interfaces have strict thread affinity: they must be created, used (Start, SetError,
    Finish), and released on the same thread. Do not pass ITracer instances across threads.
}

interface

uses
  OneAgentSDK.Types;

const
  // HTTP header name for outgoing Dynatrace tag propagation.
  // Set this header on outgoing HTTP requests using the value from IOutgoingRemoteCallTracer.GetDynatraceStringTag.
  DYNATRACE_HTTP_HEADERNAME = 'X-dynaTrace';
  DYNATRACE_HTTP_W3C_PARENT = 'traceparent';
  DYNATRACE_HTTP_W3C_STATE = 'tracestate';

  // Message property name for Dynatrace tag propagation via messaging systems.
  DYNATRACE_MESSAGE_PROPERTYNAME = 'dtdTraceTagInfo';

type
  // Base tracer interface. All tracers follow the Start → [SetError] → Finish lifecycle.
  ITracer = interface
    ['{A4B3C2D1-E5F6-7890-ABCD-EF1234567890}']
    // Starts timing and captures entry fields. Call exactly once before Finish.
    procedure Start;
    // Records an error on this tracer. Call at most once; concatenate multiple errors if needed.
    procedure SetError(const AMessage: string); overload;
    procedure SetError(const AErrorClass, AMessage: string); overload;
    // Ends timing, flushes data, and releases the tracer handle. Call exactly once.
    // Note: the destructor will call Finish automatically if you forget, but explicit calls are preferred.
    procedure Finish;
  end;

  // Tracer for an outgoing remote call (RPC, gRPC, custom protocol, etc.).
  IOutgoingRemoteCallTracer = interface(ITracer)
    ['{B5C4D3E2-F6A7-8901-BCDE-F12345678901}']
    // Returns the Dynatrace propagation tag as an ASCII string.
    // Call AFTER Start. Send this value in the DYNATRACE_HTTP_HEADERNAME HTTP header
    // or DYNATRACE_MESSAGE_PROPERTYNAME message property on the outgoing request.
    function GetDynatraceStringTag: string;
    // Optionally sets the wire protocol name. Call BEFORE Start.
    procedure SetProtocolName(const AProtocolName: string);
  end;

  // Tracer for an incoming remote call (server/handler side).
  IIncomingRemoteCallTracer = interface(ITracer)
    ['{C6D5E4F3-A7B8-9012-CDEF-012345678902}']
    // Injects the incoming propagation tag received from the caller.
    // Call BEFORE Start. Pass the value received in DYNATRACE_HTTP_HEADERNAME or DYNATRACE_MESSAGE_PROPERTYNAME.
    procedure SetDynatraceStringTag(const ATag: string);
    // Optionally sets the wire protocol name. Call BEFORE Start.
    procedure SetProtocolName(const AProtocolName: string);
  end;

  // Tracer for an outgoing HTTP request (client side).
  IOutgoingWebRequestTracer = interface(ITracer)
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567891}']
    // Returns the Dynatrace propagation tag as an ASCII string.
    // Call AFTER Start. Send this value in the 'X-dynaTrace' HTTP header.
    function GetDynatraceStringTag: string;
    // Adds an HTTP request header. Call BEFORE Start.
    procedure AddRequestHeader(const AName, AValue: string);
    // Adds an HTTP response header. Call AFTER the response is received, BEFORE Finish.
    procedure AddResponseHeader(const AName, AValue: string);
    // Sets the HTTP response status code. Call AFTER the response is received, BEFORE Finish.
    procedure SetStatusCode(AStatusCode: Integer);
  end;

  // Opaque descriptor for a database instance. Create once and reuse across requests.
  // The descriptor is released when the last interface reference is dropped.
  IDatabaseInfo = interface
    ['{D7E6F5A4-B8C9-0123-DEF0-123456789003}']
  end;

  // Tracer for an outgoing SQL database request.
  IDatabaseRequestTracer = interface(ITracer)
    ['{E8F7A6B5-C9D0-1234-EF01-234567890004}']
    // Optional metadata, typically set after the query completes and before Finish.
    procedure SetReturnedRowCount(ACount: Integer);
    procedure SetRoundTripCount(ACount: Integer);
  end;

  // Root SDK interface. Obtain an instance via CreateOneAgentSDK.
  IOneAgentSDK = interface
    ['{F9A8B7C6-D0E1-2345-F012-345678900005}']

    // Returns the current operational state of the SDK/agent.
    function GetCurrentState: TSdkState;

    // Returns W3C trace and span IDs for the currently active PurePath node.
    // Intended for structured log enrichment only — not for tag propagation between services.
    function GetTraceContextInfo: TTraceContextInfo;

    // Installs a callback to receive SDK warning messages. Pass nil to remove.
    // The callback must be thread-safe when the SDK is used on multiple threads.
    procedure SetLoggingCallback(ACallback: TOneAgentSDKLoggingCallback);

    // Creates a database info descriptor used with TraceSQLDatabaseRequest.
    // AChannelEndpoint is optional (pass '' if unknown).
    // For well-known database vendors use the DB_VENDOR_* constants in OneAgentSDK.Types.
    function CreateDatabaseInfo(
      const AName, AVendor: string;
      AChannelType: TChannelType;
      const AChannelEndpoint: string): IDatabaseInfo;

    // Traces an arbitrary service call that does not fit any other tracer type.
    function TraceCustomService(
      const AServiceMethod, AServiceName: string): ITracer;

    // Traces an outgoing remote call. After Start, call GetDynatraceStringTag and
    // propagate the tag with the request.
    // AChannelEndpoint is optional (pass '' if unknown).
    function TraceOutgoingRemoteCall(
      const AServiceMethod, AServiceName, AServiceEndpoint: string;
      AChannelType: TChannelType;
      const AChannelEndpoint: string): IOutgoingRemoteCallTracer;

    // Traces an incoming remote call (server side).
    // Before Start, call SetDynatraceStringTag with the tag received from the caller.
    function TraceIncomingRemoteCall(
      const AServiceMethod, AServiceName, AServiceEndpoint: string
    ): IIncomingRemoteCallTracer;

    // Traces an outgoing SQL request against the given database.
    // ADatabaseInfo must have been created by CreateDatabaseInfo on this SDK instance.
    function TraceSQLDatabaseRequest(
      ADatabaseInfo: IDatabaseInfo;
      const AStatement: string): IDatabaseRequestTracer;

    // Traces an outgoing HTTP web request.
    // AUrl is the full URL including scheme, host, path, and query string.
    // AMethod is the HTTP method (GET, POST, etc.).
    function TraceOutgoingWebRequest(
      const AUrl, AMethod: string): IOutgoingWebRequestTracer;

    // Attaches a searchable custom attribute to the currently active PurePath node.
    // May be called multiple times; duplicate keys record multiple values.
    procedure AddCustomRequestAttribute(const AKey, AValue: string); overload;
    procedure AddCustomRequestAttribute(const AKey: string; AValue: Int64); overload;
    procedure AddCustomRequestAttribute(const AKey: string; AValue: Double); overload;
  end;

// Sets an SDK stub variable BEFORE calling CreateOneAgentSDK.
// Use this to point the stub at a OneAgent installation without the installer.
// AKey and AValue are separate for convenience; internally passed as 'key=value'.
// Supported keys:
//   'home'        - OneAgent installation folder (e.g. 'C:\oneagent')
//   'tenant'      - Environment ID of your Dynatrace environment
//   'tenantToken' - Agent connection token (NOT an API or PaaS token)
//   'server'      - Dynatrace Server / ActiveGate URL(s)
//   'loglevelcon' - Console log level ('none' to suppress)
procedure SetOneAgentSDKVariable(const AKey, AValue: string);

// Creates an IOneAgentSDK instance.
// When a compatible Dynatrace OneAgent is found, returns a live implementation.
// Otherwise returns a no-op implementation that is always safe to call.
// The underlying C SDK is shut down automatically when the last IOneAgentSDK reference is released.
function CreateOneAgentSDK: IOneAgentSDK;

implementation

uses
  OneAgentSDK.Native,
  OneAgentSDK.Impl,
  OneAgentSDK.NullImpl;

procedure SetOneAgentSDKVariable(const AKey, AValue: string);
var
  Combined: string;
begin
  Combined := AKey + '=' + AValue;
  onesdk_stub_set_variable(PWideChar(Combined), 1);
end;

function CreateOneAgentSDK: IOneAgentSDK;
var
  InitOK: Boolean;
begin
  InitOK := (onesdk_initialize = ONESDK_SUCCESS);
  // Always create the live impl so that diagnostic functions
  // (GetCurrentState, agent_get_version_string, stub_get_agent_load_info)
  // return real data even when init fails. The C SDK functions are safe
  // to call after a failed initialize — they return sensible defaults.
  Result := TOneAgentSDKImpl.Create(InitOK);
end;

end.
