import { LocalizedError } from '@/core/locales/LocalizedError';
import type { MessageKey } from '@/core/locales/messages';

const providerErrors: Readonly<Partial<Record<string, MessageKey>>> = {
  invalid_credentials: 'errors.invalidCredentials',
  email_not_confirmed: 'errors.unconfirmed',
  over_email_send_rate_limit: 'errors.emailLimit',
  over_request_rate_limit: 'errors.rateLimit',
  email_address_not_authorized: 'errors.mailDenied',
  email_address_invalid: 'errors.invalidEmail',
  user_already_exists: 'errors.exists',
  weak_password: 'errors.weakPassword',
  signup_disabled: 'errors.signupDisabled',
};

/** Map provider codes to safe messages without rendering raw provider errors. */
export function authError(error: unknown, fallback: MessageKey = 'errors.auth'): LocalizedError {
  const code = typeof error === 'object' && error !== null && 'code' in error && typeof error.code === 'string'
    ? error.code
    : undefined;
  const key = code && Object.hasOwn(providerErrors, code) ? providerErrors[code] : undefined;
  return new LocalizedError(key ?? fallback, code);
}
