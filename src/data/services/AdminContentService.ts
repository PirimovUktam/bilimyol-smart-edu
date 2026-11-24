import { supabase, isSupabaseConfigured } from '@/core/config/supabase';
import { Course } from '@/domain/entities/Course';
import { Skill } from '@/domain/entities/Skill';
import { Lesson } from '@/domain/entities/Lesson';
import { Question } from '@/domain/entities/Question';
import { mapCourseSubject } from '@/data/repositories/SupabaseCourseRepository';
import { isDemoRuntimeActive } from '@/core/runtime/demoRuntime';

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

interface AdminDemoStores {
  courses: Course[];
  skills: Skill[];
  lessons: AdminLessonRecord[];
  questions: AdminQuestionRecord[];
}

let demoStores: AdminDemoStores | null = null;
let demoStoresPromise: Promise<AdminDemoStores> | null = null;

async function ensureDemoStores(): Promise<AdminDemoStores> {
  if (demoStores) return demoStores;
  demoStoresPromise ??= Promise.all([
    import('../datasources/courses'),
    import('../datasources/skills'),
    import('../datasources/lessons'),
    import('../datasources/questions'),
  ]).then(([coursesMod, skillsMod, lessonsMod, questionsMod]) => {
    const questions: AdminQuestionRecord[] = [];
    for (const [courseId, qList] of Object.entries(questionsMod.PLACEMENT_QUESTIONS)) {
      for (const q of qList) {
        questions.push({
          ...q,
          courseId,
          isPlacement: true,
        });
      }
    }
    demoStores = {
      courses: [...coursesMod.SEED_COURSES],
      skills: [...skillsMod.SEED_SKILLS],
      lessons: Object.values(lessonsMod.SEED_LESSONS).map((l) => ({
        ...l,
        isPublished: true,
        isArchived: false,
      })),
      questions,
    };
    return demoStores;
  }).catch((err) => {
    demoStoresPromise = null;
    throw err;
  });
  return demoStoresPromise;
}

