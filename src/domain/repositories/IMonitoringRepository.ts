import {
  TeacherClass,
  DailyLearningStats,
  WeeklyActivityDay,
  StudentAlert,
  ChildSummary,
  ClassStudentSummary,
  TeacherInvitationSummary,
  UserRole,
} from '../entities/MonitoringEntities';

export interface IMonitoringRepository {
  // Role & Teacher Verification
  getUserRole(): Promise<UserRole>;
  setUserRole(role: UserRole): Promise<void>;
  redeemTeacherInvitationCode(code: string): Promise<{ success: boolean; schoolName?: string; message: string }>;
  claimFirstAdminRole(bootstrapKey?: string): Promise<{ success: boolean; message: string }>;

  // Teacher Invitation Management (Admin/Management)
  createTeacherInvitation(
    schoolName?: string,
    maxUses?: number,
    validityDays?: number
  ): Promise<{
    id: string;
    plainCode: string;
    codePrefix: string;
    schoolName: string;
    maxUses: number;
    expiresAt: string;
    message: string;
  }>;
  listTeacherInvitations(): Promise<TeacherInvitationSummary[]>;
  revokeTeacherInvitation(id: string): Promise<{ success: boolean; message: string }>;

  // Parent Features
  createParentLinkCode(): Promise<{ id: string; linkCode: string; expiresAt: string }>;
  getParentChildren(): Promise<ChildSummary[]>;
  getChildWeeklyStats(studentId: string): Promise<WeeklyActivityDay[]>;
  getChildAlerts(studentId: string): Promise<StudentAlert[]>;

  // Student Actions
  redeemParentLinkCode(code: string): Promise<{ success: boolean; parentName?: string; message: string }>;
  joinClassByCode(code: string): Promise<{ success: boolean; className?: string; subject?: string; message: string }>;
  getStudentLinkedParents(): Promise<{ parentId: string; parentName: string; linkedAt: string }[]>;
  getStudentJoinedClasses(): Promise<TeacherClass[]>;

  // Teacher Features
  createTeacherClass(name: string, subject?: string, gradeLevel?: string): Promise<TeacherClass>;
  getTeacherClasses(): Promise<TeacherClass[]>;
  getClassStudents(classId: string): Promise<ClassStudentSummary[]>;

  // Learning Session & Heartbeat
  recordHeartbeat(
    sessionId: string,
    courseId?: string,
    lessonId?: string,
    platform?: string
  ): Promise<{ addedSeconds: number; totalSeconds: number }>;
  getTodayDailyStats(userId?: string): Promise<DailyLearningStats | null>;
}
