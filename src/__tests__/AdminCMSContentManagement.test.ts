import { describe, it, expect, beforeEach } from 'vitest';
import { adminContentService } from '../data/services/AdminContentService';
import { supabaseCourseRepository } from '../data/repositories/SupabaseCourseRepository';
import { supabaseLessonRepository } from '../data/repositories/SupabaseLessonRepository';

describe('Admin CMS Content Management (Bosqich 3)', () => {
  beforeEach(() => {
    // Reset/setup clean state
  });

  it('1. Fanlar CMS: Yangi fan yaratish, o‘qitish va faollik statusini boshqarish', async () => {
    const courseId = `course_test_${Date.now()}`;
    const created = await adminContentService.saveCourse({
      id: courseId,
      title: 'Oliy Matematika',
      subject: 'mathematics',
      description: 'Integrallar va differensial hisob',
      primaryColorHex: '#6366F1',
      secondaryColorHex: '#A5B4FC',
      totalStudentsEstimate: 300,
      isActive: true,
    });

    expect(created.id).toBe(courseId);
    expect(created.title).toBe('Oliy Matematika');

    const allCourses = await adminContentService.getCourses();
    expect(allCourses.some((c) => c.id === courseId)).toBe(true);

    // Toggle active to false
    await adminContentService.saveCourse({ ...created, isActive: false });
    const afterDeactivate = await adminContentService.getCourses();
    const deactivatedCourse = afterDeactivate.find((c) => c.id === courseId);
    expect(deactivatedCourse?.isActive).toBe(false);

    // Clean up
    await adminContentService.deleteCourse(courseId);
    const afterDelete = await adminContentService.getCourses();
    expect(afterDelete.some((c) => c.id === courseId)).toBe(false);
  });

  it('2. Ko‘nikmalar CMS: Fanga yangi ko‘nikma qo‘shish va filtrlash', async () => {
    const skillId = `skill_test_${Date.now()}`;
    const created = await adminContentService.saveSkill({
      id: skillId,
      courseId: 'course_math_01',
      name: 'Matritsalar va Determinantlar',
      code: 'SKILL_MATRICE',
      description: 'Chiziqli algebra asoslari',
      orderIndex: 99,
    });

    expect(created.id).toBe(skillId);
    expect(created.name).toBe('Matritsalar va Determinantlar');

    const courseSkills = await adminContentService.getSkills('course_math_01');
    expect(courseSkills.some((s) => s.id === skillId)).toBe(true);

    // Delete skill
    await adminContentService.deleteSkill(skillId);
    const afterDelete = await adminContentService.getSkills('course_math_01');
    expect(afterDelete.some((s) => s.id === skillId)).toBe(false);
  });

  it('3. Darslar CMS: Darslik yaratish, nashr qilish (publish) va arxivlash (archive)', async () => {
    const lessonId = `lesson_test_${Date.now()}`;
    const created = await adminContentService.saveLesson({
      id: lessonId,
      courseId: 'course_math_01',
      skillId: 'skill_math_functions',
      title: 'Tenglamalar Sistemasi Haqida',
      summary: 'Qo‘shish va o‘rniga qo‘yish usullari',
      estimatedMinutes: 20,
      isPublished: true,
      isArchived: false,
    });

    expect(created.id).toBe(lessonId);
    expect(created.isPublished).toBe(true);

    // Toggle publish to false (draft)
    await adminContentService.toggleLessonPublish(lessonId, false);
    let lessons = await adminContentService.getLessons('course_math_01');
    expect(lessons.find((l) => l.id === lessonId)?.isPublished).toBe(false);

    // Toggle archive
    await adminContentService.toggleLessonArchive(lessonId, true);
    lessons = await adminContentService.getLessons('course_math_01');
    expect(lessons.find((l) => l.id === lessonId)?.isArchived).toBe(true);

    // Delete lesson
    await adminContentService.deleteLesson(lessonId);
    lessons = await adminContentService.getLessons('course_math_01');
    expect(lessons.some((l) => l.id === lessonId)).toBe(false);
  });

  it('4. Test Banki CMS: Yangi savol va 4 ta variant kiritish, to‘g‘ri javobni belgilash', async () => {
    const qId = `q_test_${Date.now()}`;
    const created = await adminContentService.saveQuestion({
      id: qId,
      courseId: 'course_math_01',
      skillId: 'skill_math_algebra',
      text: '3(x - 2) = 15 tenglamani yeching.',
      options: ['x = 3', 'x = 5', 'x = 7', 'x = 9'],
      correctIndex: 2, // 'x = 7'
      difficulty: 'medium',
      explanation: '3x - 6 = 15 => 3x = 21 => x = 7.',
      isPlacement: false,
    });

    expect(created.id).toBe(qId);
    expect(created.options.length).toBe(4);
    expect(created.correctIndex).toBe(2);

    const questions = await adminContentService.getQuestions('course_math_01', 'skill_math_algebra');
    expect(questions.some((q) => q.id === qId)).toBe(true);

    // Delete question
    await adminContentService.deleteQuestion(qId);
    const afterDelete = await adminContentService.getQuestions('course_math_01', 'skill_math_algebra');
    expect(afterDelete.some((q) => q.id === qId)).toBe(false);
  });

  it('5. Repozitoriy integratsiyasi: O‘quvchi repozitoriylari fallback va sozlanish holatida ishlaydi', async () => {
    const courses = await supabaseCourseRepository.getAllCourses();
    expect(courses.length).toBeGreaterThan(0);

    const lesson = await supabaseLessonRepository.getLessonById('lesson_math_functions_01');
    expect(lesson).toBeDefined();
    expect(lesson?.title).toContain('Funksiya');
  });
});
