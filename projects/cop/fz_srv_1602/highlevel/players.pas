unit Players;

{$mode delphi}

interface
uses Servers, Clients;

procedure OnAttachNewClient(srv:pxrServer; cl:pIClient); stdcall;

function GenerateMessageForClientId(id:cardinal; message: string):string;

implementation
uses Packets, xrstrings, sysutils, PureServer, sysmsgs, MapList, LogMgr, TranslationMgr, ConfigCache, Synchro, DownloadMgr, ServerStuff;

//Callback for sending SYSMSGS
type FZSysMsgSendCallbackData = record
  srv:pIPureServer;
  cl_id:ClientID;
end;
pFZSysMsgSendCallbackData = ^FZSysMsgSendCallbackData;

procedure SysMsg_SendCallback(msg:pointer; len:cardinal; userdata:pointer); stdcall;
var
  data:pFZSysMsgSendCallbackData;
begin
  data:=pFZSysMsgSendCallbackData(userdata);
  //DPNSEND_IMMEDIATELLY + DPNSEND_GUARANTEED + DPNSEND_PRIORITY_HIGH
  SendPacketToClient_LL(data.srv, data.cl_id.id, msg, len, $100+$8+$80, 0);
end;

procedure ExportMapListToClient(srv:pIPureServer; cl_id:ClientID; gameid:cardinal); stdcall;
var
  maplist:FZClientVotingMapList;
  elements:array of FZClientVotingElement;
  translations:array of string;
  helper:pCMapListHelper;
  servermaps_cur:pSGameTypeMaps;
  mapitm_cur, mapitm_end:pSGameTypeMaps_SMapItm;
  i:integer;
  userdata:FZSysMsgSendCallbackData;
begin
  maplist.gametype := gameid;

  helper:=GetMapList();

  if helper.m_storage.start = nil then begin
    LoadMapList();
  end;

  servermaps_cur:=helper.m_storage.start;
  while servermaps_cur<>helper.m_storage.last do begin
    if servermaps_cur.m_game_type_id = gameid then break;
    servermaps_cur:=pointer(servermaps_cur)+sizeof(SGameTypeMaps);
  end;
  if servermaps_cur=helper.m_storage.last then begin
    //нет такого типа игры!
    FZLogMgr.Get.Write('No gametype in maplist, id='+inttostr(gameid), FZ_LOG_ERROR);
    exit;
  end;

  //Составим список карт для экспорта
  mapitm_end:=servermaps_cur.m_map_names.last;
  mapitm_cur:=servermaps_cur.m_map_names.start;
  maplist.count:= (mapitm_end - mapitm_cur)+1;
  setlength(elements, maplist.count);
  setlength(translations, maplist.count);
  maplist.maps:=@elements[0];

  //первый элемент отвечает за очистку списка карт клиента

  elements[0].mapname:=nil;
  elements[0].mapver:=nil;

  for i:=1 to maplist.count-1 do begin
    elements[i].mapname:=get_string_value(@mapitm_cur.map_name);
    elements[i].mapver:=get_string_value(@mapitm_cur.map_ver);
    translations[i]:=FZTranslationMgr.Get().TranslateOrEmptySingle(elements[i].mapname);
    if length(translations[i])>0 then begin
      elements[i].description:=PAnsiChar(translations[i]);
    end else begin
      elements[i].description:=nil;
    end;
    mapitm_cur:=pointer(mapitm_cur)+sizeof(SGameTypeMaps_SMapItm);
  end;


  userdata.srv:=srv;
  userdata.cl_id:=cl_id;

  while(maplist.count>0) do begin
    SendSysMessage_COP(@ProcessClientVotingMaplist, @maplist, @SysMsg_SendCallback, @userdata);
    maplist.count:=maplist.count-maplist.was_sent;
    maplist.maps:=pointer(maplist.maps)+maplist.was_sent*sizeof(FZClientVotingElement);
  end;

  setlength(elements, 0);
  setlength(translations, 0);
end;

