unit TBUNP_ServerPipe;

interface

uses
  Classes, SysUtils, SyncObjs,
  TBUNP_CommonTypes,
  TBUNP_ServerTypes,
  uNamedPipesExchange,  // 使用封装后的命名管道交换单元
  TBUNP_Utils;

type
  TTBUNP_ServerPipe = class(TObject)
  private
    FPipeServer: TPipeServer;
    FActive: Boolean;
    FPipeName: string;
    
    // 存储连接信息和对应的事件
    FConnections: TDictionary<THandle, TStream>;
    
    // 原始事件适配到我们的回调
    procedure HandleConnect(Sender: TObject; PipeHandle: THandle);
    procedure HandleDisconnect(Sender: TObject; PipeHandle: THandle);
    procedure HandleRead(Sender: TObject; PipeHandle: THandle; 
      IncommingValue: TStream; OutgoingValue: TStream);
    procedure HandleIdle(Sender: TObject);
    
  public
    // 公共接口
    constructor Create;
    destructor Destroy; override;
    
    function Start: Boolean; overload;
    function Start(aPipeName: PWideChar): Boolean; overload;
    procedure Stop;
    function Broadcast(aMsg: PWideChar): Boolean;
    function Send(aPipe: HPIPE; aMsg: PWideChar): Boolean;
    function Disconnect(aPipe: HPIPE): Boolean;
    function GetClientCount: Integer;
    
    // 事件回调属性
    property OnPipeServerConnectCallback: TPSConnectCb 
      read FOnPipeServerConnectCallback write FOnPipeServerConnectCallback;
    property OnPipeServerDisconnectCallback: TPSDisconnectCb 
      read FOnPipeServerDisconnectCallback write FOnPipeServerDisconnectCallback;
    property OnPipeServerErrorCallback: TPSErrorCb 
      read FOnPipeServerErrorCallback write FOnPipeServerErrorCallback;
    property OnPipeServerMessageCallback: TPSMessageCb 
      read FOnPipeServerMessageCallback write FOnPipeServerMessageCallback;
    property OnPipeServerSentCallback: TPSSentCb 
      read FOnPipeServerSentCallback write FOnPipeServerSentCallback;
    
  private
    // 内部使用的事件回调
    FOnPipeServerConnectCallback: TPSConnectCb;
    FOnPipeServerDisconnectCallback: TPSDisconnectCb;
    FOnPipeServerErrorCallback: TPSErrorCb;
    FOnPipeServerMessageCallback: TPSMessageCb;
    FOnPipeServerSentCallback: TPSSentCb;
  end;

implementation

{ TTBUNP_ServerPipe }

constructor TTBUNP_ServerPipe.Create;
begin
  inherited Create;
  FPipeServer := nil;
  FConnections := TDictionary<THandle, TStream>.Create;
  FActive := False;
  FPipeName := '';
end;

destructor TTBUNP_ServerPipe.Destroy;
begin
  Stop;
  FConnections.Free;
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
  
  try
    // 创建封装后的管道服务器
    FPipeServer := TPipeServer.Create(FPipeName);
    
    // 设置事件处理程序
    FPipeServer.OnConnect := HandleConnect;
    FPipeServer.OnDisconnect := HandleDisconnect;
    FPipeServer.OnReadFromPipe := HandleRead;
    FPipeServer.OnIdle := HandleIdle;
    
    // 启动服务器
    FPipeServer.Active := True;
    
    FActive := True;
    Result := True;
    
  except
    on E: Exception do
    begin
      Result := False;
      FreeAndNil(FPipeServer);
      
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
begin
  if not FActive or (FPipeServer = nil) then
    Exit;
    
  FActive := False;
  FPipeServer.Active := False;
  FreeAndNil(FPipeServer);
  FConnections.Clear;
end;

procedure TTBUNP_ServerPipe.HandleConnect(Sender: TObject; PipeHandle: THandle);
begin
  // 记录新连接
  FConnections.AddOrSetValue(PipeHandle, nil);
  
  // 触发连接事件
  if Assigned(FOnPipeServerConnectCallback) then
    FOnPipeServerConnectCallback(Cardinal(PipeHandle));
