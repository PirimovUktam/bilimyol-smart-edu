import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { Mail, ArrowLeft, Send, CheckCircle2, AlertCircle } from 'lucide-react';
import { useAuth } from '../../core/context/AuthContext';
import { BilimYolLogo } from '../../presentation/components/BilimYolLogo';
import { Button } from '../../presentation/components/Button';
import { Card } from '../../presentation/components/Card';

interface ForgotPasswordViewProps {
  onNavigateLogin: () => void;
}

export const ForgotPasswordView: React.FC<ForgotPasswordViewProps> = ({
  onNavigateLogin,
}) => {
  const { resetPassword } = useAuth();
  const [email, setEmail] = useState('');
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [isSent, setIsSent] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleReset = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMsg(null);

    if (!email.trim()) {
      setErrorMsg('Iltimos, email manzilingizni kiriting.');
      return;
    }

    setIsSubmitting(true);
    const { error } = await resetPassword(email.trim());
    setIsSubmitting(false);

    if (error) {
      setErrorMsg(error.message || 'Xatolik yuz berdi. Iltimos qaytadan urinib ko‘ring.');
    } else {
      setIsSent(true);
    }
  };

  return (
    <div className="min-h-[calc(100vh-140px)] flex items-center justify-center px-4 py-8">
      <motion.div
        initial={{ opacity: 0, y: 15 }}
        animate={{ opacity: 1, y: 0 }}
        className="max-w-md w-full"
      >
        <div className="text-center mb-6">
          <div className="flex justify-center mb-3">
            <BilimYolLogo size="lg" variant="dark" />
          </div>
          <h1 className="text-2xl font-black text-white tracking-tight">
            Parolni tiklash
          </h1>
          <p className="text-sm text-slate-400 mt-1">
            Email manzilingizga parolni tiklash havolasini yuboramiz
          </p>
        </div>

        <Card variant="cosmicGlow" className="p-7 sm:p-8 bg-slate-900/90 shadow-2xl">
          {isSent ? (
            <div className="text-center py-4 space-y-4">
              <div className="w-12 h-12 bg-emerald-500/20 border border-emerald-500/40 rounded-full flex items-center justify-center mx-auto text-emerald-400 shadow-sm shadow-emerald-500/30">
                <CheckCircle2 className="w-6 h-6" />
              </div>
              <div>
                <h3 className="text-base font-bold text-white">
                  Havola yuborildi!
                </h3>
                <p className="text-xs text-slate-300 mt-1">
                  <strong className="text-cyan-300">{email}</strong> manziliga parolni tiklash bo‘yicha ko‘rsatmalar yuborildi.
                </p>
              </div>
              <Button
                variant="outline"
                size="md"
                className="w-full bg-slate-800/80 hover:bg-slate-700 text-slate-300 border-slate-700"
                onClick={onNavigateLogin}
                leftIcon={<ArrowLeft className="w-4 h-4" />}
              >
                Kirish sahifasiga qaytish
              </Button>
            </div>
          ) : (
            <form onSubmit={handleReset} className="space-y-4">
              {errorMsg && (
                <div className="p-3.5 bg-rose-950/60 border border-rose-500/40 rounded-xl flex items-start gap-2.5 text-rose-300 text-xs font-semibold">
                  <AlertCircle className="w-4 h-4 shrink-0 mt-0.5 text-rose-400" />
                  <span>{errorMsg}</span>
                </div>
              )}

              <div>
                <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider mb-1.5">
                  Email manzilingiz
                </label>
                <div className="relative">
                  <Mail className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                  <input
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="nomingiz@misol.uz"
                    className="w-full pl-10 pr-4 py-2.5 bg-slate-950/80 border border-slate-700 rounded-xl text-sm text-white placeholder-slate-500 focus:border-cyan-400 focus:ring-1 focus:ring-cyan-400 outline-none transition-all"
                    required
                  />
                </div>
              </div>

              <Button
                type="submit"
                variant="cyan"
                size="lg"
                className="w-full mt-2 font-black"
                isLoading={isSubmitting}
                rightIcon={<Send className="w-4 h-4" />}
              >
                Tiklash havolasini yuborish
              </Button>

              <Button
                type="button"
                variant="ghost"
                size="sm"
                className="w-full text-slate-400 hover:text-white"
                onClick={onNavigateLogin}
                leftIcon={<ArrowLeft className="w-4 h-4" />}
              >
                Ortga qaytish
              </Button>
            </form>
          )}
        </Card>
      </motion.div>
    </div>
  );
};
