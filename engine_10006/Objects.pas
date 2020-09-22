unit Objects;
{$mode delphi}
{$I _pathes.inc}

interface
uses vector, Synchro, CDB, MatVectors, BaseClasses, spatial, Schedule, Renderable, Collidable, xrstrings;

function Init():boolean; stdcall;
type
ObjectProperties = packed record
  net_ID:word;
  bActiveCounter:byte;
  flags:byte;
end;

SavedPosition = packed record
  dwTime:cardinal;
  vPosition:FVector3;
end;

CObject = packed record //sizeof = 0x104
  base_DLL_Pure:DLL_Pure;
  base_ISpatial:ISpatial;
  base_ISheduled:ISheduled;
  base_IRenderable:IRenderable;
  base_ICollidable:ICollidable;
  //offset:0xA4
  Props:ObjectProperties;
  NameObject:shared_str;
  NameSection:shared_str;
  NameVisual:shared_str;
  Parent:pointer; {pCObject}
  PositionStack:array[0..3] of SavedPosition;
  PositionStack_cnt:cardinal;
  dwFrame_UpdateCL:cardinal;
  dwFrame_AsCrow:cardinal;
end;
pCObject=^CObject;
ppCObject=^pCObject;

CObjectList = packed record
  map_NETID:array[0..11] of Byte; {xr_map}
  destroy_queue:xr_vector;
  objects_active:xr_vector;
  objects_sleeping:xr_vector;
  crows_0:xr_vector;
  crows_1:xr_vector;
  crows:pxr_vector;
  objects_dup:ppCObject;
  objects_dup_memsz:cardinal;
  m_relcase_callbacks:xr_vector;
end;
pCObjectList = ^CObjectList;

CObjectSpace = packed record
  Lock:xrCriticalSection;
  m_static:CDB__MODEL;
  m_BoundingVolume:FBox3;
  xrc:xrXRC;
  r_temp:collide__rq_results;
  r_spatial:xr_vector;
end;

CUsableScriptObject = packed record
  vtable:pointer;
  m_sTipText:shared_str;
  m_bNonscriptUsable:byte; {boolean}
  _unused1:byte;
  _unused2:word;
end;

CScriptBinder = packed record
  vtable:pointer;
  m_object:pointer; {CScriptBinderObject*}
end;

CGameObject = packed record
  base_CObject:CObject;
  base_CUsableScriptObject:CUsableScriptObject;
  base_CScriptBinder:CScriptBinder;
  //offset:0x118
  m_spawned:byte;
  m_server_flags:cardinal;
  _unused1:byte;
  _unused2:word;
  m_ai_location:pointer; {CAI_ObjectLocation*}
  m_story_id:cardinal;
  m_anim_mov_ctrl:pointer; {animation_movement_controller*}
  m_bObjectRemoved:byte; {boolean}
  _unused3:byte;
  _unused4:word;
  //offset:0x130
  m_ini_file:pCIniFile;
  m_bCrPr_Activated:boolean;
  _unused5:byte;
  _unused6:word;
  m_dwCrPr_ActivationStep:cardinal;
  m_visual_callback:array[0..5] of pointer; {visual_callback*}
  m_visual_callback_cnt:cardinal;
  m_lua_game_object:pointer; {CScriptGameObject}
  m_script_clsid:integer;
  //offset:0x160
  m_spawn_time:cardinal;
  m_callbacks:pointer;
end;

function FindObjectInListById(list:pCObjectList; id:word):pCObject;

implementation
uses basedefs, srcCalls, xr_debug;
var
  CObjectList__net_Find:srcECXCallFunction;

function FindObjectInListById(list:pCObjectList; id:word):pCObject;
var
  fullid:integer;
begin
  R_ASSERT(list<>nil, 'Cannot find object by ID - no list');
  fullid:=id;
  result:=CObjectList__net_Find.Call([list, fullid]).VPointer;
end;

function Init():boolean; stdcall;
var
  tmp:pointer;
begin
 result:=false;
 tmp:=nil;

 if not InitSymbol(tmp, xrEngine, '?net_Find@CObjectList@@QAEPAVCObject@@I@Z') then exit;
 CObjectList__net_Find:=srcECXCallFunction.Create(tmp, [vtPointer, vtInteger], 'net_Find', 'CObjectList');

 result:=true;
end;

end.
