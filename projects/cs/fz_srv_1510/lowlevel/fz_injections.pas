unit fz_injections;
{$mode delphi}

interface
function Init():boolean; stdcall;

implementation
uses srcBase, basedefs, GameSpy, srcInjections, Voting, Console, BasicProtection, Chat, Players, ConfigMgr, LogMgr, Bans{, PacketFilter}, PlayerSkins, UpdateRate, ControlGUI, Servers, ServerStuff, misc_stuff, SACE_hacks, xrstrings, ge_filter;

function PatchBanSystem():boolean;
begin
  //������ ����� ������� � xrServer::ProcessClientDigest � �����:
  //P->r_stringZ	(xrCL->m_cdkey_digest);
	//P->r_stringZ	(secondary_cdkey);
  //���� ������ (��� �� ������� ��������) � �����, ����� �����
  //�� ��� ������ � ��� ����������� � ���������� � ����������� ��������� �� ����� CHALLENGE_RESPOND
  //[bug]������ ��� ����� ��� �������� ���, ��� ��� �����������������, � ���� �� �������� � ��������... ���������.
  //[bug] �� ���������, � xrCL->m_cdkey_digest �������� ������ ��� �� ������� ��������, �� ���� �� ����������� ���������!
  //������� - ������ ���, ����� � xrCL->m_cdkey_digest �������� ���������� � CHALLENGE_RESPOND ���
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$307AC7), @xrServer__ProcessClientDigest_ProtectFromKeyChange, 5,[F_RMEM+F_PUSH_EBP+$0C, F_PUSH_ECX, F_PUSH_ESI], false, false);
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$307B37),@xrServer__ProcessClientDigest_CheckAdditionalRejectingConditions,6,[F_PUSH_EDI],pointer(xrGame+$307B4C), JUMP_IF_FALSE, false, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$31D947), @xrServer__ProcessClientDigest_ProtectFromKeyChange, 5,[F_RMEM+F_PUSH_EBP+$0C, F_PUSH_ECX, F_PUSH_ESI], false, false);
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$31D9B7),@xrServer__ProcessClientDigest_CheckAdditionalRejectingConditions,6,[F_PUSH_EDI],pointer(xrGame+$31D9CC), JUMP_IF_FALSE, false, false);
  end;

  //����������� �� ��� ��������
  srcInjectionWithConditionalJump.Create(pointer(xrNetServer+$AE6F),@IPureServer__net_Handler_SubnetBans,5,[F_RMEM+F_PUSH_ESP+$0C],pointer(xrNetServer+$AE7F), JUMP_IF_TRUE, true, False);

  //��������� � ���, ��� IP ������� � ������� ��������
  srcBaseInjection.Create(pointer(xrNetServer+$AE7F),@IPureServer__net_Handler_OnBannedByGameIpFound,7,[F_RMEM+F_PUSH_ESP+$0C], true, False);

  //����������� ��� ������� �����
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
  //����� �����������
  //������� ������ �� ����� ���������� ������������� �� ���� ������ ������ (�����, ������� ������ � game_sv_mp::OnVoteStart)
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

  //�������� �� ����������� ������ ����������� � game_sv_mp::OnEvent
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30AE54),@CanSafeStartVoting,5,[F_PUSH_EBX, F_PUSH_ECX, F_RMEM+F_PUSH_ESP+$424],pointer(xrGame+$30B05E), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$320CA4),@CanSafeStartVoting,5,[F_PUSH_EBX, F_PUSH_ECX, F_RMEM+F_PUSH_ESP+$424],pointer(xrGame+$320EAE), JUMP_IF_FALSE, true, false);
  end;

  //������� sv_changelevel �� sv_changelevelgametype ���� � ���������� ���� ����� ��� ���� ��� ����� (game_sv_mp::OnVoteStart)
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$30cd63), @ProvideDefaultGameTypeForMapchangeVoting, 6,[], true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$322C03), @ProvideDefaultGameTypeForMapchangeVoting, 6,[], true, false);
  end;

  //[bug]����������� ������ �������� ������� � void game_sv_mp::UpdateVote(); ��-��������, ���� �� ��������� ����������, �� ����������, ���� �����������
  //������� ����������� �����������
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30D059),@IsVoteSuccess,94,[F_RMEM+F_PUSH_ESP+$1C, F_RMEM+F_PUSH_ESP+$20, F_RMEM+F_PUSH_ESP+$24],pointer(xrGame+$30D04F), JUMP_IF_TRUE, true, true);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$322EF9),@IsVoteSuccess,94,[F_RMEM+F_PUSH_ESP+$1C, F_RMEM+F_PUSH_ESP+$20, F_RMEM+F_PUSH_ESP+$24],pointer(xrGame+$322EEF), JUMP_IF_TRUE, true, true);
  end;

  //��������� ����������� �����������
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30D041),@IsVoteEarlyFail,5,[F_PUSH_EBP, F_RMEM+F_PUSH_ESP+$1C, F_RMEM+F_PUSH_ESP+$20, F_RMEM+F_PUSH_ESP+$24],pointer(xrGame+$30D0B7), JUMP_IF_TRUE, true, true);
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30D046),@IsVoteEarlySuccess,9,[F_PUSH_EBP, F_RMEM+F_PUSH_ESP+$1C, F_RMEM+F_PUSH_ESP+$20, F_RMEM+F_PUSH_ESP+$24],pointer(xrGame+$30D1BC), JUMP_IF_FALSE, true, true);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$322EE1),@IsVoteEarlyFail,5,[F_PUSH_EBP, F_RMEM+F_PUSH_ESP+$1C, F_RMEM+F_PUSH_ESP+$20, F_RMEM+F_PUSH_ESP+$24],pointer(xrGame+$322F57), JUMP_IF_TRUE, true, true);
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$322EE6),@IsVoteEarlySuccess,9,[F_PUSH_EBP, F_RMEM+F_PUSH_ESP+$1C, F_RMEM+F_PUSH_ESP+$20, F_RMEM+F_PUSH_ESP+$24],pointer(xrGame+$32305C), JUMP_IF_FALSE, true, true);
  end;

  //[bug] � SearcherClientByName::operator() ���������� ��������� ���� �������
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcEAXReturnerInjection.Create(pointer(xrGame+$2B2E38),@CarefullyComparePlayerNames,35,[F_PUSH_ECX, F_PUSH_EAX], true, true);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcEAXReturnerInjection.Create(pointer(xrGame+$2C5C38),@CarefullyComparePlayerNames,35,[F_PUSH_ECX, F_PUSH_EAX], true, true);
  end;

  //[bug] ���� ��� ������ ����������� �� ���/��� ������ ��������������� ������, �� ������ � ���������� ��������, ������������� ��� ������ �����������, �� ���������. ������� ������ �������! (����������� �� ����� ����� � �� ����!)
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30CCE6),@OnVoteStartIncorrectPlayerName,12,[F_PUSH_EBX],pointer(xrGame+$30CE93), JUMP_IF_FALSE, true, true);
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30CC5C),@OnVoteStartIncorrectPlayerName,12,[F_PUSH_EBX],pointer(xrGame+$30CE93), JUMP_IF_FALSE, true, true);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$322B86),@OnVoteStartIncorrectPlayerName,12,[F_PUSH_EBX],pointer(xrGame+$322D33), JUMP_IF_FALSE, true, true);
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$322AFC),@OnVoteStartIncorrectPlayerName,12,[F_PUSH_EBX],pointer(xrGame+$322D33), JUMP_IF_FALSE, true, true);
  end;

  //��������� ������������� �����������+ FZ'���� ���������� ����� + ��� �� IP � �����������
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcKit.nop_code(pointer(xrGame+$30CDC7), 2);
    srcBaseInjection.Create(pointer(xrGame+$30CDCF), @OnVoteStart, 13,[F_PUSH_EBX, F_RMEM+F_PUSH_EBP+$C, F_RMEM+F_PUSH_EBP+8, F_PUSH_EAX],true, true);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcKit.nop_code(pointer(xrGame+$322C67), 2);
    srcBaseInjection.Create(pointer(xrGame+$322C6F), @OnVoteStart, 13,[F_PUSH_EBX, F_RMEM+F_PUSH_EBP+$C, F_RMEM+F_PUSH_EBP+8, F_PUSH_EAX],true, true);
  end;

  //���������� ������ ��������������� (game_sv_mp::OnEvent)
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30AEA1),@OnVote,6,[F_PUSH_EBX, F_RMEM+F_PUSH_ESP+$424, F_PUSHCONST+1],pointer(xrGame+$30AEAC), JUMP_IF_FALSE, true, false);
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30AED5),@OnVote,6,[F_PUSH_EBX, F_RMEM+F_PUSH_ESP+$424, F_PUSHCONST+0],pointer(xrGame+$30AEE0), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$320CF1),@OnVote,6,[F_PUSH_EBX, F_RMEM+F_PUSH_ESP+$424, F_PUSHCONST+1],pointer(xrGame+$320CFC), JUMP_IF_FALSE, true, false);
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$320D25),@OnVote,6,[F_PUSH_EBX, F_RMEM+F_PUSH_ESP+$424, F_PUSHCONST+0],pointer(xrGame+$320D30), JUMP_IF_FALSE, true, false);
  end;

  //�� ���� ����� ���� � ������ ���������
  //[bug] ���� ������� ����������, � ����� - ������ ����������� ������� � ����
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcEAXReturnerInjection.Create(pointer(xrGame+$2F48F7),@IterateAndComparePlayersNames,5,[F_PUSH_EAX, F_RMEM+F_PUSH_ESP+0, F_RMEM+F_PUSH_ESP+8, F_RMEM+F_PUSH_ESP+4], true, true, 0);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcEAXReturnerInjection.Create(pointer(xrGame+$3098A7),@IterateAndComparePlayersNames,5,[F_PUSH_EAX, F_RMEM+F_PUSH_ESP+0, F_RMEM+F_PUSH_ESP+8, F_RMEM+F_PUSH_ESP+4], true, true, 0);
  end;

  result:=true;
