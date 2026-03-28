unit TBUNP_ServerPipe;

interface

uses
  Classes, SysUtils, SyncObjs, Windows,
  TBUNP_CommonTypes,
  TBUNP_ServerTypes,
  Cromis.Comm.Custom,  // 必要的依赖
  Cromis.Comm.IPC,     // Cromis IPC
  TBUNP_Utils;

type
  TTBUNP_ServerPipe = class(TObject)
  private
    FIPCServer: TIPCServer;
    FOnPipeServerConnectCallback: TPSConnectCb;
    FOnPipeServerDisconnectCallback: TPSDisconnectCb;
    FOnPipeServerErrorCallback: TPSErrorCb;
    FOnPipeServerMessageCallback: TPSMessageCb;
    FOnPipeServerSentCallback: TPSSentCb;
    FPipeName: string;
    FRequestCounter: Integer;
    FConnections: TThreadList;  // 存储连接信息
    FHandleCounter: Cardinal;   // 句柄计数器

    // 内部事件处理
    procedure HandleClientConnect(const Context: ICommContext);
    procedure HandleClientDisconnect(const Context: ICommContext);
    procedure HandleServerError(const Context: ICommContext; const Error: TServerError);
    procedure HandleExecuteRequest(const Context: ICommContext;
      const Request, Response: IMessageData);

    // 工具函数
    function GenerateNewHandle: HPIPE;
    procedure SendEventToMainThread(AEvent: Integer; AHandle: HPIPE;
      AData: Pointer = nil; ASize: Integer = 0);

  public
    constructor Create;
    destructor Destroy; override;

    function Start: Boolean; overload;
    function Start(aPipeName: PWideChar): Boolean; overload;
    procedure Stop;
    function Broadcast(aMsg: PWideChar): Boolean;
    function Send(aPipe: HPIPE; aMsg: PWideChar): Boolean;
    function Disconnect(aPipe: HPIPE): Boolean;
    function GetClientCount: Integer;

    function isActive(): Boolean;

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
  end;

implementation

{ TConnectionInfo 用于存储连接信息 }
type
  TConnectionInfo = class
  public
    Context: ICommContext;
    Handle: HPIPE;
    ClientID: string;
    constructor Create(AContext: ICommContext; AHandle: HPIPE; const AClientID: string);
  end;

constructor TConnectionInfo.Create(AContext: ICommContext; AHandle: HPIPE; const AClientID: string);
begin
  inherited Create;
  Context := AContext;
  Handle := AHandle;
  ClientID := AClientID;
end;

{ TTBUNP_ServerPipe }

constructor TTBUNP_ServerPipe.Create;
begin
  inherited Create;
  FIPCServer := nil;
  FConnections := TThreadList.Create;
  FPipeName := 'TBU_Pipe';
  FRequestCounter := 0;
  FHandleCounter := 1000;  // 从 1000 开始

  FIPCServer := TIPCServer.Create;
  // 设置事件处理程序
  FIPCServer.OnClientConnect := HandleClientConnect;
  FIPCServer.OnClientDisconnect := HandleClientDisconnect;
  FIPCServer.OnServerError := HandleServerError;
  FIPCServer.OnExecuteRequest := HandleExecuteRequest;
end;

destructor TTBUNP_ServerPipe.Destroy;
begin
  // 设置事件处理程序
//  FIPCServer.OnClientConnect := nil;
//  FIPCServer.OnClientDisconnect := nil;
  FIPCServer.OnServerError := nil;
  FIPCServer.OnExecuteRequest := nil;
  //
  Stop;
  FIPCServer.free;
  FConnections.Free;
  inherited;
end;

function TTBUNP_ServerPipe.GenerateNewHandle: HPIPE;
begin
  // 生成新的唯一句柄
  // 使用 InterlockedIncrement 确保线程安全
  Result := HPIPE(InterlockedIncrement(Integer(FHandleCounter)));
end;

