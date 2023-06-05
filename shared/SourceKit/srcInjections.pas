unit srcInjections;
{$mode delphi}
{$I _pathes.inc}

interface

type

{ srcBaseInjection }

srcBaseInjection = class
protected
  _patch_addr:pointer;                  //����� ����� � �����, �� �������� ���� �������� �� ������
  _ret_addr:pointer;                    //�����, ���� ���������� ��������� ����� ���������� ������
  _length:cardinal;                     //����� ����, �������� �����������
  _payload_addr:pointer;                //����� �������, ������� ���� �����������

  _code:array of byte;                  //����� � �������� ������
  _code_addr:pointer;

  _src_cut:array of byte;               //����� � ����������� ������������
  _src_cut_addr:pointer;

  _need_overwrite:boolean;              //��������� �������� ������� ���������� ��� ������ ��� ���
  _exec_srccode_in_end:boolean;         //��������� ������������ ��� �� ���� ������ ��� �����

  _is_active:boolean;
  _is_ok:boolean;

//  _remapable:boolean;


  function _SrcInit():boolean;
  function _AssembleInit(args:array of cardinal):boolean; virtual;

  //��������� ��� ��������
  function _WritePayloadCall(pos: pointer; args:array of cardinal): pointer; virtual;
  function _WriteBeforeSaveRegisters(addr:pointer):pointer; virtual;
  function _WriteAfterCall(addr:pointer):pointer; virtual;
  function _WriteAfterLoadRegisters(addr:pointer):pointer; virtual;
  function _WriteReturnJmp(addr:pointer):pointer;
  function _WriteSrcJmp(addr:pointer):pointer;
  function _WriteCodeJmp(addr:pointer):pointer;

  //������� ������ ������ ���� ������ payload
  function _GetPayloadCallerProjectedSize(args:array of cardinal):integer; virtual;

  //������� ���� ������ � ����� ����������� ����� ������� ������� payload'a ����������
  //���������� ��� ����������� ������� �������� ���������� ��� ������� � F_PUSH_ESP
  function _GetSavedInStackBytesCount():cardinal; virtual;

  //��������� ����� ������
  function _WriteRegisterArgs(pos:pointer; args:array of cardinal): pointer; virtual;
  function _WriteInjectionFinal(pos:pointer):pointer; virtual;

public
  constructor Create(addr:pointer; payload:pointer; count:cardinal; args:array of cardinal; exec_src_in_end:boolean=true; overwritten:boolean=false);
  destructor Destroy(); override;
  function IsActive():boolean;
  function Enable():boolean;
  procedure Disable();
  function GetSignature():string;
end;

srcCleanupInjection = class (srcBaseInjection)
  protected
  function _AssembleInit({%H-}args:array of cardinal):boolean; override;
  public
  constructor Create(addr:pointer; payload:pointer; count:cardinal);
  destructor Destroy; override;
end;

{ srcResultParserInjection }
srcResultParserInjection = class (srcBaseInjection)
  //����������: ������� ������� ������ ������� � �� ������
  protected
  _popcnt_from_stack:cardinal; //������� ���� ����� �� ����� ����� ���������� �������� - ���� �� ������, ���� ��������� ������ �������

  function _ParseResultFromStack(addr:pointer):pointer; virtual; abstract;

  function _WriteBeforeSaveRegisters(addr:pointer):pointer; override;
  function _WriteAfterCall(addr:pointer):pointer; override;
  function _WriteAfterLoadRegisters(addr:pointer):pointer; override;
  function _GetPayloadCallerProjectedSize(args:array of cardinal):integer; override;
  function _GetSavedInStackBytesCount():cardinal; override;

  public
  constructor Create(addr:pointer; payload:pointer; count:cardinal; args:array of cardinal; exec_src_in_end:boolean=true; overwritten:boolean=false; popcnt:cardinal=0);
end;

