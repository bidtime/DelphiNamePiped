program Server;

uses
  Vcl.Forms,
  Main in 'Main.pas' {Form1},
  uFormIniFiles in '..\Public\uFormIniFiles.pas',
  TBUNamedServerPipe in '..\..\..\_wrappers\TBUNamedServerPipe.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
