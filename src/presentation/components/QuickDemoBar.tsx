import React from 'react';
import { RotateCcw, BookOpen, Headphones, Zap } from 'lucide-react';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { usePlacementStore } from '@/app/store/usePlacementStore';
import { useRoadmapStore } from '@/app/store/useRoadmapStore';
import { useLessonStore } from '@/app/store/useLessonStore';

interface QuickDemoBarProps {
  onNavigate: (view: string) => void;
  currentView?: string;
}

export const QuickDemoBar: React.FC<QuickDemoBarProps> = ({ onNavigate }) => {
  const { activeCourse, selectCourseById } = useCourseStore();
  const { resetAll } = useLearnerStore();
  const { resetPlacement } = usePlacementStore();
  const { loadRoadmap } = useRoadmapStore();
  const { resetLessonState } = useLessonStore();

  const handleReset = async () => {
    await resetAll();
    resetPlacement();
    resetLessonState();
    if (activeCourse) {
      await loadRoadmap(activeCourse.id);
    }
    onNavigate('course-selection');
  };

  const handleFastSwitch = async (courseId: string) => {
    await selectCourseById(courseId);
    await loadRoadmap(courseId);
    onNavigate('roadmap');
  };

  return (
    <header className="bg-slate-900 text-slate-200 text-xs border-b border-slate-800 py-1.5 px-4 sticky top-0 z-50 shadow-inner" aria-label="Demo boshqaruv paneli">
      <div className="max-w-7xl mx-auto flex flex-wrap items-center justify-between gap-2">
        <div className="flex items-center gap-2 font-medium">
          <span className="flex items-center gap-1.5 px-2 py-0.5 rounded bg-blue-500/20 text-blue-300 font-semibold border border-blue-500/30">
            <Zap className="w-3.5 h-3.5 text-blue-400 animate-pulse" />
            CHECKPOINT 1 DEMO
          </span>
          <span className="text-slate-400 hidden sm:inline">
            100% Offline Core Intelligence Loop • Zero Gemini Dependency
          </span>
        </div>

        <div className="flex items-center gap-2">
          <div className="flex items-center bg-slate-800 rounded-lg p-0.5 border border-slate-700">
            <button
              onClick={() => handleFastSwitch('course_math_01')}
              className={`flex items-center gap-1.5 px-2.5 py-1 rounded-md transition-all font-medium ${
                activeCourse?.id === 'course_math_01'
                  ? 'bg-blue-600 text-white shadow-xs'
                  : 'text-slate-300 hover:text-white'
              }`}
              title="Matematika (Funksiyalar 41% → 63%)"
            >
              <BookOpen className="w-3 h-3" />
              <span>Matematika (Asosiy)</span>
            </button>
            <button
              onClick={() => handleFastSwitch('course_eng_01')}
              className={`flex items-center gap-1.5 px-2.5 py-1 rounded-md transition-all font-medium ${
                activeCourse?.id === 'course_eng_01'
                  ? 'bg-teal-600 text-white shadow-xs'
                  : 'text-slate-300 hover:text-white'
              }`}
              title="Ingliz tili (Listening 43% → 65%)"
            >
              <Headphones className="w-3 h-3" />
              <span>Ingliz tili</span>
            </button>
          </div>

          <button
            onClick={handleReset}
            className="flex items-center gap-1 px-2.5 py-1 bg-slate-800 hover:bg-slate-700 text-amber-300 hover:text-amber-200 rounded-lg border border-amber-500/30 transition-all font-medium cursor-pointer"
            title="Barcha natijalarni tozalab, boshlang'ich holatga qaytarish"
          >
            <RotateCcw className="w-3 h-3" />
            <span>Demo Reset</span>
          </button>
        </div>
      </div>
    </header>
  );
};
