import React from 'react';
import { motion } from 'framer-motion';
import { Calculator, Headphones, ArrowRight, CheckCircle2, Sparkles, ShieldCheck } from 'lucide-react';
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
          <span>Shaxsiy O‘quv Traektoriyasi</span>
        </div>

        <h1 className="text-3xl sm:text-4xl md:text-5xl font-extrabold text-slate-900 tracking-tight">
          O‘zingizga mos fanni tanlang
        </h1>
        <p className="text-base sm:text-lg text-slate-600 max-w-2xl mx-auto">
          BilimYo‘l sun'iy intellekti darajangizni aniqlaydi va sizga moslashuvchan, bosqichma-bosqich o‘quv yo‘lini tuzib beradi.
        </p>
      </motion.div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 max-w-4xl w-full">
        {courses.map((course, index) => {
          const isMath = course.subject === 'mathematics';
          const Icon = isMath ? Calculator : Headphones;
          const iconBg = isMath ? 'bg-blue-100 text-blue-700' : 'bg-teal-100 text-teal-700';

          return (
            <motion.div
              key={course.id}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.4, delay: index * 0.1 }}
              className="group relative bg-white border-2 border-slate-200/90 rounded-3xl p-7 shadow-sm hover:shadow-xl hover:-translate-y-1 transition-all duration-300 flex flex-col justify-between"
            >
              <div className="space-y-5">
                <div className="flex items-start justify-between">
                  <div className={`w-14 h-14 rounded-2xl ${iconBg} flex items-center justify-center shadow-inner`}>
                    <Icon className="w-7 h-7" />
                  </div>
                  {isMath ? (
                    <Badge variant="blue" size="sm">
                      Asosiy Demo
                    </Badge>
                  ) : (
                    <Badge variant="teal" size="sm">
                      Ikkinchi Demo
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
                    Asosiy ko‘nikmalar (Skill Module):
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
                        <span className="text-xs font-semibold text-blue-600 flex items-center gap-1.5 bg-blue-50/80 px-2 py-1 rounded-lg">
                          <CheckCircle2 className="w-3.5 h-3.5 text-blue-600" /> Funksiyalar (Fokus)
                        </span>
                        <span className="text-xs font-medium text-slate-700 flex items-center gap-1.5">
                          <CheckCircle2 className="w-3.5 h-3.5 text-blue-500" /> Grafiklar
                        </span>
                      </>
                    ) : (
                      <>
                        <span className="text-xs font-medium text-slate-700 flex items-center gap-1.5">
                          <CheckCircle2 className="w-3.5 h-3.5 text-teal-500" /> Vocabulary
                        </span>
                        <span className="text-xs font-medium text-slate-700 flex items-center gap-1.5">
                          <CheckCircle2 className="w-3.5 h-3.5 text-teal-500" /> Grammar
                        </span>
                        <span className="text-xs font-semibold text-teal-600 flex items-center gap-1.5 bg-teal-50/80 px-2 py-1 rounded-lg">
                          <CheckCircle2 className="w-3.5 h-3.5 text-teal-600" /> Listening (Fokus)
                        </span>
                        <span className="text-xs font-medium text-slate-700 flex items-center gap-1.5">
                          <CheckCircle2 className="w-3.5 h-3.5 text-teal-500" /> Reading
                        </span>
                      </>
                    )}
                  </div>
                </div>
              </div>

              <div className="mt-8 pt-4">
                <Button
                  onClick={() => handleChoose(course.id)}
                  variant={isMath ? 'primary' : 'secondary'}
                  size="lg"
                  className="w-full justify-between group-hover:shadow-lg"
                  rightIcon={<ArrowRight className="w-5 h-5 group-hover:translate-x-1 transition-transform" />}
                >
                  Tanlash va Boshlash
                </Button>
              </div>
            </motion.div>
          );
        })}
      </div>

      <div className="mt-12 flex items-center gap-2 text-xs text-slate-500">
        <ShieldCheck className="w-4 h-4 text-emerald-600" />
        <span>Barcha darslar va tahlillar 100% offline rejimda ishlaydi</span>
      </div>
    </div>
  );
};
