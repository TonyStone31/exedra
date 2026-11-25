unit SiteDb;

{ Thread-local database connections, registered tables, upgrades and chores.
  OpenSite creates missing tables and runs each upgrade once. Settings
  prefer the database, then [site] in the config, then the caller's default.
  Chores run on a server thread or periodically during CGI requests. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Variants, IniFiles, sqldb, sqldblib, mysql57conn, mysql80conn, pqconnection, sqlite3conn;

const
  { A message's revision: microseconds since 1970 when it last changed.
    Browsers ask for everything newer than the last one they saw. }
  RevNow = 'CAST(UNIX_TIMESTAMP(NOW(6)) * 1000000 AS UNSIGNED)';

type
  TChore = procedure;

  TSettingDef = record
    Name, Caption, Default, Kind: string;  // Kind: text, number, yesno, choice:a|b, secret
    Group: string;                         // the heading it goes under on the admin page
  end;

var
  Config: TMemIniFile;
  { The settings an admin may change, as the units registered them. }
  SettingDefs: array of TSettingDef;

procedure RegisterTable(const CreateSQL: string);
{ A change to a table made after it was first created; Id names it for good. }
procedure RegisterUpgrade(const Id, SQL: string);
procedure RegisterChore(Chore: TChore; Minutes: integer);
{ Waits for a chore running now, then keeps the rest from starting until
  ReleaseChores: for a restore, which replaces the tables they use. }
procedure HoldChores;
procedure ReleaseChores;
procedure RegisterSetting(const Name, Caption, Default, Kind: string; const Group: string = 'Site');
{ Runs once the tables are there, before the first request (default rows,
  caches). }
procedure RegisterStartup(Proc: TChore);
procedure OpenSite(const ConfigFile: string);
{ Makes the tables that are missing and runs the upgrades not yet run: at
  start, and after a backup from an older program is put back. }
procedure CreateTables;
{ Every table of this program dropped but those named in Keep, and made
  again as a program had them that had run the upgrades named in Applied:
  the layout a backup's rows fit.  A table this program does not make,
  another part's or one put there by hand, is left as it is. }
procedure RebuildTables(Applied: TStrings; const Keep: array of string);
{ True for an upgrade this program registers, and for a table it makes. }
function UpgradeKnown(const Id: string): boolean;
function TableKnown(const Name: string): boolean;
{$ifndef CGI}
procedure StartChores;
{$endif}
{ Every request handler starts with this. }
procedure CheckConnection;
{ A thread that ends gives its connection back with this. }
procedure DoneConnection;
{ The caller frees the query. }
{ This thread's open connection, for a unit that streams rows or runs
  statements of its own; CheckConnection first. }
function Connection: TSQLConnection;
{ The file the database is, when it is one (SQLite); '' with a server. }
function DatabaseFile: string;
function Query(const SQL: string; const Values: array of variant): TSQLQuery;
procedure Exec(const SQL: string; const Values: array of variant);
{ The same, answering how many rows the statement changed. }
function ExecCount(const SQL: string; const Values: array of variant): integer;
{ The first column of the first row, or Null when there is none. }
function Value(const SQL: string; const Values: array of variant): variant;
{ The same as a number, 0 when there is none. }
function IntValue(const SQL: string; const Values: array of variant): int64;
function LastId: integer;
{ A name for an address: 2 to 40 lowercase letters, digits or hyphens. }
function ValidSlug(const S: string): boolean;
function Setting(const Name, Default: string): string;
function SettingInt(const Name: string; Default: int64): int64;
procedure SaveSetting(const Name, NewValue: string);
{ The settings read again from the table, after a restore. }
procedure ReloadSettings;
{ SQL for a DATETIME column as an ISO time a browser reads as UTC. }
function IsoTime(const Column: string): string;
{ A line in the program's log, written at once. }
procedure Log(const Line: string);

implementation

uses SiteGuardRules, SiteSql, SiteSqlLite, SiteBase;

type
  TChoreItem = record
    Chore: TChore;
    Minutes: integer;
    LastRun: TDateTime;
  end;

threadvar
  Conn: TSQLConnection;
  LastUsed: TDateTime;

var
  Tables, Upgrades: TStringList;
  Settings: TStringList;
  Chores: array of TChoreItem;
  Startups: array of TChore;
  ConnectLock, SettingsLock, ChoreLock, LogLock: TRTLCriticalSection;

procedure RegisterTable(const CreateSQL: string);
begin
  if Tables = nil then
    Tables := TStringList.Create;
  Tables.Add(CreateSQL);
end;

procedure RegisterUpgrade(const Id, SQL: string);
begin
  if Upgrades = nil then
    Upgrades := TStringList.Create;
  Upgrades.AddPair(Id, SQL);
end;

procedure RegisterChore(Chore: TChore; Minutes: integer);
begin
  SetLength(Chores, Length(Chores) + 1);
  Chores[High(Chores)].Chore := Chore;
  Chores[High(Chores)].Minutes := Minutes;
  Chores[High(Chores)].LastRun := 0;
end;

procedure RegisterSetting(const Name, Caption, Default, Kind: string; const Group: string);
begin
  SetLength(SettingDefs, Length(SettingDefs) + 1);
  SettingDefs[High(SettingDefs)].Name := Name;
  SettingDefs[High(SettingDefs)].Caption := Caption;
  SettingDefs[High(SettingDefs)].Default := Default;
  SettingDefs[High(SettingDefs)].Kind := Kind;
  SettingDefs[High(SettingDefs)].Group := Group;
end;

procedure RegisterStartup(Proc: TChore);
begin
  SetLength(Startups, Length(Startups) + 1);
  Startups[High(Startups)] := Proc;
end;

{ TStringList.Values drops a name set to '', and an empty setting is a
  real answer, so lines are written whole. }
procedure KeepSetting(const Name, NewValue: string);
var
  I: integer;
begin
  EnterCriticalSection(SettingsLock);
  try
    I := Settings.IndexOfName(Name);
    if I >= 0 then
      Settings[I] := Name + '=' + NewValue
    else
      Settings.Add(Name + '=' + NewValue);
  finally
    LeaveCriticalSection(SettingsLock);
  end;
end;

procedure LoadSettings;
begin
  with Query('SELECT name, value FROM settings', []) do
  try
    while not EOF do
    begin
      KeepSetting(Fields[0].AsString, Fields[1].AsString);
      Next;
    end;
  finally
    Free;
  end;
end;

{ With EXEDRA_SQL_LOG naming a file, every statement's text is added to
  it once: a way to compare what the program sends before and after a
  change to the SQL.  The table and upgrade statements go in too, as they
  were registered, marked TABLE and UPGRADE. }
var
  SqlLogFile: string;
  SqlSeen: TStringList;
  SqlLogLock: TRTLCriticalSection;

procedure NoteSql(const SQL: string);
var
  F: TextFile;
begin
  EnterCriticalSection(SqlLogLock);
  try
    if SqlSeen.IndexOf(SQL) >= 0 then
      Exit;
    SqlSeen.Add(SQL);
    AssignFile(F, SqlLogFile);
    {$I-}
    if FileExists(SqlLogFile) then
      Append(F)
    else
      Rewrite(F);
    if IOResult = 0 then
    begin
      WriteLn(F, StringReplace(StringReplace(SQL, #13, ' ', [rfReplaceAll]), #10, ' ', [rfReplaceAll]));
      CloseFile(F);
    end;
    {$I+}
  finally
    LeaveCriticalSection(SqlLogLock);
  end;
end;

var
  ServerKnown: boolean;

function ServerVersion(C: TSQLConnection): string;
var
  Q: TSQLQuery;
begin
  Q := TSQLQuery.Create(nil);
  try
    Q.DataBase := C;
    Q.SQL.Text := 'SELECT VERSION()';
    Q.Open;
    Result := Q.Fields[0].AsString;
  finally
    Q.Free;
  end;
end;

{ A statement run directly, and again when the server only asks for that. }
procedure DirectAgain(C: TSQLConnection; const SQL: string);
var
  Tries: integer;
begin
  Tries := 0;
  repeat
  try
    C.ExecuteDirect(SQL);
    Exit;
  except
    on E: Exception do
    begin
      Inc(Tries);
      if (Tries > 20) or not SqlSendAgain(E.Message) then
        raise;
      Sleep(25 * Tries);
    end;
  end;
  until False;
end;

{ Runs what SiteSql answered: one statement, or several on lines of their own. }
procedure RunLines(C: TSQLConnection; const Script: string);
var
  P, Q: integer;
begin
  P := 1;
  while P <= Length(Script) do
  begin
    Q := Pos(#10, Script, P);
    if Q = 0 then
      Q := Length(Script) + 1;
    if Q > P then
      DirectAgain(C, Copy(Script, P, Q - P));
    P := Q + 1;
  end;
end;

function DatabaseFile: string;
begin
  if Config.ReadString('database', 'server', '') = 'sqlite' then
    Result := ExpandFileName(Config.ReadString('database', 'file', IncludeTrailingPathDelimiter(Config.ReadString('site', 'files', '.')) + 'data' + PathDelim + 'exedra.db'))
  else
    Result := '';
end;

function NewConnection: TSQLConnection;
var
  Trans: TSQLTransaction;
  Lite: boolean;
begin
  Lite := Config.ReadString('database', 'server', '') = 'sqlite';
  if Lite then
  begin
    // one file, no server: [database] file= says where, or it lies with the site's files
    Result := TSQLite3Connection.Create(nil);
    // a whole number is read as a long one whatever its column was called
    TSQLite3Connection(Result).AlwaysUseBigint := True;
    Result.DatabaseName := DatabaseFile;
    ForceDirectories(ExtractFilePath(Result.DatabaseName));
    SqlDialect := sdSqlite;
    ServerKnown := True;
  end
  else if Config.ReadString('database', 'server', '') = 'postgres' then
    Result := TPQConnection.Create(nil)
  else if Config.ReadString('database', 'client', 'mariadb') = 'mysql80' then
    Result := TMySQL80Connection.Create(nil)
  else
  begin
    Result := TMySQL57Connection.Create(nil);
    TMySQL57Connection(Result).SkipLibraryVersionCheck := True;
  end;
  if not Lite then
  begin
    Result.HostName := Config.ReadString('database', 'host', '127.0.0.1');
    if Result is TPQConnection then
      Result.Params.Values['port'] := Config.ReadString('database', 'port', '5432')
    else
      Result.Params.Values['Port'] := Config.ReadString('database', 'port', '3306');
    Result.DatabaseName := Config.ReadString('database', 'name', 'exedra');
    Result.UserName := Config.ReadString('database', 'user', 'exedra');
    Result.Password := Config.ReadString('database', 'password', '');
    if Result is TPQConnection then
      Result.CharSet := 'UTF8'
    else
      Result.CharSet := 'utf8mb4';
  end;
  // Every statement commits on its own (MySQL's autocommit), so nothing
  // stays open between requests: no old snapshots, no held table locks.
  Trans := TSQLTransaction.Create(Result);
  Trans.Options := [stoUseImplicit];
  Result.Transaction := Trans;
  // The client library's start-up is not safe to run in two threads at once.
  EnterCriticalSection(ConnectLock);
  try
    try
      Result.Open;
      if Lite then
        LiteOpened(Result.Handle);
      if not ServerKnown then
      begin
        SqlServerIs(ServerVersion(Result));
        ServerKnown := True;
      end;
      RunLines(Result, SqlSessionStart);
    except
      // a database that does not answer: nothing made here is kept
      Result.Free;
      raise;
    end;
  finally
    LeaveCriticalSection(ConnectLock);
  end;
end;

{ An upgrade's statements, one a line.  A line refused because what it adds
  is there already is passed over: always when Lenient, else only where
  the server has no ADD COLUMN IF NOT EXISTS of its own. }
procedure RunUpgrade(const Script, Registered: string; Lenient: boolean);
var
  P, Q: integer;
begin
  P := 1;
  while P <= Length(Script) do
  begin
    Q := Pos(#10, Script, P);
    if Q = 0 then
      Q := Length(Script) + 1;
    if Q > P then
    try
      DirectAgain(Conn, Copy(Script, P, Q - P));
    except
      on E: Exception do
        if not ((Lenient and SqlThereAlready(E.Message)) or SqlAlreadyThere(Registered, E.Message)) then
          raise;
    end;
    P := Q + 1;
  end;
end;

{ The tables and upgrades themselves; CreateTables holds the lock around it. }
procedure MakeTables;
var
  S: string;
  I: integer;
begin
  RunLines(Conn, SqlSetup);
  RunLines(Conn, SqlSchema('CREATE TABLE IF NOT EXISTS settings (name VARCHAR(60) PRIMARY KEY,' + ' value TEXT NOT NULL) CHARACTER SET utf8mb4'));
  RunLines(Conn, SqlSchema('CREATE TABLE IF NOT EXISTS upgrades (id VARCHAR(60) PRIMARY KEY,' + ' done DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP)'));
  for S in Tables do
  begin
    if SqlLogFile <> '' then
      NoteSql('TABLE ' + S);
    RunLines(Conn, SqlSchema(S));
  end;
  if Upgrades <> nil then
    for I := 0 to Upgrades.Count - 1 do
    begin
      if SqlLogFile <> '' then
        NoteSql('UPGRADE ' + Upgrades.Names[I] + ' ' + Upgrades.ValueFromIndex[I]);
      // read even when it is not run: a table an upgrade made is known by it
      S := SqlSchema(Upgrades.ValueFromIndex[I]);
      if IntValue('SELECT COUNT(*) FROM upgrades WHERE id = :i', [Upgrades.Names[I]]) = 0 then
      begin
        Log('Upgrading the database: ' + Upgrades.Names[I]);
        // whole or not at all, where the server can take a table change
        // back: a start that is cut short leaves nothing half done
        if SqlSchemaInTransaction then
          Conn.ExecuteDirect('BEGIN');
        try
          // SQLite takes one table change a statement, so an upgrade is
          // several: a part that is there from a start that was cut short
          // is passed over and the rest is done
          RunUpgrade(S, Upgrades.ValueFromIndex[I], SqlPartsMayBeThere and (Pos(#10, S) > 0));
          Exec('INSERT INTO upgrades (id) VALUES (:i)', [Upgrades.Names[I]]);
          if SqlSchemaInTransaction then
            Conn.ExecuteDirect('COMMIT');
        except
          if SqlSchemaInTransaction then
            Conn.ExecuteDirect('ROLLBACK');
          raise;
        end;
      end;
    end;
end;

procedure CreateTables;
var
  Locked: boolean;
begin
  // what the lock itself needs has to be there first
  RunLines(Conn, SqlSetup);
  // one program at a time: two that start together (CGI requests on a new
  // site) would each find the same upgrade not yet run
  Locked := IntValue('SELECT ' + SqlLock('''exedra-tables''', 60), []) = 1;
  try
    MakeTables;
  finally
    if Locked then
      IntValue('SELECT ' + SqlUnlock('''exedra-tables'''), []);
  end;
end;

function UpgradeKnown(const Id: string): boolean;
begin
  Result := (Upgrades <> nil) and (Upgrades.IndexOfName(Id) >= 0);
end;

{ The name after CREATE TABLE [IF NOT EXISTS] in a registered statement. }
function TableMade(const Statement: string): string;
var
  P, Q: integer;
  U: string;
begin
  Result := '';
  U := UpperCase(Statement);
  P := Pos('CREATE TABLE ', U);
  if P = 0 then
    Exit;
  Inc(P, 13);
  if Copy(U, P, 14) = 'IF NOT EXISTS ' then
    Inc(P, 14);
  Q := P;
  while (Q <= Length(Statement)) and (Statement[Q] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do
    Inc(Q);
  Result := LowerCase(Copy(Statement, P, Q - P));
end;

function TableKnown(const Name: string): boolean;
var
  S: string;
  I: integer;
begin
  Result := SameText(Name, 'settings') or SameText(Name, 'upgrades');
  if Result then
    Exit;
  for S in Tables do
    if SameText(TableMade(S), Name) then
      Exit(True);
  if Upgrades <> nil then
    for I := 0 to Upgrades.Count - 1 do
      if SameText(TableMade(Upgrades.ValueFromIndex[I]), Name) then
        Exit(True);
end;

procedure RebuildTables(Applied: TStrings; const Keep: array of string);
var
  Names: TStringList;
  Q: TSQLQuery;
  S, K: string;
  I: integer;
  Kept: boolean;
begin
  Names := TStringList.Create;
  try
    Q := TSQLQuery.Create(nil);
    try
      Q.DataBase := Conn;
      Q.SQL.Text := SqlTableList;
      Q.Open;
      while not Q.EOF do
      begin
        Names.Add(Q.Fields[0].AsString);
        Q.Next;
      end;
    finally
      Q.Free;
    end;
    for S in Names do
    begin
      Kept := False;
      for K in Keep do
        if SameText(K, S) then
          Kept := True;
      if not Kept and TableKnown(S) then
        Conn.ExecuteDirect(SqlDropTable(S));
    end;
  finally
    Names.Free;
  end;
  RunLines(Conn, SqlSetup);
  RunLines(Conn, SqlSchema('CREATE TABLE IF NOT EXISTS settings (name VARCHAR(60) PRIMARY KEY,' + ' value TEXT NOT NULL) CHARACTER SET utf8mb4'));
  RunLines(Conn, SqlSchema('CREATE TABLE IF NOT EXISTS upgrades (id VARCHAR(60) PRIMARY KEY,' + ' done DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP)'));
  for S in Tables do
    RunLines(Conn, SqlSchema(S));
  if Upgrades <> nil then
    for I := 0 to Upgrades.Count - 1 do
      if Applied.IndexOf(Upgrades.Names[I]) >= 0 then
        // a kept table has the column already
        RunUpgrade(SqlSchema(Upgrades.ValueFromIndex[I]), Upgrades.ValueFromIndex[I], True);
end;

procedure OpenSite(const ConfigFile: string);
var
  Proc: TChore;
begin
  Config := TMemIniFile.Create(ConfigFile);
  Settings := TStringList.Create;
  if Config.ReadString('database', 'server', '') = 'sqlite' then
  begin
    // the library by the name every system has it under, not the one that
    // comes only with the development files
    with TSQLDBLibraryLoader.Create(nil) do
    begin
      ConnectionType := 'SQLite3';
      LibraryName := Config.ReadString('database', 'library', {$ifdef unix}'libsqlite3.so.0'{$else}'sqlite3.dll'{$endif});
      Enabled := True;
    end;
  end
  else if Config.ReadString('database', 'server', '') = 'postgres' then
  begin
    // PostgreSQL's client library, by name when it is not where the system looks
    if Config.ReadString('database', 'library', '') <> '' then
      with TSQLDBLibraryLoader.Create(nil) do
      begin
        ConnectionType := 'PostgreSQL';
        LibraryName := Config.ReadString('database', 'library', '');
        Enabled := True;
      end;
  end
  else if Config.ReadString('database', 'client', 'mariadb') = 'mysql80' then
  begin
    // MySQL 8's client library, by name when it is not where the system looks
    if Config.ReadString('database', 'library', '') <> '' then
      with TSQLDBLibraryLoader.Create(nil) do
      begin
        ConnectionType := 'MySQL 8.0';
        LibraryName := Config.ReadString('database', 'library', '');
        Enabled := True;
      end;
  end
  else
    // MariaDB's client library reports its own version (11.x), which the
    // MySQL 5.7 connection does not recognize, though it speaks the same API.
    with TSQLDBLibraryLoader.Create(nil) do
    begin
      ConnectionType := 'MySQL 5.7';
      LibraryName := Config.ReadString('database', 'library', 'libmariadb.so.3');
      Enabled := True;
    end;
  Conn := NewConnection;
  LastUsed := Now;
  CreateTables;
  LoadSettings;
  SetBaseFromUrl(Setting('url', ''));
  for Proc in Startups do
    Proc();
end;

procedure HoldChores;
begin
  EnterCriticalSection(ChoreLock);
end;

procedure ReleaseChores;
begin
  LeaveCriticalSection(ChoreLock);
end;

procedure RunChores;
var
  I: integer;
begin
  if TryEnterCriticalSection(ChoreLock) = 0 then
    Exit;
  try
    for I := 0 to High(Chores) do
      if Now - Chores[I].LastRun >= Chores[I].Minutes / MinsPerDay then
      begin
        Chores[I].LastRun := Now;
        try
          Chores[I].Chore();
        except
          on E: Exception do
            Log('A chore failed: ' + E.Message);
        end;
      end;
  finally
    LeaveCriticalSection(ChoreLock);
  end;
end;

{ Connections their threads are done with, kept for the next thread: a
  visitor's every new connection would otherwise open one to the database,
  which costs little on MariaDB and a good deal on PostgreSQL. }
const
  POOL_SIZE = 16;
  POOL_MINUTES = 5;

type
  TPooled = record
    Conn: TSQLConnection;
    Used: TDateTime;
  end;

var
  Pool: array[0..POOL_SIZE - 1] of TPooled;
  PoolCount: integer;
  PoolLock: TRTLCriticalSection;

procedure DoneConnection;
var
  Mine: TSQLConnection;
begin
  if Conn = nil then
    Exit;
  Mine := Conn;
  Conn := nil;
  try
    // nothing of this thread's stays on it: no open transaction, no named lock
    // (SQLite refuses a ROLLBACK when no transaction is open)
    if not (Mine is TSQLite3Connection) or LiteInTransaction(Mine.Handle) then
      Mine.ExecuteDirect('ROLLBACK');
    if SqlSessionReset <> '' then
      Mine.ExecuteDirect(SqlSessionReset);
  except
    FreeAndNil(Mine);
    Exit;
  end;
  EnterCriticalSection(PoolLock);
  try
    if PoolCount < POOL_SIZE then
    begin
      Pool[PoolCount].Conn := Mine;
      Pool[PoolCount].Used := Now;
      Inc(PoolCount);
      Mine := nil;
    end;
  finally
    LeaveCriticalSection(PoolLock);
  end;
  Mine.Free;
end;

{ The connection most lately given back, or nil; ones idle too long are
  closed on the way. }
function PooledConnection: TSQLConnection;
var
  Old: array of TSQLConnection;
  I: integer;
begin
  Result := nil;
  Old := nil;
  EnterCriticalSection(PoolLock);
  try
    while (Result = nil) and (PoolCount > 0) do
    begin
      Dec(PoolCount);
      if Now - Pool[PoolCount].Used < POOL_MINUTES / MinsPerDay then
        Result := Pool[PoolCount].Conn
      else
      begin
        SetLength(Old, Length(Old) + 1);
        Old[High(Old)] := Pool[PoolCount].Conn;
      end;
    end;
  finally
    LeaveCriticalSection(PoolLock);
  end;
  for I := 0 to High(Old) do
    Old[I].Free;
end;

procedure CheckConnection;
begin
  // MariaDB drops connections idle for hours; start a fresh one instead.
  if (Conn <> nil) and (Now - LastUsed > 10 / MinsPerDay) then
    FreeAndNil(Conn);
  if Conn = nil then
    Conn := PooledConnection;
  if Conn = nil then
    Conn := NewConnection;
  LastUsed := Now;
  {$ifdef CGI}
  if Random(40) = 0 then
    RunChores;
  {$endif}
end;

{$ifndef CGI}
type
  TChoreThread = class(TThread)
    procedure Execute; override;
  end;

procedure TChoreThread.Execute;
begin
  while not Terminated do
  begin
    try
      CheckConnection;
      RunChores;
    except
      on E: Exception do
        Log('Chores: ' + E.Message);
    end;
    Sleep(20000);
  end;
end;

procedure StartChores;
begin
  with TChoreThread.Create(True) do
  begin
    FreeOnTerminate := True;
    Start;
  end;
end;
{$endif}

function Connection: TSQLConnection;
begin
  CheckConnection;
  Result := Conn;
end;

procedure ReloadSettings;
begin
  // a setting the table no longer holds (a restored backup) must go too
  EnterCriticalSection(SettingsLock);
  try
    Settings.Clear;
  finally
    LeaveCriticalSection(SettingsLock);
  end;
  LoadSettings;
  SetBaseFromUrl(Setting('url', ''));
end;

function Prepare(const SQL: string; const Values: array of variant): TSQLQuery;
var
  I, P, Q: integer;
  Text, Names: string;
  ValuesIn: boolean;
begin
  if SqlLogFile <> '' then
    NoteSql(SQL);
  Text := SqlStatement(SQL, Values, ValuesIn);
  Result := TSQLQuery.Create(nil);
  Result.DataBase := Conn;
  // the rows are only read: no need to ask the server for the table's keys
  Result.UsePrimaryKeyAsKey := False;
  if ValuesIn then
    Result.ParamCheck := False;
  Result.SQL.Text := Text;
  if not ValuesIn then
  begin
    Names := SqlParamNames(SQL);
    if Names = '' then
      for I := 0 to High(Values) do
        Result.Params[I].Value := Values[I]
    else
    begin
      // by name: the statement's own order of parameters may have changed
      P := 1;
      for I := 0 to High(Values) do
      begin
        Q := Pos(',', Names + ',', P);
        Result.ParamByName(Copy(Names, P, Q - P)).Value := Values[I];
        P := Q + 1;
      end;
    end;
  end;
end;

{ A statement the server refused goes in the log too, with its reason. }
procedure NoteFailure(const SQL: string; E: Exception);
begin
  if SqlLogFile <> '' then
    NoteSql('FAILED ' + E.Message + ' :: ' + SQL);
end;

{ How often a statement is sent again when the server only asks for that. }
const
  SEND_AGAIN = 20;

function Query(const SQL: string; const Values: array of variant): TSQLQuery;
var
  Tries: integer;
begin
  Tries := 0;
  repeat
    Result := Prepare(SQL, Values);
  try
    Result.Open;
    Exit;
  except
    on E: Exception do
    begin
      FreeAndNil(Result);
      Inc(Tries);
      if (Tries > SEND_AGAIN) or not SqlSendAgain(E.Message) then
      begin
        NoteFailure(SQL, E);
        raise;
      end;
      Sleep(25 * Tries);
    end;
  end;
  until False;
end;

function ExecCount(const SQL: string; const Values: array of variant): integer;
var
  Q: TSQLQuery;
  Tries: integer;
begin
  Result := 0;
  Tries := 0;
  repeat
    Q := Prepare(SQL, Values);
  try
    try
      Q.ExecSQL;
      Result := Q.RowsAffected;
      Exit;
    except
      on E: Exception do
      begin
        Inc(Tries);
        if (Tries > SEND_AGAIN) or not SqlSendAgain(E.Message) then
        begin
          NoteFailure(SQL, E);
          raise;
        end;
        Sleep(25 * Tries);
      end;
    end;
  finally
    Q.Free;
  end;
  until False;
end;

procedure Exec(const SQL: string; const Values: array of variant);
begin
  ExecCount(SQL, Values);
end;

function Value(const SQL: string; const Values: array of variant): variant;
begin
  with Query(SQL, Values) do
  try
    if EOF then
      Result := Null
    else
      Result := Fields[0].Value;
  finally
    Free;
  end;
end;

function IntValue(const SQL: string; const Values: array of variant): int64;
var
  V: variant;
begin
  V := Value(SQL, Values);
  if VarIsNull(V) then
    Result := 0
  else
    Result := V;
end;

function LastId: integer;
begin
  Result := IntValue('SELECT LAST_INSERT_ID()', []);
end;

function ValidSlug(const S: string): boolean;
var
  C: char;
begin
  Result := (Length(S) >= 2) and (Length(S) <= 40) and (S[1] <> '-');
  for C in S do
    if not (C in ['a'..'z', '0'..'9', '-']) then
      Exit(False);
end;

function Setting(const Name, Default: string): string;
var
  I: integer;
begin
  EnterCriticalSection(SettingsLock);
  try
    I := -1;
    if Settings <> nil then
      I := Settings.IndexOfName(Name);
    if I >= 0 then
      Result := Settings.ValueFromIndex[I]
    else if Config <> nil then
      Result := Config.ReadString('site', Name, Default)
    else
      Result := Default;
  finally
    LeaveCriticalSection(SettingsLock);
  end;
end;

function SettingInt(const Name: string; Default: int64): int64;
begin
  Result := StrToInt64Def(Setting(Name, IntToStr(Default)), Default);
end;

procedure SaveSetting(const Name, NewValue: string);
begin
  Exec(SqlReplace('settings', 'name, value', ':n, :v'), [Name, NewValue]);
  KeepSetting(Name, NewValue);
end;

function IsoTime(const Column: string): string;
begin
  Result := SqlIsoTime(Column);
end;

procedure Log(const Line: string);
begin
  EnterCriticalSection(LogLock);
  try
    WriteLn(StdErr, FormatDateTime('yyyy-mm-dd hh:nn:ss ', Now), LogText(Line));
    Flush(StdErr);
  finally
    LeaveCriticalSection(LogLock);
  end;
end;

initialization
  InitCriticalSection(ConnectLock);
  InitCriticalSection(SettingsLock);
  InitCriticalSection(ChoreLock);
  InitCriticalSection(LogLock);
  InitCriticalSection(SqlLogLock);
  InitCriticalSection(PoolLock);
  SqlSeen := TStringList.Create;
  SqlSeen.Sorted := True;
  SqlLogFile := GetEnvironmentVariable('EXEDRA_SQL_LOG');
  Randomize;
end.
