unit abstractions;

{$mode delphi}

interface

type
  FZ_GAME_VERSION = (FZ_VER_UNKNOWN, FZ_VER_SOC_10006, FZ_VER_SOC_10006_V2, FZ_VER_CS_1510, FZ_VER_COP_1602);

  FZAbstractGameVersion = class
  public
    function GetCoreParams(): PAnsiChar; virtual; abstract;
    function GetCoreApplicationPath(): PAnsiChar; virtual; abstract;
    procedure ShowMpMainMenu(); virtual; abstract;
    procedure AssignStatus(str:PAnsiChar); virtual; abstract;
    function CheckForUserCancelDownload():boolean; virtual; abstract;
    function CheckForLevelExist():boolean; virtual; abstract;
    function UpdatePath(root:string; appendix:string):string; virtual; abstract;
    function PathExists(root:string):boolean; virtual; abstract;
    function StartVisualDownload():boolean; virtual; abstract;
    function StopVisualDownload():boolean; virtual; abstract;  //main_menu.m_sPDProgress.IsInProgress:=0;
    procedure SetVisualProgress(progress:single); virtual; abstract;
    procedure ExecuteConsoleCommand(cmd:PAnsiChar); virtual; abstract;
    function GetEngineExeFileName():PAnsiChar; virtual; abstract;
    function GetEngineExeModuleAddress():uintptr; virtual; abstract;
    function ThreadSpawn(proc:uintptr; args:uintptr; name:PAnsiChar = nil; stack:cardinal = 0):boolean; virtual; abstract;
    procedure AbortConnection(); virtual; abstract;
    procedure Log(txt:PAnsiChar); virtual; abstract;
    function GetPlayerName():string; virtual; abstract;
    function IsServerListUpdateActive():boolean; virtual; abstract;
    function IsMessageActive():boolean; virtual; abstract;
    procedure TriggerMessage(); virtual; abstract;
    procedure PrepareForMessageShowing(); virtual; abstract;
    procedure ResetMasterServerError(); virtual; abstract;
  end;

  { FZTestGameVersion }

  FZTestGameVersion = class(FZAbstractGameVersion)
  public
    function ThreadSpawn(proc:uintptr; args:uintptr; {%H-}name:PAnsiChar = nil; {%H-}stack:cardinal = 0):boolean; override;
    procedure Log(txt:PAnsiChar); override;
    function GetPlayerName():string; override;
    function IsServerListUpdateActive():boolean; override;
  end;

  { FZBaseGameVersion }

  string_path=array [0..519] of Char;
  xrCoreData = packed record
    ApplicationName:array[0..63] of char;
    ApplicationPath:string_path;
    WorkingPath:string_path;
    UserName:array[0..63] of char;
    CompName:array[0..63] of char;
    Params:array[0..511] of char;
  end;
  pxrCoreData = ^xrCoreData;

  FZBaseGameVersion = class(FZAbstractGameVersion)
  protected
    _exe_module_name:string;
    _xrGame_module_name:string;
    _xrCore_module_name:string;

    _exe_module_address:uintptr;
    _xrGame_module_address:uintptr;
    _xrCore_module_address:uintptr;

    _g_ppGameLevel:puintptr;
    _g_ppConsole:puintptr;
    _xr_FS:puintptr;
    _core:pxrCoreData;

    CConsole__Execute:pointer;
    CLocatorApi__update_path:pointer;
    CLocatorApi__path_exists:pointer;
    Log_fun:procedure(text:PAnsiChar); cdecl;
    CConsole__GetString:pointer;

    _log_file_name:string;

    function FunFromVTable(obj:uintptr; index:cardinal):uintptr; stdcall;
    function DoEcxCall_noarg(fun:uintptr; obj:uintptr):uintptr; stdcall;
    function DoEcxCall_1arg(fun:uintptr; obj:uintptr; arg:uintptr):uintptr; stdcall;
    function DoEcxCall_2arg(fun:uintptr; obj:uintptr; arg1:uintptr; arg2:uintptr):uintptr; stdcall;
    function DoEcxCall_3arg(fun:uintptr; obj:uintptr; arg1:uintptr; arg2:uintptr; arg3:uintptr):uintptr; stdcall;

    function GetLevel():uintptr;
  public
    constructor Create();
    destructor Destroy(); override;
    function GetCoreParams(): PAnsiChar; override;
    function GetCoreApplicationPath(): PAnsiChar; override;
    procedure ExecuteConsoleCommand(cmd:PAnsiChar); override;
    function GetEngineExeFileName():PAnsiChar; override;
    function GetEngineExeModuleAddress():uintptr; override;
    function UpdatePath(root:string; appendix:string):string; override;
    function PathExists(root:string):boolean; override;
    function CheckForLevelExist():boolean; override;
    procedure Log(txt:PAnsiChar); override;
    function GetPlayerName():string; override;
  end;

  { FZUnknownGameVersion }

  FZUnknownGameVersion = class(FZBaseGameVersion)
  public
    procedure ShowMpMainMenu(); override;
    procedure AssignStatus(str:PAnsiChar); override;
    function CheckForUserCancelDownload():boolean; override;
    function StartVisualDownload():boolean; override;
    function StopVisualDownload():boolean; override;
    procedure SetVisualProgress({%H-}progress:single); override;
    function ThreadSpawn(proc:uintptr; args:uintptr; {%H-}name:PAnsiChar = nil; {%H-}stack:cardinal = 0):boolean; override;
    procedure AbortConnection(); override;
    function IsServerListUpdateActive():boolean; override;
    function IsMessageActive():boolean; override;
    procedure TriggerMessage(); override;
    procedure PrepareForMessageShowing(); override;
    procedure ResetMasterServerError(); override;
  end;

  { FZCommonGameVersion }

  FZCommonGameVersion = class(FZBaseGameVersion)
  protected
    _g_ppGamePersistent:puintptr;
    _g_ppStringContainer:puintptr;
    _pDevice:uintptr;
    _g_pbRendering:pbyte;

    xrCriticalSection__Enter:pointer;
    xrCriticalSection__Leave:pointer;
    str_container__dock:pointer;
    thread_spawn:procedure(fun:pointer; name:PAnsiChar; stack:cardinal; args:pointer); cdecl;

    procedure SafeExec_start();
    procedure SafeExec_end();
    procedure assign_string(pshared_str:uintptr; text:PAnsiChar); stdcall;

    function GetMainMenu():uintptr;
    procedure ActivateMainMenu(state:boolean); virtual;

    function get_CMainMenu_castto_IMainMenu_offset():uintptr; virtual; abstract;

    function get_IGamePersistent__m_pMainMenu_offset():uintptr; virtual; abstract;
    function get_CMainMenu__m_startDialog_offset():uintptr; virtual; abstract;
    function get_CMainMenu__m_sPDProgress__FileName_offset():uintptr; virtual; abstract;
    function get_CMainMenu__m_sPDProgress__Status_offset():uintptr; virtual; abstract;
    function get_CMainMenu__m_sPDProgress__IsInProgress_offset():uintptr; virtual; abstract;
    function get_CMainMenu__m_sPDProgress__Progress_offset():uintptr; virtual; abstract;
    function get_CMainMenu__m_pGameSpyFull_offset():uintptr; virtual; abstract;
    function get_CMainMenu__m_NeedErrDialog_offset():uintptr; virtual; abstract;
    function get_CMainMenu__ConnectToMasterServer_dlg_id():cardinal; virtual; abstract;
    function get_CMainMenu__Message_dlg_id():cardinal; virtual; abstract;
    function get_CGameSpy_Full__m_pGS_HTTP_offset():uintptr; virtual; abstract;
    function get_CGameSpy_Full__m_pGS_SB_offset():uintptr; virtual; abstract;
    function get_CGameSpy_HTTP__m_LastRequest_offset():uintptr; virtual; abstract;
    function get_CGameSpy_Browser__m_bTryingToConnectToMasterServer_offset():uintptr; virtual; abstract;
    function get_CGameSpy_Browser__m_bAbleToConnectToMasterServer_offset():uintptr; virtual; abstract;

    function get_CMainMenu__m_pMB_ErrDlgs_first_element_ptr_offset():uintptr; virtual; abstract;
    function get_CUIMessageBoxEx_to_CUISimpleWindow_m_bShowMe_offset():uintptr; virtual; abstract;

    function get_CRenderDevice__mt_bMustExit_offset():uintptr; virtual; abstract;
    function get_CRenderDevice__mt_csEnter_offset():uintptr; virtual; abstract;
    function get_CRenderDevice__b_is_Active_offset():uintptr; virtual; abstract;

    function get_CLevel__m_bConnectResult_offset():uintptr; virtual; abstract;
    function get_CLevel__m_bConnectResultReceived_offset():uintptr; virtual; abstract;
    function get_CLevel__m_connect_server_err_offset():uintptr; virtual; abstract;

    function get_shared_str__p_offset():uintptr; virtual; abstract;
    function get_str_value__dwReference_offset():uintptr; virtual; abstract;
    function get_str_value__value_offset():uintptr; virtual; abstract;

    function get_SecondaryThreadProcAddress():uintptr; virtual; abstract;
    function get_SecondaryThreadProcName():PAnsiChar; virtual; abstract;

    function virtual_IMainMenu__Activate_index():cardinal; virtual; abstract;
    function virtual_CUIDialogWnd__Dispatch_index():cardinal; virtual; abstract;

    procedure SetActiveErrorDlg(dlg:cardinal);
    function GetNeedErrorDlg():cardinal;
  public
    constructor Create();
    procedure ShowMpMainMenu(); override;
    procedure AssignStatus(str:PAnsiChar); override;
    function CheckForUserCancelDownload():boolean; override;
    function StartVisualDownload():boolean; override;
    function StopVisualDownload():boolean; override;
    procedure SetVisualProgress(progress:single); override;
    function ThreadSpawn(proc:uintptr; args:uintptr; name:PAnsiChar = nil; stack:cardinal = 0):boolean; override;
    procedure AbortConnection(); override;
    function IsServerListUpdateActive():boolean; override;
    function IsMessageActive():boolean; override;
    procedure TriggerMessage(); override;
    procedure PrepareForMessageShowing(); override;
    procedure ResetMasterServerError(); override;
  end;

  { FZGameVersion1510 }

  FZGameVersion1510 = class(FZCommonGameVersion)
  protected
    function get_CMainMenu_castto_IMainMenu_offset():uintptr; override;

    function get_IGamePersistent__m_pMainMenu_offset():uintptr; override;
    function get_CMainMenu__m_startDialog_offset():uintptr; override;
    function get_CMainMenu__m_sPDProgress__FileName_offset():uintptr; override;
    function get_CMainMenu__m_sPDProgress__Status_offset():uintptr; override;
    function get_CMainMenu__m_sPDProgress__IsInProgress_offset():uintptr; override;
    function get_CMainMenu__m_sPDProgress__Progress_offset():uintptr; override;
    function get_CMainMenu__m_pGameSpyFull_offset():uintptr; override;
    function get_CMainMenu__m_NeedErrDialog_offset():uintptr; override;
    function get_CMainMenu__ConnectToMasterServer_dlg_id():cardinal; override;
    function get_CMainMenu__Message_dlg_id():cardinal; override;
    function get_CGameSpy_Full__m_pGS_HTTP_offset():uintptr; override;
    function get_CGameSpy_HTTP__m_LastRequest_offset():uintptr; override;
    function get_CGameSpy_Full__m_pGS_SB_offset():uintptr; override;
    function get_CGameSpy_Browser__m_bTryingToConnectToMasterServer_offset():uintptr; override;
    function get_CGameSpy_Browser__m_bAbleToConnectToMasterServer_offset():uintptr; override;

    function get_CMainMenu__m_pMB_ErrDlgs_first_element_ptr_offset():uintptr; override;
    function get_CUIMessageBoxEx_to_CUISimpleWindow_m_bShowMe_offset():uintptr; override;

    function get_CRenderDevice__mt_bMustExit_offset():uintptr; override;
    function get_CRenderDevice__mt_csEnter_offset():uintptr; override;
    function get_CRenderDevice__b_is_Active_offset():uintptr; override;

    function get_CLevel__m_bConnectResult_offset():uintptr; override;
    function get_CLevel__m_bConnectResultReceived_offset():uintptr; override;
    function get_CLevel__m_connect_server_err_offset():uintptr; override;

    function get_shared_str__p_offset():uintptr; override;
    function get_str_value__dwReference_offset():uintptr; override;
    function get_str_value__value_offset():uintptr; override;

    function get_SecondaryThreadProcAddress():uintptr; override;
    function get_SecondaryThreadProcName():PAnsiChar; override;

    function virtual_IMainMenu__Activate_index():cardinal; override;
    function virtual_CUIDialogWnd__Dispatch_index():cardinal; override;
  public
    constructor Create();
  end;

  { FZGameVersion10006 }

  FZGameVersion10006 = class(FZCommonGameVersion)
  protected
    function get_CMainMenu_castto_IMainMenu_offset():uintptr; override;

    function get_IGamePersistent__m_pMainMenu_offset():uintptr; override;
    function get_CMainMenu__m_startDialog_offset():uintptr; override;
    function get_CMainMenu__m_sPDProgress__FileName_offset():uintptr; override;
    function get_CMainMenu__m_sPDProgress__Status_offset():uintptr; override;
    function get_CMainMenu__m_sPDProgress__IsInProgress_offset():uintptr; override;
    function get_CMainMenu__m_sPDProgress__Progress_offset():uintptr; override;
    function get_CMainMenu__m_pGameSpyFull_offset():uintptr; override;
    function get_CMainMenu__m_NeedErrDialog_offset():uintptr; override;
    function get_CMainMenu__ConnectToMasterServer_dlg_id():cardinal; override;
    function get_CMainMenu__Message_dlg_id():cardinal; override;
    function get_CGameSpy_Full__m_pGS_HTTP_offset():uintptr; override;
    function get_CGameSpy_HTTP__m_LastRequest_offset():uintptr; override;
    function get_CGameSpy_Full__m_pGS_SB_offset():uintptr; override;
    function get_CGameSpy_Browser__m_bTryingToConnectToMasterServer_offset():uintptr; override;
    function get_CGameSpy_Browser__m_bAbleToConnectToMasterServer_offset():uintptr; override;

    function get_CMainMenu__m_pMB_ErrDlgs_first_element_ptr_offset():uintptr; override;
    function get_CUIMessageBoxEx_to_CUISimpleWindow_m_bShowMe_offset():uintptr; override;

    function get_CRenderDevice__mt_bMustExit_offset():uintptr; override;
    function get_CRenderDevice__mt_csEnter_offset():uintptr; override;
    function get_CRenderDevice__b_is_Active_offset():uintptr; override;

    function get_CLevel__m_bConnectResult_offset():uintptr; override;
    function get_CLevel__m_bConnectResultReceived_offset():uintptr; override;
    function get_CLevel__m_connect_server_err_offset():uintptr; override;

    function get_shared_str__p_offset():uintptr; override;
    function get_str_value__dwReference_offset():uintptr; override;
    function get_str_value__value_offset():uintptr; override;

    function get_SecondaryThreadProcAddress():uintptr; override;
    function get_SecondaryThreadProcName():PAnsiChar; override;

    function virtual_IMainMenu__Activate_index():cardinal; override;
    function virtual_CUIDialogWnd__Dispatch_index():cardinal; override;

  public
    constructor Create();
  end;

  { FZGameVersion10006_v2 }

  FZGameVersion10006_v2 = class(FZGameVersion10006)
  protected
    function get_SecondaryThreadProcAddress():uintptr; override;
    function get_SecondaryThreadProcName():PAnsiChar; override;
  end;

  { FZGameVersion1602 }

  FZGameVersion1602 = class(FZCommonGameVersion)
  protected
    function get_CMainMenu_castto_IMainMenu_offset():uintptr; override;

    function get_IGamePersistent__m_pMainMenu_offset():uintptr; override;
    function get_CMainMenu__m_startDialog_offset():uintptr; override;
    function get_CMainMenu__m_sPDProgress__FileName_offset():uintptr; override;
    function get_CMainMenu__m_sPDProgress__Status_offset():uintptr; override;
    function get_CMainMenu__m_sPDProgress__IsInProgress_offset():uintptr; override;
    function get_CMainMenu__m_sPDProgress__Progress_offset():uintptr; override;
    function get_CMainMenu__m_pGameSpyFull_offset():uintptr; override;
    function get_CMainMenu__m_NeedErrDialog_offset():uintptr; override;
    function get_CMainMenu__ConnectToMasterServer_dlg_id():cardinal; override;
    function get_CMainMenu__Message_dlg_id():cardinal; override;
    function get_CGameSpy_Full__m_pGS_HTTP_offset():uintptr; override;
    function get_CGameSpy_HTTP__m_LastRequest_offset():uintptr; override;
    function get_CGameSpy_Full__m_pGS_SB_offset():uintptr; override;
    function get_CGameSpy_Browser__m_bTryingToConnectToMasterServer_offset():uintptr; override;
    function get_CGameSpy_Browser__m_bAbleToConnectToMasterServer_offset():uintptr; override;

    function get_CMainMenu__m_pMB_ErrDlgs_first_element_ptr_offset():uintptr; override;
    function get_CUIMessageBoxEx_to_CUISimpleWindow_m_bShowMe_offset():uintptr; override;

    function get_CRenderDevice__mt_bMustExit_offset():uintptr; override;
    function get_CRenderDevice__mt_csEnter_offset():uintptr; override;
    function get_CRenderDevice__b_is_Active_offset():uintptr; override;

    function get_CLevel__m_bConnectResult_offset():uintptr; override;
    function get_CLevel__m_bConnectResultReceived_offset():uintptr; override;
    function get_CLevel__m_connect_server_err_offset():uintptr; override;

    function get_shared_str__p_offset():uintptr; override;
    function get_str_value__dwReference_offset():uintptr; override;
    function get_str_value__value_offset():uintptr; override;

    function get_SecondaryThreadProcAddress():uintptr; override;
    function get_SecondaryThreadProcName():PAnsiChar; override;

    function virtual_IMainMenu__Activate_index():cardinal; override;
    function virtual_CUIDialogWnd__Dispatch_index():cardinal; override;
  public
    procedure ShowMpMainMenu(); override;
    procedure PrepareForMessageShowing(); override;
    constructor Create();
  end;

  { FZGameVersionCreator }

  FZGameVersionCreator = class
    class function GetGameVersion():FZ_GAME_VERSION;
  public
    class function DetermineGameVersion():FZAbstractGameVersion;
  end;


