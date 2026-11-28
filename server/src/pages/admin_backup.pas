unit Admin_Backup;

{ The admin page's Backup tab. }

{$mode objfpc}
{$modeswitch externalclass}
{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

interface

uses JS, Web, Admin_List;

procedure AdminBackup(Box: TJSHTMLElement);

implementation

type
  // Blob.slice with the place as the server gave it
  TPieces = class external name 'Blob'(TJSBlob)
    function slice(Start, Stop: double): TJSBlob; overload;
  end;

var
  Endless: double; external name 'Infinity';

// a < b as the browser compares: two texts by their letters, anything else as numbers
function Less(A, B: JSValue): boolean;
begin
  if (jsTypeOf(A) = 'string') and (jsTypeOf(B) = 'string') then Result := string(A) < string(B)
  else Result := Num(A) < Num(B);
end;

// Backups of the whole site: made, checked, downloaded, uploaded and
// restored here (src/core/sitebackup.pas).  The page says plainly whether a
// fresh, whole backup exists, here and on the other machine.
procedure AdminBackup(Box: TJSHTMLElement);
var
  Timer: NativeInt;

  function Hours(Iso: JSValue): double;
  begin
    if Truthy(Iso) then Result := (TJSDate.now - Num(TDate.new(Iso))) / 36e5 else Result := Endless;
  end;

  procedure Show; async;
  var
    Data, Newest, Outside, Pictures, Logs: TJSObject;
    List, Worries, Bits, Lines: TJSArray;
    Notice, Line, Far, Make, Go, Up, Pick, Send, Progress, Move, Steps: TJSHTMLElement;
    Word, Done: string;
    I: NativeInt;

    function TickOf(const Name: string; Words: JSValue): TJSObject;
    var
      TheLabel, Tick: TJSHTMLElement;
    begin
      TheLabel := C.el('label');
      Tick := C.el('input');
      TJSObject(Tick)['type'] := 'checkbox';
      TJSObject(Tick)['name'] := Name;
      TJSObject(Tick)['value'] := '1';
      TKit(TheLabel).add(Tick, ' ', Words);
      Result := new(['label', TheLabel, 'tick', Tick]);
    end;

    procedure MakeNow(E: TJSEvent); async;
    var
      WithPictures, WithLogs: string;
    begin
      E.preventDefault;
      try
        if Truthy(TJSObject(Pictures['tick'])['checked']) then WithPictures := '1' else WithPictures := '0';
        if Truthy(TJSObject(Logs['tick'])['checked']) then WithLogs := '1' else WithLogs := '0';
        C.toast(await(JSValue, C.post('/api/admin/backup/make', new(['pictures', WithPictures, 'logs', WithLogs]))));
        Show;
      except
        C.failed(JSExceptValue);
      end;
    end;

    // one backup kept: what it holds, whether it was proven whole, and what can be done with it
    procedure Kept(B: TJSObject);
    var
      Row, Name, Detail, More, TableList, Down, Check, Restore, Del: TJSHTMLElement;
      About, M: TJSObject;
      Holds, Names: TJSArray;
      Words: string;
      N: NativeInt;

      procedure CheckNow(E: TJSEvent); async;
      begin
        try
          C.toast(await(JSValue, C.post('/api/admin/backup/check', new(['name', B['name']]))));
          Show;
        except
          C.failed(JSExceptValue);
        end;
      end;

      procedure RestoreNow(E: TJSEvent); async;
      var
        Typed: JSValue;
      begin
        Typed := window.prompt(T('Restoring %s replaces every table with the backup’s (a table the backup does not have is emptied) and writes its files over the data folder and the pictures; files added since stay. Everyone else sees a "back in a minute" page while it runs, and a restart afterwards is wise. Type RESTORE to go ahead.', B['name']));
        if Same(Typed, nil) then Exit;
        try
          C.toast(await(JSValue, C.post('/api/admin/backup/restore', new(['name', B['name'], 'confirm', TJSString(Typed).trim]))));
          Show;
        except
          C.failed(JSExceptValue);
        end;
      end;

      procedure DeleteNow(E: TJSEvent); async;
      begin
        if not window.confirm(T('Delete %s?', B['name'])) then Exit;
        try
          C.toast(await(JSValue, C.post('/api/admin/backup/delete', new(['name', B['name']]))));
          Show;
        except
          C.failed(JSExceptValue);
        end;
      end;

    begin
      Row := C.el('div', 'person backup-row');
      Name := C.el('a', 'backup-name', B['name']);
      TJSObject(Name)['href'] := '/api/admin/backup/file/' + encodeURIComponent(string(B['name']));
      Name.setAttribute('download', string(B['name']));
      Words := C.sizeText(B['bytes']) + ' · ' + DateTimeText(B['when']);
      if Truthy(B['uploaded']) then Words := Words + ' · ' + T('uploaded');
      TKit(Row).add(Name, C.el('span', 'dim', Words));
      // what it holds, from its manifest; and whether it was proven whole
      About := TJSObject(Either(B['about'], TJSObject.new));
      M := TJSObject(About['manifest']);
      Holds := TJSArray.new;
      if Truthy(M) then
      begin
        if Truthy(M['site']) then Holds.push(M['site']);
        if Truthy(M['tables']) then
          Holds.push(TN(M['tables'], '%d table', '%d tables') + ', ' + TN(Either(M['rows'], 0), '%d row', '%d rows'));
        if Truthy(M['files']) then Holds.push(TN(M['files'], '%d file', '%d files'));
        if Truthy(M['pictures']) then Holds.push(T('with pictures')) else Holds.push(T('no pictures'));
        if Truthy(M['logs']) then Holds.push(T('with access logs')) else Holds.push(T('no access logs'));
      end
      else if Same(About['manifest'], nil) then Holds.push(T('no manifest inside: an early backup or not one made here'));
      Detail := C.el('div', 'backup-holds dim', Holds.join(' · '));
      if Truthy(M) and Truthy(M['counts']) then
      begin
        More := C.el('a', 'small-link', T('Tables'));
        TJSObject(More)['href'] := '#';
        TableList := C.el('div', 'backup-tables dim');
        TableList.hidden := True;
        Names := SortBy(TJSArray(TJSObject.keys(TJSObject(M['counts']))), undefined);
        for N := 0 to Names.length - 1 do
          Names[N] := string(Names[N]) + ' ' + string(TJSObject(M['counts'])[string(Names[N])]);
        TableList.textContent := Names.join(' · ');
        More.addEventListener('click', TJSRawEventHandler(procedure(E: TJSEvent)
          begin
            E.preventDefault;
            TableList.hidden := not TableList.hidden;
          end));
        TKit(Detail).add(' ', More);
        TKit(Row).add(Detail, TableList);
      end
      else Row.appendChild(Detail);
      if Truthy(About['checked']) then
      begin
        if Truthy(About['whole']) then
          Row.appendChild(C.el('div', 'backup-check good', T('Checked %s: whole.', DateTimeText(About['checked'])) + ' ' + string(Either(About['note'], ''))))
        else
          Row.appendChild(C.el('div', 'backup-check bad', T('Checked %s: NOT whole.', DateTimeText(About['checked'])) + ' ' + string(Either(About['note'], ''))));
      end
      else Row.appendChild(C.el('div', 'backup-check warn', T('Not checked yet.')));
      Down := C.el('a', 'small-link', T('Download'));
      TJSObject(Down)['href'] := TJSObject(Name)['href'];
      Down.setAttribute('download', string(B['name']));
      Row.appendChild(Down);
      Check := C.el('button', 'small-link', T('Check'));
      TJSObject(Check)['type'] := 'button';
      TJSObject(Check)['disabled'] := Truthy(Data['busy']);
      Check.addEventListener('click', TJSRawEventHandler(@CheckNow));
      Row.appendChild(Check);
      Restore := C.el('button', 'small-link', T('Restore…'));
      TJSObject(Restore)['type'] := 'button';
      TJSObject(Restore)['disabled'] := Truthy(Data['busy']);
      Restore.addEventListener('click', TJSRawEventHandler(@RestoreNow));
      Row.appendChild(Restore);
      Del := C.el('button', 'small-link', T('Delete'));
      TJSObject(Del)['type'] := 'button';
      Del.addEventListener('click', TJSRawEventHandler(@DeleteNow));
      Row.appendChild(Del);
      Box.appendChild(Row);
    end;

    // in pieces of 8 MB, each sent again when it does not arrive; however
    // large the file, the server never holds more than one piece
    procedure Upload(E: TJSEvent); async;
    const
      Piece = 8 * 1024 * 1024;
    var
      Sent: TJSBlob;
      Where, Url, Body: string;
      Offset: double;
      Tries: NativeInt;
      Last, Lost: boolean;
      Answer: TJSObject;
      R: TJSResponse;
      Trouble: JSValue;
    begin
      E.preventDefault;
      if TJSHTMLInputElement(Pick).files.length = 0 then Exit;
      Sent := TJSHTMLInputElement(Pick).files[0];
      Where := '/api/admin/backup/chunk?name=' + C.enc(TJSObject(Sent)['name']);
      TJSObject(Send)['disabled'] := True;
      Offset := 0;
      Tries := 0;
      try
        try
          Trouble := undefined;
          while True do
          begin
            Last := Offset + Piece >= Sent.size;
            Url := Where + '&offset=' + Str(Offset);
            if Last then Url := Url + '&size=' + Str(Sent.size);
            Lost := False;
            try
              R := await(TJSResponse, window.fetch(Url, new(['method', 'POST', 'body', TPieces(Sent).slice(Offset, Offset + Piece),
                'headers', new(['Content-Type', 'application/octet-stream'])])));
              Body := await(string, R.text);
              if R.ok then Answer := TJSObject(TJSJSON.parse(Body))
              else
              begin
                Lost := True;
                Trouble := TJSError.new(Body);
              end;
            except
              Lost := True;
              Trouble := JSExceptValue;
            end;
            if Lost then
            begin
              Inc(Tries);
              if Tries > 4 then Break;
              await(JSValue, TJSPromise.new(procedure(Go, Stop: TJSPromiseResolver)
                begin
                  window.setTimeout(procedure begin Go(undefined); end, 2000 * Tries);
                end));
              Continue;
            end;
            Tries := 0;
            if Truthy(Answer['done']) then
            begin
              Progress.textContent := '';
              C.toast(T('Kept as %s.', Answer['name']));
              Break;
            end;
            Offset := Num(Answer['have']);
            Progress.textContent := T('Sending: %s', Str(MathFloor(100 * Offset / MathMax(1, Sent.size))) + '%');
          end;
          if Lost then
          begin
            Progress.textContent := '';
            C.failed(Trouble);
          end
          else Show;
        except
          Progress.textContent := '';
          C.failed(JSExceptValue);
        end;
      finally
        TJSObject(Send)['disabled'] := False;
      end;
    end;

  begin
    try
      Data := await(TJSObject, C.get('/api/admin/backup'));
    except
      C.failed(JSExceptValue);
      Exit;
    end;
    Box.replaceChildren;
    Box.appendChild(C.el('p', 'hint', T('A backup is one zip file with every table of the database, the data folder with members’ files, and the program’s config file. The pictures are large: the wiki’s hold what members uploaded, so they belong in a whole backup. The access logs are only history. Each goes in when asked. Backups are kept on the server in %s.', Data['folder'])));
    // what needs saying first
    List := SortBy(TJSArray(Either(Data['backups'], TJSArray.new)).slice(0), function(A, B: TJSObject): double
      begin
        if Less(A['when'], B['when']) then Result := 1 else Result := -1;
      end);
    if List.length > 0 then Newest := TJSObject(List[0]) else Newest := nil;
    if Truthy(Data['outside']) and (jsTypeOf(Data['outside']) = 'object') then Outside := TJSObject(Data['outside']) else Outside := nil;
    Worries := TJSArray.new;
    if Newest = nil then Worries.push(T('No backup has been made here yet.'))
    else if Hours(Newest['when']) > 36 then Worries.push(T('The newest backup here is %s old.', C.ago(Newest['when'])));
    if (Newest <> nil) and Truthy(Newest['about']) and Same(TJSObject(Newest['about'])['whole'], False) then
      Worries.push(T('The newest backup here did not pass its check: %s', Either(TJSObject(Newest['about'])['note'], '')));
    if Outside = nil then Worries.push(T('No copy on another machine has been recorded. A script that copies backups elsewhere writes backup-status.json beside the program.'))
    else if Same(Outside['ok'], False) then Worries.push(T('The last copy to another machine failed (%s).', Either(Outside['failed'], T('see its log'))))
    else if Hours(Outside['when']) > 36 then Worries.push(T('The last copy to another machine is %s old.', C.ago(Outside['when'])));
    if (Num(Data['free_bytes']) >= 0) and (Num(Data['free_bytes']) < 2 * 1024 * 1024 * 1024) then
      Worries.push(T('Only %s is free on the disk that holds the backups.', C.sizeText(Data['free_bytes'])));
    if Worries.length > 0 then
    begin
      Notice := C.el('div', 'notice bad');
      for I := 0 to Worries.length - 1 do Notice.appendChild(C.el('div', '', Worries[I]));
      Box.appendChild(Notice);
    end
    else Box.appendChild(C.el('p', 'notice good', T('A whole backup from the last day and a half is here, and the copy on the other machine is fresh.')));
    // the job running, or how the last one ended
    if Truthy(Data['busy']) then
    begin
      Line := C.el('p', 'notice working');
      if Same(Data['doing'], 'restore') then Word := T('Restoring…')
      else if Same(Data['doing'], 'check') then Word := T('Checking…')
      else Word := T('Making a backup…');
      TKit(Line).add(C.el('b', '', Word), ' ', C.el('span', '', Either(Data['step'], '')), ' ',
        C.el('span', 'dim', T('started %s by %s', DateTimeText(Data['started']), Either(Data['by'], ''))));
      Box.appendChild(Line);
      if Timer = 0 then Timer := window.setInterval(procedure begin Show; end, 2000);
    end
    else
    begin
      if Timer <> 0 then
      begin
        window.clearInterval(Timer);
        Timer := 0;
      end;
      if Truthy(Data['error']) then Box.appendChild(C.el('p', 'notice bad', T('The last job failed: %s', Data['error'])))
      else if Truthy(Data['last']) then Box.appendChild(C.el('p', 'notice good', Data['last']));
    end;
    Far := C.el('div', 'backup-outside');
    Far.appendChild(C.el('h3', '', T('Copy on another machine')));
    if Outside = nil then Far.appendChild(C.el('p', 'dim', T('None recorded.')))
    else
    begin
      if Truthy(Outside['ok']) then Done := T('complete')
      else if Truthy(Outside['failed']) then Done := T('FAILED') + ' (' + string(Outside['failed']) + ')'
      else Done := T('FAILED');
      Bits := Items(DateTimeText(Outside['when']), Done);
      if Truthy(Outside['database_bytes']) then Bits.push(T('database %s', C.sizeText(Outside['database_bytes'])));
      if Truthy(Outside['config_bytes']) then Bits.push(T('config and files %s', C.sizeText(Outside['config_bytes'])));
      if Truthy(Outside['images_bytes']) then Bits.push(T('pictures %s', C.sizeText(Outside['images_bytes'])));
      if Truthy(Outside['kept']) then Bits.push(TN(Outside['kept'], '%d dump kept', '%d dumps kept'));
      if Truthy(Outside['ok']) then Far.appendChild(C.el('p', '', Bits.join(' · '))) else Far.appendChild(C.el('p', 'bad', Bits.join(' · ')));
      if Truthy(Outside['where']) then Far.appendChild(C.el('p', 'dim', Outside['where']));
    end;
    Box.appendChild(Far);
    Make := C.el('form', 'backup-make');
    Pictures := TickOf('pictures', T('Include the pictures (%s): slow and large, but whole', Either(Data['pictures'], T('none registered'))));
    TJSObject(Pictures['tick'])['checked'] := True;
    Logs := TickOf('logs', T('Include the access logs (the last %d days)', Either(Data['log_days'], 0)));
    Go := C.el('button', '', T('Make a backup now'));
    TJSObject(Go)['disabled'] := Truthy(Data['busy']);
    TKit(Make).add(Go, Pictures['label'], Logs['label']);
    Make.addEventListener('submit', TJSRawEventHandler(@MakeNow));
    Box.appendChild(Make);
    // what is kept
    Box.appendChild(C.el('h3', '', TN(List.length, '%d backup kept here', '%d backups kept here') + ' · ' + T('the newest %d made here stay', Data['keep'])));
    if List.length = 0 then Box.appendChild(C.el('p', 'dim', T('No backups yet.')));
    for I := 0 to List.length - 1 do Kept(TJSObject(List[I]));
    // one from elsewhere
    Up := C.el('form', 'backup-upload');
    Pick := C.el('input');
    TJSObject(Pick)['type'] := 'file';
    TJSObject(Pick)['accept'] := '.zip,application/zip';
    TJSObject(Pick)['required'] := True;
    Send := C.el('button', '', T('Upload a backup'));
    Progress := C.el('span', 'dim');
    Progress.setAttribute('role', 'status');
    TKit(Up).add(C.el('label', '', T('A backup file from another day or another server, of any size:')), Pick, Send, Progress);
    Up.addEventListener('submit', TJSRawEventHandler(@Upload));
    Box.appendChild(Up);
    // moving the site
    Move := C.el('details', 'backup-move');
    Move.appendChild(C.el('summary', '', T('Moving the site to another machine')));
    Steps := C.el('ol');
    Lines := Items(
      T('Make a backup here with the pictures, and download it (or copy it from the folder above).'),
      T('On the new machine: install MariaDB and the client library, make an empty database, and put the program, its static, templates and lang folders and a config file naming that database in one folder, with a data folder the service’s user owns.'),
      T('With the service stopped, as that user, run the program with its config file and --restore and the path of the backup file. It builds the tables, loads every table, puts the data folder and the pictures back (where it may write), and leaves the old config file beside the backups to compare.'),
      T('Start the service. The site is as it was; members stay signed in from the old sessions only if they sign in again.'));
    for I := 0 to Lines.length - 1 do Steps.appendChild(C.el('li', '', Lines[I]));
    Move.appendChild(Steps);
    Move.appendChild(C.el('p', 'dim', 'exedra site.ini --restore /path/site-20260101-000000.zip · exedra site.ini --backup --pictures --logs'));
    Box.appendChild(Move);
  end;

begin
  Timer := 0;
  Show;
end;

end.
