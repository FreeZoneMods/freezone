unit fz_injections;
{$mode delphi}

interface
function Init():boolean; stdcall;

implementation
uses srcBase, basedefs, GameSpy, srcInjections, Voting, Console, BasicProtection, Chat, Players, ConfigMgr, LogMgr, Bans{, PacketFilter}, PlayerSkins, UpdateRate, ControlGUI, Servers, ServerStuff, misc_stuff, SACE_hacks, xrstrings, ge_filter;

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
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$307AC7), @xrServer__ProcessClientDigest_ProtectFromKeyChange, 5,[F_RMEM+F_PUSH_EBP+$0C, F_PUSH_ECX, F_PUSH_ESI], false, false);
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$307B37),@xrServer__ProcessClientDigest_CheckAdditionalRejectingConditions,6,[F_PUSH_EDI],pointer(xrGame+$307B4C), JUMP_IF_FALSE, false, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$31D947), @xrServer__ProcessClientDigest_ProtectFromKeyChange, 5,[F_RMEM+F_PUSH_EBP+$0C, F_PUSH_ECX, F_PUSH_ESI], false, false);
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$31D9B7),@xrServer__ProcessClientDigest_CheckAdditionalRejectingConditions,6,[F_PUSH_EDI],pointer(xrGame+$31D9CC), JUMP_IF_FALSE, false, false);
  end;

  //Пропатчимся на бан подсетей
  srcInjectionWithConditionalJump.Create(pointer(xrNetServer+$AE6F),@IPureServer__net_Handler_SubnetBans,5,[F_RMEM+F_PUSH_ESP+$0C],pointer(xrNetServer+$AE7F), JUMP_IF_TRUE, true, False);

  //Сообщение о том, что IP забанен в игровом банлисте
  srcBaseInjection.Create(pointer(xrNetServer+$AE7F),@IPureServer__net_Handler_OnBannedByGameIpFound,7,[F_RMEM+F_PUSH_ESP+$0C], true, False);

  //заблокируем бан пустого ключа
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30950E),@cdkey_ban_list__ban_player_checkemptykey,9,[F_PUSH_ESI],pointer(xrGame+$30951E), JUMP_IF_TRUE, true, true);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$31F34E),@cdkey_ban_list__ban_player_checkemptykey,9,[F_PUSH_ESI],pointer(xrGame+$31F35E), JUMP_IF_TRUE, true, true);
  end;
  result:=true;
end;

function PatchVoting():boolean;
begin
  result:=false;
  //патчи голосований
  //подмена буфера со всеми возможными голосованиями во всех местах движка (благо, юзаются только в game_sv_mp::OnVoteStart)
  if xrGameDllType()=XRGAME_SV_1510 then begin
    if not PatchVoteCommandsArrayPtrAtAddr(pointer(xrGame+$30C9A6), 4) then exit;
    if not PatchVoteCommandsArrayPtrAtAddr(pointer(xrGame+$30C9B2), 0) then exit;
    if not PatchVoteCommandsArrayPtrAtAddr(pointer(xrGame+$30C9D3), 4) then exit;
    if not PatchVoteCommandsArrayPtrAtAddr(pointer(xrGame+$30C9F2), 8) then exit;
    if not PatchVoteCommandsArrayPtrAtAddr(pointer(xrGame+$30CA76), 0) then exit;
    if not PatchVoteCommandsArrayPtrAtAddr(pointer(xrGame+$30CAE3), 4) then exit;
    if not PatchVoteCommandsArrayPtrAtAddr(pointer(xrGame+$30CB01), 0) then exit;
    if not PatchVoteCommandsArrayPtrAtAddr(pointer(xrGame+$30CB27), 0) then exit;
    if not PatchVoteCommandsArrayPtrAtAddr(pointer(xrGame+$30CB74), 4) then exit;
    if not PatchVoteCommandsArrayPtrAtAddr(pointer(xrGame+$30CBCD), 0) then exit;
    if not PatchVoteCommandsArrayPtrAtAddr(pointer(xrGame+$30CBFA), 0) then exit;
    if not PatchVoteCommandsArrayPtrAtAddr(pointer(xrGame+$30CC52), 4) then exit;
    if not PatchVoteCommandsArrayPtrAtAddr(pointer(xrGame+$30CC72), 0) then exit;
    if not PatchVoteCommandsArrayPtrAtAddr(pointer(xrGame+$30CD12), 4) then exit;
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    if not PatchVoteCommandsArrayPtrAtAddr(pointer(xrGame+$322846), 4) then exit;
    if not PatchVoteCommandsArrayPtrAtAddr(pointer(xrGame+$322852), 0) then exit;
    if not PatchVoteCommandsArrayPtrAtAddr(pointer(xrGame+$322873), 4) then exit;
    if not PatchVoteCommandsArrayPtrAtAddr(pointer(xrGame+$322892), 8) then exit;
    if not PatchVoteCommandsArrayPtrAtAddr(pointer(xrGame+$322916), 0) then exit;
    if not PatchVoteCommandsArrayPtrAtAddr(pointer(xrGame+$322983), 4) then exit;
    if not PatchVoteCommandsArrayPtrAtAddr(pointer(xrGame+$3229A1), 0) then exit;
    if not PatchVoteCommandsArrayPtrAtAddr(pointer(xrGame+$3229C7), 0) then exit;
    if not PatchVoteCommandsArrayPtrAtAddr(pointer(xrGame+$322A14), 4) then exit;
    if not PatchVoteCommandsArrayPtrAtAddr(pointer(xrGame+$322A6D), 0) then exit;
    if not PatchVoteCommandsArrayPtrAtAddr(pointer(xrGame+$322A9A), 0) then exit;
    if not PatchVoteCommandsArrayPtrAtAddr(pointer(xrGame+$322AF2), 4) then exit;
    if not PatchVoteCommandsArrayPtrAtAddr(pointer(xrGame+$322B12), 0) then exit;
    if not PatchVoteCommandsArrayPtrAtAddr(pointer(xrGame+$322BB2), 4) then exit;
  end;

  //проверка на возможность начать голосование в game_sv_mp::OnEvent
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30AE54),@CanSafeStartVoting,5,[F_PUSH_EBX, F_PUSH_ECX, F_RMEM+F_PUSH_ESP+$424],pointer(xrGame+$30B05E), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$320CA4),@CanSafeStartVoting,5,[F_PUSH_EBX, F_PUSH_ECX, F_RMEM+F_PUSH_ESP+$424],pointer(xrGame+$320EAE), JUMP_IF_FALSE, true, false);
  end;

  //Изменим sv_changelevel на sv_changelevelgametype если в настройках явно задан тип игры для карты (game_sv_mp::OnVoteStart)
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$30cd63), @ProvideDefaultGameTypeForMapchangeVoting, 6,[], true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$322C03), @ProvideDefaultGameTypeForMapchangeVoting, 6,[], true, false);
  end;

  //[bug]исправление логики подсчета голосов в void game_sv_mp::UpdateVote(); по-хорошему, надо ее полностью переписать, но накостылим, имея стандартное
  //обычное прекращение голосования
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30D059),@IsVoteSuccess,94,[F_RMEM+F_PUSH_ESP+$1C, F_RMEM+F_PUSH_ESP+$20, F_RMEM+F_PUSH_ESP+$24],pointer(xrGame+$30D04F), JUMP_IF_TRUE, true, true);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$322EF9),@IsVoteSuccess,94,[F_RMEM+F_PUSH_ESP+$1C, F_RMEM+F_PUSH_ESP+$20, F_RMEM+F_PUSH_ESP+$24],pointer(xrGame+$322EEF), JUMP_IF_TRUE, true, true);
  end;

  //досрочное прекращение голосования
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30D041),@IsVoteEarlyFail,5,[F_PUSH_EBP, F_RMEM+F_PUSH_ESP+$1C, F_RMEM+F_PUSH_ESP+$20, F_RMEM+F_PUSH_ESP+$24],pointer(xrGame+$30D0B7), JUMP_IF_TRUE, true, true);
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30D046),@IsVoteEarlySuccess,9,[F_PUSH_EBP, F_RMEM+F_PUSH_ESP+$1C, F_RMEM+F_PUSH_ESP+$20, F_RMEM+F_PUSH_ESP+$24],pointer(xrGame+$30D1BC), JUMP_IF_FALSE, true, true);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$322EE1),@IsVoteEarlyFail,5,[F_PUSH_EBP, F_RMEM+F_PUSH_ESP+$1C, F_RMEM+F_PUSH_ESP+$20, F_RMEM+F_PUSH_ESP+$24],pointer(xrGame+$322F57), JUMP_IF_TRUE, true, true);
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$322EE6),@IsVoteEarlySuccess,9,[F_PUSH_EBP, F_RMEM+F_PUSH_ESP+$1C, F_RMEM+F_PUSH_ESP+$20, F_RMEM+F_PUSH_ESP+$24],pointer(xrGame+$32305C), JUMP_IF_FALSE, true, true);
  end;

  //[bug] в SearcherClientByName::operator() исправляем сравнение имен игроков
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcEAXReturnerInjection.Create(pointer(xrGame+$2B2E38),@CarefullyComparePlayerNames,35,[F_PUSH_ECX, F_PUSH_EAX], true, true);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcEAXReturnerInjection.Create(pointer(xrGame+$2C5C38),@CarefullyComparePlayerNames,35,[F_PUSH_ECX, F_PUSH_EAX], true, true);
  end;

  //[bug] если при старте голосования на кик/бан задать несуществующего игрока, то строка с консольной командой, выполняющейся при успехе голосования, не обновится. Чревато крешем сервера! (голосования до этого могло и не быть!)
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30CCE6),@OnVoteStartIncorrectPlayerName,12,[F_PUSH_EBX],pointer(xrGame+$30CE93), JUMP_IF_FALSE, true, true);
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30CC5C),@OnVoteStartIncorrectPlayerName,12,[F_PUSH_EBX],pointer(xrGame+$30CE93), JUMP_IF_FALSE, true, true);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$322B86),@OnVoteStartIncorrectPlayerName,12,[F_PUSH_EBX],pointer(xrGame+$322D33), JUMP_IF_FALSE, true, true);
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$322AFC),@OnVoteStartIncorrectPlayerName,12,[F_PUSH_EBX],pointer(xrGame+$322D33), JUMP_IF_FALSE, true, true);
  end;

  //обработка нестандартных голосований+ FZ'шный транслятор строк
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcKit.nop_code(pointer(xrGame+$30CDC7), 2);
    srcBaseInjection.Create(pointer(xrGame+$30CDCF), @OnVoteStart, 13,[F_PUSH_EBX, F_RMEM+F_PUSH_EBP+$C, F_RMEM+F_PUSH_EBP+8, F_PUSH_EAX],true, true);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcKit.nop_code(pointer(xrGame+$322C67), 2);
    srcBaseInjection.Create(pointer(xrGame+$322C6F), @OnVoteStart, 13,[F_PUSH_EBX, F_RMEM+F_PUSH_EBP+$C, F_RMEM+F_PUSH_EBP+8, F_PUSH_EAX],true, true);
  end;

  //блокировка плохих голосовальщиков (game_sv_mp::OnEvent)
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30AEA1),@OnVote,6,[F_PUSH_EBX, F_RMEM+F_PUSH_ESP+$424, F_PUSHCONST+1],pointer(xrGame+$30AEAC), JUMP_IF_FALSE, true, false);
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30AED5),@OnVote,6,[F_PUSH_EBX, F_RMEM+F_PUSH_ESP+$424, F_PUSHCONST+0],pointer(xrGame+$30AEE0), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$320CF1),@OnVote,6,[F_PUSH_EBX, F_RMEM+F_PUSH_ESP+$424, F_PUSHCONST+1],pointer(xrGame+$320CFC), JUMP_IF_FALSE, true, false);
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$320D25),@OnVote,6,[F_PUSH_EBX, F_RMEM+F_PUSH_ESP+$424, F_PUSHCONST+0],pointer(xrGame+$320D30), JUMP_IF_FALSE, true, false);
  end;

  //Не даем брать ники в другой раскладке
  //[bug] игра сначала сравнивает, а потом - меняет недопустмые символы в нике
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcEAXReturnerInjection.Create(pointer(xrGame+$2F48F7),@IterateAndComparePlayersNames,5,[F_PUSH_EAX, F_RMEM+F_PUSH_ESP+0, F_RMEM+F_PUSH_ESP+8, F_RMEM+F_PUSH_ESP+4], true, true, 0);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcEAXReturnerInjection.Create(pointer(xrGame+$3098A7),@IterateAndComparePlayersNames,5,[F_PUSH_EAX, F_RMEM+F_PUSH_ESP+0, F_RMEM+F_PUSH_ESP+8, F_RMEM+F_PUSH_ESP+4], true, true, 0);
  end;

  result:=true;
