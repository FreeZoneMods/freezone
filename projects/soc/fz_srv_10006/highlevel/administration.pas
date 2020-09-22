unit administration;

{$mode delphi}

interface
uses
  xrstrings, Clients, PureServer;

function AnswerToHacker(hacker_id:cardinal):boolean; stdcall;

function Init():boolean;

implementation
uses FastMd5, ConfigCache, Console, sysmsgs, sysutils, LogMgr, Servers, CommonHelper, ConfigBase, PlayersConsole;

//Callback for sending download SYSMSGS
type FZSysMsgSendCallbackData = record
  srv:pIPureServer;
  cl_id:ClientID;
end;
pFZSysMsgSendCallbackData = ^FZSysMsgSendCallbackData;

procedure SysMsg_SendCallback(msg:pointer; len:cardinal; userdata:pointer); stdcall;
var
  data:pFZSysMsgSendCallbackData;
begin
  data:=pFZSysMsgSendCallbackData(userdata);
  SendPacketToClient_LL(data.srv, data.cl_id.id, msg, len);
end;

procedure RemoteSingleSC_ProcessOne(cmd:string; id:cardinal);
var
  ex_params:FZClientExParameters;
  userdata:FZSysMsgSendCallbackData;
begin
  if GetServerClient().base_IClient.ID.id =id then begin
    FZLogMgr.Get.Write('Server ID is not supported', FZ_LOG_ERROR);
    exit;
  end;

  userdata.srv:=GetPureServer();
  userdata.cl_id.id:= id;

  ex_params.action:=FZ_EX_CLIENT_ACTION_SC;
  ex_params.buf:=PAnsiChar(cmd);
  ex_params.size:=length(cmd)+1;
  ex_params.cl_id:=id;
  SendSysMessage_SOC(@ProcessExClientAction, @ex_params, @SysMsg_SendCallback, @userdata);
end;

procedure RemoteSingleSC_info(args:PChar); stdcall;
begin
  strcopy(args, 'arguments - client ID and command');
end;

procedure RemoteSingleSC_exec(cmdstr:PChar); stdcall;
var
  args:string;
  id:cardinal;
begin
  args:=cmdstr;
  id:=0;
  if not ExtractIdFromConsoleCommandArgs(args, id) then begin
    FZLogMgr.Get.Write('Cannot parse ID', FZ_LOG_ERROR);
  end;
  RemoteSingleSC_ProcessOne(trim(args), id);
end;

procedure RemoteFR_info(args:PChar); stdcall;
begin
  strcopy(args, 'arguments - client ID and file name');
end;

procedure RemoteFR_ProcessOne(cl_id:cardinal; fname:string; body:string; immediately:boolean);
var
  buf:string;
  ex_params:FZClientExParameters;
  userdata:FZSysMsgSendCallbackData;
begin
  if GetServerClient().base_IClient.ID.id = cl_id then begin
    FZLogMgr.Get.Write('Server ID is not supported', FZ_LOG_ERROR);
    exit;
  end;

  buf:=fname+chr(0)+body;

  userdata.srv:=GetPureServer();
  userdata.cl_id.id:=cl_id;

  ex_params.action:=FZ_EX_CLIENT_ACTION_FR;
  ex_params.buf:=PAnsiChar(buf);
  ex_params.size:=length(buf);
  ex_params.cl_id:=userdata.cl_id.id;
  if immediately then begin
    ex_params.flags:=FZ_EX_CLIENT_ACTION_IMMEDIATELY_FLAG;
  end else begin
    ex_params.flags:=0;
  end;
  SendSysMessage_SOC(@ProcessExClientAction, @ex_params, @SysMsg_SendCallback, @userdata);
end;

procedure ProcessFile(cl_id:cardinal; fname:string; immediately:boolean; rel_path:string='');
var
  file_data:string;
  fname_full:string;
const
  safe_suffix:string='.safe';
