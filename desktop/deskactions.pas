unit DeskActions;

{$mode objfpc}{$H+}

interface

uses
  fpjson;

type
  TRowAction = (raLeave, raDeleteChannel, raDeleteConversation, raSilence, raMentions, raNotifyAll);
  TRowActions = set of TRowAction;

function RowActions(Info: TJSONObject; Conversation: boolean): TRowActions;
function NotifyMode(Info: TJSONObject): string;
function NotifyActionMode(Action: TRowAction): string;
function RoomUnread(Info: TJSONObject): integer;
function RoomMentions(Info: TJSONObject): integer;
function NoticeRoom(Before, After: TJSONArray; const NamedRoom: string): string;
function MayDeleteMessage(Msg: TJSONObject; const Member: string; Conversation, DeleteAny: boolean; DeleteOwn: boolean = True): boolean;
{ Removes the message and returns its former place, or -1 if absent. }
function RemoveMessage(List: TJSONArray; Id: integer): integer;

implementation

uses
  SysUtils;

function NotifyMode(Info: TJSONObject): string;
begin
  Result := 'all';
  if Info <> nil then
    Result := Info.Get('notify', 'all');
  if (Result <> 'none') and (Result <> 'mentions') then
    Result := 'all';
end;

function NotifyActionMode(Action: TRowAction): string;
begin
  case Action of
    raSilence: Result := 'none';
    raMentions: Result := 'mentions';
    raNotifyAll: Result := 'all';
    else
      Result := '';
  end;
end;

function RoomUnread(Info: TJSONObject): integer;
begin
  Result := 0;
  if Info = nil then
    Exit;
  if NotifyMode(Info) = 'all' then
    Result := Info.Get('unread', 0)
  else if NotifyMode(Info) = 'mentions' then
    Result := Info.Get('mentions', 0);
end;

function RoomMentions(Info: TJSONObject): integer;
begin
  Result := 0;
  if (Info <> nil) and (NotifyMode(Info) <> 'none') then
    Result := Info.Get('mentions', 0);
end;

function NoticeRoom(Before, After: TJSONArray; const NamedRoom: string): string;
var
  Item, OldItem: TJSONEnum;
  Current, Previous: TJSONObject;
begin
  Result := '';
  for Item in After do
  begin
    Current := TJSONObject(Item.Value);
    if NotifyMode(Current) = 'none' then
      Continue;
    if NamedRoom <> '' then
    begin
      if Current.Get('slug', '') = NamedRoom then
        Exit(NamedRoom);
      Continue;
    end;
    Previous := nil;
    for OldItem in Before do
      if TJSONObject(OldItem.Value).Get('slug', '') = Current.Get('slug', '') then
      begin
        Previous := TJSONObject(OldItem.Value);
        Break;
      end;
    if (Previous = nil) or (Current.Get('mentions', 0) > Previous.Get('mentions', 0)) then
      Exit(Current.Get('slug', ''));
  end;
end;

function RowActions(Info: TJSONObject; Conversation: boolean): TRowActions;
begin
  Result := [];
  if Conversation then
    Exit([raDeleteConversation]);
  if Info = nil then
    Exit;
  // Sidebar channels are followed; a room card can state otherwise.
  if (Info.Get('kind', '') <> 'shelf') and Info.Get('following', True) then
  begin
    Include(Result, raLeave);
    if NotifyMode(Info) <> 'none' then Include(Result, raSilence);
    if NotifyMode(Info) <> 'mentions' then Include(Result, raMentions);
    if NotifyMode(Info) <> 'all' then Include(Result, raNotifyAll);
  end;
  if Info.Get('private', False) and Info.Get('owner', False) then
    Include(Result, raDeleteChannel);
end;

function MayDeleteMessage(Msg: TJSONObject; const Member: string; Conversation, DeleteAny: boolean; DeleteOwn: boolean = True): boolean;
begin
  // one's own message in a channel needs the site's delete-own, as the server asks; a private one is always one's own to delete
  Result := (Msg <> nil) and (Member <> '') and not Msg.Get('deleted', False) and ((SameText(Msg.Get('name', ''), Member) and (Conversation or DeleteOwn)) or
    (not Conversation and DeleteAny));
end;

function RemoveMessage(List: TJSONArray; Id: integer): integer;
var
  I: integer;
begin
  Result := -1;
  if Id <= 0 then
    Exit;
  for I := 0 to List.Count - 1 do
    if TJSONObject(List[I]).Get('id', 0) = Id then
    begin
      List.Delete(I);
      Exit(I);
    end;
end;

end.
