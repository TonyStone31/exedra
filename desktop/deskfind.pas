unit DeskFind;

{ A list of messages from somewhere else: what a search found, or what is
  pinned in a room.  A click on a room's name takes the reader there. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, fpjson, InkMemo, InkPage, DeskContent, DeskNet;

type
  TFindForm = class(TForm)
    FindPanel: TPanel;
    SearchRow: TPanel;
    OnlyHere: TCheckBox;
    FindEdit: TEdit;
    FindButton: TButton;
    Results: TInkMemo;
    procedure FindButtonClick(Sender: TObject);
    procedure FindEditKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure ResultsLinkClick(Sender: TObject; LineIndex: integer; const LinkName: string);
    procedure ResultsKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
  private
    Generation: integer;
    procedure SearchDone(Job: TApiJob);
    procedure PinsDone(Job: TApiJob);
  private
    Matches: TJSONArray;
    Previews: TPreviewState;
    EmptyText: string;
    Target: TApiTarget;
    Picture: TInkPageResourceEvent;
    procedure ResultsResource(Sender: TObject; const URL: string; Destination: TStream; var Handled: boolean);
    function EntryHtml(Msg: TJSONObject): string;
    procedure Render;
  public
    Room: string;   // where to look; on return, the room the reader picked
    Picked: boolean;
    Link: string;   // a message (msg:room:id) or thread (thread:id) link picked instead
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ShowList(List: TJSONArray; const Empty: string);
  end;

{ Searches Room, or every room (Ctrl+F); returns True when the reader picked
  something to go to: Room is then the room, and Link the message or thread
  within it when one was picked ('' for the room itself). }
function FindInRoom(var Room: string; out Link: string; Picture: TInkPageResourceEvent = nil): boolean;
{ What is pinned in Room. }
function ShowPins(var Room: string; out Link: string; Picture: TInkPageResourceEvent = nil): boolean;
procedure FindPictureArrived(const URL: string);

implementation

uses
  LCLType, LCLIntf, InkMarkdown, DeskView;

  {$R *.lfm}

constructor TFindForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Target := ApiTarget;
  Matches := TJSONArray.Create;
  Previews := TPreviewState.Create;
end;

destructor TFindForm.Destroy;
begin
  ApiForgetReceiver(Self);
  Previews.Free;
  Matches.Free;
  inherited Destroy;
end;

function TFindForm.EntryHtml(Msg: TJSONObject): string;
var
  GoTo_: string;
begin
  if Msg.Get('dm', False) then
    Exit('<p class="at"><a href="msg:' + Escape(Room) + ':' + IntToStr(Msg.Get('id', 0)) + '">go to the message</a></p>' +
      MessageHtml(Msg, False, Previews.IsOpen(Msg), Previews.FocusId = Msg.Get('id', 0)));
  if Msg.Get('parent', 0) > 0 then
    GoTo_ := '<a href="thread:' + Escape(Msg.Get('room', '')) + ':' + IntToStr(Msg.Get('parent', 0)) + '">open the thread</a>'
  else
    GoTo_ := '<a href="msg:' + Escape(Msg.Get('room', '')) + ':' + IntToStr(Msg.Get('id', 0)) + '">go to the message</a>';
  Result := '<p class="at"><a href="room:' + Escape(Msg.Get('room', '')) + '">#' + Escape(Msg.Get('room', '')) + '</a> &nbsp;&middot;&nbsp; ' +
    GoTo_ + '</p>' + MessageHtml(Msg, False, Previews.IsOpen(Msg), Previews.FocusId = Msg.Get('id', 0));
end;

procedure TFindForm.ShowList(List: TJSONArray; const Empty: string);
begin
  Matches.Free;
  Matches := List.Clone as TJSONArray;
  EmptyText := Empty;
  Previews.Clear;
  Render;
  Results.ScrollTo(0);
end;

procedure TFindForm.Render;
var
  Item: TJSONEnum;
begin
  Results.Clear;
  if Matches.Count = 0 then
    Results.AppendBlock('<p><i>' + Escape(EmptyText) + '</i></p>', itfHTML);
  Results.BeginUpdate;
  try
    for Item in Matches do
      Results.AppendBlock(EntryHtml(TJSONObject(Item.Value)), itfHTML);
  finally
    Results.EndUpdate;
  end;
end;

procedure TFindForm.ResultsResource(Sender: TObject; const URL: string; Destination: TStream; var Handled: boolean);
begin
  Handled := True;
  if ApiTargetCurrent(Target) and Assigned(Picture) then Picture(Sender, URL, Destination, Handled);
end;

procedure TFindForm.FindButtonClick(Sender: TObject);
var
  Path: string;
begin
  if not ApiTargetCurrent(Target) then Exit;
  Inc(Generation);
  if Room.StartsWith('@') and OnlyHere.Checked then
    Path := '/api/dm/search?' + Query(['with', Copy(Room, 2, MaxInt), 'q', Trim(FindEdit.Text)])
  else if OnlyHere.Checked then
    Path := '/api/search?' + Query(['q', Trim(FindEdit.Text), 'room', Room])
  else
    Path := '/api/search?' + Query(['q', Trim(FindEdit.Text)]);
  ApiGetAsync(Path, @SearchDone, Generation, 'find');
end;

procedure TFindForm.SearchDone(Job: TApiJob);
var
  List: TJSONArray;
  I: integer;
  Msg: TJSONObject;
begin
  if (Job.Tag <> Generation) or not ApiTargetCurrent(Target) then Exit;
  try
    List := Job.ArrayJSON;
    try
      if Pos('/api/dm/search?', Job.Path) > 0 then
        for I := 0 to List.Count - 1 do
        begin
          if not (List[I] is TJSONObject) then raise Exception.Create('The server returned an invalid message.');
          Msg := DmAsMessage(TJSONObject(List[I]));
          Msg.Add('dm', True);
          List[I] := Msg;
        end;
      ShowList(List, 'Nothing found. Words of three letters or more find more.');
    finally
      List.Free;
    end;
  except
    on E: Exception do
      if not ApiErrorHandled(E) then Results.AppendBlock('<p><i>' + Escape(E.Message) + '</i></p>', itfHTML);
  end;
end;

procedure TFindForm.PinsDone(Job: TApiJob);
var
  List: TJSONArray;
begin
  if not ApiTargetCurrent(Target) then Exit;
  try
    List := Job.ArrayJSON;
    try
      ShowList(List, 'Nothing is pinned here.');
    finally
      List.Free;
    end;
  except
    on E: Exception do
      if not ApiErrorHandled(E) then Results.AppendBlock('<p><i>' + Escape(E.Message) + '</i></p>', itfHTML);
  end;
end;

procedure TFindForm.FindEditKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
    Close;
end;

procedure TFindForm.ResultsLinkClick(Sender: TObject; LineIndex: integer; const LinkName: string);
var
  Parts: TStringArray;
  I, Id: integer;
begin
  // an address from the server's HTML carries the path the site sits under: handled without it
  if SiteLocal(LinkName) <> LinkName then
  begin
    ResultsLinkClick(Sender, LineIndex, SiteLocal(LinkName));
    Exit;
  end;
  if not ApiTargetCurrent(Target) then Exit;
  if LinkName.StartsWith('preview:') then
  begin
    Id := StrToIntDef(Copy(LinkName, 9, MaxInt), 0);
    for I := 0 to Matches.Count - 1 do
      if TJSONObject(Matches[I]).Get('id', 0) = Id then
      begin
        Previews.Toggle(TJSONObject(Matches[I]));
        Results.ReplaceBlock(I, EntryHtml(TJSONObject(Matches[I])), itfHTML);
        Break;
      end;
  end
  else if WebAddress(LinkName) then
    OpenURL(LinkName)
  else if LinkName.StartsWith('/') then
    OpenURL(Server + LinkName)
  else if LinkName.StartsWith('dmquote:') and Room.StartsWith('@') then
  begin
    Link := 'msg:' + Room + ':' + Copy(LinkName, 9, MaxInt);
    Picked := True;
    Close;
  end
  else if LinkName.StartsWith('room:') then
  begin
    Room := Copy(LinkName, 6, MaxInt);
    Picked := True;
    Close;
  end
  else if LinkName.StartsWith('msg:') then
  begin
    Parts := LinkName.Split([':']);
    if Length(Parts) = 3 then
      Room := Parts[1];
    Link := LinkName;
    Picked := True;
    Close;
  end
  else if LinkName.StartsWith('thread:') then
  begin
    Parts := LinkName.Split([':']);
    if Length(Parts) = 3 then
      Room := Parts[1];
    Link := LinkName;
    Picked := True;
    Close;
  end;
end;

procedure TFindForm.ResultsKeyDown(Sender: TObject; var Key: word; Shift: TShiftState);
var
  I, B: integer;
  Preview: TJSONObject;
begin
  if (Shift = [ssAlt]) and ((Key = VK_DOWN) or (Key = VK_UP)) then
  begin
    I := Previews.Step(Matches, Key = VK_UP);
    if I >= 0 then
    begin
      Render;
      for B := 0 to Results.BlockCount - 1 do
        if Results.Block(B).Entry = I then
        begin
          Results.ScrollTo(Results.Block(B).Bounds.Top);
          Break;
        end;
    end;
    Key := 0;
  end
  else if (Shift = []) and ((Key = VK_RETURN) or (Key = VK_SPACE)) and (Previews.FocusId > 0) then
  begin
    ResultsLinkClick(Sender, -1, 'preview:' + IntToStr(Previews.FocusId));
    Key := 0;
  end
  else if (Shift = [ssCtrl]) and (Key = VK_RETURN) then
  begin
    for I := 0 to Matches.Count - 1 do
      if TJSONObject(Matches[I]).Get('id', 0) = Previews.FocusId then
      begin
        Preview := PreviewOf(TJSONObject(Matches[I]));
        if Preview <> nil then
          OpenURL(Preview.Get('url', ''));
        Break;
      end;
    Key := 0;
  end;
end;

procedure FindPictureArrived(const URL: string);
var
  I: integer;
begin
  for I := 0 to Screen.FormCount - 1 do
    if Screen.Forms[I] is TFindForm then
      TFindForm(Screen.Forms[I]).Results.ResourceChanged(URL);
end;

function FindInRoom(var Room: string; out Link: string; Picture: TInkPageResourceEvent): boolean;
var
  F: TFindForm;
begin
  F := TFindForm.Create(Application);
  try
    F.Room := Room;
    F.Picture := Picture;
    F.Results.OnResource := @F.ResultsResource;
    F.Caption := 'Find';
    StripeMemo(F.Results);
    // this room only, or everywhere one may read
    if Room.StartsWith('@') then
    begin
      F.Caption := 'Find in conversation with ' + Copy(Room, 2, MaxInt);
      F.OnlyHere.Caption := 'Only in this conversation';
      F.FindEdit.TextHint := 'Words to find';
    end
    else
      F.OnlyHere.Caption := 'Only in #' + Room;
    F.OnlyHere.Hint := F.OnlyHere.Caption;
    F.OnlyHere.ShowHint := True;
    F.OnlyHere.Checked := True;
    F.ShowModal;
    Result := F.Picked and ApiTargetCurrent(F.Target);
    Room := F.Room;
    Link := F.Link;
  finally
    F.Free;
  end;
end;

function ShowPins(var Room: string; out Link: string; Picture: TInkPageResourceEvent): boolean;
var
  F: TFindForm;
begin
  Link := '';
  F := TFindForm.Create(Application);
  try
    F.Room := Room;
    F.Picture := Picture;
    F.Results.OnResource := @F.ResultsResource;
    F.Caption := 'Pinned in #' + Room;
    StripeMemo(F.Results);
    F.FindPanel.Visible := False;
    ApiGetAsync('/api/pins?' + Query(['room', Room]), @F.PinsDone);
    F.ShowModal;
    Result := F.Picked and ApiTargetCurrent(F.Target);
    Room := F.Room;
    Link := F.Link;
  finally
    F.Free;
  end;
end;

end.
