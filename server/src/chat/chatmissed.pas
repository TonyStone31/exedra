unit ChatMissed;

{ Mail for unread private messages and mentions after mail_notes_minutes.
  One mail combines new items, at least mail_notes_hours apart. Skip members
  who opted out, lack a confirmed address or have never visited. }

{$mode objfpc}{$H+}

interface

{ Something for the member came in: look at them on the next round. }
procedure MarkMissed(UserId: integer);

implementation

uses
  Classes, SysUtils, Variants, httpdefs, httproute, SiteDb, SiteSql, SiteUsers, SiteBell, SiteMail, SiteMarkup, SiteGuard, SiteNotices;

type
  TDue = record
    Id: integer;
    Name, Email, Key: string;
    Away, Seen, Waiting: boolean;
  end;

procedure MarkMissed(UserId: integer);
begin
  Exec('UPDATE users SET mail_due = NOW() WHERE id = :u AND mail_due IS NULL AND mail_notes = 1' +
    ' AND verified = 1 AND banned = 0 AND email <> '''' AND last_seen IS NOT NULL', [UserId]);
end;

{ The mail's lines for one member, '' when nothing new is unread. }
function MissedLines(UserId: integer): string;
var
  Since: string;
begin
  Result := '';
  Since := ' > COALESCE((SELECT mailed FROM users WHERE id = :u2), ''2000-01-01'')';
  with Query('SELECT u.name FROM dm_peers p JOIN users u ON u.id = p.other_id JOIN dms d ON d.id = p.last_id' +
      ' WHERE p.user_id = :u AND p.last_id > p.last_read_id AND d.from_id = p.other_id AND d.created' + Since + ' ORDER BY p.last_id DESC LIMIT 10', [UserId, UserId]) do
  try
    while not EOF do
    begin
      Result := Result + Fields[0].AsString + ' sent you a private message.'#10#10;
      Next;
    end;
  finally
    Free;
  end;
  with Query('SELECT r.slug, COALESCE(u.name, m.author), m.body FROM mentions n' + ' JOIN messages m ON m.id = n.message_id JOIN rooms r ON r.id = m.room_id' +
      ' LEFT JOIN users u ON u.id = m.user_id LEFT JOIN follows f ON f.room_id = r.id AND f.user_id = n.user_id' +
      ' WHERE n.user_id = :u AND m.deleted = 0 AND m.id > COALESCE(f.last_read_id, 0)' +
      ' AND (r.private = 0 OR f.user_id IS NOT NULL) AND COALESCE(f.notify, 0) < 2 AND m.created' + Since + ' ORDER BY n.message_id DESC LIMIT 10', [UserId, UserId]) do
  try
    while not EOF do
    begin
      Result := Result + Fields[1].AsString + ' mentioned you in #' + Fields[0].AsString + ':'#10 + '  ' + PlainLine(Fields[2].AsString) + #10#10;
      Next;
    end;
  finally
    Free;
  end;
  // the site's own notices (SiteNotices), with the page each one points to
  with Query('SELECT body, link FROM notices WHERE user_id = :u AND seen = 0 AND created' + Since + NotMailedElsewhere + ' ORDER BY id DESC LIMIT 10', [UserId, UserId]) do
  try
    while not EOF do
    begin
      Result := Result + StringReplace(NoticeCut(Fields[0].AsString, 300), #10, ' ', [rfReplaceAll]) + #10 + '  ' + Setting('url', '') + Fields[1].AsString + #10#10;
      Next;
    end;
  finally
    Free;
  end;
end;

function MailOne(const Due: TDue; const Lines: string): boolean;
var
  Site, Url, Off, Hours: string;
begin
  Hours := IntToStr(SettingInt('mail_notes_hours', 6)) + ' hours';
  if Hours = '1 hours' then
    Hours := 'hour';
  Site := Setting('name', 'Exedra');
  Url := Setting('url', '');
  Off := Url + '/mail-off/' + Due.Key;
  Result := SendMail(Due.Email, 'Waiting for you on ' + Site, 'Hello ' + Due.Name + ','#10#10 + 'While you were away:'#10#10 + Lines +
    'Open the chat: ' + Url + #10#10 + '--'#10 + 'You get one of these at most every ' + Hours +
    ', and only when something new is waiting. To stop them, open this link (no need to sign in):'#10 + Off + #10 + 'or switch them off on your profile page.'#10,
    'List-Unsubscribe: <' + Off + '>'#13#10 + 'List-Unsubscribe-Post: List-Unsubscribe=One-Click'#13#10);
end;

{ The chore: everyone marked, once their message has waited long enough. }
procedure MailMissed;
var
  Due: array of TDue;
  D: TDue;
  I: integer;
  Minutes: int64;
  Lines: string;
begin
  if (Setting('mail_notes', '1') <> '1') or not MailReady then
    Exit;
  Minutes := SettingInt('mail_notes_minutes', 15);
  Due := [];
  with Query('SELECT id, name, email, mail_key, away <> '''', last_seen > ' + SqlAgo(':m', suMinute) + ',' + ' (mailed IS NOT NULL AND mailed > ' +
      SqlAgo(':h', suHour) + ') FROM users' + ' WHERE mail_due < ' + SqlAgo(':m2', suMinute) + ' AND mail_notes = 1 AND verified = 1 AND banned = 0' +
      ' AND email <> '''' AND last_seen IS NOT NULL' +
      // the ones a round would only pass over are not taken: 200 of them
      // would keep the rest from their turn
      ' AND NOT (mailed IS NOT NULL AND mailed > ' + SqlAgo(':h2', suHour) + ')' + ' AND (away <> '''' OR last_seen <= ' + SqlAgo(':m3', suMinute) +
      ')' + ' ORDER BY mail_due LIMIT 200', [Minutes, SettingInt('mail_notes_hours', 6), Minutes, SettingInt('mail_notes_hours', 6), Minutes]) do
  try
    while not EOF do
    begin
      SetLength(Due, Length(Due) + 1);
      Due[High(Due)].Id := Fields[0].AsInteger;
      Due[High(Due)].Name := Fields[1].AsString;
      Due[High(Due)].Email := Fields[2].AsString;
      Due[High(Due)].Key := Fields[3].AsString;
      Due[High(Due)].Away := Fields[4].AsInteger = 1;
      Due[High(Due)].Seen := Fields[5].AsInteger = 1;
      Due[High(Due)].Waiting := Fields[6].AsInteger = 1;
      Next;
    end;
  finally
    Free;
  end;
  for I := 0 to High(Due) do
  begin
    D := Due[I];
    // Mailed lately, or here and not away: stays marked for a later round,
    // when it goes if it is still unread.
    if D.Waiting or (not D.Away and (D.Seen or UserIsLive(D.Id))) then
      Continue;
    Lines := MissedLines(D.Id);
    if Lines <> '' then
    begin
      if D.Key = '' then
      begin
        D.Key := RandomHex(16);
        Exec('UPDATE users SET mail_key = :k WHERE id = :u', [D.Key, D.Id]);
      end;
      // Not sent: tried again next round, until the day-old line below gives up
      if not MailOne(D, Lines) then
        Continue;
      Exec('UPDATE users SET mailed = NOW() WHERE id = :u', [D.Id]);
    end;
    Exec('UPDATE users SET mail_due = NULL WHERE id = :u', [D.Id]);
  end;
  // A day old is too late to mail about, and stops a bad address being tried forever.
  Exec('UPDATE users SET mail_due = NULL WHERE mail_due < ' + SqlAgo('1', suDay), []);
