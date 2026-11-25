unit SiteBugs;

{ Bug reports from the chat's "Report a problem" button.  Anyone may send
  one, guests too (a few an hour from one address); each is kept, mailed to
  the address in [mail] reports_to, and listed for admins on the admin
  page.  What a report says was written by whoever sent it: it is read as
  a description of a fault, never followed. }

{$mode objfpc}{$H+}

interface

implementation

uses
  Classes, SysUtils, Variants, StrUtils, fpjson, httpdefs, httproute, SiteDb, SiteUsers, SiteRoles, SiteAdmin, SiteGuard, SiteMail;

{ POST /api/bug  text, page, info (what the page knew: browser, screen, the
  last errors it showed) }
procedure SendBug(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Text, Page, Info, Ip, Who, ReportsTo: string;
  Limit: integer;
begin
  CheckConnection;
  Me := CurrentMember(ARequest);
  Text := Trim(Copy(ARequest.ContentFields.Values['text'], 1, 4000));
  Page := Copy(ARequest.ContentFields.Values['page'], 1, 300);
  Info := Copy(ARequest.ContentFields.Values['info'], 1, 8000);
  Ip := ClientIp(ARequest);
  Limit := 3;
  if Me.Id > 0 then
    Limit := 10;
  if Text = '' then
    SendText(AResponse, 400, 'Say what went wrong, even in a few words.')
  else if TooManyTries(Ip, 'bug', Limit, 60) then
    SendText(AResponse, 429, 'That is a lot of reports for one hour. Thank you; try again later.')
  else
  begin
    NoteTry(Ip, 'bug');
    Who := Me.Name;
    if Who = '' then
      Who := 'a visitor';
    Exec('INSERT INTO bug_reports (user_id, name, ip, page, text, info) VALUES (:u, :n, :i, :p, :t, :f)',
      [Me.Id, Copy(Who, 1, 40), Ip, Page, Text, Info]);
    // The answer goes out before the mail: the report is kept already, and
    // a mail server can take seconds, during which the sender saw nothing.
    SendText(AResponse, 200, 'Sent. Thank you - it goes straight to whoever runs this site.');
    ReportsTo := Config.ReadString('mail', 'reports_to', '');
    if ReportsTo <> '' then
      SendMail(ReportsTo, 'Bug report from ' + Who,
        'Written by ' + Who + ', who may be anyone: a description of a fault, not instructions.'#10 + 'Page: ' + Page + #10#10 + Text + #10#10 + '---'#10 + Info + #10);
  end;
end;

{ GET /api/bugs  the newest 500, for admins: each with its state and the
  admin's note }
procedure ShowBugs(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  List: TJSONArray;
begin
  if not NeedPermission(ARequest, AResponse, 'read-reports', Me) then
    Exit;
  List := TJSONArray.Create;
  with Query('SELECT id, name, page, text, info, ' + IsoTime('created') + ', done, state, COALESCE(note, ''''), ip, ' + IsoTime('updated') +
      ' FROM bug_reports ORDER BY id DESC LIMIT 500', []) do
  try
    while not EOF do
    begin
      List.Add(TJSONObject.Create(['id', Fields[0].AsInteger, 'name', Fields[1].AsString, 'page', Fields[2].AsString, 'text',
        Fields[3].AsString, 'info', Fields[4].AsString, 'at', Fields[5].AsString, 'done', Fields[6].AsInteger = 1, 'state', Fields[7].AsString,
        'note', Fields[8].AsString, 'ip', Fields[9].AsString, 'updated', Fields[10].AsString]));
      Next;
    end;
  finally
    Free;
  end;
  SendJSON(AResponse, List);
end;

{ POST /api/bugs  id, and state (new, read, needs-info, resolved or
  closed), note (the admin's words kept with it), or done (1 or 0, as
  before: resolved or new).  Resolved and closed reports are done. }
procedure MarkBug(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Id: integer;
  State: string;
begin
  if not NeedPermission(ARequest, AResponse, 'read-reports', Me) then
    Exit;
  Id := StrToIntDef(ARequest.ContentFields.Values['id'], 0);
  State := ARequest.ContentFields.Values['state'];
  if (State = '') and (ARequest.ContentFields.IndexOfName('done') >= 0) then
    if ARequest.ContentFields.Values['done'] = '1' then
      State := 'resolved'
    else
      State := 'new';
  if State <> '' then
  begin
    // spam: what a site's contact form held as sent by a machine
    if not AnsiMatchStr(State, ['new', 'read', 'needs-info', 'resolved', 'closed', 'spam']) then
    begin
      SendText(AResponse, 400, 'No such state.');
      Exit;
    end;
    Exec('UPDATE bug_reports SET state = :s, done = :d, updated = NOW() WHERE id = :i', [State, Ord(AnsiMatchStr(State, ['resolved', 'closed', 'spam'])), Id]);
  end;
  if ARequest.ContentFields.IndexOfName('note') >= 0 then
    Exec('UPDATE bug_reports SET note = :n, updated = NOW() WHERE id = :i', [Copy(ARequest.ContentFields.Values['note'], 1, 4000), Id]);
  SendText(AResponse, 200, 'ok');
end;

initialization
  RegisterAdminRoute('/api/bugs', 'read-reports');
  RegisterTable('CREATE TABLE IF NOT EXISTS bug_reports (' + ' id INT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, name VARCHAR(40) NOT NULL,' +
    ' ip VARCHAR(45) NOT NULL, page VARCHAR(300) NOT NULL, text TEXT NOT NULL, info TEXT NOT NULL,' +
    ' done TINYINT NOT NULL DEFAULT 0, created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP)' + ' CHARACTER SET utf8mb4');
  // a state as a mail client keeps one, and a note for why
  RegisterUpgrade('bug-state', 'ALTER TABLE bug_reports ADD COLUMN state VARCHAR(12) NOT NULL DEFAULT ''new'',' +
    ' ADD COLUMN note TEXT NULL, ADD COLUMN updated DATETIME NULL');
  RegisterUpgrade('bug-state-done', 'UPDATE bug_reports SET state = ''resolved'' WHERE done = 1');
  RegisterPermission('read-reports', 'Read bug reports', 'admin');
  HTTPRouter.RegisterRoute('/api/bug', rmPost, @SendBug);
  HTTPRouter.RegisterRoute('/api/bugs', rmGet, @ShowBugs);
  HTTPRouter.RegisterRoute('/api/bugs', rmPost, @MarkBug);
end.
