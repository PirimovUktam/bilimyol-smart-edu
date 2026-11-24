import type { CefrLevelId, Question, QuestionAnswerSubmission } from '../entities/Question';

export type PlacementCefrLevel = 'Pre-A1' | 'A1' | 'A2' | 'B1';

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
 * Calibrated English CEFR placement tier capped strictly at B1 (B2–C2 are DEFERRED).
 * Never manufactures completed lessons/nodes, though previously earned exit nodes
 * act as a floor without ever exceeding B1.
 */
export function computeEnglishPlacementCefr(
  questions: ReadonlyArray<Pick<Question, 'id' | 'difficulty' | 'cefrLevel'>>,
  submissions: QuestionAnswerSubmission[],
  completedNodeIds: string[] = [],
): PlacementCefrLevel {
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
  const a1Acc = a1Total > 0 ? a1Correct / a1Total : overall;
  const higherTotal = a2Total + b1Total;
  const higherCorrect = a2Correct + b1Correct;
  const higherAcc = higherTotal > 0 ? higherCorrect / higherTotal : overall;
  const b1Acc = b1Total > 0 ? b1Correct / b1Total : higherAcc;
  const a2Acc = a2Total > 0 ? a2Correct / a2Total : higherAcc;

  let placed: PlacementCefrLevel = 'Pre-A1';
  if (answered > 0) {
    if (overall >= 0.875 && a1Acc >= 0.75 && higherAcc >= 0.75 && b1Acc >= 0.5) {
      placed = 'B1';
    } else if (overall >= 0.625 && a1Acc >= 0.5 && a2Acc >= 0.5) {
      placed = 'A2';
    } else if (overall >= 0.375) {
      placed = 'A1';
    } else {
      placed = 'Pre-A1';
    }
  }

  if (completedNodeIds.includes('node_eng_a2_exit')) {
    return 'B1';
  }
  if (completedNodeIds.includes('node_eng_a1_exit') && (placed === 'Pre-A1' || placed === 'A1')) {
    return 'A2';
  }
  return placed;
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
