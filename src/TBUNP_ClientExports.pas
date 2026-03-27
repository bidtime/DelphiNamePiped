unit TBUNP_ClientExports;

interface

uses
  SysUtils, Classes,
  Pipes,
  TBUNP_ClientPipe;

{ Declare Pipe Client Procedures }
procedure PipeClientInitialize; stdcall; export;
procedure PipeClientDestroy; stdcall; export;
function PipeClientConnect: WordBool; stdcall; export;
function PipeClientConnectNamed(aPipeName: PWideChar): WordBool; stdcall; export;
function PipeClientConnectRemote(aServerName: PWideChar): WordBool; stdcall; export;
function PipeClientConnectRemoteNamed(aServerName, aPipeName: PWideChar): WordBool; stdcall; export;
function PipeClientSend(aMsg: PWideChar): WordBool; stdcall; export;
procedure PipeClientDisconnect; stdcall; export;
function PipeClientGetPipeId: Cardinal; stdcall; export;
{ Declare Pipe Client Callback Registration Procedures }
procedure RegisterOnPipeClientDisconnectCallback(const aCallback: TPCDisconnectCb); stdcall; export;
procedure RegisterOnPipeClientErrorCallback(const aCallback: TPCErrorCb); stdcall; export;
procedure RegisterOnPipeClientMessageCallback(const aCallback: TPCMessageCb); stdcall; export;
procedure RegisterOnPipeClientSentCallback(const aCallback: TPCSentCb); stdcall; export;

exports
  { Declare Pipe Client Procedures }
  PipeClientInitialize,
  PipeClientDestroy,
  PipeClientConnect,
  PipeClientConnectNamed,
  PipeClientConnectRemote,
  PipeClientConnectRemoteNamed,
  PipeClientSend,
  PipeClientDisconnect,
  PipeClientGetPipeId,
  { Declare Pipe Client Callback Registration Procedures }
  RegisterOnPipeClientDisconnectCallback,
  RegisterOnPipeClientErrorCallback,
  RegisterOnPipeClientMessageCallback,
  RegisterOnPipeClientSentCallback;

implementation

{ Declare Pipe Client Procedures }
procedure PipeClientInitialize; stdcall; export;
begin
  gClientPipe := TTBUNP_ClientPipe.Create;
end;

procedure PipeClientDestroy; stdcall; export;
begin
  FreeAndNil(gClientPipe);
end;

function PipeClientConnect: WordBool; stdcall; export;
begin
  Result := WordBool(gClientPipe.Connect);
end;

function PipeClientConnectNamed(aPipeName: PWideChar): WordBool; stdcall; export;
begin
  Result := WordBool(gClientPipe.Connect(aPipeName));
end;

function PipeClientConnectRemote(aServerName: PWideChar): WordBool; stdcall; export;
begin
  Result := WordBool(gClientPipe.ConnectRemote(aServerName));
end;

function PipeClientConnectRemoteNamed(aServerName, aPipeName: PWideChar): WordBool; stdcall; export;
begin
  Result := WordBool(gClientPipe.ConnectRemote(aServerName, aPipeName));
end;

function PipeClientSend(aMsg: PWideChar): WordBool; stdcall; export;
begin
  Result := WordBool(gClientPipe.Send(aMsg));
end;

procedure PipeClientDisconnect; stdcall; export;
begin
  gClientPipe.Disconnect;
end;

function PipeClientGetPipeId: Cardinal; stdcall; export;
begin
  Result := Cardinal(gClientPipe.GetPipeId);
end;

{ Declare Pipe Server Callback Registration Procedures }
procedure RegisterOnPipeClientDisconnectCallback(const aCallback: TPCDisconnectCb); stdcall; export;
begin
  gClientPipe.OnPipeClientDisconnectCallback := aCallback;
end;

procedure RegisterOnPipeClientErrorCallback(const aCallback: TPCErrorCb); stdcall; export;
begin
  gClientPipe.OnPipeClientErrorCallback := aCallback;
end;

procedure RegisterOnPipeClientMessageCallback(const aCallback: TPCMessageCb); stdcall; export;
begin
  gClientPipe.OnPipeClientMessageCallback := aCallback;
end;

procedure RegisterOnPipeClientSentCallback(const aCallback: TPCSentCb); stdcall; export;
begin
  gClientPipe.OnPipeClientSentCallback := aCallback;
end;

initialization

finalization

end.
