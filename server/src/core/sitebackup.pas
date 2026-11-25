unit SiteBackup;

{ ZIP backup, check and restore jobs, one at a time, from the admin page or
  command line. Restore pauses other requests and preserves sessions; the
  saved config is left for the admin to install. Archive layout and requests
  are in docs/API.md. }

{$mode objfpc}{$H+}

interface

{ The command line's backup and restore: the same jobs, run to the end in the
  caller's thread, with each step printed. }
function CommandLineBackup(WithPictures, WithLogs: boolean): boolean;
function CommandLineRestore(const Path: string): boolean;

{ A top-level folder of data/ the program makes again on its own (a static
  copy, a cache): left out of every backup and never put back. }
procedure LeaveOutOfBackups(const Folder: string);

implementation

uses
  {$ifdef unix} Unix, BaseUnix, {$endif} SysUtils, Classes, StrUtils, DateUtils, Variants, DB, sqldb, zipper, fpjson, httpdefs, httproute,
  SiteDb, SiteUsers, SiteRoles, SiteAdmin, SiteGuard, SiteStats, SiteBell, WebPages, SiteSql;

const
  { the first line of a backup's database file }
  FORMAT_LINE = '-- exedra backup 2';
  TABLE_MARK = '-- table `';
  BATCH_BYTES = 800 * 1024;
  { one row's statement at most: under MariaDB's usual 16 MB packet }
  ROW_BYTES = 12 * 1024 * 1024;
  { a piece of an upload: under the server's 32 MB body cap, and small enough
    to send again quickly when a connection drops }
  CHUNK_BYTES = 8 * 1024 * 1024;
  { tables that are the moment's, not the site's: not put back }
  NOT_RESTORED: array[0..3] of string = ('sessions', 'attempts', 'presence', 'typing');

type
  TJobKind = (jkNone, jkBackup, jkRestore, jkCheck);

  TBackupJob = class(TThread)
    Kind: TJobKind;
    Name, By: string;
    Pictures, Logs: boolean;
    procedure Execute; override;
  end;

var
  Remade: TStringList;
  JobLock: TRTLCriticalSection;
  JobKind: TJobKind = jkNone;
  JobStep, JobError, JobLast, JobBy: string;
  JobStarted: TDateTime;
  { the command line runs the job itself and wants to see the steps }
  Console: boolean = False;
  { what the page learned about each file, by name: the manifest's summary
    (read once per size and time) and the last check's outcome, kept in
    data/backups/checks.json so a restart does not forget the checks }
  Known: TStringList;

{ A folder only the service's user can open, from the moment it is made:
  backups hold the config (the database password) and the data folder
  (keys), and so do their unpacked copies. }
procedure PrivateFolder(const Folder: string);
{$ifdef unix}
var
  Path: string;
begin
  Path := ExcludeTrailingPathDelimiter(Folder);
  if not DirectoryExists(Path) then
  begin
    ForceDirectories(ExtractFileDir(Path));
    fpMkdir(Path, &700);
  end;
  // one made before, with the usual permissions
  fpChmod(Path, &700);
end;
{$else}
begin
  ForceDirectories(Folder);
end;
{$endif}

{ An empty file only the service's user can read, made before a writer
  opens it with fmCreate, which keeps the mode of a file that is there. }
procedure PrivateFile(const Path: string);
{$ifdef unix}
var
  Handle: cint;
begin
  Handle := fpOpen(Path, O_WRONLY or O_CREAT or O_TRUNC, &600);
  if Handle >= 0 then
    fpClose(Handle);
  fpChmod(Path, &600);
end;
{$else}
begin
end;
{$endif}

function BackupsFolder: string;
begin
  Result := FilesRoot + 'data' + PathDelim + 'backups' + PathDelim;
  PrivateFolder(Result);
end;

function IsoUtc(When: TDateTime): string;
begin
  Result := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', When);
end;

{ A small text file as a string; '' when it is not there. }
function SmallFile(const Path: string): string;
begin
  Result := '';
  if not FileExists(Path) then
    Exit;
  with TStringList.Create do
  try
    LoadFromFile(Path);
    Result := Text;
  finally
    Free;
  end;
end;

function SizeOfFile(const Path: string): int64;
var
  Entry: TSearchRec;
begin
  Result := 0;
  if FindFirst(Path, faAnyFile, Entry) = 0 then
  begin
    Result := Entry.Size;
    FindClose(Entry);
  end;
end;

function SizeWords(Bytes: int64): string;
begin
  if Bytes >= 1024 * 1024 * 1024 then
    Result := FormatFloat('0.0', Bytes / (1024 * 1024 * 1024)) + ' GB'
  else if Bytes >= 1024 * 1024 then
    Result := IntToStr(Bytes div (1024 * 1024)) + ' MB'
  else
    Result := IntToStr(Bytes div 1024) + ' KB';
end;

procedure SetStep(const Step: string);
begin
  EnterCriticalSection(JobLock);
  try
    JobStep := Step;
  finally
    LeaveCriticalSection(JobLock);
  end;
  if Console then
    WriteLn(Step);
end;

procedure LeaveOutOfBackups(const Folder: string);
begin
  if Remade.IndexOf(Folder) < 0 then
    Remade.Add(Folder);
end;

{ The top-level names of data/ a backup passes over: its own folder, the
  folders the program remakes, and the logs unless asked for. }
function SkippedFolders(WithLogs: boolean): TStringArray;
var
  I: integer;
begin
  Result := ['backups'];
  if not WithLogs then
    Result := Concat(Result, ['logs']);
  for I := 0 to Remade.Count - 1 do
    Result := Concat(Result, [Remade[I]]);
end;

{ A path inside an archive that stays inside the folder it is unpacked to:
  relative, with no step up.  Two dots inside a name (a wiki page called
  WHILE..DO) are fine; a part that is only two dots is not. }
function SafePath(const Path: string): boolean;
var
  Part: string;
begin
  Result := (Path <> '') and not (Path[1] in ['/', '\']) and (Pos(':', Path) = 0);
  if Result then
    for Part in Path.Split(['/', '\']) do
      if Part = '..' then
        Exit(False);
end;

{ A file name as the admin page may name it: ours, with nothing of a path. }
function SafeName(const Name: string): boolean;
var
  C: char;
begin
  Result := (Length(Name) >= 5) and (Length(Name) <= 120) and EndsText('.zip', Name) and (Pos('..', Name) = 0) and (Name[1] <> '.');
  if Result then
    for C in Name do
      if not (C in ['a'..'z', 'A'..'Z', '0'..'9', '.', '-', '_']) then
        Exit(False);
end;

// ---- writing the database out

{ The file holds no table definitions: only each table's name, its
  columns and its rows, so a backup made on one database server goes back
  on another.  The values are written as MariaDB writes them: text in
  quotes with backslash escapes, NULL, plain numbers, bytes as 0x and hex
  digits. }

function SqlText(const S: string): string;
var
  C: char;
begin
  Result := '''';
  for C in S do
    case C of
      '\': Result := Result + '\\';
      '''': Result := Result + '\''';
      #0: Result := Result + '\0';
      #10: Result := Result + '\n';
      #13: Result := Result + '\r';
      #26: Result := Result + '\Z';
      else
        Result := Result + C;
    end;
  Result := Result + '''';
end;

function SqlValue(F: TField): string;
var
  Bytes: TBytes;
  I: integer;
  Fs: TFormatSettings;
begin
  if F.IsNull then
    Exit('NULL');
  case F.DataType of
    ftSmallint, ftInteger, ftWord, ftLargeint, ftAutoInc, ftShortint, ftByte, ftLongWord:
      Result := F.AsString;
    ftBoolean:
      Result := IntToStr(Ord(F.AsBoolean));
    ftFloat, ftCurrency, ftBCD, ftFMTBcd, ftSingle, ftExtended:
    begin
      Fs := DefaultFormatSettings;
      Fs.DecimalSeparator := '.';
      Fs.ThousandSeparator := #0;
      Result := FloatToStr(F.AsFloat, Fs);
    end;
    ftDate:
      Result := '''' + FormatDateTime('yyyy-mm-dd', F.AsDateTime) + '''';
    ftTime:
      Result := '''' + FormatDateTime('hh:nn:ss', F.AsDateTime) + '''';
    ftDateTime, ftTimeStamp:
      // the thousandths too, when the time has them
      if MilliSecondOf(F.AsDateTime) <> 0 then
        Result := '''' + FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', F.AsDateTime) + ''''
      else
        Result := '''' + FormatDateTime('yyyy-mm-dd hh:nn:ss', F.AsDateTime) + '''';
    ftBlob, ftBytes, ftVarBytes, ftGraphic, ftOraBlob, ftTypedBinary:
    begin
      Bytes := F.AsBytes;
      if Length(Bytes) = 0 then
        Exit('''''');
      Result := '0x';
      for I := 0 to High(Bytes) do
        Result := Result + IntToHex(Bytes[I], 2);
    end;
    else
      Result := SqlText(F.AsString);
  end;
end;

{ The names of the tables in the database. }
function TableNames: TStringList;
var
  Q: TSQLQuery;
begin
  Result := TStringList.Create;
  Q := TSQLQuery.Create(nil);
  try
    Q.DataBase := Connection;
    Q.SQL.Text := SqlTableList;
    Q.Open;
    while not Q.EOF do
    begin
      Result.Add(Q.Fields[0].AsString);
      Q.Next;
    end;
  finally
    Q.Free;
  end;
  Result.Sort;
end;

{ Every table into Path, one statement a line; each table's row count into
  Counts when given. }
procedure DumpDatabase(const Path: string; Counts: TJSONObject);
var
  Dump: TextFile;
  Names: TStringList;
  Table, Row, Batch, Head, Mark: string;
  Q: TSQLQuery;
  I, Rows, First, Got: integer;
  Paged, Any: boolean;
begin
  AssignFile(Dump, Path);
  Rewrite(Dump);
  Names := nil;
  // every table as it was at one moment: a message written meanwhile is in
  // all of its tables or in none
  Connection.ExecuteDirect(SqlSnapshot);
  try
    Names := TableNames;
    WriteLn(Dump, FORMAT_LINE);
    WriteLn(Dump, '-- ', Setting('name', 'Exedra'), ' ', IsoUtc(LocalTimeToUniversal(Now)));
    // a server that hands a whole result over at once is asked a page at a time
    Paged := SqlDumpPage('x', '') <> '';
    for Table in Names do
    begin
      SetStep('Writing ' + Table);
      Head := '';
      Batch := '';
      Rows := 0;
      Mark := '';
      First := 0;
      if Paged then
        First := 1;
      repeat
        Got := 0;
        Q := TSQLQuery.Create(nil);
      try
        Q.DataBase := Connection;
        Q.UniDirectional := True;
        Q.ParamCheck := False;
        if Paged then
          Q.SQL.Text := SqlDumpPage(Table, Mark)
        else
          Q.SQL.Text := 'SELECT * FROM ' + SqlName(Table);
        Q.Open;
        if Head = '' then
        begin
          for I := First to Q.Fields.Count - 1 do
            if not SqlFilledByServer(Q.Fields[I].FieldName) then
            begin
              if Head <> '' then
                Head := Head + ',';
              Head := Head + '`' + Q.Fields[I].FieldName + '`';
            end;
          WriteLn(Dump, TABLE_MARK, Table, '` (', Head, ')');
          Head := 'INSERT INTO `' + Table + '` (' + Head + ') VALUES ';
        end;
        while not Q.EOF do
        begin
          Row := '(';
          Any := False;
          for I := First to Q.Fields.Count - 1 do
            if not SqlFilledByServer(Q.Fields[I].FieldName) then
            begin
              if Any then
                Row := Row + ',';
              Row := Row + SqlValue(Q.Fields[I]);
              Any := True;
            end;
          Row := Row + ')';
          // a statement must fit the server's packet when it is run again
          if Length(Row) > ROW_BYTES then
            raise Exception.CreateFmt('A row of %s is %d MB written out, too large to be put back; the backup was not made.', [Table, Length(Row) div (1024 * 1024)]);
          if (Batch <> '') and (Length(Batch) + Length(Row) + 1 > BATCH_BYTES) then
          begin
            WriteLn(Dump, Batch, ';');
            Batch := '';
            SetStep('Writing ' + Table + ': ' + IntToStr(Rows) + ' rows');
          end;
          if Batch = '' then
            Batch := Head + Row
          else
            Batch := Batch + ',' + Row;
          Inc(Rows);
          Inc(Got);
          if Paged then
            Mark := Q.Fields[0].AsString;
          Q.Next;
        end;
      finally
        Q.Free;
      end;
      until not Paged or (Got = 0);
      if Batch <> '' then
        WriteLn(Dump, Batch, ';');
      if Counts <> nil then
        Counts.Add(Table, Rows);
    end;
    WriteLn(Dump, '-- end');
  finally
    Connection.ExecuteDirect('COMMIT');
    CloseFile(Dump);
    Names.Free;
  end;
end;

{ A dump written to its end: its last line is "-- end".  A file cut short,
  by a full disk or a broken download, is never run. }
function DumpComplete(const Path: string): boolean;
var
  F: TFileStream;
  Tail: string;
  Size: int64;
begin
  Result := False;
  if not FileExists(Path) then
    Exit;
  F := TFileStream.Create(Path, fmOpenRead or fmShareDenyNone);
  try
    Size := F.Size;
    if Size < 16 then
      Exit;
    SetLength(Tail, 16);
    F.Position := Size - 16;
    F.ReadBuffer(Tail[1], 16);
    Result := Pos('-- end', TrimRight(Tail)) = Length(TrimRight(Tail)) - 5;
  finally
    F.Free;
  end;
end;

// ---- reading it back

type
  { one value of a row as the file wrote it }
  TDumpValue = record
    Kind: (dvNull, dvNumber, dvText, dvBytes);
    Text: string;
  end;

{ The name between backquotes that starts at P; P moves past it. }
function BackName(const Line: string; var P: integer): string;
var
  Q: integer;
begin
  Result := '';
  if (P > Length(Line)) or (Line[P] <> '`') then
    Exit;
  Q := PosEx('`', Line, P + 1);
  if Q = 0 then
    Exit;
  Result := Copy(Line, P + 1, Q - P - 1);
  P := Q + 1;
end;

{ The next value of a row; P stands on its first character and moves to
  the comma or parenthesis after it. }
function ReadValue(const Line: string; var P: integer): TDumpValue;
var
  Start: integer;
  S: string;
begin
  Result.Text := '';
  if Line[P] = '''' then
  begin
    Result.Kind := dvText;
    Inc(P);
    Start := P;
    S := '';
    while P <= Length(Line) do
    begin
      if Line[P] = '\' then
      begin
        S := S + Copy(Line, Start, P - Start);
        Inc(P);
        case Line[P] of
          '0': S := S + #0;
          'n': S := S + #10;
          'r': S := S + #13;
          'Z': S := S + #26;
          't': S := S + #9;
          'b': S := S + #8;
          else
            S := S + Line[P];
        end;
        Inc(P);
        Start := P;
      end
      else if Line[P] = '''' then
      begin
        // a quote written twice is one quote
        if (P < Length(Line)) and (Line[P + 1] = '''') then
        begin
          S := S + Copy(Line, Start, P - Start + 1);
          Inc(P, 2);
          Start := P;
        end
        else
          Break;
      end
      else
        Inc(P);
    end;
    Result.Text := S + Copy(Line, Start, P - Start);
    Inc(P);
  end
  else
  begin
    Start := P;
    while (P <= Length(Line)) and not (Line[P] in [',', ')']) do
      Inc(P);
    S := Copy(Line, Start, P - Start);
    if S = 'NULL' then
      Result.Kind := dvNull
    else if (Length(S) > 2) and (S[1] = '0') and (S[2] in ['x', 'X']) then
    begin
      Result.Kind := dvBytes;
      Result.Text := Copy(S, 3, MaxInt);
      for Start := 1 to Length(Result.Text) do
        if not (Result.Text[Start] in ['0'..'9', 'a'..'f', 'A'..'F']) then
          raise Exception.Create('The backup holds a value that is not what it says it is; nothing more was put back.');
    end
    else
    begin
      Result.Kind := dvNumber;
      Result.Text := S;
    end;
  end;
end;

{ The upgrades noted in this database that this program does not register:
  those of a part it does not have.  That part's tables are never touched
  by a restore, so its upgrade marks have to come through one unchanged. }
procedure ForeignUpgrades(List: TStrings);
begin
  with Query('SELECT id FROM upgrades', []) do
  try
    while not EOF do
    begin
      if not UpgradeKnown(Fields[0].AsString) then
        List.Add(Fields[0].AsString);
      Next;
    end;
  finally
    Free;
  end;
end;

{ Rebuild and fill tables from this program's dump; return the statement
  count. Skip transient tables and tables this program does not register.
  Foreign holds the upgrade marks to preserve for those skipped tables. }
function RunDump(const Path: string; Tables: TStringList; Foreign: TStrings): integer;
var
  Dump: TextFile;
  Line, Table, Head, Batch, Row: string;
  Applied, Columns, Target, Emptied: TStringList;
  Keep: array of boolean;
  P, I, N: integer;
  V: TDumpValue;
  Q: TSQLQuery;

  procedure Open;
  begin
    AssignFile(Dump, Path);
    Reset(Dump);
    ReadLn(Dump, Line);
    if Line <> FORMAT_LINE then
    begin
      CloseFile(Dump);
      raise Exception.Create('This is not a backup made here: the database file starts wrong.');
    end;
  end;

  { The table an INSERT line fills and its columns; P left on the first row. }
  function Insert: boolean;
  var
    Name: string;
  begin
    Result := False;
    if not StartsStr('INSERT INTO `', Line) then
      Exit;
    P := 13;
    Table := BackName(Line, P);
    Columns.Clear;
    if Copy(Line, P, 2) = ' (' then
    begin
      Inc(P, 2);
      repeat
        Name := BackName(Line, P);
        if Name <> '' then
          Columns.Add(LowerCase(Name));
        if (P <= Length(Line)) and (Line[P] = ',') then
          Inc(P);
      until (Name = '') or (P > Length(Line)) or (Line[P] = ')');
      Inc(P);
    end;
    P := PosEx('VALUES ', Line, P);
    if P = 0 then
      Exit;
    Inc(P, 7);
    Result := True;
  end;

  { The first time a table comes up: its rows of this moment go, and the
    columns it has here are read. }
  procedure Start(const Name: string);
  var
    K: integer;
  begin
    if AnsiMatchText(Name, NOT_RESTORED) or (Emptied.IndexOf(Name) >= 0) then
      Exit;
    Emptied.Add(Name);
    Target.Values[Name] := '';
    if not TableKnown(Name) then
    begin
      // another part's table, or one this program no longer has: it is laid
      // out by upgrades this program cannot run, so it is left as it is
      Log('The backup has rows for ' + Name + ', which this program does not make; the table is left as it is');
      Exit;
    end;
    SetStep('Putting back ' + Name);
    if Tables <> nil then
      Tables.Add(Name);
    Target.Values[Name] := '';
    Q := TSQLQuery.Create(nil);
    try
      Q.DataBase := Connection;
      Q.ParamCheck := False;
      Q.SQL.Text := 'SELECT * FROM ' + SqlName(Name) + ' WHERE 1 = 0';
      try
        Q.Open;
      except
        // a table that is not here: its rows are left out
        Log('The backup has a table this database does not: ' + Name);
        Exit;
      end;
      Row := ',';
      for K := 0 to Q.Fields.Count - 1 do
        if not SqlFilledByServer(Q.Fields[K].FieldName) then
          Row := Row + LowerCase(Q.Fields[K].FieldName) + ',';
      Target.Values[Name] := Row;
    finally
      Q.Free;
    end;
    Connection.ExecuteDirect(SqlEmptyTable(Name));
  end;

begin
  Result := 0;
  Applied := TStringList.Create;
  Columns := TStringList.Create;
  Target := TStringList.Create;
  Emptied := TStringList.Create;
  try
    // first the upgrades the backup's program had run: they say how its
    // tables were laid out
    Open;
    try
      while not EOF(Dump) do
      begin
        ReadLn(Dump, Line);
        if StartsStr('INSERT INTO `upgrades`', Line) and Insert then
        begin
          N := Columns.IndexOf('id');
          if N < 0 then
            N := 0;
          while (P <= Length(Line)) and (Line[P] = '(') do
          begin
            Inc(P);
            I := 0;
            repeat
              V := ReadValue(Line, P);
              if I = N then
                Applied.Add(V.Text);
              Inc(I);
              if Line[P] = ',' then
                Inc(P)
              else
                Break;
            until P > Length(Line);
            Inc(P);
            if (P <= Length(Line)) and (Line[P] = ',') then
              Inc(P);
          end;
        end;
      end;
    finally
      CloseFile(Dump);
    end;
    SetStep('Making the tables as the backup had them');
    RebuildTables(Applied, NOT_RESTORED);
    if SqlLoadStart <> '' then
      Connection.ExecuteDirect(SqlLoadStart);
    try
      Open;
      try
        while not EOF(Dump) do
        begin
          ReadLn(Dump, Line);
          if Line = '' then
            Continue;
          // a table the backup holds, with rows or without
          if StartsStr(TABLE_MARK, Line) then
          begin
            P := Length(TABLE_MARK);
            Start(BackName(Line, P));
            Continue;
          end;
          if not Insert then
            Continue;
          Start(Table);
          if AnsiMatchText(Table, NOT_RESTORED) or (Target.Values[Table] = '') then
            Continue;
          // the columns this table has here; one it lost is left out
          SetLength(Keep, Columns.Count);
          Head := '';
          for I := 0 to Columns.Count - 1 do
          begin
            Keep[I] := Pos(',' + Columns[I] + ',', Target.Values[Table]) > 0;
            if Keep[I] then
            begin
              if Head <> '' then
                Head := Head + ', ';
              Head := Head + SqlName(Columns[I]);
            end;
          end;
          if (Head = '') or (Columns.Count = 0) then
            raise Exception.Create('The backup does not say which columns the rows of ' + Table + ' fill.');
          Batch := '';
          while (P <= Length(Line)) and (Line[P] = '(') do
          begin
            Inc(P);
            Row := '';
            I := 0;
            repeat
              V := ReadValue(Line, P);
              if (I < Length(Keep)) and Keep[I] then
              begin
                if Row <> '' then
                  Row := Row + ',';
                case V.Kind of
                  dvNull: Row := Row + 'NULL';
                  dvNumber: Row := Row + V.Text;
                  dvBytes: Row := Row + SqlBytesLiteral(V.Text);
                  else
                    Row := Row + SqlTextLiteral(V.Text);
                end;
              end;
              Inc(I);
              if (P <= Length(Line)) and (Line[P] = ',') then
                Inc(P)
              else
                Break;
            until P > Length(Line);
            Inc(P);
            if Batch <> '' then
              Batch := Batch + ',';
            Batch := Batch + '(' + Row + ')';
            if (P <= Length(Line)) and (Line[P] = ',') then
              Inc(P);
          end;
          if Batch <> '' then
          begin
            Connection.ExecuteDirect('INSERT INTO ' + SqlName(Table) + ' (' + Head + ') VALUES ' + Batch);
            Inc(Result);
          end;
        end;
      finally
        CloseFile(Dump);
      end;
      // of the upgrades this program does not know, the ones noted here
      // before, not the backup's
      for I := 0 to Applied.Count - 1 do
        if not UpgradeKnown(Applied[I]) then
          Exec('DELETE FROM upgrades WHERE id = :i', [Applied[I]]);
      for I := 0 to Foreign.Count - 1 do
        Exec(SqlInsertIgnore('upgrades', 'id', ':i'), [Foreign[I]]);
    finally
      if SqlLoadEnd <> '' then
        Connection.ExecuteDirect(SqlLoadEnd);
    end;
  finally
    Applied.Free;
    Columns.Free;
    Target.Free;
    Emptied.Free;
  end;
end;

{ Room left on the disk holding Folder, in bytes; -1 when unknown. }
function FreeBytes(const Folder: string): int64;
{$ifdef unix}
var
  Info: TStatFS;
begin
  Result := -1;
  if fpStatFS(Folder, @Info) = 0 then
    Result := int64(Info.bavail) * Info.bsize;
end;
  {$else}
begin
  Result := -1;
end;
{$endif}

// ---- files

{ Every file under Disk into the zip as Archive/..., links and the named
  top-level folders left out. }
{ True for the database's own file and the files SQLite keeps beside it:
  the database goes in a backup as rows, never as the file in use. }
function IsDatabaseFile(const Path: string): boolean;
begin
  Result := (DatabaseFile <> '') and StartsStr(DatabaseFile, ExpandFileName(Path));
end;

procedure AddFolder(Z: TZipper; const Disk, Archive: string; const Skip: array of string; Top: boolean; var Count: integer);
var
  Entry: TSearchRec;
  Name: string;
begin
  if FindFirst(IncludeTrailingPathDelimiter(Disk) + '*', faAnyFile, Entry) <> 0 then
    Exit;
  try
    repeat
      Name := Entry.Name;
      if (Name = '.') or (Name = '..') then
        Continue;
      {$push}
      {$warn 5044 off}
      if (Entry.Attr and faSymLink) <> 0 then
        Continue;
      {$pop}
      if Top and AnsiMatchText(Name, Skip) then
        Continue;
      if (Entry.Attr and faDirectory) <> 0 then
        AddFolder(Z, IncludeTrailingPathDelimiter(Disk) + Name, Archive + '/' + Name, Skip, False, Count)
      else if IsDatabaseFile(IncludeTrailingPathDelimiter(Disk) + Name) then
        Continue
      else
      begin
        Z.Entries.AddFileEntry(IncludeTrailingPathDelimiter(Disk) + Name, Archive + '/' + Name);
        Inc(Count);
      end;
    until FindNext(Entry) <> 0;
  finally
    FindClose(Entry);
  end;
end;

procedure CopyOneFile(const From, Dest: string);
var
  Source, Target: TFileStream;
  {$ifdef unix}
  Info, Was: Stat;
  Mode: cint;
  Handle: cint;
  {$endif}
begin
  ForceDirectories(ExtractFilePath(Dest));
  {$ifdef unix}
  // a private file put back stays private: the file has its mode before a
  // byte is written, and one that is there is never made more open
  if fpStat(From, Info) = 0 then
  begin
    Mode := Info.st_mode and &777;
    if fpStat(Dest, Was) = 0 then
      Mode := Mode and Was.st_mode;
    // the service writes it now and on the next restore
    Mode := Mode or &600;
    Handle := fpOpen(Dest, O_WRONLY or O_CREAT, Mode);
    if Handle >= 0 then
      fpClose(Handle);
    fpChmod(Dest, Mode);
  end;
  {$endif}
  Source := TFileStream.Create(From, fmOpenRead or fmShareDenyWrite);
  try
    Target := TFileStream.Create(Dest, fmCreate);
    try
      Target.CopyFrom(Source, 0);
    finally
      Target.Free;
    end;
  finally
    Source.Free;
  end;
end;

{ Everything under From over Dest, the named top-level folders left out;
  counts the files. }
procedure CopyFolder(const From, Dest: string; const Skip: array of string; Top: boolean; var Count: integer);
var
  Entry: TSearchRec;
  Name: string;
begin
  if FindFirst(IncludeTrailingPathDelimiter(From) + '*', faAnyFile, Entry) <> 0 then
    Exit;
  try
    repeat
      Name := Entry.Name;
      if (Name = '.') or (Name = '..') then
        Continue;
      if Top and AnsiMatchText(Name, Skip) then
        Continue;
      if (Entry.Attr and faDirectory) <> 0 then
        CopyFolder(IncludeTrailingPathDelimiter(From) + Name, IncludeTrailingPathDelimiter(Dest) + Name, Skip, False, Count)
      else if IsDatabaseFile(IncludeTrailingPathDelimiter(Dest) + Name) then
        Continue
      else
      begin
        CopyOneFile(IncludeTrailingPathDelimiter(From) + Name, IncludeTrailingPathDelimiter(Dest) + Name);
        Inc(Count);
        if Count mod 200 = 0 then
          SetStep('Putting files back: ' + IntToStr(Count));
      end;
    until FindNext(Entry) <> 0;
  finally
    FindClose(Entry);
  end;
end;

procedure RemoveFolder(const Folder: string);
var
  Entry: TSearchRec;
begin
  if not DirectoryExists(Folder) then
    Exit;
  if FindFirst(IncludeTrailingPathDelimiter(Folder) + '*', faAnyFile, Entry) = 0 then
  try
    repeat
      if (Entry.Name = '.') or (Entry.Name = '..') then
        Continue;
      if (Entry.Attr and faDirectory) <> 0 then
        RemoveFolder(IncludeTrailingPathDelimiter(Folder) + Entry.Name)
      else
        DeleteFile(IncludeTrailingPathDelimiter(Folder) + Entry.Name);
    until FindNext(Entry) <> 0;
  finally
    FindClose(Entry);
  end;
  RemoveDir(Folder);
end;

function Writable(const Folder: string): boolean;
var
  Probe: string;
  H: THandle;
begin
  Result := False;
  if not DirectoryExists(Folder) then
    Exit;
  Probe := IncludeTrailingPathDelimiter(Folder) + '.writable-' + IntToStr(Random(1000000));
  H := FileCreate(Probe);
  if H = THandle(-1) then
    Exit;
  FileClose(H);
  DeleteFile(Probe);
  Result := True;
end;

{ The registered folders beside the program that are not in the data folder
  (already in every backup) and not the program's own static files: the
  pictures, and the uploads when a setting put them elsewhere.  The uploads
  are members' files and go in every backup; the rest only when asked. }
function OutsideFolders(WithPictures: boolean): TStringList;
var
  All: TStringList;
  I: integer;
  F: string;
begin
  Result := TStringList.Create;
  All := StorageFolderList;
  try
    for I := 0 to All.Count - 1 do
    begin
      F := IncludeTrailingPathDelimiter(All.ValueFromIndex[I]);
      if StartsText(FilesRoot + 'data' + PathDelim, F) or StartsText(ExtractFilePath(ParamStr(0)) + 'data' + PathDelim, F) or
        StartsText(FilesRoot + 'static' + PathDelim, F) or (All.Names[I] = 'static-files') then
        Continue;
      if WithPictures or (All.Names[I] = 'uploads') then
        Result.Values[All.Names[I]] := F;
    end;
  finally
    All.Free;
  end;
end;

{ The picture folders alone, for the page's words. }
function PictureFolders: TStringList;
begin
  Result := OutsideFolders(True);
  if Result.IndexOfName('uploads') >= 0 then
    Result.Delete(Result.IndexOfName('uploads'));
end;

{ Keeps the newest backup_keep of the backups made here; uploads stay. }
procedure PruneBackups;
var
  Entry: TSearchRec;
  Made: TStringList;
  Keep, I: integer;
begin
  Keep := SettingInt('backup_keep', 5);
  if Keep < 1 then
    Keep := 1;
  Made := TStringList.Create;
  try
    if FindFirst(BackupsFolder + 'site-*.zip', faAnyFile, Entry) = 0 then
    try
      repeat
        Made.Add(Entry.Name);
      until FindNext(Entry) <> 0;
    finally
      FindClose(Entry);
    end;
    Made.Sort;
    for I := 0 to Made.Count - 1 - Keep do
      DeleteFile(BackupsFolder + Made[I]);
  finally
    Made.Free;
  end;
end;

// ---- what is known about each file

{ The kept notes about the backups: name=JSON, read from checks.json once. }
procedure LoadKnown;
var
  Parsed: TJSONData;
  I: integer;
begin
  if Known <> nil then
    Exit;
  Known := TStringList.Create;
  if not FileExists(BackupsFolder + 'checks.json') then
    Exit;
  try
    Parsed := GetJSON(SmallFile(BackupsFolder + 'checks.json'));
    try
      if Parsed is TJSONObject then
        for I := 0 to Parsed.Count - 1 do
          Known.Values[TJSONObject(Parsed).Names[I]] := Parsed.Items[I].AsJSON;
    finally
      Parsed.Free;
    end;
  except
    on E: Exception do
      Log('checks.json could not be read: ' + E.Message);
  end;
end;

procedure SaveKnown;
var
  All: TJSONObject;
  I: integer;
begin
  All := TJSONObject.Create;
  try
    for I := 0 to Known.Count - 1 do
      if FileExists(BackupsFolder + Known.Names[I]) then
        All.Add(Known.Names[I], GetJSON(Known.ValueFromIndex[I]));
    with TStringList.Create do
    try
      Text := All.FormatJSON;
      SaveToFile(BackupsFolder + 'checks.json');
    finally
      Free;
    end;
  finally
    All.Free;
  end;
end;

{ What is known about Name: a copy, or an empty object. }
function KnownAbout(const Name: string): TJSONObject;
var
  Parsed: TJSONData;
begin
  Result := nil;
  EnterCriticalSection(JobLock);
  try
    LoadKnown;
    if Known.IndexOfName(Name) >= 0 then
    try
      Parsed := GetJSON(Known.Values[Name]);
      if Parsed is TJSONObject then
        Result := TJSONObject(Parsed)
      else
        Parsed.Free;
    except
      Result := nil;
    end;
  finally
    LeaveCriticalSection(JobLock);
  end;
  if Result = nil then
    Result := TJSONObject.Create;
end;

procedure Remember(const Name: string; About: TJSONObject);
begin
  EnterCriticalSection(JobLock);
  try
    LoadKnown;
    Known.Values[Name] := About.AsJSON;
    SaveKnown;
  finally
    LeaveCriticalSection(JobLock);
  end;
end;

{ The manifest inside the zip at Path, or nil when it has none or cannot be
  opened: only the central directory and that one small entry are read. }
function ReadManifest(const Path: string): TJSONObject;
var
  Un: TUnZipper;
  Tmp: string;
  Parsed: TJSONData;
begin
  Result := nil;
  Tmp := BackupsFolder + 'reading-' + IntToStr(PtrUInt(GetCurrentThreadId)) + PathDelim;
  Un := TUnZipper.Create;
  try
    try
      Un.FileName := Path;
      Un.OutputPath := Tmp;
      Un.UnZipFile('manifest.json');
      if FileExists(Tmp + 'manifest.json') then
      begin
        Parsed := GetJSON(SmallFile(Tmp + 'manifest.json'));
        if Parsed is TJSONObject then
          Result := TJSONObject(Parsed)
        else
          Parsed.Free;
      end;
    except
      Result := nil;
    end;
  finally
    Un.Free;
    RemoveFolder(Tmp);
  end;
end;

{ The short form of a manifest the page shows beside a file: the site, when,
  what is in it, and how many rows of which tables. }
function Summary(Manifest: TJSONObject): TJSONObject;
var
  Tables: TJSONObject;
  Rows: int64;
  I: integer;
begin
  Result := TJSONObject.Create(['site', Manifest.Get('site', ''), 'when', Manifest.Get('when', ''), 'pictures', Manifest.Get('pictures', False),
    'logs', Manifest.Get('logs', False), 'files', Manifest.Get('files', 0), 'database_bytes', Manifest.Get('database_bytes', int64(0))]);
  Tables := Manifest.Get('tables', TJSONObject(nil));
  if Tables <> nil then
  begin
    Rows := 0;
    for I := 0 to Tables.Count - 1 do
      Rows := Rows + Tables.Items[I].AsInt64;
    Result.Add('tables', Tables.Count);
    Result.Add('rows', Rows);
    Result.Add('counts', Tables.Clone);
  end;
end;

{ What the page shows for the file at Path: the manifest's summary, read
  once for a given size and time, and the last check. }
function AboutBackup(const Name: string; Size: int64; Stamp: TDateTime): TJSONObject;
var
  Manifest: TJSONObject;
  Key: string;
begin
  Result := KnownAbout(Name);
  Key := IntToStr(Size) + '@' + IsoUtc(Stamp);
  if Result.Get('key', '') <> Key then
  begin
    // a new file, or one replaced: the manifest again, the old check forgotten
    Result.Clear;
    Result.Add('key', Key);
    Manifest := ReadManifest(BackupsFolder + Name);
    if Manifest <> nil then
    try
      Result.Add('manifest', Summary(Manifest));
    finally
      Manifest.Free;
    end
    else
      Result.Add('manifest', TJSONNull.Create);
    Remember(Name, Result);
  end;
end;

// ---- the jobs

procedure MakeBackup(WithPictures, WithLogs: boolean);
var
  Tmp, Name, Part, IniName: string;
  Z: TZipper;
  Un: TUnZipper;
  Folders: TStringList;
  Manifest, Counts, About: TJSONObject;
  I, Files, Entries: integer;
begin
  Tmp := BackupsFolder + 'making' + PathDelim;
  RemoveFolder(Tmp);
  PrivateFolder(Tmp);
  Name := 'site-' + FormatDateTime('yyyymmdd-hhnnss', LocalTimeToUniversal(Now)) + '.zip';
  Part := BackupsFolder + Name + '.part';
  try
    SetStep('Writing the database');
    Counts := TJSONObject.Create;
    Manifest := TJSONObject.Create(['program', 'exedra', 'format', 2, 'site', Setting('name', 'Exedra'), 'when', IsoUtc(LocalTimeToUniversal(Now)),
      'pictures', WithPictures, 'logs', WithLogs, 'tables', Counts]);
    try
      DumpDatabase(Tmp + 'database.sql', Counts);
      Manifest.Add('database_bytes', SizeOfFile(Tmp + 'database.sql'));
      SetStep('Packing');
      Z := TZipper.Create;
      try
        PrivateFile(Part);
        Z.FileName := Part;
        Z.Entries.AddFileEntry(Tmp + 'database.sql', 'database.sql');
        if (Config <> nil) and FileExists(Config.FileName) then
        begin
          IniName := ExtractFileName(Config.FileName);
          Z.Entries.AddFileEntry(Config.FileName, 'config/' + IniName);
        end;
        Files := 0;
        AddFolder(Z, FilesRoot + 'data', 'data', SkippedFolders(WithLogs), True, Files);
        Folders := OutsideFolders(WithPictures);
        try
          for I := 0 to Folders.Count - 1 do
            if DirectoryExists(Folders.ValueFromIndex[I]) then
              AddFolder(Z, Folders.ValueFromIndex[I], 'pictures/' + Folders.Names[I], [], True, Files);
        finally
          Folders.Free;
        end;
        Manifest.Add('files', Files);
        with TStringList.Create do
        try
          Text := Manifest.FormatJSON;
          SaveToFile(Tmp + 'manifest.json');
        finally
          Free;
        end;
        Z.Entries.AddFileEntry(Tmp + 'manifest.json', 'manifest.json');
        Entries := Z.Entries.Count;
        Z.ZipAllFiles;
      finally
        Z.Free;
      end;
    finally
      Manifest.Free;
    end;
    // read back before it is named: a file that does not open is no backup
    SetStep('Checking the file');
    Un := TUnZipper.Create;
    try
      Un.FileName := Part;
      Un.Examine;
      if Un.Entries.Count <> Entries then
        raise Exception.CreateFmt('The file holds %d entries, not the %d written.', [Un.Entries.Count, Entries]);
    finally
      Un.Free;
    end;
    if not RenameFile(Part, BackupsFolder + Name) then
      raise Exception.Create('The finished file could not be named.');
    About := AboutBackup(Name, SizeOfFile(BackupsFolder + Name), FileDateToDateTime(FileAge(BackupsFolder + Name)));
    try
      About.Add('checked', IsoUtc(LocalTimeToUniversal(Now)));
      About.Add('whole', True);
      About.Add('note', Format('Made here and read back: %d entries.', [Entries]));
      Remember(Name, About);
    finally
      About.Free;
    end;
    PruneBackups;
    Log('Backup made: ' + Name);
    EnterCriticalSection(JobLock);
    try
      JobLast := 'Backup ' + Name + ' is ready.';
    finally
      LeaveCriticalSection(JobLock);
    end;
  finally
    DeleteFile(Part);
    RemoveFolder(Tmp);
  end;
end;

{ Opens the file, unpacks database.sql and manifest.json alone, and proves
  the dump whole; what it learned is kept for the page. }
procedure CheckBackup(const Name: string);
var
  Tmp, Note: string;
  Un: TUnZipper;
  About: TJSONObject;
  I: integer;
  Entries: int64;
  Whole: boolean;
begin
  Tmp := BackupsFolder + 'checking' + PathDelim;
  RemoveFolder(Tmp);
  PrivateFolder(Tmp);
  Whole := False;
  Note := '';
  try
    try
      SetStep('Opening ' + Name);
      Un := TUnZipper.Create;
      try
        Un.FileName := BackupsFolder + Name;
        Un.OutputPath := Tmp;
        Un.Examine;
        Entries := 0;
        for I := 0 to Un.Entries.Count - 1 do
          Entries := Entries + Un.Entries[I].Size;
        SetStep('Reading the database file');
        Un.UnZipFile('database.sql');
        Un.UnZipFile('manifest.json');
        if not FileExists(Tmp + 'database.sql') then
          Note := 'No database.sql inside: not a backup made here.'
        else if not DumpComplete(Tmp + 'database.sql') then
          Note := 'The database file is cut short: it has no end mark.'
        else if not FileExists(Tmp + 'manifest.json') then
          Note := 'The database file is whole; there is no manifest (an early backup).'
        else
          Note := Format('Whole: %d entries, %s unpacked, the database file ends as it should.', [Un.Entries.Count, SizeWords(Entries)]);
        Whole := FileExists(Tmp + 'database.sql') and DumpComplete(Tmp + 'database.sql');
      finally
        Un.Free;
      end;
    except
      on E: Exception do
        Note := 'The file does not open as a zip: ' + E.Message;
    end;
    About := AboutBackup(Name, SizeOfFile(BackupsFolder + Name), FileDateToDateTime(FileAge(BackupsFolder + Name)));
    try
      About.Delete('checked');
      About.Delete('whole');
      About.Delete('note');
      About.Add('checked', IsoUtc(LocalTimeToUniversal(Now)));
      About.Add('whole', Whole);
      About.Add('note', Note);
      Remember(Name, About);
    finally
      About.Free;
    end;
    Log('Backup checked: ' + Name + ': ' + Note);
    EnterCriticalSection(JobLock);
    try
      JobLast := Name + ': ' + Note;
    finally
      LeaveCriticalSection(JobLock);
    end;
    if not Whole then
      raise Exception.Create(Name + ': ' + Note);
  finally
    RemoveFolder(Tmp);
  end;
end;

procedure UnpackBackup(const Path, Tmp: string);
var
  Un: TUnZipper;
  Needed: int64;
  I: integer;
begin
  SetStep('Unpacking');
  Un := TUnZipper.Create;
  try
    Un.FileName := Path;
    Un.OutputPath := Tmp;
    Un.Examine;
    Needed := 0;
    for I := 0 to Un.Entries.Count - 1 do
    begin
      if not SafePath(Un.Entries[I].ArchiveFileName) then
        raise Exception.Create('The file names a path outside itself (' + Un.Entries[I].ArchiveFileName + ') and is not trusted.');
      // a link could point the files after it anywhere; backups made here hold none
      if Un.Entries[I].IsLink then
        raise Exception.Create('The file holds a link (' + Un.Entries[I].ArchiveFileName + ') and is not trusted.');
      Needed := Needed + Un.Entries[I].Size;
    end;
    // unpacked, then a copy of today's database beside it: room for both
    if (FreeBytes(BackupsFolder) >= 0) and (FreeBytes(BackupsFolder) < Needed + Needed div 4 + 64 * 1024 * 1024) then
      raise Exception.CreateFmt('Not enough room on the disk to unpack it: %d MB needed, %d MB free.', [(Needed + Needed div 4) div
        (1024 * 1024), FreeBytes(BackupsFolder) div (1024 * 1024)]);
    Un.UnZipAllFiles;
  finally
    Un.Free;
  end;
  if not FileExists(Tmp + 'database.sql') then
    raise Exception.Create('This is not a backup made here: no database.sql inside.');
  if not DumpComplete(Tmp + 'database.sql') then
    raise Exception.Create('The backup''s database file is cut short (no end mark); nothing was changed.');
end;

function RestorePictures(const Tmp: string; var Files: integer): string;
var
  Folders: TStringList;
  Entry: TSearchRec;
  Folder: string;
begin
  Result := '';
  if DirectoryExists(Tmp + 'pictures') then
  begin
    Folders := OutsideFolders(True);
    try
      if FindFirst(Tmp + 'pictures' + PathDelim + '*', faDirectory, Entry) = 0 then
      try
        repeat
          if (Entry.Name = '.') or (Entry.Name = '..') or ((Entry.Attr and faDirectory) = 0) then
            Continue;
          Folder := Folders.Values[Entry.Name];
          // a new machine has no such folder yet: it is made where it may be
          if (Folder <> '') and not DirectoryExists(Folder) then
            ForceDirectories(Folder);
          if (Folder <> '') and Writable(Folder) then
          begin
            SetStep('Putting back the pictures: ' + Entry.Name);
            CopyFolder(Tmp + 'pictures' + PathDelim + Entry.Name, Folder, [], True, Files);
          end
          else
            Result := Result + ' ' + Entry.Name;
        until FindNext(Entry) <> 0;
      finally
        FindClose(Entry);
      end;
    finally
      Folders.Free;
    end;
  end;
end;

procedure RestoreBackup(const Path: string);
var
  Tmp, Kept, Name: string;
  Statements, Files, I: integer;
  Signed, Restored, Marks: TStringList;
  Entry: TSearchRec;
  StayShut: boolean;
begin
  Tmp := BackupsFolder + 'restoring' + PathDelim;
  RemoveFolder(Tmp);
  PrivateFolder(Tmp);
  Signed := TStringList.Create;
  Restored := TStringList.Create;
  Marks := TStringList.Create;
  Name := ExtractFileName(Path);
  StayShut := False;
  try
    UnpackBackup(Path, Tmp);
    // the gate shuts, the requests already running finish, the chores wait
    Restoring := True;
    SetStep('Waiting for requests to finish');
    Sleep(1000);
    // every request that got past the gate is answered first, or half a minute passes
    I := 0;
    while (ActiveRequests > 0) and (I < 290) do
    begin
      Sleep(100);
      Inc(I);
    end;
    HoldChores;
    try
      // who is signed in now, so a session cannot end up as someone else
      with Query('SELECT DISTINCT s.user_id, u.name FROM sessions s JOIN users u ON u.id = s.user_id', []) do
      try
        while not EOF do
        begin
          Signed.Values[Fields[0].AsString] := Fields[1].AsString;
          Next;
        end;
      finally
        Free;
      end;
      SetStep('Keeping a copy of the database as it is');
      DumpDatabase(Tmp + 'before.sql', nil);
      ForeignUpgrades(Marks);
      try
        Statements := RunDump(Tmp + 'database.sql', Restored, Marks);
        // the tables of an older backup brought up to this program's layout
        SetStep('Bringing the tables up to date');
        CreateTables;
      except
        on E: Exception do
        begin
          // the tables half replaced: today's copy goes back whole
          SetStep('Putting the database back as it was');
          Log('Restore of ' + Name + ' failed (' + E.Message + '); putting the database back');
          try
            RunDump(Tmp + 'before.sql', nil, Marks);
          except
            on Again: Exception do
            begin
              // neither the backup nor the moment before: the copy is kept and
              // the site stays shut until someone restarts it or puts it back
              CopyOneFile(Tmp + 'before.sql', BackupsFolder + 'database-before-' + ChangeFileExt(Name, '') + '.sql');
              StayShut := True;
              Log('The database could not be put back either (' + Again.Message + '); its copy is database-before-' + ChangeFileExt(Name, '') + '.sql');
              raise Exception.Create('The restore failed (' + E.Message + ') and the database could not be put back as it was (' +
                Again.Message + '). A copy of the database as it was is kept beside the backups as database-before-' + ChangeFileExt(Name, '') +
                '.sql; the site stays shut until the service is restarted.');
            end;
          end;
          raise Exception.Create('The restore failed and the database was put back as it was: ' + E.Message);
        end;
      end;
      // a session whose number now belongs to another name, or to no one, ends
      for I := 0 to Signed.Count - 1 do
        if VarToStr(Value('SELECT name FROM users WHERE id = :u', [StrToInt(Signed.Names[I])])) <> Signed.ValueFromIndex[I] then
        begin
          Exec('DELETE FROM sessions WHERE user_id = :u', [StrToInt(Signed.Names[I])]);
          // and its open pages: what is rung for that number is no longer theirs
          DropUser(StrToInt(Signed.Names[I]));
        end;
      SetStep('Reading the settings again');
      ReloadSettings;
      LoadBlocks;
      // who may do what is the backup's now
      LoadGrants;
      Files := 0;
      // the logs too, when the backup has them
      if DirectoryExists(Tmp + 'data') then
      begin
        SetStep('Putting files back');
        CopyFolder(Tmp + 'data', FilesRoot + 'data', SkippedFolders(True), True, Files);
      end;
      Kept := RestorePictures(Tmp, Files);
      // the config file is the admin's to compare and put in place
      if FindFirst(Tmp + 'config' + PathDelim + '*', faAnyFile, Entry) = 0 then
      try
        repeat
          if (Entry.Attr and faDirectory) = 0 then
            CopyOneFile(Tmp + 'config' + PathDelim + Entry.Name, BackupsFolder + Entry.Name + '.from-' + ChangeFileExt(Name, '') + '.txt');
        until FindNext(Entry) <> 0;
      finally
        FindClose(Entry);
      end;
    finally
      ReleaseChores;
    end;
    Log('Backup restored: ' + Name + ', ' + IntToStr(Statements) + ' statements, ' + IntToStr(Files) + ' files');
    EnterCriticalSection(JobLock);
    try
      JobLast := Format('Restored %s: %d statements and %d files. A restart of the service makes sure every cache is fresh.', [Name, Statements, Files]);
      if Kept <> '' then
        JobLast := JobLast + ' The pictures (' + Trim(Kept) + ') were not put back: their folders are not writable by the program.';
    finally
      LeaveCriticalSection(JobLock);
    end;
  finally
    if not StayShut then
      Restoring := False;
    Signed.Free;
    Restored.Free;
    Marks.Free;
    RemoveFolder(Tmp);
  end;
end;

procedure TBackupJob.Execute;
begin
  try
    try
      CheckConnection;
      case Kind of
        jkBackup: MakeBackup(Pictures, Logs);
        jkRestore: RestoreBackup(BackupsFolder + Name);
        jkCheck: CheckBackup(Name);
        jkNone: ;
      end;
    except
      on E: Exception do
      begin
        Log('Backup job failed: ' + E.Message);
        EnterCriticalSection(JobLock);
        try
          JobError := E.Message;
        finally
          LeaveCriticalSection(JobLock);
        end;
      end;
    end;
  finally
    DoneConnection;
    EnterCriticalSection(JobLock);
    try
      JobKind := jkNone;
      JobStep := '';
    finally
      LeaveCriticalSection(JobLock);
    end;
  end;
end;

{ Starts a job unless one runs; False then. }
{ Claims the one job slot; False when a job runs. }
function StartJobState(Kind: TJobKind; const By: string): boolean;
begin
  EnterCriticalSection(JobLock);
  try
    if JobKind <> jkNone then
      Exit(False);
    JobKind := Kind;
    JobStep := 'Starting';
    JobError := '';
    JobLast := '';
    JobBy := By;
    JobStarted := Now;
    Result := True;
  finally
    LeaveCriticalSection(JobLock);
  end;
end;

function StartJob(Kind: TJobKind; const Name, By: string; Pictures, Logs: boolean): boolean;
var
  Job: TBackupJob;
begin
  // a CGI program has no threads (no cthreads in its build), and a request
  // could not wait for a backup: backups need the program as its own server
  {$ifdef CGI}
  Exit(False);
  {$endif}
  if not StartJobState(Kind, By) then
    Exit(False);
  try
    Job := TBackupJob.Create(True);
    Job.Kind := Kind;
    Job.Name := Name;
    Job.By := By;
    Job.Pictures := Pictures;
    Job.Logs := Logs;
    Job.FreeOnTerminate := True;
    Job.Start;
  except
    EnterCriticalSection(JobLock);
    try
      JobKind := jkNone;
      JobStep := '';
    finally
      LeaveCriticalSection(JobLock);
    end;
    raise;
  end;
  Result := True;
end;

{ The command line's jobs: the same work, here and now, each step printed;
  the job state is set so a check from the page would see it busy. }
function RunHere(Kind: TJobKind; const Name: string; Pictures, Logs: boolean): boolean;
begin
  Result := False;
  if not StartJobState(Kind, 'command line') then
  begin
    WriteLn('A backup job is already running.');
    Exit;
  end;
  Console := True;
  try
    try
      case Kind of
        jkBackup: MakeBackup(Pictures, Logs);
        jkRestore: RestoreBackup(Name);
        jkNone, jkCheck: ;
      end;
      WriteLn(JobLast);
      Result := True;
    except
      on E: Exception do
        WriteLn('Failed: ', E.Message);
    end;
  finally
    EnterCriticalSection(JobLock);
    try
      JobKind := jkNone;
      JobStep := '';
    finally
      LeaveCriticalSection(JobLock);
    end;
  end;
end;

function CommandLineBackup(WithPictures, WithLogs: boolean): boolean;
begin
  Result := RunHere(jkBackup, '', WithPictures, WithLogs);
end;

function CommandLineRestore(const Path: string): boolean;
begin
  if not FileExists(Path) then
  begin
    WriteLn('No such file: ', Path);
    Exit(False);
  end;
  Result := RunHere(jkRestore, ExpandFileName(Path), False, False);
end;

// ---- the routes

{ GET /api/admin/backup }
procedure ShowBackups(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Answer, About: TJSONObject;
  Outside: TJSONData;
  List: TJSONArray;
  Entry: TSearchRec;
  Folders: TStringList;
  Names, Doing, Started: string;
  I: integer;
begin
  if not NeedPermission(ARequest, AResponse, 'manage-backups', Me) then
    Exit;
  CheckConnection;
  List := TJSONArray.Create;
  if FindFirst(BackupsFolder + '*.zip', faAnyFile, Entry) = 0 then
  try
    repeat
      if (Entry.Attr and faDirectory) = 0 then
      begin
        About := AboutBackup(Entry.Name, Entry.Size, Entry.TimeStamp);
        About.Delete('key');
        List.Add(TJSONObject.Create(['name', Entry.Name, 'bytes', Entry.Size, 'when', IsoUtc(LocalTimeToUniversal(Entry.TimeStamp)),
          'uploaded', StartsText('uploaded-', Entry.Name), 'about', About]));
      end;
    until FindNext(Entry) <> 0;
  finally
    FindClose(Entry);
  end;
  // a copy kept elsewhere by a script, as it last reported beside the program
  Outside := TJSONData(TJSONNull.Create);
  if FileExists(ExtractFilePath(ParamStr(0)) + 'backup-status.json') then
  try
    Outside.Free;
    Outside := GetJSON(SmallFile(ExtractFilePath(ParamStr(0)) + 'backup-status.json'));
  except
    Outside := TJSONNull.Create;
  end;
  Names := '';
  Folders := PictureFolders;
  try
    for I := 0 to Folders.Count - 1 do
      Names := Names + ' ' + Folders.Names[I];
  finally
    Folders.Free;
  end;
  EnterCriticalSection(JobLock);
  try
    Doing := '';
    case JobKind of
      jkBackup: Doing := 'backup';
      jkRestore: Doing := 'restore';
      jkCheck: Doing := 'check';
      jkNone: ;
    end;
    Started := '';
    if JobKind <> jkNone then
      Started := IsoUtc(LocalTimeToUniversal(JobStarted));
    Answer := TJSONObject.Create(['backups', List, 'busy', JobKind <> jkNone, 'doing', Doing, 'step', JobStep, 'error', JobError, 'last',
      JobLast, 'by', JobBy, 'started', Started, 'pictures', Trim(Names), 'keep', SettingInt('backup_keep', 5), 'folder', BackupsFolder,
      'outside', Outside, 'free_bytes', FreeBytes(BackupsFolder), 'log_days', SettingInt('access_log_days', 14)]);
  finally
    LeaveCriticalSection(JobLock);
  end;
  SendJSON(AResponse, Answer);
end;

{ POST /api/admin/backup/make  pictures=1 for the picture folders too }
procedure MakeNow(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
begin
  if not NeedPermission(ARequest, AResponse, 'manage-backups', Me) then
    Exit;
  if not StartJob(jkBackup, '', Me.Name, ARequest.ContentFields.Values['pictures'] = '1', ARequest.ContentFields.Values['logs'] = '1') then
  begin
    SendText(AResponse, 409, 'A backup job is already running.');
    Exit;
  end;
  Log(Me.Name + ' started a backup');
  SendText(AResponse, 200, 'Making the backup.');
end;

{ POST /api/admin/backup/restore  name, confirm=RESTORE }
procedure RestoreNow(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Name: string;
begin
  if not NeedPermission(ARequest, AResponse, 'manage-backups', Me) then
    Exit;
  Name := ARequest.ContentFields.Values['name'];
  if not SafeName(Name) or not FileExists(BackupsFolder + Name) then
  begin
    SendText(AResponse, 404, 'No backup by that name.');
    Exit;
  end;
  if ARequest.ContentFields.Values['confirm'] <> 'RESTORE' then
  begin
    SendText(AResponse, 400, 'Type RESTORE to confirm.');
    Exit;
  end;
  if not StartJob(jkRestore, Name, Me.Name, False, False) then
  begin
    SendText(AResponse, 409, 'A backup job is already running.');
    Exit;
  end;
  Log(Me.Name + ' started restoring ' + Name);
  SendText(AResponse, 200, 'Restoring.');
end;

{ POST /api/admin/backup/check  name: opens the file and proves it whole }
procedure CheckNow(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Name: string;
begin
  if not NeedPermission(ARequest, AResponse, 'manage-backups', Me) then
    Exit;
  Name := ARequest.ContentFields.Values['name'];
  if not SafeName(Name) or not FileExists(BackupsFolder + Name) then
  begin
    SendText(AResponse, 404, 'No backup by that name.');
    Exit;
  end;
  if not StartJob(jkCheck, Name, Me.Name, False, False) then
  begin
    SendText(AResponse, 409, 'A backup job is already running.');
    Exit;
  end;
  SendText(AResponse, 200, 'Checking ' + Name + '.');
end;

{ POST /api/admin/backup/delete  name }
procedure DeleteBackup(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Name: string;
begin
  if not NeedPermission(ARequest, AResponse, 'manage-backups', Me) then
    Exit;
  Name := ARequest.ContentFields.Values['name'];
  if not SafeName(Name) or not FileExists(BackupsFolder + Name) then
  begin
    SendText(AResponse, 404, 'No backup by that name.');
    Exit;
  end;
  if JobKind <> jkNone then
  begin
    SendText(AResponse, 409, 'A backup job is running; the files stay as they are until it ends.');
    Exit;
  end;
  DeleteFile(BackupsFolder + Name);
  EnterCriticalSection(JobLock);
  try
    LoadKnown;
    if Known.IndexOfName(Name) >= 0 then
    begin
      Known.Delete(Known.IndexOfName(Name));
      SaveKnown;
    end;
  finally
    LeaveCriticalSection(JobLock);
  end;
  Log(Me.Name + ' deleted backup ' + Name);
  SendText(AResponse, 200, 'Deleted.');
end;

{ The name an upload is kept under: the file's own, cleaned, after "uploaded-". }
function UploadName(const FileName: string): string;
var
  Clean: string;
  C: char;
begin
  Clean := '';
  for C in LowerCase(ExtractFileName(FileName)) do
    if C in ['a'..'z', '0'..'9', '.', '-', '_'] then
      Clean := Clean + C;
  Clean := StringReplace(Clean, '..', '.', [rfReplaceAll]);
  if not EndsText('.zip', Clean) then
    Clean := Clean + '.zip';
  Result := 'uploaded-' + Copy(Clean, 1, 80);
  if not SafeName(Result) then
    Result := 'uploaded-' + FormatDateTime('yyyymmdd-hhnnss', Now) + '.zip';
end;

{ Append a backup piece to name.part only at its current offset. Return have
  so retries resume; size marks the final piece, checked for length and ZIP
  format before renaming. Each request holds at most CHUNK_BYTES. See
  docs/API.md. }
procedure UploadChunk(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Name, Part: string;
  Offset, Size, Have: int64;
  Target: TFileStream;
  Head: string;
begin
  if not NeedPermission(ARequest, AResponse, 'manage-backups', Me) then
    Exit;
  Name := UploadName(ARequest.QueryFields.Values['name']);
  Part := BackupsFolder + Name + '.part';
  Offset := StrToInt64Def(ARequest.QueryFields.Values['offset'], -1);
  Size := StrToInt64Def(ARequest.QueryFields.Values['size'], -1);
  Have := 0;
  if FileExists(Part) then
    with TFileStream.Create(Part, fmOpenRead or fmShareDenyNone) do
    try
      Have := Size;
    finally
      Free;
    end;
  if (Offset < 0) or (Length(ARequest.Content) > CHUNK_BYTES) then
  begin
    SendText(AResponse, 400, 'That piece did not come from this page.');
    Exit;
  end;
  // a new upload starts the file again; a piece out of order is refused
  if Offset = 0 then
    Have := 0
  else if Offset <> Have then
  begin
    SendJSON(AResponse, TJSONObject.Create(['have', Have]));
    Exit;
  end;
  if Offset = 0 then
  begin
    PrivateFile(Part);
    Target := TFileStream.Create(Part, fmCreate);
  end
  else
    Target := TFileStream.Create(Part, fmOpenReadWrite or fmShareDenyWrite);
  try
    Target.Position := Offset;
    if ARequest.Content <> '' then
      Target.WriteBuffer(ARequest.Content[1], Length(ARequest.Content));
    Have := Target.Size;
  finally
    Target.Free;
  end;
  if Size < 0 then
  begin
    SendJSON(AResponse, TJSONObject.Create(['have', Have]));
    Exit;
  end;
  // the last piece: whole, and a zip
  Head := '';
  with TFileStream.Create(Part, fmOpenRead or fmShareDenyNone) do
  try
    if Size >= 2 then
    begin
      SetLength(Head, 2);
      ReadBuffer(Head[1], 2);
    end;
  finally
    Free;
  end;
  if (Have <> Size) or (Head <> 'PK') then
  begin
    DeleteFile(Part);
    SendText(AResponse, 400, Format('The file did not arrive whole (%d of %d bytes) or is not a zip. Try again.', [Have, Size]));
    Exit;
  end;
  if FileExists(BackupsFolder + Name) then
    Name := ChangeFileExt(Name, '') + '-' + FormatDateTime('yyyymmdd-hhnnss', Now) + '.zip';
  if not RenameFile(Part, BackupsFolder + Name) then
  begin
    SendText(AResponse, 500, 'The file arrived but could not be named.');
    Exit;
  end;
  Log(Me.Name + ' uploaded backup ' + Name + ' (' + IntToStr(Size) + ' bytes)');
  SendJSON(AResponse, TJSONObject.Create(['have', Have, 'name', Name, 'done', True]));
end;

{ GET /api/admin/backup/file/:name }
procedure SendBackup(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Name: string;
begin
  if not NeedPermission(ARequest, AResponse, 'manage-backups', Me) then
    Exit;
  Name := ARequest.RouteParams['name'];
  if not SafeName(Name) or not FileExists(BackupsFolder + Name) then
  begin
    SendText(AResponse, 404, 'No backup by that name.');
    Exit;
  end;
  AResponse.ContentType := 'application/zip';
  AResponse.SetCustomHeader('Content-Disposition', 'attachment; filename="' + Name + '"');
  AResponse.SetCustomHeader('Cache-Control', 'private, no-store');
  AResponse.ContentStream := TFileStream.Create(BackupsFolder + Name, fmOpenRead or fmShareDenyWrite);
  AResponse.FreeContentStream := True;
  AResponse.ContentLength := AResponse.ContentStream.Size;
  AResponse.SendContent;
end;

initialization
  Remade := TStringList.Create;
  InitCriticalSection(JobLock);
  RegisterPermission('manage-backups', 'Make, download and restore backups of the whole site', 'admin');
  RegisterAdminSection('backup', 'Backup', 'manage-backups');
  RegisterSetting('backup_keep', 'Backups made on the admin page to keep (the oldest are dropped; uploads stay)', '5', 'number', 'Safety');
  RegisterAdminRoute('/api/admin/backup', 'manage-backups');
  RegisterAdminRoute('/api/admin/backup/file', 'manage-backups');
  RegisterAdminRoute('/api/admin/backup/make', 'manage-backups');
  RegisterAdminRoute('/api/admin/backup/restore', 'manage-backups');
  RegisterAdminRoute('/api/admin/backup/check', 'manage-backups');
  RegisterAdminRoute('/api/admin/backup/delete', 'manage-backups');
  HTTPRouter.RegisterRoute('/api/admin/backup', rmGet, @ShowBackups);
  HTTPRouter.RegisterRoute('/api/admin/backup/make', rmPost, @MakeNow);
  HTTPRouter.RegisterRoute('/api/admin/backup/restore', rmPost, @RestoreNow);
  HTTPRouter.RegisterRoute('/api/admin/backup/check', rmPost, @CheckNow);
  HTTPRouter.RegisterRoute('/api/admin/backup/delete', rmPost, @DeleteBackup);
  RegisterAdminRoute('/api/admin/backup/chunk', 'manage-backups');
  RegisterBodyLimit('/api/admin/backup/chunk', CHUNK_BYTES + 4096);
  HTTPRouter.RegisterRoute('/api/admin/backup/chunk', rmPost, @UploadChunk);
  HTTPRouter.RegisterRoute('/api/admin/backup/file/:name', rmGet, @SendBackup);

finalization
  Remade.Free;
  Known.Free;
  DoneCriticalSection(JobLock);
end.
