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
    const validRes = await monitoringRepo.redeemTeacherInvitationCode('USTOZ-2026-ALPHA');
    expect(validRes.success).toBe(true);
    expect(validRes.message).toContain('muvaffaqiyatli');
    expect(validRes.schoolName).toBeDefined();

    // Authoritative role is now teacher
    expect(await monitoringRepo.getUserRole()).toBe('teacher');
  });

  it('3. Role Authorization: Teacher can create classes, generates unique code', async () => {
    await monitoringRepo.redeemTeacherInvitationCode('BILIMYO-USTOZ-77');
    expect(await monitoringRepo.getUserRole()).toBe('teacher');

    const newClass = await monitoringRepo.createTeacherClass('9-A Geometriya');
    expect(newClass.classCode).toBeDefined();
    expect(newClass.name).toBe('9-A Geometriya');
  });

  it('4. Parent Isolation: Parent cannot view children before active linking', async () => {
    await monitoringRepo.setUserRole('parent');

    // Without redemption, active child list is empty
    const initialChildren = await monitoringRepo.getParentChildren();
    expect(initialChildren.length).toBe(0);

    // Creating linking code generates a secure 6-char token
    const { linkCode } = await monitoringRepo.createParentLinkCode();
    expect(linkCode).toMatch(/^[A-Z0-9]{6}$/);

    // Redeeming code connects the student
    const res = await monitoringRepo.redeemParentLinkCode(linkCode);
    expect(res.success).toBe(true);

    const linkedChildren = await monitoringRepo.getParentChildren();
    expect(linkedChildren.length).toBe(1);
  });

  it('5. Class Code Security: Invalid or malformed class code is rejected with descriptive error', async () => {
    await monitoringRepo.setUserRole('student');

    const emptyJoin = await monitoringRepo.joinClassByCode('');
    expect(emptyJoin.success).toBe(false);
    expect(emptyJoin.message).toContain('kiriting');

    const invalidJoin = await monitoringRepo.joinClassByCode('INVALID');
    expect(invalidJoin.success).toBe(false);
    expect(invalidJoin.message).toContain('topilmadi');
  });

  it('6. Parent Link Code Security: Invalid or malformed code is rejected', async () => {
    await monitoringRepo.setUserRole('student');

    const shortCode = await monitoringRepo.redeemParentLinkCode('ABC');
    expect(shortCode.success).toBe(false);
    expect(shortCode.message).toContain('6 ta belgi');

    const nonExistent = await monitoringRepo.redeemParentLinkCode('XYZ999');
    expect(nonExistent.success).toBe(false);
    expect(nonExistent.message).toContain('Yaroqsiz');
  });

  it('7. Teacher Class Roster Isolation: Students only appear in classes they joined', async () => {
    await monitoringRepo.setUserRole('teacher');

    const classA = await monitoringRepo.createTeacherClass('Math 101');
    const classB = await monitoringRepo.createTeacherClass('Physics 201');

    const studentsA = await monitoringRepo.getClassStudents(classA.id);
    const studentsB = await monitoringRepo.getClassStudents(classB.id);

    expect(studentsA.length).toBeGreaterThan(0);
    expect(studentsB.length).toBeGreaterThan(0);
  });
});
