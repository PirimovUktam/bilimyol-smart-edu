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
import { AdminDashboardView } from '@/features/admin/AdminDashboardView';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { useRoadmapStore } from '@/app/store/useRoadmapStore';
import { resolveContinuationLessonId, decideCourseReconciliation } from '@/app/router/lessonResolution';
import { useAuth } from '@/core/context/AuthContext';
import { isSupabaseConfigured } from '@/core/config/supabase';
import { isProtectedAuthReady } from '@/core/utils/authGuards';
import { activeLearningTracker } from '@/core/services/ActiveLearningTracker';
import { YolchiAIChatView } from '@/features/ai-tutor/YolchiAIChatView';
import { ProgressView } from '@/features/progress/ProgressView';
import { Card } from '@/presentation/components/Card';
import { Button } from '@/presentation/components/Button';
import { ShieldAlert } from 'lucide-react';
import { PitchShowcaseView } from '@/features/pitch/PitchShowcaseView';
import { DemoShowcaseView } from '@/features/pitch/DemoShowcaseView';

import { BilimYolLogo } from '@/presentation/components/BilimYolLogo';

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
  | 'admin';

const getInitialView = (): AppView => {
  if (typeof window !== 'undefined') {
    const params = new URLSearchParams(window.location.search);
    const viewParam = params.get('view');
    const validViews: AppView[] = [
      'pitch',
      'demo',
      'course-selection',
      'onboarding',
      'placement',
      'knowledge-map',
      'roadmap',
      'lesson',
      'dashboard',
      'ai-tutor',
      'progress',
      'login',
      'register',
      'forgot-password',
      'profile',
      'admin',
    ];
    if (viewParam && validViews.includes(viewParam as AppView)) return viewParam as AppView;
    const path = window.location.pathname.toLowerCase();
    const hash = window.location.hash.toLowerCase();
    if (path === '/demo' || hash === '#demo') return 'demo';
    if (path === '/pitch' || hash === '#pitch') return 'pitch';
    if (path === '/register' || hash === '#register') return 'register';
    if (path === '/forgot-password' || hash === '#forgot-password') return 'forgot-password';
    if (path === '/login' || hash === '#login') return 'login';
  }
  return 'login';
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

  const { loadCourses, activeCourse, courses, isLoading: isCourseLoading } = useCourseStore();
  const { loadProfile, profile: learnerProfile } = useLearnerStore();
  const { loadRoadmap } = useRoadmapStore();
  const { profile: authProfile, session, isLoading: isAuthLoading } = useAuth();
  const hasUsableAuth = isProtectedAuthReady(
    isSupabaseConfigured,
    import.meta.env.PROD,
    session,
    authProfile,
  );

  const userRole = authProfile?.role || 'student';

  useEffect(() => {
    if (!hasUsableAuth) return;
    void loadCourses().catch(() => undefined);
    void loadProfile().catch(() => undefined);
  }, [hasUsableAuth, loadCourses, loadProfile]);

  // One-way reconcile: the server profile is allowed to replace a local
  // storage restore on startup, and later genuine profile changes follow the
  // same path. A selection writes the same profile value back, so it cannot
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
    if (!decision.shouldReconcile || !selectedId || isCourseLoading) return;
    const active = useCourseStore.getState().activeCourse;
    if (active && active.id === selectedId) return;
    if (useCourseStore.getState().courses.length === 0) return;
    void useCourseStore.getState().selectCourseById(selectedId).catch(() => undefined);
  }, [learnerProfile?.selectedCourseId, courses.length, isCourseLoading, activeCourse?.id]);

  // A lesson and roadmap belong to one active course. The course store clears
  // their backing stores on a successful switch; the router must also discard
  // the route-local lesson id so a stale URL cannot render foreign content.
  const previousActiveCourseIdRef = useRef<string | null | undefined>(undefined);
  useEffect(() => {
    const currentCourseId = activeCourse?.id || null;
    const previousCourseId = previousActiveCourseIdRef.current;
    if (previousCourseId !== undefined && previousCourseId !== currentCourseId) {
      setActiveLessonId(null);
    }
    previousActiveCourseIdRef.current = currentCourseId;
  }, [activeCourse?.id]);

  useEffect(() => {
    // Start active learning tracker if user is student
    if (hasUsableAuth && userRole === 'student' && activeCourse) {
      activeLearningTracker.start(activeCourse.id, activeLessonId ?? undefined);
    }

    return () => {
      activeLearningTracker.stop();
    };
  }, [hasUsableAuth, userRole, activeCourse, activeLessonId]);

  const handleRoleRouting = useCallback((resolvedRole?: 'student' | 'admin') => {
    const role = resolvedRole || (hasUsableAuth ? authProfile?.role : undefined) || 'student';
    if (role === 'admin') {
      setCurrentView('admin');
    } else {
      setCurrentView('dashboard');
    }
  }, [authProfile?.role, hasUsableAuth]);

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

  // Route Guard & Role Routing
  // 1. Never block public showcases ('pitch' and 'demo').
  // 2. If session is still loading (isAuthLoading), wait.
  // 3. For unauthenticated visitors: any protected screen redirects to 'login'.
  // 4. For authenticated users on auth forms ('login', 'register', 'forgot-password'): route to their role dashboard.
  useEffect(() => {
    if (isAuthLoading) return;

    // Public showcase presentations never require login
    if (currentView === 'pitch' || currentView === 'demo') {
      return;
    }

    const isAuthForm =
      currentView === 'login' || currentView === 'register' || currentView === 'forgot-password';

    if (!hasUsableAuth) {
      // Unauthenticated visitor trying to access protected screens -> force to 'login'
      if (!isAuthForm) {
        setCurrentView('login');
      }
      return;
    }

    // Authenticated user
    const effectiveRole = authProfile?.role || 'student';

    // If already logged in and on an auth form, send to appropriate dashboard
    if (isAuthForm) {
      if (effectiveRole === 'admin') setCurrentView('admin');
      else setCurrentView('dashboard');
      return;
    }

    // Role-based view guards for non-student roles landing on student views
    if (effectiveRole === 'admin' && currentView !== 'admin' && currentView !== 'profile') {
      setCurrentView('admin');
    }
  }, [isAuthLoading, hasUsableAuth, authProfile, currentView]);

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
  const isAccessDenied = currentView === 'admin' && (!hasUsableAuth || userRole !== 'admin');

  // Prevent flicker during initial session resolution
  if (isAuthLoading && !isPitchOrDemo) {
    return (
      <div className="min-h-screen w-full bg-[#0a0f2c] text-white flex flex-col items-center justify-center p-4 relative overflow-hidden">
        <div className="absolute top-1/4 left-1/4 w-[400px] h-[400px] bg-indigo-600/20 rounded-full blur-[120px] pointer-events-none" />
        <div className="absolute bottom-1/4 right-1/4 w-[400px] h-[400px] bg-blue-500/20 rounded-full blur-[120px] pointer-events-none" />
        <div className="relative z-10 flex flex-col items-center gap-4">
          <BilimYolLogo size="lg" variant="dark" />
          <div className="flex items-center gap-2 mt-2">
            <div className="w-5 h-5 border-2 border-indigo-400 border-t-transparent rounded-full animate-spin" />
            <span className="text-xs font-semibold text-indigo-200">Tizim yuklanmoqda...</span>
          </div>
        </div>
      </div>
    );
  }

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
                Ushbu panelga kirish faqat administratorlar uchun ruxsat etilgan.
                Sizning joriy hisob turingiz: <strong>O‘quvchi</strong>.
              </p>
              <Button
                variant="primary"
                onClick={() => setCurrentView('dashboard')}
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
                onNavigateApp={() => setCurrentView(hasUsableAuth ? 'dashboard' : 'login')}
                onNavigateAiTutor={() => setCurrentView(hasUsableAuth ? 'ai-tutor' : 'login')}
              />
            )}

            {currentView === 'demo' && (
              <DemoShowcaseView
                onNavigateCourses={() => setCurrentView(hasUsableAuth ? 'course-selection' : 'login')}
                onNavigateDashboard={() => setCurrentView(hasUsableAuth ? 'dashboard' : 'login')}
                onNavigateAiTutor={() => setCurrentView(hasUsableAuth ? 'ai-tutor' : 'login')}
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

            {currentView === 'admin' && <AdminDashboardView />}
          </>
        )}
      </main>

      {/* Footer (Hidden on Pitch/Demo pages which have their own rich pitch footer) */}
      {!isPitchOrDemo && (
        <footer className="bg-white border-t border-slate-200 py-6 text-center text-xs text-slate-500 mt-auto">
          <div className="max-w-7xl mx-auto px-4 flex flex-col sm:flex-row items-center justify-between gap-2">
            <span>
              <strong>BilimYo‘l Smart Edu</strong> © 2026 — O‘quvchi va Ma’muriyat uchun yagona ta’lim platformasi
            </span>
            <span className="text-slate-400">
              {hasUsableAuth ? `Hisob: ${authProfile?.email} (${userRole})` : 'Yo‘lchi AI • Real Adaptive Learning'}
            </span>
          </div>
        </footer>
      )}
    </div>
  );
};
