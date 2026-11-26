import { describe, expect, it, vi } from 'vitest';
import { mapLearnerLesson } from '@/data/repositories/SupabaseLessonRepository';
import { RouteEngine } from '@/domain/personalization/RouteEngine';
import { evaluateWordMatch } from '@/domain/entities/Question';
import { SubmitLessonAnswerUseCase } from '@/domain/usecases/SubmitLessonAnswerUseCase';
import { useLessonStore } from '@/app/store/useLessonStore';
import { supabaseLearnerRepository } from '@/data/repositories/SupabaseLearnerRepository';
import type { LearningPathNode } from '@/domain/entities/LearningPathNode';

describe('W1-B2: CEFR SQL mapping, wire parity, and <28% reinforcement clearance', () => {
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

  it('FIX-P1-40: SubmitLessonAnswerUseCase forwards serverResult.correctOption on wrong non-MCQ attempts', async () => {
    const useCase = new SubmitLessonAnswerUseCase({
      submitAnswerAttempt: async () => ({
        isCorrect: false,
        correctOption: 'They read books in the library.',
        explanation: 'Ega + fe’l + to‘ldiruvchi tartibini saqlang.',
        newSkillScore: 0,
        overallScore: 0,
        xpAwarded: 0,
      }),
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
    expect(res.correctOption).toBe('They read books in the library.');
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
