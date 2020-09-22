unit Chat;

{$mode delphi}

interface
uses Packets, Clients, Servers, PureServer, TranslationMgr, ConfigCache, Games;

function OnChatMessage_ValidateAndChange(srv:pxrServer; p:pNET_packet; sender:pxrClientData):boolean; stdcall;
function OnChatMessage_AlternativeSendCondition(receive_candidate:pxrClientData; {%H-}to_team:word):boolean; stdcall;

function OnPlayerSpeechMessage({%H-}game:pgame_sv_mp; {%H-}p:pNET_packet; sender:ClientID):boolean; stdcall;
function OnChatCommand(srv:pxrServer; msg:PChar; {%H-}p:pNET_packet; sender:pxrClientData):boolean; stdcall;

procedure SendChatMessage(srv:pIPureServer; cl_id:cardinal; name:string; msg:string; team_id:word=0; channel_id:word=$0); stdcall;
procedure SendChatMessageByFreeZone(srv:pIPureServer; cl_id:cardinal; msg:string); stdcall;
procedure SendChatMessageByFreeZoneWSplitting(srv:pIPureServer; cl_id:cardinal; msg:string); stdcall;
procedure SendChatMessageToPlayers(sender_name:string; msg:string; team_id:word=0; channel_id:word=$FFFF); stdcall;

implementation
uses sysutils, HackProcessor, Players, xr_debug, ChatCommands, LogMgr, Censor;

const
  MAX_NICK_SIZE:cardinal = 30;
  MAX_MSG_SIZE:cardinal = 260;   //порог срабатывания антихакера
  MAX_TOTAL_SIZE:cardinal = 200; //включая терминаторы, ник и сообщение вместе, антихакер не сработает, но сообщение будет обработано для предотвращения краша

  CHAT_GROUP = '[CHAT]';

function OnPlayerSpeechMessage(game:pgame_sv_mp; p:pNET_packet; sender:ClientID):boolean; stdcall;
var
  cld:pxrClientData;
  t:cardinal;
begin
  result:=false;

  cld:=ID_to_client(sender.id);
  if cld=nil then exit;

  t:=GetFZBuffer(cld.ps).OnSpeechMessage();
  if t<>0 then begin
    result:=false;
    SendChatMessageByFreezone(GetPureServer(), sender.id, FZTranslationMgr.Get.TranslateSingle('fz_speech_have_been_muted_for_you')+' '+inttostr(t div 1000));
  end else begin
    result:=not GetFZBuffer(cld.ps).IsSpeechMuted();
    if not result then begin
      SendChatMessageByFreezone(GetPureServer(), sender.id, FZTranslationMgr.Get.TranslateSingle('fz_you_cant_speech'));
    end;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function ModifyChatStringForHacker(pMsg:PAnsiChar):boolean;
var
  translated:string;
begin
  result:=false;
  translated:=FZTranslationMgr.Get().TranslateOrEmptySingle('fz_chat_antihacker');
  if length(translated) > 0 then begin
    translated:=leftstr(translated, MAX_TOTAL_SIZE-MAX_NICK_SIZE-1);
    strcopy(pMsg, PAnsiChar(translated));
    //выставить "цвет" сообщения (общий чат)
    pWord(@pMsg[length(translated)+1])^:=0;
    result:=true;
  end;
end;

function CorrectChatSymbol(symb:char):char; stdcall;
begin
  case symb of
    '%': result:='_';
  else
    result:=symb;
  end;
end;

function OnChatMessage_ValidateAndChange(srv:pxrServer; p:pNET_packet; sender:pxrClientData):boolean; stdcall;
var
  pData:pByte;
  dest_teamid, msg_type, from_teamid:word;
  len_nick:cardinal;
  len_message:cardinal;

  cfg:FZCacheData;

  pNick, pMsg, pTmp:PAnsiChar;
  orig_nick:string;
  time:cardinal;
  gui_str:string;
  buf:FZPlayerStateAdditionalInfo;
const
  ELIPSIS:string='[...]';
const
  MUTED:string='[MUTED] ';
  CENSORED:string='[CENSORED] ';
