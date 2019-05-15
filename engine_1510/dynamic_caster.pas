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
  if xrGameDllType()=XRGAME_SV_1510 then begin
    RTTI_CSE_Abstract:= $5C33D0;
    RTTI_CSE_ALifeItemWeaponMagazined:=$5e39ec;
    RTTI_CSE_ALifeCreatureActor:=$5c45d0;

    RTTI_IClient:= $5E0A14;
    RTTI_xrClientData:= $5E0A2C;

    RTTI_game_sv_CaptureTheArtefact:=$5E0AB8;
    RTTI_game_sv_ArtefactHunt:=$5E0A6C;
    RTTI_game_sv_Deathmatch:=$5E0A48;
    RTTI_game_sv_mp:=$5DDBE8;


    RTTI_CInventoryItem:=$5B4D70;
    RTTI_CInventoryOwner:=$5B43F4;
    RTTI_CObject:=$5B2048;

    RTTI_CMPPlayersBag:=$5DF684;
    RTTI_CArtefact:=$5D6B40;
    RTTI_CWeapon:=$5DF584;
    RTTI_CWeaponKnife:=$5DE264;
    RTTI_CWeaponMagazined:=$5DE280;
    RTTI_CWeaponMagazinedWGrenade:=$5DEDE8;

    RTTI_CWeaponAmmo:=$5DF59C;
    RTTI_CShootingObject:=$5D5F90;

    _RTTI_function:=$4BF2DC;
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    RTTI_CSE_Abstract:= $5DF3F0;
    RTTI_CSE_ALifeItemWeaponMagazined:= $600b34;
    RTTI_CSE_ALifeCreatureActor:=$5e0b58;

    RTTI_IClient:= $5FD194;
    RTTI_xrClientData:= $5FD1AC;

    RTTI_game_sv_CaptureTheArtefact:=$5FD238;
    RTTI_game_sv_ArtefactHunt:=$5FD1EC;
    RTTI_game_sv_Deathmatch:=$5FD1C8;
    RTTI_game_sv_mp:=$5FA368;

    RTTI_CInventoryItem:=$5D0D70;
    RTTI_CInventoryOwner:=$5D03F4;
    RTTI_CObject:=$5CE048;

    RTTI_CMPPlayersBag:=$5FBE04;
    RTTI_CArtefact:=$5F32D8;
    RTTI_CWeapon:=$5FBD04;
    RTTI_CWeaponKnife:=$5FA9E4;
    RTTI_CWeaponMagazined:=$5FAA00;
    RTTI_CWeaponMagazinedWGrenade:=$5FB568;

    RTTI_CWeaponAmmo:=$5FBD1C;
    RTTI_CShootingObject:=$5F2728;

    _RTTI_function:=$4D563C;
  end;
  result:=true;
end;

end.
