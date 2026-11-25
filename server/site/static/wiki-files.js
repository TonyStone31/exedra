'use strict';
document.querySelectorAll('.wiki-file-upload').forEach(form => {
  const message = document.createElement('p');
  message.setAttribute('role', 'status');
  form.append(message);
  form.addEventListener('submit', async event => {
    event.preventDefault();
    const button = form.querySelector('button');
    button.disabled = true;
    message.textContent = '';
    try {
      const response = await fetch(form.action, {method: 'POST', body: new FormData(form)});
      if (!response.ok) {
        const content = await response.text();
        try {
          const conflict = JSON.parse(content);
          if (conflict.conflict) {
            form.elements.name.value = conflict.suggested;
            message.textContent = window.t('That name is already used. A free name has been filled in.');
            return;
          }
        } catch (_) { /* The server also returns plain text refusals. */ }
        throw new Error(content);
      }
      const info = await response.json();
      location.assign(SiteBase.url(info.page));
    } catch (error) {
      message.textContent = error.message;
    } finally {
      button.disabled = false;
    }
  });
});
// deleting takes every version: ask first
document.querySelectorAll('form.wiki-file-delete[data-confirm]').forEach(form => {
  form.addEventListener('submit', event => {
    if (!window.confirm(form.dataset.confirm)) event.preventDefault();
  });
});
// the library's viewer: a picture large, with its neighbours a key or a
// swipe away; Escape, the close button or a click outside leaves it
(() => {
  const grid = document.querySelector('.wiki-file-grid');
  if (!grid) return;
  const items = Array.from(grid.querySelectorAll('a[data-view]'));
  if (!items.length) return;
  const t = window.t || (s => s);
  const make = (tag, cls, text) => { const e = document.createElement(tag); if (cls) e.className = cls; if (text !== undefined) e.textContent = text; return e; };
  const box = make('div', 'wiki-viewer');
  box.setAttribute('role', 'dialog');
  box.setAttribute('aria-modal', 'true');
  box.hidden = true;
  const stage = make('div', 'wiki-viewer-stage');
  const img = make('img');
  img.alt = '';
  stage.append(img);
  const prev = make('button', 'wiki-viewer-prev', '‹');
  const next = make('button', 'wiki-viewer-next', '›');
  const close = make('button', 'wiki-viewer-close', '×');
  prev.type = next.type = close.type = 'button';
  prev.setAttribute('aria-label', t('Previous'));
  next.setAttribute('aria-label', t('Next'));
  close.setAttribute('aria-label', t('Close'));
  const bar = make('div', 'wiki-viewer-bar');
  const name = make('b');
  const info = make('span');
  const open = make('a', '', t('Open its page'));
  bar.append(name, info, open);
  box.append(stage, prev, next, close, bar);
  document.body.append(box);
  let at = 0, back = null;
  const show = i => {
    at = (i + items.length) % items.length;
    const a = items[at];
    img.src = a.dataset.view;
    name.textContent = a.querySelector('.wiki-file-name').textContent;
    info.textContent = a.dataset.size + ' · ' + (at + 1) + ' / ' + items.length;
    open.href = SiteBase.strip(a.getAttribute('href'));
    // the next one starts loading now, so a key press shows it at once
    new Image().src = items[(at + 1) % items.length].dataset.view;
  };
  const leave = () => {
    box.hidden = true;
    document.documentElement.classList.remove('wiki-viewing');
    if (back) back.focus();
  };
  items.forEach((a, i) => a.addEventListener('click', event => {
    if (event.ctrlKey || event.metaKey || event.shiftKey || event.button !== 0) return;
    event.preventDefault();
    back = a;
    show(i);
    box.hidden = false;
    document.documentElement.classList.add('wiki-viewing');
    close.focus();
  }));
  prev.addEventListener('click', () => show(at - 1));
  next.addEventListener('click', () => show(at + 1));
  close.addEventListener('click', leave);
  box.addEventListener('click', event => { if (event.target === box || event.target === stage) leave(); });
  document.addEventListener('keydown', event => {
    if (box.hidden) return;
    if (event.key === 'Escape') leave();
    else if (event.key === 'ArrowLeft') show(at - 1);
    else if (event.key === 'ArrowRight') show(at + 1);
    else return;
    event.preventDefault();
  });
  let startX = null;
  stage.addEventListener('touchstart', event => { startX = event.touches[0].clientX; }, {passive: true});
  stage.addEventListener('touchend', event => {
    if (startX === null) return;
    const dx = event.changedTouches[0].clientX - startX;
    startX = null;
    if (Math.abs(dx) > 50) show(at + (dx < 0 ? 1 : -1));
  });
})();
