unit fz_injections;
{$mode delphi}
interface
function Init():boolean; stdcall;

implementation
uses srcBase, basedefs, srcInjections, Players, ConfigMgr, ServerStuff, GameSpy, administration, chat, voting, BasicProtection, Bans, misc_stuff, HackProcessor, windows, xr_debug, ge_filter, Servers, UpdateRate;


function IsArgNull(arg:pointer):boolean; stdcall;
var
  r:integer;
begin
  result:=(arg = nil);
end;

procedure SafeRetFrom_NET_Compressor__Decompress_1(); stdcall;
asm
  xor eax, eax
  pop edi
  pop esi
  pop ebp
  add esp, $20
  ret $10
end;

procedure SafeRetFrom_NET_Compressor__Decompress_2(); stdcall;
asm
  pop ebx
  xor eax, eax
  pop edi
  pop esi
  pop ebp
  add esp, $20
  ret $10
end;

procedure CheckDecompressResult(res:cardinal; clientid:cardinal); stdcall;
begin
  if res = 0 then begin
    BadEventsProcessor(FZ_SEC_EVENT_WARN, GenerateMessageForClientId(clientid, ' sent corrupted packet (decompression failed)'));
  end;
end;

function AlwaysTrue():boolean; stdcall;
begin
  result:=true;
end;

procedure AssignDwordToDwordFromPtr(src: cardinal; dst: pcardinal); stdcall;
begin
  dst^:=src;
end;

function PatchGameSpy():boolean;
begin
  result:=false;

  //������� ����� �������

  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcEAXReturnerInjection.Create(pointer(xrGame+$2e72e7), @ChangeNumPlayersInClientRequest, 11, [F_PUSH_EAX], true, false, 0);
  end;

  //��������� ��� ����� �� ������������ ���� (� callback_serverkey): xrGame+$2e7283
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$2e7283), @WriteMapnameToClientRequest, 14, [F_PUSH_EAX, F_RMEM+F_PUSH_ESP+$101C, F_PUSH_ECX], true, true);
  end;

  //� gcd_authenticate_user ������ ����������� ���� ���������� ������� � ����� ������ �� �������...
  srcInjectionWithConditionalJump.Create(pointer(xrGameSpy+$B192),@IsSameCdKeyValidated,5,[],pointer(xrGameSpy+$B1DD), JUMP_IF_TRUE, true, false);
  //...� ��������� �������� ������ � ��������
  srcInjectionWithConditionalJump.Create(pointer(xrGameSpy+$B26E),@OnAuthSend,8,[F_PUSH_ESI],pointer(xrGameSpy+$B281), JUMP_IF_TRUE, true, false);

  result:=true;
end;

function PatchChat():boolean;
begin
  result:=false;

  //[bug] ����������� ����� ������� ��������� � "�������" ������ - ���������� ����� ������ � xrServer::OnMessage, ������ ������� � ������, ���������� ����� ������ ��� ��������� �� ����� ��������
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$29e2bd),@OnChatMessage_ValidateAndChange,6,[F_PUSH_ESI, F_PUSH_EBX, F_PUSH_EAX],pointer(xrGame+$29e2cb), JUMP_IF_FALSE, true, false);
  end;

  //[bug] ����������� �� ����� ��������� ��������� ������� ��������� - �� � ������� 1; ��� � xrServer::OnChatMessage, ��� ������ �� ����������
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$29e997),@OnChatMessage_AlternativeSendCondition,6,[F_PUSH_EAX, F_RMEM+F_PUSH_ESP+$14],pointer(xrGame+$29e9c4), JUMP_IF_TRUE, true, false);
  end;

  //���������� ��� � ����� � game_sv_mp::OnEvent;
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2d89e7),@OnPlayerSpeechMessage,6,[F_PUSH_EBX, F_PUSH_ECX, F_PUSH_EAX],pointer(xrGame+$2d89ed), JUMP_IF_FALSE, true, false);
  end;

  //������ ����������� ���������� � ��� ��������� �� ����� ������� � ������������
  if FZConfigMgr.Get.GetBool('unlimited_chat_for_dead', true) then begin
    if xrGameDllType()=XRGAME_SV_10006 then begin
      srcKit.Get.nop_code(pointer(xrGame+$29E9AA), 26);
    end;
  end;

  result:=true;
end;

