if (!pas.AppPage) {
rtl.module("app_helpers",["System","JS","Web"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  this.Body = null;
  this.Me = null;
  this.SiteName = undefined;
  this.Stream = null;
  this.Panel = null;
  this.S = null;
  this.Extras = null;
  this.SideEl = null;
  this.SideLink = null;
  this.SideAvatar = null;
  this.SideIcon = null;
  this.SideIconButton = null;
  this.Icons = undefined;
  this.KeysPost = null;
  this.Trail = null;
  this.Locale = undefined;
  this.PinWatch = null;
  this.Find = function (Selector, Root) {
    var Result = null;
    if (!Boolean(Root)) Root = document;
    Result = Root.querySelector(Selector);
    return Result;
  };
  this.May = function (P) {
    var Result = false;
    Result = $mod.Me.can.indexOf(P) >= 0;
    return Result;
  };
  this.MayHere = function (P) {
    var Result = false;
    Result = Boolean($mod.S.info) && Boolean($mod.S.info["can"]) && Boolean($mod.S.info["can"]["" + P]);
    return Result;
  };
  this.El = function (Tag, Cls, Words) {
    var Result = null;
    Result = $mod.SideEl.call(undefined,Tag,Cls,Words);
    return Result;
  };
  this.Link = function (Href, Cls, Words) {
    var Result = null;
    Result = $mod.SideLink.call(undefined,Href,Cls,Words);
    return Result;
  };
  this.Avatar = function (Name, Url, Cls) {
    var Result = null;
    Result = $mod.SideAvatar.call(undefined,Name,Url,Cls);
    return Result;
  };
  this.Icon = function (Name) {
    var Result = null;
    Result = $mod.SideIcon.call(undefined,Name);
    return Result;
  };
  this.IconButton = function (Name, Title, Cls) {
    var Result = null;
    Result = $mod.SideIconButton.call(undefined,Name,Title,Cls);
    return Result;
  };
  this.Get = async function (Url) {
    var Result = undefined;
    var Answer = null;
    Answer = await window.fetch(Url);
    if (!Answer.ok) throw new Error(await Answer.text());
    Result = Answer.json();
    return Result;
  };
  this.Post = function (Url, Fields) {
    var Result = undefined;
    Result = $mod.KeysPost.call(undefined,Url,Fields);
    return Result;
  };
  this.Toast = function (Words, Kind) {
    var Note = null;
    if (Boolean(Kind)) {
      Note = $mod.El("div","toast " + ("" + Kind),Words)}
     else Note = $mod.El("div","toast ",Words);
    $mod.Find("#toasts",undefined).appendChild(Note);
    window.setTimeout(function () {
      Note.classList.add("going");
    },4500);
    window.setTimeout(function () {
      Note.remove();
    },5000);
  };
  this.Remember = function (What) {
    $mod.Trail.push((new Date()).toISOString().slice(11,19) + " " + What);
    if ($mod.Trail.length > 15) $mod.Trail.shift();
  };
  this.Failed = function (Err) {
    var Words = undefined;
    Words = Err["message"];
    if (!Boolean(Words)) Words = String(Err);
    $mod.Remember("shown: " + ("" + Words));
    $mod.Toast(Words,"bad");
  };
  this.Clock = function (At) {
    var Result = undefined;
    var D = null;
    D = new Date(At);
    if (isNaN(D)) {
      Result = At}
     else Result = D.toLocaleTimeString($mod.Locale,pas.JS.New(["hour","2-digit","minute","2-digit"]));
    return Result;
  };
  this.DayLabel = function (D) {
    var Result = "";
    var Today = null;
    var Yesterday = null;
    Today = new Date();
    Yesterday = new Date(Date.now() - 86400000);
    if (D.toDateString() === Today.toDateString()) {
      Result = window.t("Today")}
     else if (D.toDateString() === Yesterday.toDateString()) {
      Result = window.t("Yesterday")}
     else if (D.getFullYear() !== Today.getFullYear()) {
      Result = D.toLocaleDateString($mod.Locale,pas.JS.New(["weekday","long","month","long","day","numeric","year","numeric"]))}
     else Result = D.toLocaleDateString($mod.Locale,pas.JS.New(["weekday","long","month","long","day","numeric"]));
    return Result;
  };
  this.Ago = function (Iso) {
    var Result = "";
    var Minutes = 0.0;
    Result = "";
    if (!Boolean(Iso)) return Result;
    Minutes = Math.round((Date.now() - Number(new Date(Iso))) / 60000);
    if (Minutes < 2) {
      Result = window.t("just now")}
     else if (Minutes < 60) {
      Result = window.tn(Minutes,"%d min ago","%d min ago")}
     else if (Minutes < (48 * 60)) {
      Result = window.tn(Math.round(Minutes / 60),"%d hours ago","%d hours ago")}
     else Result = window.tn(Math.round(Minutes / 1440),"%d days ago","%d days ago");
    return Result;
  };
  this.SizeText = function (N) {
    var Result = "";
    if (N < 1024) {
      Result = window.t("%d B",N)}
     else if (N < (1024 * 1024)) {
      Result = window.t("%d KB",Math.round(N / 1024))}
     else if (N < (1024 * 1024 * 1024)) {
      Result = window.t("%s MB",((N / 1024) / 1024).toFixed(1))}
     else if (N < (1024 * 1024 * 1024 * 1024)) {
      Result = window.t("%s GB",(((N / 1024) / 1024) / 1024).toFixed(1))}
     else Result = window.t("%s TB",((((N / 1024) / 1024) / 1024) / 1024).toFixed(2));
    return Result;
  };
  this.NearBottom = function (Box) {
    var Result = false;
    if (!Boolean(Box)) Box = $mod.Stream;
    Result = (Box.scrollHeight - Box.scrollTop - Box.clientHeight) < 160;
    return Result;
  };
  this.KeepPinned = function (Box) {
    Box.pinned = true;
    Box.addEventListener("scroll",function (E) {
      Box.pinned = !Boolean(Box.noPin) && ($mod.NearBottom(Box) || (Box.scrollTop === Box.pinTop));
      Box.pinTop = -1;
    });
    $mod.PinWatch.observe(Box);
  };
  this.Enc = function (Value) {
    var Result = "";
    Result = encodeURIComponent(Value);
    return Result;
  };
  this.LoadMe = async function () {
    var Result = undefined;
    var Got = null;
    Got = await $mod.Get("/api/me");
    $mod.Me.avatar = Got["avatar"];
    $mod.Me.can = Got["can"];
    $mod.Me.away = Got["away"];
    $mod.Me.ignores = Got["ignores"];
    $mod.Me.wrapped = Got["wrapped"];
    $mod.Me.verified = Got["verified"];
    $mod.Me.email = Got["email"];
    $mod.Me.mailNotes = Got["mail_notes"];
    $mod.Me["autoAway"] = Got["auto_away"];
    $mod.Me.mailHours = Got["mail_hours"];
    $mod.Me.readReceipts = Got["read_receipts"];
    $mod.Me.prefs = Got["prefs"];
    $mod.Me.password = Got["password"];
    $mod.Me.closedNames = Got["closed_names"];
    if (Boolean(Got["reactions"])) $mod.Me.reactions = Got["reactions"];
    return Result;
  };
  this.StartHelpers = function () {
    var Name = undefined;
    var Lang = undefined;
    $mod.Body = document.body;
    Name = $mod.Body.dataset["me"];
    if (!Boolean(Name)) Name = "";
    $mod.Me = pas.JS.New(["name",Name,"can",new Array(),"ignores",new Array(),"reactions",pas.JS.New(["shown",new Array(),"more",new Array()])]);
    $mod.SiteName = $mod.Body.dataset["site"];
    $mod.Stream = $mod.Find("#stream",undefined);
    $mod.Panel = $mod.Find("#panel",undefined);
    $mod.S = pas.JS.New(["view","","room","","info",null,"messages",new Map(),"since",0,"lastRead",0,"divider",0,"oldest",Infinity,"older",true,"thread",0,"threadMessages",new Map(),"generation",0,"rooms",new Array(),"dms",new Array(),"commands",null,"typingSent",0,"tick",0,"alerts",new Object(),"dm","","dmLast",0,"dmFirst",0,"dmTimer",0,"beams",new Object(),"typers",new Object(),"here",new Array()]);
    $mod.SideEl = window.Side["el"];
    $mod.SideLink = window.Side["link"];
    $mod.SideAvatar = window.Side["avatar"];
    $mod.Icons = window.Side["icons"];
    $mod.SideIcon = window.Side["icon"];
    $mod.SideIconButton = window.Side["iconButton"];
    $mod.KeysPost = window.Keys["post"];
    $mod.Trail = new Array();
    window.addEventListener("error",function (E) {
      $mod.Remember("error: " + ("" + E["message"]) + " (" + ("" + E["filename"]) + ":" + ("" + E["lineno"]) + ")");
    });
    window.addEventListener("unhandledrejection",function (E) {
      var Reason = undefined;
      Reason = E["reason"];
      if (Boolean(Reason) && Boolean(Reason["message"])) Reason = Reason["message"];
      $mod.Remember("promise: " + ("" + Reason));
    });
    try {
      Lang = document.documentElement["lang"];
      if (!Boolean(Lang)) Lang = "";
      $mod.Locale = Intl.getCanonicalLocales(Lang)[0];
    } catch ($e) {
    };
    $mod.PinWatch = new ResizeObserver($impl.Watched);
    $mod.KeepPinned($mod.Stream);
    if (Boolean(window.visualViewport)) {
      window.visualViewport.addEventListener("resize",$impl.FitShown);
      window.visualViewport.addEventListener("scroll",$impl.FitShown);
      $impl.FitShown(null);
    };
  };
  $mod.$implcode = function () {
    $impl.Watched = function (Entries) {
      var I = 0;
      var Target = null;
      var Box = null;
      for (var $l = 0, $end = Entries.length - 1; $l <= $end; $l++) {
        I = $l;
        Target = Entries[I]["target"];
        if (Reflect.has(Target,"pinned")) {
          Box = Target}
         else Box = Target.parentNode;
        if (!Target.isConnected) {
          $mod.PinWatch.unobserve(Target)}
         else if (Boolean(Box.pinned) && !Boolean(Box.noPin)) {
          Box.scrollTop = Box.scrollHeight;
          Box.pinTop = Box.scrollTop;
        };
      };
    };
    $impl.FitShown = function (E) {
      var View = null;
      var Root = null;
      View = window.visualViewport;
      Root = document.documentElement;
      if ((Math.abs(View.scale - 1) < 0.01) && (View.height < (Root.clientHeight - 1))) {
        Root.style.setProperty("--shown-height","" + View.height + "px");
        Root.style.setProperty("--shown-top","" + View.offsetTop + "px");
      } else {
        Root.style.removeProperty("--shown-height");
        Root.style.removeProperty("--shown-top");
      };
    };
  };
},[]);
rtl.module("app_profile",["System","JS","Web","weborworker","app_helpers"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  this.OpenProfile = async function (Name) {
    var Result = undefined;
    var Generation = 0;
    var I = 0;
    var Who = null;
    var P = null;
    var Head = null;
    var Menu = null;
    var Card = null;
    var Face = null;
    var About = null;
    var Line = null;
    var Bio = null;
    var Links = null;
    var A = null;
    var Tools = null;
    var Edit = null;
    var Pic = null;
    var Input = null;
    var List = null;
    async function Chosen(E) {
      var Form = null;
      Form = new FormData();
      Form.append("avatar","1");
      Form.append("file",Input.files[0]);
      try {
        await pas.app_helpers.Post("/api/upload",Form);
        pas.app_router.Route(window.SiteBase.path(),false);
      } catch ($e) {
        pas.app_helpers.Failed($e);
      };
    };
    Generation = pas.app_helpers.S.generation;
    Who = await pas.app_helpers.Get("/api/user?name=" + pas.app_helpers.Enc(Name));
    if (Generation !== pas.app_helpers.S.generation) return Result;
    pas.app_helpers.S.title = Who["name"];
    Head = pas.app_helpers.Find("#roomhead",undefined);
    Menu = pas.app_helpers.IconButton("menu",window.t("Channels"),"menubtn");
    Menu.addEventListener("click",function (E) {
      pas.app_router.ToggleMenu();
    });
    Head.append(Menu,pas.app_helpers.El("div","titles",undefined));
    pas.app_helpers.Find(".titles",Head).appendChild(pas.app_helpers.El("h1","",Who["name"]));
    Card = pas.app_helpers.El("section","profile",undefined);
    Face = pas.app_helpers.Avatar(Who["name"],Who["avatar"],"big");
    Card.appendChild(Face);
    About = pas.app_helpers.El("div","about",undefined);
    Line = pas.app_helpers.El("h2","",Who["name"]);
    if (Boolean(Who["badge"])) Line.appendChild(pas.app_helpers.El("span","role",Who["badge"]));
    if (Boolean(Who["banned"])) Line.appendChild(pas.app_helpers.El("span","role",window.t("banned")));
    About.appendChild(Line);
    if (Boolean(Who["away"])) About.appendChild(pas.app_helpers.El("p","away",window.t("Away: %s",Who["away"])));
    if (Boolean(Who["closed"])) {
      About.appendChild(pas.app_helpers.El("p","seen",window.t("Former member")))}
     else if (Boolean(Who["seen"])) {
      About.appendChild(pas.app_helpers.El("p","seen",window.t("Joined %s · last here %s",window.dateText(Who["joined"]),pas.app_helpers.Ago(Who["seen"]))))}
     else About.appendChild(pas.app_helpers.El("p","seen",window.t("Joined %s",window.dateText(Who["joined"]))));
    Bio = pas.app_helpers.El("div","bio",undefined);
    Bio.innerHTML = Who.bio_html;   // safe html: rendered by the server, HTML escaped;
    About.appendChild(Bio);
    if (Boolean(Who["links"])) {
      Links = pas.app_helpers.El("p","links",undefined);
      List = Who["links"].split(new RegExp("\\s+"));
      for (var $l = 0, $end = List.length - 1; $l <= $end; $l++) {
        I = $l;
        if ((new RegExp("^https?:\\/\\/")).test("" + List[I])) {
          A = pas.app_helpers.Link(List[I],"",List[I].replace(new RegExp("^https?:\\/\\/"),""));
          A.rel = "nofollow ugc me";
          A.target = "_blank";
          Links.appendChild(A);
        };
      };
      About.appendChild(Links);
    };
    Tools = pas.app_helpers.El("div","tools",undefined);
    if (!Boolean(Who["closed"])) {
      I = 0;
      while (I < pas.app_router.Parts.length) {
        P = pas.app_router.Parts[I];
        if (Boolean(P["profileTools"])) P["profileTools"].call(P,Who,Tools);
        I += 1;
      };
    };
    if (Object.is(pas.app_helpers.Me.name,Who["name"])) {
      Edit = pas.app_helpers.El("button","",window.t("Edit profile"));
      Edit.type = "button";
      Edit.addEventListener("click",function (E) {
        $impl.EditProfile(Who,About);
      });
      Tools.appendChild(Edit);
      Pic = pas.app_helpers.El("button","",window.t("Change picture"));
      Pic.type = "button";
      Input = pas.app_helpers.El("input",undefined,undefined);
      Input.type = "file";
      Input.accept = "image/*";
      Input.hidden = true;
      Pic.addEventListener("click",function (E) {
        Input.click();
      });
      Input.addEventListener("change",Chosen);
      Tools.append(Pic,Input);
    };
    About.appendChild(Tools);
    Card.appendChild(About);
    pas.app_helpers.Find("#card",undefined).appendChild(Card);
    if (Object.is(pas.app_helpers.Me.name,Who["name"])) pas.app_helpers.Find("#card",undefined).append($impl.PrefsBox(),$impl.AccountBox(),$impl.SignInsBox());
    if (Object.is(pas.app_helpers.Me.name,Who["name"]) && pas.app_helpers.May("api-tokens")) pas.app_helpers.Find("#card",undefined).appendChild($impl.TokensBox());
    I = 0;
    while (I < pas.app_router.Parts.length) {
      P = pas.app_router.Parts[I];
      if (Boolean(P["profile"])) await P["profile"].call(P,Who,Generation);
      I += 1;
    };
    return Result;
  };
  this.ConfirmBox = function () {
    var Result = null;
    var Form = null;
    var Email = null;
    var Again = null;
    async function Submit(E) {
      E.preventDefault();
      try {
        pas.app_helpers.Toast(await pas.app_helpers.Post("/api/verify",pas.JS.New(["email",Email.value.trim()])),undefined);
      } catch ($e) {
        pas.app_helpers.Failed($e);
      };
    };
    Form = pas.app_helpers.El("form","confirmbox",undefined);
    Email = pas.app_helpers.El("input",undefined,undefined);
    Email.type = "email";
    Email.placeholder = window.t("A different address (or leave it)");
    Again = pas.app_helpers.El("button","primary",window.t("Send the link again"));
    Form.append(pas.app_helpers.El("p","notice",window.t("Confirm your email to talk: open the link we mailed you. It can take a minute, and it may be in the spam folder.")),Email,Again);
    Form.addEventListener("submit",Submit);
    Result = Form;
    return Result;
  };
  this.Shared = function (Key, Value) {
    var Result = "";
    var Kept = undefined;
    try {
      if (typeof(Value) === "undefined") {
        Kept = localStorage.getItem(Key);
        if (Boolean(Kept)) {
          Result = "" + Kept}
         else Result = "";
        return Result;
      };
      localStorage.setItem(Key,Value);
    } catch ($e) {
    };
    Result = "";
    return Result;
  };
  this.StartAway = function () {
    var Kinds = null;
    var I = 0;
    $impl.LastTouch = Date.now();
    Kinds = new Array("keydown","pointerdown","wheel");
    for (var $l = 0, $end = Kinds.length - 1; $l <= $end; $l++) {
      I = $l;
      document.addEventListener("" + Kinds[I],$impl.Touched,pas.JS.New(["capture",true,"passive",true]));
    };
    window.setInterval(function () {
      var Last = 0.0;
      Last = Number($mod.Shared("touched",undefined));
      if (!Boolean(Last)) Last = 0;
      Last = Math.max($impl.LastTouch,Last);
      if (Boolean(pas.app_helpers.Me.name) && (pas.app_helpers.Me.autoAway > 0) && ($mod.Shared("idle",undefined) !== "1") && ((Date.now() - Last) >= (pas.app_helpers.Me.autoAway * 60000))) {
        $mod.Shared("idle","1");
        pas.app_helpers.Post("/api/prefs",pas.JS.New(["idle","1"])).catch($impl.Nothing);
      };
    },30000);
  };
  $mod.$implcode = function () {
    $impl.LastTouch = 0.0;
    $impl.OneOrZero = function (Value) {
      var Result = "";
      if (Boolean(Value)) {
        Result = "1"}
       else Result = "0";
      return Result;
    };
    $impl.PasswordInput = function (Words, Fresh) {
      var Result = null;
      Result = pas.app_helpers.El("input",undefined,undefined);
      Result.type = "password";
      Result.placeholder = Words;
      if (Fresh) {
        Result.autocomplete = "new-password"}
       else Result.autocomplete = "current-password";
      Result.required = true;
      return Result;
    };
    $impl.LeaveBox = function () {
      var Result = null;
      var Box = null;
      var Form = null;
      var Anonymous = null;
      var Mark = null;
      var Proof = null;
      var Named = false;
      var Words = "";
      async function Submit(E) {
        var Fields = null;
        E.preventDefault();
        if (!window.confirm(window.t("Close your account for good?"))) return;
        try {
          Fields = pas.JS.New(["anonymous",$impl.OneOrZero(Anonymous.checked)]);
          if (Boolean(pas.app_helpers.Me.password)) {
            Fields["current"] = await window.Keys.passwordProof(pas.app_helpers.Me.name,Proof.value)}
           else Fields["name"] = Proof.value.trim();
          await pas.app_helpers.Post("/api/close",Fields);
          try {
            await window.Keys.signOut();
          } catch ($e) {
          };
          window.location.href = window.SiteBase.url("/");
        } catch ($e) {
          pas.app_helpers.Failed($e);
        };
      };
      Box = pas.app_helpers.El("details","leave",undefined);
      Box.appendChild(pas.app_helpers.El("summary","",window.t("Close this account")));
      Named = !Object.is(pas.app_helpers.Me.closedNames,"anonymous");
      Words = window.t("Closing your account signs you out everywhere, for good. Your email address, password, picture and profile are wiped, and nobody else can take your name.") + " ";
      if (Named) {
        Words = Words + window.t("What you wrote here stays, under your name unless you tick the box.")}
       else Words = Words + window.t('What you wrote here stays, shown as written by "Former member".');
      Words = Words + " " + window.t("Where others quoted or mentioned you, your name stays as they typed it. Only an admin can open a closed account again.");
      Box.appendChild(pas.app_helpers.El("p","hint",Words));
      Form = pas.app_helpers.El("form","invite",undefined);
      Anonymous = pas.app_helpers.El("input",undefined,undefined);
      Anonymous.type = "checkbox";
      if (Named) {
        Mark = pas.app_helpers.El("label",undefined,undefined);
        Mark.append(Anonymous,pas.app_helpers.El("span","",window.t('Show "Former member" in place of my name on what I wrote')));
        Form.appendChild(Mark);
      };
      if (Boolean(pas.app_helpers.Me.password)) {
        Proof = $impl.PasswordInput(window.t("Your password"),false)}
       else Proof = pas.app_helpers.El("input",undefined,undefined);
      if (!Boolean(pas.app_helpers.Me.password)) {
        Proof.placeholder = window.t("Type your name, %s, to confirm",pas.app_helpers.Me.name);
        Proof.required = true;
      };
      Form.append(Proof,pas.app_helpers.El("button","primary",window.t("Close my account")));
      Form.addEventListener("submit",Submit);
      Box.appendChild(Form);
      Result = Box;
      return Result;
    };
    $impl.AccountBox = function () {
      var Result = null;
      var Box = null;
      var Address = null;
      var Email = null;
      var Pass = null;
      var Form = null;
      var Old = null;
      var Fresh = null;
      async function Done(Words) {
        var Result = undefined;
        await pas.app_helpers.LoadMe();
        pas.app_helpers.Toast(Words,undefined);
        pas.app_router.Route(window.SiteBase.path(),false);
        return Result;
      };
      async function ChangeAddress(E) {
        var Fields = null;
        E.preventDefault();
        try {
          Fields = pas.JS.New(["email",Email.value.trim()]);
          if (Boolean(Pass)) Fields["current"] = await window.Keys.passwordProof(pas.app_helpers.Me.name,Pass.value);
          await Done(await pas.app_helpers.Post("/api/email",Fields));
        } catch ($e) {
          pas.app_helpers.Failed($e);
        };
      };
      async function ChangePassword(E) {
        E.preventDefault();
        try {
          if (Boolean(Old)) {
            await window.Keys.changePassword(pas.app_helpers.Me.name,Old.value,Fresh.value,pas.app_helpers.Me.wrapped)}
           else await window.Keys.setupKeys(pas.app_helpers.Me.name,Fresh.value);
          if (Boolean(Old)) {
            await Done(window.t("Your password is changed. Your other devices and apps are signed out."))}
           else await Done(window.t("Saved."));
        } catch ($e) {
          pas.app_helpers.Failed($e);
        };
      };
      Box = pas.app_helpers.El("details","tokens",undefined);
      Box.appendChild(pas.app_helpers.El("summary","",window.t("Email and password")));
      if (Object.is(pas.app_helpers.Me.verified,false)) {
        Box.open = true;
        Box.appendChild($mod.ConfirmBox());
      } else {
        Address = pas.app_helpers.El("form","invite",undefined);
        Email = pas.app_helpers.El("input",undefined,undefined);
        Email.type = "email";
        if (Boolean(pas.app_helpers.Me.email)) {
          Email.value = pas.app_helpers.Me.email}
         else Email.value = "";
        Email.placeholder = window.t("Email address");
        if (Boolean(pas.app_helpers.Me.password)) {
          Pass = $impl.PasswordInput(window.t("Your password"),false)}
         else Pass = null;
        Address.append(Email);
        if (Boolean(Pass)) Address.append(Pass);
        Address.append(pas.app_helpers.El("button","primary",window.t("Change the address")));
        Address.addEventListener("submit",ChangeAddress);
        Box.appendChild(Address);
      };
      Form = pas.app_helpers.El("form","invite",undefined);
      if (Boolean(pas.app_helpers.Me.password)) {
        Old = $impl.PasswordInput(window.t("Your password"),false)}
       else Old = null;
      Fresh = $impl.PasswordInput(window.t("New password, 8 characters or more"),true);
      if (Boolean(Old)) {
        Form.append(Old)}
       else Box.appendChild(pas.app_helpers.El("p","hint",window.t("This account has no password yet. With one you can also sign in here with your name.")));
      if (Boolean(Old)) {
        Form.append(Fresh,pas.app_helpers.El("button","primary",window.t("Change the password")))}
       else Form.append(Fresh,pas.app_helpers.El("button","primary",window.t("Set a password")));
      Form.addEventListener("submit",ChangePassword);
      Box.appendChild(Form);
      Box.appendChild($impl.LeaveBox());
      Result = Box;
      return Result;
    };
    $impl.PrefsBox = function () {
      var Result = null;
      var Box = null;
      var Mail = null;
      var Check = null;
      var Hint = null;
      var Away = null;
      var After = null;
      var Receipts = null;
      var Shown = null;
      var List = null;
      var I = 0;
      function Option(Minutes, Words) {
        var O = null;
        O = pas.app_helpers.El("option","",Words);
        O.value = Minutes;
        After.appendChild(O);
      };
      async function MailChanged(E) {
        try {
          await pas.app_helpers.Post("/api/prefs",pas.JS.New(["mail_notes",$impl.OneOrZero(Check.checked)]));
          pas.app_helpers.Me.mailNotes = Check.checked;
          pas.app_helpers.Toast(window.t("Saved."),undefined);
        } catch ($e) {
          Check.checked = pas.app_helpers.Me.mailNotes;
          pas.app_helpers.Failed($e);
        };
      };
      async function AwayChanged(E) {
        try {
          await pas.app_helpers.Post("/api/prefs",pas.JS.New(["auto_away",After.value]));
          pas.app_helpers.Me.autoAway = Number(After.value);
          pas.app_helpers.Toast(window.t("Saved."),undefined);
        } catch ($e) {
          After.value = pas.app_helpers.Me.autoAway;
          pas.app_helpers.Failed($e);
        };
      };
      function ModulePref(Pref) {
        var Line = null;
        var Mark = null;
        async function Changed(E) {
          var Sent = null;
          Sent = new Object();
          Sent["" + Pref["name"]] = $impl.OneOrZero(Mark.checked);
          try {
            await pas.app_helpers.Post("/api/prefs",Sent);
            Pref["on"] = Mark.checked;
            pas.app_helpers.Toast(window.t("Saved."),undefined);
          } catch ($e) {
            Mark.checked = Pref["on"];
            pas.app_helpers.Failed($e);
          };
        };
        Line = pas.app_helpers.El("label",undefined,undefined);
        Mark = pas.app_helpers.El("input",undefined,undefined);
        Mark.type = "checkbox";
        Mark.checked = Pref["on"];
        Line.append(Mark,pas.app_helpers.El("span","",Pref["words"]));
        Mark.addEventListener("change",Changed);
        Box.appendChild(Line);
      };
      async function ReceiptsChanged(E) {
        try {
          await pas.app_helpers.Post("/api/dm/receipts",pas.JS.New(["on",$impl.OneOrZero(Shown.checked)]));
          pas.app_helpers.Me.readReceipts = Shown.checked;
          pas.app_helpers.Toast(window.t("Saved."),undefined);
        } catch ($e) {
          Shown.checked = pas.app_helpers.Me.readReceipts;
          pas.app_helpers.Failed($e);
        };
      };
      Box = pas.app_helpers.El("section","prefs",undefined);
      Mail = pas.app_helpers.El("label",undefined,undefined);
      Check = pas.app_helpers.El("input",undefined,undefined);
      Check.type = "checkbox";
      Check.checked = pas.app_helpers.Me.mailNotes;
      Mail.append(Check,pas.app_helpers.El("span","",window.t("Email me about private messages and mentions I miss")));
      if (Boolean(pas.app_helpers.Me.email)) {
        Hint = pas.app_helpers.El("p","hint",window.tn(pas.app_helpers.Me.mailHours,"To %1:s, at most one every %0:d hours, and only when something new waits for you.","To %1:s, at most one every %0:d hours, and only when something new waits for you.",pas.app_helpers.Me.email))}
       else Hint = pas.app_helpers.El("p","hint",window.t("Your account has no email address."));
      Check.disabled = !Boolean(pas.app_helpers.Me.email);
      Away = pas.app_helpers.El("label",undefined,undefined);
      After = pas.app_helpers.El("select",undefined,undefined);
      Option(0,window.t("never"));
      Option(5,window.tn(5,"after %d minutes","after %d minutes"));
      Option(10,window.tn(10,"after %d minutes","after %d minutes"));
      Option(15,window.tn(15,"after %d minutes","after %d minutes"));
      Option(30,window.tn(30,"after %d minutes","after %d minutes"));
      Option(60,window.t("after an hour"));
      After.value = pas.app_helpers.Me.autoAway;
      Away.append(pas.app_helpers.El("span","",window.t("Show me as away when I have not touched the chat")),After);
      Check.addEventListener("change",MailChanged);
      After.addEventListener("change",AwayChanged);
      Box.append(Mail,Hint);
      if (Boolean(pas.app_helpers.Me.prefs)) {
        List = pas.app_helpers.Me.prefs}
       else List = new Array();
      for (var $l = 0, $end = List.length - 1; $l <= $end; $l++) {
        I = $l;
        ModulePref(List[I]);
      };
      Box.appendChild(Away);
      if (typeof(pas.app_helpers.Me.readReceipts) !== "undefined") {
        Receipts = pas.app_helpers.El("label",undefined,undefined);
        Shown = pas.app_helpers.El("input",undefined,undefined);
        Shown.type = "checkbox";
        Shown.checked = pas.app_helpers.Me.readReceipts;
        Receipts.append(Shown,pas.app_helpers.El("span","",window.t("Show others when I have read their private messages")));
        Shown.addEventListener("change",ReceiptsChanged);
        Box.append(Receipts,pas.app_helpers.El("p","hint",window.t("With this off, you do not see when others have read yours either. It shows only between two members who both have it on.")));
      };
      Result = Box;
      return Result;
    };
    $impl.Nothing = function (Err) {
      var Result = undefined;
      return Result;
    };
    $impl.Touched = function (E) {
      if ((Date.now() - $impl.LastTouch) < 10000) return;
      $impl.LastTouch = Date.now();
      $mod.Shared("touched",String($impl.LastTouch));
      if (Boolean(pas.app_helpers.Me.name) && ($mod.Shared("idle",undefined) === "1")) {
        $mod.Shared("idle","0");
        pas.app_helpers.Post("/api/prefs",pas.JS.New(["idle","0"])).catch($impl.Nothing);
      };
    };
    $impl.SignInsBox = function () {
      var Result = null;
      var Box = null;
      var List = null;
      async function Show() {
        var Result = undefined;
        var Logins = null;
        var Providers = null;
        var I = 0;
        function Provider(P) {
          var Row = null;
          var X = null;
          async function Unlink(E) {
            try {
              await pas.app_helpers.Post("/api/logins",pas.JS.New(["unlink",P["name"]]));
              Show();
            } catch ($e) {
              pas.app_helpers.Failed($e);
            };
          };
          Row = pas.app_helpers.El("div","person",undefined);
          Row.appendChild(pas.app_helpers.El("b","",P["title"]));
          if (Boolean(P["login"])) {
            Row.appendChild(pas.app_helpers.El("span","dim",window.t("linked as %s",P["login"])));
            X = pas.app_helpers.El("button","small-link",window.t("Unlink"));
            X.type = "button";
            X.addEventListener("click",Unlink);
            Row.appendChild(X);
          } else Row.appendChild(pas.app_helpers.Link("/signin-with/" + ("" + P["name"]),"small-link",window.t("Link")));
          List.appendChild(Row);
        };
        Logins = await pas.app_helpers.Get("/api/logins");
        Providers = Logins["providers"];
        Box.hidden = Providers.length === 0;
        List.replaceChildren();
        for (var $l = 0, $end = Providers.length - 1; $l <= $end; $l++) {
          I = $l;
          Provider(Providers[I]);
        };
        return Result;
      };
      Box = pas.app_helpers.El("details","tokens",undefined);
      Box.hidden = true;
      Box.appendChild(pas.app_helpers.El("summary","",window.t("Sign in with GitHub, GitLab and others")));
      List = pas.app_helpers.El("div","tokenlist",undefined);
      Box.appendChild(List);
      Show().catch(function (Err) {
        var Result = undefined;
        pas.app_helpers.Failed(Err);
        return Result;
      });
      Result = Box;
      return Result;
    };
    $impl.TokensBox = function () {
      var Result = null;
      var Box = null;
      var List = null;
      var Form = null;
      var Name = null;
      var Make = null;
      async function Show() {
        var Result = undefined;
        var Tokens = null;
        var I = 0;
        function Token(Tok) {
          var Row = null;
          var X = null;
          var Title = undefined;
          async function TakeBack(E) {
            try {
              await pas.app_helpers.Post("/api/tokens",pas.JS.New(["delete",Tok["id"]]));
              Show();
            } catch ($e) {
              pas.app_helpers.Failed($e);
            };
          };
          Row = pas.app_helpers.El("div","person",undefined);
          Title = Tok["name"];
          if (!Boolean(Title)) Title = Tok["kind"];
          Row.append(pas.app_helpers.El("b","",Title),pas.app_helpers.El("span","dim",window.t("%s, made %s",Tok["kind"],pas.app_helpers.Ago(Tok["created"]))));
          X = pas.app_helpers.El("button","small-link",window.t("Take back"));
          X.type = "button";
          X.addEventListener("click",TakeBack);
          Row.appendChild(X);
          List.appendChild(Row);
        };
        Tokens = await pas.app_helpers.Get("/api/tokens");
        List.replaceChildren();
        if (Tokens.length === 0) List.appendChild(pas.app_helpers.El("p","dim",window.t("None yet. Apps you signed in to show here too.")));
        for (var $l = 0, $end = Tokens.length - 1; $l <= $end; $l++) {
          I = $l;
          Token(Tokens[I]);
        };
        return Result;
      };
      async function Submit(E) {
        var Made = null;
        var Fresh = null;
        E.preventDefault();
        try {
          Made = JSON.parse(await pas.app_helpers.Post("/api/tokens",pas.JS.New(["name",Name.value])));
          Fresh = pas.app_helpers.El("pre","newtoken",Made["token"]);
          Form.after(Fresh);
          Form.after(pas.app_helpers.El("p","hint",window.t("Copy it now; it is not shown again. Send it as Authorization: Bearer followed by the token. Anyone holding it can talk as you, so keep it secret.")));
          Name.value = "";
          Show();
        } catch ($e) {
          pas.app_helpers.Failed($e);
        };
      };
      Box = pas.app_helpers.El("details","tokens",undefined);
      Box.appendChild(pas.app_helpers.El("summary","",window.t("Tokens for bots and scripts")));
      List = pas.app_helpers.El("div","tokenlist",undefined);
      Box.addEventListener("toggle",function (E) {
        if (Boolean(Box.open)) Show().catch(function (Err) {
          var Result = undefined;
          pas.app_helpers.Failed(Err);
          return Result;
        });
      });
      Form = pas.app_helpers.El("form","invite",undefined);
      Name = pas.app_helpers.El("input",undefined,undefined);
      Name.placeholder = window.t("What will use it, such as my-bot");
      Make = pas.app_helpers.El("button","primary",window.t("Make a token"));
      Form.append(Name,Make);
      Form.addEventListener("submit",Submit);
      Box.append(List,Form);
      Result = Box;
      return Result;
    };
    $impl.EditProfile = function (Who, Box) {
      var Form = null;
      var Bio = null;
      var Links = null;
      var Save = null;
      async function Submit(E) {
        E.preventDefault();
        try {
          await pas.app_helpers.Post("/api/profile",pas.JS.New(["bio",Bio.value,"links",Links.value]));
          pas.app_router.Route(window.SiteBase.path(),false);
        } catch ($e) {
          pas.app_helpers.Failed($e);
        };
      };
      Form = pas.app_helpers.El("form","editprofile",undefined);
      Bio = pas.app_helpers.El("textarea",undefined,undefined);
      Bio.value = Who["bio"];
      Bio.placeholder = window.t("A few words about you. Markdown works.");
      Links = pas.app_helpers.El("input",undefined,undefined);
      Links.value = Who["links"];
      Links.placeholder = window.t("Links, separated by spaces");
      Save = pas.app_helpers.El("button","primary",window.t("Save"));
      Form.append(Bio,Links,Save);
      Box.appendChild(Form);
      Form.addEventListener("submit",Submit);
    };
  };
},["app_router"]);
rtl.module("app_admin",["System","JS","Web","weborworker","app_helpers"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  this.LoadScript = function (Src) {
    var Result = undefined;
    if (!$impl.Scripts.has(Src)) $impl.Scripts.set(Src,new Promise(function (Resolve, Reject) {
      var Script = null;
      Script = pas.app_helpers.El("script",undefined,undefined);
      if (Object.is($impl.ScriptVersion,null)) {
        Script.src = "" + Src}
       else Script.src = "" + Src + "?v=" + pas.app_helpers.Enc($impl.ScriptVersion);
      Script.onload = Resolve;
      Script.onerror = function () {
        $impl.Scripts.delete(Src);
        Script.remove();
        Reject(new Error(window.t("Could not load %s.",Src)));
      };
      document.head.appendChild(Script);
    }));
    Result = $impl.Scripts.get(Src);
    return Result;
  };
  this.OpenAdmin = async function () {
    var Result = undefined;
    var Generation = 0;
    Generation = pas.app_helpers.S.generation;
    if (document.readyState === "loading") await new Promise(function (Resolve, Reject) {
      document.addEventListener("DOMContentLoaded",function (E) {
        Resolve(E);
      },pas.JS.New(["once",true]));
    });
    if (Generation !== pas.app_helpers.S.generation) return Result;
    try {
      await $mod.LoadScript("/static/admin.js");
    } catch ($e) {
      pas.app_helpers.Failed($e);
      return Result;
    };
    if (Generation !== pas.app_helpers.S.generation) return Result;
    await window.Chat.openAdmin();
    return Result;
  };
  this.SubTabs = function (Box, Id, List) {
    var Result = null;
    var Nav = null;
    var Tabs = null;
    var Current = undefined;
    var I = 0;
    var Holder = null;
    var Count = null;
    function Select(Key) {
      var K = "";
      var B = null;
      if (!Boolean(Tabs["" + Key])) Key = List[0]["key"];
      for (K in Tabs) {
        Tabs[K].button.classList.toggle("on",Object.is(K,Key));
        if (Object.is(K,Key)) {
          Tabs[K].button.setAttribute("aria-selected","true")}
         else Tabs[K].button.setAttribute("aria-selected","false");
        Tabs[K].holder.hidden = !Object.is(K,Key);
      };
      Current = Key;
      try {
        localStorage.setItem("sub-" + ("" + Id),Key);
      } catch ($e) {
      };
      B = Tabs["" + Key].button;
      if (Boolean(B["scrollIntoView"]) && (Nav.scrollWidth > Nav.clientWidth)) B.scrollIntoView(pas.JS.New(["block","nearest","inline","nearest"]));
    };
    function Add(Tab) {
      var B = null;
      var Badge = null;
      var Part = null;
      B = pas.app_helpers.El("button","",Tab["title"]);
      B.type = "button";
      B.setAttribute("role","tab");
      Badge = pas.app_helpers.El("span","sub-count",undefined);
      Badge.hidden = true;
      B.appendChild(Badge);
      Part = pas.app_helpers.El("div","subpart",undefined);
      Part.setAttribute("role","tabpanel");
      Part.hidden = true;
      B.addEventListener("click",function (E) {
        Select(Tab["key"]);
      });
      Nav.appendChild(B);
      Box.appendChild(Part);
      Tabs["" + Tab["key"]] = pas.JS.New(["button",B,"holder",Part,"badge",Badge]);
    };
    Nav = pas.app_helpers.El("nav","subtabs",undefined);
    Nav.setAttribute("role","tablist");
    Box.appendChild(Nav);
    Tabs = new Object();
    Current = "";
    try {
      Current = localStorage.getItem("sub-" + ("" + Id));
      if (!Boolean(Current)) Current = "";
    } catch ($e) {
    };
    for (var $l = 0, $end = List.length - 1; $l <= $end; $l++) {
      I = $l;
      Add(List[I]);
    };
    Select(Current);
    Holder = function (Key) {
      var Result = null;
      Result = Tabs["" + Key].holder;
      return Result;
    };
    Count = function (Key, N) {
      var B = null;
      B = Tabs["" + Key].badge;
      B.hidden = !(N > 0);
      if (N > 0) {
        B.textContent = N.toLocaleString(pas.app_helpers.Locale)}
       else B.textContent = "";
    };
    Result = pas.JS.New(["holder",Holder,"select",Select,"count",Count]);
    return Result;
  };
  this.Waiting = function (Holder, Words) {
    var Result = null;
    Result = pas.app_helpers.El("p","lv-wait",undefined);
    if (!Boolean(Words)) Words = window.t("Loading…");
    Result.append(pas.app_helpers.El("span","lv-spinner",undefined)," " + ("" + Words));
    Holder.replaceChildren(Result);
    return Result;
  };
  this.Facts = function (Holder, Pairs) {
    var Result = null;
    var I = 0;
    var P = null;
    var Value = null;
    Result = pas.app_helpers.El("dl","lv-facts",undefined);
    for (var $l = 0, $end = Pairs.length - 1; $l <= $end; $l++) {
      I = $l;
      P = Pairs[I];
      if (Object.is(P[1],"") || Object.is(P[1],null) || (typeof(P[1]) === "undefined")) continue;
      Result.appendChild(pas.app_helpers.El("dt","",P[0]));
      Value = pas.app_helpers.El("dd",undefined,undefined);
      if (typeof(P[1]) === "object") {
        Value.appendChild(P[1])}
       else Value.textContent = String(P[1]);
      Result.appendChild(Value);
    };
    Holder.appendChild(Result);
    return Result;
  };
  this.Chip = function (Words, Cls) {
    var Result = null;
    if (Boolean(Cls)) {
      Result = pas.app_helpers.El("span","lv-chip " + ("" + Cls),Words)}
     else Result = pas.app_helpers.El("span","lv-chip",Words);
    return Result;
  };
  this.StartAdmin = function () {
    if (Boolean(document.currentScript)) {
      $impl.ScriptVersion = (new URLSearchParams(document.currentScript["src"].split("?")[1])).get("v")}
     else $impl.ScriptVersion = null;
    $impl.Scripts = new Map();
  };
  $mod.$implcode = function () {
    $impl.ScriptVersion = undefined;
    $impl.Scripts = null;
  };
},[]);
rtl.module("app_router",["System","JS","Web","app_helpers"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  this.Parts = null;
  this.Installed = false;
  this.LayerOpened = function () {
    if ($impl.LayerEntry) return;
    $impl.LayerEntry = true;
    window.history.pushState(new Object(),"",window.SiteBase.path());
  };
  this.LayerClosed = function (After) {
    if (!$impl.LayerEntry || $impl.OnTop()) {
      if (Boolean(After)) After.call(undefined);
      return;
    };
    $impl.LayerEntry = false;
    if (Boolean(After)) {
      $impl.AfterMove = After}
     else $impl.AfterMove = function () {
    };
    window.history.back();
  };
  this.ToggleMenu = function () {
    pas.app_helpers.Body.classList.toggle("menu");
    if (pas.app_helpers.Body.classList.contains("menu")) {
      $mod.LayerOpened()}
     else $mod.LayerClosed(undefined);
  };
  this.Route = async function (Path, Push) {
    var Result = undefined;
    var Pieces = null;
    var I = 0;
    var P = null;
    if (Path === "/") {
      Path = $impl.FirstRoom();
      if (Path === "/") {
        window.location.href = window.SiteBase.url("/");
        return Result;
      };
    };
    if ($impl.LayerEntry && Boolean(Push)) {
      $impl.LayerEntry = false;
      Result = new Promise(function (Done, Refuse) {
        $impl.AfterMove = function () {
          $mod.Route(Path,Push).then(Done);
        };
        window.history.back();
      });
      return Result;
    };
    if (Object.is(Push,"replace")) {
      window.history.replaceState(new Object(),"",Path)}
     else if (Boolean(Push)) window.history.pushState(new Object(),"",Path);
    $impl.Here = Path;
    $impl.ClearView();
    Pieces = Path.split("/").map(decodeURIComponent);
    try {
      if (Object.is(Pieces[1],"u")) {
        await pas.app_profile.OpenProfile(Pieces[2])}
       else if (Object.is(Pieces[1],"admin")) {
        await pas.app_admin.OpenAdmin()}
       else {
        I = 0;
        while (I < $mod.Parts.length) {
          P = $mod.Parts[I];
          if (Boolean(P["open"]) && Boolean(await P["open"].call(P,Pieces))) break;
          I += 1;
        };
      };
    } catch ($e) {
      pas.app_helpers.Stream.appendChild(pas.app_helpers.El("p","notice",$e["message"]));
    };
    $mod.RenderSide();
    return Result;
  };
  this.RenderSide = function () {
    var I = 0;
    var P = null;
    I = 0;
    while (I < $mod.Parts.length) {
      P = $mod.Parts[I];
      if (Boolean(P["sidebar"])) P["sidebar"].call(P);
      I += 1;
    };
  };
  this.SyncNow = function (WithRooms) {
    var I = 0;
    var P = null;
    I = 0;
    while (I < $mod.Parts.length) {
      P = $mod.Parts[I];
      if (Boolean(P["sync"])) P["sync"].call(P,WithRooms);
      I += 1;
    };
  };
  this.StartRouter = function () {
    document.addEventListener("click",function (E) {
      var A = null;
      var FromList = false;
      A = E.target.closest("a[href]");
      if (!Boolean(A) || Boolean(A["target"]) || E.ctrlKey || E.metaKey || E.shiftKey || (A.origin !== window.location.origin)) return;
      if (!$impl.IsAppPath(window.SiteBase.strip(A["pathname"]))) return;
      E.preventDefault();
      FromList = pas.app_helpers.Body.classList.contains("menu") && Boolean(A.closest("#side"));
      pas.app_helpers.Body.classList.remove("menu");
      if (FromList) {
        $mod.Route(window.SiteBase.strip(A["pathname"]),"replace")}
       else $mod.Route(window.SiteBase.strip(A["pathname"]),true);
    });
    window.Side.newTabLinks(".msg",true,function (A) {
      var Result = false;
      Result = A.classList.contains("shot") || $impl.IsAppPath(window.SiteBase.strip(A["pathname"]));
      return Result;
    });
    $impl.Narrow = window.matchMedia("(max-width: 860px)");
    document.addEventListener("click",function (E) {
      if (!pas.app_helpers.Body.classList.contains("menu") || Boolean(E.target.closest("#side, .menubtn"))) return;
      E.preventDefault();
      E.stopPropagation();
      pas.app_helpers.Body.classList.remove("menu");
      $mod.LayerClosed(undefined);
    },true);
    $mod.Installed = window.matchMedia("(display-mode: standalone)").matches;
    $impl.Here = window.SiteBase.path();
    document.addEventListener("pointerdown",function (E) {
      if (!$mod.Installed) return;
      if (!$impl.Guarded) {
        $impl.Guarded = true;
        window.history.replaceState(pas.JS.New(["guard",true]),"",window.SiteBase.path());
        window.history.pushState(new Object(),"",window.SiteBase.path());
      } else if (Boolean(history.state) && Boolean(history.state["guard"])) window.history.pushState(new Object(),"",$impl.Here);
    },true);
    window.addEventListener("popstate",function (E) {
      var After = undefined;
      if (Boolean($impl.AfterMove)) {
        After = $impl.AfterMove;
        $impl.AfterMove = null;
        After.call(undefined);
      } else if (Boolean(history.state) && Boolean(history.state["guard"])) {
        window.history.replaceState(pas.JS.New(["guard",true]),"",$impl.Here);
        pas.app_helpers.Toast(window.t("Press back again to leave"),undefined);
      } else if ($impl.LayerEntry) {
        $impl.LayerEntry = false;
        $impl.CloseTop();
        if ($impl.OnTop()) $mod.LayerOpened();
      } else $mod.Route(window.SiteBase.path(),false);
    });
    document.addEventListener("keydown",function (E) {
      var K = null;
      var Rooms = null;
      var I = 0;
      K = E;
      if (K.ctrlKey && (K.key === "k")) {
        E.preventDefault();
        if ($impl.Narrow.matches) {
          pas.app_helpers.Body.classList.add("menu");
          $mod.LayerOpened();
        };
        pas.app_helpers.Find("#jump",undefined).focus();
        return;
      };
      if (!K.altKey || ((K.key !== "ArrowUp") && (K.key !== "ArrowDown"))) return;
      Rooms = Array.from(document.querySelectorAll("#roomlist a.room"));
      if (Rooms.length === 0) return;
      E.preventDefault();
      I = Rooms.findIndex(function (A, Index, List) {
        var Result = false;
        Result = A.classList.contains("active");
        return Result;
      });
      if (K.key === "ArrowDown") {
        I = (I + 1) % Rooms.length}
       else I = ((I + Rooms.length) - 1) % Rooms.length;
      $mod.Route(window.SiteBase.strip(Rooms[I].getAttribute("href")),true);
    });
    $mod.Parts = new Array();
  };
  $mod.$implcode = function () {
    $impl.LayerEntry = false;
    $impl.AfterMove = null;
    $impl.Narrow = null;
    $impl.Guarded = false;
    $impl.Here = "";
    $impl.IsAppPath = function (Path) {
      var Result = false;
      Result = (new RegExp("^\\/(p|m|u|dm)\\/|^\\/(admin|chat-search)$")).test(Path);
      return Result;
    };
    $impl.OnTop = function () {
      var Result = false;
      Result = pas.app_helpers.Body.classList.contains("menu") || !pas.app_helpers.Panel.hidden || !pas.app_helpers.Find("#lightbox",undefined).hidden;
      return Result;
    };
    $impl.CloseTop = function () {
      if (!pas.app_helpers.Find("#lightbox",undefined).hidden) {
        pas.app_helpers.Find("#lightbox",undefined).hidden = true}
       else if (pas.app_helpers.Body.classList.contains("menu")) {
        pas.app_helpers.Body.classList.remove("menu")}
       else if (!pas.app_helpers.Panel.hidden) {
        pas.app_panel.ClosePanel();
        if (window.SiteBase.path().startsWith("/m/") && Boolean(pas.app_helpers.S.room)) window.history.replaceState(new Object(),"","/p/" + pas.app_helpers.Enc(pas.app_helpers.S.room));
      };
    };
    $impl.ClearView = function () {
      var AdminNav = null;
      pas.app_helpers.S.generation += 1;
      pas.app_helpers.S.view = "";
      pas.app_helpers.S.room = "";
      pas.app_helpers.S.info = null;
      pas.app_helpers.S.messages.clear();
      pas.app_helpers.S.thread = 0;
      pas.app_helpers.S.threadMessages.clear();
      pas.app_helpers.S.dm = "";
      pas.app_helpers.S.typers = new Object();
      window.clearTimeout(pas.app_helpers.S.dmTimer);
      pas.app_helpers.Stream.replaceChildren();
      pas.app_helpers.Stream.className = "";
      pas.app_helpers.Stream.noPin = false;
      pas.app_helpers.Find("#roomhead",undefined).replaceChildren();
      pas.app_helpers.Find("#card",undefined).replaceChildren();
      pas.app_helpers.Find("#typing",undefined).replaceChildren();
      pas.app_helpers.Find("#composer-area",undefined).replaceChildren();
      pas.app_helpers.Body.classList.remove("admin-view");
      AdminNav = pas.app_helpers.Find("#adminnav",undefined);
      if (Boolean(AdminNav)) AdminNav.hidden = true;
      pas.app_panel.ClosePanel();
    };
    $impl.FirstRoom = function () {
      var Result = "";
      var R = undefined;
      R = pas.app_helpers.S.rooms.find(function (X, Index, List) {
        var Result = false;
        Result = Object.is(X["kind"],"channel");
        return Result;
      });
      if (Boolean(R)) {
        Result = "/p/" + pas.app_helpers.Enc(R["slug"])}
       else Result = "/";
      return Result;
    };
  };
},["app_panel","app_profile","app_admin"]);
rtl.module("app_panel",["System","JS","Web","app_helpers"],function () {
  "use strict";
  var $mod = this;
  this.OpenPanel = function (Title, Cls) {
    var Result = null;
    var Head = null;
    var Close = null;
    pas.app_helpers.Body.classList.remove("menu");
    pas.app_helpers.Panel.hidden = false;
    if (Boolean(Cls)) {
      pas.app_helpers.Panel["className"] = Cls}
     else pas.app_helpers.Panel.className = "";
    pas.app_helpers.Panel.replaceChildren();
    Head = pas.app_helpers.El("header",undefined,undefined);
    Head.appendChild(pas.app_helpers.El("h2","",Title));
    Close = pas.app_helpers.IconButton("close",window.t("Close"),undefined);
    Close.addEventListener("click",function (E) {
      $mod.ClosePanel();
      if (window.SiteBase.path().startsWith("/m/") && Boolean(pas.app_helpers.S.room)) window.history.replaceState(new Object(),"","/p/" + pas.app_helpers.Enc(pas.app_helpers.S.room));
      pas.app_router.LayerClosed(undefined);
    });
    Head.appendChild(Close);
    pas.app_helpers.Panel.appendChild(Head);
    pas.app_helpers.Body.classList.add("withpanel");
    pas.app_router.LayerOpened();
    Result = pas.app_helpers.Panel;
    return Result;
  };
  this.OpenReport = function () {
    var Box = null;
    var Form = null;
    var Words = null;
    var Send = null;
    async function Submit(E) {
      var Lines = null;
      var Theme = undefined;
      var Name = undefined;
      var Where = "";
      E.preventDefault();
      Send.disabled = true;
      Send.textContent = window.t("Sending…");
      Words.disabled = true;
      Theme = document.documentElement.dataset["theme"];
      if (!Boolean(Theme)) Theme = "auto";
      Name = pas.app_helpers.Me.name;
      if (!Boolean(Name)) Name = "no";
      if (pas.app_router.Installed) {
        Where = ", installed app"}
       else Where = ", browser tab";
      Lines = new Array();
      Lines.push("browser: " + window.navigator.userAgent);
      Lines.push("screen: " + ("" + window.innerWidth) + "x" + ("" + window.innerHeight) + " at " + ("" + window.devicePixelRatio));
      Lines.push("theme: " + ("" + Theme));
      Lines.push("signed in: " + ("" + Name));
      Lines.push("notifications: " + pas.app_notify.NotifyState() + Where);
      Lines.push("last errors:");
      if (pas.app_helpers.Trail.length > 0) {
        Lines = Lines.concat(pas.app_helpers.Trail)}
       else Lines = Lines.concat(new Array("none"));
      try {
        pas.app_helpers.Toast(await pas.app_helpers.Post("/api/bug",pas.JS.New(["text",Words.value,"page",window.SiteBase.path(),"info",Lines.join("\n")])),undefined);
        $mod.ClosePanel();
        pas.app_router.LayerClosed(undefined);
      } catch ($e) {
        pas.app_helpers.Failed($e);
      };
      Send.disabled = false;
      Send.textContent = window.t("Send the report");
      Words.disabled = false;
    };
    Box = $mod.OpenPanel(window.t("Report a problem"),"report");
    Form = pas.app_helpers.El("form","reportform",undefined);
    Words = pas.app_helpers.El("textarea",undefined,undefined);
    Words.rows = 8;
    Words.maxLength = 4000;
    Words.placeholder = window.t("What went wrong, or what looked wrong? What were you doing?");
    Send = pas.app_helpers.El("button","primary",window.t("Send the report"));
    Form.append(Words,pas.app_helpers.El("p","hint",window.t("Sent along: this page's address, your browser and screen size, and the last errors this page showed. Nothing else.")),Send);
    Form.addEventListener("submit",Submit);
    Box.appendChild(Form);
    Words.focus();
  };
  this.ClosePanel = function () {
    pas.app_helpers.Panel.hidden = true;
    pas.app_helpers.Panel.replaceChildren();
    pas.app_helpers.S.thread = 0;
    pas.app_helpers.S.threadMessages.clear();
    pas.app_helpers.Body.classList.remove("withpanel");
  };
},["app_router","app_notify"]);
rtl.module("app_account",["System","JS","Web","app_helpers"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  this.RenderAccount = function () {
    var Tools = null;
    var Report = null;
    var Install = null;
    async function Accept(E) {
      pas.app_notify.InstallOffer.prompt();
      await pas.app_notify.InstallOffer.userChoice;
      pas.app_notify.InstallOffer = null;
      $mod.RenderAccount();
    };
    Tools = new Array();
    Report = pas.app_helpers.IconButton("bug",window.t("Report a problem"),undefined);
    Report.addEventListener("click",function (E) {
      pas.app_panel.OpenReport();
    });
    Tools.push(Report);
    if (Boolean(pas.app_notify.InstallOffer)) {
      Install = pas.app_helpers.IconButton("install",window.t("Install the app"),undefined);
      Install.addEventListener("click",Accept);
      Tools.push(Install);
    };
    if (Boolean(pas.app_helpers.Me.name)) Tools.push(pas.app_notify.BellButton());
    window.Side.account(pas.JS.New(["name",pas.app_helpers.Me.name,"avatar",pas.app_helpers.Me.avatar,"admin",$impl.MayAdmin(),"tools",Tools,"links",pas.app_helpers.Extras.accountLinks,"unconfirmed",Object.is(pas.app_helpers.Me.verified,false)]));
  };
  this.JoinForm = function (Caption) {
    var Result = null;
    var Form = null;
    var Name = null;
    var Pass = null;
    var Go = null;
    var Row = null;
    var A = null;
    var Others = null;
    var Titles = null;
    var I = 0;
    async function Submit(E) {
      E.preventDefault();
      Go.disabled = true;
      Go.textContent = window.t("One moment");
      if (Boolean(await window.Keys.joinFrom(Form,pas.app_helpers.Failed))) location.reload();
      Go.disabled = false;
      Go.textContent = window.t("Join");
    };
    Form = pas.app_helpers.El("form","quickjoin",undefined);
    Form.appendChild(pas.app_helpers.El("span","caption",Caption));
    Name = pas.app_helpers.El("input",undefined,undefined);
    Name.name = "name";
    Name.placeholder = window.t("Name");
    Name.maxLength = 24;
    Name.autocomplete = "username";
    Name.required = true;
    Pass = pas.app_helpers.El("input",undefined,undefined);
    Pass.name = "password";
    Pass.type = "password";
    Pass.placeholder = window.t("Password");
    Pass.autocomplete = "current-password";
    Pass.required = true;
    Go = pas.app_helpers.El("button","",window.t("Join"));
    Form.append(Name,Pass,Go);
    if (Boolean(pas.app_helpers.Body.dataset["sso"])) {
      Row = pas.app_helpers.El("div","ssolink",undefined);
      Row.appendChild(pas.app_helpers.El("span","",window.t("or sign in with")));
      Others = pas.app_helpers.Body.dataset["sso"].split(",");
      for (var $l = 0, $end = Others.length - 1; $l <= $end; $l++) {
        I = $l;
        A = pas.app_helpers.Link("/signin-with/" + ("" + Others[I]),"ssoicon",undefined);
        Titles = pas.JS.New(["github","GitHub","gitlab","GitLab","codeberg","Codeberg","google","Google","microsoft","Microsoft"]);
        A.title = window.t("Sign in with %s",Titles["" + Others[I]]);
        A.appendChild(pas.app_helpers.El("span","ssologo " + ("" + Others[I]),undefined));
        Row.appendChild(A);
      };
      Form.appendChild(Row);
    };
    Form.addEventListener("submit",Submit);
    Result = Form;
    return Result;
  };
  this.PopMenu = function (Anchor, Items) {
    var Menu = null;
    var Old = null;
    var R = null;
    var Shown = 0.0;
    var I = 0;
    var Close = null;
    function Add(Item) {
      var B = null;
      B = pas.app_helpers.El("button","",Item[0]);
      B.type = "button";
      B.addEventListener("click",function (E) {
        Menu.remove();
        Item[1].call(Item);
      });
      Menu.appendChild(B);
    };
    Old = document.querySelectorAll(".popmenu");
    for (var $l = 0, $end = Old.length - 1; $l <= $end; $l++) {
      I = $l;
      Old.item(I).remove();
    };
    Menu = pas.app_helpers.El("nav","popmenu",undefined);
    for (var $l1 = 0, $end1 = Items.length - 1; $l1 <= $end1; $l1++) {
      I = $l1;
      Add(Items[I]);
    };
    R = Anchor.getBoundingClientRect();
    Menu.style.setProperty("left","" + Math.min(R.left,window.innerWidth - 220) + "px");
    Menu.style.setProperty("top","" + (R.bottom + 4) + "px");
    document.body.appendChild(Menu);
    if (Boolean(window.visualViewport)) {
      Shown = window.visualViewport.height}
     else Shown = window.innerHeight;
    if ((R.bottom + 4 + Menu.offsetHeight) > Shown) Menu.style.setProperty("top","" + Math.max(4,R.top - 4 - Menu.offsetHeight) + "px");
    Close = function (E) {
      if (Menu.contains(E.target)) return;
      Menu.remove();
      document.removeEventListener("click",Close);
    };
    window.setTimeout(function () {
      document.addEventListener("click",Close);
    });
  };
  $mod.$implcode = function () {
    var Rights = ["view-admin","manage-permissions","manage-settings","manage-channels","manage-private","read-reports","manage-blocks","view-visitors","view-storage"];
    $impl.MayAdmin = function () {
      var Result = false;
      var I = 0;
      Result = true;
      for (I = 0; I <= 8; I++) if (pas.app_helpers.May(Rights[I])) return Result;
      Result = pas.app_helpers.Extras.adminTabs.some(function (Extra, Index, List) {
        var Result = false;
        Result = Boolean(Extra["permission"]) && pas.app_helpers.May(Extra["permission"]);
        return Result;
      }) || pas.app_helpers.Extras.adminScripts.some(function (Extra, Index, List) {
        var Result = false;
        Result = Extra["permissions"].some(function (P, At, All) {
          var Result = false;
          Result = pas.app_helpers.May(P);
          return Result;
        });
        return Result;
      });
      return Result;
    };
  };
},["app_notify","app_panel"]);
rtl.module("app_notify",["System","JS","Web","app_helpers"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  this.InstallOffer = null;
  this.Notify = async function (Title, Words) {
    var Result = undefined;
    var Reg = null;
    try {
      Reg = await navigator.serviceWorker.ready;
      await Reg.showNotification(Title,pas.JS.New(["body",Words,"tag","page","icon",window.SiteBase.url("/icon-192.png")]));
    } catch ($e) {
      new Notification(Title,pas.JS.New(["body",Words]));
    };
    return Result;
  };
  this.SubscribePush = async function () {
    var Result = false;
    var Reg = null;
    var Key = undefined;
    var Bytes = undefined;
    var Words = undefined;
    var Raw = "";
    var Sub = null;
    try {
      Reg = await navigator.serviceWorker.ready;
      Key = (await pas.app_helpers.Get("/api/push/key"))["key"];
      Raw = atob(Key.replace(new RegExp("-","g"),"+").replace(new RegExp("_","g"),"/"));
      Bytes = Uint8Array.from(Raw,function (C) {
        var Result = 0;
        Result = C.charCodeAt(0);
        return Result;
      });
      Sub = await Reg.pushManager.getSubscription();
      if (!Boolean(Sub)) Sub = await Reg.pushManager.subscribe(pas.JS.New(["userVisibleOnly",true,"applicationServerKey",Bytes]));
      await pas.app_helpers.Post("/api/push",pas.JS.New(["endpoint",Sub["endpoint"]]));
      Result = true;
    } catch ($e) {
      Words = $e["message"];
      if (!Boolean(Words)) Words = $e;
      pas.app_helpers.Remember("push: " + ("" + Words));
      Result = false;
    };
    return Result;
  };
  this.NotifyState = function () {
    var Result = "";
    var State = undefined;
    if (!Reflect.has(window,"Notification") || !Reflect.has(window.navigator,"serviceWorker") || !Reflect.has(window,"PushManager")) {
      Result = "none";
      return Result;
    };
    State = pas.JS.New(["granted","on","denied","blocked"])["" + Notification.permission];
    if (Boolean(State)) {
      Result = "" + State}
     else Result = "off";
    return Result;
  };
  this.BellButton = function () {
    var Result = null;
    var State = "";
    State = $mod.NotifyState();
    Result = pas.app_helpers.IconButton("bell",pas.JS.New(["on",window.t("Notifications are on"),"off",window.t("Turn on notifications for mentions and private messages"),"blocked",window.t("Notifications are blocked: click to see how to allow them"),"none",window.t("This browser cannot show notifications")])[State],"bell-" + State);
    Result.addEventListener("click",function (E) {
      $impl.TurnOnNotifications();
    });
    return Result;
  };
  this.OfferNotifications = function () {
    var Asked = undefined;
    var State = "";
    var Bar = null;
    var No = null;
    var Yes = null;
    Asked = "";
    try {
      Asked = localStorage.getItem("notify-asked-2");
      if (!Boolean(Asked)) Asked = "";
    } catch ($e) {
    };
    State = $mod.NotifyState();
    if (!Boolean(pas.app_helpers.Me.name) || Boolean(Asked) || (State === "on") || Boolean(pas.app_helpers.Find("#notifybar",undefined))) return;
    Bar = pas.app_helpers.El("div","notifybar",undefined);
    Bar.id = "notifybar";
    if (State === "off") {
      No = pas.app_helpers.El("button","small-link",window.t("Not now"))}
     else No = pas.app_helpers.El("button","small-link",window.t("OK"));
    No.type = "button";
    No.addEventListener("click",function (E) {
      try {
        localStorage.setItem("notify-asked-2","1");
      } catch ($e) {
      };
      Bar.remove();
    });
    Bar.appendChild(pas.app_helpers.Icon("bell"));
    if (State === "off") {
      Yes = pas.app_helpers.El("button","primary",window.t("Turn on"));
      Yes.type = "button";
      Yes.addEventListener("click",function (E) {
        $impl.TurnOnNotifications();
      });
      Bar.append(pas.app_helpers.El("span","",window.t("Get a notification when someone mentions you or sends you a private message?")),Yes);
    } else if (State === "blocked") {
      Bar.appendChild(pas.app_helpers.El("span","",$impl.BlockedHelp))}
     else Bar.appendChild(pas.app_helpers.El("span","",window.t("This browser cannot show notifications from sites, so mentions and private messages only show here.")));
    Bar.appendChild(No);
    pas.app_helpers.Find("#main",undefined).prepend(Bar);
  };
  this.StartNotify = function () {
    if (Reflect.has(window.navigator,"serviceWorker")) navigator.serviceWorker.register(window.SiteBase.url("/sw.js")).catch(function (Err) {
      var Result = undefined;
      pas.app_helpers.Remember("service worker: " + ("" + Err["message"]));
      return Result;
    });
    window.addEventListener("beforeinstallprompt",function (E) {
      E.preventDefault();
      $mod.InstallOffer = E;
      pas.app_account.RenderAccount();
    });
    if (window.matchMedia("(display-mode: standalone)").matches) {
      $impl.BlockedHelp = window.t('Notifications are blocked for this site, and the app cannot ask again. Open %s in the browser itself, tap the icon left of the address, Permissions, and allow Notifications (or reset them); the app uses the same setting. In Brave, also turn on "Use Google services for push messaging" under Settings, Privacy and security.',window.location.host)}
     else $impl.BlockedHelp = window.t('Notifications are blocked for this site. Allow them in the browser\'s site settings (the icon left of the address, or Settings, Site settings, Notifications). In Brave, also turn on "Use Google services for push messaging" under Settings, Privacy and security.');
  };
  $mod.$implcode = function () {
    $impl.BlockedHelp = "";
    $impl.TurnOnNotifications = async function () {
      var State = "";
      var Bar = null;
      State = $mod.NotifyState();
      if (State === "none") {
        pas.app_helpers.Toast(window.t("This browser cannot show notifications from sites."),"bad");
        return;
      };
      if (State === "blocked") {
        pas.app_helpers.Toast($impl.BlockedHelp,"bad");
        return;
      };
      if (!Object.is(await Notification.requestPermission(),"granted")) {
        pas.app_helpers.Toast($impl.BlockedHelp,"bad")}
       else if (await $mod.SubscribePush()) {
        pas.app_helpers.Toast(window.t("Notifications are on: mentions and private messages, when the chat is not in front of you."),undefined)}
       else pas.app_helpers.Toast(window.t('Notifications are allowed, but the browser would not sign up for push messages. In Brave, turn on "Use Google services for push messaging" under Settings, Privacy and security, then tap the bell again.'),"bad");
      pas.app_account.RenderAccount();
      Bar = pas.app_helpers.Find("#notifybar",undefined);
      if (Boolean(Bar)) Bar.remove();
    };
  };
},["app_account"]);
rtl.module("AppPage",["System","JS","Web","weborworker","app_helpers","app_notify","app_account","app_router","app_panel","app_profile","app_admin"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  $mod.$implcode = function () {
    $impl.Start = async function () {
      var Result = undefined;
      var I = 0;
      var P = null;
      var Thread = 0.0;
      var View = undefined;
      var Target = undefined;
      if (Boolean(pas.app_helpers.Me.name)) try {
        await pas.app_helpers.LoadMe();
      } catch ($e) {
      };
      I = 0;
      while (I < pas.app_router.Parts.length) {
        P = pas.app_router.Parts[I];
        if (Boolean(P["prepare"])) await P["prepare"].call(P);
        I += 1;
      };
      pas.app_account.RenderAccount();
      pas.app_router.RenderSide();
      I = 0;
      while (I < pas.app_router.Parts.length) {
        P = pas.app_router.Parts[I];
        if (Boolean(P["start"])) P["start"].call(P);
        I += 1;
      };
      Thread = Number(pas.app_helpers.Body.dataset["thread"]);
      View = pas.app_helpers.Body.dataset["view"];
      Target = pas.app_helpers.Body.dataset["target"];
      try {
        if (Object.is(View,"profile")) {
          await pas.app_profile.OpenProfile(Target)}
         else if (Object.is(View,"admin")) {
          await pas.app_admin.OpenAdmin()}
         else {
          I = 0;
          while (I < pas.app_router.Parts.length) {
            P = pas.app_router.Parts[I];
            if (Boolean(P["view"]) && Boolean(await P["view"].call(P,View,Target,Thread))) break;
            I += 1;
          };
        };
      } catch ($e) {
        pas.app_helpers.Stream.appendChild(pas.app_helpers.El("p","notice",$e["message"]));
      };
      pas.app_router.SyncNow(true);
      return Result;
    };
    $impl.Load = function () {
      pas.app_helpers.StartHelpers();
      pas.app_notify.StartNotify();
      pas.app_router.StartRouter();
      pas.app_profile.StartAway();
      pas.app_admin.StartAdmin();
      pas.app_helpers.Extras = pas.JS.New(["groups",new Array(),"cards",new Array(),"badges",new Array(),"rooms",new Array(),"commands",new Object(),"adminTabs",new Array(),"adminScripts",new Array(),"adminOverview",new Array(),"settingGroups",new Object(),"accountLinks",new Array(),"places",new Object()]);
      window["Chat"] = pas.JS.New(["extras",pas.app_helpers.Extras,"me",pas.app_helpers.Me,"state",pas.app_helpers.S,"icons",pas.app_helpers.Icons,"el",pas.app_helpers.SideEl,"link",pas.app_helpers.SideLink,"icon",pas.app_helpers.SideIcon,"get",pas.app_helpers.Get,"post",pas.app_helpers.KeysPost,"enc",pas.app_helpers.Enc,"toast",pas.app_helpers.Toast,"failed",pas.app_helpers.Failed,"route",pas.app_router.Route,"openPanel",pas.app_panel.OpenPanel,"ago",pas.app_helpers.Ago,"subTabs",pas.app_admin.SubTabs,"facts",pas.app_admin.Facts,"chip",pas.app_admin.Chip,"waiting",pas.app_admin.Waiting,"$",pas.app_helpers.Find,"stream",pas.app_helpers.Stream,"Site",pas.app_helpers.SiteName,"iconButton",pas.app_helpers.SideIconButton,"sizeText",pas.app_helpers.SizeText,"syncNow",pas.app_router.SyncNow,"toggleMenu",pas.app_router.ToggleMenu,"locale",pas.app_helpers.Locale,"clock",pas.app_helpers.Clock,"shared",pas.app_profile.Shared,"loadScript",pas.app_admin.LoadScript,"parts",pas.app_router.Parts,"body",pas.app_helpers.Body,"panel",pas.app_helpers.Panel,"avatar",pas.app_helpers.SideAvatar,"dayLabel",pas.app_helpers.DayLabel,"keepPinned",pas.app_helpers.KeepPinned,"pinWatch",pas.app_helpers.PinWatch,"nearBottom",pas.app_helpers.NearBottom,"may",pas.app_helpers.May,"mayHere",pas.app_helpers.MayHere,"notify",pas.app_notify.Notify,"popMenu",pas.app_account.PopMenu,"joinForm",pas.app_account.JoinForm,"confirmBox",pas.app_profile.ConfirmBox,"layerOpened",pas.app_router.LayerOpened,"layerClosed",pas.app_router.LayerClosed,"offerNotifications",pas.app_notify.OfferNotifications,"subscribePush",pas.app_notify.SubscribePush]);
      window["Site"] = window["Chat"];
      if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded",function (E) {
          $impl.Start();
        },pas.JS.New(["once",true]))}
       else $impl.Start();
    };
  };
  $mod.$init = function () {
    $impl.Load();
  };
},[]);

rtl.run('AppPage');
}
