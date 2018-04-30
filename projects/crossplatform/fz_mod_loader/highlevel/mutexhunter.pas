unit mutexhunter;

{$mode delphi}

interface
procedure KillMutex();

implementation
uses LogMgr, windows, sysutils;
////////////////////////////////////////////////////////////////////////////////
type
  TNtInfo = pointer;

  NTStatus = cardinal;
  PVOID    = pointer;
  USHORT = WORD;
  UCHAR = byte;
  ULONG = cardinal;
  PWSTR = PWideChar;
  ULONG_PTR = UIntPtr;

SYSTEM_HANDLE_TABLE_ENTRY_INFO = packed record
  UniqueProcessId:USHORT;
  CreatorBackTraceIndex:USHORT;
  ObjectTypeIndex:UCHAR;
  HandleAttributes:UCHAR;
  HandleValue:USHORT;
  pObject:PVOID;
  GrantedAccess:ULONG;
end;
pSYSTEM_HANDLE_TABLE_ENTRY_INFO=^SYSTEM_HANDLE_TABLE_ENTRY_INFO;

SYSTEM_HANDLE_INFORMATION = packed record
  NumberOfHandles:ULONG;
  Handles:SYSTEM_HANDLE_TABLE_ENTRY_INFO;
end;
pSYSTEM_HANDLE_INFORMATION=^SYSTEM_HANDLE_INFORMATION;

SYSTEM_HANDLE_TABLE_ENTRY_INFO_EX = packed record
   pObject:pointer;
   UniqueProcessId:ULONG_PTR;
   HandleValue:ULONG_PTR;
   GrantedAccess:ULONG;
   CreatorBackTraceIndex:USHORT;
   ObjectTypeIndex:USHORT;
   HandleAttributes:ULONG;
   Reserved:ULONG;
end;
pSYSTEM_HANDLE_TABLE_ENTRY_INFO_EX = {%H-}^SYSTEM_HANDLE_TABLE_ENTRY_INFO_EX;

SYSTEM_HANDLE_INFORMATION_EX = packed record
  NumberOfHandles:ULONG_PTR;
  Reserved:ULONG_PTR;
  Handles:SYSTEM_HANDLE_TABLE_ENTRY_INFO_EX;
end;
pSYSTEM_HANDLE_INFORMATION_EX={%H-}^SYSTEM_HANDLE_INFORMATION_EX;

UNICODE_STRING = packed record
  Length:USHORT;
  MaximumLength:USHORT;
  Buffer:PWSTR;
end;
pUNICODE_STRING=^UNICODE_STRING;

const
  STATUS_SUCCESS              = NTStatus($00000000);
  {%H-}STATUS_ACCESS_DENIED        = NTStatus($C0000022);
  STATUS_INFO_LENGTH_MISMATCH = NTStatus($C0000004);

  ObjectNameInformation:cardinal = 1;
  SystemHandleInformation:cardinal = $10;
  {%H-}SystemExtendedHandleInformation = $40;

function NtQuerySystemInformation(ASystemInformationClass: dword;
                                  ASystemInformation: Pointer;
                                  ASystemInformationLength: dword;
                                  AReturnLength:PCardinal): NTStatus;
                                  stdcall; external 'ntdll.dll';

function NtQueryObject(ObjectHandle: THandle;
                       ObjectInformationClass:
                       DWORD; ObjectInformation: Pointer;
                       ObjectInformationLength:
                       ULONG; ReturnLength: PDWORD): NTStatus; stdcall; external 'ntdll.dll';

////////////////////////////////////////////////////////////////////////////////
function GetNtSystemInfo(ATableType:dword):TNtInfo;
var
  mSize: dword;
  mPtr: pointer;
  St: NTStatus;
begin
  Result := nil;
  mSize := $4000; //начальный размер буфера

  repeat
    mPtr := VirtualAlloc(nil, mSize, MEM_COMMIT or MEM_RESERVE, PAGE_READWRITE);
    if mPtr = nil then Exit;
    St := NtQuerySystemInformation(ATableType, mPtr, mSize, nil);
    if St = STATUS_INFO_LENGTH_MISMATCH then begin //надо больше памяти
         VirtualFree(mPtr, 0, MEM_RELEASE);
         mSize := mSize * 2;
    end;
  until St <> STATUS_INFO_LENGTH_MISMATCH;

  if St = STATUS_SUCCESS then begin
    Result := mPtr;
  end else begin
    VirtualFree(mPtr, 0, MEM_RELEASE);
  end;
end;

function GetNtObjectInfo(hndl:THandle; info_type:dword):TNtInfo;
var
  mSize: dword;
  mPtr: pointer;
  St: NTStatus;
