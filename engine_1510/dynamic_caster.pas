unit dynamic_caster;
{$MODE Delphi}
interface

function dynamic_cast(inptr:pointer; vfdelta:cardinal; srctype:cardinal; targettype:cardinal; isreference:boolean):pointer; stdcall;
function Init():boolean; stdcall;

var
  //XRGAME-based
  RTTI_CSE_Abstract:cardinal;
  RTTI_IClient:cardinal;
  RTTI_xrClientData:cardinal;

   

implementation
uses basedefs;

var
  _RTTI_function:cardinal;

function dynamic_cast(inptr:pointer; vfdelta:cardinal; srctype:cardinal; targettype:cardinal; isreference:boolean):pointer; stdcall;
asm
  pushad

  movzx eax, isreference
  push eax

  push targettype
  push srctype

  push vfdelta

  push inptr

  mov eax, xrGame
  add eax, _RTTI_function
  call eax

  mov @result, eax
  add esp, $14
  
  popad
end;


function Init():boolean; stdcall;
begin
  if xrGameDllType()=XRGAME_SV_1510 then begin
    RTTI_CSE_Abstract:= $5C33D0;
    RTTI_IClient:= $5E0A14;
    RTTI_xrClientData:= $5E0A2C;
    _RTTI_function:=$4BF2DC;
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    RTTI_CSE_Abstract:= $5DF3F0;
    RTTI_IClient:= $5FD194;
    RTTI_xrClientData:= $5FD1AC;
    _RTTI_function:=$4D563C;
  end;
  result:=true;
end;

end.
