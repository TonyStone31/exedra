unit app_profile;

{ The site's page: a member's profile, and on one's own the choices, the
  account, the other sign-ins and the tokens. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web, WebOrWorker, app_helpers;

function OpenProfile(Name: JSValue): JSValue; async;
function ConfirmBox: TEl;
function Shared(Key: JSValue; Value: JSValue = undefined): string;
procedure StartAway;

implementation

uses app_router;

type
  // Web's FormData takes a text or a blob; the file comes as it is.
  TFields = class external name 'FormData'(TJSObject)
    constructor new;
    procedure append(const Name: string; Value: JSValue);
  end;

var
  LastTouch: double;

function ParseJSON(Value: JSValue): JSValue; external name 'JSON.parse';

function OneOrZero(Value: JSValue): string;
begin
  if Truthy(Value) then Result := '1' else Result := '0';
end;

function PrefsBox: TEl; forward;
function AccountBox: TEl; forward;
function SignInsBox: TEl; forward;
function TokensBox: TEl; forward;
procedure EditProfile(Who: TJSObject; Box: TEl); forward;

// ---------------------------------------------------------------- profile

function OpenProfile(Name: JSValue): JSValue; async;
var
  Generation, I: NativeInt;
  Who, P: TJSObject;
  Head, Menu, Card, Face, About, Line, Bio, Links, A, Tools, Edit, Pic, Input: TEl;
  List: TJSArray;

  procedure Chosen(E: TJSEvent); async;
  var
    Form: TFields;
  begin
    Form := TFields.new;
    Form.append('avatar', '1');
    Form.append('file', TJSArray(Input.files)[0]);
    try
      await(JSValue, Post('/api/upload', Form));
      Route(SiteBase.path, False);
    except
      Failed(JSExceptValue);
    end;
  end;

begin
  Generation := S.generation;
  Who := TJSObject(await(Get('/api/user?name=' + Enc(Name))));
  if Generation <> S.generation then Exit;
  S.title := Who['name'];
  Head := Find('#roomhead');
  Menu := IconButton('menu', T('Channels'), 'menubtn');
  Menu.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin ToggleMenu; end));
  Head.add(Menu, El('div', 'titles'));
  Find('.titles', Head).appendChild(El('h1', '', Who['name']));

  Card := El('section', 'profile');
  Face := Avatar(Who['name'], Who['avatar'], 'big');
  Card.appendChild(Face);
  About := El('div', 'about');
  Line := El('h2', '', Who['name']);
  if Truthy(Who['badge']) then Line.appendChild(El('span', 'role', Who['badge']));
  if Truthy(Who['banned']) then Line.appendChild(El('span', 'role', T('banned')));
  About.appendChild(Line);
  if Truthy(Who['away']) then About.appendChild(El('p', 'away', T('Away: %s', Who['away'])));
  // a closed account: the name on what its member wrote, and nothing of when
  if Truthy(Who['closed']) then About.appendChild(El('p', 'seen', T('Former member')))
  else if Truthy(Who['seen']) then About.appendChild(El('p', 'seen', T('Joined %s · last here %s', DateText(Who['joined']), Ago(Who['seen']))))
  else About.appendChild(El('p', 'seen', T('Joined %s', DateText(Who['joined']))));
  Bio := El('div', 'bio');
  // One line of the browser's own, so the reason goes into the built script with it.
  asm Bio.innerHTML = Who.bio_html;   // safe html: rendered by the server, HTML escaped
  end;
  About.appendChild(Bio);
  if Truthy(Who['links']) then
  begin
    Links := El('p', 'links');
    List := TJSArray(TJSString(Who['links']).split(TJSRegexp.new('\s+')));
    for I := 0 to List.length - 1 do
      if TJSRegexp.new('^https?:\/\/').test(String(List[I])) then
      begin
        A := Link(List[I], '', TJSString(List[I]).replace(TJSRegexp.new('^https?:\/\/'), ''));
        A.rel := 'nofollow ugc me';
        A.target := '_blank';
        Links.appendChild(A);
      end;
    About.appendChild(Links);
  end;
  Tools := El('div', 'tools');
  if not Truthy(Who['closed']) then
  begin
    I := 0;
    while I < Parts.length do
    begin
      P := TJSObject(Parts[I]);
      if Truthy(P['profileTools']) then TJSFunction(P['profileTools']).call(P, Who, Tools);
      Inc(I);
    end;
  end;
  if Same(Me.name, Who['name']) then
  begin
    Edit := El('button', '', T('Edit profile'));
    Edit.kind := 'button';
    Edit.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin EditProfile(Who, About); end));
    Tools.appendChild(Edit);
    Pic := El('button', '', T('Change picture'));
    Pic.kind := 'button';
    Input := El('input');
    Input.kind := 'file';
    Input.accept := 'image/*';
    Input.hidden := True;
    Pic.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin Input.click; end));
    Input.addEventListener('change', TJSRawEventHandler(@Chosen));
    Tools.add(Pic, Input);
  end;
  About.appendChild(Tools);
  Card.appendChild(About);
  Find('#card').appendChild(Card);
  if Same(Me.name, Who['name']) then Find('#card').add(PrefsBox, AccountBox, SignInsBox);
  if Same(Me.name, Who['name']) and May('api-tokens') then Find('#card').appendChild(TokensBox);

  I := 0;
  while I < Parts.length do
  begin
    P := TJSObject(Parts[I]);
    if Truthy(P['profile']) then await(JSValue, TJSFunction(P['profile']).call(P, Who, Generation));
    Inc(I);
  end;
