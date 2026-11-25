// The catalog's tab on the admin page, loaded by the admin shell: the list of
// entries with its filters, the picked entry's reports, words and picture,
// what readers did lately, and the numbers.  A site's own script adds
// sub-tabs through C.extras.catalogTabs and words for its choices through
// C.extras.catalogCaptions.
(function () {
  'use strict';
  const C = window.Site;
  if (!C) return;
  const el = C.el;

  // a heading and a table under it, and a number as a tile: both drawn by admin.js
  function table(holder, title, headings, rows) {
    holder.appendChild(el('h2', '', title));
    C.adminTable(holder, headings, rows);
  }
  function stat(holder, value, caption, note, cls) { return C.stat(holder, value, caption, note, cls); }

  // the catalog's entries as a list: searched, filtered and sorted on the
  // server, the picked entry below with its reports, classification and the
  // buttons that act on it; the numbers by kind, source and status in a sub-tab
  function catalog(holder) {
    // a site's own script adds sub-tabs after Entries: C.extras.catalogTabs.push({key, title, build(holder)})
    const more = C.extras.catalogTabs || [];
    const subs = C.subTabs(holder, 'catalog', [{key: 'entries', title: t('Entries')}].concat(more.map(function (x) { return {key: x.key, title: x.title}; }),
      [{key: 'activity', title: t('Activity')}, {key: 'numbers', title: t('Numbers')}]));
    activity(subs.holder('activity'));
    const tiles = el('div', 'tiles-admin'), numbers = subs.holder('numbers');
    subs.holder('entries').appendChild(tiles);
    const notice = el('p'); notice.setAttribute('role', 'status');
    // counts: whether the next answer should bring the catalog's numbers (first, and after a change)
    let can = [], drawn = false, counts = true;
    // kinds, and what an entry works with: the choices the server's units registered,
    // filled from the list's first answer (a plain catalog has none of the second)
    const kinds = [], works = [];
    // what the list can be narrowed to; entries flagged for review join it when there are any
    const shows = [['hidden', t('Hidden entries')], ['reported', t('Reported by members')]];
    const caption = function (v) { const words = (C.extras.catalogCaptions || {})[v]; return words || t(v.charAt(0).toUpperCase() + v.slice(1)); };
    const choices = function (data) {
      if (!data.choices || kinds.length || works.length) return;
      for (const v of data.choices.kind || []) kinds.push([v, caption(v)]);
      for (const v of data.choices.works_with || []) works.push([v, caption(v)]);
    };
    const named = function (list, v) { const x = list.find(function (p) { return p[0] === v; }); return x ? x[1] : v; };
    const flagged = function (item) { return /^Flagged for review/.test(item.hidden_note || ''); };
    const summary = function (data) {
      tiles.replaceChildren();
      stat(tiles, data.total, t('Entries'));
      stat(tiles, data.hidden, t('Hidden'));
      stat(tiles, data.reported || 0, t('Reported by members'), '', data.reported ? 'warn' : '');
      // flagged entries, sources and states come from a site's own tools: shown when there are any
      if (data.flagged) {
        stat(tiles, data.flagged, t('Flagged for review'));
        if (!shows.some(function (p) { return p[0] === 'flagged'; })) shows.push(['flagged', t('Flagged for review')]);
      }
      if (drawn) return;
      drawn = true;
      table(numbers, t('By kind'), [t('Kind'), t('Entries')], data.kinds.map(item => [t(item.name), item.count]));
      if (data.sources.length) table(numbers, t('By source'), [t('Source'), t('Entries')], data.sources.map(item => [t(item.name), item.count]));
      if (data.statuses.some(item => item.name !== 'unknown'))
        table(numbers, t('By status'), [t('Status'), t('Entries')], data.statuses.map(item => [t(item.name), item.count]));
    };
    // The fields of an entry, for the Add form and the Edit form (item: the entry being changed).
    // kind: a list of choices for a select, 'area' for a few lines, 'file' for a picture, nothing for one line
    const entryFields = function (form, fields, item) {
      const field = function (key, caption, kind) {
        const label = el('label', '', caption), input = el(Array.isArray(kind) ? 'select' : kind === 'area' ? 'textarea' : 'input');
        input.name = key;
        if (Array.isArray(kind)) for (const [value, words] of kind) { const option = el('option', '', words); option.value = value; input.appendChild(option); }
        else if (kind === 'area') input.rows = 3;
        else if (kind === 'file') { input.type = 'file'; input.accept = 'image/png,image/jpeg,image/gif,image/webp'; }
        else input.maxLength = key === 'url' ? 2000 : key === 'kind' ? 20 : 300;
        if (kind !== 'file') input.value = was(item, key);
        fields[key] = input; label.appendChild(input); form.appendChild(label);
      };
      field('title', t('Title'));
      field('url', t('Where it lives (an address), if it lives somewhere'));
      field('summary', t('What it is, in a few lines'), 'area');
      // one of the kinds the server's units registered; with none, the admin's own word for it
      field('kind', t('Kind'), kinds.length ? kinds : '');
      if (works.length && item.id) field('works_with', t('Works with'), works);
      field('categories', t('Categories (comma separated)'));
      field('license', t('License, if it has one'));
      field('picture', t('Picture (PNG, JPEG, GIF or WebP)'), 'file');
      fields.title.required = true;
      fields.url.type = 'url'; fields.url.placeholder = 'https://';
    };
    // What a field holds before it is changed.  A kind typed freely shows empty while unknown.
    const was = function (item, key) {
      if (key !== 'kind') return item[key] || '';
      if (kinds.length) return item.kind || 'unknown';
      return item.kind && item.kind !== 'unknown' ? item.kind : '';
    };
    // The picture chosen in a form goes to the entry once the entry is saved.
    const sendPicture = async function (id, input) {
      if (!input.files.length) return;
      const sent = new FormData();
      sent.append('id', id); sent.append('file', input.files[0]);
      await C.post('/api/admin/catalog/picture', sent);
    };
    function button(parent, caption, work, cls) {
      const control = el('button', cls || '', caption); control.type = 'button';
      control.addEventListener('click', async function () {
        control.disabled = true;
        try { await work(); } catch (error) { notice.textContent = error.message; }
        finally { control.disabled = false; }
      });
      parent.appendChild(control);
    }
    const detail = function (item, box, view) {
      const title = item.title || item.name;
      const head = el('div', 'lv-detail-head');
      const link = el('a', '', title); link.href = '/catalog/' + item.id; link.target = '_blank';
      head.appendChild(link);
      head.appendChild(item.hidden ? C.chip(flagged(item) ? t('Flagged') : t('Hidden'), 'bad') : C.chip(t('Visible')));
      box.appendChild(head);
      C.facts(box, [[t('Key'), item.entry_key], [t('Kind'), named(kinds, item.kind)]].concat(works.length ? [[t('Works with'), named(works, item.works_with)]] : [], [
        [t('Categories'), item.categories], [item.hidden ? t('Hidden reason') : t('Note'), item.hidden ? (item.hidden_note || t('No reason recorded.')) : item.hidden_note]]));
      if (item.reports > 0) {
        box.appendChild(el('h3', '', tn(item.reports, '%d member report', '%d member reports')));
        const notes = el('ul');
        for (const line of String(item.report_notes || '').split('\n').filter(Boolean)) notes.appendChild(el('li', '', line));
        box.appendChild(notes);
      }
      const acts = el('div', 'lv-actions');
      if (item.reports > 0 && can.includes('edit-catalog')) button(acts, t('Dismiss the reports'), async function () {
        await C.post('/api/admin/catalog/dismiss', {id: item.id}); counts = true; await view.reload();
      });
      if (can.includes('edit-catalog')) button(acts, item.hidden ? t('Unhide') : t('Hide'), async function () {
        await C.post('/api/catalog/hide', {id: item.id, hidden: item.hidden ? '0' : '1'}); counts = true; await view.reload();
      });
      if (can.includes('delete-catalog')) button(acts, t('Delete'), async function () {
        if (!window.confirm(t('Delete %s, its ratings and README? This cannot be undone.', title))) return;
        await C.post('/api/admin/catalog/delete', {id: item.id}); view.unpick(); counts = true; await view.reload();
      }, 'bad');
      box.appendChild(acts);
      if (can.includes('edit-catalog')) {
        box.appendChild(el('h3', '', t('Edit this entry')));
        const edit = el('form', 'lv-edit'), fields = {};
        entryFields(edit, fields, item);
        if (item.picture) {
          const shown = el('img', 'catalog-admin-picture'); shown.src = item.picture; shown.alt = '';
          edit.appendChild(shown);
          button(edit, t('Remove the picture'), async function () {
            await C.post('/api/admin/catalog/picture', {id: item.id, remove: '1'}); await view.reload();
          });
        }
        const save = el('button', 'primary', t('Save')); edit.appendChild(save);
        edit.addEventListener('submit', async function (event) {
          event.preventDefault(); save.disabled = true;
          try {
            // only what was changed is sent, so words nobody touched are not marked as an admin's
            const sent = {id: item.id, categories: fields.categories.value};
            for (const key in fields) if (key !== 'picture' && fields[key].value !== was(item, key)) sent[key] = fields[key].value;
            // a kind taken out is unknown again; sent empty it would stay as it was
            if (sent.kind !== undefined && !sent.kind.trim()) sent.kind = 'unknown';
            await C.post('/api/admin/catalog/save', sent);
            await sendPicture(item.id, fields.picture);
            counts = true; await view.reload();
            C.toast(t('Saved.'));
          } catch (error) { notice.textContent = error.message; }
          finally { save.disabled = false; }
        });
        box.appendChild(edit);
      }
      box.appendChild(notice);
    };
    // an entry put in by hand: a small form over the list, opened by its line.  It is
    // made once the list's first answer says this person may change the catalog.
    const addPlace = el('div'); subs.holder('entries').appendChild(addPlace);
    let entries = null, addOffered = false;
    const offerAdd = function () {
      if (addOffered || !can.includes('edit-catalog')) return;
      addOffered = true;
      const adding = el('details', 'catalog-add'), addForm = el('form', 'lv-edit'), added = {};
      adding.appendChild(el('summary', '', t('Add an entry')));
      entryFields(addForm, added, {});
      const addSave = el('button', 'primary', t('Add')), addNote = el('p'); addNote.setAttribute('role', 'status');
      addForm.append(addSave, addNote);
      adding.appendChild(addForm);
      addForm.addEventListener('submit', async function (event) {
        event.preventDefault(); addSave.disabled = true; addNote.textContent = '';
        try {
          const sent = {};
          for (const key in added) if (key !== 'picture') sent[key] = added[key].value;
          const made = JSON.parse(await C.post('/api/admin/catalog/add', sent));
          // the entry is in; a picture the server refuses is said, and can be sent again from the entry
          try { await sendPicture(made.id, added.picture); } catch (error) { C.toast(error.message, 'bad'); }
          for (const key in added) added[key].value = was({}, key);
          adding.open = false; counts = true;
          C.toast(t('Added.'));
          if (entries) await entries.reload();
          window.open('/catalog/' + made.id, '_blank');
        } catch (error) { addNote.textContent = error.message; }
        finally { addSave.disabled = false; }
      });
      addPlace.appendChild(adding);
    };
    entries = C.listView(subs.holder('entries'), {
      id: 'catalog', key: function (item) { return String(item.id); }, sort: 'name', csv: 'catalog',
      search: t('Search by name, title or key'),
      remote: function (s) {
        return C.get('/api/admin/catalog?q=' + C.enc(s.q) + '&page=' + s.page + '&show=' + C.enc(s.filters.show || 'all') +
          '&kind=' + C.enc(s.filters.kind || '') + '&sort=' + C.enc(s.sort) + (counts ? '' : '&counts=0')).then(function (data) {
          counts = false;
          can = data.can;
          choices(data);
          offerAdd();
          // the catalog's numbers come with the first answer only
          if (data.kinds) summary(data);
          return {rows: data.items, total: data.matches};
        });
      },
      columns: [
        {key: 'name', title: t('Entry'), cell: function (item) { return item.title || item.name; }},
        {key: 'key', title: t('Key'), wide: true, value: function (item) { return item.entry_key; }},
        {key: 'kind', title: t('Kind'), value: function (item) { return named(kinds, item.kind); }},
        {key: 'reports', title: t('Reports'), num: true, cell: function (item) { return item.reports ? C.chip(String(item.reports), 'bad') : ''; }},
        {key: 'state', title: t('State'), value: function (item) { return item.hidden ? (flagged(item) ? t('Flagged') : t('Hidden')) : t('Visible'); },
          cell: function (item) { return item.hidden ? C.chip(flagged(item) ? t('Flagged') : t('Hidden'), 'bad') : C.chip(t('Visible')); }}
      ],
      filters: [
        {key: 'show', title: t('Show'), all: t('All entries'),
          options: shows},
        {key: 'kind', title: t('Kind'), all: t('Every kind'), options: kinds}
      ],
      rowClass: function (item) { return item.reports > 0 ? 'unread' : ''; },
      noun: function (n) { return tn(n, '%d entry', '%d entries'); },
      detail: detail
    });
    for (const extra of more) extra.build(subs.holder(extra.key));
  }

  // how readers use Random project and Interesting, over a period: the
  // totals, then by day, by reader, by project, by narrowing, and what
  // crawlers did with the links (they follow Not for me but never press)
  function activity(holder) {
    const bar = el('div', 'visit-controls');
    const period = el('select'), hide = el('input'), hideLabel = el('label', 'visit-tick'), periodLabel = el('label', '', t('Period') + ' ');
    periodLabel.appendChild(period);
    for (const [v, words] of [['1', t('Today')], ['7', t('Last 7 days')], ['30', t('Last 30 days')], ['90', t('Last 90 days')], ['0', t('Everything kept')]]) {
      const option = el('option', '', words); option.value = v; period.appendChild(option);
    }
    period.value = '7';
    hide.type = 'checkbox'; hide.checked = true;
    hideLabel.append(hide, ' ' + t('Hide my own'));
    bar.append(periodLabel, hideLabel);
    holder.appendChild(bar);
    const note = el('p', 'hint'), tiles = el('div', 'tiles-admin');
    holder.append(note, tiles);
    const subs = C.subTabs(holder, 'catalog-activity', [{key: 'days', title: t('By day')}, {key: 'people', title: t('Readers')},
      {key: 'projects', title: t('Projects')}, {key: 'narrowing', title: t('Narrowing')}, {key: 'crawlers', title: t('Crawlers')}]);
    const shown = function (r) { return (r.start || 0) + (r.skip || 0) + (r.yes || 0) + (r.narrow || 0); };
    const rate = function (yes, skip) { return yes + skip ? Math.round(100 * yes / (yes + skip)) + '%' : ''; };
    const reader = function (r) { return r.name || t('Guest %s', r.who.slice(1, 7)); };
    // what a reader narrowed Random project to, as 'components/lazarus': each half in the
    // site's own words (C.extras.catalogCaptions['only-components']), nothing chosen as Anything
    const narrowing = function (v) {
      const words = C.extras.catalogCaptions || {};
      const parts = String(v || '').split('/').filter(Boolean).map(function (part) { return words['only-' + part] || t('%s only', part); });
      return parts.length ? parts.join(' · ') : t('Anything');
    };
    const steps = [
      {key: 'start', title: t('Started'), num: true},
      {key: 'yes', title: t('Interesting'), num: true},
      {key: 'skip', title: t('Not for me'), num: true},
      {key: 'narrow', title: t('Narrowed'), num: true, wide: true},
      {key: 'press', title: t('Pressed'), num: true, wide: true},
      {key: 'unpress', title: t('Taken back'), num: true, wide: true}
    ];
    const days = C.listView(subs.holder('days'), {
      id: 'catalog-days', key: function (r) { return r.day; }, sort: '-day', csv: 'catalog-activity-days', search: false,
      columns: [{key: 'day', title: t('Day'), down: true}, {key: 'people', title: t('Readers'), num: true}].concat(steps,
        [{key: 'crawler_steps', title: t('Crawler steps'), num: true, wide: true}]),
      noun: function (n) { return tn(n, '%d day', '%d days'); }, empty: t('No one used Random project or Interesting in this period.')
    });
    const people = C.listView(subs.holder('people'), {
      id: 'catalog-readers', key: function (r) { return r.who; }, sort: '-last', csv: 'catalog-activity-readers', search: t('Filter by member'),
      columns: [
        {key: 'name', title: t('Reader'), value: reader},
        {key: 'last', title: t('Last'), down: true, cell: function (r) { return window.dateTimeText(r.last); }},
        {key: 'days', title: t('Days'), num: true, wide: true},
        {key: 'shown', title: t('Projects shown'), num: true, value: shown},
        {key: 'rate', title: t('Interesting rate'), num: true, value: function (r) { return r.yes + r.skip ? Math.round(100 * r.yes / (r.yes + r.skip)) : -1; },
          cell: function (r) { return rate(r.yes, r.skip); }}
      ].concat(steps),
      filters: [{key: 'kind', title: t('Readers'), all: t('Everyone'), options: [['member', t('Members')], ['guest', t('Guests')]],
        test: function (r, v) { return v === 'member' ? !!r.name : !r.name; }}],
      noun: function (n) { return tn(n, '%d reader', '%d readers'); }, empty: t('No one used Random project or Interesting in this period.'),
      detail: function (r, box) {
        box.appendChild(el('div', 'lv-detail-head', reader(r)));
        C.facts(box, [[t('First'), window.dateTimeText(r.first)], [t('Last'), window.dateTimeText(r.last)], [t('Days'), r.days],
          [t('Projects shown'), shown(r)], [t('Interesting, show me another'), r.yes], [t('Not for me, show me another'), r.skip],
          [t('Interesting rate'), rate(r.yes, r.skip)], [t('Interesting pressed elsewhere'), r.press], [t('Taken back'), r.unpress],
          [t('Narrowed to'), String(r.narrowings || '').split(', ').filter(Boolean).map(narrowing).join('; ')]]);
        if (!r.name) box.appendChild(el('p', 'hint', t('Someone not signed in; only a scrambled form of the address is kept.')));
      }
    });
    const projects = C.listView(subs.holder('projects'), {
      id: 'catalog-projects', key: function (r) { return String(r.id); }, sort: '-yes', csv: 'catalog-activity-projects', search: t('Filter by project'),
      columns: [
        {key: 'title', title: t('Project'), cell: function (r) { const a = C.link('/catalog/' + r.id, '', r.title); a.target = '_blank'; return a; }},
        {key: 'yes', title: t('Interesting'), num: true, down: true},
        {key: 'skip', title: t('Not for me'), num: true},
        {key: 'press', title: t('Pressed'), num: true, wide: true},
        {key: 'unpress', title: t('Taken back'), num: true, wide: true},
        {key: 'people', title: t('Readers'), num: true, wide: true},
        {key: 'interest', title: t('Interesting now'), num: true}
      ],
      noun: function (n) { return tn(n, '%d project', '%d projects'); }, empty: t('No project got an answer in this period.')
    });
    const narrow = C.listView(subs.holder('narrowing'), {
      id: 'catalog-narrowing', key: function (r) { return r.narrowing; }, sort: '-steps', search: false,
      columns: [{key: 'narrowing', title: t('Showing'), value: function (r) { return narrowing(r.narrowing); }},
        {key: 'steps', title: t('Projects shown'), num: true, down: true}, {key: 'people', title: t('Readers'), num: true}],
      noun: function (n) { return tn(n, '%d choice', '%d choices'); }, empty: t('No one used Random project in this period.')
    });
    const crawlers = C.listView(subs.holder('crawlers'), {
      id: 'catalog-crawlers', key: function (r) { return r.name; }, sort: '-steps', csv: 'catalog-activity-crawlers', search: false,
      columns: [
        {key: 'name', title: t('Crawler'), value: function (r) { return r.name || t('No crawler name, no script'); }},
        {key: 'steps', title: t('Steps'), num: true, down: true},
        {key: 'addresses', title: t('Addresses'), num: true},
        {key: 'start', title: t('Started'), num: true, wide: true},
        {key: 'skip', title: t('Not for me'), num: true, wide: true},
        {key: 'last', title: t('Last'), wide: true, cell: function (r) { return window.dateTimeText(r.last); }}
      ],
      noun: function (n) { return tn(n, '%d crawler', '%d crawlers'); }, empty: t('No crawler followed the random links in this period.')
    });
    holder.appendChild(el('p', 'hint', t('A reader is counted when the page\'s script sends the click, or for a press; crawlers follow the links without either. The steps without a crawler name are mostly crawlers posing as browsers, or someone with scripts turned off.')));
    let asked = 0;
    const load = function () {
      const mine = ++asked;
      for (const v of [days, people, projects, narrow, crawlers]) v.loading();
      C.waiting(tiles);
      C.get('/api/admin/catalog/activity?days=' + period.value + '&hide=' + (hide.checked ? '1' : '0')).then(function (d) {
        if (mine !== asked) return;
        const n = (d.totals || [])[0] || {}, k = (d.kept || [])[0] || {};
        note.textContent = d.since ? t('Counting since %s.', window.dateTimeText(d.since)) : t('Nothing counted yet: the counting began with this version.');
        tiles.replaceChildren();
        stat(tiles, n.discoverers || 0, t('Readers discovering'), n.members ? tn(n.members, '%d member', '%d members') : '');
        stat(tiles, shown(n), t('Projects shown'), n.start ? tn(n.start, '%d start', '%d starts') : '');
        stat(tiles, n.yes || 0, t('Interesting, show me another'));
        stat(tiles, n.skip || 0, t('Not for me, show me another'));
        stat(tiles, rate(n.yes || 0, n.skip || 0) || '–', t('Interesting rate'));
        stat(tiles, n.press || 0, t('Interesting pressed elsewhere'), n.unpress ? tn(n.unpress, '%d taken back', '%d taken back') : '');
        stat(tiles, k.interest || 0, t('Interesting kept'), tn(k.interest_people || 0, 'from %d reader', 'from %d readers') + ' · ' + tn(k.interest_all || 0, '%d in all', '%d in all'));
        stat(tiles, k.ratings || 0, t('Ratings'), k.reports ? tn(k.reports, '%d report', '%d reports') : '');
        stat(tiles, n.crawler_steps || 0, t('Crawler steps'));
        subs.count('crawlers', (d.crawlers || []).length);
        days.set(d.by_day || []); people.set(d.people || []); projects.set(d.projects || []);
        narrow.set(d.narrowings || []); crawlers.set(d.crawlers || []);
      }).catch(function (error) {
        if (mine !== asked) return;
        tiles.replaceChildren();
        for (const v of [days, people, projects, narrow, crawlers]) v.failed(error.message);
      });
    };
    period.addEventListener('change', load);
    hide.addEventListener('change', load);
    load();
  }


  // the catalog's settings sit with it, and both go when the module is off
  C.extras.settingGroups.Catalog = 'Catalog';
  C.extras.adminTabs.push({title: 'Catalog', permission: 'view-catalog', build: catalog, group: 'Catalog', part: 'catalog',
    // the entries members reported, waiting for a look
    badge: function () { return C.get('/api/admin/catalog?show=reported&counts=0').then(function (d) { return d.matches; }); }});
})();
