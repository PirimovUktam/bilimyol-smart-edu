import { useState, useEffect, useCallback, useRef, Suspense, lazy } from 'react';
import { Navbar } from '@/presentation/components/Navbar';
import { LoginView } from '@/features/auth/LoginView';
import { RegisterView } from '@/features/auth/RegisterView';
import { ForgotPasswordView } from '@/features/auth/ForgotPasswordView';
import { ResetPasswordView } from '@/features/auth/ResetPasswordView';
import { WelcomeView } from '@/features/auth/WelcomeView';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { useRoadmapStore } from '@/app/store/useRoadmapStore';
import { useLessonStore } from '@/app/store/useLessonStore';
import { resolveNextLearningLesson } from '@/app/router/lessonResolution';
import { useAuth } from '@/core/context/AuthContext';
import { isProtectedAuthReady } from '@/core/utils/authGuards';
import { hasStartedCourse, pendingFoundationLesson } from '@/domain/personalization/learningStart';
import { activeLearningTracker } from '@/core/services/ActiveLearningTracker';
import { Button } from '@/presentation/components/Button';

import { SectionState } from '@/presentation/components/SectionState';
import { RouteErrorBoundary } from '@/presentation/components/RouteErrorBoundary';

// Route-level code-splitting for heavy, rarely-opened surfaces. The marketing
// slides (~2.7k lines) and the admin panel only load when actually visited.
const LazyPitchShowcaseView = lazy(() =>
  import('@/features/pitch/PitchShowcaseView').then((m) => ({ default: m.PitchShowcaseView }))
);
const LazyDemoShowcaseView = lazy(() =>
  import('@/features/pitch/DemoShowcaseView').then((m) => ({ default: m.DemoShowcaseView }))
);
const LazyAdminDashboardView = lazy(() =>
  import('@/features/admin/AdminDashboardView').then((m) => ({ default: m.AdminDashboardView }))
);

// Learner surfaces are split per-route so the initial bundle stays small. The
// auth screens stay eager (they are the first paint for most visitors).
const LazyCourseSelectionView = lazy(() =>
  import('@/features/course-selection/CourseSelectionView').then((m) => ({ default: m.CourseSelectionView }))
);
const LazyOnboardingView = lazy(() =>
  import('@/features/onboarding/OnboardingView').then((m) => ({ default: m.OnboardingView }))
);
const LazyPlacementTestView = lazy(() =>
  import('@/features/placement/PlacementTestView').then((m) => ({ default: m.PlacementTestView }))
);
const LazyKnowledgeMapView = lazy(() =>
  import('@/features/knowledge-map/KnowledgeMapView').then((m) => ({ default: m.KnowledgeMapView }))
);
const LazyRoadmapView = lazy(() =>
  import('@/features/roadmap/RoadmapView').then((m) => ({ default: m.RoadmapView }))
);
const LazyInteractiveLessonView = lazy(() =>
  import('@/features/lesson/InteractiveLessonView').then((m) => ({ default: m.InteractiveLessonView }))
);
const LazyDashboardView = lazy(() =>
  import('@/features/dashboard/DashboardView').then((m) => ({ default: m.DashboardView }))
);
const LazyYolchiAIChatView = lazy(() =>
  import('@/features/ai-tutor/YolchiAIChatView').then((m) => ({ default: m.YolchiAIChatView }))
);
const LazyProgressView = lazy(() =>
  import('@/features/progress/ProgressView').then((m) => ({ default: m.ProgressView }))
);
const LazyProfileView = lazy(() =>
  import('@/features/profile/ProfileView').then((m) => ({ default: m.ProfileView }))
);


const RouteFallback = () => (
  <div className="learning-page"><SectionState kind="loading" title="Sahifa yuklanmoqda…" /></div>
);

const views = [
  'pitch', 'demo', 'course-selection', 'onboarding', 'placement', 'knowledge-map',
  'roadmap', 'lesson', 'dashboard', 'ai-tutor', 'progress', 'login', 'register',
  'forgot-password', 'reset-password', 'profile', 'admin', 'welcome',
] as const;

