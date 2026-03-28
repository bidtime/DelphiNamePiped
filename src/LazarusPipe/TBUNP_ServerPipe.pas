unit TBUNP_ServerPipe;

interface

uses
  Classes, Windows, SysUtils, Generics.Collections, SyncObjs,
  TBUNP_CommonTypes, TBUNP_ServerTypes, TBUNP_Utils;

const
  rsCouldNotCreateInterfacePipe = 'Could not create interface pipe, please close all instances of this program and restart';

type
  TPipeServerMode = (pipeModeByte, pipeModeMessage);

  TTBUNP_ServerPipe = class;
  TPipeServerIOHandler = class;

  TPipeServerIOHandler = class(TThread)
  private
    FServer: TTBUNP_ServerPipe;
    FPipeHandleServer: THandle;
    FPipeMode: TPipeServerMode;
  protected
    procedure Execute; override;
  public
    constructor Create(AServer: TTBUNP_ServerPipe; APipeHandle: THandle; APipeMode: TPipeServerMode);
  end;

  TTBUNP_ServerPipe = class(TObject)
  private
    FPipeName: string;
    FPipeMode: TPipeServerMode;
    FActive: Boolean;

    // 回调属性
    FOnPipeServerConnectCallback: TPSConnectCb;
    FOnPipeServerDisconnectCallback: TPSConnectCb;
    FOnPipeServerErrorCallback: TPSErrorCb;
    FOnPipeServerMessageCallback: TPSMessageCb;
    FOnPipeServerSentCallback: TPSSentCb;

    // 线程和连接管理
    FListenThread: TThread;
    FIOHandlers: TObjectList<TThread>;
    FIOHandlersLock: TCriticalSection;

    // 内部方法
    function PipeServerCreateInstance: THandle;
    procedure PipeServerCloseInstance(PipeHandle: THandle);
    procedure PipeServerCreateIOHandler(PipeHandle: THandle);
    procedure PipeServerIOHandlerTerminated(Sender: TObject);
    // 移除了重复的 GetClientCount 声明

  public
    constructor Create;
    destructor Destroy; override;

    function Start: Boolean; overload;
    function Start(aPipeName: PWideChar): Boolean; overload;
    procedure Stop;
    function Broadcast(aMsg: PWideChar): Boolean;
    function Send(aPipe: HPIPE; aMsg: PWideChar): Boolean;
    function Disconnect(aPipe: HPIPE): Boolean;

    // 公共的 GetClientCount 方法
    function GetClientCount: Integer;

    property OnPipeServerConnectCallback: TPSConnectCb
      read FOnPipeServerConnectCallback write FOnPipeServerConnectCallback;
    property OnPipeServerDisconnectCallback: TPSConnectCb
      read FOnPipeServerDisconnectCallback write FOnPipeServerDisconnectCallback;
    property OnPipeServerErrorCallback: TPSErrorCb
      read FOnPipeServerErrorCallback write FOnPipeServerErrorCallback;
    property OnPipeServerMessageCallback: TPSMessageCb
      read FOnPipeServerMessageCallback write FOnPipeServerMessageCallback;
    property OnPipeServerSentCallback: TPSSentCb
      read FOnPipeServerSentCallback write FOnPipeServerSentCallback;
  end;

implementation

{ TPipeServerIOHandler }

constructor TPipeServerIOHandler.Create(AServer: TTBUNP_ServerPipe;
  APipeHandle: THandle; APipeMode: TPipeServerMode);
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FServer := AServer;
  FPipeHandleServer := APipeHandle;
  FPipeMode := APipeMode;
end;

procedure TPipeServerIOHandler.Execute;
var
  LastError: DWORD;
  TotalBytesAvail, BytesLeftThisMessage: DWORD;
  BytesToRead, ResultBytes: DWORD;
  Buffer: array of AnsiChar;
  Msg: WideString;
  AnsiMsg: AnsiString;
