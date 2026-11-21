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
import { useLessonStore } from '@/app/store/useLessonStore';
import { InteractiveLessonView } from '@/features/lesson/InteractiveLessonView';

afterEach(async () => {
  useLessonStore.getState().clearSession();
  await usePreferences.getState().setLanguage('uz', false);
});

describe('InteractiveLessonView ru step category tab localization', () => {
  it('localizes step category tabs in ru locale while preserving eng_list_step_2 heading for T3-03', async () => {
    setDemoRuntimeActive(true);
    await loadRussian();
    await usePreferences.getState().setLanguage('ru', false);
    await useCourseStore.getState().loadCourses();
    await useCourseStore.getState().selectCourseById('course_eng_01');
    useLessonStore.getState().clearSession();

    await useLessonStore.getState().loadLesson('lesson_eng_a1_m1_greetings');
    const greetingsHtml = renderToStaticMarkup(
      <AuthProvider>
        <InteractiveLessonView
          lessonId="lesson_eng_a1_m1_greetings"
          onFinish={() => {}}
          onBackToRoadmap={() => {}}
        />
      </AuthProvider>,
    );
    expect(greetingsHtml).toContain('Теория');
    expect(greetingsHtml).toContain('Аудирование');
    expect(greetingsHtml).toContain('Карточки');
    expect(greetingsHtml).toContain('Тест');
    expect(greetingsHtml).not.toMatch(/\b(Nazariya|Misol|Tinglash|Test)\b/);

    useLessonStore.getState().clearSession();
    await useLessonStore.getState().loadLesson('lesson_eng_listening_01');
    useLessonStore.getState().goToStep(1);
    const listeningHtml = renderToStaticMarkup(
      <AuthProvider>
        <InteractiveLessonView
          lessonId="lesson_eng_listening_01"
          onFinish={() => {}}
          onBackToRoadmap={() => {}}
        />
      </AuthProvider>,
    );
    expect(listeningHtml).toContain('Audio Xabarni Tinglash');
  });
});
