unit ge_filter;

{$mode delphi}

interface
uses Packets;

function CheckGameEventPacket(p:pNET_Packet; clid:cardinal):boolean; stdcall;

function Init():boolean;
procedure Free();

implementation
uses Clients, CSE, Games, Sysutils, Players, HackProcessor, LogMgr, Servers, CommonHelper, ConfigCache;

type
  FZGECheckResult = record
    success:boolean;
  end;

  { FZGEHandler }
  FZGEHandler = class
    _eventType:word;
    _eventDescr:string;
  public
    constructor Create(eventType:word; eventDescr:string);
    function ValidatePacket(sender:pxrClientData; receiver:pCSE_Abstract; pData:pointer; remained_cnt:cardinal):FZGECheckResult; virtual; abstract;
    procedure FireBadEvent(sender:pxrClientData; attack:boolean; descr_override:string='');
  end;

  { FZGEInvalidHandler }
  FZGEInvalidHandler = class(FZGEHandler)
  public
    function ValidatePacket(sender:pxrClientData; {%H-}receiver:pCSE_Abstract; {%H-}pData:pointer; {%H-}remained_cnt:cardinal):FZGECheckResult; override;
  end;

  { FZGEServerOnlyEventHandler }
  FZGEServerOnlyEventHandler = class(FZGEHandler)
  private
    _silent:boolean;
  public
    constructor Create(eventType:word; eventDescr:string; silent:boolean=false);
    function ValidatePacket(sender:pxrClientData; {%H-}receiver:pCSE_Abstract; {%H-}pData:pointer; {%H-}remained_cnt:cardinal):FZGECheckResult; override;
  end;

  { FZGELengthCheckerPacketHandler }
  FZGELengthCheckerPacketHandler = class(FZGEHandler)
    _counter:cardinal;
  public
    constructor Create(counter:cardinal; eventType:word; eventDescr:string);
    function ValidatePacket(sender:pxrClientData; receiver:pCSE_Abstract; {%H-}pData:pointer; remained_cnt:cardinal):FZGECheckResult; override;
  end;

  { FZGEOwnershipTakeCheckerPacket }
  FZGEOwnershipTakeCheckerPacket = class(FZGEHandler)
  public
    function ValidatePacket(sender:pxrClientData; receiver:pCSE_Abstract; pData:pointer; remained_cnt:cardinal):FZGECheckResult; override;
  end;

  { FZGEInventoryOperationCheckerPacket }
  FZGEInventoryOperationCheckerPacket = class(FZGEHandler)
  private
    _allow_unexistant:boolean;
  public
    constructor Create(eventType:word; eventDescr:string; allow_unexistant:boolean=false);
    function ValidatePacket(sender:pxrClientData; receiver:pCSE_Abstract; pData:pointer; remained_cnt:cardinal):FZGECheckResult; override;
  end;

  { FZGEAddonAttachCheckerPacket }
  FZGEAddonAttachCheckerPacket = class(FZGEHandler)
  public
    function ValidatePacket(sender:pxrClientData; receiver:pCSE_Abstract; pData:pointer; remained_cnt:cardinal):FZGECheckResult; override;
  end;

  { FZGEAddonDetachCheckerPacket }
  FZGEAddonDetachCheckerPacket = class(FZGEHandler)
  public
    function ValidatePacket(sender:pxrClientData; receiver:pCSE_Abstract; pData:pointer; remained_cnt:cardinal):FZGECheckResult; override;
  end;

  { FZGESlotActivationHandler }
  FZGESlotActivationHandler = class(FZGEHandler)
  public
    function ValidatePacket(sender:pxrClientData; receiver:pCSE_Abstract; pData:pointer; remained_cnt:cardinal):FZGECheckResult; override;
  end;

const
  GE_FILTER_GROUP:string = '[GE_FILTER] ';
  GE_FILTER_GROUP_BAD:string = '[GE_FILTER_BAD] ';

{ FZGEHandler }
constructor FZGEHandler.Create(eventType: word; eventDescr: string);
begin
  _eventType:=eventType;
  _eventDescr:=eventDescr;
