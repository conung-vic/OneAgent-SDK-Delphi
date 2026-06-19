unit UMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  System.JSON,
  System.Net.HttpClient,
  System.Net.URLClient,
  OneAgentSDK,
  OneAgentSDK.Types,
  Vcl.ExtCtrls;

type
  TfrmMain = class(TForm)
    btnRequest: TButton;
    edAddress: TEdit;
    mmResponse: TMemo;
    btnClear: TButton;
    shIndicator: TShape;
    procedure btnRequestClick(Sender: TObject);
    procedure btnClearClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    SDK: IOneAgentSDK;
    procedure Log(const AMsg: string);
    procedure OnSDKWarning(const AMessage: string);
    procedure RunHttpRequest;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}


procedure TfrmMain.Log(const AMsg: string);
begin
  mmResponse.Lines.Add(AMsg);
end;

procedure TfrmMain.OnSDKWarning(const AMessage: string);
begin
  Log('[SDK Warning] ' + AMessage);
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  SDK := CreateOneAgentSDK;
  SDK.SetLoggingCallback(OnSDKWarning);

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
  SDK := nil;
end;

procedure TfrmMain.btnClearClick(Sender: TObject);
begin
  mmResponse.Lines.Clear;
end;

procedure TfrmMain.btnRequestClick(Sender: TObject);
begin
  RunHttpRequest;
end;

procedure TfrmMain.RunHttpRequest;
var
  Tracer   : IOutgoingWebRequestTracer;
  Http     : THTTPClient;
  Response : IHTTPResponse;
  Tag      : string;
  Ctx      : TTraceContextInfo;
  I        : Integer;
  Header   : TNameValuePair;
begin
  Tracer := SDK.TraceOutgoingWebRequest(edAddress.Text, 'GET');

  Http := THTTPClient.Create;
  try
    Tracer.AddRequestHeader('Accept', 'application/json');
    Tracer.Start;
    try
      Tag := Tracer.GetDynatraceStringTag;
      Log('DT tag: [' + Tag + ']');

      if Tag <> '' then
        Http.CustomHeaders[DYNATRACE_HTTP_HEADERNAME] := Tag;

      Ctx := SDK.GetTraceContextInfo;
      Log('TraceContext valid: ' + BoolToStr(Ctx.IsValid, True)
        + ', traceId: ' + Ctx.TraceId + ', spanId: ' + Ctx.SpanId);

      if Ctx.IsValid then
        Http.CustomHeaders[DYNATRACE_HTTP_W3C_PARENT] :=
          '00-' + Ctx.TraceId + '-' + Ctx.SpanId + '-01';

      Response := Http.Get(edAddress.Text);

      for I := 0 to Length(Response.Headers) - 1 do
      begin
        Header := Response.Headers[I];
        Tracer.AddResponseHeader(Header.Name, Header.Value);
      end;
      Tracer.SetStatusCode(Response.StatusCode);

      Log('HTTP ' + IntToStr(Response.StatusCode));

      if Response.StatusCode = 200 then
        Log(Response.ContentAsString(TEncoding.UTF8))
      else
        Log('Response body: ' + Response.ContentAsString(TEncoding.UTF8));
    except
      on E: Exception do
      begin
        Tracer.SetError(E.ClassName, E.Message);
        Log(E.ClassName + ': ' + E.Message);
      end;
    end;
  finally
    Tracer.Finish;
    Http.Free;
  end;
end;

end.
