/** Pure boundary shared by fresh, cached and deterministic lesson responses. */
const answerFields = new Set([
  'correctIndex', 'correct_index', 'correctOption', 'correct_option',
  'correctOptionId', 'correct_option_id', 'correctAnswer', 'correct_answer',
  'answerIndex', 'answer_index', 'answer', 'explanation',
]);

export function stripAnswerKeys(value: unknown): any {
  if (Array.isArray(value)) return value.map(stripAnswerKeys);
  if (value === null || typeof value !== 'object') return value;
  return Object.fromEntries(
    Object.entries(value)
      .filter(([key]) => !answerFields.has(key))
      .map(([key, nested]) => [key, stripAnswerKeys(nested)]),
  );
}

/** Template ids are not global question ids: each skill owns its answer row. */
export function scopeFallbackQuestionId(sourceId: string, courseId: string, skillId: string): string {
  return `${sourceId}_${courseId}_${skillId}`;
}
