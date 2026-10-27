import { Question } from '@/domain/entities/Question';

/**
 * Stable per-question option ordering.
 *
 * The curated seed banks originally shipped every question with the correct
 * option at index 0, which made every quiz trivially guessable ("always A") and
 * pedagogically meaningless. We deterministically permute options per question
 * id so the correct answer lands at a varied, stable position.
 *
 * The permutation is a pure function of the question id, so the SAME order is
 * produced wherever the bank is imported — the learner UI and the in-memory
 * "server" scorer both see identical options + correctIndex. The answer key is
 * moved together with its option, so correctness is always preserved.
 */
const stableHash = (value: string): number => {
  let hash = 2166136261;
  for (let i = 0; i < value.length; i++) {
    hash ^= value.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
};

export function permuteQuestionOptions<T extends Question>(question: T): T {
  if (!question || !Array.isArray(question.options) || question.options.length < 2) return question;

  const total = question.options.length;
  const current = question.correctIndex;
  if (typeof current !== 'number' || !Number.isInteger(current) || current < 0 || current >= total) {
    return question;
  }

  const target = stableHash(question.id) % total;
  if (target === current) return question;

  const correctOption = question.options[current];
  const remaining = question.options.filter((_, index) => index !== current);
  remaining.splice(target, 0, correctOption);

  return { ...question, options: remaining, correctIndex: target };
}
