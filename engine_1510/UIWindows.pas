unit UIWindows;

{$mode delphi}
{$I _pathes.inc}

interface
uses Fonts, MatVectors, xrstrings;

type
  IUISimpleWindow = packed record
    vftable:cardinal;
  end;

  CUISimpleWindow = packed record
    base_IUISimpleWindow:IUISimpleWindow;
    m_bShowMe:byte; //bool
    unused1:byte;
    unused2:word;
    m_wndPos:Fvector2;
    m_wndSize:Fvector2;
    m_alignment:cardinal;
  end;

  CUIWindow = packed record
    base_CUISimpleWindow:CUISimpleWindow;
    m_windowName:shared_str;
    unknown1:array[0..8] of char; //here WINDOW_LIST m_ChildWndList; - pointers to 1st and last entries of the list?
    m_pParentWnd:^CUIWindow;
    m_pMouseCapturer:^CUIWindow;
    m_pOrignMouseCapturer:^CUIWindow;
    m_pKeyboardCapturer:^CUIWindow;
    m_pMessageTarget:^CUIWindow;
    m_pFont:pCGameFont;
    cursor_pos:FVector2;
    m_dwLastClickTime:cardinal;
    m_dwFocusReceiveTime:cardinal;
    m_bAutoDelete:byte; //bool
    m_bPP:byte; //bool
    m_bIsEnabled:byte; //bool
    m_bCursorOverWindow:byte;
    m_bClickable:byte; //bool
    m_bCustomDraw:byte; //bool
    unused:word;
  end;
  pCUIWindow=^CUIWindow;

  CUIMessageBox = packed record
    //todo:fill
  end;
  pCUIMessageBox=^CUIMessageBox;

implementation

end.

