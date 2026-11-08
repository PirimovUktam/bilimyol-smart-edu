import { useState } from 'react';
import { Search } from 'lucide-react';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { hasStartedCourse } from '@/domain/personalization/learningStart';
import { PageHeader } from '@/presentation/components/PageHeader';
import { SubjectSelector } from './SubjectSelector';

export function CourseSelectionView({ onSelectCourse }: { onSelectCourse: (courseId: string) => void }) {
  const courses = useCourseStore((state) => state.courses);
  const activeCourseId = useCourseStore((state) => state.activeCourse?.id);
  const isLoading = useCourseStore((state) => state.isLoading);
  const error = useCourseStore((state) => state.error);
  const profile = useLearnerStore((state) => state.profile);
  const [query, setQuery] = useState('');
  const search = query.trim().toLocaleLowerCase('uz');
  const visible = courses.filter((course) => (course.title + ' ' + course.description).toLocaleLowerCase('uz').includes(search));
  const selected = courses.find((course) => course.id === activeCourseId);
  const completed = new Set(profile?.completedLessonIds);
  const completedByCourseId = Object.fromEntries(courses.map((course) => [
    course.id, course.lessons.filter((id) => completed.has(id)).length,
  ]));
  const progressByCourseId = Object.fromEntries(courses.filter((course) => course.lessons.length).map((course) => [
    course.id, 100 * completedByCourseId[course.id] / course.lessons.length,
  ]));

  const choose = async (courseId: string) => {
    try {
      await useCourseStore.getState().selectCourseById(courseId);
      if (useCourseStore.getState().activeCourse?.id === courseId) onSelectCourse(courseId);
    } catch {
      // The selector displays the store error and remains available for retry.
    }
  };

  return (
    <div className="learning-page space-y-6 sm:space-y-8">
      <PageHeader
        eyebrow="Fanlar katalogi"
        title="O‘zingizga mos fanni tanlang"
        highlightWord="fanni tanlang"
        description="Har bir fanning natijalari alohida saqlanadi. Istalgan vaqtda boshqa fanga o‘tib, keyin o‘qishni davom ettirishingiz mumkin."
      />
      {courses.length > 6 && (
        <label className="relative block max-w-sm">
          <span className="sr-only">Fanlarni qidirish</span>
          <Search aria-hidden="true" className="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-slatefine" />
          <input
            type="search"
            className="form-input pl-10 pr-4"
            placeholder="Fanlarni qidirish"
            value={query}
            onChange={(event) => setQuery(event.target.value)}
          />
        </label>
      )}
      <SubjectSelector
        courses={visible}
        selectedCourseId={selected && hasStartedCourse(selected, profile) ? selected.id : null}
        isLoading={isLoading}
        error={error}
        completedByCourseId={completedByCourseId}
        progressByCourseId={progressByCourseId}
        onSelect={choose}
        ariaLabel="Mavjud fanlar"
      />
    </div>
  );
}
