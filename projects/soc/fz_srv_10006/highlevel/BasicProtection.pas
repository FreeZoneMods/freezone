unit BasicProtection;
{$MODE Delphi}
interface
uses Packets, Clients, sysutils;
function CheckIfPacketZStringIsLesserThan(p:pNET_Packet; len:cardinal; id:ClientID; autocorrection:boolean; msgid:cardinal; gen_badevents:boolean):boolean; stdcall;
function CheckIfPCharZStringIsLesserThan(p:PChar; len:cardinal; id:ClientID; autocorrection:boolean; msgid:cardinal; gen_badevents:boolean):boolean; stdcall;
function CheckIfPacketZStringIsLesserThenWithDisconnect(p:pNET_Packet; len:cardinal; cl:pIClient; msgid:cardinal; gen_badevents:boolean):boolean; stdcall;

function CheckIfDwordIsLesserThan(dw: cardinal; treasure: cardinal; cl_id:cardinal; gen_badevents:boolean): boolean; stdcall;
function OneByteChecker(current:byte; valid:byte; clientid:cardinal; gen_badevents:boolean):boolean; stdcall;

implementation
uses HackProcessor, Players;

function CheckIfPacketZStringIsLesserThan(p:pNET_Packet; len:cardinal; id:ClientID; autocorrection:boolean; msgid:cardinal; gen_badevents:boolean):boolean; stdcall;
var
  i:integer;
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
      str:=GenerateMessageForClientId(id.id, '');
    end else begin
      str:='Client';
    end;
    str:=str+' sent bad packet ';

    if msgid<>$FF then begin
      str:=str+'MsgID='+inttohex(msgid, 8);
    end;

    str:=str+' max string length is '+inttostr(len)+' byte(s), current length is '+inttostr(cnt)+' byte(s)';
    if gen_badevents then begin
      BadEventsProcessor(FZ_SEC_EVENT_WARN, str);
    end;
    if autocorrection then begin
      p.B.data[p.r_pos+len{%H-}-1]:=0;
      result:=true;
    end;
  end;
end;

function CheckIfPCharZStringIsLesserThan(p:PChar; len:cardinal; id:ClientID; autocorrection:boolean; msgid:cardinal; gen_badevents:boolean):boolean; stdcall;
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
      str:=GenerateMessageForClientId(id.id, '');
    end else begin
      str:='Client';
    end;
    str:=str+' sent too long string! ';
    if msgid<>$FF then begin
      str:=str+'MsgID='+inttohex(msgid, 8);
    end;

    if gen_badevents then begin
      BadEventsProcessor(FZ_SEC_EVENT_WARN, str);
    end;

    if autocorrection then begin
      p[len-1]:=chr(0);
      result:=true;
    end;
  end;
end;

function CheckIfPacketZStringIsLesserThenWithDisconnect(p:pNET_Packet; len:cardinal; cl:pIClient; msgid:cardinal; gen_badevents:boolean):boolean; stdcall;
var
  str:string;
  cnt, i:cardinal;
begin
  cnt:=0;
  for i:=p.r_pos to p.B.count-1 do begin
    cnt:=cnt+1;
    if p.B.data[i]=0 then break;
  end;

  result:= (cnt<=len);
  if not result then begin
    //не церемонимся с этим "клиентом"
    str:=GenerateMessageForClientId(cl.ID.id, ' sent bad packet');

    if msgid<>$FF then begin
      str:=str+' MsgID='+inttohex(msgid, 8);
    end;

    str:=str+'. Disconnecting.';
    DisconnectPlayer(cl, 'Attempts to crash the server');

    if gen_badevents then begin
      BadEventsProcessor(FZ_SEC_EVENT_WARN, str);
    end;
    InvalidatePacket(p);
  end;
end;

function CheckIfDwordIsLesserThan(dw: cardinal; treasure: cardinal; cl_id:cardinal; gen_badevents:boolean): boolean; stdcall;
begin
  result:= (dw < treasure);
  if gen_badevents and not result and (cl_id<>0) then begin
    BadEventsProcessor(FZ_SEC_EVENT_ATTACK, GenerateMessageForClientId(cl_id, ' sent too large packet'));
  end;
end;

function OneByteChecker(current:byte; valid:byte; clientid:cardinal; gen_badevents:boolean):boolean; stdcall;
begin
  result:= (current = valid);

  if gen_badevents and not result and (clientid<>0) then begin
    BadEventsProcessor(FZ_SEC_EVENT_WARN, GenerateMessageForClientId(clientid, ' has suspicious activity (maybe attack)'));
  end;
end;

end.
