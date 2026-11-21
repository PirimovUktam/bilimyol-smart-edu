import assert from 'node:assert/strict';
import { mkdir } from 'node:fs/promises';
import { join } from 'node:path';

export const BASE_VIEWPORTS = {
  mobile390: { width: 390, height: 844 },
  desktop1440: { width: 1440, height: 900 },
};

const COURSE_TITLE_PATTERNS = {
  course_eng_01: /Ingliz tili|Английский/i,
  course_math_01: /Matematika|Математика/i,
  course_it: /IT & Kodlash|IT/i,
  course_logic: /Mantiq|Логика/i,
};

function resolveViewport(viewport) {
  if (typeof viewport === 'string') {
    const preset = BASE_VIEWPORTS[viewport];
    if (!preset) {
      throw new Error(`Unknown viewport preset "${viewport}". Expected one of: ${Object.keys(BASE_VIEWPORTS).join(', ')}`);
    }
    return { ...preset };
  }
  if (viewport && typeof viewport.width === 'number' && typeof viewport.height === 'number') {
    return { width: viewport.width, height: viewport.height };
  }
  return { ...BASE_VIEWPORTS.desktop1440 };
}

export async function createEnglishE2EContext(browser, options = {}) {
  const {
    viewport = 'desktop1440',
    locale = 'uz',
    theme = 'light',
    reducedMotion = 'reduce',
    defaultTimeout = 5000,
  } = options;

  if (locale !== 'uz' && locale !== 'ru') {
    throw new Error(`Unsupported locale "${locale}". Expected "uz" or "ru".`);
  }
  if (theme !== 'light' && theme !== 'dark') {
    throw new Error(`Unsupported theme "${theme}". Expected "light" or "dark".`);
  }

  const resolvedViewport = resolveViewport(viewport);
  const context = await browser.newContext({
    viewport: resolvedViewport,
    reducedMotion,
  });

  if (locale !== 'uz' || theme !== 'light') {
    await context.addInitScript(
      ({ initialLocale, initialTheme }) => {
        if (!sessionStorage.getItem('__e2e_prefs_seeded')) {
          if (initialLocale !== 'uz') {
            localStorage.setItem('bilimyol.language', initialLocale);
          }
          if (initialTheme !== 'light') {
            localStorage.setItem('bilimyol.theme', initialTheme);
          }
          sessionStorage.setItem('__e2e_prefs_seeded', '1');
        }
      },
      { initialLocale: locale, initialTheme: theme },
    );
  }

  const page = await context.newPage();
  page.setDefaultTimeout(defaultTimeout);

  const errors = [];
  const remoteRequests = [];

  page.on('pageerror', (error) => {
    errors.push(error?.message ?? String(error));
  });

  page.on('request', (request) => {
    try {
      const url = new URL(request.url());
      const isHostedSupabase = url.hostname.endsWith('.supabase.co');
      let pageOrigin = null;
      try {
        const currentPageUrl = page.url();
        if (currentPageUrl && currentPageUrl.startsWith('http')) {
          pageOrigin = new URL(currentPageUrl).origin;
        }
      } catch {
        pageOrigin = null;
      }
      const isSupabaseApiPath = ['/rest/v1/', '/auth/v1/', '/functions/v1/'].some((prefix) =>
        url.pathname.startsWith(prefix),
      );
      const isNonPreviewOrigin = pageOrigin === null || url.origin !== pageOrigin;

      if (isHostedSupabase || (isSupabaseApiPath && isNonPreviewOrigin)) {
        remoteRequests.push(`${request.method()} ${url.origin}${url.pathname}`);
      }
    } catch {
      // Ignore malformed/non-HTTP URLs such as data: or blob:
    }
  });

  await page.route('https://fonts.googleapis.com/**', async (route) => {
    await route.fulfill({
      status: 200,
      contentType: 'text/css',
      body: '/* E2E offline font stylesheet stub */',
    });
  });

  await page.route('https://fonts.gstatic.com/**', async (route) => {
    await route.abort();
  });

  return {
    context,
    page,
    errors,
    remoteRequests,
    async dispose() {
      await context.close();
    },
  };
}

