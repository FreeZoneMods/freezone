unit Bans;
{$mode delphi}
interface
uses Clients, Packets, SubnetBanList, xrstrings;
function Init():boolean; stdcall;


procedure xrServer__ProcessClientDigest_ProtectFromKeyChange(xrCL:pxrClientData; secondary:pshared_str; p:pNET_Packet); stdcall;
function xrServer__ProcessClientDigest_CheckAdditionalRejectingConditions(xrCL:pxrClientData):boolean; stdcall;
function IPureServer__net_Handler_SubnetBans(ip:ip_address):boolean; stdcall;
function IPureServer__net_Handler_OnBannedByGameIpFound(ip:ip_address):boolean; stdcall;
function cdkey_ban_list__ban_player_checkemptykey(cl:pxrClientData):boolean; stdcall;

implementation
uses basedefs, global_functions, LogMgr, sysutils, misc_stuff, ConfigCache, Servers, dynamic_caster, Keys,TranslationMgr, Level, sysmsgs, Players, PlayersConnectionLog, HackProcessor;

procedure xrServer__ProcessClientDigest_ProtectFromKeyChange(xrCL:pxrClientData; secondary:pshared_str; p:pNET_Packet); stdcall;
var
  gs_hash:PAnsiChar;
  hash2:shared_str;
  hwid:string;
  old_hwid:string;
begin
  init_string(@hash2);
  //Считаем (основной) хеш от верхнего регистра
  NET_Packet__r_stringZ.Call([p, @hash2]);

  //Теперь посмотрим - один из хешей может в реальности быть hwid
  //hwid всегда заносим в secondary
  if ValidateHwId(get_string_value(@hash2), nil)<>FZ_HWID_NOT_HWID then begin
    hwid := get_string_value(@hash2);
    assign_string(secondary, PAnsiChar(hwid));
  end else if ValidateHwId(get_string_value(@xrCL.m_cdkey_digest), nil)<>FZ_HWID_NOT_HWID then begin
    hwid := get_string_value(@xrCL.m_cdkey_digest);
    assign_string(@xrCL.m_cdkey_digest, get_string_value(@hash2));
    assign_string(secondary, PAnsiChar(hwid));
  end else begin
    //Ни один из хешей не hwid. Что ж...
    hwid:='';
    //хеш от верхнего регистра - как основной
    assign_string(secondary, get_string_value(@xrCL.m_cdkey_digest));
    //хеш от нижнего регистра - как дополнительный
    assign_string(@xrCL.m_cdkey_digest, get_string_value(@hash2));
  end;

  old_hwid:=GetHwId(xrCL);
  if (length(old_hwid)>0) and (old_hwid<>hwid) then begin
    //Зашел другой клиент с тем же ip, сбросим флаг реконнекта для обнуления статы
    FZLogMgr.Get.Write(GenerateMessageForClientId(xrCL.base_IClient.ID.id, 'has different HWID, reset reconnect flag'), FZ_LOG_INFO);
    xrCL.base_IClient.flags:= xrCL.base_IClient.flags and (not ICLIENT_FLAG_RECONNECT);
  end;

  SetHwId(xrCL, hwid);

  //Если есть геймспаевский хеш - основной заменяем им
  gs_hash:=xrGS_gcd_getkeyhash.Call([xrCL.base_IClient.ID.id]).VPChar;
  if (gs_hash<>nil) and (gs_hash[0]<>CHR(0)) then begin
    assign_string(@xrCL.m_cdkey_digest, gs_hash);
  end;
end;

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

  //if (pIClient(player).flags and ICLIENT_FLAG_LOCAL)>0 then exit; //или оставить серверного??

  if strcomp(get_string_value(@checkfor.m_cdkey_digest), get_string_value(@cl.m_cdkey_digest))=0 then begin
    //Совпадение? Не думаю... ;)
    result:=false;
    pboolean(pboolworking)^:=true;

    newkey:= GenerateRandomKey(true);
    FZLogMgr.Get.Write(GenerateMessageForClientId(checkfor.base_IClient.ID.id, 'has duplicate cd-key! Suggest '+newkey), FZ_LOG_IMPORTANT_INFO);
    reason:=FZTranslationMgr.Get.TranslateSingle('fz_same_key_exist_use_this')+' '+newkey;
    xrServer__SendConnectResult(GetLevel.Server, @checkfor.base_IClient, 0, 3,  PChar(reason));
  end;
end;

function xrServer__ProcessClientDigest_CheckAdditionalRejectingConditions(xrCL:pxrClientData):boolean; stdcall;
var
  hwidresult:FZHwIdValidationResult;
  hwid, hash, reason:string;
begin
  result:=true;
  //теперь проверим, нет ли такого игрока уже на сервере
  if FZConfigCache.Get.GetDataCopy.no_same_cdkeys then begin
    ForEachClientDo(CheckForSameKey, nil, @result, xrCL);
  end;

  if xrCL.base_IClient.flags and ICLIENT_FLAG_LOCAL = 0 then begin
    hwid:=GetHwId(xrCL);
    hash:=get_string_value(@xrCL.m_cdkey_digest);
    hwidresult:=ValidateHwId(PAnsiChar(hwid), PAnsiChar(hash));

    if hwidresult = FZ_HWID_INVALID then begin
      reason:=FZTranslationMgr.Get.TranslateSingle('fz_invalid_hwid');
      xrServer__SendConnectResult(GetLevel.Server, @xrCL.base_IClient, 0, 3,  PChar(reason));
      FZLogMgr.Get.Write(GenerateMessageForClientId(xrCL.base_IClient.ID.id,'has invalid HWID'), FZ_LOG_IMPORTANT_INFO );
    end else if hwidresult = FZ_HWID_UNKNOWN_VERSION then begin
      if FZConfigCache.Get.GetDataCopy.strict_hwid then begin
        reason:=FZTranslationMgr.Get.TranslateSingle('fz_hwid_version_not_supported');
        FZLogMgr.Get.Write(GenerateMessageForClientId(xrCL.base_IClient.ID.id, 'has unknown HWID type'), FZ_LOG_IMPORTANT_INFO );
        xrServer__SendConnectResult(GetLevel.Server, @xrCL.base_IClient, 0, 3,  PChar(reason));
      end;
    end else if hwidresult <> FZ_HWID_VALID then begin
      if FZConfigCache.Get.GetDataCopy.strict_hwid then begin
        FZLogMgr.Get.Write(GenerateMessageForClientId(xrCL.base_IClient.ID.id, 'has no HWID'), FZ_LOG_IMPORTANT_INFO );
        reason:=FZTranslationMgr.Get.TranslateSingle('fz_hwid_required');
        xrServer__SendConnectResult(GetLevel.Server, @xrCL.base_IClient, 0, 3,  PChar(reason));
      end;
    end;
  end;
end;

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
  if (length(get_string_value(@cl.m_cdkey_digest))=0) then begin
    result:=false;
    exit;
  end;

  if strcomp(get_string_value(@cl.m_cdkey_digest), 'd41d8cd98f00b204e9800998ecf8427e')=0 then begin
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
