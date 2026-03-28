unit TBUNP_ServerPipe;

interface

uses
  SysUtils, Classes,
  TBUNP_CommonTypes,
  TBUNP_ServerTypes,
  SimplePipes,
  TBUNP_Utils;

type
//  TPSConnectCb = procedure(aPipe: Cardinal) of object; stdcall;
//  TPSDisconnectCb = procedure(aPipe: Cardinal) of object; stdcall;
//  TPSErrorCb = procedure(aPipe: Cardinal; aPipeContext: ShortInt;
//    aErrorCode: Integer) of object; stdcall;
//  TPSMessageCb = procedure(aPipe: Cardinal; aMsg: PWideChar) of object; stdcall;
//  TPSSentCb = procedure(aPipe: Cardinal; aSize: Cardinal) of object; stdcall;

  TTBUNP_ServerPipe = class(TObject)
  private
    FPipeServer: TSharedPipe;  // SimplePipes 的服务器类
    FOnPipeServerConnectCallback: TPSConnectCb;
    FOnPipeServerDisconnectCallback: TPSDisconnectCb;
    FOnPipeServerErrorCallback: TPSErrorCb;
    FOnPipeServerMessageCallback: TPSMessageCb;
    FOnPipeServerSentCallback: TPSSentCb;
    
    procedure HandleMessage(const Msg: string);
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

constructor TTBUNP_ServerPipe.Create;
begin
  inherited Create;
  // 初始化代码
end;

destructor TTBUNP_ServerPipe.Destroy;
begin
  Stop;
  inherited;
end;

function TTBUNP_ServerPipe.Start: Boolean;
begin
  if FPipeServer <> nil then
  begin
    Result := False;
    Exit;
  end;
  
  try
    FPipeServer := TSharedPipe.CreateReadEnd('TBU_Pipe');
    FPipeServer.OnData := HandleMessage;
    Result := True;
    
    // 触发连接事件
    if Assigned(FOnPipeServerConnectCallback) then
      FOnPipeServerConnectCallback(0);
      
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
  if FPipeServer <> nil then
  begin
    Result := False;
    Exit;
  end;
  
  try
    FPipeServer := TSharedPipe.CreateReadEnd(StrPas(aPipeName));
    FPipeServer.OnData := HandleMessage;
    Result := True;
    
    if Assigned(FOnPipeServerConnectCallback) then
      FOnPipeServerConnectCallback(0);
      
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

procedure TTBUNP_ServerPipe.Stop;
begin
  FreeAndNil(FPipeServer);
end;

procedure TTBUNP_ServerPipe.HandleMessage(const Msg: string);
var
  Stream: TStringStream;
begin
  if Assigned(FOnPipeServerMessageCallback) then
  begin
    Stream := TStringStream.Create(Msg);
    try
      FOnPipeServerMessageCallback(0, PWideChar(WideString(Msg)));
    finally
      Stream.Free;
    end;
  end;
end;

function TTBUNP_ServerPipe.Broadcast(aMsg: PWideChar): Boolean;
begin
  if FPipeServer = nil then
  begin
    Result := False;
    Exit;
  end;
  
  try
    FPipeServer.Write(PChar(aMsg)^, Length(aMsg) * SizeOf(Char));
    Result := True;
    
    if Assigned(FOnPipeServerSentCallback) then
      FOnPipeServerSentCallback(0, Length(aMsg) * SizeOf(Char));
      
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
  // SimplePipes 是单连接，直接使用 Broadcast
  Result := Broadcast(aMsg);
end;

function TTBUNP_ServerPipe.Disconnect(aPipe: HPIPE): Boolean;
begin
  Stop;
  Result := True;
end;

function TTBUNP_ServerPipe.GetClientCount: Integer;
begin
  // SimplePipes 是单连接
  if FPipeServer <> nil then
    Result := 1
  else
    Result := 0;
end;

end.