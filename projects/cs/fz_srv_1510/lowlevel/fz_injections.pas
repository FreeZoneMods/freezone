unit fz_injections;
{$mode delphi}
interface
function Init():boolean; stdcall;

implementation
uses srcBase, basedefs, GameSpy, srcInjections, Voting, Console, BasicProtection, Chat, Players, ConfigMgr, LogMgr, Bans, PacketFilter, PlayerSkins, UpdateRate, ControlGUI, Servers, ServerStuff, misc_stuff, global_functions, SACE_hacks;

function PatchBanSystem():boolean;
begin
  //первым делом смотрим в xrServer::ProcessClientDigest и видим:
  //P->r_stringZ	(xrCL->m_cdkey_digest);
	//P->r_stringZ	(secondary_cdkey);
  //Если второе (хеш от нижнего регистра) и ладно, пусть будет
  //То вот первый у нас дублируется с полученным и проверенным геймспаем во время CHALLENGE_RESPOND
  //Клиент тут может нам отослать все, что ему заблагорассудится, и чего не окажется в банлисте... непорядок.
  //делаем так, чтобы в xrCL->m_cdkey_digest оказался полученный в CHALLENGE_RESPOND хеш
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$307AC7), @xrServer__ProcessClientDigest_ProtectFromKeyChange, 5,[F_RMEM+F_PUSH_EBP+$0C], false, false);
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$307B37),@xrServer__ProcessClientDigest_CheckAdditionalRejectingConditions,6,[F_PUSH_EDI],pointer(xrGame+$307B4C), JUMP_IF_FALSE, false, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$31D947), @xrServer__ProcessClientDigest_ProtectFromKeyChange, 5,[F_RMEM+F_PUSH_EBP+$0C], false, false);
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$31D9B7),@xrServer__ProcessClientDigest_CheckAdditionalRejectingConditions,6,[F_PUSH_EDI],pointer(xrGame+$31D9CC), JUMP_IF_FALSE, false, false);
  end;

  //Пропатчимся на бан подсетей
  srcInjectionWithConditionalJump.Create(pointer(xrNetServer+$AE6F),@IPureServer__net_Handler_SubnetBans,5,[F_RMEM+F_PUSH_ESP+$0C],pointer(xrNetServer+$AE7F), JUMP_IF_TRUE, true, False);

  //Сообщение о том, что IP забанен в игровом банлисте
  srcBaseInjection.Create(pointer(xrNetServer+$AE7F),@IPureServer__net_Handler_OnBannedByGameIpFound,7,[], true, False);

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
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30AE54),@CanSafeStartVote,5,[F_PUSH_EBX, F_PUSH_ECX, F_RMEM+F_PUSH_ESP+$424],pointer(xrGame+$30B05E), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$320CA4),@CanSafeStartVote,5,[F_PUSH_EBX, F_PUSH_ECX, F_RMEM+F_PUSH_ESP+$424],pointer(xrGame+$320EAE), JUMP_IF_FALSE, true, false);
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

  //в gcd_authenticate_user правим возможность игры нескольким игрокам с одним ключом на сервере и отключаем отправку пакета с запросом
  if not srcKit.Get.nop_code(pointer(xrGameSpy+$B1E0),1, CHR($EB)) then exit;
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

  result:=true;
end;

function PatchSaceFakers():boolean;
begin
  //Проверка на то, что DPN_MSGID_ENUM_HOSTS_QUERY с ToConnect не был отправлен SACE ( в IPureServer::net_Handler)
  srcInjectionWithConditionalJump.Create(pointer(xrNetServer+$AC60),@IPureServer__net_Handler_isToConnectsentbysace,15,[F_PUSH_ECX], pointer(xrNetServer+$AE8D), JUMP_IF_TRUE, true, false);
  result:=true;
end;

