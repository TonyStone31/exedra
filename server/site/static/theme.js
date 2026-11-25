// Runs before the page draws, so a dark page never flashes light.
// auto follows the system; light and dark are the member's choice.
(function () {
  let theme = 'auto';
  try { theme = localStorage.getItem('theme') || 'auto'; } catch (e) { }
  const valid = function (value) { return ['auto', 'light', 'dark'].includes(value) ? value : 'auto'; };
  function apply(value) {
    theme = valid(value);
    if (theme === 'auto') delete document.documentElement.dataset.theme;
    else document.documentElement.dataset.theme = theme;
    document.querySelectorAll('[data-theme-picker]').forEach(function (picker) { picker.value = theme; });
    window.dispatchEvent(new Event('themechange'));
  }
  window.Theme = {get: function () { return theme; }, set: function (value) {
    apply(value);
    try { localStorage.setItem('theme', theme); } catch (e) { }
  }};
  apply(theme);
  window.addEventListener('storage', function (event) {
    if (event.key === 'theme' || event.key === null) {
      let saved = 'auto';
      try { saved = localStorage.getItem('theme') || 'auto'; } catch (e) { }
      apply(saved);
    }
  });
  document.addEventListener('DOMContentLoaded', function () {
    document.querySelectorAll('[data-theme-picker]').forEach(function (picker) {
      picker.value = theme;
      picker.closest('.theme-choice').hidden = false;
      picker.addEventListener('change', function () { Theme.set(picker.value); });
    });
  });
})();
