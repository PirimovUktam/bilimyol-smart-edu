import { afterEach, describe, expect, it, vi } from 'vitest';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import { message, ru, uz, type MessageKey } from '../core/locales/messages';
import { readPreference, usePreferences } from '../core/preferences/preferences';

afterEach(() => vi.unstubAllGlobals());

describe('preferences at first paint', () => {
  const bootstrap = readFileSync('public/preferences-init.js', 'utf8');
  function initialize(saved: Record<string, string>, blocked = false) {
    const root = { dataset: {} as Record<string, string>, lang: '', style: {}, classList: { toggle: vi.fn() } };
    runInNewContext(bootstrap, {
      document: { documentElement: root }, navigator: { language: 'ru-RU' },
      localStorage: { getItem: (key: string) => { if (blocked) throw new Error('denied'); return saved[key]; } },
    });
    return root;
  }
  it('always initializes Uzbek and light for new visitors, even in Russian browsers', () => {
    expect(initialize({})).toMatchObject({ lang: 'uz', dataset: { theme: 'light' }, style: { colorScheme: 'light' } });
  });
  it('uses saved preferences before rendering', () => {
    const root = initialize({ 'bilimyol.theme': 'dark', 'bilimyol.language': 'ru' });
    expect(root).toMatchObject({ lang: 'ru', dataset: { theme: 'dark' } });
    expect(root.classList.toggle).toHaveBeenCalledWith('dark', true);
  });
  it('handles unavailable storage and corrupted preferences', () => {
    expect(initialize({}, true).lang).toBe('uz');
    expect(initialize({ 'bilimyol.language': 'en', 'bilimyol.theme': 'invalid' }).dataset.theme).toBe('light');
    vi.stubGlobal('localStorage', { getItem: () => { throw Error('denied'); } });
    expect(readPreference('bilimyol.language', ['uz', 'ru'], 'uz')).toBe('uz');
  });
  it('persists user choices while remaining usable if storage fails', () => {
    const setItem = vi.fn();
    vi.stubGlobal('localStorage', { setItem });
    usePreferences.getState().setLanguage('ru');
    usePreferences.getState().setTheme('dark');
    expect(setItem).toHaveBeenCalledWith('bilimyol.language', 'ru');
    expect(setItem).toHaveBeenCalledWith('bilimyol.theme', 'dark');
    setItem.mockImplementation(() => { throw Error('denied'); });
    usePreferences.getState().setTheme('light');
    expect(usePreferences.getState().theme).toBe('light');
  });
});

describe('typed interface dictionaries', () => {
  it('has the same nonempty keys in both languages', () => {
    expect(Object.keys(ru)).toEqual(Object.keys(uz));
    for (const namespace of Object.keys(uz) as (keyof typeof uz)[]) {
      expect(Object.keys(ru[namespace])).toEqual(Object.keys(uz[namespace]));
      for (const key of Object.keys(uz[namespace])) {
        expect(message('ru', `${namespace}.${key}` as MessageKey).trim().length).toBeGreaterThan(0);
      }
    }
  });
  it('uses selected language without translating learner content', () => {
    expect(message('uz', 'auth.login')).toBe('Kirish');
    expect(message('ru', 'auth.login')).toBe('Войти');
  });
});
