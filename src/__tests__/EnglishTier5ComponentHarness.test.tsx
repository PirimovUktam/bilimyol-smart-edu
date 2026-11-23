import React from 'react';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { message } from '@/core/locales/messages';
import type { LessonFlashcard } from '@/domain/entities/Lesson';
import { SEED_COURSES } from '@/data/datasources/courses';
import { SEED_SKILLS } from '@/data/datasources/skills';
import { setDemoRuntimeActive } from '@/core/runtime/demoRuntime';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { useLessonStore } from '@/app/store/useLessonStore';

const hookState: {
  slots: unknown[];
  idx: number;
  effectCleanups: Array<(() => void) | undefined>;
  effectDeps: Array<readonly unknown[] | undefined>;
  pendingEffects: Array<{ slot: number; fn: () => void | (() => void); deps?: readonly unknown[] }>;
} = {
  slots: [],
  idx: 0,
  effectCleanups: [],
  effectDeps: [],
  pendingEffects: [],
};

function resetHarness() {
  for (const cleanup of hookState.effectCleanups) {
    cleanup?.();
  }
  hookState.slots = [];
  hookState.idx = 0;
  hookState.effectCleanups = [];
  hookState.effectDeps = [];
  hookState.pendingEffects = [];
}

function depsChanged(prev: readonly unknown[] | undefined, next: readonly unknown[] | undefined): boolean {
  if (!prev || !next) return true;
  if (prev.length !== next.length) return true;
  return next.some((item, i) => !Object.is(item, prev[i]));
}

function flushEffects() {
  const toRun = [...hookState.pendingEffects];
  hookState.pendingEffects = [];
  for (const eff of toRun) {
    if (depsChanged(hookState.effectDeps[eff.slot], eff.deps)) {
      hookState.effectCleanups[eff.slot]?.();
      hookState.effectDeps[eff.slot] = eff.deps;
      const cleanup = eff.fn();
      hookState.effectCleanups[eff.slot] = typeof cleanup === 'function' ? cleanup : undefined;
    }
  }
}

function findButtons(node: React.ReactNode, acc: Array<{ text: string; onClick?: () => void; disabled?: boolean }> = []) {
  if (node == null || typeof node !== 'object') return acc;
  if (Array.isArray(node)) {
    node.forEach((child) => findButtons(child, acc));
    return acc;
  }
  if (React.isValidElement(node)) {
    const props = node.props as Record<string, unknown>;
    const isButtonTag = node.type === 'button' || (typeof node.type === 'function' && /Button/.test(node.type.name));
    if (isButtonTag) {
      acc.push({
        text: extractText(node),
        onClick: typeof props.onClick === 'function' ? (props.onClick as () => void) : undefined,
        disabled: Boolean(props.disabled),
      });
    }
    if (props.children) findButtons(props.children as React.ReactNode, acc);
  }
  return acc;
}

function extractText(node: React.ReactNode): string {
  if (node == null || typeof node === 'boolean') return '';
  if (typeof node === 'string' || typeof node === 'number') return String(node);
  if (Array.isArray(node)) return node.map(extractText).join(' ');
  if (React.isValidElement(node)) {
    const props = node.props as Record<string, unknown>;
    return props.children !== undefined ? extractText(props.children as React.ReactNode) : '';
  }
  return '';
}

vi.mock('@/core/locales/useTranslation', () => ({
  useTranslation: () => ({
    language: 'uz' as const,
    t: (key: Parameters<typeof message>[1], values?: Record<string, string | number>) =>
      message('uz', key, values),
  }),
  translate: (key: Parameters<typeof message>[1], values?: Record<string, string | number>) =>
    message('uz', key, values),
}));

vi.mock('@/core/context/AuthContext', () => ({
  useAuth: () => ({
    profile: { id: 'guest_user_01', role: 'learner' },
    session: null,
    isDemoMode: true,
    isPasswordRecovery: false,
    isLoading: false,
  }),
}));

