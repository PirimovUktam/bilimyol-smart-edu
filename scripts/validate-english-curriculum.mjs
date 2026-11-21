import fs from 'node:fs';
import path from 'node:path';

const rootDir = process.cwd();
const contentDir = path.join(rootDir, 'content', 'english');

const LEVEL_ORDER = ['a1', 'a2', 'b1', 'b2', 'c1', 'c2'];
const REQUIRED_LEVELS = new Set(['a1', 'a2', 'b1']);

const schema = JSON.parse(fs.readFileSync(path.join(contentDir, 'curriculum-schema.json'), 'utf8'));
const skeleton = JSON.parse(fs.readFileSync(path.join(contentDir, 'cefr-skeleton.json'), 'utf8'));

const errors = [];

function assert(cond, msg) {
  if (!cond) errors.push(msg);
}

function normPrompt(s) {
  return String(s ?? '').trim().toLowerCase().replace(/\s+/g, ' ');
}

function resolveRef(ref, rootSchema) {
  if (!ref.startsWith('#/$defs/')) {
    throw new Error(`Unsupported $ref: ${ref}`);
  }
  const key = ref.slice('#/$defs/'.length);
  const def = rootSchema.$defs?.[key];
  if (!def) throw new Error(`Missing $def: ${key}`);
  return def;
}

