unit SiteWords;

{ Translations from site/lang/<code>.exedra.json, keyed by English text. Say
  uses the request's language; SiteWord takes a language. Missing
  translations return English; WordsJson supplies the browser's matching
  catalog. }

{$mode objfpc}{$H+}

interface

uses Classes, fpjson, httpdefs;

const
  LANGUAGE_CODES: array[0..34] of string = ('de', 'fr', 'es', 'it', 'pt', 'ru', 'ja', 'ko', 'zh_CN', 'zh_TW', 'nl', 'pl', 'uk', 'fi', 'cs',
    'sk', 'hu', 'tr', 'ar', 'fa', 'id', 'ro', 'sv', 'bg', 'vi', 'eo', 'af', 'ca', 'el', 'da', 'no', 'he', 'mk', 'sq', 'zh');
  LANGUAGE_NAMES: array[0..34] of string = ('Deutsch', 'Français', 'Español', 'Italiano', 'Português', 'Русский', '日本語', '한국어',
    '中文（中国）', '中文（台灣）', 'Nederlands', 'Polski', 'Українська', 'Suomi', 'Čeština', 'Slovenčina', 'Magyar', 'Türkçe', 'العربية',
    'فارسی', 'Bahasa Indonesia', 'Română', 'Svenska', 'Български', 'Tiếng Việt', 'Esperanto', 'Afrikaans', 'Català', 'Ελληνικά',
    'Dansk', 'Norsk', 'עברית', 'Македонски', 'Shqip', '中文');

type
  { Load before sharing an instance; reads do not change the catalog. }
  TWordCatalog = class
  private
    FLanguages: TJSONObject;
  public
    constructor Create;
    destructor Destroy; override;
    procedure LoadDirectory(const DirectoryName: string);
    function Text(const Language, English: string): string;
    function Json(const Language: string): string;
    procedure AddCodes(Codes: TStrings);
  end;

procedure LoadSiteWords(const DirectoryName: string);
function SiteWord(const Language, English: string): string;
{ The language the current request is answered in, set once per request by
  WebPages.  A thread with no request behind it (chores, IRC) reads en. }
