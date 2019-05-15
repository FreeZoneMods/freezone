unit GameSpy;
{$MODE Delphi}
interface
uses misc_stuff, xrstrings;

//ќтветы сервера клиентам дл€ списка серверов
type gsBufWriter = procedure (buf:pointer; data:PChar); cdecl;

function ChangeHostname(old_hostname:pstr_value):PAnsiChar; stdcall;
function GetTranslatedMapname():PAnsiChar; stdcall;
function OnAuthSend(cl:pgsclient_t):boolean; stdcall;
function IsSameCdKeyValidated():boolean; stdcall;

procedure OnConfigReloaded();

function Init():boolean; stdcall;

implementation
uses sysutils, TranslationMgr, ConfigCache, ServerStuff, Console, strutils, LogMgr;

function IsClientAuthNotRequired:boolean; stdcall;
begin
  result:= FZConfigCache.Get.GetDataCopy.is_cdkey_checking_disabled;
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

procedure OnConfigReloaded();
begin
end;

var
  new_hostname:string;
  new_mapname:string;
function ChangeHostname(old_hostname:pstr_value):PAnsiChar; stdcall;
begin
  new_hostname:=FZConfigCache.Get.GetDataCopy.servername;
  if length(new_hostname)=0 then begin
    if old_hostname<> nil then begin
      new_hostname:=PAnsiChar(@old_hostname.value);
    end else begin
      new_hostname:='';
    end;
  end;

  //single-threaded mode
  result:=PAnsiChar(new_hostname)
end;

function GetTranslatedMapname():PAnsiChar; stdcall;
var
  name,ver,link:string;
begin
  GetMapStatus(name, ver, link);
  new_mapname:=FZTranslationMgr.Get.TranslateSingle(name);
  result:=PAnsiChar(new_mapname);
end;

function Init():boolean; stdcall;
begin
  OnConfigReloaded();
  result:=true;
end;

end.
