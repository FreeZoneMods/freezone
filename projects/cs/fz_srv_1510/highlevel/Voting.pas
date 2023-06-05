unit Voting;
{$mode delphi}
interface
uses Packets, Clients, Games, xrstrings, misc_stuff;

function PatchVoteCommandsArrayPtrAtAddr(addr:pointer; offset:cardinal):boolean; stdcall;
function IsVoteEarlyFail(game:pgame_sv_mp; agreed, against_explicit, total_clients:cardinal):boolean; stdcall;
function IsVoteEarlySuccess({%H-}game:pgame_sv_mp; agreed, {%H-}against_explicit, total_clients:cardinal):boolean; stdcall;
function IsVoteSuccess(agreed, against_explicit, total_clients:cardinal):boolean; stdcall;

procedure OnVoteStart(game:pgame_sv_mp; senderid:ClientID; VoteCommand:PChar; resVoteCommand:PChar); stdcall;

function CanSafeStartVoting({%H-}game:pgame_sv_mp; p:pNET_Packet; sender_id:ClientID):boolean; stdcall;
function CarefullyComparePlayerNames(name1:PChar; name2:PChar):cardinal; stdcall;

function IterateAndComparePlayersNames(it_begin:ppIClient; it_end:ppIClient; newname:PChar; client:pIClient):ppIClient; stdcall;
function OnVoteStartIncorrectPlayerName(game:pgame_sv_mp): boolean; stdcall;
function OnVote({%H-}game:pgame_sv_mp; sender_id:ClientID; {%H-}status:boolean):boolean; stdcall;

procedure ProvideDefaultGameTypeForMapchangeVoting(); stdcall;
procedure OnMapChanged(); stdcall;
function Init():boolean;

implementation
uses srcBase, LogMgr, math, sysutils, console, CommonHelper, TranslationMgr, ConfigCache, PureServer, Players, dynamic_caster, basedefs, chat, Servers, MapList, HackProcessor, MapGametypes;
var
  votecommands:array of _votecommands;
  _last_map_change_time:cardinal;

procedure AddVoteCommand(name:PAnsiChar; command:PAnsiChar; mask:cardinal); stdcall;
var
  i:integer;
begin
  i:=length(votecommands);
  SetLength(votecommands, i+1);
  votecommands[i].name:=name;
  votecommands[i].command:=command;
  votecommands[i].flag:=mask;
end;

function PatchVoteCommandsArrayPtrAtAddr(addr:pointer; offset:cardinal):boolean;stdcall;
var
  new_addr:cardinal;
begin
  if length(votecommands)=0 then begin
    AddVoteCommand('restart', 'g_restart', $2);
    AddVoteCommand('restart_fast', 'g_restart_fast', $4);
    AddVoteCommand('kick', 'sv_kick', $8);
    AddVoteCommand('ban', 'sv_banplayer', $10);
    AddVoteCommand('changemap', 'sv_changelevel', $20);
    AddVoteCommand('changeweather', 'sv_setenvtime', $40);
    AddVoteCommand('changegametype', 'sv_changegametype', $80);

    AddVoteCommand('fraglimit', 'sv_fraglimit', $100);
    AddVoteCommand('timelimit', 'sv_timelimit', $200);

    AddVoteCommand(nil, nil, $0); //terminator
  end;

  new_addr:=cardinal(@(votecommands[0]))+offset;
  result:=srcKit.CopyBuf(@new_addr, addr, sizeof(pointer))
end;

function CheckPlayerAllowedStartVoting(pl:pointer; pcardinal_id:pointer; pbool_flag:pointer):boolean; stdcall;
var
  cld:pxrClientData;
begin
  result:=false;
  cld:=dynamic_cast(pl, 0, xrGame+RTTI_IClient, xrGame+RTTI_xrClientData, false);
  if cld<>nil then begin
    pboolean(pbool_flag)^:=GetFZBuffer(cld.ps).IsAllowedStartingVoting();
    if not pboolean(pbool_flag)^ then begin
      SendChatMessageByFreezone(GetPureServer(), pcardinal(pcardinal_id)^, FZTranslationMgr.Get.TranslateSingle('fz_you_cant_start_voting'));
    end;
  end else begin
    pboolean(pbool_flag)^:=false;
  end;
end;

function CanSafeStartVoting(game:pgame_sv_mp; p:pNET_Packet; sender_id:ClientID):boolean; stdcall;
var
  pVoteStr:PAnsiChar;
  i:integer;
  args:array of string;
  args_cnt:integer;
  tmpstr, logstr, tmpstr2:string;
  suppress_badevent:boolean;
const
  BannedSymbols:string = '%';
  MAX_VOTE_STRING_SIZE: integer = 200;

