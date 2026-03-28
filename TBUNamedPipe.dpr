library TBUNamedPipe;

{$I TBUNamedPipe.inc}

{ Important note about DLL memory management: ShareMem must be the
  first unit in your library's USES clause AND your project's (select
  Project-View Source) USES clause if your DLL exports any procedures or
  functions that pass strings as parameters or function results. This
  applies to all strings passed to and from your DLL--even those that
  are nested in records and classes. ShareMem is the interface unit to
  the BORLNDMM.DLL shared memory manager, which must be deployed along
  with your DLL. To avoid using BORLNDMM.DLL, pass string information
  using PChar or ShortString parameters. }

uses
  System.SysUtils,
  System.Classes,
  TBUNP_CommonTypes in 'src\TBUNP_CommonTypes.pas',
  TBUNP_ServerTypes in 'src\TBUNP_ServerTypes.pas',
  TBUNP_ClientTypes in 'src\TBUNP_ClientTypes.pas',
  TBUNP_ServerExports in 'src\TBUNP_ServerExports.pas',
  TBUNP_ClientExports in 'src\TBUNP_ClientExports.pas',
  {$IFDEF USE_VCL_PIPES}
  Pipes in 'src\Components\Pipes.pas',
  TBUNP_ServerPipe in 'src\TBUNP_ServerPipe.pas',
  TBUNP_ClientPipe in 'src\TBUNP_ClientPipe.pas',
  {$ENDIF}
  {$IFDEF USE_SIMPLE_PIPES}
  SimplePipes in 'src\SimplePipe\Components\SimplePipes.pas',
  TBUNP_ServerPipe in 'src\SimplePipe\TBUNP_ServerPipe.pas',
  TBUNP_ClientPipe in 'src\\SimplePipe\TBUNP_ClientPipe.pas',
  {$ENDIF}
  {$IFDEF USE_WINAPI_VER_01}
  WinApiPipeClient in 'src\WinAPI_Ver_01\Components\WinApiPipeClient.pas',
  WinApiPipeServer in 'src\WinAPI_Ver_01\Components\WinApiPipeServer.pas',
  TBUNP_ServerPipe in 'src\WinAPI_Ver_01\TBUNP_ServerPipe.pas',
  TBUNP_ClientPipe in 'src\\WinAPI_Ver_01\TBUNP_ClientPipe.pas',
  {$ENDIF}
  {$IFDEF USE_FWIO_PIPES}
  uNamedPipesExchange in 'src\FWIOPipe\Components\uNamedPipesExchange.pas',
  FWIOCompletionPipes in 'src\FWIOPipe\Components\FWIOCompletionPipes.pas',
  TBUNP_ServerPipe in 'src\FWIOPipe\TBUNP_ServerPipe.pas',
  TBUNP_ClientPipe in 'src\\FWIOPipe\TBUNP_ClientPipe.pas',
  {$ENDIF}
  {$IFDEF CROMIS_PIPES}
  Cromis.Comm.Custom in 'src\CromisPipes\Components\Cromis.Comm.Custom.pas',
  Cromis.Threading in 'src\CromisPipes\Components\Cromis.Threading.pas',
  Cromis.Unicode in 'src\CromisPipes\Components\Cromis.Unicode.pas',
  Cromis.Comm.IPC in 'src\CromisPipes\Components\Cromis.Comm.IPC.pas',
  TBUNP_ServerPipe in 'src\CromisPipes\TBUNP_ServerPipe.pas',
  TBUNP_ClientPipe in 'src\\CromisPipes\TBUNP_ClientPipe.pas',
  {$ENDIF}
  {$IFDEF LAZARUS_PIPES}
  pipeserver_unit in 'src\LazarusPipe\Components\pipeserver_unit.pas',
  pipeclient_unit in 'src\LazarusPipe\Components\pipeclient_unit.pas',
  TBUNP_ServerPipe in 'src\LazarusPipe\TBUNP_ServerPipe.pas',
  TBUNP_ClientPipe in 'src\\LazarusPipe\TBUNP_ClientPipe.pas',
  {$ENDIF}
  TBUNP_Utils in 'src\TBUNP_Utils.pas';

{$R *.res}

begin
end.
