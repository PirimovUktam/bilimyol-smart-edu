import { describe, expect, it } from 'vitest';
import { isValidSupabaseUrl } from '../core/config/supabase';

describe('supabase config URL validation', () => {
  it('accepts a well-formed Supabase project URL', () => {
    expect(isValidSupabaseUrl('https://jlqbenwojcgbloamfyis.supabase.co')).toBe(true);
    expect(isValidSupabaseUrl('https://ncidqtwzykziwcgbeyaw.supabase.co/')).toBe(true);
  });

  it('rejects empty, malformed, non-https and non-supabase URLs', () => {
    for (const bad of [
      '',
      'not-a-url',
      'http://jlqbenwojcgbloamfyis.supabase.co', // must be https
      'https://evil.example.com',
      'https://jlqbenwojcgbloamfyis.supabase.co.evil.com',
      'https://attacker.com/?ref=jlqbenwojcgbloamfyis',
      'ftp://x.supabase.co',
    ]) {
      expect(isValidSupabaseUrl(bad), bad).toBe(false);
    }
  });
});
