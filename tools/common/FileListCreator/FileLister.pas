unit FileLister;

{$mode objfpc}{$H+}

interface

type

{ FZFileItem }

FZFileItem = class
public
  constructor Create(root, dir, name:string);
  function Size():cardinal;
  function RelativePath():string;
  function Crc32(): cardinal;
  function MD5(): string;
protected
  _full_name:string;
  _relative_name:string;
  _short_name:string;
end;

{ FZFileLister }

FZFileLister = class
protected
  _files:array of FZFileItem;

  procedure _Scan(root:string; path:string);
public
  constructor Create();
  destructor Destroy(); override;
  procedure Clear();
  procedure ScanDir(root:string);
  function Count():integer;
  function Get(index:integer):FZFileItem;
end;

implementation
uses Windows, FastCrc, FastMd5;

{ FZFileItem }

constructor FZFileItem.Create(root, dir, name: string);
begin
  inherited Create();
  _short_name:=name;
  _relative_name:=dir+name;
  _full_name:=root+dir+name;
end;

function FZFileItem.Size: cardinal;
var
  file_handle, mapping_handle:cardinal;
begin
  file_handle:=CreateFile(PAnsiChar(self._full_name), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if (file_handle<>INVALID_HANDLE_VALUE) then begin
    result:=GetFileSize(file_handle, nil);
    CloseHandle(file_handle);
  end;
end;

function FZFileItem.RelativePath: string;
begin
  result:=self._relative_name;
end;

function FZFileItem.Crc32: cardinal;
begin
  result:=GetFileCRC32(self._full_name);

end;

function FZFileItem.MD5: string;
var
  file_handle, mapping_handle:cardinal;
  ptr:PChar;
  filesize, bufsize, readbytes:cardinal;
begin
  result:='';
  filesize:=Size();
  bufsize:= ((filesize div 64)+2)*64;
  GetMem(ptr, bufsize);
  file_handle:=CreateFile(PAnsiChar(self._full_name), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if (file_handle<>INVALID_HANDLE_VALUE) and (ptr<>nil) then begin
    if ReadFile(file_handle, ptr[0], filesize, readbytes, nil) and (readbytes=filesize) then begin
      result:=CalcMD5(ptr, filesize, bufsize);
    end;
  end;
  CloseHandle(file_handle);

  FreeMem(ptr);
end;

{ FZFileLister }
constructor FZFileLister.Create;
begin
  inherited;
  SetLength(_files, 0);
end;

destructor FZFileLister.Destroy;
begin
  Clear();
  inherited;
end;

procedure FZFileLister.Clear;
var
  i:integer;
begin
  for i:=0 to length(_files)-1 do begin
    _files[i].Free;
  end;
  SetLength(_files, 0);
end;

procedure FZFileLister._Scan(root:string; path: string);
var
  hndl:THandle;
  data:WIN32_FIND_DATA;
  name:string;
begin
  name:=root+path+'*.*';
  hndl:=FindFirstFile(PAnsiChar(name), @data);
  if hndl = INVALID_HANDLE_VALUE then exit;

  repeat
    name := PAnsiChar(@data.cFileName[0]);
    if  (name = '.') or (name='..') then continue;

    if (data.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY <> 0) then begin
      _Scan(root, path+name+'\');
    end else begin
      SetLength(_files, length(_files)+1);
      _files[length(_files)-1]:=FZFileItem.Create(root, path, name);
    end;
  until not FindNextFile(hndl, @data);

  FindClose(hndl);
end;

procedure FZFileLister.ScanDir(root: string);
begin
  if (root[length(root)]<>'\') and (root[length(root)]<>'/') then begin
    root:=root+'\';
  end;
  _Scan(root, '');
end;

function FZFileLister.Count: integer;
begin
  result:=length(_files);
end;

function FZFileLister.Get(index: integer): FZFileItem;
begin
  assert(index < Count(), 'Invalid file index');
  result:=_files[index];
end;

end.

