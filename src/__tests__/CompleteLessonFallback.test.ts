import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const MIG = 'supabase/migrations/20261017000001_complete_lesson_reinforcement_exercise_fallback.sql';
const src = () => readFileSync(resolve(process.cwd(), MIG), 'utf-8');

describe('complete_lesson reinforcement_exercise fallback', () => {
  it('falls back to reinforcement_exercise->>id when no interactiveQuestion step carries one', () => {
    const s = src();
    expect(s).toContain("reinforcement_exercise->>'id'");
    expect(s).toMatch(/ARRAY\[l\.reinforcement_exercise->>'id'\]/);
    expect(s).toMatch(/cardinality\(v_questions\), 0\) = 0[\s\S]{0,300}reinforcement_exercise/);
  });

  it('keeps the existing interactiveQuestion and generated_lessons paths intact', () => {
    const s = src();
    expect(s).toContain("step->'interactiveQuestion'");
    expect(s).toContain("step->'interactive_question'");
    expect(s).toContain("questions->0->>'id'");
  });

  it('rejects when neither path yields a scorable question', () => {
    const s = src();
    expect(s).toContain("Darsning baholanadigan savollari topilmadi.");
    expect(s).toContain("Dars javoblari serverda tasdiqlanmagan.");
  });
});
