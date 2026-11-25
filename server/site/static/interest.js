// The Interesting button on catalog cards and entry pages: pressed without
// leaving the page, every button for the same entry following the answer.
// Without scripts the form posts and the entry page comes back.
(function () {
  'use strict';
  const t = window.t || function (s) { return s; };

  // the press answered: a small lift and a +1 that floats away
  function cheer(button) {
    if (window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    button.classList.remove('pop');
    void button.offsetWidth;
    button.classList.add('pop');
    const plus = document.createElement('span');
    plus.className = 'plus-one';
    plus.setAttribute('aria-hidden', 'true');
    plus.textContent = '+1';
    button.appendChild(plus);
    setTimeout(function () { plus.remove(); }, 900);
  }

  // Once a visit, someone not signed in hears what joining adds.
  function invite() {
    if (!document.body.classList.contains('guest')) return;
    try {
      if (sessionStorage.getItem('interest-invited')) return;
      sessionStorage.setItem('interest-invited', '1');
    } catch (e) { return; }
    const note = document.createElement('div');
    note.className = 'interest-invite';
    note.setAttribute('role', 'status');
    note.appendChild(document.createTextNode(t('Thanks! Members can also rate entries.') + ' '));
    const join = document.createElement('a');
    join.href = '/signin?return=' + encodeURIComponent(location.pathname + location.search);
    join.textContent = t('Join');
    note.appendChild(join);
    const close = document.createElement('button');
    close.type = 'button';
    close.textContent = '×';
    close.setAttribute('aria-label', t('Hide'));
    close.addEventListener('click', function () { note.remove(); });
    note.appendChild(close);
    document.body.appendChild(note);
    setTimeout(function () { note.classList.add('gone'); }, 9000);
    setTimeout(function () { note.remove(); }, 9600);
  }

  function show(entry, answer, pressed) {
    for (const form of document.querySelectorAll('.interest-form[data-entry="' + entry + '"]')) {
      const button = form.querySelector('.interest-button');
      if (answer.mine && form === pressed) cheer(button);
      button.classList.toggle('on', answer.mine);
      button.setAttribute('aria-pressed', answer.mine ? 'true' : 'false');
      button.title = answer.mine ? t('You find this interesting. Press again to take it back.') : t('Tell others this looks interesting');
      form.querySelector('.interest-count').textContent = String(answer.interest);
    }
  }

  document.addEventListener('submit', async function (event) {
    const form = event.target.closest && event.target.closest('.interest-form');
    if (!form) return;
    event.preventDefault();
    const button = form.querySelector('.interest-button');
    if (button.disabled) return;
    button.disabled = true;
    try {
      const answer = await fetch(form.action, {method: 'POST', credentials: 'same-origin', headers: {Accept: 'application/json'}});
      if (answer.ok) {
        const data = await answer.json();
        show(form.dataset.entry, data, form);
        if (data.mine) invite();
      }
      else button.title = (await answer.text()).slice(0, 200);
    } catch (e) {
      form.submit();
    } finally {
      button.disabled = false;
    }
  });

  // Discovering: the left arrow is Not for me, the right arrow Interesting,
  // both on to the next project; not while typing in a box.
  // Discovering: the page changes at once, so a tap would show nothing.
  // Interesting pops a +1 first; Not for me slides the project away; then
  // the next one comes.  Without scripts the form and the link work as is.
  const reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  // Back to a page the browser kept as it was left: shown again, ready again
  window.addEventListener('pageshow', function (event) {
    if (!event.persisted) return;
    leaving = false;
    document.body.classList.remove('leaving', 'leaving-yes', 'leaving-no');
    for (const burst of document.querySelectorAll('.star-burst')) burst.remove();
    const done = document.querySelector('.discover-yes.done');
    if (done) done.classList.remove('done');
  });
  // A person's click says so (hand=1) for the admin's numbers; a crawler
  // following the same link does not run this.
  function byHand(url) { return /[?&]hand=1/.test(url) ? url : url + (url.indexOf('?') >= 0 ? '&' : '?') + 'hand=1'; }
  function handField(form) {
    if (form.querySelector('input[name="hand"]')) return;
    const field = document.createElement('input');
    field.type = 'hidden'; field.name = 'hand'; field.value = '1';
    form.appendChild(field);
  }
  // every Random project link: the catalog's, the entry's, the guide's
  document.addEventListener('click', function (event) {
    const link = event.target.closest && event.target.closest('a[href^="/catalog-random"]');
    if (link) link.href = byHand(link.getAttribute('href'));
  }, true);
  let leaving = false;
  function leave(how, go) {
    if (leaving) return;
    leaving = true;
    if (reduce) { go(); return; }
    document.body.classList.add('leaving', 'leaving-' + how);
    if (how === 'yes') {
      // a star bursts from the button under the thumb, with sparks, and the
      // project shrinks into that spot as the star flies off the top
      const button = document.querySelector('.discover-yes');
      const at = button ? button.getBoundingClientRect() : {left: innerWidth / 2, top: innerHeight / 2, width: 0, height: 0};
      const x = at.left + at.width / 2, y = at.top + at.height / 2;
      const entry = document.querySelector('.catalog-entry');
      if (entry) {
        const box = entry.getBoundingClientRect();
        entry.style.transformOrigin = (x - box.left) + 'px ' + (y - box.top) + 'px';
      }
      const burst = document.createElement('div');
      burst.className = 'star-burst';
      burst.setAttribute('aria-hidden', 'true');
      burst.style.left = x + 'px';
      burst.style.top = y + 'px';
      const star = document.createElement('span');
      star.className = 'fly-star';
      // the button's own star, drawn the same everywhere
      const drawn = document.querySelector('.discover-yes .star-icon');
      if (drawn) star.appendChild(drawn.cloneNode(true)); else star.textContent = '\u2605';
      burst.appendChild(star);
      for (let i = 0; i < 7; i++) {
        const spark = document.createElement('i');
        spark.style.setProperty('--a', (i * 51 + 20) + 'deg');
        spark.style.setProperty('--d', (70 + (i % 3) * 30) + 'px');
        burst.appendChild(spark);
      }
      document.body.appendChild(burst);
      if (navigator.vibrate) { try { navigator.vibrate(18); } catch (e) { } }
    }
    // the arrival's animation, if still running, must not hold the page in place
    const entry = document.querySelector('.catalog-entry');
    if (entry) entry.classList.remove('arrive-yes', 'arrive-no');
    setTimeout(go, how === 'yes' ? 950 : 520);
  }
  document.addEventListener('submit', function (event) {
    const form = event.target.closest && event.target.closest('.discover-bar form');
    // only the Interesting form; the narrowing's form goes its own way
    if (!form || !form.querySelector('.discover-yes')) return;
    event.preventDefault();
    handField(form);
    const button = form.querySelector('.discover-yes');
    if (button) {
      button.classList.add('done');
      const count = document.querySelector('.catalog-entry .interest-count');
      if (count) count.textContent = String(Number(count.textContent || '0') + 1);
    }
    leave('yes', function () { form.submit(); });
  });
  document.addEventListener('click', function (event) {
    const link = event.target.closest && event.target.closest('.discover-bar .discover-no');
    if (!link || event.metaKey || event.ctrlKey || event.button !== 0) return;
    event.preventDefault();
    leave('no', function () { location.href = link.href; });
  });

  // the narrowing: a change fetches a project of that kind at once, and the
  // Go button is only for a page without scripts
  for (const form of document.querySelectorAll('.discover-choice')) {
    const go = form.querySelector('button');
    if (go) go.hidden = true;
    form.addEventListener('change', function () { handField(form); form.requestSubmit ? form.requestSubmit() : form.submit(); });
  }

  // Only while discovering (the random button's pages), and never from
  // inside the README, whose code and tables the arrows scroll.
  document.addEventListener('keydown', function (event) {
    if (event.altKey || event.ctrlKey || event.metaKey || event.shiftKey) return;
    if (new URLSearchParams(location.search).get('discover') !== '1') return;
    const target = event.target;
    if (target && (target.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(target.tagName))) return;
    if (target && target.closest && target.closest('.catalog-readme, pre, table')) return;
    const control = document.querySelector('.discover-bar [data-key="' + event.key + '"]');
    if (!control) return;
    event.preventDefault();
    // a click sends the button with its form everywhere, older Safari too
    control.click();
  });

  // A picture from another site that does not come, as a project's icon or in
  // its README, goes quietly rather than showing as broken.
  document.addEventListener('error', function (event) {
    const picture = event.target;
    if (picture && picture.tagName === 'IMG' && picture.closest('.catalog-icon, .catalog-thumb, .catalog-readme')) {
      const thumb = picture.closest('.catalog-thumb');
      (thumb || picture).remove();
    }
  }, true);
})();
