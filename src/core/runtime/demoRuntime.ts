/**
 * Process-local demo runtime state.
 *
 * This deliberately does not read or write localStorage, cookies, auth state,
 * or environment configuration. The auth/UI layer can activate it for an
 * explicit demo session, while data-plane callers can synchronously decide
 * whether they must stay on the bundled in-memory data path.
 */
let demoRuntimeActive = false;

export const isDemoRuntimeActive = (): boolean => demoRuntimeActive;

export const setDemoRuntimeActive = (active: boolean): void => {
  demoRuntimeActive = active;
};
