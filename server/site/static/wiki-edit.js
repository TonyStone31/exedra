// Wiki editor tools: [[links]], pictures and the wiki renderer's preview.
// The shared toolbar is in editor.js; the plain form and Preview button
// also work without scripts.
(function () {
  'use strict';
  const form = document.querySelector('form.wikiedit');
  if (!form || !window.Editor) return;
  const box = form.querySelector('textarea[name="body"]');
  if (!box) return;
  const t = window.t || function (s) { return s; };

  // what changed, Save and Cancel go in one row under the editor
  const summary = form.querySelector('input[name="summary"]');
  const actions = form.querySelector('button[type="submit"]:not([name])');
  // the plain form's own words say the same as the help: hide them here
  const fine = form.querySelector(':scope > p.fine');
  if (fine) fine.hidden = true;

  const ed = window.Editor.attach(box, {
    storeKey: 'wiki-edit-mode',
    heads: '.wikibody h1, .wikibody h2, .wikibody h3, .wikibody h4, .wikibody h5, .wikibody h6',
    hint: t('Markdown and [[wiki links]]. Drag, paste or'),
    emptyWords: t('The page shows here as you write.'),
    helpLink: {href: '/wiki-help', words: t('Everything you can write here')},
    sendRow: [summary && summary.closest('label'), actions && actions.parentElement !== form ? actions.parentElement : null],
    cheats: [
      ['[[Page Name]]  [[Page Name|' + t('words') + ']]', t('a link to a wiki page')],
      ['[[File:Name.png]]', t('a picture; add |thumb|300px|caption for a small framed one')],
      ['Category:Name', t('on a line at the end: puts the page in a category')],
      ['#REDIRECT [[Other Page]]', t('as the first line: sends readers to another page')]
    ],
    preview: async function (text, signal) {
      const r = await fetch('/api/wiki/preview', {method: 'POST', body: new URLSearchParams({body: text}), signal: signal});
      if (!r.ok) throw new Error(await r.text());
      return (await r.json()).html;
    },
    linkTools: function (editor) {
      editor.tool(t('Link to a wiki page'), '', '[[ ]]', findPage);
      editor.tool(t('Image'), '', editor.svg('<rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="9" cy="10" r="1.8"/><path d="M21 16l-5-5-9 9"/>'), imagePanel).setAttribute('aria-haspopup', 'dialog');
    },
    pictures: {accept: 'image/png,image/jpeg,image/gif,image/webp', types: /^image\/(png|jpeg|gif|webp)$/, send: send},
    // the wiki's emoji set, with the site's own pictures, then the names
    // every part knows: a keyword of the wiki's keeps the wiki's emoji
    emoji: async function () {
      const r = await fetch('/api/wiki/emoji');
      return EmojiNames.after(r.ok ? await r.json() : []);
    }
  });
  const el = ed.el, replace = ed.replace, closePop = ed.closePop;
  function pop(button) { return ed.pop(button); }

  // ---- [[links]]: a finder for the page to link to


  function findPage(button) {
    const card = pop(button);
    const a = box.selectionStart, b = box.selectionEnd, words = box.value.slice(a, b);
    const find = el('input');
    find.type = 'search';
    find.placeholder = t('Find a page');
    find.setAttribute('aria-label', t('Find a page'));
    const list = el('ul', 'wikitools-found');
    card.append(find, list);
    find.focus();
    const put = function (title) {
      closePop();
      const text = words && words !== title ? '[[' + title + '|' + words + ']]' : '[[' + title + ']]';
      replace(a, b, text);
    };
    let timer = 0, asked = 0;
    const search = function () {
      const q = find.value.trim();
      const mine = ++asked;
      list.replaceChildren();
      if (q.length < 2) return;
      fetch('/api/wiki/search?q=' + encodeURIComponent(q)).then(function (r) { return r.ok ? r.json() : []; }).then(function (found) {
        if (mine !== asked) return;
        for (const p of (found || []).slice(0, 8)) {
          const li = el('li');
          const pick = el('button', '', p.title);
          pick.type = 'button';
          pick.addEventListener('click', function () { put(p.title); });
          li.appendChild(pick);
          list.appendChild(li);
        }
        // a page that does not exist yet: the link starts it
        const li = el('li', 'wikitools-new');
        const pick = el('button', '', t('Link to "%s", a new page', q));
        pick.type = 'button';
        pick.addEventListener('click', function () { put(q); });
        li.appendChild(pick);
        list.appendChild(li);
      }).catch(function () { });
    };
    find.addEventListener('input', function () { clearTimeout(timer); timer = setTimeout(search, 250); });
    find.addEventListener('keydown', function (e) {
      if (e.key === 'Enter') { e.preventDefault(); const first = list.querySelector('button'); if (first) first.click(); }
    });
    if (words) { find.value = words; search(); }
  }

  // ---- images: [[File:Name.png]], as MediaWiki writes them

  const fileRef = /\[\[\s*:?\s*(?:File|Image)\s*:\s*([^|\]]+)/gi;
  const pathRef = /\]\(\/wiki-images\/[0-9a-f]\/[0-9a-f]{2}\/([^)\s]+)\)/g;


  function usedNames() {
    const v = box.value, seen = new Set();
    let m;
    fileRef.lastIndex = 0;
    while ((m = fileRef.exec(v))) seen.add(m[1].trim().replace(/ /g, '_'));
    pathRef.lastIndex = 0;
    while ((m = pathRef.exec(v))) { try { seen.add(decodeURIComponent(m[1])); } catch (e) { seen.add(m[1]); } }
    return Array.from(seen);
  }

  function putImage(name) {
    const a = box.selectionStart, b = box.selectionEnd, v = box.value;
    const text = '[[File:' + name.replace(/_/g, ' ') + ']]';
    // a picture on a line of its own unless the member is mid-sentence
    const lead = a === 0 || v[a - 1] === '\n' ? '' : '\n\n';
    replace(a, b, lead + text, lead.length + text.length, lead.length + text.length);
  }

  function thumbs(list, files, empty) {
    list.replaceChildren();
    if (!files.length) { list.appendChild(el('p', 'fine', empty)); return; }
    for (const f of files) {
      const b = el('button', 'wikiimg');
      b.type = 'button';
      b.title = t('Put %s in the page', f.name);
      const img = el('img');
      img.loading = 'lazy';
      img.alt = '';
      img.src = f.url;
      const cap = el('span', '', f.name.replace(/_/g, ' '));
      b.append(img, cap);
      b.addEventListener('click', function () { closePop(); putImage(f.name); });
      list.appendChild(b);
    }
  }

  async function files(query) {
    const r = await fetch('/api/wiki/files?' + query);
    if (!r.ok) throw new Error(r.status);
    return r.json();
  }

  function imagePanel(button) {
    const card = pop(button);
    card.classList.add('wikitools-images');
    const head = el('div', 'wikiimg-head');
    const pick = el('button', 'wikiimg-upload', t('Upload images'));
    pick.type = 'button';
    pick.addEventListener('click', function () { closePop(); ed.choose(); });
    const find = el('input');
    find.type = 'search';
    find.placeholder = t('Find an image');
    find.setAttribute('aria-label', t('Find an image'));
    head.append(find, pick);
    const onPage = el('section');
    onPage.appendChild(el('h3', '', t('On this page')));
    const pageList = el('div', 'wikiimg-list');
    onPage.appendChild(pageList);
    const lib = el('section');
    const libHead = el('h3', '', t('Newest in the wiki'));
    const libList = el('div', 'wikiimg-list');
    lib.append(libHead, libList);
    const all = el('a', 'wikiimg-all', t('All images'));
    all.href = '/wiki-files';
    all.target = '_blank';
    card.append(head, onPage, lib, el('p', 'fine wikiimg-tip', t('You can also drag pictures onto the text, or paste a screenshot.')), all);
    find.focus();
    const names = usedNames();
    if (names.length) {
      pageList.appendChild(el('p', 'fine', t('Loading…')));
      files('names=' + encodeURIComponent(names.join('|'))).then(function (found) {
        // a picture the server does not know is still shown, by its name
        const known = new Map((found || []).map(function (f) { return [f.name, f]; }));
        thumbs(pageList, names.map(function (n) { return known.get(n) || {name: n, url: ''}; }), '');
      }).catch(function () { pageList.replaceChildren(el('p', 'fine', t('The list could not be loaded.'))); });
    } else {
      thumbs(pageList, [], t('This page has no pictures yet.'));
    }
    const load = function (q) {
      libHead.textContent = q ? t('Found') : t('Newest in the wiki');
      files('limit=24' + (q ? '&q=' + encodeURIComponent(q) : '')).then(function (found) {
        thumbs(libList, found || [], q ? t('No image has that name.') : t('No images yet.'));
      }).catch(function () { libList.replaceChildren(el('p', 'fine', t('The list could not be loaded.'))); });
    };
    let timer = 0;
    find.addEventListener('input', function () { clearTimeout(timer); timer = setTimeout(function () { load(find.value.trim()); }, 250); });
    load('');
  }

  // ---- uploading: the editor shows a line for each picture on its way;
  // this sends one and answers what to write in its place

  async function send(f, name, again) {
    const body = new FormData();
    body.append('file', f, name);
    body.append('name', name);
    const r = await fetch('/api/wiki/upload', {method: 'POST', body: body});
    // a refusal comes as a sentence, an answer as JSON
    const text = await r.text();
    let answer = {};
    try { answer = JSON.parse(text); } catch (e) { answer = {error: text.trim().slice(0, 200)}; }
    // another picture has that name already: keep both
    if (r.status === 409 && answer.conflict && again !== true) return send(f, answer.suggested || name, true);
    if (!r.ok) throw new Error(answer.error || (r.status === 413 ? t('That picture is too big.') : t('The picture could not be uploaded.')));
    return {put: '[[File:' + answer.name.replace(/_/g, ' ') + ']]', words: t('%s is uploaded.', answer.name.replace(/_/g, ' '))};
  }

  // the form's own Preview button reloads the page; the live preview does its work
  const reload = form.querySelector('button[name="preview"]');
  if (reload) reload.hidden = true;
})();
