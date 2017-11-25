unit PacketFilter;
{$mode delphi}
interface
uses Packets;

type
net_handler_args = packed record
  dwMessageType:word;
  _unused:word;
  pMessage:pointer;
end;

fz_ll_net_packet_structure = packed record
  header:MultipacketHeader;
  compression_byte:byte;
  data:array[0..8191] of char;//берем по максимуму
end;
pfz_ll_net_packet_structure=^fz_ll_net_packet_structure;

pnet_handler_args=^net_handler_args;

procedure net_Handler(args:pnet_handler_args); stdcall;
procedure SentPacketsRegistrator({%H-}id:cardinal; data:pointer; {%H-}size:cardinal); stdcall;
function Init():boolean;


implementation
uses LogMgr, ConfigCache, sysutils;

function IsStrictMode():boolean; stdcall;
begin
  result:=FZConfigCache.Get.GetDataCopy.is_strict_filter;
end;


procedure DPNDestroyClient(id:cardinal); stdcall;
begin
  FZLogMgr.Get.Write('DPNDestroyClient called for '+inttostr(id), FZ_LOG_DBG);
  //todo:сделать (IPureServer)->NET->DestroyClient (vtable:0x60)
end;


procedure ProcessSinglePacketInNetHandle({%H-}data:PAnsiChar; {%H-}size:cardinal; {%H-}clid:cardinal); stdcall;
begin
end;


procedure net_Handler(args:pnet_handler_args); stdcall;
//патч IPureServer::net_Handler, работает раньше самого контролера!
var
  pMsg:PDPNMSG_RECEIVE;
  pPacketData:pfz_ll_net_packet_structure;
  i:cardinal;
  size:cardinal;
begin

  if args.dwMessageType=DPN_MSGID_RECEIVE then begin
    pMsg:=args.pMessage;
    if (pMsg.dwReceiveDataSize>2*sizeof(cardinal)) and (pMSYS_PING(pMSG.pReceiveData).sign1=SIGN1) and (pMSYS_PING(pMSG.pReceiveData).sign2=SIGN2) then begin
      //this is system ping message, ignore it
    end else begin
      //проверка на размер пакета - должен быть не более $4000 байт
      if pMsg.dwReceiveDataSize>=$4000 then begin
        FZLogMgr.Get.Write('Packet size = '+inttostr(pMsg.dwReceiveDataSize), FZ_LOG_IMPORTANT_INFO);
        DPNDestroyClient(pMsg.dpnidSender);
        exit;
      end;

      pPacketData:= pfz_ll_net_packet_structure(pMsg.pReceiveData);

      if (pPacketData.header.tag<>NET_TAG_MERGED) then begin
        FZLogMgr.Get.Write('NON-MERGED packet from client id='+inttostr(pMsg.dpnidSender), FZ_LOG_IMPORTANT_INFO);
        if IsStrictMode() then begin
          //что интересно, контролер при получении пакета с NET_TAG_NONMERGED или отличным размером/включенным сжатием сразу вызывает (IPureServer)->NET->DestroyClient (vtable:0x60)
          DPNDestroyClient(pMsg.dpnidSender);
          exit;
        end;
      end;

      if pPacketData.compression_byte=NET_TAG_NONCOMPRESSED then begin
        if pPacketData.header.unpacked_size<>pMsg.dwReceiveDataSize-4 then begin
          FZLogMgr.Get.Write('Invalid size in header, packet from client id='+inttostr(pMsg.dpnidSender), FZ_LOG_IMPORTANT_INFO);
          DPNDestroyClient(pMsg.dpnidSender);
          exit;
        end;
      end else if pPacketData.compression_byte=NET_TAG_COMPRESSED then begin;
        //TODO: Из-за ассерта в декомпрессоре могут быть проблемы...
        //TODO: Decompress
      end else begin
        FZLogMgr.Get.Write('Unknown compression tag value, client id='+inttostr(pMsg.dpnidSender), FZ_LOG_IMPORTANT_INFO);
      end;

      if pPacketData.header.tag=NET_TAG_MERGED then begin
        i:=0;
        while i<pPacketData.header.unpacked_size do begin
          size:= pWord(@pPacketData.data[i])^;
          i:=i+2;
          ProcessSinglePacketInNetHandle(@pPacketData.data[i], size, pMsg.dpnidSender);
          i:=i+size;
        end;
      end else if pPacketData.header.tag=NET_TAG_NONMERGED then begin
        ProcessSinglePacketInNetHandle(@pPacketData.data, pPacketData.header.unpacked_size, pMsg.dpnidSender);
      end else begin
        //todo:можно отбросить пакет
      end;

    end;
  end;
end;

procedure SentPacketsRegistrator(id:cardinal; data:pointer; size:cardinal); stdcall;
begin
//   FZLogMgr.Get.Write(inttohex(pword(@data)^,4));
    if pword(data)^=$1980 then exit; //MSYS
    //FZLogMgr.Get.Write('[out]'+inttohex(pword(data)^,4)+', sz='+inttostr(size));

end;

function Init():boolean;
begin
  result:=true;
end;


end.