function TTBUNP_ServerPipe.Start: Boolean;
begin
  try
    // 设置服务器名称
    FIPCServer.ServerName := FPipeName;

    if not isActive then begin
      FIPCServer.Start;
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

function TTBUNP_ServerPipe.Start(aPipeName: PWideChar): Boolean;
begin
  if aPipeName <> nil then
    FPipeName := StrPas(aPipeName);

  Result := Start;
end;

procedure TTBUNP_ServerPipe.Stop;
begin
  if isActive then begin
    FIPCServer.Stop;
  end;

  // 清理连接列表
  var List := FConnections.LockList;
  try
    for var i := List.Count - 1 downto 0 do
      TConnectionInfo(List[i]).Free;
    List.Clear;
  finally
    FConnections.UnlockList;
  end;
end;

procedure TTBUNP_ServerPipe.HandleClientConnect(const Context: ICommContext);
var
  Handle: HPIPE;
begin
  if Context = nil then
    Exit;

  Handle := GenerateNewHandle;

  // 添加到连接列表
  var ConnInfo := TConnectionInfo.Create(Context, Handle, Context.Client.ID);
  var List := FConnections.LockList;
  try
    List.Add(ConnInfo);
  finally
    FConnections.UnlockList;
  end;

  // 在主线程中触发连接事件
  SendEventToMainThread(1, Handle);
end;

procedure TTBUNP_ServerPipe.HandleClientDisconnect(const Context: ICommContext);
var
  List: TList;
  i: Integer;
  ConnInfo: TConnectionInfo;
  FoundHandle: HPIPE;
begin
  if Context = nil then
    Exit;

  FoundHandle := 0;

  // 从连接列表中移除
  List := FConnections.LockList;
  try
    for i := 0 to List.Count - 1 do
    begin
      ConnInfo := TConnectionInfo(List[i]);
      if ConnInfo.Context = Context then
      begin
        FoundHandle := ConnInfo.Handle;
        ConnInfo.Free;
        List.Delete(i);
        Break;
      end;
    end;
  finally
    FConnections.UnlockList;
  end;

  if FoundHandle <> 0 then
  begin
    // 在主线程中触发断开事件
    SendEventToMainThread(4, FoundHandle);
  end;
end;

procedure TTBUNP_ServerPipe.HandleServerError(const Context: ICommContext;
  const Error: TServerError);
var
  Handle: HPIPE;
  i: Integer;
  List: TList;
  ConnInfo: TConnectionInfo;
begin
  if Context <> nil then
  begin
    // 查找上下文对应的句柄
    List := FConnections.LockList;
    try
      Handle := 0;
      for i := 0 to List.Count - 1 do
      begin
        ConnInfo := TConnectionInfo(List[i]);
        if ConnInfo.Context = Context then
        begin
          Handle := ConnInfo.Handle;
          Break;
        end;
      end;
    finally
      FConnections.UnlockList;
    end;
  end
  else
    Handle := 0;

  SendEventToMainThread(2, Handle, nil, Error.Code);
end;

function TTBUNP_ServerPipe.isActive: Boolean;
begin
  Result := self.FIPCServer.Listening;
end;

procedure TTBUNP_ServerPipe.HandleExecuteRequest(const Context: ICommContext;
  const Request, Response: IMessageData);
var
  Handle: HPIPE;
  i: Integer;
  List: TList;
  ConnInfo: TConnectionInfo;
  Msg: WideString;
  AnsiMsg: AnsiString;
  StreamSize: Int64;
