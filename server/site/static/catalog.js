// The catalog list follows its filters as they change, and stars go in without
// leaving the page.  With no scripts the form and the star buttons post as usual.
(function () {
  'use strict';

  // The filters as an address: empty ones left out, and a search only once it
  // has two characters.
  function address(form) {
    const query = new URLSearchParams();
    for (const [name, value] of new FormData(form).entries()) {
      const text = String(value).trim();
      if (text === '' || (name === 'q' && text.length < 2)) continue;
      query.set(name, text);
    }
    const tail = query.toString();
    return form.getAttribute('action') + (tail ? '?' + tail : '');
  }

  window.CatalogFilters = {address: address};

  const form = document.querySelector('.catalog-form');
  const status = document.querySelector('.catalog-updating');
  let running = null;
  let waiting = 0;

  async function refresh() {
    const url = address(form);
    if (running) running.abort();
    const mine = new AbortController();
    running = mine;
    if (status) status.textContent = status.dataset.busy || '';
    try {
      const answer = await fetch(url, {signal: mine.signal, credentials: 'same-origin'});
      const text = await answer.text();
      if (mine !== running) return;
      if (!answer.ok) {
        if (status) status.textContent = text.slice(0, 200);
        return;
      }
      const page = new DOMParser().parseFromString(text, 'text/html');
      for (const part of ['.catalog-types', '.catalog-cards', '.findpages']) {
        const fresh = page.querySelector(part);
        const old = document.querySelector(part);
        if (fresh && old) old.replaceWith(fresh);
      }
      history.replaceState(null, '', url);
      if (status) status.textContent = '';
    } catch (e) {
      if (e && e.name === 'AbortError') return;
      location.assign(url);
    }
  }

  if (form) {
    const go = form.querySelector('.catalog-go');
    if (go) go.hidden = true;
    form.addEventListener('change', function (event) {
      if (event.target.matches('select')) refresh();
    });
    form.addEventListener('input', function (event) {
      if (!event.target.matches('input[name=q]')) return;
      const text = event.target.value.trim();
      clearTimeout(waiting);
      if (text.length === 1) return;
      waiting = setTimeout(refresh, 300);
    });
    form.addEventListener('submit', function (event) {
      event.preventDefault();
      clearTimeout(waiting);
      refresh();
    });
  }

  // All, Components, Applications: the same list, without leaving the page.
  document.addEventListener('click', function (event) {
    const link = event.target.closest && event.target.closest('.catalog-types a');
    if (!link || !form) return;
    event.preventDefault();
    const field = form.querySelector('[name=type]');
    if (field) field.value = link.dataset.type || '';
    refresh();
  });

  // Stars: every form for the entry and its summary follow the answer.
  function show(entry, answer) {
    for (const stars of document.querySelectorAll('.rate-form[data-entry="' + entry + '"]')) {
      for (const button of stars.querySelectorAll('.rate-star')) {
        const value = Number(button.value);
        button.classList.toggle('on', value <= answer.mine);
        button.textContent = value <= answer.mine ? '★' : '☆';
        button.setAttribute('aria-pressed', value === answer.mine ? 'true' : 'false');
      }
      const clear = stars.querySelector('.rate-clear');
      if (clear) clear.hidden = answer.mine === 0;
    }
    for (const line of document.querySelectorAll('[data-rating-summary="' + entry + '"]')) {
      line.textContent = answer.summary || line.dataset.none || '';
    }
  }

  document.addEventListener('submit', async function (event) {
    const stars = event.target.closest && event.target.closest('.rate-form');
    if (!stars || !event.submitter) return;
    event.preventDefault();
    const body = new URLSearchParams({stars: event.submitter.value});
    try {
      const answer = await fetch(stars.action, {method: 'POST', body: body, credentials: 'same-origin', headers: {Accept: 'application/json'}});
      if (!answer.ok) {
        if (status) status.textContent = (await answer.text()).slice(0, 200);
        return;
      }
      show(stars.dataset.entry, await answer.json());
    } catch (e) {
      // submit() alone leaves out the button pressed, and so the stars
      const kept = document.createElement('input');
      kept.type = 'hidden';
      kept.name = 'stars';
      kept.value = event.submitter.value;
      stars.appendChild(kept);
      stars.submit();
    }
  });
})();