function Init():boolean; stdcall;
procedure Free(); stdcall;
function VersionAbstraction():FZAbstractGameVersion;

implementation
uses windows, LogMgr, sysutils;

function AtomicExchange(addr:pcardinal; val:cardinal):cardinal;
var
  tmpptr:plongint;
  tmp:longint;
begin
  tmpptr:=plongint(addr);
  tmp:=InterlockedExchange(tmpptr^, val);
  result:=cardinal(tmp);
end;

procedure uniassert(cond:boolean; descr:string);
begin
  if not cond then begin
    MessageBox(0, PAnsiChar(descr), 'Assertion failed!', MB_OK or MB_ICONERROR);
    TerminateProcess(GetCurrentProcess(), 1);
  end;
end;

{ FZBaseGameVersion }

function CConsole__GetString_fake(cmd:PAnsiChar):PAnsiChar; stdcall;
begin
  result:='Unknown';
end;

constructor FZBaseGameVersion.Create();
var
  f:textfile;
begin
  _exe_module_name:='xrEngine.exe';
  _exe_module_address:=GetModuleHandle(PAnsiChar(_exe_module_name));

  if _exe_module_address=0 then begin
    _exe_module_name:='xr_3DA.exe';
    _exe_module_address:=GetModuleHandle(PAnsiChar(_exe_module_name));
  end;

  _xrGame_module_name:='xrGame';
  _xrGame_module_address:=GetModuleHandle(PAnsiChar(_xrGame_module_name));

  _xrCore_module_name:='xrCore';
  _xrCore_module_address:=GetModuleHandle(PAnsiChar(_xrCore_module_name));

  uniassert(_exe_module_address<>0,    'xrEngine is 0');
  uniassert(_xrGame_module_address<>0, 'xrGame is 0');
  uniassert(_xrCore_module_address<>0, 'xrCore is 0');

  _g_ppGameLevel:=GetProcAddress(_exe_module_address, '?g_pGameLevel@@3PAVIGame_Level@@A');
  uniassert(_g_ppGameLevel<>nil, 'g_ppGameLevel is 0');

  _g_ppConsole:=GetProcAddress(_exe_module_address, '?Console@@3PAVCConsole@@A');
  uniassert(_g_ppConsole<>nil, 'console is 0');

  _core:=GetProcAddress(_xrCore_module_address, '?Core@@3VxrCore@@A');
  uniassert(_core<>nil, 'core is 0');

  _xr_FS:=GetProcAddress(_xrCore_module_address, '?xr_FS@@3PAVCLocatorAPI@@A');
  uniassert(_xr_FS<>nil, 'fs is 0');

  CConsole__Execute:= GetProcAddress(_exe_module_address, '?Execute@CConsole@@QAEXPBD@Z');
  uniassert(CConsole__Execute<>nil, 'CConsole::Execute is 0');

  CLocatorApi__update_path:= GetProcAddress(_xrCore_module_address, '?update_path@CLocatorAPI@@QAEPBDAAY0CAI@DPBD1@Z');
  uniassert(CLocatorApi__update_path<>nil, 'CLocatorApi::update_path is 0');

  CLocatorApi__path_exists:= GetProcAddress(_xrCore_module_address, '?path_exist@CLocatorAPI@@QAE_NPBD@Z');
  uniassert(CLocatorApi__path_exists<>nil, 'CLocatorApi::path_exists is 0');

  //Осторожно! Собака кусается! (тут функция, проверяем значение указателя на нее)
  Log_fun:= GetProcAddress(_xrCore_module_address, '?Msg@@YAXPBDZZ');
  uniassert(@Log_fun<>nil, 'Log_fun is 0');

  //По умолчанию, будем использовать эту заглушку, если в потомках не найдется чего-то поприличнее
  CConsole__GetString:=@CConsole__GetString_fake;


  {$IFNDEF RELEASE}
  _log_file_name:='fz_loader_log.txt';
  {$ELSE}
  _log_file_name:='';
  {$ENDIF}

  if length(_log_file_name) > 0 then begin
    assignfile(f, _log_file_name);
    rewrite(f);
    closefile(f);
  end;
