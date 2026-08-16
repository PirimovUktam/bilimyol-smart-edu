import { create } from 'zustand';
import { Course } from '@/domain/entities/Course';
import { Skill } from '@/domain/entities/Skill';
import { inMemoryCourseRepository } from '@/data/repositories/InMemoryCourseRepository';

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
    const courses = await inMemoryCourseRepository.getAllCourses();
    const activeCourse = courses[0] || null;
    const skills = activeCourse ? await inMemoryCourseRepository.getSkillsByCourseId(activeCourse.id) : [];
    set({ courses, activeCourse, activeCourseSkills: skills, isLoading: false });
  },

  selectCourseById: async (courseId: string) => {
    const courses = get().courses.length > 0 ? get().courses : await inMemoryCourseRepository.getAllCourses();
    const activeCourse = courses.find((c) => c.id === courseId) || courses[0];
    const skills = activeCourse ? await inMemoryCourseRepository.getSkillsByCourseId(activeCourse.id) : [];
    set({ courses, activeCourse, activeCourseSkills: skills });
  },
}));
