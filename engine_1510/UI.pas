unit UI;

{$mode delphi}

interface

uses BaseClasses, Vector, Schedule, UIWindows, srcCalls;

type
  CDialogHolder = packed record
    base_IScheduled:IScheduled;
    base_pureFrame:pureFrame;
    m_input_receivers:xr_vector;
    m_dialogsToRender:xr_vector;
    m_dialogsToRender_new:xr_vector;
    m_b_in_update:byte; {boolean}
    unused1:byte;
    unused2:word;
  end;
  pCDialogHolder=^CDialogHolder;

  CUIWndCallback = packed record
    vftable:pointer;
    m_callbacks:xr_vector;
  end;

  CUIDialogWnd = packed record
    base_CUIWindow:CUIWindow;
    m_pHolder:pCDialogHolder;
    m_bWorkInPause:byte; //bool
    unused1:byte;
    unused2:word;
  end;
  pCUIDialogWnd = ^CUIDialogWnd;

  CUIMessageBoxEx = packed record
    base_CUIDialogWnd:CUIDialogWnd;
    base_CUIWndCallback:CUIWndCallback;
    m_pMessageBox:pCUIMessageBox;
  end;
  pCUIMessageBoxEx=^CUIMessageBoxEx;

const
  CUIDialogWnd_Dispatch_index:cardinal=$A4;

var
  virtual_CUIDialogWnd__Dispatch:srcVirtualECXCallFunction;

function Init():boolean;

implementation

function Init():boolean;
begin
  virtual_CUIDialogWnd__Dispatch:=srcVirtualECXCallFunction.Create(CUIDialogWnd_Dispatch_index, [vtPointer, vtInteger, vtInteger], 'CUIDialogWnd', 'Dispatch');
  result:=true;
end;

end.