end;

function FZBaseGameVersion.FunFromVTable(obj: uintptr; index: cardinal): uintptr; stdcall;
begin
  index:=index*sizeof(pointer);
  asm
    pushad
    mov eax, obj
    mov eax, [eax]
    mov ebx, index
    mov eax, [eax+ebx]
    mov result, eax
    popad
  end;
end;

function FZBaseGameVersion.DoEcxCall_noarg(fun: uintptr; obj: uintptr): uintptr; stdcall;
asm
  pushad
  mov ecx, obj
  call fun
  mov result, eax
  popad
end;

function FZBaseGameVersion.DoEcxCall_1arg(fun: uintptr; obj: uintptr; arg: uintptr):uintptr; stdcall;
asm
  pushad
  mov ecx, obj
  push arg
  call fun
  mov result, eax
  popad
end;

function FZBaseGameVersion.DoEcxCall_2arg(fun: uintptr; obj: uintptr; arg1: uintptr; arg2: uintptr): uintptr; stdcall;
asm
  pushad
  mov ecx, obj
  push arg2
  push arg1
  call fun
  mov result, eax
  popad
end;

function FZBaseGameVersion.DoEcxCall_3arg(fun: uintptr; obj: uintptr; arg1: uintptr; arg2: uintptr; arg3: uintptr): uintptr; stdcall;
asm
  pushad
  mov ecx, obj
  push arg3
  push arg2
  push arg1
  call fun
  mov result, eax
  popad
