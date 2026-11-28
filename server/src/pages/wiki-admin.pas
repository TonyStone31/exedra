unit WikiAdminPage;

{ The wiki emoji tab: names, keywords, custom SVG and default pictures. }

{$mode objfpc}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}
{$modeswitch externalclass}

interface

implementation

uses JS, Web, PageGlobals, PageKit;

// pas2js Web declares only the string URLSearchParams constructor.
type
  TParams = class external name 'URLSearchParams'(TJSURLSearchParams)
    constructor new(Data: TJSObject);
  end;

function Say(const Text: string): string;
begin
  if Truthy(TJSObject(window)['t']) then Result := T(Text) else Result := Text;
end;

procedure Send(Data: TJSObject); async;
var
  R: TJSResponse;
begin
  R := await(Post('/api/wiki/emoji/save', TParams.new(Data)));
  if not R.ok then raise TJSError.new(await(string, R.text));
end;

function ReadSvg(AFile: TJSFile): TJSPromise;
begin
  Result := TJSPromise.new(procedure(Done, Fail: TJSPromiseResolver)
    var
      Reader: TJSFileReader;
    begin
      if isUndefined(AFile) or (AFile = nil) then begin Done(''); Exit; end;
      if AFile.size > 64 * 1024 then
      begin
        Fail(TJSError.new(Say('The picture is too big: 64 KB at most.')));
        Exit;
      end;
      Reader := TJSFileReader.new;
      Reader.addEventListener('load', TJSRawEventHandler(procedure(E: TJSEvent)
        begin
          if Truthy(Reader.result) then Done(string(Reader.result)) else Done('');
        end));
      Reader.addEventListener('error', TJSRawEventHandler(procedure(E: TJSEvent)
        begin
          Fail(TJSError.new(Say('The file could not be read.')));
        end));
      Reader.readAsText(AFile);
    end);
end;

function Picker: TJSHTMLInputElement;
begin
  Result := TJSHTMLInputElement(SiteShell.el('input'));
  Result._type := 'file';
  Result.accept := 'image/svg+xml,.svg';
end;

