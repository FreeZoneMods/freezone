unit GameSpySystem;

{$mode delphi}

interface
type
GHTTPRequest = cardinal;

CGameSpy_Available = packed record
  //todo:fill
end;
pCGameSpy_Available=^CGameSpy_Available;

CGameSpy_Patching = packed record
  //todo:fill
end;
pCGameSpy_Patching=^CGameSpy_Patching;

CGameSpy_HTTP = packed record
  m_hGameSpyDLL:cardinal;
  m_LastRequest:GHTTPRequest;
  ghttpStartup:procedure();cdecl;
  ghttpCleanup:procedure();cdecl;
  ghttpThink:procedure();cdecl;
  ghttpCancelRequest:procedure(request:GHTTPRequest); cdecl;
  ghttpSave:function( url:PAnsiChar; filename:PAnsiChar; blocking:cardinal; completedCallback:pointer; param:pointer ):cardinal; cdecl;
  ghttpSaveEx:function( url:PAnsiChar; filename:PAnsiChar; headers:PAnsiChar; post:pointer; throttle:cardinal; blocking:cardinal; progressCallback:pointer; completedCallback:pointer; param:pointer ):cardinal; cdecl;
  GetGameID:procedure(GameID:pinteger; verID:integer);cdecl;
end;
pCGameSpy_HTTP=^CGameSpy_HTTP;

CGameSpy_Browser = packed record
  //todo:fill
end;
pCGameSpy_Browser=^CGameSpy_Browser;

CGameSpy_Full = packed record
  m_hGameSpyDLL:cardinal;
  m_bServicesAlreadyChecked:byte; {bool}
  unused1:byte;
  unused2:word;
	m_pGSA:pCGameSpy_Available;
	m_pGS_Patching:pCGameSpy_Patching;
	m_pGS_HTTP:pCGameSpy_HTTP;
	m_pGS_SB:pCGameSpy_Browser;
  GetGameVersion:function(KeyValue:PChar):PChar; cdecl;
end;
pCGameSpy_Full=^CGameSpy_Full;

implementation

end.