end;

procedure FZGEHandler.FireBadEvent(sender: pxrClientData; attack: boolean; descr_override: string);
var
  t:FZSecurityEventType;
  msg:string;
begin
  if attack then t:=FZ_SEC_EVENT_ATTACK else t:=FZ_SEC_EVENT_WARN;
  if length(descr_override) = 0 then descr_override:=_eventDescr;
  msg:=GE_FILTER_GROUP_BAD+GenerateMessageForClientId(sender.base_IClient.ID.id, 'sent '+descr_override+' event packet (type #'+inttostr(_eventType)+')');
  BadEventsProcessor(t, msg);
end;

{ FZGEInvalidHandler }
function FZGEInvalidHandler.ValidatePacket(sender:pxrClientData; receiver:pCSE_Abstract; pData:pointer; remained_cnt:cardinal): FZGECheckResult;
begin
  FireBadEvent(sender, true);
  result.success:=false;
end;

{ FZGEServerOnlyEventHandler }
constructor FZGEServerOnlyEventHandler.Create(eventType: word; eventDescr: string; silent: boolean);
begin
  inherited Create(eventType, eventDescr);
  _silent:=silent;
end;

function FZGEServerOnlyEventHandler.ValidatePacket(sender:pxrClientData; receiver:pCSE_Abstract; pData:pointer; remained_cnt:cardinal): FZGECheckResult;
begin
  result.success:=IsLocalServerClient(@sender.base_IClient);
  if not result.success and not _silent then begin
    FireBadEvent(sender, true);
  end;
end;

{ FZGELengthCheckerPacketHandler }
constructor FZGELengthCheckerPacketHandler.Create(counter: cardinal; eventType: word; eventDescr: string);
begin
  inherited Create(eventType, eventDescr);
  _counter:=counter;
end;

function FZGELengthCheckerPacketHandler.ValidatePacket(sender:pxrClientData; receiver:pCSE_Abstract; pData:pointer; remained_cnt:cardinal): FZGECheckResult;
begin
  result.success:=false;
  if receiver = nil then begin
    FZLogMgr.Get.Write(GE_FILTER_GROUP+GenerateMessageForClientId(sender.base_IClient.ID.id, 'sent '+_eventDescr+' event for entity which doesn''t exist'), FZ_LOG_ERROR);
  end else if not IsLocalServerClient(@sender.base_IClient) and not IsServerObjectControlledByClient(receiver, sender) then begin
    FZLogMgr.Get.Write(GE_FILTER_GROUP+GenerateMessageForClientId(sender.base_IClient.ID.id, 'sent '+_eventDescr+' event for not own entity'), FZ_LOG_ERROR);
  end else begin
    result.success:=remained_cnt >= _counter;

    if not result.success then begin
      FireBadEvent(sender, true, 'corrupted '+_eventDescr);
    end;
  end;
end;

{ FZGEOwnershipTakeCheckerPacket }
function FZGEOwnershipTakeCheckerPacket.ValidatePacket(sender: pxrClientData; receiver: pCSE_Abstract; pData: pointer; remained_cnt: cardinal): FZGECheckResult;
var
  entity_id:word;
  entity:pCSE_Abstract;
begin
  result.success:=false;
  if not FZCommonHelper.MovingPointerReader(pData, remained_cnt, @entity_id, sizeof(entity_id)) then begin
    FireBadEvent(sender, true, 'corrupted '+_eventDescr);
  end else if receiver=nil then begin
    FZLogMgr.Get.Write(GE_FILTER_GROUP+GenerateMessageForClientId(sender.base_IClient.ID.id, 'sent '+_eventDescr+' event for entity which doesn''t exist'), FZ_LOG_DBG);
  end else if not IsLocalServerClient(@sender.base_IClient) and not IsServerObjectControlledByClient(receiver, sender) then begin
    FZLogMgr.Get.Write(GE_FILTER_GROUP+GenerateMessageForClientId(sender.base_IClient.ID.id, 'sent '+_eventDescr+' event for not own entity'), FZ_LOG_ERROR);
  end else begin
    entity:=EntityFromEid(@GetCurrentGame.base_game_sv_GameState, entity_id);
    if entity=nil then begin
      FZLogMgr.Get.Write(GE_FILTER_GROUP+GenerateMessageForClientId(sender.base_IClient.ID.id, 'sent '+_eventDescr+' event for unexistent item ('+inttostr(entity_id)+')'), FZ_LOG_DBG);
    end else if (entity.ID_Parent<>$FFFF) and (entity.ID_Parent<>receiver.ID) then begin
      FZLogMgr.Get.Write(GE_FILTER_GROUP+GenerateMessageForClientId(sender.base_IClient.ID.id, 'sent '+_eventDescr+' event for item ('+inttostr(entity_id)+') with existent parent'), FZ_LOG_ERROR);
    end else begin
      result.success:=true;
    end;
  end;
