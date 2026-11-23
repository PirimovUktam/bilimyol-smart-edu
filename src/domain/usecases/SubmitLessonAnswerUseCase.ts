import { ILearnerRepository } from '../repositories/ILearnerRepository';
import {
  Question,
  evaluateSentenceOrder,
  evaluateWordMatch,
  getLocalizedMistakeFeedback,
  getLocalizedQuestionExplanation,
  matchesAcceptedAnswer,
  normalizeFreeTextAnswer,
} from '../entities/Question';

export interface LessonAnswerResult {
  isCorrect: boolean;
  selectedOption: string;
  correctOption: string;
  explanation?: string;
  newSkillScore?: number;
  overallScore?: number;
  xpAwarded?: number;
}

export class SubmitLessonAnswerUseCase {
  constructor(private learnerRepo?: ILearnerRepository) {}

  async execute(
    question: Question,
    selectedIndex: number,
    lessonId?: string,
    idempotencyKey?: string,
    language: 'uz' | 'ru' = 'uz',
  ): Promise<LessonAnswerResult> {
    const selectedOption = question.options[selectedIndex] || '';

    let isCorrect = false;
    let correctOption = '';
    let explanation = '';
    let newSkillScore: number | undefined;
    let overallScore: number | undefined;
    let xpAwarded: number | undefined;

    if (this.learnerRepo) {
      if (typeof this.learnerRepo.submitAnswerAttempt === 'function') {
        const serverResult = await this.learnerRepo.submitAnswerAttempt({
          courseId: question.courseId,
          skillId: question.skillId,
          lessonId: lessonId || 'lesson_general',
          questionId: question.id,
          selectedIndex,
          selectedAnswer: selectedOption,
          questionType: question.questionType,
          evaluationMode: question.evaluationMode,
          language,
          idempotencyKey: idempotencyKey ?? `attempt_${lessonId || 'general'}_${question.id}_${selectedIndex}`,
        });

        isCorrect = serverResult.isCorrect;
        correctOption =
          serverResult.correctOption ||
          (serverResult.correctIndex !== undefined ? question.options[serverResult.correctIndex] || '' : '');
        explanation = serverResult.explanation;
        newSkillScore = serverResult.newSkillScore;
        overallScore = serverResult.overallScore;
        xpAwarded = serverResult.xpAwarded;
      } else {
        const knownIndex = question.correctIndex ?? 0;
        isCorrect = selectedIndex === knownIndex;
        correctOption = question.options[knownIndex] || '';
        explanation = isCorrect
          ? getLocalizedQuestionExplanation(question, language)
          : getLocalizedMistakeFeedback(question, selectedOption, language);
        await this.learnerRepo.recordAnswerAttempt({
          courseId: question.courseId,
          skillId: question.skillId,
          lessonId: lessonId || 'lesson_general',
          questionId: question.id,
          selectedIndex,
          selectedAnswer: selectedOption,
          isCorrect,
        });
      }
    } else {
      // Local fallback only if no repository injected
      const knownIndex = question.correctIndex ?? 0;
      isCorrect = selectedIndex === knownIndex;
      correctOption = question.options[knownIndex] || '';
      explanation = isCorrect
        ? getLocalizedQuestionExplanation(question, language)
        : getLocalizedMistakeFeedback(question, selectedOption, language);
    }

    return {
      isCorrect,
      selectedOption,
      correctOption,
      explanation,
      newSkillScore,
      overallScore,
      xpAwarded,
    };
  }

  async executeText(
    question: Question,
    answerText: string,
    lessonId?: string,
    idempotencyKey?: string,
    language: 'uz' | 'ru' = 'uz',
  ): Promise<LessonAnswerResult> {
    const trimmed = answerText.trim();
    const answerLanguage = question.courseId === 'course_eng_01' ? undefined : 'uz';
    const normalized = normalizeFreeTextAnswer(trimmed, answerLanguage);
    const qType = question.questionType === 'fill_blank' ? 'fill_blank' : 'text_input';

    let isCorrect = false;
    let explanation = '';
    let newSkillScore: number | undefined;
    let overallScore: number | undefined;
    let xpAwarded: number | undefined;

    if (this.learnerRepo && typeof this.learnerRepo.submitAnswerAttempt === 'function') {
      const serverResult = await this.learnerRepo.submitAnswerAttempt({
        courseId: question.courseId,
        skillId: question.skillId,
        lessonId: lessonId || 'lesson_general',
        questionId: question.id,
        selectedIndex: 0,
        selectedAnswer: trimmed,
        questionType: qType,
        evaluationMode: question.evaluationMode ?? 'deterministic',
        language,
        idempotencyKey:
          idempotencyKey ?? `attempt_${lessonId || 'general'}_${question.id}_text_${normalized}`,
      });

      isCorrect = serverResult.isCorrect;
      explanation = serverResult.explanation;
      newSkillScore = serverResult.newSkillScore;
      overallScore = serverResult.overallScore;
      xpAwarded = serverResult.xpAwarded;
    } else {
      isCorrect = matchesAcceptedAnswer(trimmed, question.acceptedAnswers ?? [], answerLanguage);
      explanation = isCorrect
        ? getLocalizedQuestionExplanation(question, language)
        : getLocalizedMistakeFeedback(question, trimmed, language);
    }

    return {
      isCorrect,
      selectedOption: trimmed,
      correctOption: '',
      explanation,
      newSkillScore,
      overallScore,
      xpAwarded,
    };
  }

