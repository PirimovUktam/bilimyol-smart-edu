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
  Zap,
  GraduationCap,
  MessageSquare,
  ExternalLink,
  CheckCircle2,
  TrendingUp,
  Brain,
  Send,
  Briefcase,
  Calendar,
  DollarSign,
  Clock,
  BarChart3,
} from 'lucide-react';
import { Button } from '@/presentation/components/Button';
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
    <div className="min-h-screen bg-slate-50 text-slate-900 selection:bg-cyan-500 selection:text-white">
      {/* Background Decorative Mesh Gradients */}
      <div className="fixed inset-0 pointer-events-none overflow-hidden z-0">
        <div className="absolute -top-40 -left-40 w-96 h-96 bg-cyan-200/50 rounded-full blur-[140px]" />
        <div className="absolute top-1/3 -right-40 w-[500px] h-[500px] bg-indigo-200/40 rounded-full blur-[160px]" />
        <div className="absolute bottom-10 left-1/4 w-[450px] h-[450px] bg-emerald-200/40 rounded-full blur-[150px]" />
      </div>

      <div className="relative z-10">
        {/* 1. TOP PITCH DAY 3.0 BANNER */}
        <div className="bg-gradient-to-r from-indigo-600 via-purple-600 to-cyan-600 border-b border-indigo-700/20 py-2.5 px-4 text-center text-white shadow-sm">
          <div className="max-w-7xl mx-auto flex flex-wrap items-center justify-between gap-3 text-xs">
            <div className="flex items-center gap-2 mx-auto sm:mx-0">
              <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-white text-indigo-900 font-black tracking-wide uppercase text-[10px] shadow-xs">
                <Sparkles className="w-3 h-3 text-amber-500" /> PITCH DAY 3.0
              </span>
              <span className="text-white/95 font-semibold">
                AIFU • IT Park • Alibaba • Inno Technopark Saralash Bosqichi
              </span>
            </div>
            <div className="flex items-center gap-2 mx-auto sm:mx-0">
              <span className="text-emerald-200 font-bold flex items-center gap-1">
                <span className="w-2 h-2 rounded-full bg-emerald-300 animate-ping inline-block" />
                1-Bosqich: Onlayn Saralash (11-oktyabr 23:59:59)
              </span>
              <button
                onClick={onNavigateDemo}
                className="underline hover:text-cyan-100 font-extrabold cursor-pointer ml-2"
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
            <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-cyan-50 border border-cyan-200 text-cyan-800 text-xs font-bold shadow-xs">
              <Sparkles className="w-3.5 h-3.5 text-cyan-600" />
              <span>O‘zbekiston EdTech Bozorida 1-Raqamli AI Ta’lim Platformasi</span>
            </div>

            <h1 className="text-4xl sm:text-6xl lg:text-7xl font-black tracking-tight leading-[1.1] text-slate-900">
              BilimYo‘l Smart Edu
            </h1>

            <p className="text-lg sm:text-2xl text-slate-600 font-medium max-w-3xl mx-auto leading-relaxed">
              Har bir o‘quvchi uchun <span className="text-cyan-700 font-bold">individual sun’iy intellekt repetitori</span> va bo‘shliqlarni yo‘qotuvchi adaptiv ta’lim traektoriyasi.
            </p>

            <div className="flex flex-wrap items-center justify-center gap-4 pt-4">
              <Button
                variant="primary"
                size="lg"
                onClick={onNavigateDemo}
                className="bg-gradient-to-r from-cyan-600 to-blue-600 hover:from-cyan-500 hover:to-blue-500 text-white font-extrabold shadow-lg shadow-cyan-600/25 px-8 py-4 text-base rounded-2xl flex items-center gap-3 cursor-pointer"
              >
                <Play className="w-5 h-5 fill-current" />
                Demo Sahifasini Ko‘rish (/demo)
              </Button>

              <Button
                variant="outline"
                size="lg"
                onClick={onNavigateApp}
                className="border-slate-300 bg-white hover:bg-slate-50 text-slate-800 font-bold px-8 py-4 text-base rounded-2xl flex items-center gap-2 cursor-pointer shadow-sm"
              >
                <Zap className="w-5 h-5 text-amber-500" />
                Jonli Prototipni Ishga Tushirish
              </Button>
            </div>

            {/* Quick Metrics Bar */}
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 pt-12 max-w-4xl mx-auto">
              <div className="p-4 rounded-2xl bg-white border border-slate-200/90 shadow-sm">
                <div className="text-2xl sm:text-3xl font-black text-cyan-600">6.5M+</div>
                <div className="text-xs text-slate-600 mt-1 font-semibold">Maktab o‘quvchilari (O‘zbekiston)</div>
              </div>
              <div className="p-4 rounded-2xl bg-white border border-slate-200/90 shadow-sm">
                <div className="text-2xl sm:text-3xl font-black text-emerald-600">100%</div>
                <div className="text-xs text-slate-600 mt-1 font-semibold">Adaptiv Diagnostika & Xarita</div>
              </div>
              <div className="p-4 rounded-2xl bg-white border border-slate-200/90 shadow-sm">
                <div className="text-2xl sm:text-3xl font-black text-indigo-600">&lt;1.5s</div>
                <div className="text-xs text-slate-600 mt-1 font-semibold">Yo‘lchi AI O‘rtacha Javob Tezligi</div>
              </div>
              <div className="p-4 rounded-2xl bg-white border border-slate-200/90 shadow-sm">
                <div className="text-2xl sm:text-3xl font-black text-purple-600">MVP</div>
                <div className="text-xs text-slate-600 mt-1 font-semibold">Ishlayotgan Web & Flutter Ilova</div>
              </div>
            </div>
          </motion.div>
        </section>

        {/* 3. SECTION 1: MUAMMO → YECHIM (PROBLEM → SOLUTION) */}
        <section className="py-16 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-slate-200">
          <div className="text-center max-w-3xl mx-auto mb-14">
            <span className="text-cyan-700 bg-cyan-50 px-3 py-1 rounded-full border border-cyan-200 text-xs font-black tracking-widest uppercase">1. ASOSIY BOSQICH</span>
            <h2 className="text-3xl sm:text-4xl font-extrabold text-slate-900 mt-2">
              Muammo <span className="text-slate-400">→</span> Bizning Yechim
            </h2>
            <p className="text-slate-600 text-sm sm:text-base mt-3">
              O‘zbekiston ta’lim tizimidagi eng o‘tkir to‘siqlarni sun’iy intellekt va adaptiv pedagogika orqali hal qilamiz.
            </p>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
            {/* The Problem Side */}
            <div className="p-8 rounded-3xl bg-rose-50/70 border border-rose-200/80 shadow-sm relative overflow-hidden space-y-6">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-rose-100 text-rose-600 flex items-center justify-center font-black">
                  ✕
                </div>
                <div>
                  <h3 className="text-xl font-extrabold text-rose-900">Kritik Muammo</h3>
                  <p className="text-xs text-rose-700">An’anaviy ta’limdagi tizimli bo‘shliqlar</p>
                </div>
              </div>

              <div className="space-y-4">
                <div className="p-4 rounded-2xl bg-white border border-rose-100 shadow-xs">
                  <h4 className="font-bold text-sm text-slate-900 flex items-center gap-2">
                    <span className="text-rose-600 font-black">1.</span> 35-40 talik ommaviy sinflar
                  </h4>
                  <p className="text-xs text-slate-600 mt-1 leading-relaxed">
                    O‘qituvchi 45 daqiqada har bir o‘quvchiga 1 daqiqa ham vaqt ajrata olmaydi. Barcha o‘quvchilar bitta sur’atda o‘qitiladi.
                  </p>
                </div>

                <div className="p-4 rounded-2xl bg-white border border-rose-100 shadow-xs">
                  <h4 className="font-bold text-sm text-slate-900 flex items-center gap-2">
                    <span className="text-rose-600 font-black">2.</span> Qimmat repetitorlar (500K - 1.5M so‘m/oy)
                  </h4>
                  <p className="text-xs text-slate-600 mt-1 leading-relaxed">
                    Oilalar byudjetiga og‘ir. Qishloq va tumanlarda esa malakali, ixtisoslashgan ustozlar umuman yetishmaydi.
                  </p>
                </div>

                <div className="p-4 rounded-2xl bg-white border border-rose-100 shadow-xs">
                  <h4 className="font-bold text-sm text-slate-900 flex items-center gap-2">
                    <span className="text-rose-600 font-black">3.</span> Quruq, tushunarsiz testlar
                  </h4>
                  <p className="text-xs text-slate-600 mt-1 leading-relaxed">
                    O‘quvchi xato qilganda nega xato qilganini tushuntiradigan hech kim yo‘q. Faqat quruq "noto‘g‘ri" degan ball qo‘yiladi.
                  </p>
                </div>

                <div className="p-4 rounded-2xl bg-white border border-rose-100 shadow-xs">
                  <h4 className="font-bold text-sm text-slate-900 flex items-center gap-2">
                    <span className="text-rose-600 font-black">4.</span> Bo‘shliqlarning to‘planib borishi
                  </h4>
                  <p className="text-xs text-slate-600 mt-1 leading-relaxed">
                    5-sinfda kasrlarni tushunmagan o‘quvchi 8-sinfda algebra va geometriyani butunlay o‘zlashtira olmay qoladi.
                  </p>
                </div>
              </div>
            </div>

            {/* The Solution Side */}
            <div className="p-8 rounded-3xl bg-cyan-50/70 border border-cyan-200/80 shadow-sm relative overflow-hidden space-y-6">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-cyan-100 text-cyan-700 flex items-center justify-center font-black">
                  ✓
                </div>
                <div>
                  <h3 className="text-xl font-extrabold text-cyan-950">BilimYo‘l Yechimi</h3>
                  <p className="text-xs text-cyan-700">Sun’iy intellektga asoslangan shaxsiy ekotizim</p>
                </div>
              </div>

              <div className="space-y-4">
                <div className="p-4 rounded-2xl bg-white border border-cyan-100 shadow-xs">
                  <h4 className="font-bold text-sm text-slate-900 flex items-center gap-2">
                    <span className="text-cyan-600 font-black">1.</span> 100% Adaptiv Diagnostika
                  </h4>
                  <p className="text-xs text-slate-600 mt-1 leading-relaxed">
                    8 ta moslashuvchan test orqali o‘quvchining har bir ko‘nikmasi (Algebra, Tenglama, Funksiya, Lug‘at va h.k.) 0-100% shkalada aniqlanadi.
                  </p>
                </div>

                <div className="p-4 rounded-2xl bg-white border border-cyan-100 shadow-xs">
                  <h4 className="font-bold text-sm text-slate-900 flex items-center gap-2">
                    <span className="text-cyan-600 font-black">2.</span> "Yo‘lchi AI" Do‘stona Mentori
                  </h4>
                  <p className="text-xs text-slate-600 mt-1 leading-relaxed">
                    Google Gemini 2.5 Flash bilan qurollangan mentor bolaga tayyor javobni emas, xatoning tub sababini pedagogik uslubda tushuntiradi.
                  </p>
                </div>

                <div className="p-4 rounded-2xl bg-white border border-cyan-100 shadow-xs">
                  <h4 className="font-bold text-sm text-slate-900 flex items-center gap-2">
                    <span className="text-cyan-600 font-black">3.</span> Individual 3 Qadamli Darslar
                  </h4>
                  <p className="text-xs text-slate-600 mt-1 leading-relaxed">
                    Zaif nuqta aniqlanishi bilan AI u uchun maxsus dars yaratadi: 1) Qisqa tushuncha; 2) Vizual model / audio to‘lqin; 3) Interaktiv mustahkamlash.
                  </p>
                </div>

                <div className="p-4 rounded-2xl bg-white border border-cyan-100 shadow-xs">
                  <h4 className="font-bold text-sm text-slate-900 flex items-center gap-2">
                    <span className="text-cyan-600 font-black">4.</span> Hamyonbop va Har Doim Yoningizda
                  </h4>
                  <p className="text-xs text-slate-600 mt-1 leading-relaxed">
                    Oyiga atigi 49,000 so‘m. Web va Flutter Mobile orqali har qanday telefonda 24/7 ishlaydi.
                  </p>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* 4. SECTION 2: JAMOA (TEAM) */}
        <section className="py-16 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-slate-200">
          <div className="text-center max-w-3xl mx-auto mb-14">
            <span className="text-cyan-700 bg-cyan-50 px-3 py-1 rounded-full border border-cyan-200 text-xs font-black tracking-widest uppercase">2. ASOSIY BOSQICH • AXION JAMOA</span>
            <h2 className="text-3xl sm:text-4xl font-extrabold text-slate-900 mt-2">
              Bizning Jamoa (Axion) — 3 Ta Asosiy Ustun
            </h2>
            <p className="text-slate-600 text-sm sm:text-base mt-3">
              Texnologik arxitektura, biznes o‘sish strategiyasi va pedagogik metodologiyani yagona maqsad atrofida birlashtirgan asoschilar jamoasi.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            {/* Member 1: Founder & Lead Developer */}
            <div className="p-7 rounded-3xl bg-white border-2 border-cyan-300/80 flex flex-col justify-between hover:border-cyan-500 transition-all group shadow-md hover:shadow-xl relative overflow-hidden">
              <div className="absolute top-0 right-0 w-32 h-32 bg-cyan-500/5 rounded-full blur-2xl -mr-10 -mt-10 pointer-events-none" />
              <div>
                <div className="flex items-center gap-4 mb-5">
                  <div className="relative">
                    <img
                      src="/images/team/oktam_pirimov.jpg"
                      alt="Pirimov O‘ktam"
                      className="w-20 h-20 rounded-2xl object-cover ring-2 ring-cyan-500/60 shadow-md"
                    />
                    <span className="absolute -bottom-2 -right-2 px-2 py-0.5 rounded-full bg-cyan-500 text-slate-950 text-[10px] font-black uppercase tracking-wider shadow-sm">
                      👑 Lead
                    </span>
                  </div>
                  <div>
                    <h3 className="text-xl font-bold text-slate-900 group-hover:text-cyan-700 transition-colors">
                      Pirimov O‘ktam
                    </h3>
                    <p className="text-xs text-cyan-700 font-bold mt-0.5">Founder & Lead Developer</p>
                    <span className="inline-block mt-1 text-[11px] text-slate-500">Arxitektura & Muhandislik</span>
                  </div>
                </div>

                <p className="text-xs text-slate-600 leading-relaxed">
                  BilimYo‘l ekotizimining asoschisi va bosh arxitektori. Web va Mobile ilovalar (React 19, Flutter), server-side anti-cheat scoring (PostgreSQL RPC) hamda Gemini AI (Yo‘lchi) Edge integratsiyasini to‘liq kod darajasida noldan yaratgan.
                </p>

                <div className="mt-5 pt-4 border-t border-slate-100 space-y-2">
                  <div className="text-[11px] text-slate-500 font-bold uppercase tracking-wider">Asosiy Ko‘nikmalar:</div>
                  <div className="flex flex-wrap gap-1.5 text-[10px]">
                    <span className="px-2.5 py-1 rounded-lg bg-cyan-50 text-cyan-800 border border-cyan-200 font-semibold">Tizim Arxitekturasi</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-100 text-slate-700">React 19 & TypeScript</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-100 text-slate-700">Flutter 3.x (Mobile)</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-100 text-slate-700">PostgreSQL RPC & RLS</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-100 text-slate-700">Gemini AI / Deno Edge</span>
                  </div>
                </div>
              </div>

              <div className="mt-6 flex items-center justify-between pt-4 border-t border-slate-100 text-xs">
                <div className="flex items-center gap-3">
                  <a
                    href="https://github.com/pirimovuktam"
                    target="_blank"
                    rel="noreferrer"
                    className="text-slate-700 hover:text-slate-900 flex items-center gap-1 font-bold transition-colors"
                  >
                    <ExternalLink className="w-3.5 h-3.5" /> GitHub
                  </a>
                  <a
                    href="https://t.me/pirimovuktam"
                    target="_blank"
                    rel="noreferrer"
                    className="text-cyan-700 hover:underline flex items-center gap-1 font-bold"
                  >
                    <MessageSquare className="w-3.5 h-3.5" /> Telegram
                  </a>
                </div>
                <span className="text-[10px] text-emerald-700 font-mono font-bold bg-emerald-50 px-2 py-0.5 rounded-md border border-emerald-200">
                  152 Web • 48 Mob Tests
                </span>
              </div>
            </div>

            {/* Member 2: Business & Growth Lead */}
            <div className="p-7 rounded-3xl bg-white border-2 border-purple-300/80 flex flex-col justify-between hover:border-purple-500 transition-all group shadow-md hover:shadow-xl relative overflow-hidden">
              <div className="absolute top-0 right-0 w-32 h-32 bg-purple-500/5 rounded-full blur-2xl -mr-10 -mt-10 pointer-events-none" />
              <div>
                <div className="flex items-center gap-4 mb-5">
                  <div className="relative">
                    <div className="w-20 h-20 rounded-2xl bg-gradient-to-tr from-purple-600 to-indigo-600 flex items-center justify-center text-white shadow-md ring-2 ring-purple-400">
                      <Briefcase className="w-10 h-10 text-purple-100" />
                    </div>
                    <span className="absolute -bottom-2 -right-2 px-2 py-0.5 rounded-full bg-purple-600 text-white text-[10px] font-black uppercase tracking-wider shadow-sm">
                      🚀 Growth
                    </span>
                  </div>
                  <div>
                    <h3 className="text-xl font-bold text-slate-900 group-hover:text-purple-700 transition-colors">
                      Abdurauf Normuminov
                    </h3>
                    <p className="text-xs text-purple-700 font-bold mt-0.5">Business & Growth Lead</p>
                    <span className="inline-block mt-1 text-[11px] text-slate-500">Bozor & Hamkorliklar</span>
                  </div>
                </div>

                <p className="text-xs text-slate-600 leading-relaxed">
                  Biznes modelni shakllantirish, bozorga chiqish (Go-To-Market) strategiyasi, maktablar va o‘quv markazlari bilan B2B hamkorlik hamda foydalanuvchilar oqimini (traction) kengaytirish rahbari.
                </p>

                <div className="mt-5 pt-4 border-t border-slate-100 space-y-2">
                  <div className="text-[11px] text-slate-500 font-bold uppercase tracking-wider">Asosiy Ko‘nikmalar:</div>
                  <div className="flex flex-wrap gap-1.5 text-[10px]">
                    <span className="px-2.5 py-1 rounded-lg bg-purple-50 text-purple-800 border border-purple-200 font-semibold">EdTech GTM Strategiyasi</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-100 text-slate-700">B2B Maktablar Hamkorligi</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-100 text-slate-700">Unit Economics & Monetizatsiya</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-100 text-slate-700">Marketing Funnels</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-100 text-slate-700">Investor Relations</span>
                  </div>
                </div>
              </div>

              <div className="mt-6 flex items-center justify-between pt-4 border-t border-slate-100 text-xs">
                <div className="flex items-center gap-2 text-purple-700 font-bold">
                  <TrendingUp className="w-3.5 h-3.5" />
                  <span>EdTech Growth Strategy</span>
                </div>
                <span className="text-[10px] text-purple-700 font-mono font-bold bg-purple-50 px-2 py-0.5 rounded-md border border-purple-200">
                  B2B & B2C Focus
                </span>
              </div>
            </div>

            {/* Member 3: Education & Product Lead */}
            <div className="p-7 rounded-3xl bg-white border-2 border-emerald-300/80 flex flex-col justify-between hover:border-emerald-500 transition-all group shadow-md hover:shadow-xl relative overflow-hidden">
              <div className="absolute top-0 right-0 w-32 h-32 bg-emerald-500/5 rounded-full blur-2xl -mr-10 -mt-10 pointer-events-none" />
              <div>
                <div className="flex items-center gap-4 mb-5">
                  <div className="relative">
                    <div className="w-20 h-20 rounded-2xl bg-gradient-to-tr from-emerald-600 to-teal-600 flex items-center justify-center text-white shadow-md ring-2 ring-emerald-400">
                      <GraduationCap className="w-10 h-10 text-emerald-100" />
                    </div>
                    <span className="absolute -bottom-2 -right-2 px-2 py-0.5 rounded-full bg-emerald-600 text-white text-[10px] font-black uppercase tracking-wider shadow-sm">
                      🎓 EdLead
                    </span>
                  </div>
                  <div>
                    <h3 className="text-xl font-bold text-slate-900 group-hover:text-emerald-700 transition-colors">
                      Hamdamova Dildora
                    </h3>
                    <p className="text-xs text-emerald-700 font-bold mt-0.5">Education & Product Lead</p>
                    <span className="inline-block mt-1 text-[11px] text-slate-500">Pedagogika & Mahsulot</span>
                  </div>
                </div>

                <p className="text-xs text-slate-600 leading-relaxed">
                  Pedagogik metodika va mahsulot arxitekturasi bo‘yicha yetakchi. Milliy ta’lim standartlari, Bloom taksonomiyasi va adaptiv diagnostika metodikasi bo‘yicha kurikulum rahbari.
                </p>

                <div className="mt-5 pt-4 border-t border-slate-100 space-y-2">
                  <div className="text-[11px] text-slate-500 font-bold uppercase tracking-wider">Asosiy Ko‘nikmalar:</div>
                  <div className="flex flex-wrap gap-1.5 text-[10px]">
                    <span className="px-2.5 py-1 rounded-lg bg-emerald-50 text-emerald-800 border border-emerald-200 font-semibold">Adaptiv Kurikulum</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-100 text-slate-700">Bloom Taksonomiyasi</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-100 text-slate-700">Diagnostik Metodika</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-100 text-slate-700">O‘quvchi UX & Psixologiyasi</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-100 text-slate-700">Math & English Standartlar</span>
                  </div>
                </div>
              </div>

              <div className="mt-6 flex items-center justify-between pt-4 border-t border-slate-100 text-xs">
                <div className="flex items-center gap-2 text-emerald-700 font-bold">
                  <Brain className="w-3.5 h-3.5" />
                  <span>Pedagogical Standards</span>
                </div>
                <span className="text-[10px] text-emerald-700 font-mono font-bold bg-emerald-50 px-2 py-0.5 rounded-md border border-emerald-200">
                  100% Moslik
                </span>
              </div>
            </div>
          </div>

          {/* Technology stack pill carousel */}
          <div className="mt-12 p-6 rounded-3xl bg-white border border-slate-200 shadow-sm flex flex-wrap items-center justify-center gap-3">
            <span className="text-xs text-slate-500 font-bold">Foydalanilgan texnologiyalar:</span>
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
                className="px-3 py-1.5 rounded-xl bg-slate-50 border border-slate-200 text-xs font-semibold text-slate-700 shadow-2xs"
              >
                {tech}
              </span>
            ))}
          </div>
        </section>

        {/* 5. SECTION 3: NEGA BIZNING JAMOA BU MUAMMONI HAL QILA OLADI? */}
        <section className="py-16 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-slate-200">
          <div className="text-center max-w-3xl mx-auto mb-14">
            <span className="text-cyan-700 bg-cyan-50 px-3 py-1 rounded-full border border-cyan-200 text-xs font-black tracking-widest uppercase">3. ASOSIY BOSQICH</span>
            <h2 className="text-3xl sm:text-4xl font-extrabold text-slate-900 mt-2">
              Nima Uchun Aynan Bizning Jamoa?
            </h2>
            <p className="text-slate-600 text-sm sm:text-base mt-3">
              G‘oya va slaydlar bosqichidan o‘tib, real ishlayotgan mahsulotga ega ekanligimiz — bizning asosiy ustunligimizdir.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            <div className="p-6 rounded-3xl bg-white border border-slate-200 shadow-sm hover:shadow-md transition-shadow">
              <div className="w-12 h-12 rounded-2xl bg-cyan-50 text-cyan-600 flex items-center justify-center mb-4">
                <CheckCircle2 className="w-6 h-6" />
              </div>
              <h3 className="text-lg font-bold text-slate-900 mb-2">100% Ishlayotgan MVP</h3>
              <p className="text-xs text-slate-600 leading-relaxed">
                Biz quruq taqdimot bilan kelmadik. Web va Flutter Mobile ilovamiz to‘liq tayyor, testlar bilan qoplangan va jonli rejimda ishlaydi.
              </p>
            </div>

            <div className="p-6 rounded-3xl bg-white border border-slate-200 shadow-sm hover:shadow-md transition-shadow">
              <div className="w-12 h-12 rounded-2xl bg-indigo-50 text-indigo-600 flex items-center justify-center mb-4">
                <Brain className="w-6 h-6" />
              </div>
              <h3 className="text-lg font-bold text-slate-900 mb-2">Haqiqiy Pedagogik AI</h3>
              <p className="text-xs text-slate-600 leading-relaxed">
                Oddiy ChatGPT wrapper emas. Tizim bolaga tayyor javobni aytib dangasa qilmaydi, balki ko‘nikmalar grafigi bo‘yicha tushuntiradi.
              </p>
            </div>

            <div className="p-6 rounded-3xl bg-white border border-slate-200 shadow-sm hover:shadow-md transition-shadow">
              <div className="w-12 h-12 rounded-2xl bg-emerald-50 text-emerald-600 flex items-center justify-center mb-4">
                <ShieldCheck className="w-6 h-6" />
              </div>
              <h3 className="text-lg font-bold text-slate-900 mb-2">Server Anti-Cheat Xavfsizligi</h3>
              <p className="text-xs text-slate-600 leading-relaxed">
                Ballar, ko‘nikmalar va XP lar to‘liq server-side hisoblanadi. O‘quvchi brauzer orqali javoblarni ko‘rib ololmaydi yoki ballni soxtalashtira olmaydi.
              </p>
            </div>

            <div className="p-6 rounded-3xl bg-white border border-slate-200 shadow-sm hover:shadow-md transition-shadow">
              <div className="w-12 h-12 rounded-2xl bg-purple-50 text-purple-600 flex items-center justify-center mb-4">
                <Users className="w-6 h-6" />
              </div>
              <h3 className="text-lg font-bold text-slate-900 mb-2">3 Kishi Kuchli Sinergiyasi</h3>
              <p className="text-xs text-slate-600 leading-relaxed">
                Tizim arxitekturasi va AI muhandisligi (O‘ktam), biznes strategiyasi va maktablar bilan B2B hamkorlik (Abdurauf) hamda milliy pedagogik kurikulum metodikasi (Dildora) — Axion jamoasida to‘liq uyg‘unlashgan.
              </p>
            </div>
          </div>
        </section>

        {/* 6. SECTION 4: YO'L XARITASI (IDEA → PROTOTYPE → MVP → LAUNCHED & SCALE) */}
        <section className="py-16 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-slate-200">
          <div className="text-center max-w-3xl mx-auto mb-14">
            <span className="text-cyan-700 bg-cyan-50 px-3 py-1 rounded-full border border-cyan-200 text-xs font-black tracking-widest uppercase">4. ASOSIY BOSQICH</span>
            <h2 className="text-3xl sm:text-4xl font-extrabold text-slate-900 mt-2">
              Yo‘l Xaritasi & Moliyalashtirish Smeta (Roadmap)
            </h2>
            <p className="text-slate-600 text-sm sm:text-base mt-3">
              Tahminiy va haddan tashqari shishirilgan raqamlar emas — aniq vaqt, real ko‘rsatkichlar (KPI) va $45,000 miqdoridagi shaffof byudjet taqsimoti.
            </p>
          </div>

          {/* Interactive Stage Selector */}
          <div className="flex flex-wrap items-center justify-center gap-3 mb-10">
            {[
              { id: 'idea', label: '1. IDEA', badge: 'Avg 2024 • $1.5K', statusBadge: '100% Bajarildi' },
              { id: 'prototype', label: '2. PROTOTYPE', badge: 'Sen 2024 • $2.5K', statusBadge: '100% Bajarildi' },
              { id: 'mvp', label: '3. MVP (HOZIRGI)', badge: 'Okt 2024 • $6K', statusBadge: 'Jonli & Testlangan' },
              { id: 'launched', label: '4. LAUNCH & SCALE', badge: '6 oy • $45K Pre-Seed', statusBadge: 'Amalga oshirilmoqda' },
            ].map((stage) => (
              <button
                key={stage.id}
                onClick={() => setActiveRoadmapStage(stage.id as any)}
                className={`px-4 sm:px-5 py-3 rounded-2xl text-xs sm:text-sm font-extrabold transition-all cursor-pointer flex flex-col sm:flex-row items-center gap-2 ${
                  activeRoadmapStage === stage.id
                    ? 'bg-cyan-600 text-white shadow-lg shadow-cyan-600/20 scale-105'
                    : 'bg-white hover:bg-slate-50 text-slate-700 border border-slate-200 shadow-2xs'
                }`}
              >
                <span>{stage.label}</span>
                <span
                  className={`text-[10px] px-2 py-0.5 rounded-full font-mono font-bold ${
                    activeRoadmapStage === stage.id ? 'bg-white/20 text-white' : 'bg-slate-100 text-slate-600'
                  }`}
                >
                  {stage.badge}
                </span>
              </button>
            ))}
          </div>

          {/* Stage Details Card */}
          <div className="p-8 sm:p-10 rounded-3xl bg-white border border-slate-200 max-w-4xl mx-auto shadow-xl">
            {activeRoadmapStage === 'idea' && (
              <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="space-y-5">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-slate-200 pb-4">
                  <div>
                    <h3 className="text-xl font-black text-slate-900">1-Bosqich: IDEA (G‘oya & Bozor Validatsiyasi)</h3>
                    <p className="text-xs text-slate-500 mt-1 flex items-center gap-3">
                      <span className="flex items-center gap-1"><Calendar className="w-3.5 h-3.5 text-cyan-600" /> Avgust 2024 (1 oy)</span>
                      <span className="flex items-center gap-1"><DollarSign className="w-3.5 h-3.5 text-emerald-600" /> $1,500 Bootstrapping</span>
                    </p>
                  </div>
                  <span className="px-3 py-1 rounded-full bg-emerald-50 text-emerald-700 border border-emerald-200 text-xs font-bold self-start sm:self-auto">
                    100% Yakunlangan
                  </span>
                </div>
                <p className="text-slate-600 text-sm leading-relaxed">
                  500 dan ortiq maktab o‘quvchilari va ota-onalar o‘rtasida so‘rovnomalar o‘tkazildi. O‘zbekiston maktab ta’limidagi matematika va ingliz tili bo‘yicha tizimli bo‘shliqlar tahlil qilinib, Bloom taksonomiyasiga asoslangan individual bilim daraxti modeli ishlab chiqildi.
                </p>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-2">
                  <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 text-xs text-slate-700 flex items-center gap-2">
                    <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" /> 500+ o‘quvchi va ota-onalar muammo auditi
                  </div>
                  <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 text-xs text-slate-700 flex items-center gap-2">
                    <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" /> Bloom taksonomiyasiga asoslangan ko‘nikmalar matritsasi
                  </div>
                  <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 text-xs text-slate-700 flex items-center gap-2">
                    <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" /> EdTech B2B va B2C bozor ehtiyojlari validatsiyasi
                  </div>
                  <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 text-xs text-slate-700 flex items-center gap-2">
                    <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" /> $1,500 shaxsiy mablag‘ bilan to‘liq yakunlandi
                  </div>
                </div>
              </motion.div>
            )}

            {activeRoadmapStage === 'prototype' && (
              <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="space-y-5">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-slate-200 pb-4">
                  <div>
                    <h3 className="text-xl font-black text-blue-900">2-Bosqich: PROTOTYPE (Algoritm & Dastlabki AI)</h3>
                    <p className="text-xs text-slate-500 mt-1 flex items-center gap-3">
                      <span className="flex items-center gap-1"><Calendar className="w-3.5 h-3.5 text-blue-600" /> Sentabr 2024 (1 oy)</span>
                      <span className="flex items-center gap-1"><DollarSign className="w-3.5 h-3.5 text-emerald-600" /> $2,500 Bootstrapping</span>
                    </p>
                  </div>
                  <span className="px-3 py-1 rounded-full bg-blue-50 text-blue-700 border border-blue-200 text-xs font-bold self-start sm:self-auto">
                    100% Yakunlangan
                  </span>
                </div>
                <p className="text-slate-600 text-sm leading-relaxed">
                  Yo‘lchi AI uchun Google Gemini API prompt muhandisligi va pedagogik cheklovlar sinovdan o‘tkazildi. 50 nafar pilot o‘quvchi ishtirokida adaptiv savollar zanjiri va diagnostik test algoritmlarining ishlashi amalda sinab ko‘rildi.
                </p>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-2">
                  <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 text-xs text-slate-700 flex items-center gap-2">
                    <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" /> Gemini API pedagogik prompt arxitekturasi
                  </div>
                  <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 text-xs text-slate-700 flex items-center gap-2">
                    <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" /> 50 nafar pilot o‘quvchi bilan diagnostika testi
                  </div>
                  <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 text-xs text-slate-700 flex items-center gap-2">
                    <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" /> Yo‘lchi AI javob to‘g‘rilash va yo‘naltirish mexanizmi
                  </div>
                  <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 text-xs text-slate-700 flex items-center gap-2">
                    <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" /> $2,500 AI API va dastlabki infratuzilma sinovi
                  </div>
                </div>
              </motion.div>
            )}

            {activeRoadmapStage === 'mvp' && (
              <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="space-y-5">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-slate-200 pb-4">
                  <div>
                    <h3 className="text-xl font-black text-cyan-900">3-Bosqich: MVP (To‘liq Ishlayotgan Tizim — HOZIRDA JONLI)</h3>
                    <p className="text-xs text-slate-500 mt-1 flex items-center gap-3">
                      <span className="flex items-center gap-1"><Calendar className="w-3.5 h-3.5 text-cyan-600" /> Oktabr 2024 (Jonli Holat)</span>
                      <span className="flex items-center gap-1"><DollarSign className="w-3.5 h-3.5 text-emerald-600" /> $6,000 Sarflangan (Asoschilar)</span>
                    </p>
                  </div>
                  <span className="px-3 py-1 rounded-full bg-cyan-50 text-cyan-700 border border-cyan-200 text-xs font-bold self-start sm:self-auto">
                    100% Jonli & Testlangan
                  </span>
                </div>
                <p className="text-slate-600 text-sm leading-relaxed">
                  Web SPA (React 19) va Mobil (Flutter) ilovalari to‘liq ishlab turibdi. Matematika va Ingliz tili kurslari 100% faol. Server-side anti-cheat scoring (PostgreSQL RPC + RLS) va 152 ta Web hamda 48 ta Mobil avtotestlar bilan himoyalangan.
                </p>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-2">
                  <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 text-xs text-slate-700 flex items-center gap-2">
                    <CheckCircle2 className="w-4 h-4 text-cyan-600 shrink-0" /> Web (React 19) + Flutter Mobil to‘liq simmetriyasi
                  </div>
                  <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 text-xs text-slate-700 flex items-center gap-2">
                    <CheckCircle2 className="w-4 h-4 text-cyan-600 shrink-0" /> Supabase RLS + Server-side Anti-cheat scoring
                  </div>
                  <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 text-xs text-slate-700 flex items-center gap-2">
                    <CheckCircle2 className="w-4 h-4 text-cyan-600 shrink-0" /> 152 ta Web va 48 ta Mobil avtotestlar (100% Pass)
                  </div>
                  <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 text-xs text-slate-700 flex items-center gap-2">
                    <CheckCircle2 className="w-4 h-4 text-cyan-600 shrink-0" /> Jonli Vercel Production deploymenti
                  </div>
                </div>
              </motion.div>
            )}

            {activeRoadmapStage === 'launched' && (
              <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="space-y-6">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-slate-200 pb-4">
                  <div>
                    <h3 className="text-xl font-black text-purple-900">
                      4-Bosqich: LAUNCH & SCALE (Pre-Seed: Bozorga Kirish & Pilot Maktablar)
                    </h3>
                    <p className="text-xs text-slate-500 mt-1 flex flex-wrap items-center gap-3">
                      <span className="flex items-center gap-1 font-semibold text-purple-800">
                        <Clock className="w-3.5 h-3.5 text-purple-600" /> Muddat: 6 oy (Noyabr 2024 – Aprel 2025)
                      </span>
                      <span className="flex items-center gap-1 font-bold text-emerald-800 bg-emerald-50 px-2.5 py-0.5 rounded-lg border border-emerald-200">
                        <DollarSign className="w-3.5 h-3.5 text-emerald-600" /> Talab Qilinayotgan Byudjet: $45,000 Pre-Seed
                      </span>
                    </p>
                  </div>
                  <span className="px-3 py-1 rounded-full bg-purple-50 text-purple-700 text-xs font-bold self-start sm:self-auto border border-purple-200">
                    Amalga oshirilmoqda
                  </span>
                </div>

                <p className="text-slate-600 text-xs sm:text-sm leading-relaxed">
                  Balandparvoz va noaniq raqamlar emas: <strong className="text-slate-900">$45,000 aniq byudjet</strong> va <strong className="text-slate-900">6 oylik muddat</strong> doirasida 10 ta pilot maktab, 3,000–5,000 nafar faol oylik o‘quvchi va B2C monetizatsiya modelini yo‘lga qo‘yish bo‘yicha professional reja.
                </p>

                {/* 4 Realistic Target KPIs */}
                <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
                  <div className="p-3.5 rounded-2xl bg-purple-50/70 border border-purple-200 text-center">
                    <div className="text-lg sm:text-xl font-black text-purple-700">10 Ta</div>
                    <div className="text-[11px] text-slate-800 font-bold mt-0.5">Pilot Maktablar</div>
                    <div className="text-[10px] text-slate-500">B2B Integratsiya</div>
                  </div>
                  <div className="p-3.5 rounded-2xl bg-cyan-50/70 border border-cyan-200 text-center">
                    <div className="text-lg sm:text-xl font-black text-cyan-700">3,000 – 5,000</div>
                    <div className="text-[11px] text-slate-800 font-bold mt-0.5">Faol O‘quvchi</div>
                    <div className="text-[10px] text-slate-500">Haqiqiy oylik MAU</div>
                  </div>
                  <div className="p-3.5 rounded-2xl bg-emerald-50/70 border border-emerald-200 text-center">
                    <div className="text-lg sm:text-xl font-black text-emerald-700">12% – 15%</div>
                    <div className="text-[11px] text-slate-800 font-bold mt-0.5">Pullik Konversiya</div>
                    <div className="text-[10px] text-slate-500">B2C obuna modeli</div>
                  </div>
                  <div className="p-3.5 rounded-2xl bg-amber-50/70 border border-amber-200 text-center">
                    <div className="text-lg sm:text-xl font-black text-amber-700">+28%</div>
                    <div className="text-[11px] text-slate-800 font-bold mt-0.5">Bilim O‘sishi</div>
                    <div className="text-[10px] text-slate-500">1 oylik ta’limda</div>
                  </div>
                </div>

                {/* Exact Financial Allocation Breakdown ($45,000) */}
                <div className="p-5 rounded-2xl bg-slate-50 border border-slate-200 space-y-4">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-black text-slate-900 uppercase tracking-wider flex items-center gap-2">
                      <BarChart3 className="w-4 h-4 text-emerald-600" />
                      $45,000 Byudjetning Aniq Va Shaffof Taqsimoti:
                    </span>
                    <span className="text-[11px] font-mono text-emerald-700 font-bold">100% Balanslangan</span>
                  </div>

                  {/* Multi-color Progress bar */}
                  <div className="w-full h-2.5 rounded-full bg-slate-200 overflow-hidden flex">
                    <div style={{ width: '27%' }} className="bg-cyan-500" title="AI & Server (27%)" />
                    <div style={{ width: '24%' }} className="bg-purple-500" title="B2B Maktablar (24%)" />
                    <div style={{ width: '22%' }} className="bg-emerald-500" title="Metodologiya (22%)" />
                    <div style={{ width: '18%' }} className="bg-amber-500" title="Marketing (18%)" />
                    <div style={{ width: '9%' }} className="bg-rose-500" title="Yuridik & Zaxira (9%)" />
                  </div>

                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
                    <div className="p-2.5 rounded-xl bg-white border border-slate-200 flex items-start justify-between shadow-2xs">
                      <div>
                        <div className="font-bold text-slate-800 flex items-center gap-1.5">
                          <span className="w-2 h-2 rounded-full bg-cyan-500" /> AI & Server Infratuzilmasi
                        </div>
                        <div className="text-[10px] text-slate-500 mt-0.5">Gemini 2.5 tokenlari, Supabase Pro, audio TTS/CDN</div>
                      </div>
                      <span className="font-mono font-bold text-cyan-700 shrink-0">$12,000 (27%)</span>
                    </div>

                    <div className="p-2.5 rounded-xl bg-white border border-slate-200 flex items-start justify-between shadow-2xs">
                      <div>
                        <div className="font-bold text-slate-800 flex items-center gap-1.5">
                          <span className="w-2 h-2 rounded-full bg-purple-500" /> B2B Maktablar Integratsiyasi
                        </div>
                        <div className="text-[10px] text-slate-500 mt-0.5">10 maktab tahlil paneli, pilot trening va texnik servis</div>
                      </div>
                      <span className="font-mono font-bold text-purple-700 shrink-0">$11,000 (24%)</span>
                    </div>

                    <div className="p-2.5 rounded-xl bg-white border border-slate-200 flex items-start justify-between shadow-2xs">
                      <div>
                        <div className="font-bold text-slate-800 flex items-center gap-1.5">
                          <span className="w-2 h-2 rounded-full bg-emerald-500" /> Metodologiya & Fanlar Kengayishi
                        </div>
                        <div className="text-[10px] text-slate-500 mt-0.5">Prezident maktablari moduli, Fizika, ekspert auditi</div>
                      </div>
                      <span className="font-mono font-bold text-emerald-700 shrink-0">$10,000 (22%)</span>
                    </div>

                    <div className="p-2.5 rounded-xl bg-white border border-slate-200 flex items-start justify-between shadow-2xs">
                      <div>
                        <div className="font-bold text-slate-800 flex items-center gap-1.5">
                          <span className="w-2 h-2 rounded-full bg-amber-500" /> GTM & O‘quvchilarni Jalb Qilish
                        </div>
                        <div className="text-[10px] text-slate-500 mt-0.5">Ota-onalar bepul diagnostika oyligi, maqsadli target</div>
                      </div>
                      <span className="font-mono font-bold text-amber-700 shrink-0">$8,000 (18%)</span>
                    </div>

                    <div className="p-2.5 rounded-xl bg-white border border-slate-200 flex items-start justify-between sm:col-span-2 shadow-2xs">
                      <div>
                        <div className="font-bold text-slate-800 flex items-center gap-1.5">
                          <span className="w-2 h-2 rounded-full bg-rose-500" /> Yuridik Rasmiylashtirish, IP & Favqulodda Zaxira
                        </div>
                        <div className="text-[10px] text-slate-500 mt-0.5">Dasturiy intellektual mulk (IP), B2B shartnomalar va kutilmagan xarajatlar zaxirasi</div>
                      </div>
                      <span className="font-mono font-bold text-rose-700 shrink-0">$4,000 (9%)</span>
                    </div>
                  </div>
                </div>

                {/* 3 Clear Timeline Sprints */}
                <div className="pt-2">
                  <div className="text-xs font-bold text-slate-500 uppercase tracking-wider mb-3">
                    6 Oylik Bosqichma-Bosqich Reja (Sprints):
                  </div>
                  <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                    <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 space-y-1.5">
                      <div className="text-[11px] font-black text-cyan-700 uppercase">1–2 Oylar (Noyabr – Dekabr)</div>
                      <div className="text-xs font-bold text-slate-900">B2B Pilot & Maktablar</div>
                      <p className="text-[11px] text-slate-600 leading-relaxed">
                        10 ta pilot maktabga ulanish, o‘qituvchilar paneli joriy etilishi, 1,000 ta ilk faol o‘quvchi oqimi.
                      </p>
                    </div>

                    <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 space-y-1.5">
                      <div className="text-[11px] font-black text-purple-700 uppercase">3–4 Oylar (Yanvar – Fevral)</div>
                      <div className="text-xs font-bold text-slate-900">Kontent & Audio Mentor</div>
                      <p className="text-[11px] text-slate-600 leading-relaxed">
                        Prezident maktablari moduli, Fizika kursi, Yo‘lchi ovozli tushuntirish, 3,000 nafar faol o‘quvchi.
                      </p>
                    </div>

                    <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 space-y-1.5">
                      <div className="text-[11px] font-black text-emerald-700 uppercase">5–6 Oylar (Mart – Aprel)</div>
                      <div className="text-xs font-bold text-slate-900">B2C Monetizatsiya & Scale</div>
                      <p className="text-[11px] text-slate-600 leading-relaxed">
                        Click / Payme to‘lov integratsiyasi, 5,000 nafar MAU va operatsion o‘zini-o‘zi qoplash (breakeven).
                      </p>
                    </div>
                  </div>
                </div>
              </motion.div>
            )}
          </div>
        </section>

        {/* 7. SECTION 5: YECHIMNI QANDAY AMALGA OSHIRISHNI REJALASHTIRYAPSIZ? */}
        <section className="py-16 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-slate-200">
          <div className="text-center max-w-3xl mx-auto mb-14">
            <span className="text-cyan-700 bg-cyan-50 border border-cyan-200 px-3 py-1 rounded-full text-xs font-black tracking-widest uppercase">
              5. ASOSIY BOSQICH
            </span>
            <h2 className="text-3xl sm:text-4xl font-extrabold text-slate-900 mt-3">
              Yechimni Amalga Oshirish Strategiyasi
            </h2>
            <p className="text-slate-600 text-sm sm:text-base mt-3">
              Bosqichlar, texnologiyalar, AI vositalari va barqaror masshtablash infratuzilmasi.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div className="p-6 rounded-3xl bg-white border border-slate-200 shadow-sm space-y-4 hover:shadow-md transition-shadow">
              <div className="w-12 h-12 rounded-2xl bg-cyan-100 text-cyan-700 flex items-center justify-center font-black text-xl">
                01
              </div>
              <h3 className="text-lg font-bold text-slate-900">AI Arxitekturasi va Dvigateli</h3>
              <p className="text-xs text-slate-600 leading-relaxed">
                Google Gemini 2.5 Flash modeli Supabase Deno Edge Functions orqali ulangan. Har bir dars o‘quvchining 0-100% ko‘nikma balliga qarab dinamik prompt bilan generatsiya qilinadi.
              </p>
              <div className="pt-2 text-[11px] text-cyan-700 font-bold">
                Asboblar: Gemini Flash, Deno Edge, RLS
              </div>
            </div>

            <div className="p-6 rounded-3xl bg-white border border-slate-200 shadow-sm space-y-4 hover:shadow-md transition-shadow">
              <div className="w-12 h-12 rounded-2xl bg-indigo-100 text-indigo-700 flex items-center justify-center font-black text-xl">
                02
              </div>
              <h3 className="text-lg font-bold text-slate-900">Ko‘p Platformali Klient</h3>
              <p className="text-xs text-slate-600 leading-relaxed">
                Veb brauzerda React 19 va mobil telefonlarda Flutter orqali ishlaydi. O‘quvchi qayerda bo‘lishidan qat’i nazar o‘zining darslari, XP lari va Yo‘lchi AI bilan muloqotini davom ettira oladi.
              </p>
              <div className="pt-2 text-[11px] text-indigo-700 font-bold">
                Asboblar: Flutter, Riverpod, React 19, Tailwind
              </div>
            </div>

            <div className="p-6 rounded-3xl bg-white border border-slate-200 shadow-sm space-y-4 hover:shadow-md transition-shadow">
              <div className="w-12 h-12 rounded-2xl bg-emerald-100 text-emerald-700 flex items-center justify-center font-black text-xl">
                03
              </div>
              <h3 className="text-lg font-bold text-slate-900">Bozor va Monetizatsiya</h3>
              <p className="text-xs text-slate-600 leading-relaxed">
                B2C Freemium modeli: 49,000 so‘mlik obuna xarajatlari bitta repetitor darsining 10 dan bir qismiga teng. B2B modeli orqali xususiy va davlat maktablariga monitoring litsenziyasi sotiladi.
              </p>
              <div className="pt-2 text-[11px] text-emerald-700 font-bold">
                Asboblar: B2C Freemium, B2B SaaS, Payme/Click
              </div>
            </div>
          </div>
        </section>

        {/* 8. SECTION 6: /DEMO SAHIFASI PREVIEW & CTA */}
        <section className="py-16 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-slate-200">
          <div className="p-8 sm:p-12 rounded-3xl bg-gradient-to-r from-cyan-600 via-indigo-600 to-blue-700 shadow-xl text-center max-w-4xl mx-auto space-y-6 text-white">
            <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-white/20 text-white text-xs font-black backdrop-blur-md">
              <Play className="w-3.5 h-3.5 fill-current" />
              6-TALAB: /demo SAHIFASI TAYYOR
            </div>

            <h2 className="text-3xl sm:text-4xl font-extrabold text-white">
              Jonli Demo Video va Interaktiv Prototip
            </h2>

            <p className="text-cyan-50 text-sm sm:text-base max-w-2xl mx-auto leading-relaxed">
              Hakamlar va investorlar uchun platformaning to‘liq 1–5 daqiqalik dars jarayoni, diagnostikasi va ishlash mexanizmi aks etgan maxsus <strong>/demo</strong> sahifasi tayyorlandi.
            </p>

            <div className="flex flex-wrap items-center justify-center gap-4 pt-2">
              <Button
                variant="primary"
                size="lg"
                onClick={onNavigateDemo}
                className="bg-white hover:bg-slate-100 text-slate-950 font-black px-8 py-3.5 rounded-2xl shadow-xl flex items-center gap-2 cursor-pointer transition-all transform hover:-translate-y-0.5"
              >
                /demo Sahifasiga O‘tish <ArrowRight className="w-4 h-4" />
              </Button>
            </div>
          </div>
        </section>

        {/* 9. BONUS 1: INTERAKTIV AI-CHATBOT (SAVOL-JAVOB NAMUNALARI BILAN) */}
        <section className="py-16 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-slate-200">
          <div className="text-center max-w-3xl mx-auto mb-10">
            <span className="text-emerald-700 bg-emerald-50 border border-emerald-200 px-3 py-1 rounded-full text-xs font-black tracking-widest uppercase">
              QO‘SHIMCHA BONUS VAZIFA 1
            </span>
            <h2 className="text-3xl sm:text-4xl font-extrabold text-slate-900 mt-3">
              Savol-Javob Namunalari Bilan AI-Chatbot
            </h2>
            <p className="text-slate-600 text-sm sm:text-base mt-3">
              Yo‘lchi AI bilan hoziroq real vaqtda muloqot qilib ko‘ring yoki quyidagi namunaviy savollarni bosing.
            </p>
          </div>

          <div className="max-w-3xl mx-auto rounded-3xl bg-white border border-slate-200 overflow-hidden shadow-xl">
            {/* Chat Header */}
            <div className="p-4 bg-slate-50 border-b border-slate-200 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <YolchiAIMascot size="sm" mood="happy" />
                <div>
                  <h4 className="text-sm font-bold text-slate-900 flex items-center gap-2">
                    Yo‘lchi AI Mentori
                    <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
                  </h4>
                  <p className="text-[10px] text-slate-500">Google Gemini 2.5 Flash bilan integratsiyalashgan</p>
                </div>
              </div>
              <button
                onClick={onNavigateAiTutor}
                className="text-xs text-cyan-700 hover:underline font-bold flex items-center gap-1 cursor-pointer"
              >
                To‘liq ekranda ochish →
              </button>
            </div>

            {/* Chat Body */}
            <div className="p-5 space-y-4 max-h-80 overflow-y-auto bg-slate-50/50">
              {chatMessages.map((msg, idx) => (
                <div
                  key={idx}
                  className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}
                >
                  <div
                    className={`max-w-[85%] p-3.5 rounded-2xl text-xs sm:text-sm leading-relaxed ${
                      msg.role === 'user'
                        ? 'bg-cyan-600 text-white font-medium rounded-br-none shadow-sm'
                        : 'bg-white text-slate-800 rounded-bl-none border border-slate-200 shadow-sm'
                    }`}
                  >
                    {msg.text}
                    <div
                      className={`text-[9px] mt-1 text-right ${
                        msg.role === 'user' ? 'text-cyan-100' : 'text-slate-400'
                      }`}
                    >
                      {msg.time}
                    </div>
                  </div>
                </div>
              ))}

              {isBotThinking && (
                <div className="flex justify-start">
                  <div className="p-3 rounded-2xl bg-white border border-slate-200 text-xs text-cyan-700 flex items-center gap-2 animate-pulse shadow-sm">
                    <Sparkles className="w-3.5 h-3.5 animate-spin" /> Yo‘lchi AI tahlil qilmoqda...
                  </div>
                </div>
              )}
            </div>

            {/* Quick Sample Prompts */}
            <div className="p-3 bg-slate-100/70 border-t border-slate-200">
              <div className="text-[11px] text-slate-600 font-bold mb-2">Namunaviy savollar (bir marta bosing):</div>
              <div className="flex flex-wrap gap-2">
                {samplePrompts.map((p, idx) => (
                  <button
                    key={idx}
                    onClick={() => handleSendQuestion(p.q)}
                    className="text-left text-[11px] px-3 py-1.5 rounded-xl bg-white hover:bg-slate-50 border border-slate-200 text-slate-700 shadow-sm transition-colors cursor-pointer"
                  >
                    💡 {p.q}
                  </button>
                ))}
              </div>
            </div>

            {/* Chat Input */}
            <div className="p-3 bg-white border-t border-slate-200 flex items-center gap-2">
              <input
                type="text"
                value={inputQuestion}
                onChange={(e) => setInputQuestion(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && handleSendQuestion()}
                placeholder="Yo‘lchi AI ga ixtiyoriy savol bering..."
                className="flex-1 bg-slate-50 border border-slate-200 rounded-xl px-4 py-2.5 text-xs text-slate-900 placeholder-slate-400 focus:outline-none focus:border-cyan-500 focus:bg-white"
              />
              <button
                onClick={() => handleSendQuestion()}
                className="p-2.5 bg-cyan-600 hover:bg-cyan-500 text-white rounded-xl font-bold transition-colors cursor-pointer shadow-sm"
              >
                <Send className="w-4 h-4" />
              </button>
            </div>
          </div>
        </section>

        {/* 10. REAL BACKEND CONTRACTS & EDGE FUNCTION ARCHITECTURE */}
        <section className="py-16 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-slate-200">
          <div className="text-center max-w-3xl mx-auto mb-10">
            <span className="text-indigo-700 bg-indigo-50 border border-indigo-200 px-3 py-1 rounded-full text-xs font-black tracking-widest uppercase">
              XAVFSIZLIK VA ARXITEKTURA
            </span>
            <h2 className="text-3xl sm:text-4xl font-extrabold text-slate-900 mt-3">
              Supabase Edge Function va Server-Side Scoring Tizimi
            </h2>
            <p className="text-slate-600 text-sm sm:text-base mt-3">
              BilimYo‘l Smart Edu ochiq kodli, server-side baholash va Gemini 2.5 Flash Edge Function himoyasiga ega.
            </p>
          </div>

          <div className="max-w-4xl mx-auto rounded-3xl bg-white border border-slate-200 overflow-hidden shadow-xl">
            {/* API Tab switcher */}
            <div className="flex border-b border-slate-200 bg-slate-50">
              <button
                onClick={() => setActiveApiTab('diagnostics')}
                className={`flex-1 py-3 px-4 text-xs font-bold transition-colors cursor-pointer ${
                  activeApiTab === 'diagnostics' ? 'bg-white text-cyan-700 border-b-2 border-cyan-600 font-black' : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                Edge Function: yolchi-tutor
              </button>
              <button
                onClick={() => setActiveApiTab('scoring')}
                className={`flex-1 py-3 px-4 text-xs font-bold transition-colors cursor-pointer ${
                  activeApiTab === 'scoring' ? 'bg-white text-cyan-700 border-b-2 border-cyan-600 font-black' : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                RPC: submit_answer_attempt()
              </button>
              <button
                onClick={() => setActiveApiTab('lessons')}
                className={`flex-1 py-3 px-4 text-xs font-bold transition-colors cursor-pointer ${
                  activeApiTab === 'lessons' ? 'bg-white text-cyan-700 border-b-2 border-cyan-600 font-black' : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                RLS: Anti-Cheat Siyosati
              </button>
            </div>

            {/* API Code & Payload */}
            <div className="p-6 font-mono text-xs space-y-4 bg-slate-900 text-slate-100">
              {activeApiTab === 'diagnostics' && (
                <>
                  <div className="text-slate-400 text-[11px]">
                    # Supabase Deno Edge Function — Gemini 2.5 Flash bilan dars/izoh generatsiyasi
                  </div>
                  <div className="p-4 rounded-xl bg-slate-950 border border-slate-800 text-cyan-300 overflow-x-auto">
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
                  <div className="p-4 rounded-xl bg-slate-950 border border-emerald-500/40 text-emerald-300 overflow-x-auto">
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
                  <div className="p-4 rounded-xl bg-slate-950 border border-slate-800 text-amber-300 overflow-x-auto">
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
                  <div className="p-4 rounded-xl bg-slate-950 border border-amber-500/40 text-amber-300 overflow-x-auto">
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
                  <div className="p-4 rounded-xl bg-slate-950 border border-slate-800 text-purple-300 overflow-x-auto">
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
        <footer className="py-12 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-slate-200 text-center space-y-4">
          <div className="flex items-center justify-center gap-2">
            <BilimYolLogo size="md" />
          </div>
          <p className="text-xs text-slate-500 max-w-xl mx-auto">
            BilimYo‘l Smart Edu — Pitch Day 3.0 (AIFU) ishtirokchisi. Barcha huquqlar himoyalangan © 2026.
          </p>
          <div className="flex flex-wrap items-center justify-center gap-4 text-xs font-bold text-cyan-700">
            <button onClick={onNavigateDemo} className="hover:underline cursor-pointer">
              /demo Sahifasi
            </button>
            <span className="text-slate-400">•</span>
            <button onClick={onNavigateApp} className="hover:underline cursor-pointer">
              Jonli Prototip
            </button>
            <span className="text-slate-400">•</span>
            <a href="https://pitch-day.uz" target="_blank" rel="noreferrer" className="hover:underline">
              pitch-day.uz Rasmiy Sayti
            </a>
          </div>
        </footer>
      </div>
    </div>
  );
};
