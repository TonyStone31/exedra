// The left column every module shares: the small helpers that draw it, the
// theme button at its top, and at its foot the row that says who is signed
// in, with a menu for the rest (profile, admin, language, signing out).
// The chat's page fills the row itself through Side.account; a page the
// server drew (wiki, forum) has plain links there, which become the row.
window.Side = (function () {
  'use strict';

  const $ = function (s, root) { return (root || document).querySelector(s); };
  // words.js gives t(); a page without it still gets its words in English
  const say = function (text) { return typeof window.t === 'function' ? window.t.apply(null, arguments) : text; };

  function el(tag, cls, text) {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text !== undefined) e.textContent = text;
    return e;
  }

  function link(href, cls, text) {
    const a = el('a', cls, text);
    a.href = href;
    return a;
  }

  function hue(name) {
    let h = 2166136261;
    for (const c of name) h = Math.imul(h ^ c.charCodeAt(0), 16777619);
    return (h >>> 0) % 360;
  }

  function avatar(name, url, cls) {
    const a = el('span', 'avatar ' + (cls || ''));
    if (url) {
      const img = el('img');
      img.src = url;
      img.alt = '';
      img.loading = 'lazy';
      a.appendChild(img);
    } else {
      a.textContent = (name || '?').charAt(0).toUpperCase();
      a.style.setProperty('--h', hue(name || '?'));
    }
    return a;
  }

  const Icons = {
    react: 'M12 22a10 10 0 1 1 0-20 10 10 0 0 1 0 20zm-4-8a4.5 4.5 0 0 0 8 0M9 9.5h.01M15 9.5h.01',
    reply: 'M21 12a8 8 0 0 1-11.6 7.1L4 21l1.9-5.4A8 8 0 1 1 21 12z',
    link: 'M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1',
    edit: 'M4 20h4L19 9l-4-4L4 16v4zM14 6l4 4',
    trash: 'M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3',
    pin: 'M9 4h6l-1 6 4 4H6l4-4-1-6zM12 14v7',
    attach: 'M21 11l-8.5 8.5a5 5 0 0 1-7-7L14 4a3.5 3.5 0 0 1 5 5l-8.5 8.5a2 2 0 0 1-3-3L15 7',
    code: 'M8 7l-5 5 5 5M16 7l5 5-5 5M14 4l-4 16',
    beam: 'M4 12h11M11 6l6 6-6 6M20 4v16',
    close: 'M6 6l12 12M18 6L6 18',
    menu: 'M4 6h16M4 12h16M4 18h16',
    search: 'M11 18a7 7 0 1 1 0-14 7 7 0 0 1 0 14zM20 20l-4-4',
    lock: 'M6 11h12v9H6zM8 11V8a4 4 0 0 1 8 0v3',
    shelf: 'M4 6h16M4 12h16M4 18h16M6 6v12M18 6v12',
    bell: 'M6 16V11a6 6 0 0 1 12 0v5l2 2H4l2-2zM10 20a2 2 0 0 0 4 0',
    sun: 'M12 17a5 5 0 1 0 0-10 5 5 0 0 0 0 10zM12 1v2M12 21v2M4.2 4.2l1.4 1.4M18.4 18.4l1.4 1.4M1 12h2M21 12h2M4.2 19.8l1.4-1.4M18.4 5.6l1.4-1.4',
    moon: 'M21 13A9 9 0 1 1 11 3a7 7 0 0 0 10 10z',
    auto: 'M12 21a9 9 0 1 1 0-18 9 9 0 0 1 0 18zM12 3v18',
    people: 'M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM2 21v-1a6 6 0 0 1 12 0v1M17 11a3 3 0 1 0 0-6M22 21v-1a5 5 0 0 0-4-4.9',
    plus: 'M12 5v14M5 12h14',
    copy: 'M8 8h12v12H8zM4 16V4h12',
    bug: 'M9 7a3 3 0 0 1 6 0M7 10h10v5a5 5 0 0 1-10 0zM12 10v10M4 13h3M17 13h3M5 8l2 2M19 8l-2 2M5 19l2-2M19 19l-2-2',
    install: 'M12 4v11M7 10l5 5 5-5M5 20h14',
    up: 'M6 15l6-6 6 6',
    down: 'M6 9l6 6 6-6',
    // two eyes, looking back at the message they have read
    seen: 'M3 12a4 5 0 1 0 8 0a4 5 0 1 0-8 0M13 12a4 5 0 1 0 8 0a4 5 0 1 0-8 0M4.6 12.6a1 1 0 1 0 2 0a1 1 0 1 0-2 0M14.6 12.6a1 1 0 1 0 2 0a1 1 0 1 0-2 0'
  };

  function icon(name) {
    const ns = 'http://www.w3.org/2000/svg';
    const svg = document.createElementNS(ns, 'svg');
    svg.setAttribute('viewBox', '0 0 24 24');
    svg.setAttribute('class', 'icon');
    const path = document.createElementNS(ns, 'path');
    path.setAttribute('d', Icons[name]);
    svg.appendChild(path);
    return svg;
  }

  function iconButton(name, title, cls) {
    const b = el('button', 'iconbtn ' + (cls || ''));
    b.type = 'button';
    b.title = title;
    b.setAttribute('aria-label', title);
    b.appendChild(icon(name));
    return b;
  }

  // ------------------------------------------------------------------ theme

  // The button at the top of the column: auto, light, dark, in turn.
  function themeButton(button) {
    if (!button || !window.Theme) return;
    const names = function () { return {auto: say('auto'), light: say('light'), dark: say('dark')}; };
    const show = function () {
      const theme = window.Theme.get();
      button.replaceChildren(icon(theme === 'light' ? 'sun' : theme === 'dark' ? 'moon' : 'auto'));
      button.title = say('Theme: %s', names()[theme]);
      button.setAttribute('aria-label', say('Theme: %s. Change theme', names()[theme]));
    };
    button.addEventListener('click', function () {
      window.Theme.set({auto: 'light', light: 'dark', dark: 'auto'}[window.Theme.get()]);
    });
    window.addEventListener('themechange', show);
    show();
  }

  // ---------------------------------------------------------------- account

  async function signOut() {
    try {
      if (window.Keys) await window.Keys.signOut();
      location.reload();
    } catch (err) { alert(err.message); }
  }

  // The menu over the row.  The language choice is the form the server
  // drew, kept out of sight in #side-language until the menu shows it.
  function accountMenu(box, who) {
    const open = $('.accountmenu', box);
    if (open) { open.close(); return; }
    const menu = el('nav', 'accountmenu');
    if (who.name) menu.appendChild(link('/u/' + encodeURIComponent(who.name), '', say('Your profile and settings')));
    for (const extra of who.links || []) menu.appendChild(link(extra.href, '', extra.title));
    if (who.admin) menu.appendChild(link('/admin', '', say('Admin')));
    const holder = $('#side-language');
    const form = holder && holder.firstElementChild;
    if (form) {
      const row = el('div', 'accountmenu-language');
      row.appendChild(form);
      menu.appendChild(row);
    }
    if (who.name) {
      const out = link('#', '', say('Sign out'));
      out.addEventListener('click', function (e) { e.preventDefault(); (who.signOut || signOut)(); });
      menu.appendChild(out);
    }
    function away(e) {
      // a click on the language choice is not a choice yet
      if (menu.contains(e.target) && !e.target.closest('a')) return;
      menu.close();
    }
    menu.close = function () {
      if (form) holder.appendChild(form);
      menu.remove();
      document.removeEventListener('click', away);
    };
    box.appendChild(menu);
    setTimeout(function () { document.addEventListener('click', away); }, 0);
  }

  // Draws the row: who.name ('' for a visitor), who.avatar, who.admin,
  // who.tools (buttons between the name and the menu's button), who.links
  // (more menu entries), who.signOut (in place of the usual one),
  // who.unconfirmed (the address still waits for its link to be opened).
  function account(who) {
    const box = $('#account');
    if (!box) return;
    box.replaceChildren();
    // the way to another link, or to a corrected address, is on the profile
    if (who.unconfirmed) box.appendChild(link('/u/' + encodeURIComponent(who.name), 'unconfirmed', say('Confirm your email')));
    if (who.name) {
      const me = link('/u/' + encodeURIComponent(who.name), 'me');
      me.title = say('Your profile and settings');
      me.append(avatar(who.name, who.avatar, 'small'), el('span', '', who.name));
      box.appendChild(me);
    } else
      box.appendChild(link('/signin', 'button signinbtn', say('Sign in or join')));
    const tools = el('div', 'tools');
    for (const tool of who.tools || []) tools.appendChild(tool);
    const more = iconButton('up', say('More'));
    more.addEventListener('click', function () { accountMenu(box, who); });
    tools.appendChild(more);
    box.appendChild(tools);
  }

  // A page the server drew: its plain account links say who this is.
  function fromLinks() {
    const box = $('#account');
    if (!box || !box.children.length) return;
    const me = $('a.me', box);
    account({name: me ? me.textContent.trim() : '', admin: !!$('a[href$="/admin"]', box), unconfirmed: !!$('a.unconfirmed', box)});
  }

  function start() {
    themeButton($('#theme'));
    fromLinks();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start);
  else start();

  // Links in what members wrote (inside boxes, a selector) open a new tab,
  // old messages and new alike: those to another site, and with own those
  // to this site too, but for the ones stays(a) says the page shows in
  // place.  Set as the click arrives, so nothing drawn later is missed.
  function newTabLinks(boxes, own, stays) {
    document.addEventListener('click', function (e) {
      const a = e.target.closest('a[href]');
      if (!a || !a.closest(boxes) || !/^https?:$/.test(a.protocol)) return;
      if (a.origin === location.origin && (!own || stays(a))) return;
      a.target = '_blank';
      a.relList.add('noopener');
    }, true);
  }
  // A forum post, wherever one is shown: its links to this site stay in the
  // tab, as the reader moves through the forum.
  newTabLinks('.forum-body, .forum-signature', false);

  return {el: el, link: link, hue: hue, avatar: avatar, icons: Icons, icon: icon, iconButton: iconButton,
    account: account, signOut: signOut, newTabLinks: newTabLinks};
})();