srcInjectionWithConditionalJump = class (srcResultParserInjection)
protected
  _jump_addr:pointer;
  _jump_type:word;
  function _GetPayloadCallerProjectedSize(args:array of cardinal):integer; override;
  function _ParseResultFromStack(addr:pointer):pointer; override;
public
  constructor Create(addr:pointer; payload:pointer {function (...):boolean; stdcall;}; count:cardinal; args:array of cardinal; jump_addr:pointer; jump_type:word; exec_src_in_end:boolean=true; overwritten:boolean=false);
end;

{ srcRegisterReturnerInjection }
srcRetRegType = (SRC_REG_EAX, SRC_REG_EBX, SRC_REG_ECX, SRC_REG_EDX, SRC_REG_EDI, SRC_REG_ESI, SRC_REG_EBP);
srcRegisterReturnerInjection = class (srcResultParserInjection)
protected
  _ret_reg_type:srcRetRegType;
  function _ParseResultFromStack(addr:pointer):pointer; override;
  function _GetPayloadCallerProjectedSize(args:array of cardinal):integer; override;
public
  constructor Create(addr:pointer; payload:pointer; count:cardinal; args:array of cardinal; register_type:srcRetRegType; exec_src_in_end:boolean=true; overwritten:boolean=false; popcnt:cardinal=0);
end;

{ srcEAXReturnerInjection }

srcEAXReturnerInjection = class(srcRegisterReturnerInjection)
public
  constructor Create(addr:pointer; payload:pointer; count:cardinal; args:array of cardinal; exec_src_in_end:boolean=true; overwritten:boolean=false; popcnt:cardinal=0);
end;

{ srcEBXReturnerInjection }

srcEBXReturnerInjection = class(srcRegisterReturnerInjection)
public
  constructor Create(addr:pointer; payload:pointer; count:cardinal; args:array of cardinal; exec_src_in_end:boolean=true; overwritten:boolean=false; popcnt:cardinal=0);
end;

{ srcECXReturnerInjection }

srcECXReturnerInjection = class(srcRegisterReturnerInjection)
public
  constructor Create(addr:pointer; payload:pointer; count:cardinal; args:array of cardinal; exec_src_in_end:boolean=true; overwritten:boolean=false; popcnt:cardinal=0);
end;

{ srcEDXReturnerInjection }

srcEDXReturnerInjection = class(srcRegisterReturnerInjection)
public
  constructor Create(addr:pointer; payload:pointer; count:cardinal; args:array of cardinal; exec_src_in_end:boolean=true; overwritten:boolean=false; popcnt:cardinal=0);
end;

{ srcESIReturnerInjection }

srcESIReturnerInjection = class(srcRegisterReturnerInjection)
public
  constructor Create(addr:pointer; payload:pointer; count:cardinal; args:array of cardinal; exec_src_in_end:boolean=true; overwritten:boolean=false; popcnt:cardinal=0);
end;

{ srcEDIReturnerInjection }

srcEDIReturnerInjection = class(srcRegisterReturnerInjection)
public
  constructor Create(addr:pointer; payload:pointer; count:cardinal; args:array of cardinal; exec_src_in_end:boolean=true; overwritten:boolean=false; popcnt:cardinal=0);
end;

{ srcEBPReturnerInjection }

srcEBPReturnerInjection = class(srcRegisterReturnerInjection)
public
  constructor Create(addr:pointer; payload:pointer; count:cardinal; args:array of cardinal; exec_src_in_end:boolean=true; overwritten:boolean=false; popcnt:cardinal=0);
end;

const
  JUMP_IF_TRUE  :     byte = $84;
  JUMP_IF_FALSE :     byte = $85;

implementation
uses Windows, sysutils, srcBase;

{ srcBaseInjection }

procedure srcBaseInjection.Disable();
begin
  if (not self._is_ok) or (not self._is_active) then begin
    if srcKit.Get.IsDebug then srcKit.Get.DbgLog('injection '+GetSignature+': already was disabled');
    exit;
  end;
  SrcKit.CopyASM(self._src_cut_addr, self._patch_addr, self._length);
  self._is_active:=false;
  if srcKit.Get.IsDebug then srcKit.Get.DbgLog('injection '+GetSignature+': disabled.');
