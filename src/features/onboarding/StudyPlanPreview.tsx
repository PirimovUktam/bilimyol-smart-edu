import { ArrowRight, BookOpen, CalendarDays, ChevronDown, ClipboardCheck, Clock, Lock, Repeat2, Target } from 'lucide-react';
import { useId } from 'react';
import { useTranslation } from '@/core/locales/useTranslation';
import type { StudySession } from '@/domain/personalization/studyPlan';
import { Button } from '@/presentation/components/Button';

const icons = { lesson: BookOpen, review: Repeat2, checkpoint: ClipboardCheck, practice: Target };

export function StudyPlanPreview({ sessions, minutes, status, action, wide = false }: {
  sessions: StudySession[];
  minutes: number;
  status?: 'chooseLevel' | 'loading' | 'unavailable' | 'empty';
  action?: { label: string; run: () => void };
  wide?: boolean;
}) {
  const { language, t } = useTranslation();
  const titleId = useId();
  const sessionCard = (session: StudySession, index: number) => (
    <li key={index} className={index === 0 ? 'rounded-2xl border border-teal-200/35 bg-teal-100/10 p-3.5' : 'rounded-2xl border border-white/12 bg-white/5 p-3.5'}>
      <div className="mb-2 flex items-center justify-between gap-2 text-xs font-bold text-teal-100">
        <span>{t('studyPlan.session', { number: index + 1 })}</span>
        <span className="shrink-0 font-mono text-indigo-100">{t('studyPlan.duration', { minutes: session.minutes })}</span>
      </div>
      <div aria-hidden="true" className="mb-3 flex h-1.5 gap-0.5 overflow-hidden rounded-full bg-white/10">
        {session.items.map((item) => <span key={item.id} className={item.ready ? 'basis-0 rounded-full bg-teal-200' : 'basis-0 rounded-full bg-indigo-300/75'} style={{ flexGrow: item.estimatedMinutes }} />)}
        {session.minutes < minutes && <span className="basis-0" style={{ flexGrow: minutes - session.minutes }} />}
      </div>
      <ul className="grid gap-1.5">
        {session.items.map((item) => {
          const Icon = item.ready ? icons[item.kind] : Lock;
          return (
            <li key={item.id} className="flex items-start gap-2 text-sm leading-snug">
              <Icon aria-hidden="true" className={item.ready ? 'mt-0.5 size-3.5 shrink-0 text-teal-200' : 'mt-0.5 size-3.5 shrink-0 text-indigo-200'} />
              <span className="min-w-0 break-words">
                {language === 'ru' ? item.titleRu ?? item.title : item.title}
                <span className="sr-only">{` · ${t(item.ready ? `studyPlan.${item.kind}` : 'studyPlan.locked')}`}</span>
              </span>
            </li>
          );
        })}
      </ul>
      {session.minutes > minutes && <p className="mt-2 text-xs text-indigo-100">{t('studyPlan.overBudget')}</p>}
    </li>
  );

  return (
    <section aria-labelledby={titleId} className="relative isolate min-w-0 overflow-hidden rounded-3xl bg-[#171a38] p-5 text-white shadow-[0_20px_50px_-30px_#322275] sm:p-7">
      <div aria-hidden="true" className="pointer-events-none absolute inset-0 -z-10 bg-[radial-gradient(ellipse_at_top_right,#454293_0%,transparent_66%),linear-gradient(145deg,#24234b,#141730)]" />
      <div aria-hidden="true" className="pointer-events-none absolute -right-18 -top-24 -z-10 size-64 rounded-full border border-white/15 outline-1 outline-offset-18 outline-white/10" />
      <header className="mb-5 flex flex-wrap items-start justify-between gap-3">
        <div>
          <div className="mb-2 flex items-center gap-2 text-xs font-semibold tracking-wide text-indigo-200"><CalendarDays aria-hidden="true" className="size-4 text-teal-200" />{t(wide ? 'studyPlan.nextSessions' : 'studyPlan.preview')}</div>
          <h2 id={titleId} className="text-2xl font-extrabold tracking-tight sm:text-[1.7rem]">{t('studyPlan.title')}</h2>
        </div>
        <span className="inline-flex items-center gap-1.5 rounded-full bg-white/10 px-3 py-1.5 text-xs font-semibold text-indigo-50"><Clock aria-hidden="true" className="size-3.5 text-teal-200" />{t('studyPlan.dailyBudget', { minutes })}</span>
      </header>
      <div aria-busy={status === 'loading'}>
        {sessions.length === 0 ? (
          <p className="rounded-xl border border-dashed border-white/25 px-4 py-5 text-sm leading-relaxed text-indigo-100">{t(`studyPlan.${status ?? 'empty'}`)}</p>
        ) : (
          <>
            <p role="status" className="sr-only">{t('studyPlan.updated', { count: sessions.length, minutes: sessions[0].minutes })}</p>
            <ol className={wide ? 'grid gap-3 md:grid-cols-3' : ''}>
              {(wide ? sessions : sessions.slice(0, 1)).map(sessionCard)}
            </ol>
            {!wide && sessions.length > 1 && (
              <details className="group mt-2">
                <summary className="flex min-h-11 cursor-pointer list-none items-center justify-between gap-2 rounded-xl px-3 text-sm font-semibold text-indigo-100 hover:bg-white/10 focus-visible:outline-2 focus-visible:outline-teal-200">
                  {t('studyPlan.laterSessions', { count: sessions.length - 1 })}
                  <ChevronDown aria-hidden="true" className="size-4 group-open:rotate-180" />
                </summary>
                <ol start={2} className="grid gap-2.5 pt-1">{sessions.slice(1).map((session, index) => sessionCard(session, index + 1))}</ol>
              </details>
            )}
          </>
        )}
      </div>
      {sessions.some((session) => session.items.some((item) => !item.ready)) && (
        <p className="mt-4 flex items-start gap-1.5 text-xs leading-relaxed text-indigo-100"><Lock aria-hidden="true" className="mt-0.5 size-3 shrink-0" />{t('studyPlan.afterPrerequisite')}</p>
      )}
      {action && <Button onClick={action.run} variant="outline" className="mt-4 border-teal-200 bg-teal-100 text-[#142837] hover:border-white hover:bg-white" rightIcon={<ArrowRight aria-hidden="true" className="size-4" />}>{action.label}</Button>}
    </section>
  );
}
