// The site's search box offers pages and words while the reader types.
// Without this script the box is the plain form it always was.
(function () {
  'use strict';
  document.querySelectorAll('form.site-search').forEach(function (form) {
    const input = form.querySelector('input[name=q]');
    if (!input || input.dataset.offers) return;
    input.dataset.offers = '1';
    input.autocomplete = 'off';
    const scope = form.querySelector('[name=in]');
    const box = document.createElement('div');
    box.className = 'complete';
    box.hidden = true;
    form.appendChild(box);
    let items = [];
    let index = -1;   // no row chosen at first: Enter sends what was typed
    let asked = 0;    // counts the lookups: an answer that is not the latest is dropped
    let timer = 0;

    const close = function () {
      box.hidden = true;
      items = [];
      index = -1;
    };
    const select = function (i) {
      index = i;
      Array.from(box.children).forEach(function (row, n) { row.classList.toggle('on', n === i); });
      if (box.children[i]) box.children[i].scrollIntoView({block: 'nearest'});
    };
    const pick = function (item) {
      if (item.url) { location.href = item.url; return; }
      input.value = item.text;
      close();
      form.submit();
    };
    const show = function (list) {
      items = list;
      box.replaceChildren();
      box.hidden = !list.length;
      index = -1;
      list.forEach(function (item, i) {
        const row = document.createElement('div');
        row.className = 'item';
        const text = document.createElement('b');
        text.textContent = item.text;
        row.appendChild(text);
        if (item.caption) {
          const where = document.createElement('span');
          where.textContent = item.caption;
          row.appendChild(where);
        }
        row.addEventListener('mousemove', function () { if (index !== i) select(i); });
        row.addEventListener('mousedown', function (e) { e.preventDefault(); pick(item); });
        box.appendChild(row);
      });
    };
    const ask = function () {
      const typed = input.value, turn = ++asked;
      clearTimeout(timer);
      if (typed.trim().length < 2) { close(); return; }
      timer = setTimeout(function () {
        fetch('/api/site-suggest?q=' + encodeURIComponent(typed) + '&in=' + encodeURIComponent(scope ? scope.value : ''))
          .then(function (answer) { return answer.ok ? answer.json() : {offers: []}; })
          .then(function (answer) { if (turn === asked && input.value === typed) show(answer.offers || []); })
          .catch(function () { });
      }, 150);
    };

    input.addEventListener('input', ask);
    if (scope) scope.addEventListener('change', ask);
    input.addEventListener('keydown', function (e) {
      if (box.hidden || !items.length) return;
      if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
        e.preventDefault();
        const step = e.key === 'ArrowDown' ? 1 : -1;
        select(index < 0 ? (step > 0 ? 0 : items.length - 1) : (index + step + items.length) % items.length);
      } else if (e.key === 'Enter' && index >= 0) {
        e.preventDefault();
        pick(items[index]);
      } else if (e.key === 'Escape') {
        asked++;
        close();
      }
    });
    input.addEventListener('blur', function () { setTimeout(close, 150); });
  });
})();
