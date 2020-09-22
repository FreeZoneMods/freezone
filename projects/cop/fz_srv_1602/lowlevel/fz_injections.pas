unit fz_injections;

{$mode delphi}

interface

function Init():boolean; stdcall;

implementation
uses basedefs, srcInjections, srcBase, BasicProtection, Bans, ServerStuff, Players, GameSpy, Chat, ConfigMgr, Voting;

function PatchBanSystem():boolean;
begin
  //первым делом смотрим в xrServer::ProcessClientDigest и видим:
  //P->r_stringZ	(xrCL->m_cdkey_digest);
	//P->r_stringZ	(secondary_cdkey);
  //Если первое (хеш от нижнего регистра) и ладно, пусть будет
  //То вот второй у нас дублируется с полученным и проверенным геймспаем во время CHALLENGE_RESPOND
  //[bug]Клиент тут может нам отослать все, что ему заблагорассудится, и чего не окажется в банлисте... непорядок.
  //[bug] По умолчанию, в xrCL->m_cdkey_digest попадает именно хеш от НИЖНЕГО регистра, то есть НЕ проверенный геймспаем!
  //Решение - делаем так, чтобы в xrCL->m_cdkey_digest оказался полученный в CHALLENGE_RESPOND хеш
{  if xrGameDllType()=XRGAME_1602 then begin
    srcBaseInjection.Create(pointer(xrGame+$307AC7), @xrServer__ProcessClientDigest_ProtectFromKeyChange, 5,[F_RMEM+F_PUSH_EBP+$0C, F_PUSH_ECX, F_PUSH_ESI], false, false);
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$307B37),@xrServer__ProcessClientDigest_CheckAdditionalRejectingConditions,6,[F_PUSH_EDI],pointer(xrGame+$307B4C), JUMP_IF_FALSE, false, false);
  end;}

  //Пропатчимся на бан подсетей
  srcInjectionWithConditionalJump.Create(pointer(xrNetServer+$A979),@IPureServer__net_Handler_SubnetBans,5,[F_RMEM+F_PUSH_ESP+$0C],pointer(xrNetServer+$A989), JUMP_IF_TRUE, true, False);

  //Сообщение о том, что IP забанен в игровом банлисте
  srcBaseInjection.Create(pointer(xrNetServer+$A989),@IPureServer__net_Handler_OnBannedByGameIpFound,7,[F_RMEM+F_PUSH_ESP+$0C], true, False);

  //заблокируем бан пустого ключа
{  if xrGameDllType()=XRGAME_1602 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30950E),@cdkey_ban_list__ban_player_checkemptykey,9,[F_PUSH_ESI],pointer(xrGame+$30951E), JUMP_IF_TRUE, true, true);
  end;}
  result:=true;
end;

function PatchVoting():boolean;
begin
  result:=false;

  //проверка на возможность начать голосование в game_sv_mp::OnEvent
  if xrGameDllType()=XRGAME_1602 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$38c2e7), @CanSafeStartVoting, 10, [F_PUSH_EBX, F_PUSH_ESI, F_RMEM+F_PUSH_ESP+$41c], pointer(xrGame+$38c4f3), JUMP_IF_FALSE, true, false);
  end;

  //[bug] если при старте голосования на кик/бан задать несуществующего игрока, то строка с консольной командой, выполняющейся при успехе голосования, не обновится. Чревато крешем сервера! (голосования до этого могло и не быть!)
  if xrGameDllType()=XRGAME_1602 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$390035),@OnVoteStartIncorrectPlayerName,12,[F_PUSH_EBX],pointer(xrGame+$3901da), JUMP_IF_FALSE, true, true);
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$38ff43),@OnVoteStartIncorrectPlayerName,19,[F_PUSH_EBX],pointer(xrGame+$3901da), JUMP_IF_FALSE, true, true);
  end;

  //обработка нестандартных голосований+ FZ'шный транслятор строк
  if xrGameDllType()=XRGAME_1602 then begin
    srcKit.nop_code(pointer(xrGame+$39010d), 2);
    srcBaseInjection.Create(pointer(xrGame+$390115), @OnVoteStart, 15,[F_PUSH_EBX, F_RMEM+F_PUSH_EBP+$C, F_RMEM+F_PUSH_EBP+8, F_PUSH_EDX],true, true);
  end;

  result:=true;
end;

