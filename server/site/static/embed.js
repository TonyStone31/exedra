// Embed the corner chat with <script src="https://your.site/embed.js"
// async></script>. data-page overrides the page address. Only that address
// is sent, without cookies; signing in and talking open the chat site in a
// new tab.
(function () {
  'use strict';
  const me = document.currentScript;
  if (!me || document.querySelector('[data-live-strip]')) return;
  // where the chat's site is, a path of its domain included (https://example.com/community)
  const base = me.src.replace(/\/embed\.js(\?.*)?$/, '');
  const page = me.getAttribute('data-page') || (location.origin + location.pathname);
  const css = document.createElement('link');
  css.rel = 'stylesheet';
  css.href = base + '/static/live-embed.css';
  document.head.appendChild(css);
  fetch(base + '/api/embed/page?url=' + encodeURIComponent(page), {credentials: 'omit', cache: 'no-store'})
    .then(function (r) { return r.ok ? r.json() : null; })
    .then(function (d) {
      if (!d) return;
      const spot = document.createElement('aside');
      spot.className = 'live-strip';
      spot.hidden = true;
      spot.setAttribute('data-live-strip', '');
      spot.setAttribute('data-live-base', base);
      spot.setAttribute('data-live-default', d.talk || '');
      if (d.room) spot.setAttribute('data-live-room', d.room);
      else {
        spot.setAttribute('data-live-page', 'site:' + page);
        spot.setAttribute('data-live-title', d.title || document.title);
        spot.setAttribute('data-live-can-bench', 'embed');
      }
      document.body.appendChild(spot);
      const s = document.createElement('script');
      // the corner chat as one plain script, so the page it sits on needs nothing else
      s.src = base + '/static/live-embed.js';
      document.body.appendChild(s);
    })
    .catch(function () { });
})();
