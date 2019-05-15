unit srcCalls;
{$mode delphi}
{$I _pathes.inc}

interface

type

srcBaseFunction = class
  private
    function _CheckTypeCompatibility(got, expected: byte): boolean;
protected
  _addr:pointer;
  _argc:cardinal;             //число аргументов, предполагаются DWORD'ы
  _types:array of byte;       //сюда занесем типы параметров

  _name:string;
  _visibility:string;

  _isok:boolean;

  function _ArgsInit(args:array of const; pos:pointer):pointer; virtual;
  function _AssembleWrapper(pos:pointer; args:array of const):pointer; virtual;
  function _WriteCallInstruction(pos:pointer; {%H-}args:array of const):pointer; virtual;
public
  constructor Create(addr:pointer; args:array of const; name:string='unnamed'; visibility:string='global');
  destructor Destroy(); override;
  function AsFloat(args:array of const):single;
  function Call(args:array of const):TVarRec; virtual;
  function GetMyAddress():pointer;
  function GetSignature():string;
  function IsItMe(name:string; visibility:string):boolean;
end;

srcCdeclFunction = class(srcBaseFunction)
  protected
  function _AssembleWrapper(pos:pointer; args:array of const):pointer; override;
end;

{ srcECXCallFunction }

srcECXCallFunction = class(srcBaseFunction)
  protected
  _to_reg_move_opcode:byte;
  _non_stack_args_count:byte;
  function _ArgsInit(args:array of const; pos:pointer):pointer; override;
  public
  constructor Create(addr:pointer; args:array of const; name:string='unnamed'; visibility:string='global');
end;

{ srcECXCallFunctionWEDIArg }

srcECXCallFunctionWEDIArg = class(srcECXCallFunction)
  protected
  _to_second_reg_move_opcode:byte;
  function _ArgsInit(args:array of const; pos:pointer):pointer; override;
  public
  constructor Create(addr:pointer; args:array of const; name:string='unnamed'; visibility:string='global');
end;

{ srcECXCallFunctionWEBXEDIArg }

srcECXCallFunctionWEBXEDIArg = class(srcECXCallFunction)
  protected
  _to_second_reg_move_opcode:byte;
  _to_third_reg_move_opcode:byte;
  function _ArgsInit(args:array of const; pos:pointer):pointer; override;
  public
  constructor Create(addr:pointer; args:array of const; name:string='unnamed'; visibility:string='global');
end;

{ srcECXCallFunctionWEDXArg }

srcECXCallFunctionWEDXArg = class(srcECXCallFunctionWEDIArg)
public
  constructor Create(addr:pointer; args:array of const; name:string='unnamed'; visibility:string='global');
end;

{ srcESICallFunction }

srcESICallFunction = class(srcECXCallFunction)
public
  constructor Create(addr:pointer; args:array of const; name:string='unnamed'; visibility:string='global');
end;

{ srcEAXCallFunction }

srcEAXCallFunction = class(srcECXCallFunction)
public
  constructor Create(addr:pointer; args:array of const; name:string='unnamed'; visibility:string='global');
end;

{ srcEDICallFunction }

srcEDICallFunction = class(srcECXCallFunction)
public
  constructor Create(addr:pointer; args:array of const; name:string='unnamed'; visibility:string='global');
end;

{ srcVirtualECXCallFunction }
srcVirtualECXCallFunction = class(srcECXCallFunction)
protected
  _vftable_offset:cardinal;
  function _WriteCallInstruction(pos:pointer; args:array of const):pointer; override;
public
  constructor Create(vftable_offset:cardinal; args:array of const; name:string='unnamed'; visibility:string='global');
end;

srcESICallFunctionWEAXArg = class(srcBaseFunction)
protected
  _mov_this_to_arg_opcode:byte;

  function _ArgsInit(args:array of const; pos:pointer):pointer; override;
public
  constructor Create(addr:pointer; args:array of const; name:string='unnamed'; visibility:string='global');
end;

{ srcEDXCallFunctionWEAXArg }

srcEDXCallFunctionWEAXArg = class(srcESICallFunctionWEAXArg)
public
  constructor Create(addr:pointer; args:array of const; name:string='unnamed'; visibility:string='global');
end;

