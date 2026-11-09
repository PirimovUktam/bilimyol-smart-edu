import { useTranslation } from '@/core/locales/useTranslation';
import { useEffect, useState } from 'react';
import {
  ArrowRight,
  BookOpen,
  ChartNoAxesCombined,
  ChevronDown,
  Clock,
  Crown,
  House,
  Layers,
  Route,
  Settings,
  Shield,
  Sparkles,
  Trophy,
} from 'lucide-react';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useAuth } from '@/core/context/AuthContext';
import type { AppView } from '@/app/router/AppRouter';
import { Avatar } from './Avatar';
import { BilimYolLogo } from './BilimYolLogo';

interface NavbarProps {
  currentView: AppView;
  onNavigate: (view: AppView) => void;
}

const studyLinks = [
  { id: 'dashboard', label: 'common.home', icon: House },
  { id: 'course-selection', label: 'common.courses', icon: Layers },
  { id: 'roadmap', label: 'common.path', icon: Route },
  { id: 'ai-tutor', label: 'common.tutor', icon: Sparkles },
  { id: 'progress', label: 'common.progress', icon: ChartNoAxesCombined },
  { id: 'knowledge-map', label: 'common.map', icon: Trophy },
] as const;

const mobileLinks = [
  { id: 'dashboard', label: 'common.home', icon: House },
  { id: 'roadmap', label: 'common.path', icon: Route },
  { id: 'ai-tutor', label: 'common.tutor', icon: Sparkles },
  { id: 'progress', label: 'common.progress', icon: ChartNoAxesCombined },
  { id: 'profile', label: 'common.profile', icon: Settings },
] as const;

const adminLink = { id: 'admin', label: 'common.admin', icon: Shield } as const;