export async function launchDemoSession(page, baseUrl) {
  await page.goto(baseUrl, { waitUntil: 'domcontentloaded', timeout: 15000 });
  const main = page.getByRole('main');

  const demoBtn = page.getByRole('button', {
    name: /Namuna hisobi bilan kirish|Войти в деморежим/i,
  });

  const postAuthHeading = main.getByRole('heading', {
    name: /O‘zingizga mos fanni tanlang|Выберите подходящий предмет|Assalomu alaykum|Здравствуйте/i,
  });

  const demoVisible = await demoBtn.first().isVisible().catch(() => false);
  if (demoVisible) {
    await demoBtn.first().click();
  } else {
    const alreadyInWorkspace = await postAuthHeading.first().isVisible().catch(() => false);
    if (!alreadyInWorkspace) {
      await demoBtn.first().waitFor({ state: 'visible' });
      await demoBtn.first().click();
    }
  }

  await postAuthHeading.first().waitFor({ state: 'visible' });
}

async function clickFirstVisible(locator) {
  const count = await locator.count().catch(() => 0);
  for (let i = 0; i < count; i++) {
    const candidate = locator.nth(i);
    if (await candidate.isVisible().catch(() => false)) {
      await candidate.click();
      return true;
    }
  }
  return false;
}

export async function selectCourse(page, courseId) {
  const titlePattern = COURSE_TITLE_PATTERNS[courseId];
  if (!titlePattern) {
    throw new Error(`Unsupported courseId "${courseId}" in selectCourse.`);
  }

  const main = page.getByRole('main');
  const courseHeading = main.getByRole('heading', {
    name: /O‘zingizga mos fanni tanlang|Выберите подходящий предмет/i,
  });

  if (!(await courseHeading.isVisible().catch(() => false))) {
    const switchBtn = page.getByRole('button', {
      name: /Fanni almashtirish|Сменить предмет/i,
    });
    if (!(await clickFirstVisible(switchBtn))) {
      const backBtn = main.getByRole('button', {
        name: /Ta’lim yo‘liga qaytish|Вернуться к пути обучения/i,
      });
      await clickFirstVisible(backBtn);
      const postSwitchBtn = page.getByRole('button', {
        name: /Fanni almashtirish|Сменить предмет/i,
      });
      if (!(await clickFirstVisible(postSwitchBtn))) {
        const coursesNav = page.getByRole('button', { name: /^Kurslar$|^Курсы$/i });
        if (!(await clickFirstVisible(coursesNav))) {
          await coursesNav.first().click();
        }
      }
    }
  }

  await courseHeading.waitFor({ state: 'visible' });

  const specificCourseBtn = main.getByRole('button', {
    name: new RegExp(`(${titlePattern.source}).*(fanini tanlash|Выбрать предмет)|Выбрать предмет.*(${titlePattern.source})`, 'i'),
  });

  if ((await specificCourseBtn.count()) > 0) {
    await specificCourseBtn.first().click();
  } else {
    await main.getByRole('button', { name: titlePattern }).first().click();
  }

  await main
    .getByRole('heading', {
      name: /O‘rganish rejangizni sozlang|Настройте свой план обучения|Boshlang‘ich darslar|Начальные уроки|Assalomu alaykum|Здравствуйте|Mening ta’lim yo‘lim|Мой путь обучения|Bilim xaritasi|Карта знаний/i,
    })
    .first()
    .waitFor({ state: 'visible' });
}

export async function setLocale(page, locale) {
  if (locale !== 'uz' && locale !== 'ru') {
    throw new Error(`Unsupported locale "${locale}". Expected "uz" or "ru".`);
  }
  const select = page.locator('#interface-language');
  await select.waitFor({ state: 'visible' });
  await select.selectOption(locale);
  await page.waitForFunction(
    (expectedLang) => document.documentElement.lang === expectedLang,
    locale,
  );
  assert.equal(await select.inputValue(), locale, `Locale selector did not update to "${locale}".`);
}

