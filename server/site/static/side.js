if (!pas.SidePage) {
rtl.module("SidePage",["System","JS","Web"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  this.El = function (Tag, Cls, Text) {
    var Result = null;
    Result = document.createElement(Tag);
    if (Boolean(Cls)) Result["className"] = Cls;
    if (typeof(Text) !== "undefined") Result["textContent"] = Text;
    return Result;
  };
  this.Link = function (Href, Cls, Text) {
    var Result = null;
    Result = $mod.El("a",Cls,Text);
    Result["href"] = Href;
    return Result;
  };
  this.Hue = function (Name) {
    var Result = 0;
    var H = 0;
    var Code = 0;
    var All = null;
    var I = 0;
    H = -2128831035;
    All = Array.from(Name);
    for (var $l = 0, $end = All.length - 1; $l <= $end; $l++) {
      I = $l;
      Code = All[I].charCodeAt(0);
      H = Math.imul(H ^ Code,16777619);
    };
    Result = (H >>> 0) % 360;
    return Result;
  };
  this.Avatar = function (Name, Url, Cls) {
    var Result = null;
    var Img = null;
    if (!Boolean(Cls)) Cls = "";
    Result = $mod.El("span","avatar " + ("" + Cls),undefined);
    if (Boolean(Url)) {
      Img = $mod.El("img",undefined,undefined);
      Img["src"] = Url;
      Img["alt"] = "";
      Img["loading"] = "lazy";
      Result.appendChild(Img);
    } else {
      if (!Boolean(Name)) Name = "?";
      Result.textContent = Name.charAt(0).toUpperCase();
      Result.style.setProperty("--h","" + $mod.Hue(Name));
    };
    return Result;
  };
  var NS = "http://www.w3.org/2000/svg";
  this.Icon = function (Name) {
    var Result = null;
    var Path = null;
    Result = document.createElementNS(NS,"svg");
    Result.setAttribute("viewBox","0 0 24 24");
    Result.setAttribute("class","icon");
    Path = document.createElementNS(NS,"path");
    Path.setAttribute("d",$impl.Icons[Name]);
    Result.appendChild(Path);
    return Result;
  };
  this.IconButton = function (Name, Title, Cls) {
    var Result = null;
    if (!Boolean(Cls)) Cls = "";
    Result = $mod.El("button","iconbtn " + ("" + Cls),undefined);
    Result["type"] = "button";
    Result.title = Title;
    Result.setAttribute("aria-label",Title);
    Result.appendChild($mod.Icon(Name));
    return Result;
  };
  this.Account = function (Who) {
    var Box = null;
    var Me = null;
    var Tools = null;
    var More = null;
    var Given = null;
    var I = 0;
    Box = $impl.Find("#account",null);
    if (!Boolean(Box)) return;
    Box.replaceChildren();
    if (Boolean(Who["unconfirmed"])) Box.appendChild($mod.Link("/u/" + encodeURIComponent(Who["name"]),"unconfirmed",$impl.Say("Confirm your email")));
    if (Boolean(Who["name"])) {
      Me = $mod.Link("/u/" + encodeURIComponent(Who["name"]),"me",undefined);
      Me.title = $impl.Say("Your profile and settings");
      Me.append($mod.Avatar(Who["name"],Who["avatar"],"small"),$mod.El("span","",Who["name"]));
      Box.appendChild(Me);
    } else Box.appendChild($mod.Link("/signin","button signinbtn",$impl.Say("Sign in or join")));
    Tools = $mod.El("div","tools",undefined);
    Given = Who["tools"];
    if (!Boolean(Given)) Given = new Array();
    for (var $l = 0, $end = Given.length - 1; $l <= $end; $l++) {
      I = $l;
      Tools.appendChild(Given[I]);
    };
    More = $mod.IconButton("up",$impl.Say("More"),undefined);
    More.addEventListener("click",function (E) {
      $impl.AccountMenu(Box,Who);
    });
    Tools.appendChild(More);
    Box.appendChild(Tools);
  };
  this.SignOut = async function () {
    try {
      if (Boolean(window.Keys)) await window.Keys.signOut();
      location.reload();
    } catch ($e) {
      alert($e["message"]);
    };
  };
  this.NewTabLinks = function (Boxes, Own, Stays) {
    document.addEventListener("click",function (E) {
      var A = null;
      A = E.target.closest("a[href]");
      if (!Boolean(A) || !Boolean(A.closest(Boxes)) || !(new RegExp("^https?:$")).test("" + A["protocol"])) return;
      if ((A.origin === window.location.origin) && (!Boolean(Own) || Boolean(Stays(A)))) return;
      A.target = "_blank";
      A.relList.add("noopener");
    },true);
  };
  $mod.$implcode = function () {
    $impl.Icons = null;
    $impl.Find = function (S, Root) {
      var Result = null;
      if (Boolean(Root)) {
        Result = Root.querySelector(S)}
       else Result = document.querySelector(S);
      return Result;
    };
    $impl.Say = function (Text) {
      var Result = "";
      if (typeof(window["t"]) === "function") {
        Result = window["t"].call(null,Text)}
       else Result = Text;
      return Result;
    };
    $impl.SayWith = function (Text, Value) {
      var Result = "";
      if (typeof(window["t"]) === "function") {
        Result = window["t"].call(null,Text,Value)}
       else Result = Text;
      return Result;
    };
    $impl.ThemeButton = function (Button) {
      function Names() {
        var Result = null;
        Result = pas.JS.New(["auto",$impl.Say("auto"),"light",$impl.Say("light"),"dark",$impl.Say("dark")]);
        return Result;
      };
      function Show(E) {
        var Now = "";
        var Name = "";
        Now = window.Theme.get();
        if (Now === "light") {
          Name = "sun"}
         else if (Now === "dark") {
          Name = "moon"}
         else Name = "auto";
        Button.replaceChildren($mod.Icon(Name));
        Button.title = $impl.SayWith("Theme: %s",Names()[Now]);
        Button.setAttribute("aria-label",$impl.SayWith("Theme: %s. Change theme",Names()[Now]));
      };
      if (!Boolean(Button) || !Boolean(window.Theme)) return;
      Button.addEventListener("click",function (E) {
        window.Theme.set(pas.JS.New(["auto","light","light","dark","dark","auto"])[window.Theme.get()]);
      });
      window.addEventListener("themechange",Show);
      Show(null);
    };
    $impl.AccountMenu = function (Box, Who) {
      var Open = null;
      var Holder = null;
      var Form = null;
      var Menu = null;
      var Row = null;
      var Out = null;
      var Links = null;
      var I = 0;
      function Away(E) {
        if (Menu.contains(E.target) && !Boolean(E.target.closest("a"))) return;
        Menu.close();
      };
      Open = $impl.Find(".accountmenu",Box);
      if (Boolean(Open)) {
        Open.close();
        return;
      };
      Menu = $mod.El("nav","accountmenu",undefined);
      if (Boolean(Who["name"])) Menu.appendChild($mod.Link("/u/" + encodeURIComponent(Who["name"]),"",$impl.Say("Your profile and settings")));
      Links = Who["links"];
      if (!Boolean(Links)) Links = new Array();
      for (var $l = 0, $end = Links.length - 1; $l <= $end; $l++) {
        I = $l;
        Menu.appendChild($mod.Link(Links[I]["href"],"",Links[I]["title"]));
      };
      if (Boolean(Who["admin"])) Menu.appendChild($mod.Link("/admin","",$impl.Say("Admin")));
      Holder = $impl.Find("#side-language",null);
      if (Boolean(Holder)) {
        Form = Holder.firstElementChild}
       else Form = Holder;
      if (Boolean(Form)) {
        Row = $mod.El("div","accountmenu-language",undefined);
        Row.appendChild(Form);
        Menu.appendChild(Row);
      };
      if (Boolean(Who["name"])) {
        Out = $mod.Link("#","",$impl.Say("Sign out"));
        Out.addEventListener("click",function (E) {
          E.preventDefault();
          if (Boolean(Who["signOut"])) {
            Who["signOut"].call(undefined)}
           else $mod.SignOut();
        });
        Menu.appendChild(Out);
      };
      Menu["close"] = function () {
        if (Boolean(Form)) Holder.appendChild(Form);
        Menu.remove();
        document.removeEventListener("click",Away);
      };
      Box.appendChild(Menu);
      window.setTimeout(function () {
        document.addEventListener("click",Away);
      },0);
    };
    $impl.FromLinks = function () {
      var Box = null;
      var Me = null;
      var Name = "";
      Box = $impl.Find("#account",null);
      if (!Boolean(Box) || !Boolean(Box.children.length)) return;
      Me = $impl.Find("a.me",Box);
      if (Boolean(Me)) {
        Name = Me.textContent.trim()}
       else Name = "";
      $mod.Account(pas.JS.New(["name",Name,"admin",Boolean($impl.Find('a[href$="/admin"]',Box)),"unconfirmed",Boolean($impl.Find("a.unconfirmed",Box))]));
    };
    $impl.Start = function (E) {
      $impl.ThemeButton($impl.Find("#theme",null));
      $impl.FromLinks();
    };
    $impl.Load = function () {
      $impl.Icons = pas.JS.New(["react","M12 22a10 10 0 1 1 0-20 10 10 0 0 1 0 20zm-4-8a4.5 4.5 0 0 0 8 0M9 9.5h.01M15 9.5h.01","reply","M21 12a8 8 0 0 1-11.6 7.1L4 21l1.9-5.4A8 8 0 1 1 21 12z","link","M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1","edit","M4 20h4L19 9l-4-4L4 16v4zM14 6l4 4","trash","M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3","pin","M9 4h6l-1 6 4 4H6l4-4-1-6zM12 14v7","attach","M21 11l-8.5 8.5a5 5 0 0 1-7-7L14 4a3.5 3.5 0 0 1 5 5l-8.5 8.5a2 2 0 0 1-3-3L15 7","code","M8 7l-5 5 5 5M16 7l5 5-5 5M14 4l-4 16","beam","M4 12h11M11 6l6 6-6 6M20 4v16","close","M6 6l12 12M18 6L6 18","menu","M4 6h16M4 12h16M4 18h16","search","M11 18a7 7 0 1 1 0-14 7 7 0 0 1 0 14zM20 20l-4-4","lock","M6 11h12v9H6zM8 11V8a4 4 0 0 1 8 0v3","shelf","M4 6h16M4 12h16M4 18h16M6 6v12M18 6v12","bell","M6 16V11a6 6 0 0 1 12 0v5l2 2H4l2-2zM10 20a2 2 0 0 0 4 0","sun","M12 17a5 5 0 1 0 0-10 5 5 0 0 0 0 10zM12 1v2M12 21v2M4.2 4.2l1.4 1.4M18.4 18.4l1.4 1.4M1 12h2M21 12h2M4.2 19.8l1.4-1.4M18.4 5.6l1.4-1.4","moon","M21 13A9 9 0 1 1 11 3a7 7 0 0 0 10 10z","auto","M12 21a9 9 0 1 1 0-18 9 9 0 0 1 0 18zM12 3v18","people","M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM2 21v-1a6 6 0 0 1 12 0v1M17 11a3 3 0 1 0 0-6M22 21v-1a5 5 0 0 0-4-4.9","plus","M12 5v14M5 12h14","copy","M8 8h12v12H8zM4 16V4h12","bug","M9 7a3 3 0 0 1 6 0M7 10h10v5a5 5 0 0 1-10 0zM12 10v10M4 13h3M17 13h3M5 8l2 2M19 8l-2 2M5 19l2-2M19 19l-2-2","install","M12 4v11M7 10l5 5 5-5M5 20h14","up","M6 15l6-6 6 6","down","M6 9l6 6 6-6","seen","M3 12a4 5 0 1 0 8 0a4 5 0 1 0-8 0M13 12a4 5 0 1 0 8 0a4 5 0 1 0-8 0M4.6 12.6a1 1 0 1 0 2 0a1 1 0 1 0-2 0M14.6 12.6a1 1 0 1 0 2 0a1 1 0 1 0-2 0"]);
      if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded",$impl.Start)}
       else $impl.Start(null);
      $mod.NewTabLinks(".forum-body, .forum-signature",false,null);
      window["Side"] = pas.JS.New(["el",$mod.El,"link",$mod.Link,"hue",$mod.Hue,"avatar",$mod.Avatar,"icons",$impl.Icons,"icon",$mod.Icon,"iconButton",$mod.IconButton,"account",$mod.Account,"signOut",$mod.SignOut,"newTabLinks",$mod.NewTabLinks]);
    };
  };
  $mod.$init = function () {
    $impl.Load();
  };
},["PageKit"]);

rtl.run('SidePage');
}
