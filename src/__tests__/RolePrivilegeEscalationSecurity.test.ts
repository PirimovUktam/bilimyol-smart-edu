import { describe, expect, it } from 'vitest';
import * as fs from 'fs';
import * as path from 'path';

const migrationPath = path.resolve(
  __dirname,
  '../../supabase/migrations/20261018000001_remove_parent_teacher_connections.sql'
);

describe('remaining role and retired-feature security contract', () => {
  const migration = () => fs.readFileSync(migrationPath, 'utf8');

  it('keeps only student and admin in the profile role constraint', () => {
    const sql = migration();
    expect(sql).toContain("CHECK (role IN ('student', 'admin'))");
    expect(sql).toContain("WHERE role IS NULL OR role NOT IN ('student', 'admin')");
  });

  it('keeps signup authoritative and learner-only', () => {
    const sql = migration();
    expect(sql).toContain("v_display_name");
    expect(sql).toMatch(/role,\s*created_at,\s*updated_at\s*\)[\s\S]*'student'/i);
    expect(sql).not.toMatch(/raw_user_meta_data->>['"]role['"]/i);
  });

  it('removes all retired relationship and invitation tables and RPCs', () => {
    const sql = migration();
    expect(sql).toContain('DROP TABLE IF EXISTS public.parent_student_links;');
    expect(sql).toContain('DROP TABLE IF EXISTS public.classes;');
    expect(sql).toContain('DROP TABLE IF EXISTS public.class_members;');
    expect(sql).toContain('DROP TABLE IF EXISTS public.teacher_invitation_codes;');
    expect(sql).toContain('DROP TABLE IF EXISTS public.student_alerts;');
    expect(sql).toContain('DROP FUNCTION IF EXISTS public.create_parent_link_code();');
    expect(sql).toContain('DROP FUNCTION IF EXISTS public.create_teacher_class(TEXT, TEXT, TEXT);');
    expect(sql).toContain('DROP FUNCTION IF EXISTS public.redeem_teacher_invitation_code(TEXT);');
  });

  it('preserves learner heartbeat storage while narrowing admin role mutation', () => {
    const sql = migration();
    expect(sql).toContain('learning_sessions and daily_learning_stats intentionally remain');
    expect(sql).toContain("IF v_clean_role NOT IN ('student', 'admin') THEN");
    expect(sql).toMatch(/REVOKE\s+ALL\s+ON\s+FUNCTION\s+public\.admin_update_user_role\(UUID, TEXT\)\s+FROM\s+PUBLIC, anon/i);
  });
});
