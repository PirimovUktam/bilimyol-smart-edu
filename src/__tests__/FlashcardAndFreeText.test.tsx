import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import {
  matchesAcceptedAnswer,
  normalizeFreeTextAnswer,
} from '@/domain/entities/Question';
import { InMemoryLearnerRepository } from '@/data/repositories/InMemoryLearnerRepository';
import { SubmitLessonAnswerUseCase } from '@/domain/usecases/SubmitLessonAnswerUseCase';
import { SEED_LESSONS } from '@/data/datasources/lessons';
import {
  FlashcardDeck,
  markDeckCardRemembered,
  requeueDeckCard,
} from '@/features/lesson/FlashcardDeck';
import type { LessonFlashcard } from '@/domain/entities/Lesson';

describe('Free-text normalization & matching', () => {
  it('normalizes whitespace, curly and Uzbek apostrophes, casing, and trailing punctuation', () => {
    expect(normalizeFreeTextAnswer("  I’m   Sam! ")).toBe("i'm sam");
    expect(normalizeFreeTextAnswer("I\u02BCm Sam")).toBe("i'm sam");
    expect(normalizeFreeTextAnswer("I\u02BBm Sam")).toBe("i'm sam");
    expect(normalizeFreeTextAnswer("MY NAME IS SAM.")).toBe('my name is sam');
    expect(normalizeFreeTextAnswer('   ')).toBe('');
  });

  it('matches all accepted variants while rejecting partial or off-topic inputs', () => {
    const accepted = ["I'm Sam", 'I am Sam', 'My name is Sam', "My name's Sam"];
    expect(matchesAcceptedAnswer("I'm Sam", accepted)).toBe(true);
    expect(matchesAcceptedAnswer("  I’m  Sam! ", accepted)).toBe(true);
    expect(matchesAcceptedAnswer("I\u02BCm Sam", accepted)).toBe(true);
    expect(matchesAcceptedAnswer("I\u02BBm Sam", accepted)).toBe(true);
    expect(matchesAcceptedAnswer('my name is sam.', accepted)).toBe(true);
    expect(matchesAcceptedAnswer('I am Sam?', accepted)).toBe(true);
    expect(matchesAcceptedAnswer('Sam', accepted)).toBe(false);
    expect(matchesAcceptedAnswer('Goodbye', accepted)).toBe(false);
    expect(matchesAcceptedAnswer('', accepted)).toBe(false);
  });
});

