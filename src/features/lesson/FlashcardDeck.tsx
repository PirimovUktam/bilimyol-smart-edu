import { useEffect, useMemo, useRef, useState } from 'react';
import { CheckCircle2, Eye, Layers, RotateCcw, Shuffle, Volume2 } from 'lucide-react';
import { useTranslation } from '@/core/locales/useTranslation';
import type { FlashcardSrsEntry, FlashcardStudyMode } from '@/domain/entities/LearnerProfile';
import type { LessonFlashcard } from '@/domain/entities/Lesson';
import { Button } from '@/presentation/components/Button';

export function requeueDeckCard(queue: LessonFlashcard[]): LessonFlashcard[] {
  if (queue.length <= 1) return [...queue];
  return [...queue.slice(1), queue[0]];
}

export function markDeckCardRemembered(
  queue: LessonFlashcard[],
  rememberedIds: string[]
): { nextQueue: LessonFlashcard[]; nextRememberedIds: string[] } {
  if (queue.length === 0) {
    return { nextQueue: [], nextRememberedIds: rememberedIds };
  }
  const [current, ...rest] = queue;
  const nextRememberedIds = rememberedIds.includes(current.id)
    ? rememberedIds
    : [...rememberedIds, current.id];
  return { nextQueue: rest, nextRememberedIds };
}

function deterministicShuffle(cards: LessonFlashcard[], salt: number): LessonFlashcard[] {
  const copy = [...cards];
  for (let i = copy.length - 1; i > 0; i--) {
    const j = (i * 7 + salt * 3 + copy[i].id.length) % (i + 1);
    const tmp = copy[i];
    copy[i] = copy[j];
    copy[j] = tmp;
  }
  return copy;
}

type ConcreteFaceMode = Exclude<FlashcardStudyMode, 'random'>;

function resolveEffectiveFaceMode(
  studyMode: FlashcardStudyMode,
  card: LessonFlashcard,
  indexSeed: number,
): ConcreteFaceMode {
  if (studyMode !== 'random') return studyMode;
  const candidates: ConcreteFaceMode[] = ['en_to_uz', 'uz_to_en'];
  if (card.audioSrc) candidates.push('audio_to_word');
  if (card.imageSrc) candidates.push('image_to_word');
  return candidates[indexSeed % candidates.length];
}

interface FlashcardDeckProps {
  cards: LessonFlashcard[];
  srsMap?: Record<string, FlashcardSrsEntry>;
  onRateCard?: (
    cardId: string,
    rating: 'need_practice' | 'remembered',
    intervalsDays?: readonly number[],
  ) => void;
  initialMode?: FlashcardStudyMode;
  startEmptyWhenAllDone?: boolean;
}

