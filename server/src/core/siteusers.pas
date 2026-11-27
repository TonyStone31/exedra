unit SiteUsers;

{ Accounts, sessions, tokens, profiles and ignored members. Store an
  Argon2id hash of the browser-derived login secret plus public and wrapped
  private keys. Sessions use cookies or bearer tokens. Closing wipes
  credentials and profile but preserves contributions; former names stay
  reserved. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, httpdefs;

type
  TMember = record
    Id: integer;
    Name: string;
    Roles: string;     // the site roles given to them, comma separated
    Banned: boolean;
    Verified: boolean;  // its email address is confirmed
  end;

  TMemberHook = procedure(UserId: integer);
  TMeHook = procedure(const Me: TMember; Answer: TJSONObject);
  TPrefShown = function: boolean;
  TNameCheck = function(const ProposedName: string): string;
  TRenameMemberHook = procedure(UserId: integer; const OldName, NewName: string);
  { Why this member cannot take the name, or '' when they can. }
  TRenameCheck = function(UserId: integer; const NewName: string): string;
  ENameUnavailable = class(Exception);

{ The member signed in on this request, or Id 0. }
function CurrentMember(ARequest: TRequest): TMember;
{ The member a request's session token or cookie names, looked up afresh
  (no per-request cache, no address noted): for the transport, which asks
  before the request is routed. }
function SignedInMember(ARequest: TRequest): TMember;
{ Sends a refusal and returns False unless a member who may talk is signed in. }
function NeedMember(ARequest: TRequest; AResponse: TResponse; out Member: TMember): boolean;
{ A member by id, as CurrentMember gives one. }
function MemberById(Id: integer): TMember;
function MemberId(const Name: string): integer;
function MemberExists(const Name: string): boolean;
function AvatarUrl(const Token: string): string;
{ The ids of the members Me ignores, comma separated ('' for none). }
function IgnoredIds(UserId: integer): string;
function Ignores(UserId, OtherId: integer): boolean;
procedure RegisterNewMemberHook(Hook: TMemberHook);
{ Called as an account is closed, inside its transaction: a unit wipes what
  it keeps about the member for the member alone (settings, what they
  follow, addresses to notify), never what the member contributed. }
procedure RegisterCloseMemberHook(Hook: TMemberHook);
{ Closes the account for ById (the member themselves, or an admin) with
  Reason; Anonymous gives it the name "Former member" and its number in
  place of its own.  '' when done, else why not. }
function CloseMember(UserId, ById: integer; const Reason: string; Anonymous: boolean): string;
{ Opens a closed account again, with no address and no password: an admin
  makes a password link next.  '' when done, else why not. }
function ReopenMember(UserId: integer): string;
function MemberClosed(UserId: integer): boolean;
{ The present name of the member who was once called Name, for finding
  their profile; '' for nobody, and for a name its member left behind when
  the account was closed without a name. }
function NameNow(const FormerName: string): string;
{ A site's own unit can refuse names (ones it keeps for itself, say): the
  hook answers why not, '' when the name is fine.  NameRefusal asks them
  all, wherever a member picks a name. }
procedure RegisterNameCheck(Hook: TNameCheck);
function NameRefusal(const ProposedName: string): string;
procedure RegisterRenameMemberHook(Hook: TRenameMemberHook);
procedure RegisterRenameCheck(Check: TRenameCheck);
{ A unit adds to /api/me what its pages need to know about the member
  signed in (a preference of theirs it keeps). }
procedure RegisterMeHook(Hook: TMeHook);
{ A unit adds a yes or no of the member's own to the preferences on their
  profile: Name (lower case letters and underscores, starting with the
  unit's own word), the Words beside its checkbox, and what it is until
  the member chooses.  Shown, when given, says whether the line shows now.
  /api/me lists them as prefs and /api/prefs saves one by its name. }
procedure RegisterMemberPref(const Name, Words: string; Default: boolean; Shown: TPrefShown = nil);
function MemberPref(UserId: integer; const Name: string): boolean;
procedure SaveMemberPref(UserId: integer; const Name: string; Value: boolean);
{ Serializes account creation, name imports and renames across processes. }
procedure LockMemberNames;
procedure UnlockMemberNames;
{ Caller holds LockMemberNames and a database transaction. Does not commit.
  Existing password salts and private-message identities stay unchanged. }
function RenameMember(UserId: integer; const NewName: string): string;
function ValidRenameName(const NewName: string): boolean;
{ A rename from start to end, for a name picked now: the rules a new account's
  name meets, the lock and the transaction.  '' when done, else why not. }
function ChangeMemberName(UserId: integer; const NewName: string): string;
function RandomHex(Bytes: integer): string;
function Sha256Hex(const S: string): string;
function IsHex(const S: string; Len: integer): boolean;
procedure SendText(AResponse: TResponse; Code: integer; const Text: string);
{ Sends and frees Data. }
procedure SendJSON(AResponse: TResponse; Data: TJSONData);
function ClientIp(ARequest: TRequest): string;
{ An address of the house or the machines behind it, not a visitor's. }
function PrivateAddress(const Ip: string): boolean;
{ Machines of the house seen passing on other people's requests without
  being named under proxies in the config file, space separated. }
function UnlistedProxies: string;
{ A form sent from another site's page: the browser names that page's
  origin, or says the request is cross-site.  Apps and scripts that send
  neither are not refused by it. }
function FromAnotherSite(ARequest: TRequest): boolean;
{ The session or program token a request carries, '' when it carries none. }
function TokenOf(ARequest: TRequest): string;
{ True when the site is reached over HTTPS, so its cookies must be too. }
function SecureCookies: boolean;
{ A LIKE pattern for names starting with S, its % and _ taken literally. }
function LikePrefix(const S: string): string;
{ For `exedra --admin Name`: makes an existing member an admin. }
function MakeAdmin(const Name: string): boolean;
function ValidName(const S: string): boolean;
{ A new account; Auth, Pub and Wrapped are empty for one made by signing in
  elsewhere (unit SiteLogins), which has no password yet. }
function AddMember(const Name, Email, Auth, Pub, Wrapped: string; Verified: boolean): integer;
{ Mails the member a link that confirms their address.  With NewEmail the
  link goes there, and opening it makes that the account's address. }
procedure SendAddressCheck(UserId: integer; const NewEmail: string = '');
function ValidEmail(const S: string): boolean;
{ Whether an account other than ExceptUser has the address. }
function EmailTaken(const Email: string; ExceptUser: integer = 0): boolean;
{ Signs the browser in as this member with a session cookie. }
procedure StartWebSession(AResponse: TResponse; UserId: integer);
{ A session token for a program (Kind 'app', Name the device's name), good for Days. }
function NewSession(UserId: integer; const Kind, Name: string; Days: integer): string;

const
  AppSessionDays = 365;
  { users.verified for a member let in while the site had no mail: they may
    write, and no mail goes to the address, which nobody confirmed. }
  UNCHECKED = 2;
  { The name of an account closed without one, before its number. }
  FormerMember = 'Former member';

{ For `exedra --password-link Name`: a one-time token, good for a week, that lets
  the member set a new password at /password/token ('' for no such member). }
function MakePasswordLink(const Name: string; Hours: integer = 168): string;
{ The member a password link is for, or ''. }
function PasswordLinkName(const Token: string): string;
{ For IRC, which sends the password itself: the same check the browser's
  sign-in makes, and the key to make an account with (AddMember Auth). }
function AuthFromPassword(const Name, Password: string): string;
function PasswordMatches(const Name, Password: string): boolean;
{ Sign-in tries, counted per address and kind ('signin', 'signup'). }
function TooManyTries(const Ip, Kind: string; Limit, Minutes: integer): boolean;
procedure NoteTry(const Ip, Kind: string);
{ New accounts from one address in a day, past the admin's number: a
  classroom or an office behind one address is the usual case, so the
  default is ten rather than a handful. }
function TooManySignups(const Ip: string): boolean;

implementation

uses
  StrUtils, Variants, Math, sqldb, jsonparser, httproute, SiteMail, SiteGuard, HlpHashFactory, HlpIHashInfo, HlpConverters,
  HlpArgon2TypeAndVersion, HlpPBKDF_Argon2NotBuildInAdapter, ClpOSRandomProvider,
  SiteDb, SiteSql, SiteMarkup, SiteRoles, SiteBell, SiteGuardRules, SiteWords;

const
  NameRule = 'A name is 2 to 24 letters, digits, - _ or a dot inside.';
  SessionDays = 30;
  ArgonIterations = 2;
  ArgonMemoryKB = 19456;

var
  NewMemberHooks: array of TMemberHook;
  CloseMemberHooks: array of TMemberHook;
  NameChecks: array of TNameCheck;
  RenameMemberHooks: array of TRenameMemberHook;
  RenameChecks: array of TRenameCheck;
  MeHooks: array of TMeHook;

  MemberPrefs: array of record
    Name, Words: string;
    Default: boolean;
    Shown: TPrefShown;
    end;

threadvar
  MemberRequestId: string;
  RequestMember: TMember;

procedure RegisterMeHook(Hook: TMeHook);
begin
  SetLength(MeHooks, Length(MeHooks) + 1);
  MeHooks[High(MeHooks)] := Hook;
end;

procedure RegisterMemberPref(const Name, Words: string; Default: boolean; Shown: TPrefShown);
begin
  SetLength(MemberPrefs, Length(MemberPrefs) + 1);
  MemberPrefs[High(MemberPrefs)].Name := Name;
  MemberPrefs[High(MemberPrefs)].Words := Words;
  MemberPrefs[High(MemberPrefs)].Default := Default;
  MemberPrefs[High(MemberPrefs)].Shown := Shown;
end;

function MemberPref(UserId: integer; const Name: string): boolean;
var
  I: integer;
  Chosen: variant;
begin
  Result := False;
  for I := 0 to High(MemberPrefs) do
    if MemberPrefs[I].Name = Name then
      Result := MemberPrefs[I].Default;
  Chosen := Value('SELECT value FROM member_prefs WHERE user_id = :u AND name = :n', [UserId, Name]);
  if not VarIsNull(Chosen) then
    Result := Chosen = 1;
end;

procedure SaveMemberPref(UserId: integer; const Name: string; Value: boolean);
begin
  Exec('INSERT INTO member_prefs (user_id, name, value) VALUES (:u, :n, :v)' + SqlOnConflict('user_id, name', 'value = ' + SqlNew('value')), [UserId, Name, Ord(Value)]);
end;

procedure RegisterNameCheck(Hook: TNameCheck);
begin
  SetLength(NameChecks, Length(NameChecks) + 1);
  NameChecks[High(NameChecks)] := Hook;
end;

{ Whether a member other than ExceptUser was once called Name: it stays theirs. }
function WasNameOf(const Name: string; ExceptUser: integer): boolean;
begin
  Result := IntValue('SELECT COUNT(*) FROM former_names WHERE name = :n AND user_id <> :u', [Name, ExceptUser]) > 0;
end;

function NameNow(const FormerName: string): string;
begin
  Result := VarToStr(Value('SELECT u.name FROM former_names f JOIN users u ON u.id = f.user_id WHERE f.name = :n AND f.hidden = 0', [FormerName]));
end;

{ Why UserId (0 for someone new) cannot be called ProposedName, '' when they can. }
function NameRefusalFor(UserId: integer; const ProposedName: string): string;
var
  Hook: TNameCheck;
begin
  Result := '';
  if WasNameOf(ProposedName, UserId) then
    Exit('That name is taken.');
  for Hook in NameChecks do
  begin
    Result := Hook(ProposedName);
    if Result <> '' then
      Exit;
  end;
end;

function NameRefusal(const ProposedName: string): string;
begin
  Result := NameRefusalFor(0, ProposedName);
end;

procedure RegisterRenameMemberHook(Hook: TRenameMemberHook);
begin
  SetLength(RenameMemberHooks, Length(RenameMemberHooks) + 1);
  RenameMemberHooks[High(RenameMemberHooks)] := Hook;
end;

procedure LockMemberNames;
begin
  if IntValue('SELECT ' + SqlLock(SqlConcat(['DATABASE()', ''':member-names''']), 10), []) <> 1 then
    raise ENameUnavailable.Create('Account names are busy. Try again.');
end;

procedure UnlockMemberNames;
begin
  Value('SELECT ' + SqlUnlock(SqlConcat(['DATABASE()', ''':member-names'''])), []);
end;

function ValidRenameName(const NewName: string): boolean;
var
  C: char;
begin
  Result := False;
  // Imported names may contain spaces and non-ASCII letters, but no URL delimiters.
  if (Length(NewName) < 2) or (Length(NewName) > 59) or (Trim(NewName) <> NewName) then
    Exit;
  for C in NewName do
    if (Ord(C) < 32) or (C in ['/', '\', '?', '#', '%', '@', '<', '>', '"', '''']) then
      Exit;
  Result := True;
end;

procedure RegisterRenameCheck(Check: TRenameCheck);
begin
  SetLength(RenameChecks, Length(RenameChecks) + 1);
  RenameChecks[High(RenameChecks)] := Check;
end;

function RenameMember(UserId: integer; const NewName: string): string;
var
  OldName: string;
  Hook: TRenameMemberHook;
  Check: TRenameCheck;
begin
  if not ValidRenameName(NewName) then
    Exit('That name cannot be used here.');
  OldName := VarToStr(Value('SELECT name FROM users WHERE id = :u FOR UPDATE', [UserId]));
  if OldName = '' then
    Exit('That member no longer exists.');
  if (IntValue('SELECT COUNT(*) FROM users WHERE name = :n AND id <> :u', [NewName, UserId]) > 0) or WasNameOf(NewName, UserId) then
    Exit('That name is taken.');
  for Check in RenameChecks do
  begin
    Result := Check(UserId, NewName);
    if Result <> '' then
      Exit;
  end;
  Exec('UPDATE users SET name = :n WHERE id = :u', [NewName, UserId]);
  // the old name stays theirs, and leads to them; a name taken back is no former one
  Exec('DELETE FROM former_names WHERE name = :n', [NewName]);
  if not SameText(OldName, NewName) then
    Exec(SqlReplace('former_names', 'name, user_id', ':n, :u'), [OldName, UserId]);
  for Hook in RenameMemberHooks do
    Hook(UserId, OldName, NewName);
  Result := '';
end;

{ RenameMember with its lock and its transaction, and word of it to open pages. }
function RenameNow(UserId: integer; const NewName: string): string;
begin
  try
    LockMemberNames;
  except
    on E: ENameUnavailable do
      Exit(E.Message);
  end;
  try
    Exec('START TRANSACTION', []);
    try
      Result := RenameMember(UserId, NewName);
      if Result = '' then
        Exec('COMMIT', [])
      else
        Exec('ROLLBACK', []);
    except
      Exec('ROLLBACK', []);
      raise;
    end;
  finally
    UnlockMemberNames;
  end;
  // open pages and apps hold names: lists, and whom a locked message is from
  if Result = '' then
    RingAll('{"t":"names"}');
end;

function ChangeMemberName(UserId: integer; const NewName: string): string;
begin
  if not ValidName(NewName) then
    Exit(NameRule);
  Result := NameRefusalFor(UserId, NewName);
  if Result = '' then
    Result := RenameNow(UserId, NewName);
end;

procedure RegisterCloseMemberHook(Hook: TMemberHook);
begin
  SetLength(CloseMemberHooks, Length(CloseMemberHooks) + 1);
  CloseMemberHooks[High(CloseMemberHooks)] := Hook;
end;

function MemberClosed(UserId: integer): boolean;
begin
  Result := IntValue('SELECT closed FROM users WHERE id = :u', [UserId]) = 1;
end;

function CloseMember(UserId, ById: integer; const Reason: string; Anonymous: boolean): string;
var
  Hook: TMemberHook;
begin
  if IntValue('SELECT COUNT(*) FROM users WHERE id = :u AND closed = 0', [UserId]) = 0 then
    Exit('That account is closed already.');
  // a site is never left without an admin
  if HasRole(VarToStr(Value('SELECT roles FROM users WHERE id = :u', [UserId])), 'admin') and
    (IntValue('SELECT COUNT(*) FROM users WHERE id <> :u AND closed = 0 AND banned = 0 AND FIND_IN_SET(''admin'', roles) > 0', [UserId]) = 0) then
    Exit('The site needs an admin. Make another member one first.');
  if Anonymous then
  begin
    Result := RenameNow(UserId, FormerMember + ' ' + IntToStr(UserId));
    if Result <> '' then
      Exit;
    // the names they had stay taken, and lead nowhere
    Exec('UPDATE former_names SET hidden = 1 WHERE user_id = :u', [UserId]);
    // the first name, kept for the password and the keys wiped below, would tell who this was
    Exec('UPDATE users SET auth_name = name, key_name = name WHERE id = :u', [UserId]);
  end;
  Exec('START TRANSACTION', []);
  try
    // before the row is wiped: a hook may need what it holds (the avatar's file)
    for Hook in CloseMemberHooks do
      Hook(UserId);
    Exec('UPDATE users SET closed = 1, closed_at = NOW(), closed_by = :b, closed_reason = :r, roles = '''', email = '''', auth_hash = '''',' +
      ' public_key = '''', wrapped_key = '''', bio = '''', links = '''', avatar = '''', away = '''', mail_notes = 0, mail_key = '''', mail_due = NULL' +
      ' WHERE id = :u', [ById, Copy(Reason, 1, 500), UserId]);
    Exec('DELETE FROM sessions WHERE user_id = :u', [UserId]);
    Exec('DELETE FROM password_links WHERE user_id = :u', [UserId]);
    Exec('DELETE FROM email_checks WHERE user_id = :u', [UserId]);
    Exec('DELETE FROM ignores WHERE user_id = :u', [UserId]);
    Exec('DELETE FROM member_addresses WHERE user_id = :u', [UserId]);
    Exec('DELETE FROM member_prefs WHERE user_id = :u', [UserId]);
    Exec('COMMIT', []);
  except
    Exec('ROLLBACK', []);
    raise;
  end;
  DropUser(UserId);
  Result := '';
end;

function ReopenMember(UserId: integer): string;
begin
  if not MemberClosed(UserId) then
    Exit('That account is not closed.');
  // with no address left to confirm, it counts as confirmed
  Exec('UPDATE users SET closed = 0, closed_at = NULL, closed_by = 0, closed_reason = '''', verified = 1 WHERE id = :u', [UserId]);
  Result := '';
end;

procedure RegisterNewMemberHook(Hook: TMemberHook);
begin
  SetLength(NewMemberHooks, Length(NewMemberHooks) + 1);
  NewMemberHooks[High(NewMemberHooks)] := Hook;
end;

function TooManySignups(const Ip: string): boolean;
begin
  Result := TooManyTries(Ip, 'signup', SettingInt('signups_per_address', 10), 24 * 60);
end;

function RandomHex(Bytes: integer): string;
var
  B: TBytes;
begin
  SetLength(B, Bytes);
  TOSRandomProvider.Instance.GetBytes(B);
  Result := LowerCase(TConverters.ConvertBytesToHexString(B, False));
end;

function Sha256Hex(const S: string): string;
begin
  Result := LowerCase(THashFactory.TCrypto.CreateSHA2_256().ComputeString(S, TEncoding.UTF8).ToString());
end;

function Argon2id(const Secret: string; const Salt: TBytes; Iterations, MemoryKB: integer): string;
var
  Builder: IArgon2ParametersBuilder;
  Params: IArgon2Parameters;
  Generator: IPBKDF_Argon2;
begin
  Builder := TArgon2idParametersBuilder.Builder();
  Builder.WithVersion(TArgon2Version.Version13).WithIterations(Iterations)
    .WithMemoryAsKB(MemoryKB).WithParallelism(1).WithSalt(Salt);
  Params := Builder.Build();
  Builder.Clear();
  Generator := TKDF.TPBKDF_Argon2.CreatePBKDF_Argon2(TEncoding.UTF8.GetBytes(unicodestring(Secret)), Params);
  Result := LowerCase(TConverters.ConvertBytesToHexString(Generator.GetBytes(32), False));
  Params.Clear();
  Generator.Clear();
end;

{ Stored as argon2id$iterations$memory$salt$hash, so the cost can be raised
  later without breaking older hashes. }
function HashSecret(const Secret: string): string;
var
  Salt: TBytes;
begin
  SetLength(Salt, 16);
  TOSRandomProvider.Instance.GetBytes(Salt);
  Result := Format('argon2id$%d$%d$%s$%s', [ArgonIterations, ArgonMemoryKB, LowerCase(TConverters.ConvertBytesToHexString(Salt, False)),
    Argon2id(Secret, Salt, ArgonIterations, ArgonMemoryKB)]);
end;

function CheckSecret(const Secret, Stored: string): boolean;
var
  Parts: TStringArray;
  Hash: string;
  I, Diff: integer;
begin
  Parts := Stored.Split(['$']);
  if (Length(Parts) <> 5) or (Parts[0] <> 'argon2id') then
    Exit(False);
  Hash := Argon2id(Secret, TConverters.ConvertHexStringToBytes(Parts[3]), StrToInt(Parts[1]), StrToInt(Parts[2]));
  if Length(Hash) <> Length(Parts[4]) then
    Exit(False);
  // Compare every character, so the time taken says nothing.
  Diff := 0;
  for I := 1 to Length(Hash) do
    Diff := Diff or (Ord(Hash[I]) xor Ord(Parts[4][I]));
  Result := Diff = 0;
end;

function IsHex(const S: string; Len: integer): boolean;
var
  C: char;
begin
  Result := Length(S) = Len;
  for C in S do
    if not (C in ['0'..'9', 'a'..'f']) then
      Exit(False);
end;

function IsBase64(const S: string; MaxLen: integer): boolean;
var
  C: char;
begin
  Result := (S <> '') and (Length(S) <= MaxLen);
  for C in S do
    if not (C in ['A'..'Z', 'a'..'z', '0'..'9', '+', '/', '=', '.']) then
      Exit(False);
end;

function ValidName(const S: string): boolean;
var
  C: char;
begin
  // A dot only inside, so "@name." at the end of a sentence still works.
  Result := (Length(S) >= 2) and (Length(S) <= 24) and not S.StartsWith('.') and not S.EndsWith('.') and (Pos('..', S) = 0);
  for C in S do
    if not (C in ['A'..'Z', 'a'..'z', '0'..'9', '_', '-', '.']) then
      Exit(False);
end;

{ Responses }

procedure SendText(AResponse: TResponse; Code: integer; const Text: string);
begin
  AResponse.Code := Code;
  AResponse.ContentType := 'text/plain; charset=utf-8';
  AResponse.Content := Text;
  AResponse.SendContent;
end;

procedure SendJSON(AResponse: TResponse; Data: TJSONData);
begin
  try
    AResponse.ContentType := 'application/json';
    AResponse.Content := Data.AsJSON;
  finally
    Data.Free;
  end;
  AResponse.SendContent;
end;

{ The house and the machines behind it. }
function PrivateAddress(const Ip: string): boolean;
var
  Second: integer;
begin
  Result := StartsStr('127.', Ip) or StartsStr('10.', Ip) or StartsStr('192.168.', Ip) or (Ip = '::1') or StartsStr('fe80:', LowerCase(Ip)) or
    StartsStr('fc', LowerCase(Ip)) or StartsStr('fd', LowerCase(Ip));
  if not Result and StartsStr('172.', Ip) then
  begin
    Second := StrToIntDef(Copy(Ip, 5, Pos('.', Copy(Ip, 5, 4)) - 1), 0);
    Result := (Second >= 16) and (Second <= 31);
  end;
end;

var
  Forwarders: string = '';
  ForwardLock: TRTLCriticalSection;

{ A proxy the config file does not name: every visitor arrives as its
  address, so the guard must not block it, and the admin page says so. }
procedure NoteForwarder(const Ip: string);
begin
  EnterCriticalSection(ForwardLock);
  try
    if (Pos(' ' + Ip + ' ', ' ' + Forwarders + ' ') = 0) and (Length(Forwarders) < 500) then
      Forwarders := Trim(Forwarders + ' ' + Ip);
  finally
    LeaveCriticalSection(ForwardLock);
  end;
end;

function UnlistedProxies: string;
begin
  EnterCriticalSection(ForwardLock);
  try
    Result := Forwarders;
    UniqueString(Result);
  finally
    LeaveCriticalSection(ForwardLock);
  end;
end;

{ Behind a proxy the config names ([site] proxies), the proxy names the
  visitor.  Anyone else could write that header, so it counts only from
  there. }
function ClientIp(ARequest: TRequest): string;
var
  Forwarded, Proxy, Candidate: string;
  Addresses: TStringArray;
  I: integer;
  Trusted: boolean;
begin
  Result := CanonicalIp(ARequest.RemoteAddress);
  Forwarded := ARequest.GetCustomHeader('X-Forwarded-For');
  if Forwarded = '' then
    Exit;
  Addresses := Forwarded.Split([',']);
  // Start at the peer: a client cannot vouch for entries it prepended.
  for I := High(Addresses) downto 0 do
  begin
    Trusted := False;
    for Proxy in Config.ReadString('site', 'proxies', '127.0.0.1').Split([',', ' '], TStringSplitOptions.ExcludeEmpty) do
      if Result = CanonicalIp(Proxy) then
        Trusted := True;
    if not Trusted then
    begin
      if (I = High(Addresses)) and PrivateAddress(Result) then
        NoteForwarder(Result);
      Exit;
    end;
    Candidate := CanonicalIp(Addresses[I]);
    if Candidate = '' then
      Exit;
    Result := Candidate;
  end;
end;

{ Members }

function TokenOf(ARequest: TRequest): string;
begin
  // another kind of Authorization (a proxy's own sign-in) is not ours to judge
  Result := ARequest.Authorization;
  if not AnsiStartsText('Bearer ', Result) then
    Result := ARequest.CookieFields.Values['sid']
  else
  begin
    Result := Trim(Copy(Result, 8, MaxInt));
    if Result = '' then
      Result := 'invalid';
  end;
end;

function LookupMember(ARequest: TRequest): TMember;
var
  Token: string;
begin
  Result.Id := 0;
  Result.Name := '';
  Result.Roles := '';
  Result.Banned := False;
  Result.Verified := False;
  Token := TokenOf(ARequest);
  if Token = '' then
    Exit;
  if TooManyTries(ClientIp(ARequest), 'bad-token', SettingInt('token_tries', 30), 1) then
    Exit;
  if not IsHex(Token, 64) then
  begin
    NoteTry(ClientIp(ARequest), 'bad-token');
    Exit;
  end;
  with Query('SELECT u.id, u.name, u.roles, u.banned, u.verified FROM sessions s JOIN users u ON u.id = s.user_id' +
      ' WHERE s.token_hash = :t AND (s.expires IS NULL OR s.expires > NOW()) AND u.closed = 0', [Sha256Hex(Token)]) do
  try
    if not EOF then
    begin
      Result.Id := Fields[0].AsInteger;
      Result.Name := Fields[1].AsString;
      Result.Roles := Fields[2].AsString;
      Result.Banned := Fields[3].AsInteger = 1;
      Result.Verified := Fields[4].AsInteger > 0;
    end;
  finally
    Free;
  end;
  // a token is too long to guess, so a wrong one (revoked, expired) is
  // slowed by its own limit and never counts as guessing a password
  if Result.Id = 0 then
    NoteTry(ClientIp(ARequest), 'bad-token');
end;

var
  { member id and address -> the minute it was last written, so a busy
    member costs one write in ten minutes, not one a request }
  AddressSeen: TStringList;
  AddressLock: TRTLCriticalSection;

{ The addresses a member signs in from, for the admins only (permission
  view-member-addresses): never in a page or answer anyone else gets. }
procedure NoteMemberAddress(UserId: integer; const Address: string);
var
  Ip, Key: string;
  I: integer;
  Minute: PtrInt;
  Due: boolean;
begin
  Ip := CanonicalIp(Address);
  if (UserId <= 0) or (Ip = '') then
    Exit;
  Key := IntToStr(UserId) + ' ' + Ip;
  Minute := Trunc(Now * MinsPerDay);
  EnterCriticalSection(AddressLock);
  try
    Due := not AddressSeen.Find(Key, I) or (Minute - PtrInt(AddressSeen.Objects[I]) >= 10);
    if Due then
    begin
      if AddressSeen.Count > 20000 then
        AddressSeen.Clear;
      if AddressSeen.Find(Key, I) then
        AddressSeen.Objects[I] := TObject(Minute)
      else
        AddressSeen.AddObject(Key, TObject(Minute));
    end;
  finally
    LeaveCriticalSection(AddressLock);
  end;
  if Due then
  try
    Exec('INSERT INTO member_addresses (user_id, ip, first_seen, last_seen, hits) VALUES (:u, :i, NOW(), NOW(), 1)' +
      SqlOnConflict('user_id, ip', 'last_seen = NOW(), hits = hits + 1'), [UserId, Ip]);
  except
    on E: Exception do
      Log('Member address for ' + IntToStr(UserId) + ' not kept: ' + E.Message);
  end;
end;

function SignedInMember(ARequest: TRequest): TMember;
begin
  Result := LookupMember(ARequest);
end;

{ Addresses not seen for member_addresses_days are forgotten. }
procedure ForgetOldAddresses;
begin
  Exec('DELETE FROM member_addresses WHERE last_seen < ' + SqlAgo(':d', suDay), [SettingInt('member_addresses_days', 180)]);
end;

function CurrentMember(ARequest: TRequest): TMember;
begin
  // A handler may ask several times; one bad token earns one strike.
  if MemberRequestId <> ARequest.RequestID then
  begin
    RequestMember := LookupMember(ARequest);
    MemberRequestId := ARequest.RequestID;
    if RequestMember.Id > 0 then
      NoteMemberAddress(RequestMember.Id, ClientIp(ARequest));
  end;
  Result := RequestMember;
end;

function MemberById(Id: integer): TMember;
begin
  Result.Id := 0;
  Result.Name := '';
  Result.Roles := '';
  Result.Banned := False;
  Result.Verified := False;
  if Id = 0 then
    Exit;
  with Query('SELECT id, name, roles, banned, verified FROM users WHERE id = :u', [Id]) do
  try
    if not EOF then
    begin
      Result.Id := Fields[0].AsInteger;
      Result.Name := Fields[1].AsString;
      Result.Roles := Fields[2].AsString;
      Result.Banned := Fields[3].AsInteger = 1;
      Result.Verified := Fields[4].AsInteger > 0;
    end;
  finally
    Free;
  end;
end;

function NeedMember(ARequest: TRequest; AResponse: TResponse; out Member: TMember): boolean;
begin
  Member := CurrentMember(ARequest);
  Result := False;
  // anything but a reading request must come from a page of this site
  if (ARequest.Method <> 'GET') and (ARequest.Method <> 'HEAD') and FromAnotherSite(ARequest) then
    SendText(AResponse, 403, 'Send this from a page of this site.')
  else if Member.Id = 0 then
    SendText(AResponse, 403, 'Sign in or join first.')
  else if Member.Banned then
    SendText(AResponse, 403, 'This account cannot talk here.')
  else if not Member.Verified then
    SendText(AResponse, 403, 'Confirm your email first: the link is in the mail we sent you.')
  else
    Result := True;
end;

function MemberId(const Name: string): integer;
begin
  Result := IntValue('SELECT id FROM users WHERE name = :n', [Name]);
end;

function MemberExists(const Name: string): boolean;
begin
  Result := MemberId(Name) > 0;
end;

function AvatarUrl(const Token: string): string;
begin
  Result := '';
  if Token <> '' then
    Result := '/f/' + Token + '/avatar';
end;

function IgnoredIds(UserId: integer): string;
begin
  Result := '';
  if UserId = 0 then
    Exit;
  with Query('SELECT ignored_id FROM ignores WHERE user_id = :u', [UserId]) do
  try
    while not EOF do
    begin
      if Result <> '' then
        Result := Result + ',';
      Result := Result + Fields[0].AsString;
      Next;
    end;
  finally
    Free;
  end;
end;

function Ignores(UserId, OtherId: integer): boolean;
begin
  Result := IntValue('SELECT COUNT(*) FROM ignores WHERE user_id = :u AND ignored_id = :o', [UserId, OtherId]) > 0;
end;

function MakeAdmin(const Name: string): boolean;
begin
  Result := MemberExists(Name);
  if Result then
    Exec('UPDATE users SET roles = ''admin'', banned = 0 WHERE name = :n', [Name]);
end;

function SecureCookies: boolean;
begin
  Result := (Setting('https', '0') = '1') or StartsText('https://', Setting('url', ''));
end;

procedure SetSessionCookie(AResponse: TResponse; const Token: string; Days: integer);
begin
  with AResponse.Cookies.Add do
  begin
    Name := 'sid';
    Value := Token;
    Path := '/';
    Expires := NowUTC + Days;
    HttpOnly := True;
    SameSite := ssLax;
    Secure := SecureCookies;
  end;
end;

{ A new session; kind web (the cookie), app (a token for an app that signs
  in) or token (one a member made for a bot, which never runs out). }
function NewSession(UserId: integer; const Kind, Name: string; Days: integer): string;
begin
  Result := RandomHex(32);
  Exec('INSERT INTO sessions (token_hash, user_id, kind, name, expires) VALUES (:t, :u, :k, :n, ' + SqlIf(':d > 0', SqlAhead(':d2', suDay), 'NULL') + ')',
    [Sha256Hex(Result), UserId, Kind, Copy(Name, 1, 60), Days, Days]);
  Exec('UPDATE users SET last_seen = NOW() WHERE id = :u', [UserId]);
end;

{ Too many tries from one address in a while: slow down. }
function TooManyTries(const Ip, Kind: string; Limit, Minutes: integer): boolean;
begin
  // a limit of 0 set by mistake would refuse everyone, the admin included: at least one try is allowed
  Result := IntValue('SELECT COUNT(*) FROM attempts WHERE ip = :i AND kind = :k' + ' AND at > ' + SqlAgo(':m', suMinute), [Ip, Kind, Minutes]) >= Max(Limit, 1);
end;

procedure NoteTry(const Ip, Kind: string);
begin
  Exec('INSERT INTO attempts (ip, kind) VALUES (:i, :k)', [Ip, Kind]);
end;

procedure StartWebSession(AResponse: TResponse; UserId: integer);
begin
  SetSessionCookie(AResponse, NewSession(UserId, 'web', '', SessionDays), SessionDays);
end;

{ Answers a sign-in or sign-up: a cookie for the page, a token for an app. }
procedure Welcome(ARequest: TRequest; AResponse: TResponse; UserId: integer; Answer: TJSONObject);
begin
  if ARequest.ContentFields.Values['app'] <> '' then
    Answer.Add('token', NewSession(UserId, 'app', ARequest.ContentFields.Values['app'], AppSessionDays))
  else
    StartWebSession(AResponse, UserId);
  SendJSON(AResponse, Answer);
end;

function AddMember(const Name, Email, Auth, Pub, Wrapped: string; Verified: boolean): integer;
var
  Hash, Refused: string;
  Hook: TMemberHook;
begin
  Hash := '';
  if Auth <> '' then
    Hash := HashSecret(Auth);
  LockMemberNames;
  try
    Refused := NameRefusal(Name);
    if Refused <> '' then
      raise ENameUnavailable.Create(Refused);
    Exec('INSERT INTO users (name, auth_name, key_name, email, verified, auth_hash, public_key, wrapped_key)' + ' VALUES (:n, :a, :k, :e, :v, :h, :p, :w)',
      [Name, Name, Name, LowerCase(Email), IfThen(Verified, 1, IfThen(MailReady, 0, UNCHECKED)), Hash, Pub, Wrapped]);
    Result := LastId;
    for Hook in NewMemberHooks do
      Hook(Result);
  finally
    UnlockMemberNames;
  end;
end;

function ValidEmail(const S: string): boolean;
var
  At: integer;
  C: char;
begin
  // no control characters and none that end an address in a mail server's own words
  for C in S do
    if (C < ' ') or (C in ['<', '>', ',', ';', '"', '\']) then
      Exit(False);
  At := Pos('@', S);
  Result := (Length(S) <= 200) and (At > 1) and (Pos('.', Copy(S, At, MaxInt)) > 2) and (Pos(' ', S) = 0) and (Pos('@', Copy(S, At + 1, MaxInt)) = 0) and not S.EndsWith('.');
end;

function EmailTaken(const Email: string; ExceptUser: integer): boolean;
begin
  // only an address its holder confirmed is theirs: one merely typed in reserves nothing
  Result := IntValue('SELECT COUNT(*) FROM users WHERE email = :e AND id <> :u AND verified = 1', [LowerCase(Email), ExceptUser]) > 0;
end;

procedure SendAddressCheck(UserId: integer; const NewEmail: string);
var
  Token, Who, Email, Link: string;
begin
  // Not inside "with Query": Name there is the query's own.
  Who := VarToStr(Value('SELECT name FROM users WHERE id = :u', [UserId]));
  Email := NewEmail;
  if Email = '' then
    Email := VarToStr(Value('SELECT email FROM users WHERE id = :u', [UserId]));
  if Email = '' then
    Exit;
  Token := RandomHex(32);
  Exec('INSERT INTO email_checks (token_hash, user_id, email, expires) VALUES (:t, :u, :e, ' + SqlAhead('2', suDay) + ')',
    [Sha256Hex(Token), UserId, NewEmail]);
  Link := Setting('url', '') + '/verify/' + Token + #10#10;
  if NewEmail = '' then
    SendMail(Email, 'Confirm your address for ' + Setting('name', 'Exedra'),
      'Hello ' + Who + ','#10#10 + 'Someone, hopefully you, made the account ' + Who + ' at ' + Setting('url', '') + ' with this address.' +
      ' Open this link to confirm it, and you can talk there:'#10#10 + Link +
      'The link works for two days. If it was not you, do nothing: the account stays unable to post.'#10)
  else
    SendMail(Email, 'Confirm your new address for ' + Setting('name', 'Exedra'),
      'Hello ' + Who + ','#10#10 + 'Someone, hopefully you, asked to use this address for the account ' + Who + ' at ' + Setting('url', '') +
      '.' + ' Open this link to confirm it:'#10#10 + Link + 'The link works for two days. If it was not you, do nothing: the account keeps the address it has.'#10);
end;

{ GET /verify/:token  the link from that mail }
procedure CheckAddress(ARequest: TRequest; AResponse: TResponse);
var
  Id: integer;
  NewEmail: string;
begin
  CheckConnection;
  if not TokenTry(ARequest, AResponse) then
    Exit;
  Id := 0;
  if IsHex(ARequest.RouteParams['token'], 64) then
    Id := IntValue('SELECT user_id FROM email_checks WHERE token_hash = :t AND expires > NOW()', [Sha256Hex(ARequest.RouteParams['token'])]);
  // the address the link was mailed to, when it is to take the place of the account's
  NewEmail := VarToStr(Value('SELECT email FROM email_checks WHERE token_hash = :t', [Sha256Hex(ARequest.RouteParams['token'])]));
  if Id = 0 then
  begin
    SendText(AResponse, 410, 'That link has run out or was used already. Sign in and ask for a new one.');
  end
  else
  begin
    // the address this link proves: the new one, or the account's own
    if NewEmail = '' then
      NewEmail := VarToStr(Value('SELECT email FROM users WHERE id = :u', [Id]));
    if NewEmail = '' then
      SendText(AResponse, 410, 'That link has run out or was used already. Sign in and ask for a new one.')
    else if EmailTaken(NewEmail, Id) then
      SendText(AResponse, 409, 'Another account uses that address.')
    else
    begin
      Exec('START TRANSACTION', []);
      try
        Exec('UPDATE users SET email = :e, verified = 1 WHERE id = :u', [NewEmail, Id]);
        // whoever else typed it in without proving it lets go of it
        Exec('DELETE FROM email_checks WHERE user_id = :u OR user_id IN (SELECT id FROM users WHERE email = :e AND id <> :v AND verified <> 1)', [Id, NewEmail, Id]);
        Exec('UPDATE users SET email = '''' WHERE email = :e AND id <> :u AND verified <> 1', [NewEmail, Id]);
        Exec('COMMIT', []);
      except
        Exec('ROLLBACK', []);
        raise;
      end;
      AResponse.SendRedirect('/');
    end;
  end;
end;

{ POST /api/verify  email: a new link (to a corrected address) }
procedure CheckAgain(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Email: string;
begin
  CheckConnection;
  if FromAnotherSite(ARequest) then
  begin
    SendText(AResponse, 403, 'Send this from a page of this site.');
    Exit;
  end;
  Me := CurrentMember(ARequest);
  Email := Trim(ARequest.ContentFields.Values['email']);
  if Me.Id = 0 then
    SendText(AResponse, 403, 'Sign in first.')
  else if IntValue('SELECT verified FROM users WHERE id = :u', [Me.Id]) = 1 then
    SendText(AResponse, 200, 'Your address is confirmed already.')
  else if TooManyTries(ClientIp(ARequest), 'verify', 3, 60) then
    SendText(AResponse, 429, 'Three links an hour is the most. Look in your spam folder too.')
  else if (Email <> '') and not ValidEmail(Email) then
    SendText(AResponse, 400, 'That does not look like an email address.')
  else if (Email <> '') and EmailTaken(Email, Me.Id) then
    SendText(AResponse, 409, 'Another account uses that address.')
  else
  begin
    if Email <> '' then
    begin
      Exec('UPDATE users SET email = :e WHERE id = :u', [LowerCase(Email), Me.Id]);
      // a link sent to the old address must not confirm the new one
      Exec('DELETE FROM email_checks WHERE user_id = :u', [Me.Id]);
    end;
    NoteTry(ClientIp(ARequest), 'verify');
    SendAddressCheck(Me.Id);
    SendText(AResponse, 200, 'Sent. Open the link in it to confirm.');
  end;
end;

{ The member's own password given again, as the sign-in key the browser
  makes from it (field current), before a change only the account's owner
  should make.  An account with no password yet passes.  A wrong one is
  answered here. }
function OwnPassword(ARequest: TRequest; AResponse: TResponse; UserId: integer): boolean;
var
  Stored, Current: string;
begin
  Stored := VarToStr(Value('SELECT auth_hash FROM users WHERE id = :u', [UserId]));
  Current := ARequest.ContentFields.Values['current'];
  // the account's own count of tries, whatever address they come from
  if (Stored <> '') and not AllowAttempt('member ' + IntToStr(UserId), 'ownpw', SettingInt('password_tries', 10), 15) then
  begin
    SendText(AResponse, 429, 'Too many tries. Wait a while and try again.');
    Exit(False);
  end;
  Result := (Stored = '') or (IsHex(Current, 64) and CheckSecret(Current, Stored));
  if not Result then
  begin
    Strike(ClientIp(ARequest), 'password');
    SendText(AResponse, 403, 'That is not the password of this account.');
  end;
end;

{ POST /api/email  email, current: another address for the account.  With
  mail on, the new one takes over when the link mailed to it is opened and
  the old one stays until then; without mail it is saved as given. }
procedure ChangeEmail(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Email: string;
begin
  CheckConnection;
  if not NeedMember(ARequest, AResponse, Me) then
    Exit;
  Email := LowerCase(Trim(ARequest.ContentFields.Values['email']));
  if MailReady and TooManyTries(ClientIp(ARequest), 'verify', 3, 60) then
    SendText(AResponse, 429, 'Three links an hour is the most. Look in your spam folder too.')
  else if (MailReady or (Email <> '')) and not ValidEmail(Email) then
    SendText(AResponse, 400, 'That does not look like an email address.')
  else if (Email <> '') and EmailTaken(Email, Me.Id) then
    SendText(AResponse, 409, 'Another account uses that address.')
  else if not OwnPassword(ARequest, AResponse, Me.Id) then
    Exit
  else if IntValue('SELECT COUNT(*) FROM users WHERE id = :u AND email = :e AND verified <> :v', [Me.Id, Email, UNCHECKED]) > 0 then
    SendText(AResponse, 200, 'That is your address already.')
  else if MailReady then
  begin
    // one change waits at a time: a link to an address given before is no use now
    Exec('DELETE FROM email_checks WHERE user_id = :u', [Me.Id]);
    NoteTry(ClientIp(ARequest), 'verify');
    SendAddressCheck(Me.Id, Email);
    SendText(AResponse, 200, 'Sent. Open the link in it, and your account uses the new address.');
  end
  else
  begin
    // nobody confirmed this one: no mail goes to it until a link to it is opened
    Exec('UPDATE users SET email = :e, verified = :v WHERE id = :u', [Email, UNCHECKED, Me.Id]);
    SendText(AResponse, 200, 'Saved.');
  end;
end;

{ POST /api/signup  name, email, auth, pub, wrapped [, app] }
procedure SignUp(ARequest: TRequest; AResponse: TResponse);
var
  Name, Email, Auth, Pub, Wrapped, Refused: string;
  Id: integer;
begin
  CheckConnection;
  with ARequest.ContentFields do
  begin
    Name := Values['name'];
    Email := Trim(Values['email']);
    Auth := Values['auth'];
    Pub := Values['pub'];
    Wrapped := Values['wrapped'];
  end;
  if Setting('registration', 'open') <> 'open' then
    SendText(AResponse, 403, 'New accounts are closed here for now.')
  else if TooManySignups(ClientIp(ARequest)) then
    SendText(AResponse, 429, 'Too many new accounts from here. Try again later.')
  else if not (IsHex(Auth, 64) and IsBase64(Pub, 400) and IsBase64(Wrapped, 600)) then
    SendText(AResponse, 400, 'That sign-up did not come from this site''s page.')
  else if MemberExists(Name) then
    SendText(AResponse, 409, 'That name is taken.')
  else
  begin
    Refused := NameRefusal(Name);
    if Refused <> '' then
      SendText(AResponse, 409, Refused)
    else if not ValidName(Name) then
      SendText(AResponse, 400, NameRule)
    else if (Email <> '') and not ValidEmail(Email) then
      SendText(AResponse, 422, 'That is not an email address.')
    else if MailReady and not ValidEmail(Email) then
      SendText(AResponse, 422, 'A new account needs an email address, to confirm it is a person.')
    else if (Email <> '') and EmailTaken(Email) then
      SendText(AResponse, 409, 'Another account uses that address.')
    else
    begin
      try
        Id := AddMember(Name, Email, Auth, Pub, Wrapped, False);
      except
        on E: ENameUnavailable do
        begin
          SendText(AResponse, 409, E.Message);
          Exit;
        end;
      end;
      if MailReady then
        SendAddressCheck(Id);
      NoteTry(ClientIp(ARequest), 'signup');
      Welcome(ARequest, AResponse, Id, TJSONObject.Create(['name', Name]));
    end;
  end;
end;

function FromAnotherSite(ARequest: TRequest): boolean;
var
  Origin: string;
begin
  Origin := ARequest.GetFieldByName('Origin');
  Result := SameText(ARequest.GetFieldByName('Sec-Fetch-Site'), 'cross-site') or ((Origin <> '') and not SameText(Copy(Origin, Pos('//', Origin) + 2, MaxInt), ARequest.Host));
end;

{ POST /api/signin  name, auth [, app].  Answers with the wrapped private
  key, which only the one who knows the password can open.  Not from
  another site's form: that would sign a visitor in as someone else. }
procedure SignIn(ARequest: TRequest; AResponse: TResponse);
var
  Auth, Ip: string;
  Id: integer;
  Answer: TJSONObject;
begin
  CheckConnection;
  if FromAnotherSite(ARequest) then
  begin
    SendText(AResponse, 403, 'Sign in on this site.');
    Exit;
  end;
  Auth := ARequest.ContentFields.Values['auth'];
  Ip := ClientIp(ARequest);
  if not AllowAttempt(Ip, 'authtry', SettingInt('signin_tries', 10), 1) or TooManyTries(Ip, 'signin', SettingInt('password_tries', 10), 15) then
  begin
    SendText(AResponse, 429, 'Too many tries. Wait a few minutes.');
    Exit;
  end;
  Answer := nil;
  Id := 0;
  with Query('SELECT id, name, auth_hash, wrapped_key FROM users WHERE name = :n', [ARequest.ContentFields.Values['name']]) do
  try
    if not EOF and IsHex(Auth, 64) and CheckSecret(Auth, Fields[2].AsString) then
    begin
      Id := Fields[0].AsInteger;
      Answer := TJSONObject.Create(['name', Fields[1].AsString, 'wrapped', Fields[3].AsString]);
    end;
  finally
    Free;
  end;
  if Answer = nil then
  begin
    NoteTry(Ip, 'signin');
    Strike(Ip, 'password');
    SendText(AResponse, 403, 'That name and password do not match.');
  end
  else
    Welcome(ARequest, AResponse, Id, Answer);
end;

procedure SignOut(ARequest: TRequest; AResponse: TResponse);
var
  Token: string;
begin
  CheckConnection;
  if FromAnotherSite(ARequest) then
  begin
    SendText(AResponse, 403, 'Send this from a page of this site.');
    Exit;
  end;
  Token := TokenOf(ARequest);
  if IsHex(Token, 64) then
  begin
    // Its live pages go too; the member's other ones come straight back.
    DropUser(CurrentMember(ARequest).Id);
    Exec('DELETE FROM sessions WHERE token_hash = :t', [Sha256Hex(Token)]);
  end;
  SetSessionCookie(AResponse, '', -1);
  SendText(AResponse, 200, 'ok');
end;

{ For a change to the account's own keys or password: signed in is enough,
  since keys come before the address is confirmed.  Tries are counted, as
  each one costs a password check. }
function NeedSignedIn(ARequest: TRequest; AResponse: TResponse; out Me: TMember): boolean;
begin
  CheckConnection;
  Me := Default(TMember);
  Result := False;
  if FromAnotherSite(ARequest) then
    SendText(AResponse, 403, 'Send this from a page of this site.')
  else if TokenTry(ARequest, AResponse) then
  begin
    Me := CurrentMember(ARequest);
    Result := Me.Id > 0;
    if not Result then
      SendText(AResponse, 403, 'Sign in first.');
  end;
end;

{ POST /api/keys  auth, pub, wrapped: the keys for locked private messages,
  for an account that has none yet (made on IRC or by signing in elsewhere).
  Without a password the account gets this one; with one, auth must match. }
procedure SaveKeys(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Auth, Pub, Wrapped, Stored: string;
begin
  if not NeedSignedIn(ARequest, AResponse, Me) then
    Exit;
  with ARequest.ContentFields do
  begin
    Auth := Values['auth'];
    Pub := Values['pub'];
    Wrapped := Values['wrapped'];
  end;
  Stored := VarToStr(Value('SELECT auth_hash FROM users WHERE id = :u', [Me.Id]));
  if not (IsHex(Auth, 64) and IsBase64(Pub, 400) and IsBase64(Wrapped, 600)) then
    SendText(AResponse, 400, 'That did not come from this site''s page.')
  else if VarToStr(Value('SELECT public_key FROM users WHERE id = :u', [Me.Id])) <> '' then
    SendText(AResponse, 409, 'This account has its keys already.')
  else if (Stored <> '') and not AllowAttempt('member ' + IntToStr(Me.Id), 'ownpw', SettingInt('password_tries', 10), 15) then
    SendText(AResponse, 429, 'Too many tries. Wait a while and try again.')
  else if (Stored <> '') and not CheckSecret(Auth, Stored) then
  begin
    Strike(ClientIp(ARequest), 'password');
    SendText(AResponse, 403, 'That is not the password of this account.');
  end
  else
  begin
    Exec('UPDATE users SET auth_hash = :h, public_key = :p, wrapped_key = :w WHERE id = :u',
      [HashSecret(Auth), Pub, Wrapped, Me.Id]);
    SendText(AResponse, 200, 'ok');
  end;
end;

{ The key the browser sends to sign in (static/keys.js keysFrom), made here
  from the password itself, for IRC clients that send that. }
function AuthFromPassword(const Name, Password: string): string;
var
  Master, Prk, Info: TBytes;
begin
  // The salt says beginend, the program's first name, and must stay so: every
  // stored password was made with it (keys.js the same).
  Master := TKDF.TPBKDF2_HMAC.CreatePBKDF2_HMAC(THashFactory.TCrypto.CreateSHA2_256(), TEncoding.UTF8.GetBytes(unicodestring(Password)),
    TEncoding.UTF8.GetBytes(unicodestring('beginend:' + LowerCase(Name))), 600000).GetBytes(32);
  // HKDF with a zero salt and one block of output (RFC 5869).
  SetLength(Prk, 32);
  FillChar(Prk[0], 32, 0);
  Prk := THashFactory.THMAC.CreateHMAC(THashFactory.TCrypto.CreateSHA2_256(), Prk).ComputeBytes(Master).GetBytes;
  Info := Concat(TEncoding.UTF8.GetBytes('sign in'), [byte(1)]);
  Result := LowerCase(TConverters.ConvertBytesToHexString(THashFactory.THMAC.CreateHMAC(THashFactory.TCrypto.CreateSHA2_256(), Prk).ComputeBytes(Info).GetBytes, False));
end;

function PasswordMatches(const Name, Password: string): boolean;
var
  Stored, SaltName: string;
begin
  Stored := VarToStr(Value('SELECT auth_hash FROM users WHERE name = :n', [Name]));
  SaltName := VarToStr(Value('SELECT auth_name FROM users WHERE name = :n', [Name]));
  Result := (Stored <> '') and CheckSecret(AuthFromPassword(SaltName, Password), Stored);
end;

{ GET /api/auth-name?name=  the password salt's name, stable across renames. }
procedure ShowAuthName(ARequest: TRequest; AResponse: TResponse);
var
  SaltName: string;
begin
  CheckConnection;
  SaltName := VarToStr(Value('SELECT auth_name FROM users WHERE name = :n', [ARequest.QueryFields.Values['name']]));
  if SaltName = '' then
    SaltName := ARequest.QueryFields.Values['name'];
  AResponse.SetCustomHeader('Cache-Control', 'no-store');
  SendJSON(AResponse, TJSONObject.Create(['name', SaltName]));
end;

function MakePasswordLink(const Name: string; Hours: integer): string;
begin
  Result := '';
  if not MemberExists(Name) or MemberClosed(MemberId(Name)) then
    Exit;
  Result := RandomHex(32);
  Exec('INSERT INTO password_links (token_hash, user_id, expires) VALUES (:t, :u, ' + SqlAhead(':h', suHour) + ')',
    [Sha256Hex(Result), MemberId(Name), Hours]);
end;

{ POST /api/forgot  who (a name or an address): mails a password link to
  the member's confirmed address.  The answer is the same either way, so it
  does not tell who has an account. }
procedure Forgot(ARequest: TRequest; AResponse: TResponse);
var
  Who, Email, Link: string;
  Id: integer;
  Opened: int64;
begin
  CheckConnection;
  Who := Trim(ARequest.ContentFields.Values['who']);
  Opened := StrToInt64Def(ARequest.ContentFields.Values['opened'], 999999);
  if TooManyTries(ClientIp(ARequest), 'forgot', 3, 60) then
  begin
    SendText(AResponse, 429, 'Three links an hour is the most. Look in your spam folder too.');
    Exit;
  end;
  NoteTry(ClientIp(ARequest), 'forgot');
  // the hidden field filled, or the box never opened or sent a moment after
  // opening: a machine filling every form (one did, through Tor, 8 Nov 2026,
  // three times in ten seconds).  The usual answer; nothing is mailed.  A
  // page from before this (no "opened") is not judged.
  if (ARequest.ContentFields.Values['website'] <> '') or (Opened < 700) then
    Id := 0
  else
    Id := IntValue('SELECT id FROM users WHERE (name = :n OR email = :e) AND email <> '''' AND verified = 1' + ' AND banned = 0 LIMIT 1', [Who, Who]);
  // One link a member an hour, however many addresses ask.
  if (Id > 0) and not TooManyTries('member ' + IntToStr(Id), 'forgot', 1, 60) then
  begin
    NoteTry('member ' + IntToStr(Id), 'forgot');
    Who := VarToStr(Value('SELECT name FROM users WHERE id = :u', [Id]));
    Email := VarToStr(Value('SELECT email FROM users WHERE id = :u', [Id]));
    Link := MakePasswordLink(Who, 2);
    SendMail(Email, 'A new password for ' + Setting('name', 'Exedra'),
      'Hello ' + Who + ','#10#10 + 'Someone, hopefully you, asked for a new password for ' + Who + ' at ' + Setting('url', '') + '.' +
      ' Open this link to set one:'#10#10 + Setting('url', '') + '/password/' + Link + #10#10 +
      'The link works for two hours and once. Private conversations you locked with the old password' +
      ' stay closed. If it was not you, do nothing: your password stays as it is.'#10);
  end;
  SendText(AResponse, 200, 'If that name or address has an account with a confirmed address, a link is on' + ' its way. Look in your spam folder too.');
end;

{ POST /api/prefs  any of: mail_notes (1 or 0), auto_away (minutes, 0 for
  never), idle (1: away as "idle" unless away already, 0: back from that),
  and a preference a unit registered, by its name (1 or 0) }
procedure SavePrefs(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Fields: TStrings;
  I: integer;
begin
  CheckConnection;
  if not NeedMember(ARequest, AResponse, Me) then
    Exit;
  Fields := ARequest.ContentFields;
  if Fields.IndexOfName('mail_notes') >= 0 then
    Exec('UPDATE users SET mail_notes = :n WHERE id = :u', [Ord(Fields.Values['mail_notes'] = '1'), Me.Id]);
  if Fields.IndexOfName('auto_away') >= 0 then
    Exec('UPDATE users SET auto_away = :a WHERE id = :u',
      [Min(Max(StrToIntDef(Fields.Values['auto_away'], 10), 0), 240), Me.Id]);
  // Only touches an away the page set, never one typed with /away.
  if Fields.Values['idle'] = '1' then
    Exec('UPDATE users SET away = ''idle'' WHERE id = :u AND away = ''''', [Me.Id])
  else if Fields.Values['idle'] = '0' then
    Exec('UPDATE users SET away = '''' WHERE id = :u AND away = ''idle''', [Me.Id]);
  for I := 0 to High(MemberPrefs) do
    if Fields.IndexOfName(MemberPrefs[I].Name) >= 0 then
      SaveMemberPref(Me.Id, MemberPrefs[I].Name, Fields.Values[MemberPrefs[I].Name] = '1');
  SendText(AResponse, 200, 'ok');
end;

function PasswordLinkName(const Token: string): string;
begin
  Result := '';
  if IsHex(Token, 64) then
    Result := VarToStr(Value('SELECT u.name FROM password_links c JOIN users u ON u.id = c.user_id' + ' WHERE c.token_hash = :t AND c.expires > NOW()', [Sha256Hex(Token)]));
end;

{ POST /api/newpassword  token, auth, pub, wrapped: a new password from a
  password link.  New keys too, so private messages from before cannot be read. }
procedure NewPassword(ARequest: TRequest; AResponse: TResponse);
var
  Token, Auth, Pub, Wrapped, SaltName: string;
  Id: integer;
begin
  CheckConnection;
  if not TokenTry(ARequest, AResponse) then
    Exit;
  with ARequest.ContentFields do
  begin
    Token := Values['token'];
    Auth := Values['auth'];
    Pub := Values['pub'];
    Wrapped := Values['wrapped'];
  end;
  Id := MemberId(PasswordLinkName(Token));
  SaltName := ARequest.ContentFields.Values['name'];
  if SaltName = '' then
    SaltName := PasswordLinkName(Token);
  if Id = 0 then
  begin
    SendText(AResponse, 410, 'That link has run out or was used already. Ask for a new one.');
    Exit;
  end;
  if not (ValidRenameName(SaltName) and IsHex(Auth, 64) and IsBase64(Pub, 400) and IsBase64(Wrapped, 600)) then
  begin
    SendText(AResponse, 400, 'That did not come from this site''s page.');
    Exit;
  end;
  // the link is used up once: its row locked, so a second use at the same
  // moment waits, then finds it gone
  Exec('START TRANSACTION', []);
  try
    if IntValue('SELECT user_id FROM password_links WHERE token_hash = :t AND expires > NOW() FOR UPDATE', [Sha256Hex(Token)]) <> Id then
    begin
      Exec('ROLLBACK', []);
      SendText(AResponse, 410, 'That link has run out or was used already. Ask for a new one.');
      Exit;
    end;
    Exec('UPDATE users SET auth_hash = :h, public_key = :p, wrapped_key = :w, auth_name = :a WHERE id = :u',
      [HashSecret(Auth), Pub, Wrapped, SaltName, Id]);
    Exec('DELETE FROM password_links WHERE user_id = :u', [Id]);
    // Apps and bots too: a new password is often for an account someone took.
    Exec('DELETE FROM sessions WHERE user_id = :u', [Id]);
    Exec('COMMIT', []);
  except
    Exec('ROLLBACK', []);
    raise;
  end;
  DropUser(Id);
  StartWebSession(AResponse, Id);
  SendText(AResponse, 200, 'ok');
end;

{ POST /api/password  current, auth, wrapped [, pub, app]: a new password
  from the member who knows the old one.  The browser wraps the same
  private key again, so private messages stay readable; pub is taken only
  from an account that had no keys.  Every sign-in of the account ends, as
  after a password link, and this one starts anew. }
procedure ChangePassword(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Auth, Pub, Wrapped: string;
begin
  if not NeedSignedIn(ARequest, AResponse, Me) then
    Exit;
  Auth := ARequest.ContentFields.Values['auth'];
  Wrapped := ARequest.ContentFields.Values['wrapped'];
  Pub := VarToStr(Value('SELECT public_key FROM users WHERE id = :u', [Me.Id]));
  if Pub = '' then
    Pub := ARequest.ContentFields.Values['pub'];
  if VarToStr(Value('SELECT auth_hash FROM users WHERE id = :u', [Me.Id])) = '' then
    SendText(AResponse, 409, 'This account has no password yet. Set one first.')
  else if not (IsHex(Auth, 64) and IsBase64(Pub, 400) and IsBase64(Wrapped, 600)) then
    SendText(AResponse, 400, 'That did not come from this site''s page.')
  else if OwnPassword(ARequest, AResponse, Me.Id) then
  begin
    Exec('UPDATE users SET auth_hash = :h, public_key = :p, wrapped_key = :w WHERE id = :u',
      [HashSecret(Auth), Pub, Wrapped, Me.Id]);
    Exec('DELETE FROM password_links WHERE user_id = :u', [Me.Id]);
    // Apps and bots too, as after a password link.
    Exec('DELETE FROM sessions WHERE user_id = :u', [Me.Id]);
    DropUser(Me.Id);
    Welcome(ARequest, AResponse, Me.Id, TJSONObject.Create(['name', Me.Name]));
  end;
end;

{ POST /api/close  current (the password's sign-in key; an account with no
  password sends its own name as name instead), anonymous (1: leave no
  name): the member closes their own account. }
procedure CloseOwn(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Refused: string;
begin
  if not NeedSignedIn(ARequest, AResponse, Me) then
    Exit;
  // with no password to ask for, the name typed out shows it is meant
  if (VarToStr(Value('SELECT auth_hash FROM users WHERE id = :u', [Me.Id])) = '') and (ARequest.ContentFields.Values['name'] <> Me.Name) then
    SendText(AResponse, 400, 'Type your name as it is written, to show you mean it.')
  else if OwnPassword(ARequest, AResponse, Me.Id) then
  begin
    Refused := CloseMember(Me.Id, Me.Id, '', (ARequest.ContentFields.Values['anonymous'] = '1') or (Setting('closed_names', 'keep') = 'anonymous'));
    if Refused <> '' then
      SendText(AResponse, 409, Refused)
    else
    begin
      Log(Me.Name + ' closed their own account');
      SetSessionCookie(AResponse, '', -1);
      SendText(AResponse, 200, 'ok');
    end;
  end;
end;

{ GET /api/me  who is signed in and what they may do anywhere }
procedure ShowMe(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Answer: TJSONObject;
  Hook: TMeHook;
  Prefs: TJSONArray;
  I: integer;
begin
  CheckConnection;
  Me := CurrentMember(ARequest);
  Answer := TJSONObject.Create(['name', Me.Name, 'roles', Me.Roles, 'banned', Me.Banned, 'verified', Me.Verified, 'can', SitePermissions(Me),
    'ignores', GetJSON('[' + IgnoredIds(Me.Id) + ']')]);
  if Me.Id > 0 then
  begin
    Answer.Add('key_name', VarToStr(Value('SELECT key_name FROM users WHERE id = :u', [Me.Id])));
    with Query('SELECT avatar, away, wrapped_key, auth_hash <> '''', email, mail_notes, auto_away' + ' FROM users WHERE id = :u', [Me.Id]) do
    try
      Answer.Add('avatar', AvatarUrl(Fields[0].AsString));
      Answer.Add('away', Fields[1].AsString);
      // Only the password typed in this browser opens it (static/keys.js).
      Answer.Add('wrapped', Fields[2].AsString);
      Answer.Add('password', Fields[3].AsInteger = 1);
      Answer.Add('email', Fields[4].AsString);
      Answer.Add('mail_notes', Fields[5].AsInteger = 1);
      Answer.Add('auto_away', Fields[6].AsInteger);
      Answer.Add('mail_hours', SettingInt('mail_notes_hours', 6));
      // what a closed account shows on what its member wrote: their name, or none
      Answer.Add('closed_names', Setting('closed_names', 'keep'));
    finally
      Free;
    end;
    Prefs := TJSONArray.Create;
    Answer.Add('prefs', Prefs);
    for I := 0 to High(MemberPrefs) do
      if not Assigned(MemberPrefs[I].Shown) or MemberPrefs[I].Shown() then
        Prefs.Add(TJSONObject.Create(['name', MemberPrefs[I].Name, 'words', Say(MemberPrefs[I].Words), 'on', MemberPref(Me.Id, MemberPrefs[I].Name)]));
    for Hook in MeHooks do
      Hook(Me, Answer);
  end;
  SendJSON(AResponse, Answer);
end;

function LikePrefix(const S: string): string;
begin
  Result := StringReplace(StringReplace(S, '\', '\\', [rfReplaceAll]), '_', '\_', [rfReplaceAll]);
  Result := StringReplace(Result, '%', '\%', [rfReplaceAll]) + '%';
end;

{ GET /api/users?q=  names that start with q, for @ completion; the ones
  here lately when q is empty }
procedure FindUsers(ARequest: TRequest; AResponse: TResponse);
var
  List: TJSONArray;
  Q: string;
  Found: TSQLQuery;
begin
  CheckConnection;
  List := TJSONArray.Create;
  Q := ARequest.QueryFields.Values['q'];
  // Both use an index: names in order, or the latest seen first.
  if Q = '' then
    Found := Query('SELECT name, avatar FROM users WHERE banned = 0 AND closed = 0 AND last_seen IS NOT NULL' + ' ORDER BY last_seen DESC LIMIT 8', [])
  else
    Found := Query('SELECT name, avatar FROM users WHERE name LIKE :q AND banned = 0 AND closed = 0' + ' ORDER BY name LIMIT 8', [LikePrefix(Q)]);
  try
    while not Found.EOF do
    begin
      List.Add(TJSONObject.Create(['name', Found.Fields[0].AsString, 'avatar', AvatarUrl(Found.Fields[1].AsString)]));
      Found.Next;
    end;
  finally
    Found.Free;
  end;
  SendJSON(AResponse, List);
end;

{ GET /api/user?name=  a member's profile }
procedure ShowUser(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Answer: TJSONObject;
  Id: integer;
begin
  CheckConnection;
  Me := CurrentMember(ARequest);
  Answer := nil;
  Id := 0;
  with Query('SELECT id, name, roles, bio, links, avatar, ' + IsoTime('created') + ', ' + IsoTime('last_seen') +
      ', public_key, away, banned, posts, closed FROM users WHERE name = :n', [ARequest.QueryFields.Values['name']]) do
  try
    if not EOF then
    begin
      Id := Fields[0].AsInteger;
      Answer := TJSONObject.Create(['name', Fields[1].AsString, 'badge', Badge(Fields[2].AsString), 'roles', Fields[2].AsString, 'bio',
        Fields[3].AsString, 'bio_html', RenderPlain(Fields[3].AsString), 'links', Fields[4].AsString, 'avatar', AvatarUrl(Fields[5].AsString),
        'joined', Fields[6].AsString, 'seen', Fields[7].AsString, 'pub', Fields[8].AsString, 'away', Fields[9].AsString, 'banned',
        Fields[10].AsInteger = 1, 'posts', Fields[11].AsInteger, 'closed', Fields[12].AsInteger = 1]);
      // a former member: the name, and nothing of when or how much
      if Fields[12].AsInteger = 1 then
      begin
        Answer.Strings['joined'] := '';
        Answer.Strings['seen'] := '';
        Answer.Integers['posts'] := 0;
        Answer.Booleans['banned'] := False;
      end;
    end;
  finally
    Free;
  end;
  if Answer = nil then
    SendText(AResponse, 404, 'No member by that name.')
  else
  begin
    Answer.Add('ignored', (Me.Id > 0) and Ignores(Me.Id, Id));
    SendJSON(AResponse, Answer);
  end;
end;

{ POST /api/profile  bio, links }
procedure SaveProfile(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
begin
  CheckConnection;
  if not NeedMember(ARequest, AResponse, Me) then
    Exit;
  Exec('UPDATE users SET bio = :b, links = :l WHERE id = :u',
    [Copy(ARequest.ContentFields.Values['bio'], 1, 2000), Copy(ARequest.ContentFields.Values['links'], 1, 500), Me.Id]);
  SendText(AResponse, 200, 'ok');
end;

{ POST /api/ignore  name, on (1 or 0): their messages fold away for me and
  they cannot send me private messages }
procedure SetIgnore(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Other: integer;
begin
  CheckConnection;
  if FromAnotherSite(ARequest) then
  begin
    SendText(AResponse, 403, 'Send this from a page of this site.');
    Exit;
  end;
  Me := CurrentMember(ARequest);
  Other := MemberId(ARequest.ContentFields.Values['name']);
  if (Me.Id = 0) or (Other = 0) or (Other = Me.Id) then
  begin
    SendText(AResponse, 400, 'Nobody to ignore.');
    Exit;
  end;
  if ARequest.ContentFields.Values['on'] = '1' then
    Exec(SqlInsertIgnore('ignores', 'user_id, ignored_id', ':u, :o'), [Me.Id, Other])
  else
    Exec('DELETE FROM ignores WHERE user_id = :u AND ignored_id = :o', [Me.Id, Other]);
  SendText(AResponse, 200, 'ok');
end;

{ Tokens for bots and scripts.  The token shows once; only its hash is
  kept, and its first 12 characters name it. }

{ GET /api/tokens }
procedure ShowTokens(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  List: TJSONArray;
begin
  CheckConnection;
  if not NeedMember(ARequest, AResponse, Me) then
    Exit;
  List := TJSONArray.Create;
  with Query('SELECT ' + SqlLeft('token_hash', 12) + ', kind, name, ' + IsoTime('created') + ' FROM sessions WHERE user_id = :u AND kind <> ''web'' ORDER BY created DESC',
      [Me.Id]) do
  try
    while not EOF do
    begin
      List.Add(TJSONObject.Create(['id', Fields[0].AsString, 'kind', Fields[1].AsString, 'name', Fields[2].AsString, 'created', Fields[3].AsString]));
      Next;
    end;
  finally
    Free;
  end;
  SendJSON(AResponse, List);
end;

{ POST /api/tokens  name: a new token, or delete=id to take one back }
procedure SaveToken(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Gone, Name: string;
begin
  CheckConnection;
  if not NeedMember(ARequest, AResponse, Me) then
    Exit;
  Gone := ARequest.ContentFields.Values['delete'];
  Name := Trim(ARequest.ContentFields.Values['name']);
  if Gone <> '' then
  begin
    Exec('DELETE FROM sessions WHERE user_id = :u AND kind <> ''web'' AND ' + SqlLeft('token_hash', 12) + ' = :i',
      [Me.Id, Gone]);
    DropUser(Me.Id);
    SendText(AResponse, 200, 'ok');
  end
  else if not Can(Me, 'api-tokens') then
    SendText(AResponse, 403, 'Tokens are not open to you here.')
  else if Name = '' then
    SendText(AResponse, 400, 'Name the token after what will use it.')
  else if IntValue('SELECT COUNT(*) FROM sessions WHERE user_id = :u AND kind = ''token''', [Me.Id]) >= 10 then
    SendText(AResponse, 400, 'Ten tokens is the most. Take one back first.')
  else
    SendJSON(AResponse, TJSONObject.Create(['token', NewSession(Me.Id, 'token', Name, 0)]));
end;

{ Chores }

procedure ForgetOldSessions;
begin
  Exec('DELETE FROM sessions WHERE expires < NOW()', []);
  Exec('DELETE FROM attempts WHERE at < ' + SqlAgo('1', suDay), []);
  Exec('DELETE FROM password_links WHERE expires < NOW()', []);
  Exec('DELETE FROM email_checks WHERE expires < NOW()', []);
end;

initialization
  RegisterRequestLimit('signuptry', 'Account signup', 10, 10, 1);
  LimitRoute('signuptry', '/api/signup', 'POST');
  RegisterRequestLimit('tokens', 'Token changes', 30, 10, 1);
  LimitRoute('tokens', '/api/tokens', 'POST');
  RegisterTable('CREATE TABLE IF NOT EXISTS users (' + ' id INT AUTO_INCREMENT PRIMARY KEY,' + ' name VARCHAR(24) NOT NULL UNIQUE,' +
    ' roles VARCHAR(200) NOT NULL DEFAULT '''',' + ' banned TINYINT NOT NULL DEFAULT 0,' + ' auth_hash VARCHAR(200) NOT NULL,' +
    ' public_key TEXT NOT NULL,' + ' wrapped_key TEXT NOT NULL,' + ' bio TEXT NOT NULL DEFAULT '''',' + ' links VARCHAR(500) NOT NULL DEFAULT '''',' +
    ' avatar VARCHAR(40) NOT NULL DEFAULT '''',' + ' away VARCHAR(200) NOT NULL DEFAULT '''',' + ' posts INT NOT NULL DEFAULT 0,' +
    ' created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,' + ' last_seen DATETIME NULL,' + ' INDEX (last_seen)' + ') CHARACTER SET utf8mb4');
  // Only the SHA-256 of a session token is kept.
  RegisterTable('CREATE TABLE IF NOT EXISTS sessions (' + ' token_hash CHAR(64) PRIMARY KEY,' + ' user_id INT NOT NULL,' +
    ' kind VARCHAR(8) NOT NULL DEFAULT ''web'',' + ' name VARCHAR(60) NOT NULL DEFAULT '''',' + ' created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,' +
    ' expires DATETIME NULL,' + ' INDEX (user_id), INDEX (expires)' + ') CHARACTER SET utf8mb4');
  RegisterTable('CREATE TABLE IF NOT EXISTS attempts (' + ' ip VARCHAR(45) NOT NULL, kind VARCHAR(10) NOT NULL,' +
    ' at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, INDEX (ip, kind, at), INDEX (at))');
  RegisterTable('CREATE TABLE IF NOT EXISTS member_prefs (user_id INT NOT NULL, name VARCHAR(40) NOT NULL, value TINYINT NOT NULL, PRIMARY KEY (user_id, name))');
  RegisterTable('CREATE TABLE IF NOT EXISTS ignores (' + ' user_id INT NOT NULL, ignored_id INT NOT NULL, PRIMARY KEY (user_id, ignored_id))');
  RegisterTable('CREATE TABLE IF NOT EXISTS password_links (' + ' token_hash CHAR(64) PRIMARY KEY, user_id INT NOT NULL, expires DATETIME NOT NULL, INDEX (expires))');
  RegisterTable('CREATE TABLE IF NOT EXISTS email_checks (' + ' token_hash CHAR(64) PRIMARY KEY, user_id INT NOT NULL, expires DATETIME NOT NULL, INDEX (expires))');
  // The address a link was mailed to, when opening it changes the account's.
  RegisterUpgrade('email-checks-new-address', 'ALTER TABLE email_checks ADD COLUMN email VARCHAR(200) NOT NULL DEFAULT ''''');
  // Everyone from before checks of addresses counts as confirmed.
  RegisterUpgrade('users-email', 'ALTER TABLE users ADD COLUMN email VARCHAR(200) NOT NULL DEFAULT '''',' +
    ' ADD COLUMN verified TINYINT NOT NULL DEFAULT 1, ADD INDEX (email)');
  // What a member chose about mail and going away; the mail itself is
  // sent by the part that has something to tell.
  RegisterUpgrade('users-mail-notes', 'ALTER TABLE users ADD COLUMN mail_notes TINYINT NOT NULL DEFAULT 1,' +
    ' ADD COLUMN mail_due DATETIME NULL, ADD COLUMN mailed DATETIME NULL,' +
    ' ADD COLUMN mail_key CHAR(32) NOT NULL DEFAULT '''', ADD COLUMN auto_away SMALLINT NOT NULL DEFAULT 10,' + ' ADD INDEX (mail_due), ADD INDEX (mail_key)');
  RegisterUpgrade('users-stable-names', 'ALTER TABLE users MODIFY name VARCHAR(60) NOT NULL,' +
    ' ADD COLUMN auth_name VARCHAR(60) NOT NULL DEFAULT '''', ADD COLUMN key_name VARCHAR(60) NOT NULL DEFAULT ''''');
  RegisterUpgrade('users-stable-names-fill', 'UPDATE users SET auth_name = name, key_name = name');
  RegisterChore(@ForgetOldSessions, 30);
  RegisterTable('CREATE TABLE IF NOT EXISTS member_addresses (user_id INT NOT NULL, ip VARCHAR(45) NOT NULL,' +
    ' first_seen DATETIME NOT NULL, last_seen DATETIME NOT NULL, hits INT NOT NULL DEFAULT 1,' +
    ' PRIMARY KEY (user_id, ip), INDEX (ip), INDEX (last_seen)) CHARACTER SET utf8mb4');
  // A closed account: the row stays, so what the member wrote keeps its author.
  RegisterUpgrade('users-closed', 'ALTER TABLE users ADD COLUMN closed TINYINT NOT NULL DEFAULT 0, ADD COLUMN closed_at DATETIME NULL,' +
    ' ADD COLUMN closed_by INT NOT NULL DEFAULT 0, ADD COLUMN closed_reason VARCHAR(500) NOT NULL DEFAULT '''', ADD INDEX (closed)');
  // The names members had before a rename: hidden ones are taken and lead nowhere.
  RegisterTable('CREATE TABLE IF NOT EXISTS former_names (name VARCHAR(60) PRIMARY KEY, user_id INT NOT NULL,' +
    ' hidden TINYINT NOT NULL DEFAULT 0, INDEX (user_id)) CHARACTER SET utf8mb4');
  RegisterSetting('closed_names', 'The name a closed account shows (keep: the member''s own; anonymous: "Former member" and a number)', 'keep',
    'choice:keep|anonymous', 'Members');
  RegisterSetting('member_addresses_days', 'Days a member''s address is kept after it was last used (admins see them in Members)',
    '180', 'number', 'Members');
  RegisterChore(@ForgetOldAddresses, 60);
  InitCriticalSection(AddressLock);
  InitCriticalSection(ForwardLock);
  AddressSeen := TStringList.Create;
  AddressSeen.Sorted := True;
  AddressSeen.Duplicates := dupIgnore;
  RegisterPermission('api-tokens', 'Make tokens for bots and scripts', 'member');
  HTTPRouter.RegisterRoute('/api/signup', rmPost, @SignUp);
  HTTPRouter.RegisterRoute('/api/signin', rmPost, @SignIn);
  HTTPRouter.RegisterRoute('/api/auth-name', rmGet, @ShowAuthName);
  HTTPRouter.RegisterRoute('/api/signout', rmPost, @SignOut);
  HTTPRouter.RegisterRoute('/api/me', rmGet, @ShowMe);
  HTTPRouter.RegisterRoute('/api/keys', rmPost, @SaveKeys);
  HTTPRouter.RegisterRoute('/api/verify', rmPost, @CheckAgain);
  HTTPRouter.RegisterRoute('/verify/:token', rmGet, @CheckAddress);
  HTTPRouter.RegisterRoute('/api/newpassword', rmPost, @NewPassword);
  HTTPRouter.RegisterRoute('/api/password', rmPost, @ChangePassword);
  HTTPRouter.RegisterRoute('/api/email', rmPost, @ChangeEmail);
  HTTPRouter.RegisterRoute('/api/close', rmPost, @CloseOwn);
  HTTPRouter.RegisterRoute('/api/users', rmGet, @FindUsers);
  HTTPRouter.RegisterRoute('/api/user', rmGet, @ShowUser);
  HTTPRouter.RegisterRoute('/api/profile', rmPost, @SaveProfile);
  HTTPRouter.RegisterRoute('/api/prefs', rmPost, @SavePrefs);
  HTTPRouter.RegisterRoute('/api/forgot', rmPost, @Forgot);
  HTTPRouter.RegisterRoute('/api/ignore', rmPost, @SetIgnore);
  HTTPRouter.RegisterRoute('/api/tokens', rmGet, @ShowTokens);
  HTTPRouter.RegisterRoute('/api/tokens', rmPost, @SaveToken);
end.
