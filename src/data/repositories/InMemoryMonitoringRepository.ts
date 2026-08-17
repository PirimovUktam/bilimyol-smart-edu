import { IMonitoringRepository } from '../../domain/repositories/IMonitoringRepository';
import {
  ParentStudentLink,
  TeacherClass,
  ClassMember,
  DailyLearningStats,
  WeeklyActivityDay,
  StudentAlert,
  ChildSummary,
  ClassStudentSummary,
  TeacherInvitationSummary,
  UserRole,
} from '../../domain/entities/MonitoringEntities';

interface InMemoryTeacherInvitation {
  id: string;
  plainCode: string;
  codePrefix: string;
  schoolName: string;
  maxUses: number;
  usedCount: number;
  expiresAt: string;
  status: 'active' | 'expired' | 'revoked' | 'exhausted';
  createdAt: string;
}

export class InMemoryMonitoringRepository implements IMonitoringRepository {
  private currentRole: UserRole = 'student';
  private links: ParentStudentLink[] = [];
  private classes: TeacherClass[] = [];
  private classMembers: ClassMember[] = [];
  private dailyStats: Map<string, DailyLearningStats> = new Map();
  private alerts: Map<string, StudentAlert[]> = new Map();
  private teacherInvitations: InMemoryTeacherInvitation[] = [];

  async getUserRole(): Promise<UserRole> {
    return this.currentRole;
  }

  async setUserRole(role: UserRole): Promise<void> {
    this.currentRole = role;
  }

  async promoteUserToAdmin(_email: string): Promise<{ success: boolean; message: string }> {
    this.currentRole = 'admin';
    return {
      success: true,
      message: 'Foydalanuvchi muvaffaqiyatli Admin roliga o‘tkazildi.',
    };
  }

  async redeemTeacherInvitationCode(code: string): Promise<{ success: boolean; schoolName?: string; message: string }> {
    const cleanCode = code.trim().toUpperCase();
    if (!cleanCode) {
      return { success: false, message: 'O‘qituvchi tasdiqlash kodini kiriting.' };
    }

    const inv = this.teacherInvitations.find((i) => i.plainCode === cleanCode);
    if (!inv || inv.status !== 'active' || new Date(inv.expiresAt).getTime() <= Date.now() || inv.usedCount >= inv.maxUses) {
      return { success: false, message: 'Kiritilgan tasdiqlash kodi yaroqsiz yoki muddati tugagan.' };
    }

    inv.usedCount += 1;
    if (inv.usedCount >= inv.maxUses) {
      inv.status = 'exhausted';
    }

    this.currentRole = 'teacher';
    return {
      success: true,
      schoolName: inv.schoolName,
      message: 'O‘qituvchi hisobi muvaffaqiyatli tasdiqlandi va faollashtirildi!',
    };
  }

  async createTeacherInvitation(
    schoolName = 'BilimYo‘l Smart School',
    maxUses = 1,
    validityDays = 7
  ): Promise<{
    id: string;
    plainCode: string;
    codePrefix: string;
    schoolName: string;
    maxUses: number;
    expiresAt: string;
    message: string;
  }> {
    const part1 = Math.random().toString(36).substring(2, 6).toUpperCase();
    const part2 = Math.random().toString(36).substring(2, 6).toUpperCase();
    const plainCode = `USTOZ-${part1}-${part2}`;
    const codePrefix = `USTOZ-${part1}-****`;
    const id = 'inv_' + Math.random().toString(36).substring(2, 9);
    const expiresAt = new Date(Date.now() + validityDays * 24 * 3600 * 1000).toISOString();

    const newInv: InMemoryTeacherInvitation = {
      id,
      plainCode,
      codePrefix,
      schoolName,
      maxUses,
      usedCount: 0,
      expiresAt,
      status: 'active',
      createdAt: new Date().toISOString(),
    };

    this.teacherInvitations.unshift(newInv);

    return {
      id,
      plainCode,
      codePrefix,
      schoolName,
      maxUses,
      expiresAt,
      message: 'O‘qituvchi taklif kodi muvaffaqiyatli yaratildi.',
    };
  }

  async listTeacherInvitations(): Promise<TeacherInvitationSummary[]> {
    return this.teacherInvitations.map((i) => ({
      id: i.id,
      codePrefix: i.codePrefix,
      schoolName: i.schoolName,
      maxUses: i.maxUses,
      usedCount: i.usedCount,
      expiresAt: i.expiresAt,
      status: i.status,
      createdAt: i.createdAt,
    }));
  }

  async revokeTeacherInvitation(id: string): Promise<{ success: boolean; message: string }> {
    const inv = this.teacherInvitations.find((i) => i.id === id);
    if (!inv) {
      return { success: false, message: 'Taklif kodi topilmadi.' };
    }
    inv.status = 'revoked';
    return { success: true, message: 'Taklif kodi bekor qilindi.' };
  }

