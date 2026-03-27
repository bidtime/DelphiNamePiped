unit WinApiPipeServer;

interface

uses
  Windows, Classes, SysUtils, SyncObjs;

type
  TOnPipeMessage = procedure(const Data: TBytes) of object;

  TWinApiPipeServer = class(TThread)
  private
    FPipeName: string;
    FPipeHandle: THandle;
    FOverlapped: TOverlapped;
    FEvent: TEvent;
    FOnMessage: TOnPipeMessage;
    FBuffer: array[0..4095] of Byte;
    procedure HandleMessage(BytesRead: DWORD);
  protected
    procedure Execute; override;
  public
    constructor Create(const APipeName: string);
    destructor Destroy; override;
    procedure StopServer;
    property OnMessage: TOnPipeMessage read FOnMessage write FOnMessage;
  end;

implementation

constructor TWinApiPipeServer.Create(const APipeName: string);
begin
  inherited Create(False);
  FPipeName := '\\.\pipe\' + APipeName;
  FEvent := TEvent.Create(nil, True, False, '');
  FreeOnTerminate := False;
end;

destructor TWinApiPipeServer.Destroy;
begin
  StopServer;
  FEvent.Free;
  inherited;
end;

procedure TWinApiPipeServer.Execute;
var
  BytesRead: DWORD;
  Success: Boolean;
  Connected: BOOL;
  WaitResult: DWORD;
begin
  while not Terminated do
  begin
    // 1. 创建命名管道实例
    FPipeHandle := CreateNamedPipe(
      PChar(FPipeName),
      PIPE_ACCESS_DUPLEX or FILE_FLAG_OVERLAPPED,
      PIPE_TYPE_MESSAGE or PIPE_READMODE_MESSAGE or PIPE_WAIT,
      PIPE_UNLIMITED_INSTANCES,
      4096, // 输出缓冲区大小
      4096, // 输入缓冲区大小
      NMPWAIT_USE_DEFAULT_WAIT,
      nil   // 默认安全属性
    );

    if FPipeHandle = INVALID_HANDLE_VALUE then
    begin
      Sleep(100); // 创建失败，稍后重试
      Continue;
    end;

    // 2. 初始化重叠结构，关联事件
    FillChar(FOverlapped, SizeOf(FOverlapped), 0);
    FOverlapped.hEvent := FEvent.Handle;

    // 3. 等待客户端连接（异步）
    ConnectNamedPipe(FPipeHandle, @FOverlapped);
    if GetLastError = ERROR_IO_PENDING then
    begin
      // 等待连接完成或线程终止信号
      WaitResult := WaitForSingleObject(FEvent.Handle, 100);
      if WaitResult = WAIT_OBJECT_0 then
      begin
        // 连接成功，开始读取数据
        while not Terminated do
        begin
          FillChar(FOverlapped, SizeOf(FOverlapped), 0);
          FOverlapped.hEvent := FEvent.Handle;

          // 异步读取
          Success := ReadFile(FPipeHandle, FBuffer, SizeOf(FBuffer), BytesRead, @FOverlapped);
          if not Success and (GetLastError = ERROR_IO_PENDING) then
          begin
            WaitResult := WaitForSingleObject(FEvent.Handle, 100);
            if WaitResult = WAIT_OBJECT_0 then
            begin
              if GetOverlappedResult(FPipeHandle, FOverlapped, BytesRead, False) then
              begin
                if BytesRead > 0 then
                  HandleMessage(BytesRead);
              end
              else
                Break; // 读取错误，断开连接
            end;
          end
          else if Success and (BytesRead > 0) then
          begin
            HandleMessage(BytesRead);
          end;
        end;
      end;
    end;

    // 4. 清理当前连接
    DisconnectNamedPipe(FPipeHandle);
    CloseHandle(FPipeHandle);
    FPipeHandle := INVALID_HANDLE_VALUE;
    FEvent.ResetEvent;
  end;
end;

procedure TWinApiPipeServer.HandleMessage(BytesRead: DWORD);
var
  Data: TBytes;
begin
  if (BytesRead > 0) and Assigned(FOnMessage) then
  begin
    SetLength(Data, BytesRead);
    Move(FBuffer, Data[0], BytesRead);
    FOnMessage(Data);
  end;
end;

procedure TWinApiPipeServer.StopServer;
begin
  Terminate;
  if FEvent <> nil then
    FEvent.SetEvent; // 唤醒等待
  WaitFor; // 等待线程结束
  if FPipeHandle <> INVALID_HANDLE_VALUE then
  begin
    CancelIo(FPipeHandle);
    DisconnectNamedPipe(FPipeHandle);
    CloseHandle(FPipeHandle);
  end;
end;

end.
