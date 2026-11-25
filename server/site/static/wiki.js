/* The language form also works when scripts are disabled. */
'use strict';
for (const form of document.querySelectorAll('.wiki-language')) {
  const picker = form.querySelector('select');
  picker.addEventListener('change', () => form.requestSubmit());
  form.querySelector('button').hidden = true;
}

/* Times come as UTC; a script shows them on the reader's clock, as the
   admin chose to show dates (words.js); a date alone stays a date. */
for (const stamp of document.querySelectorAll('time[datetime]')) {
  const when = new Date(stamp.dateTime);
  if (Number.isNaN(when.getTime()) || !window.dateText) continue;
  stamp.title = stamp.textContent;
  stamp.textContent = stamp.dataset.show === 'date' || stamp.dateTime.length === 10 ? window.dateText(stamp.dateTime.length === 10 ? stamp.dateTime : when)
    : window.dateTimeText(when);
}

/* Reading aids for an article, added by script so the page still works
   without one: ids on the headings, so a section can be linked to; a table
   of contents when there are three or more sections; a copy button on each
   block of code; and the language bar folded when a page has many. */
(function () {
  const body = document.querySelector('.wikipage > .wikibody');
  const page = document.querySelector('.wikipage');
  if (!body || !page) return;
  const t = window.t || function (s) { return s; };
  const tn = window.tn || function (n, one, many) { return (n === 1 ? one : many).replace('%d', n); };

  // ids: the heading's words, as MediaWiki writes them, so links from there still land
  const used = new Set();
  // a heading's words, without the edit link a member is given beside them
  const words = h => { const copy = h.cloneNode(true); for (const a of copy.querySelectorAll('.sectionedit')) a.remove(); return copy.textContent.trim(); };
  const headings = Array.from(body.querySelectorAll('h2, h3')).filter(h => words(h));
  for (const h of headings) {
    if (h.id) { used.add(h.id); continue; }
    let id = words(h).replace(/\s+/g, '_').replace(/[\[\]{}|#<>"']/g, '');
    let n = 2; const base = id;
    while (used.has(id) || document.getElementById(id)) id = base + '_' + n++;
    h.id = id; used.add(id);
  }
  if (location.hash) {
    // #section-3 is where a saved section edit comes back to
    const part = /^#section-(\d+)$/.exec(location.hash);
    const link = part && body.querySelector('.sectionedit[href$="section=' + part[1] + '"]');
    const target = link ? link.parentElement : document.getElementById(decodeURIComponent(location.hash.slice(1)));
    if (target) target.scrollIntoView();
  }

  // Save as PDF: the browser's print, with folded sections opened for the
  // paper and closed again after, whichever way the print was started
  const opened = [];
  window.addEventListener('beforeprint', () => {
    for (const d of body.querySelectorAll('details:not([open])')) { d.open = true; opened.push(d); }
  });
  window.addEventListener('afterprint', () => { while (opened.length) opened.pop().open = false; });
  for (const button of page.querySelectorAll('[data-print]')) {
    button.hidden = false;
    button.addEventListener('click', () => window.print());
  }

  // the right column on a wide screen: the contents (when there are enough
  // sections) and the page's cards, which on a phone stay at the foot
  const side = document.createElement('aside');
  side.className = 'wiki-side';
  const tools = page.querySelector(':scope > .pagetools');
  (tools || body).insertAdjacentElement(tools ? 'afterend' : 'beforebegin', side);
  page.classList.add('has-side');
  // the page's tools sit in the left column while there is one beside the page
  const toolsHead = document.querySelector('.siteside [data-page-tools]');
  if (tools && toolsHead) {
    const toolsHome = document.createComment('tools');
    tools.parentNode.insertBefore(toolsHome, tools);
    const beside = window.matchMedia('(min-width: 901px)');
    const placeTools = () => {
      toolsHead.hidden = !beside.matches;
      if (beside.matches) toolsHead.insertAdjacentElement('afterend', tools);
      else toolsHome.parentNode.insertBefore(tools, toolsHome.nextSibling);
    };
    placeTools(); beside.addEventListener('change', placeTools);
  }
  // what other units put under a page (its bench; anything marked data-beside)
  // sits in the side column on a wide screen, and where it was on a narrow one
  const movable = Array.from(page.querySelectorAll(':scope > .page-bench, :scope > [data-beside]'));
  const homes = new Map(movable.map(box => { const mark = document.createComment('home'); box.parentNode.insertBefore(mark, box); return [box, mark]; }));
  const wideSide = window.matchMedia('(min-width: 1320px)');
  const placeBoxes = () => {
    for (const box of movable) {
      if (wideSide.matches) side.appendChild(box);
      else { const mark = homes.get(box); mark.parentNode.insertBefore(box, mark.nextSibling); }
    }
  };
  placeBoxes(); wideSide.addEventListener('change', placeBoxes);
  // a part its own script redraws: the new one takes the old one's place
  new MutationObserver(records => {
    for (const r of records) for (const node of r.addedNodes)
      if (node.nodeType === 1 && node.hasAttribute('data-beside') && !movable.includes(node)) {
        const old = movable.findIndex(box => box.className === node.className && !box.isConnected);
        if (old >= 0) { homes.set(node, homes.get(movable[old])); movable[old] = node; }
      }
  }).observe(page, {childList: true, subtree: true});

  // the table of contents; not on a page laid out across the whole width
  // (one marked no-contents), where it has no column to sit in
  if (headings.length >= 3 && !document.querySelector('.no-contents')) {
    const toc = document.createElement('nav');
    toc.className = 'toc';
    toc.setAttribute('aria-label', t('On this page'));
    const details = document.createElement('details');
    const summary = document.createElement('summary');
    summary.textContent = t('On this page');
    details.appendChild(summary);
    const list = document.createElement('ol');
    for (const h of headings) {
      const li = document.createElement('li');
      li.className = h.tagName === 'H3' ? 'sub' : '';
      const a = document.createElement('a');
      a.href = '#' + encodeURIComponent(h.id);
      a.textContent = words(h);
      li.appendChild(a); list.appendChild(li);
    }
    details.appendChild(list);
    toc.appendChild(details);
    side.insertBefore(toc, side.firstChild);
    page.classList.add('has-toc');
    const wide = window.matchMedia('(min-width: 1320px)');
    const fit = () => { details.open = wide.matches; };
    fit(); wide.addEventListener('change', fit);
    // the section being read is marked in the list: the last heading above
    // a line a third of the way down the screen, and at the page's end the
    // last section, which could never reach that line on its own
    const links = headings.map((h, i) => list.children[i].firstChild);
    let current = null, ticking = false;
    const mark = () => {
      ticking = false;
      const line = window.innerHeight * 0.3;
      let index = -1;
      const atEnd = window.innerHeight + window.scrollY >= document.documentElement.scrollHeight - 4;
      if (atEnd) index = headings.length - 1;
      else headings.forEach((h, i) => { if (h.getBoundingClientRect().top <= line) index = i; });
      // above every heading, the first section is the one being read
      const next = links[index >= 0 ? index : 0] || null;
      if (next === current) return;
      if (current) current.classList.remove('now');
      current = next;
      if (current) {
        current.classList.add('now');
        // the list keeps the marked line in view when it scrolls itself
        if (current.scrollIntoView && details.open && window.matchMedia('(min-width: 1320px)').matches) current.scrollIntoView({block: 'nearest'});
      }
    };
    const onScroll = () => { if (!ticking) { ticking = true; requestAnimationFrame(mark); } };
    window.addEventListener('scroll', onScroll, {passive: true});
    window.addEventListener('resize', onScroll);
    mark();
  }

  // copy a block of code: one button, an icon, at the top right of every
  // block (the renderer's own in the code bar, one of ours on a bare block);
  // a tick for a moment when it is done
  const ICON_COPY = 'M9 9h10v10H9zM5 15V5h10';
  const ICON_DONE = 'M5 12l5 5L19 7';
  const icon = (button, path) => {
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('viewBox', '0 0 24 24'); svg.setAttribute('aria-hidden', 'true');
    const line = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    line.setAttribute('d', path); line.setAttribute('fill', 'none'); line.setAttribute('stroke', 'currentColor');
    line.setAttribute('stroke-width', '2'); line.setAttribute('stroke-linejoin', 'round'); line.setAttribute('stroke-linecap', 'round');
    svg.appendChild(line);
    button.replaceChildren(svg);
  };
  const copyButton = (b, pre) => {
    icon(b, ICON_COPY);
    b.title = t('Copy'); b.setAttribute('aria-label', t('Copy'));
    b.addEventListener('click', () => {
      navigator.clipboard.writeText(pre.textContent).then(() => {
        icon(b, ICON_DONE); b.classList.add('ok'); b.title = t('Copied');
        setTimeout(() => { icon(b, ICON_COPY); b.classList.remove('ok'); b.title = t('Copy'); }, 1500);
      });
    });
  };
  if (navigator.clipboard) {
    for (const b of body.querySelectorAll('.code .codebar .copy')) copyButton(b, b.closest('.code').querySelector('pre'));
    for (const pre of body.querySelectorAll('pre')) {
      if (pre.closest('.code')) continue;
      const wrap = document.createElement('div');
      wrap.className = 'codebox';
      pre.parentNode.insertBefore(wrap, pre);
      wrap.appendChild(pre);
      const b = document.createElement('button');
      b.type = 'button'; b.className = 'copybtn';
      copyButton(b, pre);
      wrap.appendChild(b);
    }
  } else {
    for (const b of body.querySelectorAll('.code .codebar .copy')) b.hidden = true;
  }

  // a long block of code in a box of its own height: it scrolls, its foot
  // can be dragged taller or shorter, and a bar under it shows all of it
  // (phones have no drag handle).  Copy and the printout always have all
  // of it.
  const BOX_LINES = 20;
  for (const pre of body.querySelectorAll('pre')) {
    const lines = pre.textContent.replace(/\n+$/, '').split('\n').length;
    // a few lines past the box are not worth a scroll bar
    if (lines <= BOX_LINES + 5) continue;
    const box = pre.closest('.code') || pre.closest('.codebox') || pre;
    box.classList.add('scrollbox');
    const bar = document.createElement('div');
    bar.className = 'code-boxbar';
    const whole = document.createElement('button');
    whole.type = 'button';
    whole.className = 'code-whole';
    const label = () => {
      const open = box.classList.contains('whole');
      whole.textContent = open ? t('Show less') : tn(lines, 'Show all %d line', 'Show all %d lines');
      whole.setAttribute('aria-expanded', open ? 'true' : 'false');
    };
    whole.addEventListener('click', () => {
      const open = box.classList.toggle('whole');
      // a height dragged by hand gives way to the choice just made
      pre.style.height = '';
      label();
      if (!open && box.getBoundingClientRect().top < 0) box.scrollIntoView({block: 'start'});
    });
    label();
    bar.append(whole);
    box.insertAdjacentElement(box === pre ? 'afterend' : 'beforeend', bar);
  }

  // many languages: the first few, and a button for the rest
  const bar = page.querySelector('.languages');
  if (bar) {
    // the dots the server writes between names are not wanted between pills
    for (const node of Array.from(bar.childNodes)) if (node.nodeType === 3) node.remove();
    const items = Array.from(bar.querySelectorAll('a, b'));
    const keep = 8;
    if (items.length > keep + 2) {
      const hidden = items.slice(keep).filter(el => el.tagName !== 'B');
      for (const el of hidden) el.hidden = true;
      const more = document.createElement('button');
      more.type = 'button'; more.className = 'more-languages';
      more.textContent = tn(hidden.length, '+%d more language', '+%d more languages');
      more.addEventListener('click', () => { for (const el of hidden) el.hidden = false; more.remove(); });
      bar.appendChild(more);
    }
  }
})();

/* The wiki draws its emoji with its own pictures.  A copy takes the emoji
   themselves, as text, wherever the words are pasted. */
document.addEventListener('copy', function (e) {
  const pick = window.getSelection();
  if (!pick || pick.isCollapsed || !e.clipboardData) return;
  const part = pick.getRangeAt(0).cloneContents();
  const pictures = part.querySelectorAll('img.emo');
  if (!pictures.length) return;
  for (const img of pictures) img.replaceWith(document.createTextNode(img.alt));
  const holder = document.createElement('div');
  holder.appendChild(part);
  e.clipboardData.setData('text/plain', pick.toString().length ? textOf(holder) : '');
  e.clipboardData.setData('text/html', holder.innerHTML);   // safe html: the page's own nodes, copied back out as they are
  e.preventDefault();

  // the words as the selection gives them, line breaks between blocks kept
  function textOf(node) {
    holder.style.cssText = 'position:fixed;left:-9999px;top:0;white-space:pre-wrap';
    document.body.appendChild(holder);
    const words = holder.innerText;
    holder.remove();
    return words;
  }
});
