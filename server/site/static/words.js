// The site's words in the reader's language.  window.WORDS comes from
// /words.js, which the page loads first; the English text is the key, so a
// word with no translation shows as English.  %s and %d fill in order;
// %1:s picks an argument by number, for languages that reorder a sentence.
(function () {
  const words = window.WORDS || {};
  window.t = function (english) {
    const args = Array.prototype.slice.call(arguments, 1);
    const text = Object.prototype.hasOwnProperty.call(words, english) && words[english] ? words[english] : english;
    let next = 0;
    return text.replace(/%(?:(\d+):)?[sd]/g, function (whole, number) {
      const at = number === undefined ? next++ : Number(number);
      return at < args.length ? String(args[at]) : whole;
    });
  };
  // A sentence about a number, with %d in both forms: tn(3, '%d reply', '%d replies').
  window.tn = function (n, one, many) {
    const args = Array.prototype.slice.call(arguments, 3);
    return window.t.apply(null, [n === 1 ? one : many, n].concat(args));
  };

  // Dates as the admin chose to show them (window.DATE_FORMAT from
  // /words.js, m-d-yyyy to begin with: 1-30-2020); "reader" gives the
  // reader's own language.  A date-only text (2020-01-30) is that day
  // wherever the reader is; a time is shown in the reader's time zone.
  function parts(value) {
    if (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value))
      return {y: +value.slice(0, 4), m: +value.slice(5, 7), d: +value.slice(8, 10), date: new Date(value + 'T00:00:00')};
    const date = value instanceof Date ? value : new Date(value);
    return isNaN(date) ? null : {y: date.getFullYear(), m: date.getMonth() + 1, d: date.getDate(), date: date};
  }
  const lang = function () { return document.documentElement.lang || undefined; };
  window.dateText = function (value) {
    const p = parts(value);
    if (!p) return String(value || '');
    const pattern = window.DATE_FORMAT || 'm-d-yyyy';
    if (pattern === 'reader') return p.date.toLocaleDateString(lang());
    const two = function (n) { return String(n).padStart(2, '0'); };
    return pattern.replace(/yyyy|mm|dd|m|d/g, function (k) {
      return k === 'yyyy' ? String(p.y) : k === 'mm' ? two(p.m) : k === 'dd' ? two(p.d) : k === 'm' ? String(p.m) : String(p.d);
    });
  };
  window.dateTimeText = function (value) {
    const p = parts(value);
    if (!p) return String(value || '');
    return window.dateText(value) + ' ' + p.date.toLocaleTimeString(lang(), {hour: 'numeric', minute: '2-digit'});
  };

  // The picker works without scripts by its button.  With them it goes on a
  // change, and comes back to wherever the chat has moved to since the page loaded.
  document.addEventListener('DOMContentLoaded', function () {
    // in the reader's own language: the dates the server left as yyyy-mm-dd
    if (window.DATE_FORMAT === 'reader') {
      document.querySelectorAll('time[data-show]').forEach(function (el) {
        const at = el.getAttribute('datetime');
        el.textContent = el.dataset.show === 'datetime' ? window.dateTimeText(at) : window.dateText(at.slice(0, 10));
      });
    }
    // Sign in and Join bring the reader back to this page afterwards.
    if (SiteBase.path() !== '/signin') {
      document.querySelectorAll('a[href="' + SiteBase.url('/signin') + '"]').forEach(function (a) {
        a.href = '/signin?return=' + encodeURIComponent(SiteBase.path() + location.search);
      });
    }
    document.querySelectorAll('.site-language').forEach(function (form) {
      const button = form.querySelector('button');
      if (button) button.hidden = true;
      form.querySelector('select').addEventListener('change', function () {
        form.querySelector('[name=return]').value = SiteBase.path() + location.search;
        form.submit();
      });
    });
  });
})();
