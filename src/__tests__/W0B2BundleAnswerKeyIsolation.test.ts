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

  const importFromRe = /^\s*(?:import|export)\s+(?!type\b)(?:[^;'"]*?\s+from\s+)?['"]([^'"]+)['"]/gm;
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

    if (!/\.(?:[cm]?[tj]sx?)$/.test(abs) || !fs.existsSync(abs)) continue;
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
    expect(reachable.has('src/main.tsx')).toBe(true);
    expect(reachable.has('src/App.tsx')).toBe(true);
    expect(reachable.has('src/app/router/AppRouter.tsx')).toBe(true);
    expect(reachable.has('src/core/context/AuthContext.tsx')).toBe(true);
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

          const staticAssetImports = [
            ...js.matchAll(/(?:from\s*|(?:\bimport(?!\s*\()))["'](\.[^"']+\.js)["']/g),
          ].map((m) => m[1]);
          for (const imp of staticAssetImports) {
            queue.push(path.resolve(path.dirname(abs), imp));
          }
        }

        const assetsDir = path.join(tmpDir, 'assets');
        const jsFiles = fs.readdirSync(assetsDir).filter((f) => f.endsWith('.js'));

        // All chunks under 500 kB and all non-demo/non-admin live chunks free of hardcoded answer keys
        for (const f of jsFiles) {
          const abs = path.join(assetsDir, f);
          const bytes = fs.statSync(abs).size;
          expect(bytes, `Chunk ${f} exceeds 500 kB (${bytes} bytes)`).toBeLessThan(500_000);
          if (!/^(?:AdminDashboardView|DemoAITutorService|demo-english-|questions-|lessons-|questionAnswerKeys-|InMemory)/.test(f)) {
            const viewJs = fs.readFileSync(abs, 'utf8');
            expect(scanChunkAnswerKeys(viewJs), `Answer key leak in live asset chunk ${f}`).toEqual({
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
    const { SupabaseLessonRepository, supabaseLessonRepository } = await import('@/data/repositories/SupabaseLessonRepository');
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

    // 3. sessionReset clears all registered Zustand stores and live runtime lesson cache cleanly
    setDemoRuntimeActive(false);
    await supabaseLessonRepository.saveLesson({
      id: 'live_ai_lesson_singleton',
      courseId: 'course_math_01',
      skillId: 'skill_math_functions',
      title: 'Singleton Live AI Lesson',
      estimatedMinutes: 10,
      summary: 'Summary',
      steps: [],
      reinforcementExercise: {
        id: 'q_live_singleton',
        courseId: 'course_math_01',
        skillId: 'skill_math_functions',
        text: 'f(2)?',
        options: ['2', '4'],
        difficulty: 'easy',
        explanation: '',
      },
    });
    expect((await supabaseLessonRepository.getLessonById('live_ai_lesson_singleton'))?.id).toBe('live_ai_lesson_singleton');

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
    expect(await supabaseLessonRepository.getLessonById('live_ai_lesson_singleton')).toBeNull();
  });
});

function findReactNode(node: unknown, predicate: (el: { type: unknown; props: Record<string, unknown> }) => boolean): { type: unknown; props: Record<string, unknown> } | null {
  if (!node || typeof node !== 'object') return null;
  if (Array.isArray(node)) {
    for (const child of node) {
      const found = findReactNode(child, predicate);
      if (found) return found;
    }
    return null;
  }
  const el = node as { type?: unknown; props?: Record<string, unknown> };
  if ('type' in el && el.props) {
    const candidate = { type: el.type, props: el.props };
    if (predicate(candidate)) return candidate;
    if (el.props.children !== undefined) {
      return findReactNode(el.props.children, predicate);
    }
  }
  return null;
}

function collectNodeText(node: unknown): string {
  if (node == null || typeof node === 'boolean') return '';
  if (typeof node === 'string' || typeof node === 'number') return String(node);
  if (Array.isArray(node)) return node.map(collectNodeText).join('');
  if (typeof node === 'object' && 'props' in node) {
    return collectNodeText((node as { props?: { children?: unknown } }).props?.children);
  }
  return '';
}

function createHookDispatcher() {
  const states: unknown[] = [];
  const refs: Array<{ current: unknown }> = [];
  const memos: Array<{ deps: unknown[]; value: unknown }> = [];
  const effects: Array<{ deps?: unknown[]; cleanup?: (() => void) | void }> = [];
  const pendingEffects: Array<{ idx: number; fn: () => void | (() => void); deps?: unknown[] }> = [];
  let idx = 0;

  return {
    reset() {
      idx = 0;
    },
    useState<T>(init: T | (() => T)): [T, (next: T | ((prev: T) => T)) => void] {
      const slot = idx++;
      if (!(slot in states)) {
        states[slot] = typeof init === 'function' ? (init as () => T)() : init;
      }
      const setState = (next: T | ((prev: T) => T)) => {
        states[slot] = typeof next === 'function' ? (next as (prev: T) => T)(states[slot] as T) : next;
      };
      return [states[slot] as T, setState];
    },
    useRef<T>(init: T): { current: T } {
      const slot = idx++;
      if (!(slot in refs)) {
        refs[slot] = { current: init };
      }
      return refs[slot] as { current: T };
    },
    useMemo<T>(factory: () => T, deps: unknown[]): T {
      const slot = idx++;
      const prev = memos[slot];
      if (!prev || deps.length !== prev.deps.length || deps.some((d, k) => !Object.is(d, prev.deps[k]))) {
        memos[slot] = { deps: [...deps], value: factory() };
      }
      return memos[slot].value as T;
    },
    useCallback<T extends (...args: never[]) => unknown>(fn: T): T {
      idx++;
      return fn;
    },
    useSyncExternalStore<T>(_sub: unknown, getSnapshot: () => T): T {
      idx++;
      return getSnapshot();
    },
    useId() {
      return `w0b2-id-${idx++}`;
    },
    useEffect(fn: () => void | (() => void), deps?: unknown[]) {
      const slot = idx++;
      const prev = effects[slot];
      const changed =
        !prev ||
        !deps ||
        !prev.deps ||
        deps.length !== prev.deps.length ||
        deps.some((d, k) => !Object.is(d, prev.deps![k]));
      if (changed) {
        pendingEffects.push({ idx: slot, fn, deps: deps ? [...deps] : undefined });
      }
    },
    flushEffects() {
      while (pendingEffects.length > 0) {
        const next = pendingEffects.shift()!;
        const prevCleanup = effects[next.idx]?.cleanup;
        if (typeof prevCleanup === 'function') prevCleanup();
        const cleanup = next.fn();
        effects[next.idx] = { deps: next.deps, cleanup };
      }
    },
    unmount() {
      for (const eff of effects) {
        if (typeof eff?.cleanup === 'function') {
          eff.cleanup();
        }
      }
    },
  };
}

function withReactHookDispatcher<T>(
  reactMod: typeof import('react'),
  hooks: ReturnType<typeof createHookDispatcher>,
  render: () => T,
): T {
  const internals =
    (
      reactMod as unknown as {
        __CLIENT_INTERNALS_DO_NOT_USE_OR_WARN_USERS_THEY_CANNOT_UPGRADE?: { H: unknown };
        default?: { __CLIENT_INTERNALS_DO_NOT_USE_OR_WARN_USERS_THEY_CANNOT_UPGRADE?: { H: unknown } };
      }
    ).__CLIENT_INTERNALS_DO_NOT_USE_OR_WARN_USERS_THEY_CANNOT_UPGRADE ??
    (
      reactMod as unknown as {
        default?: { __CLIENT_INTERNALS_DO_NOT_USE_OR_WARN_USERS_THEY_CANNOT_UPGRADE?: { H: unknown } };
      }
    ).default?.__CLIENT_INTERNALS_DO_NOT_USE_OR_WARN_USERS_THEY_CANNOT_UPGRADE;
  if (!internals) {
    throw new Error('React hook dispatcher internals unavailable in test harness');
  }
  const prev = internals.H;
  internals.H = {
    useState: hooks.useState.bind(hooks),
    useRef: hooks.useRef.bind(hooks),
    useMemo: hooks.useMemo.bind(hooks),
    useCallback: hooks.useCallback.bind(hooks),
    useSyncExternalStore: hooks.useSyncExternalStore.bind(hooks),
    useId: hooks.useId.bind(hooks),
    useEffect: hooks.useEffect.bind(hooks),
    useDebugValue: () => undefined,
  };
  try {
    hooks.reset();
    return render();
  } finally {
    internals.H = prev;
  }
}

describe('W0-B2 UI async lifecycle & error boundary resilience', () => {
  afterEach(() => {
    vi.doUnmock('@/data/datasources/english/flashcards');
    vi.doUnmock('@/features/ai-tutor/YolchiAIChatView');
    vi.doUnmock('@/core/context/AuthContext');
    vi.unstubAllGlobals();
    vi.resetModules();
  });

  it('handles RoadmapView SRS Hub error recovery, prefetch rejection safety, and unmount cancellation', async () => {
    const actualFlashcards = await import('@/data/datasources/english/flashcards');
    const actualCourses = await import('@/data/datasources/courses');
    const englishCourse = actualCourses.SEED_COURSES.find((c) => c.id === 'course_eng_01')!;

    // Part 1: handleToggleSrsHub transient load failure resets promise ref and recovers on retry + closes cleanly
    vi.resetModules();
    const hooksB = createHookDispatcher();
    let readAttempt = 0;
    vi.doMock('@/data/datasources/english/flashcards', () => ({
      get ENGLISH_FLASHCARD_BY_ID() {
        readAttempt += 1;
        if (readAttempt === 1) {
          throw new Error('Transient flashcard catalog failure');
        }
        return actualFlashcards.ENGLISH_FLASHCARD_BY_ID;
      },
    }));

    const reactModB = await import('react');
    const modB = await import('@/features/roadmap/RoadmapView');
    const csB = (await import('@/app/store/useCourseStore')).useCourseStore;
    const lsB = (await import('@/app/store/useLearnerStore')).useLearnerStore;
    const rsB = (await import('@/app/store/useRoadmapStore')).useRoadmapStore;
    const BtnB = (await import('@/presentation/components/Button')).Button;
    const DeckB = (await import('@/features/lesson/FlashcardDeck')).FlashcardDeck;

    csB.setState({ activeCourse: englishCourse, activeCourseSkills: [] });
    lsB.setState({
      profile: {
        id: 'learner-b',
        courseId: 'course_eng_01',
        displayName: 'Test B',
        xp: 0,
        streakDays: 0,
        completedLessonIds: ['lesson_eng_starter'],
        scoresByCourse: {},
        flashcardSrsByCourse: {},
        onboardingCompleted: true,
        placementCompleted: true,
      },
    });
    rsB.setState({
      roadmap: { courseId: 'course_eng_01', nodes: [] },
      error: null,
      loadRoadmap: vi.fn().mockResolvedValue(undefined),
    });

    const renderRoadmapB = () => {
      const t = withReactHookDispatcher(reactModB, hooksB, () =>
        modB.RoadmapView({
          onStartLesson: () => {},
          onOpenKnowledgeMap: () => {},
          onChooseCourse: () => {},
          onConfigure: () => {},
        }),
      );
      hooksB.flushEffects();
      return t;
    };

    let tree = renderRoadmapB();
    const hubBtnErr = findReactNode(
      tree,
      (el) => el.type === BtnB && collectNodeText(el.props.children).includes('Flashcard takrorlash'),
    );
    expect(hubBtnErr).not.toBeNull();
    (hubBtnErr!.props.onClick as () => void)();
    await vi.waitFor(() => {
      expect(readAttempt).toBeGreaterThanOrEqual(1);
    });
    await new Promise((r) => setTimeout(r, 15));

    tree = renderRoadmapB();
    expect(readAttempt).toBe(1);
    expect(findReactNode(tree, (el) => el.props.role === 'alert')).not.toBeNull();
    expect(findReactNode(tree, (el) => el.type === DeckB)).toBeNull();

    const hubBtnRetry = findReactNode(
      tree,
      (el) => el.type === BtnB && collectNodeText(el.props.children).includes('Flashcard takrorlash'),
    );
    (hubBtnRetry!.props.onClick as () => void)();
    await vi.waitFor(() => {
      expect(readAttempt).toBe(2);
    });
    await new Promise((r) => setTimeout(r, 15));

    tree = renderRoadmapB();
    expect(readAttempt).toBe(2);
    expect(findReactNode(tree, (el) => el.props.role === 'alert')).toBeNull();
    const deckEl = findReactNode(tree, (el) => el.type === DeckB);
    expect(deckEl).not.toBeNull();
    expect((deckEl!.props.cards as unknown[]).length).toBeGreaterThan(0);

    const closeBtn = findReactNode(
      tree,
      (el) => el.type === BtnB && collectNodeText(el.props.children).includes('Kartochkalarni yopish'),
    );
    expect(closeBtn).not.toBeNull();
    (closeBtn!.props.onClick as () => void)();
    tree = renderRoadmapB();
    expect(findReactNode(tree, (el) => el.type === DeckB)).toBeNull();
    hooksB.unmount();

    // Part 2: pending SRS Hub open cancelled by unmount cleanup before delayed resolve
    const hooks2 = createHookDispatcher();
    vi.doUnmock('@/data/datasources/english/flashcards');
    vi.resetModules();
    let resolveDelayedDeck!: (mod: typeof actualFlashcards) => void;
    vi.doMock('@/data/datasources/english/flashcards', () => new Promise<typeof actualFlashcards>((resolve) => {
      resolveDelayedDeck = resolve;
    }));

    const reactMod2 = await import('react');
    const mod2 = await import('@/features/roadmap/RoadmapView');
    const cs2 = (await import('@/app/store/useCourseStore')).useCourseStore;
    const ls2 = (await import('@/app/store/useLearnerStore')).useLearnerStore;
    const rs2 = (await import('@/app/store/useRoadmapStore')).useRoadmapStore;
    const Btn2 = (await import('@/presentation/components/Button')).Button;
    const Deck2 = (await import('@/features/lesson/FlashcardDeck')).FlashcardDeck;

    cs2.setState({ activeCourse: englishCourse, activeCourseSkills: [] });
    ls2.setState({
      profile: {
        id: 'learner-2',
        courseId: 'course_eng_01',
        displayName: 'Test 2',
        xp: 0,
        streakDays: 0,
        completedLessonIds: ['lesson_eng_starter'],
        scoresByCourse: {},
        flashcardSrsByCourse: {},
        onboardingCompleted: true,
        placementCompleted: true,
      },
    });
    rs2.setState({
      roadmap: { courseId: 'course_eng_01', nodes: [] },
      error: null,
      loadRoadmap: vi.fn().mockResolvedValue(undefined),
    });

    const renderRoadmap2 = () => {
      const t = withReactHookDispatcher(reactMod2, hooks2, () =>
        mod2.RoadmapView({
          onStartLesson: () => {},
          onOpenKnowledgeMap: () => {},
          onChooseCourse: () => {},
          onConfigure: () => {},
        }),
      );
      hooks2.flushEffects();
      return t;
    };

    const tInitial = renderRoadmap2();
    const hubBtn2 = findReactNode(
      tInitial,
      (el) => el.type === Btn2 && collectNodeText(el.props.children).includes('Flashcard takrorlash'),
    );
    (hubBtn2!.props.onClick as () => void)();
    await vi.waitFor(() => {
      expect(typeof resolveDelayedDeck).toBe('function');
    });
    hooks2.unmount();
    resolveDelayedDeck(actualFlashcards);
    await new Promise((r) => setTimeout(r, 15));

    const tAfterUnmount = withReactHookDispatcher(reactMod2, hooks2, () =>
      mod2.RoadmapView({
        onStartLesson: () => {},
        onOpenKnowledgeMap: () => {},
        onChooseCourse: () => {},
        onConfigure: () => {},
      }),
    );
    expect(findReactNode(tAfterUnmount, (el) => el.type === Deck2)).toBeNull();

    // Part 3: mount prefetch rejection causes zero unhandled rejections
    const hooks3 = createHookDispatcher();
    vi.doUnmock('@/data/datasources/english/flashcards');
    vi.resetModules();
    let prefetchAttempt = 0;
    vi.doMock('@/data/datasources/english/flashcards', () => {
      prefetchAttempt += 1;
      return Promise.reject(new Error('Prefetch network error'));
    });

    const reactMod3 = await import('react');
    const mod3 = await import('@/features/roadmap/RoadmapView');
    const cs3 = (await import('@/app/store/useCourseStore')).useCourseStore;
    const ls3 = (await import('@/app/store/useLearnerStore')).useLearnerStore;
    const rs3 = (await import('@/app/store/useRoadmapStore')).useRoadmapStore;

    cs3.setState({ activeCourse: englishCourse, activeCourseSkills: [] });
    ls3.setState({
      profile: {
        id: 'learner-3',
        courseId: 'course_eng_01',
        displayName: 'Test 3',
        xp: 0,
        streakDays: 0,
        completedLessonIds: ['lesson_eng_starter'],
        scoresByCourse: {},
        flashcardSrsByCourse: {},
        onboardingCompleted: true,
        placementCompleted: true,
      },
    });
    rs3.setState({
      roadmap: { courseId: 'course_eng_01', nodes: [] },
      error: null,
      loadRoadmap: vi.fn().mockResolvedValue(undefined),
    });

    const unhandled: unknown[] = [];
    const onUnhandled = (reason: unknown) => {
      unhandled.push(reason);
    };
    process.on('unhandledRejection', onUnhandled);
    try {
      withReactHookDispatcher(reactMod3, hooks3, () =>
        mod3.RoadmapView({
          onStartLesson: () => {},
          onOpenKnowledgeMap: () => {},
          onChooseCourse: () => {},
          onConfigure: () => {},
        }),
      );
      hooks3.flushEffects();
      await Promise.resolve();
      await new Promise((r) => setTimeout(r, 20));
      expect(prefetchAttempt).toBe(1);
      expect(unhandled).toEqual([]);
      hooks3.unmount();
    } finally {
      process.off('unhandledRejection', onUnhandled);
    }
  });

  it('wraps LazyTutorConversation inside InteractiveLessonView modal with a retryable error boundary', async () => {
    const actualCourses = await import('@/data/datasources/courses');
    const mathCourse = actualCourses.SEED_COURSES.find((c) => c.id === 'course_math_01')!;
    const storage = new Map<string, string>();
    vi.stubGlobal('localStorage', {
      getItem: (k: string) => storage.get(k) ?? null,
      setItem: (k: string, v: string) => storage.set(k, v),
      removeItem: (k: string) => storage.delete(k),
    });

    vi.resetModules();
    const hooks = createHookDispatcher();

    let chatAttempt = 0;
    const FakeTutorConversation = () => null;
    vi.doMock('@/features/ai-tutor/YolchiAIChatView', () => ({
      get TutorConversation() {
        chatAttempt += 1;
        if (chatAttempt === 1) {
          throw new Error('Tutor chunk download failed');
        }
        return FakeTutorConversation;
      },
    }));

    vi.doMock('@/core/context/AuthContext', () => ({
      useAuth: () => ({ account: { id: 'student-1', role: 'student', firstName: 'Ali', lastName: 'Vali' } }),
    }));

    const reactMod = await import('react');
    const { InteractiveLessonView } = await import('@/features/lesson/InteractiveLessonView');
    const { useCourseStore } = await import('@/app/store/useCourseStore');
    const { useLearnerStore } = await import('@/app/store/useLearnerStore');
    const { useLessonStore } = await import('@/app/store/useLessonStore');
    const { Modal } = await import('@/presentation/components/Modal');
    const { Button } = await import('@/presentation/components/Button');

    useCourseStore.setState({ activeCourse: mathCourse, activeCourseSkills: [] });
    useLearnerStore.setState({
      profile: {
        id: 'student-1',
        courseId: 'course_math_01',
        displayName: 'Ali',
        xp: 0,
        streakDays: 0,
        completedLessonIds: [],
        scoresByCourse: {},
        flashcardSrsByCourse: {},
        onboardingCompleted: true,
        placementCompleted: true,
      },
    });
    useLessonStore.setState({
      isLoading: false,
      error: null,
      activeStepIndex: 0,
      currentLesson: {
        id: 'lesson_test_eb',
        courseId: 'course_math_01',
        skillId: 'skill_math_functions',
        title: 'Linear Functions',
        estimatedMinutes: 10,
        summary: 'Basics',
        steps: [{ id: 's1', type: 'explanation', title: 'Intro', content: 'Hello' }],
        reinforcementExercise: {
          id: 'q_reinf',
          courseId: 'course_math_01',
          skillId: 'skill_math_functions',
          text: '2 + 2?',
          options: ['3', '4'],
          difficulty: 'easy',
          explanation: 'Sum is 4',
        },
      },
    });

    const renderLesson = () => {
      const tree = withReactHookDispatcher(reactMod, hooks, () =>
        InteractiveLessonView({
          lessonId: 'lesson_test_eb',
          onFinish: () => {},
          onBackToRoadmap: () => {},
        }),
      );
      hooks.flushEffects();
      return tree;
    };

    let tree = renderLesson();
    const askBtn = findReactNode(
      tree,
      (el) => el.type === Button && collectNodeText(el.props.children).includes('Yo‘lchidan so‘rash'),
    );
    expect(askBtn).not.toBeNull();
    (askBtn!.props.onClick as () => void)();

    tree = renderLesson();
    const modalEl = findReactNode(tree, (el) => el.type === Modal);
    expect(modalEl).not.toBeNull();

    const boundaryEl = modalEl!.props.children as {
      type: {
        getDerivedStateFromError?: () => { hasError: boolean };
        new (props: Record<string, unknown>): {
          props: Record<string, unknown>;
          state: { hasError: boolean };
          setState: (updater: unknown) => void;
          render: () => unknown;
        };
      };
      props: Record<string, unknown>;
    };
    expect(typeof boundaryEl?.type?.getDerivedStateFromError).toBe('function');

    // Trigger first lazy chunk failure (marks LazyTutorConversation failure flag)
    const lazyBefore = findReactNode(boundaryEl.props.children, (el) => Boolean((el.type as { _payload?: unknown })?._init));
    expect(lazyBefore).not.toBeNull();
    const lazyBeforeType = lazyBefore!.type as { _init: (p: unknown) => unknown; _payload: unknown };
    let thrownPromise: unknown;
    try {
      lazyBeforeType._init(lazyBeforeType._payload);
    } catch (pending) {
      thrownPromise = pending;
    }
    await expect(Promise.resolve(thrownPromise)).rejects.toThrow('Tutor chunk download failed');
    expect(chatAttempt).toBe(1);

    // Simulate ErrorBoundary catching error, rendering fallback [role="alert"], and clicking Retry
    const eb = new boundaryEl.type(boundaryEl.props);
    eb.setState = (updater) => {
      const patch = typeof updater === 'function' ? updater(eb.state, eb.props) : updater;
      eb.state = { ...eb.state, ...patch };
    };
    eb.state = boundaryEl.type.getDerivedStateFromError!();

    const fallbackTree = eb.render();
    const alertNode = findReactNode(fallbackTree, (el) => el.props.role === 'alert');
    expect(alertNode).not.toBeNull();
    const retryBtn = findReactNode(
      fallbackTree,
      (el) => el.type === Button && collectNodeText(el.props.children).includes('Qayta urinish'),
    );
    expect(retryBtn).not.toBeNull();

    (retryBtn!.props.onClick as () => void)();
    expect(eb.state.hasError).toBe(false);

    // Next render creates a fresh LazyTutorConversation that resolves attempt 2 cleanly
    const treeAfterRetry = renderLesson();
    const modalAfterRetry = findReactNode(treeAfterRetry, (el) => el.type === Modal);
    const lazyAfter = findReactNode(modalAfterRetry!.props.children, (el) => Boolean((el.type as { _payload?: unknown })?._init));
    expect(lazyAfter).not.toBeNull();
    expect(lazyAfter!.type).not.toBe(lazyBefore!.type);

    const lazyAfterType = lazyAfter!.type as { _init: (p: unknown) => unknown; _payload: unknown };
    let retryPromise: unknown;
    try {
      lazyAfterType._init(lazyAfterType._payload);
    } catch (pending) {
      retryPromise = pending;
    }
    const resolvedComponent = await Promise.resolve(retryPromise);
    expect((resolvedComponent as { default: unknown }).default).toBe(FakeTutorConversation);
    expect(chatAttempt).toBe(2);
  });
});
