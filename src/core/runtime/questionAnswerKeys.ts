import { permuteQuestionOptions } from '@/core/utils/questionOptionOrder';
import { Question } from '@/domain/entities/Question';

/**
 * Runtime answer-key registry.
 *
 * AI / deterministic-fallback questions are generated at runtime and are not
 * part of the static seed banks, so the in-memory scorer has no way to know
 * their correct option. Keeping the key inside the client `Question` object
 * would leak the answer and breaks the anti-cheat contract enforced by the
 * generated-content tests.
 *
 * Instead the AI services (which act as the "server" for AI content in the
 * bundled demo runtime) register the answer key here, and the in-memory learner
 * repository — the demo-mode scoring authority — looks it up. The key never
 * travels in the question payload returned to the UI.
 */
export interface RuntimeQuestionAnswerKey {
  correctIndex: number;
  explanation: string;
  options: string[];
}

const registry = new Map<string, RuntimeQuestionAnswerKey>();

export function registerQuestionAnswerKey(question: {
  id?: string;
  options?: string[];
  correctIndex?: number;
  explanation?: string;
}): void {
  if (!question || typeof question.id !== 'string' || !Array.isArray(question.options)) return;
  const index = question.correctIndex;
  if (typeof index !== 'number' || !Number.isInteger(index) || index < 0 || index >= question.options.length) return;
  registry.set(question.id, {
    correctIndex: index,
    explanation: question.explanation || '',
    options: [...question.options],
  });
}

export function getQuestionAnswerKey(questionId: string): RuntimeQuestionAnswerKey | undefined {
  return registry.get(questionId);
}

export function clearQuestionAnswerKeys(): void {
  registry.clear();
}

type AuthoredQuestion = {
  id?: string;
  options?: string[];
  correctIndex?: number;
  explanation?: string;
};

/**
 * Deterministically permutes an authored question's options, registers the
 * resulting answer key, and returns the question WITHOUT any answer metadata so
 * it is safe to hand to the client. Used by the AI services for generated and
 * deterministic-fallback questions.
 */
export function publishQuestionWithRegisteredKey<T extends AuthoredQuestion>(
  raw: T
): Omit<T, 'correctIndex' | 'explanation'> {
  const permuted = permuteQuestionOptions(raw as unknown as Question) as unknown as T;
  registerQuestionAnswerKey(permuted as AuthoredQuestion);
  const clone = { ...(permuted as Record<string, unknown>) };
  delete clone.correctIndex;
  delete clone.explanation;
  return clone as Omit<T, 'correctIndex' | 'explanation'>;
}