export async function setTheme(page, theme) {
  if (theme !== 'light' && theme !== 'dark') {
    throw new Error(`Unsupported theme "${theme}". Expected "light" or "dark".`);
  }

  const currentTheme = await page.evaluate(() => document.documentElement.dataset.theme ?? 'light');
  if (currentTheme !== theme) {
    const togglePattern =
      theme === 'dark'
        ? /Qorong‘i rejimni yoqish|Включить тёмную тему/i
        : /Yorug‘ rejimni yoqish|Включить светлую тему/i;
    await page.getByRole('button', { name: togglePattern }).first().click();
  }

  await page.waitForFunction(
    (expectedTheme) =>
      document.documentElement.dataset.theme === expectedTheme &&
      document.documentElement.classList.contains('dark') === (expectedTheme === 'dark'),
    theme,
  );
}

export async function assertNoHorizontalOverflow(page, label = 'viewport') {
  const sizes = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
  }));
  assert(
    sizes.scrollWidth <= sizes.clientWidth + 1,
    `Horizontal overflow detected at ${label}: scrollWidth=${sizes.scrollWidth} > clientWidth=${sizes.clientWidth}`,
  );
}

export async function setViewportPreset(page, preset) {
  const size = resolveViewport(preset);
  await page.setViewportSize(size);
  await assertNoHorizontalOverflow(page, `${preset} (${size.width}x${size.height})`);
  return size;
}

export async function throttleNetwork(page, options = {}) {
  const {
    pattern = '**/*',
    delayMs = 250,
    abort = false,
    abortErrorCode = 'failed',
  } = options;

  const handler = async (route) => {
    try {
      if (abort) {
        await route.abort(abortErrorCode);
        return;
      }
      if (delayMs > 0) {
        await new Promise((resolve) => setTimeout(resolve, delayMs));
      }
      await route.fallback();
    } catch {
      // Page/context may close while route is in flight.
    }
  };

  await page.route(pattern, handler);

  return async function unthrottle() {
    await page.unroute(pattern, handler);
  };
}

export async function openAndCloseYolchiAi(page, options = {}) {
  const {
    askText = null,
    closeWith = 'button',
    preserveStepIndicator = null,
    preserveText = null,
  } = options;

  const askBtn = page.getByRole('button', {
    name: /Yo‘lchidan so‘rash|Спросить Yo‘lchi/i,
  });
  await askBtn.first().waitFor({ state: 'visible' });

  let capturedStepText = null;
  const stepLocator = page.getByText(/^(Qadam|Шаг)\s+\d+\s*\/\s*\d+$/i);
  if (
    (await stepLocator.count().catch(() => 0)) > 0 &&
    (await stepLocator.first().isVisible().catch(() => false))
  ) {
    capturedStepText = (await stepLocator.first().textContent())?.trim() ?? null;
  }

  if (preserveStepIndicator) {
    await page.getByText(preserveStepIndicator).first().waitFor({ state: 'visible' });
  }
  if (preserveText) {
    await page.getByText(preserveText).first().waitFor({ state: 'visible' });
  }

  await askBtn.first().click();

  const dialog = page.getByRole('dialog', {
    name: /Yo‘lchi bilan shu dars haqida|Обсудить урок с Yo‘lchi/i,
  });
  await dialog.waitFor({ state: 'visible' });

  if (typeof askText === 'string' && askText.trim().length > 0) {
    const feedbackBtns = dialog.getByRole('button', {
      name: /Foydali javob|Полезный ответ/i,
    });
    const beforeCount = await feedbackBtns.count();
    const input = dialog.getByRole('textbox', {
      name: /Yo‘lchi AI ga savol yozing|Напишите вопрос Yo‘lchi AI/i,
    });
    await input.fill(askText);
    await dialog
      .getByRole('button', { name: /Savolni yuborish|Отправить вопрос/i })
      .click();
    await feedbackBtns.nth(beforeCount).waitFor({ state: 'visible' });
  }

  if (closeWith === 'escape') {
    await page.keyboard.press('Escape');
  } else {
    await dialog.getByRole('button', { name: /Yopish|Закрыть/i }).click();
  }

  await dialog.waitFor({ state: 'hidden' });
  await askBtn.first().waitFor({ state: 'visible' });

  if (capturedStepText) {
    await page.getByText(capturedStepText, { exact: true }).first().waitFor({ state: 'visible' });
  }
  if (preserveStepIndicator) {
    await page.getByText(preserveStepIndicator).first().waitFor({ state: 'visible' });
  }
  if (preserveText) {
    await page.getByText(preserveText).first().waitFor({ state: 'visible' });
  }
}

