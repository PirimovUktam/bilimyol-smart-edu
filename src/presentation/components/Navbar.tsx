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
  BookOpen,
  LayoutDashboard,
  Users,
  GraduationCap,
  Link2,
  ShieldAlert,
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

  const studentNavLinks = [
    { id: 'course-selection', label: 'Fanlar', icon: BookOpen },
    { id: 'knowledge-map', label: 'Bilim Xaritasi', icon: Compass },
    { id: 'roadmap', label: 'Yo‘l Xaritasi', icon: Map },
    { id: 'dashboard', label: 'Dashboard', icon: LayoutDashboard },
  ];

  return (
    <>
      <nav className="bg-white/90 backdrop-blur-md border-b border-slate-200 sticky top-0 z-40">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center gap-6">
              <button
                onClick={() => onNavigate(userRole === 'parent' ? 'parent' : userRole === 'teacher' ? 'teacher' : 'course-selection')}
                className="cursor-pointer focus:outline-none"
              >
                <BilimYolLogo size="md" />
              </button>

              {/* Desktop Navigation */}
              <div className="hidden md:flex items-center gap-1 pl-4 border-l border-slate-200">
                {userRole === 'student' &&
                  studentNavLinks.map((link) => {
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

                {userRole === 'parent' && (
                  <button
                    onClick={() => onNavigate('parent')}
                    className="flex items-center gap-2 px-3 py-2 rounded-xl text-sm font-semibold bg-emerald-50 text-emerald-700"
                  >
                    <Users className="w-4 h-4" />
                    <span>Ota-ona Paneli</span>
                  </button>
                )}

                {userRole === 'teacher' && (
                  <button
                    onClick={() => onNavigate('teacher')}
                    className="flex items-center gap-2 px-3 py-2 rounded-xl text-sm font-semibold bg-blue-50 text-blue-700"
                  >
                    <GraduationCap className="w-4 h-4" />
                    <span>O‘qituvchi Paneli</span>
                  </button>
                )}

                {userRole === 'admin' && (
                  <button
                    onClick={() => onNavigate('admin')}
                    className="flex items-center gap-2 px-3 py-2 rounded-xl text-sm font-semibold bg-purple-50 text-purple-700 border border-purple-200"
                  >
                    <ShieldAlert className="w-4 h-4 text-purple-600" />
                    <span>Boshqaruv (Admin)</span>
                  </button>
                )}
              </div>
            </div>

            {/* Right Status (Role Badge + Stats + Profile) */}
            <div className="flex items-center gap-2.5">
              {/* Role Indicator Badge */}
              <div className="flex items-center px-2.5 py-1 rounded-xl text-xs font-semibold border">
                {userRole === 'student' && (
                  <span className="text-blue-700 bg-blue-50 border-blue-200 px-2 py-0.5 rounded-lg border">
                    🎓 O‘quvchi
                  </span>
                )}
                {userRole === 'parent' && (
                  <span className="text-emerald-700 bg-emerald-50 border-emerald-200 px-2 py-0.5 rounded-lg border">
                    👨‍👩‍👧 Ota-ona
                  </span>
                )}
                {userRole === 'teacher' && (
                  <span className="text-indigo-700 bg-indigo-50 border-indigo-200 px-2 py-0.5 rounded-lg border">
                    👨‍🏫 O‘qituvchi
                  </span>
                )}
                {userRole === 'admin' && (
                  <span className="text-purple-700 bg-purple-50 border-purple-200 px-2 py-0.5 rounded-lg border flex items-center gap-1 font-bold">
                    ⚡ Administrator
                  </span>
                )}
              </div>

              {/* Student Connection Trigger */}
              {userRole === 'student' && (
                <button
                  onClick={() => setIsConnectionsModalOpen(true)}
                  className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-blue-50 hover:bg-blue-100 border border-blue-200 text-xs font-bold text-blue-700 transition-colors shadow-xs"
                  title="Ota-ona yoki Sinfga Ulanish"
                >
                  <Link2 className="w-3.5 h-3.5 text-blue-600" />
                  <span>Ulanish</span>
                </button>
              )}

              {activeCourse && userRole === 'student' && (
                <div className="hidden lg:flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-slate-100 border border-slate-200/80 text-xs font-semibold text-slate-700">
                  <span className="w-2 h-2 rounded-full bg-blue-600 animate-pulse" />
                  <span>{activeCourse.title}</span>
                </div>
              )}

              {userRole === 'student' && (
                <>
                  <div className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl bg-amber-50 border border-amber-200/80 text-xs font-bold text-amber-800">
                    <Flame className="w-3.5 h-3.5 text-amber-500 fill-amber-500" />
                    <span>{profile?.streakDays ?? 1} kun</span>
                  </div>

                  <div className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl bg-blue-50 border border-blue-200/80 text-xs font-bold text-blue-700">
                    <Award className="w-3.5 h-3.5 text-blue-600" />
                    <span>{profile?.xp ?? 0} XP</span>
                  </div>
                </>
              )}

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
                  {authProfile?.firstName?.charAt(0) || 'F'}
                </div>
                <span className="hidden md:inline text-xs font-bold">
                  {authProfile?.firstName || 'Profil'}
                </span>
              </button>
            </div>
          </div>

          {/* Mobile Navigation bar */}
          <div className="md:hidden flex items-center justify-around py-2 border-t border-slate-100">
            {userRole === 'student' &&
              studentNavLinks.map((link) => {
                const Icon = link.icon;
                const isActive = currentView === link.id;
                return (
                  <button
                    key={link.id}
                    onClick={() => onNavigate(link.id)}
                    className={`flex flex-col items-center gap-1 py-1 px-3 rounded-lg text-[11px] font-semibold cursor-pointer ${
                      isActive ? 'text-blue-600' : 'text-slate-500'
                    }`}
                  >
                    <Icon className="w-4 h-4" />
                    <span>{link.label}</span>
                  </button>
                );
              })}

            {userRole === 'parent' && (
              <button
                onClick={() => onNavigate('parent')}
                className="flex items-center gap-2 py-1 px-3 text-xs font-bold text-emerald-600"
              >
                <Users className="w-4 h-4" />
                <span>Ota-ona Paneli</span>
              </button>
            )}

            {userRole === 'teacher' && (
              <button
                onClick={() => onNavigate('teacher')}
                className="flex items-center gap-2 py-1 px-3 text-xs font-bold text-blue-600"
              >
                <GraduationCap className="w-4 h-4" />
                <span>O‘qituvchi Paneli</span>
              </button>
            )}
          </div>
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