function PatchVoting():boolean;
begin
  result:=false;

  //[bug] �������� ����������� �������� �� ������ ����������� � �������� ���������� � game_sv_mp::OnEvent
  //[bug] ����� ������� ��������� ������������ ������ � game_sv_mp::OnVoteStart ��� ���������� CommandName � CommandParams
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2D88F7),@CanSafeStartVoting,8,[F_PUSH_EBX,F_RMEM+F_PUSH_ESP+$410, F_RMEM+F_PUSH_ESP+$41c],pointer(xrGame+$2D8A41), JUMP_IF_FALSE, false, false);
  end;

  //[bug] CCC_BanPlayerByName::Execute �� �������� � ������ ������ ����� 17 ��������. ���������. ������� ��� �������� (������������ ��� ������, buff �� ����� ���� ������ 4096 �������� �������
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcKit.Get.nop_code(pointer(xrGame+$28a3d1), 1, CHR($EB));
  end;

  //[bug] CCC_KickPlayerByName::Execute -����������
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcKit.Get.nop_code(pointer(xrGame+$28a089), 1, CHR($EB));
  end;

  //������� sv_changelevel �� sv_changelevelgametype ���� � ���������� ���� ����� ��� ���� ��� ����� (game_sv_mp::OnVoteStart)
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$2D9AAD),@ProvideDefaultGameTypeForMapchangeVoting,9,[], false, false);
  end;

  //��������� ������������� �����������+ FZ'���� ���������� ����� + ��� �� IP � �����������
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcKit.nop_code(pointer(xrGame+$2d9b62), 2);
    srcBaseInjection.Create(pointer(xrGame+$2d9b6b), @OnVoteStart, 5,[F_PUSH_EBP, F_RMEM+F_PUSH_ESP+$2830, F_RMEM+F_PUSH_ESP+$282C, F_PUSH_EAX], true, false);
  end;

  result:=true;
end;

function PatchShop(): boolean;
begin
  result:=false;

  //[bug] ��� � �������� ���� �������� ��� ������ ��-�� ����������������� ��������� ���������� �������� ���������� ������ GAME_EVENT_PLAYER_READY (� game_sv_mp::OnEvent)
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2d88a0),@CheckPlayerReadySignalValidity,6,[F_PUSH_EAX], pointer(xrGame+$2d88ae), JUMP_IF_FALSE, true, false);
  end;

  //[bug] ��� ���������� �������� ��������������� �������� � ������ ������ ���� �������, � ������ ����� ���� ������������ ���� �������� ������
  //[bug] ����� ��� ��������� ������ ����������� ��� ��������. ��� ��� ������ � game_sv_Deathmatch::SpawnWeaponsForActor(� ��� �� ��� � ��� CTA �� ������)
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2ce6c8),@BeforeSpawnBoughtItems_DM,5,[F_PUSH_EBP, F_PUSH_EBX], pointer(xrGame+$2ce7ee), JUMP_IF_FALSE, false, false);
  end;

  //� �������� ����� ����� ��������� ����. ��� ��� ������ ��� �������� � �������� ����������� ��������, ���� ���������� ����� ����������.
  //������ ���: � game_sv_Deathmatch::OnPlayerBuyFinished ����� ��������� �������� ����������� ��� ��������� � ���������� ������ �� ����.
  //������ �������� - � ������������ � �������� ����� ��������� ������ ����� �������� �����, ������� �� ���������� �������������. ��� ����, ����� ��� �� ������������ � ���������� � ����, ����
  //���������, ��� ������ ��� ���� ������, � ��������� ������ ����� ������� (��� �������� ������ � �������� �� ����������� ������� ����� �������)
  if xrGameDllType()=XRGAME_SV_10006 then begin
    //� game_sv_Deathmatch::OnPlayerBuyFinished
    srcBaseInjection.Create(pointer(xrGame+$2ce504), @BeforeDestroyingSoldItem_DM,6,[F_PUSH_EAX, F_RMEM+F_PUSH_ESP+$18+$8, F_RMEM+F_PUSH_ESP+$14+$8,F_PUSH_ESP+$1C+$8], false, false);
  end;

  //����� ����, � �������� ����� ����� ��� �������� ������������ �� ���������� � �������� ������� ����� ���� ����, ������� ��������� ��� �� 3 ����� �� ���
  //��� �������������� ����� � game_sv_Deathmatch::CheckItem ��������� �������� �� ������� ���� ����������� � �������� ��������� � ����� �� ����������� ���������� � ����������
  //������ � ���������� ������� ��� ����������� ����������� �������� ����� ��������� ���������� ��������
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcKit.nop_code(pointer(xrGame+$2ce0de), 2);
  end;


  //[bug] ���� ��������� game_cl_xxx::CanCallBuyMenu �� ���������� ����������� true, ����� ���������� �������� ������ � �����. ���������.
  //��� ����������� ��������� � game_sv_Deathmatch::OnEvent, ��� �� ����� ������� GAME_EVENT_PLAYER_BUY_FINISHED ����� �� ����. � �� � ��� ��� ���, ��� ��� � ���������� �� ������
  //(� �� ����� ��������� ������� � game_cl_Deathmatch::OnBuyMenu_Ok ������� if (!m_bBuyEnabled) return;
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2d4a46),@CanPlayerBuyNow,6,[F_PUSH_EAX],pointer(xrGame+$2d4aac), JUMP_IF_FALSE, true, false);
  end;

  //[bug] ����������� �� ����� �������� �� ���������, ����� � ������ ���� �������. ����� - ����� � ��������� � ��������� ��������. ���� - � ������ ������ ������������ �����. ����� ���� �� �����, � ��� � ������ ��� �������� �������� ����� �����...
  //��� ������� �������� ������� � CWeaponMagazinedWGrenade::Detach ���, ���������� �� �������� �������� (UnloadMagazine), ����� ����� ��� � �������� � ������!
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcKit.nop_code(pointer(xrGame+$22B2D6), 6);
  end;

  result:=true;
