import { describe, it, expect } from 'vitest';
import { InMemoryCourseRepository } from '../data/repositories/InMemoryCourseRepository';
import { InMemoryLessonRepository } from '../data/repositories/InMemoryLessonRepository';

describe('CourseSwitching', () => {
  const courseRepo = new InMemoryCourseRepository();
  const lessonRepo = new InMemoryLessonRepository();

  it('should return correct distinct skills for Mathematics and English', async () => {
    const mathSkills = await courseRepo.getSkillsByCourseId('course_math_01');
    const engSkills = await courseRepo.getSkillsByCourseId('course_eng_01');

    expect(mathSkills.length).toBe(4);
    expect(mathSkills.map((s) => s.code)).toEqual(['MATH-ALG', 'MATH-EQ', 'MATH-FUNC', 'MATH-GRAPH']);

    expect(engSkills.length).toBe(4);
    expect(engSkills.map((s) => s.code)).toEqual(['ENG-VOCAB', 'ENG-GRAM', 'ENG-LIST', 'ENG-READ']);
  });

  it('should return distinct lessons and roadmaps for each course', async () => {
    const mathLesson = await lessonRepo.getLessonById('lesson_math_functions_01');
    const engLesson = await lessonRepo.getLessonById('lesson_eng_listening_01');

    expect(mathLesson?.title).toBe('Funksiyalar asoslari');
    expect(engLesson?.title).toBe('Listening asoslari: Vaqt va Kalit So‘zlar');

    const mathNodes = await lessonRepo.getBaseRoadmapNodes('course_math_01');
    const engNodes = await lessonRepo.getBaseRoadmapNodes('course_eng_01');

    expect(mathNodes.length).toBe(4);
    expect(engNodes.length).toBe(4);
  });
});