begin
  Result := nil;
  mSize := $4000; //начальный размер буфера

  repeat
    mPtr := VirtualAlloc(nil, mSize, MEM_COMMIT or MEM_RESERVE, PAGE_READWRITE);
    if mPtr = nil then Exit;
    St := NtQueryObject(hndl, info_type, mPtr, mSize, nil);
    if St = STATUS_INFO_LENGTH_MISMATCH then begin //надо больше памяти
         VirtualFree(mPtr, 0, MEM_RELEASE);
         mSize := mSize * 2;
    end;
  until St <> STATUS_INFO_LENGTH_MISMATCH;

  if St = STATUS_SUCCESS then begin
    Result := mPtr;
  end else begin
    VirtualFree(mPtr, 0, MEM_RELEASE);
  end;
end;

procedure FreeNtInfo(tbl:TNtInfo);
begin
  if tbl<>nil then begin
    VirtualFree(tbl, 0, MEM_RELEASE);
  end;
end;

function StrPosW(const Str, SubStr: PWideChar): PWideChar;
var
  P: PWideChar;
  I: SizeInt;
begin
  Result := nil;
  if (Str = nil) or (SubStr = nil) or (Str^ = #0) or (SubStr^ = #0) then
    Exit;
  Result := Str;
  while Result^ <> #0 do
  begin
    if Result^ <> SubStr^ then
      Inc(Result)
    else
    begin
      P := Result + 1;
      I := 1;
      while (P^ <> #0) and (P^ = SubStr[I]) do
      begin
        Inc(I);
        Inc(P);
      end;
      if SubStr[I] = #0 then
        Exit
      else
        Inc(Result);
    end;
  end;
  Result := nil;
end;

procedure KillMutex();
var
  mutex:THandle;
  info, objinfo:TNtInfo;
  i:cardinal;
  entry:pSYSTEM_HANDLE_TABLE_ENTRY_INFO;

  mutex_object_type:integer;
  curprocid:cardinal;
const
  MUTEX_A:PAnsiChar = 'STALKER-SoC';
  MUTEX_W:PWideChar = 'STALKER-SoC';
begin
  mutex := OpenMutex(SYNCHRONIZE, false, MUTEX_A );
  if mutex = 0 then exit;

  info:=GetNtSystemInfo(SystemHandleInformation);
  if (info = nil) or (pSYSTEM_HANDLE_INFORMATION(info).NumberOfHandles=0) then begin
    FZLogMgr.Get.Write('GetInfoTable failed', FZ_LOG_ERROR);
    exit;
  end;

  mutex_object_type:=-1;
  curprocid:=GetCurrentProcessId();
  for i:=pSYSTEM_HANDLE_INFORMATION(info).NumberOfHandles-1 downto 0 do begin
    entry:= pointer(uintptr(@(pSYSTEM_HANDLE_INFORMATION(info).Handles)) + uintptr(i*sizeof(SYSTEM_HANDLE_TABLE_ENTRY_INFO)));
    if (entry.UniqueProcessId = curprocid ) then begin
      if (mutex = entry.HandleValue) then begin
        mutex_object_type:=entry.ObjectTypeIndex;
        break;
      end;
    end;
  end;
  CloseHandle(mutex);
  FreeNtInfo(info);

  if mutex_object_type < 0 then begin
    FZLogMgr.Get.Write('Cannot determine mutex object type', FZ_LOG_ERROR);
    exit;
  end;

  info:=GetNtSystemInfo(SystemHandleInformation);
  if (info = nil) or (pSYSTEM_HANDLE_INFORMATION(info).NumberOfHandles=0) then begin
    FZLogMgr.Get.Write('GetInfoTable failed (2)', FZ_LOG_ERROR);
    exit;
  end;

  mutex:=0;
  for i:=0 to pSYSTEM_HANDLE_INFORMATION(info).NumberOfHandles-1 do begin
    entry:= pointer(uintptr(@(pSYSTEM_HANDLE_INFORMATION(info).Handles)) + uintptr(i*sizeof(SYSTEM_HANDLE_TABLE_ENTRY_INFO)));
    if ( entry.ObjectTypeIndex = mutex_object_type) and (entry.UniqueProcessId = curprocid) then begin
      mutex:=entry.HandleValue;
      objinfo:=GetNtObjectInfo(mutex, ObjectNameInformation);
      if objinfo=nil then continue;

      if StrPosW(pUNICODE_STRING(objinfo).Buffer, MUTEX_W) <> nil then begin
        FZLogMgr.Get.Write('Mutex found, deleting', FZ_LOG_DBG);
        FreeNtInfo(objinfo);
        CloseHandle(mutex);
        break;
      end else begin
        FreeNtInfo(objinfo);
        mutex:=0;
      end;
    end;
  end;

  if mutex = 0 then begin
    FZLogMgr.Get.Write('Cannot find mutex', FZ_LOG_ERROR);
  end;
  FreeNtInfo(info);
end;

end.

