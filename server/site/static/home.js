// The home page and the sign-in page: joining, a forgotten password, signing out, filtering a list.
(function () {
  // Back where the reader was before signing in, a page here only.
  // Browsers drop tabs and line breaks from an address, so '/<tab>/elsewhere'
  // would leave the site: control characters refuse it, and the address must
  // stay on this site once read as a URL.
  function returnAddress() {
    const back = new URLSearchParams(location.search).get('return') || '';
    if (back.charAt(0) !== '/' || /^.[\/\\]/.test(back) || /[\u0000-\u001f\u007f\\]/.test(back)) return '';
    let url;
    try { url = new URL(back, location.origin); } catch (e) { return ''; }
    if (url.origin !== location.origin || url.pathname.indexOf('/signin') === 0) return '';
    // the address as the site knows it; SiteBase.url puts the base back
    return url.pathname + url.search + url.hash;
  }

  // The sign-in buttons for GitHub and the rest take it along.
  if (returnAddress()) {
    document.querySelectorAll('a.sso[href^="' + SiteBase.url('/signin-with/') + '"]').forEach(function (a) {
      a.href = SiteBase.strip(a.getAttribute('href')).split('?')[0] + '?return=' + encodeURIComponent(returnAddress());
    });
  }

  Keys.bindJoinForms(function () {
    if (returnAddress()) { location.href = SiteBase.url(returnAddress()); return; }
    const chat = document.querySelector('.topbar nav a');
    location.href = chat ? chat.getAttribute('href') : SiteBase.url('/');
  });

  document.querySelectorAll('form.newpassword').forEach(function (form) {
    form.addEventListener('submit', async function (e) {
      e.preventDefault();
      try {
        await Keys.setNewPassword(form.dataset.token, form.dataset.name, form.elements.password.value);
        location.href = SiteBase.url('/');
      } catch (err) {
        alert(err.message);
      }
    });
  });

  // Forgot the password: a link by mail, to the address the account confirmed.
  // The box starts closed; how long it has been open goes along (-1: never
  // opened), so a machine that fills it the moment the page shows is told
  // the usual answer and nothing is mailed.  The hidden field likewise.
  document.querySelectorAll('form.forgot').forEach(function (form) {
    var box = form.closest('details'), opened = box && box.open ? Date.now() : 0;
    if (box) box.addEventListener('toggle', function () { if (box.open && !opened) opened = Date.now(); });
    form.addEventListener('submit', async function (e) {
      e.preventDefault();
      try {
        alert(await Keys.post('/api/forgot', {who: form.elements.who.value,
          website: form.elements.website ? form.elements.website.value : '',
          opened: opened ? Date.now() - opened : -1}));
      } catch (err) {
        alert(err.message);
      }
    });
  });

  document.querySelectorAll('.signout').forEach(function (a) {
    a.addEventListener('click', async function (e) {
      e.preventDefault();
      await Keys.signOut();
      location.reload();
    });
  });

  document.querySelectorAll('pre.copy').forEach(function (pre) {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = 'copybtn';
    b.textContent = t('Copy');
    b.addEventListener('click', function () {
      navigator.clipboard.writeText(pre.textContent).then(function () { b.textContent = t('Copied'); });
    });
    pre.before(b);
  });

  const find = document.getElementById('find');
  if (find) {
    find.addEventListener('input', function () {
      const words = this.value.toLowerCase().trim();
      document.querySelectorAll('[data-find]').forEach(function (a) {
        a.hidden = words !== '' && !a.dataset.find.includes(words);
      });
    });
  }
})();
