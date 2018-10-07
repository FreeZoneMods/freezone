unit ChatCommands;
{$MODE Delphi}
interface
uses Contnrs, Clients, Servers, Windows;

//TODO: начать голосование на САКЕ через чат
type

FZChatCommand = class
protected
  _name:PChar;
  _info:string;
  _enabled:boolean;
public
  constructor Create(name:PChar; info:string);
  destructor Destroy(); override;
  function Execute(args:PChar; who:pxrClientData; srv:pxrServer):boolean; virtual;
end;

FZChatHelpCommand = class (FZChatCommand)
  _cached:string;
  _cs:TRtlCriticalSection;
public
  constructor Create(name:PChar; info:string);
  destructor Destroy(); override;
  function Execute(args:PChar; who:pxrClientData; srv:pxrServer):boolean; override;
end;

FZChatSaceCommand = class(FZChatCommand)
  function Execute(args:PChar; who:pxrClientData; srv:pxrServer):boolean; override;
end;

FZChatUpdateRateCommand = class(FZChatCommand)
  function Execute(args:PChar; who:pxrClientData; srv:pxrServer):boolean; override;
end;


////////////////////////////////////////////////
FZChatCommandList = class
  _list:TObjectList;
public
  constructor Create();
  procedure AddCommand(c:FZChatCommand);
  function Execute(cmd:PChar; who:pxrClientData; srv:pxrServer):boolean; stdcall;
  destructor Destroy; override;

  class function Get():FZChatCommandList;
end;

function Init():boolean;

implementation
uses Sysutils, Chat, TranslationMgr, LogMgr, SACE_interface, players, xrstrings, xr_debug;

var
  _instance:FZChatCommandList = nil;


{ FZChatCommand }

constructor FZChatCommand.Create(name:PChar; info:string);
begin
  self._name:=name;
  self._info:=info;
  _enabled:=true;
end;

destructor FZChatCommand.Destroy;
begin

  inherited;
end;


function FZChatCommand.Execute(args: PChar; who: pxrClientData;
  srv: pxrServer): boolean;
begin
  if (args<>nil) and (strcomp(args, 'help')=0) then begin
    SendChatMessageByFreeZone(@srv.base_IPureServer, who.base_IClient.ID.id, FZTranslationMgr.Get.TranslateSingle(_info));
    result:=true;
  end else begin
    result:=false;
  end;
end;

{ FZChatCommandList }

procedure FZChatCommandList.AddCommand(c: FZChatCommand);
begin
  _list.Add(c);
end;

constructor FZChatCommandList.Create;
begin
  _list:=TObjectList.Create;
  AddCommand(FZChatHelpCommand.Create('help', FZTranslationMgr.Get.TranslateSingle('fz_cmd_help_help')));
  AddCommand(FZChatSaceCommand.Create('sace', FZTranslationMgr.Get.TranslateSingle('fz_cmd_sace_help')));
  AddCommand(FZChatUpdateRateCommand.Create('updrate', FZTranslationMgr.Get.TranslateSingle('fz_cmd_updrate_help')));    
end;

destructor FZChatCommandList.Destroy;
begin
  _list.Free;
  inherited;

end;

function FZChatCommandList.Execute(cmd: PChar; who:pxrClientData; srv:pxrServer):boolean;
var
  i:integer;
  args:PChar;
  cmd_smp:FZChatCommand;
begin
  cmd:=@cmd[1];

  FZLogMgr.Get.Write('Client '+get_string_value(@who.base_IClient.name)+' is running chat command "'+cmd+'"', FZ_LOG_INFO);

  i:=pos(' ', cmd);
  if i>0 then begin
    args := @cmd[i];
    cmd[i-1]:=chr(0);
  end else begin
    args:=nil;
  end;

  result:=false;
  for i:=0 to _list.Count-1 do begin
    cmd_smp:=_list.Items[i] as FZChatCommand;
    if strcomp(cmd, cmd_smp._name) = 0 then begin
      if cmd_smp._enabled then begin
        if not cmd_smp.Execute(args, who, srv) then begin
          FZLogMgr.Get.Write('Invalid syntax!', FZ_LOG_INFO);
          SendChatMessageByFreeZone(@srv.base_IPureServer, who.base_IClient.ID.id, FZTranslationMgr.Get.TranslateSingle('fz_invalid_command_call'));
        end;
      end else begin
        SendChatMessageByFreeZone(@srv.base_IPureServer, who.base_IClient.ID.id, FZTranslationMgr.Get.TranslateSingle('fz_command_disabled'));      
      end;
      result:=true;
      break;
    end; 
  end;

  if not result then begin
    FZLogMgr.Get.Write('Unknown command: '+cmd, FZ_LOG_INFO);
    SendChatMessageByFreeZone(@srv.base_IPureServer, who.base_IClient.ID.id, FZTranslationMgr.Get.TranslateSingle('fz_unknown_command'));
  end;
