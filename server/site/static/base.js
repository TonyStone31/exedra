// A site under a path of its domain (https://example.com/community): the
// scripts go on writing addresses that start at /, and this puts the
// path, the base, before them where they leave the page: requests, links,
// pictures, forms and the address bar.  The page's first script.  With no
// base it only defines the three helpers, which then change nothing.
(function () {
  'use strict';
  var base = '';
  try {
    base = new URL(document.currentScript.src).pathname.replace(/\/static\/base\.js$/, '');
  } catch (e) { }
  // an address that starts at / with the base before it; anything else as it is
  function url(address) {
    return base && typeof address === 'string' && address.charAt(0) === '/' && address.charAt(1) !== '/' ? base + address : address;
  }
  // the other way: the base taken off an address read from the page or the bar
  function strip(address) {
    if (!base || typeof address !== 'string' || address.indexOf(base) !== 0) return address;
    var rest = address.slice(base.length);
    return rest === '' ? '/' : rest.charAt(0) === '/' || rest.charAt(0) === '?' || rest.charAt(0) === '#' ? (rest.charAt(0) === '/' ? rest : '/' + rest) : address;
  }
  window.SiteBase = {base: base, url: url, strip: strip, path: function () { return strip(location.pathname); }};
  if (!base) return;

  var fetchNow = window.fetch;
  window.fetch = function (input, init) { return fetchNow.call(this, url(input), init); };
  var openNow = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function () {
    arguments[1] = url(arguments[1]);
    return openNow.apply(this, arguments);
  };
  ['pushState', 'replaceState'].forEach(function (name) {
    var now = history[name];
    history[name] = function (state, title, address) {
      return address === undefined ? now.call(history, state, title) : now.call(history, state, title, url(address));
    };
  });
  // el.href = '/x', img.src = '/x', form.action = '/x'
  function prefix(proto, name) {
    var d = Object.getOwnPropertyDescriptor(proto, name);
    if (!d || !d.set) return;
    Object.defineProperty(proto, name, {configurable: true, enumerable: d.enumerable, get: d.get,
      set: function (value) { d.set.call(this, url(value)); }});
  }
  prefix(HTMLAnchorElement.prototype, 'href');
  prefix(HTMLLinkElement.prototype, 'href');
  prefix(HTMLImageElement.prototype, 'src');
  prefix(HTMLScriptElement.prototype, 'src');
  prefix(HTMLSourceElement.prototype, 'src');
  prefix(HTMLMediaElement.prototype, 'src');
  prefix(HTMLFormElement.prototype, 'action');
  var setNow = Element.prototype.setAttribute;
  Element.prototype.setAttribute = function (name, value) {
    if (name === 'href' || name === 'src' || name === 'action' || name === 'poster') value = url(value);
    return setNow.call(this, name, value);
  };
})();
