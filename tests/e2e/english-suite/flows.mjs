import assert from 'node:assert/strict';

export const FAST_TIMEOUT = 2800;
export const STD_TIMEOUT = 4500;
export const PLACEMENT_MIN_INTERVAL_MS = 900;

export async function clickFirstVisibleButton(page, namePattern) {
  const buttons = page.getByRole('button', { name: namePattern });
  const count = await buttons.count().catch(() => 0);
  for (let i = 0; i < count; i++) {
    const candidate = buttons.nth(i);
    if (await candidate.isVisible().catch(() => false)) {
      await candidate.click();
      return true;
    }
  }
  await buttons.first().click();
  return true;
}

export async function openEnglishOnboarding(page, baseUrl, helpers) {
  await helpers.launchDemoSession(page, baseUrl);
  await helpers.selectCourse(page, 'course_eng_01');
}

export async function openStarterLesson(page, baseUrl, helpers) {
  await openEnglishOnboarding(page, baseUrl, helpers);
  const main = page.getByRole('main');
  const beginnerRadio = main.getByRole('radio', {
    name: /Noldan boşlayman|Начинаю с нуля/i,
  });
  await beginnerRadio.check();
  await main
    .getByRole('button', {
      name: /Birinçi darsni boşlaş|Boşlanğiç darsni davom ettiriş|Начать первый урок|Продолжить вводный урок/i,
    })
    .click();
  await main
    .getByRole('heading', {
      name: /Birinçi inglizça sözlar|Первые английские слова/i,
    })
    .first()
    .waitFor({ state: 'visible' });
}

export async function openEnglishRoadmap(page, baseUrl, helpers) {
  await openEnglishOnboarding(page, baseUrl, helpers);
  const main = page.getByRole('main');
  await main
    .getByRole('radio', { name: /Asoslarini bilaman|Знаю основы/i })
    .check();
  await main
    .getByRole('button', {
      name: /Ta’lim yölini oçiş|Открыть путь обучения/i,
    })
    .click();
  await main
    .getByRole('heading', { name: /Mening ta’lim yölim|Мой путь обучения/i })
    .first()
    .waitFor({ state: 'visible' });
}

export async function startEnglishPlacement(page, baseUrl, helpers) {
  await openEnglishOnboarding(page, baseUrl, helpers);
  const main = page.getByRole('main');
  await main
    .getByRole('radio', { name: /Asoslarini bilaman|Знаю основы/i })
    .check();
  await main
    .getByRole('button', {
      name: /Ixtiyoriy diagnostika|Необязательная диагностика/i,
    })
    .click();
  await main
    .getByRole('heading', {
      name: /Boşlanğiç diagnostika|Входная диагностика/i,
    })
    .first()
    .waitFor({ state: 'visible' });
}

export async function navigateToRoadmapFromWorkspace(page) {
  const main = page.getByRole('main');
  const roadmapHeading = main.getByRole('heading', {
    name: /Mening ta’lim yölim|Мой путь обучения/i,
  });
  if (await roadmapHeading.first().isVisible().catch(() => false)) {
    return;
  }
  const backBtn = main.getByRole('button', {
    name: /Ta’lim yöliga qaytiş|Вернуться к пути обучения/i,
  });
  if (await backBtn.first().isVisible().catch(() => false)) {
    await backBtn.first().click();
  } else {
    await clickFirstVisibleButton(page, /^Ta’lim yöli$|^Путь обучения$/i);
  }
  await main
    .getByRole('heading', {
      name: /Mening ta’lim yölim|Мой путь обучения|Boşlanğiç darslar|Начальные уроки/i,
    })
    .first()
    .waitFor({ state: 'visible' });
}