begin
  LastError := 0;

  while (not Terminated) and (LastError <> ERROR_BROKEN_PIPE) do
  begin
    if FPipeHandleServer = INVALID_HANDLE_VALUE then
      Break;

    // 检查管道中是否有数据可用
    if PeekNamedPipe(FPipeHandleServer, nil, 0, nil,
      @TotalBytesAvail, @BytesLeftThisMessage) then
    begin
      // 确定要读取的字节数
      if (BytesLeftThisMessage > 0) then
        BytesToRead := BytesLeftThisMessage
      else
        BytesToRead := TotalBytesAvail;

      if (BytesToRead > 0) then
      begin
        // 分配缓冲区
        SetLength(Buffer, BytesToRead);

        // 读取数据
        if not ReadFile(FPipeHandleServer, Buffer[0], BytesToRead, ResultBytes, nil) then
        begin
          // 读取错误
          Break;
        end;

        if ResultBytes > 0 then
        begin
          // 转换为字符串
          SetLength(AnsiMsg, ResultBytes);
          Move(Buffer[0], AnsiMsg[1], ResultBytes);
          Msg := WideString(AnsiMsg);

          // 在主线程中触发消息事件
          TThread.Queue(nil,
            procedure
            begin
              if Assigned(FServer.FOnPipeServerMessageCallback) then
                FServer.FOnPipeServerMessageCallback(Cardinal(FPipeHandleServer), PWideChar(Msg));
            end
          );
        end;
      end;
    end
    else
    begin
      // 检查是否管道已断开
      LastError := GetLastError;
      if (LastError = ERROR_BROKEN_PIPE) or (LastError = ERROR_PIPE_NOT_CONNECTED) then
      begin
        // 管道断开
        TThread.Queue(nil,
          procedure
          begin
            if Assigned(FServer.FOnPipeServerDisconnectCallback) then
              FServer.FOnPipeServerDisconnectCallback(Cardinal(FPipeHandleServer));
          end
        );
        Break;
      end;
    end;

    // 防止CPU占用过高
    Sleep(10);
  end;
end;

{ TTBUNP_ServerPipe }

constructor TTBUNP_ServerPipe.Create;
begin
  inherited Create;
  FActive := False;
  FPipeName := 'TBU_Pipe';
  FPipeMode := pipeModeByte;
  FIOHandlersLock := TCriticalSection.Create;
  FIOHandlers := TObjectList<TThread>.Create(False);
end;

destructor TTBUNP_ServerPipe.Destroy;
begin
  Stop;
  FIOHandlers.Free;
  FIOHandlersLock.Free;
  inherited;
end;

function TTBUNP_ServerPipe.Start: Boolean;
begin
  if FActive then
  begin
    Result := True;
    Exit;
  end;

  if FPipeName = '' then
    FPipeName := 'TBU_Pipe';

  Result := False;
  try
    FActive := True;

    // 启动监听线程
    FListenThread := TThread.CreateAnonymousThread(
      procedure
      var
        CurrentPendingPipeHandle: THandle;
        LastError: DWORD;
        i: Integer;
      begin
        CurrentPendingPipeHandle := INVALID_HANDLE_VALUE;

        while not TThread.CurrentThread.CheckTerminated do
        begin
          // 创建新的管道实例
          CurrentPendingPipeHandle := PipeServerCreateInstance;
          LastError := GetLastError;

          if CurrentPendingPipeHandle <> INVALID_HANDLE_VALUE then
          begin
            // 等待客户端连接
            while not TThread.CurrentThread.CheckTerminated do
            begin
              if ConnectNamedPipe(CurrentPendingPipeHandle, nil) then
              begin
                // 连接成功
              end;

              LastError := GetLastError;

              case LastError of
                ERROR_PIPE_LISTENING:
                  begin
                    // 仍在等待客户端连接
                  end;

                ERROR_PIPE_CONNECTED:
                  begin
                    // 客户端已连接
                    // 在主线程中创建IO处理器
                    TThread.Queue(nil,
                      procedure
                      begin
                        PipeServerCreateIOHandler(CurrentPendingPipeHandle);
                      end
                    );

                    // 重置当前管道句柄，以便创建新的实例
                    CurrentPendingPipeHandle := INVALID_HANDLE_VALUE;

                    // 触发连接事件
                    TThread.Queue(nil,
                      procedure
                      begin
                        if Assigned(FOnPipeServerConnectCallback) then
                          FOnPipeServerConnectCallback(Cardinal(CurrentPendingPipeHandle));
                      end
                    );

                    Break;
                  end;
              end;

              // 短暂休眠，防止CPU占用过高
              Sleep(1);
            end;
          end;

          // 短暂休眠
          Sleep(1);
        end;

        // 关闭当前待处理的管道实例
        if CurrentPendingPipeHandle <> INVALID_HANDLE_VALUE then
          PipeServerCloseInstance(CurrentPendingPipeHandle);
      end
    );

    FListenThread.FreeOnTerminate := True;
    FListenThread.Start;

    Result := True;

  except
    on E: Exception do
    begin
      Result := False;
      FActive := False;
      if Assigned(FOnPipeServerErrorCallback) then
        FOnPipeServerErrorCallback(0, 0, GetLastError);
    end;
  end;
