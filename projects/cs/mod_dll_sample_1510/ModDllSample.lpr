library ModDllSample;

{$mode objfpc}{$H+}
uses srcCalls, windows;

var
  Log_fun:srcCdeclFunction;
  xrCore:cardinal;

const
  XRCORE_DLL:PAnsiChar='xrCore';
  MSG_NAME:PAnsiChar='?Msg@@YAXPBDZZ';

type
  FZDllModFunResult = cardinal;

const
  FZ_DLL_MOD_FUN_SUCCESS_LOCK: cardinal = 0;    //Мод успешно загрузился, требуется залочить клиента по name_lock
  {%H-}FZ_DLL_MOD_FUN_SUCCESS_NOLOCK: cardinal = 1;  //Успех, лочить клиента (с использованием name_lock) пока не надо
  FZ_DLL_MOD_FUN_FAILURE: cardinal = 2;         //Ошибка загрузки мода

function ModLoad(mod_name:PAnsiChar; mod_params:PAnsiChar):FZDllModFunResult; stdcall;
var
  f:pointer;
begin
  result:=FZ_DLL_MOD_FUN_FAILURE;
  xrCore:=LoadLibrary(XRCORE_DLL);
  f:=GetProcAddress(xrCore, MSG_NAME);
  if f<>nil then begin
    Log_fun:=srcCdeclFunction.Create(f, [vtPChar], 'Msg');
    Log_fun.Call(['# Sample mod DLL loaded, modname '+mod_name+', modparams '+mod_params]);
    result:=FZ_DLL_MOD_FUN_SUCCESS_LOCK;
  end;
  FreeLibrary(xrCore);
end;

exports
  ModLoad;

begin
end.

