if (!pas.WikiPage) {
rtl.module("WikiPage",["System"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  $mod.$implcode = function () {
    $impl.SVG = "http://www.w3.org/2000/svg";
    $impl.ICON_COPY = "M9 9h10v10H9zM5 15V5h10";
    $impl.ICON_DONE = "M5 12l5 5L19 7";
    $impl.BOX_LINES = 20;
    $impl.KEEP = 8;
    $impl.LanguageForm = function (Form) {
      var Picker = null;
      Picker = Form.querySelector("select");
      Picker.addEventListener("change",function (E) {
        Form.requestSubmit();
      });
      Form.querySelector("button").hidden = true;
    };
    $impl.Times = function () {
      var Stamps = null;
      var Stamp = null;
      var When = null;
      var I = 0;
      Stamps = document.querySelectorAll("time[datetime]");
      for (var $l = 0, $end = Stamps.length - 1; $l <= $end; $l++) {
        I = $l;
        Stamp = Stamps.item(I);
        When = new Date(Stamp.dateTime);
        if (Number.isNaN(When.getTime()) || !Boolean(window["dateText"])) continue;
        Stamp.title = Stamp.textContent;
        if ((Stamp.dataset["show"] === "date") || (Stamp.dateTime.length === 10)) {
          if (Stamp.dateTime.length === 10) {
            Stamp.textContent = window.dateText(Stamp.dateTime)}
           else Stamp.textContent = window.dateText(When);
        } else Stamp.textContent = window.dateTimeText(When);
      };
    };
    $impl.ReadingAids = function () {
      var Body = null;
      var Page = null;
      var Side = null;
      var Tools = null;
      var Bar = null;
      var ToolsHead = null;
      var ToolsHome = null;
      var T = null;
      var TN = null;
      var Used = null;
      var Headings = null;
      var Opened = null;
      var Movable = null;
      var Items = null;
      var Hidden = null;
      var Part = null;
      var Homes = null;
      var Beside = null;
      var WideSide = null;
      var Found = null;
      var H = null;
      var Link = null;
      var Target = null;
      var Pre = null;
      var Wrap = null;
      var B = null;
      var More = null;
      var Mark = null;
      var Id = "";
      var Base = "";
      var I = 0;
      var N = 0;
      function Words(Heading) {
        var Result = "";
        var Copy = null;
        var Links = null;
        var K = 0;
        Copy = Heading.cloneNode(true);
        Links = Copy.querySelectorAll(".sectionedit");
        for (var $l = 0, $end = Links.length - 1; $l <= $end; $l++) {
          K = $l;
          Links.item(K).remove();
        };
        Result = Copy.textContent.trim();
        return Result;
      };
      function PlaceTools(E) {
        ToolsHead.hidden = !Beside.matches;
        if (Beside.matches) {
          ToolsHead.insertAdjacentElement("afterend",Tools)}
         else ToolsHome.parentNode.insertBefore(Tools,ToolsHome.nextSibling);
      };
      function PlaceBoxes(E) {
        var K = 0;
        var Home = null;
        for (var $l = 0, $end = Movable.length - 1; $l <= $end; $l++) {
          K = $l;
          if (WideSide.matches) {
            Side.appendChild(Movable[K])}
           else {
            Home = Homes.get(Movable[K]);
            Home.parentNode.insertBefore(Movable[K],Home.nextSibling);
          };
        };
      };
      function Redrawn(Records, Observer) {
        var R = 0;
        var K = 0;
        var Old = 0;
        var Node = null;
        for (var $l = 0, $end = rtl.length(Records) - 1; $l <= $end; $l++) {
          R = $l;
          for (var $l1 = 0, $end1 = Records[R].addedNodes.length - 1; $l1 <= $end1; $l1++) {
            K = $l1;
            Node = Records[R].addedNodes.item(K);
            if ((Node.nodeType === 1) && Node.hasAttribute("data-beside") && !Movable.includes(Node)) {
              Old = Movable.findIndex(function (Box, Index, List) {
                var Result = false;
                Result = (Box.className === Node.className) && !Boolean(Box["isConnected"]);
                return Result;
              });
              if (Old >= 0) {
                Homes.set(Node,Homes.get(Movable[Old]));
                Movable[Old] = Node;
              };
            };
          };
        };
      };
      function Contents() {
        var Toc = null;
        var Summary = null;
        var List = null;
        var Li = null;
        var Current = null;
        var Details = null;
        var A = null;
        var Wide = null;
        var Links = null;
        var Ticking = false;
        var K = 0;
        function Fit(E) {
          Details.open = Wide.matches;
        };
        function MarkNow(Time) {
          var Line = 0.0;
          var Index = 0;
          var J = 0;
          var AtEnd = false;
          var Next = null;
          Ticking = false;
          Line = window.innerHeight * 0.3;
          Index = -1;
          AtEnd = (window.innerHeight + window.scrollY) >= (document.documentElement.scrollHeight - 4);
          if (AtEnd) {
            Index = Headings.length - 1}
           else for (var $l = 0, $end = Headings.length - 1; $l <= $end; $l++) {
            J = $l;
            if (Headings[J].getBoundingClientRect().top <= Line) Index = J;
          };
          if (Index >= 0) {
            Next = Links[Index]}
           else Next = Links[0];
          if (!Boolean(Next)) Next = null;
          if (Next === Current) return;
          if (Current !== null) Current.classList.remove("now");
          Current = Next;
          if (Current !== null) {
            Current.classList.add("now");
            if (Boolean(Current["scrollIntoView"]) && Details.open && window.matchMedia("(min-width: 1320px)").matches) Current.scrollIntoView(pas.JS.New(["block","nearest"]));
          };
        };
        function OnScroll(E) {
          if (!Ticking) {
            Ticking = true;
            window.requestAnimationFrame(MarkNow);
          };
        };
        Toc = document.createElement("nav");
        Toc.className = "toc";
        Toc.setAttribute("aria-label",T("On this page"));
        Details = document.createElement("details");
        Summary = document.createElement("summary");
        Summary.textContent = T("On this page");
        Details.appendChild(Summary);
        List = document.createElement("ol");
        for (var $l = 0, $end = Headings.length - 1; $l <= $end; $l++) {
          K = $l;
          Li = document.createElement("li");
          if (Headings[K].tagName === "H3") {
            Li.className = "sub"}
           else Li.className = "";
          A = document.createElement("a");
          A.href = "#" + encodeURIComponent(Headings[K].id);
          A.textContent = Words(Headings[K]);
          Li.appendChild(A);
          List.appendChild(Li);
        };
        Details.appendChild(List);
        Toc.appendChild(Details);
        Side.insertBefore(Toc,Side.firstChild);
        Page.classList.add("has-toc");
        Wide = window.matchMedia("(min-width: 1320px)");
        Fit(null);
        Wide.addEventListener("change",Fit);
        Links = new Array();
        for (var $l1 = 0, $end1 = Headings.length - 1; $l1 <= $end1; $l1++) {
          K = $l1;
          Links.push(List.children.item(K).firstChild);
        };
        Current = null;
        Ticking = false;
        window.addEventListener("scroll",OnScroll,pas.JS.New(["passive",true]));
        window.addEventListener("resize",OnScroll);
        MarkNow(0);
      };
      function Icon(Button, Path) {
        var Picture = null;
        var Line = null;
        Picture = document.createElementNS($impl.SVG,"svg");
        Picture.setAttribute("viewBox","0 0 24 24");
        Picture.setAttribute("aria-hidden","true");
        Line = document.createElementNS($impl.SVG,"path");
        Line.setAttribute("d",Path);
        Line.setAttribute("fill","none");
        Line.setAttribute("stroke","currentColor");
        Line.setAttribute("stroke-width","2");
        Line.setAttribute("stroke-linejoin","round");
        Line.setAttribute("stroke-linecap","round");
        Picture.appendChild(Line);
        Button.replaceChildren(Picture);
      };
      function CopyButton(Button, Block) {
        Icon(Button,$impl.ICON_COPY);
        Button.title = T("Copy");
        Button.setAttribute("aria-label",T("Copy"));
        Button.addEventListener("click",function (E) {
          window.navigator.clipboard.writeText(Block.textContent).then(function (Value) {
            var Result = undefined;
            Icon(Button,$impl.ICON_DONE);
            Button.classList.add("ok");
            Button.title = T("Copied");
            window.setTimeout(function () {
              Icon(Button,$impl.ICON_COPY);
              Button.classList.remove("ok");
              Button.title = T("Copy");
            },1500);
            return Result;
          });
        });
      };
      function LongBlock(Block) {
        var Lines = 0;
        var Box = null;
        var Foot = null;
        var Whole = null;
        function Caption() {
          var Open = false;
          Open = Box.classList.contains("whole");
          if (Open) {
            Whole.textContent = T("Show less")}
           else Whole.textContent = TN(Lines,"Show all %d line","Show all %d lines");
          if (Open) {
            Whole.setAttribute("aria-expanded","true")}
           else Whole.setAttribute("aria-expanded","false");
        };
        Lines = rtl.length(Block.textContent.replace(new RegExp("\\n+$"),"").split("\n"));
        if (Lines <= (20 + 5)) return;
        Box = Block.closest(".code");
        if (Box === null) Box = Block.closest(".codebox");
        if (Box === null) Box = Block;
        Box.classList.add("scrollbox");
        Foot = document.createElement("div");
        Foot.className = "code-boxbar";
        Whole = document.createElement("button");
        Whole.type = "button";
        Whole.className = "code-whole";
        Whole.addEventListener("click",function (E) {
          var Open = false;
          Open = Box.classList.toggle("whole");
          Block.style["height"] = "";
          Caption();
          if (!Open && (Box.getBoundingClientRect().top < 0)) Box.scrollIntoView(pas.JS.New(["block","start"]));
        });
        Caption();
        Foot.append(Whole);
        if (Box === Block) {
          Box.insertAdjacentElement("afterend",Foot)}
         else Box.insertAdjacentElement("beforeend",Foot);
      };
      Body = document.querySelector(".wikipage > .wikibody");
      Page = document.querySelector(".wikipage");
      if ((Body === null) || (Page === null)) return;
      if (Boolean(window["t"])) {
        T = window["t"]}
       else T = function (English) {
        var Result = "";
        Result = English;
        return Result;
      };
      if (Boolean(window["tn"])) {
        TN = window["tn"]}
       else TN = function (Count, One, Many) {
        var Result = "";
        if (Count === 1) {
          Result = One}
         else Result = Many;
        Result = Result.replace("%d","" + Count);
        return Result;
      };
      Used = new Set();
      Headings = new Array();
      Found = Body.querySelectorAll("h2, h3");
      for (var $l = 0, $end = Found.length - 1; $l <= $end; $l++) {
        I = $l;
        if (Words(Found.item(I)) !== "") Headings.push(Found.item(I));
      };
      for (var $l1 = 0, $end1 = Headings.length - 1; $l1 <= $end1; $l1++) {
        I = $l1;
        H = Headings[I];
        if (H.id !== "") {
          Used.add(H.id);
          continue;
        };
        Id = Words(H).replace(new RegExp("\\s+","g"),"_").replace(new RegExp('[\\[\\]{}|#<>"\']',"g"),"");
        N = 2;
        Base = Id;
        while (Used.has(Id) || (document.getElementById(Id) !== null)) {
          Id = Base + "_" + ("" + N);
          N += 1;
        };
        H.id = Id;
        Used.add(Id);
      };
      if (window.location.hash !== "") {
        Part = (new RegExp("^#section-(\\d+)$")).exec(window.location.hash);
        Link = null;
        if (Part !== null) Link = Body.querySelector('.sectionedit[href$="section=' + ("" + Part[1]) + '"]');
        if (Link !== null) {
          Target = Link.parentElement}
         else Target = document.getElementById(decodeURIComponent(window.location.hash.slice(1)));
        if (Target !== null) Target.scrollIntoView();
      };
      Opened = new Array();
      window.addEventListener("beforeprint",function (E) {
        var Folded = null;
        var K = 0;
        Folded = Body.querySelectorAll("details:not([open])");
        for (var $l2 = 0, $end2 = Folded.length - 1; $l2 <= $end2; $l2++) {
          K = $l2;
          Folded.item(K).open = true;
          Opened.push(Folded.item(K));
        };
      });
      window.addEventListener("afterprint",function (E) {
        while (Opened.length > 0) Opened.pop().open = false;
      });
      Found = Page.querySelectorAll("[data-print]");
      for (var $l2 = 0, $end2 = Found.length - 1; $l2 <= $end2; $l2++) {
        I = $l2;
        Found.item(I).hidden = false;
        Found.item(I).addEventListener("click",function (E) {
          window.print();
        });
      };
      Side = document.createElement("aside");
      Side.className = "wiki-side";
      Tools = Page.querySelector(":scope > .pagetools");
      if (Tools !== null) {
        Tools.insertAdjacentElement("afterend",Side)}
       else Body.insertAdjacentElement("beforebegin",Side);
      Page.classList.add("has-side");
      ToolsHead = document.querySelector(".siteside [data-page-tools]");
      if ((Tools !== null) && (ToolsHead !== null)) {
        ToolsHome = document.createComment("tools");
        Tools.parentNode.insertBefore(ToolsHome,Tools);
        Beside = window.matchMedia("(min-width: 901px)");
        PlaceTools(null);
        Beside.addEventListener("change",PlaceTools);
      };
      Movable = Array.from(Page.querySelectorAll(":scope > .page-bench, :scope > [data-beside]"));
      Homes = new Map();
      for (var $l3 = 0, $end3 = Movable.length - 1; $l3 <= $end3; $l3++) {
        I = $l3;
        Mark = document.createComment("home");
        Movable[I].parentNode.insertBefore(Mark,Movable[I]);
        Homes.set(Movable[I],Mark);
      };
      WideSide = window.matchMedia("(min-width: 1320px)");
      PlaceBoxes(null);
      WideSide.addEventListener("change",PlaceBoxes);
      (new MutationObserver(rtl.createSafeCallback(null,Redrawn))).observe(Page,pas.JS.New(["childList",true,"subtree",true]));
      if ((Headings.length >= 3) && (document.querySelector(".no-contents") === null)) Contents();
      if (Boolean(window.navigator["clipboard"])) {
        Found = Body.querySelectorAll(".code .codebar .copy");
        for (var $l4 = 0, $end4 = Found.length - 1; $l4 <= $end4; $l4++) {
          I = $l4;
          CopyButton(Found.item(I),Found.item(I).closest(".code").querySelector("pre"));
        };
        Found = Body.querySelectorAll("pre");
        for (var $l5 = 0, $end5 = Found.length - 1; $l5 <= $end5; $l5++) {
          I = $l5;
          Pre = Found.item(I);
          if (Pre.closest(".code") !== null) continue;
          Wrap = document.createElement("div");
          Wrap.className = "codebox";
          Pre.parentNode.insertBefore(Wrap,Pre);
          Wrap.appendChild(Pre);
          B = document.createElement("button");
          B.type = "button";
          B.className = "copybtn";
          CopyButton(B,Pre);
          Wrap.appendChild(B);
        };
      } else {
        Found = Body.querySelectorAll(".code .codebar .copy");
        for (var $l6 = 0, $end6 = Found.length - 1; $l6 <= $end6; $l6++) {
          I = $l6;
          Found.item(I).hidden = true;
        };
      };
      Found = Body.querySelectorAll("pre");
      for (var $l7 = 0, $end7 = Found.length - 1; $l7 <= $end7; $l7++) {
        I = $l7;
        LongBlock(Found.item(I));
      };
      Bar = Page.querySelector(".languages");
      if (Bar !== null) {
        Items = Array.from(Bar.childNodes);
        for (var $l8 = 0, $end8 = Items.length - 1; $l8 <= $end8; $l8++) {
          I = $l8;
          if (Items[I].nodeType === 3) Items[I].remove();
        };
        Items = Array.from(Bar.querySelectorAll("a, b"));
        if (Items.length > (8 + 2)) {
          Hidden = new Array();
          for (var $l9 = 8, $end9 = Items.length - 1; $l9 <= $end9; $l9++) {
            I = $l9;
            if (Items[I].tagName !== "B") Hidden.push(Items[I]);
          };
          for (var $l10 = 0, $end10 = Hidden.length - 1; $l10 <= $end10; $l10++) {
            I = $l10;
            Hidden[I].hidden = true;
          };
          More = document.createElement("button");
          More.type = "button";
          More.className = "more-languages";
          More.textContent = TN(Hidden.length,"+%d more language","+%d more languages");
          More.addEventListener("click",function (E) {
            var K = 0;
            for (var $l11 = 0, $end11 = Hidden.length - 1; $l11 <= $end11; $l11++) {
              K = $l11;
              Hidden[K].hidden = false;
            };
            More.remove();
          });
          Bar.appendChild(More);
        };
      };
    };
    $impl.CopyEmoji = function (E) {
      var Pick = null;
      var Data = null;
      var Part = null;
      var Pictures = null;
      var Holder = null;
      var I = 0;
      function TextOf() {
        var Result = "";
        Holder.style.cssText = "position:fixed;left:-9999px;top:0;white-space:pre-wrap";
        document.body.appendChild(Holder);
        Result = Holder.innerText;
        Holder.remove();
        return Result;
      };
      Pick = window.getSelection();
      Data = E.clipboardData;
      if (!Boolean(Pick) || Pick.isCollapsed || !Boolean(Data)) return;
      Part = Pick.getRangeAt(0).cloneContents();
      Pictures = Part.querySelectorAll("img.emo");
      if (Pictures.length === 0) return;
      for (var $l = 0, $end = Pictures.length - 1; $l <= $end; $l++) {
        I = $l;
        Pictures.item(I).replaceWith(document.createTextNode(Pictures.item(I).alt));
      };
      Holder = document.createElement("div");
      Holder.appendChild(Part);
      if (Pick.toString().length > 0) {
        Data.setData("text/plain",TextOf())}
       else Data.setData("text/plain","");
      Data.setData("text/html",Holder.innerHTML);
      E.preventDefault();
    };
    $impl.Start = function () {
      var Forms = null;
      var I = 0;
      Forms = document.querySelectorAll(".wiki-language");
      for (var $l = 0, $end = Forms.length - 1; $l <= $end; $l++) {
        I = $l;
        $impl.LanguageForm(Forms.item(I));
      };
      $impl.Times();
      $impl.ReadingAids();
      document.addEventListener("copy",$impl.CopyEmoji);
    };
  };
  $mod.$init = function () {
    $impl.Start();
  };
},["JS","weborworker","Web","PageKit"]);

rtl.run('WikiPage');
}
