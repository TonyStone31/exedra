unit WikiChat;

{ Wiki/chat integration: /wiki command, #channel links and per-page benches.
  All languages share one bench, preserved across renames. POST /wiki-bench
  opens it for page=Slug. }

{$mode objfpc}{$H+}

interface

implementation

uses
  SysUtils, httpdefs, httproute, SiteDb, SiteUsers, SiteParts, SiteGuard, WebPages, ChatRooms, ChatMessages, ChatBenches, SiteWords, Wiki;

function WikiCommand(const Me: TMember; const Room: TRoom; Parent: integer; const Args: string): TCommandResult;
var
  Slug, Url: string;
begin
  Slug := SlugOf(Args);
  if Slug = '' then
    Slug := MAIN_PAGE;
  Url := ExcludeTrailingPathDelimiter(Setting('url', '')) + PageUrl(Slug);
  if PageExists(Slug) then
    Result := CommandResult('', Url)
  else
    Result := CommandResult('', Format(SiteWord(RequestLanguage, 'There is no page by this name yet.') + ' ' + SiteWord(RequestLanguage, 'Write it: %s'), [Url + '?edit=1']));
end;

{ A page's key for its bench: its name without a language. }
function BenchKey(const Key: string): string;
var
  Language: integer;
begin
  Result := BaseSlug(SlugOf(Key), Language);
end;

function BenchPage(const Key: string; out Title, Url: string): boolean;
begin
  Result := (Key <> '') and PageExists(Key);
  Title := Say('Wiki') + ': ' + StringReplace(Key, '_', ' ', [rfReplaceAll]);
  Url := PageUrl(Key);
end;

{ The part under a wiki page about its bench: what is being said there and
  a way in, or a button to open one. }
function BenchPart(ARequest: TRequest; const Slug, Title: string): string;
var
  Me: TMember;
  Room: TRoom;
begin
  Result := '';
  if not PartOn('chat') then
    Exit;
  Me := CurrentMember(ARequest);
  Room := PageBenchRoom('wiki', Slug);
  Result := '<section class="page-bench"><h2>' + E(Say('Talk about this page')) + '</h2>';
  if (Room.Id > 0) and not OpenToAll(Room) then
    Result := Result + '<p>' + E(Say('The bench for this page is closed.')) + '</p>'
  else if Room.Id > 0 then
    Result := Result + '<div class="bench-glimpse" data-live-room="' + E(Room.Slug) + '"></div><p><a class="button" href="/p/' + E(Room.Slug) +
      '">' + E(Say('Join the talk at its bench')) + '</a></p>'
  else if Me.Id = 0 then
    Result := Result + '<p>' + E(Say('Nobody has opened a bench for this page yet.')) + ' <a href="/signin?return=' + HTTPEncode(PageUrl(Slug)) +
      '">' + E(Say('Sign in to open one.')) + '</a></p>'
  else if MayOpenBench(Me) then
    Result := Result + '<form method="post" action="/wiki-bench"><input type="hidden" name="page" value="' + E(Slug) + '"><p>' +
      E(Say('Nobody has opened a bench for this page yet.')) + ' <button type="submit">' + E(Say('Open a bench for this page')) + '</button></p></form>'
  else
    Result := Result + '<p>' + E(Say('This account cannot open a bench.')) + '</p>';
  Result := Result + '</section>';
end;

{ POST /wiki-bench  page=Slug }
procedure StartBench(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Room: TRoom;
  Problem: string;
  Code: integer;
begin
  CheckConnection;
  if FromAnotherSite(ARequest) then
  begin
    SendText(AResponse, 403, Say('Send this from a page of this site.'));
    Exit;
  end;
  if not NeedMember(ARequest, AResponse, Me) then
    Exit;
  Room := OpenPageBench(Me, 'wiki', ARequest.ContentFields.Values['page'], Code, Problem);
  if Room.Id = 0 then
  begin
    SendText(AResponse, Code, Problem);
    Exit;
  end;
  // back to the page, where the corner chat opens on the new bench
  AResponse.SetCustomHeader('Cache-Control', 'no-store');
  SeeOther(AResponse, PageUrl(SlugOf(ARequest.ContentFields.Values['page'])) + '?bench=open');
end;

var
  MovedBefore: TWikiPageMoved = nil;

{ A wiki page given a new name keeps its bench.  The bench belongs to the
  page in all its languages, so only the page without a language moves it;
  a bench the new name already has stays. }
procedure BenchFollowsPage(const OldSlug, NewSlug: string);
var
  OldLanguage, NewLanguage: integer;
  OldBase, NewBase: string;
begin
  OldBase := BaseSlug(OldSlug, OldLanguage);
  NewBase := BaseSlug(NewSlug, NewLanguage);
  if (OldLanguage < 0) and (NewLanguage < 0) and (OldBase <> NewBase) and (IntValue('SELECT COUNT(*) FROM page_benches WHERE kind = ''wiki'' AND pagekey = :n',
    [NewBase]) = 0) then
    Exec('UPDATE page_benches SET pagekey = :n WHERE kind = ''wiki'' AND pagekey = :o', [NewBase, OldBase]);
  if Assigned(MovedBefore) then
    MovedBefore(OldSlug, NewSlug);
end;

initialization
  WikiRoomThere := @RoomExists;
  RegisterPageKind('wiki', @BenchPage, @BenchKey);
  WikiLive := @LiveStrip;
  WikiPagePart := @BenchPart;
  MovedBefore := WikiPageMoved;
  WikiPageMoved := @BenchFollowsPage;
  RegisterPartPaths('chat', ['/wiki-bench']);
  LimitRoute('pagebench', '/wiki-bench', 'POST');
  HTTPRouter.RegisterRoute('/wiki-bench', rmPost, @StartBench);
  RegisterCommand('wiki', '/wiki [Page Name] - find a wiki page, or write it', @WikiCommand);
end.
