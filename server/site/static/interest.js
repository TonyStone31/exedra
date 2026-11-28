if (!pas.interest) {
rtl.module("interest",["System"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  $mod.$implcode = function () {
    $impl.Reduce = false;
    $impl.Leaving = false;
    $impl.Say = function (Text) {
      var Result = "";
      if (Boolean(window["t"])) {
        Result = window.t(Text)}
       else Result = Text;
      return Result;
    };
    $impl.Cheer = function (Button) {
      var Plus = null;
      var Width = 0.0;
      if (Boolean(window["matchMedia"]) && window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
      Button.classList.remove("pop");
      Width = Button.offsetWidth;
      Button.classList.add("pop");
      Plus = pas.PageKit.MakeElement("span","plus-one");
      Plus.setAttribute("aria-hidden","true");
      Plus.textContent = "+1";
      Button.appendChild(Plus);
      window.setTimeout(function () {
        Plus.remove();
      },900);
    };
    $impl.Invite = function () {
      var Note = null;
      var Join = null;
      var Close = null;
      if (!document.body.classList.contains("guest")) return;
      try {
        if (Boolean(window.sessionStorage.getItem("interest-invited"))) return;
        window.sessionStorage.setItem("interest-invited","1");
      } catch ($e) {
        return;
      };
      Note = pas.PageKit.MakeElement("div","interest-invite");
      Note.setAttribute("role","status");
      Note.appendChild(document.createTextNode($impl.Say("Thanks! Members can also rate entries.") + " "));
      Join = pas.PageKit.MakeElement("a","");
      Join.href = "/signin?return=" + encodeURIComponent(window.location.pathname + window.location.search);
      Join.textContent = $impl.Say("Join");
      Note.appendChild(Join);
      Close = pas.PageKit.MakeElement("button","");
      Close.type = "button";
      Close.textContent = "×";
      Close.setAttribute("aria-label",$impl.Say("Hide"));
      Close.addEventListener("click",function (E) {
        Note.remove();
      });
      Note.appendChild(Close);
      document.body.appendChild(Note);
      window.setTimeout(function () {
        Note.classList.add("gone");
      },9000);
      window.setTimeout(function () {
        Note.remove();
      },9600);
    };
    $impl.Show = function (Entry, Answer, Pressed) {
      var Forms = null;
      var Form = null;
      var Button = null;
      var I = 0;
      Forms = document.querySelectorAll('.interest-form[data-entry="' + Entry + '"]');
      for (var $l = 0, $end = Forms.length - 1; $l <= $end; $l++) {
        I = $l;
        Form = Forms.item(I);
        Button = Form.querySelector(".interest-button");
        if (Boolean(Answer["mine"]) && (Form === Pressed)) $impl.Cheer(Button);
        Button.classList["toggle"].call(Button.classList,"on",Answer["mine"]);
        if (Boolean(Answer["mine"])) {
          Button.setAttribute("aria-pressed","true");
          Button.title = $impl.Say("You find this interesting. Press again to take it back.");
        } else {
          Button.setAttribute("aria-pressed","false");
          Button.title = $impl.Say("Tell others this looks interesting");
        };
        Form.querySelector(".interest-count").textContent = "" + Answer["interest"];
      };
    };
    $impl.Press = async function (E) {
      var Form = null;
      var Button = null;
      var Answer = null;
      var Data = null;
      Form = pas.PageKit.Closest(E.target,".interest-form");
      if (Form === null) return;
      E.preventDefault();
      Button = Form.querySelector(".interest-button");
      if (Button.disabled) return;
      Button.disabled = true;
      try {
        try {
          Answer = await window.fetch(Form.action,pas.JS.New(["method","POST","credentials","same-origin","headers",pas.JS.New(["Accept","application/json"])]));
          if (Answer.ok) {
            Data = await Answer.json();
            $impl.Show(Form.dataset["entry"],Data,Form);
            if (Boolean(Data["mine"])) $impl.Invite();
          } else Button.title = (await Answer.text()).slice(0,200);
        } catch ($e) {
          Form.submit();
        };
      } finally {
        Button.disabled = false;
      };
    };
    $impl.ByHand = function (Url) {
      var Result = "";
      Result = Url;
      if ((new RegExp("[?&]hand=1")).test(Url)) return Result;
      if (Url.indexOf("?",0) >= 0) {
        Result = Url + "&hand=1"}
       else Result = Url + "?hand=1";
      return Result;
    };
    $impl.HandField = function (Form) {
      var Field = null;
      if (Form.querySelector('input[name="hand"]') !== null) return;
      Field = pas.PageKit.MakeElement("input","");
      Field.type = "hidden";
      Field.name = "hand";
      Field.value = "1";
      Form.appendChild(Field);
    };
    $impl.Leave = function (How, Go) {
      var Button = null;
      var Entry = null;
      var Burst = null;
      var Star = null;
      var Drawn = null;
      var Spark = null;
      var At = null;
      var Box = null;
      var X = 0.0;
      var Y = 0.0;
      var Width = 0.0;
      var Height = 0.0;
      var I = 0;
      var Delay = 0;
      if ($impl.Leaving) return;
      $impl.Leaving = true;
      if ($impl.Reduce) {
        Go();
        return;
      };
      document.body.classList.add("leaving","leaving-" + How);
      if (How === "yes") {
        Button = document.querySelector(".discover-yes");
        X = window.innerWidth / 2;
        Y = window.innerHeight / 2;
        Width = 0;
        Height = 0;
        if (Button !== null) {
          At = Button.getBoundingClientRect();
          X = At.left;
          Y = At.top;
          Width = At.width;
          Height = At.height;
        };
        X = X + (Width / 2);
        Y = Y + (Height / 2);
        Entry = document.querySelector(".catalog-entry");
        if (Entry !== null) {
          Box = Entry.getBoundingClientRect();
          Entry.style.setProperty("transform-origin","" + (X - Box.left) + "px " + ("" + (Y - Box.top)) + "px");
        };
        Burst = pas.PageKit.MakeElement("div","star-burst");
        Burst.setAttribute("aria-hidden","true");
        Burst.style.setProperty("left","" + X + "px");
        Burst.style.setProperty("top","" + Y + "px");
        Star = pas.PageKit.MakeElement("span","fly-star");
        Drawn = document.querySelector(".discover-yes .star-icon");
        if (Drawn !== null) {
          Star.appendChild(Drawn.cloneNode(true))}
         else Star.textContent = "★";
        Burst.appendChild(Star);
        for (I = 0; I <= 6; I++) {
          Spark = pas.PageKit.MakeElement("i","");
          Spark.style.setProperty("--a","" + ((I * 51) + 20) + "deg");
          Spark.style.setProperty("--d","" + (70 + ((I % 3) * 30)) + "px");
          Burst.appendChild(Spark);
        };
        document.body.appendChild(Burst);
        if (Boolean(window.navigator["vibrate"])) try {
          window.navigator.vibrate(18);
        } catch ($e) {
        };
      };
      Entry = document.querySelector(".catalog-entry");
      if (Entry !== null) Entry.classList.remove("arrive-yes","arrive-no");
      if (How === "yes") {
        Delay = 950}
       else Delay = 520;
      window.setTimeout(Go,Delay);
    };
    $impl.Narrow = function (Form) {
      var Go = null;
      Go = Form.querySelector("button");
      if (Go !== null) Go.hidden = true;
      Form.addEventListener("change",function (E) {
        $impl.HandField(Form);
        if (Boolean(Form["requestSubmit"])) {
          Form.requestSubmit()}
         else Form.submit();
      });
    };
    $impl.Start = function () {
      var Forms = null;
      var I = 0;
      document.addEventListener("submit",$impl.Press);
      $impl.Reduce = Boolean(window["matchMedia"]) && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
      $impl.Leaving = false;
      window.addEventListener("pageshow",function (E) {
        var Bursts = null;
        var Done = null;
        var N = 0;
        if (!Boolean(E["persisted"])) return;
        $impl.Leaving = false;
        document.body.classList.remove("leaving","leaving-yes","leaving-no");
        Bursts = document.querySelectorAll(".star-burst");
        for (var $l = 0, $end = Bursts.length - 1; $l <= $end; $l++) {
          N = $l;
          Bursts.item(N).remove();
        };
        Done = document.querySelector(".discover-yes.done");
        if (Done !== null) Done.classList.remove("done");
      });
      document.addEventListener("click",function (E) {
        var Link = null;
        Link = pas.PageKit.Closest(E.target,'a[href^="/catalog-random"]');
        if (Link !== null) Link.href = $impl.ByHand(Link.getAttribute("href"));
      },true);
      document.addEventListener("submit",function (E) {
        var Form = null;
        var Button = null;
        var Count = null;
        var Value = 0.0;
        Form = pas.PageKit.Closest(E.target,".discover-bar form");
        if ((Form === null) || (Form.querySelector(".discover-yes") === null)) return;
        E.preventDefault();
        $impl.HandField(Form);
        Button = Form.querySelector(".discover-yes");
        if (Button !== null) {
          Button.classList.add("done");
          Count = document.querySelector(".catalog-entry .interest-count");
          if (Count !== null) {
            if (Count.textContent === "") {
              Value = 0}
             else Value = Number(Count.textContent);
            Count.textContent = "" + (Value + 1);
          };
        };
        $impl.Leave("yes",function () {
          Form.submit();
        });
      });
      document.addEventListener("click",function (E) {
        var Link = null;
        var Click = null;
        Link = pas.PageKit.Closest(E.target,".discover-bar .discover-no");
        Click = E;
        if ((Link === null) || Click.metaKey || Click.ctrlKey || (Click.button !== 0)) return;
        E.preventDefault();
        $impl.Leave("no",function () {
          window.location.href = Link.href;
        });
      });
      Forms = document.querySelectorAll(".discover-choice");
      for (var $l = 0, $end = Forms.length - 1; $l <= $end; $l++) {
        I = $l;
        $impl.Narrow(Forms.item(I));
      };
      document.addEventListener("keydown",function (E) {
        var Key = null;
        var Target = null;
        var Control = null;
        Key = E;
        if (Key.altKey || Key.ctrlKey || Key.metaKey || Key.shiftKey) return;
        if ((new URLSearchParams(window.location.search)).get("discover") !== "1") return;
        Target = E.target;
        if ((Target !== null) && (Target.isContentEditable || (new RegExp("^(INPUT|TEXTAREA|SELECT)$")).test(Target.tagName))) return;
        if (pas.PageKit.Closest(Target,".catalog-readme, pre, table") !== null) return;
        Control = document.querySelector('.discover-bar [data-key="' + Key.key + '"]');
        if (Control === null) return;
        E.preventDefault();
        Control.click();
      });
      document.addEventListener("error",function (E) {
        var Picture = null;
        var Thumb = null;
        Picture = E.target;
        if ((Picture !== null) && (Picture.tagName === "IMG") && (Picture.closest(".catalog-icon, .catalog-thumb, .catalog-readme") !== null)) {
          Thumb = Picture.closest(".catalog-thumb");
          if (Thumb !== null) {
            Thumb.remove()}
           else Picture.remove();
        };
      },true);
    };
  };
  $mod.$init = function () {
    $impl.Start();
  };
},["JS","Web","PageKit","PageGlobals"]);

rtl.run('interest');
}
