unit BasicProtection;
{$MODE Delphi}
interface
uses Packets, Clients, LogMgr, sysutils, Console, ConfigCache;
function CheckIfPacketZStringIsLesserThen(p:pNET_Packet; len:cardinal; id:ClientID; autocorrection:boolean; msgid:cardinal):boolean; stdcall;
function CheckIfPCharZStringIsLesserThen(p:PChar; len:cardinal; id:ClientID; autocorrection:boolean; msgid:cardinal):boolean; stdcall;

function CheckIfPacketZStringIsLesserThenWithDisconnect(p:pNET_Packet; len:cardinal; cl:pIClient; msgid:cardinal):boolean; stdcall;

implementation
uses srcBase, misc_stuff;

function CheckIfPacketZStringIsLesserThen(p:pNET_Packet; len:cardinal; id:ClientID; autocorrection:boolean; msgid:cardinal):boolean; stdcall;
var
  i:cardinal;
  cnt:cardinal;
  str:string;
begin
  cnt:=0;
  for i:=p.r_pos to p.B.count-1 do begin
    cnt:=cnt+1;
    if p.B.data[i]=0 then break;
  end;

  result:= (cnt<=len);
  if not result then begin
    if id.id<>0 then begin
      str:='Client ID='+inttostr(id.id);
    end else begin
      str:='Client';
    end;
    str:=str+' sent bad packet ';

    if msgid<>$FF then begin
      str:=str+'MsgID='+inttohex(msgid, 8);
    end;

    str:=str+' max string length is '+inttostr(len)+' byte(s), current length is '+inttostr(cnt)+' byte(s)';
    FZLogMgr.Get.Write(str, FZ_LOG_ERROR);
    if autocorrection then begin
      p.B.data[p.r_pos+len-1]:=0;
      result:=true;
    end;
  end;
end;

function CheckIfPCharZStringIsLesserThen(p:PChar; len:cardinal; id:ClientID; autocorrection:boolean; msgid:cardinal):boolean; stdcall;
var
  cnt:cardinal;
  str:string;
begin
  cnt:=0;
  while (cnt<len) and (p[cnt]<>chr(0)) do begin
    cnt:=cnt+1;
  end;

  result:= (cnt<len);
  if not result then begin
    if id.id<>0 then begin
      str:='Client ID='+inttostr(id.id);
    end else begin
      str:='Client';
    end;
    str:=str+' sent too long string! ';
    if msgid<>$FF then begin
      str:=str+'MsgID='+inttohex(msgid, 8);
    end;

    FZLogMgr.Get.Write(str, FZ_LOG_ERROR);
    if autocorrection then begin
      p[len-1]:=chr(0);
      result:=true;
    end;
  end;
end;

function CheckIfPacketZStringIsLesserThenWithDisconnect(p:pNET_Packet; len:cardinal; cl:pIClient; msgid:cardinal):boolean; stdcall;
var
  str, cmd:string;
  cnt, i, time:cardinal;
begin
  cnt:=0;
  for i:=p.r_pos to p.B.count-1 do begin
    cnt:=cnt+1;
    if p.B.data[i]=0 then break;
  end;

  result:= (cnt<=len);
  if not result then begin
    //не церемонимся с этим "клиентом"
    str:='Client ID='+inttostr(cl.ID.id)+' sent bad packet';

    if msgid<>$FF then begin
      str:=str+' MsgID='+inttohex(msgid, 8);
    end;

    time:=FZConfigCache.Get.GetDataCopy.ban_for_badpackets;
    if time>0 then begin
      str:=str+'. Banning '+ip_address_to_str(cl.m_cAddress);
      cmd:='sv_banplayer_ip '+ip_address_to_str(cl.m_cAddress)+' ';
      time:=BanTimeFromMinToSec(time);
      cmd:=cmd+inttostr(time);

    end else begin
      str:=str+'. Disconnecting.';
      cmd:='sv_kick_id '+inttostr(cl.ID.id);
    end;

    FZLogMgr.Get.Write(str, FZ_LOG_ERROR);
    InvalidatePacket(p);
    ExecuteConsoleCommand(PAnsiChar(cmd));
  end;
end;

end.
