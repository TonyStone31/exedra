// Corner chat: the page's bench, last-used room or site's open channel.
// Members can post and see unread counts; visitors see who is here. A
// teaser appears once a visit; [data-live-room] shows a bench's latest
// messages. Build all member text as text nodes.
(function () {
  'use strict';
  const spot = document.querySelector('[data-live-strip]');
  // the glimpse boxes on the page: not the bubble's spot, which names a room too
  const glimpses = Array.prototype.slice.call(document.querySelectorAll('[data-live-room]:not([data-live-strip])'));
  if (!spot && !glimpses.length) return;
  // on another site (embed.js): every request and link goes to the chat's
  // own address, with no cookies, and links open there in a new tab
  const base = spot ? (spot.getAttribute('data-live-base') || '') : '';
  function U(path) { return base + path; }
  // the corner chat's stylesheet comes from where this script came from; it is shown once that is in
  const styles = document.createElement('link');
  styles.rel = 'stylesheet';
  styles.href = U('/static/live.css') + ((document.currentScript && /\?v=[^&]*/.exec(document.currentScript.src)) || [''])[0];
  if (spot) document.head.appendChild(styles);
  function away(a) { if (base) { a.target = '_blank'; a.rel = 'noopener'; } return a; }
  const t = window.t || function (s) { return s; };
  const tn = window.tn || function (n, one, many) { return (n === 1 ? one : many).replace('%d', n); };
  const lang = document.documentElement.lang || 'en';
  let relative = null;
  try { relative = new Intl.RelativeTimeFormat(lang, {numeric: 'auto'}); } catch (e) { }

  function ago(iso) {
    const seconds = (Date.parse(iso) - Date.now()) / 1000;
    if (!relative || isNaN(seconds)) return '';
    const steps = [[60, 'second'], [3600, 'minute'], [86400, 'hour'], [604800, 'day'], [2629800, 'week'], [31557600, 'month'], [Infinity, 'year']];
    const sizes = {second: 1, minute: 60, hour: 3600, day: 86400, week: 604800, month: 2629800, year: 31557600};
    for (const [limit, unit] of steps) {
      if (Math.abs(seconds) < limit) {
        if (unit === 'second') return relative.format(0, 'second');
        return relative.format(Math.round(seconds / sizes[unit]), unit);
      }
    }
    return '';
  }

  function el(tag, cls, text) {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text !== undefined) e.textContent = text;
    return e;
  }

  function benchIcon() {
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('viewBox', '0 0 24 24');
    svg.setAttribute('aria-hidden', 'true');
    const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    path.setAttribute('d', 'M3 10h18M5 10v8M19 10v8M3 14h18M6 6h12');
    path.setAttribute('fill', 'none');
    path.setAttribute('stroke', 'currentColor');
    path.setAttribute('stroke-width', '2');
    path.setAttribute('stroke-linecap', 'round');
    svg.appendChild(path);
    return svg;
  }

  async function getJson(url) {
    const r = await fetch(U(url), {credentials: base ? 'omit' : 'same-origin', cache: 'no-store'});
    if (!r.ok) throw Object.assign(new Error(await r.text()), {status: r.status});
    return r.json();
  }
  function remember(key, value) { try { localStorage.setItem(key, value); } catch (e) { } }
  function recall(key) { try { return localStorage.getItem(key) || ''; } catch (e) { return ''; } }
  function session(key, value) {
    try { if (value === undefined) return sessionStorage.getItem(key) || ''; sessionStorage.setItem(key, value); } catch (e) { }
    return '';
  }

  // ---- a bench's glimpse on its page
  async function refreshGlimpse(box) {
    let data;
    try { data = await getJson('/api/live?room=' + encodeURIComponent(box.getAttribute('data-live-room'))); } catch (e) { return; }
    const list = (data.messages || []).slice().reverse();
    box.replaceChildren();
    if (!list.length) {
      box.appendChild(el('p', 'glimpse-empty', t('Nothing said here yet. Be the first.')));
      return;
    }
    const head = el('p', 'glimpse-head', t('Latest at its bench'));
    if (data.here > 0) head.appendChild(el('span', 'live-here', ' · ' + tn(data.here, '%d here now', '%d here now')));
    box.appendChild(head);
    const ol = el('ol', 'glimpse-list');
    for (const m of list) {
      const li = el('li');
      li.appendChild(el('b', 'live-who', m.name));
      li.appendChild(el('time', 'live-when', ago(m.at)));
      li.appendChild(el('span', 'live-text', m.text));
      ol.appendChild(li);
    }
    box.appendChild(ol);
  }

  // ---- the bubble and its sheet
  if (!spot) { glimpses.forEach(refreshGlimpse); return; }
  // a reader on another site counts as a visitor: no cookies go there
  const member = !base && !!document.querySelector('.account .me');
  // the page's own bench when it has one; else the room last used in the
  // chat; else the site's open channel (asked for when the page named none)
  const own = spot.getAttribute('data-live-room') || (glimpses[0] ? glimpses[0].getAttribute('data-live-room') : '');
  let room = own || recall('last-room') || spot.getAttribute('data-live-default') || '';
  // the page a bench can be opened for, and whether this reader may
  const pageKey = spot.getAttribute('data-live-page') || '';
  const pageTitle = spot.getAttribute('data-live-title') || '';
  const canBench = spot.getAttribute('data-live-can-bench') || '';
  const pageHeading = document.querySelector('h1') ? document.querySelector('h1').textContent.trim() : '';

  if (styles.sheet) spot.hidden = false;
  else styles.onload = styles.onerror = function () { spot.hidden = false; };
  spot.className = 'live-bench';
  spot.replaceChildren();
  const bubble = el('button', 'live-bubble');
  bubble.type = 'button';
  bubble.setAttribute('aria-label', t('Live chat'));
  bubble.title = t('Live chat');
  bubble.appendChild(benchIcon());
  const badge = el('span', 'live-badge', '');
  badge.hidden = true;
  bubble.appendChild(badge);
  // a line of the latest talk beside the button, once a visit
  const teaser = el('button', 'live-teaser');
  teaser.type = 'button';
  const teaserWho = el('b'), teaserText = el('span', 'live-teaser-text'), teaserWhen = el('time');
  teaser.append(teaserWho, teaserText, teaserWhen);
  const teaserOff = el('button', 'live-teaser-off', '×');
  teaserOff.type = 'button';
  teaserOff.title = t('Not now');
  teaserOff.setAttribute('aria-label', t('Not now'));
  const teaserRow = el('div', 'live-teaser-row');
  teaserRow.hidden = true;
  teaserRow.append(teaser, teaserOff);
  spot.appendChild(teaserRow);
  spot.appendChild(bubble);

  const panel = el('section', 'live-sheet');
  panel.hidden = true;
  panel.setAttribute('aria-label', t('Live chat'));
  const head = el('header', 'live-sheet-head');
  const title = el('div', 'live-sheet-title');
  title.appendChild(benchIcon());
  const titleText = el('div');
  const titleName = el('b', '', own ? (pageHeading || room) : '#' + room);
  titleText.appendChild(titleName);
  const here = el('span', 'live-sheet-here', own ? t('Live bench') : t('Live chat'));
  titleText.appendChild(here);
  title.appendChild(titleText);
  head.appendChild(title);
  const open = el('a', 'live-sheet-open', t('Open the chat'));
  open.href = U('/p/' + encodeURIComponent(room));
  away(open);
  head.appendChild(open);
  const fold = el('button', 'live-sheet-fold', '–');
  fold.type = 'button';
  fold.title = t('Minimize');
  fold.setAttribute('aria-label', t('Minimize'));
  head.appendChild(fold);
  panel.appendChild(head);
  // for a member: where there is something new for them
  const news = el('nav', 'live-news');
  news.hidden = true;
  news.setAttribute('aria-label', t('New for you'));
  panel.appendChild(news);
  const list = el('div', 'live-sheet-list');
  list.setAttribute('role', 'log');
  list.setAttribute('aria-live', 'polite');
  panel.appendChild(list);
  const foot = el('div', 'live-sheet-foot');
  panel.appendChild(foot);
  spot.insertBefore(panel, teaserRow);

  let shown = false;
  let timer = null;
  // what was drawn last: an edit or a deletion changes it, not only a new message
  let lastSeen = '';
  // which room the sheet is on: an answer that comes back for an earlier one is dropped
  let generation = 0;
  function switchRoom(slug) {
    room = slug;
    generation++;
    lastSeen = '';
    open.href = U('/p/' + encodeURIComponent(room));
  }

  // the room's own name, kind and whether it is readable at all: a room
  // remembered from the chat may have gone, in which case the site's channel
  async function describeRoom() {
    const mine = generation;
    let info = null;
    try { info = await getJson('/api/room?slug=' + encodeURIComponent(room)); } catch (e) {
      if (mine !== generation) return;
      if (!own && room !== spot.getAttribute('data-live-default') && spot.getAttribute('data-live-default')) {
        switchRoom(spot.getAttribute('data-live-default'));
        titleName.textContent = '#' + room;
        return describeRoom();
      }
      return;
    }
    if (mine !== generation) return;
    if (info && info.title) titleName.textContent = own ? (info.title || pageHeading) : info.kind === 'channel' ? '#' + info.slug : info.title;
    here.textContent = own ? t('Live bench') : info && info.kind === 'channel' ? t('Live chat') : t('Live bench');
  }

  function show(on) {
    shown = on;
    panel.hidden = !on;
    bubble.classList.toggle('open', on);
    session('live-open', on ? '1' : '0');
    if (on) hideTeaser();
    // one timer at most, however often it is opened
    if (timer) { clearInterval(timer); timer = null; }
    if (on) { refreshList(true); refreshNews(); timer = setInterval(refreshList, 6000); }
  }
  bubble.addEventListener('click', function () { show(!shown); });
  fold.addEventListener('click', function () { show(false); });

  async function refreshList(first) {
    if (document.visibilityState === 'hidden') return;
    const mine = generation;
    let data;
    try { data = await getJson('/api/messages?room=' + encodeURIComponent(room)); } catch (e) {
      if (first && mine === generation) list.replaceChildren(el('p', 'live-sheet-empty', t('The chat could not be reached.')));
      return;
    }
    if (mine !== generation) return;
    // not what was deleted, and not the members this reader ignores
    const messages = (data.messages || []).filter(function (m) { return !m.deleted && !m.ignored && m.body; }).reverse().slice(-40);
    const seen = JSON.stringify(messages.map(function (m) { return [m.id, m.body, m.edited || '']; }));
    if (!first && seen === lastSeen) return;
    const atBottom = first || list.scrollHeight - list.scrollTop - list.clientHeight < 80;
    list.replaceChildren();
    if (!messages.length) list.appendChild(el('p', 'live-sheet-empty', t('Nothing said here yet. Be the first.')));
    let lastName = '';
    for (const m of messages) {
      // a message is a way into the chat, at that very message
      const row = el('a', 'live-msg' + (m.name === lastName ? ' same' : ''));
      row.href = U('/m/' + encodeURIComponent(m.id));
      away(row);
      row.title = t('Open in the chat');
      if (m.name !== lastName) {
        const who = el('div', 'live-msg-who');
        who.appendChild(el('b', '', m.name));
        who.appendChild(el('time', '', ago(m.at)));
        row.appendChild(who);
      }
      // an action (/me waves) is stored as *Ann waves*: shown as the chat shows it
      const action = m.body.startsWith('*' + m.name + ' ') && m.body.endsWith('*');
      row.appendChild(el('div', 'live-msg-text' + (action ? ' action' : ''), action ? m.body.slice(1, -1) : m.body));
      list.appendChild(row);
      lastName = m.name;
    }
    lastSeen = seen;
    if (atBottom) list.scrollTop = list.scrollHeight;
    if (member && atBottom) markRead(data);
  }

  // ---- read here is read: the mark the chat's own page leaves as it syncs,
  // so the badge and the chat's sidebar stop counting what was seen here
  async function markRead(data) {
    const newest = Math.max.apply(null, (data.messages || []).map(function (m) { return m.id; }));
    if (!(newest > data.last_read)) return;
    try { await getJson('/api/sync?' + new URLSearchParams({room: room, since: data.rev, read: newest})); } catch (e) { return; }
    newsAsked = 0;
    refreshNews();
  }

  // ---- a member's news: the rooms they follow with something unread, as
  // the chat's sidebar counts it: a silenced room (notify none) counts
  // nothing, a mentions-only room counts its mentions.  Asked for at most
  // once in twenty seconds: the answer costs the server a query a room.
  let newsAsked = 0;
  function countOf(r) { return r.notify === 'none' ? 0 : r.notify === 'mentions' ? (r.mentions || 0) : (r.unread || 0); }
  async function refreshNews() {
    if (!member || document.visibilityState === 'hidden' || Date.now() - newsAsked < 20000) return;
    newsAsked = Date.now();
    let rooms;
    try { rooms = await getJson('/api/rooms'); } catch (e) { return; }
    const fresh = (rooms || []).filter(function (r) { return countOf(r) > 0; });
    let total = 0, mentions = 0;
    for (const r of fresh) { total += countOf(r); if (r.notify !== 'none') mentions += r.mentions || 0; }
    badge.hidden = total === 0;
    badge.textContent = total > 99 ? '99+' : String(total);
    badge.classList.toggle('mention', mentions > 0);
    bubble.title = total ? tn(total, '%d unread message in the chat', '%d unread messages in the chat') : t('Live chat');
    news.replaceChildren();
    news.hidden = !fresh.length;
    if (!fresh.length) return;
    news.appendChild(el('span', 'live-news-lead', t('New for you:')));
    fresh.sort(function (a, b) { return (b.mentions - a.mentions) || (b.unread - a.unread); });
    for (const r of fresh.slice(0, 6)) {
      const a = el('a', 'live-news-room' + (r.mentions ? ' mention' : ''));
      a.href = U(r.kind === 'shelf' ? '/u/' + encodeURIComponent(r.title) : '/p/' + encodeURIComponent(r.slug));
      a.append(el('span', '', r.kind === 'channel' ? '#' + r.slug : r.title), el('b', '', countOf(r) > 99 ? '99+' : String(countOf(r))));
      a.title = r.mentions ? tn(r.mentions, '%d mention of you', '%d mentions of you') : tn(countOf(r), '%d unread', '%d unread');
      news.appendChild(a);
    }
    if (fresh.length > 6) news.appendChild(el('a', 'live-news-more', tn(fresh.length - 6, 'and %d more', 'and %d more'))).href = '/';
  }

  // ---- the way to speak: a box for a member, an invitation for a visitor;
  // and a bench for the page, when it has none and this reader may open one
  function benchOffer() {
    if (!pageKey || own) return null;
    const box = el('div', 'live-make');
    if (canBench === 'yes') {
      const b = el('button', 'live-make-bench', t('Open a bench for this page'));
      b.type = 'button';
      b.title = pageTitle;
      const note = el('span', 'live-make-note');
      b.addEventListener('click', async function () {
        b.disabled = true;
        note.textContent = '';
        const parts = pageKey.split(':');
        try {
          const r = await fetch('/page-bench', {method: 'POST', credentials: 'same-origin',
            body: new URLSearchParams({kind: parts[0], key: parts.slice(1).join(':')})});
          if (!r.ok) { note.textContent = (await r.text()).slice(0, 200); b.disabled = false; return; }
          const made = await r.json();
          remember('last-room', made.room);
          location.href = made.url;
        } catch (e) {
          note.textContent = t('The chat could not be reached.');
          b.disabled = false;
        }
      });
      box.append(b, note);
    } else if (canBench === 'embed') {
      // a page on another site: the chat's own site opens the bench, signed in there
      const a = away(el('a', 'live-make-bench', t('Open a bench for this page')));
      a.href = U('/embed/bench?url=' + encodeURIComponent(pageKey.slice(pageKey.indexOf(':') + 1)));
      a.title = pageTitle;
      box.appendChild(a);
    } else if (canBench === 'signin') {
      const a = el('a', 'live-make-signin', t('Sign in to open a bench for this page'));
      a.href = '/signin?return=' + encodeURIComponent(location.pathname + location.search);
      box.appendChild(a);
    } else return null;
    return box;
  }
  const offer = benchOffer();
  if (offer) foot.appendChild(offer);
  if (member) {
    const form = el('form', 'live-say');
    const box = el('textarea');
    box.rows = 1;
    box.maxLength = 8000;
    box.placeholder = t('Say something…');
    box.setAttribute('aria-label', t('Say something…'));
    const send = el('button', 'live-send', t('Send'));
    send.type = 'submit';
    form.append(box, send);
    const note = el('p', 'live-say-note');
    const sent = el('p', 'live-sent');
    sent.hidden = true;
    const goOn = el('a', '', t('Continue in the chat'));
    sent.append(t('Sent.') + ' ', goOn);
    foot.append(form, note, sent);
    box.addEventListener('keydown', function (event) {
      if (event.key === 'Enter' && !event.shiftKey) { event.preventDefault(); if (form.requestSubmit) form.requestSubmit(); else send.click(); }
    });
    form.addEventListener('submit', async function (event) {
      event.preventDefault();
      const words = box.value.trim();
      if (!words) return;
      send.disabled = true;
      note.textContent = '';
      sent.hidden = true;
      try {
        const r = await fetch('/api/post', {method: 'POST', credentials: 'same-origin', body: new URLSearchParams({room: room, body: words})});
        if (!r.ok) { note.textContent = (await r.text()).slice(0, 200); return; }
        box.value = '';
        remember('last-room', room);
        goOn.href = '/p/' + encodeURIComponent(room);
        sent.hidden = false;
        await refreshList(true);
      } catch (e) {
        note.textContent = t('The chat could not be reached.');
      } finally {
        send.disabled = false;
        box.focus();
      }
    });
  } else {
    const invite = el('p', 'live-invite', t('Read along, or join to say something here.') + ' ');
    const join = el('a', 'button', t('Join'));
    join.href = base ? U('/p/' + encodeURIComponent(room)) : '/signin?return=' + encodeURIComponent(location.pathname + location.search);
    away(join);
    invite.appendChild(join);
    foot.appendChild(invite);
  }

  // ---- who is there: the pulse on the bubble, the line under the title,
  // and for a visitor the badge
  async function refreshHere() {
    if (document.visibilityState === 'hidden') return;
    let data;
    try { data = await getJson('/api/live?room=' + encodeURIComponent(room)); } catch (e) { return; }
    const n = data.here || 0;
    if (!member) {
      badge.hidden = n === 0;
      badge.textContent = String(n);
      bubble.title = n > 0 ? tn(n, '%d here now', '%d here now') : t('Live chat');
    }
    bubble.classList.toggle('busy', n > 0);
    if (n > 0) here.textContent = tn(n, '%d here now', '%d here now');
    else here.textContent = own ? t('Live bench') : t('Live chat');
  }

  // ---- the teaser: the latest line said at the page's bench, or anywhere
  // on the site, once a visit, while it is less than a day old
  let teaserTimer = null;
  function hideTeaser() {
    teaserRow.hidden = true;
    if (teaserTimer) { clearTimeout(teaserTimer); teaserTimer = null; }
  }
  async function tease() {
    if (session('live-teased') || session('live-open') === '1') return;
    let data;
    try { data = await getJson(own ? '/api/live?room=' + encodeURIComponent(room) : '/api/live'); } catch (e) { return; }
    const m = (data.messages || [])[0];
    if (!m || Date.now() - Date.parse(m.at) > 86400000) return;
    session('live-teased', '1');
    teaserWho.textContent = m.name + (own || !m.room ? '' : ' ' + t('in') + ' ' + (m.kind === 'channel' ? '#' + m.room : m.title)) + ':';
    // an action's words begin with the name, which is not said twice
    teaserText.textContent = ' ' + (m.text.startsWith(m.name + ' ') ? m.text.slice(m.name.length + 1) : m.text) + ' ';
    teaserWhen.textContent = ago(m.at);
    teaser.title = t('Open the chat');
    teaser.addEventListener('click', function () {
      // a line from another room opens that room
      if (!own && m.room && m.room !== room) {
        switchRoom(m.room);
        titleName.textContent = m.kind === 'channel' ? '#' + m.room : m.title;
        describeRoom();
      }
      show(true);
    });
    teaserOff.addEventListener('click', hideTeaser);
    teaserRow.hidden = false;
    teaserTimer = setTimeout(hideTeaser, 20000);
  }

  let openAtStart = session('live-open') === '1';
  // a bench just opened for this page, or the page asking for it: the sheet opens
  if (new URLSearchParams(location.search).get('bench') === 'open') openAtStart = true;
  describeRoom();
  if (openAtStart) show(true);
  // the page's bench card: its way in opens the live bench here rather than leaving
  for (const a of document.querySelectorAll('.page-bench a[href="/p/' + room + '"], .catalog-room a[href="/p/' + room + '"]')) {
    a.addEventListener('click', function (event) {
      if (event.metaKey || event.ctrlKey) return;
      event.preventDefault();
      show(true);
      panel.scrollIntoView({block: 'nearest'});
    });
  }
  refreshHere();
  setInterval(refreshHere, 30000);
  if (member) {
    refreshNews();
    setInterval(refreshNews, 180000);
  }
  setTimeout(tease, 2500);
  document.addEventListener('visibilitychange', function () {
    if (document.visibilityState === 'visible') { refreshHere(); if (shown) refreshList(); if (member) refreshNews(); }
  });
  glimpses.forEach(refreshGlimpse);
  setInterval(function () { glimpses.forEach(refreshGlimpse); }, 30000);
})();
