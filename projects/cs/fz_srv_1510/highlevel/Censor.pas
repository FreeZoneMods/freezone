unit Censor;
{$mode delphi}
interface
uses Contnrs, windows,RegExpr;

type
FZCensoredItem = class
public
  expr:string;
  is_valid:boolean;
  constructor Create(str:string);
end;


FZCensor = class
  _whitelist:TObjectList;
  _blacklist:TObjectList;
  _lock:TRtlCriticalSection;
  //_re:TRegExpr;

  procedure _ReplaceNonLiterals(var str: string);
public
  constructor Create;
  destructor Destroy; override;
  procedure ReloadDefaultFile();
  procedure Reload(fname:string);
  function CheckAndCensorString(str: PChar; do_censor:boolean; log_message:string): boolean;

  class function Get():FZCensor;
end;


function Init():boolean;
implementation
uses LogMgr, Sysutils;

var
  _instance:FZCensor;


function Init():boolean;
begin
  FZLogMgr.Get.Write('Using TRegExpr library ver.'+inttostr(TREgExpr.VersionMajor)+'.'+inttostr(TREgExpr.VersionMinor), FZ_LOG_IMPORTANT_INFO);
  _instance:=FZCensor.Create();
  result:=true;
end;

{ FZCensor }

function FZCensor.CheckAndCensorString(str: PChar; do_censor:boolean; log_message:string): boolean;
var
  msg:string;
  i,j:integer;
  _re:TRegExpr;
begin
  result:=false;
  msg:=' '+ansilowercase(str)+' ';
  _ReplaceNonLiterals(msg);
  EnterCriticalSection(_lock);
  try
    for i:=0 to _whitelist.Count-1  do begin
      _re:=TRegExpr.Create;
      _re.ModifierR;
      _re.Expression:=(_whitelist[i] as FZCensoredItem).expr;
      if _re.Exec(msg) then begin
        //Оно в белом списке
        _re.Free;
        result:=false;
        exit;
      end;
      _re.Free;
    end;
    
    for i:=0 to _blacklist.Count-1  do begin
      _re:=TRegExpr.Create;
      _re.ModifierR;
      _re.Expression:=(_blacklist[i] as FZCensoredItem).expr;
      if _re.Exec(msg) then begin
        //Оно в черном списке
        if length(log_message)>0 then begin
          FZLogMgr.Get.Write(log_message+str, FZ_LOG_INFO);
        end;

        result:=true;
        j:=0;
        if do_censor then begin
          while str[j]<>chr(0) do begin
            str[j]:='*';
            j:=j+1;
          end;
        end;
        _re.Free;
        exit;
      end;
      _re.Free;
    end;
  finally
    LeaveCriticalSection(_lock);
  end;
end;

constructor FZCensor.Create;
begin
  InitializeCriticalSection(_lock);
  _whitelist:=TObjectList.Create();
  _blacklist:=TObjectList.Create();
//  _re:=TRegExpr.Create();
//  _re.ModifierR;
  ReloadDefaultFile();
end;

destructor FZCensor.Destroy;
begin
  DeleteCriticalSection(_lock);
//  _re.Free;
  _whitelist.free;
  _blacklist.Free;
end;

class function FZCensor.Get: FZCensor;
begin
  result:=_instance;
end;

procedure FZCensor.Reload(fname: string);
var
  f:textfile;
  cur_list:TObjectList;
  str:string;
  itm:FZCensoredItem;
begin
  EnterCriticalSection(_lock);
  try
    _whitelist.Clear;
    _blacklist.Clear;
    cur_list:=self._blacklist;
    assignfile(f, fname);
    try
      reset(f);
    except
      FZLogMgr.Get.Write('Cannot open file '+ fname+' for reading. Check existance!', FZ_LOG_ERROR);
      exit;    
    end;

    while not eof(f) do begin
      readln(f, str);
      str:=trim(str);
      if str='[whitelist]' then begin
        cur_list:=self._whitelist;
      end else if str='[blacklist]' then begin
        cur_list:=self._blacklist;
      end else begin
        itm:=FZCensoredItem.Create(str);
        if itm.is_valid then begin
          cur_list.Add(itm);
        end else begin
          itm.Free;
        end;
      end;
    end;

    closefile(f);
  finally
    LeaveCriticalSection(_lock);
  end;
end;

procedure FZCensor.ReloadDefaultFile;
begin
  FZLogMgr.Get.Write('Loading banned expressions...', FZ_LOG_INFO);
  Reload('fz_censored.ini');
  FZLogMgr.Get.Write('Found '+inttostr(self._blacklist.Count)+' banned expression(s)', FZ_LOG_INFO);
  FZLogMgr.Get.Write('Found '+inttostr(self._whitelist.Count)+' whitelisted expression(s)', FZ_LOG_INFO);
end;

procedure FZCensor._ReplaceNonLiterals(var str: string);
const
  REMOVEDSYMBOLS:string = '.,:;"/\|!#$%^&*()[]{}<>+-_=?';
var
  i:integer;
begin
  for i:=1 to length(str) do begin
    if pos(str[i], REMOVEDSYMBOLS)<>0 then begin
      str[i]:=' ';
    end;
  end;  
end;

{ FZCensoredItem }

constructor FZCensoredItem.Create(str: string);
begin
  if (length(str)=0) or ((length(str)>=2) and (str[1]='/') and (str[2]='/')) then begin
    self.is_valid:=false;
  end else begin
    self.expr:=str;
    self.is_valid:=true;
  end;
end;

end.
