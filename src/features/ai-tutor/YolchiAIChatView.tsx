import React, { useState, useRef, useEffect, useCallback } from 'react';
import { motion } from 'framer-motion';
import {
  Send,
  Sparkles,
  ArrowRight,
  RefreshCw,
  AlertTriangle,
} from 'lucide-react';
import { YolchiAIMascot } from '@/presentation/components/YolchiAIMascot';
import { Card } from '@/presentation/components/Card';
import { Button } from '@/presentation/components/Button';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useLearnerStore } from '@/app/store/useLearnerStore';
import { GeminiAITutorService, GeminiAIServiceError } from '@/data/services/GeminiAITutorService';
import { isSupabaseConfigured } from '@/core/config/supabase';
import { isDemoRuntimeActive } from '@/core/runtime/demoRuntime';
import { SkillScoringEngine } from '@/domain/personalization/SkillScoringEngine';

interface Message {
  id: string;
  sender: 'ai' | 'user';
  text: string;
  time: string;
  isError?: boolean;
}

interface YolchiAIChatViewProps {
  onStartLesson?: () => void;
}

const aiService = new GeminiAITutorService();

export const YolchiAIChatView: React.FC<YolchiAIChatViewProps> = ({ onStartLesson }) => {
  const { activeCourse } = useCourseStore();
  const { profile } = useLearnerStore();
  const [inputText, setInputText] = useState('');
  const [messages, setMessages] = useState<Message[]>([
    {
      id: 'welcome',
      sender: 'ai',
      text: 'Salom! Men sizning shaxsiy ta’lim yo‘ldoshingiz — Yo‘lchi AI man. Savollaringizga tushunarli javob beraman, xatolaringizni pedagogik tahlil qilaman va sizga mos misollar yechib beraman. 🤖✨',
      time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
    },
  ]);
  const [isTyping, setIsTyping] = useState(false);
  const [lastFailedPrompt, setLastFailedPrompt] = useState<string | null>(null);
  const [aiStatus, setAiStatus] = useState<'unknown' | 'ready' | 'fallback' | 'unavailable'>(
    isSupabaseConfigured && !isDemoRuntimeActive() ? 'unknown' : 'fallback'
  );
  const mountedRef = useRef(true);
  const messagesContainerRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    mountedRef.current = true;
    return () => {
      mountedRef.current = false;
    };
  }, []);

  const scrollToBottom = useCallback(() => {
    const el = messagesContainerRef.current;
    if (el) {
      el.scrollTop = el.scrollHeight;
    }
  }, []);

  useEffect(() => {
    scrollToBottom();
  }, [messages, isTyping, scrollToBottom]);

  const quickPrompts = [
    'Qoidani sodda tushuntir 💡',
    'Yana bitta misol ber ✍️',
    'Mavzuni test qilib ko‘r 🎯',
    'Formulani ko‘rsat 📐',
  ];

  const currentCourseScore = activeCourse && profile?.scoresByCourse
    ? SkillScoringEngine.computeOverallScore(profile.scoresByCourse[activeCourse.id] || {})
    : null;

  const sendMessage = useCallback(
    async (textToSend?: string) => {
      const text = (textToSend ?? inputText).trim();
      if (!text || isTyping) return;

      const userMsg: Message = {
        id: `u_${Date.now()}`,
        sender: 'user',
        text,
        time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
      };

      setMessages((prev) => [...prev, userMsg]);
      setInputText('');
      setIsTyping(true);
      setLastFailedPrompt(null);

      try {
        const response = await aiService.askTutor({
          message: text,
          courseId: activeCourse?.id,
          topic: activeCourse?.title,
          learnerName: profile?.name,
          learnerScore: currentCourseScore ?? undefined,
        });

        if (!mountedRef.current) return;
        setAiStatus(response.isDeterministicFallback || !response.isAiGenerated ? 'fallback' : 'ready');
        setMessages((prev) => [
          ...prev,
          {
            id: `a_${Date.now()}`,
            sender: 'ai' as const,
            text: response.answer,
            time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
          },
        ]);
      } catch (err) {
        if (!mountedRef.current) return;
        setAiStatus('unavailable');
        const message =
          err instanceof GeminiAIServiceError
            ? err.message
            : 'Kechirasiz, javob berishda xatolik yuz berdi. Qayta urinib ko‘ring.';
        setLastFailedPrompt(text);
        setMessages((prev) => [
          ...prev,
          {
            id: `e_${Date.now()}`,
            sender: 'ai' as const,
            text: message,
            time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
            isError: true,
          },
        ]);
      } finally {
        if (mountedRef.current) setIsTyping(false);
      }
    },
    [inputText, isTyping, activeCourse?.id, activeCourse?.title, currentCourseScore, profile?.name]
  );

  const statusLabel = aiStatus === 'unknown'
    ? 'Holat tekshirilmoqda'
    : aiStatus === 'ready'
    ? 'AI faol'
    : aiStatus === 'fallback'
    ? 'Namunaviy rejim'
    : 'AI vaqtincha mavjud emas';
  const statusClass = aiStatus === 'unknown'
    ? 'bg-slate-100 text-slate-700 border-slate-200'
    : aiStatus === 'ready'
    ? 'bg-emerald-100 text-emerald-800 border-emerald-200'
    : aiStatus === 'fallback'
    ? 'bg-amber-100 text-amber-800 border-amber-200'
    : 'bg-rose-100 text-rose-800 border-rose-200';

  return (
    <div className="max-w-4xl mx-auto px-4 py-8 space-y-6">
      {/* Header bar */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-slate-200">
        <div className="flex items-center gap-4">
          <YolchiAIMascot size="sm" mood="explaining" />
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-xl sm:text-2xl font-black text-slate-900 tracking-tight">
                Yo‘lchi AI
              </h1>
               <span className={`px-2 py-0.5 text-[10px] font-extrabold uppercase rounded-full border flex items-center gap-1 ${statusClass}`}>
                 <span className={`w-1.5 h-1.5 rounded-full ${aiStatus === 'ready' ? 'bg-emerald-500' : aiStatus === 'fallback' ? 'bg-amber-500' : aiStatus === 'unknown' ? 'bg-slate-500' : 'bg-rose-500'}`} />
                 {statusLabel}
               </span>
             </div>
             <p className="text-xs text-slate-500">
               {activeCourse?.title || 'Kurs tanlanmagan'} bo‘yicha individual yordamchi
             </p>
          </div>
        </div>

        {onStartLesson && (
          <Button
            variant="gradient"
            size="sm"
            onClick={onStartLesson}
            rightIcon={<ArrowRight className="w-4 h-4" />}
          >
            Interaktiv darsga o‘tish
          </Button>
        )}
      </div>

      <Card className="p-4 border-indigo-100 bg-indigo-50/60 text-xs text-indigo-950">
        <strong>Joriy o‘quv konteksti:</strong>{' '}
        {activeCourse?.title || 'Kurs tanlanmagan'}
        {currentCourseScore !== null ? ` • o‘zlashtirish ${currentCourseScore}%` : ' • hali baho mavjud emas'}
      </Card>

      {/* Main Chat Box Container */}
      <Card className="p-4 sm:p-6 border-slate-200 shadow-md min-h-[500px] flex flex-col justify-between bg-gradient-to-b from-slate-50/50 via-white to-indigo-50/30">
        {/* Messages Stream */}
        <div ref={messagesContainerRef} className="space-y-4 overflow-y-auto max-h-[520px] pr-2">
          {messages.map((msg) => (
            <motion.div
              key={msg.id}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              className={`flex flex-col ${msg.sender === 'user' ? 'items-end' : 'items-start'}`}
            >
              <div
                className={`max-w-xl p-4 rounded-3xl text-sm leading-relaxed ${
                  msg.sender === 'user'
                    ? 'bg-gradient-to-r from-blue-600 to-indigo-600 text-white rounded-tr-xs shadow-md shadow-indigo-600/20'
                    : msg.isError
                    ? 'bg-rose-50 border border-rose-200 text-rose-800 rounded-tl-xs shadow-sm'
                    : 'bg-white border border-indigo-100/80 text-slate-800 rounded-tl-xs shadow-sm'
                }`}
              >
                <div className="flex items-center justify-between gap-3 mb-1 text-[11px] font-bold opacity-80">
                  <span>{msg.sender === 'ai' ? 'Yo‘lchi AI' : 'Siz'}</span>
                  <span className="text-[10px]">{msg.time}</span>
                </div>
                <p className="font-medium whitespace-pre-line">{msg.text}</p>
              </div>
            </motion.div>
          ))}

          {/* Typing indicator */}
          {isTyping && (
            <div className="flex items-center gap-2 text-xs font-bold text-indigo-600 p-2">
              <span className="w-2 h-2 rounded-full bg-indigo-500 animate-bounce" />
              <span className="w-2 h-2 rounded-full bg-indigo-500 animate-bounce [animation-delay:0.2s]" />
              <span className="w-2 h-2 rounded-full bg-indigo-500 animate-bounce [animation-delay:0.4s]" />
              <span>Yo‘lchi AI yozmoqda...</span>
            </div>
          )}

          {/* Retry affordance after an AI error */}
          {!isTyping && lastFailedPrompt && (
            <div className="flex items-center gap-2 p-2">
              <AlertTriangle className="w-4 h-4 text-amber-500" />
              <button
                type="button"
                onClick={() => sendMessage(lastFailedPrompt)}
                className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl border border-amber-200 bg-amber-50 hover:bg-amber-100 text-xs font-bold text-amber-800 transition-colors cursor-pointer"
              >
                <RefreshCw className="w-3.5 h-3.5" />
                Qayta urinish
              </button>
            </div>
          )}
        </div>

        {/* Bottom Actions & Input */}
        <div className="pt-4 mt-4 border-t border-slate-100 space-y-3">
          {/* Quick Prompts Chips */}
          <div className="flex flex-wrap items-center gap-2">
            {quickPrompts.map((chip, idx) => (
              <button
                key={idx}
                type="button"
                disabled={isTyping}
                onClick={() => sendMessage(chip)}
                className="px-3 py-1.5 rounded-xl border border-indigo-200 bg-white hover:bg-indigo-50 text-xs font-bold text-indigo-700 transition-all shadow-2xs hover:scale-102 cursor-pointer disabled:opacity-50 disabled:pointer-events-none"
              >
                {chip}
              </button>
            ))}
          </div>

          {/* Text Input Pill */}
          <form
            onSubmit={(e) => {
              e.preventDefault();
              sendMessage();
            }}
            className="flex items-center gap-2 bg-white p-1.5 pl-4 rounded-2xl border border-slate-300 shadow-sm focus-within:border-indigo-500 focus-within:ring-2 focus-within:ring-indigo-200"
          >
            <input
              type="text"
              value={inputText}
              onChange={(e) => setInputText(e.target.value)}
              placeholder="Yo‘lchi AI ga savol bering yoki formulani so‘rang..."
              aria-label="Yo‘lchi AI ga savol yozing"
              className="flex-1 text-sm bg-transparent border-0 outline-none text-slate-900 placeholder:text-slate-400 font-medium"
            />
            <Button
              type="submit"
              variant="gradient"
              size="sm"
              disabled={!inputText.trim() || isTyping}
              className="rounded-xl px-4 py-2"
            >
              <Send className="w-4 h-4" />
            </Button>
          </form>

           <p className="text-[10px] text-slate-400 flex items-center gap-1.5">
             <Sparkles className="w-3 h-3 text-indigo-400" />
             {aiStatus === 'unknown'
               ? 'AI holati birinchi so‘rovdan keyin tasdiqlanadi.'
               : aiStatus === 'fallback'
               ? 'Hozir namunaviy javoblar ko‘rsatilmoqda; haqiqiy AI javobi emas.'
               : aiStatus === 'unavailable'
               ? 'AI javobi olinmadi. Qayta urinish orqali yana tekshiring.'
               : 'Javoblar joriy kurs va o‘zlashtirish konteksti bilan AI modeliga yuboriladi.'}
           </p>
        </div>
      </Card>
    </div>
  );
};