end;

function TTBUNP_ServerPipe.Start(aPipeName: PWideChar): Boolean;
begin
  if aPipeName <> nil then
    FPipeName := StrPas(aPipeName)
  else
    FPipeName := 'TBU_Pipe';

  Result := Start;
end;

procedure TTBUNP_ServerPipe.Stop;
var
  i: Integer;
begin
  if not FActive then
    Exit;

  FActive := False;

  // 停止监听线程
  if FListenThread <> nil then
  begin
    FListenThread.Terminate;
    FListenThread.WaitFor;
    FListenThread := nil;
  end;

  // 停止所有IO处理器
  FIOHandlersLock.Enter;
  try
    for i := 0 to FIOHandlers.Count - 1 do
    begin
      FIOHandlers[i].Terminate;
    end;
  finally
    FIOHandlersLock.Leave;
  end;

  // 等待所有IO处理器停止
  while GetClientCount > 0 do
  begin
    Sleep(100);
  end;
end;

function TTBUNP_ServerPipe.PipeServerCreateInstance: THandle;
var
  PipeType: Cardinal;
begin
  // 根据管道模式设置类型
  PipeType := 0;
  case FPipeMode of
    pipeModeByte:
      begin
        PipeType := PIPE_TYPE_BYTE or PIPE_READMODE_BYTE;
      end;
    pipeModeMessage:
      begin
        PipeType := PIPE_TYPE_MESSAGE or PIPE_READMODE_MESSAGE;
      end;
  end;

  // 创建命名管道实例（非阻塞模式）
  Result := CreateNamedPipe(
    PChar('\\.\pipe\' + FPipeName),
    PIPE_ACCESS_DUPLEX or FILE_FLAG_WRITE_THROUGH,
    PipeType or PIPE_NOWAIT,  // 非阻塞模式
    PIPE_UNLIMITED_INSTANCES,  // 无限实例
    MAXDWORD,  // 输出缓冲区大小（系统管理）
    MAXDWORD,  // 输入缓冲区大小（系统管理）
    10000,     // 默认超时（10秒）
    nil        // 安全属性
  );

  if Result = INVALID_HANDLE_VALUE then
    raise Exception.Create(rsCouldNotCreateInterfacePipe);
end;

procedure TTBUNP_ServerPipe.PipeServerCloseInstance(PipeHandle: THandle);
begin
  if PipeHandle <> INVALID_HANDLE_VALUE then
  begin
    DisconnectNamedPipe(PipeHandle);
    CloseHandle(PipeHandle);
  end;
end;

procedure TTBUNP_ServerPipe.PipeServerCreateIOHandler(PipeHandle: THandle);
var
  NewIOHandler: TPipeServerIOHandler;
begin
  if PipeHandle <> INVALID_HANDLE_VALUE then
  begin
    NewIOHandler := TPipeServerIOHandler.Create(Self, PipeHandle, FPipeMode);
    NewIOHandler.OnTerminate := PipeServerIOHandlerTerminated;
    NewIOHandler.Start;

    FIOHandlersLock.Enter;
    try
      FIOHandlers.Add(NewIOHandler);
    finally
      FIOHandlersLock.Leave;
    end;

    // 触发连接事件
    if Assigned(FOnPipeServerConnectCallback) then
      FOnPipeServerConnectCallback(Cardinal(PipeHandle));
  end;
end;

procedure TTBUNP_ServerPipe.PipeServerIOHandlerTerminated(Sender: TObject);
var
  i: Integer;
  IOHandler: TPipeServerIOHandler;
begin
  if not (Sender is TPipeServerIOHandler) then
    Exit;

  IOHandler := TPipeServerIOHandler(Sender);

  // 从列表中移除
  FIOHandlersLock.Enter;
  try
    i := FIOHandlers.IndexOf(IOHandler);
    if i > -1 then
    begin
      FIOHandlers.Delete(i);
    end;
  finally
    FIOHandlersLock.Leave;
  end;

  // 关闭管道实例
  PipeServerCloseInstance(IOHandler.FPipeHandleServer);

  // 触发断开连接事件
  if Assigned(FOnPipeServerDisconnectCallback) then
    FOnPipeServerDisconnectCallback(Cardinal(IOHandler.FPipeHandleServer));
end;

function TTBUNP_ServerPipe.GetClientCount: Integer;
begin
  FIOHandlersLock.Enter;
  try
    Result := FIOHandlers.Count;
  finally
    FIOHandlersLock.Leave;
  end;
end;

function TTBUNP_ServerPipe.Broadcast(aMsg: PWideChar): Boolean;
var
  Msg: WideString;
  AnsiMsg: AnsiString;
  BytesWritten: DWORD;
  i: Integer;
  Success: Boolean;
  IOHandler: TPipeServerIOHandler;
begin
  Result := False;
  if not FActive or (aMsg = nil) then
    Exit;

  Msg := StrPas(aMsg);
  if Length(Msg) = 0 then
    Exit;

  AnsiMsg := AnsiString(Msg);
  if Length(AnsiMsg) = 0 then
    Exit;

  FIOHandlersLock.Enter;
  try
    for i := 0 to FIOHandlers.Count - 1 do
    begin
      if FIOHandlers[i] is TPipeServerIOHandler then
      begin
        IOHandler := TPipeServerIOHandler(FIOHandlers[i]);
        Success := WriteFile(IOHandler.FPipeHandleServer,
          AnsiMsg[1], Length(AnsiMsg), BytesWritten, nil);

        if Success and (BytesWritten = DWORD(Length(AnsiMsg))) then
        begin
          if Assigned(FOnPipeServerSentCallback) then
            FOnPipeServerSentCallback(IOHandler.FPipeHandleServer, BytesWritten);
        end
        else
        begin
          if Assigned(FOnPipeServerErrorCallback) then
            FOnPipeServerErrorCallback(IOHandler.FPipeHandleServer, 0, GetLastError);
        end;
      end;
    end;

    Result := True;
  finally
    FIOHandlersLock.Leave;
  end;
end;

function TTBUNP_ServerPipe.Send(aPipe: HPIPE; aMsg: PWideChar): Boolean;
var
  Msg: WideString;
  AnsiMsg: AnsiString;
  BytesWritten: DWORD;
  i: Integer;
  Success: Boolean;
  IOHandler: TPipeServerIOHandler;
begin
  Result := False;
  if not FActive or (aMsg = nil) then
    Exit;

  Msg := StrPas(aMsg);
  if Length(Msg) = 0 then
    Exit;

  AnsiMsg := AnsiString(Msg);
  if Length(AnsiMsg) = 0 then
    Exit;

  FIOHandlersLock.Enter;
  try
    for i := 0 to FIOHandlers.Count - 1 do
    begin
      if FIOHandlers[i] is TPipeServerIOHandler then
      begin
        IOHandler := TPipeServerIOHandler(FIOHandlers[i]);
        if IOHandler.FPipeHandleServer = aPipe then
        begin
          Success := WriteFile(IOHandler.FPipeHandleServer,
            AnsiMsg[1], Length(AnsiMsg), BytesWritten, nil);

          Result := Success and (BytesWritten = DWORD(Length(AnsiMsg)));

          if Result then
          begin
            if Assigned(FOnPipeServerSentCallback) then
              FOnPipeServerSentCallback(aPipe, BytesWritten);
          end
          else
          begin
            if Assigned(FOnPipeServerErrorCallback) then
              FOnPipeServerErrorCallback(aPipe, 0, GetLastError);
          end;

          Break;
        end;
      end;
    end;
  finally
    FIOHandlersLock.Leave;
  end;
end;

function TTBUNP_ServerPipe.Disconnect(aPipe: HPIPE): Boolean;
var
  i: Integer;
  IOHandler: TPipeServerIOHandler;
begin
  Result := False;
  if not FActive then
    Exit;

  FIOHandlersLock.Enter;
  try
    for i := 0 to FIOHandlers.Count - 1 do
    begin
      if FIOHandlers[i] is TPipeServerIOHandler then
      begin
        IOHandler := TPipeServerIOHandler(FIOHandlers[i]);
        if IOHandler.FPipeHandleServer = aPipe then
        begin
          IOHandler.Terminate;
          Result := True;
          Break;
        end;
      end;
    end;
  finally
    FIOHandlersLock.Leave;
  end;
end;

end.
