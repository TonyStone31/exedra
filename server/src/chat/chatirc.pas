unit ChatIrc;

{ IRC on the site's rooms and members, with optional TLS and guest reading.
  PASS, SASL PLAIN and NickServ sign members in; REGISTER mails a
  confirmation link. Messages and commands use the chat's permission checks.
  Locked private conversations stay on the web. See docs/CODE-MAP.md. }

{$mode objfpc}{$H+}

interface

{ Starts the listeners the config asks for; server mode only. }
procedure StartIrc;

implementation

uses
  Classes, SysUtils, StrUtils, Variants, DateUtils, Math, base64, fpjson, jsonparser, sockets, ssockets,
  SiteDb, SiteSql, SiteUsers, ChatRooms, ChatMessages, ChatPrivate, SiteFiles, SiteMail, SiteGuard, SiteGuardRules, SiteTls;

const
  LongCode = 5;      // lines of code IRC gets as text; past that, a link
  MaxLine = 400;     // characters of text in one IRC line
  PerAddress = 5;    // connections at once from one address

type
  { TLS for one client.  The listener only makes it: the handshake is left
    to the client's own thread, so a newcomer that says nothing holds up
    nobody else. }
  TIrcTls = class(TSiteTlsHandler)
  public
    function Accept: boolean; override;
    function Handshake: boolean;
  end;

  TIrcListener = class(TThread)
  private
    Server: TInetServer;
    Tls: boolean;
    procedure Connected(Sender: TObject; Data: TSocketStream);
    procedure GetHandler(Sender: TObject; out AHandler: TSocketHandler);
  protected
    procedure Execute; override;
  public
    constructor Create(APort: word; WithTls: boolean);
  end;

  TIrcClient = class(TThread)
  private
    Sock: TSocketStream;
    Ip, Nick, Pass, Buffer, AuthAt: string;
    Me: TMember;
    GotUser, Welcomed, InCap, ServerTime: boolean;
    Rooms: TStringList;           // joined: slugs, each with its room id as the object
    Posted: string;               // ,ids, this connection said, not sent back
    LastMessage, LastDm: integer;
    Heard, Pinged, Looked, Checked: QWord;
    procedure Send(const Line: string);
    procedure Numeric(const Code, Text: string);
    procedure Notice(const Text: string);
    procedure ServiceNotice(const Text: string);
    procedure Handle(const Line: string);
    procedure Welcome;
    function SignIn(const Name, Password: string): boolean;
    procedure NickServ(const Text: string);
    procedure Join(const Channel: string);
    procedure Part(const Channel: string);
    procedure Names(const Slug: string; RoomId: integer);
    procedure Message(const Target, Text: string);
    procedure Command(const Channel, Body: string);
    procedure SendLines(const From, Target, Body, Link: string; Thread: boolean; At: TDateTime);
    procedure Deliver;
  protected
    procedure Execute; override;
  public
    constructor Create(ASock: TSocketStream);
    destructor Destroy; override;
  end;

var
  Listeners: array of TIrcListener;
  Here: TStringList;       // the address of each connection
  HereLock: TRTLCriticalSection;

function ServerName: string;
begin
  Result := Config.ReadString('irc', 'name', 'exedra');
end;

function SiteUrl: string;
begin
  Result := ExcludeTrailingPathDelimiter(Setting('url', ''));
end;

function IsProxy(const Ip: string): boolean;
var
  Proxy: string;
begin
  Result := False;
  for Proxy in Config.ReadString('site', 'proxies', '127.0.0.1').Split([',', ' '], TStringSplitOptions.ExcludeEmpty) do
    if Ip = CanonicalIp(Proxy) then
      Exit(True);
end;

{ Notes one more connection from Ip, or False when there are too many: they
  each hold a database connection, which the site needs too. }
function Arrive(const Ip: string): boolean;
var
  I, Same: integer;
begin
  EnterCriticalSection(HereLock);
  try
    Same := 0;
    for I := 0 to Here.Count - 1 do
      if Here[I] = Ip then
        Inc(Same);
    Result := (Here.Count < Config.ReadInteger('irc', 'max_clients', 50)) and ((Same < PerAddress) or IsProxy(Ip));
    if Result then
      Here.Add(Ip);
  finally
    LeaveCriticalSection(HereLock);
  end;
end;

procedure Leave(const Ip: string);
begin
  EnterCriticalSection(HereLock);
  try
    if Here.IndexOf(Ip) >= 0 then
      Here.Delete(Here.IndexOf(Ip));
  finally
    LeaveCriticalSection(HereLock);
  end;
end;

{ An IRC line in its parts: the command, then the parameters, the last one
  after " :" kept whole.  Tags and a prefix are dropped. }
