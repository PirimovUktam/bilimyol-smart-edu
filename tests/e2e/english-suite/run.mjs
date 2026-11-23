import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import { rm } from 'node:fs/promises';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import * as helpers from './helpers.mjs';

const SUITE_DIR = resolve(fileURLToPath(new URL('.', import.meta.url)));
const REPO_ROOT = resolve(SUITE_DIR, '..', '..', '..');

export const TIER_MODULES = {
  1: { label: 'Tier 1 (Features)', file: 'tier1-features.mjs', minExpected: 35 },
  2: { label: 'Tier 2 (Boundaries)', file: 'tier2-boundaries.mjs', minExpected: 35 },
  3: { label: 'Tier 3 (Combinations)', file: 'tier3-combinations.mjs', minExpected: 7 },
  4: { label: 'Tier 4 (Scenarios)', file: 'tier4-scenarios.mjs', minExpected: 5 },
};

const VALID_MILESTONES = new Set(['M1', 'M2', 'M3', 'M4', 'M5', 'M6', 'all']);

function parseCliArgs(argv) {
  const options = {
    tier: 'all',
    milestone: 'all',
    suiteSelfCheck: false,
    allowPartial: false,
    port: 5201,
    timeout: 5000,
    screenshotsDir: 'artifacts/e2e-english-screenshots',
  };

  for (const arg of argv) {
    if (arg === '--suite-self-check') {
      options.suiteSelfCheck = true;
    } else if (arg === '--allow-partial') {
      options.allowPartial = true;
    } else if (arg.startsWith('--tier=')) {
      options.tier = arg.slice('--tier='.length).trim();
    } else if (arg.startsWith('--milestone=')) {
      options.milestone = arg.slice('--milestone='.length).trim();
    } else if (arg.startsWith('--port=')) {
      const parsed = Number(arg.slice('--port='.length).trim());
      if (!Number.isInteger(parsed) || parsed < 1024 || parsed > 65535) {
        throw new Error(`Invalid --port value: "${arg}"`);
      }
      options.port = parsed;
    } else if (arg.startsWith('--timeout=')) {
      const parsed = Number(arg.slice('--timeout='.length).trim());
      if (!Number.isInteger(parsed) || parsed < 1000 || parsed > 120000) {
        throw new Error(`Invalid --timeout value: "${arg}" (expected 1000..120000 ms)`);
      }
      options.timeout = parsed;
    } else if (arg.startsWith('--screenshots-dir=')) {
      const dir = arg.slice('--screenshots-dir='.length).trim();
      if (!dir) throw new Error('Empty --screenshots-dir value.');
      options.screenshotsDir = dir;
    } else {
      throw new Error(`Unknown CLI flag: "${arg}"`);
    }
  }

  if (options.tier !== 'all' && !['1', '2', '3', '4'].includes(options.tier)) {
    throw new Error(`Invalid --tier="${options.tier}". Expected 1|2|3|4|all.`);
  }
  if (!VALID_MILESTONES.has(options.milestone)) {
    throw new Error(`Invalid --milestone="${options.milestone}". Expected M1|M2|M3|M4|M5|M6|all.`);
  }

  return options;
}

function getRequestedTierKeys(tierOption) {
  return tierOption === 'all' ? [1, 2, 3, 4] : [Number(tierOption)];
}

function expandMilestoneTokens(rawMilestone) {
  const tokens = Array.isArray(rawMilestone)
    ? rawMilestone.flatMap((entry) => String(entry).split(/[,/|]/))
    : String(rawMilestone).split(/[,/|]/);

  const expanded = new Set();
  for (const token of tokens) {
    const trimmed = token.trim().toUpperCase();
    if (!trimmed) continue;
    const rangeMatch = trimmed.match(/^M(\d+)\s*[-\u2013]\s*M(\d+)$/);
    if (rangeMatch) {
      const start = Number(rangeMatch[1]);
      const end = Number(rangeMatch[2]);
      if (start <= end && end - start <= 10) {
        for (let idx = start; idx <= end; idx++) {
          expanded.add(`M${idx}`);
        }
        continue;
      }
    }
    expanded.add(trimmed);
  }
  return expanded;
}

