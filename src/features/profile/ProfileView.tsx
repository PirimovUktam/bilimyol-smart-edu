import { translate as t } from '@/core/locales/useTranslation';
import { useTranslation } from '@/core/locales/useTranslation';
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
  const { t } = useTranslation();
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
    if (!firstName.trim()) return setProfileError(t('profile.nameRequired'));
    setSaving(true);
    try {
      const { error } = await updateProfile({ firstName: firstName.trim(), lastName: lastName.trim() });
      if (error) setProfileError(error.message);
      else setProfileStatus(t('profile.saved'));
    } catch {
      setProfileError(t('profile.failed'));
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
      else setSecurityStatus(t('profile.passwordMail'));
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
      setSecurityError(t('profile.logoutFailed'));
      setConfirmExit(false);
    } finally {
      setSecurityAction(null);
    }
  };

  return (
    <div className="learning-page space-y-6 sm:space-y-8">
      <PageHeader
        eyebrow={isDemoMode ? t('profile.demo') : t('profile.settings')}
        title={t('profile.profile')}
        description={t('profile.description')}
      />

      <Card className="fade-up stagger-1 flex flex-wrap items-center gap-4 bg-gradient-to-r from-white via-white to-indigo-50/50" padding="md">
        <Avatar name={name} className="size-15! text-lg! shadow-sm" />
        <div className="min-w-0 flex-1 space-y-1">
          <div className="flex flex-wrap items-center gap-2">
            <h2 className="heading break-words text-xl font-extrabold">{name || t('courses.student')}</h2>
            <Badge variant="emerald" size="sm">
              {isDemoMode ? 'Namuna' : isAdmin ? 'Admin' : t('courses.student')}
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
        >{t('profile.logout')}</Button>
      </Card>

      <div className="grid gap-5 lg:grid-cols-2">
        <Card className="fade-up stagger-2 space-y-4" padding="md">
          <div>
            <span className="highlight mb-1.5">{t('profile.card')}</span>
            <h2 className="heading text-lg font-extrabold">{t('profile.personal')}{' '}<span className="heading-accent">{t('profile.details')}</span>
            </h2>
          </div>
          <form onSubmit={saveProfile} className="space-y-3.5">
            <label className="block text-sm font-bold">{t('profile.firstName')}<input
                className="form-input mt-1.5 px-3.5 font-normal"
                required
                maxLength={80}
                autoComplete="given-name"
                value={firstName}
                onChange={(event) => setFirstName(event.target.value)}
              />
            </label>
            <label className="block text-sm font-bold">{t('profile.lastName')}<input
                className="form-input mt-1.5 px-3.5 font-normal"
                maxLength={80}
                autoComplete="family-name"
                value={lastName}
                onChange={(event) => setLastName(event.target.value)}
              />
            </label>
            <Feedback error={profileError} status={profileStatus} />
            <Button type="submit" isLoading={saving} leftIcon={<Save aria-hidden="true" className="size-4" />}>{t('profile.save')}</Button>
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
            <span className="highlight mb-1.5">{t('profile.protection')}</span>
            <h2 className="heading flex items-center gap-2 text-lg font-extrabold">
              <ShieldCheck aria-hidden="true" className="size-5 text-brand" />{t('profile.account')}{' '}<span className="heading-accent">{t('profile.security')}</span>
            </h2>
          </div>
          {isDemoMode ? (
            <p className="text-sm text-slatefine">{t('profile.demoSecurity')}</p>
          ) : (
            <div className="flex flex-wrap gap-2.5">
              <Button
                variant="outline"
                isLoading={securityAction === 'email'}
                disabled={securityAction !== null}
                onClick={() => void requestRecovery()}
                leftIcon={<KeyRound aria-hidden="true" className="size-4" />}
              >{t('profile.password')}</Button>
              <Button variant="ghost" onClick={() => setConfirmExit(true)} disabled={securityAction !== null}>{t('profile.logoutAll')}</Button>
            </div>
          )}
          <Feedback error={securityError} status={securityStatus} />
        </Card>
      </div>

      <Modal
        isOpen={confirmExit}
        title={t('profile.logoutAllConfirm')}
        maxWidth="sm"
        dismissable={securityAction !== 'exit'}
        onClose={() => setConfirmExit(false)}
      >
        <p className="mb-4 text-sm leading-relaxed text-slatefine">{t('profile.logoutAllDescription')}</p>
        <div className="flex flex-wrap justify-end gap-2">
          <Button variant="ghost" disabled={securityAction === 'exit'} onClick={() => setConfirmExit(false)}>{t('courses.cancel')}</Button>
          <Button variant="danger" isLoading={securityAction === 'exit'} onClick={() => void exit('global')}>{t('profile.logout')}</Button>
        </div>
      </Modal>
    </div>
  );
}

