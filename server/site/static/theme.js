if (!pas.ThemePage) {
rtl.module("ThemePage",["System","JS","Web"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  $mod.$implcode = function () {
    $impl.Theme = "";
    $impl.Stored = function () {
      var Result = "";
      Result = "auto";
      try {
        Result = window.localStorage.getItem("theme");
        if (!Boolean(Result)) Result = "auto";
      } catch ($e) {
      };
      return Result;
    };
    $impl.Valid = function (Value) {
      var Result = "";
      if ((new Array("auto","light","dark")).includes(Value)) {
        Result = "" + Value}
       else Result = "auto";
      return Result;
    };
    $impl.Apply = function (Value) {
      var Pickers = null;
      var I = 0;
      $impl.Theme = $impl.Valid(Value);
      if ($impl.Theme === "auto") {
        pas.JS.JSDelete(document.documentElement.dataset,"theme")}
       else document.documentElement.dataset["theme"] = $impl.Theme;
      Pickers = document.querySelectorAll("[data-theme-picker]");
      for (var $l = 0, $end = Pickers.length - 1; $l <= $end; $l++) {
        I = $l;
        Pickers.item(I).value = $impl.Theme;
      };
      window.dispatchEvent(new Event("themechange"));
    };
    $impl.GetTheme = function () {
      var Result = "";
      Result = $impl.Theme;
      return Result;
    };
    $impl.SetTheme = function (Value) {
      $impl.Apply(Value);
      try {
        window.localStorage.setItem("theme",$impl.Theme);
      } catch ($e) {
      };
    };
    $impl.Show = function (Picker) {
      Picker.value = $impl.Theme;
      Picker.closest(".theme-choice").hidden = false;
      Picker.addEventListener("change",function (E) {
        Theme.set(Picker.value);
      });
    };
    $impl.Start = function () {
      $impl.Theme = $impl.Stored();
      window["Theme"] = pas.JS.New(["get",$impl.GetTheme,"set",$impl.SetTheme]);
      $impl.Apply($impl.Theme);
      window.addEventListener("storage",function (E) {
        if ((E.key === "theme") || pas.JS.isNull(E.key)) $impl.Apply($impl.Stored());
      });
      document.addEventListener("DOMContentLoaded",function (E) {
        var Pickers = null;
        var I = 0;
        Pickers = document.querySelectorAll("[data-theme-picker]");
        for (var $l = 0, $end = Pickers.length - 1; $l <= $end; $l++) {
          I = $l;
          $impl.Show(Pickers.item(I));
        };
      });
    };
  };
  $mod.$init = function () {
    $impl.Start();
  };
},["PageKit"]);

rtl.run('ThemePage');
}
