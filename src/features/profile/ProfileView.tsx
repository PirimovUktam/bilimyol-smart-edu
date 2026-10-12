import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { User, Mail, Award, Flame, BookOpen, Moon, Sun, Bell, LogOut, CheckCircle2, Save, Smartphone, Shield } from 'lucide-react';
import { useAuth } from '../../core/context/AuthContext';
import { useLearnerStore } from '../../app/store/useLearnerStore';
import { useCourseStore } from '../../app/store/useCourseStore';
import { Button } from '../../presentation/components/Button';
import { Card } from '../../presentation/components/Card';
import { Badge } from '../../presentation/components/Badge';

interface ProfileViewProps {
  onSignOut: () => void;
}

export const ProfileView: React.FC<ProfileViewProps> = ({ onSignOut }) => {
  const { profile, updateProfile, signOut } = useAuth();
  const { profile: learnerProfile } = useLearnerStore();
  const { activeCourse } = useCourseStore();

  const [firstName, setFirstName] = useState(profile?.firstName || '');
  const [lastName, setLastName] = useState(profile?.lastName || '');
  const [darkMode, setDarkMode] = useState(true);
  const [notifications, setNotifications] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [savedSuccess, setSavedSuccess] = useState(false);

  const handleSaveProfile = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSaving(true);
    await updateProfile({ firstName, lastName });
    setIsSaving(false);
    setSavedSuccess(true);
    setTimeout(() => setSavedSuccess(false), 2500);
  };

  const handleLogout = async () => {
    await signOut();
    onSignOut();
  };

  return (
    <div className="max-w-4xl mx-auto px-4 py-8 space-y-6">
      {/* Profile Header Card */}
      <motion.div initial={{ opacity: 0, y: 15 }} animate={{ opacity: 1, y: 0 }}>
        <Card variant="cosmicGlow" className="p-6 sm:p-8 bg-slate-900/90">
          <div className="flex flex-col sm:flex-row items-center sm:items-start gap-5">
            <div className="relative">
              <div className="w-20 h-20 rounded-3xl bg-gradient-to-br from-cyan-500 via-indigo-600 to-purple-600 text-white font-black text-2xl flex items-center justify-center shadow-lg shadow-cyan-500/30 shrink-0 ring-2 ring-cyan-400/50">
                {profile?.firstName?.charAt(0)?.toUpperCase() || 'U'}
                {profile?.lastName?.charAt(0)?.toUpperCase() || ''}
              </div>
              <div className="absolute -bottom-1 -right-1 w-6 h-6 rounded-full bg-emerald-500 border-2 border-slate-900 flex items-center justify-center shadow-xs">
                <div className="w-2 h-2 rounded-full bg-white animate-pulse" />
              </div>
            </div>

            <div className="space-y-1.5 text-center sm:text-left flex-1">
              <div className="flex flex-col sm:flex-row sm:items-center gap-2.5">
                <h1 className="text-xl sm:text-2xl font-black text-white tracking-tight">
                  {profile?.firstName} {profile?.lastName}
                </h1>
                <Badge
                  variant={
                    profile?.role === 'admin'
                      ? 'purple'
                      : profile?.role === 'teacher'
                      ? 'blue'
                      : profile?.role === 'parent'
                      ? 'emerald'
                      : 'blue'
                  }
                  size="sm"
                  className="bg-cyan-950/80 text-cyan-300 border-cyan-500/40 shadow-xs"
                >
                  {profile?.role === 'admin'
                    ? '⚡ Administrator'
                    : profile?.role === 'teacher'
                    ? '👨‍🏫 O‘qituvchi'
                    : profile?.role === 'parent'
                    ? '👨‍👩‍👧 Ota-ona'
                    : '🎓 Faol O‘quvchi'}
                </Badge>
              </div>
              <p className="text-xs sm:text-sm text-slate-400 flex items-center justify-center sm:justify-start gap-1.5 font-medium">
                <Mail className="w-3.5 h-3.5 text-cyan-400" />
                {profile?.email}
              </p>
            </div>

            <Button
              variant="outline"
              size="sm"
              onClick={handleLogout}
              leftIcon={<LogOut className="w-4 h-4 text-rose-400" />}
              className="text-rose-400 hover:bg-rose-950/40 border-rose-500/30 bg-slate-900/60"
            >
              Chiqish
            </Button>
          </div>
        </Card>
      </motion.div>

      {/* Learning Stats Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <Card variant="neonPurple" className="p-5 bg-slate-900/80 flex items-center gap-4">
          <div className="w-12 h-12 rounded-2xl bg-purple-500/10 text-purple-400 border border-purple-500/30 flex items-center justify-center shrink-0 shadow-sm shadow-purple-500/20">
            <Award className="w-6 h-6" />
          </div>
          <div>
            <div className="text-xl font-black text-white">
              {learnerProfile?.xp ?? 120} XP
            </div>
            <div className="text-xs text-slate-400 font-semibold">Umumiy Tajriba</div>
          </div>
        </Card>

        <Card variant="neonAmber" className="p-5 bg-slate-900/80 flex items-center gap-4">
          <div className="w-12 h-12 rounded-2xl bg-amber-500/10 text-amber-400 border border-amber-500/30 flex items-center justify-center shrink-0 shadow-sm shadow-amber-500/20">
            <Flame className="w-6 h-6 fill-amber-400" />
          </div>
          <div>
            <div className="text-xl font-black text-white">
              {learnerProfile?.streakDays ?? 3} kun
            </div>
            <div className="text-xs text-slate-400 font-semibold">Uzluksiz Streak 🔥</div>
          </div>
        </Card>

        <Card variant="neonCyan" className="p-5 bg-slate-900/80 flex items-center gap-4">
          <div className="w-12 h-12 rounded-2xl bg-cyan-500/10 text-cyan-400 border border-cyan-500/30 flex items-center justify-center shrink-0 shadow-sm shadow-cyan-500/20">
            <BookOpen className="w-6 h-6" />
          </div>
          <div>
            <div className="text-xl font-black text-white">
              {activeCourse?.title || 'Matematika'}
            </div>
            <div className="text-xs text-slate-400 font-semibold">Joriy Fan</div>
          </div>
        </Card>
      </div>

      {/* Profile Details & Preferences */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Personal Details Form */}
        <Card variant="cosmic" className="p-6 bg-slate-900/85 space-y-5">
          <h2 className="text-base font-extrabold text-white flex items-center gap-2">
            <User className="w-4 h-4 text-cyan-400" />
            Shaxsiy Ma’lumotlar
          </h2>

          <form onSubmit={handleSaveProfile} className="space-y-4">
            {savedSuccess && (
              <div className="p-3 bg-emerald-950/60 border border-emerald-500/40 rounded-xl flex items-center gap-2 text-emerald-300 text-xs font-semibold">
                <CheckCircle2 className="w-4 h-4 text-emerald-400" />
                Ma’lumotlar muvaffaqiyatli saqlandi!
              </div>
            )}

            <div>
              <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider mb-1.5">
                Ism
              </label>
              <input
                type="text"
                value={firstName}
                onChange={(e) => setFirstName(e.target.value)}
                className="w-full px-3.5 py-2.5 bg-slate-950/80 border border-slate-700 rounded-xl text-sm text-white focus:border-cyan-400 focus:ring-1 focus:ring-cyan-400 outline-none transition-all"
                required
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider mb-1.5">
                Familiya
              </label>
              <input
                type="text"
                value={lastName}
                onChange={(e) => setLastName(e.target.value)}
                className="w-full px-3.5 py-2.5 bg-slate-950/80 border border-slate-700 rounded-xl text-sm text-white focus:border-cyan-400 focus:ring-1 focus:ring-cyan-400 outline-none transition-all"
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider mb-1.5">
                Email
              </label>
              <input
                type="email"
                value={profile?.email || ''}
                disabled
                className="w-full px-3.5 py-2.5 bg-slate-950/40 border border-slate-800 rounded-xl text-sm text-slate-500 cursor-not-allowed"
              />
            </div>

            <Button
              type="submit"
              variant="cyan"
              size="md"
              isLoading={isSaving}
              leftIcon={<Save className="w-4 h-4" />}
              className="w-full font-bold"
            >
              O‘zgarishlarni Saqlash
            </Button>
          </form>
        </Card>

        {/* System Settings & Preferences */}
        <Card variant="cosmic" className="p-6 bg-slate-900/85 space-y-5">
          <h2 className="text-base font-extrabold text-white flex items-center gap-2">
            <Sun className="w-4 h-4 text-amber-400" />
            Tizim Sozlamalari
          </h2>

          <div className="space-y-4">
            {/* Dark mode switch */}
            <div className="flex items-center justify-between p-3.5 rounded-2xl bg-slate-950/60 border border-slate-800">
              <div className="flex items-center gap-3">
                <Moon className="w-5 h-5 text-cyan-400" />
                <div>
                  <div className="text-sm font-bold text-white">Qorong‘i kiber rejim</div>
                  <div className="text-xs text-slate-400">Ko‘zni asrash va diqqatni jamlash uchun</div>
                </div>
              </div>

              <button
                type="button"
                onClick={() => setDarkMode(!darkMode)}
                className={`w-12 h-6 flex items-center rounded-full p-1 transition-colors cursor-pointer ${
                  darkMode ? 'bg-cyan-500 justify-end' : 'bg-slate-700 justify-start'
                }`}
              >
                <div className="w-4 h-4 bg-slate-950 rounded-full shadow-xs" />
              </button>
            </div>

            {/* Notifications switch */}
            <div className="flex items-center justify-between p-3.5 rounded-2xl bg-slate-950/60 border border-slate-800">
              <div className="flex items-center gap-3">
                <Bell className="w-5 h-5 text-emerald-400" />
                <div>
                  <div className="text-sm font-bold text-white">Kunlik eslatmalar</div>
                  <div className="text-xs text-slate-400">15 daqiqalik o‘quv vaqtini eslatish</div>
                </div>
              </div>

              <button
                type="button"
                onClick={() => setNotifications(!notifications)}
                className={`w-12 h-6 flex items-center rounded-full p-1 transition-colors cursor-pointer ${
                  notifications ? 'bg-emerald-500 justify-end' : 'bg-slate-700 justify-start'
                }`}
              >
                <div className="w-4 h-4 bg-slate-950 rounded-full shadow-xs" />
              </button>
            </div>

            <div className="p-4 bg-cyan-950/30 rounded-2xl border border-cyan-500/30 text-xs text-cyan-300 space-y-1.5">
              <div className="font-bold flex items-center gap-1.5 text-white">
                <Smartphone className="w-4 h-4 text-cyan-400" />
                Cross-Platform Sinxronizatsiya
              </div>
              <p className="text-slate-300 leading-relaxed">
                Ushbu hisob bilan Flutter mobil ilovamizga kirsangiz, barcha progress, Streak va bilim ballaringiz avtomatik sinxronlanadi.
              </p>
            </div>
          </div>
        </Card>
      </div>
    </div>
  );
};

