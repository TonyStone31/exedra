if (!pas.KeysPage) {
rtl.module("KeysPage",["System","JS","Web","weborworker"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  this.Ready = function () {
    var Result = false;
    Result = Boolean(window["crypto"]) && Boolean(crypto["subtle"]);
    return Result;
  };
  this.Post = async function (Url, Fields) {
    var Result = "";
    var Body = undefined;
    var Answer = null;
    var Text = "";
    var E = null;
    if (pas.JS.jsInstanceOf(Fields,FormData)) {
      Body = Fields}
     else Body = new URLSearchParams(Fields);
    Answer = await fetch(Url,pas.JS.New(["method","POST","body",Body]));
    Text = await Answer.text();
    if (!Answer.ok) {
      E = new Error(Text);
      E.status = Answer.status;
      throw E;
    };
    Result = Text;
    return Result;
  };
  this.Join = async function (Name, Password, Email) {
    var Err = null;
    if (!$mod.Ready()) throw new Error(window.t("This page has to be opened over https for accounts to work."));
    try {
      await $impl.SignIn(Name,Password);
    } catch ($e) {
      Err = $e;
      if (Err.status !== 403) throw $e;
      if (Password.length < 8) throw new Error(window.t("A new password needs 8 characters or more."));
      try {
        await $impl.SignUp(Name,Password,Email);
      } catch ($e) {
        Err = $e;
        if (Err.message === "That name is taken.") throw new Error(window.t("That name is taken, or the password is wrong."));
        if (Err.status === 422) Err.needEmail = true;
        throw $e;
      };
    };
  };
  this.JoinFrom = async function (Form, Failed) {
    var Result = false;
    var Box = null;
    var Elements = null;
    var Name = undefined;
    var Email = undefined;
    var Err = undefined;
    var Password = "";
    var Need = false;
    Box = Form.querySelector("input[name=email]");
    try {
      Elements = Form["elements"];
      Name = Elements["name"].value.trim();
      Password = Elements["password"].value;
      if (Boolean(Box)) {
        Email = Box.value.trim()}
       else Email = "";
      await $mod.Join(Name,Password,Email);
      Result = true;
    } catch ($e) {
      Err = $e;
      Need = Boolean(Err["needEmail"]) && !Boolean(Box);
      if (Need) $impl.EmailBox(Form).focus();
      if (Need) {
        Failed(new Error(window.t("New here? Add your email; a link to confirm it is sent there.")))}
       else Failed(Err);
      Result = false;
    };
    return Result;
  };
  this.SignOut = async function () {
    var Reg = undefined;
    var Sub = undefined;
    try {
      if (Reflect.has(window.navigator,"serviceWorker")) {
        Reg = await window.navigator["serviceWorker"].getRegistration("/")}
       else Reg = null;
      if (Boolean(Reg) && Boolean(Reg["pushManager"])) {
        Sub = await Reg["pushManager"].getSubscription()}
       else Sub = null;
      if (Boolean(Sub)) {
        await $mod.Post("/api/push",pas.JS.New(["endpoint",Sub["endpoint"],"off","1"]));
        await Sub.unsubscribe();
      };
    } catch ($e) {
    };
    await $mod.Post("/api/signout",new Object());
    try {
      await $impl.KeyStore("readwrite",function (S) {
        var Result = null;
        Result = S.delete("me");
        return Result;
      });
    } catch ($e) {
    };
  };
  this.BindJoinForms = function (After) {
    var Forms = null;
    var I = 0;
    Forms = document.querySelectorAll(".quickjoin:not(.newpassword):not(.forgot)");
    for (var $l = 0, $end = Forms.length - 1; $l <= $end; $l++) {
      I = $l;
      $impl.BindJoinForm(Forms.item(I),After);
    };
  };
  this.MyKey = async function () {
    var Result = undefined;
    try {
      Result = await $impl.KeyStore("readonly",function (S) {
        var Result = null;
        Result = S.get("me");
        return Result;
      });
    } catch ($e) {
      Result = null;
    };
    return Result;
  };
  this.SetupKeys = async function (Name, Password) {
    var Made = null;
    if (Password.length < 8) throw new Error(window.t("A password needs 8 characters or more."));
    Made = await $impl.NewAccountKeys(Name,Password,await $impl.PasswordName(Name));
    await $mod.Post("/api/keys",Made["fields"]);
    await $impl.KeepPrivateKey(Made["pkcs8"],Name);
  };
  this.Unlock = async function (Name, Password, Wrapped) {
    try {
      await $impl.OpenWrapped(await $impl.KeysFrom(await $impl.PasswordName(Name),Password),Name,Wrapped);
    } catch ($e) {
      throw new Error(window.t("That is not the password of this account."));
    };
  };
  this.SetNewPassword = async function (Token, Name, Password) {
    var Made = null;
    if (Password.length < 8) throw new Error(window.t("A password needs 8 characters or more."));
    Made = await $impl.NewAccountKeys(Name,Password,undefined);
    Made["fields"]["token"] = Token;
    await $mod.Post("/api/newpassword",Made["fields"]);
    await $impl.KeepPrivateKey(Made["pkcs8"],Name);
  };
  this.ChangePassword = async function (Name, Current, Password, Wrapped) {
    var Salt = undefined;
    var Pkcs8 = undefined;
    var Old = null;
    var Keys = null;
    var Fields = null;
    var Made = null;
    if (Password.length < 8) throw new Error(window.t("A password needs 8 characters or more."));
    Salt = await $impl.PasswordName(Name);
    Old = await $impl.KeysFrom(Salt,Current);
    if (Boolean(Wrapped)) {
      try {
        Pkcs8 = await $impl.UnwrapKey(Old,Wrapped);
      } catch ($e) {
        throw new Error(window.t("That is not the password of this account."));
      };
      Keys = await $impl.KeysFrom(Salt,Password);
      Fields = pas.JS.New(["auth",Keys.auth,"wrapped",await $impl.WrapKey(Keys,Pkcs8)]);
    } else {
      Made = await $impl.NewAccountKeys(Name,Password,Salt);
      Fields = Made["fields"];
      Pkcs8 = Made["pkcs8"];
    };
    Fields["current"] = Old.auth;
    await $mod.Post("/api/password",Fields);
    await $impl.KeepPrivateKey(Pkcs8,Name);
  };
  this.PasswordProof = async function (Name, Password) {
    var Result = "";
    Result = (await $impl.KeysFrom(await $impl.PasswordName(Name),Password)).auth;
    return Result;
  };
  this.Seal = async function (Other, Payload) {
    var Result = null;
    var Now = null;
    var Pair = null;
    var Seen = undefined;
    var E = null;
    var Iv = null;
    var Data = null;
    if (Boolean($impl.PairKeys[Other])) try {
      Now = JSON.parse(await (await fetch("/api/key?name=" + encodeURIComponent(Other))).text());
      if (Boolean(Now["pub"]) && !Object.is(Now["pub"],$impl.PairKeys[Other].pub)) pas.JS.JSDelete($impl.PairKeys,Other);
    } catch ($e) {
    };
    Pair = await $impl.PairKey(Other);
    Seen = await $impl.SeenKey(Other,Pair);
    if (Boolean(Seen) && !Object.is(Seen,Pair.pub)) {
      E = new Error(window.t("Their key has changed. Open the conversation again and look at the warning before you write."));
      E["keyChanged"] = true;
      throw E;
    };
    if (!Boolean(Seen)) await $impl.Remember(Other,Pair);
    Iv = crypto.getRandomValues(new Uint8Array(12));
    Data = await crypto.subtle.encrypt(pas.JS.New(["name","AES-GCM","iv",Iv,"additionalData",$impl.Between(Pair.me,Pair.other)]),Pair.key,$impl.Enc.encode(JSON.stringify(Payload)));
    Result = pas.JS.New(["iv",$impl.B64(Iv),"data",$impl.B64(Data)]);
    return Result;
  };
  this.OpenSealed = async function (Other, Message) {
    var Result = undefined;
    var Pair = null;
    var From = undefined;
    var Target = undefined;
    var Payload = undefined;
    var Plain = "";
    Pair = await $impl.PairKey(Other);
    From = Message["from_key_name"];
    if (!Boolean(From)) From = Message["from"];
    if ($impl.Lower(From) === $impl.Lower(Pair.me)) {
      Target = Pair.other}
     else Target = Pair.me;
    Plain = $impl.Dec.decode(await crypto.subtle.decrypt(pas.JS.New(["name","AES-GCM","iv",$impl.Unb64(Message["iv"]),"additionalData",$impl.Between(From,Target)]),Pair.key,$impl.Unb64(Message["data"])));
    try {
      Payload = JSON.parse(Plain);
      if (Boolean(Payload) && Boolean(Payload["t"])) return Payload;
    } catch ($e) {
    };
    Result = pas.JS.New(["t","text","text",Plain]);
    return Result;
  };
  this.SealFile = async function (Other, AFile, Expire) {
    var Result = null;
    var Pair = null;
    var Iv = null;
    var Plain = null;
    var Data = null;
    var Form = null;
    var Answer = null;
    Pair = await $impl.PairKey(Other);
    Iv = crypto.getRandomValues(new Uint8Array(12));
    Plain = await $impl.WithoutCameraData(await AFile.arrayBuffer());
    Data = await crypto.subtle.encrypt(pas.JS.New(["name","AES-GCM","iv",Iv]),Pair.key,Plain);
    Form = new FormData();
    Form.append("sealed","1");
    if (!Boolean(Expire)) Expire = "";
    Form.append("expire",Expire);
    Form.append("file",new Blob(Array.of(Data)),"sealed");
    Answer = JSON.parse(await $mod.Post("/api/upload",Form));
    Result = pas.JS.New(["token",Answer["token"],"name",AFile["name"],"type",AFile.type,"size",Plain.byteLength,"iv",$impl.B64(Iv)]);
    return Result;
  };
  this.OpenFile = async function (Other, Meta) {
    var Result = null;
    var Pair = null;
    var Answer = null;
    var Plain = null;
    var Kind = undefined;
    Pair = await $impl.PairKey(Other);
    Answer = await fetch("/f/" + ("" + Meta["token"]) + "/sealed");
    if (!Answer.ok) throw new Error(await Answer.text());
    Plain = await crypto.subtle.decrypt(pas.JS.New(["name","AES-GCM","iv",$impl.Unb64(Meta["iv"])]),Pair.key,await Answer.arrayBuffer());
    Kind = Meta["type"];
    if (!Boolean(Kind)) Kind = "application/octet-stream";
    Result = new Blob(Array.of(Plain),pas.JS.New(["type",Kind]));
    return Result;
  };
  this.Partner = async function (Other) {
    var Result = null;
    var Pair = null;
    var Seen = undefined;
    var Me = null;
    var Mine = null;
    var E = null;
    var Both = "";
    var Code = "";
    var Hash = null;
    var I = 0;
    Pair = await $impl.PairKey(Other);
    Seen = await $impl.SeenKey(Other,Pair);
    if (!Boolean(Seen)) await $impl.Remember(Other,Pair);
    Me = await (await fetch("/api/me")).json();
    Mine = JSON.parse(await (await fetch("/api/key?name=" + encodeURIComponent(Me["name"]))).text());
    if (!Boolean(Mine["pub"]) || !await $impl.OwnsKey(Mine["pub"])) {
      E = new Error(window.t("The key this site gives out for you is not your own. Do not rely on this conversation being private."));
      E["notOwn"] = true;
      throw E;
    };
    Both = Array.of(Pair.pub,Mine["pub"]).sort().join("|");
    Hash = new Uint8Array(await crypto.subtle.digest("SHA-256",$impl.Enc.encode(Both)));
    Code = "";
    for (I = 0; I <= 9; I++) {
      if ((I !== 0) && ((I % 2) === 0)) Code = Code + " ";
      Code = Code + Hash[I].toString(16).padStart(2,"0");
    };
    Result = pas.JS.New(["code",Code,"changed",Boolean(Seen) && !Object.is(Seen,Pair.pub)]);
    return Result;
  };
  this.Trust = async function (Other) {
    var Pair = null;
    Pair = await $impl.PairKey(Other);
    await $impl.Remember(Other,Pair);
  };
  this.BeamSend = async function (Other, AFile, Progress) {
    var Result = undefined;
    var Peer = null;
    var Channel = null;
    var Token = undefined;
    var Answered = null;
    var Tries = 0;
    var Took = null;
    var Gone = null;
    async function Look() {
      var Beam = null;
      try {
        Beam = await (await fetch("/api/beam?token=" + ("" + Token))).json();
        if (Boolean(Beam["answer"])) {
          Took(JSON.parse(Beam["answer"]));
          return;
        };
      } catch ($e) {
      };
      Tries += 1;
      if (Tries > 600) {
        Gone(new Error(window.t("Nobody took the beam.")));
        return;
      };
      window.setTimeout(function () {
        Look();
      },1500);
    };
    async function Opened(E) {
      var Sent = 0;
      var Piece = null;
      Progress(0,AFile.size,"sending");
      Channel.send(JSON.stringify(pas.JS.New(["name",AFile["name"],"size",AFile.size,"type",AFile.type])));
      Channel.bufferedAmountLowThreshold = 1024 * 1024;
      Sent = 0;
      while (Sent < AFile.size) {
        if (Channel.bufferedAmount > (4 * 1024 * 1024)) await new Promise(function (Done, Fail) {
          Channel.onbufferedamountlow = Done;
        });
        Piece = await AFile.slice(Sent,Sent + 65536).arrayBuffer();
        Channel.send(Piece);
        Sent = Sent + Piece.byteLength;
        Progress(Sent,AFile.size,"sending");
      };
    };
    Peer = new RTCPeerConnection(pas.JS.New(["iceServers",await $impl.IceServers()]));
    Channel = Peer.createDataChannel("beam",pas.JS.New(["ordered",true]));
    Channel.binaryType = "arraybuffer";
    await Peer.setLocalDescription(await Peer.createOffer());
    await $impl.Gathered(Peer);
    Token = JSON.parse(await $mod.Post("/api/beam",pas.JS.New(["to",Other,"offer",JSON.stringify(Peer.localDescription)])))["token"];
    Progress(0,AFile.size,"waiting");
    Answered = new Promise(function (Done, Fail) {
      Took = Done;
      Gone = Fail;
      Tries = 0;
      Look();
    });
    Channel.onopen = Opened;
    Channel.onmessage = function (E) {
      if (Object.is(E["data"],"got it")) {
        Progress(AFile.size,AFile.size,"done");
        window.setTimeout(function () {
          Peer.close();
        },1000);
      };
    };
    Answered.then(function (Answer) {
      var Result = undefined;
      Result = Peer.setRemoteDescription(Answer);
      return Result;
    }).catch(function (Err) {
      var Result = undefined;
      Progress(0,AFile.size,Err["message"]);
      return Result;
    });
    Result = Token;
    return Result;
  };
  this.BeamReceive = async function (Token, Progress) {
    var Result = undefined;
    var Beam = null;
    var Peer = null;
    var Received = null;
    Beam = await (await fetch("/api/beam?token=" + ("" + Token))).json();
    if (!Boolean(Beam["offer"])) throw new Error(window.t("That beam is over."));
    Peer = new RTCPeerConnection(pas.JS.New(["iceServers",await $impl.IceServers()]));
    Received = new Promise(function (Done, Fail) {
      Peer.ondatachannel = function (E) {
        var Channel = null;
        var Head = null;
        var Parts = null;
        var Got = 0;
        Channel = E["channel"];
        Channel.binaryType = "arraybuffer";
        Head = null;
        Parts = new Array();
        Got = 0;
        Channel.onmessage = function (M) {
          var Kind = undefined;
          if (!Boolean(Head)) {
            Head = JSON.parse(M["data"]);
            Progress(0,Head.size,"receiving");
            return;
          };
          Parts.push(M["data"]);
          Got = Got + M["data"].byteLength;
          Progress(Got,Head.size,"receiving");
          if (Got >= Head.size) {
            Channel.send("got it");
            Kind = Head.type;
            if (!Boolean(Kind)) Kind = "application/octet-stream";
            Done(new File(Parts,Head.name,pas.JS.New(["type",Kind])));
          };
        };
        Channel.onclose = function (C) {
          if (!Boolean(Head) || (Got < Head.size)) Fail(new Error(window.t("The beam was cut off.")));
        };
      };
    });
    await Peer.setRemoteDescription(JSON.parse(Beam["offer"]));
    await Peer.setLocalDescription(await Peer.createAnswer());
    await $impl.Gathered(Peer);
    await $mod.Post("/api/beam/answer",pas.JS.New(["token",Token,"answer",JSON.stringify(Peer.localDescription)]));
    Progress(0,0,"connecting");
    Result = await Received;
    return Result;
  };
  this.Smaller = async function (AFile) {
    var Result = undefined;
    var Picture = null;
    var Scale = 0.0;
    var Canvas = null;
    var Made = null;
    if ((AFile.type !== "image/jpeg") || (AFile.size < 1500000) || !Boolean(window["createImageBitmap"])) return AFile;
    try {
      Picture = await createImageBitmap(AFile,pas.JS.New(["imageOrientation","from-image"]));
      Scale = Math.min(1,2560 / Math.max(Picture.width,Picture.height));
      Canvas = document.createElement("canvas");
      Canvas.width = Math.round(Picture.width * Scale);
      Canvas.height = Math.round(Picture.height * Scale);
      Canvas.getContext("2d").drawImage(Picture,0,0,Canvas.width,Canvas.height);
      Made = await new Promise(function (Done, Fail) {
        Canvas.toBlob(Done,"image/jpeg",0.85);
      });
      if (Boolean(Made) && (Made.size < AFile.size)) {
        Result = new File(Array.of(Made),AFile["name"],pas.JS.New(["type","image/jpeg"]))}
       else Result = AFile;
    } catch ($e) {
      Result = AFile;
    };
    return Result;
  };
  $mod.$implcode = function () {
    $impl.Chunk = 64 * 1024;
    $impl.Enc = null;
    $impl.Dec = null;
    $impl.PairKeys = null;
    $impl.B64 = function (B) {
      var Result = "";
      var Bytes = null;
      var S = "";
      var I = 0;
      Bytes = new Uint8Array(B);
      S = "";
      I = 0;
      while (I < Bytes.length) {
        S = S + String.fromCharCode.apply(null,Bytes.subarray(I,I + 32768));
        I = I + 32768;
      };
      Result = btoa(S);
      return Result;
    };
    $impl.Unb64 = function (S) {
      var Result = null;
      Result = Uint8Array.from(atob(S),function (C, Index, All) {
        var Result = undefined;
        Result = C.charCodeAt(0);
        return Result;
      });
      return Result;
    };
    $impl.Hex = function (B) {
      var Result = "";
      Result = Array.from(new Uint8Array(B),function (X) {
        var Result = undefined;
        Result = X.toString(16).padStart(2,"0");
        return Result;
      }).join("");
      return Result;
    };
    $impl.Lower = function (S) {
      var Result = "";
      Result = S.toLowerCase();
      return Result;
    };
    $impl.KeysFrom = async function (Name, Password) {
      var Result = null;
      var Base = null;
      var Hk = null;
      var Wrap = null;
      var Master = null;
      var Bits = null;
      function Info(S) {
        var Result = null;
        Result = pas.JS.New(["name","HKDF","hash","SHA-256","salt",new Uint8Array(32),"info",$impl.Enc.encode(S)]);
        return Result;
      };
      Base = await crypto.subtle.importKey("raw",$impl.Enc.encode(Password),"PBKDF2",false,["deriveBits"]);
      Master = await crypto.subtle.deriveBits(pas.JS.New(["name","PBKDF2","hash","SHA-256","salt",$impl.Enc.encode("beginend:" + $impl.Lower(Name)),"iterations",600000]),Base,256);
      Hk = await crypto.subtle.importKey("raw",Master,"HKDF",false,["deriveBits","deriveKey"]);
      Bits = await crypto.subtle.deriveBits(Info("sign in"),Hk,256);
      Wrap = await crypto.subtle.deriveKey(Info("wrap"),Hk,pas.JS.New(["name","AES-GCM","length",256]),false,["encrypt","decrypt"]);
      Result = pas.JS.New(["auth",$impl.Hex(Bits),"wrap",Wrap]);
      return Result;
    };
    $impl.PasswordName = async function (Name) {
      var Result = undefined;
      var Answer = null;
      Answer = await fetch("/api/auth-name?name=" + encodeURIComponent(Name),pas.JS.New(["cache","no-store"]));
      if (!Answer.ok) throw new Error(await Answer.text());
      Result = (await Answer.json())["name"];
      return Result;
    };
    $impl.KeyStore = function (Mode, Work) {
      var Result = null;
      Result = new Promise(function (Done, Fail) {
        var Opening = null;
        Opening = indexedDB.open("beginend",1);
        Opening.onupgradeneeded = function (E) {
          Opening.result.createObjectStore("keys");
        };
        Opening.onerror = function (E) {
          Fail(Opening.error);
        };
        Opening.onsuccess = function (E) {
          var Request = null;
          Request = Work(Opening.result.transaction("keys",Mode).objectStore("keys"));
          Request.onsuccess = function (E) {
            Done(Request.result);
          };
          Request.onerror = function (E) {
            Fail(Request.error);
          };
        };
      });
      return Result;
    };
    $impl.KeepPrivateKey = async function (Pkcs8, Name) {
      var Key = null;
      Key = await crypto.subtle.importKey("pkcs8",Pkcs8,pas.JS.New(["name","ECDH","namedCurve","P-256"]),false,["deriveBits"]);
      await $impl.KeyStore("readwrite",function (S) {
        var Result = null;
        Result = S.put(pas.JS.New(["name",Name,"key",Key]),"me");
        return Result;
      });
    };
    $impl.WrapKey = async function (Keys, Pkcs8) {
      var Result = "";
      var Iv = null;
      Iv = crypto.getRandomValues(new Uint8Array(12));
      Result = $impl.B64(Iv) + "." + $impl.B64(await crypto.subtle.encrypt(pas.JS.New(["name","AES-GCM","iv",Iv]),Keys.wrap,Pkcs8));
      return Result;
    };
    $impl.UnwrapKey = async function (Keys, Wrapped) {
      var Result = null;
      var Parts = [];
      Parts = Wrapped.split(".");
      Result = await crypto.subtle.decrypt(pas.JS.New(["name","AES-GCM","iv",$impl.Unb64(Parts[0])]),Keys.wrap,$impl.Unb64(Parts[1]));
      return Result;
    };
    $impl.NewAccountKeys = async function (Name, Password, SaltName) {
      var Result = null;
      var Keys = null;
      var Pair = null;
      var Pkcs8 = undefined;
      var Pub = "";
      var Wrapped = "";
      if (!Boolean(SaltName)) SaltName = Name;
      Keys = await $impl.KeysFrom(SaltName,Password);
      Pair = await crypto.subtle.generateKey(pas.JS.New(["name","ECDH","namedCurve","P-256"]),true,["deriveBits"]);
      Pkcs8 = await crypto.subtle.exportKey("pkcs8",Pair["privateKey"]);
      Pub = $impl.B64(await crypto.subtle.exportKey("spki",Pair["publicKey"]));
      Wrapped = await $impl.WrapKey(Keys,Pkcs8);
      Result = pas.JS.New(["pkcs8",Pkcs8,"fields",pas.JS.New(["name",Name,"auth",Keys.auth,"pub",Pub,"wrapped",Wrapped])]);
      return Result;
    };
    $impl.SignUp = async function (Name, Password, Email) {
      var Made = null;
      var Fields = null;
      Made = await $impl.NewAccountKeys(Name,Password,undefined);
      Fields = Made["fields"];
      if (!Boolean(Email)) Email = "";
      Fields["email"] = Email;
      await $mod.Post("/api/signup",Fields);
      await $impl.KeepPrivateKey(Made["pkcs8"],Name);
    };
    $impl.OpenWrapped = async function (Keys, Name, Wrapped) {
      await $impl.KeepPrivateKey(await $impl.UnwrapKey(Keys,Wrapped),Name);
    };
    $impl.SignIn = async function (Name, Password) {
      var Keys = null;
      var Answer = null;
      Keys = await $impl.KeysFrom(await $impl.PasswordName(Name),Password);
      Answer = JSON.parse(await $mod.Post("/api/signin",pas.JS.New(["name",Name,"auth",Keys.auth])));
      if (Boolean(Answer["wrapped"])) {
        await $impl.OpenWrapped(Keys,Answer["name"],Answer["wrapped"])}
       else await $mod.SetupKeys(Answer["name"],Password);
    };
    $impl.EmailBox = function (Form) {
      var Result = null;
      var Box = null;
      Box = Form.querySelector("input[name=email]");
      if (!Boolean(Box)) {
        Box = document.createElement("input");
        Box.name = "email";
        Box.type = "email";
        Box["autocomplete"] = "email";
        Box.required = true;
        Box.placeholder = window.t("Email, to confirm the new account");
        Form.querySelector("button").before(Box);
      };
      Result = Box;
      return Result;
    };
    $impl.BindJoinForm = function (Form, After) {
      async function Submitted(E) {
        var Button = null;
        var Words = "";
        E.preventDefault();
        Button = Form.querySelector("button");
        Words = Button.textContent;
        Button.disabled = true;
        Button.textContent = window.t("One moment");
        if (await $mod.JoinFrom(Form,function (Err) {
          alert(Err["message"]);
        })) After();
        Button.disabled = false;
        Button.textContent = Words;
      };
      Form.addEventListener("submit",Submitted);
    };
    $impl.PairKey = async function (Other) {
      var Result = null;
      var Me = null;
      var Theirs = null;
      var Mine = null;
      var Pub = null;
      var Hk = null;
      var Key = null;
      var Shared = null;
      var MyName = undefined;
      var TheirName = undefined;
      if (Boolean($impl.PairKeys[Other])) return $impl.PairKeys[Other];
      Me = await $mod.MyKey();
      if (!Boolean(Me)) throw new Error(window.t("locked"));
      Theirs = JSON.parse(await (await fetch("/api/key?name=" + encodeURIComponent(Other))).text());
      Mine = await (await fetch("/api/me")).json();
      Pub = await crypto.subtle.importKey("spki",$impl.Unb64(Theirs["pub"]),pas.JS.New(["name","ECDH","namedCurve","P-256"]),false,[]);
      Shared = await crypto.subtle.deriveBits(pas.JS.New(["name","ECDH","public",Pub]),Me["key"],256);
      Hk = await crypto.subtle.importKey("raw",Shared,"HKDF",false,["deriveKey"]);
      MyName = Mine["key_name"];
      if (!Boolean(MyName)) MyName = Me["name"];
      TheirName = Theirs["key_name"];
      if (!Boolean(TheirName)) TheirName = Other;
      Key = await crypto.subtle.deriveKey(pas.JS.New(["name","HKDF","hash","SHA-256","salt",new Uint8Array(32),"info",$impl.Enc.encode("beginend private message")]),Hk,pas.JS.New(["name","AES-GCM","length",256]),false,["encrypt","decrypt"]);
      $impl.PairKeys[Other] = pas.JS.New(["pub",Theirs["pub"],"me",MyName,"other",TheirName,"key",Key]);
      Result = $impl.PairKeys[Other];
      return Result;
    };
    $impl.SeenKey = async function (Other, Pair) {
      var Result = undefined;
      Result = await $impl.KeyStore("readonly",function (S) {
        var Result = null;
        Result = S.get("seen:" + $impl.Lower(Other));
        return Result;
      });
      if (!Boolean(Result)) Result = await $impl.KeyStore("readonly",function (S) {
        var Result = null;
        Result = S.get("seen:" + $impl.Lower(Pair.other));
        return Result;
      });
      return Result;
    };
    $impl.Remember = function (Other, Pair) {
      var Result = null;
      Result = $impl.KeyStore("readwrite",function (S) {
        var Result = null;
        Result = S.put(Pair.pub,"seen:" + $impl.Lower(Other));
        return Result;
      });
      return Result;
    };
    $impl.OwnsKey = async function (Pub) {
      var Result = false;
      var Me = null;
      var Curve = null;
      var Once = null;
      var Claimed = null;
      var Mine = null;
      var Theirs = null;
      Me = await $mod.MyKey();
      Curve = pas.JS.New(["name","ECDH","namedCurve","P-256"]);
      Once = await crypto.subtle.generateKey(Curve,false,["deriveBits"]);
      Claimed = await crypto.subtle.importKey("spki",$impl.Unb64(Pub),Curve,false,[]);
      Mine = await crypto.subtle.deriveBits(pas.JS.New(["name","ECDH","public",Once["publicKey"]]),Me["key"],256);
      Theirs = await crypto.subtle.deriveBits(pas.JS.New(["name","ECDH","public",Claimed]),Once["privateKey"],256);
      Result = $impl.Hex(Mine) === $impl.Hex(Theirs);
      return Result;
    };
    $impl.Between = function (From, Target) {
      var Result = null;
      Result = $impl.Enc.encode($impl.Lower(From) + ">" + $impl.Lower(Target));
      return Result;
    };
    $impl.WithoutCameraData = function (Bytes) {
      var Result = undefined;
      var D = null;
      var Parts = null;
      var Changed = false;
      var Profile = false;
      var Little = false;
      var P = 0;
      var Turn = 0;
      var M = 0;
      var Size = 0;
      var Base = 0;
      var Stop = 0;
      var Dir = 0;
      var I = 0;
      var N = 0;
      var Long = 0;
      var Kind = "";
      function W(At) {
        var Result = 0;
        if ((At + 1) < Stop) {
          if (Little) {
            Result = D[At] | (D[At + 1] << 8)}
           else Result = (D[At] << 8) | D[At + 1];
        } else Result = 0;
        return Result;
      };
      D = new Uint8Array(Bytes);
      Parts = new Array();
      Changed = false;
      if ((D.length > 16) && (D[0] === 0xFF) && (D[1] === 0xD8)) {
        P = 2;
        Turn = 0;
        while (((P + 4) <= D.length) && (D[P] === 0xFF) && (D[P + 1] !== 0xDA)) {
          M = D[P + 1];
          Size = (D[P + 2] << 8) | D[P + 3];
          if ((Size < 2) || ((P + 2 + Size) > D.length)) return Bytes;
          Profile = (M === 0xE2) && (Size > 13) && (D[P + 4] === 0x49) && (D[P + 5] === 0x43) && (D[P + 6] === 0x43);
          if ((M < 0xE0) || ((M > 0xEF) && (M !== 0xFE)) || (M === 0xE0) || (M === 0xEE) || Profile) {
            Parts.push(D.subarray(P,P + 2 + Size))}
           else {
            Changed = true;
            if ((M === 0xE1) && (Turn === 0) && (Size > 20) && (D[P + 4] === 0x45) && (D[P + 5] === 0x78)) {
              Base = P + 10;
              Stop = P + 2 + Size;
              Little = D[Base] === 0x49;
              if (Little) {
                Dir = Base + (W(Base + 4) | (W(Base + 6) << 16))}
               else Dir = Base + ((W(Base + 4) << 16) | W(Base + 6));
              N = W(Dir);
              for (var $l = 0, $end = N - 1; $l <= $end; $l++) {
                I = $l;
                if (W(Dir + 2 + (12 * I)) === 0x112) Turn = W(Dir + 10 + (12 * I));
              };
            };
          };
          P = P + 2 + Size;
        };
        if (!Changed || ((P + 4) > D.length) || (D[P] !== 0xFF)) return Bytes;
        if ((Turn > 1) && (Turn < 9)) Parts.unshift(Uint8Array.of(0xFF,0xE1,0,0x22,0x45,0x78,0x69,0x66,0,0,0x4D,0x4D,0,0x2A,0,0,0,8,0,1,1,0x12,0,3,0,0,0,1,0,Turn,0,0,0,0,0,0));
        Parts.unshift(D.subarray(0,2));
        Parts.push(D.subarray(P));
      } else if ((D.length > 16) && (D[0] === 0x89) && (D[1] === 0x50) && (D[2] === 0x4E) && (D[3] === 0x47)) {
        P = 8;
        Parts.push(D.subarray(0,8));
        while ((P + 12) <= D.length) {
          Long = ((D[P] << 24) | (D[P + 1] << 16) | (D[P + 2] << 8) | D[P + 3]) >>> 0;
          if ((P + 12 + Long) > D.length) return Bytes;
          Kind = String.fromCharCode(D[P + 4],D[P + 5],D[P + 6],D[P + 7]);
          if (Array.of("eXIf","tEXt","zTXt","iTXt","tIME").indexOf(Kind) >= 0) {
            Changed = true}
           else Parts.push(D.subarray(P,P + 12 + Long));
          P = P + 12 + Long;
        };
        if (!Changed || (P !== D.length)) return Bytes;
      } else return Bytes;
      Result = (new Blob(Parts)).arrayBuffer();
      return Result;
    };
    $impl.IceServers = async function () {
      var Result = null;
      var Answer = null;
      var Ice = undefined;
      var Urls = null;
      Answer = await (await fetch("/api/ice")).json();
      Ice = Answer["ice"];
      if (!Boolean(Ice)) Ice = "";
      Urls = Ice.split(new RegExp("\\s+")).filter(function (Url, Index, All) {
        var Result = false;
        Result = Boolean(Url);
        return Result;
      });
      if (Urls.length !== 0) {
        Result = Array.of(pas.JS.New(["urls",Urls]))}
       else Result = new Array();
      return Result;
    };
    $impl.Gathered = function (Peer) {
      var Result = null;
      Result = new Promise(function (Done, Fail) {
        var Timer = 0;
        if (Peer.iceGatheringState === "complete") {
          Done(undefined);
          return;
        };
        Timer = window.setTimeout(function () {
          Done(undefined);
        },4000);
        Peer.addEventListener("icegatheringstatechange",function (E) {
          if (Peer.iceGatheringState === "complete") {
            window.clearTimeout(Timer);
            Done(undefined);
          };
        });
      });
      return Result;
    };
  };
  $mod.$init = function () {
    $impl.Enc = new TextEncoder();
    $impl.Dec = new TextDecoder();
    $impl.PairKeys = new Object();
    window["Keys"] = pas.JS.New(["ready",$mod.Ready,"post",$mod.Post,"join",$mod.Join,"joinFrom",$mod.JoinFrom,"signOut",$mod.SignOut,"bindJoinForms",$mod.BindJoinForms,"myKey",$mod.MyKey,"setupKeys",$mod.SetupKeys,"unlock",$mod.Unlock,"setNewPassword",$mod.SetNewPassword,"changePassword",$mod.ChangePassword,"passwordProof",$mod.PasswordProof,"seal",$mod.Seal,"open",$mod.OpenSealed,"sealFile",$mod.SealFile,"openFile",$mod.OpenFile,"partner",$mod.Partner,"trust",$mod.Trust,"beamSend",$mod.BeamSend,"beamReceive",$mod.BeamReceive,"smaller",$mod.Smaller]);
  };
},["PageKit","PageGlobals"]);

rtl.run('KeysPage');
}
