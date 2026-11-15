import type { MessageKey } from './messages';
import { translate } from './useTranslation';

/** Only safe, reviewed messages cross the service/UI boundary. */
export class LocalizedError extends Error {
  constructor(readonly messageKey: MessageKey, readonly code?: string) {
    super(translate(messageKey));
    this.name = 'LocalizedError';
  }
}
export function displayError(error: unknown, t: (key: MessageKey) => string, fallback: MessageKey = 'errors.auth'): string {
  return t(error instanceof LocalizedError ? error.messageKey : fallback);
}