const goals: Record<OnboardingGoal, string> = {
  get mastery() { return t('profile.mastery'); },
  get exam_prep() { return t('courses.exam'); },
  get skills_boost() { return t('profile.skills'); },
};
const levels: Record<InitialLevel, string> = { get beginner() { return t('courses.beginner'); }, get intermediate() { return t('profile.intermediate'); }, get advanced() { return t('profile.advanced'); } };

function LearningPreferences({ learner, course, onChooseSubject, onOpenLearningPlan }: {
  learner: LearnerProfile; course: Course | null; onChooseSubject: () => void; onOpenLearningPlan: () => void;
}) {
  const { t } = useTranslation();
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
      setStatus(t('profile.preferencesSaved'));
    } catch {
      setError(t('profile.preferencesFailed'));
    } finally {
      setSaving(false);
    }
  };

  return (
    <Card className="fade-up stagger-3 space-y-4" padding="md">
      <div>
        <span className="highlight mb-1.5">
          <Sparkles aria-hidden="true" className="size-3.5" />{t('profile.customization')}</span>
        <h2 className="heading text-lg font-extrabold">{t('profile.learning')}{' '}<span className="heading-accent">{t('profile.preferences')}</span>
        </h2>
      </div>
      <div className="flex flex-wrap items-center justify-between gap-2 rounded-2xl border border-hairline bg-canvas/80 p-3">
        <span className="inline-flex items-center gap-2 text-sm font-bold text-ink">
          <BookOpen aria-hidden="true" className="size-4 shrink-0 text-brand" />
          {course?.title ?? t('profile.noSubject')}
        </span>
        <div className="flex flex-wrap gap-1.5">
          <Button variant="ghost" size="sm" onClick={onChooseSubject}>{t('profile.switchSubject')}</Button>
          {course && (
            <Button variant="outline" size="sm" onClick={onOpenLearningPlan}>
              {level ? levels[level] + ' · Darajani sozlash' : t('profile.chooseLevel')}
            </Button>
          )}
        </div>
      </div>
      <form onSubmit={save} className="grid gap-3.5 sm:grid-cols-2">
        <div className="text-sm sm:col-span-2">
          <label className="font-bold" htmlFor="profile-goal">{t('courses.goal')}</label>
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
          <label className="font-bold" htmlFor="profile-daily-minutes">{t('courses.dailyTime')}</label>
          <select
            id="profile-daily-minutes"
            className="form-input mt-1.5 px-3"
            value={minutes}
            onChange={(event) => setMinutes(Number(event.target.value) as DailyTimeCommitment)}
          >
            {[15, 30, 60].map((value) => (
              <option key={value} value={value}>
                {value}{' '}{t('courses.minutes')}</option>
            ))}
          </select>
        </div>
        <div className="space-y-3 sm:col-span-2">
          <Feedback error={error} status={status} />
          <Button type="submit" isLoading={saving}>{t('profile.saveSettings')}</Button>
        </div>
      </form>
    </Card>
  );
}

function ReminderPreferences() {
  const { t } = useTranslation();
  const [enabled, setEnabled] = useState<boolean | null>(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [retry, setRetry] = useState(0);

  useEffect(() => {
    let active = true;
    setError('');
    void supabaseLearnerRepository.getLearningReminders().then(
      (value) => { if (active) setEnabled(value); },
      () => { if (active) setError(t('profile.reminderLoadFailed')); },
    );
    return () => { active = false; };
  }, [retry, t]);

  const toggle = async (next: boolean) => {
    setSaving(true);
    setError('');
    try {
      setEnabled(await supabaseLearnerRepository.setLearningReminders(next));
    } catch {
      setError(t('profile.reminderSaveFailed'));
    } finally {
      setSaving(false);
    }
  };

  return (
    <Card className="fade-up stagger-3 space-y-3.5" padding="md">
      <div>
        <span className="highlight mb-1.5">{t('profile.notification')}</span>
        <h2 className="heading flex items-center gap-2 text-lg font-extrabold">
          <Bell aria-hidden="true" className="size-5 text-brand" />{t('profile.reminders')}</h2>
      </div>
      <p className="text-sm text-slatefine">{t('profile.reminderDescription')}</p>
      {enabled == null ? (
        error ? (
          <Button variant="outline" onClick={() => setRetry((value) => value + 1)}>{t('courses.retry')}</Button>
        ) : (
          <p role="status" className="text-sm text-slatefine">{t('profile.loading')}</p>
        )
      ) : (
        <label className="flex min-h-11 w-fit cursor-pointer items-center gap-3 text-sm font-bold">
          <input
            type="checkbox"
            checked={enabled}
            disabled={saving}
            className="size-5 accent-brand"
            onChange={(event) => void toggle(event.target.checked)}
          />{' '}{t('profile.showReminder')}</label>
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
