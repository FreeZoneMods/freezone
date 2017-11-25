library ModDllSample;

{$mode objfpc}{$H+}
uses srcCalls, windows;

var
  Log_fun:srcCdeclFunction;
  xrCore:cardinal;

const
  XRCORE_DLL:PAnsiChar='xrCore';

procedure ModLoad(mod_name:PAnsiChar; mod_params:PAnsiChar); stdcall;
begin
  xrCore:=LoadLibrary(XRCORE_DLL);
  Log_fun:=srcCdeclFunction.Create(pointer(xrCore+$16270), [vtPChar], 'Log');

  Log_fun.Call(['# Sample mod DLL loaded, modname '+mod_name]);
  FreeLibrary(xrCore);
end;

exports
  ModLoad;

begin
end.

