if (pas.search && pas.search.$state === rtl.m_initialized) pas.search.Start();
if (!pas.search)
rtl.module("search",["System"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  this.Start = function () {
    var Forms = null;
    var I = 0;
    Forms = document.querySelectorAll("form.site-search");
    for (var $l = 0, $end = Forms.length - 1; $l <= $end; $l++) {
      I = $l;
      $impl.Attach(Forms.item(I));
    };
  };
  $mod.$implcode = function () {
    $impl.Attach = function (Form) {
      var Input = null;
      var Scope = null;
      var Box = null;
      var Items = null;
      var Index = 0;
      var Asked = 0;
      var Timer = 0;
      function Close() {
        Box.hidden = true;
        Items = new Array();
        Index = -1;
      };
      function Select(I) {
        var N = 0;
        Index = I;
        for (var $l = 0, $end = Box.children.length - 1; $l <= $end; $l++) {
          N = $l;
          if (N === I) {
            Box.children.item(N).classList.add("on")}
           else Box.children.item(N).classList.remove("on");
        };
        if ((I >= 0) && (I < Box.children.length)) Box.children.item(I).scrollIntoView(pas.JS.New(["block","nearest"]));
      };
      function Pick(Item) {
        if (Boolean(Item["url"])) {
          window.location.href = "" + Item["url"];
          return;
        };
        Input["value"] = Item["text"];
        Close();
        Form.submit();
      };
      function BindRow(Row, I, Item) {
        Row.addEventListener("mousemove",function (E) {
          if (Index !== I) Select(I);
        });
        Row.addEventListener("mousedown",function (E) {
          E.preventDefault();
          Pick(Item);
        });
      };
      function Show(List) {
        var I = 0;
        var Row = null;
        var Part = null;
        var One = null;
        Box.replaceChildren();
        Items = List;
        Box.hidden = !Boolean(List.length);
        Index = -1;
        for (var $l = 0, $end = List.length - 1; $l <= $end; $l++) {
          I = $l;
          One = List[I];
          Row = pas.PageKit.MakeElement("div","item");
          Part = pas.PageKit.MakeElement("b","");
          Part["textContent"] = One["text"];
          Row.appendChild(Part);
          if (Boolean(One["caption"])) {
            Part = pas.PageKit.MakeElement("span","");
            Part.textContent = "" + One["caption"];
            Row.appendChild(Part);
          };
          BindRow(Row,I,One);
          Box.appendChild(Row);
        };
      };
      async function Look(Typed, Turn) {
        var Answer = null;
        var Data = null;
        var Where = "";
        Where = "";
        if (Scope !== null) Where = "" + Scope["value"];
        try {
          Answer = await window.fetch("/api/site-suggest?q=" + encodeURIComponent(Typed) + "&in=" + encodeURIComponent(Where));
          if (Answer.ok) {
            Data = await Answer.json()}
           else Data = pas.JS.New(["offers",new Array()]);
          if ((Turn === Asked) && (Input.value === Typed)) if (Boolean(Data["offers"])) {
            Show(Data["offers"])}
           else Show(new Array());
        } catch ($e) {
        };
      };
      function Ask() {
        var Typed = "";
        var Turn = 0;
        Typed = Input.value;
        Asked += 1;
        Turn = Asked;
        window.clearTimeout(Timer);
        if (Typed.trim().length < 2) {
          Close();
          return;
        };
        Timer = window.setTimeout(function () {
          Look(Typed,Turn);
        },150);
      };
      Input = Form.querySelector("input[name=q]");
      if ((Input === null) || Boolean(Input.dataset["offers"])) return;
      Input.dataset["offers"] = "1";
      Input.autocomplete = "off";
      Scope = Form.querySelector("[name=in]");
      Box = pas.PageKit.MakeElement("div","complete");
      Box.hidden = true;
      Form.appendChild(Box);
      Items = new Array();
      Index = -1;
      Asked = 0;
      Timer = 0;
      Input.addEventListener("input",function (E) {
        Ask();
      });
      if (Scope !== null) Scope.addEventListener("change",function (E) {
        Ask();
      });
      Input.addEventListener("keydown",function (E) {
        var Key = "";
        var Step = 0;
        if (Box.hidden || (Items.length === 0)) return;
        Key = E.key;
        if ((Key === "ArrowDown") || (Key === "ArrowUp")) {
          E.preventDefault();
          if (Key === "ArrowDown") {
            Step = 1}
           else Step = -1;
          if (Index < 0) {
            if (Step > 0) {
              Select(0)}
             else Select(Items.length - 1);
          } else Select((Index + Step + Items.length) % Items.length);
        } else if ((Key === "Enter") && (Index >= 0)) {
          E.preventDefault();
          Pick(Items[Index]);
        } else if (Key === "Escape") {
          Asked += 1;
          Close();
        };
      });
      Input.addEventListener("blur",function (E) {
        window.setTimeout(function () {
          Close();
        },150);
      });
    };
  };
  $mod.$init = function () {
    $mod.Start();
  };
},["JS","Web","PageKit"]);

rtl.run('search');