describe('InMemoryLearnerRepository free-text grading, retries & persistence', () => {
  it('avoids idempotency collisions across free-text retries and persists progress', async () => {
    const store = new Map<string, string>();
    const storage = {
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

    const repo = new InMemoryLearnerRepository(() => storage);
    const starter = SEED_LESSONS['lesson_eng_starter'];
    const question = starter.steps.find((s) => s.interactiveQuestion)!.interactiveQuestion!;
    const useCase = new SubmitLessonAnswerUseCase(repo);

    // 1. Bare name mistake
    const wrongSam = await useCase.executeText(question, 'Sam', starter.id, undefined, 'uz');
    expect(wrongSam.isCorrect).toBe(false);
    expect(wrongSam.correctOption).toBe('');
    expect(wrongSam.explanation).toContain("I'm");

    // 1b. Repeated identical wrong text_input still returns targeted feedback with 0 XP
    const repeatedWrongSam = await useCase.executeText(question, 'Sam', starter.id, undefined, 'uz');
    expect(repeatedWrongSam.isCorrect).toBe(false);
    expect(repeatedWrongSam.xpAwarded).toBe(0);
    expect(repeatedWrongSam.correctOption).toBe('');
    expect(repeatedWrongSam.explanation).toContain("I'm");

    // 2. Farewell mistake (same selectedIndex = 0, different text -> must NOT collide!)
    const wrongBye = await useCase.executeText(question, 'Goodbye', starter.id, undefined, 'uz');
    expect(wrongBye.isCorrect).toBe(false);
    expect(wrongBye.explanation).toContain('Goodbye');

    // 3. Valid answer succeeds and updates skill score & XP
    const correct = await useCase.executeText(question, "I'm Sam", starter.id, undefined, 'uz');
    expect(correct.isCorrect).toBe(true);
    expect(correct.xpAwarded).toBe(2);

    // 3b. Direct repository caller omitting questionType still uses text:-keyed idempotency
    //     and repeated identical wrong submission preserves targeted feedback with alreadyProcessed: true
    const directRepo = new InMemoryLearnerRepository();
    const directWrong = await directRepo.submitAnswerAttempt({
      courseId: question.courseId,
      skillId: question.skillId,
      lessonId: starter.id,
      questionId: question.id,
      selectedIndex: 0,
      selectedAnswer: 'Sam',
      timeSpentSeconds: 3,
      language: 'uz',
    });
    expect(directWrong.isCorrect).toBe(false);
    expect(directWrong.alreadyProcessed).toBe(false);
    const directRepeatWrong = await directRepo.submitAnswerAttempt({
      courseId: question.courseId,
      skillId: question.skillId,
      lessonId: starter.id,
      questionId: question.id,
      selectedIndex: 0,
      selectedAnswer: 'Sam',
      timeSpentSeconds: 3,
      language: 'uz',
    });
    expect(directRepeatWrong.isCorrect).toBe(false);
    expect(directRepeatWrong.alreadyProcessed).toBe(true);
    expect(directRepeatWrong.xpAwarded).toBe(0);
    expect(directRepeatWrong.correctOption).toBeUndefined();
    expect(directRepeatWrong.explanation).toContain("I'm");
    const directCorrect = await directRepo.submitAnswerAttempt({
      courseId: question.courseId,
      skillId: question.skillId,
      lessonId: starter.id,
      questionId: question.id,
      selectedIndex: 0,
      selectedAnswer: "I'm Sam",
      timeSpentSeconds: 3,
      language: 'uz',
    });
    expect(directCorrect.isCorrect).toBe(true);
    expect(directCorrect.alreadyProcessed).toBe(false);

    await repo.markLessonCompleted(starter.id, starter.courseId);

    // 4. Reloaded repository restores completion, XP, and English skill score
    const reloaded = new InMemoryLearnerRepository(() => storage);
    const profile = await reloaded.getProfile();
    expect(profile.completedLessonIds).toContain('lesson_eng_starter');
    expect(profile.xp).toBeGreaterThanOrEqual(22);
    expect(profile.scoresByCourse['course_eng_01']?.['skill_eng_vocab']?.score).toBe(100);
    expect(profile.scoresByCourse['course_math_01']).toBeUndefined();
  });
});

describe('FlashcardDeck state & SSR rendering', () => {
  const sampleCards: LessonFlashcard[] = [
    {
      id: 'fc_1',
      front: "What's your name?",
      backUz: 'Ismingiz nima?',
      backRu: 'Как вас зовут?',
      ipa: '/wɒts jɔː neɪm/',
      partOfSpeech: 'phrase',
      cefrLevel: 'A1',
      example: "Hi, I'm Aziza. What's your name?",
      exampleUz: 'Salom, men Azizaman. Ismingiz nima?',
      exampleRu: 'Привет, я Азиза. Как тебя зовут?',
      audioSrc: '/lesson-media/english/a1-starter-whats-your-name.wav',
    },
    {
      id: 'fc_2',
      front: 'Nice to meet you.',
      backUz: 'Tanishganimdan xursandman.',
      backRu: 'Приятно познакомиться.',
      ipa: '/naɪs tə miːt juː/',
      partOfSpeech: 'phrase',
      cefrLevel: 'A1',
      example: "I'm Ben. Nice to meet you.",
      exampleUz: 'Men Benman. Tanishganimdan xursandman.',
      exampleRu: 'Я Бен. Приятно познакомиться.',
      audioSrc: '/lesson-media/english/a1-starter-nice-to-meet-you.wav',
    },
  ];

  it('re-queues need-practice cards and pops remembered cards', () => {
    const requeued = requeueDeckCard(sampleCards);
    expect(requeued.map((c) => c.id)).toEqual(['fc_2', 'fc_1']);

    const afterRemember = markDeckCardRemembered(requeued, []);
    expect(afterRemember.nextQueue.map((c) => c.id)).toEqual(['fc_1']);
    expect(afterRemember.nextRememberedIds).toEqual(['fc_2']);
  });

  it('renders front recall prompt without leaking the answer before reveal', () => {
    const html = renderToStaticMarkup(<FlashcardDeck cards={sampleCards} />);
    expect(html).toContain("What&#x27;s your name?");
    expect(html).toContain('Javobni ko‘rish');
    expect(html).toContain('Talaffuzni tinglash');
    expect(html).not.toContain('Ismingiz nima?');
    expect(html).not.toContain('Eslab qoldim');
  });
});
