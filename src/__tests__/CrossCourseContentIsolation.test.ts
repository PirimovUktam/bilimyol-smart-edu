import { describe, it, expect, vi, beforeEach } from 'vitest';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import {
  resolveContinuationLessonId,
  isLessonCourseMismatch,
  decideCourseReconciliation,
} from '../app/router/lessonResolution';
import {
  useCourseStore,
  resolveInitialCourse,
  ACTIVE_COURSE_STORAGE_KEY,
} from '../app/store/useCourseStore';
import { useLearnerStore } from '../app/store/useLearnerStore';
import { useLessonStore } from '../app/store/useLessonStore';
import { mapCourseSubject } from '../data/repositories/SupabaseCourseRepository';
import { resolveLessonCourseId } from '../data/repositories/SupabaseLearnerRepository';
import { supabaseLearnerRepository } from '../data/repositories/SupabaseLearnerRepository';
import { deriveReinforcementNodeId } from '../features/reinforcement/reinforcementNodeId';
import { GeminiAITutorService } from '../data/services/GeminiAITutorService';
import { GetRoadmapUseCase } from '../domain/usecases/GetRoadmapUseCase';
import { SubmitReinforcementUseCase } from '../domain/usecases/SubmitReinforcementUseCase';
import { inMemoryLessonRepository } from '../data/repositories/InMemoryLessonRepository';
import { InMemoryLearnerRepository } from '../data/repositories/InMemoryLearnerRepository';
import { SkillScoringEngine } from '../domain/personalization/SkillScoringEngine';
import { Question } from '../domain/entities/Question';

// ---------------------------------------------------------------------------
// localStorage polyfill for the node test environment (persistence tests)
// ---------------------------------------------------------------------------
const storageMap = new Map<string, string>();
(globalThis as Record<string, unknown>).localStorage = {
  getItem: (k: string) => (storageMap.has(k) ? (storageMap.get(k) as string) : null),
  setItem: (k: string, v: string) => void storageMap.set(k, String(v)),
  removeItem: (k: string) => void storageMap.delete(k),
  clear: () => storageMap.clear(),
};

const resetStores = () => {
  storageMap.clear();
  useCourseStore.setState({ courses: [], activeCourse: null, activeCourseSkills: [], isLoading: false });
  useLearnerStore.setState({ profile: null, isLoading: false });
};

