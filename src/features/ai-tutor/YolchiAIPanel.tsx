import { useTranslation } from '@/core/locales/useTranslation';
import { useEffect, useRef, useState } from 'react';
import type { AIExplanationResponse } from '@/data/services/IAITutorService';
import { GeminiAITutorService } from '@/data/services/GeminiAITutorService';
import type { Question } from '@/domain/entities/Question';
import type { LessonAnswerResult } from '@/domain/usecases/SubmitLessonAnswerUseCase';
import { Button } from '@/presentation/components/Button';
import { LearningText } from '@/presentation/components/LearningText';
import { Modal } from '@/presentation/components/Modal';

const tutor = new GeminiAITutorService();

interface YolchiAIPanelProps {
  question: Question;
  answer: LessonAnswerResult;
  lessonId?: string;
  learnerScore?: number;
  recentMistakes?: string[];
  onProceedToReinforcement: () => void;
  onClose: () => void;
}

export function YolchiAIPanel({
  question,
  answer,
  lessonId,
  learnerScore,
  recentMistakes,
  onProceedToReinforcement,
  onClose,
}: YolchiAIPanelProps) {
  const { language, t } = useTranslation();
  const [retry, setRetry] = useState(0);
  const [explanation, setExplanation] = useState<AIExplanationResponse | null>(null);
  const [error, setError] = useState('');
  const request = useRef<Promise<AIExplanationResponse> | null>(null);
  const lastRequestKey = useRef<string>('');
  const requestKey = `${question.id}:${answer.selectedOption}:${language}:${lessonId ?? ''}:${retry}`;

  useEffect(() => {
    let active = true;
    if (lastRequestKey.current !== requestKey) {
      lastRequestKey.current = requestKey;
      request.current = null;
      setExplanation(null);
      setError('');
    }
    request.current ??= tutor.explainMistake({
      courseId: question.courseId,
      skillId: question.skillId,
      questionId: question.id,
      questionText: (language === 'ru' && question.textRu) ? question.textRu : question.text,
      selectedOption: answer.selectedOption,
      correctOption: answer.correctOption,
      language,
      lessonId,
      learnerScore,
      recentMistakes,
    });
    void request.current.then((value) => {
      if (active) setExplanation(value);
    }).catch((failure: unknown) => {
      if (active) setError(failure instanceof Error ? failure.message : t('tutor.explanationFailed'));
    });
    return () => { active = false; };
  }, [question, answer, language, lessonId, learnerScore, recentMistakes, requestKey, retry, t]);

  return (
    <Modal isOpen title={t('tutor.mistakes')} maxWidth="md" onClose={onClose}>
      <div className="space-y-4">
        {explanation ? (
          <div className="space-y-3 rounded-xl border border-hairline bg-canvas p-4">
            <p className="text-xs font-semibold text-brand-dark">
              {explanation.isDeterministicFallback || explanation.isFallback ? t('tutor.prepared') : t('tutor.explanation')}
            </p>
            <h3 className="font-bold">{explanation.title}</h3>
            <LearningText text={explanation.explanation} />
            <LearningText text={explanation.remediationStep} />
          </div>
        ) : error ? (
          <div className="space-y-2">
            <p role="alert">{error}</p>
            <Button variant="outline" onClick={() => {
              request.current = null;
              setError('');
              setRetry((value) => value + 1);
            }}>{t('courses.retry')}</Button>
          </div>
        ) : (
          <p role="status">{t('tutor.analyzing')}</p>
        )}
        <Button onClick={onProceedToReinforcement}>{t('tutor.reinforce')}</Button>
      </div>
    </Modal>
  );
}
