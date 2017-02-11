unit GameSpy;
{$MODE Delphi}
interface
uses misc_stuff;

//ќтветы сервера клиентам дл€ списка серверов
type gsBufWriter = procedure (buf:pointer; data:PChar); cdecl;

procedure WriteHostnameToClientRequest(old_hostname:PChar; buf:pointer; BufWriter:gsBufWriter); stdcall;
procedure WriteMapnameToClientRequest(old_name:PChar; buf:pointer; BufWriter:gsBufWriter); stdcall;
function OnAuthSend(cl:pgsclient_t):boolean; stdcall;


implementation
uses LogMgr, sysutils, strings, TranslationMgr, ConfigCache, ConfigMgr, ServerStuff;

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

end.
