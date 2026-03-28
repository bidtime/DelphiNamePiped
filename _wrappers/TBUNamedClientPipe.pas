unit TBUNamedClientPipe;

interface

uses
  SysUtils;

const
  /// <summary>
  /// The file name of the lib to load
  /// </summary>
  libName = 'TBUNamedPipe.dll';

{ PipeUtils }
/// <summary>
/// Translates a context ID to it's string value
/// </summary>
/// <param name="aPipe">[ Cardinal ] The context ID</param>
/// <returns>[ string ] The name of the context</returns>
function PipeContextToString(aPipeContext: ShortInt): string;

type
  { Pipe Server Callbacks }
  /// <summary>
  /// OnConnect callback
  /// </summary>
  /// <param name="aPipe">[ Cardinal ] The pipe ID</param>
  TPSConnectCb    = procedure(aPipe: Cardinal) of object; stdcall;
  /// <summary>
  /// OnDisconnect callback
  /// </summary>
  /// <param name="aPipe">[ Cardinal ] The pipe ID</param>
  TPSDisconnectCb = procedure(aPipe: Cardinal) of object; stdcall;
  /// <summary>
  /// OnError callback
  /// </summary>
  /// <param name="aPipe">[ Cardinal ] The pipe ID</param>
  /// <param name="aPipeContext">[ ShortInt ] The error context</param>
  /// <param name="aErrorCode">[ Integer ] The error code</param>
  TPSErrorCb      = procedure(aPipe: Cardinal; aPipeContext: ShortInt; aErrorCode: Integer) of object; stdcall;
  /// <summary>
  /// OnMessage callback
  /// </summary>
  /// <param name="aPipe">[ Cardinal ] The pipe ID</param>
  /// <param name="aMsg">[ PWideChar ] The message</param>
  TPSMessageCb    = procedure(aPipe: Cardinal; aMsg: PWideChar) of object; stdcall;
  /// <summary>
  /// OnSent callback
  /// </summary>
  /// <param name="aPipe">[ Cardinal ] The pipe ID</param>
  /// <param name="aSize">[ Cardinal ] The size in bytes</param>
  TPSSentCb       = procedure(aPipe: Cardinal; aSize: Cardinal) of object; stdcall;

  { Pipe Client Callbacks }
  /// <summary>
  /// OnDisconnect callback
  /// </summary>
  /// <param name="aPipe">[ Cardinal ] The pipe ID</param>
  TPCDisconnectCb = procedure(aPipe: Cardinal) of object; stdcall;
  /// <summary>
  /// OnError callback
  /// </summary>
  /// <param name="aPipe">[ Cardinal ] The pipe ID</param>
  /// <param name="aPipeContext">[ ShortInt ] The error context</param>
  /// <param name="aErrorCode">[ Integer ] The error code</param>
  TPCErrorCb      = procedure(aPipe: Cardinal; aPipeContext: ShortInt; aErrorCode: Integer) of object; stdcall;
  /// <summary>
  /// OnMessage callback
  /// </summary>
  /// <param name="aPipe">[ Cardinal ] The pipe ID</param>
  /// <param name="aMsg">[ PWideChar ] The message</param>
  TPCMessageCb    = procedure(aPipe: Cardinal; aMsg: PWideChar) of object; stdcall;
  /// <summary>
  /// OnSent callback
  /// </summary>
  /// <param name="aPipe">[ Cardinal ] The pipe ID</param>
  /// <param name="aSize">[ Cardinal ] The size in bytes</param>
  TPCSentCb       = procedure(aPipe: Cardinal; aSize: Cardinal) of object; stdcall;


