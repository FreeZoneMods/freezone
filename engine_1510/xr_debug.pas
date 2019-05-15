unit xr_debug;

{$mode delphi}
{$I _pathes.inc}

interface

procedure xr_assertion_fail(expression:PAnsiChar; filename:PAnsiChar; line:integer; functionname:PAnsiChar; ignore_always:boolean); stdcall;
procedure R_ASSERT(e:boolean; description:string; function_name:string = ''; filename: string = ''; line:integer = -1);


function Init():boolean; stdcall;

implementation
uses srcCalls, basedefs;

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
var
  tmp:pointer;
begin
  result:=false;
  tmp:=nil;

  if not InitSymbol(pxrDebug, xrCore, '?Debug@@3VxrDebug@@A') then exit;

  if not InitSymbol(tmp, xrCore, '?fail@xrDebug@@QAEXPBD0H0AA_N@Z') then exit;
  xrDebug__fail:=srcECXCallFunction.Create(tmp, [vtPointer, vtPChar, vtPChar, vtInteger, vtPChar, vtPointer], 'fail', 'xrDebug');

  result:=true;
end;

end.

