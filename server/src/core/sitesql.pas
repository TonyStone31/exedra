unit SiteSql;

{ SQL dialect helpers and translation of MariaDB statements and schemas for
  other servers. Multi-statement results use one line per statement. These
  functions return SQL text only; untrusted values must remain query
  parameters. }

{$mode objfpc}{$H+}

interface

type
  TSqlDialect = (sdMariaDB, sdMySQL, sdPostgres, sdSqlite);
  { MINUTE and friends, for the time sums }
  TSqlUnit = (suSecond, suMinute, suHour, suDay);

var
  SqlDialect: TSqlDialect = sdMariaDB;

{ Tells the unit which server answered, from its SELECT VERSION() text. }
procedure SqlServerIs(const Version: string);
{ A statement every new connection runs first, or '' for none. }
function SqlSessionStart: string;
{ Lets go of every named lock the connection holds, before another thread
  takes the connection over. }
function SqlSessionReset: string;
{ Statements run once before the tables are made, or '' for none. }
function SqlSetup: string;
{ A statement as the server in use wants it.  ValuesIn says the values
  were written into the text, so no parameters are left to fill. }
function SqlStatement(const SQL: string; const Values: array of variant; out ValuesIn: boolean): string;
{ The parameter names of a statement, comma separated, in the order their
  values are given; '' when the values simply go in by position. }
function SqlParamNames(const SQL: string): string;

{ Now, on the server's clock; and now in UTC whatever the server's zone. }
function SqlNow: string;
function SqlUtcNow: string;
{ Now less, or plus, an amount of time.  Amount is a number or a parameter
  (':m'): SqlAgo('2', suMinute), SqlAhead(':d', suDay). }
function SqlAgo(const Amount: string; U: TSqlUnit): string;
function SqlAhead(const Amount: string; U: TSqlUnit): string;
{ A time expression less, or plus, an amount of time. }
function SqlMinus(const Expr, Amount: string; U: TSqlUnit): string;
function SqlPlus(const Expr, Amount: string; U: TSqlUnit): string;

{ A DATETIME column as text: an ISO time a browser reads as UTC, the day
  (2026-11-17), and seconds since 1970. }
function SqlIsoTime(const Column: string): string;
function SqlDay(const Column: string): string;
function SqlUnix(const Column: string): string;
{ The date part of a time expression, still a date. }
function SqlDate(const Expr: string): string;
{ A time as text in another shape; Format in MariaDB's letters (%Y %m %d
  %H %i %s), which each server's branch translates. }
function SqlDateFormat(const Expr, Format: string): string;
{ Text against a regular expression (a parameter or a quoted pattern). }
function SqlRegexp(const Expr, Pattern: string): string;

{ One value or another by a condition. }
function SqlIf(const Condition, ThenValue, ElseValue: string): string;

{ INSERT that leaves an existing row alone:
  SqlInsertIgnore('follows', 'user_id, room_id', ':u, :r') }
function SqlInsertIgnore(const Table, Columns, Values: string): string;
{ The same with rows from a SELECT in place of VALUES. }
function SqlInsertIgnoreSelect(const Table, Columns, Select: string): string;
{ INSERT that takes the place of an existing row with the same key. }
function SqlReplace(const Table, Columns, Values: string): string;
{ What follows an INSERT so that a row with the same key is updated
  instead.  Keys are the columns of the key that collides (a server that
  must be told gets them); Assignments is the SET list.
  ' ... VALUES (:i, 1)' + SqlOnConflict('ip', 'hits = hits + 1') }
function SqlOnConflict(const Keys, Assignments: string): string;
{ Inside those assignments: the value the INSERT brought for a column. }
function SqlNew(const Column: string): string;

{ Texts joined into one; the larger of two values; the first N characters. }
function SqlConcat(const Parts: array of string): string;
function SqlGreatest(const A, B: string): string;
function SqlLeft(const Expr: string; Count: integer): string;
{ A column's values of a group in one text, with Separator between them.
  Expr may carry DISTINCT and ORDER BY as MariaDB writes them. }
function SqlGroupConcat(const Expr, Separator: string): string;

