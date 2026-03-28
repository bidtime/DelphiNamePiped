unit TBUNP_ClientPipe;

interface

uses
  Classes, Windows, SysUtils, ExtCtrls, SyncObjs,
  TBUNP_CommonTypes, TBUNP_ClientTypes, TBUNP_Utils;

const
  rsCouldNotConnectInterfacePipe =
    'Could not connect to interface pipe, please check if the server application is started';

type
  TTBUNP_ClientPipe = class;

  TPipeClientHelper = class(TObject)
  public
    class function PipeClientCreateInstance(sPipeName: string): THandle;
    class procedure PipeClientCloseInstance(hPipeHandle: THandle);
    class procedure PipeClientSendAnsiString(hPipeHandle: THandle; const Data: AnsiString);
    class function PipeClientCheckReceiveAnsiString(hPipeHandle: THandle): AnsiString;
  end;

  TPipeClientReadThread = class(TThread)
  private
    FClient: TTBUNP_ClientPipe;
    FPipeHandle: THandle;
  protected
    procedure Execute; override;
  public
    constructor Create(AClient: TTBUNP_ClientPipe; APipeHandle: THandle);
  end;

  TTBUNP_ClientPipe = class(TObject)
  private
    FPipeHandle: THandle;
    FOwnState: TOwnState;
    FCleanupTimer: TTimer;
    FServerName: string;
    FPipeName: string;
    FReadThread: TPipeClientReadThread;

    // 回调属性
    FOnPipeClientDisconnectCallback: TPCDisconnectCb;
    FOnPipeClientErrorCallback: TPCErrorCb;
    FOnPipeClientMessageCallback: TPCMessageCb;
    FOnPipeClientSentCallback: TPCSentCb;

    // 内部方法
    procedure StartReadThread;
    procedure StopReadThread;
    procedure HandlePipeMessage(const Msg: AnsiString);
    procedure HandleError(ErrorCode: DWORD);
    procedure FCleanupTimerTick(aSender: TObject);

  public
    constructor Create;
    destructor Destroy; override;

    function Connect: Boolean; overload;
    function Connect(aPipeName: PWideChar): Boolean; overload;
    function ConnectRemote(aServername: PWideChar): Boolean; overload;
    function ConnectRemote(aServername, aPipeName: PWideChar): Boolean; overload;
    procedure Disconnect;
    function Send(aMsg: PWideChar): Boolean;
    function GetPipeId: HPIPE;

    property OnPipeClientDisconnectCallback: TPCDisconnectCb
      read FOnPipeClientDisconnectCallback write FOnPipeClientDisconnectCallback;
    property OnPipeClientErrorCallback: TPCErrorCb
      read FOnPipeClientErrorCallback write FOnPipeClientErrorCallback;
    property OnPipeClientMessageCallback: TPCMessageCb
      read FOnPipeClientMessageCallback write FOnPipeClientMessageCallback;
    property OnPipeClientSentCallback: TPCSentCb
      read FOnPipeClientSentCallback write FOnPipeClientSentCallback;
  end;

implementation

{ TPipeClientHelper }

class function TPipeClientHelper.PipeClientCreateInstance(sPipeName: string): THandle;
var
  LERR: Integer;
  I: Integer;