srcVirtualBaseFunction = class(srcBaseFunction)
protected
  _vftable_offset:cardinal;
  function _WriteCallInstruction(pos:pointer; args:array of const):pointer; override;
public
  constructor Create(vftable_offset:cardinal; args:array of const; name:string='unnamed'; visibility:string='global');

end;

implementation
uses srcBase, sysutils;

{ srcESICallFunction }

constructor srcESICallFunction.Create(addr: pointer; args: array of const; name: string; visibility: string);
begin
  inherited;
  _to_reg_move_opcode:=MOV_ESI_DWORD;
end;

{ srcEAXCallFunction }

constructor srcEAXCallFunction.Create(addr: pointer; args: array of const; name: string; visibility: string);
begin
  inherited;
  _to_reg_move_opcode:=MOV_EAX_DWORD;
end;

{ srcEDICallFunction }

constructor srcEDICallFunction.Create(addr: pointer; args: array of const; name: string; visibility: string);
begin
  inherited;
  _to_reg_move_opcode:=MOV_EDI_DWORD;
end;

{ srcBaseFunction }

function srcBaseFunction.AsFloat(args: array of const): single;
var
  tmp:cardinal;
begin
  result:=0;
  tmp:=cardinal(self.Call(args).VInteger);
  Move(tmp, result, sizeof(result));
end;

function srcBaseFunction.Call(args: array of const): TVarRec;
var
  code:array of byte;
  i:integer;
begin
  result.VInteger:=0;
  if not self._isok then begin
    if srcKit.Get.IsDebug() then srcKit.Get.DbgLog(GetSignature + ': isok=false!', true);
    exit;
  end;

  if cardinal(high(args)-low(args)+1)<>self._argc then begin
    if srcKit.Get.IsDebug() then srcKit.Get.DbgLog(GetSignature + ': arguments count mismatch! Expected '+inttostr(self._argc)+', got '+inttostr(cardinal(high(args)-low(args)+1)), true);
    exit;
  end;

  //контроль типов аргументов
  for i:=low(args) to high(args) do begin
    if not self._CheckTypeCompatibility(args[i].VType, self._types[i-low(args)]) then begin
      if srcKit.Get.IsDebug() then srcKit.Get.DbgLog(GetSignature + ': type mismatch in argument #'+inttostr(i-low(args)+1)+'! Expected '+inttostr(self._types[i-low(args)])+', got '+inttostr(args[i].VType), true);
      exit;
    end;
  end;

  setlength(code, 5*self._argc+100); //TODO:посчитать размер "в граммах"
  srcKit.MakeExecutable(@code[0], 5*self._argc+100);
  try
    if srcKit.Get.IsDebug() then srcKit.Get.DbgLog(GetSignature + ': calling, assembled wrapper at address @'+inttohex(uintptr(@code[0]),8));

    _AssembleWrapper(@code[0], args);

    result.VInteger:=integer(srcKit.LowLevelCall(@code[0]));

    if srcKit.Get.IsDebug() then srcKit.Get.DbgLog(GetSignature + ': result='+inttohex(result.VInteger, 8));
  finally
    setlength(code, 0);
  end;
end;

constructor srcBaseFunction.Create(addr:pointer; args:array of const; name:string='unnamed'; visibility:string='global');
var
  i:integer;
begin
  self._addr:=addr;
  self._argc:=high(args)-low(args)+1;
  setlength(self._types, self._argc);
  for i:=0 to self._argc-1 do begin
    self._types[i]:=byte(args[low(args)+i].VInteger);
  end;
  self._name:=name;
  self._visibility:=visibility;
  _isok:=true;
  if srcKit.Get.IsDebug then srcKit.Get.DbgLog(GetSignature+' created!');
  srcKit.Get.RegisterFunction(self);
end;

destructor srcBaseFunction.Destroy;
begin
  if srcKit.Get.IsDebug() then srcKit.Get.DbgLog(GetSignature + ': Destroying');
  setlength(self._types, 0);
  inherited;
end;

function srcBaseFunction.GetMyAddress: pointer;
begin
  result:=self._addr;
end;

function srcBaseFunction.GetSignature: string;
begin
  result:=self._visibility+'::'+self._name+' (@'+inttohex(uintptr(self._addr), 8)+')';
end;

