unit clsids;

{$mode delphi}

interface
uses BaseClasses;

function Init():boolean;

var
  CLSID_OBJECT_PLAYERS_BAG:CLASS_ID;


implementation
uses xr_debug;

function MakeClassId(clsid:string):CLASS_ID;
var
  i:integer;
begin
  R_ASSERT(length(clsid)=sizeof(CLASS_ID), 'Invalid CLSID string "'+clsid+'"');
  for i:=0 to sizeof(CLASS_ID)-1 do begin
    PAnsiChar(@result)[i]:=clsid[sizeof(CLASS_ID)-i];
  end;
end;

function Init():boolean;
begin
  CLSID_OBJECT_PLAYERS_BAG:=MakeClassId('MP_PLBAG');

  result:=true;
end;

end.

