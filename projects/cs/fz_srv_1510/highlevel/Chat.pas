unit Chat;
{$mode delphi}
interface
uses Packets, Clients, Servers, MatVectors, PureServer, Games;

function OnChatMessage_ValidateAndChange(srv:pxrServer; p:pNET_packet; sender:pxrClientData):boolean; stdcall;
//TODO: отдельный обработчик для админских сообщений; вывести из отдельной процедуры в Packets, перехватывающей всё отправляемые пакеты
//function OnAdminChatMessage_Sent(srv:pxrServer; msg:PChar; sender:pxrClientData):boolean; stdcall;

function OnPlayerSpeechMessage(game:pgame_sv_mp; p:pNET_packet; sender:ClientID):boolean; stdcall;
function OnChatCommand(srv:pxrServer; msg:PChar; p:pNET_packet; sender:pxrClientData):boolean; stdcall;

procedure SendChatMessage(srv:pIPureServer; cl_id:cardinal; name:string; msg:string; team_id:word=0; channel_id:word=$FFFF); stdcall;
procedure SendChatMessageByFreeZone(srv:pIPureServer; cl_id:cardinal; msg:string); stdcall;
procedure SendChatMessageByFreeZoneWSplitting(srv:pIPureServer; cl_id:cardinal; msg:string); stdcall;
procedure SendSaceChatMessage(srv:pIPureServer; cl_id:cardinal); stdcall;

function Init():boolean; stdcall;

const
  ServerAdminName:PChar = 'ServerAdmin';

implementation
uses misc_stuff, BasicProtection, LogMgr, sysutils, TranslationMgr, srcBase, ChatCommands, dynamic_caster, basedefs, Players, Console, Censor, ConfigCache, Level, ControlGUI;

const
  MAX_NICK_SIZE:cardinal = 50;
  MAX_MSG_SIZE:cardinal = 250;
  FREEZONE_CHAT_STRING:PChar = '%c[red]FreeZone';



function OnPlayerSpeechMessage(game:pgame_sv_mp; p:pNET_packet; sender:ClientID):boolean; stdcall;
var
  cl:pIClient;
  cld:pxrClientData;
  t:cardinal;
begin
  result:=false;
  cl:=nil;
  ForEachClientDo(AssignFoundClientAction, OneIDSearcher, @sender.id, @cl);
  if cl=nil then exit;

  cld:=dynamic_cast(cl, 0, xrGame+RTTI_IClient, xrGame+RTTI_xrClientData, false);
  if cld=nil then exit;

  t:=FZPlayerStateAdditionalInfo(cld.ps.FZBuffer).OnSpeechMessage();
  if t<>0 then begin
    result:=false;
    SendChatMessageByFreezone(@(pCLevel(g_ppGameLevel^).Server.base_IPureServer), sender.id, FZTranslationMgr.Get.TranslateSingle('fz_speech_have_been_muted_for_you')+' '+inttostr(t div 1000));
  end else begin
    result:=not FZPlayerStateAdditionalInfo(cld.ps.FZBuffer).IsSpeechMuted();
    if not result then begin
      SendChatMessageByFreezone(@(pCLevel(g_ppGameLevel^).Server.base_IPureServer), sender.id, FZTranslationMgr.Get.TranslateSingle('fz_you_cant_speech'));    
    end;  
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function CorrectChatSymbol(symb:char):char; stdcall;
begin
  case symb of
    '%', '$', '#': result:='_';
  else
    result:=symb;
  end;
end;

function CheckPlayerChatForMute(player:pointer; pl_id:pointer; pbool_res:pointer):boolean; stdcall;
var
  cld:pxrClientData;
  t:cardinal;
begin
  result:=false; //продолжать не надо, клиент искомый только один и так
  cld:=dynamic_cast(player, 0, xrGame+RTTI_IClient, xrGame+RTTI_xrClientData, false);
  if cld=nil then exit;
  if FZPlayerStateAdditionalInfo(cld.ps.FZBuffer).IsMuted() then begin
    pboolean(pbool_res)^:=true;
  end else begin
    t:=FZPlayerStateAdditionalInfo(cld.ps.FZBuffer).OnChatMessage();
    pboolean(pbool_res)^:=(t<>0);
    if t<>0 then begin
      SendChatMessageByFreezone(@(pCLevel(g_ppGameLevel^).Server.base_IPureServer), pcardinal(pl_id)^, FZTranslationMgr.Get.TranslateSingle('fz_chat_have_been_muted_for_you')+' '+inttostr(t div 1000));
    end;
  end;
