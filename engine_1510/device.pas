unit Device;

{$mode delphi}

interface
uses Windows, Time, Vector, Synchro, MatVectors;

type
CRegistrator = packed record
  R:xr_vector;
  flags:cardinal;
end;

CRenderDevice = packed record
  m_dwWindowStyle:cardinal;
  m_rcWindowBounds:TRECT;
  m_rcWindowClient:TRECT;
  Timer_MM_Delta:cardinal;
  Timer:CTimer_paused;
  TimerGlobal:CTimer_paused;
  TimerMM:CTimer;
  //Offset:0xF0
  m_hWnd:HWND;
  dwFrame:cardinal;
  dwPrecacheFrame:cardinal;
  dwPrecacheTotal:cardinal;
  dwWidth:cardinal;
  dwHeight:cardinal;
  fWidth_2:single;
  fHeight_2:single;
  //offset: 0x110
  b_is_Ready:cardinal;
  b_is_Active:cardinal;
  m_pRender:pointer; {IRenderDeviceRender*}
  m_bNearer:cardinal;
  //offset:0x120
  seqRender:CRegistrator; {<pureRender>}
  seqAppActivate:CRegistrator; {<pureAppActivate>}
  seqAppDeactivate:CRegistrator; {<pureAppDeactivate>}
  seqAppStart:CRegistrator; {<pureAppStart>}
  seqAppEnd:CRegistrator; {<pureAppEnd>}
  seqFrame:CRegistrator;  {<pureFrame>}
  seqFrameMT:CRegistrator; {<pureFrame>}
  seqDeviceReset:CRegistrator; {<pureDeviceReset>}
  //offset: 0x1A0
  seqParallel:xr_vector;
  Statistic:pointer; {CStats*}
  fTimeDelta:single;
  fTimeGlobal:single;
  dwTimeDelta:cardinal;
  dwTimeGlobal:cardinal;
  //offset:0x1C0
  dwTimeContinual:cardinal;
  vCameraPosition:FVector3;
  vCameraDirection:FVector3;
  vCameraTop:FVector3;
  vCameraRight:FVector3;
  mView:FMatrix4x4;
  mProject:FMatrix4x4;
  mFullTransform:FMatrix4x4;
  mInvFullTransform:FMatrix4x4;
  fFOV:single;
  fASPECT:single;
  mt_csEnter:xrCriticalSection;
  //offset:0x300
  mt_csLeave:xrCriticalSection;
  mt_bMustExit:cardinal;
end;
pCRenderDevice = ^CRenderDevice;

function Init():boolean;

function GetDevice():pCRenderDevice;

implementation
uses basedefs;

var
  g_pDevice:pCRenderDevice;

function GetDevice():pCRenderDevice;
begin
  result:=g_pDevice;
end;

function Init():boolean;
begin
  g_pDevice:=GetProcAddress(xrEngine,'?Device@@3VCRenderDevice@@A');
  result := g_pDevice<>nil;
end;

end.

