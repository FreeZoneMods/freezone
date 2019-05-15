unit dynamic_caster;
{$MODE Delphi}
{$I _pathes.inc}

interface

function dynamic_cast(inptr:pointer; vfdelta:cardinal; srctype:cardinal; targettype:cardinal; isreference:boolean):pointer; stdcall;
function Init():boolean; stdcall;

var
  //XRGAME-based
  RTTI_CSE_Abstract:cardinal;
  RTTI_CSE_ALifeItemWeaponMagazined:cardinal;
  RTTI_CSE_ALifeCreatureActor:cardinal;
  RTTI_IClient:cardinal;
  RTTI_xrClientData:cardinal;
  RTTI_game_sv_CaptureTheArtefact:cardinal;
  RTTI_game_sv_Deathmatch:cardinal;
  RTTI_game_sv_ArtefactHunt:cardinal;
  RTTI_game_sv_mp:cardinal;

  RTTI_CObject:cardinal;

  RTTI_CInventoryItem:cardinal;
  RTTI_CInventoryOwner:cardinal;

  RTTI_CMPPlayersBag:cardinal;

  RTTI_CArtefact:cardinal;
  RTTI_CWeapon:cardinal;
  RTTI_CWeaponMagazined:cardinal;
  RTTI_CWeaponMagazinedWGrenade:cardinal;
  RTTI_CWeaponKnife:cardinal;
  RTTI_CWeaponAmmo:cardinal;
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
  if xrGameDllType()=XRGAME_1602 then begin
    RTTI_CSE_Abstract:= $619c00;
    RTTI_CSE_ALifeItemWeaponMagazined:=$63e088;
    RTTI_CSE_ALifeCreatureActor:=$61b270;

    RTTI_IClient:= $638c5c;
    RTTI_xrClientData:= $638c74;

    RTTI_game_sv_CaptureTheArtefact:=$638d00;
    RTTI_game_sv_ArtefactHunt:=$638cb4;
    RTTI_game_sv_Deathmatch:=$638c90;
    RTTI_game_sv_mp:=$6345b0;


    RTTI_CInventoryItem:=$61842c;
    RTTI_CInventoryOwner:=$618484;
    RTTI_CObject:=$616020;

    RTTI_CMPPlayersBag:=$637408;
    RTTI_CArtefact:=$62d14c;
    RTTI_CWeapon:=$637268;
    RTTI_CWeaponKnife:=$635ef0;
    RTTI_CWeaponMagazined:=$635f0c;
    RTTI_CWeaponMagazinedWGrenade:=$636a7c;

    RTTI_CWeaponAmmo:=$6372d0;
    RTTI_CShootingObject:=$62c4e8;

    _RTTI_function:=$509d9a;
  end;
  result:=true;
end;

end.
