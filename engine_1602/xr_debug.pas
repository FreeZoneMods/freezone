unit xr_debug;

{$mode delphi}
{$I _pathes.inc}

interface

procedure xr_assertion_fail(expression:PAnsiChar; filename:PAnsiChar; line:integer; functionname:PAnsiChar; ignore_always:boolean); stdcall;
procedure R_ASSERT(e:boolean; description:string; function_name:string = ''; filename: string = ''; line:integer = -1);


function Init():boolean; stdcall;

implementation
uses srcCalls, windows, basedefs;

var
  xrDebug__fail:srcECXCallFunction;
  pxrDebug:pointer;

procedure xr_assertion_fail(expression:PAnsiChar; filename:PAnsiChar; line:integer; functionname:PAnsiChar; ignore_always:boolean); stdcall;
begin
  assert(pxrDebug <> nil);
  xrDebug__fail.Call([pxrDebug, expression, filename, line, functionname, @ignore_always]);
end;

procedure R_ASSERT(e:boolean; description:string; function_name:string; filename: string; line:integer);
begin
  if not e then begin
    if length(filename) = 0 then begin
      filename:='FreeZone';
    end;

    if length(description)=0  then begin
      description:='(no description)';
    end;

    xr_assertion_fail(PAnsiChar(description), PAnsiChar(filename), line, PAnsiChar(function_name), false);
  end;
end;

function Init():boolean; stdcall;
begin
  result:=false;
  pxrDebug := GetProcAddress(xrCore, '?Debug@@3VxrDebug@@A');
  xrDebug__fail:=srcECXCallFunction.Create(GetProcAddress(xrCore, '?fail@xrDebug@@QAEXPBD0H0AA_N@Z'), [vtPointer, vtPChar, vtPChar, vtInteger, vtPChar, vtPointer], 'fail', 'xrDebug');

  if (pxrDebug=nil) or (xrDebug__fail.GetMyAddress()=nil) then exit;
  result:=true;
end;

end.

