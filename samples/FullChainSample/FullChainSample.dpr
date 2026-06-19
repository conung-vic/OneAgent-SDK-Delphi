program FullChainSample;

uses
  System.SysUtils,
  System.Classes,
  OneAgentSDK in '..\..\src\OneAgentSDK.pas',
  OneAgentSDK.Types in '..\..\src\OneAgentSDK.Types.pas',
  OneAgentSDK.Native in '..\..\src\OneAgentSDK.Native.pas',
  OneAgentSDK.Impl in '..\..\src\OneAgentSDK.Impl.pas',
  OneAgentSDK.NullImpl in '..\..\src\OneAgentSDK.NullImpl.pas',
  Vcl.Forms,
  UMain in 'UMain.pas' {frmMain};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