end;

function srcBaseInjection.Enable(): boolean;
begin

  result:=false;
  if (not self._is_ok) then begin
    if srcKit.Get.IsDebug then srcKit.Get.DbgLog('injection '+GetSignature+': isok = false, cannot enable', true);
    exit;
  end;

  if self._is_active then begin
    if srcKit.Get.IsDebug then srcKit.Get.DbgLog('injection '+GetSignature+': already active, cannot enable!');
    exit;
  end;

  if (self._length<5) then begin
    if srcKit.Get.IsDebug then srcKit.Get.DbgLog('injection '+GetSignature+': not enough bytes to write jump, cannot enable!', true);
    self._is_ok:=false;
    exit;
  end;

  srcKit.nop_code(self._patch_addr, self._length);
  //���� ������� ��������� ��������� ��� ������ - �� ����� ����� �� ���, ����� - �� ����� � ���� �����
  if (self._need_overwrite) or self._exec_srccode_in_end then begin
    if srcKit.Get.IsDebug then srcKit.Get.DbgLog('injection '+GetSignature+': patching to _code done');
    if srcKit.WriteCall(self._patch_addr, self._code_addr, false)=nil then exit;
  end else begin
    if srcKit.WriteCall(self._patch_addr, self._src_cut_addr, false)=nil then exit;
    if srcKit.Get.IsDebug then srcKit.Get.DbgLog('injection '+GetSignature+': pacthing to _src_cut done');
  end;
  self._is_active:=true;
  result:=true;
end;

constructor srcBaseInjection.Create(addr: pointer; payload: pointer;
  count: cardinal; args: array of cardinal; exec_src_in_end: boolean;
  overwritten: boolean);
begin
  //TODO:������� ��������������� ������������ ����� ����, ��������� ��� ���������� ������ �� ���������� ������ (������ �� ������������� ����������)
  self._patch_addr:=addr;
  self._length:=count;
  self._ret_addr:=pointer(cardinal(addr)+count);
  self._payload_addr:=payload;
  self._need_overwrite:=overwritten;
  self._exec_srccode_in_end:=exec_src_in_end;

  if srcKit.Get.IsDebug then begin
    srcKit.Get.DbgLog('new injection '+GetSignature+' (payload: '+inttohex(cardinal(payload), 8) +')');
    srcKit.Get.DbgLog('injection '+GetSignature+
                      ': length='+inttostr(self._length)+
                      ', overwrite='+booltostr(self._need_overwrite, true)+
                      ', in end='+booltostr(self._exec_srccode_in_end, true));
  end;


  _is_ok:= self._SrcInit() and self._AssembleInit(args);

  self._is_active:=false;

  if srcKit.Get.IsDebug then srcKit.Get.DbgLog('injection '+GetSignature+': initialization finished, isok = '+booltostr(self._is_ok, true));
  srcKit.Get.RegisterInjection(self);
end;

function srcBaseInjection.IsActive(): boolean;
begin
  result:=self._is_active;
end;

function srcBaseInjection._SrcInit(): boolean;
begin
  //������� ����� � ���������� ������������ �����
  result:=false;

  setlength(self._src_cut, self._length+6);                   //�� �������� ��� �������

  _src_cut_addr:=@(self._src_cut[0]);
  srcKit.Get().MakeExecutable(_src_cut_addr, length(self._src_cut));

  if srcKit.Get.IsDebug then srcKit.Get.DbgLog('injection '+GetSignature+': srcbuf = '+inttohex(cardinal(_src_cut_addr), 8));
  if not srcKit.CopyASM(self._patch_addr, @self._src_cut[0], self._length) then exit; //�������� ������������ ���
  
  if self._exec_srccode_in_end then begin
    if self._WriteReturnJmp(@(self._src_cut[self._length])) = nil then exit;
  end else begin
    if self._WriteCodeJmp(@(self._src_cut[self._length])) = nil then exit;
  end;
  result:=true;