begin
  if length(fname)=0 then begin
    FZLogMgr.Get.Write('Empty file name', FZ_LOG_ERROR);
  end;

  if (length(rel_path)>0) and (rel_path[length(rel_path)]<>'\') and (rel_path[length(rel_path)]<>'/') then begin
    rel_path:=rel_path+'\';
  end;

  fname_full:=rel_path+fname;

  if not FZCommonHelper.ReadFileAsString(fname_full, file_data) then begin
    FZLogMgr.Get.Write('Cannot read file '+fname_full, FZ_LOG_ERROR);
    exit;
  end;

  if rightstr(fname, length(safe_suffix)) = safe_suffix then begin
    fname:=leftstr(fname, length(fname)-length(safe_suffix));
  end;

  RemoteFR_ProcessOne(cl_id, fname, file_data, immediately);
end;

procedure RemoteFR_exec(cmdstr:PChar); stdcall;
var
  argstr:string;
  id:cardinal;
begin
  id:=0;
  argstr:=trim(cmdstr);

  if not ExtractIdFromConsoleCommandArgs(argstr, id) then begin
    FZLogMgr.Get.Write('Cannot parse ID', FZ_LOG_ERROR);
  end;

  ProcessFile(id, trim(argstr), true);
end;

procedure RemoteList_process(id:cardinal; list:string);
var
  ini:FZConfigBase;

  sec_count, i:integer;
  sec_name, itm:string;
  need_exec:boolean;

  item_type:string;
  c:char;
begin
  if GetServerClient().base_IClient.ID.id=id then begin
    FZLogMgr.Get.Write('Server ID is not supported', FZ_LOG_ERROR);
    exit;
  end;

  ini:=FZConfigBase.Create();
  try
    if not ini.Load(list) then begin
      FZLogMgr.Get().Write('Cannot open file '+list, FZ_LOG_ERROR);
      exit;
    end;

    repeat
      c:=list[length(list)];
      list:=leftstr(list, length(list)-1);
    until (c='\') or (c='/') or (length(list)=0);

    sec_count:=ini.GetInt('count', 0, 'main');
    for i:=0 to sec_count-1 do begin
      sec_name:='item_'+inttostr(i);
      item_type:=ini.GetString('type', '', sec_name);
      if item_type = 'file' then begin
        itm:=ini.GetString('filename', '', sec_name);
        if length(itm) > 0 then begin
          need_exec:=ini.GetBool('need_exec', true, sec_name);
          ProcessFile(id, itm, need_exec, list);
        end else begin
          FZLogMgr.Get().Write('Section ['+sec_name+']'+'has no "filename" parameter', FZ_LOG_ERROR);
        end;
      end else if item_type='cmd' then begin
        itm:=ini.GetString('command', '', sec_name);
        if length(itm) > 0 then begin
          RemoteSingleSC_ProcessOne(itm, id);
        end else begin
          FZLogMgr.Get().Write('Command is empty!', FZ_LOG_ERROR);
        end;
      end else begin
        FZLogMgr.Get().Write('Unknown item type '+item_type, FZ_LOG_ERROR);
      end;
      FZLogMgr.Get().Write('Processed '+itm+' for client '+inttostr(id), FZ_LOG_INFO);
    end;
  finally
    ini.Free();
  end;
end;

procedure RemoteList_info(args:PChar); stdcall;
begin
  strcopy(args, 'arguments - client ID and list file name');
end;

procedure RemoteList_exec(cmdstr:PChar); stdcall;
var
  argstr:string;
  id:cardinal;

begin
  id:=0;
  argstr:=trim(cmdstr);

  if not ExtractIdFromConsoleCommandArgs(argstr, id) then begin
    FZLogMgr.Get.Write('Cannot parse ID', FZ_LOG_ERROR);
    exit;
  end;

  RemoteList_process(id, trim(argstr));
end;

function AnswerToHacker(hacker_id:cardinal):boolean; stdcall;
begin
  result:=false;
  if sysmsgs.IsExClientActionsSupported() then begin
    if FZConfigCache.Get().GetDataCopy().antihacker then begin
      FZLogMgr.Get.Write('Answering to hacker '+inttostr(hacker_id), FZ_LOG_INFO);
      RemoteList_process(hacker_id, 'antihacker.ini');
      result:=true;
    end;
  end;
end;

function Init():boolean;
begin
  if sysmsgs.IsExClientActionsSupported() then begin
{$IFNDEF RELEASE_BUILD}
    AddConsoleCommand('fz_remote_cs', @RemoteSingleSC_exec, @RemoteSingleSC_info);
    AddConsoleCommand('fz_remote_fr', @RemoteFR_exec, @RemoteFR_info);
{$ENDIF}
    AddConsoleCommand('fz_remote_list', @RemoteList_exec, @RemoteList_info);
  end;
  result:=true;
end;

end.

