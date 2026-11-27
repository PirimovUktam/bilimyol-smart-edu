// @vitest-environment jsdom
import React from 'react';
import { beforeAll, describe, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { mapLearnerLesson } from '@/data/repositories/SupabaseLessonRepository';
import { RouteEngine } from '@/domain/personalization/RouteEngine';
import { evaluateWordMatch } from '@/domain/entities/Question';
import { SubmitLessonAnswerUseCase } from '@/domain/usecases/SubmitLessonAnswerUseCase';
import { useLessonStore } from '@/app/store/useLessonStore';
import { useRoadmapStore } from '@/app/store/useRoadmapStore';
import { ReinforcementModal } from '@/features/reinforcement/ReinforcementModal';
import { supabaseLearnerRepository } from '@/data/repositories/SupabaseLearnerRepository';
import type { LearningPathNode } from '@/domain/entities/LearningPathNode';

describe('W1-B2: CEFR SQL mapping, wire parity, and <28% reinforcement clearance', () => {
  beforeAll(() => {
    if (typeof HTMLDialogElement !== 'undefined') {
      HTMLDialogElement.prototype.showModal ??= function showModalPolyfill(this: HTMLDialogElement) {
        this.setAttribute('open', '');
      };
      HTMLDialogElement.prototype.close ??= function closePolyfill(this: HTMLDialogElement) {
        this.removeAttribute('open');
      };
    }
  });
  it('FIX-P0-01 & FIX-P1-40: mapLearnerLesson preserves per-question skillId, officialCefrDisclaimer, pedagogy17, and alternateExercise while stripping learner secrets', () => {
    const mapped = mapLearnerLesson({
      id: 'lesson_eng_a1_exit',
      course_id: 'course_eng_01',
      skill_id: 'skill_eng_reading',
      skill_domain: 'integrated',
      cefr_level: 'A1',
      module_id: 'mod_eng_a1_exit',
      unit_id: 'unit_eng_a1_exit',
      title: 'A1 yakuniy tekshiruv',
      title_ru: 'Итоговая проверка A1',
      summary: 'A1 yakuni',
      summary_ru: 'Итог A1',
      official_cefr_disclaimer_uz: 'Norasmiy amaliy baholash',
      official_cefr_disclaimer_ru: 'Неофициальная практическая оценка',
      pedagogy17: {
        grammarFocus: 'Present Simple',
        uzbekContrast: 'O‘zbek tilidan farqli tartib',
      },
      estimated_minutes: 15,
      steps: [
        {
          id: 'step_1',
          stepNumber: 1,
          type: 'interactive_question',
          title: 'Listening step',
          content: 'Tinglang',
          interactiveQuestion: {
            id: 'q_eng_a1_exit_listen',
            courseId: 'course_eng_01',
            skillId: 'skill_eng_listening',
            questionType: 'multiple_choice',
            text: 'Soat nechada?',
            options: ['08:30', '20:00', '19:30', '20:30'],
            difficulty: 'easy',
          },
        },
      ],
      reinforcement_exercise: {
        id: 'q_eng_a1_exit_reinf',
        courseId: 'course_eng_01',
        skillId: 'skill_eng_reading',
        questionType: 'text_input',
        text: 'Yozing',
        options: [],
        difficulty: 'easy',
      },
      alternate_exercise: {
        id: 'q_eng_a1_exit_alt',
        courseId: 'course_eng_01',
        skillId: 'skill_eng_grammar',
        questionType: 'fill_blank',
        text: 'Bo‘sh joyni to‘ldiring',
        blankTemplate: 'She ___ English.',
        options: [],
        difficulty: 'easy',
      },
    });

    expect(mapped.steps[0]?.interactiveQuestion?.skillId).toBe('skill_eng_listening');
    expect(mapped.alternateExercise?.skillId).toBe('skill_eng_grammar');
    expect(mapped.officialCefrDisclaimerUz).toBe('Norasmiy amaliy baholash');
    expect(mapped.officialCefrDisclaimerRu).toBe('Неофициальная практическая оценка');
    expect(mapped.pedagogy17).toBeDefined();
  });

  it('FIX-P1-40: word_match wire payload serializes key-sorted {"leftId":"selectedRightText"} even when learner_lessons deranges matchPairs right column', async () => {
    const spy = vi.spyOn(supabaseLearnerRepository, 'submitAnswerAttempt').mockResolvedValue({
      isCorrect: true,
      explanation: 'To‘g‘ri moslashtirildi.',
      newSkillScore: 100,
      overallScore: 100,
      xpAwarded: 2,
    });
    vi.spyOn(supabaseLearnerRepository, 'markLessonCompleted').mockResolvedValue();
    vi.spyOn(supabaseLearnerRepository, 'getProfile').mockResolvedValue({
      id: 'user-w1b2',
      name: 'Learner',
      xp: 22,
      streak: 1,
      completedLessonIds: ['lesson_eng_a1_m1_greetings'],
      completedNodeIds: [],
      completedReinforcementIds: [],
      scoresByCourse: {},
    } as any);

    // Simulate sanitized learner_lessons where right values were cyclically shifted (+1 mod N):
    // pair_gm holds 'Xayrli kech', pair_ge holds 'Xayrli tong'!
    const derangedLesson = mapLearnerLesson({
      id: 'lesson_eng_a1_m1_greetings',
      course_id: 'course_eng_01',
      skill_id: 'skill_eng_vocab',
      title: 'Greetings',
      summary: 'Summary',
      estimated_minutes: 10,
      steps: [
        {
          id: 's1',
          stepNumber: 1,
          type: 'interactive_question',
          title: 'Match',
          content: 'Moslang',
          interactiveQuestion: {
            id: 'q_eng_a1_m1_greet_match',
            courseId: 'course_eng_01',
            skillId: 'skill_eng_vocab',
            questionType: 'word_match',
            text: 'Juftliklarni moslang',
            options: [],
            matchPairs: [
              { id: 'pair_gm', left: 'Good morning', right: 'Xayrli kech' },
              { id: 'pair_ge', left: 'Good evening', right: 'Xayrli tong' },
            ],
            difficulty: 'easy',
          },
        },
      ],
      reinforcement_exercise: {
        id: 'q_eng_a1_m1_greet_reinf',
        courseId: 'course_eng_01',
        skillId: 'skill_eng_vocab',
        questionType: 'text_input',
        text: 'Reinforce',
        options: [],
        difficulty: 'easy',
      },
    });

    useLessonStore.setState({
      currentLesson: derangedLesson,
      currentStepIndex: 0,
      isEvaluatingAnswer: false,
      isCompleted: false,
      lastAnswerResult: null,
      answeredQuestionIds: [],
    });

    // User clicks left 'pair_gm' ('Good morning') -> right button 'pair_ge' (which displays 'Xayrli tong')
    // and left 'pair_ge' ('Good evening') -> right button 'pair_gm' (which displays 'Xayrli kech').
    await useLessonStore.getState().submitStructuredAnswer({
      matchPairs: { pair_gm: 'pair_ge', pair_ge: 'pair_gm' },
    });

    expect(spy).toHaveBeenCalledTimes(1);
    expect(spy.mock.calls[0]?.[0]?.selectedAnswer).toBe(
      '{"pair_ge":"Xayrli kech","pair_gm":"Xayrli tong"}',
    );
    expect(
      evaluateWordMatch(
        { pair_ge: 'Xayrli kech', pair_gm: 'Xayrli tong' },
        [
          { id: 'pair_gm', left: 'Good morning', right: 'Xayrli tong' },
          { id: 'pair_ge', left: 'Good evening', right: 'Xayrli kech' },
        ],
      ),
    ).toBe(true);

    spy.mockRestore();
  });

  it('FIX-P1-40: SubmitLessonAnswerUseCase withholds literal correctOption on wrong non-MCQ attempts, forwards wrongFeedback, and sorts self_assessed criteria', async () => {
    const submittedPayloads: string[] = [];
    const useCase = new SubmitLessonAnswerUseCase({
      submitAnswerAttempt: async (req: { selectedAnswer: string }) => {
        submittedPayloads.push(req.selectedAnswer);
        return {
          isCorrect: false,
          correctOption: undefined,
          explanation: 'Ega + fe’l + to‘ldiruvchi tartibini saqlang.',
          newSkillScore: 0,
          overallScore: 0,
          xpAwarded: 0,
        };
      },
    } as any);

    const res = await useCase.executeStructured(
      {
        id: 'q_eng_a1_m2_order_1',
        courseId: 'course_eng_01',
        skillId: 'skill_eng_grammar',
        questionType: 'sentence_order',
        text: 'Gap tuzing',
        options: [],
        orderedTokens: ['books', 'They', 'read'],
        difficulty: 'easy',
        explanation: '',
      },
      {
        serializedAnswer: '["books","They","read"]',
        displayAnswer: 'books They read',
        orderedTokens: ['books', 'They', 'read'],
      },
      'lesson_eng_a1_m2_sentence_builder',
    );

    expect(res.isCorrect).toBe(false);
    expect(res.correctOption).toBe('');
    expect(res.explanation).toBe('Ega + fe’l + to‘ldiruvchi tartibini saqlang.');

    await useCase.executeSelfAssessed(
      {
        id: 'q_eng_a1_m1_speaking_prompt',
        courseId: 'course_eng_01',
        skillId: 'skill_eng_vocab',
        questionType: 'speaking_prompt',
        evaluationMode: 'self_assessed',
        text: 'O‘zingizni tanishtiring',
        options: [],
        sampleResponse: 'Hello! My name is Dilnoza.',
        difficulty: 'easy',
        explanation: '',
      },
      'Hello! My name is Dilnoza.',
      ['crit_polite', 'crit_greet'],
      'lesson_eng_a1_m1_speaking',
    );
    expect(submittedPayloads.at(-1)).toBe(
      '{"response":"Hello! My name is Dilnoza.","criteria":["crit_greet","crit_polite"]}',
    );
  });

  it('FIX-P0-01 & FIX-P1-40: ReinforcementModal preserves server-deranged 4-pair word_match & 2-token sentence_order without double-permutation un-scrambling and serializes sorted self_assessed criteria', async () => {
    const completeSpy = vi.spyOn(useRoadmapStore.getState(), 'completeReinforcement').mockResolvedValue({
      isCorrect: false,
      oldScore: 20,
      newScore: 20,
      xpAwarded: 0,
      updatedRoadmap: {
        id: 'roadmap_course_eng_01',
        courseId: 'course_eng_01',
        title: 'Roadmap',
        nodes: [],
        activeNodeId: '',
        updatedAt: 1,
      },
      explanation: 'Juftliklarni tekshiring.',
    });

    try {
      // 1. Sanitized 4-pair q_eng_a1_m1_greet_match (id.length === 23, 23 % 4 === 3):
      // Server already shifted right by +1 mod 4: [Xayrli kech, Ahvolingiz qanday?, Yaxshiman, rahmat., Xayrli tong].
      // ReinforcementModal MUST NOT shift again by +3 mod 4 (which would restore exact solution alignment!).
      const sanitizedGreetMatch = mapLearnerLesson({
        id: 'lesson_eng_a1_m1_greetings',
        course_id: 'course_eng_01',
        skill_id: 'skill_eng_vocab',
        title: 'Greetings',
        summary: 'Summary',
        estimated_minutes: 6,
        steps: [],
        reinforcement_exercise: {
          id: 'q_eng_a1_m1_greet_match',
          courseId: 'course_eng_01',
          skillId: 'skill_eng_vocab',
          questionType: 'word_match',
          text: 'Moslang',
          options: [],
          matchPairs: [
            { id: 'pair_gm', left: 'Good morning', right: 'Xayrli kech' },
            { id: 'pair_ge', left: 'Good evening', right: 'Ahvolingiz qanday?' },
            { id: 'pair_hay', left: 'How are you?', right: 'Yaxshiman, rahmat.' },
            { id: 'pair_ift', left: "I'm fine, thanks.", right: 'Xayrli tong' },
          ],
          difficulty: 'easy',
        },
      }).reinforcementExercise;

      const { container } = render(
        <ReinforcementModal
          isOpen
          question={sanitizedGreetMatch}
          courseId="course_eng_01"
          skillId="skill_eng_vocab"
          lessonId="lesson_eng_a1_m1_greetings"
          reinforcementNodeId="reinf_node_eng_a1_m1_greetings"
          onSuccess={() => {}}
          onClose={() => {}}
        />,
      );

      const rightButtons = Array.from(
        container.querySelectorAll('[data-match-side="right"] [data-match-item]'),
      );
      expect(rightButtons.map((b) => b.textContent?.trim())).toEqual([
        'Xayrli kech',
        'Ahvolingiz qanday?',
        'Yaxshiman, rahmat.',
        'Xayrli tong',
      ]);

      // Click all 4 correct pairings via UI buttons and submit
      const leftButtons = Array.from(
        container.querySelectorAll('[data-match-side="left"] [data-match-item]'),
      );
      // pair_gm (0: Good morning) -> right index 3 (Xayrli tong)
      fireEvent.click(leftButtons[0]!);
      fireEvent.click(rightButtons[3]!);
      // pair_ge (1: Good evening) -> right index 0 (Xayrli kech)
      fireEvent.click(leftButtons[1]!);
      fireEvent.click(rightButtons[0]!);
      // pair_hay (2: How are you?) -> right index 1 (Ahvolingiz qanday?)
      fireEvent.click(leftButtons[2]!);
      fireEvent.click(rightButtons[1]!);
      // pair_ift (3: I'm fine, thanks.) -> right index 2 (Yaxshiman, rahmat.)
      fireEvent.click(leftButtons[3]!);
      fireEvent.click(rightButtons[2]!);

      const submitBtn = Array.from(container.querySelectorAll('button')).find((b) =>
        /tekshirish|проверить/i.test(b.textContent ?? ''),
      )!;
      fireEvent.click(submitBtn);

      await waitFor(() => expect(completeSpy).toHaveBeenCalledTimes(1));
      expect(completeSpy.mock.calls[0]?.[5]).toBe(
        '{"pair_ge":"Xayrli kech","pair_gm":"Xayrli tong","pair_hay":"Ahvolingiz qanday?","pair_ift":"Yaxshiman, rahmat."}',
      );
      cleanup();

      // 2. Sanitized 2-token sentence_order ["world", "Hello"] must NOT be swapped back to ["Hello", "world"]!
      const sanitized2Tok = mapLearnerLesson({
        id: 'lesson_2tok',
        course_id: 'course_eng_01',
        skill_id: 'skill_eng_grammar',
        title: 'Two Token',
        summary: 'Summary',
        estimated_minutes: 5,
        steps: [],
        reinforcement_exercise: {
          id: 'q_2tok',
          courseId: 'course_eng_01',
          skillId: 'skill_eng_grammar',
          questionType: 'sentence_order',
          text: 'Tartiblang',
          options: [],
          orderedTokens: ['world', 'Hello'],
          difficulty: 'easy',
        },
      }).reinforcementExercise;

      render(
        <ReinforcementModal
          isOpen
          question={sanitized2Tok}
          courseId="course_eng_01"
          skillId="skill_eng_grammar"
          reinforcementNodeId="reinf_lesson_lesson_2tok"
          onSuccess={() => {}}
          onClose={() => {}}
        />,
      );
      const tokenButtons = screen
        .getAllByRole('button')
        .filter((b) => b.textContent === 'world' || b.textContent === 'Hello');
      expect(tokenButtons.map((b) => b.textContent)).toEqual(['world', 'Hello']);
      cleanup();

      // 3. Self-assessed reinforcement serializes sorted checkedRubricIds
      const sanitizedSelf = mapLearnerLesson({
        id: 'lesson_self',
        course_id: 'course_eng_01',
        skill_id: 'skill_eng_vocab',
        title: 'Speaking',
        summary: 'Summary',
        estimated_minutes: 5,
        steps: [],
        reinforcement_exercise: {
          id: 'q_self_reinf',
          courseId: 'course_eng_01',
          skillId: 'skill_eng_vocab',
          questionType: 'speaking_prompt',
          evaluationMode: 'self_assessed',
          text: 'Gapiring',
          options: [],
          sampleResponse: 'Hello, I am Sam.',
          rubricCriteria: [
            { id: 'crit_b', labelUz: 'Mezon B', labelRu: 'Критерий B' },
            { id: 'crit_a', labelUz: 'Mezon A', labelRu: 'Критерий A' },
          ],
          difficulty: 'easy',
        },
      }).reinforcementExercise;

      const selfView = render(
        <ReinforcementModal
          isOpen
          question={sanitizedSelf}
          courseId="course_eng_01"
          skillId="skill_eng_vocab"
          reinforcementNodeId="reinf_lesson_lesson_self"
          onSuccess={() => {}}
          onClose={() => {}}
        />,
      );
      const textarea = selfView.container.querySelector('textarea')!;
      fireEvent.change(textarea, { target: { value: 'Hello, I am Sam.' } });
      const checkboxes = selfView.container.querySelectorAll('input[type="checkbox"]');
      fireEvent.click(checkboxes[0]!); // crit_b
      fireEvent.click(checkboxes[1]!); // crit_a
      const selfSubmit = Array.from(selfView.container.querySelectorAll('button')).find((b) =>
        /tekshirish|проверить/i.test(b.textContent ?? ''),
      )!;
      fireEvent.click(selfSubmit);

      await waitFor(() => expect(completeSpy).toHaveBeenCalledTimes(2));
      expect(completeSpy.mock.calls[1]?.[5]).toBe(
        '{"response":"Hello, I am Sam.","criteria":["crit_a","crit_b"]}',
      );
    } finally {
      cleanup();
      completeSpy.mockRestore();
    }
  });

  it('FIX-P1-40: RouteEngine clears parent node reinforcement status once reinf_<node_id> is completed even when score < 50', () => {
    const baseNodes: LearningPathNode[] = [
      {
        id: 'node_eng_a1_m1_greetings',
        courseId: 'course_eng_01',
        skillId: 'skill_eng_vocab',
        title: 'Greetings',
        description: 'Desc',
        prerequisites: [],
        requiredScore: 70,
        status: 'available',
        isReinforcement: false,
        targetLessonId: 'lesson_eng_a1_m1_greetings',
        estimatedMinutes: 10,
        order: 1,
      },
    ];

    const stuckBefore = RouteEngine.adaptRoadmap(
      'course_eng_01',
      baseNodes,
      {
        skill_eng_vocab: {
          skillId: 'skill_eng_vocab',
          courseId: 'course_eng_01',
          score: 22,
          masteryLevel: 'needs_remediation',
          lastUpdated: 1,
          isWeakestFocus: true,
        },
      },
      [],
      [],
    );
    expect(stuckBefore.nodes.find((n) => n.id === 'node_eng_a1_m1_greetings')?.status).toBe('reinforcement');

    const clearedAfter = RouteEngine.adaptRoadmap(
      'course_eng_01',
      baseNodes,
      {
        skill_eng_vocab: {
          skillId: 'skill_eng_vocab',
          courseId: 'course_eng_01',
          score: 22,
          masteryLevel: 'needs_remediation',
          lastUpdated: 2,
          isWeakestFocus: false,
        },
      },
      [],
      ['reinf_node_eng_a1_m1_greetings'],
    );
    expect(clearedAfter.nodes.find((n) => n.id === 'node_eng_a1_m1_greetings')?.status).toBe('available');
    expect(clearedAfter.nodes.find((n) => n.id === 'reinf_node_eng_a1_m1_greetings')?.status).toBe('completed');
  });
});