end;


function PatchGameSpy():boolean;
begin
  //Меняем имя сервера (в callback_serverkey)
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$321DCD), @WriteHostnameToClientRequest, 7, [F_PUSH_EAX, F_PUSH_ECX, F_PUSH_EDX], true, true);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$337F3D), @WriteHostnameToClientRequest, 7, [F_PUSH_EAX, F_PUSH_ECX, F_PUSH_EDX], true, true);
  end;

  //Переводим имя карты на человеческий язык (в callback_serverkey)
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$321E07), @WriteMapnameToClientRequest, 7, [F_PUSH_EAX, F_PUSH_ECX, F_PUSH_EDX], true, true);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$337F77), @WriteMapnameToClientRequest, 7, [F_PUSH_EAX, F_PUSH_ECX, F_PUSH_EDX], true, true);
  end;

  //в gcd_authenticate_user правим возможность игры нескольким игрокам с одним ключом на сервере...
  srcInjectionWithConditionalJump.Create(pointer(xrGameSpy+$B1E2),@IsSameCdKeyValidated,5,[],pointer(xrGameSpy+$B22D), JUMP_IF_TRUE, true, false);

  //...и отключаем отправку пакета с запросом
  srcInjectionWithConditionalJump.Create(pointer(xrGameSpy+$B2B7),@OnAuthSend,8,[F_PUSH_ESI],pointer(xrGameSpy+$B2CA), JUMP_IF_TRUE, true, false);

  result:=true;
end;

function PatchChat():boolean;
begin
  result:=false;

  //обработчик сырых данных в xrServer::OnMessage, правит гадости и решает, отправлять пакет дальше или отбросить от греха подальше
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2C8190),@OnChatMessage_ValidateAndChange,6,[F_PUSH_EBP, F_PUSH_EDI, F_PUSH_EAX],pointer(xrGame+$2C819B), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2DD200),@OnChatMessage_ValidateAndChange,6,[F_PUSH_EBP, F_PUSH_EDI, F_PUSH_EAX],pointer(xrGame+$2DD20B), JUMP_IF_FALSE, true, false);
  end;

  //делаем возможность отправлять в чат сообщения от имени мертвых и наблюдателей
  if FZConfigMgr.Get.GetBool('unlimited_chat_for_dead', true) then begin
    if xrGameDllType()=XRGAME_SV_1510 then begin
      srcKit.Get.nop_code(pointer(xrGame+$2CA859), 25);
    end else if xrGameDllType()=XRGAME_CL_1510 then begin
       srcKit.Get.nop_code(pointer(xrGame+$2DF7B9), 25);
    end;
  end;

  //обработчик ора в рацию в game_sv_mp::OnEvent;
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
  end;

  result:=true;
end;

function PatchConsole():boolean;
begin
  c_sv_fraglimit.max:=100000;
  c_sv_timelimit.max:=100000;
  c_sv_vote_enabled.max:=$FFFF;
  result:=true;
end;

function IsArgNull(arg:pointer):boolean; stdcall;
begin
  result:=(arg = nil);
end;

function AlwaysTrue():boolean; stdcall;
begin
  result:=true;
end;

