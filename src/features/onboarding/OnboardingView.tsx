import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Target, Clock, BarChart3, ArrowRight, ArrowLeft, Check, Sparkles } from 'lucide-react';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { OnboardingGoal, DailyTimeCommitment, InitialLevel } from '@/core/types/common';
import { Button } from '@/presentation/components/Button';
import { Card } from '@/presentation/components/Card';

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
          <div className="flex items-center justify-between text-xs font-bold text-slate-500 mb-2">
            <span>Bosqich {step} / 3</span>
            <span>{step === 1 ? 'Maqsad' : step === 2 ? 'Kunlik Vaqt' : 'Dastlabki Baholash'}</span>
          </div>
          <div className="h-2 w-full bg-slate-200 rounded-full overflow-hidden">
            <motion.div
              className="h-full bg-blue-600 rounded-full"
              initial={{ width: '33%' }}
              animate={{ width: `${(step / 3) * 100}%` }}
              transition={{ duration: 0.3 }}
            />
          </div>
        </div>

        <Card className="border-slate-200/90 shadow-xl p-8">
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
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-xl bg-blue-100 text-blue-700 flex items-center justify-center">
                    <Target className="w-5 h-5" />
                  </div>
                  <div>
                    <h2 className="text-xl font-bold text-slate-900">
                      {activeCourse?.title} bo‘yicha asosiy maqsadingiz nima?
                    </h2>
                    <p className="text-xs text-slate-500">Shaxsiy rejani maqsadingizga qarab moslaymiz</p>
                  </div>
                </div>

                <div className="space-y-3">
                  {goalOptions.map((opt) => {
                    const isSelected = goal === opt.id;
                    return (
                      <button
                        key={opt.id}
                        type="button"
                        onClick={() => setGoal(opt.id)}
                        className={`w-full text-left p-4 rounded-2xl border-2 transition-all flex items-center justify-between cursor-pointer ${
                          isSelected
                            ? 'border-blue-600 bg-blue-50/60 shadow-xs'
                            : 'border-slate-200 hover:border-slate-300 hover:bg-slate-50/50'
                        }`}
                      >
                        <div>
                          <div className="font-bold text-slate-900 text-sm">{opt.title}</div>
                          <div className="text-xs text-slate-500 mt-0.5">{opt.desc}</div>
                        </div>
                        <div
                          className={`w-5 h-5 rounded-full border flex items-center justify-center transition-colors ${
                            isSelected ? 'bg-blue-600 border-blue-600 text-white' : 'border-slate-300'
                          }`}
                        >
                          {isSelected && <Check className="w-3 h-3 stroke-[3]" />}
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
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-xl bg-teal-100 text-teal-700 flex items-center justify-center">
                    <Clock className="w-5 h-5" />
                  </div>
                  <div>
                    <h2 className="text-xl font-bold text-slate-900">
                      Kuniga qancha vaqt ajrata olasiz?
                    </h2>
                    <p className="text-xs text-slate-500">Muntazamlik — muvaffaqiyat garovidir</p>
                  </div>
                </div>

                <div className="space-y-3">
                  {timeOptions.map((opt) => {
                    const isSelected = dailyMinutes === opt.value;
                    return (
                      <button
                        key={opt.value}
                        type="button"
                        onClick={() => setDailyMinutes(opt.value)}
                        className={`w-full text-left p-4 rounded-2xl border-2 transition-all flex items-center justify-between cursor-pointer ${
                          isSelected
                            ? 'border-teal-600 bg-teal-50/60 shadow-xs'
                            : 'border-slate-200 hover:border-slate-300 hover:bg-slate-50/50'
                        }`}
                      >
                        <div>
                          <div className="font-bold text-slate-900 text-sm">{opt.label}</div>
                          <div className="text-xs text-slate-500 mt-0.5">{opt.desc}</div>
                        </div>
                        <div
                          className={`w-5 h-5 rounded-full border flex items-center justify-center transition-colors ${
                            isSelected ? 'bg-teal-600 border-teal-600 text-white' : 'border-slate-300'
                          }`}
                        >
                          {isSelected && <Check className="w-3 h-3 stroke-[3]" />}
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
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-xl bg-indigo-100 text-indigo-700 flex items-center justify-center">
                    <BarChart3 className="w-5 h-5" />
                  </div>
                  <div>
                    <h2 className="text-xl font-bold text-slate-900">
                      O‘z darajangizni qanday baholaysiz?
                    </h2>
                    <p className="text-xs text-slate-500">Keyingi qadamda 5 ta qisqa savolli Placement Test o‘tkazamiz</p>
                  </div>
                </div>

                <div className="space-y-3">
                  {levelOptions.map((opt) => {
                    const isSelected = initialLevel === opt.value;
                    return (
                      <button
                        key={opt.value}
                        type="button"
                        onClick={() => setInitialLevel(opt.value)}
                        className={`w-full text-left p-4 rounded-2xl border-2 transition-all flex items-center justify-between cursor-pointer ${
                          isSelected
                            ? 'border-indigo-600 bg-indigo-50/60 shadow-xs'
                            : 'border-slate-200 hover:border-slate-300 hover:bg-slate-50/50'
                        }`}
                      >
                        <div>
                          <div className="font-bold text-slate-900 text-sm">{opt.label}</div>
                          <div className="text-xs text-slate-500 mt-0.5">{opt.desc}</div>
                        </div>
                        <div
                          className={`w-5 h-5 rounded-full border flex items-center justify-center transition-colors ${
                            isSelected ? 'bg-indigo-600 border-indigo-600 text-white' : 'border-slate-300'
                          }`}
                        >
                          {isSelected && <Check className="w-3 h-3 stroke-[3]" />}
                        </div>
                      </button>
                    );
                  })}
                </div>

                <div className="p-3 bg-amber-50/80 rounded-xl border border-amber-200/80 text-[11px] text-amber-800 flex items-start gap-2">
                  <Sparkles className="w-4 h-4 text-amber-600 shrink-0 mt-0.5" />
                  <span>
                    <strong>Eslatma:</strong> Bu faqat dastlabki so‘rovnoma. Asosiy ko‘nikma ballari (Skill Scores) Placement Test orqali aniqlanadi.
                  </span>
                </div>
              </motion.div>
            )}
          </AnimatePresence>

          <div className="flex items-center justify-between pt-8 mt-6 border-t border-slate-100">
            <Button
              type="button"
              variant="ghost"
              size="md"
              onClick={handlePrev}
              leftIcon={<ArrowLeft className="w-4 h-4" />}
            >
              Orqaga
            </Button>

            <Button
              type="button"
              variant="primary"
              size="md"
              onClick={handleNext}
              rightIcon={<ArrowRight className="w-4 h-4" />}
            >
              {step === 3 ? 'Placement Testga o‘tish' : 'Keyingisi'}
            </Button>
          </div>
        </Card>
      </div>
    </div>
  );
};
