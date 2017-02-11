unit sysmsgs;
{$mode delphi}
interface
type

pFZClAddrDescription = pointer;
FZSysmsgPayloadWriter = procedure(var buf:string; addrs:pFZClAddrDescription; args:pointer=nil); stdcall;
FZSysMsgSender = procedure(msg:pointer; len:cardinal; userdata:pointer); stdcall;

FZArchiveCompressionType = (NO_COMPRESSION, LZO_COMPRESSION);

FZFileDownloadInfo = record
  filename:PAnsiChar;
  url:PAnsiChar;
  crc32:cardinal;
  compression:FZArchiveCompressionType;
  progress_msg:PAnsiChar;
  error_already_has_dl_msg:PAnsiChar;
end;
pFZFileDownloadInfo = ^FZFileDownloadInfo;

FZReconnectInetAddrData = record
  ip:PAnsiChar;
  port:cardinal;
end;

FZMapInfo = record
  fileinfo:FZFileDownloadInfo;
  reconnect_addr:FZReconnectInetAddrData;
  mapname:PAnsiChar;
  mapver:PAnsiChar;
  xmlname:PAnsiChar;
end;
pFZMapInfo = ^FZMapInfo;

FZClientVotingElement = record
  mapname:PAnsiChar;
  mapver:PAnsiChar;
  description:PAnsiChar;
end;
pFZClientVotingElement=^FZClientVotingElement;

FZClientVotingMapList = record
  maps:pFZClientVotingElement;
  count:cardinal;
  gametype:cardinal;
  was_sent:cardinal; //out
end;
pFZClientVotingMapList=^FZClientVotingMapList;

FZSysBuffer = packed record
  addr:pointer;
  size:cardinal;
end;
pFZSysBuffer = ^FZSysBuffer;

FZDownloadFinishCallback = function (addrs:pFZClAddrDescription; reconnect_addr:FZReconnectInetAddrData):string; stdcall;

function Init():boolean; stdcall;
external 'sysmsgs.dll' name 'FZSysMsgsInit';

procedure SendSysMessage(payload:FZSysmsgPayloadWriter; pay_args:pointer; send_callback:FZSysMsgSender; userdata:pointer); stdcall;
external 'sysmsgs.dll' name 'FZSysMsgsSendSysMessage';

procedure ProcessClientMap(var buf:string; addrs:pFZClAddrDescription; args:pointer=nil); stdcall;
external 'sysmsgs.dll' name 'FZSysMsgsProcessClientMap';

procedure ProcessClientVotingMaplist(var buf:string; addrs:pFZClAddrDescription; args:pointer=nil); stdcall;
external 'sysmsgs.dll' name 'FZSysMsgsProcessClientVotingMaplist';
implementation
end.
