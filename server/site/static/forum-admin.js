if (pas.ForumAdminPage && pas.ForumAdminPage.$state === rtl.m_initialized) pas.ForumAdminPage.Start();
if (!pas.ForumAdminPage)
rtl.module("ForumAdminPage",["System"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  this.Start = function () {
    var Tabs = null;
    var I = 0;
    var Style = null;
    Tabs = window.Site.extras["adminTabs"];
    for (var $l = 0, $end = Tabs.length - 1; $l <= $end; $l++) {
      I = $l;
      if ($impl.Same(Tabs[I]["permission"],"forum-boards")) return;
    };
    Style = pas.PageKit.MakeElement("link","");
    Style.rel = "stylesheet";
    Style.href = "/static/forum.css" + (new URL(document.currentScript.src)).search;
    document.head.appendChild(Style);
    Tabs.push(pas.JS.New(["title",window.t("Forum boards"),"permission","forum-boards","build",$impl.Build,"group","Forum"]));
  };
  $mod.$implcode = function () {
    $impl.Same = function (A, B) {
      var Result = false;
      Result = (typeof(A) === typeof(B)) && (A == B);
      return Result;
    };
    $impl.El = function (Tag, Text) {
      var Result = null;
      Result = pas.PageKit.MakeElement(Tag,"");
      if (typeof(Text) !== "undefined") Result["textContent"] = Text;
      return Result;
    };
    $impl.Button = function (Text, Action) {
      var Result = null;
      Result = $impl.El("button",Text);
      Result.type = "button";
      Result.addEventListener("click",function (E) {
        Action();
      });
      return Result;
    };
    $impl.Value = function (Item, Key, Fallback) {
      var Result = undefined;
      Result = Item[Key];
      if (!Boolean(Result)) Result = Fallback;
      return Result;
    };
    var Captions = ["Name","Category","Parent board","Read permission","Position","Actions"];
    $impl.Build = async function (Box) {
      var Boards = null;
      var Categories = null;
      var Permissions = null;
      var error = null;
      var Content = null;
      var Busy = false;
      var Data = null;
      async function Change(Path, Fields) {
        var Buttons = null;
        var Disabled = [];
        var I = 0;
        if (Busy) return;
        Busy = true;
        error.textContent = "";
        Buttons = Box.querySelectorAll("button");
        Disabled = rtl.arraySetLength(Disabled,false,Buttons.length);
        for (var $l = 0, $end = Buttons.length - 1; $l <= $end; $l++) {
          I = $l;
          Disabled[I] = Buttons.item(I).disabled;
          Buttons.item(I).disabled = true;
        };
        try {
          try {
            await window.Site.post("/api/forum/admin/" + Path,Fields);
            await Load();
          } catch ($e) {
            error.textContent = "" + $e["message"];
          };
        } finally {
          Busy = false;
          for (var $l1 = 0, $end1 = Buttons.length - 1; $l1 <= $end1; $l1++) {
            I = $l1;
            Buttons.item(I).disabled = Disabled[I];
          };
        };
      };
      function Field(Form, Name, Caption, Initial, Kind) {
        var Result = null;
        var Label_ = null;
        var Input = null;
        Label_ = $impl.El("label",Caption + " ");
        if (Kind === "textarea") {
          Input = $impl.El("textarea",undefined)}
         else Input = $impl.El("input",undefined);
        Input["name"] = Name;
        if (typeof(Initial) === "undefined") {
          Input["value"] = ""}
         else Input["value"] = "" + Initial;
        if ((Kind !== "") && (Kind !== "textarea")) Input["type"] = Kind;
        Label_.appendChild(Input);
        Form.appendChild(Label_);
        Result = Input;
        return Result;
      };
      function Edit(Board) {
        var Form = null;
        var Values = null;
        var BoardId = undefined;
        var HasChildren = false;
        var ParentLabel = null;
        var CategoryLabel = null;
        var Parent = null;
        var Category = null;
        var Option = null;
        var Save = null;
        var Item = null;
        var I = 0;
        Form = $impl.El("form",undefined);
        Values = new Object();
        BoardId = $impl.Value(Board,"id",0);
        HasChildren = false;
        for (var $l = 0, $end = Boards.length - 1; $l <= $end; $l++) {
          I = $l;
          if ($impl.Same(Boards[I]["parent_id"],BoardId)) HasChildren = true;
        };
        Values["name"] = Field(Form,"name",window.t("Name"),$impl.Value(Board,"name",""),"");
        Values["name"].required = true;
        Values["name"].maxLength = 100;
        Values["slug"] = Field(Form,"slug",window.t("Slug"),$impl.Value(Board,"slug",""),"");
        Values["slug"].required = true;
        Values["slug"].maxLength = 80;
        Values["description"] = Field(Form,"description",window.t("Description"),$impl.Value(Board,"description",""),"textarea");
        Values["description"].maxLength = 2000;
        Values["position"] = Field(Form,"position",window.t("Position"),$impl.Value(Board,"position",0),"number");
        Values["position"].required = true;
        ParentLabel = $impl.El("label",window.t("Parent board") + " ");
        Parent = $impl.El("select",undefined);
        Option = $impl.El("option",window.t("None"));
        Option.value = "0";
        Parent.appendChild(Option);
        for (var $l1 = 0, $end1 = Boards.length - 1; $l1 <= $end1; $l1++) {
          I = $l1;
          Item = Boards[I];
          if (!HasChildren && !Boolean(Item["parent_id"]) && !$impl.Same(Item["id"],BoardId)) {
            Option = $impl.El("option",Item["name"]);
            Option.value = "" + Item["id"];
            Parent.appendChild(Option);
          };
        };
        Parent.value = "" + $impl.Value(Board,"parent_id",0);
        ParentLabel.appendChild(Parent);
        Form.appendChild(ParentLabel);
        CategoryLabel = $impl.El("label",window.t("Category") + " ");
        Category = $impl.El("select",undefined);
        Category.name = "category_id";
        Option = $impl.El("option",window.t("General"));
        Option.value = "0";
        Category.appendChild(Option);
        for (var $l2 = 0, $end2 = Categories.length - 1; $l2 <= $end2; $l2++) {
          I = $l2;
          Item = Categories[I];
          Option = $impl.El("option",Item["name"]);
          Option.value = "" + Item["id"];
          Category.appendChild(Option);
        };
        Category.value = "" + $impl.Value(Board,"category_id",0);
        CategoryLabel.appendChild(Category);
        Form.appendChild(CategoryLabel);
        Values["read_permission"] = Field(Form,"read_permission",window.t("Read permission"),$impl.Value(Board,"read_permission","forum-read"),"");
        Values["read_permission"].required = true;
        Values["read_permission"].maxLength = 40;
        Values["read_permission"].setAttribute("list","forum-permissions");
        Save = $impl.El("button",window.t("Save"));
        Save.type = "submit";
        Form.append(Save,$impl.Button(window.t("Cancel"),Draw));
        Form.addEventListener("submit",function (E) {
          var Fields = null;
          var Keys = [];
          var N = 0;
          E.preventDefault();
          Fields = pas.JS.New(["id",BoardId,"parent_id",Parent.value,"category_id",Category.value]);
          Keys = Object.keys(Values);
          for (var $l3 = 0, $end3 = rtl.length(Keys) - 1; $l3 <= $end3; $l3++) {
            N = $l3;
            Fields[Keys[N]] = Values[Keys[N]]["value"];
          };
          Change("board",Fields);
        });
        Content.replaceChildren(Form);
      };
      function Order(Index, Offset) {
        var Ordered = null;
        var Ids = null;
        var Other = 0;
        var I = 0;
        var Kept = undefined;
        Ordered = Boards.slice();
        Other = Index + Offset;
        if ((Other < 0) || (Other >= Ordered.length)) return;
        Kept = Ordered[Index];
        Ordered[Index] = Ordered[Other];
        Ordered[Other] = Kept;
        Ids = new Array();
        for (var $l = 0, $end = Ordered.length - 1; $l <= $end; $l++) {
          I = $l;
          Ids.push(Ordered[I]["id"]);
        };
        Change("order",pas.JS.New(["ids",Ids.join(",")]));
      };
      function EditCategory(Category) {
        var Form = null;
        var Name = null;
        var Position = null;
        var Save = null;
        Form = $impl.El("form",undefined);
        Name = Field(Form,"name",window.t("Category name"),$impl.Value(Category,"name",""),"");
        Name.required = true;
        Name.maxLength = 100;
        Position = Field(Form,"position",window.t("Position"),$impl.Value(Category,"position",0),"number");
        Save = $impl.El("button",window.t("Save"));
        Save.type = "submit";
        Form.append(Save,$impl.Button(window.t("Cancel"),Draw));
        Form.addEventListener("submit",function (E) {
          E.preventDefault();
          Change("category",pas.JS.New(["id",$impl.Value(Category,"id",0),"name",Name.value,"position",Position.value]));
        });
        Content.replaceChildren(Form);
      };
      function CategoryRow(Category, Index) {
        var Result = null;
        var Row = null;
        var Up = null;
        var Down = null;
        Row = $impl.El("li","" + Category["name"] + " (" + ("" + Category["position"]) + ") ");
        Up = $impl.Button(window.t("Move category up"),function () {
          Change("category",pas.JS.New(["id",Category["id"],"name",Category["name"],"position",Number(Categories[Index - 1]["position"]) - 1]));
        });
        Down = $impl.Button(window.t("Move category down"),function () {
          Change("category",pas.JS.New(["id",Category["id"],"name",Category["name"],"position",Number(Categories[Index + 1]["position"]) + 1]));
        });
        Up.disabled = Index === 0;
        Down.disabled = Index === (Categories.length - 1);
        Row.append($impl.Button(window.t("Rename category"),function () {
          EditCategory(Category);
        }),Up,Down,$impl.Button(window.t("Remove category"),function () {
          if (window.confirm(window.t("Remove category %s?",Category["name"]))) Change("category/remove",pas.JS.New(["id",Category["id"]]));
        }));
        Result = Row;
        return Result;
      };
      function BoardRow(Board, Index) {
        var Result = null;
        var Row = null;
        var Actions = null;
        var Parent = null;
        var Category = null;
        var Item = null;
        var Up = null;
        var Down = null;
        var I = 0;
        var CategoryId = undefined;
        var ParentName = undefined;
        var CategoryName = undefined;
        Row = $impl.El("tr",undefined);
        Parent = null;
        Category = null;
        for (var $l = 0, $end = Boards.length - 1; $l <= $end; $l++) {
          I = $l;
          Item = Boards[I];
          if ($impl.Same(Item["id"],Board["parent_id"])) {
            Parent = Item;
            break;
          };
        };
        if (Parent !== null) {
          CategoryId = Parent["category_id"]}
         else CategoryId = Board["category_id"];
        for (var $l1 = 0, $end1 = Categories.length - 1; $l1 <= $end1; $l1++) {
          I = $l1;
          Item = Categories[I];
          if ($impl.Same(Item["id"],CategoryId)) {
            Category = Item;
            break;
          };
        };
        ParentName = "";
        if (Parent !== null) ParentName = Parent["name"];
        CategoryName = window.t("General");
        if (Category !== null) CategoryName = Category["name"];
        Row.append($impl.El("td",Board["name"]),$impl.El("td",CategoryName),$impl.El("td",ParentName),$impl.El("td",Board["read_permission"]),$impl.El("td","" + Board["position"]));
        Actions = $impl.El("td",undefined);
        Up = $impl.Button(window.t("Move up"),function () {
          Order(Index,-1);
        });
        Down = $impl.Button(window.t("Move down"),function () {
          Order(Index,1);
        });
        Up.disabled = Index === 0;
        Down.disabled = Index === (Boards.length - 1);
        Actions.append($impl.Button(window.t("Edit"),function () {
          Edit(Board);
        }),Up,Down,$impl.Button(window.t("Remove"),function () {
          if (window.confirm(window.t("Remove board %s?",Board["name"]))) Change("remove",pas.JS.New(["id",Board["id"]]));
        }));
        Row.appendChild(Actions);
        Result = Row;
        return Result;
      };
      function Draw() {
        var Choices = null;
        var Table = null;
        var Head = null;
        var Wrap = null;
        var List = null;
        var Old = null;
        var Names = null;
        var Values = null;
        var Option = null;
        var I = 0;
        Content.replaceChildren();
        Choices = $impl.El("datalist",undefined);
        Choices.id = "forum-permissions";
        Names = new Set(new Array("forum-read","forum-members","forum-staff"));
        for (var $l = 0, $end = Permissions.length - 1; $l <= $end; $l++) {
          I = $l;
          Names.add(Permissions[I]["name"]);
        };
        for (var $l1 = 0, $end1 = Boards.length - 1; $l1 <= $end1; $l1++) {
          I = $l1;
          Names.add(Boards[I]["read_permission"]);
        };
        Values = Array.from(Names);
        for (var $l2 = 0, $end2 = Values.length - 1; $l2 <= $end2; $l2++) {
          I = $l2;
          Option = $impl.El("option",undefined);
          Option.value = "" + Values[I];
          Choices.appendChild(Option);
        };
        Old = Box.querySelector("datalist");
        if (Old !== null) Old.remove();
        Box.appendChild(Choices);
        Content.append($impl.El("p",window.tn(Boards.length,"%d board","%d boards")),$impl.Button(window.t("Add board"),function () {
          Edit(new Object());
        }));
        Table = $impl.El("table",undefined);
        Table.className = "grid";
        Head = $impl.El("tr",undefined);
        for (I = 0; I <= 5; I++) Head.appendChild($impl.El("th",window.t(Captions[I])));
        Table.appendChild(Head);
        for (var $l3 = 0, $end3 = Boards.length - 1; $l3 <= $end3; $l3++) {
          I = $l3;
          Table.appendChild(BoardRow(Boards[I],I));
        };
        Wrap = $impl.El("div",undefined);
        Wrap.className = "gridwrap";
        Wrap.appendChild(Table);
        Content.appendChild(Wrap);
        Content.append($impl.El("h3",window.t("Categories")),$impl.Button(window.t("Add category"),function () {
          EditCategory(new Object());
        }));
        List = $impl.El("ul",undefined);
        for (var $l4 = 0, $end4 = Categories.length - 1; $l4 <= $end4; $l4++) {
          I = $l4;
          List.appendChild(CategoryRow(Categories[I],I));
        };
        Content.appendChild(List);
      };
      async function Load() {
        var Results = null;
        Results = await Promise.all(new Array(window.Site.get("/api/forum/admin/boards"),window.Site.get("/api/forum/admin/categories")));
        Boards = Results[0];
        Categories = Results[1];
        Draw();
      };
      Box.className = Box.className + " forum-admin";
      Boards = new Array();
      Categories = new Array();
      Permissions = new Array();
      error = $impl.El("p",undefined);
      error.className = "forum-error";
      error.setAttribute("role","alert");
      Content = $impl.El("div",undefined);
      Box.replaceChildren(error,Content);
      Busy = false;
      try {
        Data = await window.Site.get("/api/admin");
        if (Boolean(Data["permissions"])) Permissions = Data["permissions"];
        await Load();
      } catch ($e) {
        error.textContent = "" + $e["message"];
      };
    };
  };
  $mod.$init = function () {
    $mod.Start();
  };
},["JS","Web","PageKit","PageGlobals"]);

rtl.run('ForumAdminPage');