function PatchGameSpy():boolean;
begin
  //Меняем имя сервера (в callback_serverkey)
  if xrGameDllType()=XRGAME_1602 then begin
    srcEAXReturnerInjection.Create(pointer(xrGame+$3b3bad), @ChangeHostname, 5, [F_PUSH_EBP], true, true);
  end;

  //Переводим имя карты на человеческий язык (в callback_serverkey)
  if xrGameDllType()=XRGAME_1602 then begin
    srcEAXReturnerInjection.Create(pointer(xrGame+$3b3bca), @GetTranslatedMapname, 10, [], false, false);
  end;

  //в gcd_authenticate_user правим возможность игры нескольким игрокам с одним ключом на сервере...
  srcInjectionWithConditionalJump.Create(pointer(xrGameSpy+$9372),@IsSameCdKeyValidated,5,[],pointer(xrGameSpy+$93bd), JUMP_IF_TRUE, true, false);

  //...и отключаем отправку пакета с запросом
  srcInjectionWithConditionalJump.Create(pointer(xrGameSpy+$944e),@OnAuthSend,8,[F_PUSH_ESI],pointer(xrGameSpy+$9461), JUMP_IF_TRUE, true, false);

  result:=true;
end;

function PatchChat():boolean;
begin
  result:=false;

  //обработчик сырых данных в xrServer::OnMessage, правит гадости и решает, отправлять пакет дальше или отбросить от греха подальше
  if xrGameDllType()=XRGAME_1602 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$34d83f),@OnChatMessage_ValidateAndChange,5,[F_PUSH_ESI, F_PUSH_EDI, F_PUSH_EAX],pointer(xrGame+$34d84d), JUMP_IF_FALSE, false, false);
  end;

  //делаем возможность отправлять в чат сообщения от имени мертвых и наблюдателей
  if FZConfigMgr.Get.GetBool('unlimited_chat_for_dead', true) then begin
    if xrGameDllType()=XRGAME_1602 then begin
      srcKit.Get.nop_code(pointer(xrGame+$34bb49), 27);
    end;
  end;

  {//обработчик ора в рацию в game_sv_mp::OnEvent;
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30AF59),@OnPlayerSpeechMessage,6,[F_PUSH_EBX, F_PUSH_EDX, F_PUSH_ECX],pointer(xrGame+$30AF5F), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$320DA9),@OnPlayerSpeechMessage,6,[F_PUSH_EBX, F_PUSH_EDX, F_PUSH_ECX],pointer(xrGame+$320DAF), JUMP_IF_FALSE, true, false);
  end;


  //меняем ник серверадмина в game_sv_mp::SvSendChatMessage
  if xrGameDllType()=XRGAME_SV_1510 then begin
    if not srcKit.Get.CopyBuf(@ServerAdminName, pointer(xrGame+$30FFB3), sizeof(pointer)) then exit;
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    if not srcKit.Get.CopyBuf(@ServerAdminName, pointer(xrGame+$325E53), sizeof(pointer)) then exit;
  end;


  //в game_sv_mp::SvSendChatMessage добавим вызов логирования чата
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$30FF80), @ControlGUI.AddChatMessageToList, 5, [F_PUSHCONST+0, F_RMEM+F_PUSH_ESP+$8], true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$325E20), @ControlGUI.AddChatMessageToList, 5, [F_PUSHCONST+0, F_RMEM+F_PUSH_ESP+$8], true, false);
  end;  }

  result:=true;
end;

function PatchPlayers():boolean;
begin
  //к каждому PlayerState у нас должен быть пристегнут буфер, в который сливается ФЗшная стата игрока
  //Пропишем сюда работу с ним.
  if xrGameDllType()=XRGAME_1602 then begin
    srcBaseInjection.Create(pointer(xrGame+$3507af), @FromPlayerStateConstructor, 6, [F_PUSH_ESI], false, false);
    srcBaseInjection.Create(pointer(xrGame+$3504b7), @FromPlayerStateClear, 6, [F_PUSH_ECX], false, false);
    srcBaseInjection.Create(pointer(xrGame+$350600), @FromPlayerStateDestructor, 7, [F_PUSH_ECX], false, false);
  end;

  result:=true;
end;

function PatchShop():boolean;
begin
  //[bug] баг с пролетом мимо магазина при спавне из-за последовательного получения нескольких сигналов готовности игрока GAME_EVENT_PLAYER_READY (в game_sv_mp::OnEvent)
  if xrGameDllType()=XRGAME_1602 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$38c262),@CheckPlayerReadySignalValidity,6,[F_PUSH_EAX], pointer(xrGame+$38c270), JUMP_IF_FALSE, true, false);
  end;

  result:=true;
