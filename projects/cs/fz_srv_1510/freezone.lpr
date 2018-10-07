library freezone;
{$MODE Delphi}
uses
  windows, Forms, Interfaces, lazcontrols,
  srcBase, srcInjections, appinit, basedefs, ConfigMgr, Console, LogMgr,
  PlayersConnectionLog, ge_filter, PlayersConsole, AdminCommands;


{$R *.res}

function Init():boolean; stdcall;
begin
  result:=false;
  try
    //вызвать Init'ы всех модулей
    if not appinit.Init() then begin
      MessageBox(0, 'FreeZone is failed to initialize!', 'ERROR!', MB_OK or MB_ICONERROR or MB_SYSTEMMODAL);
    end;

    if FZConfigMgr.Get.GetBool('new_votings_allowed_by_default', true) then begin
      //Hack - иначе новые голосования постоянно будут блочиться при перезапуске сервера, так как лимиты команды обрежут загруженное из конфига значение...
      c_sv_vote_enabled.value^:=c_sv_vote_enabled.value^+$300;
    end;
    result:=true
  except
    MessageBox(0, 'Unexpected exception while initing FreeZone!', 'ERROR!', MB_OK or MB_ICONERROR or MB_SYSTEMMODAL);
  end;

  if not result then begin
    TerminateProcess(GetCurrentProcess(), 13);
  end;
end;


procedure Cleanup(); stdcall;
begin
  //Вызывается на Application::Terminate
  //Вызываем очистку
  FZLogMgr.Get.Write('Cleanup...', FZ_LOG_INFO);
  appinit.Free;
  srcKit.Finish;
end;

exports
  Init;

var
  CApplication_destructor:pointer;
begin
  randomize();

{$IFDEF RELEASE_BUILD}
  srcKit.Get.SwitchDebugMode(false);
  srcKit.Get.FullDbgLogStatus(false);
{$ELSE}
  srcKit.Get.SwitchDebugMode(true);
  srcKit.Get.FullDbgLogStatus(true);
{$ENDIF}

  Init();

  CApplication_destructor:=GetProcAddress(xrEngine, '??1CApplication@@QAE@XZ');
  if CApplication_destructor<>nil then begin
    srcCleanupInjection.Create(CApplication_destructor, @Cleanup, 5);
  end;
  srcKit.Get.InjectAll;

  RequireDerivedFormResource:=True;
  Application.Initialize;
end.



