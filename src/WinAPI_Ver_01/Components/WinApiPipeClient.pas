unit WinApiPipeClient;

interface

uses
  Windows, Classes, SysUtils;

type
  TWinApiPipeClient = class
  private
    FPipeName: string;
    FPipeHandle: THandle;
  public
    constructor Create(const AServerName, APipeName: string);
    destructor Destroy; override;
    function Connect(Timeout: DWORD = 5000): Boolean;
    procedure Disconnect;
    function Send(const Data: TBytes): Boolean; overload;
    function Send(const Data: string): Boolean; overload;
    function Read(var Buffer; BufferSize: DWORD; var BytesRead: DWORD; Timeout: DWORD = 1000): Boolean;
  end;

implementation

constructor TWinApiPipeClient.Create(const AServerName, APipeName: string);
begin
  inherited Create;
  if AServerName = '' then
    FPipeName := '\\.\pipe\' + APipeName
  else
    FPipeName := '\\' + AServerName + '\pipe\' + APipeName;
  FPipeHandle := INVALID_HANDLE_VALUE;
end;

destructor TWinApiPipeClient.Destroy;
begin
  Disconnect;
  inherited;
end;

function TWinApiPipeClient.Connect(Timeout: DWORD): Boolean;
var
  StartTime: Cardinal;
begin
  if FPipeHandle <> INVALID_HANDLE_VALUE then
  begin
    Result := True;
    Exit;
  end;

  StartTime := GetTickCount;
  while (GetTickCount - StartTime) < Timeout do
  begin
    // 尝试连接
    FPipeHandle := CreateFile(
      PChar(FPipeName),
      GENERIC_READ or GENERIC_WRITE,
      0, // 不共享
      nil,
      OPEN_EXISTING,
      FILE_FLAG_OVERLAPPED,
      0
    );

    if FPipeHandle <> INVALID_HANDLE_VALUE then
    begin
      // 设置管道读模式
      var Mode: DWORD := PIPE_READMODE_MESSAGE;
      if SetNamedPipeHandleState(FPipeHandle, Mode, nil, nil) then
      begin
        Result := True;
        Exit;
      end
      else
      begin
        CloseHandle(FPipeHandle);
        FPipeHandle := INVALID_HANDLE_VALUE;
      end;
    end;

    if GetLastError <> ERROR_PIPE_BUSY then
      Break;

    // 管道忙，等待后重试
    if not WaitNamedPipe(PChar(FPipeName), 200) then
      Break;
  end;

  Result := False;
end;

procedure TWinApiPipeClient.Disconnect;
begin
  if FPipeHandle <> INVALID_HANDLE_VALUE then
  begin
    FlushFileBuffers(FPipeHandle);
    CloseHandle(FPipeHandle);
    FPipeHandle := INVALID_HANDLE_VALUE;
  end;
end;

function TWinApiPipeClient.Send(const Data: TBytes): Boolean;
var
  BytesWritten: DWORD;
begin
  Result := False;
  if (FPipeHandle = INVALID_HANDLE_VALUE) or (Length(Data) = 0) then
    Exit;

  if WriteFile(FPipeHandle, Data[0], Length(Data), BytesWritten, nil) then
    Result := BytesWritten = DWORD(Length(Data));
end;

function TWinApiPipeClient.Send(const Data: string): Boolean;
begin
  Result := Send(TEncoding.UTF8.GetBytes(Data));
end;

function TWinApiPipeClient.Read(var Buffer; BufferSize: DWORD; var BytesRead: DWORD; Timeout: DWORD): Boolean;
var
  Overlapped: TOverlapped;
  Event: THandle;
  WaitResult: DWORD;
begin
  Result := False;
  BytesRead := 0;
  if FPipeHandle = INVALID_HANDLE_VALUE then
    Exit;

  Event := CreateEvent(nil, True, False, nil);
  try
    FillChar(Overlapped, SizeOf(Overlapped), 0);
    Overlapped.hEvent := Event;

    if not ReadFile(FPipeHandle, Buffer, BufferSize, BytesRead, @Overlapped) then
    begin
      if GetLastError = ERROR_IO_PENDING then
      begin
        WaitResult := WaitForSingleObject(Event, Timeout);
        if WaitResult = WAIT_OBJECT_0 then
          Result := GetOverlappedResult(FPipeHandle, Overlapped, BytesRead, False);
      end;
    end
    else
    begin
      Result := True;
    end;
  finally
    CloseHandle(Event);
  end;
end;

end.