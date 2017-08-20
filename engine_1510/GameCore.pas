unit GameCore;

{$mode delphi}

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
uses basedefs, Windows;

function Init():boolean;
begin
  Core:=GetProcAddress(xrCore, '?Core@@3VxrCore@@A');
  result:=(Core<>nil);
end;

end.