end;

function srcBaseInjection._AssembleInit(args:array of cardinal):boolean;
var
  sz, totalsz:cardinal;
  pos:pointer;
begin
  result:=false;
  //TODO: ������� ����������� ����, ��� ������, ����� �������� ������� (��������� ���� ���-> ������������������ ����������, ���� �������� � �������� ����������)
  //������ ������ - �������� ����� � ����� ������

  //��������� ��������� ������ ������
  sz:=_GetPayloadCallerProjectedSize(args);


  setlength(self._code, sz);
  srcKit.MakeExecutable(@self._code[0], sz);
  _code_addr:=@(self._code[0]);
  if srcKit.Get.IsDebug then srcKit.Get.DbgLog('injection '+GetSignature+': codebuf='+inttohex(cardinal(_code_addr),8));

  pos:=_code_addr;
  //�������� ��� ������

  //TODO:��������� � ���, ��� ����� ���������� payload � ������ ���������

  pos:=self._WritePayloadCall(pos, args);
  if pos = nil then begin
    if srcKit.Get.IsDebug then srcKit.Get.DbgLog('injection '+GetSignature+': payload not written!', true);
    exit;
  end;


  pos:=self._WriteInjectionFinal(pos);
  if pos = nil then begin
    if srcKit.Get.IsDebug then srcKit.Get.DbgLog('injection '+GetSignature+': final not written!', true);
    exit;
  end;

  totalsz:=uintptr(pos) - uintptr(@(self._code[0]));
  if totalsz > sz then begin
    if srcKit.Get.IsDebug then srcKit.Get.DbgLog('injection '+GetSignature+': code buffer overflow! Need '+inttostr(totalsz)+' bytes, size '+inttostr(sz)+' bytes', true);
    halt;
  end else begin
    if srcKit.Get.IsDebug then srcKit.Get.DbgLog('injection '+GetSignature+': code uses '+inttostr(totalsz)+' bytes from '+inttostr(sz)+' bytes', false);
  end;

  result:=true;
end;

destructor srcBaseInjection.Destroy();
begin
  if srcKit.Get.IsDebug then srcKit.Get.DbgLog('injection '+GetSignature+': Destroying.');
  self.Disable;
  setlength(self._src_cut, 0);
  setlength(self._code, 0);
  inherited;
end;

function srcBaseInjection._WriteCodeJmp(addr: pointer): pointer;
begin
  result:=srcKit.WriteMemCall(addr, @self._code_addr, false);
end;

function srcBaseInjection._WriteBeforeSaveRegisters(addr: pointer): pointer;
begin
  result:=addr;
end;

function srcBaseInjection._WriteAfterCall(addr: pointer): pointer;
begin
  result:=addr;
end;

function srcBaseInjection._WriteAfterLoadRegisters(addr: pointer): pointer;
begin
  result:=addr;
end;

function srcBaseInjection._WritePayloadCall(pos: pointer; args:array of cardinal): pointer;
begin
  result:=pos;

  if result<>nil then result:=self._WriteBeforeSaveRegisters(result);
  if result<>nil then result:=srcKit.WriteSaveRegisters(result);
  if result<>nil then result:=self._WriteRegisterArgs(result, args);
  if result<>nil then result:=srcKit.WriteMemCall(result, @self._payload_addr, true);
  if result<>nil then result:=self._WriteAfterCall(result);
  if result<>nil then result:=srcKit.WriteLoadRegisters(result);
  if result<>nil then result:=self._WriteAfterLoadRegisters(result);
end;

function srcBaseInjection._WriteReturnJmp(addr: pointer): pointer;
begin
  result:=srcKit.WriteMemCall(addr, @self._ret_addr, false);
end;

function srcBaseInjection._WriteSrcJmp(addr: pointer): pointer;
begin
  result:=srcKit.WriteMemCall(addr, @self._src_cut_addr, false);
end;

