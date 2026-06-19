object frmMain: TfrmMain
  Left = 0
  Top = 0
  BorderStyle = bsSingle
  Caption = 'HTTP Example for Dynatrace OneAgent'
  ClientHeight = 498
  ClientWidth = 1064
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
    Left = 1007
    Top = 8
    Width = 26
    Height = 25
    Brush.Color = clRed
    Shape = stCircle
  end
  object btnRequest: TButton
    Left = 8
    Top = 8
    Width = 105
    Height = 25
    Caption = 'Make Request'
    TabOrder = 0
    OnClick = btnRequestClick
  end
  object edAddress: TEdit
    Left = 119
    Top = 8
    Width = 866
    Height = 23
    TabOrder = 1
    Text = 'http://localhost:7071/api/HttpTriggerJava'
  end
  object mmResponse: TMemo
    Left = 119
    Top = 64
    Width = 914
    Height = 417
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 2
  end
  object btnClear: TButton
    Left = 8
    Top = 63
    Width = 105
    Height = 25
    Caption = 'Clear'
    TabOrder = 3
    OnClick = btnClearClick
  end
end
