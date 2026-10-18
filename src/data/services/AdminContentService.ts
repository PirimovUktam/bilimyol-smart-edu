import { supabase, isSupabaseConfigured } from '@/core/config/supabase';
import { Course } from '@/domain/entities/Course';
import { Skill } from '@/domain/entities/Skill';
import { Lesson } from '@/domain/entities/Lesson';
import { Question } from '@/domain/entities/Question';
import { SEED_COURSES } from '../datasources/courses';
import { SEED_SKILLS } from '../datasources/skills';
import { SEED_LESSONS } from '../datasources/lessons';
import { PLACEMENT_QUESTIONS } from '../datasources/questions';
import { mapCourseSubject } from '@/data/repositories/SupabaseCourseRepository';
import { isDemoRuntimeActive } from '@/core/runtime/demoRuntime';

export interface AdminLessonRecord extends Lesson {
  isPublished: boolean;
  isArchived: boolean;
  createdAt?: string;
  updatedAt?: string;
}

export interface AdminQuestionRecord extends Question {
  isPlacement?: boolean;
  createdAt?: string;
}

// In-memory fallbacks mutable stores
let inMemoryCourses: Course[] = [...SEED_COURSES];
let inMemorySkills: Skill[] = [...SEED_SKILLS];
let inMemoryLessons: AdminLessonRecord[] = Object.values(SEED_LESSONS).map((l) => ({
  ...l,
  isPublished: true,
  isArchived: false,
}));
let inMemoryQuestions: AdminQuestionRecord[] = [];
for (const [courseId, qList] of Object.entries(PLACEMENT_QUESTIONS)) {
  for (const q of qList) {
    inMemoryQuestions.push({
      ...q,
      courseId,
      isPlacement: true,
    });
  }
}

export class AdminContentService {
  // =========================================================================
  // 1. COURSES MANAGEMENT (FANLAR)
  // =========================================================================
  async getCourses(): Promise<Course[]> {
    if (!isSupabaseConfigured || isDemoRuntimeActive()) {
      return [...inMemoryCourses];
    }
    try {
      const { data, error } = await supabase
        .from('courses')
        .select('*')
        .order('created_at', { ascending: false });

      if (error || !data || data.length === 0) {
        return [...inMemoryCourses];
      }

      return data.map((c) => ({
        id: c.id,
        title: c.title,
        subject: mapCourseSubject({ id: c.id, subject: c.subject }),
        description: c.description || '',
        iconName: c.icon_name || 'BookOpen',
        primaryColor: c.primary_color_hex || '#4F46E5',
        secondaryColor: c.secondary_color_hex || '#818CF8',
        primaryColorHex: c.primary_color_hex || '#4F46E5',
        secondaryColorHex: c.secondary_color_hex || '#818CF8',
        skills: [],
        lessons: [],
        totalStudentsEstimate: c.total_students_estimate || 1000,
        isActive: c.is_active ?? true,
      }));
    } catch {
      return [...inMemoryCourses];
    }
  }

  async saveCourse(course: Partial<Course>): Promise<Course> {
    const id = course.id || `course_${Date.now()}`;
    const newCourse: Course = {
      id,
      title: course.title || 'Yangi Fan',
      subject: course.subject || 'other',
      description: course.description || '',
      iconName: course.iconName || 'BookOpen',
      primaryColor: course.primaryColor || course.primaryColorHex || '#4F46E5',
      secondaryColor: course.secondaryColor || course.secondaryColorHex || '#818CF8',
      primaryColorHex: course.primaryColorHex || course.primaryColor || '#4F46E5',
      secondaryColorHex: course.secondaryColorHex || course.secondaryColor || '#818CF8',
      skills: course.skills || [],
      lessons: course.lessons || [],
      totalStudentsEstimate: course.totalStudentsEstimate || 100,
      isActive: course.isActive ?? true,
    };

    if (isSupabaseConfigured && !isDemoRuntimeActive()) {
      const { error } = await supabase.from('courses').upsert({
        id: newCourse.id,
        title: newCourse.title,
        description: newCourse.description,
        icon_name: newCourse.iconName,
        primary_color_hex: newCourse.primaryColorHex || newCourse.primaryColor,
        secondary_color_hex: newCourse.secondaryColorHex || newCourse.secondaryColor,
        total_students_estimate: newCourse.totalStudentsEstimate,
        is_active: newCourse.isActive,
      });
      if (error) throw new Error(`Fan saqlashda xatolik: ${error.message}`);
    }

    // Update in-memory
    const idx = inMemoryCourses.findIndex((c) => c.id === id);
    if (idx >= 0) inMemoryCourses[idx] = newCourse;
    else inMemoryCourses.unshift(newCourse);

    return newCourse;
  }