{ Full-text search: the condition (and the score, when selected) for the
  indexed Columns against the words in a parameter.  Boolean is the mode
  with + and - and "phrases". }
function SqlMatch(const Columns, Param: string; boolean: boolean = False): string;

{ A lock by name, held by this connection until released: SELECT them.
  SqlLock gives 1 when the lock was taken within Seconds. }
function SqlLock(const NameParam: string; Seconds: integer): string;
function SqlUnlock(const NameParam: string): string;

{ A whole statement: every table's name and the bytes it takes with its
  indexes. }
function SqlTableSizes: string;

{ For the backup: a table or column name quoted; a statement listing the
  tables; one dropping a table and one emptying it; the statement that
  opens a transaction seeing the database as of one moment. }
function SqlName(const Name: string): string;
function SqlTableList: string;
function SqlDropTable(const Table: string): string;
function SqlEmptyTable(const Table: string): string;
function SqlSnapshot: string;
{ A page of a table's rows after the row marked After ('' for the start),
  the mark of each row in the first column; '' for a server that streams a
  whole table without holding it in memory. }
function SqlDumpPage(const Table, After: string): string;
{ True for a column the server fills by itself, which a backup neither
  writes nor puts back. }
function SqlFilledByServer(const Column: string): boolean;
{ A text and a run of bytes (as hex digits) as literals. }
function SqlTextLiteral(const S: string): string;
function SqlBytesLiteral(const Hex: string): string;
{ Run before and after a backup's rows go in, or '' for none. }
function SqlLoadStart: string;
function SqlLoadEnd: string;
{ True when the server can take a table change back: an upgrade is then
  run in a transaction with its mark, so it is done whole or not at all. }
function SqlSchemaInTransaction: boolean;
{ True when a refused statement only has to be sent again: SQLite says
  "schema has changed" to a connection that had read the tables before
  another one changed them, and "locked" to one that came while another
  held the file. }
function SqlSendAgain(const Error: string): boolean;
{ True where a table change of several parts goes to the server one part
  at a time, and a refused part does not undo the others. }
function SqlPartsMayBeThere: boolean;
{ True when the error says a column or index an upgrade adds is there. }
function SqlThereAlready(const Error: string): boolean;

{ A table or upgrade statement, registered in MariaDB's words, as the
  server in use wants it. }
function SqlSchema(const Statement: string): string;
{ True when a refused table change only says the change is already there:
  the answer of a server without ADD COLUMN IF NOT EXISTS to a column it
  has. }
function SqlAlreadyThere(const Statement, Error: string): boolean;

implementation

uses
  SysUtils, RegExpr, SiteSqlPg, SiteSqlLite;

const
  UNIT_WORDS: array[TSqlUnit] of string = ('SECOND', 'MINUTE', 'HOUR', 'DAY');
  MYSQL_MODE = 'SET SESSION sql_mode = ''STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION''';

procedure SqlServerIs(const Version: string);
begin
  if Pos('mariadb', LowerCase(Version)) > 0 then
    SqlDialect := sdMariaDB
  else if Pos('postgresql', LowerCase(Version)) > 0 then
    SqlDialect := sdPostgres
  else
    SqlDialect := sdMySQL;
end;

function SqlSessionStart: string;
begin
  // Times are kept in UTC on every server, whatever zone the machine or
  // the database server is set to: the pages hand them to browsers as UTC.
  // MySQL's stock mode refuses a GROUP BY that leaves out a selected
  // column; the statements were written under MariaDB's stock mode.
  if SqlDialect = sdMySQL then
    Result := MYSQL_MODE + #10 + 'SET time_zone = ''+00:00'''
  else if SqlDialect = sdMariaDB then
    Result := 'SET time_zone = ''+00:00'''
  else if SqlDialect = sdPostgres then
    Result := PgSessionStart
  else if SqlDialect = sdSqlite then
    Result := LiteSessionStart
  else
    Result := '';
end;

function SqlSessionReset: string;
begin
  if SqlDialect = sdPostgres then
    Result := 'SELECT pg_advisory_unlock_all()'
  else if SqlDialect = sdSqlite then
    Result := 'SELECT release_all_locks()'
  else
    Result := 'DO RELEASE_ALL_LOCKS()';
end;

function SqlSetup: string;
begin
  if SqlDialect = sdPostgres then
    Result := PgSetup
  else
    Result := '';
end;

function SqlStatement(const SQL: string; const Values: array of variant; out ValuesIn: boolean): string;
begin
  ValuesIn := SqlDialect = sdPostgres;
  if ValuesIn then
    Result := PgStatement(SQL, Values)
  else if SqlDialect = sdSqlite then
    Result := LiteTranslate(SQL)
  else
    Result := SQL;
end;

function SqlParamNames(const SQL: string): string;
begin
  // the translation may move a parameter, so there the values go in by name
  if SqlDialect = sdSqlite then
    Result := LiteParamNames(SQL)
  else
    Result := '';
end;

function SqlNow: string;
begin
  Result := 'NOW()';
end;

function SqlUtcNow: string;
begin
  Result := 'UTC_TIMESTAMP()';
end;

function SqlMinus(const Expr, Amount: string; U: TSqlUnit): string;
begin
  Result := Expr + ' - INTERVAL ' + Amount + ' ' + UNIT_WORDS[U];
end;

function SqlPlus(const Expr, Amount: string; U: TSqlUnit): string;
begin
  Result := Expr + ' + INTERVAL ' + Amount + ' ' + UNIT_WORDS[U];
end;

function SqlAgo(const Amount: string; U: TSqlUnit): string;
begin
  Result := SqlMinus(SqlNow, Amount, U);
end;

function SqlAhead(const Amount: string; U: TSqlUnit): string;
begin
  Result := SqlPlus(SqlNow, Amount, U);
end;

function SqlIsoTime(const Column: string): string;
begin
  Result := 'DATE_FORMAT(' + Column + ', ''%Y-%m-%dT%H:%i:%sZ'')';
end;

function SqlDay(const Column: string): string;
begin
  Result := 'DATE_FORMAT(' + Column + ', ''%Y-%m-%d'')';
end;

function SqlUnix(const Column: string): string;
begin
  Result := 'UNIX_TIMESTAMP(' + Column + ')';
end;

function SqlDate(const Expr: string): string;
begin
  Result := 'DATE(' + Expr + ')';
end;

function SqlInsertIgnore(const Table, Columns, Values: string): string;
begin
  Result := 'INSERT IGNORE INTO ' + Table + ' (' + Columns + ') VALUES (' + Values + ')';
end;

function SqlInsertIgnoreSelect(const Table, Columns, Select: string): string;
begin
  Result := 'INSERT IGNORE INTO ' + Table + ' (' + Columns + ') ' + Select;
end;

function SqlDateFormat(const Expr, Format: string): string;
begin
  Result := 'DATE_FORMAT(' + Expr + ', ''' + Format + ''')';
end;

function SqlRegexp(const Expr, Pattern: string): string;
begin
  Result := Expr + ' REGEXP ' + Pattern;
end;

function SqlIf(const Condition, ThenValue, ElseValue: string): string;
begin
  Result := 'IF(' + Condition + ', ' + ThenValue + ', ' + ElseValue + ')';
end;

function SqlReplace(const Table, Columns, Values: string): string;
begin
  Result := 'REPLACE INTO ' + Table + ' (' + Columns + ') VALUES (' + Values + ')';
end;

function SqlOnConflict(const Keys, Assignments: string): string;
begin
  Result := ' ON DUPLICATE KEY UPDATE ' + Assignments;
end;

function SqlNew(const Column: string): string;
begin
  Result := 'VALUES(' + Column + ')';
end;

function SqlConcat(const Parts: array of string): string;
var
  I: integer;
begin
  Result := 'CONCAT(';
  for I := 0 to High(Parts) do
  begin
    if I > 0 then
      Result := Result + ', ';
    Result := Result + Parts[I];
  end;
  Result := Result + ')';
end;

function SqlGreatest(const A, B: string): string;
begin
  Result := 'GREATEST(' + A + ', ' + B + ')';
end;

function SqlLeft(const Expr: string; Count: integer): string;
begin
  Result := 'LEFT(' + Expr + ', ' + IntToStr(Count) + ')';
end;

function SqlGroupConcat(const Expr, Separator: string): string;
begin
  Result := 'GROUP_CONCAT(' + Expr + ' SEPARATOR ''' + StringReplace(Separator, '''', '''''', [rfReplaceAll]) + ''')';
end;

function SqlMatch(const Columns, Param: string; boolean: boolean): string;
begin
  Result := 'MATCH(' + Columns + ') AGAINST (' + Param;
  if boolean then
    Result := Result + ' IN BOOLEAN MODE';
  Result := Result + ')';
end;

function SqlLock(const NameParam: string; Seconds: integer): string;
begin
  Result := 'GET_LOCK(' + NameParam + ', ' + IntToStr(Seconds) + ')';
end;

function SqlUnlock(const NameParam: string): string;
begin
  Result := 'RELEASE_LOCK(' + NameParam + ')';
end;

function SqlTableSizes: string;
begin
  if SqlDialect = sdPostgres then
    Result := 'SELECT c.relname, pg_total_relation_size(c.oid) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace' +
      ' WHERE n.nspname = current_schema() AND c.relkind = ''r'''
  else if SqlDialect = sdSqlite then
    // the file is one piece; a table's share of it is not told
    Result := 'SELECT name, 0 FROM sqlite_master WHERE type = ''table'' AND name NOT LIKE ''sqlite_%'''
  else
    Result := 'SELECT table_name, COALESCE(data_length, 0) + COALESCE(index_length, 0) FROM information_schema.tables WHERE table_schema = DATABASE()';
end;

function SqlName(const Name: string): string;
begin
  if SqlDialect in [sdPostgres, sdSqlite] then
    Result := '"' + Name + '"'
  else
    Result := '`' + Name + '`';
end;

function SqlTableList: string;
begin
  if SqlDialect = sdPostgres then
    Result := 'SELECT tablename FROM pg_tables WHERE schemaname = current_schema()'
  else if SqlDialect = sdSqlite then
    Result := 'SELECT name FROM sqlite_master WHERE type = ''table'' AND name NOT LIKE ''sqlite_%'''
  else
    Result := 'SHOW FULL TABLES WHERE Table_type = ''BASE TABLE''';
end;

function SqlDropTable(const Table: string): string;
begin
  Result := 'DROP TABLE IF EXISTS ' + SqlName(Table);
  if SqlDialect = sdPostgres then
    Result := Result + ' CASCADE';
end;

function SqlEmptyTable(const Table: string): string;
begin
  if SqlDialect = sdSqlite then
    Result := 'DELETE FROM ' + SqlName(Table)
  else
    Result := 'TRUNCATE TABLE ' + SqlName(Table);
end;

function SqlSnapshot: string;
begin
  if SqlDialect = sdPostgres then
    Result := 'START TRANSACTION ISOLATION LEVEL REPEATABLE READ'
  else if SqlDialect = sdSqlite then
    Result := 'BEGIN'
  else
    Result := 'START TRANSACTION WITH CONSISTENT SNAPSHOT';
end;

function SqlDumpPage(const Table, After: string): string;
begin
  Result := '';
  if SqlDialect = sdPostgres then
  begin
    // rows in the order they lie on disk, 5000 at a time
    Result := 'SELECT CAST(ctid AS text) AS row_mark, * FROM ' + SqlName(Table);
    if After <> '' then
      Result := Result + ' WHERE ctid > CAST(''' + After + ''' AS tid)';
    Result := Result + ' ORDER BY ctid LIMIT 5000';
  end;
end;

function SqlFilledByServer(const Column: string): boolean;
begin
  Result := (SqlDialect = sdPostgres) and (Copy(LowerCase(Column), 1, 4) = 'fts_');
end;

function SqlTextLiteral(const S: string): string;
var
  C: char;
begin
  if (SqlDialect = sdSqlite) and (Pos(#0, S) > 0) then
  begin
    // a zero byte cannot stand in a statement's text: the text goes in by its bytes
    Result := 'CAST(X''';
    for C in S do
      Result := Result + IntToHex(Ord(C), 2);
    Result := Result + ''' AS TEXT)';
  end
  else if SqlDialect in [sdPostgres, sdSqlite] then
    // a quote is doubled and nothing else is special.  PostgreSQL keeps no
    // zero byte in a text at all, so one is left out there
    Result := '''' + StringReplace(StringReplace(S, #0, '', [rfReplaceAll]), '''', '''''', [rfReplaceAll]) + ''''
  else
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
end;

function SqlBytesLiteral(const Hex: string): string;
begin
  if SqlDialect = sdPostgres then
    Result := '''\x' + Hex + ''''
  else if SqlDialect = sdSqlite then
    Result := 'X''' + Hex + ''''
  else if Hex = '' then
    Result := ''''''
  else
    Result := '0x' + Hex;
end;

function SqlLoadStart: string;
begin
  if SqlDialect in [sdPostgres, sdSqlite] then
    Result := ''
  else
    // a row whose id is 0 is kept as it is
    Result := 'SET SESSION sql_mode = ''NO_AUTO_VALUE_ON_ZERO''';
end;

function SqlLoadEnd: string;
begin
  if SqlDialect = sdPostgres then
    // the counters behind the id columns go past the ids just put in; one
    // that is further on already (a table the restore left alone) stays
    Result := 'DO $f$ DECLARE r record; BEGIN FOR r IN SELECT table_name, column_name FROM information_schema.columns' +
      ' WHERE table_schema = current_schema() AND is_identity = ''YES'' LOOP' +
      ' EXECUTE format(''SELECT setval(%L, GREATEST((SELECT COALESCE(MAX(%I), 0) FROM %I), (SELECT last_value FROM %s), 1))'',' +
      ' pg_get_serial_sequence(r.table_name, r.column_name), r.column_name, r.table_name, pg_get_serial_sequence(r.table_name, r.column_name));' + ' END LOOP; END $f$'
  else if SqlDialect = sdSqlite then
    Result := ''
  else if SqlDialect = sdMySQL then
    Result := MYSQL_MODE
  else
    Result := 'SET SESSION sql_mode = DEFAULT';
end;

function SqlSchemaInTransaction: boolean;
begin
  Result := SqlDialect in [sdPostgres, sdSqlite];
end;

function SqlSendAgain(const Error: string): boolean;
var
  E: string;
begin
  E := LowerCase(Error);
  Result := (SqlDialect = sdSqlite) and ((Pos('schema has changed', E) > 0) or (Pos('database is locked', E) > 0) or (Pos('database table is locked', E) > 0));
end;

function SqlPartsMayBeThere: boolean;
begin
  Result := SqlDialect = sdSqlite;
end;

function SqlThereAlready(const Error: string): boolean;
var
  E: string;
begin
  E := LowerCase(Error);
  Result := (Pos('duplicate column name', E) > 0) or (Pos('duplicate key name', E) > 0) or (Pos('already exists', E) > 0);
end;

function SqlSchema(const Statement: string): string;
begin
  Result := Statement;
  if SqlDialect = sdPostgres then
    Result := PgSchema(Statement)
  else if SqlDialect = sdSqlite then
    Result := LiteSchema(Statement)
  else if SqlDialect = sdMySQL then
  begin
    // a TEXT column's default must be written as an expression
    Result := ReplaceRegExpr('((?:TINY|MEDIUM|LONG)?(?:TEXT|BLOB)\b[^,]*?DEFAULT) (''(?:[^'']|'''')*'')', Result, '$1 ($2)', True);
    Result := ReplaceRegExpr('(ADD (?:COLUMN )?)IF NOT EXISTS ', Result, '$1', True);
  end;
end;

function SqlAlreadyThere(const Statement, Error: string): boolean;
begin
  Result := (SqlDialect in [sdMySQL, sdSqlite]) and (Pos('IF NOT EXISTS', UpperCase(Statement)) > 0) and (Pos('duplicate column name', LowerCase(Error)) > 0);
end;

end.
