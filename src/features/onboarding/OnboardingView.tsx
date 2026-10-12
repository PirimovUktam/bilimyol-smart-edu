import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Target, Clock, BarChart3, ArrowRight, ArrowLeft, Check, Sparkles, Compass } from 'lucide-react';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { OnboardingGoal, DailyTimeCommitment, InitialLevel } from '@/core/types/common';
import { Button } from '@/presentation/components/Button';
import { Card } from '@/presentation/components/Card';
import { Badge } from '@/presentation/components/Badge';

interface OnboardingViewProps {
  onComplete: () => void;
  onBack: () => void;
}

export const OnboardingView: React.FC<OnboardingViewProps> = ({ onComplete, onBack }) => {
  const { activeCourse } = useCourseStore();
  const { setOnboardingData } = useLearnerStore();

  const [step, setStep] = useState<1 | 2 | 3>(1);
  const [goal, setGoal] = useState<OnboardingGoal>('mastery');
  const [dailyMinutes, setDailyMinutes] = useState<DailyTimeCommitment>(15);
  const [initialLevel, setInitialLevel] = useState<InitialLevel>('intermediate');

  const isMath = activeCourse?.subject === 'mathematics';

  const goalOptions = isMath
    ? [
        { id: 'mastery' as OnboardingGoal, title: 'Mavzuni mustahkamlash', desc: 'Asosiy formulalar va tushunchalarni chuqurroq o‘zlashtirish' },
        { id: 'exam_prep' as OnboardingGoal, title: 'Imtihonga tayyorlanish', desc: 'DTM va milliy sertifikat testlariga qat’iy tayyorgarlik' },
        { id: 'skills_boost' as OnboardingGoal, title: 'Bilim darajasini oshirish', desc: 'Mantiqiy fikrlash va masalalar yechish tezligini oshirish' },
      ]
    : [
        { id: 'mastery' as OnboardingGoal, title: 'Umumiy ingliz tilini yaxshilash', desc: 'Kundalik suhbat va erkin fikr bayon qilish' },
        { id: 'exam_prep' as OnboardingGoal, title: 'Imtihonga tayyorlanish', desc: 'IELTS / CEFR imtihonlariga yo‘naltirilgan intensiv reja' },
        { id: 'skills_boost' as OnboardingGoal, title: 'Til ko‘nikmalarini rivojlantirish', desc: 'Listening va Reading ko‘nikmalarini mustahkamlash' },
      ];

  const timeOptions: { value: DailyTimeCommitment; label: string; desc: string }[] = [
    { value: 15, label: '15 daqiqa', desc: 'Engil va barqaror kunlik odat' },
    { value: 30, label: '30 daqiqa', desc: 'Optimal intensivlikdagi o‘rganish' },
    { value: 60, label: '60 daqiqa', desc: 'Tezkor va chuqur natijaga erishish' },
  ];

  const levelOptions: { value: InitialLevel; label: string; desc: string }[] = [
    { value: 'beginner', label: 'Boshlang‘ich', desc: 'Asosiy tushunchalardan boshlamoqchiman' },
    { value: 'intermediate', label: 'O‘rta', desc: 'Bazasini bilaman, bo‘shliqlarni to‘ldirmoqchiman' },
    { value: 'advanced', label: 'Yuqori', desc: 'Murakkab masalalar va yuqori daraja kerak' },
  ];

  const handleNext = async () => {
    if (step < 3) {
      setStep((s) => (s + 1) as 1 | 2 | 3);
    } else {
      await setOnboardingData(goal, dailyMinutes, initialLevel);
      onComplete();
    }
  };

  const handlePrev = () => {
    if (step > 1) {
      setStep((s) => (s - 1) as 1 | 2 | 3);
    } else {
      onBack();
    }
  };

  return (
    <div className="min-h-[calc(100vh-120px)] flex flex-col items-center justify-center px-4 py-8">
      <div className="max-w-2xl w-full">
        {/* Progress Bar */}
        <div className="mb-8">
          <div className="flex items-center justify-between text-xs font-bold text-slate-400 mb-2">
            <span className="flex items-center gap-1.5">
              <span className="w-2 h-2 rounded-full bg-cyan-400 animate-pulse" />
              Bosqich {step} / 3
            </span>
            <span className="text-cyan-300 font-extrabold">
              {step === 1 ? 'Ta’lim Maqsadi' : step === 2 ? 'Kunlik Vaqt' : 'Dastlabki Daraja'}
            </span>
          </div>
          <div className="h-2.5 w-full bg-slate-800/90 rounded-full overflow-hidden border border-slate-700/60">
            <motion.div
              className="h-full bg-gradient-to-r from-cyan-400 via-blue-500 to-indigo-500 rounded-full shadow-sm shadow-cyan-500/40"
              initial={{ width: '33%' }}
              animate={{ width: `${(step / 3) * 100}%` }}
              transition={{ duration: 0.35 }}
            />
          </div>
        </div>

        <Card variant="cosmicGlow" className="p-8 sm:p-10 bg-slate-900/90">
          <AnimatePresence mode="wait">
            {step === 1 && (
              <motion.div
                key="step1"
                initial={{ opacity: 0, x: 20 }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: -20 }}
                transition={{ duration: 0.25 }}
                className="space-y-6"
              >
                <div className="flex items-center gap-3.5">
                  <div className="w-11 h-11 rounded-2xl bg-cyan-500/15 border border-cyan-500/40 text-cyan-300 flex items-center justify-center shadow-sm shadow-cyan-500/20 shrink-0">
                    <Target className="w-6 h-6" />
                  </div>
                  <div>
                    <h2 className="text-xl sm:text-2xl font-black text-white tracking-tight">
                      {activeCourse?.title} bo‘yicha maqsadingiz nima?
                    </h2>
                    <p className="text-xs sm:text-sm text-slate-400 mt-0.5">Shaxsiy rejani sizning ustuvorligingizga moslaymiz</p>
                  </div>
                </div>

                <div className="space-y-3 pt-2">
                  {goalOptions.map((opt) => {
                    const isSelected = goal === opt.id;
                    return (
                      <button
                        key={opt.id}
                        type="button"
                        onClick={() => setGoal(opt.id)}
                        className={`w-full text-left p-4.5 rounded-2xl border-2 transition-all flex items-center justify-between cursor-pointer ${
                          isSelected
                            ? 'border-cyan-400 bg-cyan-950/60 shadow-md shadow-cyan-500/20 ring-1 ring-cyan-400/40'
                            : 'border-slate-800 bg-slate-900/70 hover:border-slate-700 hover:bg-slate-800/80'
                        }`}
                      >
                        <div>
                          <div className={`font-bold text-sm ${isSelected ? 'text-white' : 'text-slate-200'}`}>
                            {opt.title}
                          </div>
                          <div className="text-xs text-slate-400 mt-1">{opt.desc}</div>
                        </div>
                        <div
                          className={`w-6 h-6 rounded-full border flex items-center justify-center transition-colors shrink-0 ml-3 ${
                            isSelected ? 'bg-gradient-to-r from-cyan-400 to-blue-500 border-cyan-400 text-slate-950 shadow-xs' : 'border-slate-700 bg-slate-800'
                          }`}
                        >
                          {isSelected && <Check className="w-3.5 h-3.5 stroke-[3]" />}
                        </div>
                      </button>
                    );
                  })}
                </div>
              </motion.div>
            )}

            {step === 2 && (
              <motion.div
                key="step2"
                initial={{ opacity: 0, x: 20 }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: -20 }}
                transition={{ duration: 0.25 }}
                className="space-y-6"
              >
                <div className="flex items-center gap-3.5">
                  <div className="w-11 h-11 rounded-2xl bg-teal-500/15 border border-teal-500/40 text-teal-300 flex items-center justify-center shadow-sm shadow-teal-500/20 shrink-0">
                    <Clock className="w-6 h-6" />
                  </div>
                  <div>
                    <h2 className="text-xl sm:text-2xl font-black text-white tracking-tight">
                      Kuniga qancha vaqt ajrata olasiz?
                    </h2>
                    <p className="text-xs sm:text-sm text-slate-400 mt-0.5">Muntazamlik va uzluksiz ketma-ketlik (Streak) muvaffaqiyat garovidir</p>
                  </div>
                </div>

                <div className="space-y-3 pt-2">
                  {timeOptions.map((opt) => {
                    const isSelected = dailyMinutes === opt.value;
                    return (
                      <button
                        key={opt.value}
                        type="button"
                        onClick={() => setDailyMinutes(opt.value)}
                        className={`w-full text-left p-4.5 rounded-2xl border-2 transition-all flex items-center justify-between cursor-pointer ${
                          isSelected
                            ? 'border-teal-400 bg-teal-950/60 shadow-md shadow-teal-500/20 ring-1 ring-teal-400/40'
                            : 'border-slate-800 bg-slate-900/70 hover:border-slate-700 hover:bg-slate-800/80'
                        }`}
                      >
                        <div>
                          <div className={`font-bold text-sm ${isSelected ? 'text-white' : 'text-slate-200'}`}>
                            {opt.label}
                          </div>
                          <div className="text-xs text-slate-400 mt-1">{opt.desc}</div>
                        </div>
                        <div
                          className={`w-6 h-6 rounded-full border flex items-center justify-center transition-colors shrink-0 ml-3 ${
                            isSelected ? 'bg-gradient-to-r from-teal-400 to-emerald-500 border-teal-400 text-slate-950 shadow-xs' : 'border-slate-700 bg-slate-800'
                          }`}
                        >
                          {isSelected && <Check className="w-3.5 h-3.5 stroke-[3]" />}
                        </div>
                      </button>
                    );
                  })}
                </div>
              </motion.div>
            )}

            {step === 3 && (
              <motion.div
                key="step3"
                initial={{ opacity: 0, x: 20 }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: -20 }}
                transition={{ duration: 0.25 }}
                className="space-y-6"
              >
                <div className="flex items-center gap-3.5">
                  <div className="w-11 h-11 rounded-2xl bg-indigo-500/15 border border-indigo-500/40 text-indigo-300 flex items-center justify-center shadow-sm shadow-indigo-500/20 shrink-0">
                    <BarChart3 className="w-6 h-6" />
                  </div>
                  <div>
                    <h2 className="text-xl sm:text-2xl font-black text-white tracking-tight">
                      O‘z darajangizni qanday baholaysiz?
                    </h2>
                    <p className="text-xs sm:text-sm text-slate-400 mt-0.5">Keyingi qadamda 5 ta qisqa savolli Placement Test o‘tkazamiz</p>
                  </div>
                </div>

                <div className="space-y-3 pt-2">
                  {levelOptions.map((opt) => {
                    const isSelected = initialLevel === opt.value;
                    return (
                      <button
                        key={opt.value}
                        type="button"
                        onClick={() => setInitialLevel(opt.value)}
                        className={`w-full text-left p-4.5 rounded-2xl border-2 transition-all flex items-center justify-between cursor-pointer ${
                          isSelected
                            ? 'border-indigo-400 bg-indigo-950/60 shadow-md shadow-indigo-500/20 ring-1 ring-indigo-400/40'
                            : 'border-slate-800 bg-slate-900/70 hover:border-slate-700 hover:bg-slate-800/80'
                        }`}
                      >
                        <div>
                          <div className={`font-bold text-sm ${isSelected ? 'text-white' : 'text-slate-200'}`}>
                            {opt.label}
                          </div>
                          <div className="text-xs text-slate-400 mt-1">{opt.desc}</div>
                        </div>
                        <div
                          className={`w-6 h-6 rounded-full border flex items-center justify-center transition-colors shrink-0 ml-3 ${
                            isSelected ? 'bg-gradient-to-r from-indigo-400 to-purple-500 border-indigo-400 text-white shadow-xs' : 'border-slate-700 bg-slate-800'
                          }`}
                        >
                          {isSelected && <Check className="w-3.5 h-3.5 stroke-[3]" />}
                        </div>
                      </button>
                    );
                  })}
                </div>

                <div className="p-3.5 bg-amber-950/40 rounded-xl border border-amber-500/40 text-xs text-amber-300 flex items-start gap-2.5 shadow-sm">
                  <Sparkles className="w-4 h-4 text-amber-400 shrink-0 mt-0.5" />
                  <span>
                    <strong>Eslatma:</strong> Bu faqat dastlabki so‘rovnoma. Asosiy ko‘nikma ballari (Skill Scores) Placement Test orqali aniqlanadi.
                  </span>
                </div>
              </motion.div>
            )}
          </AnimatePresence>

          <div className="flex items-center justify-between pt-8 mt-6 border-t border-slate-800/80">
            <Button
              type="button"
              variant="outline"
              size="md"
              onClick={handlePrev}
              leftIcon={<ArrowLeft className="w-4 h-4" />}
              className="bg-slate-800/80 hover:bg-slate-700 text-slate-300 border-slate-700"
            >
              Orqaga
            </Button>

            <Button
              type="button"
              variant="cyan"
              size="md"
              onClick={handleNext}
              rightIcon={<ArrowRight className="w-4 h-4" />}
              className="font-black px-6"
            >
              {step === 3 ? 'Placement Testga o‘tish' : 'Keyingisi'}
            </Button>
          </div>
        </Card>
      </div>
    </div>
  );
};

