unit Battleye;
{$mode delphi}
interface
uses xrstrings;

type

BattlEyeClient = packed record
//todo:fill
end;
pBattlEyeClient = ^BattlEyeClient;

BattlEyeServer = packed record
//todo:fill
end;
pBattlEyeServer = ^BattlEyeServer;

BattlEyeSystem = packed record
  m_server_path:shared_str;
  m_client_path:shared_str;
  m_test_load_client:byte; {bool}
  _unused1:byte;
  _unused2:word;
  client:pBattlEyeClient;
  server:pBattlEyeServer;
end;


implementation

end.
