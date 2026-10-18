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
    error: 'border-rose-200 bg-rose-50/80 text-rose-800',
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
        {courses.map((course) => {
          const primaryColor = getCourseColor(course, 'primary');
          const secondaryColor = getCourseColor(course, 'secondary');
          const Icon = getCourseIcon(course);
          const isSelected = course.id === selectedCourseId;
          const isInactive = course.isActive === false;
          const isDisabled = disabled || isLoading || isInactive;
          const progress = getProgress(progressByCourseId, course.id);
          const lessonCount = course.lessons?.length || 0;

          return (
            <button
              key={course.id}
              type="button"
              disabled={isDisabled}
              aria-pressed={isSelected}
              aria-label={`${course.title} fanini tanlash${isSelected ? ' — tanlangan' : ''}`}
              className={`group relative flex min-w-[min(84vw,20rem)] snap-start flex-col justify-between overflow-hidden rounded-3xl border-2 bg-white p-5 text-left shadow-sm outline-none motion-safe:transition-[transform,box-shadow,border-color,background-color] motion-safe:duration-200 motion-safe:ease-out motion-reduce:transition-none md:min-w-0 ${
                isSelected
                  ? 'ring-4 ring-blue-100'
                  : 'border-slate-200 hover:-translate-y-0.5 hover:border-blue-300 hover:shadow-lg'
              } focus-visible:ring-4 focus-visible:ring-blue-200 focus-visible:ring-offset-2 active:scale-[0.99] disabled:cursor-not-allowed disabled:opacity-60 disabled:hover:translate-y-0 disabled:hover:border-slate-200 disabled:hover:shadow-sm motion-reduce:active:scale-100`}
              style={{
                borderColor: isSelected ? primaryColor : undefined,
                backgroundImage: isSelected
                  ? `linear-gradient(135deg, ${primaryColor}12, ${secondaryColor}08)`
                  : undefined,
              }}
              onClick={() => {
                void onSelect(course.id);
              }}
            >
              <span
                aria-hidden="true"
                className="absolute inset-x-0 top-0 h-1"
                style={{ backgroundColor: primaryColor }}
              />

              <span className="flex items-start justify-between gap-3">
                <span
                  className="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl border"
                  style={{
                    color: primaryColor,
                    backgroundColor: `${primaryColor}14`,
                    borderColor: `${primaryColor}40`,
                  }}
                >
                  <Icon className="h-6 w-6" aria-hidden="true" />
                </span>
                <span className="flex items-center gap-1.5 text-right text-[10px] font-extrabold uppercase tracking-wide text-slate-500">
                  {isSelected && <Check className="h-3.5 w-3.5 text-blue-600" aria-hidden="true" />}
                  {isInactive ? 'Faol emas' : isSelected ? 'Tanlangan' : getSubjectLabel(course.subject)}
                </span>
              </span>

              <span className="mt-5 block">
                <span className="block text-lg font-black tracking-tight text-slate-950 transition-colors motion-reduce:transition-none group-hover:text-blue-700">
                  {course.title}
                </span>
                <span className="mt-2 block min-h-10 text-sm font-medium leading-5 text-slate-600">
                  {course.description || 'Bu kurs uchun tavsif mavjud emas.'}
                </span>
              </span>

              <span className="mt-5 flex flex-wrap items-center gap-x-3 gap-y-2 border-t border-slate-100 pt-4 text-xs font-bold text-slate-500">
                <span className="inline-flex items-center gap-1.5">
                  <BookOpen className="h-3.5 w-3.5 text-blue-600" aria-hidden="true" />
                  {lessonCount > 0 ? `${lessonCount} ta dars` : 'Darslar haqida ma’lumot yo‘q'}
                </span>
                {progress !== null && (
                  <span className="inline-flex items-center gap-1.5 text-indigo-700">
                    <span
                      className="h-1.5 w-1.5 rounded-full bg-indigo-500"
                      aria-hidden="true"
                    />
                    {progress}% progress
                  </span>
                )}
              </span>

              {progress !== null && (
                <span
                  className="mt-3 block h-1.5 overflow-hidden rounded-full bg-slate-100"
                  role="progressbar"
                  aria-label={`${course.title} progressi`}
                  aria-valuemin={0}
                  aria-valuemax={100}
                  aria-valuenow={progress}
                >
                  <span
                    className="block h-full rounded-full bg-gradient-to-r from-blue-600 to-indigo-500 motion-safe:transition-[width] motion-safe:duration-300 motion-reduce:transition-none"
                    style={{ width: `${progress}%` }}
                  />
                </span>
              )}
            </button>
          );
        })}
      </div>
    </div>
  );
};
