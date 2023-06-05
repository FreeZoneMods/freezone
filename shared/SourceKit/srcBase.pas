unit srcBase;
{$mode delphi}
{$I _pathes.inc}

interface
uses srcInjectMgr, srcLogging, srcInjections, srcFunctionsMgr, srcCalls;

type

{ srcKit }

 srcKit = class
private
  _log:srcLog;
  _srcdebug: boolean;
  _fulllog:boolean;
  _injector: srcInjector;
  _functions: srcFunMgr;
  {%H-}constructor Create();
  procedure _Cleanup();

public
  procedure DbgLog(text:string; IsError:boolean = false);stdcall;
  procedure SwitchDebugMode(status:boolean);
  procedure FullDbgLogStatus(status:boolean);
  function IsDebug:boolean;
  procedure RegisterInjection(injection:srcBaseInjection);
  procedure RegisterFunction(f:srcBaseFunction);
  procedure InjectAll();
  class function Get():srcKit;
  class procedure Finish;
  destructor Destroy(); override;
  procedure EngineCall(args:array of const; name:string; visibility:string='global');
  function FindEngineCall(name:string; visibility:string='global'):srcBaseFunction; stdcall;

  class function CopyBuf(src, dst: pointer; cnt: cardinal): boolean;
  class function CopyASM(src:pointer; dst:pointer; cnt:cardinal):boolean;
  class function WriteCall(patch_addr:pointer; dest_addr:pointer; write_call:boolean = true):pointer;
  class function WriteMemCall(patch_addr:pointer; var_addr:pointer; write_call:boolean = true):pointer;
  class function WriteConditionalJump(patch_addr, to_addr: pointer; jmptype:byte):pointer;
  class function WriteMemConditionalJump(patch_addr, var_addr: pointer; jmptype:byte):pointer;

  class function MakeExecutable(addr:pointer; sz:cardinal):boolean;

  class function nop_code(addr:pointer; count:cardinal; opcode:char=CHR($90)):boolean;
  class function WriteSaveRegisters(pos:pointer):pointer;
  class function WriteLoadRegisters(pos:pointer):pointer;
  class function WriteSaveOnlyGeneralRegisters(pos:pointer):pointer;
  class function WriteLoadOnlyGeneralRegisters(pos:pointer):pointer;
  class function WritePushDword(pos:pointer; val:cardinal):pointer;
  class function WriteTestReg(pos:pointer; test_type:word):pointer;
  class function WriteWordInstruction(pos:pointer; instruction:word):pointer;
  class function WriteAddESPDword(pos:pointer; val:cardinal):pointer;
  class function LowLevelCall(func:pointer):cardinal; stdcall;
end;

const
  PUSHAD            :byte   =$60;
  POPAD             :byte   =$61;
  PUSHFD            :byte   =$9C;
  POPFD             :byte   =$9D;

  PUSH_EAX          :byte   =$50;
  PUSH_ECX          :byte   =$51;
  PUSH_EDX          :byte   =$52;
  PUSH_EBX          :byte   =$53;
  PUSH_ESP          :byte   =$54;
  PUSH_EBP          :byte   =$55;
  PUSH_ESI          :byte   =$56;
  PUSH_EDI          :byte   =$57;
  PUSH_DWORD        :byte   =$68;

  POP_EAX           :byte   =$58;
  POP_ECX           :byte   =$59;
  POP_EDX           :byte   =$5A;
  POP_EBX           :byte   =$5B;
  POP_ESP           :byte   =$5C;
  POP_EBP           :byte   =$5D;
  POP_ESI           :byte   =$5E;
  POP_EDI           :byte   =$5F;          

  RET               :byte   =$C3;
  ADD_ESP_DWORD     :word   =$C481;
  MOV_EAX_DWORD     :byte   =$B8;  
  MOV_ECX_DWORD     :byte   =$B9;
  MOV_EDX_DWORD     :byte   =$BA;
  MOV_EBX_DWORD     :byte   =$BB;
  MOV_ESI_DWORD     :byte   =$BE;
  MOV_EDI_DWORD     :byte   =$BF;

  CALL_RELATIVE     :byte   =$E8;
  JMP_RELATIVE      :byte   =$E9;


