import React, { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import {
  KeyRound,
  PlusCircle,
  Copy,
  CheckCircle,
  AlertCircle,
  ShieldCheck,
  Ban,
  Clock,
  School,
} from 'lucide-react';
import { useMonitoringStore } from '../../app/store/useMonitoringStore';
import { Button } from '../../presentation/components/Button';
import { Badge } from '../../presentation/components/Badge';

interface Props {
  isOpen: boolean;
  onClose: () => void;
}

export const TeacherInvitationManagementModal: React.FC<Props> = ({ isOpen, onClose }) => {
  const {
    invitations,
    createdInvitation,
    fetchTeacherInvitations,
    createTeacherInvitation,
    revokeTeacherInvitation,
  } = useMonitoringStore();

  const [schoolName, setSchoolName] = useState('BilimYo‘l Smart School');
  const [maxUses, setMaxUses] = useState(1);
  const [validityDays, setValidityDays] = useState(7);
  const [copiedCode, setCopiedCode] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [statusMsg, setStatusMsg] = useState<{ text: string; isError: boolean } | null>(null);

  useEffect(() => {
    if (isOpen) {
      fetchTeacherInvitations();
    }
  }, [isOpen, fetchTeacherInvitations]);

  if (!isOpen) return null;

  const handleCreateCode = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    setStatusMsg(null);
    try {
      const res = await createTeacherInvitation(schoolName.trim(), maxUses, validityDays);
      setStatusMsg({ text: `Yangi kod yaratildi: ${res.plainCode}`, isError: false });
    } catch (err: unknown) {
      setStatusMsg({
        text: err instanceof Error ? err.message : 'Kod yaratishda xatolik.',
        isError: true,
      });
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleCopy = (code: string) => {
    navigator.clipboard.writeText(code);
    setCopiedCode(true);
    setTimeout(() => setCopiedCode(false), 2000);
  };

  const handleRevoke = async (id: string) => {
    if (confirm('Ushbu taklif kodini haqiqatan ham bekor qilmoqchimisiz?')) {
      await revokeTeacherInvitation(id);
    }
  };

  return (
    <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
      <motion.div
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        className="bg-card border border-border rounded-2xl max-w-2xl w-full p-6 shadow-2xl space-y-6 max-h-[90vh] overflow-y-auto"
      >
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2.5">
            <div className="w-9 h-9 rounded-xl bg-indigo-500/10 text-indigo-600 flex items-center justify-center">
              <KeyRound className="w-5 h-5" />
            </div>
            <div>
              <h2 className="text-lg font-bold text-foreground">O‘qituvchilar Uchun Taklif Kodlari</h2>
              <p className="text-xs text-muted-foreground">Maktab va o‘qituvchilarni xavfsiz tasdiqlash boshqaruvi</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="text-muted-foreground hover:text-foreground text-sm font-semibold cursor-pointer"
          >
            ✕
          </button>
        </div>

        {/* Generate Code Form */}
        <form onSubmit={handleCreateCode} className="p-4 rounded-xl bg-secondary/40 border border-border/60 space-y-3">
          <div className="flex items-center gap-2 text-xs font-bold text-foreground">
            <PlusCircle className="w-4 h-4 text-indigo-600" />
            <span>Yangi O‘qituvchi Kodi Yaratish</span>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
            <div>
              <label className="block text-[11px] font-semibold text-muted-foreground mb-1">
                Maktab / Tashkilot
              </label>
              <div className="relative">
                <School className="w-3.5 h-3.5 text-muted-foreground absolute left-2.5 top-1/2 -translate-y-1/2" />
                <input
                  type="text"
                  value={schoolName}
                  onChange={(e) => setSchoolName(e.target.value)}
                  placeholder="Maktab nomi"
                  required
                  className="w-full pl-8 pr-3 py-1.5 rounded-lg bg-background border border-border text-xs text-foreground focus:ring-1 focus:ring-indigo-500 outline-none"
                />
              </div>
            </div>

            <div>
              <label className="block text-[11px] font-semibold text-muted-foreground mb-1">
                Foydalanish soni
              </label>
              <select
                value={maxUses}
                onChange={(e) => setMaxUses(Number(e.target.value))}
                className="w-full px-2.5 py-1.5 rounded-lg bg-background border border-border text-xs text-foreground focus:ring-1 focus:ring-indigo-500 outline-none"
              >
                <option value={1}>1 marta (Bir martalik)</option>
                <option value={5}>5 marta</option>
                <option value={10}>10 marta</option>
                <option value={50}>50 marta</option>
              </select>
            </div>

            <div>
              <label className="block text-[11px] font-semibold text-muted-foreground mb-1">
                Amal qilish muddati
              </label>
              <select
                value={validityDays}
                onChange={(e) => setValidityDays(Number(e.target.value))}
                className="w-full px-2.5 py-1.5 rounded-lg bg-background border border-border text-xs text-foreground focus:ring-1 focus:ring-indigo-500 outline-none"
              >
                <option value={1}>1 kun</option>
                <option value={7}>7 kun (Tavsiya)</option>
                <option value={30}>30 kun</option>
                <option value={365}>1 yil</option>
              </select>
            </div>
          </div>

          <div className="flex justify-end pt-1">
            <Button
              type="submit"
              variant="primary"
              size="sm"
              isLoading={isSubmitting}
            >
              Kodni Generatsiya Qilish
            </Button>
          </div>
        </form>

        {/* Newly Created Code One-Time Alert */}
        {createdInvitation && (
          <div className="p-4 rounded-xl bg-indigo-50/80 dark:bg-indigo-950/40 border border-indigo-200 dark:border-indigo-800/60 space-y-2">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-indigo-900 dark:text-indigo-200 flex items-center gap-1.5">
                <ShieldCheck className="w-4 h-4 text-indigo-600" />
                Yangi Kod Tayyor (Bir martalik ko‘rsatuv):
              </span>
              <Button
                variant="secondary"
                size="sm"
                onClick={() => handleCopy(createdInvitation.plainCode)}
                className="gap-1 text-xs"
              >
                {copiedCode ? <CheckCircle className="w-3.5 h-3.5 text-emerald-500" /> : <Copy className="w-3.5 h-3.5" />}
                <span>{copiedCode ? 'Nusxalandi' : 'Nusxa olish'}</span>
              </Button>
            </div>

            <div className="p-2.5 rounded-lg bg-white dark:bg-slate-900 border border-indigo-100 font-mono font-extrabold text-base tracking-widest text-indigo-600 dark:text-indigo-400 text-center">
              {createdInvitation.plainCode}
            </div>

            <p className="text-[11px] text-indigo-700 dark:text-indigo-300">
              ⚠️ <strong>Muhim:</strong> Ushbu to‘liq kodni hozir nusxalab oling. Xavfsizlik maqsadida ma’lumotlar bazasida faqat xesh saqlanadi va kod qayta to‘liq ko‘rsatilmaydi.
            </p>
          </div>
        )}

        {statusMsg && (
          <div
            className={`p-3 rounded-xl text-xs flex items-center gap-2 ${
              statusMsg.isError
                ? 'bg-rose-50 text-rose-700 border border-rose-200'
                : 'bg-emerald-50 text-emerald-700 border border-emerald-200'
            }`}
          >
            {statusMsg.isError ? <AlertCircle className="w-4 h-4 shrink-0" /> : <CheckCircle className="w-4 h-4 shrink-0" />}
            <span>{statusMsg.text}</span>
          </div>
        )}

        {/* Existing Invitations Table */}
        <div className="space-y-3">
          <h3 className="text-xs font-bold text-foreground uppercase tracking-wider">
            Mavjud Kodlar Ro‘yxati
          </h3>

          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead>
                <tr className="border-b border-border text-muted-foreground uppercase">
                  <th className="pb-2 pl-2">Kod Prefiksi</th>
                  <th className="pb-2">Maktab</th>
                  <th className="pb-2">Ishlatildi / Limit</th>
                  <th className="pb-2">Holati</th>
                  <th className="pb-2">Muddati</th>
                  <th className="pb-2 pr-2 text-right">Amal</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border/40">
                {invitations.map((inv) => (
                  <tr key={inv.id} className="hover:bg-secondary/20 transition-colors">
                    <td className="py-2.5 pl-2 font-mono font-bold text-foreground">
                      {inv.codePrefix}
                    </td>
                    <td className="py-2.5 text-foreground">{inv.schoolName}</td>
                    <td className="py-2.5">
                      <span className="font-semibold text-foreground">{inv.usedCount}</span>
                      <span className="text-muted-foreground"> / {inv.maxUses}</span>
                    </td>
                    <td className="py-2.5">
                      <Badge
                        variant={
                          inv.status === 'active'
                            ? 'emerald'
                            : inv.status === 'exhausted'
                            ? 'slate'
                            : inv.status === 'expired'
                            ? 'amber'
                            : 'rose'
                        }
                      >
                        {inv.status === 'active'
                          ? 'Faol'
                          : inv.status === 'exhausted'
                          ? 'Tugagan'
                          : inv.status === 'expired'
                          ? 'Muddati o‘tgan'
                          : 'Bekor qilingan'}
                      </Badge>
                    </td>
                    <td className="py-2.5 text-muted-foreground">
                      <span className="flex items-center gap-1">
                        <Clock className="w-3 h-3" />
                        {new Date(inv.expiresAt).toLocaleDateString('uz-UZ')}
                      </span>
                    </td>
                    <td className="py-2.5 pr-2 text-right">
                      {inv.status === 'active' && (
                        <button
                          onClick={() => handleRevoke(inv.id)}
                          className="px-2 py-1 rounded bg-rose-50 hover:bg-rose-100 text-rose-700 font-semibold text-[11px] border border-rose-200 transition-colors inline-flex items-center gap-1 cursor-pointer"
                        >
                          <Ban className="w-3 h-3" />
                          Bekor qilish
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>

            {invitations.length === 0 && (
              <div className="p-6 text-center text-xs text-muted-foreground">
                Hozircha birorta ham taklif kodi mavjud emas.
              </div>
            )}
          </div>
        </div>
      </motion.div>
    </div>
  );
};