  async deleteCourse(courseId: string): Promise<void> {
    if (isSupabaseConfigured && !isDemoRuntimeActive()) {
      const { error } = await supabase.from('courses').delete().eq('id', courseId);
      if (error) throw new Error(`Fanni o‘chirishda xatolik: ${error.message}`);
    }
    inMemoryCourses = inMemoryCourses.filter((c) => c.id !== courseId);
  }

  // =========================================================================
  // 2. SKILLS MANAGEMENT (KO‘NIKMALAR VA MAVZULAR)
  // =========================================================================
  async getSkills(courseId?: string): Promise<Skill[]> {
    if (!isSupabaseConfigured || isDemoRuntimeActive()) {
      return courseId ? inMemorySkills.filter((s) => s.courseId === courseId) : [...inMemorySkills];
    }
    try {
      let query = supabase.from('skills').select('*').order('order_index', { ascending: true });
      if (courseId) {
        query = query.eq('course_id', courseId);
      }
      const { data, error } = await query;
      if (error || !data || data.length === 0) {
        return courseId ? inMemorySkills.filter((s) => s.courseId === courseId) : [...inMemorySkills];
      }
      return data.map((s) => ({
        id: s.id,
        courseId: s.course_id,
        name: s.name,
        code: s.code,
        description: s.description || '',
        order: s.order_index ?? 0,
        orderIndex: s.order_index,
        iconName: s.icon_name || 'Target',
      }));
    } catch {
      return courseId ? inMemorySkills.filter((s) => s.courseId === courseId) : [...inMemorySkills];
    }
  }

  async saveSkill(skill: Partial<Skill>): Promise<Skill> {
    const id = skill.id || `skill_${Date.now()}`;
    const newSkill: Skill = {
      id,
      courseId: skill.courseId || 'course_math_01',
      name: skill.name || 'Yangi Ko‘nikma',
      code: skill.code || 'SKILL_NEW',
      description: skill.description || '',
      order: skill.order ?? skill.orderIndex ?? (inMemorySkills.length + 1),
      orderIndex: skill.orderIndex ?? skill.order ?? (inMemorySkills.length + 1),
      iconName: skill.iconName || 'Target',
    };

    if (isSupabaseConfigured && !isDemoRuntimeActive()) {
      const { error } = await supabase.from('skills').upsert({
        id: newSkill.id,
        course_id: newSkill.courseId,
        name: newSkill.name,
        code: newSkill.code,
        description: newSkill.description,
        order_index: newSkill.orderIndex ?? newSkill.order,
        icon_name: newSkill.iconName,
      });
      if (error) throw new Error(`Ko‘nikma saqlashda xatolik: ${error.message}`);
    }

    const idx = inMemorySkills.findIndex((s) => s.id === id);
    if (idx >= 0) inMemorySkills[idx] = newSkill;
    else inMemorySkills.push(newSkill);

    return newSkill;
  }

  async deleteSkill(skillId: string): Promise<void> {
    if (isSupabaseConfigured && !isDemoRuntimeActive()) {
      const { error } = await supabase.from('skills').delete().eq('id', skillId);
      if (error) throw new Error(`Ko‘nikmani o‘chirishda xatolik: ${error.message}`);
    }
    inMemorySkills = inMemorySkills.filter((s) => s.id !== skillId);
  }

