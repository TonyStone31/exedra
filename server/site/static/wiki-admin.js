if (!pas.WikiAdminPage) {
rtl.module("WikiAdminPage",["System"],function () {
  "use strict";
  var $mod = this;
  var $impl = $mod.$impl;
  $mod.$implcode = function () {
    $impl.Say = function (Text) {
      var Result = "";
      if (Boolean(window["t"])) {
        Result = window.t(Text)}
       else Result = Text;
      return Result;
    };
    $impl.Send = async function (Data) {
      var R = null;
      R = await pas.PageKit.Post("/api/wiki/emoji/save",new URLSearchParams(Data),null);
      if (!R.ok) throw new Error(await R.text());
    };
    $impl.ReadSvg = function (AFile) {
      var Result = null;
      Result = new Promise(function (Done, Fail) {
        var Reader = null;
        if (pas.JS.isUndefined(AFile) || (AFile === null)) {
          Done("");
          return;
        };
        if (AFile.size > (64 * 1024)) {
          Fail(new Error($impl.Say("The picture is too big: 64 KB at most.")));
          return;
        };
        Reader = new FileReader();
        Reader.addEventListener("load",function (E) {
          if (Boolean(Reader.result)) {
            Done("" + Reader.result)}
           else Done("");
        });
        Reader.addEventListener("error",function (E) {
          Fail(new Error($impl.Say("The file could not be read.")));
        });
        Reader.readAsText(AFile);
      });
      return Result;
    };
    $impl.Picker = function () {
      var Result = null;
      Result = window.Site.el("input");
      Result.type = "file";
      Result.accept = "image/svg+xml,.svg";
      return Result;
    };
    $impl.Build = function (Holder) {
      var Root = null;
      var Notice = null;
      var List = null;
      function Row(Emoji) {
        var Result = null;
        var Line = null;
        var Face = null;
        var Plain = null;
        var Drawn = null;
        var Name = null;
        var Keywords = null;
        var DrawnBox = null;
        var AFile = null;
        var Save = null;
        var Back = null;
        var Img = null;
        async function Store(Extra) {
          var Data = null;
          var Svg = "";
          var DrawnValue = "";
          Save.disabled = true;
          Back.disabled = true;
          try {
            if (DrawnBox.checked) {
              DrawnValue = "1"}
             else DrawnValue = "0";
            Data = pas.JS.New(["chars",Emoji["emoji"],"name",Name.value,"keywords",Keywords.value,"drawn",DrawnValue]);
            if (Extra !== null) Object.assign(Data,Extra);
            Svg = await $impl.ReadSvg(AFile.files.item(0));
            if (Svg !== "") Data["svg"] = Svg;
            await $impl.Send(Data);
            Notice.textContent = $impl.Say("Saved.") + " " + ("" + Emoji["emoji"]);
            await Load();
          } catch ($e) {
            Notice.textContent = "" + $e["message"];
            Save.disabled = false;
            Back.disabled = false;
          };
        };
        Line = window.Site.el("form","emoji-admin-row");
        Face = window.Site.el("span","emoji-admin-face");
        if (Boolean(Emoji["src"])) {
          Img = window.Site.el("img");
          Img.src = "" + Emoji["src"];
          Img.alt = "" + Emoji["emoji"];
          Face.appendChild(Img);
        } else Face["textContent"] = Emoji["emoji"];
        Plain = window.Site.el("span","emoji-admin-plain",Emoji["emoji"]);
        Plain.title = $impl.Say("As the reader's font draws it");
        Name = window.Site.el("input");
        Name["value"] = Emoji["name"];
        Name.setAttribute("aria-label",$impl.Say("Name"));
        Keywords = window.Site.el("input");
        Keywords.value = Emoji["keywords"].join(" ");
        Keywords.setAttribute("aria-label",$impl.Say("Keywords"));
        Keywords.placeholder = $impl.Say("keywords, with spaces between");
        DrawnBox = window.Site.el("input");
        DrawnBox.type = "checkbox";
        DrawnBox.checked = Boolean(Emoji["src"]);
        Drawn = window.Site.el("label","emoji-admin-drawn");
        Drawn.append(DrawnBox,document.createTextNode(" " + $impl.Say("Own picture")));
        AFile = $impl.Picker();
        AFile.setAttribute("aria-label",$impl.Say("A picture of your own (SVG)"));
        Save = window.Site.el("button","",$impl.Say("Save"));
        Save.type = "submit";
        Back = window.Site.el("button","",$impl.Say("Default picture"));
        Back.type = "button";
        Line.append(Face,Plain,Name,Keywords,Drawn,AFile,Save,Back);
        Line.addEventListener("submit",function (E) {
          E.preventDefault();
          Store(null);
        });
        Back.addEventListener("click",function (E) {
          Store(pas.JS.New(["plain","1"]));
        });
        Result = Line;
        return Result;
      };
      async function Load() {
        var R = null;
        var Set_ = null;
        var I = 0;
        Notice.textContent = $impl.Say("Loading…");
        try {
          R = await pas.PageKit.Get("/api/wiki/emoji?fresh=" + ("" + Date.now()),null);
          if (!R.ok) throw new Error(await R.text());
          Set_ = await R.json();
          Notice.textContent = "";
          List.replaceChildren();
          for (var $l = 0, $end = Set_.length - 1; $l <= $end; $l++) {
            I = $l;
            List.appendChild(Row(Set_[I]));
          };
        } catch ($e) {
          Notice.textContent = "" + $e["message"];
        };
      };
      function AddForm() {
        var Result = null;
        var Form = null;
        var Chars = null;
        var Name = null;
        var Keywords = null;
        var AFile = null;
        var Add = null;
        async function Submit(E) {
          var Svg = "";
          var Drawn = "";
          var Data = null;
          E.preventDefault();
          Add.disabled = true;
          try {
            try {
              Svg = await $impl.ReadSvg(AFile.files.item(0));
              if (Svg !== "") {
                Drawn = "1"}
               else Drawn = "0";
              Data = pas.JS.New(["add","1","chars",Chars.value.trim(),"name",Name.value,"keywords",Keywords.value,"drawn",Drawn]);
              if (Svg !== "") Data["svg"] = Svg;
              await $impl.Send(Data);
              Form.reset();
              Notice.textContent = $impl.Say("Saved.");
              await Load();
            } catch ($e) {
              Notice.textContent = "" + $e["message"];
            };
          } finally {
            Add.disabled = false;
          };
        };
        Form = window.Site.el("form","emoji-admin-add");
        Chars = window.Site.el("input");
        Chars.placeholder = $impl.Say("Emoji");
        Chars.setAttribute("aria-label",$impl.Say("Emoji"));
        Chars.size = 4;
        Name = window.Site.el("input");
        Name.placeholder = $impl.Say("Name");
        Name.setAttribute("aria-label",$impl.Say("Name"));
        Keywords = window.Site.el("input");
        Keywords.placeholder = $impl.Say("keywords, with spaces between");
        Keywords.setAttribute("aria-label",$impl.Say("Keywords"));
        AFile = $impl.Picker();
        AFile.setAttribute("aria-label",$impl.Say("A picture of your own (SVG)"));
        Add = window.Site.el("button","",$impl.Say("Add"));
        Add.type = "submit";
        Form.append(window.Site.el("h3","",$impl.Say("Add an emoji")),Chars,Name,Keywords,AFile,Add);
        Form.addEventListener("submit",Submit);
        Result = Form;
        return Result;
      };
      Root = window.Site.el("section","emoji-admin");
      Root.append(window.Site.el("h2","",$impl.Say("Wiki emoji")),window.Site.el("p","",$impl.Say("Pages keep the emoji themselves. Here you choose how the wiki draws them: with its own picture, or as the reader's computer does. A keyword typed between colons, like :yes:, becomes its emoji when a page is saved.")));
      Notice = window.Site.el("p","emoji-admin-notice");
      Notice.setAttribute("role","status");
      List = window.Site.el("div","emoji-admin-list");
      Root.append(Notice,List,AddForm());
      Holder.appendChild(Root);
      Load();
    };
  };
  $mod.$init = function () {
    if (Boolean(window.Site) && Boolean(window.Site.extras)) window.Site.extras["adminTabs"].push(pas.JS.New(["title","Emoji","permission","wiki-emoji","build",$impl.Build,"group","Wiki"]));
  };
},["JS","Web","PageGlobals","PageKit"]);

rtl.run('WikiAdminPage');
}
