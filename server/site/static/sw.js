// The service worker: what lets the site be installed as an app, and shows
// notifications when no page of it is open.  A push carries nothing (see
// src/chat/chatpush.pas); this asks the site what is new and shows that.

// a site under a path of its domain: every address here starts with that path
const base = new URL(self.registration.scope).pathname.replace(/\/$/, '');
function siteUrl(address) { return address.charAt(0) === '/' ? base + address : address; }

self.addEventListener('install', function () { self.skipWaiting(); });
self.addEventListener('activate', function (e) { e.waitUntil(self.clients.claim()); });

// Pages come from the network as always; the handler is what browsers look
// for before they offer to install.
self.addEventListener('fetch', function () { });

async function showNew() {
  const open = await self.clients.matchAll({type: 'window', includeUncontrolled: true});
  if (open.some(function (c) { return c.visibilityState === 'visible'; })) return;
  let notes = [];
  try {
    const answer = await fetch(siteUrl('/api/notes'), {credentials: 'same-origin'});
    if (answer.ok) notes = await answer.json();
    // nobody is signed in on this device any more: it stops getting pushes
    else if (answer.status === 401) {
      const sub = await self.registration.pushManager.getSubscription();
      if (sub) await sub.unsubscribe();
    }
  } catch (e) { }
  if (!notes.length) notes = [{title: 'Something new', body: 'Open the chat to see it.', tag: 'new', url: '/'}];
  for (const n of notes)
    await self.registration.showNotification(n.title, {body: n.body, tag: n.tag, data: {url: n.url},
      icon: siteUrl('/icon-192.png')});
}

self.addEventListener('push', function (e) { e.waitUntil(showNew()); });

// A tap opens the conversation, in an open window when there is one.
self.addEventListener('notificationclick', function (e) {
  e.notification.close();
  const url = siteUrl((e.notification.data && e.notification.data.url) || '/');
  e.waitUntil(self.clients.matchAll({type: 'window', includeUncontrolled: true}).then(function (list) {
    // a window that will not go there (one this worker does not control)
    // must not leave the tap at whatever it was showing
    for (const c of list)
      if ('focus' in c) return c.navigate(url).then(function (w) { return (w || c).focus(); })
        .catch(function () { return self.clients.openWindow(url); });
    return self.clients.openWindow(url);
  }));
});
