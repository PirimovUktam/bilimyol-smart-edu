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
  onProceedToReinforcement: () => void;
  onClose: () => void;
}

export function YolchiAIPanel({ question, answer, onProceedToReinforcement, onClose }: YolchiAIPanelProps) {
  const [retry, setRetry] = useState(0);
  const [explanation, setExplanation] = useState<AIExplanationResponse | null>(null);
  const [error, setError] = useState('');
  const request = useRef<Promise<AIExplanationResponse> | null>(null);

  useEffect(() => {
    let active = true;
    request.current ??= tutor.explainMistake({
      courseId: question.courseId,
      skillId: question.skillId,
      questionId: question.id,
      questionText: question.text,
      selectedOption: answer.selectedOption,
      correctOption: answer.correctOption,
    });
    void request.current.then((value) => {
      if (active) setExplanation(value);
    }).catch((failure: unknown) => {
      if (active) setError(failure instanceof Error ? failure.message : 'Izohni yuklab bo‘lmadi.');
    });
    return () => { active = false; };
  }, [question, answer, retry]);

  return (
    <Modal isOpen title="Yo‘lchi bilan xato tahlili" maxWidth="md" onClose={onClose}>
      <div className="space-y-4">
        {explanation ? (
          <div className="space-y-3 rounded-xl border border-hairline bg-canvas p-4">
            <p className="text-xs font-semibold text-brand-dark">
              {explanation.isDeterministicFallback || explanation.isFallback ? 'Tayyor izoh' : 'Yo‘lchi AI izohi'}
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
            }}>Qayta urinish</Button>
          </div>
        ) : (
          <p role="status">Yo‘lchi topshirilgan javobni tahlil qilmoqda…</p>
        )}
        <Button onClick={onProceedToReinforcement}>Mavzuni mustahkamlash mashqi</Button>
      </div>
    </Modal>
  );
}