end;

// Until the address is confirmed: the way to another link, or to fix a
// mistyped address.
function ConfirmBox: TEl;
var
  Form, Email, Again: TEl;

  procedure Submit(E: TJSEvent); async;
  begin
    E.preventDefault;
    try
      Toast(await(JSValue, Post('/api/verify', new(['email', TJSString(Email.value).trim]))));
    except
      Failed(JSExceptValue);
    end;
  end;

begin
  Form := El('form', 'confirmbox');
  Email := El('input');
  Email.kind := 'email';
  Email.placeholder := T('A different address (or leave it)');
  Again := El('button', 'primary', T('Send the link again'));
  Form.add(El('p', 'notice', T('Confirm your email to talk: open the link we mailed you. It can take a minute, and it may be in the spam folder.')), Email, Again);
  Form.addEventListener('submit', TJSRawEventHandler(@Submit));
  Result := Form;
end;

// A box for a password, in the account's forms.
function PasswordInput(const Words: string; Fresh: boolean): TEl;
begin
  Result := El('input');
  Result.kind := 'password';
  Result.placeholder := Words;
  if Fresh then Result.autocomplete := 'new-password' else Result.autocomplete := 'current-password';
  Result.required := True;
end;

// Closing the account: what goes and what stays said first, then the
// password, or the name typed out by an account that has no password.
function LeaveBox: TEl;
var
  Box, Form, Anonymous, Mark, Proof: TEl;
  Named: boolean;
  Words: string;

  procedure Submit(E: TJSEvent); async;
  var
    Fields: TJSObject;
  begin
    E.preventDefault;
    if not window.confirm(T('Close your account for good?')) then Exit;
    try
      Fields := new(['anonymous', OneOrZero(Anonymous.checked)]);
      if Truthy(Me.password) then Fields['current'] := await(JSValue, Keys.passwordProof(Me.name, Proof.value))
      else Fields['name'] := TJSString(Proof.value).trim;
      await(JSValue, Post('/api/close', Fields));
      // the key this browser kept goes too
      try
        await(JSValue, Keys.signOut);
      except
      end;
      window.location.href := SiteBase.url('/');
    except
      Failed(JSExceptValue);
    end;
  end;

