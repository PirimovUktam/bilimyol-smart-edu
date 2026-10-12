import { describe, it, expect } from 'vitest';
import * as fs from 'fs';
import * as path from 'path';

describe('BilimYolLogo Accessibility & Contrast Suite', () => {
  const logoPath = path.resolve(__dirname, '../presentation/components/BilimYolLogo.tsx');
  const loginViewPath = path.resolve(__dirname, '../features/auth/LoginView.tsx');
  const appRouterPath = path.resolve(__dirname, '../app/router/AppRouter.tsx');

  it('1. BilimYolLogo supports universal text color resolution including dark and auto variants', () => {
    const code = fs.readFileSync(logoPath, 'utf8');
    expect(code).toContain("variant?: 'light' | 'dark' | 'auto'");
    expect(code).toContain('textColor?: string');
    expect(code).toContain("variant === 'dark'");
    expect(code).toContain("'text-white'");
    expect(code).toContain("'text-slate-900 dark:text-white'");
  });

  it('2. LoginView uses variant="dark" and avoids duplicate subtitles in the hero section', () => {
    const code = fs.readFileSync(loginViewPath, 'utf8');
    // Must pass variant="dark" in the dark hero header
    expect(code).toMatch(/<BilimYolLogo[^>]*variant="dark"[^>]*\/>/i);
    // Must hide internal subtitle to prevent visual text duplication
    expect(code).toMatch(/<BilimYolLogo[^>]*showSubtitle=\{false\}[^>]*\/>/i);
  });

  it('3. AppRouter loading screen renders BilimYolLogo with variant="dark" on dark background', () => {
    const code = fs.readFileSync(appRouterPath, 'utf8');
    expect(code).toMatch(/<BilimYolLogo[^>]*variant="dark"[^>]*\/>/i);
  });
});
