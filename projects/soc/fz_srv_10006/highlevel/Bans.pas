unit Bans;
{$mode delphi}
interface
uses Clients, Packets, SubnetBanList, xrstrings;
function Init():boolean; stdcall;


function IPureServer__net_Handler_SubnetBans(ip:ip_address):boolean; stdcall;
function IPureServer__net_Handler_OnBannedByGameIpFound(ip:ip_address):boolean; stdcall;
function cdkey_ban_list__ban_player_checkemptykey(cl:pxrClientData):boolean; stdcall;

implementation
uses LogMgr, sysutils, misc_stuff, PlayersConnectionLog, HackProcessor;

function IPureServer__net_Handler_SubnetBans(ip:ip_address):boolean;  stdcall;
begin
  result:=FZSubnetBanList.Get.CheckForBan(ip);
  if result then begin
    FZLogMgr.Get.Write('Banned FZ IP found! '+ip_address_to_str(ip), FZ_LOG_INFO);
  end else if not FZPlayersConnectionMgr.Get().ProcessNewConnection(ip) then begin
    BadEventsProcessor(FZ_SEC_EVENT_ATTACK, 'Suspect fake players from IP '+ip_address_to_str(ip));
    result:=true;
  end else begin
    FZLogMgr.Get.Write('New player found, IP: '+ip_address_to_str(ip), FZ_LOG_INFO);
  end;
end;

function IPureServer__net_Handler_OnBannedByGameIpFound(ip:ip_address):boolean; stdcall;
begin
  FZLogMgr.Get.Write('Warning! The IP is banned, disconnecting '+ip_address_to_str(ip)+'!', FZ_LOG_IMPORTANT_INFO);
  result:=true;
end;

//TODO:причина банов

function cdkey_ban_list__ban_player_checkemptykey(cl:pxrClientData):boolean; stdcall;
begin
  if (length(get_string_value(@cl.base_IClient.m_guid[0]))=0) then begin
    result:=false;
    exit;
  end;

  if strcomp(get_string_value(@cl.base_IClient.m_guid[0]), 'd41d8cd98f00b204e9800998ecf8427e')=0 then begin
    result:=false;
    exit;
  end;

  result:=true;
end;

////////////////////////////////////////////////////////////
function Init():boolean; stdcall;
begin
  result:=true;
end;

end.
