import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const MIG = 'supabase/migrations/20261015000001_followup_security_persistence_hardening.sql';
const src = () => readFileSync(resolve(process.cwd(), MIG), 'utf-8');

describe('server-authoritative XP hardening (complete_reinforcement / award_xp)', () => {
  it('complete_reinforcement ignores client p_xp_awarded and uses a server constant', () => {
    const s = src();
    expect(s).toContain('v_server_xp_awarded INT := 30');
    expect(s).toContain('v_server_xp_awarded, now()');
    // the client-supplied p_xp_awarded must not flow into persistence or award_xp
    expect(s).not.toMatch(/xp_awarded,\s*p_xp_awarded/);
    expect(s).not.toMatch(/award_xp\(p_xp_awarded/);
    expect(s).toMatch(/award_xp\(v_server_xp_awarded/);
  });

  it('complete_reinforcement requires a server-verified correct answer', () => {
    const s = src();
    expect(s).toContain("lesson_id = p_reinforcement_node_id");
    expect(s).toContain("AND question_id = p_question_id");
    expect(s).toMatch(/SELECT is_correct/);
    // U+2018/U+2019 curly apostrophe inside the SQL literal
    expect(s).toMatch(/tasdiqlanmagan/);
  });

  it('award_xp never trusts p_amount; derives amount from verified action_key', () => {
    const s = src();
    expect(s).toContain("answer_correct_");
    expect(s).toContain("placement_completed_");
    expect(s).toContain("reinforcement_completed_");
    expect(s).toContain("lesson_completed_");
    // p_amount is never written to gamification_events.xp_delta
    expect(s).not.toMatch(/xp_delta\)\s*VALUES \([^)]*p_amount/);
    expect(s).toMatch(/xp_delta\)\s*VALUES \(v_uid, p_action_key, v_amount\)/);
  });

  it('gamification_events is idempotent via (user_id, action_key) conflict', () => {
    const s = src();
    expect(s).toContain('ON CONFLICT (user_id, action_key) DO NOTHING');
    expect(s).toContain('uq_gamification_event_key');
  });

  it('advisory locks serialize reinforcement completion', () => {
    const s = src();
    expect(s).toMatch(/pg_advisory_xact_lock\(hashtextextended\('learning:' \|\| v_uid::TEXT, 0\)\)/);
    expect(s).toMatch(/pg_advisory_xact_lock\(\s*hashtextextended\(v_uid::TEXT \|\| ':' \|\| p_reinforcement_node_id/);
  });

  it('learner writes are revoked; only SECURITY DEFINER RPCs persist XP state', () => {
    const s = src();
    expect(s).toMatch(/REVOKE ALL ON FUNCTION public\.complete_reinforcement\(TEXT, TEXT, TEXT, TEXT, INT\) FROM PUBLIC, anon/);
    expect(s).toMatch(/GRANT EXECUTE ON FUNCTION public\.complete_reinforcement\(TEXT, TEXT, TEXT, TEXT, INT\) TO authenticated, service_role/);
    // reinforcement_attempts is in the blanket REVOKE ALL table list
    expect(s).toMatch(/public\.reinforcement_attempts/);
    expect(s).toMatch(/REVOKE ALL ON TABLE[\s\S]{0,700}public\.reinforcement_attempts[\s\S]{0,700}FROM PUBLIC, anon, authenticated/);
  });
});