  // =========================================================================
  // 3. LESSONS MANAGEMENT (DARSLAR VA MATERIALLAR)
  // =========================================================================
  async getLessons(courseId?: string): Promise<AdminLessonRecord[]> {
    if (!isSupabaseConfigured || isDemoRuntimeActive()) {
      return courseId ? inMemoryLessons.filter((l) => l.courseId === courseId) : [...inMemoryLessons];
    }
    // Learner access uses learner_lessons; CMS reads use the role-gated view
    // so answer-key JSON never travels to ordinary authenticated clients.
    let query = supabase.from('admin_lessons').select('*').order('created_at', { ascending: false });
    if (courseId) {
      query = query.eq('course_id', courseId);
    }
    const { data, error } = await query;
    if (error) throw new Error(`Darslarni yuklashda xatolik: ${error.message}`);
    if (!data) return [];
    return data.map((l) => ({
        id: l.id,
        courseId: l.course_id,
        skillId: l.skill_id,
        title: l.title,
        estimatedMinutes: l.estimated_minutes || 15,
        summary: l.summary || '',
        steps: Array.isArray(l.steps) ? l.steps : [],
        reinforcementExercise: l.reinforcement_exercise || {
          id: `q_reinf_${l.id}`,
          courseId: l.course_id,
          skillId: l.skill_id,
          text: 'Mavzuni to‘liq o‘zlashtirdingizmi?',
          options: ['Ha, to‘liq', 'Qisman', 'Yana takrorlash kerak', 'Boshqatdan'],
          difficulty: 'medium',
          explanation: 'Mustahkamlash savoli',
        },
        isPublished: l.is_published ?? true,
        isArchived: l.is_archived ?? false,
        createdAt: l.created_at,
        updatedAt: l.updated_at,
    }));
  }

  async saveLesson(lesson: Partial<AdminLessonRecord>): Promise<AdminLessonRecord> {
    const id = lesson.id || `lesson_${Date.now()}`;
    const newLesson: AdminLessonRecord = {
      id,
      courseId: lesson.courseId || 'course_math_01',
      skillId: lesson.skillId || 'skill_math_functions',
      title: lesson.title || 'Yangi Dars',
      estimatedMinutes: lesson.estimatedMinutes || 15,
      summary: lesson.summary || '',
      steps: lesson.steps && lesson.steps.length > 0 ? lesson.steps : [
        {
          id: `step_${Date.now()}_1`,
          stepNumber: 1,
          type: 'concept',
          title: 'Asosiy tushuncha',
          content: 'Darsning nazariy qismi...',
        },
      ],
      reinforcementExercise: lesson.reinforcementExercise || {
        id: `q_reinf_${id}`,
        courseId: lesson.courseId || 'course_math_01',
        skillId: lesson.skillId || 'skill_math_functions',
        text: 'Mavzuni to‘liq o‘zlashtirdingizmi?',
        options: ['Ha, to‘liq', 'Qisman', 'Yana takrorlash kerak', 'Boshqatdan'],
        difficulty: 'medium',
        explanation: 'Mustahkamlash savoli',
      },
      isPublished: lesson.isPublished ?? true,
      isArchived: lesson.isArchived ?? false,
      updatedAt: new Date().toISOString(),
    };

    if (isSupabaseConfigured && !isDemoRuntimeActive()) {
      const { data, error } = await supabase.rpc('admin_save_lesson', { p_lesson: {
        id: newLesson.id,
        course_id: newLesson.courseId,
        skill_id: newLesson.skillId,
        title: newLesson.title,
        summary: newLesson.summary,
        estimated_minutes: newLesson.estimatedMinutes,
        steps: newLesson.steps,
        reinforcement_exercise: newLesson.reinforcementExercise || null,
        is_published: newLesson.isPublished,
        is_archived: newLesson.isArchived,
        updated_at: newLesson.updatedAt,
      } });
      if (error || data?.saved !== true) throw new Error(`Darsni saqlashda xatolik: ${error?.message || 'Server saqlashni tasdiqlamadi.'}`);
    }

    const idx = inMemoryLessons.findIndex((l) => l.id === id);
    if (idx >= 0) inMemoryLessons[idx] = newLesson;
    else inMemoryLessons.unshift(newLesson);

    return newLesson;
  }

  async toggleLessonPublish(lessonId: string, isPublished: boolean): Promise<void> {
    if (isSupabaseConfigured && !isDemoRuntimeActive()) {
      const { error } = await supabase
        .from('lessons')
        .update({ is_published: isPublished, updated_at: new Date().toISOString() })
        .eq('id', lessonId);
      if (error) throw new Error(`Nashr holatini o‘zgartirishda xatolik: ${error.message}`);
    }
    const l = inMemoryLessons.find((item) => item.id === lessonId);
    if (l) l.isPublished = isPublished;
  }

  async toggleLessonArchive(lessonId: string, isArchived: boolean): Promise<void> {
    if (isSupabaseConfigured && !isDemoRuntimeActive()) {
      const { error } = await supabase
        .from('lessons')
        .update({ is_archived: isArchived, updated_at: new Date().toISOString() })
        .eq('id', lessonId);
      if (error) throw new Error(`Arxiv holatini o‘zgartirishda xatolik: ${error.message}`);
    }
    const l = inMemoryLessons.find((item) => item.id === lessonId);
    if (l) l.isArchived = isArchived;
  }

