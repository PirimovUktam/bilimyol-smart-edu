import {
  ArrowRight,
  BookOpen,
  ChartNoAxesCombined,
  ChevronDown,
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
  { id: 'dashboard', label: 'Bosh sahifa', icon: House },
  { id: 'course-selection', label: 'Kurslar', icon: Layers },
  { id: 'roadmap', label: 'Ta’lim yo‘li', icon: Route },
  { id: 'ai-tutor', label: 'Yo‘lchi AI', icon: Sparkles },
  { id: 'progress', label: 'Natijalar', icon: ChartNoAxesCombined },
  { id: 'knowledge-map', label: 'Yutuqlar va xarita', icon: Trophy },
] as const;

const mobileLinks = [
  { id: 'dashboard', label: 'Bosh sahifa', icon: House },
  { id: 'roadmap', label: 'Ta’lim yo‘li', icon: Route },
  { id: 'ai-tutor', label: 'Yo‘lchi AI', icon: Sparkles },
  { id: 'progress', label: 'Natijalar', icon: ChartNoAxesCombined },
  { id: 'profile', label: 'Profil', icon: Settings },
] as const;

const adminLink = { id: 'admin', label: 'Boshqaruv', icon: Shield } as const;

export function Navbar({ currentView, onNavigate }: NavbarProps) {
  const { profile } = useAuth();
  const course = useCourseStore((state) => state.activeCourse);
  const isAdmin = profile?.role === 'admin';
  const name = profile
    ? [profile.firstName, profile.lastName].filter(Boolean).join(' ')
    : 'Profil';
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
      aria-label="Fanni almashtirish"
      className={
        compact
          ? 'flex min-h-11 min-w-0 items-center gap-1.5 rounded-full border border-purple-400/30 bg-[#171C47] px-3.5 text-xs font-bold text-indigo-100 shadow-sm transition-transform active:scale-95'
          : 'mt-4 flex min-h-11 w-full cursor-pointer items-center gap-2.5 rounded-2xl border border-purple-400/25 bg-[#161B44]/85 px-3.5 text-left text-xs font-bold text-indigo-100 transition-all hover:border-purple-400/50 hover:bg-[#1D2358]'
      }
    >
      <span className="grid size-7 shrink-0 place-items-center rounded-lg bg-gradient-to-br from-[#8B5CF6] to-[#06B6D4] text-white shadow-xs">
        <BookOpen aria-hidden="true" className="size-3.5" />
      </span>
      <span className="max-w-32 truncate">{course?.title ?? 'Fan tanlash'}</span>
      <ChevronDown
        aria-hidden="true"
        className="ml-auto size-4 shrink-0 text-purple-300"
      />
    </button>
  );

  return (
    <>
      <aside className="workspace-sidebar">
        <button
          type="button"
          aria-label="BilimYo‘l bosh sahifasi"
          onClick={() => select(home)}
          className="w-full cursor-pointer rounded-2xl px-2 py-1.5 text-left transition-transform hover:scale-[1.01]"
        >
          <BilimYolLogo variant="dark" showSubtitle={false} />
        </button>

        {!isAdmin && subjectButton(false)}

        <nav aria-label="Asosiy navigatsiya" className="mt-5 space-y-1.5">
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
                {label}
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
              <span className="inline-flex size-9 items-center justify-center rounded-xl bg-amber-400/15 text-amber-300 shadow-inner">
                <Crown aria-hidden="true" className="size-5" />
              </span>
              <h3 className="mt-2.5 font-display text-base font-extrabold text-white">
                Premium Ta’lim
              </h3>
              <p className="mt-1 text-xs leading-relaxed text-indigo-200/80">
                Cheksiz darslar, AI yordam va ko‘proq imkoniyatlar
              </p>
              <button
                type="button"
                onClick={() => select('roadmap')}
                className="cosmos-cta-btn mt-3.5 w-full py-2.5 px-3.5 text-xs"
              >
                Obuna bo‘lish
                <ArrowRight aria-hidden="true" className="size-3.5" />
              </button>
            </div>
          )}

          <button
            type="button"
            aria-label="Profil"
            aria-current={section === 'profile' ? 'page' : undefined}
            onClick={() => select('profile')}
            className="workspace-nav-link gap-3! border border-purple-400/20 bg-[#151A42]/80 p-2.5!"
          >
            <Avatar
              name={name}
              className="bg-purple-500/25! text-purple-200!"
            />
            <span className="min-w-0 flex-1 truncate text-white">{name}</span>
            <Settings
              aria-hidden="true"
              className="size-4 shrink-0 text-indigo-300"
            />
          </button>
        </div>
      </aside>

      <header className="workspace-mobile-header">
        <button
          type="button"
          aria-label="BilimYo‘l bosh sahifasi"
          onClick={() => select(home)}
          className="min-w-0 cursor-pointer text-left"
        >
          <BilimYolLogo size="sm" variant="dark" showSubtitle={false} />
        </button>
        {isAdmin ? (
          <button
            type="button"
            onClick={() => select('profile')}
            className="min-h-11 px-3 text-sm font-bold text-white"
          >
            Profil
          </button>
        ) : (
          subjectButton(true)
        )}
      </header>

      {!isAdmin && (
        <nav className="workspace-mobile-nav" aria-label="Mobil navigatsiya">
          {mobileLinks.map(({ id, label, icon: Icon }) => (
            <button
              type="button"
              key={id}
              onClick={() => select(id)}
              aria-current={section === id ? 'page' : undefined}
              className="workspace-tab"
            >
              <Icon aria-hidden="true" className="size-5" />
              {label}
            </button>
          ))}
        </nav>
      )}
    </>
  );
}
