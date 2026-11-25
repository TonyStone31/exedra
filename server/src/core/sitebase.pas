unit SiteBase;

{ A site that does not have a domain to itself: it sits under a path of
  one, https://example.com/community.  That path is the base.  It comes
  off every request before the program looks at the address, and goes
  on every address the program sends out.  With no base (the usual
  case) nothing here changes anything. }

{$mode objfpc}{$H+}

interface

{ The base: '' at the top of a domain, else '/community', no slash at the end. }
function BasePath: string;
{ Takes the base from the site's public address, the url setting. }
procedure SetBaseFromUrl(const Url: string);
{ A request's address without the base: /community/wiki/X gives /wiki/X.
  An address that does not start with the base comes back as it is, so a
  proxy that already took it off works too. }
function WithoutBase(const Address: string): string;
{ An address that starts at / with the base before it; others unchanged. }
function WithBase(const Address: string): string;
{ A page with the base put before every address in it that starts at /. }
function RebaseHtml(const Page: string): string;
{ The same for HTML carried inside a JSON answer. }
function RebaseJson(const Answer: string): string;

implementation

uses SysUtils, StrUtils;

var
  Base: string = '';

function BasePath: string;
begin
  Result := Base;
end;

procedure SetBaseFromUrl(const Url: string);
var
  P: integer;
begin
  Base := '';
  P := Pos('://', Url);
  if P = 0 then
    Exit;
  P := PosEx('/', Url, P + 3);
  if P = 0 then
    Exit;
  Base := Copy(Url, P, MaxInt);
  while (Base <> '') and (Base[Length(Base)] = '/') do
    SetLength(Base, Length(Base) - 1);
end;

function WithoutBase(const Address: string): string;
begin
  Result := Address;
  if (Base = '') or not Address.StartsWith(Base) then
    Exit;
  // /community and /community/x and /community?x, not /communityhall
  if Length(Address) = Length(Base) then
    Result := '/'
  else if Address[Length(Base) + 1] = '/' then
    Result := Copy(Address, Length(Base) + 1, MaxInt)
  else if Address[Length(Base) + 1] = '?' then
    Result := '/' + Copy(Address, Length(Base) + 1, MaxInt);
end;

function WithBase(const Address: string): string;
begin
  if (Base <> '') and (Address <> '') and (Address[1] = '/') and not Address.StartsWith('//') then
    Result := Base + Address
  else
    Result := Address;
end;

{ Base before the / that follows each Mark, unless that / starts //host. }
function Rebased(const Text: string; const Marks: array of string): string;
var
  Mark: string;
  At, From: integer;
begin
  Result := Text;
  if Base = '' then
    Exit;
  for Mark in Marks do
  begin
    From := 1;
    repeat
      At := PosEx(Mark, Result, From);
      if At = 0 then
        Break;
      // At + Length(Mark) - 1 is the address's first /
      From := At + Length(Mark);
      if (From > Length(Result)) or (Result[From] <> '/') then
      begin
        Insert(Base, Result, From - 1);
        From := From + Length(Base);
      end;
    until False;
  end;
end;

function RebaseHtml(const Page: string): string;
begin
  Result := Rebased(Page, [' href="/', ' src="/', ' action="/', ' poster="/', ' data-href="/']);
end;

function RebaseJson(const Answer: string): string;
begin
  Result := Rebased(Answer, [' href=\"/', ' src=\"/', ' action=\"/', ' poster=\"/']);
end;

end.
