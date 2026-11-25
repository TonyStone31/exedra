unit ForumSwitch;

{ The forum as a part of the suite (SiteParts): off unless the site turns
  it on.  While it is off its addresses answer 404. }

{$mode objfpc}{$H+}

interface

function ForumOn: boolean;

implementation

uses SiteParts, SiteWords, WebPages;

function ForumOn: boolean;
begin
  Result := PartOn('forum');
end;

function ForumLink: string;
begin
  Result := '<a href="/forum">' + E(Say('Forum')) + '</a>';
end;

initialization
  RegisterPart('forum', 'The forum: boards, topics and posts', False);
  RegisterPartPaths('forum', ['/forum', '/api/forum']);
  RegisterPartLink('forum', @ForumLink);
  RegisterPartHome('forum', '/forum');
  // announces the admin's boards tab to the site's page
  RegisterPartScript('forum', '/forum/admin.js');
end.
