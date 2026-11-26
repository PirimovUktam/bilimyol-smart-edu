import { useTranslation } from '@/core/locales/useTranslation';
import React, { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import confetti from 'canvas-confetti';
import { CheckCircle2, XCircle, Award, ArrowRight, Zap, X } from 'lucide-react';
import { Question, type WordMatchPair } from '@/domain/entities/Question';
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
  lessonId?: string;
  reinforcementNodeId?: string;
  onSuccess: () => void;
  onClose: () => void;
}

export const ReinforcementModal: React.FC<ReinforcementModalProps> = ({
  isOpen,
  question,
  courseId,
  skillId,
  lessonId,
  reinforcementNodeId: explicitReinforcementNodeId,
  onSuccess,
  onClose,
}) => {
  const { language, t } = useTranslation();
  const { completeReinforcement, isUpdating, roadmap, error: submissionError } = useRoadmapStore();

  const [selectedIdx, setSelectedIdx] = useState<number | null>(null);
  const [textInput, setTextInput] = useState('');
  const [matchedPairs, setMatchedPairs] = useState<Record<string, string>>({});
  const [selectedMatchLeft, setSelectedMatchLeft] = useState<string | null>(null);
  const [pickedTokenIndices, setPickedTokenIndices] = useState<number[]>([]);
  const [feedbackState, setFeedbackState] = useState<'answering' | 'success' | 'incorrect'>('answering');
  const [scoreTransition, setScoreTransition] = useState<{ oldScore: number; newScore: number; xpAwarded?: number } | null>(null);
  const [failureFeedback, setFailureFeedback] = useState<{ correctOption?: string; explanation?: string } | null>(null);

  const qType = question.questionType ?? 'multiple_choice';
  const isTextMode = qType === 'text_input' || qType === 'fill_blank';
  const isMatchMode = qType === 'word_match';
  const isOrderMode = qType === 'sentence_order';
  const isSelfAssessed = qType === 'speaking_prompt' || qType === 'writing_prompt';
  const isChoiceMode = !isTextMode && !isOrderMode && !isMatchMode && !isSelfAssessed;

  const shuffledRightPairs = React.useMemo<WordMatchPair[]>(() => {
    const pairs = question.matchPairs ?? [];
    if (pairs.length <= 1) return [...pairs];
    const shift = Math.max(1, question.id.length % pairs.length);
    return [...pairs.slice(shift), ...pairs.slice(0, shift)];
  }, [question.id, question.matchPairs]);

  const shuffledOrder = React.useMemo(() => {
    const tokens = question.orderedTokens ?? [];
    if (tokens.length <= 1) return tokens.map((token, idx) => ({ idx, token }));
    const copy = tokens.map((token, idx) => ({ idx, token }));
    const shift = Math.max(1, question.id.length % copy.length);
    return [...copy.slice(shift), ...copy.slice(0, shift)];
  }, [question.id, question.orderedTokens]);

  useEffect(() => {
    if (isOpen) {
      setSelectedIdx(null);
      setTextInput('');
      setMatchedPairs({});
      setSelectedMatchLeft(null);
      setPickedTokenIndices([]);
      setFeedbackState('answering');
      setScoreTransition(null);
      setFailureFeedback(null);
    }
  }, [isOpen, question.id]);

  if (!isOpen) return null;

  const canSubmit = isChoiceMode
    ? selectedIdx !== null
    : isTextMode || isSelfAssessed
    ? textInput.trim().length > 0
    : isMatchMode
    ? (question.matchPairs?.length ?? 0) > 0 &&
      Object.keys(matchedPairs).length === (question.matchPairs?.length ?? 0)
    : pickedTokenIndices.length > 0;

  const handleSelectMatchLeft = (pairId: string) => {
    if (isUpdating) return;
    setFeedbackState('answering');
    setFailureFeedback(null);
    setSelectedMatchLeft((prev) => (prev === pairId ? null : pairId));
  };

  const handleSelectMatchRight = (rightPairId: string) => {
    if (isUpdating) return;
    setFeedbackState('answering');
    setFailureFeedback(null);
    if (!selectedMatchLeft) {
      const owner = Object.entries(matchedPairs).find(([, r]) => r === rightPairId)?.[0];
      if (owner) {
        const next = { ...matchedPairs };
        delete next[owner];
        setMatchedPairs(next);
      }
      return;
    }
    const next = { ...matchedPairs };
    for (const [k, v] of Object.entries(next)) {
      if (v === rightPairId) delete next[k];
    }
    next[selectedMatchLeft] = rightPairId;
    setMatchedPairs(next);
    setSelectedMatchLeft(null);
  };

  const handleSubmit = async () => {
    if (!canSubmit || isUpdating) return;

    const reinforcementNodeId =
      explicitReinforcementNodeId ||
      deriveReinforcementNodeId(roadmap, courseId, skillId, lessonId);
    const overrideAnswer = isTextMode
      ? textInput.trim()
      : isMatchMode
      ? JSON.stringify(
          Object.fromEntries(
            Object.entries(matchedPairs)
              .map(([leftId, rightVal]) => {
                const rightPair = question.matchPairs?.find((p) => p.id === rightVal);
                return [leftId, rightPair ? rightPair.right : rightVal] as const;
              })
              .sort(([a], [b]) => a.localeCompare(b)),
          ),
        )
      : isOrderMode
      ? JSON.stringify(pickedTokenIndices.map((idx) => shuffledOrder[idx]?.token ?? '').filter(Boolean))
      : isSelfAssessed
      ? JSON.stringify({ response: textInput.trim(), criteria: [] })
      : undefined;

    let result: Awaited<ReturnType<typeof completeReinforcement>>;
    try {
      result = await completeReinforcement(
        courseId,
        skillId,
        reinforcementNodeId,
        question,
        selectedIdx ?? 0,
        overrideAnswer,
        language,
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
                    <h3 className="font-display text-xl font-bold text-ink">{t('assessment.apply')}</h3>
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
                  {(language === 'ru' && question.textRu) ? question.textRu : question.text}
                </h4>
                {question.sentenceWithError && (
                  <p className="rounded-lg border border-coral/30 bg-coral/10 px-3 py-2 font-mono text-xs font-bold text-ink">
                    {question.sentenceWithError}
                  </p>
                )}
                {question.dialogueContext && question.dialogueContext.length > 0 && (
                  <div className="space-y-1 rounded-lg border border-brand/25 bg-sand px-3 py-2 text-xs text-ink">
                    {question.dialogueContext.map((line, i) => (
                      <p key={i}>{line}</p>
                    ))}
                  </div>
                )}
                {question.blankTemplate && (
                  <p className="rounded-lg border border-brand/25 bg-sand px-3 py-2 text-xs font-semibold text-ink">
                    {question.blankTemplate}
                  </p>
                )}
                {question.formulaLatex && (
                  <div className="p-3 bg-paper rounded-lg border border-hairline text-center font-mono font-bold text-brand-dark text-sm">
                    <Formula source={question.formulaLatex} display />
                  </div>
                )}
              </div>

              {/* Input / Options */}
              {isTextMode ? (
                <div className="space-y-2">
                  <input
                    type="text"
                    value={textInput}
                    onChange={(e) => {
                      setTextInput(e.target.value);
                      setFeedbackState('answering');
                      setFailureFeedback(null);
                    }}
                    placeholder={t('lesson.answerPlaceholder')}
                    disabled={isUpdating}
                    className="form-input min-h-11 w-full px-4 py-3"
                  />
                </div>
              ) : isSelfAssessed ? (
                <div className="space-y-3">
                  <textarea
                    rows={4}
                    value={textInput}
                    onChange={(e) => {
                      setTextInput(e.target.value);
                      setFeedbackState('answering');
                      setFailureFeedback(null);
                    }}
                    placeholder={t('lesson.selfAssessedPlaceholder')}
                    disabled={isUpdating}
                    className="form-input w-full px-4 py-3"
                  />
                  {question.sampleResponse && (
                    <p className="rounded-xl border border-hairline bg-canvas px-3 py-2 text-xs text-slatefine">
                      {t('lesson.modelResponse')}: {question.sampleResponse}
                    </p>
                  )}
                </div>
              ) : isMatchMode && question.matchPairs ? (
                <div className="space-y-3">
                  <p className="text-xs font-medium text-slatefine">{t('lesson.wordMatchSelectPrompt')}</p>
                  <div
                    role="group"
                    aria-label={t('lesson.wordMatchGroup')}
                    className="grid grid-cols-1 sm:grid-cols-2 gap-3"
                  >
                    <div data-match-side="left" className="space-y-2">
                      <span className="block font-mono text-[11px] font-bold uppercase tracking-wider text-slatefine">
                        {t('lesson.wordMatchLeft')}
                      </span>
                      {question.matchPairs.map((pair) => {
                        const isSelectedLeft = selectedMatchLeft === pair.id;
                        const assignedRightId = matchedPairs[pair.id];
                        const assignedPair = question.matchPairs?.find((p) => p.id === assignedRightId);
                        return (
                          <button
                            key={pair.id}
                            type="button"
                            data-match-item
                            data-pair-id={pair.id}
                            aria-pressed={isSelectedLeft}
                            disabled={isUpdating}
                            onClick={() => handleSelectMatchLeft(pair.id)}
                            className={`flex min-h-11 w-full cursor-pointer items-center justify-between gap-2 rounded-xl border px-3.5 py-2.5 text-left text-sm font-bold transition-colors ${
                              isSelectedLeft
                                ? 'border-brand bg-brand/15 text-brand-dark ring-2 ring-brand/30'
                                : assignedPair
                                ? 'border-mint/40 bg-mint/10 text-ink'
                                : 'border-hairline bg-canvas text-ink hover:bg-sand'
                            }`}
                          >
                            <span>{pair.left}</span>
                            {assignedPair && (
                              <span className="rounded-full bg-sand px-2 py-0.5 text-xs font-semibold text-brand-dark">
                                {assignedPair.right}
                              </span>
                            )}
                          </button>
                        );
                      })}
                    </div>

                    <div data-match-side="right" className="space-y-2">
                      <span className="block font-mono text-[11px] font-bold uppercase tracking-wider text-slatefine">
                        {t('lesson.wordMatchRight')}
                      </span>
                      {shuffledRightPairs.map((pair) => {
                        const isUsed = Object.values(matchedPairs).includes(pair.id);
                        return (
                          <button
                            key={pair.id}
                            type="button"
                            data-match-item
                            data-pair-id={pair.id}
                            aria-pressed={isUsed}
                            disabled={isUpdating}
                            onClick={() => handleSelectMatchRight(pair.id)}
                            className={`flex min-h-11 w-full cursor-pointer items-center justify-between gap-2 rounded-xl border px-3.5 py-2.5 text-left text-sm font-semibold transition-colors ${
                              isUsed
                                ? 'border-brand/40 bg-sand text-brand-dark'
                                : 'border-hairline bg-canvas text-ink hover:bg-sand'
                            }`}
                          >
                            <span>{pair.right}</span>
                          </button>
                        );
                      })}
                    </div>
                  </div>
                  {Object.keys(matchedPairs).length > 0 && (
                    <div>
                      <Button
                        type="button"
                        size="sm"
                        variant="ghost"
                        disabled={isUpdating}
                        onClick={() => {
                          setMatchedPairs({});
                          setSelectedMatchLeft(null);
                          setFeedbackState('answering');
                          setFailureFeedback(null);
                        }}
                        className="min-h-11"
                      >
                        {t('lesson.clearSelection')}
                      </Button>
                    </div>
                  )}
                </div>
              ) : isOrderMode ? (
                <div className="space-y-3">
                  <div className="flex min-h-12 flex-wrap gap-2 rounded-xl border border-hairline bg-canvas p-3">
                    {pickedTokenIndices.map((sIdx, pos) => (
                      <button
                        key={`${sIdx}-${pos}`}
                        type="button"
                        onClick={() => setPickedTokenIndices((prev) => prev.filter((_, i) => i !== pos))}
                        className="min-h-10 cursor-pointer rounded-lg border border-brand/40 bg-brand/15 px-3 py-1 text-xs font-bold text-brand-dark"
                      >
                        {shuffledOrder[sIdx]?.token}
                      </button>
                    ))}
                  </div>
                  <div className="flex flex-wrap gap-2">
                    {shuffledOrder.map((item, sIdx) => {
                      const picked = pickedTokenIndices.includes(sIdx);
                      return (
                        <button
                          key={`${item.idx}-${item.token}`}
                          type="button"
                          disabled={picked || isUpdating}
                          onClick={() => setPickedTokenIndices((prev) => [...prev, sIdx])}
                          className={`min-h-10 cursor-pointer rounded-lg border px-3 py-1.5 text-xs font-bold ${
                            picked ? 'border-hairline bg-sand text-slatefine opacity-45' : 'border-hairline bg-paper text-ink hover:bg-sand'
                          }`}
                        >
                          {item.token}
                        </button>
                      );
                    })}
                  </div>
                </div>
              ) : (
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
                            ? 'border-mint/50 bg-mint/10 ring-2 ring-mint/30 text-[#6EE7B7]'
                            : isWrongPick
                            ? 'border-coral/50 bg-coral/10 ring-2 ring-coral/25 text-[#FDA4AF]'
                            : isSelected
                            ? 'border-brand ring-2 ring-brand/40 bg-sand shadow-xs text-ink'
                            : 'border-hairline bg-canvas hover:border-brand/40 hover:bg-paper text-graphite'
                        }`}
                      >
                        <div className="flex items-center gap-3">
                          <span className={`w-6 h-6 rounded flex items-center justify-center text-xs ${
                            isCorrectOption
                              ? 'bg-mint text-white'
                              : isWrongPick
                              ? 'bg-coral text-white'
                              : isSelected
                              ? 'bg-brand text-white'
                              : 'bg-hairline text-ink'
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
                          <CheckCircle2 className="w-4 h-4 text-brand" />
                        ) : null}
                      </button>
                    );
                  })}
                </div>
              )}

              {feedbackState === 'incorrect' && (
                <div className="p-3.5 bg-coral/10 border border-coral/30 rounded-xl space-y-2">
                  <div className="flex flex-col sm:flex-row sm:items-center gap-2">
                    {isChoiceMode && selectedIdx !== null && (
                      <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-coral/15 border border-coral/30 font-mono text-[11px] font-bold text-ink">
                        <XCircle className="w-3.5 h-3.5 text-coral" />{t('lesson.selectedAnswer')}{' '}{question.options[selectedIdx]}
                      </span>
                    )}
                    {isChoiceMode && failureFeedback?.correctOption && (
                      <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-mint/15 border border-mint/30 font-mono text-[11px] font-bold text-ink">
                        <CheckCircle2 className="w-3.5 h-3.5 text-mint" />{t('lesson.rightAnswer')}{' '}{failureFeedback.correctOption}
                      </span>
                    )}
                  </div>
                  <p className="text-xs font-medium text-ink leading-relaxed">
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
                  disabled={!canSubmit || isUpdating}
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
                <h3 className="font-display text-2xl font-extrabold text-ink mt-1">{t('assessment.reinforced')}</h3>
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

              <p className="rounded-xl border border-emerald-500/30 bg-emerald-500/10 px-3.5 py-2 text-xs font-bold text-mint max-w-md mx-auto">
                {t('adaptive.reinforceImpact')}
              </p>

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
