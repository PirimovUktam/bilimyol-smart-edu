import React, { useState, useEffect } from 'react';
import { QuickDemoBar } from '@/presentation/components/QuickDemoBar';
import { Navbar } from '@/presentation/components/Navbar';
import { CourseSelectionView } from '@/features/course-selection/CourseSelectionView';
import { OnboardingView } from '@/features/onboarding/OnboardingView';
import { PlacementTestView } from '@/features/placement/PlacementTestView';
import { KnowledgeMapView } from '@/features/knowledge-map/KnowledgeMapView';
import { RoadmapView } from '@/features/roadmap/RoadmapView';
import { InteractiveLessonView } from '@/features/lesson/InteractiveLessonView';
import { DashboardView } from '@/features/dashboard/DashboardView';
import { LoginView } from '@/features/auth/LoginView';
import { RegisterView } from '@/features/auth/RegisterView';
import { ForgotPasswordView } from '@/features/auth/ForgotPasswordView';
import { ProfileView } from '@/features/profile/ProfileView';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { useRoadmapStore } from '@/app/store/useRoadmapStore';
import { useAuth } from '@/core/context/AuthContext';

export type AppView =
  | 'course-selection'
  | 'onboarding'
  | 'placement'
  | 'knowledge-map'
  | 'roadmap'
  | 'lesson'
  | 'dashboard'
  | 'login'
  | 'register'
  | 'forgot-password'
  | 'profile';

export const AppRouter: React.FC = () => {
  const [currentView, setCurrentView] = useState<AppView>('course-selection');
  const [activeLessonId, setActiveLessonId] = useState<string>('lesson_math_functions_01');

  const { loadCourses, activeCourse } = useCourseStore();
  const { loadProfile } = useLearnerStore();
  const { loadRoadmap } = useRoadmapStore();
  const { profile: authProfile } = useAuth();

  useEffect(() => {
    loadCourses();
    loadProfile();
  }, [loadCourses, loadProfile]);

  const handleSelectCourse = () => {
    setCurrentView('onboarding');
  };

  const handleOnboardingComplete = () => {
    setCurrentView('placement');
  };

  const handlePlacementComplete = () => {
    setCurrentView('knowledge-map');
  };

  const handleStartLesson = (lessonId: string) => {
    setActiveLessonId(lessonId);
    setCurrentView('lesson');
  };

  const handleLessonFinish = () => {
    setCurrentView('dashboard');
  };

  const handleResetDemo = async () => {
    if (activeCourse) {
      await loadRoadmap(activeCourse.id);
    }
    setCurrentView('course-selection');
  };

  const isAuthView = currentView === 'login' || currentView === 'register' || currentView === 'forgot-password';

  return (
    <div className="min-h-screen flex flex-col bg-slate-50 text-slate-900 font-sans">
      {/* Top Demo Fast Controls */}
      <QuickDemoBar onNavigate={(v) => setCurrentView(v as AppView)} currentView={currentView} />

      {/* Main Navigation (Hidden on standalone Auth screens) */}
      {!isAuthView && (
        <Navbar currentView={currentView} onNavigate={(v) => setCurrentView(v as AppView)} />
      )}

      {/* Main Content View Switcher */}
      <main className="flex-1">
        {currentView === 'login' && (
          <LoginView
            onSuccess={() => setCurrentView('dashboard')}
            onNavigateRegister={() => setCurrentView('register')}
            onNavigateForgotPassword={() => setCurrentView('forgot-password')}
          />
        )}

        {currentView === 'register' && (
          <RegisterView
            onSuccess={() => setCurrentView('course-selection')}
            onNavigateLogin={() => setCurrentView('login')}
          />
        )}

        {currentView === 'forgot-password' && (
          <ForgotPasswordView onNavigateLogin={() => setCurrentView('login')} />
        )}

        {currentView === 'profile' && (
          <ProfileView onSignOut={() => setCurrentView('login')} />
        )}

        {currentView === 'course-selection' && (
          <CourseSelectionView onSelectCourse={handleSelectCourse} />
        )}

        {currentView === 'onboarding' && (
          <OnboardingView
            onComplete={handleOnboardingComplete}
            onBack={() => setCurrentView('course-selection')}
          />
        )}

        {currentView === 'placement' && (
          <PlacementTestView onComplete={handlePlacementComplete} />
        )}

        {currentView === 'knowledge-map' && (
          <KnowledgeMapView onProceedToRoadmap={() => setCurrentView('roadmap')} />
        )}

        {currentView === 'roadmap' && (
          <RoadmapView
            onStartLesson={handleStartLesson}
            onOpenKnowledgeMap={() => setCurrentView('knowledge-map')}
          />
        )}

        {currentView === 'lesson' && (
          <InteractiveLessonView
            lessonId={activeLessonId}
            onFinish={handleLessonFinish}
            onBackToRoadmap={() => setCurrentView('roadmap')}
          />
        )}

        {currentView === 'dashboard' && (
          <DashboardView
            onContinueLesson={() => {
              const defaultLesson =
                activeCourse?.subject === 'mathematics'
                  ? 'lesson_math_functions_01'
                  : 'lesson_eng_listening_01';
              handleStartLesson(defaultLesson);
            }}
            onOpenRoadmap={() => setCurrentView('roadmap')}
            onOpenKnowledgeMap={() => setCurrentView('knowledge-map')}
            onResetDemo={handleResetDemo}
          />
        )}
      </main>

      {/* Footer */}
      <footer className="bg-white border-t border-slate-200 py-6 text-center text-xs text-slate-500 mt-auto">
        <div className="max-w-7xl mx-auto px-4 flex flex-col sm:flex-row items-center justify-between gap-2">
          <span>
            <strong>BilimYo‘l Smart Edu</strong> © 2026 — Umummilliy AI Xakaton 2026 (Qarshi bosqichi)
          </span>
          <span className="text-slate-400">
            {authProfile ? `Foydalanuvchi: ${authProfile.email}` : 'Checkpoint 2 • Supabase & Gemini AI'}
          </span>
        </div>
      </footer>
    </div>
  );
};
