import { useTranslation } from '@/core/locales/useTranslation';
import { useState, useEffect, useCallback, useRef, Suspense, lazy } from 'react';
import { WelcomeView } from '@/features/auth/WelcomeView';
import { ProductTourView } from '@/features/tour/ProductTourView';
import {
  hasCompletedProductTour,
  isRootWelcomeEntry,
  markProductTourCompleted,
} from '@/core/preferences/productTour';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { useRoadmapStore } from '@/app/store/useRoadmapStore';
import { useLessonStore } from '@/app/store/useLessonStore';
import { resolveNextLearningLesson } from '@/app/router/lessonResolution';
import { useAuth } from '@/core/context/AuthContext';
import { isProtectedAuthReady } from '@/core/utils/authGuards';
import { hasStartedCourse } from '@/domain/personalization/learningStart';
import { activeLearningTracker } from '@/core/services/ActiveLearningTracker';
import { Button } from '@/presentation/components/Button';
import { withMotionPreferences } from '@/presentation/components/withMotionPreferences';
import { InteractiveLessonView } from '@/features/lesson/InteractiveLessonView';

import { SectionState } from '@/presentation/components/SectionState';
import { RouteErrorBoundary } from '@/presentation/components/RouteErrorBoundary';
import type { ComponentType } from 'react';

function lazyAnimated<Props extends object>(load: () => Promise<ComponentType<Props>>) {
  return lazy(async () => {
    const [View, { withMotionPreferences }] = await Promise.all([
      load(), import('@/presentation/components/withMotionPreferences'),
    ]);
    return { default: withMotionPreferences(View) };
  });
}

// Navigation & auth forms are only needed when entering auth or logged-in workspace.
const LazyNavbar = lazy(() =>
  import('@/presentation/components/Navbar').then((m) => ({ default: m.Navbar }))
);
const LazyLoginView = lazy(() =>
  import('@/features/auth/LoginView').then((m) => ({ default: m.LoginView }))
);
const LazyRegisterView = lazy(() =>
  import('@/features/auth/RegisterView').then((m) => ({ default: m.RegisterView }))
);
const LazyForgotPasswordView = lazy(() =>
  import('@/features/auth/ForgotPasswordView').then((m) => ({ default: m.ForgotPasswordView }))
);
const LazyResetPasswordView = lazy(() =>
  import('@/features/auth/ResetPasswordView').then((m) => ({ default: m.ResetPasswordView }))
);