  async executeStructured(
    question: Question,
    payload: {
      serializedAnswer: string;
      displayAnswer: string;
      matchPairs?: Record<string, string>;
      orderedTokens?: string[];
    },
    lessonId?: string,
    idempotencyKey?: string,
    language: 'uz' | 'ru' = 'uz',
  ): Promise<LessonAnswerResult> {
    const qType = question.questionType ?? 'word_match';
    let isCorrect = false;
    let explanation = '';
    let newSkillScore: number | undefined;
    let overallScore: number | undefined;
    let xpAwarded: number | undefined;

    if (this.learnerRepo && typeof this.learnerRepo.submitAnswerAttempt === 'function') {
      const serverResult = await this.learnerRepo.submitAnswerAttempt({
        courseId: question.courseId,
        skillId: question.skillId,
        lessonId: lessonId || 'lesson_general',
        questionId: question.id,
        selectedIndex: 0,
        selectedAnswer: payload.serializedAnswer,
        questionType: qType,
        evaluationMode: question.evaluationMode ?? 'deterministic',
        language,
        idempotencyKey:
          idempotencyKey ??
          `attempt_${lessonId || 'general'}_${question.id}_${qType}_${payload.serializedAnswer}`,
      });
      isCorrect = serverResult.isCorrect;
      explanation = serverResult.explanation;
      newSkillScore = serverResult.newSkillScore;
      overallScore = serverResult.overallScore;
      xpAwarded = serverResult.xpAwarded;
    } else {
      if (qType === 'word_match') {
        isCorrect = evaluateWordMatch(payload.matchPairs ?? {}, question.matchPairs ?? []);
      } else if (qType === 'sentence_order') {
        isCorrect = evaluateSentenceOrder(
          payload.orderedTokens ?? [],
          question.orderedTokens ?? [],
          question.acceptedAnswers ?? [],
        );
      }
      explanation = isCorrect
        ? getLocalizedQuestionExplanation(question, language)
        : getLocalizedMistakeFeedback(question, payload.displayAnswer, language);
    }

    return {
      isCorrect,
      selectedOption: payload.displayAnswer,
      correctOption: '',
      explanation,
      newSkillScore,
      overallScore,
      xpAwarded,
    };
  }

  async executeSelfAssessed(
    question: Question,
    responseText: string,
    checkedCriteriaIds: string[],
    lessonId?: string,
    idempotencyKey?: string,
    language: 'uz' | 'ru' = 'uz',
  ): Promise<LessonAnswerResult> {
    const trimmed = responseText.trim();
    const qType = question.questionType === 'speaking_prompt' ? 'speaking_prompt' : 'writing_prompt';
    const serialized = JSON.stringify({ response: trimmed, criteria: checkedCriteriaIds });

    let isCorrect = false;
    let explanation = '';
    let newSkillScore: number | undefined;
    let overallScore: number | undefined;
    let xpAwarded: number | undefined;

    if (this.learnerRepo && typeof this.learnerRepo.submitAnswerAttempt === 'function') {
      const serverResult = await this.learnerRepo.submitAnswerAttempt({
        courseId: question.courseId,
        skillId: question.skillId,
        lessonId: lessonId || 'lesson_general',
        questionId: question.id,
        selectedIndex: 0,
        selectedAnswer: serialized,
        questionType: qType,
        evaluationMode: 'self_assessed',
        language,
        idempotencyKey:
          idempotencyKey ?? `attempt_${lessonId || 'general'}_${question.id}_${qType}_${trimmed}`,
      });
      isCorrect = serverResult.isCorrect;
      explanation = serverResult.explanation;
      newSkillScore = serverResult.newSkillScore;
      overallScore = serverResult.overallScore;
      xpAwarded = serverResult.xpAwarded;
    } else {
      isCorrect = trimmed.length > 0;
      explanation = isCorrect
        ? getLocalizedQuestionExplanation(question, language)
        : getLocalizedMistakeFeedback(question, '', language);
    }

    return {
      isCorrect,
      selectedOption: trimmed,
      correctOption: '',
      explanation,
      newSkillScore,
      overallScore,
      xpAwarded,
    };
  }
}
