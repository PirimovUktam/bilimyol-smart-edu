import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { User, Mail, Award, Flame, BookOpen, LogOut, CheckCircle2, AlertCircle, Save, ShieldCheck } from 'lucide-react';
import { useAuth } from '../../core/context/AuthContext';
import { useLearnerStore } from '../../app/store/useLearnerStore';
import { useCourseStore } from '../../app/store/useCourseStore';
import { Button } from '../../presentation/components/Button';
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
  const [isSaving, setIsSaving] = useState(false);
  const [savedSuccess, setSavedSuccess] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);

  // Sync when profile loads
  useEffect(() => {
    setFirstName(profile?.firstName || '');
    setLastName(profile?.lastName || '');
  }, [profile?.firstName, profile?.lastName]);

  const handleSaveProfile = async (e: React.FormEvent) => {
    e.preventDefault();
    setSavedSuccess(false);
    setSaveError(null);
    setIsSaving(true);
    try {
      const result = await updateProfile({ firstName, lastName });
      if (result?.error) {
        setSaveError(result.error.message || 'Saqlashda xatolik yuz berdi.');
      } else {
        setSavedSuccess(true);
        setTimeout(() => setSavedSuccess(false), 2500);
      }
    } catch (err) {
      setSaveError(err instanceof Error ? err.message : 'Saqlashda xatolik yuz berdi.');
    } finally {
      setIsSaving(false);
    }
  };

  const handleLogout = async () => {
    await signOut();
    onSignOut();
  };

  return (
    <div className="max-w-5xl mx-auto px-4 py-8 space-y-6">
      {/* Profile Header Card */}
      <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }}>
        <div className="p-6 sm:p-8 rounded-2xl bg-white border border-[#e4ddce] shadow-xs relative overflow-hidden">
          {/* Top architectural accent strip */}
          <div className="absolute top-0 left-0 right-0 h-1.5 bg-[#10151f]" />

          <div className="flex flex-col sm:flex-row items-center sm:items-start gap-6 pt-1">
            <div className="w-20 h-20 rounded-2xl bg-[#10151f] text-white font-mono font-bold text-2xl flex items-center justify-center shadow-md shrink-0">
              {profile?.firstName?.charAt(0)?.toUpperCase() || 'U'}
              {profile?.lastName?.charAt(0)?.toUpperCase() || ''}
            </div>

            <div className="space-y-2 text-center sm:text-left flex-1">
              <div className="editorial-kicker justify-center sm:justify-start">
                <span>TALABA DOSYESI</span>
                <span>//</span>
                <span>STATUS: FAOLLASHTIRILGAN</span>
              </div>
              <div className="flex flex-col sm:flex-row sm:items-center gap-3">
                <h1 className="font-display text-2xl sm:text-3xl font-extrabold text-[#10151f]">
                  {profile?.firstName} {profile?.lastName}
                </h1>
                <Badge
                  variant={profile?.role === 'admin' ? 'purple' : 'slate'}
                  size="sm"
                >
                  {profile?.role === 'admin' ? 'ADMINISTRATOR' : 'FAOL TALABA'}
                </Badge>
              </div>
              <p className="font-mono text-xs text-slate-500 flex items-center justify-center sm:justify-start gap-1.5">
                <Mail className="w-3.5 h-3.5" />
                {profile?.email}
              </p>
            </div>

            <Button
              variant="outline"
              size="sm"
              onClick={handleLogout}
              leftIcon={<LogOut className="w-4 h-4 text-coral" />}
              className="text-coral hover:bg-coral/5 border-coral/25 font-mono text-xs font-bold"
            >
              Chiqish
            </Button>
          </div>
        </div>
      </motion.div>

      {/* Learning Stats Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="p-5 rounded-2xl bg-white border border-[#e4ddce] shadow-xs flex items-center gap-4">
          <div className="w-11 h-11 rounded-xl bg-[#fbf9f4] border border-[#e4ddce] text-slate-800 flex items-center justify-center shrink-0">
            <Award className="w-5 h-5 text-amber-500" />
          </div>
          <div>
            <div className="font-mono-num text-xl font-black text-[#10151f]">
              {learnerProfile?.xp ?? 0} <span className="text-xs font-sans font-bold">XP</span>
            </div>
            <div className="font-mono text-[10px] text-slate-500 uppercase tracking-wider font-bold">Jamg‘arilgan XP</div>
          </div>
        </div>

        <div className="p-5 rounded-2xl bg-white border border-[#e4ddce] shadow-xs flex items-center gap-4">
          <div className="w-11 h-11 rounded-xl bg-[#fbf9f4] border border-[#e4ddce] text-amber-600 flex items-center justify-center shrink-0">
            <Flame className="w-5 h-5 fill-amber-500" />
          </div>
          <div>
            <div className="font-mono-num text-xl font-black text-[#10151f]">
              {learnerProfile?.streakDays ?? 0} <span className="text-xs font-sans font-bold">kun</span>
            </div>
            <div className="font-mono text-[10px] text-slate-500 uppercase tracking-wider font-bold">Uzluksiz Streak</div>
          </div>
        </div>

        <div className="p-5 rounded-2xl bg-white border border-[#e4ddce] shadow-xs flex items-center gap-4">
          <div className="w-11 h-11 rounded-xl bg-[#fbf9f4] border border-[#e4ddce] text-brand-dark flex items-center justify-center shrink-0">
            <BookOpen className="w-5 h-5" />
          </div>
          <div>
            <div className="font-display text-lg font-bold text-[#10151f] truncate max-w-[170px]">
              {activeCourse?.title || 'Tanlanmagan'}
            </div>
            <div className="font-mono text-[10px] text-slate-500 uppercase tracking-wider font-bold">Faol Kurs</div>
          </div>
        </div>
      </div>

      {/* Profile Details & Preferences */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Personal Details Form */}
        <div className="p-6 rounded-2xl bg-white border border-[#e4ddce] shadow-xs space-y-5">
          <div className="flex items-center gap-2 pb-3 border-b border-[#e4ddce]">
            <User className="w-4 h-4 text-slate-700" />
            <h2 className="font-display text-base font-bold text-[#10151f]">
              Shaxsiy Ma’lumotlar
            </h2>
          </div>

          <form onSubmit={handleSaveProfile} className="space-y-4">
            {savedSuccess && (
              <div className="p-3 bg-mint/10 border border-mint/25 rounded-xl flex items-center gap-2 text-mint text-xs font-mono font-bold">
                <CheckCircle2 className="w-4 h-4 text-mint" />
                O‘ZGARISHLAR SAQLANDI!
              </div>
            )}

            {saveError && (
              <div className="p-3 bg-coral/5 border border-coral/25 rounded-xl flex items-center gap-2 text-coral text-xs font-mono font-bold">
                <AlertCircle className="w-4 h-4 shrink-0 text-coral" />
                {saveError}
              </div>
            )}

            <div>
              <label className="block font-mono text-[10px] font-bold text-slate-600 uppercase tracking-wider mb-1.5">
                Ism
              </label>
              <input
                type="text"
                value={firstName}
                onChange={(e) => setFirstName(e.target.value)}
                className="w-full px-3.5 py-2.5 bg-[#fbf9f4] border border-[#e4ddce] rounded-xl text-sm text-slate-900 focus:bg-white focus:border-[#10151f] focus:ring-2 focus:ring-[#10151f]/10 outline-none"
                required
              />
            </div>

            <div>
              <label className="block font-mono text-[10px] font-bold text-slate-600 uppercase tracking-wider mb-1.5">
                Familiya
              </label>
              <input
                type="text"
                value={lastName}
                onChange={(e) => setLastName(e.target.value)}
                className="w-full px-3.5 py-2.5 bg-[#fbf9f4] border border-[#e4ddce] rounded-xl text-sm text-slate-900 focus:bg-white focus:border-[#10151f] focus:ring-2 focus:ring-[#10151f]/10 outline-none"
              />
            </div>

            <div>
              <label className="block font-mono text-[10px] font-bold text-slate-600 uppercase tracking-wider mb-1.5">
                Email
              </label>
              <input
                type="email"
                value={profile?.email || ''}
                disabled
                className="w-full px-3.5 py-2.5 bg-[#f5efe4] border border-[#e4ddce] rounded-xl text-sm font-mono text-slate-500 cursor-not-allowed"
              />
            </div>

            <Button
              type="submit"
              variant="primary"
              size="md"
              isLoading={isSaving}
              leftIcon={<Save className="w-4 h-4" />}
              className="font-bold uppercase tracking-wider text-xs"
            >
              O‘zgarishlarni Saqlash
            </Button>
          </form>
        </div>

        {/* System Info */}
        <div className="p-6 rounded-2xl bg-white border border-[#e4ddce] shadow-xs space-y-5">
          <div className="flex items-center gap-2 pb-3 border-b border-[#e4ddce]">
            <ShieldCheck className="w-4 h-4 text-slate-700" />
            <h2 className="font-display text-base font-bold text-[#10151f]">
              Tizim va Xavfsizlik
            </h2>
          </div>

          <div className="space-y-3">
            {[
              { label: 'Hisob turi', value: profile?.role === 'admin' ? 'ADMINISTRATOR' : 'TALABA' },
              { label: 'Email', value: profile?.email || '—' },
              { label: 'Joriy kurs', value: activeCourse?.title || 'Tanlanmagan' },
              { label: 'Umumiy XP', value: `${learnerProfile?.xp ?? 0} XP` },
            ].map((row) => (
              <div key={row.label} className="flex items-center justify-between p-3 rounded-xl bg-[#fbf9f4] border border-[#e4ddce]">
                <span className="font-mono text-xs text-slate-500 font-bold uppercase">{row.label}</span>
                <span className="font-mono text-xs font-bold text-slate-900 text-right">{row.value}</span>
              </div>
            ))}

            <div className="p-4 bg-[#fbf9f4] rounded-xl border border-[#e4ddce] text-xs text-slate-700 space-y-1">
              <div className="font-mono text-[10px] font-bold text-slate-800 uppercase tracking-wider">
                Cross-Platform Sinxronizatsiya
              </div>
              <p className="text-slate-600 leading-relaxed font-sans text-xs">
                Ushbu hisob orqali web va Flutter mobil ilovasi o‘rtasida barcha progress va bilim ballaringiz sinxronlashadi.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
