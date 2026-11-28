unit WikiPage;

{ What a wiki page does for a reader: the language picker, times on the
  reader's clock, reading aids for an article, and emoji copied as text. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

implementation

uses JS, WebOrWorker, Web, PageKit;

type
  TWords = reference to function(const English: string): string;
  TCounted = reference to function(N: NativeInt; const One, Many: string): string;
  // Web has no time element, no details element and no replaceWith.
  TTimeElement = class external name 'HTMLTimeElement'(TJSHTMLElement)
    dateTime: string;
  end;
  TDetailsElement = class external name 'HTMLDetailsElement'(TJSHTMLElement)
    open: boolean;
  end;
  TReplaceable = class external name 'Element'(TJSElement)
    procedure replaceWith(Node: TJSNode);
  end;

const
  SVG = 'http://www.w3.org/2000/svg';
  ICON_COPY = 'M9 9h10v10H9zM5 15V5h10';
  ICON_DONE = 'M5 12l5 5L19 7';
  BOX_LINES = 20;
  KEEP = 8;

// words.js is optional here: other sites load this script without it.
function DateText(Value: JSValue): string; external name 'window.dateText';
function DateTimeText(Value: JSValue): string; external name 'window.dateTimeText';

{ The language form also works when scripts are disabled. }
procedure LanguageForm(Form: TJSHTMLFormElement);
var
  Picker: TJSElement;
begin
  Picker := Form.querySelector('select');
  Picker.addEventListener('change', TJSRawEventHandler(procedure(E: TJSEvent) begin Form.requestSubmit; end));
  TJSHTMLElement(Form.querySelector('button')).hidden := True;
end;

{ Times come as UTC; they are shown on the reader's clock, as the admin
  chose to show dates (words.js); a date alone stays a date. }
procedure Times;
var
  Stamps: TJSNodeList;
  Stamp: TTimeElement;
  When: TJSDate;
  I: integer;
begin
  Stamps := document.querySelectorAll('time[datetime]');
  for I := 0 to Stamps.length - 1 do
  begin
    Stamp := TTimeElement(Stamps[I]);
    When := TJSDate.new(Stamp.dateTime);
    if TJSNumber.isNaN(When.Time) or not Truthy(TJSObject(window)['dateText']) then Continue;
    Stamp.title := Stamp.textContent;
    if (Stamp.dataset['show'] = 'date') or (Length(Stamp.dateTime) = 10) then
    begin
      if Length(Stamp.dateTime) = 10 then Stamp.textContent := DateText(Stamp.dateTime)
      else Stamp.textContent := DateText(When);
    end
    else Stamp.textContent := DateTimeText(When);
  end;
end;

{ Reading aids for an article, added by script so the page still works
  without one: ids on the headings, a table of contents from three sections
  up, a copy button on each block of code, and a folded language bar. }
procedure ReadingAids;
var
  Body, Page, Side, Tools, Bar: TJSElement;
  ToolsHead: TJSHTMLElement;
  ToolsHome: TJSNode;
  T: TWords;
  TN: TCounted;
  Used: TJSSet;
  Headings, Opened, Movable, Items, Hidden, Part: TJSArray;
  Homes: TJSMap;
  Beside, WideSide: TJSMediaQueryList;
  Found: TJSNodeList;
  H, Link, Target, Pre, Wrap: TJSElement;
  B, More: TJSHTMLButtonElement;
  Mark: TJSNode;
  Id, Base: string;
  I, N: integer;

  // a heading's words, without the edit link a member is given beside them
  function Words(Heading: TJSElement): string;
  var
    Copy: TJSElement;
    Links: TJSNodeList;
    K: integer;
  begin
    Copy := TJSElement(Heading.cloneNode(True));
    Links := Copy.querySelectorAll('.sectionedit');
    for K := 0 to Links.length - 1 do TJSElement(Links[K]).remove;
    Result := TJSString(Copy.textContent).trim;
  end;

  procedure PlaceTools(E: TJSEvent);
  begin
    ToolsHead.hidden := not Beside.matches;
    if Beside.matches then ToolsHead.insertAdjacentElement('afterend', Tools)
    else ToolsHome.parentNode.insertBefore(Tools, ToolsHome.nextSibling);
  end;

  procedure PlaceBoxes(E: TJSEvent);
  var
    K: integer;
    Home: TJSNode;
  begin
    for K := 0 to Movable.length - 1 do
      if WideSide.matches then Side.appendChild(TJSNode(Movable[K]))
      else
      begin
        Home := TJSNode(Homes.get(Movable[K]));
        Home.parentNode.insertBefore(TJSNode(Movable[K]), Home.nextSibling);
      end;
  end;

  // a part its own script redraws: the new one takes the old one's place
  procedure Redrawn(Records: TJSMutationRecordArray; Observer: TJSMutationObserver);
  var
    R, K, Old: integer;
    Node: TJSElement;
  begin
    for R := 0 to Length(Records) - 1 do
      for K := 0 to Records[R].addedNodes.length - 1 do
      begin
        Node := TJSElement(Records[R].addedNodes[K]);
        if (Node.nodeType = 1) and Node.hasAttribute('data-beside') and not Movable.includes(Node) then
        begin
          Old := Movable.findIndex(function(Box: JSValue; Index: NativeInt; List: TJSArray): boolean
            begin
              Result := (TJSElement(Box).className = Node.className) and not Truthy(TJSObject(Box)['isConnected']);
            end);
          if Old >= 0 then
          begin
            Homes.&set(Node, Homes.get(Movable[Old]));
            Movable[Old] := Node;
          end;
        end;
      end;
  end;

  // the table of contents, and in it the section being read
  procedure Contents;
  var
    Toc, Summary, List, Li, Current: TJSElement;
    Details: TDetailsElement;
    A: TJSHTMLAnchorElement;
    Wide: TJSMediaQueryList;
    Links: TJSArray;
    Ticking: boolean;
    K: integer;

    procedure Fit(E: TJSEvent);
    begin
      Details.open := Wide.matches;
    end;

    // the last heading above a line a third of the way down the screen, and
    // at the page's end the last section, which could never reach that line
    procedure MarkNow(Time: TJSDOMHighResTimeStamp);
    var
      Line: double;
      Index, J: integer;
      AtEnd: boolean;
      Next: TJSElement;
    begin
      Ticking := False;
      Line := window.innerHeight * 0.3;
      Index := -1;
      AtEnd := window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 4;
      if AtEnd then Index := Headings.length - 1
      else
        for J := 0 to Headings.length - 1 do
          if TJSElement(Headings[J]).getBoundingClientRect.top <= Line then Index := J;
      // above every heading, the first section is the one being read
      if Index >= 0 then Next := TJSElement(Links[Index]) else Next := TJSElement(Links[0]);
      if not Truthy(Next) then Next := nil;
      if Next = Current then Exit;
      if Current <> nil then Current.classList.remove('now');
      Current := Next;
      if Current <> nil then
      begin
        Current.classList.add('now');
        // the list keeps the marked line in view when it scrolls itself
        if Truthy(TJSObject(Current)['scrollIntoView']) and Details.open and window.matchMedia('(min-width: 1320px)').matches then
          TJSHTMLElement(Current).scrollIntoView(TJSObject(new(['block', 'nearest'])));
      end;
    end;

    procedure OnScroll(E: TJSEvent);
    begin
      if not Ticking then
      begin
        Ticking := True;
        window.requestAnimationFrame(@MarkNow);
      end;
    end;

  begin
    Toc := document.createElement('nav');
    Toc.className := 'toc';
    Toc.setAttribute('aria-label', T('On this page'));
    Details := TDetailsElement(document.createElement('details'));
    Summary := document.createElement('summary');
    Summary.textContent := T('On this page');
    Details.appendChild(Summary);
    List := document.createElement('ol');
    for K := 0 to Headings.length - 1 do
    begin
      Li := document.createElement('li');
      if TJSElement(Headings[K]).tagName = 'H3' then Li.className := 'sub' else Li.className := '';
      A := TJSHTMLAnchorElement(document.createElement('a'));
      A.href := '#' + encodeURIComponent(TJSElement(Headings[K]).id);
      A.textContent := Words(TJSElement(Headings[K]));
      Li.appendChild(A);
      List.appendChild(Li);
    end;
    Details.appendChild(List);
    Toc.appendChild(Details);
    Side.insertBefore(Toc, Side.firstChild);
    Page.classList.add('has-toc');
    Wide := window.matchMedia('(min-width: 1320px)');
    Fit(nil);
    Wide.addEventListener('change', TJSRawEventHandler(@Fit));
    Links := TJSArray.new;
    for K := 0 to Headings.length - 1 do Links.push(List.children[K].firstChild);
    Current := nil;
    Ticking := False;
    window.addEventListener('scroll', TJSRawEventHandler(@OnScroll), TJSEventListenerOptions(new(['passive', True])));
    window.addEventListener('resize', TJSRawEventHandler(@OnScroll));
    MarkNow(0);
  end;

  procedure Icon(Button: TJSElement; const Path: string);
  var
    Picture, Line: TJSElement;
  begin
    Picture := document.createElementNS(SVG, 'svg');
    Picture.setAttribute('viewBox', '0 0 24 24');
    Picture.setAttribute('aria-hidden', 'true');
    Line := document.createElementNS(SVG, 'path');
    Line.setAttribute('d', Path);
    Line.setAttribute('fill', 'none');
    Line.setAttribute('stroke', 'currentColor');
    Line.setAttribute('stroke-width', '2');
    Line.setAttribute('stroke-linejoin', 'round');
    Line.setAttribute('stroke-linecap', 'round');
    Picture.appendChild(Line);
    Button.replaceChildren(Picture);
  end;

  // copy a block of code: an icon at its top right, a tick for a moment when it is done
  procedure CopyButton(Button: TJSHTMLElement; Block: TJSElement);
  begin
    Icon(Button, ICON_COPY);
    Button.title := T('Copy');
    Button.setAttribute('aria-label', T('Copy'));
    Button.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
      begin
        window.navigator.clipboard.writeText(Block.textContent)._then(function(Value: JSValue): JSValue
          begin
            Icon(Button, ICON_DONE);
            Button.classList.add('ok');
            Button.title := T('Copied');
            window.setTimeout(procedure
              begin
                Icon(Button, ICON_COPY);
                Button.classList.remove('ok');
                Button.title := T('Copy');
              end, 1500);
          end);
      end));
  end;

  // a long block of code in a box of its own height, and a bar under it that shows all of it
  procedure LongBlock(Block: TJSHTMLElement);
  var
    Lines: NativeInt;
    Box, Foot: TJSElement;
    Whole: TJSHTMLButtonElement;

    procedure Caption;
    var
      Open: boolean;
    begin
      Open := Box.classList.contains('whole');
      if Open then Whole.textContent := T('Show less')
      else Whole.textContent := TN(Lines, 'Show all %d line', 'Show all %d lines');
      if Open then Whole.setAttribute('aria-expanded', 'true') else Whole.setAttribute('aria-expanded', 'false');
    end;

  begin
    Lines := Length(TJSString(TJSString(Block.textContent).replace(TJSRegexp.new('\n+$'), '')).split(#10));
    // a few lines past the box are not worth a scroll bar
    if Lines <= BOX_LINES + 5 then Exit;
    Box := Block.closest('.code');
    if Box = nil then Box := Block.closest('.codebox');
    if Box = nil then Box := Block;
    Box.classList.add('scrollbox');
    Foot := document.createElement('div');
    Foot.className := 'code-boxbar';
    Whole := TJSHTMLButtonElement(document.createElement('button'));
    Whole._type := 'button';
    Whole.className := 'code-whole';
    Whole.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
      var
        Open: boolean;
      begin
        Open := Box.classList.toggle('whole');
        // a height dragged by hand gives way to the choice just made
        TJSObject(Block.style)['height'] := '';
        Caption;
        if not Open and (Box.getBoundingClientRect.top < 0) then TJSHTMLElement(Box).scrollIntoView(TJSObject(new(['block', 'start'])));
      end));
    Caption;
    Foot.append(Whole);
    if Box = Block then Box.insertAdjacentElement('afterend', Foot) else Box.insertAdjacentElement('beforeend', Foot);
  end;

