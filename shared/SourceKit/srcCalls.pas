unit srcCalls;
{$mode delphi}
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
  function _WriteCallInstruction(pos:pointer; args:array of const):pointer; virtual;
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


srcECXCallFunction = class(srcBaseFunction)
  protected
  _to_reg_move_opcode:byte;
  function _ArgsInit(args:array of const; pos:pointer):pointer; override;
  public
  constructor Create(addr:pointer; args:array of const; name:string='unnamed'; visibility:string='global');
end;

{ srcESICallFunction }

srcESICallFunction = class(srcECXCallFunction)
public
  constructor Create(addr:pointer; args:array of const; name:string='unnamed'; visibility:string='global');
end;

srcVirtualECXCallFunction = class(srcECXCallFunction)
protected
  _vftable_offset:cardinal;
  function _WriteCallInstruction(pos:pointer; args:array of const):pointer; override;
public
  constructor Create(vftable_offset:cardinal; args:array of const; name:string='unnamed'; visibility:string='global');
end;

srcESICallFunctionWEAXArg = class(srcBaseFunction)
  protected
  function _ArgsInit(args:array of const; pos:pointer):pointer; override;
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

constructor srcESICallFunction.Create(addr: pointer; args: array of const;
  name: string; visibility: string);
begin
  inherited;
  _to_reg_move_opcode:=MOV_ESI_DWORD;
end;

{ srcBaseFunction }


function srcBaseFunction.AsFloat(args: array of const): single;
var
  tmp:cardinal;
begin
  tmp:=self.Call(args).VInteger;
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
    if srcKit.Get.IsDebug() then srcKit.Get.DbgLog(GetSignature + ': calling, assembled wrapper at address @'+inttohex(cardinal(@code[0]),8));

    _AssembleWrapper(@code[0], args);

    result.VInteger:=srcKit.LowLevelCall(@code[0]);

    if srcKit.Get.IsDebug() then srcKit.Get.DbgLog(GetSignature + ': result='+inttostr(result.VInteger));
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
    self._types[i]:=args[low(args)+i].VInteger;
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
  result:=self._visibility+'::'+self._name+' (@'+inttohex(cardinal(self._addr), 8)+')';
end;

function srcBaseFunction.IsItMe(name, visibility: string): boolean;
begin
  result:= (self._visibility=visibility) and (self._name=name);
end;

function srcBaseFunction._ArgsInit(args: array of const; pos: pointer):pointer;
var
  i:integer;
begin
  for i:= high(args) downto low(args) do begin
    if args[i].VType=vtString then begin
      pos:=srcKit.WritePushDword(pos, cardinal(PChar(args[i].VString)))
    end else begin
      pos:=srcKit.WritePushDword(pos, args[i].VInteger)
    end;
  end;
  result:=pos;
end;

function srcBaseFunction._AssembleWrapper(pos: pointer; args:array of const): pointer;
begin
  (PByte(pos))^:=PUSH_EAX;        //сюда будем писать резалт
  pos:=pointer(cardinal(pos)+1);
  pos:=srcKit.WriteSaveRegisters(pos);
  pos:=_ArgsInit(args, pos);
  pos:=_WriteCallInstruction(pos, args);
  (PCardinal(pos))^:=$24244489; //mov [esp+$24], eax
  pos:=pointer(cardinal(pos)+4);
  pos:=srcKit.WriteLoadRegisters(pos);
  (PByte(pos))^:=POP_EAX;       //результат выполнения функции
  pos:=pointer(cardinal(pos)+1);
  (PByte(pos))^:=RET;
  pos:=pointer(cardinal(pos)+1);
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
  pos:=pointer(cardinal(pos)+1);
  pos:=srcKit.WriteSaveRegisters(pos);
  pos:=_ArgsInit(args, pos);
  pos:=_WriteCallInstruction(pos, args);
  if self._argc>0 then pos:=srcKit.Get.WriteAddESPDword(pos, 4*self._argc);  //снимаем со стека лишнее

  (PCardinal(pos))^:=$24244489; //mov [esp+$24], eax
  pos:=pointer(cardinal(pos)+4);

  pos:=srcKit.WriteLoadRegisters(pos);
  (PByte(pos))^:=POP_EAX;       //результат выполнения функции
  pos:=pointer(cardinal(pos)+1);
  (PByte(pos))^:=RET;
  pos:=pointer(cardinal(pos)+1);
  result:=pos;
end;

{ srcECXCallFunction }

constructor srcECXCallFunction.Create(addr: pointer; args: array of const;
  name: string; visibility: string);
begin
  inherited;
  _to_reg_move_opcode:=MOV_ECX_DWORD;
  if (self._argc<1) and (args[low(args)].VType<>vtObject) then begin
    if srcKit.Get.IsDebug() then srcKit.Get.DbgLog(GetSignature + ': first argument MUST have object type!', true);
    self._isok:=false;
  end;
end;

function srcECXCallFunction._ArgsInit(args: array of const;
  pos: pointer): pointer;
var
  i:integer;
begin
  for i:= high(args) downto low(args)+1 do begin
    if args[i].VType=vtString then begin
      pos:=srcKit.WritePushDword(pos, cardinal(PChar(args[i].VString)))
    end else begin
      pos:=srcKit.WritePushDword(pos, args[i].VInteger)
    end;
  end;
  (PByte(pos))^:=_to_reg_move_opcode;
  pos:=pointer(cardinal(pos)+1);
  (PCardinal(pos))^:=args[low(args)].VInteger;
  pos:=pointer(cardinal(pos)+4);
  result:=pos;
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
end;

function srcESICallFunctionWEAXArg._ArgsInit(args: array of const;
  pos: pointer): pointer;
begin

  if args[low(args)+1].VType=vtString then begin
    (PByte(pos))^:=MOV_EAX_DWORD;
    pos:=pointer(cardinal(pos)+1);
    (PCardinal(pos))^:=cardinal(PChar(args[low(args)+1].VString));
    pos:=pointer(cardinal(pos)+4);
  end else begin
    (PByte(pos))^:=MOV_EAX_DWORD;
    pos:=pointer(cardinal(pos)+1);
    (PCardinal(pos))^:=args[low(args)+1].VInteger;
    pos:=pointer(cardinal(pos)+4);
  end;

  (PByte(pos))^:=MOV_ESI_DWORD;
  pos:=pointer(cardinal(pos)+1);
  (PCardinal(pos))^:=args[low(args)].VInteger;
  pos:=pointer(cardinal(pos)+4);
  result:=pos;
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
  obj:cardinal;
  vftable:cardinal;
  f:cardinal;
begin
  obj:=args[low(args)].VInteger;
  vftable:= (PCardinal(obj))^;
  f:=(PCardinal(vftable+_vftable_offset))^;
  result:=srcKit.WriteCall(pos, pointer(f), true);  
end;

{ srcVirtualECXCallFunction }

function srcVirtualECXCallFunction._WriteCallInstruction(pos: pointer;
  args: array of const): pointer;
var
  obj:cardinal;
  vftable:cardinal;
  f:cardinal;
begin
  obj:=args[low(args)].VInteger;
  vftable:= (PCardinal(obj))^;
  f:=(PCardinal(vftable+_vftable_offset))^;
  result:=srcKit.WriteCall(pos, pointer(f), true);  
end;

constructor srcVirtualECXCallFunction.Create(vftable_offset: cardinal;
  args: array of const; name, visibility: string);
begin
  _vftable_offset:=vftable_offset;
  inherited Create(nil, args, name, visibility);
end;

end.
