unit KeysPage;

{ Account keys, encrypted messages and peer-to-peer files. The password
  stays here: one derived key signs in, another wraps the private key. ECDH
  gives two members their message key; the server stores sealed text and
  files. Beam sends files over WebRTC; the server relays connection offers
  only. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web, weborworker;

type
  TJoinFailed = reference to procedure(Err: JSValue);
  TJoined = reference to procedure;
  TBeamProgress = reference to procedure(Sent, Total, State: JSValue);

function Ready: boolean;
function Post(const Url: string; Fields: JSValue): string; async;
procedure Join(Name: JSValue; const Password: string; Email: JSValue); async;
function JoinFrom(Form: TJSHTMLElement; Failed: TJoinFailed): boolean; async;
procedure SignOut; async;
procedure BindJoinForms(After: TJoined);
function MyKey: JSValue; async;
procedure SetupKeys(Name: JSValue; const Password: string); async;
procedure Unlock(Name: JSValue; const Password: string; Wrapped: JSValue); async;
procedure SetNewPassword(Token, Name: JSValue; const Password: string); async;
procedure ChangePassword(Name: JSValue; const Current, Password: string; Wrapped: JSValue); async;
function PasswordProof(Name: JSValue; const Password: string): string; async;
function Seal(const Other: string; Payload: JSValue): TJSObject; async;
function OpenSealed(const Other: string; Message: TJSObject): JSValue; async;
function SealFile(const Other: string; AFile: TJSBlob; Expire: JSValue): TJSObject; async;
function OpenFile(const Other: string; Meta: TJSObject): TJSBlob; async;
function Partner(const Other: string): TJSObject; async;
procedure Trust(const Other: string); async;
function BeamSend(const Other: string; AFile: TJSBlob; Progress: TBeamProgress): JSValue; async;
function BeamReceive(Token: JSValue; Progress: TBeamProgress): JSValue; async;
function Smaller(AFile: TJSBlob): JSValue; async;

implementation

uses PageKit, PageGlobals;

type
  THandler = reference to procedure(E: TJSObject);
  // The key store as the browser has it: Web's handlers answer false, which cancels an event.
  TStoreRequest = class external name 'Object'(TJSObject)
    result: JSValue;
    error: JSValue;
    onupgradeneeded, onerror, onsuccess: THandler;
  end;
  TStore = class external name 'Object'(TJSObject)
    function put(Value: JSValue; const Key: string): TStoreRequest;
    function get(const Key: string): TStoreRequest;
    function delete(const Key: string): TStoreRequest;
  end;
  TStoreTransaction = class external name 'Object'(TJSObject)
    function objectStore(const Name: string): TStore;
  end;
  // Web's transaction takes a list of names only; one name is given here.
  TStoreDatabase = class external name 'Object'(TJSObject)
    function createObjectStore(const Name: string): TStore;
    function transaction(const Name, Mode: string): TStoreTransaction;
  end;
  TStoreFactory = class external name 'Object'(TJSObject)
    function open(const Name: string; Version: NativeInt): TStoreRequest;
  end;
  TStoreWork = reference to function(S: TStore): TStoreRequest;

  TPasswordKeys = class external name 'Object'(TJSObject)
    auth: string;
    wrap: TJSCryptoKey;
  end;
  TPair = class external name 'Object'(TJSObject)
    pub, me, other: JSValue;
    key: TJSCryptoKey;
  end;
  TFailure = class external name 'Error'(TJSError)
    status: NativeInt;
    needEmail: boolean;
  end;
  // Web declares only the string URLSearchParams constructor.
  TFields = class external name 'URLSearchParams'(TJSObject)
    constructor new(Data: JSValue);
  end;
  TFormFields = class external name 'FormData'(TJSFormData)
    procedure append(const Name: string; Value: JSValue); overload;
  end;
  TNumber = class external name 'Number'(TJSObject)
    function toString(Radix: NativeInt): string; overload;
  end;
  TNewFile = class external name 'File'(TJSBlob)
    constructor new(Parts: TJSArray; Name: JSValue; Options: TJSObject);
  end;
  TWorkers = class external name 'Object'(TJSObject)
    function getRegistration(const Scope: string): TJSPromise;
  end;
  TPushManager = class external name 'Object'(TJSObject)
    function getSubscription: TJSPromise;
  end;
  TPushSubscription = class external name 'Object'(TJSObject)
    function unsubscribe: TJSPromise;
  end;
  TPaint = class external name 'Object'(TJSObject)
    procedure drawImage(Picture: JSValue; X, Y, W, H: double);
  end;
  TCanvas = class external name 'Object'(TJSObject)
    procedure toBlob(Done: TJSPromiseResolver; const Kind: string; Quality: double);
  end;
  // The beam's connection: the WebRTC unit is not part of the shared runtime.
  TChannel = class external name 'Object'(TJSObject)
    binaryType: string;
    bufferedAmount: NativeInt;
    bufferedAmountLowThreshold: NativeInt;
    onopen, onmessage, onclose: THandler;
    onbufferedamountlow: TJSPromiseResolver;
    procedure send(Data: JSValue);
  end;
  TPeer = class external name 'RTCPeerConnection'(TJSObject)
    iceGatheringState: string;
    localDescription: JSValue;
    ondatachannel: THandler;
    constructor new(Options: TJSObject);
    function createDataChannel(const Name: string; Options: TJSObject): TChannel;
    function createOffer: TJSPromise;
    function createAnswer: TJSPromise;
    function setLocalDescription(Description: JSValue): TJSPromise;
    function setRemoteDescription(Description: JSValue): TJSPromise;
    procedure addEventListener(const Name: string; Handler: THandler);
    procedure close;
  end;
  TBeamHead = class external name 'Object'(TJSObject)
    name: JSValue;
    kind: JSValue; external name 'type';
    size: NativeInt;
  end;

const
  Chunk = 64 * 1024;

var
  Enc: TJSTextEncoder;
  Dec: TJSTextDecoder;
  PairKeys: TJSObject;
  KeyStores: TStoreFactory; external name 'indexedDB';

function Atob(S: JSValue): string; external name 'atob';
function Btoa(const S: string): string; external name 'btoa';
function CharsOf(This: JSValue; Codes: TJSUint8Array): string; external name 'String.fromCharCode.apply';
function EncodeUri(Value: JSValue): string; external name 'encodeURIComponent';
function ParseJson(Text: JSValue): JSValue; external name 'JSON.parse';
function ToJson(Value: JSValue): string; external name 'JSON.stringify';
function ListOf(Value: JSValue): TJSArray; external name 'Array.of';
function Fetch(const Url: string): TJSPromise; external name 'fetch'; overload;
function Fetch(const Url: string; Options: TJSObject): TJSPromise; external name 'fetch'; overload;
function CreateImageBitmap(Source: JSValue; Options: TJSObject): TJSPromise; external name 'createImageBitmap';
procedure Alert(Text: JSValue); external name 'alert';
function Max(A, B: double): double; external name 'Math.max';
function Min(A, B: double): double; external name 'Math.min';
function RoundOf(A: double): NativeInt; external name 'Math.round';
// Strict equality for two values of any kind.
function Same(A, B: JSValue): boolean; external name 'Object.is';
// Whether an object has a property, its own or inherited.
function Has(Target: JSValue; const Key: string): boolean; external name 'Reflect.has';

function B64(B: JSValue): string;
var
  Bytes: TJSUint8Array;
  S: string;
  I: NativeInt;
begin
  Bytes := TJSUint8Array.new(TJSObject(B));
  S := '';
  I := 0;
  while I < Bytes.length do
  begin
    S := S + CharsOf(nil, Bytes.subarray(I, I + 32768));
    I := I + 32768;
  end;
  Result := Btoa(S);
end;

function Unb64(S: JSValue): TJSUint8Array;
begin
  Result := TJSUint8Array.from(Atob(S), function(C: JSValue; Index: NativeInt; All: TJSTypedArray): JSValue
    begin
      Result := TJSString(C).charCodeAt(0);
    end);
end;

function Hex(B: JSValue): string;
begin
  Result := TJSArray.from(TJSUint8Array.new(TJSObject(B)), function(X: JSValue): JSValue
    begin
      Result := TJSString(TNumber(X).toString(16)).padStart(2, '0');
    end).join('');
end;

function Lower(S: JSValue): string;
begin
  Result := TJSString(S).toLowerCase;
end;

function Ready: boolean;
begin
  Result := Truthy(TJSObject(window)['crypto']) and Truthy(TJSObject(Crypto)['subtle']);
end;

function Post(const Url: string; Fields: JSValue): string; async;
var
  Body: JSValue;
  Answer: TJSResponse;
  Text: string;
  E: TJSError;
begin
  if jsInstanceOf(Fields, TJSFormData) then Body := Fields
  else Body := TFields.new(Fields);
  Answer := await(TJSResponse, Fetch(Url, new(['method', 'POST', 'body', Body])));
  Text := await(string, Answer.text);
  if not Answer.ok then
  begin
    E := TJSError.new(Text);
    TFailure(E).status := Answer.status;
    raise E;
  end;
  Result := Text;
end;

function KeysFrom(Name: JSValue; const Password: string): TPasswordKeys; async;
var
  Base, Hk, Wrap: TJSCryptoKey;
  Master, Bits: TJSArrayBuffer;

  function Info(const S: string): TJSObject;
  begin
    Result := new(['name', 'HKDF', 'hash', 'SHA-256', 'salt', TJSUint8Array.new(32), 'info', Enc.encode(S)]);
  end;

begin
  Base := await(Crypto.subtle.importKey('raw', Enc.encode(Password), 'PBKDF2', False, ['deriveBits']));
  // Keep this salt: changing it breaks every password.
  Master := await(Crypto.subtle.deriveBits(new(['name', 'PBKDF2', 'hash', 'SHA-256',
    'salt', Enc.encode('beginend:' + Lower(Name)), 'iterations', 600000]), Base, 256));
  Hk := await(Crypto.subtle.importKey('raw', Master, 'HKDF', False, ['deriveBits', 'deriveKey']));
  Bits := await(Crypto.subtle.deriveBits(Info('sign in'), Hk, 256));
  Wrap := await(Crypto.subtle.deriveKey(Info('wrap'), Hk, new(['name', 'AES-GCM', 'length', 256]), False,
    ['encrypt', 'decrypt']));
  Result := TPasswordKeys(new(['auth', Hex(Bits), 'wrap', Wrap]));
end;

function PasswordName(Name: JSValue): JSValue; async;
var
  Answer: TJSResponse;
begin
  Answer := await(TJSResponse, Fetch('/api/auth-name?name=' + EncodeUri(Name), new(['cache', 'no-store'])));
  if not Answer.ok then raise TJSError.new(await(string, Answer.text));
  Result := TJSObject(await(JSValue, Answer.json))['name'];
end;

// The private key stays in this browser, and cannot be read back out.
function KeyStore(const Mode: string; Work: TStoreWork): TJSPromise;
begin
  Result := TJSPromise.new(procedure(Done, Fail: TJSPromiseResolver)
    var
      Opening: TStoreRequest;
    begin
      // the first name again: members' keys are in there
      Opening := KeyStores.open('beginend', 1);
      Opening.onupgradeneeded := procedure(E: TJSObject)
        begin
          TStoreDatabase(Opening.result).createObjectStore('keys');
        end;
      Opening.onerror := procedure(E: TJSObject)
        begin
          Fail(Opening.error);
        end;
      Opening.onsuccess := procedure(E: TJSObject)
        var
          Request: TStoreRequest;
        begin
          Request := Work(TStoreDatabase(Opening.result).transaction('keys', Mode).objectStore('keys'));
          Request.onsuccess := procedure(E: TJSObject)
            begin
              Done(Request.result);
            end;
          Request.onerror := procedure(E: TJSObject)
            begin
              Fail(Request.error);
            end;
        end;
    end);
end;

procedure KeepPrivateKey(Pkcs8, Name: JSValue); async;
var
  Key: TJSCryptoKey;
begin
  Key := await(Crypto.subtle.importKey('pkcs8', TJSObject(Pkcs8), new(['name', 'ECDH', 'namedCurve', 'P-256']),
    False, ['deriveBits']));
  await(KeyStore('readwrite', function(S: TStore): TStoreRequest
    begin
      Result := S.put(new(['name', Name, 'key', Key]), 'me');
    end));
end;

function MyKey: JSValue; async;
begin
  try
    Result := await(JSValue, KeyStore('readonly', function(S: TStore): TStoreRequest
      begin
        Result := S.get('me');
      end));
  except
    Result := Null;
  end;
end;

// The private key as the server keeps it: encrypted with the password's key.
function WrapKey(Keys: TPasswordKeys; Pkcs8: JSValue): string; async;
var
  Iv: TJSTypedArray;
begin
  Iv := Crypto.getRandomValues(TJSUint8Array.new(12));
  Result := B64(Iv) + '.' + B64(await(Crypto.subtle.encrypt(new(['name', 'AES-GCM', 'iv', Iv]), Keys.wrap,
    TJSBufferSource(Pkcs8))));
end;

function UnwrapKey(Keys: TPasswordKeys; Wrapped: JSValue): TJSArrayBuffer; async;
var
  Parts: TJSStringDynArray;
begin
  Parts := TJSString(Wrapped).split('.');
  Result := await(Crypto.subtle.decrypt(new(['name', 'AES-GCM', 'iv', Unb64(Parts[0])]), Keys.wrap, Unb64(Parts[1])));
end;

// A new key pair, its private half wrapped with the password's key.
function NewAccountKeys(Name: JSValue; const Password: string; SaltName: JSValue): TJSObject; async;
var
  Keys: TPasswordKeys;
  Pair: TJSObject;
  Pkcs8: JSValue;
  Pub, Wrapped: string;
begin
  if not Truthy(SaltName) then SaltName := Name;
  Keys := await(KeysFrom(SaltName, Password));
  Pair := TJSObject(await(JSValue, Crypto.subtle.generateKey(new(['name', 'ECDH', 'namedCurve', 'P-256']), True,
    ['deriveBits'])));
  Pkcs8 := await(JSValue, Crypto.subtle.exportKey('pkcs8', TJSCryptoKey(Pair['privateKey'])));
  Pub := B64(await(JSValue, Crypto.subtle.exportKey('spki', TJSCryptoKey(Pair['publicKey']))));
  Wrapped := await(WrapKey(Keys, Pkcs8));
  Result := new(['pkcs8', Pkcs8, 'fields', new(['name', Name, 'auth', Keys.auth, 'pub', Pub, 'wrapped', Wrapped])]);
end;

procedure SignUp(Name: JSValue; const Password: string; Email: JSValue); async;
var
  Made, Fields: TJSObject;
begin
  Made := await(NewAccountKeys(Name, Password, undefined));
  Fields := TJSObject(Made['fields']);
  if not Truthy(Email) then Email := '';
  Fields['email'] := Email;
  await(Post('/api/signup', Fields));
  await(KeepPrivateKey(Made['pkcs8'], Name));
end;

// An account made on IRC or by signing in with GitHub, GitLab or Google
// has no keys yet: they are made here from its password (its first one,
// when it has none).
procedure SetupKeys(Name: JSValue; const Password: string); async;
var
  Made: TJSObject;
begin
  if Length(Password) < 8 then raise TJSError.new(T('A password needs 8 characters or more.'));
  Made := await(NewAccountKeys(Name, Password, await(PasswordName(Name))));
  await(Post('/api/keys', Made['fields']));
  await(KeepPrivateKey(Made['pkcs8'], Name));
end;

// A new password from a one-time link an admin made.
procedure SetNewPassword(Token, Name: JSValue; const Password: string); async;
var
  Made: TJSObject;
begin
  if Length(Password) < 8 then raise TJSError.new(T('A password needs 8 characters or more.'));
  Made := await(NewAccountKeys(Name, Password, undefined));
  TJSObject(Made['fields'])['token'] := Token;
  await(Post('/api/newpassword', Made['fields']));
  await(KeepPrivateKey(Made['pkcs8'], Name));
end;

procedure OpenWrapped(Keys: TPasswordKeys; Name, Wrapped: JSValue); async;
begin
  await(KeepPrivateKey(await(UnwrapKey(Keys, Wrapped)), Name));
end;

// The sign-in key of the account's password, which the server asks for
// again before a change only the account's owner should make.
function PasswordProof(Name: JSValue; const Password: string): string; async;
begin
  Result := (await(KeysFrom(await(PasswordName(Name)), Password))).auth;
end;

// A new password from the member who knows the old one.  The private key
// stays the same, wrapped again, so locked conversations stay readable;
// an account that had no keys (wrapped is empty) gets them here.
procedure ChangePassword(Name: JSValue; const Current, Password: string; Wrapped: JSValue); async;
var
  Salt, Pkcs8: JSValue;
  Old, Keys: TPasswordKeys;
  Fields, Made: TJSObject;
begin
  if Length(Password) < 8 then raise TJSError.new(T('A password needs 8 characters or more.'));
  Salt := await(PasswordName(Name));
  Old := await(KeysFrom(Salt, Current));
  if Truthy(Wrapped) then
  begin
    try
      Pkcs8 := await(UnwrapKey(Old, Wrapped));
    except
      raise TJSError.new(T('That is not the password of this account.'));
    end;
    Keys := await(KeysFrom(Salt, Password));
    Fields := new(['auth', Keys.auth, 'wrapped', await(WrapKey(Keys, Pkcs8))]);
  end
  else
  begin
    Made := await(NewAccountKeys(Name, Password, Salt));
    Fields := TJSObject(Made['fields']);
    Pkcs8 := Made['pkcs8'];
  end;
  Fields['current'] := Old.auth;
  await(Post('/api/password', Fields));
  await(KeepPrivateKey(Pkcs8, Name));
end;

// Signed in some other way: the password still opens the private key.
procedure Unlock(Name: JSValue; const Password: string; Wrapped: JSValue); async;
begin
  try
    await(OpenWrapped(await(KeysFrom(await(PasswordName(Name)), Password)), Name, Wrapped));
  except
    raise TJSError.new(T('That is not the password of this account.'));
  end;
end;

procedure SignIn(Name: JSValue; const Password: string); async;
var
  Keys: TPasswordKeys;
  Answer: TJSObject;
begin
  Keys := await(KeysFrom(await(PasswordName(Name)), Password));
  Answer := TJSObject(ParseJson(await(Post('/api/signin', new(['name', Name, 'auth', Keys.auth])))));
  if Truthy(Answer['wrapped']) then await(OpenWrapped(Keys, Answer['name'], Answer['wrapped']))
  else await(SetupKeys(Answer['name'], Password));
end;

procedure SignOut; async;
var
  Reg, Sub: JSValue;
begin
  // This browser stops getting pushes for the account it leaves.
  try
    // not .ready: it waits for ever where the chat never registered its worker
    if Has(window.navigator, 'serviceWorker') then
      Reg := await(JSValue, TWorkers(TJSObject(window.navigator)['serviceWorker']).getRegistration('/'))
    else Reg := Null;
    if Truthy(Reg) and Truthy(TJSObject(Reg)['pushManager']) then
      Sub := await(JSValue, TPushManager(TJSObject(Reg)['pushManager']).getSubscription)
    else Sub := Null;
    if Truthy(Sub) then
    begin
      await(Post('/api/push', new(['endpoint', TJSObject(Sub)['endpoint'], 'off', '1'])));
      await(TPushSubscription(Sub).unsubscribe);
    end;
  except
  end;
  await(Post('/api/signout', TJSObject.new));
  try
    await(KeyStore('readwrite', function(S: TStore): TStoreRequest
      begin
        Result := S.delete('me');
      end));
  except
  end;
end;

// One form for both: a known name signs in, a new name joins.
procedure Join(Name: JSValue; const Password: string; Email: JSValue); async;
var
  Err: TFailure;
begin
  if not Ready then raise TJSError.new(T('This page has to be opened over https for accounts to work.'));
  try
    await(SignIn(Name, Password));
  except
    Err := TFailure(JSExceptValue);
    if Err.status <> 403 then raise;
    if Length(Password) < 8 then raise TJSError.new(T('A new password needs 8 characters or more.'));
    try
      await(SignUp(Name, Password, Email));
    except
      Err := TFailure(JSExceptValue);
      if Err.message = 'That name is taken.' then
        raise TJSError.new(T('That name is taken, or the password is wrong.'));
      if Err.status = 422 then Err.needEmail := True;
      raise;
    end;
  end;
end;

// A new name needs an address: the box for it appears in the form when
// the server asks for one.
function EmailBox(Form: TJSHTMLElement): TJSHTMLInputElement;
var
  Box: TJSHTMLInputElement;
begin
  Box := TJSHTMLInputElement(Form.querySelector('input[name=email]'));
  if not Truthy(Box) then
  begin
    Box := TJSHTMLInputElement(document.createElement('input'));
    Box.name := 'email';
    Box._type := 'email';
    TJSObject(Box)['autocomplete'] := 'email';
    Box.required := True;
    Box.placeholder := T('Email, to confirm the new account');
    Form.querySelector('button').before(Box);
  end;
  Result := Box;
end;

// Joins from a form with name and password, asking for the email when
// the name is new; true when it worked.
function JoinFrom(Form: TJSHTMLElement; Failed: TJoinFailed): boolean; async;
var
  Box: TJSHTMLInputElement;
  Elements: TJSObject;
  Name, Email, Err: JSValue;
  Password: string;
  Need: boolean;
begin
  Box := TJSHTMLInputElement(Form.querySelector('input[name=email]'));
  try
    Elements := TJSObject(TJSObject(Form)['elements']);
    Name := TJSString(TJSHTMLInputElement(Elements['name']).value).trim;
    Password := TJSHTMLInputElement(Elements['password']).value;
    if Truthy(Box) then Email := TJSString(Box.value).trim
    else Email := '';
    await(Join(Name, Password, Email));
    Result := True;
  except
    Err := JSExceptValue;
    Need := Truthy(TJSObject(Err)['needEmail']) and not Truthy(Box);
    if Need then EmailBox(Form).focus;
    if Need then Failed(TJSError.new(T('New here? Add your email; a link to confirm it is sent there.')))
    else Failed(Err);
    Result := False;
  end;
end;

procedure BindJoinForm(Form: TJSHTMLElement; After: TJoined);

  procedure Submitted(E: TJSEvent); async;
  var
    Button: TJSHTMLButtonElement;
    Words: string;
  begin
    E.preventDefault;
    Button := TJSHTMLButtonElement(Form.querySelector('button'));
    Words := Button.textContent;
    Button.disabled := True;
    Button.textContent := T('One moment');
    if await(JoinFrom(Form, procedure(Err: JSValue)
      begin
        Alert(TJSObject(Err)['message']);
      end)) then After();
    Button.disabled := False;
    Button.textContent := Words;
  end;

begin
  Form.addEventListener('submit', TJSRawEventHandler(@Submitted));
end;

procedure BindJoinForms(After: TJoined);
var
  Forms: TJSNodeList;
  I: NativeInt;
begin
  Forms := document.querySelectorAll('.quickjoin:not(.newpassword):not(.forgot)');
  for I := 0 to Forms.length - 1 do BindJoinForm(TJSHTMLElement(Forms[I]), After);
end;

// Private conversations

// The key two members share, derived from my private key and their public one.
function PairKey(const Other: string): TPair; async;
var
  Me, Theirs, Mine: TJSObject;
  Pub, Hk, Key: TJSCryptoKey;
  Shared: TJSArrayBuffer;
  MyName, TheirName: JSValue;
begin
  if Truthy(PairKeys[Other]) then Exit(TPair(PairKeys[Other]));
  Me := TJSObject(await(MyKey));
  if not Truthy(Me) then raise TJSError.new(T('locked'));
  Theirs := TJSObject(ParseJson(await(JSValue, TJSResponse(await(JSValue, Fetch('/api/key?name=' + EncodeUri(Other)))).text)));
  Mine := TJSObject(await(JSValue, TJSResponse(await(JSValue, Fetch('/api/me'))).json));
  Pub := await(Crypto.subtle.importKey('spki', Unb64(Theirs['pub']), new(['name', 'ECDH', 'namedCurve', 'P-256']),
    False, []));
  Shared := await(Crypto.subtle.deriveBits(new(['name', 'ECDH', 'public', Pub]), TJSCryptoKey(Me['key']), 256));
  Hk := await(Crypto.subtle.importKey('raw', Shared, 'HKDF', False, ['deriveKey']));
  MyName := Mine['key_name'];
  if not Truthy(MyName) then MyName := Me['name'];
  TheirName := Theirs['key_name'];
  if not Truthy(TheirName) then TheirName := Other;
  // The label keeps the first name too, or locked conversations would not open.
  Key := await(Crypto.subtle.deriveKey(new(['name', 'HKDF', 'hash', 'SHA-256', 'salt', TJSUint8Array.new(32),
    'info', Enc.encode('beginend private message')]), Hk, new(['name', 'AES-GCM', 'length', 256]), False,
    ['encrypt', 'decrypt']));
  PairKeys[Other] := new(['pub', Theirs['pub'], 'me', MyName, 'other', TheirName, 'key', Key]);
  Result := TPair(PairKeys[Other]);
end;

// The server hands out public keys, so it could hand out its own. This
// browser remembers the key it saw for each member, under the name it
// asked for, and says when another one comes. Both sides can compare a
// code made from the two keys. An older record under the name the server
// answers with is still read.
function SeenKey(const Other: string; Pair: TPair): JSValue; async;
begin
  Result := await(JSValue, KeyStore('readonly', function(S: TStore): TStoreRequest
    begin
      Result := S.get('seen:' + Lower(Other));
    end));
  if not Truthy(Result) then
    Result := await(JSValue, KeyStore('readonly', function(S: TStore): TStoreRequest
      begin
        Result := S.get('seen:' + Lower(Pair.other));
      end));
end;

// The key seen now for a member is the one this browser expects from here on.
function Remember(const Other: string; Pair: TPair): TJSPromise;
begin
  Result := KeyStore('readwrite', function(S: TStore): TStoreRequest
    begin
      Result := S.put(Pair.pub, 'seen:' + Lower(Other));
    end);
end;

// Whether a public key belongs to the private key this browser holds:
// both sides of an exchange with a throwaway key come out the same only
// then.  So the server cannot pass another key off as the member's own.
function OwnsKey(Pub: JSValue): boolean; async;
var
  Me, Curve, Once: TJSObject;
  Claimed: TJSCryptoKey;
  Mine, Theirs: TJSArrayBuffer;
begin
  Me := TJSObject(await(MyKey));
  Curve := new(['name', 'ECDH', 'namedCurve', 'P-256']);
  Once := TJSObject(await(JSValue, Crypto.subtle.generateKey(Curve, False, ['deriveBits'])));
  Claimed := await(Crypto.subtle.importKey('spki', Unb64(Pub), Curve, False, []));
  Mine := await(Crypto.subtle.deriveBits(new(['name', 'ECDH', 'public', Once['publicKey']]), TJSCryptoKey(Me['key']), 256));
  Theirs := await(Crypto.subtle.deriveBits(new(['name', 'ECDH', 'public', Claimed]), TJSCryptoKey(Once['privateKey']), 256));
  Result := Hex(Mine) = Hex(Theirs);
end;

function Partner(const Other: string): TJSObject; async;
var
  Pair: TPair;
  Seen: JSValue;
  Me, Mine: TJSObject;
  E: TJSError;
  Both, Code: string;
  Hash: TJSUint8Array;
  I: integer;
begin
  Pair := await(PairKey(Other));
  Seen := await(SeenKey(Other, Pair));
  if not Truthy(Seen) then await(Remember(Other, Pair));
  Me := TJSObject(await(JSValue, TJSResponse(await(JSValue, Fetch('/api/me'))).json));
  Mine := TJSObject(ParseJson(await(JSValue, TJSResponse(await(JSValue, Fetch('/api/key?name=' + EncodeUri(Me['name'])))).text)));
  // a code made with a key that is not this member's would prove nothing
  if not Truthy(Mine['pub']) or not await(OwnsKey(Mine['pub'])) then
  begin
    E := TJSError.new(T('The key this site gives out for you is not your own. Do not rely on this conversation being private.'));
    TJSObject(E)['notOwn'] := True;
    raise E;
  end;
  Both := TJSArray._of(Pair.pub, Mine['pub']).sort().join('|');
  Hash := TJSUint8Array.new(await(Crypto.subtle.digest('SHA-256', Enc.encode(Both))));
  Code := '';
  for I := 0 to 9 do
  begin
    if (I <> 0) and (I mod 2 = 0) then Code := Code + ' ';
    Code := Code + TJSString(TNumber(JSValue(Hash[I])).toString(16)).padStart(2, '0');
  end;
  Result := new(['code', Code, 'changed', Truthy(Seen) and not Same(Seen, Pair.pub)]);
end;

// The member looked at the code: the key seen now is the one to expect.
procedure Trust(const Other: string); async;
var
  Pair: TPair;
begin
  Pair := await(PairKey(Other));
  await(Remember(Other, Pair));
end;

// Who sent it to whom is sealed in with it, so the server cannot turn a
// message around.
function Between(From, Target: JSValue): TJSUint8Array;
begin
  Result := Enc.encode(Lower(From) + '>' + Lower(Target));
end;

function Seal(const Other: string; Payload: JSValue): TJSObject; async;
var
  Now: TJSObject;
  Pair: TPair;
  Seen: JSValue;
  E: TJSError;
  Iv: TJSTypedArray;
  Data: TJSArrayBuffer;
begin
  // before writing, their key as it is now: after a password reset they
  // have a new one, and a page left open would go on writing to the old
  // key, which nobody can open any more
  if Truthy(PairKeys[Other]) then
    try
      Now := TJSObject(ParseJson(await(JSValue, TJSResponse(await(JSValue, Fetch('/api/key?name=' + EncodeUri(Other)))).text)));
      if Truthy(Now['pub']) and not Same(Now['pub'], TPair(PairKeys[Other]).pub) then JSDelete(PairKeys, Other);
    except
    end;
  Pair := await(PairKey(Other));
  // a key other than the one this browser saw before: nothing is written
  // to it until the member has looked at the warning and said so
  Seen := await(SeenKey(Other, Pair));
  if Truthy(Seen) and not Same(Seen, Pair.pub) then
  begin
    E := TJSError.new(T('Their key has changed. Open the conversation again and look at the warning before you write.'));
    TJSObject(E)['keyChanged'] := True;
    raise E;
  end;
  if not Truthy(Seen) then await(Remember(Other, Pair));
  Iv := Crypto.getRandomValues(TJSUint8Array.new(12));
  Data := await(Crypto.subtle.encrypt(new(['name', 'AES-GCM', 'iv', Iv, 'additionalData', Between(Pair.me, Pair.other)]),
    Pair.key, Enc.encode(ToJson(Payload))));
  Result := new(['iv', B64(Iv), 'data', B64(Data)]);
end;

function OpenSealed(const Other: string; Message: TJSObject): JSValue; async;
var
  Pair: TPair;
  From, Target, Payload: JSValue;
  Plain: string;
begin
  Pair := await(PairKey(Other));
  From := Message['from_key_name'];
  if not Truthy(From) then From := Message['from'];
  if Lower(From) = Lower(Pair.me) then Target := Pair.other
  else Target := Pair.me;
  Plain := Dec.decode(await(Crypto.subtle.decrypt(new(['name', 'AES-GCM', 'iv', Unb64(Message['iv']),
    'additionalData', Between(From, Target)]), Pair.key, Unb64(Message['data']))));
  try
    Payload := ParseJson(Plain);
    if Truthy(Payload) and Truthy(TJSObject(Payload)['t']) then Exit(Payload);
  except
  end;
  Result := new(['t', 'text', 'text', Plain]);
end;

// A camera photo made smaller before it goes up: 2560 on its long side
// shows as much on a screen and is a fraction of the bytes.  Anything
// else, and a photo that would not get smaller, goes as it is.
function Smaller(AFile: TJSBlob): JSValue; async;
var
  Picture: TJSImageBitmap;
  Scale: double;
  Canvas: TJSHTMLCanvasElement;
  Made: TJSBlob;
begin
  if (AFile.type_ <> 'image/jpeg') or (AFile.size < 1500000) or not Truthy(TJSObject(window)['createImageBitmap']) then
    Exit(AFile);
  try
    Picture := TJSImageBitmap(await(JSValue, CreateImageBitmap(AFile, new(['imageOrientation', 'from-image']))));
    Scale := Min(1, 2560 / Max(Picture.width, Picture.height));
    Canvas := TJSHTMLCanvasElement(document.createElement('canvas'));
    Canvas.width := RoundOf(Picture.width * Scale);
    Canvas.height := RoundOf(Picture.height * Scale);
    TPaint(Canvas.getContext('2d')).drawImage(Picture, 0, 0, Canvas.width, Canvas.height);
    Made := TJSBlob(await(JSValue, TJSPromise.new(procedure(Done, Fail: TJSPromiseResolver)
      begin
        TCanvas(TJSObject(Canvas)).toBlob(Done, 'image/jpeg', 0.85);
      end)));
    if Truthy(Made) and (Made.size < AFile.size) then
      Result := TNewFile.new(ListOf(Made), TJSObject(AFile)['name'], new(['type', 'image/jpeg']))
    else Result := AFile;
  except
    Result := AFile;
  end;
end;

// A file for a private conversation: encrypted here, then uploaded.
// A JPEG or PNG without what the camera wrote beside the picture (where
// and when, the device, comments).  The server does this for a plain
// file; a sealed one it cannot read, so the page does it first.  A JPEG
// keeps the one value that says which way up it is.
function WithoutCameraData(Bytes: TJSArrayBuffer): JSValue;
var
  D: TJSUint8Array;
  Parts: TJSArray;
  Changed, Profile, Little: boolean;
  P, Turn, M, Size, Base, Stop, Dir, I, N: integer;
  Long: NativeInt;
  Kind: string;

  function W(At: integer): integer;
  begin
    if At + 1 < Stop then
    begin
      if Little then Result := D[At] or (D[At + 1] shl 8)
      else Result := (D[At] shl 8) or D[At + 1];
    end
    else Result := 0;
  end;

begin
  D := TJSUint8Array.new(Bytes);
  Parts := TJSArray.new;
  Changed := False;
  if (D.length > 16) and (D[0] = $FF) and (D[1] = $D8) then
  begin
    P := 2;
    Turn := 0;
    while (P + 4 <= D.length) and (D[P] = $FF) and (D[P + 1] <> $DA) do
    begin
      M := D[P + 1];
      Size := (D[P + 2] shl 8) or D[P + 3];
      if (Size < 2) or (P + 2 + Size > D.length) then Exit(Bytes);
      Profile := (M = $E2) and (Size > 13) and (D[P + 4] = $49) and (D[P + 5] = $43) and (D[P + 6] = $43);
      if (M < $E0) or ((M > $EF) and (M <> $FE)) or (M = $E0) or (M = $EE) or Profile then
        Parts.push(D.subarray(P, P + 2 + Size))
      else
      begin
        Changed := True;
        // Exif, then the TIFF header: its first directory may hold the turn (tag 0x0112)
        if (M = $E1) and (Turn = 0) and (Size > 20) and (D[P + 4] = $45) and (D[P + 5] = $78) then
        begin
          Base := P + 10;
          Stop := P + 2 + Size;
          Little := D[Base] = $49;
          if Little then Dir := Base + (W(Base + 4) or (W(Base + 6) shl 16))
          else Dir := Base + ((W(Base + 4) shl 16) or W(Base + 6));
          N := W(Dir);
          for I := 0 to N - 1 do
            if W(Dir + 2 + 12 * I) = $0112 then Turn := W(Dir + 10 + 12 * I);
        end;
      end;
      P := P + 2 + Size;
    end;
    if not Changed or (P + 4 > D.length) or (D[P] <> $FF) then Exit(Bytes);
    if (Turn > 1) and (Turn < 9) then
      Parts.unshift(TJSUint8Array._of($FF, $E1, 0, $22, $45, $78, $69, $66, 0, 0, $4D, $4D, 0, $2A, 0, 0, 0, 8,
        0, 1, 1, $12, 0, 3, 0, 0, 0, 1, 0, Turn, 0, 0, 0, 0, 0, 0));
    Parts.unshift(D.subarray(0, 2));
    Parts.push(D.subarray(P));
  end
  else if (D.length > 16) and (D[0] = $89) and (D[1] = $50) and (D[2] = $4E) and (D[3] = $47) then
  begin
    P := 8;
    Parts.push(D.subarray(0, 8));
    while P + 12 <= D.length do
    begin
      // shr 0 reads the four bytes as a size without a sign
      Long := ((D[P] shl 24) or (D[P + 1] shl 16) or (D[P + 2] shl 8) or D[P + 3]) shr 0;
      if P + 12 + Long > D.length then Exit(Bytes);
      Kind := TJSString.fromCharCode(D[P + 4], D[P + 5], D[P + 6], D[P + 7]);
      if TJSArray._of('eXIf', 'tEXt', 'zTXt', 'iTXt', 'tIME').indexOf(Kind) >= 0 then Changed := True
      else Parts.push(D.subarray(P, P + 12 + Long));
      P := P + 12 + Long;
    end;
    if not Changed or (P <> D.length) then Exit(Bytes);
  end
  else Exit(Bytes);
  Result := TJSBlob.new(Parts).arrayBuffer;
end;

function SealFile(const Other: string; AFile: TJSBlob; Expire: JSValue): TJSObject; async;
var
  Pair: TPair;
  Iv: TJSTypedArray;
  Plain, Data: TJSArrayBuffer;
  Form: TJSFormData;
  Answer: TJSObject;
begin
  Pair := await(PairKey(Other));
  Iv := Crypto.getRandomValues(TJSUint8Array.new(12));
  Plain := TJSArrayBuffer(await(JSValue, WithoutCameraData(TJSArrayBuffer(await(JSValue, AFile.arrayBuffer)))));
  Data := await(Crypto.subtle.encrypt(new(['name', 'AES-GCM', 'iv', Iv]), Pair.key, TJSBufferSource(JSValue(Plain))));
  Form := TJSFormData.new;
  Form.append('sealed', '1');
  if not Truthy(Expire) then Expire := '';
  TFormFields(Form).append('expire', Expire);
  Form.append('file', TJSBlob.new(ListOf(Data)), 'sealed');
  Answer := TJSObject(ParseJson(await(Post('/api/upload', Form))));
  Result := new(['token', Answer['token'], 'name', TJSObject(AFile)['name'], 'type', AFile.type_,
    'size', Plain.byteLength, 'iv', B64(Iv)]);
end;

function OpenFile(const Other: string; Meta: TJSObject): TJSBlob; async;
var
  Pair: TPair;
  Answer: TJSResponse;
  Plain: TJSArrayBuffer;
  Kind: JSValue;
begin
  Pair := await(PairKey(Other));
  Answer := await(TJSResponse, Fetch('/f/' + string(Meta['token']) + '/sealed'));
  if not Answer.ok then raise TJSError.new(await(string, Answer.text));
  Plain := await(Crypto.subtle.decrypt(new(['name', 'AES-GCM', 'iv', Unb64(Meta['iv'])]), Pair.key,
    TJSBufferSource(await(JSValue, Answer.arrayBuffer))));
  Kind := Meta['type'];
  if not Truthy(Kind) then Kind := 'application/octet-stream';
  Result := TJSBlob.new(ListOf(Plain), TJSBlobInit(new(['type', Kind])));
end;

// Beam

function IceServers: TJSArray; async;
var
  Answer: TJSObject;
  Ice: JSValue;
  Urls: TJSArray;
begin
  Answer := TJSObject(await(JSValue, TJSResponse(await(JSValue, Fetch('/api/ice'))).json));
  Ice := Answer['ice'];
  if not Truthy(Ice) then Ice := '';
  Urls := TJSArray(TJSString(Ice).split(TJSRegexp.new('\s+'))).filter(function(Url: JSValue; Index: NativeInt; All: TJSArray): boolean
    begin
      Result := Truthy(Url);
    end);
  if Urls.length <> 0 then Result := ListOf(new(['urls', Urls]))
  else Result := TJSArray.new;
end;

// Waits until the browser has found every way it can be reached, so one
// offer and one answer are all the server has to pass on.
function Gathered(Peer: TPeer): TJSPromise;
begin
  Result := TJSPromise.new(procedure(Done, Fail: TJSPromiseResolver)
    var
      Timer: NativeInt;
    begin
      if Peer.iceGatheringState = 'complete' then
      begin
        Done(undefined);
        Exit;
      end;
      Timer := window.setTimeout(procedure
        begin
          Done(undefined);
        end, 4000);
      Peer.addEventListener('icegatheringstatechange', procedure(E: TJSObject)
        begin
          if Peer.iceGatheringState = 'complete' then
          begin
            window.clearTimeout(Timer);
            Done(undefined);
          end;
        end);
    end);
end;

// Offers a file and returns the beam's token at once, so the offer can be
// announced; the file goes once the other side takes it.
// progress(sent, total, state) reports how it goes.
function BeamSend(const Other: string; AFile: TJSBlob; Progress: TBeamProgress): JSValue; async;
var
  Peer: TPeer;
  Channel: TChannel;
  Token: JSValue;
  Answered: TJSPromise;
  Tries: integer;
  Took, Gone: TJSPromiseResolver;

  procedure Look; async;
  var
    Beam: TJSObject;
  begin
    try
      Beam := TJSObject(await(JSValue, TJSResponse(await(JSValue, Fetch('/api/beam?token=' + string(Token)))).json));
      if Truthy(Beam['answer']) then
      begin
        Took(ParseJson(Beam['answer']));
        Exit;
      end;
    except
    end;
    Inc(Tries);
    if Tries > 600 then
    begin
      Gone(TJSError.new(T('Nobody took the beam.')));
      Exit;
    end;
    window.setTimeout(procedure
      begin
        Look;
      end, 1500);
  end;

  procedure Opened(E: TJSObject); async;
  var
    Sent: NativeInt;
    Piece: TJSArrayBuffer;
  begin
    Progress(0, AFile.size, 'sending');
    Channel.send(ToJson(new(['name', TJSObject(AFile)['name'], 'size', AFile.size, 'type', AFile.type_])));
    Channel.bufferedAmountLowThreshold := 1024 * 1024;
    Sent := 0;
    while Sent < AFile.size do
    begin
      if Channel.bufferedAmount > 4 * 1024 * 1024 then
        await(JSValue, TJSPromise.new(procedure(Done, Fail: TJSPromiseResolver)
          begin
            Channel.onbufferedamountlow := Done;
          end));
      Piece := TJSArrayBuffer(await(JSValue, AFile.slice(Sent, Sent + Chunk).arrayBuffer));
      Channel.send(Piece);
      Sent := Sent + Piece.byteLength;
      Progress(Sent, AFile.size, 'sending');
    end;
  end;

begin
  Peer := TPeer.new(new(['iceServers', await(IceServers)]));
  Channel := Peer.createDataChannel('beam', new(['ordered', True]));
  Channel.binaryType := 'arraybuffer';
  await(Peer.setLocalDescription(await(JSValue, Peer.createOffer)));
  await(Gathered(Peer));
  Token := TJSObject(ParseJson(await(Post('/api/beam', new(['to', Other, 'offer', ToJson(Peer.localDescription)])))))['token'];
  Progress(0, AFile.size, 'waiting');
  Answered := TJSPromise.new(procedure(Done, Fail: TJSPromiseResolver)
    begin
      Took := Done;
      Gone := Fail;
      Tries := 0;
      Look;
    end);
  Channel.onopen := @Opened;
  Channel.onmessage := procedure(E: TJSObject)
    begin
      if Same(E['data'], 'got it') then
      begin
        Progress(AFile.size, AFile.size, 'done');
        window.setTimeout(procedure
          begin
            Peer.close;
          end, 1000);
      end;
    end;
  Answered._then(function(Answer: JSValue): JSValue
    begin
      Result := Peer.setRemoteDescription(Answer);
    end).catch(function(Err: JSValue): JSValue
    begin
      Progress(0, AFile.size, TJSObject(Err)['message']);
    end);
  Result := Token;
end;

// Takes a beam; resolves with the file once it has all arrived.
function BeamReceive(Token: JSValue; Progress: TBeamProgress): JSValue; async;
var
  Beam: TJSObject;
  Peer: TPeer;
  Received: TJSPromise;
begin
  Beam := TJSObject(await(JSValue, TJSResponse(await(JSValue, Fetch('/api/beam?token=' + string(Token)))).json));
  if not Truthy(Beam['offer']) then raise TJSError.new(T('That beam is over.'));
  Peer := TPeer.new(new(['iceServers', await(IceServers)]));
  Received := TJSPromise.new(procedure(Done, Fail: TJSPromiseResolver)
    begin
      Peer.ondatachannel := procedure(E: TJSObject)
        var
          Channel: TChannel;
          Head: TBeamHead;
          Parts: TJSArray;
          Got: NativeInt;
        begin
          Channel := TChannel(E['channel']);
          Channel.binaryType := 'arraybuffer';
          Head := nil;
          Parts := TJSArray.new;
          Got := 0;
          Channel.onmessage := procedure(M: TJSObject)
            var
              Kind: JSValue;
            begin
              if not Truthy(Head) then
              begin
                Head := TBeamHead(ParseJson(M['data']));
                Progress(0, Head.size, 'receiving');
                Exit;
              end;
              Parts.push(M['data']);
              Got := Got + TJSArrayBuffer(M['data']).byteLength;
              Progress(Got, Head.size, 'receiving');
              if Got >= Head.size then
              begin
                Channel.send('got it');
                Kind := Head.kind;
                if not Truthy(Kind) then Kind := 'application/octet-stream';
                Done(TNewFile.new(Parts, Head.name, new(['type', Kind])));
              end;
            end;
          Channel.onclose := procedure(C: TJSObject)
            begin
              if not Truthy(Head) or (Got < Head.size) then Fail(TJSError.new(T('The beam was cut off.')));
            end;
        end;
    end);
  await(Peer.setRemoteDescription(ParseJson(Beam['offer'])));
  await(Peer.setLocalDescription(await(JSValue, Peer.createAnswer)));
  await(Gathered(Peer));
  await(Post('/api/beam/answer', new(['token', Token, 'answer', ToJson(Peer.localDescription)])));
  Progress(0, 0, 'connecting');
  Result := await(JSValue, Received);
end;

initialization
  Enc := TJSTextEncoder.new;
  Dec := TJSTextDecoder.new;
  PairKeys := TJSObject.new;
  TJSObject(window)['Keys'] := new(['ready', @Ready, 'post', @Post, 'join', @Join, 'joinFrom', @JoinFrom,
    'signOut', @SignOut, 'bindJoinForms', @BindJoinForms, 'myKey', @MyKey, 'setupKeys', @SetupKeys, 'unlock', @Unlock,
    'setNewPassword', @SetNewPassword, 'changePassword', @ChangePassword, 'passwordProof', @PasswordProof,
    'seal', @Seal, 'open', @OpenSealed, 'sealFile', @SealFile, 'openFile', @OpenFile, 'partner', @Partner,
    'trust', @Trust, 'beamSend', @BeamSend, 'beamReceive', @BeamReceive, 'smaller', @Smaller]);
end.
