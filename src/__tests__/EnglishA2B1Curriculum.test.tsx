import { existsSync, readFileSync, statSync } from 'node:fs';
import path from 'node:path';
import { renderToStaticMarkup } from 'react-dom/server';
import { afterEach, describe, expect, it, vi } from 'vitest';

vi.mock('zustand', async (importOriginal) => {
  const actual = await importOriginal<typeof import('zustand')>();
  const React = await import('react');
  return {
    ...actual,
    create: ((createState: Parameters<typeof actual.create>[0]) => {
      if (!createState) return actual.create;
      const api = actual.create(createState);
      return Object.assign(
        (selector: (state: unknown) => unknown = (state) => state) =>
          React.useSyncExternalStore(
            api.subscribe,
            () => selector(api.getState()),
            () => selector(api.getState()),
          ),
        api,
      );
    }) as typeof actual.create,
  };
});

import { AuthProvider } from '@/core/context/AuthContext';
import { loadRussian } from '@/core/locales/messages';
import { usePreferences } from '@/core/preferences/preferences';
import { setDemoRuntimeActive } from '@/core/runtime/demoRuntime';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { isIntegratedEnglishLesson, isValidAssessment, useLessonStore } from '@/app/store/useLessonStore';
import { useRoadmapStore } from '@/app/store/useRoadmapStore';
import { SEED_COURSES } from '@/data/datasources/courses';
import { SEED_LESSONS } from '@/data/datasources/lessons';
import { SEED_ROADMAP_NODES } from '@/data/datasources/roadmaps';
import { SEED_SKILLS } from '@/data/datasources/skills';
import {
  ENGLISH_A1_LESSONS_LIST,
  ENGLISH_A1_ROADMAP_NODES,
  ENGLISH_A2_CURRICULUM_META,
  ENGLISH_A2_FLASHCARDS,
  ENGLISH_A2_LESSONS,
  ENGLISH_A2_LESSONS_LIST,
  ENGLISH_A2_QUESTIONS,
  ENGLISH_A2_ROADMAP_NODES,
  ENGLISH_ALL_AUDIO_ASSETS,
  ENGLISH_ALL_FLASHCARD_ENTRIES,
  ENGLISH_ALL_FLASHCARDS,
  ENGLISH_ALL_IMAGE_ASSETS,
  ENGLISH_ALL_LESSONS,
  ENGLISH_ALL_LESSONS_LIST,
  ENGLISH_ALL_LESSONS_ORDER,
  ENGLISH_ALL_QUESTIONS,
  ENGLISH_ALL_ROADMAP_NODES,
  ENGLISH_B1_CURRICULUM_META,
  ENGLISH_B1_FLASHCARDS,
  ENGLISH_B1_LESSONS,
  ENGLISH_B1_LESSONS_LIST,
  ENGLISH_B1_QUESTIONS,
  ENGLISH_B1_ROADMAP_NODES,
  ENGLISH_FLASHCARD_BY_ID,
  ENGLISH_FLASHCARDS_BY_LESSON,
} from '@/data/datasources/english';
import { InMemoryLearnerRepository } from '@/data/repositories/InMemoryLearnerRepository';
import { mapLearnerLesson } from '@/data/repositories/SupabaseLessonRepository';
import { readApprovedLessonMedia } from '@/domain/entities/LessonMedia';
import type { LearnerProfile } from '@/domain/entities/LearnerProfile';
import type { Question, QuestionType } from '@/domain/entities/Question';
import { computeNextFlashcardSrs, isFlashcardDue } from '@/domain/personalization/FlashcardSrsEngine';
import { RouteEngine } from '@/domain/personalization/RouteEngine';
import { SubmitLessonAnswerUseCase } from '@/domain/usecases/SubmitLessonAnswerUseCase';
import { FlashcardDeck } from '@/features/lesson/FlashcardDeck';
import { InteractiveLessonView } from '@/features/lesson/InteractiveLessonView';
import { RoadmapView } from '@/features/roadmap/RoadmapView';

const ALL_NINE_QUESTION_TYPES: QuestionType[] = [
  'multiple_choice',
  'text_input',
  'fill_blank',
  'word_match',
  'sentence_order',
  'error_correction',
  'conversation_completion',
  'speaking_prompt',
  'writing_prompt',
];

function createMemoryStorage(): Storage {
  const store = new Map<string, string>();
  return {
    getItem: (k: string) => store.get(k) ?? null,
    setItem: (k: string, v: string) => {
      store.set(k, v);
    },
    removeItem: (k: string) => {
      store.delete(k);
    },
    clear: () => {
      store.clear();
    },
    key: (i: number) => [...store.keys()][i] ?? null,
    get length() {
      return store.size;
    },
  } as Storage;
}

const isChoiceMode = (q: Question): boolean => {
  const qType = q.questionType ?? 'multiple_choice';
  return (
    qType === 'multiple_choice' ||
    qType === 'error_correction' ||
    qType === 'conversation_completion'
  );
};

const extractSectionByCefr = (html: string, level: string): string => {
  const marker = `data-cefr-level="${level}"`;
  const start = html.indexOf(marker);
  if (start === -1) return '';
  const next = html.indexOf('data-cefr-level="', start + marker.length);
  return next === -1 ? html.slice(start) : html.slice(start, next);
};

afterEach(async () => {
  useLessonStore.getState().clearSession();
  await usePreferences.getState().setLanguage('uz', false);
});