end;

{ FZGEInventoryOperationCheckerPacket }
constructor FZGEInventoryOperationCheckerPacket.Create(eventType: word; eventDescr: string; allow_unexistant: boolean);
begin
  inherited Create(eventType, eventDescr);
  _allow_unexistant:=allow_unexistant;
end;

function FZGEInventoryOperationCheckerPacket.ValidatePacket(sender: pxrClientData; receiver: pCSE_Abstract; pData: pointer; remained_cnt: cardinal): FZGECheckResult;
var
  entity_id:word;
  entity:pCSE_Abstract;
begin
  result.success:=false;
  if not FZCommonHelper.MovingPointerReader(pData, remained_cnt, @entity_id, sizeof(entity_id)) then begin
    FireBadEvent(sender, true, 'corrupted '+_eventDescr);
  end else if receiver=nil then begin
    FZLogMgr.Get.Write(GE_FILTER_GROUP+GenerateMessageForClientId(sender.base_IClient.ID.id, 'sent '+_eventDescr+' event for entity which doesn''t exist'), FZ_LOG_ERROR);
  end else if not IsLocalServerClient(@sender.base_IClient) and not IsServerObjectControlledByClient(receiver, sender) then begin
    FZLogMgr.Get.Write(GE_FILTER_GROUP+GenerateMessageForClientId(sender.base_IClient.ID.id, 'sent '+_eventDescr+' event for not own entity'), FZ_LOG_ERROR);
  end else begin
    entity:=EntityFromEid(@GetCurrentGame.base_game_sv_GameState, entity_id);
    //Проверкой на локального клиента подавляем спам на GEG_PLAYER_ITEM2RUCK
    if (entity=nil) then begin
      if not IsLocalServerClient(@sender.base_IClient) then begin
        if not _allow_unexistant then FZLogMgr.Get.Write(GE_FILTER_GROUP+GenerateMessageForClientId(sender.base_IClient.ID.id, 'sent '+_eventDescr+' event for unexistent item'), FZ_LOG_ERROR);
      end;
    end else if entity.ID_Parent<>receiver.ID then begin
      if not IsLocalServerClient(@sender.base_IClient) then begin
        FZLogMgr.Get.Write(GE_FILTER_GROUP+GenerateMessageForClientId(sender.base_IClient.ID.id, 'sent '+_eventDescr+' event for not own item'), FZ_LOG_ERROR);
      end;
    end else begin
      result.success:=true;
    end;
  end;
end;

{ FZGEAddonAttachCheckerPacket }
function FZGEAddonAttachCheckerPacket.ValidatePacket(sender: pxrClientData; receiver: pCSE_Abstract; pData: pointer; remained_cnt: cardinal): FZGECheckResult;
var
  addon_id:word;
  addon:pCSE_Abstract;