function SplitLine(Line: string; Params: TStrings): string;
var
  Trailing: string;
  P: integer;
begin
  Params.Clear;
  if Line.StartsWith('@') then
    Delete(Line, 1, Pos(' ', Line + ' '));
  if Line.StartsWith(':') then
    Delete(Line, 1, Pos(' ', Line + ' '));
  Trailing := '';
  P := Pos(' :', Line);
  if P > 0 then
  begin
    Trailing := Copy(Line, P + 2, MaxInt);
    SetLength(Line, P - 1);
  end;
  Params.AddStrings(Line.Split([' '], TStringSplitOptions.ExcludeEmpty));
  if P > 0 then
    Params.Add(Trailing);
  Result := '';
  if Params.Count > 0 then
  begin
    Result := UpperCase(Params[0]);
    Params.Delete(0);
  end;
end;

function Param(Params: TStrings; I: integer): string;
begin
  Result := '';
  if I < Params.Count then
    Result := Params[I];
end;

{ What IRC gets of a message: code blocks of a few lines as they are,
  longer ones as a line with the link, the fences gone. }
function IrcText(const Body, Link: string): string;
var
  Lines, Code: TStringList;
  Line: string;
  InCode: boolean;
begin
  Result := '';
  Lines := TStringList.Create;
  Code := TStringList.Create;
  try
    Lines.Text := Body;
    InCode := False;
    for Line in Lines do
      if TrimLeft(Line).StartsWith('```') then
      begin
        if InCode then
        begin
          if Code.Count > LongCode then
            Result := Result + Format('[code: %d lines] %s', [Code.Count, Link]) + #10
          else
            Result := Result + Code.Text;
          Code.Clear;
        end;
        InCode := not InCode;
      end
      else if InCode then
        Code.Add(Line)
      else
        Result := Result + Line + #10;
    // A fence never closed.
    Result := Result + Code.Text;
  finally
    Code.Free;
    Lines.Free;
  end;
end;

{ TIrcTls }

function TIrcTls.Accept: boolean;
begin
  Result := True;
end;

function TIrcTls.Handshake: boolean;
begin
  Result := inherited Accept;
end;

{ TIrcListener }

constructor TIrcListener.Create(APort: word; WithTls: boolean);
begin
  Tls := WithTls;
  Server := TInetServer.Create(Config.ReadString('irc', 'address', '0.0.0.0'), APort);
  Server.ReuseAddress := True;
  Server.OnConnect := @Connected;
  if Tls then
    Server.OnCreateClientSocketHandler := @GetHandler;
  // Bound here, before the thread starts, so a port that is taken shows at
  // start and two listeners never bind at the same moment.
  Server.Listen;
  FreeOnTerminate := True;
  inherited Create(False);
end;

procedure TIrcListener.GetHandler(Sender: TObject; out AHandler: TSocketHandler);
var
  Handler: TIrcTls;
begin
  Handler := TIrcTls.Create;
  Handler.HandshakeTimeoutMs := 10000;
  Handler.CertificateData.Certificate.FileName := Config.ReadString('irc', 'cert', '');
  Handler.CertificateData.PrivateKey.FileName := Config.ReadString('irc', 'key', '');
  AHandler := Handler;
end;

procedure TIrcListener.Connected(Sender: TObject; Data: TSocketStream);
begin
  // RemoteEndpoint fails on an accepted socket (see TIrcClient.Create), so the older call stays
  {$push}
  {$warn 5066 off}
  if not Arrive(NetAddrToStr(Data.RemoteAddress.sin_addr)) then
    {$pop}
  begin
    Data.Free;
    Exit;
  end;
  try
    TIrcClient.Create(Data);
  except
    // A constructor that fails frees what it was given (Destroy).
    on E: Exception do
      Log('IRC connection: ' + E.Message);
  end;
end;

procedure TIrcListener.Execute;
begin
  try
    Server.StartAccepting;
  except
    on E: Exception do
      Log('IRC listener: ' + E.Message);
  end;
end;

{ TIrcClient }

constructor TIrcClient.Create(ASock: TSocketStream);
begin
  Sock := ASock;
  // RemoteEndpoint raises "Address Family not supported" on an accepted
  // socket (FPC trunk, 27 Oct 2026); the IPv4 address is enough here.
  {$push}
  {$warn 5066 off}
  Ip := CanonicalIp(NetAddrToStr(Sock.RemoteAddress.sin_addr));
  {$pop}
  Nick := '*';
  Rooms := TStringList.Create;
  Me := MemberById(0);
  Heard := GetTickCount64;
  FreeOnTerminate := True;
  inherited Create(False);
end;

destructor TIrcClient.Destroy;
begin
  Leave(Ip);
  Rooms.Free;
  Sock.Free;
  inherited Destroy;
