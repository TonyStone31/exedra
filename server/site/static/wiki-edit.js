if (!pas.WikiEditPage) {
rtl.module("WikiEditPage",["System"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  $mod.$implcode = function () {
    $impl.Start = function () {
      var Form = null;
      var Summary = null;
      var Actions = null;
      var Fine = null;
      var Reload = null;
      var RowSummary = null;
      var RowActions = null;
      var Box = null;
      var Say = undefined;
      var T = null;
      var TWith = null;
      var Ed = null;
      var El = null;
      var ElClass = null;
      var ElText = null;
      var Replace = null;
      var ReplaceSelect = null;
      var ClosePop = null;
      var FileRef = null;
      var PathRef = null;
      function Pop(Button) {
        var Result = null;
        Result = Ed.pop(Button);
        return Result;
      };
      function FindPage(Button) {
        var Card = null;
        var List = null;
        var Find = null;
        var A = 0;
        var B = 0;
        var Timer = 0;
        var Asked = 0;
        var Words = "";
        function Put(Title) {
          var Text = "";
          ClosePop();
          if ((Words !== "") && (Words !== Title)) {
            Text = "[[" + Title + "|" + Words + "]]"}
           else Text = "[[" + Title + "]]";
          Replace(A,B,Text);
        };
        function Offer(Li, Pick, Title) {
          Pick.type = "button";
          Pick.addEventListener("click",function (E) {
            Put(Title);
          });
          Li.appendChild(Pick);
          List.appendChild(Li);
        };
        function Search() {
          var Q = "";
          var Mine = 0;
          Q = Find.value.trim();
          Asked += 1;
          Mine = Asked;
          List.replaceChildren();
          if (Q.length < 2) return;
          window.fetch("/api/wiki/search?q=" + encodeURIComponent(Q)).then(function (Answer) {
            var Result = undefined;
            if (Answer.ok) {
              Result = Answer.json()}
             else Result = new Array();
            return Result;
          }).then(function (Found) {
            var Result = undefined;
            var Pages = null;
            var I = 0;
            if (Mine !== Asked) return Result;
            if (Boolean(Found)) {
              Pages = Found}
             else Pages = new Array();
            Pages = Pages.slice(0,8);
            for (var $l = 0, $end = Pages.length - 1; $l <= $end; $l++) {
              I = $l;
              Offer(El("li"),ElText("button","",Pages[I]["title"]),"" + Pages[I]["title"]);
            };
            Offer(ElClass("li","wikitools-new"),ElText("button","",TWith('Link to "%s", a new page',Q)),Q);
            return Result;
          }).catch(function (Why) {
            var Result = undefined;
            return Result;
          });
        };
        Card = Pop(Button);
        A = Box.selectionStart;
        B = Box.selectionEnd;
        Words = Box.value.slice(A,B);
        Find = El("input");
        Find.type = "search";
        Find.placeholder = T("Find a page");
        Find.setAttribute("aria-label",T("Find a page"));
        List = ElClass("ul","wikitools-found");
        Card.append(Find,List);
        Find.focus();
        Timer = 0;
        Asked = 0;
        Find.addEventListener("input",function (E) {
          window.clearTimeout(Timer);
          Timer = window.setTimeout(rtl.createSafeCallback(null,Search),250);
        });
        Find.addEventListener("keydown",function (E) {
          var First = null;
          if (E.key !== "Enter") return;
          E.preventDefault();
          First = List.querySelector("button");
          if (First !== null) First.click();
        });
        if (Words !== "") {
          Find.value = Words;
          Search();
        };
      };
      function UsedNames() {
        var Result = null;
        var V = "";
        var Seen = null;
        var M = null;
        V = Box.value;
        Seen = new Set();
        FileRef.lastIndex = 0;
        M = FileRef.exec(V);
        while (M !== null) {
          Seen.add(("" + M[1]).trim().replace(new RegExp(" ","g"),"_"));
          M = FileRef.exec(V);
        };
        PathRef.lastIndex = 0;
        M = PathRef.exec(V);
        while (M !== null) {
          try {
            Seen.add(decodeURIComponent("" + M[1]));
          } catch ($e) {
            Seen.add(M[1]);
          };
          M = PathRef.exec(V);
        };
        Result = Array.from(Seen);
        return Result;
      };
      function PutImage(Name) {
        var A = 0;
        var B = 0;
        var After = 0;
        var V = "";
        var Text = "";
        var Lead = "";
        A = Box.selectionStart;
        B = Box.selectionEnd;
        V = Box.value;
        Text = "[[File:" + Name.replace(new RegExp("_","g")," ") + "]]";
        if ((A === 0) || (V.charAt(A - 1) === "\n")) {
          Lead = ""}
         else Lead = "\n\n";
        After = Lead.length + Text.length;
        ReplaceSelect(A,B,Lead + Text,After,After);
      };
      function Thumb(List, F) {
        var B = null;
        var Img = null;
        var Cap = null;
        B = ElClass("button","wikiimg");
        B.type = "button";
        B.title = TWith("Put %s in the page",F["name"]);
        Img = El("img");
        Img["loading"] = "lazy";
        Img.alt = "";
        Img["src"] = F["url"];
        Cap = ElText("span","",F["name"].replace(new RegExp("_","g")," "));
        B.append(Img,Cap);
        B.addEventListener("click",function (E) {
          ClosePop();
          PutImage("" + F["name"]);
        });
        List.appendChild(B);
      };
      function Thumbs(List, Files, Empty) {
        var I = 0;
        List.replaceChildren();
        if (!Boolean(Files["length"])) {
          List.appendChild(ElText("p","fine",Empty));
          return;
        };
        for (var $l = 0, $end = Files.length - 1; $l <= $end; $l++) {
          I = $l;
          Thumb(List,Files[I]);
        };
      };
      async function Files(Query) {
        var Result = undefined;
        var R = null;
        R = await window.fetch("/api/wiki/files?" + Query);
        if (!R.ok) throw new Error("" + R.status);
        Result = R.json();
        return Result;
      };
      function ImagePanel(Button) {
        var Card = null;
        var Head = null;
        var Pick = null;
        var OnPage = null;
        var PageList = null;
        var Lib = null;
        var LibHead = null;
        var LibList = null;
        var All = null;
        var Find = null;
        var Names = null;
        var Timer = 0;
        function Failed(List) {
          List.replaceChildren(ElText("p","fine",T("The list could not be loaded.")));
        };
        function Load(Q) {
          var Query = "";
          if (Q !== "") {
            LibHead.textContent = T("Found")}
           else LibHead.textContent = T("Newest in the wiki");
          Query = "limit=24";
          if (Q !== "") Query = Query + "&q=" + encodeURIComponent(Q);
          Files(Query).then(function (Found) {
            var Result = undefined;
            var Rows = null;
            if (Boolean(Found)) {
              Rows = Found}
             else Rows = new Array();
            if (Q !== "") {
              Thumbs(LibList,Rows,T("No image has that name."))}
             else Thumbs(LibList,Rows,T("No images yet."));
            return Result;
          }).catch(function (Why) {
            var Result = undefined;
            Failed(LibList);
            return Result;
          });
        };
        Card = Pop(Button);
        Card.classList.add("wikitools-images");
        Head = ElClass("div","wikiimg-head");
        Pick = ElText("button","wikiimg-upload",T("Upload images"));
        Pick.type = "button";
        Pick.addEventListener("click",function (E) {
          ClosePop();
          Ed.choose();
        });
        Find = El("input");
        Find.type = "search";
        Find.placeholder = T("Find an image");
        Find.setAttribute("aria-label",T("Find an image"));
        Head.append(Find,Pick);
        OnPage = El("section");
        OnPage.appendChild(ElText("h3","",T("On this page")));
        PageList = ElClass("div","wikiimg-list");
        OnPage.appendChild(PageList);
        Lib = El("section");
        LibHead = ElText("h3","",T("Newest in the wiki"));
        LibList = ElClass("div","wikiimg-list");
        Lib.append(LibHead,LibList);
        All = ElText("a","wikiimg-all",T("All images"));
        All.href = "/wiki-files";
        All.target = "_blank";
        Card.append(Head,OnPage,Lib,ElText("p","fine wikiimg-tip",T("You can also drag pictures onto the text, or paste a screenshot.")),All);
        Find.focus();
        Names = UsedNames();
        if (Names.length > 0) {
          PageList.appendChild(ElText("p","fine",T("Loading…")));
          Files("names=" + encodeURIComponent(Names.join("|"))).then(function (Found) {
            var Result = undefined;
            var Known = null;
            var Rows = null;
            var Shown = null;
            var I = 0;
            var F = undefined;
            if (Boolean(Found)) {
              Rows = Found}
             else Rows = new Array();
            Known = new Map();
            for (var $l = 0, $end = Rows.length - 1; $l <= $end; $l++) {
              I = $l;
              Known.set(Rows[I]["name"],Rows[I]);
            };
            Shown = new Array();
            for (var $l1 = 0, $end1 = Names.length - 1; $l1 <= $end1; $l1++) {
              I = $l1;
              F = Known.get(Names[I]);
              if (!Boolean(F)) F = pas.JS.New(["name",Names[I],"url",""]);
              Shown.push(F);
            };
            Thumbs(PageList,Shown,"");
            return Result;
          }).catch(function (Why) {
            var Result = undefined;
            Failed(PageList);
            return Result;
          });
        } else Thumbs(PageList,new Array(),T("This page has no pictures yet."));
        Timer = 0;
        Find.addEventListener("input",function (E) {
          window.clearTimeout(Timer);
          Timer = window.setTimeout(function () {
            Load(Find.value.trim());
          },250);
        });
        Load("");
      };
      async function Send(F, Name, Again) {
        var Result = undefined;
        var Body = null;
        var R = null;
        var Text = "";
        var Shown = "";
        var Answer = null;
        var Other = undefined;
        Body = new FormData();
        Body.append("file",F,Name);
        Body.append("name",Name);
        R = await window.fetch("/api/wiki/upload",pas.JS.New(["method","POST","body",Body]));
        Text = await R.text();
        try {
          Answer = JSON.parse(Text);
        } catch ($e) {
          Answer = pas.JS.New(["error",Text.trim().slice(0,200)]);
        };
        if ((R.status === 409) && Boolean(Answer["conflict"]) && !Object.is(Again,true)) {
          Other = Answer["suggested"];
          if (!Boolean(Other)) Other = Name;
          return Send(F,"" + Other,true);
        };
        if (!R.ok) {
          if (Boolean(Answer["error"])) throw new Error("" + Answer["error"]);
          if (R.status === 413) throw new Error(T("That picture is too big."));
          throw new Error(T("The picture could not be uploaded."));
        };
        Shown = Answer["name"].replace(new RegExp("_","g")," ");
        Result = pas.JS.New(["put","[[File:" + Shown + "]]","words",TWith("%s is uploaded.",Shown)]);
        return Result;
      };
      async function Preview(Text, Signal) {
        var Result = undefined;
        var R = null;
        R = await window.fetch("/api/wiki/preview",pas.JS.New(["method","POST","body",new URLSearchParams(pas.JS.New(["body",Text])),"signal",Signal]));
        if (!R.ok) throw new Error(await R.text());
        Result = (await R.json())["html"];
        return Result;
      };
      function LinkTools(Editor) {
        Editor.tool(T("Link to a wiki page"),"","[[ ]]",FindPage);
        Editor.tool(T("Image"),"",Editor.svg('<rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="9" cy="10" r="1.8"/><path d="M21 16l-5-5-9 9"/>'),ImagePanel).setAttribute("aria-haspopup","dialog");
      };
      async function Emoji() {
        var Result = undefined;
        var R = null;
        var List = undefined;
        R = await window.fetch("/api/wiki/emoji");
        if (R.ok) {
          List = await R.json()}
         else List = new Array();
        Result = window.EmojiNames.after(List);
        return Result;
      };
      Form = document.querySelector("form.wikiedit");
      if ((Form === null) || !Boolean(window["Editor"])) return;
      Box = Form.querySelector('textarea[name="body"]');
      if (Box === null) return;
      Say = window["t"];
      if (!Boolean(Say)) Say = function (English) {
        var Result = "";
        Result = English;
        return Result;
      };
      T = Say;
      TWith = Say;
      Summary = Form.querySelector('input[name="summary"]');
      Actions = Form.querySelector('button[type="submit"]:not([name])');
      Fine = Form.querySelector(":scope > p.fine");
      if (Fine !== null) Fine.hidden = true;
      RowSummary = null;
      if (Summary !== null) RowSummary = Summary.closest("label");
      RowActions = null;
      if ((Actions !== null) && (Actions.parentElement !== Form)) RowActions = Actions.parentElement;
      Ed = window.Editor.attach(Box,pas.JS.New(["storeKey","wiki-edit-mode","heads",".wikibody h1, .wikibody h2, .wikibody h3, .wikibody h4, .wikibody h5, .wikibody h6","hint",T("Markdown and [[wiki links]]. Drag, paste or"),"emptyWords",T("The page shows here as you write."),"helpLink",pas.JS.New(["href","/wiki-help","words",T("Everything you can write here")]),"sendRow",new Array(RowSummary,RowActions),"cheats",new Array(new Array("[[Page Name]]  [[Page Name|" + T("words") + "]]",T("a link to a wiki page")),new Array("[[File:Name.png]]",T("a picture; add |thumb|300px|caption for a small framed one")),new Array("Category:Name",T("on a line at the end: puts the page in a category")),new Array("#REDIRECT [[Other Page]]",T("as the first line: sends readers to another page"))),"preview",Preview,"linkTools",LinkTools,"pictures",pas.JS.New(["accept","image/png,image/jpeg,image/gif,image/webp","types",new RegExp("^image\\/(png|jpeg|gif|webp)$"),"send",Send]),"emoji",Emoji]));
      El = Ed["el"];
      ElClass = Ed["el"];
      ElText = Ed["el"];
      Replace = Ed["replace"];
      ReplaceSelect = Ed["replace"];
      ClosePop = Ed["closePop"];
      FileRef = new RegExp("\\[\\[\\s*:?\\s*(?:File|Image)\\s*:\\s*([^|\\]]+)","gi");
      PathRef = new RegExp("\\]\\(\\/wiki-images\\/[0-9a-f]\\/[0-9a-f]{2}\\/([^)\\s]+)\\)","g");
      Reload = Form.querySelector('button[name="preview"]');
      if (Reload !== null) Reload.hidden = true;
    };
  };
  $mod.$init = function () {
    $impl.Start();
  };
},["JS","Web","PageKit"]);

rtl.run('WikiEditPage');
}
