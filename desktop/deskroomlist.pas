unit DeskRoomList;

{$mode objfpc}{$H+}

interface

uses
  Classes, Types, Controls, StdCtrls, InkListBox;

type
  TRowMenuEvent = procedure(Sender: TObject; Index: integer; const Position: TPoint) of object;

  TDeskRoomList = class(TInkListBox)
  private
    FRowKeys: TStrings;
    FOnRowMenu: TRowMenuEvent;
    FMenuPress: boolean;
    function IsRow(Index: integer): boolean;
    function MenuWidth: integer;
    function MenuRight(Index: integer): integer;
  protected
    procedure DrawItem(Index: integer; ARect: TRect; State: TOwnerDrawState); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
    procedure DoContextPopup(MousePos: TPoint; var Handled: boolean); override;
    procedure KeyDown(var Key: word; Shift: TShiftState); override;
  public
    procedure Click; override;
    property RowKeys: TStrings read FRowKeys write FRowKeys;
  published
    property OnRowMenu: TRowMenuEvent read FOnRowMenu write FOnRowMenu;
  end;

implementation

uses
  Graphics, Math, LCLType;

function TDeskRoomList.IsRow(Index: integer): boolean;
begin
  Result := (FRowKeys <> nil) and (Index >= 0) and (Index < FRowKeys.Count) and (FRowKeys[Index] <> '');
end;

function TDeskRoomList.MenuWidth: integer;
begin
  Result := Scale96ToFont(24);
end;

function TDeskRoomList.MenuRight(Index: integer): integer;
begin
  Result := Min(ClientWidth, ItemRect(Index).Right);
end;

procedure TDeskRoomList.DrawItem(Index: integer; ARect: TRect; State: TOwnerDrawState);
var
  TextRect: TRect;
  X, Y, Half: integer;
begin
  if not IsRow(Index) then
  begin
    inherited DrawItem(Index, ARect, State);
    Exit;
  end;
  TextRect := ARect;
  TextRect.Right := Min(TextRect.Right, ClientWidth) - MenuWidth;
  inherited DrawItem(Index, TextRect, State);
  ARect.Left := TextRect.Right;
  ARect.Right := Min(ARect.Right, ClientWidth);
  Canvas.FillRect(ARect);
  if [odSelected, odFocused] * State <> [] then
    Canvas.Pen.Color := SelectionTextColor
  else
    Canvas.Pen.Color := Font.Color;
  X := (ARect.Left + ARect.Right) div 2;
  Y := (ARect.Top + ARect.Bottom) div 2;
  Half := Scale96ToFont(3);
  Canvas.Polyline([Point(X - Half, Y - Half div 2), Point(X, Y + Half div 2), Point(X + Half, Y - Half div 2)]);
end;

procedure TDeskRoomList.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
var
  Index: integer;
begin
  Index := ItemAtPos(Point(X, Y), True);
  FMenuPress := Button = mbRight;
  if (Button = mbLeft) and IsRow(Index) then
    FMenuPress := X >= MenuRight(Index) - MenuWidth;
  if not FMenuPress then
    inherited MouseDown(Button, Shift, X, Y);
end;

procedure TDeskRoomList.Click;
begin
  if not FMenuPress then
    inherited Click;
end;

procedure TDeskRoomList.KeyDown(var Key: word; Shift: TShiftState);
begin
  FMenuPress := False;
  inherited KeyDown(Key, Shift);
end;

procedure TDeskRoomList.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
var
  Index: integer;
begin
  if FMenuPress then
  begin
    if Button = mbLeft then
    begin
      Index := ItemAtPos(Point(X, Y), True);
      if IsRow(Index) and Assigned(FOnRowMenu) then
        FOnRowMenu(Self, Index, ClientToScreen(Point(MenuRight(Index) - MenuWidth, ItemRect(Index).Bottom)));
    end;
    Exit;
  end;
  inherited MouseUp(Button, Shift, X, Y);
end;

procedure TDeskRoomList.DoContextPopup(MousePos: TPoint; var Handled: boolean);
var
  Index: integer;
begin
  Handled := True;
  if (MousePos.X < 0) and (MousePos.Y < 0) then
  begin
    Index := ItemIndex;
    if Index >= 0 then
      MousePos := Point(MenuRight(Index) - MenuWidth, ItemRect(Index).Bottom);
  end
  else
    Index := ItemAtPos(MousePos, True);
  if IsRow(Index) and Assigned(FOnRowMenu) then
    FOnRowMenu(Self, Index, ClientToScreen(MousePos));
end;

end.