function validateAgainstSchema(value, nodeSchema, rootSchema, ptr) {
  const localErrors = [];
  if (nodeSchema.$ref) {
    return validateAgainstSchema(value, resolveRef(nodeSchema.$ref, rootSchema), rootSchema, ptr);
  }
  if (nodeSchema.oneOf) {
    const matches = nodeSchema.oneOf.map((branch) => validateAgainstSchema(value, branch, rootSchema, ptr));
    const passing = matches.filter((m) => m.length === 0);
    if (passing.length !== 1) {
      localErrors.push(`${ptr}: expected exactly 1 oneOf match, got ${passing.length}`);
      if (passing.length === 0) {
        matches.forEach((m, idx) => m.slice(0, 5).forEach((e) => localErrors.push(`  [oneOf #${idx}] ${e}`)));
      }
    }
    return localErrors;
  }
  if (nodeSchema.const !== undefined && JSON.stringify(value) !== JSON.stringify(nodeSchema.const)) {
    localErrors.push(`${ptr}: expected const ${JSON.stringify(nodeSchema.const)}, got ${JSON.stringify(value)}`);
  }
  if (nodeSchema.enum && !nodeSchema.enum.includes(value)) {
    localErrors.push(`${ptr}: value ${JSON.stringify(value)} not in enum ${JSON.stringify(nodeSchema.enum)}`);
  }
  if (nodeSchema.type) {
    const actualType = Array.isArray(value) ? 'array' : value === null ? 'null' : typeof value;
    const allowedTypes = Array.isArray(nodeSchema.type) ? nodeSchema.type : [nodeSchema.type];
    const matchesType = allowedTypes.some((t) =>
      t === 'integer' ? typeof value === 'number' && Number.isInteger(value) : actualType === t,
    );
    if (!matchesType) {
      localErrors.push(`${ptr}: expected ${allowedTypes.join('|')}, got ${actualType}`);
      return localErrors;
    }
  }
  if (typeof value === 'string') {
    if (nodeSchema.minLength !== undefined && value.length < nodeSchema.minLength) {
      localErrors.push(`${ptr}: string length ${value.length} < minLength ${nodeSchema.minLength}`);
    }
    if (nodeSchema.pattern && !new RegExp(nodeSchema.pattern).test(value)) {
      localErrors.push(`${ptr}: string ${JSON.stringify(value)} failed pattern ${nodeSchema.pattern}`);
    }
  }
  if (typeof value === 'number') {
    if (nodeSchema.minimum !== undefined && value < nodeSchema.minimum) {
      localErrors.push(`${ptr}: ${value} < minimum ${nodeSchema.minimum}`);
    }
    if (nodeSchema.exclusiveMinimum !== undefined && value <= nodeSchema.exclusiveMinimum) {
      localErrors.push(`${ptr}: ${value} <= exclusiveMinimum ${nodeSchema.exclusiveMinimum}`);
    }
    if (nodeSchema.maximum !== undefined && value > nodeSchema.maximum) {
      localErrors.push(`${ptr}: ${value} > maximum ${nodeSchema.maximum}`);
    }
  }
  if (Array.isArray(value)) {
    if (nodeSchema.minItems !== undefined && value.length < nodeSchema.minItems) {
      localErrors.push(`${ptr}: array length ${value.length} < minItems ${nodeSchema.minItems}`);
    }
    if (nodeSchema.maxItems !== undefined && value.length > nodeSchema.maxItems) {
      localErrors.push(`${ptr}: array length ${value.length} > maxItems ${nodeSchema.maxItems}`);
    }
    if (nodeSchema.uniqueItems) {
      const seen = new Set(value.map((item) => JSON.stringify(item)));
      if (seen.size !== value.length) {
        localErrors.push(`${ptr}: array items must be unique`);
      }
    }
    if (nodeSchema.items) {
      value.forEach((item, idx) => {
        localErrors.push(...validateAgainstSchema(item, nodeSchema.items, rootSchema, `${ptr}[${idx}]`));
      });
    }
  }
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    if (nodeSchema.minProperties !== undefined && Object.keys(value).length < nodeSchema.minProperties) {
      localErrors.push(
        `${ptr}: object has ${Object.keys(value).length} properties < minProperties ${nodeSchema.minProperties}`,
      );
    }
    for (const req of nodeSchema.required ?? []) {
      if (!(req in value)) {
        localErrors.push(`${ptr}: missing required property '${req}'`);
      }
    }
    const props = nodeSchema.properties ?? {};
    for (const [k, v] of Object.entries(value)) {
      if (k in props) {
        localErrors.push(...validateAgainstSchema(v, props[k], rootSchema, `${ptr}.${k}`));
      } else if (nodeSchema.additionalProperties === false) {
        localErrors.push(`${ptr}: unexpected additional property '${k}'`);
      } else if (nodeSchema.additionalProperties && typeof nodeSchema.additionalProperties === 'object') {
        localErrors.push(
          ...validateAgainstSchema(v, nodeSchema.additionalProperties, rootSchema, `${ptr}.${k}`),
        );
      }
    }
  }
  if (nodeSchema.allOf) {
    for (const sub of nodeSchema.allOf) {
      if (sub.if && sub.then) {
        const condErrs = validateAgainstSchema(value, sub.if, rootSchema, ptr);
        if (condErrs.length === 0) {
          localErrors.push(...validateAgainstSchema(value, sub.then, rootSchema, ptr));
        }
      } else {
        localErrors.push(...validateAgainstSchema(value, sub, rootSchema, ptr));
      }
    }
  }
  return localErrors;
}

// 1. Validate schema metadata & CEFR skeleton
assert(schema.$schema === 'https://json-schema.org/draft/2020-12/schema', 'Expected Draft 2020-12 schema');
assert(Array.isArray(schema.$defs?.CefrLevelId?.enum), 'Missing CefrLevelId enum in schema');
errors.push(...validateAgainstSchema(skeleton, schema, schema, 'cefr-skeleton'));
assert(
  JSON.stringify(skeleton.levels.map((l) => l.cefrLevel)) === JSON.stringify(['A1', 'A2', 'B1', 'B2', 'C1', 'C2']),
  'CEFR levels must be ordered A1 -> C2',
);

// 2. Discover & load starter + placement media + level curriculum/media pairs
const approvedAudioIds = new Set();
const placementAudioBySource = new Map();
const starterMediaPath = path.join(contentDir, 'starter-media.json');
assert(fs.existsSync(starterMediaPath), 'Missing starter-media.json');
if (fs.existsSync(starterMediaPath)) {
  const starterMedia = JSON.parse(fs.readFileSync(starterMediaPath, 'utf8'));
  for (const item of starterMedia.audio ?? []) {
    if (item.kind === 'audio' && (item.reviewStatus ?? starterMedia.reviewStatus) === 'approved') {
      approvedAudioIds.add(item.id);
    }
  }
}