export async function readDemoProgressSnapshot(page) {
  return page.evaluate(() => {
    const progressRaw = sessionStorage.getItem('bilimyol_demo_progress');
    const sessionRaw = sessionStorage.getItem('bilimyol_demo_session');
    const activeCourseId = localStorage.getItem('bilimyol_active_course_id');
    let progress = null;
    if (progressRaw) {
      try {
        progress = JSON.parse(progressRaw);
      } catch {
        progress = null;
      }
    }
    return {
      progressRaw,
      progress,
      sessionRaw,
      activeCourseId,
    };
  });
}

export async function reloadAndVerifyPersistence(page, assertFn) {
  const before = await readDemoProgressSnapshot(page);
  await page.reload({ waitUntil: 'domcontentloaded' });
  const after = await readDemoProgressSnapshot(page);
  if (typeof assertFn === 'function') {
    await assertFn({ before, after, page });
  }
  return { before, after };
}

function sanitizeFilenameSegment(name) {
  return String(name || 'screenshot')
    .toLowerCase()
    .replace(/[^a-z0-9_-]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 80) || 'screenshot';
}

export async function captureFailureScreenshot(
  page,
  testName,
  dir = 'artifacts/e2e-english-screenshots',
) {
  await mkdir(dir, { recursive: true });
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const filePath = join(dir, `fail-${sanitizeFilenameSegment(testName)}-${stamp}.png`);
  await page.screenshot({
    path: filePath,
    animations: 'disabled',
    fullPage: true,
  });
  return filePath;
}

export async function captureViewPairScreenshots(
  page,
  namePrefix,
  dir = 'artifacts/e2e-english-screenshots',
) {
  await mkdir(dir, { recursive: true });
  const originalViewport = page.viewportSize();
  const originalScroll = await page.evaluate(() => ({ x: window.scrollX, y: window.scrollY }));
  const safePrefix = sanitizeFilenameSegment(namePrefix);
  const mobilePath = join(dir, `${safePrefix}-390.png`);
  const desktopPath = join(dir, `${safePrefix}-1440.png`);
  const overflowErrors = [];

  try {
    await page.setViewportSize(BASE_VIEWPORTS.mobile390);
    await page.evaluate(() => window.scrollTo(0, 0));
    await page.screenshot({
      path: mobilePath,
      animations: 'disabled',
      fullPage: true,
    });
    try {
      await assertNoHorizontalOverflow(
        page,
        `mobile390 (${BASE_VIEWPORTS.mobile390.width}x${BASE_VIEWPORTS.mobile390.height})`,
      );
    } catch (err) {
      overflowErrors.push(err?.message ?? String(err));
    }

    await page.setViewportSize(BASE_VIEWPORTS.desktop1440);
    await page.evaluate(() => window.scrollTo(0, 0));
    await page.screenshot({
      path: desktopPath,
      animations: 'disabled',
      fullPage: true,
    });
    try {
      await assertNoHorizontalOverflow(
        page,
        `desktop1440 (${BASE_VIEWPORTS.desktop1440.width}x${BASE_VIEWPORTS.desktop1440.height})`,
      );
    } catch (err) {
      overflowErrors.push(err?.message ?? String(err));
    }
  } finally {
    if (originalViewport) {
      await page.setViewportSize(originalViewport);
    }
    await page.evaluate(({ x, y }) => window.scrollTo(x, y), originalScroll).catch(() => {});
  }

  if (overflowErrors.length > 0) {
    throw new Error(overflowErrors.join(' | '));
  }

  return { mobilePath, desktopPath };
}