end;

function PatchHits():boolean;
begin
  result:=false;

  //[bug] � xrServer::Process_event ��� ��������� ��������� GE_HIT ��� GE_HIT_STATISTIC � ������� ���������� ��������� ���������� ������� ID, ��� �� ���� ��������� ����
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$355559),@AssignDwordToDwordFromPtr,7,[F_PUSH_EBP, F_PUSH_ESP], true, false);
  end;

  //[bug] � ����������� GAME_EVENT_ON_HIT (game_sv_GameState::OnEvent) ���� ���������, ��� ��� �������� �� ��� ��� �� �� ���������� �������. �� � ������ ��������� ����������/���������� ����
  //����� ����, ���� ��������� � ���, ��� �� ��������� ��� ������� (�� ��� ��� ������� � ���������), ����� �������� �����.
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2c2b07),@OnGameEventDelayedHitProcessing, 5,[F_PUSH_EDI, F_PUSH_EAX, F_PUSH_ESI, F_RMEM+F_PUSH_ESP+$438], pointer(xrGame+$2c2b25), JUMP_IF_FALSE, true, false);
  end;

  //[bug] CDestroyablePhysicsObject::Hit �� ����� � ����, ��� HDS.who ����� null. ������ ������ - ������� ����������� ��� ��� ����� �������� �������������
  //��� ������� ������ �� �����, �� ��� �������������� ������ �� �������� ������ ����� ������������, ����� ���������� ������
  //(����: ��������� �����; ������� � �����/�����, ����� �����, ������� �� ��� ����; �� ��������� ������, ����� g_kill � ������� � �����; ���� ����� ����� ����������, ��� ����������)
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$1f38c0),@IsArgNull,7,[F_PUSH_EDI], pointer(xrGame+$1f3a0d), JUMP_IF_TRUE, true, false);
  end;

  //[bug] ����������, �� ����� � ����, ��� HDS.who ����� null � CExplosiveItem::Hit
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$25170f),@IsArgNull,7,[F_PUSH_EAX], pointer(xrGame+$251716), JUMP_IF_TRUE, true, false);
  end;

  //[bug] GAME_EVENT_PLAYER_HITTED ����� �������� ������ ��������� ������. ��������� � game_sv_mp::OnEvent
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2d884e),@OnGameEventPlayerHitted,7,[F_RMEM+F_PUSH_ESP+$410, F_RMEM+F_PUSH_ESP+$41c], pointer(xrGame+$2d8874), JUMP_IF_FALSE, true, false);
  end;

  result:=true;
end;

function PatchServer():boolean;
begin
  result:=false;

  //���� ����� � xrServer::Process_event_reject. ����� ����� �� ����� ������ ������ ������� �� ������ - ���������� ����
  //R_ASSERT			(e_parent && e_entity);
  //R_ASSERT3				(e_entity->ID_Parent == id_parent, e_entity->name_replace(), e_parent->name_replace());
  //R_ASSERT3				(C.end()!=c,e_entity->name_replace(),e_parent->name_replace());
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$3564d4),@xrServer__Process_event_reject_CheckEntities,7,[F_PUSH_ESI, F_PUSH_EDI], pointer(xrGame+$356562), JUMP_IF_FALSE, true, false);
  end;

  //����������, ��� ������ �� ������� �� ����� ������ ������ ���� ������� � CInventory::Eat
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$206092),@CInventory_Eat_CheckIsValid,8,[F_PUSH_EBX, F_RMEM+F_PUSH_ESP+$202C], pointer(xrGame+$20629b), JUMP_IF_FALSE, false, false);
  end;

  //[bug] ������ � ��������������: IPureServer::DisconnectClient ������� ������� �����������, �� �������� ������. ����� ���, � ������������� ������� ��� ����� ���������� �����, ��� ������� ��������
  //���������, ������, �� ���������. �� ����� ��������� ������� ������.
  //�������� � game_sv_mp::OnEvent, ���������� �� ��� ������, ����� ���, ��� ��������� �������� (��� ��� � ��� "����������" ������� �������, �� ������ ��������� ��������� �� ������� ��������� ������ ��� ��������)
  //� ����������� game_sv_mp ����� �������� ������ OnEvent �� ������������� �������, � �������, ����
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2d880e),@OnGameEvent_CheckClientExist,7,[F_RMEM+F_PUSH_ESP+$410, F_RMEM+F_PUSH_ESP+$414, F_RMEM+F_PUSH_ESP+$41c], pointer(xrGame+$2d8842), JUMP_IF_FALSE, true, false);
  end;

  //[bug] � game_sv_GameState::OnEvent ����� R_ASSERT ������ �� ��������� - ������������� ����� �������� �������� ������ � ��� �������.
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$2c2bb1), @OnGameEventNotImplenented, 60, [F_RMEM+F_PUSH_ESP+$428, F_RMEM+F_PUSH_ESP+$42C, F_RMEM+F_PUSH_ESP+$434], true, true);
  end;

  //[bug] CLevel::GetLevelInfo ��� �������� �� ��, ��� ������ � game ������ ����������. ��-�� ����� ������ ����� ������ ��� ����� �����.
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$1a4230),@IsCurrentGameExist,6,[], pointer(xrGame+$1a4229), JUMP_IF_FALSE, true, false);
  end;

  result:=true;
