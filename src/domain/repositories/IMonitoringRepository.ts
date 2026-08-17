import {
  TeacherClass,
  DailyLearningStats,
  WeeklyActivityDay,
  StudentAlert,
  ChildSummary,
  ClassStudentSummary,
  UserRole,
} from '../entities/MonitoringEntities';

export interface IMonitoringRepository {
  // Role
  getUserRole(): Promise<UserRole>;
  setUserRole(role: UserRole): Promise<void>;

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