//маски регистров для передачи параметров инъекциям  
  F_PUSH_EAX    :     cardinal = $00800000;
  F_PUSH_ECX    :     cardinal = $20800000;
  F_PUSH_EDX    :     cardinal = $40800000;
  F_PUSH_EBX    :     cardinal = $60800000;
  F_PUSH_ESP    :     cardinal = $80800000;
  F_PUSH_EBP    :     cardinal = $A0800000;
  F_PUSH_ESI    :     cardinal = $C0800000;
  F_PUSH_EDI    :     cardinal = $E0800000;

  F_PUSHCONST   :     cardinal = $02800000;
  F_RMEM        :     cardinal = $01000000;
  F_MEMOFFSET   :     cardinal = $00800000;

//виды условных переходов
  JUMPTYPE_JE   :     byte = $84;
  JUMPTYPE_JNE  :     byte = $85;
  JUMPTYPE_JAE  :     byte = $83;
  JUMPTYPE_JBE  :     byte = $86;

//маски тестирования
  TEST_EAX_EAX  :     word = $C085;
  TEST_AL_AL  :     word = $C084; 

  XCHG_EAX_MEM_ESP : cardinal = $90240487;

implementation
uses windows, sysutils;

var
  _instance:srcKit = nil;

{ srcKit }

constructor srcKit.Create;
begin
  inherited Create();
  _injector:=nil;
  _functions:=nil;
  _log:=nil;
  _srcdebug:=false;
  _fulllog:=true;
end;

procedure srcKit.DbgLog(text: string; IsError: boolean); stdcall;
begin
  if not IsDebug then exit;
  if not _fulllog and not IsError then exit;
  if self._log=nil then self._log:=srcLog.Create('SourceKit Debug Log', 'srcLog.log', true);
  _log.Write(text, IsError);
end;


destructor srcKit.Destroy;
begin
  self._Cleanup();
  _instance:=nil;
  inherited;
end;

procedure srcKit._Cleanup;
begin
  self._injector.Free;
  //функции после врезок!
  self._functions.Free;

  self._log.Free;
end;

class function srcKit.Get: srcKit;
begin
  if _instance=nil then _instance:=srcKit.Create;
  result:=_instance
end;

procedure srcKit.InjectAll;
begin
  if self._injector<>nil then self._injector.InjectAll();
end;

function srcKit.IsDebug: boolean;
begin
  result:=_srcdebug;
end;

procedure srcKit.RegisterInjection(injection: srcBaseInjection);
begin
  if self._injector= nil then self._injector:=srcInjector.Create;
  self._injector.RegisterInjection(injection);
end;

procedure srcKit.SwitchDebugMode(status: boolean);
begin
  self._srcdebug:=status;
end;

class procedure srcKit.Finish;
begin
  _instance.Free;
  _instance:=nil;
end;

class function srcKit.CopyBuf(src, dst: pointer; cnt: cardinal): boolean;
var
  rb, oldprot, oldprot2:cardinal;
begin
  rb:=0; //suppress warning
  oldprot:=0;
  result:=false;

  if not VirtualProtect(dst, cnt, PAGE_EXECUTE_READWRITE, oldprot) then exit;
  WriteProcessMemory(GetCurrentProcess, dst, src, cnt, rb);
  if not VirtualProtect(dst, cnt, oldprot, oldprot2) then exit;

  result:=(cnt=rb);
end;

class function srcKit.CopyASM(src: pointer; dst: pointer; cnt: cardinal): boolean;
var
  offset, target_addr:cardinal;
  cmd:byte;