end;


function PatchGameSpy():boolean;
begin
  //������ ��� ������� (� callback_serverkey)
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$321DCD), @WriteHostnameToClientRequest, 7, [F_PUSH_EAX, F_PUSH_ECX, F_PUSH_EDX], true, true);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$337F3D), @WriteHostnameToClientRequest, 7, [F_PUSH_EAX, F_PUSH_ECX, F_PUSH_EDX], true, true);
  end;

  //��������� ��� ����� �� ������������ ���� (� callback_serverkey)
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$321E07), @WriteMapnameToClientRequest, 7, [F_PUSH_EAX, F_PUSH_ECX, F_PUSH_EDX], true, true);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$337F77), @WriteMapnameToClientRequest, 7, [F_PUSH_EAX, F_PUSH_ECX, F_PUSH_EDX], true, true);
  end;

  //� gcd_authenticate_user ������ ����������� ���� ���������� ������� � ����� ������ �� �������...
  srcInjectionWithConditionalJump.Create(pointer(xrGameSpy+$B1E2),@IsSameCdKeyValidated,5,[],pointer(xrGameSpy+$B22D), JUMP_IF_TRUE, true, false);

  //...� ��������� �������� ������ � ��������
  srcInjectionWithConditionalJump.Create(pointer(xrGameSpy+$B2B7),@OnAuthSend,8,[F_PUSH_ESI],pointer(xrGameSpy+$B2CA), JUMP_IF_TRUE, true, false);

  // [bug] ��� � callback_playerkey - � index_searcher ������ ��������� �������, ��-�� ����� ������ ������� ���������� �����
  // ��� ��� ���������� ������������� ��� �������� ���� �� �� � ���� - �������� ����� FindClient �� ����
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcEAXReturnerInjection.Create(pointer(xrGame+$32259C), @index_searcher_client_finder, 5, [F_RMEM+F_PUSH_EAX], true, true);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcEAXReturnerInjection.Create(pointer(xrGame+$33870C), @index_searcher_client_finder, 5, [F_RMEM+F_PUSH_EAX], true, true);
  end;

  result:=true;
end;

