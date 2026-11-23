import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { InMemoryLearnerRepository } from '@/data/repositories/InMemoryLearnerRepository';
import { mapLearnerLesson } from '@/data/repositories/SupabaseLessonRepository';
import { SEED_LESSONS } from '@/data/datasources/lessons';
import { SEED_ROADMAP_NODES } from '@/data/datasources/roadmaps';
import { RouteEngine } from '@/domain/personalization/RouteEngine';
import { usesMathMastery } from '@/domain/personalization/learningStart';
import { computeNextFlashcardSrs, isFlashcardDue } from '@/domain/personalization/FlashcardSrsEngine';
import { normalizeFreeTextAnswer } from '@/domain/entities/Question';
import { SubmitLessonAnswerUseCase } from '@/domain/usecases/SubmitLessonAnswerUseCase';
import { isIntegratedEnglishLesson, isValidAssessment, useLessonStore } from '@/app/store/useLessonStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { setDemoRuntimeActive } from '@/core/runtime/demoRuntime';
import { FlashcardDeck } from '@/features/lesson/FlashcardDeck';
import type { LessonFlashcard } from '@/domain/entities/Lesson';

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

describe('M2.2 Rich Exercises, Comma Normalization & Sanitization', () => {
  it('strips commas in normalizeFreeTextAnswer so comma-less and comma-ful inputs match and strips trailing punctuation clusters', () => {
    expect(normalizeFreeTextAnswer("Hi, my name's Sam!")).toBe("hi my name's sam");
    expect(normalizeFreeTextAnswer("Hi, my name's Sam!,")).toBe("hi my name's sam");
    expect(normalizeFreeTextAnswer("Hi my name's Sam")).toBe("hi my name's sam");
    expect(normalizeFreeTextAnswer('...,,,')).toBe('');
  });

  it('evaluates fill_blank, word_match, sentence_order, error_correction, conversation_completion, speaking_prompt, writing_prompt', async () => {
    const storage = createMemoryStorage();
    const repo = new InMemoryLearnerRepository(() => storage);
    const useCase = new SubmitLessonAnswerUseCase(repo);

    // 1. fill_blank
    const dailyLesson = SEED_LESSONS['lesson_eng_a1_m2_daily_life'];
    const fillQ = dailyLesson.steps.find((s) => s.interactiveQuestion)?.interactiveQuestion;
    expect(fillQ).toBeDefined();
    const fillWrong = await useCase.executeText(fillQ!, 'study', dailyLesson.id, undefined, 'uz');
    expect(fillWrong.isCorrect).toBe(false);
    const fillOk = await useCase.executeText(fillQ!, 'studies', dailyLesson.id, undefined, 'uz');
    expect(fillOk.isCorrect).toBe(true);

    // 2. word_match
    const greetLesson = SEED_LESSONS['lesson_eng_a1_m1_greetings'];
    const matchQ = greetLesson.steps.find((s) => s.interactiveQuestion)?.interactiveQuestion;
    expect(matchQ).toBeDefined();
    const wrongPairs: Record<string, string> = {};
    matchQ!.matchPairs!.forEach((p, idx, arr) => {
      wrongPairs[p.id] = arr[(idx + 1) % arr.length].id;
    });
    const matchWrong = await useCase.executeStructured(
      matchQ!,
      { serializedAnswer: JSON.stringify(wrongPairs), displayAnswer: 'wrong', matchPairs: wrongPairs },
      greetLesson.id,
      undefined,
      'uz',
    );
    expect(matchWrong.isCorrect).toBe(false);

    const rightPairs: Record<string, string> = {};
    matchQ!.matchPairs!.forEach((p) => {
      rightPairs[p.id] = p.id;
    });
    const matchOk = await useCase.executeStructured(
      matchQ!,
      { serializedAnswer: JSON.stringify(rightPairs), displayAnswer: 'right', matchPairs: rightPairs },
      greetLesson.id,
      undefined,
      'uz',
    );
    expect(matchOk.isCorrect).toBe(true);

    // 3. sentence_order
    const sbLesson = SEED_LESSONS['lesson_eng_a1_m2_sentence_builder'];
    const orderQ = sbLesson.steps.find((s) => s.interactiveQuestion)?.interactiveQuestion;
    expect(orderQ).toBeDefined();
    const reversed = [...orderQ!.orderedTokens!].reverse();
    const orderWrong = await useCase.executeStructured(
      orderQ!,
      { serializedAnswer: JSON.stringify(reversed), displayAnswer: reversed.join(' '), orderedTokens: reversed },
      sbLesson.id,
      undefined,
      'ru',
    );
    expect(orderWrong.isCorrect).toBe(false);
    const orderOk = await useCase.executeStructured(
      orderQ!,
      {
        serializedAnswer: JSON.stringify(orderQ!.orderedTokens!),
        displayAnswer: orderQ!.orderedTokens!.join(' '),
        orderedTokens: orderQ!.orderedTokens!,
      },
      sbLesson.id,
      undefined,
      'ru',
    );
    expect(orderOk.isCorrect).toBe(true);

    // 4. error_correction + conversation_completion mistakeFeedbackByOption
    const listLesson = SEED_LESSONS['lesson_eng_listening_01'];
    const listQ = listLesson.steps.find((s) => s.interactiveQuestion)?.interactiveQuestion;
    expect(listQ).toBeDefined();
    const amIdx = listQ!.options.indexOf('03:15 (quarter past three AM)');
    expect(amIdx).toBeGreaterThanOrEqual(0);
    const amWrong = await useCase.execute(listQ!, amIdx, listLesson.id, undefined, 'uz');
    expect(amWrong.isCorrect).toBe(false);
    expect(amWrong.explanation).toContain('in the afternoon');

    // 5. speaking_prompt & writing_prompt self-assessment
    const speakLesson = SEED_LESSONS['lesson_eng_a1_m1_speaking'];
    const speakQ = speakLesson.steps.find((s) => s.interactiveQuestion)?.interactiveQuestion;
    expect(speakQ).toBeDefined();
    const blankSpeak = await useCase.executeSelfAssessed(speakQ!, '   ', [], speakLesson.id, undefined, 'uz');
    expect(blankSpeak.isCorrect).toBe(false);
    const validSpeak = await useCase.executeSelfAssessed(
      speakQ!,
      'Hello! My name is Sam. I am from Tashkent.',
      ['crit_greet'],
      speakLesson.id,
      undefined,
      'uz',
    );
    expect(validSpeak.isCorrect).toBe(true);

    const writeLesson = SEED_LESSONS['lesson_eng_a1_m4_writing'];
    const writeQ = writeLesson.steps.find((s) => s.interactiveQuestion)?.interactiveQuestion;
    expect(writeQ).toBeDefined();
    const validWrite = await useCase.executeSelfAssessed(
      writeQ!,
      'My desk is beside the window.',
      ['crit_w_greet'],
      writeLesson.id,
      undefined,
      'ru',
    );
    expect(validWrite.isCorrect).toBe(true);
  });

  it('validates all 9 modes in isValidAssessment and preserves rich fields in mapLearnerLesson without leaking keys', () => {
    for (const lesson of Object.values(SEED_LESSONS)) {
      if (lesson.courseId !== 'course_eng_01') continue;
      const allowMulti = isIntegratedEnglishLesson(lesson);
      for (const step of lesson.steps) {
        if (step.interactiveQuestion) {
          expect(isValidAssessment(step.interactiveQuestion, lesson.courseId, lesson.skillId, allowMulti)).toBe(true);
        }
      }
      expect(isValidAssessment(lesson.reinforcementExercise, lesson.courseId, lesson.skillId, allowMulti)).toBe(true);
      if (lesson.alternateExercise) {
        expect(isValidAssessment(lesson.alternateExercise, lesson.courseId, lesson.skillId, allowMulti)).toBe(true);
      }
    }

    const rawWordMatch = SEED_LESSONS['lesson_eng_a1_m1_greetings'];
    const mapped = mapLearnerLesson({
      id: rawWordMatch.id,
      course_id: rawWordMatch.courseId,
      skill_id: rawWordMatch.skillId,
      title: rawWordMatch.title,
      summary: rawWordMatch.summary,
      steps: rawWordMatch.steps,
      reinforcement_exercise: rawWordMatch.reinforcementExercise,
    });
    const q = mapped.steps.find((s) => s.interactiveQuestion)?.interactiveQuestion;
    expect(q?.questionType).toBe('word_match');
    expect(q?.matchPairs?.length).toBeGreaterThanOrEqual(3);
    expect(mapped.reinforcementExercise.questionType).toBe('conversation_completion');
    expect(mapped.reinforcementExercise.correctIndex).toBeUndefined();
    expect(mapped.reinforcementExercise.explanation).toBe('');
  });
});

