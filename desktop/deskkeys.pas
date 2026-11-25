unit DeskKeys;

{ The keys made from a member's name and password, and the locked private
  messages they open, exactly as the web page makes them (static/keys.js,
  docs/API.md).  The password itself never leaves this program, and the
  private key stays in memory. }

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

var
  { This member's private key (PKCS#8) once the password opened it; empty
    until then.  Kept in memory only. }
  MyKey: TBytes;

function CallbackState: string;
function ProviderCallbackAllowed(const Method, Path, Grant, Failed, State, Expected: string): boolean;
procedure WipeBytes(var Bytes: TBytes);
procedure WipeText(var Text: string);

{ The sign-in secret (64 hex digits) and the key that opens the member's
  wrapped private key.  Takes about a second on purpose. }
procedure PasswordKeys(const Name, Password: string; out Auth: string; out Wrap: TBytes);
{ The private key (PKCS#8) from the server's wrapped copy; raises when the
  password was not this account's. }
function Unwrap(const Wrapped: string; const Wrap: TBytes): TBytes;
{ The key two members share: this member's private key and the other's
  public key (SPKI, base64). }
function PairKey(const PrivateKey: TBytes; const TheirKey: string): TBytes;
{ A private message sealed from one to the other; Iv and Data are base64. }
procedure Seal(const Key: TBytes; const FromName, ToName, Plain: string; out Iv, Data: string);
function Open(const Key: TBytes; const FromName, ToName, Iv, Data: string): string;
{ A file of a locked conversation: its bytes sealed, and the IV, base64. }
function SealBytes(const Key, Plain: TBytes; out Iv: string): TBytes;
function OpenBytes(const Key, Sealed: TBytes; const Iv: string): TBytes;

implementation

uses
  base64, HlpHashFactory, HlpConverters, ClpOSRandomProvider, ClpIKeyParameter, ClpKeyParameter,
  ClpIAeadParameters, ClpAeadParameters, ClpIBufferedCipher, ClpCipherUtilities, ClpIBasicAgreement,
  ClpAgreementUtilities, ClpPrivateKeyFactory, ClpPublicKeyFactory,
  ClpBigIntegerUtilities;

function CallbackState: string;
var
  Bytes: TBytes;
begin
  SetLength(Bytes, 32);
  TOSRandomProvider.Instance.GetBytes(Bytes);
  Result := LowerCase(TConverters.ConvertBytesToHexString(Bytes, False));
end;

function ProviderCallbackAllowed(const Method, Path, Grant, Failed, State, Expected: string): boolean;
begin
  Result := (Method = 'GET') and (Path = '/') and (Expected <> '') and (State = Expected) and (((Grant <> '') and (Failed = '')) or
    ((Grant = '') and ((Failed = '1') or (Failed = 'closed'))));
end;

procedure WipeBytes(var Bytes: TBytes);
begin
  if Length(Bytes) > 0 then FillChar(Bytes[0], Length(Bytes), 0);
  Bytes := nil;
end;

procedure WipeText(var Text: string);
begin
  UniqueString(Text);
  if Length(Text) > 0 then FillChar(Text[1], Length(Text), 0);
  Text := '';
end;

function FromBytes(const B: TBytes): rawbytestring;
begin
  Result := '';
  if B <> nil then
    SetString(Result, pansichar(@B[0]), Length(B));
end;

function Base64Of(const B: TBytes): string;
begin
  Result := EncodeStringBase64(FromBytes(B));
end;

function BytesOf64(const S: string): TBytes;
begin
  Result := BytesOf(DecodeStringBase64(S));
end;

{ HKDF-SHA256 with a zero salt and one block of output (RFC 5869). }
function Hkdf(const Master: TBytes; const Info: string): TBytes;
var
  Prk: TBytes;
begin
  SetLength(Prk, 32);
  FillChar(Prk[0], 32, 0);
  Prk := THashFactory.THMAC.CreateHMAC(THashFactory.TCrypto.CreateSHA2_256(), Prk).ComputeBytes(Master).GetBytes;
  Result := THashFactory.THMAC.CreateHMAC(THashFactory.TCrypto.CreateSHA2_256(), Prk).ComputeBytes(Concat(TEncoding.UTF8.GetBytes(unicodestring(Info)), [byte(1)])).GetBytes;
  WipeBytes(Prk);
end;

procedure PasswordKeys(const Name, Password: string; out Auth: string; out Wrap: TBytes);
var
  Master, PasswordBytes, AuthBytes: TBytes;
begin
  PasswordBytes := TEncoding.UTF8.GetBytes(unicodestring(Password));
  try
    // The salt says beginend, the server's first name; every password was made with it.
    Master := TKDF.TPBKDF2_HMAC.CreatePBKDF2_HMAC(THashFactory.TCrypto.CreateSHA2_256(), PasswordBytes, TEncoding.UTF8.GetBytes(unicodestring('beginend:' + LowerCase(Name))),
      600000).GetBytes(32);
    AuthBytes := Hkdf(Master, 'sign in');
    Auth := LowerCase(TConverters.ConvertBytesToHexString(AuthBytes, False));
    Wrap := Hkdf(Master, 'wrap');
  finally
    WipeBytes(PasswordBytes);
    WipeBytes(AuthBytes);
    WipeBytes(Master);
  end;
end;

{ AES-GCM as the browser does it: a 128-bit tag after the text. }
function Gcm(Encrypt: boolean; const Key, Nonce, Extra, Input: TBytes): TBytes;
var
  Cipher: IBufferedCipher;
begin
  Cipher := TCipherUtilities.GetCipher('AES/GCM/NoPadding');
  Cipher.Init(Encrypt, TAeadParameters.Create(TKeyParameter.Create(Key) as IKeyParameter, 128, Nonce, Extra) as IAeadParameters);
  Result := Cipher.DoFinal(Input);
end;

function NewNonce: TBytes;
begin
  Result := nil;
  SetLength(Result, 12);
  TOSRandomProvider.Instance.GetBytes(Result);
end;

function Unwrap(const Wrapped: string; const Wrap: TBytes): TBytes;
var
  Dot: integer;
begin
  Result := nil;
  Dot := Pos('.', Wrapped);
  try
    Result := Gcm(False, Wrap, BytesOf64(Copy(Wrapped, 1, Dot - 1)), nil, BytesOf64(Copy(Wrapped, Dot + 1, MaxInt)));
  except
    raise Exception.Create('That is not the password of this account.');
  end;
end;

function PairKey(const PrivateKey: TBytes; const TheirKey: string): TBytes;
var
  Agreement: IBasicAgreement;
begin
  Agreement := TAgreementUtilities.GetBasicAgreement('ECDH');
  Agreement.Init(TPrivateKeyFactory.CreateKey(PrivateKey));
  // The shared secret is the point's x, 32 bytes, as WebCrypto's deriveBits gives it.
  Result := Hkdf(TBigIntegerUtilities.AsUnsignedByteArray(32, Agreement.CalculateAgreement(TPublicKeyFactory.CreateKey(BytesOf64(TheirKey)))), 'beginend private message');
end;

{ Who sent it to whom is sealed in with it, so the server cannot turn a
  message around. }
function Between(const FromName, ToName: string): TBytes;
begin
  Result := TEncoding.UTF8.GetBytes(unicodestring(LowerCase(FromName) + '>' + LowerCase(ToName)));
end;

procedure Seal(const Key: TBytes; const FromName, ToName, Plain: string; out Iv, Data: string);
var
  Nonce: TBytes;
begin
  Nonce := NewNonce;
  Iv := Base64Of(Nonce);
  Data := Base64Of(Gcm(True, Key, Nonce, Between(FromName, ToName), TEncoding.UTF8.GetBytes(unicodestring(Plain))));
end;

function Open(const Key: TBytes; const FromName, ToName, Iv, Data: string): string;
begin
  Result := UTF8Encode(TEncoding.UTF8.GetString(Gcm(False, Key, BytesOf64(Iv), Between(FromName, ToName), BytesOf64(Data))));
end;

function SealBytes(const Key, Plain: TBytes; out Iv: string): TBytes;
var
  Nonce: TBytes;
begin
  Nonce := NewNonce;
  Iv := Base64Of(Nonce);
  Result := Gcm(True, Key, Nonce, nil, Plain);
end;

function OpenBytes(const Key, Sealed: TBytes; const Iv: string): TBytes;
begin
  Result := Gcm(False, Key, BytesOf64(Iv), nil, Sealed);
end;

end.
