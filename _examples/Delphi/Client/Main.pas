unit Main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, TBUNamedClientPipe,
  Vcl.ComCtrls, Vcl.ToolWin;

type
  TForm2 = class(TForm)
    memoLog: TMemo;
    edtText: TEdit;
    Button1: TButton;
    Button3: TButton;
    Button2: TButton;
    edtPipeName: TEdit;
    cbAuto: TCheckBox;
    btnClear: TButton;
    ToolBar1: TToolBar;
    ToolButton1: TToolButton;
    Label1: TLabel;
    chkBreak: TCheckBox;
    edDelay: TEdit;
    btnDoLoop: TButton;
    edtNums: TEdit;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnClearClick(Sender: TObject);
    procedure btnDoLoopClick(Sender: TObject);
  private
    FConnected: Boolean;
    FMaxLogLines: Word;
    FAutoScroll: boolean;
    procedure SetButtons;
    function readWriteIni(const bWrite: boolean): boolean;
    function isBreak(): boolean;
    procedure ExecuteLoop(ACallback: TProc<Word>);
    procedure AddLog(const S: string);
    class procedure TaskForceQueue(const AMethod: TThreadProcedure);
    procedure showText(const S: string);
    class procedure delay(const MaxWaitTime: DWORD; cbBreak: TFunc<boolean>=nil); static;
  public
    procedure OnDisconnect(aPipe: Cardinal); stdcall;
    procedure OnError(aPipe: Cardinal; aPipeContext: ShortInt; aErrorCode: Integer); stdcall;
    procedure OnMessage(aPipe: Cardinal; aMsg: PWideChar); stdcall;
    procedure OnSent(aPipe, aSize: Cardinal); stdcall;
  end;

var
  Form2: TForm2;

implementation

uses uFormIniFiles, System.Threading, Winapi.PsAPI;

{$R *.dfm}

procedure TForm2.SetButtons;
begin
  Button1.Enabled := FConnected;
  Button2.Enabled := FConnected;
  Button3.Enabled := not FConnected;
end;

procedure TForm2.AddLog(const S: string);
var str: string;
begin
  if (isBreak()) then
    exit;

  TThread.ForceQueue(nil,
  procedure
  begin
    if (isBreak()) then
      exit;
    str := format('%s %s', [FormatDateTime('YYYY-MM-DD hh:nn:ss zzz', now()), S]);
    self.ShowText(S);
  end);
end;

procedure TForm2.showText(const S: string);
begin
  if isBreak() then
    Exit;

  try
    // 开始批量更新以提高性能
    memoLog.Lines.BeginUpdate;
    try
      // 检查是否需要删除旧的行
      if (FMaxLogLines > 0) and (memoLog.Lines.Count >= FMaxLogLines) then begin
        // 删除最旧的行以腾出空间
        while memoLog.Lines.Count >= FMaxLogLines do begin
          memoLog.Lines.Delete(0);
        end;
      end;
      memoLog.Lines.Add(formatDateTime('YYYY-MM-DD hh:nn:ss zzz', now) + ': ' + S);
      if FAutoScroll then
      begin
        memoLog.SelStart := Length(memoLog.Text);
        memoLog.SelLength := 0;
        // 发送滚动到底部的消息
        memoLog.Perform(WM_VSCROLL, SB_BOTTOM, 0);    //FMemo.Perform(EM_SCROLLCARET, 0, 0);
        //SendMessage(FMemo.Handle, WM_VSCROLL, SB_BOTTOM, 0);
      end;
    finally
      memoLog.Lines.EndUpdate;
    end;
  except
    on E: Exception do begin
      //doAddLog(PChar('TMemoAppender.DisplayLogLine 错误: ' + E.Message));
    end;
  end;end;

class procedure TForm2.TaskForceQueue(const AMethod: TThreadProcedure);
begin
  TTask.Run(
  procedure
  begin
    TThread.ForceQueue(nil, AMethod);
  end);
end;

procedure TForm2.btnClearClick(Sender: TObject);
begin
  self.memoLog.clear;
end;

procedure TForm2.btnDoLoopClick(Sender: TObject);
begin
  ExecuteLoop(
    procedure(n: word)
    begin
      AddLog(format('%d, %s', [n, edtText.Text]));
      PipeClientSend(PWideChar(format('%d, %s', [n, edtText.Text])));
//      if self.chkFmt.Checked then
//        AddLog('done: %d', [n])
//      else
//      if PipeClientSend(PWideChar(edtText.Text)) then begin
//        AddLog(Format('<< Successfully sent message: %d, %s', [n, edtText.Text]));
//      end else begin
//        AddLog(Format('<< Failed to sent message: %d, %s', [n, edtText.Text]));
//      end;
    end
  );
