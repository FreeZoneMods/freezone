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

  //Подмена числа игроков

  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcEAXReturnerInjection.Create(pointer(xrGame+$2e72e7), @ChangeNumPlayersInClientRequest, 11, [F_PUSH_EAX], true, false, 0);
  end;

  //Переводим имя карты на человеческий язык (в callback_serverkey): xrGame+$2e7283
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$2e7283), @WriteMapnameToClientRequest, 14, [F_PUSH_EAX, F_RMEM+F_PUSH_ESP+$101C, F_PUSH_ECX], true, true);
  end;

  //в gcd_authenticate_user правим возможность игры нескольким игрокам с одним ключом на сервере...
  srcInjectionWithConditionalJump.Create(pointer(xrGameSpy+$B192),@IsSameCdKeyValidated,5,[],pointer(xrGameSpy+$B1DD), JUMP_IF_TRUE, true, false);
  //...и отключаем отправку пакета с запросом
  srcInjectionWithConditionalJump.Create(pointer(xrGameSpy+$B26E),@OnAuthSend,8,[F_PUSH_ESI],pointer(xrGameSpy+$B281), JUMP_IF_TRUE, true, false);

  result:=true;
end;

function PatchChat():boolean;
begin
  result:=false;

  //[bug] исправление очень длинных сообщений и "цветных" крашей - обработчик сырых данных в xrServer::OnMessage, правит гадости и решает, отправлять пакет дальше или отбросить от греха подальше
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$29e2bd),@OnChatMessage_ValidateAndChange,6,[F_PUSH_ESI, F_PUSH_EBX, F_PUSH_EAX],pointer(xrGame+$29e2cb), JUMP_IF_FALSE, true, false);
  end;

  //[bug] Серверадмин не видит приватных сообщений команды наемников - он в команде 1; баг в xrServer::OnChatMessage, ему просто не отправляют
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$29e997),@OnChatMessage_AlternativeSendCondition,6,[F_PUSH_EAX, F_RMEM+F_PUSH_ESP+$14],pointer(xrGame+$29e9c4), JUMP_IF_TRUE, true, false);
  end;

  //обработчик ора в рацию в game_sv_mp::OnEvent;
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2d89e7),@OnPlayerSpeechMessage,6,[F_PUSH_EBX, F_PUSH_ECX, F_PUSH_EAX],pointer(xrGame+$2d89ed), JUMP_IF_FALSE, true, false);
  end;

  //делаем возможность отправлять в чат сообщения от имени мертвых и наблюдателей
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

  //[bug] удаление запрещенных символов из строки голосования и проверка валидности в game_sv_mp::OnEvent
  //[bug] также фиксает возможное переполнение буфера в game_sv_mp::OnVoteStart при заполнении CommandName и CommandParams
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2D88F7),@CanSafeStartVoting,8,[F_PUSH_EBX,F_RMEM+F_PUSH_ESP+$410, F_RMEM+F_PUSH_ESP+$41c],pointer(xrGame+$2D8A41), JUMP_IF_FALSE, false, false);
  end;

  //[bug] CCC_BanPlayerByName::Execute не работает с никами длиной более 17 символов. Непорядок. Убиваем эту проверку (безопасность там мнимая, buff не может быть больше 4096 символов априори
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcKit.Get.nop_code(pointer(xrGame+$28a3d1), 1, CHR($EB));
  end;

  //[bug] CCC_KickPlayerByName::Execute -аналогично
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcKit.Get.nop_code(pointer(xrGame+$28a089), 1, CHR($EB));
  end;

  //Изменим sv_changelevel на sv_changelevelgametype если в настройках явно задан тип игры для карты (game_sv_mp::OnVoteStart)
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$2D9AAD),@ProvideDefaultGameTypeForMapchangeVoting,9,[], false, false);
  end;

  //обработка нестандартных голосований+ FZ'шный транслятор строк + бан по IP в голосовании
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcKit.nop_code(pointer(xrGame+$2d9b62), 2);
    srcBaseInjection.Create(pointer(xrGame+$2d9b6b), @OnVoteStart, 5,[F_PUSH_EBP, F_RMEM+F_PUSH_ESP+$2830, F_RMEM+F_PUSH_ESP+$282C, F_PUSH_EAX], true, false);
  end;

  result:=true;
end;

