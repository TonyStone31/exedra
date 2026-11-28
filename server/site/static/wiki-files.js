if (!pas.WikiFilesPage) {
rtl.module("WikiFilesPage",["System"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  $mod.$implcode = function () {
    $impl.Say = function (Text) {
      var Result = "";
      if (Boolean(window["t"])) {
        Result = window.t(Text)}
       else Result = Text;
      return Result;
    };
    $impl.Upload = function (Form) {
      var Message = null;
      async function Send(E) {
        var Button = null;
        var Response = null;
        var Content = "";
        var Conflict = null;
        var Info = null;
        E.preventDefault();
        Button = Form.querySelector("button");
        Button.disabled = true;
        Message.textContent = "";
        try {
          try {
            Response = await window.fetch(Form.action,pas.JS.New(["method","POST","body",new FormData(Form)]));
            if (!Response.ok) {
              Content = await Response.text();
              try {
                Conflict = JSON.parse(Content);
                if (Boolean(Conflict["conflict"])) {
                  Form.elements.namedItem("name")["value"] = Conflict["suggested"];
                  Message.textContent = window.t("That name is already used. A free name has been filled in.");
                  return;
                };
              } catch ($e) {
              };
              throw new Error(Content);
            };
            Info = await Response.json();
            window.location.assign(window.SiteBase.url("" + Info["page"]));
          } catch ($e) {
            Message.textContent = "" + $e["message"];
          };
        } finally {
          Button.disabled = false;
        };
      };
      Message = pas.PageKit.MakeElement("p","");
      Message.setAttribute("role","status");
      Form.appendChild(Message);
      Form.addEventListener("submit",Send);
    };
    $impl.ConfirmDelete = function (Form) {
      Form.addEventListener("submit",function (E) {
        if (!window.confirm(Form.dataset["confirm"])) E.preventDefault();
      });
    };
    $impl.Viewer = function () {
      var Grid = null;
      var Items = null;
      var Box = null;
      var Stage = null;
      var Prev = null;
      var Next = null;
      var Close = null;
      var Bar = null;
      var Name = null;
      var Info = null;
      var Img = null;
      var Open = null;
      var At = 0;
      var Back = null;
      var StartX = undefined;
      var I = 0;
      function Show(N) {
        var A = null;
        At = (N + Items.length) % Items.length;
        A = Items.item(At);
        Img.src = A.dataset["view"];
        Name.textContent = A.querySelector(".wiki-file-name").textContent;
        Info.textContent = A.dataset["size"] + " · " + ("" + (At + 1)) + " / " + ("" + Items.length);
        Open.href = window.SiteBase.strip(A.getAttribute("href"));
        (new Image()).src = Items.item((At + 1) % Items.length).dataset["view"];
      };
      function Leave() {
        Box.hidden = true;
        document.documentElement.classList.remove("wiki-viewing");
        if (Back !== null) Back.focus();
      };
      function Bind(A, N) {
        A.addEventListener("click",function (E) {
          var Click = null;
          Click = E;
          if (Click.ctrlKey || Click.metaKey || Click.shiftKey || (Click.button !== 0)) return;
          E.preventDefault();
          Back = A;
          Show(N);
          Box.hidden = false;
          document.documentElement.classList.add("wiki-viewing");
          Close.focus();
        });
      };
      Grid = document.querySelector(".wiki-file-grid");
      if (Grid === null) return;
      Items = Grid.querySelectorAll("a[data-view]");
      if (Items.length === 0) return;
      Box = pas.PageKit.MakeElement("div","wiki-viewer");
      Box.setAttribute("role","dialog");
      Box.setAttribute("aria-modal","true");
      Box.hidden = true;
      Stage = pas.PageKit.MakeElement("div","wiki-viewer-stage");
      Img = pas.PageKit.MakeElement("img","");
      Img.alt = "";
      Stage.appendChild(Img);
      Prev = pas.PageKit.MakeElement("button","wiki-viewer-prev");
      Prev.textContent = "‹";
      Next = pas.PageKit.MakeElement("button","wiki-viewer-next");
      Next.textContent = "›";
      Close = pas.PageKit.MakeElement("button","wiki-viewer-close");
      Close.textContent = "×";
      Prev.type = "button";
      Next.type = "button";
      Close.type = "button";
      Prev.setAttribute("aria-label",$impl.Say("Previous"));
      Next.setAttribute("aria-label",$impl.Say("Next"));
      Close.setAttribute("aria-label",$impl.Say("Close"));
      Bar = pas.PageKit.MakeElement("div","wiki-viewer-bar");
      Name = pas.PageKit.MakeElement("b","");
      Info = pas.PageKit.MakeElement("span","");
      Open = pas.PageKit.MakeElement("a","");
      Open.textContent = $impl.Say("Open its page");
      Bar.append(Name,Info,Open);
      Box.append(Stage,Prev,Next,Close,Bar);
      document.body.appendChild(Box);
      At = 0;
      Back = null;
      for (var $l = 0, $end = Items.length - 1; $l <= $end; $l++) {
        I = $l;
        Bind(Items.item(I),I);
      };
      Prev.addEventListener("click",function (E) {
        Show(At - 1);
      });
      Next.addEventListener("click",function (E) {
        Show(At + 1);
      });
      Close.addEventListener("click",function (E) {
        Leave();
      });
      Box.addEventListener("click",function (E) {
        if ((E.target === Box) || (E.target === Stage)) Leave();
      });
      document.addEventListener("keydown",function (E) {
        var Key = "";
        if (Box.hidden) return;
        Key = E.key;
        if (Key === "Escape") {
          Leave()}
         else if (Key === "ArrowLeft") {
          Show(At - 1)}
         else if (Key === "ArrowRight") {
          Show(At + 1)}
         else return;
        E.preventDefault();
      });
      StartX = null;
      Stage.addEventListener("touchstart",function (E) {
        StartX = E.touches.item(0).clientX;
      },pas.JS.New(["passive",true]));
      Stage.addEventListener("touchend",function (E) {
        var Dx = 0.0;
        if (pas.JS.isNull(StartX)) return;
        Dx = E.changedTouches.item(0).clientX - rtl.getNumber(StartX);
        StartX = null;
        if (Math.abs(Dx) > 50) if (Dx < 0) {
          Show(At + 1)}
         else Show(At - 1);
      });
    };
    $impl.Start = function () {
      var Forms = null;
      var I = 0;
      Forms = document.querySelectorAll(".wiki-file-upload");
      for (var $l = 0, $end = Forms.length - 1; $l <= $end; $l++) {
        I = $l;
        $impl.Upload(Forms.item(I));
      };
      Forms = document.querySelectorAll("form.wiki-file-delete[data-confirm]");
      for (var $l1 = 0, $end1 = Forms.length - 1; $l1 <= $end1; $l1++) {
        I = $l1;
        $impl.ConfirmDelete(Forms.item(I));
      };
      $impl.Viewer();
    };
  };
  $mod.$init = function () {
    $impl.Start();
  };
},["JS","weborworker","Web","PageKit","PageGlobals"]);

rtl.run('WikiFilesPage');
}