function srcBaseInjection._WriteRegisterArgs(pos: pointer; args:array of cardinal): pointer;
var
  i:integer;
  tmp:cardinal;  
  tmpi:integer;
  esp_add:cardinal;
const
  MASK_POSITIVE_SIGN:cardinal = $00800000;
  
begin
  esp_add:=0; //���� � ���� ����� ���������� ��������� �� ����� - ����� ������� �������� ��������������� �������� �������� 
  for i:=high(args) downto low(args) do begin
    srcKit.Get.DbgLog(inttohex(args[i],8));
    //�������, �� ��������� �� ���� �������� � �������
    if (args[i] and $0F000000)=0 then begin
      //� ������� � ���������� �� ��������
      tmp:=args[i] shr 29;
      PByte(pos)^:=PUSH_EAX+tmp;
      pos:=PAnsiChar(pos)+1;

      //���������/��������� �������� ��������� �� ��������
      tmpi:=(args[i] and $00FFFFFF)-MASK_POSITIVE_SIGN;
      if (tmp{%H-}{%H-}=PUSH_ESP-PUSH_EAX) then tmpi:=tmpi{%H-}+_GetSavedInStackBytesCount()+esp_add;
      srcKit.Get.DbgLog('tmpi='+inttostr(tmpi));
      if tmpi<>0 then begin
        //add [esp], XXXXX
        PCardinal(pos)^:=$240481; //������� 3 �����, � �� 4!!! �� ������� �����
        pos:=PAnsiChar(pos)+3;
        PCardinal(pos)^:=tmpi;
        pos:=PAnsiChar(pos)+4;
      end;
      esp_add:=esp_add+4;

    end else if (args[i] and F_RMEM)<>0 then begin
      //push [reg+offset]
      tmp:=args[i] shr 29;
      if (args[i] and $F0000000)<>(F_PUSH_ESP-F_MEMOFFSET) then begin
        srcKit.Get.DbgLog('not esp');
        PWord(pos)^:=$B0FF+(tmp shl 8);
        pos:=PAnsiChar(pos)+2;
        PCardinal(pos)^:= (args[i] and $00FFFFFF)-MASK_POSITIVE_SIGN;
        pos:=PAnsiChar(pos)+4;
        esp_add:=esp_add+4;

      end else begin
        srcKit.Get.DbgLog('esp');
        PCardinal(pos)^:=$0024B4FF;
        pos:=PAnsiChar(pos)+3;
        PCardinal(pos)^:= (args[i] and $00FFFFFF)-MASK_POSITIVE_SIGN+_GetSavedInStackBytesCount()+esp_add; //�� �������� ��� pushad
        pos:=PAnsiChar(pos)+4;
        esp_add:=esp_add+4;
      end;

    end else if (args[i] and (F_PUSHCONST-F_MEMOFFSET))<>0 then begin
      //push const
      pos:=srcKit.WritePushDword(pos, args[i]-F_PUSHCONST);
      esp_add:=esp_add+4;
    end;

  end;
  result:=pos;
end;

function srcBaseInjection._WriteInjectionFinal(pos: pointer): pointer;
begin
  if (not self._need_overwrite) and self._exec_srccode_in_end then begin
    pos:=self._WriteSrcJmp(pos);
  end else begin
    pos:=self._WriteReturnJmp(pos);
  end;
  result:=pos;
end;

function srcBaseInjection.GetSignature(): string;
begin
  result:= self.ClassName+':@'+inttohex(cardinal(self._patch_addr),8);
end;

function srcBaseInjection._GetPayloadCallerProjectedSize(args:array of cardinal): integer;
var
  argcnt:integer;
const
  PUSHAD_SIZE = 1;
  PUSHFD_SIZE = 1;
  CALL_SIZE = 6;
  POPFD_SIZE = 1;
  POPAD_SIZE = 1;
  JUMPBACK_SIZE = 6;
  MAX_PUSH_ARGUMENT_SIZE = 8;
