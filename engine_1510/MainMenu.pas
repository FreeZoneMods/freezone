unit MainMenu;

{$mode delphi}
{$I _pathes.inc}

interface
uses
  xrstrings, Vector, GameSpySystem, srcCalls, BaseClasses, Device, UI;

type
  Patch_Dawnload_Progress = packed record
    IsInProgress:cardinal; {BOOL}
    Progress:single;
    Status:shared_str;
    FileName:shared_str;
  end;

  IMainMenu = packed record
    vftable:pointer;
  end;
  pIMainMenu=^IMainMenu;

  CMainMenu = packed record
    base_IMainMenu:IMainMenu;
    base_IInputReceiver:IInputReceiver;
    base_pureRender:pureRender;
    base_CDialogHolder:CDialogHolder;
    base_CUIWndCallback:CUIWndCallback;
    base_CDeviceResetNotifier:CDeviceResetNotifier;

    m_startDialog:pCUIDialogWnd;
    m_Flags:cardinal;
    m_screenshot_name:string_path;
    m_screenshotFrame:cardinal;
    m_pp_draw_wnds:xr_vector; {CUIWindow*}

    m_pGameSpyFull:pCGameSpy_Full;
    m_sPDProgress:Patch_Dawnload_Progress; //+$278
    m_NeedErrDialog:cardinal;
    m_start_time:cardinal;
    m_sPatchURL:shared_str;
    m_sPatchFileName:shared_str;
    m_downloaded_mp_map_url:shared_str;
    m_player_name:shared_str;
    m_cdkey:shared_str;
    m_pMB_ErrDlgs:xr_vector;
    //to be continued
  end;
  pCMainMenu=^CMainMenu;

const
  CMainMenu_EErrorDlg_ErrInvalidPassword:cardinal = 0;
  CMainMenu_EErrorDlg_ErrInvalidHost:cardinal = 1;
  CMainMenu_EErrorDlg_ErrSessionFull:cardinal = 2;
  CMainMenu_EErrorDlg_ErrServerReject:cardinal = 3;
  CMainMenu_EErrorDlg_ErrCDKeyInUse:cardinal =4;
  CMainMenu_EErrorDlg_ErrCDKeyDisabled:cardinal =5;
  CMainMenu_EErrorDlg_ErrCDKeyInvalid:cardinal =6;
  CMainMenu_EErrorDlg_ErrDifferentVersion:cardinal =7;
  CMainMenu_EErrorDlg_ErrGSServiceFailed:cardinal =8;
  CMainMenu_EErrorDlg_ErrMasterServerConnectFailed:cardinal =9;
  CMainMenu_EErrorDlg_NoNewPatch:cardinal =10;
  CMainMenu_EErrorDlg_NewPatchFound:cardinal =11;
  CMainMenu_EErrorDlg_PatchDownloadError:cardinal =12;
  CMainMenu_EErrorDlg_PatchDownloadSuccess:cardinal =13;
  CMainMenu_EErrorDlg_ConnectToMasterServer:cardinal =14;
  CMainMenu_EErrorDlg_SessionTerminate:cardinal =15;
  CMainMenu_EErrorDlg_LoadingError:cardinal =16;
  CMainMenu_EErrorDlg_DownloadMPMap:cardinal =17;
  CMainMenu_EErrorDlg_ErrMax:cardinal =18;
  CMainMenu_EErrorDlg_ErrNoError:cardinal =18;

var
  virtual_IMainMenu__Activate:srcVirtualECXCallFunction;

function Init():boolean;

implementation

function Init():boolean;
const
  IMainMenu__Activate_index:cardinal=$4;
begin
  virtual_IMainMenu__Activate:=srcVirtualECXCallFunction.Create(IMainMenu__Activate_index, [vtPointer, vtBoolean], 'IMainMenu', 'Activate');
  result:=true;
end;

end.

