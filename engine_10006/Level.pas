unit Level;
{$mode delphi}
{$I _pathes.inc}

interface
uses BaseClasses, Objects, Vector, Cameras, Hud, PureClient, xrstrings, games, physics, NET_Common, Servers, BattlEye, Synchro;

type
IGame_Level = packed record //sizeof = 0x160
    base_DLL_Pure:DLL_Pure;
    base_IInputReceiver:IInputReceiver;
    base_pureRender:pureRender;
    base_pureFrame:pureFrame;
    base_IEventReceiver:IEventReceiver;
    pCurrentEntity:pCObject;
    pCurrentViewEntity:pCObject;
    Sounds_Random:xr_vector;
    Sounds_Random_dwNextTime:cardinal;
    Sounds_Random_Enabled:cardinal;
    m_pCameras:pCCameraManager;
    snd_ER:xr_vector;
    //offset: 0x54
    Objects:CObjectList;
    //offset:0xcc
    ObjectSpace:CObjectSpace;
    //offset:0x140
    bReady:cardinal;
    pLevel:pCIniFile;
    pHUD:pCCustomHUD;
    snd_Events:xr_vector;
    _unused1:cardinal;
end;
pIGame_Level=^IGame_Level;
ppIGame_Level=^pIGame_Level;

message_filter = packed record
//todo:fill;
end;
pmessage_filter=^message_filter;

DemoHeader = packed record
  m_server_options:array[0..4095] of Char;
  m_time_global:cardinal;
  m_time_server:cardinal;
  m_time_delta:integer;
  m_time_delta_user:integer;
end;

CLevelSoundManager = packed record
//todo:fill
end;
pCLevelSoundManager=^CLevelSoundManager;

CSpaceRestrictionManager = packed record
//todo:fill
end;
pCSpaceRestrictionManager = ^CSpaceRestrictionManager;

CSeniorityHierarchyHolder = packed record
//todo:fill
end;
pCSeniorityHierarchyHolder = ^CSeniorityHierarchyHolder;

CClientSpawnManager = packed record
//todo:fill
end;
pCClientSpawnManager = ^CClientSpawnManager;

CAutosaveManager = packed record
  //todo:fill
end;
pCAutosaveManager = ^CAutosaveManager ;

CEvent = packed record
//todo:fill
end;
pCEvent = ^CEvent;

type CStatGraph = packed record
//todo:fill
end;
pCStatGraph = ^CStatGraph;

secure_messaging__key_t = packed record
  m_key_length:cardinal;
  m_key:array[0..31] of integer;
end;

Feel__Touch = packed record
  base_pure_relcase:pure_relcase;
  feel_touch_disable:xr_vector;
  feel_touch:xr_vector;
  q_nearest:xr_vector;
end;

GlobalFeelTouch = packed record
  base_Feel__Touch:Feel__Touch;
end;

CZoneList = packed record
//todo:fill
end;
pCZoneList=^CZoneList;

LevelMapSyncData = packed record
  m_sended_map_name_request:byte; {boolean}
  m_map_sync_received:byte; {boolean}
  m_map_loaded:byte; {boolean}
  _unused1:byte;
  m_name:shared_str;
  m_map_version:shared_str;
  m_map_download_url:shared_str;
  m_level_geom_crc32:cardinal;
  m_wait_map_time:cardinal;
  invalid_geom_checksum:byte; {boolean}
  invalid_map_or_version:byte; {boolean}
  _unused2:word;
end;


CGameTaskManager = packed record
  //todo:fill;
end;
pCGameTaskManager = ^CGameTaskManager;


CBulletManager = packed record
  //todo:fill;
end;
pCBulletManager = ^CBulletManager;

DemoHeaderStruct = packed record
	bServerClient:byte;
	Head:array[0..30] of char;
	ServerOptions:shared_str;
end;

