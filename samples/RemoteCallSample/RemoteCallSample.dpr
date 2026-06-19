program RemoteCallSample;

{$APPTYPE CONSOLE}
{$R *.res}

{
  Demonstrates tracing outgoing and incoming remote calls with tag propagation.

  In a real distributed system:
  - The CALLER uses TraceOutgoingRemoteCall, retrieves the tag after Start,
    and sends it to the remote service (e.g. in an HTTP header or gRPC metadata).
  - The CALLEE uses TraceIncomingRemoteCall, injects the received tag before Start,
    and the two traces are linked in the Dynatrace UI.

  This sample simulates both sides in one process to show the full pattern.
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

// Simulates the SERVICE SIDE receiving and processing a remote call.
procedure SimulateIncomingRemoteCall(const SDK: IOneAgentSDK; const IncomingTag: string);
var
  Tracer : IIncomingRemoteCallTracer;
begin
  WriteLn('  [Server] Tracing incoming remote call...');
  Tracer := SDK.TraceIncomingRemoteCall('GetUser', 'UserService', 'grpc://users:9090');

  // Inject the propagation tag received from the caller (before Start).
  if IncomingTag <> '' then
    Tracer.SetDynatraceStringTag(IncomingTag);

  Tracer.SetProtocolName('gRPC');
  Tracer.Start;
  try
    WriteLn('  [Server] Handling GetUser request...');
    Sleep(5);
  except
    on E: Exception do
    begin
      Tracer.SetError(E.ClassName, E.Message);
    end;
  end;
  Tracer.Finish;
  WriteLn('  [Server] Done.');
end;

// Simulates the CLIENT SIDE making an outgoing remote call.
procedure SimulateOutgoingRemoteCall(const SDK: IOneAgentSDK);
var
  Tracer      : IOutgoingRemoteCallTracer;
  OutgoingTag : string;
begin
  WriteLn('  [Client] Tracing outgoing remote call...');
  Tracer := SDK.TraceOutgoingRemoteCall(
    'GetUser',            // service method
    'UserService',        // service name
    'grpc://users:9090',  // logical service endpoint
    ctTcpIp,             // channel type
    'users:9090'         // physical channel endpoint
  );
  Tracer.SetProtocolName('gRPC');
  Tracer.Start;
  try
    // Retrieve the propagation tag and send it with the request.
    OutgoingTag := Tracer.GetDynatraceStringTag;
    WriteLn('  [Client] Propagation tag: ', OutgoingTag);

    // In a real app, OutgoingTag would be sent in the HTTP header 'X-dynaTrace'
    // or equivalent mechanism. Here we pass it directly to the server side.
    SimulateIncomingRemoteCall(SDK, OutgoingTag);
  except
    on E: Exception do
    begin
      Tracer.SetError(E.ClassName, E.Message);
    end;
  end;
  Tracer.Finish;
  WriteLn('  [Client] Done.');
end;

var
  SDK : IOneAgentSDK;

begin
  try
    SDK := CreateOneAgentSDK;
    SDK.SetLoggingCallback(OnSDKWarning);

    WriteLn('SDK state: ', Ord(SDK.GetCurrentState));
    WriteLn;
    WriteLn('--- Outgoing + Incoming Remote Call ---');
    SimulateOutgoingRemoteCall(SDK);
    WriteLn;
    WriteLn('Sample complete.');
  except
    on E: Exception do
      WriteLn(E.ClassName, ': ', E.Message);
  end;
end.
