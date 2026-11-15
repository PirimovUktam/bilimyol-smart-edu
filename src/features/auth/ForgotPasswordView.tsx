import { LocalizedError, displayError } from '@/core/locales/LocalizedError';
import { useTranslation } from '@/core/locales/useTranslation';
import { useState, type FormEvent } from 'react';
import { ArrowLeft, MailCheck, Send } from 'lucide-react';
import { useAuth } from '@/core/context/AuthContext';
import { Button } from '@/presentation/components/Button';
import { AuthLayout } from './AuthLayout';

export function ForgotPasswordView({ onNavigateLogin }: { onNavigateLogin: () => void }) {
  const { t } = useTranslation();
  const { resetPassword } = useAuth();
  const [email, setEmail] = useState('');
  const [error, setError] = useState<Error | null>(null);
  const [sent, setSent] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      const result = await resetPassword(email.trim());
      if (result.error) setError(result.error);
      else setSent(true);
    } catch {
      setError(new LocalizedError('errors.auth'));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <AuthLayout title={t('auth.recovery')} subtitle={t('auth.recoveryDescription')}>
      {sent ? (
        <div role="status" className="flex items-start gap-3 rounded-card bg-mint/8 p-4 text-sm">
          <MailCheck aria-hidden="true" className="size-5 shrink-0 text-mint" />
          <div><p className="font-bold text-mint">{t('auth.requestAccepted')}</p>
            <p className="mt-1 leading-relaxed text-slatefine">{t('shell.if')}{' '}<strong className="break-all">{email}</strong>{t('shell.recoverySent')}</p></div>
        </div>
      ) : (
        <form onSubmit={submit} className="space-y-4">
          {error && <p role="alert" className="rounded-xl bg-rose-50 p-3 text-sm text-coral">{displayError(error, t)}</p>}
          <label className="block text-sm font-bold">{t('auth.email')}
            <input type="email" className="form-input mt-1.5 px-3.5 font-normal" autoComplete="email" required
              placeholder={t('auth.emailPlaceholder')} value={email} onChange={(event) => setEmail(event.target.value)} />
          </label>
          <Button type="submit" className="w-full" isLoading={submitting}
            rightIcon={<Send aria-hidden="true" className="size-4" />}>{t('auth.sendRecovery')}</Button>
        </form>
      )}
      <Button type="button" variant="ghost" className="mt-4 w-full" onClick={onNavigateLogin}
        leftIcon={<ArrowLeft aria-hidden="true" className="size-4" />}>{t('auth.backLogin')}</Button>
    </AuthLayout>
  );
}
