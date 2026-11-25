unit WebPages;

{ Shared home, account and admin pages, templates and installable app files.
  Registered modules add home cards, scripts and a start page; a single
  enabled module opens on its front page. Uploaded branding is kept in
  data/site, with static defaults. See docs/CODE-MAP.md. }

{$mode objfpc}{$H+}

interface

uses
  httpdefs, SiteUsers;

type
  THomePart = function: string;

  TRobotsPart = function(ARequest: TRequest): string;

  { Where / sends this reader, or '' for the home page. }
  THomeStart = function(const Me: TMember): string;

var
  { A site's own line on the sign-in page, HTML, under the words about one
    box for both; nil for none.  A unit on top sets it. }
  SignInNote: THomePart = nil;
  { A site's own lines for robots.txt, after the common ones: more Disallow
    lines and its Sitemap; nil for none.  A unit on top sets it. }
  RobotsPart: TRobotsPart = nil;
  { Set by a part that opens the site on its own page. }
  HomeStart: THomeStart = nil;

procedure LoadTemplates;
{ Adds a part to the home page: the template shows it where it puts Name in
  double braces, and Make makes it along with the page's other lists. }
procedure RegisterHomePart(const Name: string; Make: THomePart);
{ A value every template may use by Name in double braces; Make runs only
  for a template that has it. }
procedure RegisterPageValue(const Name: string; Make: THomePart);
{ The request this thread is answering, for a page value that depends on
  who asks or for what; nil before the first one. }
function PageRequest: TRequest;
function CachedHomePart(const Name: string): string;
{ Language empty means the current request's. }
function FillTemplate(const Name: string; const Values: array of string; const Language: string = ''): string;
procedure SendPage(AResponse: TResponse; const Html: string);
{ After a form's POST: the browser loads TargetUrl with a GET (303), and the
  answer is sent, as SendText and SendJSON send theirs.  The framework's
  SendRedirect answers 307, which keeps the POST. }
procedure SeeOther(AResponse: TResponse; const TargetUrl: string);
{ the folder the site's templates, static files and data live under }
function FilesRoot: string;
{ Module page in site/templates/page.html, with shared and module links in
  Side and Content beside them. Build Side with SideGroup and SideLink.
  Styles and Scripts are comma-separated /static file names; BodyClass and
  MainClass let the module style the frame. }
function PartPage(ARequest: TRequest; const Me: TMember; const Title, Content: string; const Side: string = ''; const Styles: string = '';
  const Scripts: string = ''; const BodyClass: string = ''; const MainClass: string = ''): string;
{ A heading in the left column's list, and a link under it. }
function SideGroup(const Caption: string): string;
function SideLink(const Address, Caption: string; MembersOnly: boolean = False): string;
{ A module's card on the home page: its name as a link, and a few lines of
  what is new in it, each made with HomeRow.  Empty says so when there are
  none yet.  A module registers it with RegisterHomePart under a name the
  home template has ('forum_home'). }
function HomeCard(const Title, Address, Rows, Empty: string): string;
function HomeRow(const Address, Caption, Note: string): string;
function AccountBox(const Me: TMember; const Language: string = ''): string;
function AdminLink(const Me: TMember): string;
{ The language a request's cookies ask for, en when none or nonsense. }
function LanguageOfRequest(ARequest: TRequest): string;
{ The app page: View and Target say what it opens, Plain is the same as
  plain HTML for readers without scripts. }
procedure SendApp(ARequest: TRequest; AResponse: TResponse; const View, Target, Title, Plain: string; Thread: integer);
{ The member a /u/ or /dm/ address names, '' for none. }
function NameInPath(const Raw: string): string;
{ The request's one address for search engines: this site, the path as
  asked, nothing after a question mark; for <link rel="canonical">. }
function CanonicalUrl(ARequest: TRequest): string;
function E(const S: string): string;
{ A date as the admin chose to show dates (the setting date_format,
  m-d-yyyy to begin with: 1-30-2020), from an ISO date or time; text
  that is not one comes back as it is.  "reader" leaves yyyy-mm-dd for
  the browser to put in the reader's own language. }
function ShowDate(const Iso: string): string;
{ The same with the time of day after it, hh:nn, as the ISO text has it. }
function ShowDateTime(const Iso: string): string;
{ A date for a page: <time datetime="ISO">the date</time>. }
function DateTag(const Iso: string; WithTime: boolean = False): string;

const
  DATE_FORMATS = 'm-d-yyyy|mm-dd-yyyy|m/d/yyyy|mm/dd/yyyy|d-m-yyyy|dd/mm/yyyy|dd.mm.yyyy|yyyy-mm-dd|reader';

function Ago(Minutes: integer): string;
function Plural(N: integer; const One, Many: string): string;

implementation

uses
  Classes, SysUtils, StrUtils, Variants, fpjson, httproute, fpmimetypes, fptemplate,
  FPImage, FPReadPNG, FPReadJPEG, FPWritePNG, FPImgCanv, FPCanvas,
  SiteDb, SiteSql, SiteMarkup, SiteLogins, SiteFiles, SiteStatic, SiteAdmin, SiteGuard, SiteWords, SiteParts, SiteBase;

var
  Templates: TStringList;
  PageValues: array of record
    Name: string;
    Make: THomePart;
    end;
  { Each language keeps its home page lists for 30 seconds. }
  Parts: array of record
    Name: string;
    Html: array[0..High(LANGUAGE_CODES) + 1] of string;
    HomeMade: array[0..High(LANGUAGE_CODES) + 1] of TDateTime;
    Make: THomePart;
    end;
  HomeLock: TRTLCriticalSection;
  { Goes on /static addresses in the templates, so a browser takes the new
    app.js and site.css after a restart instead of the copy it kept. }
  Started: string;

function ShowDate(const Iso: string): string;
var
  Pattern: string;
  Y, M, D, P: integer;
begin
  Result := Iso;
  if (Length(Iso) < 10) or (Iso[5] <> '-') or (Iso[8] <> '-') then
    Exit;
  Y := StrToIntDef(Copy(Iso, 1, 4), 0);
  M := StrToIntDef(Copy(Iso, 6, 2), 0);
  D := StrToIntDef(Copy(Iso, 9, 2), 0);
  if (Y = 0) or (M < 1) or (M > 12) or (D < 1) or (D > 31) then
    Exit;
  Pattern := Setting('date_format', 'm-d-yyyy');
  if (Pattern = 'reader') or (Pos('|' + Pattern + '|', '|' + DATE_FORMATS + '|') = 0) then
    Exit(Copy(Iso, 1, 10));
  Result := '';
  P := 1;
  while P <= Length(Pattern) do
    if Copy(Pattern, P, 4) = 'yyyy' then
    begin
      Result := Result + IntToStr(Y);
      Inc(P, 4);
    end
    else if Copy(Pattern, P, 2) = 'mm' then
    begin
      Result := Result + Format('%.2d', [M]);
      Inc(P, 2);
    end
    else if Copy(Pattern, P, 2) = 'dd' then
    begin
      Result := Result + Format('%.2d', [D]);
      Inc(P, 2);
    end
    else if Pattern[P] = 'm' then
    begin
      Result := Result + IntToStr(M);
      Inc(P);
    end
    else if Pattern[P] = 'd' then
    begin
      Result := Result + IntToStr(D);
      Inc(P);
    end
    else
    begin
      Result := Result + Pattern[P];
      Inc(P);
    end;
end;

function ShowDateTime(const Iso: string): string;
begin
  Result := ShowDate(Iso);
  if (Result <> Iso) and (Length(Iso) >= 16) and (Iso[11] in ['T', ' ']) then
    Result := Result + ' ' + Copy(Iso, 12, 5);
end;

function DateTag(const Iso: string; WithTime: boolean): string;
begin
  if WithTime then
    // UTC on the page; a script puts it on the reader's clock
    Result := '<time datetime="' + E(Iso) + '" data-show="datetime">' + E(ShowDateTime(Iso)) + ' UTC</time>'
  else
    Result := '<time datetime="' + E(Iso) + '" data-show="date">' + E(ShowDate(Iso)) + '</time>';
end;

function E(const S: string): string;
begin
  Result := HtmlText(S);
end;

function FilesRoot: string;
begin
  Result := IncludeTrailingPathDelimiter(Setting('files', ExtractFilePath(ParamStr(0))));
end;

{ Where the admin page keeps the site's icon and logo. }
function LookDir: string;
begin
  Result := FilesRoot + 'data' + PathDelim + 'site' + PathDelim;
end;

{ /site/Name with its age after it, so a new upload is not hidden by a cached
  copy; '' when there is no such file. }
function LookUrl(const Name: string): string;
begin
  Result := '';
  if FileExists(LookDir + Name) then
    Result := '/site/' + Name + '?v=' + IntToStr(FileAge(LookDir + Name));
end;

{ Every templates/*.html, by its name without the extension: the ones this
  unit serves and whatever the other units bring. }
procedure LoadTemplates;
var
  R: TSearchRec;
begin
  LoadSiteWords(FilesRoot + 'lang');
  Templates := TStringList.Create;
  if FindFirst(FilesRoot + 'templates/*.html', faAnyFile, R) = 0 then
  try
    repeat
      if (R.Attr and faDirectory) = 0 then
        with TStringList.Create do
        try
          LoadFromFile(FilesRoot + 'templates/' + R.Name);
          Templates.AddPair(ChangeFileExt(R.Name, ''), Text);
        finally
          Free;
        end;
    until FindNext(R) <> 0;
  finally
    SysUtils.FindClose(R);
  end;
  ServeFolder('static', FilesRoot + 'static');
  ForceDirectories(LookDir);
  ServeFolder('site', LookDir);
end;

{ A site's own icon when it has one, else the plain one. }
function IconUrl(Size: integer): string;
begin
  Result := LookUrl(Format('icon-%d.png', [Size]));
  if Result = '' then
    Result := Format('/static/icon-%d.png', [Size]);
end;

{ What the brand link shows: the logo, the name, or both. }
function Brand: string;
begin
  Result := '';
  if LookUrl('logo.png') <> '' then
    Result := '<img class="brandlogo" src="' + LookUrl('logo.png') + '" alt="' + E(Setting('name', 'Exedra')) + '">';
  if (Result = '') or (Setting('show_name', '1') = '1') then
    Result := Result + '<span>' + E(Setting('name', 'Exedra')) + '</span>';
end;

threadvar
  RequestAddress: string;
  RequestNow: TRequest;

function PageRequest: TRequest;
begin
  Result := RequestNow;
end;

{ The picker every page carries: GET /language sets the cookie and comes back
  here, so it works with no script.  words.js submits it on a change. }
function LanguageForm(const Language: string): string;
var
  Choices: TStringList;
  I: integer;
begin
  Result := '<form method="get" action="/language" class="site-language"><input type="hidden" name="return" value="' + E(RequestAddress) +
    '"><label><span>' + E(SiteWord(Language, 'Language')) + '</span> <select name="language" aria-label="' + E(SiteWord(Language, 'Language')) + '">';
  Choices := LanguagesWithWords;
  try
    for I := 0 to Choices.Count - 1 do
    begin
      Result := Result + '<option value="' + E(Choices.ValueFromIndex[I]) + '" lang="' + E(HtmlLanguage(Choices.ValueFromIndex[I])) + '"';
      if Choices.ValueFromIndex[I] = Language then
        Result := Result + ' selected';
      Result := Result + '>' + E(Choices.Names[I]) + '</option>';
    end;
  finally
    Choices.Free;
  end;
  Result := Result + '</select></label> <button>' + E(SiteWord(Language, 'Apply')) + '</button></form>';
end;

{ The line that names the software, unless the site turned it off. }
function PoweredBy(const Language: string): string;
begin
  Result := '';
  if Setting('powered_by', '1') = '1' then
    Result := '<p class="powered">' + Format(E(SiteWord(Language, 'Powered by %s')), ['<a href="https://github.com/TonyStone31/exedra" rel="noopener">Exedra</a>']) + '</p>';
end;

function FillTemplate(const Name: string; const Values: array of string; const Language: string): string;
var
  T: TTemplateParser;
  I, TagStart, TagEnd: integer;
  Source, TagName, Lang: string;
begin
  Lang := Language;
  if Lang = '' then
    Lang := RequestLanguage;
  T := TTemplateParser.Create;
  try
    T.StartDelimiter := '{{';
    T.EndDelimiter := '}}';
    T.Values['site'] := E(Setting('name', 'Exedra'));
    T.Values['tagline'] := E(Setting('tagline', ''));
    T.Values['icon32'] := IconUrl(32);
    T.Values['icon180'] := IconUrl(180);
    T.Values['brand'] := Brand;
    T.Values['powered'] := PoweredBy(Lang);
    // the date format rides along, so a new choice reaches every cached script
    T.Values['v'] := Started + StringReplace(StringReplace(StringReplace(Setting('date_format', 'm-d-yyyy'), '/', 's', [rfReplaceAll]),
      '.', 'p', [rfReplaceAll]), '-', '', [rfReplaceAll]);
    T.Values['partscripts'] := PartScriptTags(T.Values['v']);
    T.Values['nav'] := PartLinks;
    T.Values['lang'] := HtmlLanguage(Lang);
    T.Values['langcode'] := Lang;
    T.Values['dir'] := LanguageDirection(Lang);
    for I := 0 to Length(Values) div 2 - 1 do
      T.Values[Values[I * 2]] := Values[I * 2 + 1];
    Source := Templates.Values[Name];
    for I := 0 to High(PageValues) do
      if (T.Values[PageValues[I].Name] = '') and (Pos('{{' + PageValues[I].Name + '}}', Source) > 0) then
        T.Values[PageValues[I].Name] := PageValues[I].Make();
    if Pos('{{language_form}}', Source) > 0 then
      T.Values['language_form'] := LanguageForm(Lang);
    TagStart := Pos('{{t:', Source);
    while TagStart > 0 do
    begin
      TagEnd := Pos('}}', Copy(Source, TagStart, MaxInt));
      if TagEnd = 0 then
        Break;
      TagEnd := TagStart + TagEnd - 1;
      TagName := Copy(Source, TagStart + 2, TagEnd - TagStart - 2);
      T.Values[TagName] := E(SiteWord(Lang, Copy(TagName, 3, MaxInt)));
      TagStart := Pos('{{t:', Source, TagEnd + 2);
    end;
    Result := T.ParseString(Source);
    // every page's first script: what lets a site sit under a path of its domain
    Result := StringReplace(Result, '<head>', '<head>'#10'<script src="/static/base.js?v=' + T.Values['v'] + '"></script>', []);
  finally
    T.Free;
  end;
end;

procedure SeeOther(AResponse: TResponse; const TargetUrl: string);
begin
  AResponse.Location := TargetUrl;
  AResponse.Code := 303;
  AResponse.CodeText := 'See Other';
  AResponse.SetCustomHeader('Cache-Control', 'no-store');
  AResponse.SendContent;
end;

procedure SendPage(AResponse: TResponse; const Html: string);
var
  Vary: string;
begin
  if (AResponse.CacheControl = '') and (AResponse.GetCustomHeader('Cache-Control') = '') then
    AResponse.SetCustomHeader('Cache-Control', 'private, no-store');
  Vary := AResponse.GetCustomHeader('Vary');
  if (Trim(Vary) <> '*') and not AnsiMatchText('Cookie', Vary.Split([',', ' '], TStringSplitOptions.ExcludeEmpty)) then
  begin
    if Vary <> '' then
      Vary := Vary + ', ';
    AResponse.SetCustomHeader('Vary', Vary + 'Cookie');
  end;
  if Setting('robots', '1') <> '1' then
    AResponse.SetCustomHeader('X-Robots-Tag', 'noindex, nofollow');
  AResponse.ContentType := 'text/html; charset=utf-8';
  AResponse.Content := Html;
  AResponse.SendContent;
end;

function Ago(Minutes: integer): string;
begin
  if Minutes < 0 then
    Result := ''
  else if Minutes < 2 then
    Result := Say('just now')
  else if Minutes < 60 then
    Result := Format(Say('%d min ago'), [Minutes])
  else if Minutes < 48 * 60 then
    Result := Format(Say('%d hours ago'), [Minutes div 60])
  else
    Result := Format(Say('%d days ago'), [Minutes div (24 * 60)]);
end;

function Plural(N: integer; const One, Many: string): string;
begin
  Result := SayCount(N, '%d ' + One, '%d ' + Many);
end;

function SideGroup(const Caption: string): string;
begin
  Result := '<div class="group">' + E(Caption) + '</div>';
end;

function SideLink(const Address, Caption: string; MembersOnly: boolean): string;
begin
  Result := '<a class="room';
  if MembersOnly then
    Result := Result + ' member-only';
  Result := Result + '" href="' + E(Address) + '">' + E(Caption) + '</a>';
end;

function PartPage(ARequest: TRequest; const Me: TMember; const Title, Content: string; const Side: string; const Styles: string;
  const Scripts: string; const BodyClass: string; const MainClass: string): string;
var
  Name, StyleTags, ScriptTags, Who, Version: string;
begin
  // the same stamp the templates put on their own files, so a new build is fetched anew
  Version := Started + StringReplace(StringReplace(StringReplace(Setting('date_format', 'm-d-yyyy'), '/', 's', [rfReplaceAll]), '.', 'p', [rfReplaceAll]),
    '-', '', [rfReplaceAll]);
  StyleTags := '';
  for Name in Styles.Split([','], TStringSplitOptions.ExcludeEmpty) do
    StyleTags := StyleTags + '<link rel="stylesheet" href="/static/' + E(Trim(Name)) + '?v=' + Version + '">';
  ScriptTags := '';
  for Name in Scripts.Split([','], TStringSplitOptions.ExcludeEmpty) do
    ScriptTags := ScriptTags + '<script src="/static/' + E(Trim(Name)) + '?v=' + Version + '"></script>';
  Who := 'guest';
  if Me.Id > 0 then
    Who := 'member';
  Result := FillTemplate('page', ['title', E(Title), 'canonical', E(CanonicalUrl(ARequest)), 'who', Who, 'account', AccountBox(Me), 'content',
    Content, 'side', Side, 'styles', StyleTags, 'scripts', ScriptTags, 'bodyclass', E(BodyClass), 'mainclass', E(MainClass)]);
end;

function AccountBox(const Me: TMember; const Language: string): string;
var
  Lang: string;
begin
  Lang := Language;
  if Lang = '' then
    Lang := RequestLanguage;
  if Me.Id > 0 then
  begin
    Result := Format('<a class="me" href="/u/%0:s">%0:s</a> <a href="#" class="signout">%1:s</a>', [E(Me.Name), E(SiteWord(Lang, 'Sign out'))]);
    // the profile is where another link is asked for, or the address corrected
    if not Me.Verified then
      Result := Format('<a class="unconfirmed" href="/u/%s">%s</a> ', [E(Me.Name), E(SiteWord(Lang, 'Confirm your email'))]) + Result;
  end
  else
    Result := '<a href="/signin">' + E(SiteWord(Lang, 'Sign in')) + '</a> <a class="button" href="/signin">' + E(SiteWord(Lang, 'Join')) + '</a>';
  if CanOpenAdmin(Me) then
    Result := AdminLink(Me) + ' ' + Result;
end;

function AdminLink(const Me: TMember): string;
begin
  Result := '';
  if CanOpenAdmin(Me) then
    Result := '<a href="/admin">' + E(Say('Admin')) + '</a>';
end;

function LanguageOfRequest(ARequest: TRequest): string;
begin
  Result := CookieLanguage(ARequest);
end;

{ Every request says first what language it is answered in. }
type
  TLanguageStep = class
    procedure Note(ARequest: TRequest; AResponse: TResponse; var aContinue: boolean);
  end;

var
  LanguageStep: TLanguageStep;

procedure TLanguageStep.Note(ARequest: TRequest; AResponse: TResponse; var aContinue: boolean);
begin
  SetRequestLanguage(LanguageOfRequest(ARequest));
  RequestNow := ARequest;
  RequestAddress := ARequest.URI;
  if (ARequest.QueryString <> '') and (Pos('?', RequestAddress) = 0) then
    RequestAddress := RequestAddress + '?' + ARequest.QueryString;
end;

{ Only an address on this site, whole, is a place to come back to. }
function SafeReturn(const Address: string): string;
begin
  Result := LocalReturn(Address);
  if Result = '' then
    Result := '/';
end;

{ GET /language?language=de&return=/somewhere }
procedure ChooseSiteLanguage(ARequest: TRequest; AResponse: TResponse);
var
  Secured: boolean;
begin
  Secured := Setting('https', '0') = '1';
  with AResponse.Cookies.Add do
  begin
    Name := 'site_language';
    Value := CanonicalLanguage(ARequest.QueryFields.Values['language']);
    Path := '/';
    Expires := NowUTC + 365;
    HttpOnly := True;
    SameSite := ssLax;
    Secure := Secured;
  end;
  // a language chosen means reading in it, here and on the wiki
  if ARequest.CookieFields.Values['wiki_language'] <> '' then
    with AResponse.Cookies.Add do
    begin
      Name := 'wiki_language';
      Value := '';
      Path := '/';
      Expires := NowUTC - 1;
      HttpOnly := True;
      SameSite := ssLax;
      Secure := Secured;
    end;
  SeeOther(AResponse, SafeReturn(ARequest.QueryFields.Values['return']));
end;

{ GET /words.js?l=de: one language's words for the browser.  The address
  carries the program's start time, so a new version is a new address. }
procedure ShowWords(ARequest: TRequest; AResponse: TResponse);
begin
  AResponse.ContentType := 'text/javascript; charset=utf-8';
  AResponse.SetCustomHeader('Cache-Control', 'public, max-age=31536000, immutable');
  AResponse.Content := 'window.WORDS=' + WordsJson(CanonicalLanguage(ARequest.QueryFields.Values['l'])) + ';window.DATE_FORMAT="' +
    StringToJSONString(Setting('date_format', 'm-d-yyyy')) + '";';
  AResponse.SendContent;
end;

procedure RegisterPageValue(const Name: string; Make: THomePart);
begin
  SetLength(PageValues, Length(PageValues) + 1);
  PageValues[High(PageValues)].Name := Name;
  PageValues[High(PageValues)].Make := Make;
end;

procedure RegisterHomePart(const Name: string; Make: THomePart);
begin
  SetLength(Parts, Length(Parts) + 1);
  Parts[High(Parts)].Name := Name;
  Parts[High(Parts)].Make := Make;
end;

function HomeCard(const Title, Address, Rows, Empty: string): string;
begin
  Result := '<section class="home-card"><h2><a href="' + E(Address) + '">' + E(Title) + '</a></h2>';
  if Rows = '' then
    Result := Result + '<p class="hint">' + E(Empty) + '</p></section>'
  else
    Result := Result + '<ul>' + Rows + '</ul></section>';
end;

function HomeRow(const Address, Caption, Note: string): string;
begin
  Result := '<li><a href="' + E(Address) + '">' + E(Caption) + '</a>';
  if Note <> '' then
    Result := Result + ' <small>' + Note + '</small>';
  Result := Result + '</li>';
end;

function CachedHomePart(const Name: string): string;
var
  I, Language: integer;
begin
  Result := '';
  Language := LanguageIndex(RequestLanguage) + 1;
  EnterCriticalSection(HomeLock);
  try
    for I := 0 to High(Parts) do
      if Parts[I].Name = Name then
      begin
        if Now - Parts[I].HomeMade[Language] > 30 / SecsPerDay then
        begin
          Parts[I].Html[Language] := Parts[I].Make();
          Parts[I].HomeMade[Language] := Now;
        end;
        Exit(Parts[I].Html[Language]);
      end;
  finally
    LeaveCriticalSection(HomeLock);
  end;
end;

procedure ShowHome(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Who, Start: string;
  Values: array of string;
  I: integer;
begin
  CheckConnection;
  Me := CurrentMember(ARequest);
  Start := '';
  if Assigned(HomeStart) then
    Start := HomeStart(Me);
  // a site that is one thing opens on it
  if Start = '' then
    Start := OnlyPartHome;
  if Start <> '' then
  begin
    AResponse.SendRedirect(Start);
    Exit;
  end;
  if Me.Id > 0 then
    Who := 'member'
  else
    Who := 'guest';
  Values := ['title', E(Setting('name', 'Exedra')), 'account', AccountBox(Me), 'who', Who];
  for I := 0 to High(Parts) do
    Values := Concat(Values, [Parts[I].Name, CachedHomePart(Parts[I].Name)]);
  SendPage(AResponse, FillTemplate('home', Values));
end;

{ GET /manifest.webmanifest }
procedure ShowManifest(ARequest: TRequest; AResponse: TResponse);
const
  // An array, not a set: a set constant stops at 255, so 512 would be 0.
  Sizes: array[0..1] of integer = (192, 512);
var
  Size: integer;
  Icons: TJSONArray;
  Manifest: TJSONObject;
begin
  CheckConnection;
  Icons := TJSONArray.Create;
  for Size in Sizes do
    Icons.Add(TJSONObject.Create(['src', WithBase(IconUrl(Size)), 'sizes', Format('%dx%d', [Size, Size]), 'type', 'image/png', 'purpose', 'any']));
  Manifest := TJSONObject.Create(['name', Setting('name', 'Exedra'), 'short_name', Setting('name', 'Exedra'), 'description', Setting('tagline', ''),
    'start_url', WithBase('/'), 'scope', WithBase('/'), 'display', 'standalone', 'background_color', '#0f1720', 'theme_color', '#0f1720', 'icons', Icons]);
  try
    AResponse.ContentType := 'application/manifest+json';
    AResponse.Content := Manifest.AsJSON;
  finally
    Manifest.Free;
  end;
  AResponse.SendContent;
end;

{ GET /icon-192.png  the icon wherever it is (for notifications) }
procedure ShowIcon(ARequest: TRequest; AResponse: TResponse);
begin
  AResponse.SendRedirect(IconUrl(192));
end;

{ GET /sw.js  from the site's root, so the worker may look after all of it }
procedure ShowWorker(ARequest: TRequest; AResponse: TResponse);
begin
  AResponse.ContentType := 'text/javascript';
  AResponse.SetCustomHeader('Cache-Control', 'no-cache');
  AResponse.ContentStream := TFileStream.Create(FilesRoot + 'static' + PathDelim + 'sw.js', fmOpenRead or fmShareDenyNone);
  AResponse.FreeContentStream := True;
  AResponse.SendContent;
end;

procedure ShowAbout(ARequest: TRequest; AResponse: TResponse);
begin
  CheckConnection;
  if Templates.IndexOfName('about') < 0 then
    SendText(AResponse, 404, Say('There is no about page here.'))
  else
    SendPage(AResponse, FillTemplate('about', ['title', E(Say('About'))]));
end;

{ Source drawn at W by H, smoothly. }
function Scaled(Source: TFPCustomImage; W, H: integer): TFPMemoryImage;
var
  Canvas: TFPImageCanvas;
begin
  Result := TFPMemoryImage.Create(W, H);
  Result.UsePalette := False;
  Canvas := TFPImageCanvas.Create(Result);
  try
    Canvas.Interpolation := TMitchellInterpolation.Create;
    Canvas.StretchDraw(0, 0, W, H, Source);
  finally
    Canvas.Interpolation.Free;
    Canvas.Free;
  end;
end;

procedure SavePng(Image: TFPCustomImage; const FileName: string);
var
  Writer: TFPWriterPNG;
begin
  Writer := TFPWriterPNG.Create;
  try
    Writer.UseAlpha := True;
    Image.SaveToFile(FileName, Writer);
  finally
    Writer.Free;
  end;
end;

{ POST /api/admin/look  what (icon or logo), and a picture, or remove=1.
  The icon is made in every size browsers and phones ask for; the logo is
  kept 96 pixels high, for the header. }
procedure SaveLook(ARequest: TRequest; AResponse: TResponse);
const
  IconSizes: array[0..3] of integer = (32, 180, 192, 512);
var
  Me: TMember;
  What, Kind: string;
  Picture, Small: TFPMemoryImage;
  Reader: TFPCustomImageReader;
  Size, W: integer;
begin
  if not NeedPermission(ARequest, AResponse, 'manage-settings', Me) then
    Exit;
  What := ARequest.ContentFields.Values['what'];
  if (What <> 'icon') and (What <> 'logo') then
  begin
    SendText(AResponse, 400, Say('Upload an icon or a logo.'));
    Exit;
  end;
  if ARequest.ContentFields.Values['remove'] = '1' then
  begin
    if What = 'logo' then
      DeleteFile(LookDir + 'logo.png')
    else
      for Size in IconSizes do
        DeleteFile(LookDir + Format('icon-%d.png', [Size]));
    SendText(AResponse, 200, Say('Removed.'));
    Exit;
  end;
  if ARequest.Files.Count <> 1 then
  begin
    SendText(AResponse, 400, Say('Choose a picture first.'));
    Exit;
  end;
  Kind := ImageType(ARequest.Files[0].LocalFileName);
  if Kind = 'image/png' then
    Reader := TFPReaderPNG.Create
  else if Kind = 'image/jpeg' then
    Reader := TFPReaderJPEG.Create
  else
  begin
    SendText(AResponse, 400, Say('That is not a PNG or JPEG picture.'));
    Exit;
  end;
  Picture := TFPMemoryImage.Create(0, 0);
  try
    try
      Picture.LoadFromFile(ARequest.Files[0].LocalFileName, Reader);
    except
      SendText(AResponse, 400, Say('That picture could not be read.'));
      Exit;
    end;
    if What = 'icon' then
    begin
      if (Picture.Width <> Picture.Height) or (Picture.Width < 192) then
      begin
        SendText(AResponse, 400, Say('The icon has to be square, 512 by 512 pixels or more is best.'));
        Exit;
      end;
      for Size in IconSizes do
      begin
        Small := Scaled(Picture, Size, Size);
        try
          SavePng(Small, LookDir + Format('icon-%d.png', [Size]));
        finally
          Small.Free;
        end;
      end;
    end
    else
    begin
      W := Picture.Width * 96 div Picture.Height;
      if W > 800 then
        W := 800;
      Small := Scaled(Picture, W, 96);
      try
        SavePng(Small, LookDir + 'logo.png');
      finally
        Small.Free;
      end;
    end;
  finally
    Picture.Free;
    Reader.Free;
  end;
  Log(Me.Name + ' uploaded a new ' + What);
  SendText(AResponse, 200, Say('Saved.') + ' ' + Say('Reload the page to see it everywhere.'));
end;

procedure ShowSignIn(ARequest: TRequest; AResponse: TResponse);
var
  Buttons, Failed, Name, Note: string;
begin
  CheckConnection;
  Note := '';
  if Assigned(SignInNote) then
    Note := SignInNote();
  Buttons := '';
  for Name in Providers do
    Buttons := Buttons + Format('<a class="button sso" href="/signin-with/%0:s"><span class="ssologo %0:s"></span>%1:s</a>', [Name, E(ProviderTitle(Name))]);
  if Buttons <> '' then
    Buttons := '<p class="or">' + E(Say('or sign in with')) + '</p><div class="ssorow">' + Buttons + '</div>';
  case ARequest.QueryFields.Values['failed'] of
    '': Failed := '';
    'closed': Failed := '<p class="notice">' + E(Say('New accounts are closed here for now.')) + '</p>';
    else
      Failed := '<p class="notice">' + E(Say('That sign-in did not go through.') + ' ' + Say('Try again.')) + '</p>';
  end;
  SendPage(AResponse, FillTemplate('signin', ['title', E(Say('Sign in or join')), 'sso', Buttons, 'failed', Failed, 'note', Note]));
end;

{ GET /password/:token  a new password, from a link an admin made or /api/forgot mailed }
procedure ShowPasswordLink(ARequest: TRequest; AResponse: TResponse);
var
  Name: string;
begin
  CheckConnection;
  if not SiteGuard.TokenTry(ARequest, AResponse) then
    Exit;
  Name := PasswordLinkName(ARequest.RouteParams['token']);
  if Name = '' then
  begin
    Strike(ClientIp(ARequest), 'password');
    SendText(AResponse, 410, Say('That link has run out or was used already.') + ' ' + Say('Ask for a new one.'));
  end
  else
    SendPage(AResponse, FillTemplate('password', ['title', E(Say('Set your password')), 'name', E(Name), 'token', E(ARequest.RouteParams['token']),
      'password_for', Format(E(Say('For %s.')), ['<b>' + E(Name) + '</b>'])]));
end;

procedure SendApp(ARequest: TRequest; AResponse: TResponse; const View, Target, Title, Plain: string; Thread: integer);
var
  Me: TMember;
  Sso: string;
begin
  Me := CurrentMember(ARequest);
  // The sign-in providers this site has, for the join box under a room.
  Sso := ''.Join(',', Providers);
  SendPage(AResponse, FillTemplate('app', ['title', E(Title), 'view', View, 'target', E(Target), 'thread', IntToStr(Thread), 'me', E(Me.Name), 'plain', Plain, 'sso', Sso]));
end;

{ The name as written first, so a + in it stays one, then with its %20 and
  the like decoded (names may hold spaces). }
function NameInPath(const Raw: string): string;
begin
  Result := VarToStr(Value('SELECT name FROM users WHERE name = :n', [Raw]));
  if Result = '' then
    Result := VarToStr(Value('SELECT name FROM users WHERE name = :n', [HTTPDecode(Raw)]));
end;

procedure ShowUserPage(ARequest: TRequest; AResponse: TResponse);
var
  Name, Former: string;
begin
  CheckConnection;
  Name := NameInPath(ARequest.RouteParams['name']);
  // a name the member had before leads to the one they have now
  Former := '';
  if Name = '' then
    Former := NameNow(HTTPDecode(ARequest.RouteParams['name']));
  if Former <> '' then
    AResponse.SendRedirect('/u/' + HTTPEncode(Former))
  else if Name = '' then
    SendText(AResponse, 404, Say('No member by that name.'))
  else
    SendApp(ARequest, AResponse, 'profile', Name, Name, '<h1>' + E(Name) + '</h1>' + RenderPlain(VarToStr(Value('SELECT bio FROM users WHERE name = :n', [Name]))), 0);
end;

{ GET /robots.txt  everything, or nothing while the robots setting is off. }
function CanonicalUrl(ARequest: TRequest): string;
var
  Path: string;
begin
  Path := ARequest.URI;
  if Pos('?', Path) > 0 then
    Path := Copy(Path, 1, Pos('?', Path) - 1);
  if Path = '' then
    Path := '/';
  if ARequest.Host.StartsWith('127.0.0.1') or ARequest.Host.StartsWith('localhost') then
    Result := 'http://' + ARequest.Host + BasePath + Path
  else
    Result := 'https://' + ARequest.Host + BasePath + Path;
end;

procedure ShowRobots(ARequest: TRequest; AResponse: TResponse);
var
  Lines: string;
begin
  CheckConnection;
  if Setting('robots', '1') = '1' then
  begin
    Lines := 'User-agent: *'#10'Disallow: /api/'#10'Disallow: /f/'#10;
    if Assigned(RobotsPart) then
      Lines := Lines + RobotsPart(ARequest);
    SendText(AResponse, 200, Lines);
  end
  else
    SendText(AResponse, 200, 'User-agent: *'#10'Disallow: /'#10);
end;

procedure ShowAdminPage(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
begin
  if not NeedAdmin(ARequest, AResponse, Me) then
    Exit;
  SendApp(ARequest, AResponse, 'admin', '', Say('Admin'), '', 0);
end;

initialization
  RegisterAdminRoute('/api/admin/look', 'manage-settings');
  InitCriticalSection(HomeLock);
  Started := FormatDateTime('yyyymmddhhnnss', Now);
  RegisterSetting('date_format', 'How dates are shown (m-d-yyyy is 1-30-2020; reader follows each reader''s language)', 'm-d-yyyy',
    'choice:' + DATE_FORMATS, 'Site');
  RegisterSetting('side_links', 'More links under the site''s name, after the modules: Name=address, Name=address (an address starts with / or https://)', '', 'longtext', 'Site');
  RegisterSetting('powered_by', 'Show "Powered by Exedra" with a link to the project at the foot of the pages', '1', 'yesno', 'Site');
  // A small server may have no /etc/mime.types.
  MimeTypes.AddType('text/css', 'css');
  MimeTypes.AddType('text/javascript', 'js');
  MimeTypes.AddType('image/png', 'png');
  MimeTypes.AddType('image/svg+xml', 'svg');
  MimeTypes.AddType('image/webp', 'webp');
  MimeTypes.AddType('image/jpeg', 'jpg');
  MimeTypes.AddType('image/x-icon', 'ico');
  MimeTypes.AddType('text/plain; charset=utf-8', 'txt');
  LanguageStep := TLanguageStep.Create;
  HTTPRouter.RegisterInterceptor('language', @LanguageStep.Note);
  HTTPRouter.RegisterRoute('/language', rmGet, @ChooseSiteLanguage);
  HTTPRouter.RegisterRoute('/words.js', rmGet, @ShowWords);
  HTTPRouter.RegisterRoute('/', rmGet, @ShowHome);
  HTTPRouter.RegisterRoute('/about', rmGet, @ShowAbout);
  HTTPRouter.RegisterRoute('/api/admin/look', rmPost, @SaveLook);
  HTTPRouter.RegisterRoute('/manifest.webmanifest', rmGet, @ShowManifest);
  HTTPRouter.RegisterRoute('/sw.js', rmGet, @ShowWorker);
  HTTPRouter.RegisterRoute('/icon-192.png', rmGet, @ShowIcon);
  HTTPRouter.RegisterRoute('/signin', rmGet, @ShowSignIn);
  HTTPRouter.RegisterRoute('/password/:token', rmGet, @ShowPasswordLink);
  HTTPRouter.RegisterRoute('/u/:name', rmGet, @ShowUserPage);
  HTTPRouter.RegisterRoute('/admin', rmGet, @ShowAdminPage);
  HTTPRouter.RegisterRoute('/robots.txt', rmGet, @ShowRobots);
end.
