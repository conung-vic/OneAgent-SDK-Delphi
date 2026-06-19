object frmMain: TfrmMain
  Left = 0
  Top = 0
  BorderStyle = bsSingle
  Caption = 'Full Chain Tracing: Client -> Server -> Database'
  ClientHeight = 520
  ClientWidth = 800
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object shIndicator: TShape
    Left = 752
    Top = 8
    Width = 26
    Height = 25
    Brush.Color = clRed
    Shape = stCircle
  end
  object lblPort: TLabel
    Left = 8
    Top = 12
    Width = 24
    Height = 15
    Caption = 'Port'
  end
  object btnStartServer: TButton
    Left = 120
    Top = 8
    Width = 105
    Height = 25
    Caption = 'Start Server'
    TabOrder = 0
    OnClick = btnStartServerClick
  end
  object btnSendRequest: TButton
    Left = 231
    Top = 8
    Width = 120
    Height = 25
    Caption = 'Send Request'
    TabOrder = 1
    OnClick = btnSendRequestClick
  end
  object btnClear: TButton
    Left = 357
    Top = 8
    Width = 75
    Height = 25
    Caption = 'Clear'
    TabOrder = 2
    OnClick = btnClearClick
  end
  object edPort: TEdit
    Left = 38
    Top = 8
    Width = 76
    Height = 23
    TabOrder = 3
    Text = '8080'
  end
  object mmLog: TMemo
    Left = 8
    Top = 45
    Width = 784
    Height = 467
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 4
  end
end