function milestoneMatches(testMilestone, targetMilestone) {
  if (targetMilestone === 'all' || targetMilestone === 'M6') return true;
  if (!testMilestone) return true;
  return expandMilestoneTokens(testMilestone).has(targetMilestone.toUpperCase());
}

function validateTestDescriptor(testCase, fileLabel) {
  assert.ok(testCase && typeof testCase === 'object', `${fileLabel}: test descriptor must be an object.`);
  assert.ok(typeof testCase.id === 'string' && testCase.id.trim().length > 0, `${fileLabel}: test descriptor missing non-empty id.`);
  assert.ok(typeof testCase.name === 'string' && testCase.name.trim().length > 0, `${fileLabel}: test "${testCase.id}" missing non-empty name.`);
  const hasMilestone = Array.isArray(testCase.milestone)
    ? testCase.milestone.length > 0
    : typeof testCase.milestone === 'string' && testCase.milestone.trim().length > 0;
  assert.ok(hasMilestone, `${fileLabel}: test "${testCase.id}" missing milestone tag.`);
  assert.equal(typeof testCase.run, 'function', `${fileLabel}: test "${testCase.id}" missing run(ctx) function.`);
}

async function loadRegisteredTierTests(tierKeys, targetMilestone) {
  const loaded = [];
  for (const tierNum of tierKeys) {
    const meta = TIER_MODULES[tierNum];
    const modulePath = resolve(SUITE_DIR, meta.file);
    if (!existsSync(modulePath)) {
      loaded.push({ tierNum, meta, present: false, tests: [], allTests: [] });
      continue;
    }

    const mod = await import(new URL(`./${meta.file}`, import.meta.url).href);
    const rawTests =
      typeof mod.registerTests === 'function'
        ? await mod.registerTests()
        : typeof mod.getTests === 'function'
          ? await mod.getTests()
          : Array.isArray(mod.tests)
            ? mod.tests
            : Array.isArray(mod.default)
              ? mod.default
              : [];

    for (const testCase of rawTests) {
      validateTestDescriptor(testCase, meta.file);
    }

    const filtered = rawTests.filter((t) => milestoneMatches(t.milestone, targetMilestone));
    loaded.push({
      tierNum,
      meta,
      present: true,
      tests: filtered,
      allTests: rawTests,
      totalInModule: rawTests.length,
    });
  }
  return loaded;
}

function verifyHelperExports() {
  const requiredExports = [
    'BASE_VIEWPORTS',
    'createEnglishE2EContext',
    'launchDemoSession',
    'selectCourse',
    'setLocale',
    'setTheme',
    'setViewportPreset',
    'throttleNetwork',
    'openAndCloseYolchiAi',
    'reloadAndVerifyPersistence',
    'captureFailureScreenshot',
    'captureViewPairScreenshots',
    'assertNoHorizontalOverflow',
    'assertNoSupabaseCallsInDemo',
    'assertNoPageErrors',
    'readDemoProgressSnapshot',
  ];

  for (const name of requiredExports) {
    assert.ok(name in helpers, `helpers.mjs missing required export "${name}".`);
  }
}

