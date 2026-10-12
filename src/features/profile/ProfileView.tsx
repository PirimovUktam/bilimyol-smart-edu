import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { User, Mail, Award, Flame, BookOpen, Moon, Sun, Bell, LogOut, CheckCircle2, Save } from 'lucide-react';
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
  const [darkMode, setDarkMode] = useState(false);
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
        <Card className="p-6 sm:p-8 shadow-md border-slate-200">
          <div className="flex flex-col sm:flex-row items-center sm:items-start gap-5">
            <div className="w-20 h-20 rounded-3xl bg-gradient-to-br from-blue-600 to-indigo-600 text-white font-extrabold text-2xl flex items-center justify-center shadow-lg shadow-blue-500/20 shrink-0">
              {profile?.firstName?.charAt(0)?.toUpperCase() || 'U'}
              {profile?.lastName?.charAt(0)?.toUpperCase() || ''}
            </div>

            <div className="space-y-1.5 text-center sm:text-left flex-1">
              <div className="flex flex-col sm:flex-row sm:items-center gap-2">
                <h1 className="text-xl sm:text-2xl font-extrabold text-slate-900">
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
              <p className="text-xs sm:text-sm text-slate-500 flex items-center justify-center sm:justify-start gap-1.5 font-medium">
                <Mail className="w-3.5 h-3.5" />
                {profile?.email}
              </p>
            </div>

            <Button
              variant="outline"
              size="sm"
              onClick={handleLogout}
              leftIcon={<LogOut className="w-4 h-4 text-rose-500" />}
              className="text-rose-600 hover:bg-rose-50 border-rose-200"
            >
              Chiqish
            </Button>
          </div>
        </Card>
      </motion.div>

      {/* Learning Stats Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <Card className="p-5 border-slate-200 flex items-center gap-4">
          <div className="w-12 h-12 rounded-2xl bg-amber-50 text-amber-600 flex items-center justify-center shrink-0">
            <Award className="w-6 h-6" />
          </div>
          <div>
            <div className="text-xl font-extrabold text-slate-900">
              {learnerProfile?.xp ?? 120} XP
            </div>
            <div className="text-xs text-slate-500 font-semibold">Umumiy Tajriba</div>
          </div>
        </Card>

        <Card className="p-5 border-slate-200 flex items-center gap-4">
          <div className="w-12 h-12 rounded-2xl bg-orange-50 text-orange-600 flex items-center justify-center shrink-0">
            <Flame className="w-6 h-6" />
          </div>
          <div>
            <div className="text-xl font-extrabold text-slate-900">
              {learnerProfile?.streakDays ?? 3} kun
            </div>
            <div className="text-xs text-slate-500 font-semibold">Uzluksiz Streak</div>
          </div>
        </Card>

        <Card className="p-5 border-slate-200 flex items-center gap-4">
          <div className="w-12 h-12 rounded-2xl bg-teal-50 text-teal-600 flex items-center justify-center shrink-0">
            <BookOpen className="w-6 h-6" />
          </div>
          <div>
            <div className="text-xl font-extrabold text-slate-900">
              {activeCourse?.title || 'Matematika'}
            </div>
            <div className="text-xs text-slate-500 font-semibold">Joriy Fan</div>
          </div>
        </Card>
      </div>

      {/* Profile Details & Preferences */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Personal Details Form */}
        <Card className="p-6 border-slate-200 space-y-5">
          <h2 className="text-base font-extrabold text-slate-900 flex items-center gap-2">
            <User className="w-4 h-4 text-blue-600" />
            Shaxsiy Ma’lumotlar
          </h2>

          <form onSubmit={handleSaveProfile} className="space-y-4">
            {savedSuccess && (
              <div className="p-3 bg-emerald-50 border border-emerald-200 rounded-xl flex items-center gap-2 text-emerald-700 text-xs font-semibold">
                <CheckCircle2 className="w-4 h-4" />
                Ma’lumotlar muvaffaqiyatli saqlandi!
              </div>
            )}

            <div>
              <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                Ism
              </label>
              <input
                type="text"
                value={firstName}
                onChange={(e) => setFirstName(e.target.value)}
                className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-900 focus:bg-white focus:border-blue-600 outline-none"
                required
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                Familiya
              </label>
              <input
                type="text"
                value={lastName}
                onChange={(e) => setLastName(e.target.value)}
                className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm text-slate-900 focus:bg-white focus:border-blue-600 outline-none"
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1.5">
                Email
              </label>
              <input
                type="email"
                value={profile?.email || ''}
                disabled
                className="w-full px-3.5 py-2.5 bg-slate-100 border border-slate-200 rounded-xl text-sm text-slate-500 cursor-not-allowed"
              />
            </div>

            <Button
              type="submit"
              variant="primary"
              size="md"
              isLoading={isSaving}
              leftIcon={<Save className="w-4 h-4" />}
            >
              O‘zgarishlarni Saqlash
            </Button>
          </form>
        </Card>

        {/* System Settings & Preferences */}
        <Card className="p-6 border-slate-200 space-y-5">
          <h2 className="text-base font-extrabold text-slate-900 flex items-center gap-2">
            <Sun className="w-4 h-4 text-amber-500" />
            Tizim Sozlamalari
          </h2>

          <div className="space-y-4">
            {/* Dark mode switch */}
            <div className="flex items-center justify-between p-3.5 rounded-2xl bg-slate-50 border border-slate-200">
              <div className="flex items-center gap-3">
                {darkMode ? (
                  <Moon className="w-5 h-5 text-indigo-600" />
                ) : (
                  <Sun className="w-5 h-5 text-amber-500" />
                )}
                <div>
                  <div className="text-sm font-bold text-slate-900">Qorong‘i rejim</div>
                  <div className="text-xs text-slate-500">Kechki payt ko‘zni charchatmaslik uchun</div>
                </div>
              </div>

              <button
                type="button"
                onClick={() => setDarkMode(!darkMode)}
                className={`w-12 h-6 flex items-center rounded-full p-1 transition-colors cursor-pointer ${
                  darkMode ? 'bg-blue-600 justify-end' : 'bg-slate-300 justify-start'
                }`}
              >
                <div className="w-4 h-4 bg-white rounded-full shadow-xs" />
              </button>
            </div>

            {/* Notifications switch */}
            <div className="flex items-center justify-between p-3.5 rounded-2xl bg-slate-50 border border-slate-200">
              <div className="flex items-center gap-3">
                <Bell className="w-5 h-5 text-teal-600" />
                <div>
                  <div className="text-sm font-bold text-slate-900">Kunlik eslatmalar</div>
                  <div className="text-xs text-slate-500">15 daqiqalik o‘quv vaqtini eslatish</div>
                </div>
              </div>

              <button
                type="button"
                onClick={() => setNotifications(!notifications)}
                className={`w-12 h-6 flex items-center rounded-full p-1 transition-colors cursor-pointer ${
                  notifications ? 'bg-teal-600 justify-end' : 'bg-slate-300 justify-start'
                }`}
              >
                <div className="w-4 h-4 bg-white rounded-full shadow-xs" />
              </button>
            </div>

            <div className="p-4 bg-blue-50/60 rounded-2xl border border-blue-100 text-xs text-blue-800 space-y-1">
              <div className="font-bold">Cross-Platform Sinxronizatsiya</div>
              <p className="text-blue-700 leading-relaxed">
                Ushbu hisob bilan Flutter mobil ilovamizga kirsangiz, barcha progress va bilim ballaringiz avtomatik sinxronlanadi.
              </p>
            </div>
          </div>
        </Card>
      </div>
    </div>
  );
};
