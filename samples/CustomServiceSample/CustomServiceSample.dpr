program CustomServiceSample;

{$APPTYPE CONSOLE}
{$R *.res}

{
  Demonstrates tracing a custom service call with the Dynatrace OneAgent SDK.
  Run this inside a Dynatrace-monitored environment to see the traced service
  appear in the Dynatrace UI under the configured service name.
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

procedure SimulateOrderProcessing(const SDK: IOneAgentSDK);
var
  Tracer : ITracer;
begin
  // Create a tracer for the business operation.
  Tracer := SDK.TraceCustomService('processOrder', 'OrderService');

  // Optionally attach searchable attributes before or after Start.
  SDK.AddCustomRequestAttribute('order.region', 'EMEA');
  SDK.AddCustomRequestAttribute('order.priority', Int64(1));

  Tracer.Start;
  try
    WriteLn('  Processing order...');
    // Simulate work (replace with real application logic).
    Sleep(10);
    WriteLn('  Order processed.');
  except
    on E: Exception do
    begin
      // Report the error to Dynatrace
      Tracer.SetError(E.ClassName, E.Message);
    end;
  end;
  Tracer.Finish;
end;

var
  SDK   : IOneAgentSDK;
  State : TSdkState;
  Info  : TTraceContextInfo;

begin
  try
    SDK := CreateOneAgentSDK;
    SDK.SetLoggingCallback(OnSDKWarning);

    State := SDK.GetCurrentState;
    Write('OneAgent SDK state: ');
    case State of
      sdkActive              : WriteLn('ACTIVE');
      sdkTemporarilyInactive : WriteLn('TEMPORARILY INACTIVE');
      sdkPermanentlyInactive : WriteLn('PERMANENTLY INACTIVE');
      sdkNotInitialized      : WriteLn('NOT INITIALIZED');
    else
      WriteLn('ERROR');
    end;

    WriteLn('Tracing custom service...');
    SimulateOrderProcessing(SDK);

    // Demonstrate log enrichment with W3C trace context.
    Info := SDK.GetTraceContextInfo;
    if Info.IsValid then
      WriteLn(Format('Log enrichment: dt.trace_id=%s dt.span_id=%s', [Info.TraceId, Info.SpanId]))
    else
      WriteLn('No active PurePath node (expected when running outside a traced request).');

    WriteLn('Done.');
  except
    on E: Exception do
      WriteLn(E.ClassName, ': ', E.Message);
  end;
end.
