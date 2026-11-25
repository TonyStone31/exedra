unit ForumRequest;

{ Forum request fields and refusals. Refuse raises EForumRequest;
  Forum.Handle and ForumPages catch it, roll back any transaction and send
  the response. Individual operations return data rather than sending
  answers. }

{$mode objfpc}{$H+}

interface

uses
  SysUtils, httpdefs;

type
  EForumRequest = class(Exception)
  public
    Code: integer;
    constructor Create(Status: integer; const Words: string);
  end;

{ Stops the request: Status is the HTTP status, Words what the member is told. }
procedure Refuse(Status: integer; const Words: string);
{ A field of the form sent, '' when it is not there. }
function Field(R: TRequest; const Name: string): string;
{ A whole number above zero, or the request is refused. }
function Number(const Text: string): integer;
{ A field that may be left out (0 then); refused when it is not a number. }
function OptionalNumber(R: TRequest; const Name: string): integer;
{ A field that has to be 0 or 1. }
function Flag(R: TRequest; const Name: string): integer;
{ Refuses text that is empty, too long or has control characters in it. }
procedure CheckText(const Text: string; MaxBytes: integer; SingleLine: boolean);

implementation

uses
  ForumRules;

constructor EForumRequest.Create(Status: integer; const Words: string);
begin
  inherited Create(Words);
  Code := Status;
end;

procedure Refuse(Status: integer; const Words: string);
begin
  raise EForumRequest.Create(Status, Words);
end;

function Number(const Text: string): integer;
begin
  Result := StrToIntDef(Text, 0);
  if Result <= 0 then
    Refuse(400, 'Enter a valid number.');
end;

function Field(R: TRequest; const Name: string): string;
begin
  Result := R.ContentFields.Values[Name];
end;

function OptionalNumber(R: TRequest; const Name: string): integer;
var
  Text: string;
begin
  Result := 0;
  Text := Field(R, Name);
  if (Text <> '') and not TryStrToInt(Text, Result) then
    Refuse(400, 'Enter a valid number.');
end;

procedure CheckText(const Text: string; MaxBytes: integer; SingleLine: boolean);
var
  Problem: string;
begin
  Problem := ForumTextProblem(Text, MaxBytes, SingleLine);
  if Problem <> '' then
    Refuse(400, Problem);
end;

function Flag(R: TRequest; const Name: string): integer;
begin
  if not (Field(R, Name) = '0') and not (Field(R, Name) = '1') then
    Refuse(400, 'Use 0 or 1 for this option.');
  Result := StrToInt(Field(R, Name));
end;

end.