function PatchShop(): boolean;
begin
  result:=false;

  //[bug] баг с пролетом мимо магазина при спавне из-за последовательного получения нескольких сигналов готовности игрока GAME_EVENT_PLAYER_READY (в game_sv_mp::OnEvent)
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2d88a0),@CheckPlayerReadySignalValidity,6,[F_PUSH_EAX], pointer(xrGame+$2d88ae), JUMP_IF_FALSE, true, false);
  end;

  //[bug] При добавлении крякером дополнительного предмета в список закупа едут индексы, и крякер может либо шопхакнуться либо завалить сервак
  //[bug] Также это открывает легкую возможность для шопхаков. Так что патчим в game_sv_Deathmatch::SpawnWeaponsForActor(а для ЧН еще и про CTA не забыть)
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2ce6c8),@BeforeSpawnBoughtItems_DM,5,[F_PUSH_EBP, F_PUSH_EBX], pointer(xrGame+$2ce7ee), JUMP_IF_FALSE, false, false);
  end;

  //В артханте игрок может продавать вещи. Так как теперь все операции с деньгами выполняются сервером, надо подсчитать сумму проданного.
  //Делаем так: в game_sv_Deathmatch::OnPlayerBuyFinished перед удалением предмета анализируем его стоимость и докидываем игроку на счет.
  //Другая проблема - у пользователя в артханте может оказаться оружие более высокого ранга, которое он попытается проапгрейдить. Для того, чтобы его не конфисковали с сообщением о чите, надо
  //запомнить, что оружие уже было раньше, и сохранить старые флаги аддонов (для респавна старых и проверки на возможность покупки новых аддонов)
  if xrGameDllType()=XRGAME_SV_10006 then begin
    //в game_sv_Deathmatch::OnPlayerBuyFinished
    srcBaseInjection.Create(pointer(xrGame+$2ce504), @BeforeDestroyingSoldItem_DM,6,[F_PUSH_EAX, F_RMEM+F_PUSH_ESP+$18+$8, F_RMEM+F_PUSH_ESP+$14+$8,F_PUSH_ESP+$1C+$8], false, false);
  end;

  //Кроме того, в артханте игрок может при хакнутых ограничениях на количество в конфигах сделать закуп кучи грен, покупая несколько раз по 3 штуки за раз
  //Для предотвращения этого в game_sv_Deathmatch::CheckItem форсируем удаление из рюкзака всех продающихся в магазине предметов с целью их дальнейшего перезакупа и переспавна
  //Вместе с предыдущей правкой это заблокирует возможность покупать много предметов маленькими партиями
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcKit.nop_code(pointer(xrGame+$2ce0de), 2);
  end;


  //[bug] если исправить game_cl_xxx::CanCallBuyMenu на постоянное возвращение true, закуп становится возможен всегда и везде. Непорядок.
  //Для исправления проверяем в game_sv_Deathmatch::OnEvent, что во время прихода GAME_EVENT_PLAYER_BUY_FINISHED игрок на базе. В ДМ и ТДМ баз нет, так что и закупиться не выйдет
  //(в ТЧ также требуется удалить в game_cl_Deathmatch::OnBuyMenu_Ok условие if (!m_bBuyEnabled) return;
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2d4a46),@CanPlayerBuyNow,6,[F_PUSH_EAX],pointer(xrGame+$2d4aac), JUMP_IF_FALSE, true, false);
  end;

  //[bug] Переключись на режим стрельбы из подствола, когда в оружии есть граната. Затем - выйди в инвентарь и отсоедини подствол. Итог - в рюкзак упадет подствольная грена. Затем идем на закуп, и нас в стволе при респавне появится новая грена...
  //Для решения проблемы удаляем в CWeaponMagazinedWGrenade::Detach код, отвечающий за разрядку магазина (UnloadMagazine), пусть грена так и остается в стволе!
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcKit.nop_code(pointer(xrGame+$22B2D6), 6);
  end;

  result:=true;
end;

