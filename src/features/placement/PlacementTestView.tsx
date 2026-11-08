import { useEffect, useState } from 'react';
import { ArrowRight, Check, ClipboardCheck, Sparkles } from 'lucide-react';
import { useCourseStore } from '@/app/store/useCourseStore';
import { usePlacementStore } from '@/app/store/usePlacementStore';
import { Button } from '@/presentation/components/Button';
import { Card } from '@/presentation/components/Card';
import { Formula } from '@/presentation/components/LearningText';
import { Modal } from '@/presentation/components/Modal';
import { PageHeader } from '@/presentation/components/PageHeader';
import { Progress } from '@/presentation/components/Progress';
import { SectionState } from '@/presentation/components/SectionState';
import { AudioSimWave } from '@/features/lesson/AudioSimWave';

export function PlacementTestView({ onComplete, onChooseCourse, onStartLearning }: {
  onComplete: () => void; onChooseCourse: () => void; onStartLearning: () => void;
}) {
  const course = useCourseStore((state) => state.activeCourse);
  const skills = useCourseStore((state) => state.activeCourseSkills);
  const question = usePlacementStore((state) => state.currentQuestion);
  const number = usePlacementStore((state) => state.questionNumber);
  const total = usePlacementStore((state) => state.totalQuestionsToAsk);
  const submitting = usePlacementStore((state) => state.isSubmitting);
  const loading = usePlacementStore((state) => state.isLoading);
  const error = usePlacementStore((state) => state.error);
  const result = usePlacementStore((state) => state.assessmentResult);
  const canRetake = usePlacementStore((state) => state.canRetake);
  const [selection, setSelection] = useState<number | null>(null);
  const [confirm, setConfirm] = useState(false);
  const courseId = course?.id;
  const finalQuestion = number >= total;
  const init = (id: string, restart = false) => {
    setSelection(null);
    setConfirm(false);
    void usePlacementStore.getState().initPlacement(id, restart);
  };

  useEffect(() => {
    if (courseId) init(courseId);
    return () => usePlacementStore.getState().resetPlacement();
  }, [courseId]);

  const submit = async () => {
    if (selection == null || submitting) return;
    setConfirm(false);
    const before = usePlacementStore.getState();
    await before.submitAnswer(selection);
    const after = usePlacementStore.getState();
    if (after.currentQuestion?.id !== before.currentQuestion?.id || after.sessionId !== before.sessionId) setSelection(null);
  };

  return (
    <div className="learning-page max-w-200 space-y-6">
      <PageHeader
        title="Boshlang‘ich diagnostika"
        highlightWord="diagnostika"
        eyebrow={course?.title ?? 'Bilim darajasi'}
        description="Diagnostika ixtiyoriy. Fan bilan endi tanishayotgan bo‘lsangiz, avval darsdan boshlashingiz mumkin."
        action={course && !result ? <Button variant="outline" onClick={onStartLearning}>Darsdan boshlash</Button> : undefined}
      />
      {!courseId ? (
        <Card className="space-y-4">
          <SectionState title="Avval fanni tanlang" />
          <Button onClick={onChooseCourse}>Fanlar katalogi</Button>
        </Card>
      ) : loading ? (
        <SectionState kind="loading" title="Diagnostika savollari yuklanmoqda…" />
      ) : result ? (
        <Card className="fade-up space-y-5" padding="md">
          <div className="flex items-center gap-3">
            <span className="grid size-12 place-items-center rounded-2xl bg-emerald-50 text-mint">
              <ClipboardCheck aria-hidden="true" className="size-7" />
            </span>
            <div>
              <span className="highlight">Natija tayyor</span>
              <h2 className="heading mt-1 text-2xl font-extrabold">Diagnostika yakunlandi</h2>
            </div>
          </div>
          <p className="text-sm font-semibold text-slatefine">
            {result.submissions.filter((answer) => answer.isCorrect).length} / {result.submissions.length} javob to‘g‘ri.
          </p>
          <ul className="space-y-3" aria-label="Ko‘nikmalar bo‘yicha natijalar">
            {Object.values(result.computedScores).map((score) => (
              <li key={score.skillId}>
                <Progress
                  showLabel
                  value={score.score}
                  ariaLabel={skills.find((skill) => skill.id === score.skillId)?.name ?? 'Ko‘nikma'}
                  tone={score.score < 50 ? 'amber' : 'emerald'}
                />
              </li>
            ))}
          </ul>
          <div className="flex flex-wrap gap-2.5 pt-1">
            <Button onClick={onComplete} rightIcon={<ArrowRight aria-hidden="true" className="size-4" />}>
              Shaxsiy yo‘lni ko‘rish
            </Button>
            {canRetake && (
              <Button variant="outline" onClick={() => init(courseId, true)}>
                Qayta topshirish
              </Button>
            )}
          </div>
          {!!result.review?.length && (
            <details className="rounded-2xl border border-hairline bg-canvas/60 p-4">
              <summary className="cursor-pointer font-bold text-brand">Javoblar tahlili</summary>
              <ol className="mt-3 space-y-3">
                {result.review.map((answer, index) => (
                  <li key={answer.questionId} className="space-y-1 rounded-2xl border border-hairline bg-paper p-3.5 text-sm leading-relaxed">
                    <p className={'font-bold ' + (answer.isCorrect ? 'text-mint' : 'text-coral')}>
                      {answer.isCorrect ? 'To‘g‘ri' : 'Xato'}
                    </p>
                    <p className="break-words font-bold">{index + 1}. {answer.questionText}</p>
                    <p className="break-words">Siz belgilagan javob — {answer.selectedOption}</p>
                    {!answer.isCorrect && <p className="break-words font-semibold text-mint">To‘g‘ri javob — {answer.correctOption}</p>}
                    {answer.explanation && <p className="break-words text-slatefine">{answer.explanation}</p>}
                  </li>
                ))}
              </ol>
            </details>
          )}
        </Card>
      ) : !question ? (
        <SectionState
          kind={error ? 'error' : 'empty'}
          title={error ? 'Diagnostikani yuklab bo‘lmadi' : 'Savollar tayyorlanmoqda'}
          description={error ?? undefined}
          onRetry={() => init(courseId)}
        />
      ) : (
        <>
          <div className="flex items-center justify-between gap-2">
            <span className="highlight">
              <Sparkles aria-hidden="true" className="size-3.5" />
              {number} / {total} savol
            </span>
          </div>
          <Progress value={(100 * number) / total} ariaLabel="Diagnostika jarayoni" size="sm" />
          <Card className="fade-up space-y-5 p-5 sm:p-7">
            <h2 className="heading break-words text-xl font-extrabold sm:text-2xl">{question.text}</h2>
            {question.contextSnippet && (
              <p className="rounded-2xl bg-canvas p-4 text-sm leading-relaxed text-slatefine">{question.contextSnippet}</p>
            )}
            {question.formulaLatex && <Formula source={question.formulaLatex} display />}
            {question.audioSimText && (
              <AudioSimWave transcript={question.audioSimText} speakerName={question.audioSimSpeaker ?? 'Audio xabar'} />
            )}
            <fieldset className="space-y-2.5" disabled={submitting}>
              <legend className="sr-only">Javob variantlari</legend>
              {question.options.map((option, index) => (
                <label
                  key={index}
                  className={
                    'flex min-h-13 cursor-pointer items-center gap-3.5 rounded-2xl border px-4 py-3 text-sm transition-all ' +
                    (selection === index
                      ? 'border-brand bg-sand font-bold ring-2 ring-brand/20'
                      : 'border-hairline bg-paper hover:border-brand/50')
                  }
                >
                  <input
                    type="radio"
                    name="placement-option"
                    checked={selection === index}
                    className="size-4 shrink-0 accent-brand"
                    onChange={() => setSelection(index)}
                  />
                  <span className="min-w-0 flex-1 break-words">{option}</span>
                  {selection === index && <Check aria-hidden="true" className="size-4 shrink-0 text-brand" />}
                </label>
              ))}
            </fieldset>
            {error && (
              <div role="alert" className="space-y-2 rounded-2xl bg-rose-50 p-3.5 text-sm text-coral">
                <p>{error}</p>
                <Button variant="ghost" size="sm" onClick={() => init(courseId)}>
                  Sessiyani qayta yuklash
                </Button>
              </div>
            )}
            <div className="flex justify-end pt-1">
              <Button
                isLoading={submitting}
                disabled={selection == null}
                onClick={() => {
                  if (finalQuestion) setConfirm(true);
                  else void submit();
                }}
                rightIcon={<ArrowRight aria-hidden="true" className="size-4" />}
              >
                {finalQuestion ? 'Natijani ko‘rish' : 'Keyingi savol'}
              </Button>
            </div>
          </Card>
          <Modal isOpen={confirm} onClose={() => setConfirm(false)} title="Javoblarni topshirasizmi?" maxWidth="sm">
            <p className="mb-4 text-sm text-slatefine">Oxirgi javobni yuborgach, natijangiz saqlanadi.</p>
            <div className="flex flex-wrap justify-end gap-2">
              <Button variant="ghost" onClick={() => setConfirm(false)}>
                Qaytish
              </Button>
              <Button onClick={() => void submit()}>Topshirish</Button>
            </div>
          </Modal>
        </>
      )}
    </div>
  );
}
