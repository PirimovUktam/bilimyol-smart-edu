import { describe, it, expect, beforeEach } from 'vitest';
import { InMemoryCourseRepository } from '../data/repositories/InMemoryCourseRepository';
import { InMemoryLessonRepository } from '../data/repositories/InMemoryLessonRepository';

describe('CourseSwitching', () => {
  let courseRepo: InMemoryCourseRepository;
  let lessonRepo: InMemoryLessonRepository;

  beforeEach(() => {
    courseRepo = new InMemoryCourseRepository();
    lessonRepo = new InMemoryLessonRepository();
  });

  it('should expose every available course instead of selecting a hard-coded subject', async () => {
    const courses = await courseRepo.getAllCourses();

    expect(courses.map((course) => course.id)).toEqual([
      'course_math_01',
      'course_eng_01',
      'course_it',
      'course_logic',
    ]);
    expect(new Set(courses.map((course) => course.subject))).toEqual(
      new Set(['mathematics', 'english', 'it', 'logic'])
    );
  });

  it('should return correct distinct skills for Mathematics and English', async () => {
    const mathSkills = await courseRepo.getSkillsByCourseId('course_math_01');
    const engSkills = await courseRepo.getSkillsByCourseId('course_eng_01');

    expect(mathSkills.length).toBe(4);
    expect(mathSkills.map((s) => s.code)).toContain('MATH-FUNC');

    expect(engSkills.length).toBe(4);
    expect(engSkills.map((s) => s.code)).toContain('ENG-LIST');
  });

  it('should return distinct lessons and roadmaps for each course', async () => {
    const mathLesson1 = await lessonRepo.getLessonById('lesson_math_functions_01');
    const mathLesson2 = await lessonRepo.getLessonById('lesson_math_functions_02');

    expect(mathLesson1?.title).toContain('Funksiya');
    expect(mathLesson2?.title).toContain('qiymatini topish');

    const mathNodes = await lessonRepo.getBaseRoadmapNodes('course_math_01');
    const engNodes = await lessonRepo.getBaseRoadmapNodes('course_eng_01');

    expect(mathNodes.some((n) => n.id === 'node_math_func')).toBe(true);
    expect(engNodes.some((n) => n.id === 'node_eng_list')).toBe(true);
  });

  it('should guarantee 100% strict subject isolation in placement questions without data leakage', async () => {
    const mathQuestions = await courseRepo.getPlacementQuestions('course_math_01');
    const engQuestions = await courseRepo.getPlacementQuestions('course_eng_01');

    expect(mathQuestions.length).toBeGreaterThan(0);
    expect(engQuestions.length).toBeGreaterThan(0);

    // Math questions must only refer to math skills and math course
    for (const q of mathQuestions) {
      expect(q.courseId).toBe('course_math_01');
      expect(q.skillId.startsWith('skill_math_')).toBe(true);
      expect(q.text.toLowerCase()).not.toContain('synonym');
      expect(q.text.toLowerCase()).not.toContain('listening');
    }

    // English questions must only refer to english skills and english course
    for (const q of engQuestions) {
      expect(q.courseId).toBe('course_eng_01');
      expect(q.skillId.startsWith('skill_eng_')).toBe(true);
      expect(q.text.toLowerCase()).not.toContain('tenglama');
      expect(q.text.toLowerCase()).not.toContain('parabola');
    }
  });

  it('should ensure all roadmap nodes have correct course alignment and target lessons', async () => {
    const mathNodes = await lessonRepo.getBaseRoadmapNodes('course_math_01');
    const engNodes = await lessonRepo.getBaseRoadmapNodes('course_eng_01');

    for (const node of mathNodes) {
      expect(node.courseId).toBe('course_math_01');
      expect(node.skillId.startsWith('skill_math_')).toBe(true);
    }

    for (const node of engNodes) {
      expect(node.courseId).toBe('course_eng_01');
      expect(node.skillId.startsWith('skill_eng_')).toBe(true);
      if (node.targetLessonId) {
        const lesson = await lessonRepo.getLessonById(node.targetLessonId);
        expect(lesson?.courseId).toBe('course_eng_01');
      }
    }
  });
});
