import { create } from 'zustand';
import { Course } from '@/domain/entities/Course';
import { Skill } from '@/domain/entities/Skill';
import { supabaseCourseRepository } from '@/data/repositories/SupabaseCourseRepository';
import { useLearnerStore } from '@/app/store/useLearnerStore';

/**
 * Single source of truth for the active course:
 * - server: learner_profiles.selected_course_id (via useLearnerStore)
 * - local cache: localStorage (instant restore after reload, offline fallback)
 * activeCourse in this store is derived from those sources, never from courses[0].
 */
export const ACTIVE_COURSE_STORAGE_KEY = 'bilimyol_active_course_id';

const readPersistedCourseId = (): string | null => {
  try {
    if (typeof localStorage === 'undefined') return null;
    return localStorage.getItem(ACTIVE_COURSE_STORAGE_KEY);
  } catch {
    return null;
  }
};

const persistCourseId = (courseId: string): void => {
  try {
    if (typeof localStorage === 'undefined') return;
    localStorage.setItem(ACTIVE_COURSE_STORAGE_KEY, courseId);
  } catch {
    /* storage unavailable — server profile remains the source of truth */
  }
};

export const resolveInitialCourse = (courses: Course[], preferredId: string | null): Course | null => {
  if (preferredId) {
    const preferred = courses.find((c) => c.id === preferredId);
    if (preferred) return preferred;
  }
  return courses[0] || null;
};

interface CourseState {
  courses: Course[];
  activeCourse: Course | null;
  activeCourseSkills: Skill[];
  isLoading: boolean;
  loadCourses: () => Promise<void>;
  selectCourseById: (courseId: string) => Promise<void>;
}

export const useCourseStore = create<CourseState>((set, get) => ({
  courses: [],
  activeCourse: null,
  activeCourseSkills: [],
  isLoading: false,

  loadCourses: async () => {
    set({ isLoading: true });
    const courses = await supabaseCourseRepository.getAllCourses();
    const preferredId = readPersistedCourseId();
    const activeCourse = resolveInitialCourse(courses, preferredId);
    const skills = activeCourse ? await supabaseCourseRepository.getSkillsByCourseId(activeCourse.id) : [];
    set({ courses, activeCourse, activeCourseSkills: skills, isLoading: false });
  },

  selectCourseById: async (courseId: string) => {
    const courses = get().courses.length > 0 ? get().courses : await supabaseCourseRepository.getAllCourses();
    const activeCourse = courses.find((c) => c.id === courseId) || courses[0];
    if (!activeCourse) return;
    const skills = await supabaseCourseRepository.getSkillsByCourseId(activeCourse.id);
    set({ courses, activeCourse, activeCourseSkills: skills });
    persistCourseId(activeCourse.id);
    try {
      await useLearnerStore.getState().setSelectedCourse(activeCourse.id);
    } catch (err) {
      console.warn('[useCourseStore] selected course persistence failed:', err);
    }
  },
}));