export class AdminContentService {
  // =========================================================================
  // 1. COURSES MANAGEMENT (FANLAR)
  // =========================================================================
  async getCourses(): Promise<Course[]> {
    if (!isSupabaseConfigured || isDemoRuntimeActive()) {
      const stores = await ensureDemoStores();
      return [...stores.courses];
    }
    const { data, error } = await supabase.from('courses').select('*').order('created_at', { ascending: false });
    if (error) throw new Error('Fanlarni serverdan yuklab bo‘lmadi.');
    return (data ?? []).map((c) => ({
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
      if (error) throw new Error(`Fan saqlashda xatolik: ${error.message}`);
      return newCourse;
    }

    // Update in-memory
    const stores = await ensureDemoStores();
    const idx = stores.courses.findIndex((c) => c.id === id);
    if (idx >= 0) stores.courses[idx] = newCourse;
    else stores.courses.unshift(newCourse);

    return newCourse;
  }

  async deleteCourse(courseId: string): Promise<void> {
    if (isSupabaseConfigured && !isDemoRuntimeActive()) {
      const { error } = await supabase.from('courses').delete().eq('id', courseId);
      if (error) throw new Error(`Fanni o‘chirishda xatolik: ${error.message}`);
      return;
    }
    const stores = await ensureDemoStores();
    stores.courses = stores.courses.filter((c) => c.id !== courseId);
  }

  // =========================================================================
  // 2. SKILLS MANAGEMENT (KO‘NIKMALAR VA MAVZULAR)
  // =========================================================================
  async getSkills(courseId: string, page = 0) {
    if (!isSupabaseConfigured || isDemoRuntimeActive()) {
      const stores = await ensureDemoStores();
      return demoPage(stores.skills.filter((s) => s.courseId === courseId), page);
    }
    const { data, error } = await supabase.from('skills')
      .select('id,course_id,name,code,description,order_index,icon_name')
      .eq('course_id', courseId).order('order_index').order('id')
      .range(page * pageSize, (page + 1) * pageSize);
    if (error && error.code !== 'PGRST103') throw new Error(error.message);
    return pageOf<Skill>((data ?? []).map((s) => ({
        id: s.id,
        courseId: s.course_id,
        name: s.name,
        code: s.code,
        description: s.description || '',
        order: s.order_index ?? 0,
        orderIndex: s.order_index,
        iconName: s.icon_name || 'Target',
    })));
  }

  async getSkillOptions(courseId: string): Promise<Pick<Skill, 'id' | 'name'>[]> {
    if (!isSupabaseConfigured || isDemoRuntimeActive()) {
      const stores = await ensureDemoStores();
      return stores.skills.filter((skill) => skill.courseId === courseId);
    }
    const rows: Pick<Skill, 'id' | 'name'>[] = [];
    for (let offset = 0; ; offset += 100) {
      const { data, error } = await supabase.from('skills').select('id,name').eq('course_id', courseId)
        .order('order_index').order('id').range(offset, offset + 99);
      if (error && error.code !== 'PGRST103') throw new Error(error.message);
      rows.push(...(data ?? []));
      if (!data || data.length < 100) return rows;
    }
  }

  async saveSkill(skill: Partial<Skill>): Promise<Skill> {
    const id = skill.id || `skill_${Date.now()}`;
    if (isSupabaseConfigured && !isDemoRuntimeActive()) {
      const fallbackOrder = skill.order ?? skill.orderIndex ?? 1;
      const newSkill: Skill = {
        id,
        courseId: skill.courseId || 'course_math_01',
        name: skill.name || 'Yangi Ko‘nikma',
        code: skill.code || 'SKILL_NEW',
        description: skill.description || '',
        order: fallbackOrder,
        orderIndex: skill.orderIndex ?? skill.order ?? fallbackOrder,
        iconName: skill.iconName || 'Target',
      };
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
      return newSkill;
    }

    const stores = await ensureDemoStores();
    const defaultOrder = stores.skills.length + 1;
    const newSkill: Skill = {
      id,
      courseId: skill.courseId || 'course_math_01',
      name: skill.name || 'Yangi Ko‘nikma',
      code: skill.code || 'SKILL_NEW',
      description: skill.description || '',
      order: skill.order ?? skill.orderIndex ?? defaultOrder,
      orderIndex: skill.orderIndex ?? skill.order ?? defaultOrder,
      iconName: skill.iconName || 'Target',
    };
    const idx = stores.skills.findIndex((s) => s.id === id);
    if (idx >= 0) stores.skills[idx] = newSkill;
    else stores.skills.push(newSkill);

    return newSkill;
  }

  async deleteSkill(skillId: string): Promise<void> {
    if (isSupabaseConfigured && !isDemoRuntimeActive()) {
      const { error } = await supabase.from('skills').delete().eq('id', skillId);
      if (error) throw new Error(`Ko‘nikmani o‘chirishda xatolik: ${error.message}`);
      return;
    }
    const stores = await ensureDemoStores();
    stores.skills = stores.skills.filter((s) => s.id !== skillId);
  }

  // =========================================================================
  // 3. LESSONS MANAGEMENT (DARSLAR VA MATERIALLAR)
  // =========================================================================
  async getLessons(courseId: string, page = 0) {
    if (!isSupabaseConfigured || isDemoRuntimeActive()) {
      const stores = await ensureDemoStores();
      return demoPage(stores.lessons.filter((l) => l.courseId === courseId), page);
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
        title: l.title,
        estimatedMinutes: l.estimated_minutes || 15,
        summary: l.summary || '',
        isPublished: l.is_published ?? true,
        isArchived: l.is_archived ?? false,
        createdAt: l.created_at,
        updatedAt: l.updated_at,
    })));
  }

  async getLessonDetails(lessonId: string): Promise<Pick<AdminLessonRecord, 'steps' | 'reinforcementExercise'>> {
    if (!isSupabaseConfigured || isDemoRuntimeActive()) {
      const stores = await ensureDemoStores();
      const lesson = stores.lessons.find((row) => row.id === lessonId);
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
          title: 'Asosiy tushuncha',
          content: 'Darsning nazariy qismi...',
        },
      ],
      reinforcementExercise: lesson.reinforcementExercise !== undefined ? lesson.reinforcementExercise : {
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
        reinforcement_exercise: newLesson.reinforcementExercise,
        is_published: newLesson.isPublished,
        is_archived: newLesson.isArchived,
        updated_at: newLesson.updatedAt,
      } });
      if (error || data?.saved !== true) throw new Error(`Darsni saqlashda xatolik: ${error?.message || 'Server saqlashni tasdiqlamadi.'}`);
      return newLesson;
    }

    const stores = await ensureDemoStores();
    const idx = stores.lessons.findIndex((l) => l.id === id);
    if (idx >= 0) stores.lessons[idx] = newLesson;
    else stores.lessons.unshift(newLesson);

    return newLesson;
  }

  async toggleLessonPublish(lessonId: string, isPublished: boolean): Promise<void> {
    if (isSupabaseConfigured && !isDemoRuntimeActive()) {
      const { error } = await supabase
        .from('lessons')
        .update({ is_published: isPublished, updated_at: new Date().toISOString() })
        .eq('id', lessonId);
      if (error) throw new Error(`Nashr holatini o‘zgartirishda xatolik: ${error.message}`);
      return;
    }
    const stores = await ensureDemoStores();
    const l = stores.lessons.find((item) => item.id === lessonId);
    if (l) l.isPublished = isPublished;
  }

  async toggleLessonArchive(lessonId: string, isArchived: boolean): Promise<void> {
    if (isSupabaseConfigured && !isDemoRuntimeActive()) {
      const { error } = await supabase
        .from('lessons')
        .update({ is_archived: isArchived, updated_at: new Date().toISOString() })
        .eq('id', lessonId);
      if (error) throw new Error(`Arxiv holatini o‘zgartirishda xatolik: ${error.message}`);
      return;
    }
    const stores = await ensureDemoStores();
    const l = stores.lessons.find((item) => item.id === lessonId);
    if (l) l.isArchived = isArchived;
  }

  async deleteLesson(lessonId: string): Promise<void> {
    if (isSupabaseConfigured && !isDemoRuntimeActive()) {
      const { error } = await supabase.from('lessons').delete().eq('id', lessonId);
      if (error) throw new Error(`Darsni o‘chirishda xatolik: ${error.message}`);
      return;
    }
    const stores = await ensureDemoStores();
    stores.lessons = stores.lessons.filter((l) => l.id !== lessonId);
  }

  // =========================================================================
  // 4. QUESTIONS MANAGEMENT (SAVOLLAR VA TESTLAR)
  // =========================================================================
  async getQuestions(courseId: string, skillId?: string, page = 0) {
    if (!isSupabaseConfigured || isDemoRuntimeActive()) {
      const stores = await ensureDemoStores();
      return demoPage(stores.questions.filter((q) => q.courseId === courseId && (!skillId || q.skillId === skillId)), page);
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
        text: q.text,
        options: Array.isArray(q.options) ? q.options : [],
        correctIndex: q.correct_index,
        difficulty: q.difficulty || 'medium',
        explanation: q.explanation || '',
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
      return newQuestion;
    }

    const stores = await ensureDemoStores();
    const idx = stores.questions.findIndex((q) => q.id === id);
    if (idx >= 0) stores.questions[idx] = newQuestion;
    else stores.questions.unshift(newQuestion);

    return newQuestion;
  }

  async deleteQuestion(questionId: string): Promise<void> {
    if (isSupabaseConfigured && !isDemoRuntimeActive()) {
      const { error } = await supabase.from('questions').delete().eq('id', questionId);
      if (error) throw new Error(`Savolni o‘chirishda xatolik: ${error.message}`);
      return;
    }
    const stores = await ensureDemoStores();
    stores.questions = stores.questions.filter((q) => q.id !== questionId);
  }
}

export const adminContentService = new AdminContentService();