function PatchChat():boolean;
begin
  result:=false;

  //���������� ����� ������ � xrServer::OnMessage, ������ ������� � ������, ���������� ����� ������ ��� ��������� �� ����� ��������
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2C8190),@OnChatMessage_ValidateAndChange,6,[F_PUSH_EBP, F_PUSH_EDI, F_PUSH_EAX],pointer(xrGame+$2C819B), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2DD200),@OnChatMessage_ValidateAndChange,6,[F_PUSH_EBP, F_PUSH_EDI, F_PUSH_EAX],pointer(xrGame+$2DD20B), JUMP_IF_FALSE, true, false);
  end;

  //������ ����������� ���������� � ��� ��������� �� ����� ������� � ������������
  if FZConfigMgr.Get.GetBool('unlimited_chat_for_dead', true) then begin
    if xrGameDllType()=XRGAME_SV_1510 then begin
      srcKit.Get.nop_code(pointer(xrGame+$2CA859), 25);
    end else if xrGameDllType()=XRGAME_CL_1510 then begin
       srcKit.Get.nop_code(pointer(xrGame+$2DF7B9), 25);
    end;
  end;

  //���������� ��� � ����� � game_sv_mp::OnEvent;
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30AF59),@OnPlayerSpeechMessage,6,[F_PUSH_EBX, F_PUSH_EDX, F_PUSH_ECX],pointer(xrGame+$30AF5F), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$320DA9),@OnPlayerSpeechMessage,6,[F_PUSH_EBX, F_PUSH_EDX, F_PUSH_ECX],pointer(xrGame+$320DAF), JUMP_IF_FALSE, true, false);
  end;


  //������ ��� ������������ � game_sv_mp::SvSendChatMessage
  if xrGameDllType()=XRGAME_SV_1510 then begin
    if not srcKit.Get.CopyBuf(@ServerAdminName, pointer(xrGame+$30FFB3), sizeof(pointer)) then exit;
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    if not srcKit.Get.CopyBuf(@ServerAdminName, pointer(xrGame+$325E53), sizeof(pointer)) then exit;
  end;


  //� game_sv_mp::SvSendChatMessage ������� ����� ����������� ����
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

  //� ������� PlayerState � ��� ������ ���� ���������� �����, � ������� ��������� ������ ����� ������
  //�������� ���� ������ � ���.
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$2CB170), @FromPlayerStateConstructor, 6, [F_PUSH_EDI], false, false);
    srcBaseInjection.Create(pointer(xrGame+$2CB187), @FromPlayerStateClear, 6, [F_PUSH_ECX], false, false);
    srcBaseInjection.Create(pointer(xrGame+$2CB270), @FromPlayerStateDestructor, 6, [F_PUSH_ESI], false, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$2E0180), @FromPlayerStateConstructor, 6, [F_PUSH_EDI], false, false);
    srcBaseInjection.Create(pointer(xrGame+$2E0197), @FromPlayerStateClear, 6, [F_PUSH_ECX], false, false);
    srcBaseInjection.Create(pointer(xrGame+$2E0280), @FromPlayerStateDestructor, 6, [F_PUSH_ESI], false, false);
  end;

  //[bug] ����� ����� ������� ��� �������� ��� (��������, �� ������������) - ��� ������ ���������� ��� ��������� �� ����.
  //��, ��� ��������, � game_sv_mp::SendPlayerKilledMessage, CActor::OnHitHealthLoss, CActor::OnCriticalHitHealthLoss,
  //������ ������ � ������ ���������, � ������ ��������� ������� ��� ������ � �� �������� 0.
  //������������ �� �������������� �� ��������� -1. ������ �������� - ����� ����� �� ��� ������
  //��������, ���� ���� �� �������� � �������� ���������� ������� - ������� �����.
  //������� - ����������� ������� �� ����� �� ��� ������ (xrGameSpyServer::xrGameSpyServer), ����� ������ �� ������ �� ��������.
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$38C164), @xrGameSpyServer_constructor_reserve_zerogameid, 6, [F_PUSH_ESI], false, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$3A2674), @xrGameSpyServer_constructor_reserve_zerogameid, 6, [F_PUSH_ESI], false, false);
  end;

  //���������� ��������������� ����� ������� �������
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30e239),@game_sv_mp__OnPlayerGameMenu_isteamchangeblocked,6,[F_RMEM+F_PUSH_ESP+$10, F_PUSH_EDI], pointer(xrGame+$30e24b), JUMP_IF_TRUE, false, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$3240d9),@game_sv_mp__OnPlayerGameMenu_isteamchangeblocked,6,[F_RMEM+F_PUSH_ESP+$10, F_PUSH_EDI], pointer(xrGame+$3240eb), JUMP_IF_TRUE, false, false);
  end;

  //��������� ���������
  if xrGameDllType()=XRGAME_SV_1510 then begin
    //game_sv_TeamDeathmatch::OnPlayerKillPlayer
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$308604),@OnTeamKill, 44,[F_PUSH_ESI, F_PUSH_EBX], pointer(xrGame+$3086e1), JUMP_IF_FALSE, false, true);
    //game_sv_CaptureTheArtefact::OnKillResult (����� �� ��������� ������ ����������� �������, ��� ��� �������� ����������)
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$3177ec),@OnTeamKill, 38,[F_PUSH_ESI, F_RMEM+F_PUSH_EBP+$10], pointer(xrGame+$3178ac), JUMP_IF_FALSE, false, true);
    //� game_sv_TeamDeathmatch::OnPlayerConnectFinished ������� ��������� m_iTeamKills � ����� ������
    srcKit.Get().nop_code(pointer(xrGame+$308324), 6);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    //game_sv_TeamDeathmatch::OnPlayerKillPlayer
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$31e484),@OnTeamKill, 44,[F_PUSH_ESI, F_PUSH_EBX], pointer(xrGame+$31e561), JUMP_IF_FALSE, false, true);
    //game_sv_CaptureTheArtefact::OnKillResult (����� �� ��������� ������ ����������� �������, ��� ��� �������� ����������)
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$32d64c),@OnTeamKill, 38,[F_PUSH_ESI, F_RMEM+F_PUSH_EBP+$10], pointer(xrGame+$32d70c), JUMP_IF_FALSE, false, true);
    //� game_sv_TeamDeathmatch::OnPlayerConnectFinished ������� ��������� m_iTeamKills � ����� ������
    srcKit.Get().nop_code(pointer(xrGame+$31e1a4), 6);
  end;

  //[bug] ��� - ����� ����� ������ ���� �������� (��� ������� �� ���� ���������), �� ������ ���� ���-���� ��������.
  //���������� ��� �����, ����� ����� � �����. �������, ���� �� �����, � ���, ��� ��������� ���� armor_piercing � power_critical �� ���������� � ����������� ����� � ������,
  //��� ����� � ������������� ����� ���.
  if xrGameDllType()=XRGAME_SV_1510 then begin
    //game_sv_TeamDeathmatch::OnPlayerHitPlayer_Case - ����� ��������� (friendly fire)
    srcBaseInjection.Create(pointer(xrGame+$30889f), @OnTeamHit_FriendlyFire, 82, [F_PUSH_EAX, F_PUSH_EBX, F_PUSH_EDI], false, true);
    //game_sv_CaptureTheArtefact::OnPlayerHitPlayer_Case - ����� ��������� (friendly fire)
    srcBaseInjection.Create(pointer(xrGame+$317e07), @OnTeamHit_FriendlyFire, 46, [F_PUSH_EAX, F_PUSH_ECX, F_PUSH_ESI], false, true);
    //game_sv_TeamDeathmatch::OnPlayerHitPlayer_Case - ��������� ��������� � ���������� ������� (����������� ����������� - ���������� ����� �� game_sv_Deathmatch)
    srcBaseInjection.Create(pointer(xrGame+$308902), @OnHitInvincible, 13, [F_PUSH_EDI], false, true);
    //game_sv_Deathmatch::OnPlayerHitPlayer_Case - ��������� ��������� � ���������� �������
    srcBaseInjection.Create(pointer(xrGame+$3014c9), @OnHitInvincible, 13, [F_PUSH_EAX], false, true);
    //game_sv_CaptureTheArtefact::OnPlayerHitPlayer_Case - ��������� ��������� � ���������� �������
    srcBaseInjection.Create(pointer(xrGame+$317e3f), @OnHitInvincible, 13, [F_PUSH_ESI], false, true);
    //game_sv_ArtefactHunt::OnPlayerHitPlayer_Case - ��������� ��������� � ���������� �������
    srcBaseInjection.Create(pointer(xrGame+$2FDEFB), @OnHitInvincible, 13, [F_PUSH_EDI], false, true);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    //game_sv_TeamDeathmatch::OnPlayerHitPlayer_Case - ����� ��������� (friendly fire)
    srcBaseInjection.Create(pointer(xrGame+$31e71f), @OnTeamHit_FriendlyFire, 82, [F_PUSH_EAX, F_PUSH_EBX, F_PUSH_EDI], false, true);
    //game_sv_CaptureTheArtefact::OnPlayerHitPlayer_Case - ����� ��������� (friendly fire)
    srcBaseInjection.Create(pointer(xrGame+$32DC67), @OnTeamHit_FriendlyFire, 46, [F_PUSH_EAX, F_PUSH_ECX, F_PUSH_ESI], false, true);
    //game_sv_TeamDeathmatch::OnPlayerHitPlayer_Case - ��������� ��������� � ���������� ������� (����������� ����������� - ���������� ����� �� game_sv_Deathmatch)
    srcBaseInjection.Create(pointer(xrGame+$31e782), @OnHitInvincible, 13, [F_PUSH_EDI], false, true);
    //game_sv_Deathmatch::OnPlayerHitPlayer_Case - ��������� ��������� � ���������� �������
    srcBaseInjection.Create(pointer(xrGame+$316629), @OnHitInvincible, 13, [F_PUSH_EAX], false, true);
    //game_sv_CaptureTheArtefact::OnPlayerHitPlayer_Case - ��������� ��������� � ���������� �������
    srcBaseInjection.Create(pointer(xrGame+$32DC9F), @OnHitInvincible, 13, [F_PUSH_ESI], false, true);
    //game_sv_ArtefactHunt::OnPlayerHitPlayer_Case - ��������� ��������� � ���������� �������
    srcBaseInjection.Create(pointer(xrGame+$312FDB), @OnHitInvincible, 13, [F_PUSH_EDI], false, true);
  end;

  //�������� ����� �����
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$30e7b0), @game_sv_mp__Player_AddExperience_expspeed, 5, [F_PUSH_ESP+$8], true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$324650), @game_sv_mp__Player_AddExperience_expspeed, 5, [F_PUSH_ESP+$8], true, false);
  end;

  //������������ �������
  if xrGameDllType()=XRGAME_SV_1510 then begin
    //� operator() �� �������� � game_sv_Deathmatch::check_InvinciblePlayers ���������� ����������� �������� �� ������������, ���� ��� �������������� ����
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$304DD8),@IsInvincibilityControlledByFZ, 6,[F_PUSH_ESI], pointer(xrGame+$304E02), JUMP_IF_TRUE, true, false);
    //� game_sv_ArtefactHunt::OnPlayerHitPlayer_Case ��������� �������� �� ����������� ������������, ����� ��� �� ��������� �� �����
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2fdee3),@IsInvincibilityControlledByFZ, 6,[F_PUSH_EBX], pointer(xrGame+$2fdf08), JUMP_IF_TRUE, true, false);
    //�������� �� ������������� �������� ������������ � game_sv_Deathmatch::OnPlayerFire (� CTA ������� � ��� �� ���������� ���� ������������)
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$303ca1),@IsInvinciblePersistAfterShot, 6,[F_PUSH_EAX], pointer(xrGame+$303ccf), JUMP_IF_TRUE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    //� operator() �� �������� � game_sv_Deathmatch::check_InvinciblePlayers ���������� ����������� �������� �� ������������, ���� ��� �������������� ����
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$319f38),@IsInvincibilityControlledByFZ, 6,[F_PUSH_ESI], pointer(xrGame+$319f62), JUMP_IF_TRUE, true, false);
    //� game_sv_ArtefactHunt::OnPlayerHitPlayer_Case ��������� �������� �� ����������� ������������, ����� ��� �� ��������� �� �����
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$312fc3),@IsInvincibilityControlledByFZ, 6,[F_PUSH_EBX], pointer(xrGame+$312fe8), JUMP_IF_TRUE, true, false);
    //�������� �� ������������� �������� ������������ � game_sv_Deathmatch::OnPlayerFire (� CTA ������� � ��� �� ���������� ���� ������������)
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$318e01),@IsInvinciblePersistAfterShot, 6,[F_PUSH_EAX], pointer(xrGame+$318e2f), JUMP_IF_TRUE, true, false);
  end;

  result:=true;
