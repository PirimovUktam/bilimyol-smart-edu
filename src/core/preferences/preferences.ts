import { create } from 'zustand';
import { loadRussian } from '../locales/messages';

export type Theme = 'light' | 'dark';
export type Language = 'uz' | 'ru';
export const preferenceKeys = { theme: 'bilimyol.theme', language: 'bilimyol.language' } as const;

export function readPreference<T extends string>(key: string, allowed: readonly T[], fallback: T): T {
  try {
    const value = globalThis.localStorage?.getItem(key);
    return allowed.includes(value as T) ? value as T : fallback;
  } catch { return fallback; }
}

function save(key: string, value: string) {
  try { globalThis.localStorage?.setItem(key, value); } catch { /* In-memory preference still works. */ }
}

let languageSelection = 0;

export const usePreferences = create<{
  theme: Theme;
  language: Language;
  setTheme: (theme: Theme) => void;
  setLanguage: (language: Language, persist?: boolean) => Promise<void>;
}>((set) => ({
  theme: readPreference(preferenceKeys.theme, ['light', 'dark'], 'light'),
  language: readPreference(preferenceKeys.language, ['uz', 'ru'], 'uz'),
  setTheme: (theme) => { save(preferenceKeys.theme, theme); set({ theme }); },
  setLanguage: async (language, persist = true) => {
    const selection = ++languageSelection;
    if (language === 'ru') await loadRussian();
    if (selection !== languageSelection) return;
    if (persist) save(preferenceKeys.language, language);
    set({ language });
  },
}));

export function syncPreferenceDocument(theme: Theme, language: Language) {
  document.documentElement.dataset.theme = theme;
  document.documentElement.classList.toggle('dark', theme === 'dark');
  document.documentElement.lang = language;
  document.documentElement.style.colorScheme = theme;
  document.querySelector('meta[name="theme-color"]')?.setAttribute('content', theme === 'dark' ? '#101426' : '#F5F6FC');
}
