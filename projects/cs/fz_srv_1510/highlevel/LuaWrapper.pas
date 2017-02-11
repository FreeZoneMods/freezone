unit LuaWrapper;

{$mode delphi}

interface
uses Lua, LuaLib;

type

  { FZLua }

  FZLua = class(TLua)
  private
    constructor Create();
  public
   class function Get():FZLua;
    function HelloWorld(LuaState: TLuaState): Integer;

    destructor Destroy(); override;
  end;

function Init():boolean; stdcall;

implementation
uses sysutils, LogMgr;

var
  _instance:FZLua;

constructor FZLua.Create;
begin
  inherited Create(true);
end;

class function FZLua.Get: FZLua;
begin
  result:=_instance;
end;

function FZLua.HelloWorld(LuaState: TLuaState): Integer;
var
  ArgCount: Integer;
  I: integer;
begin
  ArgCount := Lua_GetTop(LuaState);

  FZLogMgr.Get.Write('Im here!');

  for I := 1 to ArgCount do
    FZLogMgr.Get.Write('Arg1'+inttostr(I)+': '+inttostr(Lua_ToInteger(LuaState, I)));

  // Clear stack
  Lua_Pop(LuaState, Lua_GetTop(LuaState));

  // Push return values
  Lua_PushInteger(LuaState, 101);
  Lua_PushInteger(LuaState, 102);
  Result := 2;
end;

destructor FZLua.Destroy;
begin
  inherited Destroy;
end;

function Init():boolean; stdcall;
begin
//  _instance:=FZLua.Create();
  result:=true;
end;

end.