function buildSmokeTests() {
  return [
    {
      id: 'M_E2E_1-SMK-01',
      name: 'Demo login -> course_eng_01 -> lesson_eng_starter -> Yolchi AI open/close -> reload persistence',
      milestone: 'M1',
      async run({ page, session, baseUrl }) {
        await helpers.launchDemoSession(page, baseUrl);
        await helpers.selectCourse(page, 'course_eng_01');

        const main = page.getByRole('main');
        await main.getByRole('radio', { name: /Noldan boşlayman/i }).check();
        await main.getByRole('button', { name: 'Birinçi darsni boşlaş' }).click();

        await main
          .getByRole('heading', { name: 'Birinçi inglizça sözlar' })
          .first()
          .waitFor({ state: 'visible' });
        await main
          .getByRole('heading', { name: 'Asosiy tuşunça' })
          .first()
          .waitFor({ state: 'visible' });

        await main.getByRole('button', { name: 'Keyingi qadam' }).click();
        await main
          .getByRole('heading', { name: 'Birga misol köramiz' })
          .first()
          .waitFor({ state: 'visible' });

        await helpers.openAndCloseYolchiAi(page, {
          askText: 'Hello qaçon işlatiladi?',
          closeWith: 'button',
          preserveStepIndicator: /^Qadam 2 \/ \d+$/,
          preserveText: 'Birga misol köramiz',
        });
        await helpers.openAndCloseYolchiAi(page, {
          askText: 'Good morning qaçon işlatiladi?',
          closeWith: 'escape',
          preserveStepIndicator: /^Qadam 2 \/ \d+$/,
          preserveText: 'Birga misol köramiz',
        });
        await main
          .getByRole('heading', { name: 'Birga misol köramiz' })
          .first()
          .waitFor({ state: 'visible' });

        await helpers.reloadAndVerifyPersistence(page, async ({ before, after }) => {
          assert.ok(before.sessionRaw, 'Expected demo session before reload.');
          assert.ok(after.sessionRaw, 'Expected demo session after reload.');
          await main
            .getByRole('heading', { name: 'Birga misol köramiz' })
            .first()
            .waitFor({ state: 'visible' });
        });

        helpers.assertNoSupabaseCallsInDemo(session.remoteRequests, 'M_E2E_1-SMK-01');
        helpers.assertNoPageErrors(session.errors, 'M_E2E_1-SMK-01');
      },
    },
    {
      id: 'M_E2E_1-SMK-02',
      name: 'Course isolation (course_math_01) + locale (uz/ru) + theme (light/dark) + 390px/1440px overflow check',
      milestone: 'M1',
      async run({ page, session, baseUrl }) {
        await helpers.setViewportPreset(page, 'mobile390');
        await helpers.launchDemoSession(page, baseUrl);
        await helpers.selectCourse(page, 'course_eng_01');
        await helpers.assertNoHorizontalOverflow(page, 'mobile390-course-eng');

        await helpers.setLocale(page, 'ru');
        await helpers.setTheme(page, 'dark');
        await helpers.setViewportPreset(page, 'desktop1440');

        await helpers.selectCourse(page, 'course_math_01');
        const snapshot = await helpers.readDemoProgressSnapshot(page);
        const completed = snapshot.progress?.profile?.completedLessonIds ?? [];
        assert.equal(
          completed.includes('lesson_math_starter'),
          false,
          'Math starter must remain uncompleted when only English was visited.',
        );

        await helpers.setLocale(page, 'uz');
        await helpers.setTheme(page, 'light');
        await helpers.assertNoHorizontalOverflow(page, 'desktop1440-uz-light');
        helpers.assertNoSupabaseCallsInDemo(session.remoteRequests, 'M_E2E_1-SMK-02');
        helpers.assertNoPageErrors(session.errors, 'M_E2E_1-SMK-02');
      },
    },
  ];
}

