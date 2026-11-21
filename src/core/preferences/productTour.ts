export const PRODUCT_TOUR_STORAGE_KEY = 'bilimyol.product_tour_completed';

const AUTH_CALLBACK_TYPES = new Set([
  'recovery',
  'signup',
  'invite',
  'magiclink',
  'email_change',
]);

const AUTH_CALLBACK_KEYS = [
  'code',
  'access_token',
  'refresh_token',
  'token_hash',
  'error',
  'error_code',
  'error_description',
] as const;

export function hasCompletedProductTour(): boolean {
  try {
    return globalThis.localStorage?.getItem(PRODUCT_TOUR_STORAGE_KEY) === 'true';
  } catch {
    return false;
  }
}

export function markProductTourCompleted(): boolean {
  try {
    globalThis.localStorage?.setItem(PRODUCT_TOUR_STORAGE_KEY, 'true');
    return true;
  } catch {
    return false;
  }
}

export function hasAuthCallbackParams(
  location: Pick<Location, 'search' | 'hash'> = window.location,
): boolean {
  const searchParams = new URLSearchParams(location.search);
  const hashRaw = location.hash.startsWith('#') ? location.hash.slice(1) : location.hash;
  const hashParams = new URLSearchParams(hashRaw);

  for (const params of [searchParams, hashParams]) {
    for (const key of AUTH_CALLBACK_KEYS) {
      if (params.has(key)) return true;
    }
    const type = params.get('type')?.toLowerCase();
    if (type && AUTH_CALLBACK_TYPES.has(type)) return true;
  }
  return false;
}

export function isRootWelcomeEntry(
  location: Pick<Location, 'pathname' | 'search' | 'hash'> = window.location,
): boolean {
  const normalizedPath = location.pathname.toLowerCase();
  if (normalizedPath !== '/' && normalizedPath !== '') return false;
  const searchParams = new URLSearchParams(location.search);
  const requestedView = searchParams.get('view')?.toLowerCase();
  if (requestedView && requestedView !== 'welcome') return false;
  if (hasAuthCallbackParams(location)) return false;
  const hash = location.hash.replace(/^#/, '').trim().toLowerCase();
  if (hash && hash !== 'welcome' && !hash.includes('=')) return false;
  return true;
}