begin
  result:=false;

  if cnt=0 then begin
    result:=true;
    exit;
  end;

  cmd:=pByte(src)^;
  if (cmd = JMP_RELATIVE) or (cmd = CALL_RELATIVE) then begin
    if cnt < 5 then exit;
    cnt:=cnt-5;

    src:=src+1;
    offset:=PCardinal(src)^;
    src:=src+4;
    target_addr:=cardinal(src)+offset;
    offset:= target_addr-cardinal(dst)-5;

    result:=CopyBuf(@cmd, dst, sizeof(cmd));
    dst:=dst+1;
    if result then result:=CopyBuf(@offset, dst, sizeof(offset));
    dst:=dst+4;

    if result then result:=CopyASM(src, dst, cnt);
  end else begin;
    result:=CopyBuf(src, dst, cnt);
  end;
  //TODO:прикрутить анализатор ассемблерного листинга, автоматом пересчитывающий адреса call'ов и проверяющий, что не перезаписываются "куски" команд
end;

class function srcKit.nop_code(addr: pointer; count: cardinal; opcode:char=CHR($90)): boolean;
var rb:cardinal;
    i:cardinal;
begin
  result:=false;
  rb:=0;
  for i:=0 to count-1 do begin
    WriteProcessMemory(GetCurrentProcess(), @PAnsiChar(uintptr(addr))[i], @opcode, 1, rb);
    if rb<>1 then exit;
  end;
  result:=true;
end;

class function srcKit.WriteCall(patch_addr: pointer; dest_addr: pointer;
  write_call: boolean): pointer;
var
  offsettowrite:pointer;
  rb:cardinal;
  opcode:char;
begin
  result:=nil;
  rb:=0;
  if write_call then opcode:=CHR(CALL_RELATIVE) else opcode:=CHR(JMP_RELATIVE);
  offsettowrite:=pointer(uintptr(dest_addr)-uintptr(patch_addr)-5);       //относительный адрес места, в которое произойдет переход
  writeprocessmemory(GetCurrentProcess(), patch_addr, @opcode, 1, rb);
  if rb<>1 then exit;
  writeprocessmemory(GetCurrentProcess(), pointer(uintptr(patch_addr)+1), @offsettowrite, 4, rb);
  if rb<>4 then exit;
  result:=pointer(uintptr(patch_addr)+5);
end;

class function srcKit.WriteMemCall(patch_addr: pointer; var_addr: pointer;
  write_call: boolean): pointer;
var
  rb:cardinal;
  opcode:array [0..1] of byte;
begin
  result:=nil;
  rb:=0;

  opcode[0]:=$FF;
  if write_call then opcode[1]:=$15 else opcode[1]:=$25;

  writeprocessmemory(GetCurrentProcess(), patch_addr, @(opcode[0]), 2, rb);
  if rb<>2 then exit;

  writeprocessmemory(GetCurrentProcess(), pointer(uintptr(patch_addr)+2), @var_addr, 4, rb);
  if rb<>4 then exit;
  result:=pointer(uintptr(patch_addr)+6);
end;

class function srcKit.WriteLoadRegisters(pos: pointer): pointer;
begin
  (PByte(pos))^:=POPFD;
  pos:=pointer(uintptr(pos)+1);
  (PByte(pos))^:=POPAD;
  pos:=pointer(uintptr(pos)+1);
  result:=pos;
end;

class function srcKit.WriteSaveRegisters(pos: pointer): pointer;
begin
  (PByte(pos))^:=PUSHAD;
  pos:=pointer(uintptr(pos)+1);
  (PByte(pos))^:=PUSHFD;
  pos:=pointer(uintptr(pos)+1);
  result:=pos;
end;

class function srcKit.LowLevelCall(func: pointer): cardinal; stdcall;
begin
  {$asmmode intel}
  asm
     call func
     mov @result, eax
  end;
end;

