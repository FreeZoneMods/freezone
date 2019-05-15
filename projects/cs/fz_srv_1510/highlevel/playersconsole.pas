unit PlayersConsole;

{$mode delphi}

interface

function Init():boolean;

implementation
uses Console, CommonHelper, sysutils, Clients, LogMgr, Servers, strutils, AdminCommands, MatVectors;

function ExtractIdFromConsoleCommandArgs(var argstr:string; var id:cardinal):boolean;
var
  id_str:string;
begin
  result:=false;
  if not FZCommonHelper.GetNextParam(argstr, id_str, ' ') then begin
    id_str:=trim(argstr);
    argstr:='';
  end;

  if id_str='last_printed' then begin
    id:=GetLastPrintedID();
  end else begin
    id:=StrToInt64Def(id_str,0);
    if id=0 then exit;
  end;
    result:=true;
end;

function ExtractRaId(var args:string):cardinal;
const
  RADMIN_ID:string='raid:';
var
  posit, last_posit:integer;
  tmp:string;
begin
  result:=0;

  posit:=0;
  last_posit:=0;
  repeat
    if posit > 0 then last_posit:=posit;
    posit:=PosEx(RADMIN_ID, args, posit+1);
  until posit=0;

  if last_posit>0 then begin
    tmp:=trim(rightstr(args, length(args)-last_posit-length(RADMIN_ID)+1));
    args:=trim(leftstr(args, last_posit-1));
  end;

  result:=StrToInt64Def(tmp, 0);
end;

function ExtractRadmin(var args:string):pxrClientData;
var
  raid_num:cardinal;
begin
  result:=nil;
  raid_num:=ExtractRaId(args);
  if raid_num > 0 then begin
    result:=ID_to_client(raid_num);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure PrintIDs_info(args:PChar); stdcall;
begin
  strcopy(args, 'Prints ID for all players');
end;

procedure PrintIDs_exec(cmdstr:PChar); stdcall;
var
  args:string;
  raid:cardinal;
begin
  args:=cmdstr+' ';
  raid:=ExtractRaId(args);

  AddAdminCommandToQueue(FZReportPlayersCommand.Create(trim(args), GetConsoleReporter(raid)));
end;

////////////////////////////////////////////////////////////////////////////////
procedure RankUp_info(args:PChar); stdcall;
begin
  strcopy(args, 'Increases rank of the player, argument is client ID');
end;

procedure RankUp_exec(cmdstr:PChar); stdcall;
var
  argstr:string;
  raid:cardinal;
  id:cardinal;
begin
  argstr:=trim(cmdstr);
  raid:=ExtractRaId(argstr);

  id:=0;
  if not ExtractIdFromConsoleCommandArgs(argstr, id) then begin
    FZLogMgr.Get.Write('Cannot parse ID', FZ_LOG_ERROR);
    exit;
  end;

  AddAdminCommandToQueue(FZAdminRankChangeCommand.Create(id, 1, GetConsoleReporter(raid)));
end;

////////////////////////////////////////////////////////////////////////////////
procedure RankDown_info(args:PChar); stdcall;
begin
  strcopy(args, 'Decreases rank of the player, argument is client ID');
end;

procedure RankDown_exec(cmdstr:PChar); stdcall;
var
  argstr:string;
  raid:cardinal;
  id:cardinal;
begin
  argstr:=trim(cmdstr);
  raid:=ExtractRaId(argstr);

  id:=0;
  if not ExtractIdFromConsoleCommandArgs(argstr, id) then begin
    FZLogMgr.Get.Write('Cannot parse ID', FZ_LOG_ERROR);
    exit;
  end;

  AddAdminCommandToQueue(FZAdminRankChangeCommand.Create(id, -1, GetConsoleReporter(raid)));
end;

////////////////////////////////////////////////////////////////////////////////
procedure BanHwid_info(args:PChar); stdcall;
begin
  strcopy(args, 'Ban player by HWID, arguments - client ID, ban time, reason');
end;

procedure BanHwid_exec(cmdstr:PChar); stdcall;
var
  args, tmp, reason:string;
  clid, raid:cardinal;
  bantime:integer;
begin
  args:=cmdstr;
  raid:=ExtractRaId(args);

  clid:=0;
  if not ExtractIdFromConsoleCommandArgs(args, clid) then begin
    FZLogMgr.Get.Write('Cannot parse ID', FZ_LOG_ERROR);
    exit;
  end;

  args:=args + ' ';
  FZCommonHelper.GetNextParam(args, tmp, ' ');
  bantime:=strtointdef(tmp, -1);
  if bantime < 0 then begin
    FZLogMgr.Get.Write('Cannot parse ban time', FZ_LOG_ERROR);
    exit;
  end;

  reason:=args;
  AddAdminCommandToQueue(FZAdminBanHwidCommand.Create(clid, raid, bantime, reason, GetConsoleReporter(raid)));
end;

////////////////////////////////////////////////////////////////////////////////
procedure MuteCmdInfo(args:PChar); stdcall;
begin
  strcopy(args, 'Disables chat for player, arguments - client ID, mute time in seconds (or -1 to unmute)');
