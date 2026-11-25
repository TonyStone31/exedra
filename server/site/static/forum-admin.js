// The forum's boards tab, loaded by the admin shell.
(function () {
  'use strict';
  const C = window.Site;
  if (C.extras.adminTabs.some(function (tab) { return tab.permission === 'forum-boards'; })) return;
  const style = document.createElement('link');
  style.rel = 'stylesheet';
  style.href = '/static/forum.css' + new URL(document.currentScript.src).search;
  document.head.appendChild(style);

  function el(tag, text) {
    const node = document.createElement(tag);
    if (text !== undefined) node.textContent = text;
    return node;
  }

  function button(text, action) {
    const node = el('button', text);
    node.type = 'button';
    node.addEventListener('click', action);
    return node;
  }

  async function build(box) {
    box.className += ' forum-admin';
    let boards = [], categories = [], permissions = [];
    const error = el('p');
    error.className = 'forum-error';
    error.setAttribute('role', 'alert');
    const content = el('div');
    box.replaceChildren(error, content);
    let busy = false;

    async function change(path, fields) {
      if (busy) return;
      busy = true;
      error.textContent = '';
      const buttons = Array.from(box.querySelectorAll('button'), function (node) { return {node: node, disabled: node.disabled}; });
      buttons.forEach(function (item) { item.node.disabled = true; });
      try {
        await C.post('/api/forum/admin/' + path, fields);
        await load();
      } catch (err) { error.textContent = err.message; }
      finally {
        busy = false;
        buttons.forEach(function (item) { item.node.disabled = item.disabled; });
      }
    }

    function field(form, name, caption, value, type) {
      const label = el('label', caption + ' ');
      const input = el(type === 'textarea' ? 'textarea' : 'input');
      input.name = name;
      input.value = value === undefined ? '' : String(value);
      if (type && type !== 'textarea') input.type = type;
      label.appendChild(input);
      form.appendChild(label);
      return input;
    }

    function edit(board) {
      const form = el('form');
      const values = {};
      const boardId = board.id || 0;
      const hasChildren = boards.some(function (item) { return item.parent_id === boardId; });
      values.name = field(form, 'name', t('Name'), board.name || '');
      values.name.required = true;
      values.name.maxLength = 100;
      values.slug = field(form, 'slug', t('Slug'), board.slug || '');
      values.slug.required = true;
      values.slug.maxLength = 80;
      values.description = field(form, 'description', t('Description'), board.description || '', 'textarea');
      values.description.maxLength = 2000;
      values.position = field(form, 'position', t('Position'), board.position || 0, 'number');
      values.position.required = true;
      const parentLabel = el('label', t('Parent board') + ' ');
      const parent = el('select');
      const none = el('option', t('None'));
      none.value = '0';
      parent.appendChild(none);
      boards.filter(function (item) { return !hasChildren && !item.parent_id && item.id !== boardId; }).forEach(function (item) {
        const option = el('option', item.name);
        option.value = String(item.id);
        parent.appendChild(option);
      });
      parent.value = String(board.parent_id || 0);
      parentLabel.appendChild(parent);
      form.appendChild(parentLabel);
      const categoryLabel = el('label', t('Category') + ' ');
      const category = el('select'); category.name = 'category_id';
      const general = el('option', t('General')); general.value = '0'; category.appendChild(general);
      categories.forEach(function (item) { const option = el('option', item.name); option.value = String(item.id); category.appendChild(option); });
      category.value = String(board.category_id || 0); categoryLabel.appendChild(category); form.appendChild(categoryLabel);
      // Free entry also works for board admins who cannot read the core permission list.
      values.read_permission = field(form, 'read_permission', t('Read permission'), board.read_permission || 'forum-read');
      values.read_permission.required = true;
      values.read_permission.maxLength = 40;
      values.read_permission.setAttribute('list', 'forum-permissions');
      const save = el('button', t('Save'));
      save.type = 'submit';
      form.append(save, button(t('Cancel'), draw));
      form.addEventListener('submit', function (event) {
        event.preventDefault();
        const fields = {id: boardId, parent_id: parent.value, category_id: category.value};
        Object.keys(values).forEach(function (key) { fields[key] = values[key].value; });
        change('board', fields);
      });
      content.replaceChildren(form);
    }

    function order(index, offset) {
      const ordered = boards.slice();
      const other = index + offset;
      if (other < 0 || other >= ordered.length) return;
      [ordered[index], ordered[other]] = [ordered[other], ordered[index]];
      return change('order', {ids: ordered.map(function (item) { return item.id; }).join(',')});
    }

    function editCategory(category) {
      const form = el('form');
      const name = field(form, 'name', t('Category name'), category.name || '');
      name.required = true; name.maxLength = 100;
      const position = field(form, 'position', t('Position'), category.position || 0, 'number');
      const save = el('button', t('Save')); save.type = 'submit';
      form.append(save, button(t('Cancel'), draw));
      form.addEventListener('submit', function (event) {
        event.preventDefault();
        change('category', {id: category.id || 0, name: name.value, position: position.value});
      });
      content.replaceChildren(form);
    }

    function drawCategories() {
      content.append(el('h3', t('Categories')), button(t('Add category'), function () { editCategory({}); }));
      const list = el('ul');
      categories.forEach(function (category, index) {
        const row = el('li', category.name + ' (' + category.position + ') ');
        const up = button(t('Move category up'), function () {
          // Position ties are allowed; move across the neighbor even when both have the same position.
          const previous = categories[index - 1];
          change('category', {id: category.id, name: category.name, position: Number(previous.position) - 1});
        });
        const down = button(t('Move category down'), function () {
          const next = categories[index + 1];
          change('category', {id: category.id, name: category.name, position: Number(next.position) + 1});
        });
        up.disabled = index === 0; down.disabled = index === categories.length - 1;
        row.append(button(t('Rename category'), function () { editCategory(category); }), up, down,
          button(t('Remove category'), function () {
            if (confirm(t('Remove category %s?', category.name))) change('category/remove', {id: category.id});
          }));
        list.appendChild(row);
      });
      content.appendChild(list);
    }

    function draw() {
      content.replaceChildren();
      const choices = el('datalist');
      choices.id = 'forum-permissions';
      const names = new Set(['forum-read', 'forum-members', 'forum-staff']);
      permissions.forEach(function (item) { names.add(item.name); });
      boards.forEach(function (item) { names.add(item.read_permission); });
      names.forEach(function (name) {
        const option = el('option'); option.value = name; choices.appendChild(option);
      });
      // The datalist remains available while a board's edit form replaces the list.
      const old = box.querySelector('datalist');
      if (old) old.remove();
      box.appendChild(choices);
      content.append(el('p', tn(boards.length, '%d board', '%d boards')), button(t('Add board'), function () { edit({}); }));
      const table = el('table');
      table.className = 'grid';
      const head = el('tr');
      [t('Name'), t('Category'), t('Parent board'), t('Read permission'), t('Position'), t('Actions')].forEach(function (caption) { head.appendChild(el('th', caption)); });
      table.appendChild(head);
      boards.forEach(function (board, index) {
        const row = el('tr');
        const parent = boards.find(function (item) { return item.id === board.parent_id; });
        const category = categories.find(function (item) { return item.id === (parent ? parent.category_id : board.category_id); });
        row.append(el('td', board.name), el('td', category ? category.name : t('General')), el('td', parent ? parent.name : ''), el('td', board.read_permission), el('td', String(board.position)));
        const actions = el('td');
        const up = button(t('Move up'), function () { order(index, -1); });
        const down = button(t('Move down'), function () { order(index, 1); });
        up.disabled = index === 0; down.disabled = index === boards.length - 1;
        actions.append(button(t('Edit'), function () { edit(board); }), up, down,
          button(t('Remove'), function () {
            if (confirm(t('Remove board %s?', board.name))) change('remove', {id: board.id});
          }));
        row.appendChild(actions);
        table.appendChild(row);
      });
      const wrap = el('div'); wrap.className = 'gridwrap'; wrap.appendChild(table); content.appendChild(wrap);
      drawCategories();
    }

    async function load() {
      [boards, categories] = await Promise.all([C.get('/api/forum/admin/boards'), C.get('/api/forum/admin/categories')]);
      draw();
    }

    try {
      const data = await C.get('/api/admin');
      permissions = data.permissions || [];
      await load();
    } catch (err) { error.textContent = err.message; }
  }

  C.extras.adminTabs.push({title: t('Forum boards'), permission: 'forum-boards', build: build, group: 'Forum'});
})();