procedure Build(Holder: TJSHTMLElement);
var
  Root, Notice, List: TJSHTMLElement;

  procedure Load; async; forward;

  function Row(Emoji: TJSObject): TJSHTMLElement;
  var
    Line, Face, Plain, Drawn: TJSHTMLElement;
    Name, Keywords, DrawnBox, AFile: TJSHTMLInputElement;
    Save, Back: TJSHTMLButtonElement;
    Img: TJSHTMLImageElement;

    procedure Store(Extra: TJSObject); async;
    var
      Data: TJSObject;
      Svg, DrawnValue: string;
    begin
      Save.disabled := True;
      Back.disabled := True;
      try
        if DrawnBox.checked then DrawnValue := '1' else DrawnValue := '0';
        Data := new(['chars', Emoji['emoji'], 'name', Name.value, 'keywords', Keywords.value, 'drawn', DrawnValue]);
        if Extra <> nil then TJSObject.assign(Data, Extra);
        Svg := await(string, ReadSvg(AFile.files[0]));
        if Svg <> '' then Data['svg'] := Svg;
        await(Send(Data));
        Notice.textContent := Say('Saved.') + ' ' + string(Emoji['emoji']);
        await(Load);
      except
        Notice.textContent := string(TJSObject(JSExceptValue)['message']);
        Save.disabled := False;
        Back.disabled := False;
      end;
    end;

  begin
    Line := SiteShell.el('form', 'emoji-admin-row');
    Face := SiteShell.el('span', 'emoji-admin-face');
    if Truthy(Emoji['src']) then
    begin
      Img := TJSHTMLImageElement(SiteShell.el('img'));
      Img.src := string(Emoji['src']); Img.alt := string(Emoji['emoji']); Face.appendChild(Img);
    end
    else TJSObject(Face)['textContent'] := Emoji['emoji'];
    Plain := SiteShell.el('span', 'emoji-admin-plain', Emoji['emoji']);
    Plain.title := Say('As the reader''s font draws it');
    Name := TJSHTMLInputElement(SiteShell.el('input')); TJSObject(Name)['value'] := Emoji['name'];
    Name.setAttribute('aria-label', Say('Name'));
    Keywords := TJSHTMLInputElement(SiteShell.el('input')); Keywords.value := TJSArray(Emoji['keywords']).join(' ');
    Keywords.setAttribute('aria-label', Say('Keywords')); Keywords.placeholder := Say('keywords, with spaces between');
    DrawnBox := TJSHTMLInputElement(SiteShell.el('input')); DrawnBox._type := 'checkbox'; DrawnBox.checked := Truthy(Emoji['src']);
    Drawn := SiteShell.el('label', 'emoji-admin-drawn');
    // pas2js Web's append overload omits text nodes.
    Drawn.append(DrawnBox, TJSElement(document.createTextNode(' ' + Say('Own picture'))));
    AFile := Picker; AFile.setAttribute('aria-label', Say('A picture of your own (SVG)'));
    Save := TJSHTMLButtonElement(SiteShell.el('button', '', Say('Save'))); Save._type := 'submit';
    Back := TJSHTMLButtonElement(SiteShell.el('button', '', Say('Default picture'))); Back._type := 'button';
    Line.append(Face, Plain, Name, Keywords, Drawn, AFile, Save, Back);
    Line.addEventListener('submit', TJSRawEventHandler(procedure(E: TJSEvent)
      begin E.preventDefault; Store(nil); end));
    Back.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
      begin Store(new(['plain', '1'])); end));
    Result := Line;
  end;

  procedure Load; async;
  var
    R: TJSResponse;
    Set_: TJSArray;
    I: integer;
  begin
    Notice.textContent := Say('Loading…');
    try
      R := await(Get('/api/wiki/emoji?fresh=' + String(JSValue(TJSDate.now))));
      if not R.ok then raise TJSError.new(await(string, R.text));
      Set_ := await(TJSArray, R.json);
      Notice.textContent := '';
      List.replaceChildren;
      for I := 0 to Set_.length - 1 do List.appendChild(Row(TJSObject(Set_[I])));
    except
      Notice.textContent := string(TJSObject(JSExceptValue)['message']);
    end;
  end;

  function AddForm: TJSHTMLElement;
  var
    Form: TJSHTMLFormElement;
    Chars, Name, Keywords, AFile: TJSHTMLInputElement;
    Add: TJSHTMLButtonElement;

    procedure Submit(E: TJSEvent); async;
    var
      Svg, Drawn: string;
      Data: TJSObject;
    begin
      E.preventDefault;
      Add.disabled := True;
      try
        try
          Svg := await(string, ReadSvg(AFile.files[0]));
          if Svg <> '' then Drawn := '1' else Drawn := '0';
          Data := new(['add', '1', 'chars', TJSString(Chars.value).trim, 'name', Name.value, 'keywords', Keywords.value, 'drawn', Drawn]);
          if Svg <> '' then Data['svg'] := Svg;
          await(Send(Data));
          Form.reset;
          Notice.textContent := Say('Saved.');
          await(Load);
        except
          Notice.textContent := string(TJSObject(JSExceptValue)['message']);
        end;
      finally
        Add.disabled := False;
      end;
    end;

  begin
    Form := TJSHTMLFormElement(SiteShell.el('form', 'emoji-admin-add'));
    Chars := TJSHTMLInputElement(SiteShell.el('input')); Chars.placeholder := Say('Emoji');
    Chars.setAttribute('aria-label', Say('Emoji')); Chars.size := 4;
    Name := TJSHTMLInputElement(SiteShell.el('input')); Name.placeholder := Say('Name'); Name.setAttribute('aria-label', Say('Name'));
    Keywords := TJSHTMLInputElement(SiteShell.el('input')); Keywords.placeholder := Say('keywords, with spaces between'); Keywords.setAttribute('aria-label', Say('Keywords'));
    AFile := Picker; AFile.setAttribute('aria-label', Say('A picture of your own (SVG)'));
    Add := TJSHTMLButtonElement(SiteShell.el('button', '', Say('Add'))); Add._type := 'submit';
    Form.append(SiteShell.el('h3', '', Say('Add an emoji')), Chars, Name, Keywords, AFile, Add);
    Form.addEventListener('submit', TJSRawEventHandler(@Submit));
    Result := Form;
  end;

begin
  Root := SiteShell.el('section', 'emoji-admin');
  Root.append(SiteShell.el('h2', '', Say('Wiki emoji')), SiteShell.el('p', '',
    Say('Pages keep the emoji themselves. Here you choose how the wiki draws them: with its own picture, or as the reader''s computer does. A keyword typed between colons, like :yes:, becomes its emoji when a page is saved.')));
  Notice := SiteShell.el('p', 'emoji-admin-notice'); Notice.setAttribute('role', 'status');
  List := SiteShell.el('div', 'emoji-admin-list');
  Root.append(Notice, List, AddForm);
  Holder.appendChild(Root);
  Load;
end;

initialization
  if Truthy(SiteShell) and Truthy(SiteShell.extras) then
    TJSArray(SiteShell.extras['adminTabs']).push(new(['title', 'Emoji', 'permission', 'wiki-emoji', 'build', @Build, 'group', 'Wiki']));
end.