const placementMediaPath = path.join(contentDir, 'placement-media.json');
assert(fs.existsSync(placementMediaPath), 'Missing placement-media.json');
if (fs.existsSync(placementMediaPath)) {
  const placementMedia = JSON.parse(fs.readFileSync(placementMediaPath, 'utf8'));
  assert(placementMedia.courseId === 'course_eng_01', 'placement-media.json courseId must be course_eng_01');
  assert(placementMedia.language === 'en', 'placement-media.json language must be en');
  assert(placementMedia.reviewStatus === 'approved', 'placement-media.json reviewStatus must be approved');
  for (const item of placementMedia.audio ?? []) {
    if (item.kind === 'audio' && (item.reviewStatus ?? placementMedia.reviewStatus) === 'approved') {
      approvedAudioIds.add(item.id);
      placementAudioBySource.set(item.canonicalSource, item);
    }
  }
}

const loadedLevels = [];
for (const lvl of LEVEL_ORDER) {
  const currPath = path.join(contentDir, `${lvl}-curriculum.json`);
  const mediaPath = path.join(contentDir, `${lvl}-media.json`);
  const hasCurr = fs.existsSync(currPath);
  const hasMedia = fs.existsSync(mediaPath);

  if (REQUIRED_LEVELS.has(lvl)) {
    assert(hasCurr, `Missing required ${lvl}-curriculum.json`);
    assert(hasMedia, `Missing required ${lvl}-media.json`);
  } else if (hasCurr !== hasMedia) {
    assert(false, `Unpaired files for ${lvl}: curriculum=${hasCurr}, media=${hasMedia}`);
  }

  if (hasMedia) {
    const mediaDoc = JSON.parse(fs.readFileSync(mediaPath, 'utf8'));
    for (const item of mediaDoc.audio ?? []) {
      if (item.kind === 'audio' && (item.reviewStatus ?? mediaDoc.reviewStatus) === 'approved') {
        approvedAudioIds.add(item.id);
      }
    }
  }

  if (hasCurr) {
    const doc = JSON.parse(fs.readFileSync(currPath, 'utf8'));
    loadedLevels.push({ lvl, doc });
    errors.push(...validateAgainstSchema(doc, schema, schema, `${lvl}-curriculum`));
  }
}

// 3. Placement IDs extraction from questions.ts
const placementQuestionIds = new Set();
const qtsPath = path.join(rootDir, 'src', 'data', 'datasources', 'questions.ts');
if (fs.existsSync(qtsPath)) {
  const qts = fs.readFileSync(qtsPath, 'utf8');
  for (const match of qts.matchAll(/\bid:\s*['"]([^'"]+)['"]/g)) {
    placementQuestionIds.add(match[1]);
  }
}

// 4. Global tracking & per-level validation
const seenModuleIds = new Set();
const seenUnitIds = new Set();
const seenLessonIds = new Set();
const seenNodeIds = new Set();
const seenQuestionIds = new Set();
const seenFlashcardIds = new Set();
const seenPromptsUz = new Map();
const seenPromptsRu = new Map();

