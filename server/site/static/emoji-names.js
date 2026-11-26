// Find emoji names as they are typed: :thu offers thumbsup, :tada: becomes
// 🎉. emoji-names.txt holds emoji and names under ## group headings, loaded
// on first use. The chat and editor display suggestions themselves.
window.EmojiNames = (function () {
  'use strict';
  const t = window.t || function (s) { return s; };

  // The list as the editor knows an emoji set: emoji, name, group, keywords.
  let asked = null;
  function list() {
    if (!asked) asked = fetch('/static/emoji-names.txt').then(function (r) { return r.ok ? r.text() : ''; }).then(function (text) {
      const found = [];
      let group = '';
      for (const line of text.split('\n')) {
        const parts = line.split(' ');
        if (line.startsWith('## ')) group = t(line.slice(3));
        else if (line && !line.startsWith('#')) found.push({emoji: parts[0], name: parts[1], group: group, keywords: parts.slice(1)});
      }
      return found;
    });
    return asked;
  }

  // Inside code a name is only words: a fence above, an indented line, or
  // an open ` on the line.
  function inCode(before) {
    let fence = false;
    for (const line of before.split('\n').slice(0, -1)) if (/^ {0,3}(`{3,}|~{3,})/.test(line)) fence = !fence;
    const line = before.slice(before.lastIndexOf('\n') + 1);
    return fence || /^( {4}|\t)/.test(line) || (line.split('`').length - 1) % 2 === 1;
  }

  // The name being typed where the caret is (at), or null: a colon where a
  // word starts, not in a time or an address, then two letters or more
  // (short: any, even none).  whole says its closing colon is there too.
  // from is where the colon is.
  function typed(text, at, short) {
    const m = /(^|[^A-Za-z0-9:/\\_]):([A-Za-z0-9+_-]{0,30})(:?)$/.exec(text.slice(Math.max(0, at - 34), at));
    if (!m || (m[3] ? !m[2] : m[2].length < (short ? 0 : 2)) || inCode(text.slice(0, at))) return null;
    return {word: m[2].toLowerCase(), from: at - m[2].length - m[3].length - 1, whole: !!m[3]};
  }

  // The emoji that fit a word, each with the keyword that fit (match): the
  // word itself first, then keywords that start with it, the shortest
  // first (heart before heart_eyes), then those and names that hold it.
  // No word yet: the set as it is.
  function matches(set, word) {
    if (!word) return set;
    const found = [];
    for (const e of set) {
      const starts = e.keywords.find(function (k) { return k.indexOf(word) === 0; });
      const holds = starts || e.keywords.find(function (k) { return k.indexOf(word) > 0; });
      if (holds) found.push(Object.assign({}, e, {match: holds, rank: holds === word ? 0 : starts ? 1 : 2}));
      else if (e.name.toLowerCase().indexOf(word) >= 0) found.push(Object.assign({}, e, {match: e.keywords[0] || '', rank: 2}));
    }
    return found.sort(function (x, y) { return x.rank - y.rank || (x.rank < 2 ? x.match.length - y.match.length : 0); });
  }

  // The emoji a whole :name: stands for.
  function named(set, word) {
    return set.find(function (e) { return e.keywords.indexOf(word) >= 0; });
  }

  // A part's own set with this list after it: an emoji of both keeps the
  // part's entry and gains the names nothing in the set answers to.
  function after(set) {
    const plain = function (s) { return s.replace(/️/g, ''); };
    return list().then(function (more) {
      const all = set.slice();
      for (const e of more) {
        const free = e.keywords.filter(function (k) { return !named(set, k); });
        const own = all.find(function (x) { return plain(x.emoji) === plain(e.emoji); });
        if (own) own.keywords = own.keywords.concat(free);
        else if (free.length) all.push(Object.assign({}, e, {keywords: free}));
      }
      return all;
    });
  }

  return {list: list, typed: typed, matches: matches, named: named, after: after};
})();