begin
  argcnt:=high(args)-low(args)+1;
  result:=PUSHAD_SIZE+PUSHFD_SIZE+MAX_PUSH_ARGUMENT_SIZE*argcnt+CALL_SIZE+POPFD_SIZE+POPAD_SIZE+JUMPBACK_SIZE;
end;

function srcBaseInjection._GetSavedInStackBytesCount(): cardinal;
const
  PUSHAD_STACK_COUNT = $20;
  PUSHFD_STACK_COUNT = 4;
begin
  result:=PUSHAD_STACK_COUNT+PUSHFD_STACK_COUNT;
end;

{ srcCleanupInjection }
var
  _CleanupCode: array [0..19] of byte;
  _cleanup_instance:srcCleanupInjection = nil;

function srcCleanupInjection._AssembleInit(args:array of cardinal): boolean;
var
  pos:pointer;
const
  sz:cardinal=20;
begin
  result:=false;

  setlength(self._code, sz);
  srcKit.MakeExecutable(@self._code[0], sz);
  _code_addr:=@(_CleanupCode[0]);
  if srcKit.Get.IsDebug then srcKit.Get.DbgLog('cleanup injection '+GetSignature+': codebuf='+inttohex(cardinal(_code_addr),8));

  pos:=srcKit.WriteSaveRegisters(self._code_addr);

  pos:=srcKit.WriteCall(pos, self._payload_addr, true);
  if pos=nil then begin
    if srcKit.Get.IsDebug then srcKit.Get.DbgLog('cleanup injection '+GetSignature+': payload not written!', true);
    exit;
  end;

  pos:=srcKit.WriteLoadRegisters(pos);
  pos:=srcKit.WriteCall(pos, self._ret_addr, false);
  if pos=nil then begin
    if srcKit.Get.IsDebug then srcKit.Get.DbgLog('cleanup injection '+GetSignature+': return not written!', true);
    exit;
  end;
  if srcKit.Get.IsDebug() then srcKit.Get.DbgLog('cleanup injection '+GetSignature+': used '+inttostr(cardinal(pos)-cardinal(self._code_addr))+' bytes of code');
  if (cardinal(pos)-cardinal(self._code_addr))>20 then begin
    if srcKit.Get.IsDebug then srcKit.Get.DbgLog('cleanup injection '+GetSignature+': code buffer overflow!', true);
    exit;
  end;
  result:=true;
end;

constructor srcCleanupInjection.Create(addr, payload: pointer;
  count: cardinal);
begin
  //����������� ������� �������� ����������� � ���, ��� ����� ����������� �������� ����� � ����� ������ �����������, �� �� ���� ����� ��������� ����� ��������
  //�� ������ �� ������ ��������� � ��������� ������
  //������� �������� - ������ ����������� ������ � ���������� ����������� ������, ��� � ����������� � ������ ������

  //������ ������ ������ ����������� � ������������ ����������!
  if _cleanup_instance<>nil then begin
    if srcKit.Get.IsDebug then srcKit.Get.DbgLog('cleanup injection '+GetSignature+': failed to create second cleanup!', true);
    exit;
  end;

  //����� - �������� ��� ������ ������ ����������� ����� ����� ������, ��� ��� ��� ��������� � ����������� ���������� ������; ����� ���������� ���� ������ � ����������� ������� ���������� � ���� ������ ������
  inherited Create(addr, payload, count, [], false, false);

  _cleanup_instance := self;
end;

destructor srcCleanupInjection.Destroy;
begin
  _cleanup_instance:=nil;
  inherited;
end;

{ srcResultParserInjection }

constructor srcResultParserInjection.Create(addr: pointer; payload: pointer; count: cardinal; args: array of cardinal; exec_src_in_end: boolean; overwritten: boolean; popcnt: cardinal);
begin
  self._popcnt_from_stack:=popcnt;
  inherited Create(addr, payload, count, args, exec_src_in_end, overwritten);
end;

function srcResultParserInjection._WriteBeforeSaveRegisters(addr: pointer): pointer;
begin
  //��������� � ����� �����, � ������� ����� ������� ��������� ������ �������
  (PByte(addr))^:=PUSH_EAX;
  addr:=pointer(cardinal(addr)+1);

  result:=addr;