end;

{ GET /mail-off/:key  asks first, as mail scanners open links; POST (the
  button, or a mail program's one-click unsubscribe) turns the mails off }
procedure MailOff(ARequest: TRequest; AResponse: TResponse);
var
  Key, Who, Text: string;
begin
  CheckConnection;
  if not TokenTry(ARequest, AResponse) then
    Exit;
  Key := ARequest.RouteParams['key'];
  Who := '';
  if IsHex(Key, 32) then
    Who := VarToStr(Value('SELECT name FROM users WHERE mail_key = :k', [Key]));
  if Who = '' then
  begin
    SendText(AResponse, 404, 'That link is not known here.');
    Exit;
  end;
  if ARequest.Method = 'POST' then
  begin
    Exec('UPDATE users SET mail_notes = 0, mail_due = NULL WHERE mail_key = :k', [Key]);
    Text := '<p>Done. ' + HtmlText(Who) + ' gets no more mail about missed messages.</p>' + '<p>Switch them back on from your profile page whenever you like.</p>';
  end
  else
    Text := '<p>Stop the mails about missed private messages and mentions for ' + HtmlText(Who) + '?</p>' + '<form method="post"><button>Stop them</button></form>';
  AResponse.ContentType := 'text/html; charset=utf-8';
  AResponse.Content := '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width">' + '<title>' +
    HtmlText(Setting('name', 'Exedra')) + '</title>' + '<body style="font: 16px system-ui, sans-serif; max-width: 34em; margin: 3em auto; padding: 0 16px">' +
    Text + '<p><a href="/">Back to the chat</a></p>';
  AResponse.SendContent;
end;

initialization
  RegisterSetting('mail_notes', 'Email members about private messages and mentions they missed', '1', 'yesno',
    'Chat');
  RegisterSetting('mail_notes_minutes', 'Minutes a message waits unread before it is mailed', '15', 'number',
    'Chat');
  RegisterSetting('mail_notes_hours', 'Hours at least between two such mails to one member', '6', 'number',
    'Chat');
  RegisterChore(@MailMissed, 5);
  HTTPRouter.RegisterRoute('/mail-off/:key', rmAll, @MailOff);
end.
