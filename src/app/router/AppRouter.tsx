import React, { useState, useEffect, useCallback, useRef } from 'react';
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
import { resolveContinuationLessonId, decideCourseReconciliation } from '@/app/router/lessonResolution';
import { useMonitoringStore } from '@/app/store/useMonitoringStore';
import { useAuth } from '@/core/context/AuthContext';
import { activeLearningTracker } from '@/core/services/ActiveLearningTracker';
import { YolchiAIChatView } from '@/features/ai-tutor/YolchiAIChatView';
import { ProgressView } from '@/features/progress/ProgressView';
import { Card } from '@/presentation/components/Card';
import { Button } from '@/presentation/components/Button';
import { ShieldAlert } from 'lucide-react';
import { PitchShowcaseView } from '@/features/pitch/PitchShowcaseView';
import { DemoShowcaseView } from '@/features/pitch/DemoShowcaseView';

export type AppView =
  | 'pitch'
  | 'demo'
  | 'course-selection'
  | 'onboarding'
  | 'placement'
  | 'knowledge-map'
  | 'roadmap'
  | 'lesson'
  | 'dashboard'
  | 'ai-tutor'
  | 'progress'
  | 'login'
  | 'register'
  | 'forgot-password'
  | 'profile'
  | 'parent'
  | 'teacher'
  | 'admin';

const getInitialView = (): AppView => {
  if (typeof window !== 'undefined') {
    const params = new URLSearchParams(window.location.search);
    const viewParam = params.get('view') as AppView | null;
    if (viewParam) return viewParam;
    const path = window.location.pathname.toLowerCase();
    const hash = window.location.hash.toLowerCase();
    if (path === '/demo' || hash === '#demo') return 'demo';
    if (path === '/pitch' || hash === '#pitch') return 'pitch';
  }
  return 'course-selection';
};