function Init():boolean; stdcall;
var
  addr:pcardinal;
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
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30AF2B),@CheckIfPacketZStringIsLesserThen,6,[F_PUSH_ECX, F_PUSHCONST+20, F_PUSH_EAX, F_PUSHCONST+1, F_PUSHCONST+$0836], pointer(xrGame+$30AF37), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$320D7B),@CheckIfPacketZStringIsLesserThen,6,[F_PUSH_ECX, F_PUSHCONST+20, F_PUSH_EAX, F_PUSHCONST+1, F_PUSHCONST+$0836], pointer(xrGame+$320D87), JUMP_IF_FALSE, true, false);
  end;


  //защита от stalkazz - в xrGameSpyServer::OnMessage убеждаемся, что длина строки в пакете M_GAMESPY_CDKEY_VALIDATION_CHALLENGE_RESPOND меньше, чем размер буфера
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$38C7E2),@CheckIfPacketZStringIsLesserThenWithDisconnect,7,[F_PUSH_EBX, F_PUSHCONST+128, F_PUSH_ESI, F_PUSHCONST+$16], pointer(xrGame+$38C7D5), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$3A2CF2),@CheckIfPacketZStringIsLesserThenWithDisconnect,7,[F_PUSH_EBX, F_PUSHCONST+128, F_PUSH_ESI, F_PUSHCONST+$16], pointer(xrGame+$3A2CE5), JUMP_IF_FALSE, true, false);
  end;

  //переделка названия логфайла
  RenameGameLog(PChar(xrCore+$3F438), 520);

  if not PatchVoting() then exit;
  if not PatchConsole() then exit;
  if not PatchGameSpy() then exit;
  if not PatchChat() then exit;
  if not PatchPlayers() then exit;
  if not PatchBanSystem() then exit;
  if not PatchSaceFakers() then exit;

  //Переделка визуалов игроков: CSE_Abstract, team, skin
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30B556),@OnSetPlayerSkin,7,[F_PUSH_ESI, F_PUSH_ECX, F_PUSH_EAX], pointer(xrGame+$30B55D), JUMP_IF_TRUE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$3213A6),@OnSetPlayerSkin,7,[F_PUSH_ESI, F_PUSH_ECX, F_PUSH_EAX], pointer(xrGame+$3213AD), JUMP_IF_TRUE, true, false);
  end;

  //Подмена секций подменяемой снаряги
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

  //[bug] баг с пролетом мимо магазина при спавне из-за последовательного получения нескольких сигналов готовности игрока GAME_EVENT_PLAYER_READY (в game_sv_mp::OnEvent)
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30ADE2),@CheckPlayerReadySignalValidity,6,[F_PUSH_EAX], pointer(xrGame+$30ADF0), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$320C32),@CheckPlayerReadySignalValidity,6,[F_PUSH_EAX], pointer(xrGame+$320C40), JUMP_IF_FALSE, true, false);
  end;

  //сброс счетчика предупреждений о пинге
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2C8C22),@OnPingWarn,6,[F_PUSH_EDI], pointer(xrGame+$2C8CE0), JUMP_IF_FALSE, false, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2DDC52),@OnPingWarn,6,[F_PUSH_EDI], pointer(xrGame+$2DDD10), JUMP_IF_FALSE, false, false);
  end;

  //Запрещаем смену имени консольной командой - там баг со стартом голосования
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

  //[bug] В game_sv_GameState::OnEvent надо проверить, что хит прилетел не для или не от серверного клиента. Ну и вообще проверить валидность/читерность хита
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2f3919),@game_sv_GameState__OnEvent_CheckHit,5,[F_PUSH_ESI, F_PUSH_EBP, F_PUSH_EBX, F_RMEM+F_PUSH_ESP+$434], pointer(xrGame+$2f3938), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$308889),@game_sv_GameState__OnEvent_CheckHit,5,[F_PUSH_ESI, F_PUSH_EBP, F_PUSH_EBX, F_RMEM+F_PUSH_ESP+$434], pointer(xrGame+$3088A8), JUMP_IF_FALSE, true, false);
  end;

  //[bug] в xrServer::Process_event при получении сообщения GE_HIT или GE_HIT_STATISTIC в очередь отложенных сообщений помещается нулевой ID
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$38a4f3),@AssignDwordToDword,6,[F_PUSH_EBP+$8, F_PUSH_ESP+$C], true, false);
    srcBaseInjection.Create(pointer(xrGame+$38a507),@AssignDwordToDword,6,[F_PUSH_EBP+$8, F_PUSH_ESP+$C], true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$3a0933),@AssignDwordToDword,6,[F_PUSH_EBP+$8, F_PUSH_ESP+$C], true, false);
    srcBaseInjection.Create(pointer(xrGame+$3a0947),@AssignDwordToDword,6,[F_PUSH_EBP+$8, F_PUSH_ESP+$C], true, false);
  end;

  //[bug] в game_sv_Deathmatch::OnEvent для события GAME_EVENT_PLAYER_KILL (самоубийство) отсутствует проверка на то, что убиваем именно отправителя пакета
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$305f8c),@game__OnEvent_SelfKill_Check,6,[F_PUSH_EAX, F_RMEM+F_PUSH_ESP+$14], pointer(xrGame+$305fa5), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$31b0ec),@game__OnEvent_SelfKill_Check,6,[F_PUSH_EAX, F_RMEM+F_PUSH_ESP+$14], pointer(xrGame+$31b105), JUMP_IF_FALSE, true, false);
  end;

  //[bug] аналогично в CTA
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$31c848),@game__OnEvent_SelfKill_Check,6,[F_PUSH_EAX, F_RMEM+F_PUSH_ESP+$1C], pointer(xrGame+$31C8FD), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$332568),@game__OnEvent_SelfKill_Check,6,[F_PUSH_EAX, F_RMEM+F_PUSH_ESP+$1C], pointer(xrGame+$33261D), JUMP_IF_FALSE, true, false);
  end;

  //[bug] GAME_EVENT_PLAYER_KILLED может отсылать только локальный клиент. Проверяем в game_sv_mp::OnEvent
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30ad5c),@CheckKillMessage,7,[F_RMEM+F_PUSH_ESP+$418, F_RMEM+F_PUSH_ESP+$424], pointer(xrGame+$30ad83), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$320bac),@CheckKillMessage,7,[F_RMEM+F_PUSH_ESP+$418, F_RMEM+F_PUSH_ESP+$424], pointer(xrGame+$320bd3), JUMP_IF_FALSE, true, false);
  end;

  //[bug] GAME_EVENT_PLAYER_HITTED также может отсылать только локальный клиент. Проверяем в game_sv_mp::OnEvent
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30ad8f),@CheckHitMessage,7,[F_RMEM+F_PUSH_ESP+$418, F_RMEM+F_PUSH_ESP+$424], pointer(xrGame+$30adb6), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$320bdf),@CheckHitMessage,7,[F_RMEM+F_PUSH_ESP+$418, F_RMEM+F_PUSH_ESP+$424], pointer(xrGame+$320c06), JUMP_IF_FALSE, true, false);
  end;

  //[bug] Так как трупы принадлежат локальному клиенту, то померший от кровотечения, нанесенного убиенным, закрешит нам сервак
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$30dc10),@game_sv_mp__OnPlayerKilled_preventlocal,6,[F_PUSH_EDI, F_PUSH_ESP+$10, F_PUSH_ESP+$1c, F_PUSH_ESP+$18], false, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$323ab0),@game_sv_mp__OnPlayerKilled_preventlocal,6,[F_PUSH_EDI, F_PUSH_ESP+$10, F_PUSH_ESP+$1c, F_PUSH_ESP+$18], false, false);
  end;

  //[bug] Аналогично, нанесение хита локальным клиентом невозможно
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30dd2c),@game_sv_mp__OnPlayerHit_preventlocal,8,[F_PUSH_EBX, F_PUSH_EDI], pointer(xrGame+$30dd7d), JUMP_IF_TRUE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$323bcc),@game_sv_mp__OnPlayerHit_preventlocal,8,[F_PUSH_EBX, F_PUSH_EDI], pointer(xrGame+$323c1d), JUMP_IF_TRUE, true, false);
  end;

  //В xrServer::Connect нам надо получить обновленное имя карты
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$307688),@xrServer__Connect_updatemapname,5,[F_PUSH_EDI], false, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$31d508),@xrServer__Connect_updatemapname,5,[F_PUSH_EDI], false, false);
  end;

  //[bug] или не совсем баг... патч в IPureServer::SendTo_LL : убираем ассерт при несуществующем клиенте, ибо если его нет - то и хрен с ним, обойдемся как-нибудь :)
  if not srcKit.Get.nop_code(pointer(xrNetServer+$B098), 1, chr($EB)) then exit;

  //[bug] в IPureServer::DisconnectClient нет синхронизации ресурсов (входа в критическую секцию)
  srcBaseInjection.Create(pointer(xrNetServer+$b44d),@LockServerPlayers,5,[], false, false);
  srcBaseInjection.Create(pointer(xrNetServer+$b454),@UnlockServerPlayers,5,[], true, false);

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

