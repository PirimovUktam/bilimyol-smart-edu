import React, { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import {
  Clock,
  TrendingUp,
  Flame,
  Award,
  AlertTriangle,
  Sparkles,
  PlusCircle,
  Copy,
  CheckCircle,
  UserCheck,
} from 'lucide-react';
import { useMonitoringStore } from '../../app/store/useMonitoringStore';
import { Button } from '../../presentation/components/Button';
import { Card } from '../../presentation/components/Card';
import { Badge } from '../../presentation/components/Badge';

export const ParentDashboardView: React.FC = () => {
  const {
    children,
    activeChild,
    childWeeklyStats,
    childAlerts,
    generatedLinkCode,
    isLoading,
    fetchParentData,
    selectChild,
    createParentLinkCode,
  } = useMonitoringStore();

  const [isLinkModalOpen, setIsLinkModalOpen] = useState(false);
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    fetchParentData();
  }, [fetchParentData]);

  const handleGenerateCode = async () => {
    await createParentLinkCode();
    setIsLinkModalOpen(true);
  };

  const handleCopyCode = () => {
    if (generatedLinkCode?.code) {
      navigator.clipboard.writeText(generatedLinkCode.code);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  return (
    <div className="max-w-6xl mx-auto px-4 py-8">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <span className="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border border-emerald-500/20">
              Ota-ona Nazorati
            </span>
            <span className="text-xs text-muted-foreground">• Haqiqiy o‘quv faoliyati</span>
          </div>
          <h1 className="text-3xl font-extrabold text-foreground tracking-tight">
            Farzandingiz Rivojlanishi
          </h1>
          <p className="text-muted-foreground text-sm mt-1">
            O‘quvchining faol o‘rganish vaqti, mavzular o‘zlashtirishi va pedagogik tavsiyalar
          </p>
        </div>

        <Button
          variant="primary"
          className="flex items-center gap-2 shadow-sm"
          onClick={handleGenerateCode}
        >
          <PlusCircle className="w-4 h-4" />
          Farzandni ulash
        </Button>
      </div>

      {/* Children Selector Tabs */}
      {children.length > 0 && (
        <div className="flex items-center gap-3 overflow-x-auto pb-3 mb-6">
          {children.map((c) => {
            const isActive = activeChild?.studentId === c.studentId;
            return (
              <button
                key={c.studentId}
                onClick={() => selectChild(c.studentId)}
                className={`flex items-center gap-2.5 px-4 py-2 rounded-xl text-sm font-medium transition-all ${
                  isActive
                    ? 'bg-blue-600 text-white shadow-md shadow-blue-500/20'
                    : 'bg-card text-muted-foreground hover:text-foreground border border-border/50 hover:border-border'
                }`}
              >
                <div className="w-6 h-6 rounded-full bg-white/20 flex items-center justify-center text-xs font-bold">
                  {c.firstName.charAt(0)}
                </div>
                <span>{c.displayName}</span>
                <span
                  className={`text-xs px-1.5 py-0.5 rounded-md ${
                    isActive ? 'bg-white/20 text-white' : 'bg-secondary text-foreground'
                  }`}
                >
                  {c.overallScore}%
                </span>
              </button>
            );
          })}
        </div>
      )}

      {/* Empty State if no children linked */}
      {children.length === 0 && !isLoading && (
        <Card className="p-12 text-center border-dashed border-2">
          <div className="w-16 h-16 rounded-2xl bg-blue-500/10 text-blue-600 flex items-center justify-center mx-auto mb-4">
            <UserCheck className="w-8 h-8" />
          </div>
          <h2 className="text-xl font-bold text-foreground mb-2">Farzand hali ulanmagan</h2>
          <p className="text-muted-foreground text-sm max-w-md mx-auto mb-6">
            Farzandingizning darslari, faol o‘quv vaqti va mavzular o‘zlashtirishini kuzatish uchun 6 xonali ulanish kodini yarating.
          </p>
          <Button variant="primary" onClick={handleGenerateCode}>
            Ulanish kodini olish
          </Button>
        </Card>
      )}

      {/* Main Dashboard for Active Child */}
      {activeChild && (
        <div className="space-y-6">
          {/* Key Metrics Grid */}
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            {/* Active Study Time Card */}
            <Card className="p-5 border-border/60 bg-gradient-to-br from-card to-blue-500/5">
              <div className="flex items-center justify-between mb-3">
                <span className="text-xs font-medium text-muted-foreground">Bugungi faol o‘qish</span>
                <div className="w-8 h-8 rounded-lg bg-blue-500/10 text-blue-600 flex items-center justify-center">
                  <Clock className="w-4 h-4" />
                </div>
              </div>
              <div className="flex items-baseline gap-2">
                <span className="text-3xl font-extrabold text-foreground tracking-tight">
                  {activeChild.todayActiveMinutes}
                </span>
                <span className="text-sm font-semibold text-muted-foreground">daqiqa</span>
              </div>
              <div className="mt-3">
                <div className="flex justify-between text-xs text-muted-foreground mb-1">
                  <span>Kunlik maqsad ({activeChild.todayGoalMinutes} daq)</span>
                  <span className="font-semibold text-foreground">{activeChild.goalCompletionPercent}%</span>
                </div>
                <div className="h-1.5 w-full bg-secondary rounded-full overflow-hidden">
                  <div
                    className="h-full bg-blue-600 rounded-full transition-all duration-500"
                    style={{ width: `${Math.min(100, activeChild.goalCompletionPercent)}%` }}
                  />
                </div>
              </div>
            </Card>

            {/* Overall Mastery */}
            <Card className="p-5 border-border/60 bg-gradient-to-br from-card to-emerald-500/5">
              <div className="flex items-center justify-between mb-3">
                <span className="text-xs font-medium text-muted-foreground">Umumiy o‘zlashtirish</span>
                <div className="w-8 h-8 rounded-lg bg-emerald-500/10 text-emerald-600 flex items-center justify-center">
                  <TrendingUp className="w-4 h-4" />
                </div>
              </div>
              <div className="flex items-baseline gap-2">
                <span className="text-3xl font-extrabold text-foreground tracking-tight">
                  {activeChild.overallScore}%
                </span>
                <Badge variant={activeChild.overallScore >= 75 ? 'emerald' : 'amber'}>
                  {activeChild.overallScore >= 75 ? 'Yaxshi' : 'E’tibor kerak'}
                </Badge>
              </div>
              <p className="text-xs text-muted-foreground mt-3 flex items-center gap-1">
                <span>Eng kuchli:</span>
                <strong className="text-foreground">{activeChild.strongestSkillName} ({activeChild.strongestSkillScore}%)</strong>
              </p>
            </Card>

            {/* Streak & Consistency */}
            <Card className="p-5 border-border/60 bg-gradient-to-br from-card to-amber-500/5">
              <div className="flex items-center justify-between mb-3">
                <span className="text-xs font-medium text-muted-foreground">Ketma-ket kunlar</span>
                <div className="w-8 h-8 rounded-lg bg-amber-500/10 text-amber-600 flex items-center justify-center">
                  <Flame className="w-4 h-4" />
                </div>
              </div>
              <div className="flex items-baseline gap-2">
                <span className="text-3xl font-extrabold text-foreground tracking-tight">
                  {activeChild.streakDays}
                </span>
                <span className="text-sm font-semibold text-muted-foreground">kun uzluksiz</span>
              </div>
              <p className="text-xs text-muted-foreground mt-3">
                Har kuni muntazam dars qilib kelmoqda
              </p>
            </Card>

            {/* Total XP Earned */}
            <Card className="p-5 border-border/60 bg-gradient-to-br from-card to-purple-500/5">
              <div className="flex items-center justify-between mb-3">
                <span className="text-xs font-medium text-muted-foreground">To‘plangan tajriba</span>
                <div className="w-8 h-8 rounded-lg bg-purple-500/10 text-purple-600 flex items-center justify-center">
                  <Award className="w-4 h-4" />
                </div>
              </div>
              <div className="flex items-baseline gap-2">
                <span className="text-3xl font-extrabold text-foreground tracking-tight">
                  {activeChild.xp}
                </span>
                <span className="text-sm font-semibold text-purple-600 dark:text-purple-400">XP</span>
              </div>
              <p className="text-xs text-muted-foreground mt-3">
                To‘g‘ri javoblar va yakunlangan darslar uchun
              </p>
            </Card>
          </div>

          {/* Middle Row: Skills Breakdown & Weekly Activity */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Subject Skills Mastery Card */}
            <Card className="p-6 border-border/60">
              <div className="flex items-center justify-between mb-6">
                <div>
                  <h2 className="text-base font-bold text-foreground">Mavzular bo‘yicha o‘zlashtirish</h2>
                  <p className="text-xs text-muted-foreground mt-0.5">Matematika fanining asosiy bo‘limlari</p>
                </div>
                <Badge variant="slate">4 ta bo‘lim</Badge>
              </div>

              <div className="space-y-4">
                {[
                  { name: 'Algebra', score: 82, status: 'Mustahkam', color: 'bg-emerald-500' },
                  { name: 'Tenglamalar', score: 72, status: 'Yaxshi', color: 'bg-blue-500' },
                  { name: 'Funksiyalar', score: 54, status: 'Diqqat kerak', color: 'bg-amber-500', isWeak: true },
                  { name: 'Grafiklar', score: 75, status: 'Yaxshi', color: 'bg-indigo-500' },
                ].map((skill) => (
                  <div key={skill.name} className="p-3 rounded-xl bg-secondary/30 border border-border/30">
                    <div className="flex items-center justify-between text-sm mb-2">
                      <div className="flex items-center gap-2">
                        <span className="font-semibold text-foreground">{skill.name}</span>
                        {skill.isWeak && (
                          <span className="text-[11px] px-2 py-0.5 rounded-full bg-amber-500/10 text-amber-600 dark:text-amber-400 font-medium">
                            Diqqat
                          </span>
                        )}
                      </div>
                      <div className="flex items-center gap-2">
                        <span className="text-xs text-muted-foreground">{skill.status}</span>
                        <span className="font-bold text-foreground">{skill.score}%</span>
                      </div>
                    </div>
                    <div className="h-2 w-full bg-secondary rounded-full overflow-hidden">
                      <div
                        className={`h-full ${skill.color} rounded-full transition-all duration-500`}
                        style={{ width: `${skill.score}%` }}
                      />
                    </div>
                  </div>
                ))}
              </div>
            </Card>

            {/* Weekly Activity Bar Chart */}
            <Card className="p-6 border-border/60">
              <div className="flex items-center justify-between mb-6">
                <div>
                  <h2 className="text-base font-bold text-foreground">Haftalik faoliyat</h2>
                  <p className="text-xs text-muted-foreground mt-0.5">Oxirgi 7 kunlik faol o‘quv vaqti (daqiqa)</p>
                </div>
                <div className="flex items-center gap-1 text-xs text-emerald-600 dark:text-emerald-400 font-medium">
                  <Clock className="w-3.5 h-3.5" />
                  <span>O‘rtacha 37 daq/kun</span>
                </div>
              </div>

              <div className="grid grid-cols-7 gap-2 pt-4 items-end h-48">
                {childWeeklyStats.map((d, i) => {
                  const maxMins = 60;
                  const heightPercent = Math.min(100, Math.max(15, (d.activeMinutes / maxMins) * 100));
                  const isToday = i === childWeeklyStats.length - 1;

                  return (
                    <div key={d.dayName} className="flex flex-col items-center gap-2 h-full justify-end">
                      <span className="text-[11px] font-bold text-foreground">{d.activeMinutes}m</span>
                      <div className="w-full bg-secondary/50 rounded-t-lg h-32 flex items-end p-1">
                        <motion.div
                          initial={{ height: 0 }}
                          animate={{ height: `${heightPercent}%` }}
                          transition={{ duration: 0.5, delay: i * 0.05 }}
                          className={`w-full rounded-md ${
                            isToday ? 'bg-blue-600 shadow-md shadow-blue-500/30' : 'bg-blue-500/60'
                          }`}
                        />
                      </div>
                      <span className={`text-[11px] font-medium ${isToday ? 'text-blue-600 font-bold' : 'text-muted-foreground'}`}>
                        {d.dayName.substring(0, 3)}
                      </span>
                    </div>
                  );
                })}
              </div>
            </Card>
          </div>

          {/* AI Pedagogical Advice & Alerts */}
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* AI Advice Card (2 cols) */}
            <Card className="lg:col-span-2 p-6 border-blue-500/30 bg-gradient-to-br from-card via-card to-blue-500/5 relative overflow-hidden">
              <div className="flex items-start gap-4">
                <div className="w-12 h-12 rounded-2xl bg-gradient-to-br from-blue-600 to-indigo-600 text-white flex items-center justify-center shadow-lg shadow-blue-500/20 shrink-0">
                  <Sparkles className="w-6 h-6" />
                </div>
                <div>
                  <div className="flex items-center gap-2 mb-1">
                    <h2 className="text-base font-bold text-foreground">Yo‘lchi AI — Pedagogik Tavsiya</h2>
                    <span className="text-[10px] uppercase font-extrabold px-2 py-0.5 rounded bg-blue-500/10 text-blue-600 border border-blue-500/20">
                      AI Tahlil
                    </span>
                  </div>
                  <p className="text-sm text-foreground/90 leading-relaxed mt-2">
                    {activeChild.pedagogicalAdvice}
                  </p>
                  <div className="mt-4 flex flex-wrap items-center gap-3 text-xs text-muted-foreground">
                    <span className="flex items-center gap-1">
                      <span className="w-2 h-2 rounded-full bg-emerald-500" />
                      Algebra: A’lo daraja
                    </span>
                    <span className="flex items-center gap-1">
                      <span className="w-2 h-2 rounded-full bg-amber-500" />
                      Funksiyalar: 1 ta mustahkamlash darsi kutilmoqda
                    </span>
                  </div>
                </div>
              </div>
            </Card>

            {/* Pedagogical Alerts Card (1 col) */}
            <Card className="p-6 border-border/60">
              <div className="flex items-center gap-2 mb-4">
                <AlertTriangle className="w-4 h-4 text-amber-500" />
                <h2 className="text-base font-bold text-foreground">Diqqat Qiling</h2>
              </div>
              <div className="space-y-3">
                {childAlerts.length > 0 ? (
                  childAlerts.map((alert) => (
                    <div
                      key={alert.id}
                      className="p-3 rounded-xl bg-amber-500/10 border border-amber-500/20 text-xs space-y-1"
                    >
                      <div className="font-semibold text-amber-700 dark:text-amber-300">
                        {alert.title}
                      </div>
                      <p className="text-muted-foreground">{alert.description}</p>
                    </div>
                  ))
                ) : (
                  <div className="p-4 rounded-xl bg-secondary/30 text-center text-xs text-muted-foreground">
                    Hech qanday kritik ogohlantirish yo‘q. Ta’lim me’yorda davom etmoqda.
                  </div>
                )}
              </div>
            </Card>
          </div>
        </div>
      )}

      {/* Link Child Modal */}
      {isLinkModalOpen && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            className="bg-card border border-border rounded-2xl max-w-md w-full p-6 shadow-2xl space-y-5"
          >
            <div className="flex items-center justify-between">
              <h2 className="text-lg font-bold text-foreground">Farzandni ulash kodi</h2>
              <button
                onClick={() => setIsLinkModalOpen(false)}
                className="text-muted-foreground hover:text-foreground text-sm font-semibold"
              >
                ✕
              </button>
            </div>

            <p className="text-xs text-muted-foreground leading-relaxed">
              Farzandingiz o‘z profilidagi <strong>“Ota-onaga ulanish”</strong> bo‘limiga quyidagi 6 xonali kodni kiritishi kerak:
            </p>

            <div className="p-4 rounded-2xl bg-secondary/50 border border-border flex items-center justify-between">
              <span className="text-2xl font-mono font-extrabold tracking-widest text-blue-600 dark:text-blue-400">
                {generatedLinkCode?.code || '------'}
              </span>
              <Button variant="secondary" size="sm" onClick={handleCopyCode} className="gap-1.5">
                {copied ? <CheckCircle className="w-4 h-4 text-emerald-500" /> : <Copy className="w-4 h-4" />}
                <span>{copied ? 'Nusxalandi' : 'Nusxa'}</span>
              </Button>
            </div>

            <div className="text-[11px] text-muted-foreground bg-blue-500/10 text-blue-700 dark:text-blue-300 p-3 rounded-xl">
              ℹ️ Ushbu kod 24 soat davomida amal qiladi va faqat bir martalik xavfsiz bog‘lanish uchundir.
            </div>

            <Button
              variant="primary"
              className="w-full"
              onClick={() => {
                setIsLinkModalOpen(false);
                fetchParentData();
              }}
            >
              Tushundim
            </Button>
          </motion.div>
        </div>
      )}
    </div>
  );
};
