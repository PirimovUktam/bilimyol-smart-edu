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
      <div className="fixed inset-0 z-50 bg-[#10151f]/75 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
        <motion.div
          initial={{ opacity: 0, scale: 0.96, y: 16 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.96, y: 16 }}
          transition={{ duration: 0.25 }}
          className="max-w-xl w-full my-6"
        >
          {/* Neo-Editorial Error Diagnosis Container */}
          <div className="rounded-2xl p-6 sm:p-8 bg-white border border-[#e4ddce] shadow-2xl space-y-6 relative overflow-hidden">
            {/* Top architectural alert strip */}
            <div className="absolute top-0 left-0 right-0 h-1.5 bg-[#e03131]" />

            {/* Top Badge & Close */}
            <div className="flex items-center justify-between pt-1">
              <div className="flex items-center gap-2">
                <span className="px-2.5 py-1 rounded bg-[#10151f] text-white font-mono text-[11px] font-bold tracking-wider uppercase">
                  Xato Diagnostikasi // Yo‘lchi AI
                </span>
                <span className="w-2 h-2 rounded-full bg-[#e03131] animate-pulse" />
              </div>

              <button
                onClick={onClose}
                aria-label="Yopish"
                className="p-1.5 rounded-lg text-slate-500 hover:text-slate-900 hover:bg-[#f5efe4] transition-colors cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Mascot with Speech Bubble */}
            <div className="flex items-start gap-4 p-4 rounded-xl bg-[#fbf9f4] border border-[#e4ddce]">
              <YolchiAIMascot size="md" mood="explaining" />
              <div className="flex-1 text-xs sm:text-sm font-medium text-slate-800 leading-relaxed font-sans">
                <p>
                  Ushbu javobda noaniqlik yuz berdi. Bu mavzuni chuqurroq o‘zlashtirish uchun eng yaxshi fursat.
                  Quyidagi tahlil orqali xato ildizini ko‘rib chiqamiz:
                </p>
              </div>
            </div>

            {/* Fallback warning if AI offline */}
            {explanation.isFallback && (
              <div className="p-3 rounded-xl bg-amber-50 border border-amber-200 flex items-start gap-2.5">
                <AlertCircle className="w-4 h-4 text-amber-700 shrink-0 mt-0.5" />
                <span className="font-mono text-xs text-amber-900 leading-relaxed">
                  AI xizmati hozircha javob bera olmadi — namunaviy tahlil ko‘rsatilmoqda.
                </span>
              </div>
            )}

            {/* Step-by-Step Visual Solution Breakdown */}
            <div className="space-y-3">
              {/* Step 1: Diagnosis title */}
              <div className="p-4 rounded-xl bg-white border border-[#e4ddce] shadow-xs space-y-1.5">
                <div className="flex items-center gap-2">
                  <span className="w-5 h-5 rounded bg-[#10151f] text-white font-mono font-bold text-[11px] flex items-center justify-center shrink-0">
                    01
                  </span>
                  <span className="font-mono text-xs font-bold text-slate-900 uppercase tracking-wider">
                    Xatoning mohiyati
                  </span>
                </div>
                <div className="pl-7 text-xs text-slate-700 font-medium bg-[#fbf9f4] p-2.5 rounded-lg border border-[#e4ddce] whitespace-pre-line font-sans">
                  {explanation.title}
                </div>
              </div>

              {/* Step 2: Explanation */}
              <div className="p-4 rounded-xl bg-white border border-[#e4ddce] shadow-xs space-y-1.5">
                <div className="flex items-center gap-2">
                  <span className="w-5 h-5 rounded bg-[#10151f] text-white font-mono font-bold text-[11px] flex items-center justify-center shrink-0">
                    02
                  </span>
                  <span className="font-mono text-xs font-bold text-slate-900 uppercase tracking-wider">
                    Nima uchun adashdingiz?
                  </span>
                </div>
                <div className="pl-7 text-xs text-slate-700 font-medium bg-[#fbf9f4] p-2.5 rounded-lg border border-[#e4ddce] whitespace-pre-line font-sans">
                  {explanation.explanation}
                </div>
              </div>

              {/* Step 3: Correct remediation */}
              <div className="p-4 rounded-xl bg-emerald-50/80 border border-mint/30 shadow-xs space-y-1.5">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <span className="w-5 h-5 rounded bg-mint text-white font-mono font-bold text-[11px] flex items-center justify-center shrink-0">
                      03
                    </span>
                    <span className="font-mono text-xs font-bold text-mint uppercase tracking-wider">
                      To‘g‘ri qoida va yechim
                    </span>
                  </div>
                  <CheckCircle2 className="w-4 h-4 text-mint" />
                </div>
                <div className="pl-7 text-xs sm:text-sm font-semibold text-mint whitespace-pre-line font-sans">
                  {explanation.remediationStep}
                </div>
              </div>
            </div>

            {/* Action Buttons */}
            <div className="space-y-2.5 pt-1">
              <Button
                variant="primary"
                size="lg"
                onClick={onProceedToReinforcement}
                rightIcon={<ArrowRight className="w-5 h-5" />}
                className="w-full font-bold py-3.5 text-sm uppercase tracking-wider"
              >
                Mavzuni Mustahkamlash Mashqi
              </Button>

              <button
                type="button"
                onClick={onClose}
                className="w-full py-2 text-center font-mono text-xs font-bold text-slate-500 hover:text-slate-900 transition-colors cursor-pointer"
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