import { BookOpen, ChartNoAxesCombined, ChevronDown, House, Route, Settings, Shield, Sparkles } from 'lucide-react';
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
  { id: 'roadmap', label: 'Ta’lim yo‘li', icon: Route },
  { id: 'ai-tutor', label: 'Yo‘lchi AI', icon: Sparkles },
  { id: 'progress', label: 'Natijalar', icon: ChartNoAxesCombined },
] as const;

const profileLink = { id: 'profile', label: 'Profil', icon: Settings } as const;
const adminLink = { id: 'admin', label: 'Boshqaruv', icon: Shield } as const;

export function Navbar({ currentView, onNavigate }: NavbarProps) {
  const { profile } = useAuth();
  const course = useCourseStore((state) => state.activeCourse);
  const isAdmin = profile?.role === 'admin';
  const name = profile ? [profile.firstName, profile.lastName].filter(Boolean).join(' ') : 'Profil';
  const home = isAdmin ? 'admin' : 'dashboard';
  const section = currentView === 'lesson' || currentView === 'placement' || currentView === 'knowledge-map' ? 'roadmap'
    : currentView === 'onboarding' ? 'course-selection' : currentView;

  const select = onNavigate;
  const subjectButton = (compact: boolean) => (
    <button type="button" onClick={() => select('course-selection')}
      aria-current={section === 'course-selection' ? 'page' : undefined}
      aria-label="Fanni almashtirish" className={compact
        ? 'flex min-h-11 min-w-0 items-center gap-1.5 rounded-full bg-sand px-3.5 text-xs font-bold text-brand border border-brand/20 shadow-2xs transition-transform active:scale-95'
        : 'mt-5 flex min-h-12 w-full items-center gap-2.5 rounded-2xl border border-brand/20 bg-sand/70 px-3.5 text-left text-sm font-bold text-ink hover:bg-sand hover:border-brand/40 transition-all cursor-pointer'}>
      <span className="grid size-7 shrink-0 place-items-center rounded-lg bg-brand text-white shadow-xs">
        <BookOpen aria-hidden="true" className="size-3.5" />
      </span>
      <span className="max-w-32 truncate">{course?.title ?? 'Fan tanlash'}</span>
      <ChevronDown aria-hidden="true" className="ml-auto size-4 shrink-0 text-brand" />
    </button>
  );

  return (
    <>
      <aside className="workspace-sidebar">
        <button
          type="button"
          aria-label="BilimYo‘l bosh sahifasi"
          onClick={() => select(home)}
          className="w-full cursor-pointer rounded-2xl bg-gradient-to-r from-[#0F172A] via-[#1E1B4B] to-[#4F46E5] p-3 text-left shadow-md shadow-indigo-500/15 transition-transform hover:scale-[1.01]"
        >
          <BilimYolLogo variant="dark" showSubtitle={false} />
        </button>
        {!isAdmin && subjectButton(false)}
        <nav aria-label="Asosiy navigatsiya" className="mt-6 space-y-1.5">
          <p className="px-3 pb-1.5 text-[11px] font-extrabold uppercase tracking-wider text-slatefine">
            {isAdmin ? 'Boshqaruv' : 'Ta’lim maydoni'}
          </p>
          {(isAdmin ? [adminLink] : studyLinks).map(({ id, label, icon: Icon }) => (
            <button type="button" key={id} onClick={() => select(id)}
              aria-current={section === id ? 'page' : undefined}
              className="workspace-nav-link">
              <Icon aria-hidden="true" className="size-5 shrink-0" />
              {label}
            </button>
          ))}
        </nav>
        <button type="button" aria-label="Profil" aria-current={section === 'profile' ? 'page' : undefined}
          onClick={() => select('profile')} className="workspace-nav-link mt-auto gap-3! border border-hairline bg-canvas/80 p-2.5!">
          <Avatar name={name} className="bg-brand/15! text-brand!" />
          <span className="min-w-0 flex-1 truncate text-ink">{name}</span>
          <Settings aria-hidden="true" className="size-4 shrink-0" />
        </button>
      </aside>

      <header className="workspace-mobile-header">
        <button type="button" aria-label="BilimYo‘l bosh sahifasi" onClick={() => select(home)} className="min-w-0 cursor-pointer text-left">
          <BilimYolLogo size="sm" showSubtitle={false} />
        </button>
        {isAdmin ? <button type="button" onClick={() => select('profile')} className="min-h-11 px-3 text-sm font-bold">Profil</button> : subjectButton(true)}
      </header>

      {!isAdmin && <nav className="workspace-mobile-nav" aria-label="Mobil navigatsiya">
        {[...studyLinks, profileLink]
          .map(({ id, label, icon: Icon }) => (
            <button type="button" key={id} onClick={() => select(id)}
              aria-current={section === id ? 'page' : undefined}
              className="workspace-tab">
              <Icon aria-hidden="true" className="size-5" />{label}
            </button>
          ))}
      </nav>}
    </>
  );
}