function PatchHits():boolean;
begin
  result:=false;

  //[bug] в xrServer::Process_event при получении сообщения GE_HIT или GE_HIT_STATISTIC в очередь отложенных сообщений помещается нулевой ID, это не дает проверить хиты
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$355559),@AssignDwordToDwordFromPtr,7,[F_PUSH_EBP, F_PUSH_ESP], true, false);
  end;

  //[bug] В обработчике GAME_EVENT_ON_HIT (game_sv_GameState::OnEvent) надо проверить, что хит прилетел не для или не от серверного клиента. Ну и вообще проверить валидность/читерность хита
  //кроме того, надо убедиться в том, что ИД нанесшего хит валиден (он мог уже умереть и удалиться), иначе возможен вылет.
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2c2b07),@OnGameEventDelayedHitProcessing, 5,[F_PUSH_EDI, F_PUSH_EAX, F_PUSH_ESI, F_RMEM+F_PUSH_ESP+$438], pointer(xrGame+$2c2b25), JUMP_IF_FALSE, true, false);
  end;

  //[bug] CDestroyablePhysicsObject::Hit не готов к тому, что HDS.who будет null. Решаем просто - игнорим прилетевший хит при таком стечении обстоятельств
  //это защитит сервер от краша, но для предотвращения вылета на клиентах одного этого недостаточно, нужна предыдущая правка
  //(тест: отключить трупы; подойти к лампе/шкафу, взять грену, бросить ее под ноги; не дожидаясь взрыва, вбить g_kill и перейти в наблы; если лампа будет похитована, все развалится)
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$1f38c0),@IsArgNull,7,[F_PUSH_EDI], pointer(xrGame+$1f3a0d), JUMP_IF_TRUE, true, false);
  end;

  //[bug] Аналогично, не готов к тому, что HDS.who будет null и CExplosiveItem::Hit
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$25170f),@IsArgNull,7,[F_PUSH_EAX], pointer(xrGame+$251716), JUMP_IF_TRUE, true, false);
  end;

  //[bug] GAME_EVENT_PLAYER_HITTED может отсылать только локальный клиент. Проверяем в game_sv_mp::OnEvent
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2d884e),@OnGameEventPlayerHitted,7,[F_RMEM+F_PUSH_ESP+$410, F_RMEM+F_PUSH_ESP+$41c], pointer(xrGame+$2d8874), JUMP_IF_FALSE, true, false);
  end;

  result:=true;
end;

