import { useEffect, useLayoutEffect } from 'react';
import { Moon, Sun } from 'lucide-react';
import { useTranslation } from '@/core/locales/useTranslation';
import { preferenceKeys, syncPreferenceDocument, usePreferences } from '@/core/preferences/preferences';

export function PreferencesBar() {
  const { theme, language, setTheme, setLanguage } = usePreferences();
  const { t } = useTranslation();
  useLayoutEffect(() => { syncPreferenceDocument(theme, language); }, [theme, language]);
  useEffect(() => {
    const sync = (event: StorageEvent) => {
      if (event.key === preferenceKeys.theme && (event.newValue === 'light' || event.newValue === 'dark')) {
        usePreferences.setState({ theme: event.newValue });
      }
      if (event.key === preferenceKeys.language && (event.newValue === 'uz' || event.newValue === 'ru')) {
        usePreferences.setState({ language: event.newValue });
      }
    };
    window.addEventListener('storage', sync);
    return () => window.removeEventListener('storage', sync);
  }, []);
  const Icon = theme === 'dark' ? Sun : Moon;
  return <header className="preferences-bar" aria-label={t('common.settings')}>
    <button type="button" className="preference-control" aria-label={t(theme === 'dark' ? 'common.light' : 'common.dark')}
      title={t(theme === 'dark' ? 'common.light' : 'common.dark')} onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}>
      <Icon className="size-4" aria-hidden="true" />
    </button>
    <label className="sr-only" htmlFor="interface-language">{t('common.language')}</label>
    <select id="interface-language" className="preference-control" value={language}
      onChange={(event) => setLanguage(event.target.value === 'ru' ? 'ru' : 'uz')}>
      <option value="uz">UZ · O‘zbekcha</option>
      <option value="ru">RU · Русский</option>
    </select>
  </header>;
}
