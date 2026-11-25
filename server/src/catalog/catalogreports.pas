unit CatalogReports;

{ One report per member and entry; another replaces it and reason=none
  withdraws it. catalog_report_hide open reports hide a visible entry
  (default three). Dismissing reports or unhiding the entry closes them. }

{$mode objfpc}{$H+}

interface

uses
  httpdefs, SiteUsers;

const
  REPORT_REASONS: array[0..4] of string = ('off-topic', 'harmful', 'empty', 'duplicate', 'other');

{ The words for a reason, in the reader's language; '' for one not known. }
function ReportReasonCaption(const Reason: string): string;
{ The part under a catalog entry for reporting it. }
function ReportPart(ARequest: TRequest; Id: integer; const Me: TMember): string;
{ How many members must report an entry before it is hidden. }
function ReportsToHide: integer;

implementation

uses
  SysUtils, StrUtils, Variants, fpjson, httproute, SiteDb, SiteRoles, SiteGuard, SiteAdmin, SiteWords, WebPages, Catalog, SiteSql;

function ReportReasonCaption(const Reason: string): string;
begin
  case Reason of
    // a site's own unit may say it in its own words: RegisterCatalogText('caption', ...)
    'off-topic':
    begin
      Result := CatalogTexts('caption', Reason);
      if Result = '' then
        Result := Say('Does not belong in this catalog');
    end;
    'harmful': Result := Say('Malware or harmful');
    'empty': Result := Say('Empty, spam or a placeholder');
    'duplicate': Result := Say('A copy of another entry');
    'other': Result := Say('Something else');
    else
      Result := '';
  end;
end;

function ReportsToHide: integer;
begin
  Result := SettingInt('catalog_report_hide', 3);
  if Result < 1 then
    Result := 1;
end;

{ For the people of an entry that lives on a code host: the badge for their
  README, with the line to paste.  Nothing for an entry that lives elsewhere. }
function BadgePart(ARequest: TRequest; Id: integer): string;
var
  Site, Name, Line: string;
begin
  if IntValue('SELECT COUNT(*) FROM catalog_entries WHERE id = :i AND forge <> ''web''', [Id]) = 0 then
    Exit('');
  Site := 'https://' + ARequest.Host;
  Name := Setting('name', 'Exedra');
  Line := '[![' + Name + '](' + Site + '/catalog-badge/' + IntToStr(Id) + ')](' + Site + '/catalog/' + IntToStr(Id) + ')';
  Result := '<details class="catalog-badge"><summary>' + E(Say('Show it in your README')) + '</summary><p><img src="/catalog-badge/' +
    IntToStr(Id) + '" alt="' + E(Name) + '" height="20"></p><p>' + E(Say('Paste this into your README.md:')) + '</p><pre class="copy">' + E(Line) + '</pre></details>';
end;

function ReportPart(ARequest: TRequest; Id: integer; const Me: TMember): string;
var
  Reason, Mine, Choices: string;
  First: boolean;
begin
  Result := '<section class="catalog-report">';
  case ARequest.QueryFields.Values['reported'] of
    '1': Result := Result + '<p class="notice" role="status">' + E(Say('Thank you. The admins will look at this entry.')) + '</p>';
    '0': Result := Result + '<p class="notice" role="status">' + E(Say('Your report is taken back.')) + '</p>';
  end;
  // a site's own line above the form, such as how to reach its admins: RegisterCatalogText('report-lead', ...)
  Result := Result + CatalogTexts('report-lead') + BadgePart(ARequest, Id);
  if Me.Id = 0 then
  begin
    Result := Result + '<p><a href="/signin?return=/catalog/' + IntToStr(Id) + '">' + E(Say('Sign in to report an entry that does not belong here.')) + '</a></p></section>';
    Exit;
  end;
  Mine := '';
  with Query('SELECT reason FROM catalog_reports WHERE entry_id = :e AND user_id = :u AND resolved = 0', [Id, Me.Id]) do
  try
    if not EOF then
      Mine := Fields[0].AsString;
  finally
    Free;
  end;
  if Mine <> '' then
  begin
    Result := Result + '<form method="post" action="/catalog/' + IntToStr(Id) + '/report"><input type="hidden" name="reason" value="none"><p>' +
      E(Format(Say('You reported this entry: %s.'), [ReportReasonCaption(Mine)])) + ' <button type="submit" class="small-link">' +
      E(Say('Take it back')) + '</button></p></form></section>';
    Exit;
  end;
  Choices := '';
  First := True;
  for Reason in REPORT_REASONS do
  begin
    Choices := Choices + '<label><input type="radio" name="reason" value="' + Reason + '"';
    if First then
      Choices := Choices + ' required';
    First := False;
    Choices := Choices + '> ' + E(ReportReasonCaption(Reason)) + '</label>';
  end;
  Result := Result + '<details><summary>' + E(Say('Report this entry')) + '</summary><form method="post" action="/catalog/' + IntToStr(Id) +
    '/report" class="catalog-report-form"><fieldset><legend>' + E(Say('What is wrong with it?')) + '</legend>' + Choices + '</fieldset><label>' +
    E(Say('Anything the admins should know (optional)')) + ' <textarea name="note" maxlength="500" rows="3"></textarea></label><p class="hint">' +
    E(Format(Say('Reports go to the admins. An entry that %d members report is hidden until an admin looks at it.'), [ReportsToHide])) +
    '</p><button type="submit">' + E(Say('Send the report')) + '</button></form></details></section>';
end;

{ Hidden after enough reports, with the reasons as its note, the visible
  count kept right; the entry's row is the lock. }
procedure HideIfReported(Id: integer);
var
  Open: integer;
  Reasons: string;
begin
  Open := IntValue('SELECT COUNT(*) FROM catalog_reports WHERE entry_id = :e AND resolved = 0', [Id]);
  if Open < ReportsToHide then
    Exit;
  Reasons := VarToStrDef(Value('SELECT ' + SqlGroupConcat('DISTINCT reason ORDER BY reason', ', ') + ' FROM catalog_reports' +
    ' WHERE entry_id = :e AND resolved = 0', [Id]), '');
  Exec('START TRANSACTION', []);
  try
    IntValue('SELECT visible FROM catalog_totals WHERE id = 1 FOR UPDATE', []);
    if IntValue('SELECT id FROM catalog_entries WHERE id = :i AND hidden = 0 FOR UPDATE', [Id]) = Id then
    begin
      Exec('UPDATE catalog_entries SET hidden = 1, hidden_note = :n WHERE id = :i', [Copy(Format('Hidden after %d member reports: %s', [Open, Reasons]), 1, 1000), Id]);
      Exec('UPDATE catalog_totals SET visible = visible - 1 WHERE id = 1', []);
      CatalogEntryHidden(Id);
    end;
    Exec('COMMIT', []);
  except
    Exec('ROLLBACK', []);
    raise;
  end;
end;

{ POST /catalog/:id/report }
procedure SendReport(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Id: integer;
  Reason, Note: string;
begin
  CheckConnection;
  if not NeedMember(ARequest, AResponse, Me) then
    Exit;
  if Me.Banned then
  begin
    SendText(AResponse, 403, Say('This account cannot report entries.'));
    Exit;
  end;
  Id := StrToIntDef(ARequest.RouteParams['id'], 0);
  Reason := ARequest.ContentFields.Values['reason'];
  if (Reason <> 'none') and not AnsiMatchStr(Reason, REPORT_REASONS) then
  begin
    SendText(AResponse, 400, Say('Choose what is wrong with the entry.'));
    Exit;
  end;
  if IntValue('SELECT COUNT(*) FROM catalog_entries WHERE id = :i AND hidden = 0', [Id]) = 0 then
  begin
    SendText(AResponse, 404, Say('No entry by that number.'));
    Exit;
  end;
  if Reason = 'none' then
    Exec('DELETE FROM catalog_reports WHERE entry_id = :e AND user_id = :u AND resolved = 0', [Id, Me.Id])
  else
  begin
    if not AllowAttempt('member ' + IntToStr(Me.Id), 'catreport', SettingInt('catreport_member', 20), 60) then
    begin
      AResponse.SetCustomHeader('Retry-After', '3600');
      SendText(AResponse, 429, Say('That is a lot of reports in one hour. Try again later.'));
      Exit;
    end;
    Note := CatalogRoomText(Trim(ARequest.ContentFields.Values['note']), 500);
    Exec('INSERT INTO catalog_reports (entry_id, user_id, reason, note, created, resolved) VALUES (:e, :u, :r, :n, ' + SqlUtcNow + ', 0)' +
      SqlOnConflict('entry_id, user_id', 'reason = ' + SqlNew('reason') + ', note = ' + SqlNew('note') + ', created = ' + SqlNew('created') + ', resolved = 0'),
      [Id, Me.Id, Reason, Note]);
    HideIfReported(Id);
  end;
  if Reason = 'none' then
    SeeOther(AResponse, '/catalog/' + IntToStr(Id) + '?reported=0')
  else
    SeeOther(AResponse, '/catalog/' + IntToStr(Id) + '?reported=1');
end;

{ POST /api/admin/catalog/dismiss  id: the entry's open reports closed, the
  entry left as it is. }
procedure DismissReports(ARequest: TRequest; AResponse: TResponse);
var
  Me: TMember;
  Id: integer;
begin
  if not NeedPermission(ARequest, AResponse, 'edit-catalog', Me) then
    Exit;
  Id := StrToIntDef(ARequest.ContentFields.Values['id'], 0);
  Exec('UPDATE catalog_reports SET resolved = 1 WHERE entry_id = :e AND resolved = 0', [Id]);
  SendJSON(AResponse, TJSONObject.Create(['ok', True]));
end;

initialization
  RegisterTable('CREATE TABLE IF NOT EXISTS catalog_reports (id INT AUTO_INCREMENT PRIMARY KEY, entry_id INT NOT NULL, user_id INT NOT NULL,' +
    ' reason VARCHAR(20) NOT NULL, note VARCHAR(1000) NOT NULL DEFAULT '''', created DATETIME NOT NULL, resolved TINYINT NOT NULL DEFAULT 0,' +
    ' UNIQUE KEY one_each (entry_id, user_id), INDEX (resolved, entry_id)) ENGINE=InnoDB CHARACTER SET utf8mb4');
  // the first reason had a name from the site the catalog was made for
  RegisterUpgrade('catalog-report-off-topic', 'UPDATE catalog_reports SET reason = ''off-topic'' WHERE reason = ''not-pascal''');
  RegisterSetting('catalog_report_hide', 'Catalog: members whose reports hide an entry until an admin looks', '3', 'number', 'Catalog');
  RegisterSetting('catreport_member', 'Catalog reports: at most this many per member in an hour', '20', 'number', 'Catalog');
  RegisterAdminRoute('/api/admin/catalog/dismiss', 'edit-catalog');
  HTTPRouter.RegisterRoute('/catalog/:id/report', rmPost, @SendReport);
  HTTPRouter.RegisterRoute('/api/admin/catalog/dismiss', rmPost, @DismissReports);
  RegisterCatalogEntryPart('reports', @ReportPart);
end.