function PatchServer():boolean;
begin
  result:=false;

  //Куча дряни в xrServer::Process_event_reject. Когда игрок во время смерти быстро кликает на аптеки - происходит креш
  //R_ASSERT			(e_parent && e_entity);
  //R_ASSERT3				(e_entity->ID_Parent == id_parent, e_entity->name_replace(), e_parent->name_replace());
  //R_ASSERT3				(C.end()!=c,e_entity->name_replace(),e_parent->name_replace());
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$3564d4),@xrServer__Process_event_reject_CheckEntities,7,[F_PUSH_ESI, F_PUSH_EDI], pointer(xrGame+$356562), JUMP_IF_FALSE, true, false);
  end;

  //Аналогично, при кликах по аптекам во время смерти мешают жить ассерты в CInventory::Eat
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$206092),@CInventory_Eat_CheckIsValid,8,[F_PUSH_EBX, F_RMEM+F_PUSH_ESP+$202C], pointer(xrGame+$20629b), JUMP_IF_FALSE, false, false);
  end;

  //[bug] Дерьмо с синхронизацией: IPureServer::DisconnectClient убивает клиента моментально, не проверяя ничего. Между тем, к уничтоженному клиенту еще могут обратиться потом, что вызовет проблемы
  //Полностью, похоже, не пофиксать. Но можно уменьшить частоту крешей.
  //Проверим в game_sv_mp::OnEvent, существует ли еще клиент, перед тем, как выполнять действия (так как у нас "отложенная" очередь событий, от момент получения сообщения до момента обработки клиент мог сдохнуть)
  //В наследниках game_sv_mp вроде проверки внутри OnEvent на существование клиента, к счастью, есть
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2d880e),@OnGameEvent_CheckClientExist,7,[F_RMEM+F_PUSH_ESP+$410, F_RMEM+F_PUSH_ESP+$414, F_RMEM+F_PUSH_ESP+$41c], pointer(xrGame+$2d8842), JUMP_IF_FALSE, true, false);
  end;

  //[bug] В game_sv_GameState::OnEvent вызов R_ASSERT совсем не смотрится - злоумышленник может запросто крешнуть сервак с его помощью.
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$2c2bb1), @OnGameEventNotImplenented, 60, [F_RMEM+F_PUSH_ESP+$428, F_RMEM+F_PUSH_ESP+$42C, F_RMEM+F_PUSH_ESP+$434], true, true);
  end;

  //[bug] CLevel::GetLevelInfo нет проверки на то, что сервер и game сейчас существуют. Из-за этого сервер может упасть при смене карты.
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

  //[bug] GAME_EVENT_PLAYER_KILLED может отсылать только локальный клиент. Проверяем в game_sv_mp::OnEvent
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2d881c),@OnGameEventPlayerKilled,7,[F_RMEM+F_PUSH_ESP+$410, F_RMEM+F_PUSH_ESP+$41c], pointer(xrGame+$2d8842), JUMP_IF_FALSE, true, false);
  end;

  //[bug] в xrServer::Process_event при обработке GE_DIE нет проверки на то, что e_src нашлось (строка 187) - в ЧН есть, так что добавляем
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcEBPReturnerInjection.Create(pointer(xrGame+$3556ce),@xrServer__Process_event_GE_DIE_CheckKillerGameEntity,6,[F_PUSH_EBP, F_PUSH_EBX], true, true);
  end;

  //[bug] в xrServer::Process_event при получении сообщения GE_DIE (Line 197) нет проверки на то, что c_src != null и c_src->owner != null
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$35572a),@Check_xrClientData_owner_valid,6,[F_PUSH_EBX], pointer(xrGame+$3557d0), JUMP_IF_FALSE, true, false);
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
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcKit.Get.nop_code(pointer(xrGame+$2d8285), 42);
  end;

  //[bug] Если в трупе остаются дочерние предметы, они препятствуют его удалению и вызывают спам в консоль в game_sv_mp::Update
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2d8235),@game_sv_mp__Update_could_corpse_be_removed,5,[F_PUSH_EAX], pointer(xrGame+$2d825a), JUMP_IF_TRUE, true, false);
  end;

  //[bug] Если уже убитый игрок до нажатия стрельбы (т.е. до перехода в спектаторы) выберет переход в наблюдатели, то на карте останется неудаляемый труп.
  //Исправление - на манер ЧН, в game_sv_mp::OnPlayerSelectSpectator добавим вызовы AllowDeadBodyRemove	и m_CorpseList.push_back.
  //Для упрощения жизни  - вызовем напрямую game_sv_mp::RespawnPlayer
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

  //Меняем имя сервера (в callback_serverkey)
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

  //Обновление имени карты xrGame+$1b6666
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$1b6666),@CLevel__net_start1_updatemapname,5,[F_PUSH_EDX], false, false);
  end;

  //Сохранение имени карты и режима
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$2d6a21),@xrServer__Connect_SaveCurrentMapInfo,6,[F_PUSH_ECX], false, false);
  end;

  //Загрузка использованных ранее имени карты и режима
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$1b614f),@CLevel__net_Start_overridelevelgametype,6,[], false, false);
  end;

  if xrGameDllType()=XRGAME_SV_10006 then begin
    //Отсылка пакета загрузки отсутствующей карты клиентом: xrGame+$2d6d9c
    srcBaseInjection.Create(pointer(xrGame+$2d6d9c),@OnAttachNewClient,5,[F_PUSH_EDI, F_PUSH_ESI], true, false); //in xrServer::AttachNewClient
  end;

  //создание буфера клиента
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$29FD40), @FromPlayerStateConstructor, 6, [F_PUSH_ESI], false, false);
    srcBaseInjection.Create(pointer(xrGame+$29FD56), @FromPlayerStateClear, 5, [F_PUSH_ECX], false, false);
    srcBaseInjection.Create(pointer(xrGame+$29FE65), @FromPlayerStateDestructor, 6, [F_PUSH_ESI], false, false);
  end;

  //Событие, когда клиент окончательно присоединен и готов  к игре - в xrServer::OnMessage M_CLIENTREADY
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$29e17e),@OnClientReady,6,[F_PUSH_ESI, F_PUSH_EAX], true, false);
  end;

  //[bug] удаление клиента - убиваем PlayerState, если клиент толком не прогрузился
  //Этим ликвидируем невыдачу клиенту денег при заходе на сервер
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$29d646),@xrServer__client_Destroy_force_destroy,6,[F_PUSH_EBX], pointer(xrGame+$29D6AC), JUMP_IF_TRUE, true, false);
  end;

  //[bug] или не совсем баг... патч в IPureServer::SendTo_LL : убираем ассерт при несуществующем клиенте, ибо если его нет - то и хрен с ним, обойдемся как-нибудь :)
  if not srcKit.Get.nop_code(pointer(xrNetServer+$a19e), 1, chr($EB)) then exit;

  //[bug] патчим запрещенные символы в нике игрока и проверяем длину
  if xrGameDllType()=XRGAME_SV_10006 then begin
    //в xrServer::new_client, при коннекте
    srcBaseInjection.Create(pointer(xrGame+$2D6BB4), @CorrectPlayerName, 5, [F_PUSH_ECX], false, false);

    //в game_sv_mp::OnPlayerChangeName, при попытке смены ника
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2DAE00), @CorrectPlayerNameWhenRenaming, 5, [F_RMEM+F_PUSH_ESP+4, F_RMEM+F_PUSH_ESP+8], pointer(xrGame+$2DAF28), JUMP_IF_FALSE, true, false);
  end;

  //[bug]защита от stalkazz - в xrGameSpyServer::OnMessage убеждаемся, что длина строки в пакете M_GAMESPY_CDKEY_VALIDATION_CHALLENGE_RESPOND меньше, чем размер буфера
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$35795c),@CheckIfPacketZStringIsLesserThenWithDisconnect,5,[F_PUSH_ESI, F_PUSHCONST+128, F_PUSH_EDI, F_PUSHCONST+$16, F_PUSHCONST+1], pointer(xrGame+$3579f0), JUMP_IF_FALSE, false, false);
  end;

  //[bug] Фикс для уязвимости DirtySky, найденной Luigi Auriemma. Суть в том, что в IPureServer::net_Handler при DPN_MSGID_CREATE_PLAYER вызов WideCharToMultiByte на большой строке не дает терминатора! А потом нетерминированная строка скармливается в strcpy_n
  srcBaseInjection.Create(pointer(xrNetServer+$9e34),@CheckClientConnectionName, 7,[F_PUSH_EDX, F_RMEM+F_PUSH_EBP+$0C], false, false);

  //[bug] В IPureServer::net_Handler также в DPN_MSGID_CREATE_PLAYER клиент имеет возможность отправить нам нетерминированные логин и пароль, которые мы слепо скопируем в SClientConnectData	cl_data
  srcBaseInjection.Create(pointer(xrNetServer+$9e90),@CheckClientConnectData, 7,[F_PUSH_ECX], true, false);

  //Пропатчимся на бан подсетей
  srcInjectionWithConditionalJump.Create(pointer(xrNetServer+$9fbf),@IPureServer__net_Handler_SubnetBans,5,[F_RMEM+F_PUSH_ESP+$0C],pointer(xrNetServer+$9fd3), JUMP_IF_TRUE, true, False);

  //Сообщение о том, что IP забанен в игровом банлисте
  srcBaseInjection.Create(pointer(xrNetServer+$9fd3),@IPureServer__net_Handler_OnBannedByGameIpFound,7,[F_RMEM+F_PUSH_ESP+$0C], true, False);

  //[bug] Фикс для stalker39x type A (by Luigi Auriemma) - переполнение буфера в IPureServer::_Recieve при попытке принять более 8192 байт данных
  srcInjectionWithConditionalJump.Create(pointer(xrNetServer+$93b0),@CheckIfDwordIsLesserThan, 5,[F_RMEM+F_PUSH_ESP+8, F_PUSHCONST+8192, F_RMEM+F_PUSH_ESP+$C, F_PUSHCONST+1],pointer(xrNetServer+$9490), JUMP_IF_FALSE, true, false);

  //[bug] Фикс для stalker39x type B (by Luigi Auriemma) - при получении некомпрешенного сообщения из 0 байт NET_Compressor::Decompress будет копировать u32(-1) байт
  srcInjectionWithConditionalJump.Create(pointer(xrNetServer+$742f),@IsArgNull,7,[F_PUSH_EAX],pointer(@SafeRetFrom_NET_Compressor__Decompress_1), JUMP_IF_TRUE, true, false);

  //[bug] Фикс для stalker39x type C (by Luigi Auriemma) - при получении MultipacketReciever::RecievePacket пакета, в байте компрессии которого невалидное значение - происходит int3
  srcInjectionWithConditionalJump.Create(pointer(xrNetServer+$6f40),@OneByteChecker,5,[F_PUSH_EAX, F_PUSHCONST+$E0, F_RMEM+F_PUSH_ESP+$802c, F_PUSHCONST+$1],pointer(xrNetServer+$7068), JUMP_IF_FALSE, true, true);

  //[bug] Assert на CRC в NET_Compressor::Decompress выполнять крайне не желательно
  srcInjectionWithConditionalJump.Create(pointer(xrNetServer+$7496),@AlwaysTrue, 14,[], pointer(@SafeRetFrom_NET_Compressor__Decompress_2), JUMP_IF_TRUE, false, false);

  //Вывод сообщения о неудачной декомпрессии пакета из MultipacketReciever::RecievePacket
  srcBaseInjection.Create(pointer(xrNetServer+$6f78),@CheckDecompressResult,5,[F_PUSH_EAX, F_RMEM+F_PUSH_ESP+$802c], true, False);

  //[bug] При смерти игрока со слишком большим числом предметов в инвентаре в game_sv_Deathmatch::OnDetach происходит переполнение EventPack. Решение - разбивать на несколько пакетов и отправлять их по мере заполнения
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$2d0cc0),@SplitEventPackPackets,7,[F_PUSH_ESP+$48], true, false);
  end;

  //[bug] При попытке подобрать рюкзак со слишком большим числом предметов в game_sv_Deathmatch::OnTouch происходит переполнение EventPack. Решение - разбивать на несколько пакетов и отправлять их по мере заполнения
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$2d04b0),@SplitEventPackPackets,6,[F_PUSH_ESP+$20], true, false);
  end;

  //[bug] При удалении рюкзака со слишком большим числом предметов в xrServer::Process_event_destroy происходит переполнение pEventPack. Решение - разбивать на несколько пакетов и отправлять их по мере заполнения
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$355ff5),@SplitEventPackPackets,6,[F_PUSH_EDI], true, false);
  end;

  //[bug] Логика обработка события GE_ADDON_DETACH позволяет клиентам заспавнить себе в рюкзак что угодно (или крешнуть сервак)
  //На исходниках - перерабатывать обработчик события.
  //Так как у нас бинарный патч - можем закостылять так:
  //1)В CInventoryItem::OnEvent производить вызов Detach(i_name, false); - тем самым у нас вообще не будет детача от произвольной хрени
  //2)В CWeaponMagazinedWGrenade::Detach и CWeaponMagazined::Detach при обнаружении валидного детача - исправлять аргумент на true
  if xrGameDllType()=XRGAME_SV_10006 then begin
    //правка аргумента с true на false в CInventoryItem::OnEvent
    srcKit.Get().nop_code(pointer(xrGame+$209c5b), 1, chr($00));

    //Исправления в CWeaponMagazined::Detach для постоянного детача аддонов со спавном
    tmp:=$9040c031; //xor eax, eax; inc eax
    srcKit.Get().CopyBuf(@tmp, pointer(xrGame+$2277d4), sizeof(tmp));
    tmp:=$9041c931; //xor ecx, ecx; inc ecx
    srcKit.Get().CopyBuf(@tmp, pointer(xrGame+$22784a), sizeof(tmp));
    srcKit.Get().CopyBuf(@tmp, pointer(xrGame+$2278bd), sizeof(tmp));

    //Исправления в CWeaponMagazinedWGrenade::Detach для постоянного детача аддонов со спавном
    tmp:=$9040c031; //xor eax, eax; inc eax
    srcKit.Get().CopyBuf(@tmp, pointer(xrGame+$22b2e8), sizeof(tmp));

    //В CInventoryItem::Detach будем ругаться при получении b_spawn_item = false на попытку нелегального спавна
    srcBaseInjection.Create(pointer(xrGame+$209ec0),@CInventoryItem_Detach_CheckForCheat,5,[F_PUSH_ECX, F_RMEM+F_PUSH_ESP+4, F_RMEM+F_PUSH_ESP+8], true, false);
  end;

  //[bug] Вылет сервера с последними строками 'cl setDestroy' в логе (при этом в дампе адрес в EIP для версии 1.0006 будет 6B6E7572).Переход по этому "левому" адресу происходит внутри CActor::shedule_Update.
  //Дело в том, что слот может начать указывать на объект, который уже НЕ принадлежит актору (мертвому), а находится в рюкзаке. После удаления рюкзака (и предмета в нем) указатель из слота начинает указывать на уже разрушенный объект,
  //у которого vtable указывает на методы базового абстрактного класса (с очень малым числом методов), поэтому при попытке взять метод производного класса берется совершенно не то, что надо (а 6B6E7572, являющееся вообще частью строки).
  //Почему так происходит? Допустим, у нас убили актора. В CActor::Die инициируется отправка GE_OWNERSHIP_REJECT - события для дропа рюкзкака. На следующем апдейте актора оно отправляется напрямую серверу, сервер его парсит в xrServer::Process_event_reject и
  //вызывает game->OnDetach. Внутри последней происходит генерация пар событий GE_OWNERSHIP_REJECT | GE_OWNERSHIP_TAKE для предметов в инвентаре актора, которые надо перекинуть в рюкзак. Пакеты с этими парами немедленно обрабатываются сервером (происходит
  //перестройка отношений владения), после чего отправляются в CLevel::OnMessage, где укладываются в очередь приходящих сообщений. Напоследок туда же отправляется и GE_OWNERSHIP_REJECT для рюкзака. На данном этапе об изменениях во владении знает только сервер!
  //Но теперь в очередь клиента вслед за парами событий может упасть нечто другое - например, GEG_PLAYER_ITEM2SLOT (инициированное либо игроков, либо откуда-то из движка - например из CGrenade::PutNextToSlot).
  //Но что будет происходить на апдейте CLevel'a, когда будут извлечены сообщения из очереди?
  //-GE_OWNERSHIP_REJECT будут переадресованы в CActor::OnEvent, в котором будет вызван inventory().DropItem. Предмет выпадет из инвентаря, очистится его слот, m_pCurrentInventory и т.д. Далее обнулится Parent.
  //-GE_OWNERSHIP_TAKE будут переадресованы в CMPPlayersBag::OnEvent, в котором выставится новый Parent.
  //-Последующий GEG_PLAYER_ITEM2SLOT приведет к тому, что в слот актора будет положен предмет, который находится не в его инвентаре, а в выпавшем рюкзаке! Но рюкзак об этом ничего не знает!
  //Теперь осталось только дождаться момента, когда рюкзак со всем содержимым будет удален из игры, и на следующем апдейте все закономерно упадет.
  //Выводы:
  //1) В xrServer::Process_event надо убедиться, что в инвентарных сообщениях актор оперирует именно СВОИМ предметом (т.е. что владение уже не было изменено)
  //2) В xrServer::Process_event проверять, что предмет ЕЩЕ НЕ УДАЛЕН перед выполнением инвентарных операций
  //3) В CActor::OnEvent перед операциями со слотами/инвентарем на манер ЧН проверять, что актор еще жив (обезопасимся от креша сервера)(решил пока не делать)
  //UPD: Похоже, что есть другой вариант креша - с числом 5C616433 при вызове каста к артефакту (?) из CActor::Die. Симптом тот же - невалидный указатель на объект при итерировании по инвентарю

  //Подключаем фильтр для исправления проблем с xrServer::Process_event
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$355216),@CheckGameEventPacket,6,[F_PUSH_EAX, F_RMEM+F_PUSH_ESP+$124], pointer(xrGame+$355a07), JUMP_IF_FALSE, true, false);
  end;

  //[bug] В game_sv_GameState::NewPlayerName_Exists отсутствует защита захватом критической секции
  //Дополнительно добавляем проверку на NULL в имени при копировании - ибо таких мест в движке вагон
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$2c2c40),@LockServerPlayers,8,[], true, false);
    srcBaseInjection.Create(pointer(xrGame+$2c2d2b),@UnlockServerPlayers,6,[], true, false);
    srcBaseInjection.Create(pointer(xrGame+$2c2d36),@UnlockServerPlayers,6,[], true, false);
    srcBaseInjection.Create(pointer(xrGame+$2c2d3f),@UnlockServerPlayers,6,[], true, false);

    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2c2cda),@IsArgNull,6,[F_PUSH_ECX], pointer(xrGame+$2c2d1f), JUMP_IF_TRUE, true, false);
  end;

  //Дополнительные вещи в апдейте game
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$2d8130),@game_sv_mp__Update_additionals,6,[], true, false);
  end;

  //Сохранение и сброс ID радмины при выполнении консольной команды от него
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$29de5d),@xrServer__OnDelayedMessage_before_radmincmd,5,[F_PUSH_EAX, F_RMEM+F_PUSH_ESP+$18], false, false);
    srcBaseInjection.Create(pointer(xrGame+$29de6c),@xrServer__OnDelayedMessage_after_radmincmd,6,[F_RMEM+F_PUSH_ESP+$14], false, false);
  end;

  if FZConfigMgr.Get.GetBool('patch_updrate', true) then begin
    //dynamic update rate - патч в IPureServer::HasBandwidth
    srcECXReturnerInjection.Create(pointer(xrNetServer+$a38a),@SelectUpdRate,6,[F_PUSH_EDI,F_RMEM+F_PUSH_ESP+$10, F_PUSH_ECX], false, false, 0);
  end;

  //Блокировка самостоятельной смены команды игроком
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2db29d),@game_sv_mp__OnPlayerGameMenu_isteamchangeblocked,6,[F_RMEM+F_PUSH_ESP+$0C, F_PUSH_EAX], pointer(xrGame+$2db2ad), JUMP_IF_TRUE, false, false);
  end;

  //Назначение предыдущей команды при реконнекте игрока, смена команды для которого заблокирована
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcEAXReturnerInjection.Create(pointer(xrGame+$2d728c), @game_sv_TeamDeathmatch__OnPlayerConnect_selectteam, 6, [F_PUSH_EBX, F_PUSH_EAX], true, false, 0);
  end;

  //Отслеживание пакетов GEG_PLAYER_WEAPON_HIDE_STATE игрока с целью выявления моментов, когда у него открыты меню (главное, инвентаря, выбора команд и скинов и т.п.). Смена команды игрока в эти моменты чревата багами.
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$3558b6),@xrServer__Process_event_onweaponhide,5,[F_PUSH_ECX, F_PUSH_EBP, F_PUSH_EDI], true, false);
  end;

  //Отслеживание спавна игрока
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$2d8b70),@game_sv_mp_OnSpawnPlayer,5,[F_RMEM+F_PUSH_ESP+$4, F_RMEM+F_PUSH_ESP+$8], true, false);
    //на всякий - из game_sv_mp_script::SpawnPlayer
    srcBaseInjection.Create(pointer(xrGame+$2dd970),@game_sv_mp_OnSpawnPlayer,5,[F_RMEM+F_PUSH_ESP+$4, F_RMEM+F_PUSH_ESP+$8], true, false);
  end;

  //Обработка тимкиллов
  if xrGameDllType()=XRGAME_SV_10006 then begin
    //game_sv_TeamDeathmatch::OnPlayerKillPlayer
    srcInjectionWithConditionalJump.Create(pointer(xrGame+$2d770f),@OnTeamKill, 40, [F_PUSH_EBX, F_PUSH_EDI], pointer(xrGame+$2d77ac), JUMP_IF_FALSE, false, true);
    //В game_sv_TeamDeathmatch::OnPlayerConnectFinished убираем обнуление m_iTeamKills в стате игрока
    srcKit.Get().nop_code(pointer(xrGame+$2d73cc), 6);
  end;

  //скорость прокачки рангов
  if xrGameDllType()=XRGAME_SV_10006 then begin
    srcBaseInjection.Create(pointer(xrGame+$2db710), @game_sv_mp__Player_AddExperience_expspeed, 5, [F_PUSH_ESP+$8], true, false);
  end;

  //неуязвимость игроков
    if xrGameDllType()=XRGAME_SV_10006 then begin
      //в game_sv_Deathmatch::check_InvinciblePlayers пропускаем стандартные проверки на неуязвимость, если она контролируется нами
      srcInjectionWithConditionalJump.Create(pointer(xrGame+$2d0fe1),@IsInvincibilityControlledByFZ, 5,[F_PUSH_EDI], pointer(xrGame+$2d1003), JUMP_IF_TRUE, true, false);
      //в game_sv_ArtefactHunt::OnPlayerHitPlayer_Case добавляем проверку на отключенную неуязвимость, чтобы хит не обнулялся на базах
      srcInjectionWithConditionalJump.Create(pointer(xrGame+$2cc153),@IsInvincibilityControlledByFZ, 6,[F_PUSH_EBX], pointer(xrGame+$2cc178), JUMP_IF_TRUE, true, false);
      //проверка на необходимость сбросить неуязвимость в game_sv_Deathmatch::OnPlayerFire
      srcInjectionWithConditionalJump.Create(pointer(xrGame+$2d1b14),@IsInvinciblePersistAfterShot, 6,[F_PUSH_EAX], pointer(xrGame+$2d1b42), JUMP_IF_TRUE, true, false);
    end;

  result:=true;
end;

end.

