// The site's admin page, loaded when it is opened.  It runs with the chat off
// too: window.Chat is the site's shell under its first name (also window.Site).
(function () {
  'use strict';

  const C = window.Chat;
  const $ = C.$, stream = C.stream, Site = C.Site, Me = C.me, S = C.state, Extras = C.extras,
    el = C.el, link = C.link, get = C.get, post = C.post, enc = C.enc, toast = C.toast,
    failed = C.failed, route = C.route, ago = C.ago, subTabs = C.subTabs, facts = C.facts,
    chip = C.chip, waiting = C.waiting, iconButton = C.iconButton, sizeText = C.sizeText,
    syncNow = C.syncNow, toggleMenu = C.toggleMenu, locale = C.locale, clock = C.clock,
    shared = C.shared, loadScript = C.loadScript;

  // ------------------------------------------------------------------ admin

  async function openAdmin() {
    const generation = S.generation;
    try {
      for (const extra of Extras.adminScripts) await loadScript(extra.src);
    } catch (err) { failed(err); return; }
    if (generation !== S.generation) return;
    const data = await get('/api/admin');
    if (generation !== S.generation) return;
    S.title = t('Admin');
    const can = function (p) { return data.can.indexOf(p) >= 0; };
    const head = $('#roomhead');
    const menu = iconButton('menu', t('Channels'), 'menubtn');
    menu.addEventListener('click', toggleMenu);
    head.append(menu, el('div', 'titles'));
    $('.titles', head).appendChild(el('h1', '', t('Running %s', Site)));
    if (data.members_total !== undefined)
      $('.titles', head).appendChild(el('p', 'topic', tn(data.members_total, '%d members', '%d members')));
    const page = el('div', 'admin');
    // a page read from the top: the stream is not held at its bottom, as a room's is
    stream.noPin = true;
    stream.pinned = false;
    stream.appendChild(page);
    stream.scrollTop = 0;

    // The page's list: one part of the page at a time, chosen on the left
    // where a room list would be, under the group it belongs to.
    const body = document.body;
    let nav = $('#adminnav');
    if (!nav) {
      nav = el('nav');
      nav.id = 'adminnav';
      const rooms = $('#roomlist');
      if (rooms && rooms.after) rooms.after(nav);
      else page.appendChild(nav);
    }
    nav.hidden = false;
    nav.setAttribute('aria-label', t('Admin'));
    nav.replaceChildren();
    body.classList.add('admin-view');
    const parts = [];
    const tab = function (title, build, caption, count, group) {
      const b = el('button', 'room');
      b.type = 'button';
      b.appendChild(el('span', 'name', caption || {Members: t('Members'), Permissions: t('Permissions'), Settings: t('Settings'),
        Look: t('Look'), Channels: t('Channels'), Private: t('Private'), Reports: t('Reports'), Blocked: t('Blocked')}[title] || title));
      // how many things wait there, when the tab knows
      const badge = el('span', 'badge mention');
      badge.hidden = true;
      b.appendChild(badge);
      const setCount = function (n) { badge.hidden = !(n > 0); badge.textContent = n > 0 ? String(n) : ''; };
      if (typeof count === 'number') setCount(count);
      else if (typeof count === 'function') Promise.resolve().then(count).then(setCount).catch(function () { });
      const holder = el('section', 'part');
      holder.hidden = true;
      page.appendChild(holder);
      // a tab is built the first time it is opened: one tab's requests at a time, not all of them at once
      let built = false;
      b.addEventListener('click', function () {
        parts.forEach(function (p) { p.button.classList.remove('active'); p.holder.hidden = true; });
        b.classList.add('active');
        holder.hidden = false;
        if (!built) { built = true; build(holder); }
        // on a phone the list is a drawer over the page: it closes on a choice
        if (body.classList.contains('menu')) toggleMenu();
        stream.scrollTop = 0;
        try { localStorage.setItem('admin-tab', title); } catch (e) { }
      });
      parts.push({button: b, holder: holder, title: title, setCount: setCount, group: group || 'More'});
    };

    filePaths = data.file_paths || [];
    const on = String(data.parts || '').split(' ');
    // a group of settings belongs to the part that registered it, and is shown with that part
    const partOfGroup = Object.assign({Chat: 'Chat', Wiki: 'Wiki', Forum: 'Forum'}, Extras.settingGroups);
    // every module the site knows, on or off
    const modules = (data.settings || []).filter(function (s) { return s.group === 'Parts'; }).map(function (s) { return s.name; });
    const partSettings = function (group) {
      return (data.settings || []).some(function (s) { return partOfGroup[s.group] === group; });
    };
    if (data.settings || can('view-admin')) tab('Overview', function (box) { adminOverview(box, data, can); }, t('Overview'), undefined, 'Site');
    for (const extra of Extras.adminTabs)
      if (extra.first && extra.permission && can(extra.permission)) tab(extra.title, extra.build, t(extra.title), extra.badge, extra.group || 'Site');
    if (data.settings && can('manage-settings')) tab('Settings', function (box) {
      adminSettings(box, data, function (group) { return group !== 'Parts' && !partOfGroup[group]; });
    }, undefined, undefined, 'Site');
    if (data.settings && can('manage-settings')) tab('Look', adminLook, undefined, undefined, 'Site');
    if (data.members) tab('Members', function (box) { adminMembers(box, data, can); }, undefined, undefined, 'Site');
    if (data.permissions) tab('Permissions', function (box) { adminPermissions(box, data); }, undefined, undefined, 'Site');
    if (can('read-reports')) tab('Reports', adminReports, undefined, data.open_reports || 0, 'Site');
    if (can('view-visitors') || can('manage-blocks')) tab('Visitors', adminVisitors, t('Visitors'), undefined, 'Server');
    if (can('view-storage')) tab('Storage', adminStorage, t('Storage'), undefined, 'Server');
    if (can('manage-backups')) tab('Backup', adminBackup, t('Backup'), undefined, 'Server');
    if (data.channels) tab('Channels', function (box) { adminChannels(box, data); }, undefined, undefined, 'Chat');
    if (on.indexOf('chat') >= 0 && can('manage-private')) tab('Private', adminPrivate, undefined, undefined, 'Chat');
    // tabs other scripts bring: title, the permission that shows it, what
    // builds it into the box, and the group it is listed under
    for (const extra of Extras.adminTabs)
      if (!extra.first && extra.permission && can(extra.permission) && (!extra.part || on.indexOf(extra.part) >= 0))
        tab(extra.title, extra.build, t(extra.title), extra.badge, extra.group);
    // each part's own settings, last in its group
    if (data.settings)
      for (const group of ['Chat', 'Wiki', 'Forum'].concat(Object.values(Extras.settingGroups)).filter(function (g, i, all) { return all.indexOf(g) === i; }))
        if (partSettings(group) && (modules.indexOf(group.toLowerCase()) < 0 || on.indexOf(group.toLowerCase()) >= 0)) tab(group + ' settings', function (box) {
          adminSettings(box, data, function (g) { return partOfGroup[g] === group; }, group);
        }, t('Settings'), undefined, group);

    // the list on the left: the site first, then the server, then each part
    const order = ['Site', 'Server', 'Chat', 'Wiki', 'Forum'];
    for (const p of parts) if (order.indexOf(p.group) < 0) order.push(p.group);
    for (const group of order) {
      const members = parts.filter(function (p) { return p.group === group; });
      if (!members.length) continue;
      nav.appendChild(el('div', 'group', t(group)));
      for (const p of members) nav.appendChild(p.button);
    }

    // what this admin may do, for panels built later (the address panel's block buttons)
    S.adminCan = can;
    // another tab opened from a row (an address looked up from anywhere), and a tab's count changed
    S.adminTab = function (title) {
      const p = parts.find(function (x) { return x.title === title; });
      if (p) p.button.click();
      return !!p;
    };
    S.adminCount = function (title, n) {
      const p = parts.find(function (x) { return x.title === title; });
      if (p) p.setCount(n);
    };
    let last = parts.length ? parts[0].title : 'Overview';
    try { last = localStorage.getItem('admin-tab') || last; } catch (e) { }
    const selected = parts.find(function (p) { return p.title === last; }) || parts[0];
    if (selected) selected.button.click();
    syncNow(true);
  }

  function adminTable(box, headings, rows) {
    const wrap = el('div', 'gridwrap');
    const table = el('table', 'grid');
    const head = el('tr');
    for (const heading of headings) head.appendChild(el('th', '', heading));
    table.appendChild(head);
    for (const values of rows) {
      const row = el('tr');
      for (const value of values) {
        // a cell is words, or something already built (a link, a chip)
        const cell = el('td');
        if (typeof value === 'object') cell.appendChild(value);
        else cell.textContent = String(value);
        row.appendChild(cell);
      }
      table.appendChild(row);
    }
    wrap.appendChild(table);
    box.appendChild(wrap);
  }

  // a number as a tile: the figure, its caption, a small note under it
  function stat(holder, value, caption, note, cls) {
    const box = el('div', 'stat' + (cls ? ' ' + cls : ''));
    box.appendChild(el('b', '', typeof value === 'number' ? value.toLocaleString(locale) : value));
    box.appendChild(el('span', '', caption));
    if (note) box.appendChild(el('small', '', note));
    holder.appendChild(box);
    return box;
  }

  // sizes or counts as plain bars, the longest filling the row
  function bars(holder, rows, format) {
    const most = Math.max.apply(null, rows.map(function (r) { return r.value; }).concat([1]));
    const grid = el('div', 'bars');
    for (const r of rows) {
      grid.appendChild(el('span', 'name', r.name));
      const bar = el('span', 'bar' + (r.other ? ' other' : ''));
      const fill = el('i'); fill.style.width = Math.max(1, Math.round(100 * r.value / most)) + '%'; bar.appendChild(fill);
      bar.title = r.name + ': ' + format(r.value);
      grid.appendChild(bar);
      grid.appendChild(el('span', 'num', format(r.value)));
    }
    holder.appendChild(grid);
  }

  // a browser string in a few words: "Firefox on Linux"
  function browserOf(agent) {
    const a = agent || '';
    const name = /Edg\//.test(a) ? 'Edge' : /OPR\/|Opera/.test(a) ? 'Opera' : /SamsungBrowser/.test(a) ? 'Samsung Internet' :
      /Firefox\//.test(a) ? 'Firefox' : /Chrome\//.test(a) ? 'Chrome' : /Version\/[\d.]+.*Safari/.test(a) ? 'Safari' : '';
    const system = /Android/.test(a) ? 'Android' : /iPhone|iPad|iPod/.test(a) ? 'iOS' : /Windows/.test(a) ? 'Windows' :
      /Mac OS X|Macintosh/.test(a) ? 'macOS' : /CrOS/.test(a) ? 'ChromeOS' : /Linux|X11/.test(a) ? 'Linux' : '';
    if (name && system) return t('%s on %s', name, system);
    return name || system || a.slice(0, 32);
  }
  function hostOf(url) {
    try { return new URL(url).hostname.replace(/^www\./, ''); } catch (e) { return ''; }
  }
  // addresses the server's units named as files, from /api/admin
  let filePaths = [];
  // a page someone reads: not a picture, script, style, API call or feed (as the report has it)
  function isPagePath(path) {
    const p = (path || '/').toLowerCase().split('?')[0];
    if (/^\/(static|api|images|files|f\/|avatar|ws|sitemap|favicon|manifest)/.test(p) ||
      p === '/robots.txt' || p === '/words.js' || p === '/sw.js') return false;
    for (const prefix of filePaths) if (p.startsWith(prefix)) return false;
    return !/\.(css|js|png|jpe?g|gif|svg|ico|webp|woff2?|xml|txt|json|map)$/.test(p);
  }
  function pageLink(path) {
    path = path || '/';
    let shown = path;
    try { shown = decodeURIComponent(path); } catch (e) { }
    // a link only for a path of this site: one slash, not two (which would name another host)
    if (!/^\/(?!\/)/.test(path)) return el('span', 'visit-path', shown);
    const a = el('a', 'visit-path', shown);
    a.href = path; a.target = '_blank'; a.rel = 'noopener'; a.title = path;
    return a;
  }

  // ------------------------------------------------------------ list views

  // Searchable, sortable lists with keyboard selection and a detail panel.
  // Rows may be local or fetched a page at a time; set() replaces them and
  // failed(words) reports a load failure. The listView options are in
  // docs/CODE-MAP.md.
  function listView(box, o) {
    const view = el('div', 'listview' + (o.cls ? ' ' + o.cls : ''));
    const bar = el('div', 'lv-bar'), scroller = el('div', 'lv-scroll'), table = el('table', 'lv-table');
    const thead = el('thead'), tbody = el('tbody');
    table.append(thead, tbody);
    scroller.appendChild(table);
    const foot = el('div', 'lv-foot'), count = el('span', 'lv-count');
    const more = el('button', 'small-link', t('Show more'));
    more.type = 'button'; more.hidden = true;
    foot.append(count, more);
    const detail = el('div', 'lv-detail');
    detail.hidden = true;
    view.append(bar, scroller, foot, detail);
    box.appendChild(view);

    const keyOf = o.key || function (r) { return JSON.stringify(r); };
    const valueOf = function (c, r) { const v = c.value ? c.value(r) : r[c.key]; return v === undefined || v === null ? '' : v; };
    const textOf = o.text || function (r) { return o.columns.map(function (c) { return String(valueOf(c, r)); }).join(' '); };
    const step = o.page || 100;
    let rows = o.rows || [], shown = [], total = 0, limit = step, page = 0, picked = null, q = '', asked = 0;
    // waiting for the rows: from the server, or from whoever made the list
    let loading = !!o.remote || o.rows === undefined, trouble = '';
    let sort = o.sort || '';
    const filters = {};
    let saved = {};
    try { saved = o.id ? JSON.parse(localStorage.getItem('lv-' + o.id) || '{}') : {}; } catch (e) { }
    if (saved.sort && o.columns.some(function (c) { return !c.nosort && c.key === saved.sort.replace(/^-/, ''); })) sort = saved.sort;
    const save = function () {
      // the sort is kept; a filter is not, so a list never opens narrowed by an old choice
      if (o.id) try { localStorage.setItem('lv-' + o.id, JSON.stringify({sort: sort})); } catch (e) { }
    };

    let find = null, timer = 0;
    if (o.search !== false) {
      find = el('input', 'lv-find');
      find.type = 'search';
      find.placeholder = o.search || t('Search');
      find.setAttribute('aria-label', find.placeholder);
      find.addEventListener('input', function () {
        clearTimeout(timer);
        timer = setTimeout(function () { q = find.value.trim(); refresh(); }, o.remote ? 250 : 60);
      });
      find.addEventListener('keydown', function (e) {
        if (e.key === 'Enter') { e.preventDefault(); if (o.enter) o.enter(find.value.trim()); }
        else if (e.key === 'ArrowDown' && tbody.firstChild && tbody.firstChild.tabIndex === 0) { e.preventDefault(); tbody.firstChild.focus(); }
      });
      bar.appendChild(find);
    }
    const selects = [];
    for (const f of o.filters || []) {
      const s = el('select', 'lv-filter');
      s.setAttribute('aria-label', f.title);
      s.title = f.title;
      filters[f.key] = f.value || '';
      s.addEventListener('change', function () { filters[f.key] = s.value; s.classList.toggle('on', s.value !== ''); save(); refresh(); });
      bar.appendChild(s);
      selects.push({f: f, s: s});
    }
    const fillSelects = function () {
      for (const x of selects) {
        const options = typeof x.f.options === 'function' ? x.f.options(rows) : x.f.options;
        const option = function (value, words) { const o2 = el('option', '', words); o2.value = value; return o2; };
        x.s.replaceChildren(option('', x.f.all || t('All')));
        for (const pair of options) x.s.appendChild(option(pair[0], pair[1]));
        const want = filters[x.f.key] || '';
        x.s.value = want;
        // a choice these rows do not have shows everything
        if (x.s.value !== want) x.s.value = '';
        // a filter that narrows the list stands out
        x.s.classList.toggle('on', x.s.value !== '');
      }
    };
    if (o.csv) {
      const csv = el('button', 'small-link lv-csv', t('Download CSV'));
      csv.type = 'button';
      csv.addEventListener('click', function () {
        const cell = function (v) {
          v = String(v);
          // text from visitors that a spreadsheet would run as a formula stays text
          if (/^[=+\-@\t\r]/.test(v) && !/^-?\d+(\.\d+)?$/.test(v)) v = "'" + v;
          return /[",\n]/.test(v) ? '"' + v.replace(/"/g, '""') + '"' : v;
        };
        const lines = [o.columns.map(function (c) { return cell(c.title); }).join(',')];
        for (const r of shown) lines.push(o.columns.map(function (c) { return cell(valueOf(c, r)); }).join(','));
        const a = el('a');
        a.href = URL.createObjectURL(new Blob([lines.join('\n') + '\n'], {type: 'text/csv'}));
        a.download = o.csv + '.csv';
        document.body.appendChild(a); a.click(); a.remove();
        setTimeout(function () { URL.revokeObjectURL(a.href); }, 5000);
      });
      bar.appendChild(csv);
    }
    if (!bar.children.length) bar.hidden = true;

    // the headings: a click sorts by it, a second click the other way
    const head = el('tr'), ths = [];
    for (const c of o.columns) {
      const th = el('th', (c.num ? 'num' : '') + (c.wide ? ' wide' : ''));
      if (c.nosort) th.textContent = c.title;
      else {
        const b = el('button', 'lv-sort', c.title);
        b.type = 'button';
        b.addEventListener('click', function () {
          sort = sort === c.key ? '-' + c.key : sort === '-' + c.key ? c.key : (c.num || c.down ? '-' : '') + c.key;
          save(); refresh();
        });
        th.appendChild(b);
      }
      ths.push(th);
      head.appendChild(th);
    }
    thead.appendChild(head);
    const markSort = function () {
      o.columns.forEach(function (c, i) {
        const on = sort.replace(/^-/, '') === c.key;
        ths[i].classList.toggle('sorted', on);
        ths[i].classList.toggle('down', on && sort[0] === '-');
        if (on) ths[i].setAttribute('aria-sort', sort[0] === '-' ? 'descending' : 'ascending'); else ths[i].removeAttribute('aria-sort');
      });
    };

    const blank = function (v) { return v === '' || v === null || v === undefined; };
    const compare = function (a, b) {
      if (typeof a === 'number' && typeof b === 'number') return a - b;
      if (typeof a === 'boolean' || typeof b === 'boolean') return Number(a) - Number(b);
      return String(a).localeCompare(String(b), locale, {numeric: true, sensitivity: 'base'});
    };
    const local = function () {
      const words = q.toLowerCase();
      let list = rows.filter(function (r) {
        for (const x of selects) {
          const v = x.s.value;
          if (v && !x.f.test(r, v)) return false;
        }
        return !words || textOf(r).toLowerCase().indexOf(words) >= 0;
      });
      const col = o.columns.find(function (c) { return !c.nosort && c.key === sort.replace(/^-/, ''); });
      if (col) {
        const dir = sort[0] === '-' ? -1 : 1;
        list = list.slice().sort(function (x, y) {
          const a = valueOf(col, x), b = valueOf(col, y);
          // the empty ones last, whichever way
          if (blank(a) || blank(b)) return blank(a) - blank(b);
          return dir * compare(a, b);
        });
      }
      shown = list;
      total = rows.length;
    };

    const rowOf = function (r) {
      const tr = el('tr');
      tr.row = r;
      if (o.rowClass) { const c = o.rowClass(r); if (c) tr.className = c; }
      for (const c of o.columns) {
        const td = el('td', (c.num ? 'num' : '') + (c.wide ? ' wide' : '') + (c.cls ? ' ' + c.cls : ''));
        const v = c.cell ? c.cell(r) : valueOf(c, r);
        if (v && typeof v === 'object') td.appendChild(v);
        else td.textContent = typeof v === 'number' ? v.toLocaleString(locale) : String(v === undefined || v === null ? '' : v);
        tr.appendChild(td);
      }
      if (o.detail) {
        tr.tabIndex = 0;
        if (picked && keyOf(picked) === keyOf(r)) tr.classList.add('on');
        tr.addEventListener('click', function (e) {
          if (e.target.closest('a, button, input, select, label, textarea')) return;
          pick(r, tr);
        });
        tr.addEventListener('keydown', function (e) {
          const to = e.key === 'ArrowDown' ? tr.nextElementSibling : e.key === 'ArrowUp' ? tr.previousElementSibling : null;
          if (to && to.row) { e.preventDefault(); to.focus(); pick(to.row, to, true); }
          else if (e.key === 'ArrowUp' && find) { e.preventDefault(); find.focus(); }
          else if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); pick(r, tr); }
          else if (e.key === 'Escape') unpick();
        });
      }
      return tr;
    };
    const draw = function () {
      tbody.replaceChildren();
      const list = o.remote ? shown : shown.slice(0, limit);
      for (const r of list) tbody.appendChild(rowOf(r));
      view.classList.toggle('lv-busy', loading && list.length > 0);
      if (!list.length && (loading || trouble)) {
        const tr = el('tr', trouble ? 'lv-none lv-trouble' : 'lv-none lv-loading'), td = el('td');
        if (trouble) td.textContent = trouble;
        else td.append(el('span', 'lv-spinner'), ' ' + t('Loading…'));
        td.colSpan = o.columns.length;
        tr.appendChild(td);
        tbody.appendChild(tr);
        count.textContent = '';
        more.hidden = true;
        return;
      }
      if (!list.length) {
        const tr = el('tr', 'lv-none'), td = el('td', '', !rows.length && !o.remote ? (o.empty || t('Nothing here yet.')) : t('Nothing matches.'));
        td.colSpan = o.columns.length;
        tr.appendChild(td);
        tbody.appendChild(tr);
      }
      const all = o.remote ? total : rows.length;
      count.textContent = list.length < all ? t('%d of %d shown', list.length, all) : o.noun ? o.noun(all) : tn(all, '%d row', '%d rows');
      if (loading) count.textContent += ' · ' + t('Loading…');
      more.hidden = o.remote ? shown.length >= total : shown.length <= limit;
    };
    more.addEventListener('click', async function () {
      if (!o.remote) { limit += step; draw(); return; }
      const mine = asked, next = page + 1;
      let a;
      more.disabled = true;
      more.textContent = t('Loading…');
      try { a = await o.remote({q: q, filters: filters, sort: sort, page: next}); } catch (err) { failed(err); return; }
      finally { more.disabled = false; more.textContent = t('Show more'); }
      // a newer search or filter since: this page is not part of its list
      if (mine !== asked) return;
      page = next;
      shown = shown.concat(a.rows);
      total = a.total;
      draw();
    });
    const refresh = async function () {
      if (o.remote) {
        page = 0;
        const mine = ++asked;
        let a;
        // the rows there stay, dimmed, until the new ones come
        loading = true;
        trouble = '';
        markSort();
        draw();
        try { a = await o.remote({q: q, filters: filters, sort: sort, page: 0}); }
        catch (err) {
          if (mine !== asked) return;
          loading = false;
          trouble = err.message || t('The list could not be read.');
          shown = [];
          draw();
          return;
        }
        if (mine !== asked) return;
        loading = false;
        rows = shown = a.rows;
        total = a.total;
        // the picked row as the server has it now, its box drawn again
        if (picked) {
          const k = keyOf(picked), fresh = rows.find(function (r) { return keyOf(r) === k; });
          // gone from the list (unhidden while hidden ones show): its box goes too
          picked = fresh || null;
          markSort(); draw(); showDetail();
          return;
        }
      } else {
        limit = step;
        local();
      }
      markSort();
      draw();
    };

    const showDetail = function () {
      detail.replaceChildren();
      if (!picked) { detail.hidden = true; return; }
      detail.hidden = false;
      const close = el('button', 'lv-close', '×');
      close.type = 'button';
      close.title = t('Close');
      close.setAttribute('aria-label', t('Close'));
      close.addEventListener('click', unpick);
      const inner = el('div', 'lv-detail-body');
      detail.append(close, inner);
      o.detail(picked, inner, api);
    };
    const pick = function (r, tr, keepFocus) {
      picked = r;
      for (const x of tbody.children) x.classList.toggle('on', x === tr);
      showDetail();
      // the box in sight, the list where it was
      if (!keepFocus && detail.getBoundingClientRect) {
        const top = detail.getBoundingClientRect().top, sh = window.innerHeight || 800;
        if (top > sh - 120) detail.scrollIntoView({block: 'nearest', behavior: 'smooth'});
      }
    };
    const unpick = function () {
      picked = null;
      for (const x of tbody.children) x.classList.remove('on');
      showDetail();
    };
    const api = {
      // new rows, the picked one kept when it is still there
      set: function (list) {
        rows = list;
        loading = false;
        trouble = '';
        if (picked) { const k = keyOf(picked); picked = rows.find(function (r) { return keyOf(r) === k; }) || null; }
        fillSelects();
        refresh();
        showDetail();
      },
      reload: function () { return refresh(); },
      // the rows are coming again (a list someone else fills), or could not be had
      loading: function () { loading = true; trouble = ''; draw(); },
      failed: function (words) { loading = false; trouble = words || t('The list could not be read.'); rows = shown = []; draw(); },
      // a row changed in place: its line and its box drawn again
      changed: function (r) {
        for (const tr of tbody.children)
          if (tr.row && keyOf(tr.row) === keyOf(r)) { const n = rowOf(r); if (tr.classList.contains('on')) n.classList.add('on'); tr.replaceWith(n); }
        if (picked && keyOf(picked) === keyOf(r)) { picked = r; showDetail(); }
      },
      pick: function (match) {
        const r = (o.remote ? shown : rows).find(match);
        if (!r) return false;
        picked = r;
        draw();
        showDetail();
        return true;
      },
      // a thing that need not be a row, an address looked up, in the box
      show: function (r) { picked = r; for (const x of tbody.children) x.classList.toggle('on', !!x.row && keyOf(x.row) === keyOf(r)); showDetail(); },
      unpick: unpick,
      search: function (words) { if (find) { find.value = words; q = words; refresh(); } },
      rows: function () { return rows; },
      element: view
    };
    fillSelects();
    refresh();
    return api;
  }

  // the guard's names for what it counts against an address
  function strikeKinds() {
    return Object.assign({'g-miss': t('missing pages'), 'g-password': t('wrong passwords or tokens'), 'g-admin': t('admin pages probed'),
      signin: t('sign-in tries'), signup: t('sign-up tries'), token: t('token tries'), authtry: t('sign-in requests'),
      wikilist: t('wiki lists'), search: t('searches')}, Extras.strikeKinds || {});
  }

  // Lift, Block now, Block for good, Allow: for an admin who manages blocks;
  // after() runs once the server has it
  // crawler: what a verified crawler at ip is ('GPTBot · OpenAI'), so a
  // block of it is asked about first and sent with the server's say-so
  function blockButtons(holder, ip, b, after, crawler) {
    if (!S.adminCan || !S.adminCan('manage-blocks')) return;
    // asked before anything else, so the warning comes ahead of the reason
    const crawlerOk = function () {
      return !crawler || confirm(t('%s is %s, checked against the addresses its company publishes. Blocking it keeps the site out of that company’s search and answers. Block it anyway?', ip, crawler));
    };
    const act = async function (what, reason) {
      const blocking = what === 'block' || what === 'forgood';
      try { await post('/api/blocks', {ip: ip, do: what, reason: reason || '', crawler_ok: blocking && crawler ? '1' : ''}); } catch (err) { failed(err); return; }
      if (S.blocksChanged) S.blocksChanged();
      if (after) after();
    };
    if (b && b.active) {
      const lift = el('button', '', t('Lift'));
      lift.type = 'button';
      lift.addEventListener('click', function () { act('lift'); });
      holder.appendChild(lift);
    }
    if (!b || !b.for_good) {
      const forGood = el('button', 'bad', t('Block for good'));
      forGood.type = 'button';
      forGood.addEventListener('click', function () { if (crawler ? crawlerOk() : confirm(t('Block %s for good?', ip))) act('forgood'); });
      holder.appendChild(forGood);
    }
    if (!b || !b.active) {
      const block = el('button', '', t('Block now'));
      block.type = 'button';
      block.addEventListener('click', function () {
        if (!crawlerOk()) return;
        const reason = prompt(t('Why? (kept with the block)'), '');
        if (reason !== null) act('block', reason);
      });
      holder.appendChild(block);
    }
    const allow = el('button', '', t('Allow'));
    allow.type = 'button';
    allow.title = t('Never block or limit this address again');
    allow.addEventListener('click', function () { act('allow'); });
    holder.appendChild(allow);
  }

  // Addresses shut out for probing or wrong passwords (src/core/siteguard.pas), a
  // sub-tab of Visitors: the list, a filter over it, and each row's whole
  // story in the address panel.  period() is the window the Visitors tab shows.
  function adminBlocks(box, period) {
    const tiles = el('div', 'tiles-admin');
    box.replaceChildren(
      el('p', 'hint', t('An address that asks for six missing pages in a minute, or gets ten passwords wrong in a quarter hour, is shut out for an hour; after three times, for thirty days. Published crawlers, checked against the addresses their companies publish, are never limited or blocked; a browser string that claims to be one of them from another address is refused. This network and the addresses in Settings, allowed_ips, are never blocked either. Allow adds an address there. With an AbuseIPDB key in Settings, an address that probes or guesses passwords here is looked up on AbuseIPDB and reported back, and blocked for good when its confidence of abuse is at the set level or above. Type an address to see its story, or to block it by hand.')),
      tiles);
    const stateOf = function (b) { return b.for_good ? 'forgood' : b.active ? 'blocked' : 'over'; };
    const stateWords = {forgood: t('For good'), blocked: t('Blocked now'), over: t('Over')};
    const list = listView(box, {
      id: 'blocks', key: function (b) { return b.ip; }, sort: '-when', csv: 'blocked',
      search: t('Filter, or type an address and press Enter to look it up'),
      enter: function (ip) { if (ip) lookUpAddress(ip); },
      columns: [
        {key: 'ip', title: t('Address'), cell: function (b) { return el('b', 'lv-ip', b.ip); }},
        {key: 'state', title: t('State'), value: function (b) { return stateWords[stateOf(b)]; },
          cell: function (b) { const s = stateOf(b); return chip(stateWords[s], s === 'over' ? '' : 'bad'); }},
        {key: 'reason', title: t('Why')},
        {key: 'times', title: t('Times'), num: true},
        {key: 'when', title: t('Last change'), down: true, wide: true, cell: function (b) { return dateTimeText(b.when); }},
        {key: 'until', title: t('Until'), wide: true, cell: function (b) { return b.for_good ? t('for good') : dateTimeText(b.until); }}
      ],
      filters: [
        {key: 'state', title: t('State'), all: t('Every state'), options: [['blocked', t('Blocked now')], ['forgood', t('For good')], ['over', t('Over')]],
          test: function (b, v) { return v === 'forgood' ? b.for_good : v === 'blocked' ? b.active : !b.active; }},
        {key: 'reason', title: t('Why'), all: t('Every reason'), test: function (b, v) { return b.reason === v; },
          options: function (rows) {
            const seen = new Map();
            for (const b of rows) seen.set(b.reason, (seen.get(b.reason) || 0) + 1);
            return Array.from(seen).sort(function (a, b) { return b[1] - a[1]; }).map(function (x) { return [x[0], x[0] + ' (' + x[1] + ')']; });
          }}
      ],
      rowClass: function (b) { return b.active ? '' : 'done'; },
      noun: function (n) { return tn(n, '%d address', '%d addresses'); }, empty: t('Nobody is blocked.'),
      detail: function (b, holder) { addressPanel(b.ip, holder, period); }
    });
    const show = async function () {
      const rows = await get('/api/blocks');
      tiles.replaceChildren();
      const active = rows.filter(function (b) { return b.active; }).length;
      stat(tiles, active, t('Blocked right now'));
      stat(tiles, rows.filter(function (b) { return b.for_good; }).length, t('For good'));
      stat(tiles, rows.length - active, t('Over, still listed'));
      list.set(rows);
    };
    S.blocksChanged = function () { show().catch(function () { }); };
    show().catch(function (err) { list.failed(err.message); });
  }

  // Backups of the whole site: made, checked, downloaded, uploaded and
  // restored here (src/core/sitebackup.pas).  The page says plainly whether a
  // fresh, whole backup exists, here and on the other machine.
  function adminBackup(box) {
    let timer = null;
    const hours = function (iso) { return iso ? (Date.now() - new Date(iso)) / 36e5 : Infinity; };
    const show = async function () {
      let data;
      try { data = await get('/api/admin/backup'); } catch (err) { failed(err); return; }
      box.replaceChildren();
      box.appendChild(el('p', 'hint', t('A backup is one zip file with every table of the database, the data folder with members’ files, and the program’s config file. The pictures are large: the wiki’s hold what members uploaded, so they belong in a whole backup. The access logs are only history. Each goes in when asked. Backups are kept on the server in %s.', data.folder)));
      // what needs saying first
      const list = (data.backups || []).slice().sort(function (a, b) { return a.when < b.when ? 1 : -1; });
      const newest = list.length ? list[0] : null;
      const outside = data.outside && typeof data.outside === 'object' ? data.outside : null;
      const worries = [];
      if (!newest) worries.push(t('No backup has been made here yet.'));
      else if (hours(newest.when) > 36) worries.push(t('The newest backup here is %s old.', ago(newest.when)));
      if (newest && newest.about && newest.about.whole === false) worries.push(t('The newest backup here did not pass its check: %s', newest.about.note || ''));
      if (!outside) worries.push(t('No copy on another machine has been recorded. A script that copies backups elsewhere writes backup-status.json beside the program.'));
      else if (outside.ok === false) worries.push(t('The last copy to another machine failed (%s).', outside.failed || t('see its log')));
      else if (hours(outside.when) > 36) worries.push(t('The last copy to another machine is %s old.', ago(outside.when)));
      if (data.free_bytes >= 0 && data.free_bytes < 2 * 1024 * 1024 * 1024) worries.push(t('Only %s is free on the disk that holds the backups.', sizeText(data.free_bytes)));
      if (worries.length) {
        const w = el('div', 'notice bad');
        for (const line of worries) w.appendChild(el('div', '', line));
        box.appendChild(w);
      } else box.appendChild(el('p', 'notice good', t('A whole backup from the last day and a half is here, and the copy on the other machine is fresh.')));
      // the job running, or how the last one ended
      if (data.busy) {
        const line = el('p', 'notice working');
        const word = data.doing === 'restore' ? t('Restoring…') : data.doing === 'check' ? t('Checking…') : t('Making a backup…');
        line.append(el('b', '', word), ' ', el('span', '', data.step || ''), ' ', el('span', 'dim', t('started %s by %s', dateTimeText(data.started), data.by || '')));
        box.appendChild(line);
        if (!timer) timer = setInterval(show, 2000);
      } else {
        if (timer) { clearInterval(timer); timer = null; }
        if (data.error) box.appendChild(el('p', 'notice bad', t('The last job failed: %s', data.error)));
        else if (data.last) box.appendChild(el('p', 'notice good', data.last));
      }
      const far = el('div', 'backup-outside');
      far.appendChild(el('h3', '', t('Copy on another machine')));
      if (!outside) far.appendChild(el('p', 'dim', t('None recorded.')));
      else {
        const bits = [dateTimeText(outside.when), outside.ok ? t('complete') : t('FAILED') + (outside.failed ? ' (' + outside.failed + ')' : '')];
        if (outside.database_bytes) bits.push(t('database %s', sizeText(outside.database_bytes)));
        if (outside.config_bytes) bits.push(t('config and files %s', sizeText(outside.config_bytes)));
        if (outside.images_bytes) bits.push(t('pictures %s', sizeText(outside.images_bytes)));
        if (outside.kept) bits.push(tn(outside.kept, '%d dump kept', '%d dumps kept'));
        far.appendChild(el('p', outside.ok ? '' : 'bad', bits.join(' · ')));
        if (outside.where) far.appendChild(el('p', 'dim', outside.where));
      }
      box.appendChild(far);
      const make = el('form', 'backup-make');
      const tickOf = function (name, words) {
        const label = el('label');
        const tick = el('input');
        tick.type = 'checkbox';
        tick.name = name;
        tick.value = '1';
        label.append(tick, ' ', words);
        return {label: label, tick: tick};
      };
      const pictures = tickOf('pictures', t('Include the pictures (%s): slow and large, but whole', data.pictures || t('none registered')));
      pictures.tick.checked = true;
      const logs = tickOf('logs', t('Include the access logs (the last %d days)', data.log_days || 0));
      const go = el('button', '', t('Make a backup now'));
      go.disabled = !!data.busy;
      make.append(go, pictures.label, logs.label);
      make.addEventListener('submit', async function (e) {
        e.preventDefault();
        try { toast(await post('/api/admin/backup/make', {pictures: pictures.tick.checked ? '1' : '0', logs: logs.tick.checked ? '1' : '0'})); show(); } catch (err) { failed(err); }
      });
      box.appendChild(make);
      // what is kept
      box.appendChild(el('h3', '', tn(list.length, '%d backup kept here', '%d backups kept here') + ' · ' + t('the newest %d made here stay', data.keep)));
      if (!list.length) box.appendChild(el('p', 'dim', t('No backups yet.')));
      for (const b of list) {
        const row = el('div', 'person backup-row');
        const name = el('a', 'backup-name', b.name);
        name.href = '/api/admin/backup/file/' + encodeURIComponent(b.name);
        name.setAttribute('download', b.name);
        row.append(name, el('span', 'dim', sizeText(b.bytes) + ' · ' + dateTimeText(b.when) + (b.uploaded ? ' · ' + t('uploaded') : '')));
        // what it holds, from its manifest; and whether it was proven whole
        const about = b.about || {}, m = about.manifest;
        const holds = [];
        if (m) {
          if (m.site) holds.push(m.site);
          if (m.tables) holds.push(tn(m.tables, '%d table', '%d tables') + ', ' + tn(m.rows || 0, '%d row', '%d rows'));
          if (m.files) holds.push(tn(m.files, '%d file', '%d files'));
          holds.push(m.pictures ? t('with pictures') : t('no pictures'));
          holds.push(m.logs ? t('with access logs') : t('no access logs'));
        } else if (about.manifest === null) holds.push(t('no manifest inside: an early backup or not one made here'));
        const detail = el('div', 'backup-holds dim', holds.join(' · '));
        if (m && m.counts) {
          const more = el('a', 'small-link', t('Tables'));
          more.href = '#';
          const tableList = el('div', 'backup-tables dim');
          tableList.hidden = true;
          const names = Object.keys(m.counts).sort();
          tableList.textContent = names.map(function (n) { return n + ' ' + m.counts[n]; }).join(' · ');
          more.addEventListener('click', function (e) { e.preventDefault(); tableList.hidden = !tableList.hidden; });
          detail.append(' ', more);
          row.append(detail, tableList);
        } else row.appendChild(detail);
        if (about.checked) row.appendChild(el('div', about.whole ? 'backup-check good' : 'backup-check bad', (about.whole ? t('Checked %s: whole.', dateTimeText(about.checked)) : t('Checked %s: NOT whole.', dateTimeText(about.checked))) + ' ' + (about.note || '')));
        else row.appendChild(el('div', 'backup-check warn', t('Not checked yet.')));
        const down = el('a', 'small-link', t('Download'));
        down.href = name.href;
        down.setAttribute('download', b.name);
        row.appendChild(down);
        const check = el('button', 'small-link', t('Check'));
        check.type = 'button';
        check.disabled = !!data.busy;
        check.addEventListener('click', async function () {
          try { toast(await post('/api/admin/backup/check', {name: b.name})); show(); } catch (err) { failed(err); }
        });
        row.appendChild(check);
        const restore = el('button', 'small-link', t('Restore…'));
        restore.type = 'button';
        restore.disabled = !!data.busy;
        restore.addEventListener('click', async function () {
          const word = prompt(t('Restoring %s replaces every table with the backup’s (a table the backup does not have is emptied) and writes its files over the data folder and the pictures; files added since stay. Everyone else sees a "back in a minute" page while it runs, and a restart afterwards is wise. Type RESTORE to go ahead.', b.name));
          if (word === null) return;
          try { toast(await post('/api/admin/backup/restore', {name: b.name, confirm: word.trim()})); show(); } catch (err) { failed(err); }
        });
        row.appendChild(restore);
        const del = el('button', 'small-link', t('Delete'));
        del.type = 'button';
        del.addEventListener('click', async function () {
          if (!confirm(t('Delete %s?', b.name))) return;
          try { toast(await post('/api/admin/backup/delete', {name: b.name})); show(); } catch (err) { failed(err); }
        });
        row.appendChild(del);
        box.appendChild(row);
      }
      // one from elsewhere
      const up = el('form', 'backup-upload');
      const pick = el('input');
      pick.type = 'file';
      pick.accept = '.zip,application/zip';
      pick.required = true;
      const send = el('button', '', t('Upload a backup'));
      const progress = el('span', 'dim');
      progress.setAttribute('role', 'status');
      up.append(el('label', '', t('A backup file from another day or another server, of any size:')), pick, send, progress);
      // in pieces of 8 MB, each sent again when it does not arrive; however
      // large the file, the server never holds more than one piece
      up.addEventListener('submit', async function (e) {
        e.preventDefault();
        if (!pick.files.length) return;
        const file = pick.files[0], piece = 8 * 1024 * 1024;
        const where = '/api/admin/backup/chunk?name=' + enc(file.name);
        send.disabled = true;
        let offset = 0, tries = 0;
        try {
          for (;;) {
            const last = offset + piece >= file.size;
            const url = where + '&offset=' + offset + (last ? '&size=' + file.size : '');
            let answer;
            try {
              const r = await fetch(url, {method: 'POST', body: file.slice(offset, offset + piece), headers: {'Content-Type': 'application/octet-stream'}});
              const text = await r.text();
              if (!r.ok) throw new Error(text);
              answer = JSON.parse(text);
            } catch (err) {
              if (++tries > 4) throw err;
              await new Promise(function (go) { setTimeout(go, 2000 * tries); });
              continue;
            }
            tries = 0;
            if (answer.done) { progress.textContent = ''; toast(t('Kept as %s.', answer.name)); break; }
            offset = answer.have;
            progress.textContent = t('Sending: %s', Math.floor(100 * offset / Math.max(1, file.size)) + '%');
          }
          show();
        } catch (err) { progress.textContent = ''; failed(err); } finally { send.disabled = false; }
      });
      box.appendChild(up);
      // moving the site
      const move = el('details', 'backup-move');
      move.appendChild(el('summary', '', t('Moving the site to another machine')));
      const steps = el('ol');
      for (const line of [
        t('Make a backup here with the pictures, and download it (or copy it from the folder above).'),
        t('On the new machine: install MariaDB and the client library, make an empty database, and put the program, its static, templates and lang folders and a config file naming that database in one folder, with a data folder the service’s user owns.'),
        t('With the service stopped, as that user, run the program with its config file and --restore and the path of the backup file. It builds the tables, loads every table, puts the data folder and the pictures back (where it may write), and leaves the old config file beside the backups to compare.'),
        t('Start the service. The site is as it was; members stay signed in from the old sessions only if they sign in again.')
      ]) steps.appendChild(el('li', '', line));
      move.appendChild(steps);
      move.appendChild(el('p', 'dim', 'exedra site.ini --restore /path/site-20260101-000000.zip · exedra site.ini --backup --pictures --logs'));
      box.appendChild(move);
    };
    show();
  }

  // Bug reports as a mail client lists mail: the newest first, unread in
  // bold, a state each and a note for why; the one picked shown whole below.
  function adminReports(box) {
    const states = [['new', t('New')], ['read', t('Read')], ['needs-info', t('Needs more information')], ['resolved', t('Resolved')], ['closed', t('Closed')], ['spam', t('Spam')]];
    const stateName = function (s) { const x = states.find(function (p) { return p[0] === s; }); return x ? x[1] : s; };
    let rows = [];
    const openCount = function () { if (S.adminCount) S.adminCount('Reports', rows.filter(function (r) { return !r.done; }).length); };
    const save = async function (r, fields, view) {
      try { await post('/api/bugs', Object.assign({id: r.id}, fields)); } catch (err) { failed(err); return false; }
      if (fields.state) { r.state = fields.state; r.done = fields.state === 'resolved' || fields.state === 'closed' || fields.state === 'spam'; }
      if (fields.note !== undefined) r.note = fields.note;
      view.changed(r);
      openCount();
      return true;
    };
    const detail = function (r, holder, view) {
      const head = el('div', 'lv-detail-head');
      head.append(el('b', '', r.name), el('span', 'dim', dateTimeText(r.at)));
      holder.appendChild(head);
      // the page the reporter named: a link only when it is a path of this site
      const local = /^\/(?!\/)/.test(r.page || '');
      const page = el(local ? 'a' : 'span', '', r.page);
      if (local) { page.href = r.page; page.target = '_blank'; page.rel = 'noopener'; }
      const ip = el('span');
      if (r.ip) {
        ip.append(r.ip + ' ');
        const look = el('button', 'small-link', t('Look up'));
        look.type = 'button';
        look.addEventListener('click', function () { lookUpAddress(r.ip); });
        ip.appendChild(look);
      }
      facts(holder, [[t('Page'), r.page ? page : ''], [t('Address'), r.ip ? ip : ''], [t('Changed'), r.updated ? dateTimeText(r.updated) : '']]);
      // the state, as a row of buttons: the one it is in pressed
      const row = el('div', 'lv-actions');
      row.appendChild(el('span', 'dim', t('State') + ':'));
      for (const st of states) {
        const b = el('button', r.state === st[0] ? 'on' : '', st[1]);
        b.type = 'button';
        b.setAttribute('aria-pressed', r.state === st[0] ? 'true' : 'false');
        b.addEventListener('click', function () { if (r.state !== st[0]) save(r, {state: st[0]}, view); });
        row.appendChild(b);
      }
      holder.appendChild(row);
      holder.appendChild(el('div', 'bugtext', r.text));
      if (r.info) {
        const more = el('details', 'buginfo-box');
        more.appendChild(el('summary', '', t('What the browser sent with it')));
        more.appendChild(el('pre', 'buginfo', r.info));
        holder.appendChild(more);
      }
      const noteForm = el('form', 'lv-note');
      const note = el('textarea');
      note.value = r.note || '';
      note.rows = 2;
      note.placeholder = t('A note for the admins: what was done, or why not');
      note.setAttribute('aria-label', t('Note'));
      const keep = el('button', '', t('Save the note'));
      noteForm.append(note, keep);
      noteForm.addEventListener('submit', async function (e) {
        e.preventDefault();
        if (await save(r, {note: note.value}, view)) toast(t('Saved.'));
      });
      holder.appendChild(noteForm);
      // opened is read, as in a mail client
      if (r.state === 'new') save(r, {state: 'read'}, view);
    };
    const view = listView(box, {
      id: 'reports', key: function (r) { return String(r.id); }, sort: '-at', csv: 'reports',
      search: t('Search the reports'),
      columns: [
        {key: 'at', title: t('Sent'), down: true, cell: function (r) { const s = el('span', '', ago(r.at)); s.title = dateTimeText(r.at); return s; }},
        {key: 'name', title: t('From')},
        {key: 'text', title: t('Report'), cls: 'lv-text', cell: function (r) { return r.text.replace(/\s+/g, ' ').slice(0, 120); }},
        {key: 'page', title: t('Page'), wide: true, cls: 'lv-text', cell: function (r) { return r.page.replace(/^https?:\/\/[^/]+/, ''); }},
        {key: 'state', title: t('State'), value: function (r) { return stateName(r.state); },
          cell: function (r) { return chip(stateName(r.state), r.state === 'new' ? 'new' : r.done ? '' : 'open'); }}
      ],
      filters: [{key: 'state', title: t('State'), all: t('Every state'), value: 'open',
        options: [['open', t('Not resolved or closed')]].concat(states),
        test: function (r, v) { return v === 'open' ? !r.done : r.state === v; }}],
      rowClass: function (r) { return (r.state === 'new' ? 'unread' : '') + (r.done ? ' done' : ''); },
      noun: function (n) { return tn(n, '%d report', '%d reports'); }, empty: t('No reports yet.'),
      detail: detail
    });
    get('/api/bugs').then(function (list) {
      rows = list.map(function (r) { if (!r.state) r.state = r.done ? 'resolved' : 'new'; return r; });
      view.set(rows);
      openCount();
    }).catch(function (err) { view.failed(err.message); });
  }

  // the part of the site a path is in, by its first word: /wiki, /forum, /p
  function sectionOf(path) {
    const first = ((path || '/').split('?')[0].split('/')[1] || '').split('-')[0];
    return first ? '/' + first : '/';
  }
  function sectionOptions(paths) {
    const seen = new Map();
    for (const p of paths) { const s = sectionOf(p); seen.set(s, (seen.get(s) || 0) + 1); }
    return Array.from(seen).sort(function (a, b) { return b[1] - a[1]; }).map(function (x) { return [x[0], x[0] + ' (' + x[1] + ')']; });
  }
  // the address panel, from anywhere an address shows: under Visitors, Address
  function lookUpAddress(ip) {
    // the Visitors tab in front (built now if it never was), then its panel
    if (S.adminTab) S.adminTab('Visitors');
    if (S.showAddress) S.showAddress(ip);
  }
  // an address as a button that opens its panel; marked when it is of concern
  function addressCell(ip, flagged) {
    const b = el('button', 'lv-ip lv-link', ip);
    b.type = 'button';
    b.title = t('Everything about this address');
    b.addEventListener('click', function () { lookUpAddress(ip); });
    if (!flagged) return b;
    const s = el('span', 'lv-flag');
    const mark = chip('!', 'bad');
    mark.title = t('Of concern: see the Of concern tab');
    s.append(b, ' ', mark);
    return s;
  }

  // when, for the visitors' lists: the time for today, the date and time before
  function stamp(at) {
    const d = new Date(at);
    if (isNaN(d)) return at || '';
    return d.toDateString() === new Date().toDateString() ? clock(at) : dateTimeText(at);
  }

  // a link out of the site, for a referer
  function outLink(url) {
    // what a visitor's browser said it came from: a link only when it is a web address
    if (!/^https?:\/\//i.test(url)) return el('span', 'visit-path', url);
    const a = el('a', 'visit-path', url);
    a.href = url; a.target = '_blank'; a.rel = 'noopener noreferrer';
    return a;
  }
  function lookButton(ip) {
    const b = el('button', '', t('Everything about this address'));
    b.type = 'button';
    b.title = t('Its whole story in the period, the guard\'s facts included, under Address');
    b.addEventListener('click', function () { lookUpAddress(ip); });
    return b;
  }

  // a reason the report gives against an address, in words
  function reasonWords(x) {
    const n = x.n || 0;
    switch (x.kind) {
      case 'rate': return tn(n, '%d request in one minute', '%d requests in one minute') + (x.text ? ' (' + stamp(x.text) + ')' : '');
      case 'requests': return tn(n, '%d request', '%d requests');
      case 'browser-crawl': return t('a browser that read %s pages', n.toLocaleString(locale));
      case 'agents': return tn(n, '%d browser string', '%d browser strings');
      case 'pretender': return t('names %s’s crawler from outside its addresses', x.text);
      case 'fake': return t('claims to be %s; its DNS says no', x.text);
      case 'missing': return tn(n, '%d page that is not here', '%d pages that are not here');
      case 'probes': return tn(n, '%d scanner path probed', '%d scanner paths probed');
      case 'refused': return tn(n, 'turned away %d time', 'turned away %d times');
      case 'errors': return tn(n, '%d server error', '%d server errors');
      case 'members': return tn(n, 'signed in as %d member', 'signed in as %d members');
    }
    return x.kind;
  }
  function reasonKinds() {
    return {rate: t('Pace'), requests: t('Many requests'), 'browser-crawl': t('A browser crawling'), agents: t('Browser strings'),
      pretender: t('Pretending to be a crawler'), fake: t('Failed its DNS check'), missing: t('Missing pages'), probes: t('Probing'),
      refused: t('Turned away'), errors: t('Server errors'), members: t('Many members')};
  }
  // a status code as a small mark: errors stand out, a line from before the codes shows none
  function statusCell(code) {
    if (!code) return el('span', 'dim', '–');
    return chip(String(code), code >= 500 ? 'bad' : code >= 400 ? 'open' : '');
  }
  function msCell(ms) {
    if (ms === undefined || ms === null) return '';
    return el('span', ms >= 2000 ? 'bot-bad' : 'dim', ms >= 1000 ? (ms / 1000).toFixed(1) + ' s' : ms + ' ms');
  }

  // the window in bars, people apart from bots apart from errors, each row to
  // its own scale: bots outnumber people a hundred to one here, and one scale
  // would flatten the people to nothing
  function timelineChart(box, tl, compact) {
    if (!tl || !tl.pages || !tl.pages.length) return;
    const step = tl.step, start = new Date(tl.start).getTime(), n = tl.pages.length;
    const iso = function (ms) { return new Date(ms).toISOString(); };
    const when = function (i) {
      const a = start + i * step * 1000, b = a + step * 1000 - 1000;
      if (step >= 86400) return dateText(iso(a).slice(0, 10));
      return (step >= 7200 ? dateTimeText(iso(a)) : stamp(iso(a))) + ' – ' + clock(iso(b));
    };
    const stepWords = step < 3600 ? tn(step / 60, 'a bar a minute', 'a bar every %d minutes') :
      step < 86400 ? tn(step / 3600, 'a bar an hour', 'a bar every %d hours') : tn(step / 86400, 'a bar a day', 'a bar every %d days');
    const rows = [
      {title: t('Pages people read, and the rest they asked for'), series: [[tl.pages, 'tl-pages', t('pages')], [tl.other, 'tl-other', t('other requests')]]},
      {title: t('Bot requests'), series: [[tl.bots, 'tl-bots', t('bot requests')]]},
      {title: t('Refused, not here, or failed'), series: [[tl.errors, 'tl-errors', t('errors')]]}
    ];
    const wrap = el('div', 'timeline' + (compact ? ' compact' : ''));
    for (const row of rows) {
      if (!row.series.some(function (ser) { return ser[0] && ser[0].some(Boolean); })) continue;
      let most = 1, total = 0;
      for (let i = 0; i < n; i++) {
        let sum = 0;
        for (const ser of row.series) sum += (ser[0] || [])[i] || 0;
        if (sum > most) most = sum;
        total += sum;
      }
      const head = el('div', 'tl-head');
      head.append(el('span', '', row.title), el('span', 'num', total.toLocaleString(locale)));
      wrap.appendChild(head);
      const bars = el('div', 'days tl-row');
      for (let i = 0; i < n; i++) {
        const col = el('b');
        const words = [];
        for (const ser of row.series) {
          const v = (ser[0] || [])[i] || 0;
          const seg = el('i', ser[1]);
          seg.style.height = Math.round(60 * v / most) + 'px';
          col.appendChild(seg);
          words.push(v.toLocaleString(locale) + ' ' + ser[2]);
        }
        col.title = when(i) + ': ' + words.join(', ');
        bars.appendChild(col);
      }
      wrap.appendChild(bars);
    }
    const cap = el('div', 'days-caption');
    cap.append(el('span', '', dateTimeText(tl.start)), el('span', '', stepWords), el('span', '', dateTimeText(iso(start + n * step * 1000 - 1000))));
    wrap.appendChild(cap);
    box.appendChild(wrap);
  }

  // One address's whole story in the window (/api/admin/visitors/address):
  // what it is, how it behaved, the guard's facts and buttons, its browsers,
  // members, pages, statuses, timeline and the last of its requests.
  function addressPanel(ip, holder, period) {
    // period: the window, or a function giving the window shown now (a
    // button pressed after the picker changed asks for the new one)
    const win = typeof period === 'function' ? period() : period;
    const again = function () { addressPanel(ip, holder, period); };
    waiting(holder, t('Reading the log…'));
    // an admin who manages blocks but may not see visitors still gets the guard's facts
    const guardOnly = function (err) {
      if (!S.adminCan || S.adminCan('view-visitors') || !S.adminCan('manage-blocks')) throw err;
      return get('/api/blocks/why?ip=' + enc(ip)).then(function (g) { return {ip: g.ip, address: {requests: 0, reasons: []}, guard: g}; });
    };
    get('/api/admin/visitors/address?ip=' + enc(ip) + '&from=' + enc(win.from) + '&to=' + enc(win.to)).catch(guardOnly).then(function (r) {
      holder.replaceChildren();
      const a = r.address, g = r.guard;
      const head = el('div', 'lv-detail-head');
      head.appendChild(el('b', '', r.ip));
      if (g && g.host) head.appendChild(el('span', 'dim', g.host));
      // what the rest of the internet knows about it, in a new tab; noreferrer
      // so those sites are not told about this admin page
      const look = el('span', 'ip-lookups');
      for (const x of [['AbuseIPDB', 'https://www.abuseipdb.com/check/', t('Abuse reports about this address')],
                       ['GreyNoise', 'https://viz.greynoise.io/ip/', t('Whether it scans the whole internet')],
                       ['ipinfo', 'https://ipinfo.io/', t('Who the address belongs to')]]) {
        const a2 = link(x[1] + enc(r.ip), '', x[0]);
        a2.target = '_blank';
        a2.rel = 'noopener noreferrer';
        a2.title = x[2];
        look.appendChild(a2);
      }
      head.appendChild(look);
      const crawlerText = a.crawler ? a.crawler + (a.company ? ' · ' + a.company : '')
        : g && g.crawler_name ? g.crawler_name + (g.company ? ' · ' + g.company : '')
        : g && g.crawler ? t('a search engine’s crawler') : '';
      if (crawlerText) head.appendChild(chip(crawlerText, 'admin'));
      else if (a.bot) head.appendChild(chip(a.bot, ''));
      if (g && g.local) head.appendChild(chip(t('This network'), 'admin'));
      else if (g && g.allowed) head.appendChild(chip(t('Allowed'), 'admin'));
      if (g && g.block && g.block.active) head.appendChild(chip(g.block.for_good ? t('Blocked for good') : t('Blocked now'), 'bad'));
      if (a.score > 0) head.appendChild(chip(t('Of concern'), 'open'));
      holder.appendChild(head);
      if (!a.requests) holder.appendChild(el('p', 'dim', S.adminCan && S.adminCan('view-visitors') ? t('Nothing from this address in the period.') : t('The log is for those who may view visitors.')));
      else {
        const tiles = el('div', 'tiles-admin');
        stat(tiles, a.requests, t('Requests'), t('%s to %s', stamp(a.first), stamp(a.last)));
        stat(tiles, a.pages, t('Pages'));
        if (a.polls) stat(tiles, a.polls, t('Open tab checks'), t('a tab left open, asking what is new'));
        stat(tiles, a.peak, t('Busiest minute'), a.peak_at ? stamp(a.peak_at) : '', a.peak >= 120 && !a.crawler ? 'warn' : '');
        stat(tiles, a.agents, t('Browser strings'), '', a.agents >= 5 && !a.crawler ? 'warn' : '');
        stat(tiles, a.missing, t('Not here (404)'), a.probes ? tn(a.probes, '%d scanner path', '%d scanner paths') : '', a.missing >= 30 || a.probes ? 'warn' : '');
        stat(tiles, a.refused, t('Turned away'), a.errors ? tn(a.errors, '%d server error', '%d server errors') : '', a.refused >= 20 ? 'warn' : '');
        holder.appendChild(tiles);
      }
      if (a.reasons && a.reasons.length) {
        const p = el('p', 'lv-reasons');
        for (const x of a.reasons) p.appendChild(chip(reasonWords(x), 'open'));
        holder.appendChild(p);
      }
      // the guard's facts, and what an admin may do about the address
      const list = el('ul', 'block-facts');
      if (!g) list.appendChild(el('li', 'dim', t('The guard’s facts could not be read.')));
      else {
        const kinds = strikeKinds();
        if (g.local) list.appendChild(el('li', 'good', t('This network: never blocked or limited.')));
        else if (g.allowed) list.appendChild(el('li', 'good', t('On the allowed list (Settings, allowed_ips): never blocked or limited.')));
        if (g.crawler) list.appendChild(el('li', 'good', t('A published crawler, by the addresses its company publishes or its name pointing back to the address: never limited or blocked by the guard.')));
        if (g.block && g.block.active) {
          list.appendChild(el('li', 'bad', g.block.for_good ? t('Blocked for good: %s (%s).', g.block.reason, dateTimeText(g.block.when))
            : t('Blocked until %s: %s. Blocked %d times so far.', dateTimeText(g.block.until), g.block.reason, g.block.times)));
        } else if (g.block) {
          list.appendChild(el('li', '', t('Not blocked now. Last block: %s, over since %s; blocked %d times so far.', g.block.reason, dateTimeText(g.block.until), g.block.times)));
        } else {
          list.appendChild(el('li', '', t('Not blocked, and never has been.')));
        }
        // what AbuseIPDB said when the site looked it up (unit SiteAbuse)
        if (g.abuse) {
          const ab = g.abuse;
          const words = t('AbuseIPDB: %d%% confidence of abuse, %s from other sites (looked up %s).', ab.score,
            tn(ab.reports, '%d report', '%d reports'), dateTimeText(ab.checked)) +
            (ab.usage || ab.isp ? ' ' + [ab.usage, ab.isp, ab.country].filter(Boolean).join(', ') + '.' : '') +
            (ab.reported ? ' ' + t('We reported it %s.', dateTimeText(ab.reported)) : '');
          list.appendChild(el('li', ab.score >= 75 ? 'bad' : '', words));
        }
        if (g.strikes && g.strikes.length) {
          const li = el('li', '', t('In the last day:') + ' ');
          li.appendChild(el('span', '', g.strikes.map(function (x) { return (kinds[x.kind] || x.kind) + ' × ' + x.count; }).join(', ')));
          list.appendChild(li);
        } else {
          list.appendChild(el('li', 'dim', t('Nothing counted against it in the last day.')));
        }
      }
      holder.appendChild(list);
      const acts = el('div', 'lv-actions');
      blockButtons(acts, r.ip, g && g.block, again, crawlerText);
      if (acts.childNodes.length) holder.appendChild(acts);
      if (!a.requests) return;
      timelineChart(holder, r.timeline, true);
      const two = el('div', 'visit-two');
      const left = el('div'), right = el('div');
      two.append(left, right);
      holder.appendChild(two);
      left.appendChild(el('h3', '', r.paths_count > r.paths.length ? t('What it asked for most (%s paths in all)', r.paths_count.toLocaleString(locale)) : t('What it asked for')));
      bars(left, r.paths.slice(0, 14).map(function (x) { let name = x.path; try { name = decodeURIComponent(name); } catch (e) { } return {name: name || '/', value: x.count}; }),
        function (n) { return tn(n, '%d request', '%d requests'); });
      right.appendChild(el('h3', '', t('How it was answered')));
      const codes = Object.keys(r.statuses || {}).sort(function (x, y) { return r.statuses[y] - r.statuses[x]; });
      bars(right, codes.map(function (c) { return {name: c === '0' ? t('before the codes were logged') : c, value: r.statuses[c], other: c === '0' || c < '400'}; }),
        function (n) { return tn(n, '%d request', '%d requests'); });
      right.appendChild(el('h3', '', t('Parts of the site')));
      const parts = Object.keys(r.parts || {}).sort(function (x, y) { return r.parts[y] - r.parts[x]; });
      bars(right, parts.map(function (k) { return {name: partLabel(k), value: r.parts[k]}; }), function (n) { return tn(n, '%d request', '%d requests'); });
      if (r.referers && r.referers.length) {
        right.appendChild(el('h3', '', t('Came by links from')));
        bars(right, r.referers.slice(0, 8).map(function (x) { return {name: x.host, value: x.requests}; }), function (n) { return tn(n, '%d request', '%d requests'); });
      }
      holder.appendChild(el('h3', '', t('Browser strings it used')));
      listView(holder, {
        id: 'v-addr-agents', key: function (x) { return x.agent; }, sort: '-requests', search: false, rows: r.agents,
        columns: [
          {key: 'browser', title: t('Browser or bot'), value: function (x) { return x.bot || browserOf(x.agent); },
            cell: function (x) { const s2 = el('span', '', x.bot || browserOf(x.agent)); if (x.claims && !a.crawler) { s2.append(' ', chip(t('claims %s', x.claims), 'bad')); } return s2; }},
          {key: 'requests', title: t('Requests'), num: true},
          {key: 'last', title: t('Last seen'), down: true, cell: function (x) { return stamp(x.last); }},
          {key: 'agent', title: t('The whole string'), wide: true, cls: 'lv-text'}
        ],
        noun: function (n) { return tn(n, '%d browser string', '%d browser strings'); }
      });
      if (r.members && r.members.length) {
        holder.appendChild(el('h3', '', t('Signed in from it as')));
        const ul = el('ul', 'lv-paths');
        for (const m of r.members) { const li = el('li'); li.append(link('/u/' + enc(m.name), '', m.name), ' ', el('span', 'dim', tn(m.requests, '%d request', '%d requests') + ', ' + stamp(m.last))); ul.appendChild(li); }
        holder.appendChild(ul);
      }
      holder.appendChild(el('h3', '', t('Its last requests in the period')));
      listView(holder, {
        id: 'v-addr-trail', key: function (l) { return l.at + l.path; }, sort: '-at', search: t('Filter its requests'), page: 100, rows: r.trail,
        csv: 'address-' + r.ip.replace(/[^0-9a-z]/gi, '_'),
        columns: [
          {key: 'at', title: t('When'), down: true, cell: function (l) { return stamp(l.at); }},
          {key: 'method', title: t('Method'), wide: true},
          {key: 'path', title: t('Page'), cell: function (l) { return pageLink(l.path); }},
          {key: 'status', title: t('Status'), num: true, cell: function (l) { return statusCell(l.status); }},
          {key: 'ms', title: t('Took'), num: true, wide: true, cell: function (l) { return msCell(l.ms); }},
          {key: 'member', title: t('Member'), wide: true, cell: function (l) { return l.member ? link('/u/' + enc(l.member), '', l.member) : ''; }},
          {key: 'browser', title: t('Browser'), wide: true, value: function (l) { return browserOf(l.agent); }}
        ],
        filters: [{key: 'kind', title: t('Which'), all: t('Every request'), options: [['pages', t('Pages')], ['other', t('Everything else')], ['errors', t('Errors and refusals')]],
          test: function (l, k) { return k === 'errors' ? l.status >= 400 : (l.method === 'GET' && isPagePath(l.path) ? 'pages' : 'other') === k; }}],
        noun: function (n) { return tn(n, '%d request', '%d requests'); }
      });
    }).catch(function (err) {
      const why = err && err.message && err.message.length < 300 && !/[<>]/.test(err.message) ? ' ' + err.message : '';
      holder.replaceChildren(el('p', 'notice', t('The address could not be looked up.') + why));
    });
  }

  // one person's period: who, from where, and every request they made with that browser
  function personDetail(v, holder, period) {
    const head = el('div', 'lv-detail-head');
    head.appendChild(el('b', '', v.ip));
    if (v.member) head.appendChild(link('/u/' + enc(v.member), '', v.member));
    head.appendChild(el('span', 'dim', browserOf(v.agent)));
    if (v.flagged) head.appendChild(chip(t('Of concern'), 'open'));
    holder.appendChild(head);
    facts(holder, [[t('First seen'), stamp(v.first)], [t('Last seen'), stamp(v.last)], [t('Pages'), v.pages], [t('Requests'), v.requests], [t('Open tab checks'), v.polls || 0],
      [t('Came in on'), pageLink(v.entry)], [t('From'), v.referer ? outLink(v.referer) : t('typed in, a bookmark, or not said')], [t('Browser'), v.agent]]);
    const acts = el('div', 'lv-actions');
    acts.appendChild(lookButton(v.ip));
    holder.appendChild(acts);
    holder.appendChild(el('h3', '', t('What they asked for in the period')));
    const trail = el('div');
    holder.appendChild(trail);
    waiting(trail, t('Reading the log…'));
    get('/api/admin/access?n=1000&ip=' + enc(v.ip) + '&agent=' + enc(v.agent) + '&from=' + enc(period.from) + '&to=' + enc(period.to)).then(function (a) {
      trail.replaceChildren();
      listView(trail, {
        id: 'v-trail', key: function (l) { return l.at + l.path; }, sort: '-at', search: t('Filter their requests'), page: 200,
        rows: a.lines,
        columns: [
          {key: 'at', title: t('When'), down: true, cell: function (l) { return stamp(l.at); }},
          {key: 'method', title: t('Method'), wide: true},
          {key: 'path', title: t('Page'), cell: function (l) { return pageLink(l.path); }},
          {key: 'status', title: t('Status'), num: true, cell: function (l) { return statusCell(l.status); }},
          {key: 'ms', title: t('Took'), num: true, wide: true, cell: function (l) { return msCell(l.ms); }},
          {key: 'from', title: t('From'), wide: true, value: function (l) { return hostOf(l.referer); }}
        ],
        filters: [{key: 'kind', title: t('Which'), all: t('Every request'), value: 'people', options: [['people', t('Pages they read')], ['other', t('Everything else')]],
          test: function (l, k) { return (l.method === 'GET' && isPagePath(l.path) ? 'people' : 'other') === k; }}],
        noun: function (n) { return tn(n, '%d request', '%d requests'); }
      });
    }).catch(function () { trail.replaceChildren(el('p', 'dim', t('The access log could not be read.'))); });
  }

  // a part of the site by its registered name, in words where they are known
  // (a site on top names its own parts and search places in Extras.places)
  function partLabel(part) {
    return Extras.places[part] || {chat: t('Chat'), api: t('API'), static: t('Static'), other: t('Other')}[part] ||
      (part.charAt(0).toUpperCase() + part.slice(1));
  }

  function placeName(where) { return where === 'chat' ? t('Chat') : Extras.places[where] || where; }

  // the day's report in sub-tabs: people apart from bots, what they read,
  // where from, the crawlers and bots, the latest requests
  function drawVisitReport(subs, r, pick, hideMe, hiddenSet) {
    const keys = ['overview', 'people', 'pages', 'searches', 'members', 'crawlers', 'bots', 'concerns', 'latest'];
    for (const k of keys) subs.holder(k).replaceChildren();
    if (!r.found) {
      for (const k of keys) subs.holder(k).appendChild(el('p', 'dim', t('There is no log for that period.')));
      return;
    }
    // the lists stop at the thousand who read most; the badges count everyone
    subs.count('people', r.visitors_count ?? r.visitors.length);
    subs.count('pages', r.pages_count ?? r.pages.length);
    subs.count('searches', r.searches.length);
    subs.count('members', r.members.length);
    subs.count('crawlers', r.crawlers.length);
    subs.count('bots', r.bots.length);
    subs.count('concerns', r.concerns_count || 0);

    drawVisitOverview(subs, r, hideMe);

    drawPeople(subs.holder('people'), r);

    let box = subs.holder('pages');
    if (r.pages_count > r.pages.length)
      box.appendChild(el('p', 'hint', t('The %s pages read most are listed, of %s.', r.pages.length.toLocaleString(locale), r.pages_count.toLocaleString(locale))));
    listView(box, {
      id: 'v-pages', key: function (p) { return p.path; }, sort: '-views', csv: 'pages-' + windowName(r), search: t('Filter pages'), rows: r.pages,
      columns: [
        {key: 'path', title: t('Page'), cell: function (p) { return pageLink(p.path); }},
        {key: 'views', title: t('Views'), num: true},
        {key: 'people', title: t('People'), num: true}
      ],
      filters: [{key: 'section', title: t('Part of the site'), all: t('The whole site'), test: function (p, k) { return sectionOf(p.path) === k; },
        options: function (rows) { return sectionOptions(rows.map(function (p) { return p.path; })); }}],
      noun: function (n) { return tn(n, '%d page', '%d pages'); }, empty: t('Nothing yet.')
    });

    box = subs.holder('searches');
    box.appendChild(el('p', 'hint', t('What people typed in the search boxes and pages. A box that searches as one types counts once, with the words as they ended.') +
      (hideMe ? ' ' + t('Your own searches are left out while Hide my visits is ticked.') : '')));
    listView(box, {
      id: 'v-searches', key: function (s) { return s.where + s.words; }, sort: '-count', search: t('Filter searches'), rows: r.searches,
      columns: [
        {key: 'where', title: t('Where'), value: function (s) { return placeName(s.where); }},
        {key: 'words', title: t('Words')},
        {key: 'count', title: t('Times'), num: true},
        {key: 'last', title: t('Last searched'), down: true, cell: function (s) { return stamp(s.last); }}
      ],
      filters: [{key: 'where', title: t('Where'), all: t('Everywhere'), test: function (s, k) { return s.where === k; },
        options: function (rows) { return Array.from(new Set(rows.map(function (s) { return s.where; }))).map(function (w) { return [w, placeName(w)]; }); }}],
      noun: function (n) { return tn(n, '%d search', '%d searches'); }, empty: t('Nobody searched in that period.')
    });

    box = subs.holder('members');
    listView(box, {
      id: 'v-members', key: function (m) { return m.name; }, sort: '-pages', search: false, rows: r.members,
      columns: [
        {key: 'name', title: t('Member'), cell: function (m) { return link('/u/' + enc(m.name), '', m.name); }},
        {key: 'pages', title: t('Pages'), num: true},
        {key: 'last', title: t('Last seen'), down: true, cell: function (m) { return stamp(m.last); }}
      ],
      noun: function (n) { return tn(n, '%d member', '%d members'); }, empty: t('No member was signed in during that period.')
    });

    drawCrawlers(subs.holder('crawlers'), r);
    drawBots(subs.holder('bots'), r);
  }

  function drawVisitOverview(subs, r, hideMe) {
    // the overview: the numbers, the hours, where people came from and what they read most
    const box = subs.holder('overview');
    const tiles = el('div', 'tiles-admin');
    stat(tiles, r.people, t('People'), t('a browser that took the page whole, not a bot'));
    stat(tiles, r.people_pages, t('Pages they read'));
    stat(tiles, r.bot_requests, t('Bot requests'), tn(r.bots.length, '%d bot or crawler', '%d bots and crawlers'));
    stat(tiles, r.members_seen, t('Members signed in'));
    const worry = stat(tiles, r.concerns_count || 0, t('Addresses of concern'), tn(r.addresses || 0, 'of %d address', 'of %d addresses'), r.concerns_count ? 'warn' : '');
    worry.style.cursor = 'pointer';
    worry.title = t('See the Of concern tab');
    worry.addEventListener('click', function () { subs.select('concerns'); });
    if (hideMe) stat(tiles, r.hidden_requests, t('Your requests left out'), tn(r.hidden_addresses, 'from %d address', 'from %d addresses'));
    box.appendChild(tiles);
    const byDay = r.by_day || [];
    if (byDay.length > 1) {
      const top = Math.max.apply(null, byDay.map(function (d) { return d.pages; }).concat([1]));
      const days = el('div', 'days');
      for (const d of byDay) {
        const bar = el('i'); bar.style.height = Math.max(2, Math.round(66 * d.pages / top)) + 'px';
        bar.title = dateText(d.day) + ': ' + tn(d.pages, '%d page', '%d pages') + ', ' + tn(d.people, '%d person', '%d people');
        days.appendChild(bar);
      }
      box.appendChild(days);
      const dc = el('div', 'days-caption');
      dc.append(el('span', '', dateText(byDay[0].day)), el('span', '', t('pages people read, day by day')), el('span', '', dateText(byDay[byDay.length - 1].day)));
      box.appendChild(dc);
    }
    timelineChart(box, r.timeline);
    const two = el('div', 'visit-two');
    const left = el('div'), right = el('div');
    two.append(left, right);
    box.appendChild(two);
    left.appendChild(el('h3', '', t('What people read most')));
    if (r.pages.length) bars(left, r.pages.slice(0, 12).map(function (p) { let n = p.path; try { n = decodeURIComponent(n); } catch (e) { } return {name: n, value: p.views}; }),
      function (n) { return tn(n, '%d view', '%d views'); });
    else left.appendChild(el('p', 'dim', t('Nothing yet.')));
    right.appendChild(el('h3', '', t('Where they came from')));
    if (r.referers.length) bars(right, r.referers.slice(0, 12).map(function (x) { return {name: x.host, value: x.views}; }), function (n) { return tn(n, '%d page', '%d pages'); });
    else right.appendChild(el('p', 'dim', t('Nobody came by a link in that period.')));
    if (r.searches.length) {
      box.appendChild(el('h3', '', t('What they searched for')));
      bars(box, r.searches.slice(0, 10).map(function (x) { return {name: x.words + '  ·  ' + (placeName(x.where)), value: x.count}; }),
        function (n) { return tn(n, '%d time', '%d times'); });
    }
  }

  function drawPeople(box, r) {
    box.appendChild(el('p', 'hint', t('Each address with one browser. Bots are counted apart, under Bots. Pick a row for everything they asked for.')));
    if (r.visitors_count > r.visitors.length)
      box.appendChild(el('p', 'hint', t('The %s who read the most are listed, of %s.', r.visitors.length.toLocaleString(locale), r.visitors_count.toLocaleString(locale))));
    listView(box, {
      id: 'v-people', key: function (v) { return v.ip + ' ' + v.agent; }, sort: '-pages', csv: 'people-' + windowName(r),
      search: t('Filter by address, page, site or member'), rows: r.visitors,
      columns: [
        {key: 'last', title: t('Last seen'), down: true, cell: function (v) { const s = el('span', '', stamp(v.last)); s.title = t('First seen %s', stamp(v.first)); return s; }},
        {key: 'ip', title: t('Address'), cell: function (v) { return addressCell(v.ip, v.flagged); }},
        {key: 'member', title: t('Member'), cell: function (v) { return v.member ? link('/u/' + enc(v.member), '', v.member) : ''; }},
        {key: 'pages', title: t('Pages'), num: true},
        {key: 'requests', title: t('Requests'), num: true, wide: true},
        {key: 'entry', title: t('Came in on'), cell: function (v) { return pageLink(v.entry); }},
        {key: 'from', title: t('From'), wide: true, value: function (v) { return hostOf(v.referer); }},
        {key: 'browser', title: t('Browser'), wide: true, value: function (v) { return browserOf(v.agent); }}
      ],
      filters: [
        {key: 'who', title: t('Who'), all: t('Everybody'), options: [['members', t('Members signed in')], ['guests', t('Not signed in')], ['concern', t('Of concern')]],
          test: function (v, k) { return k === 'members' ? !!v.member : k === 'guests' ? !v.member : v.flagged > 0; }},
        {key: 'browser', title: t('Browser'), all: t('Every browser'), test: function (v, k) { return browserOf(v.agent) === k; },
          options: function (rows) { return Array.from(new Set(rows.map(function (v) { return browserOf(v.agent); }))).sort().map(function (b) { return [b, b]; }); }},
        {key: 'from', title: t('From'), all: t('From anywhere'), test: function (v, k) { return k === '-' ? !hostOf(v.referer) : hostOf(v.referer) === k; },
          options: function (rows) {
            return [['-', t('No link (typed in or a bookmark)')]].concat(Array.from(new Set(rows.map(function (v) { return hostOf(v.referer); }).filter(Boolean))).sort().map(function (h) { return [h, h]; }));
          }}
      ],
      noun: function (n) { return tn(n, '%d person', '%d people'); }, empty: t('Nobody read a page in that period.'),
      detail: function (v, holder) { personDetail(v, holder, {from: r.from, to: r.to}); }
    });
  }

  function drawCrawlers(box, r) {
    box.appendChild(el('p', 'hint', tn(r.crawler_sources.length,
      'Found by the address ranges their companies publish (%d list, read once a day): a request from those addresses is that company\'s crawler, whatever its browser string says.',
      'Found by the address ranges their companies publish (%d lists, read once a day): a request from those addresses is that company\'s crawler, whatever its browser string says.')));
    // the parts of the site the crawlers read, as the units register them: the three
    // they read most by name, the rest together, four colors in all
    const totals = new Map();
    for (const c of r.crawlers) for (const k in (c.parts || {})) totals.set(k, (totals.get(k) || 0) + c.parts[k]);
    const named = Array.from(totals).filter(function (x) { return x[0] !== 'other'; }).sort(function (a, b) { return b[1] - a[1]; }).slice(0, 3).map(function (x) { return x[0]; });
    const parts = named.map(function (k) { return [k, partLabel(k)]; }).concat([['other', t('Other')]]);
    const partOf = function (c, k) {
      if (k !== 'other') return (c.parts || {})[k] || 0;
      let n = 0;
      for (const x in (c.parts || {})) if (named.indexOf(x) < 0) n += c.parts[x];
      return n;
    };
    if (!r.crawlers.length) box.appendChild(el('p', 'dim', t('No known crawler came in that period.')));
    else {
      // what each read, part by part: one bar a crawler, the parts side by side in it
      const legend = el('div', 'crawl-legend');
      parts.forEach(function (p, i) { const k = el('span'); k.append(el('i', 'crawl-c' + (i + 1)), ' ' + p[1]); legend.appendChild(k); });
      box.appendChild(legend);
      const most = Math.max.apply(null, r.crawlers.map(function (c) { return c.requests; }).concat([1]));
      const chart = el('div', 'crawl-chart');
      for (const c of r.crawlers.slice(0, 20)) {
        const name = el('span', 'name', c.name); name.title = c.company;
        const bar = el('span', 'crawl-bar');
        bar.style.width = Math.max(2, Math.round(100 * c.requests / most)) + '%';
        parts.forEach(function (p, i) {
          if (!partOf(c, p[0])) return;
          const seg = el('i', 'crawl-c' + (i + 1));
          seg.style.flexGrow = partOf(c, p[0]);
          seg.title = p[1] + ': ' + tn(partOf(c, p[0]), '%d request', '%d requests');
          bar.appendChild(seg);
        });
        const track = el('span', 'crawl-track'); track.appendChild(bar);
        const num = el('span', 'num', c.requests.toLocaleString(locale));
        num.title = parts.map(function (p) { return p[1] + ' ' + partOf(c, p[0]); }).join(' · ');
        chart.append(name, track, num);
      }
      box.appendChild(chart);
      listView(box, {
        id: 'v-crawlers', key: function (c) { return c.name; }, sort: '-requests', csv: 'crawlers-' + windowName(r), search: t('Filter crawlers'), rows: r.crawlers,
        columns: [
          {key: 'name', title: t('Crawler')}, {key: 'company', title: t('Company')},
          {key: 'requests', title: t('Requests'), num: true},
        ].concat(parts.map(function (p) { return {key: 'part-' + p[0], title: p[1], num: true, wide: true, value: function (c) { return partOf(c, p[0]); }}; })).concat([
          {key: 'addresses', title: t('Addresses'), num: true}, {key: 'last', title: t('Last seen'), down: true, cell: function (c) { return stamp(c.last); }}
        ]),
        filters: [{key: 'company', title: t('Company'), all: t('Every company'), test: function (c, k) { return c.company === k; },
          options: function (rows) { return Array.from(new Set(rows.map(function (c) { return c.company; }))).sort().map(function (x) { return [x, x]; }); }}],
        noun: function (n) { return tn(n, '%d crawler', '%d crawlers'); },
        detail: function (c, holder) {
          const head = el('div', 'lv-detail-head');
          head.append(el('b', '', c.name), el('span', 'dim', c.company));
          holder.appendChild(head);
          facts(holder, [[t('Requests'), c.requests.toLocaleString(locale)], [t('Addresses'), c.addresses], [t('Last seen'), stamp(c.last)],
            [t('By part'), Object.keys(c.parts || {}).map(function (k) { return partLabel(k) + ' ' + c.parts[k]; }).join(' · ')]]);
          holder.appendChild(el('h3', '', t('What it read most')));
          bars(holder, c.paths.map(function (p) { return {name: p.path || '/', value: p.count}; }), function (n) { return tn(n, '%d request', '%d requests'); });
        }
      });
    }
    // two weeks of them, a row a crawler, a cell a day, darker for more
    const cd = r.crawler_days;
    if (cd && cd.series.length) {
      box.appendChild(el('h3', '', t('Day by day')));
      const peak = Math.max.apply(null, cd.series.map(function (s) { return Math.max.apply(null, s.counts); }).concat([1]));
      const wrap = el('div', 'gridwrap'), table = el('table', 'grid crawl-days'), head = el('tr');
      head.appendChild(el('th', '', t('Crawler')));
      for (const d of cd.days) { const th = el('th', '', dateText(d).replace(/[-/.]?\d{4}[-/.]?/, '')); th.title = dateText(d); head.appendChild(th); }
      table.appendChild(head);
      const order = cd.series.slice().sort(function (a, b) { return b.counts.reduce(function (x, y) { return x + y; }, 0) - a.counts.reduce(function (x, y) { return x + y; }, 0); });
      for (const s of order) {
        const row = el('tr');
        row.appendChild(el('td', 'name', s.name));
        s.counts.forEach(function (n, i) {
          const cell = el('td', 'heat', n ? n.toLocaleString(locale) : '');
          // a log scale: a crawler that came ten times still shows
          const share = n ? Math.round(12 + 88 * Math.log(1 + n) / Math.log(1 + peak)) : 0;
          cell.style.setProperty('--share', share + '%');
          if (share > 55) cell.classList.add('deep');
          cell.title = s.name + ', ' + dateText(cd.days[i]) + ': ' + tn(n, '%d request', '%d requests');
          row.appendChild(cell);
        });
        table.appendChild(row);
      }
      wrap.appendChild(table); box.appendChild(wrap);
    }
    if (r.pretenders.length) {
      box.appendChild(el('h3', '', t('Pretending to be one of them')));
      box.appendChild(el('p', 'hint', t('These name a known crawler in their browser string but come from outside its company\'s published addresses.')));
      listView(box, {
        id: 'v-pretenders', key: function (p) { return p.name; }, sort: '-requests', search: false, rows: r.pretenders,
        columns: [
          {key: 'name', title: t('Says it is')}, {key: 'company', title: t('Company')}, {key: 'requests', title: t('Requests'), num: true},
          {key: 'addresses', title: t('Addresses'), num: true}, {key: 'last', title: t('Last seen'), down: true, cell: function (p) { return stamp(p.last); }},
          {key: 'sample', title: t('For example'), wide: true, cell: function (p) { return addressCell(p.sample); }}
        ],
        noun: function (n) { return tn(n, '%d pretender', '%d pretenders'); },
        detail: function (p, holder) {
          facts(holder, [[t('Says it is'), p.name + ' (' + p.company + ')'], [t('Requests'), p.requests], [t('For example'), addressCell(p.sample)]]);
        }
      });
    }
    if (r.crawler_sources.length) {
      const lists = el('details', 'crawl-sources');
      lists.appendChild(el('summary', '', t('The published lists')));
      const holder = el('div');
      lists.appendChild(holder);
      box.appendChild(lists);
      listView(holder, {
        id: 'v-sources', key: function (s) { return s.url; }, sort: 'company', search: false, rows: r.crawler_sources,
        columns: [
          {key: 'company', title: t('Company')},
          {key: 'name', title: t('Crawler'), cell: function (s) { const a = el('a', '', s.name); a.href = s.url; a.target = '_blank'; a.rel = 'noopener'; return a; }},
          {key: 'ranges', title: t('Ranges'), num: true},
          {key: 'created', title: t('List dated'), wide: true, cell: function (s) { return s.created ? dateText(s.created) : ''; }},
          {key: 'fetched', title: t('Read'), wide: true, cell: function (s) { return s.fetched ? dateTimeText(s.fetched) : ''; }},
          {key: 'error', title: t('Problem')}
        ],
        noun: function (n) { return tn(n, '%d list', '%d lists'); }
      });
    }
  }

  function drawBots(box, r) {
    box.appendChild(el('p', 'hint', t('Known by the name in their browser string, or because they asked for robots.txt. The big search engines are checked against their DNS: one that only claims the name shows as not verified.')));
    const checks = {listed: '✓ ' + t('Published address'), verified: '✓ ' + t('Verified'), unverified: t('Not verified')};
    listView(box, {
      id: 'v-bots', key: function (b) { return b.name; }, sort: '-requests', csv: 'bots-' + windowName(r), search: t('Filter bots'), rows: r.bots,
      columns: [
        {key: 'name', title: t('Bot')},
        {key: 'check', title: t('Checked'), value: function (b) { return checks[b.check] || ''; },
          cell: function (b) { return b.check ? el('span', b.check === 'unverified' ? 'bot-bad' : 'bot-ok', checks[b.check] || b.check) : ''; }},
        {key: 'requests', title: t('Requests'), num: true},
        {key: 'addresses', title: t('Addresses'), num: true},
        {key: 'last', title: t('Last seen'), down: true, cell: function (b) { return stamp(b.last); }},
        {key: 'paths', title: t('Pages it asked for most'), wide: true, nosort: true, cls: 'lv-text', value: function (b) { return b.paths.join(' '); },
          cell: function (b) { return el('span', 'dim', b.paths.slice(0, 3).map(function (p) { return p || '/'; }).join('  ·  ')); }}
      ],
      filters: [{key: 'check', title: t('Checked'), all: t('Checked or not'), options: [['listed', t('Published address')], ['verified', t('Verified')], ['unverified', t('Not verified')], ['-', t('Not checked')]],
        test: function (b, k) { return k === '-' ? !b.check : b.check === k; }}],
      noun: function (n) { return tn(n, '%d bot', '%d bots'); }, empty: t('No bot came in that period.'),
      detail: function (b, holder) {
        const head = el('div', 'lv-detail-head');
        head.append(el('b', '', b.name), b.check ? el('span', b.check === 'unverified' ? 'bot-bad' : 'bot-ok', checks[b.check]) : '');
        holder.appendChild(head);
        facts(holder, [[t('Requests'), b.requests.toLocaleString(locale)], [t('Addresses'), b.addresses], [t('For example'), b.sample ? addressCell(b.sample) : ''], [t('Last seen'), stamp(b.last)]]);
        holder.appendChild(el('h3', '', t('Pages it asked for most')));
        const ul = el('ul', 'lv-paths');
        for (const p of b.paths) { const li = el('li'); li.appendChild(pageLink(p || '/')); ul.appendChild(li); }
        holder.appendChild(ul);
      }
    });
  }

  // the latest requests of the day, newest first: people's pages, the rest
  // of what people asked for, and the bots', as the report told them apart
  function drawLatest(box, r) {
    box.appendChild(el('p', 'hint', t('The latest thousand requests from people and four hundred from bots in the period, newest first. Pick an address for its whole story.')));
    const kinds = [['page', t('Pages people read')], ['other', t('Everything else people asked for')], ['bot', t('Bots')]];
    listView(box, {
      id: 'v-latest2', key: function (l) { return l.at + l.ip + l.path + l.kind; }, sort: '-at', csv: 'latest-' + windowName(r), page: 200,
      search: t('Filter by address, page or member'), rows: r.latest || [],
      columns: [
        {key: 'at', title: t('When'), down: true, cell: function (l) { return stamp(l.at); }},
        {key: 'ip', title: t('Address'), cell: function (l) { return addressCell(l.ip); }},
        {key: 'member', title: t('Member'), cell: function (l) { return l.member ? link('/u/' + enc(l.member), '', l.member) : ''; }},
        {key: 'path', title: t('Page'), cell: function (l) { return pageLink(l.path); }},
        {key: 'status', title: t('Status'), num: true, cell: function (l) { return statusCell(l.status); }},
        {key: 'ms', title: t('Took'), num: true, wide: true, cell: function (l) { return msCell(l.ms); }},
        {key: 'browser', title: t('Browser or bot'), wide: true, value: function (l) { return l.bot || browserOf(l.agent); },
          cell: function (l) { const s2 = el('span', 'dim', l.bot || browserOf(l.agent)); s2.title = l.agent; return s2; }}
      ],
      filters: [
        {key: 'kind', title: t('Which'), all: t('Every request'), value: 'page', options: kinds, test: function (l, k) { return l.kind === k; }},
        {key: 'status', title: t('Status'), all: t('Any status'), options: [['ok', t('Answered')], ['4xx', t('Refused or not here')], ['5xx', t('Failed')]],
          test: function (l, k) { return k === 'ok' ? !(l.status >= 400) : k === '4xx' ? l.status >= 400 && l.status < 500 : l.status >= 500; }},
        {key: 'section', title: t('Part of the site'), all: t('The whole site'), test: function (l, k) { return sectionOf(l.path) === k; },
          options: function (rows) { return sectionOptions(rows.map(function (l) { return l.path; })); }}
      ],
      noun: function (n) { return tn(n, '%d request', '%d requests'); }, empty: t('Nothing in that period\'s logs yet.'),
      detail: function (l, holder) {
        const head = el('div', 'lv-detail-head');
        head.append(el('b', '', l.ip), l.member ? link('/u/' + enc(l.member), '', l.member) : '', el('span', 'dim', dateTimeText(l.at)));
        holder.appendChild(head);
        facts(holder, [[t('Asked for'), l.method + ' ' + l.path], [t('Page'), pageLink(l.path)], [t('Answered'), l.status ? statusCell(l.status) : ''],
          [t('Took'), msCell(l.ms)], [t('Bot'), l.bot], [t('From'), l.referer ? outLink(l.referer) : ''], [t('Browser'), l.agent]]);
        const acts = el('div', 'lv-actions'); acts.appendChild(lookButton(l.ip)); holder.appendChild(acts);
      }
    });
  }

  function drawVisitCounts(box, data) {
    if (!data.server) box.appendChild(el('p', 'notice', t('Visitor collection requires server mode.')));
    const today = data.days.length ? data.days[0].day : '';
    const byDay = new Map();
    for (const d of data.days) byDay.set(d.day, (byDay.get(d.day) || 0) + d.requests);
    const days = Array.from(byDay).sort().slice(-30);
    if (days.length > 1) {
      const most = Math.max.apply(null, days.map(function (d) { return d[1]; }).concat([1]));
      const row = el('div', 'days');
      for (const d of days) {
        const bar = el('i'); bar.style.height = Math.max(2, Math.round(66 * d[1] / most)) + 'px';
        bar.title = dateText(d[0]) + ': ' + tn(d[1], '%d request', '%d requests');
        if (d[0] === today) bar.classList.add('today');
        row.appendChild(bar);
      }
      box.appendChild(row);
      const cap = el('div', 'days-caption'); cap.append(el('span', '', dateText(days[0][0])), el('span', '', t('requests a day, bots included')), el('span', '', dateText(days[days.length - 1][0]))); box.appendChild(cap);
    }
    box.appendChild(el('p', 'hint', t('UTC days. Counts are saved each minute. People are browsers that took the page whole, bots everything else that came; each address counts once in each part and day, and totals add those counts. People are counted from 6 Nov 2026.')));
    const partName = partLabel;
    const totals = new Map();
    for (const day of data.days) {
      const total = totals.get(day.part) || [0, 0, 0, 0];
      day.people = Math.min(day.people || 0, day.visitors); day.bots = day.visitors - day.people;
      total[0] += day.requests; total[1] += day.people; total[2] += day.refused; total[3] += day.bots;
      totals.set(day.part, total);
    }
    const countCols = [
      {key: 'requests', title: t('Requests'), num: true}, {key: 'people', title: t('People'), num: true}, {key: 'bots', title: t('Bot addresses'), num: true}, {key: 'refused', title: t('Guard refusals'), num: true}];
    box.appendChild(el('h3', '', t('All days kept')));
    listView(box, {
      id: 'v-parts', key: function (x) { return x.part; }, sort: '-requests', search: false,
      rows: Array.from(totals, function (pair) { return {part: pair[0], requests: pair[1][0], people: pair[1][1], refused: pair[1][2], bots: pair[1][3]}; }),
      columns: [{key: 'part', title: t('Part'), value: function (x) { return partName(x.part); }}].concat(countCols), noun: function (n) { return tn(n, '%d part', '%d parts'); }
    });
    box.appendChild(el('h3', '', t('Day by day')));
    listView(box, {
      id: 'v-partdays', key: function (x) { return x.day + x.part; }, sort: '-day', search: false, csv: 'requests-by-day',
      rows: data.days,
      columns: [{key: 'day', title: t('Day'), down: true, cell: function (x) { return dateText(x.day); }},
        {key: 'part', title: t('Part'), value: function (x) { return partName(x.part); }}].concat(countCols),
      filters: [{key: 'part', title: t('Part'), all: t('Every part'), test: function (x, k) { return x.part === k; },
        options: function (rows) { return Array.from(new Set(rows.map(function (x) { return x.part; }))).map(function (p) { return [p, partName(p)]; }); }}],
      noun: function (n) { return tn(n, '%d row', '%d rows'); }
    });
    box.appendChild(el('h3', '', t('Busiest paths today')));
    listView(box, {
      id: 'v-paths', key: function (x) { return x.path; }, sort: '-requests', search: t('Filter paths'), rows: data.paths,
      columns: [{key: 'path', title: t('Path'), cell: function (x) { return pageLink(x.path); }}, {key: 'requests', title: t('Requests'), num: true}],
      noun: function (n) { return tn(n, '%d path', '%d paths'); }
    });
  }

  // a window's name for a file: its days
  function windowName(r) {
    return String(r.from || '').slice(0, 10) + '-' + String(r.to || '').slice(0, 10);
  }

  // the addresses the report holds something against, the worst first
  function drawConcerns(box, r, period) {
    box.replaceChildren();
    box.appendChild(el('p', 'hint', t('Every address is judged on its own, whatever it said it was: its busiest minute, how many browser strings and members it used, the pages it asked for that are not here, the scanner paths it probed, how often the guard turned it away, and whether it named a crawler it is not. A published crawler is welcome at any pace; an address on the allowed list (or this network) is not weighed. Pick a row for the whole story and the block buttons.')));
    if (r.concerns_count > r.concerns.length)
      box.appendChild(el('p', 'hint', t('The %s weighed heaviest are listed, of %s.', r.concerns.length.toLocaleString(locale), r.concerns_count.toLocaleString(locale))));
    const kinds = reasonKinds();
    const blockWords = {forgood: t('For good'), blocked: t('Blocked now'), over: t('Block over')};
    listView(box, {
      id: 'v-concerns', key: function (c) { return c.ip; }, sort: '-score', csv: 'concerns-' + windowName(r),
      search: t('Filter by address, bot or reason'), rows: r.concerns,
      columns: [
        {key: 'score', title: t('Weight'), num: true},
        {key: 'ip', title: t('Address'), cell: function (c) { return el('b', 'lv-ip', c.ip); }},
        // the guard's state, so a blocked address shows without opening it
        {key: 'block', title: t('Blocked'), value: function (c) { return blockWords[c.block] || ''; },
          cell: function (c) { return c.block ? chip(blockWords[c.block], c.block === 'over' ? '' : 'bad') : el('span', '', ''); }},
        {key: 'what', title: t('Says it is'), value: function (c) { return c.crawler || c.bot || t('a browser'); }},
        // AbuseIPDB's confidence, once the site has looked the address up
        {key: 'abuse', title: t('AbuseIPDB'), num: true, value: function (c) { return c.abuse == null ? -1 : c.abuse; },
          cell: function (c) { return c.abuse == null ? el('span', 'dim', '') : chip(c.abuse + '%', c.abuse >= 75 ? 'bad' : ''); }},
        {key: 'reasons', title: t('Why'), nosort: true, cls: 'lv-text', value: function (c) { return c.reasons.map(reasonWords).join('; '); },
          cell: function (c) { const s2 = el('span', 'lv-reasons'); for (const x of c.reasons) s2.appendChild(chip(reasonWords(x), 'open')); return s2; }},
        {key: 'requests', title: t('Requests'), num: true},
        {key: 'peak', title: t('Busiest minute'), num: true, wide: true},
        {key: 'last', title: t('Last seen'), down: true, wide: true, cell: function (c) { return stamp(c.last); }}
      ],
      filters: [{key: 'block', title: t('Blocked'), all: t('Blocked or not'),
        options: [['forgood', t('For good')], ['blocked', t('Blocked now')], ['over', t('Block over')], ['none', t('Never blocked')]],
        test: function (c, v) { return v === 'none' ? !c.block : c.block === v; }},
        {key: 'kind', title: t('Reason'), all: t('Every reason'), test: function (c, k) { return c.reasons.some(function (x) { return x.kind === k; }); },
        options: function (rows) {
          const seen = new Map();
          for (const c of rows) for (const x of c.reasons) seen.set(x.kind, (seen.get(x.kind) || 0) + 1);
          return Array.from(seen).sort(function (a, b) { return b[1] - a[1]; }).map(function (x) { return [x[0], (kinds[x[0]] || x[0]) + ' (' + x[1] + ')']; });
        }}],
      noun: function (n) { return tn(n, '%d address', '%d addresses'); }, empty: t('Nothing of concern in that period.'),
      detail: function (c, holder) { addressPanel(c.ip, holder, period); }
    });
  }

  function adminVisitors(box) {
    // an admin who manages blocks without seeing visitors: the blocked list alone
    if (S.adminCan && !S.adminCan('view-visitors')) {
      const utc = function (back) { return new Date(Date.now() - back * 864e5).toISOString().slice(0, 10); };
      adminBlocks(box, function () { return {from: utc(1), to: utc(0)}; });
      return;
    }
    let hideMe = true;
    try { hideMe = localStorage.getItem('admin-hide-me') !== 'off'; } catch (e) { }
    // the window: the last hours back from now, today or yesterday on this
    // computer's clock, a UTC day (one log), every day kept, or any two
    // moments; the last 24 hours at first, the choice remembered
    const utcDay = function (back) { return new Date(Date.now() - back * 864e5).toISOString().slice(0, 10); };
    const iso = function (ms) { return new Date(ms).toISOString().slice(0, 19) + 'Z'; };
    // midnight on this computer's clock, back days ago: today and yesterday
    // are the admin's own days, not UTC ones (those start at 7 PM in New York)
    const localMidnight = function (back) { const d = new Date(); d.setHours(0, 0, 0, 0); d.setDate(d.getDate() - back); return d.getTime(); };
    let choice = '24h';
    try { choice = localStorage.getItem('admin-visit-window') || '24h'; } catch (e) { }
    let days = [];
    const controls = el('div', 'visit-controls');
    const pickLabel = el('label', '', t('Period') + ' ');
    const pick = el('select'); pickLabel.appendChild(pick);
    const custom = el('span', 'visit-custom');
    const fromBox = el('input'), toBox = el('input');
    fromBox.type = toBox.type = 'datetime-local';
    fromBox.setAttribute('aria-label', t('From'));
    toBox.setAttribute('aria-label', t('To'));
    const local = function (ms) { const d = new Date(ms); return new Date(ms - d.getTimezoneOffset() * 60000).toISOString().slice(0, 16); };
    fromBox.value = local(Date.now() - 864e5);
    toBox.value = local(Date.now());
    custom.append(fromBox, ' – ', toBox);
    custom.hidden = choice !== 'custom';
    const option = function (value, words) { const o2 = el('option', '', words); o2.value = value; return o2; };
    const fillPeriods = function () {
      const oldest = days.length ? days[days.length - 1] : utcDay(0);
      pick.replaceChildren(
        option('1h', t('The last hour')), option('8h', t('The last 8 hours')), option('24h', t('The last 24 hours')),
        option('48h', t('The last 2 days')), option('168h', t('The last 7 days')),
        option('today', t('Today')), option('yesterday', t('Yesterday')),
        option('all', tn(days.length, 'Every day kept (%d), from %s', 'Every day kept (%d), from %s').replace('%s', dateText(oldest))),
        option('custom', t('Between two moments…')));
      const one = el('optgroup');
      one.label = t('One day');
      for (const d of days) one.appendChild(option(d, dateText(d)));
      pick.appendChild(one);
      pick.value = choice;
      if (pick.value !== choice) { choice = '24h'; pick.value = choice; }
    };
    fillPeriods();
    // the window as the server takes it: moments for the hours (the end rounded
    // to the minute, so a second look within it finds the report kept), days whole
    const windowOf = function () {
      const minute = Math.floor(Date.now() / 60000) * 60000;
      if (/^\d+h$/.test(choice)) return {from: iso(minute + 59000 - parseInt(choice, 10) * 3600e3), to: iso(minute + 59000)};
      if (choice === 'today') return {from: iso(localMidnight(0)), to: iso(minute + 59000)};
      if (choice === 'yesterday') return {from: iso(localMidnight(1)), to: iso(localMidnight(0) - 1000)};
      if (choice === 'all') return {from: days.length ? days[days.length - 1] : utcDay(0), to: utcDay(0)};
      if (choice === 'custom') {
        const a = fromBox.value ? new Date(fromBox.value).getTime() : minute - 864e5, b = toBox.value ? new Date(toBox.value).getTime() : minute + 59000;
        return a <= b ? {from: iso(a), to: iso(b)} : {from: iso(b), to: iso(a)};
      }
      return {from: choice, to: choice};
    };
    let period = windowOf();
    const periodNow = function () { return period; };
    const label = el('label', 'visit-tick'), tick = el('input');
    tick.type = 'checkbox'; tick.checked = hideMe; label.append(tick, ' ' + t('Hide my visits'));
    tick.addEventListener('change', function () { hideMe = tick.checked; try { localStorage.setItem('admin-hide-me', hideMe ? 'on' : 'off'); } catch (e) { } load(); });
    const again = el('button', 'small-link', t('Refresh'));
    again.type = 'button';
    again.addEventListener('click', function () { load(); });
    controls.append(pickLabel, custom, label, again);
    box.appendChild(controls);
    const tabList = [
      {key: 'overview', title: t('Overview')}, {key: 'people', title: t('People')}, {key: 'pages', title: t('Pages')},
      {key: 'searches', title: t('Searches')}, {key: 'members', title: t('Members')}, {key: 'crawlers', title: t('Known crawlers')},
      {key: 'bots', title: t('Bots')}, {key: 'concerns', title: t('Of concern')}, {key: 'latest', title: t('Latest requests')},
      {key: 'address', title: t('Address')}];
    const blocks = S.adminCan && S.adminCan('manage-blocks');
    if (blocks) tabList.push({key: 'blocked', title: t('Blocked')});
    tabList.push({key: 'counts', title: t('By part of the site')});
    const subs = subTabs(box, 'visitors', tabList);
    const reportParts = ['overview', 'people', 'pages', 'searches', 'members', 'crawlers', 'bots', 'concerns', 'latest'];

    // the address panel: any address, typed or picked anywhere, in the window shown
    const addrBox = subs.holder('address');
    const addrForm = el('form', 'visit-lookup');
    const addrInput = el('input');
    addrInput.type = 'search';
    addrInput.placeholder = t('An address, such as 203.0.113.9');
    addrInput.setAttribute('aria-label', t('Address'));
    const addrGo = el('button', '', t('Look up'));
    addrForm.append(addrInput, addrGo);
    const addrPanel = el('div', 'lv-detail visit-address');
    addrPanel.hidden = true;
    addrBox.append(el('p', 'hint', t('Everything one address did in the period, whatever it said it was, with the guard’s facts and the block buttons. Pick an address anywhere in these lists, or type one.')), addrForm, addrPanel);
    let shownIp = '';
    const showAddress = function (ip) {
      shownIp = (ip || '').trim();
      addrInput.value = shownIp;
      addrPanel.hidden = !shownIp;
      if (shownIp) addressPanel(shownIp, addrPanel, periodNow);
    };
    addrForm.addEventListener('submit', function (e) { e.preventDefault(); showAddress(addrInput.value); });
    S.showAddress = function (ip) { subs.select('address'); showAddress(ip); };
    S.blockLook = S.showAddress;

    let loads = 0;
    const load = function () {
      const mine = ++loads;
      period = windowOf();
      for (const k of reportParts) waiting(subs.holder(k), t('Reading the log…'));
      pick.disabled = tick.disabled = again.disabled = true;
      get('/api/admin/visitors/report?from=' + enc(period.from) + '&to=' + enc(period.to) + (hideMe ? '&hide=me' : '')).then(function (r) {
        if (mine !== loads) return;
        if (JSON.stringify(days) !== JSON.stringify(r.days)) {
          days = r.days;
          fillPeriods();
          // "every day kept" asked before the days were known: asked again with them
          if (windowOf().from !== period.from) { load(); return; }
        }
        drawVisitReport(subs, r, pick, hideMe);
        if (r.found) {
          drawLatest(subs.holder('latest'), r);
          drawConcerns(subs.holder('concerns'), r, periodNow);
        }
        if (shownIp) showAddress(shownIp);
        // a blocked row's open story, told again for this window
        if (S.blocksChanged) S.blocksChanged();
      }).catch(function (err) {
        if (mine !== loads) return;
        // the server's own short reason when it gave one (not a proxy's error page)
        const why = err && err.message && err.message.length < 300 && !/[<>]/.test(err.message) ? ' ' + err.message : '';
        for (const k of reportParts) subs.holder(k).replaceChildren(el('p', 'notice', t('The access log could not be read.') + why));
      }).finally(function () { if (mine === loads) pick.disabled = tick.disabled = again.disabled = false; });
    };
    pick.addEventListener('change', function () {
      choice = pick.value;
      try { localStorage.setItem('admin-visit-window', choice); } catch (e) { }
      custom.hidden = choice !== 'custom';
      load();
    });
    fromBox.addEventListener('change', function () { if (choice === 'custom') load(); });
    toBox.addEventListener('change', function () { if (choice === 'custom') load(); });
    load();
    if (blocks) adminBlocks(subs.holder('blocked'), periodNow);
    waiting(subs.holder('counts'));
    get('/api/admin/visitors').then(function (data) { subs.holder('counts').replaceChildren(); drawVisitCounts(subs.holder('counts'), data); })
      .catch(function (err) { subs.holder('counts').replaceChildren(el('p', 'notice', err.message)); });
  }

  function adminStorage(box) {
    get('/api/admin/storage').then(function (data) {
      if (data.disk_total > 0) {
        const used = data.disk_total - data.disk_free, share = used / data.disk_total;
        const tiles = el('div', 'tiles-admin');
        const disk = stat(tiles, Math.round(share * 100) + '%', t('Disk used'), sizeText(used) + ' ' + t('of') + ' ' + sizeText(data.disk_total), share > 0.9 ? 'warn' : '');
        const meter = el('div', 'meter' + (share > 0.95 ? ' bad' : share > 0.8 ? ' warn' : '')); const fill = el('i'); fill.style.width = Math.round(share * 100) + '%'; meter.appendChild(fill); disk.appendChild(meter);
        stat(tiles, sizeText(data.disk_free), t('Free'));
        stat(tiles, sizeText(data.items.reduce(function (sum, item) { return sum + item.bytes; }, 0)), t('The site uses'), t('database and folders'));
        box.appendChild(tiles);
      }
      if (data.items.length) bars(box, data.items.slice().sort(function (a, b) { return b.bytes - a.bytes; }).map(function (item) { return {name: t(item.caption), value: item.bytes}; }), sizeText);
      box.appendChild(el('p', 'hint', t('Measured in the background at most once an hour. Database sizes are engine estimates including indexes. Folder sizes exclude symbolic links.')));
      if (!data.items.length) box.appendChild(el('p', 'notice', t('No storage measurement yet.')));
      adminTable(box, [t('Group or folder'), t('Size'), t('Measured'), t('Status')], data.items.map(function (item) {
        return [t(item.caption), sizeText(item.bytes), dateTimeText(item.measured), item.complete ? t('Complete') : t('Partial')];
      }));
    }).catch(failed);
  }

  // The first thing an admin sees: which modules (parts) this site runs, each with
  // its switch, and what waits for attention.
  function adminOverview(box, data, can) {
    const on = String(data.parts || '').split(' ');
    const switches = (data.settings || []).filter(function (s) { return s.group === 'Parts'; });
    if (data.unlisted_proxies)
      box.appendChild(el('p', 'problem', t('Requests arrive through %s, which the config file does not name under proxies. Until it does, every visitor looks like that one address and the guard cannot tell them apart.', data.unlisted_proxies)));
    box.appendChild(el('h2', '', t('Community modules')));
    box.appendChild(el('p', 'hint', t('Each module can be on or off. A module that is off has no pages and no entries here; what it holds is kept.')));
    const cards = el('div', 'part-cards');
    box.appendChild(cards);
    const names = {chat: t('Chat'), wiki: t('Wiki'), forum: t('Forum')};
    const fronts = {chat: '/', wiki: '/wiki', forum: '/forum'};
    const list = switches.length ? switches.map(function (s) { return {name: s.name, caption: s.caption, on: s.value === '1', change: true}; }) :
      on.filter(Boolean).map(function (name) { return {name: name, caption: '', on: true, change: false}; });
    for (const p of list) {
      const card = el('div', 'part-card ' + (p.on ? 'on' : 'off'));
      const head = el('h3', '', names[p.name] || t(p.name.charAt(0).toUpperCase() + p.name.slice(1)));
      head.appendChild(el('span', 'part-state', p.on ? t('On') : t('Off')));
      card.appendChild(head);
      // the caption says what the part is, after its name and a colon
      const words = t(p.caption);
      const about = words.indexOf(': ') > 0 ? words.slice(words.indexOf(': ') + 2) : words;
      card.appendChild(el('p', '', about.charAt(0).toUpperCase() + about.slice(1)));
      const tools = el('div', 'part-tools');
      if (p.change) {
        const flip = el('button', p.on ? '' : 'primary', p.on ? t('Turn off') : t('Turn on'));
        flip.type = 'button';
        flip.addEventListener('click', async function () {
          flip.disabled = true;
          try {
            const fields = {};
            fields[p.name] = p.on ? '0' : '1';
            await post('/api/admin/settings', fields);
            // the page's list and the top bar follow the parts: read it all again
            location.reload();
          } catch (err) { failed(err); flip.disabled = false; }
        });
        tools.appendChild(flip);
      }
      if (p.on) tools.appendChild(link(fronts[p.name] || '/' + p.name, 'small-link', t('Open')));
      card.appendChild(tools);
      cards.appendChild(card);
    }
    box.appendChild(el('h2', '', t('The site')));
    const stats = el('div', 'tiles-admin');
    box.appendChild(stats);
    if (data.members_total !== undefined) stat(stats, data.members_total, t('Members'));
    if (can('read-reports')) {
      const waiting = stat(stats, data.open_reports || 0, t('Reports'), '', (data.open_reports || 0) > 0 ? 'warn' : '');
      waiting.style.cursor = 'pointer';
      waiting.addEventListener('click', function () { S.adminTab('Reports'); });
    }
    stat(stats, list.filter(function (p) { return p.on; }).length, t('Modules on'));
    if (data.version) stat(stats, data.version, t('Exedra version'));
    // what other scripts add to this page
    for (const extra of Extras.adminOverview)
      if (!extra.permission || can(extra.permission)) {
        const holder = el('section', 'overview-extra');
        box.appendChild(holder);
        extra.build(holder);
      }
  }

  // Only says which groups of settings this box holds; key keeps each box's
  // last section apart.
  function adminSettings(box, data, only, key) {
    const layout = el('div', 'settings-layout');
    const side = el('div', 'settings-side');
    const search = el('input', 'lv-find');
    search.type = 'search';
    search.autocomplete = 'off';
    search.placeholder = t('Search settings');
    search.setAttribute('aria-label', t('Search settings'));
    const nav = el('nav', 'subtabs settings-nav');
    nav.setAttribute('aria-label', t('Settings sections'));
    const picker = el('select', 'lv-filter settings-picker');
    picker.setAttribute('aria-label', t('Settings section'));
    const panel = el('div', 'settings-panels');
    const empty = el('p', 'hint', t('No settings match your search.'));
    empty.hidden = true;
    panel.appendChild(empty);
    side.append(search, nav, picker);
    layout.append(side, panel);
    box.appendChild(layout);

    const groups = new Map();
    for (const s of data.settings) {
      if (only && !only(s.group)) continue;
      if (!groups.has(s.group)) groups.set(s.group, []);
      groups.get(s.group).push(s);
    }
    let chosen = shared('admin-settings-section' + (key ? '-' + key : ''));
    if (!groups.has(chosen)) chosen = groups.keys().next().value;
    const sections = [];
    function show() {
      const query = search.value.trim().toLowerCase();
      let found = false;
      for (const section of sections) {
        let matches = 0;
        for (const field of section.fields) {
          const match = !query || field.words.includes(query);
          field.label.hidden = !match;
          // Hidden search results must not be submitted or block number validation.
          field.input.disabled = !match;
          if (match) matches++;
        }
        section.form.hidden = query ? matches === 0 : section.group !== chosen;
        section.button.classList.toggle('on', section.group === chosen);
        section.button.setAttribute('aria-pressed', section.group === chosen ? 'true' : 'false');
        if (!section.form.hidden) found = true;
      }
      picker.value = chosen;
      empty.hidden = found;
    }
    function select(group) {
      chosen = group;
      shared('admin-settings-section' + (key ? '-' + key : ''), group);
      search.value = '';
      show();
    }

    for (const [group, settings] of groups) {
      const button = el('button');
      button.type = 'button';
      button.append(el('span', '', t(group)), chip(t('%d', settings.length)));
      button.addEventListener('click', function () { select(group); });
      nav.appendChild(button);
      const option = el('option', '', t('%s (%d)', t(group), settings.length));
      option.value = group;
      picker.appendChild(option);
      const form = el('form', 'settings settings-section');
      form.autocomplete = 'off';
      form.appendChild(el('h3', '', t(group)));
      if (group === 'Sign-in')
        form.appendChild(el('p', 'hint', t('Make an OAuth app at each provider and give it this return address: %s followed by its name: github, gitlab, codeberg, google or microsoft. A provider shows on the sign-in page once its id and secret are here and it is switched on.',
          location.origin + SiteBase.url('/_oauth/'))));
      const fields = [];
      for (const s of settings) {
        const label = el('label');
        const caption = el('span', 'setting-caption', t(s.caption));
        caption.appendChild(el('small', 'hint', t(s.name)));
        label.appendChild(caption);
        let input;
        if (s.kind === 'yesno' || s.kind.startsWith('choice:')) {
          input = el('select');
          const choices = s.kind === 'yesno' ? [['1', t('yes')], ['0', t('no')]] :
            s.kind.slice(7).split('|').map(function (c) { return [c, t(c)]; });
          for (const c of choices) {
            const o = el('option', '', c[1]);
            o.value = c[0];
            input.appendChild(o);
          }
        } else {
          // a long line (a list of emoji, of addresses) gets the column's
          // whole width and wraps; it stays one line: Enter saves, as in a box
          const long = s.kind === 'longtext';
          input = el(long ? 'textarea' : 'input');
          if (long) {
            label.classList.add('wide');
            input.rows = 3;
            input.addEventListener('keydown', function (e) {
              if (e.key === 'Enter') { e.preventDefault(); form.requestSubmit(); }
            });
            input.addEventListener('input', function () {
              if (input.value.includes('\n')) input.value = input.value.replace(/\s*\n\s*/g, ' ');
            });
          }
          if (s.kind === 'number') input.type = 'number';
          // No browser autofill: its suggestion box holds the page's scrolling
          // while it is open (Brave on Windows, 10 Nov 2026), and these are
          // the site's settings, not the admin's own details.
          input.autocomplete = 'off';
          input.spellcheck = false;
          // Secrets never come back from the server: an empty box keeps the one set.
          // A text box masked by CSS, not a password box, so no password manager offers itself.
          if (s.kind === 'secret') {
            input.classList.add('secret');
            input.setAttribute('data-1p-ignore', '');
            input.setAttribute('data-lpignore', 'true');
            input.placeholder = s.set ? t('set (empty keeps it)') : t('not set');
          }
        }
        input.name = s.name;
        input.value = s.value;
        label.appendChild(input);
        form.appendChild(label);
        fields.push({label: label, input: input, words: [s.caption, t(s.caption), s.name].join(' ').toLowerCase()});
      }
      const save = el('button', 'primary', t('Save settings'));
      save.type = 'submit';
      form.appendChild(save);
      if (group === 'File scanning') fileScanning(form);
      form.addEventListener('submit', async function (e) {
        e.preventDefault();
        save.disabled = true;
        try { toast(await post('/api/admin/settings', new URLSearchParams(new FormData(form)))); }
        catch (err) { failed(err); }
        finally { save.disabled = false; }
      });
      panel.appendChild(form);
      sections.push({group: group, button: button, form: form, fields: fields});
    }
    search.addEventListener('input', show);
    picker.addEventListener('change', function () { select(picker.value); });
    show();
  }

  // Under the File scanning settings: whether the scanner runs, a test with
  // the EICAR file, and the uploads it stopped or could not check.
  function fileScanning(form) {
    const status = el('p', 'hint');
    status.setAttribute('role', 'status');
    const test = el('button', '', t('Test the scanner'));
    test.type = 'button';
    const said = el('p');
    said.setAttribute('role', 'status');
    const list = el('div', 'scan-list');
    const panel = el('div', 'scan-panel');
    panel.append(el('h3', '', t('The scanner')), status, el('p', 'hint', t('The test scans the EICAR test file, a harmless file that every virus scanner reports.')), test, said, list);
    form.appendChild(panel);
    const show = async function () {
      const d = await get('/api/admin/scans');
      status.textContent = [d.on ? t('Scanning is on.') : t('Scanning is off.'),
        d.ready ? t('Scanner ready: %s', d.version || '?') : d.problem,
        d.last_error ? t('Last error, %s: %s', dateTimeText(d.last_error_at), d.last_error) : ''].join(' ').trim();
      list.replaceChildren(el('h3', '', t('Files stopped or not checked')));
      if (!d.files.length) { list.appendChild(el('p', 'hint', t('Nothing yet.'))); return; }
      adminTable(list, [t('When'), t('Member'), t('Where'), t('File'), t('Size'), t('Result'), 'SHA-256'], d.files.map(function (f) {
        return [dateTimeText(f.when), f.member, f.route, f.name, sizeText(f.size),
          f.found ? t('refused, found %s', f.names) : (f.kept ? t('kept unchecked: %s', f.names) : t('refused unchecked: %s', f.names)), f.sha256];
      }));
    };
    test.addEventListener('click', async function () {
      test.disabled = true;
      said.textContent = '';
      try {
        const r = JSON.parse(await post('/api/admin/scans/test', {}));
        said.textContent = r.caught ? t('The scanner caught the test file: %s', r.words) :
          r.error ? t('The scanner could not check the test file: %s', r.words) : t('The scanner did not catch the test file.');
        if (r.caught && !r.limits) said.textContent += ' ' + t('It does not report the files it stops reading at a limit, so those would count as clean: set AlertExceedsMax yes in clamd.conf.');
        await show();
      } catch (err) { failed(err); }
      finally { test.disabled = false; }
    });
    show().catch(failed);
  }

  // The site's icon (made in every size from one square picture) and the
  // logo in the header.
  function adminLook(box) {
    const part = function (what, title, hint, preview) {
      const form = el('form', 'settings look');
      form.appendChild(el('h3', '', title));
      form.appendChild(el('p', 'hint', hint));
      const img = el('img', 'lookpreview ' + what);
      img.alt = '';
      img.addEventListener('error', function () { img.hidden = true; });
      img.addEventListener('load', function () { img.hidden = false; });
      img.src = preview;
      const file = el('input');
      file.type = 'file';
      file.name = 'picture';
      file.accept = 'image/png,image/jpeg';
      const save = el('button', 'primary', t('Upload'));
      const remove = el('button', '', t('Use none'));
      remove.type = 'button';
      const send = async function (fields) {
        fields.append('what', what);
        try {
          toast(await post('/api/admin/look', fields));
          img.src = preview + (preview.includes('?') ? '&' : '?') + Date.now();
        } catch (err) { failed(err); }
      };
      form.addEventListener('submit', function (e) { e.preventDefault(); send(new FormData(form)); });
      remove.addEventListener('click', function () {
        const fields = new FormData();
        fields.append('remove', '1');
        send(fields);
      });
      form.append(img, file, save, remove);
      box.appendChild(form);
    };
    const logo = $('.brandlogo');
    part('icon', t('Icon'), t('One square PNG or JPEG, 512 by 512 pixels or more. It becomes the browser tab icon, the installed app\'s icon and the notification icon, in every size they need.'), '/icon-192.png');
    part('logo', t('Logo'), t('Shown in the header, 32 pixels high, beside the name or instead of it (Settings, "Show the name beside the logo"). It sits on the dark header bar in both themes, so use light lettering. A wide PNG with a clear background works best.'), logo ? logo.src : '/site/logo.png');
  }

  function adminChannels(box, data) {
    box.appendChild(el('p', 'hint', t('Public channels everyone follows when they join. Members open their own private channels from the + in the sidebar.')));
    const table = el('table', 'grid');
    const addRow = function (c) {
      const tr = el('tr');
      const slug = el('input');
      slug.value = c.slug || '';
      slug.readOnly = !!c.slug;
      slug.placeholder = t('new-channel');
      const topic = el('input');
      topic.value = c.topic || '';
      topic.placeholder = t('What it is for');
      const policy = el('select');
      [['all', t('everyone posts')], ['readonly', t('read only: some post, all reply')]].forEach(function (p) {
        const o = el('option', '', p[1]);
        o.value = p[0];
        policy.appendChild(o);
      });
      policy.value = c.policy === 'readonly' ? 'readonly' : 'all';
      const archived = el('input');
      archived.type = 'checkbox';
      archived.checked = !!c.archived;
      archived.title = t('Archived');
      // The channel's icon: a click on it picks a new picture.
      const iconCell = el('label', 'chanicon');
      if (c.slug) {
        const img = el('img');
        img.alt = '';
        if (c.avatar) img.src = c.avatar; else img.hidden = true;
        const pick = el('input');
        pick.type = 'file';
        pick.accept = 'image/png,image/jpeg,image/webp';
        pick.hidden = true;
        iconCell.title = t('Change the icon');
        iconCell.append(img, el('span', '', c.avatar ? '' : t('Icon')), pick);
        pick.addEventListener('change', async function () {
          const fields = new FormData();
          fields.append('file', pick.files[0]);
          fields.append('room_icon', c.slug);
          try {
            img.src = JSON.parse(await post('/api/upload', fields)).url;
            img.hidden = false;
            iconCell.querySelector('span').textContent = '';
            toast(t('Icon saved.'));
          } catch (err) { failed(err); }
        });
      }
      const save = el('button', '', c.slug ? t('Save') : t('Create'));
      save.type = 'button';
      save.addEventListener('click', async function () {
        try {
          toast(await post('/api/admin/channel', {slug: slug.value, topic: topic.value, policy: policy.value,
            archived: archived.checked ? '1' : '0'}));
          if (!c.slug) route('/admin', false);
        } catch (err) { failed(err); }
      });
      [iconCell, slug, topic, policy, archived, save].forEach(function (x) { const td = el('td'); td.appendChild(x); tr.appendChild(td); });
      table.appendChild(tr);
    };
    data.channels.forEach(addRow);
    addRow({});
    box.appendChild(table);
  }

  // Who has private channels and conversations: who, when and how much, never
  // what.  Deleting here is for everyone in them and cannot be undone.
  function adminPrivate(box) {
    const when = function (iso) { return iso ? ago(iso) : t('nothing yet'); };
    const count = function (n) { return tn(n, '%d message', '%d messages'); };
    const people = function (c) {
      const names = c.members.map(function (n) { return n === c.owner ? t('%s (owner)', n) : n; });
      if (c.owner && c.members.indexOf(c.owner) < 0) names.unshift(t('%s (owner, left)', c.owner));
      return names.join(', ') || t('nobody');
    };
    const removeButton = function (ask, fields, show) {
      const remove = el('button', 'small-link bad', t('Delete'));
      remove.type = 'button';
      remove.addEventListener('click', async function () {
        if (!confirm(ask)) return;
        try { toast(await post('/api/admin/private/delete', fields)); await show(); } catch (err) { failed(err); }
      });
      return remove;
    };
    const part = function (rows, empty) {
      const wrap = el('div', 'gridwrap');
      if (!rows.length) { wrap.appendChild(el('p', 'dim', empty)); return wrap; }
      const table = el('table', 'grid privategrid');
      rows.forEach(function (row) { table.appendChild(row); });
      wrap.appendChild(table);
      return wrap;
    };
    const row = function (cells) {
      const tr = el('tr');
      cells.forEach(function (c) {
        const td = el('td', c.dim ? 'dim' : '');
        if (c.node) td.appendChild(c.node); else td.textContent = c.text;
        tr.appendChild(td);
      });
      return tr;
    };
    let list = null;
    const body = el('div');
    const find = el('input');
    find.type = 'search';
    find.placeholder = t('Find a member or channel');
    const fill = function () {
      const q = find.value.trim().toLowerCase();
      const has = function (text) { return !q || String(text).toLowerCase().indexOf(q) >= 0; };
      const channels = list.channels.filter(function (c) {
        return has(c.slug) || has(c.title) || has(c.owner) || c.members.some(has);
      }).map(function (c) {
        return row([
          {node: el('b', '', c.archived ? t('#%s (archived)', c.slug) : '#' + c.slug)},
          {text: people(c)},
          {text: count(c.messages), dim: true},
          {text: when(c.last), dim: true},
          {node: removeButton(t('Delete #%s for good?\n\nIts messages, threads and files go for everyone in it. This cannot be undone.', c.slug), {kind: 'channel', slug: c.slug}, show)},
        ]);
      });
      const talks = list.conversations.filter(function (c) { return has(c.a) || has(c.b); }).map(function (c) {
        return row([
          {node: el('b', '', t('%s and %s', c.a, c.b))},
          {text: c.locked ? t('locked') : t('plain'), dim: true},
          {text: count(c.messages), dim: true},
          {text: when(c.last), dim: true},
          {node: removeButton(t('Delete the conversation between %s and %s for good?\n\nEvery message and file goes from both sides. This cannot be undone.', c.a, c.b),
            {kind: 'conversation', a: c.a, b: c.b}, show)},
        ]);
      });
      body.replaceChildren(el('h2', '', t('Private channels')), part(channels, q ? t('None match.') : t('There are none.')),
        el('h2', '', t('Private conversations')), part(talks, q ? t('None match.') : t('There are none.')));
    };
    const show = async function () {
      list = await get('/api/admin/private');
      fill();
    };
    find.addEventListener('input', fill);
    box.append(el('p', 'hint', t('Who talks in private and how much. What they say does not come here.')), find, body);
    show().catch(failed);
  }

  // The permission grid: a row for each permission, a column for each role.
  // a role as the admin pages show it: the channel roles by the word channel
  function roleTitle(name) {
    return {owner: t('channel owner'), 'room-moderator': t('channel moderator')}[name] || name;
  }

  function adminPermissions(box, data) {
    box.appendChild(el('p', 'hint', t('Tick which roles may do what. Admins may always do everything. The channel roles (channel owner, channel moderator) count only in their channel. To give one member one extra right, make a role with it and give them that role under Members.')));
    const wrap = el('div', 'gridwrap');
    const table = el('table', 'grid perms');
    const headRow = el('tr');
    headRow.appendChild(el('th', '', ''));
    for (const r of data.roles) {
      const th = el('th', r.scope === 'room' ? 'roomrole' : '', roleTitle(r.name));
      th.title = r.caption;
      headRow.appendChild(th);
    }
    table.appendChild(headRow);
    for (const p of data.permissions) {
      const tr = el('tr');
      const name = el('td', 'pname', t(p.caption));
      name.title = p.name;
      tr.appendChild(name);
      const have = p.roles.split(',').filter(Boolean);
      for (const r of data.roles) {
        const td = el('td');
        const box2 = el('input');
        box2.type = 'checkbox';
        box2.checked = r.name === 'admin' || have.indexOf(r.name) >= 0;
        box2.disabled = r.name === 'admin';
        box2.title = roleTitle(r.name) + ': ' + t(p.caption);
        box2.addEventListener('change', async function () {
          if (box2.checked) have.push(r.name);
          else have.splice(have.indexOf(r.name), 1);
          try { await post('/api/admin/permission', {name: p.name, roles: have.join(',')}); }
          catch (err) { failed(err); box2.checked = !box2.checked; }
        });
        td.appendChild(box2);
        tr.appendChild(td);
      }
      table.appendChild(tr);
    }
    wrap.appendChild(table);
    box.appendChild(wrap);

    box.appendChild(el('h2', '', t('Roles')));
    const roles = el('table', 'grid');
    for (const r of data.roles) {
      const tr = el('tr');
      tr.append(el('td', '', roleTitle(r.name)), el('td', 'dim', r.scope === 'room' ? t('in one channel') : t('site')),
        el('td', 'dim', r.caption));
      const td = el('td');
      if (!r.builtin) {
        const x = el('button', 'small-link', t('Delete'));
        x.type = 'button';
        x.addEventListener('click', async function () {
          if (!confirm(t('Delete the role %s? Members who have it lose it.', r.name))) return;
          try { await post('/api/admin/role', {name: r.name, delete: '1'}); route('/admin', false); } catch (err) { failed(err); }
        });
        td.appendChild(x);
      }
      tr.appendChild(td);
      roles.appendChild(tr);
    }
    box.appendChild(roles);
    const form = el('form', 'invite');
    const name = el('input');
    name.placeholder = t('new-role');
    const caption = el('input');
    caption.placeholder = t('What it is for');
    const scope = el('select');
    [['site', t('site')], ['room', t('in one channel')]].forEach(function (o) {
      const opt = el('option', '', o[1]);
      opt.value = o[0];
      scope.appendChild(opt);
    });
    const add = el('button', 'primary', t('Make the role'));
    form.append(name, caption, scope, add);
    form.addEventListener('submit', async function (e) {
      e.preventDefault();
      try {
        await post('/api/admin/role', {name: name.value, caption: caption.value, scope: scope.value});
        route('/admin', false);
      } catch (err) { failed(err); }
    });
    box.appendChild(form);
  }

  // Members as a list: sorted by any column on the server, a role or bans
  // picked out; the one picked below with its roles and the ban.
  function adminMembers(box, data, can) {
    const giveable = data.roles.filter(function (r) {
      return r.scope === 'site' && r.name !== 'member' && r.name !== 'guest';
    });
    const detail = function (u, holder, view) {
      const head = el('div', 'lv-detail-head');
      head.appendChild(link('/u/' + enc(u.name), '', u.name));
      if (u.banned) head.appendChild(chip(t('Banned'), 'bad'));
      if (u.closed) head.appendChild(chip(t('Closed'), 'bad'));
      holder.appendChild(head);
      facts(holder, [[t('Joined'), u.joined ? dateText(u.joined) : ''], [t('Last here'), u.seen ? ago(u.seen) : t('never back')],
        [t('Messages'), u.posts.toLocaleString(locale)]].concat(u.closed ? [[t('Closed'), dateText(u.closed)],
        [t('Closed by'), u.closed_by === u.name ? t('the member') : u.closed_by], [t('Reason'), u.closed_reason]] : []));
      // admins only (view-member-addresses): the server sends them to nobody else
      if (u.addresses) {
        const sect = el('div', 'member-addresses');
        sect.appendChild(el('h4', '', u.address_count > u.addresses.length
          ? t('Addresses: the %d newest of %d', u.addresses.length, u.address_count) : t('Addresses')));
        const panel = el('div', 'lv-detail');
        const list = el('ul', 'member-address-list');
        for (const a of u.addresses) {
          const li = el('li');
          const b = el('button', 'lv-link', a.ip);
          b.type = 'button';
          b.title = t('Its whole story under Address: score, blocks, requests');
          b.addEventListener('click', function () {
            // the address panel reads the logs from the day before it was last seen, at most 30 days back
            const today = new Date().toISOString().slice(0, 10);
            const back = new Date(Math.max(Date.parse(a.seen) - 864e5, Date.now() - 30 * 864e5)).toISOString().slice(0, 10);
            addressPanel(a.ip, panel, {from: back, to: today});
          });
          li.append(b, document.createTextNode(' ' + ago(a.seen) + ', ' + tn(a.times, '%d time', '%d times')));
          list.appendChild(li);
        }
        sect.append(list, panel);
        holder.appendChild(sect);
      }
      const have = u.roles.split(',').filter(Boolean);
      const roles = el('div', 'lv-actions rolechecks');
      // a closed account holds no role; it can be opened again, or renamed
      roles.hidden = !!u.closed;
      roles.appendChild(el('span', 'dim', t('Roles') + ':'));
      for (const r of giveable) {
        const label = el('label');
        const c = el('input');
        c.type = 'checkbox';
        c.checked = have.indexOf(r.name) >= 0;
        c.disabled = u.name === Me.name || !can('manage-members');
        c.addEventListener('change', async function () {
          if (c.checked) have.push(r.name); else have.splice(have.indexOf(r.name), 1);
          try { toast(await post('/api/admin/member', {name: u.name, roles: have.join(',')})); u.roles = have.join(','); view.changed(u); }
          catch (err) { failed(err); c.checked = !c.checked; }
        });
        label.append(c, document.createTextNode(' ' + r.name));
        roles.appendChild(label);
      }
      holder.appendChild(roles);
      if (u.name === Me.name) { holder.appendChild(el('p', 'hint', t('Ask another admin to change your own account.'))); return; }
      const acts = el('div', 'lv-actions');
      const act = function (caption, cls, run) {
        const b = el('button', cls, caption);
        b.type = 'button';
        b.addEventListener('click', async function () {
          try { await run(); } catch (err) { failed(err); }
        });
        acts.appendChild(b);
      };
      const again = function () { view.unpick(); view.reload(); };
      if (u.closed) {
        if (can('manage-members')) act(t('Reopen the account'), '', async function () {
          toast(await post('/api/admin/member', {name: u.name, reopen: '1'}));
          toast(t('It has no password now: make a password link for %s.', u.name));
          again();
        });
      } else if (can('ban')) act(u.banned ? t('Lift the ban') : t('Ban'), u.banned ? '' : 'bad', async function () {
        if (!u.banned && !confirm(t('Ban %s? They are signed out and can only read.', u.name))) return;
        toast(await post('/api/admin/member', {name: u.name, banned: u.banned ? '0' : '1'}));
        u.banned = !u.banned;
        view.changed(u);
      });
      if (can('manage-members')) {
        // for a member who cannot get in: the link is shown once, to hand over
        if (!u.closed) act(t('Password link'), '', async function () {
          let address = (await post('/api/admin/member', {name: u.name, password_link: '1'})).trim();
          if (address.charAt(0) === '/') address = location.origin + SiteBase.url(address);
          const shown = el('pre', 'newtoken', address);
          const copy = el('button', '', t('Copy'));
          copy.type = 'button';
          copy.addEventListener('click', function () {
            navigator.clipboard.writeText(address).then(function () { copy.textContent = t('Copied'); });
          });
          const made = el('div', 'lv-actions member-link');
          made.append(shown, copy, el('p', 'hint', t('Give this link to %s. It sets a new password, works once and for a week. Private conversations locked with the old password stay closed.', u.name)));
          const old = $('.member-link', holder);
          if (old) old.replaceWith(made); else acts.after(made);
        });
        act(t('Rename'), '', async function () {
          const name = prompt(t('A new name for %s. Mentions of the old name stay as they were written.', u.name), u.name);
          if (!name || name.trim() === u.name) return;
          toast(await post('/api/admin/member', {name: u.name, rename: name.trim()}));
          again();
        });
        if (!u.closed) act(t('Close the account'), 'bad', async function () {
          const reason = prompt(t('Close the account of %s? They are signed out for good; their address, password and profile are wiped, and what they wrote stays. Why? (kept with the account)', u.name), '');
          if (!reason || !reason.trim()) return;
          toast(await post('/api/admin/member', {name: u.name, close: '1', reason: reason.trim()}));
          again();
        });
      }
      if (acts.children.length) holder.appendChild(acts);
    };
    listView(box, {
      id: 'members', key: function (u) { return u.name; }, sort: '-seen', csv: 'members',
      search: can('view-member-addresses') ? t('Find a member by name or address') : t('Find a member by name'),
      remote: function (s) {
        return get('/api/admin/members?q=' + enc(s.q) + '&sort=' + enc(s.sort) + '&role=' + enc(s.filters.role || '') +
          '&state=' + enc(s.filters.state || '') + '&page=' + s.page).then(function (a) { return {rows: a.members, total: a.total}; });
      },
      columns: [
        {key: 'name', title: t('Member'), cell: function (u) { return link('/u/' + enc(u.name), '', u.name); }},
        {key: 'roles', title: t('Roles'), nosort: true, cell: function (u) {
          const span = el('span', 'chips');
          for (const r of u.roles.split(',').filter(Boolean)) span.appendChild(chip(r, r === 'admin' ? 'admin' : ''));
          if (u.banned) span.appendChild(chip(t('Banned'), 'bad'));
          if (u.closed) span.appendChild(chip(t('Closed'), 'bad'));
          return span;
        }},
        {key: 'posts', title: t('Messages'), num: true},
        {key: 'joined', title: t('Joined'), down: true, wide: true, cell: function (u) { return u.joined ? dateText(u.joined) : ''; }},
        {key: 'seen', title: t('Last here'), down: true, cell: function (u) { return u.seen ? ago(u.seen) : t('never back'); }}
      ].concat(can('view-member-addresses') ? [
        {key: 'addresses', title: t('Address'), nosort: true, wide: true, cell: function (u) {
          if (!u.addresses || !u.addresses.length) return '';
          return u.addresses[0].ip + (u.address_count > 1 ? ' +' + (u.address_count - 1) : '');
        }}] : []),
      filters: [
        {key: 'role', title: t('Role'), all: t('Every role'), options: giveable.map(function (r) { return [r.name, r.name]; }).concat([['none', t('No role given')]])},
        {key: 'state', title: t('Banned or closed'), all: t('Everyone'), options: [['active', t('Neither')], ['banned', t('Banned')], ['closed', t('Closed')]]}
      ],
      noun: function (n) { return tn(n, '%d member', '%d members'); },
      detail: detail
    });
  }

  C.listView = listView;
  C.stat = stat;
  C.adminTable = adminTable;
  C.openAdmin = openAdmin;
})();
