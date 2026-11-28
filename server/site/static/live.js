// A page that loads this file alone, with no runtime, gets the plain script.
if (typeof rtl === 'undefined') (function () {
  var plain = document.createElement('script');
  plain.src = document.currentScript.src.replace(/live\.js/, 'live-embed.js');
  document.body.appendChild(plain);
})(); else {
if (!pas.LivePage) {
rtl.module("LivePage",["System"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  $mod.$implcode = function () {
    $impl.SVG = "http://www.w3.org/2000/svg";
    $impl.Limits = [60,3600,86400,604800,2629800,31557600];
    $impl.Parts = ["second","minute","hour","day","week","month","year"];
    $impl.Sizes = [1,60,3600,86400,604800,2629800,31557600];
    $impl.Messages = function (Data) {
      var Result = null;
      if (Boolean(Data["messages"])) {
        Result = Data["messages"]}
       else Result = new Array();
      return Result;
    };
    $impl.Start = function () {
      var Spot = null;
      var Bubble = null;
      var Badge = null;
      var Teaser = null;
      var TeaserWho = null;
      var TeaserText = null;
      var TeaserWhen = null;
      var TeaserOff = null;
      var TeaserRow = null;
      var Panel = null;
      var Head = null;
      var Title = null;
      var TitleText = null;
      var TitleName = null;
      var Here = null;
      var Fold = null;
      var News = null;
      var List = null;
      var Foot = null;
      var Offer = null;
      var SayNote = null;
      var SentLine = null;
      var Invite = null;
      var Open = null;
      var GoOn = null;
      var Join = null;
      var SayForm = null;
      var SayBox = null;
      var Send = null;
      var Glimpses = null;
      var Styles = null;
      var Base = "";
      var Lang = "";
      var Own = "";
      var Room = "";
      var PageKey = "";
      var PageTitle = "";
      var CanBench = "";
      var PageHeading = "";
      var LastSeen = "";
      var T = null;
      var TN = null;
      var Relative = null;
      var Member = false;
      var Shown = false;
      var OpenAtStart = false;
      var Timer = 0;
      var TeaserTimer = 0;
      var Generation = 0;
      var I = 0;
      var NewsAsked = 0.0;
      var Current = null;
      var Found = null;
      var Ways = null;
      function U(Path) {
        var Result = "";
        Result = Base + Path;
        return Result;
      };
      function Away(A) {
        var Result = null;
        if (Base !== "") {
          A.target = "_blank";
          A.rel = "noopener";
        };
        Result = A;
        return Result;
      };
      function Ago(Iso) {
        var Result = "";
        var Seconds = 0.0;
        var N = 0;
        Seconds = (Date.parse("" + Iso) - Date.now()) / 1000;
        if ((Relative === null) || isNaN(Seconds)) return "";
        for (N = 0; N <= 6; N++) if ((N === 6) || (Math.abs(Seconds) < $impl.Limits[N])) {
          if (N === 0) return Relative.format(0,"second");
          return Relative.format(Math.round(Seconds / $impl.Sizes[N]),$impl.Parts[N]);
        };
        Result = "";
        return Result;
      };
      function El(Tag, Cls, Text) {
        var Result = null;
        Result = document.createElement(Tag);
        if (Boolean(Cls)) Result.className = "" + Cls;
        if (typeof(Text) !== "undefined") Result["textContent"] = Text;
        return Result;
      };
      function BenchIcon() {
        var Result = null;
        var Path = null;
        Result = document.createElementNS($impl.SVG,"svg");
        Result.setAttribute("viewBox","0 0 24 24");
        Result.setAttribute("aria-hidden","true");
        Path = document.createElementNS($impl.SVG,"path");
        Path.setAttribute("d","M3 10h18M5 10v8M19 10v8M3 14h18M6 6h12");
        Path.setAttribute("fill","none");
        Path.setAttribute("stroke","currentColor");
        Path.setAttribute("stroke-width","2");
        Path.setAttribute("stroke-linecap","round");
        Result.appendChild(Path);
        return Result;
      };
      async function GetJson(Url) {
        var Result = undefined;
        var R = null;
        var Cookies = "";
        var Failure = null;
        if (Base !== "") {
          Cookies = "omit"}
         else Cookies = "same-origin";
        R = await window.fetch(U(Url),pas.JS.New(["credentials",Cookies,"cache","no-store"]));
        if (!R.ok) {
          Failure = new Error(await R.text());
          Failure["status"] = R.status;
          throw Failure;
        };
        Result = await R.json();
        return Result;
      };
      function Remember(Key, Value) {
        try {
          window.localStorage.setItem(Key,"" + Value);
        } catch ($e) {
        };
      };
      function Recall(Key) {
        var Result = "";
        var Kept = undefined;
        try {
          Kept = window.localStorage.getItem(Key);
          if (Boolean(Kept)) {
            Result = "" + Kept}
           else Result = "";
        } catch ($e) {
          Result = "";
        };
        return Result;
      };
      function Session(Key, Value) {
        var Result = "";
        var Kept = undefined;
        Result = "";
        try {
          if (typeof(Value) === "undefined") {
            Kept = window.sessionStorage.getItem(Key);
            if (Boolean(Kept)) Result = "" + Kept;
            return Result;
          };
          window.sessionStorage.setItem(Key,"" + Value);
        } catch ($e) {
        };
        return Result;
      };
      async function RefreshGlimpse(Box) {
        var Data = null;
        var M = null;
        var Said = null;
        var Lead = null;
        var Ol = null;
        var Li = null;
        var N = 0;
        try {
          Data = await GetJson("/api/live?room=" + encodeURIComponent(Box.getAttribute("data-live-room")));
        } catch ($e) {
          return;
        };
        Said = $impl.Messages(Data).slice().reverse();
        Box.replaceChildren();
        if (Said.length === 0) {
          Box.appendChild(El("p","glimpse-empty",T("Nothing said here yet. Be the first.")));
          return;
        };
        Lead = El("p","glimpse-head",T("Latest at its bench"));
        if (Number(Data["here"]) > 0) Lead.appendChild(El("span","live-here"," · " + TN(Data["here"],"%d here now","%d here now")));
        Box.appendChild(Lead);
        Ol = El("ol","glimpse-list",undefined);
        for (var $l = 0, $end = Said.length - 1; $l <= $end; $l++) {
          N = $l;
          M = Said[N];
          Li = El("li",undefined,undefined);
          Li.appendChild(El("b","live-who",M["name"]));
          Li.appendChild(El("time","live-when",Ago(M["at"])));
          Li.appendChild(El("span","live-text",M["text"]));
          Ol.appendChild(Li);
        };
        Box.appendChild(Ol);
      };
      function AllGlimpses() {
        var N = 0;
        for (var $l = 0, $end = Glimpses.length - 1; $l <= $end; $l++) {
          N = $l;
          RefreshGlimpse(Glimpses[N]);
        };
      };
      function SwitchRoom(Slug) {
        Room = "" + Slug;
        Generation += 1;
        LastSeen = "";
        Open.href = U("/p/" + encodeURIComponent(Room));
      };
      async function DescribeRoom() {
        var Mine = 0;
        var Info = null;
        var Channel = "";
        Mine = Generation;
        Info = null;
        try {
          Info = await GetJson("/api/room?slug=" + encodeURIComponent(Room));
        } catch ($e) {
          if (Mine !== Generation) return;
          Channel = Spot.getAttribute("data-live-default");
          if ((Own === "") && (Room !== Channel) && Boolean(Channel)) {
            SwitchRoom(Channel);
            TitleName.textContent = "#" + Room;
            await DescribeRoom();
          };
          return;
        };
        if (Mine !== Generation) return;
        if ((Info !== null) && Boolean(Info["title"])) if (Own !== "") {
          TitleName["textContent"] = Info["title"]}
         else if (Object.is(Info["kind"],"channel")) {
          TitleName.textContent = "#" + ("" + Info["slug"])}
         else TitleName["textContent"] = Info["title"];
        if (Own !== "") {
          Here.textContent = T("Live bench")}
         else if ((Info !== null) && Object.is(Info["kind"],"channel")) {
          Here.textContent = T("Live chat")}
         else Here.textContent = T("Live bench");
      };
      function HideTeaser() {
        TeaserRow.hidden = true;
        if (TeaserTimer !== 0) {
          window.clearTimeout(TeaserTimer);
          TeaserTimer = 0;
        };
      };
      async function MarkRead(Data) {
        var Newest = 0.0;
        Newest = Math.max.apply(null,$impl.Messages(Data).map(function (M, N, A) {
          var Result = undefined;
          Result = M["id"];
          return Result;
        }));
        if (!(Newest > Number(Data["last_read"]))) return;
        try {
          await GetJson("/api/sync?" + (new URLSearchParams(pas.JS.New(["room",Room,"since",Data["rev"],"read",Newest]))).toString());
        } catch ($e) {
          return;
        };
        NewsAsked = 0;
        RefreshNews();
      };
      async function RefreshList(First) {
        var Mine = 0;
        var N = 0;
        var Data = null;
        var M = null;
        var Said = null;
        var Seen = "";
        var AtBottom = false;
        var Action = false;
        var LastName = undefined;
        var Row = null;
        var Who = null;
        if (document.visibilityState === "hidden") return;
        Mine = Generation;
        try {
          Data = await GetJson("/api/messages?room=" + encodeURIComponent(Room));
        } catch ($e) {
          if (First && (Mine === Generation)) List.replaceChildren(El("p","live-sheet-empty",T("The chat could not be reached.")));
          return;
        };
        if (Mine !== Generation) return;
        Said = $impl.Messages(Data).filter(function (Each, N, A) {
          var Result = false;
          Result = !Boolean(Each["deleted"]) && !Boolean(Each["ignored"]) && Boolean(Each["body"]);
          return Result;
        }).reverse().slice(-40);
        Seen = JSON.stringify(Said.map(function (Each, N, A) {
          var Result = undefined;
          if (Boolean(Each["edited"])) {
            Result = Array.of(Each["id"],Each["body"],Each["edited"])}
           else Result = Array.of(Each["id"],Each["body"],"");
          return Result;
        }));
        if (!First && (Seen === LastSeen)) return;
        AtBottom = First || ((List.scrollHeight - List.scrollTop - List.clientHeight) < 80);
        List.replaceChildren();
        if (Said.length === 0) List.appendChild(El("p","live-sheet-empty",T("Nothing said here yet. Be the first.")));
        LastName = "";
        for (var $l = 0, $end = Said.length - 1; $l <= $end; $l++) {
          N = $l;
          M = Said[N];
          if (Object.is(M["name"],LastName)) {
            Row = El("a","live-msg same",undefined)}
           else Row = El("a","live-msg",undefined);
          Row.href = U("/m/" + encodeURIComponent("" + M["id"]));
          Away(Row);
          Row.title = T("Open in the chat");
          if (!Object.is(M["name"],LastName)) {
            Who = El("div","live-msg-who",undefined);
            Who.appendChild(El("b","",M["name"]));
            Who.appendChild(El("time","",Ago(M["at"])));
            Row.appendChild(Who);
          };
          Action = M["body"].startsWith("*" + ("" + M["name"]) + " ") && M["body"].endsWith("*");
          if (Action) {
            Row.appendChild(El("div","live-msg-text action",M["body"].slice(1,-1)))}
           else Row.appendChild(El("div","live-msg-text",M["body"]));
          List.appendChild(Row);
          LastName = M["name"];
        };
        LastSeen = Seen;
        if (AtBottom) List.scrollTop = List.scrollHeight;
        if (Member && AtBottom) MarkRead(Data);
      };
      function Show(Open_) {
        Shown = Open_;
        Panel.hidden = !Open_;
        if (Open_) {
          Bubble.classList.add("open")}
         else Bubble.classList.remove("open");
        if (Open_) {
          Session("live-open","1")}
         else Session("live-open","0");
        if (Open_) HideTeaser();
        if (Timer !== 0) {
          window.clearInterval(Timer);
          Timer = 0;
        };
        if (Open_) {
          RefreshList(true);
          RefreshNews();
          Timer = window.setInterval(RefreshList,6000);
        };
      };
      function CountOf(R) {
        var Result = 0.0;
        if (Object.is(R["notify"],"none")) {
          Result = 0}
         else if (Object.is(R["notify"],"mentions")) {
          if (Boolean(R["mentions"])) {
            Result = Number(R["mentions"])}
           else Result = 0;
        } else if (Boolean(R["unread"])) {
          Result = Number(R["unread"])}
         else Result = 0;
        return Result;
      };
      function Count99(N) {
        var Result = "";
        if (N > 99) {
          Result = "99+"}
         else Result = "" + N;
        return Result;
      };
      async function RefreshNews() {
        var Rooms = undefined;
        var Fresh = null;
        var R = null;
        var Total = 0.0;
        var Mentions = 0.0;
        var N = 0;
        var A = null;
        if (!Member || (document.visibilityState === "hidden") || ((Date.now() - NewsAsked) < 20000)) return;
        NewsAsked = Date.now();
        try {
          Rooms = await GetJson("/api/rooms");
        } catch ($e) {
          return;
        };
        if (!Boolean(Rooms)) Rooms = new Array();
        Fresh = Rooms.filter(function (Each, K, All) {
          var Result = false;
          Result = CountOf(Each) > 0;
          return Result;
        });
        Total = 0;
        Mentions = 0;
        for (var $l = 0, $end = Fresh.length - 1; $l <= $end; $l++) {
          N = $l;
          R = Fresh[N];
          Total = Total + CountOf(R);
          if (!Object.is(R["notify"],"none") && Boolean(R["mentions"])) Mentions = Mentions + Number(R["mentions"]);
        };
        Badge.hidden = Total === 0;
        Badge.textContent = Count99(Total);
        if (Mentions > 0) {
          Badge.classList.add("mention")}
         else Badge.classList.remove("mention");
        if (Boolean(Total)) {
          Bubble.title = TN(Total,"%d unread message in the chat","%d unread messages in the chat")}
         else Bubble.title = T("Live chat");
        News.replaceChildren();
        News.hidden = Fresh.length === 0;
        if (Fresh.length === 0) return;
        News.appendChild(El("span","live-news-lead",T("New for you:")));
        Fresh.sort(function (A, B) {
          var Result = 0.0;
          Result = Number(B["mentions"]) - Number(A["mentions"]);
          if (!Boolean(Result)) Result = Number(B["unread"]) - Number(A["unread"]);
          return Result;
        });
        for (var $l1 = 0, $end1 = Fresh.slice(0,6).length - 1; $l1 <= $end1; $l1++) {
          N = $l1;
          R = Fresh[N];
          if (Boolean(R["mentions"])) {
            A = El("a","live-news-room mention",undefined)}
           else A = El("a","live-news-room",undefined);
          if (Object.is(R["kind"],"shelf")) {
            A.href = U("/u/" + encodeURIComponent("" + R["title"]))}
           else A.href = U("/p/" + encodeURIComponent("" + R["slug"]));
          if (Object.is(R["kind"],"channel")) {
            A.append(El("span","","#" + ("" + R["slug"])),El("b","",Count99(CountOf(R))))}
           else A.append(El("span","",R["title"]),El("b","",Count99(CountOf(R))));
          if (Boolean(R["mentions"])) {
            A.title = TN(R["mentions"],"%d mention of you","%d mentions of you")}
           else A.title = TN(CountOf(R),"%d unread","%d unread");
          News.appendChild(A);
        };
        if (Fresh.length > 6) News.appendChild(El("a","live-news-more",TN(Fresh.length - 6,"and %d more","and %d more"))).href = "/";
      };
      function BenchOffer() {
        var Result = null;
        var Box = null;
        var Note = null;
        var B = null;
        var A = null;
        async function Make(E) {
          var Names = null;
          var R = null;
          var Made = null;
          B.disabled = true;
          Note.textContent = "";
          Names = PageKey.split(":");
          try {
            R = await window.fetch("/page-bench",pas.JS.New(["method","POST","credentials","same-origin","body",new URLSearchParams(pas.JS.New(["kind",Names[0],"key",Names.slice(1).join(":")]))]));
            if (!R.ok) {
              Note.textContent = (await R.text()).slice(0,200);
              B.disabled = false;
              return;
            };
            Made = await R.json();
            Remember("last-room",Made["room"]);
            window.location["href"] = Made["url"];
          } catch ($e) {
            Note.textContent = T("The chat could not be reached.");
            B.disabled = false;
          };
        };
        if ((PageKey === "") || (Own !== "")) return null;
        Box = El("div","live-make",undefined);
        if (CanBench === "yes") {
          B = El("button","live-make-bench",T("Open a bench for this page"));
          B.type = "button";
          B.title = PageTitle;
          Note = El("span","live-make-note",undefined);
          B.addEventListener("click",Make);
          Box.append(B,Note);
        } else if (CanBench === "embed") {
          A = Away(El("a","live-make-bench",T("Open a bench for this page")));
          A.href = U("/embed/bench?url=" + encodeURIComponent(PageKey.slice(PageKey.indexOf(":",0) + 1)));
          A.title = PageTitle;
          Box.appendChild(A);
        } else if (CanBench === "signin") {
          A = El("a","live-make-signin",T("Sign in to open a bench for this page"));
          A.href = "/signin?return=" + encodeURIComponent(window.location.pathname + window.location.search);
          Box.appendChild(A);
        } else return null;
        Result = Box;
        return Result;
      };
      async function Speak(Event) {
        var Words = "";
        var R = null;
        Event.preventDefault();
        Words = SayBox.value.trim();
        if (Words === "") return;
        Send.disabled = true;
        SayNote.textContent = "";
        SentLine.hidden = true;
        try {
          try {
            R = await window.fetch("/api/post",pas.JS.New(["method","POST","credentials","same-origin","body",new URLSearchParams(pas.JS.New(["room",Room,"body",Words]))]));
            if (!R.ok) {
              SayNote.textContent = (await R.text()).slice(0,200);
              return;
            };
            SayBox.value = "";
            Remember("last-room",Room);
            GoOn.href = "/p/" + encodeURIComponent(Room);
            SentLine.hidden = false;
            await RefreshList(true);
          } catch ($e) {
            SayNote.textContent = T("The chat could not be reached.");
          };
        } finally {
          Send.disabled = false;
          SayBox.focus();
        };
      };
      async function RefreshHere() {
        var Data = null;
        var N = 0.0;
        if (document.visibilityState === "hidden") return;
        try {
          Data = await GetJson("/api/live?room=" + encodeURIComponent(Room));
        } catch ($e) {
          return;
        };
        if (Boolean(Data["here"])) {
          N = Number(Data["here"])}
         else N = 0;
        if (!Member) {
          Badge.hidden = N === 0;
          Badge.textContent = "" + N;
          if (N > 0) {
            Bubble.title = TN(N,"%d here now","%d here now")}
           else Bubble.title = T("Live chat");
        };
        if (N > 0) {
          Bubble.classList.add("busy")}
         else Bubble.classList.remove("busy");
        if (N > 0) {
          Here.textContent = TN(N,"%d here now","%d here now")}
         else if (Own !== "") {
          Here.textContent = T("Live bench")}
         else Here.textContent = T("Live chat");
      };
      async function Tease() {
        var Data = null;
        var M = null;
        var Where = "";
        if ((Session("live-teased",undefined) !== "") || (Session("live-open",undefined) === "1")) return;
        try {
          if (Own !== "") {
            Data = await GetJson("/api/live?room=" + encodeURIComponent(Room))}
           else Data = await GetJson("/api/live");
        } catch ($e) {
          return;
        };
        M = $impl.Messages(Data)[0];
        if (!Boolean(M) || ((Date.now() - Date.parse("" + M["at"])) > 86400000)) return;
        Session("live-teased","1");
        Where = "";
        if ((Own === "") && Boolean(M["room"])) if (Object.is(M["kind"],"channel")) {
          Where = " " + T("in") + " #" + ("" + M["room"])}
         else Where = " " + T("in") + " " + ("" + M["title"]);
        TeaserWho.textContent = "" + M["name"] + Where + ":";
        if (M["text"].startsWith("" + M["name"] + " ")) {
          TeaserText.textContent = " " + M["text"].slice(M["name"].length + 1) + " "}
         else TeaserText.textContent = " " + ("" + M["text"]) + " ";
        TeaserWhen.textContent = Ago(M["at"]);
        Teaser.title = T("Open the chat");
        Teaser.addEventListener("click",function (E) {
          if ((Own === "") && Boolean(M["room"]) && !Object.is(M["room"],Room)) {
            SwitchRoom(M["room"]);
            if (Object.is(M["kind"],"channel")) {
              TitleName.textContent = "#" + ("" + M["room"])}
             else TitleName["textContent"] = M["title"];
            DescribeRoom();
          };
          Show(true);
        });
        TeaserOff.addEventListener("click",function (E) {
          HideTeaser();
        });
        TeaserRow.hidden = false;
        TeaserTimer = window.setTimeout(rtl.createSafeCallback(null,HideTeaser),20000);
      };
      Spot = document.querySelector("[data-live-strip]");
      Glimpses = Array.from(document.querySelectorAll("[data-live-room]:not([data-live-strip])"));
      if ((Spot === null) && (Glimpses.length === 0)) return;
      if (Spot !== null) {
        Base = Spot.getAttribute("data-live-base")}
       else Base = "";
      if (!Boolean(Base)) Base = "";
      Styles = document.createElement("link");
      Styles.rel = "stylesheet";
      Current = document["currentScript"];
      Found = null;
      if (Boolean(Current)) Found = (new RegExp("\\?v=[^&]*")).exec("" + Current["src"]);
      if (Found !== null) {
        Styles.href = U("/static/live.css") + ("" + Found["0"])}
       else Styles.href = U("/static/live.css");
      if (Spot !== null) document.head.appendChild(Styles);
      if (Boolean(window["t"])) {
        T = window["t"]}
       else T = function (English) {
        var Result = "";
        Result = English;
        return Result;
      };
      if (Boolean(window["tn"])) {
        TN = window["tn"]}
       else TN = function (N, One, Many) {
        var Result = "";
        if (Object.is(N,1)) {
          Result = One}
         else Result = Many;
        Result = Result.replace("%d","" + N);
        return Result;
      };
      Lang = "" + document.documentElement["lang"];
      if (!Boolean(Lang)) Lang = "en";
      Relative = null;
      try {
        Relative = new Intl.RelativeTimeFormat(Lang,pas.JS.New(["numeric","auto"]));
      } catch ($e) {
      };
      if (Spot === null) {
        AllGlimpses();
        return;
      };
      Member = (Base === "") && (document.querySelector(".account .me") !== null);
      Own = Spot.getAttribute("data-live-room");
      if (!Boolean(Own)) if (Glimpses.length > 0) {
        Own = Glimpses[0].getAttribute("data-live-room")}
       else Own = "";
      Room = Own;
      if (!Boolean(Room)) Room = Recall("last-room");
      if (!Boolean(Room)) Room = Spot.getAttribute("data-live-default");
      if (!Boolean(Room)) Room = "";
      PageKey = Spot.getAttribute("data-live-page");
      if (!Boolean(PageKey)) PageKey = "";
      PageTitle = Spot.getAttribute("data-live-title");
      if (!Boolean(PageTitle)) PageTitle = "";
      CanBench = Spot.getAttribute("data-live-can-bench");
      if (!Boolean(CanBench)) CanBench = "";
      if (document.querySelector("h1") !== null) {
        PageHeading = document.querySelector("h1").textContent.trim()}
       else PageHeading = "";
      if (Boolean(Styles["sheet"])) {
        Spot.hidden = false}
       else {
        Styles["onerror"] = function () {
          Spot.hidden = false;
        };
        Styles["onload"] = Styles["onerror"];
      };
      Spot.className = "live-bench";
      Spot.replaceChildren();
      Bubble = El("button","live-bubble",undefined);
      Bubble.type = "button";
      Bubble.setAttribute("aria-label",T("Live chat"));
      Bubble.title = T("Live chat");
      Bubble.appendChild(BenchIcon());
      Badge = El("span","live-badge","");
      Badge.hidden = true;
      Bubble.appendChild(Badge);
      Teaser = El("button","live-teaser",undefined);
      Teaser.type = "button";
      TeaserWho = El("b",undefined,undefined);
      TeaserText = El("span","live-teaser-text",undefined);
      TeaserWhen = El("time",undefined,undefined);
      Teaser.append(TeaserWho,TeaserText,TeaserWhen);
      TeaserOff = El("button","live-teaser-off","×");
      TeaserOff.type = "button";
      TeaserOff.title = T("Not now");
      TeaserOff.setAttribute("aria-label",T("Not now"));
      TeaserRow = El("div","live-teaser-row",undefined);
      TeaserRow.hidden = true;
      TeaserRow.append(Teaser,TeaserOff);
      Spot.appendChild(TeaserRow);
      Spot.appendChild(Bubble);
      Panel = El("section","live-sheet",undefined);
      Panel.hidden = true;
      Panel.setAttribute("aria-label",T("Live chat"));
      Head = El("header","live-sheet-head",undefined);
      Title = El("div","live-sheet-title",undefined);
      Title.appendChild(BenchIcon());
      TitleText = El("div",undefined,undefined);
      if (Own === "") {
        TitleName = El("b","","#" + Room)}
       else if (PageHeading !== "") {
        TitleName = El("b","",PageHeading)}
       else TitleName = El("b","",Room);
      TitleText.appendChild(TitleName);
      if (Own !== "") {
        Here = El("span","live-sheet-here",T("Live bench"))}
       else Here = El("span","live-sheet-here",T("Live chat"));
      TitleText.appendChild(Here);
      Title.appendChild(TitleText);
      Head.appendChild(Title);
      Open = El("a","live-sheet-open",T("Open the chat"));
      Open.href = U("/p/" + encodeURIComponent(Room));
      Away(Open);
      Head.appendChild(Open);
      Fold = El("button","live-sheet-fold","–");
      Fold.type = "button";
      Fold.title = T("Minimize");
      Fold.setAttribute("aria-label",T("Minimize"));
      Head.appendChild(Fold);
      Panel.appendChild(Head);
      News = El("nav","live-news",undefined);
      News.hidden = true;
      News.setAttribute("aria-label",T("New for you"));
      Panel.appendChild(News);
      List = El("div","live-sheet-list",undefined);
      List.setAttribute("role","log");
      List.setAttribute("aria-live","polite");
      Panel.appendChild(List);
      Foot = El("div","live-sheet-foot",undefined);
      Panel.appendChild(Foot);
      Spot.insertBefore(Panel,TeaserRow);
      Shown = false;
      Timer = 0;
      LastSeen = "";
      Generation = 0;
      Bubble.addEventListener("click",function (E) {
        Show(!Shown);
      });
      Fold.addEventListener("click",function (E) {
        Show(false);
      });
      NewsAsked = 0;
      Offer = BenchOffer();
      if (Offer !== null) Foot.appendChild(Offer);
      if (Member) {
        SayForm = El("form","live-say",undefined);
        SayBox = El("textarea",undefined,undefined);
        SayBox.rows = 1;
        SayBox.maxLength = 8000;
        SayBox.placeholder = T("Say something…");
        SayBox.setAttribute("aria-label",T("Say something…"));
        Send = El("button","live-send",T("Send"));
        Send.type = "submit";
        SayForm.append(SayBox,Send);
        SayNote = El("p","live-say-note",undefined);
        SentLine = El("p","live-sent",undefined);
        SentLine.hidden = true;
        GoOn = El("a","",T("Continue in the chat"));
        SentLine.append(T("Sent.") + " ",GoOn);
        Foot.append(SayForm,SayNote,SentLine);
        SayBox.addEventListener("keydown",function (E) {
          if ((E.key === "Enter") && !E.shiftKey) {
            E.preventDefault();
            if (Boolean(SayForm["requestSubmit"])) {
              SayForm.requestSubmit()}
             else Send.click();
          };
        });
        SayForm.addEventListener("submit",Speak);
      } else {
        Invite = El("p","live-invite",T("Read along, or join to say something here.") + " ");
        Join = El("a","button",T("Join"));
        if (Base !== "") {
          Join.href = U("/p/" + encodeURIComponent(Room))}
         else Join.href = "/signin?return=" + encodeURIComponent(window.location.pathname + window.location.search);
        Away(Join);
        Invite.appendChild(Join);
        Foot.appendChild(Invite);
      };
      TeaserTimer = 0;
      OpenAtStart = Session("live-open",undefined) === "1";
      if (Object.is((new URLSearchParams(window.location.search)).get("bench"),"open")) OpenAtStart = true;
      DescribeRoom();
      if (OpenAtStart) Show(true);
      Ways = document.querySelectorAll('.page-bench a[href="/p/' + Room + '"], .catalog-room a[href="/p/' + Room + '"]');
      for (var $l = 0, $end = Ways.length - 1; $l <= $end; $l++) {
        I = $l;
        Ways.item(I).addEventListener("click",function (E) {
          if (E.metaKey || E.ctrlKey) return;
          E.preventDefault();
          Show(true);
          Panel.scrollIntoView(pas.JS.New(["block","nearest"]));
        });
      };
      RefreshHere();
      window.setInterval(rtl.createSafeCallback(null,RefreshHere),30000);
      if (Member) {
        RefreshNews();
        window.setInterval(rtl.createSafeCallback(null,RefreshNews),180000);
      };
      window.setTimeout(rtl.createSafeCallback(null,Tease),2500);
      document.addEventListener("visibilitychange",function (E) {
        if (document.visibilityState === "visible") {
          RefreshHere();
          if (Shown) RefreshList(false);
          if (Member) RefreshNews();
        };
      });
      AllGlimpses();
      window.setInterval(rtl.createSafeCallback(null,AllGlimpses),30000);
    };
  };
  $mod.$init = function () {
    $impl.Start();
  };
},["JS","Web"]);

rtl.run('LivePage');
}
}