// Route-level code-splitting for heavy, rarely-opened surfaces. The marketing
// slides (~2.7k lines) and the admin panel only load when actually visited.
const LazyPitchShowcaseView = lazyAnimated(() =>
  import('@/features/pitch/PitchShowcaseView').then((m) => m.PitchShowcaseView)
);
const LazyDemoShowcaseView = lazyAnimated(() =>
  import('@/features/pitch/DemoShowcaseView').then((m) => m.DemoShowcaseView)
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
const LazyRoadmapView = lazyAnimated(() =>
  import('@/features/roadmap/RoadmapView').then((m) => m.RoadmapView)
);
const EagerInteractiveLessonView = withMotionPreferences(InteractiveLessonView);
const LazyDashboardView = lazy(() =>
  import('@/features/dashboard/DashboardView').then((m) => ({ default: m.DashboardView }))
);
const LazyYolchiAIChatView = lazyAnimated(() =>
  import('@/features/ai-tutor/YolchiAIChatView').then((m) => m.YolchiAIChatView)
);
const LazyProgressView = lazy(() =>
  import('@/features/progress/ProgressView').then((m) => ({ default: m.ProgressView }))
);
const LazyProfileView = lazy(() =>
  import('@/features/profile/ProfileView').then((m) => ({ default: m.ProfileView }))
);


const RouteFallback = () => {
  const { t } = useTranslation();
  return (
  <div className="learning-page"><SectionState kind="loading" title={t('shell.pageLoading')} /></div>
);
};

const views = [
  'pitch', 'demo', 'tour', 'course-selection', 'onboarding', 'placement', 'knowledge-map',
  'roadmap', 'lesson', 'dashboard', 'ai-tutor', 'progress', 'login', 'register',
  'forgot-password', 'reset-password', 'profile', 'admin', 'welcome',
] as const;

type AppView = typeof views[number];

const readRoute = (): { view: AppView; lessonId: string | null; planOrigin: 'roadmap' | 'profile' | null } => {
  const { pathname, search, hash } = window.location;
  const path = pathname.toLowerCase().slice(1);
  const params = new URLSearchParams(search);
  const candidates = [path, params.get('view'), hash.slice(1).toLowerCase()];
  const view = candidates.find((candidate): candidate is AppView =>
    views.some((supported) => supported === candidate),
  ) ?? 'welcome';
  const from = params.get('from');
  return {
    view,
    lessonId: view === 'lesson' ? params.get('lessonId') : null,
    planOrigin: view === 'onboarding' && (from === 'roadmap' || from === 'profile') ? from : null,
  };
};

const standaloneViews = new Set<AppView>(['welcome', 'tour', 'login', 'register', 'forgot-password', 'reset-password', 'pitch', 'demo']);
const learningViews = new Set<AppView>(['lesson', 'placement', 'roadmap', 'knowledge-map', 'ai-tutor']);

export { type AppView };

export function AppRouter() {
  const { t } = useTranslation();
  const [{ view, lessonId, planOrigin }, setRoute] = useState(readRoute);
  const main = useRef<HTMLElement>(null);
  const navigate = useCallback((next: AppView, id?: string, replace = false) => {
    const nextLesson = next === 'lesson' ? id ?? null : null;
    const planOrigin = next === 'onboarding' && (id === 'roadmap' || id === 'profile') ? id : null;
    const query = new URLSearchParams({ view: next });
    if (nextLesson) query.set('lessonId', nextLesson);
    if (planOrigin) query.set('from', planOrigin);
    const url = next === 'welcome' ? '/' : standaloneViews.has(next) ? '/' + next : '/?' + query;
    if (url !== window.location.pathname + window.location.search + window.location.hash) {
      window.history[replace ? 'replaceState' : 'pushState'](null, '', url);
    }
    setRoute({ view: next, lessonId: nextLesson, planOrigin });
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
  const isTourView = view === 'tour';
  const isWorkspace = !standaloneViews.has(view);
  const [tourCompleted, setTourCompleted] = useState(() => hasCompletedProductTour());
  const finishFirstVisitTour = useCallback(() => {
    markProductTourCompleted();
    setTourCompleted(true);
  }, []);
  const finishReplayTour = useCallback(() => {
    markProductTourCompleted();
    setTourCompleted(true);
    navigate(hasUsableAuth ? 'profile' : 'welcome');
  }, [hasUsableAuth, navigate]);
  const learnerId = hasUsableAuth && !isAdmin && !isPasswordRecovery ? profile?.id : undefined;
  const home: AppView = isAdmin ? 'admin' : 'dashboard';

  useEffect(() => {
    let disposed = false;
    setSetupError(false);
    setReadyLearner(null);
    if (!learnerId) return;
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
    if (isLoading || isShowcase || isTourView || view === 'reset-password') return;
    if (isPasswordRecovery) navigate('reset-password', undefined, true);
    else if (!hasUsableAuth && isWorkspace) navigate('login', undefined, true);
    else if (hasUsableAuth && !isWorkspace) {
      if (isAdmin) navigate('admin', undefined, true);
      else if (setupError || (learnerId && readyLearner === learnerId && (isDemoMode || learnerProfile?.id === learnerId))) {
        navigate(setupError || (activeCourse && hasStartedCourse(activeCourse, learnerProfile)) ? 'dashboard' : 'course-selection', undefined, true);
      }
    } else if (hasUsableAuth && isAdmin && view !== 'admin' && view !== 'profile') {
      navigate('admin', undefined, true);
    }
  }, [isLoading, isShowcase, isTourView, isPasswordRecovery, hasUsableAuth, isWorkspace, isAdmin, isDemoMode, view, readyLearner, learnerId, setupError, activeCourse, learnerProfile, navigate]);

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

  const startLesson = (id: string) => {
    void useLessonStore.getState().loadLesson(id);
    navigate('lesson', id);
  };
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
          <SectionState kind="error" title={t('shell.workspaceFailed')}
            description={t('shell.workspaceRetry')}
            onRetry={() => setSetupRetry((attempt) => attempt + 1)} />
        </div>
      );
    }
    if (isWorkspace && learnerId && view !== 'admin' && view !== 'profile' && (!learnerProfile || readyLearner !== learnerId)) return <RouteFallback />;
    if (!isWorkspace && !isShowcase && !isTourView && view !== 'reset-password' && hasUsableAuth) return <RouteFallback />;

    switch (view) {
      case 'welcome':
        if (isLoading || isPasswordRecovery) return <RouteFallback />;
        if (!tourCompleted && isRootWelcomeEntry(window.location)) {
          return (
            <ProductTourView
              mode="first-visit"
              onComplete={finishFirstVisitTour}
              onSkip={finishFirstVisitTour}
            />
          );
        }
        return <WelcomeView onRegister={() => navigate('register')} onLogin={() => navigate('login')} />;
      case 'tour':
        if (isLoading) return <RouteFallback />;
        return (
          <ProductTourView
            mode="replay"
            onComplete={finishReplayTour}
            onSkip={finishReplayTour}
          />
        );
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
        return <LazyLoginView onNavigateRegister={() => navigate('register')} onNavigateForgotPassword={() => navigate('forgot-password')} />;
      case 'register':
        return <LazyRegisterView onNavigateLogin={login} />;
      case 'forgot-password':
        return <LazyForgotPasswordView onNavigateLogin={login} />;
      case 'reset-password':
        return <LazyResetPasswordView onNavigateLogin={login} />;
      case 'profile':
        return <LazyProfileView onSignOut={login} onChooseSubject={() => navigate('course-selection')}
          onOpenLearningPlan={() => navigate('onboarding', 'profile')} onReplayTour={() => navigate('tour')} />;
      case 'course-selection':
        return <LazyCourseSelectionView onSelectCourse={(id) => {
          const chosen = useCourseStore.getState().activeCourse;
          if (chosen?.id !== id) return;
          navigate(hasStartedCourse(chosen, useLearnerStore.getState().profile) ? 'dashboard' : 'onboarding');
        }} />;
      case 'onboarding':
        return <LazyOnboardingView key={courseId} editing={Boolean(planOrigin)} onComplete={(id, level, diagnostic) => {
          const chosen = useCourseStore.getState().activeCourse;
          if (chosen?.id !== id) return;
          const first = level === 'beginner' && !planOrigin
            ? resolveNextLearningLesson(chosen, useLearnerStore.getState().profile, useRoadmapStore.getState().roadmap) : null;
          if (diagnostic) navigate('placement');
          else if (first) startLesson(first);
          else openRoadmap();
        }} onBack={() => navigate(planOrigin ?? 'course-selection')} />;
      case 'placement':
        return <LazyPlacementTestView onComplete={openRoadmap} onChooseCourse={() => navigate('course-selection')}
          onStartLearning={openRoadmap} />;
      case 'knowledge-map':
        return <LazyKnowledgeMapView onProceedToRoadmap={openRoadmap}
          onStartPlacement={() => navigate('placement')} onChooseCourse={() => navigate('course-selection')}
          onStartLesson={continueLesson} />;
      case 'roadmap':
        return <LazyRoadmapView onStartLesson={startLesson} onOpenKnowledgeMap={openKnowledgeMap}
          onChooseCourse={() => navigate('course-selection')} onConfigure={() => navigate('onboarding')}
          onEditPlan={() => navigate('onboarding', 'roadmap')}
          onStartPlacement={() => navigate('placement')} />;
      case 'lesson':
        return lessonId ? <EagerInteractiveLessonView key={lessonId} lessonId={lessonId}
          onFinish={openRoadmap} onBackToRoadmap={openRoadmap} />
          : <div className="learning-page"><SectionState title={t('shell.lessonMissing')}
            description={t('shell.chooseLesson')} />
            <Button className="mt-4" onClick={openRoadmap}>{t('lesson.backPath')}</Button></div>;
      case 'dashboard':
        return <LazyDashboardView onContinueLesson={continueLesson} onOpenRoadmap={openRoadmap}
          onOpenKnowledgeMap={openKnowledgeMap}
          onOpenCourses={() => navigate('course-selection')}
          onOpenOnboarding={() => navigate('onboarding')}
          onStartPlacement={() => navigate('placement')} onOpenAITutor={() => navigate('ai-tutor')}
          onOpenProgress={() => navigate('progress')} onOpenProfile={() => navigate('profile')} />;
      case 'ai-tutor':
        return <LazyYolchiAIChatView key={profile?.id} onStartLesson={() => continueLesson()} />;
      case 'progress':
        return <LazyProgressView onContinueLesson={() => continueLesson()}
          onOpenRoadmap={openRoadmap} onOpenKnowledgeMap={openKnowledgeMap} />;
      case 'admin':
        return isAdmin ? <LazyAdminDashboardView /> : (
          <div className="learning-page">
            <SectionState kind="error" title={t('shell.restricted')} description={t('shell.adminOnly')} />
            <Button className="mt-4" onClick={() => navigate('dashboard')}>{t('shell.backHome')}</Button>
          </div>
        );
    }
  };

  const showNavigation = isWorkspace && hasUsableAuth && view !== 'lesson';
  const isShowingFirstVisitTour =
    view === 'welcome' &&
    !isLoading &&
    !hasUsableAuth &&
    !isPasswordRecovery &&
    !tourCompleted &&
    isRootWelcomeEntry(window.location);
  return (
    <div className={showNavigation ? 'workspace-shell bg-canvas text-ink' : 'min-h-screen bg-canvas text-ink'}
      data-learner={showNavigation && !isAdmin ? '' : undefined}
      data-view={view}>
      {showNavigation && (
        <Suspense fallback={null}>
          <LazyNavbar currentView={view} onNavigate={navigate} />
        </Suspense>
      )}
      <div className={isWorkspace ? 'workspace-content' : undefined}>
        {isWorkspace && <a href="#main-content" className="sr-only focus:not-sr-only focus:absolute focus:z-50 focus:rounded-xl focus:bg-paper focus:p-3">{t('shell.skip')}</a>}
        <main ref={main} id="main-content" tabIndex={-1} className="focus:outline-none">
          <RouteErrorBoundary key={view + (lessonId ?? '')}>
            <Suspense fallback={<RouteFallback />}>{renderView()}</Suspense>
          </RouteErrorBoundary>
        </main>
        {!isShowcase && !isTourView && !isShowingFirstVisitTour && (
          <footer className="border-t border-hairline px-4 py-5 text-center text-xs text-slatefine">{t('shell.footer')}</footer>
        )}
      </div>
    </div>
  );
}