function validateLoadedSuite(options, loaded) {
  const presentEntries = loaded.filter((entry) => entry.present);
  const missingEntries = loaded.filter((entry) => !entry.present);

  const seenIds = new Set();
  for (const entry of presentEntries) {
    for (const testCase of entry.allTests ?? entry.tests) {
      if (seenIds.has(testCase.id)) {
        throw new Error(`Duplicate testCase.id "${testCase.id}" detected in ${entry.meta.file}.`);
      }
      seenIds.add(testCase.id);
    }
  }

  if (options.tier !== 'all') {
    if (missingEntries.length > 0) {
      throw new Error(
        `Requested --tier=${options.tier}, but ${missingEntries[0].meta.file} does not exist. M_E2E_1 smoke fallback is disabled for explicit --tier.`,
      );
    }
    const entry = loaded[0];
    if (entry.tests.length === 0) {
      throw new Error(
        `Filter --tier=${options.tier} --milestone=${options.milestone} matched 0 tests in ${entry.meta.file}.`,
      );
    }
    if (
      (options.milestone === 'all' || options.milestone === 'M6') &&
      !options.allowPartial &&
      entry.totalInModule < entry.meta.minExpected
    ) {
      throw new Error(
        `${entry.meta.label} has ${entry.totalInModule} tests (< minExpected ${entry.meta.minExpected}). Pass --allow-partial to run a partial tier.`,
      );
    }
    return { mode: 'tiers', testsCount: entry.tests.length, smokeTests: [] };
  }

  if (presentEntries.length === 0) {
    if (options.milestone !== 'all' && options.milestone !== 'M1') {
      throw new Error(
        `M_E2E_1 smoke mode applies only when --tier=all and --milestone=all|M1. Requested --milestone=${options.milestone}, but no tier1..4 modules exist yet.`,
      );
    }
    const smokeTests = buildSmokeTests().filter((t) =>
      milestoneMatches(t.milestone, options.milestone),
    );
    if (smokeTests.length === 0) {
      throw new Error(`Filter --milestone=${options.milestone} matched 0 M_E2E_1 smoke tests.`);
    }
    return { mode: 'smoke', testsCount: smokeTests.length, smokeTests };
  }

  if (!options.allowPartial) {
    if (missingEntries.length > 0) {
      throw new Error(
        `Missing tier module(s) under --tier=all: ${missingEntries.map((e) => e.meta.file).join(', ')}. Pass --allow-partial to run partial tiers.`,
      );
    }
    if (options.milestone === 'all' || options.milestone === 'M6') {
      const underMin = presentEntries.filter((e) => e.totalInModule < e.meta.minExpected);
      if (underMin.length > 0) {
        throw new Error(
          `Tier module(s) below minExpected under --milestone=${options.milestone}: ${underMin.map((e) => `${e.meta.file} (${e.totalInModule}/${e.meta.minExpected})`).join(', ')}. Pass --allow-partial to bypass.`,
        );
      }
    }
  }

  const totalMatched = presentEntries.reduce((sum, e) => sum + e.tests.length, 0);
  if (totalMatched === 0) {
    throw new Error(
      `Filter --tier=all --milestone=${options.milestone} matched 0 tests across present tier modules.`,
    );
  }
  return { mode: 'tiers', testsCount: totalMatched, smokeTests: [] };
}

async function runSuiteSelfCheck(options) {
  verifyHelperExports();
  const tierKeys = getRequestedTierKeys(options.tier);
  const loaded = await loadRegisteredTierTests(tierKeys, options.milestone);
  const plan = validateLoadedSuite(options, loaded);

  console.log('=== BilimYöl English E2E Suite Self-Check ===');
  console.log(`Helpers verified: OK`);
  console.log(
    `Filter: --tier=${options.tier} --milestone=${options.milestone}${options.allowPartial ? ' --allow-partial' : ''}`,
  );

  for (const entry of loaded) {
    if (!entry.present) {
      const stateLabel =
        plan.mode === 'smoke'
          ? 'PENDING (M_E2E_1 smoke active)'
          : 'MISSING (allowed via --allow-partial)';
      console.log(`${entry.meta.label}: ${stateLabel} (${entry.meta.file})`);
      continue;
    }
    console.log(
      `${entry.meta.label}: ${entry.tests.length} matching tests (${entry.totalInModule} total in ${entry.meta.file}, target >= ${entry.meta.minExpected})`,
    );
  }

  console.log(`M_E2E_1 Smoke Tests: ${plan.smokeTests.length}`);
  console.log(`Total Selected Tests: ${plan.testsCount}`);
}

