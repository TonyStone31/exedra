// Shared text editor with a preview from the module's renderer. Text stays
// as typed except for completed :keyword: emoji. Editor.attach options and
// the returned editor are in docs/CODE-MAP.md. The plain form still works
// where the module supports it.
(function () {
  'use strict';
  const t = window.t || function (s) { return s; };
  const el = function (tag, cls, text) {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text !== undefined) e.textContent = text;
    return e;
  };
  const mac = /Mac|iPhone|iPad/.test(navigator.platform);
  const mod = mac ? '⌘' : 'Ctrl+';
  const shiftKey = mac ? '⇧' : 'Shift+';
  const svg = function (inner) { return '<svg viewBox="0 0 24 24" aria-hidden="true">' + inner + '</svg>'; };

  let made = 0;

  function attach(box, options) {
    if (box.editor) return box.editor;
    const opts = options || {};
    const form = box.closest('form');
    // named on a new code block; with none, the site's own setting says how such a block is colored
    const language = opts.language || '';

    const editor = {box: box, form: form, el: el, svg: svg, replace: replace, wrap: wrap, lines: lines, prefix: prefix, pop: pop,
      closePop: closePop, say: say, tool: tool, gap: gap, upload: upload, choose: choose};

    // ---- editing the text, so the browser's undo still works

    function replace(from, to, text, selectFrom, selectTo) {
      box.focus();
      box.setSelectionRange(from, to);
      let done = false;
      try { done = document.execCommand('insertText', false, text); } catch (e) { done = false; }
      if (!done) box.setRangeText(text, from, to, 'end');
      const at = from + (selectFrom === undefined ? text.length : selectFrom);
      box.setSelectionRange(at, from + (selectTo === undefined ? text.length : selectTo));
      box.dispatchEvent(new Event('input', {bubbles: true}));
    }

    // the selected words between two marks, or the marks around a placeholder;
    // the same marks again take them off
    function wrap(before, after, placeholder) {
      const a = box.selectionStart, b = box.selectionEnd, v = box.value;
      const inner = v.slice(a, b);
      if (v.slice(a - before.length, a) === before && v.slice(b, b + after.length) === after) {
        replace(a - before.length, b + after.length, inner, 0, inner.length);
        return;
      }
      const words = inner || placeholder;
      replace(a, b, before + words + after, before.length, before.length + words.length);
    }

    // the whole lines the selection touches
    function lines() {
      const v = box.value;
      const from = v.lastIndexOf('\n', box.selectionStart - 1) + 1;
      let to = v.indexOf('\n', box.selectionEnd - (box.selectionEnd > box.selectionStart && v[box.selectionEnd - 1] === '\n' ? 1 : 0));
      if (to < 0) to = v.length;
      return {from: from, to: to, text: v.slice(from, to)};
    }

    // a mark at the start of each line (a list, a quote); taken off when every line has it
    function prefix(make, test) {
      const l = lines();
      const rows = l.text.split('\n');
      const all = rows.every(function (r) { return test.test(r); });
      const out = rows.map(function (r, i) { return all ? r.replace(test, function (m, indent) { return typeof indent === 'string' ? indent : ''; }) : make(i) + r.replace(/^(\s*)([-*+]\s+|\d+[.)]\s+|>\s?)/, '$1'); });
      replace(l.from, l.to, out.join('\n'), 0, out.join('\n').length);
    }

    function code() {
      const a = box.selectionStart, b = box.selectionEnd;
      const inner = box.value.slice(a, b);
      if (inner.indexOf('\n') < 0) { wrap('`', '`', t('code')); return; }
      // a block, its language named so it is colored
      const block = '```' + language + '\n' + inner.replace(/\n$/, '') + '\n```\n';
      replace(a, b, block, 3, 3 + language.length);
    }

    function link() {
      const a = box.selectionStart, b = box.selectionEnd;
      const words = box.value.slice(a, b) || t('words');
      const text = '[' + words + '](https://)';
      replace(a, b, text, words.length + 3, text.length - 1);
    }

    function table(columns, rows) {
      const cell = function (i) { return ' ' + t('Column') + ' ' + (i + 1) + ' '; };
      let text = '|';
      for (let i = 0; i < columns; i++) text += cell(i) + '|';
      text += '\n|';
      for (let i = 0; i < columns; i++) text += ' --- |';
      for (let r = 0; r < rows - 1; r++) {
        text += '\n|';
        for (let i = 0; i < columns; i++) text += '   |';
      }
      const a = box.selectionStart, v = box.value;
      // a table needs a blank line before it
      const lead = a === 0 || v.slice(a - 2, a) === '\n\n' ? '' : (v[a - 1] === '\n' ? '\n' : '\n\n');
      replace(a, box.selectionEnd, lead + text + '\n', lead.length + 2, lead.length + 2 + cell(0).length - 2);
    }

    // ---- a small box under a button: the heading menu, the table grid, a part's own finder

    let open = null;
    function closePop() { if (open) { open.remove(); open = null; } }
    document.addEventListener('pointerdown', function (e) { if (open && !open.contains(e.target) && !e.target.closest('.editor-tools, .editor-side')) closePop(); });
    document.addEventListener('keydown', function (e) { if (e.key === 'Escape' && open) { closePop(); box.focus(); } });
    function pop(button) {
      closePop();
      open = el('div', 'editor-tools-pop');
      button.after(open);
      // under its own button, but never past the right edge of the bar
      const card = open;
      requestAnimationFrame(function () {
        const room = button.parentElement.clientWidth;
        card.style.left = Math.max(0, Math.min(button.offsetLeft, room - card.offsetWidth)) + 'px';
      });
      return open;
    }

    function tableGrid(button) {
      const card = pop(button);
      const size = el('p', 'editor-tools-size', '');
      const grid = el('div', 'editor-tools-grid');
      for (let r = 1; r <= 6; r++) {
        for (let c = 1; c <= 6; c++) {
          const cell = el('button');
          cell.type = 'button';
          cell.dataset.r = r;
          cell.dataset.c = c;
          cell.setAttribute('aria-label', t('%s table', c + ' × ' + r));
          cell.addEventListener('pointerenter', function () {
            for (const x of grid.children) x.classList.toggle('on', +x.dataset.r <= r && +x.dataset.c <= c);
            size.textContent = t('%s table', c + ' × ' + r);
          });
          cell.addEventListener('click', function () { closePop(); table(c, r); });
          grid.appendChild(cell);
        }
      }
      card.append(grid, size);
    }

    // ---- headings: a short menu, as GitLab has; # is left for the page's own title

    function setHeading(level) {
      const l = lines();
      const rest = l.text.replace(/^#{1,6}\s+/, '');
      replace(l.from, l.to, level ? '#'.repeat(level) + ' ' + rest : rest);
    }

    function headingMenu(button) {
      const card = pop(button);
      card.classList.add('editor-tools-menu');
      const now = (/^(#{1,6})\s+/.exec(lines().text) || ['', ''])[1].length;
      for (const [level, words] of [[2, t('Heading')], [3, t('Subheading')], [4, t('Small heading')], [0, t('Normal text')]]) {
        const b = el('button', 'editor-tools-h' + level, words);
        b.type = 'button';
        if (level === now) b.setAttribute('aria-current', 'true');
        b.addEventListener('click', function () { closePop(); setHeading(level); });
        card.appendChild(b);
      }
      card.querySelector('button').focus();
    }

    // ---- pictures: dropped on the text, pasted into it or chosen; each stands
    // as a line saying it is on its way until the part has taken it

    const chooser = el('input');
    chooser.type = 'file';
    chooser.accept = opts.pictures ? opts.pictures.accept : '';
    chooser.multiple = true;
    chooser.hidden = true;
    if (form) form.appendChild(chooser);
    chooser.addEventListener('change', function () { upload(Array.from(chooser.files)); chooser.value = ''; });
    // the kinds asked for are read when the chooser opens, so one input serves both links
    function choose(accept) {
      chooser.accept = typeof accept === 'string' ? accept : (opts.pictures ? opts.pictures.accept : '');
      chooser.click();
    }
    // camera photos go up smaller unless this is ticked
    const full = el('input');
    full.type = 'checkbox';

    let pending = 0;
    async function upload(list) {
      if (!opts.pictures) return;
      if (!full.checked && window.Keys) list = await Promise.all(list.map(Keys.smaller));
      for (const f of list) {
        // the part says what it takes; left to itself the editor takes pictures
        const refusal = opts.pictures.refuses ? opts.pictures.refuses(f)
          : (opts.pictures.types.test(f.type) ? '' : t('Only pictures can be added: PNG, JPEG, GIF or WebP. %s is not one.', f.name || ''));
        if (refusal) {
          say(refusal, true);
          continue;
        }
        // a pasted screenshot has no useful name of its own
        const name = !f.name || /^image\.\w+$/i.test(f.name) ? 'Screenshot ' + new Date().toISOString().slice(0, 19).replace(/[T:]/g, '-') + '.' + f.type.split('/')[1].replace('jpeg', 'jpg') : f.name;
        const mark = '[' + t('Uploading %s…', name) + ']';
        const a = box.selectionStart, v = box.value;
        const lead = a === 0 || v[a - 1] === '\n' ? '' : '\n';
        replace(a, box.selectionEnd, lead + mark + '\n');
        send(f, name, mark);
      }
    }

    async function send(f, name, mark) {
      pending++;
      busy();
      let put = '';
      try {
        const done = await opts.pictures.send(f, name);
        put = done.put || '';
        if (done.words) say(done.words);
      } catch (e) {
        say(e.message || t('The picture could not be uploaded.'), true);
      } finally {
        pending--;
        busy();
      }
      const at = box.value.indexOf(mark);
      if (at < 0) return;
      const end = at + mark.length + (put || box.value[at + mark.length] !== '\n' ? 0 : 1);
      const keepA = box.selectionStart, keepB = box.selectionEnd, shift = put.length - (end - at);
      replace(at, end, put);
      const fix = function (x) { return x > at ? Math.max(at, x + shift) : x; };
      box.setSelectionRange(fix(keepA), fix(keepB));
    }

    if (opts.pictures) {

      // the text box takes dropped and pasted pictures
      box.addEventListener('dragover', function (e) {
        if (e.dataTransfer && Array.from(e.dataTransfer.types).includes('Files')) { e.preventDefault(); shell.classList.add('dropping'); }
      });
      box.addEventListener('dragleave', function () { shell.classList.remove('dropping'); });
      box.addEventListener('drop', function (e) {
        shell.classList.remove('dropping');
        const list = e.dataTransfer ? Array.from(e.dataTransfer.files) : [];
        if (!list.length) return;
        e.preventDefault();
        // the drop point becomes the cursor, so the picture goes where it fell
        if (document.caretPositionFromPoint) {
          const p = document.caretPositionFromPoint(e.clientX, e.clientY);
          if (p && p.offsetNode === box) box.setSelectionRange(p.offset, p.offset);
        }
        upload(list);
      });
      box.addEventListener('paste', function (e) {
        const list = e.clipboardData ? Array.from(e.clipboardData.files || []) : [];
        if (!list.length) return;
        e.preventDefault();
        upload(list);
      });
    }

    // ---- the frame: tools over the text, the views on the right, a line
    // under it all for help and news

    const shell = el('div', 'editor editor-shell' + (opts.compact ? ' editor-compact' : ''));
    const bar = el('div', 'editor-bar');
    const tools = el('div', 'editor-tools');
    tools.setAttribute('role', 'toolbar');
    tools.setAttribute('aria-label', t('Formatting'));
    const side = el('div', 'editor-side');
    bar.append(tools, side);
    function tool(label, keys, mark, act) {
      const b = el('button', 'editor-tool');
      b.type = 'button';
      b.title = label + (keys ? ' (' + keys + ')' : '');
      b.setAttribute('aria-label', label);
      b.innerHTML = mark;   // safe html: the toolbar's own icons, written here
      b.addEventListener('click', function () { act(b); });
      tools.appendChild(b);
      return b;
    }
    function gap() { tools.appendChild(el('span', 'editor-tool-gap')); }
    tool(t('Heading'), '', 'H<span class="editor-tool-more" aria-hidden="true">▾</span>', headingMenu).setAttribute('aria-haspopup', 'menu');
    tool(t('Bold'), mod + 'B', '<b>B</b>', function () { wrap('**', '**', t('bold')); });
    tool(t('Italic'), mod + 'I', '<i>I</i>', function () { wrap('_', '_', t('italic')); });
    tool(t('Strikethrough'), mod + shiftKey + 'X', '<s>S</s>', function () { wrap('~~', '~~', t('words')); });
    gap();
    tool(t('Link'), mod + 'K', svg('<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>'), link);
    if (opts.linkTools) opts.linkTools(editor);
    gap();
    tool(t('Bulleted list'), mod + shiftKey + '8', svg('<path d="M9 6h11M9 12h11M9 18h11"/><circle cx="4.5" cy="6" r="1.2"/><circle cx="4.5" cy="12" r="1.2"/><circle cx="4.5" cy="18" r="1.2"/>'), bullets);
    tool(t('Numbered list'), mod + shiftKey + '7', '1.', numbers);
    tool(t('Quote'), '', '❝', function () { prefix(function () { return '> '; }, /^>\s?/); });
    gap();
    tool(t('Code'), mod + 'E', '&lt;/&gt;', code);
    tool(t('Table'), '', svg('<rect x="3" y="5" width="18" height="14" rx="1.5"/><path d="M3 10h18M3 14.5h18M9 5v14M15 5v14"/>'), tableGrid);
    // ---- emoji: a button with the whole set, and suggestions as a :keyword is typed

    let emojiAsked = null;
    function emojiSet() {
      if (!emojiAsked) emojiAsked = Promise.resolve().then(opts.emoji).then(function (list) { return Array.isArray(list) ? list : []; })
        .catch(function () { emojiAsked = null; return []; });
      return emojiAsked;
    }
    // the set's own picture, or the emoji as the font draws it
    function emojiFace(e) {
      if (e.src) { const i = el('img', 'emo'); i.src = e.src; i.alt = e.emoji; return i; }
      return el('span', 'emo', e.emoji);
    }
    const groupWords = {status: t('Status'), color: t('Colors'), symbol: t('Symbols'), own: t('This site\'s own')};
    function emojiPanel(button) {
      const card = pop(button);
      card.classList.add('editor-emoji');
      const a = box.selectionStart, b = box.selectionEnd;
      const find = el('input');
      find.type = 'search';
      find.placeholder = t('Find an emoji');
      find.setAttribute('aria-label', t('Find an emoji'));
      const grid = el('div', 'editor-emoji-grid');
      card.append(find, grid);
      function fill(list) {
        grid.replaceChildren();
        const q = find.value.trim().toLowerCase().replace(/:/g, '');
        let group = null;
        for (const e of list) {
          if (q && e.name.toLowerCase().indexOf(q) < 0 && !e.keywords.some(function (k) { return k.indexOf(q) >= 0; })) continue;
          if (!q && e.group !== group) { group = e.group; grid.appendChild(el('div', 'editor-emoji-group', groupWords[group] || group)); }
          const cell = el('button', 'editor-emoji-cell');
          cell.type = 'button';
          cell.title = e.name + (e.keywords.length ? '  :' + e.keywords[0] + ':' : '');
          cell.setAttribute('aria-label', e.name);
          cell.appendChild(emojiFace(e));
          cell.addEventListener('click', function () { closePop(); replace(a, b, e.emoji); });
          grid.appendChild(cell);
        }
        if (!grid.querySelector('button')) grid.appendChild(el('p', 'editor-emoji-none', t('No emoji has that name.')));
      }
      emojiSet().then(function (list) {
        fill(list);
        find.addEventListener('input', function () { fill(list); });
      });
      find.addEventListener('keydown', function (e) {
        if (e.key === 'Enter') { e.preventDefault(); const first = grid.querySelector('button'); if (first) first.click(); }
      });
      requestAnimationFrame(function () { find.focus(); });
    }
    if (opts.emoji)
      tool(t('Emoji'), '', svg('<rect x="3.5" y="3.5" width="17" height="17" rx="4.5"/><path d="M8 12.4l2.8 2.8L16.2 9.6"/>'), emojiPanel).setAttribute('aria-haspopup', 'dialog');

    // where the caret is on the screen, measured with a copy of the box's text
    function caretPoint(index) {
      const cs = getComputedStyle(box);
      const copy = el('div');
      for (const p of ['boxSizing', 'width', 'fontFamily', 'fontSize', 'fontWeight', 'fontStyle', 'lineHeight', 'letterSpacing', 'wordSpacing', 'tabSize',
        'textIndent', 'paddingTop', 'paddingRight', 'paddingBottom', 'paddingLeft', 'borderTopWidth', 'borderRightWidth', 'borderBottomWidth', 'borderLeftWidth'])
        copy.style[p] = cs[p];
      copy.style.position = 'absolute';
      copy.style.visibility = 'hidden';
      copy.style.whiteSpace = 'pre-wrap';
      copy.style.overflowWrap = 'break-word';
      copy.style.borderStyle = 'solid';
      copy.style.top = '0';
      copy.style.left = '-9999px';
      copy.textContent = box.value.slice(0, index);
      const mark = el('span', '', '​');
      copy.appendChild(mark);
      document.body.appendChild(copy);
      const r = box.getBoundingClientRect();
      const point = {top: r.top + mark.offsetTop - box.scrollTop + mark.offsetHeight, left: r.left + mark.offsetLeft - box.scrollLeft};
      copy.remove();
      return point;
    }
    let suggest = null, choices = [], chosen = 0, typedFrom = -1;
    let eager = false;   // opened by an arrow key: a colon alone is enough
    let typedAt = -1;    // where the caret was left by typing: arrows open the list only there
    function closeSuggest() { if (suggest) { suggest.remove(); suggest = null; } choices = []; eager = false; }
    function takeChoice(i) {
      const e = choices[i];
      const at = box.selectionStart;
      closeSuggest();
      if (e && typedFrom >= 0) replace(typedFrom, at, e.emoji);
    }
    // The one selected row, for the keys and the pointer alike.
    function mark(i) {
      chosen = i;
      Array.from(suggest.children).forEach(function (row, n) { row.classList.toggle('on', n === i); });
    }
    function showSuggest() {
      if (!suggest) {
        suggest = el('ul', 'editor-suggest');
        suggest.setAttribute('role', 'listbox');
        // a click keeps the caret in the text
        suggest.addEventListener('pointerdown', function (e) { e.preventDefault(); });
        document.body.appendChild(suggest);
      }
      suggest.replaceChildren();
      choices.forEach(function (e, i) {
        const row = el('li');
        row.setAttribute('role', 'option');
        const key = e.match || e.keywords[0] || '';
        // a name that only says the keyword again is left out
        row.append(emojiFace(e), el('span', 'editor-suggest-key', ':' + key + ':'), el('span', 'editor-suggest-name', e.name === key ? '' : e.name));
        row.addEventListener('mousemove', function () { if (chosen !== i) mark(i); });
        row.addEventListener('click', function () { takeChoice(i); });
        suggest.appendChild(row);
      });
      mark(0);
      const p = caretPoint(typedFrom);
      suggest.style.top = Math.min(p.top + 4, window.innerHeight - suggest.offsetHeight - 8) + 'px';
      suggest.style.left = Math.max(8, Math.min(p.left, window.innerWidth - suggest.offsetWidth - 8)) + 'px';
    }
    if (opts.emoji) {
      // ev: the input that brought this, none when an arrow key asks
      const offer = function (ev) {
        const at = box.selectionStart;
        // the keyword being typed, as every part finds it (emoji-names.js);
        // one finished with its second colon becomes its emoji at once
        const typing = at === box.selectionEnd && EmojiNames.typed(box.value, at, eager);
        if (!typing || (typing.whole && !(ev && ev.data === ':'))) { closeSuggest(); return; }
        typedFrom = typing.from;
        emojiSet().then(function (list) {
          if (box.selectionStart !== at) return;
          if (typing.whole) {
            const hit = EmojiNames.named(list, typing.word);
            closeSuggest();
            if (hit) replace(typedFrom, at, hit.emoji);
            return;
          }
          choices = EmojiNames.matches(list, typing.word).slice(0, 8);
          if (choices.length) showSuggest(); else closeSuggest();
        });
      };
      box.addEventListener('input', function (ev) { offer(ev); typedAt = box.selectionStart; });
      box.addEventListener('keydown', function (e) {
        const arrow = (e.key === 'ArrowDown' || e.key === 'ArrowUp') && !e.shiftKey && !e.ctrlKey && !e.altKey && !e.metaKey;
        if (!suggest || !choices.length) {
          // an arrow key after a colon, or a colon and one letter, opens the list
          const short = arrow && box.selectionStart === typedAt && box.selectionEnd === typedAt && EmojiNames.typed(box.value, typedAt, true);
          if (!short || short.whole || short.word.length > 1) return;
          eager = true;
          offer();
        } else if (arrow) {
          mark((chosen + (e.key === 'ArrowDown' ? 1 : choices.length - 1)) % choices.length);
        } else if (e.key === 'Enter' || e.key === 'Tab') {
          takeChoice(chosen);
        } else if (e.key === 'Escape') {
          closeSuggest();
          typedAt = -1;
        } else return;
        e.preventDefault();
        e.stopImmediatePropagation();
      });
      box.addEventListener('blur', closeSuggest);
      box.addEventListener('scroll', closeSuggest);
      window.addEventListener('resize', closeSuggest);
    }
    function bullets() { prefix(function () { return '- '; }, /^(\s*)[-*+]\s+/); }
    function numbers() { prefix(function (i) { return (i + 1) + '. '; }, /^(\s*)\d+[.)]\s+/); }

    // ---- write, side by side, preview; and the whole window

    const modes = el('div', 'editor-modes');
    modes.setAttribute('role', 'tablist');
    const whole = el('button', 'editor-whole');
    whole.type = 'button';
    whole.innerHTML = svg('<path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5"/>');   // safe html: a fixed icon
    side.append(modes, whole);
    const panes = el('div', 'editor-panes');
    const view = el('div', 'editor-view' + (opts.viewClass ? ' ' + opts.viewClass : ''));
    view.setAttribute('aria-live', 'polite');
    const foot = el('div', 'editor-foot');
    const news = el('span', 'editor-news');
    news.setAttribute('role', 'status');
    const hint = el('span', 'editor-hint');
    const attach = el('button', 'editor-link', (opts.pictures && opts.pictures.label) || t('add pictures'));
    attach.type = 'button';
    attach.addEventListener('click', choose);
    hint.append(document.createTextNode(opts.hint || t('Markdown.')));
    if (opts.pictures) {
      hint.append(document.createTextNode(' '), attach);
      // Android's chooser has the camera and the file browser but no gallery,
      // unless pictures alone are asked for: a second link asks for those
      if (opts.pictures.gallery && /Android/.test(navigator.userAgent)) {
        const gallery = el('button', 'editor-link', /video/.test(opts.pictures.gallery) ? t('Photos and videos') : t('Photos'));
        gallery.type = 'button';
        gallery.addEventListener('click', function () { choose(opts.pictures.gallery); });
        hint.append(document.createTextNode(' · '), gallery);
      }
      const fullLabel = el('label', 'editor-full', '');
      fullLabel.append(full, ' ' + t('Photos at full size'));
      fullLabel.title = t('A camera photo is made smaller before it is sent, which is much quicker on a phone. Tick this to send it as it is.');
      hint.append(document.createTextNode(' '), fullLabel);
    }
    const helpButton = el('button', 'editor-link', t('Formatting help'));
    helpButton.type = 'button';
    helpButton.setAttribute('aria-expanded', 'false');
    foot.append(hint, news, helpButton);
    const help = el('div', 'editor-help');
    help.hidden = true;
    // a box inside its label comes out of it: a click on the preview or a
    // menu would otherwise go to the box, as clicks in a label do
    const label = box.closest('label');
    if (label) {
      if (!box.id) box.id = 'editor-box-' + (++made);
      label.htmlFor = box.id;
      label.after(shell);
    } else box.before(shell);
    shell.append(bar, panes, foot, help);
    panes.append(box, view);
    // the form's own parts the part wants under the editor: full screen
    // takes the row along, so the text can be sent without leaving it
    const sendRow = el('div', 'editor-send');
    shell.after(sendRow);
    for (const part of opts.sendRow || []) if (part) sendRow.appendChild(part);
    sendRow.hidden = !sendRow.firstChild;

    const cheats = [
      ['## ' + t('Heading'), t('a heading; ### for a smaller one')],
      ['**' + t('bold') + '**  _' + t('italic') + '_  ~~' + t('struck') + '~~', t('emphasis')],
      ['`code`', t('code in a sentence')],
      ['```' + (language || 'pascal') + '\nbegin\nend.\n```', t('a block of code; the word after ``` names its language, for its colors')],
      ['- ' + t('item') + '\n1. ' + t('item'), t('lists; Tab moves an item in, Shift+Tab out')],
      ['> ' + t('words'), t('a quotation')],
      ['[' + t('words') + '](https://…)', t('a link to another site')],
    ].concat(opts.cheats || []);
    const sheet = el('table');
    for (const [mark, what] of cheats) {
      const tr = el('tr');
      const a = el('td');
      a.appendChild(el('code', '', mark));
      tr.append(a, el('td', '', what));
      sheet.appendChild(tr);
    }
    const keys = el('p', 'fine', t('Keys: %s bold, %s italic, %s link, %s code, %s preview, %s save.', mod + 'B', mod + 'I', mod + 'K', mod + 'E', mod + shiftKey + 'P', mod + 'Enter'));
    help.append(sheet, keys);
    if (opts.helpLink) {
      const more = el('p', 'fine');
      const guide = el('a', '', opts.helpLink.words);
      guide.href = opts.helpLink.href;
      guide.target = '_blank';
      more.appendChild(guide);
      help.appendChild(more);
    }
    helpButton.addEventListener('click', function () {
      help.hidden = !help.hidden;
      helpButton.setAttribute('aria-expanded', help.hidden ? 'false' : 'true');
    });

    let newsTimer = 0;
    function say(words, bad) {
      clearTimeout(newsTimer);
      news.textContent = words;
      news.classList.toggle('bad', !!bad);
      if (!bad) newsTimer = setTimeout(function () { busy(); }, 4000);
    }
    function busy() {
      if (pending) { news.classList.remove('bad'); news.textContent = window.tn ? tn(pending, 'Uploading %d picture…', 'Uploading %d pictures…') : t('Uploading…'); }
      else if (!news.classList.contains('bad')) news.textContent = '';
    }

    const narrow = window.matchMedia('(max-width: 899px)');
    const storeKey = opts.storeKey || 'editor-mode';
    let mode = opts.mode || 'split';
    try { mode = localStorage.getItem(storeKey) || mode; } catch (e) { }
    // a part with no renderer has the text alone
    if (!opts.preview) { mode = 'write'; modes.hidden = true; }
    const shown = function () { return mode === 'split' && narrow.matches ? 'write' : mode; };
    const tabs = {};
    for (const [key, words] of [['write', t('Write')], ['split', t('Side by side')], ['preview', t('Preview')]]) {
      const b = el('button', 'editor-mode', words);
      b.type = 'button';
      b.setAttribute('role', 'tab');
      b.dataset.mode = key;
      b.addEventListener('click', function () { setMode(key); });
      tabs[key] = b;
      modes.appendChild(b);
    }
    function setMode(key) {
      mode = key;
      try { localStorage.setItem(storeKey, mode); } catch (e) { }
      draw();
      if (shown() !== 'preview') box.focus();
    }
    function draw() {
      const now = shown();
      panes.dataset.mode = now;
      bar.dataset.mode = now;
      for (const key in tabs) tabs[key].setAttribute('aria-selected', key === now ? 'true' : 'false');
      tabs.split.hidden = narrow.matches;
      for (const b of tools.querySelectorAll('.editor-tool')) b.disabled = now === 'preview';
      if (now === 'preview') closePop();
      if (now !== 'write' && stale) ask();
      else if (now === 'split') { measure(); follow(); }
    }
    if (narrow.addEventListener) narrow.addEventListener('change', draw);

    function setWhole(on, quiet) {
      shell.classList.toggle('whole', on);
      if (on) foot.after(sendRow); else shell.after(sendRow);
      requestAnimationFrame(function () { measure(); follow(); });
      document.documentElement.classList.toggle('editor-whole', on);
      whole.setAttribute('aria-pressed', on ? 'true' : 'false');
      whole.title = on ? t('Leave full screen (Esc)') : t('Full screen');
      whole.setAttribute('aria-label', whole.title);
      if (!quiet) box.focus();
    }
    whole.addEventListener('click', function () { setWhole(!shell.classList.contains('whole')); });
    setWhole(false, true);
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape' && !open && shell.classList.contains('whole')) setWhole(false);
    });

    // ---- the preview, a moment after typing stops

    let stale = true, timer = 0, asking = null;
    async function ask() {
      stale = false;
      if (asking) asking.abort();
      const mine = new AbortController();
      asking = mine;
      view.classList.add('busy');
      // the first time there is nothing to dim: say it is coming
      if (!view.firstChild) view.appendChild(el('p', 'fine', t('Making the preview…')));
      try {
        const html = await opts.preview(box.value, mine.signal);
        if (asking !== mine) return;
        view.innerHTML = html;   // safe html: the part's own renderer made it
        if (!box.value.trim()) view.replaceChildren(el('p', 'fine', opts.emptyWords || t('The preview shows here as you write.')));
        else if (opts.afterPreview) opts.afterPreview(view);
        measure();
        follow();
      } catch (e) {
        if (e.name === 'AbortError') return;
        stale = true;
        view.replaceChildren(el('p', 'problem', t('The preview could not be made. It tries again when you type.')));
      } finally {
        if (asking === mine) { asking = null; view.classList.remove('busy'); }
      }
    }
    box.addEventListener('input', function () {
      stale = true;
      clearTimeout(timer);
      if (shown() !== 'write') timer = setTimeout(ask, 700);
    });

    // side by side: the preview keeps to the same part of the page as the
    // text.  Each heading in the text is tied to its heading in the preview,
    // and between two headings the preview moves in step; a page whose
    // headings do not pair up one for one goes by how far down the text is.
    let ties = null;
    const mirror = el('div');
    mirror.setAttribute('aria-hidden', 'true');
    mirror.style.cssText = 'position:absolute;visibility:hidden;pointer-events:none;top:0;left:-9999px;white-space:pre-wrap;overflow-wrap:break-word;box-sizing:border-box;border:0;margin:0;';

    // where each heading line of the text starts
    function headingStarts() {
      const starts = [];
      let at = 0, fence = '';
      for (const line of box.value.split('\n')) {
        const mark = /^ {0,3}(`{3,}|~{3,})(.*)$/.exec(line);
        if (mark) {
          if (!fence) fence = mark[1];
          else if (mark[1][0] === fence[0] && mark[1].length >= fence.length && !mark[2].trim()) fence = '';
        } else if (!fence && /^ {0,3}#{1,6}([ \t]|$)/.test(line)) starts.push({at: at, words: plain(line.replace(/^\s*#+/, '').replace(/\[\[(?:[^\]|]*\|)?([^\]]*)\]\]/g, '$1').replace(/\[([^\]]*)\]\([^)]*\)/g, '$1'))});
        at += line.length + 1;
      }
      return starts;
    }
    // a heading's letters and digits alone, so the text's heading and the page's can be told to be the same
    function plain(words) { return words.replace(/[^\p{L}\p{N}]+/gu, '').toLowerCase(); }

    function measure() {
      ties = null;
      if (shown() !== 'split') return;
      const heads = Array.from(view.querySelectorAll(opts.heads || 'h1, h2, h3, h4, h5, h6'));
      // each heading of the text with its own heading in the preview, in order;
      // one that has no partner (a heading inside a quotation, say) is passed over
      const starts = [], paired = [];
      let next = 0;
      for (const h of headingStarts()) {
        for (let k = next; k < Math.min(heads.length, next + 4); k++) {
          if (plain(heads[k].textContent) !== h.words) continue;
          starts.push(h.at);
          paired.push(heads[k]);
          next = k + 1;
          break;
        }
      }
      if (!starts.length) return;
      // the text laid out as the box lays it out, with a mark at each heading
      const look = getComputedStyle(box);
      for (const k of ['fontFamily', 'fontSize', 'fontWeight', 'lineHeight', 'letterSpacing', 'tabSize', 'paddingTop', 'paddingRight', 'paddingBottom', 'paddingLeft'])
        mirror.style[k] = look[k];
      mirror.style.width = box.clientWidth + 'px';
      mirror.replaceChildren();
      const marks = [];
      let from = 0;
      for (const at of starts) {
        mirror.append(box.value.slice(from, at));
        const mark = el('span');
        mirror.append(mark);
        marks.push(mark);
        from = at;
      }
      mirror.append(box.value.slice(from));
      document.body.appendChild(mirror);
      const textMax = box.scrollHeight - box.clientHeight, viewMax = view.scrollHeight - view.clientHeight;
      const top = view.getBoundingClientRect().top - view.scrollTop;
      const made = [[0, 0]];
      for (let i = 0; i < marks.length; i++) {
        const a = Math.min(marks[i].offsetTop - parseFloat(look.paddingTop), textMax);
        const b = Math.min(paired[i].getBoundingClientRect().top - top - 12, viewMax);
        const last = made[made.length - 1];
        if (a > last[0] && b >= last[1]) made.push([a, b]);
      }
      mirror.remove();
      mirror.replaceChildren();
      if (textMax > made[made.length - 1][0]) made.push([textMax, Math.max(viewMax, made[made.length - 1][1])]);
      ties = made;
    }

    function follow() {
      if (shown() !== 'split') return;
      const y = box.scrollTop;
      if (ties && ties.length > 1) {
        let i = 0;
        while (i < ties.length - 2 && ties[i + 1][0] <= y) i++;
        const a = ties[i], b = ties[i + 1];
        const part = b[0] > a[0] ? Math.min(1, Math.max(0, (y - a[0]) / (b[0] - a[0]))) : 0;
        view.scrollTop = a[1] + part * (b[1] - a[1]);
        return;
      }
      const room = box.scrollHeight - box.clientHeight;
      view.scrollTop = room > 0 ? (y / room) * (view.scrollHeight - view.clientHeight) : 0;
    }
    box.addEventListener('scroll', follow, {passive: true});
    // a picture that arrives, or a window made wider, moves every heading
    let again = 0;
    const remeasure = function () { clearTimeout(again); again = setTimeout(function () { measure(); follow(); }, 150); };
    view.addEventListener('load', remeasure, true);
    window.addEventListener('resize', remeasure);

    // ---- keys: the toolbar's, and lists that go on by themselves

    function save() {
      if (pending) { say(t('Wait until the pictures are uploaded.'), true); return; }
      if (!form) return;
      const button = form.querySelector('button[type="submit"]:not([name])');
      if (form.requestSubmit) form.requestSubmit(button || undefined);
      else if (button) button.click();
    }

    shell.addEventListener('keydown', function (e) {
      if (!(e.ctrlKey || e.metaKey) || e.altKey) return;
      const k = e.key.toLowerCase();
      if (k === 'enter') { e.preventDefault(); save(); return; }
      if (e.shiftKey && k === 'p') { e.preventDefault(); setMode(shown() === 'preview' ? (narrow.matches ? 'write' : 'split') : 'preview'); }
    });

    box.addEventListener('keydown', function (e) {
      const k = e.key.toLowerCase();
      if ((e.ctrlKey || e.metaKey) && !e.altKey) {
        const act = e.shiftKey
          ? {x: function () { wrap('~~', '~~', t('words')); }, '*': bullets, '8': bullets, '&': numbers, '7': numbers}[e.code === 'Digit8' ? '8' : e.code === 'Digit7' ? '7' : k]
          : {b: function () { wrap('**', '**', t('bold')); }, i: function () { wrap('_', '_', t('italic')); }, k: link, e: code}[k];
        if (act) { e.preventDefault(); act(); return; }
      }
      if (e.ctrlKey || e.metaKey || e.altKey || box.selectionStart !== box.selectionEnd) return;
      const v = box.value, at = box.selectionStart;
      const start = v.lastIndexOf('\n', at - 1) + 1;
      const line = v.slice(start, at);
      const item = /^(\s*)([-*+]|\d+[.)]|>)(\s+)/.exec(line);
      if (e.key === 'Enter' && !e.shiftKey && item) {
        e.preventDefault();
        // an empty item ends the list
        if (line.length === item[0].length) { replace(start, at, ''); return; }
        const next = /\d/.test(item[2]) ? (parseInt(item[2], 10) + 1) + item[2].slice(-1) : item[2];
        replace(at, at, '\n' + item[1] + next + item[3]);
        return;
      }
      // Tab moves a list item in or out; elsewhere it leaves the box, as it should
      if (e.key === 'Tab' && item && item[2] !== '>') {
        e.preventDefault();
        if (e.shiftKey) {
          const cut = Math.min(2, item[1].length);
          if (cut) replace(start, start + cut, '', 0, 0);
          box.setSelectionRange(at - cut, at - cut);
        } else {
          replace(start, start, '  ', 0, 0);
          box.setSelectionRange(at + 2, at + 2);
        }
      }
    });

    // ---- not leaving with changes unsaved, nor sending half an upload

    const first = box.value;
    let saving = false;
    // heard first (capture), so a part that sends the form itself does not
    // send it with a file still on its way
    if (form) form.addEventListener('submit', function (e) {
      if (pending) { e.preventDefault(); e.stopImmediatePropagation(); say(t('Wait until the pictures are uploaded.'), true); return; }
      saving = true;
    }, true);
    // a part whose save was refused says so: the text is still unsaved
    editor.notSaved = function () { saving = false; };
    window.addEventListener('beforeunload', function (e) {
      if (!saving && box.value !== first) { e.preventDefault(); e.returnValue = ''; }
    });

    editor.shell = shell;
    editor.view = view;
    draw();
    if (shown() !== 'write') ask();
    box.editor = editor;
    return editor;
  }

  window.Editor = {attach: attach};
})();
