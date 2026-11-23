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
import { updatedCourseText, updatedUzbekSpelling } from '@/core/locales/uzbekAlphabet';

export interface AdminLessonRecord extends Omit<Lesson, 'reinforcementExercise'> {
  reinforcementExercise: Lesson['reinforcementExercise'] | null;
  isPublished: boolean;
  isArchived: boolean;
  createdAt?: string;
  updatedAt?: string;
}

export interface AdminQuestionRecord extends Question {
  isPlacement?: boolean;
  createdAt?: string;
}

const pageSize = 20;
function pageOf<T>(rows: T[]) {
  return { rows: rows.slice(0, pageSize), hasMore: rows.length > pageSize };
}
function demoPage<T>(rows: T[], page: number) {
  return pageOf(rows.slice(page * pageSize, (page + 1) * pageSize + 1));
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
    const { data, error } = await supabase.from('courses').select('*').order('created_at', { ascending: false });
    if (error) throw new Error('Fanlarni serverdan yuklab bölmadi.');
    return (data ?? []).map((c) => ({
        id: c.id,
        title: updatedUzbekSpelling(c.title),
        subject: mapCourseSubject({ id: c.id, subject: c.subject }),
        description: updatedUzbekSpelling(c.description || ''),
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
        subject: newCourse.subject,
        description: newCourse.description,
        icon_name: newCourse.iconName,
        primary_color_hex: newCourse.primaryColorHex || newCourse.primaryColor,
        secondary_color_hex: newCourse.secondaryColorHex || newCourse.secondaryColor,
        total_students_estimate: newCourse.totalStudentsEstimate,
        is_active: newCourse.isActive,
      });
      if (error) throw new Error(`Fan saqlaşda xatolik: ${error.message}`);
      return newCourse;
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
      if (error) throw new Error(`Fanni öçirişda xatolik: ${error.message}`);
      return;
    }
    inMemoryCourses = inMemoryCourses.filter((c) => c.id !== courseId);
  }

  // =========================================================================
  // 2. SKILLS MANAGEMENT (KÖNIKMALAR VA MAVZULAR)
  // =========================================================================
  async getSkills(courseId: string, page = 0) {
    if (!isSupabaseConfigured || isDemoRuntimeActive()) {
      return demoPage(inMemorySkills.filter((s) => s.courseId === courseId), page);
    }
    const { data, error } = await supabase.from('skills')
      .select('id,course_id,name,code,description,order_index,icon_name')
      .eq('course_id', courseId).order('order_index').order('id')
      .range(page * pageSize, (page + 1) * pageSize);
    if (error && error.code !== 'PGRST103') throw new Error(error.message);
    return pageOf<Skill>((data ?? []).map((s) => ({
        id: s.id,
        courseId: s.course_id,
        name: updatedUzbekSpelling(s.name),
        code: s.code,
        description: updatedUzbekSpelling(s.description || ''),
        order: s.order_index ?? 0,
        orderIndex: s.order_index,
        iconName: s.icon_name || 'Target',
    })));
  }

  async getSkillOptions(courseId: string): Promise<Pick<Skill, 'id' | 'name'>[]> {
    if (!isSupabaseConfigured || isDemoRuntimeActive()) {
      return inMemorySkills.filter((skill) => skill.courseId === courseId);
    }
    const rows: Pick<Skill, 'id' | 'name'>[] = [];
    for (let offset = 0; ; offset += 100) {
      const { data, error } = await supabase.from('skills').select('id,name').eq('course_id', courseId)
        .order('order_index').order('id').range(offset, offset + 99);
      if (error && error.code !== 'PGRST103') throw new Error(error.message);
      rows.push(...(data ?? []).map((skill) => ({ ...skill, name: updatedUzbekSpelling(skill.name) })));
      if (!data || data.length < 100) return rows;
    }
  }

  async saveSkill(skill: Partial<Skill>): Promise<Skill> {
    const id = skill.id || `skill_${Date.now()}`;
    const newSkill: Skill = {
      id,
      courseId: skill.courseId || 'course_math_01',
      name: skill.name || 'Yangi Könikma',
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
      if (error) throw new Error(`Könikma saqlaşda xatolik: ${error.message}`);
      return newSkill;
    }

    const idx = inMemorySkills.findIndex((s) => s.id === id);
    if (idx >= 0) inMemorySkills[idx] = newSkill;
    else inMemorySkills.push(newSkill);

    return newSkill;
  }

  async deleteSkill(skillId: string): Promise<void> {
    if (isSupabaseConfigured && !isDemoRuntimeActive()) {
      const { error } = await supabase.from('skills').delete().eq('id', skillId);
      if (error) throw new Error(`Könikmani öçirişda xatolik: ${error.message}`);
      return;
    }
    inMemorySkills = inMemorySkills.filter((s) => s.id !== skillId);
  }

  // =========================================================================
  // 3. LESSONS MANAGEMENT (DARSLAR VA MATERIALLAR)
  // =========================================================================
  async getLessons(courseId: string, page = 0) {
    if (!isSupabaseConfigured || isDemoRuntimeActive()) {
      return demoPage(inMemoryLessons.filter((l) => l.courseId === courseId), page);
    }
    // Learner access uses learner_lessons; CMS reads use the role-gated view
    // so answer-key JSON never travels to ordinary authenticated clients.
    const { data, error } = await supabase.from('admin_lessons')
      .select('id,course_id,skill_id,title,estimated_minutes,summary,is_published,is_archived,created_at,updated_at')
      .eq('course_id', courseId).order('created_at', { ascending: false }).order('id')
      .range(page * pageSize, (page + 1) * pageSize);
    if (error && error.code !== 'PGRST103') throw new Error(error.message);
    return pageOf((data ?? []).map((l) => ({
        id: l.id,
        courseId: l.course_id,
        skillId: l.skill_id,
        title: updatedCourseText(l.title, courseId),
        estimatedMinutes: l.estimated_minutes || 15,
        summary: updatedCourseText(l.summary || '', courseId),
        isPublished: l.is_published ?? true,
        isArchived: l.is_archived ?? false,
        createdAt: l.created_at,
        updatedAt: l.updated_at,
    })));
  }

  async getLessonDetails(lessonId: string): Promise<Pick<AdminLessonRecord, 'steps' | 'reinforcementExercise'>> {
    if (!isSupabaseConfigured || isDemoRuntimeActive()) {
      const lesson = inMemoryLessons.find((row) => row.id === lessonId);
      if (!lesson) throw new Error('Dars topilmadi.');
      return { steps: lesson.steps, reinforcementExercise: lesson.reinforcementExercise };
    }
    const { data, error } = await supabase.from('admin_lessons')
      .select('steps,reinforcement_exercise').eq('id', lessonId).single();
    if (error || !data) throw new Error(error?.message ?? 'Dars topilmadi.');
    return { steps: data.steps, reinforcementExercise: data.reinforcement_exercise };
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
      steps: lesson.steps ?? [
        {
          id: `step_${Date.now()}_1`,
          stepNumber: 1,
          type: 'concept',
          title: 'Asosiy tuşunça',
          content: 'Darsning nazariy qismi...',
        },
      ],
      reinforcementExercise: lesson.reinforcementExercise !== undefined ? lesson.reinforcementExercise : {
        id: `q_reinf_${id}`,
        courseId: lesson.courseId || 'course_math_01',
        skillId: lesson.skillId || 'skill_math_functions',
        text: 'Mavzuni töliq özlaştirdingizmi?',
        options: ['Ha, töliq', 'Qisman', 'Yana takrorlaş kerak', 'Boşqatdan'],
        difficulty: 'medium',
        explanation: 'Mustahkamlaş savoli',
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
        reinforcement_exercise: newLesson.reinforcementExercise,
        is_published: newLesson.isPublished,
        is_archived: newLesson.isArchived,
        updated_at: newLesson.updatedAt,
      } });
      if (error || data?.saved !== true) throw new Error(`Darsni saqlaşda xatolik: ${error?.message || 'Server saqlashni tasdiqlamadi.'}`);
      return newLesson;
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
      if (error) throw new Error(`Naşr holatini özgartirişda xatolik: ${error.message}`);
      return;
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
      if (error) throw new Error(`Arxiv holatini özgartirişda xatolik: ${error.message}`);
      return;
    }
    const l = inMemoryLessons.find((item) => item.id === lessonId);
    if (l) l.isArchived = isArchived;
  }

  async deleteLesson(lessonId: string): Promise<void> {
    if (isSupabaseConfigured && !isDemoRuntimeActive()) {
      const { error } = await supabase.from('lessons').delete().eq('id', lessonId);
      if (error) throw new Error(`Darsni öçirişda xatolik: ${error.message}`);
      return;
    }
    inMemoryLessons = inMemoryLessons.filter((l) => l.id !== lessonId);
  }

  // =========================================================================
  // 4. QUESTIONS MANAGEMENT (SAVOLLAR VA TESTLAR)
  // =========================================================================
  async getQuestions(courseId: string, skillId?: string, page = 0) {
    if (!isSupabaseConfigured || isDemoRuntimeActive()) {
      return demoPage(inMemoryQuestions.filter((q) => q.courseId === courseId && (!skillId || q.skillId === skillId)), page);
    }
    // Answer keys are exposed only through the admin-only security-definer
    // view; learner-facing question reads never receive correct_index.
    let query = supabase.from('admin_questions')
      .select('id,course_id,skill_id,text,options,correct_index,difficulty,explanation,formula_latex,is_placement,created_at')
      .eq('course_id', courseId).order('created_at', { ascending: false }).order('id');
    if (skillId) query = query.eq('skill_id', skillId);

    const { data, error } = await query.range(page * pageSize, (page + 1) * pageSize);
    if (error && error.code !== 'PGRST103') throw new Error(error.message);
    return pageOf<AdminQuestionRecord>((data ?? []).map((q) => ({
        id: q.id,
        courseId: q.course_id,
        skillId: q.skill_id,
        text: updatedCourseText(q.text, courseId),
        options: Array.isArray(q.options) ? q.options.map((text: string) => updatedCourseText(text, courseId)) : [],
        correctIndex: q.correct_index,
        difficulty: q.difficulty || 'medium',
        explanation: updatedCourseText(q.explanation || '', courseId),
        formulaLatex: q.formula_latex || undefined,
        isPlacement: q.is_placement ?? false,
        createdAt: q.created_at,
    })));
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
      explanation: question.explanation || 'Pedagogik tuşuntiriş va töğri yeçim.',
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
      if (error || data?.saved !== true) throw new Error(`Savolni saqlaşda xatolik: ${error?.message || 'Server saqlashni tasdiqlamadi.'}`);
      return newQuestion;
    }

    const idx = inMemoryQuestions.findIndex((q) => q.id === id);
    if (idx >= 0) inMemoryQuestions[idx] = newQuestion;
    else inMemoryQuestions.unshift(newQuestion);

    return newQuestion;
  }

  async deleteQuestion(questionId: string): Promise<void> {
    if (isSupabaseConfigured && !isDemoRuntimeActive()) {
      const { error } = await supabase.from('questions').delete().eq('id', questionId);
      if (error) throw new Error(`Savolni öçirişda xatolik: ${error.message}`);
      return;
    }
    inMemoryQuestions = inMemoryQuestions.filter((q) => q.id !== questionId);
  }
}

export const adminContentService = new AdminContentService();
