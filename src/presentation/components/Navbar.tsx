import React, { useState } from 'react';
import { BilimYolLogo } from './BilimYolLogo';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { useAuth } from '@/core/context/AuthContext';
import {
  Flame,
  Award,
  Map,
  Compass,
  LayoutDashboard,
  Users,
  GraduationCap,
  Link2,
  ShieldAlert,
  Bot,
  TrendingUp,
  User,
  Sparkles,
  Play,
} from 'lucide-react';
import { StudentConnectionsModal } from '@/features/student/StudentConnectionsModal';

interface NavbarProps {
  currentView: string;
  onNavigate: (view: string) => void;
}

export const Navbar: React.FC<NavbarProps> = ({ currentView, onNavigate }) => {
  const { activeCourse } = useCourseStore();
  const { profile } = useLearnerStore();
  const { profile: authProfile } = useAuth();
  const [isConnectionsModalOpen, setIsConnectionsModalOpen] = useState(false);

  const userRole = authProfile?.role || 'student';

  // Desktop navigation items
  const studentDesktopLinks = [
    { id: 'dashboard', label: 'Bosh sahifa', icon: LayoutDashboard },
    { id: 'roadmap', label: 'Ta’lim yo‘li', icon: Map },
    { id: 'knowledge-map', label: 'Bilim xaritasi', icon: Compass },
    { id: 'ai-tutor', label: 'Yo‘lchi AI', icon: Bot },
    { id: 'progress', label: 'Natijalar', icon: TrendingUp },
  ];

  // Mobile Bottom Navigation Items
  const studentMobileBottomLinks = [
    { id: 'dashboard', label: 'Bosh sahifa', icon: LayoutDashboard },
    { id: 'roadmap', label: 'Darslar', icon: Map },
    { id: 'ai-tutor', label: 'Yo‘lchi AI', icon: Bot },
    { id: 'progress', label: 'Natijalar', icon: TrendingUp },
    { id: 'profile', label: 'Profil', icon: User },
  ];

  return (
    <>
      <nav className="bg-[#030712]/85 backdrop-blur-2xl border-b border-white/10 sticky top-0 z-40 transition-all duration-300">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center gap-5">
              <button
                onClick={() =>
                  onNavigate(
                    userRole === 'admin'
                      ? 'admin'
                      : userRole === 'parent'
                      ? 'parent'
                      : userRole === 'teacher'
                      ? 'teacher'
                      : 'dashboard'
                  )
                }
                className="cursor-pointer focus:outline-none transition-transform hover:scale-102"
              >
                <BilimYolLogo size="md" variant="dark" />
              </button>

              {/* Desktop Navigation */}
              <div className="hidden lg:flex items-center gap-1.5 pl-4 border-l border-white/10">
                {userRole === 'student' &&
                  studentDesktopLinks.map((link) => {
                    const Icon = link.icon;
                    const isActive = currentView === link.id;
                    return (
                      <button
                        key={link.id}
                        onClick={() => onNavigate(link.id)}
                        className={`flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                          isActive
                            ? 'bg-cyan-950/80 text-cyan-300 border border-cyan-500/40 shadow-[0_0_15px_rgba(6,182,212,0.25)] font-black'
                            : 'text-slate-300 hover:text-white hover:bg-white/5'
                        }`}
                      >
                        <Icon className={`w-4 h-4 ${isActive ? 'text-cyan-400' : 'text-slate-400'}`} />
                        <span>{link.label}</span>
                      </button>
                    );
                  })}

                {userRole === 'parent' && (
                  <button
                    onClick={() => onNavigate('parent')}
                    className="flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-bold bg-emerald-950/80 text-emerald-300 border border-emerald-500/40"
                  >
                    <Users className="w-4 h-4" />
                    <span>Ota-ona Paneli</span>
                  </button>
                )}

                {userRole === 'teacher' && (
                  <button
                    onClick={() => onNavigate('teacher')}
                    className="flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-bold bg-indigo-950/80 text-indigo-300 border border-indigo-500/40"
                  >
                    <GraduationCap className="w-4 h-4" />
                    <span>O‘qituvchi Paneli</span>
                  </button>
                )}

                {userRole === 'admin' && (
                  <button
                    onClick={() => onNavigate('admin')}
                    className="flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-bold bg-purple-950/80 text-purple-300 border border-purple-500/40 shadow-[0_0_15px_rgba(168,85,247,0.25)]"
                  >
                    <ShieldAlert className="w-4 h-4 text-purple-400" />
                    <span>Boshqaruv (Admin)</span>
                  </button>
                )}

                {/* Pitch Day 3.0 & /demo Direct Competition Links */}
                <div className="flex items-center gap-2 ml-2 pl-3 border-l border-white/10">
                  <button
                    onClick={() => onNavigate('pitch')}
                    className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-black bg-gradient-to-r from-cyan-500 via-indigo-600 to-purple-600 hover:from-cyan-400 hover:to-purple-500 text-white shadow-[0_0_20px_rgba(99,102,241,0.35)] transition-all cursor-pointer group"
                    title="Pitch Day 3.0 Taqdimot Ekrani"
                  >
                    <Sparkles className="w-3.5 h-3.5 text-amber-300 group-hover:rotate-12 transition-transform" />
                    <span>Pitch Day 3.0</span>
                  </button>

                  <button
                    onClick={() => onNavigate('demo')}
                    className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-black bg-white/10 hover:bg-white/20 text-white border border-white/20 transition-all cursor-pointer backdrop-blur-md"
                    title="/demo Sahifasi (Video & Prototip)"
                  >
                    <Play className="w-3 h-3 text-cyan-400 fill-cyan-400" />
                    <span>/demo</span>
                  </button>
                </div>
              </div>
            </div>

            {/* Right Status (Role Badge + Stats + Profile) */}
            <div className="flex items-center gap-2 sm:gap-3">
              {/* Active Subject Pill for quick context */}
              {userRole === 'student' && activeCourse && (
                <div className="hidden md:flex items-center gap-1.5 px-2.5 py-1 rounded-xl bg-slate-800/80 border border-white/10 text-xs text-slate-300 font-semibold">
                  <span className="w-2 h-2 rounded-full bg-cyan-400 animate-pulse" />
                  <span>{activeCourse.title}</span>
                </div>
              )}

              {/* Role Indicator Badge */}
              <div className="hidden sm:flex items-center text-xs font-bold">
                {userRole === 'student' && (
                  <span className="text-cyan-300 bg-cyan-950/80 border border-cyan-500/40 px-2.5 py-1 rounded-xl">
                    🎓 O‘quvchi
                  </span>
                )}
                {userRole === 'parent' && (
                  <span className="text-emerald-300 bg-emerald-950/80 border border-emerald-500/40 px-2.5 py-1 rounded-xl">
                    👨‍👩‍👧 Ota-ona
                  </span>
                )}
                {userRole === 'teacher' && (
                  <span className="text-indigo-300 bg-indigo-950/80 border border-indigo-500/40 px-2.5 py-1 rounded-xl">
                    👨‍🏫 O‘qituvchi
                  </span>
                )}
                {userRole === 'admin' && (
                  <span className="text-purple-300 bg-purple-950/80 border border-purple-500/40 px-2.5 py-1 rounded-xl flex items-center gap-1 font-bold">
                    ⚡ Administrator
                  </span>
                )}
              </div>

              {/* Student Connection Trigger */}
              {userRole === 'student' && (
                <button
                  onClick={() => setIsConnectionsModalOpen(true)}
                  className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-slate-800/80 hover:bg-slate-700/80 border border-white/10 text-xs font-bold text-slate-200 transition-colors cursor-pointer"
                  title="Ota-ona yoki Sinfga Ulanish"
                >
                  <Link2 className="w-3.5 h-3.5 text-cyan-400" />
                  <span className="hidden sm:inline">Ulanish</span>
                </button>
              )}

              {userRole === 'student' && (
                <>
                  <div
                    className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl bg-amber-950/80 border border-amber-500/40 text-xs font-black text-amber-300 shadow-[0_0_12px_rgba(245,158,11,0.2)]"
                    title="Kunlik faollik streak"
                  >
                    <Flame className="w-3.5 h-3.5 text-amber-400 fill-amber-400 pulse-flame" />
                    <span>{profile?.streakDays ?? 5} kun</span>
                  </div>

                  <div
                    className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl bg-purple-950/80 border border-purple-500/40 text-xs font-black text-purple-300 shadow-[0_0_12px_rgba(168,85,247,0.2)]"
                    title="Jami tajriba ochkolari"
                  >
                    <Award className="w-3.5 h-3.5 text-purple-400" />
                    <span>{profile?.xp ?? 1200} XP</span>
                  </div>
                </>
              )}

              {/* Profile Avatar / Link */}
              <button
                onClick={() => onNavigate('profile')}
                className={`flex items-center gap-2 pl-2 pr-2 sm:pr-3 py-1 rounded-xl transition-all cursor-pointer ${
                  currentView === 'profile'
                    ? 'bg-cyan-950/80 text-cyan-300 ring-2 ring-cyan-500'
                    : 'hover:bg-white/10 text-slate-200'
                }`}
                title="Mening Profilim"
              >
                <div className="w-7 h-7 rounded-lg bg-gradient-to-tr from-cyan-500 via-indigo-600 to-purple-600 text-white font-extrabold text-xs flex items-center justify-center shadow-xs">
                  {authProfile?.firstName?.charAt(0) || 'O'}
                </div>
                <span className="hidden md:inline text-xs font-bold text-slate-200">
                  {authProfile?.firstName || 'Profil'}
                </span>
              </button>
            </div>
          </div>
        </div>

        {/* Mobile Sub-Navigation Bar */}
        <div className="lg:hidden flex items-center justify-around py-1.5 px-2 border-t border-white/10 bg-[#030712]/95 backdrop-blur-2xl">
          {userRole === 'student' &&
            studentMobileBottomLinks.map((link) => {
              const Icon = link.icon;
              const isActive = currentView === link.id;
              return (
                <button
                  key={link.id}
                  onClick={() => onNavigate(link.id)}
                  className={`flex flex-col items-center gap-0.5 py-1 px-2 rounded-xl text-[10px] font-bold transition-all cursor-pointer ${
                    isActive ? 'text-cyan-400 font-black' : 'text-slate-400 hover:text-white'
                  }`}
                >
                  <Icon className={`w-4 h-4 ${isActive ? 'text-cyan-400' : 'text-slate-500'}`} />
                  <span>{link.label}</span>
                </button>
              );
            })}
        </div>
      </nav>

      {/* Student Connections Modal */}
      <StudentConnectionsModal
        isOpen={isConnectionsModalOpen}
        onClose={() => setIsConnectionsModalOpen(false)}
      />
    </>
  );
};