//Here we call constructing downloader SYSMSGS
procedure OnAttachNewClient(srv:pxrServer; cl:pIClient); stdcall;
var
  dat:FZCacheData;
  dlinfo:FZMapInfo;
  moddllinfo:FZDllDownloadInfo;
  mapname, mapver, maplink, link, xml:string;
  dl_msg, err_msg, incompatible_mod_msg:string;
  filename:string;
  need_dl:boolean;
  userdata:FZSysMsgSendCallbackData;
  flags:FZSysmsgsCommonFlags;
begin
  xrCriticalSection__Enter(@srv.base_IPureServer.net_players.csPlayers);
  try
    userdata.srv:=@srv.base_IPureServer;
    userdata.cl_id:=cl.ID;

    if IsLocalServerClient(cl) or not CheckForClientExist(srv, cl) then exit;
    dat:=FZConfigCache.Get.GetDataCopy();

    if length(dat.mod_name)>0 then begin
      filename:=dat.mod_name+'.mod';
      dl_msg:=FZTranslationMgr.Get().TranslateOrEmptySingle('fz_mod_downloading');
      err_msg:=FZTranslationMgr.Get().TranslateOrEmptySingle('fz_already_has_download');
      incompatible_mod_msg:=FZTranslationMgr.Get().TranslateOrEmptySingle('fz_incompatible_mod');

      moddllinfo.fileinfo.filename:=PAnsiChar(filename);
      moddllinfo.fileinfo.url:=PAnsiChar(dat.mod_link);
      moddllinfo.fileinfo.crc32:=dat.mod_crc32;
      moddllinfo.fileinfo.progress_msg:=PAnsiChar(dl_msg);
      moddllinfo.fileinfo.error_already_has_dl_msg:=PAnsiChar(err_msg);
      moddllinfo.fileinfo.compression:=FZDownloadMgr.GetCompressionTypeByIndex(dat.mod_compression_type);
      moddllinfo.procname:='ModLoad';
      moddllinfo.procarg1:=PAnsiChar(dat.mod_name);
      moddllinfo.procarg2:=PAnsiChar(dat.mod_params);
      moddllinfo.dsign:=PAnsiChar(dat.mod_dsign);
      moddllinfo.name_lock:=PAnsiChar(dat.mod_name);
      moddllinfo.incompatible_mod_message:=PAnsiChar(incompatible_mod_msg);
      moddllinfo.mod_is_applying_message:=PAnsiChar(dl_msg);

      if dat.mod_is_reconnect_needed then begin
        moddllinfo.modding_policy:=FZ_MODDING_WHEN_CONNECTING;
      end else begin
        moddllinfo.modding_policy:=FZ_MODDING_WHEN_NOT_CONNECTING;
      end;
      moddllinfo.reconnect_addr.ip:=PAnsiChar(dat.reconnect_ip);
      moddllinfo.reconnect_addr.port:=dat.reconnect_port;

      if (length(dat.mod_link) = 0) or (length(dat.mod_dsign) > 0) then begin
        if (length(dat.mod_link) = 0) then begin
          FZLogMgr.Get.Write('Send MODLOAD packet for '+dat.mod_name+' (default loader)', FZ_LOG_INFO);
        end else begin
          FZLogMgr.Get.Write('Send MODLOAD packet for '+dat.mod_name, FZ_LOG_INFO);
        end;
        SendSysMessage_COP(@ProcessClientModDll, @moddllinfo, @SysMsg_SendCallback ,@userdata);
      end else begin
        FZLogMgr.Get.Write('MOD_DSIGN parameter not specified!'+dat.mod_name, FZ_LOG_ERROR);
      end;
    end;

    GetMapStatus(mapname, mapver, maplink);
    if (length(mapname)=0) or (length(mapver)=0) then exit;

    if (dat.enable_map_downloader) then begin
      link:=FZDownloadMgr.Get.GetLinkByMapName(mapname, mapver);
      if length(link)>0 then begin
        dlinfo.fileinfo.url:=PAnsiChar(link);
      end else begin
        dlinfo.fileinfo.url:=PAnsiChar(maplink);
      end;
      filename:=FZDownloadMgr.Get.GetMapPrefix(mapname, mapver)+mapname+'_'+mapver+'.map';
      dl_msg:=FZTranslationMgr.Get().TranslateOrEmptySingle('fz_map_downloading');
      err_msg:=FZTranslationMgr.Get().TranslateOrEmptySingle('fz_already_has_download');
      xml:=FZDownloadMgr.Get.GetXMLName(mapname, mapver);

      dlinfo.fileinfo.filename:=PAnsiChar(filename);
      dlinfo.fileinfo.progress_msg:=PAnsiChar(dl_msg);
      dlinfo.fileinfo.error_already_has_dl_msg:=PAnsiChar(err_msg);
      need_dl:=true;
      dlinfo.fileinfo.crc32:=FZDownloadMgr.Get.GetCRC32(mapname, mapver, need_dl);
      dlinfo.fileinfo.compression:=FZDownloadMgr.Get.GetCompressionType(mapname, mapver);

      dlinfo.reconnect_addr.ip:=PAnsiChar(dat.reconnect_ip);
      dlinfo.reconnect_addr.port:=dat.reconnect_port;
      dlinfo.mapver:=PAnsiChar(mapver);
      dlinfo.mapname:=PAnsiChar(mapname);
      dlinfo.xmlname:=PAnsiChar(xml);
      dlinfo.flags := 0;

      if dat.mod_prefer_parent_appdata_for_maps or FZDownloadMgr.Get().IsPreferParentAppdataDl(mapname, mapver) then begin
        dlinfo.flags:=dlinfo.flags or FZ_MAPLOAD_PREFER_PARENT_APPDATA_STORE;
      end;

      flags:=GetCommonSysmsgsFlags();
      if FZDownloadMgr.Get.IsPatchAndReconnectAfterMapload(mapname, mapver) then begin
        if flags and FZ_SYSMSGS_PATCHES_WITH_MAPCHANGE <> FZ_SYSMSGS_PATCHES_WITH_MAPCHANGE then begin
          flags:=flags or FZ_SYSMSGS_PATCHES_WITH_MAPCHANGE;
          SetCommonSysmsgsFlags(flags);
        end;
        dlinfo.flags:=dlinfo.flags or FZ_MAPLOAD_MANDATORY_RECONNECT;
      end else begin
        if flags and FZ_SYSMSGS_PATCHES_WITH_MAPCHANGE <> 0 then begin
          flags:=flags and (FZ_SYSMSGS_FLAGS_ALL_ENABLED - FZ_SYSMSGS_PATCHES_WITH_MAPCHANGE);
          SetCommonSysmsgsFlags(flags);
        end;
      end;

      if not need_dl then begin
        //Контрольная сумма не найдена, просто сообщаем
        FZLogMgr.Get.Write('No CRC32 for map '+mapname+', ver '+mapver, FZ_LOG_INFO);
      end else begin
        FZLogMgr.Get.Write('Send DOWNLOAD packet for '+mapname+', ver.='+mapver, FZ_LOG_INFO);
        SendSysMessage_COP(@ProcessClientMap, @dlinfo, @SysMsg_SendCallback ,@userdata);
      end;
    end;

    // TODO: отправлять при загрузке клиента, а не при коннекте (минимизация лагов)
    if dat.enable_maplist_sync then begin
      ExportMapListToClient(@srv.base_IPureServer, cl.ID, srv.game.base_game_GameState.m_type);
    end;

  finally
    xrCriticalSection__Leave(@srv.base_IPureServer.net_players.csPlayers);
  end;
end;

function GetNameAndIpByClientId(id:cardinal; var ip:string):string;
var
  cld:pxrClientData;
begin
  ip:='0.0.0.0';
  result:='(null)';

  cld:=ID_to_client(id);
  if (cld=nil) then exit;

  ip:=ip_address_to_str(cld.base_IClient.m_cAddress);

  if (cld.ps <> nil) then begin
    result:=get_string_value(@cld.ps.m_account.m_player_name);
  end;

  if length(result) = 0 then begin
    result:=get_string_value(@cld.base_IClient.name);
  end;
end;

function GenerateMessageForClientId(id:cardinal; message: string):string;
var
  name, ip:string;
begin
  ip:='';
  name:=GetNameAndIpByClientId(id, ip);
  result:='Player "'+name+'" (ID='+inttostr(id)+', IP='+ip+') '+message;
end;

end.

