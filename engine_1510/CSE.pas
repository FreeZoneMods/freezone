unit CSE;
{$mode delphi}
interface
uses xrstrings, vector, BaseClasses, MatVectors, srcCalls;
function Init():boolean; stdcall;

type

GameTypeChooser = packed record
  m_GameType:word;
end;

CSE_Abstract = packed record
  vftable:pointer;
  _flags_ISE:cardinal;

  _v:xr_vector;

  _unk1:cardinal;
  _unk2:cardinal;
  _unk3:cardinal;
  s_name_replace:PChar;

  net_Ready:word;
  _unused1:word;

  net_Processed:word;
  _unused2:word;

  m_wVersion:word;
  m_script_version:word;
  RespawnTime:word;
  ID:word;
  ID_Parent:word;
  ID_Phantom:word;
  owner:pointer; {xrClientData}
  s_name:shared_str;
  m_gameType:GameTypeChooser;
  s_RP:byte;
  _unused3:byte;
  s_flags:word;
  _unused4:word;
  children:xr_vector{<u16>};
  o_Position:FVector3;
  o_Angle:FVector3;
  _unk4:single;
  m_tClassID:CLASS_ID;
  m_script_clsid:integer;
  m_ini_string:shared_str;
  m_ini_file:pCInifile;
  m_bALifeControl:boolean;
  _unk5:byte;
  m_tSpawnID:word;
  m_spawn_flags:cardinal;
  client_data:xr_vector{<u8>};
end;

pCSE_Abstract = ^CSE_Abstract;
ppCSE_Abstract = ^pCSE_Abstract;


CSE_Visual = packed record
  vftable:pointer;
  visual_name:shared_str;
  startup_animation:shared_str;
  flags:cardinal;
end;
pCSE_Visual=^CSE_Visual;

const
  EGameIDs__eGameIDNoGame:cardinal = 0;
  EGameIDs__eGameIDSingle:cardinal = 1;
  EGameIDs__eGameIDDeathmatch:cardinal = 2;
  EGameIDs__eGameIDTeamDeathmatch:cardinal = 4;
  EGameIDs__eGameIDArtefactHunt:cardinal = 8;
  EGameIDs__eGameIDCaptureTheArtefact:cardinal = 16;
  EGameIDs__eGameIDDominationZone:cardinal = 32;
  EGameIDs__eGameIDTeamDominationZone:cardinal = 64;


  CSE_Abstract__visual_index:cardinal=$28;


var
  CSE_Visual__set_visual:srcESICallFunctionWEAXArg;
  CSE_Abstract__visual:srcVirtualBaseFunction;

implementation
uses BaseDefs;

function Init():boolean; stdcall;
begin
 if xrGameDllType()=XRGAME_SV_1510 then begin
   CSE_Visual__set_visual:=srcESICallFunctionWEAXArg.Create(pointer(xrGame+$322F60), [vtPointer, vtPChar], 'set_visual', 'CSE_Visual');
 end else if xrGameDllType()=XRGAME_CL_1510 then begin
   CSE_Visual__set_visual:=srcESICallFunctionWEAXArg.Create(pointer(xrGame+$339110), [vtPointer, vtPChar], 'set_visual', 'CSE_Visual');
 end;
 CSE_Abstract__visual:=srcVirtualBaseFunction.Create(CSE_Abstract__visual_index, [vtPointer], 'visual', 'CSE_Abstract');

 result:=true;
end;

end.