begin
  result:=true;
  suppress_badevent:=false;

  ForEachClientDo(CheckPlayerAllowedStartVoting, OneIDSearcher, @sender_id.id, @result);
  if not result then begin
    FZLogMgr.Get.Write('Player '+inttostr(sender_id.id)+' denied to start voting.', FZ_LOG_IMPORTANT_INFO);
    exit;
  end;

  result:=false;
  pVoteStr:=@p.B.data[p.r_pos];

  //строка не может быть длиннее 1024 символов. Мы искусственно ограничимся меньшим числом ;)
  //[bug] в нижележащей game_sv_mp::OnVoteStart идет жесткое ограничение на 256 символов! Иначе - переполнение буфера и вылет
  //TODO:запретить всем клиентам, кроме серверного, использовать знак $ (а надо ли???)
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
    end else if (args[0]='fraglimit') or (args[0]='timelimit') then begin
      //Один числовой аргумент
      result := (args_cnt = 2) and (strtointdef(args[1], -1) >= 0);
    end else if (args[0]='changeweather') then begin
      //Два строковых аргумента, первый ТРАНСЛИРУЕТСЯ!
      result:= (args_cnt = 3) and IsWeatherPresent(args[1], args[2]);
    end else if (args[0]='changemap') then begin
      //два строковых аргумента, первый ТРАНСЛИРУЕТСЯ!
      //Проверяем, есть ли такая карта на сервере
      result:=(args_cnt=3) and IsMapPresent(args[1], args[2], game.base_game_sv_GameState.base_game_GameState.m_type);
      if result then begin
        if (FZMapGametypesMgr.Get().IsMapBanned(args[1], args[2])) then begin
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
    end else if (args[0]='changegametype') then begin
      //Один строковый аргумент, не транслируется
      result:= (args_cnt = 2) and ( (args[1]='dm') or (args[1]='deathmatch') or (args[1]='tdm') or (args[1]='teamdeathmatch') or (args[1]='ah') or (args[1]='artefacthunt') or (args[1]='cta') or (args[1]='capturetheartefact'));
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

      if (tmpstr = 'kick') or (tmpstr = 'ban') or (tmpstr = 'fraglimit') or (tmpstr = 'timelimit') or (tmpstr = 'changeweather') or (tmpstr = 'changemap') or (tmpstr = 'changegametype') or (tmpstr = 'restart') or (tmpstr = 'restart_fast') then begin
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
    BadEventsProcessor(FZ_SEC_EVENT_WARN, GenerateMessageForClientId(sender_id.id, ' is denied to start voting (parameters not parsed)'));
  end;

  setlength(args, 0);
end;

function IsVoteEarlySuccess(game:pgame_sv_mp; agreed, against_explicit, total_clients:cardinal):boolean; stdcall;
begin
  result:=false;
  if not FZConfigCache.Get.GetDataCopy.allow_early_success_in_vote then exit;
  result:= (agreed/total_clients)>=c_sv_vote_quota.value^;
  if result then FZLogMgr.Get.Write('Vote Early Success! Agreed '+inttostr(floor(100*agreed/total_clients))+'% of players', FZ_LOG_IMPORTANT_INFO);
end;

function IsVoteEarlyFail(game:pgame_sv_mp; agreed, against_explicit, total_clients:cardinal):boolean; stdcall;
begin
  //прекратим голосование, когда все проголосовали против
  result:=false;
  if not FZConfigCache.Get.GetDataCopy.allow_early_fail_in_vote then exit;

  if (agreed=0) and (game.fz_vote_started_by_admin=0) then begin //последнее - на случай, если голосование начал сервер;
    result:=true;
    FZLogMgr.Get.Write('Voting Early Fail - no agreed participants!', FZ_LOG_IMPORTANT_INFO);
  end else if ((agreed+against_explicit)>=total_clients) and (agreed/total_clients<c_sv_vote_quota.value^) then begin
    result:=true;
    FZLogMgr.Get.Write('Voting Early Fail - all participants voted!', FZ_LOG_IMPORTANT_INFO);
  end else if (total_clients-against_explicit)/total_clients<c_sv_vote_quota.value^ then begin
    result:=true;
    FZLogMgr.Get.Write('Voting Early Fail - '+inttostr(floor(100*against_explicit/total_clients))+'% of players disagreed!', FZ_LOG_IMPORTANT_INFO);
  end;
end;

