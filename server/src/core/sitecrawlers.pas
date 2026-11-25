unit SiteCrawlers;

{ Identify crawlers by published IP ranges, fetched daily and cached in
  crawler-ranges.json. crawler-sources.txt adds sources; its format is in
  docs/CODE-MAP.md. A matching browser name from outside its company's
  ranges is unverified. }

{$mode objfpc}{$H+}

interface

uses
  fpjson;

{ The crawler whose published ranges hold Address ('' for none), and its company. }
function PublishedCrawler(const Address: string; out Company: string): string;
{ The company whose crawler a browser string names, when that company
  publishes its addresses ('' otherwise): to tell a pretender. }
function ClaimedCompany(const Agent: string): string;
{ True when every list of Company holds ranges, so an address outside them is
  really outside: a list that never downloaded proves nothing. }
function CompanyListsReady(const Company: string): boolean;
{ The lists, for the admin: company, crawler, address, ranges, the list's own
  date, when it was fetched, and what went wrong if it did. }
function CrawlerSourcesJSON: TJSONArray;

implementation

uses
  Classes, SysUtils, StrUtils, DateUtils, Sockets, jsonparser, fphttpclient, SiteDb, SiteTls;

type
  TSource = record
    Company, Name, Url, word: string;
    Created, Fetched, Error: string;
    Prefixes: TStringArray;
  end;

  TBytes16 = array[0..15] of byte;

  TRange = record
    Source: integer;
    Bytes: TBytes16;
    Bits: integer;
  end;

const
  BUILT_IN: array[0..17] of array[0..3] of string = (
    ('Google', 'Googlebot and Google''s common crawlers', 'https://developers.google.com/static/crawling/ipranges/common-crawlers.json', 'google'),
    ('Google', 'Google special crawlers (AdsBot and others)', 'https://developers.google.com/static/crawling/ipranges/special-crawlers.json', 'google'),
    ('Google', 'Google user-triggered fetchers', 'https://developers.google.com/static/crawling/ipranges/user-triggered-fetchers.json', 'google'),
    ('Google', 'Google''s own user-triggered fetchers', 'https://developers.google.com/static/crawling/ipranges/user-triggered-fetchers-google.json', 'google'),
    ('Microsoft', 'Bingbot', 'https://www.bing.com/toolbox/bingbot.json', 'bingbot'),
    ('OpenAI', 'GPTBot', 'https://openai.com/gptbot.json', 'gptbot'),
    ('OpenAI', 'OAI-SearchBot', 'https://openai.com/searchbot.json', 'oai-searchbot'),
    ('OpenAI', 'ChatGPT-User', 'https://openai.com/chatgpt-user.json', 'chatgpt-user'),
    ('OpenAI', 'OpenAI AdsBot', 'https://openai.com/adsbot.json', 'oai-adsbot'),
    ('Apple', 'Applebot', 'https://search.developer.apple.com/applebot.json', 'applebot'),
    ('Perplexity', 'PerplexityBot', 'https://www.perplexity.ai/perplexitybot.json', 'perplexitybot'),
    ('Perplexity', 'Perplexity-User', 'https://www.perplexity.ai/perplexity-user.json', 'perplexity-user'),
    ('DuckDuckGo', 'DuckDuckBot', 'https://duckduckgo.com/duckduckbot.json', 'duckduckbot'),
    ('DuckDuckGo', 'DuckAssistBot', 'https://duckduckgo.com/duckassistbot.json', 'duckassistbot'),
    ('Common Crawl', 'CCBot', 'https://index.commoncrawl.org/ccbot.json', 'ccbot'),
    ('Mistral', 'MistralAI-Index', 'https://mistral.ai/mistralai-index-ips.json', 'mistralai-index'),
    ('Mistral', 'MistralAI-User', 'https://mistral.ai/mistralai-user-ips.json', 'mistralai-user'),
    ('Anthropic', 'ClaudeBot and Anthropic''s other crawlers', 'https://claude.com/crawling/bots.json', 'claude'));
  USER_AGENT = 'ExedraCrawlerRanges/1.0 (reads the published crawler address lists once a day)';

var
  Lock: TRTLCriticalSection;
  Sources: array of TSource;
  Ranges: array of TRange;
  LastFetch: TDateTime;

function DataFolder: string;
begin
  Result := IncludeTrailingPathDelimiter(Setting('files', ExtractFilePath(ParamStr(0)))) + 'data' + PathDelim;
