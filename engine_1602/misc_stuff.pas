unit misc_stuff;
{$mode delphi}
{$I _pathes.inc}

interface
uses Clients, Packets;
function Init():boolean; stdcall;
function BanTimeFromMinToSec(min:cardinal):cardinal; stdcall;
procedure AssignDwordFromPtrToDwordFromPtr(src: pcardinal; dst: pcardinal); stdcall;

type _votecommands = packed record
  name:PChar;
  command:PChar;
  flag:cardinal;
end;

NewPlayerName_Exists_client_finder = packed record
  CL:pIClient;
  NewName:PChar;
end;
pNewPlayerName_Exists_client_finder=^NewPlayerName_Exists_client_finder;

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
  errmsg:PChar;
  reqstr:PChar;
  reqlen:integer;
  reauthq:gsnode_s;
end;
pgsclient_t=^gsclient_t;

const
  VOTESTATUS_YES:cardinal = 1;
  VOTESTATUS_NO:cardinal = 0;
  VOTESTATUS_NOVOTENOW:cardinal = 2;

  GAMESPY_CLIENT_STATUS_GOTOK:cardinal=1;
  GAMESPY_CLIENT_STATUS_GOTNOK:cardinal=2;

implementation
uses sysutils;

function BanTimeFromMinToSec(min:cardinal):cardinal; stdcall;
begin
  if min<=35791394 then result:=min*60 else result:=$7FFFFFFF;
end;

procedure AssignDwordFromPtrToDwordFromPtr(src: pcardinal; dst: pcardinal); stdcall;
begin
  dst^:=src^;
end;

function Init():boolean; stdcall;
begin
  result:=true;
end;

end.