end;

function srcResultParserInjection._WriteAfterCall(addr: pointer): pointer;
var
  stacksz:integer;
begin
  //�������-������ ���� ������� � ������� ���-�� � EAX; �������� ��� � �����
  stacksz:=inherited _GetSavedInStackBytesCount();
  //mov [esp-stacksz], eax
  (PWord(addr))^:=$8489;
  addr:=pointer(cardinal(addr)+2);
  (PByte(addr))^:=$24;
  addr:=pointer(cardinal(addr)+1);
  (PInteger(addr))^:=stacksz;
  addr:=pointer(cardinal(addr)+4);

  result:=addr;
end;

function srcResultParserInjection._WriteAfterLoadRegisters(addr: pointer): pointer;
begin
  //��������������� ��������� �� �����
  addr:=_ParseResultFromStack(addr);

  //������� ������ �� �����
  if _popcnt_from_stack > 0 then begin
    addr:=srcKit.WriteAddESPDword(addr, _popcnt_from_stack);
  end;

  result:=addr;
end;

function srcResultParserInjection._GetPayloadCallerProjectedSize(args: array of cardinal): integer;
const
  WRITE_BEFORE_SAVE_REG_SIZE = 1;
  WRITE_AFTER_CALL_SIZE = 7;
  RESTORE_FUN_REGS_SIZE = 6;
begin
  result:=inherited _GetPayloadCallerProjectedSize(args);
  result:=result+WRITE_BEFORE_SAVE_REG_SIZE+WRITE_AFTER_CALL_SIZE;
  if _popcnt_from_stack > 0 then begin
    result:=result+RESTORE_FUN_REGS_SIZE;
  end;
end;

function srcResultParserInjection._GetSavedInStackBytesCount(): cardinal;
const
  STACK_BUFFER_SIZE = 4;
begin
  Result:=inherited _GetSavedInStackBytesCount();
  result:=result+STACK_BUFFER_SIZE;
end;

{ srcRegisterReturnerInjection }
constructor srcRegisterReturnerInjection.Create(addr: pointer; payload: pointer; count: cardinal; args: array of cardinal; register_type: srcRetRegType; exec_src_in_end: boolean; overwritten: boolean; popcnt: cardinal);
begin
  //������������ ���� ������ ����� ������� �������� ������������, �.�. � ������� ���������� ��������� � ������ ��������
  _ret_reg_type:=register_type;
  inherited Create(addr, payload, count, args, exec_src_in_end, overwritten, popcnt);
end;

function srcRegisterReturnerInjection._ParseResultFromStack(addr: pointer): pointer;
var
  opcode:byte;
begin
  case _ret_reg_type of
    SRC_REG_EAX: opcode:=POP_EAX;
    SRC_REG_EBX: opcode:=POP_EBX;
    SRC_REG_ECX: opcode:=POP_ECX;
    SRC_REG_EDX: opcode:=POP_EDX;
    SRC_REG_ESI: opcode:=POP_ESI;
    SRC_REG_EDI: opcode:=POP_EDI;
    SRC_REG_EBP: opcode:=POP_EBP;
  else
    srcKit.Get.DbgLog('srcRegisterReturnerInjection._ParseResultFromStack: Unknown register type '+inttostr(integer(_ret_reg_type)), true);
    halt();
  end;
  (PByte(addr))^:=opcode;
  addr:=pointer(cardinal(addr)+1);
  result:=addr;
end;

function srcRegisterReturnerInjection._GetPayloadCallerProjectedSize(args: array of cardinal): integer;
const
  RESTORE_FROM_STACK_SIZE = 1;
begin
  result:=inherited _GetPayloadCallerProjectedSize(args);
  result:=result+RESTORE_FROM_STACK_SIZE;
end;

