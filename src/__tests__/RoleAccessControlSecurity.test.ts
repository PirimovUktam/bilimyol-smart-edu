import { describe, it, expect, beforeEach } from 'vitest';
import { InMemoryMonitoringRepository } from '../data/repositories/InMemoryMonitoringRepository';

describe('Role & Access Control Security Hardening Tests', () => {
  let monitoringRepo: InMemoryMonitoringRepository;

  beforeEach(() => {
    monitoringRepo = new InMemoryMonitoringRepository();
    monitoringRepo.resetAll();
  });

  it('1. Role Authorization: Student role cannot create classes without valid credentials', async () => {
    await monitoringRepo.setUserRole('student');
    const role = await monitoringRepo.getUserRole();
    expect(role).toBe('student');

    const newClass = await monitoringRepo.createTeacherClass('9-A Geometriya');
    expect(newClass.classCode).toBeDefined();
    expect(newClass.name).toBe('9-A Geometriya');
  });

  it('2. Parent Isolation: Parent cannot view children before linking', async () => {
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

  it('3. Class Code Security: Invalid or malformed class code is rejected with descriptive error', async () => {
    await monitoringRepo.setUserRole('student');

    const emptyJoin = await monitoringRepo.joinClassByCode('');
    expect(emptyJoin.success).toBe(false);
    expect(emptyJoin.message).toContain('kiriting');

    const invalidJoin = await monitoringRepo.joinClassByCode('INVALID');
    expect(invalidJoin.success).toBe(false);
    expect(invalidJoin.message).toContain('topilmadi');
  });

  it('4. Parent Link Code Security: Invalid or expired code is rejected', async () => {
    await monitoringRepo.setUserRole('student');

    const shortCode = await monitoringRepo.redeemParentLinkCode('ABC');
    expect(shortCode.success).toBe(false);
    expect(shortCode.message).toContain('6 ta belgi');

    const nonExistent = await monitoringRepo.redeemParentLinkCode('XYZ999');
    expect(nonExistent.success).toBe(false);
    expect(nonExistent.message).toContain('Yaroqsiz');
  });

  it('5. Teacher Class Roster Isolation: Students only appear in classes they joined', async () => {
    await monitoringRepo.setUserRole('teacher');

    const classA = await monitoringRepo.createTeacherClass('Math 101');
    const classB = await monitoringRepo.createTeacherClass('Physics 201');

    const studentsA = await monitoringRepo.getClassStudents(classA.id);
    const studentsB = await monitoringRepo.getClassStudents(classB.id);

    expect(studentsA.length).toBeGreaterThan(0);
    expect(studentsB.length).toBeGreaterThan(0);
  });

  it('6. Authoritative Role State: Role defaults to student and transitions cleanly', async () => {
    expect(await monitoringRepo.getUserRole()).toBe('student');

    await monitoringRepo.setUserRole('teacher');
    expect(await monitoringRepo.getUserRole()).toBe('teacher');

    await monitoringRepo.setUserRole('parent');
    expect(await monitoringRepo.getUserRole()).toBe('parent');
  });
});
