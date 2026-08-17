export type UserRole = 'student' | 'parent' | 'teacher';

export interface ParentStudentLink {
  id: string;
  parentUserId: string;
  studentUserId?: string;
  linkCode: string;
  status: 'pending' | 'active' | 'revoked' | 'expired';
  expiresAt: string;
  createdAt: string;
}

export interface TeacherClass {
  id: string;
  teacherUserId: string;
  name: string;
  subject: string;
  gradeLevel: string;
  classCode: string;
  studentCount?: number;
  averageMastery?: number;
  createdAt: string;
}

export interface ClassMember {
  id: string;
  classId: string;
  studentUserId: string;
  status: 'active' | 'archived' | 'left';
  joinedAt: string;
}

export interface LearningSession {
  id: string;
  userId: string;
  courseId: string;
  lessonId?: string;
  startedAt: string;
  lastHeartbeatAt: string;
  endedAt?: string;
  activeSeconds: number;
  platform: 'web' | 'android' | 'ios';
}

export interface DailyLearningStats {
  id: string;
  userId: string;
  activityDate: string; // YYYY-MM-DD
  activeSeconds: number;
  lessonsCompleted: number;
  questionsAnswered: number;
  correctAnswers: number;
  accuracyPercent: number;
  xpEarned: number;
  overallScore: number;
}

export interface WeeklyActivityDay {
  dayName: string; // "Dushanba", "Seshanba", etc.
  dateStr: string;
  activeMinutes: number;
  lessonsCount: number;
  accuracyPercent: number;
}

export interface StudentAlert {
  id: string;
  userId: string;
  alertType: 'inactivity' | 'weak_topic' | 'score_drop' | 'goal_achieved' | 'streak_milestone';
  title: string;
  description: string;
  severity: 'info' | 'warning' | 'critical';
  metadata?: Record<string, unknown>;
  isResolved: boolean;
  createdAt: string;
}

export interface ChildSummary {
  studentId: string;
  firstName: string;
  lastName: string;
  displayName: string;
  avatarUrl?: string;
  todayActiveMinutes: number;
  overallScore: number;
  streakDays: number;
  xp: number;
  weakestSkillName: string;
  weakestSkillScore: number;
  strongestSkillName: string;
  strongestSkillScore: number;
  todayGoalMinutes: number;
  goalCompletionPercent: number;
  statusTitle: string;
  pedagogicalAdvice: string;
}

export interface ClassStudentSummary {
  studentId: string;
  name: string;
  email?: string;
  todayActiveMinutes: number;
  overallScore: number;
  completedLessonsCount: number;
  totalAttemptsCount: number;
  weakestSkillName: string;
  weakestSkillScore: number;
  status: 'Yaxshi' | 'Nazorat' | 'E’tibor' | 'A’lo';
  alertCount: number;
  lastActiveDate: string;
}
