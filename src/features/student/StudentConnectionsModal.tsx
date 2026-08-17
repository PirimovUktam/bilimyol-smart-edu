import React, { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { UserCheck, GraduationCap, CheckCircle, AlertCircle } from 'lucide-react';
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

  useEffect(() => {
    if (isOpen) {
      fetchStudentConnections();
    }
  }, [isOpen, fetchStudentConnections]);

  if (!isOpen) return null;

  const handleRedeemParent = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!parentCode.trim()) return;

    setStatusMessage(null);
    const res = await redeemParentLinkCode(parentCode.trim());
    if (res.success) {
      setStatusMessage({ text: res.message, isError: false });
      setParentCode('');
    } else {
      setStatusMessage({ text: res.message, isError: true });
    }
  };

  const handleJoinClass = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!classCode.trim()) return;

    setStatusMessage(null);
    const res = await joinClassByCode(classCode.trim());
    if (res.success) {
      setStatusMessage({ text: res.message, isError: false });
      setClassCode('');
    } else {
      setStatusMessage({ text: res.message, isError: true });
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
          <button onClick={onClose} className="text-muted-foreground hover:text-foreground text-sm font-semibold">
            ✕
          </button>
        </div>

        {/* Tab switcher */}
        <div className="flex p-1 rounded-xl bg-secondary/60">
          <button
            onClick={() => { setActiveTab('parent'); setStatusMessage(null); }}
            className={`w-1/2 py-2 text-xs font-semibold rounded-lg transition-all flex items-center justify-center gap-2 ${
              activeTab === 'parent' ? 'bg-card text-foreground shadow-sm' : 'text-muted-foreground'
            }`}
          >
            <UserCheck className="w-4 h-4" />
            Ota-onaga Ulanish
          </button>
          <button
            onClick={() => { setActiveTab('class'); setStatusMessage(null); }}
            className={`w-1/2 py-2 text-xs font-semibold rounded-lg transition-all flex items-center justify-center gap-2 ${
              activeTab === 'class' ? 'bg-card text-foreground shadow-sm' : 'text-muted-foreground'
            }`}
          >
            <GraduationCap className="w-4 h-4" />
            Sinfga Qo‘shilish
          </button>
        </div>

        {statusMessage && (
          <div
            className={`p-3 rounded-xl text-xs flex items-center gap-2 ${
              statusMessage.isError
                ? 'bg-rose-500/10 text-rose-600 dark:text-rose-400 border border-rose-500/20'
                : 'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border border-emerald-500/20'
            }`}
          >
            {statusMessage.isError ? <AlertCircle className="w-4 h-4 shrink-0" /> : <CheckCircle className="w-4 h-4 shrink-0" />}
            <span>{statusMessage.text}</span>
          </div>
        )}

        {/* Parent Connection Tab */}
        {activeTab === 'parent' && (
          <div className="space-y-4">
            <form onSubmit={handleRedeemParent} className="space-y-3">
              <label className="block text-xs font-semibold text-foreground">
                Ota-onangiz bergan 6 xonali kod:
              </label>
              <div className="flex gap-2">
                <input
                  type="text"
                  placeholder="Masalan: AB12CD"
                  value={parentCode}
                  onChange={(e) => setParentCode(e.target.value.toUpperCase())}
                  maxLength={6}
                  required
                  className="w-full px-3.5 py-2.5 rounded-xl bg-secondary/50 border border-border text-sm font-mono tracking-widest uppercase text-foreground focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
                <Button type="submit" variant="primary">
                  Ulanish
                </Button>
              </div>
            </form>

            {linkedParents.length > 0 && (
              <div className="pt-2 border-t border-border/50">
                <span className="text-xs font-semibold text-muted-foreground block mb-2">Ulangan ota-onalar:</span>
                <div className="space-y-2">
                  {linkedParents.map((p) => (
                    <div key={p.parentId} className="p-3 rounded-xl bg-secondary/30 flex items-center justify-between text-xs">
                      <span className="font-semibold text-foreground">{p.parentName}</span>
                      <span className="text-emerald-600 dark:text-emerald-400 font-medium">Faol ulangan</span>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        )}

        {/* Teacher Class Tab */}
        {activeTab === 'class' && (
          <div className="space-y-4">
            <form onSubmit={handleJoinClass} className="space-y-3">
              <label className="block text-xs font-semibold text-foreground">
                O‘qituvchingiz bergan sinf kodi:
              </label>
              <div className="flex gap-2">
                <input
                  type="text"
                  placeholder="Masalan: MAT7A1"
                  value={classCode}
                  onChange={(e) => setClassCode(e.target.value.toUpperCase())}
                  maxLength={6}
                  required
                  className="w-full px-3.5 py-2.5 rounded-xl bg-secondary/50 border border-border text-sm font-mono tracking-widest uppercase text-foreground focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
                <Button type="submit" variant="primary">
                  Qo‘shilish
                </Button>
              </div>
            </form>

            {joinedClasses.length > 0 && (
              <div className="pt-2 border-t border-border/50">
                <span className="text-xs font-semibold text-muted-foreground block mb-2">A’zo bo‘lgan sinflaringiz:</span>
                <div className="space-y-2">
                  {joinedClasses.map((c) => (
                    <div key={c.id} className="p-3 rounded-xl bg-secondary/30 flex items-center justify-between text-xs">
                      <div>
                        <span className="font-semibold text-foreground">{c.name}</span>
                        <span className="text-muted-foreground ml-2">({c.subject})</span>
                      </div>
                      <span className="text-blue-600 dark:text-blue-400 font-medium">A’zo</span>
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
