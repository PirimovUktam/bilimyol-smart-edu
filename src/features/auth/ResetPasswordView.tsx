import { LocalizedError, displayError } from '@/core/locales/LocalizedError';
import { useTranslation } from '@/core/locales/useTranslation';
import { useState, type FormEvent } from 'react';
import { ArrowLeft, CheckCircle2 } from 'lucide-react';
import { useAuth } from '@/core/context/AuthContext';
import { Button } from '@/presentation/components/Button';
import { PasswordInput } from '@/presentation/components/PasswordInput';
import { SectionState } from '@/presentation/components/SectionState';
import { AuthLayout } from './AuthLayout';

export function ResetPasswordView({ onNavigateLogin }: { onNavigateLogin: () => void }) {
  const { t } = useTranslation();
  const { updatePassword, signOut, isLoading, isPasswordRecovery } = useAuth();
  const [password, setPassword] = useState('');
  const [confirmation, setConfirmation] = useState('');
  const [error, setError] = useState<Error | null>(null);
  const [done, setDone] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    setError(null);
    if (password !== confirmation) return setError(new LocalizedError('auth.mismatch'));
    setSubmitting(true);
    try {
      const result = await updatePassword(password);
      if (result.error) setError(result.error);
      else setDone(true);
    } catch {
      setError(new LocalizedError('errors.auth'));
    } finally {
      setSubmitting(false);
    }
  };

  const returnToLogin = async () => {
    try {
      if (isPasswordRecovery || done) await signOut();
      onNavigateLogin();
    } catch {
      setError(new LocalizedError('auth.logoutFailed'));
    }
  };

  return (
    <AuthLayout title={t('auth.setPassword')} subtitle={t('auth.setPasswordDescription')}>
      {error && <p role="alert" className="mb-4 rounded-xl bg-rose-50 p-3 text-sm text-coral">{displayError(error, t)}</p>}
      {done ? (
        <p role="status" className="flex items-center gap-2 rounded-xl bg-mint/8 p-3 text-sm font-bold text-mint">
          <CheckCircle2 aria-hidden="true" className="size-5 shrink-0" />{t('auth.passwordUpdated')}
        </p>
      ) : isPasswordRecovery ? (
        <form onSubmit={submit} className="space-y-4">
          <div>
            <label htmlFor="reset-password" className="mb-1.5 block text-sm font-bold">{t('auth.newPassword')}</label>
            <PasswordInput id="reset-password" value={password} minLength={6} required autoComplete="new-password"
              onChange={(event) => setPassword(event.target.value)} />
          </div>
          <div>
            <label htmlFor="reset-confirm" className="mb-1.5 block text-sm font-bold">{t('auth.confirmPassword')}</label>
            <PasswordInput id="reset-confirm" value={confirmation} required autoComplete="new-password"
              onChange={(event) => setConfirmation(event.target.value)} />
          </div>
          <Button type="submit" isLoading={submitting} className="w-full">{t('auth.savePassword')}</Button>
        </form>
      ) : isLoading ? (
        <SectionState kind="loading" title={t('auth.checkingRecovery')} />
      ) : (
        <SectionState title={t('auth.noRecovery')} description={t('auth.requestNewRecovery')} />
      )}
      <Button type="button" variant="ghost" className="mt-4 w-full" disabled={submitting}
        onClick={() => void returnToLogin()} leftIcon={<ArrowLeft aria-hidden="true" className="size-4" />}>
        {t('auth.backLogin')}
      </Button>
    </AuthLayout>
  );
}
