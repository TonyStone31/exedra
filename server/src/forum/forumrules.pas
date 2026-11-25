unit ForumRules;

{ Database-free forum rules: slugs, paging, text validation, posting and
  editing permissions, removal and addresses. }

{$mode objfpc}{$H+}

interface

const
  ForumPageSize = 25;
  ForumMaxBody = 32768;
  { A signature is a few lines under every post of its member. }
  ForumMaxSignature = 500;
  ForumMaxSignatureLines = 6;

type
  TForumDelete = (fdRefuse, fdPost, fdTopic, fdHide);

function ForumSlug(const Text: string): string;
function ForumPage(const Text: string): integer;
function ForumOffset(Page: integer): integer;
function ForumTextProblem(const Text: string; MaxBytes: integer; SingleLine: boolean): string;
{ What is wrong with a signature, '' for nothing; an empty one is no
  signature and is fine. }
function ForumSignatureProblem(const Text: string): string;
function ForumMayWrite(MemberId: integer; Banned, Verified, Granted: boolean): boolean;
function ForumMayReadBoard(Granted, HasParent, ParentExists, ParentGranted: boolean): boolean;
function ForumMayChange(MemberId, AuthorId: integer; Writable, Moderate, Locked, Hidden: boolean): boolean;
function ForumDeleteAction(Allowed, FirstPost, HasReplies: boolean): TForumDelete;
function ForumTopicWhere(const BoardIds: string; Moderate: boolean): string;
function ForumPostWhere(Moderate: boolean): string;
function ForumBoardUrl(const Slug: string): string;
function ForumTopicUrl(Id: integer): string;
function ForumPageUrl(const Path: string; Page: integer; const SearchText: string = ''): string;

function ForumPageForPosition(Position: integer): integer;
function ForumPositionColumn(Moderator: boolean): string;
function ForumPostUrl(TopicId, PostId: integer): string;

implementation

uses SysUtils, httpdefs;

function ForumPageForPosition(Position: integer): integer;
begin
  if Position < 1 then Exit(1);
  Result := (Position - 1) div ForumPageSize + 1;
end;

function ForumPositionColumn(Moderator: boolean): string;
begin
  Result := 'visible_position';
  if Moderator then Result := 'position';
end;

function ForumPostUrl(TopicId, PostId: integer): string;
begin
  Result := ForumTopicUrl(TopicId) + '?post=' + IntToStr(PostId) + '#post-' + IntToStr(PostId);
end;

function ForumBoardUrl(const Slug: string): string;
begin
  Result := '/forum/' + HTTPEncode(Slug);
end;

function ForumTopicUrl(Id: integer): string;
begin
  Result := '/forum/t/' + IntToStr(Id);
end;

function ForumPageUrl(const Path: string; Page: integer; const SearchText: string): string;
var
  Separator: string;
begin
  Result := Path;
  Separator := '?';
  if SearchText <> '' then
  begin
    Result := Result + '?q=' + HTTPEncode(SearchText);
    Separator := '&';
  end;
  if Page > 1 then
    Result := Result + Separator + 'page=' + IntToStr(ForumPage(IntToStr(Page)));
end;

function ForumSlug(const Text: string): string;
var
  C: char;
  Separator: boolean;
begin
  Result := '';
  Separator := False;
  for C in LowerCase(Trim(Text)) do
    if C in ['a'..'z', '0'..'9'] then
    begin
      if Separator and (Result <> '') then
        Result := Result + '-';
      Result := Result + C;
      Separator := False;
      if Length(Result) >= 80 then
        Break;
    end
    else
      Separator := True;
  Result := Copy(Result, 1, 80);
  if (Result <> '') and (Result[Length(Result)] = '-') then
    Delete(Result, Length(Result), 1);
end;

function ForumPage(const Text: string): integer;
begin
  Result := StrToIntDef(Text, 1);
  if Result < 1 then
    Result := 1;
  if Result > 1000000 then
    Result := 1000000;
end;

function ForumOffset(Page: integer): integer;
begin
  Result := (ForumPage(IntToStr(Page)) - 1) * ForumPageSize;
end;

function ForumTextProblem(const Text: string; MaxBytes: integer; SingleLine: boolean): string;
var
  C: char;
begin
  Result := '';
  if Trim(Text) = '' then
    Exit('Enter some text.');
  if Length(Text) > MaxBytes then
    Exit('The text is too long.');
  for C in Text do
    if ((Ord(C) < 32) and (SingleLine or not (C in [#9, #10, #13]))) or (Ord(C) = 127) then
      Exit('The text contains an invalid control character.');
end;

function ForumSignatureProblem(const Text: string): string;
var
  C: char;
  Lines: integer;
begin
  Result := '';
  if Trim(Text) = '' then
    Exit;
  if Length(Text) > ForumMaxSignature then
    Exit('The signature is too long.');
  Lines := 1;
  for C in Trim(Text) do
    if C = #10 then
      Inc(Lines)
    else if ((Ord(C) < 32) and not (C in [#9, #13])) or (Ord(C) = 127) then
      Exit('The text contains an invalid control character.');
  if Lines > ForumMaxSignatureLines then
    Exit('The signature has too many lines.');
end;

function ForumMayWrite(MemberId: integer; Banned, Verified, Granted: boolean): boolean;
begin
  Result := (MemberId > 0) and not Banned and Verified and Granted;
end;

function ForumMayReadBoard(Granted, HasParent, ParentExists, ParentGranted: boolean): boolean;
begin
  Result := Granted and (not HasParent or (ParentExists and ParentGranted));
end;

function ForumMayChange(MemberId, AuthorId: integer; Writable, Moderate, Locked, Hidden: boolean): boolean;
begin
  Result := (MemberId > 0) and (Moderate or (Writable and (MemberId = AuthorId) and not Locked and not Hidden));
end;

function ForumDeleteAction(Allowed, FirstPost, HasReplies: boolean): TForumDelete;
begin
  Result := fdRefuse;
  if not Allowed then
    Exit;
  if not FirstPost then
    Result := fdPost
  else if HasReplies then
    Result := fdHide
  else
    Result := fdTopic;
end;

function ForumTopicWhere(const BoardIds: string; Moderate: boolean): string;
begin
  if BoardIds = '' then
    Result := '1 = 0'
  else
    Result := 't.board_id IN (' + BoardIds + ')';
  if not Moderate then
    Result := Result + ' AND t.hidden = 0';
end;

function ForumPostWhere(Moderate: boolean): string;
begin
  Result := '';
  if not Moderate then
    Result := ' AND (p.hidden = 0 OR p.id = t.first_post_id)';
end;

end.
