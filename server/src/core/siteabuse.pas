unit SiteAbuse;

{ AbuseIPDB lookups and reports for addresses the guard found hostile. A
  chore checks at most weekly and reports at most daily per address; a high
  score alone never blocks an address. Allowed addresses and published
  crawlers are exempt. Quotas and 429 pauses limit calls; no key means no
  calls. }

{$mode objfpc}{$H+}

interface

implementation

uses
  Classes, SysUtils, StrUtils, DateUtils, fpjson, jsonparser, httpdefs, fphttpclient, SiteDb, SiteSql, SiteGuard, SiteTls;

const
  API = 'https://api.abuseipdb.com/api/v2/';
  // a week: scores move slowly, and the free lookups are kept for new addresses
  CHECK_DAYS = 7;
  PER_ROUND = 20;

var
  // set by an answer 429: no call before it
  QuietUntil: TDateTime = 0;

function Key: string;
begin
  Result := Trim(Setting('abuseipdb_key', ''));
end;

{ A path as it goes into a report: no query, plain characters, short. }
function CleanPath(const Path: string): string;
var
  C: char;
begin
  Result := '';
  for C in Path do
    if C = '?' then
      Break
    else if (C > ' ') and (C < #127) then
      Result := Result + C;
  Result := Copy(Result, 1, 80);
end;

procedure NoteHostile(const Ip, Kind, Detail: string);
var
  Path: string;
begin
  if (Key = '') or NeverBlocked(Ip) then
    Exit;
  // the guard can note a request before it has opened this thread's
  // connection (a malformed path, or an address already blocked)
  CheckConnection;
  Path := CleanPath(Detail);
  // one row an address: its kinds and the first few paths it tried
  Exec('INSERT INTO abuse_queue (ip, kinds, detail, hits, first_at, last_at) VALUES (:i, :k, :d, 1, NOW(), NOW())' + SqlOnConflict('ip',
    'hits = hits + 1, last_at = NOW(),' + ' kinds = ' + SqlIf('FIND_IN_SET(:k2, kinds) > 0', 'kinds', SqlLeft(SqlConcat(['kinds', ''',''', ':k3']), 60)) +
    ',' + ' detail = ' + SqlIf(':d2 = '''' OR LENGTH(detail) > 200 OR LOCATE(:d3, detail) > 0', 'detail', SqlConcat(['detail', ''' ''', ':d4']))),
    [Ip, Kind, Path, Kind, Kind, Path, Path, Path]);
end;

function NewClient: TFPHTTPClient;
begin
  Result := TFPHTTPClient.Create(nil);
  Result.ConnectTimeout := 10000;
  Result.IOTimeout := 20000;
  Result.AddHeader('Key', Key);
  Result.AddHeader('Accept', 'application/json');
  Result.AddHeader('User-Agent', 'Exedra/1 (checks and reports hostile addresses)');
end;

{ An answer 429: quiet until the time it names (an hour when it names none). }
procedure Slowed(Client: TFPHTTPClient);
var
  Wait: integer;
begin
  Wait := StrToIntDef(Client.GetHeader(Client.ResponseHeaders, 'Retry-After'), 3600);
  QuietUntil := IncSecond(Now, Wait);
  Log('AbuseIPDB asked us to wait ' + IntToStr(Wait) + ' seconds');
end;

{ The answer's body, whatever its status (Get alone raises on all but 200). }
function Ask(Client: TFPHTTPClient; const Method, Url: string): string;
var
  Answer: TStringStream;
begin
  Answer := TStringStream.Create('');
  try
    Client.HTTPMethod(Method, Url, Answer, []);
    Result := Answer.DataString;
  finally
    Answer.Free;
  end;
end;

{ The score AbuseIPDB gives the address, -1 when it could not be had. }
function Check(const Ip: string): integer;
var
  Client: TFPHTTPClient;
  Data: TJSONData;
  Info: TJSONObject;
  Body: string;
begin
  Result := -1;
  Client := NewClient;
  Data := nil;
  try
    try
      Body := Ask(Client, 'GET', API + 'check?maxAgeInDays=30&ipAddress=' + HTTPEncode(Ip));
      if Client.ResponseStatusCode = 429 then
        Slowed(Client)
      else if Client.ResponseStatusCode = 200 then
      begin
        Data := GetJSON(Body);
        Info := TJSONObject(Data).Objects['data'];
        Result := Info.Get('abuseConfidenceScore', 0);
        Exec('INSERT INTO abuse_checks (ip, score, reports, usage_type, isp, country, checked) VALUES (:i, :s, :r, :u, :p, :c, NOW())' +
          SqlOnConflict('ip', 'score = ' + SqlNew('score') + ', reports = ' + SqlNew('reports') + ', usage_type = ' + SqlNew('usage_type') +
          ',' + ' isp = ' + SqlNew('isp') + ', country = ' + SqlNew('country') + ', checked = NOW()'),
          [Ip, Result, Info.Get('totalReports', 0), Copy(Info.Get('usageType', ''), 1, 60), Copy(Info.Get('isp', ''), 1, 100), Copy(Info.Get('countryCode', ''), 1, 2)]);
      end
      else
      begin
        Log('AbuseIPDB lookup of ' + Ip + ' answered ' + IntToStr(Client.ResponseStatusCode));
        // a key it does not take: an hour's quiet, not a try every round
        if (Client.ResponseStatusCode = 401) or (Client.ResponseStatusCode = 403) then
          QuietUntil := IncHour(Now, 1);
      end;
    except
      on E: Exception do
        Log('AbuseIPDB lookup of ' + Ip + ' failed: ' + E.Message);
    end;
  finally
    Data.Free;
    Client.Free;
  end;
end;

{ Our report: Web App Attack (21) for probes, Brute-Force (18) for passwords. }
procedure Report(const Ip, Kinds, Paths: string);
var
  Client: TFPHTTPClient;
  Categories, Comment: string;
begin
  Categories := '';
  Comment := '';
  if (Pos('probe', Kinds) > 0) or (Pos('admin', Kinds) > 0) then
  begin
    Categories := '21';
    Comment := 'Probed for files and administration pages that are not there';
    if Paths <> '' then
      Comment := Comment + ': ' + Paths;
  end;
  if Pos('password', Kinds) > 0 then
  begin
    Categories := IfThen(Categories = '', '18', Categories + ',18');
    Comment := IfThen(Comment = '', '', Comment + '. ') + 'Locked out after repeated wrong passwords';
  end;
  if Categories = '' then
    Exit;
  Client := NewClient;
  try
    Client.AddHeader('Content-Type', 'application/x-www-form-urlencoded');
    Client.RequestBody := TStringStream.Create('ip=' + HTTPEncode(Ip) + '&categories=' + HTTPEncode(Categories) + '&comment=' + HTTPEncode(Copy(Comment, 1, 1000)));
    try
      Ask(Client, 'POST', API + 'report');
      if Client.ResponseStatusCode = 429 then
        Slowed(Client)
      else if Client.ResponseStatusCode = 200 then
        Exec('INSERT INTO abuse_reports (ip, categories, comment, at) VALUES (:i, :c, :m, NOW())', [Ip, Categories, Copy(Comment, 1, 500)])
      else
        Log('AbuseIPDB report of ' + Ip + ' answered ' + IntToStr(Client.ResponseStatusCode));
    except
      on E: Exception do
        Log('AbuseIPDB report of ' + Ip + ' failed: ' + E.Message);
    end;
  finally
    Client.RequestBody.Free;
    Client.RequestBody := nil;
    Client.Free;
  end;
end;

procedure WorkQueue;
var
  Rows: TStringList;
  I, Score, Threshold: integer;
  Parts: TStringArray;
  Ip, Kinds, Paths, Why: string;
begin
  if (Key = '') or (Now < QuietUntil) then
    Exit;
  Rows := TStringList.Create;
  try
    // a minute's quiet first, so a burst of probes is one row and one report
    with Query('SELECT ip, kinds, detail FROM abuse_queue WHERE last_at < ' + SqlAgo('1', suMinute) + ' ORDER BY first_at LIMIT ' + IntToStr(PER_ROUND), []) do
    try
      while not EOF do
      begin
        Rows.Add(Fields[0].AsString + #9 + Fields[1].AsString + #9 + Fields[2].AsString);
        Next;
      end;
    finally
      Free;
    end;
    Threshold := SettingInt('abuseipdb_block_score', 90);
    for I := 0 to Rows.Count - 1 do
    begin
      if Now < QuietUntil then
        Break;
      Parts := Rows[I].Split([#9]);
      Ip := Parts[0];
      Kinds := Parts[1];
      Paths := Parts[2];
      if NeverBlocked(Ip) or KnownCrawler(Ip) then
      begin
        Exec('DELETE FROM abuse_queue WHERE ip = :i', [Ip]);
        Continue;
      end;
      // the score: the one kept from this week, else a lookup while the day's allowance lasts
      Score := IntValue('SELECT COALESCE(MAX(score), -1) FROM abuse_checks WHERE ip = :i AND checked > ' + SqlAgo(':d', suDay), [Ip, CHECK_DAYS]);
      if Score < 0 then
      begin
        if IntValue('SELECT COUNT(*) FROM abuse_checks WHERE checked > ' + SqlAgo('1', suDay), []) >= SettingInt('abuseipdb_checks_day', 300) then
          Break;
        Score := Check(Ip);
        if Score < 0 then
          Continue;
      end;
      if (Setting('abuseipdb_report', '1') = '1') and (IntValue('SELECT COUNT(*) FROM abuse_reports WHERE ip = :i AND at > ' + SqlAgo('1', suDay), [Ip]) = 0) and
        (IntValue('SELECT COUNT(*) FROM abuse_reports WHERE at > ' + SqlAgo('1', suDay), []) < SettingInt('abuseipdb_reports_day', 300)) then
        Report(Ip, Kinds, Paths);
      if (Threshold > 0) and (Score >= Threshold) then
      begin
        if Pos('password', Kinds) > 0 then
          Why := 'guessed passwords here'
        else if (Pos('probe', Kinds) > 0) or (Pos('admin', Kinds) > 0) then
          Why := 'probed here'
        else
          Why := 'asked for many missing pages here';
        BlockForGood(Ip, Format('AbuseIPDB %d%% and %s', [Score, Why]));
      end;
      Exec('DELETE FROM abuse_queue WHERE ip = :i', [Ip]);
    end;
  finally
    Rows.Free;
  end;
end;

initialization
  RegisterTable('CREATE TABLE IF NOT EXISTS abuse_queue (ip VARCHAR(45) PRIMARY KEY, kinds VARCHAR(60) NOT NULL DEFAULT '''',' +
    ' detail VARCHAR(300) NOT NULL DEFAULT '''', hits INT NOT NULL DEFAULT 1, first_at DATETIME NOT NULL, last_at DATETIME NOT NULL,' +
    ' INDEX (first_at)) CHARACTER SET utf8mb4');
  RegisterTable('CREATE TABLE IF NOT EXISTS abuse_checks (ip VARCHAR(45) PRIMARY KEY, score INT NOT NULL, reports INT NOT NULL DEFAULT 0,' +
    ' usage_type VARCHAR(60) NOT NULL DEFAULT '''', isp VARCHAR(100) NOT NULL DEFAULT '''', country CHAR(2) NOT NULL DEFAULT '''',' +
    ' checked DATETIME NOT NULL, INDEX (checked)) CHARACTER SET utf8mb4');
  RegisterTable('CREATE TABLE IF NOT EXISTS abuse_reports (id INT AUTO_INCREMENT PRIMARY KEY, ip VARCHAR(45) NOT NULL,' +
    ' categories VARCHAR(20) NOT NULL, comment VARCHAR(500) NOT NULL DEFAULT '''', at DATETIME NOT NULL,' + ' INDEX (ip, at), INDEX (at)) CHARACTER SET utf8mb4');
  RegisterSetting('abuseipdb_key', 'AbuseIPDB: API key (abuseipdb.com/account/api); empty turns it off', '', 'secret', 'AbuseIPDB');
  RegisterSetting('abuseipdb_block_score', 'AbuseIPDB: block for good at this confidence or above, an address that probed or guessed passwords here (0: never)',
    '90', 'number', 'AbuseIPDB');
  RegisterSetting('abuseipdb_report', 'AbuseIPDB: report probes and password guessing back (once a day an address)', '1', 'yesno', 'AbuseIPDB');
  RegisterSetting('abuseipdb_checks_day', 'AbuseIPDB: lookups a day at most (the free plan allows 1,000)', '300', 'number', 'AbuseIPDB');
  RegisterSetting('abuseipdb_reports_day', 'AbuseIPDB: reports a day at most (the free plan allows 1,000)', '300', 'number', 'AbuseIPDB');
  RegisterChore(@WorkQueue, 2);
  HostileSeen := @NoteHostile;
end.
