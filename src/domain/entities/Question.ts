import { DifficultyLevel } from '@/core/types/common';
import type { LessonMedia } from './LessonMedia';

export type CefrLevelId = 'Pre-A1' | 'A1' | 'A2' | 'B1' | 'B2' | 'C1' | 'C2';

export type QuestionType =
  | 'multiple_choice'
  | 'text_input'
  | 'fill_blank'
  | 'word_match'
  | 'sentence_order'
  | 'error_correction'
  | 'conversation_completion'
  | 'speaking_prompt'
  | 'writing_prompt';

export type QuestionEvaluationMode = 'deterministic' | 'self_assessed';

export interface WordMatchPair {
  id: string;
  left: string;
  right: string;
}

export interface RubricCriterion {
  id: string;
  labelUz: string;
  labelRu: string;
}

export interface LocalizedFeedback {
  uz: string;
  ru: string;
  en?: string;
}

export interface Question {
  id: string;
  courseId: string;
  skillId: string;
  skillDomain?: string;
  cefrLevel?: CefrLevelId;
  topic?: string;
  isPlacement?: boolean;
  text: string;
  textRu?: string;
  contextSnippet?: string;
  questionType?: QuestionType;
  evaluationMode?: QuestionEvaluationMode;
  options: string[];
  correctIndex?: number;
  acceptedAnswers?: string[];
  blankTemplate?: string;
  sentenceWithError?: string;
  dialogueContext?: string[];
  matchPairs?: WordMatchPair[];
  orderedTokens?: string[];
  sampleResponse?: string;
  rubricCriteria?: RubricCriterion[];
  selfAssessmentNoticeUz?: string;
  selfAssessmentNoticeRu?: string;
  mistakeFeedbackByOption?: Record<string, LocalizedFeedback>;
  difficulty: DifficultyLevel;
  explanation: string;
  explanationRu?: string;
  wrongFeedback?: string;
  wrongFeedbackRu?: string;
  formulaLatex?: string;
  audioSimText?: string;
  audioSimSpeaker?: string;
  media?: LessonMedia;
}

export interface QuestionAnswerSubmission {
  questionId: string;
  selectedIndex: number;
  isCorrect: boolean;
  timeSpentSeconds: number;
}

export function normalizeFreeTextAnswer(input: string): string {
  return input
    .trim()
    .replace(/,/g, ' ')
    .replace(/[’‘`´\u02BB\u02BC]/g, "'")
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .replace(/[\s.,!?]+$/g, '')
    .trim();
}

export function matchesAcceptedAnswer(input: string, acceptedAnswers: string[] = []): boolean {
  const normalized = normalizeFreeTextAnswer(input);
  if (!normalized) return false;
  return acceptedAnswers.some((candidate) => {
    const normalizedCandidate = normalizeFreeTextAnswer(candidate);
    return normalizedCandidate.length > 0 && normalizedCandidate === normalized;
  });
}

export function evaluateWordMatch(
  submittedPairs: Record<string, string>,
  matchPairs: WordMatchPair[] = [],
): boolean {
  if (!matchPairs.length) return false;
  return matchPairs.every((pair) => {
    const chosen = submittedPairs[pair.id];
    if (typeof chosen !== 'string') return false;
    const trimmed = chosen.trim();
    return trimmed === pair.id || normalizeFreeTextAnswer(trimmed) === normalizeFreeTextAnswer(pair.right);
  });
}

export function evaluateSentenceOrder(
  submittedTokens: string[],
  orderedTokens: string[] = [],
  acceptedAnswers: string[] = [],
): boolean {
  if (!submittedTokens.length || !orderedTokens.length) return false;
  if (submittedTokens.length === orderedTokens.length &&
      orderedTokens.every((token, index) => token === submittedTokens[index])) {
    return true;
  }
  const joined = submittedTokens.join(' ');
  const targetCandidates = acceptedAnswers.length > 0
    ? acceptedAnswers
    : [orderedTokens.join(' ')];
  return matchesAcceptedAnswer(joined, targetCandidates);
}

export function getLocalizedQuestionExplanation(
  question: Question,
  language: 'uz' | 'ru' = 'uz',
): string {
  return (language === 'ru' ? question.explanationRu : undefined) || question.explanation || '';
}

export function getLocalizedMistakeFeedback(
  question: Question,
  selectedOption: string,
  language: 'uz' | 'ru' = 'uz',
): string {
  const perOption = selectedOption ? question.mistakeFeedbackByOption?.[selectedOption] : undefined;
  const perOptionText = perOption ? (language === 'ru' ? perOption.ru : perOption.uz) : undefined;
  return (
    perOptionText ||
    (language === 'ru' ? question.wrongFeedbackRu : undefined) ||
    question.wrongFeedback ||
    getLocalizedQuestionExplanation(question, language)
  );
}