export function FlashcardDeck({
  cards,
  srsMap,
  onRateCard,
  initialMode = 'en_to_uz',
  startEmptyWhenAllDone = false,
}: FlashcardDeckProps) {
  const { language, t } = useTranslation();
  const cardsKey = useMemo(() => cards.map((card) => card.id).join('|'), [cards]);
  const cardsRef = useRef(cards);
  cardsRef.current = cards;

  const [studyMode, setStudyMode] = useState<FlashcardStudyMode>(initialMode);
  const [randomSeed, setRandomSeed] = useState(0);
  const [queue, setQueue] = useState<LessonFlashcard[]>(() =>
    startEmptyWhenAllDone ? [] : [...cards]
  );
  const [isRevealed, setIsRevealed] = useState(false);
  const [rememberedIds, setRememberedIds] = useState<string[]>([]);
  const [requeuedCounts, setRequeuedCounts] = useState<Record<string, number>>({});
  const [imageFailed, setImageFailed] = useState(false);
  const [audioUnavailable, setAudioUnavailable] = useState(false);
  const [statusMessage, setStatusMessage] = useState('');
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const audioGenRef = useRef(0);
  const ratedCurrentRevealRef = useRef(false);

  const stopAudio = () => {
    audioGenRef.current += 1;
    if (audioRef.current) {
      audioRef.current.onended = null;
      audioRef.current.onerror = null;
      audioRef.current.pause();
      audioRef.current.currentTime = 0;
      audioRef.current = null;
    }
  };

  useEffect(() => {
    stopAudio();
    ratedCurrentRevealRef.current = false;
    const base = cardsRef.current;
    setQueue(startEmptyWhenAllDone ? [] : [...base]);
    setIsRevealed(false);
    setRememberedIds([]);
    setRequeuedCounts({});
    setImageFailed(false);
    setAudioUnavailable(false);
    setStatusMessage('');
    return () => {
      stopAudio();
    };
  }, [cardsKey, startEmptyWhenAllDone]);

  const activeCard = queue[0];
  const activeSrs = activeCard ? srsMap?.[activeCard.id] : undefined;

  useEffect(() => {
    setImageFailed(false);
    setAudioUnavailable(false);
    return () => {
      stopAudio();
    };
  }, [activeCard?.id]);

  const handleSelectMode = (nextMode: FlashcardStudyMode) => {
    stopAudio();
    ratedCurrentRevealRef.current = false;
    setStudyMode(nextMode);
    setIsRevealed(false);
    setImageFailed(false);
    setAudioUnavailable(false);
    setStatusMessage('');
    if (nextMode === 'random') {
      const nextSeed = randomSeed + 1;
      setRandomSeed(nextSeed);
      setQueue(deterministicShuffle(cards, nextSeed));
      setRememberedIds([]);
    } else if (queue.length === 0 && cards.length > 0 && !startEmptyWhenAllDone) {
      setQueue([...cards]);
    }
  };

  const handlePlayAudio = (audioSrc?: string) => {
    if (!audioSrc || typeof Audio === 'undefined') {
      setAudioUnavailable(true);
      return;
    }
    const gen = ++audioGenRef.current;
    setAudioUnavailable(false);
    try {
      if (audioRef.current) {
        audioRef.current.onended = null;
        audioRef.current.onerror = null;
        audioRef.current.pause();
        audioRef.current.currentTime = 0;
        audioRef.current = null;
      }
      const audio = new Audio(audioSrc);
      audioRef.current = audio;
      audio.onerror = () => {
        if (audioGenRef.current === gen) {
          setAudioUnavailable(true);
        }
      };
      const playPromise = audio.play();
      if (playPromise && typeof playPromise.catch === 'function') {
        playPromise.catch(() => {
          /* Rapid taps or browser autoplay blocks must never throw unhandled errors. */
        });
      }
    } catch {
      if (audioGenRef.current === gen) {
        setAudioUnavailable(true);
      }
    }
  };

  const handleReveal = () => {
    ratedCurrentRevealRef.current = false;
    setIsRevealed(true);
    if (activeCard) {
      const meaning = language === 'ru' ? activeCard.backRu : activeCard.backUz;
      setStatusMessage(`${activeCard.front} — ${meaning}`);
    }
  };

  const handleNeedPractice = () => {
    if (!isRevealed || ratedCurrentRevealRef.current || !activeCard) return;
    ratedCurrentRevealRef.current = true;
    stopAudio();
    const ratedCard = activeCard;
    onRateCard?.(ratedCard.id, 'need_practice', ratedCard.srsDefaults?.intervalsDays);
    setIsRevealed(false);
    setRequeuedCounts((prev) => ({
      ...prev,
      [ratedCard.id]: (prev[ratedCard.id] ?? 0) + 1,
    }));
    setQueue((prev) => requeueDeckCard(prev));
    setStatusMessage(t('lesson.needPractice'));
  };

  const handleRemembered = () => {
    if (!isRevealed || ratedCurrentRevealRef.current || !activeCard) return;
    ratedCurrentRevealRef.current = true;
    stopAudio();
    const ratedCard = activeCard;
    const wasLastCard = queue.length <= 1;
    onRateCard?.(ratedCard.id, 'remembered', ratedCard.srsDefaults?.intervalsDays);
    setQueue((prevQueue) => markDeckCardRemembered(prevQueue, []).nextQueue);
    setRememberedIds((prevIds) =>
      prevIds.includes(ratedCard.id) ? prevIds : [...prevIds, ratedCard.id]
    );
    setIsRevealed(false);
    setStatusMessage(
      wasLastCard
        ? t('lesson.cardsReviewed')
        : `${ratedCard.front}: ${t('lesson.remembered')}`
    );
  };

  const handleRestart = () => {
    stopAudio();
    ratedCurrentRevealRef.current = false;
    setQueue([...cards]);
    setIsRevealed(false);
    setRememberedIds([]);
    setRequeuedCounts({});
    setImageFailed(false);
    setAudioUnavailable(false);
    setStatusMessage('');
  };

  const handleRandomPractice = () => {
    stopAudio();
    ratedCurrentRevealRef.current = false;
    const nextSeed = randomSeed + 1;
    setRandomSeed(nextSeed);
    setStudyMode('random');
    setQueue(deterministicShuffle(cards, nextSeed));
    setIsRevealed(false);
    setRememberedIds([]);
    setRequeuedCounts({});
    setImageFailed(false);
    setAudioUnavailable(false);
    setStatusMessage('');
  };

  if (cards.length === 0) {
    return (
      <section className="space-y-4" aria-label={t('lesson.flashcard')}>
        <div className="edtech-card flex flex-col items-center gap-3 border border-hairline bg-paper p-6 text-center">
          <h3 className="heading text-lg font-extrabold text-ink">{t('lesson.srsEmptyTitle')}</h3>
        </div>
      </section>
    );
  }

  const faceMode: ConcreteFaceMode = activeCard
    ? resolveEffectiveFaceMode(studyMode, activeCard, randomSeed + rememberedIds.length)
    : 'en_to_uz';
  const localizedMeaning = activeCard
    ? language === 'ru'
      ? activeCard.backRu
      : activeCard.backUz
    : '';
  const localizedAlt = activeCard
    ? (language === 'ru' ? activeCard.altRu : activeCard.alt) || activeCard.alt || t('lesson.imagePromptHint')
    : '';

  const modes: Array<{ id: FlashcardStudyMode; label: string }> = [
    { id: 'en_to_uz', label: t('lesson.modeEnToUz') },
    { id: 'uz_to_en', label: t('lesson.modeUzToEn') },
    { id: 'audio_to_word', label: t('lesson.modeAudioToWord') },
    { id: 'image_to_word', label: t('lesson.modeImageToWord') },
    { id: 'random', label: t('lesson.modeRandom') },
  ];

  const showFrontAudio =
    Boolean(activeCard?.audioSrc) && (faceMode !== 'uz_to_en' || isRevealed);
  const showImageBlock =
    Boolean(activeCard) &&
    (faceMode === 'image_to_word' || Boolean(activeCard?.imageSrc));

  return (
    <section className="space-y-4" aria-label={t('lesson.flashcard')}>
      <div className="sr-only" aria-live="polite">
        {statusMessage}
      </div>

      <div className="flex flex-wrap items-center justify-between gap-2 text-xs font-bold text-slatefine">
        <span className="highlight">
          <Layers className="size-3.5" aria-hidden="true" />
          {t('lesson.flashcard')}
        </span>
        <span className="rounded-full border border-hairline bg-paper px-3 py-1 text-ink">
          {rememberedIds.length} / {cards.length}
        </span>
      </div>

      <div
        role="group"
        aria-label={t('lesson.flashcardModeGroup')}
        className="flex flex-wrap gap-2"
      >
        {modes.map((mode) => {
          const active = studyMode === mode.id;
          return (
            <button
              key={mode.id}
              type="button"
              aria-pressed={active}
              onClick={() => handleSelectMode(mode.id)}
              className={`min-h-11 cursor-pointer rounded-xl border px-3 py-2 text-xs font-bold transition-colors ${
                active
                  ? 'border-brand bg-brand text-white'
                  : 'border-hairline bg-paper text-ink hover:bg-sand'
              }`}
            >
              {mode.label}
            </button>
          );
        })}
      </div>

      {!activeCard ? (
        <div className="edtech-card flex flex-col items-center gap-4 border border-hairline bg-paper p-6 text-center">
          <div className="flex size-12 items-center justify-center rounded-2xl border border-mint/30 bg-mint/15 text-mint">
            <CheckCircle2 className="size-6" aria-hidden="true" />
          </div>
          <div className="space-y-1">
            <h3 className="heading text-xl font-extrabold text-ink">
              {t('lesson.cardsReviewed')}
            </h3>
            <p className="text-sm font-medium text-slatefine">
              {t('lesson.srsEmptyTitle')} · {rememberedIds.length} / {cards.length}
            </p>
          </div>
          <div className="flex flex-wrap justify-center gap-2">
            <Button
              variant="outline"
              size="md"
              onClick={handleRestart}
              leftIcon={<RotateCcw className="size-4" aria-hidden="true" />}
              className="min-h-11"
            >
              {t('lesson.restartCards')}
            </Button>
            <Button
              variant="primary"
              size="md"
              onClick={handleRandomPractice}
              leftIcon={<Shuffle className="size-4" aria-hidden="true" />}
              className="min-h-11"
            >
              {t('lesson.srsRandomPractice')}
            </Button>
          </div>
        </div>
      ) : (
        <div
          key={`${activeCard.id}-${faceMode}`}
          data-testid={`flashcard-${activeCard.id}`}
          data-flashcard-mode={faceMode}
          className="edtech-card space-y-5 border border-hairline bg-paper p-5 sm:p-6"
        >
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div className="flex flex-wrap items-center gap-2">
              {activeCard.cefrLevel && (
                <span className="highlight">{activeCard.cefrLevel}</span>
              )}
              {activeCard.partOfSpeech && (
                <span className="rounded-full border border-hairline bg-sand px-3 py-1 text-xs font-semibold text-graphite">
                  {activeCard.partOfSpeech}
                </span>
              )}
              {((requeuedCounts[activeCard.id] ?? 0) > 0 || activeSrs?.status === 'need_practice') && (
                <span className="rounded-full border border-amber-500/30 bg-amber-500/15 px-3 py-1 text-xs font-semibold text-ink">
                  {t('lesson.needPractice')}
                </span>
              )}
              {activeSrs && activeSrs.status === 'remembered' && activeSrs.intervalDays >= 1 && (
                <span className="rounded-full border border-mint/30 bg-mint/15 px-3 py-1 text-xs font-semibold text-ink">
                  {t('lesson.srsNextInterval', { days: activeSrs.intervalDays })}
                </span>
              )}
            </div>

            {showFrontAudio && activeCard.audioSrc && (
              <Button
                variant="outline"
                size="sm"
                onClick={() => handlePlayAudio(activeCard.audioSrc)}
                aria-label={
                  faceMode === 'en_to_uz' || isRevealed
                    ? `${t('lesson.playAudio')}: ${activeCard.front}`
                    : t('lesson.playAudio')
                }
                leftIcon={<Volume2 className="size-4 text-brand" aria-hidden="true" />}
                className="min-h-11"
              >
                {t('lesson.playAudio')}
              </Button>
            )}
          </div>

          {audioUnavailable && (
            <p role="status" className="rounded-xl border border-hairline bg-canvas px-3 py-2 text-xs text-slatefine">
              {t('lesson.audioUnavailable')}
            </p>
          )}

          {showImageBlock && (
            !activeCard.imageSrc || imageFailed ? (
              <div
                role="img"
                aria-label={localizedAlt}
                className="rounded-xl border border-hairline bg-canvas p-4 text-sm text-slatefine"
              >
                {t('lesson.imageFailed')} {localizedAlt}
              </div>
            ) : (
              <figure className="overflow-hidden rounded-xl border border-hairline bg-canvas">
                <img
                  src={activeCard.imageSrc}
                  alt={localizedAlt}
                  onError={() => setImageFailed(true)}
                  className="max-h-56 w-full object-cover"
                />
              </figure>
            )
          )}

          {/* Front prompt box: strict polarity so target word/meaning never leaks before reveal */}
          <div className="space-y-2 rounded-2xl border border-hairline bg-canvas/70 p-5 text-center">
            {faceMode === 'en_to_uz' && (
              <h3 className="heading text-2xl font-extrabold tracking-tight text-ink sm:text-3xl">
                {activeCard.front}
              </h3>
            )}

            {faceMode === 'uz_to_en' && (
              <h3 className="heading text-2xl font-extrabold tracking-tight text-ink sm:text-3xl">
                {localizedMeaning}
              </h3>
            )}

            {faceMode === 'audio_to_word' && !isRevealed && (
              <p className="text-sm font-semibold text-graphite">
                {t('lesson.audioPromptHint')}
              </p>
            )}

            {faceMode === 'image_to_word' && !isRevealed && (
              <p className="text-sm font-semibold text-graphite">
                {t('lesson.imagePromptHint')}
              </p>
            )}

            {(faceMode === 'audio_to_word' || faceMode === 'image_to_word') && isRevealed && (
              <h3 className="heading text-2xl font-extrabold tracking-tight text-ink sm:text-3xl">
                {activeCard.front}
              </h3>
            )}

            {isRevealed && activeCard.ipa && (
              <p className="flex flex-wrap items-center justify-center gap-1.5 font-mono text-sm font-semibold text-brand-dark">
                <span>{activeCard.ipa}</span>
                {activeCard.ipaAmE && activeCard.ipaAmE !== activeCard.ipa && (
                  <span className="text-xs text-slatefine">· AmE {activeCard.ipaAmE}</span>
                )}
              </p>
            )}
          </div>

          {!isRevealed ? (
            <div className="flex justify-center">
              <Button
                variant="primary"
                size="md"
                onClick={handleReveal}
                leftIcon={<Eye className="size-4" aria-hidden="true" />}
                className="min-h-11 w-full sm:w-auto"
              >
                {t('lesson.showAnswer')}
              </Button>
            </div>
          ) : (
            <div className="space-y-4">
              <div className="space-y-3 rounded-2xl border border-hairline bg-canvas p-4">
                {faceMode === 'uz_to_en' && (
                  <p className="text-base font-extrabold text-brand-dark sm:text-lg">
                    {activeCard.front}
                  </p>
                )}
                <p className="text-base font-bold text-ink sm:text-lg">
                  {localizedMeaning}
                </p>
                <div className="space-y-1 border-t border-hairline pt-3 text-sm">
                  <span className="font-mono text-[11px] font-bold uppercase tracking-wider text-brand-dark">
                    {t('lesson.example')}
                  </span>
                  <p className="font-semibold text-ink">{activeCard.example}</p>
                  <p className="text-graphite">
                    {language === 'ru' ? activeCard.exampleRu : activeCard.exampleUz}
                  </p>
                </div>
              </div>

              <div className="flex flex-col gap-2 sm:flex-row">
                <Button
                  variant="outline"
                  size="md"
                  onClick={handleNeedPractice}
                  leftIcon={<RotateCcw className="size-4" aria-hidden="true" />}
                  className="min-h-11 flex-1"
                >
                  {t('lesson.needPractice')}
                </Button>
                <Button
                  variant="success"
                  size="md"
                  onClick={handleRemembered}
                  leftIcon={<CheckCircle2 className="size-4" aria-hidden="true" />}
                  className="min-h-11 flex-1"
                >
                  {t('lesson.remembered')}
                </Button>
              </div>
            </div>
          )}
        </div>
      )}
    </section>
  );
}