end;

procedure TForm2.Button1Click(Sender: TObject);
begin
  if PipeClientSend(PWideChar(edtText.Text)) then
    AddLog('<< Successfully sent message: ' + edtText.Text)
  else
    AddLog('<< Failed to send message: ' + edtText.Text);

  //edtText.Text := '';
end;

procedure TForm2.Button2Click(Sender: TObject);
begin
  PipeClientDisconnect;
  AddLog('<< Disconnected from pipe server.');
  FConnected := False;
  SetButtons;
end;

procedure TForm2.Button3Click(Sender: TObject);
begin
  FConnected := PipeClientConnectNamed(PWideChar(self.edtPipeName.Text));

  if FConnected then
    AddLog('<< Pipe client connected.')
  else
    AddLog('<< Unable to connect to the pipe server.');

  SetButtons;
end;

procedure TForm2.ExecuteLoop(ACallback: TProc<Word>);
var
  n, nDelay: word;
  StartTime, EndTime: Cardinal;
  TotalTime, Frequency: Double;
  LoopCount, MemUsage, LastMemUsage: Cardinal;
  ProcessHandle: THandle;
begin
  addLog('ExecuteLoop begin...');
  self.chkBreak.Checked := false;
  n := 0;
  LoopCount := 0;
  nDelay := StrToIntDef(self.edDelay.Text, 20);
  var curMaxLines := StrToIntDef(self.edtNums.Text, 2000);

  // 获取当前进程内存使用
  ProcessHandle := GetCurrentProcess;
  GetProcessMemoryInfo(ProcessHandle, @MemUsage, SizeOf(MemUsage));
  LastMemUsage := MemUsage;
  addLog('初始内存使用: ' + FormatFloat('0.00', MemUsage/1024/1024) + ' MB');

  StartTime := GetTickCount;

  while true do begin
    if n = Word.MaxValue then begin
      n := 0;
    end else begin
      Inc(n);
    end;

    Inc(LoopCount);

    if Assigned(ACallback) then
    begin
      ACallback(n);
    end;

    // 每100次检查一次内存
    if (LoopCount mod 100) = 0 then
    begin
      GetProcessMemoryInfo(ProcessHandle, @MemUsage, SizeOf(MemUsage));
      if MemUsage > LastMemUsage + 1024 * 1024 then  // 内存增加超过1MB
      begin
        addLog('内存增加: ' + FormatFloat('0.00', (MemUsage-LastMemUsage)/1024/1024) + ' MB');
        LastMemUsage := MemUsage;
      end;
    end;

    delay(nDelay);

    if self.isBreak() or (self.chkBreak.Checked) or (not self.FConnected) or (LoopCount >= curMaxLines) then begin
      break;
    end;
  end;

  EndTime := GetTickCount;
  TotalTime := (EndTime - StartTime) / 1000.0;

  if TotalTime > 0 then
    Frequency := LoopCount / TotalTime
  else
    Frequency := 0;

  addLog('最终内存使用: ' + FormatFloat('0.00', MemUsage/1024/1024) + ' MB');
  addLog('ExecuteLoop 完成统计:');
  addLog('  总循环次数: ' + IntToStr(LoopCount));
  addLog('  总耗时: ' + FormatFloat('0.00', TotalTime) + ' 秒');
  addLog('  频率: ' + FormatFloat('0.0', Frequency) + ' 次/秒');
  addLog('ExecuteLoop end.');
end;

