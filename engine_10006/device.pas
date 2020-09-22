unit Device;

{$mode delphi}
{$I _pathes.inc}

interface
uses Windows, xr_time, Vector, Synchro, MatVectors, Statistics, BaseClasses;

type
CRegistrator = packed record
  R:xr_vector;
  flags:cardinal;
end;

CGammaControl = packed record
  fGamma:single;
  fBrightness:single;
  fContrast:single;
	cBalance:Fcolor;
end;

CRenderDevice = packed record
  m_dwWindowStyle:cardinal;
  m_rcWindowBounds:TRECT;
  m_rcWindowClient:TRECT;
  Timer_MM_Delta:cardinal;
  //Offset:0x28
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
  //offset:0x110
  b_is_Ready:cardinal;
  b_is_Active:cardinal;
  m_WireShader:pointer; //ref_shader
  m_SelectionShader:pointer; //ref_shader
  m_bNearer:cardinal;
  //offset: 0x124
  seqRender:CRegistrator; {<pureRender>}
  seqAppActivate:CRegistrator; {<pureAppActivate>}
  seqAppDeactivate:CRegistrator; {<pureAppDeactivate>}
  seqAppStart:CRegistrator; {<pureAppStart>}
  seqAppEnd:CRegistrator; {<pureAppEnd>}
  seqFrame:CRegistrator;  {<pureFrame>}
  seqFrameMT:CRegistrator; {<pureFrame>}
  seqDeviceReset:CRegistrator; {<pureDeviceReset>}
  //offset: 0x1C4
  seqParallel:xr_vector;

  Resources:pointer; //CResourceManager
  Statistic:pCStats;
  Gamma:CGammaControl;
  //offset:0x1F8
  fTimeDelta:single;
  fTimeGlobal:single;
  dwTimeDelta:cardinal;
  dwTimeGlobal:cardinal;
  dwTimeContinual:cardinal;

  //offset:0x20C
  vCameraPosition:FVector3;
  vCameraDirection:FVector3;
  vCameraTop:FVector3;
  vCameraRight:FVector3;
  mView:FMatrix4x4;
  mProject:FMatrix4x4;
  mFullTransform:FMatrix4x4;
  mInvFullTransform:FMatrix4x4;
  //offset:0x33C
  fFOV:single;
  fASPECT:single;

  mt_csEnter:xrCriticalSection;
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
  g_pbRendering:pcardinal;

function GetDevice():pCRenderDevice;
begin
  result:=g_pDevice;
end;

function Init():boolean;
begin
  result:=false;
  if not InitSymbol(g_pDevice, xrEngine, '?Device@@3VCRenderDevice@@A') then exit;
  if not InitSymbol(g_pbRendering, xrEngine, '?g_bRendering@@3HA') then exit;
  result:=true;
end;

end.