end;

function PatchKillsAndCorpses():boolean;
var
  tmp:cardinal;
begin
  result:=false;

  //[bug] GAME_EVENT_PLAYER_KILLED ����� �������� ������ ��������� ������. ��������� � game_sv_mp::OnEvent
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2d881c),@OnGameEventPlayerKilled,7,[F_RMEM+F_PUSH_ESP+$410, F_RMEM+F_PUSH_ESP+$41c], pointer(xrGame+$2d8842), JUMP_IF_FALSE, true, false);
  end;

  //[bug] � xrServer::Process_event ��� ��������� GE_DIE ��� �������� �� ��, ��� e_src ������� (������ 187) - � �� ����, ��� ��� ���������
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcEBPReturnerInjection.Create(pointer(xrGame+$3556ce),@xrServer__Process_event_GE_DIE_CheckKillerGameEntity,6,[F_PUSH_EBP, F_PUSH_EBX], true, true);
  end;

  //[bug] � xrServer::Process_event ��� ��������� ��������� GE_DIE (Line 197) ��� �������� �� ��, ��� c_src != null � c_src->owner != null
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$35572a),@Check_xrClientData_owner_valid,6,[F_PUSH_EBX], pointer(xrGame+$3557d0), JUMP_IF_FALSE, true, false);
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
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcKit.Get.nop_code(pointer(xrGame+$2d8285), 42);
  end;

  //[bug] ���� � ����� �������� �������� ��������, ��� ������������ ��� �������� � �������� ���� � ������� � game_sv_mp::Update
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2d8235),@game_sv_mp__Update_could_corpse_be_removed,5,[F_PUSH_EAX], pointer(xrGame+$2d825a), JUMP_IF_TRUE, true, false);
  end;

  //[bug] ���� ��� ������ ����� �� ������� �������� (�.�. �� �������� � ����������) ������� ������� � �����������, �� �� ����� ��������� ����������� ����.
  //����������� - �� ����� ��, � game_sv_mp::OnPlayerSelectSpectator ������� ������ AllowDeadBodyRemove	� m_CorpseList.push_back.
  //��� ��������� �����  - ������� �������� game_sv_mp::RespawnPlayer
  tmp:=$9090cb8b; //(mov ecx, ebx; nop; nop
  srcKit.CopyBuf(@tmp, pointer(xrGame+$2db327), sizeof(tmp));
  srcBaseInjection.Create(pointer(xrGame+$2db329), pointer(xrGame+$2d8b70), 9, [F_PUSH_EBP, F_PUSHCONST+0], false, true);
  result:=true;
end;

function Init():boolean; stdcall;
var
  tmp:cardinal;
