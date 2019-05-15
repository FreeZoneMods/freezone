unit ServerStuff;

{$mode delphi}

interface
uses NET_common, CSE, Games, Level;

type
FZServerState = record
  lock:TRTLCriticalSection;
  mapname:string;
  mapver:string;
  maplink:string;
end;


procedure GetMapStatus(var name:string; var ver:string; var link:string); stdcall;
procedure xrServer__Connect_updatemapname(gdd:pGameDescriptionData); stdcall;

function Init():boolean; stdcall;
procedure Clean(); stdcall;

implementation
uses LogMgr, sysutils, CommonHelper, Windows;

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

  //xrServer__Connect_SaveCurrentMapInfo(PAnsiChar(gametype));
end;

procedure GetMapStatus(var name:string; var ver:string; var link:string); stdcall;
begin
  EnterCriticalSection(_serverstate.lock);
  name:=_serverstate.mapname;
  ver:=_serverstate.mapver;
  link:=_serverstate.maplink;
  LeaveCriticalSection(_serverstate.lock);
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

