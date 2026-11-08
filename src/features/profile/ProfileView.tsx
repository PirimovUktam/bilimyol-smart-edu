import { useEffect, useState, type FormEvent } from 'react';
import { Bell, BookOpen, KeyRound, LogOut, Save, ShieldCheck, Sparkles } from 'lucide-react';
import { useAuth } from '@/core/context/AuthContext';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { useCourseStore } from '@/app/store/useCourseStore';
import { supabaseLearnerRepository } from '@/data/repositories/SupabaseLearnerRepository';
import type { DailyTimeCommitment, InitialLevel, OnboardingGoal } from '@/core/types/common';
import type { LearnerProfile } from '@/domain/entities/LearnerProfile';
import type { Course } from '@/domain/entities/Course';
import { Avatar } from '@/presentation/components/Avatar';
import { Badge } from '@/presentation/components/Badge';
import { Button } from '@/presentation/components/Button';
import { Card } from '@/presentation/components/Card';
import { Modal } from '@/presentation/components/Modal';
import { PageHeader } from '@/presentation/components/PageHeader';

interface ProfileViewProps {
  onSignOut: () => void;
  onChooseSubject: () => void;
  onOpenLearningPlan: () => void;
}

export function ProfileView({ onSignOut, onChooseSubject, onOpenLearningPlan }: ProfileViewProps) {
  const { profile, updateProfile, signOut, resetPassword, isDemoMode } = useAuth();
  const learner = useLearnerStore((state) => state.profile);
  const course = useCourseStore((state) => state.activeCourse);
  const [firstName, setFirstName] = useState(profile?.firstName ?? '');
  const [lastName, setLastName] = useState(profile?.lastName ?? '');
  const [profileStatus, setProfileStatus] = useState('');
  const [profileError, setProfileError] = useState('');
  const [securityStatus, setSecurityStatus] = useState('');
  const [securityError, setSecurityError] = useState('');
  const [saving, setSaving] = useState(false);
  const [securityAction, setSecurityAction] = useState<'email' | 'exit' | null>(null);
  const [confirmExit, setConfirmExit] = useState(false);
  const isAdmin = profile?.role === 'admin';
  const name = [profile?.firstName, profile?.lastName].filter(Boolean).join(' ');

  const saveProfile = async (event: FormEvent) => {
    event.preventDefault();
    setProfileStatus('');
    setProfileError('');
    if (!firstName.trim()) return setProfileError('Ism bo‘sh qolmasligi kerak.');
    setSaving(true);
    try {
      const { error } = await updateProfile({ firstName: firstName.trim(), lastName: lastName.trim() });
      if (error) setProfileError(error.message);
      else setProfileStatus('Profil saqlandi.');
    } catch {
      setProfileError('Profilni saqlab bo‘lmadi.');
    } finally {
      setSaving(false);
    }
  };

  const requestRecovery = async () => {
    if (!profile?.email) return;
    setSecurityStatus('');
    setSecurityError('');
    setSecurityAction('email');
    try {
      const { error } = await resetPassword(profile.email);
      if (error) setSecurityError(error.message);
      else setSecurityStatus('Parolni yangilash uchun pochtangizdagi havolani oching.');
    } finally {
      setSecurityAction(null);
    }
  };

  const exit = async (scope: 'local' | 'global') => {
    setSecurityError('');
    setSecurityAction('exit');
    try {
      await signOut(scope);
      onSignOut();
    } catch {
      setSecurityError('Sessiyani tugatib bo‘lmadi. Qayta urinib ko‘ring.');
      setConfirmExit(false);
    } finally {
      setSecurityAction(null);
    }
  };

  return (
    <div className="learning-page space-y-6 sm:space-y-8">
      <PageHeader
        eyebrow={isDemoMode ? 'Namuna hisobi' : 'Hisob sozlamalari'}
        title="Profil"
        description="Hisobingiz va o‘rganish sozlamalarini boshqaring."
      />

      <Card className="fade-up stagger-1 flex flex-wrap items-center gap-4 bg-gradient-to-r from-white via-white to-indigo-50/50" padding="md">
        <Avatar name={name} className="size-15! text-lg! shadow-sm" />
        <div className="min-w-0 flex-1 space-y-1">
          <div className="flex flex-wrap items-center gap-2">
            <h2 className="heading break-words text-xl font-extrabold">{name || 'O‘quvchi'}</h2>
            <Badge variant="emerald" size="sm">
              {isDemoMode ? 'Namuna' : isAdmin ? 'Admin' : 'O‘quvchi'}
            </Badge>
          </div>
          <p className="break-all text-sm font-medium text-slatefine">{profile?.email}</p>
        </div>
        <Button
          variant="outline"
          isLoading={securityAction === 'exit'}
          disabled={securityAction !== null}
          onClick={() => void exit('local')}
          leftIcon={<LogOut aria-hidden="true" className="size-4" />}
        >
          Chiqish
        </Button>
      </Card>

      <div className="grid gap-5 lg:grid-cols-2">
        <Card className="fade-up stagger-2 space-y-4" padding="md">
          <div>
            <span className="highlight mb-1.5">Shaxsiy karta</span>
            <h2 className="heading text-lg font-extrabold">
              Shaxsiy <span className="heading-accent">ma’lumotlar</span>
            </h2>
          </div>
          <form onSubmit={saveProfile} className="space-y-3.5">
            <label className="block text-sm font-bold">
              Ism
              <input
                className="form-input mt-1.5 px-3.5 font-normal"
                required
                maxLength={80}
                autoComplete="given-name"
                value={firstName}
                onChange={(event) => setFirstName(event.target.value)}
              />
            </label>
            <label className="block text-sm font-bold">
              Familiya
              <input
                className="form-input mt-1.5 px-3.5 font-normal"
                maxLength={80}
                autoComplete="family-name"
                value={lastName}
                onChange={(event) => setLastName(event.target.value)}
              />
            </label>
            <Feedback error={profileError} status={profileStatus} />
            <Button type="submit" isLoading={saving} leftIcon={<Save aria-hidden="true" className="size-4" />}>
              Profilni saqlash
            </Button>
          </form>
        </Card>

        {!isAdmin && learner && (
          <LearningPreferences
            learner={learner}
            course={course}
            onChooseSubject={onChooseSubject}
            onOpenLearningPlan={onOpenLearningPlan}
          />
        )}

        {!isAdmin && <ReminderPreferences />}

        <Card className="fade-up stagger-4 space-y-4" padding="md">
          <div>
            <span className="highlight mb-1.5">Himoya</span>
            <h2 className="heading flex items-center gap-2 text-lg font-extrabold">
              <ShieldCheck aria-hidden="true" className="size-5 text-brand" /> Hisob <span className="heading-accent">xavfsizligi</span>
            </h2>
          </div>
          {isDemoMode ? (
            <p className="text-sm text-slatefine">Parol va qurilmalar sozlamalari shaxsiy hisobda mavjud.</p>
          ) : (
            <div className="flex flex-wrap gap-2.5">
              <Button
                variant="outline"
                isLoading={securityAction === 'email'}
                disabled={securityAction !== null}
                onClick={() => void requestRecovery()}
                leftIcon={<KeyRound aria-hidden="true" className="size-4" />}
              >
                Parolni yangilash
              </Button>
              <Button variant="ghost" onClick={() => setConfirmExit(true)} disabled={securityAction !== null}>
                Barcha qurilmalardan chiqish
              </Button>
            </div>
          )}
          <Feedback error={securityError} status={securityStatus} />
        </Card>
      </div>

      <Modal
        isOpen={confirmExit}
        title="Barcha qurilmalardan chiqasizmi?"
        maxWidth="sm"
        dismissable={securityAction !== 'exit'}
        onClose={() => setConfirmExit(false)}
      >
        <p className="mb-4 text-sm leading-relaxed text-slatefine">Bu qurilmada ham qayta kirishingiz kerak bo‘ladi.</p>
        <div className="flex flex-wrap justify-end gap-2">
          <Button variant="ghost" disabled={securityAction === 'exit'} onClick={() => setConfirmExit(false)}>
            Bekor qilish
          </Button>
          <Button variant="danger" isLoading={securityAction === 'exit'} onClick={() => void exit('global')}>
            Chiqish
          </Button>
        </div>
      </Modal>
    </div>
  );
}

