unit Bans;
{$mode delphi}
interface
uses Clients, Packets, SubnetBanList;
function Init():boolean; stdcall;


procedure xrServer__ProcessClientDigest_ProtectFromKeyChange(xrCL:pxrClientData); stdcall;
function xrServer__ProcessClientDigest_CheckAdditionalRejectingConditions(xrCL:pxrClientData):boolean; stdcall;
function IPureServer__net_Handler_SubnetBans(ip:ip_address):boolean; stdcall;
function IPureServer__net_Handler_OnBannedByGameIpFound():boolean; stdcall;
function cdkey_ban_list__ban_player_checkemptykey(cl:pxrClientData):boolean; stdcall;

implementation
uses basedefs, global_functions, LogMgr, sysutils, xrstrings, misc_stuff, Console, ConfigCache, Servers, PureServer, dynamic_caster, Keys,TranslationMgr, Level;

function CheckForSameKey(player:pointer; pboolworking:pointer; xrcldata:pointer):boolean; stdcall;
var
  cl:pxrClientData;
  checkfor:pxrClientData;
  reason, newkey:string;
begin
  result:=true;
  if not pboolean(pboolworking)^ then exit; //уже нашли, продолжать смысла нет 

  cl:=dynamic_cast(player, 0, xrGame+RTTI_IClient, xrGame+RTTI_xrClientData, false);
  checkfor:=pxrClientData(xrcldata);
  if (cl=nil) or (checkfor=nil) or (cl=checkfor) then exit;
  if (checkfor.m_cdkey_digest.p_=nil) or (cl.m_cdkey_digest.p_=nil) then exit;

  //if (pIClient(player).flags and ICLIENT_FLAG_LOCAL)>0 then exit; //или оставить серверного??

  if strcomp(PChar(@checkfor.m_cdkey_digest.p_.value), PChar(@cl.m_cdkey_digest.p_.value))=0 then begin
    //—овпадение? Ќе думаю... ;)
    result:=false;
    pboolean(pboolworking)^:=true;

    newkey:= GenerateRandomKey(true);
    FZLogMgr.Get.Write('Same key found! Suggest '+newkey, FZ_LOG_IMPORTANT_INFO);
    reason:=FZTranslationMgr.Get.TranslateSingle('fz_same_key_exist_use_this')+' '+newkey;
    xrServer__SendConnectResult(pCLevel(g_ppGameLevel^).Server, @checkfor.base_IClient, 0, 3,  PChar(reason));
  end;
end;

procedure xrServer__ProcessClientDigest_ProtectFromKeyChange(xrCL:pxrClientData); stdcall;
var
  gs_hash:PChar;
begin
  //вместо P->r_stringZ	(xrCL->m_cdkey_digest) делаем xrGS_gcd_getkeyhash(ID)
  gs_hash:=xrGS_gcd_getkeyhash.Call([xrCL.base_IClient.ID.id]).VPChar;
  assign_string(@xrCL.m_cdkey_digest, gs_hash);
end;

function xrServer__ProcessClientDigest_CheckAdditionalRejectingConditions(xrCL:pxrClientData):boolean; stdcall;
begin
  result:=true;
  //теперь проверим, нет ли такого игрока уже на сервере
  if FZConfigCache.Get.GetDataCopy.no_same_cdkeys then begin
    ForEachClientDo(CheckForSameKey, nil, @result, xrCL);
  end;
end;

function IPureServer__net_Handler_SubnetBans(ip:ip_address):boolean;  stdcall;
begin
  result:=FZSubnetBanList.Get.CheckForBan(ip);
  if result then begin
    FZLogMgr.Get.Write('Banned FZ IP found! '+IpToStr(ip), FZ_LOG_IMPORTANT_INFO);
  end else begin
    FZLogMgr.Get.Write('New player found, IP: '+IpToStr(ip), FZ_LOG_IMPORTANT_INFO);
  end;
end;

function IPureServer__net_Handler_OnBannedByGameIpFound():boolean; stdcall;
begin
  FZLogMgr.Get.Write('Warning! The IP is banned, disconnecting!', FZ_LOG_IMPORTANT_INFO);
end;

//TODO:причина банов

//команда на перезагрузку банлиста////////////////////////////
procedure RescanFZSubnetBanList(c:PChar); stdcall;
begin
  FZSubnetBanList.Get.ReloadDefaultFile();
end;

procedure RescanFZSubnetBanList_CmdInfo(info:PChar); stdcall;
begin
  strcopy(info, 'Reload FreeZone Subnets Banlist');
end;

////////////////////////////////////////////////////////////
function Init():boolean; stdcall;
const
  rescanbanlist_name:PChar = 'fz_rescan_banned_subnets';
begin
  AddConsoleCommand(rescanbanlist_name,RescanFZSubnetBanList,RescanFZSubnetBanList_CmdInfo);
  result:=true;
end;

function cdkey_ban_list__ban_player_checkemptykey(cl:pxrClientData):boolean; stdcall;
begin
  if (cl.m_cdkey_digest.p_ = nil) then begin
    result:=false;
    exit;
  end;

  if (length(PChar(@cl.m_cdkey_digest.p_.value))=0) then begin
    result:=false;
    exit;
  end;

  if strcomp(@cl.m_cdkey_digest.p_.value, 'd41d8cd98f00b204e9800998ecf8427e')=0 then begin
    result:=false;
    exit;
  end;

  result:=true;
end;

end.