end;

destructor FZBaseGameVersion.Destroy();
begin
  inherited Destroy;
end;

function FZBaseGameVersion.GetLevel(): uintptr;
begin
  result:=_g_ppGameLevel^;
end;

function FZBaseGameVersion.GetCoreParams(): PAnsiChar;
begin
  result:=_core.Params;
end;

function FZBaseGameVersion.GetCoreApplicationPath(): PAnsiChar;
begin
  result:=_core.ApplicationPath;
end;

procedure FZBaseGameVersion.ExecuteConsoleCommand(cmd: PAnsiChar);
begin
  DoEcxCall_1arg(uintptr(CConsole__Execute), _g_ppConsole^, uintptr(cmd));
end;

function FZBaseGameVersion.GetEngineExeFileName(): PAnsiChar;
begin
  result:=PAnsiChar(_exe_module_name);
end;

function FZBaseGameVersion.GetEngineExeModuleAddress(): uintptr;
begin
  result:=_exe_module_address;
end;

function FZBaseGameVersion.UpdatePath(root: string; appendix: string): string;
var
  buf:array[0..1023] of char;
  res_buf:PAnsiChar;
begin
  res_buf:=@buf[0];
  DoEcxCall_3arg(uintptr(CLocatorApi__update_path), _xr_FS^, uintptr(res_buf), uintptr(PAnsiChar(root)), uintptr(PAnsiChar(appendix)));
  result:=res_buf;
end;

function FZBaseGameVersion.PathExists(root: string): boolean;
begin
  result:= byte(DoEcxCall_1arg(uintptr(CLocatorApi__path_exists), _xr_FS^, uintptr(PAnsiChar(root)))) <> 0;
end;

function FZBaseGameVersion.CheckForLevelExist(): boolean;
begin
  result:=(GetLevel()<>0);
end;

procedure FZBaseGameVersion.Log(txt: PAnsiChar);
var
  f:textfile;
begin
  if length(_log_file_name) > 0 then begin
    assignfile(f, _log_file_name);
    try
      append(f);
    except
      rewrite(f);
    end;
    writeln(f, txt);
    closefile(f);
  end;

  Log_fun(txt);
end;

function FZBaseGameVersion.GetPlayerName(): string;
var
  res:PAnsiChar;
const
  cmd:string='mm_net_player_name';
begin
  res:=PAnsiChar(DoEcxCall_1arg(uintptr(CConsole__GetString), _g_ppConsole^, uintptr(PAnsiChar(cmd))));
  result:=res;
end;

{ FZUnknownGameVersion }

procedure FZUnknownGameVersion.ShowMpMainMenu();
begin
end;

procedure FZUnknownGameVersion.AssignStatus(str: PAnsiChar);
begin
  FZLogMgr.Get().Write('Changing status to: '+ str, FZ_LOG_INFO);
end;

function FZUnknownGameVersion.CheckForUserCancelDownload(): boolean;
begin
  result:=false;
end;

function FZUnknownGameVersion.StartVisualDownload(): boolean;
begin
  result:=true;
end;

function FZUnknownGameVersion.StopVisualDownload(): boolean;
begin
  result:=true;
end;

procedure FZUnknownGameVersion.SetVisualProgress(progress: single);
begin
end;

function FZUnknownGameVersion.ThreadSpawn(proc: uintptr; args: uintptr; name:PAnsiChar = nil; stack:cardinal = 0):boolean;
var
  thId:cardinal;
begin
  result:=true;
  thId:=0;
  CreateThread(nil, 0, pointer(proc), pointer(args), 0, thId);
end;

procedure FZUnknownGameVersion.AbortConnection();
begin
end;

function FZUnknownGameVersion.IsServerListUpdateActive(): boolean;
begin
  result:=false;
end;

function FZUnknownGameVersion.IsMessageActive(): boolean;
begin
  result:=false;
end;

procedure FZUnknownGameVersion.TriggerMessage();
begin
end;

procedure FZUnknownGameVersion.PrepareForMessageShowing();
begin
end;

procedure FZUnknownGameVersion.ResetMasterServerError();
begin
end;

{ FZCommonGameVersion }
constructor FZCommonGameVersion.Create();
begin
  inherited;
  _g_ppStringContainer:=GetProcAddress(_xrcore_module_address, '?g_pStringContainer@@3PAVstr_container@@A');
  uniassert(_g_ppStringContainer<>nil, 'StringContainer is 0');

  _g_ppGamePersistent:=GetProcAddress(_exe_module_address, '?g_pGamePersistent@@3PAVIGame_Persistent@@A');
  uniassert(_g_ppGamePersistent<>nil, 'GamePersistent is 0');

  _pDevice:=uintptr(GetProcAddress(_exe_module_address, '?Device@@3VCRenderDevice@@A'));
  uniassert(_pDevice<>0, 'Device is 0');

  _g_pbRendering:=GetProcAddress(_exe_module_address, '?g_bRendering@@3HA');
  uniassert(_g_pbRendering<>nil, 'bRendering is 0');

  xrCriticalSection__Enter:=GetProcAddress(_xrcore_module_address, '?Enter@xrCriticalSection@@QAEXXZ');
  uniassert(xrCriticalSection__Enter<>nil, 'xrCriticalSection::Enter is 0');

  xrCriticalSection__Leave:=GetProcAddress(_xrcore_module_address, '?Leave@xrCriticalSection@@QAEXXZ');
  uniassert(xrCriticalSection__Leave<>nil, 'xrCriticalSection::Leave is 0');

  str_container__dock:=GetProcAddress(_xrcore_module_address, '?dock@str_container@@QAEPAUstr_value@@PBD@Z');
  uniassert(str_container__dock<>nil, 'str_container::dock is 0');

  //Осторожно! Собака кусается! (тут функция, проверяем значение указателя на нее)
  thread_spawn:=GetProcAddress(_xrCore_module_address, '?thread_spawn@@YAXP6AXPAX@ZPBDI0@Z');
  uniassert(@thread_spawn<>nil, 'thread_spawn is 0');
end;

procedure FZCommonGameVersion.SafeExec_start();
var
  old_active_status:cardinal;

  mt_bMustExit:pbyte;
  mt_csEnter:uintptr;
  b_is_Active:pcardinal;
begin
  //НЕ ТРОГАТЬ! ОПАСНО ДЛЯ ЖИЗНИ!
  mt_bMustExit := pbyte(_pDevice + get_CRenderDevice__mt_bMustExit_offset());
  mt_csEnter   := _pDevice + get_CRenderDevice__mt_csEnter_offset();
  b_is_Active  := pointer(_pDevice + get_CRenderDevice__b_is_Active_offset());

  //Даем cигнал к завершению второго потока
  mt_bMustExit^:=1;

  //Ожидаем завершения
  while (mt_bMustExit^ > 0) do Sleep(1);

  //теперь мимикрируем под Secondary Thread, захватывая мьютекс, разрешающий
  //начало его выполнения и сигнализируещий главному потоку об активной работе оного
  //Он может быть захвачен только во время активности параллельного участка главного потока!

  DoEcxCall_noarg(uintptr(xrCriticalSection__Enter), mt_csEnter);

  //но тут нас ожидает проблема: главный поток сейчас может вовсю исполнять свою работу и
  //рендерить. Надо заблокировать ему возможность начала рендеринга, а если он после этого
  //окажется уже занят им - подождать, пока он закончит свои дела.
  old_active_status:=AtomicExchange(b_is_Active, 0);

  //CRenderDevice::b_is_Active, будучи выставлен в false, предотвратит начало рендеринга
  //Но если рендеринг начался до того, как мы выставили флаг, нам надо подождать его конца
  while _g_pbRendering^<>0 do begin
    Sleep(1);
  end;

  AtomicExchange(b_is_Active, old_active_status);
