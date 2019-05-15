unit ConfigBase;

{$mode delphi}

interface
uses SysUtils, INIFiles, LazUTF8, SyncObjs;

type

  { FZConfigBase }

  FZConfigBase = class
    public
     constructor Create();
     destructor Destroy(); override;
     function Load(FName:string):boolean;
     function GetData(Key:string; var Value:string; section:string = 'main'):boolean;
     function GetBool(Key:string; default:boolean = false; section:string = 'main'):boolean;
     function GetInt(Key:string; default:integer = 0; section:string = 'main'):integer;
     function GetFloat(Key:string; default:single = 0; section:string = 'main'):single;
     function GetString(key:string; default:string = ''; section:string = 'main'):string;
     function IsSectionExist(section:string):boolean;
     function IsKeyExist(section:string; key:string):boolean;

     procedure Reload();
    protected
     _lock:TCriticalSection;
     _filename:string;
     _full_path:string;
     _inifile:TIniFile;
  end;

implementation
uses CommonHelper;

constructor FZConfigBase.Create();
begin
  inherited;
  _lock:=SyncObjs.TCriticalSection.Create();
  self._filename:='';
  self._full_path:='';
  _inifile:=nil;
end;

destructor FZConfigBase.Destroy();
begin
  _inifile.Free();
  _lock.Free();
  inherited Destroy;
end;

function FZConfigBase.Load(FName:string):boolean;
begin
  result:=false;
  _lock.Enter();

  self._filename:=FName;
  self._full_path:=GetCurrentDir()+'\'+FName;
  if _inifile<>nil then begin
    _inifile.Free();
  end;

  try
    _inifile:=TIniFile.Create(_full_path, [ifoStripComments, ifoStripInvalid] );
    result:=true;
  except
    _inifile:=nil;
    result:=false;
  end;

  _lock.Leave();
end;

function FZConfigBase.IsSectionExist(section: string): boolean;
begin
  _lock.Enter();
  result:=_inifile.SectionExists(section);
  _lock.Leave();
end;

function FZConfigBase.IsKeyExist(section: string; key: string): boolean;
begin
  _lock.Enter;
  result:=IsSectionExist(section) and _inifile.ValueExists(section, key);
  _lock.Leave;
end;

function FZConfigBase.GetData(Key: string; var Value: string; section:string = 'main'): boolean;
var
  tmp:string;
begin
  result:=false;

  _lock.Enter();
  if (_inifile<>nil) and _inifile.SectionExists(section) and _inifile.ValueExists(section, key) then begin
    Value:=_inifile.ReadString(section, key, '');

    tmp:=Value+';';
    FZCommonHelper.GetNextParam(tmp, Value, ';');
    Value:=trim(Value);

    if length(Value)>0 then begin
      result:=true;
    end;
  end;
  _lock.Leave();
end;

function FZConfigBase.GetBool(Key:string; default:boolean = false; section:string = 'main'):boolean;
var
  temp:string;
begin
  result:=default;
  if GetData(Key, temp, section) then begin
    if (lowercase(temp)='true') or (lowercase(temp)='on') or (lowercase(temp)='1') then
      result:=true
    else
      result:=false;
  end;
end;

function FZConfigBase.GetString(key:string; default:string = ''; section:string = 'main'):string;
var
  temp:string;
begin
  result:=default;
  if GetData(Key, temp, section) then begin
    result:=temp;
  end;
end;

function FZConfigBase.GetInt(Key:string; default:integer = 0; section:string = 'main'):integer;
var
  temp:string;
begin
  if GetData(Key, temp, section) then begin
    result:=strtointdef(temp, default);
  end else begin
    result:=default;
  end;
end;

function FZConfigBase.GetFloat(Key: string; default: single; section: string): single;
var
  temp:string;
begin
  if GetData(Key, temp, section) then begin
    result:=FZCommonHelper.StringToFloatDef(temp, default);
  end else begin
    result:=default;
  end;
end;

procedure FZConfigBase.Reload();
begin
  Load(_filename);
end;

end.


