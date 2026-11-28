if (!pas.catalog) {
rtl.module("catalog",["System"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  $mod.$implcode = function () {
    $impl.Form = null;
    $impl.Status = null;
    $impl.Running = null;
    $impl.Waiting = 0;
    $impl.Same = function (A, B) {
      var Result = false;
      Result = (typeof(A) === typeof(B)) && (A == B);
      return Result;
    };
    $impl.Address = function (AForm) {
      var Result = "";
      var Query = null;
      var Entries = null;
      var Entry = null;
      var Pair = null;
      var Name = "";
      var Text = "";
      var Tail = "";
      Query = new URLSearchParams("");
      Entries = (new FormData(AForm)).entries();
      Entry = Entries.next();
      while (!Entry.done) {
        Pair = Entry.value;
        Name = "" + Pair[0];
        Text = ("" + Pair[1]).trim();
        if ((Text !== "") && !((Name === "q") && (Text.length < 2))) Query.set(Name,Text);
        Entry = Entries.next();
      };
      Tail = Query.toString();
      Result = AForm.getAttribute("action");
      if (Tail !== "") Result = Result + "?" + Tail;
      return Result;
    };
    var Parts = [".catalog-types",".catalog-cards",".findpages"];
    $impl.Refresh = async function () {
      var Url = "";
      var Text = "";
      var Mine = null;
      var Answer = null;
      var Page = null;
      var Fresh = null;
      var Old = null;
      var I = 0;
      Url = $impl.Address($impl.Form);
      if ($impl.Running !== null) $impl.Running.abort();
      Mine = new AbortController();
      $impl.Running = Mine;
      if ($impl.Status !== null) if (pas.JS.isUndefined($impl.Status.dataset["busy"])) {
        $impl.Status.textContent = ""}
       else $impl.Status.textContent = $impl.Status.dataset["busy"];
      try {
        Answer = await pas.PageKit.Get(Url,pas.JS.New(["signal",Mine.signal,"credentials","same-origin"]));
        Text = await Answer.text();
        if (Mine !== $impl.Running) return;
        if (!Answer.ok) {
          if ($impl.Status !== null) $impl.Status.textContent = Text.slice(0,200);
          return;
        };
        Page = (new DOMParser()).parseFromString(Text,"text/html");
        for (I = 0; I <= 2; I++) {
          Fresh = Page.querySelector(Parts[I]);
          Old = document.querySelector(Parts[I]);
          if ((Fresh !== null) && (Old !== null)) Old.parentNode.replaceChild(Fresh,Old);
        };
        window.history.replaceState(null,"",Url);
        if ($impl.Status !== null) $impl.Status.textContent = "";
      } catch ($e) {
        if (!pas.JS.isNull($e) && !pas.JS.isUndefined($e)) if (("" + $e["name"]) === "AbortError") return;
        window.location.assign(Url);
      };
    };
    $impl.Show = function (Entry, Answer) {
      var Forms = null;
      var Buttons = null;
      var Lines = null;
      var Stars = null;
      var Line = null;
      var Button = null;
      var Clear = null;
      var I = 0;
      var J = 0;
      var Value = 0.0;
      var Lit = false;
      Forms = document.querySelectorAll('.rate-form[data-entry="' + Entry + '"]');
      for (var $l = 0, $end = Forms.length - 1; $l <= $end; $l++) {
        I = $l;
        Stars = Forms.item(I);
        Buttons = Stars.querySelectorAll(".rate-star");
        for (var $l1 = 0, $end1 = Buttons.length - 1; $l1 <= $end1; $l1++) {
          J = $l1;
          Button = Buttons.item(J);
          Value = Number(Button.value);
          Lit = Value <= Number(Answer["mine"]);
          if (Lit) {
            Button.classList.add("on")}
           else Button.classList.remove("on");
          if (Lit) {
            Button.textContent = "★"}
           else Button.textContent = "☆";
          if ($impl.Same(Value,Answer["mine"])) {
            Button.setAttribute("aria-pressed","true")}
           else Button.setAttribute("aria-pressed","false");
        };
        Clear = Stars.querySelector(".rate-clear");
        if (Clear !== null) Clear.hidden = $impl.Same(Answer["mine"],0);
      };
      Lines = document.querySelectorAll('[data-rating-summary="' + Entry + '"]');
      for (var $l2 = 0, $end2 = Lines.length - 1; $l2 <= $end2; $l2++) {
        I = $l2;
        Line = Lines.item(I);
        if (Boolean(Answer["summary"])) {
          Line.textContent = "" + Answer["summary"]}
         else if (!pas.JS.isUndefined(Line.dataset["none"])) {
          Line.textContent = Line.dataset["none"]}
         else Line.textContent = "";
      };
    };
    $impl.Rate = async function (E) {
      var Stars = null;
      var Submitter = null;
      var Body = null;
      var Answer = null;
      var Data = null;
      var Kept = null;
      Stars = pas.PageKit.Closest(E.target,".rate-form");
      Submitter = E["submitter"];
      if ((Stars === null) || pas.JS.isUndefined(Submitter) || (Submitter === null)) return;
      E.preventDefault();
      Body = new URLSearchParams("");
      Body.set("stars",Submitter.value);
      try {
        Answer = await pas.PageKit.Post(Stars.action,Body,pas.JS.New(["Accept","application/json"]));
        if (!Answer.ok) {
          if ($impl.Status !== null) $impl.Status.textContent = (await Answer.text()).slice(0,200);
          return;
        };
        Data = await Answer.json();
        $impl.Show(Stars.dataset["entry"],Data);
      } catch ($e) {
        Kept = pas.PageKit.MakeElement("input","");
        Kept.type = "hidden";
        Kept.name = "stars";
        Kept.value = Submitter.value;
        Stars.appendChild(Kept);
        Stars.submit();
      };
    };
    $impl.Start = function () {
      var Go = null;
      window["CatalogFilters"] = pas.JS.New(["address",$impl.Address]);
      $impl.Form = document.querySelector(".catalog-form");
      $impl.Status = document.querySelector(".catalog-updating");
      $impl.Running = null;
      $impl.Waiting = 0;
      if ($impl.Form !== null) {
        Go = $impl.Form.querySelector(".catalog-go");
        if (Go !== null) Go.hidden = true;
        $impl.Form.addEventListener("change",function (E) {
          if (E.target.matches("select")) $impl.Refresh();
        });
        $impl.Form.addEventListener("input",function (E) {
          var Text = "";
          if (!E.target.matches("input[name=q]")) return;
          Text = E.target.value.trim();
          window.clearTimeout($impl.Waiting);
          if (Text.length === 1) return;
          $impl.Waiting = window.setTimeout(function () {
            $impl.Refresh();
          },300);
        });
        $impl.Form.addEventListener("submit",function (E) {
          E.preventDefault();
          window.clearTimeout($impl.Waiting);
          $impl.Refresh();
        });
      };
      document.addEventListener("click",function (E) {
        var Link = null;
        var Field = null;
        Link = pas.PageKit.Closest(E.target,".catalog-types a");
        if ((Link === null) || ($impl.Form === null)) return;
        E.preventDefault();
        Field = $impl.Form.querySelector("[name=type]");
        if (Field !== null) if (pas.JS.isUndefined(Link.dataset["type"])) {
          Field.value = ""}
         else Field.value = Link.dataset["type"];
        $impl.Refresh();
      });
      document.addEventListener("submit",$impl.Rate);
    };
  };
  $mod.$init = function () {
    $impl.Start();
  };
},["JS","Web","PageKit"]);

rtl.run('catalog');
}