begin
  result:=false;

  //������ ��� ������� (� callback_serverkey)
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$2e7243), @WriteHostnameToClientRequest, 7, [F_PUSH_EAX, F_PUSH_ECX, F_PUSH_EDX], true, true);
  end;

  if not PatchGameSpy() then exit;
  if not PatchChat() then exit;
  if not PatchVoting() then exit;
  if not PatchHits() then exit;
  if not PatchKillsAndCorpses() then exit;
  if not PatchShop() then exit;
  if not PatchServer() then exit;

  //���������� ����� ����� xrGame+$1b6666
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$1b6666),@CLevel__net_start1_updatemapname,5,[F_PUSH_EDX], false, false);
  end;

  //���������� ����� ����� � ������
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$2d6a21),@xrServer__Connect_SaveCurrentMapInfo,6,[F_PUSH_ECX], false, false);
  end;

  //�������� �������������� ����� ����� ����� � ������
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$1b614f),@CLevel__net_Start_overridelevelgametype,6,[], false, false);
  end;

  if xrGameDllType()=XRGAME_SV_10006 then begin
    //������� ������ �������� ������������� ����� ��������: xrGame+$2d6d9c
    srcBaseInjection.Create(pointer(xrGame+$2d6d9c),@OnAttachNewClient,5,[F_PUSH_EDI, F_PUSH_ESI], true, false); //in xrServer::AttachNewClient
  end;

  //�������� ������ �������
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$29FD40), @FromPlayerStateConstructor, 6, [F_PUSH_ESI], false, false);
    srcBaseInjection.Create(pointer(xrGame+$29FD56), @FromPlayerStateClear, 5, [F_PUSH_ECX], false, false);
    srcBaseInjection.Create(pointer(xrGame+$29FE65), @FromPlayerStateDestructor, 6, [F_PUSH_ESI], false, false);
  end;

  //�������, ����� ������ ������������ ����������� � �����  � ���� - � xrServer::OnMessage M_CLIENTREADY
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$29e17e),@OnClientReady,6,[F_PUSH_ESI, F_PUSH_EAX], true, false);
  end;

  //[bug] �������� ������� - ������� PlayerState, ���� ������ ������ �� �����������
  //���� ����������� �������� ������� ����� ��� ������ �� ������
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$29d646),@xrServer__client_Destroy_force_destroy,6,[F_PUSH_EBX], pointer(xrGame+$29D6AC), JUMP_IF_TRUE, true, false);
  end;

  //[bug] ��� �� ������ ���... ���� � IPureServer::SendTo_LL : ������� ������ ��� �������������� �������, ��� ���� ��� ��� - �� � ���� � ���, ��������� ���-������ :)
  if not srcKit.Get.nop_code(pointer(xrNetServer+$a19e), 1, chr($EB)) then exit;

  //[bug] ������ ����������� ������� � ���� ������ � ��������� �����
  if xrGameDllType()=XRGAME_SV_10006 then begin
    //� xrServer::new_client, ��� ��������
    srcBaseInjection.Create(pointer(xrGame+$2D6BB4), @CorrectPlayerName, 5, [F_PUSH_ECX], false, false);

    //� game_sv_mp::OnPlayerChangeName, ��� ������� ����� ����
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2DAE00), @CorrectPlayerNameWhenRenaming, 5, [F_RMEM+F_PUSH_ESP+4, F_RMEM+F_PUSH_ESP+8], pointer(xrGame+$2DAF28), JUMP_IF_FALSE, true, false);
  end;

  //[bug]������ �� stalkazz - � xrGameSpyServer::OnMessage ����������, ��� ����� ������ � ������ M_GAMESPY_CDKEY_VALIDATION_CHALLENGE_RESPOND ������, ��� ������ ������
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$35795c),@CheckIfPacketZStringIsLesserThenWithDisconnect,5,[F_PUSH_ESI, F_PUSHCONST+128, F_PUSH_EDI, F_PUSHCONST+$16, F_PUSHCONST+1], pointer(xrGame+$3579f0), JUMP_IF_FALSE, false, false);
  end;

  //[bug] ���� ��� ���������� DirtySky, ��������� Luigi Auriemma. ���� � ���, ��� � IPureServer::net_Handler ��� DPN_MSGID_CREATE_PLAYER ����� WideCharToMultiByte �� ������� ������ �� ���� �����������! � ����� ����������������� ������ ������������� � strcpy_n
  srcBaseInjection.Create(pointer(xrNetServer+$9e34),@CheckClientConnectionName, 7,[F_PUSH_EDX, F_RMEM+F_PUSH_EBP+$0C], false, false);

  //[bug] � IPureServer::net_Handler ����� � DPN_MSGID_CREATE_PLAYER ������ ����� ����������� ��������� ��� ����������������� ����� � ������, ������� �� ����� ��������� � SClientConnectData	cl_data
  srcBaseInjection.Create(pointer(xrNetServer+$9e90),@CheckClientConnectData, 7,[F_PUSH_ECX], true, false);

  //����������� �� ��� ��������
  srcInjectionWithConditionalJump.Create(pointer(xrNetServer+$9fbf),@IPureServer__net_Handler_SubnetBans,5,[F_RMEM+F_PUSH_ESP+$0C],pointer(xrNetServer+$9fd3), JUMP_IF_TRUE, true, False);

  //��������� � ���, ��� IP ������� � ������� ��������
  srcBaseInjection.Create(pointer(xrNetServer+$9fd3),@IPureServer__net_Handler_OnBannedByGameIpFound,7,[F_RMEM+F_PUSH_ESP+$0C], true, False);

  //[bug] ���� ��� stalker39x type A (by Luigi Auriemma) - ������������ ������ � IPureServer::_Recieve ��� ������� ������� ����� 8192 ���� ������
  srcInjectionWithConditionalJump.Create(pointer(xrNetServer+$93b0),@CheckIfDwordIsLesserThan, 5,[F_RMEM+F_PUSH_ESP+8, F_PUSHCONST+8192, F_RMEM+F_PUSH_ESP+$C, F_PUSHCONST+1],pointer(xrNetServer+$9490), JUMP_IF_FALSE, true, false);

  //[bug] ���� ��� stalker39x type B (by Luigi Auriemma) - ��� ��������� ��������������� ��������� �� 0 ���� NET_Compressor::Decompress ����� ���������� u32(-1) ����
  srcInjectionWithConditionalJump.Create(pointer(xrNetServer+$742f),@IsArgNull,7,[F_PUSH_EAX],pointer(@SafeRetFrom_NET_Compressor__Decompress_1), JUMP_IF_TRUE, true, false);

  //[bug] ���� ��� stalker39x type C (by Luigi Auriemma) - ��� ��������� MultipacketReciever::RecievePacket ������, � ����� ���������� �������� ���������� �������� - ���������� int3
  srcInjectionWithConditionalJump.Create(pointer(xrNetServer+$6f40),@OneByteChecker,5,[F_PUSH_EAX, F_PUSHCONST+$E0, F_RMEM+F_PUSH_ESP+$802c, F_PUSHCONST+$1],pointer(xrNetServer+$7068), JUMP_IF_FALSE, true, true);

  //[bug] Assert �� CRC � NET_Compressor::Decompress ��������� ������ �� ����������
  srcInjectionWithConditionalJump.Create(pointer(xrNetServer+$7496),@AlwaysTrue, 14,[], pointer(@SafeRetFrom_NET_Compressor__Decompress_2), JUMP_IF_TRUE, false, false);

  //����� ��������� � ��������� ������������ ������ �� MultipacketReciever::RecievePacket
  srcBaseInjection.Create(pointer(xrNetServer+$6f78),@CheckDecompressResult,5,[F_PUSH_EAX, F_RMEM+F_PUSH_ESP+$802c], true, False);

  //[bug] ��� ������ ������ �� ������� ������� ������ ��������� � ��������� � game_sv_Deathmatch::OnDetach ���������� ������������ EventPack. ������� - ��������� �� ��������� ������� � ���������� �� �� ���� ����������
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$2d0cc0),@SplitEventPackPackets,7,[F_PUSH_ESP+$48], true, false);
  end;

  //[bug] ��� ������� ��������� ������ �� ������� ������� ������ ��������� � game_sv_Deathmatch::OnTouch ���������� ������������ EventPack. ������� - ��������� �� ��������� ������� � ���������� �� �� ���� ����������
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$2d04b0),@SplitEventPackPackets,6,[F_PUSH_ESP+$20], true, false);
  end;

  //[bug] ��� �������� ������� �� ������� ������� ������ ��������� � xrServer::Process_event_destroy ���������� ������������ pEventPack. ������� - ��������� �� ��������� ������� � ���������� �� �� ���� ����������
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$355ff5),@SplitEventPackPackets,6,[F_PUSH_EDI], true, false);
  end;

  //[bug] ������ ��������� ������� GE_ADDON_DETACH ��������� �������� ���������� ���� � ������ ��� ������ (��� �������� ������)
  //�� ���������� - �������������� ���������� �������.
  //��� ��� � ��� �������� ���� - ����� ����������� ���:
  //1)� CInventoryItem::OnEvent ����������� ����� Detach(i_name, false); - ��� ����� � ��� ������ �� ����� ������ �� ������������ �����
  //2)� CWeaponMagazinedWGrenade::Detach � CWeaponMagazined::Detach ��� ����������� ��������� ������ - ���������� �������� �� true
  if xrGameDllType()=XRGAME_SV_10006 then begin
    //������ ��������� � true �� false � CInventoryItem::OnEvent
    srcKit.Get().nop_code(pointer(xrGame+$209c5b), 1, chr($00));

    //����������� � CWeaponMagazined::Detach ��� ����������� ������ ������� �� �������
    tmp:=$9040c031; //xor eax, eax; inc eax
    srcKit.Get().CopyBuf(@tmp, pointer(xrGame+$2277d4), sizeof(tmp));
    tmp:=$9041c931; //xor ecx, ecx; inc ecx
    srcKit.Get().CopyBuf(@tmp, pointer(xrGame+$22784a), sizeof(tmp));
    srcKit.Get().CopyBuf(@tmp, pointer(xrGame+$2278bd), sizeof(tmp));

    //����������� � CWeaponMagazinedWGrenade::Detach ��� ����������� ������ ������� �� �������
    tmp:=$9040c031; //xor eax, eax; inc eax
    srcKit.Get().CopyBuf(@tmp, pointer(xrGame+$22b2e8), sizeof(tmp));

    //� CInventoryItem::Detach ����� �������� ��� ��������� b_spawn_item = false �� ������� ������������ ������
    srcBaseInjection.Create(pointer(xrGame+$209ec0),@CInventoryItem_Detach_CheckForCheat,5,[F_PUSH_ECX, F_RMEM+F_PUSH_ESP+4, F_RMEM+F_PUSH_ESP+8], true, false);
  end;

  //[bug] ����� ������� � ���������� �������� 'cl setDestroy' � ���� (��� ���� � ����� ����� � EIP ��� ������ 1.0006 ����� 6B6E7572).������� �� ����� "������" ������ ���������� ������ CActor::shedule_Update.
  //���� � ���, ��� ���� ����� ������ ��������� �� ������, ������� ��� �� ����������� ������ (��������), � ��������� � �������. ����� �������� ������� (� �������� � ���) ��������� �� ����� �������� ��������� �� ��� ����������� ������,
  //� �������� vtable ��������� �� ������ �������� ������������ ������ (� ����� ����� ������ �������), ������� ��� ������� ����� ����� ������������ ������ ������� ���������� �� ��, ��� ���� (� 6B6E7572, ���������� ������ ������ ������).
  //������ ��� ����������? ��������, � ��� ����� ������. � CActor::Die ������������ �������� GE_OWNERSHIP_REJECT - ������� ��� ����� ��������. �� ��������� ������� ������ ��� ������������ �������� �������, ������ ��� ������ � xrServer::Process_event_reject �
  //�������� game->OnDetach. ������ ��������� ���������� ��������� ��� ������� GE_OWNERSHIP_REJECT | GE_OWNERSHIP_TAKE ��� ��������� � ��������� ������, ������� ���� ���������� � ������. ������ � ����� ������ ���������� �������������� �������� (����������
  //����������� ��������� ��������), ����� ���� ������������ � CLevel::OnMessage, ��� ������������ � ������� ���������� ���������. ���������� ���� �� ������������ � GE_OWNERSHIP_REJECT ��� �������. �� ������ ����� �� ���������� �� �������� ����� ������ ������!
  //�� ������ � ������� ������� ����� �� ������ ������� ����� ������ ����� ������ - ��������, GEG_PLAYER_ITEM2SLOT (�������������� ���� �������, ���� ������-�� �� ������ - �������� �� CGrenade::PutNextToSlot).
  //�� ��� ����� ����������� �� ������� CLevel'a, ����� ����� ��������� ��������� �� �������?
  //-GE_OWNERSHIP_REJECT ����� �������������� � CActor::OnEvent, � ������� ����� ������ inventory().DropItem. ������� ������� �� ���������, ��������� ��� ����, m_pCurrentInventory � �.�. ����� ��������� Parent.
  //-GE_OWNERSHIP_TAKE ����� �������������� � CMPPlayersBag::OnEvent, � ������� ���������� ����� Parent.
  //-����������� GEG_PLAYER_ITEM2SLOT �������� � ����, ��� � ���� ������ ����� ������� �������, ������� ��������� �� � ��� ���������, � � �������� �������! �� ������ �� ���� ������ �� �����!
  //������ �������� ������ ��������� �������, ����� ������ �� ���� ���������� ����� ������ �� ����, � �� ��������� ������� ��� ����������� ������.
  //������:
  //1) � xrServer::Process_event ���� ���������, ��� � ����������� ���������� ����� ��������� ������ ����� ��������� (�.�. ��� �������� ��� �� ���� ��������)
  //2) � xrServer::Process_event ���������, ��� ������� ��� �� ������ ����� ����������� ����������� ��������
  //3) � CActor::OnEvent ����� ���������� �� �������/���������� �� ����� �� ���������, ��� ����� ��� ��� (������������ �� ����� �������)(����� ���� �� ������)
  //UPD: ������, ��� ���� ������ ������� ����� - � ������ 5C616433 ��� ������ ����� � ��������� (?) �� CActor::Die. ������� ��� �� - ���������� ��������� �� ������ ��� ������������ �� ���������

  //���������� ������ ��� ����������� ������� � xrServer::Process_event
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$355216),@CheckGameEventPacket,6,[F_PUSH_EAX, F_RMEM+F_PUSH_ESP+$124], pointer(xrGame+$355a07), JUMP_IF_FALSE, true, false);
  end;

  //[bug] � game_sv_GameState::NewPlayerName_Exists ����������� ������ �������� ����������� ������
  //������������� ��������� �������� �� NULL � ����� ��� ����������� - ��� ����� ���� � ������ �����
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$2c2c40),@LockServerPlayers,8,[], true, false);
    srcBaseInjection.Create(pointer(xrGame+$2c2d2b),@UnlockServerPlayers,6,[], true, false);
    srcBaseInjection.Create(pointer(xrGame+$2c2d36),@UnlockServerPlayers,6,[], true, false);
    srcBaseInjection.Create(pointer(xrGame+$2c2d3f),@UnlockServerPlayers,6,[], true, false);

    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2c2cda),@IsArgNull,6,[F_PUSH_ECX], pointer(xrGame+$2c2d1f), JUMP_IF_TRUE, true, false);
  end;

  //�������������� ���� � ������� game
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$2d8130),@game_sv_mp__Update_additionals,6,[], true, false);
  end;

  //���������� � ����� ID ������� ��� ���������� ���������� ������� �� ����
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$29de5d),@xrServer__OnDelayedMessage_before_radmincmd,5,[F_PUSH_EAX, F_RMEM+F_PUSH_ESP+$18], false, false);
    srcBaseInjection.Create(pointer(xrGame+$29de6c),@xrServer__OnDelayedMessage_after_radmincmd,6,[F_RMEM+F_PUSH_ESP+$14], false, false);
  end;

  if FZConfigMgr.Get.GetBool('patch_updrate', true) then begin
    //dynamic update rate - ���� � IPureServer::HasBandwidth
    srcECXReturnerInjection.Create(pointer(xrNetServer+$a38a),@SelectUpdRate,6,[F_PUSH_EDI,F_RMEM+F_PUSH_ESP+$10, F_PUSH_ECX], false, false, 0);
  end;

  //���������� ��������������� ����� ������� �������
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2db29d),@game_sv_mp__OnPlayerGameMenu_isteamchangeblocked,6,[F_RMEM+F_PUSH_ESP+$0C, F_PUSH_EAX], pointer(xrGame+$2db2ad), JUMP_IF_TRUE, false, false);
  end;

  //���������� ���������� ������� ��� ���������� ������, ����� ������� ��� �������� �������������
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcEAXReturnerInjection.Create(pointer(xrGame+$2d728c), @game_sv_TeamDeathmatch__OnPlayerConnect_selectteam, 6, [F_PUSH_EBX, F_PUSH_EAX], true, false, 0);
  end;

  //������������ ������� GEG_PLAYER_WEAPON_HIDE_STATE ������ � ����� ��������� ��������, ����� � ���� ������� ���� (�������, ���������, ������ ������ � ������ � �.�.). ����� ������� ������ � ��� ������� ������� ������.
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$3558b6),@xrServer__Process_event_onweaponhide,5,[F_PUSH_ECX, F_PUSH_EBP, F_PUSH_EDI], true, false);
  end;

  //������������ ������ ������
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$2d8b70),@game_sv_mp_OnSpawnPlayer,5,[F_RMEM+F_PUSH_ESP+$4, F_RMEM+F_PUSH_ESP+$8], true, false);
    //�� ������ - �� game_sv_mp_script::SpawnPlayer
    srcBaseInjection.Create(pointer(xrGame+$2dd970),@game_sv_mp_OnSpawnPlayer,5,[F_RMEM+F_PUSH_ESP+$4, F_RMEM+F_PUSH_ESP+$8], true, false);
  end;

  //��������� ���������
  if xrGameDllType()=XRGAME_SV_10006 then begin
    //game_sv_TeamDeathmatch::OnPlayerKillPlayer
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2d770f),@OnTeamKill, 40, [F_PUSH_EBX, F_PUSH_EDI], pointer(xrGame+$2d77ac), JUMP_IF_FALSE, false, true);
    //� game_sv_TeamDeathmatch::OnPlayerConnectFinished ������� ��������� m_iTeamKills � ����� ������
    srcKit.Get().nop_code(pointer(xrGame+$2d73cc), 6);
  end;

  //�������� �������� ������
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$2db710), @game_sv_mp__Player_AddExperience_expspeed, 5, [F_PUSH_ESP+$8], true, false);
  end;

  //������������ �������
    if xrGameDllType()=XRGAME_SV_10006 then begin
      //� game_sv_Deathmatch::check_InvinciblePlayers ���������� ����������� �������� �� ������������, ���� ��� �������������� ����
      srcInjectionWithConditionalJump.Create(pointer(xrGame+$2d0fe1),@IsInvincibilityControlledByFZ, 5,[F_PUSH_EDI], pointer(xrGame+$2d1003), JUMP_IF_TRUE, true, false);
      //� game_sv_ArtefactHunt::OnPlayerHitPlayer_Case ��������� �������� �� ����������� ������������, ����� ��� �� ��������� �� �����
      srcInjectionWithConditionalJump.Create(pointer(xrGame+$2cc153),@IsInvincibilityControlledByFZ, 6,[F_PUSH_EBX], pointer(xrGame+$2cc178), JUMP_IF_TRUE, true, false);
      //�������� �� ������������� �������� ������������ � game_sv_Deathmatch::OnPlayerFire
      srcInjectionWithConditionalJump.Create(pointer(xrGame+$2d1b14),@IsInvinciblePersistAfterShot, 6,[F_PUSH_EAX], pointer(xrGame+$2d1b42), JUMP_IF_TRUE, true, false);
    end;

  result:=true;
end;

end.