function PatchPlayers():boolean;
begin

  //к каждому PlayerState у нас должен быть пристегнут буфер, в который сливается ФЗшная стата игрока
  //Пропишем сюда работу с ним.
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$2CB170), @FromPlayerStateConstructor, 6, [F_PUSH_EDI], false, false);
    srcBaseInjection.Create(pointer(xrGame+$2CB187), @FromPlayerStateClear, 6, [F_PUSH_ECX], false, false);
    srcBaseInjection.Create(pointer(xrGame+$2CB270), @FromPlayerStateDestructor, 6, [F_PUSH_ESI], false, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$2E0180), @FromPlayerStateConstructor, 6, [F_PUSH_EDI], false, false);
    srcBaseInjection.Create(pointer(xrGame+$2E0197), @FromPlayerStateClear, 6, [F_PUSH_ECX], false, false);
    srcBaseInjection.Create(pointer(xrGame+$2E0280), @FromPlayerStateDestructor, 6, [F_PUSH_ESI], false, false);
  end;

  //[bug] Когда игрок умирает или получает хит (например, от кровотечения) - его клиент отправляет нам сообщение об этом.
  //Но, вот незадача, в game_sv_mp::SendPlayerKilledMessage, CActor::OnHitHealthLoss, CActor::OnCriticalHitHealthLoss,
  //откуда клиент и кидает сообщения, в случае отсутсвия киллера или оружия в ИД попадает 0.
  //Общепринятым же несуществующим ИД считается -1. Отсюда проблемы - убить может НЕ ТОТ объект
  //Например, если этот ИД совпадет с объектом серверного клиента - получим вылет.
  //Решение - резервируем нулевой ИД сразу же при старте (xrGameSpyServer::xrGameSpyServer), чтобы больше он никому не достался.
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$38C164), @xrGameSpyServer_constructor_reserve_zerogameid, 6, [F_PUSH_ESI], false, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$3A2674), @xrGameSpyServer_constructor_reserve_zerogameid, 6, [F_PUSH_ESI], false, false);
  end;

  //Блокировка самостоятельной смены команды игроком
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30e239),@game_sv_mp__OnPlayerGameMenu_isteamchangeblocked,6,[F_RMEM+F_PUSH_ESP+$10, F_PUSH_EDI], pointer(xrGame+$30e24b), JUMP_IF_TRUE, false, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$3240d9),@game_sv_mp__OnPlayerGameMenu_isteamchangeblocked,6,[F_RMEM+F_PUSH_ESP+$10, F_PUSH_EDI], pointer(xrGame+$3240eb), JUMP_IF_TRUE, false, false);
  end;

  //Обработка тимкиллов
  if xrGameDllType()=XRGAME_SV_1510 then begin
    //game_sv_TeamDeathmatch::OnPlayerKillPlayer
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$308604),@OnTeamKill, 44,[F_PUSH_ESI, F_PUSH_EBX], pointer(xrGame+$3086e1), JUMP_IF_FALSE, false, true);
    //game_sv_CaptureTheArtefact::OnKillResult (берем из стекового фрейма вышележащей функции, так как аргумент затирается)
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$3177ec),@OnTeamKill, 38,[F_PUSH_ESI, F_RMEM+F_PUSH_EBP+$10], pointer(xrGame+$3178ac), JUMP_IF_FALSE, false, true);
    //В game_sv_TeamDeathmatch::OnPlayerConnectFinished убираем обнуление m_iTeamKills в стате игрока
    srcKit.Get().nop_code(pointer(xrGame+$308324), 6);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    //game_sv_TeamDeathmatch::OnPlayerKillPlayer
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$31e484),@OnTeamKill, 44,[F_PUSH_ESI, F_PUSH_EBX], pointer(xrGame+$31e561), JUMP_IF_FALSE, false, true);
    //game_sv_CaptureTheArtefact::OnKillResult (берем из стекового фрейма вышележащей функции, так как аргумент затирается)
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$32d64c),@OnTeamKill, 38,[F_PUSH_ESI, F_RMEM+F_PUSH_EBP+$10], pointer(xrGame+$32d70c), JUMP_IF_FALSE, false, true);
    //В game_sv_TeamDeathmatch::OnPlayerConnectFinished убираем обнуление m_iTeamKills в стате игрока
    srcKit.Get().nop_code(pointer(xrGame+$31e1a4), 6);
  end;

  //[bug] баг - когда игрок должен быть неуязвим (или защищен от огня союзников), то иногда урон все-таки проходит.
  //Происходит это тогда, когда игрок в броне. Причина, судя по всему, в том, что параметры хита armor_piercing и power_critical не обнуляются в обработчике хитов в геймах,
  //что ведет к инициированию урона ими.
  if xrGameDllType()=XRGAME_SV_1510 then begin
    //game_sv_TeamDeathmatch::OnPlayerHitPlayer_Case - огонь союзников (friendly fire)
    srcBaseInjection.Create(pointer(xrGame+$30889f), @OnTeamHit_FriendlyFire, 82, [F_PUSH_EAX, F_PUSH_EBX, F_PUSH_EDI], false, true);
    //game_sv_CaptureTheArtefact::OnPlayerHitPlayer_Case - огонь союзников (friendly fire)
    srcBaseInjection.Create(pointer(xrGame+$317e07), @OnTeamHit_FriendlyFire, 46, [F_PUSH_EAX, F_PUSH_ECX, F_PUSH_ESI], false, true);
    //game_sv_TeamDeathmatch::OnPlayerHitPlayer_Case - обработка попаданий в неуязвимых игроков (оптимизация компилятора - заинлайнен метод из game_sv_Deathmatch)
    srcBaseInjection.Create(pointer(xrGame+$308902), @OnHitInvincible, 13, [F_PUSH_EDI], false, true);
    //game_sv_Deathmatch::OnPlayerHitPlayer_Case - обработка попаданий в неуязвимых игроков
    srcBaseInjection.Create(pointer(xrGame+$3014c9), @OnHitInvincible, 13, [F_PUSH_EAX], false, true);
    //game_sv_CaptureTheArtefact::OnPlayerHitPlayer_Case - обработка попаданий в неуязвимых игроков
    srcBaseInjection.Create(pointer(xrGame+$317e3f), @OnHitInvincible, 13, [F_PUSH_ESI], false, true);
    //game_sv_ArtefactHunt::OnPlayerHitPlayer_Case - обработка попаданий в неуязвимых игроков
    srcBaseInjection.Create(pointer(xrGame+$2FDEFB), @OnHitInvincible, 13, [F_PUSH_EDI], false, true);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    //game_sv_TeamDeathmatch::OnPlayerHitPlayer_Case - огонь союзников (friendly fire)
    srcBaseInjection.Create(pointer(xrGame+$31e71f), @OnTeamHit_FriendlyFire, 82, [F_PUSH_EAX, F_PUSH_EBX, F_PUSH_EDI], false, true);
    //game_sv_CaptureTheArtefact::OnPlayerHitPlayer_Case - огонь союзников (friendly fire)
    srcBaseInjection.Create(pointer(xrGame+$32DC67), @OnTeamHit_FriendlyFire, 46, [F_PUSH_EAX, F_PUSH_ECX, F_PUSH_ESI], false, true);
    //game_sv_TeamDeathmatch::OnPlayerHitPlayer_Case - обработка попаданий в неуязвимых игроков (оптимизация компилятора - заинлайнен метод из game_sv_Deathmatch)
    srcBaseInjection.Create(pointer(xrGame+$31e782), @OnHitInvincible, 13, [F_PUSH_EDI], false, true);
    //game_sv_Deathmatch::OnPlayerHitPlayer_Case - обработка попаданий в неуязвимых игроков
    srcBaseInjection.Create(pointer(xrGame+$316629), @OnHitInvincible, 13, [F_PUSH_EAX], false, true);
    //game_sv_CaptureTheArtefact::OnPlayerHitPlayer_Case - обработка попаданий в неуязвимых игроков
    srcBaseInjection.Create(pointer(xrGame+$32DC9F), @OnHitInvincible, 13, [F_PUSH_ESI], false, true);
    //game_sv_ArtefactHunt::OnPlayerHitPlayer_Case - обработка попаданий в неуязвимых игроков
    srcBaseInjection.Create(pointer(xrGame+$312FDB), @OnHitInvincible, 13, [F_PUSH_EDI], false, true);
  end;

  //Скорость роста опыта
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$30e7b0), @game_sv_mp__Player_AddExperience_expspeed, 5, [F_PUSH_ESP+$8], true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$324650), @game_sv_mp__Player_AddExperience_expspeed, 5, [F_PUSH_ESP+$8], true, false);
  end;

  //неуязвимость игроков
  if xrGameDllType()=XRGAME_SV_1510 then begin
    //в operator() из функтора в game_sv_Deathmatch::check_InvinciblePlayers пропускаем стандартные проверки на неуязвимость, если она контролируется нами
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$304DD8),@IsInvincibilityControlledByFZ, 6,[F_PUSH_ESI], pointer(xrGame+$304E02), JUMP_IF_TRUE, true, false);
    //в game_sv_ArtefactHunt::OnPlayerHitPlayer_Case добавляем проверку на отключенную неуязвимость, чтобы хит не обнулялся на базах
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2fdee3),@IsInvincibilityControlledByFZ, 6,[F_PUSH_EBX], pointer(xrGame+$2fdf08), JUMP_IF_TRUE, true, false);
    //проверка на необходимость сбросить неуязвимость в game_sv_Deathmatch::OnPlayerFire (в CTA выстрел и так не сбрасывает флаг неуязвимости)
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$303ca1),@IsInvinciblePersistAfterShot, 6,[F_PUSH_EAX], pointer(xrGame+$303ccf), JUMP_IF_TRUE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    //в operator() из функтора в game_sv_Deathmatch::check_InvinciblePlayers пропускаем стандартные проверки на неуязвимость, если она контролируется нами
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$319f38),@IsInvincibilityControlledByFZ, 6,[F_PUSH_ESI], pointer(xrGame+$319f62), JUMP_IF_TRUE, true, false);
    //в game_sv_ArtefactHunt::OnPlayerHitPlayer_Case добавляем проверку на отключенную неуязвимость, чтобы хит не обнулялся на базах
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$312fc3),@IsInvincibilityControlledByFZ, 6,[F_PUSH_EBX], pointer(xrGame+$312fe8), JUMP_IF_TRUE, true, false);
    //проверка на необходимость сбросить неуязвимость в game_sv_Deathmatch::OnPlayerFire (в CTA выстрел и так не сбрасывает флаг неуязвимости)
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$318e01),@IsInvinciblePersistAfterShot, 6,[F_PUSH_EAX], pointer(xrGame+$318e2f), JUMP_IF_TRUE, true, false);
  end;

  result:=true;
end;

function PatchSaceFakers():boolean;
begin
  //Проверка на то, что DPN_MSGID_ENUM_HOSTS_QUERY с ToConnect не был отправлен SACE ( в IPureServer::net_Handler)
  srcInjectionWithConditionalJump.Create(pointer(xrNetServer+$AC60),@IPureServer__net_Handler_isToConnectsentbysace,15,[F_PUSH_ECX], pointer(xrNetServer+$AE8D), JUMP_IF_TRUE, true, false);
  result:=true;
end;