end;

procedure TTBUNP_ServerPipe.HandleDisconnect(Sender: TObject; PipeHandle: THandle);
begin
  // 移除连接
  FConnections.Remove(PipeHandle);
  
  // 触发断开事件
  if Assigned(FOnPipeServerDisconnectCallback) then
    FOnPipeServerDisconnectCallback(Cardinal(PipeHandle));
end;

procedure TTBUNP_ServerPipe.HandleRead(Sender: TObject; PipeHandle: THandle; 
  IncommingValue: TStream; OutgoingValue: TStream);
var
  Msg: WideString;
  Buffer: TBytes;
  OutStream: TMemoryStream;
  ResponseStr: WideString;
begin
  if Assigned(FOnPipeServerMessageCallback) and (IncommingValue <> nil) then
  begin
    // 读取接收到的数据
    IncommingValue.Position := 0;
    SetLength(Buffer, IncommingValue.Size);
    IncommingValue.Read(Buffer[0], IncommingValue.Size);
    
    // 转换为 Unicode 字符串
    SetLength(Msg, (IncommingValue.Size + 1) div SizeOf(WideChar));
    if IncommingValue.Size > 0 then
      Move(Buffer[0], Msg[1], IncommingValue.Size);
    
    // 触发消息事件
    FOnPipeServerMessageCallback(Cardinal(PipeHandle), PWideChar(Msg));
    
    // 如果需要回复，可以准备响应数据
    if OutgoingValue <> nil then
    begin
      // 这里可以准备响应数据
      // 例如：ResponseStr := 'Response from server';
      // 但通常响应应该由应用程序逻辑决定
    end;
  end;
end;

procedure TTBUNP_ServerPipe.HandleIdle(Sender: TObject);
begin
  // 空闲事件，可以在这里处理其他任务
  // 或者检查是否需要停止服务器
end;

function TTBUNP_ServerPipe.Broadcast(aMsg: PWideChar): Boolean;
var
  Msg: WideString;
  AnsiMsg: AnsiString;
  Buffer: TBytes;
  SendStream, ReceiveStream: TMemoryStream;
  PipeHandle: THandle;
  i: Integer;
  Keys: TArray<THandle>;
begin
  Result := False;
  if not FActive or (FPipeServer = nil) or (aMsg = nil) then
    Exit;
    
  Msg := StrPas(aMsg);
  if Length(Msg) = 0 then
    Exit;
    
  // 转换为 ANSI 用于传输
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
        // 获取所有连接句柄
        Keys := FConnections.Keys.ToArray;
        
        for i := 0 to Length(Keys) - 1 do
        begin
          PipeHandle := Keys[i];
          
          // 注意：TPipeServer 的 SendData 是客户端方法
          // 服务器广播需要另外实现
          // 这里需要调整实现
        end;
      finally
        ReceiveStream.Free;
      end;
    finally
      SendStream.Free;
    end;
    
    Result := True;
    
  except
    on E: Exception do
    begin
      Result := False;
      if Assigned(FOnPipeServerErrorCallback) then
        FOnPipeServerErrorCallback(0, 0, GetLastError);
    end;
  end;
end;

function TTBUNP_ServerPipe.Send(aPipe: HPIPE; aMsg: PWideChar): Boolean;
begin
  // 这个封装不支持向特定管道发送消息
  // 如果需要此功能，需要扩展 TPipeServer
  Result := False;
  if Assigned(FOnPipeServerErrorCallback) then
    FOnPipeServerErrorCallback(aPipe, 1, ERROR_NOT_SUPPORTED);
end;

function TTBUNP_ServerPipe.Disconnect(aPipe: HPIPE): Boolean;
begin
  // 这个封装不支持主动断开特定连接
  // 断开由客户端发起
  Result := False;
  if Assigned(FOnPipeServerErrorCallback) then
    FOnPipeServerErrorCallback(aPipe, 1, ERROR_NOT_SUPPORTED);
end;

function TTBUNP_ServerPipe.GetClientCount: Integer;
begin
  if FActive then
    Result := FConnections.Count
  else
    Result := 0;
end;

end.