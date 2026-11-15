import { translate as t } from '@/core/locales/useTranslation';
import { useTranslation } from '@/core/locales/useTranslation';
import { ArrowRight, BookOpen, Brain, Calculator, Check, Code2, Headphones, type LucideIcon } from 'lucide-react';
import type { Course } from '@/domain/entities/Course';
import { Progress } from '@/presentation/components/Progress';
import { SectionState } from '@/presentation/components/SectionState';

export type SubjectSelectorLayout = 'grid' | 'compact';

interface SubjectSelectorProps {
  courses: Course[];
  selectedCourseId?: string | null;
  isLoading?: boolean;
  error?: string | null;
  disabled?: boolean;
  layout?: SubjectSelectorLayout;
  progressByCourseId?: Record<string, number | null | undefined>;
  completedByCourseId?: Record<string, number>;
  onSelect: (courseId: string) => void | Promise<void>;
  ariaLabel?: string;
  className?: string;
}

const subjects: Record<Course['subject'], { icon: LucideIcon; tone: string; category: string }> = {
  mathematics: { icon: Calculator, tone: 'bg-gradient-to-br from-indigo-500/30 to-purple-600/30 text-indigo-200 ring-1 ring-purple-400/40', get category() { return t('courses.science'); } },
  english: { icon: Headphones, tone: 'bg-gradient-to-br from-pink-500/30 to-rose-600/30 text-pink-200 ring-1 ring-pink-400/40', get category() { return t('courses.foreign'); } },
  it: { icon: Code2, tone: 'bg-gradient-to-br from-cyan-500/30 to-blue-600/30 text-cyan-200 ring-1 ring-cyan-400/40', get category() { return t('shell.programming'); } },
  logic: { icon: Brain, tone: 'bg-gradient-to-br from-amber-500/30 to-orange-600/30 text-amber-200 ring-1 ring-amber-400/40', get category() { return t('shell.thinking'); } },
  other: { icon: BookOpen, tone: 'bg-gradient-to-br from-emerald-500/30 to-teal-600/30 text-emerald-200 ring-1 ring-emerald-400/40', get category() { return t('courses.general'); } },
};

export function SubjectSelector({
  courses, selectedCourseId, isLoading, error, disabled, layout = 'grid',
  progressByCourseId, completedByCourseId, onSelect, ariaLabel = t('courses.choose'), className = '',
}: SubjectSelectorProps) {
  const { t } = useTranslation();
  if (isLoading && courses.length === 0) return <SectionState kind="loading" title={t('courses.loading')} />;
  if (error && courses.length === 0) return <SectionState kind="error" title={t('courses.loadFailed')} description={error} />;
  if (courses.length === 0) return <SectionState title={t('courses.empty')} />;

  return (
    <div className={'space-y-4 ' + className} aria-busy={Boolean(isLoading)}>
      {error && (
        <p role="alert" className="rounded-2xl border border-coral/25 bg-rose-50 p-3.5 text-sm font-semibold text-coral">
          {error}
        </p>
      )}
      {isLoading && <p role="status" className="text-xs font-semibold text-brand">{t('courses.switching')}</p>}
      <div
        role="group"
        aria-label={ariaLabel}
        className={
          layout === 'compact'
            ? 'grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4'
            : 'grid grid-cols-1 gap-5 sm:grid-cols-2 xl:grid-cols-4'
        }
      >
        {courses.map((course, index) => {
          const { icon: Icon, tone, category } = subjects[course.subject] ?? subjects.other;
          const selected = course.id === selectedCourseId;
          const progress = progressByCourseId?.[course.id];
          const completed = completedByCourseId?.[course.id];
          const lessons = course.lessons.length;
          const pct = progress != null ? Math.round(progress) : 0;

          return (
            <button
              key={course.id}
              type="button"
              disabled={Boolean(disabled || isLoading || course.isActive === false)}
              aria-pressed={selected}
              aria-label={t('dynamic.selectSubject', { title: course.title }) + (selected ? t('dynamic.selectedSuffix') : '')}
              onClick={() => void onSelect(course.id)}
              style={{ animationDelay: `${index * 90}ms` }}
              className={
                'fade-up edtech-card-hover group flex min-w-0 cursor-pointer flex-col justify-between p-5 text-left disabled:cursor-not-allowed disabled:opacity-65 ' +
                (selected ? 'border-purple-400! bg-purple-500/15! ring-2 ring-purple-400/40' : '')
              }
            >
              {/* (a) Top: Colored Icon Container + Category/Selection Badge */}
              <span className="flex w-full items-center justify-between gap-2">
                <span className={'grid size-12 shrink-0 place-items-center rounded-2xl shadow-2xs transition-transform duration-200 group-hover:scale-105 ' + tone}>
                  <Icon aria-hidden="true" className="size-6" />
                </span>
                {selected ? (
                  <span className="inline-flex items-center gap-1 rounded-full bg-emerald-500/20 border border-emerald-400/40 px-3 py-1 text-[11px] font-bold text-emerald-300">
                    <Check aria-hidden="true" className="size-3.5" />
                    <span>{t('courses.selected')}</span>
                  </span>
                ) : (
                  <span className="highlight !py-1 !px-2.5 !text-[11px]">
                    {category}
                  </span>
                )}
              </span>

              {/* (b) Middle: Title, 2-line Description & Visual Progress */}
              <span className="my-4 block w-full">
                <span className="heading block break-words text-lg font-extrabold leading-snug text-ink group-hover:text-path transition-colors">
                  {course.title}
                </span>
                <span className="mt-1.5 block line-clamp-2 text-xs leading-relaxed text-slatefine">
                  {course.description}
                </span>

                <span className="mt-4 block w-full">
                  <span className="mb-1.5 flex items-center justify-between text-[11px] font-bold text-slatefine">
                    <span>{t('courses.mastery')}</span>
                    <span className="font-mono-num text-path">{pct}%</span>
                  </span>
                  <Progress
                    value={pct}
                    size="sm"
                    tone={pct >= 80 ? 'emerald' : 'indigo'}
                    ariaLabel={t('dynamic.lessonsProgress', { title: course.title })}
                  />
                </span>
              </span>

              {/* (c) Bottom: Meta-data (Lessons, XP) & .commonBtn Action */}
              <span className="mt-auto flex w-full items-center justify-between gap-2 border-t border-hairline pt-3.5">
                <span className="flex flex-col text-[11px] font-bold text-slatefine">
                  <span>
                    {lessons > 0
                      ? completed == null
                        ? t('dynamic.lessonCount', { count: lessons })
                        : t('dynamic.lessonCompletion', { done: completed, total: lessons })
                      : t('courses.noLessonCount')}
                  </span>
                </span>
                <span className="commonBtn !px-3.5 !py-2 text-xs">
                  <span>{selected ? t('courses.continue') : t('dynamic.select')}</span>
                  <ArrowRight aria-hidden="true" className="size-3.5 transition-transform group-hover:translate-x-0.5" />
                </span>
              </span>
            </button>
          );
        })}
      </div>
    </div>
  );
}
