unit dynamic_caster;
{$MODE Delphi}
{$I _pathes.inc}

interface

function dynamic_cast(inptr:pointer; vfdelta:cardinal; srctype:cardinal; targettype:cardinal; isreference:boolean):pointer; stdcall;
function Init():boolean; stdcall;

var
  //XRGAME-based
  RTTI_CSE_Abstract:cardinal;
  RTTI_CSE_ALifeCreatureActor:cardinal;
  RTTI_IClient:cardinal;
  RTTI_xrClientData:cardinal;
  RTTI_CWeapon:cardinal;
  RTTI_CWeaponMagazined:cardinal;
  RTTI_CWeaponKnife:cardinal;
  RTTI_CInventoryItem:cardinal;
  RTTI_CInventoryOwner:cardinal;
  RTTI_CEatableItem:cardinal;
  RTTI_CEntityAlive:cardinal;
  RTTI_CObject:cardinal;

  RTTI_game_sv_ArtefactHunt:cardinal;
  RTTI_game_sv_mp:cardinal;
  RTTI_CShootingObject:cardinal;

   

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
  if xrGameDllType()=XRGAME_SV_10006 then begin
    RTTI_CSE_Abstract:=$53f1e0;
    RTTI_CSE_ALifeCreatureActor:=$53f224;
    RTTI_IClient:= $55a7b4;
    RTTI_xrClientData:= $55a7cc;
    RTTI_CWeapon:=$556bc8;
    RTTI_CWeaponMagazined:=$5557BC;
    RTTI_CWeaponKnife:=$556d50;
    RTTI_CInventoryItem:=$538cdc;
    RTTI_CInventoryOwner:=$53835C;
    RTTI_CObject:=$536048;
    _RTTI_function:=$45094c;

    RTTI_CEatableItem:=$556404;
    RTTI_CEntityAlive:=$53951C;

    RTTI_game_sv_ArtefactHunt:=$557f28;
    RTTI_game_sv_mp:=$557F4C;

    RTTI_CShootingObject:=$54E910;
  end;
  result:=true;
end;

end.