begin
  Body := document.querySelector('.wikipage > .wikibody');
  Page := document.querySelector('.wikipage');
  if (Body = nil) or (Page = nil) then Exit;
  if Truthy(TJSObject(window)['t']) then T := TWords(TJSObject(window)['t'])
  else T := function(const English: string): string begin Result := English; end;
  if Truthy(TJSObject(window)['tn']) then TN := TCounted(TJSObject(window)['tn'])
  else TN := function(Count: NativeInt; const One, Many: string): string
    begin
      if Count = 1 then Result := One else Result := Many;
      Result := TJSString(Result).replace('%d', String(JSValue(Count)));
    end;

  // ids: the heading's words, as MediaWiki writes them, so links from there still land
  Used := TJSSet.new;
  Headings := TJSArray.new;
  Found := Body.querySelectorAll('h2, h3');
  for I := 0 to Found.length - 1 do
    if Words(TJSElement(Found[I])) <> '' then Headings.push(Found[I]);
  for I := 0 to Headings.length - 1 do
  begin
    H := TJSElement(Headings[I]);
    if H.id <> '' then
    begin
      Used.add(H.id);
      Continue;
    end;
    Id := TJSString(TJSString(Words(H)).replace(TJSRegexp.new('\s+', 'g'), '_')).replace(TJSRegexp.new('[\[\]{}|#<>"'']', 'g'), '');
    N := 2;
    Base := Id;
    while Used.has(Id) or (document.getElementById(Id) <> nil) do
    begin
      Id := Base + '_' + String(JSValue(N));
      Inc(N);
    end;
    H.id := Id;
    Used.add(Id);
  end;
  if window.location.hash <> '' then
  begin
    // #section-3 is where a saved section edit comes back to
    Part := TJSArray(TJSRegexp.new('^#section-(\d+)$').execFull(window.location.hash));
    Link := nil;
    if Part <> nil then Link := Body.querySelector('.sectionedit[href$="section=' + string(Part[1]) + '"]');
    if Link <> nil then Target := Link.parentElement
    else Target := document.getElementById(decodeURIComponent(TJSString(window.location.hash).slice(1)));
    if Target <> nil then TJSHTMLElement(Target).scrollIntoView;
  end;

  // Save as PDF: the browser's print, with folded sections opened for the
  // paper and closed again after, whichever way the print was started
  Opened := TJSArray.new;
  window.addEventListener('beforeprint', TJSRawEventHandler(procedure(E: TJSEvent)
    var
      Folded: TJSNodeList;
      K: integer;
    begin
      Folded := Body.querySelectorAll('details:not([open])');
      for K := 0 to Folded.length - 1 do
      begin
        TDetailsElement(Folded[K]).open := True;
        Opened.push(Folded[K]);
      end;
    end));
  window.addEventListener('afterprint', TJSRawEventHandler(procedure(E: TJSEvent)
    begin
      while Opened.length > 0 do TDetailsElement(Opened.pop).open := False;
    end));
  Found := Page.querySelectorAll('[data-print]');
  for I := 0 to Found.length - 1 do
  begin
    TJSHTMLElement(Found[I]).hidden := False;
    Found[I].addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent) begin window.print; end));
  end;

  // the right column on a wide screen: the contents (when there are enough
  // sections) and the page's cards, which on a phone stay at the foot
  Side := document.createElement('aside');
  Side.className := 'wiki-side';
  Tools := Page.querySelector(':scope > .pagetools');
  if Tools <> nil then Tools.insertAdjacentElement('afterend', Side)
  else Body.insertAdjacentElement('beforebegin', Side);
  Page.classList.add('has-side');
  // the page's tools sit in the left column while there is one beside the page
  ToolsHead := TJSHTMLElement(document.querySelector('.siteside [data-page-tools]'));
  if (Tools <> nil) and (ToolsHead <> nil) then
  begin
    ToolsHome := document.createComment('tools');
    Tools.parentNode.insertBefore(ToolsHome, Tools);
    Beside := window.matchMedia('(min-width: 901px)');
    PlaceTools(nil);
    Beside.addEventListener('change', TJSRawEventHandler(@PlaceTools));
  end;
  // what other units put under a page (its bench; anything marked data-beside)
  // sits in the side column on a wide screen, and where it was on a narrow one
  Movable := TJSArray.from(Page.querySelectorAll(':scope > .page-bench, :scope > [data-beside]'));
  Homes := TJSMap.new;
  for I := 0 to Movable.length - 1 do
  begin
    Mark := document.createComment('home');
    TJSNode(Movable[I]).parentNode.insertBefore(Mark, TJSNode(Movable[I]));
    Homes.&set(Movable[I], Mark);
  end;
  WideSide := window.matchMedia('(min-width: 1320px)');
  PlaceBoxes(nil);
  WideSide.addEventListener('change', TJSRawEventHandler(@PlaceBoxes));
  // Web's own record for these options spells subtree with a capital T.
  TJSMutationObserver.new(@Redrawn).observe(Page, TJSObject(new(['childList', True, 'subtree', True])));

  // not on a page laid out across the whole width (one marked no-contents),
  // where the contents have no column to sit in
  if (Headings.length >= 3) and (document.querySelector('.no-contents') = nil) then Contents;

  // one copy button at the top right of every block: the renderer's own in
  // the code bar, one of ours on a bare block
  if Truthy(TJSObject(window.navigator)['clipboard']) then
  begin
    Found := Body.querySelectorAll('.code .codebar .copy');
    for I := 0 to Found.length - 1 do
      CopyButton(TJSHTMLElement(Found[I]), TJSElement(Found[I]).closest('.code').querySelector('pre'));
    Found := Body.querySelectorAll('pre');
    for I := 0 to Found.length - 1 do
    begin
      Pre := TJSElement(Found[I]);
      if Pre.closest('.code') <> nil then Continue;
      Wrap := document.createElement('div');
      Wrap.className := 'codebox';
      Pre.parentNode.insertBefore(Wrap, Pre);
      Wrap.appendChild(Pre);
      B := TJSHTMLButtonElement(document.createElement('button'));
      B._type := 'button';
      B.className := 'copybtn';
      CopyButton(B, Pre);
      Wrap.appendChild(B);
    end;
  end
  else
  begin
    Found := Body.querySelectorAll('.code .codebar .copy');
    for I := 0 to Found.length - 1 do TJSHTMLElement(Found[I]).hidden := True;
  end;

  // Copy and the printout always have all of a long block.
  Found := Body.querySelectorAll('pre');
  for I := 0 to Found.length - 1 do LongBlock(TJSHTMLElement(Found[I]));

  // many languages: the first few, and a button for the rest
  Bar := Page.querySelector('.languages');
  if Bar <> nil then
  begin
    // the dots the server writes between names are not wanted between pills;
    // Web declares remove on elements only, the cast keeps the browser's call
    Items := TJSArray.from(Bar.childNodes);
    for I := 0 to Items.length - 1 do
      if TJSNode(Items[I]).nodeType = 3 then TJSElement(Items[I]).remove;
    Items := TJSArray.from(Bar.querySelectorAll('a, b'));
    if Items.length > KEEP + 2 then
    begin
      Hidden := TJSArray.new;
      for I := KEEP to Items.length - 1 do
        if TJSElement(Items[I]).tagName <> 'B' then Hidden.push(Items[I]);
      for I := 0 to Hidden.length - 1 do TJSHTMLElement(Hidden[I]).hidden := True;
      More := TJSHTMLButtonElement(document.createElement('button'));
      More._type := 'button';
      More.className := 'more-languages';
      More.textContent := TN(Hidden.length, '+%d more language', '+%d more languages');
      More.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
        var
          K: integer;
        begin
          for K := 0 to Hidden.length - 1 do TJSHTMLElement(Hidden[K]).hidden := False;
          More.remove;
        end));
      Bar.appendChild(More);
    end;
  end;
