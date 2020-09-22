unit HackProcessor;

{$mode delphi}

interface
uses Clients;

type
  FZSecurityEventType = (FZ_SEC_EVENT_ATTACK, FZ_SEC_EVENT_WARN, FZ_SEC_EVENT_INFO);

procedure BadEventsProcessor(t: FZSecurityEventType; description: string); stdcall;

function ActiveDefence(ps:pgame_PlayerState):boolean;

implementation
uses Servers, LogMgr, ConfigCache, dynamic_caster, basedefs, Chat, Games;

const
  ANTIHACKER_GROUP:string='[ACTDEF] ';
  ATTACK_GROUP:string='[ATTACK] ';
  WARN_GROUP:string='[!] ';
  INFO_GROUP:string=' ';

function NotifyRadmins(player:pointer; pmsg:pointer; psrv:pointer):boolean; stdcall;
var
  cld:pxrClientData;
begin
  result:=true;
  cld:=dynamic_cast(player, 0, xrGame+RTTI_IClient, xrGame+RTTI_xrClientData, false);
  if (cld<>nil) and (cld.m_admin_rights__m_has_admin_rights) then begin
    SendChatMessageByFreeZone(psrv, cld.base_IClient.ID.id, PAnsiChar(pmsg));
  end;
end;

procedure BadEventsProcessor(t: FZSecurityEventType; description: string); stdcall;
begin
  if t = FZ_SEC_EVENT_ATTACK then begin
    description:=ATTACK_GROUP+description;
  end else if t = FZ_SEC_EVENT_WARN then begin
    description:=WARN_GROUP+description;
  end else begin
    description:=INFO_GROUP+description;
  end;

  FZLogMgr.Get.Write(description, FZ_LOG_IMPORTANT_INFO);

  if FZConfigCache.Get().GetDataCopy().radmins_see_sec_events then begin
      ForEachClientDo(@NotifyRadmins, nil, PAnsiChar(description), GetPureServer());
  end;
end;

function AnswerToHacker({%H-}id:cardinal):boolean;
begin
  result:=false;
end;

function ActiveDefence(ps:pgame_PlayerState):boolean;
var
  hacker:pxrClientData;
begin
  result:=false;
  hacker:=nil;
  LockServerPlayers();
  try
    hacker:=GetClientByGameID(ps.GameID);
    if (hacker<>nil) and AnswerToHacker(hacker.base_IClient.ID.id) then begin
      BadEventsProcessor(FZ_SEC_EVENT_INFO, ANTIHACKER_GROUP+GetPlayerName(ps)+' - sorry, bro, have a nice day');
      result:=true;
    end;
  finally
    UnlockServerPlayers();
  end;
end;

end.