export async function advanceLessonStep(page, expectedTitlePattern = null) {
  const main = page.getByRole('main');
  const stepBadge = main.getByText(/^(Qadam|Шаг)\s+\d+\s*\/\s*\d+$/i).first();
  const prevText = (await stepBadge.textContent())?.trim() ?? '';
  const match = prevText.match(/^(Qadam|Шаг)\s+(\d+)\s*\/\s*(\d+)$/i);
  const nextStepNum = match ? Number(match[2]) + 1 : null;

  await main
    .getByRole('button', { name: /Keyingi qadam|Следующий шаг/i })
    .click();

  await page.waitForFunction(
    ({ previous, expectedStep }) => {
      const spans = [...document.querySelectorAll('main span')];
      const badgeChanged = spans.some((el) => {
        const text = el.textContent?.trim() ?? '';
        return /^(Qadam|Шаг)\s+\d+\s*\/\s*\d+$/i.test(text) && text !== previous;
      });
      if (!badgeChanged) return false;
      if (expectedStep == null) return true;
      return spans.some((el) => {
        const text = el.textContent?.trim() ?? '';
        return new RegExp(`^(Qadam|Шаг)\\s+${expectedStep}$`, 'i').test(text);
      });
    },
    { previous: prevText, expectedStep: nextStepNum },
  );

  if (expectedTitlePattern) {
    await main
      .getByRole('heading', { name: expectedTitlePattern })
      .first()
      .waitFor({ state: 'visible' });
  }
}

export async function advanceToExerciseStep(page, maxSteps = 8) {
  const main = page.getByRole('main');
  for (let i = 0; i < maxSteps; i++) {
    const checkBtn = main.getByRole('button', {
      name: /^TEKŞIRIŞ$|^ПРОВЕРИТЬ$/i,
    });
    if ((await checkBtn.count()) > 0 && (await checkBtn.first().isVisible().catch(() => false))) {
      return;
    }
    const revealBtn = main.getByRole('button', {
      name: /Javobni köriş|Показать ответ/i,
    });
    if ((await revealBtn.count()) > 0 && (await revealBtn.first().isVisible().catch(() => false))) {
      await completeVisibleFlashcardDeck(page);
    }
    await advanceLessonStep(page);
  }
  assert.fail(`Could not reach interactive exercise step within ${maxSteps} steps.`);
}

export async function completeVisibleFlashcardDeck(page, maxCards = 12) {
  const main = page.getByRole('main');
  for (let i = 0; i < maxCards; i++) {
    const doneHeading = main.getByRole('heading', {
      name: /Barça kartoçkalar körib çiqildi|Все карточки просмотрены/i,
    });
    if (await doneHeading.isVisible().catch(() => false)) {
      return;
    }
    const revealBtn = main.getByRole('button', {
      name: /Javobni köriş|Показать ответ/i,
    });
    if (!(await revealBtn.isVisible().catch(() => false))) {
      return;
    }
    await revealBtn.click();
    await main
      .getByRole('button', { name: /Eslab qoldim|Запомнил\(а\)/i })
      .click();
  }
  assert.fail(`Flashcard deck did not finish within ${maxCards} cards.`);
}

export async function submitFreeTextAnswer(page, text, { viaEnter = false } = {}) {
  const main = page.getByRole('main');
  const input = main.getByRole('textbox', {
    name: /Javobingizni ingliz tilida yozing|Напишите ответ на английском/i,
  });
  await input.waitFor({ state: 'visible' });
  await input.fill(text);
  if (viaEnter) {
    await input.press('Enter');
  } else {
    await main
      .getByRole('button', { name: /^TEKŞIRIŞ$|^ПРОВЕРИТЬ$/i })
      .click();
  }
}

export async function finishCompletionDialog(page) {
  const dialog = page.getByRole('dialog', {
    name: /Dars yakunlandi|Урок завершён/i,
  });
  await dialog.waitFor({ state: 'visible' });
  await dialog
    .getByRole('button', {
      name: /Ta’lim yöliga ötiş|Перейти к пути обучения/i,
    })
    .click();
  await dialog.waitFor({ state: 'hidden' });
}