end;

{ An address as 16 bytes, IPv4 as ::ffff:a.b.c.d (Shift 96 then); False when it is not one. }
function AddressBytes(const Text: string; out Bytes: TBytes16; out Shift: integer): boolean;
var
  Parts: TStringArray;
  V6: in6_addr;
  I, N: integer;
begin
  Result := False;
  Shift := 0;
  for I := 0 to 15 do
    Bytes[I] := 0;
  Parts := Trim(Text).Split(['.']);
  if (Length(Parts) = 4) and (Pos(':', Text) = 0) then
  begin
    for I := 0 to 3 do
    begin
      N := StrToIntDef(Parts[I], -1);
      if (N < 0) or (N > 255) then
        Exit;
      Bytes[12 + I] := N;
    end;
    Bytes[10] := 255;
    Bytes[11] := 255;
    Shift := 96;
    Exit(True);
  end;
  if not TryStrToHostAddr6(Trim(Text), V6) then
    Exit;
  for I := 0 to 15 do
    Bytes[I] := V6.u6_addr8[I];
  Result := True;
end;

function Inside(const Address: TBytes16; const Range: TRange): boolean;
var
  Full, Rest, I: integer;
  Mask: byte;
begin
  Full := Range.Bits div 8;
  Rest := Range.Bits mod 8;
  for I := 0 to Full - 1 do
    if Address[I] <> Range.Bytes[I] then
      Exit(False);
  if Rest > 0 then
  begin
    Mask := byte($FF shl (8 - Rest));
    if (Address[Full] and Mask) <> (Range.Bytes[Full] and Mask) then
      Exit(False);
  end;
  Result := True;
end;

procedure AddRange(var List: array of TRange; var Count: integer; Source: integer; const Prefix: string);
var
  Slash, Bits, Shift: integer;
  Bytes: TBytes16;
begin
  Slash := Pos('/', Prefix);
  if Slash = 0 then
    Exit;
  Bits := StrToIntDef(Copy(Prefix, Slash + 1, 3), -1);
  if not AddressBytes(Copy(Prefix, 1, Slash - 1), Bytes, Shift) or (Bits < 0) or (Bits + Shift > 128) then
    Exit;
  List[Count].Source := Source;
  List[Count].Bytes := Bytes;
  List[Count].Bits := Bits + Shift;
  Inc(Count);
end;