begin
  Box := El('details', 'leave');
  Box.appendChild(El('summary', '', T('Close this account')));
  Named := not Same(Me.closedNames, 'anonymous');
  Words := T('Closing your account signs you out everywhere, for good. Your email address, password, picture and profile are wiped, and nobody else can take your name.') + ' ';
  if Named then Words := Words + T('What you wrote here stays, under your name unless you tick the box.')
  else Words := Words + T('What you wrote here stays, shown as written by "Former member".');
  Words := Words + ' ' + T('Where others quoted or mentioned you, your name stays as they typed it. Only an admin can open a closed account again.');
  Box.appendChild(El('p', 'hint', Words));
  Form := El('form', 'invite');
  Anonymous := El('input');
  Anonymous.kind := 'checkbox';
  if Named then
  begin
    Mark := El('label');
    Mark.add(Anonymous, El('span', '', T('Show "Former member" in place of my name on what I wrote')));
    Form.appendChild(Mark);
  end;
  if Truthy(Me.password) then Proof := PasswordInput(T('Your password'), False) else Proof := El('input');
  if not Truthy(Me.password) then
  begin
    Proof.placeholder := T('Type your name, %s, to confirm', Me.name);
    Proof.required := True;
  end;
  Form.add(Proof, El('button', 'primary', T('Close my account')));
  Form.addEventListener('submit', TJSRawEventHandler(@Submit));
  Box.appendChild(Form);
  Result := Box;
end;

// The account's address and password, on the member's own profile.  A
// change of either asks for the password the account has; one made by
// signing in elsewhere has none, and can set its first here.
function AccountBox: TEl;
var
  Box, Address, Email, Pass, Form, Old, Fresh: TEl;

  function Done(Words: JSValue): JSValue; async;
  begin
    await(LoadMe);
    Toast(Words);
    Route(SiteBase.path, False);
  end;

  procedure ChangeAddress(E: TJSEvent); async;
  var
    Fields: TJSObject;
  begin
    E.preventDefault;
    try
      Fields := new(['email', TJSString(Email.value).trim]);
      if Truthy(Pass) then Fields['current'] := await(JSValue, Keys.passwordProof(Me.name, Pass.value));
      await(Done(await(JSValue, Post('/api/email', Fields))));
    except
      Failed(JSExceptValue);
    end;
  end;

  procedure ChangePassword(E: TJSEvent); async;
  begin
    E.preventDefault;
    try
      if Truthy(Old) then await(JSValue, Keys.changePassword(Me.name, Old.value, Fresh.value, Me.wrapped))
      else await(JSValue, Keys.setupKeys(Me.name, Fresh.value));
      if Truthy(Old) then await(Done(T('Your password is changed. Your other devices and apps are signed out.')))
      else await(Done(T('Saved.')));
    except
      Failed(JSExceptValue);
    end;
  end;

begin
  Box := El('details', 'tokens');
  Box.appendChild(El('summary', '', T('Email and password')));
  if Same(Me.verified, False) then
  begin
    Box.open := True;
    Box.appendChild(ConfirmBox);
  end
  else
  begin
    Address := El('form', 'invite');
    Email := El('input');
    Email.kind := 'email';
    if Truthy(Me.email) then Email.value := Me.email else Email.value := '';
    Email.placeholder := T('Email address');
    if Truthy(Me.password) then Pass := PasswordInput(T('Your password'), False) else Pass := nil;
    Address.add(Email);
    if Truthy(Pass) then Address.add(Pass);
    Address.add(El('button', 'primary', T('Change the address')));
    Address.addEventListener('submit', TJSRawEventHandler(@ChangeAddress));
    Box.appendChild(Address);
  end;
  Form := El('form', 'invite');
  if Truthy(Me.password) then Old := PasswordInput(T('Your password'), False) else Old := nil;
  Fresh := PasswordInput(T('New password, 8 characters or more'), True);
  if Truthy(Old) then Form.add(Old)
  else Box.appendChild(El('p', 'hint', T('This account has no password yet. With one you can also sign in here with your name.')));
  if Truthy(Old) then Form.add(Fresh, El('button', 'primary', T('Change the password')))
  else Form.add(Fresh, El('button', 'primary', T('Set a password')));
  Form.addEventListener('submit', TJSRawEventHandler(@ChangePassword));
  Box.appendChild(Form);
  Box.appendChild(LeaveBox);
  Result := Box;
end;