async function runPlaywrightSuite(options) {
  verifyHelperExports();
  const tierKeys = getRequestedTierKeys(options.tier);
  const loaded = await loadRegisteredTierTests(tierKeys, options.milestone);
  const plan = validateLoadedSuite(options, loaded);

  process.env.VITE_SUPABASE_URL = '';
  process.env.VITE_SUPABASE_ANON_KEY = '';

  const { build, preview } = await import('vite');
  const { chromium } = await import('playwright');

  const host = '127.0.0.1';
  const outDir = resolve(REPO_ROOT, 'dist-english-e2e');
  const mode = 'e2e-offline';
  const baseUrl = `http://${host}:${options.port}`;

  let server = null;
  let browser = null;
  const summary = [];
  let totalPassed = 0;
  let totalFailed = 0;

  try {
    await build({ mode, build: { outDir } });
    server = await preview({
      mode,
      build: { outDir },
      preview: { host, port: options.port, strictPort: true },
    });
    browser = await chromium.launch();

    if (plan.mode === 'smoke') {
      let passed = 0;
      let failed = 0;
      for (const testCase of plan.smokeTests) {
        const session = await helpers.createEnglishE2EContext(browser);
        try {
          await testCase.run({
            browser,
            baseUrl,
            session,
            page: session.page,
            helpers,
            screenshotsDir: options.screenshotsDir,
          });
          passed++;
          totalPassed++;
          console.log(`PASS [${testCase.id}] ${testCase.name}`);
        } catch (err) {
          failed++;
          totalFailed++;
          let shot = '';
          try {
            shot = await helpers.captureFailureScreenshot(
              session.page,
              testCase.id || testCase.name,
              options.screenshotsDir,
            );
          } catch {
            // Ignore screenshot failure if page crashed/closed.
          }
          console.error(
            `FAIL [${testCase.id}] ${testCase.name}: ${err?.message ?? err}${shot ? ` (screenshot: ${shot})` : ''}`,
          );
        } finally {
          await session.dispose();
        }
      }
      summary.push({ label: 'M_E2E_1 Smoke', passed, failed });
    } else {
      for (const entry of loaded) {
        if (!entry.present) {
          summary.push({ label: entry.meta.label, passed: 0, failed: 0, skipped: true });
          continue;
        }
        let passed = 0;
        let failed = 0;
        for (const testCase of entry.tests) {
          const session = await helpers.createEnglishE2EContext(browser, {
            defaultTimeout: options.timeout,
            ...(testCase.contextOptions ?? {}),
          });
          try {
            await testCase.run({
              browser,
              baseUrl,
              session,
              page: session.page,
              helpers,
              screenshotsDir: options.screenshotsDir,
            });
            passed++;
            totalPassed++;
            console.log(`PASS [${testCase.id}] ${testCase.name}`);
          } catch (err) {
            failed++;
            totalFailed++;
            let shot = '';
            try {
              shot = await helpers.captureFailureScreenshot(
                session.page,
                testCase.id || testCase.name,
                options.screenshotsDir,
              );
            } catch {
              // Ignore screenshot failure if page crashed/closed.
            }
            console.error(
              `FAIL [${testCase.id}] ${testCase.name}: ${err?.message ?? err}${shot ? ` (screenshot: ${shot})` : ''}`,
            );
          } finally {
            await session.dispose();
          }
        }
        summary.push({ label: entry.meta.label, passed, failed });
      }
    }
  } finally {
    if (browser) {
      await browser.close().catch(() => {});
    }
    if (server?.httpServer) {
      server.httpServer.closeAllConnections?.();
      await new Promise((resolveClose) => server.httpServer.close(resolveClose));
    }
    await rm(outDir, { recursive: true, force: true }).catch(() => {});
  }

  console.log('\n=== BilimYöl English E2E Summary ===');
  for (const row of summary) {
    if (row.skipped) {
      console.log(`${row.label}: 0/0 (not registered)`);
    } else {
      console.log(`${row.label}: ${row.passed}/${row.passed + row.failed} passed`);
    }
  }
  console.log(`Total: ${totalPassed}/${totalPassed + totalFailed} passed`);

  if (totalFailed > 0 || totalPassed === 0) {
    process.exitCode = 1;
  }
}

try {
  const options = parseCliArgs(process.argv.slice(2));
  if (options.suiteSelfCheck) {
    await runSuiteSelfCheck(options);
  } else {
    await runPlaywrightSuite(options);
  }
} catch (err) {
  console.error(`Error: ${err?.message ?? err}`);
  process.exitCode = 1;
}
