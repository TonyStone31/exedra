program exedra;

{ Community server with optional modules, built as a server or with -dCGI.
  The config is exedra.ini beside the program or the command-line path.
  Leave a module out of uses to build without it; WikiChat needs both wiki
  and chat. See docs/CODE-MAP.md for the units and command-line options. }

{$mode objfpc}{$H+}

uses
  {$ifdef unix} {$ifndef CGI} cthreads, {$endif} cwstring, {$endif} ChatPart,
  Wiki,
  WikiChat,
  Forum,
  Catalog,
  SiteServer;

begin
  RunServer;
end.