// Mail about missed messages, and when to show as away; saved as soon as
// they change.
function PrefsBox: TEl;
var
  Box, Mail, Check, Hint, Away, After, Receipts, Shown: TEl;
  List: TJSArray;
  I: NativeInt;

  procedure Option(Minutes: NativeInt; const Words: string);
  var
    O: TEl;
  begin
    O := El('option', '', Words);
    O.value := Minutes;
    After.appendChild(O);
  end;

  // A failed save puts the box back as it was.
  procedure MailChanged(E: TJSEvent); async;
  begin
    try
      await(JSValue, Post('/api/prefs', new(['mail_notes', OneOrZero(Check.checked)])));
      Me.mailNotes := Check.checked;
      Toast(T('Saved.'));
    except
      Check.checked := Me.mailNotes;
      Failed(JSExceptValue);
    end;
  end;

  procedure AwayChanged(E: TJSEvent); async;
  begin
    try
      await(JSValue, Post('/api/prefs', new(['auto_away', After.value])));
      Me.autoAway := Number(After.value);
      Toast(T('Saved.'));
    except
      After.value := Me.autoAway;
      Failed(JSExceptValue);
    end;
  end;

  // What the modules add (RegisterMemberPref): a yes or no each.
  procedure ModulePref(Pref: TJSObject);
  var
    Line, Mark: TEl;

    procedure Changed(E: TJSEvent); async;
    var
      Sent: TJSObject;
    begin
      Sent := TJSObject.new;
      Sent[String(Pref['name'])] := OneOrZero(Mark.checked);
      try
        await(JSValue, Post('/api/prefs', Sent));
        Pref['on'] := Mark.checked;
        Toast(T('Saved.'));
      except
        Mark.checked := Pref['on'];
        Failed(JSExceptValue);
      end;
    end;

  begin
    Line := El('label');
    Mark := El('input');
    Mark.kind := 'checkbox';
    Mark.checked := Pref['on'];
    Line.add(Mark, El('span', '', Pref['words']));
    Mark.addEventListener('change', TJSRawEventHandler(@Changed));
    Box.appendChild(Line);
  end;

  procedure ReceiptsChanged(E: TJSEvent); async;
  begin
    try
      await(JSValue, Post('/api/dm/receipts', new(['on', OneOrZero(Shown.checked)])));
      Me.readReceipts := Shown.checked;
      Toast(T('Saved.'));
    except
      Shown.checked := Me.readReceipts;
      Failed(JSExceptValue);
    end;
  end;

begin
  Box := El('section', 'prefs');
  Mail := El('label');
  Check := El('input');
  Check.kind := 'checkbox';
  Check.checked := Me.mailNotes;
  Mail.add(Check, El('span', '', T('Email me about private messages and mentions I miss')));
  if Truthy(Me.email) then
    Hint := El('p', 'hint', TN(Me.mailHours, 'To %1:s, at most one every %0:d hours, and only when something new waits for you.',
      'To %1:s, at most one every %0:d hours, and only when something new waits for you.', Me.email))
  else Hint := El('p', 'hint', T('Your account has no email address.'));
  Check.disabled := not Truthy(Me.email);
  Away := El('label');
  After := El('select');
  Option(0, T('never'));
  Option(5, TN(5, 'after %d minutes', 'after %d minutes'));
  Option(10, TN(10, 'after %d minutes', 'after %d minutes'));
  Option(15, TN(15, 'after %d minutes', 'after %d minutes'));
  Option(30, TN(30, 'after %d minutes', 'after %d minutes'));
  Option(60, T('after an hour'));
  After.value := Me.autoAway;
  Away.add(El('span', '', T('Show me as away when I have not touched the chat')), After);
  Check.addEventListener('change', TJSRawEventHandler(@MailChanged));
  After.addEventListener('change', TJSRawEventHandler(@AwayChanged));
  Box.add(Mail, Hint);
  if Truthy(Me.prefs) then List := TJSArray(Me.prefs) else List := TJSArray.new;
  for I := 0 to List.length - 1 do ModulePref(TJSObject(List[I]));
  Box.appendChild(Away);
  // Read receipts, on a site where each member chooses.
  if jsTypeOf(Me.readReceipts) <> 'undefined' then
  begin
    Receipts := El('label');
    Shown := El('input');
    Shown.kind := 'checkbox';
    Shown.checked := Me.readReceipts;
    Receipts.add(Shown, El('span', '', T('Show others when I have read their private messages')));
    Shown.addEventListener('change', TJSRawEventHandler(@ReceiptsChanged));
    Box.add(Receipts, El('p', 'hint', T('With this off, you do not see when others have read yours either. It shows only between two members who both have it on.')));
  end;
  Result := Box;