begin
  result.success:=false;
  if not FZCommonHelper.MovingPointerReader(pData, remained_cnt, @addon_id, sizeof(addon_id)) then begin
    FireBadEvent(sender, true, 'corrupted '+_eventDescr);
  end else if receiver=nil then begin
    FZLogMgr.Get.Write(GE_FILTER_GROUP+GenerateMessageForClientId(sender.base_IClient.ID.id, 'sent '+_eventDescr+' event for entity which doesn''t exist'), FZ_LOG_ERROR);
  end else if not IsLocalServerClient(@sender.base_IClient) and not IsServerObjectControlledByClient(receiver, sender) then begin
    FZLogMgr.Get.Write(GE_FILTER_GROUP+GenerateMessageForClientId(sender.base_IClient.ID.id, 'sent '+_eventDescr+' event for not own entity'), FZ_LOG_ERROR);
  end else begin
    addon:=EntityFromEid(@GetCurrentGame.base_game_sv_GameState, addon_id);
    if addon=nil then begin
      FZLogMgr.Get.Write(GE_FILTER_GROUP+GenerateMessageForClientId(sender.base_IClient.ID.id, 'sent '+_eventDescr+' event for unexistent addon  ('+inttostr(addon_id)+')'), FZ_LOG_ERROR);
    end else if not IsLocalServerClient(@sender.base_IClient) and not IsServerObjectControlledByClient(addon, sender) then begin
      FZLogMgr.Get.Write(GE_FILTER_GROUP+GenerateMessageForClientId(sender.base_IClient.ID.id, 'sent '+_eventDescr+' event for not own addon ('+inttostr(addon_id)+')'), FZ_LOG_ERROR);
    end else begin
      result.success:=true;
    end;
  end;
end;

{ FZGEAddonDetachCheckerPacket }
function FZGEAddonDetachCheckerPacket.ValidatePacket(sender: pxrClientData; receiver: pCSE_Abstract; pData: pointer; remained_cnt: cardinal): FZGECheckResult;
var
  tmpstr:string;
  c:char;
begin
  //[bug] Тут передается (кто бы мог подумать) имя секции, которое затем (кто бы снова мог такое подумать!) отправляется прямиком для создания спавнящегося объекта
  result.success:=false;

  if receiver=nil then begin
    FZLogMgr.Get.Write(GE_FILTER_GROUP+GenerateMessageForClientId(sender.base_IClient.ID.id, 'sent '+_eventDescr+' event for entity which doesn''t exist'), FZ_LOG_ERROR);
    exit;
  end else if not IsLocalServerClient(@sender.base_IClient) and not IsServerObjectControlledByClient(receiver, sender) then begin
    FZLogMgr.Get.Write(GE_FILTER_GROUP+GenerateMessageForClientId(sender.base_IClient.ID.id, 'sent '+_eventDescr+' event for not own entity'), FZ_LOG_ERROR);
    exit;
  end;

  while (length(tmpstr)<64) and FZCommonHelper.MovingPointerReader(pData, remained_cnt, @c, sizeof(c)) do begin
    if c = chr(0) then begin
      result.success:=true;
      break;
    end else begin
      tmpstr:=tmpstr+c;
    end;
  end;

  if not result.success then begin
    FireBadEvent(sender, true, 'corrupted '+_eventDescr);
  end;
end;

{ FZGESlotActivationHandler }
function FZGESlotActivationHandler.ValidatePacket(sender: pxrClientData; receiver: pCSE_Abstract; pData: pointer; remained_cnt: cardinal): FZGECheckResult;
var
  slot:integer;
begin
  result.success:=false;

  if receiver=nil then begin
    FZLogMgr.Get.Write(GE_FILTER_GROUP+GenerateMessageForClientId(sender.base_IClient.ID.id, 'sent '+_eventDescr+' event for entity which doesn''t exist'), FZ_LOG_ERROR);
  end else if not IsLocalServerClient(@sender.base_IClient) and not IsServerObjectControlledByClient(receiver, sender) then begin
    FZLogMgr.Get.Write(GE_FILTER_GROUP+GenerateMessageForClientId(sender.base_IClient.ID.id, 'sent '+_eventDescr+' event for not own entity'), FZ_LOG_ERROR);
  end else if FZCommonHelper.MovingPointerReader(pData, remained_cnt, @slot, sizeof(slot)) then begin
    if (slot < -1) or (slot > 10) then begin
      FireBadEvent(sender, true, 'invalid '+_eventDescr);
    end else begin
      result.success:=true;
    end;
  end else begin
    FireBadEvent(sender, true, 'corrupted '+_eventDescr);
  end;