end;

procedure FZCommonGameVersion.SafeExec_end();
begin
  //НЕ ТРОГАТЬ! ОПАСНО ДЛЯ ЖИЗНИ!
  //Самое время перезапустить второй поток
  ThreadSpawn(get_SecondaryThreadProcAddress(), 0, get_SecondaryThreadProcName(), 0);

  //Больше не требуется ничего ждать :)
  DoEcxCall_noarg(uintptr(xrCriticalSection__Leave), _pDevice + get_CRenderDevice__mt_csEnter_offset());

  //ждать завершения работы итерации главного потока нет необходимости.
  //Более того, вторичный поток еще может успеть захватить mt_csEnter ;)
end;

procedure FZCommonGameVersion.assign_string(pshared_str: uintptr; text: PAnsiChar); stdcall;
var
  pnewvalue, poldvalue:uintptr;
begin
  uniassert(pshared_str <> 0, 'pshared_str is nil, cannot assign');

  pnewvalue:=DoEcxCall_1arg( uintptr(str_container__dock), _g_ppStringContainer^, uintptr(text) );

  if pnewvalue<>0 then begin
    pcardinal(pnewvalue+get_str_value__dwReference_offset())^:=pcardinal(pnewvalue+get_str_value__dwReference_offset())^+1;
  end;

  poldvalue:=puintptr(pshared_str+get_shared_str__p_offset())^;
  if poldvalue<>0 then begin
    pcardinal(poldvalue+get_str_value__dwReference_offset())^:=pcardinal(poldvalue+get_str_value__dwReference_offset())^-1;
    if pcardinal(poldvalue+get_str_value__dwReference_offset())^ = 0 then begin
      puintptr(pshared_str+get_str_value__value_offset())^:=0;
    end;
  end;

  puintptr(pshared_str+get_shared_str__p_offset())^:=pnewvalue;
end;

function FZCommonGameVersion.GetMainMenu(): uintptr;
var
  gamePersistent: uintptr;
begin
  gamePersistent:=_g_ppGamePersistent^;
  uniassert(gamePersistent<>0, 'gamePersistent not exist');

  result:=puintptr(gamePersistent+get_IGamePersistent__m_pMainMenu_offset())^;
end;

procedure FZCommonGameVersion.ActivateMainMenu(state: boolean);
var
  imm:uintptr;
  arg:uintptr;
begin
  imm:=GetMainMenu()+get_CMainMenu_castto_IMainMenu_offset();
  if state then arg := 1 else arg:=0;
  DoEcxCall_1arg(FunFromVTable(imm, virtual_IMainMenu__Activate_index()), imm, arg);
end;

function FZCommonGameVersion.IsMessageActive(): boolean;
var
  mm:uintptr;
  windows_start:uintptr;
  msgwnd:uintptr;
begin
  result:=false;
  mm:=GetMainMenu();
  if mm = 0 then exit;

  windows_start:=puintptr(mm+get_CMainMenu__m_pMB_ErrDlgs_first_element_ptr_offset())^;
  if windows_start = 0 then exit;

  msgwnd:=puintptr(windows_start+sizeof(uintptr)*get_CMainMenu__Message_dlg_id())^;
  if msgwnd = 0 then exit;

  //Сначала смотрим, не показывается ли окно
  result:=(pByte(msgwnd+get_CUIMessageBoxEx_to_CUISimpleWindow_m_bShowMe_offset())^ <> 0);
  if result then exit;

  //Быть может, мы его собираемся показать? (наоборот проверять нельзя! Выставление значения во время активности окна его скрывает!)
  result:=pByte(mm+get_CMainMenu__m_NeedErrDialog_offset())^ = get_CMainMenu__Message_dlg_id();
end;

procedure FZCommonGameVersion.TriggerMessage();
begin
  SetActiveErrorDlg(get_CMainMenu__Message_dlg_id());
end;

procedure FZCommonGameVersion.PrepareForMessageShowing();
begin
  //Окно сообщение в ТЧ/ЧН может "зависнуть" в неопределенном состоянии
  //Будем триггерить его до тех пор, пока не "отлипнет"
  while IsMessageActive() do begin
    TriggerMessage();
  end;
end;

procedure FZCommonGameVersion.ResetMasterServerError();
var
  mm,gsfull,sb:uintptr;
begin
  mm:=GetMainMenu();
  if mm = 0 then exit;

  gsfull:=puintptr(mm+get_CMainMenu__m_pGameSpyFull_offset())^;
  if gsfull=0 then exit;

  sb:=puintptr(gsfull+get_CGameSpy_Full__m_pGS_SB_offset())^;
  if sb=0 then exit;

  pByte(sb+get_CGameSpy_Browser__m_bAbleToConnectToMasterServer_offset())^:=1;
end;

procedure FZCommonGameVersion.ShowMpMainMenu();
const
  MP_MENU_CMD:cardinal = 2;
  MP_MENU_PARAM:cardinal = 1;
var
  dlg, mm:uintptr;
begin
  mm:=GetMainMenu();

  SafeExec_start();

  ActivateMainMenu(false);
  ActivateMainMenu(true);

  //m_startDialog обновляется после ActivateMainMenu, поэтому нельзя заранее смотреть его положение!
  dlg:=puintptr(mm+get_CMainMenu__m_startDialog_offset())^;
  if( dlg<>0 ) then begin
    DoEcxCall_2arg(FunFromVTable(dlg, virtual_CUIDialogWnd__Dispatch_index()), dlg, MP_MENU_CMD, MP_MENU_PARAM);
  end;

  SafeExec_end();
end;

procedure FZCommonGameVersion.AssignStatus(str: PAnsiChar);
var
  mm:uintptr;
begin
  mm:=GetMainMenu();

  SafeExec_start();

  assign_string(mm+get_CMainMenu__m_sPDProgress__FileName_offset(), str);
  assign_string(mm+get_CMainMenu__m_sPDProgress__Status_offset(), str);

  SafeExec_end();
end;

function FZCommonGameVersion.CheckForUserCancelDownload(): boolean;
begin
  result := (pbyte(GetMainMenu() + get_CMainMenu__m_sPDProgress__IsInProgress_offset())^ = 0);
end;

function FZCommonGameVersion.StartVisualDownload(): boolean;
var
  mm:uintptr;
  tmp:cardinal;
  cyclesCount:cardinal;

  gsFull, gsHttp:uintptr;