end;

procedure TIrcClient.Send(const Line: string);
var
  Data: string;
begin
  // A line break inside would start a second IRC line, one the sender wrote
  // (an away text or a topic made on the web, say).
  Data := StringReplace(StringReplace(Line, #13, ' ', [rfReplaceAll]), #10, ' ', [rfReplaceAll]) + #13#10;
  Sock.WriteBuffer(Data[1], Length(Data));
end;

procedure TIrcClient.Numeric(const Code, Text: string);
begin
  Send(':' + ServerName + ' ' + Code + ' ' + Nick + ' ' + Text);
end;

procedure TIrcClient.Notice(const Text: string);
var
  Line: string;
begin
  for Line in Text.Split([#10], TStringSplitOptions.ExcludeEmpty) do
    Send(':' + ServerName + ' NOTICE ' + Nick + ' :' + Line);
end;

procedure TIrcClient.ServiceNotice(const Text: string);
begin
  Send(':NickServ!services@' + ServerName + ' NOTICE ' + Nick + ' :' + Text);
end;

procedure TIrcClient.Welcome;
var
  Site: string;
begin
  Welcomed := True;
  Site := Setting('name', 'Exedra');
  if (Pass <> '') and (Me.Id = 0) then
    SignIn(Nick, Pass);
  Numeric('001', ':Welcome to ' + Site + ', ' + Nick);
  Numeric('002', ':Your host is ' + ServerName);
  Numeric('003', ':This server speaks for ' + SiteUrl);
  Numeric('004', ServerName + ' exedra i nt');
  Numeric('005', 'CHANTYPES=# NETWORK=' + Site + ' CASEMAPPING=ascii PREFIX=(o)@ CHANMODES=,,,nt NICKLEN=24' + ' :are supported by this server');
  Numeric('375', ':- ' + Site + ' -');
  Numeric('372', ':- Channels on ' + SiteUrl + ': /list, then /join #' + Setting('start_room', 'lobby') + '.');
  Numeric('372', ':- Setting up your client: ' + SiteUrl + '/irc');
  Numeric('372', ':- Sign in: /msg NickServ IDENTIFY password.  New: /msg NickServ REGISTER password email');
  Numeric('372', ':- Private messages work until a conversation is locked on the web.');
  Numeric('376', ':End of /MOTD command.');
  if Me.Id = 0 then
    if MemberExists(Nick) then
      ServiceNotice(Nick + ' is a member here. Sign in with /msg NickServ IDENTIFY password')
    else
      ServiceNotice('You can read the public channels. To talk, /msg NickServ REGISTER password email');
end;

function TIrcClient.SignIn(const Name, Password: string): boolean;
var
  Found: string;
begin
  Result := False;
  if IsBlocked(Ip) then
  begin
    Terminate;
    Exit;
  end;
  if not AllowAttempt(Ip, 'authtry', SettingInt('signin_tries', 10), 1) or TooManyTries(Ip, 'signin', SettingInt('password_tries', 10), 15) then
  begin
    ServiceNotice('Too many tries. Wait a few minutes.');
    Exit;
  end;
  Found := VarToStr(Value('SELECT name FROM users WHERE name = :n', [Name]));
  if (Found = '') or not PasswordMatches(Found, Password) then
  begin
    NoteTry(Ip, 'signin');
    if Strike(Ip, 'password') then
      Terminate;
    ServiceNotice('That name and password do not match.');
    Exit;
  end;
  Me := MemberById(MemberId(Found));
  if not ValidName(Me.Name) then
  begin
    Me := MemberById(0);
    ServiceNotice('This account name needs the web chat. Sign in at ' + SiteUrl + '.');
    Exit;
  end;
  AuthAt := VarToStr(Value('SELECT auth_hash FROM users WHERE id = :u', [Me.Id]));
  if Welcomed and (Nick <> Me.Name) then
    Send(':' + Nick + ' NICK ' + Me.Name);
  Nick := Me.Name;
  ServiceNotice('You are signed in as ' + Me.Name + '.');
  Result := True;
end;

procedure TIrcClient.NickServ(const Text: string);
var
  Words: TStringArray;
  Verb, Name: string;
begin
  Words := Text.Split([' '], TStringSplitOptions.ExcludeEmpty);
  if Length(Words) = 0 then
    Exit;
  Verb := UpperCase(Words[0]);
  if Verb = 'IDENTIFY' then
  begin
    // IDENTIFY password, or IDENTIFY name password
    if Length(Words) = 2 then
      SignIn(Nick, Words[1])
    else if Length(Words) >= 3 then
      SignIn(Words[1], Words[2]);
  end
  else if Verb = 'REGISTER' then
  begin
    if IsBlocked(Ip) then
    begin
      Terminate;
      Exit;
    end;
    if not AllowAttempt(Ip, 'signuptry', SettingInt('signuptry_address', 10), 1) then
    begin
      ServiceNotice('Too many signup tries. Try again in a minute.');
      Exit;
    end;
    Name := Nick;
    if Me.Id > 0 then
      ServiceNotice('You are signed in already.')
    else if (Length(Words) < 2) or ((Length(Words) < 3) and MailReady) then
      ServiceNotice('Use: /msg NickServ REGISTER password email - a link to confirm it is mailed to you')
    else if Setting('registration', 'open') <> 'open' then
      ServiceNotice('New accounts are closed here for now.')
    else if TooManySignups(Ip) then
      ServiceNotice('Too many new accounts from here. Try again later.')
    else if not ValidName(Name) then
      ServiceNotice('A name is 2 to 24 letters, digits, - _ or a dot inside. Change your nick first.')
    else if MemberExists(Name) then
      ServiceNotice(Name + ' is taken. Change your nick, or IDENTIFY if it is yours.')
    else if NameRefusal(Name) <> '' then
      ServiceNotice(NameRefusal(Name))
    else if Length(Words[1]) < 8 then
      ServiceNotice('A password needs 8 characters or more.')
    else if MailReady and not ValidEmail(Words[2]) then
      ServiceNotice('That does not look like an email address.')
    else if MailReady and EmailTaken(Words[2]) then
      ServiceNotice('Another account uses that address.')
    else
    begin
      if Length(Words) < 3 then
        SetLength(Words, 3);
      AddMember(Name, Words[2], AuthFromPassword(Name, Words[1]), '', '', False);
      NoteTry(Ip, 'signup');
      Me := MemberById(MemberId(Name));
      AuthAt := VarToStr(Value('SELECT auth_hash FROM users WHERE id = :u', [Me.Id]));
      if MailReady then
      begin
        SendAddressCheck(Me.Id);
        ServiceNotice('Welcome, ' + Name + '. Open the link mailed to ' + Words[2] + ' and you can talk.');
      end
      else
        ServiceNotice('Welcome, ' + Name + '.');
      ServiceNotice('The same name and password sign you in at ' + SiteUrl + '.');
    end;
  end
  else
    ServiceNotice('IDENTIFY password - sign in.  REGISTER password email - join with your nick as the name.');
end;

procedure TIrcClient.Names(const Slug: string; RoomId: integer);
var
  List: string;
begin
  List := '';
  with Query('SELECT u.name FROM follows f JOIN users u ON u.id = f.user_id WHERE f.room_id = :r' + ' ORDER BY u.last_seen DESC LIMIT 200', [RoomId]) do
  try
    while not EOF do
    begin
      List := List + Fields[0].AsString + ' ';
      Next;
    end;
  finally
    Free;
  end;
  if (Me.Id = 0) or (Pos(' ' + Nick + ' ', ' ' + List) = 0) then
    List := Nick + ' ' + List;
  Numeric('353', '= #' + Slug + ' :' + Trim(List));
  Numeric('366', '#' + Slug + ' :End of /NAMES list.');
end;

procedure TIrcClient.Join(const Channel: string);
var
  Room: TRoom;
  Slug: string;
  Ids: TStringList;
  I: integer;
begin
  Slug := LowerCase(Channel.TrimLeft(['#']));
  Room := FindRoom(Slug);
  if not CanRead(Me, Room) then
  begin
    Numeric('403', Channel + ' :No such channel');
    Exit;
  end;
  if Rooms.IndexOf(Room.Slug) >= 0 then
    Exit;
  Rooms.AddObject(Room.Slug, TObject(PtrInt(Room.Id)));
  if (Me.Id > 0) and not IsFollower(Me.Id, Room.Id) then
    Follow(Me.Id, Room.Id);
  Send(':' + Nick + '!' + Nick + '@' + ServerName + ' JOIN :#' + Room.Slug);
  if Room.Topic <> '' then
    Numeric('332', '#' + Room.Slug + ' :' + Room.Topic);
  Names(Room.Slug, Room.Id);
  // What was said before, oldest first.
  Ids := TStringList.Create;
  try
    with Query('SELECT message_id FROM message_rooms WHERE room_id = :r ORDER BY message_id DESC LIMIT ' + IntToStr(SettingInt('irc_backlog', 15)), [Room.Id]) do
    try
      while not EOF do
      begin
        Ids.Insert(0, Fields[0].AsString);
        Next;
      end;
    finally
      Free;
    end;
    for I := 0 to Ids.Count - 1 do
      with Query('SELECT COALESCE(u.name, m.author), m.body, m.created FROM messages m' + ' LEFT JOIN users u ON u.id = m.user_id WHERE m.id = :m AND m.deleted = 0',
          [StrToInt(Ids[I])]) do
      try
        if not EOF then
          SendLines(Fields[0].AsString, '#' + Room.Slug, Fields[1].AsString, SiteUrl + '/m/' + Ids[I], False,
            Fields[2].AsDateTime);
      finally
        Free;
      end;
  finally
    Ids.Free;
  end;
end;

procedure TIrcClient.Part(const Channel: string);
var
  Slug: string;
begin
  Slug := LowerCase(Channel.TrimLeft(['#']));
  if Rooms.IndexOf(Slug) < 0 then
    Numeric('442', Channel + ' :You are not on that channel')
  else
  begin
    Rooms.Delete(Rooms.IndexOf(Slug));
    Send(':' + Nick + '!' + Nick + '@' + ServerName + ' PART #' + Slug);
  end;
end;

{ A line from a member the way IRC shows it; a message of several lines
  becomes several.  At, when it is old, goes in front (or in the
  server-time tag a client asked for). }
procedure TIrcClient.SendLines(const From, Target, Body, Link: string; Thread: boolean; At: TDateTime);
var
  Line, Head, Stamp: string;
  Action: boolean;
begin
  Head := '';
  Stamp := '';
  if At > 0 then
    if ServerTime then
      Head := '@time=' + FormatDateTime('yyyy-mm-dd"T"hh:nn:ss".000Z"', At) + ' '
    else
      Stamp := '[' + FormatDateTime('mmm d hh:nn', UniversalTimeToLocal(At)) + '] ';
  Head := Head + ':' + From + '!' + From + '@' + ServerName + ' PRIVMSG ' + Target + ' :';
  // /me arrives as *Name does something*.
  Action := Body.StartsWith('*' + From + ' ') and Body.EndsWith('*') and (Pos(#10, Body) = 0);
  if Action then
  begin
    Send(Head + #1'ACTION ' + Stamp + Copy(Body, Length(From) + 3, Length(Body) - Length(From) - 3) + #1);
    Exit;
  end;
  if Thread then
    Stamp := Stamp + '(thread) ';
  for Line in IrcText(Body, Link).Split([#10], TStringSplitOptions.ExcludeEmpty) do
    if Line.Trim <> '' then
      Send(Head + Stamp + Copy(Line, 1, MaxLine));
end;

{ A private message's JSON (ChatPrivate) for plain text. }
function PlainDm(const Text: string): string;
begin
  with TJSONObject.Create(['t', 'text', 'text', Text]) do
  try
    Result := AsJSON;
  finally
    Free;
  end;
end;

{ PRIVMSG to a channel or a member, NickServ included. }
procedure TIrcClient.Message(const Target, Text: string);
var
  Body, Info, Go: string;
  Other, Id, Status: integer;
  Room: TRoom;
begin
  Body := Text;
  // CTCP ACTION is /me; other CTCP (VERSION, PING) gets nothing.
  if Body.StartsWith(#1) then
    if Body.StartsWith(#1'ACTION ') then
      Body := '/me ' + Copy(Body, 9, MaxInt).TrimRight([#1])
    else
      Exit;
  if SameText(Target, 'NickServ') then
    NickServ(Body)
  else if Me.Id = 0 then
    Numeric('404', Target + ' :Sign in to talk: /msg NickServ IDENTIFY password')
  else if not Me.Verified then
  begin
    // The link may have been opened since signing in.
    Me := MemberById(Me.Id);
    if Me.Verified then
      Message(Target, Text)
    else
      Numeric('404', Target + ' :Open the link mailed to you first, to confirm your address');
  end
  else if Target.StartsWith('#') then
  begin
    Room := FindRoom(LowerCase(Target.TrimLeft(['#'])));
    Id := Say(Me, Room, 0, Body, '', Info, Go, Status);
    if Id > 0 then
      Posted := Posted + IntToStr(Id) + ',';
    if Info <> '' then
      Notice(Info);
  end
  else
  begin
    Other := MemberId(Target);
    if Other = 0 then
      Numeric('401', Target + ' :No such nick')
    else if DmRefused(Me, Other) <> '' then
      Notice(DmRefused(Me, Other))
    else if DmLocked(Me.Id, Other) then
      Notice('Your conversation with ' + Target + ' is locked (end to end encrypted). Read and answer it at ' + SiteUrl + '/dm/' + Target)
    else
      SendPlainDm(Me.Id, Other, PlainDm(Body));
  end;
end;

{ An IRC verb that is one of the page's /commands in a channel. }
procedure TIrcClient.Command(const Channel, Body: string);
var
  Info, Go: string;
  Status: integer;
begin
  if Me.Id = 0 then
    Notice('Sign in first: /msg NickServ IDENTIFY password')
  else
  begin
    Say(Me, FindRoom(LowerCase(Channel.TrimLeft(['#']))), 0, Body, '', Info, Go, Status);
    if Info <> '' then
      Notice(Info);
  end;
end;

procedure TIrcClient.Handle(const Line: string);
var
  Params: TStringList;
  Verb, Target, Text, Name, Raw: string;
  Parts: TStringArray;
  Room: TRoom;
begin
  Params := TStringList.Create;
  try
    Verb := SplitLine(Line, Params);
    Target := Param(Params, 0);
    // while a backup is put back the tables are not whole: nothing is read
    // or written for IRC until it is done
    if Restoring and Welcomed and (Verb <> 'PING') then
    begin
      Notice('A backup is being restored. Back in a minute.');
      Exit;
    end;
    case Verb of
      // HAProxy's PROXY line (send-proxy): who is really connecting, believed
      // only from a proxy the config names.
      'PROXY':
        if not Welcomed and (Params.Count >= 2) and IsProxy(Ip) then
        begin
          Leave(Ip);
          Ip := '';
          if (CanonicalIp(Params[1]) <> '') and Arrive(CanonicalIp(Params[1])) then
            Ip := CanonicalIp(Params[1]);
          if (Ip = '') or IsBlocked(Ip) then
            Terminate;
        end;
      'CAP':
        case UpperCase(Target) of
          'LS': begin
            InCap := True;
            Send(':' + ServerName + ' CAP * LS :sasl server-time');
          end;
          'REQ': begin
            Text := Param(Params, 1);
            if Pos('server-time', Text) > 0 then
              ServerTime := True;
            Send(':' + ServerName + ' CAP * ACK :' + Text);
          end;
          'END': begin
            InCap := False;
            if GotUser and (Nick <> '*') and not Welcomed then
              Welcome;
          end;
        end;
      'AUTHENTICATE':
        if Target = 'PLAIN' then
          Send('AUTHENTICATE +')
        else
        begin
          // base64 of authzid NUL name NUL password
          Raw := DecodeStringBase64(Target);
          Parts := Raw.Split([#0]);
          if (Length(Parts) = 3) and SignIn(Parts[1], Parts[2]) then
          begin
            Numeric('900', Nick + '!' + Nick + '@' + ServerName + ' ' + Me.Name + ' :You are now logged in');
            Numeric('903', ':SASL authentication successful');
          end
          else
            Numeric('904', ':SASL authentication failed');
        end;
      'PASS':
        Pass := Target;
      'NICK':
        if not Welcomed then
          Nick := Target
        else if Me.Id > 0 then
          Notice('Your nick is your name here, ' + Me.Name + '.')
        else if (Target <> '') and not MemberExists(Target) then
        begin
          Send(':' + Nick + ' NICK ' + Target);
          Nick := Target;
        end
        else
          Numeric('433', Target + ' :That name is a member here; IDENTIFY if it is yours');
      'USER':
      begin
        GotUser := True;
        if not InCap and (Nick <> '*') and not Welcomed then
          Welcome;
      end;
      'PING':
        Send(':' + ServerName + ' PONG ' + ServerName + ' :' + Target);
      'PONG': ;
      'JOIN':
        if Target = '0' then
          while Rooms.Count > 0 do
            Part('#' + Rooms[0])
        else
          for Name in Target.Split([','], TStringSplitOptions.ExcludeEmpty) do
            Join(Name);
      'PART':
        for Name in Target.Split([','], TStringSplitOptions.ExcludeEmpty) do
          Part(Name);
      'PRIVMSG':
        Message(Target, Param(Params, 1));
      'NOTICE': ;
      'TOPIC':
        if Params.Count > 1 then
          Command(Target, '/topic ' + Param(Params, 1))
        else
        begin
          Room := FindRoom(LowerCase(Target.TrimLeft(['#'])));
          if CanRead(Me, Room) and (Room.Topic <> '') then
            Numeric('332', Target + ' :' + Room.Topic)
          else
            Numeric('331', Target + ' :No topic is set');
        end;
      'NAMES':
      begin
        Room := FindRoom(LowerCase(Target.TrimLeft(['#'])));
        if CanRead(Me, Room) then
          Names(Room.Slug, Room.Id);
      end;
      'LIST':
      begin
        Numeric('321', 'Channel :Users  Name');
        with Query('SELECT slug, topic, (SELECT COUNT(*) FROM follows f WHERE f.room_id = r.id) FROM rooms r' +
            ' WHERE r.private = 0 AND r.archived = 0 AND r.kind <> ''shelf'' ORDER BY r.slug', []) do
        try
          while not EOF do
          begin
            Numeric('322', '#' + Fields[0].AsString + ' ' + Fields[2].AsString + ' :' + Fields[1].AsString);
            Next;
          end;
        finally
          Free;
        end;
        Numeric('323', ':End of /LIST');
      end;
      'WHO':
        Numeric('315', Target + ' :End of /WHO list.');
      'WHOIS':
      begin
        Name := Param(Params, Params.Count - 1);
        if not MemberExists(Name) then
          Numeric('401', Name + ' :No such nick')
        else
        begin
          Numeric('311', Name + ' ' + Name + ' ' + ServerName + ' * :' + SiteUrl + '/u/' + Name);
          Text := VarToStr(Value('SELECT away FROM users WHERE name = :n', [Name]));
          if Text <> '' then
            Numeric('301', Name + ' :' + Text);
        end;
        Numeric('318', Name + ' :End of /WHOIS list.');
      end;
      'MODE':
        if not Target.StartsWith('#') then
          Numeric('221', '+i')
        else if Params.Count = 1 then
          Numeric('324', Target + ' +nt')
        else if Param(Params, 1) = '+o' then
          Command(Target, '/op ' + Param(Params, 2))
        else if Param(Params, 1) = '-o' then
          Command(Target, '/deop ' + Param(Params, 2))
        else if Param(Params, 1) = 'b' then
          Numeric('368', Target + ' :End of channel ban list');
      'KICK':
        Command(Target, '/kick ' + Param(Params, 1));
      'INVITE':
        Command(Param(Params, 1), '/invite ' + Target);
      'AWAY':
        if Me.Id = 0 then
          Numeric('451', ':Sign in first')
        else
        begin
          Exec('UPDATE users SET away = :a WHERE id = :u', [Copy(Target, 1, 200), Me.Id]);
          if Target = '' then
            Numeric('305', ':You are no longer marked as being away')
          else
            Numeric('306', ':You have been marked as being away');
        end;
      'ISON':
      begin
        Text := '';
        for Name in Line.Split([' ', ':'], TStringSplitOptions.ExcludeEmpty) do
          if (UpperCase(Name) <> 'ISON') and MemberExists(Name) then
            Text := Text + Name + ' ';
        Numeric('303', ':' + Trim(Text));
      end;
      'USERHOST':
        Numeric('302', ':' + Target + '=+' + Target + '@' + ServerName);
      'QUIT':
        Terminate;
      'MOTD':
        Numeric('422', ':No MOTD here');
      else
        if Welcomed then
          Numeric('421', Verb + ' :Unknown command');
    end;
  finally
    Params.Free;
  end;
end;

{ What arrived since last time: messages in the joined rooms and plain
  private messages to this member. }
procedure TIrcClient.Deliver;
var
  Ids, Slug, Payload: string;
  I, Id: integer;
  Item: TJSONData;
begin
  if Restoring then
    Exit;
  // Every ten seconds, the member as the page would see them now: banned,
  // taken out of a room, or a new password since signing in.
  if GetTickCount64 - Checked >= 10000 then
  begin
    Checked := GetTickCount64;
    if (Me.Id > 0) and (VarToStr(Value('SELECT auth_hash FROM users WHERE id = :u', [Me.Id])) <> AuthAt) then
    begin
      Notice('Your password changed. Sign in again.');
      Terminate;
      Exit;
    end;
    if (Me.Id > 0) and (MemberById(Me.Id).Name <> Me.Name) then
    begin
      Notice('Your account name changed. Reconnect with your new name.');
      Terminate;
      Exit;
    end;
    Me := MemberById(Me.Id);
    // Connected counts as here: no mail about what IRC shows them (ChatMissed).
    Exec('UPDATE users SET last_seen = NOW() WHERE id = :u AND last_seen < ' + SqlAgo('5', suMinute), [Me.Id]);
    for I := Rooms.Count - 1 downto 0 do
      if not CanRead(Me, RoomById(PtrInt(Rooms.Objects[I]))) then
      begin
        Send(':' + ServerName + ' KICK #' + Rooms[I] + ' ' + Nick + ' :This channel is no longer open to you');
        Rooms.Delete(I);
      end;
  end;
  if Rooms.Count > 0 then
  begin
    Ids := '';
    for I := 0 to Rooms.Count - 1 do
      Ids := Ids + IntToStr(PtrInt(Rooms.Objects[I])) + ',';
    SetLength(Ids, Length(Ids) - 1);
    with Query('SELECT m.id, m.room_id, COALESCE(u.name, m.author), m.body, m.parent_id FROM messages m' +
        ' LEFT JOIN users u ON u.id = m.user_id WHERE m.id > :l AND m.deleted = 0 AND m.room_id IN (' + Ids + ')' + ' ORDER BY m.id LIMIT 200', [LastMessage]) do
    try
      while not EOF do
      begin
        Id := Fields[0].AsInteger;
        LastMessage := Max(LastMessage, Id);
        if Pos(',' + IntToStr(Id) + ',', ',' + Posted) = 0 then
        begin
          Slug := Rooms[Rooms.IndexOfObject(TObject(PtrInt(Fields[1].AsInteger)))];
          SendLines(Fields[2].AsString, '#' + Slug, Fields[3].AsString, SiteUrl + '/m/' + IntToStr(Id), not Fields[4].IsNull, 0);
        end;
        Next;
      end;
    finally
      Free;
    end;
  end;
  if Me.Id = 0 then
    Exit;
  with Query('SELECT d.id, u.name, d.iv, d.data FROM dms d JOIN users u ON u.id = d.from_id' + ' WHERE d.to_id = :u AND d.id > :l ORDER BY d.id LIMIT 100', [Me.Id, LastDm]) do
  try
    while not EOF do
    begin
      LastDm := Max(LastDm, Fields[0].AsInteger);
      if Fields[2].AsString <> '' then
        Notice(Fields[1].AsString + ' sent you a locked message: ' + SiteUrl + '/dm/' + Fields[1].AsString)
      else
      begin
        Payload := '';
        try
          Item := GetJSON(Fields[3].AsString);
          try
            Payload := TJSONObject(Item).Get('text', '');
            if TJSONObject(Item).Get('t', '') <> 'text' then
              Payload := Trim(Payload + ' ' + SiteUrl + '/dm/' + Fields[1].AsString);
          finally
            Item.Free;
          end;
        except
          Payload := Fields[3].AsString;
        end;
        // /me in a private message is an ACTION here, as in a channel
        SendLines(Fields[1].AsString, Me.Name, ActionText(Fields[1].AsString, Payload), SiteUrl + '/dm/' + Fields[1].AsString, False, 0);
      end;
      Next;
    end;
  finally
    Free;
  end;
end;

procedure TIrcClient.Execute;
var
  Chunk: array[0..16383] of char;
  Got, P: integer;
  Line, Piece: string;
begin
  try
    try
      if (Sock.Handler is TIrcTls) and not TIrcTls(Sock.Handler).Handshake then
        Exit;
      CheckConnection;
      if IsBlocked(Ip) then
        Exit;
      LastMessage := IntValue('SELECT COALESCE(MAX(id), 0) FROM messages', []);
      LastDm := IntValue('SELECT COALESCE(MAX(id), 0) FROM dms', []);
      while not Terminated do
      begin
        if Sock.CanRead(1000) then
        begin
          Got := Sock.Read(Chunk, SizeOf(Chunk));
          if Got <= 0 then
            Break;
          Heard := GetTickCount64;
          Pinged := 0;
          SetString(Piece, PChar(@Chunk[0]), Got);
          Buffer := Buffer + Piece;
          if Length(Buffer) > 8192 then
            Break;
          CheckConnection;
          P := Pos(#10, Buffer);
          while (P > 0) and not Terminated do
          begin
            Line := Copy(Buffer, 1, P - 1).TrimRight([#13]);
            Delete(Buffer, 1, P);
            if Line <> '' then
              Handle(Line);
            P := Pos(#10, Buffer);
          end;
        end;
        if Welcomed and (GetTickCount64 - Looked >= 1000) then
        begin
          CheckConnection;
          Deliver;
          Looked := GetTickCount64;
        end;
        // Quiet for two minutes: ask; for four: gone.
        if (Pinged = 0) and (GetTickCount64 - Heard > 120000) then
        begin
          Send('PING :' + ServerName);
          Pinged := GetTickCount64;
        end
        else if (Pinged > 0) and (GetTickCount64 - Pinged > 120000) then
          Break;
      end;
    except
      on E: Exception do
        Log('IRC ' + Ip + ' ' + Nick + ': ' + E.Message);
    end;
  finally
    DoneConnection;
  end;
end;

procedure StartIrc;
var
  Port: integer;
begin
  InitCriticalSection(HereLock);
  Here := TStringList.Create;
  Port := Config.ReadInteger('irc', 'port', 0);
  try
    if Port > 0 then
      Listeners := Concat(Listeners, [TIrcListener.Create(Port, False)]);
    Port := Config.ReadInteger('irc', 'tls_port', 0);
    if (Port > 0) and FileExists(Config.ReadString('irc', 'cert', '')) then
      Listeners := Concat(Listeners, [TIrcListener.Create(Port, True)]);
  except
    on E: Exception do
      Log('IRC is off: ' + E.Message);
  end;
end;


initialization
  RegisterSetting('irc_backlog', 'Messages from before that IRC shows on joining a channel', '15', 'number', 'Chat');
end.