describe('M2.2 SRS Flashcards, Polarity & Course Isolation', () => {
  const sampleCards: LessonFlashcard[] = [
    {
      id: 'fc_test_1',
      front: "What's your name?",
      backUz: 'Ismingiz nima?',
      backRu: 'Как вас зовут?',
      ipa: '/wɒts jɔː neɪm/',
      example: "Hi, I'm Aziza. What's your name?",
      exampleUz: 'Salom, men Azizaman. Ismingiz nima?',
      exampleRu: 'Привет, я Азиза. Как тебя зовут?',
      audioSrc: '/lesson-media/english/a1-starter-whats-your-name.wav',
      imageSrc: '/lesson-media/english/a1-starter-greeting.png',
      alt: 'Two students greeting outside a school',
    },
  ];

  it('persists flashcardSrsByCourse across repository reloads with [0,1,3,7,14] buckets', async () => {
    const storage = createMemoryStorage();
    const repo = new InMemoryLearnerRepository(() => storage);

    const afterPractice = await repo.recordFlashcardSrs('course_eng_01', 'fc_test_1', 'need_practice');
    expect(afterPractice.flashcardSrsByCourse?.['course_eng_01']?.['fc_test_1']?.status).toBe('need_practice');
    expect(afterPractice.flashcardSrsByCourse?.['course_eng_01']?.['fc_test_1']?.intervalDays).toBe(0);

    const afterRemember1 = await repo.recordFlashcardSrs('course_eng_01', 'fc_test_1', 'remembered');
    const entry1 = afterRemember1.flashcardSrsByCourse?.['course_eng_01']?.['fc_test_1'];
    expect(entry1?.status).toBe('remembered');
    expect(entry1?.intervalDays).toBe(1);
    expect(isFlashcardDue(entry1)).toBe(false);

    const entry2 = computeNextFlashcardSrs(entry1, 'fc_test_1', 'remembered');
    expect(entry2.intervalDays).toBe(3);

    const reloaded = new InMemoryLearnerRepository(() => storage);
    const loadedProfile = await reloaded.getProfile();
    expect(loadedProfile.flashcardSrsByCourse?.['course_eng_01']?.['fc_test_1']?.intervalDays).toBe(1);
    expect(loadedProfile.flashcardSrsByCourse?.['course_math_01']).toBeUndefined();
  });

  it('hides target text on uz_to_en, audio_to_word, and image_to_word modes before reveal', () => {
    const uzToEnHtml = renderToStaticMarkup(
      <FlashcardDeck cards={sampleCards} initialMode="uz_to_en" />,
    );
    expect(uzToEnHtml).toContain('Ismingiz nima?');
    expect(uzToEnHtml).not.toContain("What&#x27;s your name?");

    const audioToWordHtml = renderToStaticMarkup(
      <FlashcardDeck cards={sampleCards} initialMode="audio_to_word" />,
    );
    expect(audioToWordHtml).toContain('Talaffuzni tinglaş');
    expect(audioToWordHtml).not.toContain("What&#x27;s your name?");
    expect(audioToWordHtml).not.toContain('Ismingiz nima?');

    const imageToWordHtml = renderToStaticMarkup(
      <FlashcardDeck cards={sampleCards} initialMode="image_to_word" />,
    );
    expect(imageToWordHtml).toContain('a1-starter-greeting.png');
    expect(imageToWordHtml).not.toContain("What&#x27;s your name?");
    expect(imageToWordHtml).not.toContain('Ismingiz nima?');

    const emptyHtml = renderToStaticMarkup(
      <FlashcardDeck cards={sampleCards} startEmptyWhenAllDone />,
    );
    expect(emptyHtml).toContain('Bugungi takrorlaş yakunlandi');
    expect(emptyHtml).toContain('Tasodifiy maşq');
  });

  it('keeps course_eng_01 isolated from usesMathMastery and preserves CEFR metadata on RouteEngine reinforcement nodes', () => {
    expect(usesMathMastery('course_eng_01')).toBe(false);
    const adapted = RouteEngine.adaptRoadmap(
      'course_eng_01',
      SEED_ROADMAP_NODES['course_eng_01'],
      {
        skill_eng_listening: {
          skillId: 'skill_eng_listening',
          courseId: 'course_eng_01',
          score: 40,
          lastUpdated: Date.now(),
          masteryLevel: 'beginner',
        },
      },
      ['node_eng_vocab', 'node_eng_gram'],
      [],
    );
    const reinf = adapted.nodes.find((n) => n.id === 'reinf_node_eng_list');
    expect(reinf).toBeDefined();
    expect(reinf?.cefrLevel).toBe('A1');
    expect(reinf?.moduleId).toBe('mod_eng_a1_m3');
  });

  it('keeps self-assessed lessons open after submit so learner can review model/rubric before completing via nextStep', async () => {
    setDemoRuntimeActive(true);
    useLessonStore.getState().clearSession();
    await useLearnerStore.getState().loadProfile();
    await useLessonStore.getState().loadLesson('lesson_eng_a1_m1_speaking');

    const lesson = useLessonStore.getState().currentLesson!;
    expect(lesson).toBeDefined();
    const lastStepIdx = lesson.steps.length - 1;
    useLessonStore.getState().goToStep(lastStepIdx);

    const result = await useLessonStore.getState().submitSelfAssessment(
      'Hello! My name is Sam. I am from Tashkent.',
      ['crit_greet'],
    );
    expect(result?.isCorrect).toBe(true);
    expect(useLessonStore.getState().isCompleted).toBe(false);
    expect(useLessonStore.getState().answeredQuestionIds).toContain(
      lesson.steps[lastStepIdx].interactiveQuestion!.id,
    );

    await useLessonStore.getState().nextStep();
    expect(useLessonStore.getState().isCompleted).toBe(true);
    expect(useLearnerStore.getState().profile?.completedLessonIds).toContain('lesson_eng_a1_m1_speaking');
    useLessonStore.getState().clearSession();
  });

  it('guards switchToAlternateExercise against duplicating alternateExercise across multi-step lessons and canonicalizes word_match idempotency', async () => {
    setDemoRuntimeActive(true);
    useLessonStore.getState().clearSession();
    await useLessonStore.getState().loadLesson('lesson_eng_a1_exit');
    const exitLesson = useLessonStore.getState().currentLesson!;
    const firstQuestionStep = exitLesson.steps.findIndex((s) => Boolean(s.interactiveQuestion));
    const secondQuestionStep = exitLesson.steps.findIndex(
      (s, idx) => idx > firstQuestionStep && Boolean(s.interactiveQuestion),
    );
    expect(firstQuestionStep).toBeGreaterThanOrEqual(0);
    expect(secondQuestionStep).toBeGreaterThan(firstQuestionStep);

    useLessonStore.getState().goToStep(firstQuestionStep);
    expect(useLessonStore.getState().switchToAlternateExercise()).toBe(true);
    useLessonStore.getState().goToStep(secondQuestionStep);
    expect(useLessonStore.getState().switchToAlternateExercise()).toBe(false);
    const altOccurrences = useLessonStore
      .getState()
      .currentLesson!.steps.filter((s) => s.interactiveQuestion?.id === exitLesson.alternateExercise!.id);
    expect(altOccurrences).toHaveLength(1);
    useLessonStore.getState().clearSession();

    // Canonical word_match idempotency & single-question XP cap for free-text
    const repo = new InMemoryLearnerRepository();
    const greetLesson = SEED_LESSONS['lesson_eng_a1_m1_greetings'];
    const matchQ = greetLesson.steps.find((s) => Boolean(s.interactiveQuestion))!.interactiveQuestion!;
    const pairsForward = Object.fromEntries(matchQ.matchPairs!.map((p) => [p.id, p.id]));
    const pairsReversed = Object.fromEntries([...matchQ.matchPairs!].reverse().map((p) => [p.id, p.id]));
    const res1 = await repo.submitAnswerAttempt({
      courseId: greetLesson.courseId,
      skillId: greetLesson.skillId,
      lessonId: greetLesson.id,
      questionId: matchQ.id,
      questionType: 'word_match',
      selectedIndex: 0,
      selectedAnswer: JSON.stringify(pairsForward),
      timeSpentSeconds: 2,
    });
    const res2 = await repo.submitAnswerAttempt({
      courseId: greetLesson.courseId,
      skillId: greetLesson.skillId,
      lessonId: greetLesson.id,
      questionId: matchQ.id,
      questionType: 'word_match',
      selectedIndex: 0,
      selectedAnswer: JSON.stringify(pairsReversed),
      timeSpentSeconds: 2,
    });
    expect(res1.xpAwarded).toBe(2);
    expect(res2.alreadyProcessed).toBe(true);
    expect(res2.xpAwarded).toBe(0);

    // Free-text starter hints are scoped to starter quiz, and distinct valid answers only award +2 XP once
    const fillLesson = SEED_LESSONS['lesson_eng_a1_m2_daily_life'];
    const fillQ = fillLesson.steps.find((s) => Boolean(s.interactiveQuestion))!.interactiveQuestion!;
    const fillHi = await repo.submitAnswerAttempt({
      courseId: fillLesson.courseId,
      skillId: fillLesson.skillId,
      lessonId: fillLesson.id,
      questionId: fillQ.id,
      questionType: 'fill_blank',
      selectedIndex: 0,
      selectedAnswer: 'hi',
      timeSpentSeconds: 2,
      language: 'uz',
    });
    expect(fillHi.isCorrect).toBe(false);
    expect(fillHi.explanation).toBe(fillQ.wrongFeedback);
    expect(fillHi.explanation).not.toContain('Salomlaşiş yaxşi');

    const starterLesson = SEED_LESSONS['lesson_eng_starter'];
    const starterQ = starterLesson.steps.find((s) => Boolean(s.interactiveQuestion))!.interactiveQuestion!;
    const xpBefore = (await repo.getProfile()).xp;
    const starterOk1 = await repo.submitAnswerAttempt({
      courseId: starterLesson.courseId,
      skillId: starterLesson.skillId,
      lessonId: starterLesson.id,
      questionId: starterQ.id,
      questionType: 'text_input',
      selectedIndex: 0,
      selectedAnswer: "I'm Sam",
      timeSpentSeconds: 2,
    });
    const starterOk2 = await repo.submitAnswerAttempt({
      courseId: starterLesson.courseId,
      skillId: starterLesson.skillId,
      lessonId: starterLesson.id,
      questionId: starterQ.id,
      questionType: 'text_input',
      selectedIndex: 0,
      selectedAnswer: 'My name is Sam',
      timeSpentSeconds: 2,
    });
    expect(starterOk1.xpAwarded).toBe(2);
    expect(starterOk2.xpAwarded).toBe(0);
    expect((await repo.getProfile()).xp).toBe(xpBefore + 2);
  });
});