end;

function PatchSaceFakers():boolean;
begin
  //�������� �� ��, ��� DPN_MSGID_ENUM_HOSTS_QUERY � ToConnect �� ��� ��������� SACE ( � IPureServer::net_Handler)
  srcInjectionWithConditionalJump.Create(pointer(xrNetServer+$AC60),@IPureServer__net_Handler_isToConnectsentbysace,15,[F_PUSH_ECX], pointer(xrNetServer+$AE8D), JUMP_IF_TRUE, true, false);
  result:=true;
end;

function PatchShop():boolean;
begin
  //[bug] ��� � �������� ���� �������� ��� ������ ��-�� ����������������� ��������� ���������� �������� ���������� ������ GAME_EVENT_PLAYER_READY (� game_sv_mp::OnEvent)
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30ADE2),@CheckPlayerReadySignalValidity,6,[F_PUSH_EAX], pointer(xrGame+$30ADF0), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$320C32),@CheckPlayerReadySignalValidity,6,[F_PUSH_EAX], pointer(xrGame+$320C40), JUMP_IF_FALSE, true, false);
  end;

  //� �� �� ��������� ��� �������� � ��������� ��������� � ��������� ��������������. �������� � ���, ��� �������� ���������� ����� ������������ ����� ������������ ������ �� ������.
  //������� ������� ������ DestroyAllPlayerItems �� OnPlayerBuyFinished
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

  //������ ������� �������� ����� �� ������� ����� ����, ��� ������ �������� ��������� ������ (����� ������� SpawnWeaponsForActor). ����� ��������, ��� ������ ���������.
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

  //[bug] ��� ���������� �������� ��������������� �������� � ������ ������ ���� �������, � ������ ����� ���� ������������, ���� �������� ������. ������ � game_sv_xxx::SpawnWeaponsForActor
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

  //[bug] ���� ��������� game_cl_xxx::CanCallBuyMenu �� ���������� ����������� true, ����� ���������� �������� ������ � �����. ���������.
  //��� ����������� ��������� � game_sv_xxx::OnEvent, ��� ����� �� ����. � �� � ��� ��� ���, ��� ��� � ���������� �� ������
  if xrGameDllType()=XRGAME_SV_1510 then begin
    //DM - game_sv_Deathmatch::OnEvent
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$305f52),@CanPlayerBuyNow,6,[F_PUSH_EAX],pointer(xrGame+$305f6a), JUMP_IF_FALSE, true, false);
    //CTA - game_sv_CaptureTheArtefact::OnEvent
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$31c87a),@CanPlayerBuyNow,6,[F_PUSH_EAX],pointer(xrGame+$31c88a), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    //DM - game_sv_Deathmatch::OnEvent
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$31B0B2),@CanPlayerBuyNow,6,[F_PUSH_EAX],pointer(xrGame+$31b0ca), JUMP_IF_FALSE, true, false);
    //CTA - game_sv_CaptureTheArtefact::OnEvent
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$33259a),@CanPlayerBuyNow,6,[F_PUSH_EAX],pointer(xrGame+$3325aa), JUMP_IF_FALSE, true, false);
  end;

  //[bug] ������ � ah/cta ��������� � ������ ��������� ��������. � ������, ����� ������ �������� ������ ���� ����� ������� ������� ��������, �� ������� �������� ������������ � ������� ��������! �� ����, �� ����� �������... �������������� ����������, ���� �������� ����� "����������" �������� ������, ��� �����.
  //���������� game_sv_mp::ChargeAmmo, ����� � ������ ah � cta ��� ������ ���������� false
  //� ������ ����� �� ���������� - ���� �������������� ����� CanChargeFreeAmmo � ���������� �������.
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30BE80),@IsSpawnFreeAmmoAllowedForGametype,5,[F_PUSH_ECX], pointer(xrGame+$30BE93), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$321CD0),@IsSpawnFreeAmmoAllowedForGametype,5,[F_PUSH_ECX], pointer(xrGame+$321ce3), JUMP_IF_FALSE, true, false);
  end;

  //[bug] ����� ����� � AH/CTA ��������� (� ���������� ������� ������� 9�18), �� � ��������� � ���� ����������� ����������� ������ ��������, ��� ������ ���� � 2� ������
  //���� � ���, ��� � mp_weapon_knife �������� ��� �� ����� ��� "��������"! � SetAmmoForWeapon, ������ ��� �������, �������� ������� � � ����. �� ��� ���������� ����� �����
  //���������� ������ ����� ��������, ��� ��� � ���� ������ ��� ����������� � ����� ����� ������ ��� ������, � �������� ��� ���� ���� ������ �� �������.
  //�������: � game_sv_mp::SpawnWeapon4Actor����� ������� SetAmmoForWeapon ����� ����������� �� � CSE_ALifeItemWeapon, � � CSE_ALifeItemWeaponMagazined, ��� ����� ������� ����.
  //��, � ���������, � ��� �� ������������ ����������� �����, ������� ������� �������� �� CLSID.
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30C443),@IsWeaponKnife,11,[F_PUSH_ESI], pointer(xrGame+$30c473), JUMP_IF_TRUE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$322293),@IsWeaponKnife,11,[F_PUSH_ESI], pointer(xrGame+$3222c3), JUMP_IF_TRUE, true, false);
  end;

  result:=true;
end;

