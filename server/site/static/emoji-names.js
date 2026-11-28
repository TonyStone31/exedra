if (!pas.EmojiNamesPage) {
rtl.module("EmojiNamesPage",["System","JS","Web"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  this.List = function () {
    var Result = null;
    if (!Boolean($impl.Asked)) $impl.Asked = fetch("/static/emoji-names.txt").then(function (R) {
      var Result = undefined;
      if (Boolean(R["ok"])) {
        Result = R.text()}
       else Result = "";
      return Result;
    }).then(function (Text) {
      var Result = undefined;
      var Found = null;
      var Group = undefined;
      var Lines = null;
      var Parts = null;
      var Line = "";
      var T = null;
      var I = 0;
      Found = new Array();
      Group = "";
      T = $impl.Translate;
      Lines = Text.split("\n");
      for (var $l = 0, $end = Lines.length - 1; $l <= $end; $l++) {
        I = $l;
        Line = "" + Lines[I];
        Parts = Line.split(" ");
        if (Line.startsWith("## ")) {
          Group = T(Line.slice(3))}
         else if ((Line !== "") && !Line.startsWith("#")) Found.push(pas.JS.New(["emoji",Parts[0],"name",Parts[1],"group",Group,"keywords",Parts.slice(1)]));
      };
      Result = Found;
      return Result;
    });
    Result = $impl.Asked;
    return Result;
  };
  this.Typed = function (Text, At, Short) {
    var Result = null;
    var M = null;
    var Word = "";
    var Colon = "";
    var Least = 0;
    Result = null;
    M = (new RegExp("(^|[^A-Za-z0-9:/\\\\_]):([A-Za-z0-9+_-]{0,30})(:?)$")).exec(Text.slice(Math.max(0,At - 34),At));
    if (!Boolean(M)) return Result;
    Word = "" + M[2];
    Colon = "" + M[3];
    if (Boolean(Short)) {
      Least = 0}
     else Least = 2;
    if (Colon !== "") {
      if (Word === "") return Result;
    } else if (Word.length < Least) return Result;
    if ($impl.InCode(Text.slice(0,At))) return Result;
    Result = pas.JS.New(["word",Word.toLowerCase(),"from",At - Word.length - Colon.length - 1,"whole",Colon !== ""]);
    return Result;
  };
  this.Matches = function (Items, Word) {
    var Result = null;
    var Found = null;
    var Keywords = null;
    var E = null;
    var Starts = undefined;
    var Holds = undefined;
    var FirstName = undefined;
    var Rank = 0;
    var I = 0;
    if (!Boolean(Word)) return Items;
    Found = new Array();
    for (var $l = 0, $end = Items.length - 1; $l <= $end; $l++) {
      I = $l;
      E = Items[I];
      Keywords = E["keywords"];
      Starts = Keywords.find(function (K, Index, A) {
        var Result = false;
        Result = K.indexOf(Word,0) === 0;
        return Result;
      });
      Holds = Starts;
      if (!Boolean(Holds)) Holds = Keywords.find(function (K, Index, A) {
        var Result = false;
        Result = K.indexOf(Word,0) > 0;
        return Result;
      });
      if (Boolean(Holds)) {
        if (("" + Holds) === Word) {
          Rank = 0}
         else if (Boolean(Starts)) {
          Rank = 1}
         else Rank = 2;
        Found.push(Object.assign(new Object(),E,pas.JS.New(["match",Holds,"rank",Rank])));
      } else if (E["name"].toLowerCase().indexOf(Word,0) >= 0) {
        FirstName = Keywords[0];
        if (!Boolean(FirstName)) FirstName = "";
        Found.push(Object.assign(new Object(),E,pas.JS.New(["match",FirstName,"rank",2])));
      };
    };
    Result = Found.sort(function (X, Y) {
      var Result = 0;
      Result = rtl.trunc(X["rank"]) - rtl.trunc(Y["rank"]);
      if ((Result === 0) && (rtl.trunc(X["rank"]) < 2)) Result = (("" + X["match"])).length - (("" + Y["match"])).length;
      return Result;
    });
    return Result;
  };
  this.Named = function (Items, Word) {
    var Result = undefined;
    Result = Items.find(function (E, Index, A) {
      var Result = false;
      Result = E["keywords"].indexOf(Word) >= 0;
      return Result;
    });
    return Result;
  };
  this.After = function (Items) {
    var Result = null;
    Result = $mod.List().then(function (More) {
      var Result = undefined;
      var All = null;
      var Free = null;
      var E = null;
      var Own = null;
      var I = 0;
      All = Items.slice();
      for (var $l = 0, $end = More.length - 1; $l <= $end; $l++) {
        I = $l;
        E = More[I];
        Free = E["keywords"].filter(function (K, Index, A) {
          var Result = false;
          Result = !Boolean($mod.Named(Items,K));
          return Result;
        });
        Own = All.find(function (X, Index, A) {
          var Result = false;
          Result = $impl.Plain(X["emoji"]) === $impl.Plain(E["emoji"]);
          return Result;
        });
        if (Boolean(Own)) {
          Own["keywords"] = Own["keywords"].concat(Free)}
         else if (Boolean(Free.length)) All.push(Object.assign(new Object(),E,pas.JS.New(["keywords",Free])));
      };
      Result = All;
      return Result;
    });
    return Result;
  };
  $mod.$implcode = function () {
    $impl.Translate = null;
    $impl.Asked = null;
    $impl.InCode = function (Before) {
      var Result = false;
      var Fence = false;
      var Lines = null;
      var Line = "";
      var I = 0;
      Fence = false;
      Lines = Before.split("\n").slice(0,-1);
      for (var $l = 0, $end = Lines.length - 1; $l <= $end; $l++) {
        I = $l;
        if ((new RegExp("^ {0,3}(`{3,}|~{3,})")).test("" + Lines[I])) Fence = !Fence;
      };
      Line = Before.slice(Before.lastIndexOf("\n") + 1);
      Result = Fence || (new RegExp("^( {4}|\\t)")).test(Line) || (((rtl.length(Line.split("`")) - 1) % 2) === 1);
      return Result;
    };
    $impl.Plain = function (S) {
      var Result = "";
      Result = S.replace(new RegExp("️","g"),"");
      return Result;
    };
    $impl.Start = function () {
      $impl.Translate = window["t"];
      if (!Boolean($impl.Translate)) $impl.Translate = function (S) {
        var Result = undefined;
        Result = S;
        return Result;
      };
      $impl.Asked = null;
      window["EmojiNames"] = pas.JS.New(["list",$mod.List,"typed",$mod.Typed,"matches",$mod.Matches,"named",$mod.Named,"after",$mod.After]);
    };
  };
  $mod.$init = function () {
    $impl.Start();
  };
},["PageKit"]);

rtl.run('EmojiNamesPage');
}