  async createParentLinkCode(): Promise<{ id: string; linkCode: string; expiresAt: string }> {
    const id = 'link_' + Math.random().toString(36).substring(2, 9);
    const linkCode = Math.random().toString(36).substring(2, 8).toUpperCase();
    const expiresAt = new Date(Date.now() + 24 * 3600 * 1000).toISOString();

    this.links.push({
      id,
      parentUserId: 'parent_user_01',
      linkCode,
      status: 'pending',
      expiresAt,
      createdAt: new Date().toISOString(),
    });

    return { id, linkCode, expiresAt };
  }

  async getParentChildren(): Promise<ChildSummary[]> {
    const activeLinks = this.links.filter((l) => l.status === 'active');
    if (activeLinks.length === 0) return [];

    return activeLinks.map((l, index) => ({
      studentId: l.studentUserId || `student_${index + 1}`,
      firstName: 'Azizbek',
      lastName: 'Karimov',
      displayName: 'Azizbek Karimov',
      todayActiveMinutes: 37,
      overallScore: 76,
      streakDays: 5,
      xp: 320,
      weakestSkillName: 'Funksiyalar',
      weakestSkillScore: 54,
      strongestSkillName: 'Algebra',
      strongestSkillScore: 82,
      todayGoalMinutes: 30,
      goalCompletionPercent: 100,
      statusTitle: 'Barqaror o‘rganmoqda',
      pedagogicalAdvice: 'Azizbek bugun 37 daqiqa faol shug‘ullandi. Funksiyalar mavzusida mustahkamlash tavsiya etiladi.',
    }));
  }

  async getChildWeeklyStats(_studentId: string): Promise<WeeklyActivityDay[]> {
    return [
      { dayName: 'Dushanba', dateStr: '2026-08-11', activeMinutes: 35, lessonsCount: 2, accuracyPercent: 80 },
      { dayName: 'Seshanba', dateStr: '2026-08-12', activeMinutes: 42, lessonsCount: 3, accuracyPercent: 78 },
      { dayName: 'Chorshanba', dateStr: '2026-08-13', activeMinutes: 28, lessonsCount: 1, accuracyPercent: 70 },
      { dayName: 'Payshanba', dateStr: '2026-08-14', activeMinutes: 51, lessonsCount: 4, accuracyPercent: 85 },
      { dayName: 'Juma', dateStr: '2026-08-15', activeMinutes: 42, lessonsCount: 3, accuracyPercent: 75 },
      { dayName: 'Shanba', dateStr: '2026-08-16', activeMinutes: 30, lessonsCount: 2, accuracyPercent: 80 },
      { dayName: 'Yakshanba', dateStr: '2026-08-17', activeMinutes: 37, lessonsCount: 2, accuracyPercent: 76 },
    ];
  }

  async getChildAlerts(studentId: string): Promise<StudentAlert[]> {
    return this.alerts.get(studentId) || [
      {
        id: 'alert_1',
        userId: studentId,
        alertType: 'weak_topic',
        title: 'Funksiyalar mavzusida qiyinchilik',
        description: 'So‘nggi 3 ta savolda xatolik kuzatildi (o‘zlashtirish 54%).',
        severity: 'warning',
        isResolved: false,
        createdAt: new Date().toISOString(),
      },
    ];
  }

  async redeemParentLinkCode(code: string): Promise<{ success: boolean; parentName?: string; message: string }> {
    const cleanCode = code.trim().toUpperCase();
    if (cleanCode.length !== 6) {
      return { success: false, message: 'Ulanish kodi 6 ta belgidan iborat bo‘lishi lozim.' };
    }

    const link = this.links.find((l) => l.linkCode === cleanCode && l.status === 'pending');
    if (!link) {
      return { success: false, message: 'Yaroqsiz yoki muddati o‘tgan kod.' };
    }

    link.status = 'active';
    link.studentUserId = 'current_student_user';

    return {
      success: true,
      parentName: 'Ota-ona',
      message: 'Ota-onaga muvaffaqiyatli ulandingiz!',
    };
  }

  async createTeacherClass(name: string, subject = 'Matematika', gradeLevel = '7-sinf'): Promise<TeacherClass> {
    const cleanName = name.trim();
    if (!cleanName) {
      throw new Error('Sinf nomi bo‘sh bo‘lishi mumkin emas.');
    }

    const id = 'class_' + Math.random().toString(36).substring(2, 9);
    const classCode = Math.random().toString(36).substring(2, 8).toUpperCase();
    const newClass: TeacherClass = {
      id,
      teacherUserId: 'teacher_user_01',
      name: cleanName,
      subject,
      gradeLevel,
      classCode,
      studentCount: 0,
      averageMastery: 72,
      createdAt: new Date().toISOString(),
    };
    this.classes.push(newClass);
    return newClass;
  }