export function assertNoSupabaseCallsInDemo(remoteRequests, label = 'demo session') {
  assert.deepEqual(
    remoteRequests,
    [],
    `Expected zero remote/Supabase calls in ${label}, got: ${JSON.stringify(remoteRequests)}`,
  );
}

export function assertNoPageErrors(errors, label = 'page') {
  assert.deepEqual(
    errors,
    [],
    `Expected zero uncaught pageerror exceptions in ${label}, got: ${JSON.stringify(errors)}`,
  );
}

export async function expectVisibleFast(locator, diagnosticMessage, timeoutMs = 2500) {
  try {
    await locator.first().waitFor({ state: 'visible', timeout: timeoutMs });
  } catch (err) {
    const detail = err?.message ? ` (${err.message.split('\n')[0]})` : '';
    assert.fail(`${diagnosticMessage}${detail}`);
  }
}

export async function runWithContext(browser, options, fn, failureMeta = null) {
  const sub = await createEnglishE2EContext(browser, options);
  try {
    return await fn(sub);
  } catch (err) {
    if (failureMeta?.id) {
      try {
        await captureFailureScreenshot(sub.page, failureMeta.id, failureMeta.screenshotsDir);
      } catch {
        // Ignore screenshot failure if page crashed/closed.
      }
    }
    throw err;
  } finally {
    await sub.dispose();
  }
}

export async function readReadingCheckpoints(page) {
  return page.evaluate(() => {
    const checkpoints = {};
    for (let i = 0; i < sessionStorage.length; i++) {
      const storageKey = sessionStorage.key(i);
      if (storageKey && storageKey.startsWith('bilimyol-reading:')) {
        checkpoints[storageKey] = sessionStorage.getItem(storageKey);
      }
    }
    return checkpoints;
  });
}

export async function writeReadingCheckpoint(page, lessonId, stepIndex, courseId = 'course_eng_01') {
  return page.evaluate(
    ({ targetLessonId, targetStepIndex, targetCourseId }) => {
      let existingKey = null;
      for (let i = 0; i < sessionStorage.length; i++) {
        const storageKey = sessionStorage.key(i);
        if (!storageKey || !storageKey.startsWith('bilimyol-reading:')) continue;
        try {
          const parsed = JSON.parse(storageKey.slice('bilimyol-reading:'.length));
          if (
            Array.isArray(parsed) &&
            parsed[1] === targetCourseId &&
            parsed[2] === targetLessonId
          ) {
            existingKey = storageKey;
            break;
          }
        } catch {
          // Ignore malformed legacy checkpoint keys
        }
      }
      const key =
        existingKey ??
        `bilimyol-reading:${JSON.stringify(['guest_user_01', targetCourseId, targetLessonId])}`;
      sessionStorage.setItem(key, String(targetStepIndex));
      return key;
    },
    { targetLessonId: lessonId, targetStepIndex: stepIndex, targetCourseId: courseId },
  );
}

export async function pressTabUntilFocused(page, targetLocator, label = 'target element', maxTabs = 90) {
  const target = targetLocator.first();
  await target.waitFor({ state: 'visible', timeout: 5000 });
  for (let i = 0; i < maxTabs; i++) {
    const isFocused = await target.evaluate((el) => el === document.activeElement);
    if (isFocused) return;
    await page.keyboard.press('Tab');
  }
  assert.fail(`Keyboard Tab navigation could not focus "${label}" within ${maxTabs} Tab presses.`);
}
