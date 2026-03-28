program Client;

uses
  Vcl.Forms,
  uFormIniFiles in '..\Public\uFormIniFiles.pas',
  Main in 'Main.pas' {Form2},
  TBUNamedClientPipe in '..\..\..\_wrappers\TBUNamedClientPipe.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm2, Form2);
  Application.Run;
end.
