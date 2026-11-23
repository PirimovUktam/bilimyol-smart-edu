import React from 'react';
import { renderToString } from 'react-dom/server';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('zustand', async (importOriginal) => {
  const actual = await importOriginal<typeof import('zustand')>();
  const react = await import('react');
  return {
    ...actual,
    create: ((createState: Parameters<typeof actual.create>[0]) => {
      if (!createState) return actual.create;
      const api = actual.create(createState);
      return Object.assign(
        (selector: (state: unknown) => unknown = (state) => state) =>
          react.useSyncExternalStore(
            api.subscribe,
            () => selector(api.getState()),
            () => selector(api.getState()),
          ),
        api,
      );
    }) as typeof actual.create,
  };
});

import {
  hasAuthCallbackParams,
  hasCompletedProductTour,
  isRootWelcomeEntry,
  markProductTourCompleted,
  PRODUCT_TOUR_STORAGE_KEY,
} from '../core/preferences/productTour';
import { loadRussian } from '../core/locales/messages';
import { usePreferences } from '../core/preferences/preferences';
import { ProductTourView } from '../features/tour/ProductTourView';

beforeEach(async () => {
  await usePreferences.getState().setLanguage('uz', false);
});

afterEach(() => {
  vi.unstubAllGlobals();
});

describe('productTour preferences and URL guards', () => {
  it('reads and writes completion flag under bilimyol.product_tour_completed', () => {
    const store = new Map<string, string>();
    vi.stubGlobal('localStorage', {
      getItem: (key: string) => store.get(key) ?? null,
      setItem: (key: string, value: string) => store.set(key, value),
    });

    expect(hasCompletedProductTour()).toBe(false);
    expect(markProductTourCompleted()).toBe(true);
    expect(store.get(PRODUCT_TOUR_STORAGE_KEY)).toBe('true');
    expect(hasCompletedProductTour()).toBe(true);
  });

  it('degrades gracefully without throwing when localStorage is blocked', () => {
    vi.stubGlobal('localStorage', {
      getItem: () => {
        throw new Error('SecurityError');
      },
      setItem: () => {
        throw new Error('SecurityError');
      },
    });

    expect(hasCompletedProductTour()).toBe(false);
    expect(markProductTourCompleted()).toBe(false);
  });

  it('detects Supabase auth callback and recovery query/hash parameters', () => {
    expect(hasAuthCallbackParams({ search: '', hash: '' })).toBe(false);
    expect(hasAuthCallbackParams({ search: '?code=pkce-code', hash: '' })).toBe(true);
    expect(hasAuthCallbackParams({ search: '', hash: '#access_token=tok&type=recovery' })).toBe(true);
    expect(hasAuthCallbackParams({ search: '?type=signup', hash: '' })).toBe(true);
    expect(hasAuthCallbackParams({ search: '?error_description=denied', hash: '' })).toBe(true);
  });

  it('only treats clean root welcome entries as first-visit tour candidates', () => {
    expect(isRootWelcomeEntry({ pathname: '/', search: '', hash: '' })).toBe(true);
    expect(isRootWelcomeEntry({ pathname: '/', search: '?view=welcome', hash: '' })).toBe(true);
    expect(isRootWelcomeEntry({ pathname: '/login', search: '', hash: '' })).toBe(false);
    expect(isRootWelcomeEntry({ pathname: '/', search: '?view=pitch', hash: '' })).toBe(false);
    expect(isRootWelcomeEntry({ pathname: '/', search: '?code=123', hash: '' })).toBe(false);
    expect(isRootWelcomeEntry({ pathname: '/', search: '', hash: '#access_token=abc' })).toBe(false);
  });
});

describe('ProductTourView rendering', () => {
  it('renders Scene 1 in Uzbek with the focal map, Skip, and primary CTA', () => {
    const html = renderToString(
      <ProductTourView mode="first-visit" onComplete={() => {}} onSkip={() => {}} />,
    );

    expect(html).toContain('Qaysi dars');
    expect(html).toContain('aynan sizga mos?');
    expect(html).toContain('BilimYöl qisqa diagnostika orqali nimani bilişingizni aniqlaydi');
    expect(html).toContain('Sinab köriş');
    expect(html).toContain('Ötkazib yuboriş');
    expect(html).toContain('To be: am / is / are');
  });

  it('renders Scene 1 cleanly in Russian when ru preference is active', async () => {
    await loadRussian();
    await usePreferences.getState().setLanguage('ru', false);

    const html = renderToString(
      <ProductTourView mode="replay" onComplete={() => {}} onSkip={() => {}} />,
    );

    expect(html).toContain('Какой урок');
    expect(html).toContain('подходит именно вам?');
    expect(html).toContain('Попробовать');
    expect(html).toContain('Пропустить');
    expect(html).toContain('Обзор продукта');
  });
});