CLevel =  packed record
    base_IGame_Level:IGame_Level;
    base_IPureClient:IPureClient;
    //CLevel+$428C here
    m_sDemoName:string_path;
    m_bDemoPlayMode:cardinal;
    m_bDemoPlayByFrame:cardinal;  //offset $4498
    m_sDemoFileName:xr_string;
    m_lDemoOfs:cardinal;   //offset $44b8
    m_sDemoHeader:DemoHeaderStruct;
    m_aDemoData:xr_deque;
    m_bDemoStarted:cardinal;  //offset $44f4
    m_dwLastDemoFrame:cardinal;
    m_bDemoSaveMode:cardinal;
    DemoCS:xrCriticalSection;
    m_dwStoredDemoDataSize:cardinal;
    m_pStoredDemoData:pByte;
    m_pOldCrashHandler:pointer;
    m_we_used_old_crach_handler:byte; {boolean}
    _unused1:byte;
    _unused2:word;
    m_dwCurDemoFrame:cardinal;
    m_level_sound_manager:pCLevelSoundManager;
    m_space_restriction_manager:pCSpaceRestrictionManager;
    m_seniority_hierarchy_holder:pCSeniorityHierarchyHolder;
    m_client_spawn_manager:pCClientSpawnManager;
    m_autosave_manager:pCAutosaveManager;
    m_ph_commander:pCPHCommander;
    m_ph_commander_scripts:pCPHCommander;
    m_name:shared_str;

    eChangeRP:pCEvent;
    eDemoPlay:pCEvent;
    eChangeTrack:pCEvent;
    eEnvironment:pCEvent;
    eEntitySpawn:pCEvent;

    pStatGraphS:pCStatGraph;
    m_dwSPC:cardinal; //SendedPacketsCount
    m_dwSPS:cardinal; //SendedPacketsSize
    pStatGraphR:pCStatGraph;
    m_dwRPC:cardinal; //ReceivedPacketsCount
    m_dwRPS:cardinal; //ReceivedPacketsSize

    m_bNeed_CrPr:cardinal;
    m_dwNumSteps:cardinal;
    m_bIn_CrPr:byte;
    _unused3:byte;
    _unused4:word;
    pObjects4CrPr:xr_vector;
    pActors4CrPr:xr_vector;
    pCurrentControlEntity:pCObject;
    m_connect_server_err:cardinal;
    m_dwDeltaUpdate:cardinal;
    m_dwLastNetUpdateTime:cardinal;
    m_bConnectResultReceived:byte; //boolean
    m_bConnectResult:byte; //boolean;
    _unused5:word;
    m_sConnectResult:xr_string;
    m_StaticParticles:xr_vector;

    game:pgame_cl_GameState;        //offset: $45D0
    m_bGameConfigStarted:cardinal;
    game_configured:cardinal;
    game_events:pNET_Queue_Event;
    game_spawn_queue:xr_deque;
    Server:pxrServer;
    //m_feel_deny:GlobalFeelTouch; - no such class in 1.0006, added to 1.0007
    battleye_system:BattlEyeSystem; //offset: $4608
    sound_registry:array[0..11] of byte; {xr_map}
    net_start_result_total:cardinal; {BOOL}
    connected_to_server:cardinal; {BOOL}
    static_Sounds:xr_vector;
    m_caServerOptions:shared_str;
    m_caClientOptions:shared_str;
    m_map_manager:pCMapManager;       //NULL for dedicated
    m_pBulletManager:pCBulletManager;
    m_dwCL_PingDeltaSend:cardinal;
    m_dwCL_PingLastSendTime:cardinal;
    m_dwRealPing:cardinal;
end;
pCLevel=^CLevel;

var
g_ppGameLevel:ppIGame_Level;

function ObjectById(lvl:pIGame_Level; id:word):pCObject;
function GetLevel():pCLevel;

function Init():boolean; stdcall;

implementation
uses basedefs, xr_debug;

function ObjectById(lvl:pIGame_Level; id:word):pCObject;
begin
  R_ASSERT(lvl<>nil, 'Cannot get object by ID - no level present');
  result:=FindObjectInListById(@lvl.Objects, id);
end;

function GetLevel():pCLevel;
begin
  R_ASSERT(g_ppGameLevel^<>nil, 'Cannot get level - no level found');
  result:=pCLevel(g_ppGameLevel^);
end;

function Init():boolean; stdcall;
begin
  result:=false;
  if not InitSymbol(g_ppGameLevel, xrEngine, '?g_pGameLevel@@3PAVIGame_Level@@A') then exit;
  result:=true;
end;

end.