end;

class function FZChatCommandList.Get: FZChatCommandList;
begin
  result:=_instance;
end;

{ FZChatHelpCommand }

constructor FZChatHelpCommand.Create(name: PChar; info: string);
begin
  inherited;
  self._cached:='';
  InitializeCriticalSection(self._cs);
end;

destructor FZChatHelpCommand.Destroy;
begin
  DeleteCriticalSection(self._cs);
  inherited;
end;

function FZChatHelpCommand.Execute(args: PChar; who: pxrClientData;
  srv: pxrServer): boolean;
var
  i:integer;
begin
  result:=inherited Execute(args, who, srv);
  if result then exit;

  EnterCriticalSection(_cs);
  if length(_cached)=0 then begin
    _cached:=FZTranslationMgr.Get.TranslateSingle('fz_help_available_commands')+' ';
    for i:=0 to _instance._list.Count-1 do begin
      if i<>_instance._list.Count-1 then begin
        _cached:=_cached+(_instance._list.Items[i] as FZChatCommand)._name+', ';
      end else begin
        _cached:=_cached+(_instance._list.Items[i] as FZChatCommand)._name
      end;
    end;
  end;
  SendChatMessageByFreeZoneWSplitting(@srv.base_IPureServer, who.base_IClient.ID.id, _cached);
  LeaveCriticalSection(_cs);

  result:=true;

end;

{ FZChatSaceCommand }

function CheckAndFillSace(player:pointer; p1:pointer; {%H-}p2:pointer):boolean; stdcall;
var
  str:pstring;
  cl:pIClient;
begin
  result:=true;
  cl:=pIClient(player);
  if cl=nil then exit;

  if not IsLocalServerClient(cl) then begin
    if GetSACEStatus(cl.ID.id)=SACE_OK then begin
      str:=pstring(p1);
      str^:=str^ + get_string_value(@cl.name)+' ';
    end;
  end;
end;

function FZChatSaceCommand.Execute(args: PChar; who: pxrClientData;
  srv: pxrServer): boolean;
var
  str:string;
begin
  result:=inherited Execute(args, who, srv);
  if result then exit;

  if IsSaceSupportedByServer() then begin
    str:='';
    ForEachClientDo(CheckAndFillSace, nil, @str);
    if str='' then begin
      str:=FZTranslationMgr.Get.TranslateSingle('fz_no_players_with_sace');
    end else begin
      str:=FZTranslationMgr.Get.TranslateSingle('fz_sace_users')+' '+str;
    end;
    SendChatMessageByFreeZoneWSplitting(@srv.base_IPureServer, who.base_IClient.ID.id, str);
  end else begin
    SendChatMessageByFreeZoneWSplitting(@srv.base_IPureServer, who.base_IClient.ID.id, FZTranslationMgr.Get.TranslateSingle('fz_sace_not_supported_by_server'));
  end;
  result:=true;
end;

{ FZChatUpdateRateCommand }

function FZChatUpdateRateCommand.Execute(args: PChar; who: pxrClientData;
  srv: pxrServer): boolean;
var
  newval:integer;
begin
  result:=inherited Execute(args, who, srv);
  if result then exit;

  if (args<>nil) then begin
    newval:=strtointdef(args, -1);
    if newval>0 then begin
      FZPlayerStateAdditionalInfo(who.ps.FZBuffer).updrate:=newval;
    end;
  end;

  SendChatMessageByFreeZoneWSplitting(@srv.base_IPureServer, who.base_IClient.ID.id, FZTranslationMgr.Get.TranslateSingle('fz_your_updrate')+' '+inttostr(FZPlayerStateAdditionalInfo(who.ps.FZBuffer).updrate));
  result:=true;
end;

function Init():boolean;
begin
  R_ASSERT(_instance = nil, 'Chat commands module is already initialized');
  _instance:=FZChatCommandList.Create();
  result:=true;
end;

end.
