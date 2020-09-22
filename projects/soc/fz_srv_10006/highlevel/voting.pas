unit Voting;

{$mode delphi}

interface
uses Packets, Games, Clients, xrstrings;

function CanSafeStartVoting(game:pgame_sv_mp; p:pNET_Packet; sender_id:ClientID):boolean; stdcall;

procedure ProvideDefaultGameTypeForMapchangeVoting(); stdcall;

procedure OnMapChanged(); stdcall;

function Init():boolean;

implementation
uses LogMgr, SysUtils, CommonHelper, MapList, Players, HackProcessor, ConfigBase, ConfigCache, Chat, TranslationMgr, Servers, MapGametypes;

var
  _last_map_change_time:cardinal;

function CanSafeStartVoting(game:pgame_sv_mp; p:pNET_Packet; sender_id:ClientID):boolean; stdcall;
var
  pVoteStr:PAnsiChar;
  i:integer;
  logstr:string;

  args:array of string;
  args_cnt:integer;
  tmpstr, tmpstr2:string;

  suppress_badevent:boolean;
const
  BannedSymbols:string = '%';
  MAX_VOTE_STRING_SIZE: integer = 200;
begin
  result:=false;
  suppress_badevent:=false;

  pVoteStr:=@p.B.data[p.r_pos];

  i:=0;
  while (pVoteStr[i]<>chr(0)) and (i<MAX_VOTE_STRING_SIZE) do begin
    if pos(pVoteStr[i], BannedSymbols)<>0 then begin
      pVoteStr[i]:='_';
    end;
    i:=i+1;
  end;

  if i<MAX_VOTE_STRING_SIZE then begin
    //Заполним строки аргументов
    args_cnt:=0;
    setlength(args, args_cnt);
    tmpstr:=trim(pVoteStr);
    logstr:='';
    while FZCommonHelper.GetNextParam(tmpstr, tmpstr2, ' ') do begin
      args_cnt:=args_cnt+1;
      setlength(args, args_cnt);
      tmpstr:=trim(tmpstr);
      args[args_cnt-1]:=tmpstr2;
      logstr:=logstr+', arg'+inttostr(args_cnt-1)+': '+args[args_cnt-1];
    end;

    if length(tmpstr)>0 then begin
      //Последний аргумент не распарсился из-за отсутствия пробела на конце, сохраняем отдельно
      args_cnt:=args_cnt+1;
      setlength(args, args_cnt);
      args[args_cnt-1]:=tmpstr;
      logstr:=logstr+', arg'+inttostr(args_cnt-1)+': '+args[args_cnt-1];
    end;

    FZLogMgr.Get.Write('VoteStart'+logstr, FZ_LOG_DBG);

    //Проверим на корректность
    if args_cnt < 1 then begin
      result := false;
    end else if (args[0]='kick') then begin
      //Один (или более) строковый аргумент, не транслируется
      result := (args_cnt > 1);
    end else if (args[0]='ban') then begin
      //Один (или более) строковый аргумент (не транслируется) и одно число
      result:= (args_cnt > 2) and (strtointdef(args[args_cnt-1], -1)>=0);
    end else if (args[0]='changeweather') then begin
      //Два строковых аргумента, первый ТРАНСЛИРУЕТСЯ!
      result:= (args_cnt = 3) and IsWeatherPresent(args[1], args[2]);
    end else if (args[0]='changemap') then begin
      //Один строковый аргумент, ТРАНСЛИРУЕТСЯ!
      //Проверяем, есть ли такая карта на сервере
      result:=(args_cnt=2) and IsMapPresent(args[1], game.base_game_sv_GameState.base_game_GameState.m_type);

      if result then begin
        if (FZMapGametypesMgr.Get().IsMapBanned(args[1], '1.0')) then begin
          //Карта запрещена админом к игре на сервере
          SendChatMessageByFreeZone(GetPureServer(), sender_id.id, FZTranslationMgr.Get.TranslateSingle('fz_this_map_is_banned'));
          FZLogMgr.Get.Write(GenerateMessageForClientId(sender_id.id, ' tries to start voting "'+pVoteStr+'" (skipped - map is banned on the server)'), FZ_LOG_INFO);
          suppress_badevent:=true;
          result:=false;
        end else if (_last_map_change_time<>0) and (FZCommonHelper.GetTimeDeltaSafe(_last_map_change_time) < FZConfigCache.Get().GetDataCopy().mapchange_voting_lock_time) then begin
          //Голосование заблокировано из-за того, что карта уже недавно менялась
          SendChatMessageByFreeZone(GetPureServer(), sender_id.id, FZTranslationMgr.Get.TranslateSingle('fz_this_voting_is_not_available'));
          FZLogMgr.Get.Write(GenerateMessageForClientId(sender_id.id, ' tries to start voting "'+pVoteStr+'" (skipped - map has been changed recently)'), FZ_LOG_INFO);
          suppress_badevent:=true;
          result:=false;
        end;
      end;
    end else if (args[0]='restart') or (args[0]='restart_fast') then begin
      //нет аргументов
      result:= (args_cnt = 1);
    end else if (length(args[0])>0) and (args[0][1]='$') then begin
      //[bug] В game_sv_mp::OnVoteStart при активации текстового голосования в отправляемую клиенту строку копируется все, кроме первого символа $.
      //Поэтому при старте голосования вида 'cl_votestart $changemap stalker_story_8' клиенту отправится 'changemap stalker_story_8', он попытается начать голосование на смену карты, отработает транслятор и все развалится
      //Также необходимо пропускать пробелы после $
      if length(args[0]) > 1 then begin
        //После $ пробелов нет, используем сам аргумент
        tmpstr:=trim(rightstr(args[0], length(args[0])-1));
      end else if args_cnt > 1 then begin
        //Пробел после $, команда в следующем аргументе
        tmpstr:=args[1];
      end else begin
        tmpstr:='';
      end;

      if (tmpstr = 'kick') or (tmpstr = 'ban') or (tmpstr = 'changeweather') or (tmpstr = 'changemap') or (tmpstr = 'restart') or (tmpstr = 'restart_fast') then begin
        result:=false;
      end else begin
        result:=true;
      end;
    end;
  end else begin
    pVoteStr[MAX_VOTE_STRING_SIZE]:=chr(0);
  end;

  if result then begin
    FZLogMgr.Get.Write(GenerateMessageForClientId(sender_id.id, ' is starting voting "'+pVoteStr+'"'), FZ_LOG_IMPORTANT_INFO);
  end else if not suppress_badevent  then begin
    BadEventsProcessor(FZ_SEC_EVENT_INFO, GenerateMessageForClientId(sender_id.id, ' is denied to start voting "'+pVoteStr+'"'));
  end;

  setlength(args, 0);