export function Navbar({ currentView, onNavigate }: NavbarProps) {
  const { t } = useTranslation();
  const { profile } = useAuth();
  const course = useCourseStore((state) => state.activeCourse);
  const [premiumSoonOpen, setPremiumSoonOpen] = useState(false);
  const isAdmin = profile?.role === 'admin';

  useEffect(() => {
    if (!premiumSoonOpen) return;
    const timer = window.setTimeout(() => setPremiumSoonOpen(false), 4200);
    return () => window.clearTimeout(timer);
  }, [premiumSoonOpen]);
  const name = profile
    ? [profile.firstName, profile.lastName].filter(Boolean).join(' ')
    : t('profile.profile');
  const home = isAdmin ? 'admin' : 'dashboard';
  const section =
    currentView === 'lesson' || currentView === 'placement'
      ? 'roadmap'
      : currentView === 'onboarding'
      ? 'course-selection'
      : currentView;

  const select = onNavigate;
  const subjectButton = (compact: boolean) => (
    <button
      type="button"
      onClick={() => select('course-selection')}
      aria-current={section === 'course-selection' ? 'page' : undefined}
      aria-label={t('common.switchCourse')}
      className={
        compact
          ? 'flex min-h-11 min-w-0 items-center gap-1.5 rounded-full border border-hairline bg-paper px-3.5 text-xs font-bold text-slatefine shadow-sm transition-transform active:scale-95'
          : 'mt-4 flex min-h-11 w-full cursor-pointer items-center gap-2.5 rounded-2xl border border-hairline bg-paper px-3.5 text-left text-xs font-bold text-slatefine transition-all hover:border-hairline hover:bg-paper'
      }
    >
      <span className="grid size-7 shrink-0 place-items-center rounded-lg bg-gradient-to-br from-[#8B5CF6] to-[#06B6D4] text-white shadow-xs">
        <BookOpen aria-hidden="true" className="size-3.5" />
      </span>
      <span className="max-w-32 truncate">{course?.title ?? t('common.chooseCourse')}</span>
      <ChevronDown
        aria-hidden="true"
        className="ml-auto size-4 shrink-0 text-brand-dark"
      />
    </button>
  );

  return (
    <>
      <aside className="workspace-sidebar">
        <button
          type="button"
          aria-label={t('shell.home')}
          onClick={() => select(home)}
          className="w-full cursor-pointer rounded-2xl px-2 py-1.5 text-left transition-transform hover:scale-[1.01]"
        >
          <BilimYolLogo variant="auto" showSubtitle={false} />
        </button>

        {!isAdmin && subjectButton(false)}

        <nav aria-label={t('common.navigation')} className="mt-5 space-y-1.5">
          {(isAdmin ? [adminLink] : studyLinks).map(
            ({ id, label, icon: Icon }) => (
              <button
                type="button"
                key={id}
                onClick={() => select(id)}
                aria-current={section === id ? 'page' : undefined}
                className="workspace-nav-link"
              >
                <Icon aria-hidden="true" className="size-5 shrink-0" />
                {t(label)}
              </button>
            ),
          )}
        </nav>

        <div className="mt-auto space-y-3 pt-5">
          {!isAdmin && (
            <div className="relative overflow-hidden rounded-3xl border border-purple-400/30 bg-gradient-to-b from-[#231B59]/90 via-[#1A1545]/95 to-[#141138] p-4 shadow-[0_14px_34px_-8px_rgba(124,58,237,0.35)]">
              <div
                aria-hidden="true"
                className="pointer-events-none absolute -top-8 -right-8 size-24 rounded-full bg-purple-500/25 blur-2xl"
              />
              <div className="flex items-center justify-between gap-2">
                <span className="inline-flex size-9 items-center justify-center rounded-xl bg-amber-400/15 text-amber-300 shadow-inner">
                  <Crown aria-hidden="true" className="size-5" />
                </span>
                <span className="inline-flex items-center gap-1 rounded-full border border-amber-400/35 bg-amber-400/15 px-2.5 py-0.5 text-[10px] font-extrabold text-amber-200">
                  <Clock aria-hidden="true" className="size-3" />{t('dashboard.soon')}</span>
              </div>
              <h3 className="mt-2.5 font-display text-base font-extrabold text-white">{t('dashboard.premium')}</h3>
              <p className="mt-1 text-xs leading-relaxed text-indigo-200/80">{t('dashboard.premiumDescription')}</p>
              <button
                type="button"
                onClick={() => setPremiumSoonOpen(true)}
                className="cosmos-cta-btn mt-3.5 w-full py-2.5 px-3.5 text-xs"
              >{t('dashboard.subscribe')}<ArrowRight aria-hidden="true" className="size-3.5" />
              </button>
              {premiumSoonOpen && (
                <p
                  role="status"
                  aria-live="polite"
                  className="fade-up mt-2.5 flex items-center justify-center gap-1.5 rounded-xl border border-cyan-400/35 bg-cyan-500/15 px-3 py-2 text-center text-[11px] font-bold text-cyan-200"
                >
                  <Sparkles aria-hidden="true" className="size-3.5 shrink-0 text-cyan-300" />{t('dashboard.comingSoon')}</p>
              )}
            </div>
          )}

          <button
            type="button"
            aria-label={t('common.profile')}
            aria-current={section === 'profile' ? 'page' : undefined}
            onClick={() => select('profile')}
            className="workspace-nav-link gap-3! border border-hairline bg-paper p-2.5!"
          >
            <Avatar
              name={name}
              className="bg-purple-500/25! text-brand-dark!"
            />
            <span className="min-w-0 flex-1 truncate text-ink">{name}</span>
            <Settings
              aria-hidden="true"
              className="size-4 shrink-0 text-slatefine"
            />
          </button>
        </div>
      </aside>

      <header className="workspace-mobile-header">
        <button
          type="button"
          aria-label={t('shell.home')}
          onClick={() => select(home)}
          className="min-w-0 cursor-pointer text-left"
        >
          <BilimYolLogo size="sm" variant="auto" showSubtitle={false} />
        </button>
        {isAdmin ? (
          <button
            type="button"
            onClick={() => select('profile')}
            className="min-h-11 px-3 text-sm font-bold text-ink"
          >{t('profile.profile')}</button>
        ) : (
          subjectButton(true)
        )}
      </header>

      {!isAdmin && (
        <nav className="workspace-mobile-nav" aria-label={t('common.mobileNavigation')}>
          {mobileLinks.map(({ id, label, icon: Icon }) => (
            <button
              type="button"
              key={id}
              onClick={() => select(id)}
              aria-current={section === id ? 'page' : undefined}
              className="workspace-tab"
            >
              <Icon aria-hidden="true" className="size-5" />
              {t(label)}
            </button>
          ))}
        </nav>
      )}

      {premiumSoonOpen && (
        <div
          role="dialog"
          aria-label={t('dashboard.premiumNotice')}
          className="fade-up fixed right-4 bottom-20 z-50 max-w-sm rounded-2xl border border-hairline bg-paper p-4 text-ink shadow-[0_20px_50px_rgba(4,6,22,0.85)] backdrop-blur-xl lg:top-6 lg:right-6 lg:bottom-auto"
        >
          <div className="flex items-start gap-3">
            <span className="grid size-10 shrink-0 place-items-center rounded-xl bg-gradient-to-br from-amber-400/25 to-purple-500/25 text-amber-300 ring-1 ring-amber-400/35">
              <Crown aria-hidden="true" className="size-5" />
            </span>
            <div className="min-w-0 flex-1">
              <p className="font-display text-sm font-extrabold text-ink">{t('dashboard.comingSoon')}</p>
              <p className="mt-1 text-xs leading-relaxed text-slatefine">{t('dashboard.premiumNoticeDescription')}</p>
            </div>
            <button
              type="button"
              onClick={() => setPremiumSoonOpen(false)}
              className="cursor-pointer rounded-lg px-2 py-1 text-xs font-bold text-slatefine hover:bg-sand hover:text-ink"
            >{t('courses.close')}</button>
          </div>
        </div>
      )}
    </>
  );
}