function PatchShop():boolean;
begin
  //[bug] баг с пролетом мимо магазина при спавне из-за последовательного получения нескольких сигналов готовности игрока GAME_EVENT_PLAYER_READY (в game_sv_mp::OnEvent)
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30ADE2),@CheckPlayerReadySignalValidity,6,[F_PUSH_EAX], pointer(xrGame+$30ADF0), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$320C32),@CheckPlayerReadySignalValidity,6,[F_PUSH_EAX], pointer(xrGame+$320C40), JUMP_IF_FALSE, true, false);
  end;

  //В ЧН по умолчанию все предметы в инвентаре удаляются и полностью перезакупаются. Проблема в том, что удаление происходит перед вычитыванием новой конфигурации закупа из пакета.
  //Сначала выпилим вызовы DestroyAllPlayerItems из OnPlayerBuyFinished
  if xrGameDllType()=XRGAME_SV_1510 then begin
    //DM
    srcKit.Get().nop_code(pointer(xrGame+$300AA3), 5);
    //CTA
    srcKit.Get().nop_code(pointer(xrGame+$31bfd6), 5);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    //DM
    srcKit.Get().nop_code(pointer(xrGame+$315c03), 5);
    //CTA
    srcKit.Get().nop_code(pointer(xrGame+$331df6), 5);
  end;

  //Теперь вызовем удаление всего из рюкзака после того, как вектор желаемых предметов считан (перед вызовом SpawnWeaponsForActor). Также запомним, что именно удалилось.
  if xrGameDllType()=XRGAME_SV_1510 then begin
    //DM
    srcBaseInjection.Create(pointer(xrGame+$300B71), @DestroyAllItemsFromPlayersInventoryDeforeBuying, 6, [F_PUSH_ESI, F_RMEM+F_PUSH_ESP+$34], false, false );
    //CTA
    srcBaseInjection.Create(pointer(xrGame+$31c091), @DestroyAllItemsFromPlayersInventoryDeforeBuying, 7, [F_PUSH_ESI, F_RMEM+F_PUSH_ESP+$34], false, false );
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    //DM
    srcBaseInjection.Create(pointer(xrGame+$315CD1), @DestroyAllItemsFromPlayersInventoryDeforeBuying, 6, [F_PUSH_ESI, F_RMEM+F_PUSH_ESP+$34], false, false );
    //CTA
    srcBaseInjection.Create(pointer(xrGame+$331eb1), @DestroyAllItemsFromPlayersInventoryDeforeBuying, 7, [F_PUSH_ESI, F_RMEM+F_PUSH_ESP+$34], false, false );
  end;

  //[bug] При добавлении крякером дополнительного предмета в список закупа едут индексы, и крякер может либо шопхакнуться, либо завалить сервак. Патчим в game_sv_xxx::SpawnWeaponsForActor
  if xrGameDllType()=XRGAME_SV_1510 then begin
    //DM
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$300C43),@BeforeSpawnBoughtItems_DM,6,[F_PUSH_ECX, F_PUSH_ESI], pointer(xrGame+$300D02), JUMP_IF_FALSE, true, false);
    //CTA
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$3175F7),@BeforeSpawnBoughtItems_CTA,6,[F_PUSH_ECX, F_PUSH_ESI], pointer(xrGame+$3176BE), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    //DM
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$315DA3),@BeforeSpawnBoughtItems_DM,6,[F_PUSH_ECX, F_PUSH_ESI], pointer(xrGame+$315E62), JUMP_IF_FALSE, true, false);
    //CTA
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$32D457),@BeforeSpawnBoughtItems_CTA,6,[F_PUSH_ECX, F_PUSH_ESI], pointer(xrGame+$32D51E), JUMP_IF_FALSE, true, false);
  end;

  //[bug] если исправить game_cl_xxx::CanCallBuyMenu на постоянное возвращение true, закуп становится возможен всегда и везде. Непорядок.
  //Для исправления проверяем в game_sv_xxx::OnEvent, что игрок на базе. В ДМ и ТДМ баз нет, так что и закупиться не выйдет
  if xrGameDllType()=XRGAME_SV_1510 then begin
    //DM - game_sv_Deathmatch::OnEvent
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$305f52),@CanPlayerBuyNow,6,[F_PUSH_EAX],pointer(xrGame+$305f6a), JUMP_IF_FALSE, true, false);
    //CTA - game_sv_CaptureTheArtefact::OnEvent
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$31c87a),@CanPlayerBuyNow,6,[F_PUSH_EAX],pointer(xrGame+$31c88a), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    //DM - game_sv_Deathmatch::OnEvent
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$31B0B2),@CanPlayerBuyNow,6,[F_PUSH_EAX],pointer(xrGame+$305fca), JUMP_IF_FALSE, true, false);
    //CTA - game_sv_CaptureTheArtefact::OnEvent
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$33259a),@CanPlayerBuyNow,6,[F_PUSH_EAX],pointer(xrGame+$3325aa), JUMP_IF_FALSE, true, false);
  end;

  //[bug] Оружие в ah/cta спавнится с полным магазином патронов. В случае, когда размер магазина больше либо равен размеру коробки патронов, то патроны начинают отображаться в игровом магазине! То есть, их можно продать... Необоснованное обогащение, надо отрубить спавн "бесплатных" патронов вообще, ибо нефиг.
  //Исправляем game_sv_mp::ChargeAmmo, чтобы в случае ah и cta они всегда возвращали false
  //В случае фикса на исходниках - надо переопределять метод CanChargeFreeAmmo в конкретных классах.
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30BE80),@IsSpawnFreeAmmoAllowedForGametype,5,[F_PUSH_ECX], pointer(xrGame+$30BE93), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$321CD0),@IsSpawnFreeAmmoAllowedForGametype,5,[F_PUSH_ECX], pointer(xrGame+$321ce3), JUMP_IF_FALSE, true, false);
  end;

  //[bug] Когда игрок в AH/CTA спавнится (с дефолтовым оружием калибра 9х18), то в инвентаре у него оказывается значительно меньше патронов, чем должно быть в 2х пачках
  //Дело в том, что в mp_weapon_knife прописан тот же самый тип "патронов"! И SetAmmoForWeapon, считая нож оружием, заряжает патроны и в него. Но при перезакупе после респа
  //появляется нужное число патронов, так как в этом случае нож добавляется в самый конец набора для закупа, и патронов для него игра просто не находит.
  //Решение: в game_sv_mp::SpawnWeapon4Actorперед вызовом SetAmmoForWeapon будем кастоваться не к CSE_ALifeItemWeapon, а к CSE_ALifeItemWeaponMagazined, там самым отсекая ножи.
  //Но, к сожалению, у нас не хаэкспорчена возможность каста, поэтому заюзаем проверку по CLSID.
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30C443),@IsWeaponKnife,11,[F_PUSH_ESI], pointer(xrGame+$30c473), JUMP_IF_TRUE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$322293),@IsWeaponKnife,11,[F_PUSH_ESI], pointer(xrGame+$3222c3), JUMP_IF_TRUE, true, false);
  end;

  result:=true;
end;

function PatchHits():boolean;
begin
  //[bug] в xrServer::Process_event при получении сообщения GE_HIT или GE_HIT_STATISTIC в очередь отложенных сообщений помещается нулевой ID, это не дает проверить хиты
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$38a4f3),@AssignDwordFromPtrToDwordFromPtr,6,[F_PUSH_EBP+$8, F_PUSH_ESP+$C], true, false);
    srcBaseInjection.Create(pointer(xrGame+$38a507),@AssignDwordFromPtrToDwordFromPtr,6,[F_PUSH_EBP+$8, F_PUSH_ESP+$C], true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$3a0933),@AssignDwordFromPtrToDwordFromPtr,6,[F_PUSH_EBP+$8, F_PUSH_ESP+$C], true, false);
    srcBaseInjection.Create(pointer(xrGame+$3a0947),@AssignDwordFromPtrToDwordFromPtr,6,[F_PUSH_EBP+$8, F_PUSH_ESP+$C], true, false);
  end;

  //[bug] В обработчике GAME_EVENT_ON_HIT (game_sv_GameState::OnEvent) надо проверить, что хит прилетел не для или не от серверного клиента. Ну и вообще проверить валидность/читерность хита
  //кроме того, надо убедиться в том, что ИД нанесшего хит валиден (он мог уже умереть и удалиться), иначе возможен вылет.
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2f3919),@OnGameEventDelayedHitProcessing,5,[F_PUSH_ESI, F_PUSH_EBP, F_PUSH_EBX, F_RMEM+F_PUSH_ESP+$434], pointer(xrGame+$2f3938), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$308889),@OnGameEventDelayedHitProcessing,5,[F_PUSH_ESI, F_PUSH_EBP, F_PUSH_EBX, F_RMEM+F_PUSH_ESP+$434], pointer(xrGame+$3088A8), JUMP_IF_FALSE, true, false);
  end;

  //[bug] CDestroyablePhysicsObject::Hit не готов к тому, что HDS.who будет null. Решаем просто - игнорим прилетевший хит при таком стечении обстоятельств
  //это защитит сервер от краша, но для предотвращения вылета на клиентах одного этого недостаточно, нужна предыдущая правка
  //  //(тест: отключить трупы; подойти к лампе/шкафу, взять грену, бросить ее под ноги; не дожидаясь взрыва, вбить g_kill и перейти в наблы; если лампа будет похитована, все развалится)
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$218105),@IsArgNull,7,[F_PUSH_EAX], pointer(xrGame+$21825c), JUMP_IF_TRUE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$22A735),@IsArgNull,7,[F_PUSH_EAX], pointer(xrGame+$22a88c), JUMP_IF_TRUE, true, false);
  end;

  //[bug] Аналогично, не готов к тому, что HDS.who будет null и CExplosiveItem::Hit
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$27C34B),@IsArgNull,7,[F_PUSH_EDX], pointer(xrGame+$27C352), JUMP_IF_TRUE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$28EE3B),@IsArgNull,7,[F_PUSH_EDX], pointer(xrGame+$28EE42), JUMP_IF_TRUE, true, false);
  end;

  //[bug] GAME_EVENT_PLAYER_HITTED может отсылать только локальный клиент. Проверяем в game_sv_mp::OnEvent
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30ad8f),@OnGameEventPlayerHitted,7,[F_RMEM+F_PUSH_ESP+$418, F_RMEM+F_PUSH_ESP+$424], pointer(xrGame+$30adb6), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$320bdf),@OnGameEventPlayerHitted,7,[F_RMEM+F_PUSH_ESP+$418, F_RMEM+F_PUSH_ESP+$424], pointer(xrGame+$320c06), JUMP_IF_FALSE, true, false);
  end;

  result:=true;