function srcBaseFunction.IsItMe(name, visibility: string): boolean;
begin
  result:= (self._visibility=visibility) and (self._name=name);
end;

function srcBaseFunction._ArgsInit(args: array of const; pos: pointer):pointer;
var
  i:integer;
  val:cardinal;
begin
  for i:= high(args) downto low(args) do begin
    if args[i].VType=vtString then begin
      if srcKit.Get.IsDebug() then srcKit.Get.DbgLog(GetSignature + ': str arg #'+inttostr(i)+' is '+inttohex(uintptr(PAnsiChar(args[i].VString)), 8), false);
      pos:=srcKit.WritePushDword(pos, uintptr(PAnsiChar(args[i].VString)))
    end else if args[i].VType = vtBoolean then begin
      if srcKit.Get.IsDebug() then srcKit.Get.DbgLog(GetSignature + ': bool arg #'+inttostr(i)+' is '+booltostr(args[i].VBoolean, true), false);
      if (args[i].VBoolean) then begin
        pos:=srcKit.WritePushDword(pos, 1);
      end else begin
        pos:=srcKit.WritePushDword(pos, 0);
      end;
    end else begin
      val:=cardinal(args[i].VInteger);
      if srcKit.Get.IsDebug() then srcKit.Get.DbgLog(GetSignature + ': arg #'+inttostr(i)+' is '+inttohex(val, 8), false);
      pos:=srcKit.WritePushDword(pos, val)
    end;
  end;
  result:=pos;
end;

function srcBaseFunction._AssembleWrapper(pos: pointer; args:array of const): pointer;
begin
  (PByte(pos))^:=PUSH_EAX;        //сюда будем писать резалт
  pos:=pointer(uintptr(pos)+1);
  pos:=srcKit.WriteSaveRegisters(pos);
  pos:=_ArgsInit(args, pos);
  pos:=_WriteCallInstruction(pos, args);
  (PCardinal(pos))^:=$24244489; //mov [esp+$24], eax
  pos:=pointer(uintptr(pos)+4);
  pos:=srcKit.WriteLoadRegisters(pos);
  (PByte(pos))^:=POP_EAX;       //результат выполнения функции
  pos:=pointer(uintptr(pos)+1);
  (PByte(pos))^:=RET;
  pos:=pointer(uintptr(pos)+1);
  result:=pos;
end;

function srcBaseFunction._CheckTypeCompatibility(got, expected: byte): boolean;
begin
  if got=expected then begin
    result:=true;
  end else if (got=vtPChar) and (expected=vtAnsiString) then begin
    result:=true;
  end else if (got=vtAnsiString) and (expected=vtPChar) then begin
    result:=true;
  end else if (got=vtString) and (expected=vtPChar) then begin
    result:=true;
  end else if (got=vtString) and (expected=vtAnsiString) then begin
    result:=true;
  end else if (got=vtObject) and (expected=vtPointer) then begin
    result:=true;
  end else begin
    result:=false;
  end;
end;

function srcBaseFunction._WriteCallInstruction(pos: pointer; args:array of const): pointer;
begin
  result:=srcKit.WriteMemCall(pos, @self._addr, true);
end;

{ srcCdeclFunction }

function srcCdeclFunction._AssembleWrapper(pos: pointer;
  args: array of const): pointer;
begin
  (PByte(pos))^:=PUSH_EAX;        //сюда будем писать резалт
  pos:=pointer(uintptr(pos)+1);
  pos:=srcKit.WriteSaveRegisters(pos);
  pos:=_ArgsInit(args, pos);
  pos:=_WriteCallInstruction(pos, args);
  if self._argc>0 then pos:=srcKit.Get.WriteAddESPDword(pos, 4*self._argc);  //снимаем со стека лишнее

  (PCardinal(pos))^:=$24244489; //mov [esp+$24], eax
  pos:=pointer(uintptr(pos)+4);

  pos:=srcKit.WriteLoadRegisters(pos);
  (PByte(pos))^:=POP_EAX;       //результат выполнения функции
  pos:=pointer(uintptr(pos)+1);
  (PByte(pos))^:=RET;
  pos:=pointer(uintptr(pos)+1);
  result:=pos;
end;

{ srcECXCallFunction }