export async function completeStarterLesson(
  page,
  baseUrl,
  helpers,
  answerText = "I'm Sam",
) {
  await openStarterLesson(page, baseUrl, helpers);
  await advanceLessonStep(page, /Birga misol köramiz/i);
  await advanceLessonStep(page, /Iboralarni eslab qolamiz/i);
  await completeVisibleFlashcardDeck(page);
  await advanceLessonStep(page, /Örganganingizni sinab köring/i);
  await submitFreeTextAnswer(page, answerText);
  await page
    .getByRole('main')
    .getByText(/Töğri javob!|Верно!/i)
    .first()
    .waitFor({ state: 'visible' });
  await finishCompletionDialog(page);
  await page
    .getByRole('main')
    .getByRole('heading', { name: /Boşlanğiç darslar|Начальные уроки/i })
    .first()
    .waitFor({ state: 'visible' });
}

export async function completeMcqLesson(page, optionPattern) {
  const main = page.getByRole('main');
  await advanceToExerciseStep(page);
  await main.getByRole('button', { name: optionPattern }).first().click();
  await main
    .getByRole('button', { name: /^TEKŞIRIŞ$|^ПРОВЕРИТЬ$/i })
    .click();
  await main
    .getByText(/Töğri javob!|Верно!/i)
    .first()
    .waitFor({ state: 'visible' });
  await finishCompletionDialog(page);
}

export async function openRoadmapNodeLesson(page, nodeTitlePattern) {
  const main = page.getByRole('main');
  const nodeCard = main.locator('li').filter({
    has: page.getByRole('heading', { name: nodeTitlePattern }),
  });
  await nodeCard.first().waitFor({ state: 'visible' });
  await nodeCard
    .first()
    .getByRole('button', {
      name: /Darsni boşlaş|Qayta köriş|Начать урок|Повторить/i,
    })
    .click();
}

export async function unlockEnglishRoadmapUpTo(page, targetNodeKey) {
  const main = page.getByRole('main');
  const roadmapHeading = main.getByRole('heading', {
    name: /Mening ta’lim yölim|Мой путь обучения/i,
  });

  const sequence = [
    { key: 'vocab', heading: /^Vocabulary$/i, answer: 'between the chair and the shelf' },
    { key: 'gram', heading: /^Grammar$/i, answer: 'does' },
    { key: 'list', heading: /^Listening$/i, answer: '15:15 (quarter past three)' },
  ];

  for (const item of sequence) {
    if (item.key === targetNodeKey) break;
    await roadmapHeading.first().waitFor({ state: 'visible' });
    await openRoadmapNodeLesson(page, item.heading);
    await completeMcqLesson(page, item.answer);
  }
  await roadmapHeading.first().waitFor({ state: 'visible' });
}

export async function openDirectEnglishLesson(page, baseUrl, lessonId) {
  await page.goto(`${baseUrl}/?view=lesson&lessonId=${encodeURIComponent(lessonId)}`, {
    waitUntil: 'domcontentloaded',
    timeout: 15000,
  });
  await page
    .getByRole('main')
    .getByText(/^(Qadam|Шаг)\s+\d+\s*\/\s*\d+$/i)
    .first()
    .waitFor({ state: 'visible' });
}

export async function assertCourseIdentity(page, helpers, expectedCourseId, label) {
  const snapshot = await helpers.readDemoProgressSnapshot(page);
  assert.equal(
    snapshot.activeCourseId,
    expectedCourseId,
    `${label}: expected localStorage activeCourseId="${expectedCourseId}", got "${snapshot.activeCourseId}".`,
  );
  if (expectedCourseId === 'course_eng_01') {
    const visibleText = await page.getByRole('main').innerText();
    assert.match(
      visibleText,
      /Ingliz tili|Английский/i,
      `${label}: expected English course label visible in main workspace.`,
    );
  }
  return snapshot;
}