begin
  R_ASSERT( (sender<>nil) and (p<>nil) and (srv<>nil), 'Cannot validate chat message - invalid input detected');

  result:=false;
  pData:=@p.B.data[0];

  msg_type:=pWord(pData)^;
  if msg_type<>M_CHAT_MESSAGE then begin
    //если отправлять ничего уже никому не надо - вернуть false;
    exit;
  end;
  pData:=@pData[sizeof(msg_type)];

  dest_teamid:=pWord(pData)^;
  if (dest_teamid>2) then begin
    BadEventsProcessor(FZ_SEC_EVENT_ATTACK, CHAT_GROUP+GenerateMessageForClientId(sender.base_IClient.ID.id, 'sent message to team #'+inttostr(dest_teamid)+'. Dropping.' ));
    exit;
  end;
  pData:=@pData[sizeof(dest_teamid)];

  pNick:=PAnsiChar(pData);
  len_nick:=0;
  orig_nick:='';
  while (pNick[len_nick]<>chr(0)) and (len_nick<MAX_NICK_SIZE) do begin
    orig_nick:=orig_nick+pNick[len_nick];
    pNick[len_nick]:=CorrectChatSymbol(pNick[len_nick]);
    len_nick:=len_nick+1;
  end;

  if len_nick>=MAX_NICK_SIZE then begin
    BadEventsProcessor(FZ_SEC_EVENT_ATTACK, CHAT_GROUP+GenerateMessageForClientId(sender.base_IClient.ID.id, 'sent chat message with TOO long name. Dropping!' ));
    exit;
  end;

  if orig_nick<>GetPlayerName(sender.ps) then begin
    BadEventsProcessor(FZ_SEC_EVENT_WARN, CHAT_GROUP+GenerateMessageForClientId(sender.base_IClient.ID.id, 'sent chat message with not-own nickname ("'+orig_nick+'"). Dropping!' ));
    exit;
  end;

  pData:=@pData[len_nick+1];

  pMsg:=PAnsiChar(pData);
  len_message:=0;
  while (pMsg[len_message]<>chr(0)) and (len_message<MAX_MSG_SIZE) do begin
    pMsg[len_message]:=CorrectChatSymbol(pMsg[len_message]);
    len_message:=len_message+1;
  end;

  if len_message >= MAX_MSG_SIZE then begin
    BadEventsProcessor(FZ_SEC_EVENT_ATTACK, CHAT_GROUP+GenerateMessageForClientId(sender.base_IClient.ID.id, 'sent TOO long chat message. Dropping!' ));
    ActiveDefence(sender.ps);
    result:=ModifyChatStringForHacker(pMsg);
    exit;
  end;

  if len_message+len_nick+2 >= MAX_TOTAL_SIZE then begin
    //Возможно, пользователь сделал это ненамеренно. Исправим его ошибку, чтобы никому не было хуже
    pTmp:=@pNick[MAX_TOTAL_SIZE-1-length(ELIPSIS)];
    strcopy(pTmp, PAnsiChar(ELIPSIS));
    //скопируем оригинальный "цвет"
    pWord(@pNick[MAX_TOTAL_SIZE])^:=pWord(@pData[len_message+1])^;
    len_message:=MAX_TOTAL_SIZE-len_nick-2;
  end;

  pData:=@pData[len_message+1];


  from_teamid:=pWord(pData)^;
  if from_teamid > 2 then begin
    BadEventsProcessor(FZ_SEC_EVENT_ATTACK, CHAT_GROUP+GenerateMessageForClientId(sender.base_IClient.ID.id, 'sent message with invalid source team ID('+inttostr(from_teamid)+'). Dropping!' ));
    ActiveDefence(sender.ps);
    result:=ModifyChatStringForHacker(pMsg);
    exit;
  end;

  //манипуляция цветами чата
  cfg:=FZConfigCache.Get().GetDataCopy();
  if cfg.new_chat_color_scheme then begin
    if dest_teamid = 0 then begin
      pWord(pData)^:=0;
    end else begin
      pWord(pData)^:=sender.ps.team;
    end;
  end;

  if (cfg.enable_chat_commands) and ((pMsg[0] ='\') or (pMsg[0] ='/')) then begin
    result:=OnChatCommand(srv, pMsg, p, sender)
  end else begin
      gui_str:=pMsg;
      LockServerPlayers();
      try
        buf:=GetFZBuffer(sender.ps);
        if (buf=nil) then exit;

        //отключение (mute) чата игрока
        if buf.IsMuted() then begin
          gui_str:=MUTED+gui_str;
          FZLogMgr.Get.Write('Muted player '+pNick+' tries to say "'+pMsg+'"', FZ_LOG_INFO);
          SendChatMessageByFreeZone(@srv.base_IPureServer, sender.base_IClient.ID.id, FZTranslationMgr.Get.TranslateSingle('fz_your_chat_muted'));
          exit;
        end;

        time:=buf.OnChatMessage();
        if time<>0 then begin
          gui_str:=MUTED+gui_str;
          FZLogMgr.Get.Write('Muted player '+pNick+' tries to say "'+pMsg+'"', FZ_LOG_INFO);
          SendChatMessageByFreezone(GetPureServer(), sender.base_IClient.ID.id, FZTranslationMgr.Get.TranslateSingle('fz_chat_have_been_muted_for_you')+' '+inttostr(time div 1000));
          exit;
        end;

        //цензор
        if FZConfigCache.Get.GetDataCopy.censor_chat and FZCensor.Get.CheckAndCensorString(pMsg, true, 'Censored message:') then begin
          gui_str:=CENSORED+gui_str;
          time:=buf.OnBadWordsInChat();
          if time>0 then begin
            SendChatMessageByFreeZone(@srv.base_IPureServer, sender.base_IClient.ID.id, FZTranslationMgr.Get.TranslateSingle('fz_muted_for_badwords')+inttostr(time div 1000));
          end;
          //не возвращаем false, чтобы отобразились звездочки
        end;
        result:=true;
      finally
        UnlockServerPlayers();
      end;
  end;
end;

function OnChatMessage_AlternativeSendCondition(receive_candidate:pxrClientData; to_team:word):boolean; stdcall;
begin
  //возвратить true если кандидат в любом случае должен получить сообщение
  result:=false;
  if IsLocalServerClient(@receive_candidate.base_IClient) then begin
    result:=true;
  end else if receive_candidate.m_admin_rights__m_has_admin_rights and FZConfigCache.Get().GetDataCopy().radmins_see_other_team_chat then begin
    result:=true;
  end;
end;

procedure SendChatMessage(srv:pIPureServer; cl_id:cardinal; name:string; msg:string; team_id:word=0; channel_id:word=$0); stdcall;
var
  p:NET_Packet;
begin
  ClearPacket(@p);
  WriteToPacket(@p, @M_CHAT_MESSAGE, sizeof(M_CHAT_MESSAGE)); //хидер

  if length(msg)>integer(MAX_MSG_SIZE) then setlength(msg, MAX_MSG_SIZE);
  if length(name)>integer(MAX_NICK_SIZE) then setlength(msg, MAX_NICK_SIZE);

  WriteToPacket(@p, @channel_id, sizeof(channel_id));
  WriteToPacket(@p, PAnsiChar(name), length(name)+1);
  WriteToPacket(@p, PAnsiChar(msg), length(msg)+1);
  WriteToPacket(@p, @team_id, sizeof(team_id));

  SendPacketToClient(srv, cl_id, @p);
end;

function OnChatCommand(srv:pxrServer; msg:PChar; p:pNET_packet; sender:pxrClientData):boolean; stdcall;
begin
  FZChatCommandList.Get.Execute(msg, sender, srv);
  result:=false;
end;

procedure SendChatMessageByFreeZone(srv:pIPureServer; cl_id:cardinal; msg:string); stdcall;
const
  FREEZONE_CHAT_PARAM:string = 'fz_chat_message_header';
  FREEZONE_DEF_CHAT_HDR:PChar = '%c[red]FreeZone';
var
  header:string;
begin
  header:=FZTranslationMgr.Get().TranslateSingle(FREEZONE_CHAT_PARAM);
  if header = FREEZONE_CHAT_PARAM then begin
    header := FREEZONE_DEF_CHAT_HDR;
  end;
  SendChatMessage(srv, cl_id, PAnsiChar(header), msg);
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

type
FZChatSendParams = packed record
  sender_name: string;
  msg: string;
  team_id: word;
  channel_id: word
end;
pFZChatSendParams = ^FZChatSendParams;

function _ChatMessageSenderCb(player:pointer{pIClient}; parameter:pointer=nil; {%H-}parameter2:pointer=nil):boolean stdcall;
var
  params:pFZChatSendParams;
begin
  params:=pFZChatSendParams(parameter);
  SendChatMessage(GetPureServer(), pIClient(player).ID.id, params.sender_name, params.msg, params.team_id, params.channel_id);
  result:=true;
end;

procedure SendChatMessageToPlayers(sender_name: string; msg: string; team_id: word; channel_id: word); stdcall;
var
  params:FZChatSendParams;
begin
  params.sender_name:=sender_name;
  params.msg:=msg;
  params.team_id:=team_id;
  params.channel_id:=channel_id;

  ForEachClientDo(@_ChatMessageSenderCb, nil, @params);
end;

end.

