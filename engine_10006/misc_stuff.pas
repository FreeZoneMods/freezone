unit misc_stuff;
{$mode delphi}
{$I _pathes.inc}

interface
function Init():boolean; stdcall;
function BanTimeFromMinToSec(min:cardinal):cardinal; stdcall;
procedure AssignDwordToDword(src: pcardinal; dst: pcardinal); stdcall;

type
gsnode_s = packed record
  obj:pointer;
  next:pointer;
  prev:pointer;
end;

gsclient_t = packed record
  localid:integer;
  hkey:array[0..32] of char;
  _unused1:byte;
  _unused2:word;  
  sesskey:integer;
  ip:integer;
  sttime:cardinal;
  ntries:integer;
  state:cardinal;
  instance:pointer;
  authfn:pointer;
  refreshauthfn:cardinal;
  errmsg:PAnsiChar;
  reqstr:PAnsiChar;
  reqlen:integer;
  reauthq:gsnode_s;
end;
pgsclient_t=^gsclient_t;

const
  GAMESPY_CLIENT_STATUS_GOTOK:cardinal=1;
  GAMESPY_CLIENT_STATUS_GOTNOK:cardinal=2;

implementation
uses sysutils;

function BanTimeFromMinToSec(min:cardinal):cardinal; stdcall;
begin
  if min<=35791394 then result:=min*60 else result:=$7FFFFFFF;
end;

procedure AssignDwordToDword(src: pcardinal; dst: pcardinal); stdcall;
begin
  dst^:=src^;
end;

function Init():boolean; stdcall;
begin
  result:=true;
end;

end.
