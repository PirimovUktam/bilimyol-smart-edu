import { useTranslation } from '@/core/locales/useTranslation';
import React, { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import confetti from 'canvas-confetti';
import { CheckCircle2, XCircle, Award, ArrowRight, Zap, X } from 'lucide-react';
import { Question } from '@/domain/entities/Question';
import { useRoadmapStore } from '@/app/store/useRoadmapStore';
import { deriveReinforcementNodeId } from './reinforcementNodeId';
import { Button } from '@/presentation/components/Button';
import { Formula } from '@/presentation/components/LearningText';
import { Modal } from '@/presentation/components/Modal';
import { sounds } from '@/core/utils/soundEffects';

interface ReinforcementModalProps {
  isOpen: boolean;
  question: Question;
  courseId: string;
  skillId: string;
  onSuccess: () => void;
  onClose: () => void;
}

export const ReinforcementModal: React.FC<ReinforcementModalProps> = ({
  isOpen,
  question,
  courseId,
  skillId,
  onSuccess,
  onClose,
}) => {
  const { t } = useTranslation();
  const { completeReinforcement, isUpdating, roadmap, error: submissionError } = useRoadmapStore();

  const [selectedIdx, setSelectedIdx] = useState<number | null>(null);
  const [feedbackState, setFeedbackState] = useState<'answering' | 'success' | 'incorrect'>('answering');
  const [scoreTransition, setScoreTransition] = useState<{ oldScore: number; newScore: number; xpAwarded?: number } | null>(null);
  const [failureFeedback, setFailureFeedback] = useState<{ correctOption?: string; explanation?: string } | null>(null);

  useEffect(() => {
    if (isOpen) {
      setSelectedIdx(null);
      setFeedbackState('answering');
      setScoreTransition(null);
      setFailureFeedback(null);
    }
  }, [isOpen]);

  if (!isOpen) return null;

  const handleSubmit = async () => {
    if (selectedIdx === null || isUpdating) return;

    const reinforcementNodeId = deriveReinforcementNodeId(roadmap, courseId, skillId);

    let result: Awaited<ReturnType<typeof completeReinforcement>>;
    try {
      result = await completeReinforcement(
        courseId,
        skillId,
        reinforcementNodeId,
        question,
        selectedIdx
      );
    } catch {
      setFeedbackState('answering');
      return;
    }

    if (result.isCorrect) {
      sounds.playSuccess();
      setTimeout(() => sounds.playUnlock(), 300);

      // Trigger Confetti
      confetti({
        particleCount: 80,
        spread: 70,
        origin: { y: 0.6 },
        disableForReducedMotion: true,
      });

      setScoreTransition({
        oldScore: result.oldScore,
        newScore: result.newScore,
        xpAwarded: result.xpAwarded ?? 0,
      });
      setFailureFeedback(null);
      setFeedbackState('success');
    } else {
      sounds.playMistake();
      setFailureFeedback({
        correctOption: result.correctOption,
        explanation: result.explanation,
      });
      setFeedbackState('incorrect');
    }
  };

  return (
    <Modal isOpen={isOpen} title={t('assessment.reinforcement')} maxWidth="lg" onClose={onClose}
      showClose={false} dismissable={!isUpdating}>
      <div>
          {feedbackState !== 'success' ? (
            <div className="space-y-6 pt-1">
              {/* Header */}
              <div className="flex items-start justify-between gap-4">
                <div className="flex items-center gap-3">
                  <div className="w-11 h-11 rounded-xl bg-navy text-white flex items-center justify-center shrink-0 shadow-md">
                    <Zap className="w-5 h-5 text-amber-400" />
                  </div>
                  <div>
                    <div className="editorial-kicker">
                      <span>{t('assessment.remediation')}</span>
                      <span>//</span>
                      <span>{t('assessment.reinforcementTitle')}</span>
                    </div>
                    <h3 className="font-display text-xl font-bold text-navy">{t('assessment.apply')}</h3>
                  </div>
                </div>

                <button
                  onClick={onClose}
                  aria-label={t('courses.close')}
                  disabled={isUpdating}
                  className="p-1.5 rounded-lg text-slate-400 hover:text-graphite hover:bg-sand transition-colors cursor-pointer"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>

              {/* Question */}
              <div className="p-5 rounded-xl bg-canvas border border-hairline space-y-3">
                <h4 className="font-display text-base sm:text-lg font-bold text-ink">
                  {question.text}
                </h4>
                {question.formulaLatex && (
                  <div className="p-3 bg-paper rounded-lg border border-hairline text-center font-mono font-bold text-brand-dark text-sm">
                    <Formula source={question.formulaLatex} display />
                  </div>
                )}
              </div>

              {/* Options */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                {question.options.map((opt, idx) => {
                  const isSelected = selectedIdx === idx;
                  const letter = String.fromCharCode(65 + idx);
                  const showResult = feedbackState === 'incorrect';
                  const correctText = failureFeedback?.correctOption || '';
                  const isCorrectOption = showResult && correctText !== '' && opt === correctText;
                  const isWrongPick = showResult && isSelected && !isCorrectOption;

                  return (
                    <button
                      key={idx}
                      type="button"
                      onClick={() => {
                        setSelectedIdx(idx);
                        setFeedbackState('answering');
                        setFailureFeedback(null);
                      }}
                      disabled={isUpdating}
                      className={`p-4 rounded-xl border text-left font-mono font-bold text-sm transition-all cursor-pointer flex items-center justify-between ${
                        isCorrectOption
                          ? 'border-mint/50 bg-mint/10 ring-2 ring-mint/30 text-[#046b4a]'
                          : isWrongPick
                          ? 'border-coral/50 bg-coral/5 ring-2 ring-coral/25 text-[#a51c1c]'
                          : isSelected
                          ? 'border-navy ring-2 ring-navy bg-paper shadow-xs'
                          : 'border-hairline bg-canvas hover:border-slate-400 hover:bg-paper text-graphite'
                      }`}
                    >
                      <div className="flex items-center gap-3">
                        <span className={`w-6 h-6 rounded flex items-center justify-center text-xs ${
                          isCorrectOption
                            ? 'bg-mint text-white'
                            : isWrongPick
                            ? 'bg-coral text-white'
                            : isSelected
                            ? 'bg-navy text-white'
                            : 'bg-hairline text-slate-700'
                        }`}>
                          {letter}
                        </span>
                        <span>{opt}</span>
                      </div>
                      {isCorrectOption ? (
                        <CheckCircle2 className="w-4 h-4 text-mint" />
                      ) : isWrongPick ? (
                        <XCircle className="w-4 h-4 text-coral" />
                      ) : isSelected ? (
                        <CheckCircle2 className="w-4 h-4 text-navy" />
                      ) : null}
                    </button>
                  );
                })}
              </div>

              {feedbackState === 'incorrect' && (
                <div className="p-3.5 bg-coral/5 border border-coral/25 rounded-xl space-y-2">
                  <div className="flex flex-col sm:flex-row sm:items-center gap-2">
                    {selectedIdx !== null && (
                      <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-coral/10 border border-coral/30 font-mono text-[11px] font-bold text-[#a51c1c]">
                        <XCircle className="w-3.5 h-3.5" />{t('lesson.selectedAnswer')}{' '}{question.options[selectedIdx]}
                      </span>
                    )}
                    {failureFeedback?.correctOption && (
                      <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-mint/15 border border-mint/30 font-mono text-[11px] font-bold text-[#046b4a]">
                        <CheckCircle2 className="w-3.5 h-3.5" />{t('lesson.rightAnswer')}{' '}{failureFeedback.correctOption}
                      </span>
                    )}
                  </div>
                  <p className="text-xs font-medium text-slate-700 leading-relaxed">
                    {failureFeedback?.explanation || t('assessment.incorrect')}
                  </p>
                </div>
              )}
              {submissionError && (
                <div role="alert" className="p-3 bg-coral/5 border border-coral/25 rounded-xl text-xs font-mono font-bold text-coral">{t('assessment.notSaved')}{' '}{submissionError}{' '}{t('assessment.retrySuffix')}</div>
              )}

              {/* Action Buttons */}
              <div className="pt-4 border-t border-hairline flex items-center justify-between">
                <Button variant="ghost" size="md" onClick={onClose} className="font-mono text-xs font-bold text-slatefine">{t('courses.cancel')}</Button>

                <Button
                  variant="primary"
                  size="md"
                  disabled={selectedIdx === null || isUpdating}
                  isLoading={isUpdating}
                  onClick={handleSubmit}
                  rightIcon={<ArrowRight className="w-4 h-4" />}
                  className="font-bold uppercase tracking-wider text-xs px-6 py-2.5"
                >{t('assessment.check')}</Button>
              </div>
            </div>
          ) : (
            /* Success & Score Update Screen */
            <motion.div
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              className="text-center space-y-6 py-4 pt-2"
            >
              <div className="w-16 h-16 rounded-2xl bg-navy text-white flex items-center justify-center mx-auto shadow-lg">
                <CheckCircle2 className="w-8 h-8 text-mint stroke-[2.5]" />
              </div>

              <div className="space-y-1">
                <div className="editorial-kicker justify-center text-mint">
                  <span>{t('assessment.confirmed')}</span>
                </div>
                <h3 className="font-display text-2xl font-extrabold text-navy mt-1">{t('assessment.reinforced')}</h3>
                <p className="text-xs sm:text-sm text-slatefine max-w-md mx-auto font-sans">{t('assessment.reinforcedDescription')}</p>
              </div>

              {/* Score Transition Banner */}
              <div className="p-6 bg-navy rounded-xl text-white space-y-4 max-w-md mx-auto shadow-xl border border-slate-800">
                <div className="flex items-center justify-between font-mono text-xs">
                  <span className="text-slate-400">{t('assessment.mastery')}</span>
                  <span className="font-bold px-2 py-0.5 rounded bg-emerald-500/20 text-mint border border-emerald-500/30">
                    +{scoreTransition ? Math.max(0, scoreTransition.newScore - scoreTransition.oldScore) : 0}{t('assessment.growth')}</span>
                </div>

                <div className="flex items-center justify-center gap-6">
                  <div className="text-center font-mono">
                    <span className="text-[10px] text-slate-400 block mb-0.5 uppercase tracking-wider">{t('assessment.previous')}</span>
                    <span className="text-2xl font-bold text-coral line-through">
                      {scoreTransition?.oldScore}%
                    </span>
                  </div>

                  <ArrowRight className="w-5 h-5 text-slatefine" />

                  <div className="text-center font-mono">
                    <span className="text-[10px] text-slate-400 block mb-0.5 uppercase tracking-wider">{t('assessment.new')}</span>
                    <span className="text-3xl font-extrabold text-mint">
                      {scoreTransition?.newScore}%
                    </span>
                  </div>
                </div>

                <div className="pt-3 border-t border-slate-800 flex items-center justify-between font-mono text-[11px] text-slate-300">
                  <span className="flex items-center gap-1.5 text-amber-300 font-bold">
                    <Award className="w-4 h-4" /> +{scoreTransition?.xpAwarded ?? 0}{t('assessment.xp')}</span>
                  <span className="flex items-center gap-1.5 text-mint font-bold">{t('assessment.saved')}</span>
                </div>
              </div>

              <div className="pt-2">
                <Button
                  variant="primary"
                  size="lg"
                  onClick={onSuccess}
                  rightIcon={<ArrowRight className="w-5 h-5" />}
                  className="w-full sm:w-auto px-8 font-bold"
                >{t('courses.continue')}</Button>
              </div>
            </motion.div>
          )}
      </div>
    </Modal>
  );
};
