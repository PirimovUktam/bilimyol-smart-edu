import React from 'react';
import { motion } from 'framer-motion';
import { Calculator, Headphones, ArrowRight, CheckCircle2, Sparkles, ShieldCheck, Clock } from 'lucide-react';
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
    <div className="min-h-[calc(100vh-120px)] flex flex-col items-center justify-center px-4 py-12">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4 }}
        className="max-w-4xl w-full text-center space-y-4 mb-10"
      >
        <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-blue-50 border border-blue-200/80 text-blue-700 text-xs font-semibold">
          <Sparkles className="w-3.5 h-3.5" />
          <span>Haqiqiy Moslashuvchan Ta’lim Tizimi</span>
        </div>

        <h1 className="text-3xl sm:text-4xl md:text-5xl font-extrabold text-slate-900 tracking-tight">
          O‘rganishni istagan fanni tanlang
        </h1>
        <p className="text-base sm:text-lg text-slate-600 max-w-2xl mx-auto">
          BilimYo‘l sun'iy intellekti darajangizni aniqlaydi va sizga individual, qadamma-qadam o‘quv traektoriyasini tuzib beradi.
        </p>
      </motion.div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 max-w-4xl w-full">
        {courses.map((course, index) => {
          const isMath = course.subject === 'mathematics';
          const Icon = isMath ? Calculator : Headphones;
          const iconBg = isMath ? 'bg-blue-100 text-blue-700' : 'bg-slate-100 text-slate-500';

          return (
            <motion.div
              key={course.id}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.4, delay: index * 0.1 }}
              className={`group relative bg-white border-2 rounded-3xl p-7 shadow-sm transition-all duration-300 flex flex-col justify-between ${
                isMath
                  ? 'border-blue-200 hover:border-blue-500 hover:shadow-xl hover:-translate-y-1'
                  : 'border-slate-200 opacity-80'
              }`}
            >
              <div className="space-y-5">
                <div className="flex items-start justify-between">
                  <div className={`w-14 h-14 rounded-2xl ${iconBg} flex items-center justify-center shadow-inner`}>
                    <Icon className="w-7 h-7" />
                  </div>
                  {isMath ? (
                    <Badge variant="blue" size="sm">
                      Faol Kurs (Full Adaptive)
                    </Badge>
                  ) : (
                    <Badge variant="slate" size="sm">
                      <Clock className="w-3 h-3 mr-1" />
                      Tez kunda
                    </Badge>
                  )}
                </div>

                <div>
                  <h2 className="text-2xl font-bold text-slate-900 group-hover:text-blue-600 transition-colors">
                    {course.title}
                  </h2>
                  <p className="text-slate-600 text-sm mt-2 leading-relaxed">
                    {course.description}
                  </p>
                </div>

                <div className="pt-2 border-t border-slate-100">
                  <span className="text-xs font-bold text-slate-400 uppercase tracking-wider block mb-2.5">
                    Asosiy ko‘nikmalar:
                  </span>
                  <div className="grid grid-cols-2 gap-2">
                    {isMath ? (
                      <>
                        <span className="text-xs font-medium text-slate-700 flex items-center gap-1.5">
                          <CheckCircle2 className="w-3.5 h-3.5 text-blue-500" /> Algebra asoslari
                        </span>
                        <span className="text-xs font-medium text-slate-700 flex items-center gap-1.5">
                          <CheckCircle2 className="w-3.5 h-3.5 text-blue-500" /> Tenglamalar
                        </span>
                        <span className="text-xs font-medium text-slate-700 flex items-center gap-1.5">
                          <CheckCircle2 className="w-3.5 h-3.5 text-blue-500" /> Funksiyalar
                        </span>
                        <span className="text-xs font-medium text-slate-700 flex items-center gap-1.5">
                          <CheckCircle2 className="w-3.5 h-3.5 text-blue-500" /> Grafiklar
                        </span>
                      </>
                    ) : (
                      <>
                        <span className="text-xs font-medium text-slate-500 flex items-center gap-1.5">
                          Vocabulary (Tez orada)
                        </span>
                        <span className="text-xs font-medium text-slate-500 flex items-center gap-1.5">
                          Grammar (Tez orada)
                        </span>
                        <span className="text-xs font-medium text-slate-500 flex items-center gap-1.5">
                          Listening (Tez orada)
                        </span>
                        <span className="text-xs font-medium text-slate-500 flex items-center gap-1.5">
                          Reading (Tez orada)
                        </span>
                      </>
                    )}
                  </div>
                </div>
              </div>

              <div className="mt-8 pt-4">
                {isMath ? (
                  <Button
                    onClick={() => handleChoose(course.id)}
                    variant="primary"
                    size="lg"
                    className="w-full justify-between group-hover:shadow-lg"
                    rightIcon={<ArrowRight className="w-5 h-5 group-hover:translate-x-1 transition-transform" />}
                  >
                    Kursni Tanlash va Boshlash
                  </Button>
                ) : (
                  <div className="p-3 bg-slate-50 border border-slate-200 rounded-xl text-center text-xs font-semibold text-slate-500">
                    Ushbu kurs kontenti tez orada ishga tushadi
                  </div>
                )}
              </div>
            </motion.div>
          );
        })}
      </div>

      <div className="mt-12 flex items-center gap-2 text-xs text-slate-500">
        <ShieldCheck className="w-4 h-4 text-emerald-600" />
        <span>Barcha natijalar va o‘quv yo‘li real statistik hisob-kitoblarga asoslangan</span>
      </div>
    </div>
  );
};
