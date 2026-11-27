unit Catalog;

{ Catalog entries, search, pages, ratings and Interesting. A site's units
  register fields, choices, filters and page parts here. CatalogAdmin,
  CatalogImport and CatalogReports handle administration, bulk JSON and
  reports; registrations are at the foot. See docs/CODE-MAP.md and
  docs/API.md. }

{$mode objfpc}{$H+}

interface

uses SysUtils, fpjson, httpdefs, SiteUsers;

type
  { Something another unit adds under a catalog entry's page. }
  TCatalogEntryPart = function(ARequest: TRequest; Id: integer; const Me: TMember): string;

  TCatalogItemPart = function(Item: TJSONObject; const Me: TMember): string;
  TCatalogFrame = function(ARequest: TRequest; const Me: TMember; const Title, Main: string): string;
  TCatalogText = function(const Value: string): string;
  TCatalogCountPart = procedure(Answer: TJSONObject);
  TCatalogRoute = procedure(ARequest: TRequest; AResponse: TResponse);
  TCatalogFilterSQL = function(const Value, Param: string): string;
  TCatalogDiscoverPart = function(ARequest: TRequest; Id: integer): string;
  TCatalogDiscoverChoice = procedure(ARequest: TRequest; out Where, Carry: string);
  TCatalogNextCarry = function(ARequest: TRequest): string;
  TCatalogNarrowing = function(const TypeText, Works: string): string;
  TCatalogFieldKind = (cfText, cfNumber, cfDate, cfBoolean, cfTime);
  TCatalogDelete = procedure(EntryId: integer);
  TCatalogMoved = procedure(EntryId: integer);

{ Registrations are made during initialization, before requests start. }
procedure RegisterCatalogEntryPart(const Name: string; Make: TCatalogEntryPart);
{ The combined bottom parts, or nil when none are registered. }
function CatalogEntryPart: TCatalogEntryPart;
{ Fixed places: card-works, card-mark, after-actions, works-fact,
  version-facts, count-facts, after-facts, talk, contact, admin-actions and join. }
procedure RegisterCatalogItemPart(const Place, Name: string; Make: TCatalogItemPart);
procedure RegisterCatalogFrame(const Name: string; Make: TCatalogFrame);
procedure RegisterCatalogText(const Name: string; Make: TCatalogText);
procedure RegisterCatalogCountPart(const Name: string; Make: TCatalogCountPart);
procedure RegisterCatalogRoom(const Name: string; Open: TCatalogRoute);
procedure RegisterCatalogChoices(const Name: string; const Choices: array of string);
{ The choices registered for a name ('kind', 'works_with', 'forge', 'source'); none: an empty list. }
function CatalogChoices(const Name: string): TStringArray;
procedure RegisterCatalogFilter(const Name: string; SQL: TCatalogFilterSQL);
{ A tab over the list (/catalog?type=Name) that shows the entries of these
  kinds.  Its words come from CatalogCaption(Name).  With none registered
  the list has no tabs. }
procedure RegisterCatalogType(const Name: string; const Kinds: array of string);
{ Field positions preserve the stored import and API order. }
procedure RegisterCatalogField(Position: integer; const Name: string; Size: integer; Kind: TCatalogFieldKind);
{ The field at a position, 0 to 35: Name is '' where none is registered. }
procedure CatalogFieldAt(Position: integer; out Name: string; out Size: integer; out Kind: TCatalogFieldKind);
procedure RegisterCatalogDiscovery(const Name: string; Narrow: TCatalogDiscoverPart; Choice: TCatalogDiscoverChoice; Next: TCatalogNextCarry; Narrowing: TCatalogNarrowing);
{ An import leaves Column as it is wherever Condition (SQL on the entry's
  row) holds, as for what an admin or a maintainer set by hand. }
procedure RegisterCatalogKept(const Column, Condition: string);
{ The conditions under which an import keeps Column, joined by OR; '' when it never does. }
function CatalogKeptWhen(const Column: string): string;
{ A unit that keeps rows for an entry removes them when the entry is deleted. }
procedure RegisterCatalogDelete(const Name: string; Remove: TCatalogDelete);
{ Runs the registered deletes; the caller holds the delete's transaction. }
procedure CatalogEntryDeleted(EntryId: integer);
{ A unit that keeps what it read from an entry's code host hears when an
  import gives the entry another address or host kind. }
procedure RegisterCatalogMoved(const Name: string; Moved: TCatalogMoved);
{ Whether any unit hears of moves, and telling them of one; the caller
  holds the import's transaction. }
function CatalogMovesHeard: boolean;
procedure CatalogEntryMoved(EntryId: integer);
{ A unit hears when an entry is hidden or shown again. }
procedure RegisterCatalogHidden(const Name: string; Hidden: TCatalogMoved);
{ Runs those; the caller has changed hidden and holds its transaction. }
procedure CatalogEntryHidden(EntryId: integer);
{ Entries were changed by hand: the filters the list offers are read again
  for the next page, not minutes later. }
procedure CatalogEntriesChanged;
{ False for text whose brackets nest deeper than Limit outside strings.
  The JSON parser goes one call deeper for each level, and a thread's
  stack is small: ask this before parsing text from outside. }
function CatalogJSONDepthOK(const Text: string; Limit: integer = 64): boolean;
{ Whether the bytes are whole UTF-8 characters, as a text column needs. }
function CatalogUTF8OK(const Text: string): boolean;
function CatalogCaption(const Text: string): string;
function CatalogOptions(const Choices: array of string; const Selected: string; AnyChoice: boolean = True): string;
function StarIcon: string;
function Fact(const Caption, Text: string): string;
function ProjectAddress(Item: TJSONObject): string;
function ReadEntry(Id: integer; MemberId: integer = 0; Hidden: boolean = False): TJSONObject;

{ An entry's state as SQL: archived, unknown (no push date), active (a push
  in the last two years) or quiet. }
function CatalogStatusSQL: string;
function CatalogEntryKey(const Text: string): string;
function CatalogURL(const Text: string): boolean;
function CatalogCategories(const Text: string): string;
function CatalogLabelKey(const Text: string): string;
function CatalogRoomText(const Text: string; MaxBytes: integer): string;
{ Every registered text of the name, one after the other.  The page of
  directions takes whole sections this way under 'how-more': each is HTML
  its unit built and escaped, and Value says who reads, 'guest', 'member'
  (signed in and may act) or 'other'. }
function CatalogTexts(const Name: string; const Value: string = ''): string;
{ A page in the catalog's frame. }
procedure CatalogPage(ARequest: TRequest; AResponse: TResponse; const Me: TMember; const Title, Main: string);
function CatalogCard(Item: TJSONObject; const Filters: string = ''): string;
{ One decimal with a point, whatever the locale: 4.5.  '' with no ratings. }
function CatalogAverage(Count, Sum: integer): string;
{ "4.5 from 12 members" in the request's language.  '' with no ratings. }
function RatingSummary(Count, Sum: integer): string;
{ Five star buttons that post to the entry; Mine is the member's own rating. }
function RateForm(Id, Mine: integer): string;
{ The "this looks interesting" button with its count, pressed when Mine. }
function InterestForm(Id, Count: integer; Mine: boolean): string;
{ Who presses the interesting button: a member by number, anyone else by a
  salted hash of their address, never the address itself. }
function InterestWho(ARequest: TRequest; const Me: TMember): string;
{ A picture address from one of the code hosts a catalog picture may come from. }
function CatalogImageAllowed(const Url: string): boolean;
{ The address of an entry's own picture, a file the admin sent, from its
  token; '' for none. }
function CatalogPictureUrl(const Token: string): string;
{ A README as HTML: raw HTML escaped, pictures from those hosts only. }
function CatalogReadmeHtml(const Body: string): string;
{ The words of a search, as typed: letters, digits and a few joining marks. }
function CatalogSearchTerms(const Q: string): TStringArray;
{ The words as a boolean full-text query, each a prefix: '+lazar* +grid*'. }
function CatalogBooleanQuery(const Terms: TStringArray): string;
{ The small picture for an entry: its own logo when known, otherwise the
  owner's picture on its code host, otherwise ''. }
function CatalogIconUrl(const Icon, Forge, Owner: string): string;
{ The icon as HTML, a letter underneath for when no picture comes. }
function CatalogIcon(const Icon, Forge, Owner, TitleText: string): string;

implementation

uses
  Classes, StrUtils, Variants, URIParser, sqldb, SiteStatic,
  httproute, SiteDb, SiteRoles,
  SiteAdmin, SiteGuard, SiteGuardRules, SiteMarkup, SiteVisitors, WebPages, SiteWords, SiteSql, SiteParts, SiteSearch, SiteIndex,
  // the catalog's other units, so the program names Catalog alone
  CatalogReports, CatalogImport, CatalogAdmin;

const
  ImageHosts: array[0..8] of string = ('raw.githubusercontent.com', 'user-images.githubusercontent.com', 'avatars.githubusercontent.com',
    'github.com', 'gitlab.com', 'codeberg.org', 'bitbucket.org', 'a.fsdn.com', 'sourceforge.net');
  PageSize = 60;

var
  FieldNames: array[0..35] of string;
  FieldSizes: array[0..35] of integer;
  FieldKinds: array[0..35] of TCatalogFieldKind;
  EntryParts: array of record
    Name: string;
    Make: TCatalogEntryPart;
    end;
  ItemParts: array of record
    Place, Name: string;
    Make: TCatalogItemPart;
    end;
  Frames: array of record
    Name: string;
    Make: TCatalogFrame;
    end;
  Texts: array of record
    Name: string;
    Make: TCatalogText;
    end;
  CountParts: array of record
    Name: string;
    Make: TCatalogCountPart;
    end;
  RoomOpeners: array of record
    Name: string;
    Open: TCatalogRoute;
    end;
  ChoiceLists: array of record
    Name: string;
    Choices: TStringArray;
    end;
  Filters: array of record
    Name: string;
    SQL: TCatalogFilterSQL;
    end;
  Types: array of record
    Name, KindList: string;   // KindList as SQL: 'package', 'library'
    end;
  Discoveries: array of record
    Name: string;
    Narrow: TCatalogDiscoverPart;
    Choice: TCatalogDiscoverChoice;
    Next: TCatalogNextCarry;
    Narrowing: TCatalogNarrowing;
    end;
  Deletes: array of record
    Name: string;
    Remove: TCatalogDelete;
    end;
  Moves, Hides: array of record
    Name: string;
    Moved: TCatalogMoved;
    end;
  Kept: array of record
    Column, Condition: string;
    end;

procedure RegisterCatalogKept(const Column, Condition: string);
begin
  SetLength(Kept, Length(Kept) + 1);
  Kept[High(Kept)].Column := Column;
  Kept[High(Kept)].Condition := Condition;
end;

function CatalogKeptWhen(const Column: string): string;
var
  I: integer;
begin
  Result := '';
  for I := 0 to High(Kept) do
    if SameText(Kept[I].Column, Column) then
    begin
      if Result <> '' then
        Result := Result + ' OR ';
      Result := Result + '(' + Kept[I].Condition + ')';
    end;
end;

procedure RegisterCatalogDelete(const Name: string; Remove: TCatalogDelete);
begin
  SetLength(Deletes, Length(Deletes) + 1);
  Deletes[High(Deletes)].Name := Name;
  Deletes[High(Deletes)].Remove := Remove;
end;

procedure CatalogEntryDeleted(EntryId: integer);
var
  I: integer;
begin
  for I := 0 to High(Deletes) do
    Deletes[I].Remove(EntryId);
end;

procedure RegisterCatalogMoved(const Name: string; Moved: TCatalogMoved);
begin
  SetLength(Moves, Length(Moves) + 1);
  Moves[High(Moves)].Name := Name;
  Moves[High(Moves)].Moved := Moved;
end;

function CatalogMovesHeard: boolean;
begin
  Result := Length(Moves) > 0;
end;

procedure CatalogEntryMoved(EntryId: integer);
var
  I: integer;
begin
  for I := 0 to High(Moves) do
    Moves[I].Moved(EntryId);
end;

procedure RegisterCatalogHidden(const Name: string; Hidden: TCatalogMoved);
begin
  SetLength(Hides, Length(Hides) + 1);
  Hides[High(Hides)].Name := Name;
  Hides[High(Hides)].Moved := Hidden;
end;

procedure CatalogEntryHidden(EntryId: integer);
var
  I: integer;
begin
  for I := 0 to High(Hides) do
    Hides[I].Moved(EntryId);
end;

function CatalogJSONDepthOK(const Text: string; Limit: integer): boolean;
var
  I, Depth: integer;
  Quoted: boolean;
begin
  Result := False;
  Depth := 0;
  Quoted := False;
  I := 1;
  while I <= Length(Text) do
  begin
    if Quoted then
    begin
      if Text[I] = '\' then
        Inc(I)
      else if Text[I] = '"' then
        Quoted := False;
    end
    else if Text[I] = '"' then
      Quoted := True
    else if Text[I] in ['[', '{'] then
    begin
      Inc(Depth);
      if Depth > Limit then
        Exit;
    end
    else if (Text[I] in [']', '}']) and (Depth > 0) then
      Dec(Depth);
    Inc(I);
  end;
  Result := True;
end;

function CatalogUTF8OK(const Text: string): boolean;
begin
  // a broken sequence does not survive the trip there and back
  Result := UTF8Encode(UTF8Decode(Text)) = Text;
end;

procedure RegisterCatalogEntryPart(const Name: string; Make: TCatalogEntryPart);
begin
  SetLength(EntryParts, Length(EntryParts) + 1);
  EntryParts[High(EntryParts)].Name := Name;
  EntryParts[High(EntryParts)].Make := Make;
end;

function EntryBottom(ARequest: TRequest; Id: integer; const Me: TMember): string;
var
  I: integer;
begin
  Result := '';
  for I := 0 to High(EntryParts) do
    Result := Result + EntryParts[I].Make(ARequest, Id, Me);
end;

function CatalogEntryPart: TCatalogEntryPart;
begin
  Result := nil;
  if Length(EntryParts) > 0 then
    Result := @EntryBottom;
end;

procedure RegisterCatalogItemPart(const Place, Name: string; Make: TCatalogItemPart);
begin
  SetLength(ItemParts, Length(ItemParts) + 1);
  ItemParts[High(ItemParts)].Place := Place;
  ItemParts[High(ItemParts)].Name := Name;
  ItemParts[High(ItemParts)].Make := Make;
end;

function CatalogItemParts(const Place: string; Item: TJSONObject; const Me: TMember): string;
var
  I: integer;
begin
  Result := '';
  for I := 0 to High(ItemParts) do
    if ItemParts[I].Place = Place then
      Result := Result + ItemParts[I].Make(Item, Me);
end;

procedure RegisterCatalogFrame(const Name: string; Make: TCatalogFrame);
begin
  SetLength(Frames, Length(Frames) + 1);
  Frames[High(Frames)].Name := Name;
  Frames[High(Frames)].Make := Make;
end;

procedure RegisterCatalogText(const Name: string; Make: TCatalogText);
begin
  SetLength(Texts, Length(Texts) + 1);
  Texts[High(Texts)].Name := Name;
  Texts[High(Texts)].Make := Make;
end;

function CatalogText(const Name: string; const Value: string = ''): string;
var
  I: integer;
begin
  Result := '';
  for I := 0 to High(Texts) do
    if Texts[I].Name = Name then
    begin
      Result := Texts[I].Make(Value);
      if Result <> '' then
        Exit;
    end;
end;

function CatalogTexts(const Name: string; const Value: string = ''): string;
var
  I: integer;
begin
  Result := '';
  for I := 0 to High(Texts) do
    if Texts[I].Name = Name then
      Result := Result + Texts[I].Make(Value);
end;

procedure RegisterCatalogCountPart(const Name: string; Make: TCatalogCountPart);
begin
  SetLength(CountParts, Length(CountParts) + 1);
  CountParts[High(CountParts)].Name := Name;
  CountParts[High(CountParts)].Make := Make;
end;

procedure RegisterCatalogRoom(const Name: string; Open: TCatalogRoute);
begin
  SetLength(RoomOpeners, Length(RoomOpeners) + 1);
  RoomOpeners[High(RoomOpeners)].Name := Name;
  RoomOpeners[High(RoomOpeners)].Open := Open;
end;

procedure StartRoom(ARequest: TRequest; AResponse: TResponse);
begin
  if Length(RoomOpeners) > 0 then
    RoomOpeners[0].Open(ARequest, AResponse)
  else
    SendText(AResponse, 404, '');
end;

procedure RegisterCatalogChoices(const Name: string; const Choices: array of string);
var
  I, J: integer;
begin
  J := -1;
  for I := 0 to High(ChoiceLists) do
    if ChoiceLists[I].Name = Name then
      J := I;
  if J < 0 then
  begin
    J := Length(ChoiceLists);
    SetLength(ChoiceLists, J + 1);
  end;
  ChoiceLists[J].Name := Name;
  SetLength(ChoiceLists[J].Choices, Length(Choices));
  for I := 0 to High(Choices) do
    ChoiceLists[J].Choices[I] := Choices[I];
end;

function CatalogChoices(const Name: string): TStringArray;
var
  I: integer;
begin
  Result := nil;
  for I := 0 to High(ChoiceLists) do
    if ChoiceLists[I].Name = Name then
      Exit(ChoiceLists[I].Choices);
end;

procedure RegisterCatalogFilter(const Name: string; SQL: TCatalogFilterSQL);
begin
  SetLength(Filters, Length(Filters) + 1);
  Filters[High(Filters)].Name := Name;
  Filters[High(Filters)].SQL := SQL;
end;

procedure RegisterCatalogType(const Name: string; const Kinds: array of string);
var
  Kind: string;
begin
  SetLength(Types, Length(Types) + 1);
  Types[High(Types)].Name := Name;
  for Kind in Kinds do
  begin
    if Types[High(Types)].KindList <> '' then
      Types[High(Types)].KindList := Types[High(Types)].KindList + ', ';
    Types[High(Types)].KindList := Types[High(Types)].KindList + '''' + StringReplace(Kind, '''', '', [rfReplaceAll]) + '''';
  end;
end;

procedure RegisterCatalogField(Position: integer; const Name: string; Size: integer; Kind: TCatalogFieldKind);
begin
  FieldNames[Position] := Name;
  FieldSizes[Position] := Size;
  FieldKinds[Position] := Kind;
end;

procedure CatalogFieldAt(Position: integer; out Name: string; out Size: integer; out Kind: TCatalogFieldKind);
begin
  Name := FieldNames[Position];
  Size := FieldSizes[Position];
  Kind := FieldKinds[Position];
end;

procedure RegisterCatalogDiscovery(const Name: string; Narrow: TCatalogDiscoverPart; Choice: TCatalogDiscoverChoice; Next: TCatalogNextCarry; Narrowing: TCatalogNarrowing);
begin
  SetLength(Discoveries, Length(Discoveries) + 1);
  Discoveries[High(Discoveries)].Name := Name;
  Discoveries[High(Discoveries)].Narrow := Narrow;
  Discoveries[High(Discoveries)].Choice := Choice;
  Discoveries[High(Discoveries)].Next := Next;
  Discoveries[High(Discoveries)].Narrowing := Narrowing;
end;

procedure DiscoverChoice(ARequest: TRequest; out Where, Carry: string); forward;

{ What a site's own unit lets a reader narrow Random to (only this kind,
  only what works with that): its control, or nothing when no unit did. }
function DiscoverNarrow(ARequest: TRequest; Id: integer): string;
var
  I: integer;
begin
  Result := '';
  for I := 0 to High(Discoveries) do
    Result := Result + Discoveries[I].Narrow(ARequest, Id);
end;

{ Random entry offers Not for me (not counted) and Interesting (kept), each
  followed by another entry. On phones the bar sits at the bottom;
  interest.js also handles the arrow keys. }
function DiscoverBar(ARequest: TRequest; Id: integer): string;
var
  Other, Short, Bar, Start, Where, Carry, Pair, Kept: string;
begin
  Start := '';
  if ARequest.QueryFields.Values['discover'] = '1' then
  begin
    Other := Say('Not for me, show me another');
    Short := Say('Not for me');
    Bar := 'discover-bar discovering';
  end
  else
  begin
    Other := Say('Random entry');
    Short := Other;
    Bar := 'discover-bar';
    Start := '&amp;do=start';
  end;
  // what Random is narrowed to goes along with either answer
  DiscoverChoice(ARequest, Where, Carry);
  Kept := '';
  for Pair in Carry.Split(['&'], TStringSplitOptions.ExcludeEmpty) do
    Kept := Kept + '<input type="hidden" name="' + E(Pair.Split(['='])[0]) + '" value="' + E(Copy(Pair, Pos('=', Pair) + 1, MaxInt)) + '">';
  Result := '<div class="' + Bar + '" role="group" aria-label="' + E(Say('Discovering entries')) + '"><a class="discover-no';
  if Start <> '' then
    Result := Result + ' random-dice';
  Result := Result + '" href="/catalog-random?from=' + IntToStr(Id) + '&amp;came=no' + Start + StringReplace(Carry, '&', '&amp;', [rfReplaceAll]) +
    '" rel="nofollow" data-key="ArrowLeft" title="' + E(Other) + '"><span class="long">' + E(Other) + '</span><span class="short">' +
    E(Short) + '</span></a>' + '<form method="post" action="/catalog/' + IntToStr(Id) + '/interest"><input type="hidden" name="then" value="next">' +
    Kept + '<button type="submit" class="discover-yes" data-key="ArrowRight" title="' + E(Say('Interesting, show me another')) + '">' +
    StarIcon + '<span class="long">' + E(Say('Interesting, show me another')) + '</span><span class="short">' + E(Say('Interesting')) + '</span></button></form></div>';
end;

procedure DiscoverChoice(ARequest: TRequest; out Where, Carry: string);
var
  I: integer;
  ExtraWhere, ExtraCarry: string;
begin
  Where := '';
  Carry := '';
  for I := 0 to High(Discoveries) do
  begin
    Discoveries[I].Choice(ARequest, ExtraWhere, ExtraCarry);
    Where := Where + ExtraWhere;
    Carry := Carry + ExtraCarry;
  end;
end;

function NextCarry(ARequest: TRequest): string;
var
  I: integer;
begin
  Result := '';
  for I := 0 to High(Discoveries) do
    Result := Result + Discoveries[I].Next(ARequest);
end;

function NarrowingOf(const TypeText, Works: string): string;
var
  I: integer;
begin
  Result := '';
  for I := 0 to High(Discoveries) do
    Result := Result + Discoveries[I].Narrowing(TypeText, Works);
end;

{ The later of the last push and the repository's own date, for sorting. }
function RecentSQL: string;
begin
  Result := SqlGreatest('COALESCE(pushed, ''1000-01-01'')', 'COALESCE(repository_date, ''1000-01-01'')');
end;

{ An entry's state, by its repository's last push. }
function CatalogStatusSQL: string;
begin
  Result := 'CASE WHEN archived = 1 THEN ''archived'' WHEN pushed IS NULL THEN ''unknown''' + ' WHEN pushed >= ' + SqlMinus('UTC_DATE()', '730', suDay) +
    ' THEN ''active'' ELSE ''quiet'' END';
end;

function CatalogEntryKey(const Text: string): string;
var
  KeyText, HostText, Part: string;
  C: char;
begin
  Result := '';
  KeyText := LowerCase(Trim(Text));
  if (KeyText = '') or (Length(KeyText) > 190) then
    Exit;
  for C in KeyText do
    if not (C in ['a'..'z', '0'..'9', '-', '.', '_', '~', '/', '+', '%']) then
      Exit;
  HostText := Copy(KeyText, 1, Pos('/', KeyText + '/') - 1);
  if (Pos('.', HostText) < 2) or HostText.EndsWith('.') then
    Exit;
  for Part in HostText.Split(['.']) do
  begin
    if (Part = '') or Part.StartsWith('-') or Part.EndsWith('-') then
      Exit;
    for C in Part do
      if not (C in ['a'..'z', '0'..'9', '-']) then
        Exit;
  end;
  for Part in KeyText.Split(['/']) do
    if (Part = '.') or (Part = '..') or (Part = '') then
      Exit;
  Result := KeyText;
end;

function CatalogURL(const Text: string): boolean;
var
  Address: TURI;
  C: char;
begin
  Result := False;
  if not StartsText('https://', Text) and not StartsText('http://', Text) then
    Exit;
  for C in Text do
    if (Ord(C) <= 32) or (Ord(C) = 127) or (C = '\') then
      Exit;
  try
    Address := ParseURI(Text, False);
    Result := (Address.Host <> '') and Address.HasAuthority and (Address.Username = '') and (Address.Password = '') and
      (SameText(Address.Protocol, 'https') or SameText(Address.Protocol, 'http'));
  except
    Result := False;
  end;
end;

function CatalogLabelKey(const Text: string): string;
begin
  Result := LowerCase(StringReplace(Trim(Text), ' ', '', [rfReplaceAll]));
end;

function CatalogRoomText(const Text: string; MaxBytes: integer): string;
var
  Cut: integer;
begin
  Cut := Length(Text);
  if Cut > MaxBytes then
  begin
    Cut := MaxBytes;
    while (Cut > 0) and ((Ord(Text[Cut + 1]) and $C0) = $80) do
      Dec(Cut);
  end;
  Result := Copy(Text, 1, Cut);
end;

function CatalogCategories(const Text: string): string;
var
  Labels, Keys: TStringList;
  Part, Caption: string;
begin
  Labels := TStringList.Create;
  Keys := TStringList.Create;
  try
    for Part in Text.Split([',']) do
    begin
      Caption := Trim(Part);
      if (Caption <> '') and (Keys.IndexOf(CatalogLabelKey(Caption)) < 0) then
      begin
        Labels.Add(Caption);
        Keys.Add(CatalogLabelKey(Caption));
      end;
    end;
    Result := string.Join(',', Labels.ToStringArray);
  finally
    Keys.Free;
    Labels.Free;
  end;
end;

function CatalogCaption(const Text: string): string;
begin
  Result := CatalogText('caption', Text);
  if Result <> '' then
    Exit;
  case Text of
    'unknown': Result := Say('Unknown');
    'github': Result := Say('GitHub');
    'gitlab': Result := Say('GitLab');
    'codeberg': Result := Say('Codeberg');
    'bitbucket': Result := Say('Bitbucket');
    'sourceforge': Result := Say('SourceForge');
    'gitea': Result := Say('Forgejo or Gitea');
    'sourcehut': Result := Say('sourcehut');
    'launchpad': Result := Say('Launchpad');
    'web': Result := Say('Web');
    'active': Result := Say('Active');
    'quiet': Result := Say('Quiet');
    'archived': Result := Say('Archived');
    'name': Result := Say('Name');
    'stars': Result := Say('Stars');
    'rating': Result := Say('Member rating');
    'other': Result := Say('Other');
    'recent': Result := Say('Most recent');
    'interest': Result := Say('Most interesting');
    'best': Result := Say('Best match');
    else
      Result := Say(Text);
  end;
end;

function CategoryLinks(Item: TJSONObject; const Filters: string): string;
var
  Part, Labels: string;
begin
  Result := '';
  Labels := Item.Get('categories', '');
  for Part in Labels.Split([','], TStringSplitOptions.ExcludeEmpty) do
    Result := Result + '<a href="/catalog?category=' + E(HTTPEncode(Part) + Filters) + '">' + E(CatalogCaption(Part)) + '</a> ';
end;

function LatestDate(Item: TJSONObject): string;
var
  ColumnName, DateText: string;
begin
  Result := '';
  for ColumnName in ['created', 'pushed', 'released', 'repository_date'] do
  begin
    DateText := Item.Get(ColumnName, '');
    if DateText > Result then
      Result := DateText;
  end;
end;

{ What an entry is called: its title, or its name when it has none. }
function EntryTitle(Item: TJSONObject): string;
begin
  Result := Item.Get('title', '');
  if Result = '' then
    Result := Item.Get('name', '');
end;

function ProjectAddress(Item: TJSONObject): string;
begin
  Result := Item.Get('url', '');
  if CatalogURL(Result) then
    Exit;
  // an entry put in by hand without an address lives nowhere: its key is only its name
  if StartsStr('entry.local/', string(Item.Get('entry_key', ''))) then
    Result := ''
  else
    Result := 'https://' + Item.Get('entry_key', '');
end;

function CatalogImageAllowed(const Url: string): boolean;
var
  Host: string;
  I: integer;
begin
  Result := False;
  if (Length(Url) > 2000) or (Pos('"', Url) > 0) or (Pos('<', Url) > 0) then
    Exit;
  // a picture kept on this site: a plain path, nothing that could climb out
  if StartsStr('/catalog-images/', Url) then
  begin
    Result := (Pos('..', Url) = 0) and (Pos('//', Copy(Url, 2, MaxInt)) = 0) and (Length(Url) < 120);
    for I := 1 to Length(Url) do
      if not (Url[I] in ['a'..'z', '0'..'9', '/', '.', '-']) then
        Exit(False);
    Exit;
  end;
  for Host in ImageHosts do
    if StartsText('https://' + Host + '/', Url) then
      Exit(True);
end;

function CatalogPictureUrl(const Token: string): string;
begin
  Result := '';
  if Token <> '' then
    Result := '/f/' + Token + '/picture';
end;

function CatalogSearchTerms(const Q: string): TStringArray;
var
  I: integer;
  word: string;

  procedure Keep;
  begin
    if word <> '' then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := word;
      word := '';
    end;
  end;

begin
  Result := nil;
  word := '';
  for I := 1 to Length(Q) do
    if (Q[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_', '.', '#']) or (Ord(Q[I]) >= 128) then
      word := word + Q[I]
    else
      Keep;
  Keep;
  if Length(Result) > 8 then
    SetLength(Result, 8);
end;

function CatalogBooleanQuery(const Terms: TStringArray): string;
var
  Term, Piece: string;
begin
  Result := '';
  // the index splits words at a dot or #, so System.JSON is two words there;
  // it keeps _ inside a word, as in lnet_ssl
  for Term in Terms do
    for Piece in Term.Split(['.', '#'], TStringSplitOptions.ExcludeEmpty) do
      // the full-text index leaves out words under three letters
      if Length(Piece) >= 3 then
        Result := Result + ' +' + Piece + '*';
  Result := Trim(Result);
end;

function CatalogIconUrl(const Icon, Forge, Owner: string): string;
var
  C: char;
begin
  if CatalogImageAllowed(Icon) then
    Exit(Icon);
  Result := '';
  if Owner = '' then
    Exit;
  for C in Owner do
    if not (C in ['A'..'Z', 'a'..'z', '0'..'9', '-', '_', '.']) then
      Exit;
  case Forge of
    'github': Result := 'https://github.com/' + Owner + '.png?size=80';
    // GitLab turns away pages that ask for many at once, and SourceForge
    // turns away every one asked for from another site: the letter stays
    'codeberg': Result := 'https://codeberg.org/' + Owner + '.png';
  end;
end;

function CatalogIcon(const Icon, Forge, Owner, TitleText: string): string;
var
  Url, Letter: string;
  Hue, I: integer;
begin
  Letter := '?';
  Hue := 0;
  for I := 1 to Length(TitleText) do
    Hue := (Hue * 31 + Ord(TitleText[I])) mod 360;
  for I := 1 to Length(TitleText) do
    if TitleText[I] in ['A'..'Z', 'a'..'z', '0'..'9'] then
    begin
      Letter := UpCase(TitleText[I]);
      Break;
    end;
  Result := '<span class="catalog-icon" aria-hidden="true" style="--hue:' + IntToStr(Hue) + '"><span>' + E(Letter) + '</span>';
  Url := CatalogIconUrl(Icon, Forge, Owner);
  if Url <> '' then
    Result := Result + '<img loading="lazy" referrerpolicy="no-referrer" alt="" src="' + E(Url) + '">';
  Result := Result + '</span>';
end;

function CatalogAverage(Count, Sum: integer): string;
var
  Settings: TFormatSettings;
begin
  Result := '';
  if Count <= 0 then
    Exit;
  Settings := DefaultFormatSettings;
  Settings.DecimalSeparator := '.';
  Result := Format('%.1f', [Sum / Count], Settings);
end;

function RatingSummary(Count, Sum: integer): string;
begin
  Result := '';
  if Count = 1 then
    Result := Format(Say('%s from %d member'), [CatalogAverage(Count, Sum), Count])
  else if Count > 1 then
    Result := Format(Say('%s from %d members'), [CatalogAverage(Count, Sum), Count]);
end;

threadvar
  // set for each request that lists or shows entries: whose presses to mark
  RequestInterestWho: string;

function InterestWho(ARequest: TRequest; const Me: TMember): string;
var
  Salt: string;
begin
  if Me.Id > 0 then
    Exit('m' + IntToStr(Me.Id));
  Salt := Setting('interest_salt', '');
  if Salt = '' then
  begin
    Salt := RandomHex(32);
    SaveSetting('interest_salt', Salt);
  end;
  Result := 'a' + Copy(Sha256Hex(Salt + ClientIp(ARequest)), 1, 40);
end;

{ Interesting's star: a drawn one, the same on every phone, in the text's color. }
function StarIcon: string;
begin
  Result := '<svg class="star-icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M12 2.5l2.95 6.02 6.6.93-4.8 4.62 1.15 6.58L12 17.52 ' +
    '6.1 20.65l1.15-6.58-4.8-4.62 6.6-.93z"/></svg>';
end;

function InterestForm(Id, Count: integer; Mine: boolean): string;
var
  Caption, Pressed, PressedWord: string;
begin
  if Mine then
  begin
    Caption := Say('You find this interesting. Press again to take it back.');
    Pressed := ' on';
    PressedWord := 'true';
  end
  else
  begin
    Caption := Say('Tell others this looks interesting');
    Pressed := '';
    PressedWord := 'false';
  end;
  Result := '<form method="post" action="/catalog/' + IntToStr(Id) + '/interest" class="interest-form" data-entry="' + IntToStr(Id) +
    '"><button type="submit" class="interest-button' + Pressed + '" aria-pressed="' + PressedWord + '" title="' + E(Caption) + '">' +
    StarIcon + ' ' + E(Say('Interesting')) + ' <span class="interest-count">' + IntToStr(Count) + '</span></button></form>';
end;

function RateForm(Id, Mine: integer): string;
var
  N: integer;
  Caption, Pressed, Mark, OnClass: string;
begin
  Result := '<form method="post" action="/catalog/' + IntToStr(Id) + '/rate" class="rate-form" data-entry="' + IntToStr(Id) + '">';
  for N := 1 to 5 do
  begin
    Caption := E(SayCount(N, 'Rate %d star', 'Rate %d stars'));
    Pressed := 'false';
    Mark := '&#9734;';
    OnClass := '';
    if N <= Mine then
    begin
      Mark := '&#9733;';
      OnClass := ' on';
    end;
    if N = Mine then
      Pressed := 'true';
    Result := Result + '<button type="submit" name="stars" value="' + IntToStr(N) + '" class="rate-star' + OnClass + '" aria-pressed="' +
      Pressed + '" aria-label="' + Caption + '" title="' + Caption + '">' + Mark + '</button>';
  end;
  Result := Result + '<button type="submit" name="stars" value="0" class="rate-clear"';
  if Mine = 0 then
    Result := Result + ' hidden';
  Result := Result + '>' + E(Say('Clear my rating')) + '</button></form>';
end;

procedure HostOf(Item: TJSONObject; out Address, Host, Logo, Place: string); forward;

{ A number with its thousands marked, 8,077, as it reads at a glance. }
function Thousands(N: integer): string;
begin
  Result := FormatFloat('#,##0', N);
end;

function CatalogCard(Item: TJSONObject; const Filters: string): string;
var
  Facts, TitleText, EntryLink, DateText, RateControls, Thumb, Status, Address, Host, Logo, Place, Rating: string;
  Stars: integer;

  procedure Fact(const Cls, Text: string; const Hint: string = '');
  begin
    if Text = '' then
      Exit;
    Facts := Facts + '<li class="' + Cls + '"';
    if Hint <> '' then
      Facts := Facts + ' title="' + E(Hint) + '"';
    Facts := Facts + '>' + Text + '</li>';
  end;

begin
  TitleText := EntryTitle(Item);
  EntryLink := '/catalog/' + IntToStr(Item.Get('id', 0));
  Facts := '';
  // an unknown status says nothing worth the room
  Status := Item.Get('status', 'unknown');
  if Status <> 'unknown' then
    Fact('fact-status status-' + E(Status), E(CatalogCaption(Status)));
  if Item.Get('kind', 'unknown') <> 'unknown' then
    Fact('fact-kind', E(CatalogCaption(Item.Get('kind', 'unknown'))));
  Facts := Facts + CatalogItemParts('card-works', Item, Default(TMember));
  HostOf(Item, Address, Host, Logo, Place);
  if Logo <> '' then
    Fact('fact-host', '<span class="host-logo host-' + Logo + '" aria-hidden="true"></span><span class="fact-host-name">' + E(Place) + '</span>', Place);
  Stars := Item.Get('stars', 0);
  if Stars > 0 then
    if Item.Get('forge', '') = 'github' then
      Fact('fact-stars', '&#9733; ' + E(Thousands(Stars)), SayCount(Stars, '%d GitHub star', '%d GitHub stars'))
    else
      Fact('fact-stars', '&#9733; ' + E(Thousands(Stars)), SayCount(Stars, '%d star', '%d stars'));
  if Item.Get('license', '') <> '' then
    Fact('fact-license', E(Item.Get('license', '')), Item.Get('license', ''));
  DateText := LatestDate(Item);
  if DateText <> '' then
    Fact('fact-date', DateTag(DateText));
  RateControls := '';
  if Item.Get('can_rate', False) then
    RateControls := RateForm(Item.Get('id', 0), Item.Get('my_rating', 0));
  // the picture the admin gave it, else the one an import found
  Thumb := Item.Get('picture', '');
  if (Thumb = '') and CatalogImageAllowed(Item.Get('image', '')) then
    Thumb := Item.Get('image', '');
  if Thumb <> '' then
    Thumb := '<a class="catalog-thumb" href="' + E(EntryLink) + '" tabindex="-1" aria-hidden="true"><img loading="lazy" referrerpolicy="no-referrer" alt="" src="' +
      E(Thumb) + '"></a>';
  Rating := RatingSummary(Item.Get('rating_count', 0), Item.Get('rating_sum', 0));
  // the title's link covers the whole card; the controls on it sit above it
  Result := '<article class="tile catalog-card">' + Thumb + '<h2 class="catalog-named">' + CatalogIcon(Item.Get('icon', ''), Item.Get('forge', ''),
    Item.Get('owner', ''), TitleText) + '<a class="card-link" href="' + E(EntryLink) + '">' + E(TitleText) + '</a></h2><p class="catalog-summary" dir="auto">' +
    E(Item.Get('summary', '')) + '</p><ul class="card-facts">' + Facts + '</ul><p class="catalog-categories">' + CategoryLinks(Item, Filters) +
    CatalogItemParts('card-mark', Item, Default(TMember)) + '</p><div class="card-foot"><span class="catalog-rating-text" data-rating-summary="' +
    IntToStr(Item.Get('id', 0)) + '">' + E(Rating) + '</span>' + RateControls + InterestForm(Item.Get('id', 0), Item.Get('interest', 0),
    Item.Get('my_interest', False)) + '</div></article>';
end;

function CatalogSelect: string;
var
  I: integer;
begin
  Result := '';
  for I := 0 to High(FieldNames) do
  begin
    if FieldNames[I] = '' then
      Continue;
    if Result <> '' then
      Result := Result + ', ';
    if FieldKinds[I] = cfTime then
      Result := Result + IsoTime(FieldNames[I]) + ' AS ' + FieldNames[I]
    else if FieldKinds[I] = cfDate then
      Result := Result + 'COALESCE(' + SqlDay(FieldNames[I]) + ', '''') AS ' + FieldNames[I]
    else
      Result := Result + FieldNames[I];
  end;
end;

{ Added after the status column: what members say, and what this one said. }
function RatingColumns(MemberId: integer): string;
begin
  Result := ', rating_count, rating_sum, image, icon, COALESCE((SELECT ' + SqlLeft('rd.body', 700) +
    ' FROM catalog_readmes rd WHERE rd.entry_id = catalog_entries.id), '''') AS readme_start, COALESCE((SELECT r.stars FROM catalog_ratings r WHERE r.entry_id = catalog_entries.id AND r.user_id = '
    + IntToStr(MemberId) + '), 0) AS my_rating' +
    // RequestInterestWho is made of letters and digits only (InterestWho)
    ', interest, EXISTS(SELECT 1 FROM catalog_interest ci WHERE ci.entry_id = catalog_entries.id AND ci.who = ''' + RequestInterestWho + ''') AS my_interest, picture';
end;

function CatalogRow(Row: TSQLQuery): TJSONObject;
var
  I, Column: integer;
begin
  Result := TJSONObject.Create;
  Column := 0;
  for I := 0 to High(FieldNames) do
  begin
    if FieldNames[I] = '' then
      Continue;
    if FieldKinds[I] in [cfNumber, cfBoolean] then
      Result.Add(FieldNames[I], Row.Fields[Column].AsInteger)
    else
      Result.Add(FieldNames[I], Row.Fields[Column].AsString);
    Inc(Column);
  end;
  Result.Add('status', Row.Fields[Column + 0].AsString);
  Result.Add('rating_count', Row.Fields[Column + 1].AsInteger);
  Result.Add('rating_sum', Row.Fields[Column + 2].AsInteger);
  Result.Add('rating_average', CatalogAverage(Row.Fields[Column + 1].AsInteger, Row.Fields[Column + 2].AsInteger));
  Result.Add('image', Row.Fields[Column + 3].AsString);
  Result.Add('icon', Row.Fields[Column + 4].AsString);
  Result.Add('readme_start', Row.Fields[Column + 5].AsString);
  Result.Add('my_rating', Row.Fields[Column + 6].AsInteger);
  Result.Add('interest', Row.Fields[Column + 7].AsInteger);
  Result.Add('my_interest', Row.Fields[Column + 8].AsInteger = 1);
  Result.Add('picture', CatalogPictureUrl(Row.Fields[Column + 9].AsString));
end;

function ReadEntry(Id: integer; MemberId: integer; Hidden: boolean): TJSONObject;
var
  Row: TSQLQuery;
begin
  Result := nil;
  // a hidden entry only for who asked for those too
  Row := Query('SELECT ' + CatalogSelect + ', ' + CatalogStatusSQL + RatingColumns(MemberId) + ' FROM catalog_entries WHERE id = :i AND (hidden = 0 OR :h = 1)',
    [Id, Ord(Hidden)]);
  try
    if not Row.EOF then
      Result := CatalogRow(Row);
  finally
    Row.Free;
  end;
end;

function QueryProblem(ARequest: TRequest): string;
begin
  Result := '';
  if Trim(ARequest.QueryFields.Values['q']) <> '' then
    Result := SearchWordsProblem(ARequest.QueryFields.Values['q']);
  if (Length(ARequest.QueryFields.Values['category']) > 800) or (Length(ARequest.QueryFields.Values['source']) > 100) then
    Result := Say('The filter text is too long.');
end;

{ A search with words and nothing else that narrows it: only q, the page,
  the order and the language asked. }
function OnlyWords(Asked: TStrings): boolean;
var
  I: integer;
begin
  Result := True;
  for I := 0 to Asked.Count - 1 do
    if not AnsiMatchText(Asked.Names[I], ['q', 'page', 'sort', 'lang', '']) and (Asked.ValueFromIndex[I] <> '') then
      Exit(False);
end;

{ The entries a search finds, best first: Limit of them after the first
  Offset.  Asked holds the words (q) and the filters, as the list's address
  has them.  Hidden entries are never among them.  Similar says the names
  only sound like the word, More that there are others after these. }
function FoundEntries(ARequest: TRequest; Asked: TStrings; Offset, Limit: integer; out Similar, More: boolean): TJSONArray;
var
  SQL, OrderSQL, Words, KindText, SourceText, StatusText, FilterValue: string;
  FilterIndex: integer;
  Row: TSQLQuery;
  BindValues: array of variant;
  Mine: boolean;
  MemberNumber: integer;
  Terms: TStringArray;
  Term, Bool, Score, Match: string;

  procedure AddFilter(const Clause: string; const Value: variant);
  begin
    SQL := SQL + Clause + ':f' + IntToStr(Length(BindValues));
    SetLength(BindValues, Length(BindValues) + 1);
    BindValues[High(BindValues)] := Value;
  end;

  { A parameter in the text being built, in the order the query reads them. }
  function Bind(const Value: variant): string;
  begin
    Result := ':f' + IntToStr(Length(BindValues));
    SetLength(BindValues, Length(BindValues) + 1);
    BindValues[High(BindValues)] := Value;
  end;

  procedure Fetch;
  begin
    Row := Query(SQL, BindValues);
    try
      while not Row.EOF do
      begin
        Result.Add(CatalogRow(Row));
        Row.Next;
      end;
    finally
      Row.Free;
    end;
  end;

begin
  BindValues := nil;
  MemberNumber := CurrentMember(ARequest).Id;
  RequestInterestWho := InterestWho(ARequest, CurrentMember(ARequest));
  Mine := (MemberNumber > 0) and (Asked.Values['mine'] = '1');
  Words := Trim(Asked.Values['q']);
  Terms := CatalogSearchTerms(Words);
  Bool := CatalogBooleanQuery(Terms);
  Similar := False;
  SQL := 'SELECT ' + CatalogSelect + ', ' + CatalogStatusSQL + RatingColumns(MemberNumber);
  // how well an entry answers the search: its name above its words, its words
  // above its README, popularity to break ties
  if Words <> '' then
  begin
    Score := '(name = ' + Bind(Words) + ') * 1000 + (name LIKE ' + Bind(LikePrefix(Words)) + ') * 300 + (title LIKE ' + Bind('%' + LikePrefix(Words)) +
      ') * 100 + (owner = ' + Bind(Words) + ') * 150';
    if Bool <> '' then
      Score := Score + ' + ' + SqlMatch('name, title, summary, topics, categories, owner', Bind(Bool), True) + ' * 20' + ' + (rm.entry_id IS NOT NULL) * 15';
    // this site's members count for more than a forge's stars: any rating lifts
    // a project, a good one more, but never above a plain match on its name
    SQL := SQL + ', ' + Score + ' + LOG(2 + stars) * 4 + (rating_count > 0) * 150 + COALESCE(rating_sum / NULLIF(rating_count, 0), 0) * 20' +
      ' + LEAST(rating_count, 20) * 5 + LEAST(interest, 50) * 6 AS score';
  end
  else
    SQL := SQL + ', 0 AS score';
  SQL := SQL + ' FROM catalog_entries';
  // the READMEs that hold the words, found once through their own index
  if Bool <> '' then
    SQL := SQL + ' LEFT JOIN (SELECT entry_id FROM catalog_readmes WHERE ' + SqlMatch('body', Bind(Bool), True) + ') rm ON rm.entry_id = catalog_entries.id';
  SQL := SQL + ' WHERE hidden = 0';
  if Mine then
    SQL := SQL + ' AND EXISTS (SELECT 1 FROM catalog_ratings r WHERE r.entry_id = catalog_entries.id AND r.user_id = ' + IntToStr(MemberNumber) + ')';
  if Words <> '' then
  begin
    // every word somewhere in the name, title, owner, topics or categories, as
    // the start of a word or inside one; or the words in the text or the README
    Match := '';
    for Term in Terms do
    begin
      if Match <> '' then
        Match := Match + ' AND ';
      // a word of one or two letters only as the start of a name or of a word in the title
      if Length(Term) < 3 then
        Match := Match + '(name LIKE ' + Bind(LikePrefix(Term)) + ' OR title LIKE ' + Bind(LikePrefix(Term)) + ' OR title LIKE ' + Bind('% ' + LikePrefix(Term)) + ')'
      else
        Match := Match + '(name LIKE ' + Bind('%' + LikePrefix(Term)) + ' OR title LIKE ' + Bind('%' + LikePrefix(Term)) + ' OR owner LIKE ' +
          Bind(LikePrefix(Term)) + ' OR authors LIKE ' + Bind('%' + LikePrefix(Term)) + ' OR topics LIKE ' + Bind('%' + LikePrefix(Term)) +
          ' OR categories LIKE ' + Bind('%' + LikePrefix(Term)) + ')';
    end;
    if Match = '' then
      Match := '0';
    SQL := SQL + ' AND ((' + Match + ')';
    if Bool <> '' then
      SQL := SQL + ' OR ' + SqlMatch('name, title, summary, topics, categories, owner', Bind(Bool), True) + ' OR rm.entry_id IS NOT NULL';
    SQL := SQL + ')';
  end;
  KindText := Asked.Values['kind'];
  SourceText := LowerCase(Trim(Asked.Values['source']));
  StatusText := Asked.Values['status'];
  if KindText <> '' then
    AddFilter(' AND kind = ', KindText);
  // a tab's kinds, from the unit that registered the tab, never from the request
  for FilterIndex := 0 to High(Types) do
    if Types[FilterIndex].Name = Asked.Values['type'] then
      SQL := SQL + ' AND kind IN (' + Types[FilterIndex].KindList + ')';
  for FilterIndex := 0 to High(Filters) do
  begin
    FilterValue := Asked.Values[Filters[FilterIndex].Name];
    if FilterValue <> '' then
      SQL := SQL + Filters[FilterIndex].SQL(FilterValue, Bind(FilterValue));
  end;
  if SourceText <> '' then
  begin
    AddFilter(' AND FIND_IN_SET(', CatalogLabelKey(SourceText));
    SQL := SQL + ', REPLACE(sources, '' '', '''')) > 0';
  end;
  if Asked.Values['category'] <> '' then
  begin
    AddFilter(' AND FIND_IN_SET(', CatalogLabelKey(Asked.Values['category']));
    SQL := SQL + ', LOWER(REPLACE(categories, '' '', ''''))) > 0';
  end;
  if StatusText <> '' then
    AddFilter(' AND (' + CatalogStatusSQL + ') = ', StatusText);
  OrderSQL := 'name, id';
  // with no choice: the best match for a search, else the best known first,
  // or a member's own favorites
  if (Words <> '') and ((Asked.Values['sort'] = '') or (Asked.Values['sort'] = 'best')) then
    OrderSQL := 'score DESC, stars DESC, ' + OrderSQL
  else if (Asked.Values['sort'] = '') or (Asked.Values['sort'] = 'best') then
    if Mine then
      OrderSQL := 'my_rating DESC, ' + OrderSQL
    else
      // what members here have rated comes first, best first; then the forges' stars
      // each press counts as much as multiplying the stars by about four and a half
      OrderSQL := 'rating_count = 0, rating_sum / NULLIF(rating_count, 0) DESC, rating_count DESC, LN(2 + stars) + interest * 1.5 DESC, ' + OrderSQL;
  case Asked.Values['sort'] of
    'stars': OrderSQL := 'stars DESC, ' + OrderSQL;
    'interest': OrderSQL := 'interest DESC, stars DESC, ' + OrderSQL;
    'rating': OrderSQL := 'rating_count = 0, rating_sum / NULLIF(rating_count, 0) DESC, rating_count DESC, ' + OrderSQL;
    'recent': OrderSQL := RecentSQL + ' DESC, ' + OrderSQL;
  end;
  AddFilter(' ORDER BY ' + OrderSQL + ' LIMIT ', Limit + 1);
  AddFilter(' OFFSET ', Offset);
  Result := TJSONArray.Create;
  try
    Fetch;
    // nothing for one longer word: names that sound like it, in case of a
    // slip; only for the word alone, since this asks without the filters
    if (Result.Count = 0) and (Offset = 0) and (Length(Terms) = 1) and (Length(Terms[0]) >= 4) and OnlyWords(Asked) then
    begin
      BindValues := nil;
      SQL := 'SELECT ' + CatalogSelect + ', ' + CatalogStatusSQL + RatingColumns(MemberNumber) + ', 0 AS score FROM catalog_entries WHERE hidden = 0' +
        ' AND (SOUNDEX(name) = SOUNDEX(' + Bind(Terms[0]) + ') OR SOUNDEX(title) = SOUNDEX(' + Bind(Terms[0]) + '))' +
        ' ORDER BY stars DESC, name, id LIMIT ' + Bind(Limit + 1);
      Fetch;
      Similar := Result.Count > 0;
    end;
    More := Result.Count > Limit;
    if More then
      Result.Delete(Limit);
  except
    Result.Free;
    raise;
  end;
end;

{ What the list shows for a request: a page of entries, and the count of
  all that are visible. }
function SearchCatalog(ARequest: TRequest): TJSONObject;
var
  Page: integer;
  Similar, More: boolean;
  Items: TJSONArray;
begin
  Page := StrToIntDef(ARequest.QueryFields.Values['page'], 0);
  if Page < 0 then
    Page := 0;
  if Page > 1000000 then
    Page := 1000000;
  Items := FoundEntries(ARequest, ARequest.QueryFields, Page * PageSize, PageSize, Similar, More);
  Result := TJSONObject.Create(['similar', Similar, 'items', Items, 'page', Page, 'more', More, 'total', IntValue('SELECT visible FROM catalog_totals WHERE id = 1', [])]);
end;

{ The catalog in the site's search: entries by the words alone, as its own
  list finds and orders them. }
function FindInCatalog(ARequest: TRequest; const Me: TMember; const Words: string; Offset, Limit: integer; out More: boolean): TSearchHits;
var
  Asked: TStringList;
  Found: TJSONArray;
  Item: TJSONObject;
  Similar: boolean;
  I: integer;
begin
  Result := nil;
  Asked := TStringList.Create;
  try
    Asked.Values['q'] := Words;
    Found := FoundEntries(ARequest, Asked, Offset, Limit, Similar, More);
  finally
    Asked.Free;
  end;
  try
    for I := 0 to Found.Count - 1 do
    begin
      Item := Found.Objects[I];
      AddSearchHit(Result, EntryTitle(Item), '/catalog/' + IntToStr(Item.Get('id', 0)), Item.Get('summary', ''), LatestDate(Item), Item.Get('owner', ''), 'entry');
    end;
  finally
    Found.Free;
  end;
end;

{ An entry as the index takes it: what it says of itself, then its README. }
function CatalogDoc(const Id: string; var Doc: TIndexDoc): boolean;
var
  Item: TJSONObject;
  Field, Day: string;
  Votes, Liked: integer;
begin
  Item := ReadEntry(StrToIntDef(Id, 0));
  Result := Item <> nil;
  if not Result then
    Exit;
  try
    Doc.Title := EntryTitle(Item);
    if Item.Get('name', '') <> Doc.Title then
      Doc.Names := Item.Get('name', '');
    for Field in ['name', 'summary', 'topics', 'categories', 'owner', 'authors'] do
      Doc.Text := Doc.Text + Item.Get(Field, '') + LineEnding;
    Doc.Text := Doc.Text + PlainWords(VarToStr(Value('SELECT body FROM catalog_readmes WHERE entry_id = :e', [StrToIntDef(Id, 0)])));
    Votes := Item.Get('rating_count', 0);
    if Votes > 20 then
      Votes := 20;
    Liked := Item.Get('interest', 0);
    if Liked > 50 then
      Liked := 50;
    Doc.Count := Round(2 * Ln(2 + Item.Get('stars', 0))) + 3 * Votes + Liked;
    Day := Copy(LatestDate(Item), 1, 10);
    if (Length(Day) <> 10) or not TryEncodeDate(StrToIntDef(Copy(Day, 1, 4), 0), StrToIntDef(Copy(Day, 6, 2), 0), StrToIntDef(Copy(Day, 9, 2), 0), Doc.Time) then
      Doc.Time := 0;
  finally
    Item.Free;
  end;
end;

function CatalogNext(const After: string; Count: integer): TStringArray;
begin
  Result := IndexIds('SELECT id FROM catalog_entries WHERE id > :a ORDER BY id LIMIT :n', [StrToIntDef(After, 0), Count]);
end;

function CatalogHits(ARequest: TRequest; const Me: TMember; const Ids: TStringArray): TSearchHits;
var
  Id: string;
  Item: TJSONObject;
begin
  Result := nil;
  for Id in Ids do
  begin
    Item := ReadEntry(StrToIntDef(Id, 0), Me.Id);
    if Item = nil then
      Continue;
    try
      AddSearchHit(Result, EntryTitle(Item), '/catalog/' + Id, Item.Get('summary', ''), LatestDate(Item), Item.Get('owner', ''), 'entry', Id);
    finally
      Item.Free;
    end;
  end;
end;

procedure EntryChanged(EntryId: integer);
begin
  SearchChanged('catalog', IntToStr(EntryId));
end;

function CatalogParams(ARequest: TRequest; Page: integer; const Omit: string = ''): string;
var
  Key: string;
begin
  Result := '';
  for Key in ['q', 'category', 'source', 'kind', 'type', 'works_with', 'status', 'sort', 'mine'] do
    if Key <> Omit then
      Result := Result + '&' + Key + '=' + HTTPEncode(ARequest.QueryFields.Values[Key]);
  if Page >= 0 then
    Result := Result + '&page=' + IntToStr(Page);
end;

function CatalogOptions(const Choices: array of string; const Selected: string; AnyChoice: boolean): string;
var
  Choice, Mark: string;
begin
  Result := '';
  if AnyChoice then
    Result := '<option value="">' + E(Say('Any')) + '</option>';
  for Choice in Choices do
  begin
    Mark := '';
    if Choice = Selected then
      Mark := ' selected';
    Result := Result + '<option value="' + E(Choice) + '"' + Mark + '>' + E(CatalogCaption(Choice)) + '</option>';
  end;
end;

procedure CatalogPage(ARequest: TRequest; AResponse: TResponse; const Me: TMember; const Title, Main: string);
var
  Html: string;
  I: integer;
begin
  AResponse.SetCustomHeader('Cache-Control', 'no-store');
  Html := '';
  for I := 0 to High(Frames) do
  begin
    Html := Frames[I].Make(ARequest, Me, Title, Main);
    if Html <> '' then
      Break;
  end;
  if Html = '' then
  begin
    // the catalog's own page, in the frame every module can share
    Html := PartPage(ARequest, Me, Title, Main, SideGroup(Say('Catalog')) + SideLink('/catalog', Say('All entries')) +
      SideLink('/catalog-random', Say('A random one')) + SideLink('/catalog-how', Say('How the catalog works')), 'catalog.css',
      'interest.js,catalog.js', 'catalog-body', 'catalog-main');
  end;
  SendPage(AResponse, Html);
end;

{ What the entries on show hold, read once every few minutes: it changes
  only when entries do, and this is on every catalog page.  The categories
  and kinds in use, and whether any entry has a source, a state or stars:
  a catalog of things that have none does not offer to filter or sort by
  them. }
type
  TInUse = record
    Categories, Kinds: string;   // one to a line
    Sources, States, Stars: boolean;
  end;

var
  InUseLock: TRTLCriticalSection;
  InUseKept: TInUse;
  InUseMade: TDateTime = 0;

function ReadInUse: TInUse;

  function Any(const Condition: string): boolean;
  begin
    Result := IntValue('SELECT id FROM catalog_entries WHERE hidden = 0 AND ' + Condition + ' LIMIT 1', []) > 0;
  end;

var
  Gathered: TStringList;
  Labels, Part: string;
begin
  Result.Kinds := '';
  Gathered := TStringList.Create;
  try
    Gathered.Sorted := True;
    Gathered.Duplicates := dupIgnore;
    Gathered.CaseSensitive := False;
    with Query('SELECT DISTINCT categories FROM catalog_entries WHERE hidden = 0', []) do
    try
      while not EOF do
      begin
        Labels := Fields[0].AsString;
        while Labels <> '' do
        begin
          Part := Trim(Copy2SymbDel(Labels, ','));
          if Part <> '' then
            Gathered.Add(Part);
        end;
        Next;
      end;
    finally
      Free;
    end;
    Result.Categories := Gathered.Text;
  finally
    Gathered.Free;
  end;
  with Query('SELECT DISTINCT kind FROM catalog_entries WHERE hidden = 0 AND kind <> ''unknown'' ORDER BY kind LIMIT 100', []) do
  try
    while not EOF do
    begin
      Result.Kinds := Result.Kinds + Fields[0].AsString + LineEnding;
      Next;
    end;
  finally
    Free;
  end;
  Result.Sources := Any('sources <> ''''');
  Result.States := Any('(pushed IS NOT NULL OR archived = 1)');
  Result.Stars := Any('stars > 0');
end;

procedure CatalogEntriesChanged;
begin
  EnterCriticalSection(InUseLock);
  InUseMade := 0;
  LeaveCriticalSection(InUseLock);
end;

function InUse: TInUse;
begin
  EnterCriticalSection(InUseLock);
  try
    if Now - InUseMade > 5 / (24 * 60) then
    begin
      InUseKept := ReadInUse;
      InUseMade := Now;
    end;
    Result := InUseKept;
  finally
    LeaveCriticalSection(InUseLock);
  end;
end;

function CategoryOptions(const Chosen: string): string;
var
  Names: TStringList;
  I: integer;
begin
  Result := '<option value="">' + E(Say('Any')) + '</option>';
  Names := TStringList.Create;
  try
    Names.Text := InUse.Categories;
    for I := 0 to Names.Count - 1 do
    begin
      Result := Result + '<option value="' + E(Names[I]) + '"';
      if CatalogLabelKey(Names[I]) = CatalogLabelKey(Chosen) then
        Result := Result + ' selected';
      Result := Result + '>' + E(CatalogCaption(Names[I])) + '</option>';
    end;
  finally
    Names.Free;
  end;
end;

{ A filter with its label, or nothing when there is nothing to choose from. }
function ChoiceField(const Name, Caption, Selected: string; const Choices: array of string): string;
begin
  Result := '';
  if Length(Choices) > 0 then
    Result := '<label>' + E(Caption) + ' <select name="' + Name + '">' + CatalogOptions(Choices, Selected) + '</select></label>';
end;

{ The kinds to filter by: the ones a site's own unit registered, or, with
  none registered, the ones the entries have. }
function KindChoices: TStringArray;
begin
  Result := CatalogChoices('kind');
  if Length(Result) = 0 then
    Result := InUse.Kinds.Split([LineEnding], TStringSplitOptions.ExcludeEmpty);
end;

{ The lines under the catalog's heading: the admin's own (the setting
  catalog_intro), or a plain sentence. }
function CatalogIntro: string;
begin
  Result := Trim(Setting('catalog_intro', ''));
  if Result = '' then
    Result := Say('What this community makes, uses and recommends. Rate an entry, mark what looks interesting, and say so when something does not belong.');
end;

{ The extra filters stay open while one of them is in use. }
function OpenMark(ARequest: TRequest): string;
var
  Field: string;
begin
  Result := '';
  for Field in ['source', 'kind', 'works_with', 'status', 'sort'] do
    if (ARequest.QueryFields.Values[Field] <> '') and (ARequest.QueryFields.Values[Field] <> 'best') then
      Exit(' open');
end;

{ The tabs over the list: All, then each type a site's unit registered.
  Plain links, each keeping the other filters; catalog.js follows them
  without a reload.  Nothing when no types are registered. }
function TypeLinks(ARequest: TRequest): string;

  function Tab(const Name, Caption: string): string;
  var
    Mark: string;
  begin
    Mark := '';
    if Name = ARequest.QueryFields.Values['type'] then
      Mark := ' aria-current="page"';
    Result := '<a data-type="' + E(Name) + '"' + Mark + ' href="/catalog?type=' + E(HTTPEncode(Name)) + E(CatalogParams(ARequest, -1, 'type')) + '">' + E(Caption) + '</a>';
  end;

var
  I: integer;
begin
  Result := '';
  if Length(Types) = 0 then
    Exit;
  Result := '<nav class="catalog-types" aria-label="' + E(Say('Kind')) + '">' + Tab('', Say('All'));
  for I := 0 to High(Types) do
    Result := Result + Tab(Types[I].Name, CatalogCaption(Types[I].Name));
  Result := Result + '</nav>';
end;

procedure ShowCatalog(ARequest: TRequest; AResponse: TResponse);
var
  Answer: TJSONObject;
  Cards, Pages, Problem, MineLink, MineField, SourceField, StatusField, StatusHint: string;
  Sorts: TStringArray;
  I: integer;
  Me: TMember;
  Rater: boolean;
  Held: TInUse;
begin
  Problem := QueryProblem(ARequest);
  if Problem <> '' then
  begin
    SendText(AResponse, 400, Problem);
    Exit;
  end;
  CheckConnection;
  Answer := SearchCatalog(ARequest);
  try
    if ARequest.PathInfo = '/api/catalog' then
    begin
      SendJSON(AResponse, Answer.Clone);
      Exit;
    end;
    Me := CurrentMember(ARequest);
    Cards := '';
    Rater := (Me.Id > 0) and Me.Verified and not Me.Banned;
    for I := 0 to Answer.Arrays['items'].Count - 1 do
    begin
      if Rater then
        Answer.Arrays['items'].Objects[I].Add('can_rate', True);
      Cards := Cards + CatalogCard(Answer.Arrays['items'].Objects[I], CatalogParams(ARequest, -1, 'category'));
      // after the first few, once: what a visitor gains by joining
      if (I = 5) and (Me.Id = 0) and (Answer.Get('page', 0) = 0) then
        Cards := Cards + CatalogItemParts('join', nil, Me);
    end;
    MineLink := '';
    MineField := '';
    if Me.Id > 0 then
      if ARequest.QueryFields.Values['mine'] = '1' then
      begin
        MineLink := '<a class="catalog-mine" href="/catalog">' + E(Say('All entries')) + '</a>';
        MineField := '<input type="hidden" name="mine" value="1">';
      end
      else
        MineLink := '<a class="catalog-mine" href="/catalog?mine=1">' + E(Say('My ratings')) + '</a>';
    // more of the member's own pages (the packages they maintain)
    if Me.Id > 0 then
      MineLink := MineLink + CatalogTexts('top-links', 'member');
    if Cards = '' then
      Cards := '<p>' + E(Say('No entries match these filters.')) + '</p>'
    else if Answer.Get('similar', False) then
      Cards := '<p class="notice catalog-similar">' + E(Say('Nothing matched exactly. These names sound like it:')) + '</p>' + Cards;
    Pages := '';
    if Answer.Integers['page'] > 0 then
      Pages := '<a href="/catalog?' + E(CatalogParams(ARequest, Answer.Integers['page'] - 1)) + '">' + E(Say('Previous')) + '</a> ';
    if Answer.Booleans['more'] then
      Pages := Pages + '<a href="/catalog?' + E(CatalogParams(ARequest, Answer.Integers['page'] + 1)) + '">' + E(Say('Next')) + '</a>';
    // sources, states and stars are a code project's: offered when entries have them
    Held := InUse;
    SourceField := '';
    StatusField := '';
    StatusHint := '';
    Sorts := ['best', 'interest', 'rating', 'name'];
    if Held.Sources then
      SourceField := ChoiceField('source', Say('Source'), ARequest.QueryFields.Values['source'], CatalogChoices('source'));
    if Held.States then
    begin
      StatusField := ChoiceField('status', Say('Status'), ARequest.QueryFields.Values['status'], ['active', 'quiet', 'archived', 'unknown']);
      StatusHint := '<p class="hint">' + E(Say(
        'Active projects have a push in the last two years. Quiet projects have an older push. Projects without a push date have unknown status. Archived projects are marked separately.'))
        + '</p>';
      Sorts := ['best', 'interest', 'rating', 'recent', 'name'];
    end;
    if Held.Stars then
      Insert('stars', Sorts, 2);
    with ARequest.QueryFields do
      CatalogPage(ARequest, AResponse, Me, Say('Catalog'), FillTemplate('catalog', ['q', E(Values['q']), 'categories', CategoryOptions(Values['category']),
        'sources', CatalogOptions(CatalogChoices('source'), Values['source']), 'mine_link', MineLink, 'mine_field', MineField, 'types',
        TypeLinks(ARequest), 'type_value', E(Values['type']), 'open', OpenMark(ARequest), 'kinds', CatalogOptions(CatalogChoices('kind'), Values['kind']),
        'works', CatalogOptions(CatalogChoices('works_with'), Values['works_with']), 'works_field', ChoiceField('works_with', Say('Works with'),
        Values['works_with'], CatalogChoices('works_with')), 'kind_field', ChoiceField('kind', Say('Kind'), Values['kind'], KindChoices),
        'intro', E(CatalogIntro), 'statuses', CatalogOptions(['active', 'quiet', 'archived', 'unknown'], Values['status']), 'source_field',
        SourceField, 'status_field', StatusField, 'status_hint', StatusHint, 'sorts', CatalogOptions(Sorts, Values['sort'], False), 'cards',
        Cards, 'pages', Pages, 'total', E(StringReplace(SayCount(Answer.Integers['total'], '%d entry in the catalog.', '%d entries in the catalog.'),
        IntToStr(Answer.Integers['total']), Thousands(Answer.Integers['total']), []))]));
  finally
    Answer.Free;
  end;
end;

function Fact(const Caption, Text: string): string;
begin
  Result := '';
  if Text <> '' then
    Result := '<dt>' + E(Caption) + '</dt><dd dir="auto">' + E(Text) + '</dd>';
end;

{ The place a project lives: its address, the logo for that place (github,
  gitlab, codeberg, bitbucket, sourceforge, sourcehut, launchpad, gitea, or
  '' for its own website) and the place's name. }
procedure HostOf(Item: TJSONObject; out Address, Host, Logo, Place: string);
begin
  Address := ProjectAddress(Item);
  Host := LowerCase(ParseURI(Address).Host);
  if StartsText('www.', Host) then
    Delete(Host, 1, 4);
  Logo := '';
  Place := '';
  case Host of
    'github.com': begin
      Logo := 'github';
      Place := Say('GitHub');
    end;
    'gitlab.com': begin
      Logo := 'gitlab';
      Place := Say('GitLab');
    end;
    'codeberg.org': begin
      Logo := 'codeberg';
      Place := Say('Codeberg');
    end;
    'bitbucket.org': begin
      Logo := 'bitbucket';
      Place := Say('Bitbucket');
    end;
    'sourceforge.net': begin
      Logo := 'sourceforge';
      Place := Say('SourceForge');
    end;
    'sr.ht', 'git.sr.ht', 'hg.sr.ht': begin
      Logo := 'sourcehut';
      Place := Say('sourcehut');
    end;
    'launchpad.net', 'code.launchpad.net': begin
      Logo := 'launchpad';
      Place := Say('Launchpad');
    end;
  end;
  if Logo = '' then
    if EndsText('.sourceforge.net', Host) or EndsText('.sourceforge.io', Host) then
    begin
      Logo := 'sourceforge';
      Place := Say('SourceForge');
    end
    else if Item.Get('forge', '') = 'gitlab' then
    begin
      // another GitLab server: its logo, under its own name
      Logo := 'gitlab';
      Place := Host;
    end
    else if Item.Get('forge', '') = 'gitea' then
    begin
      Logo := 'gitea';
      Place := Host;
    end;
end;

{ The way to the project where it lives, as a button with that place's logo:
  View on GitHub, on GitLab, on Codeberg and so on, by the address's host;
  a project's own site gets a globe. }
function ViewOnButton(Item: TJSONObject): string;
var
  Address, Host, Logo, Place: string;
begin
  HostOf(Item, Address, Host, Logo, Place);
  Result := '';
  if Address = '' then
    Exit;
  if Logo = '' then
    Result := CatalogText('project-button', Address);
  if Result <> '' then
    Exit;
  if Logo = '' then
    Result := '<a class="button view-on" rel="nofollow ugc noopener" href="' + E(Address) + '"><span class="host-logo host-web" aria-hidden="true"></span>' +
      E(Say('Visit its website')) + '</a>'
  else
    Result := '<a class="button view-on" rel="nofollow ugc noopener" href="' + E(Address) + '"><span class="host-logo host-' + Logo +
      '" aria-hidden="true"></span>' + E(Format(Say('View on %s'), [Place])) + '</a>';
end;

{ What others think of a project, under its name: its stars where it lives,
  how many find it interesting, its members' rating; nothing when there is
  nothing yet. }
function EntryProof(Item: TJSONObject): string;
var
  Address, Host, Logo, Place, Rating, Status: string;
begin
  Result := '';
  HostOf(Item, Address, Host, Logo, Place);
  // active or quiet at a glance, with the last change it is judged by
  Status := Item.Get('status', '');
  if (Status = 'active') or (Status = 'quiet') or (Status = 'archived') then
  begin
    Result := '<li class="fact-status status-' + Status + '"><span class="status-dot" aria-hidden="true"></span>' + E(CatalogCaption(Status));
    if ShowDate(Item.Get('pushed', '')) <> '' then
      Result := Result + ' · ' + E(Format(Say('last change %s'), [ShowDate(Item.Get('pushed', ''))]));
    Result := Result + '</li>';
  end;
  if Item.Integers['stars'] > 0 then
    if Logo <> '' then
      Result := Result + '<li class="fact-stars"><span class="host-logo host-' + Logo + '" aria-hidden="true"></span>&#9733; ' +
        E(Format(Say('%s on %s'), [Thousands(Item.Integers['stars']), Place])) + '</li>'
    else
      Result := Result + '<li class="fact-stars">&#9733; ' + E(Thousands(Item.Integers['stars'])) + '</li>';
  if Item.Integers['interest'] > 0 then
    Result := Result + '<li class="fact-interest">' + StarIcon + ' ' + E(SayCount(Item.Integers['interest'], '%d finds this interesting', '%d find this interesting')) + '</li>';
  Rating := RatingSummary(Item.Integers['rating_count'], Item.Integers['rating_sum']);
  if Rating <> '' then
    Result := Result + '<li class="fact-rating">&#9733; ' + E(Rating) + '</li>';
  if Result <> '' then
    Result := '<ul class="card-facts entry-proof">' + Result + '</ul>';
end;

{ One step of discovering, kept for the admin's numbers: start,
  skip (Not for me), yes (Interesting, show me another), narrow (the kind or
  compiler chosen), press and unpress (the Interesting button elsewhere).
  hand is the page's script saying a person clicked; a crawler following
  the link does not send it, and a crawler's own name goes in bot. }
procedure NoteDiscovering(ARequest: TRequest; const Me: TMember; const Action: string; EntryId: integer; const Narrowing: string);
var
  Hand: integer;
begin
  Hand := 0;
  if (ARequest.QueryFields.Values['hand'] = '1') or (ARequest.ContentFields.Values['hand'] = '1') then
    Hand := 1;
  Exec('INSERT INTO catalog_actions (created, action, entry_id, who, member_id, hand, bot, local_net, narrowing)' + ' VALUES (' +
    SqlUtcNow + ', :a, :e, :w, :m, :h, :b, :l, :n)', [Action, EntryId, InterestWho(ARequest, Me), Me.Id, Hand, Copy(BotName(ARequest.UserAgent), 1, 64),
    Ord(PrivateAddress(ClientIp(ARequest))), Copy(Narrowing, 1, 32)]);
end;

function CatalogReadmeHtml(const Body: string): string;
begin
  Result := RenderReadme(Body, ImageHosts);
end;

{ A README as HTML, made again first when it was made by an older
  RenderReadme; '' when the entry has none. }
function RenderedReadme(Id: integer): string;
var
  Body: string;
begin
  Result := '';
  with Query('SELECT html, body, rendered FROM catalog_readmes WHERE entry_id = :e', [Id]) do
  try
    if EOF then
      Exit;
    Result := Fields[0].AsString;
    if Fields[2].AsInteger >= ReadmeRenderVersion then
      Exit;
    Body := Fields[1].AsString;
  finally
    Free;
  end;
  Result := CatalogReadmeHtml(Body);
  // a README saved again meanwhile keeps the HTML made with it
  Exec('UPDATE catalog_readmes SET html = :h, rendered = :r WHERE entry_id = :e AND body = :b', [Result, ReadmeRenderVersion, Id, Body]);
end;

{ The READMEs an older RenderReadme made, made again for up to half a
  minute each round: quick to catch up, and the other chores, which wait
  on the same thread, still get their turn every minute. }
procedure RenderOldReadmes;
var
  Ids: array of integer;
  I: integer;
  Stop: QWord;
  Last: integer;
begin
  if not PartOn('catalog') then
    Exit;
  Stop := GetTickCount64 + 30000;
  // onward by number, so one that cannot be made again is not taken twice
  Last := 0;
  repeat
    Ids := [];
    with Query('SELECT entry_id FROM catalog_readmes WHERE rendered < :r AND entry_id > :l ORDER BY entry_id LIMIT 100', [ReadmeRenderVersion, Last]) do
    try
      while not EOF do
      begin
        Ids := Concat(Ids, [Fields[0].AsInteger]);
        Next;
      end;
    finally
      Free;
    end;
    for I := 0 to High(Ids) do
    begin
      RenderedReadme(Ids[I]);
      Last := Ids[I];
      if GetTickCount64 > Stop then
        Exit;
    end;
  until Length(Ids) = 0;
end;

{ Old steps go; a year and a month is enough to compare with. }
procedure ForgetOldSteps;
begin
  Exec('DELETE FROM catalog_actions WHERE created < ' + SqlMinus('UTC_DATE()', '400', suDay), []);
end;

{ The facts about an entry, as the rows of a list: only what is known.  The
  ones about a code host (owner, pushes, releases, stars) show for entries
  that have them. }
function EntryFacts(Item: TJSONObject; const Me: TMember): string;

  // a choice left at its empty value says nothing
  function Known(const Field, Empty: string): string;
  begin
    Result := '';
    if Item.Strings[Field] <> Empty then
      Result := CatalogCaption(Item.Strings[Field]);
  end;

begin
  Result := Fact(Say('Name'), Item.Strings['name']) + Fact(Say('Address'), IfThen(ProjectAddress(Item) = '', '', Item.Strings['entry_key'])) +
    Fact(Say('Kind'), Known('kind', 'unknown')) + CatalogItemParts('works-fact', Item, Me) + Fact(Say('Forge'), Known('forge', 'web')) +
    Fact(Say('Owner'), Item.Strings['owner']) + Fact(Say('Status'), Known('status', 'unknown')) + Fact(Say('Version'), Item.Strings['version']) +
    Fact(Say('Authors'), Item.Strings['authors']) + Fact(Say('License'), Item.Strings['license']) + CatalogItemParts('version-facts', Item, Me) +
    Fact(Say('Created'), ShowDate(Item.Strings['created'])) + Fact(Say('Last pushed'), ShowDate(Item.Strings['pushed'])) +
    Fact(Say('Latest release'), Item.Strings['release_name']) + Fact(Say('Released'), ShowDate(Item.Strings['released']));
  // when an import last brought it; an entry put in by hand has no such day
  if Item.Get('sources', '') <> '' then
    Result := Result + Fact(Say('Last seen (UTC)'), Item.Strings['seen']);
  if Item.Integers['stars'] > 0 then
    if Item.Strings['forge'] = 'github' then
      Result := Result + Fact(Say('GitHub stars'), IntToStr(Item.Integers['stars']))
    else
      Result := Result + Fact(Say('Stars'), IntToStr(Item.Integers['stars']));
  if Item.Integers['forks'] > 0 then
    Result := Result + Fact(Say('Forks'), IntToStr(Item.Integers['forks']));
  Result := Result + CatalogItemParts('count-facts', Item, Me);
end;

function EntryActions(Item: TJSONObject; Id: integer): string;
var
  Part: string;
begin
  // where it lives and Interesting first, where the eye lands
  Result := '<div class="catalog-actions">' + ViewOnButton(Item);
  if CatalogURL(Item.Strings['download_url']) then
  begin
    Part := CatalogText('download', Item.Strings['download_url']);
    if Part = '' then
      Part := Say('Download');
    Result := Result + ' <a class="button download-button" rel="nofollow ugc noopener" href="' + E(Item.Strings['download_url']) +
      '"><span aria-hidden="true">&#8595;</span> ' + E(Part) + '</a>';
  end;
  // no account needed, and pressing it shows that; the button's own title says what it does
  Result := Result + InterestForm(Id, Item.Integers['interest'], Item.Booleans['my_interest']) + '</div>';
end;

function EntryRating(Item: TJSONObject; Id: integer; const Me: TMember): string;
var
  Summary: string;
begin
  Summary := RatingSummary(Item.Integers['rating_count'], Item.Integers['rating_sum']);
  if Summary = '' then
    Summary := Say('No ratings yet.');
  Result := '<section class="catalog-rating"><h2>' + E(Say('Member rating')) + '</h2><p class="catalog-rating-text" data-rating-summary="' +
    IntToStr(Id) + '" data-none="' + E(Say('No ratings yet.')) + '">' + E(Summary) + '</p>';
  if Me.Id = 0 then
    Result := Result + '<p><a href="/signin?return=/catalog/' + IntToStr(Id) + '">' + E(Say('Sign in to rate this entry.')) + '</a></p>'
  else if Me.Verified and not Me.Banned then
    Result := Result + RateForm(Id, Item.Integers['my_rating']);
  Result := Result + '</section>';
end;

procedure EntryPage(ARequest: TRequest; AResponse: TResponse);
var
  ReadmeTitle: string;
  Item: TJSONObject;
  Me: TMember;
  Main, Facts, TitleText, Part, SourceLinks, Topics, Labels, Readme, Arrive: string;
  Id: integer;
begin
  // The router also matches the bare path for a parameter route.
  if (ARequest.PathInfo = '/catalog') or (ARequest.PathInfo = '/catalog/') then
  begin
    ShowCatalog(ARequest, AResponse);
    Exit;
  end;
  CheckConnection;
  Id := StrToIntDef(ARequest.RouteParams['id'], 0);
  Me := CurrentMember(ARequest);
  RequestInterestWho := InterestWho(ARequest, Me);
  // who looks after the catalog sees a hidden entry too, to decide about it
  Item := ReadEntry(Id, Me.Id, Can(Me, 'view-catalog'));
  if Item = nil then
  begin
    SendText(AResponse, 404, Say('No entry by that number.'));
    Exit;
  end;
  try
    TitleText := EntryTitle(Item);
    Arrive := '';
    if (ARequest.QueryFields.Values['discover'] = '1') and ((ARequest.QueryFields.Values['came'] = 'yes') or (ARequest.QueryFields.Values['came'] = 'no')) then
      Arrive := ' arrive-' + ARequest.QueryFields.Values['came'];
    // the way back and the choice of what comes next on one line, the two
    // answers under it; outside the entry, so they stay while it moves
    Main := '<div class="directory catalog-top"><div class="catalog-crumbs"><a href="/catalog">' + E(Say('Catalog')) + '</a> · <a href="/catalog-how">' +
      E(Say('How the catalog works')) + '</a>' + DiscoverNarrow(ARequest, Id) + '</div>' + DiscoverBar(ARequest, Id) +
      '</div><section class="directory catalog-entry' + Arrive + '"><h1 class="catalog-named" dir="auto">' + CatalogIcon(Item.Strings['icon'],
      Item.Strings['forge'], Item.Strings['owner'], TitleText) + E(TitleText) + '</h1><p class="catalog-summary" dir="auto">' + E(Item.Strings['summary']) + '</p>';
    if Item.Strings['picture'] <> '' then
      Main := Main + '<p class="catalog-picture"><img alt="" src="' + E(Item.Strings['picture']) + '"></p>';
    Main := Main + EntryProof(Item);
    Main := Main + EntryActions(Item, Id);
    Main := Main + CatalogItemParts('after-actions', Item, Me);
    Main := Main + EntryRating(Item, Id, Me);
    Facts := EntryFacts(Item, Me);
    Readme := RenderedReadme(Id);
    if Readme <> '' then
    begin
      // SourceForge projects have no README file: what shows is the project's own description there
      if Item.Get('forge', '') = 'sourceforge' then
        ReadmeTitle := Say('About this project, from SourceForge')
      else
        ReadmeTitle := Say('README');
      Main := Main + '<div class="catalog-entry-grid"><div class="catalog-readme" dir="auto"><h2>' + E(ReadmeTitle) + '</h2>' + Readme + '</div><aside class="catalog-side">';
    end;
    Main := Main + '<dl class="catalog-facts">' + Facts + '</dl><p class="catalog-categories">' + CategoryLinks(Item, '') + '</p>';
    Main := Main + CatalogItemParts('after-facts', Item, Me);
    Topics := '';
    Labels := Item.Strings['topics'];
    for Part in Labels.Split([','], TStringSplitOptions.ExcludeEmpty) do
      Topics := Topics + '<a href="/catalog?q=' + E(HTTPEncode(Trim(Part))) + '">' + E(Trim(Part)) + '</a> ';
    if Topics <> '' then
      Main := Main + '<p>' + E(Say('Topics')) + ': ' + Topics + '</p>';
    SourceLinks := '';
    Labels := Item.Strings['sources'];
    for Part in Labels.Split([','], TStringSplitOptions.ExcludeEmpty) do
      SourceLinks := SourceLinks + '<a href="/catalog?source=' + E(HTTPEncode(Part)) + '">' + E(CatalogCaption(Part)) + '</a> ';
    if SourceLinks <> '' then
      Main := Main + '<p>' + E(Say('Found by')) + ': ' + SourceLinks + '</p>';
    Main := Main + CatalogItemParts('talk', Item, Me);
    if Assigned(CatalogEntryPart) then
      Main := Main + EntryBottom(ARequest, Id, Me)
    else
      Main := Main + CatalogItemParts('contact', Item, Me);
    // hidden from readers: said to who can still see it, with the way to show it again
    if Item.Get('hidden', 0) = 1 then
      Main := Main + '<p class="notice">' + E(Say('This entry is hidden: only those who look after the catalog see it.')) + '</p>';
    if Can(Me, 'edit-catalog') then
      Main := Main + '<form method="post" action="/api/catalog/hide"><input type="hidden" name="id" value="' + IntToStr(Id) +
        '"><input type="hidden" name="hidden" value="' + IntToStr(1 - Item.Get('hidden', 0)) + '"><button type="submit">' +
        E(IfThen(Item.Get('hidden', 0) = 1, Say('Unhide'), Say('Hide'))) + '</button></form>';
    Main := Main + CatalogItemParts('admin-actions', Item, Me);
    if Readme <> '' then
      Main := Main + '</aside></div>';
    CatalogPage(ARequest, AResponse, Me, TitleText, Main + '</section>');
  finally
    Item.Free;
  end;
end;

{ GET /catalog/:id/badge  a small picture for a project's README, in the
  manner of the shields people put there: the site, then how many find
  it interesting and its members' rating.  Only numbers go in, never the
  project's own words. }
function BadgeSvg(Interest, RatingCount, RatingSum: integer): string;
var
  Left, Right: string;
  LeftWidth, RightWidth: integer;
begin
  Left := CatalogText('badge-name');
  if Left = '' then
    Left := Setting('name', 'Exedra');
  if (Interest = 0) and (RatingCount = 0) then
    Right := 'in the catalog'
  else
  begin
    Right := '';
    if Interest > 0 then
      Right := '&#10022; ' + IntToStr(Interest) + ' interesting';
    if RatingCount > 0 then
    begin
      if Right <> '' then
        Right := Right + '  ';
      Right := Right + '&#9733; ' + CatalogAverage(RatingCount, RatingSum);
    end;
  end;
  LeftWidth := 12 + Length(Left) * 7;
  // an entity counts as one character
  RightWidth := 14 + (Length(Right) - 6 * (Length(Right) - Length(StringReplace(Right, '&#', '', [rfReplaceAll]))) div 2) * 7;
  Result := '<svg xmlns="http://www.w3.org/2000/svg" width="' + IntToStr(LeftWidth + RightWidth) + '" height="20" role="img" aria-label="' +
    E(Left) + '">' + '<linearGradient id="s" x2="0" y2="100%"><stop offset="0" stop-color="#fff" stop-opacity=".1"/><stop offset="1" stop-opacity=".1"/></linearGradient>' +
    '<clipPath id="r"><rect width="' + IntToStr(LeftWidth + RightWidth) + '" height="20" rx="3"/></clipPath><g clip-path="url(#r)">' +
    '<rect width="' + IntToStr(LeftWidth) + '" height="20" fill="#0b0f16"/><rect x="' + IntToStr(LeftWidth) + '" width="' + IntToStr(RightWidth) +
    '" height="20" fill="#0f9d8f"/><rect width="' + IntToStr(LeftWidth + RightWidth) + '" height="20" fill="url(#s)"/></g>' +
    '<g fill="#fff" font-family="Verdana,DejaVu Sans,sans-serif" font-size="11"><text x="6" y="14">' + E(Left) + '</text><text x="' +
    IntToStr(LeftWidth + 7) + '" y="14">' + Right + '</text></g></svg>';
end;

procedure ShowBadge(ARequest: TRequest; AResponse: TResponse);
var
  Id, Interest, RatingCount, RatingSum: integer;
begin
  CheckConnection;
  Id := StrToIntDef(ARequest.RouteParams['id'], 0);
  Interest := 0;
  RatingCount := 0;
  RatingSum := 0;
  with Query('SELECT interest, rating_count, rating_sum FROM catalog_entries WHERE id = :i AND hidden = 0', [Id]) do
  try
    if EOF then
    begin
      SendText(AResponse, 404, Say('No entry by that number.'));
      Exit;
    end;
    Interest := Fields[0].AsInteger;
    RatingCount := Fields[1].AsInteger;
    RatingSum := Fields[2].AsInteger;
  finally
    Free;
  end;
  AResponse.ContentType := 'image/svg+xml; charset=utf-8';
  AResponse.SetCustomHeader('Cache-Control', 'public, max-age=3600');
  AResponse.Content := BadgeSvg(Interest, RatingCount, RatingSum);
  AResponse.SendContent;
end;

{ GET /api/catalog/:id/readme: a visible project's README as it was read,
  for programs that show it themselves. }
procedure ShowReadme(ARequest: TRequest; AResponse: TResponse);
var
  Id: integer;
begin
  CheckConnection;
  Id := StrToIntDef(ARequest.RouteParams['id'], 0);
  if IntValue('SELECT COUNT(*) FROM catalog_entries WHERE id = :i AND hidden = 0', [Id]) = 0 then
  begin
    SendText(AResponse, 404, Say('No entry by that number.'));
    Exit;
  end;
  with Query('SELECT body, url, ' + IsoTime('fetched') + ' FROM catalog_readmes WHERE entry_id = :e', [Id]) do
  try
    if EOF then
      SendJSON(AResponse, TJSONObject.Create(['markdown', '', 'url', '', 'fetched', '']))
    else
      SendJSON(AResponse, TJSONObject.Create(['markdown', Fields[0].AsString, 'url', Fields[1].AsString, 'fetched', Fields[2].AsString]));
  finally
    Free;
  end;
end;

{ GET /catalog-count.json: public counts, readable from any site. }
procedure ShowCount(ARequest: TRequest; AResponse: TResponse);
var
  Answer: TJSONObject;
  I: integer;
begin
  CheckConnection;
  Answer := TJSONObject.Create(['projects', IntValue('SELECT visible FROM catalog_totals WHERE id = 1', [])]);
  try
    for I := 0 to High(CountParts) do
      CountParts[I].Make(Answer);
    AResponse.ContentType := 'application/json; charset=utf-8';
    AResponse.SetCustomHeader('Cache-Control', 'public, max-age=600');
    AResponse.SetCustomHeader('Access-Control-Allow-Origin', '*');
    AResponse.Content := Answer.AsJSON;
    AResponse.SendContent;
  finally
    Answer.Free;
  end;
end;

{ POST /catalog/:id/interest  anyone, member or not: this looks interesting,
  or, pressed again, not after all.  Answers JSON to a script, and otherwise
  goes back to the entry.  A form on another site may not press it for its
  visitors: a browser names the page's origin, and it must be this site. }
procedure PressInterest(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Id, Count: integer;
  Who, Action: string;
  Mine: boolean;
begin
  CheckConnection;
  Me := CurrentMember(ARequest);
  if Me.Banned then
  begin
    SendText(AResponse, 403, Say('This account cannot do that.'));
    Exit;
  end;
  if FromAnotherSite(ARequest) then
  begin
    SendText(AResponse, 403, Say('Press it on this site.'));
    Exit;
  end;
  Who := InterestWho(ARequest, Me);
  if not AllowAttempt(Who, 'catintr', SettingInt('catintr_hour', 120), 60) then
  begin
    AResponse.SetCustomHeader('Retry-After', '3600');
    SendText(AResponse, 429, Say('That is a lot of presses in one hour. Try again later.'));
    Exit;
  end;
  Id := StrToIntDef(ARequest.RouteParams['id'], 0);
  Exec('START TRANSACTION', []);
  try
    // The entry's row is the lock, so the count cannot drift.
    if IntValue('SELECT id FROM catalog_entries WHERE id = :i AND hidden = 0 FOR UPDATE', [Id]) = 0 then
    begin
      Exec('ROLLBACK', []);
      SendText(AResponse, 404, Say('No entry by that number.'));
      Exit;
    end;
    Mine := IntValue('SELECT COUNT(*) FROM catalog_interest WHERE entry_id = :e AND who = :w', [Id, Who]) = 0;
    // from discovering: interesting, then the next one; never taken back
    Action := 'yes';
    if (ARequest.ContentFields.Values['then'] = 'next') and not Mine then
      Mine := True
    else if Mine then
    begin
      Exec('INSERT INTO catalog_interest (entry_id, who, created) VALUES (:e, :w, ' + SqlUtcNow + ')', [Id, Who]);
      Action := 'press';
    end
    else
    begin
      Exec('DELETE FROM catalog_interest WHERE entry_id = :e AND who = :w', [Id, Who]);
      Action := 'unpress';
    end;
    if ARequest.ContentFields.Values['then'] = 'next' then
      Action := 'yes';
    NoteDiscovering(ARequest, Me, Action, Id, NarrowingOf(ARequest.ContentFields.Values['type'], ARequest.ContentFields.Values['works']));
    Count := IntValue('SELECT COUNT(*) FROM catalog_interest WHERE entry_id = :e', [Id]);
    Exec('UPDATE catalog_entries SET interest = :c WHERE id = :i', [Count, Id]);
    Exec('COMMIT', []);
  except
    Exec('ROLLBACK', []);
    raise;
  end;
  if ARequest.ContentFields.Values['then'] = 'next' then
  begin
    SeeOther(AResponse, '/catalog-random?from=' + IntToStr(Id) + '&came=yes' + NextCarry(ARequest));
  end
  else if Pos('application/json', ARequest.Accept) > 0 then
    SendJSON(AResponse, TJSONObject.Create(['interest', Count, 'mine', Mine]))
  else
  begin
    SeeOther(AResponse, '/catalog/' + IntToStr(Id));
  end;
end;

{ POST /catalog/:id/rate  stars 1 to 5, or 0 to take the rating back.  The same
  stars again also takes it back.  Answers JSON to a script, and otherwise goes
  back to the entry. }
procedure RateEntry(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Id, Stars, Before, Count, Sum: integer;
begin
  CheckConnection;
  if FromAnotherSite(ARequest) then
  begin
    SendText(AResponse, 403, Say('Press it on this site.'));
    Exit;
  end;
  if not NeedMember(ARequest, AResponse, Me) then
    Exit;
  Id := StrToIntDef(ARequest.RouteParams['id'], 0);
  Stars := StrToIntDef(ARequest.ContentFields.Values['stars'], -1);
  if (Stars < 0) or (Stars > 5) then
  begin
    SendText(AResponse, 400, Say('A rating is 1 to 5 stars.'));
    Exit;
  end;
  Exec('START TRANSACTION', []);
  try
    // The entry's row is the lock, so the two counts cannot drift.
    if IntValue('SELECT id FROM catalog_entries WHERE id = :i AND hidden = 0 FOR UPDATE', [Id]) = 0 then
    begin
      Exec('ROLLBACK', []);
      SendText(AResponse, 404, Say('No entry by that number.'));
      Exit;
    end;
    Before := IntValue('SELECT COALESCE(MAX(stars), 0) FROM catalog_ratings WHERE entry_id = :e AND user_id = :u', [Id, Me.Id]);
    if Stars = Before then
      Stars := 0;
    if Stars = 0 then
      Exec('DELETE FROM catalog_ratings WHERE entry_id = :e AND user_id = :u', [Id, Me.Id])
    else
      Exec('INSERT INTO catalog_ratings (entry_id, user_id, stars, updated) VALUES (:e, :u, :s, ' + SqlUtcNow + ')' +
        SqlOnConflict('entry_id, user_id', 'stars = ' + SqlNew('stars') + ', updated = ' + SqlNew('updated')), [Id, Me.Id, Stars]);
    Count := IntValue('SELECT COUNT(*) FROM catalog_ratings WHERE entry_id = :e', [Id]);
    Sum := IntValue('SELECT COALESCE(SUM(stars), 0) FROM catalog_ratings WHERE entry_id = :e', [Id]);
    Exec('UPDATE catalog_entries SET rating_count = :c, rating_sum = :s WHERE id = :i', [Count, Sum, Id]);
    Exec('COMMIT', []);
  except
    Exec('ROLLBACK', []);
    raise;
  end;
  if Pos('application/json', ARequest.Accept) > 0 then
    SendJSON(AResponse, TJSONObject.Create(['count', Count, 'average', CatalogAverage(Count, Sum), 'mine', Stars, 'summary', RatingSummary(Count, Sum)]))
  else
  begin
    SeeOther(AResponse, '/catalog/' + IntToStr(Id));
  end;
end;

{ The pictures the catalog keeps: files under <files>/catalog-images, served
  at /catalog-images/<path>, put there by its tools. }
procedure ServeCatalogImages;
begin
  if DirectoryExists(FilesRoot + 'catalog-images') then
    ServeFolder('catalog-images', FilesRoot + 'catalog-images');
end;

{ GET /catalog-how  how the catalog is made and ordered, and how anyone can
  help: ratings, Interesting, discovering, reports. }
procedure ShowHow(ARequest: TRequest; AResponse: TResponse);

  function Part(const Anchor, Heading: string; const Lines: array of string): string;
  var
    Line: string;
  begin
    Result := '<h2 id="' + Anchor + '">' + E(Heading) + '</h2>';
    for Line in Lines do
      if Line <> '' then
        Result := Result + '<p>' + E(Line) + '</p>';
  end;

  // a site's own words for a part (RegisterCatalogText), or these
  function Words(const Name, Plain: string): string;
  begin
    Result := CatalogText(Name);
    if Result = '' then
      Result := Plain;
  end;

var
  Me: TMember;
  Who: string;
begin
  CheckConnection;
  Me := CurrentMember(ARequest);
  Who := 'other';
  if Me.Id = 0 then
    Who := 'guest'
  else if Me.Verified and not Me.Banned then
    Who := 'member';
  CatalogPage(ARequest, AResponse, Me, Say('How the catalog works'), '<section class="directory catalog-how"><p><a href="/catalog">' +
    E(Say('Catalog')) + '</a> · <a href="/catalog-random">' + E(Say('Random entry')) + '</a></p><h1>' + E(Say('How the catalog works')) +
    '</h1>' + Part('sources', Say('Where the entries come from'),
    [Words('how-sources', Say('The people who look after this site add the entries, one at a time or many at once.')),
    Say('Some may be in the wrong place, and some may not belong at all. People here put that right.')]) + Part('ratings', Say('Member ratings'),
    [Say('Signed-in members rate entries from one to five stars. Ratings count most: an entry members rate well comes before any number of stars on a code host.')]) +
    Part('interesting', Say('Interesting'), [Say(
    'Anyone may press Interesting on an entry, signed in or not, once per entry. It says "worth a look" and moves the entry up for everyone.'),
    Say('Interesting counts more than stars on a code host, and less than member ratings. Press it again to take it back.')]) +
    Part('discover', Say('Discovering entries'), [Say(
    'Random entry shows one entry at a time. Interesting, show me another counts your Interesting and moves on. Not for me, show me another just moves on.'),
    Say('Not for me counts against nothing: an entry nobody has found yet is not pushed down for it. On a keyboard the left and right arrows do the same.')]) +
    Part('order', Say('The order of the list'), [Say(
    'First the entries members rated, best first; then the rest by what visitors found interesting and, for code, their stars on the code host. A search puts the best match first.')]) + Part('reports', Say('Something that does not belong'),
    [Words('how-reports', Say('A signed-in member can report an entry that does not belong, on the entry''s page. When several members report one, it is hidden until an admin looks.'))]) +
    Part('yours', Say('Is it yours?'), [Say('If an entry is yours and something about it is wrong, or you want it taken out, tell the people who run this site.')]) +
    Part('privacy', Say('What is kept'), [Say(
    'A rating or report is kept with your account. For Interesting from someone not signed in only a scrambled form of their address is kept, never the address itself.')]) +
    CatalogTexts('how-more', Who) + '</section>');
end;

{ GET /catalog-random?from=N  any one project, shown for discovering: not
  the one just seen and not one this visitor already finds interesting }
procedure ShowRandomEntry(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Id: integer;
  Came, Where, Carry, Action: string;
begin
  CheckConnection;
  Me := CurrentMember(ARequest);
  DiscoverChoice(ARequest, Where, Carry);
  // the step that brought the reader here; after Interesting it is kept already
  if ARequest.QueryFields.Values['came'] <> 'yes' then
  begin
    if ARequest.QueryFields.Values['do'] = 'narrow' then
      Action := 'narrow'
    else if (ARequest.QueryFields.Values['came'] = 'no') and (ARequest.QueryFields.Values['do'] <> 'start') then
      Action := 'skip'
    else
      Action := 'start';
    NoteDiscovering(ARequest, Me, Action, StrToIntDef(ARequest.QueryFields.Values['from'], 0),
      NarrowingOf(ARequest.QueryFields.Values['type'], ARequest.QueryFields.Values['works']));
  end;
  // came=yes or no: the reader's last answer, so the next project can arrive
  // the way that fits (DiscoverBar and its styles)
  Came := '';
  if (ARequest.QueryFields.Values['came'] = 'yes') or (ARequest.QueryFields.Values['came'] = 'no') then
    Came := '&came=' + ARequest.QueryFields.Values['came'];
  Id := IntValue('SELECT id FROM catalog_entries WHERE hidden = 0 AND id <> :f AND id NOT IN' + ' (SELECT entry_id FROM catalog_interest WHERE who = :w)' +
    Where + ' ORDER BY RAND() LIMIT 1', [StrToIntDef(ARequest.QueryFields.Values['from'], 0), InterestWho(ARequest, Me)]);
  if Id > 0 then
    SeeOther(AResponse, '/catalog/' + IntToStr(Id) + '?discover=1' + Came + Carry)
  else
    SeeOther(AResponse, '/catalog');
end;

procedure HideEntry(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Id, Hidden, WasHidden: integer;
begin
  if not NeedPermission(ARequest, AResponse, 'edit-catalog', Me) then
    Exit;
  Id := StrToIntDef(ARequest.ContentFields.Values['id'], 0);
  Hidden := StrToIntDef(ARequest.ContentFields.Values['hidden'], -1);
  if (Id < 1) or not (Hidden in [0, 1]) then
  begin
    SendText(AResponse, 400, Say('Choose an entry and whether to hide it.'));
    Exit;
  end;
  Exec('START TRANSACTION', []);
  try
    IntValue('SELECT visible FROM catalog_totals WHERE id = 1 FOR UPDATE', []);
    WasHidden := -1;
    with Query('SELECT hidden FROM catalog_entries WHERE id = :i FOR UPDATE', [Id]) do
    try
      if not EOF then
        WasHidden := Fields[0].AsInteger;
    finally
      Free;
    end;
    if WasHidden = -1 then
    begin
      Exec('ROLLBACK', []);
      SendText(AResponse, 404, Say('No entry by that number.'));
      Exit;
    end;
    if WasHidden <> Hidden then
    begin
      // the note says who hid it, and goes when it is shown again
      if Hidden = 1 then
        Exec('UPDATE catalog_entries SET hidden = 1, hidden_note = :n WHERE id = :i', [Format('Hidden by %s', [Me.Name]), Id])
      else
        Exec('UPDATE catalog_entries SET hidden = 0, hidden_note = NULL WHERE id = :i', [Id]);
      Exec('UPDATE catalog_totals SET visible = visible + :d WHERE id = 1', [WasHidden - Hidden]);
      Log(Me.Name + IfThen(Hidden = 1, ' hid', ' showed') + ' catalog entry ' + IntToStr(Id));
      CatalogEntryHidden(Id);
    end;
    // shown again by an admin: the reports that hid it are answered
    if Hidden = 0 then
      Exec('UPDATE catalog_reports SET resolved = 1 WHERE entry_id = :e AND resolved = 0', [Id]);
    Exec('COMMIT', []);
  except
    Exec('ROLLBACK', []);
    raise;
  end;
  CatalogEntriesChanged;
  SeeOther(AResponse, '/catalog');
end;

{ The catalog's card on the home page: the entries last added. }
function CatalogHomeCard: string;
var
  Rows: string;
begin
  Result := '';
  if not PartOn('catalog') then
    Exit;
  Rows := '';
  with Query('SELECT id, COALESCE(NULLIF(title, ''''), name), summary FROM catalog_entries WHERE hidden = 0 ORDER BY id DESC LIMIT 5', []) do
  try
    while not EOF do
    begin
      Rows := Rows + HomeRow('/catalog/' + Fields[0].AsString, Fields[1].AsString, E(Copy(Fields[2].AsString, 1, 80)));
      Next;
    end;
  finally
    Free;
  end;
  Result := HomeCard(Say('Catalog'), '/catalog', Rows, Say('No entries yet.'));
end;

function CatalogLink: string;
begin
  Result := '<a href="/catalog">' + E(Say('Catalog')) + '</a>';
end;

initialization
  { The fields of an entry.  The number is the field's place in a row of an
    import and in what /api/catalog answers, so the places stay as they are;
    a site's own unit takes free places for its own fields. }
  RegisterCatalogField(0, 'entry_key', 190, cfText);
  RegisterCatalogField(1, 'name', 200, cfText);
  RegisterCatalogField(2, 'title', 300, cfText);
  RegisterCatalogField(3, 'summary', 60000, cfText);
  RegisterCatalogField(4, 'url', 2048, cfText);
  RegisterCatalogField(5, 'forge', 20, cfText);
  RegisterCatalogField(6, 'owner', 200, cfText);
  RegisterCatalogField(7, 'kind', 20, cfText);
  RegisterCatalogField(8, 'categories', 200, cfText);
  RegisterCatalogField(10, 'license', 60, cfText);
  RegisterCatalogField(11, 'stars', 0, cfNumber);
  RegisterCatalogField(12, 'forks', 0, cfNumber);
  RegisterCatalogField(13, 'created', 0, cfDate);
  RegisterCatalogField(14, 'pushed', 0, cfDate);
  RegisterCatalogField(15, 'archived', 0, cfBoolean);
  RegisterCatalogField(16, 'release_name', 80, cfText);
  RegisterCatalogField(17, 'released', 0, cfDate);
  RegisterCatalogField(18, 'topics', 500, cfText);
  RegisterCatalogField(21, 'download_url', 2048, cfText);
  RegisterCatalogField(22, 'version', 40, cfText);
  RegisterCatalogField(23, 'authors', 300, cfText);
  RegisterCatalogField(31, 'sources', 100, cfText);
  RegisterCatalogField(32, 'seen', 0, cfTime);
  RegisterCatalogField(33, 'hidden', 0, cfNumber);
  RegisterCatalogField(34, 'room_id', 0, cfNumber);
  RegisterCatalogField(35, 'id', 0, cfNumber);
  RegisterCatalogKept('kind', 'admin_set = 1');
  RegisterCatalogKept('works_with', 'admin_set = 1');
  RegisterCatalogKept('categories', 'admin_set = 1');
  // and the words an admin wrote
  RegisterCatalogKept('title', 'words_set = 1');
  RegisterCatalogKept('url', 'words_set = 1');
  RegisterCatalogKept('summary', 'words_set = 1');
  RegisterCatalogKept('license', 'words_set = 1');
  RegisterCatalogChoices('forge', ['github', 'gitlab', 'codeberg', 'bitbucket', 'sourceforge', 'web', 'gitea', 'sourcehut', 'launchpad']);
  RegisterCatalogChoices('source', ['github', 'gitlab', 'codeberg', 'sourceforge']);

  { The tables, then what was added to them later, in the order it was added. }
  RegisterTable('CREATE TABLE IF NOT EXISTS catalog_entries (' + ' id INT AUTO_INCREMENT PRIMARY KEY, entry_key VARCHAR(190) NOT NULL UNIQUE,' +
    ' name VARCHAR(200) NOT NULL, title VARCHAR(300) NOT NULL DEFAULT '''', summary TEXT NOT NULL DEFAULT '''',' +
    ' url VARCHAR(2048) NOT NULL DEFAULT '''', forge VARCHAR(20) NOT NULL DEFAULT ''web'',' +
    ' owner VARCHAR(200) NOT NULL DEFAULT '''', kind VARCHAR(20) NOT NULL DEFAULT ''unknown'',' +
    ' categories VARCHAR(200) NOT NULL DEFAULT '''', works_with VARCHAR(20) NOT NULL DEFAULT ''unknown'',' +
    ' license VARCHAR(60) NOT NULL DEFAULT '''', stars INT NOT NULL DEFAULT 0, forks INT NOT NULL DEFAULT 0,' +
    ' created DATE NULL, pushed DATE NULL, archived TINYINT NOT NULL DEFAULT 0,' +
    ' release_name VARCHAR(80) NOT NULL DEFAULT '''', released DATE NULL, topics VARCHAR(500) NOT NULL DEFAULT '''',' +
    ' download_url VARCHAR(2048) NOT NULL DEFAULT '''',' + ' version VARCHAR(40) NOT NULL DEFAULT '''', authors VARCHAR(300) NOT NULL DEFAULT '''',' +
    ' repository_date DATE NULL,' + ' sources VARCHAR(100) NOT NULL DEFAULT '''', seen DATETIME NOT NULL, hidden TINYINT NOT NULL DEFAULT 0,' +
    ' room_id INT NULL, FULLTEXT(title, summary, topics), INDEX(kind), INDEX(stars), INDEX(pushed),' +
    ' INDEX(repository_date), INDEX(hidden, name), INDEX(room_id)) ENGINE=InnoDB CHARACTER SET utf8mb4');
  RegisterTable('CREATE TABLE IF NOT EXISTS catalog_totals (' + ' id TINYINT PRIMARY KEY, visible INT NOT NULL DEFAULT 0) ENGINE=InnoDB CHARACTER SET utf8mb4');
  RegisterUpgrade('catalog-total', 'INSERT INTO catalog_totals (id, visible)' +
    ' SELECT 1, COUNT(*) FROM catalog_entries WHERE hidden = 0 ON DUPLICATE KEY UPDATE visible = VALUES(visible)');
  RegisterTable('CREATE TABLE IF NOT EXISTS catalog_ratings (' + ' entry_id INT NOT NULL, user_id INT NOT NULL, stars TINYINT NOT NULL, updated DATETIME NOT NULL,' +
    ' PRIMARY KEY (entry_id, user_id), INDEX (user_id)) ENGINE=InnoDB CHARACTER SET utf8mb4');
  RegisterUpgrade('catalog-interest-column', 'ALTER TABLE catalog_entries ADD COLUMN interest INT NOT NULL DEFAULT 0');
  RegisterTable('CREATE TABLE IF NOT EXISTS catalog_interest (entry_id INT NOT NULL, who VARCHAR(48) NOT NULL, created DATETIME NOT NULL,' +
    ' PRIMARY KEY (entry_id, who)) ENGINE=InnoDB CHARACTER SET ascii');
  RegisterTable('CREATE TABLE IF NOT EXISTS catalog_actions (id BIGINT AUTO_INCREMENT PRIMARY KEY, created DATETIME NOT NULL,' +
    ' action VARCHAR(8) NOT NULL, entry_id INT NOT NULL DEFAULT 0, who VARCHAR(48) NOT NULL, member_id INT NOT NULL DEFAULT 0,' +
    ' hand TINYINT NOT NULL DEFAULT 0, bot VARCHAR(64) NOT NULL DEFAULT '''', local_net TINYINT NOT NULL DEFAULT 0,' +
    ' narrowing VARCHAR(32) NOT NULL DEFAULT '''', INDEX (created), INDEX (who)) ENGINE=InnoDB CHARACTER SET utf8mb4');
  RegisterUpgrade('catalog-admin-set', 'ALTER TABLE catalog_entries ADD COLUMN admin_set TINYINT NOT NULL DEFAULT 0');
  RegisterUpgrade('catalog-words-set', 'ALTER TABLE catalog_entries ADD COLUMN words_set TINYINT NOT NULL DEFAULT 0');
  // the projects a reader already finds interesting, which random projects leave out
  RegisterUpgrade('catalog-interest-who', 'ALTER TABLE catalog_interest ADD INDEX catalog_interest_who (who)');
  RegisterUpgrade('catalog-rating-columns', 'ALTER TABLE catalog_entries ADD COLUMN rating_count INT NOT NULL DEFAULT 0, ADD COLUMN rating_sum INT NOT NULL DEFAULT 0');
  RegisterTable('CREATE TABLE IF NOT EXISTS catalog_readmes (' + ' entry_id INT PRIMARY KEY, body MEDIUMTEXT NOT NULL, html MEDIUMTEXT NOT NULL,' +
    ' url VARCHAR(2048) NOT NULL DEFAULT '''', fetched DATETIME NOT NULL) ENGINE=InnoDB CHARACTER SET utf8mb4');
  RegisterUpgrade('catalog-image-column', 'ALTER TABLE catalog_entries ADD COLUMN image VARCHAR(2048) NOT NULL DEFAULT ''''');
  RegisterUpgrade('catalog-search-index', 'ALTER TABLE catalog_entries ADD FULLTEXT catalog_search (name, title, summary, topics, categories, owner)');
  RegisterUpgrade('catalog-readme-rendered', 'ALTER TABLE catalog_readmes ADD COLUMN rendered INT NOT NULL DEFAULT 0');
  RegisterUpgrade('catalog-readme-index', 'ALTER TABLE catalog_readmes ADD FULLTEXT catalog_readme_search (body)');
  RegisterUpgrade('catalog-icon-column', 'ALTER TABLE catalog_entries ADD COLUMN icon VARCHAR(2048) NOT NULL DEFAULT ''''');
  RegisterUpgrade('catalog-hidden-note', 'ALTER TABLE catalog_entries ADD COLUMN hidden_note VARCHAR(1000) NULL');
  // An entry's own picture: a file token, as a member's avatar is.
  RegisterUpgrade('catalog-picture', 'ALTER TABLE catalog_entries ADD COLUMN picture VARCHAR(40) NOT NULL DEFAULT ''''');

  { The module: its switch, its link, its card on the home page, its permission and settings. }
  // a module the admin's overview switches on and off
  // off on a new site, like the forum: a site owner turns it on
  RegisterPart('catalog', 'The catalog: what the community makes and recommends in one list, with ratings and reports', False);
  RegisterPartPaths('catalog', ['/catalog', '/catalog-random', '/catalog-how', '/catalog-count.json', '/catalog-badge', '/catalog-images',
    '/api/catalog', '/api/admin/catalog']);
  RegisterPartLink('catalog', @CatalogLink);
  RegisterPartHome('catalog', '/catalog');
  RegisterHomePart('catalog_home', @CatalogHomeCard);
  RegisterSetting('catintr_hour', 'Catalog: presses of Interesting per visitor in an hour', '120', 'number', 'Catalog');
  RegisterSetting('catalog_intro', 'Catalog: the lines under its heading (empty: a plain sentence)', '', 'longtext', 'Catalog');

  { Work at start and every so often. }
  InitCriticalSection(InUseLock);
  RegisterChore(@ForgetOldSteps, 1440);
  RegisterStartup(@ServeCatalogImages);
  RegisterChore(@RenderOldReadmes, 1);

  { Who may ask what, how much and how often. }
  RegisterRequestLimit('catlist', 'Catalog lists', 60, 60, 1);
  // the rate route shares this limit: rooms need a permission, and ratings come quickly
  RegisterRequestLimit('catroom', 'Catalog rooms and ratings', 60, 30, 1);
  // badges come through a few shared picture proxies (GitHub's above all), so
  // they have their own, larger limit, outside /catalog/*
  RegisterRequestLimit('catbadge', 'README badges', 600, 600, 1);
  // the pictures the catalog keeps, put there by its tools
  RegisterFileGuard('/catalog-images');
  LimitRoute('catlist', '/catalog-random', 'GET');
  RegisterAdminRoute('/api/catalog/hide', 'edit-catalog');
  LimitRoute('catlist', '/catalog', 'GET');
  LimitRoute('catlist', '/catalog/*', 'GET');
  LimitRoute('catlist', '/api/catalog', 'GET');
  RegisterSearchRoute('/catalog');
  RegisterSearch('catalog', 'Catalog', 40, @FindInCatalog, '', '/catalog?q=');
  RegisterIndexed('catalog', @CatalogDoc, @CatalogNext, @CatalogHits, nil, True);
  IndexPrefers('catalog', 10, 0, 0);
  RegisterCatalogHidden('search', @EntryChanged);
  RegisterCatalogDelete('search', @EntryChanged);
  LimitRoute('catroom', '/catalog/*', 'POST');
  LimitRoute('catbadge', '/catalog-badge/*', 'GET');

  { The addresses the catalog answers. }
  HTTPRouter.RegisterRoute('/catalog', rmGet, @ShowCatalog);
  HTTPRouter.RegisterRoute('/catalog/:id', rmGet, @EntryPage);
  HTTPRouter.RegisterRoute('/catalog/:id/room', rmPost, @StartRoom);
  HTTPRouter.RegisterRoute('/catalog/:id/interest', rmPost, @PressInterest);
  HTTPRouter.RegisterRoute('/catalog-badge/:id', rmGet, @ShowBadge);
  HTTPRouter.RegisterRoute('/catalog/:id/badge', rmGet, @ShowBadge);
  HTTPRouter.RegisterRoute('/catalog/:id/rate', rmPost, @RateEntry);
  HTTPRouter.RegisterRoute('/catalog-random', rmGet, @ShowRandomEntry);
  HTTPRouter.RegisterRoute('/catalog-how', rmGet, @ShowHow);
  HTTPRouter.RegisterRoute('/catalog-count.json', rmGet, @ShowCount);
  HTTPRouter.RegisterRoute('/api/catalog/:id/readme', rmGet, @ShowReadme);
  HTTPRouter.RegisterRoute('/api/catalog', rmGet, @ShowCatalog);
  HTTPRouter.RegisterRoute('/api/catalog/hide', rmPost, @HideEntry);
end.
