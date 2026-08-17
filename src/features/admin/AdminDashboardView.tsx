import React, { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import {
  ShieldAlert,
  KeyRound,
  PlusCircle,
  Copy,
  CheckCircle,
  AlertCircle,
  Ban,
  Clock,
  School,
  Users,
  Sparkles,
  RefreshCw,
} from 'lucide-react';
import { useMonitoringStore } from '../../app/store/useMonitoringStore';
import { Button } from '../../presentation/components/Button';
import { Card } from '../../presentation/components/Card';
import { Badge } from '../../presentation/components/Badge';

export const AdminDashboardView: React.FC = () => {
  const {
    invitations,
    createdInvitation,
    fetchTeacherInvitations,
    createTeacherInvitation,
    revokeTeacherInvitation,
    isLoading,
  } = useMonitoringStore();

  const [schoolName, setSchoolName] = useState('BilimYo‘l Smart School');
  const [maxUses, setMaxUses] = useState(1);
  const [validityDays, setValidityDays] = useState(7);
  const [copiedCode, setCopiedCode] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [statusMsg, setStatusMsg] = useState<{ text: string; isError: boolean } | null>(null);

  useEffect(() => {
    fetchTeacherInvitations();
  }, [fetchTeacherInvitations]);

  const handleCreateCode = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    setStatusMsg(null);
    try {
      const res = await createTeacherInvitation(schoolName.trim(), maxUses, validityDays);
      setStatusMsg({ text: `Yangi ustoz kodi muvaffaqiyatli yaratildi: ${res.plainCode}`, isError: false });
    } catch (err: unknown) {
      setStatusMsg({
        text: err instanceof Error ? err.message : 'Kod yaratishda xatolik yuz berdi.',
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

  const activeCodesCount = invitations.filter((i) => i.status === 'active').length;
  const totalUsesCount = invitations.reduce((acc, i) => acc + i.usedCount, 0);

  return (
    <div className="max-w-6xl mx-auto px-4 py-8 space-y-8">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <span className="px-2.5 py-0.5 rounded-full text-xs font-bold bg-purple-500/10 text-purple-700 dark:text-purple-300 border border-purple-500/20 flex items-center gap-1.5">
              <ShieldAlert className="w-3.5 h-3.5" />
              Platforma Boshqaruv Markazi
            </span>
            <span className="text-xs text-muted-foreground">• Faqat Administratorlar uchun</span>
          </div>
          <h1 className="text-3xl font-extrabold text-foreground tracking-tight">
            Administrator Konsoli
          </h1>
          <p className="text-muted-foreground text-sm mt-1">
            O‘qituvchilar taklif kodlari boshqaruvi, xavfsizlik va tizim nazorati
          </p>
        </div>

        <Button
          variant="outline"
          size="sm"
          onClick={() => fetchTeacherInvitations()}
          isLoading={isLoading}
          className="flex items-center gap-2"
        >
          <RefreshCw className="w-3.5 h-3.5" />
          <span>Yangilash</span>
        </Button>
      </div>

      {/* Platform Metric Overview Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <Card className="p-5 flex items-center gap-4 border-indigo-100 dark:border-indigo-900/40">
          <div className="w-12 h-12 rounded-xl bg-indigo-500/10 text-indigo-600 flex items-center justify-center shrink-0">
            <KeyRound className="w-6 h-6" />
          </div>
          <div>
            <div className="text-2xl font-extrabold text-foreground">{invitations.length}</div>
            <div className="text-xs text-muted-foreground font-medium">Jami Taklif Kodlari</div>
          </div>
        </Card>

        <Card className="p-5 flex items-center gap-4 border-emerald-100 dark:border-emerald-900/40">
          <div className="w-12 h-12 rounded-xl bg-emerald-500/10 text-emerald-600 flex items-center justify-center shrink-0">
            <Sparkles className="w-6 h-6" />
          </div>
          <div>
            <div className="text-2xl font-extrabold text-foreground">{activeCodesCount}</div>
            <div className="text-xs text-muted-foreground font-medium">Faol Kodlar</div>
          </div>
        </Card>

        <Card className="p-5 flex items-center gap-4 border-purple-100 dark:border-purple-900/40">
          <div className="w-12 h-12 rounded-xl bg-purple-500/10 text-purple-600 flex items-center justify-center shrink-0">
            <Users className="w-6 h-6" />
          </div>
          <div>
            <div className="text-2xl font-extrabold text-foreground">{totalUsesCount}</div>
            <div className="text-xs text-muted-foreground font-medium">Tasdiqlangan O‘qituvchilar</div>
          </div>
        </Card>
      </div>

      {/* Create New Code Card */}
      <Card className="p-6 border-slate-200 dark:border-slate-800 shadow-md">
        <div className="flex items-center gap-2 mb-4">
          <div className="w-8 h-8 rounded-lg bg-indigo-500/10 text-indigo-600 flex items-center justify-center">
            <PlusCircle className="w-4 h-4" />
          </div>
          <div>
            <h2 className="text-base font-bold text-foreground">Yangi O‘qituvchi Taklif Kodi Yaratish</h2>
            <p className="text-xs text-muted-foreground">Maktab yoki o‘qituvchi uchun xavfsiz tasdiqlash tokeni generatsiya qiling</p>
          </div>
        </div>

        <form onSubmit={handleCreateCode} className="space-y-4">
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div>
              <label className="block text-xs font-bold text-foreground uppercase tracking-wider mb-1.5">
                Maktab / Muassasa Nomi *
              </label>
              <div className="relative">
                <School className="w-4 h-4 text-muted-foreground absolute left-3 top-1/2 -translate-y-1/2" />
                <input
                  type="text"
                  value={schoolName}
                  onChange={(e) => setSchoolName(e.target.value)}
                  placeholder="Masalan: Toshkent IDUM №1"
                  required
                  className="w-full pl-9 pr-3 py-2 bg-secondary/50 border border-border rounded-xl text-xs text-foreground focus:ring-2 focus:ring-indigo-500 outline-none"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-bold text-foreground uppercase tracking-wider mb-1.5">
                Maksimal Foydalanish Soni
              </label>
              <select
                value={maxUses}
                onChange={(e) => setMaxUses(Number(e.target.value))}
                className="w-full px-3 py-2 bg-secondary/50 border border-border rounded-xl text-xs text-foreground focus:ring-2 focus:ring-indigo-500 outline-none"
              >
                <option value={1}>1 marta (Yakka o‘qituvchi uchun)</option>
                <option value={5}>5 marta (Kichik kafedra)</option>
                <option value={10}>10 marta (Metod birlashma)</option>
                <option value={50}>50 marta (Butun maktab jamoasi)</option>
              </select>
            </div>

            <div>
              <label className="block text-xs font-bold text-foreground uppercase tracking-wider mb-1.5">
                Amal Qilish Muddati
              </label>
              <select
                value={validityDays}
                onChange={(e) => setValidityDays(Number(e.target.value))}
                className="w-full px-3 py-2 bg-secondary/50 border border-border rounded-xl text-xs text-foreground focus:ring-2 focus:ring-indigo-500 outline-none"
              >
                <option value={1}>1 kun</option>
                <option value={7}>7 kun (Tavsiya etiladi)</option>
                <option value={30}>30 kun (1 oy)</option>
                <option value={365}>1 yil</option>
              </select>
            </div>
          </div>

          <div className="flex justify-end pt-2">
            <Button
              type="submit"
              variant="primary"
              isLoading={isSubmitting}
              className="gap-2"
            >
              <KeyRound className="w-4 h-4" />
              <span>Kodni Generatsiya Qilish</span>
            </Button>
          </div>
        </form>

        {/* Newly Created Code Notification */}
        {createdInvitation && (
          <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            className="mt-6 p-4 rounded-xl bg-indigo-50/90 dark:bg-indigo-950/40 border border-indigo-200 dark:border-indigo-800 space-y-3"
          >
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold text-indigo-900 dark:text-indigo-200 flex items-center gap-1.5">
                <CheckCircle className="w-4 h-4 text-indigo-600" />
                Yangi Kod Tayyor (Bir martalik to‘liq ko‘rsatuv):
              </span>
              <Button
                variant="secondary"
                size="sm"
                onClick={() => handleCopy(createdInvitation.plainCode)}
                className="gap-1.5 text-xs"
              >
                {copiedCode ? <CheckCircle className="w-3.5 h-3.5 text-emerald-600" /> : <Copy className="w-3.5 h-3.5" />}
                <span>{copiedCode ? 'Nusxalandi!' : 'Kodni nusxalash'}</span>
              </Button>
            </div>

            <div className="p-3 bg-white dark:bg-slate-900 rounded-lg border border-indigo-100 dark:border-indigo-900/50 text-center">
              <span className="font-mono font-extrabold text-xl tracking-widest text-indigo-600 dark:text-indigo-400">
                {createdInvitation.plainCode}
              </span>
            </div>

            <p className="text-xs text-indigo-700 dark:text-indigo-300 leading-relaxed">
              ⚠️ <strong>Xavfsizlik eslatmasi:</strong> Ushbu to‘liq kodni nusxalab o‘qituvchiga yuboring. Ma’lumotlar bazasida faqat kriptografik SHA-256 xesh saqlanadi va ushbu kod qayta to‘liq ko‘rsatilmaydi.
            </p>
          </motion.div>
        )}

        {statusMsg && (
          <div
            className={`mt-4 p-3 rounded-xl text-xs font-semibold flex items-center gap-2 ${
              statusMsg.isError
                ? 'bg-rose-50 text-rose-700 border border-rose-200'
                : 'bg-emerald-50 text-emerald-700 border border-emerald-200'
            }`}
          >
            {statusMsg.isError ? <AlertCircle className="w-4 h-4 shrink-0" /> : <CheckCircle className="w-4 h-4 shrink-0" />}
            <span>{statusMsg.text}</span>
          </div>
        )}
      </Card>

      {/* Invitations Table */}
      <Card className="p-6 border-slate-200 dark:border-slate-800">
        <div className="flex items-center justify-between mb-4">
          <div>
            <h2 className="text-base font-bold text-foreground">Barcha Taklif Kodlari Ro‘yxati</h2>
            <p className="text-xs text-muted-foreground">Kriptografik prefikslar va faollik statistikasi</p>
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-border text-muted-foreground uppercase font-bold tracking-wider">
                <th className="pb-3 pl-2">Kod Prefiksi</th>
                <th className="pb-3">Maktab / Tashkilot</th>
                <th className="pb-3">Ishlatildi / Limit</th>
                <th className="pb-3">Holati</th>
                <th className="pb-3">Muddati</th>
                <th className="pb-3 pr-2 text-right">Amal</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border/40">
              {invitations.map((inv) => (
                <tr key={inv.id} className="hover:bg-secondary/20 transition-colors">
                  <td className="py-3 pl-2 font-mono font-bold text-foreground">
                    {inv.codePrefix}
                  </td>
                  <td className="py-3 text-foreground font-medium">{inv.schoolName}</td>
                  <td className="py-3">
                    <span className="font-bold text-foreground">{inv.usedCount}</span>
                    <span className="text-muted-foreground"> / {inv.maxUses}</span>
                  </td>
                  <td className="py-3">
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
                  <td className="py-3 text-muted-foreground font-mono">
                    <span className="flex items-center gap-1.5">
                      <Clock className="w-3.5 h-3.5 text-muted-foreground" />
                      {new Date(inv.expiresAt).toLocaleDateString('uz-UZ')}
                    </span>
                  </td>
                  <td className="py-3 pr-2 text-right">
                    {inv.status === 'active' && (
                      <button
                        onClick={() => handleRevoke(inv.id)}
                        className="px-2.5 py-1 rounded-lg bg-rose-50 hover:bg-rose-100 text-rose-700 font-bold text-[11px] border border-rose-200 transition-colors inline-flex items-center gap-1 cursor-pointer"
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
            <div className="p-8 text-center text-xs text-muted-foreground">
              Hozircha birorta ham taklif kodi yaratilmagan.
            </div>
          )}
        </div>
      </Card>
    </div>
  );
};