end;

function Init():boolean; stdcall;
var
  tmp:cardinal;
begin
  result:=false;

  if not PatchVoting() then exit;
  if not PatchGameSpy() then exit;
  if not PatchChat() then exit;
  if not PatchPlayers() then exit;
  if not PatchBanSystem() then exit;
  if not PatchShop() then exit;

  //[bug]защита от stalkazz - в xrGameSpyServer::OnMessage убеждаемся, что длина строки в пакете M_GAMESPY_CDKEY_VALIDATION_CHALLENGE_RESPOND меньше, чем размер буфера
  if xrGameDllType()=XRGAME_1602 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$438f92),@CheckIfPacketZStringIsLesserThanWithDisconnect,7,[F_PUSH_EBX, F_PUSHCONST+128, F_PUSH_ESI, F_PUSHCONST+$16, F_PUSHCONST+1], pointer(xrGame+$438f85), JUMP_IF_FALSE, true, false);
  end;

  //Отсылка пакета загрузки отсутствующей карты клиентом
  if xrGameDllType()=XRGAME_1602 then begin
    srcBaseInjection.Create(pointer(xrGame+$43c0ef),@OnAttachNewClient,5,[F_PUSH_ESI, F_PUSH_EDI], true, false);
  end;

  //В xrServer::Connect нам надо получить обновленное имя карты
  if xrGameDllType()=XRGAME_1602 then begin
    srcBaseInjection.Create(pointer(xrGame+$43c6f1),@xrServer__Connect_updatemapname,5,[F_PUSH_EDI], false, false);
  end;

  //Загрузка использованных ранее имени карты и режима
  if xrGameDllType()=XRGAME_1602 then begin
    srcBaseInjection.Create(pointer(xrGame+$24c208),@CLevel__net_Start_overridelevelgametype,7,[], false, false);
  end;

  //[bug] При смерти игрока со слишком большим числом предметов в инвентаре в game_sv_xxx::OnDetach происходит переполнение EventPack. Решение - разбивать на несколько пакетов и отправлять их по мере заполнения
  if xrGameDllType()=XRGAME_1602 then begin
    //game_sv_Deathmatch::OnDetach
    srcBaseInjection.Create(pointer(xrGame+$384240),@SplitEventPackPackets,8,[F_PUSH_ESP+$48], true, false);
    //game_sv_TeamDeathmatch::OnDetachItem
    srcBaseInjection.Create(pointer(xrGame+$389ca0),@SplitEventPackPackets,7,[F_PUSH_ESP+$40], true, false);
    //game_sv_CaptureTheArtefact::OnDetachItem
    srcBaseInjection.Create(pointer(xrGame+$395ba0),@SplitEventPackPackets,7,[F_PUSH_ESP+$40], true, false);
  end;

  //[bug] При попытке подобрать рюкзак со слишком большим числом предметов в game_sv_xxx::OnTouch происходит переполнение EventPack. Решение - разбивать на несколько пакетов и отправлять их по мере заполнения
  if xrGameDllType()=XRGAME_1602 then begin
    //game_sv_Deathmatch::OnTouch
    srcBaseInjection.Create(pointer(xrGame+$382f30),@SplitEventPackPackets,7,[F_PUSH_ESP+$c054], true, false);
    //game_sv_TeamDeathmatch::OnTouchItem / game_sv_CaptureTheArtefact::OnTouchItem
    srcBaseInjection.Create(pointer(xrGame+$3890f0),@SplitEventPackPackets,7,[F_PUSH_ESP+$8038], true, false);
  end;

  //[bug] При удалении рюкзака со слишком большим числом предметов в xrServer::Process_event_destroy происходит переполнение pEventPack. Решение - разбивать на несколько пакетов и отправлять их по мере заполнения
  if xrGameDllType()=XRGAME_1602 then begin
    srcBaseInjection.Create(pointer(xrGame+$4379c5),@SplitEventPackPackets,7,[F_PUSH_ESI], true, false);
  end;

  result:=true;
end;

//xrgame+38f610 - game_sv_mp::Player_AddBonusMoney
//xrgame+23be80 - CLevel::ClientSendProfileData
//xrgame+34f8f0 - game_PlayerState::net_Export

end.

