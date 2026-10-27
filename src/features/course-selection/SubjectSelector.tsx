import React from 'react';
import {
  BookOpen,
  Brain,
  Calculator,
  Check,
  Code,
  Code2,
  Headphones,
  type LucideIcon,
} from 'lucide-react';
import { Course } from '@/domain/entities/Course';

export type SubjectSelectorLayout = 'grid' | 'horizontal';

interface SubjectSelectorProps {
  courses: Course[];
  selectedCourseId?: string | null;
  isLoading?: boolean;
  error?: string | null;
  disabled?: boolean;
  layout?: SubjectSelectorLayout;
  progressByCourseId?: Record<string, number | null | undefined>;
  onSelect: (courseId: string) => void | Promise<void>;
  ariaLabel?: string;
  className?: string;
}

const courseIcons: Record<string, LucideIcon> = {
  BookOpen,
  Brain,
  Calculator,
  Code,
  Code2,
  Headphones,
};

const subjectLabels: Record<Course['subject'], string> = {
  mathematics: 'Matematika',
  english: 'Ingliz tili',
  it: 'IT va kodlash',
  logic: 'Mantiq',
  other: 'Boshqa fan',
};

const getCourseColor = (course: Course, key: 'primary' | 'secondary'): string => {
  if (key === 'primary') return course.primaryColorHex || course.primaryColor || '#2563EB';
  return course.secondaryColorHex || course.secondaryColor || '#4F46E5';
};

const getCourseIcon = (course: Course): LucideIcon => courseIcons[course.iconName] || BookOpen;

const getProgress = (progressByCourseId: SubjectSelectorProps['progressByCourseId'], courseId: string): number | null => {
  const value = progressByCourseId?.[courseId];
  if (typeof value !== 'number' || !Number.isFinite(value)) return null;
  return Math.max(0, Math.min(100, Math.round(value)));
};

const getSubjectLabel = (subject: Course['subject']): string => subjectLabels[subject];

const StatusMessage: React.FC<{
  tone: 'loading' | 'error' | 'empty';
  children: React.ReactNode;
}> = ({ tone, children }) => {
  const styles = {
    loading: 'border-blue-200 bg-blue-50/70 text-blue-800',
    error: 'border-coral/25 bg-rose-50/80 text-coral',
    empty: 'border-slate-200 bg-white text-slate-600',
  }[tone];

  return (
    <div
      className={`rounded-2xl border px-4 py-4 text-sm font-semibold ${styles}`}
      role={tone === 'error' ? 'alert' : 'status'}
      aria-live="polite"
    >
      {tone === 'loading' && (
        <span
          aria-hidden="true"
          className="mr-2 inline-block h-4 w-4 animate-spin rounded-full border-2 border-current border-t-transparent align-[-0.15em] motion-reduce:animate-none"
        />
      )}
      {children}
    </div>
  );
};

