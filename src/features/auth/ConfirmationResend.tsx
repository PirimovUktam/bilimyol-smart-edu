import { useEffect, useState } from 'react';
import { useAuth } from '@/core/context/AuthContext';
import { Button } from '@/presentation/components/Button';

export function ConfirmationResend({ email }: { email: string }) {
  const { resendConfirmation } = useAuth();
  const [busy, setBusy] = useState(false);
  const [remaining, setRemaining] = useState(0);
  const [message, setMessage] = useState('');
  const [failed, setFailed] = useState(false);
  useEffect(() => {
    if (!remaining) return;
    const timer = window.setTimeout(() => setRemaining(value => Math.max(0, value - 1)), 1000);
    return () => window.clearTimeout(timer);
  }, [remaining]);
  const resend = async () => {
    if (busy || remaining) return;
    setBusy(true);
    setMessage('');
    try {
      const result = await resendConfirmation(email);
      setFailed(Boolean(result.error));
      setMessage(result.error?.message ?? 'So‘rov qabul qilindi. Tasdiqlash kutilayotgan hisob bo‘lsa, pochtangiz va spam papkasini tekshiring.');
    } catch {
      setFailed(true);
      setMessage('Xat so‘rovini yuborib bo‘lmadi. Ulanishni tekshiring.');
    } finally {
      setBusy(false);
      setRemaining(60);
    }
  };
  return <div className="mt-3 space-y-2">
    <Button type="button" variant="outline" className="w-full" isLoading={busy}
      disabled={!email.trim() || remaining > 0} onClick={resend}>
      {remaining ? `Qayta so‘rash: ${remaining} soniya` : 'Tasdiqlash xatini qayta so‘rash'}
    </Button>
    {message && <p role={failed ? 'alert' : 'status'} className="text-sm leading-relaxed">{message}</p>}
  </div>;
}
