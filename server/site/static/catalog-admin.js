if (!pas.CatalogAdminPage) {
rtl.module("CatalogAdminPage",["System"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  $mod.$implcode = function () {
    $impl.Same = function (A, B) {
      var Result = false;
      Result = (typeof(A) === typeof(B)) && (A == B);
      return Result;
    };
    $impl.Plus = function (A, B) {
      return A + B;
    };
    $impl.El = function (Tag, Cls, Text) {
      var Result = null;
      Result = window.Site.el(Tag,Cls,Text);
      return Result;
    };
    $impl.OrValue = function (Item, Key, Fallback) {
      var Result = undefined;
      Result = Item[Key];
      if (!Boolean(Result)) Result = Fallback;
      return Result;
    };
    $impl.ArrayOrEmpty = function (Value) {
      var Result = null;
      if (Boolean(Value)) {
        Result = Value}
       else Result = new Array();
      return Result;
    };
    $impl.First = function (Value) {
      var Result = null;
      var Items = null;
      Items = $impl.ArrayOrEmpty(Value);
      if ((Items.length > 0) && Boolean(Items[0])) {
        Result = Items[0]}
       else Result = new Object();
      return Result;
    };
    $impl.Table = function (Holder, Title, Headings, Rows) {
      Holder.appendChild($impl.El("h2","",Title));
      window.Site.adminTable(Holder,Headings,Rows);
    };
    $impl.Catalog = function (Holder) {
      var More = null;
      var Kinds = null;
      var Works = null;
      var Shows = null;
      var Tabs = null;
      var Subs = null;
      var Tiles = null;
      var Numbers = null;
      var Notice = null;
      var AddPlace = null;
      var Can = null;
      var Drawn = false;
      var Counts = false;
      var AddOffered = false;
      var Entries = null;
      var I = 0;
      var Extra = null;
      function Caption(V) {
        var Result = undefined;
        var Words = null;
        Words = window.Site.extras["catalogCaptions"];
        if (Boolean(Words) && Boolean(Words["" + V])) {
          Result = Words["" + V]}
         else Result = window.t(V.charAt(0).toUpperCase() + V.slice(1));
        return Result;
      };
      function Choices(Data) {
        var Options = null;
        var Values = null;
        var N = 0;
        if (!Boolean(Data["choices"]) || (Kinds.length > 0) || (Works.length > 0)) return;
        Options = Data["choices"];
        Values = $impl.ArrayOrEmpty(Options["kind"]);
        for (var $l = 0, $end = Values.length - 1; $l <= $end; $l++) {
          N = $l;
          Kinds.push(new Array(Values[N],Caption(Values[N])));
        };
        Values = $impl.ArrayOrEmpty(Options["works_with"]);
        for (var $l1 = 0, $end1 = Values.length - 1; $l1 <= $end1; $l1++) {
          N = $l1;
          Works.push(new Array(Values[N],Caption(Values[N])));
        };
      };
      function Named(List, V) {
        var Result = undefined;
        var N = 0;
        var Pair = null;
        Result = V;
        for (var $l = 0, $end = List.length - 1; $l <= $end; $l++) {
          N = $l;
          Pair = List[N];
          if ($impl.Same(Pair[0],V)) {
            Result = Pair[1];
            return Result;
          };
        };
        return Result;
      };
      function Flagged(Item) {
        var Result = false;
        Result = (new RegExp("^Flagged for review")).test("" + $impl.OrValue(Item,"hidden_note",""));
        return Result;
      };
      function NumberRows(List) {
        var Result = null;
        var N = 0;
        var Item = null;
        Result = new Array();
        for (var $l = 0, $end = List.length - 1; $l <= $end; $l++) {
          N = $l;
          Item = List[N];
          Result.push(new Array(window.t(Item["name"]),Item["count"]));
        };
        return Result;
      };
      function Summary(Data) {
        var N = 0;
        var HasFlagged = false;
        var HasStatus = false;
        var Statuses = null;
        Tiles.replaceChildren();
        window.Site.stat(Tiles,Data["total"],window.t("Entries"),undefined,undefined);
        window.Site.stat(Tiles,Data["hidden"],window.t("Hidden"),undefined,undefined);
        if (Boolean(Data["reported"])) {
          window.Site.stat(Tiles,$impl.OrValue(Data,"reported",0),window.t("Reported by members"),"","warn")}
         else window.Site.stat(Tiles,$impl.OrValue(Data,"reported",0),window.t("Reported by members"),"","");
        if (Boolean(Data["flagged"])) {
          window.Site.stat(Tiles,Data["flagged"],window.t("Flagged for review"),undefined,undefined);
          HasFlagged = false;
          for (var $l = 0, $end = Shows.length - 1; $l <= $end; $l++) {
            N = $l;
            if (Shows[N][0] == "flagged") HasFlagged = true;
          };
          if (!HasFlagged) Shows.push(new Array("flagged",window.t("Flagged for review")));
        };
        if (Drawn) return;
        Drawn = true;
        $impl.Table(Numbers,window.t("By kind"),new Array(window.t("Kind"),window.t("Entries")),NumberRows(Data["kinds"]));
        if (Data["sources"].length > 0) $impl.Table(Numbers,window.t("By source"),new Array(window.t("Source"),window.t("Entries")),NumberRows(Data["sources"]));
        Statuses = Data["statuses"];
        HasStatus = false;
        for (var $l1 = 0, $end1 = Statuses.length - 1; $l1 <= $end1; $l1++) {
          N = $l1;
          if (Statuses[N]["name"] != "unknown") HasStatus = true;
        };
        if (HasStatus) $impl.Table(Numbers,window.t("By status"),new Array(window.t("Status"),window.t("Entries")),NumberRows(Statuses));
      };
      function Was(Item, Key) {
        var Result = undefined;
        if (Key !== "kind") {
          Result = $impl.OrValue(Item,Key,"");
          return Result;
        };
        if (Kinds.length > 0) {
          Result = $impl.OrValue(Item,"kind","unknown");
          return Result;
        };
        if (Boolean(Item["kind"]) && (Item["kind"] != "unknown")) {
          Result = Item["kind"]}
         else Result = "";
        return Result;
      };
      function EntryFields(Form, Fields, Item) {
        function Field(Key, Caption, Kind) {
          var Label_ = null;
          var Input = null;
          var Option = null;
          var N = 0;
          var Pair = null;
          Label_ = $impl.El("label","",Caption);
          if (rtl.isArray(Kind)) {
            Input = $impl.El("select","",undefined)}
           else if (Kind == "area") {
            Input = $impl.El("textarea","",undefined)}
           else Input = $impl.El("input","",undefined);
          Input["name"] = Key;
          if (rtl.isArray(Kind)) {
            for (var $l = 0, $end = Kind.length - 1; $l <= $end; $l++) {
              N = $l;
              Pair = Kind[N];
              Option = $impl.El("option","",Pair[1]);
              Option.value = "" + Pair[0];
              Input.appendChild(Option);
            }}
           else if (Kind == "area") {
            Input["rows"] = 3}
           else if (Kind == "file") {
            Input["type"] = "file";
            Input["accept"] = "image/png,image/jpeg,image/gif,image/webp";
          } else if (Key === "url") {
            Input["maxLength"] = 2000}
           else if (Key === "kind") {
            Input["maxLength"] = 20}
           else Input["maxLength"] = 300;
          if (Kind != "file") Input["value"] = Was(Item,Key);
          Fields[Key] = Input;
          Label_.appendChild(Input);
          Form.appendChild(Label_);
        };
        Field("title",window.t("Title"),"");
        Field("url",window.t("Where it lives (an address), if it lives somewhere"),"");
        Field("summary",window.t("What it is, in a few lines"),"area");
        if (Kinds.length > 0) {
          Field("kind",window.t("Kind"),Kinds)}
         else Field("kind",window.t("Kind"),"");
        if ((Works.length > 0) && Boolean(Item["id"])) Field("works_with",window.t("Works with"),Works);
        Field("categories",window.t("Categories (comma separated)"),"");
        Field("license",window.t("License, if it has one"),"");
        Field("picture",window.t("Picture (PNG, JPEG, GIF or WebP)"),"file");
        Fields["title"]["required"] = true;
        Fields["url"]["type"] = "url";
        Fields["url"]["placeholder"] = "https://";
      };
      async function SendPicture(Id, Input) {
        var Sent = null;
        if (Input.files.length === 0) return;
        Sent = new FormData();
        Sent.append("id","" + Id);
        Sent.append("file",Input.files.item(0));
        await window.Site.post("/api/admin/catalog/picture",Sent);
      };
      function Button(Parent, Caption, Work, Cls) {
        var Control = null;
        async function Click(E) {
          Control.disabled = true;
          try {
            try {
              await Work.call(null);
            } catch ($e) {
              Notice.textContent = "" + $e["message"];
            };
          } finally {
            Control.disabled = false;
          };
        };
        Control = $impl.El("button",Cls,Caption);
        Control.type = "button";
        Control.addEventListener("click",Click);
        Parent.appendChild(Control);
      };
      function Detail(Item, Box, View) {
        var State = "";
        var Title = undefined;
        var Note = undefined;
        var Head = null;
        var Acts = null;
        var Notes = null;
        var Link = null;
        var Facts = null;
        var Lines = [];
        var N = 0;
        async function Dismiss() {
          await window.Site.post("/api/admin/catalog/dismiss",pas.JS.New(["id",Item["id"]]));
          Counts = true;
          await View.reload();
        };
        async function Hide() {
          var Hidden = "";
          if (Boolean(Item["hidden"])) {
            Hidden = "0"}
           else Hidden = "1";
          await window.Site.post("/api/catalog/hide",pas.JS.New(["id",Item["id"],"hidden",Hidden]));
          Counts = true;
          await View.reload();
        };
        async function Delete() {
          if (!window.confirm(window.t("Delete %s, its ratings and README? This cannot be undone.",Title))) return;
          await window.Site.post("/api/admin/catalog/delete",pas.JS.New(["id",Item["id"]]));
          View.unpick();
          Counts = true;
          await View.reload();
        };
        function EditEntry() {
          var Edit = null;
          var Fields = null;
          var Save = null;
          var Shown = null;
          async function RemovePicture() {
            await window.Site.post("/api/admin/catalog/picture",pas.JS.New(["id",Item["id"],"remove","1"]));
            await View.reload();
          };
          async function Submit(E) {
            var Sent = null;
            var Keys = [];
            var N = 0;
            var Key = "";
            E.preventDefault();
            Save.disabled = true;
            try {
              try {
                Sent = pas.JS.New(["id",Item["id"],"categories",Fields["categories"]["value"]]);
                Keys = Object.keys(Fields);
                for (var $l = 0, $end = rtl.length(Keys) - 1; $l <= $end; $l++) {
                  N = $l;
                  Key = Keys[N];
                  if ((Key !== "picture") && !$impl.Same(Fields[Key]["value"],Was(Item,Key))) Sent[Key] = Fields[Key]["value"];
                };
                if ((typeof(Sent["kind"]) !== "undefined") && ((("" + Sent["kind"])).trim() === "")) Sent["kind"] = "unknown";
                await window.Site.post("/api/admin/catalog/save",Sent);
                await SendPicture(Item["id"],Fields["picture"]);
                Counts = true;
                await View.reload();
                window.Site.toast(window.t("Saved."),undefined);
              } catch ($e) {
                Notice.textContent = "" + $e["message"];
              };
            } finally {
              Save.disabled = false;
            };
          };
          Box.appendChild($impl.El("h3","",window.t("Edit this entry")));
          Edit = $impl.El("form","lv-edit",undefined);
          Fields = new Object();
          EntryFields(Edit,Fields,Item);
          if (Boolean(Item["picture"])) {
            Shown = $impl.El("img","catalog-admin-picture",undefined);
            Shown.src = "" + Item["picture"];
            Shown.alt = "";
            Edit.appendChild(Shown);
            Button(Edit,window.t("Remove the picture"),RemovePicture,"");
          };
          Save = $impl.El("button","primary",window.t("Save"));
          Edit.appendChild(Save);
          Edit.addEventListener("submit",Submit);
          Box.appendChild(Edit);
        };
        Title = $impl.OrValue(Item,"title",Item["name"]);
        Head = $impl.El("div","lv-detail-head",undefined);
        Link = $impl.El("a","",Title);
        Link.href = "/catalog/" + ("" + Item["id"]);
        Link.target = "_blank";
        Head.appendChild(Link);
        if (Boolean(Item["hidden"])) {
          if (Flagged(Item)) {
            State = window.t("Flagged")}
           else State = window.t("Hidden");
          Head.appendChild(window.Site.chip(State,"bad"));
        } else Head.appendChild(window.Site.chip(window.t("Visible"),undefined));
        Box.appendChild(Head);
        Facts = new Array(new Array(window.t("Key"),Item["entry_key"]),new Array(window.t("Kind"),Named(Kinds,Item["kind"])));
        if (Works.length > 0) Facts.push(new Array(window.t("Works with"),Named(Works,Item["works_with"])));
        Facts.push(new Array(window.t("Categories"),Item["categories"]));
        if (Boolean(Item["hidden"])) {
          State = window.t("Hidden reason");
          Note = $impl.OrValue(Item,"hidden_note",window.t("No reason recorded."));
        } else {
          State = window.t("Note");
          Note = Item["hidden_note"];
        };
        Facts.push(new Array(State,Note));
        window.Site.facts(Box,Facts);
        if (Number(Item["reports"]) > 0) {
          Box.appendChild($impl.El("h3","",window.tn(Item["reports"],"%d member report","%d member reports")));
          Notes = $impl.El("ul","",undefined);
          Lines = ("" + $impl.OrValue(Item,"report_notes","")).split("\n");
          for (var $l = 0, $end = rtl.length(Lines) - 1; $l <= $end; $l++) {
            N = $l;
            if (Lines[N] !== "") Notes.appendChild($impl.El("li","",Lines[N]));
          };
          Box.appendChild(Notes);
        };
        Acts = $impl.El("div","lv-actions",undefined);
        if ((Number(Item["reports"]) > 0) && Can.includes("edit-catalog")) Button(Acts,window.t("Dismiss the reports"),Dismiss,"");
        if (Can.includes("edit-catalog")) if (Boolean(Item["hidden"])) {
          Button(Acts,window.t("Unhide"),Hide,"")}
         else Button(Acts,window.t("Hide"),Hide,"");
        if (Can.includes("delete-catalog")) Button(Acts,window.t("Delete"),Delete,"bad");
        Box.appendChild(Acts);
        if (Can.includes("edit-catalog")) EditEntry();
        Box.appendChild(Notice);
      };
      function OfferAdd() {
        var Adding = null;
        var AddForm = null;
        var Added = null;
        var AddSave = null;
        var AddNote = null;
        async function Submit(E) {
          var Sent = null;
          var Made = null;
          var Keys = [];
          var N = 0;
          E.preventDefault();
          AddSave.disabled = true;
          AddNote.textContent = "";
          try {
            try {
              Sent = new Object();
              Keys = Object.keys(Added);
              for (var $l = 0, $end = rtl.length(Keys) - 1; $l <= $end; $l++) {
                N = $l;
                if (Keys[N] !== "picture") Sent[Keys[N]] = Added[Keys[N]]["value"];
              };
              Made = JSON.parse(await window.Site.post("/api/admin/catalog/add",Sent));
              try {
                await SendPicture(Made["id"],Added["picture"]);
              } catch ($e) {
                window.Site.toast("" + $e["message"],"bad");
              };
              for (var $l1 = 0, $end1 = rtl.length(Keys) - 1; $l1 <= $end1; $l1++) {
                N = $l1;
                Added[Keys[N]]["value"] = Was(new Object(),Keys[N]);
              };
              Adding["open"] = false;
              Counts = true;
              window.Site.toast(window.t("Added."),undefined);
              if (Entries !== null) await Entries.reload();
              window.open("/catalog/" + ("" + Made["id"]),"_blank");
            } catch ($e) {
              AddNote.textContent = "" + $e["message"];
            };
          } finally {
            AddSave.disabled = false;
          };
        };
        if (AddOffered || !Can.includes("edit-catalog")) return;
        AddOffered = true;
        Adding = $impl.El("details","catalog-add",undefined);
        AddForm = $impl.El("form","lv-edit",undefined);
        Added = new Object();
        Adding.appendChild($impl.El("summary","",window.t("Add an entry")));
        EntryFields(AddForm,Added,new Object());
        AddSave = $impl.El("button","primary",window.t("Add"));
        AddNote = $impl.El("p","",undefined);
        AddNote.setAttribute("role","status");
        AddForm.append(AddSave,AddNote);
        Adding.appendChild(AddForm);
        AddForm.addEventListener("submit",Submit);
        AddPlace.appendChild(Adding);
      };
      async function Remote(S) {
        var Result = null;
        var Data = null;
        var Filters = null;
        var Url = "";
        Filters = S["filters"];
        Url = "/api/admin/catalog?q=" + window.Site.enc("" + S["q"]) + "&page=" + ("" + S["page"]) + "&show=" + window.Site.enc("" + $impl.OrValue(Filters,"show","all")) + "&kind=" + window.Site.enc("" + $impl.OrValue(Filters,"kind","")) + "&sort=" + window.Site.enc("" + S["sort"]);
        if (!Counts) Url = Url + "&counts=0";
        Data = await window.Site.get(Url);
        Counts = false;
        Can = Data["can"];
        Choices(Data);
        OfferAdd();
        if (Boolean(Data["kinds"])) Summary(Data);
        Result = pas.JS.New(["rows",Data["items"],"total",Data["matches"]]);
        return Result;
      };
      function State(Item) {
        var Result = undefined;
        if (Boolean(Item["hidden"])) {
          if (Flagged(Item)) {
            Result = window.t("Flagged")}
           else Result = window.t("Hidden")}
         else Result = window.t("Visible");
        return Result;
      };
      More = $impl.ArrayOrEmpty(window.Site.extras["catalogTabs"]);
      Tabs = new Array(pas.JS.New(["key","entries","title",window.t("Entries")]));
      for (var $l = 0, $end = More.length - 1; $l <= $end; $l++) {
        I = $l;
        Extra = More[I];
        Tabs.push(pas.JS.New(["key",Extra["key"],"title",Extra["title"]]));
      };
      Tabs.push(pas.JS.New(["key","activity","title",window.t("Activity")]),pas.JS.New(["key","numbers","title",window.t("Numbers")]));
      Subs = window.Site.subTabs(Holder,"catalog",Tabs);
      $impl.Activity(Subs.holder("activity"));
      Tiles = $impl.El("div","tiles-admin",undefined);
      Numbers = Subs.holder("numbers");
      Subs.holder("entries").appendChild(Tiles);
      Notice = $impl.El("p","",undefined);
      Notice.setAttribute("role","status");
      Can = new Array();
      Drawn = false;
      Counts = true;
      Kinds = new Array();
      Works = new Array();
      Shows = new Array(new Array("hidden",window.t("Hidden entries")),new Array("reported",window.t("Reported by members")));
      AddPlace = $impl.El("div","",undefined);
      Subs.holder("entries").appendChild(AddPlace);
      Entries = null;
      AddOffered = false;
      Entries = window.Site.listView(Subs.holder("entries"),pas.JS.New(["id","catalog","key",function (Item) {
        var Result = undefined;
        Result = "" + Item["id"];
        return Result;
      },"sort","name","csv","catalog","search",window.t("Search by name, title or key"),"remote",Remote,"columns",new Array(pas.JS.New(["key","name","title",window.t("Entry"),"cell",function (Item) {
        var Result = undefined;
        Result = $impl.OrValue(Item,"title",Item["name"]);
        return Result;
      }]),pas.JS.New(["key","key","title",window.t("Key"),"wide",true,"value",function (Item) {
        var Result = undefined;
        Result = Item["entry_key"];
        return Result;
      }]),pas.JS.New(["key","kind","title",window.t("Kind"),"value",function (Item) {
        var Result = undefined;
        Result = Named(Kinds,Item["kind"]);
        return Result;
      }]),pas.JS.New(["key","reports","title",window.t("Reports"),"num",true,"cell",function (Item) {
        var Result = undefined;
        if (Boolean(Item["reports"])) {
          Result = window.Site.chip("" + Item["reports"],"bad")}
         else Result = "";
        return Result;
      }]),pas.JS.New(["key","state","title",window.t("State"),"value",State,"cell",function (Item) {
        var Result = undefined;
        if (Boolean(Item["hidden"])) {
          Result = window.Site.chip(State(Item),"bad")}
         else Result = window.Site.chip(window.t("Visible"),undefined);
        return Result;
      }])),"filters",new Array(pas.JS.New(["key","show","title",window.t("Show"),"all",window.t("All entries"),"options",Shows]),pas.JS.New(["key","kind","title",window.t("Kind"),"all",window.t("Every kind"),"options",Kinds])),"rowClass",function (Item) {
        var Result = undefined;
        if (Number(Item["reports"]) > 0) {
          Result = "unread"}
         else Result = "";
        return Result;
      },"noun",function (N) {
        var Result = "";
        Result = window.tn(N,"%d entry","%d entries");
        return Result;
      },"detail",Detail]));
      for (var $l1 = 0, $end1 = More.length - 1; $l1 <= $end1; $l1++) {
        I = $l1;
        Extra = More[I];
        Extra["build"].call(Extra,Subs.holder("" + Extra["key"]));
      };
    };
    $impl.Shown = function (R) {
      var Result = undefined;
      Result = $impl.Plus($impl.Plus($impl.Plus($impl.OrValue(R,"start",0),$impl.OrValue(R,"skip",0)),$impl.OrValue(R,"yes",0)),$impl.OrValue(R,"narrow",0));
      return Result;
    };
    $impl.Rate = function (Yes, Skip) {
      var Result = "";
      if (Boolean($impl.Plus(Yes,Skip))) {
        Result = "" + Math.round((100 * Number(Yes)) / Number($impl.Plus(Yes,Skip))) + "%"}
       else Result = "";
      return Result;
    };
    $impl.Reader = function (R) {
      var Result = undefined;
      if (Boolean(R["name"])) {
        Result = R["name"]}
       else Result = window.t("Guest %s",R["who"].slice(1,7));
      return Result;
    };
    $impl.Narrowing = function (V) {
      var Result = undefined;
      var Words = null;
      var Parts = [];
      var Names = null;
      var I = 0;
      var Part = "";
      Words = window.Site.extras["catalogCaptions"];
      Names = new Array();
      if (!Boolean(V)) V = "";
      Parts = ("" + V).split("/");
      for (var $l = 0, $end = rtl.length(Parts) - 1; $l <= $end; $l++) {
        I = $l;
        Part = Parts[I];
        if (Part === "") continue;
        if (Boolean(Words) && Boolean(Words["only-" + Part])) {
          Names.push(Words["only-" + Part])}
         else Names.push(window.t("%s only",Part));
      };
      if (Names.length > 0) {
        Result = Names.join(" · ")}
       else Result = window.t("Anything");
      return Result;
    };
    $impl.Activity = function (Holder) {
      var Bar = null;
      var HideLabel = null;
      var PeriodLabel = null;
      var Note = null;
      var Tiles = null;
      var Period = null;
      var Hide = null;
      var Subs = null;
      var Steps = null;
      var Days = null;
      var People = null;
      var Projects = null;
      var Narrow = null;
      var Crawlers = null;
      var Asked = 0;
      var Choices = rtl.arraySetLength(null,"",5);
      var Captions = rtl.arraySetLength(null,"",5);
      var I = 0;
      var Option = null;
      function ReaderDetail(R, Box) {
        var Result = undefined;
        var Narrowings = [];
        var Names = null;
        var N = 0;
        Box.appendChild($impl.El("div","lv-detail-head",$impl.Reader(R)));
        Narrowings = ("" + $impl.OrValue(R,"narrowings","")).split(", ");
        Names = new Array();
        for (var $l = 0, $end = rtl.length(Narrowings) - 1; $l <= $end; $l++) {
          N = $l;
          if (Narrowings[N] !== "") Names.push($impl.Narrowing(Narrowings[N]));
        };
        window.Site.facts(Box,new Array(new Array(window.t("First"),window.dateTimeText(R["first"])),new Array(window.t("Last"),window.dateTimeText(R["last"])),new Array(window.t("Days"),R["days"]),new Array(window.t("Projects shown"),$impl.Shown(R)),new Array(window.t("Interesting, show me another"),R["yes"]),new Array(window.t("Not for me, show me another"),R["skip"]),new Array(window.t("Interesting rate"),$impl.Rate(R["yes"],R["skip"])),new Array(window.t("Interesting pressed elsewhere"),R["press"]),new Array(window.t("Taken back"),R["unpress"]),new Array(window.t("Narrowed to"),Names.join("; "))));
        if (!Boolean(R["name"])) Box.appendChild($impl.El("p","hint",window.t("Someone not signed in; only a scrambled form of the address is kept.")));
        return Result;
      };
      async function Load() {
        var Mine = 0;
        var D = null;
        var N = null;
        var K = null;
        var Url = "";
        var Caption = "";
        var Extra = "";
        Asked += 1;
        Mine = Asked;
        Days.loading();
        People.loading();
        Projects.loading();
        Narrow.loading();
        Crawlers.loading();
        window.Site.waiting(Tiles);
        Url = "/api/admin/catalog/activity?days=" + Period.value + "&hide=";
        if (Hide.checked) {
          Url = Url + "1"}
         else Url = Url + "0";
        try {
          D = await window.Site.get(Url);
          if (Mine !== Asked) return;
          N = $impl.First(D["totals"]);
          K = $impl.First(D["kept"]);
          if (Boolean(D["since"])) {
            Note.textContent = window.t("Counting since %s.",window.dateTimeText(D["since"]))}
           else Note.textContent = window.t("Nothing counted yet: the counting began with this version.");
          Tiles.replaceChildren();
          Extra = "";
          if (Boolean(N["members"])) Extra = window.tn(N["members"],"%d member","%d members");
          window.Site.stat(Tiles,$impl.OrValue(N,"discoverers",0),window.t("Readers discovering"),Extra,undefined);
          Extra = "";
          if (Boolean(N["start"])) Extra = window.tn(N["start"],"%d start","%d starts");
          window.Site.stat(Tiles,$impl.Shown(N),window.t("Projects shown"),Extra,undefined);
          window.Site.stat(Tiles,$impl.OrValue(N,"yes",0),window.t("Interesting, show me another"),undefined,undefined);
          window.Site.stat(Tiles,$impl.OrValue(N,"skip",0),window.t("Not for me, show me another"),undefined,undefined);
          Caption = $impl.Rate($impl.OrValue(N,"yes",0),$impl.OrValue(N,"skip",0));
          if (Caption === "") Caption = "–";
          window.Site.stat(Tiles,Caption,window.t("Interesting rate"),undefined,undefined);
          Extra = "";
          if (Boolean(N["unpress"])) Extra = window.tn(N["unpress"],"%d taken back","%d taken back");
          window.Site.stat(Tiles,$impl.OrValue(N,"press",0),window.t("Interesting pressed elsewhere"),Extra,undefined);
          window.Site.stat(Tiles,$impl.OrValue(K,"interest",0),window.t("Interesting kept"),window.tn($impl.OrValue(K,"interest_people",0),"from %d reader","from %d readers") + " · " + window.tn($impl.OrValue(K,"interest_all",0),"%d in all","%d in all"),undefined);
          Extra = "";
          if (Boolean(K["reports"])) Extra = window.tn(K["reports"],"%d report","%d reports");
          window.Site.stat(Tiles,$impl.OrValue(K,"ratings",0),window.t("Ratings"),Extra,undefined);
          window.Site.stat(Tiles,$impl.OrValue(N,"crawler_steps",0),window.t("Crawler steps"),undefined,undefined);
          Subs.count("crawlers",$impl.ArrayOrEmpty(D["crawlers"]).length);
          Days.set($impl.ArrayOrEmpty(D["by_day"]));
          People.set($impl.ArrayOrEmpty(D["people"]));
          Projects.set($impl.ArrayOrEmpty(D["projects"]));
          Narrow.set($impl.ArrayOrEmpty(D["narrowings"]));
          Crawlers.set($impl.ArrayOrEmpty(D["crawlers"]));
        } catch ($e) {
          if (Mine !== Asked) return;
          Tiles.replaceChildren();
          Caption = "" + $e["message"];
          Days.failed(Caption);
          People.failed(Caption);
          Projects.failed(Caption);
          Narrow.failed(Caption);
          Crawlers.failed(Caption);
        };
      };
      Bar = $impl.El("div","visit-controls",undefined);
      Period = $impl.El("select","",undefined);
      Hide = $impl.El("input","",undefined);
      HideLabel = $impl.El("label","visit-tick",undefined);
      PeriodLabel = $impl.El("label","",window.t("Period") + " ");
      PeriodLabel.appendChild(Period);
      Choices[0] = "1";
      Choices[1] = "7";
      Choices[2] = "30";
      Choices[3] = "90";
      Choices[4] = "0";
      Captions[0] = window.t("Today");
      Captions[1] = window.t("Last 7 days");
      Captions[2] = window.t("Last 30 days");
      Captions[3] = window.t("Last 90 days");
      Captions[4] = window.t("Everything kept");
      for (I = 0; I <= 4; I++) {
        Option = $impl.El("option","",Captions[I]);
        Option.value = Choices[I];
        Period.appendChild(Option);
      };
      Period.value = "7";
      Hide.type = "checkbox";
      Hide.checked = true;
      HideLabel.append(Hide,document.createTextNode(" " + window.t("Hide my own")));
      Bar.append(PeriodLabel,HideLabel);
      Holder.appendChild(Bar);
      Note = $impl.El("p","hint",undefined);
      Tiles = $impl.El("div","tiles-admin",undefined);
      Holder.append(Note,Tiles);
      Subs = window.Site.subTabs(Holder,"catalog-activity",new Array(pas.JS.New(["key","days","title",window.t("By day")]),pas.JS.New(["key","people","title",window.t("Readers")]),pas.JS.New(["key","projects","title",window.t("Projects")]),pas.JS.New(["key","narrowing","title",window.t("Narrowing")]),pas.JS.New(["key","crawlers","title",window.t("Crawlers")])));
      Steps = new Array(pas.JS.New(["key","start","title",window.t("Started"),"num",true]),pas.JS.New(["key","yes","title",window.t("Interesting"),"num",true]),pas.JS.New(["key","skip","title",window.t("Not for me"),"num",true]),pas.JS.New(["key","narrow","title",window.t("Narrowed"),"num",true,"wide",true]),pas.JS.New(["key","press","title",window.t("Pressed"),"num",true,"wide",true]),pas.JS.New(["key","unpress","title",window.t("Taken back"),"num",true,"wide",true]));
      Days = window.Site.listView(Subs.holder("days"),pas.JS.New(["id","catalog-days","key",function (R) {
        var Result = undefined;
        Result = R["day"];
        return Result;
      },"sort","-day","csv","catalog-activity-days","search",false,"columns",(new Array(pas.JS.New(["key","day","title",window.t("Day"),"down",true]),pas.JS.New(["key","people","title",window.t("Readers"),"num",true]))).concat(Steps,new Array(pas.JS.New(["key","crawler_steps","title",window.t("Crawler steps"),"num",true,"wide",true]))),"noun",function (N) {
        var Result = "";
        Result = window.tn(N,"%d day","%d days");
        return Result;
      },"empty",window.t("No one used Random project or Interesting in this period.")]));
      People = window.Site.listView(Subs.holder("people"),pas.JS.New(["id","catalog-readers","key",function (R) {
        var Result = undefined;
        Result = R["who"];
        return Result;
      },"sort","-last","csv","catalog-activity-readers","search",window.t("Filter by member"),"columns",(new Array(pas.JS.New(["key","name","title",window.t("Reader"),"value",$impl.Reader]),pas.JS.New(["key","last","title",window.t("Last"),"down",true,"cell",function (R) {
        var Result = undefined;
        Result = window.dateTimeText(R["last"]);
        return Result;
      }]),pas.JS.New(["key","days","title",window.t("Days"),"num",true,"wide",true]),pas.JS.New(["key","shown","title",window.t("Projects shown"),"num",true,"value",$impl.Shown]),pas.JS.New(["key","rate","title",window.t("Interesting rate"),"num",true,"value",function (R) {
        var Result = undefined;
        if (Boolean($impl.Plus(R["yes"],R["skip"]))) {
          Result = Math.round((100 * Number(R["yes"])) / Number($impl.Plus(R["yes"],R["skip"])))}
         else Result = -1;
        return Result;
      },"cell",function (R) {
        var Result = undefined;
        Result = $impl.Rate(R["yes"],R["skip"]);
        return Result;
      }]))).concat(Steps),"filters",new Array(pas.JS.New(["key","kind","title",window.t("Readers"),"all",window.t("Everyone"),"options",new Array(new Array("member",window.t("Members")),new Array("guest",window.t("Guests"))),"test",function (R, V) {
        var Result = undefined;
        if (V === "member") {
          Result = Boolean(R["name"])}
         else Result = !Boolean(R["name"]);
        return Result;
      }])),"noun",function (N) {
        var Result = "";
        Result = window.tn(N,"%d reader","%d readers");
        return Result;
      },"empty",window.t("No one used Random project or Interesting in this period."),"detail",ReaderDetail]));
      Projects = window.Site.listView(Subs.holder("projects"),pas.JS.New(["id","catalog-projects","key",function (R) {
        var Result = undefined;
        Result = "" + R["id"];
        return Result;
      },"sort","-yes","csv","catalog-activity-projects","search",window.t("Filter by project"),"columns",new Array(pas.JS.New(["key","title","title",window.t("Project"),"cell",function (R) {
        var Result = undefined;
        var A = null;
        A = window.Site.link("/catalog/" + ("" + R["id"]),"",R["title"]);
        A.target = "_blank";
        Result = A;
        return Result;
      }]),pas.JS.New(["key","yes","title",window.t("Interesting"),"num",true,"down",true]),pas.JS.New(["key","skip","title",window.t("Not for me"),"num",true]),pas.JS.New(["key","press","title",window.t("Pressed"),"num",true,"wide",true]),pas.JS.New(["key","unpress","title",window.t("Taken back"),"num",true,"wide",true]),pas.JS.New(["key","people","title",window.t("Readers"),"num",true,"wide",true]),pas.JS.New(["key","interest","title",window.t("Interesting now"),"num",true])),"noun",function (N) {
        var Result = "";
        Result = window.tn(N,"%d project","%d projects");
        return Result;
      },"empty",window.t("No project got an answer in this period.")]));
      Narrow = window.Site.listView(Subs.holder("narrowing"),pas.JS.New(["id","catalog-narrowing","key",function (R) {
        var Result = undefined;
        Result = R["narrowing"];
        return Result;
      },"sort","-steps","search",false,"columns",new Array(pas.JS.New(["key","narrowing","title",window.t("Showing"),"value",function (R) {
        var Result = undefined;
        Result = $impl.Narrowing(R["narrowing"]);
        return Result;
      }]),pas.JS.New(["key","steps","title",window.t("Projects shown"),"num",true,"down",true]),pas.JS.New(["key","people","title",window.t("Readers"),"num",true])),"noun",function (N) {
        var Result = "";
        Result = window.tn(N,"%d choice","%d choices");
        return Result;
      },"empty",window.t("No one used Random project in this period.")]));
      Crawlers = window.Site.listView(Subs.holder("crawlers"),pas.JS.New(["id","catalog-crawlers","key",function (R) {
        var Result = undefined;
        Result = R["name"];
        return Result;
      },"sort","-steps","csv","catalog-activity-crawlers","search",false,"columns",new Array(pas.JS.New(["key","name","title",window.t("Crawler"),"value",function (R) {
        var Result = undefined;
        Result = $impl.OrValue(R,"name",window.t("No crawler name, no script"));
        return Result;
      }]),pas.JS.New(["key","steps","title",window.t("Steps"),"num",true,"down",true]),pas.JS.New(["key","addresses","title",window.t("Addresses"),"num",true]),pas.JS.New(["key","start","title",window.t("Started"),"num",true,"wide",true]),pas.JS.New(["key","skip","title",window.t("Not for me"),"num",true,"wide",true]),pas.JS.New(["key","last","title",window.t("Last"),"wide",true,"cell",function (R) {
        var Result = undefined;
        Result = window.dateTimeText(R["last"]);
        return Result;
      }])),"noun",function (N) {
        var Result = "";
        Result = window.tn(N,"%d crawler","%d crawlers");
        return Result;
      },"empty",window.t("No crawler followed the random links in this period.")]));
      Holder.appendChild($impl.El("p","hint",window.t("A reader is counted when the page's script sends the click, or for a press; crawlers follow the links without either. The steps without a crawler name are mostly crawlers posing as browsers, or someone with scripts turned off.")));
      Asked = 0;
      Period.addEventListener("change",function (E) {
        Load();
      });
      Hide.addEventListener("change",function (E) {
        Load();
      });
      Load();
    };
    $impl.Badge = async function () {
      var Result = undefined;
      var D = null;
      D = await window.Site.get("/api/admin/catalog?show=reported&counts=0");
      Result = D["matches"];
      return Result;
    };
  };
  $mod.$init = function () {
    if (Boolean(window.Site)) {
      window.Site.extras["settingGroups"]["Catalog"] = "Catalog";
      window.Site.extras["adminTabs"].push(pas.JS.New(["title","Catalog","permission","view-catalog","build",$impl.Catalog,"group","Catalog","part","catalog","badge",$impl.Badge]));
    };
  };
},["JS","Web","PageKit","PageGlobals"]);

rtl.run('CatalogAdminPage');
}