{ Pipe Client }
// Methods
/// <summary>
/// Initialize the pipe client class
/// </summary>
procedure PipeClientInitialize;                                                     stdcall;
/// <summary>
/// Destroy the pipe client class
/// </summary>
procedure PipeClientDestroy;                                                        stdcall;
/// <summary>
/// Connect to the local pipe server
/// </summary>
/// <returns>[ WordBool ] True on success</returns>
function PipeClientConnect: WordBool;                                               stdcall;
/// <summary>
/// Connect to the local pipe server
/// </summary>
/// <param name="aPipeName">[ PWideChar ] The pipe name</param>
/// <returns>[ WordBool ] True on success</returns>
function PipeClientConnectNamed(aPipeName: PWideChar): WordBool;                    stdcall;
/// <summary>
/// Connect to a remote pipe server
/// </summary>
/// <param name="aServerName">[ PWideChar ] The server name ( Hostname )</param>
/// <returns>[ WordBool ] True on success</returns>
function PipeClientConnectRemote(aServerName: PWideChar): WordBool;                 stdcall;
/// <summary>
/// Connect to a remote pipe server
/// </summary>
/// <param name="aServerName">[ PWideChar ] The server name ( Hostname )</param>
/// <param name="aPipeName">[ PWideChar ] The pipe name</param>
/// <returns>[ WordBool ] True on success</returns>
function PipeClientConnectRemoteNamed(aServerName, aPipeName: PWideChar): WordBool; stdcall;
/// <summary>
/// Send a message to the pipe server
/// </summary>
/// <param name="aMsg">[ PWideChar ] The message</param>
/// <returns>[ WordBool ] True on success</returns>
function PipeClientSend(aMsg: PWideChar): WordBool;                                 stdcall;
/// <summary>
/// Disconnect from the pipe server
/// </summary>
procedure PipeClientDisconnect;                                                     stdcall;
/// <summary>
/// Get the ID of the current pipe
/// </summary>
/// <returns>[ Cardinal ] The pipe ID</returns>
function PipeClientGetPipeId: Cardinal;                                             stdcall;
// Callback registration
/// <summary>
/// Register the OnDisconnect callback method
/// </summary>
/// <param name="aCallback">[ TPCDisconnectCb ] The callback method</param>
procedure RegisterOnPipeClientDisconnectCallback(const aCallback: TPCDisconnectCb); stdcall;
/// <summary>
/// Register the OnError callback method
/// </summary>
/// <param name="aCallback">[ TPCErrorCb ] The callback method</param>
procedure RegisterOnPipeClientErrorCallback(const aCallback: TPCErrorCb);           stdcall;
/// <summary>
/// Register the OnMessage callback method
/// </summary>
/// <param name="aCallback">[ TPCMessageCb ] The callback method</param>
procedure RegisterOnPipeClientMessageCallback(const aCallback: TPCMessageCb);       stdcall;
/// <summary>
/// Register the OnSent callback method
/// </summary>
/// <param name="aCallback">[ TPCSentCb ] The callback method</param>
procedure RegisterOnPipeClientSentCallback(const aCallback: TPCSentCb);             stdcall;

implementation

{ Pipe Client }
// Methods
procedure PipeClientInitialize;        external libName;
procedure PipeClientDestroy;           external libName;
function PipeClientConnect;            external libName;
function PipeClientConnectNamed;       external libName;
function PipeClientConnectRemote;      external libName;
function PipeClientConnectRemoteNamed; external libName;
function PipeClientSend;               external libName;
procedure PipeClientDisconnect;        external libName;
function PipeClientGetPipeId;          external libName;
// Callback registration
procedure RegisterOnPipeClientDisconnectCallback; external libName;
procedure RegisterOnPipeClientErrorCallback;      external libName;
procedure RegisterOnPipeClientMessageCallback;    external libName;
procedure RegisterOnPipeClientSentCallback;       external libName;

{ PipeUtils }
function PipeContextToString(aPipeContext: ShortInt): string;
begin
  case aPipeContext of
    0: Result := 'Listener';
    1: Result := 'Worker';
    else raise Exception.Create('Unknown Pipe Context ID');
  end;
end;

initialization

finalization

end.
