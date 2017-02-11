unit ConfigBase;

{$mode delphi}

interface
uses SysUtils, syncobjs, LazUTF8;

{$DEFINE 1USE_CUSTOM_IMPL}

type
  FZConfigBase = class
     function GetValue(str: string):string;
     function GetKey(str: string):string;
    public
     constructor Create();
     procedure Load(FName:string);
     function GetData(Key:string; var Value:string):boolean;
     function GetBool(Key:string; default:boolean = false):boolean;
     function GetInt(Key:string; default:integer = 0):integer;
     function GetString(key:string; default:string = ''):string;     
     procedure SetData(Key:string; Value:string);
     procedure Save();
     procedure Reload();
     function IsSaved():boolean;
    protected
     _filename:string;


{$IFDEF USE_CUSTOM_IMPL}
{$IFDEF USE_TMREWS}
     _lock:TMultiReadExclusiveWriteSynchronizer;
{$ELSE}
     _cs:TCriticalSection;
{$ENDIF}
     _keys:array of string;
     _values:array of string;
     _size:integer;
     _is_saved:boolean;
{$ELSE}
     _full_path:string;
{$ENDIF}

    procedure _BeginRead();
    procedure _EndRead();
    procedure _BeginWrite();
    procedure _EndWrite();
  end;

implementation
uses Windows, CommonHelper, LogMgr;


constructor FZConfigBase.Create();
begin
  inherited;
  self._filename:='';

{$IFDEF USE_CUSTOM_IMPL}
{$IFDEF USE_TMREWS}
  _lock:=TMultiReadExclusiveWriteSynchronizer.Create;
{$ELSE}
  _cs:=TCriticalSection.Create;
{$ENDIF}
{$ELSE}
self._full_path:='';
{$ENDIF}
end;

{$IFDEF USE_CUSTOM_IMPL}
procedure FZConfigBase.Load(FName:string);
var
  f:textfile;
  t:string;
begin
  self._BeginWrite;
  try
    setlength(_keys, 0);
    setlength(_values, 0);
    _size:=0;
    _filename :=FName;
    try
      assignfile(f, FName);
      reset(f);

      while not eof(f) do begin
       readln(f,t);
        if pos('=',t)>0 then begin
          setlength(_keys, _size+1);
          setlength(_values, _size+1);
          _keys[_size] := lowercase(GetKey(t));
          _values[_size]:= GetValue(t);
          _size:=_size+1;
        end;
      end;
      closefile(f);
      _is_saved :=true;
    except
      _is_saved :=false;
    end;
  finally
    self._EndWrite;
  end;
end;

function FZConfigBase.GetValue(str: string):string;
var
  i:integer;
  after_last_equals:string;
  tmp:string;

begin
  self._BeginRead;
  try
    result:='';

    after_last_equals:='';
    tmp:='';
    
    for i:=length(str) downto 1 do begin
       if str[i] = ';' then begin
        after_last_equals:='';
        tmp:='';
      end else if str[i] = '=' then begin
        after_last_equals:= trim(tmp);
        tmp:=str[i]+tmp;
      end else begin
        tmp:=str[i]+tmp;
      end;
    end;

    result:=after_last_equals;
  finally
    self._EndRead;
  end;
end;

function FZConfigBase.GetKey(str: string):string;
var i:integer;
begin
  result:='';
  self._BeginRead;
  try
    for i:=1 to length(str) do begin
      if str[i] = '=' then begin
        result:= trim(result);
        exit;
      end else begin
        result:=result + str[i];
      end;
    end
  finally
    self._EndRead;
  end;
end;

function FZConfigBase.GetData(Key:string; var Value:string):boolean;
var
  i:integer;
begin
  self._BeginRead;
  try
    result:=false;
    key := lowercase(key);
    for i:=_size-1 downto 0 do begin
      if lowercase(_keys[i]) = key then begin
        value:=_values[i];
        result:=true;
        break;
      end;
    end;
  finally
    self._EndRead;
  end;
end;

procedure FZConfigBase.SetData(Key:string; Value:string);
var
  success:boolean;
  i:integer;
