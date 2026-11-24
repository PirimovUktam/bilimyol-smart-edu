import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const backend = vi.hoisted(() => ({
  configured: true,
  getUser: vi.fn(),
  from: vi.fn(),
  rpc: vi.fn(),
  invoke: vi.fn(),
}));

vi.mock('@/core/config/supabase', () => ({
  get isSupabaseConfigured() {
    return backend.configured;
  },
  supabase: {
    auth: { getUser: backend.getUser },
    from: backend.from,
    rpc: backend.rpc,
    functions: { invoke: backend.invoke },
  },
}));

const ROOT = process.cwd();
const SRC = path.resolve(ROOT, 'src');

const BANNED_LIVE_MODULES = new Set([
  'src/data/datasources/questions.ts',
  'src/data/datasources/lessons.ts',
  'src/data/datasources/starterLessons.ts',
  'src/data/datasources/roadmaps.ts',
  'src/data/datasources/courses.ts',
  'src/data/datasources/skills.ts',
  'src/data/datasources/demoAiResponses.ts',
  'src/data/datasources/english/index.ts',
  'src/data/datasources/english/a1.ts',
  'src/data/datasources/english/a2.ts',
  'src/data/datasources/english/b1.ts',
  'src/data/services/DemoAITutorService.ts',
  'src/data/repositories/InMemoryCourseRepository.ts',
  'src/data/repositories/InMemoryLearnerRepository.ts',
  'src/data/repositories/InMemoryLessonRepository.ts',
  'src/core/runtime/questionAnswerKeys.ts',
  'content/english/a1-curriculum.json',
  'content/english/a2-curriculum.json',
  'content/english/b1-curriculum.json',
  'content/english/placement-questions.json',
]);

function normalizeRel(absPath: string): string {
  return path.relative(ROOT, absPath).replace(/\\/g, '/');
}

function resolveStaticImport(fromFile: string, specifier: string): string | null {
  let target: string | null = null;
  if (specifier.startsWith('@/')) {
    target = path.resolve(SRC, specifier.slice(2));
  } else if (specifier.startsWith('.')) {
    target = path.resolve(path.dirname(fromFile), specifier);
  } else {
    return null;
  }

  const candidates = [
    target,
    `${target}.ts`,
    `${target}.tsx`,
    `${target}.js`,
    `${target}.json`,
    path.join(target, 'index.ts'),
    path.join(target, 'index.tsx'),
  ];
  for (const c of candidates) {
    if (fs.existsSync(c) && fs.statSync(c).isFile()) {
      return c;
    }
  }
  return null;
}

function extractStaticImports(filePath: string): string[] {
  const raw = fs.readFileSync(filePath, 'utf8');
  const results: string[] = [];
  const code = raw
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/^\s*\/\/.*$/gm, '');

  const importFromRe = /(?:^|\n)\s*(?:import|export)\s+(?!type\b)(?:[^;'"]*?\s+from\s+)?['"]([^'"]+)['"]\s*;/g;
  let match: RegExpExecArray | null;
  while ((match = importFromRe.exec(code)) !== null) {
    results.push(match[1]);
  }
  return results;
}

function walkStaticGraph(entryRelPaths: string[]): Set<string> {
  const visited = new Set<string>();
  const stack = entryRelPaths.map((rel) => path.resolve(ROOT, rel));

  while (stack.length > 0) {
    const abs = stack.pop()!;
    const rel = normalizeRel(abs);
    if (visited.has(rel)) continue;
    visited.add(rel);

    if (abs.endsWith('.json') || !fs.existsSync(abs)) continue;
    for (const spec of extractStaticImports(abs)) {
      const resolved = resolveStaticImport(abs, spec);
      if (resolved && !visited.has(normalizeRel(resolved))) {
        stack.push(resolved);
      }
    }
  }
  return visited;
}