{ The ranges made again from the sources' prefixes; the caller holds Lock. }
procedure Rebuild;
var
  I, Total, Count: integer;
  Prefix: string;
begin
  Total := 0;
  for I := 0 to High(Sources) do
    Inc(Total, Length(Sources[I].Prefixes));
  SetLength(Ranges, Total);
  Count := 0;
  for I := 0 to High(Sources) do
    for Prefix in Sources[I].Prefixes do
      AddRange(Ranges, Count, I, Prefix);
  SetLength(Ranges, Count);
end;

{ The built-in lists and those in crawler-sources.txt, as sources without prefixes. }
function SourceList: specialize TArray<TSource>;
var
  Lines: TStringList;
  Line: string;
  Parts: TStringArray;
  I, N: integer;
begin
  Result := nil;
  SetLength(Result, Length(BUILT_IN));
  for I := 0 to High(BUILT_IN) do
  begin
    Result[I].Company := BUILT_IN[I][0];
    Result[I].Name := BUILT_IN[I][1];
    Result[I].Url := BUILT_IN[I][2];
    Result[I].word := BUILT_IN[I][3];
  end;
  if not FileExists(DataFolder + 'crawler-sources.txt') then
    Exit;
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(DataFolder + 'crawler-sources.txt');
    for Line in Lines do
    begin
      if (Trim(Line) = '') or StartsStr('#', Trim(Line)) then
        Continue;
      Parts := Line.Split([#9]);
      if (Length(Parts) < 3) or not StartsStr('https://', Trim(Parts[2])) then
        Continue;
      N := Length(Result);
      SetLength(Result, N + 1);
      Result[N].Company := Trim(Parts[0]);
      Result[N].Name := Trim(Parts[1]);
      Result[N].Url := Trim(Parts[2]);
      if Length(Parts) >= 4 then
        Result[N].word := LowerCase(Trim(Parts[3]))
      else
        Result[N].word := LowerCase(Result[N].Name);
    end;
  finally
    Lines.Free;
  end;
end;

procedure SaveCache;
var
  Data, Item: TJSONObject;
  List, Prefixes: TJSONArray;
  I: integer;
  Prefix: string;
  Text: TStringList;
begin
  Data := TJSONObject.Create;
  Text := TStringList.Create;
  try
    Data.Add('fetched', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', LastFetch));
    List := TJSONArray.Create;
    for I := 0 to High(Sources) do
    begin
      Item := TJSONObject.Create(['company', Sources[I].Company, 'name', Sources[I].Name, 'url', Sources[I].Url, 'word', Sources[I].word,
        'created', Sources[I].Created, 'fetched', Sources[I].Fetched, 'error', Sources[I].Error]);
      Prefixes := TJSONArray.Create;
      for Prefix in Sources[I].Prefixes do
        Prefixes.Add(Prefix);
      Item.Add('prefixes', Prefixes);
      List.Add(Item);
    end;
    Data.Add('sources', List);
    Text.Text := Data.AsJSON;
    try
      Text.SaveToFile(DataFolder + 'crawler-ranges.json');
    except
      on E: Exception do
        Log('Crawler ranges not saved: ' + E.Message);
    end;
  finally
    Text.Free;
    Data.Free;
  end;
end;

procedure LoadCache;
var
  Text: TStringList;
  Data: TJSONData;
  List: TJSONArray;
  Item: TJSONObject;
  I, J: integer;
begin
  if not FileExists(DataFolder + 'crawler-ranges.json') then
    Exit;
  Text := TStringList.Create;
  Data := nil;
  try
    try
      Text.LoadFromFile(DataFolder + 'crawler-ranges.json');
      Data := GetJSON(Text.Text);
      List := TJSONObject(Data).Arrays['sources'];
      EnterCriticalSection(Lock);
      try
        SetLength(Sources, List.Count);
        for I := 0 to List.Count - 1 do
        begin
          Item := List.Objects[I];
          Sources[I].Company := Item.Get('company', '');
          Sources[I].Name := Item.Get('name', '');
          Sources[I].Url := Item.Get('url', '');
          Sources[I].word := Item.Get('word', '');
          Sources[I].Created := Item.Get('created', '');
          Sources[I].Fetched := Item.Get('fetched', '');
          Sources[I].Error := Item.Get('error', '');
          SetLength(Sources[I].Prefixes, Item.Arrays['prefixes'].Count);
          for J := 0 to Item.Arrays['prefixes'].Count - 1 do
            Sources[I].Prefixes[J] := Item.Arrays['prefixes'].Strings[J];
        end;
        LastFetch := ScanDateTime('yyyy-mm-dd"T"hh:nn:ss', TJSONObject(Data).Get('fetched', '2000-01-01T00:00:00'));
        Rebuild;
      finally
        LeaveCriticalSection(Lock);
      end;
    except
      on E: Exception do
        Log('Crawler ranges not read: ' + E.Message);
    end;
  finally
    Data.Free;
    Text.Free;
  end;
end;

{ One list from its company; the old prefixes stay when it does not come. }
procedure Fetch(var Source: TSource; const Old: TSource);
var
  Client: TFPHTTPClient;
  Body: string;
  Data: TJSONData;
  List: TJSONArray;
  I, N: integer;
  Prefix: string;
begin
  Source.Prefixes := Old.Prefixes;
  Source.Created := Old.Created;
  Source.Fetched := Old.Fetched;
  Source.Error := '';
  Client := TFPHTTPClient.Create(nil);
  Data := nil;
  try
    try
      Client.ConnectTimeout := 10000;
      Client.IOTimeout := 20000;
      Client.AllowRedirect := True;
      Client.MaxRedirects := 3;
      Client.AddHeader('User-Agent', USER_AGENT);
      Client.AddHeader('Accept', 'application/json');
      Body := Client.Get(Source.Url);
      if Client.ResponseStatusCode <> 200 then
        raise Exception.CreateFmt('answer %d', [Client.ResponseStatusCode]);
      Data := GetJSON(Body);
      List := TJSONObject(Data).Arrays['prefixes'];
      SetLength(Source.Prefixes, List.Count);
      N := 0;
      for I := 0 to List.Count - 1 do
      begin
        Prefix := List.Objects[I].Get('ipv4Prefix', List.Objects[I].Get('ipv6Prefix', ''));
        if Prefix <> '' then
        begin
          Source.Prefixes[N] := Prefix;
          Inc(N);
        end;
      end;
      SetLength(Source.Prefixes, N);
      Source.Created := Copy(TJSONObject(Data).Get('creationTime', ''), 1, 10);
      Source.Fetched := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', NowUTC);
    except
      on E: Exception do
        Source.Error := Copy(E.Message, 1, 200);
    end;
  finally
    Data.Free;
    Client.Free;
  end;
end;

{ Once an hour: a day after the last reading, the lists read again. }
procedure Refresh;
var
  Fresh: specialize TArray<TSource>;
  Old: TSource;
  I, J: integer;
begin
  if Now - LastFetch < 1 then
    Exit;
  Fresh := SourceList;
  for I := 0 to High(Fresh) do
  begin
    Old := Fresh[I];
    EnterCriticalSection(Lock);
    try
      for J := 0 to High(Sources) do
        if Sources[J].Url = Fresh[I].Url then
          Old := Sources[J];
    finally
      LeaveCriticalSection(Lock);
    end;
    Fetch(Fresh[I], Old);
    Sleep(1000);
  end;
  EnterCriticalSection(Lock);
  try
    SetLength(Sources, Length(Fresh));
    for I := 0 to High(Fresh) do
      Sources[I] := Fresh[I];
    LastFetch := Now;
    Rebuild;
  finally
    LeaveCriticalSection(Lock);
  end;
  SaveCache;
end;

function PublishedCrawler(const Address: string; out Company: string): string;
var
  Bytes: TBytes16;
  Shift, I: integer;
begin
  Result := '';
  Company := '';
  if not AddressBytes(Address, Bytes, Shift) then
    Exit;
  EnterCriticalSection(Lock);
  try
    for I := 0 to High(Ranges) do
      if Inside(Bytes, Ranges[I]) then
      begin
        Result := Sources[Ranges[I].Source].Name;
        Company := Sources[Ranges[I].Source].Company;
        Exit;
      end;
  finally
    LeaveCriticalSection(Lock);
  end;
end;

function ClaimedCompany(const Agent: string): string;
var
  Lower: string;
  I: integer;
begin
  Result := '';
  Lower := LowerCase(Agent);
  EnterCriticalSection(Lock);
  try
    for I := 0 to High(Sources) do
      // google alone is any browser on a Google phone; its crawlers say bot or google- something
      if (Sources[I].word <> '') and (Pos(Sources[I].word, Lower) > 0) and ((Sources[I].word <> 'google') or (Pos('googlebot', Lower) > 0) or
        (Pos('google-', Lower) > 0) or (Pos('googleother', Lower) > 0) or (Pos('adsbot-google', Lower) > 0) or (Pos('storebot-google', Lower) > 0)) and
        // that word alone is also a desktop app's browser string; ClaudeBot and Claude-User are the crawlers
        ((Sources[I].word <> 'claude') or (Pos('claudebot', Lower) > 0) or (Pos('claude-', Lower) > 0)) then
        Exit(Sources[I].Company);
  finally
    LeaveCriticalSection(Lock);
  end;
end;

function CompanyListsReady(const Company: string): boolean;
var
  I: integer;
  Seen: boolean;
begin
  Seen := False;
  Result := True;
  EnterCriticalSection(Lock);
  try
    for I := 0 to High(Sources) do
      if Sources[I].Company = Company then
      begin
        Seen := True;
        if Length(Sources[I].Prefixes) = 0 then
          Result := False;
      end;
  finally
    LeaveCriticalSection(Lock);
  end;
  Result := Result and Seen;
end;

function CrawlerSourcesJSON: TJSONArray;
var
  I: integer;
begin
  Result := TJSONArray.Create;
  EnterCriticalSection(Lock);
  try
    for I := 0 to High(Sources) do
      Result.Add(TJSONObject.Create(['company', Sources[I].Company, 'name', Sources[I].Name, 'url', Sources[I].Url, 'ranges',
        Length(Sources[I].Prefixes), 'created', Sources[I].Created, 'fetched', Sources[I].Fetched, 'error', Sources[I].Error]));
  finally
    LeaveCriticalSection(Lock);
  end;
end;

initialization
  InitCriticalSection(Lock);
  LastFetch := 0;
  RegisterStartup(@LoadCache);
  RegisterChore(@Refresh, 60);

finalization
  DoneCriticalSection(Lock);
end.
