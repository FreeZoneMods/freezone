unit LogLL;

{$mode delphi}
{$I _pathes.inc}

interface

//Primary goal - protective functions
//Includes non-portable addresses!
procedure Log_LowLevel(str:string);
function Init():boolean; stdcall;

implementation
uses xrstrings, BaseDefs, synchro;

procedure Log_LowLevel(str:string);
var
  shstr:shared_str;
  AddOne_fun_addrs:cardinal;
  LogFile_addr:cardinal;
  logCS:pxrCriticalSection;

  ebx_str:pointer;
  esi_str:pointer;
  edx_str:pointer;
begin
  init_string(@shstr);
  assign_string(@shstr, PAnsiChar(str));
  AddOne_fun_addrs:=xrCore+$B520;
  LogFile_addr:=xrCore+$BF36C;
  logCS:=pointer(xrCore+$BF438);

  xrCriticalSection__Enter(logCS);
  asm
    pushad
    mov esi, [LogFile_addr]
    mov esi, [esi]
    lea ebx, [shstr]
    push ebx

    mov edx, [AddOne_fun_addrs]

    mov ebx_str, ebx
    mov esi_str, esi
    mov edx_str, edx

    call edx
    popad
  end;
  xrCriticalSection__Leave(logCS);

  shstr.p_.dwReference:=shstr.p_.dwReference-1;
end;

function Init():boolean; stdcall;
begin
  result:=true;
end;

end.

