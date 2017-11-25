unit safesync;

{$mode delphi}

interface

type
  FZSafeProc = procedure(ptr:pointer);

procedure SafeExec(payload:FZSafeProc; arg:pointer=nil);

implementation
uses
  RenderDevice, Synchro, sysutils, global_functions, basedefs;

procedure SafeExec(payload:FZSafeProc; arg:pointer);
var
  old_active_status:cardinal;
begin
  ////////////////////////////////////////////////////
  // ВНИМАНИЕ! В этой процедуре высока концентрация //
  // черной (или чертовой, кому как нравится) магии.//
  // Без понимания многопоточности в целом и ее     //
  // реализации в X-Ray в частности что-либо менять //
  //          КАТЕГОРИЧЕСКИ ЗАПРЕЩАЕТСЯ!            //
  // P.S.Да даже и при понимании подумайте 10 раз...//
  ////////////////////////////////////////////////////

  //Даем cигнал к завершению второго потока
  pDevice.mt_bMustExit:=1;
  //Ожидаем завершения
  while (pDevice.mt_bMustExit>0) do Sleep(1);

  //теперь мимикрируем под Secondary Thread, захватывая мьютекс, разрешающий
  //начало его выполнения и сигнализируещий главному потоку об активной работе оного
  //Он может быть захвачен только во время активности параллельного участка главного потока!
  xrCriticalSection__Enter(@pDevice.mt_csEnter);

  //но тут нас ожидает проблема: главный поток сейчас может вовсю исполнять свою работу и
  //рендерить. Надо заблокировать ему возможность начала рендеринга, а если он после этого
  //окажется уже занят им - подождать, пока он закончит свои дела.
  old_active_status:=AtomicExchange(@pDevice.b_is_Active, 0);

  //CRenderDevice::b_is_Active, будучи выставлен в false, предотвратит начало рендеринга
  //Но если рендеринг начался до того, как мы выставили флаг, нам надо подождать его конца
  while g_pbRendering^<>0 do begin
    Sleep(1);
  end;

  AtomicExchange(@pDevice.b_is_Active, old_active_status);
  //Ок, теперь делаем то, ради чего мы сюда, собственно, и пришли
  payload(arg);

  //Самое время перезапустить второй поток
  thread_spawn(pointer(xrEngine+$556F0), PChar(xrEngine+$7ACB4), 0, nil);

  //Больше не требуется ничего ждать :)
  xrCriticalSection__Leave(@pDevice.mt_csEnter);

  //ждать завершения работы итерации главного процесса нет необходимости.
  //Более того, вторичный поток еще может успеть захватить mt_csEnter ;)
end;

end.

