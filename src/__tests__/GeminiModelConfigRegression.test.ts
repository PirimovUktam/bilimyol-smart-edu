import { describe, it, expect } from 'vitest';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { GeminiAITutorService } from '../data/services/GeminiAITutorService';
import { DemoAITutorService } from '../data/services/DemoAITutorService';

const EDGE_FUNCTION_PATH = path.resolve(
  process.cwd(),
  'supabase/functions/yolchi-tutor/index.ts'
);
const SERVICE_PATH = path.resolve(
  process.cwd(),
  'src/data/services/GeminiAITutorService.ts'
);

/**
 * Bosqiç 1 regression himoyasi:
 * - Model nomi hujjatlangan va tasdiqlangan bölişi şart (taxmin yöq).
 * - GEMINI_API_KEY faqat Edge secret (Deno.env) orqali öqiladi — kodda hardcoded kalit yöq.
 * - Fallback javobi heç qaçon haqiqiy AI natijasi deb belgilanmaydi.
 */
describe('Gemini Model Config Regression (Bosqiç 1)', () => {
  it('1. Edge Function model defaulti gemini-3.6-flash va GEMINI_MODEL secret orqali override qilinadi', () => {
    const src = fs.readFileSync(EDGE_FUNCTION_PATH, 'utf-8');
    expect(src).toContain('Deno.env.get("GEMINI_MODEL")');
    expect(src).toContain('"gemini-3.6-flash"');
  });

  it('2. GEMINI_API_KEY faqat Deno.env dan öqiladi — kodda hardcoded kalit yöq', () => {
    const src = fs.readFileSync(EDGE_FUNCTION_PATH, 'utf-8');
    expect(src).toContain('Deno.env.get("GEMINI_API_KEY")');
    // Google API kalitlari AIza bilan boşlanadi — manba kodda bölmasligi şart
    expect(src).not.toMatch(/AIza[0-9A-Za-z_-]{10,}/);
  });

  it('3. Frontend servisi kalitni özi saqlamaydi — faqat Edge Function invoke qiladi', () => {
    const src = fs.readFileSync(SERVICE_PATH, 'utf-8');
    expect(src).toContain("supabase.functions.invoke('yolchi-tutor'");
    expect(src).not.toMatch(/AIza[0-9A-Za-z_-]{10,}/);
    expect(src).not.toContain('VITE_GEMINI');
  });

  it('4. generateLesson Edge fallback bayroğini buzmaydi (mislabel himoyasi)', () => {
    const src = fs.readFileSync(SERVICE_PATH, 'utf-8');
    expect(src).toContain('isDeterministicFallback: Boolean(data.isDeterministicFallback)');
    expect(src).not.toContain('isDeterministicFallback: false,');
  });

  it('5. Demo fallback xizmati özini fallback deb belgilaydi (isAiGenerated=false)', async () => {
    const demo = new DemoAITutorService();
    const res = await demo.generateLesson({
      courseId: 'course_math_01',
      skillId: 'skill_math_functions',
      topic: 'Funksiyalar',
      difficulty: 'easy',
    });
    expect(res.isAiGenerated).toBe(false);
    expect(res.isDeterministicFallback).toBe(true);
  });

  it('6. Supabase sozlanmagan muhitda Gemini servisi fallback qaytaradi va uni AI deb körsatmaydi', async () => {
    const service = new GeminiAITutorService();
    const res = await service.generateLesson({
      courseId: 'course_math_01',
      skillId: 'skill_math_functions',
      topic: 'Funksiyalar',
      difficulty: 'easy',
    });
    expect(res.title).toBeDefined();
    expect(res.steps.length).toBeGreaterThan(0);
    // Sozlanmagan muhitda faqat deterministik fallback qaytişi mumkin
    expect(res.isDeterministicFallback).toBe(true);
    expect(res.isAiGenerated).toBe(false);
  });
});
