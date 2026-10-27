import React, { useState, useRef, useEffect, useCallback } from 'react';
import { motion } from 'framer-motion';
import {
  Send,
  Sparkles,
  ArrowRight,
  RefreshCw,
  AlertTriangle,
  Terminal,
  HelpCircle,
  Lightbulb,
  Compass,
} from 'lucide-react';
import { YolchiAIMascot } from '@/presentation/components/YolchiAIMascot';
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
      text: 'Salom! Men sizning shaxsiy ta’lim yo‘ldoshingiz — Yo‘lchi AI man. Savollaringizga tushunarli javob beraman, xatolaringizni pedagogik tahlil qilaman va sizga mos misollar yechib beraman.',
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
    { label: 'Qoidani sodda tushuntir', icon: Lightbulb },
    { label: 'Yana bitta misol ber', icon: Compass },
    { label: 'Formulani ko‘rsat', icon: Terminal },
    { label: 'Mavzuni test qilib ko‘r', icon: HelpCircle },
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
    ? 'TEKSHIRILMOQDA'
    : aiStatus === 'ready'
    ? 'ONLINE // GEMINI'
    : aiStatus === 'fallback'
    ? 'NAMUNAVIY MODEL'
    : 'OFFLINE';

  const statusDot = aiStatus === 'ready'
    ? 'bg-mint'
    : aiStatus === 'fallback'
    ? 'bg-amber-500'
    : aiStatus === 'unknown'
    ? 'bg-slate-400'
    : 'bg-coral';

  return (
    <div className="max-w-6xl mx-auto px-4 py-8 space-y-6">
      {/* Top Dossier Header */}
      <div className="flex flex-col md:flex-row md:items-end justify-between gap-4 pb-6 border-b border-[#e4ddce]">
        <div className="space-y-1">
          <div className="editorial-kicker">
            <span>PEDAGOGIK YORDAMCHI</span>
            <span>//</span>
            <span>LABORATORIYA</span>
          </div>
          <div className="flex items-center gap-3">
            <h1 className="font-display text-2xl sm:text-3xl font-extrabold text-[#10151f] tracking-tight">
              Yo‘lchi AI Mentor
            </h1>
            <span className="font-mono text-[10px] font-bold px-2.5 py-1 rounded bg-white border border-[#e4ddce] text-slate-700 flex items-center gap-1.5 shadow-2xs">
              <span className={`w-2 h-2 rounded-full ${statusDot} animate-pulse`} />
              {statusLabel}
            </span>
          </div>
          <p className="text-xs text-slate-500">
            {activeCourse ? (
              <span>
                Faol yo‘nalish: <strong className="text-slate-800">{activeCourse.title}</strong>{' '}
                {currentCourseScore !== null && `(O‘zlashtirish: ${currentCourseScore}%)`}
              </span>
            ) : (
              'Barcha umumiy fanlar bo‘yicha savol-javob konsoli'
            )}
          </p>
        </div>

        {onStartLesson && (
          <Button
            variant="primary"
            size="md"
            onClick={onStartLesson}
            rightIcon={<ArrowRight className="w-4 h-4" />}
            className="font-bold shrink-0"
          >
            Interaktiv darsga o‘tish
          </Button>
        )}
      </div>

      {/* Laboratory Two-Column Layout */}
      <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">
        {/* Left Telemetry Rail */}
        <div className="lg:col-span-1 space-y-4">
          {/* Active Context Card */}
          <div className="p-5 rounded-2xl bg-white border border-[#e4ddce] shadow-xs space-y-3">
            <div className="flex items-center gap-3">
              <YolchiAIMascot size="sm" mood="explaining" />
              <div>
                <span className="font-mono text-[10px] font-bold text-slate-400 uppercase tracking-widest block">
                  AGENT STATUSI
                </span>
                <span className="font-display text-sm font-bold text-[#10151f]">
                  Yo‘lchi v2.4
                </span>
              </div>
            </div>

            <div className="pt-2 border-t border-[#e4ddce] space-y-2">
              <div className="flex justify-between font-mono text-[11px]">
                <span className="text-slate-500">Kurs:</span>
                <span className="font-bold text-slate-800 text-right truncate max-w-[130px]">
                  {activeCourse?.title || 'Umumiy'}
                </span>
              </div>
              <div className="flex justify-between font-mono text-[11px]">
                <span className="text-slate-500">O‘zlashtirish:</span>
                <span className="font-bold text-brand-dark">
                  {currentCourseScore !== null ? `${currentCourseScore}%` : 'N/A'}
                </span>
              </div>
            </div>
          </div>

          {/* Quick Prompts Rail */}
          <div className="p-5 rounded-2xl bg-[#fbf9f4] border border-[#e4ddce] space-y-3">
            <span className="font-mono text-[10px] font-bold text-slate-500 uppercase tracking-wider block">
              Tezkor So‘rovlar
            </span>
            <div className="space-y-1.5">
              {quickPrompts.map((chip, idx) => {
                const Icon = chip.icon;
                return (
                  <button
                    key={idx}
                    type="button"
                    disabled={isTyping}
                    onClick={() => sendMessage(chip.label)}
                    className="w-full text-left p-2.5 rounded-xl border border-[#e4ddce] bg-white hover:bg-[#f5efe4] transition-all text-xs font-semibold text-slate-800 flex items-center gap-2 cursor-pointer disabled:opacity-50"
                  >
                    <Icon className="w-3.5 h-3.5 text-brand shrink-0" />
                    <span className="truncate">{chip.label}</span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Technical Info Docket */}
          <div className="p-4 rounded-xl border border-[#e4ddce] bg-white text-[11px] font-mono text-slate-500 space-y-1">
            <span className="font-bold text-slate-700 block uppercase">Pedagogik protokol:</span>
            <p className="font-sans text-[11px] text-slate-600 leading-relaxed">
              Javoblar Sokratik metod orqali to‘g‘ridan-to‘g‘ri yechim bermasdan, o‘quvchini fikrlashga yetaklaydi.
            </p>
          </div>
        </div>

        {/* Main Conversation Workbench */}
        <div className="lg:col-span-3 flex flex-col justify-between rounded-2xl border border-[#e4ddce] bg-white shadow-xs min-h-[580px] overflow-hidden">
          {/* Top Workbench Bar */}
          <div className="px-6 py-3 border-b border-[#e4ddce] bg-[#fbf9f4] flex items-center justify-between">
            <div className="flex items-center gap-2 font-mono text-xs text-slate-600 font-bold uppercase tracking-wider">
              <Terminal className="w-4 h-4 text-slate-500" />
              <span>DIALOK SEANSI // LIVE</span>
            </div>
            <span className="font-mono text-[10px] text-slate-400">
              {messages.length} ta xabar
            </span>
          </div>

          {/* Messages Stream */}
          <div ref={messagesContainerRef} className="p-6 space-y-4 overflow-y-auto max-h-[500px]">
            {messages.map((msg) => (
              <motion.div
                key={msg.id}
                initial={{ opacity: 0, y: 8 }}
                animate={{ opacity: 1, y: 0 }}
                className={`flex flex-col ${msg.sender === 'user' ? 'items-end' : 'items-start'}`}
              >
                <div
                  className={`max-w-2xl p-4 sm:p-5 rounded-xl text-sm leading-relaxed ${
                    msg.sender === 'user'
                      ? 'bg-[#10151f] text-white rounded-tr-xs shadow-xs'
                      : msg.isError
                      ? 'bg-coral/5 border border-coral/25 text-coral rounded-tl-xs shadow-2xs'
                      : 'bg-[#fbf9f4] border border-[#e4ddce] text-slate-900 rounded-tl-xs shadow-2xs'
                  }`}
                >
                  <div className="flex items-center justify-between gap-4 mb-2 font-mono text-[10px] font-bold tracking-wider uppercase opacity-75">
                    <span>{msg.sender === 'ai' ? 'YO‘LCHI AI' : 'TALABA'}</span>
                    <span className="font-mono-num">{msg.time}</span>
                  </div>
                  <p className="font-sans font-medium whitespace-pre-line text-xs sm:text-sm">
                    {msg.text}
                  </p>
                </div>
              </motion.div>
            ))}

            {/* Typing indicator */}
            {isTyping && (
              <div className="flex items-center gap-2 font-mono text-xs font-bold text-brand-dark p-3 bg-[#fbf9f4] rounded-xl border border-[#e4ddce] w-fit">
                <span className="w-2 h-2 rounded-full bg-brand animate-bounce" />
                <span className="w-2 h-2 rounded-full bg-brand animate-bounce [animation-delay:0.2s]" />
                <span className="w-2 h-2 rounded-full bg-brand animate-bounce [animation-delay:0.4s]" />
                <span>Yo‘lchi AI tahlil qilmoqda...</span>
              </div>
            )}

            {/* Retry affordance after an AI error */}
            {!isTyping && lastFailedPrompt && (
              <div className="flex items-center gap-2 p-2">
                <AlertTriangle className="w-4 h-4 text-amber-600" />
                <button
                  type="button"
                  onClick={() => sendMessage(lastFailedPrompt)}
                  className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg border border-amber-300 bg-amber-50 hover:bg-amber-100 font-mono text-xs font-bold text-amber-900 transition-colors cursor-pointer"
                >
                  <RefreshCw className="w-3.5 h-3.5" />
                  Qayta urinish
                </button>
              </div>
            )}
          </div>

          {/* Bottom Console Input */}
          <div className="p-4 sm:p-5 border-t border-[#e4ddce] bg-[#fbf9f4] space-y-3">
            <form
              onSubmit={(e) => {
                e.preventDefault();
                sendMessage();
              }}
              className="flex items-center gap-2 bg-white p-1.5 pl-4 rounded-xl border border-[#e4ddce] focus-within:border-[#10151f] focus-within:ring-2 focus-within:ring-[#10151f]/10 shadow-xs"
            >
              <input
                type="text"
                value={inputText}
                onChange={(e) => setInputText(e.target.value)}
                placeholder="Savol bering, masalani yozing yoki tushuntirish so‘rang..."
                aria-label="Yo‘lchi AI ga savol yozing"
                className="flex-1 text-sm bg-transparent border-0 outline-none text-slate-900 placeholder:text-slate-400 font-medium"
              />
              <Button
                type="submit"
                variant="primary"
                size="sm"
                disabled={!inputText.trim() || isTyping}
                className="rounded-lg px-4 py-2 font-bold"
              >
                <Send className="w-4 h-4" />
              </Button>
            </form>

            <div className="flex items-center justify-between font-mono text-[10px] text-slate-400">
              <span className="flex items-center gap-1.5">
                <Sparkles className="w-3 h-3 text-brand" />
                {aiStatus === 'ready'
                  ? 'Gemini 1.5 Pro orqali pedagogik tahlil faol'
                  : aiStatus === 'fallback'
                  ? 'Namunaviy deterministik o‘quv javoblari faol'
                  : 'Tarmoq holati tekshirilmoqda'}
              </span>
              <span>ENTER — YUBORISH</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