  async deleteLesson(lessonId: string): Promise<void> {
    if (isSupabaseConfigured && !isDemoRuntimeActive()) {
      const { error } = await supabase.from('lessons').delete().eq('id', lessonId);
      if (error) throw new Error(`Darsni o‘chirishda xatolik: ${error.message}`);
    }
    inMemoryLessons = inMemoryLessons.filter((l) => l.id !== lessonId);
  }

  // =========================================================================
  // 4. QUESTIONS MANAGEMENT (SAVOLLAR VA TESTLAR)
  // =========================================================================
  async getQuestions(courseId?: string, skillId?: string): Promise<AdminQuestionRecord[]> {
    if (!isSupabaseConfigured || isDemoRuntimeActive()) {
      return inMemoryQuestions.filter((q) => {
        if (courseId && q.courseId !== courseId) return false;
        if (skillId && q.skillId !== skillId) return false;
        return true;
      });
    }
    // Answer keys are exposed only through the admin-only security-definer
    // view; learner-facing question reads never receive correct_index.
    let query = supabase.from('admin_questions').select('*').order('created_at', { ascending: false });
    if (courseId) query = query.eq('course_id', courseId);
    if (skillId) query = query.eq('skill_id', skillId);

    const { data, error } = await query;
    if (error) throw new Error(`Savollarni yuklashda xatolik: ${error.message}`);
    if (!data) return [];

    return data.map((q) => ({
        id: q.id,
        courseId: q.course_id,
        skillId: q.skill_id,
        text: q.text,
        options: Array.isArray(q.options) ? q.options : [],
        correctIndex: q.correct_index,
        difficulty: q.difficulty || 'medium',
        explanation: q.explanation || '',
        formulaLatex: q.formula_latex || undefined,
        isPlacement: q.is_placement ?? false,
        createdAt: q.created_at,
    }));
  }

  async saveQuestion(question: Partial<AdminQuestionRecord>): Promise<AdminQuestionRecord> {
    const id = question.id || `q_${Date.now()}`;
    const newQuestion: AdminQuestionRecord = {
      id,
      courseId: question.courseId || 'course_math_01',
      skillId: question.skillId || 'skill_math_algebra',
      text: question.text || 'Savol matni',
      options: question.options && question.options.length === 4 ? question.options : ['Variant 1', 'Variant 2', 'Variant 3', 'Variant 4'],
      correctIndex: typeof question.correctIndex === 'number' ? question.correctIndex : 0,
      difficulty: question.difficulty || 'medium',
      explanation: question.explanation || 'Pedagogik tushuntirish va to‘g‘ri yechim.',
      formulaLatex: question.formulaLatex || undefined,
      isPlacement: question.isPlacement ?? false,
    };

    if (isSupabaseConfigured && !isDemoRuntimeActive()) {
      const { data, error } = await supabase.rpc('admin_save_question', { p_question: {
        id: newQuestion.id,
        course_id: newQuestion.courseId,
        skill_id: newQuestion.skillId,
        text: newQuestion.text,
        options: newQuestion.options,
        correct_index: newQuestion.correctIndex,
        difficulty: newQuestion.difficulty,
        explanation: newQuestion.explanation,
        formula_latex: newQuestion.formulaLatex || null,
        is_placement: newQuestion.isPlacement,
      } });
      if (error || data?.saved !== true) throw new Error(`Savolni saqlashda xatolik: ${error?.message || 'Server saqlashni tasdiqlamadi.'}`);
    }

    const idx = inMemoryQuestions.findIndex((q) => q.id === id);
    if (idx >= 0) inMemoryQuestions[idx] = newQuestion;
    else inMemoryQuestions.unshift(newQuestion);

    return newQuestion;
  }

  async deleteQuestion(questionId: string): Promise<void> {
    if (isSupabaseConfigured && !isDemoRuntimeActive()) {
      const { error } = await supabase.from('questions').delete().eq('id', questionId);
      if (error) throw new Error(`Savolni o‘chirishda xatolik: ${error.message}`);
    }
    inMemoryQuestions = inMemoryQuestions.filter((q) => q.id !== questionId);
  }
}

export const adminContentService = new AdminContentService();
