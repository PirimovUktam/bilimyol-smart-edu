import React, { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import {
  Users,
  GraduationCap,
  Clock,
  AlertCircle,
  PlusCircle,
  TrendingUp,
  Search,
  CheckCircle,
  Copy,
} from 'lucide-react';
import { useMonitoringStore } from '../../app/store/useMonitoringStore';
import { Button } from '../../presentation/components/Button';
import { Card } from '../../presentation/components/Card';
import { Badge } from '../../presentation/components/Badge';

export const TeacherDashboardView: React.FC = () => {
  const {
    classes,
    activeClass,
    classStudents,
    isLoading,
    fetchTeacherData,
    selectClass,
    createTeacherClass,
  } = useMonitoringStore();

  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [newClassName, setNewClassName] = useState('');
  const [newSubject, setNewSubject] = useState('Matematika');
  const [newGradeLevel, setNewGradeLevel] = useState('7-sinf');
  const [searchTerm, setSearchTerm] = useState('');
  const [copiedCode, setCopiedCode] = useState(false);

  useEffect(() => {
    fetchTeacherData();
  }, [fetchTeacherData]);

  const handleCreateClass = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newClassName.trim()) return;
    await createTeacherClass(newClassName.trim(), newSubject, newGradeLevel);
    setNewClassName('');
    setIsCreateModalOpen(false);
  };

  const handleCopyClassCode = (code: string) => {
    navigator.clipboard.writeText(code);
    setCopiedCode(true);
    setTimeout(() => setCopiedCode(false), 2000);
  };

  const filteredStudents = classStudents.filter((s) =>
    s.name.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const totalStudents = classStudents.length;
  const avgMastery =
    totalStudents > 0
      ? Math.round(classStudents.reduce((acc, s) => acc + s.overallScore, 0) / totalStudents)
      : 0;
  const activeTodayCount = classStudents.filter((s) => s.todayActiveMinutes > 0).length;
  const attentionCount = classStudents.filter((s) => s.status === 'E’tibor').length;

  return (
    <div className="max-w-6xl mx-auto px-4 py-8">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <span className="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-blue-500/10 text-blue-600 dark:text-blue-400 border border-blue-500/20">
              O‘qituvchi Paneli
            </span>
            <span className="text-xs text-muted-foreground">• Sinf nazorati va pedagogik tahlil</span>
          </div>
          <h1 className="text-3xl font-extrabold text-foreground tracking-tight">
            Sinflar va O‘quvchilar Nazorati
          </h1>
          <p className="text-muted-foreground text-sm mt-1">
            Sinf o‘zlashtirishi, davomat, zaif mavzular va individual o‘quvchilar progressi
          </p>
        </div>

        <Button
          variant="primary"
          className="flex items-center gap-2 shadow-sm"
          onClick={() => setIsCreateModalOpen(true)}
        >
          <PlusCircle className="w-4 h-4" />
          Yangi sinf ochish
        </Button>
      </div>

      {/* Class Selector Tabs */}
      {classes.length > 0 && (
        <div className="flex items-center gap-3 overflow-x-auto pb-3 mb-6">
          {classes.map((c) => {
            const isActive = activeClass?.id === c.id;
            return (
              <button
                key={c.id}
                onClick={() => selectClass(c.id)}
                className={`flex items-center gap-2.5 px-4 py-2.5 rounded-xl text-sm font-semibold transition-all ${
                  isActive
                    ? 'bg-blue-600 text-white shadow-md shadow-blue-500/20'
                    : 'bg-card text-muted-foreground hover:text-foreground border border-border/50 hover:border-border'
                }`}
              >
                <GraduationCap className="w-4 h-4" />
                <span>{c.name}</span>
                <span className={`text-xs px-2 py-0.5 rounded-md font-mono ${
                  isActive ? 'bg-white/20 text-white' : 'bg-secondary text-foreground'
                }`}>
                  {c.classCode}
                </span>
              </button>
            );
          })}
        </div>
      )}

      {/* Empty State */}
      {classes.length === 0 && !isLoading && (
        <Card className="p-12 text-center border-dashed border-2">
          <div className="w-16 h-16 rounded-2xl bg-blue-500/10 text-blue-600 flex items-center justify-center mx-auto mb-4">
            <Users className="w-8 h-8" />
          </div>
          <h2 className="text-xl font-bold text-foreground mb-2">Hali sinflar yaratilmagan</h2>
          <p className="text-muted-foreground text-sm max-w-md mx-auto mb-6">
            O‘quvchilaringizni biriktirish va dars monitoringini boshlash uchun birinchi sinfingizni oching.
          </p>
          <Button variant="primary" onClick={() => setIsCreateModalOpen(true)}>
            Yangi sinf ochish
          </Button>
        </Card>
      )}

      {activeClass && (
        <div className="space-y-6">
          {/* Class Code Banner */}
          <div className="p-4 rounded-2xl bg-gradient-to-r from-blue-600/10 via-indigo-600/10 to-transparent border border-blue-500/20 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-blue-600 text-white flex items-center justify-center font-bold">
                {activeClass.gradeLevel.charAt(0)}
              </div>
              <div>
                <div className="flex items-center gap-2">
                  <h3 className="font-bold text-foreground">{activeClass.name}</h3>
                  <Badge variant="slate">{activeClass.subject}</Badge>
                </div>
                <p className="text-xs text-muted-foreground">O‘quvchilar qo‘shilishi uchun sinf kodi</p>
              </div>
            </div>

            <div className="flex items-center gap-3">
              <div className="px-3 py-1.5 rounded-xl bg-card border border-border flex items-center gap-2 font-mono font-bold text-blue-600 dark:text-blue-400 text-base">
                <span>{activeClass.classCode}</span>
              </div>
              <Button
                variant="secondary"
                size="sm"
                onClick={() => handleCopyClassCode(activeClass.classCode)}
                className="gap-1.5"
              >
                {copiedCode ? <CheckCircle className="w-4 h-4 text-emerald-500" /> : <Copy className="w-4 h-4" />}
                <span>{copiedCode ? 'Nusxalandi' : 'Kodni nusxalash'}</span>
              </Button>
            </div>
          </div>

          {/* Quick Metrics Grid */}
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            <Card className="p-5 border-border/60">
              <div className="flex items-center justify-between mb-2">
                <span className="text-xs font-medium text-muted-foreground">O‘quvchilar soni</span>
                <Users className="w-4 h-4 text-blue-500" />
              </div>
              <div className="text-3xl font-extrabold text-foreground">{totalStudents}</div>
              <p className="text-xs text-muted-foreground mt-2">Sinf a’zolari ro‘yxatida</p>
            </Card>

            <Card className="p-5 border-border/60">
              <div className="flex items-center justify-between mb-2">
                <span className="text-xs font-medium text-muted-foreground">O‘rtacha o‘zlashtirish</span>
                <TrendingUp className="w-4 h-4 text-emerald-500" />
              </div>
              <div className="text-3xl font-extrabold text-foreground">{avgMastery}%</div>
              <p className="text-xs text-muted-foreground mt-2">Matematika fanidan sinf darajasi</p>
            </Card>

            <Card className="p-5 border-border/60">
              <div className="flex items-center justify-between mb-2">
                <span className="text-xs font-medium text-muted-foreground">Bugun faol o‘quvchilar</span>
                <Clock className="w-4 h-4 text-purple-500" />
              </div>
              <div className="text-3xl font-extrabold text-foreground">
                {activeTodayCount} <span className="text-base text-muted-foreground font-normal">/ {totalStudents}</span>
              </div>
              <p className="text-xs text-muted-foreground mt-2">Bugun platformada dars qilganlar</p>
            </Card>

            <Card className="p-5 border-border/60">
              <div className="flex items-center justify-between mb-2">
                <span className="text-xs font-medium text-muted-foreground">E’tibor kerak bo‘lganlar</span>
                <AlertCircle className="w-4 h-4 text-amber-500" />
              </div>
              <div className="text-3xl font-extrabold text-amber-600 dark:text-amber-400">
                {attentionCount}
              </div>
              <p className="text-xs text-muted-foreground mt-2">O‘zlashtirishi 55% dan past</p>
            </Card>
          </div>

          {/* Student Roster Table */}
          <Card className="p-6 border-border/60">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-6">
              <div>
                <h2 className="text-base font-bold text-foreground">Sinf O‘quvchilari Ro‘yxati</h2>
                <p className="text-xs text-muted-foreground mt-0.5">Har bir o‘quvchining real ko‘rsatkichlari</p>
              </div>

              <div className="relative w-full sm:w-64">
                <Search className="w-4 h-4 text-muted-foreground absolute left-3 top-1/2 -translate-y-1/2" />
                <input
                  type="text"
                  placeholder="O‘quvchi qidirish..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="w-full pl-9 pr-4 py-2 rounded-xl bg-secondary/50 border border-border text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
              </div>
            </div>

            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm">
                <thead>
                  <tr className="border-b border-border text-xs text-muted-foreground uppercase font-semibold">
                    <th className="pb-3 pl-2">O‘quvchi</th>
                    <th className="pb-3">O‘zlashtirish</th>
                    <th className="pb-3">Bugungi faol vaqt</th>
                    <th className="pb-3">Topshiriqlar</th>
                    <th className="pb-3">Kuchsiz mavzusi</th>
                    <th className="pb-3 pr-2">Holati</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border/40">
                  {filteredStudents.map((student) => (
                    <tr key={student.studentId} className="hover:bg-secondary/30 transition-colors">
                      <td className="py-4 pl-2">
                        <div className="font-semibold text-foreground">{student.name}</div>
                        <div className="text-xs text-muted-foreground">{student.email || 'student@bilimyol.uz'}</div>
                      </td>
                      <td className="py-4">
                        <div className="flex items-center gap-2">
                          <span className="font-bold text-foreground">{student.overallScore}%</span>
                          <div className="w-16 h-1.5 bg-secondary rounded-full overflow-hidden">
                            <div
                              className={`h-full rounded-full ${
                                student.overallScore >= 80
                                  ? 'bg-emerald-500'
                                  : student.overallScore >= 65
                                  ? 'bg-blue-500'
                                  : 'bg-amber-500'
                              }`}
                              style={{ width: `${student.overallScore}%` }}
                            />
                          </div>
                        </div>
                      </td>
                      <td className="py-4">
                        <span className="font-medium text-foreground">{student.todayActiveMinutes} daq</span>
                      </td>
                      <td className="py-4 text-xs text-muted-foreground">
                        {student.completedLessonsCount} dars • {student.totalAttemptsCount} savol
                      </td>
                      <td className="py-4">
                        <span className="text-xs px-2.5 py-1 rounded-lg bg-secondary font-medium text-foreground">
                          {student.weakestSkillName} ({student.weakestSkillScore}%)
                        </span>
                      </td>
                      <td className="py-4 pr-2">
                        <Badge
                          variant={
                            student.status === 'A’lo'
                              ? 'emerald'
                              : student.status === 'Yaxshi'
                              ? 'blue'
                              : student.status === 'Nazorat'
                              ? 'amber'
                              : 'rose'
                          }
                        >
                          {student.status}
                        </Badge>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>

              {filteredStudents.length === 0 && (
                <div className="p-8 text-center text-xs text-muted-foreground">
                  Qidiruv bo‘yicha o‘quvchi topilmadi.
                </div>
              )}
            </div>
          </Card>
        </div>
      )}

      {/* Create Class Modal */}
      {isCreateModalOpen && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4">
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            className="bg-card border border-border rounded-2xl max-w-md w-full p-6 shadow-2xl space-y-5"
          >
            <div className="flex items-center justify-between">
              <h2 className="text-lg font-bold text-foreground">Yangi Sinf Yaratish</h2>
              <button
                onClick={() => setIsCreateModalOpen(false)}
                className="text-muted-foreground hover:text-foreground text-sm font-semibold"
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleCreateClass} className="space-y-4">
              <div>
                <label className="block text-xs font-semibold text-foreground mb-1">
                  Sinf Nomi
                </label>
                <input
                  type="text"
                  placeholder="Masalan: 7-A Sinf"
                  value={newClassName}
                  onChange={(e) => setNewClassName(e.target.value)}
                  required
                  className="w-full px-3.5 py-2.5 rounded-xl bg-secondary/50 border border-border text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-foreground mb-1">
                  Fan
                </label>
                <select
                  value={newSubject}
                  onChange={(e) => setNewSubject(e.target.value)}
                  className="w-full px-3.5 py-2.5 rounded-xl bg-secondary/50 border border-border text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                  <option value="Matematika">Matematika</option>
                  <option value="Ingliz tili">Ingliz tili</option>
                </select>
              </div>

              <div>
                <label className="block text-xs font-semibold text-foreground mb-1">
                  Sinf Darajasi
                </label>
                <select
                  value={newGradeLevel}
                  onChange={(e) => setNewGradeLevel(e.target.value)}
                  className="w-full px-3.5 py-2.5 rounded-xl bg-secondary/50 border border-border text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                  <option value="5-sinf">5-sinf</option>
                  <option value="6-sinf">6-sinf</option>
                  <option value="7-sinf">7-sinf</option>
                  <option value="8-sinf">8-sinf</option>
                  <option value="9-sinf">9-sinf</option>
                </select>
              </div>

              <div className="pt-2 flex gap-3">
                <Button
                  type="button"
                  variant="secondary"
                  className="w-1/2"
                  onClick={() => setIsCreateModalOpen(false)}
                >
                  Bekor qilish
                </Button>
                <Button type="submit" variant="primary" className="w-1/2">
                  Sinfni ochish
                </Button>
              </div>
            </form>
          </motion.div>
        </div>
      )}
    </div>
  );
};
