if (typeof window !== 'undefined' && typeof document !== 'undefined') {
  await import('@testing-library/jest-dom/vitest');
  const [{ afterEach }, { cleanup }] = await Promise.all([
    import('vitest'),
    import('@testing-library/react'),
  ]);
  afterEach(() => {
    cleanup();
  });
}

export {};
