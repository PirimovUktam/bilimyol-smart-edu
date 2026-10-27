import React from 'react';
import { BilimYolLogo } from './BilimYolLogo';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { useAuth } from '@/core/context/AuthContext';
import {
  Flame,
  Award,
  Map,
  Compass,
  LayoutDashboard,
  ShieldAlert,
  Bot,
  TrendingUp,
  User,
  Sparkles,
  Play,
  ArrowRight,
  GraduationCap,
} from 'lucide-react';

interface NavbarProps {
  currentView: string;
  onNavigate: (view: string) => void;
}

export const Navbar: React.FC<NavbarProps> = ({ currentView, onNavigate }) => {
  const { profile } = useLearnerStore();
  const { profile: authProfile } = useAuth();

  const userRole = authProfile?.role || 'student';

  // Desktop navigation items
  const studentDesktopLinks = [
    { id: 'dashboard', label: 'Bosh sahifa', icon: LayoutDashboard },
    { id: 'roadmap', label: 'Ta’lim yo‘li', icon: Map },
    { id: 'knowledge-map', label: 'Bilim xaritasi', icon: Compass },
    { id: 'ai-tutor', label: 'Yo‘lchi AI', icon: Bot },
    { id: 'progress', label: 'Natijalar', icon: TrendingUp },
  ];

  // Mobile bottom navigation items
  const studentMobileBottomLinks = [
    { id: 'dashboard', label: 'Bosh sahifa', icon: LayoutDashboard },
    { id: 'roadmap', label: 'Darslar', icon: Map },
    { id: 'ai-tutor', label: 'Yo‘lchi AI', icon: Bot },
    { id: 'progress', label: 'Natijalar', icon: TrendingUp },
    { id: 'profile', label: 'Profil', icon: User },
  ];

  return (
    <>
      <nav className={`${currentView === 'dashboard' && userRole === 'student' ? 'lg:hidden' : ''} bg-paper/90 backdrop-blur-md border-b border-hairline sticky top-0 z-40`}>
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center gap-6">
              <button
                onClick={() =>
                  onNavigate(userRole === 'admin' ? 'admin' : 'dashboard')
                }
                className="cursor-pointer focus:outline-none"
              >
                <BilimYolLogo size="md" />
              </button>

              {/* Desktop Navigation */}
              <div className="hidden lg:flex items-center gap-1.5 pl-5 border-l border-hairline">
                {userRole === 'student' &&
                  studentDesktopLinks.map((link) => {
                    const Icon = link.icon;
                    const isActive = currentView === link.id;
                    return (
                      <button
                        key={link.id}
                        onClick={() => onNavigate(link.id)}
                        aria-current={isActive ? 'page' : undefined}
                        className={`flex items-center gap-2 px-3 py-1.5 rounded-lg text-xs font-bold transition-all cursor-pointer ${
                          isActive
                            ? 'bg-ink text-white shadow-xs'
                            : 'text-slatefine hover:text-ink hover:bg-sand'
                        }`}
                      >
                        <Icon className={`w-3.5 h-3.5 ${isActive ? 'text-path' : 'text-faint'}`} />
                        <span>{link.label}</span>
                      </button>
                    );
                  })}

                {userRole === 'admin' && (
                  <button
                    onClick={() => onNavigate('admin')}
                    className="flex items-center gap-2 px-3 py-1.5 rounded-lg text-xs font-bold bg-[#6d28d9]/10 text-[#5b21b6] border border-[#6d28d9]/25"
                  >
                    <ShieldAlert className="w-3.5 h-3.5" />
                    <span>Boshqaruv (Admin)</span>
                  </button>
                )}

                {/* Pitch Day 3.0 & /demo links */}
                <div className="flex items-center gap-1.5 ml-2 pl-3 border-l border-hairline">
                  <button
                    onClick={() => onNavigate('pitch')}
                    className="flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-[11px] font-bold bg-brand/8 text-brand-dark border border-brand/20 hover:bg-brand/15 transition-all cursor-pointer group"
                    title="Pitch Day 3.0 Taqdimot Ekrani"
                  >
                    <Sparkles className="w-3 h-3 text-brand group-hover:rotate-12 transition-transform" />
                    <span>Pitch Day 3.0</span>
                  </button>

                  <button
                    onClick={() => onNavigate('demo')}
                    className="flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-[11px] font-bold bg-mint/10 hover:bg-mint/20 text-[#046b4a] border border-mint/30 transition-all cursor-pointer"
                    title="/demo Sahifasi (Video & Prototip)"
                  >
                    <Play className="w-2.5 h-2.5 fill-current" />
                    <span>/demo</span>
                  </button>
                </div>
              </div>
            </div>

            {/* Right Status (Role Badge + Stats + Profile) */}
            <div className="flex items-center gap-2 sm:gap-2.5">
              {!authProfile ? (
                <button
                  onClick={() => onNavigate('login')}
                  className="flex items-center gap-2 px-4 py-2 rounded-xl bg-ink hover:bg-graphite text-white text-xs font-bold shadow-xs hover:scale-[1.02] active:scale-[0.98] transition-all cursor-pointer"
                >
                  <span>Kirish</span>
                  <ArrowRight className="w-3.5 h-3.5" />
                </button>
              ) : (
                <>
                  {/* Role Indicator Badge */}
                  <div className="hidden sm:flex items-center">
                    {userRole === 'student' && (
                      <span className="text-graphite bg-sand border border-hairline px-2.5 py-1 rounded-lg text-[11px] font-mono font-bold uppercase tracking-wider flex items-center gap-1.5">
                        <GraduationCap className="w-3.5 h-3.5 text-brand" />
                        O‘quvchi
                      </span>
                    )}
                    {userRole === 'admin' && (
                      <span className="text-[#5b21b6] bg-[#6d28d9]/10 border border-[#6d28d9]/25 px-2.5 py-1 rounded-lg text-[11px] font-mono font-bold uppercase tracking-wider flex items-center gap-1.5">
                        <ShieldAlert className="w-3.5 h-3.5" />
                        Administrator
                      </span>
                    )}
                  </div>

                  {userRole === 'student' && (
                    <>
                      <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-amber/12 border border-amber/30 text-xs font-mono font-bold text-[#8a5a00]">
                        <Flame className="w-3.5 h-3.5 fill-amber text-amber" />
                        <span>{profile?.streakDays ?? 0} kun</span>
                      </div>

                      <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-brand/8 border border-brand/25 text-xs font-mono font-bold text-brand-dark">
                        <Award className="w-3.5 h-3.5 text-brand" />
                        <span>{profile?.xp ?? 0} XP</span>
                      </div>
                    </>
                  )}

                  {/* Profile Avatar / Link */}
                  <button
                    onClick={() => onNavigate('profile')}
                    className={`flex items-center gap-2 pl-1.5 pr-2.5 py-1 rounded-lg transition-all cursor-pointer border ${
                      currentView === 'profile'
                        ? 'bg-ink text-white border-ink'
                        : 'bg-paper hover:bg-sand text-graphite border-hairline'
                    }`}
                    title="Mening Profilim"
                  >
                    <div className="w-6 h-6 rounded-md bg-brand text-white font-mono font-bold text-xs flex items-center justify-center">
                      {authProfile?.firstName?.charAt(0) || 'O'}
                    </div>
                    <span className="hidden md:inline text-xs font-bold tracking-tight">
                      {authProfile?.firstName || 'Profil'}
                    </span>
                  </button>
                </>
              )}
            </div>
          </div>
        </div>

        {/* Mobile Sub-Navigation Bar for Quick Switching */}
        <div className="lg:hidden flex items-center justify-around py-1.5 px-2 border-t border-hairline bg-paper/95">
          {userRole === 'student' &&
            studentMobileBottomLinks.map((link) => {
              const Icon = link.icon;
              const isActive = currentView === link.id;
              return (
                <button
                  key={link.id}
                  onClick={() => onNavigate(link.id)}
                  aria-label={link.label}
                  aria-current={isActive ? 'page' : undefined}
                  className={`flex flex-col items-center justify-center gap-0.5 min-h-[44px] min-w-[44px] px-2 rounded-xl text-[10px] font-bold transition-all cursor-pointer ${
                    isActive ? 'text-brand font-black' : 'text-slatefine hover:text-ink'
                  }`}
                >
                  <Icon className={`w-4 h-4 ${isActive ? 'text-brand' : 'text-faint'}`} />
                  <span>{link.label}</span>
                </button>
              );
            })}
        </div>
      </nav>
    </>
  );
};
