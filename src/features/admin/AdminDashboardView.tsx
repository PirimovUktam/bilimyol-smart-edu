import { translate, useTranslation } from '@/core/locales/useTranslation';
import React, { useCallback, useEffect, useState, useTransition } from 'react';
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
import { Modal } from '../../presentation/components/Modal';
import type { SubjectType } from '@/core/types/common';
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
  const { t } = useTranslation();
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
    primaryColorHex: '#3550d6',
    secondaryColorHex: '#0d9ad6',
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

  const loadAllCmsData = useCallback(async () => {
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
    } catch {
      setStatusMsg({ text: translate('admin.loadFailed'), isError: true });
    } finally {
      setIsCmsLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadAllCmsData();
  }, [loadAllCmsData]);

  // Handlers for Course CMS
  const handleSaveCourse = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!courseForm.title?.trim()) return;
    setIsSubmitting(true);
    try {
      await adminContentService.saveCourse(courseForm);
      await loadAllCmsData();
      setShowCourseModal(false);
      setStatusMsg({ text: t('admin.courseSaved'), isError: false });
    } catch (err: any) {
      setStatusMsg({ text: err.message || t('admin.error'), isError: true });
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDeleteCourse = async (courseId: string) => {
    if (!confirm(t('admin.confirmCourseDelete'))) return;
    try {
      await adminContentService.deleteCourse(courseId);
      await loadAllCmsData();
      setStatusMsg({ text: t('admin.courseDeleted'), isError: false });
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
      setStatusMsg({ text: t('admin.skillSaved'), isError: false });
    } catch (err: any) {
      setStatusMsg({ text: err.message, isError: true });
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDeleteSkill = async (skillId: string) => {
    if (!confirm(t('admin.confirmSkillDelete'))) return;
    try {
      await adminContentService.deleteSkill(skillId);
      await loadAllCmsData();
      setStatusMsg({ text: t('admin.skillDeleted'), isError: false });
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
      setStatusMsg({ text: t('admin.lessonSaved'), isError: false });
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
    if (!confirm(t('admin.confirmLessonDelete'))) return;
    try {
      await adminContentService.deleteLesson(lessonId);
      await loadAllCmsData();
      setStatusMsg({ text: t('admin.lessonDeleted'), isError: false });
    } catch (err: any) {
      setStatusMsg({ text: err.message, isError: true });
    }
  };

  // Handlers for Questions CMS
  const handleSaveQuestion = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!questionForm.text?.trim()) return;
    const options = [
      questionForm.option0.trim() || t('admin.option1'),
      questionForm.option1.trim() || t('admin.option2'),
      questionForm.option2.trim() || t('admin.option3'),
      questionForm.option3.trim() || t('admin.option4'),
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
      setStatusMsg({ text: t('admin.questionSaved'), isError: false });
    } catch (err: any) {
      setStatusMsg({ text: err.message, isError: true });
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDeleteQuestion = async (questionId: string) => {
    if (!confirm(t('admin.confirmQuestionDelete'))) return;
    try {
      await adminContentService.deleteQuestion(questionId);
      await loadAllCmsData();
      setStatusMsg({ text: t('admin.questionDeleted'), isError: false });
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

  const formError = statusMsg?.isError && <p role="alert" className="text-sm text-coral">{statusMsg.text}</p>;

  return (
    <div className="max-w-6xl mx-auto px-4 py-8 space-y-8">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <span className="px-2.5 py-0.5 rounded-full text-xs font-bold bg-brand/10 text-brand-dark dark:text-path border border-brand/20 flex items-center gap-1.5">
              <ShieldAlert className="w-3.5 h-3.5" />{t('admin.title')}</span>
            <span className="text-xs text-muted-foreground">{t('admin.onlyAdmins')}</span>
          </div>
          <h1 className="text-3xl font-extrabold text-foreground tracking-tight">{t('admin.console')}</h1>
          <p className="text-muted-foreground text-sm mt-1">{t('admin.description')}</p>
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
          <span>{t('admin.refreshAll')}</span>
        </Button>
      </div>

      {/* Global Overview Metrics */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
        <Card className="p-4 border-brand/10 dark:border-brand-dark/40">
          <div className="text-xs text-muted-foreground font-semibold flex items-center gap-1">
            <BookOpen className="w-3.5 h-3.5 text-brand" />{t('dashboard.subjects')}</div>
          <div className="text-2xl font-black text-foreground mt-1">{courses.length}</div>
        </Card>
        <Card className="p-4 border-path/15 dark:border-path/40">
          <div className="text-xs text-muted-foreground font-semibold flex items-center gap-1">
            <Target className="w-3.5 h-3.5 text-path" />{t('path.skills')}</div>
          <div className="text-2xl font-black text-foreground mt-1">{skills.length}</div>
        </Card>
        <Card className="p-4 border-mint/10 dark:border-mint/40">
          <div className="text-xs text-muted-foreground font-semibold flex items-center gap-1">
            <FileText className="w-3.5 h-3.5 text-mint" />{t('admin.lessons')}</div>
          <div className="text-2xl font-black text-foreground mt-1">{lessons.length}</div>
        </Card>
        <Card className="p-4 border-amber-100 dark:border-amber-900/40">
          <div className="text-xs text-muted-foreground font-semibold flex items-center gap-1">
            <HelpCircle className="w-3.5 h-3.5 text-amber-500" />{t('admin.questions')}</div>
          <div className="text-2xl font-black text-foreground mt-1">{questions.length}</div>
        </Card>
      </div>

      {/* Status Alert Notification */}
      {statusMsg && (
        <div
          className={`p-3.5 rounded-xl text-xs font-semibold flex items-center justify-between gap-2 shadow-sm ${
            statusMsg.isError
              ? 'bg-coral/5 text-coral border border-coral/25'
              : 'bg-mint/10 text-mint border border-mint/25'
          }`}
        >
          <div className="flex items-center gap-2">
            {statusMsg.isError ? <AlertCircle className="w-4 h-4 shrink-0" /> : <CheckCircle className="w-4 h-4 shrink-0" />}
            <span>{statusMsg.text}</span>
          </div>
          <button onClick={() => setStatusMsg(null)} className="text-xs underline hover:no-underline cursor-pointer">{t('courses.close')}</button>
        </div>
      )}

      {/* Tab Navigation Navigation Bar */}
      <div className="flex flex-wrap items-center gap-2 border-b border-border pb-3">
        <button
          aria-pressed={activeTab === 'courses'}
          onClick={() => startTransition(() => setActiveTab('courses'))}
          className={`px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-1.5 cursor-pointer ${
            activeTab === 'courses'
              ? 'bg-brand text-white shadow-md shadow-brand/20'
              : 'bg-secondary/60 text-muted-foreground hover:bg-secondary hover:text-foreground'
          }`}
        >
          <BookOpen className="w-3.5 h-3.5" />
          <span>{t('admin.coursesCount')}{courses.length})</span>
        </button>

        <button
          aria-pressed={activeTab === 'skills'}
          onClick={() => startTransition(() => setActiveTab('skills'))}
          className={`px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-1.5 cursor-pointer ${
            activeTab === 'skills'
              ? 'bg-path text-white shadow-md shadow-path/20'
              : 'bg-secondary/60 text-muted-foreground hover:bg-secondary hover:text-foreground'
          }`}
        >
          <Target className="w-3.5 h-3.5" />
          <span>{t('admin.skillsCount')}{skills.length})</span>
        </button>

        <button
          aria-pressed={activeTab === 'lessons'}
          onClick={() => startTransition(() => setActiveTab('lessons'))}
          className={`px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-1.5 cursor-pointer ${
            activeTab === 'lessons'
              ? 'bg-mint text-white shadow-md shadow-mint/20'
              : 'bg-secondary/60 text-muted-foreground hover:bg-secondary hover:text-foreground'
          }`}
        >
          <FileText className="w-3.5 h-3.5" />
          <span>{t('admin.lessonsCount')}{lessons.length})</span>
        </button>

        <button
          aria-pressed={activeTab === 'questions'}
          onClick={() => startTransition(() => setActiveTab('questions'))}
          className={`px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-1.5 cursor-pointer ${
            activeTab === 'questions'
              ? 'bg-amber-600 text-white shadow-md shadow-amber-600/20'
              : 'bg-secondary/60 text-muted-foreground hover:bg-secondary hover:text-foreground'
          }`}
        >
          <HelpCircle className="w-3.5 h-3.5" />
          <span>{t('admin.questionBank')}{questions.length})</span>
        </button>
      </div>

      {/* ========================================================================= */}
      {/* TAB 1: COURSES CMS (FANLARNI BOSHQARISH) */}
      {/* ========================================================================= */}
      {activeTab === 'courses' && (
        <div className="space-y-6">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-lg font-extrabold text-foreground">{t('admin.courseList')}</h2>
              <p className="text-xs text-muted-foreground">{t('admin.courseDescription')}</p>
            </div>
            <Button
              variant="primary"
              size="sm"
              onClick={() => {
                setCourseForm({
                  id: `course_${Date.now()}`,
                  title: '',
                  description: '',
                  subject: 'other',
                  primaryColorHex: '#3550d6',
                  secondaryColorHex: '#0d9ad6',
                  totalStudentsEstimate: 1000,
                  isActive: true,
                });
                setStatusMsg(null);
                setShowCourseModal(true);
              }}
              className="gap-1.5"
            >
              <PlusCircle className="w-4 h-4" />
              <span>{t('admin.addCourse')}</span>
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
                      {c.isActive ? t('admin.visible') : t('admin.hidden')}
                    </Badge>
                  </div>
                  <h3 className="text-base font-bold text-foreground">{c.title}</h3>
                  <p className="text-xs text-muted-foreground mt-1 line-clamp-2">{c.description || t('admin.noDescription')}</p>
                  <div className="mt-4 flex items-center gap-3 text-xs text-muted-foreground font-mono">
                    <span>ID: {c.id}</span>
                    <span>• {c.totalStudentsEstimate}{t('admin.student')}</span>
                  </div>
                </div>

                <div className="flex items-center justify-end gap-2 pt-4 border-t border-border mt-4">
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => {
                      setCourseForm({ ...c });
                      setStatusMsg(null);
                      setShowCourseModal(true);
                    }}
                    className="gap-1 text-xs"
                  >
                    <Edit3 className="w-3.5 h-3.5" />{t('admin.edit')}</Button>
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => handleDeleteCourse(c.id)}
                    className="text-coral hover:bg-coral/5 dark:hover:bg-coral/30 gap-1 text-xs"
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
              <label className="text-xs font-bold text-foreground">{t('admin.chooseSubject')}</label>
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
              <span>{t('admin.addSkill')}</span>
            </Button>
          </div>

          <Card className="p-6 border-slate-200 dark:border-slate-800">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead>
                  <tr className="border-b border-border text-muted-foreground uppercase font-bold tracking-wider">
                    <th className="pb-3 pl-2">{t('admin.order')}</th>
                    <th className="pb-3">{t('admin.skillName')}</th>
                    <th className="pb-3">{t('admin.code')}</th>
                    <th className="pb-3">{t('admin.summary')}</th>
                    <th className="pb-3 pr-2 text-right">{t('admin.action')}</th>
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
                            className="p-1.5 rounded-lg hover:bg-secondary text-brand transition-colors cursor-pointer"
                          >
                            <Edit3 className="w-3.5 h-3.5" />
                          </button>
                          <button
                            onClick={() => handleDeleteSkill(s.id)}
                            className="p-1.5 rounded-lg hover:bg-coral/5 text-coral transition-colors cursor-pointer"
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
                <div className="p-8 text-center text-xs text-muted-foreground">{t('admin.noSkills')}</div>
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
              <label className="text-xs font-bold text-foreground">{t('admin.filterSubject')}</label>
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
              <span>{t('admin.addLesson')}</span>
            </Button>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {filteredLessons.map((l) => (
              <Card key={l.id} className="p-5 border-border flex flex-col justify-between hover:shadow-md transition-shadow">
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-xs font-mono text-muted-foreground">{t('admin.duration')}{l.estimatedMinutes}{t('courses.minutes')}</span>
                    <div className="flex items-center gap-1.5">
                      <Badge variant={l.isPublished ? 'emerald' : 'slate'}>
                        {l.isPublished ? t('admin.published') : 'Qoralama'}
                      </Badge>
                      {l.isArchived && <Badge variant="rose">{t('admin.archived')}</Badge>}
                    </div>
                  </div>
                  <h3 className="text-base font-bold text-foreground">{l.title}</h3>
                  <p className="text-xs text-muted-foreground mt-1 line-clamp-2">{l.summary || t('admin.noSummary')}</p>
                  <div className="mt-3 text-xs text-brand font-semibold">{t('admin.stepCount')}{l.steps?.length || 0}{t('admin.steps')}</div>
                </div>

                <div className="flex items-center justify-between pt-4 border-t border-border mt-4">
                  <div className="flex items-center gap-1.5">
                    <button
                      onClick={() => handleTogglePublish(l.id, l.isPublished)}
                      className={`px-2.5 py-1 rounded-lg text-xs font-bold border transition-colors flex items-center gap-1 cursor-pointer ${
                        l.isPublished
                          ? 'bg-amber-50 text-amber-700 border-amber-200 hover:bg-amber-100'
                          : 'bg-mint/10 text-mint border-mint/25 hover:bg-mint/10'
                      }`}
                    >
                      {l.isPublished ? <EyeOff className="w-3.5 h-3.5" /> : <Eye className="w-3.5 h-3.5" />}
                      <span>{l.isPublished ? t('admin.draftAction') : t('admin.publish')}</span>
                    </button>
                    <button
                      onClick={() => handleToggleArchive(l.id, l.isArchived)}
                      className="p-1.5 rounded-lg border border-border hover:bg-secondary text-muted-foreground transition-colors cursor-pointer"
                      title={l.isArchived ? t('admin.unarchive') : t('admin.archive')}
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
                      className="p-1.5 rounded-lg hover:bg-secondary text-brand transition-colors cursor-pointer"
                    >
                      <Edit3 className="w-3.5 h-3.5" />
                    </button>
                    <button
                      onClick={() => handleDeleteLesson(l.id)}
                      className="p-1.5 rounded-lg hover:bg-coral/5 text-coral transition-colors cursor-pointer"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </div>
              </Card>
            ))}
          </div>

          {filteredLessons.length === 0 && (
            <Card className="p-8 text-center text-xs text-muted-foreground border-border">{t('admin.noLessons')}</Card>
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
                  <option value="">{t('admin.allSkills')}</option>
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
              <span>{t('admin.addQuestion')}</span>
            </Button>
          </div>

          <div className="space-y-3">
            {filteredQuestions.map((q, qIdx) => (
              <Card key={q.id} className="p-4 border-border space-y-3 hover:border-brand/25 transition-colors">
                <div className="flex items-start justify-between gap-4">
                  <div>
                    <div className="flex items-center gap-2 mb-1">
                      <span className="font-mono text-xs font-bold text-muted-foreground">#{qIdx + 1}</span>
                      <Badge
                        variant={q.difficulty === 'easy' ? 'emerald' : q.difficulty === 'hard' ? 'rose' : 'amber'}
                      >
                        {q.difficulty}
                      </Badge>
                      {q.isPlacement && <Badge variant="indigo">{t('admin.diagnostic')}</Badge>}
                      <span className="text-[11px] font-mono text-muted-foreground">({q.skillId})</span>
                    </div>
                    <p className="text-sm font-semibold text-foreground">{q.text}</p>
                    {q.formulaLatex && (
                      <div className="text-xs font-mono text-brand bg-brand/50 px-2 py-0.5 rounded mt-1 inline-block">
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
                      className="p-1.5 rounded-lg hover:bg-secondary text-brand cursor-pointer"
                    >
                      <Edit3 className="w-4 h-4" />
                    </button>
                    <button
                      onClick={() => handleDeleteQuestion(q.id)}
                      className="p-1.5 rounded-lg hover:bg-coral/5 text-coral cursor-pointer"
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
                            ? 'bg-mint/10 dark:bg-mint/30 border-mint/30 font-bold text-mint dark:text-mint'
                            : 'bg-secondary/30 border-border text-foreground'
                        }`}
                      >
                        <span>
                          {String.fromCharCode(65 + oIdx)}) {opt}
                        </span>
                        {isCorrect && (
                          <span className="flex items-center gap-0.5 text-mint text-[10px] font-black uppercase">
                            <Check className="w-3.5 h-3.5" />{t('assessment.correct')}</span>
                        )}
                      </div>
                    );
                  })}
                </div>

                {q.explanation && (
                  <p className="text-[11px] text-muted-foreground italic border-t border-border/50 pt-2">
                    💡 <strong>{t('admin.explanation')}</strong> {q.explanation}
                  </p>
                )}
              </Card>
            ))}

            {filteredQuestions.length === 0 && (
              <Card className="p-8 text-center text-xs text-muted-foreground border-border">{t('admin.noQuestions')}</Card>
            )}
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* MODALS */}
      {/* ========================================================================= */}
        {/* Course Modal */}
        {showCourseModal && (
          <Modal isOpen onClose={() => setShowCourseModal(false)} title={t('admin.courseDetails')} maxWidth="md" dismissable={!isSubmitting}>
              <form onSubmit={handleSaveCourse} className="space-y-3 text-xs">
                {formError}
                <div>
                  <label htmlFor="admin-course-title" className="font-bold text-foreground block mb-1">{t('admin.courseName')}</label>
                  <input
                    id="admin-course-title"
                    type="text"
                    required
                    value={courseForm.title}
                    onChange={(e) => setCourseForm({ ...courseForm, title: e.target.value })}
                    className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none"
                    placeholder={t('admin.physicsExample')}
                  />
                </div>
                <div>
                  <label htmlFor="admin-course-subject" className="font-bold text-foreground block mb-1">{t('admin.subjectType')}</label>
                  <select id="admin-course-subject" className="form-input px-3" value={courseForm.subject ?? 'other'}
                    onChange={(event) => setCourseForm({ ...courseForm, subject: event.target.value as SubjectType })}>
                    <option value="mathematics">{t('admin.mathematics')}</option>
                    <option value="english">{t('dashboard.english')}</option>
                    <option value="it">{t('admin.programming')}</option>
                    <option value="logic">{t('admin.logic')}</option>
                    <option value="other">{t('admin.other')}</option>
                  </select>
                </div>
                <div>
                  <label htmlFor="admin-course-description" className="font-bold text-foreground block mb-1">{t('admin.summary')}</label>
                  <textarea
                    id="admin-course-description"
                    rows={2}
                    value={courseForm.description}
                    onChange={(e) => setCourseForm({ ...courseForm, description: e.target.value })}
                    className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none"
                    placeholder={t('admin.coursePlaceholder')}
                  />
                </div>
                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <label htmlFor="admin-course-color" className="font-bold text-foreground block mb-1">{t('admin.color')}</label>
                    <input
                      id="admin-course-color"
                      type="text"
                      value={courseForm.primaryColorHex}
                      onChange={(e) => setCourseForm({ ...courseForm, primaryColorHex: e.target.value })}
                      className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none font-mono"
                    />
                  </div>
                  <div>
                    <label htmlFor="admin-course-status" className="font-bold text-foreground block mb-1">{t('admin.status')}</label>
                    <select
                      id="admin-course-status"
                      value={courseForm.isActive ? 'true' : 'false'}
                      onChange={(e) => setCourseForm({ ...courseForm, isActive: e.target.value === 'true' })}
                      className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none"
                    >
                      <option value="true">{t('admin.visible')}</option>
                      <option value="false">{t('admin.inactive')}</option>
                    </select>
                  </div>
                </div>
                <div className="flex justify-end gap-2 pt-3">
                  <Button variant="ghost" type="button" disabled={isSubmitting} onClick={() => setShowCourseModal(false)}>{t('courses.cancel')}</Button>
                  <Button variant="primary" type="submit" isLoading={isSubmitting}>{t('courses.save')}</Button>
                </div>
              </form>
          </Modal>
        )}

        {/* Skill Modal */}
        {showSkillModal && (
          <Modal isOpen onClose={() => setShowSkillModal(false)} title={t('admin.skillDetails')} maxWidth="md">
              <form onSubmit={handleSaveSkill} className="space-y-3 text-xs">
                {formError}
                <div>
                  <label className="font-bold text-foreground block mb-1">{t('admin.subject')}</label>
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
                  <label className="font-bold text-foreground block mb-1">{t('admin.skillRequired')}</label>
                  <input
                    type="text"
                    required
                    value={skillForm.name}
                    onChange={(e) => setSkillForm({ ...skillForm, name: e.target.value })}
                    className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none"
                    placeholder={t('admin.quadraticExample')}
                  />
                </div>
                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <label className="font-bold text-foreground block mb-1">{t('admin.slug')}</label>
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
                    <label className="font-bold text-foreground block mb-1">{t('admin.orderNumber')}</label>
                    <input
                      type="number"
                      value={skillForm.orderIndex}
                      onChange={(e) => setSkillForm({ ...skillForm, orderIndex: Number(e.target.value) })}
                      className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none"
                    />
                  </div>
                </div>
                <div>
                  <label className="font-bold text-foreground block mb-1">{t('admin.summary')}</label>
                  <textarea
                    rows={2}
                    value={skillForm.description}
                    onChange={(e) => setSkillForm({ ...skillForm, description: e.target.value })}
                    className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none"
                    placeholder={t('admin.skillPlaceholder')}
                  />
                </div>
                <div className="flex justify-end gap-2 pt-3">
                  <Button variant="ghost" type="button" onClick={() => setShowSkillModal(false)}>{t('courses.cancel')}</Button>
                  <Button variant="primary" type="submit" isLoading={isSubmitting}>{t('courses.save')}</Button>
                </div>
              </form>
          </Modal>
        )}

        {/* Lesson Modal */}
        {showLessonModal && (
          <Modal isOpen onClose={() => setShowLessonModal(false)} title={t('admin.lessonDetails')} maxWidth="lg">
              <form onSubmit={handleSaveLesson} className="space-y-3 text-xs">
                {formError}
                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <label className="font-bold text-foreground block mb-1">{t('admin.subject')}</label>
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
                    <label className="font-bold text-foreground block mb-1">{t('assessment.skill')}</label>
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
                  <label className="font-bold text-foreground block mb-1">{t('admin.lessonRequired')}</label>
                  <input
                    type="text"
                    required
                    value={lessonForm.title}
                    onChange={(e) => setLessonForm({ ...lessonForm, title: e.target.value })}
                    className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none font-bold"
                    placeholder={t('admin.linearExample')}
                  />
                </div>
                <div>
                  <label className="font-bold text-foreground block mb-1">{t('admin.shortSummary')}</label>
                  <textarea
                    rows={2}
                    value={lessonForm.summary}
                    onChange={(e) => setLessonForm({ ...lessonForm, summary: e.target.value })}
                    className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none"
                    placeholder={t('admin.lessonPlaceholder')}
                  />
                </div>
                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <label className="font-bold text-foreground block mb-1">{t('admin.estimatedTime')}</label>
                    <input
                      type="number"
                      value={lessonForm.estimatedMinutes}
                      onChange={(e) => setLessonForm({ ...lessonForm, estimatedMinutes: Number(e.target.value) })}
                      className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none"
                    />
                  </div>
                  <div>
                    <label className="font-bold text-foreground block mb-1">{t('admin.publicationStatus')}</label>
                    <select
                      value={lessonForm.isPublished ? 'true' : 'false'}
                      onChange={(e) => setLessonForm({ ...lessonForm, isPublished: e.target.value === 'true' })}
                      className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none"
                    >
                      <option value="true">{t('admin.publishedVisible')}</option>
                      <option value="false">{t('admin.draftHidden')}</option>
                    </select>
                  </div>
                </div>
                <div className="flex justify-end gap-2 pt-3">
                  <Button variant="ghost" type="button" onClick={() => setShowLessonModal(false)}>{t('courses.cancel')}</Button>
                  <Button variant="primary" type="submit" isLoading={isSubmitting}>{t('admin.saveLesson')}</Button>
                </div>
              </form>
          </Modal>
        )}

        {/* Question Modal */}
        {showQuestionModal && (
          <Modal isOpen onClose={() => setShowQuestionModal(false)} title={t('admin.questionDetails')} maxWidth="lg">
              <form onSubmit={handleSaveQuestion} className="space-y-3 text-xs">
                {formError}
                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <label className="font-bold text-foreground block mb-1">{t('admin.subject')}</label>
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
                    <label className="font-bold text-foreground block mb-1">{t('assessment.skill')}</label>
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
                  <label className="font-bold text-foreground block mb-1">{t('admin.questionRequired')}</label>
                  <textarea
                    rows={2}
                    required
                    value={questionForm.text}
                    onChange={(e) => setQuestionForm({ ...questionForm, text: e.target.value })}
                    className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none font-medium"
                    placeholder={t('admin.equationExample')}
                  />
                </div>

                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <label className="font-bold text-foreground block mb-1">{t('admin.formula')}</label>
                    <input
                      type="text"
                      value={questionForm.formulaLatex}
                      onChange={(e) => setQuestionForm({ ...questionForm, formulaLatex: e.target.value })}
                      className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none font-mono"
                      placeholder="2x + 6 = 14"
                    />
                  </div>
                  <div>
                    <label className="font-bold text-foreground block mb-1">{t('admin.difficulty')}</label>
                    <select
                      value={questionForm.difficulty}
                      onChange={(e) => setQuestionForm({ ...questionForm, difficulty: e.target.value as any })}
                      className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none"
                    >
                      <option value="easy">{t('admin.easy')}</option>
                      <option value="medium">{t('admin.medium')}</option>
                      <option value="hard">{t('admin.hard')}</option>
                    </select>
                  </div>
                </div>

                {/* 4 Options and Correct Answer Selector */}
                <div className="space-y-2 pt-2 border-t border-border">
                  <label className="font-bold text-foreground block">{t('admin.options')}</label>

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
                          className="w-4 h-4 text-mint focus:ring-mint cursor-pointer"
                        />
                        <span className="font-bold text-foreground w-4">{String.fromCharCode(65 + idx)})</span>
                        <input
                          type="text"
                          required
                          value={questionForm[key]}
                          onChange={(e) => setQuestionForm({ ...questionForm, [key]: e.target.value })}
                          className={`flex-1 px-3 py-1.5 border rounded-xl bg-secondary/50 outline-none text-xs ${
                            isSelected ? 'border-mint bg-mint/20 font-bold' : 'border-border'
                          }`}
                          placeholder={`Variant ${idx + 1}`}
                        />
                      </div>
                    );
                  })}
                </div>

                <div>
                  <label className="font-bold text-foreground block mb-1">{t('admin.fullExplanation')}</label>
                  <textarea
                    rows={2}
                    value={questionForm.explanation}
                    onChange={(e) => setQuestionForm({ ...questionForm, explanation: e.target.value })}
                    className="w-full px-3 py-2 border border-border rounded-xl bg-secondary/50 outline-none"
                    placeholder={t('admin.solutionExample')}
                  />
                </div>

                <div className="flex items-center gap-2 pt-1">
                  <input
                    type="checkbox"
                    id="isPlacementCheck"
                    checked={questionForm.isPlacement}
                    onChange={(e) => setQuestionForm({ ...questionForm, isPlacement: e.target.checked })}
                    className="rounded text-brand cursor-pointer"
                  />
                  <label htmlFor="isPlacementCheck" className="text-xs font-semibold text-foreground cursor-pointer">{t('admin.useDiagnostic')}</label>
                </div>

                <div className="flex justify-end gap-2 pt-3">
                  <Button variant="ghost" type="button" onClick={() => setShowQuestionModal(false)}>{t('courses.cancel')}</Button>
                  <Button variant="primary" type="submit" isLoading={isSubmitting}>{t('admin.saveQuestion')}</Button>
                </div>
              </form>
          </Modal>
        )}
    </div>
  );
};
