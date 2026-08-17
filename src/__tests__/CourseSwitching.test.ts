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
});
