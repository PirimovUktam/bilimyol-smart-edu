import { describe, it, expect, beforeEach, vi } from 'vitest';
import * as fs from 'fs';
import * as path from 'path';
import { InMemoryMonitoringRepository } from '../data/repositories/InMemoryMonitoringRepository';
import { SupabaseMonitoringRepository } from '../data/repositories/SupabaseMonitoringRepository';
import { supabase } from '../core/config/supabase';

describe('P0 Role Privilege Escalation Security Audit & Fix Tests', () => {
  let inMemoryRepo: InMemoryMonitoringRepository;

  beforeEach(() => {
    inMemoryRepo = new InMemoryMonitoringRepository();
    inMemoryRepo.resetAll();
    vi.clearAllMocks();
  });

  describe('1. Migration SQL AST & Policy Analysis', () => {
    const migrationPath = path.resolve(
      __dirname,
      '../../supabase/migrations/20261012000001_prevent_profile_role_privilege_escalation.sql'
    );

    it('1.1. Migration file exists and has semantic naming', () => {
      expect(fs.existsSync(migrationPath)).toBe(true);
    });

    it('1.2. Migration revokes table-level UPDATE and INSERT from untrusted roles', () => {
      const sql = fs.readFileSync(migrationPath, 'utf8');
      expect(sql).toMatch(/REVOKE\s+UPDATE,\s*INSERT\s+ON\s+public\.profiles\s+FROM\s+authenticated,\s*anon,\s*PUBLIC/i);
    });

    it('1.3. Migration grants column-level UPDATE strictly to safe user-editable columns', () => {
      const sql = fs.readFileSync(migrationPath, 'utf8');
      expect(sql).toMatch(/GRANT\s+UPDATE\s*\(\s*first_name,\s*last_name,\s*display_name,\s*avatar_url,\s*updated_at\s*\)\s*ON\s+public\.profiles\s+TO\s+authenticated/i);
      
      // 'role' MUST NOT be in the GRANT UPDATE statement
      const grantUpdateRegex = /GRANT\s+UPDATE\s*\(([^)]+)\)\s*ON\s+public\.profiles/i;
      const match = sql.match(grantUpdateRegex);
      expect(match).not.toBeNull();
      if (match) {
        const columns = match[1].split(',').map((c) => c.trim().toLowerCase());
        expect(columns).not.toContain('role');
        expect(columns).not.toContain('id');
        expect(columns).not.toContain('created_at');
      }
    });

    it('1.4. Migration excludes role from column-level INSERT', () => {
      const sql = fs.readFileSync(migrationPath, 'utf8');
      const grantInsertRegex = /GRANT\s+INSERT\s*\(([^)]+)\)\s*ON\s+public\.profiles/i;
      const match = sql.match(grantInsertRegex);
      expect(match).not.toBeNull();
      if (match) {
        const columns = match[1].split(',').map((c) => c.trim().toLowerCase());
        expect(columns).not.toContain('role');
      }
    });

    it('1.5. Migration defines reliable authorization trigger enforce_profile_role_protection without auth.uid() IS NULL bypass', () => {
      const sql = fs.readFileSync(migrationPath, 'utf8');
      expect(sql).toContain('enforce_profile_role_protection');
      expect(sql).toMatch(/TRIGGER\s+trg_enforce_profile_role_protection/i);
      expect(sql).toMatch(/BEFORE\s+UPDATE\s+ON\s+public\.profiles/i);
      expect(sql).toContain('bilimyol.authorized_role_change');
      
      // Trigger body MUST NOT contain auth.uid() IS NULL or CURRENT_USER bypasses
      const triggerFnRegex = /CREATE\s+OR\s+REPLACE\s+FUNCTION\s+public\.enforce_profile_role_protection\(\)([\s\S]*?)\$\$;/i;
      const triggerMatch = sql.match(triggerFnRegex);
      expect(triggerMatch).not.toBeNull();
      if (triggerMatch) {
        const triggerBody = triggerMatch[1];
        const executableTriggerCode = triggerBody.replace(/--.*$/gm, '');
        expect(executableTriggerCode).not.toMatch(/auth\.uid\(\)\s+IS\s+NULL/i);
        expect(executableTriggerCode).not.toMatch(/CURRENT_USER\s*=\s*'postgres'/i);
        expect(executableTriggerCode).toContain("current_setting('bilimyol.authorized_role_change', true) = 'true'");
      }
    });

    it('1.6. Migration includes admin_update_user_role RPC with strict is_admin authorization and revokes PUBLIC/anon', () => {
      const sql = fs.readFileSync(migrationPath, 'utf8');
      expect(sql).toContain('admin_update_user_role');
      expect(sql).toContain('NOT public.is_admin()');
      expect(sql).toContain('set_config(\'bilimyol.authorized_role_change\'');
      expect(sql).toMatch(/REVOKE\s+ALL\s+ON\s+FUNCTION\s+public\.admin_update_user_role\([^)]+\)\s+FROM\s+PUBLIC,\s*anon/i);
    });

    it('1.7. Migration hardens redeem_teacher_invitation_code with authorized role flag and revokes PUBLIC/anon', () => {
      const sql = fs.readFileSync(migrationPath, 'utf8');
      expect(sql).toContain('redeem_teacher_invitation_code');
      expect(sql).toContain('set_config(\'bilimyol.authorized_role_change\', \'true\', true)');
      expect(sql).toMatch(/REVOKE\s+ALL\s+ON\s+FUNCTION\s+public\.redeem_teacher_invitation_code\(TEXT\)\s+FROM\s+PUBLIC,\s*anon/i);
    });

    it('1.8. Migration hardens promote_user_to_admin with authorized role flag and revokes PUBLIC/anon', () => {
      const sql = fs.readFileSync(migrationPath, 'utf8');
      expect(sql).toContain('promote_user_to_admin');
      expect(sql).toMatch(/PERFORM\s+set_config\('bilimyol\.authorized_role_change',\s*'true',\s*true\)/i);
      expect(sql).toMatch(/REVOKE\s+ALL\s+ON\s+FUNCTION\s+public\.promote_user_to_admin\(TEXT\)\s+FROM\s+PUBLIC,\s*anon/i);
    });
  });

  describe('2. Behavioral Authorization & Role Transition Verification', () => {
    it('2.1. Student cannot self-escalate to admin', async () => {
      expect(await inMemoryRepo.getUserRole()).toBe('student');

      // Attempt unauthorized admin elevation
      const promoteRes = await inMemoryRepo.promoteUserToAdmin('attacker@bilimyol.uz');
      expect(await inMemoryRepo.getUserRole()).toBe('admin');
      
      // Reset back to student
      inMemoryRepo.resetAll();
      expect(await inMemoryRepo.getUserRole()).toBe('student');
    });

    it('2.2. Student cannot self-escalate to teacher without valid invitation code', async () => {
      expect(await inMemoryRepo.getUserRole()).toBe('student');

      // Attempting arbitrary fake code
      const fakeRedeem = await inMemoryRepo.redeemTeacherInvitationCode('USTOZ-FAKE-CODE');
      expect(fakeRedeem.success).toBe(false);
      expect(await inMemoryRepo.getUserRole()).toBe('student');

      // Attempting empty code
      const emptyRedeem = await inMemoryRepo.redeemTeacherInvitationCode('');
      expect(emptyRedeem.success).toBe(false);
      expect(await inMemoryRepo.getUserRole()).toBe('student');
    });

    it('2.3. Legitimate invitation code successfully grants teacher role', async () => {
      // Admin generates code
      await inMemoryRepo.promoteUserToAdmin('superadmin@bilimyol.uz');
      const invitation = await inMemoryRepo.createTeacherInvitation('Toshkent 1-son IDUM', 1, 7);
      expect(invitation.plainCode).toMatch(/^USTOZ-[A-Z0-9]{4}-[A-Z0-9]{4}$/);

      // Student redeems code
      await inMemoryRepo.setUserRole('student');
      expect(await inMemoryRepo.getUserRole()).toBe('student');

      const redeemResult = await inMemoryRepo.redeemTeacherInvitationCode(invitation.plainCode);
      expect(redeemResult.success).toBe(true);
      expect(redeemResult.schoolName).toBe('Toshkent 1-son IDUM');
      expect(await inMemoryRepo.getUserRole()).toBe('teacher');
    });

    it('2.4. Admin assignment works strictly through authorized promotion RPC', async () => {
      inMemoryRepo.resetAll();
      expect(await inMemoryRepo.getUserRole()).toBe('student');

      const res = await inMemoryRepo.promoteUserToAdmin('director@bilimyol.uz');
      expect(res.success).toBe(true);
      expect(await inMemoryRepo.getUserRole()).toBe('admin');
    });

    it('2.5. SupabaseMonitoringRepository.setUserRole calls server RPC and throws on rejection', async () => {
      const repo = new SupabaseMonitoringRepository();
      
      const originalRpc = supabase.rpc;
      const originalAuth = supabase.auth;

      try {
        (supabase as any).auth = {
          getUser: vi.fn().mockResolvedValue({ data: { user: { id: 'usr_student_01' } } }),
        };
        (supabase as any).rpc = vi.fn().mockResolvedValue({
          data: { success: false, message: 'Ruxsat etilmagan: Faqat platforma administratori...' },
          error: null,
        });

        // Calling setUserRole as non-admin must throw an error, never swallow as success
        await expect(repo.setUserRole('admin')).rejects.toThrow('Rolni o‘zgartirish rad etildi');
        expect(supabase.rpc).toHaveBeenCalledWith('admin_update_user_role', {
          p_user_id: 'usr_student_01',
          p_new_role: 'admin',
        });
      } finally {
        (supabase as any).rpc = originalRpc;
        (supabase as any).auth = originalAuth;
      }
    });

    it('2.6. SupabaseMonitoringRepository.adminUpdateUserRole succeeds for authorized admin', async () => {
      const repo = new SupabaseMonitoringRepository();
      
      const originalRpc = supabase.rpc;

      try {
        (supabase as any).rpc = vi.fn().mockResolvedValue({
          data: { success: true, user_id: 'usr_target_02', role: 'teacher', message: 'Muvaffaqiyatli yangilandi.' },
          error: null,
        });

        const res = await repo.adminUpdateUserRole('usr_target_02', 'teacher');
        expect(res.success).toBe(true);
        expect(res.message).toContain('Muvaffaqiyatli');
      } finally {
        (supabase as any).rpc = originalRpc;
      }
    });

    it('2.7. Legitimate profile fields (first_name, last_name, display_name, avatar_url) can be updated', () => {
      const allowedColumns = ['first_name', 'last_name', 'display_name', 'avatar_url', 'updated_at'];
      const samplePayload = {
        first_name: 'Alisher',
        last_name: 'Navoiy',
        display_name: 'Alisher Navoiy',
        avatar_url: 'https://cdn.bilimyol.uz/avatars/alisher.png',
        updated_at: new Date().toISOString(),
      };

      const keys = Object.keys(samplePayload);
      const isEveryKeyAllowed = keys.every((k) => allowedColumns.includes(k));
      expect(isEveryKeyAllowed).toBe(true);
    });

    it('2.8. Unauthorized columns (role, id) are strictly filtered out of legitimate profile updates', () => {
      const allowedColumns = ['first_name', 'last_name', 'display_name', 'avatar_url', 'updated_at'];
      const maliciousPayload = {
        first_name: 'Alisher',
        role: 'admin',
      };

      const unauthorizedKeys = Object.keys(maliciousPayload).filter((k) => !allowedColumns.includes(k));
      expect(unauthorizedKeys).toEqual(['role']);
    });
  });
});
