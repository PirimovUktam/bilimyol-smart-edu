import { useState, type FormEvent } from 'react';
import { AlertCircle, ArrowRight, Play } from 'lucide-react';
import { useAuth } from '@/core/context/AuthContext';
import { isSupabaseConfigured } from '@/core/config/supabase';
import { Button } from '@/presentation/components/Button';
import { PasswordInput } from '@/presentation/components/PasswordInput';
import { AuthLayout } from './AuthLayout';
import { ConfirmationResend } from './ConfirmationResend';

interface LoginViewProps {
  onNavigateRegister: () => void;
  onNavigateForgotPassword: () => void;
}

export function LoginView({ onNavigateRegister, onNavigateForgotPassword }: LoginViewProps) {
  const { signIn, setDemoUser } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    setError(null);
    setIsSubmitting(true);
    try {
      const result = await signIn(email.trim(), password);
      if (result.error) setError(result.error.message);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <AuthLayout title="Xush kelibsiz!" subtitle="O‘quv yo‘lingizni davom ettirish uchun hisobingizga kiring.">
      <form onSubmit={submit} className="space-y-4">
        {error && <p role="alert" className="flex items-start gap-2 rounded-xl border border-coral/20 bg-rose-50 p-3 text-sm text-coral">
          <AlertCircle aria-hidden="true" className="mt-0.5 size-4 shrink-0" />{error}
        </p>}
        {!isSupabaseConfigured && (
          <p className="rounded-xl bg-sand p-3 text-sm text-slatefine">Bu muhitda hisob xizmati ulanmagan. Ilovani namuna rejimida sinab ko‘ring.</p>
        )}
        <div>
          <label htmlFor="login-email" className="mb-1.5 block text-sm font-bold">Email manzilingiz</label>
          <input id="login-email" className="form-input px-3.5" type="email" required autoComplete="email"
            placeholder="nomingiz@misol.uz" value={email} onChange={(event) => setEmail(event.target.value)} />
        </div>
        <div>
          <div className="mb-1.5 flex flex-wrap items-center justify-between gap-2">
            <label htmlFor="login-password" className="text-sm font-bold">Parol</label>
            <button type="button" className="cursor-pointer text-xs font-bold text-brand-dark hover:underline"
              onClick={onNavigateForgotPassword}>Unutdingizmi?</button>
          </div>
          <PasswordInput id="login-password" required autoComplete="current-password" placeholder="Parolingiz"
            value={password} onChange={(event) => setPassword(event.target.value)} />
        </div>
        <Button type="submit" size="lg" className="w-full" isLoading={isSubmitting}
          rightIcon={<ArrowRight aria-hidden="true" className="size-4" />}>Kirish</Button>
      </form>
      {error?.startsWith('Emailingiz hali tasdiqlanmagan.') && <ConfirmationResend key={email.trim()} email={email} />}
      <div className="my-5 flex items-center gap-3 text-xs text-slatefine" aria-hidden="true">
        <span className="h-px flex-1 bg-hairline" /> yoki <span className="h-px flex-1 bg-hairline" />
      </div>
      <Button type="button" variant="outline" className="w-full" disabled={isSubmitting}
        onClick={setDemoUser}
        leftIcon={<Play aria-hidden="true" className="size-4 text-brand" />}>Namuna hisobi bilan kirish</Button>
      <p className="mt-2 text-center text-xs leading-relaxed text-slatefine">Namuna natijalari brauzer xotirasida saqlanadi.</p>
      <p className="mt-5 text-center text-sm text-slatefine">
        Hisobingiz yo‘qmi? <button type="button" className="cursor-pointer font-bold text-brand-dark hover:underline"
          onClick={onNavigateRegister}>Ro‘yxatdan o‘tish</button>
      </p>
    </AuthLayout>
  );
}
