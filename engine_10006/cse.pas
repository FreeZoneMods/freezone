unit CSE;

{$mode delphi}
{$I _pathes.inc}

interface
uses Vector, MatVectors, BaseClasses, xrstrings, Bones, Physics;

type
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

CSE_Abstract = packed record //sizeof = 0xa0
  base_ISE_Abstract:ISE_Abstract;
  base_CPureServerObject:CPureServerObject;
  base_CScriptValueContainer:CScriptValueContainer;
  s_name_replace:PAnsiChar;
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
  s_gameid:byte;
  s_RP:byte;
  s_flags:word;
  children:xr_vector; {<u16>}
  o_Position:FVector3;
  o_Angle:FVector3;
  m_tClassID:int64;
  m_script_clsid:integer;
  m_ini_string:shared_str;
  m_ini_file:pCIniFile;
  m_bALifeControl:byte;
  _unused1:byte;
  m_tSpawnID:word;
  m_spawn_flags:cardinal;
  client_data:xr_vector; {<u8>}
  unused1:cardinal;
end;
pCSE_Abstract = ^CSE_Abstract;
ppCSE_Abstract = ^pCSE_Abstract;

CSE_ALifeObject = packed record //sizeof = 0xC8
  base_CSE_Abstract:CSE_Abstract;
  base_CRandom:CRandom;
  m_tGraphID:word;
  unused1:word;
  m_fDistance:single;
  m_bOnline:byte; {boolean}
  m_bDirectControl:byte; {boolean}
  unused2:word;
  m_tNodeID:cardinal;
  m_flags:cardinal;
  m_story_id:cardinal;
  m_spawn_story_id:cardinal;
  m_alife_simulator:pointer; {CALifeSimulator*}
  unused3:cardinal;
end;

CSE_ALifeDynamicObject = packed record //sizeof = 0xD8
  base_CSE_ALifeObject:CSE_ALifeObject;
  m_tTimeID:qword;
  m_switch_counter:qword;
end;

CSE_Visual = packed record  //sizeof = 0x10
  vtable:pointer;
  visual_name:shared_str;
  startup_animation:shared_str;
  flags:byte;
  unused1:byte;
  unused2:word;
end;

CSE_ALifeDynamicObjectVisual = packed record //sizeof = 0xE8
  base_CSE_ALifeDynamicObject:CSE_ALifeDynamicObject;
  base_CSE_Visual:CSE_Visual;
end;

CSE_ALifeCreatureAbstract = packed record  //sizeof = 0x150
  base_CSE_ALifeDynamicObjectVisual:CSE_ALifeDynamicObjectVisual;
  s_team:byte;
  s_squad:byte;
  s_group:byte;
  unused1:byte;
  fHealth:single;
  m_fMorale:single;
  m_fAccuracy:single;
  m_fIntelligence:single;
  timestamp:cardinal;
  flags:byte;
  unused2:byte;
  unused3:word;
  o_model:single;
  o_torso:SRotation;
  m_bDeathIsProcessed:byte; {boolean}
  unused4:byte;
  unused5:word;
  m_dynamic_out_restrictions:xr_vector; {ALife::_OBJECT_ID}
  m_dynamic_in_restrictions:xr_vector; {ALife::_OBJECT_ID}
  m_ef_creature_type:cardinal;
  m_ef_weapon_type:cardinal;
  m_ef_detector_type:cardinal;
  m_killer_id:word; //ALife::_OBJECT_ID
  unused6:word;
  m_game_death_time:qword;
end;

CSE_ALifeTraderAbstract = packed record  //sizeof = 0x60
  vtable:cardinal;
  m_dwMoney:cardinal;
  m_fMaxItemMass:single;
  m_trader_flags:cardinal;
  m_community_index:integer;
  m_reputation:integer;
  m_rank:integer;
  m_character_name:xr_string;
  m_sCharacterProfile:shared_str;
  m_SpecificCharacter:shared_str;
  m_CheckedCharacters:xr_vector; {shared_str}
  m_DefaultCharacters:xr_vector; {shared_str}
end;

CSE_PHSkeleton = packed record //sizeof = 0x50
  vtable:cardinal;
  unused1:cardinal;
  _flags:byte;
  unused2:byte;
  unused3:word;
  unused4:cardinal;
  saved_bones:SPHBonesData;
  source_id:word;
  unused5:word;
  unused6:cardinal;
end;

CSE_ALifeCreatureActor = packed record  //sizeof = 0x698
  base_CSE_ALifeCreatureAbstract:CSE_ALifeCreatureAbstract;
  base_CSE_ALifeTraderAbstract:CSE_ALifeTraderAbstract;
  base_CSE_PHSkeleton:CSE_PHSkeleton;
  //offset: 0x200;
  mstate:word;
  accel:FVector3;
  velocity:FVector3;
  unused1:word;
  fRadiation:single;
  weapon:byte;
  unused2:byte;
  m_u16NumItems:word;
  m_holderID:word;
  unused3:word;
  m_AliveState:SPHNetState;
  m_BoneDataSize:byte;
  unused4:byte;
  unused5:word;
  m_DeadBodyData:array[0..1023] of char;
end;

function Init():boolean; stdcall;
implementation

function Init():boolean; stdcall;
begin
  result:=true;
end;

end.

