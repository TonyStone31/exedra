// Account keys, encrypted messages and peer-to-peer files. The password
// stays here: one derived key signs in, another wraps the private key. ECDH
// gives two members their message key; the server stores sealed text and
// files. Beam sends files over WebRTC; the server relays connection offers
// only.
window.Keys = (function () {
  const enc = new TextEncoder();
  const dec = new TextDecoder();
  const b64 = function (b) {
    const bytes = new Uint8Array(b);
    let s = '';
    for (let i = 0; i < bytes.length; i += 32768) s += String.fromCharCode.apply(null, bytes.subarray(i, i + 32768));
    return btoa(s);
  };
  const unb64 = function (s) { return Uint8Array.from(atob(s), function (c) { return c.charCodeAt(0); }); };
  const hex = function (b) {
    return Array.from(new Uint8Array(b), function (x) { return x.toString(16).padStart(2, '0'); }).join('');
  };
  const ready = function () { return !!(window.crypto && crypto.subtle); };

  async function post(url, fields) {
    const answer = await fetch(url, {method: 'POST', body: fields instanceof FormData ? fields : new URLSearchParams(fields)});
    const text = await answer.text();
    if (!answer.ok) {
      const e = new Error(text);
      e.status = answer.status;
      throw e;
    }
    return text;
  }

  async function keysFrom(name, password) {
    const base = await crypto.subtle.importKey('raw', enc.encode(password), 'PBKDF2', false, ['deriveBits']);
    const master = await crypto.subtle.deriveBits({name: 'PBKDF2', hash: 'SHA-256',
      // Keep this salt: changing it breaks every password.
      salt: enc.encode('beginend:' + name.toLowerCase()), iterations: 600000}, base, 256);
    const hk = await crypto.subtle.importKey('raw', master, 'HKDF', false, ['deriveBits', 'deriveKey']);
    const info = function (s) { return {name: 'HKDF', hash: 'SHA-256', salt: new Uint8Array(32), info: enc.encode(s)}; };
    return {
      auth: hex(await crypto.subtle.deriveBits(info('sign in'), hk, 256)),
      wrap: await crypto.subtle.deriveKey(info('wrap'), hk, {name: 'AES-GCM', length: 256}, false,
        ['encrypt', 'decrypt'])
    };
  }

  async function passwordName(name) {
    const answer = await fetch('/api/auth-name?name=' + encodeURIComponent(name), {cache: 'no-store'});
    if (!answer.ok) throw new Error(await answer.text());
    return (await answer.json()).name;
  }

  // The private key stays in this browser, and cannot be read back out.
  function keyStore(mode, work) {
    return new Promise(function (done, fail) {
      const open = indexedDB.open('beginend', 1);  // the first name again: members' keys are in there
      open.onupgradeneeded = function () { open.result.createObjectStore('keys'); };
      open.onerror = function () { fail(open.error); };
      open.onsuccess = function () {
        const request = work(open.result.transaction('keys', mode).objectStore('keys'));
        request.onsuccess = function () { done(request.result); };
        request.onerror = function () { fail(request.error); };
      };
    });
  }

  async function keepPrivateKey(pkcs8, name) {
    const key = await crypto.subtle.importKey('pkcs8', pkcs8, {name: 'ECDH', namedCurve: 'P-256'},
      false, ['deriveBits']);
    await keyStore('readwrite', function (s) { return s.put({name: name, key: key}, 'me'); });
  }

  async function myKey() {
    try { return await keyStore('readonly', function (s) { return s.get('me'); }); } catch (e) { return null; }
  }

  // The private key as the server keeps it: encrypted with the password's key.
  async function wrapKey(keys, pkcs8) {
    const iv = crypto.getRandomValues(new Uint8Array(12));
    return b64(iv) + '.' + b64(await crypto.subtle.encrypt({name: 'AES-GCM', iv: iv}, keys.wrap, pkcs8));
  }

  async function unwrapKey(keys, wrapped) {
    const parts = wrapped.split('.');
    return crypto.subtle.decrypt({name: 'AES-GCM', iv: unb64(parts[0])}, keys.wrap, unb64(parts[1]));
  }

  // A new key pair, its private half wrapped with the password's key.
  async function newAccountKeys(name, password, saltName) {
    const keys = await keysFrom(saltName || name, password);
    const pair = await crypto.subtle.generateKey({name: 'ECDH', namedCurve: 'P-256'}, true, ['deriveBits']);
    const pkcs8 = await crypto.subtle.exportKey('pkcs8', pair.privateKey);
    return {
      pkcs8: pkcs8,
      fields: {
        name: name, auth: keys.auth,
        pub: b64(await crypto.subtle.exportKey('spki', pair.publicKey)),
        wrapped: await wrapKey(keys, pkcs8)
      }
    };
  }

  async function signUp(name, password, email) {
    const made = await newAccountKeys(name, password);
    made.fields.email = email || '';
    await post('/api/signup', made.fields);
    await keepPrivateKey(made.pkcs8, name);
  }

  // An account made on IRC or by signing in with GitHub, GitLab or Google
  // has no keys yet: they are made here from its password (its first one,
  // when it has none).
  async function setupKeys(name, password) {
    if (password.length < 8) throw new Error(t('A password needs 8 characters or more.'));
    const made = await newAccountKeys(name, password, await passwordName(name));
    await post('/api/keys', made.fields);
    await keepPrivateKey(made.pkcs8, name);
  }

  // A new password from a one-time link an admin made.
  async function setNewPassword(token, name, password) {
    if (password.length < 8) throw new Error(t('A password needs 8 characters or more.'));
    const made = await newAccountKeys(name, password);
    made.fields.token = token;
    await post('/api/newpassword', made.fields);
    await keepPrivateKey(made.pkcs8, name);
  }

  async function openWrapped(keys, name, wrapped) {
    await keepPrivateKey(await unwrapKey(keys, wrapped), name);
  }

  // The sign-in key of the account's password, which the server asks for
  // again before a change only the account's owner should make.
  async function passwordProof(name, password) {
    return (await keysFrom(await passwordName(name), password)).auth;
  }

  // A new password from the member who knows the old one.  The private key
  // stays the same, wrapped again, so locked conversations stay readable;
  // an account that had no keys (wrapped is empty) gets them here.
  async function changePassword(name, current, password, wrapped) {
    if (password.length < 8) throw new Error(t('A password needs 8 characters or more.'));
    const salt = await passwordName(name);
    const old = await keysFrom(salt, current);
    let fields, pkcs8;
    if (wrapped) {
      try { pkcs8 = await unwrapKey(old, wrapped); } catch (err) { throw new Error(t('That is not the password of this account.')); }
      const keys = await keysFrom(salt, password);
      fields = {auth: keys.auth, wrapped: await wrapKey(keys, pkcs8)};
    } else {
      const made = await newAccountKeys(name, password, salt);
      fields = made.fields;
      pkcs8 = made.pkcs8;
    }
    fields.current = old.auth;
    await post('/api/password', fields);
    await keepPrivateKey(pkcs8, name);
  }

  // Signed in some other way: the password still opens the private key.
  async function unlock(name, password, wrapped) {
    try {
      await openWrapped(await keysFrom(await passwordName(name), password), name, wrapped);
    } catch (err) {
      throw new Error(t('That is not the password of this account.'));
    }
  }

  async function signIn(name, password) {
    const keys = await keysFrom(await passwordName(name), password);
    const answer = JSON.parse(await post('/api/signin', {name: name, auth: keys.auth}));
    if (answer.wrapped) await openWrapped(keys, answer.name, answer.wrapped);
    else await setupKeys(answer.name, password);
  }

  async function signOut() {
    // This browser stops getting pushes for the account it leaves.
    try {
      // not .ready: it waits for ever where the chat never registered its worker
      const reg = 'serviceWorker' in navigator ? await navigator.serviceWorker.getRegistration('/') : null;
      const sub = reg && reg.pushManager ? await reg.pushManager.getSubscription() : null;
      if (sub) {
        await post('/api/push', {endpoint: sub.endpoint, off: '1'});
        await sub.unsubscribe();
      }
    } catch (err) { }
    await post('/api/signout', {});
    try { await keyStore('readwrite', function (s) { return s.delete('me'); }); } catch (e) { }
  }

  // One form for both: a known name signs in, a new name joins.
  async function join(name, password, email) {
    if (!ready()) throw new Error(t('This page has to be opened over https for accounts to work.'));
    try {
      await signIn(name, password);
    } catch (err) {
      if (err.status !== 403) throw err;
      if (password.length < 8) throw new Error(t('A new password needs 8 characters or more.'));
      try {
        await signUp(name, password, email);
      } catch (err2) {
        if (err2.message === 'That name is taken.') throw new Error(t('That name is taken, or the password is wrong.'));
        if (err2.status === 422) err2.needEmail = true;
        throw err2;
      }
    }
  }

  // A new name needs an address: the box for it appears in the form when
  // the server asks for one.
  function emailBox(form) {
    let box = form.querySelector('input[name=email]');
    if (!box) {
      box = document.createElement('input');
      box.name = 'email';
      box.type = 'email';
      box.autocomplete = 'email';
      box.required = true;
      box.placeholder = t('Email, to confirm the new account');
      form.querySelector('button').before(box);
    }
    return box;
  }

  // Joins from a form with name and password, asking for the email when
  // the name is new; true when it worked.
  async function joinFrom(form, failed) {
    const box = form.querySelector('input[name=email]');
    try {
      await join(form.elements.name.value.trim(), form.elements.password.value, box ? box.value.trim() : '');
      return true;
    } catch (err) {
      if (err.needEmail && !box) emailBox(form).focus();
      failed(err.needEmail && !box ? new Error(t('New here? Add your email; a link to confirm it is sent there.')) : err);
      return false;
    }
  }

  function bindJoinForms(after) {
    document.querySelectorAll('.quickjoin:not(.newpassword):not(.forgot)').forEach(function (form) {
      form.addEventListener('submit', async function (e) {
        e.preventDefault();
        const button = form.querySelector('button');
        const label = button.textContent;
        button.disabled = true;
        button.textContent = t('One moment');
        if (await joinFrom(form, function (err) { alert(err.message); })) after();
        button.disabled = false;
        button.textContent = label;
      });
    });
  }

  // Private conversations

  const pairKeys = {};
  // The key two members share, derived from my private key and their public one.
  async function pairKey(other) {
    if (pairKeys[other]) return pairKeys[other];
    const me = await myKey();
    if (!me) throw new Error(t('locked'));
    const theirs = JSON.parse(await (await fetch('/api/key?name=' + encodeURIComponent(other))).text());
    const mine = await (await fetch('/api/me')).json();
    const pub = await crypto.subtle.importKey('spki', unb64(theirs.pub), {name: 'ECDH', namedCurve: 'P-256'}, false, []);
    const shared = await crypto.subtle.deriveBits({name: 'ECDH', public: pub}, me.key, 256);
    const hk = await crypto.subtle.importKey('raw', shared, 'HKDF', false, ['deriveKey']);
    // The label keeps the first name too, or locked conversations would not open.
    pairKeys[other] = {pub: theirs.pub, me: mine.key_name || me.name, other: theirs.key_name || other, key: await crypto.subtle.deriveKey({name: 'HKDF', hash: 'SHA-256',
      salt: new Uint8Array(32), info: enc.encode('beginend private message')}, hk,
      {name: 'AES-GCM', length: 256}, false, ['encrypt', 'decrypt'])};
    return pairKeys[other];
  }

  // The server hands out public keys, so it could hand out its own. This
  // browser remembers the key it saw for each member and says when another
  // one comes, and both sides can compare a code made from the two keys.
  async function partner(other) {
    const pair = await pairKey(other);
    const spot = 'seen:' + pair.other.toLowerCase();
    const seen = await keyStore('readonly', function (s) { return s.get(spot); });
    if (!seen) await keyStore('readwrite', function (s) { return s.put(pair.pub, spot); });
    const me = await (await fetch('/api/me')).json();
    const mine = JSON.parse(await (await fetch('/api/key?name=' + encodeURIComponent(me.name))).text());
    const both = [pair.pub, mine.pub].sort().join('|');
    const hash = new Uint8Array(await crypto.subtle.digest('SHA-256', enc.encode(both)));
    let code = '';
    for (let i = 0; i < 10; i++) code += (i && i % 2 === 0 ? ' ' : '') + hash[i].toString(16).padStart(2, '0');
    return {code: code, changed: !!seen && seen !== pair.pub};
  }

  // The member looked at the code: the key seen now is the one to expect.
  async function trust(other) {
    const pair = await pairKey(other);
    await keyStore('readwrite', function (s) { return s.put(pair.pub, 'seen:' + pair.other.toLowerCase()); });
  }

  // Who sent it to whom is sealed in with it, so the server cannot turn a
  // message around.
  const between = function (from, to) { return enc.encode(from.toLowerCase() + '>' + to.toLowerCase()); };

  async function seal(other, payload) {
    // before writing, their key as it is now: after a password reset they
    // have a new one, and a page left open would go on writing to the old
    // key, which nobody can open any more
    if (pairKeys[other]) {
      try {
        const now = JSON.parse(await (await fetch('/api/key?name=' + encodeURIComponent(other))).text());
        if (now.pub && now.pub !== pairKeys[other].pub) delete pairKeys[other];
      } catch (e) { }
    }
    const pair = await pairKey(other);
    const iv = crypto.getRandomValues(new Uint8Array(12));
    const data = await crypto.subtle.encrypt({name: 'AES-GCM', iv: iv, additionalData: between(pair.me, pair.other)},
      pair.key, enc.encode(JSON.stringify(payload)));
    return {iv: b64(iv), data: b64(data)};
  }

  async function open(other, message) {
    const pair = await pairKey(other);
    const from = message.from_key_name || message.from;
    const to = from.toLowerCase() === pair.me.toLowerCase() ? pair.other : pair.me;
    const plain = dec.decode(await crypto.subtle.decrypt({name: 'AES-GCM', iv: unb64(message.iv),
      additionalData: between(from, to)}, pair.key, unb64(message.data)));
    try {
      const payload = JSON.parse(plain);
      if (payload && payload.t) return payload;
    } catch (e) { }
    return {t: 'text', text: plain};
  }

  // A file for a private conversation: encrypted here, then uploaded.
  async function sealFile(other, file, expire) {
    const pair = await pairKey(other);
    const iv = crypto.getRandomValues(new Uint8Array(12));
    const data = await crypto.subtle.encrypt({name: 'AES-GCM', iv: iv}, pair.key, await file.arrayBuffer());
    const form = new FormData();
    form.append('sealed', '1');
    form.append('expire', expire || '');
    form.append('file', new Blob([data]), 'sealed');
    const answer = JSON.parse(await post('/api/upload', form));
    return {token: answer.token, name: file.name, type: file.type, size: file.size, iv: b64(iv)};
  }

  async function openFile(other, meta) {
    const pair = await pairKey(other);
    const answer = await fetch('/f/' + meta.token + '/sealed');
    if (!answer.ok) throw new Error(await answer.text());
    const plain = await crypto.subtle.decrypt({name: 'AES-GCM', iv: unb64(meta.iv)}, pair.key, await answer.arrayBuffer());
    return new Blob([plain], {type: meta.type || 'application/octet-stream'});
  }

  // Beam

  async function iceServers() {
    const answer = await (await fetch('/api/ice')).json();
    const urls = (answer.ice || '').split(/\s+/).filter(Boolean);
    return urls.length ? [{urls: urls}] : [];
  }

  // Waits until the browser has found every way it can be reached, so one
  // offer and one answer are all the server has to pass on.
  function gathered(peer) {
    return new Promise(function (done) {
      if (peer.iceGatheringState === 'complete') return done();
      const timer = setTimeout(done, 4000);
      peer.addEventListener('icegatheringstatechange', function () {
        if (peer.iceGatheringState === 'complete') { clearTimeout(timer); done(); }
      });
    });
  }

  const Chunk = 64 * 1024;

  // Offers a file and returns the beam's token at once, so the offer can be
  // announced; the file goes once the other side takes it.
  // progress(sent, total, state) reports how it goes.
  async function beamSend(other, file, progress) {
    const peer = new RTCPeerConnection({iceServers: await iceServers()});
    const channel = peer.createDataChannel('beam', {ordered: true});
    channel.binaryType = 'arraybuffer';
    await peer.setLocalDescription(await peer.createOffer());
    await gathered(peer);
    const token = JSON.parse(await post('/api/beam', {to: other, offer: JSON.stringify(peer.localDescription)})).token;
    progress(0, file.size, 'waiting');
    const answered = new Promise(function (done, fail) {
      let tries = 0;
      const look = async function () {
        try {
          const beam = await (await fetch('/api/beam?token=' + token)).json();
          if (beam.answer) return done(JSON.parse(beam.answer));
        } catch (e) { }
        if (++tries > 600) return fail(new Error(t('Nobody took the beam.')));
        setTimeout(look, 1500);
      };
      look();
    });
    channel.onopen = async function () {
      progress(0, file.size, 'sending');
      channel.send(JSON.stringify({name: file.name, size: file.size, type: file.type}));
      channel.bufferedAmountLowThreshold = 1024 * 1024;
      let sent = 0;
      while (sent < file.size) {
        if (channel.bufferedAmount > 4 * 1024 * 1024)
          await new Promise(function (done) { channel.onbufferedamountlow = done; });
        const piece = await file.slice(sent, sent + Chunk).arrayBuffer();
        channel.send(piece);
        sent += piece.byteLength;
        progress(sent, file.size, 'sending');
      }
    };
    channel.onmessage = function (e) {
      if (e.data === 'got it') {
        progress(file.size, file.size, 'done');
        setTimeout(function () { peer.close(); }, 1000);
      }
    };
    answered.then(function (answer) { return peer.setRemoteDescription(answer); })
      .catch(function (err) { progress(0, file.size, err.message); });
    return token;
  }

  // Takes a beam; resolves with the file once it has all arrived.
  async function beamReceive(token, progress) {
    const beam = await (await fetch('/api/beam?token=' + token)).json();
    if (!beam.offer) throw new Error(t('That beam is over.'));
    const peer = new RTCPeerConnection({iceServers: await iceServers()});
    const received = new Promise(function (done, fail) {
      peer.ondatachannel = function (e) {
        const channel = e.channel;
        channel.binaryType = 'arraybuffer';
        let head = null;
        const parts = [];
        let got = 0;
        channel.onmessage = function (m) {
          if (!head) {
            head = JSON.parse(m.data);
            progress(0, head.size, 'receiving');
            return;
          }
          parts.push(m.data);
          got += m.data.byteLength;
          progress(got, head.size, 'receiving');
          if (got >= head.size) {
            channel.send('got it');
            done(new File(parts, head.name, {type: head.type || 'application/octet-stream'}));
          }
        };
        channel.onclose = function () { if (!head || got < head.size) fail(new Error(t('The beam was cut off.'))); };
      };
    });
    await peer.setRemoteDescription(JSON.parse(beam.offer));
    await peer.setLocalDescription(await peer.createAnswer());
    await gathered(peer);
    await post('/api/beam/answer', {token: token, answer: JSON.stringify(peer.localDescription)});
    progress(0, 0, 'connecting');
    return received;
  }

  return {
    ready: ready, post: post, join: join, joinFrom: joinFrom, signOut: signOut, bindJoinForms: bindJoinForms, myKey: myKey,
    setupKeys: setupKeys, unlock: unlock, setNewPassword: setNewPassword, changePassword: changePassword,
    passwordProof: passwordProof,
    seal: seal, open: open, sealFile: sealFile, openFile: openFile, partner: partner, trust: trust,
    beamSend: beamSend, beamReceive: beamReceive
  };
})();
