unit TBUNP_ClientPipe;

interface

uses
  SysUtils, Classes,
  Pipes,
  TBUNP_ClientTypes,
  TBUNP_Utils;

type
  TTBUNP_ClientPipe = class(TObject)
    private
      FPipeClient:   TPipeClient;
      procedure OPCDCB(aSender: TObject; aPipe: HPIPE);
      procedure OPCECB(aSender: TObject; aPipe: HPIPE;
                       aPipeContext: TPipeContext; aErrorCode: Integer);
      procedure OPCMCB(aSender: TObject; aPipe: HPIPE; aStream: TStream);
      procedure OPCSCB(aSender: TObject; aPipe: HPIPE; aSize: Cardinal);
    public
      OnPipeClientDisconnectCallback: TPCDisconnectCb;
      OnPipeClientErrorCallback:      TPCErrorCb;
      OnPipeClientMessageCallback:    TPCMessageCb;
      OnPipeClientSentCallback:       TPCSentCb;
      constructor Create;
      destructor Destroy; override;
      function Connect: Boolean; overload;
      function Connect(aPipeName: PWideChar): Boolean; overload;
      function ConnectRemote(aServername: PWideChar): Boolean; overload;
      function ConnectRemote(aServername, aPipeName: PWideChar): Boolean; overload;
      procedure Disconnect;
      function Send(aMsg: PWideChar): Boolean;
      function GetPipeId: HPIPE;
  end;

implementation

constructor TTBUNP_ClientPipe.Create;
begin
  FPipeClient                  := TPipeClient.CreateUnowned;
  FPipeClient.OnPipeDisconnect := OPCDCB;
  FPipeClient.OnPipeError      := OPCECB;
  FPipeClient.OnPipeMessage    := OPCMCB;
  FPipeClient.OnPipeSent       := OPCSCB;
end;

destructor TTBUNP_ClientPipe.Destroy;
begin
  FPipeClient.OnPipeMessage    := nil;
  // Call local method Disconnect, as it disconnects and frees the resource
  Disconnect;
  FPipeClient.free;
  inherited;
end;

function TTBUNP_ClientPipe.Connect: Boolean;
begin
  if FPipeClient.Connected then
  begin
    Result := False;
    Exit;
  end;

  Result    := FPipeClient.Connect(2000, True);

  // We must manually cleanup to prevent unexpected behaviour
//  if not Result then
//    Disconnect;
end;

function TTBUNP_ClientPipe.Connect(aPipeName: PWideChar): Boolean;
begin
  if FPipeClient.Connected then
  begin
    Result := False;
    Exit;
  end;

  FPipeClient.PipeName         := StrPas(aPipeName);
  Result    := FPipeClient.Connect(2000, True);

  // We must manually cleanup to prevent unexpected behaviour
  if not Result then
    Disconnect;
end;

function TTBUNP_ClientPipe.ConnectRemote(aServername: PWideChar): Boolean;
begin
  if FPipeClient.Connected then
  begin
    Result := False;
    Exit;
  end;

  FPipeClient.ServerName       := StrPas(aServerName);
  Result    := FPipeClient.Connect(2000, True);

  // We must manually cleanup to prevent unexpected behaviour
  if not Result then
    Disconnect;
end;

function TTBUNP_ClientPipe.ConnectRemote(aServername, aPipeName: PWideChar): Boolean;
begin
  if FPipeClient.Connected then
  begin
    Result := False;
    Exit;
  end;

  FPipeClient.ServerName       := StrPas(aServerName);
  FPipeClient.PipeName         := StrPas(aPipeName);

  Result    := FPipeClient.Connect(2000, True);

  // We must manually cleanup to prevent unexpected behaviour
  if not Result then
    Disconnect;
end;

procedure TTBUNP_ClientPipe.Disconnect;
begin
  if FPipeClient.Connected then
    FPipeClient.Disconnect;
end;

function TTBUNP_ClientPipe.Send(aMsg: PWideChar): Boolean;
begin
  if (not FPipeClient.Connected) or (Length(aMsg) <= 0) then
  begin
    Result := False;
    Exit;
  end;

  Result := FPipeClient.Write(aMsg^, Length(aMsg) * SizeOf(Char));
end;

function TTBUNP_ClientPipe.GetPipeId: HPIPE;
begin
  if (not FPipeClient.Connected) then
  begin
    Result := 0;
    Exit;
  end;

  Result := FPipeClient.Pipe;
end;

procedure TTBUNP_ClientPipe.OPCDCB(aSender: TObject; aPipe: HPIPE);
begin
  if Assigned(OnPipeClientDisconnectCallback) then
    OnPipeClientDisconnectCallback(Cardinal(aPipe));
end;

procedure TTBUNP_ClientPipe.OPCECB(aSender: TObject; aPipe: HPIPE;
                                   aPipeContext: TPipeContext;
                                   aErrorCode: Integer);
begin
  if Assigned(OnPipeClientErrorCallback) then
    OnPipeClientErrorCallback(Cardinal(aPipe),
                              ShortInt(aPipeContext),
                              aErrorCode);
end;

procedure TTBUNP_ClientPipe.OPCMCB(aSender: TObject; aPipe: HPIPE;
                                   aStream: TStream);
var
  msg: WideString;
begin
  if Assigned(OnPipeClientMessageCallback) then
  begin
    SetLength(msg, aStream.Size div SizeOf(Char));
    aStream.Position := 0;
    aStream.Read(msg[1], aStream.Size);

    OnPipeClientMessageCallback(Cardinal(aPipe), PWideChar(msg));
  end;
end;

procedure TTBUNP_ClientPipe.OPCSCB(aSender: TObject; aPipe: HPIPE;
                                   aSize: Cardinal);
begin
  if Assigned(OnPipeClientSentCallback) then
    OnPipeClientSentCallback(Cardinal(aPipe), aSize);
end;

initialization

finalization

end.
