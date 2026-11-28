if (!pas.AdminPage) {
rtl.module("Admin_List",["System","JS","Web"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  this.C = null;
  this.Me = null;
  this.Extras = null;
  this.S = null;
  this.Stream = null;
  this.Locale = undefined;
  this.SiteName = undefined;
  this.FilePaths = null;
  this.Same = function (A, B) {
    var Result = false;
    Result = (typeof(A) === typeof(B)) && (A == B);
    return Result;
  };
  this.IsUndef = function (V) {
    var Result = false;
    Result = typeof(V) === "undefined";
    return Result;
  };
  this.Either = function (A, B) {
    var Result = undefined;
    if (Boolean(A)) {
      Result = A}
     else Result = B;
    return Result;
  };
  this.LocaleNumber = function (V) {
    var Result = "";
    Result = V.toLocaleString($mod.Locale);
    return Result;
  };
  this.Fixed = function (V, Digits) {
    var Result = "";
    Result = V.toFixed(Digits);
    return Result;
  };
  this.Toggle = function (Node, Name, Force) {
    var Result = false;
    Result = Node.classList.toggle(Name,Force);
    return Result;
  };
  this.FindIn = function (List, Test) {
    var Result = undefined;
    Result = List.find(Test);
    return Result;
  };
  this.SortBy = function (List, Compare) {
    var Result = null;
    Result = List.sort(Compare);
    return Result;
  };
  this.Regex = function (Pattern, Value) {
    var Result = false;
    Result = (new RegExp(Pattern)).test(String(Value));
    return Result;
  };
  this.MostOf = function (Values) {
    var Result = 0.0;
    Result = Math.max.apply(null,Values.concat(Array.of(1)));
    return Result;
  };
  this.AdminTable = function (Box, Headings, Rows) {
    var Wrap = null;
    var Table = null;
    var Head = null;
    var Row = null;
    var Cell = null;
    var Values = null;
    var Value = undefined;
    var I = 0;
    var J = 0;
    Wrap = $mod.C.el("div","gridwrap");
    Table = $mod.C.el("table","grid");
    Head = $mod.C.el("tr");
    for (var $l = 0, $end = Headings.length - 1; $l <= $end; $l++) {
      I = $l;
      Head.appendChild($mod.C.el("th","",Headings[I]));
    };
    Table.appendChild(Head);
    for (var $l1 = 0, $end1 = Rows.length - 1; $l1 <= $end1; $l1++) {
      I = $l1;
      Row = $mod.C.el("tr");
      Values = Rows[I];
      for (var $l2 = 0, $end2 = Values.length - 1; $l2 <= $end2; $l2++) {
        J = $l2;
        Value = Values[J];
        Cell = $mod.C.el("td");
        if (typeof(Value) === "object") {
          Cell.appendChild(Value)}
         else Cell.textContent = String(Value);
        Row.appendChild(Cell);
      };
      Table.appendChild(Row);
    };
    Wrap.appendChild(Table);
    Box.appendChild(Wrap);
  };
  this.Stat = function (Holder, Value, Caption, Note, Cls) {
    var Result = null;
    var Box = null;
    if (Boolean(Cls)) {
      Box = $mod.C.el("div","stat " + ("" + Cls))}
     else Box = $mod.C.el("div","stat");
    if (typeof(Value) === "number") {
      Box.appendChild($mod.C.el("b","",$mod.LocaleNumber(Value)))}
     else Box.appendChild($mod.C.el("b","",Value));
    Box.appendChild($mod.C.el("span","",Caption));
    if (Boolean(Note)) Box.appendChild($mod.C.el("small","",Note));
    Holder.appendChild(Box);
    Result = Box;
    return Result;
  };
  this.Bars = function (Holder, Rows, Format) {
    var Most = 0.0;
    var Grid = null;
    var Bar = null;
    var Fill = null;
    var Values = null;
    var R = null;
    var I = 0;
    Values = new Array();
    for (var $l = 0, $end = Rows.length - 1; $l <= $end; $l++) {
      I = $l;
      Values.push(Rows[I]["value"]);
    };
    Most = $mod.MostOf(Values);
    Grid = $mod.C.el("div","bars");
    for (var $l1 = 0, $end1 = Rows.length - 1; $l1 <= $end1; $l1++) {
      I = $l1;
      R = Rows[I];
      Grid.appendChild($mod.C.el("span","name",R["name"]));
      if (Boolean(R["other"])) {
        Bar = $mod.C.el("span","bar other")}
       else Bar = $mod.C.el("span","bar");
      Fill = $mod.C.el("i");
      Fill.style["width"] = String(Math.max(1,Math.round((100 * Number(R["value"])) / Most))) + "%";
      Bar.appendChild(Fill);
      Bar.title = "" + R["name"] + ": " + ("" + Format(R["value"]));
      Grid.appendChild(Bar);
      Grid.appendChild($mod.C.el("span","num",Format(R["value"])));
    };
    Holder.appendChild(Grid);
  };
  this.BrowserOf = function (Agent) {
    var Result = undefined;
    var A = "";
    var Name = "";
    var System = "";
    A = "" + $mod.Either(Agent,"");
    if ($mod.Regex("Edg\\/",A)) {
      Name = "Edge"}
     else if ($mod.Regex("OPR\\/|Opera",A)) {
      Name = "Opera"}
     else if ($mod.Regex("SamsungBrowser",A)) {
      Name = "Samsung Internet"}
     else if ($mod.Regex("Firefox\\/",A)) {
      Name = "Firefox"}
     else if ($mod.Regex("Chrome\\/",A)) {
      Name = "Chrome"}
     else if ($mod.Regex("Version\\/[\\d.]+.*Safari",A)) {
      Name = "Safari"}
     else Name = "";
    if ($mod.Regex("Android",A)) {
      System = "Android"}
     else if ($mod.Regex("iPhone|iPad|iPod",A)) {
      System = "iOS"}
     else if ($mod.Regex("Windows",A)) {
      System = "Windows"}
     else if ($mod.Regex("Mac OS X|Macintosh",A)) {
      System = "macOS"}
     else if ($mod.Regex("CrOS",A)) {
      System = "ChromeOS"}
     else if ($mod.Regex("Linux|X11",A)) {
      System = "Linux"}
     else System = "";
    if ((Name !== "") && (System !== "")) return window.t("%s on %s",Name,System);
    if (Name !== "") {
      Result = Name}
     else if (System !== "") {
      Result = System}
     else Result = A.slice(0,32);
    return Result;
  };
  this.HostOf = function (Url) {
    var Result = "";
    try {
      Result = (new URL(String(Url))).hostname.replace(new RegExp("^www\\."),"");
    } catch ($e) {
      Result = "";
    };
    return Result;
  };
  this.IsPagePath = function (Path) {
    var Result = false;
    var P = "";
    var I = 0;
    P = ("" + $mod.Either(Path,"/")).toLowerCase().split("?")[0];
    if ($mod.Regex("^\\/(static|api|images|files|f\\/|avatar|ws|sitemap|favicon|manifest)",P) || (P === "/robots.txt") || (P === "/words.js") || (P === "/sw.js")) return false;
    for (var $l = 0, $end = $mod.FilePaths.length - 1; $l <= $end; $l++) {
      I = $l;
      if (P.startsWith("" + $mod.FilePaths[I])) return false;
    };
    Result = !$mod.Regex("\\.(css|js|png|jpe?g|gif|svg|ico|webp|woff2?|xml|txt|json|map)$",P);
    return Result;
  };
  this.PageLink = function (Path) {
    var Result = null;
    var Shown = undefined;
    Path = $mod.Either(Path,"/");
    Shown = Path;
    try {
      Shown = decodeURIComponent("" + Path);
    } catch ($e) {
    };
    if (!$mod.Regex("^\\/(?!\\/)",Path)) return $mod.C.el("span","visit-path",Shown);
    Result = $mod.C.el("a","visit-path",Shown);
    Result["href"] = Path;
    Result["target"] = "_blank";
    Result["rel"] = "noopener";
    Result["title"] = Path;
    return Result;
  };
  this.ListView = function (Box, O) {
    var Result = null;
    var View = null;
    var Bar = null;
    var Scroller = null;
    var Table = null;
    var Thead = null;
    var Tbody = null;
    var Foot = null;
    var Count = null;
    var More = null;
    var Detail = null;
    var Head = null;
    var Find = null;
    var KeyOf = null;
    var TextOf = null;
    var Step = 0.0;
    var Limit = 0.0;
    var Page = 0.0;
    var Asked = 0.0;
    var Total = undefined;
    var Picked = undefined;
    var Trouble = undefined;
    var Rows = null;
    var Shown = null;
    var Selects = null;
    var Ths = null;
    var Columns = null;
    var Given = null;
    var Q = "";
    var Sort = "";
    var Loading = false;
    var Filters = null;
    var Saved = null;
    var Timer = 0;
    var Api = null;
    var I = 0;
    function ValueOf(Col, R) {
      var Result = undefined;
      if (Boolean(Col["value"])) {
        Result = Col.value(R)}
       else Result = R["" + Col["key"]];
      if ($mod.IsUndef(Result) || (Result == null)) Result = "";
      return Result;
    };
    function PlainSort() {
      var Result = "";
      Result = Sort.replace(new RegExp("^-"),"");
      return Result;
    };
    function Save() {
      if (Boolean(O["id"])) try {
        window.localStorage.setItem("lv-" + ("" + O["id"]),JSON.stringify(pas.JS.New(["sort",Sort])));
      } catch ($e) {
      };
    };
    function AddFind() {
      Find = $mod.C.el("input","lv-find");
      Find.type = "search";
      Find.placeholder = "" + $mod.Either(O["search"],window.t("Search"));
      Find.setAttribute("aria-label",Find.placeholder);
      Find.addEventListener("input",function (E) {
        var Wait = 0;
        window.clearTimeout(Timer);
        if (Boolean(O["remote"])) {
          Wait = 250}
         else Wait = 60;
        Timer = window.setTimeout(function () {
          Q = Find.value.trim();
          Refresh();
        },Wait);
      });
      Find.addEventListener("keydown",function (E) {
        if (E.key === "Enter") {
          E.preventDefault();
          if (Boolean(O["enter"])) O.enter(Find.value.trim());
        } else if ((E.key === "ArrowDown") && Boolean(Tbody.firstChild) && $mod.Same(Tbody.firstChild["tabIndex"],0)) {
          E.preventDefault();
          Tbody.firstChild.focus();
        };
      });
      Bar.appendChild(Find);
    };
    function AddFilter(F) {
      var Choice = null;
      Choice = $mod.C.el("select","lv-filter");
      Choice.setAttribute("aria-label","" + F["title"]);
      Choice.title = "" + F["title"];
      Filters["" + F["key"]] = $mod.Either(F["value"],"");
      Choice.addEventListener("change",function (E) {
        Filters["" + F["key"]] = Choice.value;
        $mod.Toggle(Choice,"on",Choice.value !== "");
        Save();
        Refresh();
      });
      Bar.appendChild(Choice);
      Selects.push(pas.JS.New(["f",F,"s",Choice]));
    };
    function FillSelects() {
      var N = 0;
      var M = 0;
      var F = null;
      var Choice = null;
      var Options = null;
      var Want = undefined;
      function Option(Value, Words) {
        var Result = null;
        Result = $mod.C.el("option","",Words);
        Result["value"] = Value;
        return Result;
      };
      for (var $l = 0, $end = Selects.length - 1; $l <= $end; $l++) {
        N = $l;
        F = Selects[N]["f"];
        Choice = Selects[N]["s"];
        if (typeof(F["options"]) === "function") {
          Options = F.options(Rows)}
         else Options = F["options"];
        Choice.replaceChildren(Option("",$mod.Either(F["all"],window.t("All"))));
        for (var $l1 = 0, $end1 = Options.length - 1; $l1 <= $end1; $l1++) {
          M = $l1;
          Choice.appendChild(Option(Options[M][0],Options[M][1]));
        };
        Want = $mod.Either(Filters["" + F["key"]],"");
        Choice["value"] = Want;
        if (!$mod.Same(Choice.value,Want)) Choice.value = "";
        $mod.Toggle(Choice,"on",Choice.value !== "");
      };
    };
    function AddCsv() {
      var Csv = null;
      function Cell(V) {
        var Result = "";
        Result = String(V);
        if ($mod.Regex("^[=+\\-@\\t\\r]",Result) && !$mod.Regex("^-?\\d+(\\.\\d+)?$",Result)) Result = "'" + Result;
        if ($mod.Regex('[",\\n]',Result)) Result = '"' + Result.replace(new RegExp('"',"g"),'""') + '"';
        return Result;
      };
      function Line(R, Titles) {
        var Result = "";
        var Cells = null;
        var N = 0;
        Cells = new Array();
        Columns = O["columns"];
        for (var $l = 0, $end = Columns.length - 1; $l <= $end; $l++) {
          N = $l;
          if (Titles) {
            Cells.push(Cell(Columns[N]["title"]))}
           else Cells.push(Cell(ValueOf(Columns[N],R)));
        };
        Result = Cells.join(",");
        return Result;
      };
      Csv = $mod.C.el("button","small-link lv-csv",window.t("Download CSV"));
      Csv["type"] = "button";
      Csv.addEventListener("click",function (E) {
        var Lines = null;
        var A = null;
        var N = 0;
        Lines = Array.of(Line(null,true));
        for (var $l = 0, $end = Shown.length - 1; $l <= $end; $l++) {
          N = $l;
          Lines.push(Line(Shown[N],false));
        };
        A = $mod.C.el("a");
        A.href = URL.createObjectURL(new Blob(Array.of(Lines.join("\n") + "\n"),pas.JS.New(["type","text/csv"])));
        A.download = "" + O["csv"] + ".csv";
        document.body.appendChild(A);
        A.click();
        A.remove();
        window.setTimeout(function () {
          URL.revokeObjectURL(A.href);
        },5000);
      });
      Bar.appendChild(Csv);
    };
    function AddHeading(Col) {
      var Th = null;
      var B = null;
      var Cls = "";
      Cls = "";
      if (Boolean(Col["num"])) Cls = "num";
      if (Boolean(Col["wide"])) Cls = Cls + " wide";
      Th = $mod.C.el("th",Cls);
      if (Boolean(Col["nosort"])) {
        Th["textContent"] = Col["title"]}
       else {
        B = $mod.C.el("button","lv-sort",Col["title"]);
        B["type"] = "button";
        B.addEventListener("click",function (E) {
          var Key = "";
          Key = "" + Col["key"];
          if ($mod.Same(Sort,Col["key"])) {
            Sort = "-" + Key}
           else if (Sort === ("-" + Key)) {
            Sort = Key}
           else if (Boolean(Col["num"]) || Boolean(Col["down"])) {
            Sort = "-" + Key}
           else Sort = Key;
          Save();
          Refresh();
        });
        Th.appendChild(B);
      };
      Ths.push(Th);
      Head.appendChild(Th);
    };
    function MarkSort() {
      var N = 0;
      var Here = false;
      var Down = false;
      var Th = null;
      Columns = O["columns"];
      for (var $l = 0, $end = Columns.length - 1; $l <= $end; $l++) {
        N = $l;
        Here = $mod.Same(PlainSort(),Columns[N]["key"]);
        Down = Sort.charAt(0) === "-";
        Th = Ths[N];
        $mod.Toggle(Th,"sorted",Here);
        $mod.Toggle(Th,"down",Here && Down);
        if (Here) {
          if (Down) {
            Th.setAttribute("aria-sort","descending")}
           else Th.setAttribute("aria-sort","ascending");
        } else Th.removeAttribute("aria-sort");
      };
    };
    function Blank(V) {
      var Result = false;
      Result = $mod.Same(V,"") || (V == null) || $mod.IsUndef(V);
      return Result;
    };
    function Compare(A, B) {
      var Result = 0.0;
      if ((typeof(A) === "number") && (typeof(B) === "number")) return rtl.getNumber(A) - rtl.getNumber(B);
      if ((typeof(A) === "boolean") || (typeof(B) === "boolean")) return Number(A) - Number(B);
      Result = String(A).localeCompare(String(B),$mod.Locale,pas.JS.New(["numeric",true,"sensitivity","base"]));
      return Result;
    };
    function Local() {
      var Words = "";
      var List = null;
      var N = 0;
      var M = 0;
      var R = undefined;
      var V = undefined;
      var Keep = false;
      var Col = null;
      var Dir = 0.0;
      Words = Q.toLowerCase();
      List = new Array();
      for (var $l = 0, $end = Rows.length - 1; $l <= $end; $l++) {
        N = $l;
        R = Rows[N];
        Keep = true;
        for (var $l1 = 0, $end1 = Selects.length - 1; $l1 <= $end1; $l1++) {
          M = $l1;
          V = Selects[M]["s"]["value"];
          if (Boolean(V) && !Boolean(Selects[M]["f"].test(R,V))) {
            Keep = false;
            break;
          };
        };
        if (Keep && ((Words === "") || (TextOf(R).toLowerCase().indexOf(Words,0) >= 0))) List.push(R);
      };
      Col = null;
      Columns = O["columns"];
      for (var $l2 = 0, $end2 = Columns.length - 1; $l2 <= $end2; $l2++) {
        N = $l2;
        if (!Boolean(Columns[N]["nosort"]) && $mod.Same(Columns[N]["key"],PlainSort())) {
          Col = Columns[N];
          break;
        };
      };
      if (Col !== null) {
        if (Sort.charAt(0) === "-") {
          Dir = -1}
         else Dir = 1;
        $mod.SortBy(List,function (X, Y) {
          var Result = 0.0;
          var A = undefined;
          var B = undefined;
          A = ValueOf(Col,X);
          B = ValueOf(Col,Y);
          if (Blank(A) || Blank(B)) return Number(Blank(A)) - Number(Blank(B));
          Result = Dir * Compare(A,B);
          return Result;
        });
      };
      Shown = List;
      Total = Rows.length;
    };
    function RowOf(R) {
      var Result = null;
      var Tr = null;
      var Td = null;
      var Col = null;
      var Cls = "";
      var V = undefined;
      var N = 0;
      Tr = $mod.C.el("tr");
      Tr["row"] = R;
      if (Boolean(O["rowClass"])) {
        V = O.rowClass(R);
        if (Boolean(V)) Tr["className"] = V;
      };
      Columns = O["columns"];
      for (var $l = 0, $end = Columns.length - 1; $l <= $end; $l++) {
        N = $l;
        Col = Columns[N];
        Cls = "";
        if (Boolean(Col["num"])) Cls = "num";
        if (Boolean(Col["wide"])) Cls = Cls + " wide";
        if (Boolean(Col["cls"])) Cls = Cls + " " + ("" + Col["cls"]);
        Td = $mod.C.el("td",Cls);
        if (Boolean(Col["cell"])) {
          V = Col.cell(R)}
         else V = ValueOf(Col,R);
        if (Boolean(V) && (typeof(V) === "object")) {
          Td.appendChild(V)}
         else if (typeof(V) === "number") {
          Td.textContent = $mod.LocaleNumber(V)}
         else if ($mod.IsUndef(V) || (V == null)) {
          Td.textContent = String("")}
         else Td.textContent = String(V);
        Tr.appendChild(Td);
      };
      if (Boolean(O["detail"])) {
        Tr.tabIndex = 0;
        if (Boolean(Picked) && $mod.Same(KeyOf(Picked),KeyOf(R))) Tr.classList.add("on");
        Tr.addEventListener("click",function (E) {
          if (Boolean(E.target.closest("a, button, input, select, label, textarea"))) return;
          Pick(R,Tr,false);
        });
        Tr.addEventListener("keydown",function (E) {
          var Key = "";
          var Goal = null;
          Key = E.key;
          if (Key === "ArrowDown") {
            Goal = Tr.nextElementSibling}
           else if (Key === "ArrowUp") {
            Goal = Tr.previousElementSibling}
           else Goal = null;
          if (Boolean(Goal) && Boolean(Goal["row"])) {
            E.preventDefault();
            Goal.focus();
            Pick(Goal["row"],Goal,true);
          } else if ((Key === "ArrowUp") && Boolean(Find)) {
            E.preventDefault();
            Find.focus();
          } else if ((Key === "Enter") || (Key === " ")) {
            E.preventDefault();
            Pick(R,Tr,false);
          } else if (Key === "Escape") Unpick();
        });
      };
      Result = Tr;
      return Result;
    };
    function Draw() {
      var List = null;
      var Tr = null;
      var Td = null;
      var All = undefined;
      var N = 0;
      Tbody.replaceChildren();
      if (Boolean(O["remote"])) {
        List = Shown}
       else List = Shown.slice(0,pas.System.Trunc(Limit));
      for (var $l = 0, $end = List.length - 1; $l <= $end; $l++) {
        N = $l;
        Tbody.appendChild(RowOf(List[N]));
      };
      $mod.Toggle(View,"lv-busy",Loading && (List.length > 0));
      Columns = O["columns"];
      if ((List.length === 0) && (Loading || Boolean(Trouble))) {
        if (Boolean(Trouble)) {
          Tr = $mod.C.el("tr","lv-none lv-trouble")}
         else Tr = $mod.C.el("tr","lv-none lv-loading");
        Td = $mod.C.el("td");
        if (Boolean(Trouble)) {
          Td["textContent"] = Trouble}
         else Td.append($mod.C.el("span","lv-spinner")," " + window.t("Loading…"));
        Td["colSpan"] = Columns.length;
        Tr.appendChild(Td);
        Tbody.appendChild(Tr);
        Count.textContent = "";
        More.hidden = true;
        return;
      };
      if (List.length === 0) {
        Tr = $mod.C.el("tr","lv-none");
        if ((Rows.length === 0) && !Boolean(O["remote"])) {
          Td = $mod.C.el("td","",$mod.Either(O["empty"],window.t("Nothing here yet.")))}
         else Td = $mod.C.el("td","",window.t("Nothing matches."));
        Td["colSpan"] = Columns.length;
        Tr.appendChild(Td);
        Tbody.appendChild(Tr);
      };
      if (Boolean(O["remote"])) {
        All = Total}
       else All = Rows.length;
      if (List.length < Number(All)) {
        Count["textContent"] = window.t("%d of %d shown",List.length,All)}
       else if (Boolean(O["noun"])) {
        Count["textContent"] = O.noun(All)}
       else Count["textContent"] = window.tn(All,"%d row","%d rows");
      if (Loading) Count.textContent = Count.textContent + " · " + window.t("Loading…");
      if (Boolean(O["remote"])) {
        More.hidden = Shown.length >= Number(Total)}
       else More.hidden = Shown.length <= Limit;
    };
    async function MoreClick(E) {
      var Mine = 0.0;
      var Next = 0.0;
      var A = null;
      if (!Boolean(O["remote"])) {
        Limit = Limit + Step;
        Draw();
        return;
      };
      Mine = Asked;
      Next = Page + 1;
      More["disabled"] = true;
      More.textContent = window.t("Loading…");
      try {
        try {
          A = await O.remote(pas.JS.New(["q",Q,"filters",Filters,"sort",Sort,"page",Next]));
        } catch ($e) {
          $mod.C.failed($e);
          return;
        };
      } finally {
        More["disabled"] = false;
        More.textContent = window.t("Show more");
      };
      if (Mine !== Asked) return;
      Page = Next;
      Shown = Shown.concat(A["rows"]);
      Total = A["total"];
      Draw();
    };
    function FreshOf(K) {
      var Result = undefined;
      var N = 0;
      for (var $l = 0, $end = Rows.length - 1; $l <= $end; $l++) {
        N = $l;
        if ($mod.Same(KeyOf(Rows[N]),K)) return Rows[N];
      };
      Result = undefined;
      return Result;
    };
    async function Refresh() {
      var Result = undefined;
      var Mine = 0.0;
      var A = null;
      if (Boolean(O["remote"])) {
        Page = 0;
        Asked = Asked + 1;
        Mine = Asked;
        Loading = true;
        Trouble = "";
        MarkSort();
        Draw();
        try {
          A = await O.remote(pas.JS.New(["q",Q,"filters",Filters,"sort",Sort,"page",0]));
        } catch ($e) {
          if (Mine !== Asked) return Result;
          Loading = false;
          Trouble = $mod.Either($e["message"],window.t("The list could not be read."));
          Shown = new Array();
          Draw();
          return Result;
        };
        if (Mine !== Asked) return Result;
        Loading = false;
        Rows = A["rows"];
        Shown = Rows;
        Total = A["total"];
        if (Boolean(Picked)) {
          Picked = $mod.Either(FreshOf(KeyOf(Picked)),null);
          MarkSort();
          Draw();
          ShowDetail();
          return Result;
        };
      } else {
        Limit = Step;
        Local();
      };
      MarkSort();
      Draw();
      return Result;
    };
    function ShowDetail() {
      var Close = null;
      var Inner = null;
      Detail.replaceChildren();
      if (!Boolean(Picked)) {
        Detail.hidden = true;
        return;
      };
      Detail.hidden = false;
      Close = $mod.C.el("button","lv-close","×");
      Close["type"] = "button";
      Close.title = window.t("Close");
      Close.setAttribute("aria-label",window.t("Close"));
      Close.addEventListener("click",Unpick);
      Inner = $mod.C.el("div","lv-detail-body");
      Detail.append(Close,Inner);
      O.detail(Picked,Inner,Api);
    };
    function MarkRows(Tr, ByKey, R) {
      var Lines = null;
      var N = 0;
      var X = null;
      Lines = Array.from(Tbody.children);
      for (var $l = 0, $end = Lines.length - 1; $l <= $end; $l++) {
        N = $l;
        X = Lines[N];
        if (ByKey) {
          $mod.Toggle(X,"on",Boolean(X["row"]) && $mod.Same(KeyOf(X["row"]),KeyOf(R)))}
         else $mod.Toggle(X,"on",X == Tr);
      };
    };
    function Pick(R, Tr, KeepFocus) {
      var Top = 0.0;
      var High = 0.0;
      Picked = R;
      MarkRows(Tr,false,null);
      ShowDetail();
      if (!KeepFocus && Boolean(Detail["getBoundingClientRect"])) {
        Top = Detail.getBoundingClientRect().top;
        High = rtl.getNumber($mod.Either(window.innerHeight,800));
        if (Top > (High - 120)) Detail.scrollIntoView(pas.JS.New(["block","nearest","behavior","smooth"]));
      };
    };
    function Unpick() {
      var Lines = null;
      var N = 0;
      Picked = null;
      Lines = Array.from(Tbody.children);
      for (var $l = 0, $end = Lines.length - 1; $l <= $end; $l++) {
        N = $l;
        Lines[N].classList.remove("on");
      };
      ShowDetail();
    };
    function SetRows(List) {
      Rows = List;
      Loading = false;
      Trouble = "";
      if (Boolean(Picked)) Picked = $mod.Either(FreshOf(KeyOf(Picked)),null);
      FillSelects();
      Refresh();
      ShowDetail();
    };
    function Reload() {
      var Result = undefined;
      Result = Refresh();
      return Result;
    };
    function SetLoading() {
      Loading = true;
      Trouble = "";
      Draw();
    };
    function SetFailed(Words) {
      Loading = false;
      Trouble = $mod.Either(Words,window.t("The list could not be read."));
      Rows = new Array();
      Shown = Rows;
      Draw();
    };
    function Changed(R) {
      var Lines = null;
      var N = 0;
      var Tr = null;
      var Fresh = null;
      Lines = Array.from(Tbody.children);
      for (var $l = 0, $end = Lines.length - 1; $l <= $end; $l++) {
        N = $l;
        Tr = Lines[N];
        if (Boolean(Tr["row"]) && $mod.Same(KeyOf(Tr["row"]),KeyOf(R))) {
          Fresh = RowOf(R);
          if (Tr.classList.contains("on")) Fresh.classList.add("on");
          Tr.replaceWith(Fresh);
        };
      };
      if (Boolean(Picked) && $mod.Same(KeyOf(Picked),KeyOf(R))) {
        Picked = R;
        ShowDetail();
      };
    };
    function PickBy(Match) {
      var Result = false;
      var R = undefined;
      if (Boolean(O["remote"])) {
        R = $mod.FindIn(Shown,Match)}
       else R = $mod.FindIn(Rows,Match);
      if (!Boolean(R)) return false;
      Picked = R;
      Draw();
      ShowDetail();
      Result = true;
      return Result;
    };
    function Show(R) {
      Picked = R;
      MarkRows(null,true,R);
      ShowDetail();
    };
    function Search(Words) {
      if (Boolean(Find)) {
        Find.value = Words;
        Q = Words;
        Refresh();
      };
    };
    function GiveRows() {
      var Result = null;
      Result = Rows;
      return Result;
    };
    if (Boolean(O["cls"])) {
      View = $mod.C.el("div","listview " + ("" + O["cls"]))}
     else View = $mod.C.el("div","listview");
    Bar = $mod.C.el("div","lv-bar");
    Scroller = $mod.C.el("div","lv-scroll");
    Table = $mod.C.el("table","lv-table");
    Thead = $mod.C.el("thead");
    Tbody = $mod.C.el("tbody");
    Table.append(Thead,Tbody);
    Scroller.appendChild(Table);
    Foot = $mod.C.el("div","lv-foot");
    Count = $mod.C.el("span","lv-count");
    More = $mod.C.el("button","small-link",window.t("Show more"));
    More["type"] = "button";
    More.hidden = true;
    Foot.append(Count,More);
    Detail = $mod.C.el("div","lv-detail");
    Detail.hidden = true;
    View.append(Bar,Scroller,Foot,Detail);
    Box.appendChild(View);
    if (Boolean(O["key"])) {
      KeyOf = O["key"]}
     else KeyOf = function (R) {
      var Result = undefined;
      Result = JSON.stringify(R);
      return Result;
    };
    if (Boolean(O["text"])) {
      TextOf = O["text"]}
     else TextOf = function (R) {
      var Result = undefined;
      var Words = null;
      var N = 0;
      Words = new Array();
      Columns = O["columns"];
      for (var $l = 0, $end = Columns.length - 1; $l <= $end; $l++) {
        N = $l;
        Words.push(String(ValueOf(Columns[N],R)));
      };
      Result = Words.join(" ");
      return Result;
    };
    Step = rtl.getNumber($mod.Either(O["page"],100));
    Rows = $mod.Either(O["rows"],new Array());
    Shown = new Array();
    Total = 0;
    Limit = Step;
    Page = 0;
    Picked = null;
    Q = "";
    Asked = 0;
    Loading = Boolean(O["remote"]) || $mod.IsUndef(O["rows"]);
    Trouble = "";
    Sort = "" + $mod.Either(O["sort"],"");
    Filters = new Object();
    Saved = new Object();
    try {
      if (Boolean(O["id"])) Saved = JSON.parse("" + $mod.Either(window.localStorage.getItem("lv-" + ("" + O["id"])),"{}"));
    } catch ($e) {
    };
    Columns = O["columns"];
    if (Boolean(Saved["sort"])) for (var $l = 0, $end = Columns.length - 1; $l <= $end; $l++) {
      I = $l;
      if (!Boolean(Columns[I]["nosort"]) && $mod.Same(Columns[I]["key"],Saved["sort"].replace(new RegExp("^-"),""))) {
        Sort = "" + Saved["sort"];
        break;
      };
    };
    Find = null;
    Timer = 0;
    if (!$mod.Same(O["search"],false)) AddFind();
    Selects = new Array();
    Given = $mod.Either(O["filters"],new Array());
    for (var $l1 = 0, $end1 = Given.length - 1; $l1 <= $end1; $l1++) {
      I = $l1;
      AddFilter(Given[I]);
    };
    if (Boolean(O["csv"])) AddCsv();
    if (Bar.children.length === 0) Bar.hidden = true;
    Head = $mod.C.el("tr");
    Ths = new Array();
    for (var $l2 = 0, $end2 = Columns.length - 1; $l2 <= $end2; $l2++) {
      I = $l2;
      AddHeading(Columns[I]);
    };
    Thead.appendChild(Head);
    More.addEventListener("click",MoreClick);
    Api = pas.JS.New(["set",SetRows,"reload",Reload,"loading",SetLoading,"failed",SetFailed,"changed",Changed,"pick",PickBy,"show",Show,"unpick",Unpick,"search",Search,"rows",GiveRows,"element",View]);
    FillSelects();
    Refresh();
    Result = Api;
    return Result;
  };
  this.StrikeKinds = function () {
    var Result = null;
    Result = Object.assign(pas.JS.New(["g-miss",window.t("missing pages"),"g-password",window.t("wrong passwords or tokens"),"g-admin",window.t("admin pages probed"),"signin",window.t("sign-in tries"),"signup",window.t("sign-up tries"),"token",window.t("token tries"),"authtry",window.t("sign-in requests"),"wikilist",window.t("wiki lists"),"search",window.t("searches")]),$mod.Either($mod.Extras["strikeKinds"],new Object()));
    return Result;
  };
  this.SectionOf = function (Path) {
    var Result = "";
    var First = "";
    First = ("" + $mod.Either(("" + $mod.Either(Path,"/")).split("?")[0].split("/")[1],"")).split("-")[0];
    if (First !== "") {
      Result = "/" + First}
     else Result = "/";
    return Result;
  };
  this.SectionOptions = function (Paths) {
    var Result = null;
    var Seen = null;
    var Section = "";
    var I = 0;
    Seen = new Map();
    for (var $l = 0, $end = Paths.length - 1; $l <= $end; $l++) {
      I = $l;
      Section = $mod.SectionOf(Paths[I]);
      Seen.set(Section,rtl.getNumber($mod.Either(Seen.get(Section),0)) + 1);
    };
    Result = $impl.ByCount(Seen);
    return Result;
  };
  this.LookUpAddress = function (Ip) {
    if (Boolean($mod.S["adminTab"])) $mod.S.adminTab("Visitors");
    if (Boolean($mod.S["showAddress"])) $mod.S.showAddress(Ip);
  };
  this.AddressCell = function (Ip) {
    var Result = null;
    Result = $mod.AddressCell$1(Ip,undefined);
    return Result;
  };
  this.AddressCell$1 = function (Ip, Flagged) {
    var Result = null;
    var B = null;
    var Mark = null;
    B = $mod.C.el("button","lv-ip lv-link",Ip);
    B["type"] = "button";
    B.title = window.t("Everything about this address");
    B.addEventListener("click",function (E) {
      $mod.LookUpAddress(Ip);
    });
    if (!Boolean(Flagged)) return B;
    Result = $mod.C.el("span","lv-flag");
    Mark = $mod.C.chip("!","bad");
    Mark.title = window.t("Of concern: see the Of concern tab");
    Result.append(B," ",Mark);
    return Result;
  };
  this.Stamp = function (At) {
    var Result = undefined;
    var D = null;
    D = new Date(At);
    if (isNaN(D)) return $mod.Either(At,"");
    if (D.toDateString() === (new Date()).toDateString()) {
      Result = $mod.C.clock(At)}
     else Result = window.dateTimeText(At);
    return Result;
  };
  this.OutLink = function (Url) {
    var Result = null;
    if (!(new RegExp("^https?:\\/\\/","i")).test(String(Url))) return $mod.C.el("span","visit-path",Url);
    Result = $mod.C.el("a","visit-path",Url);
    Result["href"] = Url;
    Result["target"] = "_blank";
    Result["rel"] = "noopener noreferrer";
    return Result;
  };
  this.LookButton = function (Ip) {
    var Result = null;
    Result = $mod.C.el("button","",window.t("Everything about this address"));
    Result["type"] = "button";
    Result.title = window.t("Its whole story in the period, the guard's facts included, under Address");
    Result.addEventListener("click",function (E) {
      $mod.LookUpAddress(Ip);
    });
    return Result;
  };
  this.ReasonWords = function (X) {
    var Result = undefined;
    var N = undefined;
    var Kind = "";
    N = $mod.Either(X["n"],0);
    Kind = String(X["kind"]);
    if (!$mod.Same(Kind,X["kind"])) return X["kind"];
    if (Kind === "rate") {
      Result = window.tn(N,"%d request in one minute","%d requests in one minute");
      if (Boolean(X["text"])) Result = "" + Result + " (" + ("" + $mod.Stamp(X["text"])) + ")";
    } else if (Kind === "requests") {
      Result = window.tn(N,"%d request","%d requests")}
     else if (Kind === "browser-crawl") {
      Result = window.t("a browser that read %s pages",$mod.LocaleNumber(N))}
     else if (Kind === "agents") {
      Result = window.tn(N,"%d browser string","%d browser strings")}
     else if (Kind === "pretender") {
      Result = window.t("names %s’s crawler from outside its addresses",X["text"])}
     else if (Kind === "fake") {
      Result = window.t("claims to be %s; its DNS says no",X["text"])}
     else if (Kind === "missing") {
      Result = window.tn(N,"%d page that is not here","%d pages that are not here")}
     else if (Kind === "probes") {
      Result = window.tn(N,"%d scanner path probed","%d scanner paths probed")}
     else if (Kind === "refused") {
      Result = window.tn(N,"turned away %d time","turned away %d times")}
     else if (Kind === "errors") {
      Result = window.tn(N,"%d server error","%d server errors")}
     else if (Kind === "members") {
      Result = window.tn(N,"signed in as %d member","signed in as %d members")}
     else Result = X["kind"];
    return Result;
  };
  this.ReasonKinds = function () {
    var Result = null;
    Result = pas.JS.New(["rate",window.t("Pace"),"requests",window.t("Many requests"),"browser-crawl",window.t("A browser crawling"),"agents",window.t("Browser strings"),"pretender",window.t("Pretending to be a crawler"),"fake",window.t("Failed its DNS check"),"missing",window.t("Missing pages"),"probes",window.t("Probing"),"refused",window.t("Turned away"),"errors",window.t("Server errors"),"members",window.t("Many members")]);
    return Result;
  };
  this.StatusCell = function (Code) {
    var Result = null;
    if (!Boolean(Code)) return $mod.C.el("span","dim","–");
    if (Number(Code) >= 500) {
      Result = $mod.C.chip(String(Code),"bad")}
     else if (Number(Code) >= 400) {
      Result = $mod.C.chip(String(Code),"open")}
     else Result = $mod.C.chip(String(Code),"");
    return Result;
  };
  this.MsCell = function (Ms) {
    var Result = undefined;
    var Cls = "";
    var Words = "";
    if ($mod.IsUndef(Ms) || (Ms == null)) return "";
    if (Number(Ms) >= 2000) {
      Cls = "bot-bad"}
     else Cls = "dim";
    if (Number(Ms) >= 1000) {
      Words = $mod.Fixed(Number(Ms) / 1000,1) + " s"}
     else Words = "" + Ms + " ms";
    Result = $mod.C.el("span",Cls,Words);
    return Result;
  };
  this.PartLabel = function (Part) {
    var Result = undefined;
    var Name = "";
    Name = "" + Part;
    Result = $mod.Either($mod.Extras["places"][Name],pas.JS.New(["chat",window.t("Chat"),"api",window.t("API"),"static",window.t("Static"),"other",window.t("Other")])[Name]);
    if (!Boolean(Result)) Result = Part.charAt(0).toUpperCase() + Part.slice(1);
    return Result;
  };
  this.PlaceName = function (Where) {
    var Result = undefined;
    if ($mod.Same(Where,"chat")) {
      Result = window.t("Chat")}
     else Result = $mod.Either($mod.Extras["places"]["" + Where],Where);
    return Result;
  };
  this.WindowName = function (R) {
    var Result = "";
    Result = String($mod.Either(R["from"],"")).slice(0,10) + "-" + String($mod.Either(R["to"],"")).slice(0,10);
    return Result;
  };
  $mod.$implcode = function () {
    $impl.ByCount = function (Seen) {
      var Result = null;
      var Pairs = null;
      var I = 0;
      Pairs = $mod.SortBy(Array.from(Seen),function (A, B) {
        var Result = 0.0;
        Result = rtl.getNumber(B[1]) - rtl.getNumber(A[1]);
        return Result;
      });
      Result = new Array();
      for (var $l = 0, $end = Pairs.length - 1; $l <= $end; $l++) {
        I = $l;
        Result.push(Array.of(Pairs[I][0],"" + Pairs[I][0] + " (" + ("" + Pairs[I][1]) + ")"));
      };
      return Result;
    };
  };
  $mod.$init = function () {
    $mod.C = window["Chat"];
    $mod.SiteName = $mod.C["Site"];
    $mod.Me = $mod.C["me"];
    $mod.S = $mod.C["state"];
    $mod.Extras = $mod.C["extras"];
    $mod.Locale = $mod.C["locale"];
    $mod.Stream = $mod.C["stream"];
    $mod.FilePaths = new Array();
  };
},[]);
rtl.module("Admin_Address",["System","JS","Web","Admin_List"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  this.TimelineChart = function (Box, Tl, Compact) {
    var Step = 0.0;
    var Start = 0.0;
    var Most = 0.0;
    var Total = 0.0;
    var Sum = 0.0;
    var N = 0;
    var I = 0;
    var J = 0;
    var K = 0;
    var StepWords = "";
    var Rows = null;
    var Series = null;
    var Ser = null;
    var Words = null;
    var Row = null;
    var Wrap = null;
    var Head = null;
    var Columns = null;
    var Col = null;
    var Seg = null;
    var Cap = null;
    var V = undefined;
    var Any = false;
    function Iso(Ms) {
      var Result = "";
      Result = (new Date(Ms)).toISOString();
      return Result;
    };
    function When(Bar) {
      var Result = "";
      var A = 0.0;
      var B = 0.0;
      A = Start + (Bar * Step * 1000);
      B = (A + (Step * 1000)) - 1000;
      if (Step >= 86400) return window.dateText(Iso(A).slice(0,10));
      if (Step >= 7200) {
        Result = window.dateTimeText(Iso(A))}
       else Result = "" + pas.Admin_List.Stamp(Iso(A));
      Result = Result + " – " + ("" + pas.Admin_List.C.clock(Iso(B)));
      return Result;
    };
    function CountOf(One, Bar) {
      var Result = undefined;
      Result = pas.Admin_List.Either(pas.Admin_List.Either(One[0],new Array())[Bar],0);
      return Result;
    };
    if (!Boolean(Tl) || !Boolean(Tl["pages"]) || !Boolean(Tl["pages"].length)) return;
    Step = Number(Tl["step"]);
    Start = (new Date(Tl["start"])).getTime();
    N = Tl["pages"].length;
    if (Step < 3600) {
      StepWords = window.tn(Step / 60,"a bar a minute","a bar every %d minutes")}
     else if (Step < 86400) {
      StepWords = window.tn(Step / 3600,"a bar an hour","a bar every %d hours")}
     else StepWords = window.tn(Step / 86400,"a bar a day","a bar every %d days");
    Rows = Array.of(pas.JS.New(["title",window.t("Pages people read, and the rest they asked for"),"series",Array.of(Array.of(Tl["pages"],"tl-pages",window.t("pages")),Array.of(Tl["other"],"tl-other",window.t("other requests")))]),pas.JS.New(["title",window.t("Bot requests"),"series",Array.of(Array.of(Tl["bots"],"tl-bots",window.t("bot requests")))]),pas.JS.New(["title",window.t("Refused, not here, or failed"),"series",Array.of(Array.of(Tl["errors"],"tl-errors",window.t("errors")))]));
    if (Compact) {
      Wrap = pas.Admin_List.C.el("div","timeline compact")}
     else Wrap = pas.Admin_List.C.el("div","timeline");
    for (var $l = 0, $end = Rows.length - 1; $l <= $end; $l++) {
      I = $l;
      Row = Rows[I];
      Series = Row["series"];
      Any = false;
      for (var $l1 = 0, $end1 = Series.length - 1; $l1 <= $end1; $l1++) {
        J = $l1;
        Ser = Series[J];
        if (Boolean(Ser[0])) for (var $l2 = 0, $end2 = Ser[0].length - 1; $l2 <= $end2; $l2++) {
          K = $l2;
          if (Boolean(Ser[0][K])) Any = true;
        };
      };
      if (!Any) continue;
      Most = 1;
      Total = 0;
      for (var $l3 = 0, $end3 = N - 1; $l3 <= $end3; $l3++) {
        K = $l3;
        Sum = 0;
        for (var $l4 = 0, $end4 = Series.length - 1; $l4 <= $end4; $l4++) {
          J = $l4;
          Sum = Sum + Number(CountOf(Series[J],K));
        };
        if (Sum > Most) Most = Sum;
        Total = Total + Sum;
      };
      Head = pas.Admin_List.C.el("div","tl-head");
      Head.append(pas.Admin_List.C.el("span","",Row["title"]),pas.Admin_List.C.el("span","num",pas.Admin_List.LocaleNumber(Total)));
      Wrap.appendChild(Head);
      Columns = pas.Admin_List.C.el("div","days tl-row");
      for (var $l5 = 0, $end5 = N - 1; $l5 <= $end5; $l5++) {
        K = $l5;
        Col = pas.Admin_List.C.el("b");
        Words = new Array();
        for (var $l6 = 0, $end6 = Series.length - 1; $l6 <= $end6; $l6++) {
          J = $l6;
          Ser = Series[J];
          V = CountOf(Ser,K);
          Seg = pas.Admin_List.C.el("i",Ser[1]);
          Seg.style["height"] = String(Math.round((60 * Number(V)) / Most)) + "px";
          Col.appendChild(Seg);
          Words.push(pas.Admin_List.LocaleNumber(V) + " " + ("" + Ser[2]));
        };
        Col.title = When(K) + ": " + Words.join(", ");
        Columns.appendChild(Col);
      };
      Wrap.appendChild(Columns);
    };
    Cap = pas.Admin_List.C.el("div","days-caption");
    Cap.append(pas.Admin_List.C.el("span","",window.dateTimeText(Tl["start"])),pas.Admin_List.C.el("span","",StepWords),pas.Admin_List.C.el("span","",window.dateTimeText(Iso((Start + (N * Step * 1000)) - 1000))));
    Wrap.appendChild(Cap);
    Box.appendChild(Wrap);
  };
  this.AddressPanel = function (Ip, Holder, Period) {
    var Win = null;
    function Again() {
      $mod.AddressPanel(Ip,Holder,Period);
    };
    function Draw(R) {
      var A = null;
      var G = null;
      var Ab = null;
      var X = null;
      var M = null;
      var Head = null;
      var Look = null;
      var Tiles = null;
      var P = null;
      var List = null;
      var Li = null;
      var Acts = null;
      var Two = null;
      var Left = null;
      var Right = null;
      var Ul = null;
      var A2 = null;
      var Lookups = null;
      var Rows = null;
      var Codes = null;
      var Parts = null;
      var Strikes = null;
      var Shown = null;
      var Names = null;
      var Kinds2 = null;
      var CrawlerText = "";
      var Words = "";
      var Cls = "";
      var Code = "";
      var Note = undefined;
      var I = 0;
      function Mark(Fits) {
        var Result = "";
        if (Fits) {
          Result = "warn"}
         else Result = "";
        return Result;
      };
      function AgentName(Row) {
        var Result = undefined;
        Result = pas.Admin_List.Either(Row["bot"],pas.Admin_List.BrowserOf(Row["agent"]));
        return Result;
      };
      Holder.replaceChildren();
      A = R["address"];
      G = R["guard"];
      Head = pas.Admin_List.C.el("div","lv-detail-head");
      Head.appendChild(pas.Admin_List.C.el("b","",R["ip"]));
      if (Boolean(G) && Boolean(G["host"])) Head.appendChild(pas.Admin_List.C.el("span","dim",G["host"]));
      Look = pas.Admin_List.C.el("span","ip-lookups");
      Lookups = Array.of(Array.of("AbuseIPDB","https://www.abuseipdb.com/check/",window.t("Abuse reports about this address")),Array.of("GreyNoise","https://viz.greynoise.io/ip/",window.t("Whether it scans the whole internet")),Array.of("ipinfo","https://ipinfo.io/",window.t("Who the address belongs to")));
      for (var $l = 0, $end = Lookups.length - 1; $l <= $end; $l++) {
        I = $l;
        A2 = pas.Admin_List.C.link("" + Lookups[I][1] + pas.Admin_List.C.enc(R["ip"]),"",Lookups[I][0]);
        A2.target = "_blank";
        A2["rel"] = "noopener noreferrer";
        A2["title"] = Lookups[I][2];
        Look.appendChild(A2);
      };
      Head.appendChild(Look);
      if (Boolean(A["crawler"])) {
        CrawlerText = "" + A["crawler"];
        if (Boolean(A["company"])) CrawlerText = CrawlerText + " · " + ("" + A["company"]);
      } else if (Boolean(G) && Boolean(G["crawler_name"])) {
        CrawlerText = "" + G["crawler_name"];
        if (Boolean(G["company"])) CrawlerText = CrawlerText + " · " + ("" + G["company"]);
      } else if (Boolean(G) && Boolean(G["crawler"])) {
        CrawlerText = window.t("a search engine’s crawler")}
       else CrawlerText = "";
      if (CrawlerText !== "") {
        Head.appendChild(pas.Admin_List.C.chip(CrawlerText,"admin"))}
       else if (Boolean(A["bot"])) Head.appendChild(pas.Admin_List.C.chip(A["bot"],""));
      if (Boolean(G) && Boolean(G["local"])) {
        Head.appendChild(pas.Admin_List.C.chip(window.t("This network"),"admin"))}
       else if (Boolean(G) && Boolean(G["allowed"])) Head.appendChild(pas.Admin_List.C.chip(window.t("Allowed"),"admin"));
      if (Boolean(G) && Boolean(G["block"]) && Boolean(G["block"]["active"])) {
        if (Boolean(G["block"]["for_good"])) {
          Head.appendChild(pas.Admin_List.C.chip(window.t("Blocked for good"),"bad"))}
         else Head.appendChild(pas.Admin_List.C.chip(window.t("Blocked now"),"bad"));
      };
      if (Number(A["score"]) > 0) Head.appendChild(pas.Admin_List.C.chip(window.t("Of concern"),"open"));
      Holder.appendChild(Head);
      if (!Boolean(A["requests"])) {
        if (Boolean(pas.Admin_List.S["adminCan"]) && pas.Admin_List.S.adminCan("view-visitors")) {
          Holder.appendChild(pas.Admin_List.C.el("p","dim",window.t("Nothing from this address in the period.")))}
         else Holder.appendChild(pas.Admin_List.C.el("p","dim",window.t("The log is for those who may view visitors.")));
      } else {
        Tiles = pas.Admin_List.C.el("div","tiles-admin");
        pas.Admin_List.Stat(Tiles,A["requests"],window.t("Requests"),window.t("%s to %s",pas.Admin_List.Stamp(A["first"]),pas.Admin_List.Stamp(A["last"])),undefined);
        pas.Admin_List.Stat(Tiles,A["pages"],window.t("Pages"),undefined,undefined);
        if (Boolean(A["polls"])) pas.Admin_List.Stat(Tiles,A["polls"],window.t("Open tab checks"),window.t("a tab left open, asking what is new"),undefined);
        if (Boolean(A["peak_at"])) {
          Note = pas.Admin_List.Stamp(A["peak_at"])}
         else Note = "";
        pas.Admin_List.Stat(Tiles,A["peak"],window.t("Busiest minute"),Note,Mark((Number(A["peak"]) >= 120) && !Boolean(A["crawler"])));
        pas.Admin_List.Stat(Tiles,A["agents"],window.t("Browser strings"),"",Mark((Number(A["agents"]) >= 5) && !Boolean(A["crawler"])));
        if (Boolean(A["probes"])) {
          Note = window.tn(A["probes"],"%d scanner path","%d scanner paths")}
         else Note = "";
        pas.Admin_List.Stat(Tiles,A["missing"],window.t("Not here (404)"),Note,Mark((Number(A["missing"]) >= 30) || Boolean(A["probes"])));
        if (Boolean(A["errors"])) {
          Note = window.tn(A["errors"],"%d server error","%d server errors")}
         else Note = "";
        pas.Admin_List.Stat(Tiles,A["refused"],window.t("Turned away"),Note,Mark(Number(A["refused"]) >= 20));
        Holder.appendChild(Tiles);
      };
      if (Boolean(A["reasons"]) && Boolean(A["reasons"].length)) {
        P = pas.Admin_List.C.el("p","lv-reasons");
        for (var $l1 = 0, $end1 = A["reasons"].length - 1; $l1 <= $end1; $l1++) {
          I = $l1;
          P.appendChild(pas.Admin_List.C.chip(pas.Admin_List.ReasonWords(A["reasons"][I]),"open"));
        };
        Holder.appendChild(P);
      };
      List = pas.Admin_List.C.el("ul","block-facts");
      if (!Boolean(G)) {
        List.appendChild(pas.Admin_List.C.el("li","dim",window.t("The guard’s facts could not be read.")))}
       else {
        Kinds2 = pas.Admin_List.StrikeKinds();
        if (Boolean(G["local"])) {
          List.appendChild(pas.Admin_List.C.el("li","good",window.t("This network: never blocked or limited.")))}
         else if (Boolean(G["allowed"])) List.appendChild(pas.Admin_List.C.el("li","good",window.t("On the allowed list (Settings, allowed_ips): never blocked or limited.")));
        if (Boolean(G["crawler"])) List.appendChild(pas.Admin_List.C.el("li","good",window.t("A published crawler, by the addresses its company publishes or its name pointing back to the address: never limited or blocked by the guard.")));
        X = G["block"];
        if (Boolean(X) && Boolean(X["active"])) {
          if (Boolean(X["for_good"])) {
            List.appendChild(pas.Admin_List.C.el("li","bad",window.t("Blocked for good: %s (%s).",X["reason"],window.dateTimeText(X["when"]))))}
           else List.appendChild(pas.Admin_List.C.el("li","bad",window.t("Blocked until %s: %s. Blocked %d times so far.",window.dateTimeText(X["until"]),X["reason"],X["times"])));
        } else if (Boolean(X)) {
          List.appendChild(pas.Admin_List.C.el("li","",window.t("Not blocked now. Last block: %s, over since %s; blocked %d times so far.",X["reason"],window.dateTimeText(X["until"]),X["times"])))}
         else List.appendChild(pas.Admin_List.C.el("li","",window.t("Not blocked, and never has been.")));
        if (Boolean(G["abuse"])) {
          Ab = G["abuse"];
          Words = window.t("AbuseIPDB: %d%% confidence of abuse, %s from other sites (looked up %s).",Ab["score"],window.tn(Ab["reports"],"%d report","%d reports"),window.dateTimeText(Ab["checked"]));
          if (Boolean(Ab["usage"]) || Boolean(Ab["isp"])) {
            Names = new Array();
            if (Boolean(Ab["usage"])) Names.push(Ab["usage"]);
            if (Boolean(Ab["isp"])) Names.push(Ab["isp"]);
            if (Boolean(Ab["country"])) Names.push(Ab["country"]);
            Words = Words + " " + Names.join(", ") + ".";
          };
          if (Boolean(Ab["reported"])) Words = Words + " " + window.t("We reported it %s.",window.dateTimeText(Ab["reported"]));
          if (Number(Ab["score"]) >= 75) {
            Cls = "bad"}
           else Cls = "";
          List.appendChild(pas.Admin_List.C.el("li",Cls,Words));
        };
        if (Boolean(G["strikes"]) && Boolean(G["strikes"].length)) {
          Li = pas.Admin_List.C.el("li","",window.t("In the last day:") + " ");
          Strikes = new Array();
          for (var $l2 = 0, $end2 = G["strikes"].length - 1; $l2 <= $end2; $l2++) {
            I = $l2;
            X = G["strikes"][I];
            Strikes.push("" + pas.Admin_List.Either(Kinds2["" + X["kind"]],X["kind"]) + " × " + ("" + X["count"]));
          };
          Li.appendChild(pas.Admin_List.C.el("span","",Strikes.join(", ")));
          List.appendChild(Li);
        } else List.appendChild(pas.Admin_List.C.el("li","dim",window.t("Nothing counted against it in the last day.")));
      };
      Holder.appendChild(List);
      Acts = pas.Admin_List.C.el("div","lv-actions");
      if (Boolean(G)) {
        Note = G["block"]}
       else Note = G;
      $impl.BlockButtons(Acts,R["ip"],Note,Again,CrawlerText);
      if (Acts.childNodes.length > 0) Holder.appendChild(Acts);
      if (!Boolean(A["requests"])) return;
      $mod.TimelineChart(Holder,R["timeline"],true);
      Two = pas.Admin_List.C.el("div","visit-two");
      Left = pas.Admin_List.C.el("div");
      Right = pas.Admin_List.C.el("div");
      Two.append(Left,Right);
      Holder.appendChild(Two);
      if (Number(R["paths_count"]) > R["paths"].length) {
        Left.appendChild(pas.Admin_List.C.el("h3","",window.t("What it asked for most (%s paths in all)",pas.Admin_List.LocaleNumber(R["paths_count"]))))}
       else Left.appendChild(pas.Admin_List.C.el("h3","",window.t("What it asked for")));
      Shown = R["paths"].slice(0,14);
      Rows = new Array();
      for (var $l3 = 0, $end3 = Shown.length - 1; $l3 <= $end3; $l3++) {
        I = $l3;
        X = Shown[I];
        Note = X["path"];
        try {
          Note = decodeURIComponent("" + Note);
        } catch ($e) {
        };
        Rows.push(pas.JS.New(["name",pas.Admin_List.Either(Note,"/"),"value",X["count"]]));
      };
      pas.Admin_List.Bars(Left,Rows,$impl.Requests);
      Right.appendChild(pas.Admin_List.C.el("h3","",window.t("How it was answered")));
      Codes = $impl.KeysByCount(pas.Admin_List.Either(R["statuses"],new Object()));
      Rows = new Array();
      for (var $l4 = 0, $end4 = Codes.length - 1; $l4 <= $end4; $l4++) {
        I = $l4;
        Code = "" + Codes[I];
        if (Code === "0") {
          Note = window.t("before the codes were logged")}
         else Note = Code;
        Rows.push(pas.JS.New(["name",Note,"value",R["statuses"][Code],"other",(Code === "0") || (Code < "400")]));
      };
      pas.Admin_List.Bars(Right,Rows,$impl.Requests);
      Right.appendChild(pas.Admin_List.C.el("h3","",window.t("Parts of the site")));
      Parts = $impl.KeysByCount(pas.Admin_List.Either(R["parts"],new Object()));
      Rows = new Array();
      for (var $l5 = 0, $end5 = Parts.length - 1; $l5 <= $end5; $l5++) {
        I = $l5;
        Rows.push(pas.JS.New(["name",pas.Admin_List.PartLabel(Parts[I]),"value",R["parts"]["" + Parts[I]]]));
      };
      pas.Admin_List.Bars(Right,Rows,$impl.Requests);
      if (Boolean(R["referers"]) && Boolean(R["referers"].length)) {
        Right.appendChild(pas.Admin_List.C.el("h3","",window.t("Came by links from")));
        Shown = R["referers"].slice(0,8);
        Rows = new Array();
        for (var $l6 = 0, $end6 = Shown.length - 1; $l6 <= $end6; $l6++) {
          I = $l6;
          Rows.push(pas.JS.New(["name",Shown[I]["host"],"value",Shown[I]["requests"]]));
        };
        pas.Admin_List.Bars(Right,Rows,$impl.Requests);
      };
      Holder.appendChild(pas.Admin_List.C.el("h3","",window.t("Browser strings it used")));
      pas.Admin_List.ListView(Holder,pas.JS.New(["id","v-addr-agents","key",function (Row) {
        var Result = undefined;
        Result = Row["agent"];
        return Result;
      },"sort","-requests","search",false,"rows",R["agents"],"columns",Array.of(pas.JS.New(["key","browser","title",window.t("Browser or bot"),"value",AgentName,"cell",function (Row) {
        var Result = undefined;
        var Span = null;
        Span = pas.Admin_List.C.el("span","",AgentName(Row));
        if (Boolean(Row["claims"]) && !Boolean(A["crawler"])) Span.append(" ",pas.Admin_List.C.chip(window.t("claims %s",Row["claims"]),"bad"));
        Result = Span;
        return Result;
      }]),pas.JS.New(["key","requests","title",window.t("Requests"),"num",true]),pas.JS.New(["key","last","title",window.t("Last seen"),"down",true,"cell",function (Row) {
        var Result = undefined;
        Result = pas.Admin_List.Stamp(Row["last"]);
        return Result;
      }]),pas.JS.New(["key","agent","title",window.t("The whole string"),"wide",true,"cls","lv-text"])),"noun",function (N) {
        var Result = undefined;
        Result = window.tn(N,"%d browser string","%d browser strings");
        return Result;
      }]));
      if (Boolean(R["members"]) && Boolean(R["members"].length)) {
        Holder.appendChild(pas.Admin_List.C.el("h3","",window.t("Signed in from it as")));
        Ul = pas.Admin_List.C.el("ul","lv-paths");
        for (var $l7 = 0, $end7 = R["members"].length - 1; $l7 <= $end7; $l7++) {
          I = $l7;
          M = R["members"][I];
          Li = pas.Admin_List.C.el("li");
          Li.append(pas.Admin_List.C.link("/u/" + pas.Admin_List.C.enc(M["name"]),"",M["name"])," ",pas.Admin_List.C.el("span","dim",window.tn(M["requests"],"%d request","%d requests") + ", " + ("" + pas.Admin_List.Stamp(M["last"]))));
          Ul.appendChild(Li);
        };
        Holder.appendChild(Ul);
      };
      Holder.appendChild(pas.Admin_List.C.el("h3","",window.t("Its last requests in the period")));
      pas.Admin_List.ListView(Holder,pas.JS.New(["id","v-addr-trail","key",function (L) {
        var Result = undefined;
        Result = "" + L["at"] + ("" + L["path"]);
        return Result;
      },"sort","-at","search",window.t("Filter its requests"),"page",100,"rows",R["trail"],"csv","address-" + R["ip"].replace(new RegExp("[^0-9a-z]","gi"),"_"),"columns",Array.of(pas.JS.New(["key","at","title",window.t("When"),"down",true,"cell",function (L) {
        var Result = undefined;
        Result = pas.Admin_List.Stamp(L["at"]);
        return Result;
      }]),pas.JS.New(["key","method","title",window.t("Method"),"wide",true]),pas.JS.New(["key","path","title",window.t("Page"),"cell",function (L) {
        var Result = undefined;
        Result = pas.Admin_List.PageLink(L["path"]);
        return Result;
      }]),pas.JS.New(["key","status","title",window.t("Status"),"num",true,"cell",function (L) {
        var Result = undefined;
        Result = pas.Admin_List.StatusCell(L["status"]);
        return Result;
      }]),pas.JS.New(["key","ms","title",window.t("Took"),"num",true,"wide",true,"cell",function (L) {
        var Result = undefined;
        Result = pas.Admin_List.MsCell(L["ms"]);
        return Result;
      }]),pas.JS.New(["key","member","title",window.t("Member"),"wide",true,"cell",function (L) {
        var Result = undefined;
        if (Boolean(L["member"])) {
          Result = pas.Admin_List.C.link("/u/" + pas.Admin_List.C.enc(L["member"]),"",L["member"])}
         else Result = "";
        return Result;
      }]),pas.JS.New(["key","browser","title",window.t("Browser"),"wide",true,"value",function (L) {
        var Result = undefined;
        Result = pas.Admin_List.BrowserOf(L["agent"]);
        return Result;
      }])),"filters",Array.of(pas.JS.New(["key","kind","title",window.t("Which"),"all",window.t("Every request"),"options",Array.of(Array.of("pages",window.t("Pages")),Array.of("other",window.t("Everything else")),Array.of("errors",window.t("Errors and refusals"))),"test",function (L, K) {
        var Result = undefined;
        if (K === "errors") {
          Result = Number(L["status"]) >= 400}
         else if (pas.Admin_List.Same(L["method"],"GET") && pas.Admin_List.IsPagePath(L["path"])) {
          Result = K === "pages"}
         else Result = K === "other";
        return Result;
      }])),"noun",$impl.Requests]));
    };
    async function Read() {
      var R = null;
      var G = null;
      var Why = "";
      var Message = undefined;
      try {
        try {
          R = await pas.Admin_List.C.get("/api/admin/visitors/address?ip=" + pas.Admin_List.C.enc(Ip) + "&from=" + pas.Admin_List.C.enc(Win["from"]) + "&to=" + pas.Admin_List.C.enc(Win["to"]));
        } catch ($e) {
          if (!Boolean(pas.Admin_List.S["adminCan"]) || pas.Admin_List.S.adminCan("view-visitors") || !pas.Admin_List.S.adminCan("manage-blocks")) throw $e;
          G = await pas.Admin_List.C.get("/api/blocks/why?ip=" + pas.Admin_List.C.enc(Ip));
          R = pas.JS.New(["ip",G["ip"],"address",pas.JS.New(["requests",0,"reasons",new Array()]),"guard",G]);
        };
        Draw(R);
      } catch ($e) {
        Why = "";
        if (Boolean($e)) {
          Message = $e["message"];
          if (Boolean(Message) && (Message.length < 300) && !pas.Admin_List.Regex("[<>]",Message)) Why = " " + ("" + Message);
        };
        Holder.replaceChildren(pas.Admin_List.C.el("p","notice",window.t("The address could not be looked up.") + Why));
      };
    };
    if (typeof(Period) === "function") {
      Win = Period()}
     else Win = Period;
    pas.Admin_List.C.waiting(Holder,window.t("Reading the log…"));
    Read();
  };
  $mod.$implcode = function () {
    $impl.BlockButtons = function (Holder, Ip, B, After, Crawler) {
      var Lift = null;
      var ForGood = null;
      var Block = null;
      var Allow = null;
      function CrawlerOk() {
        var Result = false;
        Result = !Boolean(Crawler) || window.confirm(window.t("%s is %s, checked against the addresses its company publishes. Blocking it keeps the site out of that company’s search and answers. Block it anyway?",Ip,Crawler));
        return Result;
      };
      async function Act(What, Reason) {
        var Blocking = false;
        var Ok = "";
        Blocking = (What === "block") || (What === "forgood");
        if (Blocking && Boolean(Crawler)) {
          Ok = "1"}
         else Ok = "";
        try {
          await pas.Admin_List.C.post("/api/blocks",pas.JS.New(["ip",Ip,"do",What,"reason",pas.Admin_List.Either(Reason,""),"crawler_ok",Ok]));
        } catch ($e) {
          pas.Admin_List.C.failed($e);
          return;
        };
        if (Boolean(pas.Admin_List.S["blocksChanged"])) pas.Admin_List.S.blocksChanged();
        if (After != null) After();
      };
      if (!Boolean(pas.Admin_List.S["adminCan"]) || !pas.Admin_List.S.adminCan("manage-blocks")) return;
      if (Boolean(B) && Boolean(B["active"])) {
        Lift = pas.Admin_List.C.el("button","",window.t("Lift"));
        Lift["type"] = "button";
        Lift.addEventListener("click",function (E) {
          Act("lift",undefined);
        });
        Holder.appendChild(Lift);
      };
      if (!Boolean(B) || !Boolean(B["for_good"])) {
        ForGood = pas.Admin_List.C.el("button","bad",window.t("Block for good"));
        ForGood["type"] = "button";
        ForGood.addEventListener("click",function (E) {
          var Go = false;
          if (Boolean(Crawler)) {
            Go = CrawlerOk()}
           else Go = window.confirm(window.t("Block %s for good?",Ip));
          if (Go) Act("forgood",undefined);
        });
        Holder.appendChild(ForGood);
      };
      if (!Boolean(B) || !Boolean(B["active"])) {
        Block = pas.Admin_List.C.el("button","",window.t("Block now"));
        Block["type"] = "button";
        Block.addEventListener("click",function (E) {
          var Reason = undefined;
          if (!CrawlerOk()) return;
          Reason = window.prompt(window.t("Why? (kept with the block)"),"");
          if (!(Reason == null)) Act("block",Reason);
        });
        Holder.appendChild(Block);
      };
      Allow = pas.Admin_List.C.el("button","",window.t("Allow"));
      Allow["type"] = "button";
      Allow.title = window.t("Never block or limit this address again");
      Allow.addEventListener("click",function (E) {
        Act("allow",undefined);
      });
      Holder.appendChild(Allow);
    };
    $impl.Requests = function (N) {
      var Result = undefined;
      Result = window.tn(N,"%d request","%d requests");
      return Result;
    };
    $impl.KeysByCount = function (Counts) {
      var Result = null;
      Result = pas.Admin_List.SortBy(Object.keys(Counts),function (X, Y) {
        var Result = 0.0;
        Result = Number(Counts[Y]) - Number(Counts[X]);
        return Result;
      });
      return Result;
    };
  };
},[]);
rtl.module("Admin_Backup",["System","JS","Web","Admin_List"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  var Piece = 8 * 1024 * 1024;
  this.AdminBackup = function (Box) {
    var Timer = 0;
    function Hours(Iso) {
      var Result = 0.0;
      if (Boolean(Iso)) {
        Result = (Date.now() - Number(new Date(Iso))) / 36e5}
       else Result = Infinity;
      return Result;
    };
    async function Show() {
      var Data = null;
      var Newest = null;
      var Outside = null;
      var Pictures = null;
      var Logs = null;
      var List = null;
      var Worries = null;
      var Bits = null;
      var Lines = null;
      var Notice = null;
      var Line = null;
      var Far = null;
      var Make = null;
      var Go = null;
      var Up = null;
      var Pick = null;
      var Send = null;
      var Progress = null;
      var Move = null;
      var Steps = null;
      var Word = "";
      var Done = "";
      var I = 0;
      function TickOf(Name, Words) {
        var Result = null;
        var TheLabel = null;
        var Tick = null;
        TheLabel = pas.Admin_List.C.el("label");
        Tick = pas.Admin_List.C.el("input");
        Tick["type"] = "checkbox";
        Tick["name"] = Name;
        Tick["value"] = "1";
        TheLabel.append(Tick," ",Words);
        Result = pas.JS.New(["label",TheLabel,"tick",Tick]);
        return Result;
      };
      async function MakeNow(E) {
        var WithPictures = "";
        var WithLogs = "";
        E.preventDefault();
        try {
          if (Boolean(Pictures["tick"]["checked"])) {
            WithPictures = "1"}
           else WithPictures = "0";
          if (Boolean(Logs["tick"]["checked"])) {
            WithLogs = "1"}
           else WithLogs = "0";
          pas.Admin_List.C.toast(await pas.Admin_List.C.post("/api/admin/backup/make",pas.JS.New(["pictures",WithPictures,"logs",WithLogs])));
          Show();
        } catch ($e) {
          pas.Admin_List.C.failed($e);
        };
      };
      function Kept(B) {
        var Row = null;
        var Name = null;
        var Detail = null;
        var More = null;
        var TableList = null;
        var Down = null;
        var Check = null;
        var Restore = null;
        var Del = null;
        var About = null;
        var M = null;
        var Holds = null;
        var Names = null;
        var Words = "";
        var N = 0;
        async function CheckNow(E) {
          try {
            pas.Admin_List.C.toast(await pas.Admin_List.C.post("/api/admin/backup/check",pas.JS.New(["name",B["name"]])));
            Show();
          } catch ($e) {
            pas.Admin_List.C.failed($e);
          };
        };
        async function RestoreNow(E) {
          var Typed = undefined;
          Typed = window.prompt(window.t('Restoring %s replaces every table with the backup’s (a table the backup does not have is emptied) and writes its files over the data folder and the pictures; files added since stay. Everyone else sees a "back in a minute" page while it runs, and a restart afterwards is wise. Type RESTORE to go ahead.',B["name"]));
          if (pas.Admin_List.Same(Typed,null)) return;
          try {
            pas.Admin_List.C.toast(await pas.Admin_List.C.post("/api/admin/backup/restore",pas.JS.New(["name",B["name"],"confirm",Typed.trim()])));
            Show();
          } catch ($e) {
            pas.Admin_List.C.failed($e);
          };
        };
        async function DeleteNow(E) {
          if (!window.confirm(window.t("Delete %s?",B["name"]))) return;
          try {
            pas.Admin_List.C.toast(await pas.Admin_List.C.post("/api/admin/backup/delete",pas.JS.New(["name",B["name"]])));
            Show();
          } catch ($e) {
            pas.Admin_List.C.failed($e);
          };
        };
        Row = pas.Admin_List.C.el("div","person backup-row");
        Name = pas.Admin_List.C.el("a","backup-name",B["name"]);
        Name["href"] = "/api/admin/backup/file/" + encodeURIComponent("" + B["name"]);
        Name.setAttribute("download","" + B["name"]);
        Words = pas.Admin_List.C.sizeText(B["bytes"]) + " · " + window.dateTimeText(B["when"]);
        if (Boolean(B["uploaded"])) Words = Words + " · " + window.t("uploaded");
        Row.append(Name,pas.Admin_List.C.el("span","dim",Words));
        About = pas.Admin_List.Either(B["about"],new Object());
        M = About["manifest"];
        Holds = new Array();
        if (Boolean(M)) {
          if (Boolean(M["site"])) Holds.push(M["site"]);
          if (Boolean(M["tables"])) Holds.push(window.tn(M["tables"],"%d table","%d tables") + ", " + window.tn(pas.Admin_List.Either(M["rows"],0),"%d row","%d rows"));
          if (Boolean(M["files"])) Holds.push(window.tn(M["files"],"%d file","%d files"));
          if (Boolean(M["pictures"])) {
            Holds.push(window.t("with pictures"))}
           else Holds.push(window.t("no pictures"));
          if (Boolean(M["logs"])) {
            Holds.push(window.t("with access logs"))}
           else Holds.push(window.t("no access logs"));
        } else if (pas.Admin_List.Same(About["manifest"],null)) Holds.push(window.t("no manifest inside: an early backup or not one made here"));
        Detail = pas.Admin_List.C.el("div","backup-holds dim",Holds.join(" · "));
        if (Boolean(M) && Boolean(M["counts"])) {
          More = pas.Admin_List.C.el("a","small-link",window.t("Tables"));
          More["href"] = "#";
          TableList = pas.Admin_List.C.el("div","backup-tables dim");
          TableList.hidden = true;
          Names = pas.Admin_List.SortBy(Object.keys(M["counts"]),undefined);
          for (var $l = 0, $end = Names.length - 1; $l <= $end; $l++) {
            N = $l;
            Names[N] = "" + Names[N] + " " + ("" + M["counts"]["" + Names[N]]);
          };
          TableList.textContent = Names.join(" · ");
          More.addEventListener("click",function (E) {
            E.preventDefault();
            TableList.hidden = !TableList.hidden;
          });
          Detail.append(" ",More);
          Row.append(Detail,TableList);
        } else Row.appendChild(Detail);
        if (Boolean(About["checked"])) {
          if (Boolean(About["whole"])) {
            Row.appendChild(pas.Admin_List.C.el("div","backup-check good",window.t("Checked %s: whole.",window.dateTimeText(About["checked"])) + " " + ("" + pas.Admin_List.Either(About["note"],""))))}
           else Row.appendChild(pas.Admin_List.C.el("div","backup-check bad",window.t("Checked %s: NOT whole.",window.dateTimeText(About["checked"])) + " " + ("" + pas.Admin_List.Either(About["note"],""))));
        } else Row.appendChild(pas.Admin_List.C.el("div","backup-check warn",window.t("Not checked yet.")));
        Down = pas.Admin_List.C.el("a","small-link",window.t("Download"));
        Down["href"] = Name["href"];
        Down.setAttribute("download","" + B["name"]);
        Row.appendChild(Down);
        Check = pas.Admin_List.C.el("button","small-link",window.t("Check"));
        Check["type"] = "button";
        Check["disabled"] = Boolean(Data["busy"]);
        Check.addEventListener("click",CheckNow);
        Row.appendChild(Check);
        Restore = pas.Admin_List.C.el("button","small-link",window.t("Restore…"));
        Restore["type"] = "button";
        Restore["disabled"] = Boolean(Data["busy"]);
        Restore.addEventListener("click",RestoreNow);
        Row.appendChild(Restore);
        Del = pas.Admin_List.C.el("button","small-link",window.t("Delete"));
        Del["type"] = "button";
        Del.addEventListener("click",DeleteNow);
        Row.appendChild(Del);
        Box.appendChild(Row);
      };
      async function Upload(E) {
        var Sent = null;
        var Where = "";
        var Url = "";
        var Body = "";
        var Offset = 0.0;
        var Tries = 0;
        var Last = false;
        var Lost = false;
        var Answer = null;
        var R = null;
        var Trouble = undefined;
        E.preventDefault();
        if (Pick.files.length === 0) return;
        Sent = Pick.files.item(0);
        Where = "/api/admin/backup/chunk?name=" + pas.Admin_List.C.enc(Sent["name"]);
        Send["disabled"] = true;
        Offset = 0;
        Tries = 0;
        try {
          try {
            Trouble = undefined;
            while (true) {
              Last = (Offset + 8388608) >= Sent.size;
              Url = Where + "&offset=" + String(Offset);
              if (Last) Url = Url + "&size=" + String(Sent.size);
              Lost = false;
              try {
                R = await window.fetch(Url,pas.JS.New(["method","POST","body",Sent.slice(Offset,Offset + 8388608),"headers",pas.JS.New(["Content-Type","application/octet-stream"])]));
                Body = await R.text();
                if (R.ok) {
                  Answer = JSON.parse(Body)}
                 else {
                  Lost = true;
                  Trouble = new Error(Body);
                };
              } catch ($e) {
                Lost = true;
                Trouble = $e;
              };
              if (Lost) {
                Tries += 1;
                if (Tries > 4) break;
                await new Promise(function (Go, Stop) {
                  window.setTimeout(function () {
                    Go(undefined);
                  },2000 * Tries);
                });
                continue;
              };
              Tries = 0;
              if (Boolean(Answer["done"])) {
                Progress.textContent = "";
                pas.Admin_List.C.toast(window.t("Kept as %s.",Answer["name"]));
                break;
              };
              Offset = Number(Answer["have"]);
              Progress.textContent = window.t("Sending: %s",String(Math.floor((100 * Offset) / Math.max(1,Sent.size))) + "%");
            };
            if (Lost) {
              Progress.textContent = "";
              pas.Admin_List.C.failed(Trouble);
            } else Show();
          } catch ($e) {
            Progress.textContent = "";
            pas.Admin_List.C.failed($e);
          };
        } finally {
          Send["disabled"] = false;
        };
      };
      try {
        Data = await pas.Admin_List.C.get("/api/admin/backup");
      } catch ($e) {
        pas.Admin_List.C.failed($e);
        return;
      };
      Box.replaceChildren();
      Box.appendChild(pas.Admin_List.C.el("p","hint",window.t("A backup is one zip file with every table of the database, the data folder with members’ files, and the program’s config file. The pictures are large: the wiki’s hold what members uploaded, so they belong in a whole backup. The access logs are only history. Each goes in when asked. Backups are kept on the server in %s.",Data["folder"])));
      List = pas.Admin_List.SortBy(pas.Admin_List.Either(Data["backups"],new Array()).slice(0),function (A, B) {
        var Result = 0.0;
        if ($impl.Less(A["when"],B["when"])) {
          Result = 1}
         else Result = -1;
        return Result;
      });
      if (List.length > 0) {
        Newest = List[0]}
       else Newest = null;
      if (Boolean(Data["outside"]) && (typeof(Data["outside"]) === "object")) {
        Outside = Data["outside"]}
       else Outside = null;
      Worries = new Array();
      if (Newest === null) {
        Worries.push(window.t("No backup has been made here yet."))}
       else if (Hours(Newest["when"]) > 36) Worries.push(window.t("The newest backup here is %s old.",pas.Admin_List.C.ago(Newest["when"])));
      if ((Newest !== null) && Boolean(Newest["about"]) && pas.Admin_List.Same(Newest["about"]["whole"],false)) Worries.push(window.t("The newest backup here did not pass its check: %s",pas.Admin_List.Either(Newest["about"]["note"],"")));
      if (Outside === null) {
        Worries.push(window.t("No copy on another machine has been recorded. A script that copies backups elsewhere writes backup-status.json beside the program."))}
       else if (pas.Admin_List.Same(Outside["ok"],false)) {
        Worries.push(window.t("The last copy to another machine failed (%s).",pas.Admin_List.Either(Outside["failed"],window.t("see its log"))))}
       else if (Hours(Outside["when"]) > 36) Worries.push(window.t("The last copy to another machine is %s old.",pas.Admin_List.C.ago(Outside["when"])));
      if ((Number(Data["free_bytes"]) >= 0) && (Number(Data["free_bytes"]) < (2 * 1024 * 1024 * 1024))) Worries.push(window.t("Only %s is free on the disk that holds the backups.",pas.Admin_List.C.sizeText(Data["free_bytes"])));
      if (Worries.length > 0) {
        Notice = pas.Admin_List.C.el("div","notice bad");
        for (var $l = 0, $end = Worries.length - 1; $l <= $end; $l++) {
          I = $l;
          Notice.appendChild(pas.Admin_List.C.el("div","",Worries[I]));
        };
        Box.appendChild(Notice);
      } else Box.appendChild(pas.Admin_List.C.el("p","notice good",window.t("A whole backup from the last day and a half is here, and the copy on the other machine is fresh.")));
      if (Boolean(Data["busy"])) {
        Line = pas.Admin_List.C.el("p","notice working");
        if (pas.Admin_List.Same(Data["doing"],"restore")) {
          Word = window.t("Restoring…")}
         else if (pas.Admin_List.Same(Data["doing"],"check")) {
          Word = window.t("Checking…")}
         else Word = window.t("Making a backup…");
        Line.append(pas.Admin_List.C.el("b","",Word)," ",pas.Admin_List.C.el("span","",pas.Admin_List.Either(Data["step"],""))," ",pas.Admin_List.C.el("span","dim",window.t("started %s by %s",window.dateTimeText(Data["started"]),pas.Admin_List.Either(Data["by"],""))));
        Box.appendChild(Line);
        if (Timer === 0) Timer = window.setInterval(function () {
          Show();
        },2000);
      } else {
        if (Timer !== 0) {
          window.clearInterval(Timer);
          Timer = 0;
        };
        if (Boolean(Data["error"])) {
          Box.appendChild(pas.Admin_List.C.el("p","notice bad",window.t("The last job failed: %s",Data["error"])))}
         else if (Boolean(Data["last"])) Box.appendChild(pas.Admin_List.C.el("p","notice good",Data["last"]));
      };
      Far = pas.Admin_List.C.el("div","backup-outside");
      Far.appendChild(pas.Admin_List.C.el("h3","",window.t("Copy on another machine")));
      if (Outside === null) {
        Far.appendChild(pas.Admin_List.C.el("p","dim",window.t("None recorded.")))}
       else {
        if (Boolean(Outside["ok"])) {
          Done = window.t("complete")}
         else if (Boolean(Outside["failed"])) {
          Done = window.t("FAILED") + " (" + ("" + Outside["failed"]) + ")"}
         else Done = window.t("FAILED");
        Bits = Array.of(window.dateTimeText(Outside["when"]),Done);
        if (Boolean(Outside["database_bytes"])) Bits.push(window.t("database %s",pas.Admin_List.C.sizeText(Outside["database_bytes"])));
        if (Boolean(Outside["config_bytes"])) Bits.push(window.t("config and files %s",pas.Admin_List.C.sizeText(Outside["config_bytes"])));
        if (Boolean(Outside["images_bytes"])) Bits.push(window.t("pictures %s",pas.Admin_List.C.sizeText(Outside["images_bytes"])));
        if (Boolean(Outside["kept"])) Bits.push(window.tn(Outside["kept"],"%d dump kept","%d dumps kept"));
        if (Boolean(Outside["ok"])) {
          Far.appendChild(pas.Admin_List.C.el("p","",Bits.join(" · ")))}
         else Far.appendChild(pas.Admin_List.C.el("p","bad",Bits.join(" · ")));
        if (Boolean(Outside["where"])) Far.appendChild(pas.Admin_List.C.el("p","dim",Outside["where"]));
      };
      Box.appendChild(Far);
      Make = pas.Admin_List.C.el("form","backup-make");
      Pictures = TickOf("pictures",window.t("Include the pictures (%s): slow and large, but whole",pas.Admin_List.Either(Data["pictures"],window.t("none registered"))));
      Pictures["tick"]["checked"] = true;
      Logs = TickOf("logs",window.t("Include the access logs (the last %d days)",pas.Admin_List.Either(Data["log_days"],0)));
      Go = pas.Admin_List.C.el("button","",window.t("Make a backup now"));
      Go["disabled"] = Boolean(Data["busy"]);
      Make.append(Go,Pictures["label"],Logs["label"]);
      Make.addEventListener("submit",MakeNow);
      Box.appendChild(Make);
      Box.appendChild(pas.Admin_List.C.el("h3","",window.tn(List.length,"%d backup kept here","%d backups kept here") + " · " + window.t("the newest %d made here stay",Data["keep"])));
      if (List.length === 0) Box.appendChild(pas.Admin_List.C.el("p","dim",window.t("No backups yet.")));
      for (var $l1 = 0, $end1 = List.length - 1; $l1 <= $end1; $l1++) {
        I = $l1;
        Kept(List[I]);
      };
      Up = pas.Admin_List.C.el("form","backup-upload");
      Pick = pas.Admin_List.C.el("input");
      Pick["type"] = "file";
      Pick["accept"] = ".zip,application/zip";
      Pick["required"] = true;
      Send = pas.Admin_List.C.el("button","",window.t("Upload a backup"));
      Progress = pas.Admin_List.C.el("span","dim");
      Progress.setAttribute("role","status");
      Up.append(pas.Admin_List.C.el("label","",window.t("A backup file from another day or another server, of any size:")),Pick,Send,Progress);
      Up.addEventListener("submit",Upload);
      Box.appendChild(Up);
      Move = pas.Admin_List.C.el("details","backup-move");
      Move.appendChild(pas.Admin_List.C.el("summary","",window.t("Moving the site to another machine")));
      Steps = pas.Admin_List.C.el("ol");
      Lines = Array.of(window.t("Make a backup here with the pictures, and download it (or copy it from the folder above)."),window.t("On the new machine: install MariaDB and the client library, make an empty database, and put the program, its static, templates and lang folders and a config file naming that database in one folder, with a data folder the service’s user owns."),window.t("With the service stopped, as that user, run the program with its config file and --restore and the path of the backup file. It builds the tables, loads every table, puts the data folder and the pictures back (where it may write), and leaves the old config file beside the backups to compare."),window.t("Start the service. The site is as it was; members stay signed in from the old sessions only if they sign in again."));
      for (var $l2 = 0, $end2 = Lines.length - 1; $l2 <= $end2; $l2++) {
        I = $l2;
        Steps.appendChild(pas.Admin_List.C.el("li","",Lines[I]));
      };
      Move.appendChild(Steps);
      Move.appendChild(pas.Admin_List.C.el("p","dim","exedra site.ini --restore /path/site-20260101-000000.zip · exedra site.ini --backup --pictures --logs"));
      Box.appendChild(Move);
    };
    Timer = 0;
    Show();
  };
  $mod.$implcode = function () {
    $impl.Less = function (A, B) {
      var Result = false;
      if ((typeof(A) === "string") && (typeof(B) === "string")) {
        Result = ("" + A) < ("" + B)}
       else Result = Number(A) < Number(B);
      return Result;
    };
  };
},[]);
rtl.module("Admin_Reports",["System","JS","Web","Admin_List"],function () {
  "use strict";
  var $mod = this;
  this.AdminReports = function (Box) {
    var States = null;
    var Rows = null;
    var View = null;
    function StateName(State) {
      var Result = undefined;
      var I = 0;
      for (var $l = 0, $end = States.length - 1; $l <= $end; $l++) {
        I = $l;
        if (pas.Admin_List.Same(States[I][0],State)) return States[I][1];
      };
      Result = State;
      return Result;
    };
    function OpenCount() {
      var I = 0;
      var Open = 0;
      if (!Boolean(pas.Admin_List.S["adminCount"])) return;
      Open = 0;
      for (var $l = 0, $end = Rows.length - 1; $l <= $end; $l++) {
        I = $l;
        if (!Boolean(Rows[I]["done"])) Open += 1;
      };
      pas.Admin_List.S.adminCount("Reports",Open);
    };
    async function Save(R, Fields, List) {
      var Result = false;
      try {
        await pas.Admin_List.C.post("/api/bugs",Object.assign(pas.JS.New(["id",R["id"]]),Fields));
      } catch ($e) {
        pas.Admin_List.C.failed($e);
        return false;
      };
      if (Boolean(Fields["state"])) {
        R["state"] = Fields["state"];
        R["done"] = pas.Admin_List.Same(Fields["state"],"resolved") || pas.Admin_List.Same(Fields["state"],"closed") || pas.Admin_List.Same(Fields["state"],"spam");
      };
      if (!pas.Admin_List.IsUndef(Fields["note"])) R["note"] = Fields["note"];
      List.changed(R);
      OpenCount();
      Result = true;
      return Result;
    };
    function Detail(R, Holder, List) {
      var Head = null;
      var Page = null;
      var Ip = null;
      var Look = null;
      var Row = null;
      var More = null;
      var NoteForm = null;
      var Note = null;
      var Keep = null;
      var Local = false;
      var Shown = undefined;
      var Address = undefined;
      var Changed = undefined;
      var I = 0;
      function StateButton(St) {
        var B = null;
        if (pas.Admin_List.Same(R["state"],St[0])) {
          B = pas.Admin_List.C.el("button","on",St[1])}
         else B = pas.Admin_List.C.el("button","",St[1]);
        B["type"] = "button";
        if (pas.Admin_List.Same(R["state"],St[0])) {
          B.setAttribute("aria-pressed","true")}
         else B.setAttribute("aria-pressed","false");
        B.addEventListener("click",function (E) {
          if (!pas.Admin_List.Same(R["state"],St[0])) Save(R,pas.JS.New(["state",St[0]]),List);
        });
        Row.appendChild(B);
      };
      async function SaveNote(E) {
        E.preventDefault();
        if (await Save(R,pas.JS.New(["note",Note["value"]]),List)) pas.Admin_List.C.toast(window.t("Saved."));
      };
      Head = pas.Admin_List.C.el("div","lv-detail-head");
      Head.append(pas.Admin_List.C.el("b","",R["name"]),pas.Admin_List.C.el("span","dim",window.dateTimeText(R["at"])));
      Holder.appendChild(Head);
      Local = pas.Admin_List.Regex("^\\/(?!\\/)",pas.Admin_List.Either(R["page"],""));
      if (Local) {
        Page = pas.Admin_List.C.el("a","",R["page"])}
       else Page = pas.Admin_List.C.el("span","",R["page"]);
      if (Local) {
        Page["href"] = R["page"];
        Page["target"] = "_blank";
        Page["rel"] = "noopener";
      };
      Ip = pas.Admin_List.C.el("span");
      if (Boolean(R["ip"])) {
        Ip.append("" + R["ip"] + " ");
        Look = pas.Admin_List.C.el("button","small-link",window.t("Look up"));
        Look["type"] = "button";
        Look.addEventListener("click",function (E) {
          pas.Admin_List.LookUpAddress(R["ip"]);
        });
        Ip.appendChild(Look);
      };
      if (Boolean(R["page"])) {
        Shown = Page}
       else Shown = "";
      if (Boolean(R["ip"])) {
        Address = Ip}
       else Address = "";
      if (Boolean(R["updated"])) {
        Changed = window.dateTimeText(R["updated"])}
       else Changed = "";
      pas.Admin_List.C.facts(Holder,Array.of(Array.of(window.t("Page"),Shown),Array.of(window.t("Address"),Address),Array.of(window.t("Changed"),Changed)));
      Row = pas.Admin_List.C.el("div","lv-actions");
      Row.appendChild(pas.Admin_List.C.el("span","dim",window.t("State") + ":"));
      for (var $l = 0, $end = States.length - 1; $l <= $end; $l++) {
        I = $l;
        StateButton(States[I]);
      };
      Holder.appendChild(Row);
      Holder.appendChild(pas.Admin_List.C.el("div","bugtext",R["text"]));
      if (Boolean(R["info"])) {
        More = pas.Admin_List.C.el("details","buginfo-box");
        More.appendChild(pas.Admin_List.C.el("summary","",window.t("What the browser sent with it")));
        More.appendChild(pas.Admin_List.C.el("pre","buginfo",R["info"]));
        Holder.appendChild(More);
      };
      NoteForm = pas.Admin_List.C.el("form","lv-note");
      Note = pas.Admin_List.C.el("textarea");
      Note["value"] = pas.Admin_List.Either(R["note"],"");
      Note["rows"] = 2;
      Note["placeholder"] = window.t("A note for the admins: what was done, or why not");
      Note.setAttribute("aria-label",window.t("Note"));
      Keep = pas.Admin_List.C.el("button","",window.t("Save the note"));
      NoteForm.append(Note,Keep);
      NoteForm.addEventListener("submit",SaveNote);
      Holder.appendChild(NoteForm);
      if (pas.Admin_List.Same(R["state"],"new")) Save(R,pas.JS.New(["state","read"]),List);
    };
    async function Load() {
      var List = null;
      var R = null;
      var I = 0;
      try {
        List = await pas.Admin_List.C.get("/api/bugs");
        Rows = new Array();
        for (var $l = 0, $end = List.length - 1; $l <= $end; $l++) {
          I = $l;
          R = List[I];
          if (!Boolean(R["state"])) if (Boolean(R["done"])) {
            R["state"] = "resolved"}
           else R["state"] = "new";
          Rows.push(R);
        };
        View.set(Rows);
        OpenCount();
      } catch ($e) {
        View.failed($e["message"]);
      };
    };
    States = Array.of(Array.of("new",window.t("New")),Array.of("read",window.t("Read")),Array.of("needs-info",window.t("Needs more information")),Array.of("resolved",window.t("Resolved")),Array.of("closed",window.t("Closed")),Array.of("spam",window.t("Spam")));
    Rows = new Array();
    View = pas.Admin_List.ListView(Box,pas.JS.New(["id","reports","key",function (R) {
      var Result = undefined;
      Result = String(R["id"]);
      return Result;
    },"sort","-at","csv","reports","search",window.t("Search the reports"),"columns",Array.of(pas.JS.New(["key","at","title",window.t("Sent"),"down",true,"cell",function (R) {
      var Result = undefined;
      var Span = null;
      Span = pas.Admin_List.C.el("span","",pas.Admin_List.C.ago(R["at"]));
      Span.title = window.dateTimeText(R["at"]);
      Result = Span;
      return Result;
    }]),pas.JS.New(["key","name","title",window.t("From")]),pas.JS.New(["key","text","title",window.t("Report"),"cls","lv-text","cell",function (R) {
      var Result = undefined;
      Result = R["text"].replace(new RegExp("\\s+","g")," ").slice(0,120);
      return Result;
    }]),pas.JS.New(["key","page","title",window.t("Page"),"wide",true,"cls","lv-text","cell",function (R) {
      var Result = undefined;
      Result = R["page"].replace(new RegExp("^https?:\\/\\/[^/]+"),"");
      return Result;
    }]),pas.JS.New(["key","state","title",window.t("State"),"value",function (R) {
      var Result = undefined;
      Result = StateName(R["state"]);
      return Result;
    },"cell",function (R) {
      var Result = undefined;
      if (pas.Admin_List.Same(R["state"],"new")) {
        Result = pas.Admin_List.C.chip(StateName(R["state"]),"new")}
       else if (Boolean(R["done"])) {
        Result = pas.Admin_List.C.chip(StateName(R["state"]),"")}
       else Result = pas.Admin_List.C.chip(StateName(R["state"]),"open");
      return Result;
    }])),"filters",Array.of(pas.JS.New(["key","state","title",window.t("State"),"all",window.t("Every state"),"value","open","options",Array.of(Array.of("open",window.t("Not resolved or closed"))).concat(States),"test",function (R, V) {
      var Result = undefined;
      if (V === "open") {
        Result = !Boolean(R["done"])}
       else Result = pas.Admin_List.Same(R["state"],V);
      return Result;
    }])),"rowClass",function (R) {
      var Result = undefined;
      var Cls = "";
      if (pas.Admin_List.Same(R["state"],"new")) {
        Cls = "unread"}
       else Cls = "";
      if (Boolean(R["done"])) Cls = Cls + " done";
      Result = Cls;
      return Result;
    },"noun",function (N) {
      var Result = undefined;
      Result = window.tn(N,"%d report","%d reports");
      return Result;
    },"empty",window.t("No reports yet."),"detail",Detail]));
    Load();
  };
});
rtl.module("Admin_Visitors",["System","JS","Web","Admin_List"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  var ReportParts = ["overview","people","pages","searches","members","crawlers","bots","concerns","latest"];
  this.AdminVisitors = function (Box) {
    var HideMe = false;
    var Blocks = false;
    var Choice = "";
    var Days = null;
    var Controls = null;
    var PickLabel = null;
    var Custom = null;
    var TickLabel = null;
    var Again = null;
    var AddrBox = null;
    var AddrForm = null;
    var AddrGo = null;
    var AddrPanel = null;
    var Pick = null;
    var FromBox = null;
    var ToBox = null;
    var Tick = null;
    var AddrInput = null;
    var Period = null;
    var TabList = null;
    var Subs = null;
    var ShownIp = "";
    var Loads = 0;
    function UtcDay(Back) {
      var Result = "";
      Result = (new Date(Date.now() - (Back * 864e5))).toISOString().slice(0,10);
      return Result;
    };
    function Iso(Ms) {
      var Result = "";
      Result = (new Date(Ms)).toISOString().slice(0,19) + "Z";
      return Result;
    };
    function LocalMidnight(Back) {
      var Result = 0.0;
      var D = null;
      D = new Date();
      D.setHours(0,0,0,0);
      D.setDate(D.getDate() - Back);
      Result = D.getTime();
      return Result;
    };
    function Local(Ms) {
      var Result = "";
      var D = null;
      D = new Date(Ms);
      Result = (new Date(Ms - (D.getTimezoneOffset() * 60000))).toISOString().slice(0,16);
      return Result;
    };
    function Option(Value, Words) {
      var Result = null;
      Result = pas.Admin_List.C.el("option","",Words);
      Result["value"] = Value;
      return Result;
    };
    function FillPeriods() {
      var Oldest = undefined;
      var One = null;
      var I = 0;
      if (Days.length > 0) {
        Oldest = Days[Days.length - 1]}
       else Oldest = UtcDay(0);
      Pick.replaceChildren(Option("1h",window.t("The last hour")),Option("8h",window.t("The last 8 hours")),Option("24h",window.t("The last 24 hours")),Option("48h",window.t("The last 2 days")),Option("168h",window.t("The last 7 days")),Option("today",window.t("Today")),Option("yesterday",window.t("Yesterday")),Option("all",window.tn(Days.length,"Every day kept (%d), from %s","Every day kept (%d), from %s").replace("%s",window.dateText(Oldest))),Option("custom",window.t("Between two moments…")));
      One = pas.Admin_List.C.el("optgroup");
      One["label"] = window.t("One day");
      for (var $l = 0, $end = Days.length - 1; $l <= $end; $l++) {
        I = $l;
        One.appendChild(Option(Days[I],window.dateText(Days[I])));
      };
      Pick.appendChild(One);
      Pick.value = Choice;
      if (Pick.value !== Choice) {
        Choice = "24h";
        Pick.value = Choice;
      };
    };
    function WindowOf() {
      var Result = null;
      var Minute = 0.0;
      var A = 0.0;
      var B = 0.0;
      var Oldest = undefined;
      Minute = Math.floor(Date.now() / 60000) * 60000;
      if (pas.Admin_List.Regex("^\\d+h$",Choice)) return pas.JS.New(["from",Iso((Minute + 59000) - (parseInt(Choice,10) * 3600e3)),"to",Iso(Minute + 59000)]);
      if (Choice === "today") return pas.JS.New(["from",Iso(LocalMidnight(0)),"to",Iso(Minute + 59000)]);
      if (Choice === "yesterday") return pas.JS.New(["from",Iso(LocalMidnight(1)),"to",Iso(LocalMidnight(0) - 1000)]);
      if (Choice === "all") {
        if (Days.length > 0) {
          Oldest = Days[Days.length - 1]}
         else Oldest = UtcDay(0);
        return pas.JS.New(["from",Oldest,"to",UtcDay(0)]);
      };
      if (Choice === "custom") {
        if (FromBox.value !== "") {
          A = (new Date(FromBox.value)).getTime()}
         else A = Minute - 864e5;
        if (ToBox.value !== "") {
          B = (new Date(ToBox.value)).getTime()}
         else B = Minute + 59000;
        if (A <= B) return pas.JS.New(["from",Iso(A),"to",Iso(B)]);
        return pas.JS.New(["from",Iso(B),"to",Iso(A)]);
      };
      Result = pas.JS.New(["from",Choice,"to",Choice]);
      return Result;
    };
    function PeriodNow() {
      var Result = null;
      Result = Period;
      return Result;
    };
    function ShowAddress(Ip) {
      ShownIp = pas.Admin_List.Either(Ip,"").trim();
      AddrInput.value = ShownIp;
      AddrPanel.hidden = ShownIp === "";
      if (ShownIp !== "") pas.Admin_Address.AddressPanel(ShownIp,AddrPanel,PeriodNow);
    };
    function OpenAddress(Ip) {
      Subs.select("address");
      ShowAddress(Ip);
    };
    function Hold(Held) {
      Pick.disabled = Held;
      Tick.disabled = Held;
      Again["disabled"] = Held;
    };
    async function Load() {
      var Mine = 0;
      var I = 0;
      var R = null;
      var Why = "";
      var Problem = null;
      Loads += 1;
      Mine = Loads;
      Period = WindowOf();
      for (I = 0; I <= 8; I++) pas.Admin_List.C.waiting(Subs.holder(ReportParts[I]),window.t("Reading the log…"));
      Hold(true);
      try {
        try {
          if (HideMe) {
            R = await pas.Admin_List.C.get("/api/admin/visitors/report?from=" + pas.Admin_List.C.enc(Period["from"]) + "&to=" + pas.Admin_List.C.enc(Period["to"]) + "&hide=me")}
           else R = await pas.Admin_List.C.get("/api/admin/visitors/report?from=" + pas.Admin_List.C.enc(Period["from"]) + "&to=" + pas.Admin_List.C.enc(Period["to"]));
          if (Mine !== Loads) return;
          if (JSON.stringify(Days) !== JSON.stringify(R["days"])) {
            Days = R["days"];
            FillPeriods();
            if (!pas.Admin_List.Same(WindowOf()["from"],Period["from"])) {
              Load();
              return;
            };
          };
          $mod.DrawVisitReport(Subs,R,Pick,HideMe,undefined);
          if (Boolean(R["found"])) {
            $impl.DrawLatest(Subs.holder("latest"),R);
            $impl.DrawConcerns(Subs.holder("concerns"),R,PeriodNow);
          };
          if (ShownIp !== "") ShowAddress(ShownIp);
          if (Boolean(pas.Admin_List.S["blocksChanged"])) pas.Admin_List.S.blocksChanged();
        } catch ($e) {
          if (Mine !== Loads) return;
          Problem = $e;
          if (Boolean(Problem) && Boolean(Problem["message"]) && (Problem["message"].length < 300) && !pas.Admin_List.Regex("[<>]",Problem["message"])) {
            Why = " " + ("" + Problem["message"])}
           else Why = "";
          for (I = 0; I <= 8; I++) Subs.holder(ReportParts[I]).replaceChildren(pas.Admin_List.C.el("p","notice",window.t("The access log could not be read.") + Why));
        };
      } finally {
        if (Mine === Loads) Hold(false);
      };
    };
    async function ReadCounts() {
      var Data = null;
      try {
        Data = await pas.Admin_List.C.get("/api/admin/visitors");
        Subs.holder("counts").replaceChildren();
        $impl.DrawVisitCounts(Subs.holder("counts"),Data);
      } catch ($e) {
        Subs.holder("counts").replaceChildren(pas.Admin_List.C.el("p","notice",$e["message"]));
      };
    };
    if (Boolean(pas.Admin_List.S["adminCan"]) && !pas.Admin_List.S.adminCan("view-visitors")) {
      $impl.AdminBlocks(Box,function () {
        var Result = null;
        Result = pas.JS.New(["from",UtcDay(1),"to",UtcDay(0)]);
        return Result;
      });
      return;
    };
    HideMe = true;
    try {
      HideMe = window.localStorage.getItem("admin-hide-me") !== "off";
    } catch ($e) {
    };
    Choice = "24h";
    try {
      Choice = "" + pas.Admin_List.Either(window.localStorage.getItem("admin-visit-window"),"24h");
    } catch ($e) {
    };
    Days = new Array();
    Controls = pas.Admin_List.C.el("div","visit-controls");
    PickLabel = pas.Admin_List.C.el("label","",window.t("Period") + " ");
    Pick = pas.Admin_List.C.el("select");
    PickLabel.appendChild(Pick);
    Custom = pas.Admin_List.C.el("span","visit-custom");
    FromBox = pas.Admin_List.C.el("input");
    ToBox = pas.Admin_List.C.el("input");
    ToBox.type = "datetime-local";
    FromBox.type = "datetime-local";
    FromBox.setAttribute("aria-label",window.t("From"));
    ToBox.setAttribute("aria-label",window.t("To"));
    FromBox.value = Local(Date.now() - 864e5);
    ToBox.value = Local(Date.now());
    Custom.append(FromBox," – ",ToBox);
    Custom.hidden = Choice !== "custom";
    FillPeriods();
    Period = WindowOf();
    TickLabel = pas.Admin_List.C.el("label","visit-tick");
    Tick = pas.Admin_List.C.el("input");
    Tick.type = "checkbox";
    Tick.checked = HideMe;
    TickLabel.append(Tick," " + window.t("Hide my visits"));
    Tick.addEventListener("change",function (E) {
      HideMe = Tick.checked;
      try {
        if (HideMe) {
          window.localStorage.setItem("admin-hide-me","on")}
         else window.localStorage.setItem("admin-hide-me","off");
      } catch ($e) {
      };
      Load();
    });
    Again = pas.Admin_List.C.el("button","small-link",window.t("Refresh"));
    Again["type"] = "button";
    Again.addEventListener("click",function (E) {
      Load();
    });
    Controls.append(PickLabel,Custom,TickLabel,Again);
    Box.appendChild(Controls);
    TabList = Array.of(pas.JS.New(["key","overview","title",window.t("Overview")]),pas.JS.New(["key","people","title",window.t("People")]),pas.JS.New(["key","pages","title",window.t("Pages")]),pas.JS.New(["key","searches","title",window.t("Searches")]),pas.JS.New(["key","members","title",window.t("Members")]),pas.JS.New(["key","crawlers","title",window.t("Known crawlers")]),pas.JS.New(["key","bots","title",window.t("Bots")]),pas.JS.New(["key","concerns","title",window.t("Of concern")]),pas.JS.New(["key","latest","title",window.t("Latest requests")]),pas.JS.New(["key","address","title",window.t("Address")]));
    Blocks = Boolean(pas.Admin_List.S["adminCan"]) && pas.Admin_List.S.adminCan("manage-blocks");
    if (Blocks) TabList.push(pas.JS.New(["key","blocked","title",window.t("Blocked")]));
    TabList.push(pas.JS.New(["key","counts","title",window.t("By part of the site")]));
    Subs = pas.Admin_List.C.subTabs(Box,"visitors",TabList);
    AddrBox = Subs.holder("address");
    AddrForm = pas.Admin_List.C.el("form","visit-lookup");
    AddrInput = pas.Admin_List.C.el("input");
    AddrInput.type = "search";
    AddrInput.placeholder = window.t("An address, such as 203.0.113.9");
    AddrInput.setAttribute("aria-label",window.t("Address"));
    AddrGo = pas.Admin_List.C.el("button","",window.t("Look up"));
    AddrForm.append(AddrInput,AddrGo);
    AddrPanel = pas.Admin_List.C.el("div","lv-detail visit-address");
    AddrPanel.hidden = true;
    AddrBox.append(pas.Admin_List.C.el("p","hint",window.t("Everything one address did in the period, whatever it said it was, with the guard’s facts and the block buttons. Pick an address anywhere in these lists, or type one.")),AddrForm,AddrPanel);
    ShownIp = "";
    AddrForm.addEventListener("submit",function (E) {
      E.preventDefault();
      ShowAddress(AddrInput.value);
    });
    pas.Admin_List.S["showAddress"] = OpenAddress;
    pas.Admin_List.S["blockLook"] = pas.Admin_List.S["showAddress"];
    Loads = 0;
    Pick.addEventListener("change",function (E) {
      Choice = Pick.value;
      try {
        window.localStorage.setItem("admin-visit-window",Choice);
      } catch ($e) {
      };
      Custom.hidden = Choice !== "custom";
      Load();
    });
    FromBox.addEventListener("change",function (E) {
      if (Choice === "custom") Load();
    });
    ToBox.addEventListener("change",function (E) {
      if (Choice === "custom") Load();
    });
    Load();
    if (Blocks) $impl.AdminBlocks(Subs.holder("blocked"),PeriodNow);
    pas.Admin_List.C.waiting(Subs.holder("counts"));
    ReadCounts();
  };
  var Keys = ["overview","people","pages","searches","members","crawlers","bots","concerns","latest"];
  this.DrawVisitReport = function (Subs, R, Pick, HideMe, HiddenSet) {
    var Box = null;
    var Pages = null;
    var Hint = "";
    var I = 0;
    for (I = 0; I <= 8; I++) Subs.holder(Keys[I]).replaceChildren();
    if (!Boolean(R["found"])) {
      for (I = 0; I <= 8; I++) Subs.holder(Keys[I]).appendChild(pas.Admin_List.C.el("p","dim",window.t("There is no log for that period.")));
      return;
    };
    if (pas.Admin_List.IsUndef(R["visitors_count"]) || (R["visitors_count"] == null)) {
      Subs.count("people",R["visitors"].length)}
     else Subs.count("people",R["visitors_count"]);
    if (pas.Admin_List.IsUndef(R["pages_count"]) || (R["pages_count"] == null)) {
      Subs.count("pages",R["pages"].length)}
     else Subs.count("pages",R["pages_count"]);
    Subs.count("searches",R["searches"].length);
    Subs.count("members",R["members"].length);
    Subs.count("crawlers",R["crawlers"].length);
    Subs.count("bots",R["bots"].length);
    Subs.count("concerns",pas.Admin_List.Either(R["concerns_count"],0));
    $impl.DrawVisitOverview(Subs,R,HideMe);
    $impl.DrawPeople(Subs.holder("people"),R);
    Box = Subs.holder("pages");
    Pages = R["pages"];
    if (Number(R["pages_count"]) > Pages.length) Box.appendChild(pas.Admin_List.C.el("p","hint",window.t("The %s pages read most are listed, of %s.",pas.Admin_List.LocaleNumber(Pages.length),pas.Admin_List.LocaleNumber(R["pages_count"]))));
    pas.Admin_List.ListView(Box,pas.JS.New(["id","v-pages","key",$impl.FieldOf("path"),"sort","-views","csv","pages-" + pas.Admin_List.WindowName(R),"search",window.t("Filter pages"),"rows",Pages,"columns",Array.of($impl.Column("path",window.t("Page"),"",null,$impl.PageOf("path"),""),$impl.Column("views",window.t("Views"),"n",null,null,""),$impl.Column("people",window.t("People"),"n",null,null,"")),"filters",Array.of($impl.Filter("section",window.t("Part of the site"),window.t("The whole site"),function (Rows) {
      var Result = undefined;
      Result = pas.Admin_List.SectionOptions($impl.Column2(Rows,"path"));
      return Result;
    },function (P, K) {
      var Result = undefined;
      Result = pas.Admin_List.SectionOf(P["path"]) === K;
      return Result;
    })),"noun",$impl.Noun("%d page","%d pages"),"empty",window.t("Nothing yet.")]));
    Box = Subs.holder("searches");
    Hint = window.t("What people typed in the search boxes and pages. A box that searches as one types counts once, with the words as they ended.");
    if (Boolean(HideMe)) Hint = Hint + " " + window.t("Your own searches are left out while Hide my visits is ticked.");
    Box.appendChild(pas.Admin_List.C.el("p","hint",Hint));
    pas.Admin_List.ListView(Box,pas.JS.New(["id","v-searches","key",function (Search) {
      var Result = undefined;
      Result = "" + Search["where"] + ("" + Search["words"]);
      return Result;
    },"sort","-count","search",window.t("Filter searches"),"rows",R["searches"],"columns",Array.of($impl.Column("where",window.t("Where"),"",function (Search) {
      var Result = undefined;
      Result = pas.Admin_List.PlaceName(Search["where"]);
      return Result;
    },null,""),$impl.Column("words",window.t("Words"),"",null,null,""),$impl.Column("count",window.t("Times"),"n",null,null,""),$impl.Column("last",window.t("Last searched"),"d",null,$impl.StampOf("last"),"")),"filters",Array.of($impl.Filter("where",window.t("Where"),window.t("Everywhere"),function (Rows) {
      var Result = undefined;
      var Places = null;
      var Choices = null;
      var N = 0;
      Places = $impl.Distinct($impl.Column2(Rows,"where"));
      Choices = new Array();
      for (var $l = 0, $end = Places.length - 1; $l <= $end; $l++) {
        N = $l;
        Choices.push($impl.Pair(Places[N],pas.Admin_List.PlaceName(Places[N])));
      };
      Result = Choices;
      return Result;
    },function (Search, K) {
      var Result = undefined;
      Result = pas.Admin_List.Same(Search["where"],K);
      return Result;
    })),"noun",$impl.Noun("%d search","%d searches"),"empty",window.t("Nobody searched in that period.")]));
    Box = Subs.holder("members");
    pas.Admin_List.ListView(Box,pas.JS.New(["id","v-members","key",$impl.FieldOf("name"),"sort","-pages","search",false,"rows",R["members"],"columns",Array.of($impl.Column("name",window.t("Member"),"",null,function (M) {
      var Result = undefined;
      Result = $impl.MemberLink(M["name"]);
      return Result;
    },""),$impl.Column("pages",window.t("Pages"),"n",null,null,""),$impl.Column("last",window.t("Last seen"),"d",null,$impl.StampOf("last"),"")),"noun",$impl.Noun("%d member","%d members"),"empty",window.t("No member was signed in during that period.")]));
    $impl.DrawCrawlers(Subs.holder("crawlers"),R);
    $impl.DrawBots(Subs.holder("bots"),R);
  };
  $mod.$implcode = function () {
    $impl.Column = function (Key, Title, Flags, Value, Cell, Cls) {
      var Result = null;
      Result = pas.JS.New(["key",Key,"title",Title]);
      if (pas.System.Pos("n",Flags) > 0) Result["num"] = true;
      if (pas.System.Pos("w",Flags) > 0) Result["wide"] = true;
      if (pas.System.Pos("d",Flags) > 0) Result["down"] = true;
      if (pas.System.Pos("s",Flags) > 0) Result["nosort"] = true;
      if (Cls !== "") Result["cls"] = Cls;
      if (Value != null) Result["value"] = Value;
      if (Cell != null) Result["cell"] = Cell;
      return Result;
    };
    $impl.Filter = function (Key, Title, All, Options, Test) {
      var Result = null;
      Result = pas.JS.New(["key",Key,"title",Title,"all",All,"options",Options,"test",Test]);
      return Result;
    };
    $impl.Noun = function (One, Many) {
      var Result = null;
      Result = function (N) {
        var Result = undefined;
        Result = window.tn(N,One,Many);
        return Result;
      };
      return Result;
    };
    $impl.FieldOf = function (Key) {
      var Result = null;
      Result = function (R) {
        var Result = undefined;
        Result = R[Key];
        return Result;
      };
      return Result;
    };
    $impl.StampOf = function (Key) {
      var Result = null;
      Result = function (R) {
        var Result = undefined;
        Result = pas.Admin_List.Stamp(R[Key]);
        return Result;
      };
      return Result;
    };
    $impl.PageOf = function (Key) {
      var Result = null;
      Result = function (R) {
        var Result = undefined;
        Result = pas.Admin_List.PageLink(R[Key]);
        return Result;
      };
      return Result;
    };
    $impl.MemberLink = function (Name) {
      var Result = null;
      Result = pas.Admin_List.C.link("/u/" + pas.Admin_List.C.enc(Name),"",Name);
      return Result;
    };
    $impl.MemberOf = function (R) {
      var Result = undefined;
      if (Boolean(R["member"])) {
        Result = $impl.MemberLink(R["member"])}
       else Result = "";
      return Result;
    };
    $impl.BrowserOfRow = function (R) {
      var Result = undefined;
      Result = pas.Admin_List.BrowserOf(R["agent"]);
      return Result;
    };
    $impl.Pair = function (A, B) {
      var Result = null;
      Result = Array.of(A,B);
      return Result;
    };
    $impl.Distinct = function (Values) {
      var Result = null;
      Result = Array.from(new Set(Values));
      return Result;
    };
    $impl.Column2 = function (Rows, Key) {
      var Result = null;
      var I = 0;
      Result = new Array();
      for (var $l = 0, $end = Rows.length - 1; $l <= $end; $l++) {
        I = $l;
        Result.push(Rows[I][Key]);
      };
      return Result;
    };
    $impl.AsChoices = function (Values) {
      var Result = null;
      var I = 0;
      Result = new Array();
      for (var $l = 0, $end = Values.length - 1; $l <= $end; $l++) {
        I = $l;
        Result.push($impl.Pair(Values[I],Values[I]));
      };
      return Result;
    };
    $impl.Counted = function (Seen, Kinds) {
      var Result = null;
      var Pairs = null;
      var Name = undefined;
      var I = 0;
      Pairs = pas.Admin_List.SortBy(Array.from(Seen),function (A, B) {
        var Result = 0.0;
        Result = Number(B[1]) - Number(A[1]);
        return Result;
      });
      Result = new Array();
      for (var $l = 0, $end = Pairs.length - 1; $l <= $end; $l++) {
        I = $l;
        Name = Pairs[I][0];
        if (Kinds !== null) {
          Result.push($impl.Pair(Name,"" + pas.Admin_List.Either(Kinds["" + Name],Name) + " (" + ("" + Pairs[I][1]) + ")"))}
         else Result.push($impl.Pair(Name,"" + Name + " (" + ("" + Pairs[I][1]) + ")"));
      };
      return Result;
    };
    $impl.Count = function (Seen, Key) {
      Seen.set(Key,Number(pas.Admin_List.Either(Seen.get(Key),0)) + 1);
    };
    $impl.RequestWords = function (N) {
      var Result = undefined;
      Result = window.tn(N,"%d request","%d requests");
      return Result;
    };
    $impl.Pixels = function (Share, Least) {
      var Result = "";
      Result = String(Math.max(Least,Math.round(Share))) + "px";
      return Result;
    };
    $impl.AdminBlocks = function (Box, Period) {
      var Tiles = null;
      var StateWords = null;
      var List = null;
      function StateOf(B) {
        var Result = "";
        if (Boolean(B["for_good"])) {
          Result = "forgood"}
         else if (Boolean(B["active"])) {
          Result = "blocked"}
         else Result = "over";
        return Result;
      };
      async function Show() {
        var Result = undefined;
        var Rows = null;
        var Active = 0;
        Rows = await pas.Admin_List.C.get("/api/blocks");
        Tiles.replaceChildren();
        Active = Rows.filter(function (B, Index, All) {
          var Result = false;
          Result = Boolean(B["active"]);
          return Result;
        }).length;
        pas.Admin_List.Stat(Tiles,Active,window.t("Blocked right now"),undefined,undefined);
        pas.Admin_List.Stat(Tiles,Rows.filter(function (B, Index, All) {
          var Result = false;
          Result = Boolean(B["for_good"]);
          return Result;
        }).length,window.t("For good"),undefined,undefined);
        pas.Admin_List.Stat(Tiles,Rows.length - Active,window.t("Over, still listed"),undefined,undefined);
        List.set(Rows);
        return Result;
      };
      function BlocksChanged() {
        Show().catch(function (Why) {
          var Result = undefined;
          return Result;
        });
      };
      Tiles = pas.Admin_List.C.el("div","tiles-admin");
      Box.replaceChildren(pas.Admin_List.C.el("p","hint",window.t("An address that asks for six missing pages in a minute, or gets ten passwords wrong in a quarter hour, is shut out for an hour; after three times, for thirty days. Published crawlers, checked against the addresses their companies publish, are never limited or blocked; a browser string that claims to be one of them from another address is refused. This network and the addresses in Settings, allowed_ips, are never blocked either. Allow adds an address there. With an AbuseIPDB key in Settings, an address that probes or guesses passwords here is looked up on AbuseIPDB and reported back, and blocked for good when its confidence of abuse is at the set level or above. Type an address to see its story, or to block it by hand.")),Tiles);
      StateWords = pas.JS.New(["forgood",window.t("For good"),"blocked",window.t("Blocked now"),"over",window.t("Over")]);
      List = pas.Admin_List.ListView(Box,pas.JS.New(["id","blocks","key",$impl.FieldOf("ip"),"sort","-when","csv","blocked","search",window.t("Filter, or type an address and press Enter to look it up"),"enter",function (Ip) {
        if (Boolean(Ip)) pas.Admin_List.LookUpAddress(Ip);
      },"columns",Array.of($impl.Column("ip",window.t("Address"),"",null,function (B) {
        var Result = undefined;
        Result = pas.Admin_List.C.el("b","lv-ip",B["ip"]);
        return Result;
      },""),$impl.Column("state",window.t("State"),"",function (B) {
        var Result = undefined;
        Result = StateWords[StateOf(B)];
        return Result;
      },function (B) {
        var Result = undefined;
        if (StateOf(B) === "over") {
          Result = pas.Admin_List.C.chip(StateWords[StateOf(B)],"")}
         else Result = pas.Admin_List.C.chip(StateWords[StateOf(B)],"bad");
        return Result;
      },""),$impl.Column("reason",window.t("Why"),"",null,null,""),$impl.Column("times",window.t("Times"),"n",null,null,""),$impl.Column("when",window.t("Last change"),"dw",null,function (B) {
        var Result = undefined;
        Result = window.dateTimeText(B["when"]);
        return Result;
      },""),$impl.Column("until",window.t("Until"),"w",null,function (B) {
        var Result = undefined;
        if (Boolean(B["for_good"])) {
          Result = window.t("for good")}
         else Result = window.dateTimeText(B["until"]);
        return Result;
      },"")),"filters",Array.of($impl.Filter("state",window.t("State"),window.t("Every state"),Array.of($impl.Pair("blocked",window.t("Blocked now")),$impl.Pair("forgood",window.t("For good")),$impl.Pair("over",window.t("Over"))),function (B, V) {
        var Result = undefined;
        if (V === "forgood") {
          Result = B["for_good"]}
         else if (V === "blocked") {
          Result = B["active"]}
         else Result = !Boolean(B["active"]);
        return Result;
      }),$impl.Filter("reason",window.t("Why"),window.t("Every reason"),function (Rows) {
        var Result = undefined;
        var Seen = null;
        var I = 0;
        Seen = new Map();
        for (var $l = 0, $end = Rows.length - 1; $l <= $end; $l++) {
          I = $l;
          $impl.Count(Seen,Rows[I]["reason"]);
        };
        Result = $impl.Counted(Seen,null);
        return Result;
      },function (B, V) {
        var Result = undefined;
        Result = pas.Admin_List.Same(B["reason"],V);
        return Result;
      })),"rowClass",function (B) {
        var Result = undefined;
        if (Boolean(B["active"])) {
          Result = ""}
         else Result = "done";
        return Result;
      },"noun",$impl.Noun("%d address","%d addresses"),"empty",window.t("Nobody is blocked."),"detail",function (B, Holder, View) {
        pas.Admin_Address.AddressPanel(B["ip"],Holder,Period);
      }]));
      pas.Admin_List.S["blocksChanged"] = BlocksChanged;
      Show().catch(function (Why) {
        var Result = undefined;
        List.failed(Why["message"]);
        return Result;
      });
    };
    $impl.PersonDetail = function (V, Holder, Period) {
      var Head = null;
      var Acts = null;
      var Trail = null;
      var From = undefined;
      async function Read() {
        var A = null;
        try {
          A = await pas.Admin_List.C.get("/api/admin/access?n=1000&ip=" + pas.Admin_List.C.enc(V["ip"]) + "&agent=" + pas.Admin_List.C.enc(V["agent"]) + "&from=" + pas.Admin_List.C.enc(Period["from"]) + "&to=" + pas.Admin_List.C.enc(Period["to"]));
          Trail.replaceChildren();
          pas.Admin_List.ListView(Trail,pas.JS.New(["id","v-trail","key",function (L) {
            var Result = undefined;
            Result = "" + L["at"] + ("" + L["path"]);
            return Result;
          },"sort","-at","search",window.t("Filter their requests"),"page",200,"rows",A["lines"],"columns",Array.of($impl.Column("at",window.t("When"),"d",null,$impl.StampOf("at"),""),$impl.Column("method",window.t("Method"),"w",null,null,""),$impl.Column("path",window.t("Page"),"",null,$impl.PageOf("path"),""),$impl.Column("status",window.t("Status"),"n",null,function (L) {
            var Result = undefined;
            Result = pas.Admin_List.StatusCell(L["status"]);
            return Result;
          },""),$impl.Column("ms",window.t("Took"),"nw",null,function (L) {
            var Result = undefined;
            Result = pas.Admin_List.MsCell(L["ms"]);
            return Result;
          },""),$impl.Column("from",window.t("From"),"w",function (L) {
            var Result = undefined;
            Result = pas.Admin_List.HostOf(L["referer"]);
            return Result;
          },null,"")),"filters",Array.of(pas.JS.New(["key","kind","title",window.t("Which"),"all",window.t("Every request"),"value","people","options",Array.of($impl.Pair("people",window.t("Pages they read")),$impl.Pair("other",window.t("Everything else"))),"test",function (L, K) {
            var Result = undefined;
            if (pas.Admin_List.Same(L["method"],"GET") && pas.Admin_List.IsPagePath(L["path"])) {
              Result = K === "people"}
             else Result = K === "other";
            return Result;
          }])),"noun",$impl.Noun("%d request","%d requests")]));
        } catch ($e) {
          Trail.replaceChildren(pas.Admin_List.C.el("p","dim",window.t("The access log could not be read.")));
        };
      };
      Head = pas.Admin_List.C.el("div","lv-detail-head");
      Head.appendChild(pas.Admin_List.C.el("b","",V["ip"]));
      if (Boolean(V["member"])) Head.appendChild($impl.MemberLink(V["member"]));
      Head.appendChild(pas.Admin_List.C.el("span","dim",pas.Admin_List.BrowserOf(V["agent"])));
      if (Boolean(V["flagged"])) Head.appendChild(pas.Admin_List.C.chip(window.t("Of concern"),"open"));
      Holder.appendChild(Head);
      if (Boolean(V["referer"])) {
        From = pas.Admin_List.OutLink(V["referer"])}
       else From = window.t("typed in, a bookmark, or not said");
      pas.Admin_List.C.facts(Holder,Array.of($impl.Pair(window.t("First seen"),pas.Admin_List.Stamp(V["first"])),$impl.Pair(window.t("Last seen"),pas.Admin_List.Stamp(V["last"])),$impl.Pair(window.t("Pages"),V["pages"]),$impl.Pair(window.t("Requests"),V["requests"]),$impl.Pair(window.t("Open tab checks"),pas.Admin_List.Either(V["polls"],0)),$impl.Pair(window.t("Came in on"),pas.Admin_List.PageLink(V["entry"])),$impl.Pair(window.t("From"),From),$impl.Pair(window.t("Browser"),V["agent"])));
      Acts = pas.Admin_List.C.el("div","lv-actions");
      Acts.appendChild(pas.Admin_List.LookButton(V["ip"]));
      Holder.appendChild(Acts);
      Holder.appendChild(pas.Admin_List.C.el("h3","",window.t("What they asked for in the period")));
      Trail = pas.Admin_List.C.el("div");
      Holder.appendChild(Trail);
      pas.Admin_List.C.waiting(Trail,window.t("Reading the log…"));
      Read();
    };
    $impl.DrawVisitOverview = function (Subs, R, HideMe) {
      var Box = null;
      var Tiles = null;
      var Worry = null;
      var Days = null;
      var Bar = null;
      var Caption = null;
      var Two = null;
      var Left = null;
      var Right = null;
      var ByDay = null;
      var Rows = null;
      var Pages = null;
      var Referers = null;
      var Searches = null;
      var Values = null;
      var D = null;
      var P = null;
      var Top = 0.0;
      var Name = undefined;
      var I = 0;
      Box = Subs.holder("overview");
      Tiles = pas.Admin_List.C.el("div","tiles-admin");
      pas.Admin_List.Stat(Tiles,R["people"],window.t("People"),window.t("a browser that took the page whole, not a bot"),undefined);
      pas.Admin_List.Stat(Tiles,R["people_pages"],window.t("Pages they read"),undefined,undefined);
      pas.Admin_List.Stat(Tiles,R["bot_requests"],window.t("Bot requests"),window.tn(R["bots"].length,"%d bot or crawler","%d bots and crawlers"),undefined);
      pas.Admin_List.Stat(Tiles,R["members_seen"],window.t("Members signed in"),undefined,undefined);
      if (Boolean(R["concerns_count"])) {
        Worry = pas.Admin_List.Stat(Tiles,pas.Admin_List.Either(R["concerns_count"],0),window.t("Addresses of concern"),window.tn(pas.Admin_List.Either(R["addresses"],0),"of %d address","of %d addresses"),"warn")}
       else Worry = pas.Admin_List.Stat(Tiles,pas.Admin_List.Either(R["concerns_count"],0),window.t("Addresses of concern"),window.tn(pas.Admin_List.Either(R["addresses"],0),"of %d address","of %d addresses"),"");
      Worry.style["cursor"] = "pointer";
      Worry.title = window.t("See the Of concern tab");
      Worry.addEventListener("click",function (E) {
        Subs.select("concerns");
      });
      if (Boolean(HideMe)) pas.Admin_List.Stat(Tiles,R["hidden_requests"],window.t("Your requests left out"),window.tn(R["hidden_addresses"],"from %d address","from %d addresses"),undefined);
      Box.appendChild(Tiles);
      ByDay = pas.Admin_List.Either(R["by_day"],new Array());
      if (ByDay.length > 1) {
        Top = pas.Admin_List.MostOf($impl.Column2(ByDay,"pages"));
        Days = pas.Admin_List.C.el("div","days");
        for (var $l = 0, $end = ByDay.length - 1; $l <= $end; $l++) {
          I = $l;
          D = ByDay[I];
          Bar = pas.Admin_List.C.el("i");
          Bar.style["height"] = $impl.Pixels((66 * Number(D["pages"])) / Top,2);
          Bar.title = window.dateText(D["day"]) + ": " + window.tn(D["pages"],"%d page","%d pages") + ", " + window.tn(D["people"],"%d person","%d people");
          Days.appendChild(Bar);
        };
        Box.appendChild(Days);
        Caption = pas.Admin_List.C.el("div","days-caption");
        Caption.append(pas.Admin_List.C.el("span","",window.dateText(ByDay[0]["day"])),pas.Admin_List.C.el("span","",window.t("pages people read, day by day")),pas.Admin_List.C.el("span","",window.dateText(ByDay[ByDay.length - 1]["day"])));
        Box.appendChild(Caption);
      };
      pas.Admin_Address.TimelineChart(Box,R["timeline"],false);
      Two = pas.Admin_List.C.el("div","visit-two");
      Left = pas.Admin_List.C.el("div");
      Right = pas.Admin_List.C.el("div");
      Two.append(Left,Right);
      Box.appendChild(Two);
      Left.appendChild(pas.Admin_List.C.el("h3","",window.t("What people read most")));
      Pages = R["pages"];
      if (Pages.length > 0) {
        Rows = Pages.slice(0,12);
        Values = new Array();
        for (var $l1 = 0, $end1 = Rows.length - 1; $l1 <= $end1; $l1++) {
          I = $l1;
          P = Rows[I];
          Name = P["path"];
          try {
            Name = decodeURIComponent("" + Name);
          } catch ($e) {
          };
          Values.push(pas.JS.New(["name",Name,"value",P["views"]]));
        };
        pas.Admin_List.Bars(Left,Values,function (N) {
          var Result = undefined;
          Result = window.tn(N,"%d view","%d views");
          return Result;
        });
      } else Left.appendChild(pas.Admin_List.C.el("p","dim",window.t("Nothing yet.")));
      Right.appendChild(pas.Admin_List.C.el("h3","",window.t("Where they came from")));
      Referers = R["referers"];
      if (Referers.length > 0) {
        Rows = Referers.slice(0,12);
        Values = new Array();
        for (var $l2 = 0, $end2 = Rows.length - 1; $l2 <= $end2; $l2++) {
          I = $l2;
          Values.push(pas.JS.New(["name",Rows[I]["host"],"value",Rows[I]["views"]]));
        };
        pas.Admin_List.Bars(Right,Values,function (N) {
          var Result = undefined;
          Result = window.tn(N,"%d page","%d pages");
          return Result;
        });
      } else Right.appendChild(pas.Admin_List.C.el("p","dim",window.t("Nobody came by a link in that period.")));
      Searches = R["searches"];
      if (Searches.length > 0) {
        Box.appendChild(pas.Admin_List.C.el("h3","",window.t("What they searched for")));
        Rows = Searches.slice(0,10);
        Values = new Array();
        for (var $l3 = 0, $end3 = Rows.length - 1; $l3 <= $end3; $l3++) {
          I = $l3;
          Values.push(pas.JS.New(["name","" + Rows[I]["words"] + "  ·  " + ("" + pas.Admin_List.PlaceName(Rows[I]["where"])),"value",Rows[I]["count"]]));
        };
        pas.Admin_List.Bars(Box,Values,function (N) {
          var Result = undefined;
          Result = window.tn(N,"%d time","%d times");
          return Result;
        });
      };
    };
    $impl.DrawPeople = function (Box, R) {
      var Visitors = null;
      Box.appendChild(pas.Admin_List.C.el("p","hint",window.t("Each address with one browser. Bots are counted apart, under Bots. Pick a row for everything they asked for.")));
      Visitors = R["visitors"];
      if (Number(R["visitors_count"]) > Visitors.length) Box.appendChild(pas.Admin_List.C.el("p","hint",window.t("The %s who read the most are listed, of %s.",pas.Admin_List.LocaleNumber(Visitors.length),pas.Admin_List.LocaleNumber(R["visitors_count"]))));
      pas.Admin_List.ListView(Box,pas.JS.New(["id","v-people","key",function (V) {
        var Result = undefined;
        Result = "" + V["ip"] + " " + ("" + V["agent"]);
        return Result;
      },"sort","-pages","csv","people-" + pas.Admin_List.WindowName(R),"search",window.t("Filter by address, page, site or member"),"rows",Visitors,"columns",Array.of($impl.Column("last",window.t("Last seen"),"d",null,function (V) {
        var Result = undefined;
        var Seen = null;
        Seen = pas.Admin_List.C.el("span","",pas.Admin_List.Stamp(V["last"]));
        Seen.title = window.t("First seen %s",pas.Admin_List.Stamp(V["first"]));
        Result = Seen;
        return Result;
      },""),$impl.Column("ip",window.t("Address"),"",null,function (V) {
        var Result = undefined;
        Result = pas.Admin_List.AddressCell$1(V["ip"],V["flagged"]);
        return Result;
      },""),$impl.Column("member",window.t("Member"),"",null,$impl.MemberOf,""),$impl.Column("pages",window.t("Pages"),"n",null,null,""),$impl.Column("requests",window.t("Requests"),"nw",null,null,""),$impl.Column("entry",window.t("Came in on"),"",null,$impl.PageOf("entry"),""),$impl.Column("from",window.t("From"),"w",function (V) {
        var Result = undefined;
        Result = pas.Admin_List.HostOf(V["referer"]);
        return Result;
      },null,""),$impl.Column("browser",window.t("Browser"),"w",$impl.BrowserOfRow,null,"")),"filters",Array.of($impl.Filter("who",window.t("Who"),window.t("Everybody"),Array.of($impl.Pair("members",window.t("Members signed in")),$impl.Pair("guests",window.t("Not signed in")),$impl.Pair("concern",window.t("Of concern"))),function (V, K) {
        var Result = undefined;
        if (K === "members") {
          Result = Boolean(V["member"])}
         else if (K === "guests") {
          Result = !Boolean(V["member"])}
         else Result = Number(V["flagged"]) > 0;
        return Result;
      }),$impl.Filter("browser",window.t("Browser"),window.t("Every browser"),function (Rows) {
        var Result = undefined;
        var Names = null;
        var I = 0;
        Names = new Array();
        for (var $l = 0, $end = Rows.length - 1; $l <= $end; $l++) {
          I = $l;
          Names.push(pas.Admin_List.BrowserOf(Rows[I]["agent"]));
        };
        Result = $impl.AsChoices(pas.Admin_List.SortBy($impl.Distinct(Names),undefined));
        return Result;
      },function (V, K) {
        var Result = undefined;
        Result = pas.Admin_List.Same(pas.Admin_List.BrowserOf(V["agent"]),K);
        return Result;
      }),$impl.Filter("from",window.t("From"),window.t("From anywhere"),function (Rows) {
        var Result = undefined;
        var Hosts = null;
        var Host = "";
        var I = 0;
        Hosts = new Array();
        for (var $l = 0, $end = Rows.length - 1; $l <= $end; $l++) {
          I = $l;
          Host = pas.Admin_List.HostOf(Rows[I]["referer"]);
          if (Host !== "") Hosts.push(Host);
        };
        Result = Array.of($impl.Pair("-",window.t("No link (typed in or a bookmark)"))).concat($impl.AsChoices(pas.Admin_List.SortBy($impl.Distinct(Hosts),undefined)));
        return Result;
      },function (V, K) {
        var Result = undefined;
        if (K === "-") {
          Result = pas.Admin_List.HostOf(V["referer"]) === ""}
         else Result = pas.Admin_List.HostOf(V["referer"]) === K;
        return Result;
      })),"noun",$impl.Noun("%d person","%d people"),"empty",window.t("Nobody read a page in that period."),"detail",function (V, Holder, View) {
        $impl.PersonDetail(V,Holder,pas.JS.New(["from",R["from"],"to",R["to"]]));
      }]));
    };
    $impl.DrawCrawlers = function (Box, R) {
      var Crawlers = null;
      var Sources = null;
      var Pretenders = null;
      var Named = null;
      var Parts = null;
      var Pairs = null;
      var Keys = null;
      var Columns = null;
      var Shown = null;
      var Order = null;
      var DayList = null;
      var Series = null;
      var Counts = null;
      var Totals = null;
      var Crawler = null;
      var Days = null;
      var Legend = null;
      var Chart = null;
      var Wrap = null;
      var Table = null;
      var Head = null;
      var Th = null;
      var Lists = null;
      var Holder = null;
      var Most = 0.0;
      var Peak = 0.0;
      var I = 0;
      var J = 0;
      function PartsOf(Crawler) {
        var Result = null;
        Result = pas.Admin_List.Either(Crawler["parts"],new Object());
        return Result;
      };
      function PartOf(Crawler, K) {
        var Result = undefined;
        var Names = [];
        var N = 0.0;
        var X = 0;
        if (!pas.Admin_List.Same(K,"other")) return pas.Admin_List.Either(PartsOf(Crawler)["" + K],0);
        N = 0;
        Names = Object.keys(PartsOf(Crawler));
        for (var $l = 0, $end = rtl.length(Names) - 1; $l <= $end; $l++) {
          X = $l;
          if (Named.indexOf(Names[X]) < 0) N = N + Number(PartsOf(Crawler)[Names[X]]);
        };
        Result = N;
        return Result;
      };
      function PartColumn(P) {
        var Result = null;
        Result = $impl.Column("part-" + ("" + P[0]),P[1],"nw",function (Crawler) {
          var Result = undefined;
          Result = PartOf(Crawler,P[0]);
          return Result;
        },null,"");
        return Result;
      };
      function Sum(Counts) {
        var Result = 0.0;
        var N = 0;
        Result = 0;
        for (var $l = 0, $end = Counts.length - 1; $l <= $end; $l++) {
          N = $l;
          Result = Result + Number(Counts[N]);
        };
        return Result;
      };
      function ChartRow(Crawler) {
        var Name = null;
        var Bar = null;
        var Seg = null;
        var Track = null;
        var number = null;
        var Words = null;
        var P = null;
        var N = 0;
        Name = pas.Admin_List.C.el("span","name",Crawler["name"]);
        Name["title"] = Crawler["company"];
        Bar = pas.Admin_List.C.el("span","crawl-bar");
        Bar.style["width"] = String(Math.max(2,Math.round((100 * Number(Crawler["requests"])) / Most))) + "%";
        Words = new Array();
        for (var $l = 0, $end = Parts.length - 1; $l <= $end; $l++) {
          N = $l;
          P = Parts[N];
          Words.push("" + P[1] + " " + ("" + PartOf(Crawler,P[0])));
          if (!Boolean(PartOf(Crawler,P[0]))) continue;
          Seg = pas.Admin_List.C.el("i","crawl-c" + String(N + 1));
          Seg.style["flexGrow"] = PartOf(Crawler,P[0]);
          Seg.title = "" + P[1] + ": " + window.tn(PartOf(Crawler,P[0]),"%d request","%d requests");
          Bar.appendChild(Seg);
        };
        Track = pas.Admin_List.C.el("span","crawl-track");
        Track.appendChild(Bar);
        number = pas.Admin_List.C.el("span","num",pas.Admin_List.LocaleNumber(Crawler["requests"]));
        number.title = Words.join(" · ");
        Chart.append(Name,Track,number);
      };
      function HeatRow(One) {
        var Row = null;
        var Cell = null;
        var Counts = null;
        var N = undefined;
        var Share = 0.0;
        var X = 0;
        Row = pas.Admin_List.C.el("tr");
        Row.appendChild(pas.Admin_List.C.el("td","name",One["name"]));
        Counts = One["counts"];
        for (var $l = 0, $end = Counts.length - 1; $l <= $end; $l++) {
          X = $l;
          N = Counts[X];
          if (Boolean(N)) {
            Cell = pas.Admin_List.C.el("td","heat",pas.Admin_List.LocaleNumber(N))}
           else Cell = pas.Admin_List.C.el("td","heat","");
          if (Boolean(N)) {
            Share = Math.round(12 + ((88 * Math.log(1 + Number(N))) / Math.log(1 + Peak)))}
           else Share = 0;
          Cell.style.setProperty("--share",String(Share) + "%");
          if (Share > 55) Cell.classList.add("deep");
          Cell.title = "" + One["name"] + ", " + window.dateText(DayList[X]) + ": " + window.tn(N,"%d request","%d requests");
          Row.appendChild(Cell);
        };
        Table.appendChild(Row);
      };
      Sources = R["crawler_sources"];
      Box.appendChild(pas.Admin_List.C.el("p","hint",window.tn(Sources.length,"Found by the address ranges their companies publish (%d list, read once a day): a request from those addresses is that company's crawler, whatever its browser string says.","Found by the address ranges their companies publish (%d lists, read once a day): a request from those addresses is that company's crawler, whatever its browser string says.")));
      Crawlers = R["crawlers"];
      Totals = new Map();
      for (var $l = 0, $end = Crawlers.length - 1; $l <= $end; $l++) {
        I = $l;
        Crawler = Crawlers[I];
        Keys = Object.keys(PartsOf(Crawler));
        for (var $l1 = 0, $end1 = Keys.length - 1; $l1 <= $end1; $l1++) {
          J = $l1;
          Totals.set(Keys[J],Number(pas.Admin_List.Either(Totals.get(Keys[J]),0)) + Number(PartsOf(Crawler)["" + Keys[J]]));
        };
      };
      Pairs = pas.Admin_List.SortBy(Array.from(Totals).filter(function (X, Index, All) {
        var Result = false;
        Result = !pas.Admin_List.Same(X[0],"other");
        return Result;
      }),function (A, B) {
        var Result = 0.0;
        Result = Number(B[1]) - Number(A[1]);
        return Result;
      }).slice(0,3);
      Named = new Array();
      Parts = new Array();
      for (var $l2 = 0, $end2 = Pairs.length - 1; $l2 <= $end2; $l2++) {
        I = $l2;
        Named.push(Pairs[I][0]);
        Parts.push($impl.Pair(Pairs[I][0],pas.Admin_List.PartLabel(Pairs[I][0])));
      };
      Parts.push($impl.Pair("other",window.t("Other")));
      if (Crawlers.length === 0) {
        Box.appendChild(pas.Admin_List.C.el("p","dim",window.t("No known crawler came in that period.")))}
       else {
        Legend = pas.Admin_List.C.el("div","crawl-legend");
        for (var $l3 = 0, $end3 = Parts.length - 1; $l3 <= $end3; $l3++) {
          I = $l3;
          Th = pas.Admin_List.C.el("span");
          Th.append(pas.Admin_List.C.el("i","crawl-c" + String(I + 1))," " + ("" + Parts[I][1]));
          Legend.appendChild(Th);
        };
        Box.appendChild(Legend);
        Most = pas.Admin_List.MostOf($impl.Column2(Crawlers,"requests"));
        Chart = pas.Admin_List.C.el("div","crawl-chart");
        Shown = Crawlers.slice(0,20);
        for (var $l4 = 0, $end4 = Shown.length - 1; $l4 <= $end4; $l4++) {
          I = $l4;
          ChartRow(Shown[I]);
        };
        Box.appendChild(Chart);
        Columns = Array.of($impl.Column("name",window.t("Crawler"),"",null,null,""),$impl.Column("company",window.t("Company"),"",null,null,""),$impl.Column("requests",window.t("Requests"),"n",null,null,""));
        for (var $l5 = 0, $end5 = Parts.length - 1; $l5 <= $end5; $l5++) {
          I = $l5;
          Columns.push(PartColumn(Parts[I]));
        };
        Columns.push($impl.Column("addresses",window.t("Addresses"),"n",null,null,""),$impl.Column("last",window.t("Last seen"),"d",null,$impl.StampOf("last"),""));
        pas.Admin_List.ListView(Box,pas.JS.New(["id","v-crawlers","key",$impl.FieldOf("name"),"sort","-requests","csv","crawlers-" + pas.Admin_List.WindowName(R),"search",window.t("Filter crawlers"),"rows",Crawlers,"columns",Columns,"filters",Array.of($impl.Filter("company",window.t("Company"),window.t("Every company"),function (Rows) {
          var Result = undefined;
          Result = $impl.AsChoices(pas.Admin_List.SortBy($impl.Distinct($impl.Column2(Rows,"company")),undefined));
          return Result;
        },function (Crawler, K) {
          var Result = undefined;
          Result = pas.Admin_List.Same(Crawler["company"],K);
          return Result;
        })),"noun",$impl.Noun("%d crawler","%d crawlers"),"detail",function (Crawler, Holder, View) {
          var Top = null;
          var Names = [];
          var ByPart = null;
          var Paths = null;
          var Read = null;
          var N = 0;
          Top = pas.Admin_List.C.el("div","lv-detail-head");
          Top.append(pas.Admin_List.C.el("b","",Crawler["name"]),pas.Admin_List.C.el("span","dim",Crawler["company"]));
          Holder.appendChild(Top);
          Names = Object.keys(PartsOf(Crawler));
          ByPart = new Array();
          for (var $l6 = 0, $end6 = rtl.length(Names) - 1; $l6 <= $end6; $l6++) {
            N = $l6;
            ByPart.push("" + pas.Admin_List.PartLabel(Names[N]) + " " + ("" + PartsOf(Crawler)[Names[N]]));
          };
          pas.Admin_List.C.facts(Holder,Array.of($impl.Pair(window.t("Requests"),pas.Admin_List.LocaleNumber(Crawler["requests"])),$impl.Pair(window.t("Addresses"),Crawler["addresses"]),$impl.Pair(window.t("Last seen"),pas.Admin_List.Stamp(Crawler["last"])),$impl.Pair(window.t("By part"),ByPart.join(" · "))));
          Holder.appendChild(pas.Admin_List.C.el("h3","",window.t("What it read most")));
          Paths = Crawler["paths"];
          Read = new Array();
          for (var $l7 = 0, $end7 = Paths.length - 1; $l7 <= $end7; $l7++) {
            N = $l7;
            Read.push(pas.JS.New(["name",pas.Admin_List.Either(Paths[N]["path"],"/"),"value",Paths[N]["count"]]));
          };
          pas.Admin_List.Bars(Holder,Read,$impl.RequestWords);
        }]));
      };
      Days = R["crawler_days"];
      if (Boolean(Days) && (Days["series"].length > 0)) {
        Box.appendChild(pas.Admin_List.C.el("h3","",window.t("Day by day")));
        Series = Days["series"];
        Counts = new Array();
        for (var $l6 = 0, $end6 = Series.length - 1; $l6 <= $end6; $l6++) {
          I = $l6;
          Counts.push(Math.max.apply(null,Series[I]["counts"]));
        };
        Peak = pas.Admin_List.MostOf(Counts);
        Wrap = pas.Admin_List.C.el("div","gridwrap");
        Table = pas.Admin_List.C.el("table","grid crawl-days");
        Head = pas.Admin_List.C.el("tr");
        Head.appendChild(pas.Admin_List.C.el("th","",window.t("Crawler")));
        DayList = Days["days"];
        for (var $l7 = 0, $end7 = DayList.length - 1; $l7 <= $end7; $l7++) {
          I = $l7;
          Th = pas.Admin_List.C.el("th","",window.dateText(DayList[I]).replace(new RegExp("[-/.]?\\d{4}[-/.]?"),""));
          Th.title = window.dateText(DayList[I]);
          Head.appendChild(Th);
        };
        Table.appendChild(Head);
        Order = pas.Admin_List.SortBy(Series.slice(0),function (A, B) {
          var Result = 0.0;
          Result = Sum(B["counts"]) - Sum(A["counts"]);
          return Result;
        });
        for (var $l8 = 0, $end8 = Order.length - 1; $l8 <= $end8; $l8++) {
          I = $l8;
          HeatRow(Order[I]);
        };
        Wrap.appendChild(Table);
        Box.appendChild(Wrap);
      };
      Pretenders = R["pretenders"];
      if (Pretenders.length > 0) {
        Box.appendChild(pas.Admin_List.C.el("h3","",window.t("Pretending to be one of them")));
        Box.appendChild(pas.Admin_List.C.el("p","hint",window.t("These name a known crawler in their browser string but come from outside its company's published addresses.")));
        pas.Admin_List.ListView(Box,pas.JS.New(["id","v-pretenders","key",$impl.FieldOf("name"),"sort","-requests","search",false,"rows",Pretenders,"columns",Array.of($impl.Column("name",window.t("Says it is"),"",null,null,""),$impl.Column("company",window.t("Company"),"",null,null,""),$impl.Column("requests",window.t("Requests"),"n",null,null,""),$impl.Column("addresses",window.t("Addresses"),"n",null,null,""),$impl.Column("last",window.t("Last seen"),"d",null,$impl.StampOf("last"),""),$impl.Column("sample",window.t("For example"),"w",null,function (P) {
          var Result = undefined;
          Result = pas.Admin_List.AddressCell(P["sample"]);
          return Result;
        },"")),"noun",$impl.Noun("%d pretender","%d pretenders"),"detail",function (P, Holder, View) {
          pas.Admin_List.C.facts(Holder,Array.of($impl.Pair(window.t("Says it is"),"" + P["name"] + " (" + ("" + P["company"]) + ")"),$impl.Pair(window.t("Requests"),P["requests"]),$impl.Pair(window.t("For example"),pas.Admin_List.AddressCell(P["sample"]))));
        }]));
      };
      if (Sources.length > 0) {
        Lists = pas.Admin_List.C.el("details","crawl-sources");
        Lists.appendChild(pas.Admin_List.C.el("summary","",window.t("The published lists")));
        Holder = pas.Admin_List.C.el("div");
        Lists.appendChild(Holder);
        Box.appendChild(Lists);
        pas.Admin_List.ListView(Holder,pas.JS.New(["id","v-sources","key",$impl.FieldOf("url"),"sort","company","search",false,"rows",Sources,"columns",Array.of($impl.Column("company",window.t("Company"),"",null,null,""),$impl.Column("name",window.t("Crawler"),"",null,function (Source) {
          var Result = undefined;
          var A = null;
          A = pas.Admin_List.C.el("a","",Source["name"]);
          A["href"] = Source["url"];
          A["target"] = "_blank";
          A["rel"] = "noopener";
          Result = A;
          return Result;
        },""),$impl.Column("ranges",window.t("Ranges"),"n",null,null,""),$impl.Column("created",window.t("List dated"),"w",null,function (Source) {
          var Result = undefined;
          if (Boolean(Source["created"])) {
            Result = window.dateText(Source["created"])}
           else Result = "";
          return Result;
        },""),$impl.Column("fetched",window.t("Read"),"w",null,function (Source) {
          var Result = undefined;
          if (Boolean(Source["fetched"])) {
            Result = window.dateTimeText(Source["fetched"])}
           else Result = "";
          return Result;
        },""),$impl.Column("error",window.t("Problem"),"",null,null,"")),"noun",$impl.Noun("%d list","%d lists")]));
      };
    };
    $impl.DrawBots = function (Box, R) {
      var Checks = null;
      function CheckSpan(B, Words) {
        var Result = null;
        if (pas.Admin_List.Same(B["check"],"unverified")) {
          Result = pas.Admin_List.C.el("span","bot-bad",Words)}
         else Result = pas.Admin_List.C.el("span","bot-ok",Words);
        return Result;
      };
      Box.appendChild(pas.Admin_List.C.el("p","hint",window.t("Known by the name in their browser string, or because they asked for robots.txt. The big search engines are checked against their DNS: one that only claims the name shows as not verified.")));
      Checks = pas.JS.New(["listed","✓ " + window.t("Published address"),"verified","✓ " + window.t("Verified"),"unverified",window.t("Not verified")]);
      pas.Admin_List.ListView(Box,pas.JS.New(["id","v-bots","key",$impl.FieldOf("name"),"sort","-requests","csv","bots-" + pas.Admin_List.WindowName(R),"search",window.t("Filter bots"),"rows",R["bots"],"columns",Array.of($impl.Column("name",window.t("Bot"),"",null,null,""),$impl.Column("check",window.t("Checked"),"",function (B) {
        var Result = undefined;
        Result = pas.Admin_List.Either(Checks["" + B["check"]],"");
        return Result;
      },function (B) {
        var Result = undefined;
        if (Boolean(B["check"])) {
          Result = CheckSpan(B,pas.Admin_List.Either(Checks["" + B["check"]],B["check"]))}
         else Result = "";
        return Result;
      },""),$impl.Column("requests",window.t("Requests"),"n",null,null,""),$impl.Column("addresses",window.t("Addresses"),"n",null,null,""),$impl.Column("last",window.t("Last seen"),"d",null,$impl.StampOf("last"),""),$impl.Column("paths",window.t("Pages it asked for most"),"ws",function (B) {
        var Result = undefined;
        Result = B["paths"].join(" ");
        return Result;
      },function (B) {
        var Result = undefined;
        var Paths = null;
        var Words = null;
        var N = 0;
        Paths = B["paths"].slice(0,3);
        Words = new Array();
        for (var $l = 0, $end = Paths.length - 1; $l <= $end; $l++) {
          N = $l;
          Words.push(pas.Admin_List.Either(Paths[N],"/"));
        };
        Result = pas.Admin_List.C.el("span","dim",Words.join("  ·  "));
        return Result;
      },"lv-text")),"filters",Array.of($impl.Filter("check",window.t("Checked"),window.t("Checked or not"),Array.of($impl.Pair("listed",window.t("Published address")),$impl.Pair("verified",window.t("Verified")),$impl.Pair("unverified",window.t("Not verified")),$impl.Pair("-",window.t("Not checked"))),function (B, K) {
        var Result = undefined;
        if (K === "-") {
          Result = !Boolean(B["check"])}
         else Result = pas.Admin_List.Same(B["check"],K);
        return Result;
      })),"noun",$impl.Noun("%d bot","%d bots"),"empty",window.t("No bot came in that period."),"detail",function (B, Holder, View) {
        var Head = null;
        var List = null;
        var Line = null;
        var Paths = null;
        var Example = undefined;
        var N = 0;
        Head = pas.Admin_List.C.el("div","lv-detail-head");
        if (Boolean(B["check"])) {
          Head.append(pas.Admin_List.C.el("b","",B["name"]),CheckSpan(B,Checks["" + B["check"]]))}
         else Head.append(pas.Admin_List.C.el("b","",B["name"]),"");
        Holder.appendChild(Head);
        if (Boolean(B["sample"])) {
          Example = pas.Admin_List.AddressCell(B["sample"])}
         else Example = "";
        pas.Admin_List.C.facts(Holder,Array.of($impl.Pair(window.t("Requests"),pas.Admin_List.LocaleNumber(B["requests"])),$impl.Pair(window.t("Addresses"),B["addresses"]),$impl.Pair(window.t("For example"),Example),$impl.Pair(window.t("Last seen"),pas.Admin_List.Stamp(B["last"]))));
        Holder.appendChild(pas.Admin_List.C.el("h3","",window.t("Pages it asked for most")));
        List = pas.Admin_List.C.el("ul","lv-paths");
        Paths = B["paths"];
        for (var $l = 0, $end = Paths.length - 1; $l <= $end; $l++) {
          N = $l;
          Line = pas.Admin_List.C.el("li");
          Line.appendChild(pas.Admin_List.PageLink(pas.Admin_List.Either(Paths[N],"/")));
          List.appendChild(Line);
        };
        Holder.appendChild(List);
      }]));
    };
    $impl.DrawLatest = function (Box, R) {
      Box.appendChild(pas.Admin_List.C.el("p","hint",window.t("The latest thousand requests from people and four hundred from bots in the period, newest first. Pick an address for its whole story.")));
      pas.Admin_List.ListView(Box,pas.JS.New(["id","v-latest2","key",function (L) {
        var Result = undefined;
        Result = "" + L["at"] + ("" + L["ip"]) + ("" + L["path"]) + ("" + L["kind"]);
        return Result;
      },"sort","-at","csv","latest-" + pas.Admin_List.WindowName(R),"page",200,"search",window.t("Filter by address, page or member"),"rows",pas.Admin_List.Either(R["latest"],new Array()),"columns",Array.of($impl.Column("at",window.t("When"),"d",null,$impl.StampOf("at"),""),$impl.Column("ip",window.t("Address"),"",null,function (L) {
        var Result = undefined;
        Result = pas.Admin_List.AddressCell(L["ip"]);
        return Result;
      },""),$impl.Column("member",window.t("Member"),"",null,$impl.MemberOf,""),$impl.Column("path",window.t("Page"),"",null,$impl.PageOf("path"),""),$impl.Column("status",window.t("Status"),"n",null,function (L) {
        var Result = undefined;
        Result = pas.Admin_List.StatusCell(L["status"]);
        return Result;
      },""),$impl.Column("ms",window.t("Took"),"nw",null,function (L) {
        var Result = undefined;
        Result = pas.Admin_List.MsCell(L["ms"]);
        return Result;
      },""),$impl.Column("browser",window.t("Browser or bot"),"w",function (L) {
        var Result = undefined;
        Result = pas.Admin_List.Either(L["bot"],pas.Admin_List.BrowserOf(L["agent"]));
        return Result;
      },function (L) {
        var Result = undefined;
        var Seen = null;
        Seen = pas.Admin_List.C.el("span","dim",pas.Admin_List.Either(L["bot"],pas.Admin_List.BrowserOf(L["agent"])));
        Seen["title"] = L["agent"];
        Result = Seen;
        return Result;
      },"")),"filters",Array.of(pas.JS.New(["key","kind","title",window.t("Which"),"all",window.t("Every request"),"value","page","options",Array.of($impl.Pair("page",window.t("Pages people read")),$impl.Pair("other",window.t("Everything else people asked for")),$impl.Pair("bot",window.t("Bots"))),"test",function (L, K) {
        var Result = undefined;
        Result = pas.Admin_List.Same(L["kind"],K);
        return Result;
      }]),$impl.Filter("status",window.t("Status"),window.t("Any status"),Array.of($impl.Pair("ok",window.t("Answered")),$impl.Pair("4xx",window.t("Refused or not here")),$impl.Pair("5xx",window.t("Failed"))),function (L, K) {
        var Result = undefined;
        if (K === "ok") {
          Result = !(Number(L["status"]) >= 400)}
         else if (K === "4xx") {
          Result = (Number(L["status"]) >= 400) && (Number(L["status"]) < 500)}
         else Result = Number(L["status"]) >= 500;
        return Result;
      }),$impl.Filter("section",window.t("Part of the site"),window.t("The whole site"),function (Rows) {
        var Result = undefined;
        Result = pas.Admin_List.SectionOptions($impl.Column2(Rows,"path"));
        return Result;
      },function (L, K) {
        var Result = undefined;
        Result = pas.Admin_List.SectionOf(L["path"]) === K;
        return Result;
      })),"noun",$impl.Noun("%d request","%d requests"),"empty",window.t("Nothing in that period's logs yet."),"detail",function (L, Holder, View) {
        var Head = null;
        var Acts = null;
        var Answered = undefined;
        var From = undefined;
        Head = pas.Admin_List.C.el("div","lv-detail-head");
        Head.append(pas.Admin_List.C.el("b","",L["ip"]),$impl.MemberOf(L),pas.Admin_List.C.el("span","dim",window.dateTimeText(L["at"])));
        Holder.appendChild(Head);
        if (Boolean(L["status"])) {
          Answered = pas.Admin_List.StatusCell(L["status"])}
         else Answered = "";
        if (Boolean(L["referer"])) {
          From = pas.Admin_List.OutLink(L["referer"])}
         else From = "";
        pas.Admin_List.C.facts(Holder,Array.of($impl.Pair(window.t("Asked for"),"" + L["method"] + " " + ("" + L["path"])),$impl.Pair(window.t("Page"),pas.Admin_List.PageLink(L["path"])),$impl.Pair(window.t("Answered"),Answered),$impl.Pair(window.t("Took"),pas.Admin_List.MsCell(L["ms"])),$impl.Pair(window.t("Bot"),L["bot"]),$impl.Pair(window.t("From"),From),$impl.Pair(window.t("Browser"),L["agent"])));
        Acts = pas.Admin_List.C.el("div","lv-actions");
        Acts.appendChild(pas.Admin_List.LookButton(L["ip"]));
        Holder.appendChild(Acts);
      }]));
    };
    $impl.DrawVisitCounts = function (Box, Data) {
      var DayRows = null;
      var Days = null;
      var CountCols = null;
      var Rows = null;
      var Total = null;
      var Today = undefined;
      var ByDay = null;
      var Totals = null;
      var Day = null;
      var Row = null;
      var Bar = null;
      var Caption = null;
      var Most = 0.0;
      var I = 0;
      function PartName(X) {
        var Result = undefined;
        Result = pas.Admin_List.PartLabel(X["part"]);
        return Result;
      };
      if (!Boolean(Data["server"])) Box.appendChild(pas.Admin_List.C.el("p","notice",window.t("Visitor collection requires server mode.")));
      DayRows = Data["days"];
      if (DayRows.length > 0) {
        Today = DayRows[0]["day"]}
       else Today = "";
      ByDay = new Map();
      for (var $l = 0, $end = DayRows.length - 1; $l <= $end; $l++) {
        I = $l;
        Day = DayRows[I];
        ByDay.set(Day["day"],Number(pas.Admin_List.Either(ByDay.get(Day["day"]),0)) + Number(Day["requests"]));
      };
      Days = pas.Admin_List.SortBy(Array.from(ByDay),undefined).slice(-30);
      if (Days.length > 1) {
        Rows = new Array();
        for (var $l1 = 0, $end1 = Days.length - 1; $l1 <= $end1; $l1++) {
          I = $l1;
          Rows.push(Days[I][1]);
        };
        Most = pas.Admin_List.MostOf(Rows);
        Row = pas.Admin_List.C.el("div","days");
        for (var $l2 = 0, $end2 = Days.length - 1; $l2 <= $end2; $l2++) {
          I = $l2;
          Bar = pas.Admin_List.C.el("i");
          Bar.style["height"] = $impl.Pixels((66 * Number(Days[I][1])) / Most,2);
          Bar.title = window.dateText(Days[I][0]) + ": " + window.tn(Days[I][1],"%d request","%d requests");
          if (pas.Admin_List.Same(Days[I][0],Today)) Bar.classList.add("today");
          Row.appendChild(Bar);
        };
        Box.appendChild(Row);
        Caption = pas.Admin_List.C.el("div","days-caption");
        Caption.append(pas.Admin_List.C.el("span","",window.dateText(Days[0][0])),pas.Admin_List.C.el("span","",window.t("requests a day, bots included")),pas.Admin_List.C.el("span","",window.dateText(Days[Days.length - 1][0])));
        Box.appendChild(Caption);
      };
      Box.appendChild(pas.Admin_List.C.el("p","hint",window.t("UTC days. Counts are saved each minute. People are browsers that took the page whole, bots everything else that came; each address counts once in each part and day, and totals add those counts. People are counted from 6 Nov 2026.")));
      Totals = new Map();
      for (var $l3 = 0, $end3 = DayRows.length - 1; $l3 <= $end3; $l3++) {
        I = $l3;
        Day = DayRows[I];
        Total = pas.Admin_List.Either(Totals.get(Day["part"]),Array.of(0,0,0,0));
        Day["people"] = Math.min(Number(pas.Admin_List.Either(Day["people"],0)),Number(Day["visitors"]));
        Day["bots"] = Number(Day["visitors"]) - Number(Day["people"]);
        Total[0] = Number(Total[0]) + Number(Day["requests"]);
        Total[1] = Number(Total[1]) + Number(Day["people"]);
        Total[2] = Number(Total[2]) + Number(Day["refused"]);
        Total[3] = Number(Total[3]) + Number(Day["bots"]);
        Totals.set(Day["part"],Total);
      };
      CountCols = Array.of($impl.Column("requests",window.t("Requests"),"n",null,null,""),$impl.Column("people",window.t("People"),"n",null,null,""),$impl.Column("bots",window.t("Bot addresses"),"n",null,null,""),$impl.Column("refused",window.t("Guard refusals"),"n",null,null,""));
      Box.appendChild(pas.Admin_List.C.el("h3","",window.t("All days kept")));
      Rows = new Array();
      Days = Array.from(Totals);
      for (var $l4 = 0, $end4 = Days.length - 1; $l4 <= $end4; $l4++) {
        I = $l4;
        Total = Days[I][1];
        Rows.push(pas.JS.New(["part",Days[I][0],"requests",Total[0],"people",Total[1],"refused",Total[2],"bots",Total[3]]));
      };
      pas.Admin_List.ListView(Box,pas.JS.New(["id","v-parts","key",$impl.FieldOf("part"),"sort","-requests","search",false,"rows",Rows,"columns",Array.of($impl.Column("part",window.t("Part"),"",PartName,null,"")).concat(CountCols),"noun",$impl.Noun("%d part","%d parts")]));
      Box.appendChild(pas.Admin_List.C.el("h3","",window.t("Day by day")));
      pas.Admin_List.ListView(Box,pas.JS.New(["id","v-partdays","key",function (X) {
        var Result = undefined;
        Result = "" + X["day"] + ("" + X["part"]);
        return Result;
      },"sort","-day","search",false,"csv","requests-by-day","rows",DayRows,"columns",Array.of($impl.Column("day",window.t("Day"),"d",null,function (X) {
        var Result = undefined;
        Result = window.dateText(X["day"]);
        return Result;
      },""),$impl.Column("part",window.t("Part"),"",PartName,null,"")).concat(CountCols),"filters",Array.of($impl.Filter("part",window.t("Part"),window.t("Every part"),function (List) {
        var Result = undefined;
        var Names = null;
        var Choices = null;
        var N = 0;
        Names = $impl.Distinct($impl.Column2(List,"part"));
        Choices = new Array();
        for (var $l5 = 0, $end5 = Names.length - 1; $l5 <= $end5; $l5++) {
          N = $l5;
          Choices.push($impl.Pair(Names[N],pas.Admin_List.PartLabel(Names[N])));
        };
        Result = Choices;
        return Result;
      },function (X, K) {
        var Result = undefined;
        Result = pas.Admin_List.Same(X["part"],K);
        return Result;
      })),"noun",$impl.Noun("%d row","%d rows")]));
      Box.appendChild(pas.Admin_List.C.el("h3","",window.t("Busiest paths today")));
      pas.Admin_List.ListView(Box,pas.JS.New(["id","v-paths","key",$impl.FieldOf("path"),"sort","-requests","search",window.t("Filter paths"),"rows",Data["paths"],"columns",Array.of($impl.Column("path",window.t("Path"),"",null,$impl.PageOf("path"),""),$impl.Column("requests",window.t("Requests"),"n",null,null,"")),"noun",$impl.Noun("%d path","%d paths")]));
    };
    $impl.DrawConcerns = function (Box, R, Period) {
      var Concerns = null;
      var Kinds = null;
      var BlockWords = null;
      function Reasons(Concern) {
        var Result = null;
        Result = Concern["reasons"];
        return Result;
      };
      Box.replaceChildren();
      Box.appendChild(pas.Admin_List.C.el("p","hint",window.t("Every address is judged on its own, whatever it said it was: its busiest minute, how many browser strings and members it used, the pages it asked for that are not here, the scanner paths it probed, how often the guard turned it away, and whether it named a crawler it is not. A published crawler is welcome at any pace; an address on the allowed list (or this network) is not weighed. Pick a row for the whole story and the block buttons.")));
      Concerns = R["concerns"];
      if (Number(R["concerns_count"]) > Concerns.length) Box.appendChild(pas.Admin_List.C.el("p","hint",window.t("The %s weighed heaviest are listed, of %s.",pas.Admin_List.LocaleNumber(Concerns.length),pas.Admin_List.LocaleNumber(R["concerns_count"]))));
      Kinds = pas.Admin_List.ReasonKinds();
      BlockWords = pas.JS.New(["forgood",window.t("For good"),"blocked",window.t("Blocked now"),"over",window.t("Block over")]);
      pas.Admin_List.ListView(Box,pas.JS.New(["id","v-concerns","key",$impl.FieldOf("ip"),"sort","-score","csv","concerns-" + pas.Admin_List.WindowName(R),"search",window.t("Filter by address, bot or reason"),"rows",Concerns,"columns",Array.of($impl.Column("score",window.t("Weight"),"n",null,null,""),$impl.Column("ip",window.t("Address"),"",null,function (Concern) {
        var Result = undefined;
        Result = pas.Admin_List.C.el("b","lv-ip",Concern["ip"]);
        return Result;
      },""),$impl.Column("block",window.t("Blocked"),"",function (Concern) {
        var Result = undefined;
        Result = pas.Admin_List.Either(BlockWords["" + Concern["block"]],"");
        return Result;
      },function (Concern) {
        var Result = undefined;
        if (!Boolean(Concern["block"])) {
          Result = pas.Admin_List.C.el("span","","")}
         else if (pas.Admin_List.Same(Concern["block"],"over")) {
          Result = pas.Admin_List.C.chip(BlockWords["" + Concern["block"]],"")}
         else Result = pas.Admin_List.C.chip(BlockWords["" + Concern["block"]],"bad");
        return Result;
      },""),$impl.Column("what",window.t("Says it is"),"",function (Concern) {
        var Result = undefined;
        Result = pas.Admin_List.Either(pas.Admin_List.Either(Concern["crawler"],Concern["bot"]),window.t("a browser"));
        return Result;
      },null,""),$impl.Column("abuse",window.t("AbuseIPDB"),"n",function (Concern) {
        var Result = undefined;
        if (pas.Admin_List.IsUndef(Concern["abuse"]) || (Concern["abuse"] == null)) {
          Result = -1}
         else Result = Concern["abuse"];
        return Result;
      },function (Concern) {
        var Result = undefined;
        if (pas.Admin_List.IsUndef(Concern["abuse"]) || (Concern["abuse"] == null)) {
          Result = pas.Admin_List.C.el("span","dim","")}
         else if (Number(Concern["abuse"]) >= 75) {
          Result = pas.Admin_List.C.chip("" + Concern["abuse"] + "%","bad")}
         else Result = pas.Admin_List.C.chip("" + Concern["abuse"] + "%","");
        return Result;
      },""),$impl.Column("reasons",window.t("Why"),"s",function (Concern) {
        var Result = undefined;
        var Words = null;
        var N = 0;
        Words = new Array();
        for (var $l = 0, $end = Reasons(Concern).length - 1; $l <= $end; $l++) {
          N = $l;
          Words.push(pas.Admin_List.ReasonWords(Reasons(Concern)[N]));
        };
        Result = Words.join("; ");
        return Result;
      },function (Concern) {
        var Result = undefined;
        var Chips = null;
        var N = 0;
        Chips = pas.Admin_List.C.el("span","lv-reasons");
        for (var $l = 0, $end = Reasons(Concern).length - 1; $l <= $end; $l++) {
          N = $l;
          Chips.appendChild(pas.Admin_List.C.chip(pas.Admin_List.ReasonWords(Reasons(Concern)[N]),"open"));
        };
        Result = Chips;
        return Result;
      },"lv-text"),$impl.Column("requests",window.t("Requests"),"n",null,null,""),$impl.Column("peak",window.t("Busiest minute"),"nw",null,null,""),$impl.Column("last",window.t("Last seen"),"dw",null,$impl.StampOf("last"),"")),"filters",Array.of($impl.Filter("block",window.t("Blocked"),window.t("Blocked or not"),Array.of($impl.Pair("forgood",window.t("For good")),$impl.Pair("blocked",window.t("Blocked now")),$impl.Pair("over",window.t("Block over")),$impl.Pair("none",window.t("Never blocked"))),function (Concern, V) {
        var Result = undefined;
        if (V === "none") {
          Result = !Boolean(Concern["block"])}
         else Result = pas.Admin_List.Same(Concern["block"],V);
        return Result;
      }),$impl.Filter("kind",window.t("Reason"),window.t("Every reason"),function (Rows) {
        var Result = undefined;
        var Seen = null;
        var N = 0;
        var M = 0;
        Seen = new Map();
        for (var $l = 0, $end = Rows.length - 1; $l <= $end; $l++) {
          N = $l;
          for (var $l1 = 0, $end1 = Reasons(Rows[N]).length - 1; $l1 <= $end1; $l1++) {
            M = $l1;
            $impl.Count(Seen,Reasons(Rows[N])[M]["kind"]);
          };
        };
        Result = $impl.Counted(Seen,Kinds);
        return Result;
      },function (Concern, K) {
        var Result = undefined;
        var N = 0;
        Result = false;
        for (var $l = 0, $end = Reasons(Concern).length - 1; $l <= $end; $l++) {
          N = $l;
          if (pas.Admin_List.Same(Reasons(Concern)[N]["kind"],K)) return true;
        };
        return Result;
      })),"noun",$impl.Noun("%d address","%d addresses"),"empty",window.t("Nothing of concern in that period."),"detail",function (Concern, Holder, View) {
        pas.Admin_Address.AddressPanel(Concern["ip"],Holder,Period);
      }]));
    };
  };
},["Admin_Address"]);
rtl.module("Admin_Site",["System","JS","Web","Admin_List"],function () {
  "use strict";
  var $mod = this;
  this.AdminStorage = function (Box) {
    async function Draw() {
      var Data = null;
      var List = null;
      var Sorted = null;
      var Rows = null;
      var Item = null;
      var Used = 0.0;
      var Share = 0.0;
      var Sum = 0.0;
      var Tiles = null;
      var Disk = null;
      var Meter = null;
      var Fill = null;
      var Cls = "";
      var I = 0;
      try {
        Data = await pas.Admin_List.C.get("/api/admin/storage");
        List = Data["items"];
        if (Number(Data["disk_total"]) > 0) {
          Used = Number(Data["disk_total"]) - Number(Data["disk_free"]);
          Share = Used / Number(Data["disk_total"]);
          Tiles = pas.Admin_List.C.el("div","tiles-admin");
          if (Share > 0.9) {
            Cls = "warn"}
           else Cls = "";
          Disk = pas.Admin_List.Stat(Tiles,String(Math.round(Share * 100)) + "%",window.t("Disk used"),pas.Admin_List.C.sizeText(Used) + " " + window.t("of") + " " + pas.Admin_List.C.sizeText(Data["disk_total"]),Cls);
          if (Share > 0.95) {
            Cls = "meter bad"}
           else if (Share > 0.8) {
            Cls = "meter warn"}
           else Cls = "meter";
          Meter = pas.Admin_List.C.el("div",Cls);
          Fill = pas.Admin_List.C.el("i");
          Fill.style["width"] = String(Math.round(Share * 100)) + "%";
          Meter.appendChild(Fill);
          Disk.appendChild(Meter);
          pas.Admin_List.Stat(Tiles,pas.Admin_List.C.sizeText(Data["disk_free"]),window.t("Free"),undefined,undefined);
          Sum = 0;
          for (var $l = 0, $end = List.length - 1; $l <= $end; $l++) {
            I = $l;
            Sum = Sum + Number(List[I]["bytes"]);
          };
          pas.Admin_List.Stat(Tiles,pas.Admin_List.C.sizeText(Sum),window.t("The site uses"),window.t("database and folders"),undefined);
          Box.appendChild(Tiles);
        };
        if (List.length > 0) {
          Sorted = pas.Admin_List.SortBy(List.slice(0),function (A, B) {
            var Result = 0.0;
            Result = Number(B["bytes"]) - Number(A["bytes"]);
            return Result;
          });
          Rows = new Array();
          for (var $l1 = 0, $end1 = Sorted.length - 1; $l1 <= $end1; $l1++) {
            I = $l1;
            Item = Sorted[I];
            Rows.push(pas.JS.New(["name",window.t(Item["caption"]),"value",Item["bytes"]]));
          };
          pas.Admin_List.Bars(Box,Rows,pas.Admin_List.C["sizeText"]);
        };
        Box.appendChild(pas.Admin_List.C.el("p","hint",window.t("Measured in the background at most once an hour. Database sizes are engine estimates including indexes. Folder sizes exclude symbolic links.")));
        if (List.length === 0) Box.appendChild(pas.Admin_List.C.el("p","notice",window.t("No storage measurement yet.")));
        Rows = new Array();
        for (var $l2 = 0, $end2 = List.length - 1; $l2 <= $end2; $l2++) {
          I = $l2;
          Item = List[I];
          if (Boolean(Item["complete"])) {
            Cls = window.t("Complete")}
           else Cls = window.t("Partial");
          Rows.push(Array.of(window.t(Item["caption"]),pas.Admin_List.C.sizeText(Item["bytes"]),window.dateTimeText(Item["measured"]),Cls));
        };
        pas.Admin_List.AdminTable(Box,Array.of(window.t("Group or folder"),window.t("Size"),window.t("Measured"),window.t("Status")),Rows);
      } catch ($e) {
        pas.Admin_List.C.failed($e);
      };
    };
    Draw();
  };
  this.AdminOverview = function (Box, Data, Can) {
    var Lit = null;
    var Settings = null;
    var Switches = null;
    var List = null;
    var Brought = null;
    var Cards = null;
    var Stats = null;
    var Waiting = null;
    var Holder = null;
    var Names = null;
    var Fronts = null;
    var Extra = null;
    var Cls = "";
    var Lively = 0;
    var I = 0;
    function Card(P) {
      var Part = null;
      var Head = null;
      var Tools = null;
      var Flip = null;
      var Name = "";
      var Words = "";
      var About = "";
      async function Switch(E) {
        var Fields = null;
        Flip["disabled"] = true;
        try {
          Fields = new Object();
          if (Boolean(P["on"])) {
            Fields[Name] = "0"}
           else Fields[Name] = "1";
          await pas.Admin_List.C.post("/api/admin/settings",Fields);
          location.reload();
        } catch ($e) {
          pas.Admin_List.C.failed($e);
          Flip["disabled"] = false;
        };
      };
      Name = "" + P["name"];
      if (Boolean(P["on"])) {
        Part = pas.Admin_List.C.el("div","part-card on")}
       else Part = pas.Admin_List.C.el("div","part-card off");
      Head = pas.Admin_List.C.el("h3","",pas.Admin_List.Either(Names[Name],window.t(Name.charAt(0).toUpperCase() + Name.slice(1))));
      if (Boolean(P["on"])) {
        Head.appendChild(pas.Admin_List.C.el("span","part-state",window.t("On")))}
       else Head.appendChild(pas.Admin_List.C.el("span","part-state",window.t("Off")));
      Part.appendChild(Head);
      Words = window.t(P["caption"]);
      if (Words.indexOf(": ",0) > 0) {
        About = Words.slice(Words.indexOf(": ",0) + 2)}
       else About = Words;
      Part.appendChild(pas.Admin_List.C.el("p","",About.charAt(0).toUpperCase() + About.slice(1)));
      Tools = pas.Admin_List.C.el("div","part-tools");
      if (Boolean(P["change"])) {
        if (Boolean(P["on"])) {
          Flip = pas.Admin_List.C.el("button","",window.t("Turn off"))}
         else Flip = pas.Admin_List.C.el("button","primary",window.t("Turn on"));
        Flip["type"] = "button";
        Flip.addEventListener("click",Switch);
        Tools.appendChild(Flip);
      };
      if (Boolean(P["on"])) Tools.appendChild(pas.Admin_List.C.link(pas.Admin_List.Either(Fronts[Name],"/" + Name),"small-link",window.t("Open")));
      Part.appendChild(Tools);
      Cards.appendChild(Part);
    };
    Lit = String(pas.Admin_List.Either(Data["parts"],"")).split(" ");
    Settings = pas.Admin_List.Either(Data["settings"],new Array());
    Switches = new Array();
    for (var $l = 0, $end = Settings.length - 1; $l <= $end; $l++) {
      I = $l;
      if (pas.Admin_List.Same(Settings[I]["group"],"Parts")) Switches.push(Settings[I]);
    };
    if (Boolean(Data["unlisted_proxies"])) Box.appendChild(pas.Admin_List.C.el("p","problem",window.t("Requests arrive through %s, which the config file does not name under proxies. Until it does, every visitor looks like that one address and the guard cannot tell them apart.",Data["unlisted_proxies"])));
    Box.appendChild(pas.Admin_List.C.el("h2","",window.t("Community modules")));
    Box.appendChild(pas.Admin_List.C.el("p","hint",window.t("Each module can be on or off. A module that is off has no pages and no entries here; what it holds is kept.")));
    Cards = pas.Admin_List.C.el("div","part-cards");
    Box.appendChild(Cards);
    Names = pas.JS.New(["chat",window.t("Chat"),"wiki",window.t("Wiki"),"forum",window.t("Forum")]);
    Fronts = pas.JS.New(["chat","/","wiki","/wiki","forum","/forum"]);
    List = new Array();
    if (Switches.length > 0) {
      for (var $l1 = 0, $end1 = Switches.length - 1; $l1 <= $end1; $l1++) {
        I = $l1;
        List.push(pas.JS.New(["name",Switches[I]["name"],"caption",Switches[I]["caption"],"on",pas.Admin_List.Same(Switches[I]["value"],"1"),"change",true]));
      }}
     else for (var $l2 = 0, $end2 = Lit.length - 1; $l2 <= $end2; $l2++) {
      I = $l2;
      if (Boolean(Lit[I])) List.push(pas.JS.New(["name",Lit[I],"caption","","on",true,"change",false]));
    };
    for (var $l3 = 0, $end3 = List.length - 1; $l3 <= $end3; $l3++) {
      I = $l3;
      Card(List[I]);
    };
    Box.appendChild(pas.Admin_List.C.el("h2","",window.t("The site")));
    Stats = pas.Admin_List.C.el("div","tiles-admin");
    Box.appendChild(Stats);
    if (!pas.Admin_List.IsUndef(Data["members_total"])) pas.Admin_List.Stat(Stats,Data["members_total"],window.t("Members"),undefined,undefined);
    if (Can("read-reports")) {
      if (Number(pas.Admin_List.Either(Data["open_reports"],0)) > 0) {
        Cls = "warn"}
       else Cls = "";
      Waiting = pas.Admin_List.Stat(Stats,pas.Admin_List.Either(Data["open_reports"],0),window.t("Reports"),"",Cls);
      Waiting.style["cursor"] = "pointer";
      Waiting.addEventListener("click",function (E) {
        pas.Admin_List.S.adminTab("Reports");
      });
    };
    Lively = 0;
    for (var $l4 = 0, $end4 = List.length - 1; $l4 <= $end4; $l4++) {
      I = $l4;
      if (Boolean(List[I]["on"])) Lively += 1;
    };
    pas.Admin_List.Stat(Stats,Lively,window.t("Modules on"),undefined,undefined);
    if (Boolean(Data["version"])) pas.Admin_List.Stat(Stats,Data["version"],window.t("Exedra version"),undefined,undefined);
    Brought = pas.Admin_List.Extras["adminOverview"];
    I = 0;
    while (I < Brought.length) {
      Extra = Brought[I];
      if (!Boolean(Extra["permission"]) || Can("" + Extra["permission"])) {
        Holder = pas.Admin_List.C.el("section","overview-extra");
        Box.appendChild(Holder);
        Extra.build(Holder);
      };
      I += 1;
    };
  };
  this.AdminLook = function (Box) {
    var Logo = null;
    var Shown = "";
    function Part(What, Title, Hint, Preview) {
      var Form = null;
      var Img = null;
      var FileBox = null;
      var Save = null;
      var Remove = null;
      async function Send(Fields) {
        var Mark = "";
        Fields.append("what",What);
        try {
          pas.Admin_List.C.toast(await pas.Admin_List.C.post("/api/admin/look",Fields));
          if (Preview.includes("?",0)) {
            Mark = "&"}
           else Mark = "?";
          Img["src"] = Preview + Mark + String(Date.now());
        } catch ($e) {
          pas.Admin_List.C.failed($e);
        };
      };
      Form = pas.Admin_List.C.el("form","settings look");
      Form.appendChild(pas.Admin_List.C.el("h3","",Title));
      Form.appendChild(pas.Admin_List.C.el("p","hint",Hint));
      Img = pas.Admin_List.C.el("img","lookpreview " + What);
      Img["alt"] = "";
      Img.addEventListener("error",function (E) {
        Img.hidden = true;
      });
      Img.addEventListener("load",function (E) {
        Img.hidden = false;
      });
      Img["src"] = Preview;
      FileBox = pas.Admin_List.C.el("input");
      FileBox["type"] = "file";
      FileBox["name"] = "picture";
      FileBox["accept"] = "image/png,image/jpeg";
      Save = pas.Admin_List.C.el("button","primary",window.t("Upload"));
      Remove = pas.Admin_List.C.el("button","",window.t("Use none"));
      Remove["type"] = "button";
      Form.addEventListener("submit",function (E) {
        E.preventDefault();
        Send(new FormData(Form));
      });
      Remove.addEventListener("click",function (E) {
        var Fields = null;
        Fields = new FormData();
        Fields.append("remove","1");
        Send(Fields);
      });
      Form.append(Img,FileBox,Save,Remove);
      Box.appendChild(Form);
    };
    Logo = pas.Admin_List.C.$(".brandlogo");
    Part("icon",window.t("Icon"),window.t("One square PNG or JPEG, 512 by 512 pixels or more. It becomes the browser tab icon, the installed app's icon and the notification icon, in every size they need."),"/icon-192.png");
    if (Boolean(Logo)) {
      Shown = "" + Logo["src"]}
     else Shown = "/site/logo.png";
    Part("logo",window.t("Logo"),window.t('Shown in the header, 32 pixels high, beside the name or instead of it (Settings, "Show the name beside the logo"). It sits on the dark header bar in both themes, so use light lettering. A wide PNG with a clear background works best.'),Shown);
  };
});
rtl.module("Admin_Settings",["System","JS","Web","Admin_List"],function () {
  "use strict";
  var $mod = this;
  this.AdminSettings = function (Box, Data, Only, Key) {
    var Layout = null;
    var Side = null;
    var Search = null;
    var Nav = null;
    var Picker = null;
    var Panel = null;
    var Empty = null;
    var Groups = null;
    var Settings = null;
    var Sections = null;
    var Pairs = null;
    var S = null;
    var Chosen = undefined;
    var Kept = "";
    var I = 0;
    function Show() {
      var Query = "";
      var Found = false;
      var Match = false;
      var Section = null;
      var Field = null;
      var Matches = 0;
      var N = 0;
      var M = 0;
      Query = Search["value"].trim().toLowerCase();
      Found = false;
      for (var $l = 0, $end = Sections.length - 1; $l <= $end; $l++) {
        N = $l;
        Section = Sections[N];
        Matches = 0;
        for (var $l1 = 0, $end1 = Section.fields.length - 1; $l1 <= $end1; $l1++) {
          M = $l1;
          Field = Section.fields[M];
          Match = (Query === "") || Field["words"].includes(Query,0);
          Field["label"].hidden = !Match;
          Field["input"]["disabled"] = !Match;
          if (Match) Matches += 1;
        };
        if (Query !== "") {
          Section.form.hidden = Matches === 0}
         else Section.form.hidden = !pas.Admin_List.Same(Section.group,Chosen);
        pas.Admin_List.Toggle(Section.button,"on",pas.Admin_List.Same(Section.group,Chosen));
        if (pas.Admin_List.Same(Section.group,Chosen)) {
          Section.button.setAttribute("aria-pressed","true")}
         else Section.button.setAttribute("aria-pressed","false");
        if (!Section.form.hidden) Found = true;
      };
      Picker["value"] = Chosen;
      Empty.hidden = Found;
    };
    function Select(Group) {
      Chosen = Group;
      pas.Admin_List.C.shared(Kept,Group);
      Search["value"] = "";
      Show();
    };
    function AddSection(Group, Settings) {
      var Button = null;
      var Option = null;
      var Form = null;
      var Save = null;
      var Fields = null;
      var N = 0;
      function AddField(S) {
        var FieldLabel = null;
        var Caption = null;
        var Input = null;
        var O = null;
        var Choices = null;
        var Names = null;
        var Long = false;
        var M = 0;
        FieldLabel = pas.Admin_List.C.el("label");
        Caption = pas.Admin_List.C.el("span","setting-caption",window.t(S["caption"]));
        Caption.appendChild(pas.Admin_List.C.el("small","hint",window.t(S["name"])));
        FieldLabel.appendChild(Caption);
        if (pas.Admin_List.Same(S["kind"],"yesno") || S["kind"].startsWith("choice:")) {
          Input = pas.Admin_List.C.el("select");
          if (pas.Admin_List.Same(S["kind"],"yesno")) {
            Choices = Array.of(Array.of("1",window.t("yes")),Array.of("0",window.t("no")))}
           else {
            Choices = new Array();
            Names = S["kind"].slice(7).split("|");
            for (var $l = 0, $end = Names.length - 1; $l <= $end; $l++) {
              M = $l;
              Choices.push(Array.of(Names[M],window.t(Names[M])));
            };
          };
          for (var $l1 = 0, $end1 = Choices.length - 1; $l1 <= $end1; $l1++) {
            M = $l1;
            O = pas.Admin_List.C.el("option","",Choices[M][1]);
            O["value"] = Choices[M][0];
            Input.appendChild(O);
          };
        } else {
          Long = pas.Admin_List.Same(S["kind"],"longtext");
          if (Long) {
            Input = pas.Admin_List.C.el("textarea")}
           else Input = pas.Admin_List.C.el("input");
          if (Long) {
            FieldLabel.classList.add("wide");
            Input["rows"] = 3;
            Input.addEventListener("keydown",function (E) {
              if (E.key === "Enter") {
                E.preventDefault();
                Form.requestSubmit();
              };
            });
            Input.addEventListener("input",function (E) {
              if (Input["value"].includes("\n",0)) Input["value"] = Input["value"].replace(new RegExp("\\s*\\n\\s*","g")," ");
            });
          };
          if (pas.Admin_List.Same(S["kind"],"number")) Input["type"] = "number";
          Input["autocomplete"] = "off";
          Input["spellcheck"] = false;
          if (pas.Admin_List.Same(S["kind"],"secret")) {
            Input.classList.add("secret");
            Input.setAttribute("data-1p-ignore","");
            Input.setAttribute("data-lpignore","true");
            if (Boolean(S["set"])) {
              Input["placeholder"] = window.t("set (empty keeps it)")}
             else Input["placeholder"] = window.t("not set");
          };
        };
        Input["name"] = S["name"];
        Input["value"] = S["value"];
        FieldLabel.appendChild(Input);
        Form.appendChild(FieldLabel);
        Fields.push(pas.JS.New(["label",FieldLabel,"input",Input,"words",Array.of(S["caption"],window.t(S["caption"]),S["name"]).join(" ").toLowerCase()]));
      };
      async function Submit(E) {
        E.preventDefault();
        Save["disabled"] = true;
        try {
          try {
            pas.Admin_List.C.toast(await pas.Admin_List.C.post("/api/admin/settings",new URLSearchParams(new FormData(Form))));
          } catch ($e) {
            pas.Admin_List.C.failed($e);
          };
        } finally {
          Save["disabled"] = false;
        };
      };
      Button = pas.Admin_List.C.el("button");
      Button["type"] = "button";
      Button.append(pas.Admin_List.C.el("span","",window.t(Group)),pas.Admin_List.C.chip(window.t("%d",Settings.length)));
      Button.addEventListener("click",function (E) {
        Select(Group);
      });
      Nav.appendChild(Button);
      Option = pas.Admin_List.C.el("option","",window.t("%s (%d)",window.t(Group),Settings.length));
      Option["value"] = Group;
      Picker.appendChild(Option);
      Form = pas.Admin_List.C.el("form","settings settings-section");
      Form["autocomplete"] = "off";
      Form.appendChild(pas.Admin_List.C.el("h3","",window.t(Group)));
      if (pas.Admin_List.Same(Group,"Sign-in")) Form.appendChild(pas.Admin_List.C.el("p","hint",window.t("Make an OAuth app at each provider and give it this return address: %s followed by its name: github, gitlab, codeberg, google or microsoft. A provider shows on the sign-in page once its id and secret are here and it is switched on.",window.location.origin + window.SiteBase.url("/_oauth/"))));
      Fields = new Array();
      for (var $l = 0, $end = Settings.length - 1; $l <= $end; $l++) {
        N = $l;
        AddField(Settings[N]);
      };
      Save = pas.Admin_List.C.el("button","primary",window.t("Save settings"));
      Save["type"] = "submit";
      Form.appendChild(Save);
      if (pas.Admin_List.Same(Group,"File scanning")) $mod.FileScanning(Form);
      if (pas.Admin_List.Same(Group,"Search")) $mod.SearchIndex(Form);
      Form.addEventListener("submit",Submit);
      Panel.appendChild(Form);
      Sections.push(pas.JS.New(["group",Group,"button",Button,"form",Form,"fields",Fields]));
    };
    Layout = pas.Admin_List.C.el("div","settings-layout");
    Side = pas.Admin_List.C.el("div","settings-side");
    Search = pas.Admin_List.C.el("input","lv-find");
    Search["type"] = "search";
    Search["autocomplete"] = "off";
    Search["placeholder"] = window.t("Search settings");
    Search.setAttribute("aria-label",window.t("Search settings"));
    Nav = pas.Admin_List.C.el("nav","subtabs settings-nav");
    Nav.setAttribute("aria-label",window.t("Settings sections"));
    Picker = pas.Admin_List.C.el("select","lv-filter settings-picker");
    Picker.setAttribute("aria-label",window.t("Settings section"));
    Panel = pas.Admin_List.C.el("div","settings-panels");
    Empty = pas.Admin_List.C.el("p","hint",window.t("No settings match your search."));
    Empty.hidden = true;
    Panel.appendChild(Empty);
    Side.append(Search,Nav,Picker);
    Layout.append(Side,Panel);
    Box.appendChild(Layout);
    Groups = new Map();
    Settings = Data["settings"];
    for (var $l = 0, $end = Settings.length - 1; $l <= $end; $l++) {
      I = $l;
      S = Settings[I];
      if ((Only != null) && !Only(S["group"])) continue;
      if (!Groups.has(S["group"])) Groups.set(S["group"],new Array());
      Groups.get(S["group"]).push(S);
    };
    if (Boolean(Key)) {
      Kept = "admin-settings-section-" + ("" + Key)}
     else Kept = "admin-settings-section";
    Chosen = pas.Admin_List.C.shared(Kept);
    if (!Groups.has(Chosen)) Chosen = Groups.keys().next().value;
    Sections = new Array();
    Pairs = Array.from(Groups);
    for (var $l1 = 0, $end1 = Pairs.length - 1; $l1 <= $end1; $l1++) {
      I = $l1;
      AddSection(Pairs[I][0],Pairs[I][1]);
    };
    Search.addEventListener("input",Show);
    Picker.addEventListener("change",function (E) {
      Select(Picker["value"]);
    });
    Show();
  };
  this.FileScanning = function (Form) {
    var Status = null;
    var Test = null;
    var Said = null;
    var List = null;
    var Panel = null;
    var First = undefined;
    async function Show() {
      var Result = undefined;
      var D = null;
      var F = null;
      var Files = null;
      var Rows = null;
      var Ready = undefined;
      var error = undefined;
      var Result_ = undefined;
      var N = 0;
      D = await pas.Admin_List.C.get("/api/admin/scans");
      if (Boolean(D["ready"])) {
        Ready = window.t("Scanner ready: %s",pas.Admin_List.Either(D["version"],"?"))}
       else Ready = D["problem"];
      if (Boolean(D["last_error"])) {
        error = window.t("Last error, %s: %s",window.dateTimeText(D["last_error_at"]),D["last_error"])}
       else error = "";
      if (Boolean(D["on"])) {
        Status.textContent = Array.of(window.t("Scanning is on."),Ready,error).join(" ").trim()}
       else Status.textContent = Array.of(window.t("Scanning is off."),Ready,error).join(" ").trim();
      List.replaceChildren(pas.Admin_List.C.el("h3","",window.t("Files stopped or not checked")));
      Files = D["files"];
      if (Files.length === 0) {
        List.appendChild(pas.Admin_List.C.el("p","hint",window.t("Nothing yet.")));
        return Result;
      };
      Rows = new Array();
      for (var $l = 0, $end = Files.length - 1; $l <= $end; $l++) {
        N = $l;
        F = Files[N];
        if (Boolean(F["found"])) {
          Result_ = window.t("refused, found %s",F["names"])}
         else if (Boolean(F["kept"])) {
          Result_ = window.t("kept unchecked: %s",F["names"])}
         else Result_ = window.t("refused unchecked: %s",F["names"]);
        Rows.push(Array.of(window.dateTimeText(F["when"]),F["member"],F["route"],F["name"],pas.Admin_List.C.sizeText(F["size"]),Result_,F["sha256"]));
      };
      pas.Admin_List.AdminTable(List,Array.of(window.t("When"),window.t("Member"),window.t("Where"),window.t("File"),window.t("Size"),window.t("Result"),"SHA-256"),Rows);
      return Result;
    };
    async function TestClick(E) {
      var R = null;
      Test["disabled"] = true;
      Said.textContent = "";
      try {
        try {
          R = JSON.parse(await pas.Admin_List.C.post("/api/admin/scans/test",new Object()));
          if (Boolean(R["caught"])) {
            Said.textContent = window.t("The scanner caught the test file: %s",R["words"])}
           else if (Boolean(R["error"])) {
            Said.textContent = window.t("The scanner could not check the test file: %s",R["words"])}
           else Said.textContent = window.t("The scanner did not catch the test file.");
          if (Boolean(R["caught"]) && !Boolean(R["limits"])) Said.textContent = Said.textContent + " " + window.t("It does not report the files it stops reading at a limit, so those would count as clean: set AlertExceedsMax yes in clamd.conf.");
          await Show();
        } catch ($e) {
          pas.Admin_List.C.failed($e);
        };
      } finally {
        Test["disabled"] = false;
      };
    };
    Status = pas.Admin_List.C.el("p","hint");
    Status.setAttribute("role","status");
    Test = pas.Admin_List.C.el("button","",window.t("Test the scanner"));
    Test["type"] = "button";
    Said = pas.Admin_List.C.el("p");
    Said.setAttribute("role","status");
    List = pas.Admin_List.C.el("div","scan-list");
    Panel = pas.Admin_List.C.el("div","scan-panel");
    Panel.append(pas.Admin_List.C.el("h3","",window.t("The scanner")),Status,pas.Admin_List.C.el("p","hint",window.t("The test scans the EICAR test file, a harmless file that every virus scanner reports.")),Test,Said,List);
    Form.appendChild(Panel);
    Test.addEventListener("click",TestClick);
    First = Show();
    First.catch(pas.Admin_List.C["failed"]);
  };
  this.SearchIndex = function (Form) {
    var Panel = null;
    var First = undefined;
    async function Show() {
      var Result = undefined;
      var D = null;
      var P = null;
      var Parts = null;
      var Count = "";
      var Words = "";
      var Line = null;
      var Builds = false;
      var N = 0;
      D = await pas.Admin_List.C.get("/api/admin/search");
      Panel.replaceChildren(pas.Admin_List.C.el("h3","",window.t("Search index")));
      if (Boolean(D["cgi"])) {
        Panel.appendChild(pas.Admin_List.C.el("p","hint",window.t("This program runs as CGI and keeps no index: the database search answers.")));
        return Result;
      };
      Parts = D["parts"];
      if (Parts.length === 0) Panel.appendChild(pas.Admin_List.C.el("p","hint",window.t("Nothing here is searched through the index yet.")));
      Builds = false;
      for (var $l = 0, $end = Parts.length - 1; $l <= $end; $l++) {
        N = $l;
        P = Parts[N];
        Count = pas.Admin_List.LocaleNumber(P["documents"]);
        if (pas.Admin_List.Same(P["state"],"ready")) {
          Words = window.t("%s documents, ready",Count)}
         else if (pas.Admin_List.Same(P["state"],"building")) {
          Words = window.t("building, %s",pas.Admin_List.Either(P["step"],""))}
         else if (pas.Admin_List.Same(P["state"],"failed")) {
          Words = window.t("failed: %s",P["problem"])}
         else if (pas.Admin_List.Same(P["state"],"waiting")) {
          Words = window.t("waiting to be built")}
         else Words = window.t("off");
        if (Boolean(P["queued"])) Words = Words + ", " + window.t("%s changes waiting",pas.Admin_List.LocaleNumber(P["queued"]));
        if (Boolean(P["refused"])) Words = Words + ", " + window.t("%s found but not shown",pas.Admin_List.LocaleNumber(P["refused"]));
        Line = pas.Admin_List.C.el("p","hint","" + P["part"] + ": " + Words);
        Line.setAttribute("role","status");
        Panel.appendChild(Line);
        if (pas.Admin_List.Same(P["state"],"building")) Builds = true;
      };
      if (Boolean(Form["isConnected"]) && Builds) window.setTimeout(function () {
        var Again = undefined;
        Again = Show();
        Again.catch(pas.Admin_List.C["failed"]);
      },2000);
      return Result;
    };
    Panel = pas.Admin_List.C.el("div","scan-panel");
    Form.appendChild(Panel);
    First = Show();
    First.catch(pas.Admin_List.C["failed"]);
  };
});
rtl.module("Admin_Chat",["System","JS","Web","Admin_List"],function () {
  "use strict";
  var $mod = this;
  this.AdminChannels = function (Box, Data) {
    var Table = null;
    var Channels = null;
    var I = 0;
    function AddRow(Channel) {
      var Tr = null;
      var Slug = null;
      var Topic = null;
      var Policy = null;
      var AsSent = null;
      var AsSentLabel = null;
      var ArchivedLabel = null;
      var Archived = null;
      var IconCell = null;
      var Img = null;
      var Pick = null;
      var Save = null;
      var O = null;
      var Td = null;
      var Choices = null;
      var Cells = null;
      var N = 0;
      async function Picked(E) {
        var Fields = null;
        Fields = new FormData();
        Fields.append("file",Pick["files"][0]);
        Fields.append("room_icon",Channel["slug"]);
        try {
          Img["src"] = JSON.parse(await pas.Admin_List.C.post("/api/upload",Fields))["url"];
          Img.hidden = false;
          IconCell.querySelector("span").textContent = "";
          pas.Admin_List.C.toast(window.t("Icon saved."));
        } catch ($e) {
          pas.Admin_List.C.failed($e);
        };
      };
      async function SaveClick(E) {
        var IsArchived = "";
        var IsAsSent = "";
        try {
          if (Boolean(Archived["checked"])) {
            IsArchived = "1"}
           else IsArchived = "0";
          if (Boolean(AsSent["checked"])) {
            IsAsSent = "1"}
           else IsAsSent = "0";
          pas.Admin_List.C.toast(await pas.Admin_List.C.post("/api/admin/channel",pas.JS.New(["slug",Slug["value"],"topic",Topic["value"],"policy",Policy["value"],"archived",IsArchived,"as_sent",IsAsSent])));
          if (!Boolean(Channel["slug"])) pas.Admin_List.C.route("/admin",false);
        } catch ($e) {
          pas.Admin_List.C.failed($e);
        };
      };
      Tr = pas.Admin_List.C.el("tr");
      Slug = pas.Admin_List.C.el("input");
      Slug["value"] = pas.Admin_List.Either(Channel["slug"],"");
      Slug["readOnly"] = Boolean(Channel["slug"]);
      Slug["placeholder"] = window.t("new-channel");
      Topic = pas.Admin_List.C.el("input");
      Topic["value"] = pas.Admin_List.Either(Channel["topic"],"");
      Topic["placeholder"] = window.t("What it is for");
      Policy = pas.Admin_List.C.el("select");
      Choices = Array.of(Array.of("all",window.t("everyone posts")),Array.of("readonly",window.t("read only: some post, all reply")),Array.of("closed",window.t("closed: only some post or reply")));
      for (var $l = 0, $end = Choices.length - 1; $l <= $end; $l++) {
        N = $l;
        O = pas.Admin_List.C.el("option","",Choices[N][1]);
        O["value"] = Choices[N][0];
        Policy.appendChild(O);
      };
      if (pas.Admin_List.Same(Channel["policy"],"readonly") || pas.Admin_List.Same(Channel["policy"],"closed")) {
        Policy["value"] = Channel["policy"]}
       else Policy["value"] = "all";
      AsSent = pas.Admin_List.C.el("input");
      AsSent["type"] = "checkbox";
      AsSent["checked"] = Boolean(Channel["as_sent"]);
      AsSentLabel = pas.Admin_List.C.el("label","aslabel","");
      AsSentLabel.append(AsSent," " + window.t("as sent"));
      AsSentLabel.title = window.t("Messages stay as they were sent: nobody changes or deletes one, a moderator neither.");
      ArchivedLabel = pas.Admin_List.C.el("label","aslabel","");
      Archived = pas.Admin_List.C.el("input");
      Archived["type"] = "checkbox";
      Archived["checked"] = Boolean(Channel["archived"]);
      Archived.title = window.t("Archived");
      ArchivedLabel.append(Archived," " + window.t("archived"));
      IconCell = pas.Admin_List.C.el("label","chanicon");
      if (Boolean(Channel["slug"])) {
        Img = pas.Admin_List.C.el("img");
        Img["alt"] = "";
        if (Boolean(Channel["avatar"])) {
          Img["src"] = Channel["avatar"]}
         else Img.hidden = true;
        Pick = pas.Admin_List.C.el("input");
        Pick["type"] = "file";
        Pick["accept"] = "image/png,image/jpeg,image/webp";
        Pick.hidden = true;
        IconCell.title = window.t("Change the icon");
        if (Boolean(Channel["avatar"])) {
          IconCell.append(Img,pas.Admin_List.C.el("span","",""),Pick)}
         else IconCell.append(Img,pas.Admin_List.C.el("span","",window.t("Icon")),Pick);
        Pick.addEventListener("change",Picked);
      };
      if (Boolean(Channel["slug"])) {
        Save = pas.Admin_List.C.el("button","",window.t("Save"))}
       else Save = pas.Admin_List.C.el("button","",window.t("Create"));
      Save["type"] = "button";
      Save.addEventListener("click",SaveClick);
      Cells = Array.of(IconCell,Slug,Topic,Policy,AsSentLabel,ArchivedLabel,Save);
      for (var $l1 = 0, $end1 = Cells.length - 1; $l1 <= $end1; $l1++) {
        N = $l1;
        Td = pas.Admin_List.C.el("td");
        Td.appendChild(Cells[N]);
        Tr.appendChild(Td);
      };
      Table.appendChild(Tr);
    };
    Box.appendChild(pas.Admin_List.C.el("p","hint",window.t("Public channels everyone follows when they join. Members open their own private channels from the + in the sidebar.")));
    Table = pas.Admin_List.C.el("table","grid");
    Channels = Data["channels"];
    for (var $l = 0, $end = Channels.length - 1; $l <= $end; $l++) {
      I = $l;
      AddRow(Channels[I]);
    };
    AddRow(new Object());
    Box.appendChild(Table);
  };
  this.AdminPrivate = function (Box) {
    var List = null;
    var Body = null;
    var Find = null;
    var First = undefined;
    function When(Iso) {
      var Result = "";
      if (Boolean(Iso)) {
        Result = pas.Admin_List.C.ago(Iso)}
       else Result = window.t("nothing yet");
      return Result;
    };
    function Count(N) {
      var Result = "";
      Result = window.tn(N,"%d message","%d messages");
      return Result;
    };
    function People(Channel) {
      var Result = undefined;
      var Members = null;
      var Names = null;
      var N = 0;
      Members = Channel["members"];
      Names = new Array();
      for (var $l = 0, $end = Members.length - 1; $l <= $end; $l++) {
        N = $l;
        if (pas.Admin_List.Same(Members[N],Channel["owner"])) {
          Names.push(window.t("%s (owner)",Members[N]))}
         else Names.push(Members[N]);
      };
      if (Boolean(Channel["owner"]) && (Members.indexOf(Channel["owner"]) < 0)) Names.unshift(window.t("%s (owner, left)",Channel["owner"]));
      Result = pas.Admin_List.Either(Names.join(", "),window.t("nobody"));
      return Result;
    };
    function RemoveButton(Ask, Fields, Show) {
      var Result = null;
      var Remove = null;
      async function Click(E) {
        if (!window.confirm("" + Ask)) return;
        try {
          pas.Admin_List.C.toast(await pas.Admin_List.C.post("/api/admin/private/delete",Fields));
          await Show();
        } catch ($e) {
          pas.Admin_List.C.failed($e);
        };
      };
      Remove = pas.Admin_List.C.el("button","small-link bad",window.t("Delete"));
      Remove["type"] = "button";
      Remove.addEventListener("click",Click);
      Result = Remove;
      return Result;
    };
    function Part(Rows, Empty) {
      var Result = null;
      var Wrap = null;
      var Table = null;
      var N = 0;
      Wrap = pas.Admin_List.C.el("div","gridwrap");
      if (Rows.length === 0) {
        Wrap.appendChild(pas.Admin_List.C.el("p","dim",Empty));
        return Wrap;
      };
      Table = pas.Admin_List.C.el("table","grid privategrid");
      for (var $l = 0, $end = Rows.length - 1; $l <= $end; $l++) {
        N = $l;
        Table.appendChild(Rows[N]);
      };
      Wrap.appendChild(Table);
      Result = Wrap;
      return Result;
    };
    function Row(Cells) {
      var Result = null;
      var Tr = null;
      var Td = null;
      var Cell = null;
      var N = 0;
      Tr = pas.Admin_List.C.el("tr");
      for (var $l = 0, $end = Cells.length - 1; $l <= $end; $l++) {
        N = $l;
        Cell = Cells[N];
        if (Boolean(Cell["dim"])) {
          Td = pas.Admin_List.C.el("td","dim")}
         else Td = pas.Admin_List.C.el("td","");
        if (Boolean(Cell["node"])) {
          Td.appendChild(Cell["node"])}
         else Td["textContent"] = Cell["text"];
        Tr.appendChild(Td);
      };
      Result = Tr;
      return Result;
    };
    function Fill() {
      var Q = "";
      var Channels = null;
      var Talks = null;
      var Given = null;
      var Members = null;
      var Channel = null;
      var Empty = undefined;
      var Head = undefined;
      var Locked = undefined;
      var Among = false;
      var N = 0;
      var M = 0;
      function Has(Text) {
        var Result = false;
        Result = (Q === "") || (String(Text).toLowerCase().indexOf(Q,0) >= 0);
        return Result;
      };
      Q = Find["value"].trim().toLowerCase();
      Channels = new Array();
      Given = List["channels"];
      for (var $l = 0, $end = Given.length - 1; $l <= $end; $l++) {
        N = $l;
        Channel = Given[N];
        Among = Has(Channel["slug"]) || Has(Channel["title"]) || Has(Channel["owner"]);
        if (!Among) {
          Members = Channel["members"];
          for (var $l1 = 0, $end1 = Members.length - 1; $l1 <= $end1; $l1++) {
            M = $l1;
            if (Has(Members[M])) {
              Among = true;
              break;
            };
          };
        };
        if (!Among) continue;
        if (Boolean(Channel["archived"])) {
          Head = window.t("#%s (archived)",Channel["slug"])}
         else Head = "#" + ("" + Channel["slug"]);
        Channels.push(Row(Array.of(pas.JS.New(["node",pas.Admin_List.C.el("b","",Head)]),pas.JS.New(["text",People(Channel)]),pas.JS.New(["text",Count(Channel["messages"]),"dim",true]),pas.JS.New(["text",When(Channel["last"]),"dim",true]),pas.JS.New(["node",RemoveButton(window.t("Delete #%s for good?\n\nIts messages, threads and files go for everyone in it. This cannot be undone.",Channel["slug"]),pas.JS.New(["kind","channel","slug",Channel["slug"]]),Show)]))));
      };
      Talks = new Array();
      Given = List["conversations"];
      for (var $l2 = 0, $end2 = Given.length - 1; $l2 <= $end2; $l2++) {
        N = $l2;
        Channel = Given[N];
        if (!(Has(Channel["a"]) || Has(Channel["b"]))) continue;
        if (Boolean(Channel["locked"])) {
          Locked = window.t("locked")}
         else Locked = window.t("plain");
        Talks.push(Row(Array.of(pas.JS.New(["node",pas.Admin_List.C.el("b","",window.t("%s and %s",Channel["a"],Channel["b"]))]),pas.JS.New(["text",Locked,"dim",true]),pas.JS.New(["text",Count(Channel["messages"]),"dim",true]),pas.JS.New(["text",When(Channel["last"]),"dim",true]),pas.JS.New(["node",RemoveButton(window.t("Delete the conversation between %s and %s for good?\n\nEvery message and file goes from both sides. This cannot be undone.",Channel["a"],Channel["b"]),pas.JS.New(["kind","conversation","a",Channel["a"],"b",Channel["b"]]),Show)]))));
      };
      if (Q !== "") {
        Empty = window.t("None match.")}
       else Empty = window.t("There are none.");
      Body.replaceChildren(pas.Admin_List.C.el("h2","",window.t("Private channels")),Part(Channels,Empty),pas.Admin_List.C.el("h2","",window.t("Private conversations")),Part(Talks,Empty));
    };
    async function Show() {
      var Result = undefined;
      List = await pas.Admin_List.C.get("/api/admin/private");
      Fill();
      return Result;
    };
    List = null;
    Body = pas.Admin_List.C.el("div");
    Find = pas.Admin_List.C.el("input");
    Find["type"] = "search";
    Find["placeholder"] = window.t("Find a member or channel");
    Find.addEventListener("input",Fill);
    Box.append(pas.Admin_List.C.el("p","hint",window.t("Who talks in private and how much. What they say does not come here.")),Find,Body);
    First = Show();
    First.catch(pas.Admin_List.C["failed"]);
  };
});
rtl.module("Admin_Members",["System","JS","Web","Admin_List"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  this.AdminPermissions = function (Box, Data) {
    var Wrap = null;
    var Table = null;
    var HeadRow = null;
    var Th = null;
    var Roles = null;
    var Form = null;
    var Name = null;
    var Caption = null;
    var Scope = null;
    var Add = null;
    var Opt = null;
    var List = null;
    var Choices = null;
    var R = null;
    var I = 0;
    function PermissionRow(P) {
      var Tr = null;
      var Cell = null;
      var Have = null;
      var N = 0;
      function RoleCell(Role) {
        var Td = null;
        var Box2 = null;
        Td = pas.Admin_List.C.el("td");
        Box2 = pas.Admin_List.C.el("input");
        Box2.type = "checkbox";
        Box2.checked = pas.Admin_List.Same(Role["name"],"admin") || (Have.indexOf(Role["name"]) >= 0);
        Box2.disabled = pas.Admin_List.Same(Role["name"],"admin");
        Box2.title = "" + $impl.RoleTitle(Role["name"]) + ": " + window.t(P["caption"]);
        Box2.addEventListener("change",async function (E) {
          if (Box2.checked) {
            Have.push(Role["name"])}
           else Have.splice(Have.indexOf(Role["name"]),1);
          try {
            await pas.Admin_List.C.post("/api/admin/permission",pas.JS.New(["name",P["name"],"roles",Have.join(",")]));
          } catch ($e) {
            pas.Admin_List.C.failed($e);
            Box2.checked = !Box2.checked;
          };
        });
        Td.appendChild(Box2);
        Tr.appendChild(Td);
      };
      Tr = pas.Admin_List.C.el("tr");
      Cell = pas.Admin_List.C.el("td","pname",window.t(P["caption"]));
      Cell["title"] = P["name"];
      Tr.appendChild(Cell);
      Have = $impl.Filled(P["roles"]);
      for (var $l = 0, $end = List.length - 1; $l <= $end; $l++) {
        N = $l;
        RoleCell(List[N]);
      };
      Table.appendChild(Tr);
    };
    function RoleRow(Role) {
      var Tr = null;
      var Td = null;
      var X = null;
      var Where = "";
      Tr = pas.Admin_List.C.el("tr");
      if (pas.Admin_List.Same(Role["scope"],"room")) {
        Where = window.t("in one channel")}
       else Where = window.t("site");
      Tr.append(pas.Admin_List.C.el("td","",$impl.RoleTitle(Role["name"])),pas.Admin_List.C.el("td","dim",Where),pas.Admin_List.C.el("td","dim",Role["caption"]));
      Td = pas.Admin_List.C.el("td");
      if (!Boolean(Role["builtin"])) {
        X = pas.Admin_List.C.el("button","small-link",window.t("Delete"));
        X["type"] = "button";
        X.addEventListener("click",async function (E) {
          if (!window.confirm(window.t("Delete the role %s? Members who have it lose it.",Role["name"]))) return;
          try {
            await pas.Admin_List.C.post("/api/admin/role",pas.JS.New(["name",Role["name"],"delete","1"]));
            pas.Admin_List.C.route("/admin",false);
          } catch ($e) {
            pas.Admin_List.C.failed($e);
          };
        });
        Td.appendChild(X);
      };
      Tr.appendChild(Td);
      Roles.appendChild(Tr);
    };
    Box.appendChild(pas.Admin_List.C.el("p","hint",window.t("Tick which roles may do what. Admins may always do everything. The channel roles (channel owner, channel moderator) count only in their channel. To give one member one extra right, make a role with it and give them that role under Members.")));
    Wrap = pas.Admin_List.C.el("div","gridwrap");
    Table = pas.Admin_List.C.el("table","grid perms");
    HeadRow = pas.Admin_List.C.el("tr");
    HeadRow.appendChild(pas.Admin_List.C.el("th","",""));
    List = Data["roles"];
    for (var $l = 0, $end = List.length - 1; $l <= $end; $l++) {
      I = $l;
      R = List[I];
      if (pas.Admin_List.Same(R["scope"],"room")) {
        Th = pas.Admin_List.C.el("th","roomrole",$impl.RoleTitle(R["name"]))}
       else Th = pas.Admin_List.C.el("th","",$impl.RoleTitle(R["name"]));
      Th["title"] = R["caption"];
      HeadRow.appendChild(Th);
    };
    Table.appendChild(HeadRow);
    for (var $l1 = 0, $end1 = Data["permissions"].length - 1; $l1 <= $end1; $l1++) {
      I = $l1;
      PermissionRow(Data["permissions"][I]);
    };
    Wrap.appendChild(Table);
    Box.appendChild(Wrap);
    Box.appendChild(pas.Admin_List.C.el("h2","",window.t("Roles")));
    Roles = pas.Admin_List.C.el("table","grid");
    for (var $l2 = 0, $end2 = List.length - 1; $l2 <= $end2; $l2++) {
      I = $l2;
      RoleRow(List[I]);
    };
    Box.appendChild(Roles);
    Form = pas.Admin_List.C.el("form","invite");
    Name = pas.Admin_List.C.el("input");
    Name.placeholder = window.t("new-role");
    Caption = pas.Admin_List.C.el("input");
    Caption.placeholder = window.t("What it is for");
    Scope = pas.Admin_List.C.el("select");
    Choices = Array.of(Array.of("site",window.t("site")),Array.of("room",window.t("in one channel")));
    for (var $l3 = 0, $end3 = Choices.length - 1; $l3 <= $end3; $l3++) {
      I = $l3;
      Opt = pas.Admin_List.C.el("option","",Choices[I][1]);
      Opt["value"] = Choices[I][0];
      Scope.appendChild(Opt);
    };
    Add = pas.Admin_List.C.el("button","primary",window.t("Make the role"));
    Form.append(Name,Caption,Scope,Add);
    Form.addEventListener("submit",async function (E) {
      E.preventDefault();
      try {
        await pas.Admin_List.C.post("/api/admin/role",pas.JS.New(["name",Name.value,"caption",Caption.value,"scope",Scope.value]));
        pas.Admin_List.C.route("/admin",false);
      } catch ($e) {
        pas.Admin_List.C.failed($e);
      };
    });
    Box.appendChild(Form);
  };
  this.AdminMembers = function (Box, Data, Can) {
    var Giveable = null;
    var Columns = null;
    var RoleChoices = null;
    var R = null;
    var Search = "";
    var I = 0;
    function Detail(U, Holder, View) {
      var Head = null;
      var Sect = null;
      var Panel = null;
      var List = null;
      var Roles = null;
      var Acts = null;
      var Facts = null;
      var Have = null;
      var Joined = undefined;
      var Seen = undefined;
      var Title = undefined;
      var ClosedBy = undefined;
      var N = 0;
      function AddressLine(A) {
        var Li = null;
        var B = null;
        Li = pas.Admin_List.C.el("li");
        B = pas.Admin_List.C.el("button","lv-link",A["ip"]);
        B["type"] = "button";
        B.title = window.t("Its whole story under Address: score, blocks, requests");
        B.addEventListener("click",function (E) {
          var Today = "";
          var Back = "";
          Today = (new Date()).toISOString().slice(0,10);
          Back = (new Date(Math.max(Date.parse("" + A["seen"]) - 864e5,Date.now() - (30 * 864e5)))).toISOString().slice(0,10);
          pas.Admin_Address.AddressPanel(A["ip"],Panel,pas.JS.New(["from",Back,"to",Today]));
        });
        Li.append(B,document.createTextNode(" " + pas.Admin_List.C.ago(A["seen"]) + ", " + window.tn(A["times"],"%d time","%d times")));
        List.appendChild(Li);
      };
      function RoleTick(Role) {
        var Label_ = null;
        var Tick = null;
        Label_ = pas.Admin_List.C.el("label");
        Tick = pas.Admin_List.C.el("input");
        Tick.type = "checkbox";
        Tick.checked = Have.indexOf(Role["name"]) >= 0;
        Tick.disabled = pas.Admin_List.Same(U["name"],pas.Admin_List.Me["name"]) || !Can("manage-members");
        Tick.addEventListener("change",async function (E) {
          if (Tick.checked) {
            Have.push(Role["name"])}
           else Have.splice(Have.indexOf(Role["name"]),1);
          try {
            pas.Admin_List.C.toast(await pas.Admin_List.C.post("/api/admin/member",pas.JS.New(["name",U["name"],"roles",Have.join(",")])));
            U["roles"] = Have.join(",");
            View.changed(U);
          } catch ($e) {
            pas.Admin_List.C.failed($e);
            Tick.checked = !Tick.checked;
          };
        });
        Label_.append(Tick,document.createTextNode(" " + ("" + Role["name"])));
        Roles.appendChild(Label_);
      };
      function Act(Caption, Cls, Run) {
        var B = null;
        B = pas.Admin_List.C.el("button",Cls,Caption);
        B["type"] = "button";
        B.addEventListener("click",async function (E) {
          try {
            await Run();
          } catch ($e) {
            pas.Admin_List.C.failed($e);
          };
        });
        Acts.appendChild(B);
      };
      function Again() {
        View.unpick();
        View.reload();
      };
      async function Reopen() {
        var Result = undefined;
        pas.Admin_List.C.toast(await pas.Admin_List.C.post("/api/admin/member",pas.JS.New(["name",U["name"],"reopen","1"])));
        pas.Admin_List.C.toast(window.t("It has no password now: make a password link for %s.",U["name"]));
        Again();
        return Result;
      };
      async function Ban() {
        var Result = undefined;
        var Banned = "";
        if (!Boolean(U["banned"]) && !window.confirm(window.t("Ban %s? They are signed out and can only read.",U["name"]))) return Result;
        if (Boolean(U["banned"])) {
          Banned = "0"}
         else Banned = "1";
        pas.Admin_List.C.toast(await pas.Admin_List.C.post("/api/admin/member",pas.JS.New(["name",U["name"],"banned",Banned])));
        U["banned"] = !Boolean(U["banned"]);
        View.changed(U);
        return Result;
      };
      async function PasswordLink() {
        var Result = undefined;
        var Address = "";
        var Shown = null;
        var Copy = null;
        var Made = null;
        var Old = null;
        Address = (await pas.Admin_List.C.post("/api/admin/member",pas.JS.New(["name",U["name"],"password_link","1"]))).trim();
        if (Address.charAt(0) === "/") Address = window.location.origin + window.SiteBase.url(Address);
        Shown = pas.Admin_List.C.el("pre","newtoken",Address);
        Copy = pas.Admin_List.C.el("button","",window.t("Copy"));
        Copy["type"] = "button";
        Copy.addEventListener("click",function (E) {
          window.navigator["clipboard"].writeText(Address).then(function (Done) {
            var Result = undefined;
            Copy.textContent = window.t("Copied");
            return Result;
          });
        });
        Made = pas.Admin_List.C.el("div","lv-actions member-link");
        Made.append(Shown,Copy,pas.Admin_List.C.el("p","hint",window.t("Give this link to %s. It sets a new password, works once and for a week. Private conversations locked with the old password stay closed.",U["name"])));
        Old = pas.Admin_List.C.$(".member-link",Holder);
        if (Boolean(Old)) {
          Old.replaceWith(Made)}
         else Acts.after(Made);
        return Result;
      };
      async function Rename() {
        var Result = undefined;
        var Name = undefined;
        Name = window.prompt(window.t("A new name for %s. Mentions of the old name stay as they were written.",U["name"]),"" + U["name"]);
        if (!Boolean(Name) || pas.Admin_List.Same(Name.trim(),U["name"])) return Result;
        pas.Admin_List.C.toast(await pas.Admin_List.C.post("/api/admin/member",pas.JS.New(["name",U["name"],"rename",Name.trim()])));
        Again();
        return Result;
      };
      async function CloseAccount() {
        var Result = undefined;
        var Reason = undefined;
        Reason = window.prompt(window.t("Close the account of %s? They are signed out for good; their address, password and profile are wiped, and what they wrote stays. Why? (kept with the account)",U["name"]),"");
        if (!Boolean(Reason) || !Boolean(Reason.trim())) return Result;
        pas.Admin_List.C.toast(await pas.Admin_List.C.post("/api/admin/member",pas.JS.New(["name",U["name"],"close","1","reason",Reason.trim()])));
        Again();
        return Result;
      };
      Head = pas.Admin_List.C.el("div","lv-detail-head");
      Head.appendChild(pas.Admin_List.C.link("/u/" + pas.Admin_List.C.enc(U["name"]),"",U["name"]));
      if (Boolean(U["banned"])) Head.appendChild(pas.Admin_List.C.chip(window.t("Banned"),"bad"));
      if (Boolean(U["closed"])) Head.appendChild(pas.Admin_List.C.chip(window.t("Closed"),"bad"));
      Holder.appendChild(Head);
      if (Boolean(U["joined"])) {
        Joined = window.dateText(U["joined"])}
       else Joined = "";
      if (Boolean(U["seen"])) {
        Seen = pas.Admin_List.C.ago(U["seen"])}
       else Seen = window.t("never back");
      Facts = Array.of(Array.of(window.t("Joined"),Joined),Array.of(window.t("Last here"),Seen),Array.of(window.t("Messages"),pas.Admin_List.LocaleNumber(U["posts"])));
      if (Boolean(U["closed"])) {
        if (pas.Admin_List.Same(U["closed_by"],U["name"])) {
          ClosedBy = window.t("the member")}
         else ClosedBy = U["closed_by"];
        Facts = Facts.concat(Array.of(Array.of(window.t("Closed"),window.dateText(U["closed"])),Array.of(window.t("Closed by"),ClosedBy),Array.of(window.t("Reason"),U["closed_reason"])));
      };
      pas.Admin_List.C.facts(Holder,Facts);
      if (Boolean(U["addresses"])) {
        Sect = pas.Admin_List.C.el("div","member-addresses");
        if (Number(U["address_count"]) > U["addresses"].length) {
          Title = window.t("Addresses: the %d newest of %d",U["addresses"].length,U["address_count"])}
         else Title = window.t("Addresses");
        Sect.appendChild(pas.Admin_List.C.el("h4","",Title));
        Panel = pas.Admin_List.C.el("div","lv-detail");
        List = pas.Admin_List.C.el("ul","member-address-list");
        for (var $l = 0, $end = U["addresses"].length - 1; $l <= $end; $l++) {
          N = $l;
          AddressLine(U["addresses"][N]);
        };
        Sect.append(List,Panel);
        Holder.appendChild(Sect);
      };
      Have = $impl.Filled(U["roles"]);
      Roles = pas.Admin_List.C.el("div","lv-actions rolechecks");
      Roles.hidden = Boolean(U["closed"]);
      Roles.appendChild(pas.Admin_List.C.el("span","dim",window.t("Roles") + ":"));
      for (var $l1 = 0, $end1 = Giveable.length - 1; $l1 <= $end1; $l1++) {
        N = $l1;
        RoleTick(Giveable[N]);
      };
      Holder.appendChild(Roles);
      if (pas.Admin_List.Same(U["name"],pas.Admin_List.Me["name"])) {
        Holder.appendChild(pas.Admin_List.C.el("p","hint",window.t("Ask another admin to change your own account.")));
        return;
      };
      Acts = pas.Admin_List.C.el("div","lv-actions");
      if (Boolean(U["closed"])) {
        if (Can("manage-members")) Act(window.t("Reopen the account"),"",Reopen);
      } else if (Can("ban")) {
        if (Boolean(U["banned"])) {
          Act(window.t("Lift the ban"),"",Ban)}
         else Act(window.t("Ban"),"bad",Ban);
      };
      if (Can("manage-members")) {
        if (!Boolean(U["closed"])) Act(window.t("Password link"),"",PasswordLink);
        Act(window.t("Rename"),"",Rename);
        if (!Boolean(U["closed"])) Act(window.t("Close the account"),"bad",CloseAccount);
      };
      if (Acts.children.length > 0) Holder.appendChild(Acts);
    };
    async function Remote(State) {
      var Result = null;
      var A = null;
      var Filters = null;
      Filters = State["filters"];
      A = await pas.Admin_List.C.get("/api/admin/members?q=" + pas.Admin_List.C.enc(State["q"]) + "&sort=" + pas.Admin_List.C.enc(State["sort"]) + "&role=" + pas.Admin_List.C.enc(pas.Admin_List.Either(Filters["role"],"")) + "&state=" + pas.Admin_List.C.enc(pas.Admin_List.Either(Filters["state"],"")) + "&page=" + ("" + State["page"]));
      Result = pas.JS.New(["rows",A["members"],"total",A["total"]]);
      return Result;
    };
    function RolesCell(U) {
      var Result = undefined;
      var Span = null;
      var Names = null;
      var N = 0;
      Span = pas.Admin_List.C.el("span","chips");
      Names = $impl.Filled(U["roles"]);
      for (var $l = 0, $end = Names.length - 1; $l <= $end; $l++) {
        N = $l;
        if (pas.Admin_List.Same(Names[N],"admin")) {
          Span.appendChild(pas.Admin_List.C.chip(Names[N],"admin"))}
         else Span.appendChild(pas.Admin_List.C.chip(Names[N],""));
      };
      if (Boolean(U["banned"])) Span.appendChild(pas.Admin_List.C.chip(window.t("Banned"),"bad"));
      if (Boolean(U["closed"])) Span.appendChild(pas.Admin_List.C.chip(window.t("Closed"),"bad"));
      Result = Span;
      return Result;
    };
    function AddressesCell(U) {
      var Result = undefined;
      if (!Boolean(U["addresses"]) || !Boolean(U["addresses"].length)) return "";
      Result = "" + U["addresses"][0]["ip"];
      if (Number(U["address_count"]) > 1) Result = "" + Result + " +" + String(Number(U["address_count"]) - 1);
      return Result;
    };
    Giveable = new Array();
    for (var $l = 0, $end = Data["roles"].length - 1; $l <= $end; $l++) {
      I = $l;
      R = Data["roles"][I];
      if (pas.Admin_List.Same(R["scope"],"site") && !pas.Admin_List.Same(R["name"],"member") && !pas.Admin_List.Same(R["name"],"guest")) Giveable.push(R);
    };
    if (Can("view-member-addresses")) {
      Search = window.t("Find a member by name or address")}
     else Search = window.t("Find a member by name");
    Columns = Array.of(pas.JS.New(["key","name","title",window.t("Member"),"cell",function (U) {
      var Result = undefined;
      Result = pas.Admin_List.C.link("/u/" + pas.Admin_List.C.enc(U["name"]),"",U["name"]);
      return Result;
    }]),pas.JS.New(["key","roles","title",window.t("Roles"),"nosort",true,"cell",RolesCell]),pas.JS.New(["key","posts","title",window.t("Messages"),"num",true]),pas.JS.New(["key","joined","title",window.t("Joined"),"down",true,"wide",true,"cell",function (U) {
      var Result = undefined;
      if (Boolean(U["joined"])) {
        Result = window.dateText(U["joined"])}
       else Result = "";
      return Result;
    }]),pas.JS.New(["key","seen","title",window.t("Last here"),"down",true,"cell",function (U) {
      var Result = undefined;
      if (Boolean(U["seen"])) {
        Result = pas.Admin_List.C.ago(U["seen"])}
       else Result = window.t("never back");
      return Result;
    }]));
    if (Can("view-member-addresses")) Columns = Columns.concat(Array.of(pas.JS.New(["key","addresses","title",window.t("Address"),"nosort",true,"wide",true,"cell",AddressesCell])));
    RoleChoices = new Array();
    for (var $l1 = 0, $end1 = Giveable.length - 1; $l1 <= $end1; $l1++) {
      I = $l1;
      RoleChoices.push(Array.of(Giveable[I]["name"],Giveable[I]["name"]));
    };
    RoleChoices = RoleChoices.concat(Array.of(Array.of("none",window.t("No role given"))));
    pas.Admin_List.ListView(Box,pas.JS.New(["id","members","key",function (U) {
      var Result = undefined;
      Result = U["name"];
      return Result;
    },"sort","-seen","csv","members","search",Search,"remote",Remote,"columns",Columns,"filters",Array.of(pas.JS.New(["key","role","title",window.t("Role"),"all",window.t("Every role"),"options",RoleChoices]),pas.JS.New(["key","state","title",window.t("Banned or closed"),"all",window.t("Everyone"),"options",Array.of(Array.of("active",window.t("Neither")),Array.of("banned",window.t("Banned")),Array.of("closed",window.t("Closed")))])),"noun",function (N) {
      var Result = undefined;
      Result = window.tn(N,"%d member","%d members");
      return Result;
    },"detail",Detail]));
  };
  $mod.$implcode = function () {
    $impl.Filled = function (List) {
      var Result = null;
      var Parts = null;
      var I = 0;
      Parts = List.split(",");
      Result = new Array();
      for (var $l = 0, $end = Parts.length - 1; $l <= $end; $l++) {
        I = $l;
        if (Boolean(Parts[I])) Result.push(Parts[I]);
      };
      return Result;
    };
    $impl.RoleTitle = function (Name) {
      var Result = undefined;
      Result = pas.Admin_List.Either(pas.JS.New(["owner",window.t("channel owner"),"room-moderator",window.t("channel moderator")])["" + Name],Name);
      return Result;
    };
  };
},["Admin_Address"]);
rtl.module("AdminPage",["System"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  $mod.$implcode = function () {
    $impl.OpenAdmin = async function () {
      var Result = undefined;
      var Generation = undefined;
      var Data = null;
      var Head = null;
      var Menu = null;
      var Page = null;
      var Nav = null;
      var Rooms = null;
      var Body = null;
      var Parts = null;
      var Scripts = null;
      var Tabs = null;
      var Settings = null;
      var Lit = null;
      var Modules = null;
      var Groups = null;
      var Order = null;
      var Members = null;
      var PartOfGroup = null;
      var Extra = null;
      var Last = undefined;
      var Selected = null;
      var I = 0;
      var J = 0;
      function Can(P) {
        var Result = false;
        Result = Data["can"].indexOf(P) >= 0;
        return Result;
      };
      function Tab(Title, Build, Caption, Count, Group) {
        var B = null;
        var Badge = null;
        var Holder = null;
        var Built = false;
        function SetCount(N) {
          Badge.hidden = !(Number(N) > 0);
          if (Number(N) > 0) {
            Badge.textContent = String(N)}
           else Badge.textContent = "";
        };
        B = pas.Admin_List.C.el("button","room");
        B["type"] = "button";
        B.appendChild(pas.Admin_List.C.el("span","name",pas.Admin_List.Either(pas.Admin_List.Either(Caption,pas.JS.New(["Members",window.t("Members"),"Permissions",window.t("Permissions"),"Settings",window.t("Settings"),"Look",window.t("Look"),"Channels",window.t("Channels"),"Private",window.t("Private"),"Reports",window.t("Reports"),"Blocked",window.t("Blocked")])["" + Title]),Title)));
        Badge = pas.Admin_List.C.el("span","badge mention");
        Badge.hidden = true;
        B.appendChild(Badge);
        if (typeof(Count) === "number") {
          SetCount(Count)}
         else if (typeof(Count) === "function") Promise.resolve().then(Count).then(SetCount).catch(function (Why) {
          var Result = undefined;
          return Result;
        });
        Holder = pas.Admin_List.C.el("section","part");
        Holder.hidden = true;
        Page.appendChild(Holder);
        Built = false;
        B.addEventListener("click",function (E) {
          var N = 0;
          for (var $l = 0, $end = Parts.length - 1; $l <= $end; $l++) {
            N = $l;
            Parts[N].button.classList.remove("active");
            Parts[N].holder.hidden = true;
          };
          B.classList.add("active");
          Holder.hidden = false;
          if (!Built) {
            Built = true;
            Build(Holder);
          };
          if (Body.classList.contains("menu")) pas.Admin_List.C.toggleMenu();
          pas.Admin_List.Stream.scrollTop = 0;
          try {
            window.localStorage.setItem("admin-tab","" + Title);
          } catch ($e) {
          };
        });
        Parts.push(pas.JS.New(["button",B,"holder",Holder,"title",Title,"setCount",SetCount,"group",pas.Admin_List.Either(Group,"More")]));
      };
      function PartSettings(Group) {
        var Result = false;
        var N = 0;
        Result = false;
        for (var $l = 0, $end = Settings.length - 1; $l <= $end; $l++) {
          N = $l;
          if (pas.Admin_List.Same(PartOfGroup["" + Settings[N]["group"]],Group)) return true;
        };
        return Result;
      };
      function PartTab(Group) {
        Tab(Group + " settings",function (Box) {
          pas.Admin_Settings.AdminSettings(Box,Data,function (G) {
            var Result = false;
            Result = pas.Admin_List.Same(PartOfGroup["" + G],Group);
            return Result;
          },Group);
        },window.t("Settings"),undefined,Group);
      };
      function PartByTitle(Title) {
        var Result = null;
        var N = 0;
        for (var $l = 0, $end = Parts.length - 1; $l <= $end; $l++) {
          N = $l;
          if (pas.Admin_List.Same(Parts[N].title,Title)) return Parts[N];
        };
        Result = undefined;
        return Result;
      };
      function AdminTab(Title) {
        var Result = false;
        var P = null;
        P = PartByTitle(Title);
        if (Boolean(P)) P.button.click();
        Result = Boolean(P);
        return Result;
      };
      function AdminCount(Title, N) {
        var P = null;
        P = PartByTitle(Title);
        if (Boolean(P)) P.setCount(N);
      };
      Generation = pas.Admin_List.S["generation"];
      try {
        Scripts = pas.Admin_List.Extras["adminScripts"];
        I = 0;
        while (I < Scripts.length) {
          await pas.Admin_List.C.loadScript(Scripts[I]["src"]);
          I += 1;
        };
      } catch ($e) {
        pas.Admin_List.C.failed($e);
        return Result;
      };
      if (!pas.Admin_List.Same(Generation,pas.Admin_List.S["generation"])) return Result;
      Data = await pas.Admin_List.C.get("/api/admin");
      if (!pas.Admin_List.Same(Generation,pas.Admin_List.S["generation"])) return Result;
      pas.Admin_List.S["title"] = window.t("Admin");
      Head = pas.Admin_List.C.$("#roomhead");
      Menu = pas.Admin_List.C.iconButton("menu",window.t("Channels"),"menubtn");
      Menu.addEventListener("click",pas.Admin_List.C["toggleMenu"]);
      Head.append(Menu,pas.Admin_List.C.el("div","titles"));
      pas.Admin_List.C.$(".titles",Head).appendChild(pas.Admin_List.C.el("h1","",window.t("Running %s",pas.Admin_List.SiteName)));
      if (!pas.Admin_List.IsUndef(Data["members_total"])) pas.Admin_List.C.$(".titles",Head).appendChild(pas.Admin_List.C.el("p","topic",window.tn(Data["members_total"],"%d members","%d members")));
      Page = pas.Admin_List.C.el("div","admin");
      pas.Admin_List.Stream["noPin"] = true;
      pas.Admin_List.Stream["pinned"] = false;
      pas.Admin_List.Stream.appendChild(Page);
      pas.Admin_List.Stream.scrollTop = 0;
      Body = document.body;
      Nav = pas.Admin_List.C.$("#adminnav");
      if (!Boolean(Nav)) {
        Nav = pas.Admin_List.C.el("nav");
        Nav.id = "adminnav";
        Rooms = pas.Admin_List.C.$("#roomlist");
        if (Boolean(Rooms) && Boolean(Rooms["after"])) {
          Rooms.after(Nav)}
         else Page.appendChild(Nav);
      };
      Nav.hidden = false;
      Nav.setAttribute("aria-label",window.t("Admin"));
      Nav.replaceChildren();
      Body.classList.add("admin-view");
      Parts = new Array();
      pas.Admin_List.FilePaths = pas.Admin_List.Either(Data["file_paths"],new Array());
      Lit = String(pas.Admin_List.Either(Data["parts"],"")).split(" ");
      PartOfGroup = Object.assign(pas.JS.New(["Chat","Chat","Wiki","Wiki","Forum","Forum"]),pas.Admin_List.Extras["settingGroups"]);
      Settings = pas.Admin_List.Either(Data["settings"],new Array());
      Modules = new Array();
      for (var $l = 0, $end = Settings.length - 1; $l <= $end; $l++) {
        I = $l;
        if (pas.Admin_List.Same(Settings[I]["group"],"Parts")) Modules.push(Settings[I]["name"]);
      };
      if (Boolean(Data["settings"]) || Can("view-admin")) Tab("Overview",function (Box) {
        pas.Admin_Site.AdminOverview(Box,Data,Can);
      },window.t("Overview"),undefined,"Site");
      Tabs = pas.Admin_List.Extras["adminTabs"];
      I = 0;
      while (I < Tabs.length) {
        Extra = Tabs[I];
        if (Boolean(Extra["first"]) && Boolean(Extra["permission"]) && Can("" + Extra["permission"])) Tab(Extra["title"],Extra["build"],window.t(Extra["title"]),Extra["badge"],pas.Admin_List.Either(Extra["group"],"Site"));
        I += 1;
      };
      if (Boolean(Data["settings"]) && Can("manage-settings")) Tab("Settings",function (Box) {
        pas.Admin_Settings.AdminSettings(Box,Data,function (Group) {
          var Result = false;
          Result = !pas.Admin_List.Same(Group,"Parts") && !Boolean(PartOfGroup["" + Group]);
          return Result;
        },undefined);
      },undefined,undefined,"Site");
      if (Boolean(Data["settings"]) && Can("manage-settings")) Tab("Look",pas.Admin_Site.AdminLook,undefined,undefined,"Site");
      if (Boolean(Data["members"])) Tab("Members",function (Box) {
        pas.Admin_Members.AdminMembers(Box,Data,Can);
      },undefined,undefined,"Site");
      if (Boolean(Data["permissions"])) Tab("Permissions",function (Box) {
        pas.Admin_Members.AdminPermissions(Box,Data);
      },undefined,undefined,"Site");
      if (Can("read-reports")) Tab("Reports",pas.Admin_Reports.AdminReports,undefined,pas.Admin_List.Either(Data["open_reports"],0),"Site");
      if (Can("view-visitors") || Can("manage-blocks")) Tab("Visitors",pas.Admin_Visitors.AdminVisitors,window.t("Visitors"),undefined,"Server");
      if (Can("view-storage")) Tab("Storage",pas.Admin_Site.AdminStorage,window.t("Storage"),undefined,"Server");
      if (Can("manage-backups")) Tab("Backup",pas.Admin_Backup.AdminBackup,window.t("Backup"),undefined,"Server");
      if (Boolean(Data["channels"])) Tab("Channels",function (Box) {
        pas.Admin_Chat.AdminChannels(Box,Data);
      },undefined,undefined,"Chat");
      if ((Lit.indexOf("chat") >= 0) && Can("manage-private")) Tab("Private",pas.Admin_Chat.AdminPrivate,undefined,undefined,"Chat");
      I = 0;
      while (I < Tabs.length) {
        Extra = Tabs[I];
        if (!Boolean(Extra["first"]) && Boolean(Extra["permission"]) && Can("" + Extra["permission"]) && (!Boolean(Extra["part"]) || (Lit.indexOf(Extra["part"]) >= 0))) Tab(Extra["title"],Extra["build"],window.t(Extra["title"]),Extra["badge"],Extra["group"]);
        I += 1;
      };
      if (Boolean(Data["settings"])) {
        Groups = Array.of("Chat","Wiki","Forum").concat(Object.values(pas.Admin_List.Extras["settingGroups"]));
        for (var $l1 = 0, $end1 = Groups.length - 1; $l1 <= $end1; $l1++) {
          I = $l1;
          if ((Groups.indexOf(Groups[I]) === I) && PartSettings("" + Groups[I]) && ((Modules.indexOf(Groups[I].toLowerCase()) < 0) || (Lit.indexOf(Groups[I].toLowerCase()) >= 0))) PartTab("" + Groups[I]);
        };
      };
      Order = Array.of("Site","Server","Chat","Wiki","Forum");
      for (var $l2 = 0, $end2 = Parts.length - 1; $l2 <= $end2; $l2++) {
        I = $l2;
        if (Order.indexOf(Parts[I].group) < 0) Order.push(Parts[I].group);
      };
      for (var $l3 = 0, $end3 = Order.length - 1; $l3 <= $end3; $l3++) {
        I = $l3;
        Members = new Array();
        for (var $l4 = 0, $end4 = Parts.length - 1; $l4 <= $end4; $l4++) {
          J = $l4;
          if (pas.Admin_List.Same(Parts[J].group,Order[I])) Members.push(Parts[J]);
        };
        if (Members.length === 0) continue;
        Nav.appendChild(pas.Admin_List.C.el("div","group",window.t(Order[I])));
        for (var $l5 = 0, $end5 = Members.length - 1; $l5 <= $end5; $l5++) {
          J = $l5;
          Nav.appendChild(Members[J].button);
        };
      };
      pas.Admin_List.S["adminCan"] = Can;
      pas.Admin_List.S["adminTab"] = AdminTab;
      pas.Admin_List.S["adminCount"] = AdminCount;
      if (Parts.length > 0) {
        Last = Parts[0].title}
       else Last = "Overview";
      try {
        Last = pas.Admin_List.Either(window.localStorage.getItem("admin-tab"),Last);
      } catch ($e) {
      };
      Selected = PartByTitle(Last);
      if (!Boolean(Selected)) Selected = Parts[0];
      if (Boolean(Selected)) Selected.button.click();
      pas.Admin_List.C.syncNow(true);
      return Result;
    };
  };
  $mod.$init = function () {
    pas.Admin_List.C["listView"] = pas.Admin_List.ListView;
    pas.Admin_List.C["stat"] = pas.Admin_List.Stat;
    pas.Admin_List.C["adminTable"] = pas.Admin_List.AdminTable;
    pas.Admin_List.C["openAdmin"] = $impl.OpenAdmin;
  };
},["JS","Web","Admin_List","Admin_Address","Admin_Backup","Admin_Reports","Admin_Visitors","Admin_Site","Admin_Settings","Admin_Chat","Admin_Members"]);

rtl.run('AdminPage');
}