end;

procedure MuteCmdExecute(cmdstr:PChar); stdcall;
var
  args:string;
  clid, raid, t:cardinal;
begin
  args:=cmdstr;
  raid:=ExtractRaId(args);

  clid:=0;
  if not ExtractIdFromConsoleCommandArgs(args, clid) then begin
    FZLogMgr.Get.Write('Cannot parse ID', FZ_LOG_ERROR);
    exit;
  end;

  t:=strtointdef(trim(args), 0);
  if t = 0 then begin
    FZLogMgr.Get.Write('Invalid mute time', FZ_LOG_ERROR);
    exit;
  end;

  AddAdminCommandToQueue(FZAdminMutePlayerCommand.Create(clid, t, GetConsoleReporter(raid)));
end;

////////////////////////////////////////////////////////////////////////////////
procedure KillCmdInfo(args:PChar); stdcall;
begin
  strcopy(args, 'Kills player, argument - client ID');
end;

procedure KillCmdExecute(cmdstr:PChar); stdcall;
var
  args:string;
  clid, raid:cardinal;
begin
  args:=cmdstr;
  raid:=ExtractRaId(args);

  clid:=0;
  if not ExtractIdFromConsoleCommandArgs(args, clid) then begin
    FZLogMgr.Get.Write('Cannot parse ID', FZ_LOG_ERROR);
    exit;
  end;

  AddAdminCommandToQueue(FZAdminKillPlayerCommand.Create(clid, GetConsoleReporter(raid)));
end;

////////////////////////////////////////////////////////////////////////////////
procedure KickCmdInfo(args:PChar); stdcall;
begin
  strcopy(args, 'Kick player, arguments - client ID, reason');
end;

procedure KickCmdExecute(cmdstr:PChar); stdcall;
var
  args, reason:string;
  clid, raid:cardinal;
begin
  args:=cmdstr;
  raid:=ExtractRaId(args);

  clid:=0;
  if not ExtractIdFromConsoleCommandArgs(args, clid) then begin
    FZLogMgr.Get.Write('Cannot parse ID', FZ_LOG_ERROR);
    exit;
  end;

  reason:=trim(args);
  AddAdminCommandToQueue(FZAdminKickPlayerCommand.Create(clid, reason, GetConsoleReporter(raid)));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TeleportCmdInfo(args:PChar); stdcall;
begin
  strcopy(args, 'Teleport player, arguments - client ID, coordinates (comma-separated)');
end;

procedure TeleportCmdExecute(cmdstr:PChar); stdcall;
var
  args:string;
  clid, raid:cardinal;
  pos,dir:FVector3;
begin
  args:=cmdstr;
  raid:=ExtractRaId(args);

  clid:=0;
  if not ExtractIdFromConsoleCommandArgs(args, clid) then begin
    FZLogMgr.Get.Write('Cannot parse ID', FZ_LOG_ERROR);
    exit;
  end;

  if not MatVectors.StringToFVector3(args, pos) then begin
    FZLogMgr.Get.Write('Cannot parse position', FZ_LOG_ERROR);
    exit;
  end;

  dir.x:=0;
  dir.y:=1;
  dir.z:=0;

  AddAdminCommandToQueue(FZAdminTeleportPlayerCommand.Create(clid, pos, dir, GetConsoleReporter(raid)));
end;

////////////////////////////////////////////////////////////////////////////////
procedure UpdrateCmdInfo(args:PChar); stdcall;
begin
  strcopy(args, 'Changes update rate for player, arguments - client ID, new update rate');
end;

procedure UpdrateCmdExecute(cmdstr:PChar); stdcall;
var
  args:string;
  clid, raid, updrate:cardinal;
begin
  args:=cmdstr;
  raid:=ExtractRaId(args);

  clid:=0;
  if not ExtractIdFromConsoleCommandArgs(args, clid) then begin
    FZLogMgr.Get.Write('Cannot parse ID', FZ_LOG_ERROR);
    exit;
  end;

  updrate:=strtointdef(trim(args), 0);
  if updrate = 0 then begin
    FZLogMgr.Get.Write('Invalid update rate value', FZ_LOG_ERROR);
    exit;
  end;

  AddAdminCommandToQueue(FZAdminSetUpdrateCommand.Create(clid, updrate, GetConsoleReporter(raid)));
end;

////////////////////////////////////////////////////////////////////////////////
procedure AddmoneyCmdInfo(args:PChar); stdcall;
begin
  strcopy(args, 'Add money for player, arguments - client ID, amount of money');
end;

procedure AddmoneyCmdExecute(cmdstr:PChar); stdcall;
var
  args:string;
  clid, raid:cardinal;
  money:integer;
