unit WikiEmoji;

{ Wiki emoji set and text processing. Pages store Unicode; completed
  :keywords: become emoji and the renderer uses site pictures with emoji alt
  text. Code and emoji outside the set remain untouched. WikiEmojiSite
  stores the set and serves administration. }

{$mode objfpc}{$H+}

interface

type
  TEmoji = record
    Chars: string;       // the emoji as UTF-8, with its U+FE0F when it has one
    Name, Group: string;
    Src: string;         // its picture's address; '' leaves it to the reader's font
    Keywords: array of string;
  end;
  TEmojiList = array of TEmoji;

{ The set in use from now on; safe while other threads read it. }
procedure SetEmojiSet(const List: TEmojiList);
function EmojiSet: TEmojiList;
{ Each :keyword: of the set, outside code, links and HTML, as its emoji. }
function ExpandEmojiKeywords(const Text: string): string;
{ Each emoji of the set that has a picture, outside code and tags, as that
  picture.  Html is the renderer's output. }
function DrawEmoji(const Html: string): string;
{ The emoji's code points in hex, joined by '-', without U+FE0F: 2705,
  1f44d.  The default picture is this name with .svg. }
function EmojiCodeName(const Chars: string): string;
{ What a keyword may be made of: a to z, 0 to 9, + - and _, 1 to 30 long. }
function ValidEmojiKeyword(const word: string): boolean;

implementation

uses SysUtils, StrUtils;

const
  VS16 = #$EF#$B8#$8F;  // U+FE0F, emoji presentation
  VS15 = #$EF#$B8#$8E;  // U+FE0E, text presentation: left as text
  ZWJ = #$E2#$80#$8D;   // joins emoji into one (a family, a flag): left as text
  KEYCAP = #$E2#$83#$A3;

var
  Lock: TRTLCriticalSection;
  Current: TEmojiList;

procedure SetEmojiSet(const List: TEmojiList);
begin
  EnterCriticalSection(Lock);
  try
    Current := Copy(List);
  finally
    LeaveCriticalSection(Lock);
  end;
end;

function EmojiSet: TEmojiList;
begin
  EnterCriticalSection(Lock);
  try
    Result := Current;
  finally
    LeaveCriticalSection(Lock);
  end;
end;

function Bare(const Chars: string): string;
begin
  Result := StringReplace(Chars, VS16, '', [rfReplaceAll]);
end;

function EmojiCodeName(const Chars: string): string;
var
  U: unicodestring;
  I, CP: integer;
begin
  Result := '';
  U := UTF8Decode(Bare(Chars));
  I := 1;
  while I <= Length(U) do
  begin
    CP := Ord(U[I]);
    if (CP >= $D800) and (CP <= $DBFF) and (I < Length(U)) then
    begin
      CP := $10000 + ((CP - $D800) shl 10) + (Ord(U[I + 1]) - $DC00);
      Inc(I);
    end;
    if Result <> '' then
      Result := Result + '-';
    Result := Result + LowerCase(IntToHex(CP, 1));
    Inc(I);
  end;
end;

function ValidEmojiKeyword(const word: string): boolean;
var
  C: char;
begin
  Result := (Length(word) >= 1) and (Length(word) <= 30);
  if Result then
    for C in word do
      if not (C in ['a'..'z', '0'..'9', '+', '-', '_']) then
        Exit(False);
end;

function KeywordChars(const List: TEmojiList; const word: string): string;
var
  I, K: integer;
begin
  for I := 0 to High(List) do
    for K := 0 to High(List[I].Keywords) do
      if List[I].Keywords[K] = word then
        Exit(List[I].Chars);
  Result := '';
end;

function ExpandEmojiKeywords(const Text: string): string;
var
  List: TEmojiList;
  Lines: array of string;
  Fence: string;
  Line, Trimmed, word, Chars: string;
  N, I, J, Run: integer;
  Out_: TAnsiStringBuilder;

  function FenceOf(const S: string): string;
  var
    P: integer;
  begin
    Result := '';
    if (S = '') or not (S[1] in ['`', '~']) then
      Exit;
    P := 1;
    while (P <= Length(S)) and (S[P] = S[1]) do
      Inc(P);
    if P > 3 then
      Result := Copy(S, 1, P - 1);
  end;

begin
  List := EmojiSet;
  if (Length(List) = 0) or (Pos(':', Text) = 0) then
    Exit(Text);
  Lines := SplitString(Text, #10);
  Out_ := TAnsiStringBuilder.Create(Length(Text));
  try
    Fence := '';
    for N := 0 to High(Lines) do
    begin
      if N > 0 then
        Out_.Append(#10);
      Line := Lines[N];
      Trimmed := TrimLeft(Line);
      // fenced code: copied as it is, the fence lines too
      if Fence <> '' then
      begin
        if StartsStr(Fence, Trimmed) and (Trim(Copy(Trimmed, Length(Fence) + 1, MaxInt)) = '') then
          Fence := '';
        Out_.Append(Line);
        Continue;
      end;
      if (Length(Line) - Length(Trimmed) <= 3) and (FenceOf(Trimmed) <> '') then
      begin
        Fence := FenceOf(Trimmed);
        Out_.Append(Line);
        Continue;
      end;
      // an indented code block
      if StartsStr('    ', Line) or StartsStr(#9, Line) or (Pos(':', Line) = 0) then
      begin
        Out_.Append(Line);
        Continue;
      end;
      I := 1;
      while I <= Length(Line) do
      begin
        case Line[I] of
          '`':
          begin
            // a code span: the same run of backticks closes it
            Run := 0;
            while (I + Run <= Length(Line)) and (Line[I + Run] = '`') do
              Inc(Run);
            J := PosEx(DupeString('`', Run), Line, I + Run);
            if J = 0 then
              J := I + Run
            else
              J := J + Run;
            Out_.Append(Copy(Line, I, J - I));
            I := J;
            Continue;
          end;
          '<':
          begin
            // an autolink or an HTML tag, to its end on this line
            J := PosEx('>', Line, I + 1);
            if (J > 0) and (I < Length(Line)) and (Line[I + 1] in ['a'..'z', 'A'..'Z', '/', '!']) then
            begin
              Out_.Append(Copy(Line, I, J + 1 - I));
              I := J + 1;
              Continue;
            end;
          end;
          '(':
            if (I > 1) and (Line[I - 1] = ']') then
            begin
              // a link's address
              J := PosEx(')', Line, I + 1);
              if J > 0 then
              begin
                Out_.Append(Copy(Line, I, J + 1 - I));
                I := J + 1;
                Continue;
              end;
            end;
          '[':
            if (I < Length(Line)) and (Line[I + 1] = '[') then
            begin
              J := PosEx(']]', Line, I + 2);
              if J > 0 then
              begin
                Out_.Append(Copy(Line, I, J + 2 - I));
                I := J + 2;
                Continue;
              end;
            end;
          ':':
            if (I = 1) or not (Line[I - 1] in ['a'..'z', 'A'..'Z', '0'..'9', ':', '/', '\', '_']) then
            begin
              J := I + 1;
              while (J <= Length(Line)) and (Line[J] in ['a'..'z', 'A'..'Z', '0'..'9', '+', '-', '_']) do
                Inc(J);
              if (J <= Length(Line)) and (Line[J] = ':') and (J - I - 1 >= 1) and (J - I - 1 <= 30) and ((J = Length(Line)) or not
                (Line[J + 1] in ['a'..'z', 'A'..'Z', '0'..'9', ':'])) then
              begin
                word := LowerCase(Copy(Line, I + 1, J - I - 1));
                Chars := KeywordChars(List, word);
                if Chars <> '' then
                begin
                  Out_.Append(Chars);
                  I := J + 1;
                  Continue;
                end;
              end;
            end;
        end;
        Out_.Append(Line[I]);
        Inc(I);
      end;
    end;
    Result := Out_.ToString;
  finally
    Out_.Free;
  end;
end;

function Attr(const S: string): string;
begin
  Result := StringReplace(S, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
end;

function DrawEmoji(const Html: string): string;
var
  List: TEmojiList;
  Seqs, Tags: array of string;
  Order: array of integer;
  I, J, K, P, Best, Len, Tmp: integer;
  Seq, Lower, CloseTag: string;
  Out_: TAnsiStringBuilder;
  Leads: set of char;
  Any: boolean;

  function At(const S: string; Where: integer): boolean;
  begin
    Result := (S <> '') and (Copy(Html, Where, Length(S)) = S);
  end;

begin
  Seqs := nil;
  Tags := nil;
  Order := nil;
  List := EmojiSet;
  if Length(List) = 0 then
    Exit(Html);
  // the drawn ones, longest first, so a longer emoji is not taken for a shorter one
  SetLength(Seqs, 0);
  SetLength(Tags, 0);
  for I := 0 to High(List) do
    if (List[I].Src <> '') and (Bare(List[I].Chars) <> '') then
    begin
      SetLength(Seqs, Length(Seqs) + 1);
      SetLength(Tags, Length(Tags) + 1);
      Seqs[High(Seqs)] := Bare(List[I].Chars);
      Tags[High(Tags)] := '<img class="emo" src="' + Attr(List[I].Src) + '" alt="' + Attr(List[I].Chars) + '" title="' + Attr(List[I].Name);
      if Length(List[I].Keywords) > 0 then
        Tags[High(Tags)] := Tags[High(Tags)] + ' :' + Attr(List[I].Keywords[0]) + ':';
      Tags[High(Tags)] := Tags[High(Tags)] + '" draggable="false">';
    end;
  if Length(Seqs) = 0 then
    Exit(Html);
  // only a byte that starts an emoji of the set sends us looking
  Leads := [];
  for I := 0 to High(Seqs) do
    Include(Leads, Seqs[I][1]);
  Any := False;
  for I := 1 to Length(Html) do
    if Html[I] in Leads then
    begin
      Any := True;
      Break;
    end;
  if not Any then
    Exit(Html);
  SetLength(Order, Length(Seqs));
  for I := 0 to High(Order) do
    Order[I] := I;
  for I := 1 to High(Order) do
  begin
    Tmp := Order[I];
    J := I - 1;
    while (J >= 0) and (Length(Seqs[Order[J]]) < Length(Seqs[Tmp])) do
    begin
      Order[J + 1] := Order[J];
      Dec(J);
    end;
    Order[J + 1] := Tmp;
  end;
  Out_ := TAnsiStringBuilder.Create(Length(Html) + 256);
  try
    P := 1;
    while P <= Length(Html) do
    begin
      if Html[P] = '<' then
      begin
        // code and preformatted text keep their emoji as written
        Lower := LowerCase(Copy(Html, P, 6));
        CloseTag := '';
        if StartsStr('<code', Lower) and (Length(Lower) >= 6) and (Lower[6] in ['>', ' ']) then
          CloseTag := '</code>'
        else if StartsStr('<pre', Lower) and (Lower[5] in ['>', ' ']) then
          CloseTag := '</pre>';
        if CloseTag <> '' then
          K := PosEx(CloseTag, Html, P)
        else
          K := 0;
        if K > 0 then
          K := K + Length(CloseTag) - 1
        else
        begin
          K := PosEx('>', Html, P);
          if K = 0 then
            K := Length(Html);
        end;
        Out_.Append(Copy(Html, P, K + 1 - P));
        P := K + 1;
        Continue;
      end;
      if Html[P] in Leads then
      begin
        Best := -1;
        for I := 0 to High(Order) do
          if At(Seqs[Order[I]], P) then
          begin
            Best := Order[I];
            Break;
          end;
        if Best >= 0 then
        begin
          Seq := Seqs[Best];
          Len := Length(Seq);
          // part of a joined emoji, a skin tone, a keycap or asked for as text: left alone
          if ((P > 3) and (Copy(Html, P - 3, 3) = ZWJ)) or At(ZWJ, P + Len) or At(VS15, P + Len) or At(KEYCAP, P + Len) or
            ((P + Len + 3 <= Length(Html)) and (Copy(Html, P + Len, 3) = #$F0#$9F#$8F) and (Html[P + Len + 3] in [#$BB..#$BF])) or
            (At(VS16, P + Len) and At(ZWJ, P + Len + 3)) then
          begin
            Out_.Append(Copy(Html, P, Len));
            P := P + Len;
            Continue;
          end;
          if At(VS16, P + Len) then
            Len := Len + 3;
          Out_.Append(Tags[Best]);
          P := P + Len;
          Continue;
        end;
      end;
      Out_.Append(Html[P]);
      Inc(P);
    end;
    Result := Out_.ToString;
  finally
    Out_.Free;
  end;
end;

initialization
  InitCriticalSection(Lock);

finalization
  DoneCriticalSection(Lock);
end.
