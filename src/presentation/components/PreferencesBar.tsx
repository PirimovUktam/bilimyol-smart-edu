import { useCallback, useEffect, useLayoutEffect, useState } from 'react';
import { Moon, Sun } from 'lucide-react';
import { useTranslation } from '@/core/locales/useTranslation';
import { preferenceKeys, syncPreferenceDocument, usePreferences } from '@/core/preferences/preferences';

export function PreferencesBar() {
  const { theme, language, setTheme, setLanguage } = usePreferences();
  const { t } = useTranslation();
  const [changingLanguage, setChangingLanguage] = useState(false);
  const [languageFailed, setLanguageFailed] = useState(false);
  const changeLanguage = useCallback(async (next: 'uz' | 'ru', persist = true) => {
    setChangingLanguage(true);
    setLanguageFailed(false);
    try { await setLanguage(next, persist); }
    catch { setLanguageFailed(true); }
    finally { setChangingLanguage(false); }
  }, [setLanguage]);
  useLayoutEffect(() => { syncPreferenceDocument(theme, language); }, [theme, language]);
  useEffect(() => {
    const sync = (event: StorageEvent) => {
      if (event.key === preferenceKeys.theme && (event.newValue === 'light' || event.newValue === 'dark')) {
        usePreferences.setState({ theme: event.newValue });
      }
      if (event.key === preferenceKeys.language && (event.newValue === 'uz' || event.newValue === 'ru')) {
        void changeLanguage(event.newValue, false);
      }
    };
    window.addEventListener('storage', sync);
    return () => window.removeEventListener('storage', sync);
  }, [changeLanguage]);
  const Icon = theme === 'dark' ? Sun : Moon;
  return <header className="preferences-bar" aria-label={t('common.settings')}>
    <button type="button" className="preference-control" aria-label={t(theme === 'dark' ? 'common.light' : 'common.dark')}
      title={t(theme === 'dark' ? 'common.light' : 'common.dark')} onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}>
      <Icon className="size-4" aria-hidden="true" />
    </button>
    <label className="sr-only" htmlFor="interface-language">{t('common.language')}</label>
    <select id="interface-language" className="preference-control" value={language} disabled={changingLanguage}
      onChange={(event) => void changeLanguage(event.target.value === 'ru' ? 'ru' : 'uz')}>
      <option value="uz">UZ · Özbekça</option>
      <option value="ru">RU · Русский</option>
    </select>
    {languageFailed && <span role="alert" title={t('admin.loadFailed')} className="max-w-36 text-xs text-coral">{t('admin.loadFailed')}</span>}
  </header>;
}