describe('Cross-course content isolation regression', () => {
  beforeEach(() => {
    resetStores();
  });

  // -------------------------------------------------------------------------
  // RC1/RC2: active course persistence (courses[0] reset bug)
  // -------------------------------------------------------------------------
  describe('active course persistence', () => {
    it('resolveInitialCourse prefers the persisted course id', () => {
      const courses = [
        { id: 'course_eng_01' } as never,
        { id: 'course_math_01' } as never,
      ];
      expect(resolveInitialCourse(courses, 'course_math_01')?.id).toBe('course_math_01');
      expect(resolveInitialCourse(courses, null)?.id).toBe('course_eng_01');
      expect(resolveInitialCourse(courses, 'course_missing')?.id).toBe('course_eng_01');
      expect(resolveInitialCourse([], 'course_math_01')).toBeNull();
    });

    it('selectCourseById persists to localStorage AND learner profile', async () => {
      await useCourseStore.getState().loadCourses();
      await useCourseStore.getState().selectCourseById('course_eng_01');

      expect(useCourseStore.getState().activeCourse?.id).toBe('course_eng_01');
      expect(storageMap.get(ACTIVE_COURSE_STORAGE_KEY)).toBe('course_eng_01');

      const repoProfile = await supabaseLearnerRepository.getProfile();
      expect(repoProfile.selectedCourseId).toBe('course_eng_01');
      expect(useLearnerStore.getState().profile?.selectedCourseId).toBe('course_eng_01');
    });

    it('reload restores the previously selected course instead of courses[0]', async () => {
      await useCourseStore.getState().loadCourses();
      await useCourseStore.getState().selectCourseById('course_it');

      // Simulate full page reload: store state wiped, cache retained.
      useCourseStore.setState({ courses: [], activeCourse: null, activeCourseSkills: [] });
      useLearnerStore.setState({ profile: null });

      await useCourseStore.getState().loadCourses();

      expect(useCourseStore.getState().activeCourse?.id).toBe('course_it');
      expect(useCourseStore.getState().activeCourse?.id).not.toBe(
        useCourseStore.getState().courses[0]?.id
      );
    });
  });

  // -------------------------------------------------------------------------
  // RC4/RC8/RC9: lesson resolution is course-scoped
  // -------------------------------------------------------------------------
  describe('lesson resolution', () => {
    const mathCourse = {
      id: 'course_math_01',
      subject: 'mathematics',
      lessons: ['lesson_math_functions_01'],
    } as never;
    const engCourse = {
      id: 'course_eng_01',
      subject: 'english',
      lessons: ['lesson_eng_listening_01'],
    } as never;
    const itCourse = { id: 'course_it', subject: 'it', lessons: [] } as never;

    it('math continuation resolves to a math lesson', async () => {
      await useCourseStore.getState().loadCourses();
      useCourseStore.setState({ activeCourse: mathCourse });
      const roadmap = await new GetRoadmapUseCase(
        inMemoryLessonRepository,
        new InMemoryLearnerRepository()
      ).execute('course_math_01');

      const lessonId = resolveContinuationLessonId(mathCourse, roadmap);
      expect(lessonId).toBeTruthy();
      expect(lessonId).toContain('math');
    });

    it('english continuation resolves to an english lesson', async () => {
      const roadmap = await new GetRoadmapUseCase(
        inMemoryLessonRepository,
        new InMemoryLearnerRepository()
      ).execute('course_eng_01');

      const lessonId = resolveContinuationLessonId(engCourse, roadmap);
      expect(lessonId).toBeTruthy();
      expect(lessonId).toContain('eng');
    });

    it('stale (other-course) roadmap is ignored — no cross-course fallback', () => {
      const staleMathRoadmap = {
        courseId: 'course_math_01',
        nodes: [
          { targetLessonId: 'lesson_math_functions_01', status: 'available' },
        ],
      } as never;

      // English active + math roadmap loaded → must NOT yield the math lesson
      const lessonId = resolveContinuationLessonId(engCourse, staleMathRoadmap);
      expect(lessonId).toBe('lesson_eng_listening_01');
      expect(lessonId).not.toBe('lesson_math_functions_01');
    });

    it('course without lessons and without matching roadmap yields null (honest empty state)', () => {
      const staleEngRoadmap = { courseId: 'course_eng_01', nodes: [] } as never;
      expect(resolveContinuationLessonId(itCourse, staleEngRoadmap)).toBeNull();
      expect(resolveContinuationLessonId(itCourse, null)).toBeNull();
      expect(resolveContinuationLessonId(null, null)).toBeNull();
    });

    it('isLessonCourseMismatch detects foreign lessons', () => {
      expect(isLessonCourseMismatch({ courseId: 'course_math_01' }, engCourse)).toBe(true);
      expect(isLessonCourseMismatch({ courseId: 'course_eng_01' }, engCourse)).toBe(false);
      expect(isLessonCourseMismatch(null, engCourse)).toBe(false);
      expect(isLessonCourseMismatch({ courseId: 'course_math_01' }, null)).toBe(false);
    });
  });

  // -------------------------------------------------------------------------
  // RC3: subject mapping from DB column
  // -------------------------------------------------------------------------
  describe('course subject mapping', () => {
    it('uses the DB subject column as the source of truth', () => {
      expect(mapCourseSubject({ id: 'course_custom_1', subject: 'english' })).toBe('english');
      expect(mapCourseSubject({ id: 'course_custom_1', subject: 'it' })).toBe('it');
      expect(mapCourseSubject({ id: 'course_custom_1', subject: 'logic' })).toBe('logic');
      expect(mapCourseSubject({ id: 'course_custom_1', subject: 'mathematics' })).toBe('mathematics');
      expect(mapCourseSubject({ id: 'course_custom_1', subject: '  English ' })).toBe('english');
    });

    it('falls back to id inference only when subject is missing — never "not eng ⇒ math"', () => {
      expect(mapCourseSubject({ id: 'course_it', subject: null })).toBe('it');
      expect(mapCourseSubject({ id: 'course_logic', subject: null })).toBe('logic');
      expect(mapCourseSubject({ id: 'course_eng_01', subject: null })).toBe('english');
      expect(mapCourseSubject({ id: 'course_math_01', subject: null })).toBe('mathematics');
    });
  });

  // -------------------------------------------------------------------------
  // RC5: lesson/reinforcement attribution
  // -------------------------------------------------------------------------
  describe('lesson course attribution', () => {
    it('explicit course id wins', async () => {
      const id = await resolveLessonCourseId('lesson_x', 'course_it', {
        getLessonById: async () => ({ courseId: 'course_eng_01' }),
      });
      expect(id).toBe('course_it');
    });

    it('resolves via the lesson repository chain', async () => {
      const id = await resolveLessonCourseId('lesson_x', null, {
        getLessonById: async () => ({ courseId: 'course_eng_01' }),
      });
      expect(id).toBe('course_eng_01');
    });

    it('unknown lesson resolves to null (never a hardcoded course)', async () => {
      expect(
        await resolveLessonCourseId('lesson_x', null, { getLessonById: async () => null })
      ).toBeNull();
      expect(
        await resolveLessonCourseId('lesson_x', undefined, {
          getLessonById: async () => {
            throw new Error('db down');
          },
        })
      ).toBeNull();
    });

    it('resolves seed lessons through the real repository chain (supabase off)', async () => {
      const math = await resolveLessonCourseId('lesson_math_functions_01');
      expect(math).toBe('course_math_01');
      const eng = await resolveLessonCourseId('lesson_eng_listening_01');
      expect(eng).toBe('course_eng_01');
      const unknown = await resolveLessonCourseId('lesson_totally_unknown_xyz');
      expect(unknown).toBeNull();
    });
  });

  describe('SubmitReinforcementUseCase passes real course context', () => {
    const buildQuestion = (): Question => ({
      id: 'q_reinf_test',
      courseId: 'course_eng_01',
      skillId: 'skill_eng_listening',
      text: 'Which word means "muhim"?',
      options: ['important', 'beautiful', 'slow', 'open'],
      correctIndex: 0,
      difficulty: 'easy',
      explanation: 'important = muhim',
    });

    it('marks reinforcement with course/skill/score/XP context from the same call', async () => {
      const learnerRepo = new InMemoryLearnerRepository();
      await learnerRepo.saveSkillScores('course_eng_01', {
        skill_eng_listening: {
          skillId: 'skill_eng_listening',
          courseId: 'course_eng_01',
          score: 40,
          lastUpdated: Date.now(),
          masteryLevel: SkillScoringEngine.getMasteryLevel(40),
          isWeakestFocus: false,
        },
      });

      const markSpy = vi.spyOn(learnerRepo, 'markReinforcementCompleted');
      const saveSpy = vi.spyOn(learnerRepo, 'saveSkillScores');
      vi.spyOn(learnerRepo, 'submitAnswerAttempt').mockResolvedValue({
        isCorrect: true,
        explanation: 'Server verified',
        newSkillScore: 100,
        overallScore: 100,
        xpAwarded: 2,
      });

      const useCase = new SubmitReinforcementUseCase(learnerRepo, inMemoryLessonRepository);
      const result = await useCase.execute(
        'course_eng_01',
        'skill_eng_listening',
        'reinf_node_eng_list',
        buildQuestion(),
        0
      );

      expect(result.isCorrect).toBe(true);
      expect(markSpy).toHaveBeenCalledTimes(1);
      const [nodeId, ctx] = markSpy.mock.calls[0];
      expect(nodeId).toBe('reinf_node_eng_list');
      expect(ctx).toBeTruthy();
      expect(ctx?.courseId).toBe('course_eng_01');
      expect(ctx?.skillId).toBe('skill_eng_listening');
      expect(ctx?.beforeScore).toBe(40);
      expect(ctx?.afterScore).toBe(result.newScore);
      expect(typeof ctx?.xpAwarded).toBe('number');
      // score saved into the SAME course scope
      expect(saveSpy).toHaveBeenCalledTimes(1);
      expect(saveSpy.mock.calls[0][0]).toBe('course_eng_01');
    });
  });

  // -------------------------------------------------------------------------
  // RC6: reinforcement node id derivation
  // -------------------------------------------------------------------------
  describe('reinforcement node id derivation', () => {
    it('preserves RouteEngine backward-compatible ids (reinf_node_math_func / reinf_node_eng_list)', async () => {
      const learnerRepo = new InMemoryLearnerRepository();

      await learnerRepo.saveSkillScores('course_math_01', {
        skill_math_functions: {
          skillId: 'skill_math_functions',
          courseId: 'course_math_01',
          score: 40,
          lastUpdated: Date.now(),
          masteryLevel: SkillScoringEngine.getMasteryLevel(40),
          isWeakestFocus: false,
        },
      });
      const mathRoadmap = await new GetRoadmapUseCase(
        inMemoryLessonRepository,
        learnerRepo
      ).execute('course_math_01');
      expect(deriveReinforcementNodeId(mathRoadmap, 'course_math_01', 'skill_math_functions')).toBe(
        'reinf_node_math_func'
      );

      const learnerRepo2 = new InMemoryLearnerRepository();
      await learnerRepo2.saveSkillScores('course_eng_01', {
        skill_eng_listening: {
          skillId: 'skill_eng_listening',
          courseId: 'course_eng_01',
          score: 40,
          lastUpdated: Date.now(),
          masteryLevel: SkillScoringEngine.getMasteryLevel(40),
          isWeakestFocus: false,
        },
      });
      const engRoadmap = await new GetRoadmapUseCase(
        inMemoryLessonRepository,
        learnerRepo2
      ).execute('course_eng_01');
      expect(deriveReinforcementNodeId(engRoadmap, 'course_eng_01', 'skill_eng_listening')).toBe(
        'reinf_node_eng_list'
      );
    });

    it('never falls back to another course node (IT/logic get scoped ids)', () => {
      const engRoadmap = {
        courseId: 'course_eng_01',
        nodes: [{ id: 'reinf_node_eng_list', isReinforcement: true, skillId: 'skill_eng_listening' }],
      } as never;

      const itId = deriveReinforcementNodeId(engRoadmap, 'course_it', 'skill_it_basics');
      expect(itId).toBe('reinf_course_it_skill_it_basics');
      expect(itId).not.toBe('reinf_node_eng_list');
      expect(itId).not.toBe('reinf_node_math_func');

      const logicId = deriveReinforcementNodeId(null, 'course_logic', 'skill_logic_patterns');
      expect(logicId).toBe('reinf_course_logic_skill_logic_patterns');
    });

    it('matching-course roadmap with no matching skill yields scoped fallback', () => {
      const roadmap = { courseId: 'course_it', nodes: [] } as never;
      expect(deriveReinforcementNodeId(roadmap, 'course_it', 'skill_it_x')).toBe(
        'reinf_course_it_skill_it_x'
      );
    });
  });

  // -------------------------------------------------------------------------
  // RC7: subject-aware AI fallback questions
  // -------------------------------------------------------------------------
  describe('AI fallback questions are subject-scoped', () => {
    const svc = new GeminiAITutorService();

    it('english fallback question contains no math content and keeps request courseId', async () => {
      const q = await svc.generateQuestion({
        courseId: 'course_eng_01',
        skillId: 'skill_eng_vocab',
        difficulty: 'medium',
      });
      expect(q.courseId).toBe('course_eng_01');
      expect(q.text).not.toContain('f(x)');
      expect(q.text).not.toContain('funksiya');
      expect(q.options).toHaveLength(4);
      expect(q.isDeterministicFallback).toBe(true);
      expect(q.isAiGenerated).toBe(false);
    });

    it('IT and logic fallback questions contain no math content', async () => {
      const it = await svc.generateQuestion({
        courseId: 'course_it',
        skillId: 'skill_it_basics',
        difficulty: 'easy',
      });
      expect(it.courseId).toBe('course_it');
      expect(it.text).not.toContain('f(x)');

      const logic = await svc.generateQuestion({
        courseId: 'course_logic',
        skillId: 'skill_logic_patterns',
        difficulty: 'easy',
      });
      expect(logic.courseId).toBe('course_logic');
      expect(logic.text).not.toContain('f(x)');
    });

    it('math fallback keeps the regression-tested math question', async () => {
      const q = await svc.generateQuestion({
        courseId: 'course_math_01',
        skillId: 'skill_math_functions',
        difficulty: 'medium',
      });
      expect(q.courseId).toBe('course_math_01');
      expect(q.text).toContain('f(x)');
      expect(q.options).toHaveLength(4);
    });

    it('generateReinforcement fallback is subject-scoped too', async () => {
      const eng = await svc.generateReinforcement({
        courseId: 'course_eng_01',
        skillId: 'skill_eng_listening',
        misconceptionTitle: 'kalit so‘zni o‘tkazib yubordi',
      });
      expect(eng.courseId).toBe('course_eng_01');
      expect(eng.text).not.toContain('f(x)');
    });
  });

  // -------------------------------------------------------------------------
  // Acceptance flow: AI lesson → exact lesson, flags surfaced
  // -------------------------------------------------------------------------
  describe('AI lesson generation flow', () => {
    it('generates an English lesson (not math) and loadLesson returns the exact id with flags', async () => {
      const lesson = await useLessonStore.getState().generateAILesson(
        'course_eng_01',
        'skill_eng_vocab',
        'Travel vocabulary',
        'medium'
      );

      expect(lesson).toBeTruthy();
      expect(lesson!.courseId).toBe('course_eng_01');
      expect(lesson!.isDeterministicFallback).toBe(true);
      expect(lesson!.isAiGenerated).toBe(false);

      const serialized = JSON.stringify(lesson!.steps) + lesson!.title;
      expect(serialized).not.toContain('f(x) = 3x');
      expect(serialized).not.toContain('f(x) = 2x');

      await useLessonStore.getState().loadLesson(lesson!.id);
      expect(useLessonStore.getState().currentLesson?.id).toBe(lesson!.id);
      expect(useLessonStore.getState().currentLesson?.courseId).toBe('course_eng_01');
      expect(useLessonStore.getState().currentLesson?.isDeterministicFallback).toBe(true);
    });
  });

  // -------------------------------------------------------------------------
  // Regression: the profile→course reconciliation used to react to BOTH the
  // profile value and the active course object, so an async profile write and
  // an active-course change undid each other forever (math⇄english ping-pong
  // that froze the app on course selection — caught by the E2E watchdog).
  // -------------------------------------------------------------------------
  describe('course reconciliation is one-way and terminating', () => {
    it('the first profile value after courses load only sets the baseline', () => {
      const d = decideCourseReconciliation(null, 'course_math_01', 4);
      expect(d.shouldReconcile).toBe(false);
      expect(d.nextLastSeenId).toBe('course_math_01');
    });

    it('does not establish a baseline while courses are still loading', () => {
      const d = decideCourseReconciliation(null, 'course_math_01', 0);
      expect(d.shouldReconcile).toBe(false);
      expect(d.nextLastSeenId).toBeNull();
    });

    it('ignores a missing profile value', () => {
      const d = decideCourseReconciliation('course_math_01', undefined, 4);
      expect(d.shouldReconcile).toBe(false);
      expect(d.nextLastSeenId).toBe('course_math_01');
    });

    it('an unchanged value never reconciles (write-back cannot retrigger)', () => {
      const d = decideCourseReconciliation('course_eng_01', 'course_eng_01', 4);
      expect(d.shouldReconcile).toBe(false);
      expect(d.nextLastSeenId).toBe('course_eng_01');
    });

    it('a genuine profile change reconciles exactly once and then quiesces', () => {
      const first = decideCourseReconciliation('course_eng_01', 'course_math_01', 4);
      expect(first.shouldReconcile).toBe(true);
      expect(first.nextLastSeenId).toBe('course_math_01');
      // selectCourseById writes the SAME profile value back → no retrigger
      const second = decideCourseReconciliation(first.nextLastSeenId, 'course_math_01', 4);
      expect(second.shouldReconcile).toBe(false);
      expect(second.nextLastSeenId).toBe('course_math_01');
    });

    it('two-store simulation terminates instead of ping-ponging math⇄english', async () => {
      await useCourseStore.getState().loadCourses();
      await useLearnerStore.getState().loadProfile();

      let lastSeen: string | null = null;
      let reconciles = 0;

      // Drive the decision the way the React effect does: after every profile
      // value change, reconcile (if due) by selecting that same course, which
      // writes the same profile value back.
      const runEffect = () => {
        const profileId = useLearnerStore.getState().profile?.selectedCourseId;
        const d = decideCourseReconciliation(
          lastSeen,
          profileId,
          useCourseStore.getState().courses.length
        );
        lastSeen = d.nextLastSeenId;
        if (d.shouldReconcile && profileId) {
          reconciles += 1;
          return profileId;
        }
        return null;
      };

      // Baseline: initial profile value (default math) must NOT reconcile.
      expect(runEffect()).toBeNull();

      // User picks English exactly like CourseSelectionView.handleChoose does.
      await useCourseStore.getState().selectCourseById('course_eng_01');
      expect(useCourseStore.getState().activeCourse?.id).toBe('course_eng_01');
      expect(useLearnerStore.getState().profile?.selectedCourseId).toBe('course_eng_01');

      // The effect reacting to that profile change must settle immediately.
      const target = runEffect();
      if (target) await useCourseStore.getState().selectCourseById(target);
      expect(reconciles).toBeLessThanOrEqual(1);

      // And no further profile changes may appear out of thin air.
      expect(runEffect()).toBeNull();
      expect(reconciles).toBeLessThanOrEqual(1);
      expect(useCourseStore.getState().activeCourse?.id).toBe('course_eng_01');
      expect(useLearnerStore.getState().profile?.selectedCourseId).toBe('course_eng_01');
    });
  });

  // -------------------------------------------------------------------------
  // Source-level guards: hardcodes removed from the P0 paths
  // -------------------------------------------------------------------------
  describe('hardcoded cross-course values removed (source audit)', () => {
    const read = (rel: string) => readFileSync(resolve(process.cwd(), rel), 'utf8');

    it('SupabaseLearnerRepository no longer hardcodes math course/skill', () => {
      const src = read('src/data/repositories/SupabaseLearnerRepository.ts');
      expect(src).not.toContain("course_id: 'course_math_01'");
      expect(src).not.toContain("skill_id: 'skill_math_functions'");
      expect(src).not.toContain('before_score: 40');
    });

    it('AppRouter no longer hardcodes math/eng lesson fallbacks', () => {
      const src = read('src/app/router/AppRouter.tsx');
      expect(src).not.toContain('lesson_math_functions_01');
      expect(src).not.toContain('lesson_eng_listening_01');
      expect(src).not.toContain("'course_math_01'");
    });

    it('RoadmapView no longer has the binary math/english default lesson', () => {
      const src = read('src/features/roadmap/RoadmapView.tsx');
      expect(src).not.toContain("isMath ? 'lesson_math_functions_01'");
      expect(src).not.toContain("lesson_eng_listening_01'");
    });

    it('ReinforcementModal no longer hardcodes the math/english node pair', () => {
      const src = read('src/features/reinforcement/ReinforcementModal.tsx');
      expect(src).not.toContain("reinf_node_math_func");
      expect(src).not.toContain("reinf_node_eng_list");
    });

    it('course store no longer resets the active course to courses[0] on load', () => {
      const src = read('src/app/store/useCourseStore.ts');
      expect(src).not.toMatch(/activeCourse\s*=\s*courses\[0\]/);
      expect(src).toContain('resolveInitialCourse');
    });

    it('AppRouter reconciles via the one-way helper (no activeCourse-reactive loop)', () => {
      const src = read('src/app/router/AppRouter.tsx');
      expect(src).toContain('decideCourseReconciliation');
      expect(src).toContain('lastSeenCourseIdRef');
      // The loop-prone dependency shape must not come back.
      expect(src).not.toContain('activeCourse?.id, activeCourse]');
    });

    it('edge function outer catch no longer fabricates math diagnosis', () => {
      const src = read('supabase/functions/yolchi-tutor/index.ts');
      expect(src).not.toContain('skillId: "skill_math_functions"');
      expect(src).toContain('status: 500');
    });
  });
});