begin
  result:=false;
  mm:=GetMainMenu();

  //Назначим строку-пояснение над индикатором загрузки (там что-то должно быть перед
  //назначением IsInProgress, иначе вероятность вылета при попытке отрисовки)
  if ( puintptr(mm+get_CMainMenu__m_sPDProgress__FileName_offset()+get_shared_str__p_offset())^ = 0 ) then begin
    AssignStatus('Preparing synchronization...');
  end;

  cyclesCount:=1000; //будем ждать 10 секунд, пока нам разрешат загружаться

  repeat
    cyclesCount:=cyclesCount-1;
    Sleep(10);
    //Атомарно выставим активность загрузки и получим предыдущее значение (только в младшем байте, остальное мусор!)
    tmp:=AtomicExchange(pcardinal(mm + get_CMainMenu__m_sPDProgress__IsInProgress_offset()), 1) and $FF;
    //Убедимся, что загрузку до нас никто еще не стартовал, пока мы ждали захват мьютекса
  until (tmp=0) or (cyclesCount = 0);

  if tmp<>0 then begin
    exit;
  end;

  SetVisualProgress(0);

  //На случай нажатия кнопки отмена - укажем, что активного запроса о загрузке не было
  gsFull:=puintptr(mm+get_CMainMenu__m_pGameSpyFull_offset())^;
  uniassert(gsFull<>0, 'm_pGameSpyFull is 0');
  gsHttp:=puintptr(gsFull+get_CGameSpy_Full__m_pGS_HTTP_offset())^;
  uniassert(gsHttp<>0, 'm_pGS_HTTP is 0');
  pcardinal(gsHttp+get_CGameSpy_HTTP__m_LastRequest_offset())^:=cardinal(-1);

  //Включим главное меню на вкладке мультиплеера(ползунок загрузки есть только там)
  ShowMpMainMenu();
  result:=true;
end;

function FZCommonGameVersion.StopVisualDownload(): boolean;
begin
  SetVisualProgress(0);
  AtomicExchange(pcardinal(GetMainMenu() + get_CMainMenu__m_sPDProgress__IsInProgress_offset()), 0);
  result:=true;
end;

procedure FZCommonGameVersion.SetVisualProgress(progress: single);
begin
  psingle(GetMainMenu()+get_CMainMenu__m_sPDProgress__Progress_offset())^ := progress;
end;

function FZCommonGameVersion.ThreadSpawn(proc: uintptr; args: uintptr; name:PAnsiChar = nil; stack:cardinal = 0): boolean;
begin
  thread_spawn(pointer(proc), name, stack, pointer(args));
  result:=true;
end;

procedure FZCommonGameVersion.AbortConnection();
var
  lvl:uintptr;
const
  EConnect__ErrConnect:byte=0;
begin
  if CheckForLevelExist() then begin
    lvl:=GetLevel();
    pbyte(lvl+get_CLevel__m_bConnectResult_offset())^ := 0;
    pbyte(lvl+get_CLevel__m_connect_server_err_offset())^ := EConnect__ErrConnect;
    pbyte(lvl+get_CLevel__m_bConnectResultReceived_offset())^ := 1;
  end;
end;

function FZCommonGameVersion.IsServerListUpdateActive(): boolean;
var
  mm, windows_start, msgwnd:uintptr;
  gsfull:uintptr;
  sb:uintptr;
  status:byte;
begin
  result:=false;

  mm:=GetMainMenu();
  if mm = 0 then exit;

  gsfull:=puintptr(mm+get_CMainMenu__m_pGameSpyFull_offset())^;
  if gsfull=0 then exit;

  sb:=puintptr(gsfull+get_CGameSpy_Full__m_pGS_SB_offset())^;
  if sb=0 then exit;

  status:=pByte(sb+get_CGameSpy_Browser__m_bTryingToConnectToMasterServer_offset())^;

  result:= status<>0;
  if result then exit;

  //Смотрим, не активно ли все еще окно
  windows_start:=puintptr(mm+get_CMainMenu__m_pMB_ErrDlgs_first_element_ptr_offset())^;
  if windows_start = 0 then exit;

  msgwnd:=puintptr(windows_start+sizeof(uintptr)*get_CMainMenu__ConnectToMasterServer_dlg_id())^;
  if msgwnd = 0 then exit;

  //Сначала смотрим, не показывается ли окно
  result:=(pByte(msgwnd+get_CUIMessageBoxEx_to_CUISimpleWindow_m_bShowMe_offset())^ <> 0);
  if result then exit;

end;

function FZCommonGameVersion.GetNeedErrorDlg(): cardinal;
var
  mm:uintptr;
begin
  result:=0;
  mm:=GetMainMenu();
  if mm = 0 then exit;

  result:=pByte(mm+get_CMainMenu__m_NeedErrDialog_offset())^;
end;

procedure FZCommonGameVersion.SetActiveErrorDlg(dlg: cardinal);
var
  mm:uintptr;
begin
  mm:=GetMainMenu();
  if mm = 0 then exit;
  pByte(mm+get_CMainMenu__m_NeedErrDialog_offset())^:=byte(dlg);
end;

{ FZGameVersion1510 }

constructor FZGameVersion1510.Create();
var
  addr:pointer;
begin
  inherited;
  addr:=GetProcAddress(_exe_module_address, '?GetString@CConsole@@QAEPBDPBD@Z');
  if addr<>nil then begin
    CConsole__GetString:=addr;
  end;
end;

function FZGameVersion1510.get_CMainMenu_castto_IMainMenu_offset(): uintptr;
begin
  result:=0;
end;

function FZGameVersion1510.get_IGamePersistent__m_pMainMenu_offset(): uintptr;
begin
  result:=$46C;
end;

function FZGameVersion1510.get_CMainMenu__m_startDialog_offset(): uintptr;
begin
  result:=$54;
end;

function FZGameVersion1510.get_CMainMenu__m_sPDProgress__FileName_offset(): uintptr;
begin
  result:=$284;
end;

function FZGameVersion1510.get_CMainMenu__m_sPDProgress__Status_offset(): uintptr;
begin
  result:=$280;
end;

function FZGameVersion1510.get_CMainMenu__m_sPDProgress__IsInProgress_offset(): uintptr;
begin
  result:=$278;
end;

function FZGameVersion1510.get_CMainMenu__m_sPDProgress__Progress_offset(): uintptr;
begin
  result:=$27C;
end;

function FZGameVersion1510.get_CMainMenu__m_pGameSpyFull_offset(): uintptr;
begin
  result:=$274;
end;

function FZGameVersion1510.get_CMainMenu__m_NeedErrDialog_offset(): uintptr;
begin
  result:=$288;
end;

function FZGameVersion1510.get_CMainMenu__ConnectToMasterServer_dlg_id(): cardinal;
begin
  result:=14;
end;

function FZGameVersion1510.get_CMainMenu__Message_dlg_id(): cardinal;
begin
  result:=$10;
end;

function FZGameVersion1510.get_CGameSpy_Full__m_pGS_HTTP_offset(): uintptr;
begin
  result:=$10;
end;

function FZGameVersion1510.get_CGameSpy_HTTP__m_LastRequest_offset(): uintptr;
begin
  result:=$4;
end;

function FZGameVersion1510.get_CGameSpy_Full__m_pGS_SB_offset(): uintptr;
begin
  result:=$14;
end;

function FZGameVersion1510.get_CGameSpy_Browser__m_bTryingToConnectToMasterServer_offset(): uintptr;
begin
  result:=$11;
end;

function FZGameVersion1510.get_CGameSpy_Browser__m_bAbleToConnectToMasterServer_offset(): uintptr;
begin
  result:=$10;
end;

function FZGameVersion1510.get_CMainMenu__m_pMB_ErrDlgs_first_element_ptr_offset(): uintptr;
begin
  result:=$2A4
end;

function FZGameVersion1510.get_CUIMessageBoxEx_to_CUISimpleWindow_m_bShowMe_offset(): uintptr;
begin
  result:=4;
end;

function FZGameVersion1510.get_CRenderDevice__mt_bMustExit_offset(): uintptr;
begin
  result:=$304;
end;

function FZGameVersion1510.get_CRenderDevice__mt_csEnter_offset(): uintptr;
begin
  result:=$2FC;
end;

function FZGameVersion1510.get_CRenderDevice__b_is_Active_offset(): uintptr;
begin
  result:=$114;
end;

function FZGameVersion1510.get_CLevel__m_bConnectResult_offset(): uintptr;
begin
  result:=$496A9;
end;