begin
  self._BeginWrite;
  try
    success:=false;
    for i:=_size-1 downto 0 do begin
      if _keys[i] = key then begin
        _values[i]:=value;
        success:=true;
        break;
      end;
    end;
    if not success then begin
      setlength(_keys, _size+1);
      setlength(_values, _size+1);
      _keys[_size]:=Key;
      _values[_size]:=Value;
      _size:=_size+1;
    end;
    _is_saved :=false;
  finally
    self._EndWrite;
  end;
end;

procedure FZConfigBase.Save();
var
  i:integer;
  f:textfile;
begin
  self._BeginRead;
  try
    assignfile(f, _filename);
    rewrite(f);
    for i:=0 to _size-1 do begin
       writeln(f, _keys[i],' = ', _values[i]);
    end;
    closefile(f);
    _is_saved :=true;
  finally
    self._EndRead;
  end;
end;

function FZConfigBase.IsSaved: boolean;
begin
  result:= _is_saved;
end;

procedure FZConfigBase._BeginRead();
begin
{$IFDEF USE_TMREWS}
  _lock.BeginRead;
{$ELSE}
  _cs.Enter;
{$ENDIF}
end;

procedure FZConfigBase._EndRead();
begin
{$IFDEF USE_TMREWS}
  _lock.EndRead;
{$ELSE}
  _cs.Leave
{$ENDIF}
end;

procedure FZConfigBase._BeginWrite();
begin
{$IFDEF USE_TMREWS}
  _lock.BeginWrite;
{$ELSE}
  _cs.Enter;
{$ENDIF}
end;

procedure FZConfigBase._EndWrite();
begin
{$IFDEF USE_TMREWS}
  _lock.EndWrite;
{$ELSE}
  _cs.Leave
{$ENDIF}
end;

{$ELSE}
procedure FZConfigBase.Load(FName:string);
begin
  self._filename:=FName;
  self._full_path:= Utf8ToWinCP(GetCurrentDir())+'\'+FName;
end;


function FZConfigBase.GetValue(str: string):string;
begin
  assert(false, 'NOT IMPLEMENTED!');
end;

function FZConfigBase.GetKey(str: string):string;
begin
  assert(false, 'NOT IMPLEMENTED!');
end;

procedure FZConfigBase.SetData(Key:string; Value:string);
begin
  assert(false, 'NOT IMPLEMENTED!');
end;

procedure FZConfigBase.Save();
begin
  assert(false, 'NOT IMPLEMENTED!');
end;

function FZConfigBase.IsSaved: boolean;
begin
  assert(false, 'NOT IMPLEMENTED!');
  result:=false;
end;

procedure FZConfigBase._BeginRead();
begin
end;

procedure FZConfigBase._EndRead();
begin
end;

procedure FZConfigBase._BeginWrite();
begin
end;

procedure FZConfigBase._EndWrite();
begin
end;


function FZConfigBase.GetData(Key: string; var Value: string): boolean;
var
  arr:PAnsiChar;
  i, res:cardinal;
  flag:boolean;
  tmp:string;
begin
  i:=128;
  repeat
    i:=i*2;
    GetMem(arr, i);
    res:=GetPrivateProfileString('main', PAnsiChar(Key),nil, @arr[0], 1024, PAnsiChar(_full_path));
    flag:= (res=i-1);
    if flag then FreeMem(arr, i);
  until not flag;

  tmp:=string(arr)+';';
  FZCommonHelper.GetNextParam(tmp, Value, ';');
  Value:=trim(Value);

  result:=(res>0);

  FreeMem(arr, i);
end;

{$ENDIF}


function FZConfigBase.GetBool(Key:string; default:boolean = false):boolean;
var
  temp:string;
begin
  result:=default;
  if GetData(Key, temp) then begin
    if (lowercase(temp)='true') or (lowercase(temp)='on') or (lowercase(temp)='1') then
      result:=true
    else
      result:=false;
  end;
end;

function FZConfigBase.GetString(key:string; default:string = ''):string;
var
  temp:string;
begin
  result:=default;
  if GetData(Key, temp) then begin
    result:=temp;
  end;
end;

function FZConfigBase.GetInt(Key:string; default:integer = 0):integer;
var
  temp:string;
begin
  result:=default;

  if GetData(Key, temp) then begin
    try
      result:=strtoint(temp);
    except
      result:=default;
    end;
  end;
end;

procedure FZConfigBase.Reload();
begin
  Load(_filename);
end;


end.


