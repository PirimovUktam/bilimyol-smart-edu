import { useState, type FormEvent } from 'react';
import { ArrowLeft, MailCheck, Send } from 'lucide-react';
import { useAuth } from '@/core/context/AuthContext';
import { Button } from '@/presentation/components/Button';
import { AuthLayout } from './AuthLayout';

export function ForgotPasswordView({ onNavigateLogin }: { onNavigateLogin: () => void }) {
  const { resetPassword } = useAuth();
  const [email, setEmail] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [sent, setSent] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      const result = await resetPassword(email.trim());
      if (result.error) setError(result.error.message);
      else setSent(true);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <AuthLayout title="Parolni tiklash" subtitle="Hisobingizga bog‘langan email manzilini kiriting.">
      {sent ? (
        <div role="status" className="flex items-start gap-3 rounded-card bg-mint/8 p-4 text-sm">
          <MailCheck aria-hidden="true" className="size-5 shrink-0 text-mint" />
          <div><p className="font-bold text-mint">So‘rov qabul qilindi</p>
            <p className="mt-1 leading-relaxed text-slatefine">Agar <strong className="break-all">{email}</strong> manzilida hisob mavjud bo‘lsa, tiklash havolasi pochtangizga keladi.</p></div>
        </div>
      ) : (
        <form onSubmit={submit} className="space-y-4">
          {error && <p role="alert" className="rounded-xl bg-rose-50 p-3 text-sm text-coral">{error}</p>}
          <label className="block text-sm font-bold">Email manzilingiz
            <input type="email" className="form-input mt-1.5 px-3.5 font-normal" autoComplete="email" required
              placeholder="nomingiz@misol.uz" value={email} onChange={(event) => setEmail(event.target.value)} />
          </label>
          <Button type="submit" className="w-full" isLoading={submitting}
            rightIcon={<Send aria-hidden="true" className="size-4" />}>Tiklash havolasini yuborish</Button>
        </form>
      )}
      <Button type="button" variant="ghost" className="mt-4 w-full" onClick={onNavigateLogin}
        leftIcon={<ArrowLeft aria-hidden="true" className="size-4" />}>Kirish sahifasiga qaytish</Button>
    </AuthLayout>
  );
}