  async getTeacherClasses(): Promise<TeacherClass[]> {
    return this.classes;
  }

  async joinClassByCode(code: string): Promise<{ success: boolean; className?: string; subject?: string; message: string }> {
    const cleanCode = code.trim().toUpperCase();
    if (!cleanCode) {
      return { success: false, message: 'Sinf kodini kiriting.' };
    }

    const targetClass = this.classes.find((c) => c.classCode === cleanCode);
    if (!targetClass) {
      return { success: false, message: 'Bunday sinf kodi topilmadi. Kodni tekshirib qayta kiriting.' };
    }

    this.classMembers.push({
      id: 'member_' + Math.random().toString(36).substring(2, 9),
      classId: targetClass.id,
      studentUserId: 'current_student_user',
      status: 'active',
      joinedAt: new Date().toISOString(),
    });

    targetClass.studentCount = (targetClass.studentCount || 0) + 1;

    return {
      success: true,
      className: targetClass.name,
      subject: targetClass.subject,
      message: `${targetClass.name} sinfiga muvaffaqiyatli qo‘shildingiz!`,
    };
  }

  async getStudentLinkedParents(): Promise<{ parentId: string; parentName: string; linkedAt: string }[]> {
    return this.links
      .filter((l) => l.status === 'active')
      .map((l) => ({
        parentId: l.parentUserId,
        parentName: 'Ota-ona',
        linkedAt: l.createdAt,
      }));
  }

  async getStudentJoinedClasses(): Promise<TeacherClass[]> {
    const memberClassIds = this.classMembers.map((m) => m.classId);
    return this.classes.filter((c) => memberClassIds.includes(c.id));
  }

  async getClassStudents(classId: string): Promise<ClassStudentSummary[]> {
    const members = this.classMembers.filter((m) => m.classId === classId);
    if (members.length === 0) {
      return [
        {
          studentId: 'stud_1',
          name: 'Ali Valiyev',
          email: 'ali@example.com',
          todayActiveMinutes: 43,
          overallScore: 82,
          completedLessonsCount: 4,
          totalAttemptsCount: 15,
          weakestSkillName: 'Grafiklar',
          weakestSkillScore: 75,
          status: 'Yaxshi',
          alertCount: 0,
          lastActiveDate: '2026-08-17',
        },
        {
          studentId: 'stud_2',
          name: 'Madina Rahimova',
          email: 'madina@example.com',
          todayActiveMinutes: 31,
          overallScore: 74,
          completedLessonsCount: 3,
          totalAttemptsCount: 12,
          weakestSkillName: 'Funksiyalar',
          weakestSkillScore: 62,
          status: 'Nazorat',
          alertCount: 1,
          lastActiveDate: '2026-08-17',
        },
        {
          studentId: 'stud_3',
          name: 'Aziz Karimov',
          email: 'aziz@example.com',
          todayActiveMinutes: 18,
          overallScore: 51,
          completedLessonsCount: 1,
          totalAttemptsCount: 6,
          weakestSkillName: 'Funksiyalar',
          weakestSkillScore: 48,
          status: 'E’tibor',
          alertCount: 2,
          lastActiveDate: '2026-08-17',
        },
      ];
    }

    return members.map((m, idx) => ({
      studentId: m.studentUserId,
      name: `O‘quvchi ${idx + 1}`,
      email: `student${idx + 1}@bilimyol.uz`,
      todayActiveMinutes: 35,
      overallScore: 75,
      completedLessonsCount: 2,
      totalAttemptsCount: 10,
      weakestSkillName: 'Algebra',
      weakestSkillScore: 60,
      status: 'Yaxshi',
      alertCount: 0,
      lastActiveDate: '2026-08-17',
    }));
  }

  async recordHeartbeat(
    _sessionId: string,
    _courseId = 'course_math_01',
    _lessonId?: string,
    _platform = 'web'
  ): Promise<{ addedSeconds: number; totalSeconds: number }> {
    return { addedSeconds: 30, totalSeconds: 300 };
  }

  async getTodayDailyStats(userId = 'current_user'): Promise<DailyLearningStats | null> {
    return (
      this.dailyStats.get(userId) || {
        id: 'ds_01',
        userId,
        activityDate: '2026-08-17',
        activeSeconds: 1800,
        lessonsCompleted: 2,
        questionsAnswered: 8,
        correctAnswers: 6,
        accuracyPercent: 75,
        xpEarned: 80,
        overallScore: 76,
      }
    );
  }

  resetAll(): void {
    this.currentRole = 'student';
    this.teacherInvitations = [];
    this.links = [];
    this.classes = [];
    this.classMembers = [];
    this.dailyStats.clear();
    this.alerts.clear();
  }
}
