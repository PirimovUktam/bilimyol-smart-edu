import { create } from 'zustand';
import {
  UserRole,
  ChildSummary,
  TeacherClass,
  ClassStudentSummary,
  WeeklyActivityDay,
  StudentAlert,
} from '../../domain/entities/MonitoringEntities';
import { IMonitoringRepository } from '../../domain/repositories/IMonitoringRepository';
import { SupabaseMonitoringRepository } from '../../data/repositories/SupabaseMonitoringRepository';

interface MonitoringState {
  currentRole: UserRole;
  isLoading: boolean;
  error: string | null;

  // Parent Data
  children: ChildSummary[];
  activeChild: ChildSummary | null;
  childWeeklyStats: WeeklyActivityDay[];
  childAlerts: StudentAlert[];
  generatedLinkCode: { code: string; expiresAt: string } | null;

  // Teacher Data
  classes: TeacherClass[];
  activeClass: TeacherClass | null;
  classStudents: ClassStudentSummary[];

  // Student Connections
  linkedParents: { parentId: string; parentName: string; linkedAt: string }[];
  joinedClasses: TeacherClass[];

  // Actions
  switchRole: (role: UserRole) => Promise<void>;
  fetchParentData: () => Promise<void>;
  selectChild: (studentId: string) => Promise<void>;
  createParentLinkCode: () => Promise<string>;
  fetchTeacherData: () => Promise<void>;
  selectClass: (classId: string) => Promise<void>;
  createTeacherClass: (name: string, subject?: string, gradeLevel?: string) => Promise<TeacherClass>;
  redeemParentLinkCode: (code: string) => Promise<{ success: boolean; message: string }>;
  joinClassByCode: (code: string) => Promise<{ success: boolean; message: string }>;
  fetchStudentConnections: () => Promise<void>;
}

const repository: IMonitoringRepository = new SupabaseMonitoringRepository();

export const useMonitoringStore = create<MonitoringState>((set, get) => ({
  currentRole: 'student',
  isLoading: false,
  error: null,

  children: [],
  activeChild: null,
  childWeeklyStats: [],
  childAlerts: [],
  generatedLinkCode: null,

  classes: [],
  activeClass: null,
  classStudents: [],

  linkedParents: [],
  joinedClasses: [],

  switchRole: async (role: UserRole) => {
    set({ currentRole: role, isLoading: true });
    try {
      await repository.setUserRole(role);
      if (role === 'parent') {
        await get().fetchParentData();
      } else if (role === 'teacher') {
        await get().fetchTeacherData();
      } else {
        await get().fetchStudentConnections();
      }
    } finally {
      set({ isLoading: false });
    }
  },

  fetchParentData: async () => {
    set({ isLoading: true, error: null });
    try {
      const children = await repository.getParentChildren();
      const firstChild = children.length > 0 ? children[0] : null;
      let weekly: WeeklyActivityDay[] = [];
      let alerts: StudentAlert[] = [];

      if (firstChild) {
        weekly = await repository.getChildWeeklyStats(firstChild.studentId);
        alerts = await repository.getChildAlerts(firstChild.studentId);
      }

      set({
        children,
        activeChild: firstChild,
        childWeeklyStats: weekly,
        childAlerts: alerts,
      });
    } catch (err: unknown) {
      set({ error: err instanceof Error ? err.message : 'Ota-ona ma’lumotlarini yuklab bo‘lmadi.' });
    } finally {
      set({ isLoading: false });
    }
  },

  selectChild: async (studentId: string) => {
    const child = get().children.find((c) => c.studentId === studentId);
    if (!child) return;

    set({ activeChild: child, isLoading: true });
    try {
      const weekly = await repository.getChildWeeklyStats(studentId);
      const alerts = await repository.getChildAlerts(studentId);
      set({ childWeeklyStats: weekly, childAlerts: alerts });
    } finally {
      set({ isLoading: false });
    }
  },

  createParentLinkCode: async () => {
    set({ isLoading: true });
    try {
      const { linkCode, expiresAt } = await repository.createParentLinkCode();
      set({ generatedLinkCode: { code: linkCode, expiresAt } });
      return linkCode;
    } finally {
      set({ isLoading: false });
    }
  },

  fetchTeacherData: async () => {
    set({ isLoading: true, error: null });
    try {
      const classes = await repository.getTeacherClasses();
      const firstClass = classes.length > 0 ? classes[0] : null;
      let students: ClassStudentSummary[] = [];

      if (firstClass) {
        students = await repository.getClassStudents(firstClass.id);
      }

      set({
        classes,
        activeClass: firstClass,
        classStudents: students,
      });
    } catch (err: unknown) {
      set({ error: err instanceof Error ? err.message : 'O‘qituvchi ma’lumotlarini yuklab bo‘lmadi.' });
    } finally {
      set({ isLoading: false });
    }
  },

  selectClass: async (classId: string) => {
    const targetClass = get().classes.find((c) => c.id === classId);
    if (!targetClass) return;

    set({ activeClass: targetClass, isLoading: true });
    try {
      const students = await repository.getClassStudents(classId);
      set({ classStudents: students });
    } finally {
      set({ isLoading: false });
    }
  },

  createTeacherClass: async (name: string, subject = 'Matematika', gradeLevel = '7-sinf') => {
    set({ isLoading: true });
    try {
      const newClass = await repository.createTeacherClass(name, subject, gradeLevel);
      const updatedClasses = [newClass, ...get().classes];
      set({
        classes: updatedClasses,
        activeClass: newClass,
        classStudents: [],
      });
      return newClass;
    } finally {
      set({ isLoading: false });
    }
  },

  redeemParentLinkCode: async (code: string) => {
    set({ isLoading: true });
    try {
      const res = await repository.redeemParentLinkCode(code);
      if (res.success) {
        await get().fetchStudentConnections();
      }
      return res;
    } finally {
      set({ isLoading: false });
    }
  },

  joinClassByCode: async (code: string) => {
    set({ isLoading: true });
    try {
      const res = await repository.joinClassByCode(code);
      if (res.success) {
        await get().fetchStudentConnections();
      }
      return res;
    } finally {
      set({ isLoading: false });
    }
  },

  fetchStudentConnections: async () => {
    try {
      const linkedParents = await repository.getStudentLinkedParents();
      const joinedClasses = await repository.getStudentJoinedClasses();
      set({ linkedParents, joinedClasses });
    } catch {
      // Non-blocking
    }
  },
}));
