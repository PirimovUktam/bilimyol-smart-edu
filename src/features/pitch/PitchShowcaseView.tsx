import React, { useState } from 'react';
import { motion } from 'framer-motion';
import {
  Sparkles,
  ArrowRight,
  Play,
  Users,
  Target,
  Cpu,
  Layers,
  ShieldCheck,
  Terminal,
  Code2,
  Smartphone,
  Globe,
  Bot,
  Zap,
  ChevronRight,
  MessageSquare,
  ExternalLink,
  FileText,
  Lightbulb,
  CheckCircle2,
  TrendingUp,
  Brain,
  Award,
  Send,
  Database,
  Lock,
  Compass,
  GraduationCap,
} from 'lucide-react';
import { Button } from '@/presentation/components/Button';
import { Badge } from '@/presentation/components/Badge';
import { BilimYolLogo } from '@/presentation/components/BilimYolLogo';
import { YolchiAIMascot } from '@/presentation/components/YolchiAIMascot';

interface PitchShowcaseViewProps {
  onNavigateDemo: () => void;
  onNavigateApp: () => void;
  onNavigateAiTutor: () => void;
}

export const PitchShowcaseView: React.FC<PitchShowcaseViewProps> = ({
  onNavigateDemo,
  onNavigateApp,
  onNavigateAiTutor,
}) => {
  // Roadmap active stage
  const [activeRoadmapStage, setActiveRoadmapStage] = useState<'idea' | 'prototype' | 'mvp' | 'launched'>('mvp');

  // Interactive Chatbot Emulator state
  const [chatMessages, setChatMessages] = useState<Array<{ role: 'user' | 'assistant'; text: string; time: string }>>([
    {
      role: 'assistant',
      text: 'Assalomu alaykum! Men Yo‘lchi AI — sizning shaxsiy repetitoringizman. Har qanday fan, qiyin formula yoki xatolik haqida savol bering!',
      time: '18:20',
    },
  ]);
  const [inputQuestion, setInputQuestion] = useState('');
  const [isBotThinking, setIsBotThinking] = useState(false);

  // API tab state
  const [activeApiTab, setActiveApiTab] = useState<'diagnostics' | 'lessons' | 'scoring'>('diagnostics');

  // Sample questions for the AI bot
  const samplePrompts = [
    {
      q: 'Kasrlarni qo‘shishda umumiy maxrajni qanday oson topish mumkin?',
      a: 'Kasrlarni qo‘shishda umumiy maxraj — bu ikkala maxrajning EKUKi (Eng Kichik Umumiy Karralisi)dir. Masalan, 1/4 va 1/6 da umumiy maxraj 12 bo‘ladi (4*3 va 6*2). Shunda: 3/12 + 2/12 = 5/12. Qaysi misolni yechishda qiynalyapsiz, birgalikda tahlil qilamizmi? 💡',
    },
    {
      q: 'Present Perfect va Past Simple o‘rtasidagi farq nima?',
      a: 'Asosiy farq — natijaning hozirgi vaqtga bog‘liqligi! "I lost my key" (Past Simple) — kalit o‘tmishda yo‘qolgan, hozir topilgan bo‘lishi mumkin. "I have lost my key" (Present Perfect) — kalit hozir ham yo‘q va uyga kira olmayapman! BilimYo‘l ingliz tili darslarida buni audio vaziyatlar orqali mustahkamlaymiz. 🇬🇧',
    },
    {
      q: 'Nega mening funksiyalar bo‘yicha bilim darajam 38% bo‘lib qoldi?',
      a: 'Diagnostikada "Argument qiymati bo‘yicha funksiyani topish" savolida xato qayd etildi. Hech xavotir olmang! Men siz uchun aynan shu bo‘shliqni to‘ldiruvchi 3 qadamli maxsus dars va grafikli model tayyorlab qo‘ydim. Darsni boshlaymizmi? 📐',
    },
  ];

  const handleSendQuestion = (textToSend?: string) => {
    const q = textToSend || inputQuestion;
    if (!q.trim()) return;

    const userMsg = {
      role: 'user' as const,
      text: q,
      time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
    };

    setChatMessages((prev) => [...prev, userMsg]);
    setInputQuestion('');
    setIsBotThinking(true);

    setTimeout(() => {
      const matchedSample = samplePrompts.find((p) => p.q === q);
      const botResponse = matchedSample
        ? matchedSample.a
        : `Ajoyib savol! BilimYo‘l Smart Edu ushbu mavzu bo‘yicha maxsus pedagogik traektoriya ishlab chiqqan. Gemini 2.5 Flash tahlili bo‘yicha, "${q}" masalasi 3 ta asosiy qadam orqali tushuntiriladi. Jonli darsni sinab ko‘rish uchun "/demo" sahifasiga o‘tishingiz mumkin! 🚀`;

      setChatMessages((prev) => [
        ...prev,
        {
          role: 'assistant',
          text: botResponse,
          time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        },
      ]);
      setIsBotThinking(false);
    }, 700);
  };

  return (
    <div className="min-h-screen bg-[#0A0D14] text-white selection:bg-cyan-500 selection:text-black">
      {/* Background Decorative Mesh Gradients */}
      <div className="fixed inset-0 pointer-events-none overflow-hidden z-0">
        <div className="absolute -top-40 -left-40 w-96 h-96 bg-indigo-600/20 rounded-full blur-[140px]" />
        <div className="absolute top-1/3 -right-40 w-[500px] h-[500px] bg-cyan-500/15 rounded-full blur-[160px]" />
        <div className="absolute bottom-10 left-1/4 w-[450px] h-[450px] bg-emerald-500/10 rounded-full blur-[150px]" />
      </div>

      <div className="relative z-10">
        {/* 1. TOP PITCH DAY 3.0 BANNER */}
        <div className="bg-gradient-to-r from-indigo-900/90 via-purple-900/90 to-cyan-900/90 border-b border-indigo-500/30 py-2.5 px-4 text-center">
          <div className="max-w-7xl mx-auto flex flex-wrap items-center justify-between gap-3 text-xs">
            <div className="flex items-center gap-2 mx-auto sm:mx-0">
              <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-cyan-400 text-slate-950 font-black tracking-wide uppercase text-[10px]">
                <Sparkles className="w-3 h-3" /> PITCH DAY 3.0
              </span>
              <span className="text-slate-200 font-semibold">
                AIFU • IT Park • Alibaba • Inno Technopark Saralash Bosqichi
              </span>
            </div>
            <div className="flex items-center gap-2 mx-auto sm:mx-0">
              <span className="text-emerald-400 font-bold flex items-center gap-1">
                <span className="w-2 h-2 rounded-full bg-emerald-400 animate-ping inline-block" />
                1-Bosqich: Onlayn Saralash (11-oktyabr 23:59:59)
              </span>
              <button
                onClick={onNavigateDemo}
                className="underline hover:text-cyan-300 font-extrabold cursor-pointer ml-2"
              >
                /demo sahifasi →
              </button>
            </div>
          </div>
        </div>

        {/* 2. HERO SECTION */}
        <section className="pt-16 pb-20 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto text-center">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5 }}
            className="space-y-6 max-w-4xl mx-auto"
          >
            <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-white/5 border border-white/10 backdrop-blur-md text-cyan-400 text-xs font-bold shadow-inner">
              <Sparkles className="w-3.5 h-3.5 text-cyan-400" />
              <span>O‘zbekiston EdTech Bozorida 1-Raqamli AI Ta’lim Platformasi</span>
            </div>

            <h1 className="text-4xl sm:text-6xl lg:text-7xl font-black tracking-tight leading-[1.1] text-transparent bg-clip-text bg-gradient-to-r from-white via-slate-100 to-cyan-300">
              BilimYo‘l Smart Edu
            </h1>

            <p className="text-lg sm:text-2xl text-slate-300 font-medium max-w-3xl mx-auto leading-relaxed">
              Har bir o‘quvchi uchun <span className="text-cyan-400 font-bold">individual sun’iy intellekt repetitori</span> va bo‘shliqlarni yo‘qotuvchi adaptiv ta’lim traektoriyasi.
            </p>

            <div className="flex flex-wrap items-center justify-center gap-4 pt-4">
              <Button
                variant="primary"
                size="lg"
                onClick={onNavigateDemo}
                className="bg-gradient-to-r from-cyan-500 to-blue-600 hover:from-cyan-400 hover:to-blue-500 text-white font-extrabold shadow-lg shadow-cyan-500/25 px-8 py-4 text-base rounded-2xl flex items-center gap-3 cursor-pointer"
              >
                <Play className="w-5 h-5 fill-current" />
                Demo Sahifasini Ko‘rish (/demo)
              </Button>

              <Button
                variant="outline"
                size="lg"
                onClick={onNavigateApp}
                className="border-white/20 bg-white/5 hover:bg-white/10 text-white font-bold px-8 py-4 text-base rounded-2xl flex items-center gap-2 cursor-pointer backdrop-blur-md"
              >
                <Zap className="w-5 h-5 text-amber-400" />
                Jonli Prototipni Ishga Tushirish
              </Button>
            </div>

            {/* Quick Metrics Bar */}
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 pt-12 max-w-4xl mx-auto">
              <div className="p-4 rounded-2xl bg-white/[0.03] border border-white/10 backdrop-blur-md">
                <div className="text-2xl sm:text-3xl font-black text-cyan-400">6.5M+</div>
                <div className="text-xs text-slate-400 mt-1 font-semibold">Maktab o‘quvchilari (O‘zbekiston)</div>
              </div>
              <div className="p-4 rounded-2xl bg-white/[0.03] border border-white/10 backdrop-blur-md">
                <div className="text-2xl sm:text-3xl font-black text-emerald-400">100%</div>
                <div className="text-xs text-slate-400 mt-1 font-semibold">Adaptiv Diagnostika & Xarita</div>
              </div>
              <div className="p-4 rounded-2xl bg-white/[0.03] border border-white/10 backdrop-blur-md">
                <div className="text-2xl sm:text-3xl font-black text-indigo-400">&lt;1.5s</div>
                <div className="text-xs text-slate-400 mt-1 font-semibold">Yo‘lchi AI O‘rtacha Javob Tezligi</div>
              </div>
              <div className="p-4 rounded-2xl bg-white/[0.03] border border-white/10 backdrop-blur-md">
                <div className="text-2xl sm:text-3xl font-black text-purple-400">MVP</div>
                <div className="text-xs text-slate-400 mt-1 font-semibold">Ishlayotgan Web & Flutter Ilova</div>
              </div>
            </div>
          </motion.div>
        </section>

        {/* 3. SECTION 1: MUAMMO → YECHIM (PROBLEM → SOLUTION) */}
        <section className="py-16 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-white/10">
          <div className="text-center max-w-3xl mx-auto mb-14">
            <span className="text-cyan-400 text-xs font-black tracking-widest uppercase">1. ASOSIY BOSQICH</span>
            <h2 className="text-3xl sm:text-4xl font-extrabold text-white mt-2">
              Muammo <span className="text-slate-500">→</span> Bizning Yechim
            </h2>
            <p className="text-slate-400 text-sm sm:text-base mt-3">
              O‘zbekiston ta’lim tizimidagi eng o‘tkir to‘siqlarni sun’iy intellekt va adaptiv pedagogika orqali hal qilamiz.
            </p>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
            {/* The Problem Side */}
            <div className="p-8 rounded-3xl bg-rose-950/20 border border-rose-500/30 backdrop-blur-md relative overflow-hidden space-y-6">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-rose-500/20 text-rose-400 flex items-center justify-center font-black">
                  ✕
                </div>
                <div>
                  <h3 className="text-xl font-extrabold text-rose-300">Kritik Muammo</h3>
                  <p className="text-xs text-rose-200/70">An’anaviy ta’limdagi tizimli bo‘shliqlar</p>
                </div>
              </div>

              <div className="space-y-4">
                <div className="p-4 rounded-2xl bg-black/40 border border-rose-500/20">
                  <h4 className="font-bold text-sm text-white flex items-center gap-2">
                    <span className="text-rose-400 font-black">1.</span> 35-40 talik ommaviy sinflar
                  </h4>
                  <p className="text-xs text-slate-300 mt-1 leading-relaxed">
                    O‘qituvchi 45 daqiqada har bir o‘quvchiga 1 daqiqa ham vaqt ajrata olmaydi. Barcha o‘quvchilar bitta sur’atda o‘qitiladi.
                  </p>
                </div>

                <div className="p-4 rounded-2xl bg-black/40 border border-rose-500/20">
                  <h4 className="font-bold text-sm text-white flex items-center gap-2">
                    <span className="text-rose-400 font-black">2.</span> Qimmat repetitorlar (500K - 1.5M so‘m/oy)
                  </h4>
                  <p className="text-xs text-slate-300 mt-1 leading-relaxed">
                    Oilalar byudjetiga og‘ir. Qishloq va tumanlarda esa malakali, ixtisoslashgan ustozlar umuman yetishmaydi.
                  </p>
                </div>

                <div className="p-4 rounded-2xl bg-black/40 border border-rose-500/20">
                  <h4 className="font-bold text-sm text-white flex items-center gap-2">
                    <span className="text-rose-400 font-black">3.</span> Quruq, tushunarsiz testlar
                  </h4>
                  <p className="text-xs text-slate-300 mt-1 leading-relaxed">
                    O‘quvchi xato qilganda nega xato qilganini tushuntiradigan hech kim yo‘q. Faqat quruq "noto‘g‘ri" degan ball qo‘yiladi.
                  </p>
                </div>

                <div className="p-4 rounded-2xl bg-black/40 border border-rose-500/20">
                  <h4 className="font-bold text-sm text-white flex items-center gap-2">
                    <span className="text-rose-400 font-black">4.</span> Bo‘shliqlarning to‘planib borishi
                  </h4>
                  <p className="text-xs text-slate-300 mt-1 leading-relaxed">
                    5-sinfda kasrlarni tushunmagan o‘quvchi 8-sinfda algebra va geometriyani butunlay o‘zlashtira olmay qoladi.
                  </p>
                </div>
              </div>
            </div>

            {/* The Solution Side */}
            <div className="p-8 rounded-3xl bg-cyan-950/20 border border-cyan-500/40 backdrop-blur-md relative overflow-hidden space-y-6">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-cyan-500/20 text-cyan-400 flex items-center justify-center font-black">
                  ✓
                </div>
                <div>
                  <h3 className="text-xl font-extrabold text-cyan-300">BilimYo‘l Yechimi</h3>
                  <p className="text-xs text-cyan-200/70">Sun’iy intellektga asoslangan shaxsiy ekotizim</p>
                </div>
              </div>

              <div className="space-y-4">
                <div className="p-4 rounded-2xl bg-black/40 border border-cyan-500/30">
                  <h4 className="font-bold text-sm text-white flex items-center gap-2">
                    <span className="text-cyan-400 font-black">1.</span> 100% Adaptiv Diagnostika
                  </h4>
                  <p className="text-xs text-slate-300 mt-1 leading-relaxed">
                    8 ta moslashuvchan test orqali o‘quvchining har bir ko‘nikmasi (Algebra, Tenglama, Funksiya, Lug‘at va h.k.) 0-100% shkalada aniqlanadi.
                  </p>
                </div>

                <div className="p-4 rounded-2xl bg-black/40 border border-cyan-500/30">
                  <h4 className="font-bold text-sm text-white flex items-center gap-2">
                    <span className="text-cyan-400 font-black">2.</span> "Yo‘lchi AI" Do‘stona Mentori
                  </h4>
                  <p className="text-xs text-slate-300 mt-1 leading-relaxed">
                    Google Gemini 2.5 Flash bilan qurollangan mentor bolaga tayyor javobni emas, xatoning tub sababini pedagogik uslubda tushuntiradi.
                  </p>
                </div>

                <div className="p-4 rounded-2xl bg-black/40 border border-cyan-500/30">
                  <h4 className="font-bold text-sm text-white flex items-center gap-2">
                    <span className="text-cyan-400 font-black">3.</span> Individual 3 Qadamli Darslar
                  </h4>
                  <p className="text-xs text-slate-300 mt-1 leading-relaxed">
                    Zaif nuqta aniqlanishi bilan AI u uchun maxsus dars yaratadi: 1) Qisqa tushuncha; 2) Vizual model / audio to‘lqin; 3) Interaktiv mustahkamlash.
                  </p>
                </div>

                <div className="p-4 rounded-2xl bg-black/40 border border-cyan-500/30">
                  <h4 className="font-bold text-sm text-white flex items-center gap-2">
                    <span className="text-cyan-400 font-black">4.</span> Hamyonbop va Har Doim Yoningizda
                  </h4>
                  <p className="text-xs text-slate-300 mt-1 leading-relaxed">
                    Oyiga atigi 49,000 so‘m. Web va Flutter Mobile orqali har qanday telefonda 24/7 ishlaydi.
                  </p>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* 4. SECTION 2: JAMOA (TEAM) */}
        <section className="py-16 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-white/10">
          <div className="text-center max-w-3xl mx-auto mb-14">
            <span className="text-cyan-400 text-xs font-black tracking-widest uppercase">2. ASOSIY BOSQICH</span>
            <h2 className="text-3xl sm:text-4xl font-extrabold text-white mt-2">
              Bizning Jamoa va Texnologik Kuch
            </h2>
            <p className="text-slate-400 text-sm sm:text-base mt-3">
              Ta’lim metodologiyasi, ilg‘or AI arxitekturasi va zamonaviy mobil dasturlashni birlashtirgan jamoa.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            {/* Member 1: Founder & Architect */}
            <div className="p-6 rounded-3xl bg-white/[0.03] border border-white/10 backdrop-blur-md flex flex-col justify-between hover:border-cyan-500/40 transition-all group">
              <div>
                <div className="w-16 h-16 rounded-2xl bg-gradient-to-tr from-cyan-500 to-blue-600 flex items-center justify-center text-white text-2xl font-black mb-4 shadow-lg shadow-cyan-500/20">
                  OP
                </div>
                <h3 className="text-lg font-bold text-white group-hover:text-cyan-400 transition-colors">
                  O‘ktam Pirimov
                </h3>
                <p className="text-xs text-cyan-400 font-semibold mb-3">Founder & Lead Systems Architect</p>
                <p className="text-xs text-slate-300 leading-relaxed">
                  Loyiha me’mori, Full-Stack va AI tizimlarining uzviy sinxronligi, pedagogik yo‘l xaritasi muallifi.
                </p>

                <div className="mt-4 pt-4 border-t border-white/5 space-y-1.5">
                  <div className="text-[11px] text-slate-400 font-bold uppercase tracking-wider">Ko‘nikmalar:</div>
                  <div className="flex flex-wrap gap-1 text-[10px]">
                    <span className="px-2 py-0.5 rounded bg-white/5 text-slate-300">Full-Stack Architecture</span>
                    <span className="px-2 py-0.5 rounded bg-white/5 text-slate-300">AI Prompt Tuning</span>
                    <span className="px-2 py-0.5 rounded bg-white/5 text-slate-300">Clean Architecture</span>
                  </div>
                </div>
              </div>

              <div className="mt-6 flex items-center gap-3 pt-4 border-t border-white/10 text-xs">
                <a
                  href="https://github.com/pirimovuktam"
                  target="_blank"
                  rel="noreferrer"
                  className="text-slate-400 hover:text-white flex items-center gap-1 font-bold"
                >
                  <ExternalLink className="w-3.5 h-3.5" /> GitHub
                </a>
                <a
                  href="https://t.me/pirimovuktam"
                  target="_blank"
                  rel="noreferrer"
                  className="text-cyan-400 hover:underline flex items-center gap-1 font-bold"
                >
                  <MessageSquare className="w-3.5 h-3.5" /> Telegram
                </a>
              </div>
            </div>

            {/* Member 2: AI & LLM Systems */}
            <div className="p-6 rounded-3xl bg-white/[0.03] border border-white/10 backdrop-blur-md flex flex-col justify-between hover:border-purple-500/40 transition-all group">
              <div>
                <div className="w-16 h-16 rounded-2xl bg-gradient-to-tr from-purple-500 to-indigo-600 flex items-center justify-center text-white text-2xl font-black mb-4 shadow-lg shadow-purple-500/20">
                  <Bot className="w-8 h-8" />
                </div>
                <h3 className="text-lg font-bold text-white group-hover:text-purple-400 transition-colors">
                  AI & Pedagogical Engine
                </h3>
                <p className="text-xs text-purple-400 font-semibold mb-3">Yo‘lchi AI Core Development</p>
                <p className="text-xs text-slate-300 leading-relaxed">
                  Google Gemini 2.5 Flash Edge Function optimizatsiyasi, pedagogik gallyutsinatsiyalarga qarshi qat’iy guardrails.
                </p>

                <div className="mt-4 pt-4 border-t border-white/5 space-y-1.5">
                  <div className="text-[11px] text-slate-400 font-bold uppercase tracking-wider">Ko‘nikmalar:</div>
                  <div className="flex flex-wrap gap-1 text-[10px]">
                    <span className="px-2 py-0.5 rounded bg-white/5 text-slate-300">Gemini 2.5 API</span>
                    <span className="px-2 py-0.5 rounded bg-white/5 text-slate-300">Deno Edge Runtime</span>
                    <span className="px-2 py-0.5 rounded bg-white/5 text-slate-300">Adaptive Scoring Engine</span>
                  </div>
                </div>
              </div>

              <div className="mt-6 flex items-center gap-3 pt-4 border-t border-white/10 text-xs">
                <span className="text-slate-400 font-bold">Latency: &lt;1.5s</span>
                <span className="text-emerald-400 font-bold">100% Guarded</span>
              </div>
            </div>

            {/* Member 3: Mobile & Frontend */}
            <div className="p-6 rounded-3xl bg-white/[0.03] border border-white/10 backdrop-blur-md flex flex-col justify-between hover:border-blue-500/40 transition-all group">
              <div>
                <div className="w-16 h-16 rounded-2xl bg-gradient-to-tr from-blue-500 to-cyan-600 flex items-center justify-center text-white text-2xl font-black mb-4 shadow-lg shadow-blue-500/20">
                  <Smartphone className="w-8 h-8" />
                </div>
                <h3 className="text-lg font-bold text-white group-hover:text-blue-400 transition-colors">
                  Mobile & Client Engineering
                </h3>
                <p className="text-xs text-blue-400 font-semibold mb-3">Flutter & React 19 Development</p>
                <p className="text-xs text-slate-300 leading-relaxed">
                  Web va Mobile platformalari o‘rtasidagi 100% simmetriya, Riverpod va Zustand holat boshqaruvi.
                </p>

                <div className="mt-4 pt-4 border-t border-white/5 space-y-1.5">
                  <div className="text-[11px] text-slate-400 font-bold uppercase tracking-wider">Ko‘nikmalar:</div>
                  <div className="flex flex-wrap gap-1 text-[10px]">
                    <span className="px-2 py-0.5 rounded bg-white/5 text-slate-300">Flutter 3.x</span>
                    <span className="px-2 py-0.5 rounded bg-white/5 text-slate-300">React 19 + TypeScript</span>
                    <span className="px-2 py-0.5 rounded bg-white/5 text-slate-300">Tailwind CSS</span>
                  </div>
                </div>
              </div>

              <div className="mt-6 flex items-center gap-3 pt-4 border-t border-white/10 text-xs">
                <span className="text-slate-400 font-bold">210 Web Tests</span>
                <span className="text-emerald-400 font-bold">41 Flutter Tests</span>
              </div>
            </div>

            {/* Member 4: Methodology & Standards */}
            <div className="p-6 rounded-3xl bg-white/[0.03] border border-white/10 backdrop-blur-md flex flex-col justify-between hover:border-emerald-500/40 transition-all group">
              <div>
                <div className="w-16 h-16 rounded-2xl bg-gradient-to-tr from-emerald-500 to-teal-600 flex items-center justify-center text-white text-2xl font-black mb-4 shadow-lg shadow-emerald-500/20">
                  <GraduationCap className="w-8 h-8" />
                </div>
                <h3 className="text-lg font-bold text-white group-hover:text-emerald-400 transition-colors">
                  Ta’lim & Metodologiya
                </h3>
                <p className="text-xs text-emerald-400 font-semibold mb-3">Curriculum & Pedagogical Alignment</p>
                <p className="text-xs text-slate-300 leading-relaxed">
                  Davlat ta’lim standarti, DTM va Milliy sertifikat talablariga mos ko‘nikmalar matritsasi (Knowledge Graph).
                </p>

                <div className="mt-4 pt-4 border-t border-white/5 space-y-1.5">
                  <div className="text-[11px] text-slate-400 font-bold uppercase tracking-wider">Ko‘nikmalar:</div>
                  <div className="flex flex-wrap gap-1 text-[10px]">
                    <span className="px-2 py-0.5 rounded bg-white/5 text-slate-300">Bloom Taxonomy</span>
                    <span className="px-2 py-0.5 rounded bg-white/5 text-slate-300">Item Response Theory</span>
                    <span className="px-2 py-0.5 rounded bg-white/5 text-slate-300">Milliy Darsliklar</span>
                  </div>
                </div>
              </div>

              <div className="mt-6 flex items-center gap-3 pt-4 border-t border-white/10 text-xs">
                <span className="text-slate-400 font-bold">Fanlar: Math & Eng</span>
                <span className="text-emerald-400 font-bold">100% Mos</span>
              </div>
            </div>
          </div>

          {/* Technology stack pill carousel */}
          <div className="mt-12 p-6 rounded-3xl bg-black/40 border border-white/10 flex flex-wrap items-center justify-center gap-4">
            <span className="text-xs text-slate-400 font-bold">Foydalanilgan texnologiyalar:</span>
            {[
              'Google Gemini 2.5 Flash',
              'React 19',
              'TypeScript',
              'Flutter (Mobile)',
              'Supabase PostgreSQL',
              'Row Level Security (RLS)',
              'Deno Edge Functions',
              'Tailwind CSS',
              'Vitest',
              'Vite 8',
            ].map((tech) => (
              <span
                key={tech}
                className="px-3 py-1.5 rounded-xl bg-white/5 border border-white/10 text-xs font-semibold text-slate-200"
              >
                {tech}
              </span>
            ))}
          </div>
        </section>

        {/* 5. SECTION 3: NEGA BIZNING JAMOA BU MUAMMONI HAL QILA OLADI? */}
        <section className="py-16 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-white/10">
          <div className="text-center max-w-3xl mx-auto mb-14">
            <span className="text-cyan-400 text-xs font-black tracking-widest uppercase">3. ASOSIY BOSQICH</span>
            <h2 className="text-3xl sm:text-4xl font-extrabold text-white mt-2">
              Nima Uchun Aynan Bizning Jamoa?
            </h2>
            <p className="text-slate-400 text-sm sm:text-base mt-3">
              G‘oya va slaydlar bosqichidan o‘tib, real ishlayotgan mahsulotga ega ekanligimiz — bizning asosiy ustunligimizdir.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            <div className="p-6 rounded-3xl bg-gradient-to-b from-white/[0.04] to-transparent border border-white/10">
              <div className="w-12 h-12 rounded-2xl bg-cyan-500/10 text-cyan-400 flex items-center justify-center mb-4">
                <CheckCircle2 className="w-6 h-6" />
              </div>
              <h3 className="text-lg font-bold text-white mb-2">100% Ishlayotgan MVP</h3>
              <p className="text-xs text-slate-300 leading-relaxed">
                Biz quruq taqdimot bilan kelmadik. Web va Flutter Mobile ilovamiz to‘liq tayyor, testlar bilan qoplangan va jonli rejimda ishlaydi.
              </p>
            </div>

            <div className="p-6 rounded-3xl bg-gradient-to-b from-white/[0.04] to-transparent border border-white/10">
              <div className="w-12 h-12 rounded-2xl bg-indigo-500/10 text-indigo-400 flex items-center justify-center mb-4">
                <Brain className="w-6 h-6" />
              </div>
              <h3 className="text-lg font-bold text-white mb-2">Haqiqiy Pedagogik AI</h3>
              <p className="text-xs text-slate-300 leading-relaxed">
                Oddiy ChatGPT wrapper emas. Tizim bolaga tayyor javobni aytib dangasa qilmaydi, balki ko‘nikmalar grafigi bo‘yicha tushuntiradi.
              </p>
            </div>

            <div className="p-6 rounded-3xl bg-gradient-to-b from-white/[0.04] to-transparent border border-white/10">
              <div className="w-12 h-12 rounded-2xl bg-emerald-500/10 text-emerald-400 flex items-center justify-center mb-4">
                <ShieldCheck className="w-6 h-6" />
              </div>
              <h3 className="text-lg font-bold text-white mb-2">Server Anti-Cheat Xavfsizligi</h3>
              <p className="text-xs text-slate-300 leading-relaxed">
                Ballar, ko‘nikmalar va XP lar to‘liq server-side hisoblanadi. O‘quvchi brauzer orqali javoblarni ko‘rib ololmaydi yoki ballni soxtalashtira olmaydi.
              </p>
            </div>

            <div className="p-6 rounded-3xl bg-gradient-to-b from-white/[0.04] to-transparent border border-white/10">
              <div className="w-12 h-12 rounded-2xl bg-purple-500/10 text-purple-400 flex items-center justify-center mb-4">
                <Globe className="w-6 h-6" />
              </div>
              <h3 className="text-lg font-bold text-white mb-2">O‘zbekiston Bozoriga Mos</h3>
              <p className="text-xs text-slate-300 leading-relaxed">
                O‘zbek tili, milliy darsliklar, DTM standartlari va mahalliy o‘quvchilar mentalitetiga to‘liq moslashtirilgan yagona aqlli EdTech tizimi.
              </p>
            </div>
          </div>
        </section>

        {/* 6. SECTION 4: YO'L XARITASI (IDEA → PROTOTYPE → MVP → LAUNCHED) */}
        <section className="py-16 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-white/10">
          <div className="text-center max-w-3xl mx-auto mb-14">
            <span className="text-cyan-400 text-xs font-black tracking-widest uppercase">4. ASOSIY BOSQICH</span>
            <h2 className="text-3xl sm:text-4xl font-extrabold text-white mt-2">
              Yo‘l Xaritasi (Roadmap)
            </h2>
            <p className="text-slate-400 text-sm sm:text-base mt-3">
              G‘oyadan boshlab to to‘liq ishga tushirishgacha bo‘lgan rivojlanish bosqichlarimiz.
            </p>
          </div>

          {/* Interactive Stage Selector */}
          <div className="flex flex-wrap items-center justify-center gap-3 mb-10">
            {[
              { id: 'idea', label: '1. IDEA', badge: '100% Bajarildi', color: 'border-slate-500 text-slate-300' },
              { id: 'prototype', label: '2. PROTOTYPE', badge: '100% Bajarildi', color: 'border-blue-500 text-blue-400' },
              { id: 'mvp', label: '3. MVP (HOZIRGI)', badge: 'Jonli & Testlangan', color: 'border-cyan-500 text-cyan-400' },
              { id: 'launched', label: '4. LAUNCHED & SCALE', badge: 'Amalga oshirilmoqda', color: 'border-purple-500 text-purple-400' },
            ].map((stage) => (
              <button
                key={stage.id}
                onClick={() => setActiveRoadmapStage(stage.id as any)}
                className={`px-5 py-3 rounded-2xl text-xs sm:text-sm font-extrabold transition-all cursor-pointer flex items-center gap-2 ${
                  activeRoadmapStage === stage.id
                    ? 'bg-cyan-500 text-slate-950 shadow-lg shadow-cyan-500/25 scale-105'
                    : 'bg-white/5 hover:bg-white/10 text-slate-300 border border-white/10'
                }`}
              >
                <span>{stage.label}</span>
                <span
                  className={`text-[10px] px-2 py-0.5 rounded-full ${
                    activeRoadmapStage === stage.id ? 'bg-black/20 text-slate-900' : 'bg-white/10 text-slate-400'
                  }`}
                >
                  {stage.badge}
                </span>
              </button>
            ))}
          </div>

          {/* Stage Details Card */}
          <div className="p-8 sm:p-10 rounded-3xl bg-white/[0.03] border border-white/15 backdrop-blur-md max-w-4xl mx-auto">
            {activeRoadmapStage === 'idea' && (
              <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="space-y-4">
                <div className="flex items-center justify-between">
                  <h3 className="text-xl font-black text-slate-200">1-Bosqich: IDEA (G‘oya & Bozor Tadqiqoti)</h3>
                  <span className="px-3 py-1 rounded-full bg-emerald-500/20 text-emerald-400 text-xs font-bold">100% Yakunlangan</span>
                </div>
                <p className="text-slate-300 text-sm leading-relaxed">
                  500 dan ortiq maktab o‘quvchilari va ota-onalar o‘rtasida so‘rovnomalar o‘tkazildi. Matematika va Ingliz tilidagi bo‘shliqlarni aniqlash modeli tuzildi.
                </p>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-2">
                  <div className="p-3 rounded-xl bg-black/30 border border-white/5 text-xs text-slate-300 flex items-center gap-2">
                    <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0" /> Bloom taksonomiyasiga asoslangan model
                  </div>
                  <div className="p-3 rounded-xl bg-black/30 border border-white/5 text-xs text-slate-300 flex items-center gap-2">
                    <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0" /> O‘zbekiston ta’lim tizimi bo‘shliqlari auditi
                  </div>
                </div>
              </motion.div>
            )}

            {activeRoadmapStage === 'prototype' && (
              <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="space-y-4">
                <div className="flex items-center justify-between">
                  <h3 className="text-xl font-black text-blue-300">2-Bosqich: PROTOTYPE (Algoritm & Dastlabki AI)</h3>
                  <span className="px-3 py-1 rounded-full bg-emerald-500/20 text-emerald-400 text-xs font-bold">100% Yakunlangan</span>
                </div>
                <p className="text-slate-300 text-sm leading-relaxed">
                  Yo‘lchi AI uchun Gemini promptlari sinovdan o‘tkazildi. 50 ta pilot o‘quvchi bilan adaptiv savollar zanjiri sinab ko‘rildi.
                </p>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-2">
                  <div className="p-3 rounded-xl bg-black/30 border border-white/5 text-xs text-slate-300 flex items-center gap-2">
                    <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0" /> Dastlabki savollar matritsasi va scoring
                  </div>
                  <div className="p-3 rounded-xl bg-black/30 border border-white/5 text-xs text-slate-300 flex items-center gap-2">
                    <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0" /> Yo‘lchi AI pedagogik reaksiyasi testi
                  </div>
                </div>
              </motion.div>
            )}

            {activeRoadmapStage === 'mvp' && (
              <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="space-y-4">
                <div className="flex items-center justify-between">
                  <h3 className="text-xl font-black text-cyan-300">3-Bosqich: MVP (To‘liq Ishlayotgan Tizim — HOZIRDA)</h3>
                  <span className="px-3 py-1 rounded-full bg-cyan-500/20 text-cyan-400 text-xs font-bold">100% Jonli & Testlangan</span>
                </div>
                <p className="text-slate-300 text-sm leading-relaxed">
                  Web SPA (React 19) va Mobil (Flutter) ilovalari to‘liq integratsiyalangan. Matematika va Ingliz tili kurslari 100% faol. 210 ta Web va 41 ta Flutter avtotestlari orqali barqarorligi isbotlangan.
                </p>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-2">
                  <div className="p-3 rounded-xl bg-black/30 border border-cyan-500/20 text-xs text-slate-200 flex items-center gap-2">
                    <CheckCircle2 className="w-4 h-4 text-cyan-400 shrink-0" /> Web + Flutter Mobile to‘liq simmetriyasi
                  </div>
                  <div className="p-3 rounded-xl bg-black/30 border border-cyan-500/20 text-xs text-slate-200 flex items-center gap-2">
                    <CheckCircle2 className="w-4 h-4 text-cyan-400 shrink-0" /> Supabase RLS + Server-side Anti-cheat
                  </div>
                </div>
              </motion.div>
            )}

            {activeRoadmapStage === 'launched' && (
              <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="space-y-4">
                <div className="flex items-center justify-between">
                  <h3 className="text-xl font-black text-purple-300">4-Bosqich: LAUNCHED & SCALE (Bozorga Kirish & Investitsiya)</h3>
                  <span className="px-3 py-1 rounded-full bg-purple-500/20 text-purple-400 text-xs font-bold">Amalga oshirilmoqda</span>
                </div>
                <p className="text-slate-300 text-sm leading-relaxed">
                  Pitch Day 3.0 g‘olibligi, $100K investitsiya jalb qilish, Fizika, Kimyo va DTM sertifikat tizimlarini qo‘shish hamda 100,000+ o‘quvchini jalb qilish.
                </p>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-2">
                  <div className="p-3 rounded-xl bg-black/30 border border-white/5 text-xs text-slate-300 flex items-center gap-2">
                    <ArrowRight className="w-4 h-4 text-purple-400 shrink-0" /> B2B maktablar uchun boshqaruv paneli
                  </div>
                  <div className="p-3 rounded-xl bg-black/30 border border-white/5 text-xs text-slate-300 flex items-center gap-2">
                    <ArrowRight className="w-4 h-4 text-purple-400 shrink-0" /> Gemini Live ovozli interaktiv mentor
                  </div>
                </div>
              </motion.div>
            )}
          </div>
        </section>

        {/* 7. SECTION 5: YECHIMNI QANDAY AMALGA OSHIRISHNI REJALASHTIRYAPSIZ? */}
        <section className="py-16 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-white/10">
          <div className="text-center max-w-3xl mx-auto mb-14">
            <span className="text-cyan-400 text-xs font-black tracking-widest uppercase">5. ASOSIY BOSQICH</span>
            <h2 className="text-3xl sm:text-4xl font-extrabold text-white mt-2">
              Yechimni Amalga Oshirish Strategiyasi
            </h2>
            <p className="text-slate-400 text-sm sm:text-base mt-3">
              Bosqichlar, texnologiyalar, AI vositalari va barqaror masshtablash infratuzilmasi.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div className="p-6 rounded-3xl bg-white/[0.03] border border-white/10 backdrop-blur-md space-y-4">
              <div className="w-12 h-12 rounded-2xl bg-cyan-500/10 text-cyan-400 flex items-center justify-center font-black text-xl">
                01
              </div>
              <h3 className="text-lg font-bold text-white">AI Arxitekturasi va Dvigateli</h3>
              <p className="text-xs text-slate-300 leading-relaxed">
                Google Gemini 2.5 Flash modeli Supabase Deno Edge Functions orqali ulangan. Har bir dars o‘quvchining 0-100% ko‘nikma balliga qarab dinamik prompt bilan generatsiya qilinadi.
              </p>
              <div className="pt-2 text-[11px] text-cyan-400 font-bold">
                Asboblar: Gemini Flash, Deno Edge, RLS
              </div>
            </div>

            <div className="p-6 rounded-3xl bg-white/[0.03] border border-white/10 backdrop-blur-md space-y-4">
              <div className="w-12 h-12 rounded-2xl bg-indigo-500/10 text-indigo-400 flex items-center justify-center font-black text-xl">
                02
              </div>
              <h3 className="text-lg font-bold text-white">Ko‘p Platformali Klient</h3>
              <p className="text-xs text-slate-300 leading-relaxed">
                Veb brauzerda React 19 va mobil telefonlarda Flutter orqali ishlaydi. O‘quvchi qayerda bo‘lishidan qat’i nazar o‘zining darslari, XP lari va Yo‘lchi AI bilan muloqotini davom ettira oladi.
              </p>
              <div className="pt-2 text-[11px] text-indigo-400 font-bold">
                Asboblar: Flutter, Riverpod, React 19, Tailwind
              </div>
            </div>

            <div className="p-6 rounded-3xl bg-white/[0.03] border border-white/10 backdrop-blur-md space-y-4">
              <div className="w-12 h-12 rounded-2xl bg-emerald-500/10 text-emerald-400 flex items-center justify-center font-black text-xl">
                03
              </div>
              <h3 className="text-lg font-bold text-white">Bozor va Monetizatsiya</h3>
              <p className="text-xs text-slate-300 leading-relaxed">
                B2C Freemium modeli: 49,000 so‘mlik obuna xarajatlari bitta repetitor darsining 10 dan bir qismiga teng. B2B modeli orqali xususiy va davlat maktablariga monitoring litsenziyasi sotiladi.
              </p>
              <div className="pt-2 text-[11px] text-emerald-400 font-bold">
                Asboblar: B2C Freemium, B2B SaaS, Payme/Click
              </div>
            </div>
          </div>
        </section>

        {/* 8. SECTION 6: /DEMO SAHIFASI PREVIEW & CTA */}
        <section className="py-16 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-white/10">
          <div className="p-8 sm:p-12 rounded-3xl bg-gradient-to-r from-cyan-950/40 via-indigo-950/40 to-purple-950/40 border border-cyan-500/40 backdrop-blur-md text-center max-w-4xl mx-auto space-y-6">
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-cyan-400 text-black text-xs font-black">
              <Play className="w-3.5 h-3.5 fill-current" />
              6-TALAB: /demo SAHIFASI TAYYOR
            </div>

            <h2 className="text-3xl sm:text-4xl font-extrabold text-white">
              Jonli Demo Video va Interaktiv Prototip
            </h2>

            <p className="text-slate-300 text-sm sm:text-base max-w-2xl mx-auto">
              Hakamlar va investorlar uchun platformaning to‘liq 1–5 daqiqalik dars jarayoni, diagnostikasi va ishlash mexanizmi aks etgan maxsus <strong>/demo</strong> sahifasi tayyorlandi.
            </p>

            <div className="flex flex-wrap items-center justify-center gap-4 pt-2">
              <Button
                variant="primary"
                size="lg"
                onClick={onNavigateDemo}
                className="bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-black px-8 py-3.5 rounded-2xl shadow-lg shadow-cyan-500/25 flex items-center gap-2 cursor-pointer"
              >
                /demo Sahifasiga O‘tish <ArrowRight className="w-4 h-4" />
              </Button>
            </div>
          </div>
        </section>

        {/* 9. BONUS 1: INTERAKTIV AI-CHATBOT (SAVOL-JAVOB NAMUNALARI BILAN) */}
        <section className="py-16 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-white/10">
          <div className="text-center max-w-3xl mx-auto mb-10">
            <span className="text-emerald-400 text-xs font-black tracking-widest uppercase">QO‘SHIMCHA BONUS VAZIFA 1</span>
            <h2 className="text-3xl sm:text-4xl font-extrabold text-white mt-2">
              Savol-Javob Namunalari Bilan AI-Chatbot
            </h2>
            <p className="text-slate-400 text-sm sm:text-base mt-3">
              Yo‘lchi AI bilan hoziroq real vaqtda muloqot qilib ko‘ring yoki quyidagi namunaviy savollarni bosing.
            </p>
          </div>

          <div className="max-w-3xl mx-auto rounded-3xl bg-slate-900/90 border border-white/15 backdrop-blur-xl overflow-hidden shadow-2xl">
            {/* Chat Header */}
            <div className="p-4 bg-slate-800/80 border-b border-white/10 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <YolchiAIMascot size="sm" mood="happy" />
                <div>
                  <h4 className="text-sm font-bold text-white flex items-center gap-2">
                    Yo‘lchi AI Mentori
                    <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
                  </h4>
                  <p className="text-[10px] text-slate-400">Google Gemini 2.5 Flash bilan integratsiyalashgan</p>
                </div>
              </div>
              <button
                onClick={onNavigateAiTutor}
                className="text-xs text-cyan-400 hover:underline font-bold flex items-center gap-1 cursor-pointer"
              >
                To‘liq ekranda ochish →
              </button>
            </div>

            {/* Chat Body */}
            <div className="p-5 space-y-4 max-h-80 overflow-y-auto">
              {chatMessages.map((msg, idx) => (
                <div
                  key={idx}
                  className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}
                >
                  <div
                    className={`max-w-[85%] p-3.5 rounded-2xl text-xs sm:text-sm leading-relaxed ${
                      msg.role === 'user'
                        ? 'bg-cyan-500 text-slate-950 font-medium rounded-br-none'
                        : 'bg-white/10 text-white rounded-bl-none border border-white/10'
                    }`}
                  >
                    {msg.text}
                    <div
                      className={`text-[9px] mt-1 text-right ${
                        msg.role === 'user' ? 'text-slate-800' : 'text-slate-400'
                      }`}
                    >
                      {msg.time}
                    </div>
                  </div>
                </div>
              ))}

              {isBotThinking && (
                <div className="flex justify-start">
                  <div className="p-3 rounded-2xl bg-white/10 text-xs text-cyan-300 flex items-center gap-2 animate-pulse">
                    <Sparkles className="w-3.5 h-3.5 animate-spin" /> Yo‘lchi AI tahlil qilmoqda...
                  </div>
                </div>
              )}
            </div>

            {/* Quick Sample Prompts */}
            <div className="p-3 bg-black/40 border-t border-white/10">
              <div className="text-[11px] text-slate-400 font-bold mb-2">Namunaviy savollar (bir marta bosing):</div>
              <div className="flex flex-wrap gap-2">
                {samplePrompts.map((p, idx) => (
                  <button
                    key={idx}
                    onClick={() => handleSendQuestion(p.q)}
                    className="text-left text-[11px] px-3 py-1.5 rounded-xl bg-white/5 hover:bg-white/10 border border-white/10 text-slate-200 transition-colors cursor-pointer"
                  >
                    💡 {p.q}
                  </button>
                ))}
              </div>
            </div>

            {/* Chat Input */}
            <div className="p-3 bg-slate-800/80 border-t border-white/10 flex items-center gap-2">
              <input
                type="text"
                value={inputQuestion}
                onChange={(e) => setInputQuestion(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && handleSendQuestion()}
                placeholder="Yo‘lchi AI ga ixtiyoriy savol bering..."
                className="flex-1 bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-xs text-white placeholder-slate-400 focus:outline-none focus:border-cyan-400"
              />
              <button
                onClick={() => handleSendQuestion()}
                className="p-2.5 bg-cyan-500 hover:bg-cyan-400 text-slate-950 rounded-xl font-bold transition-colors cursor-pointer"
              >
                <Send className="w-4 h-4" />
              </button>
            </div>
          </div>
        </section>

        {/* 10. REAL BACKEND CONTRACTS & EDGE FUNCTION ARCHITECTURE */}
        <section className="py-16 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-white/10">
          <div className="text-center max-w-3xl mx-auto mb-10">
            <span className="text-indigo-400 text-xs font-black tracking-widest uppercase">XAVFSIZLIK VA ARXITEKTURA</span>
            <h2 className="text-3xl sm:text-4xl font-extrabold text-white mt-2">
              Supabase Edge Function va Server-Side Scoring Tizimi
            </h2>
            <p className="text-slate-400 text-sm sm:text-base mt-3">
              BilimYo‘l Smart Edu ochiq kodli, server-side baholash va Gemini 2.5 Flash Edge Function himoyasiga ega.
            </p>
          </div>

          <div className="max-w-4xl mx-auto rounded-3xl bg-slate-900/90 border border-white/15 backdrop-blur-xl overflow-hidden shadow-2xl">
            {/* API Tab switcher */}
            <div className="flex border-b border-white/10 bg-slate-800/50">
              <button
                onClick={() => setActiveApiTab('diagnostics')}
                className={`flex-1 py-3 px-4 text-xs font-bold transition-colors cursor-pointer ${
                  activeApiTab === 'diagnostics' ? 'bg-white/10 text-cyan-400 border-b-2 border-cyan-400' : 'text-slate-400 hover:text-white'
                }`}
              >
                Edge Function: yolchi-tutor
              </button>
              <button
                onClick={() => setActiveApiTab('scoring')}
                className={`flex-1 py-3 px-4 text-xs font-bold transition-colors cursor-pointer ${
                  activeApiTab === 'scoring' ? 'bg-white/10 text-cyan-400 border-b-2 border-cyan-400' : 'text-slate-400 hover:text-white'
                }`}
              >
                RPC: submit_answer_attempt()
              </button>
              <button
                onClick={() => setActiveApiTab('lessons')}
                className={`flex-1 py-3 px-4 text-xs font-bold transition-colors cursor-pointer ${
                  activeApiTab === 'lessons' ? 'bg-white/10 text-cyan-400 border-b-2 border-cyan-400' : 'text-slate-400 hover:text-white'
                }`}
              >
                RLS: Anti-Cheat Siyosati
              </button>
            </div>

            {/* API Code & Payload */}
            <div className="p-6 font-mono text-xs space-y-4">
              {activeApiTab === 'diagnostics' && (
                <>
                  <div className="text-slate-400 text-[11px]">
                    # Supabase Deno Edge Function — Gemini 2.5 Flash bilan dars/izoh generatsiyasi
                  </div>
                  <div className="p-4 rounded-xl bg-black/60 border border-white/5 text-cyan-300 overflow-x-auto">
                    <pre>{`curl -X POST "https://<supabase-project>.functions.supabase.co/yolchi-tutor" \\
  -H "Authorization: Bearer <ANON_KEY>" \\
  -H "Content-Type: application/json" \\
  -d '{
    "action": "explain_error",
    "courseId": "course_math_01",
    "question": "f(x) = 2x + 3 funksiyada x = 4 bo‘lsa, f(x) ni toping.",
    "userAnswer": "9",
    "weakestSkill": "Funksiyalar va formulalar",
    "language": "uz"
  }'`}</pre>
                  </div>
                  <div className="text-slate-400 text-[11px]">Server Response (Gemini 2.5 Flash Structured JSON):</div>
                  <div className="p-4 rounded-xl bg-black/60 border border-emerald-500/30 text-emerald-300 overflow-x-auto">
                    <pre>{`{
  "explanation": "Qadamma-qadam tahlil qilamiz: x o‘rniga 4 qo‘yilganda, birinchi bo‘lib ko‘paytirish bajariladi: 2 * 4 = 8. Keyin 3 qo‘shiladi: 8 + 3 = 11. Siz 9 deb adashganingiz ko‘paytirishdagi ehtiyotsizlik bo‘lishi mumkin.",
  "pedagogicalHint": "Har doim amallar tartibiga e’tibor bering: avval ko‘paytirish, so‘ng qo‘shish!",
  "isDeterministicFallback": false,
  "recommendedStep": "practice_functions_linear"
}`}</pre>
                  </div>
                </>
              )}

              {activeApiTab === 'scoring' && (
                <>
                  <div className="text-slate-400 text-[11px]">
                    # PostgreSQL RPC: submit_answer_attempt() — Server-side xolis scoring va XP berish
                  </div>
                  <div className="p-4 rounded-xl bg-black/60 border border-white/5 text-amber-300 overflow-x-auto">
                    <pre>{`-- SQL RPC chaqiruvi (Frontend to‘g‘ri javob indeksini bila olmaydi)
SELECT public.submit_answer_attempt(
  p_user_id := auth.uid(),
  p_course_id := 'course_math_01',
  p_lesson_id := 'lesson_math_functions_01',
  p_skill_id := 'skill_math_functions',
  p_question_id := 'q_math_func_01',
  p_selected_index := 2,
  p_idempotency_key := 'uuid-v4-client-token'
);`}</pre>
                  </div>
                  <div className="text-slate-400 text-[11px]">Server Response (JSON):</div>
                  <div className="p-4 rounded-xl bg-black/60 border border-amber-500/30 text-amber-300 overflow-x-auto">
                    <pre>{`{
  "is_correct": true,
  "xp_awarded": 20,
  "streak_extended": true,
  "new_skill_mastery": 65,
  "message": "Tabriklaymiz! Savol to‘g‘ri yechildi va +20 XP hisobingizga qo‘shildi."
}`}</pre>
                  </div>
                </>
              )}

              {activeApiTab === 'lessons' && (
                <>
                  <div className="text-slate-400 text-[11px]">
                    # Row Level Security (RLS) & Anti-Cheat Xavfsizlik Siyosati
                  </div>
                  <div className="p-4 rounded-xl bg-black/60 border border-white/5 text-purple-300 overflow-x-auto">
                    <pre>{`-- answer_attempts jadvali faqat authenticated userlar uchun
ALTER TABLE public.answer_attempts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can only read their own attempts"
  ON public.answer_attempts FOR SELECT
  USING (auth.uid() = user_id);

-- O‘quvchi to‘g‘ridan-to‘g‘ri ball yoki XP yozolmaydi: faqat RPC ruxsat berilgan
REVOKE INSERT, UPDATE ON public.gamification_profiles FROM authenticated;
GRANT EXECUTE ON FUNCTION public.submit_answer_attempt TO authenticated;`}</pre>
                  </div>
                </>
              )}
            </div>
          </div>
        </section>

        {/* 11. FOOTER & FINAL CALL TO ACTION */}
        <footer className="py-12 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-white/10 text-center space-y-4">
          <div className="flex items-center justify-center gap-2">
            <BilimYolLogo size="md" />
          </div>
          <p className="text-xs text-slate-400 max-w-xl mx-auto">
            BilimYo‘l Smart Edu — Pitch Day 3.0 (AIFU) ishtirokchisi. Barcha huquqlar himoyalangan © 2026.
          </p>
          <div className="flex flex-wrap items-center justify-center gap-4 text-xs font-bold text-cyan-400">
            <button onClick={onNavigateDemo} className="hover:underline cursor-pointer">
              /demo Sahifasi
            </button>
            <span className="text-slate-600">•</span>
            <button onClick={onNavigateApp} className="hover:underline cursor-pointer">
              Jonli Prototip
            </button>
            <span className="text-slate-600">•</span>
            <a href="https://pitch-day.uz" target="_blank" rel="noreferrer" className="hover:underline">
              pitch-day.uz Rasmiy Sayti
            </a>
          </div>
        </footer>
      </div>
    </div>
  );
};
