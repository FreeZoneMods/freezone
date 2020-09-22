unit ServerStuff;

{$mode delphi}

interface
uses NET_common, Packets, CSE, Games, Level;

type
FZServerState = record
  lock:TRTLCriticalSection;
  mapname:string;
  mapver:string;
  maplink:string;
end;


procedure GetMapStatus(var name:string; var ver:string; var link:string); stdcall;
procedure xrServer__Connect_updatemapname(gdd:pGameDescriptionData); stdcall;
procedure xrServer__Connect_SaveCurrentMapInfo(gametype:PAnsiChar); stdcall;
procedure CLevel__net_Start_overridelevelgametype(); stdcall;

procedure SplitEventPackPackets(packet:pNET_Packet); stdcall;

function Init():boolean; stdcall;
procedure Clean(); stdcall;

implementation
uses LogMgr, sysutils, CommonHelper, Windows, xrstrings, ConfigCache, Voting, Servers;

const
  MAP_SETTINGS_FILE:string='fz_mapname.txt';

var
  _serverstate:FZServerState;

procedure xrServer__Connect_updatemapname(gdd:pGameDescriptionData); stdcall;
var
  game:pgame_sv_mp;
  gametype:string;
begin
  EnterCriticalSection(_serverstate.lock);
  _serverstate.mapname:=PChar(@gdd.map_name[0]);
  _serverstate.mapver:=PChar(@gdd.map_version[0]);
  _serverstate.maplink:=PChar(@gdd.download_url[0]);
  LeaveCriticalSection(_serverstate.lock);
  FZLogMgr.Get.Write('Mapname updated: '+_serverstate.mapname+', '+_serverstate.mapver, FZ_LOG_IMPORTANT_INFO);

  game:=GetCurrentGame();
  gametype:=GametypeNameById(game.base_game_sv_GameState.base_game_GameState.m_type);

  xrServer__Connect_SaveCurrentMapInfo(PAnsiChar(gametype));
end;

procedure GetMapStatus(var name:string; var ver:string; var link:string); stdcall;
begin
  EnterCriticalSection(_serverstate.lock);
  name:=_serverstate.mapname;
  ver:=_serverstate.mapver;
  link:=_serverstate.maplink;
  LeaveCriticalSection(_serverstate.lock);
end;

procedure xrServer__Connect_SaveCurrentMapInfo(gametype:PAnsiChar); stdcall;
var
  f:textfile;
begin
  if FZConfigCache.Get().GetDataCopy().preserve_map then begin
    EnterCriticalSection(_serverstate.lock);
    try
      FZLogMgr.Get.Write('Saving map status: '+_serverstate.mapname+' | '+_serverstate.mapver+' | '+gametype, FZ_LOG_INFO);

      assignfile(f, MAP_SETTINGS_FILE);
      rewrite(f);
      try
        writeln(f, _serverstate.mapname);
        writeln(f, _serverstate.mapver);
        writeln(f, gametype);
      finally
        closefile(f)
      end;
    except
      FZLogMgr.Get.Write('Cannot save map name!', FZ_LOG_ERROR);
    end;
    LeaveCriticalSection(_serverstate.lock);
  end;
end;

procedure CLevel__net_Start_overridelevelgametype(); stdcall;
var
  lvl:pCLevel;
  runstr, mapname, mode, mapversion, tmp:string;
  f:textfile;
  verpos, from:integer;
  is_first_start:boolean;
const
  VER_KEY:string='ver=';
begin
  lvl:=GetLevel();
  mapversion:='1.0';
  runstr:=get_string_value(@lvl.m_caServerOptions);
  if not FZCommonHelper.GetNextParam(runstr, mapname, '/') or not FZCommonHelper.GetNextParam(runstr, mode, '/') then begin
    FZLogMgr.Get.Write('Cannot parse current map parameters in command string!', FZ_LOG_ERROR);
    exit;
  end;

  verpos:=Pos(VER_KEY, runstr);
  if verpos > 0 then begin
    from:=verpos;
    mapversion:='';
    verpos:=verpos+length(VER_KEY);
    while (verpos<=length(runstr)) and (runstr[verpos] <> '/') do begin
      mapversion:=mapversion+runstr[verpos];
      verpos:=verpos+1;
    end;
    Delete(runstr, from, length(VER_KEY)+length(mapversion)+1);
  end;

  EnterCriticalSection(_serverstate.lock);
  is_first_start:=length(_serverstate.mapname) = 0;
  LeaveCriticalSection(_serverstate.lock);

  //Восстановление параметров надо выполнять только при запуске сервера! При смене карты производить это нельзя.
  if FZConfigCache.Get().GetDataCopy().preserve_map and is_first_start then begin
    FZLogMgr.Get.Write('Restoring map settings', FZ_LOG_DBG);
    try
      assignfile(f, MAP_SETTINGS_FILE);
      reset(f);
      try
        readln(f, tmp);
        if length(trim(tmp))>0 then mapname:=trim(tmp);
        readln(f, tmp);
        if length(trim(tmp))>0 then mapversion:=trim(tmp);
        readln(f, tmp);
        if length(trim(tmp))>0 then mode:=trim(tmp);
      finally
        closefile(f);
      end;
    except
      FZLogMgr.Get.Write('Cannot restore map name!', FZ_LOG_ERROR);
    end;
  end;

  if not is_first_start then begin
    Voting.OnMapChanged();
  end;

//  FZTeleportMgr.Get.OnMapUpdate(mapname, mapversion);

  FZLogMgr.Get.Write('Overriding map params to: '+mapname+' | '+mapversion+' | '+mode, FZ_LOG_INFO);
  runstr:=mapname+'/'+mode+'/ver='+mapversion+'/'+runstr;
  assign_string(@lvl.m_caServerOptions, PAnsiChar(runstr));
end;

procedure SplitEventPackPackets(packet:pNET_Packet); stdcall;
begin
  if packet.B.count > sizeof(packet.B.data) - 100 then begin
    FZLogMgr.Get().Write('Flushing part of the events pack to prevent buffer overrun', FZ_LOG_DBG);
    //Отправим пакет
    SendBroadcastPacket(@GetLevel.Server.base_IPureServer, packet);

    //Начнем запись в пакет с самого начала
    ClearPacket(packet);
    WriteToPacket(packet, @M_EVENT_PACK, sizeof(M_EVENT_PACK));
  end;
end;


function Init():boolean; stdcall;
begin
  result:=true;
  InitializeCriticalSection( _serverstate.lock );
end;

procedure Clean(); stdcall;
begin
  DeleteCriticalSection( _serverstate.lock );
end;

end.