function FZGameVersion1510.get_CLevel__m_bConnectResultReceived_offset(): uintptr;
begin
  result:=$496A8;
end;

function FZGameVersion1510.get_CLevel__m_connect_server_err_offset(): uintptr;
begin
  result:=$49698;
end;

function FZGameVersion1510.get_shared_str__p_offset(): uintptr;
begin
  result:=0;
end;

function FZGameVersion1510.get_str_value__dwReference_offset(): uintptr;
begin
  result:=0;
end;

function FZGameVersion1510.get_str_value__value_offset(): uintptr;
begin
  result:=$10;
end;

function FZGameVersion1510.get_SecondaryThreadProcAddress(): uintptr;
begin
  result:=_exe_module_address+$556F0;
end;

function FZGameVersion1510.get_SecondaryThreadProcName(): PAnsiChar;
begin
  result:=PAnsiChar(_exe_module_address+$7ACB4);
end;

function FZGameVersion1510.virtual_IMainMenu__Activate_index(): cardinal;
begin
  result:=$1;
end;

function FZGameVersion1510.virtual_CUIDialogWnd__Dispatch_index(): cardinal;
begin
  result:=$29;
end;

{ FZGameVersion10006 }

constructor FZGameVersion10006.Create();
var
  addr:pointer;
begin
  inherited;
  addr:=GetProcAddress(_exe_module_address, '?GetString@CConsole@@QAEPADPBD@Z');
  if addr<>nil then begin
    CConsole__GetString:=addr;
  end;
end;

function FZGameVersion10006.get_CMainMenu_castto_IMainMenu_offset(): uintptr;
begin
  result:=0;
end;

function FZGameVersion10006.get_IGamePersistent__m_pMainMenu_offset(): uintptr;
begin
  result:=$468;
end;

function FZGameVersion10006.get_CMainMenu__m_startDialog_offset(): uintptr;
begin
  result:=$50;
end;

function FZGameVersion10006.get_CMainMenu__m_sPDProgress__FileName_offset(): uintptr;
begin
  result:=$284;
end;

function FZGameVersion10006.get_CMainMenu__m_sPDProgress__Status_offset(): uintptr;
begin
  result:=$280;
end;

function FZGameVersion10006.get_CMainMenu__m_sPDProgress__IsInProgress_offset(): uintptr;
begin
  result:=$278;
end;

function FZGameVersion10006.get_CMainMenu__m_sPDProgress__Progress_offset(): uintptr;
begin
  result:=$27C;
end;

function FZGameVersion10006.get_CMainMenu__m_pGameSpyFull_offset(): uintptr;
begin
  result:=$274;
end;

function FZGameVersion10006.get_CMainMenu__m_NeedErrDialog_offset(): uintptr;
begin
  result:=$288
end;

function FZGameVersion10006.get_CMainMenu__ConnectToMasterServer_dlg_id(): cardinal;
begin
  result:=14;
end;

function FZGameVersion10006.get_CMainMenu__Message_dlg_id(): cardinal;
begin
  result:=$10;
end;

function FZGameVersion10006.get_CGameSpy_Full__m_pGS_HTTP_offset(): uintptr;
begin
  result:=$10;
end;

function FZGameVersion10006.get_CGameSpy_HTTP__m_LastRequest_offset(): uintptr;
begin
  result:=$04;
end;

function FZGameVersion10006.get_CGameSpy_Full__m_pGS_SB_offset(): uintptr;
begin
  result:=$14;
end;

function FZGameVersion10006.get_CGameSpy_Browser__m_bTryingToConnectToMasterServer_offset(): uintptr;
begin
  result:=$11;
end;

function FZGameVersion10006.get_CGameSpy_Browser__m_bAbleToConnectToMasterServer_offset(): uintptr;
begin
  result:=$10;
end;

function FZGameVersion10006.get_CMainMenu__m_pMB_ErrDlgs_first_element_ptr_offset(): uintptr;
begin
  result:=$29c;
end;

function FZGameVersion10006.get_CUIMessageBoxEx_to_CUISimpleWindow_m_bShowMe_offset(): uintptr;
begin
  result:=4;
end;

function FZGameVersion10006.get_CRenderDevice__mt_bMustExit_offset(): uintptr;
begin
  result:=$34c;
end;

function FZGameVersion10006.get_CRenderDevice__mt_csEnter_offset(): uintptr;
begin
  result:=$344;
end;

function FZGameVersion10006.get_CRenderDevice__b_is_Active_offset(): uintptr;
begin
  result:=$114;
end;

function FZGameVersion10006.get_CLevel__m_bConnectResult_offset(): uintptr;
begin
  result:=$45a1;
end;

function FZGameVersion10006.get_CLevel__m_bConnectResultReceived_offset(): uintptr;
begin
  result:=$45a0;
end;

function FZGameVersion10006.get_CLevel__m_connect_server_err_offset(): uintptr;
begin
  result:=$4594;
end;

function FZGameVersion10006.get_shared_str__p_offset(): uintptr;
begin
  result:=0;
end;

function FZGameVersion10006.get_str_value__dwReference_offset(): uintptr;
begin
  result:=0;
end;

function FZGameVersion10006.get_str_value__value_offset(): uintptr;
begin
  result:=$c;
end;

function FZGameVersion10006.get_SecondaryThreadProcAddress(): uintptr;
begin
  result:=_exe_module_address+$83450;
end;

function FZGameVersion10006.get_SecondaryThreadProcName(): PAnsiChar;
begin
  result:=PAnsiChar(_exe_module_address+$D4D48);
end;

function FZGameVersion10006.virtual_IMainMenu__Activate_index(): cardinal;
begin
  result:=1;
end;

function FZGameVersion10006.virtual_CUIDialogWnd__Dispatch_index(): cardinal;
begin
  result:=$2C;
end;

{ FZGameVersion10006_v2 }

function FZGameVersion10006_v2.get_SecondaryThreadProcAddress: uintptr;
begin
  result:=_exe_module_address+$836A0;
end;

function FZGameVersion10006_v2.get_SecondaryThreadProcName: PAnsiChar;
begin
  result:= PAnsiChar(_exe_module_address+$D4D78);
end;

{ FZGameVersion1602 }

constructor FZGameVersion1602.Create();
var
  addr:pointer;
begin
  inherited;
  addr:=GetProcAddress(_exe_module_address, '?GetString@CConsole@@QBEPBDPBD@Z');
  if addr<>nil then begin
    CConsole__GetString:=addr;
  end;
end;

procedure FZGameVersion1602.ShowMpMainMenu();
const
  CMainMenu_login_manager_offset:cardinal=$274;
  login_manager_m_current_profile_offset:cardinal=$11C;
var
  mm, lm, profile:uintptr;
begin
  //В ЗП нельзя переходить в мультплеерное окно, если юзер никуда не залогинился - будет вылет
  mm:=GetMainMenu();
  lm:=puintptr(mm+CMainMenu_login_manager_offset)^;
  if lm=0 then exit;

  profile:=puintptr(lm+login_manager_m_current_profile_offset)^;
  if profile=0 then exit;

  inherited ShowMpMainMenu;
end;

procedure FZGameVersion1602.PrepareForMessageShowing();
var
  mm:uintptr;
  windows_start:uintptr;
  msgwnd:uintptr;
begin
  //в ЗП многократно триггерить бесполезно - оно работает только на отображение окна
  //Оно и к лучшему - не надо ничего ждать перед отображением
  //Но надо выставить статус m_bShowed окна в false (оно может быть залипшим!)
  mm:=GetMainMenu();
  if mm = 0 then exit;

  windows_start:=puintptr(mm+get_CMainMenu__m_pMB_ErrDlgs_first_element_ptr_offset())^;
  if windows_start = 0 then exit;

  msgwnd:=puintptr(windows_start+sizeof(uintptr)*get_CMainMenu__Message_dlg_id())^;
  if msgwnd = 0 then exit;

  pByte(msgwnd+get_CUIMessageBoxEx_to_CUISimpleWindow_m_bShowMe_offset())^:=0;
