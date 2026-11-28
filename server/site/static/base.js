if (!pas.BasePage) {
rtl.module("BasePage",["System","JS","Web"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  $mod.$implcode = function () {
    $impl.Base = "";
    $impl.Url = function (Address) {
      var Result = undefined;
      if (($impl.Base !== "") && rtl.isString(Address) && (Address.charAt(0) === "/") && (Address.charAt(1) !== "/")) {
        Result = $impl.Base + ("" + Address)}
       else Result = Address;
      return Result;
    };
    $impl.Strip = function (Address) {
      var Result = undefined;
      var Rest = "";
      var First = "";
      Result = Address;
      if (($impl.Base === "") || !rtl.isString(Address) || (Address.indexOf($impl.Base,0) !== 0)) return Result;
      Rest = Address.slice($impl.Base.length);
      First = Rest.charAt(0);
      if (Rest === "") {
        Result = "/"}
       else if (First === "/") {
        Result = Rest}
       else if ((First === "?") || (First === "#")) Result = "/" + Rest;
      return Result;
    };
    $impl.Path = function () {
      var Result = undefined;
      Result = $impl.Strip(window.location.pathname);
      return Result;
    };
    $impl.WrapHistory = function (Name) {
      var Now = null;
      Now = window.history[Name];
      window.history[Name] = function (State, Title, Address) {
        var Result = undefined;
        if (typeof(Address) === "undefined") {
          Result = Now.call(window.history,State,Title)}
         else Result = Now.call(window.history,State,Title,$impl.Url(Address));
        return Result;
      };
    };
    $impl.Prefix = function (Proto, Name) {
      var D = null;
      D = Object.getOwnPropertyDescriptor(Proto,Name);
      if (!Boolean(D) || !Boolean(D["set"])) return;
      Object.defineProperty(Proto,Name,pas.JS.New(["configurable",true,"enumerable",D["enumerable"],"get",D["get"],"set",function (Value) {
        D["set"].call(this,$impl.Url(Value));
      }]));
    };
    $impl.Start = function () {
      var FetchNow = null;
      var OpenNow = null;
      var SetNow = null;
      $impl.Base = "";
      try {
        $impl.Base = (new URL(document.currentScript.src)).pathname.replace(new RegExp("\\/static\\/base\\.js$"),"");
      } catch ($e) {
      };
      window["SiteBase"] = pas.JS.New(["base",$impl.Base,"url",$impl.Url,"strip",$impl.Strip,"path",$impl.Path]);
      if ($impl.Base === "") return;
      FetchNow = window["fetch"];
      window["fetch"] = function (Input, Init) {
        var Result = undefined;
        Result = FetchNow.call(this,$impl.Url(Input),Init);
        return Result;
      };
      OpenNow = XMLHttpRequest.prototype["open"];
      XMLHttpRequest.prototype["open"] = function () {
        var Result = undefined;
        arguments[1] = $impl.Url(arguments[1]);
        Result = OpenNow.apply(this,arguments);
        return Result;
      };
      $impl.WrapHistory("pushState");
      $impl.WrapHistory("replaceState");
      $impl.Prefix(HTMLAnchorElement.prototype,"href");
      $impl.Prefix(HTMLLinkElement.prototype,"href");
      $impl.Prefix(HTMLImageElement.prototype,"src");
      $impl.Prefix(HTMLScriptElement.prototype,"src");
      $impl.Prefix(HTMLSourceElement.prototype,"src");
      $impl.Prefix(HTMLMediaElement.prototype,"src");
      $impl.Prefix(HTMLFormElement.prototype,"action");
      SetNow = Element.prototype["setAttribute"];
      Element.prototype["setAttribute"] = function (Name, Value) {
        var Result = undefined;
        if ((Name === "href") || (Name === "src") || (Name === "action") || (Name === "poster")) Value = $impl.Url(Value);
        Result = SetNow.call(this,Name,Value);
        return Result;
      };
    };
  };
  $mod.$init = function () {
    $impl.Start();
  };
},["PageKit"]);

rtl.run('BasePage');
}