end;

// Auto away: no key, click or tap for Me.autoAway minutes in any tab shows
// the member as away ("idle") until they are back.  The tabs share the
// time and the flag; the server leaves an away typed with /away alone.
function Shared(Key: JSValue; Value: JSValue): string;
var
  Kept: JSValue;
begin
  try
    if jsTypeOf(Value) = 'undefined' then
    begin
      Kept := LocalStore.getItem(Key);
      if Truthy(Kept) then Result := String(Kept) else Result := '';
      Exit;
    end;
    LocalStore.setItem(Key, Value);
  except
  end;
  Result := '';
end;

function Nothing(Err: JSValue): JSValue;
begin
end;

procedure Touched(E: TJSEvent);
begin
  if TAnyDate.now - LastTouch < 10000 then Exit;
  LastTouch := TAnyDate.now;
  Shared('touched', Text(LastTouch));
  if Truthy(Me.name) and (Shared('idle') = '1') then
  begin
    Shared('idle', '0');
    TJSPromise(Post('/api/prefs', new(['idle', '0']))).catch(@Nothing);
  end;
end;

procedure StartAway;
var
  Kinds: TJSArray;
  I: NativeInt;
begin
  LastTouch := TAnyDate.now;
  Kinds := TJSArray.new('keydown', 'pointerdown', 'wheel');
  for I := 0 to Kinds.length - 1 do
    document.addEventListener(String(Kinds[I]), TJSRawEventHandler(@Touched), TJSEventListenerOptions(new(['capture', True, 'passive', True])));
  window.setInterval(procedure
    var
      Last: double;
    begin
      Last := Number(Shared('touched'));
      if not Truthy(Last) then Last := 0;
      Last := Max(LastTouch, Last);
      if Truthy(Me.name) and (Me.autoAway > 0) and (Shared('idle') <> '1') and (TAnyDate.now - Last >= Me.autoAway * 60000) then
      begin
        Shared('idle', '1');
        TJSPromise(Post('/api/prefs', new(['idle', '1']))).catch(@Nothing);
      end;
    end, 30000);
end;

// Sign-ins at GitHub, GitLab and the others linked to this account.
function SignInsBox: TEl;
var
  Box, List: TEl;

  function Show: JSValue; async;
  var
    Logins: TJSObject;
    Providers: TJSArray;
    I: NativeInt;

    procedure Provider(P: TJSObject);
    var
      Row, X: TEl;

      procedure Unlink(E: TJSEvent); async;
      begin
        try
          await(JSValue, Post('/api/logins', new(['unlink', P['name']])));
          Show;
        except
          Failed(JSExceptValue);
        end;
      end;

    begin
      Row := El('div', 'person');
      Row.appendChild(El('b', '', P['title']));
      if Truthy(P['login']) then
      begin
        Row.appendChild(El('span', 'dim', T('linked as %s', P['login'])));
        X := El('button', 'small-link', T('Unlink'));
        X.kind := 'button';
        X.addEventListener('click', TJSRawEventHandler(@Unlink));
        Row.appendChild(X);
      end
      else
        Row.appendChild(Link('/signin-with/' + String(P['name']), 'small-link', T('Link')));
      List.appendChild(Row);
    end;

  begin
    Logins := TJSObject(await(Get('/api/logins')));
    Providers := TJSArray(Logins['providers']);
    Box.hidden := Providers.length = 0;
    List.replaceChildren;
    for I := 0 to Providers.length - 1 do Provider(TJSObject(Providers[I]));
  end;

