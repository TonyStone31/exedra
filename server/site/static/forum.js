if (!pas.ForumPage) {
rtl.module("ForumPage",["System"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  $mod.$implcode = function () {
    $impl.TextOr = function (Value, Fallback) {
      var Result = "";
      if (Boolean(Value)) {
        Result = "" + Value}
       else Result = Fallback;
      return Result;
    };
    $impl.Post = async function (Path, Fields) {
      var Result = undefined;
      var Response = null;
      Response = await pas.PageKit.Post(Path,Fields,null);
      if (!Response.ok) throw new Error($impl.TextOr(await Response.text(),window.t("Could not save the forum.")));
      Result = await Response.json();
      return Result;
    };
    $impl.TopicAddress = function (Id, Page, PostId) {
      var Result = "";
      Result = "/forum/t/" + ("" + Number(Id));
      if (Number(Page) > 1) Result = Result + "?page=" + ("" + Number(Page));
      if (Boolean(PostId)) Result = Result + "#post-" + ("" + Number(PostId));
      return Result;
    };
    $impl.CodeBlock = function (Block) {
      var Copy = null;
      var Flip = null;
      async function CopyCode(E) {
        try {
          await window.navigator.clipboard.writeText(Block.querySelector("pre code").textContent);
          Copy.textContent = window.t("Copied");
        } catch ($e) {
          window.alert(window.t("Could not copy the code."));
        };
      };
      Copy = Block.querySelector(".copy");
      if (Copy !== null) {
        Copy.dataset["forumCode"] = "1";
        Copy.textContent = window.t("Copy");
        Copy.addEventListener("click",CopyCode);
      };
      Flip = Block.querySelector(".flip");
      if (Flip !== null) {
        Flip.dataset["forumCode"] = "1";
        Flip.textContent = window.t("Source");
        Flip.addEventListener("click",function (E) {
          if (Block.classList.toggle("source")) {
            Flip.textContent = window.t("Document")}
           else Flip.textContent = window.t("Source");
        });
      };
    };
    $impl.CodeButtons = function (Box) {
      var Blocks = null;
      var I = 0;
      Blocks = Box.querySelectorAll(".code");
      for (var $l = 0, $end = Blocks.length - 1; $l <= $end; $l++) {
        I = $l;
        $impl.CodeBlock(Blocks.item(I));
      };
    };
    $impl.FileRules = function (Textarea) {
      var Result = null;
      var Kinds = null;
      var Most = 0.0;
      var Gallery = "";
      function Refuses(AFile) {
        var Result = "";
        var Found = null;
        var Kind = "";
        Found = (new RegExp("\\.([A-Za-z0-9]+)$")).exec($impl.TextOr(AFile["name"],""));
        if (Found !== null) {
          Kind = Found["1"].toLowerCase()}
         else Kind = "";
        if ((Kind === "") && (new RegExp("^image\\/(png|jpeg|gif|webp)$")).test("" + AFile["type"])) return "";
        if (Kinds.indexOf(Kind) < 0) return window.t("%s is not a kind of file accepted here.",$impl.TextOr(AFile["name"],""));
        if (Number(AFile["size"]) > (Most * 1024 * 1024)) return window.t("%s is too big: files can be %d MB at most here.",$impl.TextOr(AFile["name"],""),Most);
        Result = "";
        return Result;
      };
      async function Send(AFile, Name) {
        var Result = undefined;
        var Body = null;
        var Response = null;
        var Answer = null;
        var Words = "";
        var Address = "";
        var Mark = "";
        Body = new FormData();
        Body.append("file",AFile,Name);
        Response = await pas.PageKit.Post("/api/forum/upload",Body,null);
        if (!Response.ok) throw new Error($impl.TextOr((await Response.text()).trim().slice(0,200),window.t("The file could not be uploaded.")));
        Answer = await Response.json();
        Words = Answer["name"].replace(new RegExp("[\\[\\]]","g"),"");
        Address = Answer["url"].replace(new RegExp(" ","g"),"%20").replace(new RegExp("\\(","g"),"%28").replace(new RegExp("\\)","g"),"%29");
        if (Boolean(Answer["image"])) {
          Mark = "!"}
         else Mark = "";
        Result = pas.JS.New(["put",Mark + "[" + Words + "](" + Address + ")","words",window.t("%s is uploaded.",Answer["name"])]);
        return Result;
      };
      Kinds = $impl.TextOr(Textarea.dataset["uploadTypes"],"").split(" ").filter(Boolean);
      Most = Number($impl.TextOr(Textarea.dataset["uploadMb"],"0"));
      if ((Kinds.length === 0) || !Boolean(Most)) return null;
      Gallery = "image/*";
      if (Kinds.some(function (K, I, A) {
        var Result = false;
        Result = (new RegExp("^(mp4|webm|mov|m4v)$")).test("" + K);
        return Result;
      })) Gallery = Gallery + ",video/*";
      Result = pas.JS.New(["accept",Kinds.map(function (K, I, A) {
        var Result = undefined;
        Result = "." + ("" + K);
        return Result;
      }).join(","),"gallery",Gallery,"label",window.t("add files"),"refuses",Refuses,"send",Send]);
      return Result;
    };
    $impl.FileTool = function (Made) {
      Made.tool(window.t("Add a file"),"",Made.svg('<path d="M20 11.5l-8.2 8.2a5 5 0 0 1-7-7l8.5-8.6a3.4 3.4 0 0 1 4.8 4.8l-8.4 8.5a1.7 1.7 0 0 1-2.4-2.4l7.7-7.8"/>'),Made.choose);
    };
    $impl.AttachEditor = function (Textarea) {
      var Form = null;
      var Files = null;
      var Hint = undefined;
      var LinkTools = undefined;
      async function Preview(Text, Signal) {
        var Result = undefined;
        var Fields = null;
        var Response = null;
        Fields = new URLSearchParams(new FormData(Form));
        Fields.set("body",Text);
        Response = await window.fetch("/api/forum/preview",pas.JS.New(["method","POST","body",Fields,"credentials","same-origin","signal",Signal]));
        if (!Response.ok) throw new Error(await Response.text());
        Result = (await Response.json())["html"];
        return Result;
      };
      function Emoji() {
        var Result = undefined;
        Result = window.EmojiNames.list();
        return Result;
      };
      if (!Boolean(window["Editor"])) return;
      Form = Textarea.closest("form");
      Files = $impl.FileRules(Textarea);
      Hint = undefined;
      LinkTools = undefined;
      if (Files !== null) {
        Hint = window.t("Markdown. Drag, paste or");
        LinkTools = $impl.FileTool;
      };
      window.Editor.attach(Textarea,pas.JS.New(["compact",true,"mode","write","storeKey","forum-edit-mode","viewClass","forum-body body","emptyWords",window.t("The post shows here as you write."),"preview",Preview,"afterPreview",$impl.CodeButtons,"emoji",Emoji,"sendRow",Array.of(Form.querySelector(":scope > button"),Form.querySelector(":scope > .forum-error")),"hint",Hint,"linkTools",LinkTools,"pictures",Files]));
    };
    $impl.ForumForm = function (Form) {
      async function Submit(Event) {
        var Path = "";
        var Target = "";
        var Fields = null;
        var error = null;
        var Buttons = null;
        var Boxes = null;
        var Data = null;
        var Page = undefined;
        var Made = null;
        var Same = false;
        var Thanks = null;
        var I = 0;
        Event.preventDefault();
        if (Boolean(Form.dataset["busy"])) return;
        Path = window.SiteBase.strip(Form.getAttribute("action"));
        if (Boolean(Form.dataset["confirm"]) && !window.confirm(Form.dataset["confirm"])) return;
        Fields = new URLSearchParams(new FormData(Form));
        error = Form.querySelector(".forum-error");
        Buttons = Form.querySelectorAll("button");
        error.textContent = "";
        Form.dataset["busy"] = "1";
        for (var $l = 0, $end = Buttons.length - 1; $l <= $end; $l++) {
          I = $l;
          Buttons.item(I).disabled = true;
        };
        try {
          try {
            Data = await $impl.Post(Path,Fields);
            if (Boolean(Data["topic_id"])) {
              if (Boolean(Data["page"])) {
                Page = Data["page"]}
               else Page = 1;
              Target = window.SiteBase.url($impl.TopicAddress(Data["topic_id"],Page,Data["post_id"]));
              Same = Target.split("#")[0] === (window.location.pathname + window.location.search);
              window.location.assign(Target);
              if (Same) window.location.reload();
            } else if (Boolean(Data["topic_deleted"])) {
              window.location.assign(window.SiteBase.url("/forum"))}
             else if (Boolean(Data["reported"])) {
              Thanks = document.createElement("p");
              Thanks.textContent = window.t("Reported. The moderators will take a look.");
              Form.replaceWith(Thanks);
            } else window.location.reload();
          } catch ($e) {
            error["textContent"] = $e["message"];
            Boxes = Form.querySelectorAll("textarea");
            for (var $l1 = 0, $end1 = Boxes.length - 1; $l1 <= $end1; $l1++) {
              I = $l1;
              Made = Boxes.item(I)["editor"];
              if (Boolean(Made) && Boolean(Made["notSaved"])) Made["notSaved"].call(Made);
            };
          };
        } finally {
          pas.JS.JSDelete(Form.dataset,"busy");
          for (var $l2 = 0, $end2 = Buttons.length - 1; $l2 <= $end2; $l2++) {
            I = $l2;
            Buttons.item(I).disabled = false;
          };
        };
      };
      Form.addEventListener("submit",Submit);
    };
    $impl.QuoteLines = function (Text) {
      var Result = "";
      Result = Text.split("\n").map(function (Line, I, A) {
        var Result = undefined;
        Result = "> " + ("" + Line);
        return Result;
      }).join("\n");
      return Result;
    };
    $impl.QuoteMarkdown = function (Author, Topic, PostId, Body) {
      var Result = "";
      var Name = "";
      var Number_ = "";
      Name = Author.replace(new RegExp("([\\\\`*_[\\]<>])","g"),"\\$1");
      Number_ = "" + Number(PostId);
      Result = "> **" + Name + "** " + window.t("wrote") + " ([" + window.t("post") + "](/forum/t/" + ("" + Number(Topic)) + "?post=" + Number_ + "#post-" + Number_ + ")):\n" + $impl.QuoteLines(Body.replace(new RegExp("\\r\\n?","g"),"\n")) + "\n\n";
      return Result;
    };
    $impl.AddQuote = function (Author, Topic, PostId, Text) {
      var Reply = null;
      var Textarea = null;
      var Gap = "";
      Reply = document.querySelector("#quick-reply");
      if (Reply === null) return;
      Textarea = Reply.querySelector(".forum-editor");
      if (Textarea.value !== "") {
        Gap = "\n\n"}
       else Gap = "";
      Textarea.value = Textarea.value + Gap + $impl.QuoteMarkdown(Author,Topic,PostId,Text);
      Textarea.dispatchEvent(new Event("input",pas.JS.New(["bubbles",true])));
      Textarea.focus();
      Reply.scrollIntoView(pas.JS.New(["block","start"]));
    };
    $impl.QuoteButton = function (Button) {
      Button.addEventListener("click",function (E) {
        var Said = null;
        Said = Button.dataset;
        $impl.AddQuote(Said["author"],Said["topic"],Said["post"],Said["body"]);
      });
    };
    $impl.MarkdownOf = function (Node, InCode) {
      var Result = "";
      var El = null;
      var Lang = null;
      var Pre = null;
      var Tag = "";
      var Mark = "";
      var Cells = null;
      var I = 0;
      function Kids(Code) {
        var Result = "";
        var K = 0;
        Result = "";
        for (var $l = 0, $end = Node.childNodes.length - 1; $l <= $end; $l++) {
          K = $l;
          Result = Result + $impl.MarkdownOf(Node.childNodes.item(K),Code);
        };
        return Result;
      };
      function Fence(Language, Text) {
        var Result = "";
        Result = "\n\n```" + Language + "\n" + Text.replace(new RegExp("\\n+$"),"") + "\n```\n\n";
        return Result;
      };
      if (Node.nodeType === 3) {
        if (InCode) return Node.nodeValue;
        return Node.nodeValue.replace(new RegExp("\\s+","g")," ");
      };
      if ((Node.nodeType !== 1) && (Node.nodeType !== 11)) return "";
      if (Node.nodeType === 11) return Kids(InCode);
      El = Node;
      Tag = El.tagName;
      if (El.classList.contains("code")) {
        Lang = El.querySelector(".codebar span");
        Pre = El.querySelector("pre");
        if (Pre === null) return "";
        if (Lang !== null) return Fence(Lang.textContent.trim(),Pre.textContent);
        return Fence("",Pre.textContent);
      };
      if (El.classList.contains("codebar") || (Tag === "BUTTON")) return "";
      if (Tag === "PRE") return Fence("",El.textContent);
      if (Tag === "IMG") return "![" + $impl.TextOr(El.getAttribute("alt"),"") + "](" + window.SiteBase.strip($impl.TextOr(El.getAttribute("src"),"")) + ")";
      if (Tag === "A") return "[" + Kids(false) + "](" + window.SiteBase.strip($impl.TextOr(El.getAttribute("href"),"")) + ")";
      if ((Tag === "B") || (Tag === "STRONG")) return "**" + Kids(false) + "**";
      if ((Tag === "I") || (Tag === "EM")) return "*" + Kids(false) + "*";
      if ((Tag === "DEL") || (Tag === "S")) return "~~" + Kids(false) + "~~";
      if (Tag === "CODE") return "`" + El.textContent + "`";
      if (Tag === "BR") return "\n";
      if ((new RegExp("^H[1-6]$")).test(Tag)) return "\n\n" + "#".repeat(Number(Tag.charAt(1))) + " " + Kids(false) + "\n\n";
      if (Tag === "LI") {
        if ((El.parentElement !== null) && (El.parentElement.tagName === "OL")) {
          Mark = "1. "}
         else Mark = "- ";
        return Mark + Kids(false).trim() + "\n";
      };
      if ((Tag === "UL") || (Tag === "OL")) return "\n\n" + Kids(false) + "\n";
      if (Tag === "BLOCKQUOTE") return "\n\n" + $impl.QuoteLines(Kids(false).trim()) + "\n\n";
      if (Tag === "TR") {
        Cells = new Array();
        for (var $l = 0, $end = El.children.length - 1; $l <= $end; $l++) {
          I = $l;
          Cells.push($impl.MarkdownOf(El.children.item(I),false).trim());
        };
        return "| " + Cells.join(" | ") + " |\n";
      };
      if (Tag === "THEAD") return Kids(false) + "|" + "---|".repeat(El.querySelectorAll("th").length) + "\n";
      if (Tag === "TABLE") return "\n\n" + Kids(false) + "\n";
      if ((Tag === "P") || (Tag === "DIV")) return "\n\n" + Kids(false) + "\n\n";
      Result = Kids(InCode);
      return Result;
    };
    $impl.SelectionMarkdown = function (Range) {
      var Result = "";
      var From = null;
      var At = null;
      var Block = null;
      var Lang = null;
      var Text = "";
      var Line = "";
      var Code = false;
      var Lines = null;
      var I = 0;
      From = Range.commonAncestorContainer;
      if (From.nodeType === 1) {
        At = From}
       else At = From.parentElement;
      if (At !== null) {
        Block = At.closest(".code")}
       else Block = null;
      if ((Block !== null) && (At.closest("pre") !== null)) {
        Lang = Block.querySelector(".codebar span");
        Text = Range.toString().replace(new RegExp("\\n+$"),"");
        if (Text.trim() === "") return "";
        if (Lang !== null) return "```" + Lang.textContent.trim() + "\n" + Text + "\n```";
        return "```\n" + Text + "\n```";
      };
      Code = false;
      Lines = $impl.MarkdownOf(Range.cloneContents(),false).split("\n");
      for (var $l = 0, $end = Lines.length - 1; $l <= $end; $l++) {
        I = $l;
        Line = "" + Lines[I];
        if ((new RegExp("^\\s*```")).test(Line)) {
          Code = !Code;
          Lines[I] = Line.trim();
        } else if (!Code) Lines[I] = Line.replace(new RegExp("\\s+$"),"").replace(new RegExp("^ (?=\\S)"),"");
      };
      Result = Lines.join("\n").replace(new RegExp("\\n{3,}","g"),"\n\n").trim();
      return Result;
    };
    $impl.QuoteSelection = function () {
      var Offer = null;
      var Picked = null;
      var Later = 0;
      function BodyOf(Node) {
        var Result = null;
        var At = null;
        var Body = null;
        Result = null;
        if (!Boolean(Node)) return Result;
        if (Node.nodeType === 1) {
          At = Node}
         else At = Node.parentElement;
        if (At !== null) {
          Body = At.closest(".forum-body")}
         else Body = null;
        if ((Body !== null) && (Body.parentElement !== null) && Body.parentElement.classList.contains("forum-post-content")) Result = Body;
        return Result;
      };
      function Look() {
        var Chosen = null;
        var Body = null;
        var Text = "";
        var Button = null;
        var Box = null;
        Offer.hidden = true;
        Picked = null;
        Chosen = window.getSelection();
        if ((Chosen === null) || Chosen.isCollapsed || (Chosen.rangeCount === 0)) return;
        Body = BodyOf(Chosen.anchorNode);
        if (Body !== null) {
          Text = $impl.SelectionMarkdown(Chosen.getRangeAt(0))}
         else Text = "";
        if ((Text === "") || (Body === null) || (Body !== BodyOf(Chosen.focusNode))) return;
        Button = Body.closest(".forum-post").querySelector(".forum-quote");
        if (Button === null) return;
        Picked = pas.JS.New(["author",Button.dataset["author"],"topic",Button.dataset["topic"],"post",Button.dataset["post"],"text",Text]);
        Box = Chosen.getRangeAt(0).getBoundingClientRect();
        Offer.hidden = false;
        Offer.style.setProperty("top","" + (window.scrollY + Box.bottom + 6) + "px");
        Offer.style.setProperty("left","" + (window.scrollX + Math.max(8,Math.min(Box.left,document.documentElement.clientWidth - Offer.offsetWidth - 8))) + "px");
      };
      function Soon(E) {
        window.clearTimeout(Later);
        Later = window.setTimeout(rtl.createSafeCallback(null,Look),150);
      };
      if (!Boolean(document.querySelector("#quick-reply")) || !Boolean(document.body) || (typeof(window["getSelection"]) !== "function")) return;
      Offer = document.createElement("button");
      Offer.type = "button";
      Offer.className = "forum-quote-selection";
      Offer.textContent = window.t("Quote selection");
      Offer.hidden = true;
      document.body.appendChild(Offer);
      Picked = null;
      Later = 0;
      document.addEventListener("mouseup",Soon);
      document.addEventListener("keyup",Soon);
      document.addEventListener("selectionchange",Soon);
      Offer.addEventListener("mousedown",function (E) {
        E.preventDefault();
      });
      Offer.addEventListener("click",function (E) {
        if (Picked === null) return;
        $impl.AddQuote(Picked["author"],Picked["topic"],Picked["post"],Picked["text"]);
        window.getSelection().removeAllRanges();
        Offer.hidden = true;
      });
    };
    $impl.PostReactions = function () {
      var Offered = null;
      var Lists = null;
      var Rows = null;
      var I = 0;
      function Words(Text) {
        var Result = null;
        Result = Text.split(" ").filter(Boolean);
        return Result;
      };
      function Draw(Row, List) {
        var Id = undefined;
        var Add = false;
        var Here = false;
        var Fresh = null;
        var More = null;
        async function React(Emoji) {
          try {
            Draw(Fresh,(await $impl.Post("/api/forum/react",new URLSearchParams(pas.JS.New(["post",Id,"r",Emoji]))))["reactions"]);
          } catch ($e) {
            window.alert("" + $e["message"]);
          };
        };
        function Toggle(R) {
          if (Add || ((Lists !== null) && Boolean(R["mine"]))) React(R["r"]);
        };
        async function Who(R) {
          var Result = undefined;
          var Response = null;
          Response = await pas.PageKit.Get("/api/forum/reacted?post=" + ("" + Id) + "&r=" + encodeURIComponent("" + R["r"]),null);
          if (!Response.ok) throw new Error(await Response.text());
          Result = await Response.json();
          return Result;
        };
        Id = Row.dataset["post"];
        Add = (Lists !== null) && pas.JS.jsIn("add",Row.dataset);
        Fresh = window.Reactions.chips(List,pas.JS.New(["toggle",Toggle,"who",Who]));
        Object.assign(Fresh.dataset,Row.dataset);
        if (Add && ((Lists["shown"].length + Lists["more"].length) > 0)) {
          More = window.Side.iconButton("react",window.t("Add a reaction"),"forum-react-add");
          More.addEventListener("click",function (E) {
            window.Reactions.choose(More,Lists,React);
          });
          Fresh.appendChild(More);
        };
        Here = Row.contains(document.activeElement);
        Row.replaceWith(Fresh);
        if (Here && (Fresh.lastElementChild !== null)) Fresh.lastElementChild.focus(pas.JS.New(["preventScroll",true]));
      };
      function Drawn(Row) {
        var Result = null;
        Result = Array.from(Row.children).map(function (Chip, N, A) {
          var Result = undefined;
          Result = pas.JS.New(["r",Chip.dataset["r"],"n",Number(Chip.dataset["n"]),"mine",Chip.classList.contains("mine")]);
          return Result;
        });
        return Result;
      };
      Offered = document.getElementById("forum-reactions");
      if (Offered !== null) {
        Lists = pas.JS.New(["shown",Words(Offered.dataset["shown"]),"more",Words(Offered.dataset["more"])])}
       else Lists = null;
      Rows = document.querySelectorAll(".forum-post .reacts");
      for (var $l = 0, $end = Rows.length - 1; $l <= $end; $l++) {
        I = $l;
        Draw(Rows.item(I),Drawn(Rows.item(I)));
      };
    };
    $impl.NewTopicLink = function (Anchor) {
      Anchor.addEventListener("click",function (E) {
        document.querySelector("#new-topic")["open"] = true;
      });
    };
    $impl.PanelButton = function (Button) {
      Button.addEventListener("click",function (E) {
        var Panel = null;
        var Field = null;
        var Opening = false;
        var Content = null;
        var Others = null;
        var I = 0;
        Panel = document.getElementById(Button.dataset["forumPanel"]);
        Opening = Panel.hidden;
        Content = Button.closest(".forum-post-content");
        Others = Content.querySelectorAll(".forum-action-panel");
        for (var $l = 0, $end = Others.length - 1; $l <= $end; $l++) {
          I = $l;
          Others.item(I).hidden = true;
        };
        Others = Content.querySelectorAll("[data-forum-panel]");
        for (var $l1 = 0, $end1 = Others.length - 1; $l1 <= $end1; $l1++) {
          I = $l1;
          Others.item(I).setAttribute("aria-expanded","false");
        };
        Panel.hidden = !Opening;
        Button.setAttribute("aria-expanded","" + Opening);
        if (Opening) {
          Field = Panel.querySelector("textarea, input:not([type=hidden]), button");
          if (Field !== null) Field.focus();
        };
      });
    };
    $impl.SolveBox = function (Box) {
      async function Changed(E) {
        var Response = null;
        var Mark = "";
        Box.disabled = true;
        try {
          if (Box.checked) {
            Mark = "1"}
           else Mark = "0";
          Response = await pas.PageKit.Post("/api/forum/solved",new URLSearchParams(pas.JS.New(["post",Box.dataset["forumSolve"],"on",Mark])),null);
          if (!Response.ok) throw new Error((await Response.text()).trim().slice(0,200));
          window.location.reload();
        } catch ($e) {
          Box.checked = !Box.checked;
          Box.disabled = false;
          window.alert("" + $e["message"]);
        };
      };
      Box.addEventListener("change",Changed);
    };
    $impl.Start = function () {
      var Nodes = null;
      var I = 0;
      Nodes = document.querySelectorAll("form[data-forum-form]");
      for (var $l = 0, $end = Nodes.length - 1; $l <= $end; $l++) {
        I = $l;
        $impl.ForumForm(Nodes.item(I));
      };
      Nodes = document.querySelectorAll(".forum-quote");
      for (var $l1 = 0, $end1 = Nodes.length - 1; $l1 <= $end1; $l1++) {
        I = $l1;
        $impl.QuoteButton(Nodes.item(I));
      };
      $impl.QuoteSelection();
      $impl.PostReactions();
      Nodes = document.querySelectorAll("[data-forum-new]");
      for (var $l2 = 0, $end2 = Nodes.length - 1; $l2 <= $end2; $l2++) {
        I = $l2;
        $impl.NewTopicLink(Nodes.item(I));
      };
      Nodes = document.querySelectorAll("[data-forum-panel]");
      for (var $l3 = 0, $end3 = Nodes.length - 1; $l3 <= $end3; $l3++) {
        I = $l3;
        $impl.PanelButton(Nodes.item(I));
      };
      window.addEventListener("pageshow",function (E) {
        if (Boolean(E["persisted"]) && (document.querySelector(".forum-topics, .forum-boards") !== null)) window.location.reload();
      });
      Nodes = document.querySelectorAll("input[data-forum-solve]");
      for (var $l4 = 0, $end4 = Nodes.length - 1; $l4 <= $end4; $l4++) {
        I = $l4;
        $impl.SolveBox(Nodes.item(I));
      };
      Nodes = document.querySelectorAll(".forum-editor");
      for (var $l5 = 0, $end5 = Nodes.length - 1; $l5 <= $end5; $l5++) {
        I = $l5;
        $impl.AttachEditor(Nodes.item(I));
      };
      $impl.CodeButtons(document);
      Nodes = document.querySelectorAll("[data-forum-tools]");
      for (var $l6 = 0, $end6 = Nodes.length - 1; $l6 <= $end6; $l6++) {
        I = $l6;
        Nodes.item(I).hidden = false;
      };
    };
  };
  $mod.$init = function () {
    $impl.Start();
  };
},["JS","Web","PageKit","PageGlobals"]);

rtl.run('ForumPage');
}