function scanChunkAnswerKeys(js: string) {
  return {
    correctIndex: (js.match(/(?:"correctIndex"|correctIndex)\s*:\s*\d+/g) || []).length,
    acceptedAnswers: (js.match(/(?:"acceptedAnswers"|acceptedAnswers)\s*:\s*\[/g) || []).length,
    orderedTokens: (js.match(/(?:"orderedTokens"|orderedTokens)\s*:\s*\[/g) || []).length,
    matchPairs: (js.match(/(?:"matchPairs"|matchPairs)\s*:\s*\[/g) || []).length,
  };
}

describe('W0-B2 (FIX-P0-23 + Coupling #1) Web production answer-key bundle isolation', () => {
  it('excludes demo/seed answer-key modules from static graphs of src/main.tsx and live routes', () => {
    const liveEntries = [
      'src/main.tsx',
      'src/features/auth/WelcomeView.tsx',
      'src/features/tour/ProductTourView.tsx',
      'src/features/auth/LoginView.tsx',
      'src/features/auth/RegisterView.tsx',
      'src/features/auth/ForgotPasswordView.tsx',
      'src/features/auth/ResetPasswordView.tsx',
      'src/features/course-selection/CourseSelectionView.tsx',
      'src/features/onboarding/OnboardingView.tsx',
      'src/features/placement/PlacementTestView.tsx',
      'src/features/knowledge-map/KnowledgeMapView.tsx',
      'src/features/roadmap/RoadmapView.tsx',
      'src/features/lesson/InteractiveLessonView.tsx',
      'src/features/dashboard/DashboardView.tsx',
      'src/features/ai-tutor/YolchiAIChatView.tsx',
      'src/features/progress/ProgressView.tsx',
      'src/features/profile/ProfileView.tsx',
      'src/features/admin/AdminDashboardView.tsx',
    ];

    const reachable = walkStaticGraph(liveEntries);
    const leaked = [...reachable].filter((rel) => BANNED_LIVE_MODULES.has(rel));
    expect(leaked).toEqual([]);

    const appRouterSrc = fs.readFileSync(path.resolve(ROOT, 'src/app/router/AppRouter.tsx'), 'utf8');
    expect(appRouterSrc).not.toMatch(/import\(\s*['"]@\/presentation\/components\/withMotionPreferences['"]\s*\)/);
    expect(appRouterSrc).toMatch(/lazyAnimated\(\s*\(\)\s*=>\s*import\(['"]@\/features\/lesson\/InteractiveLessonView['"]/);

    const lessonViewSrc = fs.readFileSync(path.resolve(ROOT, 'src/features/lesson/InteractiveLessonView.tsx'), 'utf8');
    expect(lessonViewSrc).not.toMatch(/^import\s+\{[^}]*\}\s+from\s+['"]@\/features\/ai-tutor\/YolchiAIChatView['"]/m);
  });

  it(
    'builds production bundle with zero preloaded answer keys, zero >500kB chunks, zero ineffective dynamic imports, and <25kB flashcard splits',
    async () => {
      const { build } = await import('vite');
      const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'bilimyol-w0b2-build-'));
      const warnings: string[] = [];

      try {
        await build({
          configFile: path.resolve(ROOT, 'vite.config.ts'),
          logLevel: 'warn',
          customLogger: {
            info() {},
            warn(msg) {
              warnings.push(String(msg));
            },
            warnOnce(msg) {
              warnings.push(String(msg));
            },
            error(msg) {
              warnings.push(`ERROR: ${String(msg)}`);
            },
            clearScreen() {},
            hasErrorLogged: () => false,
            hasWarned: false,
          },
          build: {
            outDir: tmpDir,
            emptyOutDir: true,
          },
        });

        expect(warnings.filter((w) => w.includes('INEFFECTIVE_DYNAMIC_IMPORT'))).toEqual([]);
        expect(warnings.filter((w) => w.includes('larger than 500 kB'))).toEqual([]);

        const html = fs.readFileSync(path.join(tmpDir, 'index.html'), 'utf8');
        const initialUrls = [
          ...[...html.matchAll(/<script[^>]+src="([^"]+)"/g)].map((m) => m[1]),
          ...[...html.matchAll(/<link[^>]+rel="modulepreload"[^>]+href="([^"]+)"/g)].map((m) => m[1]),
        ];

        expect(initialUrls.length).toBeGreaterThan(0);

        // Walk static JS imports across preloaded entry chunks as a browser does on initial load
        const preloadedVisited = new Set<string>();
        const queue = initialUrls.map((u) => path.join(tmpDir, u.replace(/^\//, '')));
        while (queue.length > 0) {
          const abs = queue.pop()!;
          const rel = path.relative(tmpDir, abs).replace(/\\/g, '/');
          if (preloadedVisited.has(rel) || !fs.existsSync(abs)) continue;
          preloadedVisited.add(rel);

          expect(rel).not.toMatch(/\/(questions|lessons|questionAnswerKeys|demoAiResponses|DemoAITutorService|InMemory|demo-english)/);
          const js = fs.readFileSync(abs, 'utf8');
          expect(scanChunkAnswerKeys(js), `Answer key leak in preloaded asset ${rel}`).toEqual({
            correctIndex: 0,
            acceptedAnswers: 0,
            orderedTokens: 0,
            matchPairs: 0,
          });

          const staticAssetImports = [...js.matchAll(/from\s*["'](\.[^"']+\.js)["']/g)].map((m) => m[1]);
          for (const imp of staticAssetImports) {
            queue.push(path.resolve(path.dirname(abs), imp));
          }
        }

        const assetsDir = path.join(tmpDir, 'assets');
        const jsFiles = fs.readdirSync(assetsDir).filter((f) => f.endsWith('.js'));

        // All chunks under 500 kB and all live learner view chunks free of hardcoded answer keys
        for (const f of jsFiles) {
          const abs = path.join(assetsDir, f);
          const bytes = fs.statSync(abs).size;
          expect(bytes, `Chunk ${f} exceeds 500 kB (${bytes} bytes)`).toBeLessThan(500_000);
          if (/View-.*\.js$/.test(f) && !f.startsWith('AdminDashboardView-')) {
            const viewJs = fs.readFileSync(abs, 'utf8');
            expect(scanChunkAnswerKeys(viewJs), `Answer key leak in learner route chunk ${f}`).toEqual({
              correctIndex: 0,
              acceptedAnswers: 0,
              orderedTokens: 0,
              matchPairs: 0,
            });
          }
        }

        const metaChunk = jsFiles.find((f) => f.startsWith('flashcards-meta-'));
        const a1Chunk = jsFiles.find((f) => f.startsWith('flashcards-english-a1-'));
        const a2b1Chunk = jsFiles.find((f) => f.startsWith('flashcards-english-a2b1-'));
        expect(metaChunk, 'Expected split flashcards-meta chunk').toBeDefined();
        expect(a1Chunk, 'Expected split flashcards-english-a1 chunk').toBeDefined();
        expect(a2b1Chunk, 'Expected split flashcards-english-a2b1 chunk').toBeDefined();

        expect(fs.statSync(path.join(assetsDir, metaChunk!)).size).toBeLessThan(5 * 1024);
        for (const chunkFile of [metaChunk!, a1Chunk!, a2b1Chunk!]) {
          expect(fs.statSync(path.join(assetsDir, chunkFile)).size).toBeLessThan(25 * 1024);
          const chunkJs = fs.readFileSync(path.join(assetsDir, chunkFile), 'utf8');
          expect(scanChunkAnswerKeys(chunkJs)).toEqual({
            correctIndex: 0,
            acceptedAnswers: 0,
            orderedTokens: 0,
            matchPairs: 0,
          });
        }
      } finally {
        fs.rmSync(tmpDir, { recursive: true, force: true });
      }
    },
    30_000,
  );

  it('provides 1:1 answer-free PLACEMENT_QUESTION_METADATA and lossless English flashcards + SRS meta for Coupling #1', async () => {
    const [{ PLACEMENT_QUESTION_METADATA }, { PLACEMENT_QUESTIONS }, flashcardsMod, metaMod] = await Promise.all([
      import('@/data/datasources/placementMetadata'),
      import('@/data/datasources/questions'),
      import('@/data/datasources/english/flashcards'),
      import('@/data/datasources/english/flashcardSrsMeta'),
    ]);

    for (const [courseId, bank] of Object.entries(PLACEMENT_QUESTIONS)) {
      const meta = PLACEMENT_QUESTION_METADATA[courseId] ?? [];
      expect(meta).toHaveLength(bank.length);
      for (let i = 0; i < bank.length; i++) {
        const q = bank[i];
        const m = meta[i];
        expect(m).toEqual({
          id: q.id,
          courseId: q.courseId,
          skillId: q.skillId,
          difficulty: q.difficulty,
          ...(q.cefrLevel ? { cefrLevel: q.cefrLevel } : {}),
        });
        expect(Object.keys(m)).not.toContain('correctIndex');
        expect(Object.keys(m)).not.toContain('options');
        expect(Object.keys(m)).not.toContain('text');
        expect(Object.keys(m)).not.toContain('explanation');
      }
    }

    const expectedByLesson: Record<string, unknown[]> = {};
    const expectedEntries: Array<{ card: unknown; lessonId: string; moduleId?: string }> = [];
    const expectedSrsMeta: Array<{ id: string; lessonId: string; moduleId?: string }> = [];
    const seen = new Set<string>();
    for (const level of ['a1', 'a2', 'b1']) {
      const json = JSON.parse(
        fs.readFileSync(path.resolve(ROOT, `content/english/${level}-curriculum.json`), 'utf8'),
      );
      for (const lesson of json.lessons) {
        const lessonCards: unknown[] = [];
        for (const step of lesson.steps) {
          for (const card of step.flashcards ?? []) {
            lessonCards.push(card);
            if (!seen.has(card.id)) {
              seen.add(card.id);
              expectedEntries.push({
                card,
                lessonId: lesson.id,
                moduleId: lesson.moduleId,
              });
              expectedSrsMeta.push({
                id: card.id,
                lessonId: lesson.id,
                ...(lesson.moduleId ? { moduleId: lesson.moduleId } : {}),
              });
            }
          }
        }
        expectedByLesson[lesson.id] = lessonCards;
      }
    }

    expect(flashcardsMod.ENGLISH_ALL_FLASHCARD_ENTRIES).toEqual(expectedEntries);
    expect(flashcardsMod.ENGLISH_FLASHCARDS_BY_LESSON).toEqual(expectedByLesson);
    expect(metaMod.ENGLISH_FLASHCARD_SRS_META).toEqual(expectedSrsMeta);
  });
});

describe('W0-B2 runtime live-vs-demo dynamic loading isolation', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    backend.configured = true;
  });

  afterEach(async () => {
    const { setDemoRuntimeActive } = await import('@/core/runtime/demoRuntime');
    setDemoRuntimeActive(false);
    vi.restoreAllMocks();
  });

  it('keeps Demo repositories and AI fallbacks bypassed in live configured mode and functional in Demo mode', async () => {
    const { setDemoRuntimeActive } = await import('@/core/runtime/demoRuntime');
    const { SupabaseLessonRepository } = await import('@/data/repositories/SupabaseLessonRepository');
    const { GeminiAITutorService } = await import('@/data/services/GeminiAITutorService');
    const { AdminContentService } = await import('@/data/services/AdminContentService');
    const { usePlacementStore } = await import('@/app/store/usePlacementStore');
    const { useCourseStore } = await import('@/app/store/useCourseStore');
    const { useLearnerStore } = await import('@/app/store/useLearnerStore');
    const { useLessonStore } = await import('@/app/store/useLessonStore');
    const { useRoadmapStore } = await import('@/app/store/useRoadmapStore');
    const { resetAllSessionStores, invalidateCourseScopedStores } = await import('@/core/runtime/sessionReset');

    // 1. Live configured mode: SupabaseLessonRepository & GeminiAITutorService never hit Demo repos
    setDemoRuntimeActive(false);
    const liveRepo = new SupabaseLessonRepository();
    await liveRepo.saveLesson({
      id: 'live_ai_lesson_1',
      courseId: 'course_math_01',
      skillId: 'skill_math_functions',
      title: 'Live AI Lesson',
      estimatedMinutes: 10,
      summary: 'Summary',
      steps: [],
      reinforcementExercise: {
        id: 'q_live_1',
        courseId: 'course_math_01',
        skillId: 'skill_math_functions',
        text: 'f(1)?',
        options: ['1', '2'],
        difficulty: 'easy',
        explanation: '',
      },
    });
    expect(liveRepo.getCachedDemoLessonSync('lesson_eng_starter')).toBeNull();
    backend.getUser.mockResolvedValue({ data: { user: { id: 'live-user' } }, error: null });
    backend.from.mockImplementation(() => ({
      select: vi.fn().mockReturnThis(),
      eq: vi.fn().mockReturnThis(),
      maybeSingle: vi.fn().mockResolvedValue({ data: null, error: null }),
    }));
    const liveCachedRead = await liveRepo.getLessonById('live_ai_lesson_1');
    expect(liveCachedRead?.id).toBe('live_ai_lesson_1');

    backend.invoke.mockResolvedValueOnce({
      data: {
        id: 'q_gen_live',
        text: 'Live generated question?',
        options: ['Yes', 'No'],
        isAiGenerated: true,
        isDeterministicFallback: false,
      },
      error: null,
    });
    const tutor = new GeminiAITutorService();
    const liveQuestion = await tutor.generateQuestion({
      courseId: 'course_math_01',
      skillId: 'skill_math_functions',
      difficulty: 'easy',
    });
    expect(liveQuestion.id).toBe('q_gen_live');
    expect(backend.invoke).toHaveBeenCalledTimes(1);

    // 2. Demo runtime: dynamically loads Demo repositories, AI fallbacks & Admin demo stores
    setDemoRuntimeActive(true);
    const engLesson = await liveRepo.getLessonById('lesson_eng_starter');
    expect(engLesson?.id).toBe('lesson_eng_starter');
    expect(liveRepo.getCachedDemoLessonSync('lesson_eng_starter')?.id).toBe('lesson_eng_starter');

    const demoQuestion = await tutor.generateQuestion({
      courseId: 'course_eng_01',
      skillId: 'skill_eng_vocab',
      difficulty: 'easy',
    });
    expect(demoQuestion.courseId).toBe('course_eng_01');
    expect(demoQuestion.isDeterministicFallback).toBe(true);
    expect(demoQuestion.options).toHaveLength(4);

    const demoReinf = await tutor.generateReinforcement({
      courseId: 'course_logic',
      skillId: 'skill_logic_patterns',
    });
    expect(demoReinf.courseId).toBe('course_logic');
    expect(demoReinf.isDeterministicFallback).toBe(true);

    const demoReply = await tutor.askTutor({
      courseId: 'course_eng_01',
      lessonId: 'lesson_eng_starter',
      message: 'Salom',
      language: 'uz',
    });
    expect(demoReply.isDeterministicFallback).toBe(true);
    expect(demoReply.answer.length).toBeGreaterThan(10);

    const adminService = new AdminContentService();
    const demoCourses = await adminService.getCourses();
    expect(demoCourses.some((c) => c.id === 'course_eng_01')).toBe(true);

    // 3. sessionReset clears all registered Zustand stores cleanly
    useLessonStore.setState({ error: 'dirty' });
    usePlacementStore.setState({ error: 'dirty' });
    useRoadmapStore.setState({ error: 'dirty' });
    invalidateCourseScopedStores();
    expect(useLessonStore.getState().error).toBeNull();
    expect(usePlacementStore.getState().error).toBeNull();
    expect(useRoadmapStore.getState().error).toBeNull();

    useCourseStore.setState({ error: 'dirty' });
    useLearnerStore.setState({ isLoading: true });
    useLessonStore.setState({ error: 'dirty' });
    resetAllSessionStores();
    expect(useCourseStore.getState().error).toBeNull();
    expect(useLearnerStore.getState().isLoading).toBe(false);
    expect(useLessonStore.getState().error).toBeNull();
  });
});