end;

procedure ProvideDefaultGameTypeForMapchangeVoting(); stdcall;
var
  cmd, mapname, gametype:string;
  i:integer;
  game:pgame_sv_mp;
  REPLACED_CMD:string='sv_changelevel ';
  NEW_CMD: string = 'sv_changelevelgametype ';
begin
  game:=GetCurrentGame();
  if (game.m_bVotingReal=0) then exit;

  cmd:=get_string_value(@game.m_pVoteCommand);
  if leftstr(cmd, length(REPLACED_CMD)) <> REPLACED_CMD then exit;

  mapname:='';
  i:=length(REPLACED_CMD);
  while i<=length(cmd) do begin
    if (cmd[i] <> ' ') then begin
      mapname:=mapname+cmd[i];
    end else if length(mapname) > 0 then begin
      break;
    end;
    i:=i+1;
  end;

  gametype:=FZMapGametypesMgr.Get().GetDefaultGameType(mapname, '1.0');

  if length(gametype) > 0 then begin
    cmd:=NEW_CMD+' '+mapname+' '+' '+gametype;
    FZLogMgr.Get.Write('Applying gametype change: '+cmd, FZ_LOG_DBG);
    assign_string(@game.m_pVoteCommand, PAnsiChar(cmd));
  end;
end;

procedure OnMapChanged(); stdcall;
begin
  _last_map_change_time:=FZCommonHelper.GetGameTickCount();
end;

function Init(): boolean;
begin
  _last_map_change_time:=0;
  result:=true;
end;

end.

