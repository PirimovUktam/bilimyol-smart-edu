import { LocalizedError, displayError } from '@/core/locales/LocalizedError';
import { useTranslation } from '@/core/locales/useTranslation';
import { useState, type FormEvent } from 'react';
import { ArrowLeft, ArrowRight, MailCheck } from 'lucide-react';
import { useAuth } from '@/core/context/AuthContext';
import { Button } from '@/presentation/components/Button';
import { PasswordInput } from '@/presentation/components/PasswordInput';
import { AuthLayout } from './AuthLayout';
import { ConfirmationResend } from './ConfirmationResend';

export function RegisterView({ onNavigateLogin }: { onNavigateLogin: () => void }) {
  const { t } = useTranslation();
  const { signUp } = useAuth();
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmation, setConfirmation] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [needsConfirmation, setNeedsConfirmation] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    setError(null);
    if (!firstName.trim()) return setError(new LocalizedError('auth.enterName'));
    if (password.trim().length < 6) return setError(new LocalizedError('auth.shortPassword'));
    if (password !== confirmation) return setError(new LocalizedError('auth.mismatch'));
    setIsSubmitting(true);
    try {
      const result = await signUp(email.trim(), password, firstName.trim(), lastName.trim());
      if (result.error) setError(result.error);
      else if (result.requiresEmailConfirmation) setNeedsConfirmation(true);
    } catch {
      setError(new LocalizedError('errors.auth'));
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <AuthLayout title={needsConfirmation ? t('auth.checkInbox') : t('auth.createAccount')}
      subtitle={needsConfirmation ? t('auth.confirmDescription') : t('auth.startPath')}>
      {needsConfirmation ? (
        <div><p role="status" className="flex items-center gap-2 rounded-xl bg-mint/8 p-3 text-sm text-mint">
          <MailCheck aria-hidden="true" className="size-5 shrink-0" /><span className="break-all">{email}</span>
        </p><ConfirmationResend email={email} /></div>
      ) : (
        <form onSubmit={submit} className="space-y-4">
          {error && <p role="alert" className="rounded-xl bg-rose-50 p-3 text-sm text-coral">{displayError(error, t)}</p>}
          <div className="grid gap-3 sm:grid-cols-2">
            <label className="block text-sm font-bold">{t('auth.firstName')}
              <input className="form-input mt-1.5 px-3.5 font-normal" value={firstName}
                onChange={(event) => setFirstName(event.target.value)} required maxLength={80} autoComplete="given-name" />
            </label>
            <label className="block text-sm font-bold">{t('auth.lastName')}
              <input className="form-input mt-1.5 px-3.5 font-normal" value={lastName}
                onChange={(event) => setLastName(event.target.value)} maxLength={80} autoComplete="family-name" />
            </label>
          </div>
          <label className="block text-sm font-bold">{t('auth.email')}
            <input className="form-input mt-1.5 px-3.5 font-normal" type="email" required autoComplete="email"
              value={email} onChange={(event) => setEmail(event.target.value)} placeholder={t('auth.emailPlaceholder')} />
          </label>
          <div>
            <label htmlFor="register-password" className="mb-1.5 block text-sm font-bold">{t('auth.password')}</label>
            <PasswordInput id="register-password" value={password} required minLength={6} autoComplete="new-password"
              placeholder={t('auth.sixCharacters')} onChange={(event) => setPassword(event.target.value)} />
          </div>
          <div>
            <label htmlFor="register-confirm" className="mb-1.5 block text-sm font-bold">{t('auth.confirmPassword')}</label>
            <PasswordInput id="register-confirm" value={confirmation} required autoComplete="new-password"
              onChange={(event) => setConfirmation(event.target.value)} />
          </div>
          <Button type="submit" size="lg" className="w-full" isLoading={isSubmitting}
            rightIcon={<ArrowRight aria-hidden="true" className="size-4" />}>{t('auth.register')}</Button>
        </form>
      )}
      <Button type="button" variant="ghost" className="mt-4 w-full" onClick={onNavigateLogin}
        leftIcon={<ArrowLeft aria-hidden="true" className="size-4" />}>{t('auth.backLogin')}</Button>
    </AuthLayout>
  );
}