const PLACEMENT_SEMANTIC_RULES = [
  {
    stem: /It is raining outside.*take your ____/i,
    answer: /^umbrella$/i,
  },
  {
    stem: /forgot his wallet.*____ him some money/i,
    answer: /^lend$/i,
  },
  {
    stem: /To ____ traffic jams during the morning rush/i,
    answer: /^avoid$/i,
  },
  {
    stem: /There ____ three books on the teacher/i,
    answer: /^are$/i,
  },
  {
    stem: /Yesterday evening, Madina ____ fresh fruit/i,
    answer: /^bought$/i,
  },
  {
    stem: /Dilşod has lived in Samarkand ____ 2019/i,
    answer: /^since$/i,
  },
  {
    stem: /What time does the music club start|Во сколько начинается музыкальный кружок/i,
    answer: /^09:00 in the morning$/i,
  },
  {
    stem: /When is the beginner swimming class this week|Когда пройдёт занятие по плаванию/i,
    answer: /^Thursday at 16:00$/i,
  },
  {
    stem: /What will the speakers do for the morning session|Что собеседники сделают для утренней сессии/i,
    answer: /^Send the PDF link in the group chat first and give out booklets after lunch$/i,
  },
  {
    stem: /Green Park Bookshop.*(?:When can a customer visit|Когда покупатель может посетить)/i,
    answer: /^On Wednesday at 11:00 AM$/i,
  },
  {
    stem: /heavy rain tomorrow.*(?:Why did Anvar change the plan|Почему Анвар изменил план)/i,
    answer: /^Bad weather is expected tomorrow$/i,
  },
  {
    stem: /City Bike Pass members.*(?:avoid paying the extra fee|избежать дополнительной платы)/i,
    answer: /^Return the bike within 45 minutes$/i,
  },
];

export async function solveEnglishPlacement(page, { accuracy = 'high', maxSteps = 12 } = {}) {
  const main = page.getByRole('main');
  let sawAudioPlayer = false;
  let matchedRuleCount = 0;
  let totalSteps = 0;
  const stems = [];

  for (let step = 1; step <= maxSteps; step++) {
    const resultVisible = await main
      .getByRole('heading', { name: /Diagnostika yakunlandi|Диагностика завершена/i })
      .isVisible()
      .catch(() => false);
    if (resultVisible) break;

    totalSteps++;
    if ((await main.locator('audio').count()) > 0) {
      sawAudioPlayer = true;
    }

    const stemText = (await main.locator('h2').first().textContent().catch(() => '')) ?? '';
    stems.push(stemText);
    const optionLabels = main.locator('fieldset label');
    const optionCount = await optionLabels.count();
    assert.ok(optionCount >= 2, `Expected >= 2 placement options on step ${step}, got ${optionCount}.`);

    const texts = [];
    for (let i = 0; i < optionCount; i++) {
      texts.push(((await optionLabels.nth(i).innerText().catch(() => '')) ?? '').trim());
    }

    const matchingRule = PLACEMENT_SEMANTIC_RULES.find(
      (rule) => rule.stem.test(stemText) || texts.some((txt) => rule.answer.test(txt)),
    );
    let targetIndex = -1;
    if (matchingRule) {
      matchedRuleCount++;
      const rightIdx = texts.findIndex((txt) => matchingRule.answer.test(txt));
      if (accuracy === 'high') {
        targetIndex = rightIdx;
      } else {
        targetIndex = texts.findIndex((_, idx) => idx !== rightIdx);
      }
    }

    if (targetIndex < 0) {
      assert.fail(
        `solveEnglishPlacement(${accuracy}): Unmatched placement item at step ${step}: stem="${stemText}" options=${JSON.stringify(texts)}`,
      );
    }

    await main.getByRole('radio').nth(targetIndex).check();
    await page.waitForTimeout(PLACEMENT_MIN_INTERVAL_MS);

    const finishBtn = main.getByRole('button', { name: /Natijani köriş|Посмотреть результат/i });
    if (await finishBtn.isVisible().catch(() => false)) {
      await finishBtn.click();
      const modal = page.getByRole('dialog', { name: /Javoblarni topşirasizmi\?|Отправить ответы\?/i });
      await modal.waitFor({ state: 'visible' });
      await modal.getByRole('button', { name: /^Topşiriş$|^Отправить$/i }).click();
      break;
    }
    await main.getByRole('button', { name: /Keyingi savol|Следующий вопрос/i }).click();
  }

  await main
    .getByRole('heading', { name: /Diagnostika yakunlandi|Диагностика завершена/i })
    .first()
    .waitFor({ state: 'visible' });

  const summaryText = await main.innerText();
  const scoreMatch = summaryText.match(/(\d+)\s*\/\s*(\d+)/);
  const correct = scoreMatch ? Number(scoreMatch[1]) : 0;
  const total = scoreMatch ? Number(scoreMatch[2]) : totalSteps;
  return { correct, total, sawAudioPlayer, matchedRuleCount, summaryText, stems };
}

