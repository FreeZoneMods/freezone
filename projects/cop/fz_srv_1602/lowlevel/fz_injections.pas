unit fz_injections;

{$mode delphi}

interface

function Init():boolean; stdcall;

implementation
uses basedefs, srcInjections, srcBase, BasicProtection, Bans, ServerStuff, Players, GameSpy;

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

function Init():boolean; stdcall;
var
  tmp:cardinal;
begin
  result:=false;

  if not PatchGameSpy() then exit;
  if not PatchBanSystem() then exit;

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

  result:=true;
end;

//xrgame+38f610 - game_sv_mp::Player_AddBonusMoney
//xrgame+23be80 - CLevel::ClientSendProfileData
//xrgame+34f8f0 - game_PlayerState::net_Export

end.

