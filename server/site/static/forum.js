// Forms on the server-rendered forum pages.
(function () {
  'use strict';

  async function post(path, fields) {
    const response = await fetch(path, {method: 'POST', body: fields, credentials: 'same-origin'});
    if (!response.ok) throw new Error(await response.text() || t('Could not save the forum.'));
    return response.json();
  }

  function topicAddress(id, page, postId) {
    const path = '/forum/t/' + Number(id);
    return path + (page > 1 ? '?page=' + Number(page) : '') + (postId ? '#post-' + Number(postId) : '');
  }

  function codeButtons(box) {
    box.querySelectorAll('.code').forEach(function (block) {
      const copy = block.querySelector('.copy');
      if (copy) {
        copy.dataset.forumCode = '1';
        copy.textContent = t('Copy');
        copy.addEventListener('click', async function () {
          try {
            await navigator.clipboard.writeText(block.querySelector('pre code').textContent);
            copy.textContent = t('Copied');
          } catch (err) { alert(t('Could not copy the code.')); }
        });
      }
      const flip = block.querySelector('.flip');
      if (flip) {
        flip.dataset.forumCode = '1';
        flip.textContent = t('Source');
        flip.addEventListener('click', function () {
          flip.textContent = block.classList.toggle('source') ? t('Document') : t('Source');
        });
      }
    });
  }

  // The post box gets the shared editor (editor.js): its toolbar, and the
  // post as it will look from the forum's own renderer.
  function editor(textarea) {
    if (!window.Editor) return;
    const form = textarea.closest('form');
    const files = fileRules(textarea);
    window.Editor.attach(textarea, {
      compact: true,
      mode: 'write',
      storeKey: 'forum-edit-mode',
      viewClass: 'forum-body body',
      emptyWords: t('The post shows here as you write.'),
      preview: async function (text, signal) {
        const fields = new URLSearchParams(new FormData(form));
        fields.set('body', text);
        const response = await fetch('/api/forum/preview', {method: 'POST', body: fields, credentials: 'same-origin', signal: signal});
        if (!response.ok) throw new Error(await response.text());
        return (await response.json()).html;
      },
      afterPreview: codeButtons,
      // emoji by name, as in the chat: :thu offers 👍
      emoji: function () { return EmojiNames.list(); },
      // the button that sends the form and its error stay in view full screen too
      sendRow: [form.querySelector(':scope > button'), form.querySelector(':scope > .forum-error')],
      hint: files ? t('Markdown. Drag, paste or') : undefined,
      linkTools: files ? function (editor) {
        editor.tool(t('Add a file'), '', editor.svg('<path d="M20 11.5l-8.2 8.2a5 5 0 0 1-7-7l8.5-8.6a3.4 3.4 0 0 1 4.8 4.8l-8.4 8.5a1.7 1.7 0 0 1-2.4-2.4l7.7-7.8"/>'), editor.choose);
      } : undefined,
      pictures: files
    });
  }

  // Files in a post: the page says the largest size and the kinds the
  // admin accepts; the forum keeps the file and the post names it.
  function fileRules(textarea) {
    const kinds = (textarea.dataset.uploadTypes || '').split(' ').filter(Boolean);
    const most = Number(textarea.dataset.uploadMb || 0);
    if (!kinds.length || !most) return null;
    return {
      accept: kinds.map(function (k) { return '.' + k; }).join(','),
      gallery: 'image/*' + (kinds.some(function (k) { return /^(mp4|webm|mov|m4v)$/.test(k); }) ? ',video/*' : ''),
      label: t('add files'),
      refuses: function (file) {
        const kind = (/\.([A-Za-z0-9]+)$/.exec(file.name || '') || ['', ''])[1].toLowerCase();
        // a pasted screenshot has no name of its own; it is a picture
        if (!kind && /^image\/(png|jpeg|gif|webp)$/.test(file.type)) return '';
        if (kinds.indexOf(kind) < 0) return t('%s is not a kind of file accepted here.', file.name || '');
        if (file.size > most * 1024 * 1024) return t('%s is too big: files can be %d MB at most here.', file.name || '', most);
        return '';
      },
      send: async function (file, name) {
        const body = new FormData();
        body.append('file', file, name);
        const response = await fetch('/api/forum/upload', {method: 'POST', body: body, credentials: 'same-origin'});
        if (!response.ok) throw new Error((await response.text()).trim().slice(0, 200) || t('The file could not be uploaded.'));
        const answer = await response.json();
        const words = answer.name.replace(/[\[\]]/g, '');
        // a blank or a parenthesis in the name would end the link early
        const address = answer.url.replace(/ /g, '%20').replace(/\(/g, '%28').replace(/\)/g, '%29');
        return {put: (answer.image ? '!' : '') + '[' + words + '](' + address + ')', words: t('%s is uploaded.', answer.name)};
      }
    };
  }

  document.querySelectorAll('form[data-forum-form]').forEach(function (form) {
    form.addEventListener('submit', async function (event) {
      event.preventDefault();
      if (form.dataset.busy) return;
      const path = SiteBase.strip(form.getAttribute('action'));
      if (form.dataset.confirm && !confirm(form.dataset.confirm)) return;
      const fields = new URLSearchParams(new FormData(form));
      const error = form.querySelector('.forum-error');
      const buttons = form.querySelectorAll('button');
      error.textContent = '';
      form.dataset.busy = '1';
      buttons.forEach(function (button) { button.disabled = true; });
      try {
        const data = await post(path, fields);
        if (data.topic_id) {
          const to = SiteBase.url(topicAddress(data.topic_id, data.page || 1, data.post_id));
          // the same page with another anchor is only a jump: read it again for the new post
          const same = to.split('#')[0] === location.pathname + location.search;
          location.assign(to);
          if (same) location.reload();
        }
        else if (data.topic_deleted) location.assign(SiteBase.url('/forum'));
        else if (data.reported) {
          // the page stays as it is; the form gives way to a word of thanks
          const thanks = document.createElement('p');
          thanks.textContent = t('Reported. The moderators will take a look.');
          form.replaceWith(thanks);
        }
        else location.reload();
      } catch (err) {
        error.textContent = err.message;
        // the text is still unsaved: the editor goes on warning before the page is left
        form.querySelectorAll('textarea').forEach(function (box) { if (box.editor && box.editor.notSaved) box.editor.notSaved(); });
      }
      finally {
        delete form.dataset.busy;
        buttons.forEach(function (button) { button.disabled = false; });
      }
    });
  });
  function quoteMarkdown(author, topic, postId, body) {
    // Names are literal Markdown, including brackets and formatting characters.
    const name = author.replace(/([\\`*_[\]<>])/g, '\\$1');
    return '> **' + name + '** ' + t('wrote') + ' ([' + t('post') + '](/forum/t/' + Number(topic) + '?post=' + Number(postId) + '#post-' + Number(postId) + ')):\n' +
      body.replace(/\r\n?/g, '\n').split('\n').map(function (line) { return '> ' + line; }).join('\n') + '\n\n';
  }

  function addQuote(author, topic, postId, text) {
    const reply = document.querySelector('#quick-reply');
    if (!reply) return;
    const textarea = reply.querySelector('.forum-editor');
    textarea.value += (textarea.value ? '\n\n' : '') + quoteMarkdown(author, topic, postId, text);
    // the editor hears of the new text as it would of typing
    textarea.dispatchEvent(new Event('input', {bubbles: true}));
    textarea.focus(); reply.scrollIntoView({block: 'start'});
  }
  document.querySelectorAll('.forum-quote').forEach(function (button) {
    button.addEventListener('click', function () {
      addQuote(button.dataset.author, button.dataset.topic, button.dataset.post, button.dataset.body);
    });
  });

  // The Markdown of a drawn piece of a post, so that what is quoted keeps
  // its code blocks (with their language), pictures, links and emphasis.
  function markdownOf(node, inCode) {
    if (node.nodeType === 3) return inCode ? node.nodeValue : node.nodeValue.replace(/\s+/g, ' ');
    if (node.nodeType !== 1 && node.nodeType !== 11) return '';
    const kids = function (code) { return Array.from(node.childNodes).map(function (k) { return markdownOf(k, code); }).join(''); };
    const fence = function (lang, text) { return '\n\n```' + lang + '\n' + text.replace(/\n+$/, '') + '\n```\n\n'; };
    if (node.nodeType === 11) return kids(inCode);
    const tag = node.tagName;
    if (node.classList.contains('code')) {
      const lang = node.querySelector('.codebar span'), pre = node.querySelector('pre');
      return pre ? fence(lang ? lang.textContent.trim() : '', pre.textContent) : '';
    }
    if (node.classList.contains('codebar') || tag === 'BUTTON') return '';
    if (tag === 'PRE') return fence('', node.textContent);
    if (tag === 'IMG') return '![' + (node.getAttribute('alt') || '') + '](' + SiteBase.strip(node.getAttribute('src') || '') + ')';
    if (tag === 'A') return '[' + kids(false) + '](' + SiteBase.strip(node.getAttribute('href') || '') + ')';
    if (tag === 'B' || tag === 'STRONG') return '**' + kids(false) + '**';
    if (tag === 'I' || tag === 'EM') return '*' + kids(false) + '*';
    if (tag === 'DEL' || tag === 'S') return '~~' + kids(false) + '~~';
    if (tag === 'CODE') return '`' + node.textContent + '`';
    if (tag === 'BR') return '\n';
    if (/^H[1-6]$/.test(tag)) return '\n\n' + '#'.repeat(Number(tag.charAt(1))) + ' ' + kids(false) + '\n\n';
    if (tag === 'LI') return (node.parentElement && node.parentElement.tagName === 'OL' ? '1. ' : '- ') + kids(false).trim() + '\n';
    if (tag === 'UL' || tag === 'OL') return '\n\n' + kids(false) + '\n';
    if (tag === 'BLOCKQUOTE') return '\n\n' + kids(false).trim().split('\n').map(function (line) { return '> ' + line; }).join('\n') + '\n\n';
    if (tag === 'TR') return '| ' + Array.from(node.children).map(function (c) { return markdownOf(c, false).trim(); }).join(' | ') + ' |\n';
    if (tag === 'THEAD') return kids(false) + '|' + Array.from(node.querySelectorAll('th')).map(function () { return '---|'; }).join('') + '\n';
    if (tag === 'TABLE') return '\n\n' + kids(false) + '\n';
    if (tag === 'P' || tag === 'DIV') return '\n\n' + kids(false) + '\n\n';
    return kids(inCode);
  }

  // What a selection holds, as Markdown.  A selection inside one code block
  // is that part of the code, fenced with the block's language.
  function selectionMarkdown(range) {
    const from = range.commonAncestorContainer;
    const at = from.nodeType === 1 ? from : from.parentElement;
    const block = at ? at.closest('.code') : null;
    if (block && at.closest('pre')) {
      const lang = block.querySelector('.codebar span');
      const text = range.toString().replace(/\n+$/, '');
      return text.trim() ? '```' + (lang ? lang.textContent.trim() : '') + '\n' + text + '\n```' : '';
    }
    // spaces left between the blocks go; lines of code keep theirs
    let code = false;
    return markdownOf(range.cloneContents(), false).split('\n').map(function (line) {
      if (/^\s*```/.test(line)) { code = !code; return line.trim(); }
      return code ? line : line.replace(/\s+$/, '').replace(/^ (?=\S)/, '');
    }).join('\n').replace(/\n{3,}/g, '\n\n').trim();
  }

  // Quoting a piece: text selected inside one post brings up a button beside
  // it, and the button puts just those words in the reply as a quote of
  // that member.  Only where the reader may reply, and only for a selection
  // that stays inside one post.
  (function () {
    if (!document.querySelector('#quick-reply') || !document.body || typeof window.getSelection !== 'function') return;
    const offer = document.createElement('button');
    offer.type = 'button';
    offer.className = 'forum-quote-selection';
    offer.textContent = t('Quote selection');
    offer.hidden = true;
    document.body.appendChild(offer);
    let picked = null;
    // the text of a post a node sits in; not the editor's preview, which
    // is drawn the same way
    function bodyOf(node) {
      const at = node && (node.nodeType === 1 ? node : node.parentElement);
      const body = at ? at.closest('.forum-body') : null;
      return body && body.parentElement && body.parentElement.classList.contains('forum-post-content') ? body : null;
    }
    function look() {
      offer.hidden = true;
      picked = null;
      const chosen = window.getSelection();
      if (!chosen || chosen.isCollapsed || !chosen.rangeCount) return;
      const body = bodyOf(chosen.anchorNode);
      const text = body ? selectionMarkdown(chosen.getRangeAt(0)) : '';
      if (!text || !body || body !== bodyOf(chosen.focusNode)) return;
      const button = body.closest('.forum-post').querySelector('.forum-quote');
      if (!button) return;
      picked = {author: button.dataset.author, topic: button.dataset.topic, post: button.dataset.post, text: text};
      const box = chosen.getRangeAt(0).getBoundingClientRect();
      offer.hidden = false;
      offer.style.top = (window.scrollY + box.bottom + 6) + 'px';
      offer.style.left = (window.scrollX + Math.max(8, Math.min(box.left, document.documentElement.clientWidth - offer.offsetWidth - 8))) + 'px';
    }
    // after the browser has settled the selection; a phone has no mouseup
    let later = 0;
    function soon() { clearTimeout(later); later = setTimeout(look, 150); }
    document.addEventListener('mouseup', soon);
    document.addEventListener('keyup', soon);
    document.addEventListener('selectionchange', soon);
    // pressing the button must not drop the selection it is about
    offer.addEventListener('mousedown', function (event) { event.preventDefault(); });
    offer.addEventListener('click', function () {
      if (!picked) return;
      addQuote(picked.author, picked.topic, picked.post, picked.text);
      window.getSelection().removeAllRanges();
      offer.hidden = true;
    });
  })();
  // Reactions under a post.  The server drew the chips; here each row is
  // drawn again by reactions.js, so a chip says who gave it and, for a
  // member who may react, puts theirs on or takes it back.  A row marked
  // data-add ends in the button that offers the forum's emoji.
  (function () {
    const offered = document.getElementById('forum-reactions');
    const lists = offered ? {shown: offered.dataset.shown.split(' ').filter(Boolean), more: offered.dataset.more.split(' ').filter(Boolean)} : null;
    function draw(row, list) {
      const id = row.dataset.post, add = lists && 'add' in row.dataset;
      const react = async function (emoji) {
        try {
          draw(fresh, (await post('/api/forum/react', new URLSearchParams({post: id, r: emoji}))).reactions);
        } catch (err) { alert(err.message); }
      };
      const fresh = Reactions.chips(list, {
        // where nothing may be added, one's own still comes off
        toggle: function (r) { if (add || (lists && r.mine)) react(r.r); },
        who: async function (r) {
          const response = await fetch('/api/forum/reacted?post=' + id + '&r=' + encodeURIComponent(r.r), {credentials: 'same-origin'});
          if (!response.ok) throw new Error(await response.text());
          return response.json();
        }
      });
      Object.assign(fresh.dataset, row.dataset);
      if (add && lists.shown.length + lists.more.length) {
        const more = Side.iconButton('react', t('Add a reaction'), 'forum-react-add');
        more.addEventListener('click', function () { Reactions.choose(more, lists, react); });
        fresh.appendChild(more);
      }
      const here = row.contains(document.activeElement);
      row.replaceWith(fresh);
      if (here && fresh.lastElementChild) fresh.lastElementChild.focus({preventScroll: true});
    }
    document.querySelectorAll('.forum-post .reacts').forEach(function (row) {
      draw(row, Array.from(row.children).map(function (chip) {
        return {r: chip.dataset.r, n: Number(chip.dataset.n), mine: chip.classList.contains('mine')};
      }));
    });
  })();
  document.querySelectorAll('[data-forum-new]').forEach(function (anchor) {
    anchor.addEventListener('click', function () { document.querySelector('#new-topic').open = true; });
  });
  document.querySelectorAll('[data-forum-panel]').forEach(function (button) {
    button.addEventListener('click', function () {
      const panel = document.getElementById(button.dataset.forumPanel);
      const opening = panel.hidden;
      const post = button.closest('.forum-post-content');
      post.querySelectorAll('.forum-action-panel').forEach(function (other) { other.hidden = true; });
      post.querySelectorAll('[data-forum-panel]').forEach(function (other) { other.setAttribute('aria-expanded', 'false'); });
      panel.hidden = !opening;
      button.setAttribute('aria-expanded', String(opening));
      if (opening) {
        const field = panel.querySelector('textarea, input:not([type=hidden]), button');
        if (field) field.focus();
      }
    });
  });
  // Back to a list the browser kept as it was: what was unread then may
  // have been read since, so the list is fetched again.
  window.addEventListener('pageshow', function (e) {
    if (e.persisted && document.querySelector('.forum-topics, .forum-boards')) location.reload();
  });
  document.querySelectorAll('.forum-editor').forEach(editor);
  codeButtons(document);
  document.querySelectorAll('[data-forum-tools]').forEach(function (tools) { tools.hidden = false; });
})();
