import { describe, expect, it } from 'vitest';
import { uz } from '@/core/locales/messages';
import { updatedCourseText, updatedUzbekSpelling } from '@/core/locales/uzbekAlphabet';
import { isAnswerRevealRequest } from '@/data/datasources/demoAiResponses';
import { mapLearnerLesson } from '@/data/repositories/SupabaseLessonRepository';
import { matchesAcceptedAnswer } from '@/domain/entities/Question';

describe('updated Uzbek alphabet', () => {
  it('renders authored Uzbek copy in the new alphabet', () => {
    expect(uz.admin.description).toBe('Öquv dasturlari, fanlar, darsliklar va test savollari boşqaruvi');
  });

  it('presents existing math content with current spelling and stable answer indices', () => {
    const lesson = mapLearnerLesson({
      id: 'lesson_legacy', course_id: 'course_math_01', skill_id: 'skill_legacy',
      title: 'Qo‘shish', title_ru: 'Сложение',
      questions: [{ id: 'q_legacy', text: "To'g'ri javobni tanlang", options: ['Uch', 'Olti'] }],
      steps: [{ id: 'step_legacy', type: 'interactive_question', title: 'Savol' }],
    });
    expect(lesson.title).toBe('Qöşiş');
    expect(lesson.titleRu).toBe('Сложение');
    expect(lesson.reinforcementExercise).toMatchObject({
      id: 'q_legacy', text: 'Töğri javobni tanlang', options: ['Uç', 'Olti'],
    });
  });

  it('accepts both spellings for Uzbek answers and keeps English matching exact', () => {
    expect(matchesAcceptedAnswer(" Qoʻshish, to'g'ri! ", ['Qöşiş töğri'], 'uz')).toBe(true);
    expect(matchesAcceptedAnswer('çair', ['chair'])).toBe(false);
  });

  it('preserves English examples, code, and identifiers in legacy content', () => {
    expect(updatedCourseText('Birinchi shart: she finishes school.', 'course_eng_01'))
      .toBe('Birinçi şart: she finishes school.');
    expect(updatedUzbekSpelling('Bog‘ ichida `push()` va Isʼhoq')).toBe('Boğ içida `push()` va Isʼhoq');
  });

  it('recognizes requests for the answer in both alphabets', () => {
    expect(isAnswerRevealRequest("To'g'ri yechimni ayt")).toBe(true);
    expect(isAnswerRevealRequest('Töğri yeçimni ayt')).toBe(true);
  });
});