end;


var
  GEHandlers:array[0..50] of FZGEHandler;

type EventHeader = packed record
  timestamp:cardinal;
  eventtype:word;
  destination:word;
end;

function CheckGameEventPacket(p:pNET_Packet; clid:cardinal):boolean; stdcall;
var
  pData:pointer;
  cld:pxrClientData;
  remained_cnt:cardinal;

  header:EventHeader;
  receiver:pCSE_Abstract;
begin
  result:=false;
  if p=nil then begin
    FZLogMgr.Get().Write(GE_FILTER_GROUP+'No packet in CheckGameEventPacket', FZ_LOG_ERROR);
    exit;
  end;

  cld:=ID_to_client(clid);
  if cld = nil then begin
    FZLogMgr.Get().Write(GE_FILTER_GROUP+'Packet from unexistent client with ID='+inttostr(clid), FZ_LOG_ERROR);
    exit;
  end;

  pData:=@p.B.data[p.r_pos];
  remained_cnt:= UnreadBytesCountInPacket(p);
  if not FZCommonHelper.MovingPointerReader(pData, remained_cnt, @header, sizeof(header)) then begin
    BadEventsProcessor(FZ_SEC_EVENT_ATTACK, GE_FILTER_GROUP+GenerateMessageForClientId(clid, 'sent message which header can''t be read' ));
    exit;
  end;

  receiver:=EntityFromEid(@GetCurrentGame.base_game_sv_GameState, header.destination);

  if FZConfigCache.Get().GetDataCopy().log_events then begin
    FZLogMgr.Get().Write(GenerateMessageForClientId(clid, 'sent '+inttostr(header.eventtype)+' for #'+inttostr(header.destination)), FZ_LOG_IMPORTANT_INFO);
  end;

  if (receiver<>nil) and (receiver.owner = nil) then begin
    BadEventsProcessor(FZ_SEC_EVENT_ATTACK, GE_FILTER_GROUP+GenerateMessageForClientId(clid, 'sent event type '+inttostr(header.eventtype)+' for receiver without owner'));
  end else if header.eventtype >= length(GEHandlers) then begin
    BadEventsProcessor(FZ_SEC_EVENT_ATTACK, GE_FILTER_GROUP+GenerateMessageForClientId(clid, 'sent invalid event type '+inttostr(header.eventtype)));
  end else if GEHandlers[header.eventtype] = nil then begin
    result:=true;
  end else begin
    result:=GEHandlers[header.eventtype].ValidatePacket(cld, receiver, pData, remained_cnt).success;
  end;

end;

