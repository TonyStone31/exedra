unit SitePoll;

{ Use poll() for Unix server sockets because select() cannot read
  descriptors above 1023. OnGetSocketHandler installs it for HTTP and
  WebSocket waits. CGI and other systems keep FPC's handler. }

{$mode objfpc}{$H+}

interface

uses
  ssockets;

type
  TPollSocketHandler = class(TSocketHandler)
  public
    function Select(aCheck: TSocketStates; TimeOut: integer): TSocketStates; override;
  end;

  { OnGetSocketHandler wants a method. }
  TPollHandlers = class
    procedure GetHandler(Sender: TObject; const UseSSL: boolean; out AHandler: TSocketHandler);
  end;

var
  PollHandlers: TPollHandlers;

implementation

uses
  BaseUnix, UnixType, Sockets;

function TPollSocketHandler.Select(aCheck: TSocketStates; TimeOut: integer): TSocketStates;
var
  P: pollfd;
  Res: cint;
begin
  Result := [];
  P.fd := Socket.Handle;
  P.events := 0;
  if sosCanRead in aCheck then
    P.events := P.events or POLLIN;
  if sosCanWrite in aCheck then
    P.events := P.events or POLLOUT;
  if sosException in aCheck then
    P.events := P.events or POLLPRI;
  P.revents := 0;
  if TimeOut < 0 then
    TimeOut := -1;
  repeat
    Res := fpPoll(@P, 1, TimeOut);
  until (Res >= 0) or (fpgeterrno <> ESysEINTR);
  if Res < 0 then
  begin
    FLastError := SocketError;
    Exit;
  end;
  FLastError := 0;
  // A closed or failed socket counts as readable, as with select(): the
  // read that follows finds out and ends the connection.
  if (sosCanRead in aCheck) and (P.revents and (POLLIN or POLLHUP or POLLERR) <> 0) then
    Include(Result, sosCanRead);
  if (sosCanWrite in aCheck) and (P.revents and (POLLOUT or POLLERR) <> 0) then
    Include(Result, sosCanWrite);
  if (sosException in aCheck) and (P.revents and (POLLPRI or POLLNVAL) <> 0) then
    Include(Result, sosException);
end;

procedure TPollHandlers.GetHandler(Sender: TObject; const UseSSL: boolean; out AHandler: TSocketHandler);
begin
  // With TLS the server makes its own handler; here HAProxy does TLS.
  if UseSSL then
    AHandler := nil
  else
    AHandler := TPollSocketHandler.Create;
end;

initialization
  PollHandlers := TPollHandlers.Create;
end.