export const AppRouter: React.FC = () => {
  const [currentView, setCurrentView] = useState<AppView>(getInitialView);
  const [activeLessonId, setActiveLessonId] = useState<string | null>(() => {
    if (typeof window !== 'undefined') {
      const params = new URLSearchParams(window.location.search);
      return params.get('lessonId');
    }
    return null;
  });

  useEffect(() => {
    (window as any).__navigateToView = (view: AppView, lessonId?: string) => {
      if (lessonId) setActiveLessonId(lessonId);
      setCurrentView(view);
    };
    return () => {
      delete (window as any).__navigateToView;
    };
  }, []);

  const { loadCourses, activeCourse, courses } = useCourseStore();
  const { loadProfile, profile: learnerProfile } = useLearnerStore();
  const { loadRoadmap } = useRoadmapStore();
  const { profile: authProfile } = useAuth();
  const monitoringRole = useMonitoringStore((s) => s.currentRole);

  const userRole = authProfile?.role || monitoringRole || 'student';

  useEffect(() => {
    loadCourses();
    loadProfile();
  }, [loadCourses, loadProfile]);

  // One-way reconcile: active course follows GENUINE profile changes only.
  // The initial profile value is a baseline (never reconciled) so it cannot
  // undo the localStorage-restored course, and the effect only reacts to the
  // profile value — a reconcile that writes back the same value can never
  // re-trigger itself (previously this looped math⇄english forever).
  const lastSeenCourseIdRef = useRef<string | null>(null);
  useEffect(() => {
    const selectedId = learnerProfile?.selectedCourseId;
    const decision = decideCourseReconciliation(
      lastSeenCourseIdRef.current,
      selectedId,
      courses.length
    );
    lastSeenCourseIdRef.current = decision.nextLastSeenId;
    if (!decision.shouldReconcile || !selectedId) return;
    const active = useCourseStore.getState().activeCourse;
    if (active && active.id === selectedId) return;
    if (useCourseStore.getState().courses.length === 0) return;
    void useCourseStore.getState().selectCourseById(selectedId);
  }, [learnerProfile?.selectedCourseId, courses.length]);

  useEffect(() => {
    // Start active learning tracker if user is student
    if (authProfile && userRole === 'student' && activeCourse) {
      activeLearningTracker.start(activeCourse.id, activeLessonId ?? undefined);
    }

    return () => {
      activeLearningTracker.stop();
    };
  }, [authProfile, userRole, activeCourse, activeLessonId]);

  const handleRoleRouting = useCallback((resolvedRole?: 'student' | 'parent' | 'teacher' | 'admin') => {
    const role = resolvedRole || authProfile?.role || monitoringRole || 'student';
    if (role === 'admin') {
      setCurrentView('admin');
    } else if (role === 'parent') {
      setCurrentView('parent');
    } else if (role === 'teacher') {
      setCurrentView('teacher');
    } else {
      setCurrentView('dashboard');
    }
  }, [authProfile?.role, monitoringRole]);

  // Synchronize browser URL bar with currentView
  useEffect(() => {
    if (typeof window === 'undefined') return;
    const path = window.location.pathname.toLowerCase();
    if (currentView === 'demo' && path !== '/demo') {
      window.history.pushState(null, '', '/demo');
    } else if (currentView === 'pitch' && path !== '/pitch') {
      window.history.pushState(null, '', '/pitch');
    } else if (currentView !== 'demo' && currentView !== 'pitch' && (path === '/demo' || path === '/pitch')) {
      window.history.pushState(null, '', '/');
    }
  }, [currentView]);

  // Handle browser back/forward and hash changes
  useEffect(() => {
    if (typeof window === 'undefined') return;
    const handlePopState = () => {
      const path = window.location.pathname.toLowerCase();
      const hash = window.location.hash.toLowerCase();
      if (path === '/demo' || hash === '#demo') {
        setCurrentView('demo');
      } else if (path === '/pitch' || hash === '#pitch') {
        setCurrentView('pitch');
      }
    };

    window.addEventListener('popstate', handlePopState);
    window.addEventListener('hashchange', handlePopState);
    return () => {
      window.removeEventListener('popstate', handlePopState);
      window.removeEventListener('hashchange', handlePopState);
    };
  }, []);

  // Adjust landing view when role is resolved (preserve pitch / demo if user explicitly opened them)
  useEffect(() => {
    if (currentView === 'pitch' || currentView === 'demo') {
      return;
    }
    const effectiveRole = authProfile?.role || monitoringRole;
    if (effectiveRole) {
      if (effectiveRole === 'admin' && currentView !== 'admin' && currentView !== 'profile') {
        setCurrentView('admin');
      } else if (effectiveRole === 'parent' && (currentView === 'course-selection' || currentView === 'login' || currentView === 'register' || currentView === 'dashboard')) {
        setCurrentView('parent');
      } else if (effectiveRole === 'teacher' && (currentView === 'course-selection' || currentView === 'login' || currentView === 'register' || currentView === 'dashboard')) {
        setCurrentView('teacher');
      }
    }
  }, [authProfile?.role, monitoringRole, currentView]);

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

  const handleContinueLesson = (lessonId?: string) => {
    const resolvedLessonId =
      lessonId || resolveContinuationLessonId(activeCourse, useRoadmapStore.getState().roadmap);

    if (resolvedLessonId) {
      handleStartLesson(resolvedLessonId);
    } else {
      setCurrentView('roadmap');
    }
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

  const isPitchOrDemo = currentView === 'pitch' || currentView === 'demo';
  const isAuthView = currentView === 'login' || currentView === 'register' || currentView === 'forgot-password';

  // Role Guard validation
  const isAccessDenied =
    (currentView === 'parent' && userRole !== 'parent') ||
    (currentView === 'teacher' && userRole !== 'teacher') ||
    (currentView === 'admin' && userRole !== 'admin');

  return (
    <div className="min-h-screen flex flex-col font-sans bg-slate-50 text-slate-900">
      {/* Main Navigation (Hidden on standalone Auth screens & Pitch/Demo presentations) */}
      {!isAuthView && !isPitchOrDemo && (
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
            {currentView === 'pitch' && (
              <PitchShowcaseView
                onNavigateDemo={() => setCurrentView('demo')}
                onNavigateApp={() => setCurrentView('dashboard')}
                onNavigateAiTutor={() => setCurrentView('ai-tutor')}
              />
            )}

            {currentView === 'demo' && (
              <DemoShowcaseView
                onNavigateCourses={() => setCurrentView('course-selection')}
                onNavigateDashboard={() => setCurrentView('dashboard')}
                onNavigateAiTutor={() => setCurrentView('ai-tutor')}
                onNavigatePitch={() => setCurrentView('pitch')}
              />
            )}

            {currentView === 'login' && (
              <LoginView
                onSuccess={handleRoleRouting}
                onNavigateRegister={() => setCurrentView('register')}
                onNavigateForgotPassword={() => setCurrentView('forgot-password')}
              />
            )}

            {currentView === 'register' && (
              <RegisterView
                onSuccess={handleRoleRouting}
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

            {currentView === 'lesson' && activeLessonId && (
              <InteractiveLessonView
                lessonId={activeLessonId}
                onFinish={handleLessonFinish}
                onBackToRoadmap={() => setCurrentView('roadmap')}
              />
            )}

            {currentView === 'lesson' && !activeLessonId && (
              <div className="max-w-md mx-auto px-4 py-16 text-center">
                <Card className="p-8 border-amber-200 bg-amber-50/50 shadow-lg">
                  <p className="text-sm text-slate-600 mb-4">
                    Dars topilmadi. Iltimos, yo‘nalishingizdan qayta tanlang.
                  </p>
                  <Button variant="primary" onClick={() => setCurrentView('roadmap')}>
                    Yo‘nalishga qaytish
                  </Button>
                </Card>
              </div>
            )}

            {currentView === 'dashboard' && (
              <DashboardView
                onContinueLesson={(lessonId?: string) => handleContinueLesson(lessonId)}
                onOpenRoadmap={() => setCurrentView('roadmap')}
                onOpenKnowledgeMap={() => setCurrentView('knowledge-map')}
                onOpenAITutor={() => setCurrentView('ai-tutor')}
                onOpenProgress={() => setCurrentView('progress')}
                onOpenProfile={() => setCurrentView('profile')}
                onOpenPitch={() => setCurrentView('pitch')}
                onOpenDemo={() => setCurrentView('demo')}
                onResetDemo={handleResetDemo}
              />
            )}

            {currentView === 'ai-tutor' && (
              <YolchiAIChatView
                onStartLesson={() => handleContinueLesson()}
              />
            )}

            {currentView === 'progress' && (
              <ProgressView
                onContinueLesson={() => handleContinueLesson()}
                onOpenRoadmap={() => setCurrentView('roadmap')}
                onOpenKnowledgeMap={() => setCurrentView('knowledge-map')}
              />
            )}

            {currentView === 'parent' && <ParentDashboardView />}

            {currentView === 'teacher' && <TeacherDashboardView />}

            {currentView === 'admin' && <AdminDashboardView />}
          </>
        )}
      </main>

      {/* Footer (Hidden on Pitch/Demo pages which have their own rich pitch footer) */}
      {!isPitchOrDemo && (
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
      )}
    </div>
  );
};
