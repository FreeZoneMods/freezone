unit RenderDevice;

{$mode delphi}

interface

uses
  BaseClasses, Synchro, Registration, Vector, statistics, MatVectors;

type
  CDeviceResetNotifier = packed record
    base_pureDeviceReset:pureDeviceReset;
  end;

  IRenderDeviceRender = packed record
    //todo: fill
  end;
  pIRenderDeviceRender = ^IRenderDeviceRender;

  CRenderDevice = packed record
    unknown:array[0..$113] of byte;
    b_is_Active:cardinal; //BOOL, +$114
    m_pRender:pIRenderDeviceRender;
    m_bNearer:cardinal; //BOOL
    seqRender:CRegistrator;
    seqAppActivate:CRegistrator;
    seqAppDeactivate:CRegistrator;
    seqAppStart:CRegistrator;
    seqAppEnd:CRegistrator;
    seqFrame:CRegistrator;
    seqFrameMT:CRegistrator;
    seqDeviceReset:CRegistrator;
    seqParallel:xr_vector;
    Statistic:pCStats;
    fTimeDelta:single;
    fTimeGlobal:single;
    dwTimeDelta:cardinal;
    dwTimeGlobal:cardinal;
    dwTimeContinual:cardinal;
    vCameraPosition:FVector3;
    vCameraDirection:FVEctor3;
    vCameraTop:FVector3;
    vCameraRight:FVector3;
    mView:FMatrix4x4;
    mProject:FMatrix4x4;
    mFullTransform:FMatrix4x4;
    mInvFullTransform:FMatrix4x4;
    fFOV:single;
    fASPECT:single;
    mt_csEnter:xrCriticalSection;//+$2FC
    mt_csLeave:xrCriticalSection;
    mt_bMustExit:cardinal; //BOOL
  end;
  pCRenderDevice = ^CRenderDevice;
function Init():boolean;

var
  pDevice:pCRenderDevice;
  g_pbRendering:pcardinal;

implementation
uses basedefs, windows;

function Init():boolean;
begin
  pDevice:=GetProcAddress(xrEngine,'?Device@@3VCRenderDevice@@A');
  g_pbRendering:=GetProcAddress(xrEngine, '?g_bRendering@@3HA');
  result:=(pDevice<>nil) and (g_pbRendering<>nil) ;
end;

end.

