import assert from 'node:assert/strict';
import { rm } from 'node:fs/promises';
import { chromium } from 'playwright';

const port = Number(process.env.PILOT_E2E_PORT ?? '5198');
const host = '127.0.0.1';
const outDir = 'dist-pilot-e2e';
const mode = 'pilot-e2e';
const supabaseUrl = 'https://pilot-test.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiJ9.mock';

process.env.VITE_SUPABASE_URL = supabaseUrl;
process.env.VITE_SUPABASE_ANON_KEY = supabaseKey;

const { build, preview } = await import('vite');
await build({ mode, build: { outDir } });
const server = await preview({ mode, build: { outDir }, preview: { host, port, strictPort: true } });

const baseUrl = `http://${host}:${port}`;
const userId = '00000000-0000-0000-0000-000000000901';
const storageKey = 'sb-pilot-test-auth-token';

const baseProgression = (overrides = {}) => [
  {
    id: 'node_math_addition',
    course_id: 'course_math_01',
    skill_id: 'skill_math_addition',
    title: 'Qöşiş va ayiriş',
    description: 'Birlaştiriş va ayrim qismini olib taşlaşni sonlar bilan ifodalang.',
    prerequisites: [],
    required_score: 80,
    target_lesson_id: 'lesson_math_starter',
    estimated_minutes: 8,
    order_index: 10,
    status: overrides.firstStatus ?? 'available',
    mastery_state: (overrides.firstAnswered ?? 0) > 0 ? 'practicing' : 'not_started',
    answered: overrides.firstAnswered ?? 0,
    correct: overrides.firstCorrect ?? 0,
    required_items: 5,
    passed_checkpoints: 0,
    required_checkpoints: 2,
    review_due: false,
    is_optional: false,
  },
  {
    id: 'node_math_multiplication',
    course_id: 'course_math_01',
    skill_id: 'skill_math_multiplication',
    title: 'Teng guruhlar va köpaytiriş',
    description: 'Teng guruhlarni takroriy qöşiş va köpaytiriş bilan ifodalang.',
    prerequisites: ['node_math_addition'],
    required_score: 80,
    target_lesson_id: 'lesson_math_foundation_02',
    estimated_minutes: 8,
    order_index: 20,
    status: 'locked',
    mastery_state: 'not_started',
    answered: 0,
    correct: 0,
    required_items: 5,
    passed_checkpoints: 0,
    required_checkpoints: 2,
    review_due: false,
    is_optional: false,
  },
];

let currentSkillScores = [];
let currentProgression = baseProgression();