begin
  args:=cmdstr;
  raid:=ExtractRaId(args);

  clid:=0;
  if not ExtractIdFromConsoleCommandArgs(args, clid) then begin
    FZLogMgr.Get.Write('Cannot parse ID', FZ_LOG_ERROR);
    exit;
  end;

  money:=strtointdef(trim(args), 0);
  if money = 0 then begin
    FZLogMgr.Get.Write('Invalid amount of money', FZ_LOG_ERROR);
    exit;
  end;

  AddAdminCommandToQueue(FZAdminAddMoneyCommand.Create(clid, money, GetConsoleReporter(raid)));
end;

////////////////////////////////////////////////////////////////////////////////
procedure ChangeteamCmdInfo(args:PChar); stdcall;
begin
  strcopy(args, 'Change player''s team and blocks teamchange, arguments - client ID, team ID (0 for leaving current team), time of blocking (-1 for unblocking)');
end;

procedure ChangeteamCmdExecute(cmdstr:PChar); stdcall;
var
  args:string;
  teamstr:string;
  blocktime:integer;
  clid, raid:cardinal;
  team:integer;
  cmd_teamchange, cmd_teamblock:FZAdminCommand;
begin
  args:=cmdstr;
  raid:=ExtractRaId(args);
  cmd_teamblock:=nil;
  cmd_teamchange:=nil;

  clid:=0;
  if not ExtractIdFromConsoleCommandArgs(args, clid) then begin
    FZLogMgr.Get.Write('Cannot parse ID', FZ_LOG_ERROR);
    exit;
  end;

  if FZCommonHelper.GetNextParam(args, teamstr, ' ') then begin
    //team is parsed
    team:=strtointdef(teamstr, 0);
    blocktime:=strtointdef(args, 0);
  end else begin
    team:=strtointdef(trim(args), 0);
    blocktime:=0;
  end;

  if (team = 0) and (blocktime = 0) then begin
    //print status
    cmd_teamchange:=FZAdminChangeTeamCommand.Create(clid, team, true, GetConsoleReporter(raid));
    cmd_teamblock:=FZAdminBlockChangeTeamCommand.Create(clid, blocktime, true, GetConsoleReporter(raid));
    cmd_teamchange.SetNextStageCommand(cmd_teamblock);
    AddAdminCommandToQueue(cmd_teamchange);
    AddAdminCommandToQueue(cmd_teamblock);
  end else begin
    if (team<>0) then begin
      cmd_teamchange:=FZAdminChangeTeamCommand.Create(clid, team, false, GetConsoleReporter(raid));
      AddAdminCommandToQueue(cmd_teamchange);
    end;

    if (blocktime<>0) then begin
      cmd_teamblock:=FZAdminBlockChangeTeamCommand.Create(clid, blocktime, false, GetConsoleReporter(raid));
      if cmd_teamchange<>nil then begin
        cmd_teamchange.SetNextStageCommand(cmd_teamblock);
      end;
      AddAdminCommandToQueue(cmd_teamblock);
    end;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure ForceInvincibilityCmdInfo(args:PChar); stdcall;
begin
  strcopy(args, 'manages invincibility of the player, arguments - client ID and status: -1 (default behavior), 0 (always disabled), 1 (always enabled)');
end;

procedure ForceInvincibilityCmdExecute(cmdstr:PChar); stdcall;
var
  args:string;
  clid, raid:cardinal;
  status:integer;
  needhelp:boolean;
begin
  args:=cmdstr;
  raid:=ExtractRaId(args);

  clid:=0;
  if not ExtractIdFromConsoleCommandArgs(args, clid) then begin
    FZLogMgr.Get.Write('Cannot parse ID', FZ_LOG_ERROR);
    exit;
  end;

  status:=0;
  needhelp:=not FZCommonHelper.TryStringToInt(trim(args), status);
  AddAdminCommandToQueue(FZAdminForceInvincibilityCommand.Create(clid, status, needhelp, GetConsoleReporter(raid)));
end;

function Init():boolean;
begin
  AddConsoleCommand('fz_listplayers', @PrintIDs_exec, @PrintIDs_info);
  AddConsoleCommand('fz_rank_up', @RankUp_exec, @RankUp_info);
  AddConsoleCommand('fz_rank_down', @RankDown_exec, @RankDown_info);
  AddConsoleCommand('fz_muteplayer', @MuteCmdExecute, @MuteCmdInfo);
  AddConsoleCommand('fz_killplayer', @KillCmdExecute, @KillCmdInfo);
  AddConsoleCommand('fz_kick', @KickCmdExecute, @KickCmdInfo);
  AddConsoleCommand('fz_teleportplayer', @TeleportCmdExecute, @TeleportCmdInfo);
  AddConsoleCommand('fz_setupdrate', @UpdrateCmdExecute, @UpdrateCmdInfo);
  AddConsoleCommand('fz_addmoney', @AddmoneyCmdExecute, @AddmoneyCmdInfo);
  AddConsoleCommand('fz_changeteam', @ChangeteamCmdExecute, @ChangeteamCmdInfo);
  AddConsoleCommand('fz_invincibilityforce', @ForceInvincibilityCmdExecute, @ForceInvincibilityCmdInfo);

  AddConsoleCommand('fz_ban_hwid', @BanHwid_exec, @BanHwid_info);
  result:=true;
end;

end.

