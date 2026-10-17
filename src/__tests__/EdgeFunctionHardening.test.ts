import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const EDGE = 'supabase/functions/yolchi-tutor/index.ts';
const src = () => readFileSync(resolve(process.cwd(), EDGE), 'utf-8');

describe('yolchi-tutor edge function hardening', () => {
  it('caps prompt-injection surface: courseId/skillId bounded to MAX_ID_LENGTH', () => {
    const s = src();
    expect(s).toContain('MAX_ID_LENGTH');
    // identifier fields are validated, not interpolated unbounded
    expect(s).toMatch(/idFields[\s\S]{0,200}courseId[\s\S]{0,200}skillId/);
    expect(s).toMatch(/length > MAX_ID_LENGTH/);
  });

  it('caps topic/skillName/misconceptionTitle text fields', () => {
    const s = src();
    for (const field of ['topic', 'skillName', 'misconceptionTitle']) {
      expect(s).toContain(`(payload as any).${field}`);
    }
    expect(s).toMatch(/length > MAX_TEXT_LENGTH/);
  });

  it('diagnose_mistake resolves correctOption server-side via questions table', () => {
    const s = src();
    expect(s).toContain('authoritativeCorrect');
    expect(s).toMatch(/from\("questions"\)[\s\S]{0,200}correct_index, options/);
    expect(s).not.toMatch(/payload\.correctOption \|\| 'Noma‘lum'/);
  });

  it('unmapped fallback question/course ids throw instead of silently keying option 0', () => {
    const s = src();
    // FALLBACK_CORRECT_INDEX lookup must not use `?? 0`
    expect(s).not.toContain('FALLBACK_CORRECT_INDEX[q.id] ?? 0');
    expect(s).not.toContain('FALLBACK_QUESTION_CORRECT_INDEX[courseId] ?? 0');
    // must surface an error for unmapped ids
    expect(s).toMatch(/javob kaliti topilmadi/);
    expect(s).toMatch(/correctIndex < 0 \|\| correctIndex > 3/);
  });

  it('generate_reinforcement requires explanation like generate_question', () => {
    const s = src();
    // reinforcement validation block should include !parsed.explanation
    expect(s).toMatch(/parsed\.correctIndex > 3 \|\|[\s\S]{0,60}!parsed\.explanation/);
  });

  it('does not log full Gemini error body (no res.text() on non-ok)', () => {
    const s = src();
    expect(s).not.toMatch(/returned status \$\{res\.status\}.*await res\.text\(\)/);
  });
});