vi.mock('zustand', async (importOriginal) => {
  const actual = await importOriginal<typeof import('zustand')>();
  return {
    ...actual,
    create: ((createState: Parameters<typeof actual.create>[0]) => {
      if (!createState) return actual.create;
      const api = actual.create(createState);
      return Object.assign(
        (selector: (state: unknown) => unknown = (state) => state) => selector(api.getState()),
        api,
      );
    }) as typeof actual.create,
  };
});

vi.mock('react', async (importOriginal) => {
  const actual = await importOriginal<typeof import('react')>();
  return {
    ...actual,
    useState: <T,>(initial: T | (() => T)): [T, React.Dispatch<React.SetStateAction<T>>] => {
      const slot = hookState.idx++;
      if (!(slot in hookState.slots)) {
        hookState.slots[slot] = typeof initial === 'function' ? (initial as () => T)() : initial;
      }
      const setState: React.Dispatch<React.SetStateAction<T>> = (next) => {
        hookState.slots[slot] =
          typeof next === 'function'
            ? (next as (prev: T) => T)(hookState.slots[slot] as T)
            : next;
      };
      return [hookState.slots[slot] as T, setState];
    },
    useMemo: <T,>(fn: () => T) => fn(),
    useRef: <T,>(initial: T) => {
      const slot = hookState.idx++;
      if (!(slot in hookState.slots)) {
        hookState.slots[slot] = { current: initial };
      }
      return hookState.slots[slot] as React.MutableRefObject<T>;
    },
    useId: () => `harness-id-${hookState.idx++}`,
    useEffect: (fn: () => void | (() => void), deps?: readonly unknown[]) => {
      const slot = hookState.idx++;
      hookState.pendingEffects.push({ slot, fn, deps });
    },
    useCallback: <T extends (...args: never[]) => unknown>(fn: T) => fn,
  };
});

