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

  // Desktop navigation items (Reference 2 style)
  const studentDesktopLinks = [
    { id: 'dashboard', label: 'Bosh sahifa', icon: LayoutDashboard },
    { id: 'roadmap', label: 'Ta’lim yo‘li', icon: Map },
    { id: 'knowledge-map', label: 'Bilim xaritasi', icon: Compass },
    { id: 'ai-tutor', label: 'Yo‘lchi AI', icon: Bot },
    { id: 'progress', label: 'Natijalar', icon: TrendingUp },
  ];

  // Mobile Bottom 5-Navigation Items (Reference 2 style)
  const studentMobileBottomLinks = [
    { id: 'dashboard', label: 'Bosh sahifa', icon: LayoutDashboard },
    { id: 'roadmap', label: 'Darslar', icon: Map },
    { id: 'ai-tutor', label: 'Yo‘lchi AI', icon: Bot },
    { id: 'progress', label: 'Natijalar', icon: TrendingUp },
    { id: 'profile', label: 'Profil', icon: User },
  ];

  return (
    <>
      <nav className={`${currentView === 'dashboard' && userRole === 'student' ? 'lg:hidden' : ''} bg-white/95 backdrop-blur-md border-b border-slate-200/90 sticky top-0 z-40`}>
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center gap-6">
              <button
                onClick={() =>
                  onNavigate(
                    userRole === 'admin'
                      ? 'admin'
                      : 'dashboard'
                  )
                }
                className="cursor-pointer focus:outline-none"
              >
                <BilimYolLogo size="md" />
              </button>

              {/* Desktop Navigation */}
              <div className="hidden lg:flex items-center gap-1 pl-4 border-l border-slate-200">
                {userRole === 'student' &&
                  studentDesktopLinks.map((link) => {
                    const Icon = link.icon;
                    const isActive = currentView === link.id;
                    return (
                      <button
                        key={link.id}
                        onClick={() => onNavigate(link.id)}
                        className={`flex items-center gap-2 px-3 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                          isActive
                            ? 'bg-indigo-50 text-indigo-700 shadow-2xs font-black'
                            : 'text-slate-600 hover:text-slate-900 hover:bg-slate-50'
                        }`}
                      >
                        <Icon className={`w-4 h-4 ${isActive ? 'text-indigo-600' : 'text-slate-400'}`} />
                        <span>{link.label}</span>
                      </button>
                    );
                  })}

                {userRole === 'admin' && (
                  <button
                    onClick={() => onNavigate('admin')}
                    className="flex items-center gap-2 px-3 py-2 rounded-xl text-xs font-bold bg-purple-50 text-purple-700 border border-purple-200"
                  >
                    <ShieldAlert className="w-4 h-4 text-purple-600" />
                    <span>Boshqaruv (Admin)</span>
                  </button>
                )}

                {/* Pitch Day 3.0 & /demo Direct Competition Links */}
                <div className="flex items-center gap-1.5 ml-2 pl-3 border-l border-slate-200">
                  <button
                    onClick={() => onNavigate('pitch')}
                    className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-black bg-gradient-to-r from-indigo-600 via-purple-600 to-indigo-700 hover:from-indigo-700 hover:to-purple-800 text-white shadow-xs transition-all cursor-pointer group"
                    title="Pitch Day 3.0 Taqdimot Ekrani"
                  >
                    <Sparkles className="w-3.5 h-3.5 text-amber-300 group-hover:rotate-12 transition-transform" />
                    <span>Pitch Day 3.0</span>
                  </button>

                  <button
                    onClick={() => onNavigate('demo')}
                    className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-black bg-emerald-50 hover:bg-emerald-100 text-emerald-800 border border-emerald-300 transition-all cursor-pointer"
                    title="/demo Sahifasi (Video & Prototip)"
                  >
                    <Play className="w-3 h-3 text-emerald-600 fill-emerald-600" />
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
                  className="flex items-center gap-2 px-4 py-2 rounded-xl bg-gradient-to-r from-blue-600 via-indigo-600 to-indigo-700 hover:from-blue-700 hover:to-indigo-800 text-white text-xs font-black shadow-md shadow-indigo-600/20 hover:scale-[1.02] active:scale-[0.98] transition-all cursor-pointer"
                >
                  <span>Kirish</span>
                  <ArrowRight className="w-3.5 h-3.5" />
                </button>
              ) : (
                <>
                  {/* Role Indicator Badge */}
                  <div className="hidden sm:flex items-center px-2 py-0.5 rounded-xl text-xs font-bold border">
                    {userRole === 'student' && (
                      <span className="text-indigo-700 bg-indigo-50 border-indigo-200 px-2 py-0.5 rounded-lg border flex items-center gap-1">
                        <GraduationCap className="w-3.5 h-3.5" />
                        O‘quvchi
                      </span>
                    )}
                    {userRole === 'admin' && (
                      <span className="text-purple-700 bg-purple-50 border-purple-200 px-2 py-0.5 rounded-lg border flex items-center gap-1 font-bold">
                        <ShieldAlert className="w-3.5 h-3.5" />
                        Administrator
                      </span>
                    )}
                  </div>

                  {userRole === 'student' && (
                    <>
                      <div className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl bg-orange-50 border border-orange-200/80 text-xs font-black text-orange-800">
                        <Flame className="w-3.5 h-3.5 text-orange-500 fill-orange-500" />
                        <span>{profile?.streakDays ?? 0} kun</span>
                      </div>

                      <div className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl bg-indigo-50 border border-indigo-200/80 text-xs font-black text-indigo-700">
                        <Award className="w-3.5 h-3.5 text-indigo-600" />
                        <span>{profile?.xp ?? 0} XP</span>
                      </div>
                    </>
                  )}

                  {/* Profile Avatar / Link */}
                  <button
                    onClick={() => onNavigate('profile')}
                    className={`flex items-center gap-2 pl-2 pr-2 sm:pr-3 py-1 rounded-xl transition-all cursor-pointer ${
                      currentView === 'profile'
                        ? 'bg-indigo-50 text-indigo-700 ring-2 ring-indigo-600'
                        : 'hover:bg-slate-100 text-slate-700'
                    }`}
                    title="Mening Profilim"
                  >
                    <div className="w-7 h-7 rounded-lg bg-gradient-to-tr from-indigo-600 to-cyan-500 text-white font-extrabold text-xs flex items-center justify-center shadow-xs">
                      {authProfile?.firstName?.charAt(0) || 'O'}
                    </div>
                    <span className="hidden md:inline text-xs font-bold">
                      {authProfile?.firstName || 'Profil'}
                    </span>
                  </button>
                </>
              )}
            </div>
          </div>
        </div>

        {/* Mobile Sub-Navigation Bar for Quick Switching */}
        <div className="lg:hidden flex items-center justify-around py-1.5 px-2 border-t border-slate-100 bg-white/95">
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
                    isActive ? 'text-indigo-600 font-black' : 'text-slate-500 hover:text-slate-800'
                  }`}
                >
                  <Icon className={`w-4 h-4 ${isActive ? 'text-indigo-600' : 'text-slate-400'}`} />
                  <span>{link.label}</span>
                </button>
              );
            })}
        </div>
      </nav>

    </>
  );
};
