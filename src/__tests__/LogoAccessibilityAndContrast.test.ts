import { describe, it, expect } from 'vitest';
import * as fs from 'fs';
import * as path from 'path';

describe('BilimYolLogo Accessibility & Contrast Suite', () => {
  const logoPath = path.resolve(__dirname, '../presentation/components/BilimYolLogo.tsx');
  const authLayoutPath = path.resolve(__dirname, '../features/auth/AuthLayout.tsx');
  const navbarPath = path.resolve(__dirname, '../presentation/components/Navbar.tsx');

  it('1. BilimYolLogo supports universal text color resolution including dark and auto variants', () => {
    const code = fs.readFileSync(logoPath, 'utf8');
    expect(code).toContain("variant?: 'light' | 'dark' | 'auto'");
    expect(code).toContain('textColor?: string');
    expect(code).toContain("variant === 'dark'");
    expect(code).toContain("'text-white'");
    expect(code).toContain("'text-slate-900 dark:text-white'");
  });

  it('2. The shared auth layout uses the dark logo variant in its showcase', () => {
    const code = fs.readFileSync(authLayoutPath, 'utf8');
    // Must pass variant="dark" in the dark hero header
    expect(code).toMatch(/<BilimYolLogo[^>]*variant="dark"[^>]*\/>/i);
    // Must hide internal subtitle to prevent visual text duplication
    expect(code).toMatch(/<BilimYolLogo[^>]*showSubtitle=\{false\}[^>]*\/>/i);
  });

  it('3. The workspace sidebar uses the dark logo variant', () => {
    const code = fs.readFileSync(navbarPath, 'utf8');
    expect(code).toMatch(/<BilimYolLogo[^>]*variant="dark"[^>]*\/>/i);
  });
});
