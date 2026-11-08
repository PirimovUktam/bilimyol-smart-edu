import { useCallback, useEffect, useRef, useState, type FormEvent } from 'react';
import { AnimatePresence } from 'framer-motion';
import { ArrowRight, BookOpen, HelpCircle, Lightbulb, Plus, RefreshCw, Send, Sparkles } from 'lucide-react';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { useLessonStore } from '@/app/store/useLessonStore';
import { useRoadmapStore } from '@/app/store/useRoadmapStore';
import { useAuth } from '@/core/context/AuthContext';
import { readTutorHistory, writeTutorHistory, type TutorMessage } from '@/core/runtime/tutorHistory';
import { GeminiAITutorService, GeminiAIServiceError } from '@/data/services/GeminiAITutorService';
import { YolchiMessageBubble, YolchiTypingIndicator } from '@/features/ai-tutor/YolchiMessageBubble';
import { Button } from '@/presentation/components/Button';
import { Card } from '@/presentation/components/Card';
import { IconButton } from '@/presentation/components/IconButton';
import { PageHeader } from '@/presentation/components/PageHeader';
import { YolchiAIMascot } from '@/presentation/components/YolchiAIMascot';

const tutor = new GeminiAITutorService();
const time = new Intl.DateTimeFormat('uz-Latn', { hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Tashkent' });
const prompts = [
  { title: 'Qoidani sodda tushuntir', icon: Lightbulb },
  { title: 'Yana bitta misol ber', icon: BookOpen },
  { title: 'Mavzuni test qilib ko‘r', icon: HelpCircle },
];

export function YolchiAIChatView({ onStartLesson }: { onStartLesson: () => void }) {
  const { profile, isDemoMode } = useAuth();
  const course = useCourseStore((state) => state.activeCourse);
  const path = useRoadmapStore((state) => state.roadmap);
  const lesson = useLessonStore((state) => state.currentLesson);
  const learner = useLearnerStore((state) => state.profile);
  const courseId = course?.id;
  useEffect(() => {
    if (courseId && useRoadmapStore.getState().roadmap?.courseId !== courseId) {
      void useRoadmapStore.getState().loadRoadmap(courseId);
    }
  }, [courseId]);

  const activeLesson = lesson?.courseId === courseId ? lesson : null;
  const node = path?.courseId === courseId ? path?.nodes.find((item) => item.id === path.activeNodeId) : null;
  const skillId = activeLesson?.skillId ?? node?.skillId;
  const topic = activeLesson?.title ?? node?.title;
  const score = courseId && skillId ? learner?.scoresByCourse[courseId]?.[skillId]?.score : undefined;
  const conversation = (profile?.id ?? 'guest') + '/' + (courseId ?? 'general');
  return (
    <div className="learning-page space-y-6 sm:space-y-8">
      <PageHeader
        eyebrow="Shaxsiy ustoz"
        title="Yo‘lchi AI"
        highlightWord="AI"
        description="Qoidani tushunib oling, xatoni tahlil qiling yoki mavzuga mos misol so‘rang."
        action={
          courseId && (
            <Button
              variant="outline"
              onClick={onStartLesson}
              rightIcon={<ArrowRight aria-hidden="true" className="size-4" />}
            >
              Darsga o‘tish
            </Button>
          )
        }
      />
      <TutorConversation
        key={conversation}
        conversation={conversation}
        courseId={courseId}
        courseTitle={course?.title}
        skillId={skillId}
        topic={topic}
        score={score}
        isDemoMode={isDemoMode}
      />
    </div>
  );
}

export function TutorConversation({ conversation, courseId, courseTitle, skillId, topic, score, isDemoMode, compact = false }: {
  conversation: string; courseId?: string; courseTitle?: string; skillId?: string; topic?: string;
  score?: number; isDemoMode: boolean; compact?: boolean;
}) {
  const [messages, setMessages] = useState(() => readTutorHistory(conversation));
  const [draft, setDraft] = useState('');
  const [waiting, setWaiting] = useState(false);
  const [failure, setFailure] = useState<{ prompt: string; error: string } | null>(null);
  const [streamingState, setStreamingState] = useState<{ id: string; visibleLength: number } | null>(null);
  const stream = useRef<HTMLDivElement>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const input = useRef<HTMLTextAreaElement>(null);
  const mounted = useRef(true);
  const busy = useRef(false);
  const streamRaf = useRef<number | null>(null);

  const isReducedMotion = () =>
    typeof window === 'undefined' ||
    typeof window.matchMedia !== 'function' ||
    window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  const scrollToBottomSmart = useCallback((force = false) => {
    const el = stream.current;
    if (!el) return;
    const distanceFromBottom = el.scrollHeight - el.scrollTop - el.clientHeight;
    if (force || distanceFromBottom <= 120) {
      if (typeof messagesEndRef.current?.scrollIntoView === 'function' && !isReducedMotion()) {
        messagesEndRef.current.scrollIntoView({ behavior: 'smooth', block: 'end' });
      } else {
        el.scrollTop = el.scrollHeight;
      }
    }
  }, []);

  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
      if (streamRaf.current != null) cancelAnimationFrame(streamRaf.current);
    };
  }, []);

  useEffect(() => {
    scrollToBottomSmart(false);
  }, [messages, waiting, failure, streamingState, scrollToBottomSmart]);

  const keep = useCallback((next: TutorMessage[]) => {
    const recent = next.slice(-60);
    writeTutorHistory(conversation, recent);
    setMessages(recent);
  }, [conversation]);

  const startStreamingReveal = useCallback((id: string, fullText: string) => {
    if (isReducedMotion() || fullText.length <= 16) {
      setStreamingState(null);
      return;
    }
    if (streamRaf.current != null) cancelAnimationFrame(streamRaf.current);
    const totalLen = fullText.length;
    const startTime = performance.now();
    const durationMs = Math.min(480, Math.max(180, totalLen * 3.5));

    setStreamingState({ id, visibleLength: Math.min(12, totalLen) });

    const tick = (now: number) => {
      if (!mounted.current) return;
      const progress = Math.min(1, (now - startTime) / durationMs);
      const nextLen = Math.max(12, Math.floor(totalLen * progress));
      if (progress < 1) {
        setStreamingState({ id, visibleLength: nextLen });
        streamRaf.current = requestAnimationFrame(tick);
      } else {
        setStreamingState(null);
        streamRaf.current = null;
      }
    };
    streamRaf.current = requestAnimationFrame(tick);
  }, []);

  const send = async (prompt: string, retry = false) => {
    const text = prompt.trim();
    if (!text || busy.current) return;
    busy.current = true;
    setWaiting(true);
    setFailure(null);
    const prior = retry ? messages.slice(0, -1) : messages;
    const next = retry ? messages : [...messages, { id: crypto.randomUUID(), sender: 'user' as const, text, time: Date.now() }];
    if (!retry) {
      keep(next);
      setDraft('');
      scrollToBottomSmart(true);
    }

    try {
      const response = await tutor.askTutor({
        message: text,
        courseId,
        skillId,
        ...(isDemoMode ? { topic: topic ?? courseTitle, learnerScore: score } : {}),
        history: prior.slice(-6).map(({ sender, text: value }) => ({ sender, text: value.slice(0, 800) })),
      });
      if (mounted.current) {
        const aiId = crypto.randomUUID();
        keep([...next, { id: aiId, sender: 'ai', text: response.answer, time: Date.now() }]);
        startStreamingReveal(aiId, response.answer);
      }
    } catch (error) {
      if (mounted.current) setFailure({
        prompt: text,
        error: error instanceof GeminiAIServiceError ? error.message : 'Javob olinmadi. Qayta urinib ko‘ring.',
      });
    } finally {
      busy.current = false;
      if (mounted.current) setWaiting(false);
    }
  };

  const feedback = useCallback((id: string, value: NonNullable<TutorMessage['feedback']>) => {
    setMessages((prev) => {
      const updated = prev.map((message) => message.id === id
        ? { ...message, feedback: message.feedback === value ? undefined : value }
        : message);
      writeTutorHistory(conversation, updated);
      return updated;
    });
  }, [conversation]);

  const submit = (event: FormEvent) => {
    event.preventDefault();
    void send(draft);
  };

  return (
    <div className={compact ? 'grid min-w-0' : 'grid items-start gap-5 xl:grid-cols-[17rem_minmax(0,1fr)]'}>
      {!compact && (
        <aside className="fade-up stagger-1 order-2 space-y-4 xl:order-1" aria-label="O‘quv konteksti">
          <section className="learning-hero space-y-3 rounded-3xl p-6">
            <div aria-hidden="true" className="tutor-orbit">
              <YolchiAIMascot size="md" mood="explaining" />
            </div>
            <span className="inline-flex items-center gap-1.5 rounded-full bg-white/15 px-3 py-1 text-xs font-bold text-indigo-100">
              <Sparkles aria-hidden="true" className="size-3.5 text-sky-300" />
              Faol mavzu
            </span>
            <h2 className="font-display text-xl font-extrabold">Sizning mavzuingiz</h2>
            <p className="break-words text-sm font-semibold text-indigo-100">{courseTitle ?? 'Umumiy suhbat'}</p>
            {topic && <p className="break-words text-sm text-indigo-100/90">{topic}</p>}
            {score != null && (
              <p className="inline-flex rounded-full bg-emerald-400/20 px-3 py-1 text-xs font-bold text-emerald-200">
                O‘zlashtirish · {score}%
              </p>
            )}
          </section>
          <Card padding="sm" className="space-y-2">
            <span className="highlight">Tezkor savollar</span>
            <h2 className="heading text-sm font-extrabold">Suhbatni boshlang</h2>
            <div className="space-y-1 pt-1">
              {prompts.map(({ title, icon: Icon }) => (
                <button
                  type="button"
                  key={title}
                  disabled={waiting}
                  onClick={() => void send(title)}
                  className="flex min-h-11 w-full cursor-pointer items-center gap-2.5 rounded-xl px-3 text-left text-sm font-medium text-slatefine transition-colors hover:bg-sand hover:text-brand disabled:opacity-50"
                >
                  <Icon aria-hidden="true" className="size-4 shrink-0 text-brand" />
                  {title}
                </button>
              ))}
            </div>
          </Card>
        </aside>
      )}
      <section
        className="edtech-card fade-up stagger-2 order-1 min-w-0 overflow-hidden xl:order-2"
        aria-label="Yo‘lchi bilan suhbat"
      >
        <div className="flex flex-wrap items-center justify-between gap-2 border-b border-hairline bg-canvas/50 p-4 sm:px-6">
          <div className="flex items-center gap-3">
            <span className="grid size-11 shrink-0 place-items-center rounded-2xl bg-sand text-brand shadow-2xs">
              <Sparkles aria-hidden="true" className="size-5" />
            </span>
            <div>
              <h2 className="heading font-extrabold">Suhbat</h2>
              <p className="break-words text-xs font-medium text-slatefine">
                {isDemoMode ? 'Namunaviy javoblar' : topic ?? courseTitle ?? 'Umumiy ta’lim savollari'}
              </p>
            </div>
          </div>
          {messages.length > 0 && (
            <Button
              size="sm"
              variant="ghost"
              disabled={waiting}
              onClick={() => {
                keep([]);
                setFailure(null);
                input.current?.focus();
              }}
              leftIcon={<Plus aria-hidden="true" className="size-4" />}
            >
              Yangi suhbat
            </Button>
          )}
        </div>
        <div
          ref={stream}
          role="log"
          aria-label="Suhbat tarixi"
          aria-live="polite"
          className="min-h-64 max-h-[min(55dvh,34rem)] space-y-4 overflow-y-auto overscroll-contain p-4 sm:p-6"
        >
          {messages.length === 0 && (
            <div className="mx-auto max-w-lg py-8 text-center">
              <span className="mx-auto mb-3 grid size-14 place-items-center rounded-2xl bg-sand text-brand">
                <Sparkles aria-hidden="true" className="size-7" />
              </span>
              <p className="heading text-lg font-extrabold">Qaysi mavzuni ko‘rib chiqamiz?</p>
              <p className="mx-auto mt-2 max-w-sm text-sm text-slatefine">
                Tushunmagan joyingizni yozing. Yo‘lchi sizga keyingi qadamni topishda yordam beradi.
              </p>
              <div className={'mt-5 flex flex-wrap justify-center gap-2 ' + (compact ? '' : 'xl:hidden')}>
                {prompts.map(({ title }) => (
                  <Button key={title} size="sm" variant="outline" disabled={waiting} onClick={() => void send(title)}>
                    {title}
                  </Button>
                ))}
              </div>
            </div>
          )}
          {messages.map((message) => {
            const isStreamingThis = streamingState?.id === message.id;
            const visibleText = isStreamingThis
              ? message.text.slice(0, streamingState.visibleLength)
              : message.text;
            return (
              <YolchiMessageBubble
                key={message.id}
                id={message.id}
                sender={message.sender === 'user' ? 'user' : 'yolchi'}
                text={visibleText}
                timestamp={time.format(message.time)}
                isStreaming={isStreamingThis}
                feedback={message.feedback}
                onFeedback={message.sender === 'ai' ? feedback : undefined}
              />
            );
          })}
          <AnimatePresence>
            {waiting && <YolchiTypingIndicator />}
          </AnimatePresence>
          {failure && (
            <div role="alert" className="rounded-2xl border border-coral/20 bg-rose-50 p-3.5 text-sm text-coral">
              <p>{failure.error}</p>
              <Button
                className="mt-2"
                variant="outline"
                size="sm"
                onClick={() => void send(failure.prompt, true)}
                leftIcon={<RefreshCw aria-hidden="true" className="size-4" />}
              >
                Qayta urinish
              </Button>
            </div>
          )}
          <div ref={messagesEndRef} className="h-px w-full" aria-hidden="true" />
        </div>
        <form onSubmit={submit} className="space-y-2 border-t border-hairline bg-canvas/40 p-3.5 sm:p-5">
          <div className="flex items-end gap-2.5">
            <textarea
              ref={input}
              aria-label="Yo‘lchi AI ga savol yozing"
              rows={2}
              maxLength={4000}
              className="form-input min-w-0 flex-1 resize-y bg-white px-3.5 py-2.5"
              placeholder="Savolingizni yozing…"
              value={draft}
              onChange={(event) => setDraft(event.target.value)}
              onKeyDown={(event) => {
                if (event.key === 'Enter' && !event.shiftKey && !event.nativeEvent.isComposing) {
                  event.preventDefault();
                  void send(draft);
                }
              }}
            />
            <IconButton
              type="submit"
              label="Savolni yuborish"
              disabled={!draft.trim() || waiting}
              className="commonBtn !size-11 !p-0 text-white!"
            >
              <Send aria-hidden="true" className="size-5" />
            </IconButton>
          </div>
          <p className="text-xs text-slatefine">AI izohini darsdagi qoida va misollar bilan tekshiring.</p>
        </form>
      </section>
    </div>
  );
}
