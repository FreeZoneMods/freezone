unit MapList;

{$mode delphi}

interface
uses xrstrings, Vector;

type
SGameWeathers = record
  m_weather_name:shared_str;
  m_start_time:shared_str;
end;

SGameTypeMaps_SMapItm = record
	map_name:shared_str;
  map_ver:shared_str;
end;
pSGameTypeMaps_SMapItm=^SGameTypeMaps_SMapItm;

SGameTypeMaps = record
  m_game_type_name:shared_str;
  m_game_type_id:cardinal; {EGameIDs}
  m_map_names:xr_vector;{SGameTypeMaps_SMapItm}
end;
pSGameTypeMaps = ^SGameTypeMaps;

CMapListHelper = record
  m_storage:xr_vector; {SGameTypeMaps}
  m_weathers:xr_vector; {SGameWeathers}
end;
pCMapListHelper=^CMapListHelper;


function Init():boolean; stdcall;
function GetMapList():pCMapListHelper; stdcall;
procedure LoadMapList(); stdcall;

implementation
uses basedefs, srcCalls;
var
  g_pMapListHelper:pCMapListHelper;
  CMapListHelper__Load:srcBaseFunction;

function GetMapList():pCMapListHelper; stdcall;
begin
  result:=g_pMapListHelper;
end;

procedure LoadMapList(); stdcall;
begin
  CMapListHelper__Load.Call([]);
end;

function Init():boolean; stdcall;
begin
  if xrGameDllType()=XRGAME_SV_1510 then begin
    g_pMapListHelper:=pointer(xrGame+$5e99c0);
    CMapListHelper__Load := srcBaseFunction.Create(pointer(xrGame+$469240),[], 'Load', 'CMapListHelper');
  end else if xrGameDllType()=XRGAME_CL_1510 then begin
    g_pMapListHelper:=pointer(xrGame+$606ac0);
    CMapListHelper__Load := srcBaseFunction.Create(pointer(xrGame+$47F630),[], 'Load', 'CMapListHelper');
  end;
  result:=true;
end;

end.

