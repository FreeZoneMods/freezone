library fz_sysmsgs;

{$mode objfpc}{$H+}

uses
  sysmsgs;

procedure FZSysMsgsInit(); stdcall;
begin
  sysmsgs.Init();
end;

procedure FZSysMsgsSendSysMessage(payload:FZSysmsgPayloadWriter; pay_args:pointer; send_callback:FZSysMsgSender; userdata:pointer); stdcall;
begin
  sysmsgs.SendSysMessage(payload, pay_args, send_callback, userdata);
end;

procedure FZSysMsgsProcessClientMap(var buf:string; addrs:pFZClAddrDescription; args:pointer=nil); stdcall;
begin
  sysmsgs.ProcessClientMap(buf, addrs, args);
end;

procedure FZSysMsgsProcessClientVotingMaplist(var buf:string; addrs:pFZClAddrDescription; args:pointer=nil); stdcall;
begin
  sysmsgs.ProcessClientVotingMaplist(buf, addrs, args);
end;

exports
  FZSysMsgsInit,
  FZSysMsgsSendSysMessage,
  FZSysMsgsProcessClientMap,
  FZSysMsgsProcessClientVotingMaplist;

begin
end.

