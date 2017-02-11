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
procedure SentPacketsRegistrator(id:cardinal; data:pointer; size:cardinal); stdcall;
function Init():boolean;


implementation
uses LogMgr, ConfigCache, sysutils, srcBase;

function IsCCSMode():boolean; stdcall;
begin
  result:=FZConfigCache.Get.GetDataCopy.is_strict_filter;
end;


procedure DPNDestroyClient(id:cardinal); stdcall;
begin
  FZLogMgr.Get.Write('DPNDestroyClient called for '+inttostr(id));
  //todo:сделать (IPureServer)->NET->DestroyClient (vtable:0x60)
end;


procedure ProcessSinglePacketInNetHandle(data:PChar; size:cardinal; clid:cardinal); stdcall;
begin
  //FZLogMgr.Get.Write('[in]'+inttohex(pword(data)^,4)+', sz='+inttostr(size));
  //FZLogMgr.Get.Write(inttostr(pWord(data)^));
      //if FZControllerMgr.Get.GetParams.ccs_present then begin
        //оно не любит пакетов с пустыми хешами
        //if pWord(data)^=M_SV_DIGEST then begin
           //FZLogMgr.Get.Write('M_SV_DIGEST caught: '+PChar(@pPacketData.data[2]));
           //FZLogMgr.Get.Write('M_SV_DIGEST caught:');
        //end;
      //end
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
        FZLogMgr.Get.Write('Packet size = '+inttostr(pMsg.dwReceiveDataSize));
        DPNDestroyClient(pMsg.dpnidSender);
        exit;
      end;

      pPacketData:= pfz_ll_net_packet_structure(pMsg.pReceiveData);

      //что интересно, контролер при получении пакета с NET_TAG_NONMERGED или отличным размером/включенным сжатием сразу вызывает (IPureServer)->NET->DestroyClient (vtable:0x60)
      if IsCCSMode() then begin
        if (pPacketData.header.tag<>NET_TAG_MERGED) or (pPacketData.header.unpacked_size<>pMsg.dwReceiveDataSize-4) or (pPacketData.compression_byte<>NET_TAG_NONCOMPRESSED) then begin
          FZLogMgr.Get.Write('-----------------------------------------------------');
          FZLogMgr.Get.Write('Strict filter detected bad packet from client '+inttostr(pMsg.dpnidSender)+'. Packet parameters:');
          FZLogMgr.Get.Write('Tag = '+inttohex(pPacketData.header.tag, 2)+', expected: '+inttohex(NET_TAG_MERGED, 2));
          FZLogMgr.Get.Write('unpacked_size = '+inttostr(pPacketData.header.unpacked_size)+', expected: '+inttostr(pMsg.dwReceiveDataSize-4));
          FZLogMgr.Get.Write('Compression tag: '+inttohex(pPacketData.compression_byte, 2) + ', expected: '+inttohex(NET_TAG_NONCOMPRESSED,2));
          DPNDestroyClient(pMsg.dpnidSender);
          FZLogMgr.Get.Write('-----------------------------------------------------');
          exit;
        end;
      end;

      //todo:Decompress
      if (pPacketData.header.unpacked_size<>pMsg.dwReceiveDataSize-4) then begin
        //compression unsupported now
        exit;
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