function IsVoteSuccess(agreed, against_explicit, total_clients:cardinal):boolean; stdcall;
begin
  if (total_clients=0) or ((agreed=0) and (against_explicit=0)) then begin
    result:=false;
    FZLogMgr.Get.Write('Voting Failed - No participants', FZ_LOG_IMPORTANT_INFO);
    exit;
  end;

  if c_sv_vote_participants.value^<>0 then begin
    result:=(agreed/(against_explicit+agreed))>=c_sv_vote_quota.value^;
  end else begin
    result:=(agreed/total_clients)>=c_sv_vote_quota.value^;
  end;

  if result then begin
    FZLogMgr.Get.Write('Voting Successfull - '+inttostr(floor(100*agreed/total_clients))+'% agreed, '+inttostr(floor(100*against_explicit/total_clients))+'% disagreed, '+inttostr(floor(100*(total_clients-against_explicit-agreed)/total_clients))+'% not voted', FZ_LOG_IMPORTANT_INFO );
  end else begin
    FZLogMgr.Get.Write('Voting Failed - '+inttostr(floor(100*agreed/total_clients))+'% agreed, '+inttostr(floor(100*against_explicit/total_clients))+'% disagreed, '+inttostr(floor(100*(total_clients-against_explicit-agreed)/total_clients))+'% not voted', FZ_LOG_IMPORTANT_INFO );
  end;
end;

function CarefullyComparePlayerNames(name1:PAnsiChar; name2:PAnsiChar):cardinal; stdcall;
var
  tmp_name_1, tmp_name_2:string;
begin
  tmp_name_1:=trim(lowercase(name1));
  tmp_name_2:=trim(lowercase(name2));
  if (tmp_name_1=tmp_name_2) then
    result:=1
  else
    result:=0;
end;

function OnPlayerStartVote(pl:pointer; {%H-}id_ptr:pointer; pbyte_res_ptr:pointer):boolean; stdcall;
var
  cld:pxrClientData;
begin
  result:=false;
  if IsLocalServerClient(pl) then
    PByte(pbyte_res_ptr)^:=1
  else begin
    PByte(pbyte_res_ptr)^:=0;
    cld:=dynamic_cast(pl, 0, xrGame+RTTI_IClient, xrGame+RTTI_xrClientData, false);
    if cld<>nil then begin
      GetFZBuffer(cld.ps).OnVoteStarted();
    end;
  end;
end;


procedure OnVoteStart(game:pgame_sv_mp; senderid:ClientID; VoteCommand:PAnsiChar; resVoteCommand:PAnsiChar); stdcall;
var
  total_command, console_command, arg1, arg2, descr, name, par:string;
  cld:pxrClientData;
  time:cardinal;
begin
  if game.m_bVotingReal<>0 then begin
    if game.m_pVoteCommand.p_ = nil then begin
      //заглушка на случай ЧП
      assign_string(@game.m_voting_string, 'Ooops! Something gone wrong...');
      assign_string(@game.m_pVoteCommand, 'deadbeef');
      FZLogMgr.Get.Write('Running voting with uninitialized m_pVoteCommand!', FZ_LOG_ERROR);
      exit;
    end;
    
    total_command:=get_string_value(@game.m_pVoteCommand);
    if not FZCommonHelper.GetNextParam(total_command, console_command, ' ') then begin
      console_command:=total_command;
      total_command:='';
    end;
    total_command:=trim(total_command);

    if console_command='sv_banplayer' then begin
      //на это же голосование повешено и onlysace
      //формат голосования: cl_votestart ban PlayerName onlysace
      FZCommonHelper.GetNextParam(total_command, arg1, ' '); //идшник игрока
      arg2:=trim(total_command);                             //время бана
      //модифицируем время бана на поминутное :)
      time:=strtointdef(arg2, 0);
      time:=BanTimeFromMinToSec(time);

      //распарсим строку голосования - нам нужен ник и реальный аргумент на месте времени бана
      name:=VoteCommand;
      name:=trim(name);
      FZCommonHelper.GetLastParam(name, par, ' ');
      name:=trim(name);
      FZCommonHelper.GetNextParam(name, descr, ' ');
      name:=trim(name);

      //анализируем инфу и составляем на ее основе команду и описалово
      descr:='ban '+name+' '+arg2+' '+FZTranslationMgr.Get.TranslateSingle('minutes');

      cld:=ID_to_client(strtoint64def(arg1, 0));
      if (cld = nil) or IsLocalServerClient(@cld.base_IClient) then begin
        if (cld = nil) then begin
          FZLogMgr.Get.Write('Can''t approve ban vote string - banned client not found', FZ_LOG_ERROR);
        end else begin
          FZLogMgr.Get.Write('Can''t approve ban vote string - attempt to ban server client', FZ_LOG_IMPORTANT_INFO);
        end;

        cld:=ID_to_client(senderid.id);
        if (cld = nil) or (cld.ps = nil) then begin
          name:='(null)';
        end else begin
          name:=GetPlayerName(cld.ps);
        end;

        descr:='ban '+name+' '+arg2+' '+FZTranslationMgr.Get.TranslateSingle('minutes');
        console_command:='';
      end else begin
        if (FZConfigCache.Get().GetDataCopy().vote_ban_by_ip) and (GetServerClient()<>nil) and (not ip_address_equal(GetServerClient().base_IClient.m_cAddress, cld.base_IClient.m_cAddress)) then begin
          console_command:='sv_banplayer_ip '+ ip_address_to_str(cld.base_IClient.m_cAddress) +' ' + inttostr(time);
        end else begin
          console_command:='sv_banplayer '+ arg1 +' ' + inttostr(time);
        end;
      end;

      assign_string(@game.m_pVoteCommand, PAnsiChar(console_command));
      assign_string(@game.m_voting_string, PAnsiChar(descr));
    end else begin
      descr:= FZTranslationMgr.Get.Translate_NoSpaces(resVoteCommand);
      assign_string(@game.m_voting_string, PAnsiChar(descr));
    end;

  end else begin
    //Это просто строка без какой-либо команды, начинающаяся с $
    VoteCommand:=PAnsiChar(cardinal(VoteCommand)+1);
    assign_string(@game.m_voting_string, VoteCommand);
  end;

  game.fz_vote_started_by_admin:=0;
  ForEachClientDo(OnPlayerStartVote, OneIDSearcher, @senderid.id, @game.fz_vote_started_by_admin);

  FZLogMgr.Get.Write('Voting "'+get_string_value(@game.m_voting_string)+'" is started', FZ_LOG_INFO);
