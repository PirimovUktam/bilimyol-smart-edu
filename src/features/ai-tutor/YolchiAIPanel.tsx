import React from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Bot, AlertCircle, ArrowRight, X, Lightbulb } from 'lucide-react';
import { AIExplanationResponse } from '@/data/services/IAITutorService';
import { Button } from '@/presentation/components/Button';
import { Card } from '@/presentation/components/Card';

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
      <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-xs flex items-center justify-center p-4">
        <motion.div
          initial={{ opacity: 0, scale: 0.95, y: 20 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.95, y: 20 }}
          transition={{ duration: 0.25 }}
          className="max-w-2xl w-full"
        >
          <Card className="p-7 sm:p-9 shadow-2xl border-2 border-blue-500 bg-white relative overflow-hidden">
            {/* Header / Avatar */}
            <div className="flex items-start justify-between gap-4 mb-6">
              <div className="flex items-center gap-3.5">
                <div className="w-13 h-13 rounded-2xl bg-gradient-to-tr from-blue-600 to-indigo-600 text-white flex items-center justify-center shadow-lg shadow-blue-500/25 shrink-0">
                  <Bot className="w-7 h-7" />
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <h3 className="text-xl font-extrabold text-slate-900">
                      {explanation.tutorName}
                    </h3>
                    <span className="px-2 py-0.5 text-[10px] font-extrabold uppercase rounded-full bg-blue-100 text-blue-800 border border-blue-200">
                      Pedagogik Tahlil
                    </span>
                  </div>
                  <p className="text-xs text-slate-500 mt-0.5">
                    Xatolik sababini tushuntirish va o‘rganish yo‘li
                  </p>
                </div>
              </div>

              <button
                onClick={onClose}
                className="p-2 rounded-xl text-slate-400 hover:text-slate-600 hover:bg-slate-100 transition-colors cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Misconception Diagnostic */}
            <div className="space-y-5">
              <div className="p-4 rounded-2xl bg-amber-50/80 border border-amber-200 text-amber-900 space-y-2">
                <div className="flex items-center gap-2 text-xs font-bold uppercase tracking-wider text-amber-800">
                  <AlertCircle className="w-4 h-4 text-amber-600" />
                  <span>Aniqlangan Xatolik Turi: {explanation.title}</span>
                </div>
                <p className="text-sm font-medium text-amber-950 leading-relaxed">
                  {explanation.explanation}
                </p>
              </div>

              <div className="p-4 rounded-2xl bg-blue-50/70 border border-blue-200 text-blue-900 space-y-1.5">
                <div className="flex items-center gap-2 text-xs font-bold uppercase tracking-wider text-blue-800">
                  <Lightbulb className="w-4 h-4 text-blue-600" />
                  <span>Qoida va Yechim:</span>
                </div>
                <p className="text-sm font-medium text-slate-800 leading-relaxed">
                  {explanation.remediationStep}
                </p>
              </div>

              <p className="text-xs font-medium text-slate-500 italic">
                💡 {explanation.suggestedAction}
              </p>
            </div>

            {/* Action CTAs */}
            <div className="pt-6 mt-6 border-t border-slate-100 flex flex-col sm:flex-row items-center justify-between gap-3">
              <Button
                variant="ghost"
                size="md"
                onClick={onClose}
                className="w-full sm:w-auto text-slate-500"
              >
                Qayta o‘ylab ko‘rish
              </Button>

              <Button
                variant="primary"
                size="lg"
                onClick={onProceedToReinforcement}
                rightIcon={<ArrowRight className="w-5 h-5" />}
                className="w-full sm:w-auto shadow-lg shadow-blue-600/30"
              >
                Mustahkamlash Mashqiga O‘tish
              </Button>
            </div>
          </Card>
        </motion.div>
      </div>
    </AnimatePresence>
  );
};