export function getCefrLevelSection(main, level) {
  const explicit = main.locator(`[data-cefr-level="${level}"]`);
  const heading = main.getByRole('heading', {
    name: new RegExp(`^${level}\\b|\\b${level}\\s*[—–:-]`, 'i'),
  });
  return explicit
    .or(
      heading.locator(
        'xpath=ancestor::*[self::section or self::article][1][not(.//*[@data-cefr-level])]',
      ),
    )
    .first();
}

export async function assertSingleCefrLevelScope(section, level, contextLabel) {
  const isPageWrapper = await section.evaluate((el) => el.classList.contains('learning-page'));
  assert.equal(
    isPageWrapper,
    false,
    `${contextLabel}: CEFR ${level} section must not resolve to outer .learning-page wrapper.`,
  );
  const otherLevels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'].filter((l) => l !== level);
  const otherHeadings = section.getByRole('heading', {
    name: new RegExp(
      `^(?:${otherLevels.join('|')})\\b|\\b(?:${otherLevels.join('|')})\\s*[—–:-]`,
      'i',
    ),
  });
  const otherCount = await otherHeadings.count();
  assert.equal(
    otherCount,
    0,
    `${contextLabel}: CEFR ${level} section must scope exclusively to ${level} (found ${otherCount} other CEFR level headings inside it).`,
  );
}

async function resolveMatchColumnItems(column) {
  const pairItems = column.locator('[data-pair-id]');
  const pairCount = await pairItems.count();
  if (pairCount > 0) {
    const items = [];
    for (let i = 0; i < pairCount; i++) {
      const item = pairItems.nth(i);
      const innerBtn = item.locator('button').first();
      const target = (await innerBtn.count()) > 0 ? innerBtn : item;
      const pairId = await item.getAttribute('data-pair-id');
      items.push({ index: i, target, pairId });
    }
    return items;
  }

  const btns = column.locator('button');
  const btnCount = await btns.count();
  const items = [];
  for (let i = 0; i < btnCount; i++) {
    const btn = btns.nth(i);
    const pairId = await btn.evaluate(
      (el) => el.getAttribute('data-pair-id') ?? el.closest('[data-pair-id]')?.getAttribute('data-pair-id') ?? null,
    );
    items.push({ index: i, target: btn, pairId });
  }
  return items;
}

function computeMismatchedRightIndices(leftItems, rightItems) {
  const n = leftItems.length;
  const m = rightItems.length;
  const allHavePairIds = leftItems.every((x) => Boolean(x.pairId)) && rightItems.every((x) => Boolean(x.pairId));
  if (!allHavePairIds) {
    return leftItems.map((_, i) => (i + 1) % m);
  }

  const chosen = new Array(n).fill(-1);
  const used = new Set();
  function backtrack(idx) {
    if (idx === n) return true;
    const leftId = leftItems[idx].pairId;
    for (let offset = 1; offset <= m; offset++) {
      const r = (idx + offset) % m;
      if (used.has(r)) continue;
      if (rightItems[r].pairId === leftId) continue;
      used.add(r);
      chosen[idx] = r;
      if (backtrack(idx + 1)) return true;
      used.delete(r);
    }
    return false;
  }

  if (backtrack(0)) {
    return chosen;
  }
  return leftItems.map((leftItem, i) => {
    const diffIdx = rightItems.findIndex((rItem, rIdx) => rItem.pairId !== leftItem.pairId && rIdx !== i);
    return diffIdx >= 0 ? diffIdx : (i + 1) % m;
  });
}

