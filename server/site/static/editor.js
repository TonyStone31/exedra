if (!pas.EditorPage) {
rtl.module("EditorPage",["System"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  $mod.$implcode = function () {
    $impl.CaretLook = ["boxSizing","width","fontFamily","fontSize","fontWeight","fontStyle","lineHeight","letterSpacing","wordSpacing","tabSize","textIndent","paddingTop","paddingRight","paddingBottom","paddingLeft","borderTopWidth","borderRightWidth","borderBottomWidth","borderLeftWidth"];
    $impl.MirrorLook = ["fontFamily","fontSize","fontWeight","lineHeight","letterSpacing","tabSize","paddingTop","paddingRight","paddingBottom","paddingLeft"];
    $impl.T = null;
    $impl.Mac = false;
    $impl.ModKey = "";
    $impl.ShiftKey = "";
    $impl.Made = 0;
    $impl.El = function (Tag, Cls, Text) {
      var Result = null;
      Result = document.createElement(Tag);
      if (Cls) Result.className = "" + Cls;
      if (typeof(Text) !== "undefined") Result["textContent"] = Text;
      return Result;
    };
    $impl.Svg = function (Inner) {
      var Result = "";
      Result = '<svg viewBox="0 0 24 24" aria-hidden="true">' + Inner + "</svg>";
      return Result;
    };
    $impl.Either = function (A, B) {
      var Result = undefined;
      if (A) {
        Result = A}
       else Result = B;
      return Result;
    };
    $impl.KeepIndent = function (M, Indent) {
      var Result = "";
      if (typeof(Indent) === "string") {
        Result = "" + Indent}
       else Result = "";
      return Result;
    };
    $impl.Attach = function (Box, Options) {
      var Result = null;
      var Opts = null;
      var Pictures = null;
      var Form = null;
      var Language = "";
      var Editor = null;
      var GroupWords = null;
      var Tabs = null;
      var Open = null;
      var AskRow = null;
      var Shell = null;
      var Bar = null;
      var Tools = null;
      var Side = null;
      var Suggest = null;
      var Modes = null;
      var Whole = null;
      var Panes = null;
      var View = null;
      var Foot = null;
      var News = null;
      var Hint = null;
      var AttachLink = null;
      var Gallery = null;
      var HelpButton = null;
      var Help = null;
      var LabelEl = null;
      var SendRow = null;
      var Sheet = null;
      var Row = null;
      var Cell = null;
      var KeysLine = null;
      var More = null;
      var Guide = null;
      var Mirror = null;
      var Chooser = null;
      var Pending = 0;
      var Chosen = 0;
      var TypedFrom = 0;
      var TypedAt = 0;
      var NewsTimer = 0;
      var Timer = 0;
      var Again = 0;
      var I = 0;
      var EmojiAsked = null;
      var Choices = null;
      var Cheats = null;
      var Pair = null;
      var Eager = false;
      var Stale = false;
      var Saving = false;
      var Narrow = null;
      var StoreKey = "";
      var Mode = "";
      var First = "";
      var Icon = "";
      var Asking = null;
      var Ties = [];
      var Part = undefined;
      var Stored = undefined;
      function Fresh() {
        if (Opts["pictures"]) {
          Pictures = Opts["pictures"]}
         else Pictures = null;
      };
      function Replace(From, To_, Text, SelectFrom, SelectTo) {
        var Done = false;
        var At = 0.0;
        var Last = 0.0;
        Box.focus();
        Box.setSelectionRange(From,To_);
        Done = false;
        try {
          Done = document.execCommand("insertText",false,Text);
        } catch ($e) {
          Done = false;
        };
        if (!Done) Box.setRangeText(Text,From,To_,"end");
        if (typeof(SelectFrom) === "undefined") {
          At = From + Text.length}
         else At = From + Number(SelectFrom);
        if (typeof(SelectTo) === "undefined") {
          Last = From + Text.length}
         else Last = From + Number(SelectTo);
        Box.setSelectionRange(At,Last);
        Box.dispatchEvent(new Event("input",pas.JS.New(["bubbles",true])));
      };
      function Wrap(Before, After, Placeholder) {
        var A = 0;
        var B = 0;
        var V = "";
        var Inner = "";
        var Words = "";
        A = Box.selectionStart;
        B = Box.selectionEnd;
        V = Box.value;
        Inner = V.slice(A,B);
        if ((V.slice(A - Before.length,A) === Before) && (V.slice(B,B + After.length) === After)) {
          Replace(A - Before.length,B + After.length,Inner,0,Inner.length);
          return;
        };
        if (Inner !== "") {
          Words = Inner}
         else Words = Placeholder;
        Replace(A,B,Before + Words + After,Before.length,Before.length + Words.length);
      };
      function Lines() {
        var Result = null;
        var V = "";
        var From = 0;
        var To_ = 0;
        var Back = 0;
        V = Box.value;
        From = V.lastIndexOf("\n",Box.selectionStart - 1) + 1;
        Back = 0;
        if ((Box.selectionEnd > Box.selectionStart) && (V.charAt(Box.selectionEnd - 1) === "\n")) Back = 1;
        To_ = V.indexOf("\n",Box.selectionEnd - Back);
        if (To_ < 0) To_ = V.length;
        Result = pas.JS.New(["from",From,"to",To_,"text",V.slice(From,To_)]);
        return Result;
      };
      function Prefix(Make, Test) {
        var L = null;
        var Rows = [];
        var Out_ = null;
        var All = false;
        var N = 0;
        var Joined = "";
        L = Lines();
        Rows = L.text.split("\n");
        All = true;
        for (var $l = 0, $end = rtl.length(Rows) - 1; $l <= $end; $l++) {
          N = $l;
          if (!Test.test(Rows[N])) {
            All = false;
            break;
          };
        };
        Out_ = new Array();
        for (var $l1 = 0, $end1 = rtl.length(Rows) - 1; $l1 <= $end1; $l1++) {
          N = $l1;
          if (All) {
            Out_.push(Rows[N].replace(Test,$impl.KeepIndent))}
           else Out_.push(Make(N) + Rows[N].replace(new RegExp("^(\\s*)([-*+]\\s+|\\d+[.)]\\s+|>\\s?)"),"$1"));
        };
        Joined = Out_.join("\n");
        Replace(L.from,L.to,Joined,0,Joined.length);
      };
      function Code() {
        var A = 0;
        var B = 0;
        var Inner = "";
        var Block = "";
        A = Box.selectionStart;
        B = Box.selectionEnd;
        Inner = Box.value.slice(A,B);
        if (Inner.indexOf("\n",0) < 0) {
          Wrap("`","`",$impl.T("code"));
          return;
        };
        Block = "```" + Language + "\n" + Inner.replace(new RegExp("\\n$"),"") + "\n" + "```" + "\n";
        Replace(A,B,Block,3,3 + Language.length);
      };
      function Link() {
        var A = 0;
        var B = 0;
        var Words = "";
        var Text = "";
        A = Box.selectionStart;
        B = Box.selectionEnd;
        Words = Box.value.slice(A,B);
        if (Words === "") Words = $impl.T("words");
        Text = "[" + Words + "](https://)";
        Replace(A,B,Text,Words.length + 3,Text.length - 1);
      };
      function Table(Columns, Rows) {
        var Text = "";
        var V = "";
        var Lead = "";
        var N = 0;
        var R = 0;
        var A = 0;
        function Cell$1(N) {
          var Result = "";
          Result = " " + $impl.T("Column") + " " + ("" + (N + 1)) + " ";
          return Result;
        };
        Text = "|";
        for (var $l = 0, $end = Columns - 1; $l <= $end; $l++) {
          N = $l;
          Text = Text + Cell$1(N) + "|";
        };
        Text = Text + "\n" + "|";
        for (var $l1 = 0, $end1 = Columns - 1; $l1 <= $end1; $l1++) {
          N = $l1;
          Text = Text + " --- |";
        };
        for (var $l2 = 0, $end2 = Rows - 2; $l2 <= $end2; $l2++) {
          R = $l2;
          Text = Text + "\n" + "|";
          for (var $l3 = 0, $end3 = Columns - 1; $l3 <= $end3; $l3++) {
            N = $l3;
            Text = Text + "   |";
          };
        };
        A = Box.selectionStart;
        V = Box.value;
        if ((A === 0) || (V.slice(A - 2,A) === "\n\n")) {
          Lead = ""}
         else if (V.charAt(A - 1) === "\n") {
          Lead = "\n"}
         else Lead = "\n\n";
        Replace(A,Box.selectionEnd,Lead + Text + "\n",Lead.length + 2,(Lead.length + 2 + Cell$1(0).length) - 2);
      };
      function ClosePop() {
        if (Open !== null) {
          Open.remove();
          Open = null;
        };
      };
      function Pop(Button) {
        var Result = null;
        var Card = null;
        ClosePop();
        Open = $impl.El("div","editor-tools-pop",undefined);
        Button.after(Open);
        Card = Open;
        window.requestAnimationFrame(function (Time) {
          var Room = 0.0;
          Room = Button.parentElement.clientWidth;
          Card.style["left"] = "" + Math.max(0,Math.min(Button.offsetLeft,Room - Card.offsetWidth)) + "px";
        });
        Result = Open;
        return Result;
      };
      function TableGrid(Button) {
        var Card = null;
        var Size = null;
        var Grid = null;
        var R = 0;
        var C = 0;
        function Add(R, C) {
          var Cell = null;
          Cell = $impl.El("button",undefined,undefined);
          Cell.type = "button";
          Cell.dataset["r"] = "" + R;
          Cell.dataset["c"] = "" + C;
          Cell.setAttribute("aria-label",$impl.T("%s table","" + C + " × " + ("" + R)));
          Cell.addEventListener("pointerenter",function (E) {
            var X = undefined;
            for (var $in = Grid.children, $l = 0, $end = rtl.length($in) - 1; $l <= $end; $l++) {
              X = $in[$l];
              X.classList.toggle("on",(Number(X.dataset["r"]) <= R) && (Number(X.dataset["c"]) <= C));
            };
            Size.textContent = $impl.T("%s table","" + C + " × " + ("" + R));
          });
          Cell.addEventListener("click",function (E) {
            ClosePop();
            Table(C,R);
          });
          Grid.appendChild(Cell);
        };
        Card = Pop(Button);
        Size = $impl.El("p","editor-tools-size","");
        Grid = $impl.El("div","editor-tools-grid",undefined);
        for (R = 1; R <= 6; R++) for (C = 1; C <= 6; C++) Add(R,C);
        Card.append(Grid,Size);
      };
      function SetHeading(Level) {
        var L = null;
        var Rest = "";
        L = Lines();
        Rest = L.text.replace(new RegExp("^#{1,6}\\s+"),"");
        if (Level !== 0) {
          Replace(L.from,L.to,"#".repeat(Level) + " " + Rest,undefined,undefined)}
         else Replace(L.from,L.to,Rest,undefined,undefined);
      };
      function HeadingMenu(Button) {
        var Card = null;
        var Now = 0;
        var Found = [];
        function Add(Level, Words) {
          var B = null;
          B = $impl.El("button","editor-tools-h" + ("" + Level),Words);
          B.type = "button";
          if (Level === Now) B.setAttribute("aria-current","true");
          B.addEventListener("click",function (E) {
            ClosePop();
            SetHeading(Level);
          });
          Card.appendChild(B);
        };
        Card = Pop(Button);
        Card.classList.add("editor-tools-menu");
        Found = (new RegExp("^(#{1,6})\\s+")).exec(Lines().text);
        if (rtl.length(Found) > 0) {
          Now = Found[1].length}
         else Now = 0;
        Add(2,$impl.T("Heading"));
        Add(3,$impl.T("Subheading"));
        Add(4,$impl.T("Small heading"));
        Add(0,$impl.T("Normal text"));
        Card.querySelector("button").focus();
      };
      function Choose(Accept) {
        Fresh();
        if (typeof(Accept) === "string") {
          Chooser["accept"] = Accept}
         else if (Pictures !== null) {
          Chooser["accept"] = Pictures.accept}
         else Chooser.accept = "";
        Chooser.click();
      };
      function WhichSize(F, Small) {
        var Result = null;
        function Mb(Sized) {
          var Result = "";
          Result = ((Sized.size / 1048576)).toFixed(1) + " MB";
          return Result;
        };
        Fresh();
        if (Boolean(Pictures["refuses"]) && Boolean(Pictures.refuses(F))) return Promise.resolve(Small);
        Result = new Promise(function (Done, Fail) {
          var Row = null;
          var Less = null;
          var All = null;
          Row = $impl.El("p","",$impl.Either(F.name,$impl.T("picture")));
          Less = $impl.El("button","",$impl.T("Smaller") + " · " + Mb(Small));
          All = $impl.El("button","",$impl.T("Full size") + " · " + Mb(F));
          All.type = "button";
          Less.type = "button";
          Less.addEventListener("click",function (E) {
            Row.remove();
            Done(Small);
          });
          All.addEventListener("click",function (E) {
            Row.remove();
            Done(F);
          });
          Row.append(Less,All);
          AskRow.appendChild(Row);
        });
        return Result;
      };
      async function Sized(F) {
        var Result = undefined;
        var Small = undefined;
        Small = await window.Keys.smaller(F);
        if (Small == F) {
          Result = F}
         else Result = WhichSize(F,Small);
        return Result;
      };
      async function Send(F, Name, Mark) {
        var Put = "";
        var Done = null;
        var At = 0;
        var End_ = 0;
        var KeepA = 0;
        var KeepB = 0;
        var Shift = 0;
        function Fix(X) {
          var Result = 0;
          if (X > At) {
            Result = Math.max(At,X + Shift)}
           else Result = X;
          return Result;
        };
        Pending += 1;
        Busy();
        Put = "";
        try {
          try {
            Fresh();
            Done = await Pictures.send(F,Name);
            if (Done["put"]) {
              Put = "" + Done["put"]}
             else Put = "";
            if (Done["words"]) Say(Done["words"],undefined);
          } catch ($e) {
            Say($impl.Either($e["message"],$impl.T("The picture could not be uploaded.")),true);
          };
        } finally {
          Pending -= 1;
          Busy();
        };
        At = Box.value.indexOf(Mark,0);
        if (At < 0) return;
        End_ = At + Mark.length;
        if ((Put === "") && (Box.value.charAt(At + Mark.length) === "\n")) End_ += 1;
        KeepA = Box.selectionStart;
        KeepB = Box.selectionEnd;
        Shift = Put.length - (End_ - At);
        Replace(At,End_,Put,undefined,undefined);
        Box.setSelectionRange(Fix(KeepA),Fix(KeepB));
      };
      async function Upload(List) {
        var N = 0;
        var A = 0;
        var F = null;
        var Refusal = undefined;
        var Name = "";
        var Mark = "";
        var V = "";
        var Lead = "";
        Fresh();
        if (Pictures === null) return;
        if (window["Keys"]) {
          Pending += 1;
          try {
            List = await Promise.all(List.map(Sized));
          } finally {
            Pending -= 1;
          };
        };
        for (var $l = 0, $end = List.length - 1; $l <= $end; $l++) {
          N = $l;
          F = List[N];
          Fresh();
          if (Pictures["refuses"]) {
            Refusal = Pictures.refuses(F)}
           else if (Pictures.types.test(F.type)) {
            Refusal = ""}
           else Refusal = $impl.T("Only pictures can be added: PNG, JPEG, GIF or WebP. %s is not one.",$impl.Either(F.name,""));
          if (Refusal) {
            Say(Refusal,true);
            continue;
          };
          if (!Boolean(F.name) || (new RegExp("^image\\.\\w+$","i")).test("" + F.name)) {
            Name = "Screenshot " + (new Date()).toISOString().slice(0,19).replace(new RegExp("[T:]","g"),"-") + "." + F.type.split("/")[1].replace("jpeg","jpg")}
           else Name = "" + F.name;
          Mark = "[" + $impl.T("Uploading %s…",Name) + "]";
          A = Box.selectionStart;
          V = Box.value;
          if ((A === 0) || (V.charAt(A - 1) === "\n")) {
            Lead = ""}
           else Lead = "\n";
          Replace(A,Box.selectionEnd,Lead + Mark + "\n",undefined,undefined);
          Send(F,Name,Mark);
        };
      };
      function Tool(Caption, Keys_, Mark, Act) {
        var Result = null;
        var B = null;
        B = $impl.El("button","editor-tool",undefined);
        B.type = "button";
        if (Keys_) {
          B.title = Caption + " (" + ("" + Keys_) + ")"}
         else B.title = Caption;
        B.setAttribute("aria-label",Caption);
        B.innerHTML = Mark;   // safe html: the toolbar's own icons, written here;
        B.addEventListener("click",function (E) {
          Act(B);
        });
        Tools.appendChild(B);
        Result = B;
        return Result;
      };
      function Gap() {
        Tools.appendChild($impl.El("span","editor-tool-gap",undefined));
      };
      function EmojiSet() {
        var Result = null;
        if (EmojiAsked === null) EmojiAsked = Promise.resolve(undefined).then(Opts["emoji"]).then(function (List) {
          var Result = undefined;
          if (Array.isArray(List)) {
            Result = List}
           else Result = new Array();
          return Result;
        }).catch(function (E) {
          var Result = undefined;
          EmojiAsked = null;
          Result = new Array();
          return Result;
        });
        Result = EmojiAsked;
        return Result;
      };
      function EmojiFace(E) {
        var Result = null;
        if (E.src) {
          Result = $impl.El("img","emo",undefined);
          Result["src"] = E.src;
          Result.alt = E.emoji;
          return Result;
        };
        Result = $impl.El("span","emo",E.emoji);
        return Result;
      };
      function EmojiPanel(Button) {
        var Card = null;
        var Grid = null;
        var Find = null;
        var A = 0;
        var B = 0;
        function Fill(List) {
          var Q = "";
          var Group = undefined;
          var N = 0;
          var E = null;
          function Add(E) {
            var Cell = null;
            Cell = $impl.El("button","editor-emoji-cell",undefined);
            Cell.type = "button";
            if (E.keywords.length !== 0) {
              Cell.title = E.name + "  :" + ("" + E.keywords[0]) + ":"}
             else Cell.title = E.name;
            Cell.setAttribute("aria-label",E.name);
            Cell.appendChild(EmojiFace(E));
            Cell.addEventListener("click",function (Ev) {
              ClosePop();
              Replace(A,B,E.emoji,undefined,undefined);
            });
            Grid.appendChild(Cell);
          };
          Grid.replaceChildren();
          Q = Find.value.trim().toLowerCase().replace(new RegExp(":","g"),"");
          Group = null;
          for (var $l = 0, $end = List.length - 1; $l <= $end; $l++) {
            N = $l;
            E = List[N];
            if ((Q !== "") && (E.name.toLowerCase().indexOf(Q,0) < 0) && !E.keywords.some(function (K, At, All) {
              var Result = false;
              Result = K.indexOf(Q,0) >= 0;
              return Result;
            })) continue;
            if ((Q === "") && !Object.is(E.group,Group)) {
              Group = E.group;
              Grid.appendChild($impl.El("div","editor-emoji-group",$impl.Either(GroupWords["" + Group],Group)));
            };
            Add(E);
          };
          if (Grid.querySelector("button") === null) Grid.appendChild($impl.El("p","editor-emoji-none",$impl.T("No emoji has that name.")));
        };
        Card = Pop(Button);
        Card.classList.add("editor-emoji");
        A = Box.selectionStart;
        B = Box.selectionEnd;
        Find = $impl.El("input",undefined,undefined);
        Find.type = "search";
        Find.placeholder = $impl.T("Find an emoji");
        Find.setAttribute("aria-label",$impl.T("Find an emoji"));
        Grid = $impl.El("div","editor-emoji-grid",undefined);
        Card.append(Find,Grid);
        EmojiSet().then(function (List) {
          var Result = undefined;
          Fill(List);
          Find.addEventListener("input",function (E) {
            Fill(List);
          });
          return Result;
        });
        Find.addEventListener("keydown",function (E) {
          var First = null;
          if (E.key === "Enter") {
            E.preventDefault();
            First = Grid.querySelector("button");
            if (First !== null) First.click();
          };
        });
        window.requestAnimationFrame(function (Time) {
          Find.focus();
        });
      };
      function CaretPoint(Index) {
        var Result = null;
        var Cs = null;
        var Look = null;
        var Twin = null;
        var Mark = null;
        var P = "";
        var R = null;
        Cs = window.getComputedStyle(Box);
        Twin = $impl.El("div",undefined,undefined);
        Look = Twin.style;
        for (var $in = $impl.CaretLook, $l = 0, $end = rtl.length($in) - 1; $l <= $end; $l++) {
          P = $in[$l];
          Look[P] = Cs[P];
        };
        Look["position"] = "absolute";
        Look["visibility"] = "hidden";
        Look["whiteSpace"] = "pre-wrap";
        Look["overflowWrap"] = "break-word";
        Look["borderStyle"] = "solid";
        Look["top"] = "0";
        Look["left"] = "-9999px";
        Twin.textContent = Box.value.slice(0,Index);
        Mark = $impl.El("span","","​");
        Twin.appendChild(Mark);
        document.body.appendChild(Twin);
        R = Box.getBoundingClientRect();
        Result = pas.JS.New(["top",((R.top + Mark.offsetTop) - Box.scrollTop) + Mark.offsetHeight,"left",(R.left + Mark.offsetLeft) - Box.scrollLeft]);
        Twin.remove();
        return Result;
      };
      function CloseSuggest() {
        if (Suggest !== null) {
          Suggest.remove();
          Suggest = null;
        };
        Choices = new Array();
        Eager = false;
      };
      function TakeChoice(N) {
        var E = null;
        var At = 0;
        E = Choices[N];
        At = Box.selectionStart;
        CloseSuggest();
        if (Boolean(E) && (TypedFrom >= 0)) Replace(TypedFrom,At,E.emoji,undefined,undefined);
      };
      function Mark(N) {
        var Rows = null;
        var At = 0;
        Chosen = N;
        Rows = Array.from(Suggest.children);
        for (var $l = 0, $end = Rows.length - 1; $l <= $end; $l++) {
          At = $l;
          Rows[At].classList.toggle("on",At === N);
        };
      };
      function ShowSuggest() {
        var N = 0;
        var P = null;
        function Add(E, N) {
          var Row = null;
          var Key = undefined;
          var Name = undefined;
          Row = $impl.El("li",undefined,undefined);
          Row.setAttribute("role","option");
          Key = $impl.Either($impl.Either(E["match"],E.keywords[0]),"");
          if (Object.is(E["name"],Key)) {
            Name = ""}
           else Name = E["name"];
          Row.append(EmojiFace(E),$impl.El("span","editor-suggest-key",":" + ("" + Key) + ":"),$impl.El("span","editor-suggest-name",Name));
          Row.addEventListener("mousemove",function (Ev) {
            if (Chosen !== N) Mark(N);
          });
          Row.addEventListener("click",function (Ev) {
            TakeChoice(N);
          });
          Suggest.appendChild(Row);
        };
        if (Suggest === null) {
          Suggest = $impl.El("ul","editor-suggest",undefined);
          Suggest.setAttribute("role","listbox");
          Suggest.addEventListener("pointerdown",function (E) {
            E.preventDefault();
          });
          document.body.appendChild(Suggest);
        };
        Suggest.replaceChildren();
        for (var $l = 0, $end = Choices.length - 1; $l <= $end; $l++) {
          N = $l;
          Add(Choices[N],N);
        };
        Mark(0);
        P = CaretPoint(TypedFrom);
        Suggest.style["top"] = "" + Math.min(P.top + 4,window.innerHeight - Suggest.offsetHeight - 8) + "px";
        Suggest.style["left"] = "" + Math.max(8,Math.min(P.left,window.innerWidth - Suggest.offsetWidth - 8)) + "px";
      };
      function Offer(Ev) {
        var At = 0;
        var Typing = null;
        At = Box.selectionStart;
        if (At === Box.selectionEnd) {
          Typing = window.EmojiNames.typed(Box.value,At,Eager)}
         else Typing = null;
        if (!Boolean(Typing) || (Typing.whole && !(Boolean(Ev) && (Ev.data === ":")))) {
          CloseSuggest();
          return;
        };
        TypedFrom = Typing.from;
        EmojiSet().then(function (List) {
          var Result = undefined;
          var Hit = null;
          if (Box.selectionStart !== At) return Result;
          if (Typing.whole) {
            Hit = window.EmojiNames.named(List,Typing.word);
            CloseSuggest();
            if (Boolean(Hit)) Replace(TypedFrom,At,Hit.emoji,undefined,undefined);
            return Result;
          };
          Choices = window.EmojiNames.matches(List,Typing.word).slice(0,8);
          if (Choices.length !== 0) {
            ShowSuggest()}
           else CloseSuggest();
          return Result;
        });
      };
      function Bullets() {
        Prefix(function (N) {
          var Result = "";
          Result = "- ";
          return Result;
        },new RegExp("^(\\s*)[-*+]\\s+"));
      };
      function Numbers() {
        Prefix(function (N) {
          var Result = "";
          Result = "" + (N + 1) + ". ";
          return Result;
        },new RegExp("^(\\s*)\\d+[.)]\\s+"));
      };
      function Say(Words, Bad) {
        window.clearTimeout(NewsTimer);
        News["textContent"] = Words;
        News.classList.toggle("bad",Boolean(Bad));
        if (!Bad) NewsTimer = window.setTimeout(function () {
          Busy();
        },4000);
      };
      function Busy() {
        if (Pending !== 0) {
          News.classList.remove("bad");
          if (window["tn"]) {
            News.textContent = window.tn(Pending,"Uploading %d picture…","Uploading %d pictures…")}
           else News.textContent = $impl.T("Uploading…");
        } else if (!News.classList.contains("bad")) News.textContent = "";
      };
      function Shown() {
        var Result = "";
        if ((Mode === "split") && Narrow.matches) {
          Result = "write"}
         else Result = Mode;
        return Result;
      };
      function Draw() {
        var Now = "";
        var Key = "";
        var B = undefined;
        Now = Shown();
        Panes.dataset["mode"] = Now;
        Bar.dataset["mode"] = Now;
        for (Key in Tabs) if (Key === Now) {
          Tabs[Key].setAttribute("aria-selected","true")}
         else Tabs[Key].setAttribute("aria-selected","false");
        Tabs["split"].hidden = Narrow.matches;
        for (var $in = Tools.querySelectorAll(".editor-tool"), $l = 0, $end = rtl.length($in) - 1; $l <= $end; $l++) {
          B = $in[$l];
          B.disabled = Now === "preview";
        };
        if (Now === "preview") ClosePop();
        if ((Now !== "write") && Stale) {
          Ask()}
         else if (Now === "split") {
          Measure();
          Follow();
        };
      };
      function SetMode(Key) {
        Mode = Key;
        try {
          window.localStorage.setItem(StoreKey,Mode);
        } catch ($e) {
        };
        Draw();
        if (Shown() !== "preview") Box.focus();
      };
      function AddTab(Key, Words) {
        var B = null;
        B = $impl.El("button","editor-mode",Words);
        B.type = "button";
        B.setAttribute("role","tab");
        B.dataset["mode"] = Key;
        B.addEventListener("click",function (E) {
          SetMode(Key);
        });
        Tabs[Key] = B;
        Modes.appendChild(B);
      };
      function SetWhole(On_, Quiet) {
        Shell.classList.toggle("whole",On_);
        if (On_) {
          Foot.after(SendRow)}
         else Shell.after(SendRow);
        window.requestAnimationFrame(function (Time) {
          Measure();
          Follow();
        });
        document.documentElement.classList.toggle("editor-whole",On_);
        if (On_) {
          Whole.setAttribute("aria-pressed","true")}
         else Whole.setAttribute("aria-pressed","false");
        if (On_) {
          Whole.title = $impl.T("Leave full screen (Esc)")}
         else Whole.title = $impl.T("Full screen");
        Whole.setAttribute("aria-label",Whole.title);
        if (!Quiet) Box.focus();
      };
      async function Ask() {
        var Mine = null;
        var Html = "";
        Stale = false;
        if (Asking !== null) Asking.abort();
        Mine = new AbortController();
        Asking = Mine;
        View.classList.add("busy");
        if (View.firstChild === null) View.appendChild($impl.El("p","fine",$impl.T("Making the preview…")));
        try {
          try {
            Html = await Opts.preview(Box.value,Mine.signal);
            if (Asking !== Mine) return;
            View.innerHTML = Html;   // safe html: the part's own renderer made it;
            if (Box.value.trim() === "") {
              View.replaceChildren($impl.El("p","fine",$impl.Either(Opts["emptyWords"],$impl.T("The preview shows here as you write."))))}
             else if (Opts["afterPreview"]) Opts.afterPreview(View);
            Measure();
            Follow();
          } catch ($e) {
            if ($e["name"] == "AbortError") return;
            Stale = true;
            View.replaceChildren($impl.El("p","problem",$impl.T("The preview could not be made. It tries again when you type.")));
          };
        } finally {
          if (Asking === Mine) {
            Asking = null;
            View.classList.remove("busy");
          };
        };
      };
      function Plain(Words) {
        var Result = "";
        Result = Words.replace(new RegExp("[^\\p{L}\\p{N}]+","gu"),"").toLowerCase();
        return Result;
      };
      function HeadingStarts() {
        var Result = null;
        var At = 0;
        var Fence = "";
        var Line = "";
        var Mark = [];
        Result = new Array();
        At = 0;
        Fence = "";
        for (var $in = Box.value.split("\n"), $l = 0, $end = rtl.length($in) - 1; $l <= $end; $l++) {
          Line = $in[$l];
          Mark = (new RegExp("^ {0,3}(`{3,}|~{3,})(.*)$")).exec(Line);
          if (rtl.length(Mark) > 0) {
            if (Fence === "") {
              Fence = Mark[1]}
             else if ((Mark[1].charAt(0) === Fence.charAt(0)) && (Mark[1].length >= Fence.length) && (Mark[2].trim() === "")) Fence = "";
          } else if ((Fence === "") && (new RegExp("^ {0,3}#{1,6}([ \\t]|$)")).test(Line)) Result.push(pas.JS.New(["at",At,"words",Plain(Line.replace(new RegExp("^\\s*#+"),"").replace(new RegExp("\\[\\[(?:[^\\]|]*\\|)?([^\\]]*)\\]\\]","g"),"$1").replace(new RegExp("\\[([^\\]]*)\\]\\([^)]*\\)","g"),"$1"))]));
          At = At + Line.length + 1;
        };
        return Result;
      };
      function Measure() {
        var Heads = null;
        var Paired = null;
        var Marks = null;
        var Starts = [];
        var Next = 0;
        var K = 0;
        var N = 0;
        var From = 0;
        var H = undefined;
        var Look = null;
        var P = "";
        var Mark = null;
        var TextMax = 0.0;
        var ViewMax = 0.0;
        var Top = 0.0;
        var A = 0.0;
        var B = 0.0;
        var Made = [];
        var Last = [];
        Ties = [];
        if (Shown() !== "split") return;
        Heads = Array.from(View.querySelectorAll("" + $impl.Either(Opts["heads"],"h1, h2, h3, h4, h5, h6")));
        Starts = [];
        Paired = new Array();
        Next = 0;
        for (var $in = HeadingStarts(), $l = 0, $end = rtl.length($in) - 1; $l <= $end; $l++) {
          H = $in[$l];
          K = Next;
          while (K < Math.min(Heads.length,Next + 4)) {
            if (Plain(Heads[K].textContent) === H.words) {
              Starts.push(H.at);
              Paired.push(Heads[K]);
              Next = K + 1;
              break;
            };
            K += 1;
          };
        };
        if (rtl.length(Starts) === 0) return;
        Look = window.getComputedStyle(Box);
        for (var $in1 = $impl.MirrorLook, $l1 = 0, $end1 = rtl.length($in1) - 1; $l1 <= $end1; $l1++) {
          P = $in1[$l1];
          Mirror.style[P] = Look[P];
        };
        Mirror.style["width"] = "" + Box.clientWidth + "px";
        Mirror.replaceChildren();
        Marks = new Array();
        From = 0;
        for (var $l2 = 0, $end2 = rtl.length(Starts) - 1; $l2 <= $end2; $l2++) {
          N = $l2;
          Mirror.append(Box.value.slice(From,Starts[N]));
          Mark = $impl.El("span",undefined,undefined);
          Mirror.append(Mark);
          Marks.push(Mark);
          From = Starts[N];
        };
        Mirror.append(Box.value.slice(From));
        document.body.appendChild(Mirror);
        TextMax = Box.scrollHeight - Box.clientHeight;
        ViewMax = View.scrollHeight - View.clientHeight;
        Top = View.getBoundingClientRect().top - View.scrollTop;
        Made = [[0,0]];
        for (var $l3 = 0, $end3 = Marks.length - 1; $l3 <= $end3; $l3++) {
          N = $l3;
          A = Math.min(Marks[N].offsetTop - parseFloat(Look["paddingTop"]),TextMax);
          B = Math.min(Paired[N].getBoundingClientRect().top - Top - 12,ViewMax);
          Last = rtl.arrayRef(Made[rtl.length(Made) - 1]);
          if ((A > Last[0]) && (B >= Last[1])) Made.push(new Array(A,B));
        };
        Mirror.remove();
        Mirror.replaceChildren();
        Last = rtl.arrayRef(Made[rtl.length(Made) - 1]);
        if (TextMax > Last[0]) Made.push(new Array(TextMax,Math.max(ViewMax,Last[1])));
        Ties = rtl.arrayRef(Made);
      };
      function Follow() {
        var Y = 0.0;
        var Part = 0.0;
        var Room = 0.0;
        var N = 0;
        var A = [];
        var B = [];
        if (Shown() !== "split") return;
        Y = Box.scrollTop;
        if (rtl.length(Ties) > 1) {
          N = 0;
          while ((N < (rtl.length(Ties) - 2)) && (Ties[N + 1][0] <= Y)) N += 1;
          A = rtl.arrayRef(Ties[N]);
          B = rtl.arrayRef(Ties[N + 1]);
          if (B[0] > A[0]) {
            Part = Math.min(1,Math.max(0,(Y - A[0]) / (B[0] - A[0])))}
           else Part = 0;
          View["scrollTop"] = A[1] + (Part * (B[1] - A[1]));
          return;
        };
        Room = Box.scrollHeight - Box.clientHeight;
        if (Room > 0) {
          View["scrollTop"] = (Y / Room) * (View.scrollHeight - View.clientHeight)}
         else View.scrollTop = 0;
      };
      function Remeasure() {
        window.clearTimeout(Again);
        Again = window.setTimeout(function () {
          Measure();
          Follow();
        },150);
      };
      function Save() {
        var Button = null;
        if (Pending !== 0) {
          Say($impl.T("Wait until the pictures are uploaded."),true);
          return;
        };
        if (Form === null) return;
        Button = Form.querySelector('button[type="submit"]:not([name])');
        if (Form["requestSubmit"]) {
          if (Button !== null) {
            Form.requestSubmit(Button)}
           else Form.requestSubmit();
        } else if (Button !== null) Button.click();
      };
      function NotSaved() {
        Saving = false;
      };
      if (Box["editor"]) return Box["editor"];
      if (Boolean(Options)) {
        Opts = Options}
       else Opts = new Object();
      Fresh();
      Form = Box.closest("form");
      if (Opts["language"]) {
        Language = "" + Opts["language"]}
       else Language = "";
      Choices = new Array();
      TypedFrom = -1;
      TypedAt = -1;
      Stale = true;
      Editor = pas.JS.New(["box",Box,"form",Form,"el",$impl.El,"svg",$impl.Svg,"replace",Replace,"wrap",Wrap,"lines",Lines,"prefix",Prefix,"pop",Pop,"closePop",ClosePop,"say",Say,"tool",Tool,"gap",Gap,"upload",Upload,"choose",Choose]);
      document.addEventListener("pointerdown",function (E) {
        if ((Open !== null) && !Open.contains(E.target) && (E.target.closest(".editor-tools, .editor-side") === null)) ClosePop();
      });
      document.addEventListener("keydown",function (E) {
        if ((E.key === "Escape") && (Open !== null)) {
          ClosePop();
          Box.focus();
        };
      });
      Chooser = $impl.El("input",undefined,undefined);
      Chooser.type = "file";
      if (Pictures !== null) {
        Chooser["accept"] = Pictures.accept}
       else Chooser.accept = "";
      Chooser.multiple = true;
      Chooser.hidden = true;
      if (Form !== null) Form.appendChild(Chooser);
      Chooser.addEventListener("change",function (E) {
        Upload(Array.from(Chooser.files));
        Chooser.value = "";
      });
      AskRow = $impl.El("div","editor-ask",undefined);
      if (Pictures !== null) {
        Box.addEventListener("dragover",function (E) {
          if (Boolean(E.dataTransfer) && Array.from(E.dataTransfer.types).includes("Files")) {
            E.preventDefault();
            Shell.classList.add("dropping");
          };
        });
        Box.addEventListener("dragleave",function (E) {
          Shell.classList.remove("dropping");
        });
        Box.addEventListener("drop",function (E) {
          var List = null;
          var P = null;
          Shell.classList.remove("dropping");
          if (Boolean(E.dataTransfer)) {
            List = Array.from(E.dataTransfer.files)}
           else List = new Array();
          if (List.length === 0) return;
          E.preventDefault();
          if (document["caretPositionFromPoint"]) {
            P = document.caretPositionFromPoint(E.clientX,E.clientY);
            if (Boolean(P) && (P.offsetNode === Box)) Box.setSelectionRange(P.offset,P.offset);
          };
          Upload(List);
        });
        Box.addEventListener("paste",function (E) {
          var List = null;
          var Data = null;
          Data = E.clipboardData;
          if (Boolean(Data)) {
            List = Array.from($impl.Either(Data.files,new Array()))}
           else List = new Array();
          if (List.length === 0) return;
          E.preventDefault();
          Upload(List);
        });
      };
      if (Opts["compact"]) {
        Shell = $impl.El("div","editor editor-shell editor-compact",undefined)}
       else Shell = $impl.El("div","editor editor-shell",undefined);
      Bar = $impl.El("div","editor-bar",undefined);
      Tools = $impl.El("div","editor-tools",undefined);
      Tools.setAttribute("role","toolbar");
      Tools.setAttribute("aria-label",$impl.T("Formatting"));
      Side = $impl.El("div","editor-side",undefined);
      Bar.append(Tools,Side);
      Tool($impl.T("Heading"),"",'H<span class="editor-tool-more" aria-hidden="true">▾</span>',HeadingMenu).setAttribute("aria-haspopup","menu");
      Tool($impl.T("Bold"),$impl.ModKey + "B","<b>B</b>",function (B) {
        Wrap("**","**",$impl.T("bold"));
      });
      Tool($impl.T("Italic"),$impl.ModKey + "I","<i>I</i>",function (B) {
        Wrap("_","_",$impl.T("italic"));
      });
      Tool($impl.T("Strikethrough"),$impl.ModKey + $impl.ShiftKey + "X","<s>S</s>",function (B) {
        Wrap("~~","~~",$impl.T("words"));
      });
      Gap();
      Tool($impl.T("Link"),$impl.ModKey + "K",$impl.Svg('<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>'),Link);
      if (Opts["linkTools"]) Opts.linkTools(Editor);
      Gap();
      Tool($impl.T("Bulleted list"),$impl.ModKey + $impl.ShiftKey + "8",$impl.Svg('<path d="M9 6h11M9 12h11M9 18h11"/><circle cx="4.5" cy="6" r="1.2"/><circle cx="4.5" cy="12" r="1.2"/><circle cx="4.5" cy="18" r="1.2"/>'),Bullets);
      Tool($impl.T("Numbered list"),$impl.ModKey + $impl.ShiftKey + "7","1.",Numbers);
      Tool($impl.T("Quote"),"","❝",function (B) {
        Prefix(function (N) {
          var Result = "";
          Result = "> ";
          return Result;
        },new RegExp("^>\\s?"));
      });
      Gap();
      Tool($impl.T("Code"),$impl.ModKey + "E","&lt;/&gt;",Code);
      Tool($impl.T("Table"),"",$impl.Svg('<rect x="3" y="5" width="18" height="14" rx="1.5"/><path d="M3 10h18M3 14.5h18M9 5v14M15 5v14"/>'),TableGrid);
      GroupWords = pas.JS.New(["status",$impl.T("Status"),"color",$impl.T("Colors"),"symbol",$impl.T("Symbols"),"own",$impl.T("This site's own")]);
      if (Opts["emoji"]) Tool($impl.T("Emoji"),"",$impl.Svg('<rect x="3.5" y="3.5" width="17" height="17" rx="4.5"/><path d="M8 12.4l2.8 2.8L16.2 9.6"/>'),EmojiPanel).setAttribute("aria-haspopup","dialog");
      if (Opts["emoji"]) {
        Box.addEventListener("input",function (Ev) {
          Offer(Ev);
          TypedAt = Box.selectionStart;
        });
        Box.addEventListener("keydown",function (Ev) {
          var E = null;
          var Arrow = false;
          var Short = null;
          E = Ev;
          Arrow = ((E.key === "ArrowDown") || (E.key === "ArrowUp")) && !E.shiftKey && !E.ctrlKey && !E.altKey && !E.metaKey;
          if ((Suggest === null) || (Choices.length === 0)) {
            if (Arrow && (Box.selectionStart === TypedAt) && (Box.selectionEnd === TypedAt)) {
              Short = window.EmojiNames.typed(Box.value,TypedAt,true)}
             else Short = null;
            if (!Boolean(Short) || Short.whole || (Short.word.length > 1)) return;
            Eager = true;
            Offer(null);
          } else if (Arrow) {
            if (E.key === "ArrowDown") {
              Mark((Chosen + 1) % Choices.length)}
             else Mark(((Chosen + Choices.length) - 1) % Choices.length);
          } else if ((E.key === "Enter") || (E.key === "Tab")) {
            TakeChoice(Chosen)}
           else if (E.key === "Escape") {
            CloseSuggest();
            TypedAt = -1;
          } else return;
          E.preventDefault();
          E.stopImmediatePropagation();
        });
        Box.addEventListener("blur",CloseSuggest);
        Box.addEventListener("scroll",CloseSuggest);
        window.addEventListener("resize",CloseSuggest);
      };
      Modes = $impl.El("div","editor-modes",undefined);
      Modes.setAttribute("role","tablist");
      Whole = $impl.El("button","editor-whole",undefined);
      Whole.type = "button";
      Icon = $impl.Svg('<path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5"/>');
      Whole.innerHTML = Icon;   // safe html: a fixed icon;
      Side.append(Modes,Whole);
      Panes = $impl.El("div","editor-panes",undefined);
      if (Opts["viewClass"]) {
        View = $impl.El("div","editor-view " + ("" + Opts["viewClass"]),undefined)}
       else View = $impl.El("div","editor-view",undefined);
      View.setAttribute("aria-live","polite");
      Foot = $impl.El("div","editor-foot",undefined);
      News = $impl.El("span","editor-news",undefined);
      News.setAttribute("role","status");
      Hint = $impl.El("span","editor-hint",undefined);
      if ((Pictures !== null) && Boolean(Pictures["label"])) {
        AttachLink = $impl.El("button","editor-link",Pictures["label"])}
       else AttachLink = $impl.El("button","editor-link",$impl.T("add pictures"));
      AttachLink.type = "button";
      AttachLink.addEventListener("click",Choose);
      Hint.append(document.createTextNode("" + $impl.Either(Opts["hint"],$impl.T("Markdown."))));
      if (Pictures !== null) {
        Hint.append(document.createTextNode(" "),AttachLink);
        if (Boolean(Pictures.gallery) && (new RegExp("Android")).test(window.navigator.userAgent)) {
          if ((new RegExp("video")).test("" + Pictures.gallery)) {
            Gallery = $impl.El("button","editor-link",$impl.T("Photos and videos"))}
           else Gallery = $impl.El("button","editor-link",$impl.T("Photos"));
          Gallery.type = "button";
          Gallery.addEventListener("click",function (E) {
            Choose(Pictures.gallery);
          });
          Hint.append(document.createTextNode(" · "),Gallery);
        };
      };
      HelpButton = $impl.El("button","editor-link",$impl.T("Formatting help"));
      HelpButton.type = "button";
      HelpButton.setAttribute("aria-expanded","false");
      Foot.append(Hint,News,HelpButton);
      Help = $impl.El("div","editor-help",undefined);
      Help.hidden = true;
      LabelEl = Box.closest("label");
      if (LabelEl !== null) {
        if (Box.id === "") {
          $impl.Made += 1;
          Box.id = "editor-box-" + ("" + $impl.Made);
        };
        LabelEl.htmlFor = Box.id;
        LabelEl.after(Shell);
      } else Box.before(Shell);
      Shell.append(Bar,Panes,AskRow,Foot,Help);
      Panes.append(Box,View);
      SendRow = $impl.El("div","editor-send",undefined);
      Shell.after(SendRow);
      if (Opts["sendRow"]) for (var $in = Opts["sendRow"], $l = 0, $end = rtl.length($in) - 1; $l <= $end; $l++) {
        Part = $in[$l];
        if (Part) SendRow.appendChild(Part);
      };
      SendRow.hidden = SendRow.firstChild === null;
      Cheats = new Array(new Array("## " + $impl.T("Heading"),$impl.T("a heading; ### for a smaller one")),new Array("**" + $impl.T("bold") + "**  _" + $impl.T("italic") + "_  ~~" + $impl.T("struck") + "~~",$impl.T("emphasis")),new Array("`code`",$impl.T("code in a sentence")),new Array("```" + ("" + $impl.Either(Language,"pascal")) + "\n" + "begin" + "\n" + "end." + "\n" + "```",$impl.T("a block of code; the word after ``` names its language, for its colors")),new Array("- " + $impl.T("item") + "\n" + "1. " + $impl.T("item"),$impl.T("lists; Tab moves an item in, Shift+Tab out")),new Array("> " + $impl.T("words"),$impl.T("a quotation")),new Array("[" + $impl.T("words") + "](https://…)",$impl.T("a link to another site")));
      if (Opts["cheats"]) Cheats = Cheats.concat(Opts["cheats"]);
      Sheet = $impl.El("table",undefined,undefined);
      for (var $l1 = 0, $end1 = Cheats.length - 1; $l1 <= $end1; $l1++) {
        I = $l1;
        Pair = Cheats[I];
        Row = $impl.El("tr",undefined,undefined);
        Cell = $impl.El("td",undefined,undefined);
        Cell.appendChild($impl.El("code","",Pair[0]));
        Row.append(Cell,$impl.El("td","",Pair[1]));
        Sheet.appendChild(Row);
      };
      KeysLine = $impl.El("p","fine",$impl.T("Keys: %s bold, %s italic, %s link, %s code, %s preview, %s save.",$impl.ModKey + "B",$impl.ModKey + "I",$impl.ModKey + "K",$impl.ModKey + "E",$impl.ModKey + $impl.ShiftKey + "P",$impl.ModKey + "Enter"));
      Help.append(Sheet,KeysLine);
      if (Opts["helpLink"]) {
        More = $impl.El("p","fine",undefined);
        Guide = $impl.El("a","",Opts["helpLink"]["words"]);
        Guide["href"] = Opts["helpLink"]["href"];
        Guide["target"] = "_blank";
        More.appendChild(Guide);
        Help.appendChild(More);
      };
      HelpButton.addEventListener("click",function (E) {
        Help.hidden = !Help.hidden;
        if (Help.hidden) {
          HelpButton.setAttribute("aria-expanded","false")}
         else HelpButton.setAttribute("aria-expanded","true");
      });
      Narrow = window.matchMedia("(max-width: 899px)");
      StoreKey = "" + $impl.Either(Opts["storeKey"],"editor-mode");
      Mode = "" + $impl.Either(Opts["mode"],"split");
      try {
        Stored = window.localStorage.getItem(StoreKey);
        if (Stored) Mode = "" + Stored;
      } catch ($e) {
      };
      if (!Opts["preview"]) {
        Mode = "write";
        Modes.hidden = true;
      };
      Tabs = new Object();
      AddTab("write",$impl.T("Write"));
      AddTab("split",$impl.T("Side by side"));
      AddTab("preview",$impl.T("Preview"));
      if (Narrow["addEventListener"]) Narrow.addEventListener("change",Draw);
      Whole.addEventListener("click",function (E) {
        SetWhole(!Shell.classList.contains("whole"),false);
      });
      SetWhole(false,true);
      document.addEventListener("keydown",function (E) {
        if ((E.key === "Escape") && (Open === null) && Shell.classList.contains("whole")) SetWhole(false,false);
      });
      Box.addEventListener("input",function (E) {
        Stale = true;
        window.clearTimeout(Timer);
        if (Shown() !== "write") Timer = window.setTimeout(Ask,700);
      });
      Mirror = $impl.El("div",undefined,undefined);
      Mirror.setAttribute("aria-hidden","true");
      Mirror.style.cssText = "position:absolute;visibility:hidden;pointer-events:none;top:0;left:-9999px;white-space:pre-wrap;overflow-wrap:break-word;" + "box-sizing:border-box;border:0;margin:0;";
      Box.addEventListener("scroll",Follow,pas.JS.New(["passive",true]));
      View.addEventListener("load",Remeasure,true);
      window.addEventListener("resize",Remeasure);
      Shell.addEventListener("keydown",function (Ev) {
        var E = null;
        var K = "";
        E = Ev;
        if (!(E.ctrlKey || E.metaKey) || E.altKey) return;
        K = E.key.toLowerCase();
        if (K === "enter") {
          E.preventDefault();
          Save();
          return;
        };
        if (E.shiftKey && (K === "p")) {
          E.preventDefault();
          if (Shown() !== "preview") {
            SetMode("preview")}
           else if (Narrow.matches) {
            SetMode("write")}
           else SetMode("split");
        };
      });
      Box.addEventListener("keydown",function (Ev) {
        var E = null;
        var K = "";
        var V = "";
        var Line = "";
        var Next = "";
        var Act = null;
        var At = 0;
        var Start = 0;
        var Cut = 0;
        var Item = [];
        E = Ev;
        K = E.key.toLowerCase();
        if ((E.ctrlKey || E.metaKey) && !E.altKey) {
          Act = null;
          if (E.shiftKey) {
            if (E.code === "Digit8") {
              K = "8"}
             else if (E.code === "Digit7") K = "7";
            if (K === "x") {
              Act = function () {
                Wrap("~~","~~",$impl.T("words"));
              }}
             else if ((K === "*") || (K === "8")) {
              Act = Bullets}
             else if ((K === "&") || (K === "7")) Act = Numbers;
          } else if (K === "b") {
            Act = function () {
              Wrap("**","**",$impl.T("bold"));
            }}
           else if (K === "i") {
            Act = function () {
              Wrap("_","_",$impl.T("italic"));
            }}
           else if (K === "k") {
            Act = Link}
           else if (K === "e") Act = Code;
          if (Act !== null) {
            E.preventDefault();
            Act();
            return;
          };
        };
        if (E.ctrlKey || E.metaKey || E.altKey || (Box.selectionStart !== Box.selectionEnd)) return;
        V = Box.value;
        At = Box.selectionStart;
        Start = V.lastIndexOf("\n",At - 1) + 1;
        Line = V.slice(Start,At);
        Item = (new RegExp("^(\\s*)([-*+]|\\d+[.)]|>)(\\s+)")).exec(Line);
        if ((E.key === "Enter") && !E.shiftKey && (rtl.length(Item) > 0)) {
          E.preventDefault();
          if (Line.length === Item[0].length) {
            Replace(Start,At,"",undefined,undefined);
            return;
          };
          if ((new RegExp("\\d")).test(Item[2])) {
            Next = "" + (parseInt(Item[2],10) + 1) + Item[2].slice(-1)}
           else Next = Item[2];
          Replace(At,At,"\n" + Item[1] + Next + Item[3],undefined,undefined);
          return;
        };
        if ((E.key === "Tab") && (rtl.length(Item) > 0) && (Item[2] !== ">")) {
          E.preventDefault();
          if (E.shiftKey) {
            Cut = Math.min(2,Item[1].length);
            if (Cut !== 0) Replace(Start,Start + Cut,"",0,0);
            Box.setSelectionRange(At - Cut,At - Cut);
          } else {
            Replace(Start,Start,"  ",0,0);
            Box.setSelectionRange(At + 2,At + 2);
          };
        };
      });
      First = Box.value;
      Saving = false;
      if (Form !== null) Form.addEventListener("submit",function (E) {
        if (Pending !== 0) {
          E.preventDefault();
          E.stopImmediatePropagation();
          Say($impl.T("Wait until the pictures are uploaded."),true);
          return;
        };
        Saving = true;
      },true);
      Editor["notSaved"] = NotSaved;
      window.addEventListener("beforeunload",function (E) {
        if (!Saving && (Box.value !== First)) {
          E.preventDefault();
          E["returnValue"] = "";
        };
      });
      Editor["shell"] = Shell;
      Editor["view"] = View;
      Draw();
      if (Shown() !== "write") Ask();
      Box["editor"] = Editor;
      Result = Editor;
      return Result;
    };
  };
  $mod.$init = function () {
    if (window["t"]) {
      $impl.T = window["t"]}
     else $impl.T = function (English) {
      var Result = "";
      Result = English;
      return Result;
    };
    $impl.Mac = (new RegExp("Mac|iPhone|iPad")).test(window.navigator.platform);
    if ($impl.Mac) {
      $impl.ModKey = "⌘"}
     else $impl.ModKey = "Ctrl+";
    if ($impl.Mac) {
      $impl.ShiftKey = "⇧"}
     else $impl.ShiftKey = "Shift+";
    $impl.Made = 0;
    window["Editor"] = pas.JS.New(["attach",$impl.Attach]);
  };
},["JS","weborworker","Web","PageKit","PageGlobals"]);

rtl.run('EditorPage');
}
