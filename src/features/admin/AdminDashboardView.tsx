import React, { useEffect, useState, useTransition } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  ShieldAlert,
  PlusCircle,
  CheckCircle,
  AlertCircle,
  RefreshCw,
  BookOpen,
  Target,
  FileText,
  HelpCircle,
  Edit3,
  Trash2,
  Archive,
  Eye,
  EyeOff,
  Check,
} from 'lucide-react';
import { Button } from '../../presentation/components/Button';
import { Card } from '../../presentation/components/Card';
import { Badge } from '../../presentation/components/Badge';
import {
  adminContentService,
  AdminLessonRecord,
  AdminQuestionRecord,
} from '../../data/services/AdminContentService';
import { Course } from '../../domain/entities/Course';
import { Skill } from '../../domain/entities/Skill';

type AdminTab = 'courses' | 'skills' | 'lessons' | 'questions';

export const AdminDashboardView: React.FC = () => {
  const [activeTab, setActiveTab] = useState<AdminTab>('courses');
  const [, startTransition] = useTransition();
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [statusMsg, setStatusMsg] = useState<{ text: string; isError: boolean } | null>(null);

  // CMS Content States
  const [courses, setCourses] = useState<Course[]>([]);
  const [skills, setSkills] = useState<Skill[]>([]);
  const [lessons, setLessons] = useState<AdminLessonRecord[]>([]);
  const [questions, setQuestions] = useState<AdminQuestionRecord[]>([]);
  const [isCmsLoading, setIsCmsLoading] = useState(false);

  // Filter state for Skills/Lessons/Questions
  const [selectedCourseFilter, setSelectedCourseFilter] = useState<string>('course_math_01');
  const [selectedSkillFilter, setSelectedSkillFilter] = useState<string>('');

  // Course Form Modal state
  const [showCourseModal, setShowCourseModal] = useState(false);
  const [courseForm, setCourseForm] = useState<Partial<Course>>({
    id: '',
    title: '',
    description: '',
    subject: 'mathematics',
    primaryColorHex: '#4F46E5',
    secondaryColorHex: '#818CF8',
    totalStudentsEstimate: 500,
    isActive: true,
  });

  // Skill Form Modal state
  const [showSkillModal, setShowSkillModal] = useState(false);
  const [skillForm, setSkillForm] = useState<Partial<Skill>>({
    id: '',
    courseId: 'course_math_01',
    name: '',
    code: '',
    description: '',
    orderIndex: 1,
  });

  // Lesson Form Modal state
  const [showLessonModal, setShowLessonModal] = useState(false);
  const [lessonForm, setLessonForm] = useState<Partial<AdminLessonRecord>>({
    id: '',
    courseId: 'course_math_01',
    skillId: 'skill_math_functions',
    title: '',
    summary: '',
    estimatedMinutes: 15,
    isPublished: true,
    isArchived: false,
  });

  // Question Form Modal state
  const [showQuestionModal, setShowQuestionModal] = useState(false);
  const [questionForm, setQuestionForm] = useState<{
    id: string;
    courseId: string;
    skillId: string;
    text: string;
    option0: string;
    option1: string;
    option2: string;
    option3: string;
    correctIndex: number;
    difficulty: 'easy' | 'medium' | 'hard';
    explanation: string;
    formulaLatex: string;
    isPlacement: boolean;
  }>({
    id: '',
    courseId: 'course_math_01',
    skillId: 'skill_math_algebra',
    text: '',
    option0: '',
    option1: '',
    option2: '',
    option3: '',
    correctIndex: 0,
    difficulty: 'medium',
    explanation: '',
    formulaLatex: '',
    isPlacement: false,
  });

  // Initial load
  useEffect(() => {
    loadAllCmsData();
  }, []);

  const loadAllCmsData = async () => {
    setIsCmsLoading(true);
    try {
      const [cList, sList, lList, qList] = await Promise.all([
        adminContentService.getCourses(),
        adminContentService.getSkills(),
        adminContentService.getLessons(),
        adminContentService.getQuestions(),
      ]);
      setCourses(cList);
      setSkills(sList);
      setLessons(lList);
      setQuestions(qList);
    } catch (err) {
      console.warn('Error loading CMS data:', err);
    } finally {
      setIsCmsLoading(false);
    }
  };

  // Handlers for Course CMS
  const handleSaveCourse = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!courseForm.title?.trim()) return;
    setIsSubmitting(true);
    try {
      await adminContentService.saveCourse(courseForm);
      await loadAllCmsData();
      setShowCourseModal(false);
      setStatusMsg({ text: 'Fan muvaffaqiyatli saqlandi!', isError: false });
    } catch (err: any) {
      setStatusMsg({ text: err.message || 'Xatolik yuz berdi', isError: true });
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDeleteCourse = async (courseId: string) => {
    if (!confirm('Ushbu fanni butunlay o‘chirmoqchimisiz?')) return;
    try {
      await adminContentService.deleteCourse(courseId);
      await loadAllCmsData();
      setStatusMsg({ text: 'Fan o‘chirildi', isError: false });
    } catch (err: any) {
      setStatusMsg({ text: err.message, isError: true });
    }
  };

  // Handlers for Skills CMS
  const handleSaveSkill = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!skillForm.name?.trim()) return;
    setIsSubmitting(true);
    try {
      await adminContentService.saveSkill(skillForm);
      await loadAllCmsData();
      setShowSkillModal(false);
      setStatusMsg({ text: 'Ko‘nikma muvaffaqiyatli saqlandi!', isError: false });
    } catch (err: any) {
      setStatusMsg({ text: err.message, isError: true });
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDeleteSkill = async (skillId: string) => {
    if (!confirm('Ko‘nikmani o‘chirmoqchimisiz?')) return;
    try {
      await adminContentService.deleteSkill(skillId);
      await loadAllCmsData();
      setStatusMsg({ text: 'Ko‘nikma o‘chirildi', isError: false });
    } catch (err: any) {
      setStatusMsg({ text: err.message, isError: true });
    }
  };

  // Handlers for Lessons CMS
  const handleSaveLesson = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!lessonForm.title?.trim()) return;
    setIsSubmitting(true);
    try {
      await adminContentService.saveLesson(lessonForm);
      await loadAllCmsData();
      setShowLessonModal(false);
      setStatusMsg({ text: 'Darslik muvaffaqiyatli saqlandi!', isError: false });
    } catch (err: any) {
      setStatusMsg({ text: err.message, isError: true });
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleTogglePublish = async (lessonId: string, current: boolean) => {
    try {
      await adminContentService.toggleLessonPublish(lessonId, !current);
      await loadAllCmsData();
    } catch (err: any) {
      setStatusMsg({ text: err.message, isError: true });
    }
  };

  const handleToggleArchive = async (lessonId: string, current: boolean) => {
    try {
      await adminContentService.toggleLessonArchive(lessonId, !current);
      await loadAllCmsData();
    } catch (err: any) {
      setStatusMsg({ text: err.message, isError: true });
    }
  };

  const handleDeleteLesson = async (lessonId: string) => {
    if (!confirm('Darsni o‘chirmoqchimisiz?')) return;
    try {
      await adminContentService.deleteLesson(lessonId);
      await loadAllCmsData();
      setStatusMsg({ text: 'Dars o‘chirildi', isError: false });
    } catch (err: any) {
      setStatusMsg({ text: err.message, isError: true });
    }
  };

  // Handlers for Questions CMS
  const handleSaveQuestion = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!questionForm.text?.trim()) return;
    const options = [
      questionForm.option0.trim() || 'Variant 1',
      questionForm.option1.trim() || 'Variant 2',
      questionForm.option2.trim() || 'Variant 3',
      questionForm.option3.trim() || 'Variant 4',
    ];
    setIsSubmitting(true);
    try {
      await adminContentService.saveQuestion({
        id: questionForm.id || undefined,
        courseId: questionForm.courseId,
        skillId: questionForm.skillId,
        text: questionForm.text,
        options,
        correctIndex: questionForm.correctIndex,
        difficulty: questionForm.difficulty,
        explanation: questionForm.explanation,
        formulaLatex: questionForm.formulaLatex || undefined,
        isPlacement: questionForm.isPlacement,
      });
      await loadAllCmsData();
      setShowQuestionModal(false);
      setStatusMsg({ text: 'Savol muvaffaqiyatli saqlandi!', isError: false });
    } catch (err: any) {
      setStatusMsg({ text: err.message, isError: true });
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDeleteQuestion = async (questionId: string) => {
    if (!confirm('Savolni o‘chirmoqchimisiz?')) return;
    try {
      await adminContentService.deleteQuestion(questionId);
      await loadAllCmsData();
      setStatusMsg({ text: 'Savol o‘chirildi', isError: false });
    } catch (err: any) {
      setStatusMsg({ text: err.message, isError: true });
    }
  };

  const filteredSkills = selectedCourseFilter
    ? skills.filter((s) => s.courseId === selectedCourseFilter)
    : skills;
  const filteredLessons = selectedCourseFilter
    ? lessons.filter((l) => l.courseId === selectedCourseFilter)
    : lessons;
  const filteredQuestions = questions.filter((q) => {
    if (selectedCourseFilter && q.courseId !== selectedCourseFilter) return false;
    if (selectedSkillFilter && q.skillId !== selectedSkillFilter) return false;
    return true;
  });

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
            Administrator Konsoli & CMS
          </h1>
          <p className="text-muted-foreground text-sm mt-1">
            O‘quv dasturlari, fanlar, darsliklar va test savollari boshqaruvi
          </p>
        </div>

        <Button
          variant="outline"
          size="sm"
          onClick={() => {
            loadAllCmsData();
          }}
          isLoading={isCmsLoading}
          className="flex items-center gap-2"
        >
          <RefreshCw className="w-3.5 h-3.5" />
          <span>Barchasini yangilash</span>
        </Button>
      </div>

      {/* Global Overview Metrics */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
        <Card className="p-4 border-indigo-100 dark:border-indigo-900/40">
          <div className="text-xs text-muted-foreground font-semibold flex items-center gap-1">
            <BookOpen className="w-3.5 h-3.5 text-indigo-500" /> Fanlar
          </div>
          <div className="text-2xl font-black text-foreground mt-1">{courses.length}</div>
        </Card>
        <Card className="p-4 border-cyan-100 dark:border-cyan-900/40">
          <div className="text-xs text-muted-foreground font-semibold flex items-center gap-1">
            <Target className="w-3.5 h-3.5 text-cyan-500" /> Ko‘nikmalar
          </div>
          <div className="text-2xl font-black text-foreground mt-1">{skills.length}</div>
        </Card>
        <Card className="p-4 border-emerald-100 dark:border-emerald-900/40">
          <div className="text-xs text-muted-foreground font-semibold flex items-center gap-1">
            <FileText className="w-3.5 h-3.5 text-emerald-500" /> Darslar
          </div>
          <div className="text-2xl font-black text-foreground mt-1">{lessons.length}</div>
        </Card>
        <Card className="p-4 border-amber-100 dark:border-amber-900/40">
          <div className="text-xs text-muted-foreground font-semibold flex items-center gap-1">
            <HelpCircle className="w-3.5 h-3.5 text-amber-500" /> Test Savollari
          </div>
          <div className="text-2xl font-black text-foreground mt-1">{questions.length}</div>
        </Card>
      </div>

      {/* Status Alert Notification */}
      {statusMsg && (
        <div
          className={`p-3.5 rounded-xl text-xs font-semibold flex items-center justify-between gap-2 shadow-sm ${
            statusMsg.isError
              ? 'bg-rose-50 text-rose-700 border border-rose-200'
              : 'bg-emerald-50 text-emerald-700 border border-emerald-200'
          }`}
        >
          <div className="flex items-center gap-2">
            {statusMsg.isError ? <AlertCircle className="w-4 h-4 shrink-0" /> : <CheckCircle className="w-4 h-4 shrink-0" />}
            <span>{statusMsg.text}</span>
          </div>
          <button onClick={() => setStatusMsg(null)} className="text-xs underline hover:no-underline cursor-pointer">
            Yopish
          </button>
        </div>
      )}

      {/* Tab Navigation Navigation Bar */}
      <div className="flex flex-wrap items-center gap-2 border-b border-border pb-3">
        <button
          onClick={() => startTransition(() => setActiveTab('courses'))}
          className={`px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-1.5 cursor-pointer ${
            activeTab === 'courses'
              ? 'bg-indigo-600 text-white shadow-md shadow-indigo-600/20'
              : 'bg-secondary/60 text-muted-foreground hover:bg-secondary hover:text-foreground'
          }`}
        >
          <BookOpen className="w-3.5 h-3.5" />
          <span>Fanlar CMS ({courses.length})</span>
        </button>

        <button
          onClick={() => startTransition(() => setActiveTab('skills'))}
          className={`px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-1.5 cursor-pointer ${
            activeTab === 'skills'
              ? 'bg-cyan-600 text-white shadow-md shadow-cyan-600/20'
              : 'bg-secondary/60 text-muted-foreground hover:bg-secondary hover:text-foreground'
          }`}
        >
          <Target className="w-3.5 h-3.5" />
          <span>Ko‘nikmalar ({skills.length})</span>
        </button>

        <button
          onClick={() => startTransition(() => setActiveTab('lessons'))}
          className={`px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-1.5 cursor-pointer ${
            activeTab === 'lessons'
              ? 'bg-emerald-600 text-white shadow-md shadow-emerald-600/20'
              : 'bg-secondary/60 text-muted-foreground hover:bg-secondary hover:text-foreground'
          }`}
        >
          <FileText className="w-3.5 h-3.5" />
          <span>Darsliklar ({lessons.length})</span>
        </button>

        <button
          onClick={() => startTransition(() => setActiveTab('questions'))}
          className={`px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-1.5 cursor-pointer ${
            activeTab === 'questions'
              ? 'bg-amber-600 text-white shadow-md shadow-amber-600/20'
              : 'bg-secondary/60 text-muted-foreground hover:bg-secondary hover:text-foreground'
          }`}
        >
          <HelpCircle className="w-3.5 h-3.5" />
          <span>Test Banki ({questions.length})</span>
        </button>
      </div>

      {/* ========================================================================= */}
      {/* TAB 1: COURSES CMS (FANLARNI BOSHQARISH) */}
      {/* ========================================================================= */}
      {activeTab === 'courses' && (
        <div className="space-y-6">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-lg font-extrabold text-foreground">Fanlar Ro‘yxati (O‘quvchilar ko‘radigan fanlar)</h2>
              <p className="text-xs text-muted-foreground">Fanlar statusi, ranglari va tavsiflarini tahrirlang</p>
            </div>
            <Button
              variant="primary"
              size="sm"
              onClick={() => {
                setCourseForm({
                  id: `course_${Date.now()}`,
                  title: '',
                  description: '',
                  subject: 'mathematics',
                  primaryColorHex: '#4F46E5',
                  secondaryColorHex: '#818CF8',
                  totalStudentsEstimate: 1000,
                  isActive: true,
                });
                setShowCourseModal(true);
              }}
              className="gap-1.5"
            >
              <PlusCircle className="w-4 h-4" />
              <span>Yangi Fan Qo‘shish</span>
            </Button>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {courses.map((c) => (
              <Card key={c.id} className="p-5 border-border flex flex-col justify-between hover:shadow-md transition-shadow">
                <div>
                  <div className="flex items-center justify-between mb-3">
                    <span className="w-10 h-10 rounded-xl flex items-center justify-center font-bold text-white shadow-sm" style={{ backgroundColor: c.primaryColorHex }}>
                      <BookOpen className="w-5 h-5" />
                    </span>
                    <Badge variant={c.isActive ? 'emerald' : 'slate'}>
                      {c.isActive ? 'Faol (Ko‘rinadi)' : 'Nofaol (Yashirin)'}
                    </Badge>
                  </div>
                  <h3 className="text-base font-bold text-foreground">{c.title}</h3>
                  <p className="text-xs text-muted-foreground mt-1 line-clamp-2">{c.description || 'Tavsif mavjud emas.'}</p>
                  <div className="mt-4 flex items-center gap-3 text-xs text-muted-foreground font-mono">
                    <span>ID: {c.id}</span>
                    <span>• {c.totalStudentsEstimate} o‘quvchi</span>
                  </div>
                </div>

                <div className="flex items-center justify-end gap-2 pt-4 border-t border-border mt-4">
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => {
                      setCourseForm({ ...c });
                      setShowCourseModal(true);
                    }}
                    className="gap-1 text-xs"
                  >
                    <Edit3 className="w-3.5 h-3.5" />
                    Tahrirlash
                  </Button>
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => handleDeleteCourse(c.id)}
                    className="text-rose-600 hover:bg-rose-50 dark:hover:bg-rose-950/30 gap-1 text-xs"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </Button>
                </div>
              </Card>
            ))}
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* TAB 3: SKILLS CMS (KO‘NIKMALAR VA MAVZULAR) */}
      {/* ========================================================================= */}
      {activeTab === 'skills' && (
        <div className="space-y-6">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
            <div className="flex items-center gap-3">
              <label className="text-xs font-bold text-foreground">Fanni tanlang:</label>
              <select
                value={selectedCourseFilter}
                onChange={(e) => setSelectedCourseFilter(e.target.value)}
                className="px-3 py-1.5 bg-secondary/60 border border-border rounded-xl text-xs text-foreground font-medium outline-none"
              >
                {courses.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.title}
                  </option>
                ))}
              </select>
            </div>

            <Button
              variant="primary"
              size="sm"
              onClick={() => {
                setSkillForm({
                  id: `skill_${Date.now()}`,
                  courseId: selectedCourseFilter || 'course_math_01',
                  name: '',
                  code: 'SKILL_',
                  description: '',
                  orderIndex: filteredSkills.length + 1,
                });
                setShowSkillModal(true);
              }}
              className="gap-1.5"
            >
              <PlusCircle className="w-4 h-4" />
              <span>Yangi Ko‘nikma Qo‘shish</span>
            </Button>
          </div>

          <Card className="p-6 border-slate-200 dark:border-slate-800">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead>
                  <tr className="border-b border-border text-muted-foreground uppercase font-bold tracking-wider">
                    <th className="pb-3 pl-2">Tartib</th>
                    <th className="pb-3">Ko‘nikma Nomi</th>
                    <th className="pb-3">Kodi</th>
                    <th className="pb-3">Tavsifi</th>
                    <th className="pb-3 pr-2 text-right">Amal</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border/40">
                  {filteredSkills.map((s) => (
                    <tr key={s.id} className="hover:bg-secondary/20 transition-colors">
                      <td className="py-3 pl-2 font-bold text-foreground font-mono">#{s.orderIndex}</td>
                      <td className="py-3 font-bold text-foreground">{s.name}</td>
                      <td className="py-3">
                        <span className="px-2 py-0.5 rounded-md bg-secondary font-mono text-[11px] font-semibold">
                          {s.code}
                        </span>
                      </td>
                      <td className="py-3 text-muted-foreground max-w-xs truncate">{s.description || '—'}</td>
                      <td className="py-3 pr-2 text-right">
                        <div className="flex items-center justify-end gap-1.5">
                          <button
                            onClick={() => {
                              setSkillForm({ ...s });
                              setShowSkillModal(true);
                            }}
                            className="p-1.5 rounded-lg hover:bg-secondary text-indigo-600 transition-colors cursor-pointer"
                          >
                            <Edit3 className="w-3.5 h-3.5" />
                          </button>
                          <button
                            onClick={() => handleDeleteSkill(s.id)}
                            className="p-1.5 rounded-lg hover:bg-rose-50 text-rose-600 transition-colors cursor-pointer"
                          >
                            <Trash2 className="w-3.5 h-3.5" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {filteredSkills.length === 0 && (
                <div className="p-8 text-center text-xs text-muted-foreground">Ushbu fan uchun ko‘nikmalar kiritilmagan.</div>
              )}
            </div>
          </Card>
        </div>
      )}

      {/* ========================================================================= */}
      {/* TAB 4: LESSONS CMS (DARSLIKLARNI BOSHQARISH) */}
      {/* ========================================================================= */}
      {activeTab === 'lessons' && (
        <div className="space-y-6">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
            <div className="flex items-center gap-3">
              <label className="text-xs font-bold text-foreground">Fan bo‘yicha filtr:</label>
              <select
                value={selectedCourseFilter}
                onChange={(e) => setSelectedCourseFilter(e.target.value)}
                className="px-3 py-1.5 bg-secondary/60 border border-border rounded-xl text-xs text-foreground font-medium outline-none"
              >
                {courses.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.title}
                  </option>
                ))}
              </select>
            </div>

            <Button
              variant="primary"
              size="sm"
              onClick={() => {
                setLessonForm({
                  id: `lesson_${Date.now()}`,
                  courseId: selectedCourseFilter || 'course_math_01',
                  skillId: filteredSkills[0]?.id || 'skill_math_functions',
                  title: '',
                  summary: '',
                  estimatedMinutes: 15,
                  isPublished: true,
                  isArchived: false,
                });
                setShowLessonModal(true);
              }}
              className="gap-1.5"
            >
              <PlusCircle className="w-4 h-4" />
              <span>Yangi Dars Qo‘shish</span>
            </Button>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {filteredLessons.map((l) => (
              <Card key={l.id} className="p-5 border-border flex flex-col justify-between hover:shadow-md transition-shadow">
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-xs font-mono text-muted-foreground">Vaqti: ~{l.estimatedMinutes} daqiqa</span>
                    <div className="flex items-center gap-1.5">
                      <Badge variant={l.isPublished ? 'emerald' : 'slate'}>
                        {l.isPublished ? 'Nashr qilingan' : 'Qoralama'}
                      </Badge>
                      {l.isArchived && <Badge variant="rose">Arxivlangan</Badge>}
                    </div>
                  </div>
                  <h3 className="text-base font-bold text-foreground">{l.title}</h3>
                  <p className="text-xs text-muted-foreground mt-1 line-clamp-2">{l.summary || 'Qisqa izoh yo‘q'}</p>
                  <div className="mt-3 text-xs text-indigo-600 font-semibold">
                    Bosqichlar soni: {l.steps?.length || 0} ta qadam
                  </div>
                </div>

                <div className="flex items-center justify-between pt-4 border-t border-border mt-4">
                  <div className="flex items-center gap-1.5">
                    <button
                      onClick={() => handleTogglePublish(l.id, l.isPublished)}
                      className={`px-2.5 py-1 rounded-lg text-xs font-bold border transition-colors flex items-center gap-1 cursor-pointer ${
                        l.isPublished
                          ? 'bg-amber-50 text-amber-700 border-amber-200 hover:bg-amber-100'
                          : 'bg-emerald-50 text-emerald-700 border-emerald-200 hover:bg-emerald-100'
                      }`}
                    >
                      {l.isPublished ? <EyeOff className="w-3.5 h-3.5" /> : <Eye className="w-3.5 h-3.5" />}
                      <span>{l.isPublished ? 'Qoralamaga o‘tkazish' : 'Nashr qilish'}</span>
                    </button>
                    <button
                      onClick={() => handleToggleArchive(l.id, l.isArchived)}
                      className="p-1.5 rounded-lg border border-border hover:bg-secondary text-muted-foreground transition-colors cursor-pointer"
                      title={l.isArchived ? 'Arxivdan chiqarish' : 'Arxivga joylash'}
                    >
                      <Archive className="w-3.5 h-3.5" />
                    </button>
                  </div>

                  <div className="flex items-center gap-1.5">
                    <button
                      onClick={() => {
                        setLessonForm({ ...l });
                        setShowLessonModal(true);
                      }}
                      className="p-1.5 rounded-lg hover:bg-secondary text-indigo-600 transition-colors cursor-pointer"
                    >
                      <Edit3 className="w-3.5 h-3.5" />
                    </button>
                    <button
                      onClick={() => handleDeleteLesson(l.id)}
                      className="p-1.5 rounded-lg hover:bg-rose-50 text-rose-600 transition-colors cursor-pointer"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </div>
              </Card>
            ))}
          </div>

          {filteredLessons.length === 0 && (
            <Card className="p-8 text-center text-xs text-muted-foreground border-border">
              Ushbu fan bo‘yicha hozircha darsliklar mavjud emas.
            </Card>
          )}
        </div>
      )}

      {/* ========================================================================= */}
      {/* TAB 5: QUESTIONS BANK CMS (SAVOLLARNI BOSHQARISH) */}
      {/* ========================================================================= */}
      {activeTab === 'questions' && (
        <div className="space-y-6">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
            <div className="flex flex-wrap items-center gap-3">
              <div>
                <select
                  value={selectedCourseFilter}
                  onChange={(e) => {
                    setSelectedCourseFilter(e.target.value);
                    setSelectedSkillFilter('');
                  }}
                  className="px-3 py-1.5 bg-secondary/60 border border-border rounded-xl text-xs text-foreground font-medium outline-none"
                >
                  {courses.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.title}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <select
                  value={selectedSkillFilter}
                  onChange={(e) => setSelectedSkillFilter(e.target.value)}
                  className="px-3 py-1.5 bg-secondary/60 border border-border rounded-xl text-xs text-foreground font-medium outline-none"
                >
                  <option value="">Barcha ko‘nikmalar</option>
                  {filteredSkills.map((s) => (
                    <option key={s.id} value={s.id}>
                      {s.name}
                    </option>
                  ))}
                </select>
              </div>
            </div>

            <Button
              variant="primary"
              size="sm"
              onClick={() => {
                setQuestionForm({
                  id: `q_${Date.now()}`,
                  courseId: selectedCourseFilter || 'course_math_01',
                  skillId: selectedSkillFilter || filteredSkills[0]?.id || 'skill_math_algebra',
                  text: '',
                  option0: '',
                  option1: '',
                  option2: '',
                  option3: '',
                  correctIndex: 0,
                  difficulty: 'medium',
                  explanation: '',
                  formulaLatex: '',
                  isPlacement: false,
                });
                setShowQuestionModal(true);
              }}
              className="gap-1.5"
            >
              <PlusCircle className="w-4 h-4" />
              <span>Yangi Savol Qo‘shish</span>
            </Button>
          </div>

          <div className="space-y-3">
            {filteredQuestions.map((q, qIdx) => (
              <Card key={q.id} className="p-4 border-border space-y-3 hover:border-indigo-200 transition-colors">
                <div className="flex items-start justify-between gap-4">
                  <div>
                    <div className="flex items-center gap-2 mb-1">
                      <span className="font-mono text-xs font-bold text-muted-foreground">#{qIdx + 1}</span>
                      <Badge
                        variant={q.difficulty === 'easy' ? 'emerald' : q.difficulty === 'hard' ? 'rose' : 'amber'}
                      >
                        {q.difficulty}
                      </Badge>
                      {q.isPlacement && <Badge variant="indigo">Diagnostik Test</Badge>}
                      <span className="text-[11px] font-mono text-muted-foreground">({q.skillId})</span>
                    </div>
                    <p className="text-sm font-semibold text-foreground">{q.text}</p>
                    {q.formulaLatex && (
                      <div className="text-xs font-mono text-indigo-600 bg-indigo-50/50 px-2 py-0.5 rounded mt-1 inline-block">
                        {q.formulaLatex}
                      </div>
                    )}
                  </div>

                  <div className="flex items-center gap-1">
                    <button
                      onClick={() => {
                        setQuestionForm({
                          id: q.id,
                          courseId: q.courseId,
                          skillId: q.skillId,
                          text: q.text,
                          option0: q.options[0] || '',
                          option1: q.options[1] || '',
                          option2: q.options[2] || '',
                          option3: q.options[3] || '',
                          correctIndex: typeof q.correctIndex === 'number' ? q.correctIndex : 0,
                          difficulty: (q.difficulty as 'easy' | 'medium' | 'hard') || 'medium',
                          explanation: q.explanation || '',
                          formulaLatex: q.formulaLatex || '',
                          isPlacement: q.isPlacement ?? false,
                        });
                        setShowQuestionModal(true);
                      }}
                      className="p-1.5 rounded-lg hover:bg-secondary text-indigo-600 cursor-pointer"
                    >
                      <Edit3 className="w-4 h-4" />
                    </button>
                    <button
                      onClick={() => handleDeleteQuestion(q.id)}
                      className="p-1.5 rounded-lg hover:bg-rose-50 text-rose-600 cursor-pointer"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>

                {/* Question Options */}
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-xs pt-1">
                  {q.options.map((opt, oIdx) => {
                    const isCorrect = q.correctIndex === oIdx;
                    return (
                      <div
                        key={oIdx}
                        className={`p-2 rounded-lg border flex items-center justify-between ${
                          isCorrect
                            ? 'bg-emerald-50 dark:bg-emerald-950/30 border-emerald-300 font-bold text-emerald-800 dark:text-emerald-300'
                            : 'bg-secondary/30 border-border text-foreground'
                        }`}
                      >
                        <span>
                          {String.fromCharCode(65 + oIdx)}) {opt}
                        </span>
                        {isCorrect && (
                          <span className="flex items-center gap-0.5 text-emerald-600 text-[10px] font-black uppercase">
                            <Check className="w-3.5 h-3.5" /> To‘g‘ri
                          </span>
                        )}
                      </div>
                    );
                  })}
                </div>

                {q.explanation && (
                  <p className="text-[11px] text-muted-foreground italic border-t border-border/50 pt-2">
                    💡 <strong>Tushuntirish:</strong> {q.explanation}
                  </p>
                )}
              </Card>
            ))}

            {filteredQuestions.length === 0 && (
              <Card className="p-8 text-center text-xs text-muted-foreground border-border">
                Tanlangan filtr bo‘yicha savollar topilmadi.
              </Card>
            )}
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* MODALS */}
      {/* ========================================================================= */}
      <AnimatePresence>
        {/* Course Modal */}
        {showCourseModal && (
          <div className="fixed inset-0 z-50 bg-black/50 backdrop-blur-xs flex items-center justify-center p-4">
            <motion.div initial={{ scale: 0.95, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} exit={{ scale: 0.95, opacity: 0 }} className="w-full max-w-md bg-white dark:bg-slate-900 rounded-2xl shadow-xl p-6 border border-border">
              <h3 className="text-base font-bold text-foreground mb-4">Fan Ma’lumotlarini Kiritish</h3>
              <form onSubmit={handleSaveCourse} className="space-y-3 text-xs">
                <div>
                  <label className="font-bold text-foreground block mb-1">Fan Nomi *</label>
                  <input
                    type="text"
                    required
                    value={courseForm.title}
                    onChange={(e) => setCourseForm({ ...courseForm, title: e.target.value })}
                    className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none"
                    placeholder="Masalan: Fizika"
                  />
                </div>
                <div>
                  <label className="font-bold text-foreground block mb-1">Tavsifi</label>
                  <textarea
                    rows={2}
                    value={courseForm.description}
                    onChange={(e) => setCourseForm({ ...courseForm, description: e.target.value })}
                    className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none"
                    placeholder="Fanning qisqacha mazmuni..."
                  />
                </div>
                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <label className="font-bold text-foreground block mb-1">Asosiy Rang (HEX)</label>
                    <input
                      type="text"
                      value={courseForm.primaryColorHex}
                      onChange={(e) => setCourseForm({ ...courseForm, primaryColorHex: e.target.value })}
                      className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none font-mono"
                    />
                  </div>
                  <div>
                    <label className="font-bold text-foreground block mb-1">Status</label>
                    <select
                      value={courseForm.isActive ? 'true' : 'false'}
                      onChange={(e) => setCourseForm({ ...courseForm, isActive: e.target.value === 'true' })}
                      className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none"
                    >
                      <option value="true">Faol (Ko‘rinadi)</option>
                      <option value="false">Nofaol</option>
                    </select>
                  </div>
                </div>
                <div className="flex justify-end gap-2 pt-3">
                  <Button variant="ghost" type="button" onClick={() => setShowCourseModal(false)}>Bekor qilish</Button>
                  <Button variant="primary" type="submit" isLoading={isSubmitting}>Saqlash</Button>
                </div>
              </form>
            </motion.div>
          </div>
        )}

        {/* Skill Modal */}
        {showSkillModal && (
          <div className="fixed inset-0 z-50 bg-black/50 backdrop-blur-xs flex items-center justify-center p-4">
            <motion.div initial={{ scale: 0.95, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} exit={{ scale: 0.95, opacity: 0 }} className="w-full max-w-md bg-white dark:bg-slate-900 rounded-2xl shadow-xl p-6 border border-border">
              <h3 className="text-base font-bold text-foreground mb-4">Ko‘nikma / Mavzu Qo‘shish</h3>
              <form onSubmit={handleSaveSkill} className="space-y-3 text-xs">
                <div>
                  <label className="font-bold text-foreground block mb-1">Fan</label>
                  <select
                    value={skillForm.courseId}
                    onChange={(e) => setSkillForm({ ...skillForm, courseId: e.target.value })}
                    className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none"
                  >
                    {courses.map((c) => (
                      <option key={c.id} value={c.id}>{c.title}</option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="font-bold text-foreground block mb-1">Ko‘nikma Nomi *</label>
                  <input
                    type="text"
                    required
                    value={skillForm.name}
                    onChange={(e) => setSkillForm({ ...skillForm, name: e.target.value })}
                    className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none"
                    placeholder="Masalan: Kvadrat tenglamalar"
                  />
                </div>
                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <label className="font-bold text-foreground block mb-1">Kod (Slug)</label>
                    <input
                      type="text"
                      required
                      value={skillForm.code}
                      onChange={(e) => setSkillForm({ ...skillForm, code: e.target.value })}
                      className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none font-mono"
                      placeholder="SKILL_MATH_QUAD"
                    />
                  </div>
                  <div>
                    <label className="font-bold text-foreground block mb-1">Tartib Raqami</label>
                    <input
                      type="number"
                      value={skillForm.orderIndex}
                      onChange={(e) => setSkillForm({ ...skillForm, orderIndex: Number(e.target.value) })}
                      className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none"
                    />
                  </div>
                </div>
                <div>
                  <label className="font-bold text-foreground block mb-1">Tavsifi</label>
                  <textarea
                    rows={2}
                    value={skillForm.description}
                    onChange={(e) => setSkillForm({ ...skillForm, description: e.target.value })}
                    className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none"
                    placeholder="Ushbu ko‘nikma orqali o‘rganiladigan tushunchalar..."
                  />
                </div>
                <div className="flex justify-end gap-2 pt-3">
                  <Button variant="ghost" type="button" onClick={() => setShowSkillModal(false)}>Bekor qilish</Button>
                  <Button variant="primary" type="submit" isLoading={isSubmitting}>Saqlash</Button>
                </div>
              </form>
            </motion.div>
          </div>
        )}

        {/* Lesson Modal */}
        {showLessonModal && (
          <div className="fixed inset-0 z-50 bg-black/50 backdrop-blur-xs flex items-center justify-center p-4">
            <motion.div initial={{ scale: 0.95, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} exit={{ scale: 0.95, opacity: 0 }} className="w-full max-w-lg bg-white dark:bg-slate-900 rounded-2xl shadow-xl p-6 border border-border max-h-[90vh] overflow-y-auto">
              <h3 className="text-base font-bold text-foreground mb-4">Darslik Qo‘shish / Tahrirlash</h3>
              <form onSubmit={handleSaveLesson} className="space-y-3 text-xs">
                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <label className="font-bold text-foreground block mb-1">Fan</label>
                    <select
                      value={lessonForm.courseId}
                      onChange={(e) => setLessonForm({ ...lessonForm, courseId: e.target.value })}
                      className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none"
                    >
                      {courses.map((c) => (
                        <option key={c.id} value={c.id}>{c.title}</option>
                      ))}
                    </select>
                  </div>
                  <div>
                    <label className="font-bold text-foreground block mb-1">Ko‘nikma</label>
                    <select
                      value={lessonForm.skillId}
                      onChange={(e) => setLessonForm({ ...lessonForm, skillId: e.target.value })}
                      className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none"
                    >
                      {skills.map((s) => (
                        <option key={s.id} value={s.id}>{s.name}</option>
                      ))}
                    </select>
                  </div>
                </div>
                <div>
                  <label className="font-bold text-foreground block mb-1">Dars Sarlavhasi *</label>
                  <input
                    type="text"
                    required
                    value={lessonForm.title}
                    onChange={(e) => setLessonForm({ ...lessonForm, title: e.target.value })}
                    className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none font-bold"
                    placeholder="Masalan: Chiziqli tenglamalar asoslari"
                  />
                </div>
                <div>
                  <label className="font-bold text-foreground block mb-1">Qisqacha Mazmuni (Summary)</label>
                  <textarea
                    rows={2}
                    value={lessonForm.summary}
                    onChange={(e) => setLessonForm({ ...lessonForm, summary: e.target.value })}
                    className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none"
                    placeholder="Dars nima haqida ekanligi..."
                  />
                </div>
                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <label className="font-bold text-foreground block mb-1">Taxminiy Vaqt (Daqiqa)</label>
                    <input
                      type="number"
                      value={lessonForm.estimatedMinutes}
                      onChange={(e) => setLessonForm({ ...lessonForm, estimatedMinutes: Number(e.target.value) })}
                      className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none"
                    />
                  </div>
                  <div>
                    <label className="font-bold text-foreground block mb-1">Nashr Holati</label>
                    <select
                      value={lessonForm.isPublished ? 'true' : 'false'}
                      onChange={(e) => setLessonForm({ ...lessonForm, isPublished: e.target.value === 'true' })}
                      className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none"
                    >
                      <option value="true">Nashr qilingan (O‘quvchilar ko‘radi)</option>
                      <option value="false">Qoralama (Yashirin)</option>
                    </select>
                  </div>
                </div>
                <div className="flex justify-end gap-2 pt-3">
                  <Button variant="ghost" type="button" onClick={() => setShowLessonModal(false)}>Bekor qilish</Button>
                  <Button variant="primary" type="submit" isLoading={isSubmitting}>Darsni Saqlash</Button>
                </div>
              </form>
            </motion.div>
          </div>
        )}

        {/* Question Modal */}
        {showQuestionModal && (
          <div className="fixed inset-0 z-50 bg-black/50 backdrop-blur-xs flex items-center justify-center p-4">
            <motion.div initial={{ scale: 0.95, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} exit={{ scale: 0.95, opacity: 0 }} className="w-full max-w-xl bg-white dark:bg-slate-900 rounded-2xl shadow-xl p-6 border border-border max-h-[90vh] overflow-y-auto">
              <h3 className="text-base font-bold text-foreground mb-4">Savol Qo‘shish / Tahrirlash</h3>
              <form onSubmit={handleSaveQuestion} className="space-y-3 text-xs">
                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <label className="font-bold text-foreground block mb-1">Fan</label>
                    <select
                      value={questionForm.courseId}
                      onChange={(e) => setQuestionForm({ ...questionForm, courseId: e.target.value })}
                      className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none"
                    >
                      {courses.map((c) => (
                        <option key={c.id} value={c.id}>{c.title}</option>
                      ))}
                    </select>
                  </div>
                  <div>
                    <label className="font-bold text-foreground block mb-1">Ko‘nikma</label>
                    <select
                      value={questionForm.skillId}
                      onChange={(e) => setQuestionForm({ ...questionForm, skillId: e.target.value })}
                      className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none"
                    >
                      {skills.map((s) => (
                        <option key={s.id} value={s.id}>{s.name}</option>
                      ))}
                    </select>
                  </div>
                </div>

                <div>
                  <label className="font-bold text-foreground block mb-1">Savol Matni *</label>
                  <textarea
                    rows={2}
                    required
                    value={questionForm.text}
                    onChange={(e) => setQuestionForm({ ...questionForm, text: e.target.value })}
                    className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none font-medium"
                    placeholder="Tenglamani yeching: 2x + 6 = 14..."
                  />
                </div>

                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <label className="font-bold text-foreground block mb-1">Matematik Formula (ixtiyoriy)</label>
                    <input
                      type="text"
                      value={questionForm.formulaLatex}
                      onChange={(e) => setQuestionForm({ ...questionForm, formulaLatex: e.target.value })}
                      className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none font-mono"
                      placeholder="2x + 6 = 14"
                    />
                  </div>
                  <div>
                    <label className="font-bold text-foreground block mb-1">Qiyinchilik</label>
                    <select
                      value={questionForm.difficulty}
                      onChange={(e) => setQuestionForm({ ...questionForm, difficulty: e.target.value as any })}
                      className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none"
                    >
                      <option value="easy">Oson (Easy)</option>
                      <option value="medium">O‘rta (Medium)</option>
                      <option value="hard">Qiyin (Hard)</option>
                    </select>
                  </div>
                </div>

                {/* 4 Options and Correct Answer Selector */}
                <div className="space-y-2 pt-2 border-t border-border">
                  <label className="font-bold text-foreground block">
                    Variantlar (To‘g‘ri javobni radio orqali belgilang) *
                  </label>

                  {[0, 1, 2, 3].map((idx) => {
                    const key = `option${idx}` as 'option0' | 'option1' | 'option2' | 'option3';
                    const isSelected = questionForm.correctIndex === idx;
                    return (
                      <div key={idx} className="flex items-center gap-2">
                        <input
                          type="radio"
                          name="correctOptionRadio"
                          checked={isSelected}
                          onChange={() => setQuestionForm({ ...questionForm, correctIndex: idx })}
                          className="w-4 h-4 text-emerald-600 focus:ring-emerald-500 cursor-pointer"
                        />
                        <span className="font-bold text-foreground w-4">{String.fromCharCode(65 + idx)})</span>
                        <input
                          type="text"
                          required
                          value={questionForm[key]}
                          onChange={(e) => setQuestionForm({ ...questionForm, [key]: e.target.value })}
                          className={`flex-1 px-3 py-1.5 border rounded-xl bg-secondary/50 outline-none text-xs ${
                            isSelected ? 'border-emerald-500 bg-emerald-50/20 font-bold' : 'border-border'
                          }`}
                          placeholder={`Variant ${idx + 1}`}
                        />
                      </div>
                    );
                  })}
                </div>

                <div>
                  <label className="font-bold text-foreground block mb-1">To‘liq Pedagogik Tushuntirish</label>
                  <textarea
                    rows={2}
                    value={questionForm.explanation}
                    onChange={(e) => setQuestionForm({ ...questionForm, explanation: e.target.value })}
                    className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none"
                    placeholder="Qadamma-qadam yechim: 2x = 8 => x = 4..."
                  />
                </div>

                <div className="flex items-center gap-2 pt-1">
                  <input
                    type="checkbox"
                    id="isPlacementCheck"
                    checked={questionForm.isPlacement}
                    onChange={(e) => setQuestionForm({ ...questionForm, isPlacement: e.target.checked })}
                    className="rounded text-indigo-600 cursor-pointer"
                  />
                  <label htmlFor="isPlacementCheck" className="text-xs font-semibold text-foreground cursor-pointer">
                    Boshlang‘ich diagnostika testi uchun ishlatilsin
                  </label>
                </div>

                <div className="flex justify-end gap-2 pt-3">
                  <Button variant="ghost" type="button" onClick={() => setShowQuestionModal(false)}>Bekor qilish</Button>
                  <Button variant="primary" type="submit" isLoading={isSubmitting}>Savolni Saqlash</Button>
                </div>
              </form>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </div>
  );
};
