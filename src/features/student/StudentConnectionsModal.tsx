import React, { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { UserCheck, GraduationCap, CheckCircle, AlertCircle, Users, BookOpen } from 'lucide-react';
import { useMonitoringStore } from '../../app/store/useMonitoringStore';
import { Button } from '../../presentation/components/Button';

interface Props {
  isOpen: boolean;
  onClose: () => void;
}

export const StudentConnectionsModal: React.FC<Props> = ({ isOpen, onClose }) => {
  const {
    linkedParents,
    joinedClasses,
    redeemParentLinkCode,
    joinClassByCode,
    fetchStudentConnections,
  } = useMonitoringStore();

  const [parentCode, setParentCode] = useState('');
  const [classCode, setClassCode] = useState('');
  const [statusMessage, setStatusMessage] = useState<{ text: string; isError: boolean } | null>(null);
  const [activeTab, setActiveTab] = useState<'parent' | 'class'>('parent');
  const [isSubmitting, setIsSubmitting] = useState(false);

  useEffect(() => {
    if (isOpen) {
      fetchStudentConnections();
    }
  }, [isOpen, fetchStudentConnections]);

  if (!isOpen) return null;

  const handleRedeemParent = async (e: React.FormEvent) => {
    e.preventDefault();
    const cleanCode = parentCode.trim().toUpperCase();
    if (!cleanCode) {
      setStatusMessage({ text: 'Iltimos, ota-onangiz bergan kodni kiriting.', isError: true });
      return;
    }
    if (cleanCode.length !== 6) {
      setStatusMessage({ text: 'Kod 6 ta belgidan iborat bo‘lishi lozim.', isError: true });
      return;
    }

    setIsSubmitting(true);
    setStatusMessage(null);
    try {
      const res = await redeemParentLinkCode(cleanCode);
      if (res.success) {
        setStatusMessage({ text: res.message, isError: false });
        setParentCode('');
        await fetchStudentConnections();
      } else {
        setStatusMessage({ text: res.message, isError: true });
      }
    } catch {
      setStatusMessage({ text: 'Ulanishda xatolik yuz berdi. Qayta urinib ko‘ring.', isError: true });
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleJoinClass = async (e: React.FormEvent) => {
    e.preventDefault();
    const cleanCode = classCode.trim().toUpperCase();
    if (!cleanCode) {
      setStatusMessage({ text: 'Iltimos, o‘qituvchingiz bergan sinf kodini kiriting.', isError: true });
      return;
    }

    setIsSubmitting(true);
    setStatusMessage(null);
    try {
      const res = await joinClassByCode(cleanCode);
      if (res.success) {
        setStatusMessage({ text: res.message, isError: false });
        setClassCode('');
        await fetchStudentConnections();
      } else {
        setStatusMessage({ text: res.message, isError: true });
      }
    } catch {
      setStatusMessage({ text: 'Sinfga qo‘shilishda xatolik yuz berdi. Qayta urinib ko‘ring.', isError: true });
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
      <motion.div
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        className="bg-card border border-border rounded-2xl max-w-lg w-full p-6 shadow-2xl space-y-6"
      >
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-bold text-foreground">Ota-ona va Sinfga Ulanish</h2>
          <button
            onClick={onClose}
            className="text-muted-foreground hover:text-foreground text-sm font-semibold cursor-pointer"
          >
            ✕
          </button>
        </div>

        {/* Tab switcher */}
        <div className="flex p-1 rounded-xl bg-secondary/60">
          <button
            onClick={() => { setActiveTab('parent'); setStatusMessage(null); }}
            className={`w-1/2 py-2 text-xs font-semibold rounded-lg transition-all flex items-center justify-center gap-2 cursor-pointer ${
              activeTab === 'parent' ? 'bg-card text-foreground shadow-sm' : 'text-muted-foreground'
            }`}
          >
            <UserCheck className="w-4 h-4" />
            Ota-onaga Ulanish
          </button>
          <button
            onClick={() => { setActiveTab('class'); setStatusMessage(null); }}
            className={`w-1/2 py-2 text-xs font-semibold rounded-lg transition-all flex items-center justify-center gap-2 cursor-pointer ${
              activeTab === 'class' ? 'bg-card text-foreground shadow-sm' : 'text-muted-foreground'
            }`}
          >
            <GraduationCap className="w-4 h-4" />
            Sinfga Qo‘shilish
          </button>
        </div>

        {statusMessage && (
          <div
            className={`p-3.5 rounded-xl text-xs flex items-center gap-2.5 font-semibold ${
              statusMessage.isError
                ? 'bg-rose-50 text-rose-700 border border-rose-200'
                : 'bg-emerald-50 text-emerald-700 border border-emerald-200'
            }`}
          >
            {statusMessage.isError ? (
              <AlertCircle className="w-4 h-4 shrink-0" />
            ) : (
              <CheckCircle className="w-4 h-4 shrink-0" />
            )}
            <span>{statusMessage.text}</span>
          </div>
        )}

        {/* Parent Connection Tab */}
        {activeTab === 'parent' && (
          <div className="space-y-4">
            <form onSubmit={handleRedeemParent} className="space-y-3">
              <label className="block text-xs font-semibold text-foreground">
                Ota-onangiz bergan 6 xonali ulanish kodi:
              </label>
              <div className="flex gap-2">
                <input
                  type="text"
                  placeholder="Masalan: AB12CD"
                  value={parentCode}
                  onChange={(e) => setParentCode(e.target.value.toUpperCase())}
                  maxLength={6}
                  disabled={isSubmitting}
                  className="w-full px-3.5 py-2.5 rounded-xl bg-secondary/50 border border-border text-sm font-mono tracking-widest uppercase text-foreground focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:opacity-50"
                />
                <Button
                  type="submit"
                  variant="primary"
                  isLoading={isSubmitting}
                  className="shrink-0"
                >
                  Ulanish
                </Button>
              </div>
              <p className="text-[11px] text-muted-foreground">
                Ota-onangiz o‘z panelida generatsiya qilgan 6 xonali kodni kiriting.
              </p>
            </form>

            {linkedParents.length > 0 && (
              <div className="pt-2 border-t border-border/50">
                <span className="text-xs font-semibold text-muted-foreground block mb-2 flex items-center gap-1.5">
                  <Users className="w-3.5 h-3.5" /> Ulangan ota-onalar:
                </span>
                <div className="space-y-2">
                  {linkedParents.map((p) => (
                    <div key={p.parentId} className="p-3 rounded-xl bg-secondary/30 flex items-center justify-between text-xs border border-border/40">
                      <span className="font-semibold text-foreground">{p.parentName}</span>
                      <span className="text-muted-foreground">
                        {p.linkedAt ? new Date(p.linkedAt).toLocaleDateString('uz-UZ') : 'Faol'}
                      </span>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        )}

        {/* Teacher Class Connection Tab */}
        {activeTab === 'class' && (
          <div className="space-y-4">
            <form onSubmit={handleJoinClass} className="space-y-3">
              <label className="block text-xs font-semibold text-foreground">
                O‘qituvchingiz bergan 6 xonali sinf kodi:
              </label>
              <div className="flex gap-2">
                <input
                  type="text"
                  placeholder="Masalan: CL7A01"
                  value={classCode}
                  onChange={(e) => setClassCode(e.target.value.toUpperCase())}
                  maxLength={6}
                  disabled={isSubmitting}
                  className="w-full px-3.5 py-2.5 rounded-xl bg-secondary/50 border border-border text-sm font-mono tracking-widest uppercase text-foreground focus:outline-none focus:ring-2 focus:ring-indigo-500 disabled:opacity-50"
                />
                <Button
                  type="submit"
                  variant="primary"
                  isLoading={isSubmitting}
                  className="shrink-0"
                >
                  Qo‘shilish
                </Button>
              </div>
              <p className="text-[11px] text-muted-foreground">
                O‘qituvchingiz doskada yoki guruhda e’lon qilgan sinf kodini kiriting.
              </p>
            </form>

            {joinedClasses.length > 0 && (
              <div className="pt-2 border-t border-border/50">
                <span className="text-xs font-semibold text-muted-foreground block mb-2 flex items-center gap-1.5">
                  <BookOpen className="w-3.5 h-3.5" /> A’zo bo‘lgan sinflaringiz:
                </span>
                <div className="space-y-2">
                  {joinedClasses.map((c) => (
                    <div key={c.id} className="p-3 rounded-xl bg-secondary/30 flex items-center justify-between text-xs border border-border/40">
                      <div>
                        <span className="font-semibold text-foreground block">{c.name}</span>
                        <span className="text-muted-foreground">{c.subject} • {c.gradeLevel}</span>
                      </div>
                      <span className="px-2 py-0.5 rounded-md bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 font-semibold text-[11px]">
                        A’zo
                      </span>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        )}
      </motion.div>
    </div>
  );
};