begin
  Result := INVALID_HANDLE_VALUE;
  I := 0;

  // 尝试连接管道，最多重试25次
  while (Result = INVALID_HANDLE_VALUE) and (I < 25) do
  begin
    // 创建文件句柄连接到命名管道
    Result := CreateFile(
      PChar('\\.\pipe\' + sPipeName),
      GENERIC_READ or GENERIC_WRITE,  // 读写权限
      0,                              // 不共享
      nil,                            // 安全属性
      OPEN_EXISTING,                  // 打开现有管道
      0,                              // 无特殊标志
      0                               // 无模板文件
    );

    LERR := GetLastError;
    case LERR of
      ERROR_PIPE_BUSY:
        begin
          Inc(I);
          Sleep(100);  // 管道忙，等待后重试
        end;
      else
        I := MaxInt;  // 其他错误，退出循环
    end;
  end;

  if Result = INVALID_HANDLE_VALUE then
    raise Exception.Create(rsCouldNotConnectInterfacePipe);
end;

class procedure TPipeClientHelper.PipeClientCloseInstance(hPipeHandle: THandle);
begin
  if hPipeHandle <> INVALID_HANDLE_VALUE then
  begin
    CloseHandle(hPipeHandle);
  end;
end;

class procedure TPipeClientHelper.PipeClientSendAnsiString(hPipeHandle: THandle; const Data: AnsiString);
var
  dw: DWORD;
begin
  if (hPipeHandle <> INVALID_HANDLE_VALUE) and (Length(Data) > 0) then
  begin
    // 写入数据到管道
    WriteFile(hPipeHandle, Data[1], Length(Data), dw, nil);
  end;
end;

class function TPipeClientHelper.PipeClientCheckReceiveAnsiString(hPipeHandle: THandle): AnsiString;
var
  lpTotalBytesAvail, lpBytesLeftThisMessage: DWORD;
  bytesToRead, res: DWORD;
  Buffer: array of Byte;
begin
  Result := '';

  // 检查管道中是否有数据
  if PeekNamedPipe(hPipeHandle, nil, 0, nil,
    @lpTotalBytesAvail, @lpBytesLeftThisMessage) then
  begin
    // 确定要读取的字节数
    if (lpBytesLeftThisMessage > 0) then
      bytesToRead := lpBytesLeftThisMessage
    else
      bytesToRead := lpTotalBytesAvail;

    if (bytesToRead > 0) then
    begin
      // 分配缓冲区
      SetLength(Buffer, bytesToRead);

      // 读取数据
      if ReadFile(hPipeHandle, Buffer[0], bytesToRead, res, nil) then
      begin
        if res > 0 then
        begin
          // 将字节数组转换为字符串
          SetLength(Result, res);
          Move(Buffer[0], Result[1], res);
        end;
      end;
    end;
  end;
end;

{ TPipeClientReadThread }

constructor TPipeClientReadThread.Create(AClient: TTBUNP_ClientPipe; APipeHandle: THandle);
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FClient := AClient;
  FPipeHandle := APipeHandle;
end;

procedure TPipeClientReadThread.Execute;
var
  LERR: DWORD;
  Msg: AnsiString;
begin
  LERR := 0;

  while (not Terminated) and
        (LERR <> ERROR_BROKEN_PIPE) and
        (LERR <> ERROR_PIPE_NOT_CONNECTED) do
  begin
    if FPipeHandle = INVALID_HANDLE_VALUE then
      Break;

    // 检查并接收消息
    Msg := TPipeClientHelper.PipeClientCheckReceiveAnsiString(FPipeHandle);

    if Msg <> '' then
    begin
      // 在主线程中处理消息
      TThread.Queue(nil,
        procedure
        begin
          FClient.HandlePipeMessage(Msg);
        end
      );
    end;

    // 短暂休眠，降低CPU使用率
    Sleep(1);

    // 检查错误
    LERR := GetLastError;
  end;

  // 如果管道断开，在中断连接
  if (LERR = ERROR_BROKEN_PIPE) or (LERR = ERROR_PIPE_NOT_CONNECTED) then
  begin
    TThread.Queue(nil,
      procedure
      begin
        FClient.Disconnect;
      end
    );
  end;
end;

{ TTBUNP_ClientPipe }

constructor TTBUNP_ClientPipe.Create;
begin
  inherited Create;
  FOwnState := ownsDisconnected;
  FPipeHandle := INVALID_HANDLE_VALUE;
  FServerName := '.';
  FPipeName := '';
  FReadThread := nil;

  FCleanupTimer := TTimer.Create(nil);
  FCleanupTimer.Enabled := False;
  FCleanupTimer.Interval := 100;
  FCleanupTimer.OnTimer := FCleanupTimerTick;
end;

destructor TTBUNP_ClientPipe.Destroy;
begin
  Disconnect;
  FCleanupTimer.Free;
  inherited;
end;

procedure TTBUNP_ClientPipe.FCleanupTimerTick(aSender: TObject);
begin
  Disconnect;
  FCleanupTimer.Enabled := False;
end;

function TTBUNP_ClientPipe.Connect: Boolean;
begin
  if FOwnState = ownsConnected then
  begin
    Result := True;
    Exit;
  end;

  Result := ConnectRemote('', 'TBU_Pipe');
  if Result then
    FOwnState := ownsConnected;
end;

function TTBUNP_ClientPipe.Connect(aPipeName: PWideChar): Boolean;
begin
  if FOwnState = ownsConnected then
  begin
    Result := True;
    Exit;
  end;

  Result := ConnectRemote('', aPipeName);
  if Result then
    FOwnState := ownsConnected;
end;

function TTBUNP_ClientPipe.ConnectRemote(aServername: PWideChar): Boolean;
begin
  if FOwnState = ownsConnected then
  begin
    Result := True;
    Exit;
  end;

  Result := ConnectRemote(aServername, nil);
  if Result then
    FOwnState := ownsConnected;
end;

function TTBUNP_ClientPipe.ConnectRemote(aServername, aPipeName: PWideChar): Boolean;
var
  ServerName, PipeName, FullPipeName: string;
begin
  Result := False;

  if FOwnState = ownsConnected then
  begin
    Result := True;
    Exit;
  end;

  // 设置服务器名和管道名
  if aServername <> nil then
    ServerName := StrPas(aServername)
  else
    ServerName := '.';

  if aPipeName <> nil then
    PipeName := StrPas(aPipeName)
  else
    PipeName := 'TBU_Pipe';

  FServerName := ServerName;
  FPipeName := PipeName;

  // 构建完整的管道名
  if ServerName = '.' then
    FullPipeName := '\\.\pipe\' + PipeName
  else
    FullPipeName := '\\' + ServerName + '\pipe\' + PipeName;

  try
    // 连接到管道
    FPipeHandle := TPipeClientHelper.PipeClientCreateInstance(FullPipeName);

    if FPipeHandle <> INVALID_HANDLE_VALUE then
    begin
      // 启动读取线程
      StartReadThread;

      FOwnState := ownsConnected;
      Result := True;
    end
    else
    begin
      HandleError(GetLastError);
    end;
  except
    on E: Exception do
    begin
      Result := False;
      HandleError(GetLastError);
    end;
  end;
end;

procedure TTBUNP_ClientPipe.StartReadThread;
begin
  if FReadThread <> nil then
    Exit;

  FReadThread := TPipeClientReadThread.Create(Self, FPipeHandle);
  FReadThread.Start;
end;

procedure TTBUNP_ClientPipe.StopReadThread;
begin
  if FReadThread <> nil then
  begin
    FReadThread.Terminate;
    FReadThread.WaitFor;
    FReadThread := nil;
  end;
end;

procedure TTBUNP_ClientPipe.HandlePipeMessage(const Msg: AnsiString);
var
  WideMsg: WideString;
begin
  if Assigned(FOnPipeClientMessageCallback) then
  begin
    WideMsg := WideString(Msg);
    FOnPipeClientMessageCallback(0, PWideChar(WideMsg));
  end;
end;

procedure TTBUNP_ClientPipe.HandleError(ErrorCode: DWORD);
begin
  if Assigned(FOnPipeClientErrorCallback) then
    FOnPipeClientErrorCallback(0, 0, ErrorCode);
end;

function TTBUNP_ClientPipe.Send(aMsg: PWideChar): Boolean;
var
  Msg: WideString;
  AnsiMsg: AnsiString;
begin
  Result := False;

  if (FOwnState = ownsDisconnected) or (FPipeHandle = INVALID_HANDLE_VALUE) or (aMsg = nil) then
    Exit;

  Msg := StrPas(aMsg);
  if Length(Msg) = 0 then
    Exit;

  AnsiMsg := AnsiString(Msg);
  if Length(AnsiMsg) = 0 then
    Exit;

  try
    // 发送消息
    TPipeClientHelper.PipeClientSendAnsiString(FPipeHandle, AnsiMsg);

    Result := True;

    if Assigned(FOnPipeClientSentCallback) then
      FOnPipeClientSentCallback(0, Length(AnsiMsg));
  except
    on E: Exception do
    begin
      Result := False;
      HandleError(GetLastError);
    end;
  end;
end;

function TTBUNP_ClientPipe.GetPipeId: HPIPE;
begin
  Result := FPipeHandle;
end;

procedure TTBUNP_ClientPipe.Disconnect;
begin
  if FOwnState = ownsDisconnected then
    Exit;

  FOwnState := ownsDisconnected;

  // 停止读取线程
  StopReadThread;

  // 关闭管道句柄
  TPipeClientHelper.PipeClientCloseInstance(FPipeHandle);
  FPipeHandle := INVALID_HANDLE_VALUE;

  if Assigned(FOnPipeClientDisconnectCallback) then
    FOnPipeClientDisconnectCallback(0);
end;

end.
