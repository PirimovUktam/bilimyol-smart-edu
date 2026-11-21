import { describe, it, expect } from 'vitest';
import { PLACEMENT_QUESTIONS } from '@/data/datasources/questions';
import { SEED_LESSONS } from '@/data/datasources/lessons';

describe('Question Content & Assessment Audit Tests', () => {
  const forbiddenPatterns = [
    /to['‘`]?g['‘`]?ri\s*javob/i,
    /noto['‘`]?g['‘`]?ri/i,
    /xato/i,
    /hisoblangan/i,
    /unutilgan/i,
    /qo['‘`]?yilgan/i,
    /deb\s+hisoblangan/i,
    /correct\s*answer/i,
    /incorrect/i,
    /\(to‘g‘ri\)/i,
    /\(xato\)/i,
  ];

  describe('1. Placement and Question Bank Audit', () => {
    it('verifies that all Math questions have clean options without spoiler text or answer keys', () => {
      const mathQuestions = PLACEMENT_QUESTIONS['course_math_01'] || [];
      expect(mathQuestions.length).toBeGreaterThanOrEqual(20);

      mathQuestions.forEach((q) => {
        expect(q.options.length).toBeGreaterThanOrEqual(3);
        expect(q.correctIndex).toBeGreaterThanOrEqual(0);
        expect(q.correctIndex).toBeLessThan(q.options.length);
        expect(q.text.trim().length).toBeGreaterThan(5);
        expect(q.explanation.trim().length).toBeGreaterThan(5);

        // Verify each option text contains no spoiler / diagnostic parenthetical hints
        q.options.forEach((opt) => {
          expect(typeof opt).toBe('string');
          expect(opt.trim().length).toBeGreaterThan(0);

          for (const pattern of forbiddenPatterns) {
            expect(opt).not.toMatch(pattern);
          }
        });
      });
    });

    it('verifies that all English questions have clean options without spoiler text', () => {
      const engQuestions = PLACEMENT_QUESTIONS['course_eng_01'] || [];
      expect(engQuestions.length).toBeGreaterThanOrEqual(5);

      engQuestions.forEach((q) => {
        expect(q.options.length).toBeGreaterThanOrEqual(3);
        expect(q.correctIndex).toBeGreaterThanOrEqual(0);
        expect(q.correctIndex).toBeLessThan(q.options.length);

        q.options.forEach((opt) => {
          for (const pattern of forbiddenPatterns) {
            expect(opt).not.toMatch(pattern);
          }
        });
      });
    });
  });

  describe('2. Lesson Interactive and Reinforcement Question Audit', () => {
    it('verifies all interactive questions in seed lessons have clean options or valid free-text keys', () => {
      const validateQuestion = (q: typeof SEED_LESSONS[string]['reinforcementExercise']) => {
        const qType = q.questionType ?? 'multiple_choice';
        if (qType === 'text_input' || qType === 'fill_blank') {
          expect(Array.isArray(q.acceptedAnswers)).toBe(true);
          expect(q.acceptedAnswers!.length).toBeGreaterThanOrEqual(1);
          q.acceptedAnswers!.forEach((ans) => {
            expect(typeof ans).toBe('string');
            expect(ans.trim().length).toBeGreaterThan(0);
            if (qType === 'text_input') {
              expect(q.text.toLowerCase()).not.toContain(ans.toLowerCase());
              expect((q.wrongFeedback || '').toLowerCase()).not.toContain(ans.toLowerCase());
            } else if (q.blankTemplate) {
              expect(q.blankTemplate).toContain('___');
            }
          });
          expect((q.explanation || '').trim().length).toBeGreaterThan(4);
          expect((q.wrongFeedback || '').trim().length).toBeGreaterThan(4);
          return;
        }

        if (qType === 'word_match') {
          expect(Array.isArray(q.matchPairs)).toBe(true);
          expect(q.matchPairs!.length).toBeGreaterThanOrEqual(3);
          q.matchPairs!.forEach((pair) => {
            expect(pair.id.trim().length).toBeGreaterThan(0);
            expect(pair.left.trim().length).toBeGreaterThan(0);
            expect(pair.right.trim().length).toBeGreaterThan(0);
          });
          expect((q.explanation || '').trim().length).toBeGreaterThan(4);
          return;
        }

        if (qType === 'sentence_order') {
          expect(Array.isArray(q.orderedTokens)).toBe(true);
          expect(q.orderedTokens!.length).toBeGreaterThanOrEqual(3);
          expect((q.explanation || '').trim().length).toBeGreaterThan(4);
          return;
        }

        if (qType === 'speaking_prompt' || qType === 'writing_prompt') {
          expect(q.evaluationMode).toBe('self_assessed');
          expect((q.sampleResponse || '').trim().length).toBeGreaterThan(5);
          expect(Array.isArray(q.rubricCriteria)).toBe(true);
          expect(q.rubricCriteria!.length).toBeGreaterThanOrEqual(3);
          return;
        }

        expect(q.options.length).toBeGreaterThanOrEqual(3);
        expect(q.correctIndex).toBeGreaterThanOrEqual(0);
        expect(q.correctIndex).toBeLessThan(q.options.length);

        q.options.forEach((opt) => {
          for (const pattern of forbiddenPatterns) {
            expect(opt).not.toMatch(pattern);
          }
        });
      };

      Object.values(SEED_LESSONS).forEach((lesson) => {
        lesson.steps.forEach((step) => {
          if (step.interactiveQuestion) {
            validateQuestion(step.interactiveQuestion);
          }
        });

        if (lesson.reinforcementExercise) {
          validateQuestion(lesson.reinforcementExercise);
        }

        if (lesson.alternateExercise) {
          validateQuestion(lesson.alternateExercise);
        }
      });
    });
  });

  describe('3. Mathematical and Assessment Correctness', () => {
    it('accurately validates f(4) = 2x + 3 gives 11 as the sole mathematically true option', () => {
      const mathLesson = SEED_LESSONS['lesson_math_functions_01'];
      const q = mathLesson.steps.find((s) => s.interactiveQuestion)?.interactiveQuestion;
      expect(q).toBeDefined();

      if (q) {
        expect(q.correctIndex).toBeDefined();
        const correctOption = q.options[q.correctIndex!];
        expect(correctOption).toBe('11');

        // Check distractors are distinct numbers
        const uniqueOptions = new Set(q.options);
        expect(uniqueOptions.size).toBe(q.options.length);
        expect(q.options).toContain('8');
        expect(q.options).toContain('14');
        expect(q.options).toContain('9');
      }
    });

    it('accurately validates reinforcement f(2) = 3x + 2 gives 8', () => {
      const mathLesson = SEED_LESSONS['lesson_math_functions_01'];
      const reinf = mathLesson.reinforcementExercise;
      expect(reinf).toBeDefined();

      if (reinf) {
        expect(reinf.correctIndex).toBeDefined();
        const correctOption = reinf.options[reinf.correctIndex!];
        expect(correctOption).toBe('8');
      }
    });
  });
});
