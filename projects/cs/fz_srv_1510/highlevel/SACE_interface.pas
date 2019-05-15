unit SACE_interface;
{$MODE Delphi}
interface

type

FZUACPlayerInfo = packed record
  dwSize:cardinal;
  dwCheatFlags:cardinal;
  bOutdated:cardinal;
  bFullscreen:cardinal;
  Reserved:array[0..23] of cardinal;
end;
pFZUACPlayerInfo=^FZUACPlayerInfo;

FZGetUACPlayerInfo_fun = function (szHash_MD5:PAnsiChar; lpPlayerInfo:pFZUACPlayerInfo):boolean;stdcall; //NB: заставить нормально работать не вышло
FZGetUACPlayerInfoByID_fun = function (ID:cardinal; lpPlayerInfo:pFZUACPlayerInfo):boolean;stdcall;

const
  SACE_NOT_FOUND:integer=-10;
  SACE_OUTDATED:integer=0;
  SACE_UNSUPPORTED:integer=10;
  SACE_OK:integer = 20;


function GetSACEStatus(id:cardinal):integer; stdcall;
function GetSACEStatusForHash(hash:PAnsiChar):integer; stdcall;
function IsSaceSupportedByServer():boolean; stdcall;
function Init():boolean;

implementation
uses Windows, LogMgr, basedefs, sysutils;

var
  UACInfo:FZGetUACPlayerInfoByID_fun;
  UACHashInfo:FZGetUACPlayerInfo_fun;

function GetSACEStatus(id:cardinal):integer; stdcall;
var
  s:FZUACPlayerInfo;
begin
  if @UACInfo=nil then begin
    result:= SACE_UNSUPPORTED;
    exit;
  end;

  //Функция определения наличия античита по ID игрока работает так: по ID находит соответствующий объект IClient игрока,
  //затем вытаскивает оттуда поле m_guid (в которое игра записывает подтвержденный геймспаем хеш ключа игрока), и по этому
  //хешу где-то внутри себя проверяет, было ли получено на него подтверждение или нет.
  //Возможные проблемы:
  //1) В игре по локальной сети в оригинале поле m_guid не заполняется - соответственно, и у игроков наличие античита не отображается
  //2) В схеме HWID вместо хеша лицензионного ключа должен приходить HWID-хеш (равно как и подтверждение наличие АЧ должно отправляться для него). Если это будет не так - будут проблемы.
  
  s.dwSize:=sizeof(s);
  if UACInfo(id, @s) then begin
    if s.bOutdated>0 then begin
      result:=SACE_OUTDATED;
    end else begin
      result:=SACE_OK;
    end;
  end else begin
    result:=SACE_NOT_FOUND;
  end;
end;

function GetSACEStatusForHash(hash:PAnsiChar):integer; stdcall;
var
  s:FZUACPlayerInfo;
begin
  if @UACHashInfo=nil then begin
    result:= SACE_UNSUPPORTED;
    exit;
  end;

  s.dwSize:=sizeof(s);
  if UACHashInfo(hash, @s) then begin
    if s.bOutdated>0 then begin
      result:=SACE_OUTDATED;
    end else begin
      result:=SACE_OK;
    end;
  end else begin
    result:=SACE_NOT_FOUND;
  end;
end;

function IsSaceSupportedByServer():boolean; stdcall;
begin
  result:=(@UACInfo<>nil);
end;

function Init():boolean;
begin
  @UACInfo:=nil;
  if xrAPI<>0 then begin
    @UACInfo:=GetProcAddress(xrAPI, 'GetUACPlayerInfoByID');
    @UACHashInfo:=GetProcAddress(xrAPI, 'GetUACPlayerInfo');
  end else begin
    FZLogMgr.Get.Write('xrAPI module not found.', FZ_LOG_INFO);
  end;

  if (@UACInfo<>nil) and (@UACHashInfo<>nil) then begin
    FZLogMgr.Get.Write('Anticheat engine found.', FZ_LOG_INFO);
    FZLogMgr.Get.Write('SACE fun is '+inttohex(cardinal(@UACInfo),8), FZ_LOG_DBG);
  end else begin
    FZLogMgr.Get.Write('SACE not found.', FZ_LOG_INFO);
    //Занулим все для гарантии
    @UACInfo:=nil;
    @UACHashInfo:=nil;
  end;
  result:=true;  
end;

end.