constructor srcECXCallFunction.Create(addr: pointer; args: array of const; name: string; visibility: string);
begin
  inherited;
  _to_reg_move_opcode:=MOV_ECX_DWORD;
  _non_stack_args_count:=1;
  if (self._argc<1) then begin
    if srcKit.Get.IsDebug() then srcKit.Get.DbgLog(GetSignature + ': first argument MUST have pointer type!', true);
    self._isok:=false;
  end;
end;

function srcECXCallFunction._ArgsInit(args: array of const; pos: pointer): pointer;
var
  i:integer;
  val:cardinal;
begin
  for i:= high(args) downto low(args)+_non_stack_args_count do begin
    if args[i].VType=vtString then begin
      if srcKit.Get.IsDebug() then srcKit.Get.DbgLog(GetSignature + ': str arg #'+inttostr(i)+' is '+inttohex(uintptr(PAnsiChar(args[i].VString)), 8), false);
      pos:=srcKit.WritePushDword(pos, uintptr(PAnsiChar(args[i].VString)));
    end else if args[i].VType = vtBoolean then begin
      if srcKit.Get.IsDebug() then srcKit.Get.DbgLog(GetSignature + ': bool arg #'+inttostr(i)+' is '+booltostr(args[i].VBoolean, true), false);
      if (args[i].VBoolean) then begin
        pos:=srcKit.WritePushDword(pos, 1);
      end else begin
        pos:=srcKit.WritePushDword(pos, 0);
      end;
    end else begin
      val:=cardinal(args[i].VInteger);
      if srcKit.Get.IsDebug() then srcKit.Get.DbgLog(GetSignature + ': arg #'+inttostr(i)+' is '+inttohex(val, 8), false);
      pos:=srcKit.WritePushDword(pos, val);
    end;
  end;
  (PByte(pos))^:=_to_reg_move_opcode;
  pos:=pointer(uintptr(pos)+1);
  (PCardinal(pos))^:=cardinal(args[low(args)].VInteger);
  pos:=pointer(uintptr(pos)+4);
  result:=pos;
end;

{ srcECXCallFunctionWEDIArg }
constructor srcECXCallFunctionWEDIArg.Create(addr: pointer; args: array of const; name: string; visibility: string);
begin
  inherited;
  _non_stack_args_count:=2;
  _to_second_reg_move_opcode:=MOV_EDI_DWORD;
  if (self._argc<2) then begin
    if srcKit.Get.IsDebug() then srcKit.Get.DbgLog(GetSignature + ': second argument MUST present!', true);
    self._isok:=false;
  end;
end;

function srcECXCallFunctionWEDIArg._ArgsInit(args: array of const; pos: pointer): pointer;
begin
  pos:=inherited;
  (PByte(pos))^:=_to_second_reg_move_opcode;
  pos:=pointer(uintptr(pos)+1);
  (PCardinal(pos))^:=cardinal(args[low(args)+1].VInteger);
  pos:=pointer(uintptr(pos)+4);
  result:=pos;
end;

{ srcECXCallFunctionWEBXEDIArg }

constructor srcECXCallFunctionWEBXEDIArg.Create(addr: pointer; args: array of const; name: string; visibility: string);
begin
  inherited;
  _non_stack_args_count:=3;
  _to_second_reg_move_opcode:=MOV_EBX_DWORD;
  _to_third_reg_move_opcode:=MOV_EDI_DWORD;
  if (self._argc<3) then begin
    if srcKit.Get.IsDebug() then srcKit.Get.DbgLog(GetSignature + ': wnd and 3rd arguments MUST present!', true);
    self._isok:=false;
  end;
end;

function srcECXCallFunctionWEBXEDIArg._ArgsInit(args: array of const; pos: pointer): pointer;
begin
  pos:=inherited;
  (PByte(pos))^:=_to_second_reg_move_opcode;
  pos:=pointer(uintptr(pos)+1);
  (PCardinal(pos))^:=cardinal(args[low(args)+1].VInteger);
  pos:=pointer(uintptr(pos)+4);

  (PByte(pos))^:=_to_third_reg_move_opcode;
  pos:=pointer(uintptr(pos)+1);
  (PCardinal(pos))^:=cardinal(args[low(args)+2].VInteger);
  pos:=pointer(uintptr(pos)+4);

  result:=pos;
end;

