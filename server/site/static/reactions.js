if (!pas.ReactionsPage) {
rtl.module("ReactionsPage",["System","JS","Web"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  this.Chips = function (List, Opts) {
    var Result = null;
    var I = 0;
    Result = $impl.El("div","reacts",undefined);
    for (var $l = 0, $end = List.length - 1; $l <= $end; $l++) {
      I = $l;
      Result.appendChild($impl.Chip(List[I],Opts));
    };
    return Result;
  };
  this.Offer = function (Box, Lists, Pick, Resized) {
    var Shown = null;
    var More = null;
    function Button(Emoji) {
      var Result = null;
      Result = $impl.El("button","",Emoji);
      Result.type = "button";
      Result.addEventListener("click",function (E) {
        Pick(Emoji);
      });
      return Result;
    };
    function Row(Cls, List) {
      var Result = null;
      var I = 0;
      Result = $impl.El("div",Cls,undefined);
      for (var $l = 0, $end = List.length - 1; $l <= $end; $l++) {
        I = $l;
        Result.appendChild(Button(List[I]));
      };
      return Result;
    };
    Shown = Row("emojis",Lists["shown"]);
    Box.appendChild(Shown);
    if (Lists["more"].length === 0) return;
    More = window.Side.iconButton("plus",window.t("More reactions"));
    More.setAttribute("aria-expanded","false");
    More.addEventListener("click",function (E) {
      var All = false;
      All = Box.classList.toggle("all");
      if (All) {
        More.replaceChildren(window.Side.icon("up"));
        More.title = window.t("Fewer reactions");
      } else {
        More.replaceChildren(window.Side.icon("plus"));
        More.title = window.t("More reactions");
      };
      More.setAttribute("aria-label",More.title);
      More.setAttribute("aria-expanded","" + All);
      Resized();
    });
    Shown.appendChild(More);
    Box.appendChild(Row("emojis rest",Lists["more"]));
  };
  this.Choose = function (Anchor, Lists, Pick) {
    var Box = null;
    if (($impl.Opened !== null) && ($impl.Opened["anchor"] == Anchor)) {
      $impl.Close(true);
      return;
    };
    Box = $impl.El("div","msgmenu",undefined);
    Box.setAttribute("role","group");
    Box.setAttribute("aria-label",Anchor.title);
    $mod.Offer(Box,Lists,function (Emoji) {
      $impl.Close(true);
      Pick(Emoji);
    },function () {
      $mod.Under(Box,Anchor.getBoundingClientRect());
    });
    Box.addEventListener("focusout",function (E) {
      if (Boolean(E.relatedTarget) && !Box.contains(E.relatedTarget)) $impl.Close(false);
    });
    $impl.Open(Box,Anchor,true);
    Box.querySelector("button").focus(pas.JS.New(["preventScroll",true]));
  };
  this.Under = function (Box, R) {
    var High = 0.0;
    var Top = 0.0;
    High = Box.offsetHeight;
    Top = R.bottom + 4;
    if ((Top + High) > (window.innerHeight - 8)) Top = R.top - 4 - High;
    Box.style.setProperty("top","" + Math.max(8,Math.min(Top,window.innerHeight - High - 8)) + "px");
    Box.style.setProperty("left","" + Math.max(8,Math.min(R.left,window.innerWidth - Box.offsetWidth - 8)) + "px");
  };
  $mod.$implcode = function () {
    $impl.REST = 350;
    $impl.HOLD = 500;
    $impl.Opened = null;
    $impl.El = function (Tag, Cls, Text) {
      var Result = null;
      Result = window.Side.el(Tag,Cls,Text);
      return Result;
    };
    $impl.Close = function (Refocus) {
      if ($impl.Opened === null) return;
      $impl.Opened["box"].remove();
      if (Refocus && Boolean($impl.Opened["refocus"])) $impl.Opened["anchor"].focus(pas.JS.New(["preventScroll",true]));
      $impl.Opened = null;
    };
    $impl.Open = function (Box, Anchor, Refocus) {
      $impl.Close(false);
      document.body.appendChild(Box);
      $impl.Opened = pas.JS.New(["box",Box,"anchor",Anchor,"refocus",Refocus]);
      $mod.Under(Box,Anchor.getBoundingClientRect());
    };
    $impl.WhoGave = function (B, Ask) {
      var Result = null;
      var Timer = 0;
      var Wanted = false;
      var Held = false;
      async function Show() {
        var Answer = null;
        var Box = null;
        var Names = null;
        var I = 0;
        Wanted = true;
        try {
          Answer = await Ask();
        } catch ($e) {
          return;
        };
        if (!Wanted || !Boolean(B["isConnected"]) || !Boolean(Answer["names"]["length"])) return;
        Names = Answer["names"];
        Box = $impl.El("div","reactwho",undefined);
        Box.setAttribute("role","tooltip");
        for (var $l = 0, $end = Names.length - 1; $l <= $end; $l++) {
          I = $l;
          Box.appendChild($impl.El("div","",Names[I]));
        };
        if (Number(Answer["more"]) > 0) Box.appendChild($impl.El("div","more",window.tn(Answer["more"],"and %d more","and %d more")));
        $impl.Open(Box,B,false);
      };
      function Soon(Ms, Hold) {
        window.clearTimeout(Timer);
        Timer = window.setTimeout(function () {
          Held = Hold;
          Show();
        },Ms);
      };
      function Drop() {
        window.clearTimeout(Timer);
        Wanted = false;
        if (($impl.Opened !== null) && ($impl.Opened["anchor"] == B)) $impl.Close(false);
      };
      function EndPointer(E) {
        if (E.pointerType !== "mouse") window.clearTimeout(Timer);
      };
      Timer = 0;
      Wanted = false;
      Held = false;
      B.addEventListener("pointerenter",function (E) {
        if (E.pointerType === "mouse") Soon(350,false);
      });
      B.addEventListener("pointerleave",function (E) {
        if (E.pointerType === "mouse") Drop();
      });
      B.addEventListener("focus",function (E) {
        if (B.matches(":focus-visible")) Soon(0,false);
      });
      B.addEventListener("blur",function (E) {
        Drop();
      });
      B.addEventListener("pointerdown",function (E) {
        Held = false;
        if (E.pointerType !== "mouse") Soon(500,true);
      });
      B.addEventListener("pointerup",EndPointer);
      B.addEventListener("pointercancel",EndPointer);
      B.addEventListener("contextmenu",function (E) {
        E.preventDefault();
        window.clearTimeout(Timer);
        Held = E.pointerType === "touch";
        if (($impl.Opened === null) || ($impl.Opened["anchor"] != B)) Show();
      });
      Result = function () {
        var Result = false;
        Result = Held;
        Held = false;
        if (!Result) Drop();
        return Result;
      };
      return Result;
    };
    $impl.Chip = function (R, Opts) {
      var Result = null;
      var B = null;
      var Held = null;
      var Cls = "";
      Cls = "react";
      if (Boolean(R["mine"])) Cls = Cls + " mine";
      B = $impl.El("button",Cls,undefined);
      B.type = "button";
      B.setAttribute("aria-pressed","" + Boolean(R["mine"]));
      B.append($impl.El("span","emoji",R["r"])," " + ("" + R["n"]));
      Held = $impl.WhoGave(B,function () {
        var Result = null;
        Result = Opts["who"].call(Opts,R);
        return Result;
      });
      B.addEventListener("click",function (E) {
        if (!Held()) Opts["toggle"].call(Opts,R);
      });
      Result = B;
      return Result;
    };
    $impl.Start = function () {
      $impl.Opened = null;
      document.addEventListener("pointerdown",function (E) {
        if (($impl.Opened !== null) && !$impl.Opened["box"].contains(E.target) && !$impl.Opened["anchor"].contains(E.target)) $impl.Close(false);
      },true);
      document.addEventListener("scroll",function (E) {
        if (($impl.Opened !== null) && !$impl.Opened["box"].contains(E.target)) $impl.Close(true);
      },true);
      window.addEventListener("resize",function (E) {
        $impl.Close(true);
      });
      document.addEventListener("pointermove",function (E) {
        if (($impl.Opened !== null) && !Boolean($impl.Opened["anchor"]["isConnected"])) $impl.Close(false);
      });
      document.addEventListener("keydown",function (E) {
        if (($impl.Opened === null) || (E.key !== "Escape")) return;
        E.preventDefault();
        E.stopPropagation();
        $impl.Close(true);
      },true);
      window["Reactions"] = pas.JS.New(["chips",$mod.Chips,"offer",$mod.Offer,"choose",$mod.Choose,"under",$mod.Under]);
    };
  };
  $mod.$init = function () {
    $impl.Start();
  };
},["PageKit","PageGlobals"]);

rtl.run('ReactionsPage');
}