{procedure TForm2.ExecuteLoop(ACallback: TProc<Word>);
var
  n, nDelay: word;
  StartTime, EndTime: Cardinal;
  ElapsedTime, LoopsPerSecond: Double;
  LoopCount: Integer;
begin
  addLog('ExecuteLoop begin...');
  self.chkBreak.Checked := false;
  n := 0;
  LoopCount := 0;
  nDelay := StrToIntDef(self.edDelay.Text, 20);
  var nMaxLines := StrToIntDef(self.edtNums.Text, 2000);

  // 记录开始时间（毫秒精度）
  StartTime := GetTickCount;

  while true do begin
    if n = Word.MaxValue then begin
      n := 0;
    end else begin
      Inc(n);
    end;

    Inc(LoopCount);

    if Assigned(ACallback) then
    begin
      ACallback(n);
    end;

    delay(nDelay);

    if self.isBreak() or not self.FConnected or (n>nMaxLines) then begin
      break;
    end;
  end;

  // 计算总耗时
  EndTime := GetTickCount;
  ElapsedTime := (EndTime - StartTime) / 1000.0;  // 转换为秒

  // 计算每秒执行次数
  if ElapsedTime > 0 then
    LoopsPerSecond := LoopCount / ElapsedTime
  else
    LoopsPerSecond := 0;

  // 打印结果
  addLog('ExecuteLoop 完成:');
  addLog('  总数: ' + IntToStr(LoopCount) + ' 次');
  addLog('  耗时: ' + FormatFloat('0.00', ElapsedTime) + ' 秒');
  addLog('  频率: ' + FormatFloat('0.00', LoopsPerSecond) + ' 次/秒');
  addLog('ExecuteLoop end.');
end;}

procedure TForm2.FormCreate(Sender: TObject);
begin
  Inherited;
  FMaxLogLines := 2000;
  FAutoScroll := true;
  self.readWriteIni(false);
  SetButtons;
  PipeClientInitialize;
  RegisterOnPipeClientDisconnectCallback(OnDisconnect);
  RegisterOnPipeClientErrorCallback(OnError);
  RegisterOnPipeClientMessageCallback(OnMessage);
  RegisterOnPipeClientSentCallback(OnSent);
  if self.cbAuto.Checked then begin
    Button3Click(Button3);
  end;
end;

procedure TForm2.FormDestroy(Sender: TObject);
begin
  self.readWriteIni(true);
  PipeClientDestroy;
end;

function TForm2.isBreak: boolean;
begin
  Result := Application.Terminated;
end;

procedure TForm2.OnDisconnect(aPipe: Cardinal); stdcall;
begin
  AddLog('>> Pipe (' + IntToStr(aPipe) + ') disconnected.');
  FConnected := False;
  SetButtons;
end;

procedure TForm2.OnError(aPipe: Cardinal; aPipeContext: ShortInt; aErrorCode: Integer); stdcall;
begin
  AddLog('>> Pipe (' + IntToStr(aPipe) +
                  ') generated error (' + IntToStr(aErrorCode) +
                  ') in the ' + PipeContextToString(aPipeContext) +
                  ' context.');
end;

procedure TForm2.OnMessage(aPipe: Cardinal; aMsg: PWideChar); stdcall;
begin
//  AddLog('>> Pipe (' + IntToStr(aPipe) +
//                  ') sent a message: ' + StrPas(aMsg));
  AddLog('>> Pipe (' + IntToStr(aPipe) +
                  ') on message: ' + StrPas(aMsg));
end;

procedure TForm2.OnSent(aPipe: Cardinal; aSize: Cardinal); stdcall;
begin
//  AddLog('>> Pipe (' + IntToStr(aPipe) +
//                  ') on sent message (' + IntToStr(aSize) + ').');
end;

function TForm2.readWriteIni(const bWrite: boolean): boolean;
begin
  if not bWrite then begin
    TFormIniFiles.LoadAllContainers(self);
    Result := true;
  end else begin
    TFormIniFiles.SaveAllContainers(self);
    Result := true;
  end;
end;

class procedure TForm2.delay(const MaxWaitTime: DWORD; cbBreak: TFunc<boolean>);
var
  StartTime: UInt64;
  WaitTime: DWORD;
  Elapsed: DWORD;
begin
  if MaxWaitTime = 0 then
    Exit;

  StartTime := GetTickCount64;

  while true do begin
    if Assigned(cbBreak) and cbBreak() then
      Exit;

    Elapsed := GetTickCount64 - StartTime;
    if Elapsed >= MaxWaitTime then
      Exit;

    // 计算剩余等待时间
    WaitTime := MaxWaitTime - (GetTickCount64 - StartTime);
    if WaitTime > 50 then
      WaitTime := 50;

    // 正确的语法：使用Pointer(nil)^
    if MsgWaitForMultipleObjects(0, Pointer(nil)^, FALSE, WaitTime, QS_ALLINPUT) = WAIT_OBJECT_0 then begin
      // 处理消息
      var Msg: TMsg;
      while PeekMessage(Msg, 0, 0, 0, PM_REMOVE) do begin
        if Msg.Message = $0012 then begin     // WM_QUIT
          break;
        end else begin
          TranslateMessage(Msg);
          DispatchMessage(Msg);
        end;
      end;
    end;
  end;
end;

end.
