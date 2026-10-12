import React from 'react';
import { motion } from 'framer-motion';
import { Calculator, Headphones, ArrowRight, CheckCircle2, Sparkles, ShieldCheck, Zap, Brain, Target } from 'lucide-react';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { Button } from '@/presentation/components/Button';
import { Badge } from '@/presentation/components/Badge';

interface CourseSelectionViewProps {
  onSelectCourse: (courseId: string) => void;
}

export const CourseSelectionView: React.FC<CourseSelectionViewProps> = ({ onSelectCourse }) => {
  const { courses, selectCourseById } = useCourseStore();
  const { setSelectedCourse } = useLearnerStore();

  const handleChoose = async (courseId: string) => {
    await selectCourseById(courseId);
    await setSelectedCourse(courseId);
    onSelectCourse(courseId);
  };

  return (
    <div className="min-h-[calc(100vh-120px)] flex flex-col items-center justify-center px-4 py-12 relative overflow-hidden">
      {/* Background ambient glow circles */}
      <div className="absolute top-1/4 left-1/2 -translate-x-1/2 w-[600px] h-[350px] bg-indigo-600/10 rounded-full blur-[140px] pointer-events-none" />

      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5 }}
        className="max-w-4xl w-full text-center space-y-4 mb-12 relative z-10"
      >
        <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-cyan-950/80 border border-cyan-500/40 text-cyan-300 text-xs font-bold shadow-[0_0_20px_rgba(6,182,212,0.25)]">
          <Sparkles className="w-3.5 h-3.5 text-cyan-400" />
          <span>Haqiqiy Moslashuvchan Ta’lim Ekotizimi</span>
        </div>

        <h1 className="text-3xl sm:text-5xl md:text-6xl font-black text-white tracking-tight leading-tight">
          O‘rganishni istagan <span className="bg-clip-text text-transparent bg-gradient-to-r from-cyan-400 via-indigo-400 to-purple-400">fanni tanlang</span>
        </h1>
        <p className="text-sm sm:text-lg text-slate-300 max-w-2xl mx-auto leading-relaxed">
          BilimYo‘l sun'iy intellekti bilim darajangizni aniqlaydi va sizga individual, qadamma-qadam o‘quv traektoriyasini tuzib beradi.
        </p>
      </motion.div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-8 max-w-5xl w-full relative z-10">
        {courses.filter((c) => c.id === 'course_math_01' || c.id === 'course_eng_01').map((course, index) => {
          const isMath = course.subject === 'mathematics';
          const Icon = isMath ? Calculator : Headphones;

          return (
            <motion.div
              key={course.id}
              initial={{ opacity: 0, y: 25 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.5, delay: index * 0.15 }}
              whileHover={{ y: -8, scale: 1.015 }}
              className={`group relative rounded-3xl p-8 backdrop-blur-2xl transition-all duration-300 flex flex-col justify-between overflow-hidden ${
                isMath
                  ? 'bg-slate-900/85 border-2 border-cyan-500/30 hover:border-cyan-400 shadow-[0_0_40px_rgba(6,182,212,0.15)] hover:shadow-[0_0_50px_rgba(6,182,212,0.3)]'
                  : 'bg-slate-900/85 border-2 border-rose-500/30 hover:border-amber-400 shadow-[0_0_40px_rgba(244,63,94,0.15)] hover:shadow-[0_0_50px_rgba(245,158,11,0.3)]'
              }`}
            >
              {/* Card ambient corner glow */}
              <div
                className={`absolute top-0 right-0 w-44 h-44 rounded-full blur-3xl pointer-events-none opacity-20 ${
                  isMath ? 'bg-cyan-500' : 'bg-rose-500'
                }`}
              />

              <div className="space-y-6 relative z-10">
                <div className="flex items-start justify-between">
                  <div
                    className={`w-16 h-16 rounded-2xl flex items-center justify-center shadow-lg ring-2 ${
                      isMath
                        ? 'bg-gradient-to-tr from-cyan-500 to-blue-600 text-white ring-cyan-400/50 shadow-cyan-500/25'
                        : 'bg-gradient-to-tr from-rose-500 to-amber-500 text-white ring-rose-400/50 shadow-rose-500/25'
                    }`}
                  >
                    <Icon className="w-8 h-8" />
                  </div>
                  <Badge variant={isMath ? 'cyan' : 'rose'} size="md">
                    <Zap className="w-3 h-3 mr-1" />
                    Full Adaptive Kurs
                  </Badge>
                </div>

                <div>
                  <h2 className={`text-2xl sm:text-3xl font-extrabold text-white transition-colors ${
                    isMath ? 'group-hover:text-cyan-300' : 'group-hover:text-amber-300'
                  }`}>
                    {course.title}
                  </h2>
                  <p className="text-slate-300 text-sm sm:text-base mt-2.5 leading-relaxed">
                    {course.description}
                  </p>
                </div>

                <div className="pt-4 border-t border-white/10">
                  <span className="text-xs font-bold text-slate-400 uppercase tracking-wider block mb-3">
                    Asosiy ko‘nikmalar & Mavzular:
                  </span>
                  <div className="grid grid-cols-2 gap-2.5">
                    {isMath ? (
                      <>
                        <span className="text-xs font-semibold text-slate-200 flex items-center gap-2">
                          <CheckCircle2 className="w-4 h-4 text-cyan-400" /> Algebra asoslari
                        </span>
                        <span className="text-xs font-semibold text-slate-200 flex items-center gap-2">
                          <CheckCircle2 className="w-4 h-4 text-cyan-400" /> Tenglamalar
                        </span>
                        <span className="text-xs font-semibold text-slate-200 flex items-center gap-2">
                          <CheckCircle2 className="w-4 h-4 text-cyan-400" /> Funksiyalar
                        </span>
                        <span className="text-xs font-semibold text-slate-200 flex items-center gap-2">
                          <CheckCircle2 className="w-4 h-4 text-cyan-400" /> Grafiklar
                        </span>
                      </>
                    ) : (
                      <>
                        <span className="text-xs font-semibold text-slate-200 flex items-center gap-2">
                          <CheckCircle2 className="w-4 h-4 text-rose-400" /> Vocabulary
                        </span>
                        <span className="text-xs font-semibold text-slate-200 flex items-center gap-2">
                          <CheckCircle2 className="w-4 h-4 text-rose-400" /> Grammar & Tenses
                        </span>
                        <span className="text-xs font-semibold text-slate-200 flex items-center gap-2">
                          <CheckCircle2 className="w-4 h-4 text-rose-400" /> Listening Audio
                        </span>
                        <span className="text-xs font-semibold text-slate-200 flex items-center gap-2">
                          <CheckCircle2 className="w-4 h-4 text-rose-400" /> Reading & Pronounce
                        </span>
                      </>
                    )}
                  </div>
                </div>
              </div>

              <div className="mt-8 pt-4 border-t border-white/10 relative z-10">
                <Button
                  onClick={() => handleChoose(course.id)}
                  variant={isMath ? 'gradient' : 'coral'}
                  size="lg"
                  className="w-full justify-between font-black text-white group-hover:shadow-xl transition-all cursor-pointer"
                  rightIcon={<ArrowRight className="w-5 h-5 group-hover:translate-x-1.5 transition-transform" />}
                >
                  Kursni Tanlash va Boshlash
                </Button>
              </div>
            </motion.div>
          );
        })}
      </div>

      {/* Floating confidence indicators */}
      <div className="mt-14 flex flex-wrap items-center justify-center gap-4 sm:gap-6 text-xs text-slate-400 relative z-10">
        <div className="flex items-center gap-2 px-3 py-1.5 rounded-xl bg-slate-900/60 border border-white/10 backdrop-blur-md">
          <ShieldCheck className="w-4 h-4 text-emerald-400" />
          <span>Server-Side Anti-Cheat Scoring</span>
        </div>
        <div className="flex items-center gap-2 px-3 py-1.5 rounded-xl bg-slate-900/60 border border-white/10 backdrop-blur-md">
          <Brain className="w-4 h-4 text-cyan-400" />
          <span>Yo‘lchi AI (Gemini 2.5 Flash)</span>
        </div>
        <div className="flex items-center gap-2 px-3 py-1.5 rounded-xl bg-slate-900/60 border border-white/10 backdrop-blur-md">
          <Target className="w-4 h-4 text-purple-400" />
          <span>100% Individual Ta’lim Traektoriyasi</span>
        </div>
      </div>
    </div>
  );
};
