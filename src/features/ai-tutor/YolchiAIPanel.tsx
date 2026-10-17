import React from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { AlertCircle, ArrowRight, X, CheckCircle2 } from 'lucide-react';
import { AIExplanationResponse } from '@/data/services/IAITutorService';
import { Button } from '@/presentation/components/Button';
import { YolchiAIMascot } from '@/presentation/components/YolchiAIMascot';

interface YolchiAIPanelProps {
  isOpen: boolean;
  explanation: AIExplanationResponse | null;
  onProceedToReinforcement: () => void;
  onClose: () => void;
}

export const YolchiAIPanel: React.FC<YolchiAIPanelProps> = ({
  isOpen,
  explanation,
  onProceedToReinforcement,
  onClose,
}) => {
  if (!isOpen || !explanation) return null;

  return (
    <AnimatePresence>
      <div className="fixed inset-0 z-50 bg-slate-950/70 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
        <motion.div
          initial={{ opacity: 0, scale: 0.95, y: 20 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.95, y: 20 }}
          transition={{ duration: 0.25 }}
          className="max-w-xl w-full my-6"
        >
          {/* Reference 4: Error Diagnosis Card with Sunset Coral-Orange Container */}
          <div className="rounded-3xl p-6 sm:p-8 bg-gradient-to-b from-[#FFF5F2] via-[#FFEBE5] to-[#FFDDD4] border-2 border-[#FF8A65] shadow-2xl space-y-6 relative overflow-hidden">
            {/* Top Badge & Close */}
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <span className="px-3 py-1 rounded-full bg-[#FF7043] text-white text-xs font-black tracking-wider uppercase shadow-xs">
                  Error Diagnosis: Yo‘lchi AI
                </span>
                <span className="w-2 h-2 rounded-full bg-[#FF7043] animate-pulse" />
              </div>

              <button
                onClick={onClose}
                aria-label="Yopish"
                className="p-1.5 rounded-full text-slate-500 hover:text-slate-800 hover:bg-white/60 transition-colors cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Mascot with Speech Bubble (Reference 4 layout) */}
            <div className="flex items-start gap-4">
              <YolchiAIMascot size="md" mood="explaining" />
              <div className="flex-1 p-4 rounded-2xl bg-white border border-[#FFCCBC] shadow-xs text-xs sm:text-sm font-semibold text-slate-800 leading-relaxed">
                <p>
                  Afsuski, javob noto‘g‘ri bo‘ldi. Lekin xavotirlanmang! Bu mavzuni o‘zlashtirish uchun eng yaxshi imkoniyat.
                  Keling, bosqichma-bosqich qanday yechilishini ko‘ramiz:
                </p>
              </div>
            </div>

            {/* Honest disclosure when the AI edge function failed and a deterministic
                explanation is being shown instead of a real model answer. */}
            {explanation.isFallback && (
              <div className="p-3 rounded-2xl bg-amber-50 border border-amber-200 flex items-start gap-2.5">
                <AlertCircle className="w-4 h-4 text-amber-600 shrink-0 mt-0.5" />
                <span className="text-[11px] sm:text-xs font-semibold text-amber-900 leading-relaxed">
                  AI xizmati hozircha javob bera olmayapti — namunaviy tahlil ko‘rsatilmoqda.
                </span>
              </div>
            )}

            {/* Step-by-Step Visual Solution Breakdown (Reference 4) */}
            <div className="space-y-3">
              {/* Step 1: Diagnosis title */}
              <div className="p-4 rounded-2xl bg-white/90 border border-[#FFAB91] shadow-2xs space-y-1.5">
                <div className="flex items-center gap-2">
                  <span className="w-6 h-6 rounded-lg bg-[#FF7043] text-white font-black text-xs flex items-center justify-center shrink-0">
                    1
                  </span>
                  <span className="text-xs font-extrabold text-slate-900">
                    Xatoning mohiyati
                  </span>
                </div>
                <div className="pl-8 text-xs text-slate-700 font-semibold bg-slate-50 p-2 rounded-xl border border-slate-200 whitespace-pre-line">
                  {explanation.title}
                </div>
              </div>

              {/* Step 2: Explanation */}
              <div className="p-4 rounded-2xl bg-white/90 border border-[#FFAB91] shadow-2xs space-y-1.5">
                <div className="flex items-center gap-2">
                  <span className="w-6 h-6 rounded-lg bg-[#FF7043] text-white font-black text-xs flex items-center justify-center shrink-0">
                    2
                  </span>
                  <span className="text-xs font-extrabold text-slate-900">
                    Nima uchun adashdingiz?
                  </span>
                </div>
                <div className="pl-8 text-xs text-slate-700 font-medium bg-slate-50 p-2 rounded-xl border border-slate-200 whitespace-pre-line">
                  {explanation.explanation}
                </div>
              </div>

              {/* Step 3: Correct remediation */}
              <div className="p-4 rounded-2xl bg-emerald-50 border-2 border-emerald-400 shadow-2xs space-y-1.5">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <span className="w-6 h-6 rounded-lg bg-emerald-600 text-white font-black text-xs flex items-center justify-center shrink-0">
                      3
                    </span>
                    <span className="text-xs font-extrabold text-emerald-950">
                      To‘g‘ri qoida
                    </span>
                  </div>
                  <CheckCircle2 className="w-5 h-5 text-emerald-600" />
                </div>
                <div className="pl-8 text-sm font-semibold text-emerald-900 whitespace-pre-line">
                  {explanation.remediationStep}
                </div>
              </div>
            </div>

            {/* Action Buttons (Reference 4) */}
            <div className="space-y-2.5 pt-2">
              <Button
                variant="gradient"
                size="lg"
                onClick={onProceedToReinforcement}
                rightIcon={<ArrowRight className="w-5 h-5" />}
                className="w-full font-black py-4 shadow-xl shadow-indigo-600/30 text-sm sm:text-base tracking-wide"
              >
                MAVZUNI MUSTAHKAMLASH
              </Button>

              <button
                type="button"
                onClick={onClose}
                className="w-full py-2.5 text-center text-xs font-bold text-slate-600 hover:text-slate-900 transition-colors cursor-pointer"
              >
                Tekshirishni o‘tkazib yuborish
              </button>
            </div>
          </div>
        </motion.div>
      </div>
    </AnimatePresence>
  );
};