end;

{ The wiki draws its emoji with its own pictures.  A copy takes the emoji
  themselves, as text, wherever the words are pasted. }
procedure CopyEmoji(E: TJSEvent);
var
  Pick: TJSSelection;
  Data: TJSDataTransfer;
  Part: TJSDocumentFragment;
  Pictures: TJSNodeList;
  Holder: TJSHTMLElement;
  I: integer;

  // the words as the selection gives them, line breaks between blocks kept
  function TextOf: string;
  begin
    Holder.style.cssText := 'position:fixed;left:-9999px;top:0;white-space:pre-wrap';
    document.body.appendChild(Holder);
    Result := Holder.innerText;
    Holder.remove;
  end;

begin
  Pick := window.getSelection;
  Data := TJSClipboardEvent(E).clipboardData;
  if not Truthy(Pick) or Pick.isCollapsed or not Truthy(Data) then Exit;
  Part := Pick.getRangeAt(0).cloneContents;
  Pictures := Part.querySelectorAll('img.emo');
  if Pictures.length = 0 then Exit;
  for I := 0 to Pictures.length - 1 do
    TReplaceable(Pictures[I]).replaceWith(document.createTextNode(TJSHTMLImageElement(Pictures[I]).alt));
  Holder := TJSHTMLElement(document.createElement('div'));
  Holder.appendChild(Part);
  if Length(Pick.toString) > 0 then Data.setData('text/plain', TextOf) else Data.setData('text/plain', '');
  // the page's own nodes, copied back out as they are
  Data.setData('text/html', Holder.innerHTML);
  E.preventDefault;
end;

procedure Start;
var
  Forms: TJSNodeList;
  I: integer;
begin
  Forms := document.querySelectorAll('.wiki-language');
  for I := 0 to Forms.length - 1 do LanguageForm(TJSHTMLFormElement(Forms[I]));
  Times;
  ReadingAids;
  document.addEventListener('copy', TJSRawEventHandler(@CopyEmoji));
end;

initialization
  Start;
end.
