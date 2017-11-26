program FileListCreator;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, SysUtils, CustApp, FileLister;

type

{ FZFileListCreator }
  FZFileListCreator = class(TCustomApplication)
protected
  procedure DoRun; override;
public
  constructor Create(TheOwner: TComponent); override;
  destructor Destroy; override;
  procedure WriteHelp; virtual;
end;

{ FZFileListCreator }

procedure FZFileListCreator.DoRun;
var
  i,j:integer;
  lister:FZFileLister;
  outfile:string;
  root_link:string;
  tmp:string;
  f:textfile;
  usemd5:boolean;
begin
  if ParamCount<2 then begin
    WriteHelp;
    Terminate;
    Exit;
  end;

  lister:=FZFileLister.Create();
  outfile:='list.ini';
  root_link:='';
  usemd5:=false;

  i:=1;
  while (i<=ParamCount) do begin
    if Params[i]='-h' then begin
      WriteHelp;
      Terminate;
      Exit;
    end else if Params[i]='-d' then begin
      i:=i+1;
      if i > ParamCount then begin
        WriteLn('-d option requires an argument!');
        Terminate;
        Exit;
      end else begin
        WriteLn('Add scan path '+Params[i]);
        lister.ScanDir(Params[i]);
      end;
    end else if Params[i]='-o' then begin
      i:=i+1;
      if i > ParamCount then begin
        WriteLn('-o option requires an argument!');
        Terminate;
        Exit;
      end else begin
        WriteLn('Set output file '+Params[i]);
        outfile:=Params[i];
      end;
    end else if Params[i]='-l' then begin
      i:=i+1;
      if i > ParamCount then begin
        WriteLn('-l option requires an argument!');
        Terminate;
        Exit;
      end else begin
        WriteLn('Set root URL '+Params[i]);
        root_link:=Params[i];
      end;
    end else if Params[i]='-md5' then begin
      WriteLn('Force using MD5 checksum');
      usemd5:=true;
    end;
    i:=i+1;
  end;

  if lister.Count() = 0 then begin
    WriteLn('Scanning started..');
    lister.ScanDir('.\');
  end;

  WriteLn('Total ', lister.Count(), ' file(s) found. Start dumping to ', outfile, '...');
  assignfile(f, outfile);
  try
    rewrite(f);

    //List Header
    WriteLn(f, '[main]');
    WriteLn(f, 'files_count=', lister.Count());

    //File entries
    for i:=0 to lister.Count()-1 do begin
      WriteLn(f, '[file_',i,']');
      tmp:=lister.Get(i).RelativePath();
      WriteLn(f, 'path=',tmp);
      for j:=1 to length(tmp) do begin
        if tmp[j]='\' then tmp[j]:='/';
      end;
      WriteLn(f, 'url=',root_link+tmp);
      WriteLn(f, 'size=',lister.Get(i).Size());
      WriteLn(f, 'crc32=',inttohex(lister.Get(i).Crc32(), 8));
      if usemd5 then begin
        WriteLn(f, 'md5=',lister.Get(i).MD5());
      end;
    end;

    closefile(f);
    WriteLn('List is ready!');
  except
    WriteLn('ERROR: dumping failed due to exception!');
  end;

  lister.Free();
  Terminate;
end;

constructor FZFileListCreator.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  StopOnException:=True;
end;

destructor FZFileListCreator.Destroy;
begin
  inherited Destroy;
end;

procedure FZFileListCreator.WriteHelp;
begin
  writeln('Usage: ', ExeName);
  writeln('Options: ');
  writeln('-h Show this help');
  writeln('-d [directory] Scan specified directory');
  writeln('-o [file] Output file name');
  writeln('-l [link] Beginning of URL');
  writeln('-md5 Enable MD5 checksum');
end;

var
  Application: FZFileListCreator;
begin
  Application:=FZFileListCreator.Create(nil);
  Application.Title:='FZ File List Creator';
  Application.Run;
  Application.Free;
end.

