import React from 'react';
import { BilimYolLogo } from './BilimYolLogo';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { useAuth } from '@/core/context/AuthContext';
import { Flame, Award, Map, Compass, BookOpen, LayoutDashboard, User as UserIcon } from 'lucide-react';

interface NavbarProps {
  currentView: string;
  onNavigate: (view: string) => void;
}

export const Navbar: React.FC<NavbarProps> = ({ currentView, onNavigate }) => {
  const { activeCourse } = useCourseStore();
  const { profile } = useLearnerStore();
  const { profile: authProfile } = useAuth();

  const navLinks = [
    { id: 'course-selection', label: 'Fanlar', icon: BookOpen },
    { id: 'knowledge-map', label: 'Bilim Xaritasi', icon: Compass },
    { id: 'roadmap', label: 'Yo‘l Xaritasi', icon: Map },
    { id: 'dashboard', label: 'Dashboard', icon: LayoutDashboard },
  ];

  return (
    <nav className="bg-white/90 backdrop-blur-md border-b border-slate-200 sticky top-7 z-40">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          <div className="flex items-center gap-6">
            <button
              onClick={() => onNavigate('course-selection')}
              className="cursor-pointer focus:outline-none"
            >
              <BilimYolLogo size="md" />
            </button>

            {/* Desktop Navigation */}
            <div className="hidden md:flex items-center gap-1 pl-4 border-l border-slate-200">
              {navLinks.map((link) => {
                const Icon = link.icon;
                const isActive = currentView === link.id;
                return (
                  <button
                    key={link.id}
                    onClick={() => onNavigate(link.id)}
                    className={`flex items-center gap-2 px-3 py-2 rounded-xl text-sm font-semibold transition-all cursor-pointer ${
                      isActive
                        ? 'bg-blue-50 text-blue-700'
                        : 'text-slate-600 hover:text-slate-900 hover:bg-slate-50'
                    }`}
                  >
                    <Icon className="w-4 h-4" />
                    <span>{link.label}</span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Right Status (Active Course + Streak + XP + Profile) */}
          <div className="flex items-center gap-2.5">
            {activeCourse && (
              <div className="hidden sm:flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-slate-100 border border-slate-200/80 text-xs font-semibold text-slate-700">
                <span className="w-2 h-2 rounded-full bg-blue-600 animate-pulse" />
                <span>{activeCourse.title}</span>
              </div>
            )}

            <div className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl bg-amber-50 border border-amber-200/80 text-xs font-bold text-amber-800">
              <Flame className="w-3.5 h-3.5 text-amber-500 fill-amber-500" />
              <span>{profile?.streakDays ?? 3} kun</span>
            </div>

            <div className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl bg-blue-50 border border-blue-200/80 text-xs font-bold text-blue-700">
              <Award className="w-3.5 h-3.5 text-blue-600" />
              <span>{profile?.xp ?? 120} XP</span>
            </div>

            {/* Profile Avatar / Link */}
            <button
              onClick={() => onNavigate('profile')}
              className={`flex items-center gap-2 pl-2 pr-3 py-1 rounded-xl transition-all cursor-pointer ${
                currentView === 'profile'
                  ? 'bg-blue-50 text-blue-700 ring-2 ring-blue-600'
                  : 'hover:bg-slate-100 text-slate-700'
              }`}
              title="Mening Profilim"
            >
              <div className="w-7 h-7 rounded-lg bg-gradient-to-tr from-blue-600 to-indigo-600 text-white font-bold text-xs flex items-center justify-center">
                {authProfile?.firstName?.charAt(0) || 'A'}
              </div>
              <span className="hidden md:inline text-xs font-bold">
                {authProfile?.firstName || 'Profil'}
              </span>
            </button>
          </div>
        </div>

        {/* Mobile Navigation bar */}
        <div className="md:hidden flex items-center justify-around py-2 border-t border-slate-100">
          {navLinks.map((link) => {
            const Icon = link.icon;
            const isActive = currentView === link.id;
            return (
              <button
                key={link.id}
                onClick={() => onNavigate(link.id)}
                className={`flex flex-col items-center gap-1 py-1 px-2 text-[11px] font-semibold transition-all ${
                  isActive ? 'text-blue-600' : 'text-slate-500 hover:text-slate-800'
                }`}
              >
                <Icon className="w-4 h-4" />
                <span>{link.label}</span>
              </button>
            );
          })}
          <button
            onClick={() => onNavigate('profile')}
            className={`flex flex-col items-center gap-1 py-1 px-2 text-[11px] font-semibold transition-all ${
              currentView === 'profile' ? 'text-blue-600' : 'text-slate-500 hover:text-slate-800'
            }`}
          >
            <UserIcon className="w-4 h-4" />
            <span>Profil</span>
          </button>
        </div>
      </div>
    </nav>
  );
};
