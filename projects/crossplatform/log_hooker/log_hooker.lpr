library log_hooker;

uses srcBase, srcInjections, windows;

function GetLogFunctionAddress():pointer;
const
  xrCore_name: PAnsiChar = 'xrCore.dll';
  msgFunName: PAnsiChar = '?Log@@YAXPBD@Z';
var
   xrCore_addr:HINST;
begin
  result:=nil;
  xrCore_addr:=GetModuleHandle(xrCore_name);
  if xrCore_addr=0 then exit;
  result:=GetProcAddress(xrCore_addr, msgFunName);
end;

procedure LogHook(msg:PAnsiChar); stdcall;
var
   f:textfile;
begin
  //Perform actions
  assignfile(f, 'test_log.log');
  append(f);
  writeln(f, msg);
  closefile(f);
end;

var
   injection_log:srcBaseInjection;

function SetLogHook():boolean;
var
   pLogFun:pointer;
begin
  if injection_log <> nil then begin
    if not injection_log.IsActive() then begin
      result:=injection_log.Enable();
    end else begin
      result:=true;
    end;
  end else begin
    result:=false;
    pLogFun:=GetLogFunctionAddress();
    if pLogFun = nil then exit;

    injection_log:=srcBaseInjection.Create(pLogFun, @LogHook, $0D, F_RMEM+F_PUSH_ESP+4, true, false);
    result:=injection_log.Enable();
  end;
end;

function Init():boolean; stdcall;
begin
  {$IFDEF RELEASE_BUILD}
    srcKit.Get.SwitchDebugMode(false);
    srcKit.Get.FullDbgLogStatus(false);
  {$ELSE}
    srcKit.Get.SwitchDebugMode(true);
    srcKit.Get.FullDbgLogStatus(true);
  {$ENDIF}

  result:=SetLogHook();
end;

exports
  Init;

begin
  injection_log := nil;
  if not Init() then begin
    MessageBox(0, 'Unexpected exception while initing Log Hooker!', 'ERROR!', MB_OK or MB_ICONERROR or MB_SYSTEMMODAL);
  end;
end.

