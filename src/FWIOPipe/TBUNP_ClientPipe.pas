unit TBUNP_ClientPipe;

interface

uses
  Classes, SysUtils, ExtCtrls,
  TBUNP_CommonTypes,
  TBUNP_ClientTypes,
  uNamedPipesExchange,
  TBUNP_Utils;

type
  TTBUNP_ClientPipe = class(TObject)
  private
    // 内部字段必须在属性声明之前
    FPipeClient: TPipeClient;
    FOwnState: TOwnState;
    FCleanupTimer: TTimer;
    FServerName: string;
    FPipeName: string;

    // 私有回调字段
    FOnPipeClientDisconnectCallback: TPCDisconnectCb;
    FOnPipeClientErrorCallback: TPCErrorCb;
    FOnPipeClientMessageCallback: TPCMessageCb;
    FOnPipeClientSentCallback: TPCSentCb;

    // 私有方法
    procedure HandleConnected(Sender: TObject);
    procedure HandleDisconnected(Sender: TObject);
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

    // 公共属性声明 - 必须在字段声明之后
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
  FPipeClient := nil;
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
    // 创建封装后的管道客户端
    FPipeClient := TPipeClient.Create(ServerName, PipeName);

    // 设置事件处理程序
    FPipeClient.OnConnected := HandleConnected;
    FPipeClient.OnDisconnected := HandleDisconnected;

    // 连接管道
    FPipeClient.Active := True;

    FOwnState := ownsConnected;
    Result := True;

  except
    on E: Exception do
    begin
      Result := False;
      FreeAndNil(FPipeClient);
      if Assigned(FOnPipeClientErrorCallback) then
        FOnPipeClientErrorCallback(0, 0, GetLastError);
    end;
  end;
end;

procedure TTBUNP_ClientPipe.HandleConnected(Sender: TObject);
begin
  // 连接成功
  if Assigned(FOnPipeClientDisconnectCallback) then
    FOnPipeClientDisconnectCallback(0);
end;

procedure TTBUNP_ClientPipe.HandleDisconnected(Sender: TObject);
begin
  FOwnState := ownsDisconnected;
  FCleanupTimer.Enabled := True;

  if Assigned(FOnPipeClientDisconnectCallback) then
    FOnPipeClientDisconnectCallback(0);
end;

function TTBUNP_ClientPipe.Send(aMsg: PWideChar): Boolean;
var
  Msg: WideString;
  AnsiMsg: AnsiString;
  SendStream, ReceiveStream: TMemoryStream;
begin
  Result := False;

  if (FOwnState = ownsDisconnected) or (FPipeClient = nil) or (aMsg = nil) then
    Exit;

  Msg := StrPas(aMsg);
  if Length(Msg) = 0 then
    Exit;

  AnsiMsg := AnsiString(Msg);
  if Length(AnsiMsg) = 0 then
    Exit;

  try
    // 准备发送流
    SendStream := TMemoryStream.Create;
    try
      SendStream.Write(AnsiMsg[1], Length(AnsiMsg));
      SendStream.Position := 0;

      // 准备接收流
      ReceiveStream := TMemoryStream.Create;
      try
        // 发送数据并接收响应
        FPipeClient.SendData(SendStream, ReceiveStream);

        // 如果有响应数据，可以处理
        if ReceiveStream.Size > 0 then
        begin
          // 这里可以触发消息事件
          if Assigned(FOnPipeClientMessageCallback) then
          begin
            ReceiveStream.Position := 0;
            SetLength(AnsiMsg, ReceiveStream.Size);
            ReceiveStream.Read(AnsiMsg[1], ReceiveStream.Size);
            Msg := WideString(AnsiMsg);
            FOnPipeClientMessageCallback(0, PWideChar(Msg));
          end;
        end;

        // 触发发送完成事件
        if Assigned(FOnPipeClientSentCallback) then
          FOnPipeClientSentCallback(0, SendStream.Size);

        Result := True;

      finally
        ReceiveStream.Free;
      end;
    finally
      SendStream.Free;
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
  // TPipeClient 没有公开管道句柄
  Result := 0;
end;

procedure TTBUNP_ClientPipe.Disconnect;
begin
  if FOwnState = ownsDisconnected then
    Exit;

  FOwnState := ownsDisconnected;

  if FPipeClient <> nil then
  begin
    try
      FPipeClient.Active := False;
    finally
      FreeAndNil(FPipeClient);
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