const goals: Record<OnboardingGoal, string> = {
  mastery: 'Bilimni mustahkamlash',
  exam_prep: 'Imtihonga tayyorlanish',
  skills_boost: 'Ko‘nikmalarni rivojlantirish',
};
const levels: Record<InitialLevel, string> = { beginner: 'Boshlang‘ich', intermediate: 'O‘rta', advanced: 'Yuqori' };

function LearningPreferences({ learner, course, onChooseSubject, onOpenLearningPlan }: {
  learner: LearnerProfile; course: Course | null; onChooseSubject: () => void; onOpenLearningPlan: () => void;
}) {
  const [goal, setGoal] = useState(learner.goal);
  const [minutes, setMinutes] = useState(learner.dailyMinutes);
  const level = course ? learner.courseLevels?.[course.id] : undefined;
  const [saving, setSaving] = useState(false);
  const [status, setStatus] = useState('');
  const [error, setError] = useState('');

  const save = async (event: FormEvent) => {
    event.preventDefault();
    setStatus('');
    setError('');
    setSaving(true);
    try {
      await useLearnerStore.getState().saveStudyPreferences(goal, minutes);
      setStatus('O‘rganish sozlamalari saqlandi.');
    } catch {
      setError('O‘rganish sozlamalarini saqlab bo‘lmadi.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <Card className="fade-up stagger-3 space-y-4" padding="md">
      <div>
        <span className="highlight mb-1.5">
          <Sparkles aria-hidden="true" className="size-3.5" />
          Moslashtirish
        </span>
        <h2 className="heading text-lg font-extrabold">
          O‘rganish <span className="heading-accent">sozlamalari</span>
        </h2>
      </div>
      <div className="flex flex-wrap items-center justify-between gap-2 rounded-2xl border border-hairline bg-canvas/80 p-3">
        <span className="inline-flex items-center gap-2 text-sm font-bold text-ink">
          <BookOpen aria-hidden="true" className="size-4 shrink-0 text-brand" />
          {course?.title ?? 'Fan tanlanmagan'}
        </span>
        <div className="flex flex-wrap gap-1.5">
          <Button variant="ghost" size="sm" onClick={onChooseSubject}>
            Fanni almashtirish
          </Button>
          {course && (
            <Button variant="outline" size="sm" onClick={onOpenLearningPlan}>
              {level ? levels[level] + ' · Darajani sozlash' : 'Darajani tanlash'}
            </Button>
          )}
        </div>
      </div>
      <form onSubmit={save} className="grid gap-3.5 sm:grid-cols-2">
        <div className="text-sm sm:col-span-2">
          <label className="font-bold" htmlFor="profile-goal">
            Maqsad
          </label>
          <select
            id="profile-goal"
            className="form-input mt-1.5 px-3"
            value={goal}
            onChange={(event) => setGoal(event.target.value as OnboardingGoal)}
          >
            {Object.entries(goals).map(([value, label]) => (
              <option key={value} value={value}>
                {label}
              </option>
            ))}
          </select>
        </div>
        <div className="text-sm">
          <label className="font-bold" htmlFor="profile-daily-minutes">
            Kunlik vaqt
          </label>
          <select
            id="profile-daily-minutes"
            className="form-input mt-1.5 px-3"
            value={minutes}
            onChange={(event) => setMinutes(Number(event.target.value) as DailyTimeCommitment)}
          >
            {[15, 30, 60].map((value) => (
              <option key={value} value={value}>
                {value} daqiqa
              </option>
            ))}
          </select>
        </div>
        <div className="space-y-3 sm:col-span-2">
          <Feedback error={error} status={status} />
          <Button type="submit" isLoading={saving}>
            Sozlamalarni saqlash
          </Button>
        </div>
      </form>
    </Card>
  );
}

function ReminderPreferences() {
  const [enabled, setEnabled] = useState<boolean | null>(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [retry, setRetry] = useState(0);

  useEffect(() => {
    let active = true;
    setError('');
    void supabaseLearnerRepository.getLearningReminders().then(
      (value) => { if (active) setEnabled(value); },
      () => { if (active) setError('Eslatma sozlamasi yuklanmadi.'); },
    );
    return () => { active = false; };
  }, [retry]);

  const toggle = async (next: boolean) => {
    setSaving(true);
    setError('');
    try {
      setEnabled(await supabaseLearnerRepository.setLearningReminders(next));
    } catch {
      setError('Eslatma sozlamasi saqlanmadi.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <Card className="fade-up stagger-3 space-y-3.5" padding="md">
      <div>
        <span className="highlight mb-1.5">Bildirishnoma</span>
        <h2 className="heading flex items-center gap-2 text-lg font-extrabold">
          <Bell aria-hidden="true" className="size-5 text-brand" /> Eslatmalar
        </h2>
      </div>
      <p className="text-sm text-slatefine">Kunlik maqsad bo‘yicha eslatma bosh sahifada ko‘rinadi.</p>
      {enabled == null ? (
        error ? (
          <Button variant="outline" onClick={() => setRetry((value) => value + 1)}>
            Qayta urinish
          </Button>
        ) : (
          <p role="status" className="text-sm text-slatefine">
            Sozlama yuklanmoqda…
          </p>
        )
      ) : (
        <label className="flex min-h-11 w-fit cursor-pointer items-center gap-3 text-sm font-bold">
          <input
            type="checkbox"
            checked={enabled}
            disabled={saving}
            className="size-5 accent-brand"
            onChange={(event) => void toggle(event.target.checked)}
          />{' '}
          Kunlik eslatmani ko‘rsatish
        </label>
      )}
      <Feedback error={error} status="" />
    </Card>
  );
}

function Feedback({ error, status }: { error: string; status: string }) {
  if (error) return <p role="alert" className="rounded-2xl bg-rose-50 p-3.5 text-sm text-coral">{error}</p>;
  if (status) return <p role="status" className="rounded-2xl bg-mint/10 p-3.5 text-sm font-semibold text-[#059669]">{status}</p>;
  return null;
}