procedure SetRequestLanguage(const Language: string);
function RequestLanguage: string;
{ The language a request's cookie chose, one this site speaks, or en. }
function CookieLanguage(ARequest: TRequest): string;
{ The site's word in the current request's language. }
function Say(const English: string): string;
{ A sentence about a number, with %d in both forms. }
function SayCount(N: integer; const One, Many: string): string;
function LanguageIndex(const Code: string): integer;
{ A known code as the list spells it; anything else is en. }
function CanonicalLanguage(const Code: string): string;
{ The language's own name: Deutsch, Suomi. }
function LanguageName(const Code: string): string;
{ For the html element: zh-CN, and rtl or ltr. }
function HtmlLanguage(const Code: string): string;
function LanguageDirection(const Code: string): string;
{ en and every language with a catalog, sorted by own name. }
function LanguagesWithWords: TStringList;
{ One language's words as a JSON object, for the browser. }
function WordsJson(const Language: string): string;

implementation

uses SysUtils, jsonparser;

threadvar
  CurrentLanguage: string;

var
  Catalog: TWordCatalog;
  CatalogLock: TRTLCriticalSection;

constructor TWordCatalog.Create;
begin
  inherited Create;
  FLanguages := TJSONObject.Create;
end;

destructor TWordCatalog.Destroy;
begin
  FLanguages.Free;
  inherited Destroy;
end;

procedure TWordCatalog.LoadDirectory(const DirectoryName: string);
var
  Entry: TSearchRec;
  Stream: TFileStream;
  Data: TJSONData;
  Loaded, Words, More: TJSONObject;
  Code: string;
  I: integer;
begin
  Loaded := TJSONObject.Create;
  try
    if FindFirst(IncludeTrailingPathDelimiter(DirectoryName) + '*.json', faAnyFile, Entry) = 0 then
    try
      repeat
        if (Entry.Attr and faDirectory) = 0 then
        begin
          Stream := TFileStream.Create(IncludeTrailingPathDelimiter(DirectoryName) + Entry.Name, fmOpenRead or fmShareDenyWrite);
          try
            Data := GetJSON(Stream);
          finally
            Stream.Free;
          end;
          if not (Data is TJSONObject) then
          begin
            Data.Free;
            raise Exception.Create('A language catalog must be a JSON object: ' + Entry.Name);
          end;
          // de.json and de.exedra.json are both German: each project
          // ships its own words and they meet here.  The plain one, de.json,
          // is the site's own and wins; among the others the first is kept.
          Code := Copy(Entry.Name, 1, Pos('.', Entry.Name) - 1);
          Words := Loaded.Find(Code, jtObject) as TJSONObject;
          if Words = nil then
            Loaded.Add(Code, Data)
          else
          begin
            More := TJSONObject(Data);
            try
              for I := 0 to More.Count - 1 do
                if Words.Find(More.Names[I]) = nil then
                  Words.Add(More.Names[I], More.Items[I].Clone)
                else if Entry.Name = Code + '.json' then
                  Words.Elements[More.Names[I]] := More.Items[I].Clone;
            finally
              More.Free;
            end;
          end;
        end;
      until FindNext(Entry) <> 0;
    finally
      FindClose(Entry);
    end;
    FLanguages.Free;
    FLanguages := Loaded;
    Loaded := nil;
  finally
    Loaded.Free;
  end;
end;

function TWordCatalog.Text(const Language, English: string): string;
var
  Words, Translation: TJSONData;
begin
  Result := English;
  Words := FLanguages.Find(Language);
  if not (Words is TJSONObject) then
    Exit;
  Translation := TJSONObject(Words).Find(English);
  if (Translation <> nil) and (Translation.JSONType = jtString) and (Translation.AsString <> '') then
    Result := Translation.AsString;
end;

function TWordCatalog.Json(const Language: string): string;
var
  Words: TJSONData;
begin
  Result := '{}';
  Words := FLanguages.Find(Language);
  if Words is TJSONObject then
    Result := Words.AsJSON;
end;

procedure TWordCatalog.AddCodes(Codes: TStrings);
var
  I: integer;
begin
  for I := 0 to FLanguages.Count - 1 do
    Codes.Add(FLanguages.Names[I]);
end;

procedure LoadSiteWords(const DirectoryName: string);
begin
  EnterCriticalSection(CatalogLock);
  try
    Catalog.LoadDirectory(DirectoryName);
  finally
    LeaveCriticalSection(CatalogLock);
  end;
end;

function SiteWord(const Language, English: string): string;
begin
  EnterCriticalSection(CatalogLock);
  try
    Result := Catalog.Text(Language, English);
  finally
    LeaveCriticalSection(CatalogLock);
  end;
end;

procedure SetRequestLanguage(const Language: string);
begin
  CurrentLanguage := Language;
end;

function CookieLanguage(ARequest: TRequest): string;
var
  Asked: string;
begin
  Asked := ARequest.CookieFields.Values['site_language'];
  // the wiki's cookie from before there was a site-wide one
  if Asked = '' then
    Asked := ARequest.CookieFields.Values['wiki_language'];
  Result := CanonicalLanguage(Asked);
end;

function RequestLanguage: string;
begin
  Result := CurrentLanguage;
  if Result = '' then
    Result := 'en';
end;

function Say(const English: string): string;
begin
  Result := SiteWord(RequestLanguage, English);
end;

function SayCount(N: integer; const One, Many: string): string;
begin
  if N = 1 then
    Result := Format(Say(One), [N])
  else
    Result := Format(Say(Many), [N]);
end;

function LanguageIndex(const Code: string): integer;
begin
  for Result := 0 to High(LANGUAGE_CODES) do
    if SameText(LANGUAGE_CODES[Result], Code) then
      Exit;
  Result := -1;
end;

function CanonicalLanguage(const Code: string): string;
var
  Language: integer;
begin
  Language := LanguageIndex(Code);
  if Language >= 0 then
    Result := LANGUAGE_CODES[Language]
  else
    Result := 'en';
end;

function LanguageName(const Code: string): string;
var
  Language: integer;
begin
  Language := LanguageIndex(Code);
  if Language >= 0 then
    Result := LANGUAGE_NAMES[Language]
  else
    Result := 'English';
end;

function HtmlLanguage(const Code: string): string;
begin
  Result := StringReplace(Code, '_', '-', [rfReplaceAll]);
end;

function LanguageDirection(const Code: string): string;
begin
  if (Code = 'ar') or (Code = 'fa') or (Code = 'he') then
    Result := 'rtl'
  else
    Result := 'ltr';
end;

function LanguagesWithWords: TStringList;
var
  I: integer;
  Codes: TStringList;
begin
  Result := TStringList.Create;
  Codes := TStringList.Create;
  try
    EnterCriticalSection(CatalogLock);
    try
      Catalog.AddCodes(Codes);
    finally
      LeaveCriticalSection(CatalogLock);
    end;
    Result.AddPair('English', 'en');
    for I := 0 to Codes.Count - 1 do
      if LanguageIndex(Codes[I]) >= 0 then
        Result.AddPair(LanguageName(Codes[I]), CanonicalLanguage(Codes[I]));
    Result.Sort;
  finally
    Codes.Free;
  end;
end;

function WordsJson(const Language: string): string;
begin
  EnterCriticalSection(CatalogLock);
  try
    Result := Catalog.Json(Language);
  finally
    LeaveCriticalSection(CatalogLock);
  end;
end;

initialization
  InitCriticalSection(CatalogLock);
  Catalog := TWordCatalog.Create;

finalization
  Catalog.Free;
  DoneCriticalSection(CatalogLock);
end.
