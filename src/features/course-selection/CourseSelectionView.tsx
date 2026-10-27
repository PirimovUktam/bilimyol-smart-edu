import React from 'react';
import { ShieldCheck, Sparkles } from 'lucide-react';
import { useCourseStore } from '@/app/store/useCourseStore';
import { SubjectSelector } from './SubjectSelector';

interface CourseSelectionViewProps {
  onSelectCourse: (courseId: string) => void;
}

export const CourseSelectionView: React.FC<CourseSelectionViewProps> = ({ onSelectCourse }) => {
  const {
    courses,
    activeCourse,
    selectCourseById,
    isLoading,
    error,
  } = useCourseStore();

  const handleChoose = async (courseId: string) => {
    try {
      await selectCourseById(courseId);
      onSelectCourse(courseId);
    } catch {
      // The store exposes the canonical error to the selector; keep the view mounted
      // so the learner can choose another loaded course or retry.
    }
  };

  return (
    <div className="min-h-[calc(100vh-120px)] bg-gradient-to-b from-blue-50/60 via-white to-indigo-50/40 px-4 py-10 sm:px-6 sm:py-14">
      <div className="mx-auto flex w-full max-w-6xl flex-col items-center">
        <header className="mb-10 max-w-3xl space-y-4 text-center">
          <div className="inline-flex items-center gap-2 rounded-full border border-blue-200/80 bg-white px-3 py-1 text-xs font-bold text-blue-700 shadow-sm">
            <Sparkles className="h-3.5 w-3.5" aria-hidden="true" />
            <span>{courses.length > 0 ? `${courses.length} ta mavjud kurs` : 'Kurslar katalogi'}</span>
          </div>
          <h1 className="text-3xl font-black tracking-tight text-slate-950 sm:text-4xl md:text-5xl">
            O‘rganishni istagan fanni tanlang
          </h1>
          <p className="mx-auto max-w-2xl text-base font-medium leading-7 text-slate-600 sm:text-lg">
            Sizga mavjud kurslardan birini tanlang. BilimYo‘l tanlovingiz asosida individual o‘quv yo‘lini tayyorlaydi.
          </p>
        </header>

        <section className="w-full" aria-labelledby="course-selection-heading">
          <h2 id="course-selection-heading" className="sr-only">Mavjud kurslar</h2>
          <SubjectSelector
            courses={courses}
            selectedCourseId={activeCourse?.id}
            isLoading={isLoading}
            error={error}
            onSelect={handleChoose}
            ariaLabel="Mavjud kurslar"
            className="w-full"
          />
        </section>

        <div className="mt-12 flex max-w-xl items-center gap-2 text-center text-xs font-semibold text-slate-500">
          <ShieldCheck className="h-4 w-4 shrink-0 text-mint" aria-hidden="true" />
          <span>Natijalar va o‘quv yo‘li faqat tanlangan kursning mavjud ma’lumotlari asosida hisoblanadi.</span>
        </div>
      </div>
    </div>
  );
};