describe('M3.3 Web CEFR A2 & B1 Curriculum Suite', () => {
  it('1. wires A1+A2+B1 totals, canonical metadata, unique IDs, and on-disk approved media assets', () => {
    const englishCourse = SEED_COURSES.find((c) => c.id === 'course_eng_01');
    expect(englishCourse).toBeDefined();
    expect(englishCourse?.lessons).toHaveLength(33);
    expect(englishCourse?.lessons[0]).toBe('lesson_eng_listening_01');
    expect(englishCourse?.starterLessonId).toBe('lesson_eng_starter');
    expect(englishCourse?.foundationLessonIds).toEqual([
      'lesson_eng_starter',
      'lesson_eng_foundation_02',
    ]);

    expect(ENGLISH_A1_LESSONS_LIST).toHaveLength(17);
    expect(ENGLISH_A2_LESSONS_LIST).toHaveLength(8);
    expect(ENGLISH_B1_LESSONS_LIST).toHaveLength(8);
    expect(ENGLISH_ALL_LESSONS_LIST).toHaveLength(33);
    expect(Object.keys(ENGLISH_ALL_LESSONS)).toHaveLength(33);
    expect(ENGLISH_ALL_LESSONS_ORDER).toHaveLength(33);
    expect(new Set(ENGLISH_ALL_LESSONS_ORDER).size).toBe(33);

    expect(ENGLISH_A2_CURRICULUM_META.cefrLevel).toBe('A2');
    expect(ENGLISH_B1_CURRICULUM_META.cefrLevel).toBe('B1');

    const nodes = SEED_ROADMAP_NODES['course_eng_01'];
    expect(nodes).toHaveLength(31);
    expect(ENGLISH_ALL_ROADMAP_NODES).toHaveLength(31);
    expect(nodes.map((n) => n.order)).toEqual(Array.from({ length: 31 }, (_, i) => i + 1));

    for (const node of nodes) {
      const targetLesson = SEED_LESSONS[node.targetLessonId!];
      expect(targetLesson).toBeDefined();
      expect(targetLesson.courseId).toBe('course_eng_01');
      expect(node.courseId).toBe('course_eng_01');
      if (node.cefrLevel) {
        expect(targetLesson.cefrLevel).toBe(node.cefrLevel);
      }
      if (node.moduleId) {
        expect(targetLesson.moduleId).toBe(node.moduleId);
      }
      if (node.unitId) {
        expect(targetLesson.unitId).toBe(node.unitId);
      }
    }

    expect(ENGLISH_A2_QUESTIONS).toHaveLength(27);
    expect(ENGLISH_B1_QUESTIONS).toHaveLength(29);
    expect(ENGLISH_ALL_QUESTIONS).toHaveLength(98);
    expect(new Set(ENGLISH_ALL_QUESTIONS.map((q) => q.id)).size).toBe(98);

    expect(ENGLISH_A2_FLASHCARDS).toHaveLength(16);
    expect(ENGLISH_B1_FLASHCARDS).toHaveLength(16);
    expect(ENGLISH_ALL_FLASHCARDS).toHaveLength(49);
    expect(ENGLISH_ALL_FLASHCARD_ENTRIES).toHaveLength(49);
    expect(Object.keys(ENGLISH_FLASHCARD_BY_ID)).toHaveLength(49);
    expect(Object.keys(ENGLISH_FLASHCARDS_BY_LESSON)).toHaveLength(33);

    expect(ENGLISH_ALL_AUDIO_ASSETS).toHaveLength(68);
    expect(ENGLISH_ALL_IMAGE_ASSETS).toHaveLength(15);
    expect(new Set(ENGLISH_ALL_AUDIO_ASSETS.map((a) => a.id)).size).toBe(68);
    expect(new Set(ENGLISH_ALL_IMAGE_ASSETS.map((i) => i.id)).size).toBe(15);

    const approvedSources = new Set([
      ...ENGLISH_ALL_AUDIO_ASSETS.filter((a) => a.reviewStatus === 'approved').map(
        (a) => a.canonicalSource,
      ),
      ...ENGLISH_ALL_IMAGE_ASSETS.filter((i) => i.reviewStatus === 'approved').map(
        (i) => i.canonicalSource,
      ),
    ]);

    for (const lesson of [...ENGLISH_A2_LESSONS_LIST, ...ENGLISH_B1_LESSONS_LIST]) {
      for (const step of lesson.steps) {
        if (step.media) {
          const validated = readApprovedLessonMedia(step.media);
          expect(validated).toBeDefined();
          expect(validated?.language).toBe('en');
          expect(approvedSources.has(step.media.source)).toBe(true);
          const diskPath = path.join(process.cwd(), 'public', step.media.source.replace(/^\//, ''));
          expect(existsSync(diskPath)).toBe(true);
          expect(statSync(diskPath).size).toBeGreaterThan(0);
          if ('posterImage' in step.media && step.media.posterImage) {
            expect(approvedSources.has(step.media.posterImage)).toBe(true);
            const posterDisk = path.join(
              process.cwd(),
              'public',
              step.media.posterImage.replace(/^\//, ''),
            );
            expect(existsSync(posterDisk)).toBe(true);
            expect(statSync(posterDisk).size).toBeGreaterThan(0);
          }
        }
        for (const card of step.flashcards ?? []) {
          if (card.audioSrc) {
            expect(approvedSources.has(card.audioSrc)).toBe(true);
            const audioDisk = path.join(process.cwd(), 'public', card.audioSrc.replace(/^\//, ''));
            expect(existsSync(audioDisk)).toBe(true);
            expect(statSync(audioDisk).size).toBeGreaterThan(0);
          }
          if (card.imageSrc) {
            expect(approvedSources.has(card.imageSrc)).toBe(true);
            const imgDisk = path.join(process.cwd(), 'public', card.imageSrc.replace(/^\//, ''));
            expect(existsSync(imgDisk)).toBe(true);
            expect(statSync(imgDisk).size).toBeGreaterThan(0);
          }
        }
      }
    }
  });

  it('2. enforces A1 -> A2 -> B1 prerequisite locking and reinforcement CEFR metadata preservation', () => {
    const baseNodes = SEED_ROADMAP_NODES['course_eng_01'];

    // Fresh learner: A2 and B1 are completely locked
    const freshPath = RouteEngine.adaptRoadmap('course_eng_01', baseNodes, {}, [], []);
    expect(freshPath.nodes.find((n) => n.id === 'node_eng_a1_m1_greetings')?.status).toBe(
      'available',
    );
    for (const a2Node of ENGLISH_A2_ROADMAP_NODES) {
      expect(freshPath.nodes.find((n) => n.id === a2Node.id)?.status).toBe('locked');
    }
    for (const b1Node of ENGLISH_B1_ROADMAP_NODES) {
      expect(freshPath.nodes.find((n) => n.id === b1Node.id)?.status).toBe('locked');
    }
    expect(RouteEngine.canStartNode(freshPath.nodes.find((n) => n.id === 'node_eng_a2_m1_directions')!, [])).toBe(
      false,
    );
    expect(RouteEngine.canStartNode(freshPath.nodes.find((n) => n.id === 'node_eng_b1_m1_travel')!, [])).toBe(
      false,
    );

    // Complete all A1 nodes -> only node_eng_a2_m1_directions unlocks; all B1 stay locked
    const completedA1 = ENGLISH_A1_ROADMAP_NODES.map((n) => n.id);
    const afterA1 = RouteEngine.adaptRoadmap('course_eng_01', baseNodes, {}, completedA1, []);
    expect(afterA1.nodes.find((n) => n.id === 'node_eng_a2_m1_directions')?.status).toBe(
      'available',
    );
    for (const laterA2 of ENGLISH_A2_ROADMAP_NODES.slice(1)) {
      expect(afterA1.nodes.find((n) => n.id === laterA2.id)?.status).toBe('locked');
    }
    for (const b1Node of ENGLISH_B1_ROADMAP_NODES) {
      expect(afterA1.nodes.find((n) => n.id === b1Node.id)?.status).toBe('locked');
    }

    // Step through A2 chain one node at a time
    const cumulativeCompleted = [...completedA1];
    for (let i = 0; i < ENGLISH_A2_ROADMAP_NODES.length; i++) {
      const current = ENGLISH_A2_ROADMAP_NODES[i];
      cumulativeCompleted.push(current.id);
      const stepPath = RouteEngine.adaptRoadmap('course_eng_01', baseNodes, {}, cumulativeCompleted, []);
      expect(stepPath.nodes.find((n) => n.id === current.id)?.status).toBe('completed');
      if (i + 1 < ENGLISH_A2_ROADMAP_NODES.length) {
        const nextA2 = ENGLISH_A2_ROADMAP_NODES[i + 1];
        expect(stepPath.nodes.find((n) => n.id === nextA2.id)?.status).toBe('available');
        expect(stepPath.nodes.find((n) => n.id === 'node_eng_b1_m1_travel')?.status).toBe('locked');
      } else {
        // node_eng_a2_exit completed -> node_eng_b1_m1_travel unlocks
        expect(stepPath.nodes.find((n) => n.id === 'node_eng_b1_m1_travel')?.status).toBe(
          'available',
        );
      }
    }

    // Step through B1 chain + verify weak-skill reinforcement node keeps CEFR metadata
    for (let i = 0; i < ENGLISH_B1_ROADMAP_NODES.length; i++) {
      const current = ENGLISH_B1_ROADMAP_NODES[i];
      cumulativeCompleted.push(current.id);
      const stepPath = RouteEngine.adaptRoadmap('course_eng_01', baseNodes, {}, cumulativeCompleted, []);
      expect(stepPath.nodes.find((n) => n.id === current.id)?.status).toBe('completed');
      if (i + 1 < ENGLISH_B1_ROADMAP_NODES.length) {
        expect(
          stepPath.nodes.find((n) => n.id === ENGLISH_B1_ROADMAP_NODES[i + 1].id)?.status,
        ).toBe('available');
      }
    }

    const lowListeningPath = RouteEngine.adaptRoadmap(
      'course_eng_01',
      baseNodes,
      {
        skill_eng_listening: {
          skillId: 'skill_eng_listening',
          score: 35,
          status: 'weak',
          lastUpdated: Date.now(),
        },
      },
      completedA1,
      [],
    );
    const reinfA2 = lowListeningPath.nodes.find(
      (n) => n.id === 'reinf_node_eng_a2_m1_directions',
    );
    expect(reinfA2).toBeDefined();
    expect(reinfA2?.isReinforcement).toBe(true);
    expect(reinfA2?.cefrLevel).toBe('A2');
    expect(reinfA2?.moduleId).toBe('mod_eng_a2_m1');
  });

  it('3. permutes A2 (15) & B1 (14) choice questions deterministically while preserving grading & mistake feedback', async () => {
    const collectLevelChoices = (rawLessons: Record<string, (typeof SEED_LESSONS)[string]>) => {
      const pairs: Array<{
        lessonId: string;
        raw: Question;
        seeded: Question;
      }> = [];
      for (const [lessonId, rawLesson] of Object.entries(rawLessons)) {
        const seededLesson = SEED_LESSONS[lessonId];
        rawLesson.steps.forEach((step, idx) => {
          if (step.interactiveQuestion && isChoiceMode(step.interactiveQuestion)) {
            pairs.push({
              lessonId,
              raw: step.interactiveQuestion,
              seeded: seededLesson.steps[idx].interactiveQuestion!,
            });
          }
        });
        if (rawLesson.reinforcementExercise && isChoiceMode(rawLesson.reinforcementExercise)) {
          pairs.push({
            lessonId,
            raw: rawLesson.reinforcementExercise,
            seeded: seededLesson.reinforcementExercise,
          });
        }
        if (rawLesson.alternateExercise && isChoiceMode(rawLesson.alternateExercise)) {
          pairs.push({
            lessonId,
            raw: rawLesson.alternateExercise,
            seeded: seededLesson.alternateExercise!,
          });
        }
      }
      return pairs;
    };

    const a2Choices = collectLevelChoices(ENGLISH_A2_LESSONS);
    const b1Choices = collectLevelChoices(ENGLISH_B1_LESSONS);
    expect(a2Choices).toHaveLength(15);
    expect(b1Choices).toHaveLength(14);

    // Raw JSON keeps correctIndex === 0; SEED_LESSONS distributes across >= 3 positions
    for (const pair of [...a2Choices, ...b1Choices]) {
      expect(pair.raw.correctIndex).toBe(0);
      expect(pair.seeded.correctIndex).toBeGreaterThanOrEqual(0);
      expect(pair.seeded.correctIndex!).toBeLessThan(pair.seeded.options.length);
      expect(pair.seeded.options[pair.seeded.correctIndex!]).toBe(pair.raw.options[0]);
    }

    expect(new Set(a2Choices.map((p) => p.seeded.correctIndex)).size).toBeGreaterThanOrEqual(3);
    expect(new Set(b1Choices.map((p) => p.seeded.correctIndex)).size).toBeGreaterThanOrEqual(3);

    // Keep A1 checkpoint unpermuted at 0
    const cpQ = SEED_LESSONS['lesson_eng_a1_u1_checkpoint'].steps.find((s) => s.interactiveQuestion)
      ?.interactiveQuestion;
    expect(cpQ?.id).toBe('q_eng_a1_u1_cp_main');
    expect(cpQ?.correctIndex).toBe(0);

    // Grade all 29 A2+B1 choice questions via SubmitLessonAnswerUseCase in both UZ and RU
    const repo = new InMemoryLearnerRepository(() => createMemoryStorage());
    const useCase = new SubmitLessonAnswerUseCase(repo);

    for (const { lessonId, seeded } of [...a2Choices, ...b1Choices]) {
      const wrongIdx = (seeded.correctIndex! + 1) % seeded.options.length;
      const wrongOptionText = seeded.options[wrongIdx];
      const wrongUz = await useCase.execute(seeded, wrongIdx, lessonId, undefined, 'uz');
      expect(wrongUz.isCorrect).toBe(false);
      expect(wrongUz.correctOption).toBe(seeded.options[seeded.correctIndex!]);
      if (seeded.mistakeFeedbackByOption?.[wrongOptionText]) {
        expect(wrongUz.explanation).toBe(seeded.mistakeFeedbackByOption[wrongOptionText].uz);
      } else {
        expect(wrongUz.explanation.trim().length).toBeGreaterThan(4);
      }

      const wrongRu = await useCase.execute(seeded, wrongIdx, lessonId, undefined, 'ru');
      expect(wrongRu.isCorrect).toBe(false);
      expect(wrongRu.explanation.trim().length).toBeGreaterThan(4);

      const right = await useCase.execute(seeded, seeded.correctIndex!, lessonId, undefined, 'uz');
      expect(right.isCorrect).toBe(true);
    }
  });

  it('4. supports all 9 QuestionType modes in A2 & B1, passes isValidAssessment across all 98 Qs, and strips keys in mapLearnerLesson', async () => {
    const a2Types = new Set(ENGLISH_A2_QUESTIONS.map((q) => q.questionType ?? 'multiple_choice'));
    const b1Types = new Set(ENGLISH_B1_QUESTIONS.map((q) => q.questionType ?? 'multiple_choice'));
    for (const mode of ALL_NINE_QUESTION_TYPES) {
      expect(a2Types.has(mode)).toBe(true);
      expect(b1Types.has(mode)).toBe(true);
    }

    // All 33 English lessons & 98 questions pass isValidAssessment with isIntegratedEnglishLesson
    let validatedCount = 0;
    for (const id of ENGLISH_ALL_LESSONS_ORDER) {
      const lesson = SEED_LESSONS[id];
      const allowMulti = isIntegratedEnglishLesson(lesson);
      for (const step of lesson.steps) {
        if (step.interactiveQuestion) {
          expect(
            isValidAssessment(step.interactiveQuestion, lesson.courseId, lesson.skillId, allowMulti),
          ).toBe(true);
          validatedCount++;
        }
      }
      expect(
        isValidAssessment(lesson.reinforcementExercise, lesson.courseId, lesson.skillId, allowMulti),
      ).toBe(true);
      validatedCount++;
      if (lesson.alternateExercise) {
        expect(
          isValidAssessment(lesson.alternateExercise, lesson.courseId, lesson.skillId, allowMulti),
        ).toBe(true);
        validatedCount++;
      }
    }
    expect(validatedCount).toBe(98);

    // Strict isolation: A1 non-integrated lesson still rejects cross-skill question, and B1 still rejects math skill
    const a1Vocab = SEED_LESSONS['lesson_eng_vocab_01'];
    expect(isIntegratedEnglishLesson(a1Vocab)).toBe(false);
    expect(
      isValidAssessment(
        { ...a1Vocab.reinforcementExercise, skillId: 'skill_eng_grammar' },
        a1Vocab.courseId,
        a1Vocab.skillId,
        isIntegratedEnglishLesson(a1Vocab),
      ),
    ).toBe(false);
    const b1Travel = SEED_LESSONS['lesson_eng_b1_m1_travel'];
    expect(isIntegratedEnglishLesson(b1Travel)).toBe(true);
    expect(
      isValidAssessment(
        { ...b1Travel.reinforcementExercise, skillId: 'skill_math_algebra' },
        b1Travel.courseId,
        b1Travel.skillId,
        isIntegratedEnglishLesson(b1Travel),
      ),
    ).toBe(false);

    const repo = new InMemoryLearnerRepository(() => createMemoryStorage());
    const useCase = new SubmitLessonAnswerUseCase(repo);

    // Representative A2 & B1 exercises across rich modes
    // A2 text_input (apostrophe/punctuation variant)
    const a2Plans = SEED_LESSONS['lesson_eng_a2_m3_plans'];
    const a2TextQ = a2Plans.steps.find((s) => s.interactiveQuestion?.id === 'q_eng_a2_m3_plan_text')!
      .interactiveQuestion!;
    expect((await useCase.executeText(a2TextQ, 'visit grandma', a2Plans.id, undefined, 'uz')).isCorrect).toBe(false);
    expect(
      (await useCase.executeText(a2TextQ, '  I’m going to visit my grandmother on Sunday! ', a2Plans.id, undefined, 'uz'))
        .isCorrect,
    ).toBe(true);

    // B1 fill_blank
    const b1TravelSeed = SEED_LESSONS['lesson_eng_b1_m1_travel'];
    const b1FillQ = b1TravelSeed.steps.find((s) => s.interactiveQuestion?.id === 'q_eng_b1_m1_fill')!
      .interactiveQuestion!;
    expect((await useCase.executeText(b1FillQ, 'leave', b1TravelSeed.id, undefined, 'ru')).isCorrect).toBe(false);
    expect((await useCase.executeText(b1FillQ, 'left', b1TravelSeed.id, undefined, 'ru')).isCorrect).toBe(true);

    // B1 text_input
    const b1ReinfText = b1TravelSeed.reinforcementExercise;
    expect(
      (await useCase.executeText(b1ReinfText, 'The bus has not arrived yet.', b1TravelSeed.id, undefined, 'uz'))
        .isCorrect,
    ).toBe(true);

    // A2 & B1 word_match
    const a2MatchQ = SEED_LESSONS['lesson_eng_a2_m2_shopping'].steps.find(
      (s) => s.interactiveQuestion?.id === 'q_eng_a2_m2_word_match',
    )!.interactiveQuestion!;
    const a2RightPairs = Object.fromEntries(a2MatchQ.matchPairs!.map((p) => [p.id, p.id]));
    const a2WrongPairs = Object.fromEntries(
      a2MatchQ.matchPairs!.map((p, idx, arr) => [p.id, arr[(idx + 1) % arr.length].id]),
    );
    expect(
      (
        await useCase.executeStructured(
          a2MatchQ,
          { serializedAnswer: JSON.stringify(a2WrongPairs), displayAnswer: 'w', matchPairs: a2WrongPairs },
          'lesson_eng_a2_m2_shopping',
          undefined,
          'uz',
        )
      ).isCorrect,
    ).toBe(false);
    expect(
      (
        await useCase.executeStructured(
          a2MatchQ,
          { serializedAnswer: JSON.stringify(a2RightPairs), displayAnswer: 'r', matchPairs: a2RightPairs },
          'lesson_eng_a2_m2_shopping',
          undefined,
          'uz',
        )
      ).isCorrect,
    ).toBe(true);

    // B1 sentence_order
    const b1ExitOrderQ = SEED_LESSONS['lesson_eng_b1_exit'].steps.find(
      (s) => s.interactiveQuestion?.id === 'q_eng_b1_exit_order',
    )!.interactiveQuestion!;
    const reversedTokens = [...b1ExitOrderQ.orderedTokens!].reverse();
    expect(
      (
        await useCase.executeStructured(
          b1ExitOrderQ,
          {
            serializedAnswer: JSON.stringify(reversedTokens),
            displayAnswer: reversedTokens.join(' '),
            orderedTokens: reversedTokens,
          },
          'lesson_eng_b1_exit',
          undefined,
          'ru',
        )
      ).isCorrect,
    ).toBe(false);
    expect(
      (
        await useCase.executeStructured(
          b1ExitOrderQ,
          {
            serializedAnswer: JSON.stringify(b1ExitOrderQ.orderedTokens!),
            displayAnswer: b1ExitOrderQ.orderedTokens!.join(' '),
            orderedTokens: b1ExitOrderQ.orderedTokens!,
          },
          'lesson_eng_b1_exit',
          undefined,
          'ru',
        )
      ).isCorrect,
    ).toBe(true);

    // mapLearnerLesson strips answer keys while preserving rich metadata
    const mappedB1Narrative = mapLearnerLesson({
      id: SEED_LESSONS['lesson_eng_b1_m3_narrative'].id,
      course_id: SEED_LESSONS['lesson_eng_b1_m3_narrative'].courseId,
      skill_id: SEED_LESSONS['lesson_eng_b1_m3_narrative'].skillId,
      skill_domain: SEED_LESSONS['lesson_eng_b1_m3_narrative'].skillDomain,
      cefr_level: SEED_LESSONS['lesson_eng_b1_m3_narrative'].cefrLevel,
      title: SEED_LESSONS['lesson_eng_b1_m3_narrative'].title,
      summary: SEED_LESSONS['lesson_eng_b1_m3_narrative'].summary,
      steps: SEED_LESSONS['lesson_eng_b1_m3_narrative'].steps,
      reinforcement_exercise: SEED_LESSONS['lesson_eng_b1_m3_narrative'].reinforcementExercise,
    });
    const mappedMatch = mappedB1Narrative.steps.find(
      (s) => s.interactiveQuestion?.id === 'q_eng_b1_m3_word_match',
    )?.interactiveQuestion;
    const mappedWriting = mappedB1Narrative.steps.find(
      (s) => s.interactiveQuestion?.id === 'q_eng_b1_m3_writing',
    )?.interactiveQuestion;
    expect(mappedMatch?.matchPairs).toHaveLength(4);
    expect(mappedMatch?.explanation).toBe('');
    expect(mappedWriting?.sampleResponse).toBeTruthy();
    expect(mappedWriting?.rubricCriteria).toHaveLength(3);
    expect(mappedWriting?.selfAssessmentNoticeUz).toContain('CEFR');
    expect(mappedWriting?.selfAssessmentNoticeRu).toContain('CEFR');
    expect(mappedB1Narrative.reinforcementExercise.acceptedAnswers).toBeUndefined();
    expect(mappedB1Narrative.reinforcementExercise.blankTemplate).toContain('___');
  });

  it('5. validates A2/B1 self_assessed speaking/writing rubrics, non-certification notices, and InteractiveLessonView rendering', async () => {
    const selfAssessedIds = [
      'q_eng_a2_m1_speaking',
      'q_eng_a2_m4_writing_prompt',
      'q_eng_b1_m1_speaking',
      'q_eng_b1_m3_writing',
      'q_eng_b1_m4_writing',
    ];
    const selfAssessedQs = ENGLISH_ALL_QUESTIONS.filter((q) => selfAssessedIds.includes(q.id));
    expect(selfAssessedQs).toHaveLength(5);

    for (const q of selfAssessedQs) {
      expect(q.evaluationMode).toBe('self_assessed');
      expect((q.sampleResponse ?? '').trim().length).toBeGreaterThan(20);
      expect(q.rubricCriteria?.length).toBeGreaterThanOrEqual(3);
      for (const crit of q.rubricCriteria ?? []) {
        expect(crit.labelUz.trim().length).toBeGreaterThan(3);
        expect(crit.labelRu.trim().length).toBeGreaterThan(3);
      }
      expect(q.selfAssessmentNoticeUz).toMatch(/rasmiy CEFR sertifikati bermaydi/i);
      expect(q.selfAssessmentNoticeRu).toMatch(/не выда[её]т официальный сертификат CEFR/i);
    }

    setDemoRuntimeActive(true);
    await useCourseStore.getState().loadCourses();
    await useCourseStore.getState().selectCourseById('course_eng_01');

    // A2 Speaking lesson via useLessonStore (answer listening MCQ first, then speaking self-assessment)
    await useLessonStore.getState().loadLesson('lesson_eng_a2_m1_directions');
    const a2Lesson = useLessonStore.getState().currentLesson!;
    const a2ListenIdx = a2Lesson.steps.findIndex(
      (s) => s.interactiveQuestion?.id === 'q_eng_a2_m1_listen_mcq',
    );
    expect(a2ListenIdx).toBeGreaterThanOrEqual(0);
    const a2ListenQ = a2Lesson.steps[a2ListenIdx].interactiveQuestion!;
    useLessonStore.getState().goToStep(a2ListenIdx);
    const listenRes = await useLessonStore.getState().submitAnswer(a2ListenQ.correctIndex!);
    expect(listenRes?.isCorrect).toBe(true);

    const a2SpeakingIdx = a2Lesson.steps.findIndex(
      (s) => s.interactiveQuestion?.id === 'q_eng_a2_m1_speaking',
    );
    expect(a2SpeakingIdx).toBeGreaterThanOrEqual(0);
    useLessonStore.getState().goToStep(a2SpeakingIdx);

    const blankRes = await useLessonStore.getState().submitSelfAssessment('   ', []);
    expect(blankRes).toBeNull();
    expect(useLessonStore.getState().isCompleted).toBe(false);

    const validA2Res = await useLessonStore
      .getState()
      .submitSelfAssessment(
        'Go straight along Navoi Street, pass the post office, and turn right at the pharmacy.',
        ['crit_a2_m1_imp', 'crit_a2_m1_prep'],
      );
    expect(validA2Res?.isCorrect).toBe(true);
    expect(useLessonStore.getState().answeredQuestionIds).toContain('q_eng_a2_m1_speaking');
    expect(useLessonStore.getState().isCompleted).toBe(false);

    const uzHtml = renderToStaticMarkup(
      <AuthProvider>
        <InteractiveLessonView
          lessonId="lesson_eng_a2_m1_directions"
          onFinish={() => {}}
          onBackToRoadmap={() => {}}
        />
      </AuthProvider>,
    );
    expect(uzHtml).toContain('data-question-mode="speaking_prompt"');
    expect(uzHtml).toContain('O‘zini baholash');
    expect(uzHtml).toContain('O‘z javobingizni yozing');
    expect(uzHtml).not.toContain('Official CEFR Certificate');

    // Completing the final step via nextStep() marks the lesson completed
    await useLessonStore.getState().nextStep();
    expect(useLessonStore.getState().isCompleted).toBe(true);

    // B1 Writing lesson in Russian locale
    useLessonStore.getState().clearSession();
    await loadRussian();
    await usePreferences.getState().setLanguage('ru', false);
    await useLessonStore.getState().loadLesson('lesson_eng_b1_m4_decisions');
    const b1Lesson = useLessonStore.getState().currentLesson!;
    const b1WritingIdx = b1Lesson.steps.findIndex(
      (s) => s.interactiveQuestion?.id === 'q_eng_b1_m4_writing',
    );
    expect(b1WritingIdx).toBeGreaterThanOrEqual(0);
    useLessonStore.getState().goToStep(b1WritingIdx);
    const validB1Res = await useLessonStore
      .getState()
      .submitSelfAssessment(
        'Aziz told us that fixing the login bug was our top priority before Friday.',
        ['crit_b1_m4_rep'],
      );
    expect(validB1Res?.isCorrect).toBe(true);
    expect(useLessonStore.getState().answeredQuestionIds).toContain('q_eng_b1_m4_writing');

    const ruHtml = renderToStaticMarkup(
      <AuthProvider>
        <InteractiveLessonView
          lessonId="lesson_eng_b1_m4_decisions"
          onFinish={() => {}}
          onBackToRoadmap={() => {}}
        />
      </AuthProvider>,
    );
    expect(ruHtml).toContain('data-question-mode="writing_prompt"');
    expect(ruHtml).toContain('Самооценка');
    expect(ruHtml).toContain('Напишите свой ответ');
  });

  it('6. supports A2/B1 SRS flashcards, course isolation, and RoadmapView CEFR grouping, SRS Hub, & per-level lock badges', async () => {
    // 6a. SRS persistence & isolation for A2 & B1 flashcards
    const storage = createMemoryStorage();
    const repo = new InMemoryLearnerRepository(() => storage);

    await repo.recordFlashcardSrs('course_eng_01', 'fc_eng_a2_m1_1', 'need_practice');
    const afterB1 = await repo.recordFlashcardSrs('course_eng_01', 'fc_eng_b1_m1_1', 'remembered');
    const a2Srs = afterB1.flashcardSrsByCourse?.['course_eng_01']?.['fc_eng_a2_m1_1'];
    const b1Srs = afterB1.flashcardSrsByCourse?.['course_eng_01']?.['fc_eng_b1_m1_1'];

    expect(a2Srs?.status).toBe('need_practice');
    expect(a2Srs?.intervalDays).toBe(0);
    expect(isFlashcardDue(a2Srs)).toBe(true);

    expect(b1Srs?.status).toBe('remembered');
    expect(b1Srs?.intervalDays).toBe(1);
    expect(isFlashcardDue(b1Srs)).toBe(false);
    expect(computeNextFlashcardSrs(b1Srs, 'fc_eng_b1_m1_1', 'remembered').intervalDays).toBe(3);

    const reloaded = new InMemoryLearnerRepository(() => storage);
    const reloadedProfile = await reloaded.getProfile();
    expect(reloadedProfile.flashcardSrsByCourse?.['course_eng_01']?.['fc_eng_a2_m1_1']?.intervalDays).toBe(0);
    expect(reloadedProfile.flashcardSrsByCourse?.['course_eng_01']?.['fc_eng_b1_m1_1']?.intervalDays).toBe(1);
    expect(reloadedProfile.flashcardSrsByCourse?.['course_math_01']).toBeUndefined();

    // 6b. FlashcardDeck polarity checks on A2 & B1 cards
    const a2Card = ENGLISH_FLASHCARD_BY_ID['fc_eng_a2_m1_1'];
    const b1Card = ENGLISH_FLASHCARD_BY_ID['fc_eng_b1_m1_1'];
    expect(a2Card.front).toBe('turn left');
    expect(b1Card.front).toBe('boarding pass');

    const a2UzToEn = renderToStaticMarkup(<FlashcardDeck cards={[a2Card]} initialMode="uz_to_en" />);
    expect(a2UzToEn).toContain(a2Card.backUz);
    expect(a2UzToEn).not.toContain(a2Card.front);

    const b1AudioToWord = renderToStaticMarkup(
      <FlashcardDeck cards={[b1Card]} initialMode="audio_to_word" />,
    );
    expect(b1AudioToWord).toContain('Talaffuzni tinglash');
    expect(b1AudioToWord).not.toContain(b1Card.front);
    expect(b1AudioToWord).not.toContain(b1Card.backUz);

    // 6c. RoadmapView grouped CEFR rendering, SRS Hub A2/B1 flashcard unlocking, and per-level lock badges
    setDemoRuntimeActive(true);
    const engCourse = SEED_COURSES.find((c) => c.id === 'course_eng_01')!;
    const engSkills = SEED_SKILLS.filter((s) => s.courseId === 'course_eng_01');
    const baseNodes = SEED_ROADMAP_NODES['course_eng_01'];

    const renderRoadmapWithCompleted = (completedNodeIds: string[], completedLessonIds: string[]) => {
      const adapted = RouteEngine.adaptRoadmap(
        'course_eng_01',
        baseNodes,
        {},
        completedNodeIds,
        [],
      );
      const profile: LearnerProfile = {
        id: 'learner_test_m3',
        name: 'Test Learner',
        completedLessonIds,
        completedNodeIds,
        completedReinforcementIds: [],
        scoresByCourse: {},
        courseLevels: { course_eng_01: 'elementary' },
        placementCompleted: true,
        streak: 1,
        xp: 100,
      };
      useCourseStore.setState({
        courses: SEED_COURSES,
        activeCourse: engCourse,
        activeCourseSkills: engSkills,
        isLoading: false,
        error: null,
      });
      useLearnerStore.setState({ profile, isLoading: false });
      useRoadmapStore.setState({ roadmap: adapted, isLoading: false, error: null });

      return renderToStaticMarkup(
        <AuthProvider>
          <RoadmapView
            onStartLesson={() => {}}
            onOpenKnowledgeMap={() => {}}
            onChooseCourse={() => {}}
            onConfigure={() => {}}
          />
        </AuthProvider>,
      );
    };

    // Case 1: A1 exit completed -> A1 & A2 Available, B1 & B2 Locked; SRS Hub includes A1 (17) + A2 M1 (4) = 21 cards
    const afterA1Completed = ENGLISH_A1_ROADMAP_NODES.map((n) => n.id);
    const afterA1LessonIds = ENGLISH_A1_LESSONS_LIST.map((l) => l.id);
    const htmlAfterA1 = renderRoadmapWithCompleted(afterA1Completed, afterA1LessonIds);

    expect(htmlAfterA1).toContain('data-cefr-level="A1"');
    expect(htmlAfterA1).toContain('data-cefr-level="A2"');
    expect(htmlAfterA1).toContain('data-cefr-level="B1"');
    expect(htmlAfterA1).toContain('data-cefr-level="B2"');
    expect(htmlAfterA1).toContain('data-cefr-level="C1"');
    expect(htmlAfterA1).toContain('data-cefr-level="C2"');
    expect(htmlAfterA1).toContain('Flashcard takrorlash (21)');

    const a2SectionAfterA1 = extractSectionByCefr(htmlAfterA1, 'A2');
    expect(a2SectionAfterA1).toContain('Ochiq');
    expect(a2SectionAfterA1).not.toContain('Avval yakunlang · A1');
    expect(a2SectionAfterA1).toContain('data-node-id="node_eng_a2_m1_directions"');
    expect(a2SectionAfterA1).toContain('data-node-id="node_eng_a2_exit"');
    expect(a2SectionAfterA1).toContain('Darsni boshlash');
    expect(a2SectionAfterA1).not.toContain('Rejalashtirilgan grammatika va lug‘at qamrovi');

    const b1SectionAfterA1 = extractSectionByCefr(htmlAfterA1, 'B1');
    expect(b1SectionAfterA1).toContain('Qulflangan');
    expect(b1SectionAfterA1).toContain('Avval yakunlang · A2');
    expect(b1SectionAfterA1).toContain('data-node-id="node_eng_b1_m1_travel"');
    expect(b1SectionAfterA1).toContain('data-node-id="node_eng_b1_exit"');
    expect(b1SectionAfterA1).not.toContain('Darsni boshlash');

    // Case 2: A1 + A2 exit completed -> B1 Available (SRS Hub = 17 A1 + 16 A2 + 4 B1 M1 = 37), B2 still Locked
    const afterA2Completed = [...afterA1Completed, ...ENGLISH_A2_ROADMAP_NODES.map((n) => n.id)];
    const afterA2LessonIds = [...afterA1LessonIds, ...ENGLISH_A2_LESSONS_LIST.map((l) => l.id)];
    const htmlAfterA2 = renderRoadmapWithCompleted(afterA2Completed, afterA2LessonIds);

    expect(htmlAfterA2).toContain('Flashcard takrorlash (37)');

    const b1SectionAfterA2 = extractSectionByCefr(htmlAfterA2, 'B1');
    expect(b1SectionAfterA2).toContain('Ochiq');
    expect(b1SectionAfterA2).not.toContain('Avval yakunlang · A2');
    expect(b1SectionAfterA2).toContain('Darsni boshlash');
    expect(b1SectionAfterA2).not.toContain('Rejalashtirilgan grammatika va lug‘at qamrovi');

    const b2SectionAfterA2 = extractSectionByCefr(htmlAfterA2, 'B2');
    expect(b2SectionAfterA2).toContain('Qulflangan');
    expect(b2SectionAfterA2).toContain('Avval yakunlang · B1');
    expect(b2SectionAfterA2).toContain('Rejalashtirilgan grammatika va lug‘at qamrovi');

    // Case 3: A1 + A2 + B1 exit completed -> SRS Hub has all 49 cards, unpopulated B2 remains Locked
    const afterB1Completed = [...afterA2Completed, ...ENGLISH_B1_ROADMAP_NODES.map((n) => n.id)];
    const afterB1LessonIds = [...afterA2LessonIds, ...ENGLISH_B1_LESSONS_LIST.map((l) => l.id)];
    const htmlAfterB1 = renderRoadmapWithCompleted(afterB1Completed, afterB1LessonIds);

    expect(htmlAfterB1).toContain('Flashcard takrorlash (49)');

    const b2SectionAfterB1 = extractSectionByCefr(htmlAfterB1, 'B2');
    expect(b2SectionAfterB1).toContain('Qulflangan');
    expect(b2SectionAfterB1).not.toContain('Ochiq');
    expect(b2SectionAfterB1).toContain('Avval yakunlang · B1');
    expect(b2SectionAfterB1).toContain('Rejalashtirilgan grammatika va lug‘at qamrovi');

    // Check cefr-skeleton raw JSON still matches the rendered level count
    const skeleton = JSON.parse(readFileSync('content/english/cefr-skeleton.json', 'utf8'));
    expect(skeleton.levels).toHaveLength(6);
  });
});