function Init():boolean;
begin
  GEHandlers[GE_RESPAWN]:=FZGEServerOnlyEventHandler.Create(GE_RESPAWN, 'GE_RESPAWN');
  GEHandlers[GE_OWNERSHIP_TAKE]:=FZGEOwnershipTakeCheckerPacket.Create(GE_OWNERSHIP_TAKE, 'GE_OWNERSHIP_TAKE');
  GEHandlers[GE_OWNERSHIP_TAKE_MP_FORCED]:=FZGEOwnershipTakeCheckerPacket.Create(GE_OWNERSHIP_TAKE_MP_FORCED, 'GE_OWNERSHIP_TAKE_MP_FORCED');
  GEHandlers[GE_OWNERSHIP_REJECT]:=FZGEInventoryOperationCheckerPacket.Create(GE_OWNERSHIP_REJECT, 'GE_OWNERSHIP_REJECT');
  GEHandlers[GE_TRANSFER_AMMO]:=FZGEServerOnlyEventHandler.Create(GE_TRANSFER_AMMO, 'GE_TRANSFER_AMMO');
  GEHandlers[GE_HIT]:=nil;
  GEHandlers[GE_DIE]:=FZGEServerOnlyEventHandler.Create(GE_DIE, 'GE_DIE');
  GEHandlers[GE_ASSIGN_KILLER]:=FZGEServerOnlyEventHandler.Create(GE_ASSIGN_KILLER, 'GE_ASSIGN_KILLER');
  GEHandlers[GE_DESTROY]:=FZGEServerOnlyEventHandler.Create(GE_DESTROY, 'GE_DESTROY');
  GEHandlers[GE_DESTROY_REJECT]:=FZGEInvalidHandler.Create(GE_DESTROY_REJECT, 'GE_DESTROY_REJECT');
  GEHandlers[GE_TELEPORT_OBJECT]:=nil;
  GEHandlers[GE_ADD_RESTRICTION]:=nil;
  GEHandlers[GE_REMOVE_RESTRICTION]:=nil;
  GEHandlers[GE_REMOVE_ALL_RESTRICTIONS]:=nil;
  GEHandlers[GE_BUY]:=FZGEInvalidHandler.Create(GE_BUY, 'GE_BUY');
  GEHandlers[GE_INFO_TRANSFER]:=FZGEServerOnlyEventHandler.Create(GE_INFO_TRANSFER, 'GE_INFO_TRANSFER');
  GEHandlers[GE_TRADE_SELL]:=FZGEServerOnlyEventHandler.Create(GE_TRADE_SELL, 'GE_TRADE_SELL');
  GEHandlers[GE_TRADE_BUY]:=FZGEServerOnlyEventHandler.Create(GE_TRADE_BUY, 'GE_TRADE_BUY');
  GEHandlers[GE_WPN_AMMO_ADD]:=FZGEInvalidHandler.Create(GE_WPN_AMMO_ADD, 'GE_WPN_AMMO_ADD');
  GEHandlers[GE_WPN_STATE_CHANGE]:=FZGEServerOnlyEventHandler.Create(GE_WPN_STATE_CHANGE, 'GE_WPN_STATE_CHANGE');
  GEHandlers[GE_ADDON_ATTACH]:=FZGEAddonAttachCheckerPacket.Create(GE_ADDON_ATTACH, 'GE_ADDON_ATTACH');
  GEHandlers[GE_ADDON_DETACH]:=FZGEAddonDetachCheckerPacket.Create(GE_ADDON_DETACH, 'GE_ADDON_DETACH');
  GEHandlers[GE_ADDON_CHANGE]:=FZGEInvalidHandler.Create(GE_ADDON_CHANGE, 'GE_ADDON_CHANGE');
  GEHandlers[GE_INSTALL_UPGRADE]:=FZGEServerOnlyEventHandler.Create(GE_INSTALL_UPGRADE, 'GE_INSTALL_UPGRADE');
  GEHandlers[GE_GRENADE_EXPLODE]:=FZGEServerOnlyEventHandler.Create(GE_GRENADE_EXPLODE, 'GE_GRENADE_EXPLODE');
  GEHandlers[GE_INV_ACTION]:= FZGELengthCheckerPacketHandler.Create(4*sizeof(cardinal), GE_INV_ACTION, 'GE_INV_ACTION');
  GEHandlers[GE_ZONE_STATE_CHANGE]:=nil; //FZGEServerOnlyEventHandler.Create(GE_ZONE_STATE_CHANGE, 'GE_ZONE_STATE_CHANGE', true);
  GEHandlers[GE_MOVE_ACTOR]:=FZGEInvalidHandler.Create(GE_MOVE_ACTOR, 'GE_MOVE_ACTOR');
  GEHandlers[GE_ACTOR_JUMPING]:=nil;
  GEHandlers[GE_ACTOR_MAX_POWER]:=FZGEInvalidHandler.Create(GE_ACTOR_MAX_POWER, 'GE_ACTOR_MAX_POWER');
  GEHandlers[GE_ACTOR_MAX_HEALTH]:=FZGEInvalidHandler.Create(GE_ACTOR_MAX_HEALTH, 'GE_ACTOR_MAX_HEALTH');
  GEHandlers[GE_CHANGE_POS]:=FZGEServerOnlyEventHandler.Create(GE_CHANGE_POS, 'GE_CHANGE_POS'); //Teleport?
  GEHandlers[GE_GAME_EVENT]:=nil;
  GEHandlers[GE_CHANGE_VISUAL]:=FZGEServerOnlyEventHandler.Create(GE_CHANGE_VISUAL, 'GE_CHANGE_VISUAL');
  GEHandlers[GE_MONEY]:=FZGEServerOnlyEventHandler.Create(GE_MONEY, 'GE_MONEY');
  GEHandlers[GEG_PLAYER_ACTIVATE_SLOT]:= FZGESlotActivationHandler.Create(GEG_PLAYER_ACTIVATE_SLOT, 'GEG_PLAYER_ACTIVATE_SLOT');
  GEHandlers[GEG_PLAYER_ITEM2SLOT]:= FZGEInventoryOperationCheckerPacket.Create(GEG_PLAYER_ITEM2SLOT, 'GEG_PLAYER_ITEM2SLOT');
  GEHandlers[GEG_PLAYER_ITEM2BELT]:= FZGEInventoryOperationCheckerPacket.Create(GEG_PLAYER_ITEM2BELT, 'GEG_PLAYER_ITEM2BELT');
  GEHandlers[GEG_PLAYER_ITEM2RUCK]:= FZGEInventoryOperationCheckerPacket.Create(GEG_PLAYER_ITEM2SLOT, 'GEG_PLAYER_ITEM2RUCK');
  GEHandlers[GEG_PLAYER_ITEM_EAT]:= FZGEInventoryOperationCheckerPacket.Create(GEG_PLAYER_ITEM_EAT, 'GEG_PLAYER_ITEM_EAT', true);
  GEHandlers[GEG_PLAYER_ITEM_SELL]:=nil;
  GEHandlers[GEG_PLAYER_ACTIVATEARTEFACT]:= FZGEInventoryOperationCheckerPacket.Create(GEG_PLAYER_ACTIVATEARTEFACT, 'GEG_PLAYER_ACTIVATEARTEFACT');
  GEHandlers[GEG_PLAYER_WEAPON_HIDE_STATE]:= FZGELengthCheckerPacketHandler.Create(sizeof(cardinal)+sizeof(byte), GEG_PLAYER_WEAPON_HIDE_STATE, 'GEG_PLAYER_WEAPON_HIDE_STATE');
  GEHandlers[GEG_PLAYER_DISABLE_SPRINT]:=FZGEServerOnlyEventHandler.Create(GEG_PLAYER_DISABLE_SPRINT, 'GEG_PLAYER_DISABLE_SPRINT');
  GEHandlers[GEG_PLAYER_ATTACH_HOLDER]:= FZGELengthCheckerPacketHandler.Create(sizeof(cardinal), GEG_PLAYER_ATTACH_HOLDER, 'GEG_PLAYER_ATTACH_HOLDER');
  GEHandlers[GEG_PLAYER_DETACH_HOLDER]:= FZGELengthCheckerPacketHandler.Create(sizeof(cardinal), GEG_PLAYER_DETACH_HOLDER, 'GEG_PLAYER_DETACH_HOLDER');
  GEHandlers[GEG_PLAYER_PLAY_HEADSHOT_PARTICLE]:=FZGEServerOnlyEventHandler.Create(GEG_PLAYER_PLAY_HEADSHOT_PARTICLE, 'GEG_PLAYER_PLAY_HEADSHOT_PARTICLE'); //Teleport?
  GEHandlers[GE_HIT_STATISTIC]:=nil;
  GEHandlers[GE_KILL_SOMEONE]:=FZGEInvalidHandler.Create(GE_KILL_SOMEONE, 'GE_KILL_SOMEONE');
  GEHandlers[GE_FREEZE_OBJECT]:=nil;
  GEHandlers[GE_LAUNCH_ROCKET]:=FZGEServerOnlyEventHandler.Create(GE_LAUNCH_ROCKET, 'GE_LAUNCH_ROCKET');

  result:=true;
end;

procedure Free();
var
  i:cardinal;
begin
  for i:=0 to length(GEHandlers)-1 do begin
    GEHandlers[i].Free;
  end;
end;

end.

