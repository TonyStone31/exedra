unit SiteTls;

{ TlsLib4Pascal behind fcl-net's socket handler for outgoing sockets and
  HTTP clients. Verify the host and certificate chain against system trust,
  or only [tls] certs= when configured as a certificate file or folder. }

{$mode objfpc}{$H+}

interface

uses
  TlsLibFclNetTls;

type
  { The handler every TLS connection gets, made by hand or by fphttpclient. }
  TSiteTlsHandler = class(TTlsLibSocketHandler)
  public
    function Connect: boolean; override;
  end;

implementation

uses
  SysUtils, sslsockets, TlpITrustAnchorStore, TlpDefaultPkixProvider, TlpFileSystemTrust, SiteDb;

var
  RootsLock: TRTLCriticalSection;
  OwnRoots: ITrustAnchorStore;

{ The certificates Path names, read once: they do not change while the
  program runs. }
function RootsFrom(const Path: string): ITrustAnchorStore;
var
  Source: TFileSystemRootSource;
begin
  EnterCriticalSection(RootsLock);
  try
    if OwnRoots = nil then
    begin
      if DirectoryExists(Path) then
        Source := TFileSystemRootSource.Create(TDefaultPkixProvider.Shared, '', Path, nil, nil)
      else if FileExists(Path) then
        Source := TFileSystemRootSource.Create(TDefaultPkixProvider.Shared, Path, '', nil, nil)
      else
        raise Exception.Create('[tls] certs= names no folder or file: ' + Path);
      try
        OwnRoots := Source.Snapshot;
      finally
        Source.Free;
      end;
    end;
    Result := OwnRoots;
  finally
    LeaveCriticalSection(RootsLock);
  end;
end;

function TSiteTlsHandler.Connect: boolean;
var
  Own: string;
begin
  // fphttpclient switches the check off on every handler it is given
  TSSLSocketHandler(Self).VerifyPeerCert := True;
  Own := '';
  if Assigned(Config) then
    Own := Config.ReadString('tls', 'certs', '');
  if Own = '' then
    UseSystemTrust := True
  else
    CustomTrustStore := RootsFrom(Own);
  Result := inherited Connect;
end;

initialization
  InitCriticalSection(RootsLock);
  TSSLSocketHandler.SetDefaultHandlerClass(TSiteTlsHandler);

finalization
  DoneCriticalSection(RootsLock);
end.