function PatchHits():boolean;
begin
  //[bug] � xrServer::Process_event ��� ��������� ��������� GE_HIT ��� GE_HIT_STATISTIC � ������� ���������� ��������� ���������� ������� ID, ��� �� ���� ��������� ����
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$38a4f3),@AssignDwordFromPtrToDwordFromPtr,6,[F_PUSH_EBP+$8, F_PUSH_ESP+$C], true, false);
    srcBaseInjection.Create(pointer(xrGame+$38a507),@AssignDwordFromPtrToDwordFromPtr,6,[F_PUSH_EBP+$8, F_PUSH_ESP+$C], true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$3a0933),@AssignDwordFromPtrToDwordFromPtr,6,[F_PUSH_EBP+$8, F_PUSH_ESP+$C], true, false);
    srcBaseInjection.Create(pointer(xrGame+$3a0947),@AssignDwordFromPtrToDwordFromPtr,6,[F_PUSH_EBP+$8, F_PUSH_ESP+$C], true, false);
  end;

  //[bug] � ����������� GAME_EVENT_ON_HIT (game_sv_GameState::OnEvent) ���� ���������, ��� ��� �������� �� ��� ��� �� �� ���������� �������. �� � ������ ��������� ����������/���������� ����
  //����� ����, ���� ��������� � ���, ��� �� ��������� ��� ������� (�� ��� ��� ������� � ���������), ����� �������� �����.
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2f3919),@OnGameEventDelayedHitProcessing,5,[F_PUSH_ESI, F_PUSH_EBP, F_PUSH_EBX, F_RMEM+F_PUSH_ESP+$434], pointer(xrGame+$2f3938), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$308889),@OnGameEventDelayedHitProcessing,5,[F_PUSH_ESI, F_PUSH_EBP, F_PUSH_EBX, F_RMEM+F_PUSH_ESP+$434], pointer(xrGame+$3088A8), JUMP_IF_FALSE, true, false);
  end;

  //[bug] CDestroyablePhysicsObject::Hit �� ����� � ����, ��� HDS.who ����� null. ������ ������ - ������� ����������� ��� ��� ����� �������� �������������
  //��� ������� ������ �� �����, �� ��� �������������� ������ �� �������� ������ ����� ������������, ����� ���������� ������
  //  //(����: ��������� �����; ������� � �����/�����, ����� �����, ������� �� ��� ����; �� ��������� ������, ����� g_kill � ������� � �����; ���� ����� ����� ����������, ��� ����������)
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$218105),@IsArgNull,7,[F_PUSH_EAX], pointer(xrGame+$21825c), JUMP_IF_TRUE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$22A735),@IsArgNull,7,[F_PUSH_EAX], pointer(xrGame+$22a88c), JUMP_IF_TRUE, true, false);
  end;

  //[bug] ����������, �� ����� � ����, ��� HDS.who ����� null � CExplosiveItem::Hit
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$27C34B),@IsArgNull,7,[F_PUSH_EDX], pointer(xrGame+$27C352), JUMP_IF_TRUE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$28EE3B),@IsArgNull,7,[F_PUSH_EDX], pointer(xrGame+$28EE42), JUMP_IF_TRUE, true, false);
  end;

  //[bug] GAME_EVENT_PLAYER_HITTED ����� �������� ������ ��������� ������. ��������� � game_sv_mp::OnEvent
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30ad8f),@OnGameEventPlayerHitted,7,[F_RMEM+F_PUSH_ESP+$418, F_RMEM+F_PUSH_ESP+$424], pointer(xrGame+$30adb6), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$320bdf),@OnGameEventPlayerHitted,7,[F_RMEM+F_PUSH_ESP+$418, F_RMEM+F_PUSH_ESP+$424], pointer(xrGame+$320c06), JUMP_IF_FALSE, true, false);
  end;

  result:=true;
end;

