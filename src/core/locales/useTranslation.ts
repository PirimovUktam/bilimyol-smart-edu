import { useCallback } from 'react';
import { usePreferences } from '../preferences/preferences';
import { message, type MessageKey } from './messages';

export function translate(key: MessageKey, values?: Record<string, string | number>) {
  return format(message(usePreferences.getState().language, key), values);
}
function format(text: string, values?: Record<string, string | number>) {
  return values ? text.replace(/\{(\w+)\}/g, (placeholder, name: string) => String(values[name] ?? placeholder)) : text;
}
export function useTranslation() {
  const language = usePreferences((state) => state.language);
  const t = useCallback((key: MessageKey, values?: Record<string, string | number>) => format(message(language, key), values), [language]);
  return { language, t };
}