end;

function PatchKillsAndCorpses():boolean;
begin

  //[bug] в xrServer::Process_event при получении сообщения GE_DIE (Line 212) нет проверки на то, что c_src != null и c_src->owner != null
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$38a618),@Check_xrClientData_owner_valid,6,[F_PUSH_EDI], pointer(xrGame+$38a676), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$3a0a58),@Check_xrClientData_owner_valid,6,[F_PUSH_EDI], pointer(xrGame+$3a0ab6), JUMP_IF_FALSE, true, false);
  end;

  //[bug] GAME_EVENT_PLAYER_KILLED может отсылать только локальный клиент. Также он не может быть источником или жертвой. Проверяем в game_sv_mp::OnEvent
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30ad5c),@OnGameEventPlayerKilled,7,[F_RMEM+F_PUSH_ESP+$418, F_RMEM+F_PUSH_ESP+$424], pointer(xrGame+$30ad83), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$320bac),@OnGameEventPlayerKilled,7,[F_RMEM+F_PUSH_ESP+$418, F_RMEM+F_PUSH_ESP+$424], pointer(xrGame+$320bd3), JUMP_IF_FALSE, true, false);
  end;

  //[bug] в game_sv_xxx::OnEvent для события GAME_EVENT_PLAYER_KILL (самоубийство) отсутствует проверка на то, что убиваем именно отправителя пакета
  if xrGameDllType()=XRGAME_SV_1510 then begin
    //DM/TDM/AH
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$305f8c),@game__OnEvent_SelfKill_Check,6,[F_PUSH_EAX, F_RMEM+F_PUSH_ESP+$14], pointer(xrGame+$305fa5), JUMP_IF_FALSE, true, false);
    //CTA
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$31c848),@game__OnEvent_SelfKill_Check,6,[F_PUSH_EAX, F_RMEM+F_PUSH_ESP+$1C], pointer(xrGame+$31C8FD), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    //DM/TDM/AH
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$31b0ec),@game__OnEvent_SelfKill_Check,6,[F_PUSH_EAX, F_RMEM+F_PUSH_ESP+$14], pointer(xrGame+$31b105), JUMP_IF_FALSE, true, false);
    //CTA
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$332568),@game__OnEvent_SelfKill_Check,6,[F_PUSH_EAX, F_RMEM+F_PUSH_ESP+$1C], pointer(xrGame+$33261D), JUMP_IF_FALSE, true, false);
  end;

  //[bug] Феерическая бага с трупаками. В game_sv_mp::Update выполняется цикл, убивающий все "лишних" трупы сверх лимита из m_CorpseList.
  //Все вроде бы неплохо - отсылаем сообщение о том, что объект подлежит удалению, затем выкидываем его ИДшник из контейнера m_CorpseList.
  //Но! Во время удаления вызывается game_sv_mp::OnDestroyObject (или его потомок), в котором производится поиск по контейнеру этого же ИДшника, и
  //выполняется его удаление. Таким образом, в game_sv_mp::Update удаляется дополнительно ДРУГОЙ элемент, что ведет к ликам и прочим крешам.
  //Ситуацию усугубляет то, что в game_sv_mp::OnPlayerDisconnect не делается проверка на то, актором был игрок или спектатором, и в m_CorpseList
  //запихиваются спектаторы, если отсоединившийся был им! Таким образом, даже отключение трупов при помощи sv_remove_corpse 0 не поможет от креша.
  //Решение - по хорошему, в game_sv_mp::Update надо делать удаление через find, но можно и просто выпилить - хуже не будет (что и сделаем).
  //Также было бы желательно переделать логику в game_sv_mp::OnPlayerDisconnect, чтобы спектаторы удалялись сразу (через отправку GE_DESTROY). Но, так
  //как это не критично - делать пока не будем.
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcKit.Get.nop_code(pointer(xrGame+$30A754), $56);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcKit.Get.nop_code(pointer(xrGame+$3205A4), $56);
  end;

  //[bug] в game_sv_Deathmatch::OnDetach и game_sv_CaptureTheArtefact::OnDetach часть предметов не отправляется ни в список перемещаемых в рюкзак,
  //ни в список удаляемых. Из-за этого они зависают в трупе, препятствуя его удалению с уровня и вызывая спам в консоль.
  if xrGameDllType()=XRGAME_SV_1510 then begin
    //game_sv_Deathmatch
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$302f76),@game_sv__OnDetach_isitemtransfertobagneeded,7,[F_PUSH_EBP], pointer(xrGame+$303006), JUMP_IF_TRUE, true, true);
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$302f7d),@game_sv__OnDetach_isitemremovingneeded,11,[F_PUSH_EBP], pointer(xrGame+$303013), JUMP_IF_FALSE, true, true);
    //game_sv_CaptureTheArtefact
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$318d89),@game_sv__OnDetach_isitemtransfertobagneeded,7,[F_PUSH_EBX], pointer(xrGame+$318df1), JUMP_IF_TRUE, true, true);
    srcKit.Get().nop_code(pointer(xrGame+$318df5), $1B);
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$318d90),@game_sv__OnDetach_isitemremovingneeded,11,[F_PUSH_EBX], pointer(xrGame+$318e3c), JUMP_IF_FALSE, true, true);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    //game_sv_Deathmatch
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$3180d6),@game_sv__OnDetach_isitemtransfertobagneeded,7,[F_PUSH_EBP], pointer(xrGame+$318166), JUMP_IF_TRUE, true, true);
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$3180dd),@game_sv__OnDetach_isitemremovingneeded,11,[F_PUSH_EBP], pointer(xrGame+$318173), JUMP_IF_FALSE, true, true);
    //game_sv_CaptureTheArtefact
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$32ebe9),@game_sv__OnDetach_isitemtransfertobagneeded,7,[F_PUSH_EBX], pointer(xrGame+$32ec51), JUMP_IF_TRUE, true, true);
    srcKit.Get().nop_code(pointer(xrGame+$32ec55), $1B);
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$32ebf0),@game_sv__OnDetach_isitemremovingneeded,11,[F_PUSH_EBX], pointer(xrGame+$32ec9c), JUMP_IF_FALSE, true, true);
  end;

  //[bug] в game_sv_Deathmatch::OnDetach не происходит удаления предметов, они остаются в трупе
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$303147),@game_sv_Deathmatch__OnDetach_destroyitems,8,[F_RMEM+F_PUSH_ESP+$10, F_RMEM+F_PUSH_ESP+$34, F_RMEM+F_PUSH_ESP+$38], true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$3182a7),@game_sv_Deathmatch__OnDetach_destroyitems,8,[F_RMEM+F_PUSH_ESP+$10, F_RMEM+F_PUSH_ESP+$34, F_RMEM+F_PUSH_ESP+$38], true, false);
  end;

  //[bug] Если в трупе остаются дочерние предметы, они препятствуют его удалению и вызывают спам в консоль в game_sv_mp::Update
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30a6a4),@game_sv_mp__Update_could_corpse_be_removed,6,[F_PUSH_EAX], pointer(xrGame+$30a6cf), JUMP_IF_TRUE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$3204f4),@game_sv_mp__Update_could_corpse_be_removed,6,[F_PUSH_EAX], pointer(xrGame+$32051f), JUMP_IF_TRUE, true, false);
  end;

  result:=true;
end;

function Init():boolean; stdcall;
var
  tmp:cardinal;