function PatchKillsAndCorpses():boolean;
begin

  //[bug] � xrServer::Process_event ��� ��������� ��������� GE_DIE (Line 212) ��� �������� �� ��, ��� c_src != null � c_src->owner != null
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$38a618),@Check_xrClientData_owner_valid,6,[F_PUSH_EDI], pointer(xrGame+$38a676), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$3a0a58),@Check_xrClientData_owner_valid,6,[F_PUSH_EDI], pointer(xrGame+$3a0ab6), JUMP_IF_FALSE, true, false);
  end;

  //[bug] GAME_EVENT_PLAYER_KILLED ����� �������� ������ ��������� ������. ����� �� �� ����� ���� ���������� ��� �������. ��������� � game_sv_mp::OnEvent
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30ad5c),@OnGameEventPlayerKilled,7,[F_RMEM+F_PUSH_ESP+$418, F_RMEM+F_PUSH_ESP+$424], pointer(xrGame+$30ad83), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$320bac),@OnGameEventPlayerKilled,7,[F_RMEM+F_PUSH_ESP+$418, F_RMEM+F_PUSH_ESP+$424], pointer(xrGame+$320bd3), JUMP_IF_FALSE, true, false);
  end;

  //[bug] � game_sv_xxx::OnEvent ��� ������� GAME_EVENT_PLAYER_KILL (������������) ����������� �������� �� ��, ��� ������� ������ ����������� ������
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

  //[bug] ����������� ���� � ���������. � game_sv_mp::Update ����������� ����, ��������� ��� "������" ����� ����� ������ �� m_CorpseList.
  //��� ����� �� ������� - �������� ��������� � ���, ��� ������ �������� ��������, ����� ���������� ��� ������ �� ���������� m_CorpseList.
  //��! �� ����� �������� ���������� game_sv_mp::OnDestroyObject (��� ��� �������), � ������� ������������ ����� �� ���������� ����� �� �������, �
  //����������� ��� ��������. ����� �������, � game_sv_mp::Update ��������� ������������� ������ �������, ��� ����� � ����� � ������ ������.
  //�������� ���������� ��, ��� � game_sv_mp::OnPlayerDisconnect �� �������� �������� �� ��, ������� ��� ����� ��� �����������, � � m_CorpseList
  //������������ ����������, ���� ��������������� ��� ��! ����� �������, ���� ���������� ������ ��� ������ sv_remove_corpse 0 �� ������� �� �����.
  //������� - �� ��������, � game_sv_mp::Update ���� ������ �������� ����� find, �� ����� � ������ �������� - ���� �� ����� (��� � �������).
  //����� ���� �� ���������� ���������� ������ � game_sv_mp::OnPlayerDisconnect, ����� ���������� ��������� ����� (����� �������� GE_DESTROY). ��, ���
  //��� ��� �� �������� - ������ ���� �� �����.
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcKit.Get.nop_code(pointer(xrGame+$30A754), $56);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcKit.Get.nop_code(pointer(xrGame+$3205A4), $56);
  end;

  //[bug] � game_sv_Deathmatch::OnDetach � game_sv_CaptureTheArtefact::OnDetach ����� ��������� �� ������������ �� � ������ ������������ � ������,
  //�� � ������ ���������. ��-�� ����� ��� �������� � �����, ����������� ��� �������� � ������ � ������� ���� � �������.
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

  //[bug] � game_sv_Deathmatch::OnDetach �� ���������� �������� ���������, ��� �������� � �����
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$303147),@game_sv_Deathmatch__OnDetach_destroyitems,8,[F_RMEM+F_PUSH_ESP+$10, F_RMEM+F_PUSH_ESP+$34, F_RMEM+F_PUSH_ESP+$38], true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$3182a7),@game_sv_Deathmatch__OnDetach_destroyitems,8,[F_RMEM+F_PUSH_ESP+$10, F_RMEM+F_PUSH_ESP+$34, F_RMEM+F_PUSH_ESP+$38], true, false);
  end;

  //[bug] ���� � ����� �������� �������� ��������, ��� ������������ ��� �������� � �������� ���� � ������� � game_sv_mp::Update
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

  //������ ����������� ������� � ���� ������ � ��������� ����� - ��������� �������� modify_player_name
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$474760),@modify_player_name,6,[F_PUSH_EAX, F_PUSH_EDI], true, true);
    if not srcKit.Get.nop_code(pointer(xrGame+$474766), 1, chr($C3)) then exit; //������ ������� ����� ����� ���������� ����� �������
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$48A8E0),@modify_player_name,6,[F_PUSH_EAX, F_PUSH_EDI], true, true);
    if not srcKit.Get.nop_code(pointer(xrGame+$48A8E6), 1, chr($C3)) then exit; //������ ������� ����� ����� ���������� ����� �������
  end;

  //�������� ������� ������ � ����� ������ � game_sv_mp::OnEvent
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30AF2B),@CheckIfPacketZStringIsLesserThen,6,[F_PUSH_ECX, F_PUSHCONST+20, F_PUSH_EAX, F_PUSHCONST+1, F_PUSHCONST+$0836, F_PUSHCONST+1], pointer(xrGame+$30AF37), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$320D7B),@CheckIfPacketZStringIsLesserThen,6,[F_PUSH_ECX, F_PUSHCONST+20, F_PUSH_EAX, F_PUSHCONST+1, F_PUSHCONST+$0836, F_PUSHCONST+1], pointer(xrGame+$320D87), JUMP_IF_FALSE, true, false);
  end;


  //[bug]������ �� stalkazz - � xrGameSpyServer::OnMessage ����������, ��� ����� ������ � ������ M_GAMESPY_CDKEY_VALIDATION_CHALLENGE_RESPOND ������, ��� ������ ������
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$38C7E2),@CheckIfPacketZStringIsLesserThanWithDisconnect,7,[F_PUSH_EBX, F_PUSHCONST+128, F_PUSH_ESI, F_PUSHCONST+$16, F_PUSHCONST+1], pointer(xrGame+$38C7D5), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$3A2CF2),@CheckIfPacketZStringIsLesserThanWithDisconnect,7,[F_PUSH_EBX, F_PUSHCONST+128, F_PUSH_ESI, F_PUSHCONST+$16, F_PUSHCONST+1], pointer(xrGame+$3A2CE5), JUMP_IF_FALSE, true, false);
  end;

  //��������� �������� ��������
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

  //��������� �������� �������: CSE_Abstract, team, skin
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30B556),@OnSetPlayerSkin,7,[F_PUSH_ESI, F_PUSH_ECX, F_PUSH_EAX], pointer(xrGame+$30B55D), JUMP_IF_TRUE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$3213A6),@OnSetPlayerSkin,7,[F_PUSH_ESI, F_PUSH_ECX, F_PUSH_EAX], pointer(xrGame+$3213AD), JUMP_IF_TRUE, true, false);
  end;

  //������� ������ ����������� ������� (game_sv_mp::SpawnWeapon4Actor)
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcEAXReturnerInjection.Create(pointer(xrGame+$30C419),@OnActorItemSpawn_ChangeItemSection,5,[F_PUSH_ECX, F_RMEM+F_PUSH_EBP+08, F_PUSH_EAX, F_RMEM+F_PUSH_EBP+$C], true, false, 0);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcEAXReturnerInjection.Create(pointer(xrGame+$322269),@OnActorItemSpawn_ChangeItemSection,5,[F_PUSH_ECX, F_RMEM+F_PUSH_EBP+08, F_PUSH_EAX, F_RMEM+F_PUSH_EBP+$C], true, false, 0);
  end;


  if FZConfigMgr.Get.GetBool('patch_updrate', true) then begin
    //dynamic update rate - ���� � IPureServer::HasBandwidth
    srcECXReturnerInjection.Create(pointer(xrNetServer+$B27A),@SelectUpdRate,6,[F_PUSH_EDI,F_RMEM+F_PUSH_ESP+$10, F_PUSH_ECX], false, false, 0);
  end;

  //������� �������� ������� �� �������� � ������� ������������� � xrServer::Process_event
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

  //����� �������� �������������� � �����
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2C8C22),@OnPingWarn,6,[F_PUSH_EDI], pointer(xrGame+$2C8CE0), JUMP_IF_FALSE, false, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2DDC52),@OnPingWarn,6,[F_PUSH_EDI], pointer(xrGame+$2DDD10), JUMP_IF_FALSE, false, false);
  end;

  //[bug]��������� ����� ����� ���������� �������� - ��� ��� �� ������� �����������
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30DF20),@CanChangeName,6,[F_PUSH_ESI], pointer(xrGame+$30DFA5), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$323DC0),@CanChangeName,6,[F_PUSH_ESI], pointer(xrGame+$323E45), JUMP_IF_FALSE, true, false);
  end;

  //������� ������ �������� ������������� ����� ��������
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$30797C),@OnAttachNewClient,5,[F_PUSH_EDI, F_PUSH_ESI], true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$31D7FC),@OnAttachNewClient,5,[F_PUSH_EDI, F_PUSH_ESI], true, false);
  end;

  //�������, ����� ������ ������������ ����������� � �����  � ���� - � xrServer::OnMessage M_CLIENTREADY
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$2c8063),@OnClientReady,6,[F_PUSH_EBP, F_PUSH_EBX], true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$2dd0d3),@OnClientReady,6,[F_PUSH_EBP, F_PUSH_EBX], true, false);
  end;

  //[bug] �������� ������� - ������� PlayerState, ���� ������ ������ �� �����������
  //���� ����������� �������� ������� ����� ��� ������ �� ������
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2c72e6),@xrServer__client_Destroy_force_destroy,6,[F_PUSH_EDI], pointer(xrGame+$2C7314), JUMP_IF_TRUE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2dc356),@xrServer__client_Destroy_force_destroy,6,[F_PUSH_EDI], pointer(xrGame+$2DC384), JUMP_IF_TRUE, true, false);
  end;

  //� xrServer::Connect ��� ���� �������� ����������� ��� �����
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$30760d),@xrServer__Connect_updatemapname,5,[F_PUSH_EDI], false, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$31d48d),@xrServer__Connect_updatemapname,5,[F_PUSH_EDI], false, false);
  end;

  //�������� �������������� ����� ����� ����� � ������
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$1d629f),@CLevel__net_Start_overridelevelgametype,8,[], false, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$1e833f),@CLevel__net_Start_overridelevelgametype,8,[], false, false);
  end;

  //[bug] ��� �� ������ ���... ���� � IPureServer::SendTo_LL : ������� ������ ��� �������������� �������, ��� ���� ��� ��� - �� � ���� � ���, ��������� ���-������ :)
  if not srcKit.Get.nop_code(pointer(xrNetServer+$B098), 1, chr($EB)) then exit;

  //[bug] ������ � ��������������: IPureServer::DisconnectClient ������� ������� �����������, �� �������� ������. ����� ���, � ������������� ������� ��� ����� ���������� �����, ��� ������� ��������
  //���������, ������, �� ���������. �� ����� ��������� ������� ������.
  //�������� � game_sv_mp::OnEvent (� �����������), ���������� �� ��� ������, ����� ���, ��� ��������� �������� (��� ��� � ��� "����������" ������� �������, �� ������� ��������� ��������� �� ������� ��������� ������ ��� ��������)
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

  //[bug] � game_sv_GameState::OnEvent ����� R_ASSERT ������ �� ��������� - ������������� ����� �������� �������� ������ � ��� �������.
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$2f39c2), @OnGameEventNotImplenented, 60, [F_RMEM+F_PUSH_ESP+$420, F_RMEM+F_PUSH_ESP+$424, F_RMEM+F_PUSH_ESP+$42c], true, true);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$308932), @OnGameEventNotImplenented, 60, [F_RMEM+F_PUSH_ESP+$420, F_RMEM+F_PUSH_ESP+$424, F_RMEM+F_PUSH_ESP+$42c], true, true);
  end;

  //� xrServer::client_Destroy - ��������� �������� �� ������� ������
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$2c7070),@LockServerPlayers,6,[], false, false);
    srcBaseInjection.Create(pointer(xrGame+$2c7336),@UnlockServerPlayers,5,[], true, false);
    srcBaseInjection.Create(pointer(xrGame+$2c730b),@UnlockServerPlayers,5,[], true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$2dc0e0),@LockServerPlayers,6,[], false, false);
    srcBaseInjection.Create(pointer(xrGame+$2dc3a6),@UnlockServerPlayers,5,[], true, false);
    srcBaseInjection.Create(pointer(xrGame+$2dc37b),@UnlockServerPlayers,5,[], true, false);
  end;

  //� game_sv_GameState::OnEvent - ��������� ���� ������� ������� ��� ��������� GAME_EVENT_CREATE_CLIENT
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$2f3945),@LockServerPlayers,7,[], false, false);
    srcKit.Get().nop_code(pointer(xrGame+$2f395e), 1, CHR($14));
    srcBaseInjection.Create(pointer(xrGame+$2f3975),@UnlockServerPlayers,6,[], true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$3088b5),@LockServerPlayers,7,[], false, false);
    srcKit.Get().nop_code(pointer(xrGame+$3088ce), 1, CHR($14));
    srcBaseInjection.Create(pointer(xrGame+$3088e5),@UnlockServerPlayers,6,[], true, false);
  end;

  //[bug] � IPureServer::GetClientAddress ����� ��������� ������� pClientAddress (� ������ ����������� � ���� ������), ��� ����������� ��� ������. �����������.
  srcInjectionWithConditionalJump.Create(pointer(xrNetServer+$b570),@IPureServer__GetClientAddress_check_arg, 6,[F_RMEM+F_PUSH_ESP+4, F_RMEM+F_PUSH_ESP+8, F_RMEM+F_PUSH_ESP+$c], pointer(xrNetServer+$b651), JUMP_IF_FALSE, true, false);

  //��������� � xrServer::OnMessage �������������� ����������, ������������� ����� ����; ��� ����� ������ �������������� �������
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$2c8457),@xrServer__OnMessage_additional,10,[F_PUSH_EBP, F_PUSH_EDI, F_PUSH_ESI], true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$2dd4c7),@xrServer__OnMessage_additional,10,[F_PUSH_EBP, F_PUSH_EDI, F_PUSH_ESI], true, false);
  end;

  //� xrServer::OnCL_Disconnected ����� � ����� ������ ��� � ������ ���� ������ ��� ��������� �� ��������������
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$30714c),@xrServer__OnCL_Disconnected_appendToPacket,6,[F_PUSH_ECX, F_PUSH_ESP, F_PUSH_EBX], true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$31cfcc),@xrServer__OnCL_Disconnected_appendToPacket,6,[F_PUSH_ECX, F_PUSH_ESP, F_PUSH_EBX], true, false);
  end;

  //���� � ������� ������ ��� - � game_sv_mp::OnPlayerDisconnect �� ���������� ������ ������� ��������� � �����������
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$30B777),@game_sv_mp__OnPlayerDisconnect_is_message_needed, 7,[F_PUSH_EAX], pointer(xrGame+$30b7a5), JUMP_IF_FALSE, false, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$3215c7),@game_sv_mp__OnPlayerDisconnect_is_message_needed, 7,[F_PUSH_EAX], pointer(xrGame+$3215f5), JUMP_IF_FALSE, false, false);
  end;

  //[bug] ���� ��� ���������� DirtySky, ��������� Luigi Auriemma. ���� � ���, ��� � IPureServer::net_Handler ��� DPN_MSGID_CREATE_PLAYER ����� WideCharToMultiByte �� ������� ������ �� ���� �����������! � ����� ����������������� ������ ������������� � strcpy_n
  srcBaseInjection.Create(pointer(xrNetServer+$ad34),@CheckClientConnectionName, 7,[F_PUSH_EDX, F_RMEM+F_PUSH_EBP+$0C], false, false);

  //[bug] � IPureServer::net_Handler ����� � DPN_MSGID_CREATE_PLAYER ������ ����� ����������� ��������� ��� ����������������� ����� � ������, ������� �� ����� ��������� � SClientConnectData	cl_data
  srcBaseInjection.Create(pointer(xrNetServer+$ad94),@CheckClientConnectData, 6,[F_PUSH_ECX], true, false);

  //[bug] � game_sv_GameState::NewPlayerName_Generate ��� �� ���� ����� �������� 64 �����, ������ � strcpy_s ���������� ����� ���� 22, ���� ���� ������������ ��� ������ sprintf'�
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcKit.Get().nop_code(pointer(xrGame+$2f3b6b), 1, chr(64));
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcKit.Get().nop_code(pointer(xrGame+$308adb), 1, chr(64));
  end;

  //[bug] Assert �� CRC � NET_Compressor::Decompress ��������� ������ �� ����������
  srcInjectionWithConditionalJump.Create(pointer(xrNetServer+$8176),@AlwaysTrue, 14,[], pointer(xrNetServer+$8124), JUMP_IF_TRUE, false, false);

  //� NET_Packet::w ���� �� ������� assert'a �� ������ ������������
  srcBaseInjection.Create(pointer(xrCore+$42ca),@NET_Packet__w_checkOverflow,6,[F_PUSH_ESI, F_RMEM+F_PUSH_EBP+$C], true, false);

  //[bug] ��� ������ ������ �� ������� ������� ������ ��������� � ��������� � game_sv_Deathmatch::OnDetach ���������� ������������ EventPack. ������� - ��������� �� ��������� ������� � ���������� �� �� ���� ����������
  //���������� - � game_sv_CaptureTheArtefact::OnDetachItem
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$303075),@SplitEventPackPackets,6,[F_PUSH_ESP+$58], true, false);
    srcBaseInjection.Create(pointer(xrGame+$318ea0),@SplitEventPackPackets,5,[F_PUSH_ESP+$48], true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$3181d5),@SplitEventPackPackets,6,[F_PUSH_ESP+$58], true, false);
    srcBaseInjection.Create(pointer(xrGame+$32ed00),@SplitEventPackPackets,5,[F_PUSH_ESP+$48], true, false);
  end;

  //[bug] ��� ������� ��������� ������ �� ������� ������� ������ ��������� � game_sv_Deathmatch::OnTouch ���������� ������������ EventPack. ������� - ��������� �� ��������� ������� � ���������� �� �� ���� ����������
  //���������� - � game_sv_CaptureTheArtefact::OnTouchItem
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$302c16),@SplitEventPackPackets,7,[F_PUSH_ESP+$24], true, false);
    srcBaseInjection.Create(pointer(xrGame+$318637),@SplitEventPackPackets,7,[F_PUSH_ESP+$18], true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$317d76),@SplitEventPackPackets,7,[F_PUSH_ESP+$24], true, false);
    srcBaseInjection.Create(pointer(xrGame+$32e497),@SplitEventPackPackets,7,[F_PUSH_ESP+$18], true, false);
  end;

  //[bug] ��� �������� ������� �� ������� ������� ������ ��������� � xrServer::Process_event_destroy ���������� ������������ pEventPack. ������� - ��������� �� ��������� ������� � ���������� �� �� ���� ����������
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$38ad56),@SplitEventPackPackets,7,[F_PUSH_EBP], true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$3a124c),@SplitEventPackPackets,5,[F_PUSH_ESI], false, false);
  end;

  //� CGameObject::CGameObject ���������� ��������� m_ai_location ������
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcKit.Get().nop_code(pointer(xrGame+$207c9d), 2, chr($90));
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcKit.Get().nop_code(pointer(xrGame+$219b8d), 2, chr($90));
  end;

  //[bug] ������ ��������� ������� GE_ADDON_DETACH ��������� �������� ���������� ���� � ������ ��� ������ (��� �������� ������)
  //�� ���������� - �������������� ���������� �������.
  //��� ��� � ��� �������� ���� - ����� ����������� ���:
  //1)� CInventoryItem::OnEvent ����������� ����� Detach(i_name, false); - ��� ����� � ��� ������ �� ����� ������ �� ������������ �����
  //2)� CWeaponMagazinedWGrenade::Detach � CWeaponMagazined::Detach ��� ����������� ��������� ������ - ���������� �������� �� true
  if xrGameDllType()=XRGAME_SV_1510 then begin
    //������ ��������� � true �� false � CInventoryItem::OnEvent
    srcKit.Get().nop_code(pointer(xrGame+$22f6ff), 1, chr($00));

    //����������� � CWeaponMagazined::Detach ��� ����������� ������ ������� �� �������
    tmp:=$9040c031; //xor eax, eax; inc eax
    srcKit.Get().CopyBuf(@tmp, pointer(xrGame+$24f8c4), sizeof(tmp));
    tmp:=$9041c931; //xor ecx, ecx; inc ecx
    srcKit.Get().CopyBuf(@tmp, pointer(xrGame+$24f93a), sizeof(tmp));
    srcKit.Get().CopyBuf(@tmp, pointer(xrGame+$24f9ad), sizeof(tmp));

    //����������� � CWeaponMagazinedWGrenade::Detach ��� ����������� ������ ������� �� �������
    tmp:=$9040c031; //xor eax, eax; inc eax
    srcKit.Get().CopyBuf(@tmp, pointer(xrGame+$2532e5), sizeof(tmp));
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    //������ ��������� � true �� false � CInventoryItem::OnEvent
    srcKit.Get().nop_code(pointer(xrGame+$241e2f), 1, chr($00));

    //����������� � CWeaponMagazined::Detach ��� ����������� ������ ������� �� �������
    tmp:=$9040c031; //xor eax, eax; inc eax
    srcKit.Get().CopyBuf(@tmp, pointer(xrGame+$262234), sizeof(tmp));
    tmp:=$9041c931; //xor ecx, ecx; inc ecx
    srcKit.Get().CopyBuf(@tmp, pointer(xrGame+$2622aa), sizeof(tmp));
    srcKit.Get().CopyBuf(@tmp, pointer(xrGame+$26231d), sizeof(tmp));

    //����������� � CWeaponMagazinedWGrenade::Detach ��� ����������� ������ ������� �� �������
    tmp:=$9040c031; //xor eax, eax; inc eax
    srcKit.Get().CopyBuf(@tmp, pointer(xrGame+$265cb5), sizeof(tmp));
  end;

  //���������� ������ ��� ����������� ������� � xrServer::Process_event
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$38a1b1),@CheckGameEventPacket,6,[F_PUSH_ESI, F_RMEM+F_PUSH_EBP+$8], pointer(xrGame+$38a867), JUMP_IF_FALSE, true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$3a05f1),@CheckGameEventPacket,6,[F_PUSH_ESI, F_RMEM+F_PUSH_EBP+$8], pointer(xrGame+$3a0ca7), JUMP_IF_FALSE, true, false);
  end;

  //������� ���� ����������� '* comparing with cheater' ��� �����������
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcKit.Get().nop_code(pointer(xrGame+$3093d9), 2);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcKit.Get().nop_code(pointer(xrGame+$31f219), 2);
  end;

  //�������������� ���� � ������� game
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$30a4c0),@game_sv_mp__Update_additionals,6,[], true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$320310),@game_sv_mp__Update_additionals,6,[], true, false);
  end;

  //���������� ���������� ������� ��� ���������� ������, ����� ������� ��� �������� �������������
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcEAXReturnerInjection.Create(pointer(xrGame+$30822c), @game_sv_TeamDeathmatch__OnPlayerConnect_selectteam, 6, [F_PUSH_EBX, F_PUSH_EAX], true, false, 0);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcEAXReturnerInjection.Create(pointer(xrGame+$31e0ac), @game_sv_TeamDeathmatch__OnPlayerConnect_selectteam, 6, [F_PUSH_EBX, F_PUSH_EAX], true, false, 0);
  end;

  //������������ ������� GEG_PLAYER_WEAPON_HIDE_STATE ������ � ����� ��������� ��������, ����� � ���� ������� ����. ����� ������� ������ � ��� ������� ������� ������.
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$38a6fc),@xrServer__Process_event_onweaponhide,5,[F_PUSH_EDX, F_RMEM+F_PUSH_EBP+$8, F_PUSH_ESI], true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$3a0b3c),@xrServer__Process_event_onweaponhide,5,[F_PUSH_EDX, F_RMEM+F_PUSH_EBP+$8, F_PUSH_ESI], true, false);
  end;

  //������������ ������ ������
  if xrGameDllType()=XRGAME_SV_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$30b440),@game_sv_mp_OnSpawnPlayer,7,[F_RMEM+F_PUSH_ESP+$8, F_RMEM+F_PUSH_ESP+$C], true, false);
    //�� ������ - �� game_sv_mp_script::SpawnPlayer
    srcBaseInjection.Create(pointer(xrGame+$311350),@game_sv_mp_OnSpawnPlayer,5,[F_RMEM+F_PUSH_ESP+$4, F_RMEM+F_PUSH_ESP+$8], true, false);
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    srcBaseInjection.Create(pointer(xrGame+$321290),@game_sv_mp_OnSpawnPlayer,7,[F_RMEM+F_PUSH_ESP+$8, F_RMEM+F_PUSH_ESP+$C], true, false);
    //�� ������ - �� game_sv_mp_script::SpawnPlayer
    srcBaseInjection.Create(pointer(xrGame+$3271b0),@game_sv_mp_OnSpawnPlayer,5,[F_RMEM+F_PUSH_ESP+$4, F_RMEM+F_PUSH_ESP+$8], true, false);
  end;

  //���������� ��������� ��� ����������� � �������
  if xrGameDllType()=XRGAME_SV_1510 then begin
    //game_sv_TeamDeathmatch::OnPlayerKillPlayer - ��������
    srcBaseInjection.Create(pointer(xrGame+$3086da), @DisconnectPlayerWithMessage, 7, [F_PUSH_EAX, F_PUSHCONST+0], false, true);
    //game_sv_CaptureTheArtefact::OnKillResult - ��������
    srcBaseInjection.Create(pointer(xrGame+$3178a5), @DisconnectPlayerWithMessage, 7, [F_PUSH_EAX, F_PUSHCONST+0], false, true);
   end else if xrGameDllType()=XRGAME_CL_1510 then begin
    //game_sv_TeamDeathmatch::OnPlayerKillPlayer - ��������
    srcBaseInjection.Create(pointer(xrGame+$31e55a), @DisconnectPlayerWithMessage, 7, [F_PUSH_EAX, F_PUSHCONST+0], false, true);
    //game_sv_CaptureTheArtefact::OnKillResult - ��������
    srcBaseInjection.Create(pointer(xrGame+$32d705), @DisconnectPlayerWithMessage, 7, [F_PUSH_EAX, F_PUSHCONST+0], false, true);
  end;

   //NET_Compressor::Decompress - ���� �������� �������� ������������� �������
   srcInjectionWithConditionalJump.Create(pointer(xrNetServer+$8103),@NET_Compressor__Decompress_Patch,5,[F_PUSH_EAX, F_RMEM+F_PUSH_ESP+$3c], pointer(xrNetServer+$8124), JUMP_IF_FALSE, true, false);

  //Cars:
  //client CActorMP::net_Relevant	 - xrgame.dll+1f61d0
  //server CActorMP::net_Relevant	 - xrgame.dll+


  //���������� �������
//  srcBaseInjection.Create(pointer(xrNetServer+$A149),@net_Handler,5,[F_PUSH_ESP], false, false);

  //������� ��������
//  srcBaseInjection.Create(pointer(xrNetServer+$AF90),@SentPacketsRegistrator,7,[F_RMEM+F_PUSH_ESP+4, F_RMEM+F_PUSH_ESP+$8, F_RMEM+F_PUSH_ESP+$c], true, false);

  //� CLevel::Load_GameSpecific_After ������ �������� �������� ������ �� ������� ;)
  //srcKit.Get.nop_code(pointer(xrGame+$1C742A), 6);

  // �������� ������ ������, ��� �� �� ���������� ))
//  g_dedicated_server^:=0;
  // � CApplication::LoadDraw ��� ��� �� ����.
//  if not srcKit.Get.nop_code(pointer(xrEngine+$5f253), 2, chr($90)) then exit;
  // � CConsole::OnRender ����
//  if not srcKit.Get.nop_code(pointer(xrEngine+$41947), 2, chr($90)) then exit;
  // IGame_Level::Load - ������ ���� ��� �� �����
//  if not srcKit.Get.nop_code(pointer(xrEngine+$5c0d4), 2, chr($90)) then exit;
  result:=true;
end;

end.

