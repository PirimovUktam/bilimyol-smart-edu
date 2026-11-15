import { describe, expect, it } from 'vitest';
import { createHash } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';
import { resolve } from 'node:path';

const root = resolve(__dirname, '../..');

describe('Lighthouse Accessibility, Agentic Browsing, and Security Compliance', () => {
  it('removes low-contrast text-cyan-300 from WelcomeView', () => {
    const welcome = readFileSync(resolve(root, 'src/features/auth/WelcomeView.tsx'), 'utf8');
    expect(welcome).not.toContain('text-cyan-300');
    expect(welcome).toContain('text-brand-dark');
  });

  it('keeps robots.txt strictly valid for Googlebot SEO without unknown directives', () => {
    const robots = readFileSync(resolve(root, 'public/robots.txt'), 'utf8');
    const lines = robots
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter((line) => line.length > 0 && !line.startsWith('#'));

    const allowedDirectives = /^(User-agent|Allow|Disallow|Sitemap):/i;
    for (const line of lines) {
      expect(line).toMatch(allowedDirectives);
    }
    expect(robots.toLowerCase()).not.toContain('agentmap:');
  });

  it('provides compliant /llms.txt starting with an H1 heading and links', () => {
    const llms = readFileSync(resolve(root, 'public/llms.txt'), 'utf8');
    expect(llms.trimStart().startsWith('# BilimYo‘l Smart Edu')).toBe(true);
    expect(llms).toMatch(/\[[^\]]+\]\(https:\/\/bilimyol\.uz\/[^)]*\)/);
  });

  it('provides a valid ARD manifest at /.well-known/ard.json whose local targets exist', () => {
    const raw = readFileSync(resolve(root, 'public/.well-known/ard.json'), 'utf8');
    const manifest = JSON.parse(raw) as {
      '@context': string;
      entries: Array<{
        identifier: string;
        displayName: string;
        type: string;
        mediaType?: string;
        url?: string;
      }>;
    };

    expect(manifest['@context']).toBe('https://agenticresourcediscovery.org/context/v1');
    expect(Array.isArray(manifest.entries)).toBe(true);
    expect(manifest.entries.length).toBeGreaterThanOrEqual(2);

    const llmsEntry = manifest.entries.find((e) => e.url === 'https://bilimyol.uz/llms.txt');
    expect(llmsEntry?.mediaType).toBe('text/markdown; profile="urn:air:agent-skills"');

    for (const entry of manifest.entries) {
      expect(entry.identifier.startsWith('urn:air:bilimyol.uz:')).toBe(true);
      expect(entry.displayName.length).toBeGreaterThan(0);
      expect(entry.type.length).toBeGreaterThan(0);
      if (entry.url?.startsWith('https://bilimyol.uz/')) {
        const relPath = entry.url.replace('https://bilimyol.uz/', '');
        expect(existsSync(resolve(root, 'public', relPath))).toBe(true);
      }
    }
  });

  it('keeps inline bootstrap in index.html synchronized with vercel.json CSP SHA-256 and without blocking network script', () => {
    const indexHtml = readFileSync(resolve(root, 'index.html'), 'utf8');
    expect(indexHtml).not.toContain('<script src="/preferences-init.js">');
    expect(indexHtml).toContain('rel="ard"');
    expect(indexHtml).toContain('href="/.well-known/ard.json"');

    const match = indexHtml.match(/<script>([\s\S]*?)<\/script>/);
    expect(match).toBeTruthy();
    const inlineCode = match![1];

    // Verify inline script behavior matches light/uz defaults & dark/ru restoration
    const rootEl = { dataset: {} as Record<string, string>, lang: '', style: {} as Record<string, string>, classList: { toggle: () => {} } };
    runInNewContext(inlineCode, {
      document: { documentElement: rootEl },
      localStorage: { getItem: (k: string) => (k === 'bilimyol.theme' ? 'dark' : k === 'bilimyol.language' ? 'ru' : null) },
    });
    expect(rootEl.lang).toBe('ru');
    expect(rootEl.dataset.theme).toBe('dark');

    const expectedSha = `sha256-${createHash('sha256').update(inlineCode, 'utf8').digest('base64')}`;
    const vercel = JSON.parse(readFileSync(resolve(root, 'vercel.json'), 'utf8')) as {
      headers: Array<{ source: string; headers: Array<{ key: string; value: string }> }>;
      rewrites: Array<{ source: string; destination: string }>;
    };

    const globalHeaders = vercel.headers.find((h) => h.source === '/(.*)')?.headers ?? [];
    const headerMap = Object.fromEntries(globalHeaders.map((h) => [h.key, h.value]));

    expect(headerMap['Content-Security-Policy']).toContain(`'${expectedSha}'`);
    expect(headerMap['Cross-Origin-Opener-Policy']).toBe('same-origin');
    expect(headerMap['X-Frame-Options']).toBe('DENY');
    expect(headerMap['X-Content-Type-Options']).toBe('nosniff');

    const spaRewrite = vercel.rewrites.find((r) => r.destination === '/index.html');
    expect(spaRewrite).toBeTruthy();
    expect(spaRewrite!.source).toContain('llms');
    expect(spaRewrite!.source).toContain('.well-known');
  });
});
