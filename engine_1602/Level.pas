unit Level;
{$mode delphi}
{$I _pathes.inc}

interface
uses BaseClasses, Objects, vector, Cameras, HUD, PureClient, Physics, xrstrings, Servers, {games,} NET_Common, AnticheatStuff, xr_configs, traffic_optimization;

type
IGame_Level = packed record //sizeof = 0x40110
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
    //offset: 0x4c
    Objects:CObjectList;
    //offset:0x40094
    ObjectSpace:CObjectSpace;
    //offset:0x400FC
    bReady:cardinal;
    pLevel:pCIniFile;
    snd_Events:xr_vector;
end;
pIGame_Level=^IGame_Level;
ppIGame_Level=^pIGame_Level;

message_filter = packed record
//todo:fill;
end;
pmessage_filter=^message_filter;

DemoHeader = packed record
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
  m_sended_map_name_request:byte; //boolean
  m_map_sync_received:byte; //boolean
  m_map_loaded:byte; //boolean
  _unused1:byte;
  m_name:shared_str;
  m_map_version:shared_str;
  m_map_download_url:shared_str;
  m_level_geom_crc32:cardinal;
  m_wait_map_time:cardinal;
  invalid_geom_checksum:byte; //boolean
  invalid_map_or_version:byte; //boolean
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

CLevel =  packed record
    base_IGame_Level:IGame_Level;
    base_IPureClient:IPureClient;
    //offset: $48570
    m_DemoPlay:cardinal;
    m_DemoPlayStarted:cardinal;
    m_DemoPlayStoped:cardinal;
    m_DemoSave:cardinal;

    m_DemoSaveStarted:cardinal;
    m_StartGlobalTime:cardinal;
    m_current_spectator:pCObject;
    m_msg_filter:pmessage_filter;

    m_demoplay_control:pointer; //demoplay_control*
    m_demo_header:DemoHeader;
    m_demo_server_options:shared_str;
  	m_demo_info:pointer;	//demo_info*
  	m_demo_info_file_pos:cardinal;
    m_writer:pIWriter;
    m_reader:pCStreamReader;

  	m_prev_packet_pos:cardinal;
  	m_prev_packet_dtime:cardinal;
    m_starting_spawns_pos:cardinal;
  	m_starting_spawns_dtime:cardinal;

    //offset: 0x485C8
    m_level_sound_manager:pCLevelSoundManager;
    m_space_restriction_manager:pCSpaceRestrictionManager;
    m_seniority_hierarchy_holder:pCSeniorityHierarchyHolder;
    m_client_spawn_manager:pCClientSpawnManager;
    m_autosave_manager:pCAutosaveManager;

    m_ph_commander:pCPHCommander;
    m_ph_commander_scripts:pCPHCommander;
    m_ph_commander_physics_worldstep:pCPHCommander;

    //offset: 0x485E8
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

    //offset: 0x48614
    m_secret_key:secure_messaging__key_t;
    //offset: 0x48698
    m_bNeed_CrPr:cardinal;
    m_dwNumSteps:cardinal;
    m_bIn_CrPr:byte;
    _unused1:byte;
    _unused2:word;
    pObjects4CrPr:xr_vector;
    pActors4CrPr:xr_vector;
    pCurrentControlEntity:pCObject;
    //offset: 0x486C0
    m_connect_server_err:cardinal;
    m_dwDeltaUpdate:cardinal;
    m_dwLastNetUpdateTime:cardinal;
    m_client_digest:shared_str;
    m_bConnectResultReceived:byte; //boolean
    m_bConnectResult:byte; //boolean;
    _unused3:word;
    m_sConnectResult:xr_string;
    m_StaticParticles:xr_vector;
    //offset: 0x486F8
    game:pointer; //pgame_cl_GameState;
    m_bGameConfigStarted:cardinal;
    game_configured:cardinal;
    game_events:pNET_Queue_Event;
    game_spawn_queue:xr_deque;
    Server:pxrServer;
    //offset: 0x48734
    m_feel_deny:GlobalFeelTouch;
    hud_zones_list:pCZoneList;
    sound_registry:array[0..23] of byte; //xr_map
    //offset: 0x4877C;
    net_start_result_total:cardinal; //BOOL
    connected_to_server:cardinal; //BOOL
    deny_m_spawn:cardinal;//BOOL
    sended_request_connection_data:cardinal;//BOOL
    map_data:LevelMapSyncData;
    static_Sounds:xr_vector;
    //offset: 0x487B4
    m_caServerOptions:shared_str;
    m_caClientOptions:shared_str;
    m_map_manager:pCMapManager;
    m_game_task_manager:pCGameTaskManager;
    m_pBulletManager:pCBulletManager;
    m_dwCL_PingDeltaSend:cardinal;
    m_dwCL_PingLastSendTime:cardinal;
    m_dwRealPing:cardinal;
    m_file_transfer:pfile_transfer__client_site;
    //offset: 0x487D8
    m_trained_stream:compression__ppmd_trained_stream;
    m_lzo_dictionary:compression__lzo_dictionary_buffer;
end;
pCLevel=^CLevel;

var
g_ppGameLevel:ppIGame_Level;

function Init():boolean; stdcall;

function ObjectById(lvl:pIGame_Level; id:word):pCObject;
function GetLevel():pCLevel;

implementation
uses basedefs, windows, xr_debug;

function ObjectById(lvl:pIGame_Level; id:word):pCObject;
begin
  R_ASSERT(lvl<>nil, 'Cannot get object by ID - no level present');
  result:=lvl.Objects.map_NETID[id];
end;

function GetLevel():pCLevel;
begin
  R_ASSERT(g_ppGameLevel^<>nil, 'Cannot get level - no level found');
  result:=pCLevel(g_ppGameLevel^);
end;

function Init():boolean; stdcall;
begin
  g_ppGameLevel:=GetProcAddress(xrEngine, '?g_pGameLevel@@3PAVIGame_Level@@A');
  result:=(g_ppGameLevel<>nil);
end;

end.