export const SubjectSelector: React.FC<SubjectSelectorProps> = ({
  courses,
  selectedCourseId = null,
  isLoading = false,
  error = null,
  disabled = false,
  layout = 'grid',
  progressByCourseId,
  onSelect,
  ariaLabel = 'Fan tanlash',
  className = '',
}) => {
  if (isLoading && courses.length === 0) {
    return <StatusMessage tone="loading">Fanlar yuklanmoqda...</StatusMessage>;
  }

  if (error && courses.length === 0) {
    return <StatusMessage tone="error">Fanlarni yuklashda xatolik: {error}</StatusMessage>;
  }

  if (courses.length === 0) {
    return <StatusMessage tone="empty">Hozircha tanlash uchun fanlar mavjud emas.</StatusMessage>;
  }

  const layoutClass = layout === 'horizontal'
    ? 'flex snap-x snap-mandatory gap-3 overflow-x-auto pb-2 motion-reduce:snap-none md:grid md:grid-cols-2 md:overflow-visible xl:grid-cols-4'
    : 'grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4';

  return (
    <div className={`space-y-3 ${className}`} aria-busy={isLoading}>
      {error && (
        <StatusMessage tone="error">Fanlarni yangilashda xatolik: {error}</StatusMessage>
      )}
      {isLoading && (
        <div className="text-xs font-semibold text-blue-700" role="status" aria-live="polite">
          Fan tanlovi yangilanmoqda...
        </div>
      )}

      <div className={layoutClass} role="group" aria-label={ariaLabel}>
        {courses.map((course, idx) => {
          const primaryColor = getCourseColor(course, 'primary');
          const Icon = getCourseIcon(course);
          const isSelected = course.id === selectedCourseId;
          const isInactive = course.isActive === false;
          const isDisabled = disabled || isLoading || isInactive;
          const progress = getProgress(progressByCourseId, course.id);
          const lessonCount = course.lessons?.length || 0;

          const subjectCode = {
            mathematics: 'MAT-01',
            english: 'ENG-02',
            it: 'DEV-03',
            logic: 'LOG-04',
            other: 'GEN-05',
          }[course.subject] || `SUB-0${idx + 1}`;

          return (
            <button
              key={course.id}
              type="button"
              disabled={isDisabled}
              aria-pressed={isSelected}
              aria-label={`${course.title} fanini tanlash${isSelected ? ' — tanlangan' : ''}`}
              className={`group relative flex min-w-[min(84vw,20rem)] snap-start flex-col justify-between overflow-hidden rounded-2xl border bg-white p-5 text-left transition-all duration-200 outline-none md:min-w-0 ${
                isSelected
                  ? 'border-[#10151f] ring-2 ring-[#10151f] shadow-md bg-gradient-to-b from-slate-50/50 to-white'
                  : 'border-[#e4ddce] hover:border-slate-400 hover:shadow-sm hover:-translate-y-0.5'
              } focus-visible:ring-2 focus-visible:ring-brand active:scale-[0.99] disabled:cursor-not-allowed disabled:opacity-60 motion-reduce:active:scale-100`}
              onClick={() => {
                void onSelect(course.id);
              }}
            >
              {/* Top editorial kicker bar */}
              <div className="flex items-center justify-between gap-2 pb-3 border-b border-[#f0ece3]">
                <div className="flex items-center gap-2">
                  <span className="font-mono text-[10px] font-bold text-slate-500 uppercase tracking-widest">
                    {subjectCode}
                  </span>
                  <span className="text-[10px] text-slate-300">•</span>
                  <span className="text-[11px] font-bold uppercase tracking-wider text-slate-600">
                    {getSubjectLabel(course.subject)}
                  </span>
                </div>
                {isSelected ? (
                  <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded bg-[#10151f] text-white font-mono text-[9px] font-bold uppercase tracking-wider shadow-2xs">
                    <Check className="h-3 w-3 text-path" aria-hidden="true" />
                    Tanlangan
                  </span>
                ) : isInactive ? (
                  <span className="font-mono text-[9px] text-slate-400 uppercase tracking-wider">
                    Faol emas
                  </span>
                ) : null}
              </div>

              {/* Main Subject Content */}
              <div className="pt-3.5 pb-2">
                <div className="flex items-start gap-3">
                  <div
                    className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl border border-[#e4ddce] bg-[#fbf9f4] transition-colors group-hover:border-path"
                    style={{ color: primaryColor }}
                  >
                    <Icon className="h-5 w-5" aria-hidden="true" />
                  </div>
                  <div>
                    <h3 className="font-display text-base sm:text-lg font-bold tracking-tight text-slate-900 group-hover:text-brand transition-colors">
                      {course.title}
                    </h3>
                    <p className="mt-1 text-xs text-slate-600 leading-relaxed font-medium line-clamp-2">
                      {course.description || 'Shaxsiy moslashuvchan darslar va bilim marshruti.'}
                    </p>
                  </div>
                </div>
              </div>

              {/* Footer Dossier Metadata */}
              <div className="pt-3 border-t border-[#f0ece3] mt-2 space-y-2">
                <div className="flex items-center justify-between text-xs">
                  <span className="inline-flex items-center gap-1.5 font-mono text-[11px] font-semibold text-slate-600">
                    <BookOpen className="h-3.5 w-3.5 text-slate-400" aria-hidden="true" />
                    {lessonCount > 0 ? `${lessonCount} dars` : 'Darslar mavjud'}
                  </span>
                  {progress !== null ? (
                    <span className="font-mono font-bold text-xs text-brand-dark">
                      {progress}%
                    </span>
                  ) : (
                    <span className="font-mono text-[10px] text-slate-400">
                      0% boshlanmagan
                    </span>
                  )}
                </div>

                {/* Micro progress line */}
                <div
                  className="h-1.5 w-full overflow-hidden rounded-full bg-[#f0ece3]"
                  role="progressbar"
                  aria-label={`${course.title} progressi`}
                  aria-valuemin={0}
                  aria-valuemax={100}
                  aria-valuenow={progress ?? 0}
                >
                  <div
                    className="h-full rounded-full bg-[#10151f] transition-all duration-300"
                    style={{ width: `${progress ?? 0}%` }}
                  />
                </div>
              </div>
            </button>
          );
        })}
      </div>
    </div>
  );
};
