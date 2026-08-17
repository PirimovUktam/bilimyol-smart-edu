import React, { useState, useEffect } from 'react';
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
import { ParentDashboardView } from '@/features/parent/ParentDashboardView';
import { TeacherDashboardView } from '@/features/teacher/TeacherDashboardView';
import { AdminDashboardView } from '@/features/admin/AdminDashboardView';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { useRoadmapStore } from '@/app/store/useRoadmapStore';
import { useAuth } from '@/core/context/AuthContext';
import { activeLearningTracker } from '@/core/services/ActiveLearningTracker';
import { Card } from '@/presentation/components/Card';
import { Button } from '@/presentation/components/Button';
import { ShieldAlert } from 'lucide-react';

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
  | 'profile'
  | 'parent'
  | 'teacher'
  | 'admin';

export const AppRouter: React.FC = () => {
  const [currentView, setCurrentView] = useState<AppView>('course-selection');
  const [activeLessonId, setActiveLessonId] = useState<string>('lesson_math_functions_01');

  const { loadCourses, activeCourse } = useCourseStore();
  const { loadProfile } = useLearnerStore();
  const { loadRoadmap } = useRoadmapStore();
  const { profile: authProfile } = useAuth();

  const userRole = authProfile?.role || 'student';

  useEffect(() => {
    loadCourses();
    loadProfile();

    // Start active learning tracker if user is student
    if (authProfile && userRole === 'student') {
      activeLearningTracker.start(activeCourse?.id || 'course_math_01', activeLessonId);
    }

    return () => {
      activeLearningTracker.stop();
    };
  }, [loadCourses, loadProfile, authProfile, userRole, activeCourse, activeLessonId]);

  // Adjust landing view when role is resolved
  useEffect(() => {
    if (authProfile) {
      if (authProfile.role === 'admin' && currentView === 'course-selection') {
        setCurrentView('admin');
      } else if (authProfile.role === 'parent' && currentView === 'course-selection') {
        setCurrentView('parent');
      } else if (authProfile.role === 'teacher' && currentView === 'course-selection') {
        setCurrentView('teacher');
      }
    }
  }, [authProfile, currentView]);

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
    activeLearningTracker.setLesson(lessonId);
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

  // Role Guard validation
  const isAccessDenied =
    (currentView === 'parent' && userRole !== 'parent') ||
    (currentView === 'teacher' && userRole !== 'teacher') ||
    (currentView === 'admin' && userRole !== 'admin');

  return (
    <div className="min-h-screen flex flex-col bg-slate-50 text-slate-900 font-sans">
      {/* Main Navigation (Hidden on standalone Auth screens) */}
      {!isAuthView && (
        <Navbar currentView={currentView} onNavigate={(v) => setCurrentView(v as AppView)} />
      )}

      {/* Main Content View Switcher */}
      <main className="flex-1">
        {/* Access Denied Guard UI */}
        {isAccessDenied ? (
          <div className="max-w-md mx-auto px-4 py-16 text-center">
            <Card className="p-8 border-rose-200 bg-rose-50/50 shadow-lg">
              <div className="w-14 h-14 rounded-2xl bg-rose-100 text-rose-600 flex items-center justify-center mx-auto mb-4">
                <ShieldAlert className="w-8 h-8" />
              </div>
              <h2 className="text-xl font-bold text-slate-900 mb-2">Ruxsat Cheklangan</h2>
              <p className="text-sm text-slate-600 mb-6">
                Ushbu panelga kirish faqat {currentView === 'parent' ? 'ota-onalar' : currentView === 'teacher' ? 'o‘qituvchilar' : 'administratorlar'} uchun ruxsat etilgan.
                Sizning joriy hisob turingiz: <strong>{userRole === 'student' ? 'O‘quvchi' : userRole === 'parent' ? 'Ota-ona' : userRole === 'teacher' ? 'O‘qituvchi' : 'Administrator'}</strong>.
              </p>
              <Button
                variant="primary"
                onClick={() => setCurrentView(userRole === 'admin' ? 'admin' : userRole === 'parent' ? 'parent' : userRole === 'teacher' ? 'teacher' : 'dashboard')}
              >
                O‘z panelingizga qaytish
              </Button>
            </Card>
          </div>
        ) : (
          <>
            {currentView === 'login' && (
              <LoginView
                onSuccess={() => setCurrentView(userRole === 'admin' ? 'admin' : userRole === 'parent' ? 'parent' : userRole === 'teacher' ? 'teacher' : 'dashboard')}
                onNavigateRegister={() => setCurrentView('register')}
                onNavigateForgotPassword={() => setCurrentView('forgot-password')}
              />
            )}

            {currentView === 'register' && (
              <RegisterView
                onSuccess={() => setCurrentView(userRole === 'admin' ? 'admin' : userRole === 'parent' ? 'parent' : userRole === 'teacher' ? 'teacher' : 'course-selection')}
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

            {currentView === 'parent' && <ParentDashboardView />}

            {currentView === 'teacher' && <TeacherDashboardView />}

            {currentView === 'admin' && <AdminDashboardView />}
          </>
        )}
      </main>

      {/* Footer */}
      <footer className="bg-white border-t border-slate-200 py-6 text-center text-xs text-slate-500 mt-auto">
        <div className="max-w-7xl mx-auto px-4 flex flex-col sm:flex-row items-center justify-between gap-2">
          <span>
            <strong>BilimYo‘l Smart Edu</strong> © 2026 — O‘quvchi, Ota-ona, O‘qituvchi va Ma’muriyat Yagona Ekotizimi
          </span>
          <span className="text-slate-400">
            {authProfile ? `Hisob: ${authProfile.email} (${userRole})` : 'Yo‘lchi AI • Real Adaptive Learning'}
          </span>
        </div>
      </footer>
    </div>
  );
};
