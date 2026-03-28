object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Delphi Server'
  ClientHeight = 450
  ClientWidth = 659
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 13
  object memoLog: TMemo
    Tag = 1
    Left = 0
    Top = 23
    Width = 659
    Height = 378
    Align = alClient
    ReadOnly = True
    ScrollBars = ssBoth
    TabOrder = 0
  end
  object ToolBar1: TToolBar
    Left = 0
    Top = 0
    Width = 659
    Height = 23
    ButtonHeight = 21
    Caption = 'ToolBar1'
    TabOrder = 1
    DesignSize = (
      659
      23)
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
    object edtNums: TEdit
      Left = 83
      Top = 0
      Width = 46
      Height = 21
      TabOrder = 8
      Text = '5000'
    end
    object chkBreak: TCheckBox
      Left = 129
      Top = 0
      Width = 33
      Height = 21
      Caption = 'bk'
      TabOrder = 5
    end
    object edDelay: TEdit
      Left = 162
      Top = 0
      Width = 19
      Height = 21
      TabOrder = 7
      Text = '0'
    end
    object btnDoLoop: TButton
      Left = 181
      Top = 0
      Width = 75
      Height = 21
      Caption = 'DoLoop'
      TabOrder = 1
      OnClick = btnDoLoopClick
    end
    object cbAuto: TCheckBox
      Left = 256
      Top = 0
      Width = 57
      Height = 21
      Caption = 'cbAuto'
      TabOrder = 4
    end
    object edtPipeName: TEdit
      Left = 313
      Top = 0
      Width = 121
      Height = 21
      TabOrder = 6
      Text = 'MyPublicPipe'
    end
    object Button3: TButton
      Left = 434
      Top = 0
      Width = 75
      Height = 21
      Anchors = [akTop, akRight]
      Caption = 'Start Server'
      TabOrder = 3
      OnClick = Button3Click
    end
    object Button2: TButton
      Left = 509
      Top = 0
      Width = 75
      Height = 21
      Anchors = [akTop, akRight]
      Caption = 'Stop Server'
      TabOrder = 2
      OnClick = Button2Click
    end
  end
  object GroupBox1: TGroupBox
    Left = 0
    Top = 401
    Width = 659
    Height = 49
    Align = alBottom
    Caption = 'Message:'
    TabOrder = 2
    ExplicitLeft = 8
    ExplicitTop = 232
    ExplicitWidth = 609
    DesignSize = (
      659
      49)
    object edtText: TEdit
      Left = 14
      Top = 18
      Width = 547
      Height = 21
      Anchors = [akLeft, akTop, akRight, akBottom]
      TabOrder = 0
      Text = #26469#33258#26381#21153#22120#28040#24687
    end
    object Button1: TButton
      Left = 575
      Top = 16
      Width = 75
      Height = 25
      Anchors = [akRight, akBottom]
      Caption = 'Send'
      TabOrder = 1
      OnClick = Button1Click
    end
  end
end
