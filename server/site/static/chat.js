if (!pas.ChatPage) {
rtl.module("chat_shared",["System","JS","Web"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  this.Same = function (A, B) {
    return A === B;
  };
  this.Toggle = function (Node, Name, Force) {
    var Result = false;
    Result = Node.classList.toggle(Name,Force);
    return Result;
  };
  this.C = null;
  this.Body = null;
  this.Stream = null;
  this.Panel = null;
  this.Site = undefined;
  this.Me = null;
  this.S = null;
  this.Extras = null;
  this.ToggleMenu = null;
  this.FailedFn = undefined;
  this.Notices = null;
  this.Menu = null;
  this.Live = null;
  this.RoomsWanted = false;
  this.FromRing = false;
  this.Setup = function () {
    var Shell = null;
    Shell = window["Chat"];
    $mod.C = Shell;
    $impl.FindFn = Shell["$"];
    $mod.Body = Shell["body"];
    $mod.Stream = Shell["stream"];
    $mod.Panel = Shell["panel"];
    $mod.Site = Shell["Site"];
    $mod.Me = Shell["me"];
    $mod.S = Shell["state"];
    $mod.Extras = Shell["extras"];
    $impl.ElFn = Shell["el"];
    $impl.LinkFn = Shell["link"];
    $impl.IconFn = Shell["icon"];
    $impl.IconButtonFn = Shell["iconButton"];
    $impl.GetFn = Shell["get"];
    $impl.PostFn = Shell["post"];
    $impl.EncFn = Shell["enc"];
    $impl.ToastFn = Shell["toast"];
    $impl.FailFn = Shell["failed"];
    $mod.FailedFn = Shell["failed"];
    $impl.RouteFn = Shell["route"];
    $impl.OpenPanelFn = Shell["openPanel"];
    $impl.AgoFn = Shell["ago"];
    $impl.ClockFn = Shell["clock"];
    $impl.DayLabelFn = Shell["dayLabel"];
    $impl.AvatarFn = Shell["avatar"];
    $impl.SizeTextFn = Shell["sizeText"];
    $impl.KeepPinnedFn = Shell["keepPinned"];
    $impl.NearBottomFn = Shell["nearBottom"];
    $impl.MayFn = Shell["may"];
    $impl.MayHereFn = Shell["mayHere"];
    $impl.NotifyFn = Shell["notify"];
    $impl.PopMenuFn = Shell["popMenu"];
    $impl.JoinFormFn = Shell["joinForm"];
    $impl.LayerOpenedFn = Shell["layerOpened"];
    $impl.LayerClosedFn = Shell["layerClosed"];
    $mod.ToggleMenu = Shell["toggleMenu"];
    $impl.ConfirmBoxFn = Shell["confirmBox"];
    $mod.Notices = pas.JS.New(["unseen",0,"items",new Array()]);
    $mod.Menu = null;
    $mod.Live = pas.JS.New(["ws",null,"id","","wait",1000,"failures",0]);
    $mod.RoomsWanted = false;
    $mod.FromRing = false;
  };
  this.Find = function (Selector, Root) {
    var Result = null;
    Result = $impl.FindFn(Selector,Root);
    return Result;
  };
  this.El = function (Tag, Cls, Text) {
    var Result = null;
    Result = $impl.ElFn(Tag,Cls,Text);
    return Result;
  };
  this.Link = function (Href, Cls, Text) {
    var Result = null;
    Result = $impl.LinkFn(Href,Cls,Text);
    return Result;
  };
  this.Icon = function (Name) {
    var Result = null;
    Result = $impl.IconFn(Name);
    return Result;
  };
  this.IconButton = function (Name, Title, Cls) {
    var Result = null;
    Result = $impl.IconButtonFn(Name,Title,Cls);
    return Result;
  };
  this.Avatar = function (Name, Url, Cls) {
    var Result = null;
    Result = $impl.AvatarFn(Name,Url,Cls);
    return Result;
  };
  this.Get = function (Url) {
    var Result = null;
    Result = $impl.GetFn(Url);
    return Result;
  };
  this.Post = function (Url, Data) {
    var Result = null;
    Result = $impl.PostFn(Url,Data);
    return Result;
  };
  this.Enc = function (Text) {
    var Result = "";
    Result = $impl.EncFn(Text);
    return Result;
  };
  this.Toast = function (Text, Kind) {
    $impl.ToastFn(Text,Kind);
  };
  this.Failed = function (Err) {
    $impl.FailFn(Err);
  };
  this.Route = function (Path, Push) {
    var Result = null;
    Result = $impl.RouteFn(Path,Push);
    return Result;
  };
  this.OpenPanel = function (Title, Cls) {
    var Result = null;
    Result = $impl.OpenPanelFn(Title,Cls);
    return Result;
  };
  this.Ago = function (Iso) {
    var Result = "";
    Result = $impl.AgoFn(Iso);
    return Result;
  };
  this.Clock = function (At) {
    var Result = "";
    Result = $impl.ClockFn(At);
    return Result;
  };
  this.DayLabel = function (Day) {
    var Result = "";
    Result = $impl.DayLabelFn(Day);
    return Result;
  };
  this.SizeText = function (N) {
    var Result = "";
    Result = $impl.SizeTextFn(N);
    return Result;
  };
  this.KeepPinned = function (Box) {
    $impl.KeepPinnedFn(Box);
  };
  this.NearBottom = function (Box) {
    var Result = false;
    Result = $impl.NearBottomFn(Box);
    return Result;
  };
  this.May = function (Permission) {
    var Result = false;
    Result = $impl.MayFn(Permission);
    return Result;
  };
  this.MayHere = function (Permission) {
    var Result = false;
    Result = $impl.MayHereFn(Permission);
    return Result;
  };
  this.Notify = function (Title, Text) {
    $impl.NotifyFn(Title,Text);
  };
  this.PopMenu = function (Anchor, Items) {
    $impl.PopMenuFn(Anchor,Items);
  };
  this.JoinForm = function (Caption) {
    var Result = null;
    Result = $impl.JoinFormFn(Caption);
    return Result;
  };
  this.ConfirmBox = function () {
    var Result = null;
    Result = $impl.ConfirmBoxFn();
    return Result;
  };
  this.LayerOpened = function () {
    $impl.LayerOpenedFn();
  };
  this.LayerClosed = function () {
    $impl.LayerClosedFn();
  };
  $mod.$implcode = function () {
    $impl.FindFn = null;
    $impl.PostFn = null;
    $impl.ToastFn = null;
    $impl.RouteFn = null;
    $impl.OpenPanelFn = null;
    $impl.NotifyFn = null;
    $impl.PopMenuFn = null;
    $impl.ElFn = null;
    $impl.LinkFn = null;
    $impl.IconButtonFn = null;
    $impl.AvatarFn = null;
    $impl.IconFn = null;
    $impl.GetFn = null;
    $impl.FailFn = null;
    $impl.KeepPinnedFn = null;
    $impl.JoinFormFn = null;
    $impl.EncFn = null;
    $impl.AgoFn = null;
    $impl.ClockFn = null;
    $impl.DayLabelFn = null;
    $impl.SizeTextFn = null;
    $impl.NearBottomFn = null;
    $impl.MayFn = null;
    $impl.MayHereFn = null;
    $impl.ConfirmBoxFn = null;
    $impl.LayerOpenedFn = null;
    $impl.LayerClosedFn = null;
  };
},[]);
rtl.module("chat_answer",["System","JS","Web","chat_shared"],function () {
  "use strict";
  var $mod = this;
  this.FirstWords = function (Text) {
    var Result = "";
    var Words = "";
    Words = Text.replace(new RegExp("```[\\s\\S]*?(```|$)","g")," ");
    Words = Words.replace(new RegExp("[*_~`]+","g"),"");
    Words = Words.replace(new RegExp("\\s+","g")," ");
    Result = Words.trim().slice(0,140);
    return Result;
  };
  this.Flash = function (There) {
    There.scrollIntoView(pas.JS.New(["block","center"]));
    There.classList.add("flash");
    window.setTimeout(function () {
      There.classList.remove("flash");
    },1600);
  };
  this.SaidIn = function (Re) {
    var Result = "";
    var R = null;
    R = Re;
    if (R.text.startsWith(R.from + " ")) {
      Result = R.text.slice(R.from.length + 1)}
     else Result = R.text;
    return Result;
  };
  this.QuoteOf = function (Re, Far) {
    var Result = null;
    var R = null;
    var Quote = null;
    R = Re;
    Quote = pas.chat_shared.El("button","quote",undefined);
    Quote.type = "button";
    if (R.gone) {
      Quote.textContent = window.t("a deleted message");
      Quote.disabled = true;
      return Quote;
    };
    Quote.append(pas.chat_shared.El("b","",R.from.slice(0,60)),document.createTextNode(" " + $mod.SaidIn(R).slice(0,140)));
    Quote.addEventListener("click",function (E) {
      var List = null;
      var There = null;
      List = Quote.closest(".threadlist");
      if (List === null) List = pas.chat_shared.Stream;
      There = List.querySelector('.msg[data-id="' + ("" + parseInt(R.id,10)) + '"]');
      if (There !== null) {
        $mod.Flash(There)}
       else Far();
    });
    Result = Quote;
    return Result;
  };
  this.AnswerStrip = function (Key) {
    var Result = undefined;
    var Strips = null;
    var I = 0;
    Result = undefined;
    Strips = document.querySelectorAll(".composer .answering");
    for (var $l = 0, $end = Strips.length - 1; $l <= $end; $l++) {
      I = $l;
      if (Strips.item(I).dataset["key"] === Key) return Strips.item(I);
    };
    return Result;
  };
  this.ShowAnswer = function () {
    var Strips = null;
    var I = 0;
    function Show(Strip) {
      var Re = null;
      var Area = null;
      var Stop = null;
      if (Boolean(pas.chat_shared.S.answer) && (pas.chat_shared.S.answer.key === Strip.dataset["key"])) {
        Re = pas.chat_shared.S.answer.re}
       else Re = null;
      Strip.replaceChildren();
      Strip.hidden = !Boolean(Re);
      if (!Boolean(Re)) return;
      Area = Strip.parentNode.querySelector("textarea");
      Stop = pas.chat_shared.IconButton("close",window.t("Do not answer it after all"),undefined);
      Stop.addEventListener("click",function (E) {
        $mod.Answer("",null);
        Area.focus();
      });
      Strip.append(pas.chat_shared.El("span","",window.t("Answering %s:",Re.from) + " " + $mod.SaidIn(Re)),Stop);
      Area.focus();
    };
    Strips = document.querySelectorAll(".composer .answering");
    for (var $l = 0, $end = Strips.length - 1; $l <= $end; $l++) {
      I = $l;
      Show(Strips.item(I));
    };
  };
  this.Answer = function (Key, Re) {
    if (Boolean(Re)) {
      pas.chat_shared.S.answer = pas.JS.New(["key",Key,"re",Re])}
     else pas.chat_shared.S.answer = null;
    $mod.ShowAnswer();
  };
  this.Answered = function (Key) {
    var Result = null;
    if (Boolean(pas.chat_shared.S.answer) && (pas.chat_shared.S.answer.key === Key)) {
      Result = pas.chat_shared.S.answer.re}
     else Result = null;
    return Result;
  };
});
rtl.module("chat_complete",["System","JS","Web","chat_shared"],function () {
  "use strict";
  var $mod = this;
  this.EmojiSet = async function () {
    var Result = null;
    var List = null;
    var Mine = null;
    List = await window.EmojiNames.list();
    if (Boolean(pas.chat_shared.Me.reactions)) {
      Mine = pas.chat_shared.Me.reactions["shown"].concat(pas.chat_shared.Me.reactions["more"])}
     else Mine = new Array();
    Result = List.concat(Mine.filter(function (R, I, A) {
      var Result = false;
      Result = !List.some(function (E, J, B) {
        var Result = false;
        Result = pas.chat_shared.Same(E["emoji"],R);
        return Result;
      });
      return Result;
    }).map(function (R, I, A) {
      var Result = undefined;
      Result = pas.JS.New(["emoji",R,"name","reaction","keywords",Array.of("reaction")]);
      return Result;
    }));
    return Result;
  };
  this.Completer = function (Area, Commands) {
    var Result = null;
    var Box = null;
    var Holder = null;
    var Items = null;
    var Index = 0;
    var Start = 0;
    var Ahead = 0;
    var Timer = 0;
    var Eager = false;
    var TypedAt = 0;
    var Waiting = false;
    var Taking = false;
    var Asked = 0;
    function WordAt() {
      var Result = null;
      var Before = "";
      var Found = undefined;
      var Parts = null;
      var E = null;
      Before = Area.value.slice(0,Area.selectionStart);
      Found = Before.match(new RegExp("(^|\\s)([@#])([\\w.-]*)$"));
      if (!Found) {
        if (Commands !== null) {
          Found = Before.match(new RegExp("^(\\/)([\\w]*)$"))}
         else Found = null;
      };
      Parts = Found;
      if (Boolean(Found) && pas.chat_shared.Same(Parts[1],"/")) return pas.JS.New(["kind","/","text",Parts[2],"at",0]);
      if (Found) return pas.JS.New(["kind",Parts[2],"text",Parts[3],"at",Before.length - Parts[3].length - 1]);
      E = window.EmojiNames.typed(Area.value,Area.selectionStart,Eager);
      if (!Boolean(E)) return E;
      Result = pas.JS.New(["kind",":","text",E["word"],"at",E["from"],"whole",E["whole"]]);
      return Result;
    };
    function Select(I) {
      var N = 0;
      var Rows = null;
      var Row = null;
      Index = I;
      Rows = Array.from(Box.children);
      for (var $l = 0, $end = Rows.length - 1; $l <= $end; $l++) {
        N = $l;
        pas.chat_shared.Toggle(Rows[N],"on",N === I);
      };
      Row = Box.children["" + I];
      Box["scrollTop"] = Math.min(Row.offsetTop,Math.max(Box.scrollTop,(Row.offsetTop + Row.offsetHeight) - Box.clientHeight));
    };
    function Show(List) {
      var I = 0;
      var Now = false;
      function AddRow(It, N) {
        var Row = null;
        Row = pas.chat_shared.El("div","item",undefined);
        Row.appendChild(pas.chat_shared.El("b","",It.label));
        if (It.hint) Row.appendChild(pas.chat_shared.El("span","",It.hint));
        Row.addEventListener("mousemove",function (E) {
          if (Index !== N) Select(N);
        });
        Row.addEventListener("mousedown",function (E) {
          E.preventDefault();
          Index = N;
          Pick();
        });
        Box.appendChild(Row);
      };
      Items = List.slice(0,8);
      Box.replaceChildren();
      Box.hidden = Items.length === 0;
      for (var $l = 0, $end = Items.length - 1; $l <= $end; $l++) {
        I = $l;
        AddRow(Items[I],I);
      };
      if (Items.length > 0) Select(((Ahead % Items.length) + Items.length) % Items.length);
      Now = Taking;
      Waiting = false;
      Taking = false;
      Ahead = 0;
      if (Now) Pick();
    };
    function Close() {
      Box.hidden = true;
      Items = new Array();
      Eager = false;
      Waiting = false;
      Taking = false;
      Ahead = 0;
    };
    function Pick() {
      var It = null;
      It = Items[Index];
      if (!Boolean(It)) return;
      Area.setRangeText(It.insert,Start,Area.selectionStart,"end");
      Close();
      Area.focus();
    };
    async function Found(W, Turn) {
      var Result = null;
      var Low = "";
      var All = null;
      var Emoji = null;
      var I = 0;
      var Seen = null;
      var Named = null;
      var More = null;
      Low = W.text.toLowerCase();
      if (W.kind === "@") return (await pas.chat_shared.Get("/api/users?q=" + pas.chat_shared.Enc(W.text))).map(function (U, N, A) {
        var Result = undefined;
        Result = pas.JS.New(["label","@" + ("" + U["name"]),"insert","@" + ("" + U["name"]) + " "]);
        return Result;
      });
      if (W.kind === "#") {
        All = pas.chat_shared.S.rooms.filter(function (R, N, A) {
          var Result = false;
          Result = R.kind !== "shelf";
          return Result;
        }).map(function (R, N, A) {
          var Result = undefined;
          Result = pas.JS.New(["slug",R.slug,"title",R.title]);
          return Result;
        });
        I = 0;
        while (I < pas.chat_shared.Extras.rooms.length) {
          More = pas.chat_shared.Extras.rooms[I];
          All = All.concat(await More(W.text));
          I += 1;
        };
        Seen = new Object();
        return All.filter(function (R, N, A) {
          var Result = false;
          if (Boolean(Seen[R.slug]) || !R.slug.startsWith(Low)) return false;
          Seen[R.slug] = true;
          Result = true;
          return Result;
        }).map(function (R, N, A) {
          var Result = undefined;
          Result = pas.JS.New(["label","#" + R.slug,"hint",R.title,"insert","#" + R.slug + " "]);
          return Result;
        });
      };
      if (W.kind === ":") {
        Emoji = await $mod.EmojiSet();
        if (!W.whole) return window.EmojiNames.matches(Emoji,W.text).map(function (E, N, A) {
          var Result = undefined;
          var Hint = undefined;
          Hint = E["match"];
          if (!Hint) Hint = E["keywords"][0];
          Result = pas.JS.New(["label",E["emoji"],"hint",Hint,"insert","" + E["emoji"] + " "]);
          return Result;
        });
        Named = window.EmojiNames.named(Emoji,W.text);
        if (Boolean(Named) && (Turn === Asked) && (Area.selectionStart === TypedAt)) Area.setRangeText("" + Named["emoji"],Start,TypedAt,"end");
        return new Array();
      };
      if (!Boolean(pas.chat_shared.S.commands)) pas.chat_shared.S.commands = await pas.chat_shared.Get("/api/commands");
      Result = pas.chat_shared.S.commands.filter(function (C, N, A) {
        var Result = false;
        Result = Commands(C) && C["name"].startsWith(Low);
        return Result;
      }).map(function (C, N, A) {
        var Result = undefined;
        Result = pas.JS.New(["label","/" + ("" + C["name"]),"hint",C["usage"],"insert","/" + ("" + C["name"]) + " "]);
        return Result;
      });
      return Result;
    };
    function Update() {
      var At = 0;
      var Turn = 0;
      var Wait = 0;
      var W = null;
      TypedAt = Area.selectionStart;
      At = TypedAt;
      W = WordAt();
      Asked += 1;
      Turn = Asked;
      window.clearTimeout(Timer);
      if (!Boolean(W)) {
        Close();
        return;
      };
      Start = W.at;
      Waiting = true;
      if (W.kind === "@") {
        Wait = 150}
       else Wait = 0;
      Timer = window.setTimeout(async function () {
        var List = null;
        List = new Array();
        try {
          List = await Found(W,Turn);
        } catch ($e) {
        };
        if (Turn === Asked) if (Area.selectionStart === At) {
          Show(List)}
         else Show(new Array());
      },Wait);
    };
    function Handle(E) {
      var Result = false;
      var Arrow = false;
      var Take = false;
      var Step = 0;
      var W = null;
      Arrow = ((E.key === "ArrowDown") || (E.key === "ArrowUp")) && !E.shiftKey && !E.ctrlKey && !E.altKey && !E.metaKey;
      if (E.key === "ArrowDown") {
        Step = 1}
       else Step = -1;
      Take = (E.key === "Enter") || (E.key === "Tab");
      if (Box.hidden || (Items.length === 0)) {
        if (Waiting && (Arrow || (Take && (Ahead !== 0)))) {
          if (Arrow) {
            Ahead = Ahead + Step}
           else Taking = true;
          E.preventDefault();
          return true;
        };
        if (!Arrow) return false;
        Eager = (Area.selectionStart === TypedAt) && (Area.selectionEnd === TypedAt);
        if (Eager) {
          W = WordAt()}
         else W = null;
        if (!Boolean(W) || (W.kind !== ":") || W.whole || (W.text.length > 1)) {
          Eager = false;
          return false;
        };
        E.preventDefault();
        Update();
        return true;
      };
      if (Arrow) {
        E.preventDefault();
        Select((Index + Step + Items.length) % Items.length);
        return true;
      };
      if (Take) {
        E.preventDefault();
        Pick();
        return true;
      };
      if (E.key === "Escape") {
        Close();
        TypedAt = -1;
        return true;
      };
      Result = false;
      return Result;
    };
    Box = pas.chat_shared.El("div","complete",undefined);
    Box.hidden = true;
    Holder = Area.closest(".composer");
    if (Holder === null) Holder = Area.parentNode;
    Holder.appendChild(Box);
    Items = new Array();
    Index = 0;
    Start = 0;
    Eager = false;
    TypedAt = -1;
    Waiting = false;
    Ahead = 0;
    Taking = false;
    Timer = 0;
    Asked = 0;
    Area.addEventListener("blur",function (E) {
      window.setTimeout(function () {
        Close();
      },150);
    });
    Result = pas.JS.New(["update",Update,"handle",Handle]);
    return Result;
  };
});
rtl.module("chat_private",["System","JS","Web","chat_shared"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  this.PlainHtml = function (Text, Locked) {
    var Result = "";
    function Esc(Raw) {
      var Result = "";
      Result = Raw.replace(new RegExp("&","g"),"&amp;");
      Result = Result.replace(new RegExp("<","g"),"&lt;");
      Result = Result.replace(new RegExp(">","g"),"&gt;");
      Result = Result.replace(new RegExp('"',"g"),"&quot;");
      return Result;
    };
    var Parts = null;
    var Part = "";
    var Lang = "";
    var Shaped = "";
    var Found = null;
    var I = 0;
    Result = "";
    Parts = Text.split("```");
    for (var $l = 0, $end = Parts.length - 1; $l <= $end; $l++) {
      I = $l;
      Part = "" + Parts[I];
      if ((I % 2) !== 0) {
        Found = (new RegExp("^([\\w+#-]+)\\n")).exec(Part);
        if (Found !== null) {
          Lang = "" + Found["1"]}
         else Lang = window.t("code");
        Result = Result + '<div class="code"><div class="codebar"><span>' + Esc(Lang) + "</span>";
        if (Locked) Result = Result + '<span class="codenote">' + Esc(window.t("Not colored: the server cannot read a locked conversation.")) + "</span>";
        Result = Result + '<button type="button" class="copy">' + Esc(window.t("Copy")) + "</button></div><pre><code>";
        Shaped = Part.replace(new RegExp("^[\\w+#-]*\\n"),"");
        Shaped = Shaped.replace(new RegExp("\\n$"),"");
        Result = Result + Esc(Shaped) + "</code></pre></div>";
      } else {
        Shaped = Esc(Part).replace(new RegExp("`([^`\\n]+)`","g"),"<code>$1</code>");
        Shaped = Shaped.replace(new RegExp("\\*\\*([^*\\n]+)\\*\\*","g"),"<b>$1</b>");
        Shaped = Shaped.replace(new RegExp("(https?:\\/\\/[^\\s<]+)","g"),'<a rel="nofollow ugc" target="_blank" href="$1">$1</a>');
        Result = Result + Shaped.replace(new RegExp("\\n","g"),"<br>");
      };
    };
    return Result;
  };
  this.OpenDm = async function (Name) {
    var Generation = 0.0;
    var Who = null;
    var Head = null;
    var MenuButton = null;
    var Titles = null;
    var H = null;
    var Lock = null;
    var Flip = null;
    var Tools = null;
    var Remove = null;
    var Search = null;
    Generation = pas.chat_shared.S.generation;
    Who = await pas.chat_shared.Get("/api/key?name=" + pas.chat_shared.Enc(Name));
    if (Generation !== pas.chat_shared.S.generation) return;
    pas.chat_shared.S.view = "dm";
    pas.chat_shared.S.dm = Who.name;
    pas.chat_shared.S.dmAvatar = Who.avatar;
    if (Boolean(Who.seen)) {
      pas.chat_shared.S.dmSeen = Who.seen}
     else pas.chat_shared.S.dmSeen = 0;
    pas.chat_shared.S.dmLast = 0;
    pas.chat_shared.S.dmFirst = 0;
    pas.chat_shared.S.dmOlderDone = false;
    pas.chat_shared.S.title = "@" + Who.name;
    Head = pas.chat_shared.Find("#roomhead",undefined);
    MenuButton = pas.chat_shared.IconButton("menu",window.t("Channels"),"menubtn");
    MenuButton.addEventListener("click",pas.chat_shared.ToggleMenu);
    Titles = pas.chat_shared.El("div","titles",undefined);
    H = pas.chat_shared.El("h1",undefined,undefined);
    H.append(pas.chat_shared.Avatar(Who.name,Who.avatar,"small"),pas.chat_shared.Link("/u/" + pas.chat_shared.Enc(Who.name),"",Who.name));
    Titles.appendChild(H);
    pas.chat_shared.S.dmLocked = Boolean(Who.locked);
    if (pas.chat_shared.S.dmLocked) {
      Lock = pas.chat_shared.El("p","topic secure",undefined)}
     else Lock = pas.chat_shared.El("p","topic",undefined);
    if (pas.chat_shared.S.dmLocked) {
      Lock.append(pas.chat_shared.Icon("lock"),document.createTextNode(window.t(" Locked: end to end encrypted. Only your two browsers can read it, and IRC users cannot.")))}
     else Lock.appendChild(document.createTextNode(window.t("Not locked: this site can read it, and it reaches IRC. ")));
    if (pas.chat_shared.Me.name !== "") {
      if (pas.chat_shared.S.dmLocked) {
        Flip = pas.chat_shared.El("button","small-link",window.t("Unlock"))}
       else Flip = pas.chat_shared.El("button","small-link",window.t("Lock it"));
      Flip.type = "button";
      if (pas.chat_shared.S.dmLocked) {
        Flip.title = window.t("New messages go plain, readable by this site and on IRC")}
       else Flip.title = window.t("New messages are encrypted in your browsers; neither this site nor IRC can read them");
      Flip.addEventListener("click",async function (E) {
        var Turn = "";
        try {
          if (pas.chat_shared.S.dmLocked) {
            Turn = "0"}
           else Turn = "1";
          await pas.chat_shared.Post("/api/dm/lock",pas.JS.New(["with",Who.name,"on",Turn]));
          pas.chat_shared.Route(window.SiteBase.path(),false);
        } catch ($e) {
          pas.chat_shared.Failed($e);
        };
      });
      Lock.appendChild(Flip);
    };
    Titles.appendChild(Lock);
    if (pas.chat_shared.S.dmLocked && (pas.chat_shared.Me.name !== "")) window.Keys.partner(Who.name).then(function (Value) {
      var Result = undefined;
      var P = null;
      var Code = null;
      var Warn = null;
      var Ok = null;
      P = Value;
      Code = pas.chat_shared.El("p","topic",window.t("Safety code: %s",P.code));
      Code.title = window.t("The same code shows on their side. Compare it another way (a call, in person) to be sure nobody sits between you.");
      Titles.appendChild(Code);
      if (!P.changed) return Result;
      Warn = pas.chat_shared.El("p","topic problem",window.t("%s has a new key since you last wrote here. That happens after a password reset. If you did not expect it, compare the safety code with them before you write anything private.",Who.name) + " ");
      Ok = pas.chat_shared.El("button","small-link",window.t("I checked"));
      Ok.type = "button";
      Ok.addEventListener("click",function (E) {
        window.Keys.trust(Who.name).then(function (Done) {
          var Result = undefined;
          Warn.remove();
          return Result;
        }).catch(pas.chat_shared.FailedFn);
      });
      Warn.appendChild(Ok);
      Titles.appendChild(Warn);
      return Result;
    }).catch(function (Err) {
      var Result = undefined;
      if (Boolean(Err) && Boolean(Err["notOwn"])) Titles.appendChild(pas.chat_shared.El("p","topic problem",Err["message"]));
      return Result;
    });
    Head.append(MenuButton,Titles);
    if (pas.chat_shared.Me.name !== "") {
      Tools = pas.chat_shared.El("div","headtools",undefined);
      Remove = pas.chat_shared.IconButton("trash",window.t("Delete this conversation"),undefined);
      Remove.addEventListener("click",function (E) {
        pas.chat_sidebar.DeleteDm(Who.name);
      });
      Search = pas.chat_shared.IconButton("search",window.t("Search"),undefined);
      Search.addEventListener("click",function (E) {
        pas.chat_panels.OpenSearch();
      });
      Tools.append(Search,Remove);
      Head.appendChild(Tools);
    };
    if (pas.chat_shared.Me.name === "") {
      pas.chat_shared.Stream.appendChild(pas.chat_shared.El("p","notice",window.t("Sign in to send private messages.")));
      pas.chat_composer.RenderComposer(pas.chat_shared.Find("#composer-area",undefined),0,null);
      return;
    };
    if (!window.Keys.ready()) {
      pas.chat_shared.Stream.appendChild(pas.chat_shared.El("p","notice",window.t("Private messages need this page opened over https.")));
      return;
    };
    if (pas.chat_shared.S.dmLocked && !Boolean(await window.Keys.myKey())) {
      pas.chat_shared.Stream.appendChild($impl.KeyForm());
      return;
    };
    pas.chat_composer.RenderComposer(pas.chat_shared.Find("#composer-area",undefined),0,Who.name);
    $mod.PollDm(Generation);
    pas.chat_sync.SyncNow(true);
  };
  this.OpenSealed = async function (M) {
    var Result = null;
    var Sent = null;
    Sent = M;
    if (!Sent.iv) {
      try {
        return JSON.parse(Sent.data);
      } catch ($e) {
        return pas.JS.New(["t","text","text",Sent.data]);
      };
    };
    try {
      Result = await window.Keys.open(pas.chat_shared.S.dm,Sent);
    } catch ($e) {
      Result = pas.JS.New(["t","text","text",window.t("(locked, and this device cannot open it)")]);
    };
    return Result;
  };
  this.PollDm = async function (Generation) {
    var List = null;
    var Stick = false;
    var M = null;
    var Payload = null;
    var P = null;
    var I = 0;
    var Wait = 0;
    var Tail = "";
    if (Generation !== pas.chat_shared.S.generation) return;
    window.clearTimeout(pas.chat_shared.S.dmTimer);
    try {
      if (document.hidden) {
        Tail = "&peek=1"}
       else if (Boolean(pas.chat_shared.S.dmLast)) {
        Tail = "&read=" + ("" + pas.chat_shared.S.dmLast)}
       else Tail = "";
      List = await pas.chat_shared.Get("/api/dm?with=" + pas.chat_shared.Enc(pas.chat_shared.S.dm) + "&after=" + ("" + pas.chat_shared.S.dmLast) + Tail);
      if (Generation !== pas.chat_shared.S.generation) return;
      Stick = pas.chat_shared.Stream.pinned || pas.chat_shared.NearBottom(undefined) || !Boolean(pas.chat_shared.S.dmLast);
      for (var $l = 0, $end = List.length - 1; $l <= $end; $l++) {
        I = $l;
        M = List[I];
        Payload = await $mod.OpenSealed(M);
        if ((Generation !== pas.chat_shared.S.generation) || (M.id <= pas.chat_shared.S.dmLast)) continue;
        pas.chat_shared.Stream.appendChild($mod.RenderDm(M,Payload));
        pas.chat_shared.S.dmLast = Math.max(pas.chat_shared.S.dmLast,M.id);
        if (!Boolean(pas.chat_shared.S.dmFirst) || (M.id < pas.chat_shared.S.dmFirst)) pas.chat_shared.S.dmFirst = M.id;
      };
      if (Boolean(List.length)) {
        pas.chat_rooms.Regroup(pas.chat_shared.Stream);
        if (Stick) {
          pas.chat_shared.Stream.scrollTop = pas.chat_shared.Stream.scrollHeight;
          pas.chat_shared.Stream.pinned = true;
        };
      };
      if (!Boolean(List.length) && !Boolean(pas.chat_shared.S.dmLast) && (pas.chat_shared.Find(".empty",pas.chat_shared.Stream) === null)) {
        P = pas.chat_shared.El("div","empty",undefined);
        P.appendChild(pas.chat_shared.El("b","",window.t("Nothing between you two yet.")));
        if (pas.chat_shared.S.dmLocked) {
          P.appendChild(pas.chat_shared.El("span","",window.t(" Locked: only the two of you will ever read what you write here.")))}
         else P.appendChild(pas.chat_shared.El("span","",window.t(" Lock it at the top when it should stay between your two browsers.")));
        pas.chat_shared.Stream.appendChild(P);
      } else if (Boolean(List.length) && (pas.chat_shared.Find(".empty",pas.chat_shared.Stream) !== null)) pas.chat_shared.Find(".empty",pas.chat_shared.Stream).remove();
    } catch ($e) {
    };
    if (Boolean(pas.chat_shared.Live.id)) {
      Wait = 60000}
     else if (document.hidden) {
      Wait = 15000}
     else Wait = 3000;
    pas.chat_shared.S.dmTimer = window.setTimeout(function () {
      $mod.PollDm(Generation);
    },Wait);
  };
  this.OlderDms = async function () {
    var Generation = 0.0;
    var List = null;
    var Height = 0;
    var I = 0;
    var Top = null;
    var Node = null;
    if (!Boolean(pas.chat_shared.S.dmFirst) || pas.chat_shared.S.dmOlderDone || pas.chat_shared.S.loadingOlder) return;
    pas.chat_shared.S.loadingOlder = true;
    Generation = pas.chat_shared.S.generation;
    try {
      try {
        List = await pas.chat_shared.Get("/api/dm?with=" + pas.chat_shared.Enc(pas.chat_shared.S.dm) + "&before=" + ("" + pas.chat_shared.S.dmFirst));
        if (Generation !== pas.chat_shared.S.generation) return;
        Height = pas.chat_shared.Stream.scrollHeight;
        Top = pas.chat_shared.Stream.querySelector(".msg");
        for (var $l = 0, $end = List.length - 1; $l <= $end; $l++) {
          I = $l;
          Node = $mod.RenderDm(List[I],await $mod.OpenSealed(List[I]));
          if (Top !== null) {
            Top.before(Node)}
           else pas.chat_shared.Stream.appendChild(Node);
        };
        if (Boolean(List.length)) pas.chat_shared.S.dmFirst = List[0].id;
        if (List.length < 100) pas.chat_shared.S.dmOlderDone = true;
        pas.chat_rooms.Regroup(pas.chat_shared.Stream);
        pas.chat_shared.Stream.scrollTop = pas.chat_shared.Stream.scrollHeight - Height;
      } catch ($e) {
        pas.chat_shared.Failed($e);
      };
    } finally {
      pas.chat_shared.S.loadingOlder = false;
    };
  };
  this.MarkSeen = function () {
    var Old = null;
    var Node = null;
    var Mine = null;
    var Mark = null;
    var List = null;
    var I = 0;
    Old = pas.chat_shared.Stream.querySelector(":scope > .msg > .seen");
    Node = null;
    if ((pas.chat_shared.S.view === "dm") && Boolean(pas.chat_shared.S.dmSeen)) {
      List = pas.chat_shared.Stream.querySelectorAll(":scope > .msg.mine");
      for (var $l = 0, $end = List.length - 1; $l <= $end; $l++) {
        I = $l;
        Mine = List.item(I);
        if (Number(Mine.dataset["id"]) <= pas.chat_shared.S.dmSeen) Node = Mine;
      };
    };
    if ((Old !== null) && (Old.parentNode === Node)) return;
    if (Old !== null) Old.remove();
    if (Node === null) return;
    Mark = pas.chat_shared.El("span","seen",undefined);
    Mark.title = window.t("Seen");
    Mark.setAttribute("aria-label",Mark.title);
    Mark.appendChild(pas.chat_shared.Icon("seen"));
    Node.appendChild(Mark);
  };
  this.DropDm = function (Id) {
    var Node = null;
    Node = pas.chat_shared.Stream.querySelector('.msg[data-id="' + ("" + Id) + '"]');
    if (Node === null) return;
    Node.remove();
    pas.chat_rooms.Regroup(pas.chat_shared.Stream);
  };
  this.StartDmEdit = function (Node) {
    var M = null;
    var Payload = null;
    var Text = null;
    var Box = null;
    var Save = null;
    var Cancel = null;
    var Area = null;
    var Complete = null;
    function Words() {
      var Result = "";
      if (Boolean(Payload.text)) {
        Result = Payload.text}
       else Result = "";
      return Result;
    };
    function Done() {
      Box.replaceWith(Text);
    };
    async function Store() {
      var Body = "";
      var Data = null;
      Body = Area.value.trim();
      if ((Body === "") && !(Boolean(Payload.files) && Boolean(Payload.files.length))) {
        pas.chat_shared.Failed(new Error(window.t("An edited message cannot be empty. Delete it instead.")));
        return;
      };
      if (Body === Words()) {
        Done();
        return;
      };
      try {
        Data = Object.assign(pas.JS.New(["id",M.id]),await $impl.DmData(pas.chat_shared.S.dm,Object.assign(new Object(),Payload,pas.JS.New(["text",Body]))));
        await pas.chat_shared.Post("/api/dm/edit",Data);
        Done();
        $mod.RefreshDm(M.id);
      } catch ($e) {
        pas.chat_shared.Failed($e);
      };
    };
    M = Node.dm["m"];
    Payload = Node.dm["payload"];
    Text = Node.querySelector(".body");
    if (Text === null) return;
    Box = pas.chat_shared.El("div","editbox",undefined);
    Area = pas.chat_shared.El("textarea",undefined,undefined);
    Area.value = Words();
    Save = pas.chat_shared.El("button","primary",window.t("Save"));
    Cancel = pas.chat_shared.El("button","",window.t("Cancel"));
    Cancel.type = "button";
    Save.type = "button";
    Box.append(Area,Save,Cancel);
    Text.replaceWith(Box);
    Area.focus();
    Area.setSelectionRange(Area.value.length,Area.value.length);
    pas.chat_composer.Fit(Area);
    Complete = pas.chat_complete.Completer(Area,null);
    Save.addEventListener("click",function (E) {
      Store();
    });
    Cancel.addEventListener("click",function (E) {
      Done();
    });
    Area.addEventListener("input",function (E) {
      pas.chat_composer.Fit(Area);
      Complete.update();
    });
    Area.addEventListener("keydown",function (E) {
      var Key = null;
      Key = E;
      if (Complete.handle(Key)) return;
      if (Key.key === "Escape") Done();
      if ((Key.key === "Enter") && !Key.shiftKey && !pas.chat_composer.InFence(Area)) {
        E.preventDefault();
        Store();
      };
    });
  };
  this.RefreshDm = async function (Id) {
    var Node = null;
    var Now = null;
    var Generation = 0.0;
    var List = null;
    var Fresh = null;
    Node = pas.chat_shared.Stream.querySelector('.msg[data-id="' + ("" + Id) + '"]');
    if ((Node === null) || (pas.chat_shared.S.view !== "dm")) return;
    Generation = pas.chat_shared.S.generation;
    try {
      List = await pas.chat_shared.Get("/api/dm?with=" + pas.chat_shared.Enc(pas.chat_shared.S.dm) + "&id=" + ("" + Id) + "&peek=1");
      if ((Generation !== pas.chat_shared.S.generation) || !Boolean(List.length)) return;
      Fresh = $mod.RenderDm(List[0],await $mod.OpenSealed(List[0]));
      Now = pas.chat_shared.Stream.querySelector('.msg[data-id="' + ("" + Id) + '"]');
      if (Now !== null) {
        Now.replaceWith(Fresh);
        pas.chat_rooms.Regroup(pas.chat_shared.Stream);
      };
    } catch ($e) {
    };
  };
  this.RenderDm = function (M, Payload) {
    var Result = null;
    var Sent = null;
    var Load = null;
    var Node = null;
    var Text = null;
    var Box = null;
    var Said = "";
    var Html = undefined;
    var Face = undefined;
    var Given = undefined;
    var Re = null;
    var I = 0;
    function Offer() {
      var Result = null;
      var Items = null;
      var Pick = null;
      Items = new Array();
      if (Load.text !== "") {
        Items.push(pas.JS.New(["icon","reply","title",window.t("Answer this message"),"run",function () {
          var First = "";
          First = pas.chat_answer.FirstWords(Said);
          if (First === "") First = window.t("code");
          pas.chat_answer.Answer("dm " + pas.chat_shared.S.dm,pas.JS.New(["id",Sent.id,"from",Sent.from,"text",First]));
        }]));
        Items.push(pas.JS.New(["icon","copy","title",window.t("Copy the text"),"run",function () {
          window.navigator.clipboard.writeText(Said).then(function (Done) {
            var Result = undefined;
            pas.chat_shared.Toast(window.t("Text copied."),undefined);
            return Result;
          });
        }]));
      };
      if ((Sent.from === pas.chat_shared.Me.name) && ((Load.t === "text") || (Load.t === "file"))) Items.push(pas.JS.New(["icon","edit","title",window.t("Edit"),"run",function () {
        $mod.StartDmEdit(Node);
      }]));
      if (Sent.from === pas.chat_shared.Me.name) Items.push(pas.JS.New(["icon","trash","title",window.t("Delete, for both of you"),"bad",true,"run",async function () {
        if (!window.confirm(window.t("Delete this message? It goes from both sides."))) return;
        try {
          await pas.chat_shared.Post("/api/dm/delete",pas.JS.New(["id",Sent.id]));
          $mod.DropDm(Sent.id);
        } catch ($e) {
          pas.chat_shared.Failed($e);
        };
      }]));
      Pick = null;
      if (pas.chat_shared.May("react")) Pick = function (R) {
        pas.chat_messages.React(Sent.id,R,true);
      };
      Result = pas.JS.New(["react",Pick,"items",Items]);
      return Result;
    };
    Sent = M;
    if (!Boolean(Payload) || (typeof(Payload) !== "object")) Payload = new Object();
    Load = Payload;
    if (typeof(Load.text) !== "string") Load.text = "";
    if (!Array.isArray(Load.files)) pas.JS.JSDelete(Load,"files");
    if (Sent.from === pas.chat_shared.Me.name) {
      Face = pas.chat_shared.Me.avatar}
     else Face = pas.chat_shared.S.dmAvatar;
    if (Array.isArray(Sent.reactions)) {
      Given = Sent.reactions}
     else Given = new Array();
    Node = pas.chat_messages.RenderMessage(pas.JS.New(["id",Sent.id,"at",Sent.at,"name",Sent.from,"uid",1,"html","","room",pas.chat_shared.S.room,"avatar",Face,"edited",Boolean(Sent.edited),"dm",true,"files",new Array(),"reactions",Given,"replies",0,"deleted",false]),true);
    Node.dm = pas.JS.New(["m",Sent,"payload",Load]);
    Said = $impl.DmWords(Sent.from,Load.text);
    Node.menu = Offer;
    Text = Node.querySelector(".body");
    if (!Boolean(Sent.iv) && (typeof(Sent.html) === "string")) {
      Html = Sent.html;
      Text.innerHTML = Html;   // safe html: rendered by the server;
    } else {
      Html = $mod.PlainHtml(Said,Boolean(Sent.iv));
      Text.innerHTML = Html;   // safe html: plainHtml escapes everything first;
    };
    pas.chat_shared.Toggle(Text,"action",Said !== Load.text);
    pas.chat_menu.DressCode(Text);
    Re = Load.re;
    if (Boolean(Re) && (typeof(Re) === "object") && (typeof(Re["text"]) === "string") && (typeof(Re["from"]) === "string")) Text.before(pas.chat_answer.QuoteOf(pas.JS.New(["id",Re["id"],"from",Re["from"],"text",Re["text"]]),function () {
      pas.chat_shared.Toast(window.t("That message is further back."),undefined);
    }));
    if (Boolean(Sent.preview) && (typeof(Sent.preview) === "object")) Text.after(pas.chat_messages.PreviewOf(Sent.preview));
    if (Boolean(Load.files)) {
      Box = pas.chat_shared.El("div","files",undefined);
      for (var $l = 0, $end = Load.files.length - 1; $l <= $end; $l++) {
        I = $l;
        if (Load.files[I]["iv"]) {
          Box.appendChild($impl.SealedFile(Load.files[I]))}
         else Box.appendChild($impl.PlainFile(Load.files[I]));
      };
      Text.after(Box);
    };
    if (Load.t === "beam") Text.after($impl.BeamCard(Sent,Load));
    Result = Node;
    return Result;
  };
  this.SendDm = async function (Other, Text, Files) {
    var Payload = null;
    var Re = null;
    var Fields = null;
    if (Boolean(Files.length)) {
      Payload = pas.JS.New(["t","file","text",Text])}
     else Payload = pas.JS.New(["t","text","text",Text]);
    if (Boolean(Files.length)) Payload["files"] = Files;
    Re = pas.chat_answer.Answered("dm " + Other);
    if (Re !== null) {
      Payload["re"] = Re;
      pas.chat_answer.Answer("",null);
    };
    Fields = pas.JS.New(["to",Other,"files",Files.map(function (F, Index, List) {
      var Result = undefined;
      Result = F["token"];
      return Result;
    }).join(",")]);
    await pas.chat_shared.Post("/api/dm",Object.assign(Fields,await $impl.DmData(Other,Payload)));
    $mod.PollNow();
  };
  this.PollNow = function () {
    window.clearTimeout(pas.chat_shared.S.dmTimer);
    $mod.PollDm(pas.chat_shared.S.generation);
  };
  this.BeamFile = async function (Other, Data) {
    var Token = "";
    var Why = undefined;
    try {
      Token = "";
      Token = await window.Keys.beamSend(Other,Data,function (Done, Total, What) {
        if (pas.chat_shared.S.beams[Token]) pas.chat_shared.S.beams[Token](Done,Total,What);
      });
      await pas.chat_shared.Post("/api/dm",Object.assign(pas.JS.New(["to",Other]),await $impl.DmData(Other,pas.JS.New(["t","beam","name",Data["name"],"size",Data["size"],"token",Token]))));
      pas.chat_shared.Toast(window.t("Keep this page open until %s has the file.",Other),undefined);
      $mod.PollNow();
    } catch ($e) {
      Why = $e;
      if (Why["message"]) Why = Why["message"];
      pas.chat_composer.Note(window.t("The beam did not start: %s",Why),false);
    };
  };
  $mod.$implcode = function () {
    $impl.KeyForm = function () {
      var Result = null;
      var First = false;
      var Form = null;
      var Go = null;
      var Password = null;
      var Say = "";
      First = !Boolean(pas.chat_shared.Me.wrapped);
      Form = pas.chat_shared.El("form","invite keyform",undefined);
      Password = pas.chat_shared.El("input",undefined,undefined);
      Password.type = "password";
      if (First) {
        Password.autocomplete = "new-password"}
       else Password.autocomplete = "current-password";
      if (First) {
        Password.placeholder = window.t("A new password, 8 characters or more")}
       else Password.placeholder = window.t("Your password");
      if (First) {
        Go = pas.chat_shared.El("button","primary",window.t("Set it"))}
       else Go = pas.chat_shared.El("button","primary",window.t("Unlock"));
      Say = window.t("Type your password to open your locked messages on this device.");
      if (First && Boolean(pas.chat_shared.Me.password)) {
        Say = window.t("Locked conversations need a key made from your password. Type it once here.")}
       else if (First) Say = window.t("Locked conversations need a password that never leaves your browser, and this account has none yet. Set one here. It also signs you in with your name, and a forgotten one cannot be reset.");
      Form.append(pas.chat_shared.El("p","notice",Say),Password,Go);
      Form.addEventListener("submit",async function (E) {
        E.preventDefault();
        Go.disabled = true;
        try {
          if (First) {
            await window.Keys.setupKeys(pas.chat_shared.Me.name,Password.value)}
           else await window.Keys.unlock(pas.chat_shared.Me.name,Password.value,pas.chat_shared.Me.wrapped);
          pas.chat_shared.Route(window.SiteBase.path(),false);
        } catch ($e) {
          pas.chat_shared.Failed($e);
        };
        Go.disabled = false;
      });
      Result = Form;
      return Result;
    };
    $impl.DmWords = function (From, Text) {
      var Result = "";
      var Action = null;
      Action = (new RegExp("^\\/me +(\\S.*)$","i")).exec(Text);
      if (Action !== null) {
        Result = From + " " + Action["1"].trim()}
       else Result = Text;
      return Result;
    };
    $impl.PlainFile = function (F) {
      var Result = null;
      var Shot = null;
      var A = null;
      var Img = null;
      if (!String(F["url"]).startsWith("/f/")) F = pas.JS.New(["name",String(F["name"]),"size",0,"url","#"]);
      if (F["image"]) {
        Shot = pas.chat_shared.Link(F["url"],"shot",undefined);
        Img = pas.chat_shared.El("img",undefined,undefined);
        Img.src = F["url"];
        Img.loading = "lazy";
        Shot.appendChild(Img);
        return Shot;
      };
      A = pas.chat_shared.Link(F["url"],"file",undefined);
      A.append(pas.chat_shared.El("span","fname",F["name"]),pas.chat_shared.El("span","fsize",pas.chat_shared.SizeText(F["size"])));
      Result = A;
      return Result;
    };
    $impl.SealedFile = function (F) {
      var Result = null;
      var A = null;
      function Kind() {
        var Result = null;
        if (F["type"]) {
          Result = F["type"]}
         else Result = "";
        return Result;
      };
      async function OpenIt(E) {
        var Blob = undefined;
        var Url = "";
        var Shot = null;
        var Save = null;
        var Img = null;
        if (E !== null) E.preventDefault();
        try {
          Blob = await window.Keys.openFile(pas.chat_shared.S.dm,F);
          Url = URL.createObjectURL(Blob);
          if (Kind().startsWith("image/")) {
            Shot = pas.chat_shared.Link(Url,"shot",undefined);
            Img = pas.chat_shared.El("img",undefined,undefined);
            Img.src = Url;
            Shot.appendChild(Img);
            A.replaceWith(Shot);
          } else {
            Save = pas.chat_shared.Link(Url,"",undefined);
            Save["download"] = F["name"];
            Save.click();
          };
        } catch ($e) {
          pas.chat_shared.Failed($e);
        };
      };
      A = pas.chat_shared.Link("#","file",undefined);
      A.append(pas.chat_shared.Icon("lock"),pas.chat_shared.El("span","fname",F["name"]),pas.chat_shared.El("span","fsize",pas.chat_shared.SizeText(F["size"])));
      A.addEventListener("click",function (E) {
        OpenIt(E);
      });
      if (Kind().startsWith("image/") && (Number(F["size"]) < (8 * 1024 * 1024))) window.setTimeout(function () {
        OpenIt(null);
      },0);
      Result = A;
      return Result;
    };
    $impl.DmData = async function (Other, Payload) {
      var Result = null;
      var Sealed = null;
      if (!pas.chat_shared.S.dmLocked) return pas.JS.New(["data",JSON.stringify(Payload)]);
      Sealed = await window.Keys.seal(Other,Payload);
      Result = pas.JS.New(["iv",Sealed["iv"],"data",Sealed["data"]]);
      return Result;
    };
    $impl.BeamCard = function (M, Payload) {
      var Result = null;
      var Card = null;
      var Bar = null;
      var State = null;
      var Take = null;
      var Report = null;
      Card = pas.chat_shared.El("div","beam",undefined);
      Card.appendChild(pas.chat_shared.Icon("beam"));
      Card.appendChild(pas.chat_shared.El("b","",Payload.name));
      Card.appendChild(pas.chat_shared.El("span","fsize",pas.chat_shared.SizeText(Payload.size)));
      Bar = pas.chat_shared.El("progress",undefined,undefined);
      Bar.max = 1;
      Bar.value = 0;
      State = pas.chat_shared.El("span","state",undefined);
      Report = function (Done, Total, What) {
        var Said = undefined;
        if (Total) {
          Bar.max = Total}
         else Bar.max = 1;
        Bar.value = Done;
        Said = pas.JS.New(["waiting",window.t("waiting for them to take it"),"sending",window.t("sending"),"receiving",window.t("receiving"),"connecting",window.t("connecting"),"done",window.t("delivered")])[What];
        if (!Said) Said = What;
        State["textContent"] = Said;
      };
      if (M.from === pas.chat_shared.Me.name) {
        pas.chat_shared.S.beams[Payload.token] = Report;
        State.textContent = window.t("sent from this page, which has to stay open");
        Card.append(Bar,State);
      } else {
        Take = pas.chat_shared.El("button","primary",window.t("Take it"));
        Take.type = "button";
        Take.addEventListener("click",async function (E) {
          var Got = null;
          var Save = null;
          Take.remove();
          Card.append(Bar,State);
          try {
            Got = await window.Keys.beamReceive(Payload.token,Report);
            State.textContent = window.t("received");
            Save = pas.chat_shared.Link(URL.createObjectURL(Got),"primary",window.t("Save %s",Got["name"]));
            Save["download"] = Got["name"];
            Card.appendChild(Save);
            Save.click();
          } catch ($e) {
            State["textContent"] = $e["message"];
          };
        });
        Card.appendChild(Take);
        Card.appendChild(pas.chat_shared.El("span","state",window.t("straight from their browser, never stored on the server")));
      };
      Result = Card;
      return Result;
    };
  };
},["weborworker","chat_sidebar","chat_rooms","chat_messages","chat_answer","chat_menu","chat_sync","chat_panels","chat_composer","chat_complete"]);
rtl.module("chat_composer",["System","JS","Web","chat_shared"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  this.Fit = function (Area) {
    var List = null;
    Area.style["height"] = "auto";
    List = Area.closest("#main, #panel").querySelector("#stream, .threadlist");
    Area.style["height"] = "" + Math.max(Area.clientHeight,Math.min(Area.scrollHeight,300,(Area.clientHeight + List.clientHeight) - 24)) + "px";
  };
  this.InFence = function (Area) {
    var Result = false;
    var Fences = undefined;
    var Count = 0;
    Fences = Area.value.slice(0,Area.selectionStart).match(new RegExp("```","g"));
    if (Fences) {
      Count = Fences.length}
     else Count = 0;
    Result = (Count % 2) === 1;
    return Result;
  };
  this.RenderComposer = function (Area, Parent, Dm) {
    var DmName = "";
    var DraftKey = "";
    var Words = "";
    var Form = null;
    var Files = null;
    var Row = null;
    var Attach = null;
    var Code = null;
    var Answering = null;
    var Options = null;
    var Beam = null;
    var Area2 = null;
    var Send = null;
    var FilePick = null;
    var BeamPick = null;
    var Expire = null;
    var Draft = undefined;
    var Pending = null;
    var Chips = null;
    var Busy = null;
    var Asking = null;
    var Complete = null;
    var Sending = false;
    function Choice(Value, Caption) {
      var Opt = null;
      Opt = pas.chat_shared.El("option","",Caption);
      Opt.value = Value;
      Expire.appendChild(Opt);
    };
    function WhichSize(Chip, Data, Small) {
      var Result = null;
      var Ask = null;
      var Less = null;
      var All = null;
      var Smaller = null;
      var Done = null;
      function Choose(Picked) {
        Asking.delete(Smaller);
        Ask.remove();
        Done(Picked);
      };
      Result = new Promise(function (Resolve, Reject) {
        Done = Resolve;
        Ask = pas.chat_shared.El("span","sizes",undefined);
        Smaller = function () {
          Choose(Small);
        };
        Less = pas.chat_shared.El("button","",window.t("Smaller") + " · " + pas.chat_shared.SizeText(Small["size"]));
        All = pas.chat_shared.El("button","",window.t("Full size") + " · " + pas.chat_shared.SizeText(Data["size"]));
        All.type = "button";
        Less.type = "button";
        Less.addEventListener("click",Smaller);
        All.addEventListener("click",function (E) {
          Choose(Data);
        });
        Ask.append(Less,All);
        Chip.appendChild(Ask);
        Asking.add(Smaller);
      });
      return Result;
    };
    function Add(List) {
      var Run = null;
      var Waiting = null;
      function Closable(Chip, Done) {
        var X = null;
        X = pas.chat_shared.El("button","","×");
        X.type = "button";
        X.addEventListener("click",function (E) {
          Pending.splice(Pending.indexOf(Done),1);
          Chip.remove();
        });
        Chip.appendChild(X);
      };
      async function Worker() {
        var Result = undefined;
        var Next = null;
        var Data = null;
        var Chip = null;
        var Share = null;
        var Small = undefined;
        var Sent = undefined;
        var Done = undefined;
        function Goes(Which, Mine, Part) {
          var Result = null;
          var Sealed = undefined;
          if (Boolean(Dm) && pas.chat_shared.S.dmLocked) {
            Sealed = Dm}
           else Sealed = "";
          Result = $impl.Upload(Which,Expire.value,Sealed,function (Sent) {
            Part.textContent = "" + Math.round(Sent * 100) + "%";
            Mine.style.setProperty("--up","" + Math.round(Sent * 100) + "%");
          });
          return Result;
        };
        while (Waiting.length > 0) {
          Next = Waiting.shift();
          Data = Next["file"];
          Chip = Next["chip"];
          Share = pas.chat_shared.El("span","share","");
          try {
            Small = await window.Keys.smaller(Data);
            if (pas.chat_shared.Same(Small,Data)) {
              Sent = Data}
             else Sent = await WhichSize(Chip,Data,Small);
            Chip.appendChild(Share);
            Done = await Goes(Sent,Chip,Share).catch(function (Err) {
              var Result = undefined;
              if (pas.chat_shared.Same(Sent,Small)) throw Err;
              pas.chat_shared.Toast(window.t("That photo did not go up at full size. Sending it smaller."),undefined);
              Result = Goes(Small,Chip,Share);
              return Result;
            });
            Share.remove();
            Chip.style.removeProperty("--up");
            Pending.push(Done);
            Chips.set(Done,Chip);
            Chip.classList.remove("busy");
            Closable(Chip,Done);
          } catch ($e) {
            Chip.remove();
            pas.chat_shared.Failed($e);
          };
        };
        return Result;
      };
      async function Go() {
        var Result = undefined;
        Waiting = Array.from(List).map(function (Data, I, A) {
          var Result = undefined;
          var Name = undefined;
          var Chip = null;
          Name = Data["name"];
          if (!Name) Name = window.t("picture");
          Chip = pas.chat_shared.El("span","chip busy",Name);
          Files.appendChild(Chip);
          Result = pas.JS.New(["file",Data,"chip",Chip]);
          return Result;
        });
        await Promise.all([Worker(),Worker()]);
        return Result;
      };
      Run = Go();
      Busy.add(Run);
      Run.then(function (Value) {
        var Result = undefined;
        Busy.delete(Run);
        return Result;
      });
    };
    function Pick(Input, Button) {
      function OpenWith(Accept) {
        Input.accept = Accept;
        Input.click();
      };
      if (!(new RegExp("Android")).test(window.navigator.userAgent)) {
        Input.click();
        return;
      };
      pas.chat_shared.PopMenu(Button,Array.of(Array.of(window.t("Photos and videos"),function () {
        OpenWith("image/*,video/*");
      }),Array.of(window.t("Camera or file"),function () {
        OpenWith("");
      })));
    };
    async function Submit() {
      var Text = "";
      var Found = undefined;
      var Parts = null;
      var Each = null;
      var Sent = null;
      var I = 0;
      var At = 0;
      var Re = null;
      var Said = null;
      var P = undefined;
      var ParentOr = undefined;
      var ReId = undefined;
      if (Sending) return;
      if (Busy.size > 0) {
        Sending = true;
        Send.disabled = true;
        pas.chat_shared.Toast(window.t("Sending when the files are up"),undefined);
        Each = Array.from(Asking);
        for (var $l = 0, $end = Each.length - 1; $l <= $end; $l++) {
          I = $l;
          Each[I]();
        };
        while (Busy.size > 0) await Promise.all(Array.from(Busy));
        Sending = false;
        Send.disabled = false;
      };
      Text = Area2.value.trim();
      if ((Text === "") && (Pending.length === 0)) return;
      $impl.Drafts.delete(DraftKey);
      Found = Text.match(new RegExp("^\\/(\\w+)\\s*([\\s\\S]*)$"));
      Parts = Found;
      if (Boolean(Found) && Boolean(pas.chat_shared.Extras.commands["" + Parts[1]])) {
        Area2.value = "";
        $mod.Fit(Area2);
        pas.chat_shared.Extras.commands["" + Parts[1]].call(pas.chat_shared.Extras.commands,Parts[2]);
        return;
      };
      Found = Text.match(new RegExp("^\\/(msg|query)\\b\\s*@?([\\w.-]*)\\s*([\\s\\S]*)$"));
      if (Found) {
        Parts = Found;
        Area2.value = "";
        $mod.Fit(Area2);
        if (!Parts[2]) {
          $mod.Note(window.t("Use: /msg name text"),Boolean(Parent));
          return;
        };
        await pas.chat_shared.Route("/dm/" + pas.chat_shared.Enc(Parts[2]),true);
        if (Boolean(Parts[3]) && (pas.chat_shared.S.view === "dm")) try {
          await pas.chat_private.SendDm(pas.chat_shared.S.dm,"" + Parts[3],new Array());
        } catch ($e) {
          pas.chat_shared.Failed($e);
        };
        return;
      };
      Send.disabled = true;
      Sending = true;
      Sent = Pending.slice(0);
      try {
        try {
          if (Boolean(Dm) && await $mod.DmCommand(Text)) {
            Sent.length = 0}
           else if (Dm) {
            await pas.chat_private.SendDm(DmName,Text,Sent)}
           else {
            Re = pas.chat_answer.Answered(DraftKey);
            if (Boolean(Parent)) {
              ParentOr = Parent}
             else ParentOr = "";
            if (Boolean(Re)) {
              ReId = Re["id"]}
             else ReId = "";
            Said = JSON.parse(await pas.chat_shared.Post("/api/post",pas.JS.New(["room",pas.chat_shared.S.room,"parent",ParentOr,"body",Text,"files",Sent.map(function (F, N, A) {
              var Result = undefined;
              Result = F["token"];
              return Result;
            }).join(","),"re",ReId])));
            if (Re === pas.chat_answer.Answered(DraftKey)) pas.chat_answer.Answer("",null);
            if (Boolean(Said.info)) $mod.Note(Said.info,Boolean(Parent));
            if (Boolean(Said.go)) {
              Area2.value = "";
              Send.disabled = false;
              if (Boolean(Said.info)) pas.chat_shared.Toast(Said.info,undefined);
              if (Said.go === "/") pas.chat_shared.S.rooms = pas.chat_shared.S.rooms.filter(function (R, N, A) {
                var Result = false;
                Result = !pas.chat_shared.Same(R["slug"],pas.chat_shared.S.room);
                return Result;
              });
              pas.chat_shared.RoomsWanted = true;
              pas.chat_shared.Route(Said.go,true);
              return;
            };
          };
          if (Area2.value.trim() === Text) Area2.value = "";
          for (var $l1 = 0, $end1 = Sent.length - 1; $l1 <= $end1; $l1++) {
            I = $l1;
            P = Sent[I];
            At = Pending.indexOf(P);
            if (At >= 0) Pending.splice(At,1);
            if (Chips.has(P)) {
              Chips.get(P).remove();
              Chips.delete(P);
            };
          };
          $mod.Fit(Area2);
          if (!Dm) pas.chat_sync.SyncNow(Text.startsWith("/"));
        } catch ($e) {
          pas.chat_shared.Failed($e);
        };
      } finally {
        Sending = false;
      };
      Send.disabled = false;
      Area2.focus();
    };
    Area.replaceChildren();
    if (pas.chat_shared.Me.name === "") {
      Area.appendChild(pas.chat_shared.JoinForm(window.t("Pick a name and a password to join the conversation.")));
      return;
    };
    if (pas.chat_shared.Me.verified === false) {
      Area.appendChild(pas.chat_shared.ConfirmBox());
      return;
    };
    if (!Boolean(Dm) && Boolean(pas.chat_shared.S.info)) if ((Boolean(Parent) && pas.chat_shared.Same(pas.chat_shared.S.info.can_reply,false)) || (!Boolean(Parent) && !pas.chat_shared.S.info.can_start)) {
      Area.appendChild(pas.chat_shared.El("p","notice",pas.chat_shared.S.info.why_not));
      return;
    };
    DmName = "" + Dm;
    Form = pas.chat_shared.El("form","composer",undefined);
    Files = pas.chat_shared.El("div","attachments",undefined);
    Row = pas.chat_shared.El("div","box",undefined);
    Attach = pas.chat_shared.IconButton("attach",window.t("Attach a file (or paste or drop one)"),undefined);
    Area2 = pas.chat_shared.El("textarea",undefined,undefined);
    Area2.rows = 1;
    Area2.maxLength = 8000;
    if (Dm) {
      Words = window.t("Private message to %s",Dm)}
     else if (Boolean(Parent)) {
      Words = window.t("Reply in the thread")}
     else if (Boolean(pas.chat_shared.S.info) && (pas.chat_shared.S.info.kind === "shelf")) {
      Words = window.t("Put something on your shelf")}
     else if (Boolean(pas.chat_shared.S.info)) {
      Words = window.t("Message %s",pas.chat_rooms.RoomTitle(pas.chat_shared.S.info))}
     else Words = window.t("Message %s","");
    Area2.placeholder = Words;
    if (Dm) {
      DraftKey = "dm " + DmName}
     else if (Boolean(Parent)) {
      DraftKey = "thread " + ("" + Parent)}
     else DraftKey = "room " + pas.chat_shared.S.room;
    Draft = $impl.Drafts.get(DraftKey);
    if (!Draft) Draft = "";
    Area2.value = "" + Draft;
    Code = pas.chat_shared.IconButton("code",window.t("Code block"),undefined);
    Send = pas.chat_shared.El("button","send",window.t("Send"));
    Row.append(Attach,Area2,Code);
    Answering = pas.chat_shared.El("div","answering",undefined);
    Answering.dataset["key"] = DraftKey;
    if (Boolean(pas.chat_shared.S.answer) && (pas.chat_shared.S.answer.key !== DraftKey) && (!Boolean(Parent) || pas.chat_shared.S.answer.key.startsWith("thread "))) pas.chat_shared.S.answer = null;
    if (Dm) {
      Beam = pas.chat_shared.IconButton("beam",window.t("Beam a file: straight to them, never stored here"),undefined);
      Beam.addEventListener("click",function (E) {
        Pick(BeamPick,Beam);
      });
      Row.appendChild(Beam);
    };
    Row.appendChild(Send);
    FilePick = pas.chat_shared.El("input",undefined,undefined);
    FilePick.type = "file";
    FilePick.multiple = true;
    FilePick.hidden = true;
    BeamPick = pas.chat_shared.El("input",undefined,undefined);
    BeamPick.type = "file";
    BeamPick.hidden = true;
    Options = pas.chat_shared.El("div","options",undefined);
    Expire = pas.chat_shared.El("select",undefined,undefined);
    Choice("",window.t("Keep files"));
    Choice("hour",window.t("Delete after an hour"));
    Choice("day",window.t("Delete after a day"));
    Choice("week",window.t("Delete after a week"));
    Choice("once",window.t("Delete after one download"));
    Options.appendChild(Expire);
    Options.appendChild(pas.chat_shared.El("span","hints",window.t("Enter sends · Shift+Enter new line · ``` for code · / for commands")));
    Form.append(Answering,Files,Row,Options,FilePick,BeamPick);
    Area.appendChild(Form);
    pas.chat_answer.ShowAnswer();
    Pending = new Array();
    Chips = new Map();
    Busy = new Set();
    Asking = new Set();
    Attach.addEventListener("click",function (E) {
      Pick(FilePick,Attach);
    });
    FilePick.addEventListener("change",function (E) {
      Add(Array.from(FilePick.files));
      FilePick.value = "";
    });
    BeamPick.addEventListener("change",function (E) {
      var First = undefined;
      First = BeamPick.files["0"];
      if (First) pas.chat_private.BeamFile(DmName,First);
      BeamPick.value = "";
    });
    Area2.addEventListener("paste",function (E) {
      var Given = undefined;
      var List = null;
      Given = E["clipboardData"]["files"];
      if (!Given) Given = new Array();
      List = Array.from(Given);
      if (List.length > 0) {
        E.preventDefault();
        Add(List);
      };
    });
    Form.addEventListener("dragover",function (E) {
      E.preventDefault();
      Form.classList.add("drop");
    });
    Form.addEventListener("dragleave",function (E) {
      Form.classList.remove("drop");
    });
    Form.addEventListener("drop",function (E) {
      E.preventDefault();
      Form.classList.remove("drop");
      Add(Array.from(E["dataTransfer"]["files"]));
    });
    Code.addEventListener("click",function (E) {
      var At = 0;
      var Selected = "";
      At = Area2.selectionStart;
      Selected = Area2.value.slice(At,Area2.selectionEnd);
      Area2.setRangeText("```\n" + Selected + "\n```",At,Area2.selectionEnd,"end");
      Area2.selectionEnd = At + 4 + Selected.length;
      Area2.selectionStart = At + 4 + Selected.length;
      Area2.focus();
      $mod.Fit(Area2);
    });
    Complete = pas.chat_complete.Completer(Area2,function (Command) {
      var Result = false;
      Result = !Boolean(Dm) || Boolean(Command["anywhere"]);
      return Result;
    });
    Sending = false;
    Form.addEventListener("submit",function (E) {
      E.preventDefault();
      Submit();
    });
    Area2.addEventListener("keydown",function (E) {
      var Key = null;
      var Mine = null;
      var map = null;
      Key = E;
      if (Complete.handle(Key)) return;
      if ((Key.key === "Escape") && Boolean(pas.chat_answer.Answered(DraftKey))) pas.chat_answer.Answer("",null);
      if ((Key.key === "Enter") && !Key.shiftKey && !$mod.InFence(Area2)) {
        E.preventDefault();
        Submit();
      };
      if ((Key.key === "ArrowUp") && (Area2.value === "") && Boolean(Dm)) {
        Mine = Array.from(pas.chat_shared.Stream.querySelectorAll(".msg")).filter(function (X, N, A) {
          var Result = false;
          var D = null;
          D = X.dm;
          Result = Boolean(D) && pas.chat_shared.Same(D["m"]["from"],pas.chat_shared.Me.name) && (pas.chat_shared.Same(D["payload"]["t"],"text") || pas.chat_shared.Same(D["payload"]["t"],"file"));
          return Result;
        });
        if (Mine.length > 0) {
          E.preventDefault();
          pas.chat_private.StartDmEdit(Mine[Mine.length - 1]);
        };
      } else if ((Key.key === "ArrowUp") && (Area2.value === "")) {
        if (Boolean(Parent)) {
          map = pas.chat_shared.S.threadMessages}
         else map = pas.chat_shared.S.messages;
        Mine = Array.from(map.values()).filter(function (X, N, A) {
          var Result = false;
          var D = null;
          D = X["data"];
          Result = (D.name === pas.chat_shared.Me.name) && !D.deleted && Boolean(D.uid);
          return Result;
        });
        if (Mine.length > 0) {
          E.preventDefault();
          pas.chat_menu.StartEdit(Mine[Mine.length - 1]["data"]);
        };
      };
    });
    Area2.addEventListener("input",function (E) {
      $impl.Drafts.set(DraftKey,Area2.value);
      $mod.Fit(Area2);
      Complete.update();
      if (((Date.now() - pas.chat_shared.S.typingSent) > 3000) && (Area2.value !== "")) {
        pas.chat_shared.S.typingSent = Date.now();
        if (Dm) {
          pas.chat_shared.Post("/api/dm/typing",pas.JS.New(["to",Dm])).catch(function (Err) {
            var Result = undefined;
            return Result;
          })}
         else pas.chat_shared.Post("/api/typing",pas.JS.New(["room",pas.chat_shared.S.room])).catch(function (Err) {
          var Result = undefined;
          return Result;
        });
      };
    });
    $mod.Fit(Area2);
    if (!Boolean(Parent)) Area2.focus();
  };
  this.DmCommand = async function (Text) {
    var Result = false;
    var Found = undefined;
    var Parts = null;
    var Said = null;
    Found = Text.match(new RegExp("^\\/(\\S+)(?:\\s+([\\s\\S]*))?$"));
    if (!Found) return false;
    Parts = Found;
    if ((Parts[1].toLowerCase() === "me") && Boolean(Parts[2])) return false;
    if (!Boolean(pas.chat_shared.S.commands)) pas.chat_shared.S.commands = await pas.chat_shared.Get("/api/commands");
    if (!pas.chat_shared.S.commands.some(function (C, N, A) {
      var Result = false;
      Result = pas.chat_shared.Same(C["name"],Parts[1].toLowerCase());
      return Result;
    })) return false;
    Said = JSON.parse(await pas.chat_shared.Post("/api/post",pas.JS.New(["body",Text])));
    if (Boolean(Said.info)) $mod.Note(Said.info,false);
    if (Boolean(Said.go)) {
      pas.chat_shared.RoomsWanted = true;
      pas.chat_shared.Route(Said.go,true);
    };
    Result = true;
    return Result;
  };
  this.Note = function (Text, InThread) {
    var Box = null;
    var N = null;
    var X = null;
    if (InThread) {
      Box = pas.chat_shared.Find(".threadlist",pas.chat_shared.Panel)}
     else Box = pas.chat_shared.Stream;
    N = pas.chat_shared.El("div","note",undefined);
    N.appendChild(pas.chat_shared.El("pre","",Text));
    X = pas.chat_shared.El("button","",window.t("Dismiss"));
    X.type = "button";
    X.addEventListener("click",function (E) {
      N.remove();
    });
    N.appendChild(X);
    Box.appendChild(N);
    Box.scrollTop = Box.scrollHeight;
  };
  this.Start = function () {
    var View = undefined;
    var Target = null;
    View = window["visualViewport"];
    if (View) {
      Target = View}
     else Target = window;
    Target.addEventListener("resize",function (E) {
      var Areas = null;
      var I = 0;
      Areas = document.querySelectorAll(".composer textarea");
      for (var $l = 0, $end = Areas.length - 1; $l <= $end; $l++) {
        I = $l;
        $mod.Fit(Areas.item(I));
      };
    });
    $impl.Drafts = new Map();
  };
  $mod.$implcode = function () {
    $impl.Drafts = null;
    $impl.Upload = function (Data, Expire, SealedFor, Told) {
      var Result = null;
      var Form = null;
      var Name = undefined;
      if (SealedFor) return window.Keys.sealFile(SealedFor,Data,Expire);
      Form = new FormData();
      Form.append("expire",Expire);
      Name = Data["name"];
      if (!Name) Name = "pasted.png";
      Form.append("file",Data,Name);
      Result = new Promise(function (Resolve, Reject) {
        var Ask = null;
        Ask = new XMLHttpRequest();
        Ask.open("POST","/api/upload");
        if (Told !== null) Ask.upload.addEventListener("progress",function (E) {
          if (E.lengthComputable) Told(E.loaded / E.total);
        });
        Ask.addEventListener("load",function (E) {
          var Refused = null;
          if ((Ask.status >= 200) && (Ask.status < 300)) {
            try {
              Resolve(JSON.parse(Ask.responseText));
            } catch ($e) {
              Reject($e);
            };
            return;
          };
          Refused = new Error(Ask.responseText);
          Refused["status"] = Ask.status;
          Reject(Refused);
        });
        Ask.addEventListener("error",function (E) {
          Reject(new Error(window.t("The file did not go up. Check the connection and try again.")));
        });
        Ask.send(Form);
      });
      return Result;
    };
  };
},["chat_rooms","chat_answer","chat_sync","chat_menu","chat_private","chat_complete"]);
rtl.module("chat_panels",["System","JS","Web","chat_shared"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  this.OpenThread = async function (Id) {
    var Box = null;
    var List = null;
    var Area = null;
    var Messages = null;
    Box = pas.chat_shared.OpenPanel(window.t("Thread"),"thread");
    pas.chat_shared.S.thread = Id;
    pas.chat_shared.S.threadMessages.clear();
    List = pas.chat_shared.El("div","threadlist",undefined);
    Box.appendChild(List);
    pas.chat_shared.KeepPinned(List);
    if (window.SiteBase.path() !== ("/m/" + ("" + Id))) window.history.replaceState(new Object(),"","/m/" + ("" + Id));
    try {
      Messages = await pas.chat_shared.Get("/api/thread?id=" + ("" + Id));
      if (pas.chat_shared.S.thread !== Id) return;
      $mod.AddThread(Messages);
    } catch ($e) {
      pas.chat_shared.Failed($e);
    };
    Area = pas.chat_shared.El("div","panelcomposer",undefined);
    Box.appendChild(Area);
    pas.chat_composer.RenderComposer(Area,Id,undefined);
  };
  this.AddThread = function (Messages) {
    var List = null;
    var Root = null;
    var Count = null;
    var Stick = false;
    var I = 0;
    List = pas.chat_shared.Find(".threadlist",pas.chat_shared.Panel);
    if (!Boolean(List)) return;
    Stick = List.pinned || pas.chat_shared.NearBottom(List);
    for (var $l = 0, $end = Messages.length - 1; $l <= $end; $l++) {
      I = $l;
      pas.chat_rooms.Upsert(Messages[I],List,pas.chat_shared.S.threadMessages,true);
    };
    Root = List.querySelector(".msg");
    if (Boolean(Root) && !Boolean(pas.chat_shared.Find(".threadcount",List))) Root.after(pas.chat_shared.El("div","threadcount",undefined));
    Count = pas.chat_shared.Find(".threadcount",List);
    if (Boolean(Count)) Count.textContent = window.tn(pas.chat_shared.S.threadMessages.size - 1,"%d replies","%d replies");
    pas.chat_rooms.Regroup(List);
    if (Stick) List.scrollTop = List.scrollHeight;
  };
  this.OpenPins = async function () {
    var Box = null;
    var Holder = null;
    var List = null;
    var I = 0;
    Box = pas.chat_shared.OpenPanel(window.t("Pinned"),"pins");
    try {
      List = await pas.chat_shared.Get("/api/pins?room=" + pas.chat_shared.Enc(pas.chat_shared.S.room));
      if (!Boolean(List.length)) Box.appendChild(pas.chat_shared.El("p","notice",window.t("Nothing is pinned here. The channel's owner and moderators pin messages that should stay in view.")));
      Holder = pas.chat_shared.El("div","threadlist",undefined);
      for (var $l = 0, $end = List.length - 1; $l <= $end; $l++) {
        I = $l;
        Holder.appendChild(pas.chat_messages.RenderMessage(List[I],true));
      };
      Box.appendChild(Holder);
    } catch ($e) {
      pas.chat_shared.Failed($e);
    };
  };
  this.OpenMembers = async function () {
    var Info = null;
    var Box = null;
    var Here = null;
    var List = null;
    var Form = null;
    var Name = null;
    var Go = null;
    var I = 0;
    function AddHere(P) {
      var Who = null;
      var Row = null;
      Who = pas.chat_shared.Link("/u/" + pas.chat_shared.Enc(P.name),"who",undefined);
      Who.append(pas.chat_shared.Avatar(P.name,P.avatar,$impl.SmallFace(P)),$impl.StatusDot(true,P.away),pas.chat_shared.El("span","",P.name));
      Row = pas.chat_shared.El("div","person",undefined);
      Row.appendChild(Who);
      if (P.away) Row.appendChild(pas.chat_shared.El("span","role",window.t("away")));
      Here.appendChild(Row);
    };
    function AddMember(P) {
      var Who = null;
      var Row = null;
      var Out = null;
      Row = pas.chat_shared.El("div","person",undefined);
      Who = pas.chat_shared.Link("/u/" + pas.chat_shared.Enc(P.name),"who",undefined);
      Who.append(pas.chat_shared.Avatar(P.name,P.avatar,$impl.SmallFace(P)),$impl.StatusDot(P.online,P.away),pas.chat_shared.El("span","",P.name));
      Row.appendChild(Who);
      if (P.owner) Row.appendChild(pas.chat_shared.El("span","role",window.t("owner")));
      if (P.roles) Row.appendChild(pas.chat_shared.El("span","role",P.roles.replace("room-moderator",window.t("moderator"))));
      if (Info.private && pas.chat_shared.MayHere("kick") && !Boolean(P.owner) && (P.name !== pas.chat_shared.Me.name)) {
        Out = pas.chat_shared.El("button","small-link",window.t("Take out"));
        Out.type = "button";
        Out.addEventListener("click",async function (E) {
          await $mod.Command("/kick " + P.name);
          Show();
        });
        Row.appendChild(Out);
      };
      List.appendChild(Row);
    };
    async function Show() {
      var People = null;
      var N = 0;
      try {
        People = await pas.chat_shared.Get("/api/room/members?room=" + pas.chat_shared.Enc(Info.slug));
        List.replaceChildren();
        if (!Boolean(People.length)) if (Info.owner) {
          List.appendChild(pas.chat_shared.El("p","notice",window.t("%s owns this channel. Nobody else holds a role in it.",Info.owner)))}
         else List.appendChild(pas.chat_shared.El("p","notice",window.t("Nobody holds a role in this channel. Site moderators look after it.")));
        for (var $l = 0, $end = People.length - 1; $l <= $end; $l++) {
          N = $l;
          AddMember(People[N]);
        };
      } catch ($e) {
        pas.chat_shared.Failed($e);
      };
    };
    Info = pas.chat_shared.S.info;
    Box = pas.chat_shared.OpenPanel(window.t("People"),"members");
    if (Boolean(pas.chat_shared.S.here.length)) {
      Box.appendChild(pas.chat_shared.El("h4","",window.t("Here now")))}
     else Box.appendChild(pas.chat_shared.El("h4","",window.t("Nobody else is here right now")));
    Here = pas.chat_shared.El("div","memberlist",undefined);
    for (var $l = 0, $end = pas.chat_shared.S.here.length - 1; $l <= $end; $l++) {
      I = $l;
      AddHere(pas.chat_shared.S.here[I]);
    };
    Box.appendChild(Here);
    if (Info.private) {
      Box.appendChild(pas.chat_shared.El("h4","",window.t("In this channel")))}
     else Box.appendChild(pas.chat_shared.El("h4","",window.t("Channel moderators")));
    List = pas.chat_shared.El("div","memberlist",undefined);
    Box.appendChild(List);
    await Show();
    if (Info.private && pas.chat_shared.MayHere("invite")) {
      Form = pas.chat_shared.El("form","invite",undefined);
      Name = pas.chat_shared.El("input",undefined,undefined);
      Name.placeholder = window.t("Invite someone by name");
      Go = pas.chat_shared.El("button","primary",window.t("Invite"));
      Form.append(Name,Go);
      Form.addEventListener("submit",async function (E) {
        E.preventDefault();
        if (Name.value.trim() === "") return;
        await $mod.Command("/invite " + Name.value.trim());
        Name.value = "";
        Show();
      });
      Box.appendChild(Form);
    };
    if (Info.private) {
      Box.appendChild(pas.chat_shared.El("p","hint",window.t("Commands work too: /invite name, /kick name, /op name makes a channel moderator.")))}
     else Box.appendChild(pas.chat_shared.El("p","hint",window.t("The owner names channel moderators with /op name. /mute name [minutes] quiets someone here.")));
  };
  this.Command = async function (Text) {
    var Answer = null;
    try {
      Answer = JSON.parse(await pas.chat_shared.Post("/api/post",pas.JS.New(["room",pas.chat_shared.S.room,"body",Text])));
      if (Answer["info"]) pas.chat_shared.Toast(Answer["info"],undefined);
      pas.chat_sync.SyncNow(false);
    } catch ($e) {
      pas.chat_shared.Failed($e);
    };
  };
  this.NewRoom = function () {
    var Box = null;
    var Form = null;
    var NameLabel = null;
    var TopicLabel = null;
    var Kind = null;
    var Go = null;
    var Name = null;
    var Topic = null;
    var Priv = null;
    Box = pas.chat_shared.OpenPanel(window.t("Open a channel"),"newroom");
    pas.chat_shared.Body.classList.remove("menu");
    Form = pas.chat_shared.El("form","settings",undefined);
    NameLabel = pas.chat_shared.El("label",undefined,undefined);
    NameLabel.appendChild(pas.chat_shared.El("span","",window.t("Name")));
    Name = pas.chat_shared.El("input",undefined,undefined);
    Name.placeholder = window.t("lowercase-with-hyphens");
    Name.maxLength = 40;
    NameLabel.appendChild(Name);
    TopicLabel = pas.chat_shared.El("label",undefined,undefined);
    TopicLabel.appendChild(pas.chat_shared.El("span","",window.t("What it is for")));
    Topic = pas.chat_shared.El("input",undefined,undefined);
    TopicLabel.appendChild(Topic);
    Kind = pas.chat_shared.El("label","check",undefined);
    Priv = pas.chat_shared.El("input",undefined,undefined);
    Priv.type = "checkbox";
    Priv.checked = !pas.chat_shared.May("create-channel");
    Priv.disabled = !pas.chat_shared.May("create-channel") || !pas.chat_shared.May("create-private");
    Kind.append(Priv,document.createTextNode(window.t(" Private: only people invited see it")));
    Go = pas.chat_shared.El("button","primary",window.t("Open it"));
    Form.append(NameLabel,TopicLabel,Kind,Go);
    Box.appendChild(Form);
    Name.focus();
    Name.addEventListener("input",function (E) {
      Name.value = Name.value.toLowerCase().replace(new RegExp("[^a-z0-9-]+","g"),"-");
    });
    Form.addEventListener("submit",async function (E) {
      var Made = null;
      var Flag = "";
      E.preventDefault();
      try {
        if (Priv.checked) {
          Flag = "1"}
         else Flag = "0";
        Made = JSON.parse(await pas.chat_shared.Post("/api/room/create",pas.JS.New(["slug",Name.value.replace(new RegExp("^-+|-+$","g"),""),"topic",Topic.value,"private",Flag])));
        pas.chat_shared.RoomsWanted = true;
        pas.chat_shared.Route("/p/" + pas.chat_shared.Enc(Made["slug"]),true);
      } catch ($e) {
        pas.chat_shared.Failed($e);
      };
    });
  };
  this.OpenSearchAll = function () {
    var Head = null;
    var MenuButton = null;
    var Results = null;
    var Input = null;
    var Timer = 0;
    var Asked = 0;
    function AddHit(M) {
      var Node = null;
      var Header = null;
      Node = pas.chat_messages.RenderMessage(M,true);
      Node.classList.add("result");
      Header = Node.querySelector("header");
      if (Boolean(Header)) Header.appendChild(pas.chat_shared.El("span","where","#" + M.room));
      $impl.OpensMessage(Node,M);
      Results.appendChild(Node);
    };
    async function Run() {
      var Q = "";
      var Turn = 0;
      var I = 0;
      var List = null;
      $impl.AllWords = Input.value.trim();
      Q = $impl.AllWords;
      Asked += 1;
      Turn = Asked;
      if (Q.length < 2) {
        Results.replaceChildren();
        return;
      };
      try {
        List = await pas.chat_shared.Get("/api/search?q=" + pas.chat_shared.Enc(Q));
        if ((Turn !== Asked) || !Results.isConnected) return;
        Results.replaceChildren();
        if (!Boolean(List.length)) Results.appendChild(pas.chat_shared.El("p","notice",window.t("Nothing found.")));
        for (var $l = 0, $end = List.length - 1; $l <= $end; $l++) {
          I = $l;
          AddHit(List[I]);
        };
      } catch ($e) {
        pas.chat_shared.Failed($e);
      };
    };
    pas.chat_shared.S.view = "search";
    pas.chat_shared.S.title = window.t("Search all chats");
    Head = pas.chat_shared.Find("#roomhead",undefined);
    MenuButton = pas.chat_shared.IconButton("menu",window.t("Channels"),"menubtn");
    MenuButton.addEventListener("click",pas.chat_shared.ToggleMenu);
    Head.append(MenuButton,pas.chat_shared.El("div","titles",undefined));
    pas.chat_shared.Find(".titles",Head).appendChild(pas.chat_shared.El("h1","",pas.chat_shared.S.title));
    pas.chat_shared.Stream.className = "findall-view";
    pas.chat_shared.Stream.noPin = true;
    Input = pas.chat_shared.El("input",undefined,undefined);
    Input.type = "search";
    Input.placeholder = window.t("Words to find");
    Input.value = $impl.AllWords;
    Results = pas.chat_shared.El("div","findall-hits",undefined);
    pas.chat_shared.Stream.append(Input,pas.chat_shared.El("p","notice",window.t("Looks in every channel you can read. A private conversation is searched from inside it.")),Results);
    Timer = 0;
    Asked = 0;
    Input.addEventListener("input",function (E) {
      window.clearTimeout(Timer);
      Timer = window.setTimeout(function () {
        Run();
      },300);
    });
    Input.focus();
    if ($impl.AllWords !== "") Run();
  };
  this.OpenSearch = function () {
    var Box = null;
    var Scope = null;
    var Results = null;
    var Input = null;
    var Only = null;
    var InDm = false;
    var WithName = "";
    var Timer = 0;
    function AddFound(M, Payload) {
      var Node = null;
      Node = pas.chat_private.RenderDm(M,Payload);
      Node.classList.add("result");
      Node.querySelector(".more").remove();
      Node.menu = null;
      Node.addEventListener("click",function (E) {
        var There = null;
        if (Boolean(E.target.closest("a, button"))) return;
        There = pas.chat_shared.Stream.querySelector('.msg[data-id="' + ("" + M["id"]) + '"]');
        if (!Boolean(There) || (pas.chat_shared.S.dm !== WithName)) {
          pas.chat_shared.Toast(window.t("That message is further back."),undefined);
          return;
        };
        pas.chat_answer.Flash(There);
      });
      Results.appendChild(Node);
    };
    function AddHit(M) {
      var Node = null;
      Node = pas.chat_messages.RenderMessage(M,true);
      Node.classList.add("result");
      $impl.OpensMessage(Node,M);
      Results.appendChild(Node);
    };
    async function Run() {
      var Q = "";
      var Where = "";
      var Found = null;
      var List = null;
      var I = 0;
      var M = null;
      Q = Input.value.trim();
      if (Q.length < 2) {
        Results.replaceChildren();
        return;
      };
      try {
        if (InDm && Only.checked) {
          Found = await pas.chat_shared.Get("/api/dm/search?with=" + pas.chat_shared.Enc(WithName) + "&q=" + pas.chat_shared.Enc(Q));
          Results.replaceChildren();
          if (!Boolean(Found.length)) Results.appendChild(pas.chat_shared.El("p","notice",window.t("Nothing found.")));
          Found.reverse();
          for (var $l = 0, $end = Found.length - 1; $l <= $end; $l++) {
            I = $l;
            M = Found[I];
            AddFound(M,await pas.chat_private.OpenSealed(M));
          };
          return;
        };
        Where = "";
        if (Only.checked && !InDm) Where = "&room=" + pas.chat_shared.Enc(pas.chat_shared.S.room);
        List = await pas.chat_shared.Get("/api/search?q=" + pas.chat_shared.Enc(Q) + Where);
        Results.replaceChildren();
        if (!Boolean(List.length)) Results.appendChild(pas.chat_shared.El("p","notice",window.t("Nothing found.")));
        for (var $l1 = 0, $end1 = List.length - 1; $l1 <= $end1; $l1++) {
          I = $l1;
          AddHit(List[I]);
        };
      } catch ($e) {
        pas.chat_shared.Failed($e);
      };
    };
    Box = pas.chat_shared.OpenPanel(window.t("Search"),"search");
    Input = pas.chat_shared.El("input",undefined,undefined);
    Input.type = "search";
    Input.placeholder = window.t("Words to find");
    Scope = pas.chat_shared.El("label","scope",undefined);
    Only = pas.chat_shared.El("input",undefined,undefined);
    Only.type = "checkbox";
    InDm = pas.chat_shared.S.view === "dm";
    WithName = pas.chat_shared.S.dm;
    Only.checked = (pas.chat_shared.S.view === "room") || InDm;
    if (InDm) {
      Scope.append(Only,document.createTextNode(window.t(" only in this conversation")))}
     else Scope.append(Only,document.createTextNode(window.t(" only in this channel")));
    Results = pas.chat_shared.El("div","threadlist",undefined);
    Box.append(Input,Scope,Results);
    if (InDm && pas.chat_shared.S.dmLocked) Box.insertBefore(pas.chat_shared.El("p","notice",window.t("Locked messages are not searched: the server cannot read them.")),Results);
    Input.focus();
    Timer = 0;
    Input.addEventListener("input",function (E) {
      window.clearTimeout(Timer);
      Timer = window.setTimeout(function () {
        Run();
      },300);
    });
    Only.addEventListener("change",function (E) {
      Run();
    });
  };
  $mod.$implcode = function () {
    $impl.AllWords = "";
    $impl.StatusDot = function (Online, Away) {
      var Result = null;
      var State = "";
      if (Online) {
        if (Away) {
          State = "away"}
         else State = "online";
      } else State = "off";
      Result = pas.chat_shared.El("span","dot " + State,undefined);
      if (State === "online") {
        Result.title = window.t("Online")}
       else if (State === "away") {
        Result.title = window.t("Away")}
       else Result.title = window.t("Not here");
      return Result;
    };
    $impl.SmallFace = function (P) {
      var Result = "";
      if (P.away) {
        Result = "small away"}
       else Result = "small";
      return Result;
    };
    $impl.OpensMessage = function (Node, M) {
      Node.addEventListener("click",function (E) {
        if (Boolean(E.target.closest("a, button"))) return;
        pas.chat_shared.Route("/m/" + ("" + M.id),true);
      });
    };
  };
},["chat_rooms","chat_messages","chat_answer","chat_sync","chat_composer","chat_private"]);
rtl.module("chat_rooms",["System","JS","Web","chat_shared"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  this.RoomTitle = function (Info) {
    var Result = "";
    if (Info.kind === "channel") return "#" + Info.title;
    Result = Info.title;
    return Result;
  };
  this.RenderHead = function (Info, Extra) {
    var Head = null;
    var Menu = null;
    var Titles = null;
    var H = null;
    var Topic = null;
    var Here = null;
    var Tools = null;
    var Follow = null;
    var People = null;
    var Pins = null;
    var Search = null;
    var Words = undefined;
    var Cls = "";
    async function SetTopic(E) {
      var Next = undefined;
      var Was = undefined;
      if (Info.topic) {
        Was = Info.topic}
       else Was = "";
      Next = window.prompt(window.t("Topic for %s",$mod.RoomTitle(Info)),"" + Was);
      if (pas.chat_shared.Same(Next,null)) return;
      try {
        await pas.chat_shared.Post("/api/topic",pas.JS.New(["room",Info.slug,"topic",Next]));
        Info.topic = Next;
        if (Next) {
          Topic.textContent = "" + Next}
         else Topic.textContent = window.t("Add a topic");
      } catch ($e) {
        pas.chat_shared.Failed($e);
      };
    };
    async function SetFollow(E) {
      var Turn = "";
      if (Info.private && Info.following && !window.confirm(window.t("Leave %s? Only an invite gets you back in.",Info.title))) return;
      try {
        if (Info.following) {
          Turn = "0"}
         else Turn = "1";
        await pas.chat_shared.Post("/api/follow",pas.JS.New(["room",Info.slug,"on",Turn]));
        Info.following = !Info.following;
        if (Info.following) {
          Follow.textContent = window.t("Following")}
         else Follow.textContent = window.t("Follow");
        pas.chat_shared.Toggle(Follow,"on",Info.following);
        pas.chat_sync.SyncNow(true);
      } catch ($e) {
        pas.chat_shared.Failed($e);
      };
    };
    Head = pas.chat_shared.Find("#roomhead",undefined);
    Head.replaceChildren();
    Menu = pas.chat_shared.IconButton("menu",window.t("Channels"),"menubtn");
    Menu.addEventListener("click",pas.chat_shared.ToggleMenu);
    Head.appendChild(Menu);
    Titles = pas.chat_shared.El("div","titles",undefined);
    H = pas.chat_shared.El("h1",undefined,undefined);
    H.appendChild(pas.chat_shared.El("span","roomname",$mod.RoomTitle(Info)));
    if (Info.avatar) H.prepend(pas.chat_shared.Avatar(Info.title,Info.avatar,"small roomicon"));
    if (Info.private) {
      H.prepend(pas.chat_shared.Icon("lock"));
      H.appendChild(pas.chat_shared.El("span","kindtag",window.t("private")));
    } else if (Info.kind !== "channel") H.appendChild(pas.chat_shared.El("span","kindtag",Info.kind));
    Titles.appendChild(H);
    if (Info.topic) {
      Words = Info.topic}
     else Words = "";
    Topic = pas.chat_shared.El("p","topic",Words);
    if (Boolean(Info.can) && Boolean(Info.can["set-topic"])) {
      Topic.title = window.t("Click to change the topic");
      Topic.classList.add("editable");
      if (!Info.topic) Topic.textContent = window.t("Add a topic");
      Topic.addEventListener("click",SetTopic);
    };
    Titles.appendChild(Topic);
    Head.appendChild(Titles);
    Here = pas.chat_shared.El("button","here",undefined);
    Here.type = "button";
    Here.title = window.t("Who is here");
    Here.addEventListener("click",function (E) {
      pas.chat_panels.OpenMembers();
    });
    Head.appendChild(Here);
    Tools = pas.chat_shared.El("div","headtools",undefined);
    if (Extra !== null) Tools.appendChild(Extra);
    if ((pas.chat_shared.Me.name !== "") && (Info.kind !== "shelf")) {
      if (Info.following) {
        Cls = "on"}
       else Cls = "";
      if (Info.following) {
        Words = window.t("Following")}
       else Words = window.t("Follow");
      Follow = pas.chat_shared.El("button","pill " + Cls,Words);
      Follow.type = "button";
      if (Info.private) {
        Follow.title = window.t("If you leave a private channel, someone must invite you back")}
       else Follow.title = window.t("Followed channels sit in your sidebar with their unread counts");
      Follow.addEventListener("click",SetFollow);
      H.appendChild(Follow);
    };
    People = pas.chat_shared.IconButton("people",window.t("People: who is here, and who is in this channel or runs it"),undefined);
    People.addEventListener("click",function (E) {
      pas.chat_panels.OpenMembers();
    });
    Tools.appendChild(People);
    Pins = pas.chat_shared.IconButton("pin",window.t("Pinned messages"),undefined);
    Pins.addEventListener("click",function (E) {
      pas.chat_panels.OpenPins();
    });
    Search = pas.chat_shared.IconButton("search",window.t("Search"),undefined);
    Search.addEventListener("click",function (E) {
      pas.chat_panels.OpenSearch();
    });
    Tools.append(Pins,Search);
    Head.appendChild(Tools);
  };
  this.RenderHere = function (List) {
    var Box = null;
    var A = null;
    var Shown = null;
    var P = null;
    var I = 0;
    var Cls = "";
    Box = pas.chat_shared.Find("#roomhead .here",undefined);
    if (Box === null) return;
    Box.replaceChildren();
    pas.chat_shared.S.here = List;
    Shown = List.slice(0,6);
    for (var $l = 0, $end = Shown.length - 1; $l <= $end; $l++) {
      I = $l;
      P = Shown[I];
      if (P.away) {
        Cls = "tiny away"}
       else Cls = "tiny";
      A = pas.chat_shared.Avatar(P.name,P.avatar,Cls);
      if (P.away) {
        A.title = window.t("%s is away: %s",P.name,P.away)}
       else A.title = window.t("%s is here",P.name);
      Box.appendChild(A);
    };
    if (List.length !== 0) Box.appendChild(pas.chat_shared.El("span","count",window.tn(List.length,"%d here","%d here")));
  };
  this.NoteTyping = function (Names) {
    var I = 0;
    for (var $l = 0, $end = Names.length - 1; $l <= $end; $l++) {
      I = $l;
      if (!pas.chat_shared.Same(Names[I],pas.chat_shared.Me.name)) pas.chat_shared.S.typers["" + Names[I]] = Date.now() + 5000;
    };
    $mod.RenderTyping();
  };
  this.RenderTyping = function () {
    var Box = null;
    var Now = 0;
    var Names = null;
    var N = "";
    var I = 0;
    var Text = "";
    Box = pas.chat_shared.Find("#typing",undefined);
    Now = Date.now();
    Names = Object.keys(pas.chat_shared.S.typers);
    for (var $l = 0, $end = Names.length - 1; $l <= $end; $l++) {
      I = $l;
      N = "" + Names[I];
      if (Number(pas.chat_shared.S.typers[N]) < Now) pas.JS.JSDelete(pas.chat_shared.S.typers,N);
    };
    Names = Object.keys(pas.chat_shared.S.typers);
    if (Names.length === 0) {
      Box.replaceChildren();
      return;
    };
    if (Names.length === 1) {
      Text = window.t("%s is typing",Names[0])}
     else if (Names.length === 2) {
      Text = window.t("%s and %s are typing",Names[0],Names[1])}
     else Text = window.t("Several people are typing");
    Box.replaceChildren(pas.chat_shared.El("span","dots",undefined),pas.chat_shared.El("span","",Text));
  };
  this.OpenRoom = async function (Slug, Thread) {
    var Generation = 0.0;
    var Info = null;
    Generation = pas.chat_shared.S.generation;
    Info = await pas.chat_shared.Get("/api/room?slug=" + pas.chat_shared.Enc(Slug));
    if (Generation !== pas.chat_shared.S.generation) return;
    pas.chat_shared.S.view = "room";
    pas.chat_shared.S.room = Info.slug;
    pas.chat_shared.S.info = Info;
    pas.chat_shared.S.title = $mod.RoomTitle(Info);
    if (!Info.private) try {
      window.localStorage.setItem("last-room",Info.slug);
    } catch ($e) {
    };
    $mod.RenderHead(Info,null);
    $mod.RenderCard(Info);
    await $mod.LoadMessages(Generation);
    pas.chat_composer.RenderComposer(pas.chat_shared.Find("#composer-area",undefined),0,undefined);
    if (Boolean(Thread)) pas.chat_panels.OpenThread(Thread);
    pas.chat_sync.SyncNow(true);
  };
  this.LoadMessages = async function (Generation) {
    var Data = null;
    var M = null;
    var I = 0;
    Data = await pas.chat_shared.Get("/api/messages?room=" + pas.chat_shared.Enc(pas.chat_shared.S.room));
    if (Generation !== pas.chat_shared.S.generation) return;
    pas.chat_shared.S.lastRead = Data.last_read;
    pas.chat_shared.S.divider = 0;
    pas.chat_shared.S.since = Data.rev - 3000000;
    pas.chat_shared.S.oldest = Infinity;
    pas.chat_shared.S.older = Data.messages.length === 50;
    for (var $l = 0, $end = Data.messages.length - 1; $l <= $end; $l++) {
      I = $l;
      M = Data.messages[I];
      if (!Boolean(pas.chat_shared.S.divider) && (pas.chat_shared.Me.name !== "") && (M.id > pas.chat_shared.S.lastRead) && (M.name !== pas.chat_shared.Me.name) && (pas.chat_shared.S.lastRead > 0)) pas.chat_shared.S.divider = M.id;
    };
    $mod.AddMessages(Data.messages,true);
    if (Data.messages.length === 0) pas.chat_shared.Stream.appendChild($mod.EmptyNote());
  };
  this.EmptyNote = function () {
    var Result = null;
    var P = null;
    P = pas.chat_shared.El("div","empty",undefined);
    P.appendChild(pas.chat_shared.El("b","",window.t("Nothing said here yet.")));
    if (pas.chat_shared.Me.name !== "") {
      P.appendChild(pas.chat_shared.El("span","",window.t(" Say hello.")))}
     else P.appendChild(pas.chat_shared.El("span","",window.t(" Join to say hello.")));
    Result = P;
    return Result;
  };
  this.AddMessages = function (List, Initial) {
    var Stick = false;
    var Empty = null;
    var I = 0;
    Stick = Initial || pas.chat_shared.Stream.pinned || pas.chat_shared.NearBottom(undefined);
    Empty = pas.chat_shared.Find(".empty",pas.chat_shared.Stream);
    if ((Empty !== null) && (List.length !== 0)) Empty.remove();
    for (var $l = 0, $end = List.length - 1; $l <= $end; $l++) {
      I = $l;
      $mod.Upsert(List[I],pas.chat_shared.Stream,pas.chat_shared.S.messages,false);
    };
    $mod.Regroup(pas.chat_shared.Stream);
    if (Stick) {
      pas.chat_shared.Stream.scrollTop = pas.chat_shared.Stream.scrollHeight;
      pas.chat_shared.Stream.pinned = true;
    };
  };
  this.Upsert = function (M, Box, map, InThread) {
    var Old = null;
    var Node = null;
    var After = null;
    var Nodes = null;
    var I = 0;
    Old = map.get(M.id);
    if (Boolean(Old) && (Old.data.rev === M.rev)) return;
    Node = pas.chat_messages.RenderMessage(M,InThread);
    if (Boolean(Old)) {
      Old.node.replaceWith(Node)}
     else {
      After = null;
      Nodes = Box.querySelectorAll(":scope > .msg");
      for (var $l = Nodes.length - 1; $l >= 0; $l--) {
        I = $l;
        if (Number(Nodes.item(I).dataset["id"]) < M.id) {
          After = Nodes.item(I);
          break;
        };
      };
      if (After !== null) {
        After.after(Node)}
       else Box.prepend(Node);
    };
    map.set(M.id,pas.JS.New(["data",M,"node",Node]));
    if ((Box === pas.chat_shared.Stream) && (M.id < pas.chat_shared.S.oldest)) pas.chat_shared.S.oldest = M.id;
  };
  this.Regroup = function (Box) {
    var Lines = null;
    var Nodes = null;
    var Prev = null;
    var Node = null;
    var Line = null;
    var When = null;
    var Day = "";
    var Together = false;
    var I = 0;
    Lines = Box.querySelectorAll(":scope > .day, :scope > .divider");
    for (var $l = 0, $end = Lines.length - 1; $l <= $end; $l++) {
      I = $l;
      Lines.item(I).remove();
    };
    Prev = null;
    Nodes = Box.querySelectorAll(":scope > .msg");
    for (var $l1 = 0, $end1 = Nodes.length - 1; $l1 <= $end1; $l1++) {
      I = $l1;
      Node = Nodes.item(I);
      When = new Date(Node.dataset["at"]);
      Day = When.toDateString();
      if ((Prev === null) || ((new Date(Prev.dataset["at"])).toDateString() !== Day)) {
        Line = pas.chat_shared.El("div","day",undefined);
        Line.appendChild(pas.chat_shared.El("span","",pas.chat_shared.DayLabel(When)));
        Node.before(Line);
        Prev = null;
      };
      if ((Box === pas.chat_shared.Stream) && Boolean(pas.chat_shared.S.divider) && (Number(Node.dataset["id"]) === pas.chat_shared.S.divider)) {
        Line = pas.chat_shared.El("div","divider",undefined);
        Line.appendChild(pas.chat_shared.El("span","",window.t("New")));
        Node.before(Line);
        Prev = null;
      };
      Together = (Prev !== null) && (Prev.dataset["name"] === Node.dataset["name"]) && !Prev.classList.contains("system") && ((When.getTime() - (new Date(Prev.dataset["at"])).getTime()) < (6 * 60000)) && !Node.classList.contains("hasthread") && !Prev.classList.contains("hasthread");
      pas.chat_shared.Toggle(Node,"cont",Together);
      Prev = Node;
    };
    if ((Box === pas.chat_shared.Stream) && (pas.chat_shared.S.view === "dm")) pas.chat_private.MarkSeen();
  };
  this.RenderCard = function (Info) {
    var Card = null;
    var Show = null;
    var I = 0;
    Card = pas.chat_shared.Find("#card",undefined);
    Card.replaceChildren();
    for (var $l = 0, $end = pas.chat_shared.Extras.cards.length - 1; $l <= $end; $l++) {
      I = $l;
      Show = pas.chat_shared.Extras.cards[I];
      Show(Info,Card);
    };
  };
  this.Start = function () {
    window.setInterval(function () {
      if (rtl.length(Object.keys(pas.chat_shared.S.typers)) !== 0) $mod.RenderTyping();
    },1000);
    pas.chat_shared.Stream.addEventListener("scroll",$impl.StreamScrolled);
  };
  $mod.$implcode = function () {
    $impl.StreamScrolled = async function (E) {
      var Generation = 0.0;
      var Data = null;
      var Height = 0;
      var I = 0;
      if ((pas.chat_shared.Stream.scrollTop <= 80) && (pas.chat_shared.S.view === "dm")) {
        pas.chat_private.OlderDms();
        return;
      };
      if ((pas.chat_shared.Stream.scrollTop > 80) || !pas.chat_shared.S.older || (pas.chat_shared.S.view !== "room") || pas.chat_shared.S.loadingOlder) return;
      pas.chat_shared.S.loadingOlder = true;
      Generation = pas.chat_shared.S.generation;
      try {
        try {
          Data = await pas.chat_shared.Get("/api/messages?room=" + pas.chat_shared.Enc(pas.chat_shared.S.room) + "&before=" + ("" + pas.chat_shared.S.oldest));
          if (Generation !== pas.chat_shared.S.generation) return;
          Height = pas.chat_shared.Stream.scrollHeight;
          pas.chat_shared.S.older = Data.messages.length === 50;
          for (var $l = 0, $end = Data.messages.length - 1; $l <= $end; $l++) {
            I = $l;
            $mod.Upsert(Data.messages[I],pas.chat_shared.Stream,pas.chat_shared.S.messages,false);
          };
          $mod.Regroup(pas.chat_shared.Stream);
          pas.chat_shared.Stream.scrollTop = pas.chat_shared.Stream.scrollHeight - Height;
        } catch ($e) {
          pas.chat_shared.Failed($e);
        };
      } finally {
        pas.chat_shared.S.loadingOlder = false;
      };
    };
  };
},["chat_messages","chat_sync","chat_panels","chat_composer","chat_private"]);
rtl.module("chat_sync",["System","JS","Web","chat_shared"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  this.SyncNow = function (WithRooms) {
    if (WithRooms) pas.chat_shared.RoomsWanted = true;
    window.clearTimeout($impl.SyncTimer);
    $mod.Sync();
  };
  this.SidebarSoon = function (Ms) {
    if (Boolean($impl.SidebarTimer)) return;
    $impl.SidebarTimer = window.setTimeout(function () {
      $impl.SidebarTimer = 0;
      $mod.SyncNow(true);
    },Ms);
  };
  this.Sync = async function () {
    var Generation = 0.0;
    var Params = null;
    var A = null;
    var Dms = null;
    var Shown = undefined;
    var Wait = 0;
    if ($impl.Syncing) {
      $impl.Again = true;
      return;
    };
    $impl.Syncing = true;
    $impl.Again = false;
    Generation = pas.chat_shared.S.generation;
    Params = new URLSearchParams(pas.JS.New(["since",pas.chat_shared.S.since]));
    if (!pas.chat_shared.FromRing) Params.set("here","1");
    pas.chat_shared.FromRing = false;
    if (pas.chat_shared.S.view === "room") Params.set("room",pas.chat_shared.S.room);
    if (Boolean(pas.chat_shared.S.thread)) Params.set("thread",pas.chat_shared.S.thread);
    if (Boolean(pas.chat_shared.Live.id)) Params.set("live",pas.chat_shared.Live.id);
    if ((pas.chat_shared.Me.name !== "") && (pas.chat_shared.RoomsWanted || (!Boolean(pas.chat_shared.Live.id) && ((pas.chat_shared.S.tick % 5) === 0)))) Params.set("rooms","1");
    pas.chat_shared.RoomsWanted = false;
    if ((pas.chat_shared.S.view === "room") && !document.hidden && pas.chat_shared.NearBottom(undefined) && Boolean(pas.chat_shared.S.messages.size)) Params.set("read",Math.max.apply(null,Array.from(pas.chat_shared.S.messages.keys())));
    pas.chat_shared.S.tick = pas.chat_shared.S.tick + 1;
    try {
      A = await pas.chat_shared.Get("/api/sync?" + ("" + Params));
      if (Generation === pas.chat_shared.S.generation) {
        if (Boolean(A.messages)) pas.chat_rooms.AddMessages(A.messages,false);
        if (Boolean(A.thread)) pas.chat_panels.AddThread(A.thread);
        if (Boolean(A.typing)) pas.chat_rooms.NoteTyping(A.typing);
        if (Boolean(A.here)) pas.chat_rooms.RenderHere(A.here);
        if (A.more) {
          pas.chat_shared.S.since = A.messages[A.messages.length - 1].rev;
          $impl.Again = true;
        } else pas.chat_shared.S.since = Math.max(pas.chat_shared.S.since,A.rev - 3000000);
      };
      if (Boolean(A.rooms)) {
        Dms = A.dms;
        if (!Boolean(Dms)) Dms = new Array();
        pas.chat_sidebar.NotifyNews(A.rooms,Dms);
        pas.chat_shared.S.rooms = A.rooms;
        if (Boolean(A.dms)) {
          pas.chat_shared.S.dms = A.dms}
         else pas.chat_shared.S.dms = new Array();
        pas.chat_sidebar.RenderSidebar();
        Shown = false;
        if (pas.chat_shared.S.view === "dm") Shown = pas.chat_shared.S.dms.find(function (X, Index, All) {
          var Result = false;
          Result = X.name === pas.chat_shared.S.dm;
          return Result;
        });
        if (Shown) {
          if (Boolean(Shown.seen)) {
            pas.chat_shared.S.dmSeen = Shown.seen}
           else pas.chat_shared.S.dmSeen = 0;
          pas.chat_private.MarkSeen();
        };
      };
    } catch ($e) {
    };
    $impl.Syncing = false;
    window.clearTimeout($impl.SyncTimer);
    if ($impl.Again) {
      $mod.Sync();
      return;
    };
    if (Boolean(pas.chat_shared.Live.id)) {
      Wait = 50000}
     else if (document.hidden) {
      Wait = 15000}
     else Wait = 3000;
    $impl.SyncTimer = window.setTimeout(function () {
      $mod.Sync();
    },Wait);
  };
  this.Start = function () {
    document.addEventListener("visibilitychange",function (E) {
      if (document.hidden) return;
      $mod.SyncNow(true);
      if (Boolean(pas.chat_shared.S.dm)) pas.chat_private.PollDm(pas.chat_shared.S.generation);
    });
  };
  $mod.$implcode = function () {
    $impl.SyncTimer = 0;
    $impl.Syncing = false;
    $impl.Again = false;
    $impl.SidebarTimer = 0;
  };
},["chat_sidebar","chat_rooms","chat_panels","chat_private"]);
rtl.module("chat_messages",["System","JS","Web","chat_shared"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  this.RenderMessage = function (M, InThread) {
    var Result = null;
    var Node = null;
    var Gutter = null;
    var More = null;
    var Content = null;
    var Head = null;
    var Time = null;
    var Text = null;
    var Show = null;
    var Line = null;
    var A = null;
    var At = null;
    var Badge = null;
    var B = undefined;
    var I = 0;
    Node = pas.chat_shared.El("article","msg",undefined);
    Node.dataset["id"] = "" + M.id;
    Node.dataset["at"] = M.at;
    Node.dataset["name"] = M.name;
    if (!M.uid) Node.classList.add("system");
    if (M.name === pas.chat_shared.Me.name) Node.classList.add("mine");
    if (M.mentions_me) Node.classList.add("mention");
    if (M.deleted) Node.classList.add("deleted");
    if (Boolean(M.replies) && !InThread) Node.classList.add("hasthread");
    Gutter = pas.chat_shared.El("div","gutter",undefined);
    if (M.uid) {
      A = pas.chat_shared.Link("/u/" + pas.chat_shared.Enc(M.name),"face",undefined);
      A.appendChild(pas.chat_shared.Avatar(M.name,M.avatar,undefined));
      Gutter.appendChild(A);
    } else Gutter.appendChild(pas.chat_shared.Avatar(M.name,"","bot"));
    At = new Date(M.at);
    if (!M.deleted) {
      More = pas.chat_shared.IconButton("down",window.t("More"),"more");
      More.setAttribute("aria-haspopup","menu");
      More.setAttribute("aria-expanded","false");
      More.addEventListener("click",function (E) {
        if ((pas.chat_shared.Menu !== null) && (pas.chat_shared.Menu.node === Node)) {
          pas.chat_menu.CloseMenu(true)}
         else pas.chat_menu.OpenMenu(Node,null);
      });
      Gutter.appendChild(More);
      Node.menu = function () {
        var Result = null;
        Result = pas.chat_menu.MessageMenu(M,InThread);
        return Result;
      };
    };
    Node.appendChild(Gutter);
    Content = pas.chat_shared.El("div","content",undefined);
    Head = pas.chat_shared.El("header",undefined,undefined);
    if (M.uid) {
      Head.appendChild(pas.chat_shared.Link("/u/" + pas.chat_shared.Enc(M.name),"who",M.name))}
     else Head.appendChild(pas.chat_shared.El("b","who",M.name));
    if (M.badge) Head.appendChild(pas.chat_shared.El("span","role",M.badge));
    for (var $l = 0, $end = pas.chat_shared.Extras.badges.length - 1; $l <= $end; $l++) {
      I = $l;
      Badge = pas.chat_shared.Extras.badges[I];
      B = Badge(M);
      if (B) Head.appendChild(B);
    };
    if ((M.room !== pas.chat_shared.S.room) && !InThread) Head.appendChild(pas.chat_shared.Link("/p/" + pas.chat_shared.Enc(M.room),"where","#" + M.room));
    Time = pas.chat_shared.El("time","",pas.chat_shared.Clock(At));
    Time.title = window.dateTimeText(At);
    Head.appendChild(Time);
    if (M.edited && !M.deleted) Head.appendChild(pas.chat_shared.El("span","edited",window.t("(edited)")));
    if (M.pinned) Head.appendChild(pas.chat_shared.El("span","pinned",window.t("pinned")));
    Content.appendChild(Head);
    Text = pas.chat_shared.El("div","body",undefined);
    if (M.deleted) {
      Text.textContent = window.t("This message was deleted.")}
     else {
      Text.innerHTML = M.html;   // safe html: rendered by the server, members' HTML escaped;
      pas.chat_menu.DressCode(Text);
    };
    if (Boolean(M.re) && !M.deleted) Content.appendChild(pas.chat_answer.QuoteOf(M.re,function () {
      pas.chat_shared.Route("/m/" + ("" + M.re["id"]),true);
    }));
    Content.appendChild(Text);
    if (!M.deleted) $impl.FoldLong(Text,Content);
    if (Boolean(M.preview) && !M.deleted) Content.appendChild($mod.PreviewOf(M.preview));
    if (M.ignored && !M.deleted) {
      Node.classList.add("ignored");
      Show = pas.chat_shared.El("button","unfold",window.t("A message from %s, whom you ignore. Show it",M.name));
      Show.type = "button";
      Show.addEventListener("click",function (E) {
        Node.classList.remove("ignored");
        Show.remove();
      });
      Content.insertBefore(Show,Text);
    };
    if (Boolean(M.files) && Boolean(M.files.length)) Content.appendChild($mod.RenderFiles(M.files));
    if (Boolean(M.reactions) && Boolean(M.reactions.length)) Content.appendChild($mod.RenderReactions(M));
    if (Boolean(M.replies) && !InThread) {
      Line = pas.chat_shared.El("button","threadline",undefined);
      Line.type = "button";
      Line.appendChild(pas.chat_shared.Icon("reply"));
      Line.appendChild(pas.chat_shared.El("b","",window.tn(M.replies,"%d reply","%d replies")));
      Line.appendChild(pas.chat_shared.El("span","",window.t("last %s",pas.chat_shared.Ago(M.last_reply))));
      Line.addEventListener("click",function (E) {
        pas.chat_panels.OpenThread(M.id);
      });
      Content.appendChild(Line);
    };
    Node.appendChild(Content);
    pas.chat_shared.C.pinWatch.observe(Node);
    Result = Node;
    return Result;
  };
  this.RenderFiles = function (Files) {
    var Result = null;
    var Box = null;
    var F = null;
    var A = null;
    var Img = null;
    var I = 0;
    Box = pas.chat_shared.El("div","files",undefined);
    for (var $l = 0, $end = Files.length - 1; $l <= $end; $l++) {
      I = $l;
      F = Files[I];
      if (F.image) {
        A = pas.chat_shared.Link(F.url,"shot",undefined);
        Img = pas.chat_shared.El("img",undefined,undefined);
        Img.src = F.url;
        Img.alt = F.name;
        Img.loading = "lazy";
        A.appendChild(Img);
        Box.appendChild(A);
      } else {
        A = pas.chat_shared.Link(F.url,"file",undefined);
        A.appendChild(pas.chat_shared.Icon("attach"));
        A.appendChild(pas.chat_shared.El("span","fname",F.name));
        A.appendChild(pas.chat_shared.El("span","fsize",pas.chat_shared.SizeText(F.size)));
        if (F.once) {
          A.appendChild(pas.chat_shared.El("span","fexp",window.t("deletes after one download")))}
         else if (F.expires) A.appendChild(pas.chat_shared.El("span","fexp",window.t("until %s",window.dateTimeText(F.expires))));
        Box.appendChild(A);
      };
    };
    Result = Box;
    return Result;
  };
  this.RenderReactions = function (M) {
    var Result = null;
    Result = window.Reactions.chips(M.reactions,pas.JS.New(["toggle",function (R) {
      $mod.React(M.id,R["r"],M.dm);
    },"who",function (R) {
      var Result = null;
      var Url = "";
      if (M.dm) {
        Url = "/api/dm/reacted"}
       else Url = "/api/reacted";
      Result = pas.chat_shared.Get(Url + "?id=" + ("" + M.id) + "&r=" + pas.chat_shared.Enc(R["r"]));
      return Result;
    }]));
    return Result;
  };
  this.React = async function (Id, R, Dm) {
    if (pas.chat_shared.Me.name === "") {
      pas.chat_shared.Toast(window.t("Join to react."),undefined);
      return;
    };
    try {
      if (Dm) {
        await pas.chat_shared.Post("/api/dm/react",pas.JS.New(["id",Id,"r",R]));
        pas.chat_private.RefreshDm(Id);
        return;
      };
      await pas.chat_shared.Post("/api/react",pas.JS.New(["id",Id,"r",R]));
      pas.chat_sync.SyncNow(false);
    } catch ($e) {
      pas.chat_shared.Failed($e);
    };
  };
  this.PreviewOf = function (P) {
    var Result = null;
    var Pre = null;
    var Box = null;
    var Line = null;
    var More = null;
    var Go = null;
    var Host = undefined;
    var Title = undefined;
    Pre = P;
    Box = pas.chat_shared.El("div","preview",undefined);
    Line = pas.chat_shared.El("button","line",undefined);
    Line.type = "button";
    Host = Pre.site;
    if (!Host) try {
      Host = (new URL(Pre.url)).host;
    } catch ($e) {
      Host = "";
    };
    if (Pre.title) {
      Title = Pre.title}
     else Title = Pre.url;
    Line.append(pas.chat_shared.El("span","site",Host),pas.chat_shared.El("span","title",Title));
    Line.title = Pre.url;
    More = pas.chat_shared.El("div","more",undefined);
    More.hidden = true;
    if (Pre.description) More.appendChild(pas.chat_shared.El("p","",Pre.description));
    Go = pas.chat_shared.El("a","small-link",window.t("Open the page"));
    Go.href = Pre.url;
    Go.target = "_blank";
    Go.rel = "noopener nofollow ugc";
    More.appendChild(Go);
    Line.addEventListener("click",function (E) {
      var Open = false;
      var Img = null;
      Open = Box.classList.toggle("open");
      More.hidden = !Open;
      if (Open && Boolean(Pre.image) && (More.querySelector("img") === null)) {
        Img = pas.chat_shared.El("img",undefined,undefined);
        Img.alt = "";
        Img.referrerPolicy = "no-referrer";
        Img.src = Pre.image;
        More.prepend(Img);
      };
    });
    Box.append(Line,More);
    Result = Box;
    return Result;
  };
  $mod.$implcode = function () {
    $impl.FoldLong = function (Text, Content) {
      window.requestAnimationFrame(function (Time) {
        var Whole = null;
        if ((Text.parentNode === null) || (Text.scrollHeight <= 640)) return;
        Text.classList.add("folded");
        Whole = pas.chat_shared.El("button","unfold whole",window.t("Show all"));
        Whole.type = "button";
        Whole.setAttribute("aria-expanded","false");
        Whole.addEventListener("click",function (E) {
          var Open = false;
          Open = Text.classList.contains("folded");
          if (Open) {
            Text.classList.remove("folded")}
           else Text.classList.add("folded");
          if (Open) {
            Whole.textContent = window.t("Show less")}
           else Whole.textContent = window.t("Show all");
          Whole.setAttribute("aria-expanded","" + Open);
          if (!Open) Text.scrollIntoView(pas.JS.New(["block","nearest"]));
        });
        Content.insertBefore(Whole,Text.nextSibling);
      });
    };
  };
},["chat_answer","chat_menu","chat_sync","chat_panels","chat_private"]);
rtl.module("chat_menu",["System","JS","Web","chat_shared"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  this.MessageMenu = function (M, InThread) {
    var Result = null;
    var Items = null;
    var MayReact = false;
    var AsSent = false;
    var From = "";
    var PinTitle = "";
    var Entry = null;
    var React = null;
    Items = new Array();
    MayReact = (pas.chat_shared.Me.name !== "") && pas.chat_shared.MayHere("react");
    if (Boolean(pas.chat_shared.S.thread) && ((M.parent === pas.chat_shared.S.thread) || (InThread && (M.id === pas.chat_shared.S.thread)))) {
      From = "thread " + ("" + pas.chat_shared.S.thread)}
     else if (InThread) {
      From = ""}
     else From = "room " + M.room;
    if ((From !== "") && Boolean(pas.chat_answer.AnswerStrip(From))) Items.push($impl.Item("reply",window.t("Answer this message"),function () {
      var Words = undefined;
      Words = pas.chat_answer.FirstWords(M.body);
      if (!Words) if (M.files.length !== 0) {
        Words = M.files[0]["name"]}
       else Words = window.t("code");
      pas.chat_answer.Answer(From,pas.JS.New(["id",M.id,"from",M.name,"text",Words]));
    }));
    if (MayReact && !InThread && !Boolean(M.parent)) Items.push($impl.Item("reply",window.t("Reply in a thread"),function () {
      pas.chat_panels.OpenThread(M.id);
    }));
    if (Boolean(M.body)) Items.push($impl.Item("copy",window.t("Copy the text"),function () {
      window.navigator.clipboard.writeText(M.body).then(function (Value) {
        var Result = undefined;
        pas.chat_shared.Toast(window.t("Text copied."),undefined);
        return Result;
      });
    }));
    Items.push($impl.Item("link",window.t("Copy a link to this"),function () {
      window.navigator.clipboard.writeText(window.location.origin + window.SiteBase.url("/m/" + ("" + M.id))).then(function (Value) {
        var Result = undefined;
        pas.chat_shared.Toast(window.t("Link copied."),undefined);
        return Result;
      });
    }));
    AsSent = Boolean(pas.chat_shared.S.info) && pas.chat_shared.S.info.as_sent;
    if ((M.name === pas.chat_shared.Me.name) && Boolean(M.uid) && pas.chat_shared.May("edit-own") && !AsSent) Items.push($impl.Item("edit",window.t("Edit"),function () {
      $mod.StartEdit(M);
    }));
    if (pas.chat_shared.MayHere("pin") && !Boolean(M.parent)) {
      if (M.pinned) {
        PinTitle = window.t("Unpin")}
       else PinTitle = window.t("Pin to the channel");
      Items.push($impl.Item("pin",PinTitle,async function () {
        try {
          await pas.chat_shared.Post("/api/pin",pas.JS.New(["id",M.id]));
          pas.chat_sync.SyncNow(false);
        } catch ($e) {
          pas.chat_shared.Failed($e);
        };
      }));
    };
    if (!AsSent && (((M.name === pas.chat_shared.Me.name) && Boolean(M.uid) && pas.chat_shared.May("delete-own")) || pas.chat_shared.MayHere("delete-any"))) {
      Entry = $impl.Item("trash",window.t("Delete"),async function () {
        if (!window.confirm(window.t("Delete this message?"))) return;
        try {
          await pas.chat_shared.Post("/api/delete",pas.JS.New(["id",M.id]));
          pas.chat_sync.SyncNow(false);
        } catch ($e) {
          pas.chat_shared.Failed($e);
        };
      });
      Entry.bad = true;
      Items.push(Entry);
    };
    React = null;
    if (MayReact) React = function (R) {
      pas.chat_messages.React(M.id,R,false);
    };
    Result = pas.JS.New(["react",React,"items",Items]);
    return Result;
  };
  this.CloseMenu = function (Refocus) {
    if (!Boolean(pas.chat_shared.Menu)) return;
    pas.chat_shared.Menu.box.remove();
    pas.chat_shared.Menu.node.classList.remove("held");
    pas.chat_shared.Menu.arrow.setAttribute("aria-expanded","false");
    if (Refocus) pas.chat_shared.Menu.arrow.focus(pas.JS.New(["preventScroll",true]));
    pas.chat_shared.Menu = null;
  };
  this.OpenMenu = function (Node, At) {
    var Offer = null;
    var Arrow = null;
    var Box = null;
    var List = null;
    var First = null;
    var Buttons = null;
    var Pick = null;
    var Place = null;
    var I = 0;
    function Entry(B) {
      var Result = null;
      B.type = "button";
      B.tabIndex = -1;
      B.setAttribute("role","menuitem");
      Result = B;
      return Result;
    };
    function Choice(B, Run) {
      var Result = null;
      Entry(B).addEventListener("click",function (E) {
        $mod.CloseMenu(true);
        Run();
      });
      Result = B;
      return Result;
    };
    function Add(It) {
      var B = null;
      if (It.bad && Boolean(List.lastChild) && !List.lastChild.classList.contains("bad")) List.appendChild(pas.chat_shared.El("hr",undefined,undefined));
      if (It.bad) {
        B = Choice(pas.chat_shared.El("button","bad",undefined),It.run)}
       else B = Choice(pas.chat_shared.El("button","",undefined),It.run);
      B.append(pas.chat_shared.Icon(It.icon),pas.chat_shared.El("span","",It.title));
      List.appendChild(B);
    };
    $mod.CloseMenu(false);
    Offer = Node.menu();
    Arrow = Node.querySelector(":scope > .gutter > .more");
    if (!Boolean(Offer.react) && (Offer.items.length === 0)) return;
    Box = pas.chat_shared.El("div","msgmenu",undefined);
    Box.setAttribute("role","menu");
    Box.tabIndex = -1;
    Place = function () {
      if (Boolean(At)) {
        window.Reactions.under(Box,pas.JS.New(["left",At["x"],"top",At["y"],"bottom",At["y"]]))}
       else window.Reactions.under(Box,Arrow.getBoundingClientRect());
    };
    if (Node.classList.contains("cont")) Box.appendChild(pas.chat_shared.El("div","when",window.dateTimeText(new Date(Node.dataset["at"]))));
    if (Boolean(Offer.react)) {
      Pick = function (R) {
        $mod.CloseMenu(true);
        Offer.react(R);
      };
      window.Reactions.offer(Box,pas.chat_shared.Me.reactions,Pick,Place);
      Buttons = Box.querySelectorAll("button");
      for (var $l = 0, $end = Buttons.length - 1; $l <= $end; $l++) {
        I = $l;
        Entry(Buttons.item(I));
      };
    };
    List = pas.chat_shared.El("div","items",undefined);
    for (var $l1 = 0, $end1 = Offer.items.length - 1; $l1 <= $end1; $l1++) {
      I = $l1;
      Add(Offer.items[I]);
    };
    Box.appendChild(List);
    Box.addEventListener("keydown",function (E) {
      var Key = "";
      var Shown = null;
      var Dest = undefined;
      Key = E.key;
      if ((Key === "Escape") || (Key === "Tab")) {
        if (Key === "Escape") E.preventDefault();
        $mod.CloseMenu(true);
        return;
      };
      Shown = Array.from(Box.querySelectorAll("button")).filter(function (B, Index, All) {
        var Result = false;
        Result = Boolean(B.offsetParent);
        return Result;
      });
      if (Shown.includes(document.activeElement)) {
        Dest = $impl.MenuStep(Shown,document.activeElement,Key)}
       else if ((new RegExp("^(Arrow|Home|End)")).test(Key)) {
        Dest = Shown[0]}
       else Dest = null;
      if (!Dest) return;
      E.preventDefault();
      Dest.focus();
    });
    document.body.appendChild(Box);
    Place();
    Node.classList.add("held");
    Arrow.setAttribute("aria-expanded","true");
    pas.chat_shared.Menu = pas.JS.New(["box",Box,"node",Node,"arrow",Arrow]);
    if (Boolean(At)) {
      First = Box}
     else First = Box.querySelector("button");
    First.focus(pas.JS.New(["preventScroll",true]));
  };
  this.StartEdit = function (M) {
    var Entry = undefined;
    var Text = null;
    var Box = null;
    var Area = null;
    var Save = null;
    var Cancel = null;
    var Complete = null;
    function Done() {
      Box.replaceWith(Text);
    };
    async function Store() {
      try {
        await pas.chat_shared.Post("/api/edit",pas.JS.New(["id",M.id,"body",Area.value]));
        Done();
        pas.chat_sync.SyncNow(false);
      } catch ($e) {
        pas.chat_shared.Failed($e);
      };
    };
    Entry = pas.chat_shared.S.messages.get(M.id);
    if (!Entry) Entry = pas.chat_shared.S.threadMessages.get(M.id);
    if (!Entry) return;
    Text = Entry.node.querySelector(".body");
    Box = pas.chat_shared.El("div","editbox",undefined);
    Area = pas.chat_shared.El("textarea",undefined,undefined);
    Area.value = M.body;
    Save = pas.chat_shared.El("button","primary",window.t("Save"));
    Cancel = pas.chat_shared.El("button","",window.t("Cancel"));
    Cancel.type = "button";
    Save.type = "button";
    Box.append(Area,Save,Cancel);
    Text.replaceWith(Box);
    Area.focus();
    pas.chat_composer.Fit(Area);
    Complete = pas.chat_complete.Completer(Area,null);
    Save.addEventListener("click",function (E) {
      Store();
    });
    Cancel.addEventListener("click",function (E) {
      Done();
    });
    Area.addEventListener("input",function (E) {
      pas.chat_composer.Fit(Area);
      Complete.update();
    });
    Area.addEventListener("keydown",function (E) {
      if (Complete.handle(E)) return;
      if (E.key === "Escape") Done();
      if ((E.key === "Enter") && !E.shiftKey && !pas.chat_composer.InFence(Area)) {
        E.preventDefault();
        Store();
      };
    });
  };
  this.DressCode = function (Root) {
    var Boxes = null;
    var I = 0;
    function Dress(Box) {
      var Pre = null;
      var Code = null;
      var Mark = null;
      var Flip = null;
      var Nums = null;
      var Fold = null;
      var Lines = 0;
      var N = 0;
      var Id = "";
      var List = "";
      var Name = undefined;
      function Say() {
        var Shut = false;
        Shut = Box.classList.contains("folded");
        if (Shut) {
          Fold.textContent = window.tn(Lines,"Show all %d line","Show all %d lines")}
         else Fold.textContent = window.t("Show less");
        if (Shut) {
          Fold.setAttribute("aria-expanded","false")}
         else Fold.setAttribute("aria-expanded","true");
      };
      Pre = Box.querySelector(":scope > pre");
      Code = Pre;
      if (Boolean(Pre)) Code = Pre.querySelector(":scope > code");
      if (!Boolean(Code) || Boolean(Pre.querySelector(".nums"))) return;
      Lines = Code.textContent.replace(new RegExp("\\n+$"),"").split("\n").length;
      Mark = Box.querySelector(":scope > .codebar span");
      if (Boolean(Mark)) {
        Id = Mark.textContent.trim().toLowerCase();
        Name = $impl.CODE_NAMES[Id];
        if (!Name) Name = Mark.textContent.trim();
        Mark["textContent"] = Name;
        if (Lines > 1) Mark.after(pas.chat_shared.El("span","codelines",window.tn(Lines,"%d line","%d lines")));
      };
      Flip = Box.querySelector(":scope > .codebar .flip");
      if (Boolean(Flip)) {
        Flip.textContent = window.t("Source");
        Flip.setAttribute("aria-pressed","false");
      };
      if (Lines < 2) return;
      Nums = pas.chat_shared.El("span","nums",undefined);
      Nums.setAttribute("aria-hidden","true");
      List = "";
      for (var $l = 1, $end = Lines; $l <= $end; $l++) {
        N = $l;
        List = List + ("" + N) + "\n";
      };
      Nums.textContent = List;
      Pre.prepend(Nums);
      Box.classList.add("numbered");
      if (Lines <= (20 + 5)) return;
      Box.classList.add("folded");
      Fold = pas.chat_shared.El("button","codefold",undefined);
      Fold.type = "button";
      Fold.addEventListener("click",function (E) {
        Box.classList.toggle("folded");
        Say();
        if (Box.classList.contains("folded") && (Box.getBoundingClientRect().top < 0)) Box.scrollIntoView(pas.JS.New(["block","nearest"]));
      });
      Say();
      Box.appendChild(Fold);
    };
    Boxes = Root.querySelectorAll(".code");
    for (var $l = 0, $end = Boxes.length - 1; $l <= $end; $l++) {
      I = $l;
      Dress(Boxes.item(I));
    };
  };
  this.Start = function () {
    var Lightbox = null;
    document.addEventListener("pointerdown",function (E) {
      if (Boolean(pas.chat_shared.Menu) && !pas.chat_shared.Menu.box.contains(E.target) && !pas.chat_shared.Menu.arrow.contains(E.target)) $mod.CloseMenu(false);
    },true);
    document.addEventListener("scroll",function (E) {
      if (Boolean(pas.chat_shared.Menu) && !pas.chat_shared.Menu.box.contains(E.target)) $mod.CloseMenu(true);
    },true);
    window.addEventListener("resize",function (E) {
      $mod.CloseMenu(true);
    });
    $impl.CODE_NAMES = pas.JS.New(["pascal","Pascal","lfm","LFM","bash","Bash","javascript","JavaScript","js","JavaScript","typescript","TypeScript","ts","TypeScript","css","CSS","html","HTML","xml","XML","sql","SQL","json","JSON","ini","INI","yaml","YAML","toml","TOML","go","Go","c","C","cpp","C++","csharp","C#","java","Java","kotlin","Kotlin","swift","Swift","rust","Rust","zig","Zig","d","D","python","Python","ruby","Ruby","lua","Lua","php","PHP","perl","Perl","basic","BASIC","diff","Diff","makefile","Makefile","asm","Assembly","batch","Batch","powershell","PowerShell","dockerfile","Dockerfile","fortran","Fortran","ada","Ada","barye","Barye","markdown","Markdown","md","Markdown","rst","reStructuredText","restructuredtext","reStructuredText"]);
    document.addEventListener("click",function (E) {
      var Flip = null;
      var Copy = null;
      var Box = null;
      var Shot = null;
      var Source = false;
      var Img = null;
      Flip = E.target.closest(".code .flip");
      if (Boolean(Flip)) {
        Box = Flip.closest(".code");
        Source = Box.classList.toggle("source");
        if (Source) {
          Flip.textContent = window.t("Rendered")}
         else Flip.textContent = window.t("Source");
        if (Source) {
          Flip.setAttribute("aria-pressed","true")}
         else Flip.setAttribute("aria-pressed","false");
        return;
      };
      Copy = E.target.closest(".code .copy");
      if (Boolean(Copy)) {
        window.navigator.clipboard.writeText(Copy.closest(".code").querySelector(":scope > pre > code").textContent).then(function (Value) {
          var Result = undefined;
          Copy.textContent = window.t("Copied");
          window.setTimeout(function () {
            Copy.textContent = window.t("Copy");
          },1500);
          return Result;
        });
        return;
      };
      Shot = E.target.closest("a.shot");
      if (Boolean(Shot) && !E.ctrlKey && !E.metaKey) {
        E.preventDefault();
        Box = pas.chat_shared.Find("#lightbox",undefined);
        Img = pas.chat_shared.El("img",undefined,undefined);
        Img.src = Shot.href;
        Box.replaceChildren(Img);
        Box.hidden = false;
        pas.chat_shared.LayerOpened();
      };
    });
    Lightbox = pas.chat_shared.Find("#lightbox",undefined);
    Lightbox.addEventListener("click",function (E) {
      Lightbox.hidden = true;
      pas.chat_shared.LayerClosed();
    });
  };
  $mod.$implcode = function () {
    $impl.FOLD_LINES = 20;
    $impl.CODE_NAMES = null;
    $impl.Item = function (Icon, Title, Run) {
      var Result = null;
      Result = pas.JS.New(["icon",Icon,"title",Title,"run",Run]);
      return Result;
    };
    $impl.MenuStep = function (Buttons, Here, Key) {
      var Result = undefined;
      var I = 0;
      var N = 0;
      var K = 0;
      var Down = false;
      var From = null;
      var R = null;
      var Best = undefined;
      var Row = 0.0;
      var Off = 0.0;
      var Far = 0.0;
      var Aside = 0.0;
      I = Buttons.indexOf(Here);
      N = Buttons.length;
      if (Key === "Home") return Buttons[0];
      if (Key === "End") return Buttons[N - 1];
      if (Key === "ArrowRight") return Buttons[(I + 1) % N];
      if (Key === "ArrowLeft") return Buttons[((I + N) - 1) % N];
      if ((Key !== "ArrowDown") && (Key !== "ArrowUp")) return null;
      Down = Key === "ArrowDown";
      From = Here.getBoundingClientRect();
      Best = null;
      Row = 0;
      Off = 0;
      for (var $l = 0, $end = N - 1; $l <= $end; $l++) {
        K = $l;
        R = Buttons[K].getBoundingClientRect();
        if (Down) {
          if (R.top < (From.bottom - 1)) continue;
        } else if (R.bottom > (From.top + 1)) continue;
        Far = Math.abs(R.top - From.top);
        Aside = Math.abs(R.left - From.left);
        if (!Boolean(Best) || (Far < (Row - 1)) || ((Far < (Row + 1)) && (Aside < Off))) {
          Best = Buttons[K];
          Row = Far;
          Off = Aside;
        };
      };
      if (Best) return Best;
      if (Down) {
        Result = Buttons[0]}
       else Result = Buttons[N - 1];
      return Result;
    };
  };
},["chat_answer","chat_messages","chat_sync","chat_panels","chat_composer","chat_complete"]);
rtl.module("chat_sidebar",["System","JS","Web","chat_shared"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  this.RenderSidebar = function () {
    var Nav = null;
    var Words = "";
    var Unread = 0.0;
    var List = null;
    var I = 0;
    var Head = null;
    var Name = undefined;
    var Count = "";
    function AddRoom(G, R) {
      var Href = "";
      var Badge = "";
      var A = null;
      var Quiet = false;
      var Lock = null;
      var More = null;
      var Items = null;
      if (R.kind === "shelf") {
        Href = "/u/" + pas.chat_shared.Enc(R.title)}
       else Href = "/p/" + pas.chat_shared.Enc(R.slug);
      A = pas.chat_shared.Link(Href,"room",undefined);
      A.dataset["slug"] = R.slug;
      if (R.slug === pas.chat_shared.S.room) A.classList.add("active");
      Quiet = R.notify === "none";
      if (Quiet) A.classList.add("quiet");
      if (Boolean(R.unread) && !Quiet && (R.notify !== "mentions")) A.classList.add("unread");
      if (R.private) {
        Lock = pas.chat_shared.El("span","sigil",undefined);
        Lock.appendChild(pas.chat_shared.Icon("lock"));
        A.appendChild(Lock);
      } else if (R.avatar) {
        A.appendChild(pas.chat_shared.Avatar(R.title,R.avatar,"tiny roomicon"))}
       else A.appendChild(pas.chat_shared.El("span","sigil",G.sigil));
      A.appendChild(pas.chat_shared.El("span","name",R.title));
      if (Boolean(R.mentions) && !Quiet) {
        A.appendChild(pas.chat_shared.El("span","badge mention","@" + ("" + R.mentions)))}
       else if (Boolean(R.unread) && !Quiet && (R.notify !== "mentions")) {
        if (R.unread > 99) {
          Badge = "99+"}
         else Badge = "" + R.unread;
        A.appendChild(pas.chat_shared.El("span","badge",Badge));
      };
      Items = $impl.RoomMenuItems(R);
      if (Items.length !== 0) {
        More = pas.chat_shared.IconButton("down",window.t("More"),"rowmenu");
        More.addEventListener("click",function (E) {
          E.preventDefault();
          E.stopPropagation();
          pas.chat_shared.PopMenu(More,Items);
        });
        A.appendChild(More);
      };
      Nav.appendChild(A);
      if (!Quiet) Unread = Unread + R.mentions;
    };
    function AddGroup(G) {
      var Rooms = null;
      var Head = null;
      var Add = null;
      var Extra = null;
      var Title = undefined;
      var J = 0;
      Rooms = pas.chat_shared.S.rooms.filter(G.test).filter(function (Room, Index, All) {
        var Result = false;
        Result = (Words === "") || Room.title.toLowerCase().includes(Words,0) || Room.slug.includes(Words,0);
        return Result;
      });
      Head = pas.chat_shared.El("div","group",undefined);
      if (pas.chat_shared.Same(G.title,"Channels")) {
        Title = window.t("Channels")}
       else if (pas.chat_shared.Same(G.title,"Shelves")) {
        Title = window.t("Shelves")}
       else if (pas.chat_shared.Same(G.title,"Benches")) {
        Title = window.t("Benches")}
       else Title = G.title;
      Head.appendChild(pas.chat_shared.El("span","",Title));
      if (pas.chat_shared.Same(G.title,"Channels") && (pas.chat_shared.May("create-private") || pas.chat_shared.May("create-channel"))) {
        Add = pas.chat_shared.IconButton("plus",window.t("Open a channel"),undefined);
        Add.classList.add("small");
        Add.addEventListener("click",function (E) {
          pas.chat_panels.NewRoom();
        });
        Head.appendChild(Add);
      };
      if (Boolean(G.button)) {
        Extra = pas.chat_shared.El("button","small-link",G.button["label"]);
        Extra.type = "button";
        Extra.addEventListener("click",G.button["click"]);
        Head.appendChild(Extra);
      };
      if ((Rooms.length === 0) && !Boolean(G.always)) return;
      Nav.appendChild(Head);
      for (var $l = 0, $end = Rooms.length - 1; $l <= $end; $l++) {
        J = $l;
        AddRoom(G,Rooms[J]);
      };
    };
    function AddDm(D) {
      var A = null;
      var More = null;
      if ((Words !== "") && !D.name.toLowerCase().includes(Words,0)) return;
      A = pas.chat_shared.Link("/dm/" + pas.chat_shared.Enc(D.name),"room person",undefined);
      if ((pas.chat_shared.S.view === "dm") && (pas.chat_shared.S.dm === D.name)) A.classList.add("active");
      if (Boolean(D.unread)) A.classList.add("unread");
      A.append(pas.chat_shared.Avatar(D.name,D.avatar,"tiny"),pas.chat_shared.El("span","name",D.name));
      if (Boolean(D.unread)) A.appendChild(pas.chat_shared.El("span","badge mention","" + D.unread));
      More = pas.chat_shared.IconButton("down",window.t("More"),"rowmenu");
      More.addEventListener("click",function (E) {
        E.preventDefault();
        E.stopPropagation();
        pas.chat_shared.PopMenu(More,Array.of(Array.of(window.t("Delete conversation"),function () {
          $mod.DeleteDm(D.name);
        })));
      });
      A.appendChild(More);
      Nav.appendChild(A);
      Unread = Unread + D.unread;
    };
    function AddPeople() {
      var J = 0;
      var K = 0;
      var Name = "";
      var Known = false;
      var A = null;
      var Shown = false;
      Shown = false;
      for (var $l = 0, $end = $impl.People.length - 1; $l <= $end; $l++) {
        J = $l;
        Name = "" + $impl.People[J]["name"];
        Known = Name === pas.chat_shared.Me.name;
        for (var $l1 = 0, $end1 = pas.chat_shared.S.dms.length - 1; $l1 <= $end1; $l1++) {
          K = $l1;
          if (pas.chat_shared.S.dms[K].name === Name) Known = true;
        };
        if (Known) continue;
        if (!Shown) {
          Head = pas.chat_shared.El("div","group",undefined);
          Head.appendChild(pas.chat_shared.El("span","",window.t("Start a private chat")));
          Nav.appendChild(Head);
          Shown = true;
        };
        A = pas.chat_shared.Link("/dm/" + pas.chat_shared.Enc(Name),"room person",undefined);
        A.append(pas.chat_shared.Avatar(Name,$impl.People[J]["avatar"],"tiny"),pas.chat_shared.El("span","name",Name));
        A.title = window.t("Start a private chat with %s",Name);
        Nav.appendChild(A);
      };
    };
    function AddNotice(N) {
      var A = null;
      A = pas.chat_shared.Link($impl.NoticePath(N.link),"room notice unread",undefined);
      A.append(pas.chat_shared.El("span","sigil","!"),pas.chat_shared.El("span","name",N.text));
      A.title = N.text;
      A.addEventListener("click",function (E) {
        var Dest = "";
        E.preventDefault();
        Dest = A.getAttribute("href");
        pas.chat_shared.Post("/api/notices",pas.JS.New(["id","" + N.id])).catch(function (Why) {
          var Result = undefined;
          return Result;
        }).then(function (Value) {
          var Result = undefined;
          window.location.assign(Dest);
          return Result;
        });
      });
      Nav.appendChild(A);
    };
    Nav = pas.chat_shared.Find("#roomlist",undefined);
    Words = pas.chat_shared.Find("#jump",undefined).value.toLowerCase().trim();
    Nav.replaceChildren();
    Unread = 0;
    List = Array.of($impl.Groups[0]).concat(pas.chat_shared.Extras.groups,$impl.Groups.slice(1));
    for (var $l = 0, $end = List.length - 1; $l <= $end; $l++) {
      I = $l;
      AddGroup(List[I]);
    };
    if (pas.chat_shared.S.dms.length !== 0) {
      Head = pas.chat_shared.El("div","group",undefined);
      Head.appendChild(pas.chat_shared.El("span","",window.t("Private")));
      Nav.appendChild(Head);
      for (var $l1 = 0, $end1 = pas.chat_shared.S.dms.length - 1; $l1 <= $end1; $l1++) {
        I = $l1;
        AddDm(pas.chat_shared.S.dms[I]);
      };
    };
    if ((Words !== "") && ($impl.PeopleFor === Words) && ($impl.People !== null)) AddPeople();
    if (Boolean(pas.chat_shared.Notices.unseen)) {
      Head = pas.chat_shared.El("div","group",undefined);
      Head.appendChild(pas.chat_shared.El("span","",window.t("Notices")));
      Nav.appendChild(Head);
      for (var $l2 = 0, $end2 = pas.chat_shared.Notices.items.length - 1; $l2 <= $end2; $l2++) {
        I = $l2;
        AddNotice(pas.chat_shared.Notices.items[I]);
      };
      if (pas.chat_shared.Notices.unseen > pas.chat_shared.Notices.items.length) Nav.appendChild(pas.chat_shared.El("div","hint",window.tn(pas.chat_shared.Notices.unseen - pas.chat_shared.Notices.items.length,"%d more notice","%d more notices")));
      Unread = Unread + pas.chat_shared.Notices.unseen;
    };
    if (Boolean(Unread)) {
      Count = "(" + ("" + Unread) + ") "}
     else Count = "";
    if (pas.chat_shared.S.title) {
      Name = pas.chat_shared.S.title}
     else Name = pas.chat_shared.Site;
    document.title = Count + ("" + Name) + " - " + ("" + pas.chat_shared.Site);
  };
  this.DeleteDm = async function (Name) {
    if (!window.confirm(window.t("Delete your conversation with %s?\n\nYour copy is gone for good. %s keeps theirs. If they write again, a new conversation starts.",Name,Name))) return;
    try {
      await pas.chat_shared.Post("/api/dm/delete",pas.JS.New(["with",Name]));
      pas.chat_shared.S.dms = pas.chat_shared.S.dms.filter(function (D, Index, All) {
        var Result = false;
        Result = D.name !== Name;
        return Result;
      });
      $mod.RenderSidebar();
      if ((pas.chat_shared.S.view === "dm") && (pas.chat_shared.S.dm === Name)) pas.chat_shared.Route("/",true);
      pas.chat_shared.Toast(window.t("Conversation deleted."),undefined);
    } catch ($e) {
      pas.chat_shared.Failed($e);
    };
  };
  this.NotifyNews = function (Rooms, Dms) {
    var Seen = null;
    var News = null;
    var R = null;
    var D = null;
    var Key = "";
    var Sign = "";
    var I = 0;
    Seen = pas.chat_shared.S.alerts;
    News = new Array();
    for (var $l = 0, $end = Rooms.length - 1; $l <= $end; $l++) {
      I = $l;
      R = Rooms[I];
      Key = "r:" + R.slug;
      if (!pas.chat_shared.Same(Seen[Key],undefined) && (R.mentions > Number(Seen[Key])) && (R.notify !== "none") && (document.hidden || (R.slug !== pas.chat_shared.S.room))) {
        if (R.kind === "channel") {
          Sign = "#"}
         else Sign = "";
        News.push(window.t("You were mentioned in %s",Sign + R.title));
      };
      Seen[Key] = R.mentions;
    };
    for (var $l1 = 0, $end1 = Dms.length - 1; $l1 <= $end1; $l1++) {
      I = $l1;
      D = Dms[I];
      Key = "d:" + D.name;
      if (!pas.chat_shared.Same(Seen[Key],undefined) && (D.unread > Number(Seen[Key])) && (document.hidden || (pas.chat_shared.S.dm !== D.name))) News.push(window.t("%s sent you a private message",D.name));
      Seen[Key] = D.unread;
    };
    if (News.length === 0) return;
    if (pas.JS.jsIn("Notification",window) && (Notification.permission === "granted") && document.hidden) {
      pas.chat_shared.Notify(pas.chat_shared.Site,News.join("\n"))}
     else News.forEach(function (N, Index, All) {
      pas.chat_shared.Toast(N,undefined);
    });
  };
  this.Start = function () {
    var FindAll = null;
    FindAll = document.getElementById("findall");
    if (FindAll !== null) {
      FindAll.hidden = false;
      FindAll.prepend(window.Side.icon("search"));
      FindAll.addEventListener("click",function (E) {
        document.body.classList.remove("menu");
        pas.chat_shared.Route("/chat-search",true);
      });
    };
    $impl.Groups = Array.of(pas.JS.New(["title","Channels","sigil","#","test",function (R, Index, All) {
      var Result = false;
      Result = R.kind === "channel";
      return Result;
    }]),pas.JS.New(["title","Benches","sigil","","test",function (R, Index, All) {
      var Result = false;
      Result = R.kind === "bench";
      return Result;
    }]),pas.JS.New(["title","Shelves","sigil","~","test",function (R, Index, All) {
      var Result = false;
      Result = R.kind === "shelf";
      return Result;
    }]));
    pas.chat_shared.Find("#jump",undefined).addEventListener("input",function (E) {
      $mod.RenderSidebar();
      $impl.LookForPeople(pas.chat_shared.Find("#jump",undefined).value.toLowerCase().trim());
    });
    pas.chat_shared.Find("#jump",undefined).addEventListener("keydown",function (E) {
      var First = null;
      if (E.key !== "Enter") return;
      First = pas.chat_shared.Find("#roomlist a.room",undefined);
      if (First !== null) {
        pas.chat_shared.Route(window.SiteBase.strip(First.getAttribute("href")),true);
        E.currentTarget.value = "";
        $impl.LookForPeople("");
        $mod.RenderSidebar();
      };
    });
    document.addEventListener("contextmenu",function (E) {
      var Node = null;
      var OnArrow = null;
      Node = E.target.closest(".msg");
      if ((Node === null) || !Node.menu) return;
      OnArrow = E.target.closest(".more");
      if ((OnArrow === null) && (E.shiftKey || !$impl.MenuHere(Node,E.target))) return;
      E.preventDefault();
      if (($impl.Hold !== null) && ($impl.Hold.opened === Node)) return;
      $impl.DropHold();
      if (OnArrow !== null) {
        pas.chat_menu.OpenMenu(Node,null)}
       else pas.chat_menu.OpenMenu(Node,pas.JS.New(["x",E.clientX,"y",E.clientY]));
    });
    document.addEventListener("touchstart",function (E) {
      var Touches = null;
      var Node = null;
      var Held = null;
      $impl.DropHold();
      Touches = E.touches;
      if (Touches.length !== 1) return;
      Node = E.target.closest(".msg");
      if ((Node === null) || !Node.menu || !$impl.MenuHere(Node,E.target)) return;
      Held = pas.JS.New(["x",Touches[0].clientX,"y",Touches[0].clientY]);
      Held.timer = window.setTimeout(function () {
        Held.opened = Node;
        pas.chat_menu.OpenMenu(Node,Held);
      },500);
      $impl.Hold = Held;
    },pas.JS.New(["passive",true]));
    document.addEventListener("touchmove",function (E) {
      var Touches = null;
      Touches = E.touches;
      if (($impl.Hold !== null) && !Boolean($impl.Hold.opened) && (Math.hypot(Touches[0].clientX - $impl.Hold.x,Touches[0].clientY - $impl.Hold.y) > 10)) $impl.DropHold();
    },pas.JS.New(["passive",true]));
    document.addEventListener("touchend",function (E) {
      if (($impl.Hold !== null) && Boolean($impl.Hold.opened) && E.cancelable) E.preventDefault();
      $impl.DropHold();
    });
    document.addEventListener("touchcancel",function (E) {
      $impl.DropHold();
    });
  };
  $mod.$implcode = function () {
    $impl.HOLD_MS = 500;
    $impl.HOLD_SLIP = 10;
    $impl.Groups = null;
    $impl.Hold = null;
    $impl.People = null;
    $impl.PeopleFor = "";
    $impl.PeopleAsked = 0;
    $impl.PeopleTimer = 0;
    $impl.LookForPeople = function (Words) {
      var Turn = 0;
      window.clearTimeout($impl.PeopleTimer);
      $impl.PeopleAsked += 1;
      Turn = $impl.PeopleAsked;
      if ((Words === "") || (pas.chat_shared.Me.name === "")) {
        $impl.People = null;
        $impl.PeopleFor = "";
        return;
      };
      $impl.PeopleTimer = window.setTimeout(function () {
        pas.chat_shared.Get("/api/users?q=" + pas.chat_shared.Enc(Words)).then(function (Found) {
          var Result = undefined;
          if (Turn !== $impl.PeopleAsked) return Result;
          $impl.People = Found;
          $impl.PeopleFor = Words;
          $mod.RenderSidebar();
          return Result;
        }).catch(function (Why) {
          var Result = undefined;
          return Result;
        });
      },200);
    };
    $impl.NoticePath = function (Path) {
      var Result = undefined;
      if ((typeof(Path) === "string") && (Path.charAt(0) === "/") && (Path.charAt(1) !== "/") && (Path.charAt(1) !== "\\")) {
        Result = Path}
       else Result = "/";
      return Result;
    };
    $impl.RoomMenuItems = function (R) {
      var Result = null;
      var Items = null;
      Items = new Array();
      if ((pas.chat_shared.Me.name === "") || (R.kind === "shelf")) return Items;
      if (R.notify !== "none") Items.push(Array.of(window.t("Silence channel"),function () {
        $impl.SetNotify(R,"none");
      }));
      if (R.notify !== "mentions") Items.push(Array.of(window.t("Mentions only"),function () {
        $impl.SetNotify(R,"mentions");
      }));
      if (Boolean(R.notify) && (R.notify !== "all")) Items.push(Array.of(window.t("Notify about everything"),function () {
        $impl.SetNotify(R,"all");
      }));
      Items.push(Array.of(window.t("Leave channel"),function () {
        $impl.LeaveRoom(R);
      }));
      if (R.private && Boolean(R.owner)) Items.push(Array.of(window.t("Delete channel"),function () {
        $impl.DeleteRoom(R);
      }));
      Result = Items;
      return Result;
    };
    $impl.SetNotify = async function (R, Mode) {
      try {
        await pas.chat_shared.Post("/api/follow/notify",pas.JS.New(["room",R.slug,"mode",Mode]));
        R.notify = Mode;
        $mod.RenderSidebar();
        if (Mode === "none") {
          pas.chat_shared.Toast(window.t("%s is silenced.",R.title),undefined)}
         else if (Mode === "mentions") {
          pas.chat_shared.Toast(window.t("Only mentions in %s from now on.",R.title),undefined)}
         else pas.chat_shared.Toast(window.t("%s notifies about everything again.",R.title),undefined);
      } catch ($e) {
        pas.chat_shared.Failed($e);
      };
    };
    $impl.LeaveRoom = async function (R) {
      if (R.private && !window.confirm(window.t("Leave %s? Only an invite gets you back in.",R.title))) return;
      try {
        await pas.chat_shared.Post("/api/follow",pas.JS.New(["room",R.slug,"on","0"]));
        pas.chat_shared.S.rooms = pas.chat_shared.S.rooms.filter(function (X, Index, All) {
          var Result = false;
          Result = X.slug !== R.slug;
          return Result;
        });
        $mod.RenderSidebar();
        if ((pas.chat_shared.S.view === "room") && (pas.chat_shared.S.room === R.slug)) {
          pas.chat_shared.Route("/",true)}
         else pas.chat_sync.SyncNow(true);
      } catch ($e) {
        pas.chat_shared.Failed($e);
      };
    };
    $impl.DeleteRoom = async function (R) {
      var Said = undefined;
      if (!window.confirm(window.t("Delete %s?\n\nEverything said in it and every file goes, for everyone in it. This cannot be undone.",R.title))) return;
      try {
        Said = await pas.chat_shared.Post("/api/room/delete",pas.JS.New(["slug",R.slug]));
        pas.chat_shared.S.rooms = pas.chat_shared.S.rooms.filter(function (X, Index, All) {
          var Result = false;
          Result = X.slug !== R.slug;
          return Result;
        });
        $mod.RenderSidebar();
        if ((pas.chat_shared.S.view === "room") && (pas.chat_shared.S.room === R.slug)) pas.chat_shared.Route("/",true);
        if (typeof(Said) === "string") {
          pas.chat_shared.Toast(Said,undefined)}
         else pas.chat_shared.Toast(window.t("Channel deleted."),undefined);
      } catch ($e) {
        pas.chat_shared.Failed($e);
      };
    };
    $impl.MenuHere = function (Node, Target) {
      var Result = false;
      var Marked = null;
      Marked = window.getSelection();
      Result = (Target.closest("a, img, pre, code, button, textarea, input") === null) && (Marked.isCollapsed || !Marked.containsNode(Node,true));
      return Result;
    };
    $impl.DropHold = function () {
      if ($impl.Hold !== null) window.clearTimeout($impl.Hold.timer);
      $impl.Hold = null;
    };
  };
},["weborworker","chat_menu","chat_sync","chat_panels"]);
rtl.module("chat_live",["System","JS","Web","chat_shared"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  this.LoadNotices = async function (Fresh) {
    var A = null;
    var Known = null;
    var Items = null;
    var Unseen = null;
    var Count = undefined;
    if (pas.chat_shared.Me.name === "") return;
    try {
      A = await pas.chat_shared.Get("/api/notices?unseen=1");
    } catch ($e) {
      return;
    };
    Known = new Set(pas.chat_shared.Notices.items.map(function (N, Index, All) {
      var Result = undefined;
      Result = N.id;
      return Result;
    }));
    Items = A.items;
    if (!Boolean(Items)) Items = new Array();
    Unseen = Items.filter(function (N, Index, All) {
      var Result = false;
      Result = !N.seen;
      return Result;
    });
    Count = A.unseen;
    if (!Count) Count = 0;
    pas.chat_shared.Notices = pas.JS.New(["unseen",Count,"items",Unseen.slice(0,3)]);
    if (Fresh) Unseen.filter(function (N, Index, All) {
      var Result = false;
      Result = !Known.has(N.id);
      return Result;
    }).slice(0,3).forEach(function (N, Index, All) {
      pas.chat_shared.Toast(N.text,undefined);
    });
    pas.chat_sidebar.RenderSidebar();
  };
  this.ConnectLive = function () {
    var Ws = null;
    var Scheme = "";
    if (!Reflect.has(window,"WebSocket") || (pas.chat_shared.Live.failures > 4)) return;
    try {
      if (window.location.protocol === "https:") {
        Scheme = "wss://"}
       else Scheme = "ws://";
      Ws = new WebSocket(Scheme + window.location.host + window.SiteBase.url("/api/live"));
    } catch ($e) {
      return;
    };
    pas.chat_shared.Live.ws = Ws;
    Ws.onmessage = function (E) {
      var Note = undefined;
      try {
        Note = JSON.parse(E.data);
      } catch ($e) {
        return;
      };
      $impl.Heard(Note);
    };
    Ws.onclose = function (E) {
      if (!Boolean(pas.chat_shared.Live.id)) pas.chat_shared.Live.failures = pas.chat_shared.Live.failures + 1;
      pas.chat_shared.Live.id = "";
      pas.chat_shared.Live.ws = null;
      window.setTimeout(function () {
        $mod.ConnectLive();
      },pas.chat_shared.Live.wait);
      pas.chat_shared.Live.wait = Math.min(pas.chat_shared.Live.wait * 2,30000);
    };
  };
  this.Start = function () {
    window.setInterval(function () {
      if (Boolean(pas.chat_shared.Live.ws) && (pas.chat_shared.Live.ws.readyState === 1)) pas.chat_shared.Live.ws.send("ping");
    },25000);
    document.addEventListener("visibilitychange",function (E) {
      if (Boolean(pas.chat_shared.Live.ws) && (pas.chat_shared.Live.ws.readyState === 1)) if (document.hidden) {
        pas.chat_shared.Live.ws.send("hidden")}
       else pas.chat_shared.Live.ws.send("shown");
    });
  };
  $mod.$implcode = function () {
    $impl.ReadTimer = 0;
    $impl.Leaving = false;
    $impl.LeaveChannel = function (Why) {
      if ($impl.Leaving) return;
      $impl.Leaving = true;
      pas.chat_shared.Toast(Why,undefined);
      window.setTimeout(function () {
        window.location.assign(window.SiteBase.url("/"));
      },2500);
    };
    $impl.LeaveIfGone = async function () {
      var Result = undefined;
      var Slug = "";
      var Answer = null;
      if ((pas.chat_shared.S.view !== "room") || !Boolean(pas.chat_shared.S.info) || !pas.chat_shared.S.info.private) return undefined;
      Slug = pas.chat_shared.S.room;
      Answer = await window.fetch("/api/room?slug=" + pas.chat_shared.Enc(Slug));
      if ((Answer.status !== 404) || (pas.chat_shared.S.view !== "room") || (pas.chat_shared.S.room !== Slug)) return undefined;
      $impl.LeaveChannel(window.t("You are no longer in #%s.",Slug));
      Result = undefined;
      return Result;
    };
    $impl.Arrived = function (M) {
      var Lower = "";
      var Names = null;
      var One = null;
      var P = undefined;
      var Data = null;
      Lower = pas.chat_shared.Me.name.toLowerCase();
      Names = M.names;
      if (!Boolean(Names)) Names = new Array();
      M.mentions_me = (pas.chat_shared.Me.name !== "") && Names.some(function (N, Index, All) {
        var Result = false;
        Result = N.toLowerCase() === Lower;
        return Result;
      });
      M.ignored = pas.chat_shared.Me.ignores.indexOf(M.uid) >= 0;
      One = new Array();
      One.push(M);
      if (Boolean(M.parent)) {
        if (pas.chat_shared.S.thread === M.parent) pas.chat_panels.AddThread(One);
        P = pas.chat_shared.S.messages.get(M.parent);
        if (P) {
          Data = P.data;
          pas.chat_rooms.Upsert(Object.assign(new Object(),Data,pas.JS.New(["replies",Data.replies + 1,"last_reply",M.at,"rev",Data.rev + 1])),pas.chat_shared.Stream,pas.chat_shared.S.messages,false);
        };
      } else pas.chat_rooms.AddMessages(One,false);
      if (!Boolean($impl.ReadTimer) && (pas.chat_shared.Me.name !== "")) $impl.ReadTimer = window.setTimeout(function () {
        $impl.ReadTimer = 0;
        pas.chat_shared.FromRing = true;
        pas.chat_sync.Sync();
      },4000 + (Math.random() * 6000));
    };
    $impl.Heard = function (Note) {
      var R = undefined;
      var One = null;
      if (Note.t === "names") {
        window.location.reload();
        return;
      } else if (Note.t === "hello") {
        pas.chat_shared.Live.id = Note.id;
        pas.chat_shared.Live.wait = 1000;
        pas.chat_shared.Live.failures = 0;
        pas.chat_sync.SyncNow(true);
        $mod.LoadNotices(false);
        $impl.LeaveIfGone().catch(function (Why) {
          var Result = undefined;
          return Result;
        });
      } else if (Note.t === "notice") {
        $mod.LoadNotices(true)}
       else if (Note.t === "room") {
        if ((Note.room === pas.chat_shared.S.room) && Boolean(Note.m)) {
          $impl.Arrived(Note.m)}
         else if (Note.room === pas.chat_shared.S.room) {
          window.setTimeout(function () {
            pas.chat_shared.FromRing = true;
            pas.chat_sync.Sync();
          },Math.random() * 300)}
         else {
          R = pas.chat_shared.S.rooms.find(function (X, Index, All) {
            var Result = false;
            Result = X.slug === Note.room;
            return Result;
          });
          if (R) {
            if (!R.unread) {
              R.unread = 1;
              pas.chat_sidebar.RenderSidebar();
            };
            pas.chat_sync.SidebarSoon(2000 + (Math.random() * 6000));
          };
        };
      } else if (Note.t === "typing") {
        if (Note.room === pas.chat_shared.S.room) {
          One = new Array();
          One.push(Note.name);
          pas.chat_rooms.NoteTyping(One);
        };
      } else if (Note.t === "dmtyping") {
        if ((pas.chat_shared.S.view === "dm") && (Note.from === pas.chat_shared.S.dm)) {
          One = new Array();
          One.push(Note.from);
          pas.chat_rooms.NoteTyping(One);
        };
      } else if (Note.t === "dmseen") {
        if ((pas.chat_shared.S.view === "dm") && (Note.from === pas.chat_shared.S.dm)) {
          pas.chat_shared.S.dmSeen = Note.seen;
          pas.chat_private.MarkSeen();
        };
      } else if (Note.t === "me") {
        pas.chat_sync.SidebarSoon(300)}
       else if (Note.t === "gone") {
        if (Note.room === pas.chat_shared.S.room) $impl.LeaveChannel(window.t("This channel was deleted."));
        pas.chat_sync.SidebarSoon(300);
      } else if (Note.t === "dm") {
        if (Note.gone && (pas.chat_shared.S.view === "dm") && (Note.from === pas.chat_shared.S.dm)) {
          pas.chat_shared.Route(window.SiteBase.path(),false)}
         else if (Boolean(Note.deleted) && (pas.chat_shared.S.view === "dm") && (Note.from === pas.chat_shared.S.dm)) {
          pas.chat_private.DropDm(Note.deleted)}
         else if (Boolean(Note.edited) && (pas.chat_shared.S.view === "dm") && (Note.from === pas.chat_shared.S.dm)) {
          pas.chat_private.RefreshDm(Note.edited)}
         else if ((pas.chat_shared.S.view === "dm") && ((Note.from === pas.chat_shared.S.dm) || (Note.from === pas.chat_shared.Me.name))) {
          if (Boolean(pas.chat_shared.S.typers[Note.from])) {
            pas.JS.JSDelete(pas.chat_shared.S.typers,Note.from);
            pas.chat_rooms.RenderTyping();
          };
          pas.chat_private.PollNow();
        };
        pas.chat_sync.SidebarSoon(300);
      };
    };
  };
},["chat_sidebar","chat_rooms","chat_sync","chat_panels","chat_private"]);
rtl.module("ChatPage",["System"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  $mod.$implcode = function () {
    $impl.ProfileTools = function (Who, Tools) {
      var Ignore = null;
      if ((pas.chat_shared.Me.name !== "") && (pas.chat_shared.Me.name !== Who.name)) {
        Tools.appendChild(pas.chat_shared.Link("/dm/" + pas.chat_shared.Enc(Who.name),"primary",window.t("Private message")));
        if (Who.ignored) {
          Ignore = pas.chat_shared.El("button","",window.t("Stop ignoring"))}
         else Ignore = pas.chat_shared.El("button","",window.t("Ignore"));
        Ignore.type = "button";
        Ignore.title = window.t("Their messages fold away, and their mentions and private messages do not reach you");
        Ignore.addEventListener("click",async function (E) {
          var Turn = "";
          try {
            if (Who.ignored) {
              Turn = "0"}
             else Turn = "1";
            await pas.chat_shared.Post("/api/ignore",pas.JS.New(["name",Who.name,"on",Turn]));
            pas.chat_shared.Route(window.SiteBase.path(),false);
          } catch ($e) {
            pas.chat_shared.Failed($e);
          };
        });
        Tools.appendChild(Ignore);
      };
    };
    $impl.ProfileShelf = async function (Who, Generation) {
      var ShelfHead = null;
      var Empty = null;
      var Info = null;
      ShelfHead = pas.chat_shared.El("div","shelfhead",undefined);
      ShelfHead.append(pas.chat_shared.Icon("shelf"),pas.chat_shared.El("b","",window.t("%s’s shelf",Who.name)),pas.chat_shared.El("span","",window.t("what they put up to stay: things they made, found or want to keep in view")));
      pas.chat_shared.Find("#card",undefined).appendChild(ShelfHead);
      Info = null;
      try {
        Info = await pas.chat_shared.Get("/api/room?slug=" + pas.chat_shared.Enc("~" + Who.name.toLowerCase()));
      } catch ($e) {
      };
      if ((Generation !== pas.chat_shared.S.generation) || !Boolean(Info)) return;
      pas.chat_shared.S.view = "room";
      pas.chat_shared.S.room = Info.slug;
      pas.chat_shared.S.info = Info;
      pas.chat_shared.Stream.className = "shelf";
      await pas.chat_rooms.LoadMessages(Generation);
      if (!Boolean(pas.chat_shared.S.messages.size)) {
        Empty = pas.chat_shared.Find(".empty",pas.chat_shared.Stream);
        if (Boolean(Empty)) {
          if (pas.chat_shared.Me.name === Who.name) {
            Empty.replaceWith(pas.chat_shared.El("p","notice empty",window.t("Your shelf is empty. Put something here that should stay: a project, a screenshot, a favorite answer.")))}
           else Empty.replaceWith(pas.chat_shared.El("p","notice empty",window.t("Nothing on the shelf yet.")));
        };
      };
      if (pas.chat_shared.Me.name === Who.name) {
        pas.chat_composer.RenderComposer(pas.chat_shared.Find("#composer-area",undefined),0,undefined)}
       else if (pas.chat_shared.Me.name !== "") pas.chat_shared.Find("#composer-area",undefined).appendChild(pas.chat_shared.El("p","notice",window.t("Reply to anything on the shelf in its thread.")));
      pas.chat_sync.SyncNow(true);
    };
    $impl.Prepare = async function () {
      if (pas.chat_shared.Me.name === "") try {
        pas.chat_shared.S.rooms = await pas.chat_shared.Get("/api/rooms");
      } catch ($e) {
      };
    };
    $impl.StartPart = function () {
      if ((pas.chat_shared.Me.name !== "") && pas.JS.jsIn("Notification",window) && (Notification.permission === "granted") && pas.JS.jsIn("PushManager",window)) pas.chat_shared.C.subscribePush();
      pas.chat_shared.C.offerNotifications();
      pas.chat_live.ConnectLive();
    };
    $impl.ViewPart = async function (View, Target, Thread) {
      var Result = false;
      if (View === "room") {
        await pas.chat_rooms.OpenRoom(Target,Thread)}
       else if (View === "dm") {
        await pas.chat_private.OpenDm(Target)}
       else if (View === "search") {
        pas.chat_panels.OpenSearchAll()}
       else return false;
      Result = true;
      return Result;
    };
    $impl.OpenPart = async function (Parts) {
      var Result = false;
      var List = null;
      var First = null;
      var Root = 0.0;
      if (pas.chat_shared.Same(Parts[1],"p")) {
        await pas.chat_rooms.OpenRoom(Parts[2],0)}
       else if (pas.chat_shared.Same(Parts[1],"m")) {
        List = await pas.chat_shared.Get("/api/thread?id=" + pas.chat_shared.Enc(Parts[2]));
        if (!Boolean(List.length)) throw new Error(window.t("That message is gone."));
        First = List[0];
        if (Boolean(First.parent)) {
          Root = First.parent}
         else Root = First.id;
        await pas.chat_rooms.OpenRoom(First.room,Root);
      } else if (pas.chat_shared.Same(Parts[1],"dm")) {
        await pas.chat_private.OpenDm(Parts[2])}
       else if (pas.chat_shared.Same(Parts[1],"chat-search")) {
        pas.chat_panels.OpenSearchAll()}
       else return false;
      Result = true;
      return Result;
    };
  };
  $mod.$init = function () {
    pas.chat_shared.Setup();
    pas.chat_shared.Extras.accountLinks.push(pas.JS.New(["href","/irc","title",window.t("Use your IRC client")]));
    pas.chat_sidebar.Start();
    pas.chat_rooms.Start();
    pas.chat_menu.Start();
    pas.chat_sync.Start();
    pas.chat_live.Start();
    pas.chat_composer.Start();
    pas.chat_shared.C.parts.push(pas.JS.New(["prepare",$impl.Prepare,"sidebar",pas.chat_sidebar.RenderSidebar,"start",$impl.StartPart,"sync",pas.chat_sync.SyncNow,"view",$impl.ViewPart,"open",$impl.OpenPart,"profileTools",$impl.ProfileTools,"profile",$impl.ProfileShelf]));
  };
},["JS","Web","chat_shared","chat_sidebar","chat_rooms","chat_menu","chat_sync","chat_live","chat_panels","chat_composer","chat_private"]);

rtl.run('ChatPage');
}
