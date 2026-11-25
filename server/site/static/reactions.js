// Shared reaction chips, names and emoji picker; each module supplies
// actions and data. Names appear on hover, keyboard focus or touch hold.
window.Reactions = (function () {
  'use strict';

  const el = Side.el;
  const REST = 350, HOLD = 500;

  // One box over the page at a time, the names behind a chip or the emoji
  // to pick from: {box, anchor, refocus}.
  let Open = null;

  function close(refocus) {
    if (!Open) return;
    Open.box.remove();
    if (refocus && Open.refocus) Open.anchor.focus({preventScroll: true});
    Open = null;
  }
  document.addEventListener('pointerdown', function (e) {
    if (Open && !Open.box.contains(e.target) && !Open.anchor.contains(e.target)) close();
  }, true);
  document.addEventListener('scroll', function (e) {
    if (Open && !Open.box.contains(e.target)) close(true);
  }, true);
  addEventListener('resize', function () { close(true); });
  // a chip drawn again leaves its names behind: they go as the pointer moves on
  document.addEventListener('pointermove', function () {
    if (Open && !Open.anchor.isConnected) close();
  });
  document.addEventListener('keydown', function (e) {
    if (!Open || e.key !== 'Escape') return;
    e.preventDefault();
    e.stopPropagation();
    close(true);
  }, true);

  // Puts a box (position: fixed) under the place r, over it where the
  // window ends below, and never outside the window.
  function under(box, r) {
    const high = box.offsetHeight;
    let top = r.bottom + 4;
    if (top + high > innerHeight - 8) top = r.top - 4 - high;
    box.style.top = Math.max(8, Math.min(top, innerHeight - high - 8)) + 'px';
    box.style.left = Math.max(8, Math.min(r.left, innerWidth - box.offsetWidth - 8)) + 'px';
  }

  function open(box, anchor, refocus) {
    close();
    document.body.appendChild(box);
    Open = {box: box, anchor: anchor, refocus: refocus};
    under(box, anchor.getBoundingClientRect());
  }

  // The names behind the chip b, asked for (ask) each time they are wanted.
  // Answers a function that says, once, whether the chip was just held: the
  // click that ends a hold is not a choice.
  function whoGave(b, ask) {
    let timer = 0, wanted = false, held = false;
    const show = async function () {
      wanted = true;
      let answer;
      try { answer = await ask(); } catch (err) { return; }
      if (!wanted || !b.isConnected || !answer.names.length) return;
      const box = el('div', 'reactwho');
      box.setAttribute('role', 'tooltip');
      for (const name of answer.names) box.appendChild(el('div', '', name));
      if (answer.more > 0) box.appendChild(el('div', 'more', tn(answer.more, 'and %d more', 'and %d more')));
      open(box, b, false);
    };
    const soon = function (ms, hold) {
      clearTimeout(timer);
      timer = setTimeout(function () { held = hold; show(); }, ms);
    };
    const drop = function () {
      clearTimeout(timer);
      wanted = false;
      if (Open && Open.anchor === b) close();
    };
    b.addEventListener('pointerenter', function (e) { if (e.pointerType === 'mouse') soon(REST, false); });
    b.addEventListener('pointerleave', function (e) { if (e.pointerType === 'mouse') drop(); });
    b.addEventListener('focus', function () { if (b.matches(':focus-visible')) soon(0, false); });
    b.addEventListener('blur', drop);
    b.addEventListener('pointerdown', function (e) {
      held = false;
      if (e.pointerType !== 'mouse') soon(HOLD, true);
    });
    for (const end of ['pointerup', 'pointercancel'])
      b.addEventListener(end, function (e) { if (e.pointerType !== 'mouse') clearTimeout(timer); });
    // a right click, and what some phones make of a hold
    b.addEventListener('contextmenu', function (e) {
      e.preventDefault();
      clearTimeout(timer);
      held = e.pointerType === 'touch';
      if (!Open || Open.anchor !== b) show();
    });
    return function () {
      const was = held;
      held = false;
      if (!was) drop();
      return was;
    };
  }

  // The chips for list, each of {r, n, mine}.  opts.toggle(r) puts the
  // reader's reaction on or takes it back; opts.who(r) asks who gave it and
  // resolves to {names, more}.
  function chips(list, opts) {
    const box = el('div', 'reacts');
    for (const r of list) {
      const b = el('button', 'react' + (r.mine ? ' mine' : ''));
      b.type = 'button';
      b.setAttribute('aria-pressed', String(!!r.mine));
      b.append(el('span', 'emoji', r.r), ' ' + r.n);
      const held = whoGave(b, function () { return opts.who(r); });
      b.addEventListener('click', function () { if (!held()) opts.toggle(r); });
      box.appendChild(b);
    }
    return box;
  }

  // The emoji to pick from, put into box: a row of those shown at once,
  // whose last button opens the rest under it.  lists is {shown, more};
  // pick(emoji) gets the one chosen, resized() hears that the rest opened
  // or closed.
  function offer(box, lists, pick, resized) {
    const row = function (cls, list) {
      const line = el('div', cls);
      for (const emoji of list) {
        const b = el('button', '', emoji);
        b.type = 'button';
        b.addEventListener('click', function () { pick(emoji); });
        line.appendChild(b);
      }
      return line;
    };
    const shown = row('emojis', lists.shown);
    box.appendChild(shown);
    if (!lists.more.length) return;
    const more = Side.iconButton('plus', t('More reactions'));
    more.setAttribute('aria-expanded', 'false');
    more.addEventListener('click', function () {
      const all = box.classList.toggle('all');
      more.replaceChildren(Side.icon(all ? 'up' : 'plus'));
      more.title = all ? t('Fewer reactions') : t('More reactions');
      more.setAttribute('aria-label', more.title);
      more.setAttribute('aria-expanded', String(all));
      resized();
    });
    shown.appendChild(more);
    box.appendChild(row('emojis rest', lists.more));
  }

  // The emoji in a box of their own under the button anchor, which opens
  // and closes it.
  function choose(anchor, lists, pick) {
    if (Open && Open.anchor === anchor) { close(true); return; }
    const box = el('div', 'msgmenu');
    box.setAttribute('role', 'group');
    box.setAttribute('aria-label', anchor.title);
    offer(box, lists, function (emoji) { close(true); pick(emoji); }, function () { under(box, anchor.getBoundingClientRect()); });
    box.addEventListener('focusout', function (e) {
      if (e.relatedTarget && !box.contains(e.relatedTarget)) close();
    });
    open(box, anchor, true);
    box.querySelector('button').focus({preventScroll: true});
  }

  return {chips: chips, offer: offer, choose: choose, under: under};
})();
