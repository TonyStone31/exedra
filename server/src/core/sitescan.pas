unit SiteScan;

{ Run ClamAV without a shell under a deadline. Clean needs exit 0 and OK;
  found needs exit 1 and FOUND; anything else is an error. scan_files
  enables upload checks; scan_unavailable decides whether failed scans
  refuse files. Outcomes are logged in upload_scans. See docs/API.md. }

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

const
  ScanClean = 0;
  ScanFound = 1;
  ScanError = 2;
  // --stream: clamd reads the file over its socket, as a service with a
  // private /tmp cannot pass it a file handle from there
  DefaultScanCommand = 'clamdscan --stream --no-summary';
  { The options a scan command may add.  None takes a value or a path,
    hides the file's answer (--infected, --quiet) or changes the mode. }
  ScanOptions: array[0..4] of string = ('--no-summary', '--stream', '--fdpass', '--multiscan', '--alert-exceeds-max');
  { How RunScanner's words start when a limit stopped the scan. }
  ScanLimitWords = 'not fully scanned, a scanner limit was reached';

{ Runs Exe with Args, no shell, for at most Seconds; Output is what it
  wrote, both streams, 64 KB at most.  Code is -1, with the reason in
  Output, when it was stopped or ended by a signal.  False when it could
  not be started. }
function RunScanProgram(const Exe: string; const Args: array of string; Seconds: integer; out Output: string; out Code: integer): boolean;
{ Parse an allowed scanner command, returning False and Problem on refusal.
  Admin settings allow clamscan or clamdscan from the standard paths with
  ScanOptions only; OwnProgram from the ini may name another compatible
  scanner. SettingName supplies the error's wording. }
function ScanCommandParts(const Command, OwnProgram, SettingName: string; out Parts: TStringArray; out Problem: string): boolean;
{ Whether Command's program Exe can be started: its version asked once an
  hour, a minute after it failed to start, and again with Fresh. }
function ScannerReady(const Command, Exe: string; out Version: string; Fresh: boolean = False): boolean;
{ Runs the command in Parts on FileName: Outcome ScanClean, ScanFound with
  what was found in Names, or ScanError with what went wrong (the file
  named Called in it).  clamscan gets --alert-exceeds-max, and the file
  comes after --.  False when the scanner could not be started. }
function RunScanner(const Parts: TStringArray; const FileName: string; Seconds: integer; out Outcome: integer; out Names: string; const Called: string = 'file'): boolean;
{ Printable ASCII, trimmed, MaxLength characters at most. }
function ScanText(const Text: string; MaxLength: integer): string;

{ The site's scanner (scan_command) on FileName, whether scan_files is on
  or not: ScanClean, ScanFound with the names in Words, or ScanError with
  what went wrong in Words.  Fresh asks again whether the scanner starts. }
function ScanFile(const FileName: string; out Words: string; Fresh: boolean = False): integer;
{ A member's upload at Route (chat, avatar, wiki, forum) scanned when
  scan_files is on.  True when it may be kept; otherwise Refusal holds the
  words for the member and Code the answer's status.  Nothing is stored here. }
function UploadScanPasses(UserId: integer; const Route, FileName, LocalPath: string; out Refusal: string; out Code: integer): boolean;
{ The uploads refused in the last Days days. }
function ScanRefusedCount(Days: integer): integer;
{ With scan_files on, why the scanner cannot be run; '' when it can, or when scanning is off. }
function ScanProblem: string;

implementation

uses
  {$ifdef unix} BaseUnix, {$endif}
  Classes, StrUtils, process, zipper, fpjson, fpsha256, httpdefs, httproute,
  SiteDb, SiteUsers, SiteAdmin, SiteGuard, SiteSql, SiteWords;

const
  OutputCap = 64 * 1024;
  HourTicks = 3600000;
  MinuteTicks = 60000;
  // archives in archives, deeper than ClamAV's MaxRecursion (17 unless changed)
  ProbeDepth = 24;
  // the EICAR test file, kept reversed so this program's own file is no test file
  EicarReversed = '*H+H$!ELIF-TSET-SURIVITNA-DRADNATS-RACIE$}7)CC7)^P(45XZP\4[PA@%P!O5X';

type
  TKnownScanner = record
    Command, Version: string;
    Asked: QWord;
    Starts: boolean;
  end;

var
  { Each command's version, asked once an hour, and whether it started. }
  VersionLock: TRTLCriticalSection;
  Known: array of TKnownScanner;
  { The last error of the site's scanner, for the admin page. }
  ErrorLock: TRTLCriticalSection;
  LastError, LastErrorAt: string;

function ScanText(const Text: string; MaxLength: integer): string;
var
  C: char;
begin
  Result := '';
  for C in Text do
    if (C >= ' ') and (C <= '~') then
      Result := Result + C;
  Result := Copy(Trim(Result), 1, MaxLength);
end;

function RunScanProgram(const Exe: string; const Args: array of string; Seconds: integer; out Output: string; out Code: integer): boolean;
var
  P: TProcess;
  Buffer: array[0..4095] of byte;
  Chunk, Arg: string;
  Started: QWord;
  N: integer;

  function TimeUp: boolean;
  begin
    Result := GetTickCount64 - Started > QWord(Seconds) * 1000;
  end;

  // the time limit holds while reading too: a program may write without end
  procedure Take;
  begin
    while (P.Output.NumBytesAvailable > 0) and not TimeUp do
    begin
      N := P.Output.Read(Buffer, SizeOf(Buffer));
      if N <= 0 then
        Break;
      SetString(Chunk, pansichar(@Buffer[0]), N);
      if Length(Output) < OutputCap then
        Output := Output + Copy(Chunk, 1, OutputCap - Length(Output));
    end;
  end;

begin
  Result := False;
  Output := '';
  Code := -1;
  P := TProcess.Create(nil);
  try
    P.Executable := Exe;
    for Arg in Args do
      P.Parameters.Add(Arg);
    P.Options := [poUsePipes, poStderrToOutPut];
    try
      P.Execute;
    except
      on E: Exception do
        Exit;
    end;
    Result := True;
    P.CloseInput;
    Started := GetTickCount64;
    while P.Running do
    begin
      Take;
      if TimeUp then
      begin
        // SIGTERM, then SIGKILL, and waited for
        P.Terminate(255);
        Output := Format('Stopped after %d seconds', [Seconds]);
        Exit;
      end;
      Sleep(50);
    end;
    Take;
    {$ifdef unix}
    // ExitCode is 0 for a program a signal ended
    if not wifexited(P.ExitStatus) then
    begin
      Output := Format('Ended by signal %d', [wtermsig(P.ExitStatus)]);
      Exit;
    end;
    {$endif}
    Code := P.ExitCode;
  finally
    P.Free;
  end;
end;

{ The first line with something on it, the scanned file's name taken out. }
function FirstLine(const Output, FileName, Called: string): string;
var
  Line: string;
begin
  Result := '';
  for Line in Output.Split([#10, #13], TStringSplitOptions.ExcludeEmpty) do
    if Trim(Line) <> '' then
    begin
      Result := Trim(Line);
      Break;
    end;
  if FileName <> '' then
    Result := StringReplace(Result, FileName, Called, [rfReplaceAll]);
end;

{ Whether a line says "<FileName>: OK". }
function SaidOK(const Output, FileName: string): boolean;
var
  Line: string;
begin
  Result := False;
  for Line in Output.Split([#10, #13], TStringSplitOptions.ExcludeEmpty) do
    if TrimRight(Line) = FileName + ': OK' then
      Exit(True);
end;

{ The names on "<FileName>: <name> FOUND" lines, each once, and whether
  each of them is only a reached limit. }
function FoundNames(const Output, FileName: string; out LimitsOnly: boolean): string;
var
  Line, Name: string;
  Seen: TStringList;
begin
  LimitsOnly := True;
  Seen := TStringList.Create;
  try
    for Line in Output.Split([#10, #13], TStringSplitOptions.ExcludeEmpty) do
      if StartsStr(FileName + ': ', Line) and EndsStr(' FOUND', TrimRight(Line)) then
      begin
        Name := TrimRight(Line);
        Name := Trim(Copy(Name, Length(FileName) + 3, Length(Name) - Length(FileName) - 2 - Length(' FOUND')));
        if (Name <> '') and (Seen.IndexOf(Name) < 0) then
        begin
          Seen.Add(Name);
          if not StartsStr('Heuristics.Limits.Exceeded', Name) then
            LimitsOnly := False;
        end;
      end;
    Result := '';
    for Name in Seen do
    begin
      if Result <> '' then
        Result := Result + ', ';
      Result := Result + Name;
    end;
  finally
    Seen.Free;
  end;
end;

function ScanCommandParts(const Command, OwnProgram, SettingName: string; out Parts: TStringArray; out Problem: string): boolean;
var
  Exe: string;
  I: integer;
begin
  Result := False;
  Problem := '';
  Parts := Trim(Command).Split([' ', #9], TStringSplitOptions.ExcludeEmpty);
  if Length(Parts) = 0 then
  begin
    Problem := SettingName + ' is empty';
    Exit;
  end;
  Exe := Parts[0];
  if not (((OwnProgram <> '') and (Exe = OwnProgram)) or AnsiMatchStr(Exe, ['clamscan', 'clamdscan', '/usr/bin/clamscan', '/usr/bin/clamdscan',
    '/usr/local/bin/clamscan', '/usr/local/bin/clamdscan'])) then
  begin
    Problem := SettingName + ' must name clamscan or clamdscan';
    Exit;
  end;
  for I := 1 to High(Parts) do
    if not AnsiMatchStr(Parts[I], ScanOptions) then
    begin
      Problem := SettingName + ' takes only these options: ' + string.Join(' ', ScanOptions);
      Exit;
    end;
  Result := True;
end;

function ScannerReady(const Command, Exe: string; out Version: string; Fresh: boolean): boolean;
var
  Output: string;
  Code, I, At: integer;
begin
  EnterCriticalSection(VersionLock);
  try
    At := -1;
    for I := 0 to High(Known) do
      if Known[I].Command = Command then
        At := I;
    if At < 0 then
    begin
      SetLength(Known, Length(Known) + 1);
      At := High(Known);
      Known[At].Command := Command;
      Known[At].Asked := 0;
    end;
    // a program that did not start is tried again soon: it may be installed by now
    if Fresh or (Known[At].Asked = 0) or (GetTickCount64 - Known[At].Asked >= HourTicks) or (not Known[At].Starts and (GetTickCount64 - Known[At].Asked >= MinuteTicks)) then
    begin
      Known[At].Starts := RunScanProgram(Exe, ['--version'], 60, Output, Code);
      Known[At].Version := '';
      if Known[At].Starts and (Code = 0) then
        Known[At].Version := ScanText(FirstLine(Output, '', ''), 100);
      if not Known[At].Starts then
        Log('Virus scanner: ' + Exe + ' cannot be started');
      Known[At].Asked := GetTickCount64;
    end;
    Version := Known[At].Version;
    Result := Known[At].Starts;
  finally
    LeaveCriticalSection(VersionLock);
  end;
end;

function RunScanner(const Parts: TStringArray; const FileName: string; Seconds: integer; out Outcome: integer; out Names: string; const Called: string): boolean;
var
  Output: string;
  Args: TStringArray;
  Code: integer;
  LimitsOnly: boolean;
begin
  Outcome := ScanError;
  Names := '';
  Args := Copy(Parts, 1, Length(Parts) - 1);
  // clamscan says so when a limit stops it; clamd needs AlertExceedsMax yes
  if (ExtractFileName(Parts[0]) = 'clamscan') and not AnsiMatchStr('--alert-exceeds-max', Args) then
    Args := Concat(Args, ['--alert-exceeds-max']);
  Args := Concat(Args, ['--', FileName]);
  Result := RunScanProgram(Parts[0], Args, Seconds, Output, Code);
  if not Result then
    Exit;
  case Code of
    0:
      // clamdscan can exit 0 for a file it skipped: clean needs its OK line
      if SaidOK(Output, FileName) then
        Outcome := ScanClean
      else
      begin
        Names := FirstLine(Output, FileName, Called);
        if Names = '' then
          Names := 'no answer for the ' + Called
        else
          Names := 'no answer for the ' + Called + ': ' + Names;
      end;
    1:
    begin
      Names := FoundNames(Output, FileName, LimitsOnly);
      if Names = '' then
      begin
        Names := FirstLine(Output, FileName, Called);
        if Names = '' then
          Names := 'exit code 1 without a finding';
      end
      // only a size or count limit was reached: the file was not fully
      // read, which is no finding and no clean result either
      else if LimitsOnly then
        Names := ScanLimitWords + ': ' + Names
      else
        Outcome := ScanFound;
    end;
    else
    begin
      Names := FirstLine(Output, FileName, Called);
      if Names = '' then
        Names := Format('exit code %d', [Code]);
    end;
  end;
  Names := ScanText(Names, 600);
end;

function OwnScanProgram: string;
begin
  Result := '';
  if Config <> nil then
    Result := Trim(Config.ReadString('site', 'scan_program', ''));
end;

procedure NoteError(const Words: string);
begin
  EnterCriticalSection(ErrorLock);
  try
    LastError := Words;
    LastErrorAt := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', NowUTC);
  finally
    LeaveCriticalSection(ErrorLock);
  end;
end;

function ScanFile(const FileName: string; out Words: string; Fresh: boolean): integer;
var
  Parts: TStringArray;
  Version: string;
  Seconds: integer;
begin
  Result := ScanError;
  if not ScanCommandParts(Setting('scan_command', DefaultScanCommand), OwnScanProgram, 'scan_command', Parts, Words) then
    Exit;
  if not ScannerReady(Setting('scan_command', DefaultScanCommand), Parts[0], Version, Fresh) then
  begin
    Words := Parts[0] + ' cannot be started';
    Exit;
  end;
  Seconds := SettingInt('scan_seconds', 120);
  if Seconds < 1 then
    Seconds := 120;
  if not RunScanner(Parts, FileName, Seconds, Result, Words) then
  begin
    Result := ScanError;
    Words := Parts[0] + ' cannot be started';
  end;
end;

function FileSha256(const FileName: string; out Size: int64): string;
var
  FileIn: TFileStream;
  SHA: TSHA256;
  Buffer: array[0..65535] of byte;
  N: integer;
begin
  Result := '';
  Size := 0;
  try
    FileIn := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  except
    on E: Exception do
      Exit;
  end;
  try
    Size := FileIn.Size;
    SHA.Init;
    repeat
      N := FileIn.Read(Buffer, SizeOf(Buffer));
      if N > 0 then
        SHA.Update(@Buffer[0], N);
    until N = 0;
    SHA.Final;
    SHA.OutputHexa(Result);
    Result := LowerCase(Result);
  finally
    FileIn.Free;
  end;
end;

{ A name as it is kept: no control characters, 200 bytes at most. }
function KeptName(const Name: string): string;
var
  C: char;
begin
  Result := '';
  for C in ExtractFileName(Name) do
    if Ord(C) >= 32 then
      Result := Result + C;
  Result := Copy(Result, 1, 200);
end;

function UploadScanPasses(UserId: integer; const Route, FileName, LocalPath: string; out Refusal: string; out Code: integer): boolean;
var
  Outcome: integer;
  Words, Hash: string;
  Size: int64;
begin
  Result := True;
  Refusal := '';
  Code := 200;
  if SettingInt('scan_files', 0) <> 1 then
    Exit;
  Outcome := ScanFile(LocalPath, Words);
  if Outcome = ScanClean then
    Exit;
  if Outcome = ScanFound then
  begin
    Result := False;
    Code := 422;
    Refusal := Format(Say('The file was not saved: the virus scanner found %s in it.'), [Words]);
  end
  else
  begin
    NoteError(Words);
    Result := Setting('scan_unavailable', 'allow') <> 'refuse';
    if not Result then
    begin
      Code := 503;
      Refusal := Say('The file was not saved: the virus scanner could not check it. Try again later.');
    end;
  end;
  Hash := FileSha256(LocalPath, Size);
  Exec('INSERT INTO upload_scans (at, user_id, route, name, size, sha256, result, names, kept) VALUES (' + SqlUtcNow + ', :u, :r, :n, :s, :h, :o, :w, :k)',
    [UserId, Route, KeptName(FileName), Size, Hash, Outcome, Words, Ord(Result)]);
  if Outcome = ScanFound then
    Log(Format('Virus scanner: %s upload by member %d refused, %s found in %s', [Route, UserId, Words, ScanText(FileName, 100)]))
  else if Result then
    Log(Format('Virus scanner: %s upload by member %d kept unscanned: %s', [Route, UserId, Words]))
  else
    Log(Format('Virus scanner: %s upload by member %d refused unscanned: %s', [Route, UserId, Words]));
end;

function ScanRefusedCount(Days: integer): integer;
begin
  Result := IntValue('SELECT COUNT(*) FROM upload_scans WHERE kept = 0 AND at > ' + SqlMinus(SqlUtcNow, IntToStr(Days), suDay), []);
end;

function ScanProblem: string;
var
  Parts: TStringArray;
  Version, Problem: string;
begin
  Result := '';
  if SettingInt('scan_files', 0) <> 1 then
    Exit;
  if not ScanCommandParts(Setting('scan_command', DefaultScanCommand), OwnScanProgram, 'scan_command', Parts, Problem) then
    Result := Problem
  else if not ScannerReady(Setting('scan_command', DefaultScanCommand), Parts[0], Version) then
    Result := Parts[0] + ' cannot be started';
end;

{ GET /api/admin/scans }
procedure ShowScans(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Parts: TStringArray;
  Problem, Version: string;
  Ready: boolean;
  Answer: TJSONObject;
  Rows: TJSONArray;
begin
  if not NeedPermission(ARequest, AResponse, 'manage-settings', Me) then
    Exit;
  Version := '';
  Ready := ScanCommandParts(Setting('scan_command', DefaultScanCommand), OwnScanProgram, 'scan_command', Parts, Problem);
  if Ready then
  begin
    Ready := ScannerReady(Setting('scan_command', DefaultScanCommand), Parts[0], Version);
    if not Ready then
      Problem := Parts[0] + ' cannot be started';
  end;
  Answer := TJSONObject.Create(['on', SettingInt('scan_files', 0) = 1, 'ready', Ready, 'version', Version, 'problem', Problem]);
  try
    EnterCriticalSection(ErrorLock);
    try
      Answer.Add('last_error', LastError);
      Answer.Add('last_error_at', LastErrorAt);
    finally
      LeaveCriticalSection(ErrorLock);
    end;
    Rows := TJSONArray.Create;
    Answer.Add('files', Rows);
    with Query('SELECT ' + IsoTime('s.at') + ', COALESCE(u.name, ''''), s.route, s.name, s.size, s.sha256, s.result, s.names, s.kept' +
        ' FROM upload_scans s LEFT JOIN users u ON u.id = s.user_id ORDER BY s.id DESC LIMIT 200', []) do
    try
      while not EOF do
      begin
        Rows.Add(TJSONObject.Create(['when', Fields[0].AsString, 'member', Fields[1].AsString, 'route', Fields[2].AsString, 'name',
          Fields[3].AsString, 'size', Fields[4].AsLargeInt, 'sha256', Fields[5].AsString, 'found', Fields[6].AsInteger = ScanFound,
          'names', Fields[7].AsString, 'kept', Fields[8].AsInteger = 1]));
        Next;
      end;
    finally
      Free;
    end;
  except
    Answer.Free;
    raise;
  end;
  SendJSON(AResponse, Answer);
end;

{ An archive in an archive, ProbeDepth deep: a scanner that reports its
  limits says MaxRecursion; one that does not calls it clean. }
procedure WriteProbe(const FileName: string);
var
  Inner, Outer: TMemoryStream;
  Zip: TZipper;
  Level: integer;
  Text: string;
begin
  Text := 'an archive deeper than the scanner reads';
  Inner := TMemoryStream.Create;
  try
    Inner.WriteBuffer(Text[1], Length(Text));
    for Level := 1 to ProbeDepth do
    begin
      Outer := TMemoryStream.Create;
      try
        Zip := TZipper.Create;
        try
          Inner.Position := 0;
          Zip.Entries.AddFileEntry(Inner, 'level' + IntToStr(Level));
          Zip.SaveToStream(Outer);
        finally
          Zip.Free;
        end;
      except
        Outer.Free;
        raise;
      end;
      Inner.Free;
      Inner := Outer;
    end;
    Inner.SaveToFile(FileName);
  finally
    Inner.Free;
  end;
end;

{ POST /api/admin/scans/test  the EICAR test file, which any scanner knows,
  scanned; when it is caught, the probe too, for whether limits are reported }
procedure TestScanner(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  TestName, ProbeName, Words, ProbeWords: string;
  Outcome: integer;
  Limits: boolean;
  Output: TFileStream;
  Eicar: string;
begin
  if not NeedPermission(ARequest, AResponse, 'manage-settings', Me) then
    Exit;
  Eicar := ReverseString(EicarReversed);
  TestName := IncludeTrailingPathDelimiter(GetTempDir) + 'scan-test-' + RandomHex(8) + '.txt';
  ProbeName := IncludeTrailingPathDelimiter(GetTempDir) + 'scan-probe-' + RandomHex(8) + '.zip';
  Limits := False;
  try
    Output := TFileStream.Create(TestName, fmCreate);
    try
      Output.WriteBuffer(Eicar[1], Length(Eicar));
    finally
      Output.Free;
    end;
    // the test asks again whether the scanner starts: it may just have been installed
    Outcome := ScanFile(TestName, Words, True);
    if Outcome = ScanFound then
    begin
      WriteProbe(ProbeName);
      Limits := (ScanFile(ProbeName, ProbeWords) = ScanError) and StartsStr(ScanLimitWords, ProbeWords);
    end;
  finally
    DeleteFile(TestName);
    DeleteFile(ProbeName);
  end;
  if Outcome = ScanError then
    NoteError(Words);
  SendJSON(AResponse, TJSONObject.Create(['caught', Outcome = ScanFound, 'error', Outcome = ScanError, 'words', Words, 'limits', Limits]));
end;

initialization
  InitCriticalSection(VersionLock);
  InitCriticalSection(ErrorLock);
  RegisterTable('CREATE TABLE IF NOT EXISTS upload_scans (id INT AUTO_INCREMENT PRIMARY KEY, at DATETIME NOT NULL, user_id INT NOT NULL,' +
    ' route VARCHAR(20) NOT NULL, name VARCHAR(200) NOT NULL, size BIGINT NOT NULL, sha256 CHAR(64) NOT NULL, result TINYINT NOT NULL,' +
    ' names VARCHAR(600) NOT NULL DEFAULT '''', kept TINYINT NOT NULL, INDEX (at)) CHARACTER SET utf8mb4');
  // --infected and --quiet hide the OK line a clean result needs now: taken
  // out of a stored command once, the old default's among them
  RegisterUpgrade('scan-command-no-infected', 'UPDATE settings SET value = TRIM(REPLACE(REPLACE(value, '' --infected'', ''''),' +
    ' '' --quiet'', '''')) WHERE name = ''scan_command''');
  RegisterAdminRoute('/api/admin/scans', 'manage-settings');
  RegisterAdminRoute('/api/admin/scans/test', 'manage-settings');
  HTTPRouter.RegisterRoute('/api/admin/scans', rmGet, @ShowScans);
  HTTPRouter.RegisterRoute('/api/admin/scans/test', rmPost, @TestScanner);

finalization
  DoneCriticalSection(ErrorLock);
  DoneCriticalSection(VersionLock);
end.