describe('Tier 5 Component Hook Harness Regressions', () => {
  beforeEach(() => {
    resetHarness();
    setDemoRuntimeActive(true);
    useLessonStore.getState().clearSession();
    useCourseStore.getState().clearSession();
    useLearnerStore.getState().clearSession();
  });

  it('guards FlashcardDeck against double-click ratings on both Eslab qoldim and Yana maşq qilaman within one reveal', async () => {
    const { FlashcardDeck } = await import('@/features/lesson/FlashcardDeck');
    const cards: LessonFlashcard[] = [
      {
        id: 'fc_dc_1',
        front: 'Airport',
        backUz: 'Aeroport',
        backRu: 'Аэропорт',
        example: 'We arrived at the airport.',
        exampleUz: 'Biz aeroportga yetib keldik.',
        exampleRu: 'Мы приехали в аэропорт.',
      },
      {
        id: 'fc_dc_2',
        front: 'Ticket',
        backUz: 'Çipta',
        backRu: 'Билет',
        example: 'Here is my ticket.',
        exampleUz: 'Mana mening çiptam.',
        exampleRu: 'Вот мой билет.',
      },
    ];
    const onRateCard = vi.fn();
    const renderDeck = () => {
      hookState.idx = 0;
      const tree = FlashcardDeck({ cards, onRateCard });
      flushEffects();
      return tree;
    };

    // 1. Reveal card 1 and rapid double-click "Yana maşq qilaman"
    const initialTree = renderDeck();
    findButtons(initialTree).find((b) => b.text.includes('Javobni köriş'))!.onClick!();
    const revealed1 = renderDeck();
    const practiceBtn = findButtons(revealed1).find((b) => b.text.includes('Yana maşq qilaman'))!;
    practiceBtn.onClick!();
    practiceBtn.onClick!();
    expect(onRateCard).toHaveBeenCalledTimes(1);
    expect(onRateCard).toHaveBeenLastCalledWith('fc_dc_1', 'need_practice', undefined);

    // 2. Card 2 should now be active (not skipped by double-click), reveal and double-click "Eslab qoldim"
    const afterPractice = renderDeck();
    expect(extractText(afterPractice)).toContain('Ticket');
    findButtons(afterPractice).find((b) => b.text.includes('Javobni köriş'))!.onClick!();
    const revealed2 = renderDeck();
    const rememberedBtn = findButtons(revealed2).find((b) => b.text.includes('Eslab qoldim'))!;
    rememberedBtn.onClick!();
    rememberedBtn.onClick!();
    expect(onRateCard).toHaveBeenCalledTimes(2);
    expect(onRateCard).toHaveBeenLastCalledWith('fc_dc_2', 'remembered', undefined);

    // 3. Card 1 (requeued) must remain in queue — deck is NOT prematurely finished
    const afterRemember = renderDeck();
    const afterRememberText = extractText(afterRemember).replace(/\s+/g, ' ');
    expect(afterRememberText).toContain('Airport');
    expect(afterRememberText).toContain('1 / 2');
  });

  it('does not jump backwards to step 1 when switchToAlternateExercise runs on step > first exercise in lesson_eng_a1_exit', async () => {
    const { InteractiveLessonView } = await import('@/features/lesson/InteractiveLessonView');
    const engCourse = SEED_COURSES.find((c) => c.id === 'course_eng_01')!;
    useCourseStore.setState({
      courses: SEED_COURSES,
      activeCourse: engCourse,
      activeCourseSkills: SEED_SKILLS.filter((s) => s.courseId === 'course_eng_01'),
    });
    useLearnerStore.setState({
      profile: {
        id: 'guest_user_01',
        name: 'Learner',
        selectedCourseId: 'course_eng_01',
        goal: 'mastery',
        dailyMinutes: 15,
        initialLevel: 'intermediate',
        xp: 0,
        streakDays: 0,
        lastActiveDate: '',
        scoresByCourse: {},
        completedLessonIds: [],
        completedNodeIds: [],
        completedReinforcementIds: [],
        createdAt: 1000,
      },
      isLoading: false,
    });

    const store = new Map<string, string>();
    vi.stubGlobal('sessionStorage', {
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
    } as Storage);

    const renderView = () => {
      hookState.idx = 0;
      const tree = InteractiveLessonView({
        lessonId: 'lesson_eng_a1_exit',
        onFinish: () => {},
        onBackToRoadmap: () => {},
      });
      flushEffects();
      return tree;
    };

    // Initial mount loads lesson_eng_a1_exit; second render mimics React re-rendering with loaded lesson
    renderView();
    renderView();
    const exitLesson = useLessonStore.getState().currentLesson!;
    expect(exitLesson.id).toBe('lesson_eng_a1_exit');

    const firstQStep = exitLesson.steps.findIndex((s) => Boolean(s.interactiveQuestion));
    const secondQStep = exitLesson.steps.findIndex((s, i) => i > firstQStep && Boolean(s.interactiveQuestion));
    expect(firstQStep).toBe(1);
    expect(secondQStep).toBe(2);

    // Advance to step 2 (> first exercise step) and re-render so readingPosition saves
    useLessonStore.getState().goToStep(secondQStep);
    renderView();
    expect(useLessonStore.getState().currentStepIndex).toBe(secondQStep);

    // Switch to alternateExercise (creates new currentLesson object ref)
    expect(useLessonStore.getState().switchToAlternateExercise()).toBe(true);
    renderView();

    // Must remain on secondQStep (must NOT jump back to firstQStep)
    expect(useLessonStore.getState().currentStepIndex).toBe(secondQStep);
    expect(useLessonStore.getState().currentLesson?.steps[secondQStep].interactiveQuestion?.id).toBe(
      exitLesson.alternateExercise?.id,
    );

    vi.unstubAllGlobals();
  }, 15000);
});
