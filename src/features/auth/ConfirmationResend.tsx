import { LocalizedError, displayError } from '@/core/locales/LocalizedError';
import { useTranslation } from '@/core/locales/useTranslation';
import { useEffect, useState } from 'react';
import { useAuth } from '@/core/context/AuthContext';
import { Button } from '@/presentation/components/Button';

export function ConfirmationResend({ email }: { email: string }) {
  const { t } = useTranslation();
  const { resendConfirmation } = useAuth();
  const [busy, setBusy] = useState(false);
  const [remaining, setRemaining] = useState(0);
  const [result, setResult] = useState<Error | 'sent' | null>(null);
  const [failed, setFailed] = useState(false);
  useEffect(() => {
    if (!remaining) return;
    const timer = window.setTimeout(() => setRemaining(value => Math.max(0, value - 1)), 1000);
    return () => window.clearTimeout(timer);
  }, [remaining]);
  const resend = async () => {
    if (busy || remaining) return;
    setBusy(true);
    setResult(null);
    try {
      const result = await resendConfirmation(email);
      setFailed(Boolean(result.error));
      setResult(result.error ?? 'sent');
    } catch {
      setFailed(true);
      setResult(new LocalizedError('auth.resendFailed'));
    } finally {
      setBusy(false);
      setRemaining(60);
    }
  };
  return <div className="mt-3 space-y-2">
    <Button type="button" variant="outline" className="w-full" isLoading={busy}
      disabled={!email.trim() || remaining > 0} onClick={resend}>
      {remaining ? t('dynamic.resendCountdown', { seconds: remaining }) : t('auth.resendConfirmation')}
    </Button>
    {result && <p role={failed ? 'alert' : 'status'} className="text-sm leading-relaxed">{result === 'sent' ? t('auth.resendAccepted') : displayError(result, t)}</p>}
  </div>;
}