{ srcInjectionWithConditionalJump }
constructor srcInjectionWithConditionalJump.Create(addr: pointer; payload: pointer; count: cardinal; args: array of cardinal; jump_addr: pointer; jump_type: word; exec_src_in_end: boolean; overwritten: boolean);
begin
  self._jump_addr:=jump_addr;
  self._jump_type:=jump_type;
  inherited Create(addr,payload,count,args,exec_src_in_end,overwritten);
end;

function srcInjectionWithConditionalJump._GetPayloadCallerProjectedSize(args: array of cardinal): integer;
const
  XCHG_SZ = 3;
  TEST_SZ = 2;
  POP_SZ = 1;
  JUMPS_SZ = 12;
begin
  result:=inherited _GetPayloadCallerProjectedSize(args);
  result:=result+XCHG_SZ+TEST_SZ+POP_SZ+JUMPS_SZ;
end;

function srcInjectionWithConditionalJump._ParseResultFromStack(addr: pointer): pointer;
begin

  (PCardinal(addr))^:=XCHG_EAX_MEM_ESP;
  addr:=pointer(cardinal(addr)+3);

  addr:=srcKit.WriteTestReg(addr, TEST_AL_AL);

  (PByte(addr))^:=POP_EAX;
  addr:=pointer(cardinal(addr)+1);

  addr:=srcKit.WriteMemConditionalJump(addr, @self._jump_addr, _jump_type);

  result:=addr;
end;

{ srcEAXReturnerInjection }
constructor srcEAXReturnerInjection.Create(addr: pointer; payload: pointer; count: cardinal; args: array of cardinal; exec_src_in_end: boolean; overwritten: boolean; popcnt: cardinal);
begin
  inherited Create(addr, payload, count, args, SRC_REG_EAX, exec_src_in_end, overwritten, popcnt);
end;

{ srcEBXReturnerInjection }
constructor srcEBXReturnerInjection.Create(addr: pointer; payload: pointer; count: cardinal; args: array of cardinal; exec_src_in_end: boolean; overwritten: boolean; popcnt: cardinal);
begin
  inherited Create(addr, payload, count, args, SRC_REG_EBX, exec_src_in_end, overwritten, popcnt);
end;

{ srcECXReturnerInjection }
constructor srcECXReturnerInjection.Create(addr: pointer; payload: pointer; count: cardinal; args: array of cardinal; exec_src_in_end: boolean; overwritten: boolean; popcnt: cardinal);
begin
  inherited Create(addr, payload, count, args, SRC_REG_ECX, exec_src_in_end, overwritten, popcnt);
end;

{ srcEDXReturnerInjection }
constructor srcEDXReturnerInjection.Create(addr: pointer; payload: pointer; count: cardinal; args: array of cardinal; exec_src_in_end: boolean; overwritten: boolean; popcnt: cardinal);
begin
  inherited Create(addr, payload, count, args, SRC_REG_EDX, exec_src_in_end, overwritten, popcnt);
end;

{ srcESIReturnerInjection }
constructor srcESIReturnerInjection.Create(addr: pointer; payload: pointer; count: cardinal; args: array of cardinal; exec_src_in_end: boolean; overwritten: boolean; popcnt: cardinal);
begin
  inherited Create(addr, payload, count, args, SRC_REG_ESI, exec_src_in_end, overwritten, popcnt);
end;

{ srcEDIReturnerInjection }
constructor srcEDIReturnerInjection.Create(addr: pointer; payload: pointer; count: cardinal; args: array of cardinal; exec_src_in_end: boolean; overwritten: boolean; popcnt: cardinal);
begin
  inherited Create(addr, payload, count, args, SRC_REG_EDI, exec_src_in_end, overwritten, popcnt);
end;

{ srcEBPReturnerInjection }
constructor srcEBPReturnerInjection.Create(addr: pointer; payload: pointer; count: cardinal; args: array of cardinal; exec_src_in_end: boolean; overwritten: boolean; popcnt: cardinal);
begin
  inherited Create(addr, payload, count, args, SRC_REG_EBP, exec_src_in_end, overwritten, popcnt);
end;

end.
