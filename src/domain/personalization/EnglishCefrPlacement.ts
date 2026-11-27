import type { CefrLevelId, Question, QuestionAnswerSubmission } from '../entities/Question';

export type PlacementCefrLevel = 'Pre-A1' | 'A1' | 'A2' | 'B1';

export interface EnglishPlacementCefrBreakdown {
  assessedCefr: PlacementCefrLevel;
  unlockedCefrFloor: PlacementCefrLevel | null;
  effectiveCefr: PlacementCefrLevel;
}

const CEFR_RANK: Record<PlacementCefrLevel, number> = {
  'Pre-A1': 0,
  A1: 1,
  A2: 2,
  B1: 3,
};

function resolveQuestionCefrTier(question: Pick<Question, 'difficulty' | 'cefrLevel'>): 'A1' | 'A2' | 'B1' {
  if (question.cefrLevel === 'B1' || question.cefrLevel === 'B2' || question.cefrLevel === 'C1' || question.cefrLevel === 'C2') {
    return 'B1';
  }
  if (question.cefrLevel === 'A2') return 'A2';
  if (question.cefrLevel === 'A1' || question.cefrLevel === 'Pre-A1') return 'A1';
  if (question.difficulty === 'hard') return 'B1';
  if (question.difficulty === 'medium') return 'A2';
  return 'A1';
}

/**
 * Separates current diagnostic reassessment tier (`assessedCefr`) from previously
 * earned exit-node unlock floor (`unlockedCefrFloor`), and computes `effectiveCefr`.
 * Requires `b1Total >= 2 && b1Acc >= 0.5` before awarding `'B1'` (`FIX-P0-11`, `FIX-P2-09`).
 */
export function evaluateEnglishPlacementCefr(
  questions: ReadonlyArray<Pick<Question, 'id' | 'difficulty' | 'cefrLevel'>>,
  submissions: QuestionAnswerSubmission[],
  completedNodeIds: string[] = [],
): EnglishPlacementCefrBreakdown {
  const questionsById = new Map(questions.map((q) => [q.id, q]));
  const deduped = new Map<string, QuestionAnswerSubmission>();
  for (const sub of submissions) {
    if (questionsById.has(sub.questionId)) {
      deduped.set(sub.questionId, sub);
    }
  }

  let answered = 0;
  let correct = 0;
  let a1Total = 0;
  let a1Correct = 0;
  let a2Total = 0;
  let a2Correct = 0;
  let b1Total = 0;
  let b1Correct = 0;

  deduped.forEach((sub) => {
    const q = questionsById.get(sub.questionId)!;
    answered += 1;
    if (sub.isCorrect) correct += 1;

    const tier = resolveQuestionCefrTier(q);
    if (tier === 'A1') {
      a1Total += 1;
      if (sub.isCorrect) a1Correct += 1;
    } else if (tier === 'A2') {
      a2Total += 1;
      if (sub.isCorrect) a2Correct += 1;
    } else {
      b1Total += 1;
      if (sub.isCorrect) b1Correct += 1;
    }
  });

  const overall = answered > 0 ? correct / answered : 0;
  const higherTotal = a2Total + b1Total;
  const higherCorrect = a2Correct + b1Correct;
  const higherAcc = higherTotal > 0 ? higherCorrect / higherTotal : overall;
  const a2Acc = a2Total > 0 ? a2Correct / a2Total : higherAcc;
  const a1Acc = a1Total > 0 ? a1Correct / a1Total : (a2Total > 0 ? a2Acc : overall);
  const b1Acc = b1Total > 0 ? b1Correct / b1Total : 0;

  let assessedCefr: PlacementCefrLevel = 'Pre-A1';
  if (answered > 0) {
    if (overall >= 0.875 && a1Acc >= 0.75 && higherAcc >= 0.75 && b1Total >= 2 && b1Acc >= 0.5) {
      assessedCefr = 'B1';
    } else if (
      (overall >= 0.625 && a1Acc >= 0.5 && a2Acc >= 0.5) ||
      (a2Total >= 3 && a2Acc >= 0.75 && a1Acc >= 0.5)
    ) {
      assessedCefr = 'A2';
    } else if (overall >= 0.375) {
      assessedCefr = 'A1';
    } else {
      assessedCefr = 'Pre-A1';
    }
  }

  let unlockedCefrFloor: PlacementCefrLevel | null = null;
  if (completedNodeIds.includes('node_eng_a2_exit')) {
    unlockedCefrFloor = 'B1';
  } else if (completedNodeIds.includes('node_eng_a1_exit')) {
    unlockedCefrFloor = 'A2';
  }

  const effectiveCefr =
    unlockedCefrFloor && CEFR_RANK[unlockedCefrFloor] > CEFR_RANK[assessedCefr]
      ? unlockedCefrFloor
      : assessedCefr;

  return {
    assessedCefr,
    unlockedCefrFloor,
    effectiveCefr,
  };
}

/**
 * Calibrated English CEFR placement tier capped strictly at B1 (B2–C2 are DEFERRED).
 * Never manufactures completed lessons/nodes, though previously earned exit nodes
 * act as an unlock floor without ever exceeding B1.
 */
export function computeEnglishPlacementCefr(
  questions: ReadonlyArray<Pick<Question, 'id' | 'difficulty' | 'cefrLevel'>>,
  submissions: QuestionAnswerSubmission[],
  completedNodeIds: string[] = [],
): PlacementCefrLevel {
  return evaluateEnglishPlacementCefr(questions, submissions, completedNodeIds).effectiveCefr;
}

export function getEnglishPlacementEntryNodeId(cefr: CefrLevelId | PlacementCefrLevel): string {
  if (cefr === 'B1' || cefr === 'B2' || cefr === 'C1' || cefr === 'C2') {
    return 'node_eng_b1_m1_travel';
  }
  if (cefr === 'A2') {
    return 'node_eng_a2_m1_directions';
  }
  return 'node_eng_a1_m1_greetings';
}