begin

  result:=false;

  //патчим запрещенные символы в нике игрока и проверяем длину - полностью заменяем modify_player_name
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$474760),@modify_player_name,6,[F_PUSH_EAX, F_PUSH_EDI], true, true);
    if not srcKit.Get.nop_code(pointer(xrGame+$474766), 1, chr($C3)) then exit; //делаем возврат сразу после выполнения нашей функции
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$48A8E0),@modify_player_name,6,[F_PUSH_EAX, F_PUSH_EDI], true, true);
    if not srcKit.Get.nop_code(pointer(xrGame+$48A8E6), 1, chr($C3)) then exit; //делаем возврат сразу после выполнения нашей функции
  end;

  //проверка размера пакета с ником игрока в game_sv_mp::OnEvent
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30AF2B),@CheckIfPacketZStringIsLesserThen,6,[F_PUSH_ECX, F_PUSHCONST+20, F_PUSH_EAX, F_PUSHCONST+1, F_PUSHCONST+$0836, F_PUSHCONST+1], pointer(xrGame+$30AF37), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$320D7B),@CheckIfPacketZStringIsLesserThen,6,[F_PUSH_ECX, F_PUSHCONST+20, F_PUSH_EAX, F_PUSHCONST+1, F_PUSHCONST+$0836, F_PUSHCONST+1], pointer(xrGame+$320D87), JUMP_IF_FALSE, true, false);
  end;


  //[bug]защита от stalkazz - в xrGameSpyServer::OnMessage убеждаемся, что длина строки в пакете M_GAMESPY_CDKEY_VALIDATION_CHALLENGE_RESPOND меньше, чем размер буфера
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$38C7E2),@CheckIfPacketZStringIsLesserThanWithDisconnect,7,[F_PUSH_EBX, F_PUSHCONST+128, F_PUSH_ESI, F_PUSHCONST+$16, F_PUSHCONST+1], pointer(xrGame+$38C7D5), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$3A2CF2),@CheckIfPacketZStringIsLesserThanWithDisconnect,7,[F_PUSH_EBX, F_PUSHCONST+128, F_PUSH_ESI, F_PUSHCONST+$16, F_PUSHCONST+1], pointer(xrGame+$3A2CE5), JUMP_IF_FALSE, true, false);
  end;

  //переделка названия логфайла
  if FZConfigMgr.Get().GetBool('rename_game_log', true) then begin
    RenameGameLog(PChar(xrCore+$3F438), sizeof(string_path));
  end;

  if not PatchVoting() then exit;
  if not PatchConsole() then exit;
  if not PatchGameSpy() then exit;
  if not PatchChat() then exit;
  if not PatchPlayers() then exit;
  if not PatchBanSystem() then exit;
  if not PatchSaceFakers() then exit;
  if not PatchShop() then exit;
  if not PatchHits() then exit;
  if not PatchKillsAndCorpses() then exit;

  //Переделка визуалов игроков: CSE_Abstract, team, skin
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30B556),@OnSetPlayerSkin,7,[F_PUSH_ESI, F_PUSH_ECX, F_PUSH_EAX], pointer(xrGame+$30B55D), JUMP_IF_TRUE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$3213A6),@OnSetPlayerSkin,7,[F_PUSH_ESI, F_PUSH_ECX, F_PUSH_EAX], pointer(xrGame+$3213AD), JUMP_IF_TRUE, true, false);
  end;

  //Подмена секций подменяемой снаряги (game_sv_mp::SpawnWeapon4Actor)
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcEAXReturnerInjection.Create(pointer(xrGame+$30C419),@OnActorItemSpawn_ChangeItemSection,5,[F_PUSH_ECX, F_RMEM+F_PUSH_EBP+08, F_PUSH_EAX, F_RMEM+F_PUSH_EBP+$C], true, false, 0);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcEAXReturnerInjection.Create(pointer(xrGame+$322269),@OnActorItemSpawn_ChangeItemSection,5,[F_PUSH_ECX, F_RMEM+F_PUSH_EBP+08, F_PUSH_EAX, F_RMEM+F_PUSH_EBP+$C], true, false, 0);
  end;


  if FZConfigMgr.Get.GetBool('patch_updrate', true) then begin
    //dynamic update rate - патч в IPureServer::HasBandwidth
    srcECXReturnerInjection.Create(pointer(xrNetServer+$B27A),@SelectUpdRate,6,[F_PUSH_EDI,F_RMEM+F_PUSH_ESP+$10, F_PUSH_ECX], false, false, 0);
  end;

  //Сделаем отправку событий на действия с оружием приоритетными в xrServer::Process_event
  if FZConfigMgr.Get.GetBool('patch_shooting_priority', true) then begin
    if xrGameDllType()=XRGAME_SV_1510 then begin
      srcEAXReturnerInjection.Create(pointer(xrGame+$38A2C1),@xrServer__Process_event_change_shooting_packets_proority,5,[], false, false, 0);
      srcKit.Get.nop_code(pointer(xrGame+$38A2C6), 1, Char(PUSH_EAX));
      srcKit.Get.nop_code(pointer(xrGame+$38A2C7), 1);
     end else if xrGameDllType()=XRGAME_CL_1510 then begin
       srcEAXReturnerInjection.Create(pointer(xrGame+$3A0701),@xrServer__Process_event_change_shooting_packets_proority,5,[], false, false, 0);
       srcKit.Get.nop_code(pointer(xrGame+$3A0706), 1, Char(PUSH_EAX));
       srcKit.Get.nop_code(pointer(xrGame+$3A0707), 1);
    end;
  end;

  //сброс счетчика предупреждений о пинге
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2C8C22),@OnPingWarn,6,[F_PUSH_EDI], pointer(xrGame+$2C8CE0), JUMP_IF_FALSE, false, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2DDC52),@OnPingWarn,6,[F_PUSH_EDI], pointer(xrGame+$2DDD10), JUMP_IF_FALSE, false, false);
  end;

  //[bug]Запрещаем смену имени консольной командой - там баг со стартом голосования
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30DF20),@CanChangeName,6,[F_PUSH_ESI], pointer(xrGame+$30DFA5), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$323DC0),@CanChangeName,6,[F_PUSH_ESI], pointer(xrGame+$323E45), JUMP_IF_FALSE, true, false);
  end;

  //Отсылка пакета загрузки отсутствующей карты клиентом
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$30797C),@OnAttachNewClient,5,[F_PUSH_EDI, F_PUSH_ESI], true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$31D7FC),@OnAttachNewClient,5,[F_PUSH_EDI, F_PUSH_ESI], true, false);
  end;

  //Событие, когда клиент окончательно присоединен и готов  к игре - в xrServer::OnMessage M_CLIENTREADY
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$2c8063),@OnClientReady,6,[F_PUSH_EBP, F_PUSH_EBX], true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$2dd0d3),@OnClientReady,6,[F_PUSH_EBP, F_PUSH_EBX], true, false);
  end;

  //[bug] удаление клиента - убиваем PlayerState, если клиент толком не прогрузился
  //Этим ликвидируем невыдачу клиенту денег при заходе на сервер
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2c72e6),@xrServer__client_Destroy_force_destroy,6,[F_PUSH_EDI], pointer(xrGame+$2C7314), JUMP_IF_TRUE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2dc356),@xrServer__client_Destroy_force_destroy,6,[F_PUSH_EDI], pointer(xrGame+$2DC384), JUMP_IF_TRUE, true, false);
  end;

  //В xrServer::Connect нам надо получить обновленное имя карты
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$30760d),@xrServer__Connect_updatemapname,5,[F_PUSH_EDI], false, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$31d48d),@xrServer__Connect_updatemapname,5,[F_PUSH_EDI], false, false);
  end;

  //Загрузка использованных ранее имени карты и режима
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$1d629f),@CLevel__net_Start_overridelevelgametype,8,[], false, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$1e833f),@CLevel__net_Start_overridelevelgametype,8,[], false, false);
  end;

  //[bug] или не совсем баг... патч в IPureServer::SendTo_LL : убираем ассерт при несуществующем клиенте, ибо если его нет - то и хрен с ним, обойдемся как-нибудь :)
  if not srcKit.Get.nop_code(pointer(xrNetServer+$B098), 1, chr($EB)) then exit;

  //[bug] Дерьмо с синхронизацией: IPureServer::DisconnectClient убивает клиента моментально, не проверяя ничего. Между тем, к уничтоженному клиенту еще могут обратиться потом, что вызовет проблемы
  //Полностью, похоже, не пофиксать. Но можно уменьшить частоту крешей.
  //Проверим в game_sv_mp::OnEvent (и наследниках), существует ли еще клиент, перед тем, как выполнять действия (так как у нас "отложенная" очередь событий, от момента получения сообщения до момента обработки клиент мог сдохнуть)
  if xrGameDllType()=XRGAME_SV_1510 then begin
    //game_sv_mp::OnEvent
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30ad4e),@OnGameEvent_CheckClientExist,7,[F_RMEM+F_PUSH_ESP+$418, F_RMEM+F_PUSH_ESP+$41C, F_RMEM+F_PUSH_ESP+$424], pointer(xrGame+$30ad83), JUMP_IF_FALSE, true, false);
    //game_sv_Deathmatch::OnEvent
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$305f11),@OnGameEvent_CheckClientExist,6,[F_RMEM+F_PUSH_ESP+$8, F_RMEM+F_PUSH_ESP+$C, F_RMEM+F_PUSH_ESP+$14], pointer(xrGame+$305f3b), JUMP_IF_FALSE, true, false);
    //game_sv_CaptureTheArtefact::OnEvent
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$31c818),@OnGameEvent_CheckClientExist,7,[F_RMEM+F_PUSH_ESP+$10, F_RMEM+F_PUSH_ESP+$14, F_RMEM+F_PUSH_ESP+$1c], pointer(xrGame+$31c861), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    //game_sv_mp::OnEvent
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$320b9e),@OnGameEvent_CheckClientExist,7,[F_RMEM+F_PUSH_ESP+$418, F_RMEM+F_PUSH_ESP+$41C, F_RMEM+F_PUSH_ESP+$424], pointer(xrGame+$320bd3), JUMP_IF_FALSE, true, false);
    //game_sv_Deathmatch::OnEvent
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$31b071),@OnGameEvent_CheckClientExist,6,[F_RMEM+F_PUSH_ESP+$8, F_RMEM+F_PUSH_ESP+$C, F_RMEM+F_PUSH_ESP+$14], pointer(xrGame+$31b09b), JUMP_IF_FALSE, true, false);
    //game_sv_CaptureTheArtefact::OnEvent
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$332538),@OnGameEvent_CheckClientExist,7,[F_RMEM+F_PUSH_ESP+$10, F_RMEM+F_PUSH_ESP+$14, F_RMEM+F_PUSH_ESP+$1c], pointer(xrGame+$332581), JUMP_IF_FALSE, true, false);
  end;

  //[bug] В game_sv_GameState::OnEvent вызов R_ASSERT совсем не смотрится - злоумышленник может запросто крешнуть сервак с его помощью.
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$2f39c2), @OnGameEventNotImplenented, 60, [F_RMEM+F_PUSH_ESP+$420, F_RMEM+F_PUSH_ESP+$424, F_RMEM+F_PUSH_ESP+$42c], true, true);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$308932), @OnGameEventNotImplenented, 60, [F_RMEM+F_PUSH_ESP+$420, F_RMEM+F_PUSH_ESP+$424, F_RMEM+F_PUSH_ESP+$42c], true, true);
  end;

  //В xrServer::client_Destroy - добавляем проверку на наличие игрока
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$2c7070),@LockServerPlayers,6,[], false, false);
    srcBaseInjection.Create(pointer(xrGame+$2c7336),@UnlockServerPlayers,5,[], true, false);
    srcBaseInjection.Create(pointer(xrGame+$2c730b),@UnlockServerPlayers,5,[], true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$2dc0e0),@LockServerPlayers,6,[], false, false);
    srcBaseInjection.Create(pointer(xrGame+$2dc3a6),@UnlockServerPlayers,5,[], true, false);
    srcBaseInjection.Create(pointer(xrGame+$2dc37b),@UnlockServerPlayers,5,[], true, false);
  end;

  //В game_sv_GameState::OnEvent - добавляем блок очереди игроков при сообщении GAME_EVENT_CREATE_CLIENT
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$2f3945),@LockServerPlayers,7,[], false, false);
    srcKit.Get().nop_code(pointer(xrGame+$2f395e), 1, CHR($14));
    srcBaseInjection.Create(pointer(xrGame+$2f3975),@UnlockServerPlayers,6,[], true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$3088b5),@LockServerPlayers,7,[], false, false);
    srcKit.Get().nop_code(pointer(xrGame+$3088ce), 1, CHR($14));
    srcBaseInjection.Create(pointer(xrGame+$3088e5),@UnlockServerPlayers,6,[], true, false);
  end;

  //[bug] В IPureServer::GetClientAddress может прилетать нулевой pClientAddress (в случае дисконнекта в этот момент), что разваливает ему логику. Отфильтруем.
  srcInjectionWithConditionalJump.Create(pointer(xrNetServer+$b570),@IPureServer__GetClientAddress_check_arg, 6,[F_RMEM+F_PUSH_ESP+4, F_RMEM+F_PUSH_ESP+8, F_RMEM+F_PUSH_ESP+$c], pointer(xrNetServer+$b651), JUMP_IF_FALSE, true, false);

  //Добавляем в xrServer::OnMessage дополнительный обработчик, выполняющийся после всех; тут можем ловить дополнительные события
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$2c8457),@xrServer__OnMessage_additional,10,[F_PUSH_EBP, F_PUSH_EDI, F_PUSH_ESI], true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$2dd4c7),@xrServer__OnMessage_additional,10,[F_PUSH_EBP, F_PUSH_EDI, F_PUSH_ESI], true, false);
  end;

  //В xrServer::OnCL_Disconnected пишем в пакет пустое имя в случае если клиент еще нормально не приконнектился
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$30714c),@xrServer__OnCL_Disconnected_appendToPacket,6,[F_PUSH_ECX, F_PUSH_ESP, F_PUSH_EBX], true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$31cfcc),@xrServer__OnCL_Disconnected_appendToPacket,6,[F_PUSH_ECX, F_PUSH_ESP, F_PUSH_EBX], true, false);
  end;

  //если у клиента пустое имя - в game_sv_mp::OnPlayerDisconnect не отправляем другим игрокам сообщение о дисконнекте
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30B777),@game_sv_mp__OnPlayerDisconnect_is_message_needed, 7,[F_PUSH_EAX], pointer(xrGame+$30b7a5), JUMP_IF_FALSE, false, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$3215c7),@game_sv_mp__OnPlayerDisconnect_is_message_needed, 7,[F_PUSH_EAX], pointer(xrGame+$3215f5), JUMP_IF_FALSE, false, false);
  end;

  //[bug] Фикс для уязвимости DirtySky, найденной Luigi Auriemma. Суть в том, что в IPureServer::net_Handler при DPN_MSGID_CREATE_PLAYER вызов WideCharToMultiByte на большой строке не дает терминатора! А потом нетерминированная строка скармливается в strcpy_n
  srcBaseInjection.Create(pointer(xrNetServer+$ad34),@CheckClientConnectionName, 7,[F_PUSH_EDX, F_RMEM+F_PUSH_EBP+$0C], false, false);

  //[bug] В IPureServer::net_Handler также в DPN_MSGID_CREATE_PLAYER клиент имеет возможность отправить нам нетерминированные логин и пароль, которые мы слепо скопируем в SClientConnectData	cl_data
  srcBaseInjection.Create(pointer(xrNetServer+$ad94),@CheckClientConnectData, 6,[F_PUSH_ECX], true, false);

  //[bug] в game_sv_GameState::NewPlayerName_Generate сам по себе буфер размером 64 байта, однако в strcpy_s передается всего лишь 22, чего явно недостаточно для случая sprintf'а
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcKit.Get().nop_code(pointer(xrGame+$2f3b6b), 1, chr(64));
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcKit.Get().nop_code(pointer(xrGame+$308adb), 1, chr(64));
  end;

  //[bug] Assert на CRC в NET_Compressor::Decompress выполнять крайне не желательно
  srcInjectionWithConditionalJump.Create(pointer(xrNetServer+$8176),@AlwaysTrue, 14,[], pointer(xrNetServer+$8124), JUMP_IF_TRUE, false, false);

  //В NET_Packet::w явно не хватает assert'a на случай переполнения
  srcBaseInjection.Create(pointer(xrCore+$42ca),@NET_Packet__w_checkOverflow,6,[F_PUSH_ESI, F_RMEM+F_PUSH_EBP+$C], true, false);

  //[bug] При смерти игрока со слишком большим числом предметов в инвентаре в game_sv_Deathmatch::OnDetach происходит переполнение EventPack. Решение - разбивать на несколько пакетов и отправлять их по мере заполнения
  //Аналогично - в game_sv_CaptureTheArtefact::OnDetachItem
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$303075),@SplitEventPackPackets,6,[F_PUSH_ESP+$58], true, false);
    srcBaseInjection.Create(pointer(xrGame+$318ea0),@SplitEventPackPackets,5,[F_PUSH_ESP+$48], true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$3181d5),@SplitEventPackPackets,6,[F_PUSH_ESP+$58], true, false);
    srcBaseInjection.Create(pointer(xrGame+$32ed00),@SplitEventPackPackets,5,[F_PUSH_ESP+$48], true, false);
  end;

  //[bug] При попытке подобрать рюкзак со слишком большим числом предметов в game_sv_Deathmatch::OnTouch происходит переполнение EventPack. Решение - разбивать на несколько пакетов и отправлять их по мере заполнения
  //Аналогично - в game_sv_CaptureTheArtefact::OnTouchItem
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$302c16),@SplitEventPackPackets,7,[F_PUSH_ESP+$24], true, false);
    srcBaseInjection.Create(pointer(xrGame+$318637),@SplitEventPackPackets,7,[F_PUSH_ESP+$18], true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$317d76),@SplitEventPackPackets,7,[F_PUSH_ESP+$24], true, false);
    srcBaseInjection.Create(pointer(xrGame+$32e497),@SplitEventPackPackets,7,[F_PUSH_ESP+$18], true, false);
  end;

  //[bug] При удалении рюкзака со слишком большим числом предметов в xrServer::Process_event_destroy происходит переполнение pEventPack. Решение - разбивать на несколько пакетов и отправлять их по мере заполнения
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$38ad56),@SplitEventPackPackets,7,[F_PUSH_EBP], true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$3a124c),@SplitEventPackPackets,5,[F_PUSH_ESI], false, false);
  end;

  //В CGameObject::CGameObject заставляем создавать m_ai_location всегда
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcKit.Get().nop_code(pointer(xrGame+$207c9d), 2, chr($90));
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcKit.Get().nop_code(pointer(xrGame+$219b8d), 2, chr($90));
  end;

  //[bug] Логика обработка события GE_ADDON_DETACH позволяет клиентам заспавнить себе в рюкзак что угодно (или крешнуть сервак)
  //На исходниках - перерабатывать обработчик события.
  //Так как у нас бинарный патч - можем закостылять так:
  //1)В CInventoryItem::OnEvent производить вызов Detach(i_name, false); - тем самым у нас вообще не будет детача от произвольной хрени
  //2)В CWeaponMagazinedWGrenade::Detach и CWeaponMagazined::Detach при обнаружении валидного детача - исправлять аргумент на true
  if xrGameDllType()=XRGAME_SV_1510 then begin
    //правка аргумента с true на false в CInventoryItem::OnEvent
    srcKit.Get().nop_code(pointer(xrGame+$22f6ff), 1, chr($00));

    //Исправления в CWeaponMagazined::Detach для постоянного детача аддонов со спавном
    tmp:=$9040c031; //xor eax, eax; inc eax
    srcKit.Get().CopyBuf(@tmp, pointer(xrGame+$24f8c4), sizeof(tmp));
    tmp:=$9041c931; //xor ecx, ecx; inc ecx
    srcKit.Get().CopyBuf(@tmp, pointer(xrGame+$24f93a), sizeof(tmp));
    srcKit.Get().CopyBuf(@tmp, pointer(xrGame+$24f9ad), sizeof(tmp));

    //Исправления в CWeaponMagazinedWGrenade::Detach для постоянного детача аддонов со спавном
    tmp:=$9040c031; //xor eax, eax; inc eax
    srcKit.Get().CopyBuf(@tmp, pointer(xrGame+$2532e5), sizeof(tmp));
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    //правка аргумента с true на false в CInventoryItem::OnEvent
    srcKit.Get().nop_code(pointer(xrGame+$241e2f), 1, chr($00));

    //Исправления в CWeaponMagazined::Detach для постоянного детача аддонов со спавном
    tmp:=$9040c031; //xor eax, eax; inc eax
    srcKit.Get().CopyBuf(@tmp, pointer(xrGame+$262234), sizeof(tmp));
    tmp:=$9041c931; //xor ecx, ecx; inc ecx
    srcKit.Get().CopyBuf(@tmp, pointer(xrGame+$2622aa), sizeof(tmp));
    srcKit.Get().CopyBuf(@tmp, pointer(xrGame+$26231d), sizeof(tmp));

    //Исправления в CWeaponMagazinedWGrenade::Detach для постоянного детача аддонов со спавном
    tmp:=$9040c031; //xor eax, eax; inc eax
    srcKit.Get().CopyBuf(@tmp, pointer(xrGame+$265cb5), sizeof(tmp));
  end;

  //Подключаем фильтр для исправления проблем с xrServer::Process_event
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$38a1b1),@CheckGameEventPacket,6,[F_PUSH_ESI, F_RMEM+F_PUSH_EBP+$8], pointer(xrGame+$38a867), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$3a05f1),@CheckGameEventPacket,6,[F_PUSH_ESI, F_RMEM+F_PUSH_EBP+$8], pointer(xrGame+$3a0ca7), JUMP_IF_FALSE, true, false);
  end;

  //Удаляем спам сообщениями '* comparing with cheater' при подключении
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcKit.Get().nop_code(pointer(xrGame+$3093d9), 2);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcKit.Get().nop_code(pointer(xrGame+$31f219), 2);
  end;

  //Дополнительные вещи в апдейте game
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$30a4c0),@game_sv_mp__Update_additionals,6,[], true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$320310),@game_sv_mp__Update_additionals,6,[], true, false);
  end;

  //Назначение предыдущей команды при реконнекте игрока, смена команды для которого заблокирована
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcEAXReturnerInjection.Create(pointer(xrGame+$30822c), @game_sv_TeamDeathmatch__OnPlayerConnect_selectteam, 6, [F_PUSH_EBX, F_PUSH_EAX], true, false, 0);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcEAXReturnerInjection.Create(pointer(xrGame+$31e0ac), @game_sv_TeamDeathmatch__OnPlayerConnect_selectteam, 6, [F_PUSH_EBX, F_PUSH_EAX], true, false, 0);
  end;

  //Отслеживание пакетов GEG_PLAYER_WEAPON_HIDE_STATE игрока с целью выявления моментов, когда у него открыты меню. Смена команды игрока в эти моменты чревата багами.
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$38a6fc),@xrServer__Process_event_onweaponhide,5,[F_PUSH_EDX, F_RMEM+F_PUSH_EBP+$8, F_PUSH_ESI], true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$3a0b3c),@xrServer__Process_event_onweaponhide,5,[F_PUSH_EDX, F_RMEM+F_PUSH_EBP+$8, F_PUSH_ESI], true, false);
  end;

  //Отслеживание спавна игрока
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$30b440),@game_sv_mp_OnSpawnPlayer,7,[F_RMEM+F_PUSH_ESP+$8, F_RMEM+F_PUSH_ESP+$C], true, false);
    //на всякий - из game_sv_mp_script::SpawnPlayer
    srcBaseInjection.Create(pointer(xrGame+$311350),@game_sv_mp_OnSpawnPlayer,5,[F_RMEM+F_PUSH_ESP+$4, F_RMEM+F_PUSH_ESP+$8], true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$321290),@game_sv_mp_OnSpawnPlayer,7,[F_RMEM+F_PUSH_ESP+$8, F_RMEM+F_PUSH_ESP+$C], true, false);
    //на всякий - из game_sv_mp_script::SpawnPlayer
    srcBaseInjection.Create(pointer(xrGame+$3271b0),@game_sv_mp_OnSpawnPlayer,5,[F_RMEM+F_PUSH_ESP+$4, F_RMEM+F_PUSH_ESP+$8], true, false);
  end;

  //нормальные сообщения при выкидывании с сервера
  if xrGameDllType()=XRGAME_SV_1510 then begin
    //game_sv_TeamDeathmatch::OnPlayerKillPlayer - тимкиллы
    srcBaseInjection.Create(pointer(xrGame+$3086da), @DisconnectPlayerWithMessage, 7, [F_PUSH_EAX, F_PUSHCONST+0], false, true);
    //game_sv_CaptureTheArtefact::OnKillResult - тимкиллы
    srcBaseInjection.Create(pointer(xrGame+$3178a5), @DisconnectPlayerWithMessage, 7, [F_PUSH_EAX, F_PUSHCONST+0], false, true);
   end else if xrGameDllType()=XRGAME_CL_1510 then begin
    //game_sv_TeamDeathmatch::OnPlayerKillPlayer - тимкиллы
    srcBaseInjection.Create(pointer(xrGame+$31e55a), @DisconnectPlayerWithMessage, 7, [F_PUSH_EAX, F_PUSHCONST+0], false, true);
    //game_sv_CaptureTheArtefact::OnKillResult - тимкиллы
    srcBaseInjection.Create(pointer(xrGame+$32d705), @DisconnectPlayerWithMessage, 7, [F_PUSH_EAX, F_PUSHCONST+0], false, true);
  end;


  //Cars:
  //client CActorMP::net_Relevant	 - xrgame.dll+1f61d0
  //server CActorMP::net_Relevant	 - xrgame.dll+


  //фильтрация пакетов
//  srcBaseInjection.Create(pointer(xrNetServer+$A149),@net_Handler,5,[F_PUSH_ESP], false, false);

  //Сниффер отправок
//  srcBaseInjection.Create(pointer(xrNetServer+$AF90),@SentPacketsRegistrator,7,[F_RMEM+F_PUSH_ESP+4, F_RMEM+F_PUSH_ESP+$8, F_RMEM+F_PUSH_ESP+$c], true, false);

  //в CLevel::Load_GameSpecific_After делаем загрузку скриптов захода на уровень ;)
  //srcKit.Get.nop_code(pointer(xrGame+$1C742A), 6);

  // Заставим сервак думать, что он не выделенный ))
//  g_dedicated_server^:=0;
  // в CApplication::LoadDraw это нам не надо.
//  if not srcKit.Get.nop_code(pointer(xrEngine+$5f253), 2, chr($90)) then exit;
  // в CConsole::OnRender тоже
//  if not srcKit.Get.nop_code(pointer(xrEngine+$41947), 2, chr($90)) then exit;
  // IGame_Level::Load - захват мыши нам не нужен
//  if not srcKit.Get.nop_code(pointer(xrEngine+$5c0d4), 2, chr($90)) then exit;
  result:=true;
end;

end.

