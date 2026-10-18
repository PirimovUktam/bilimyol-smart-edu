import { create } from 'zustand';
import { Course } from '@/domain/entities/Course';
import { Skill } from '@/domain/entities/Skill';
import { supabaseCourseRepository } from '@/data/repositories/SupabaseCourseRepository';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { useRoadmapStore } from '@/app/store/useRoadmapStore';
import { useLessonStore } from '@/app/store/useLessonStore';
import { usePlacementStore } from '@/app/store/usePlacementStore';

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
  if (preferredId !== null) {
    const preferred = courses.find((c) => c.id === preferredId);
    return preferred || null;
  }
  return courses[0] || null;
};

interface CourseState {
  courses: Course[];
  activeCourse: Course | null;
  activeCourseSkills: Skill[];
  isLoading: boolean;
  error: string | null;
  loadCourses: () => Promise<void>;
  selectCourseById: (courseId: string) => Promise<void>;
  clearSession: () => void;
}

const courseSelectionError = (courseId: string): Error =>
  new Error(`Kurs topilmadi: "${courseId}". Mavjud kurslardan birini tanlang.`);

const invalidateCourseScopedState = (): void => {
  useRoadmapStore.getState().clearSession();
  useLessonStore.getState().clearSession();
  usePlacementStore.getState().resetPlacement();
};

export const useCourseStore = create<CourseState>((set, get) => {
  let currentOperation: object | null = null;

  return {
    courses: [],
    activeCourse: null,
    activeCourseSkills: [],
    isLoading: false,
    error: null,

    clearSession: () => {
      currentOperation = null;
      set({ courses: [], activeCourse: null, activeCourseSkills: [], isLoading: false, error: null });
    },

    loadCourses: async () => {
      const operation = {};
      currentOperation = operation;
      set({ isLoading: true, error: null });
      if (currentOperation !== operation) return;
      try {
        const courses = await supabaseCourseRepository.getAllCourses();
        if (currentOperation !== operation) return;
        // The server profile is authoritative once it is available. Local
        // storage is only the reload/offline fallback while the profile loads.
        const preferredId = useLearnerStore.getState().profile?.selectedCourseId || readPersistedCourseId();
        const activeCourse = resolveInitialCourse(courses, preferredId);
        const skills = activeCourse ? await supabaseCourseRepository.getSkillsByCourseId(activeCourse.id) : [];
        if (currentOperation !== operation) return;
        const previousCourseId = get().activeCourse?.id || null;
        if (previousCourseId !== (activeCourse?.id || null) && previousCourseId !== null) {
          invalidateCourseScopedState();
        }
        if (activeCourse) persistCourseId(activeCourse.id);
        set({ courses, activeCourse, activeCourseSkills: skills, isLoading: false, error: null });
      } catch (err) {
        if (currentOperation !== operation) return;
        set({ isLoading: false, error: err instanceof Error ? err.message : 'Kurslarni yuklashda xatolik yuz berdi.' });
        throw err;
      }
    },

    selectCourseById: async (courseId: string) => {
      const operation = {};
      currentOperation = operation;
      set({ isLoading: true, error: null });
      try {
        const courses = get().courses.length > 0 ? get().courses : await supabaseCourseRepository.getAllCourses();
        if (currentOperation !== operation) return;
        // A selection is valid only when it resolves to the exact canonical
        // course returned by the repository. Never silently substitute the
        // first course (which used to turn unknown ids into mathematics).
        const activeCourse = courses.find((course) => course.id === courseId);
        if (!activeCourse) {
          const error = courseSelectionError(courseId);
          set({ courses, isLoading: false, error: error.message });
          throw error;
        }
        const skills = await supabaseCourseRepository.getSkillsByCourseId(activeCourse.id);
        if (currentOperation !== operation) return;

        // Persist before committing the new active course. This keeps a
        // profile read that is already in flight from reverting a newer user
        // choice; the learner store also drops stale writes by operation.
        await useLearnerStore.getState().setSelectedCourse(activeCourse.id, () => currentOperation === operation);
        if (currentOperation !== operation) return;
        persistCourseId(activeCourse.id);
        if (currentOperation !== operation) return;

        const previousCourseId = get().activeCourse?.id || null;
        if (previousCourseId !== activeCourse.id) invalidateCourseScopedState();
        set({ courses, activeCourse, activeCourseSkills: skills, isLoading: false, error: null });
      } catch (err) {
        if (currentOperation !== operation) return;
        set({ isLoading: false, error: err instanceof Error ? err.message : 'Kursni tanlashda xatolik yuz berdi.' });
        throw err;
      }
    },
  };
});