export async function completeRichExerciseStep(page) {
  const main = page.getByRole('main');
  const richRegion = main.locator(
    '[data-question-mode="fill_blank"], [data-question-mode="word_match"], [data-question-mode="sentence_order"], [data-exercise-type="fill_blank"], [data-exercise-type="word_match"], [data-exercise-type="sentence_order"]',
  );
  const checkBtn = main.getByRole('button', { name: /^TEKŞIRIŞ$|^ПРОВЕРИТЬ$/i });

  const fillInput = main.getByRole('textbox', {
    name: /Böş joyni töldiring|Fill in the blank|Javobingizni/i,
  });
  const wordMatchGroup = main.getByRole('group', { name: /Sözlarni moslang|Word match/i });
  const sentenceOrderGroup = main.getByRole('group', { name: /Gap tuzing|Sentence order/i });

  const hasRichRegion = (await richRegion.count()) > 0;
  const hasFill = await fillInput.first().isVisible().catch(() => false);
  const hasMatch = await wordMatchGroup.first().isVisible().catch(() => false);
  const hasOrder = await sentenceOrderGroup.first().isVisible().catch(() => false);

  assert.ok(
    hasRichRegion || hasFill || hasMatch || hasOrder,
    'T1-F5-02: Expected active rich exercise UI (fill_blank, word_match, or sentence_order), not plain MCQ.',
  );

  // 1) Deterministic wrong-attempt verification + explanatory feedback
  if (hasFill) {
    await fillInput.first().fill('wrong_blank_probe');
    await checkBtn.click();
  } else if (hasOrder) {
    const tokens = sentenceOrderGroup.first().getByRole('button');
    const count = await tokens.count();
    assert.ok(count >= 2, 'Expected >= 2 word tokens in sentence_order exercise.');
    for (let i = count - 1; i >= 0; i--) {
      await tokens.nth(i).click();
    }
    await checkBtn.click();
  } else if (hasMatch) {
    const group = wordMatchGroup.first();
    const leftSide = group.locator('[data-match-side="left"]');
    const rightSide = group.locator('[data-match-side="right"]');
    if ((await leftSide.count()) > 0 && (await rightSide.count()) > 0) {
      const leftItems = await resolveMatchColumnItems(leftSide);
      const rightItems = await resolveMatchColumnItems(rightSide);
      assert.ok(
        leftItems.length >= 2 && rightItems.length >= 2,
        `Expected >= 2 left/right items in word_match (got ${leftItems.length}/${rightItems.length}).`,
      );
      const mismatchIndices = computeMismatchedRightIndices(leftItems, rightItems);
      for (let i = 0; i < leftItems.length; i++) {
        await leftItems[i].target.click();
        await rightItems[mismatchIndices[i]].target.click();
      }
    } else {
      const items = await resolveMatchColumnItems(group);
      assert.ok(items.length >= 2, `Expected >= 2 items in word_match (got ${items.length}).`);
      const itemsWithPairs = items.filter((item) => Boolean(item.pairId));
      if (itemsWithPairs.length >= 4 && itemsWithPairs.length % 2 === 0) {
        const half = itemsWithPairs.length / 2;
        const firstHalf = itemsWithPairs.slice(0, half);
        const secondHalf = itemsWithPairs.slice(half);
        const mismatchIndices = computeMismatchedRightIndices(firstHalf, secondHalf);
        for (let i = 0; i < firstHalf.length; i++) {
          await firstHalf[i].target.click();
          await secondHalf[mismatchIndices[i]].target.click();
        }
      } else {
        const first = items[0];
        const mismatched = items.find((item, idx) => idx > 0 && item.pairId !== first.pairId) ?? items[items.length - 1];
        await first.target.click();
        await mismatched.target.click();
      }
    }
    await checkBtn.click();
  }

  await main.getByText(/Javobni körib çiqamiz|Qayta tekşiramiz|Notöğri/i).first().waitFor({ state: 'visible' });
  const feedbackText = await main.locator('[role="status"]').first().innerText().catch(() => '');
  assert.ok(feedbackText.trim().length >= 12, `Expected non-empty explanatory feedback, got "${feedbackText}".`);

  await main.getByRole('button', { name: /Qayta uriniş|Попробовать снова/i }).click();

  // 2) Submit valid answer guided by prompt/options
  if (hasFill) {
    const promptText = await main.locator('h3').first().innerText().catch(() => '');
    const candidate = /\bI\s+___/i.test(promptText)
      ? 'am'
      : /\b(She|He|It)\s+___/i.test(promptText)
        ? 'is'
        : /\b(You|We|They)\s+___/i.test(promptText)
          ? 'are'
          : 'hello';
    await fillInput.first().fill(candidate);
    await checkBtn.click();
  } else if (hasOrder) {
    const tokens = sentenceOrderGroup.first().getByRole('button');
    const count = await tokens.count();
    const labels = [];
    for (let i = 0; i < count; i++) {
      labels.push({ idx: i, text: ((await tokens.nth(i).innerText()) ?? '').trim() });
    }
    const ordered = [...labels].sort((a, b) => {
      const aCap = /^[A-Z]/.test(a.text) ? -1 : 0;
      const bCap = /^[A-Z]/.test(b.text) ? -1 : 0;
      if (aCap !== bCap) return aCap - bCap;
      const aEnd = /[.!?]$/.test(a.text) ? 1 : 0;
      const bEnd = /[.!?]$/.test(b.text) ? 1 : 0;
      return aEnd - bEnd;
    });
    for (const item of ordered) {
      await tokens.nth(item.idx).click();
    }
    await checkBtn.click();
  } else if (hasMatch) {
    const group = wordMatchGroup.first();
    const leftSide = group.locator('[data-match-side="left"]');
    const rightSide = group.locator('[data-match-side="right"]');

    if ((await leftSide.count()) > 0 && (await rightSide.count()) > 0) {
      const leftItems = await resolveMatchColumnItems(leftSide);
      const rightItems = await resolveMatchColumnItems(rightSide);
      assert.ok(
        leftItems.length >= 2 && rightItems.length >= 2,
        `Expected >= 2 left/right items in word_match exercise (got ${leftItems.length}/${rightItems.length}).`,
      );
      const usedRight = new Set();
      for (let i = 0; i < leftItems.length; i++) {
        const leftItem = leftItems[i];
        await leftItem.target.click();
        let rightIdx = -1;
        if (leftItem.pairId) {
          rightIdx = rightItems.findIndex((r, idx) => !usedRight.has(idx) && r.pairId === leftItem.pairId);
        }
        if (rightIdx < 0) {
          rightIdx = !usedRight.has(i) && i < rightItems.length
            ? i
            : rightItems.findIndex((_, idx) => !usedRight.has(idx));
        }
        assert.ok(rightIdx >= 0, 'Expected matching right item in word_match exercise.');
        usedRight.add(rightIdx);
        await rightItems[rightIdx].target.click();
      }
    } else {
      const items = await resolveMatchColumnItems(group);
      assert.ok(items.length >= 2, 'Expected matchable pair items in word_match exercise.');
      const groupedByPairId = new Map();
      const ungrouped = [];
      for (const item of items) {
        if (item.pairId) {
          if (!groupedByPairId.has(item.pairId)) {
            groupedByPairId.set(item.pairId, []);
          }
          groupedByPairId.get(item.pairId).push(item);
        } else {
          ungrouped.push(item);
        }
      }
      if (groupedByPairId.size > 0) {
        for (const pairGroup of groupedByPairId.values()) {
          for (const item of pairGroup) {
            await item.target.click();
          }
        }
      } else {
        for (const item of ungrouped) {
          await item.target.click();
        }
      }
    }
    await checkBtn.click();
  }

  await main.getByText(/Töğri javob!|Верно!/i).first().waitFor({ state: 'visible' });
}