begin
  Box := El('details', 'tokens');
  Box.hidden := True;
  Box.appendChild(El('summary', '', T('Sign in with GitHub, GitLab and others')));
  List := El('div', 'tokenlist');
  Box.appendChild(List);
  TJSPromise(Show).catch(function(Err: JSValue): JSValue begin Failed(Err); end);
  Result := Box;
end;

// Tokens let a bot or a script act as this member (Authorization: Bearer).
function TokensBox: TEl;
var
  Box, List, Form, Name, Make: TEl;

  function Show: JSValue; async;
  var
    Tokens: TJSArray;
    I: NativeInt;

    procedure Token(Tok: TJSObject);
    var
      Row, X: TEl;
      Title: JSValue;

      procedure TakeBack(E: TJSEvent); async;
      begin
        try
          await(JSValue, Post('/api/tokens', new(['delete', Tok['id']])));
          Show;
        except
          Failed(JSExceptValue);
        end;
      end;

    begin
      Row := El('div', 'person');
      Title := Tok['name'];
      if not Truthy(Title) then Title := Tok['kind'];
      Row.add(El('b', '', Title), El('span', 'dim', T('%s, made %s', Tok['kind'], Ago(Tok['created']))));
      X := El('button', 'small-link', T('Take back'));
      X.kind := 'button';
      X.addEventListener('click', TJSRawEventHandler(@TakeBack));
      Row.appendChild(X);
      List.appendChild(Row);
    end;

  begin
    Tokens := TJSArray(await(Get('/api/tokens')));
    List.replaceChildren;
    if Tokens.length = 0 then List.appendChild(El('p', 'dim', T('None yet. Apps you signed in to show here too.')));
    for I := 0 to Tokens.length - 1 do Token(TJSObject(Tokens[I]));
  end;

  procedure Submit(E: TJSEvent); async;
  var
    Made: TJSObject;
    Fresh: TEl;
  begin
    E.preventDefault;
    try
      Made := TJSObject(ParseJSON(await(JSValue, Post('/api/tokens', new(['name', Name.value])))));
      Fresh := El('pre', 'newtoken', Made['token']);
      Form.after(Fresh);
      Form.after(El('p', 'hint', T('Copy it now; it is not shown again. Send it as Authorization: Bearer followed by the token. Anyone holding it can talk as you, so keep it secret.')));
      Name.value := '';
      Show;
    except
      Failed(JSExceptValue);
    end;
  end;

begin
  Box := El('details', 'tokens');
  Box.appendChild(El('summary', '', T('Tokens for bots and scripts')));
  List := El('div', 'tokenlist');
  Box.addEventListener('toggle', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      if Truthy(Box.open) then TJSPromise(Show).catch(function(Err: JSValue): JSValue begin Failed(Err); end);
    end));
  Form := El('form', 'invite');
  Name := El('input');
  Name.placeholder := T('What will use it, such as my-bot');
  Make := El('button', 'primary', T('Make a token'));
  Form.add(Name, Make);
  Form.addEventListener('submit', TJSRawEventHandler(@Submit));
  Box.add(List, Form);
  Result := Box;
end;

procedure EditProfile(Who: TJSObject; Box: TEl);
var
  Form, Bio, Links, Save: TEl;

  procedure Submit(E: TJSEvent); async;
  begin
    E.preventDefault;
    try
      await(JSValue, Post('/api/profile', new(['bio', Bio.value, 'links', Links.value])));
      Route(SiteBase.path, False);
    except
      Failed(JSExceptValue);
    end;
  end;

begin
  Form := El('form', 'editprofile');
  Bio := El('textarea');
  Bio.value := Who['bio'];
  Bio.placeholder := T('A few words about you. Markdown works.');
  Links := El('input');
  Links.value := Who['links'];
  Links.placeholder := T('Links, separated by spaces');
  Save := El('button', 'primary', T('Save'));
  Form.add(Bio, Links, Save);
  Box.appendChild(Form);
  Form.addEventListener('submit', TJSRawEventHandler(@Submit));
end;

end.