for (const { lvl, doc } of loadedLevels) {
  const expectedCefr = lvl.toUpperCase();
  assert(doc.cefrLevel === expectedCefr, `${lvl}-curriculum cefrLevel '${doc.cefrLevel}' !== '${expectedCefr}'`);

  const skelLvl = skeleton.levels.find((l) => l.cefrLevel === expectedCefr);
  assert(Boolean(skelLvl), `cefr-skeleton missing level ${expectedCefr}`);
  if (skelLvl) {
    assert(
      doc.modules.length === skelLvl.modules.length,
      `${expectedCefr} modules.length (${doc.modules.length}) !== skeleton (${skelLvl.modules.length})`,
    );
    assert(
      JSON.stringify(doc.modules.map((m) => m.id)) === JSON.stringify(skelLvl.modules.map((m) => m.id)),
      `${expectedCefr} module IDs mismatch skeleton`,
    );
    doc.modules.forEach((dm, i) => {
      const sm = skelLvl.modules[i];
      if (!sm) return;
      assert(
        JSON.stringify(dm.plannedLessonIds) === JSON.stringify(sm.plannedLessonIds),
        `${dm.id}: plannedLessonIds mismatch skeleton`,
      );
      assert(dm.checkpointNodeId === sm.checkpointNodeId, `${dm.id}: checkpointNodeId mismatch skeleton`);
      assert(
        JSON.stringify(dm.prerequisites) === JSON.stringify(sm.prerequisites),
        `${dm.id}: prerequisites mismatch skeleton`,
      );
      assert(
        JSON.stringify(dm.units.map((u) => u.id)) === JSON.stringify(sm.units.map((u) => u.id)),
        `${dm.id}: unit IDs mismatch skeleton`,
      );
      dm.units.forEach((du, j) => {
        const su = sm.units[j];
        if (!su) return;
        assert(
          JSON.stringify(du.plannedLessonIds) === JSON.stringify(su.plannedLessonIds),
          `${du.id}: plannedLessonIds mismatch skeleton`,
        );
        assert(du.checkpointNodeId === su.checkpointNodeId, `${du.id}: checkpointNodeId mismatch skeleton`);
      });
    });
  }

  for (const mod of doc.modules) {
    assert(!seenModuleIds.has(mod.id), `Duplicate module id '${mod.id}'`);
    seenModuleIds.add(mod.id);
    for (const unit of mod.units) {
      assert(!seenUnitIds.has(unit.id), `Duplicate unit id '${unit.id}'`);
      seenUnitIds.add(unit.id);
    }
  }

  const levelLessonIds = new Set();
  for (const lesson of doc.lessons) {
    assert(!seenLessonIds.has(lesson.id), `Duplicate lesson id '${lesson.id}'`);
    seenLessonIds.add(lesson.id);
    levelLessonIds.add(lesson.id);

    const ref = lesson.pedagogy17?.listeningRef;
    if (ref !== null && ref !== undefined) {
      assert(
        approvedAudioIds.has(ref),
        `Lesson '${lesson.id}' pedagogy17.listeningRef '${ref}' must be null or resolve to an approved audio entry`,
      );
    }

    for (const step of lesson.steps) {
      for (const card of step.flashcards ?? []) {
        assert(!seenFlashcardIds.has(card.id), `Duplicate flashcard id '${card.id}'`);
        seenFlashcardIds.add(card.id);
      }
    }

    const qList = [
      ...lesson.steps.map((s) => s.interactiveQuestion).filter(Boolean),
      lesson.reinforcementExercise,
      lesson.alternateExercise,
    ].filter(Boolean);

    for (const q of qList) {
      assert(!seenQuestionIds.has(q.id), `Duplicate question id '${q.id}'`);
      assert(!placementQuestionIds.has(q.id), `Question ID '${q.id}' collides with questions.ts`);
      seenQuestionIds.add(q.id);

      const pUz = normPrompt(q.text);
      assert(!seenPromptsUz.has(pUz), `Duplicate question prompt '${q.text}' (also in ${seenPromptsUz.get(pUz)})`);
      seenPromptsUz.set(pUz, q.id);

      const pRu = normPrompt(q.textRu);
      if (pRu) {
        assert(!seenPromptsRu.has(pRu), `Duplicate question textRu '${q.textRu}' (also in ${seenPromptsRu.get(pRu)})`);
        seenPromptsRu.set(pRu, q.id);
      }
    }
  }

  assert(
    new Set(doc.lessonsOrder).size === doc.lessonsOrder.length,
    `${lvl}-curriculum lessonsOrder contains duplicate IDs`,
  );
  assert(
    doc.lessonsOrder.length === levelLessonIds.size &&
      doc.lessonsOrder.every((id) => levelLessonIds.has(id)),
    `${lvl}-curriculum lessonsOrder must match lessons[].id set`,
  );
  if (skelLvl) {
    for (const pid of skelLvl.plannedLessonIds) {
      assert(levelLessonIds.has(pid), `${lvl}-curriculum missing skeleton plannedLessonId '${pid}'`);
    }
  }

  const levelNodeIds = new Set();
  for (const node of doc.roadmapNodes) {
    assert(!seenNodeIds.has(node.id), `Duplicate node id '${node.id}'`);
    seenNodeIds.add(node.id);
    levelNodeIds.add(node.id);
    assert(
      levelLessonIds.has(node.targetLessonId),
      `Node '${node.id}' targetLessonId '${node.targetLessonId}' missing from ${lvl} lessons`,
    );
  }
  if (skelLvl?.exitAssessmentNodeId) {
    assert(
      levelNodeIds.has(skelLvl.exitAssessmentNodeId),
      `${lvl}-curriculum missing skeleton exitAssessmentNodeId '${skelLvl.exitAssessmentNodeId}' in roadmapNodes`,
    );
  }

  // A1-specific assertions
  if (lvl === 'a1') {
    assert(
      doc.lessonsOrder[0] === 'lesson_eng_listening_01',
      'course_eng_01 lessonsOrder[0] must be lesson_eng_listening_01',
    );
    const openableRichNode = doc.roadmapNodes.find(
      (n) => n.prerequisites.length === 0 && n.hasRichExercise && n.nodeKind === 'lesson',
    );
    assert(Boolean(openableRichNode), 'Expected at least 1 entry-openable A1 rich exercise node');

    const openableCheckpoint = doc.roadmapNodes.find(
      (n) => n.prerequisites.length === 0 && n.nodeKind === 'unit_checkpoint' && n.isCheckpoint,
    );
    assert(Boolean(openableCheckpoint), 'Expected at least 1 entry-openable A1 unit_checkpoint node');

    const openableSpeaking = doc.roadmapNodes.find(
      (n) => n.prerequisites.length === 0 && n.taskKind === 'speaking_prompt',
    );
    assert(Boolean(openableSpeaking), 'Expected at least 1 entry-openable A1 speaking_prompt node');

    const lockedCheckpoints = doc.roadmapNodes.filter(
      (n) => n.prerequisites.length > 0 && (n.nodeKind === 'unit_checkpoint' || n.nodeKind === 'level_assessment'),
    );
    assert(lockedCheckpoints.length >= 4, 'Expected A1 Unit 2-4 checkpoints and A1 exit gated by prerequisites');

    const starterLesson = doc.lessons.find((l) => l.id === 'lesson_eng_starter');
    const starterQuiz = starterLesson?.steps?.find(
      (s) => s.interactiveQuestion?.id === 'q_lesson_eng_starter_quiz',
    )?.interactiveQuestion;
    assert(Boolean(starterQuiz), 'Missing q_lesson_eng_starter_quiz in lesson_eng_starter');
    if (starterQuiz) {
      for (const variant of ["Hi my name's Sam", "Hello my name's Sam"]) {
        assert(
          starterQuiz.acceptedAnswers.includes(variant),
          `q_lesson_eng_starter_quiz.acceptedAnswers missing comma-less variant "${variant}"`,
        );
      }
    }
  } else {
    // A2+ structural assertions
    const prevExit = skelLvl?.prerequisites?.[0];
    if (prevExit) {
      const m1Id = doc.modules[0]?.id;
      const m1Entry = doc.roadmapNodes.some(
        (n) => n.moduleId === m1Id && n.prerequisites.includes(prevExit),
      );
      assert(m1Entry, `${expectedCefr} Module 1 entry node must include '${prevExit}' in prerequisites`);
    }
    const exitNode = doc.roadmapNodes.find((n) => n.id === skelLvl?.exitAssessmentNodeId);
    assert(
      Boolean(exitNode && exitNode.nodeKind === 'level_assessment'),
      `${expectedCefr} exit node '${skelLvl?.exitAssessmentNodeId}' must have nodeKind 'level_assessment'`,
    );
    const checkpoints = doc.roadmapNodes.filter(
      (n) => n.nodeKind === 'unit_checkpoint' || n.nodeKind === 'level_assessment',
    );
    for (const cp of checkpoints) {
      assert(cp.prerequisites.length > 0, `${expectedCefr} checkpoint/exit '${cp.id}' must have prerequisites`);
    }
  }
}