type AppView = typeof views[number];

const readRoute = () => {
  const { pathname, search, hash } = window.location;
  const path = pathname.toLowerCase().slice(1);
  const params = new URLSearchParams(search);
  const candidates = [path, params.get('view'), hash.slice(1).toLowerCase()];
  const view = candidates.find((candidate): candidate is AppView =>
    views.some((supported) => supported === candidate),
  ) ?? 'welcome';
  return { view, lessonId: view === 'lesson' ? params.get('lessonId') : null };
};

const standaloneViews = new Set<AppView>(['welcome', 'login', 'register', 'forgot-password', 'reset-password', 'pitch', 'demo']);
const learningViews = new Set<AppView>(['lesson', 'placement', 'roadmap', 'knowledge-map', 'ai-tutor']);

export { type AppView };

export function AppRouter() {
  const [{ view, lessonId }, setRoute] = useState(readRoute);
  const main = useRef<HTMLElement>(null);
  const navigate = useCallback((next: AppView, id?: string, replace = false) => {
    const nextLesson = next === 'lesson' ? id ?? null : null;
    const query = new URLSearchParams({ view: next });
    if (nextLesson) query.set('lessonId', nextLesson);
    const url = next === 'welcome' ? '/' : standaloneViews.has(next) ? '/' + next : '/?' + query;
    if (url !== window.location.pathname + window.location.search + window.location.hash) {
      window.history[replace ? 'replaceState' : 'pushState'](null, '', url);
    }
    setRoute({ view: next, lessonId: nextLesson });
  }, []);

  useEffect(() => {
    const restore = () => setRoute(readRoute());
    window.addEventListener('popstate', restore);
    window.addEventListener('hashchange', restore);
    return () => {
      window.removeEventListener('popstate', restore);
      window.removeEventListener('hashchange', restore);
    };
  }, [navigate]);

  useEffect(() => {
    window.scrollTo(0, 0);
    if (!standaloneViews.has(view)) main.current?.focus({ preventScroll: true });
  }, [view, lessonId]);

  const activeCourse = useCourseStore((state) => state.activeCourse);
  const learnerProfile = useLearnerStore((state) => state.profile);
  const [setupRetry, setSetupRetry] = useState(0);
  const [setupError, setSetupError] = useState(false);
  const [readyLearner, setReadyLearner] = useState<string | null>(null);
  const { profile, session, isDemoMode, isPasswordRecovery, isLoading } = useAuth();
  const hasUsableAuth = isProtectedAuthReady(session, profile, isDemoMode);
  const isAdmin = profile?.role === 'admin';
  const isShowcase = view === 'demo' || view === 'pitch';
  const isWorkspace = !standaloneViews.has(view);
  const learnerId = hasUsableAuth && !isAdmin && !isPasswordRecovery ? profile?.id : undefined;
  const home: AppView = isAdmin ? 'admin' : 'dashboard';

  useEffect(() => {
    if (!learnerId) return;
    let disposed = false;
    setSetupError(false);
    setReadyLearner(null);
    void (async () => {
      try {
        await useLearnerStore.getState().loadProfile();
        if (!disposed) await useCourseStore.getState().loadCourses();
        if (!disposed) setReadyLearner(learnerId);
      } catch {
        if (!disposed) setSetupError(true);
      }
    })();
    return () => { disposed = true; };
  }, [learnerId, setupRetry]);

  useEffect(() => {
    if (isLoading || isShowcase || view === 'reset-password') return;
    if (isPasswordRecovery) navigate('reset-password', undefined, true);
    else if (!hasUsableAuth && isWorkspace) navigate('login', undefined, true);
    else if (hasUsableAuth && !isWorkspace) {
      if (isAdmin) navigate('admin', undefined, true);
      else if (readyLearner === learnerId || setupError) {
        navigate(setupError || (activeCourse && hasStartedCourse(activeCourse, learnerProfile)) ? 'dashboard' : 'course-selection', undefined, true);
      }
    } else if (hasUsableAuth && isAdmin && view !== 'admin' && view !== 'profile') {
      navigate('admin', undefined, true);
    }
  }, [isLoading, isShowcase, isPasswordRecovery, hasUsableAuth, isWorkspace, isAdmin, view, readyLearner, learnerId, setupError, activeCourse, learnerProfile, navigate]);

  const courseId = activeCourse?.id;
  const trackLesson = useLessonStore((state) => {
    const current = state.currentLesson;
    return view === 'lesson' && current?.courseId === courseId && current?.id === lessonId ? lessonId : null;
  });
  const tracking = Boolean(learnerId && !isDemoMode && session && courseId && learningViews.has(view));
  useEffect(() => {
    if (!tracking || !courseId) return;
    activeLearningTracker.start(courseId);
    return () => activeLearningTracker.stop();
  }, [tracking, learnerId, courseId]);

  useEffect(() => {
    activeLearningTracker.setLesson(trackLesson);
  }, [tracking, courseId, trackLesson]);

  const startLesson = (id: string) => navigate('lesson', id);
  const continueLesson = (id?: string) => {
    const target = id ?? resolveNextLearningLesson(activeCourse, learnerProfile, useRoadmapStore.getState().roadmap);
    if (target) startLesson(target);
    else navigate('roadmap');
  };
  const openRoadmap = () => navigate('roadmap');
  const openKnowledgeMap = () => navigate('knowledge-map');
  const login = () => navigate('login', undefined, true);

  const renderView = () => {
    if (isWorkspace && !hasUsableAuth) return <RouteFallback />;
    if (isWorkspace && learnerId && view !== 'admin' && view !== 'profile' && setupError) {
      return (
        <div className="learning-page">
          <SectionState kind="error" title="Ta’lim maydonini yuklab bo‘lmadi"
            description="Profil va fanlar ro‘yxatini qayta yuklab ko‘ring."
            onRetry={() => setSetupRetry((attempt) => attempt + 1)} />
        </div>
      );
    }
    if (isWorkspace && learnerId && view !== 'admin' && view !== 'profile' && (!learnerProfile || readyLearner !== learnerId)) return <RouteFallback />;
    if (!isWorkspace && !isShowcase && view !== 'reset-password' && hasUsableAuth) return <RouteFallback />;

    switch (view) {
      case 'welcome':
        return <WelcomeView onRegister={() => navigate('register')} onLogin={() => navigate('login')} />;
      case 'pitch':
        return <LazyPitchShowcaseView onNavigateDemo={() => navigate('demo')}
          onNavigateApp={() => navigate(hasUsableAuth ? home : 'login')}
          onNavigateAiTutor={() => navigate(hasUsableAuth ? 'ai-tutor' : 'login')} />;
      case 'demo':
        return <LazyDemoShowcaseView onNavigateCourses={() => navigate(hasUsableAuth ? 'course-selection' : 'login')}
          onNavigateDashboard={() => navigate(hasUsableAuth ? home : 'login')}
          onNavigateAiTutor={() => navigate(hasUsableAuth ? 'ai-tutor' : 'login')}
          onNavigatePitch={() => navigate('pitch')} />;
      case 'login':
        return <LoginView onNavigateRegister={() => navigate('register')} onNavigateForgotPassword={() => navigate('forgot-password')} />;
      case 'register':
        return <RegisterView onNavigateLogin={login} />;
      case 'forgot-password':
        return <ForgotPasswordView onNavigateLogin={login} />;
      case 'reset-password':
        return <ResetPasswordView onNavigateLogin={login} />;
      case 'profile':
        return <LazyProfileView onSignOut={login} onChooseSubject={() => navigate('course-selection')}
          onOpenLearningPlan={() => navigate('onboarding')} />;
      case 'course-selection':
        return <LazyCourseSelectionView onSelectCourse={(id) => {
          const chosen = useCourseStore.getState().activeCourse;
          if (chosen?.id !== id) return;
          navigate(hasStartedCourse(chosen, useLearnerStore.getState().profile) ? 'dashboard' : 'onboarding');
        }} />;
      case 'onboarding':
        return <LazyOnboardingView key={courseId} onComplete={(id, level, diagnostic) => {
          const chosen = useCourseStore.getState().activeCourse;
          if (chosen?.id !== id) return;
          const foundation = pendingFoundationLesson(chosen, useLearnerStore.getState().profile);
          if (diagnostic && level !== 'beginner') navigate('placement');
          else if (foundation) startLesson(foundation);
          else openRoadmap();
        }} onBack={() => navigate('course-selection')} />;
      case 'placement':
        return <LazyPlacementTestView onComplete={openRoadmap} onChooseCourse={() => navigate('course-selection')}
          onStartLearning={openRoadmap} />;
      case 'knowledge-map':
        return <LazyKnowledgeMapView onProceedToRoadmap={openRoadmap}
          onStartPlacement={() => navigate('placement')} onChooseCourse={() => navigate('course-selection')} />;
      case 'roadmap':
        return <LazyRoadmapView onStartLesson={startLesson} onOpenKnowledgeMap={openKnowledgeMap}
          onChooseCourse={() => navigate('course-selection')} onConfigure={() => navigate('onboarding')} />;
      case 'lesson':
        return lessonId ? <LazyInteractiveLessonView key={lessonId} lessonId={lessonId}
          onFinish={openRoadmap} onBackToRoadmap={openRoadmap} />
          : <div className="learning-page"><SectionState title="Dars topilmadi"
            description="Ta’lim yo‘lingizdan dars tanlang." />
            <Button className="mt-4" onClick={openRoadmap}>Ta’lim yo‘liga qaytish</Button></div>;
      case 'dashboard':
        return <LazyDashboardView onContinueLesson={continueLesson} onOpenRoadmap={openRoadmap}
          onOpenCourses={() => navigate('course-selection')}
          onOpenOnboarding={() => navigate('onboarding')}
          onStartPlacement={() => navigate('placement')} onOpenAITutor={() => navigate('ai-tutor')}
          onOpenProgress={() => navigate('progress')} />;
      case 'ai-tutor':
        return <LazyYolchiAIChatView key={profile?.id} onStartLesson={() => continueLesson()} />;
      case 'progress':
        return <LazyProgressView onContinueLesson={() => continueLesson()}
          onOpenRoadmap={openRoadmap} onOpenKnowledgeMap={openKnowledgeMap} />;
      case 'admin':
        return isAdmin ? <LazyAdminDashboardView /> : (
          <div className="learning-page">
            <SectionState kind="error" title="Ruxsat cheklangan" description="Bu sahifa administratorlar uchun." />
            <Button className="mt-4" onClick={() => navigate('dashboard')}>Bosh sahifaga qaytish</Button>
          </div>
        );
    }
  };

  const showNavigation = isWorkspace && hasUsableAuth && view !== 'lesson';
  return (
    <div className={showNavigation ? 'workspace-shell bg-canvas text-ink' : 'min-h-screen bg-canvas text-ink'}
      data-learner={showNavigation && !isAdmin ? '' : undefined}
      data-view={view}>
      {showNavigation && <Navbar currentView={view} onNavigate={navigate} />}
      <div className={isWorkspace ? 'workspace-content' : undefined}>
        {isWorkspace && <a href="#main-content" className="sr-only focus:not-sr-only focus:absolute focus:z-50 focus:rounded-xl focus:bg-paper focus:p-3">
          Asosiy mazmunga o‘tish
        </a>}
        <main ref={main} id="main-content" tabIndex={-1} className="focus:outline-none">
          <RouteErrorBoundary key={view + (lessonId ?? '')}>
            <Suspense fallback={<RouteFallback />}>{renderView()}</Suspense>
          </RouteErrorBoundary>
        </main>
        {!isShowcase && <footer className="border-t border-hairline px-4 py-5 text-center text-xs text-slatefine">
          BilimYo‘l Smart Edu · Shaxsiy ta’lim yo‘li
        </footer>}
      </div>
    </div>
  );
}