class function srcKit.WritePushDword(pos: pointer; val: cardinal): pointer;
begin
  (PByte(pos))^:=PUSH_DWORD;
  pos:=pointer(uintptr(pos)+1);
  (PCardinal(pos))^:=val;
  pos:=pointer(uintptr(pos)+4);
  result:=pos;
end;

class function srcKit.WriteAddESPDword(pos: pointer; val: cardinal): pointer;
begin
  (PWord(pos))^:=ADD_ESP_DWORD;
  pos:=pointer(uintptr(pos)+2);
  (PCardinal(pos))^:=val;
  pos:=pointer(uintptr(pos)+4);
  result:=pos;
end;

procedure srcKit.FullDbgLogStatus(status: boolean);
begin
  self._fulllog:=status;
end;

procedure srcKit.RegisterFunction(f: srcBaseFunction);
begin
  if self._functions=nil then self._functions:=srcFunMgr.Create();
  _functions.RegisterFunction(f);
end;

procedure srcKit.EngineCall(args: array of const; name: string;
  visibility: string);
begin
  self._functions.CallByName(args, name, visibility);
end;

class function srcKit.WriteConditionalJump(patch_addr, to_addr: pointer;
  jmptype: byte): pointer;
var
  rb:cardinal;
  opcode:array [0..1] of byte;
  offsettowrite:pointer;
begin
  result:=nil;
  rb:=0;

  opcode[0]:=$0F;
  opcode[1]:=jmptype;

  writeprocessmemory(GetCurrentProcess(), patch_addr, @(opcode[0]), 2, rb);
  if rb<>2 then exit;

  offsettowrite:=pointer(uintptr(to_addr)-uintptr(patch_addr)-6);       //относительный адрес места, в которое произойдет переход
  writeprocessmemory(GetCurrentProcess(), pointer(uintptr(patch_addr)+2), @offsettowrite, 4, rb);
  if rb<>4 then exit;
  result:=pointer(uintptr(patch_addr)+6);
end;

class function srcKit.WriteTestReg(pos: pointer; test_type:word): pointer;
begin
  result:=WriteWordInstruction(pos, test_type);
end;

class function srcKit.WriteWordInstruction(pos: pointer; instruction: word): pointer;
begin
  (PWord(pos))^:=instruction;
  pos:=pointer(uintptr(pos)+sizeof(instruction));
  result:=pos;
end;

class function srcKit.WriteLoadOnlyGeneralRegisters(pos: pointer): pointer;
begin
  (PByte(pos))^:=POPAD;
  pos:=pointer(uintptr(pos)+1);
  result:=pos;
end;

class function srcKit.WriteSaveOnlyGeneralRegisters(pos: pointer): pointer;
begin
  (PByte(pos))^:=PUSHAD;
  pos:=pointer(uintptr(pos)+1);
  result:=pos;
end;

class function srcKit.WriteMemConditionalJump(patch_addr,
  var_addr: pointer; jmptype: byte): pointer;
begin
{общий вид получаемой конструкции:
 jxx @nojmp
   jmp [var_addr]
 @nojmp:}

  result:=WriteConditionalJump(patch_addr, pointer(uintptr(patch_addr)+12), jmptype);
  if result<>nil then result:=WriteMemCall(result, var_addr, false);

end;

class function srcKit.MakeExecutable(addr: pointer; sz: cardinal): boolean;
var
  oldprotect:cardinal;
begin
  oldprotect:=0;
  result:=(VirtualProtect(addr, sz, PAGE_EXECUTE_READWRITE, oldprotect));
  if srcKit.Get.IsDebug then srcKit.Get.DbgLog('MakeExecutable 0x'+inttohex(uintptr(addr), 2*sizeof(addr))+', size '+inttostr(sz)+' bytes, result '+booltostr(result, true));
end;

function srcKit.FindEngineCall(name: string; visibility: string): srcBaseFunction; stdcall;
begin
  result:=nil;
  self._functions.SearchByName(result, name, visibility);
end;

end.
