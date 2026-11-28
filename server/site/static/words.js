if (!pas.WordsPage) {
rtl.module("WordsPage",["System","JS","Web"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  $mod.$implcode = function () {
    $impl.Words = null;
    $impl.T = function (English) {
      var Result = "";
      var Args = null;
      var Found = undefined;
      var Next = 0;
      Args = Array.prototype.slice.call(arguments,1);
      if (Object.prototype.hasOwnProperty.call($impl.Words,English) && Boolean(Reflect.get($impl.Words,English))) {
        Found = Reflect.get($impl.Words,English)}
       else Found = English;
      Next = 0;
      Result = Found.replace(new RegExp("%(?:(\\d+):)?[sd]","g"),function (Whole, Digits, Offset, Whole2) {
        var Result = "";
        var At = 0.0;
        if (typeof(Digits) === "undefined") {
          At = Next;
          Next += 1;
        } else At = Number(Digits);
        if (At < Args.length) {
          Result = String(Reflect.get(Args,At))}
         else Result = Whole;
        return Result;
      });
      return Result;
    };
    $impl.TN = function (N, One, Many) {
      var Result = undefined;
      var Form = undefined;
      if (N === 1) {
        Form = One}
       else Form = Many;
      Result = window.t.apply(null,(new Array(Form,N)).concat(Array.prototype.slice.call(arguments,3)));
      return Result;
    };
    $impl.Parts = function (Value) {
      var Result = null;
      var date = null;
      if (rtl.isString(Value) && (new RegExp("^\\d{4}-\\d{2}-\\d{2}$")).test("" + Value)) return pas.JS.New(["y",Number(Value.slice(0,4)),"m",Number(Value.slice(5,7)),"d",Number(Value.slice(8,10)),"date",new Date("" + Value + "T00:00:00")]);
      if (pas.JS.jsInstanceOf(Value,Date)) {
        date = Value}
       else date = new Date(Value);
      if (isNaN(date)) {
        Result = null}
       else Result = pas.JS.New(["y",date.getFullYear(),"m",date.getMonth() + 1,"d",date.getDate(),"date",date]);
      return Result;
    };
    $impl.Lang = function () {
      var Result = undefined;
      Result = document.documentElement.lang;
      if (!Boolean(Result)) Result = undefined;
      return Result;
    };
    $impl.Two = function (N) {
      var Result = "";
      Result = String(N).padStart(2,"0");
      return Result;
    };
    $impl.DateText = function (Value) {
      var Result = "";
      var P = null;
      var Pattern = undefined;
      P = $impl.Parts(Value);
      if (P === null) {
        if (Boolean(Value)) return String(Value);
        return String("");
      };
      Pattern = window["DATE_FORMAT"];
      if (!Boolean(Pattern)) Pattern = "m-d-yyyy";
      if (Pattern == "reader") return P["date"].toLocaleDateString($impl.Lang());
      Result = Pattern.replace(new RegExp("yyyy|mm|dd|m|d","g"),function (K) {
        var Result = "";
        if (K === "yyyy") {
          Result = String(P["y"])}
         else if (K === "mm") {
          Result = $impl.Two(P["m"])}
         else if (K === "dd") {
          Result = $impl.Two(P["d"])}
         else if (K === "m") {
          Result = String(P["m"])}
         else Result = String(P["d"]);
        return Result;
      });
      return Result;
    };
    $impl.DateTimeText = function (Value) {
      var Result = "";
      var P = null;
      P = $impl.Parts(Value);
      if (P === null) {
        if (Boolean(Value)) return String(Value);
        return String("");
      };
      Result = window.dateText(Value) + " " + P["date"].toLocaleTimeString($impl.Lang(),pas.JS.New(["hour","numeric","minute","2-digit"]));
      return Result;
    };
    $impl.Language = function (Form) {
      var Button = null;
      Button = Form.querySelector("button");
      if (Button !== null) Button.hidden = true;
      Form.querySelector("select").addEventListener("change",function (E) {
        Form.querySelector("[name=return]").value = SiteBase.path() + window.location.search;
        Form.submit();
      });
    };
    $impl.Ready = function (E) {
      var List = null;
      var I = 0;
      var El = null;
      var At = "";
      if (window["DATE_FORMAT"] == "reader") {
        List = document.querySelectorAll("time[data-show]");
        for (var $l = 0, $end = List.length - 1; $l <= $end; $l++) {
          I = $l;
          El = List.item(I);
          At = El.getAttribute("datetime");
          if (El.dataset["show"] === "datetime") {
            El.textContent = window.dateTimeText(At)}
           else El.textContent = window.dateText(At.slice(0,10));
        };
      };
      if (SiteBase.path() !== "/signin") {
        List = document.querySelectorAll('a[href="' + SiteBase.url("/signin") + '"]');
        for (var $l1 = 0, $end1 = List.length - 1; $l1 <= $end1; $l1++) {
          I = $l1;
          List.item(I).href = "/signin?return=" + encodeURIComponent(SiteBase.path() + window.location.search);
        };
      };
      List = document.querySelectorAll(".site-language");
      for (var $l2 = 0, $end2 = List.length - 1; $l2 <= $end2; $l2++) {
        I = $l2;
        $impl.Language(List.item(I));
      };
    };
    $impl.Start = function () {
      $impl.Words = window["WORDS"];
      if (!Boolean($impl.Words)) $impl.Words = new Object();
      window["t"] = $impl.T;
      window["tn"] = $impl.TN;
      window["dateText"] = $impl.DateText;
      window["dateTimeText"] = $impl.DateTimeText;
      document.addEventListener("DOMContentLoaded",$impl.Ready);
    };
  };
  $mod.$init = function () {
    $impl.Start();
  };
},["PageKit"]);

rtl.run('WordsPage');
}