end;

function FZGameVersion1602.get_CMainMenu_castto_IMainMenu_offset(): uintptr;
begin
  result:= 0;
end;

function FZGameVersion1602.get_IGamePersistent__m_pMainMenu_offset(): uintptr;
begin
  result:=$46C;
end;

function FZGameVersion1602.get_CMainMenu__m_startDialog_offset(): uintptr;
begin
  result:=$4C;
end;

function FZGameVersion1602.get_CMainMenu__m_sPDProgress__FileName_offset(): uintptr;
begin
  result:=$294;
end;

function FZGameVersion1602.get_CMainMenu__m_sPDProgress__Status_offset(): uintptr;
begin
  result:=$290;
end;

function FZGameVersion1602.get_CMainMenu__m_sPDProgress__IsInProgress_offset(): uintptr;
begin
  result:=$288;
end;

function FZGameVersion1602.get_CMainMenu__m_sPDProgress__Progress_offset(): uintptr;
begin
  result:=$28C;
end;

function FZGameVersion1602.get_CMainMenu__m_pGameSpyFull_offset(): uintptr;
begin
  result:=$26C;
end;

function FZGameVersion1602.get_CMainMenu__m_NeedErrDialog_offset(): uintptr;
begin
  result:=$298;
end;

function FZGameVersion1602.get_CMainMenu__ConnectToMasterServer_dlg_id(): cardinal;
begin
  result:=14;
end;

function FZGameVersion1602.get_CMainMenu__Message_dlg_id(): cardinal;
begin
  result:=$10;
end;

function FZGameVersion1602.get_CGameSpy_Full__m_pGS_HTTP_offset(): uintptr;
begin
  result:=$10;
end;

function FZGameVersion1602.get_CGameSpy_HTTP__m_LastRequest_offset(): uintptr;
begin
  result:=$04;
end;

function FZGameVersion1602.get_CGameSpy_Full__m_pGS_SB_offset(): uintptr;
begin
  result:=$14;
end;

function FZGameVersion1602.get_CGameSpy_Browser__m_bTryingToConnectToMasterServer_offset(): uintptr;
begin
  result:=$11;
end;

function FZGameVersion1602.get_CGameSpy_Browser__m_bAbleToConnectToMasterServer_offset(): uintptr;
begin
  result:=$10;
end;

function FZGameVersion1602.get_CMainMenu__m_pMB_ErrDlgs_first_element_ptr_offset(): uintptr;
begin
  result:=$2B4;
end;

function FZGameVersion1602.get_CUIMessageBoxEx_to_CUISimpleWindow_m_bShowMe_offset(): uintptr;
begin
  result:=4;
end;

function FZGameVersion1602.get_CRenderDevice__mt_bMustExit_offset(): uintptr;
begin
  result:=$3E4;
end;

function FZGameVersion1602.get_CRenderDevice__mt_csEnter_offset(): uintptr;
begin
  result:=$3DC;
end;

function FZGameVersion1602.get_CRenderDevice__b_is_Active_offset(): uintptr;
begin
  result:=$14;
end;

function FZGameVersion1602.get_CLevel__m_bConnectResult_offset(): uintptr;
begin
  result:=$486D1;
end;

function FZGameVersion1602.get_CLevel__m_bConnectResultReceived_offset(): uintptr;
begin
  result:=$486D0;
end;

function FZGameVersion1602.get_CLevel__m_connect_server_err_offset(): uintptr;
begin
  result:=$486C0;
end;

function FZGameVersion1602.get_shared_str__p_offset(): uintptr;
begin
  result:=$0;
end;

function FZGameVersion1602.get_str_value__dwReference_offset(): uintptr;
begin
  result:=$0;
end;

function FZGameVersion1602.get_str_value__value_offset(): uintptr;
begin
  result:=$10;
end;

function FZGameVersion1602.get_SecondaryThreadProcAddress(): uintptr;
begin
  result:=_exe_module_address+$53290;
end;

function FZGameVersion1602.get_SecondaryThreadProcName(): PAnsiChar;
begin
  result:= PAnsiChar(_exe_module_address + $75F34);
end;

function FZGameVersion1602.virtual_IMainMenu__Activate_index(): cardinal;
begin
  result:=1;
end;

function FZGameVersion1602.virtual_CUIDialogWnd__Dispatch_index(): cardinal;
begin
  result:=$1F;
end;

{ FZTestGameVersion }

function FZTestGameVersion.ThreadSpawn(proc: uintptr; args: uintptr; name:PAnsiChar = nil; stack:cardinal = 0):boolean;
var
  thId:cardinal;
begin
  result:=true;
  thId:=0;
  CreateThread(nil, 0, pointer(proc), pointer(args), 0, thId);
end;

procedure FZTestGameVersion.Log(txt: PAnsiChar);
var
  s:string;
begin
  s:='[TestGame] '+txt;
  writeln(s);
end;

function FZTestGameVersion.GetPlayerName(): string;
begin
  result:='TestPlayer';
end;

function FZTestGameVersion.IsServerListUpdateActive(): boolean;
begin
  result:=false;
end;

////////////////////////////////////////////////////////////////////////////////////
{ FZGameVersionCreator }
////////////////////////////////////////////////////////////////////////////////////
class function FZGameVersionCreator.GetGameVersion: FZ_GAME_VERSION;
var
  xrGS_GetGameVersion: function(pBuf:pointer):PAnsiChar; cdecl;
  xrGS:HMODULE;
  xr3DA:HMODULE;
  ptimestamp:pcardinal;
  ver:string;
begin
  result:=FZ_VER_UNKNOWN;
  xrGS:=GetModuleHandle('xrGameSpy.dll');
  if xrGS = 0 then exit;

  xrGS_GetGameVersion:=GetProcAddress(xrGS, 'xrGS_GetGameVersion');
  if @xrGS_GetGameVersion = nil then exit;

  ver:=xrGS_GetGameVersion(nil);

  if ver = '1.5.10' then begin
    result:=FZ_VER_CS_1510;
  end else if ver = '1.0006' then begin
    xr3DA:=GetModuleHandle('xr_3DA.exe');
    if xr3DA = 0 then exit;

    ptimestamp:= pcardinal(xr3DA + (pcardinal(xr3DA+$3C)^)+8);
    if ptimestamp^ = $47C577F6 then begin
      result:=FZ_VER_SOC_10006_V2;
    end else begin
      result:=FZ_VER_SOC_10006;
    end;

  end else if ver = '1.6.02' then begin
    result:=FZ_VER_COP_1602;
  end;
end;

class function FZGameVersionCreator.DetermineGameVersion: FZAbstractGameVersion;
begin
{$IFDEF TESTS}
  result:=FZTestGameVersion.Create();
{$ELSE}
  case GetGameVersion() of
    FZ_VER_CS_1510: result:=FZGameVersion1510.Create();
    FZ_VER_SOC_10006: result:=FZGameVersion10006.Create();
    FZ_VER_SOC_10006_V2: result:=FZGameVersion10006_v2.Create();
    FZ_VER_COP_1602: result:=FZGameVersion1602.Create();
  else
    result:=FZUnknownGameVersion.Create();
  end;
{$ENDIF}
end;


////////////////////////////////////////////////////////////////////////////////////
{Global area}
////////////////////////////////////////////////////////////////////////////////////
var
  _abstraction: FZAbstractGameVersion;

function VersionAbstraction: FZAbstractGameVersion;
begin
  result:=_abstraction;
end;

function Init():boolean; stdcall;
begin
  _abstraction:=FZGameVersionCreator.DetermineGameVersion();
  result:=true;
end;

procedure Free(); stdcall;
begin
  _abstraction.Free();
end;

end.

