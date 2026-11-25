// The admin page's Emoji tab: the wiki's own emoji (WikiEmojiSite).  Each
// emoji shows its picture, name and keywords; an admin may change the
// words, turn the site's picture off (the reader's font draws it then),
// give it a picture of their own (SVG) or go back to the default one, and
// add an emoji the set does not have.
(function () {
  'use strict';
  if (!window.Site || !window.Site.extras) return;
  const t = window.t || function (s) { return s; };
  const node = window.Site.el;
  async function send(data) {
    const r = await fetch('/api/wiki/emoji/save', {method: 'POST', credentials: 'same-origin', body: new URLSearchParams(data)});
    if (!r.ok) throw new Error(await r.text());
  }
  function readSvg(file) {
    return new Promise(function (done, fail) {
      if (!file) { done(''); return; }
      if (file.size > 64 * 1024) { fail(new Error(t('The picture is too big: 64 KB at most.'))); return; }
      const reader = new FileReader();
      reader.onload = function () { done(String(reader.result || '')); };
      reader.onerror = function () { fail(new Error(t('The file could not be read.'))); };
      reader.readAsText(file);
    });
  }
  function picker() {
    const input = node('input');
    input.type = 'file';
    input.accept = 'image/svg+xml,.svg';
    return input;
  }

  function build(holder) {
    const root = node('section', 'emoji-admin');
    root.append(node('h2', '', t('Wiki emoji')),
      node('p', '', t('Pages keep the emoji themselves. Here you choose how the wiki draws them: with its own picture, or as the reader\'s computer does. A keyword typed between colons, like :yes:, becomes its emoji when a page is saved.')));
    const notice = node('p', 'emoji-admin-notice');
    notice.setAttribute('role', 'status');
    const list = node('div', 'emoji-admin-list');
    root.append(notice, list, addForm());
    holder.appendChild(root);
    load();

    async function load() {
      notice.textContent = t('Loading…');
      try {
        const r = await fetch('/api/wiki/emoji?fresh=' + Date.now(), {credentials: 'same-origin'});
        if (!r.ok) throw new Error(await r.text());
        const set = await r.json();
        notice.textContent = '';
        list.replaceChildren();
        for (const e of set) list.appendChild(row(e));
      } catch (error) {
        notice.textContent = error.message;
      }
    }

    function row(e) {
      const line = node('form', 'emoji-admin-row');
      const face = node('span', 'emoji-admin-face');
      if (e.src) { const img = node('img'); img.src = e.src; img.alt = e.emoji; face.appendChild(img); }
      else face.textContent = e.emoji;
      const plain = node('span', 'emoji-admin-plain', e.emoji);
      plain.title = t('As the reader\'s font draws it');
      const name = node('input');
      name.value = e.name;
      name.setAttribute('aria-label', t('Name'));
      const keys = node('input');
      keys.value = e.keywords.join(' ');
      keys.setAttribute('aria-label', t('Keywords'));
      keys.placeholder = t('keywords, with spaces between');
      const drawnBox = node('input');
      drawnBox.type = 'checkbox';
      drawnBox.checked = !!e.src;
      const drawn = node('label', 'emoji-admin-drawn');
      drawn.append(drawnBox, document.createTextNode(' ' + t('Own picture')));
      const file = picker();
      file.setAttribute('aria-label', t('A picture of your own (SVG)'));
      const save = node('button', '', t('Save'));
      save.type = 'submit';
      const back = node('button', '', t('Default picture'));
      back.type = 'button';
      line.append(face, plain, name, keys, drawn, file, save, back);
      async function store(extra) {
        save.disabled = back.disabled = true;
        try {
          const data = Object.assign({chars: e.emoji, name: name.value, keywords: keys.value, drawn: drawnBox.checked ? '1' : '0'}, extra || {});
          const svg = await readSvg(file.files[0]);
          if (svg) data.svg = svg;
          await send(data);
          notice.textContent = t('Saved.') + ' ' + e.emoji;
          await load();
        } catch (error) {
          notice.textContent = error.message;
          save.disabled = back.disabled = false;
        }
      }
      line.addEventListener('submit', function (ev) { ev.preventDefault(); store(); });
      back.addEventListener('click', function () { store({plain: '1'}); });
      return line;
    }

    function addForm() {
      const form = node('form', 'emoji-admin-add');
      const chars = node('input');
      chars.placeholder = t('Emoji');
      chars.setAttribute('aria-label', t('Emoji'));
      chars.size = 4;
      const name = node('input');
      name.placeholder = t('Name');
      name.setAttribute('aria-label', t('Name'));
      const keys = node('input');
      keys.placeholder = t('keywords, with spaces between');
      keys.setAttribute('aria-label', t('Keywords'));
      const file = picker();
      file.setAttribute('aria-label', t('A picture of your own (SVG)'));
      const add = node('button', '', t('Add'));
      add.type = 'submit';
      form.append(node('h3', '', t('Add an emoji')), chars, name, keys, file, add);
      form.addEventListener('submit', async function (ev) {
        ev.preventDefault();
        add.disabled = true;
        try {
          const svg = await readSvg(file.files[0]);
          const data = {add: '1', chars: chars.value.trim(), name: name.value, keywords: keys.value, drawn: svg ? '1' : '0'};
          if (svg) data.svg = svg;
          await send(data);
          form.reset();
          notice.textContent = t('Saved.');
          await load();
        } catch (error) {
          notice.textContent = error.message;
        } finally {
          add.disabled = false;
        }
      });
      return form;
    }
  }

  window.Site.extras.adminTabs.push({title: 'Emoji', permission: 'wiki-emoji', build: build, group: 'Wiki'});
})();
