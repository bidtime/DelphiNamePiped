unit TBUNP_ServerExports;

interface

uses
  SysUtils, Classes,
  Pipes,
  TBUNP_ServerPipe;

{ Declare Pipe Server Procedures }
procedure PipeServerInitialize; stdcall; export;
procedure PipeServerDestroy; stdcall; export;
function PipeServerStart: WordBool; stdcall; export;
function PipeServerStartNamed(aPipeName: PWideChar): WordBool; stdcall; export;
procedure PipeServerStop; stdcall; export;
function PipeServerBroadcast(aMsg: PWideChar): WordBool; stdcall; export;
function PipeServerSend(aPipe: Cardinal; aMsg: PWideChar): WordBool; stdcall; export;
function PipeServerDisconnect(aPipe: Cardinal): WordBool; stdcall; export;
function PipeServerGetClientCount: Integer; stdcall; export;
{ Declare Pipe Server Callback Registration Procedures }
procedure RegisterOnPipeServerConnectCallback(const aCallback: TPSConnectCb); stdcall; export;
procedure RegisterOnPipeServerDisconnectCallback(const aCallback: TPSDisconnectCb); stdcall; export;
procedure RegisterOnPipeServerErrorCallback(const aCallback: TPSErrorCb); stdcall; export;
procedure RegisterOnPipeServerMessageCallback(const aCallback: TPSMessageCb); stdcall; export;
procedure RegisterOnPipeServerSentCallback(const aCallback: TPSSentCb); stdcall; export;

exports
  { Declare Pipe Server Procedures }
  PipeServerInitialize,
  PipeServerDestroy,
  PipeServerStart,
  PipeServerStartNamed,
  PipeServerStop,
  PipeServerBroadcast,
  PipeServerSend,
  PipeServerDisconnect,
  PipeServerGetClientCount,
  { Declare Pipe Server Callback Registration Procedures }
  RegisterOnPipeServerConnectCallback,
  RegisterOnPipeServerDisconnectCallback,
  RegisterOnPipeServerErrorCallback,
  RegisterOnPipeServerMessageCallback,
  RegisterOnPipeServerSentCallback;

implementation

{ Declare Pipe Server Procedures }
procedure PipeServerInitialize; stdcall; export;
begin
  gServerPipe := TTBUNP_ServerPipe.Create;
end;

procedure PipeServerDestroy; stdcall; export;
begin
  FreeAndNil(gServerPipe);
end;

function PipeServerStart: WordBool; stdcall; export;
begin
  Result := WordBool(gServerPipe.Start);
end;

function PipeServerStartNamed(aPipeName: PWideChar): WordBool; stdcall; export;
begin
  Result := WordBool(gServerPipe.Start(aPipeName));
end;

procedure PipeServerStop; stdcall; export;
begin
  gServerPipe.Stop;
end;

function PipeServerBroadcast(aMsg: PWideChar): WordBool; stdcall; export;
begin
  Result := WordBool(gServerPipe.Broadcast(aMsg));
end;

function PipeServerSend(aPipe: Cardinal; aMsg: PWideChar): WordBool; stdcall; export;
begin
  Result := WordBool(gServerPipe.Send(HPIPE(aPipe), aMsg));
end;

function PipeServerDisconnect(aPipe: Cardinal): WordBool; stdcall; export;
begin
  Result := WordBool(gServerPipe.Disconnect(HPIPE(aPipe)));
end;

function PipeServerGetClientCount: Integer; stdcall; export;
begin
  Result := gServerPipe.GetClientCount;
end;

{ Declare Pipe Server Callback Registration Procedures }
procedure RegisterOnPipeServerConnectCallback(const aCallback: TPSConnectCb); stdcall; export;
begin
  gServerPipe.OnPipeServerConnectCallback := aCallback;
end;

procedure RegisterOnPipeServerDisconnectCallback(const aCallback: TPSDisconnectCb); stdcall; export;
begin
  gServerPipe.OnPipeServerDisconnectCallback := aCallback;
end;

procedure RegisterOnPipeServerErrorCallback(const aCallback: TPSErrorCb); stdcall; export;
begin
  gServerPipe.OnPipeServerErrorCallback := aCallback;
end;

procedure RegisterOnPipeServerMessageCallback(const aCallback: TPSMessageCb); stdcall; export;
begin
  gServerPipe.OnPipeServerMessageCallback := aCallback;
end;

procedure RegisterOnPipeServerSentCallback(const aCallback: TPSSentCb); stdcall; export;
begin
  gServerPipe.OnPipeServerSentCallback := aCallback;
end;


initialization

finalization

end.
