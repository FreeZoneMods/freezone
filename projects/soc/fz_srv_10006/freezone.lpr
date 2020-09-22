library freezone;

{$mode delphi}

uses
  windows,                          //MessageBox'ы
  BaseEngineFrameworkFunctions,     //Должен быть первым для корректной инициализации путей
  srcBase, srcInjections,           //управление srcKit и очистка
  basedefs,
  LogMgr,
  appinit;

function Init():boolean; stdcall;
begin
  result:=false;
  try
    //вызвать Init'ы всех модулей
    if not appinit.Init() then begin
      MessageBox(0, 'FreeZone is failed to initialize!', 'ERROR!', MB_OK or MB_ICONERROR or MB_SYSTEMMODAL);
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
  srcCleanupInjection.Create({%H-}pointer(xrEngine+$ac330), @Cleanup, 5);
  srcKit.Get.InjectAll;
end.


