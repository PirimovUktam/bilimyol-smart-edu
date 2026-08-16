import React from 'react';
import { BilimYolLogo } from './BilimYolLogo';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { Flame, Award, Map, Compass, BookOpen, LayoutDashboard } from 'lucide-react';

interface NavbarProps {
  currentView: string;
  onNavigate: (view: string) => void;
}

export const Navbar: React.FC<NavbarProps> = ({ currentView, onNavigate }) => {
  const { activeCourse } = useCourseStore();
  const { profile } = useLearnerStore();

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

          {/* Right Status (Active Course + Streak + XP) */}
          <div className="flex items-center gap-3">
            {activeCourse && (
              <div className="hidden sm:flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-slate-100 border border-slate-200/80 text-xs font-semibold text-slate-700">
                <span className="w-2 h-2 rounded-full bg-blue-600 animate-pulse" />
                <span>{activeCourse.title}</span>
              </div>
            )}

            <div className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-amber-50 border border-amber-200/80 text-xs font-bold text-amber-800">
              <Flame className="w-4 h-4 text-amber-500 fill-amber-500" />
              <span>{profile?.streakDays ?? 1} kun streak</span>
            </div>

            <div className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-blue-50 border border-blue-200/80 text-xs font-bold text-blue-700">
              <Award className="w-4 h-4 text-blue-600" />
              <span>{profile?.xp ?? 120} XP</span>
            </div>
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
        </div>
      </div>
    </nav>
  );
};
