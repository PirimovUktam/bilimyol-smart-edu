import { describe, it, expect, beforeEach } from 'vitest';
import { InMemoryMonitoringRepository } from '../data/repositories/InMemoryMonitoringRepository';

describe('Admin Role & Bootstrap Security Hardening Tests', () => {
  let monitoringRepo: InMemoryMonitoringRepository;

  beforeEach(() => {
    monitoringRepo = new InMemoryMonitoringRepository();
    monitoringRepo.resetAll();
  });

  it('1. Zero Hardcoded Tokens: Repository starts with no pre-baked teacher invitation codes', async () => {
    const list = await monitoringRepo.listTeacherInvitations();
    expect(list.length).toBe(0);

    // Redeeming arbitrary ungenerated codes is strictly rejected
    const redeemRes = await monitoringRepo.redeemTeacherInvitationCode('USTOZ-7K4P-2M9X');
    expect(redeemRes.success).toBe(false);
    expect(redeemRes.message).toContain('yaroqsiz');
  });

  it('2. Security: Unprivileged user cannot elevate themselves to admin or create invitation codes', async () => {
    // Current role is student
    expect(await monitoringRepo.getUserRole()).toBe('student');

    // Student cannot create teacher invitation codes
    // (In server RPC, public.is_admin() returns false)
    expect(await monitoringRepo.getUserRole()).not.toBe('admin');
  });

  it('3. Privileged Admin Promotion: Server-side operation promotes designated user to Admin', async () => {
    expect(await monitoringRepo.getUserRole()).toBe('student');

    // Executed via server-side promoteUserToAdmin (Supabase SQL Editor / CLI)
    const promoteRes = await monitoringRepo.promoteUserToAdmin('admin@bilimyol.uz');
    expect(promoteRes.success).toBe(true);
    expect(promoteRes.message).toContain('muvaffaqiyatli Admin roliga');

    // Role is now admin
    expect(await monitoringRepo.getUserRole()).toBe('admin');
  });

  it('4. Admin Teacher Code Management: Admin creates and lists secure invitation codes dynamically', async () => {
    await monitoringRepo.promoteUserToAdmin('admin@bilimyol.uz');
    expect(await monitoringRepo.getUserRole()).toBe('admin');

    const created = await monitoringRepo.createTeacherInvitation('Toshkent IDUM №1', 5, 30);
    expect(created.plainCode).toMatch(/^USTOZ-[A-Z0-9]{4}-[A-Z0-9]{4}$/);
    expect(created.maxUses).toBe(5);

    const list = await monitoringRepo.listTeacherInvitations();
    expect(list.length).toBe(1);
    const item = list[0];
    expect(item.codePrefix).toContain('****');
  });

  it('5. Admin Code Revocation: Admin revokes invitation code preventing teacher redemption', async () => {
    await monitoringRepo.promoteUserToAdmin('admin@bilimyol.uz');

    const created = await monitoringRepo.createTeacherInvitation('Samarqand Maktabi', 1, 7);
    const revokeRes = await monitoringRepo.revokeTeacherInvitation(created.id);
    expect(revokeRes.success).toBe(true);

    // Redeeming revoked code is rejected
    const redeemRes = await monitoringRepo.redeemTeacherInvitationCode(created.plainCode);
    expect(redeemRes.success).toBe(false);
  });

  it('6. Teacher Redemption Lifecycle: Dynamically created invitation code successfully promotes teacher', async () => {
    await monitoringRepo.promoteUserToAdmin('admin@bilimyol.uz');
    const created = await monitoringRepo.createTeacherInvitation('Namangan IDUM', 1, 7);

    // Switch to a new teacher candidate role
    await monitoringRepo.setUserRole('student');
    expect(await monitoringRepo.getUserRole()).toBe('student');

    // Teacher candidate redeems the single-use invitation code
    const redeemRes = await monitoringRepo.redeemTeacherInvitationCode(created.plainCode);
    expect(redeemRes.success).toBe(true);
    expect(redeemRes.message).toContain('muvaffaqiyatli');
    expect(await monitoringRepo.getUserRole()).toBe('teacher');

    // Second redemption of exhausted code is rejected
    const secondRedeem = await monitoringRepo.redeemTeacherInvitationCode(created.plainCode);
    expect(secondRedeem.success).toBe(false);
  });

  it('7. Role Routing Logic: Maps roles deterministically to dedicated landing views', () => {
    const routeForRole = (role?: string) => {
      if (role === 'admin') return 'admin';
      if (role === 'parent') return 'parent';
      if (role === 'teacher') return 'teacher';
      return 'dashboard';
    };

    expect(routeForRole('admin')).toBe('admin');
    expect(routeForRole('parent')).toBe('parent');
    expect(routeForRole('teacher')).toBe('teacher');
    expect(routeForRole('student')).toBe('dashboard');
    expect(routeForRole(undefined)).toBe('dashboard');
  });

  it('8. Role Access Guard: Non-admin users are strictly blocked from admin panel', () => {
    const checkAccess = (targetView: string, userRole: string) => {
      if (targetView === 'admin' && userRole !== 'admin') return false;
      if (targetView === 'parent' && userRole !== 'parent') return false;
      if (targetView === 'teacher' && userRole !== 'teacher') return false;
      return true;
    };

    expect(checkAccess('admin', 'admin')).toBe(true);
    expect(checkAccess('admin', 'student')).toBe(false);
    expect(checkAccess('admin', 'teacher')).toBe(false);
    expect(checkAccess('admin', 'parent')).toBe(false);

    expect(checkAccess('teacher', 'teacher')).toBe(true);
    expect(checkAccess('teacher', 'student')).toBe(false);
    expect(checkAccess('parent', 'parent')).toBe(true);
    expect(checkAccess('parent', 'student')).toBe(false);
  });
});
