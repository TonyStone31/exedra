unit app_account;

{ The site's page: the account row at the foot of the side, the form a
  visitor joins with, and a small menu under a button. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web, app_helpers;

procedure RenderAccount;
function JoinForm(Caption: JSValue): TEl;
procedure PopMenu(Anchor: TJSElement; Items: TJSArray);

implementation

uses app_notify, app_panel;

type
  // What the browser hands over when it can install the site.
  TInstallOffer = class external name 'Object'(TJSObject)
    userChoice: JSValue;
    procedure prompt;
  end;

// pas2js Web requires a reload argument; the browser permits none.
procedure Reload; external name 'location.reload';

// ---------------------------------------------------------------- account

// Whether the admin page has anything for this member.
function MayAdmin: boolean;
const
  Rights: array[0..8] of string = ('view-admin', 'manage-permissions', 'manage-settings', 'manage-channels', 'manage-private',
    'read-reports', 'manage-blocks', 'view-visitors', 'view-storage');
var
  I: NativeInt;
begin
  Result := True;
  for I := 0 to 8 do
    if May(Rights[I]) then Exit;
  Result := Extras.adminTabs.some(function(Extra: JSValue; Index: NativeInt; List: TJSArray): boolean
      begin
        Result := Truthy(TJSObject(Extra)['permission']) and May(TJSObject(Extra)['permission']);
      end) or
    Extras.adminScripts.some(function(Extra: JSValue; Index: NativeInt; List: TJSArray): boolean
      begin
        Result := TJSArray(TJSObject(Extra)['permissions']).some(function(P: JSValue; At: NativeInt; All: TJSArray): boolean
          begin
            Result := May(P);
          end);
      end);
end;

// The row at the bottom of the side: who you are, a few buttons, and a
// menu with the rest.  side.js draws it, as on the wiki and the forum;
// this page adds its own buttons.
procedure RenderAccount;
var
  Tools: TJSArray;
  Report, Install: TEl;

  procedure Accept(E: TJSEvent); async;
  begin
    TInstallOffer(InstallOffer).prompt;
    await(JSValue, TInstallOffer(InstallOffer).userChoice);
    InstallOffer := nil;
    RenderAccount;
  end;

begin
  Tools := TJSArray.new;
  Report := IconButton('bug', T('Report a problem'));
  Report.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin OpenReport; end));
  Tools.push(Report);
  if Truthy(InstallOffer) then
  begin
    Install := IconButton('install', T('Install the app'));
    Install.addEventListener('click', TJSRawEventHandler(@Accept));
    Tools.push(Install);
  end;
  if Truthy(Me.name) then Tools.push(BellButton);
  Side.account(new(['name', Me.name, 'avatar', Me.avatar, 'admin', MayAdmin, 'tools', Tools, 'links', Extras.accountLinks,
    'unconfirmed', Same(Me.verified, False)]));
end;

function JoinForm(Caption: JSValue): TEl;
var
  Form, Name, Pass, Go, Row, A: TEl;
  Others: TJSArray;
  Titles: TJSObject;
  I: NativeInt;

  procedure Submit(E: TJSEvent); async;
  begin
    E.preventDefault;
    Go.disabled := True;
    Go.textContent := T('One moment');
    if Truthy(await(JSValue, Keys.joinFrom(Form, @Failed))) then Reload;
    Go.disabled := False;
    Go.textContent := T('Join');
  end;

begin
  Form := El('form', 'quickjoin');
  Form.appendChild(El('span', 'caption', Caption));
  Name := El('input');
  Name.fieldName := 'name';
  Name.placeholder := T('Name');
  Name.maxLength := 24;
  Name.autocomplete := 'username';
  Name.required := True;
  Pass := El('input');
  Pass.fieldName := 'password';
  Pass.kind := 'password';
  Pass.placeholder := T('Password');
  Pass.autocomplete := 'current-password';
  Pass.required := True;
  Go := El('button', '', T('Join'));
  Form.add(Name, Pass, Go);
  if Truthy(TJSObject(Body.dataset)['sso']) then
  begin
    Row := El('div', 'ssolink');
    Row.appendChild(El('span', '', T('or sign in with')));
    Others := TJSArray(TJSString(TJSObject(Body.dataset)['sso']).split(','));
    for I := 0 to Others.length - 1 do
    begin
      A := Link('/signin-with/' + String(Others[I]), 'ssoicon');
      Titles := new(['github', 'GitHub', 'gitlab', 'GitLab', 'codeberg', 'Codeberg', 'google', 'Google', 'microsoft', 'Microsoft']);
      A.title := T('Sign in with %s', Titles[String(Others[I])]);
      A.appendChild(El('span', 'ssologo ' + String(Others[I])));
      Row.appendChild(A);
    end;
    Form.appendChild(Row);
  end;
  Form.addEventListener('submit', TJSRawEventHandler(@Submit));
  Result := Form;
end;

// A small menu under a button: [caption, what it does] pairs.  Any click
// closes it.
procedure PopMenu(Anchor: TJSElement; Items: TJSArray);
var
  Menu: TEl;
  Old: TJSNodeList;
  R: TJSDOMRect;
  Shown: double;
  I: NativeInt;
  Close: TJSRawEventHandler;

  procedure Add(Item: TJSArray);
  var
    B: TEl;
  begin
    B := El('button', '', Item[0]);
    B.kind := 'button';
    B.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
      begin
        Menu.remove;
        TJSFunction(Item[1]).call(TJSObject(Item));
      end));
    Menu.appendChild(B);
  end;

begin
  Old := document.querySelectorAll('.popmenu');
  for I := 0 to Old.length - 1 do TJSElement(Old[I]).remove;
  Menu := El('nav', 'popmenu');
  for I := 0 to Items.length - 1 do Add(TJSArray(Items[I]));
  R := Anchor.getBoundingClientRect;
  Menu.style.setProperty('left', String(JSValue(Min(R.left, window.innerWidth - 220))) + 'px');
  Menu.style.setProperty('top', String(JSValue(R.bottom + 4)) + 'px');
  document.body.appendChild(Menu);
  // no room below, as beside the message box: it opens above the button
  if Truthy(ShownPart) then Shown := ShownPart.height else Shown := window.innerHeight;
  if R.bottom + 4 + Menu.offsetHeight > Shown then
    Menu.style.setProperty('top', String(JSValue(Max(4, R.top - 4 - Menu.offsetHeight))) + 'px');
  Close := TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      if Menu.contains(TJSNode(E.target)) then Exit;
      Menu.remove;
      document.removeEventListener('click', Close);
    end);
  window.setTimeout(procedure begin document.addEventListener('click', Close); end);
end;

end.
