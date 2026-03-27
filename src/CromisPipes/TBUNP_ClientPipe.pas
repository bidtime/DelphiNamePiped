unit TBUNP_ClientPipe;

interface

uses
  Classes, SysUtils, ExtCtrls, Windows,
  TBUNP_CommonTypes,
  TBUNP_ClientTypes,
  Cromis.Comm.Custom,  // 必要的依赖
  Cromis.Comm.IPC,     // Cromis IPC
  TBUNP_Utils;

type
  TTBUNP_ClientPipe = class(TObject)
  private
    FIPCClient: TIPCClient;
    FOwnState: TOwnState;
    FCleanupTimer: TTimer;
    FServerName: string;
    FPipeName: string;

    // 回调属性
    FOnPipeClientDisconnectCallback: TPCDisconnectCb;
    FOnPipeClientErrorCallback: TPCErrorCb;
    FOnPipeClientMessageCallback: TPCMessageCb;
    FOnPipeClientSentCallback: TPCSentCb;

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

{ TTBUNP_ClientPipe }

constructor TTBUNP_ClientPipe.Create;
begin
  inherited Create;
  FOwnState := ownsDisconnected;
  FIPCClient := nil;
  FServerName := '.';
  FPipeName := '';

  FCleanupTimer := TTimer.Create(nil);
  FCleanupTimer.Enabled := False;
  FCleanupTimer.Interval := 100;
  FCleanupTimer.OnTimer := FCleanupTimerTick;
end;

destructor TTBUNP_ClientPipe.Destroy;
begin
  Disconnect;
  FreeAndNil(FCleanupTimer);
  inherited;
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
  ServerName, PipeName: string;
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

  try
    FIPCClient := TIPCClient.Create;

    // 设置服务器名称
    FIPCClient.ServerName := PipeName;

    // 设置计算机名
    FIPCClient.ComputerName := ServerName;

    // 连接管道
    FIPCClient.ConnectClient(5000);  // 5秒超时

    if FIPCClient.IsConnected then
    begin
      FOwnState := ownsConnected;
      Result := True;
    end
    else
    begin
      FreeAndNil(FIPCClient);
      if Assigned(FOnPipeClientErrorCallback) then
        FOnPipeClientErrorCallback(0, 0, FIPCClient.LastError);
    end;

  except
    on E: Exception do
    begin
      Result := False;
      FreeAndNil(FIPCClient);
      if Assigned(FOnPipeClientErrorCallback) then
        FOnPipeClientErrorCallback(0, 0, GetLastError);
    end;
  end;
end;

function TTBUNP_ClientPipe.Send(aMsg: PWideChar): Boolean;
var
  Msg: WideString;
  AnsiMsg: AnsiString;
  Request, Response: IIPCData;
  EchoStr: AnsiString;
  HasEcho: Boolean;
begin
  Result := False;

  if (FOwnState = ownsDisconnected) or (FIPCClient = nil) or (aMsg = nil) then
    Exit;

  Msg := StrPas(aMsg);
  if Length(Msg) = 0 then
    Exit;

  AnsiMsg := AnsiString(Msg);

  try
    // 创建请求
    Request := AcquireIPCData;
    Request.ID := IntToStr(GetTickCount);
    Request.Data.WriteUTF8String('Command', 'SendMessage');
    Request.Data.WriteUTF8String('Message', AnsiMsg);

    // 发送请求
    Response := FIPCClient.ExecuteConnectedRequest(Request);

    if FIPCClient.AnswerValid then
    begin
      // 触发发送完成事件
      if Assigned(FOnPipeClientSentCallback) then
        FOnPipeClientSentCallback(0, Length(AnsiMsg));

      // 检查是否有响应数据
      EchoStr := '';

      if (Response <> nil) and (Response.Data.Storage.Size > 0) then
      begin
        // 尝试读取回显消息
        // 注意：我们需要检查是否存在 'Echo' 字段
        // 由于 ValueExists 可能不存在，我们使用 try-except
        try
          // 尝试读取 Echo 字段
          EchoStr := Response.Data.ReadUTF8String('Echo');
          HasEcho := True;
        except
          // Echo 字段不存在，不处理
          HasEcho := False;
        end;

        if HasEcho then
        begin
          Msg := WideString(EchoStr);

          // 触发消息事件
          if Assigned(FOnPipeClientMessageCallback) then
            TThread.Queue(nil, procedure
              begin
                FOnPipeClientMessageCallback(0, PWideChar(Msg));
              end
            );
        end;
      end;

      Result := True;
    end
    else
    begin
      if Assigned(FOnPipeClientErrorCallback) then
        FOnPipeClientErrorCallback(0, 0, FIPCClient.LastError);
    end;

  except
    on E: Exception do
    begin
      Result := False;
      if Assigned(FOnPipeClientErrorCallback) then
        FOnPipeClientErrorCallback(0, 0, GetLastError);
    end;
  end;
end;

function TTBUNP_ClientPipe.GetPipeId: HPIPE;
begin
  // TIPCClient 不公开管道句柄
  Result := 0;
end;

procedure TTBUNP_ClientPipe.Disconnect;
begin
  if FOwnState = ownsDisconnected then
    Exit;

  FOwnState := ownsDisconnected;

  if FIPCClient <> nil then
  begin
    try
      FIPCClient.DisconnectClient;
    finally
      FreeAndNil(FIPCClient);
    end;
  end;

  if Assigned(FOnPipeClientDisconnectCallback) then
    FOnPipeClientDisconnectCallback(0);
end;

procedure TTBUNP_ClientPipe.FCleanupTimerTick(aSender: TObject);
begin
  Disconnect;
  FCleanupTimer.Enabled := False;
end;

end.
