unit CSE;
{$mode delphi}
interface
uses xrstrings, vector, BaseClasses, MatVectors, srcCalls, xr_configs;

type

GameTypeChooser = packed record
  m_GameType:word;
end;

IPureLoadableObject = packed record
  vtable:pointer;
end;

IPureSavableObject = packed record
  vtable:pointer;
end;

IPureSerializeObject = packed record
  base_IPureLoadableObject:IPureLoadableObject;
  base_IPureSavableObject:IPureSavableObject;
end;

IPureServerObject = packed record
  base_IPureSerializeObject:IPureSerializeObject;
end;

CPureServerObject = packed record
  base_IPureServerObject:IPureServerObject;
end;

CScriptValueContainer = packed record
  vftable:pointer;
  m_values:xr_vector;
end;

ISE_Abstract = packed record
  vftable:pointer;
  m_editor_flags:cardinal;
end;

CSE_Abstract = packed record
  base_ISE_Abstract:ISE_Abstract;
  base_CPureServerObject:CPureServerObject;
  base_CScriptValueContainer:CScriptValueContainer;

  s_name_replace:PChar;
  net_Ready:cardinal;
  net_Processed:cardinal;
  m_wVersion:word;
  m_script_version:word;
  RespawnTime:word;
  ID:word;
  ID_Parent:word;
  ID_Phantom:word;
  owner:pointer; {pxrClientData}
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


function Init():boolean; stdcall;
function GametypeNameById(id:cardinal):string;

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

function GametypeNameById(id: cardinal): string;
begin
  if id = EGameIDs__eGameIDSingle then begin
    result:='single';
  end else if id = EGameIDs__eGameIDDeathmatch then begin
    result:='deathmatch';
  end else if id = EGameIDs__eGameIDTeamDeathmatch then begin
    result:='teamdeathmatch';
  end else if id = EGameIDs__eGameIDArtefactHunt then begin
    result:= 'artefacthunt';
  end else if id = EGameIDs__eGameIDCaptureTheArtefact then begin
    result:= 'capturetheartefact';
  end else if id = EGameIDs__eGameIDDominationZone then begin
    result:= 'dominationzone';
  end else if id = EGameIDs__eGameIDTeamDominationZone then begin
    result:= 'teamdominationzone';
  end else begin
    result := '';
  end;
end;

end.
