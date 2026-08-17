import { describe, it, expect, beforeEach } from 'vitest';
import { InMemoryMonitoringRepository } from '../data/repositories/InMemoryMonitoringRepository';

describe('Parent + Teacher Learning Monitoring System Tests', () => {
  let monitoringRepo: InMemoryMonitoringRepository;

  beforeEach(() => {
    monitoringRepo = new InMemoryMonitoringRepository();
    monitoringRepo.resetAll();
  });

  it('A. Parent creates a 6-digit linking code with 24-hour expiration', async () => {
    const { linkCode, expiresAt } = await monitoringRepo.createParentLinkCode();

    expect(linkCode).toBeDefined();
    expect(linkCode.length).toBe(6);
    expect(new Date(expiresAt).getTime()).toBeGreaterThan(Date.now());
  });

  it('B. Student successfully redeems linking code to establish relationship', async () => {
    const { linkCode } = await monitoringRepo.createParentLinkCode();

    const redemption = await monitoringRepo.redeemParentLinkCode(linkCode);
    expect(redemption.success).toBe(true);
    expect(redemption.message).toContain('muvaffaqiyatli');

    // Attempting to redeem already activated or invalid code fails
    const invalidRedeem = await monitoringRepo.redeemParentLinkCode('INVALID');
    expect(invalidRedeem.success).toBe(false);
  });

  it('C. Parent dashboard displays child active study time and skill breakdown', async () => {
    const { linkCode } = await monitoringRepo.createParentLinkCode();
    await monitoringRepo.redeemParentLinkCode(linkCode);

    const children = await monitoringRepo.getParentChildren();
    expect(children.length).toBeGreaterThan(0);

    const child = children[0];
    expect(child.displayName).toBe('Azizbek Karimov');
    expect(child.todayActiveMinutes).toBe(37); // Pedagogical active study time
    expect(child.overallScore).toBe(76);
    expect(child.weakestSkillName).toBe('Funksiyalar');
    expect(child.weakestSkillScore).toBe(54);
    expect(child.pedagogicalAdvice).toContain('Funksiyalar');
  });

  it('D. Active study time calculation vs raw screen time verification', async () => {
    // 30 seconds of active interaction pulse
    const heartbeat = await monitoringRepo.recordHeartbeat('sess_01', 'course_math_01', 'lesson_01', 'web');
    expect(heartbeat.addedSeconds).toBe(30);

    const dailyStats = await monitoringRepo.getTodayDailyStats('student_01');
    expect(dailyStats).not.toBeNull();
    expect(dailyStats?.activeSeconds).toBe(1800); // 30 mins
  });

  it('E. Teacher creates class and receives unique class code', async () => {
    const newClass = await monitoringRepo.createTeacherClass('7-A Sinf', 'Matematika', '7-sinf');

    expect(newClass.id).toBeDefined();
    expect(newClass.name).toBe('7-A Sinf');
    expect(newClass.classCode).toBeDefined();
    expect(newClass.classCode.length).toBeGreaterThanOrEqual(4);
  });

  it('F. Student joins class by code and increments roster', async () => {
    const newClass = await monitoringRepo.createTeacherClass('8-B Algebra', 'Matematika', '8-sinf');

    const joinRes = await monitoringRepo.joinClassByCode(newClass.classCode);
    expect(joinRes.success).toBe(true);
    expect(joinRes.className).toBe('8-B Algebra');

    const classes = await monitoringRepo.getTeacherClasses();
    const target = classes.find((c) => c.id === newClass.id);
    expect(target?.studentCount).toBe(1);
  });

  it('G. Teacher dashboard displays student roster with mastery levels and alerts', async () => {
    const newClass = await monitoringRepo.createTeacherClass('7-A Sinf');
    const students = await monitoringRepo.getClassStudents(newClass.id);

    expect(students.length).toBe(3);
    const weakStudent = students.find((s) => s.status === 'E’tibor');
    expect(weakStudent).toBeDefined();
    expect(weakStudent?.overallScore).toBeLessThan(55);
    expect(weakStudent?.alertCount).toBeGreaterThan(0);
  });

  it('H. User role switching persists and changes context safely', async () => {
    expect(await monitoringRepo.getUserRole()).toBe('student');

    await monitoringRepo.setUserRole('parent');
    expect(await monitoringRepo.getUserRole()).toBe('parent');

    await monitoringRepo.setUserRole('teacher');
    expect(await monitoringRepo.getUserRole()).toBe('teacher');
  });
});