const browser = await chromium.launch();
try {
  const context = await browser.newContext({ viewport: { width: 1440, height: 960 }, reducedMotion: 'reduce' });
  await context.addInitScript(({ key, uid }) => {
    const exp = Math.floor(Date.now() / 1000) + 3600;
    localStorage.setItem(key, JSON.stringify({
      access_token: 'mock-access-token',
      refresh_token: 'mock-refresh-token',
      expires_in: 3600,
      expires_at: exp,
      token_type: 'bearer',
      user: {
        id: uid,
        email: 'pilot@example.test',
        role: 'authenticated',
        aud: 'authenticated',
        user_metadata: { first_name: 'Ali', last_name: 'Valiyev' },
      },
    }));
  }, { key: storageKey, uid: userId });

  const page = await context.newPage();
  const pageErrors = [];
  page.on('pageerror', (err) => pageErrors.push(err.message));
  page.setDefaultTimeout(12000);

  await page.route('https://fonts.googleapis.com/**', (route) => route.abort());
  await page.route('https://fonts.gstatic.com/**', (route) => route.abort());
  await page.route(`${supabaseUrl}/**`, async (route) => {
    const req = route.request();
    const url = new URL(req.url());
    const accept = req.headers()['accept'] ?? '';
    const wantsObject = accept.includes('application/vnd.pgrst.object+json');
    const json = (body, status = 200) =>
      route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) });

    if (url.pathname === '/auth/v1/user') {
      return json({
        id: userId,
        email: 'pilot@example.test',
        role: 'authenticated',
        aud: 'authenticated',
        user_metadata: { first_name: 'Ali', last_name: 'Valiyev' },
      });
    }
    if (url.pathname === '/rest/v1/profiles') {
      const row = {
        id: userId,
        first_name: 'Ali',
        last_name: 'Valiyev',
        display_name: 'Ali Valiyev',
        email: 'pilot@example.test',
        avatar_url: null,
        role: 'student',
        created_at: '2026-11-18T00:00:00Z',
        updated_at: '2026-11-18T00:00:00Z',
      };
      return json(wantsObject ? row : [row]);
    }
    if (url.pathname === '/rest/v1/learner_profiles') {
      const row = {
        user_id: userId,
        selected_course_id: 'course_math_01',
        goal: 'mastery',
        daily_minutes: 15,
        initial_level: 'intermediate',
        course_levels: { course_math_01: 'intermediate' },
        created_at: '2026-11-18T00:00:00Z',
      };
      return json(wantsObject ? row : [row]);
    }
    if (url.pathname === '/rest/v1/gamification_profiles') {
      const row = { user_id: userId, xp: 20, streak_days: 1, last_activity_date: '2026-11-18' };
      return json(wantsObject ? row : [row]);
    }
    if (url.pathname === '/rest/v1/user_preferences') {
      const row = { user_id: userId, notifications_enabled: true };
      return json(wantsObject ? row : [row]);
    }
    if (url.pathname === '/rest/v1/learner_skill_scores') {
      return json(currentSkillScores);
    }
    if (url.pathname === '/rest/v1/lesson_progress' || url.pathname === '/rest/v1/reinforcement_attempts') {
      return json([]);
    }
    if (url.pathname === '/rest/v1/courses') {
      return json([{
        id: 'course_math_01',
        title: 'Matematika',
        subject: 'mathematics',
        description: 'Matematika kursi',
        icon_name: 'Calculator',
        primary_color_hex: '#4F46E5',
        secondary_color_hex: '#818CF8',
        total_students_estimate: 1000,
        is_active: true,
      }]);
    }
    if (url.pathname === '/rest/v1/skills') {
      return json([
        {
          id: 'skill_math_addition',
          course_id: 'course_math_01',
          name: 'Qöşiş va ayiriş',
          code: 'MATH_ADD',
          description: 'Miqdorlarni birlaştiriş va farqni topiş.',
          order_index: -2,
          icon_name: 'Calculator',
        },
        {
          id: 'skill_math_multiplication',
          course_id: 'course_math_01',
          name: 'Teng guruhlar',
          code: 'MATH_MUL',
          description: 'Teng miqdorlarni takror qöşiş va köpaytiriş.',
          order_index: -1,
          icon_name: 'Calculator',
        },
      ]);
    }
    if (url.pathname === '/rest/v1/learner_lessons') {
      if (url.searchParams.get('id')?.startsWith('eq.')) {
        const lessonRow = {
          id: 'lesson_math_starter',
          course_id: 'course_math_01',
          skill_id: 'skill_math_addition',
          title: 'Qöşiş va ayirişdan boşlaymiz',
          summary: 'Qöşiş va ayiriş asoslari',
          estimated_minutes: 8,
          is_locked: false,
          steps: [
            {
              id: 'step_1',
              stepNumber: 1,
              type: 'concept',
              title: 'Asosiy tuşunça',
              content: 'Ikki guruhni birlaştiramiz.',
            },
            {
              id: 'step_2',
              stepNumber: 2,
              type: 'interactive_question',
              title: 'Mustaqil maşq',
              content: 'Javobni tanlang.',
              masteryCheckpoint: 'application',
              interactiveQuestion: {
                id: 'q_pilot_lesson_math_starter_1',
                text: '4 ta kök va 3 ta oq tugma bor. Jami neçta?',
                options: ['7', '1', '12'],
                difficulty: 'easy',
              },
            },
            {
              id: 'step_3',
              stepNumber: 3,
              type: 'concept',
              title: 'Darsni yakunlaş',
              content: 'Yaxşi davom eting.',
            },
          ],
          reinforcement_exercise: {
            id: 'q_pilot_lesson_math_starter_1',
            text: '4 ta kök va 3 ta oq tugma bor. Jami neçta?',
            options: ['7', '1', '12'],
            difficulty: 'easy',
          },
        };
        return json(wantsObject ? lessonRow : [lessonRow]);
      }
      return json([
        { id: 'lesson_math_starter', course_id: 'course_math_01' },
        { id: 'lesson_math_foundation_02', course_id: 'course_math_01' },
      ]);
    }
    if (url.pathname === '/rest/v1/rpc/get_math_progression') {
      return json(currentProgression);
    }
    if (url.pathname === '/rest/v1/rpc/submit_answer_attempt') {
      currentProgression = baseProgression({ firstAnswered: 1, firstCorrect: 1, firstStatus: 'in_progress' });
      return json({
        is_correct: true,
        explanation: '4 + 3 = 7.',
        new_skill_score: 100,
        overall_score: 100,
        xp_awarded: 4,
        total_xp: 24,
        total_attempts: 1,
        correct_attempts: 1,
        already_processed: false,
      });
    }
    if (url.pathname === '/rest/v1/rpc/record_learning_activity') {
      return json({ streak_days: 1 });
    }
    return json([]);
  });

  const main = page.getByRole('main');

  // 1. State B (4/4 diagnostics, answered = 0) + click test to expected open lesson
  currentSkillScores = [
    {
      course_id: 'course_math_01',
      skill_id: 'skill_math_addition',
      score: 100,
      last_updated: '2026-11-18T00:00:00Z',
      mastery_level: 'mastered',
      is_weakest_focus: true,
    },
    {
      course_id: 'course_math_01',
      skill_id: 'skill_math_multiplication',
      score: 100,
      last_updated: '2026-11-18T00:00:00Z',
      mastery_level: 'mastered',
      is_weakest_focus: false,
    },
  ];
  currentProgression = baseProgression();
  const expectedTargetLessonId = currentProgression.find((n) => n.status !== 'locked' && n.status !== 'completed')?.target_lesson_id;
  assert(expectedTargetLessonId, 'Fixture must have an open node target_lesson_id');

  await page.goto(`${baseUrl}/?view=knowledge-map`, { waitUntil: 'domcontentloaded' });
  await main.getByRole('heading', { name: 'Diagnostika natijasi' }).waitFor({ state: 'visible' });
  assert.equal(await main.getByRole('button', { name: 'Diagnostikani boşlaş' }).count(), 0);
  const startButtons = main.getByRole('button', { name: 'Birinçi maşqni boşlaş' });
  assert.equal(await startButtons.count(), 1, 'Expected exactly one Birinçi maşqni boşlaş button');
  assert.equal(await main.getByRole('progressbar', { name: 'Umumiy özlaştiriş' }).getAttribute('aria-valuenow'), '0');
  await main.getByText(/2-mavzu.*Qulflangan/).waitFor({ state: 'visible' });
  assert.equal(await main.getByText(/xato qildingiz|Bilim böşliği aniqlandi/i).count(), 0);

  await startButtons.first().click();
  await page.waitForFunction((lessonId) => {
    const params = new URLSearchParams(window.location.search);
    return params.get('view') === 'lesson' && params.get('lessonId') === lessonId;
  }, expectedTargetLessonId);
  await main.getByRole('heading', { name: 'Qöşiş va ayirişdan boşlaymiz' }).waitFor({ state: 'visible' });
  console.log('PASS Pilot State B (4/4) click routes to open targetLessonId:', expectedTargetLessonId);

  // 1b. Answer one exercise in the lesson and return to Knowledge Map via browser Back (SPA navigation without reload)
  await main.getByRole('button', { name: 'Keyingi qadam' }).click();
  await main.getByText('7', { exact: true }).click();
  await main.getByRole('button', { name: /Tekşiriş/i }).click();
  await main.getByText(/Töğri/i).first().waitFor({ state: 'visible' });
  await page.goBack();
  await main.getByText('1 · Baholangan mavzular').waitFor({ state: 'visible' });
  await main.getByText(/1\/5/).first().waitFor({ state: 'visible' });
  assert.equal(await main.getByRole('button', { name: 'Birinçi maşqni boşlaş' }).count(), 0);
  console.log('PASS Pilot SPA return to KnowledgeMap after 1st exercise refreshes roadmap (answered > 0)');

  // 2. State B fallback when no open lesson exists -> Ta'lim yöli (roadmap)
  currentProgression = baseProgression({ firstStatus: 'locked' });
  await page.goto(`${baseUrl}/?view=knowledge-map`, { waitUntil: 'domcontentloaded' });
  await main.getByRole('heading', { name: 'Diagnostika natijasi' }).waitFor({ state: 'visible' });
  const fallbackButtons = main.getByRole('button', { name: 'Birinçi maşqni boşlaş' });
  assert.equal(await fallbackButtons.count(), 1);
  await fallbackButtons.first().click();
  await page.waitForFunction(() => new URLSearchParams(window.location.search).get('view') === 'roadmap');
  await main.getByRole('heading', { name: /Mening ta’lim yölim/ }).waitFor({ state: 'visible' });
  console.log('PASS Pilot State B fallback routes to Ta’lim yöli when no open lesson exists');

  // 3. State B with diagnostic gap (< 100) names that skill
  currentSkillScores = [
    {
      course_id: 'course_math_01',
      skill_id: 'skill_math_addition',
      score: 100,
      last_updated: '2026-11-18T00:00:00Z',
      mastery_level: 'mastered',
      is_weakest_focus: false,
    },
    {
      course_id: 'course_math_01',
      skill_id: 'skill_math_multiplication',
      score: 50,
      last_updated: '2026-11-18T00:00:00Z',
      mastery_level: 'developing',
      is_weakest_focus: true,
    },
  ];
  currentProgression = baseProgression();
  await page.goto(`${baseUrl}/?view=knowledge-map`, { waitUntil: 'domcontentloaded' });
  await main.getByRole('heading', { name: 'Diagnostika natijasi' }).waitFor({ state: 'visible' });
  await main.getByText(/Teng guruhlar.*50%/).waitFor({ state: 'visible' });
  assert.equal(await main.getByRole('button', { name: 'Birinçi maşqni boşlaş' }).count(), 1);
  console.log('PASS Pilot State B (score < 100) names gap skill');

  // 3b. Layout & theme checks on State B (360px/390px/1440px, light & dark)
  for (const [width, theme] of [[360, 'light'], [390, 'dark'], [1440, 'dark']]) {
    await page.setViewportSize({ width, height: 844 });
    await page.evaluate((nextTheme) => {
      document.documentElement.dataset.theme = nextTheme;
      document.documentElement.classList.toggle('dark', nextTheme === 'dark');
    }, theme);
    const hasOverflow = await page.evaluate(() => document.documentElement.scrollWidth > window.innerWidth);
    assert.equal(hasOverflow, false, `Horizontal overflow detected at ${width}px (${theme})`);
    assert.equal(await main.getByRole('button', { name: 'Birinçi maşqni boşlaş' }).count(), 1);
  }
  await page.setViewportSize({ width: 1440, height: 960 });
  await page.evaluate(() => {
    document.documentElement.dataset.theme = 'light';
    document.documentElement.classList.remove('dark');
  });
  console.log('PASS Pilot State B layout has zero horizontal overflow across 360px/390px/1440px light & dark');

  // 4. State A (no diagnostic scores, answered = 0)
  currentSkillScores = [];
  currentProgression = baseProgression();
  await page.goto(`${baseUrl}/?view=knowledge-map`, { waitUntil: 'domcontentloaded' });
  await main.getByRole('button', { name: 'Diagnostikani boşlaş' }).waitFor({ state: 'visible' });
  assert.equal(await main.getByRole('button', { name: 'Birinçi maşqni boşlaş' }).count(), 0);
  console.log('PASS Pilot State A shows Diagnostikani boşlaş');

  // 5. Post-exercise (answered > 0) shows lesson progress
  currentSkillScores = [
    {
      course_id: 'course_math_01',
      skill_id: 'skill_math_addition',
      score: 100,
      last_updated: '2026-11-18T00:00:00Z',
      mastery_level: 'mastered',
      is_weakest_focus: true,
    },
  ];
  currentProgression = baseProgression({ firstAnswered: 2, firstCorrect: 2, firstStatus: 'in_progress' });
  await page.goto(`${baseUrl}/?view=knowledge-map`, { waitUntil: 'domcontentloaded' });
  await main.getByText('1 · Baholangan mavzular').waitFor({ state: 'visible' });
  assert.equal(await main.getByRole('button', { name: 'Birinçi maşqni boşlaş' }).count(), 0);
  assert.equal(await main.getByRole('button', { name: 'Diagnostikani boşlaş' }).count(), 0);
  console.log('PASS Pilot post-exercise (answered > 0) shows lesson progress');

  assert.deepEqual(pageErrors, [], `Unexpected page errors: ${pageErrors.join(', ')}`);
  console.log('PILOT KNOWLEDGE MAP CLICK TEST PASSED');
} finally {
  await browser.close();
  server.httpServer.closeAllConnections?.();
  await new Promise((resolve) => server.httpServer.close(resolve));
  await rm(outDir, { recursive: true, force: true });
}
