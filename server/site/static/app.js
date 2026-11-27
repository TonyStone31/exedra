// The site's page: account, profiles, the side panel and the admin page,
// moving between them without reloading.  Everything it shows comes from
// the JSON API.  The parts of the suite that live on this page add
// themselves to Chat.parts (chat.js: rooms, threads, private conversations)
// and answer for their own addresses, the side list and the live updates.
(function () {
  'use strict';

  const body = document.body;
  const Me = {name: body.dataset.me || '', can: [], ignores: [], reactions: {shown: [], more: []}};
  const Site = body.dataset.site;
  const $ = function (s, root) { return (root || document).querySelector(s); };
  const stream = $('#stream');
  const panel = $('#panel');

  const S = {
    view: '', room: '', info: null, messages: new Map(), since: 0, lastRead: 0, divider: 0,
    oldest: Infinity, older: true, thread: 0, threadMessages: new Map(), generation: 0,
    rooms: [], dms: [], commands: null, typingSent: 0, tick: 0, alerts: {},
    dm: '', dmLast: 0, dmFirst: 0, dmTimer: 0, beams: {}, typers: {}, here: []
  };

  // What the member may do anywhere, from /api/me.
  function may(p) { return Me.can.indexOf(p) >= 0; }
  // What the member may do in the open room, from /api/room.
  function mayHere(p) { return !!(S.info && S.info.can && S.info.can[p]); }

  // ---------------------------------------------------------------- helpers

  // drawn the same in every module: side.js
  const el = Side.el, link = Side.link, avatar = Side.avatar,
    Icons = Side.icons, icon = Side.icon, iconButton = Side.iconButton;

  async function get(url) {
    const answer = await fetch(url);
    if (!answer.ok) throw new Error(await answer.text());
    return answer.json();
  }

  const post = Keys.post;

  function toast(text, kind) {
    const t = el('div', 'toast ' + (kind || ''), text);
    $('#toasts').appendChild(t);
    setTimeout(function () { t.classList.add('going'); }, 4500);
    setTimeout(function () { t.remove(); }, 5000);
  }

  // The last things that went wrong on this page, for a bug report.
  const Trail = [];
  function remember(what) {
    Trail.push(new Date().toISOString().slice(11, 19) + ' ' + what);
    if (Trail.length > 15) Trail.shift();
  }
  window.addEventListener('error', function (e) { remember('error: ' + e.message + ' (' + e.filename + ':' + e.lineno + ')'); });
  window.addEventListener('unhandledrejection', function (e) { remember('promise: ' + (e.reason && e.reason.message || e.reason)); });

  function failed(err) {
    remember('shown: ' + (err.message || String(err)));
    toast(err.message || String(err), 'bad');
  }

  // A color for a name: names that differ by one letter still look different.
  let locale;
  try { locale = Intl.getCanonicalLocales(document.documentElement.lang || '')[0]; } catch (err) { }

  function clock(at) {
    const d = new Date(at);
    return isNaN(d) ? at : d.toLocaleTimeString(locale, {hour: '2-digit', minute: '2-digit'});
  }

  function dayLabel(d) {
    const today = new Date();
    const yesterday = new Date(Date.now() - 86400000);
    if (d.toDateString() === today.toDateString()) return t('Today');
    if (d.toDateString() === yesterday.toDateString()) return t('Yesterday');
    if (d.getFullYear() !== today.getFullYear())
      return d.toLocaleDateString(locale, {weekday: 'long', month: 'long', day: 'numeric', year: 'numeric'});
    return d.toLocaleDateString(locale, {weekday: 'long', month: 'long', day: 'numeric'});
  }

  function ago(iso) {
    if (!iso) return '';
    const minutes = Math.round((Date.now() - new Date(iso)) / 60000);
    if (minutes < 2) return t('just now');
    if (minutes < 60) return tn(minutes, '%d min ago', '%d min ago');
    if (minutes < 48 * 60) return tn(Math.round(minutes / 60), '%d hours ago', '%d hours ago');
    return tn(Math.round(minutes / 1440), '%d days ago', '%d days ago');
  }

  function sizeText(n) {
    if (n < 1024) return t('%d B', n);
    if (n < 1024 * 1024) return t('%d KB', Math.round(n / 1024));
    if (n < 1024 * 1024 * 1024) return t('%s MB', (n / 1024 / 1024).toFixed(1));
    if (n < 1024 * 1024 * 1024 * 1024) return t('%s GB', (n / 1024 / 1024 / 1024).toFixed(1));
    return t('%s TB', (n / 1024 / 1024 / 1024 / 1024).toFixed(2));
  }

  function nearBottom(box) {
    box = box || stream;
    return box.scrollHeight - box.scrollTop - box.clientHeight < 160;
  }

  // A list read at its bottom stays there when it gets shorter (a phone's
  // keyboard opening, the composer growing) or a message in it gets taller
  // (a reaction, an edit, a picture arriving): neither sends a scroll
  // event.  Watched are the list and each message drawn (chat.js).
  const pinWatch = new ResizeObserver(function (entries) {
    for (const e of entries) {
      const box = 'pinned' in e.target ? e.target : e.target.parentNode;
      if (!e.target.isConnected) pinWatch.unobserve(e.target);
      else if (box.pinned && !box.noPin) {
        box.scrollTop = box.scrollHeight;
        box.pinTop = box.scrollTop;
      }
    }
  });
  function keepPinned(box) {
    box.pinned = true;
    // The scroll event of the watch's own move comes a frame late: a list
    // still where the watch put it has not been left, however far its bottom now is.
    box.addEventListener('scroll', function () {
      box.pinned = !box.noPin && (nearBottom(box) || box.scrollTop === box.pinTop);
      box.pinTop = -1;
    });
    pinWatch.observe(box);
  }
  keepPinned(stream);

  // A phone browser that ignores interactive-widget leaves the page its full
  // height under the keyboard; the page then takes the height shown.  Not
  // while zoomed in, where the shown part is smaller on purpose.
  if (window.visualViewport) {
    const fitShown = function () {
      const view = window.visualViewport;
      const root = document.documentElement;
      if (Math.abs(view.scale - 1) < 0.01 && view.height < root.clientHeight - 1) {
        root.style.setProperty('--shown-height', view.height + 'px');
        root.style.setProperty('--shown-top', view.offsetTop + 'px');
      } else {
        root.style.removeProperty('--shown-height');
        root.style.removeProperty('--shown-top');
      }
    };
    window.visualViewport.addEventListener('resize', fitShown);
    window.visualViewport.addEventListener('scroll', fitShown);
    fitShown();
  }

  function enc(s) { return encodeURIComponent(s); }

  // ------------------------------------------------- app and notifications

  // Phones only show notifications through the service worker.
  async function notify(title, text) {
    try {
      const reg = await navigator.serviceWorker.ready;
      await reg.showNotification(title, {body: text, tag: 'page', icon: SiteBase.url('/icon-192.png')});
    } catch (err) {
      new Notification(title, {body: text});
    }
  }

  // Web Push: the browser's push address goes to the site, which uses it
  // when a mention or a private message comes and no page is open.
  async function subscribePush() {
    try {
      const reg = await navigator.serviceWorker.ready;
      const key = (await get('/api/push/key')).key;
      const raw = atob(key.replace(/-/g, '+').replace(/_/g, '/'));
      const bytes = Uint8Array.from(raw, function (c) { return c.charCodeAt(0); });
      const sub = await reg.pushManager.getSubscription() ||
        await reg.pushManager.subscribe({userVisibleOnly: true, applicationServerKey: bytes});
      await post('/api/push', {endpoint: sub.endpoint});
      return true;
    } catch (err) {
      remember('push: ' + (err.message || err));
      return false;
    }
  }

  if ('serviceWorker' in navigator) navigator.serviceWorker.register(SiteBase.url('/sw.js')).catch(function (err) {
    remember('service worker: ' + err.message);
  });

  // The browser says it can install the site as an app: offer it.
  let installOffer = null;
  window.addEventListener('beforeinstallprompt', function (e) {
    e.preventDefault();
    installOffer = e;
    renderAccount();
  });

  // What this browser can do about notifications: on, off (not asked yet),
  // blocked, or none (no push in this browser).
  function notifyState() {
    if (!('Notification' in window) || !('serviceWorker' in navigator) || !('PushManager' in window)) return 'none';
    return {granted: 'on', denied: 'blocked'}[Notification.permission] || 'off';
  }

  // A blocked site cannot ask again; only the browser's settings undo it.
  // The installed app has no address bar, but it shares the browser's.
  const BlockedHelp = matchMedia('(display-mode: standalone)').matches ?
    t('Notifications are blocked for this site, and the app cannot ask again. Open %s in the browser itself, tap the icon left of the address, Permissions, and allow Notifications (or reset them); the app uses the same setting. In Brave, also turn on "Use Google services for push messaging" under Settings, Privacy and security.', location.host) :
    t('Notifications are blocked for this site. Allow them in the browser\'s site settings (the icon left of the address, or Settings, Site settings, Notifications). In Brave, also turn on "Use Google services for push messaging" under Settings, Privacy and security.');

  async function turnOnNotifications() {
    const state = notifyState();
    if (state === 'none') { toast(t('This browser cannot show notifications from sites.'), 'bad'); return; }
    if (state === 'blocked') { toast(BlockedHelp, 'bad'); return; }
    if (await Notification.requestPermission() !== 'granted') toast(BlockedHelp, 'bad');
    else if (await subscribePush())
      toast(t('Notifications are on: mentions and private messages, when the chat is not in front of you.'));
    else toast(t('Notifications are allowed, but the browser would not sign up for push messages. In Brave, turn on "Use Google services for push messaging" under Settings, Privacy and security, then tap the bell again.'), 'bad');
    renderAccount();
    const bar = $('#notifybar');
    if (bar) bar.remove();
  }

  // The bell beside Sign out: always there, saying how things stand.
  function bellButton() {
    const state = notifyState();
    const bell = iconButton('bell', {on: t('Notifications are on'), off: t('Turn on notifications for mentions and private messages'),
      blocked: t('Notifications are blocked: click to see how to allow them'), none: t('This browser cannot show notifications')}[state],
      'bell-' + state);
    bell.addEventListener('click', function () {
      turnOnNotifications();   // when on, this checks the push sign-up again and says how it went
    });
    return bell;
  }

  // Once, after signing in: ask in plain sight rather than behind a menu,
  // or say plainly why notifications cannot be had here.
  function offerNotifications() {
    let asked = '';
    try { asked = localStorage.getItem('notify-asked-2') || ''; } catch (e) { }
    const state = notifyState();
    if (!Me.name || asked || state === 'on' || $('#notifybar')) return;
    const bar = el('div', 'notifybar');
    bar.id = 'notifybar';
    const no = el('button', 'small-link', state === 'off' ? t('Not now') : t('OK'));
    no.type = 'button';
    no.addEventListener('click', function () {
      try { localStorage.setItem('notify-asked-2', '1'); } catch (e) { }
      bar.remove();
    });
    bar.appendChild(icon('bell'));
    if (state === 'off') {
      const yes = el('button', 'primary', t('Turn on'));
      yes.type = 'button';
      yes.addEventListener('click', turnOnNotifications);
      bar.append(el('span', '', t('Get a notification when someone mentions you or sends you a private message?')), yes);
    } else if (state === 'blocked') bar.appendChild(el('span', '', BlockedHelp));
    else bar.appendChild(el('span', '', t('This browser cannot show notifications from sites, so mentions and private messages only show here.')));
    bar.appendChild(no);
    $('#main').prepend(bar);
  }

  // ---------------------------------------------------------------- account

  // Whether the admin page has anything for this member.
  function mayAdmin() {
    return ['view-admin', 'manage-permissions', 'manage-settings', 'manage-channels', 'manage-private',
      'read-reports', 'manage-blocks', 'view-visitors', 'view-storage'].some(may) ||
      Extras.adminTabs.some(function (extra) { return extra.permission && may(extra.permission); }) ||
      Extras.adminScripts.some(function (extra) { return extra.permissions.some(may); });
  }

  // The row at the bottom of the side: who you are, a few buttons, and a
  // menu with the rest.  side.js draws it, as on the wiki and the forum;
  // this page adds its own buttons.
  function renderAccount() {
    const tools = [];
    const report = iconButton('bug', t('Report a problem'));
    report.addEventListener('click', openReport);
    tools.push(report);
    if (installOffer) {
      const install = iconButton('install', t('Install the app'));
      install.addEventListener('click', async function () {
        installOffer.prompt();
        await installOffer.userChoice;
        installOffer = null;
        renderAccount();
      });
      tools.push(install);
    }
    if (Me.name) tools.push(bellButton());
    Side.account({name: Me.name, avatar: Me.avatar, admin: mayAdmin(), tools: tools, links: Extras.accountLinks,
      unconfirmed: Me.verified === false});
  }

  function joinForm(caption) {
    const form = el('form', 'quickjoin');
    form.appendChild(el('span', 'caption', caption));
    const name = el('input');
    name.name = 'name';
    name.placeholder = t('Name');
    name.maxLength = 24;
    name.autocomplete = 'username';
    name.required = true;
    const pass = el('input');
    pass.name = 'password';
    pass.type = 'password';
    pass.placeholder = t('Password');
    pass.autocomplete = 'current-password';
    pass.required = true;
    const go = el('button', '', t('Join'));
    form.append(name, pass, go);
    if (body.dataset.sso) {
      const row = el('div', 'ssolink');
      row.appendChild(el('span', '', t('or sign in with')));
      for (const p of body.dataset.sso.split(',')) {
        const a = link('/signin-with/' + p, 'ssoicon');
        a.title = t('Sign in with %s', {github: 'GitHub', gitlab: 'GitLab', codeberg: 'Codeberg', google: 'Google',
          microsoft: 'Microsoft'}[p]);
        a.appendChild(el('span', 'ssologo ' + p));
        row.appendChild(a);
      }
      form.appendChild(row);
    }
    form.addEventListener('submit', async function (e) {
      e.preventDefault();
      go.disabled = true;
      go.textContent = t('One moment');
      if (await Keys.joinFrom(form, failed)) location.reload();
      go.disabled = false;
      go.textContent = t('Join');
    });
    return form;
  }

  // A small menu under a button: [caption, what it does] pairs.  Any click
  // closes it.
  function popMenu(anchor, items) {
    document.querySelectorAll('.popmenu').forEach(function (m) { m.remove(); });
    const menu = el('nav', 'popmenu');
    for (const item of items) {
      const b = el('button', '', item[0]);
      b.type = 'button';
      b.addEventListener('click', function () { menu.remove(); item[1](); });
      menu.appendChild(b);
    }
    const r = anchor.getBoundingClientRect();
    menu.style.left = Math.min(r.left, innerWidth - 220) + 'px';
    menu.style.top = (r.bottom + 4) + 'px';
    document.body.appendChild(menu);
    // no room below, as beside the message box: it opens above the button
    const shown = window.visualViewport ? visualViewport.height : innerHeight;
    if (r.bottom + 4 + menu.offsetHeight > shown) menu.style.top = Math.max(4, r.top - 4 - menu.offsetHeight) + 'px';
    setTimeout(function () {
      document.addEventListener('click', function close(e) {
        if (menu.contains(e.target)) return;
        menu.remove();
        document.removeEventListener('click', close);
      });
    });
  }

  // ----------------------------------------------------------------- router

  function isAppPath(path) { return /^\/(p|m|u|dm)\/|^\/(admin|chat-search)$/.test(path); }

  document.addEventListener('click', function (e) {
    const a = e.target.closest('a[href]');
    if (!a || a.target || e.ctrlKey || e.metaKey || e.shiftKey || a.origin !== location.origin) return;
    if (!isAppPath(SiteBase.strip(a.pathname))) return;
    e.preventDefault();
    // A room picked from the phone's room list takes the place of the one
    // left, so Back leaves the chat once instead of room by room.
    const fromList = body.classList.contains('menu') && a.closest('#side');
    body.classList.remove('menu');
    route(SiteBase.strip(a.pathname), fromList ? 'replace' : true);
  });

  // A link in a message opens a new tab and the conversation stays: all
  // but a picture, shown over the page, and what the router above shows.
  Side.newTabLinks('.msg', true, function (a) { return a.classList.contains('shot') || isAppPath(SiteBase.strip(a.pathname)); });

  // ------------------------------------------------------------ the back key

  // Back closes what is on top (the room list on a phone, the side panel, a
  // picture) before it leaves the place.  Opening one
  // adds a history entry, so Back has something to take away; closing one
  // some other way takes the entry back out.
  let layerEntry = false;
  let afterMove = null;   // runs instead of the next popstate's usual work
  // The width at which the room list slides over the chat (site.css).
  const Narrow = matchMedia('(max-width: 860px)');

  function onTop() {
    return body.classList.contains('menu') || !panel.hidden || !$('#lightbox').hidden;
  }

  function layerOpened() {
    if (layerEntry) return;
    layerEntry = true;
    history.pushState({}, '', SiteBase.path());
  }

  // Takes our entry back out once nothing is on top, then runs Then.
  function layerClosed(then) {
    if (!layerEntry || onTop()) {
      if (then) then();
      return;
    }
    layerEntry = false;
    afterMove = then || function () { };
    history.back();
  }

  // Closes the top one only: a picture over a thread leaves the thread.
  function closeTop() {
    if (!$('#lightbox').hidden) $('#lightbox').hidden = true;
    else if (body.classList.contains('menu')) body.classList.remove('menu');
    else if (!panel.hidden) {
      closePanel();
      if (SiteBase.path().startsWith('/m/') && S.room) history.replaceState({}, '', '/p/' + enc(S.room));
    }
  }

  function toggleMenu() {
    body.classList.toggle('menu');
    if (body.classList.contains('menu')) layerOpened();
    else layerClosed();
  }

  // On a phone, a tap beside the open room list closes it and does nothing
  // else.
  document.addEventListener('click', function (e) {
    if (!body.classList.contains('menu') || e.target.closest('#side, .menubtn')) return;
    e.preventDefault();
    e.stopPropagation();
    body.classList.remove('menu');
    layerClosed();
  }, true);

  // Installed apps keep a guard history entry under the last page: Back
  // asks once, then allows closing; a tap restores the page entry. Create
  // entries on a tap because Chrome skips those added before interaction.
  const Installed = matchMedia('(display-mode: standalone)').matches;
  let guarded = false;
  let here = SiteBase.path();   // the place shown, for the guard's entries
  document.addEventListener('pointerdown', function () {
    if (!Installed) return;
    if (!guarded) {
      guarded = true;
      history.replaceState({guard: true}, '', SiteBase.path());
      history.pushState({}, '', SiteBase.path());
    } else if (history.state && history.state.guard) history.pushState({}, '', here);
  }, true);

  window.addEventListener('popstate', function () {
    if (afterMove) {
      const then = afterMove;
      afterMove = null;
      then();
    } else if (history.state && history.state.guard) {
      history.replaceState({guard: true}, '', here);
      toast(t('Press back again to leave'));
    } else if (layerEntry) {
      layerEntry = false;
      closeTop();
      if (onTop()) layerOpened();
    } else route(SiteBase.path(), false);
  });

  function clearView() {
    S.generation++;
    S.view = '';
    S.room = '';
    S.info = null;
    S.messages.clear();
    S.thread = 0;
    S.threadMessages.clear();
    S.dm = '';
    S.typers = {};
    clearTimeout(S.dmTimer);
    stream.replaceChildren();
    stream.className = '';
    stream.noPin = false;
    $('#roomhead').replaceChildren();
    $('#card').replaceChildren();
    $('#typing').replaceChildren();
    $('#composer-area').replaceChildren();
    // the admin page's list gives the side back to the parts
    body.classList.remove('admin-view');
    const adminNav = $('#adminnav');
    if (adminNav) adminNav.hidden = true;
    closePanel();
  }

  // Alt+Up and Alt+Down walk the sidebar; Ctrl+K jumps to a room by name.
  document.addEventListener('keydown', function (e) {
    if (e.ctrlKey && e.key === 'k') {
      e.preventDefault();
      if (Narrow.matches) {
        body.classList.add('menu');
        layerOpened();
      }
      $('#jump').focus();
      return;
    }
    if (!e.altKey || (e.key !== 'ArrowUp' && e.key !== 'ArrowDown')) return;
    const rooms = Array.from(document.querySelectorAll('#roomlist a.room'));
    if (!rooms.length) return;
    e.preventDefault();
    let i = rooms.findIndex(function (a) { return a.classList.contains('active'); });
    i = (i + (e.key === 'ArrowDown' ? 1 : rooms.length - 1)) % rooms.length;
    route(SiteBase.strip(rooms[i].getAttribute('href')), true);
  });

  function firstRoom() {
    const r = S.rooms.find(function (x) { return x.kind === 'channel'; });
    return r ? '/p/' + enc(r.slug) : '/';
  }

  // Push is true to add a history entry, 'replace' to take the current one's
  // place, false when Back or Forward already moved there.
  async function route(path, push) {
    if (path === '/') {
      path = firstRoom();
      if (path === '/') { location.href = SiteBase.url('/'); return; }
    }
    // Leaving with something on top: its entry goes first.
    if (layerEntry && push) {
      layerEntry = false;
      return new Promise(function (done) {
        afterMove = function () { route(path, push).then(done); };
        history.back();
      });
    }
    if (push === 'replace') history.replaceState({}, '', path);
    else if (push) history.pushState({}, '', path);
    here = path;
    clearView();
    const parts = path.split('/').map(decodeURIComponent);
    try {
      if (parts[1] === 'u') await openProfile(parts[2]);
      else if (parts[1] === 'admin') await openAdmin();
      else for (const p of Parts) if (p.open && await p.open(parts)) break;
    } catch (err) {
      stream.appendChild(el('p', 'notice', err.message));
    }
    renderSide();
  }

  // The parts on this page, each with what it answers for (chat.js).
  const Parts = [];
  function renderSide() { for (const p of Parts) if (p.sidebar) p.sidebar(); }
  function syncNow(withRooms) { for (const p of Parts) if (p.sync) p.sync(withRooms); }

  // ------------------------------------------------------------------ panel

  function openPanel(title, cls) {
    // On a phone the room list slides over the chat, and the panel fills the
    // screen under it: a panel opened from the list closes the list.
    body.classList.remove('menu');
    panel.hidden = false;
    panel.className = cls || '';
    panel.replaceChildren();
    const head = el('header');
    head.appendChild(el('h2', '', title));
    const close = iconButton('close', t('Close'));
    close.addEventListener('click', function () {
      closePanel();
      if (SiteBase.path().startsWith('/m/') && S.room) history.replaceState({}, '', '/p/' + enc(S.room));
      layerClosed();
    });
    head.appendChild(close);
    panel.appendChild(head);
    body.classList.add('withpanel');
    layerOpened();
    return panel;
  }

  // Report a problem: what they write, and what the page knows.
  function openReport() {
    const box = openPanel(t('Report a problem'), 'report');
    const form = el('form', 'reportform');
    const text = el('textarea');
    text.rows = 8;
    text.maxLength = 4000;
    text.placeholder = t('What went wrong, or what looked wrong? What were you doing?');
    const send = el('button', 'primary', t('Send the report'));
    form.append(text, el('p', 'hint', t('Sent along: this page\'s address, your browser and screen size, and the last errors this page showed. Nothing else.')), send);
    form.addEventListener('submit', async function (e) {
      e.preventDefault();
      // The server mails the report before it answers, so say it is on its way.
      send.disabled = true;
      send.textContent = t('Sending…');
      text.disabled = true;
      const info = ['browser: ' + navigator.userAgent, 'screen: ' + innerWidth + 'x' + innerHeight + ' at ' + devicePixelRatio,
        'theme: ' + (document.documentElement.dataset.theme || 'auto'), 'signed in: ' + (Me.name || 'no'),
        'notifications: ' + notifyState() + (Installed ? ', installed app' : ', browser tab'),
        'last errors:'].concat(Trail.length ? Trail : ['none']).join('\n');
      try {
        toast(await post('/api/bug', {text: text.value, page: SiteBase.path(), info: info}));
        closePanel();
        layerClosed();
      } catch (err) { failed(err); }
      send.disabled = false;
      send.textContent = t('Send the report');
      text.disabled = false;
    });
    box.appendChild(form);
    text.focus();
  }

  function closePanel() {
    panel.hidden = true;
    panel.replaceChildren();
    S.thread = 0;
    S.threadMessages.clear();
    body.classList.remove('withpanel');
  }

  // ---------------------------------------------------------------- profile

  async function openProfile(name) {
    const generation = S.generation;
    const who = await get('/api/user?name=' + enc(name));
    if (generation !== S.generation) return;
    S.title = who.name;
    const head = $('#roomhead');
    const menu = iconButton('menu', t('Channels'), 'menubtn');
    menu.addEventListener('click', toggleMenu);
    head.append(menu, el('div', 'titles'));
    $('.titles', head).appendChild(el('h1', '', who.name));

    const card = el('section', 'profile');
    const face = avatar(who.name, who.avatar, 'big');
    card.appendChild(face);
    const text = el('div', 'about');
    const line = el('h2', '', who.name);
    if (who.badge) line.appendChild(el('span', 'role', who.badge));
    if (who.banned) line.appendChild(el('span', 'role', t('banned')));
    text.appendChild(line);
    if (who.away) text.appendChild(el('p', 'away', t('Away: %s', who.away)));
    // a closed account: the name on what its member wrote, and nothing of when
    if (who.closed) text.appendChild(el('p', 'seen', t('Former member')));
    else text.appendChild(el('p', 'seen', who.seen ? t('Joined %s · last here %s', dateText(who.joined), ago(who.seen)) :
      t('Joined %s', dateText(who.joined))));
    const bio = el('div', 'bio');
    bio.innerHTML = who.bio_html;   // safe html: rendered by the server, HTML escaped
    text.appendChild(bio);
    if (who.links) {
      const links = el('p', 'links');
      who.links.split(/\s+/).filter(function (l) { return /^https?:\/\//.test(l); }).forEach(function (l) {
        const a = link(l, '', l.replace(/^https?:\/\//, ''));
        a.rel = 'nofollow ugc me';
        a.target = '_blank';
        links.appendChild(a);
      });
      text.appendChild(links);
    }
    const tools = el('div', 'tools');
    if (!who.closed) for (const p of Parts) if (p.profileTools) p.profileTools(who, tools);
    if (Me.name === who.name) {
      const edit = el('button', '', t('Edit profile'));
      edit.type = 'button';
      edit.addEventListener('click', function () { editProfile(who, text); });
      tools.appendChild(edit);
      const pic = el('button', '', t('Change picture'));
      pic.type = 'button';
      const input = el('input');
      input.type = 'file';
      input.accept = 'image/*';
      input.hidden = true;
      pic.addEventListener('click', function () { input.click(); });
      input.addEventListener('change', async function () {
        const form = new FormData();
        form.append('avatar', '1');
        form.append('file', input.files[0]);
        try { await post('/api/upload', form); route(SiteBase.path(), false); } catch (err) { failed(err); }
      });
      tools.append(pic, input);
    }
    text.appendChild(tools);
    card.appendChild(text);
    $('#card').appendChild(card);
    if (Me.name === who.name) $('#card').append(prefsBox(), accountBox(), signInsBox());
    if (Me.name === who.name && may('api-tokens')) $('#card').appendChild(tokensBox());

    for (const p of Parts) if (p.profile) await p.profile(who, generation);
  }

  // Until the address is confirmed: the way to another link, or to fix a
  // mistyped address.
  function confirmBox() {
    const form = el('form', 'confirmbox');
    const email = el('input');
    email.type = 'email';
    email.placeholder = t('A different address (or leave it)');
    const again = el('button', 'primary', t('Send the link again'));
    form.append(el('p', 'notice', t('Confirm your email to talk: open the link we mailed you. It can take a minute, and it may be in the spam folder.')), email, again);
    form.addEventListener('submit', async function (e) {
      e.preventDefault();
      try { toast(await post('/api/verify', {email: email.value.trim()})); } catch (err) { failed(err); }
    });
    return form;
  }

  // A box for a password, in the account's forms.
  function passwordInput(words, fresh) {
    const input = el('input');
    input.type = 'password';
    input.placeholder = words;
    input.autocomplete = fresh ? 'new-password' : 'current-password';
    input.required = true;
    return input;
  }

  // The account's address and password, on the member's own profile.  A
  // change of either asks for the password the account has; one made by
  // signing in elsewhere has none, and can set its first here.
  function accountBox() {
    const box = el('details', 'tokens');
    box.appendChild(el('summary', '', t('Email and password')));
    const done = async function (words) {
      await loadMe();
      toast(words);
      route(SiteBase.path(), false);
    };
    if (Me.verified === false) {
      box.open = true;
      box.appendChild(confirmBox());
    } else {
      const form = el('form', 'invite');
      const email = el('input');
      email.type = 'email';
      email.value = Me.email || '';
      email.placeholder = t('Email address');
      const pass = Me.password ? passwordInput(t('Your password'), false) : null;
      form.append(email);
      if (pass) form.append(pass);
      form.append(el('button', 'primary', t('Change the address')));
      form.addEventListener('submit', async function (e) {
        e.preventDefault();
        try {
          const fields = {email: email.value.trim()};
          if (pass) fields.current = await Keys.passwordProof(Me.name, pass.value);
          await done(await post('/api/email', fields));
        } catch (err) { failed(err); }
      });
      box.appendChild(form);
    }
    const form = el('form', 'invite');
    const old = Me.password ? passwordInput(t('Your password'), false) : null;
    const fresh = passwordInput(t('New password, 8 characters or more'), true);
    if (old) form.append(old);
    else box.appendChild(el('p', 'hint', t('This account has no password yet. With one you can also sign in here with your name.')));
    form.append(fresh, el('button', 'primary', old ? t('Change the password') : t('Set a password')));
    form.addEventListener('submit', async function (e) {
      e.preventDefault();
      try {
        if (old) await Keys.changePassword(Me.name, old.value, fresh.value, Me.wrapped);
        else await Keys.setupKeys(Me.name, fresh.value);
        await done(old ? t('Your password is changed. Your other devices and apps are signed out.') : t('Saved.'));
      } catch (err) { failed(err); }
    });
    box.appendChild(form);
    box.appendChild(leaveBox());
    return box;
  }

  // Closing the account: what goes and what stays said first, then the
  // password, or the name typed out by an account that has no password.
  function leaveBox() {
    const box = el('details', 'leave');
    box.appendChild(el('summary', '', t('Close this account')));
    const named = Me.closedNames !== 'anonymous';
    box.appendChild(el('p', 'hint', t('Closing your account signs you out everywhere, for good. Your email address, password, picture and profile are wiped, and nobody else can take your name.') + ' ' +
      (named ? t('What you wrote here stays, under your name unless you tick the box.') : t('What you wrote here stays, shown as written by "Former member".')) + ' ' +
      t('Where others quoted or mentioned you, your name stays as they typed it. Only an admin can open a closed account again.')));
    const form = el('form', 'invite');
    const anonymous = el('input');
    anonymous.type = 'checkbox';
    if (named) {
      const label = el('label');
      label.append(anonymous, el('span', '', t('Show "Former member" in place of my name on what I wrote')));
      form.appendChild(label);
    }
    const proof = Me.password ? passwordInput(t('Your password'), false) : el('input');
    if (!Me.password) {
      proof.placeholder = t('Type your name, %s, to confirm', Me.name);
      proof.required = true;
    }
    form.append(proof, el('button', 'primary', t('Close my account')));
    form.addEventListener('submit', async function (e) {
      e.preventDefault();
      if (!confirm(t('Close your account for good?'))) return;
      try {
        const fields = {anonymous: anonymous.checked ? '1' : '0'};
        if (Me.password) fields.current = await Keys.passwordProof(Me.name, proof.value);
        else fields.name = proof.value.trim();
        await post('/api/close', fields);
        // the key this browser kept goes too
        try { await Keys.signOut(); } catch (err) { }
        location.href = SiteBase.url('/');
      } catch (err) { failed(err); }
    });
    box.appendChild(form);
    return box;
  }

  // Mail about missed messages, and when to show as away; saved as soon as
  // they change.
  function prefsBox() {
    const box = el('section', 'prefs');
    const mail = el('label');
    const check = el('input');
    check.type = 'checkbox';
    check.checked = Me.mailNotes;
    mail.append(check, el('span', '', t('Email me about private messages and mentions I miss')));
    const hint = el('p', 'hint', Me.email ? tn(Me.mailHours, 'To %1:s, at most one every %0:d hours, and only when something new waits for you.',
      'To %1:s, at most one every %0:d hours, and only when something new waits for you.', Me.email) : t('Your account has no email address.'));
    check.disabled = !Me.email;
    const away = el('label');
    const after = el('select');
    [[0, t('never')], [5, tn(5, 'after %d minutes', 'after %d minutes')], [10, tn(10, 'after %d minutes', 'after %d minutes')], [15, tn(15, 'after %d minutes', 'after %d minutes')], [30, tn(30, 'after %d minutes', 'after %d minutes')],
      [60, t('after an hour')]].forEach(function (c) {
      const o = el('option', '', c[1]);
      o.value = c[0];
      after.appendChild(o);
    });
    after.value = Me.autoAway;
    away.append(el('span', '', t('Show me as away when I have not touched the chat')), after);
    // A failed save puts the box back as it was.
    check.addEventListener('change', async function () {
      try {
        await post('/api/prefs', {mail_notes: check.checked ? '1' : '0'});
        Me.mailNotes = check.checked;
        toast(t('Saved.'));
      } catch (err) { check.checked = Me.mailNotes; failed(err); }
    });
    after.addEventListener('change', async function () {
      try {
        await post('/api/prefs', {auto_away: after.value});
        Me.autoAway = Number(after.value);
        toast(t('Saved.'));
      } catch (err) { after.value = Me.autoAway; failed(err); }
    });
    box.append(mail, hint);
    // What the modules add (RegisterMemberPref): a yes or no each.
    (Me.prefs || []).forEach(function (pref) {
      const line = el('label');
      const on = el('input');
      on.type = 'checkbox';
      on.checked = pref.on;
      line.append(on, el('span', '', pref.words));
      on.addEventListener('change', async function () {
        const sent = {};
        sent[pref.name] = on.checked ? '1' : '0';
        try {
          await post('/api/prefs', sent);
          pref.on = on.checked;
          toast(t('Saved.'));
        } catch (err) { on.checked = pref.on; failed(err); }
      });
      box.appendChild(line);
    });
    box.appendChild(away);
    // Read receipts, on a site where each member chooses.
    if (Me.readReceipts !== undefined) {
      const receipts = el('label');
      const shown = el('input');
      shown.type = 'checkbox';
      shown.checked = Me.readReceipts;
      receipts.append(shown, el('span', '', t('Show others when I have read their private messages')));
      shown.addEventListener('change', async function () {
        try {
          await post('/api/dm/receipts', {on: shown.checked ? '1' : '0'});
          Me.readReceipts = shown.checked;
          toast(t('Saved.'));
        } catch (err) { shown.checked = Me.readReceipts; failed(err); }
      });
      box.append(receipts, el('p', 'hint', t('With this off, you do not see when others have read yours either. It shows only between two members who both have it on.')));
    }
    return box;
  }

  // Auto away: no key, click or tap for Me.autoAway minutes in any tab shows
  // the member as away ("idle") until they are back.  The tabs share the
  // time and the flag; the server leaves an away typed with /away alone.
  function shared(key, value) {
    try {
      if (value === undefined) return localStorage.getItem(key) || '';
      localStorage.setItem(key, value);
    } catch (e) { }
    return '';
  }
  let lastTouch = Date.now();
  ['keydown', 'pointerdown', 'wheel'].forEach(function (kind) {
    document.addEventListener(kind, function () {
      if (Date.now() - lastTouch < 10000) return;
      lastTouch = Date.now();
      shared('touched', String(lastTouch));
      if (Me.name && shared('idle') === '1') {
        shared('idle', '0');
        post('/api/prefs', {idle: '0'}).catch(function () { });
      }
    }, {capture: true, passive: true});
  });
  setInterval(function () {
    const touched = Math.max(lastTouch, Number(shared('touched')) || 0);
    if (Me.name && Me.autoAway > 0 && shared('idle') !== '1' && Date.now() - touched >= Me.autoAway * 60000) {
      shared('idle', '1');
      post('/api/prefs', {idle: '1'}).catch(function () { });
    }
  }, 30000);

  // Sign-ins at GitHub, GitLab and the others linked to this account.
  function signInsBox() {
    const box = el('details', 'tokens');
    box.hidden = true;
    box.appendChild(el('summary', '', t('Sign in with GitHub, GitLab and others')));
    const list = el('div', 'tokenlist');
    box.appendChild(list);
    const show = async function () {
      const logins = await get('/api/logins');
      box.hidden = !logins.providers.length;
      list.replaceChildren();
      for (const p of logins.providers) {
        const row = el('div', 'person');
        row.appendChild(el('b', '', p.title));
        if (p.login) {
          row.appendChild(el('span', 'dim', t('linked as %s', p.login)));
          const x = el('button', 'small-link', t('Unlink'));
          x.type = 'button';
          x.addEventListener('click', async function () {
            try { await post('/api/logins', {unlink: p.name}); show(); } catch (err) { failed(err); }
          });
          row.appendChild(x);
        } else {
          row.appendChild(link('/signin-with/' + p.name, 'small-link', t('Link')));
        }
        list.appendChild(row);
      }
    };
    show().catch(failed);
    return box;
  }

  // Tokens let a bot or a script act as this member (Authorization: Bearer).
  function tokensBox() {
    const box = el('details', 'tokens');
    box.appendChild(el('summary', '', t('Tokens for bots and scripts')));
    const list = el('div', 'tokenlist');
    const show = async function () {
      const tokens = await get('/api/tokens');
      list.replaceChildren();
      if (!tokens.length) list.appendChild(el('p', 'dim', t('None yet. Apps you signed in to show here too.')));
      for (const t of tokens) {
        const row = el('div', 'person');
        row.append(el('b', '', t.name || t.kind), el('span', 'dim', window.t('%s, made %s', t.kind, ago(t.created))));
        const x = el('button', 'small-link', window.t('Take back'));
        x.type = 'button';
        x.addEventListener('click', async function () {
          try { await post('/api/tokens', {delete: t.id}); show(); } catch (err) { failed(err); }
        });
        row.appendChild(x);
        list.appendChild(row);
      }
    };
    box.addEventListener('toggle', function () { if (box.open) show().catch(failed); });
    const form = el('form', 'invite');
    const name = el('input');
    name.placeholder = t('What will use it, such as my-bot');
    const make = el('button', 'primary', t('Make a token'));
    form.append(name, make);
    form.addEventListener('submit', async function (e) {
      e.preventDefault();
      try {
        const made = JSON.parse(await post('/api/tokens', {name: name.value}));
        const shown = el('pre', 'newtoken', made.token);
        form.after(shown);
        form.after(el('p', 'hint', t('Copy it now; it is not shown again. Send it as Authorization: Bearer followed by the token. Anyone holding it can talk as you, so keep it secret.')));
        name.value = '';
        show();
      } catch (err) { failed(err); }
    });
    box.append(list, form);
    return box;
  }

  function editProfile(who, box) {
    const form = el('form', 'editprofile');
    const bio = el('textarea');
    bio.value = who.bio;
    bio.placeholder = t('A few words about you. Markdown works.');
    const links = el('input');
    links.value = who.links;
    links.placeholder = t('Links, separated by spaces');
    const save = el('button', 'primary', t('Save'));
    form.append(bio, links, save);
    box.appendChild(form);
    form.addEventListener('submit', async function (e) {
      e.preventDefault();
      try { await post('/api/profile', {bio: bio.value, links: links.value}); route(SiteBase.path(), false); } catch (err) { failed(err); }
    });
  }

  // ------------------------------------------------------------------ admin

  const ScriptVersion = document.currentScript ? new URLSearchParams(document.currentScript.src.split('?')[1]).get('v') : null;
  const Scripts = new Map();
  function loadScript(src) {
    if (!Scripts.has(src)) {
      Scripts.set(src, new Promise(function (resolve, reject) {
        const script = el('script');
        script.src = src + (ScriptVersion === null ? '' : '?v=' + enc(ScriptVersion));
        script.onload = resolve;
        script.onerror = function () {
          Scripts.delete(src);
          script.remove();
          reject(new Error(t('Could not load %s.', src)));
        };
        document.head.appendChild(script);
      }));
    }
    return Scripts.get(src);
  }

  async function openAdmin() {
    const generation = S.generation;
    if (document.readyState === 'loading')
      await new Promise(function (resolve) { document.addEventListener('DOMContentLoaded', resolve, {once: true}); });
    if (generation !== S.generation) return;
    try { await loadScript('/static/admin.js'); } catch (err) { failed(err); return; }
    if (generation !== S.generation) return;
    await window.Chat.openAdmin();
  }

  // tabs inside a tab: a row of smaller ones, the one last chosen remembered
  function subTabs(box, id, list) {
    const nav = el('nav', 'subtabs');
    nav.setAttribute('role', 'tablist');
    box.appendChild(nav);
    const parts = {};
    let current = '';
    try { current = localStorage.getItem('sub-' + id) || ''; } catch (e) { }
    const select = function (key) {
      if (!parts[key]) key = list[0].key;
      for (const k in parts) {
        parts[k].button.classList.toggle('on', k === key);
        parts[k].button.setAttribute('aria-selected', k === key ? 'true' : 'false');
        parts[k].holder.hidden = k !== key;
      }
      current = key;
      try { localStorage.setItem('sub-' + id, key); } catch (e) { }
      // on a phone the row scrolls: the chosen one in sight
      const b = parts[key].button;
      if (b.scrollIntoView && nav.scrollWidth > nav.clientWidth) b.scrollIntoView({block: 'nearest', inline: 'nearest'});
    };
    for (const s of list) {
      const b = el('button', '', s.title);
      b.type = 'button';
      b.setAttribute('role', 'tab');
      const badge = el('span', 'sub-count');
      badge.hidden = true;
      b.appendChild(badge);
      const holder = el('div', 'subpart');
      holder.setAttribute('role', 'tabpanel');
      holder.hidden = true;
      b.addEventListener('click', function () { select(s.key); });
      nav.appendChild(b);
      box.appendChild(holder);
      parts[s.key] = {button: b, holder: holder, badge: badge};
    }
    select(current);
    return {
      holder: function (key) { return parts[key].holder; },
      select: select,
      count: function (key, n) { const b = parts[key].badge; b.hidden = !(n > 0); b.textContent = n > 0 ? n.toLocaleString(locale) : ''; }
    };
  }

  // a part of a page whose words are on their way: a turning mark and what it waits for
  function waiting(holder, words) {
    const p = el('p', 'lv-wait');
    p.append(el('span', 'lv-spinner'), ' ' + (words || t('Loading…')));
    holder.replaceChildren(p);
    return p;
  }

  // facts about one thing, as label and value lines in a picked row's box
  function facts(holder, pairs) {
    const dl = el('dl', 'lv-facts');
    for (const p of pairs) {
      if (p[1] === '' || p[1] === null || p[1] === undefined) continue;
      dl.appendChild(el('dt', '', p[0]));
      const dd = el('dd');
      if (typeof p[1] === 'object') dd.appendChild(p[1]); else dd.textContent = String(p[1]);
      dl.appendChild(dd);
    }
    holder.appendChild(dl);
    return dl;
  }
  function chip(text, cls) { return el('span', 'lv-chip' + (cls ? ' ' + cls : ''), text); }

  // ------------------------------------------------------------------ start

  function ready(then) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', function () { then(); }, {once: true});
    else then();
  }

  // What the server knows of the member signed in.
  async function loadMe() {
    const me = await get('/api/me');
    Me.avatar = me.avatar;
    Me.can = me.can;
    Me.away = me.away;
    Me.ignores = me.ignores;
    Me.wrapped = me.wrapped;
    Me.verified = me.verified;
    Me.email = me.email;
    Me.mailNotes = me.mail_notes;
    Me.autoAway = me.auto_away;
    Me.mailHours = me.mail_hours;
    Me.readReceipts = me.read_receipts;
    Me.prefs = me.prefs;
    Me.password = me.password;
    Me.closedNames = me.closed_names;
    if (me.reactions) Me.reactions = me.reactions;
  }

  async function start() {
    if (Me.name) {
      try { await loadMe(); } catch (err) { }
    }
    for (const p of Parts) if (p.prepare) await p.prepare();
    renderAccount();
    renderSide();
    for (const p of Parts) if (p.start) p.start();
    const thread = Number(body.dataset.thread);
    const view = body.dataset.view;
    const target = body.dataset.target;
    try {
      if (view === 'profile') await openProfile(target);
      else if (view === 'admin') await openAdmin();
      else for (const p of Parts) if (p.view && await p.view(view, target, thread)) break;
    } catch (err) {
      stream.appendChild(el('p', 'notice', err.message));
    }
    syncNow(true);
  }

  // What another script, loaded after this one, can
  // add: sidebar groups ({title, test, sigil, button, always}), things over
  // a room's messages, badges by a name, rooms for # completion and
  // /commands the page runs itself.
  const Extras = {groups: [], cards: [], badges: [], rooms: [], commands: {}, adminTabs: [], adminScripts: [], adminOverview: [], settingGroups: {}, accountLinks: [], places: {}};
  window.Chat = {extras: Extras, me: Me, state: S, icons: Icons, el: el, link: link, icon: icon, get: get,
    post: post, enc: enc, toast: toast, failed: failed, route: route, openPanel: openPanel, ago: ago,
    subTabs: subTabs, facts: facts, chip: chip, waiting: waiting, $: $, stream: stream, Site: Site,
    iconButton: iconButton, sizeText: sizeText, syncNow: syncNow, toggleMenu: toggleMenu,
    locale: locale, clock: clock, shared: shared, loadScript: loadScript, parts: Parts, body: body,
    panel: panel, avatar: avatar, dayLabel: dayLabel, keepPinned: keepPinned, pinWatch: pinWatch,
    nearBottom: nearBottom, may: may, mayHere: mayHere, notify: notify, popMenu: popMenu,
    joinForm: joinForm, confirmBox: confirmBox, layerOpened: layerOpened, layerClosed: layerClosed,
    offerNotifications: offerNotifications, subscribePush: subscribePush};

  // the same under the name a module's script should use: this is the site's
  // shell, whatever modules are on; Chat is its name from when the chat was all there was
  window.Site = window.Chat;

  // after the page's other scripts (chat.js, extensions) have added themselves
  ready(start);
})();