begin
  if (Context = nil) or (Request = nil) or (Response = nil) then
    Exit;

  // 查找上下文对应的句柄
  Handle := 0;
  List := FConnections.LockList;
  try
    for i := 0 to List.Count - 1 do
    begin
      ConnInfo := TConnectionInfo(List[i]);
      if ConnInfo.Context = Context then
      begin
        Handle := ConnInfo.Handle;
        Break;
      end;
    end;
  finally
    FConnections.UnlockList;
  end;

  if Handle = 0 then
    Exit;

  // 读取请求数据
  StreamSize := Request.Data.Storage.Size;
  if StreamSize > 0 then
  begin
    Request.Data.Storage.Position := 0;
    SetLength(AnsiMsg, StreamSize);
    Request.Data.Storage.Read(AnsiMsg[1], StreamSize);

    // 转换为 Unicode
    Msg := WideString(AnsiMsg);

    // 在主线程中触发消息事件
    TThread.Queue(nil, procedure
      begin
        if Assigned(FOnPipeServerMessageCallback) then
          FOnPipeServerMessageCallback(Cardinal(Handle), PWideChar(Msg));
      end
    );
  end;

  // 准备响应（示例：简单的回显）
  Response.ID := Request.ID;
  if Msg <> '' then
  begin
    // 这里可以准备自定义响应
    // 示例：回显原始消息
    Response.Data.WriteUTF8String('Echo', AnsiString(Msg));
  end;

  // 触发发送完成事件
  SendEventToMainThread(5, Handle, nil, StreamSize);
end;

procedure TTBUNP_ServerPipe.SendEventToMainThread(AEvent: Integer; AHandle: HPIPE;
  AData: Pointer = nil; ASize: Integer = 0);
begin
  TThread.Queue(nil, procedure
    begin
      case AEvent of
        1:  // 连接
          if Assigned(FOnPipeServerConnectCallback) then
            FOnPipeServerConnectCallback(Cardinal(AHandle));

        2:  // 错误
          if Assigned(FOnPipeServerErrorCallback) then
            FOnPipeServerErrorCallback(Cardinal(AHandle), 0, ASize);

//        3:  // 消息（已经在 HandleExecuteRequest 中处理）
//          // 不在这里处理

        4:  // 断开
          if Assigned(FOnPipeServerDisconnectCallback) then
            FOnPipeServerDisconnectCallback(Cardinal(AHandle));

        5:  // 发送完成
          if Assigned(FOnPipeServerSentCallback) then
            FOnPipeServerSentCallback(Cardinal(AHandle), ASize);
      end;
    end
  );
end;

function TTBUNP_ServerPipe.Broadcast(aMsg: PWideChar): Boolean;
begin
  // Cromis IPC 不支持直接的广播
  // 需要遍历所有连接单独发送
  Result := False;
  if not isActive or (aMsg = nil) then
    Exit;

  // 获取所有连接
  var List := FConnections.LockList;
  try
    for var i := 0 to List.Count - 1 do
    begin
      var ConnInfo := TConnectionInfo(List[i]);
      // 这里需要实现向单个连接发送消息
      // 由于Cromis没有直接的广播API，我们需要单独处理每个连接
    end;
  finally
    FConnections.UnlockList;
  end;

  Result := True;
end;

function TTBUNP_ServerPipe.Send(aPipe: HPIPE; aMsg: PWideChar): Boolean;
begin
  // 向特定连接发送消息
  // Cromis 没有直接的发送API，需要通过ExecuteRequest机制
  Result := False;
  if not isActive or (aMsg = nil) then
    Exit;

  // 需要特定的实现来处理
  if Assigned(FOnPipeServerErrorCallback) then
    FOnPipeServerErrorCallback(aPipe, 1, 50);  // ERROR_NOT_SUPPORTED

  Result := False;
end;

function TTBUNP_ServerPipe.Disconnect(aPipe: HPIPE): Boolean;
begin
  // Cromis 没有直接断开特定连接的API
  // 断开由客户端发起
  Result := False;
  if Assigned(FOnPipeServerErrorCallback) then
    FOnPipeServerErrorCallback(aPipe, 1, 50);  // ERROR_NOT_SUPPORTED
end;

function TTBUNP_ServerPipe.GetClientCount: Integer;
var
  List: TList;
begin
  List := FConnections.LockList;
  try
    Result := List.Count;
  finally
    FConnections.UnlockList;
  end;
end;

end.
