unit SiteMail;

{ SMTP over TLS (port 465), with credentials in [mail]. Without a host,
  SendMail returns failure; file= instead appends outgoing mail to a file
  without sending. See docs/CODE-MAP.md for configuration fields. }

{$mode objfpc}{$H+}

interface

uses
  ssockets;

{ Sends a plain text mail; False (and the reason in the log) when it did
  not go.  Headers: more header lines, each ending in CR LF. }
function SendMail(const ToAddress, Subject, Body: string; const Headers: string = ''): boolean;
function MailReady: boolean;
{ The mail server, connected: TLS made, its greeting read and the hello
  answered.  The caller frees it. }
function MailServer: TInetSocket;

implementation

uses
  Classes, SysUtils, base64, SiteDb, SiteUsers, SiteTls;

var
  FileLock: TRTLCriticalSection;

{ The file mail is added to in place of being sent, '' on a site that sends. }
function MailFile: string;
begin
  Result := Config.ReadString('mail', 'file', '');
end;

function MailReady: boolean;
begin
  Result := (Config.ReadString('mail', 'host', '') <> '') or (MailFile <> '');
end;

{ A header's words as mail carries them: as they are when plain ASCII, else
  in encoded words (RFC 2047), each short enough for its line. }
function HeaderWords(const Text: string): string;
const
  MOST = 42;  // bytes in one encoded word, which is 75 characters at most
var
  C: char;
  From, Upto: integer;
begin
  Result := Text;
  for C in Text do
    if Ord(C) > 126 then
      Result := '';
  if Result <> '' then
    Exit;
  From := 1;
  while From <= Length(Text) do
  begin
    Upto := From + MOST;
    if Upto > Length(Text) then
      Upto := Length(Text) + 1;
    // never inside a character of several bytes
    while (Upto <= Length(Text)) and ((Ord(Text[Upto]) and $C0) = $80) do
      Dec(Upto);
    if Result <> '' then
      Result := Result + #13#10' ';
    Result := Result + '=?UTF-8?B?' + EncodeStringBase64(Copy(Text, From, Upto - From)) + '?=';
    From := Upto;
  end;
end;

procedure AddToFile(const Message: string);
var
  Lines: string;
  Kept: TFileStream;
begin
  Lines := 'From exedra ' + FormatDateTime('ddd mmm dd hh:nn:ss yyyy', NowUTC) + #10 + StringReplace(Message, #13#10, #10, [rfReplaceAll]) + #10;
  EnterCriticalSection(FileLock);
  try
    if FileExists(MailFile) then
      Kept := TFileStream.Create(MailFile, fmOpenReadWrite)
    else
      Kept := TFileStream.Create(MailFile, fmCreate);
    try
      Kept.Seek(0, soEnd);
      Kept.WriteBuffer(Lines[1], Length(Lines));
    finally
      Kept.Free;
    end;
  finally
    LeaveCriticalSection(FileLock);
  end;
end;

{ The server's answer: its lines until the one with a space after the code. }
function Answer(Sock: TSocketStream): string;
var
  C: char;
  Line: string;
begin
  Result := '';
  repeat
    Line := '';
    repeat
      if Sock.Read(C, 1) <> 1 then
        raise Exception.Create('the mail server hung up');
      if C <> #13 then
        Line := Line + C;
    until C = #10;
    Result := Result + Line;
  until (Length(Line) < 4) or (Line[4] = ' ');
end;

procedure Expect(Sock: TSocketStream; const Command, Code: string);
var
  Data, Got: string;
begin
  if Command <> '' then
  begin
    Data := Command + #13#10;
    Sock.WriteBuffer(Data[1], Length(Data));
  end;
  Got := Answer(Sock);
  if not Got.StartsWith(Code) then
    raise Exception.Create(Trim(Got));
end;

{ The body with lines that start with a dot doubled (RFC 5321 4.5.2). }
function DotStuffed(const Body: string): string;
var
  Lines: TStringList;
  I: integer;
begin
  Lines := TStringList.Create;
  try
    Lines.Text := Body;
    for I := 0 to Lines.Count - 1 do
      if Lines[I].StartsWith('.') then
        Lines[I] := '.' + Lines[I];
    Lines.LineBreak := #13#10;
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

function MailServer: TInetSocket;
begin
  // As fphttpclient does: made, then connected, which starts the TLS.
  Result := TInetSocket.Create(Config.ReadString('mail', 'host', ''), Config.ReadInteger('mail', 'port', 465), TSiteTlsHandler.Create);
  try
    Result.ConnectTimeout := 10000;
    Result.Connect;
    Result.IOTimeout := 20000;
    Expect(Result, '', '220');
    Expect(Result, 'EHLO ' + Config.ReadString('irc', 'name', 'exedra'), '250');
  except
    Result.Free;
    raise;
  end;
end;

function SendMail(const ToAddress, Subject, Body: string; const Headers: string): boolean;
var
  Sock: TInetSocket;
  From, Name, Message: string;
begin
  Result := False;
  if not MailReady then
  begin
    Log('Mail to ' + ToAddress + ' not sent: no [mail] host in the config');
    Exit;
  end;
  From := Config.ReadString('mail', 'from', Config.ReadString('mail', 'user', ''));
  Name := Config.ReadString('mail', 'name', '');
  if Name = '' then
    Name := Setting('name', 'Exedra');
  Message := 'From: ' + HeaderWords(Name) + ' <' + From + '>'#13#10 + 'To: <' + ToAddress + '>'#13#10 + 'Subject: ' + HeaderWords(Subject) +
    #13#10 + 'Date: ' + FormatDateTime('ddd, dd mmm yyyy hh:nn:ss', NowUTC) + ' +0000'#13#10 + 'Message-ID: <' + RandomHex(12) + '@' +
    Copy(From, Pos('@', From) + 1, MaxInt) + '>'#13#10 + 'MIME-Version: 1.0'#13#10 + 'Content-Type: text/plain; charset=utf-8'#13#10 +
    'Content-Transfer-Encoding: 8bit'#13#10 + Headers + #13#10 + DotStuffed(Body);
  Sock := nil;
  try
    try
      if MailFile <> '' then
      begin
        AddToFile(Message);
        Exit(True);
      end;
      Sock := MailServer;
      Expect(Sock, 'AUTH LOGIN', '334');
      Expect(Sock, EncodeStringBase64(Config.ReadString('mail', 'user', '')), '334');
      Expect(Sock, EncodeStringBase64(Config.ReadString('mail', 'password', '')), '235');
      Expect(Sock, 'MAIL FROM:<' + From + '>', '250');
      Expect(Sock, 'RCPT TO:<' + ToAddress + '>', '25');
      Expect(Sock, 'DATA', '354');
      Expect(Sock, Message + '.', '250');
      Expect(Sock, 'QUIT', '221');
      Result := True;
    except
      on E: Exception do
        Log('Mail to ' + ToAddress + ' not sent: ' + E.Message);
    end;
  finally
    Sock.Free;
  end;
end;

initialization
  InitCriticalSection(FileLock);
end.
