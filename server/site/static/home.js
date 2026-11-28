if (!pas.home) {
rtl.module("home",["System"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  $mod.$implcode = function () {
    $impl.ReturnAddress = function () {
      var Result = "";
      var Back = "";
      var Value = undefined;
      var Url = null;
      Result = "";
      Value = (new URLSearchParams(window.location.search)).get("return");
      if (pas.JS.isNull(Value) || pas.JS.isUndefined(Value)) return Result;
      Back = "" + Value;
      if ((Back.charAt(0) !== "/") || (new RegExp("^.[/\\\\]")).test(Back) || (new RegExp("[\\u0000-\\u001f\\u007f\\\\]")).test(Back)) return Result;
      try {
        Url = new URL(Back,window.location.origin);
      } catch ($e) {
        return Result;
      };
      if ((Url.origin !== window.location.origin) || (Url.pathname.indexOf("/signin",0) === 0)) return Result;
      Result = Url.pathname + Url.search + Url.hash;
      return Result;
    };
    $impl.Joined = function () {
      var Chat = null;
      if ($impl.ReturnAddress() !== "") {
        window.location.href = window.SiteBase.url($impl.ReturnAddress());
        return;
      };
      Chat = document.querySelector(".topbar nav a");
      if (Chat !== null) {
        window.location.href = Chat.getAttribute("href")}
       else window.location.href = window.SiteBase.url("/");
    };
    $impl.NewPassword = function (Form) {
      async function Save(E) {
        E.preventDefault();
        try {
          await window.Keys.setNewPassword(Form.dataset["token"],Form.dataset["name"],Form.elements.namedItem("password").value);
          window.location.href = window.SiteBase.url("/");
        } catch ($e) {
          window.alert("" + $e["message"]);
        };
      };
      Form.addEventListener("submit",Save);
    };
    $impl.Forgot = function (Form) {
      var Box = null;
      var Opened = 0;
      async function Send(E) {
        var Website = null;
        var Address = "";
        var Age = 0;
        E.preventDefault();
        try {
          Website = Form.elements.namedItem("website");
          Address = "";
          if (Website !== null) Address = Website.value;
          Age = -1;
          if (Opened !== 0) Age = Date.now() - Opened;
          window.alert(await window.Keys.post("/api/forgot",pas.JS.New(["who",Form.elements.namedItem("who").value,"website",Address,"opened",Age])));
        } catch ($e) {
          window.alert("" + $e["message"]);
        };
      };
      Box = Form.closest("details");
      Opened = 0;
      if ((Box !== null) && (Box["open"] == true)) Opened = Date.now();
      if (Box !== null) Box.addEventListener("toggle",function (E) {
        if ((Box["open"] == true) && (Opened === 0)) Opened = Date.now();
      });
      Form.addEventListener("submit",Send);
    };
    $impl.SignOut = async function (E) {
      E.preventDefault();
      await window.Keys.signOut();
      window.location.reload();
    };
    $impl.CopyText = function (Pre) {
      var Button = null;
      Button = pas.PageKit.MakeElement("button","copybtn");
      Button.type = "button";
      Button.textContent = pas.PageKit.Word("Copy");
      Button.addEventListener("click",function (E) {
        window.navigator.clipboard.writeText(Pre.textContent).then(function (Value) {
          var Result = undefined;
          Button.textContent = pas.PageKit.Word("Copied");
          return Result;
        });
      });
      Pre.before(Button);
    };
    $impl.Filter = function (E) {
      var Words = "";
      var Items = null;
      var I = 0;
      var Item = null;
      Words = E.currentTarget.value.toLowerCase().trim();
      Items = document.querySelectorAll("[data-find]");
      for (var $l = 0, $end = Items.length - 1; $l <= $end; $l++) {
        I = $l;
        Item = Items.item(I);
        Item.hidden = (Words !== "") && !Item.dataset["find"].includes(Words,0);
      };
    };
    $impl.Start = function () {
      var Nodes = null;
      var I = 0;
      var A = null;
      var Find = null;
      if ($impl.ReturnAddress() !== "") {
        Nodes = document.querySelectorAll('a.sso[href^="' + window.SiteBase.url("/signin-with/") + '"]');
        for (var $l = 0, $end = Nodes.length - 1; $l <= $end; $l++) {
          I = $l;
          A = Nodes.item(I);
          A.href = window.SiteBase.strip(A.getAttribute("href")).split("?")[0] + "?return=" + encodeURIComponent($impl.ReturnAddress());
        };
      };
      window.Keys.bindJoinForms($impl.Joined);
      Nodes = document.querySelectorAll("form.newpassword");
      for (var $l1 = 0, $end1 = Nodes.length - 1; $l1 <= $end1; $l1++) {
        I = $l1;
        $impl.NewPassword(Nodes.item(I));
      };
      Nodes = document.querySelectorAll("form.forgot");
      for (var $l2 = 0, $end2 = Nodes.length - 1; $l2 <= $end2; $l2++) {
        I = $l2;
        $impl.Forgot(Nodes.item(I));
      };
      Nodes = document.querySelectorAll(".signout");
      for (var $l3 = 0, $end3 = Nodes.length - 1; $l3 <= $end3; $l3++) {
        I = $l3;
        Nodes.item(I).addEventListener("click",$impl.SignOut);
      };
      Nodes = document.querySelectorAll("pre.copy");
      for (var $l4 = 0, $end4 = Nodes.length - 1; $l4 <= $end4; $l4++) {
        I = $l4;
        $impl.CopyText(Nodes.item(I));
      };
      Find = document.getElementById("find");
      if (Find !== null) Find.addEventListener("input",$impl.Filter);
    };
  };
  $mod.$init = function () {
    $impl.Start();
  };
},["JS","Web","PageKit","PageGlobals"]);

rtl.run('home');
}
