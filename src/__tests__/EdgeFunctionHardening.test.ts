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
    expect(s).toContain('["courseId", "skillId", "questionId"]');
    expect(s).toMatch(/length <= MAX_ID_LENGTH/);
  });

  it('limits streamed request bytes and resolves catalogue topics on the server', () => {
    const s = src();
    expect(s).toContain('req.body?.getReader()');
    expect(s).toContain('bytes > MAX_REQUEST_BYTES');
    expect(s).toContain('topic: skill.name');
    expect(s).toContain('skillName: skill.name');
    expect(s).toMatch(/length <= MAX_TEXT_LENGTH/);
  });

  it('diagnose_mistake requires a verified persisted attempt for the authenticated identity', () => {
    const s = src();
    expect(s).toMatch(/rpc\("tutor_mistake_context",[\s\S]{0,150}p_user_id: user.id/);
    expect(s).toContain('if (!context) throw new TutorHttpError(403');
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

  it('supports a comma-separated APP_ORIGINS allowlist for prod+staging origins', () => {
    const s = src();
    expect(s).toContain('APP_ORIGINS');
    expect(s).toMatch(/split\(","\)/);
    // request-scoped CORS: echoes an allowed Origin, not a static single value
    expect(s).toMatch(/corsHeaders\(req/);
    expect(s).not.toMatch(/"Access-Control-Allow-Origin":\s*"?\*"?/);
  });
});
