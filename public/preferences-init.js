// Runs before rendering or stylesheet loading. Must agree with preferences.ts.
(() => {
  let theme = 'light';
  let language = 'uz';
  try {
    if (localStorage.getItem('bilimyol.theme') === 'dark') theme = 'dark';
    if (localStorage.getItem('bilimyol.language') === 'ru') language = 'ru';
  } catch { /* Restricted storage: keep explicit defaults. */ }
  document.documentElement.dataset.theme = theme;
  document.documentElement.classList.toggle('dark', theme === 'dark');
  document.documentElement.lang = language;
  document.documentElement.style.colorScheme = theme;
})();
