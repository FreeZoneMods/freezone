unit GameSpy;
{$MODE Delphi}
interface
uses misc_stuff;

//ќтветы сервера клиентам дл€ списка серверов
type gsBufWriter = procedure (buf:pointer; data:PChar); cdecl;
procedure WriteHostnameToClientRequest(old_hostname:PChar; buf:pointer; BufWriter:gsBufWriter); stdcall;
procedure WriteMapnameToClientRequest({%H-}old_name:PChar; buf:pointer; BufWriter:gsBufWriter); stdcall;
function OnAuthSend(cl:pgsclient_t):boolean; stdcall;
function IsSameCdKeyValidated():boolean; stdcall;

function ChangeNumPlayersInClientRequest(real_num:integer):integer; stdcall;
procedure OnConfigReloaded();

function Init():boolean; stdcall;


implementation
uses sysutils, TranslationMgr, ConfigCache, ServerStuff, Console, strutils, LogMgr;

function IsClientAuthNotRequired:boolean; stdcall;
begin
  result:= FZConfigCache.Get.GetDataCopy.is_cdkey_checking_disabled;
end;

var
  min_players_count:integer;

function ChangeNumPlayersInClientRequest(real_num:integer):integer; stdcall;
var
  min:integer;
begin
  min:=min_players_count;

  if min>real_num then
    result:=min
  else
    result:=real_num;
end;

procedure OnConfigReloaded();
begin
  min_players_count:=FZConfigCache.Get.GetDataCopy.min_players;
end;

procedure SetMinPlayers_info(args:PChar); stdcall;
begin
  strcopy(args, 'Set minimal count of players');
end;

procedure SetMinPlayers_exec(cmdstr:PChar); stdcall;
var
  cnt:integer;
  args:string;
  raid_pos:integer;
  str:string;
begin
  args:=trim(cmdstr);

  raid_pos:=pos('raid:', args);
  if raid_pos <> 0 then begin
    args:=trim(leftstr(args, raid_pos-1));
  end;

  cnt:=StrToIntDef(args, -1);
  if cnt >= 0 then begin
    min_players_count:=cnt;
  end else if length(args) = 0 then begin
    str:='Current minimal players count is '+inttostr(min_players_count);
    FZLogMgr.Get.Write(str, FZ_LOG_USEROUT);
  end else begin
    FZLogMgr.Get.Write('Invalid argument', FZ_LOG_ERROR);
  end;
end;

function OnAuthSend(cl:pgsclient_t):boolean; stdcall;
begin
  //правим в gcd_authenticate_user
  if IsClientAuthNotRequired then begin
    //Ќе будем отправл€ть запрос мастеру, сразу выставим статус подтвержденным
    cl.state:=GAMESPY_CLIENT_STATUS_GOTOK; //cs_gotok
    result:=true;
  end else begin
    //идем как в оригинале в send_auth_req(prod, client,challenge, response)
    result:=false;
  end;
end;

function IsSameCdKeyValidated():boolean; stdcall;
begin
  result:=FZConfigCache.Get.GetDataCopy.is_same_cdkey_validated;
end;

procedure WriteHostnameToClientRequest(old_hostname:PChar; buf:pointer; BufWriter:gsBufWriter); stdcall;
var
  new_hostname:string;
begin
  new_hostname:=FZConfigCache.Get.GetDataCopy.servername;
  if length(new_hostname)=0 then new_hostname:=old_hostname;

  BufWriter(buf, PChar(new_hostname));
end;

procedure WriteMapnameToClientRequest(old_name:PChar; buf:pointer; BufWriter:gsBufWriter); stdcall;
var
  name,ver,link:string;
  new_name:string;
begin
  GetMapStatus(name, ver, link);
  new_name:=FZTranslationMgr.Get.Translate(name);
  BufWriter(buf, PChar(new_name));
end;

function Init():boolean; stdcall;
begin
  OnConfigReloaded();
  if min_players_count <> 0 then begin
    AddConsoleCommand('fz_minplayers', @SetMinPlayers_exec, @SetMinPlayers_info);
  end;
  result:=true;
end;

end.
