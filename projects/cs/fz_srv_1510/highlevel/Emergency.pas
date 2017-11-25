unit Emergency;
{$mode delphi}
interface

function Init():boolean; stdcall;

implementation
uses Windows, Console, Sysutils;

procedure reboot_cmd_info(arg:PChar); stdcall;
begin
  strcopy(arg, 'Reboots the machine. USE ONLY WHEN SITUATION IS TOTALLY BAD!');
end;

procedure reboot_cmd_execute({%H-}arg:PChar); stdcall;
begin
  ShellExecute(0, nil, 'c:\windows\system32\shutdown.exe', '/r /t 0 /d u:4:6 /f /c "[Freezone Server] Admin running reboot command."', nil, SW_HIDE);
end;

function Init():boolean; stdcall;
begin
  AddConsoleCommand('fz_server_emergency_reboot', reboot_cmd_execute, reboot_cmd_info);
  result:=true;
end;

end.