end;


function OnPlayerBadWord(player:pointer; pl_id:pointer; ptime:pointer):boolean; stdcall;
var
  cld:pxrClientData;
begin
  result:=false; //продолжать не надо, клиент искомый только один и так
  cld:=dynamic_cast(player, 0, xrGame+RTTI_IClient, xrGame+RTTI_xrClientData, false);
  if cld<>nil then begin
    pcardinal(ptime)^:=FZPlayerStateAdditionalInfo(cld.ps.FZBuffer).OnBadWordsInChat();
  end else begin
    pcardinal(ptime)^:=0;
  end;
end;

type
  FZChatMsg = record
    sender:PChar;
    msg:PChar;
    teamid:word;
  end;
  pFZChatMsg=^FZChatMsg;

function SendMessageToRAdmins(player:pointer; pmsg:pointer; psrv:pointer):boolean; stdcall;
var
  cld:pxrClientData;
begin
  result:=true;
  cld:=dynamic_cast(player, 0, xrGame+RTTI_IClient, xrGame+RTTI_xrClientData, false);
  if (cld<>nil) and (cld.m_admin_rights__m_has_admin_rights) and (pFZChatMsg(pmsg).teamid <> cld.ps.team) then begin
    SendChatMessage(@pxrServer(psrv).base_IPureServer, cld.base_IClient.ID.id, pFZChatMsg(pmsg).sender, pFZChatMsg(pmsg).msg, pFZChatMsg(pmsg).teamid);
  end;
end;

function OnChatMessage_ValidateAndChange(srv:pxrServer; p:pNET_packet; sender:pxrClientData):boolean; stdcall;
var
  i:cardinal;
  pname:PChar;
  pmsg:PChar;
  teamid:word;
  teamid_sender:word;
  is_muted:boolean;
  t:cardinal;
  msg_struct:FZChatMsg;
  j:cardinal;