export async function completeInteractiveStepAndFinishLesson(
  page,
  maxSteps = 10,
  { skipCloseDialog = false } = {},
) {
  const main = page.getByRole('main');
  const completionDialog = page.getByRole('dialog', { name: /Dars yakunlandi|Урок завершён/i });

  for (let step = 0; step < maxSteps; step++) {
    if (await completionDialog.isVisible().catch(() => false)) {
      break;
    }

    const revealBtn = main.getByRole('button', { name: /Javobni köriş|Показать ответ/i });
    if ((await revealBtn.count()) > 0 && (await revealBtn.first().isVisible().catch(() => false))) {
      await completeVisibleFlashcardDeck(page);
    }

    const submitBtn = main.getByRole('button', {
      name: /^TEKŞIRIŞ$|^ПРОВЕРИТЬ$|Namunani köriş|Saqlaş|Baholaş/i,
    });
    if ((await submitBtn.count()) > 0 && (await submitBtn.first().isVisible().catch(() => false))) {
      const richFill = main.getByRole('textbox', {
        name: /Böş joyni töldiring|Fill in the blank/i,
      });
      const wordMatchGroup = main.getByRole('group', { name: /Sözlarni moslang|Word match/i });
      const sentenceOrderGroup = main.getByRole('group', { name: /Gap tuzing|Sentence order/i });

      if (
        (await richFill.first().isVisible().catch(() => false)) ||
        (await wordMatchGroup.first().isVisible().catch(() => false)) ||
        (await sentenceOrderGroup.first().isVisible().catch(() => false))
      ) {
        await completeRichExerciseStep(page);
      } else {
        const textbox = main.getByRole('textbox');
        if ((await textbox.count()) > 0 && (await textbox.first().isVisible().catch(() => false))) {
          const promptText = await main.locator('h3').first().innerText().catch(() => '');
          const isSelfAssessed = await main
            .getByText(/Özini baholaş|Mustaqil maşq|Self-assess/i)
            .first()
            .isVisible()
            .catch(() => false);
          const candidate = isSelfAssessed
            ? 'In my view, regular practice with structured feedback strengthens English fluency.'
            : /What's your name/i.test(promptText)
              ? "I'm Sam"
              : /\bI\s+___/i.test(promptText)
                ? 'am'
                : /\b(She|He|It)\s+___/i.test(promptText)
                  ? 'is'
                  : 'hello';
          await textbox.first().fill(candidate);
          await submitBtn.first().click();
        } else {
          const optionBtns = main.locator('button[aria-pressed], [data-option-index]');
          const fallbackBtns = main.locator('button').filter({ hasText: /^[A-D]\s+/ });
          const candidates = (await optionBtns.count()) > 0 ? optionBtns : fallbackBtns;
          const optCount = await candidates.count();
          assert.ok(optCount >= 2, `Expected >= 2 option buttons on interactive exercise step, got ${optCount}.`);

          for (let idx = 0; idx < optCount; idx++) {
            await candidates.nth(idx).click();
            await submitBtn.first().click();
            if (await completionDialog.isVisible().catch(() => false)) break;
            if (await main.getByText(/Töğri javob!|Верно!/i).first().isVisible().catch(() => false)) break;
            const retryBtn = main.getByRole('button', { name: /Qayta uriniş|Попробовать снова/i });
            if (await retryBtn.first().isVisible().catch(() => false)) {
              await retryBtn.first().click();
            }
          }
        }
      }
    }

    if (await completionDialog.isVisible().catch(() => false)) {
      break;
    }

    const nextStepBtn = main.getByRole('button', { name: /Keyingi qadam|Следующий шаг/i });
    if (await nextStepBtn.first().isVisible().catch(() => false)) {
      await advanceLessonStep(page);
      continue;
    }

    const finishBtn = main.getByRole('button', { name: /Darsni yakunlaş|Sinovni yakunlaş|Завершить урок/i });
    if (await finishBtn.first().isVisible().catch(() => false)) {
      await finishBtn.first().click();
      break;
    }
    break;
  }

  if (!skipCloseDialog) {
    await finishCompletionDialog(page);
  }
}

export function assertCleanSession(session, testId) {
  helpersSafeAssertClean(session, testId);
}

function helpersSafeAssertClean(session, testId) {
  assert.deepEqual(
    session.remoteRequests,
    [],
    `Expected zero remote/Supabase calls in ${testId}, got: ${JSON.stringify(session.remoteRequests)}`,
  );
  assert.deepEqual(
    session.errors,
    [],
    `Expected zero uncaught pageerror exceptions in ${testId}, got: ${JSON.stringify(session.errors)}`,
  );
}