{ srcECXCallFunctionWEDXArg }

constructor srcECXCallFunctionWEDXArg.Create(addr: pointer; args: array of const; name: string; visibility: string);
begin
  inherited;
  _to_second_reg_move_opcode:=MOV_EDX_DWORD;
end;

{ srcESICallFunctionWEAXArg }

constructor srcESICallFunctionWEAXArg.Create(addr: pointer;
  args: array of const; name, visibility: string);
begin
  inherited;
  if (self._argc<>2) then begin
    if srcKit.Get.IsDebug() then srcKit.Get.DbgLog(GetSignature + ': invalid args count!', true);
    self._isok:=false;
  end;
  _mov_this_to_arg_opcode:=MOV_ESI_DWORD;
end;

function srcESICallFunctionWEAXArg._ArgsInit(args: array of const;
  pos: pointer): pointer;
var
  val:cardinal;
begin
  if args[low(args)+1].VType=vtString then begin
    (PByte(pos))^:=MOV_EAX_DWORD;
    pos:=pointer(uintptr(pos)+1);
    if srcKit.Get.IsDebug() then srcKit.Get.DbgLog(GetSignature + ': str arg is '+inttohex(cardinal(PAnsiChar(args[low(args)+1].VString)), 8), false);
    (puintptr(pos))^:=uintptr(PAnsiChar(args[low(args)+1].VString));
    pos:=pointer(uintptr(pos)+4);
  end else begin
    if args[low(args)+1].VType=vtBoolean then begin
      if args[low(args)+1].VBoolean then begin
        val:=1;
      end else begin
        val:=0;
      end;
      if srcKit.Get.IsDebug() then srcKit.Get.DbgLog(GetSignature + ': bool arg is '+booltostr(args[low(args)+1].VBoolean), false);
    end else begin
      val:=cardinal(args[low(args)+1].VInteger);
      if srcKit.Get.IsDebug() then srcKit.Get.DbgLog(GetSignature + ': arg is '+inttohex(val, 8), false);
    end;

    (PByte(pos))^:=MOV_EAX_DWORD;
    pos:=pointer(uintptr(pos)+1);
    (PCardinal(pos))^:=val;
    pos:=pointer(uintptr(pos)+4);
  end;

  (PByte(pos))^:=_mov_this_to_arg_opcode;
  pos:=pointer(uintptr(pos)+1);
  (PCardinal(pos))^:=cardinal(args[low(args)].VInteger);
  pos:=pointer(uintptr(pos)+4);
  result:=pos;
end;

{ srcEDXCallFunctionWEAXArg }
constructor srcEDXCallFunctionWEAXArg.Create(addr:pointer; args:array of const; name:string='unnamed'; visibility:string='global');
begin
  inherited;
  _mov_this_to_arg_opcode:=MOV_EDX_DWORD;
end;

{ srcVirtualBaseFunction }

constructor srcVirtualBaseFunction.Create(vftable_offset: cardinal; args: array of const; name,
  visibility: string);
begin
  _vftable_offset:=vftable_offset;
  inherited Create(nil, args, name, visibility);

end;

function srcVirtualBaseFunction._WriteCallInstruction(
  pos: pointer; args:array of const): pointer;
var
  obj:uintptr;
  vftable:uintptr;
  f:uintptr;
begin
  obj:=uintptr(args[low(args)].VInteger);
  vftable:= (puintptr(obj))^;
  f:=(puintptr(vftable+_vftable_offset))^;
  result:=srcKit.WriteCall(pos, pointer(f), true);  
end;

{ srcVirtualECXCallFunction }

function srcVirtualECXCallFunction._WriteCallInstruction(pos: pointer;
  args: array of const): pointer;
var
  obj:uintptr;
  vftable:uintptr;
  f:uintptr;
begin
  obj:=uintptr(args[low(args)].VInteger);
  vftable:= (puintptr(obj))^;
  f:=(puintptr(vftable+_vftable_offset))^;
  result:=srcKit.WriteCall(pos, pointer(f), true);  
end;

constructor srcVirtualECXCallFunction.Create(vftable_offset: cardinal;
  args: array of const; name, visibility: string);
begin
  _vftable_offset:=vftable_offset;
  inherited Create(nil, args, name, visibility);
end;

end.
