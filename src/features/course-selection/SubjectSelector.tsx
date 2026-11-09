import { ArrowRight, BookOpen, Brain, Calculator, Check, Code2, Headphones, Zap, type LucideIcon } from 'lucide-react';
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
  mathematics: { icon: Calculator, tone: 'bg-gradient-to-br from-indigo-500/30 to-purple-600/30 text-indigo-200 ring-1 ring-purple-400/40', category: 'Aniq fanlar' },
  english: { icon: Headphones, tone: 'bg-gradient-to-br from-pink-500/30 to-rose-600/30 text-pink-200 ring-1 ring-pink-400/40', category: 'Xorijiy til' },
  it: { icon: Code2, tone: 'bg-gradient-to-br from-cyan-500/30 to-blue-600/30 text-cyan-200 ring-1 ring-cyan-400/40', category: 'Dasturlash' },
  logic: { icon: Brain, tone: 'bg-gradient-to-br from-amber-500/30 to-orange-600/30 text-amber-200 ring-1 ring-amber-400/40', category: 'Tafakkur' },
  other: { icon: BookOpen, tone: 'bg-gradient-to-br from-emerald-500/30 to-teal-600/30 text-emerald-200 ring-1 ring-emerald-400/40', category: 'Umumiy kurs' },
};

export function SubjectSelector({
  courses, selectedCourseId, isLoading, error, disabled, layout = 'grid',
  progressByCourseId, completedByCourseId, onSelect, ariaLabel = 'Fan tanlash', className = '',
}: SubjectSelectorProps) {
  if (isLoading && courses.length === 0) return <SectionState kind="loading" title="Fanlar yuklanmoqda…" />;
  if (error && courses.length === 0) return <SectionState kind="error" title="Fanlar yuklanmadi" description={error} />;
  if (courses.length === 0) return <SectionState title="Fanlar topilmadi" />;

  return (
    <div className={'space-y-4 ' + className} aria-busy={Boolean(isLoading)}>
      {error && (
        <p role="alert" className="rounded-2xl border border-coral/25 bg-rose-50 p-3.5 text-sm font-semibold text-coral">
          {error}
        </p>
      )}
      {isLoading && <p role="status" className="text-xs font-semibold text-brand">Fan tanlovi yangilanmoqda…</p>}
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
              aria-label={course.title + ' fanini tanlash' + (selected ? ' — tanlangan' : '')}
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
                    <span>Tanlangan</span>
                  </span>
                ) : (
                  <span className="highlight !py-1 !px-2.5 !text-[11px]">
                    {category}
                  </span>
                )}
              </span>

              {/* (b) Middle: Title, 2-line Description & Visual Progress */}
              <span className="my-4 block w-full">
                <span className="heading block break-words text-lg font-extrabold leading-snug text-ink group-hover:text-cyan-300 transition-colors">
                  {course.title}
                </span>
                <span className="mt-1.5 block line-clamp-2 text-xs leading-relaxed text-slatefine">
                  {course.description}
                </span>

                <span className="mt-4 block w-full">
                  <span className="mb-1.5 flex items-center justify-between text-[11px] font-bold text-slatefine">
                    <span>O‘zlashtirish</span>
                    <span className="font-mono-num text-cyan-300">{pct}%</span>
                  </span>
                  <Progress
                    value={pct}
                    size="sm"
                    tone={pct >= 80 ? 'emerald' : 'indigo'}
                    ariaLabel={course.title + ' darslari bajarilishi'}
                  />
                </span>
              </span>

              {/* (c) Bottom: Meta-data (Lessons, XP) & .commonBtn Action */}
              <span className="mt-auto flex w-full items-center justify-between gap-2 border-t border-purple-400/20 pt-3.5">
                <span className="flex flex-col text-[11px] font-bold text-slatefine">
                  <span>
                    {lessons > 0
                      ? completed == null
                        ? lessons + ' dars'
                        : completed + ' / ' + lessons + ' dars tugallangan'
                      : 'Darslar soni ko‘rsatilmagan'}
                  </span>
                  <span className="mt-0.5 inline-flex items-center gap-1 text-[10px] text-amber-300">
                    <Zap aria-hidden="true" className="size-3" />
                    +{Math.max(1, lessons) * 20} XP
                  </span>
                </span>
                <span className="commonBtn !px-3.5 !py-2 text-xs">
                  <span>{selected ? 'Davom etish' : 'Tanlash'}</span>
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