// 5. Cross-level prerequisite validation
for (const { lvl, doc } of loadedLevels) {
  for (const node of doc.roadmapNodes) {
    for (const prereq of node.prerequisites) {
      assert(seenNodeIds.has(prereq), `${lvl} Node '${node.id}' prerequisite '${prereq}' not found in roadmapNodes`);
    }
  }
  for (const lesson of doc.lessons) {
    for (const prereq of lesson.prerequisites) {
      assert(
        seenNodeIds.has(prereq) || seenLessonIds.has(prereq),
        `${lvl} Lesson '${lesson.id}' prerequisite '${prereq}' not found in roadmapNodes or lessons`,
      );
    }
  }
}

// 6. Placement bank validation (A1-B1 calibrated, zero B2-C2, zero 'Audio context:' leaks)
const placementPath = path.join(contentDir, 'placement-questions.json');
assert(fs.existsSync(placementPath), 'Missing placement-questions.json');
let placementCount = 0;
if (fs.existsSync(placementPath)) {
  const placementDoc = JSON.parse(fs.readFileSync(placementPath, 'utf8'));
  errors.push(...validateAgainstSchema(placementDoc, schema, schema, 'placement-questions'));

  const expectedSkills = new Set([
    'skill_eng_vocab',
    'skill_eng_grammar',
    'skill_eng_listening',
    'skill_eng_reading',
  ]);
  const expectedDifficultyByCefr = { A1: 'easy', A2: 'medium', B1: 'hard' };
  const skillLevels = new Map([...expectedSkills].map((s) => [s, new Set()]));
  const placementIds = new Set();
  const placementPromptsUz = new Set();
  const placementPromptsRu = new Set();
  const distinctCorrectIndices = new Set();

  const questions = placementDoc.questions ?? [];
  placementCount = questions.length;
  assert(questions.length === 12, `placement-questions.json must contain 12 items, got ${questions.length}`);
  assert(placementAudioBySource.size === 3, `placement-media.json must contain 3 approved audio items, got ${placementAudioBySource.size}`);

  for (const q of questions) {
    assert(!placementIds.has(q.id), `Duplicate placement question id '${q.id}'`);
    assert(!seenQuestionIds.has(q.id), `Placement question id '${q.id}' collides with M1-M3 lesson question`);
    placementIds.add(q.id);

    const pUz = normPrompt(q.text);
    const pRu = normPrompt(q.textRu);
    assert(!placementPromptsUz.has(pUz) && !seenPromptsUz.has(pUz), `Placement prompt duplicates another question: '${q.id}'`);
    assert(!placementPromptsRu.has(pRu) && !seenPromptsRu.has(pRu), `Placement textRu duplicates another question: '${q.id}'`);
    placementPromptsUz.add(pUz);
    placementPromptsRu.add(pRu);

    assert(!/audio\s*context:/i.test(q.text) && !/audio\s*context:/i.test(q.textRu), `${q.id}: forbidden 'Audio context:' text in prompt`);
    assert(['A1', 'A2', 'B1'].includes(q.cefrLevel), `${q.id}: invalid placement cefrLevel '${q.cefrLevel}' (A1-B1 only)`);
    assert(
      expectedDifficultyByCefr[q.cefrLevel] === q.difficulty,
      `${q.id}: cefrLevel '${q.cefrLevel}' must pair with difficulty '${expectedDifficultyByCefr[q.cefrLevel]}'`,
    );
    assert(expectedSkills.has(q.skillId), `${q.id}: unexpected skillId '${q.skillId}'`);
    if (skillLevels.has(q.skillId)) {
      skillLevels.get(q.skillId).add(q.cefrLevel);
    }

    distinctCorrectIndices.add(q.correctIndex);

    // Check all 4 options have non-empty UZ & RU feedback
    const fbMap = q.mistakeFeedbackByOption ?? {};
    for (const opt of q.options ?? []) {
      const entry = fbMap[opt];
      assert(
        Boolean(entry && typeof entry.uz === 'string' && entry.uz.trim() && typeof entry.ru === 'string' && entry.ru.trim()),
        `${q.id}: mistakeFeedbackByOption missing uz/ru entry for option '${opt}'`,
      );
    }

    // Gate G5: correct option not leaked verbatim in prompt or wrongFeedback
    const correctOpt = (q.options ?? [])[q.correctIndex] ?? '';
    if (correctOpt.trim().length >= 4) {
      const escaped = correctOpt.trim().toLowerCase().replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      const pat = new RegExp(`(?<!\\w)${escaped}(?!\\w)`, 'i');
      for (const [fname, fval] of [
        ['text', q.text],
        ['textRu', q.textRu],
        ['wrongFeedback', q.wrongFeedback],
        ['wrongFeedbackRu', q.wrongFeedbackRu],
      ]) {
        assert(!pat.test(String(fval ?? '')), `${q.id}: ${fname} leaks correct option '${correctOpt}'`);
      }
    }

    if (q.skillId === 'skill_eng_listening') {
      assert(Boolean(q.media), `${q.id}: listening placement item requires media`);
      if (q.media) {
        const expectedSource = `/lesson-media/english/placement/${q.id}.wav`;
        assert(q.media.source === expectedSource, `${q.id}: media.source '${q.media.source}' !== '${expectedSource}'`);
        const manifestAudio = placementAudioBySource.get(q.media.source);
        assert(Boolean(manifestAudio), `${q.id}: media.source '${q.media.source}' missing from placement-media.json`);
        if (manifestAudio) {
          assert(q.media.id === manifestAudio.id, `${q.id}: media.id mismatch with placement-media.json`);
          assert(q.media.durationSeconds === manifestAudio.durationSeconds, `${q.id}: media.durationSeconds mismatch`);
          assert(q.media.transcript === manifestAudio.transcript, `${q.id}: media.transcript mismatch`);
        }
        const strippedLines = String(q.media.transcript ?? '')
          .split(/\r?\n/)
          .map((ln) => ln.replace(/^[A-Za-z.\s]+:\s*/, '').trim())
          .filter(Boolean);
        for (const line of strippedLines) {
          if (line.length >= 20) {
            assert(
              !q.text.toLowerCase().includes(line.toLowerCase()) && !q.textRu.toLowerCase().includes(line.toLowerCase()),
              `${q.id}: prompt leaks listening transcript turn inline`,
            );
          }
        }
      }
    } else {
      assert(!q.media && !q.audioSimText, `${q.id}: non-listening placement item must not have media or audioSimText`);
    }
  }

  for (const skill of expectedSkills) {
    const levelsSet = skillLevels.get(skill);
    assert(
      levelsSet && levelsSet.size === 3 && levelsSet.has('A1') && levelsSet.has('A2') && levelsSet.has('B1'),
      `placement-questions.json skill '${skill}' must cover exactly A1, A2, B1`,
    );
  }
  assert(distinctCorrectIndices.size >= 3, `placement-questions.json correctIndex must span >= 3 positions, got ${distinctCorrectIndices.size}`);
}

if (errors.length > 0) {
  for (const err of errors) console.error(`ERROR: ${err}`);
  process.exit(1);
}

const summaryParts = loadedLevels.map(
  ({ lvl, doc }) =>
    `${lvl.toUpperCase()}(modules=${doc.modules.length}, lessons=${doc.lessons.length}, nodes=${doc.roadmapNodes.length})`,
);
console.log(
  `[OK schema+curriculum] Draft 2020-12 validated | CEFR levels=${skeleton.levels.length} | ${summaryParts.join(' | ')} | placement=${placementCount}`,
);
