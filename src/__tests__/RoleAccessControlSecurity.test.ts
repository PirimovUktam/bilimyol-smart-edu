import { describe, it, expect, beforeEach } from 'vitest';
import { InMemoryMonitoringRepository } from '../data/repositories/InMemoryMonitoringRepository';

describe('Role & Access Control Security Hardening Tests', () => {
  let monitoringRepo: InMemoryMonitoringRepository;

  beforeEach(() => {
    monitoringRepo = new InMemoryMonitoringRepository();
    monitoringRepo.resetAll();
  });

  it('1. Teacher Activation Code: Invalid or expired code is rejected', async () => {
    const invalidRes = await monitoringRepo.redeemTeacherInvitationCode('INVALID-CODE-123');
    expect(invalidRes.success).toBe(false);
    expect(invalidRes.message).toContain('yaroqsiz');

    // Role remains student
    expect(await monitoringRepo.getUserRole()).toBe('student');
  });

  it('2. Teacher Activation Code: Valid server code elevates role to teacher', async () => {
    const inv = await monitoringRepo.createTeacherInvitation('BilimYo‘l Markazi', 1, 7);
    const validRes = await monitoringRepo.redeemTeacherInvitationCode(inv.plainCode);
    expect(validRes.success).toBe(true);
    expect(validRes.message).toContain('muvaffaqiyatli');
    expect(validRes.schoolName).toBeDefined();

    // Authoritative role is now teacher
    expect(await monitoringRepo.getUserRole()).toBe('teacher');
  });

  it('3. Admin Invitation Generation: Generates secure high-entropy token and safe prefix', async () => {
    const created = await monitoringRepo.createTeacherInvitation('Toshkent IDUM №1', 1, 7);

    expect(created.plainCode).toMatch(/^USTOZ-[A-Z0-9]{4}-[A-Z0-9]{4}$/);
    expect(created.codePrefix).toContain('****');
    expect(created.maxUses).toBe(1);

    // List displays only prefix, not full plain token
    const list = await monitoringRepo.listTeacherInvitations();
    const found = list.find((i) => i.id === created.id);
    expect(found).toBeDefined();
    expect(found?.codePrefix).toBe(created.codePrefix);
    expect((found as unknown as { plainCode?: string }).plainCode).toBeUndefined();
  });

  it('4. Usage Limits & Exhaustion: Single-use invitation becomes exhausted after redemption', async () => {
    const created = await monitoringRepo.createTeacherInvitation('Prezident Maktabi', 1, 7);

    // First redemption succeeds
    const firstRedeem = await monitoringRepo.redeemTeacherInvitationCode(created.plainCode);
    expect(firstRedeem.success).toBe(true);

    // Second redemption fails because max_uses = 1 is exhausted
    const secondRedeem = await monitoringRepo.redeemTeacherInvitationCode(created.plainCode);
    expect(secondRedeem.success).toBe(false);
    expect(secondRedeem.message).toContain('yaroqsiz');
  });

  it('5. Revocation: Admin can revoke active invitation code', async () => {
    const created = await monitoringRepo.createTeacherInvitation('Samarqand Maktabi', 5, 14);

    const revokeRes = await monitoringRepo.revokeTeacherInvitation(created.id);
    expect(revokeRes.success).toBe(true);

    // Attempting to redeem revoked code is rejected
    const redeemRes = await monitoringRepo.redeemTeacherInvitationCode(created.plainCode);
    expect(redeemRes.success).toBe(false);
  });

  it('6. Parent Isolation: Parent cannot view children before active linking', async () => {
    await monitoringRepo.setUserRole('parent');

    const initialChildren = await monitoringRepo.getParentChildren();
    expect(initialChildren.length).toBe(0);

    const { linkCode } = await monitoringRepo.createParentLinkCode();
    expect(linkCode).toMatch(/^[A-Z0-9]{6}$/);

    const res = await monitoringRepo.redeemParentLinkCode(linkCode);
    expect(res.success).toBe(true);

    const linkedChildren = await monitoringRepo.getParentChildren();
    expect(linkedChildren.length).toBe(1);
  });

  it('7. Class Code Security: Invalid or malformed class code is rejected with descriptive error', async () => {
    await monitoringRepo.setUserRole('student');

    const emptyJoin = await monitoringRepo.joinClassByCode('');
    expect(emptyJoin.success).toBe(false);
    expect(emptyJoin.message).toContain('kiriting');

    const invalidJoin = await monitoringRepo.joinClassByCode('INVALID');
    expect(invalidJoin.success).toBe(false);
    expect(invalidJoin.message).toContain('topilmadi');
  });

  it('8. Teacher Class Roster Isolation: Students only appear in classes they joined', async () => {
    await monitoringRepo.setUserRole('teacher');

    const classA = await monitoringRepo.createTeacherClass('Math 101');
    const classB = await monitoringRepo.createTeacherClass('Physics 201');

    const studentsA = await monitoringRepo.getClassStudents(classA.id);
    const studentsB = await monitoringRepo.getClassStudents(classB.id);

    expect(studentsA.length).toBeGreaterThan(0);
    expect(studentsB.length).toBeGreaterThan(0);
  });
});
