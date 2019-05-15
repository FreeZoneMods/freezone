unit GameCore;

{$mode delphi}
{$I _pathes.inc}

interface
uses xrstrings;

type
  xrCoreData = packed record
    ApplicationName:array[0..63] of char;
    ApplicationPath:string_path;
    WorkingPath:string_path;
    UserName:array[0..63] of char;
    CompName:array[0..63] of char;
    Params:array[0..511] of char;
  end;
  pxrCoreData = ^xrCoreData;

var
  Core:pxrCoreData;

function Init():boolean;

implementation
uses basedefs;

function Init():boolean;
begin
  result:=false;

  if not InitSymbol(Core, xrCore, '?Core@@3VxrCore@@A') then exit;

  result:=true;
end;

end.