begin
  //если отправлять ничего уже никому не надо - вернуть false;
  if pword(@p.B.data[0])^<>M_CHAT_MESSAGE then begin
    result:=false;
    exit;
  end;

  teamid:=pword(@p.B.data[p.r_pos])^;
  if (teamid<>$FFFF) and (teamid>2) then begin
    FZLogMgr.Get.Write('Player ID='+inttostr(sender.base_IClient.ID.id)+'sent message to team #'+inttostr(teamid)+'. Dropping.', FZ_LOG_ERROR);
    result:=false;
    exit;    
  end;
  i:=p.r_pos+2;
  pname:=PChar(@p.B.data[i]);

  j:=0;
  while (p.B.count>i) and (j<=MAX_NICK_SIZE) do begin
    if p.B.data[i+j]=0 then begin
      break;
    end;
    j:=j+1;
  end;
  if j>MAX_NICK_SIZE then begin
    FZLogMgr.Get.Write('Nickname in chat packet is TOO long, sender ID='+inttostr(sender.base_IClient.ID.id)+'! Dropping.', FZ_LOG_ERROR);
    result:=false;
    exit;
  end;

  i:=i+j+1;
  pmsg:=PChar(@p.B.data[i]);
  j:=0;
  while (p.B.count>i) and (j<=MAX_MSG_SIZE) do begin
    if p.B.data[i+j]=0 then begin
      break;
    end;
    p.B.data[i+j]:=byte(CorrectChatSymbol(chr(p.B.data[i+j])));
    j:=j+1;
  end;
  if j>MAX_MSG_SIZE then begin
    FZLogMgr.Get.Write('Chat message is TOO long, sender ID='+inttostr(sender.base_IClient.ID.id)+'! Dropping.', FZ_LOG_ERROR);
    result:=false;
    exit;
  end;
  if j=0 then begin
    result:=false;
    exit;
  end;
  i:=i+j+1;

  //манипуляция цветами чата
  if teamid = $FFFF then begin
    teamid_sender:=0;
  end else begin
    teamid_sender := sender.ps.team;
    //if teamid_sender>0 then teamid_sender:=teamid-1;
  end;

  pword(@p.B.data[i])^:=teamid_sender;

  if (pmsg[0] ='\') or (pmsg[0] ='/') then begin
    result:=OnChatCommand(srv, pmsg, p, sender)
  end else begin
    result:=true;
    ControlGUI.AddChatMessageToList(pname, pmsg);

    //отключение (mute) чата игрока
    is_muted:=false;
    ForEachClientDo(CheckPlayerChatForMute, OneIDSearcher, @sender.base_IClient.ID.id, @is_muted);
    if is_muted then begin
      FZLogMgr.Get.Write('Muted player '+pname+' tries to say "'+pmsg+'"', FZ_LOG_INFO);
      SendChatMessageByFreeZone(@srv.base_IPureServer, sender.base_IClient.ID.id, FZTranslationMgr.Get.TranslateSingle('fz_your_chat_muted'));
      result:=false;
      exit;
    end;

    //цензор
    if FZConfigCache.Get.GetDataCopy.censor_chat and FZCensor.Get.CheckAndCensorString(pmsg, true, 'Censored message:') then begin
       t:=0;
       ForEachClientDo(OnPlayerBadWord, OneIDSearcher, @sender.base_IClient.ID.id, @t);
       if t>0 then begin
         t:=t div 1000;
         SendChatMessageByFreeZone(@srv.base_IPureServer, sender.base_IClient.ID.id, FZTranslationMgr.Get.TranslateSingle('fz_muted_for_badwords')+inttostr(t));
       end;
    end;

    //отправлять радминам весь чат другой команды
    if (FZConfigCache.Get.GetDataCopy.radmins_see_other_team_chat) and (teamid<>$FFFF) then begin
      msg_struct.msg:=pmsg;
      msg_struct.sender:=pname;
      msg_struct.teamid:=sender.ps.team;
      ForEachClientDo(SendMessageToRAdmins, nil, @msg_struct, srv);
    end;
  end;
end;

function OnChatCommand(srv:pxrServer; msg:PChar; p:pNET_packet; sender:pxrClientData):boolean; stdcall;
begin
  //SendChatMessageByFreeZone(@srv.base_IPureServer, sender.base_IClient.ID.id, FZTranslationMgr.Get.TranslateSingle('not_implemented'));
  FZChatCommandList.Get.Execute(msg, sender, srv);
  result:=false;
end;

procedure SendChatMessageByFreeZone(srv:pIPureServer; cl_id:cardinal; msg:string); stdcall;
begin
  SendChatMessage(srv, cl_id, FREEZONE_CHAT_STRING, msg);
end;

procedure SendSaceChatMessage(srv:pIPureServer; cl_id:cardinal); stdcall;
begin
  SendChatMessage(srv, cl_id, '%c[0,0,0,0]', '%c[SACE]');
end;


procedure SendChatMessageByFreeZoneWSplitting(srv:pIPureServer; cl_id:cardinal; msg:string); stdcall;
var
  i:integer;
  s,tmpstr, nextword:string;
const
  delimeters:string = ',./\| :;!@#$%^&*()_-+=';
begin
  for i:=1 to length(msg) do begin
    if (length(nextword)>=integer(MAX_MSG_SIZE)-1) then begin
      //слово чересчур длинное. Отправляем предшествующее и его
      if length(tmpstr)>0 then begin
        SendChatMessageByFreeZone(srv, cl_id, tmpstr);
      end;
      SendChatMessageByFreeZone(srv, cl_id, nextword);
      tmpstr:='';
      if pos(msg[i], delimeters)>0 then begin
        nextword:='';
      end else begin
        nextword:='';
        nextword:=nextword+msg[i];
        if (i=length(msg)) then begin
          SendChatMessageByFreeZone(srv, cl_id, nextword);
        end;
      end;
    end else if(pos(msg[i], delimeters)>0) or (i=length(msg)) then begin
      //у нас символ-разделитель, слово закончилось
      s:=msg[i];

      if (length(tmpstr)>0) and (length(tmpstr)+length(nextword)+1<=integer(MAX_MSG_SIZE)) then begin
        //в этом сообщении еще есть место. Добавляем слово туда
        tmpstr:=tmpstr+nextword+s;
      end else if (length(tmpstr)=0) then begin
        //это будет первое слово в пустом сообщении (оно не может быть чересчур длинным - это уже обработано)
        tmpstr:=nextword+s;;
      end else begin
        //это сообщение заполнено. Отправляем его и формируем новое
        SendChatMessageByFreeZone(srv, cl_id, tmpstr);
        tmpstr:=nextword+s;
      end;
      nextword:='';
    end else begin
      nextword:=nextword+msg[i];
    end;
  end;

  //отправим хвост
  if length(tmpstr)>0 then begin
    SendChatMessageByFreeZone(srv, cl_id, tmpstr);
  end;
end;


procedure SendChatMessage(srv:pIPureServer; cl_id:cardinal; name:string; msg:string; team_id:word=0; channel_id:word=$FFFF); stdcall;
var
  p:NET_Packet;
begin
  ClearPacket(@p);
  p.w_allow:=true;
  WriteToPacket(@p, @M_CHAT_MESSAGE, sizeof(M_CHAT_MESSAGE)); //хидер

  if length(msg)>integer(MAX_MSG_SIZE) then setlength(msg, MAX_MSG_SIZE);
  if length(name)>integer(MAX_NICK_SIZE) then setlength(msg, MAX_NICK_SIZE);

  WriteToPacket(@p, @channel_id, sizeof(channel_id));
  WriteToPacket(@p, PChar(name), length(name)+1);
  WriteToPacket(@p, PChar(msg), length(msg)+1);
  WriteToPacket(@p, @team_id, sizeof(team_id));

  IPureServer__SendTo.Call([srv, cl_id, @p, 8, 0]);

end;


////////////////////////////////////////////
procedure MuteCmdInfo(args:PChar); stdcall;
begin
  strcopy(args, 'Disables chat for player');
end;
procedure MuteCmdExecute(args:PChar); stdcall;
const
  INV_F:string='Invalid call. Format: fz_muteplayer <player_id|last_printed> <mute time in seconds|-1 to unmute>';
var
  pos_del:integer;
  t:PChar;
  time:integer;
  id:ClientID;
  res:boolean;
begin
  pos_del:=pos(' ', args);
  if pos_del=0 then begin
    FZLogMgr.Get.Write(INV_F, FZ_LOG_IMPORTANT_INFO);
    exit;
  end;
  t:=@args[pos_del];
  args[pos_del-1]:=chr(0);

  pos_del:=pos('raid', t);
  if pos_del<>0 then begin
    t[pos_del-1]:=chr(0);
  end;

  time:=strtointdef(trim(t), 0)*1000;
  if time=0 then begin
    FZLogMgr.Get.Write(INV_F, FZ_LOG_IMPORTANT_INFO);
    exit;  
  end;
  if strcomp(args, 'last_printed')=0 then begin
    id.id:=last_printed_id^;
  end else begin
    id.id:=strtoint64def(trim(args),0);
  end;
  if time>0 then begin
    res:=MutePlayer(id, time);
  end else begin
    res:=UnMutePlayer(id);
  end;

  if not res then begin
    FZLogMgr.Get.Write('No such player id: '+inttostr(id.id), FZ_LOG_IMPORTANT_INFO);
  end;
end;
////////////////////////////////////////////
procedure ReloadBadwordsCmdInfo(args:PChar); stdcall;
begin
  strcopy(args, 'Reloads list of banned words in chat');
end;

procedure ReloadBadwordsCmdExecute(args:PChar); stdcall;
begin
  FZCensor.Get.ReloadDefaultFile;
end;
////////////////////////////////////////////

function Init():boolean; stdcall;
begin
  AddConsoleCommand('fz_reload_banned_words', ReloadBadwordsCmdExecute, ReloadBadwordsCmdInfo);
  AddConsoleCommand('fz_muteplayer', MuteCmdExecute, MuteCmdInfo);
  result:=true;
end;

end.
