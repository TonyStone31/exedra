unit DeskAccountKeys;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DeskNet;

{ P-256, SPKI public key, and PKCS#8 private key wrapped as keys.js does. }
procedure NewAccountKeys(const Wrap: TBytes; out PrivateKey: TBytes; out Pub, Wrapped: string);

type
  TAccountKeySetup = class;
  TAccountKeysDone = procedure(Setup: TAccountKeySetup) of object;

  TAccountKeySetup = class(TComponent)
  private
    Target: TApiTarget;
    MemberName, Password: string;
    Done: TAccountKeysDone;
    PrivateKey: TBytes;
    procedure SaltDone(Job: TApiJob);
    procedure KeysDone(Job: TApiJob);
    procedure Finish(const Words: string);
  public
    Error: string;
    destructor Destroy; override;
    procedure Start(const ATarget: TApiTarget; const AName, APassword: string; ADone: TAccountKeysDone);
    function TakeKey: TBytes;
  end;

implementation

uses
  base64, fpjson, DeskKeys, ClpGeneratorUtilities, ClpECParameters,
  ClpIECParameters, ClpECNamedCurveTable, ClpSecureRandom, ClpISecureRandom,
  ClpIAsymmetricCipherKeyPair, ClpIAsymmetricCipherKeyPairGenerator,
  ClpPrivateKeyInfoFactory, ClpSubjectPublicKeyInfoFactory;

function Base64Of(const Bytes: TBytes): string;
var
  Raw: rawbytestring;
begin
  SetString(Raw, pansichar(@Bytes[0]), Length(Bytes));
  Result := EncodeStringBase64(Raw);
end;

procedure NewAccountKeys(const Wrap: TBytes; out PrivateKey: TBytes; out Pub, Wrapped: string);
var
  Gen: IAsymmetricCipherKeyPairGenerator;
  Pair: IAsymmetricCipherKeyPair;
  Iv: string;
  Sealed: TBytes;
begin
  Gen := TGeneratorUtilities.GetKeyPairGenerator('ECDH');
  Gen.Init(TECKeyGenerationParameters.Create(TECNamedCurveTable.GetOid('secp256r1'), TSecureRandom.Create() as ISecureRandom) as IECKeyGenerationParameters);
  Pair := Gen.GenerateKeyPair();
  PrivateKey := TPrivateKeyInfoFactory.CreatePrivateKeyInfo(Pair.Private).GetDerEncoded;
  Pub := Base64Of(TSubjectPublicKeyInfoFactory.CreateSubjectPublicKeyInfo(Pair.Public).GetDerEncoded);
  // SealBytes uses a random 12-byte IV, no additional data, and a 128-bit tag.
  Sealed := SealBytes(Wrap, PrivateKey, Iv);
  Wrapped := Iv + '.' + Base64Of(Sealed);
end;

destructor TAccountKeySetup.Destroy;
begin
  ApiCancelReceiver(Self);
  WipeText(Password);
  WipeBytes(PrivateKey);
  inherited Destroy;
end;

procedure TAccountKeySetup.Start(const ATarget: TApiTarget; const AName, APassword: string; ADone: TAccountKeysDone);
begin
  Target := ATarget;
  MemberName := AName;
  Password := APassword;
  Done := ADone;
  ApiGetTargetAsync(Target, '/api/auth-name?' + Query(['name', MemberName]), @SaltDone);
end;

procedure TAccountKeySetup.Finish(const Words: string);
begin
  Error := Words;
  WipeText(Password);
  if Error <> '' then WipeBytes(PrivateKey);
  if Assigned(Done) then Done(Self);
end;

function TAccountKeySetup.TakeKey: TBytes;
begin
  Result := PrivateKey;
  PrivateKey := nil;
end;

procedure TAccountKeySetup.SaltDone(Job: TApiJob);
var
  Auth, Pub, Wrapped: string;
  Wrap: TBytes;
  Answer: TJSONObject;
begin
  try
    try
      if Length(UTF8Decode(Password)) < 8 then
        raise Exception.Create('A password needs 8 characters or more.');
      Answer := Job.ObjectJSON;
      try
        PasswordKeys(Answer.Get('name', MemberName), Password, Auth, Wrap);
      finally
        Answer.Free;
      end;
      NewAccountKeys(Wrap, PrivateKey, Pub, Wrapped);
      ApiPostTargetAsync(Target, '/api/keys', ['name', MemberName, 'auth', Auth, 'pub', Pub, 'wrapped', Wrapped], @KeysDone);
    except
      on E: Exception do Finish(E.Message);
    end;
  finally
    WipeText(Password);
    WipeText(Auth);
    WipeBytes(Wrap);
  end;
end;

procedure TAccountKeySetup.KeysDone(Job: TApiJob);
begin
  Finish(Job.Error);
end;

end.
