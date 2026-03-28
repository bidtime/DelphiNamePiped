object Form2: TForm2
  Left = 0
  Top = 0
  Caption = 'Delphi Client'
  ClientHeight = 350
  ClientWidth = 635
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  DesignSize = (
    635
    350)
  TextHeight = 13
  object Label1: TLabel
    Left = 8
    Top = 322
    Width = 73
    Height = 13
    Anchors = [akLeft, akBottom]
    Caption = 'Send Message:'
  end
  object memoLog: TMemo
    Left = 6
    Top = 29
    Width = 623
    Height = 284
    Anchors = [akLeft, akTop, akRight, akBottom]
    ReadOnly = True
    ScrollBars = ssBoth
    TabOrder = 0
  end
  object edtText: TEdit
    Left = 87
    Top = 319
    Width = 459
    Height = 21
    TabOrder = 1
    Text = #26469#33258#23458#25143#31471#28040#24687
  end
  object Button1: TButton
    Left = 552
    Top = 317
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = 'Send'
    TabOrder = 2
    OnClick = Button1Click
  end
  object ToolBar1: TToolBar
    Left = 0
    Top = 0
    Width = 635
    Height = 24
    ButtonHeight = 21
    Caption = 'ToolBar1'
    TabOrder = 3
    DesignSize = (
      635
      24)
    object ToolButton1: TToolButton
      Left = 0
      Top = 0
      Width = 8
      Caption = 'ToolButton1'
      Style = tbsSeparator
    end
    object btnClear: TButton
      Left = 8
      Top = 0
      Width = 75
      Height = 21
      Caption = 'Clear'
      TabOrder = 0
      OnClick = btnClearClick
    end
    object chkBreak: TCheckBox
      Left = 83
      Top = 0
      Width = 35
      Height = 21
      Caption = 'bk'
      TabOrder = 5
    end
    object edDelay: TEdit
      Left = 118
      Top = 0
      Width = 19
      Height = 21
      TabOrder = 6
      Text = '0'
    end
    object btnDoLoop: TButton
      Left = 137
      Top = 0
      Width = 75
      Height = 21
      Caption = 'DoLoop'
      TabOrder = 7
      OnClick = btnDoLoopClick
    end
    object cbAuto: TCheckBox
      Left = 212
      Top = 0
      Width = 57
      Height = 21
      Caption = 'cbAuto'
      TabOrder = 3
    end
    object edtPipeName: TEdit
      Left = 269
      Top = 0
      Width = 92
      Height = 21
      TabOrder = 4
      Text = 'MyPublicPipe'
    end
    object Button3: TButton
      Left = 361
      Top = 0
      Width = 75
      Height = 21
      Anchors = [akTop, akRight]
      Caption = 'Connect'
      TabOrder = 2
      OnClick = Button3Click
    end
    object Button2: TButton
      Left = 436
      Top = 0
      Width = 75
      Height = 21
      Anchors = [akTop, akRight]
      Caption = 'Disconnect'
      TabOrder = 1
      OnClick = Button2Click
    end
  end
end
