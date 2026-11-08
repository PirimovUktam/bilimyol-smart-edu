import { useState, type FormEvent } from 'react';
import { ArrowLeft, CheckCircle2 } from 'lucide-react';
import { useAuth } from '@/core/context/AuthContext';
import { Button } from '@/presentation/components/Button';
import { PasswordInput } from '@/presentation/components/PasswordInput';
import { SectionState } from '@/presentation/components/SectionState';
import { AuthLayout } from './AuthLayout';

export function ResetPasswordView({ onNavigateLogin }: { onNavigateLogin: () => void }) {
  const { updatePassword, signOut, isLoading, isPasswordRecovery } = useAuth();
  const [password, setPassword] = useState('');
  const [confirmation, setConfirmation] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    setError(null);
    if (password !== confirmation) return setError('Parollar bir-biriga mos kelmadi.');
    setSubmitting(true);
    try {
      const result = await updatePassword(password);
      if (result.error) setError(result.error.message);
      else setDone(true);
    } finally {
      setSubmitting(false);
    }
  };

  const returnToLogin = async () => {
    try {
      if (isPasswordRecovery || done) await signOut();
      onNavigateLogin();
    } catch {
      setError('Sessiyani tugatib bo‘lmadi. Qayta urinib ko‘ring.');
    }
  };

  return (
    <AuthLayout title="Yangi parol o‘rnating" subtitle="Hisobingiz uchun kamida olti belgili parol tanlang.">
      {error && <p role="alert" className="mb-4 rounded-xl bg-rose-50 p-3 text-sm text-coral">{error}</p>}
      {done ? (
        <p role="status" className="flex items-center gap-2 rounded-xl bg-mint/8 p-3 text-sm font-bold text-mint">
          <CheckCircle2 aria-hidden="true" className="size-5 shrink-0" />Parol yangilandi!
        </p>
      ) : isPasswordRecovery ? (
        <form onSubmit={submit} className="space-y-4">
          <div>
            <label htmlFor="reset-password" className="mb-1.5 block text-sm font-bold">Yangi parol</label>
            <PasswordInput id="reset-password" value={password} minLength={6} required autoComplete="new-password"
              onChange={(event) => setPassword(event.target.value)} />
          </div>
          <div>
            <label htmlFor="reset-confirm" className="mb-1.5 block text-sm font-bold">Parolni takrorlang</label>
            <PasswordInput id="reset-confirm" value={confirmation} required autoComplete="new-password"
              onChange={(event) => setConfirmation(event.target.value)} />
          </div>
          <Button type="submit" isLoading={submitting} className="w-full">Parolni saqlash</Button>
        </form>
      ) : isLoading ? (
        <SectionState kind="loading" title="Tiklash havolasi tekshirilmoqda…" />
      ) : (
        <SectionState title="Faol tiklash havolasi topilmadi" description="Kirish sahifasidan yangi tiklash havolasini so‘rashingiz mumkin." />
      )}
      <Button type="button" variant="ghost" className="mt-4 w-full" disabled={submitting}
        onClick={() => void returnToLogin()} leftIcon={<ArrowLeft aria-hidden="true" className="size-4" />}>
        Kirish sahifasiga qaytish
      </Button>
    </AuthLayout>
  );
}