end;


function IterateAndComparePlayersNames(it_begin:ppIClient; it_end:ppIClient; newname:PAnsiChar; client:pIClient):ppIClient; stdcall;
var
  newname_s:string;
  player_name:string;
begin
  //проверка на то, нет ли уже не сервере игрока с ником newname
  newname_s:=trim(lowercase(newname));
  while it_begin<>it_end do begin
    if (client<>it_begin^) then begin
      player_name:= get_string_value(@it_begin^.name);
      player_name:=trim(lowercase(player_name));
      if player_name=newname_s then break;
    end;
    it_begin:=pointer(cardinal(it_begin)+sizeof(it_begin));
  end;

  result:= it_begin;
end;

function OnVoteStartIncorrectPlayerName(game:pgame_sv_mp): boolean; stdcall;
begin
  //был задан некорректный ник для бана/кика
  //если придумаем, как исправить ситуацию и начать голосование - вернуть true
  //но у нас всегда false...
  FZLogMgr.Get.Write('Voting not started - player id not found by name!', FZ_LOG_ERROR);
  game.m_bVotingActive:=0;
  result:=false;
end;

function OnPlayerVotes(pl:pointer; id:pointer; canvote:pointer):boolean; stdcall;
var
  pld:pxrClientData;
begin
  result:=false;
  pld:=dynamic_cast(pl, 0, xrGame+RTTI_IClient, xrGame+RTTI_xrClientData, false);
  pboolean(canvote)^:=false;

  if pld<>nil then begin
    GetFZBuffer(pld.ps).OnVote();
    pboolean(canvote)^:= not GetFZBuffer(pld.ps).IsPlayerVoteMuted();
    if not pboolean(canvote)^ then begin
      SendChatMessageByFreezone(GetPureServer(), pcardinal(id)^, FZTranslationMgr.Get.TranslateSingle('fz_you_cant_vote'));
    end;
  end;
end;

function OnVote(game:pgame_sv_mp; sender_id:ClientID; status:boolean):boolean; stdcall;
begin
  result:=false;
  ForEachClientDo(OnPlayerVotes, OneIDSearcher, @sender_id.id, @result);
end;

procedure ProvideDefaultGameTypeForMapchangeVoting(); stdcall;
var
  cmd, mapname, mapver, gametype:string;
  i:integer;
  game:pgame_sv_mp;
  REPLACED_CMD:string='sv_changelevel ';
  NEW_CMD: string = 'sv_changelevelgametype ';
begin
  game:=GetCurrentGame();
  if game.m_bVotingReal=0 then exit;

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

  mapver:='';
  while i<=length(cmd) do begin
    if (cmd[i] <> ' ') then begin
      mapver:=mapver+cmd[i];
    end else if length(mapver) > 0 then begin
      break;
    end;
    i:=i+1;
  end;

  gametype:=FZMapGametypesMgr.Get().GetDefaultGameType(mapname, mapver);

  if length(gametype) > 0 then begin
    cmd:=NEW_CMD+' '+mapname+' '+mapver+' '+gametype;
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
