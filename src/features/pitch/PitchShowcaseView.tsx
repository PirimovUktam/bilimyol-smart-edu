import React, { useState } from 'react';
import { motion, useScroll, useSpring } from 'framer-motion';
import {
  Sparkles,
  ArrowRight,
  Play,
  Users,
  ShieldCheck,
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
  Clock,
  Layers,
  Check,
  X,
  ChevronRight,
  Rocket,
  Award,
  Terminal,
} from 'lucide-react';
import { Button } from '@/presentation/components/Button';
import { BilimYolLogo } from '@/presentation/components/BilimYolLogo';
import { YolchiAIMascot } from '@/presentation/components/YolchiAIMascot';

interface PitchShowcaseViewProps {
  onNavigateDemo: () => void;
  onNavigateApp: () => void;
  onNavigateAiTutor: () => void;
}

type RoadmapStageId = 'now' | '6months' | '1year' | '3years';

export const PitchShowcaseView: React.FC<PitchShowcaseViewProps> = ({
  onNavigateDemo,
  onNavigateApp,
  onNavigateAiTutor,
}) => {
  // Top scroll progress bar
  const { scrollYProgress } = useScroll();
  const scaleX = useSpring(scrollYProgress, {
    stiffness: 100,
    damping: 30,
    restDelta: 0.001,
  });

  // Roadmap active stage (Slide 06)
  const [activeRoadmapStage, setActiveRoadmapStage] = useState<RoadmapStageId>('now');

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

  // Section scroll helper
  const scrollToSection = (id: string) => {
    const elem = document.getElementById(id);
    if (elem) {
      elem.scrollIntoView({ behavior: 'smooth' });
    }
  };

  return (
    <div className="min-h-screen bg-[#070b15] text-slate-100 selection:bg-cyan-500 selection:text-white relative overflow-hidden font-sans">
      {/* 0. TOP ANIMATED SCROLL PROGRESS BAR */}
      <motion.div
        style={{ scaleX }}
        className="fixed top-0 left-0 right-0 h-1 bg-gradient-to-r from-cyan-500 via-indigo-500 to-emerald-400 origin-left z-50 shadow-[0_0_12px_rgba(6,182,212,0.8)]"
      />

      {/* AMBIENT AURORA BACKGROUND GLOWS */}
      <div className="fixed inset-0 pointer-events-none overflow-hidden z-0">
        {/* Cyber tech grid */}
        <div className="absolute inset-0 bg-[linear-gradient(to_right,#ffffff05_1px,transparent_1px),linear-gradient(to_bottom,#ffffff05_1px,transparent_1px)] bg-[size:48px_48px] [mask-image:radial-gradient(ellipse_80%_60%_at_50%_0%,#000_70%,transparent_100%)]" />

        {/* Top cyan aurora glow */}
        <motion.div
          animate={{ scale: [1, 1.15, 1], opacity: [0.18, 0.28, 0.18] }}
          transition={{ duration: 10, repeat: Infinity, ease: 'easeInOut' }}
          className="absolute -top-40 left-1/2 -translate-x-1/2 w-[900px] h-[550px] bg-gradient-to-b from-cyan-500/25 via-blue-600/15 to-transparent rounded-full blur-[140px]"
        />

        {/* Mid-section violet ambient blob */}
        <motion.div
          animate={{ y: [0, 40, 0], opacity: [0.15, 0.25, 0.15] }}
          transition={{ duration: 14, repeat: Infinity, ease: 'easeInOut' }}
          className="absolute top-1/3 -right-32 w-[600px] h-[600px] bg-indigo-600/20 rounded-full blur-[160px]"
        />

        {/* Bottom emerald glow */}
        <motion.div
          animate={{ x: [0, 30, 0], opacity: [0.12, 0.22, 0.12] }}
          transition={{ duration: 12, repeat: Infinity, ease: 'easeInOut' }}
          className="absolute bottom-1/4 -left-32 w-[650px] h-[650px] bg-emerald-600/15 rounded-full blur-[170px]"
        />
      </div>

      <div className="relative z-10">
        {/* 1. TOP PITCH DAY 3.0 BANNER */}
        <div className="sticky top-0 z-40 bg-[#070b15]/85 backdrop-blur-xl border-b border-white/10 py-2.5 px-4 text-center text-white shadow-lg shadow-black/40">
          <div className="max-w-7xl mx-auto flex flex-wrap items-center justify-between gap-3 text-xs">
            <div className="flex items-center gap-2 mx-auto sm:mx-0">
              <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-cyan-500/15 text-cyan-300 border border-cyan-500/30 font-black tracking-wide uppercase text-[10px] shadow-[0_0_12px_rgba(6,182,212,0.3)]">
                <Sparkles className="w-3 h-3 text-cyan-400 animate-spin" /> PITCH DAY 3.0
              </span>
              <span className="text-slate-300 font-medium">
                AIFU • IT Park • Alibaba • Inno Technopark Saralash Bosqichi
              </span>
            </div>
            <div className="flex items-center gap-3 mx-auto sm:mx-0">
              <span className="text-emerald-400 font-bold flex items-center gap-1.5 text-[11px]">
                <span className="w-2 h-2 rounded-full bg-emerald-400 animate-ping inline-block" />
                1-Bosqich: Onlayn Saralash
              </span>
              <button
                onClick={onNavigateDemo}
                className="px-3 py-1 rounded-xl bg-gradient-to-r from-cyan-500 to-blue-600 text-white font-extrabold hover:brightness-110 cursor-pointer shadow-md shadow-cyan-500/20 text-[11px] flex items-center gap-1 transition-all"
              >
                /demo sahifasi <ChevronRight className="w-3 h-3" />
              </button>
            </div>
          </div>
        </div>

        {/* QUICK FLOATING SECTION JUMPER (Interactive Navigation Pill) */}
        <div className="max-w-5xl mx-auto px-4 pt-4 hidden md:block">
          <div className="p-1.5 rounded-2xl bg-slate-900/80 border border-white/10 backdrop-blur-xl flex items-center justify-center gap-1 text-[11px] text-slate-300 shadow-2xl">
            <span className="text-slate-500 font-mono font-bold px-2 uppercase tracking-wider text-[10px]">
              Tezkor O‘tish:
            </span>
            <button
              onClick={() => scrollToSection('muammo-yechim')}
              className="px-3 py-1 rounded-xl hover:bg-white/10 hover:text-white transition-colors cursor-pointer font-semibold"
            >
              1. Muammo → Yechim
            </button>
            <button
              onClick={() => scrollToSection('axion-jamoa')}
              className="px-3 py-1 rounded-xl hover:bg-white/10 hover:text-white transition-colors cursor-pointer font-semibold"
            >
              2. Jamoa
            </button>
            <button
              onClick={() => scrollToSection('nega-biz')}
              className="px-3 py-1 rounded-xl hover:bg-white/10 hover:text-white transition-colors cursor-pointer font-semibold"
            >
              3. Nega Biz?
            </button>
            <button
              onClick={() => scrollToSection('milestones-monetizatsiya')}
              className="px-3 py-1 rounded-xl bg-cyan-500/20 text-cyan-300 border border-cyan-500/30 hover:bg-cyan-500/30 transition-colors cursor-pointer font-bold"
            >
              4. Milestones & Monetizatsiya
            </button>
            <button
              onClick={() => scrollToSection('strategiya')}
              className="px-3 py-1 rounded-xl hover:bg-white/10 hover:text-white transition-colors cursor-pointer font-semibold"
            >
              5. Strategiya
            </button>
            <button
              onClick={() => scrollToSection('ai-mentor')}
              className="px-3 py-1 rounded-xl hover:bg-white/10 hover:text-white transition-colors cursor-pointer font-semibold"
            >
              6. AI Chatbot
            </button>
          </div>
        </div>

        {/* 2. HERO SECTION */}
        <section className="pt-16 pb-20 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto text-center">
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.7, ease: [0.22, 1, 0.36, 1] }}
            className="space-y-6 max-w-4xl mx-auto"
          >
            <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-gradient-to-r from-cyan-500/10 via-indigo-500/10 to-purple-500/10 border border-cyan-500/30 text-cyan-300 text-xs font-bold shadow-[0_0_20px_rgba(6,182,212,0.2)]">
              <Sparkles className="w-3.5 h-3.5 text-cyan-400" />
              <span>O‘zbekiston EdTech Bozorida 1-Raqamli AI Ta’lim Platformasi</span>
            </div>

            <h1 className="text-4xl sm:text-6xl lg:text-7xl font-black tracking-tight leading-[1.08] text-white">
              BilimYo‘l{' '}
              <span className="bg-gradient-to-r from-cyan-400 via-teal-300 to-indigo-400 bg-clip-text text-transparent">
                Smart Edu
              </span>
            </h1>

            <p className="text-lg sm:text-2xl text-slate-300 font-medium max-w-3xl mx-auto leading-relaxed">
              Darslik emas — <span className="text-cyan-300 font-bold underline decoration-cyan-500/50 underline-offset-4">shaxsiy ta’lim yo‘li.</span> Har bir o‘quvchiga 24/7 adaptiv AI repetitor va individual rivojlanish traektoriyasi.
            </p>

            <div className="flex flex-wrap items-center justify-center gap-4 pt-4">
              <Button
                variant="primary"
                size="lg"
                onClick={onNavigateDemo}
                className="bg-gradient-to-r from-cyan-500 via-blue-600 to-indigo-600 hover:brightness-110 text-white font-extrabold shadow-[0_0_30px_rgba(6,182,212,0.4)] px-8 py-4 text-base rounded-2xl flex items-center gap-3 cursor-pointer transition-all transform hover:-translate-y-0.5 border border-cyan-400/30"
              >
                <Play className="w-5 h-5 fill-current" />
                Demo Sahifasini Ko‘rish (/demo)
              </Button>

              <Button
                variant="outline"
                size="lg"
                onClick={onNavigateApp}
                className="border-slate-700 bg-slate-900/80 hover:bg-slate-800 text-slate-200 font-bold px-8 py-4 text-base rounded-2xl flex items-center gap-2 cursor-pointer shadow-lg backdrop-blur-md hover:border-slate-500 transition-all"
              >
                <Zap className="w-5 h-5 text-amber-400 animate-pulse" />
                Jonli Prototipni Ishga Tushirish
              </Button>
            </div>

            {/* Quick Metrics Bar with Glowing High-Tech Cards */}
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 pt-10 max-w-4xl mx-auto">
              <motion.div
                whileHover={{ y: -4 }}
                className="p-5 rounded-2xl bg-slate-900/70 border border-cyan-500/30 backdrop-blur-xl shadow-lg relative overflow-hidden group"
              >
                <div className="absolute top-0 right-0 w-24 h-24 bg-cyan-500/10 rounded-full blur-xl group-hover:bg-cyan-500/20 transition-all pointer-events-none" />
                <div className="text-3xl sm:text-4xl font-black text-cyan-400 tracking-tight">6.5M+</div>
                <div className="text-xs text-slate-300 mt-1 font-semibold">Maktab o‘quvchilari (O‘zbekiston)</div>
              </motion.div>

              <motion.div
                whileHover={{ y: -4 }}
                className="p-5 rounded-2xl bg-slate-900/70 border border-emerald-500/30 backdrop-blur-xl shadow-lg relative overflow-hidden group"
              >
                <div className="absolute top-0 right-0 w-24 h-24 bg-emerald-500/10 rounded-full blur-xl group-hover:bg-emerald-500/20 transition-all pointer-events-none" />
                <div className="text-3xl sm:text-4xl font-black text-emerald-400 tracking-tight">100%</div>
                <div className="text-xs text-slate-300 mt-1 font-semibold">Adaptiv Diagnostika & Xarita</div>
              </motion.div>

              <motion.div
                whileHover={{ y: -4 }}
                className="p-5 rounded-2xl bg-slate-900/70 border border-indigo-500/30 backdrop-blur-xl shadow-lg relative overflow-hidden group"
              >
                <div className="absolute top-0 right-0 w-24 h-24 bg-indigo-500/10 rounded-full blur-xl group-hover:bg-indigo-500/20 transition-all pointer-events-none" />
                <div className="text-3xl sm:text-4xl font-black text-indigo-400 tracking-tight">&lt;1.5s</div>
                <div className="text-xs text-slate-300 mt-1 font-semibold">Yo‘lchi AI O‘rtacha Javob Tezligi</div>
              </motion.div>

              <motion.div
                whileHover={{ y: -4 }}
                className="p-5 rounded-2xl bg-slate-900/70 border border-purple-500/30 backdrop-blur-xl shadow-lg relative overflow-hidden group"
              >
                <div className="absolute top-0 right-0 w-24 h-24 bg-purple-500/10 rounded-full blur-xl group-hover:bg-purple-500/20 transition-all pointer-events-none" />
                <div className="text-3xl sm:text-4xl font-black text-purple-400 tracking-tight">MVP</div>
                <div className="text-xs text-slate-300 mt-1 font-semibold">Ishlayotgan Web & Flutter Ilova</div>
              </motion.div>
            </div>
          </motion.div>
        </section>

        {/* 3. SECTION 1: MUAMMO → YECHIM (PROBLEM → SOLUTION) - JAW-DROPPING CYBER REDESIGN */}
        <section id="muammo-yechim" className="py-20 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-white/10 relative">
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: '-80px' }}
            transition={{ duration: 0.6 }}
            className="text-center max-w-3xl mx-auto mb-16"
          >
            <span className="inline-flex items-center gap-1.5 px-3.5 py-1 rounded-full bg-cyan-500/15 text-cyan-300 border border-cyan-500/30 text-xs font-black tracking-widest uppercase shadow-[0_0_15px_rgba(6,182,212,0.25)]">
              <Sparkles className="w-3.5 h-3.5 text-cyan-400" />
              1. ASOSIY BOSQICH
            </span>
            <h2 className="text-3xl sm:text-5xl font-black text-white mt-3 tracking-tight">
              Muammo <span className="text-cyan-400">→</span> Bizning Yechim
            </h2>
            <p className="text-slate-300 text-sm sm:text-base mt-4 max-w-2xl mx-auto leading-relaxed">
              O‘zbekiston ta’lim tizimidagi eng o‘tkir to‘siqlarni sun’iy intellekt va adaptiv pedagogika orqali hal qilamiz.
            </p>
          </motion.div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 items-stretch">
            {/* THE PROBLEM SIDE (Crimson Neon Cyber Glassmorphism) */}
            <motion.div
              initial={{ opacity: 0, x: -40 }}
              whileInView={{ opacity: 1, x: 0 }}
              viewport={{ once: true, margin: '-60px' }}
              transition={{ duration: 0.7, ease: [0.22, 1, 0.36, 1] }}
              className="p-8 sm:p-10 rounded-3xl bg-gradient-to-b from-rose-950/40 via-slate-900/80 to-slate-950/90 border border-rose-500/30 shadow-[0_0_50px_-15px_rgba(244,63,94,0.35)] relative overflow-hidden flex flex-col justify-between group hover:border-rose-500/60 transition-all duration-300 backdrop-blur-2xl"
            >
              {/* Corner ambient orb */}
              <div className="absolute top-0 right-0 w-48 h-48 bg-rose-500/10 rounded-full blur-3xl pointer-events-none group-hover:bg-rose-500/20 transition-all" />

              <div>
                <div className="flex items-center gap-4 mb-6">
                  <div className="w-12 h-12 rounded-2xl bg-rose-500/20 text-rose-400 border border-rose-500/40 flex items-center justify-center font-black text-2xl shadow-[0_0_20px_rgba(244,63,94,0.4)]">
                    <X className="w-6 h-6 stroke-[3]" />
                  </div>
                  <div>
                    <h3 className="text-2xl font-black text-white group-hover:text-rose-200 transition-colors">
                      Kritik Muammo
                    </h3>
                    <p className="text-xs text-rose-400 font-semibold tracking-wide">
                      An’anaviy ta’limdagi tizimli bo‘shliqlar
                    </p>
                  </div>
                </div>

                <div className="space-y-4">
                  {[
                    {
                      num: '1',
                      title: '35–40 talik ommaviy sinflar',
                      desc: 'O‘qituvchi 45 daqiqada har bir o‘quvchiga 1 daqiqa ham vaqt ajrata olmaydi. Barcha o‘quvchilar bitta sur’atda o‘qitiladi.',
                    },
                    {
                      num: '2',
                      title: 'Qimmat repetitorlar (500K – 1.5M so‘m/oy)',
                      desc: 'Oilalar byudjetiga og‘ir. Qishloq va tumanlarda esa malakali, ixtisoslashgan ustozlar umuman yetishmaydi.',
                    },
                    {
                      num: '3',
                      title: 'Quruq, tushunarsiz testlar',
                      desc: 'O‘quvchi xato qilganda nega xato qilganini tushuntiradigan hech kim yo‘q. Faqat quruq "noto‘g‘ri" degan ball qo‘yiladi.',
                    },
                    {
                      num: '4',
                      title: 'Bo‘shliqlarning to‘planib borishi',
                      desc: '5-sinfda kasrlarni tushunmagan o‘quvchi 8-sinfda algebra va geometriyani butunlay o‘zlashtira olmay qoladi.',
                    },
                  ].map((item, idx) => (
                    <motion.div
                      key={item.num}
                      initial={{ opacity: 0, y: 15 }}
                      whileInView={{ opacity: 1, y: 0 }}
                      viewport={{ once: true }}
                      transition={{ delay: 0.1 * idx, duration: 0.5 }}
                      whileHover={{ x: 4 }}
                      className="p-4 rounded-2xl bg-slate-900/90 border border-rose-500/20 hover:border-rose-400/50 shadow-sm transition-all"
                    >
                      <h4 className="font-bold text-sm text-slate-100 flex items-center gap-2.5">
                        <span className="w-5 h-5 rounded-md bg-rose-500/20 text-rose-400 font-black text-xs flex items-center justify-center border border-rose-500/40">
                          {item.num}
                        </span>
                        {item.title}
                      </h4>
                      <p className="text-xs text-slate-400 mt-1.5 pl-7 leading-relaxed">
                        {item.desc}
                      </p>
                    </motion.div>
                  ))}
                </div>
              </div>

              <div className="mt-8 pt-4 border-t border-rose-500/20 flex items-center justify-between text-xs text-rose-300">
                <span className="font-mono text-[11px]">Natija: 73% o‘quvchi bazaviy formulalarda adashadi</span>
                <span className="px-2.5 py-0.5 rounded-full bg-rose-500/20 text-rose-300 font-bold border border-rose-500/30 text-[10px]">
                  Eski Metodika
                </span>
              </div>
            </motion.div>

            {/* THE SOLUTION SIDE (Electric Cyan Cyber Glassmorphism) */}
            <motion.div
              initial={{ opacity: 0, x: 40 }}
              whileInView={{ opacity: 1, x: 0 }}
              viewport={{ once: true, margin: '-60px' }}
              transition={{ duration: 0.7, ease: [0.22, 1, 0.36, 1] }}
              className="p-8 sm:p-10 rounded-3xl bg-gradient-to-b from-cyan-950/40 via-slate-900/80 to-slate-950/90 border border-cyan-500/30 shadow-[0_0_50px_-15px_rgba(6,182,212,0.35)] relative overflow-hidden flex flex-col justify-between group hover:border-cyan-400/60 transition-all duration-300 backdrop-blur-2xl"
            >
              {/* Corner ambient orb */}
              <div className="absolute top-0 right-0 w-48 h-48 bg-cyan-500/10 rounded-full blur-3xl pointer-events-none group-hover:bg-cyan-500/20 transition-all" />

              <div>
                <div className="flex items-center gap-4 mb-6">
                  <div className="w-12 h-12 rounded-2xl bg-cyan-500/20 text-cyan-300 border border-cyan-500/40 flex items-center justify-center font-black text-2xl shadow-[0_0_20px_rgba(6,182,212,0.4)]">
                    <Check className="w-6 h-6 stroke-[3]" />
                  </div>
                  <div>
                    <h3 className="text-2xl font-black text-white group-hover:text-cyan-200 transition-colors">
                      BilimYo‘l Yechimi
                    </h3>
                    <p className="text-xs text-cyan-400 font-semibold tracking-wide">
                      Sun’iy intellektga asoslangan shaxsiy ekotizim
                    </p>
                  </div>
                </div>

                <div className="space-y-4">
                  {[
                    {
                      num: '1',
                      title: '100% Adaptiv Diagnostika',
                      desc: '8 ta moslashuvchan test orqali o‘quvchining har bir ko‘nikmasi (Algebra, Tenglama, Funksiya, Lug‘at va h.k.) 0-100% shkalada aniqlanadi.',
                    },
                    {
                      num: '2',
                      title: '"Yo‘lchi AI" Do‘stona Mentori',
                      desc: 'Google Gemini 2.5 Flash bilan qurollangan mentor bolaga tayyor javobni emas, xatoning tub sababini pedagogik uslubda tushuntiradi.',
                    },
                    {
                      num: '3',
                      title: 'Individual 3 Qadamli Darslar',
                      desc: 'Zaif nuqta aniqlanishi bilan AI u uchun maxsus dars yaratadi: 1) Qisqa tushuncha; 2) Vizual model / audio to‘lqin; 3) Interaktiv mustahkamlash.',
                    },
                    {
                      num: '4',
                      title: 'Hamyonbop va Har Doim Yoningizda',
                      desc: 'Oyiga atigi 59 900 so‘m. Web va Flutter Mobile orqali har qanday telefonda 24/7 ishlaydi.',
                    },
                  ].map((item, idx) => (
                    <motion.div
                      key={item.num}
                      initial={{ opacity: 0, y: 15 }}
                      whileInView={{ opacity: 1, y: 0 }}
                      viewport={{ once: true }}
                      transition={{ delay: 0.1 * idx, duration: 0.5 }}
                      whileHover={{ x: 4 }}
                      className="p-4 rounded-2xl bg-slate-900/90 border border-cyan-500/20 hover:border-cyan-400/50 shadow-sm transition-all"
                    >
                      <h4 className="font-bold text-sm text-slate-100 flex items-center gap-2.5">
                        <span className="w-5 h-5 rounded-md bg-cyan-500/20 text-cyan-300 font-black text-xs flex items-center justify-center border border-cyan-500/40">
                          {item.num}
                        </span>
                        {item.title}
                      </h4>
                      <p className="text-xs text-slate-300 mt-1.5 pl-7 leading-relaxed">
                        {item.desc}
                      </p>
                    </motion.div>
                  ))}
                </div>
              </div>

              <div className="mt-8 pt-4 border-t border-cyan-500/20 flex items-center justify-between text-xs text-cyan-300">
                <span className="font-mono text-[11px]">Natija: 1 oyda +28% bilim o‘sishi va doimiy streak</span>
                <span className="px-2.5 py-0.5 rounded-full bg-cyan-500/20 text-cyan-300 font-bold border border-cyan-500/30 text-[10px]">
                  Innovatsion AI Model
                </span>
              </div>
            </motion.div>
          </div>
        </section>

        {/* 4. SECTION 2: JAMOA (TEAM) • AXION JAMOA */}
        <section id="axion-jamoa" className="py-20 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-white/10">
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: '-80px' }}
            transition={{ duration: 0.6 }}
            className="text-center max-w-3xl mx-auto mb-16"
          >
            <span className="inline-flex items-center gap-1.5 px-3.5 py-1 rounded-full bg-purple-500/15 text-purple-300 border border-purple-500/30 text-xs font-black tracking-widest uppercase shadow-[0_0_15px_rgba(168,85,247,0.25)]">
              <Users className="w-3.5 h-3.5 text-purple-400" />
              2. ASOSIY BOSQICH • AXION JAMOA
            </span>
            <h2 className="text-3xl sm:text-5xl font-black text-white mt-3 tracking-tight">
              Bizning Jamoa (Axion) — 3 Ta Asosiy Ustun
            </h2>
            <p className="text-slate-300 text-sm sm:text-base mt-4 max-w-2xl mx-auto leading-relaxed">
              Texnologik arxitektura, biznes o‘sish strategiyasi va pedagogik metodologiyani yagona maqsad atrofida birlashtirgan asoschilar jamoasi.
            </p>
          </motion.div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            {/* Member 1: Founder & Lead Developer */}
            <motion.div
              whileHover={{ y: -8, scale: 1.01 }}
              transition={{ duration: 0.3 }}
              className="p-8 rounded-3xl bg-slate-900/80 border border-cyan-500/30 flex flex-col justify-between hover:border-cyan-400/80 shadow-[0_0_35px_-10px_rgba(6,182,212,0.25)] relative overflow-hidden group backdrop-blur-xl"
            >
              <div className="absolute top-0 right-0 w-36 h-36 bg-cyan-500/10 rounded-full blur-2xl -mr-10 -mt-10 pointer-events-none group-hover:bg-cyan-500/20 transition-all" />
              <div>
                <div className="flex items-center gap-4 mb-6">
                  <div className="relative">
                    <img
                      src="/images/team/oktam_pirimov.jpg"
                      alt="Pirimov O‘ktam"
                      className="w-20 h-20 rounded-2xl object-cover ring-2 ring-cyan-500 shadow-md"
                    />
                    <span className="absolute -bottom-2 -right-2 px-2 py-0.5 rounded-full bg-cyan-500 text-slate-950 text-[10px] font-black uppercase tracking-wider shadow-sm">
                      👑 Lead
                    </span>
                  </div>
                  <div>
                    <h3 className="text-xl font-bold text-white group-hover:text-cyan-300 transition-colors">
                      Pirimov O‘ktam
                    </h3>
                    <p className="text-xs text-cyan-400 font-bold mt-0.5">Founder & Lead Developer</p>
                    <span className="inline-block mt-1 text-[11px] text-slate-400">Arxitektura & Muhandislik</span>
                  </div>
                </div>

                <p className="text-xs text-slate-300 leading-relaxed">
                  BilimYo‘l ekotizimining asoschisi va bosh arxitektori. Web va Mobile ilovalar (React 19, Flutter), server-side anti-cheat scoring (PostgreSQL RPC) hamda Gemini AI (Yo‘lchi) Edge integratsiyasini to‘liq noldan yaratgan.
                </p>

                <div className="mt-6 pt-4 border-t border-white/10 space-y-2">
                  <div className="text-[11px] text-slate-400 font-bold uppercase tracking-wider">Asosiy Ko‘nikmalar:</div>
                  <div className="flex flex-wrap gap-1.5 text-[10px]">
                    <span className="px-2.5 py-1 rounded-lg bg-cyan-500/15 text-cyan-300 border border-cyan-500/30 font-semibold">Tizim Arxitekturasi</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-800 text-slate-300">React 19 & TS</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-800 text-slate-300">Flutter 3.x</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-800 text-slate-300">PostgreSQL RPC</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-800 text-slate-300">Gemini 2.5 Flash</span>
                  </div>
                </div>
              </div>

              <div className="mt-6 flex items-center justify-between pt-4 border-t border-white/10 text-xs">
                <div className="flex items-center gap-3">
                  <a
                    href="https://github.com/pirimovuktam"
                    target="_blank"
                    rel="noreferrer"
                    className="text-slate-300 hover:text-white flex items-center gap-1 font-bold transition-colors"
                  >
                    <ExternalLink className="w-3.5 h-3.5 text-cyan-400" /> GitHub
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
                <span className="text-[10px] text-emerald-400 font-mono font-bold bg-emerald-500/15 px-2 py-0.5 rounded-md border border-emerald-500/30">
                  152 Web • 48 Mob Tests
                </span>
              </div>
            </motion.div>

            {/* Member 2: Business & Growth Lead */}
            <motion.div
              whileHover={{ y: -8, scale: 1.01 }}
              transition={{ duration: 0.3 }}
              className="p-8 rounded-3xl bg-slate-900/80 border border-purple-500/30 flex flex-col justify-between hover:border-purple-400/80 shadow-[0_0_35px_-10px_rgba(168,85,247,0.25)] relative overflow-hidden group backdrop-blur-xl"
            >
              <div className="absolute top-0 right-0 w-36 h-36 bg-purple-500/10 rounded-full blur-2xl -mr-10 -mt-10 pointer-events-none group-hover:bg-purple-500/20 transition-all" />
              <div>
                <div className="flex items-center gap-4 mb-6">
                  <div className="relative">
                    <div className="w-20 h-20 rounded-2xl bg-gradient-to-tr from-purple-600 to-indigo-600 flex items-center justify-center text-white shadow-md ring-2 ring-purple-400">
                      <Briefcase className="w-10 h-10 text-purple-100" />
                    </div>
                    <span className="absolute -bottom-2 -right-2 px-2 py-0.5 rounded-full bg-purple-600 text-white text-[10px] font-black uppercase tracking-wider shadow-sm">
                      🚀 Growth
                    </span>
                  </div>
                  <div>
                    <h3 className="text-xl font-bold text-white group-hover:text-purple-300 transition-colors">
                      Abdurauf Normuminov
                    </h3>
                    <p className="text-xs text-purple-400 font-bold mt-0.5">Business & Growth Lead</p>
                    <span className="inline-block mt-1 text-[11px] text-slate-400">Bozor & Hamkorliklar</span>
                  </div>
                </div>

                <p className="text-xs text-slate-300 leading-relaxed">
                  Biznes modelni shakllantirish, bozorga chiqish (Go-To-Market) strategiyasi, maktablar va o‘quv markazlari bilan B2B hamkorlik hamda foydalanuvchilar oqimini (traction) kengaytirish rahbari.
                </p>

                <div className="mt-6 pt-4 border-t border-white/10 space-y-2">
                  <div className="text-[11px] text-slate-400 font-bold uppercase tracking-wider">Asosiy Ko‘nikmalar:</div>
                  <div className="flex flex-wrap gap-1.5 text-[10px]">
                    <span className="px-2.5 py-1 rounded-lg bg-purple-500/15 text-purple-300 border border-purple-500/30 font-semibold">EdTech GTM Strategiyasi</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-800 text-slate-300">B2B Maktablar</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-800 text-slate-300">Unit Economics</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-800 text-slate-300">Marketing Funnels</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-800 text-slate-300">Investor Relations</span>
                  </div>
                </div>
              </div>

              <div className="mt-6 flex items-center justify-between pt-4 border-t border-white/10 text-xs">
                <div className="flex items-center gap-2 text-purple-400 font-bold">
                  <TrendingUp className="w-3.5 h-3.5" />
                  <span>EdTech Growth Strategy</span>
                </div>
                <span className="text-[10px] text-purple-300 font-mono font-bold bg-purple-500/15 px-2 py-0.5 rounded-md border border-purple-500/30">
                  B2B & B2C Focus
                </span>
              </div>
            </motion.div>

            {/* Member 3: Education & Product Lead */}
            <motion.div
              whileHover={{ y: -8, scale: 1.01 }}
              transition={{ duration: 0.3 }}
              className="p-8 rounded-3xl bg-slate-900/80 border border-emerald-500/30 flex flex-col justify-between hover:border-emerald-400/80 shadow-[0_0_35px_-10px_rgba(16,185,129,0.25)] relative overflow-hidden group backdrop-blur-xl"
            >
              <div className="absolute top-0 right-0 w-36 h-36 bg-emerald-500/10 rounded-full blur-2xl -mr-10 -mt-10 pointer-events-none group-hover:bg-emerald-500/20 transition-all" />
              <div>
                <div className="flex items-center gap-4 mb-6">
                  <div className="relative">
                    <div className="w-20 h-20 rounded-2xl bg-gradient-to-tr from-emerald-600 to-teal-600 flex items-center justify-center text-white shadow-md ring-2 ring-emerald-400">
                      <GraduationCap className="w-10 h-10 text-emerald-100" />
                    </div>
                    <span className="absolute -bottom-2 -right-2 px-2 py-0.5 rounded-full bg-emerald-600 text-white text-[10px] font-black uppercase tracking-wider shadow-sm">
                      🎓 EdLead
                    </span>
                  </div>
                  <div>
                    <h3 className="text-xl font-bold text-white group-hover:text-emerald-300 transition-colors">
                      Hamdamova Dildora
                    </h3>
                    <p className="text-xs text-emerald-400 font-bold mt-0.5">Education & Product Lead</p>
                    <span className="inline-block mt-1 text-[11px] text-slate-400">Pedagogika & Mahsulot</span>
                  </div>
                </div>

                <p className="text-xs text-slate-300 leading-relaxed">
                  Pedagogik metodika va mahsulot arxitekturasi bo‘yicha yetakchi. Milliy ta’lim standartlari, Bloom taksonomiyasi va adaptiv diagnostika metodikasi bo‘yicha kurikulum rahbari.
                </p>

                <div className="mt-6 pt-4 border-t border-white/10 space-y-2">
                  <div className="text-[11px] text-slate-400 font-bold uppercase tracking-wider">Asosiy Ko‘nikmalar:</div>
                  <div className="flex flex-wrap gap-1.5 text-[10px]">
                    <span className="px-2.5 py-1 rounded-lg bg-emerald-500/15 text-emerald-300 border border-emerald-500/30 font-semibold">Adaptiv Kurikulum</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-800 text-slate-300">Bloom Taksonomiyasi</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-800 text-slate-300">Diagnostik Metodika</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-800 text-slate-300">O‘quvchi UX</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-800 text-slate-300">Milliy Standartlar</span>
                  </div>
                </div>
              </div>

              <div className="mt-6 flex items-center justify-between pt-4 border-t border-white/10 text-xs">
                <div className="flex items-center gap-2 text-emerald-400 font-bold">
                  <Brain className="w-3.5 h-3.5" />
                  <span>Pedagogical Standards</span>
                </div>
                <span className="text-[10px] text-emerald-400 font-mono font-bold bg-emerald-500/15 px-2 py-0.5 rounded-md border border-emerald-500/30">
                  100% Moslik
                </span>
              </div>
            </motion.div>
          </div>

          {/* Technology stack pill carousel */}
          <div className="mt-12 p-6 rounded-3xl bg-slate-900/60 border border-white/10 backdrop-blur-md flex flex-wrap items-center justify-center gap-3">
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
                className="px-3 py-1.5 rounded-xl bg-slate-800/80 border border-white/10 text-xs font-semibold text-slate-200 shadow-sm"
              >
                {tech}
              </span>
            ))}
          </div>
        </section>

        {/* 5. SECTION 3: NEGA BIZNING JAMOA BU MUAMMONI HAL QILA OLADI? */}
        <section id="nega-biz" className="py-20 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-white/10">
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: '-80px' }}
            transition={{ duration: 0.6 }}
            className="text-center max-w-3xl mx-auto mb-16"
          >
            <span className="inline-flex items-center gap-1.5 px-3.5 py-1 rounded-full bg-cyan-500/15 text-cyan-300 border border-cyan-500/30 text-xs font-black tracking-widest uppercase shadow-[0_0_15px_rgba(6,182,212,0.25)]">
              <Award className="w-3.5 h-3.5 text-cyan-400" />
              3. ASOSIY BOSQICH
            </span>
            <h2 className="text-3xl sm:text-5xl font-black text-white mt-3 tracking-tight">
              Nima Uchun Aynan Bizning Jamoa?
            </h2>
            <p className="text-slate-300 text-sm sm:text-base mt-4 max-w-2xl mx-auto leading-relaxed">
              G‘oya va slaydlar bosqichidan o‘tib, real ishlayotgan mahsulotga ega ekanligimiz — bizning asosiy ustunligimizdir.
            </p>
          </motion.div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            <motion.div
              whileHover={{ y: -6 }}
              className="p-6 rounded-3xl bg-slate-900/80 border border-cyan-500/20 hover:border-cyan-400/60 transition-all backdrop-blur-xl shadow-lg"
            >
              <div className="w-12 h-12 rounded-2xl bg-cyan-500/20 text-cyan-400 flex items-center justify-center mb-4 border border-cyan-500/30">
                <CheckCircle2 className="w-6 h-6" />
              </div>
              <h3 className="text-lg font-bold text-white mb-2">100% Ishlayotgan MVP</h3>
              <p className="text-xs text-slate-400 leading-relaxed">
                Biz quruq taqdimot bilan kelmadik. Web va Flutter Mobile ilovamiz to‘liq tayyor, 152 ta test bilan qoplangan va jonli rejimda ishlaydi.
              </p>
            </motion.div>

            <motion.div
              whileHover={{ y: -6 }}
              className="p-6 rounded-3xl bg-slate-900/80 border border-indigo-500/20 hover:border-indigo-400/60 transition-all backdrop-blur-xl shadow-lg"
            >
              <div className="w-12 h-12 rounded-2xl bg-indigo-500/20 text-indigo-400 flex items-center justify-center mb-4 border border-indigo-500/30">
                <Brain className="w-6 h-6" />
              </div>
              <h3 className="text-lg font-bold text-white mb-2">Haqiqiy Pedagogik AI</h3>
              <p className="text-xs text-slate-400 leading-relaxed">
                Oddiy ChatGPT wrapper emas. Tizim bolaga tayyor javobni aytib dangasa qilmaydi, balki ko‘nikmalar grafigi bo‘yicha tushuntiradi.
              </p>
            </motion.div>

            <motion.div
              whileHover={{ y: -6 }}
              className="p-6 rounded-3xl bg-slate-900/80 border border-emerald-500/20 hover:border-emerald-400/60 transition-all backdrop-blur-xl shadow-lg"
            >
              <div className="w-12 h-12 rounded-2xl bg-emerald-500/20 text-emerald-400 flex items-center justify-center mb-4 border border-emerald-500/30">
                <ShieldCheck className="w-6 h-6" />
              </div>
              <h3 className="text-lg font-bold text-white mb-2">Server Anti-Cheat Xavfsizligi</h3>
              <p className="text-xs text-slate-400 leading-relaxed">
                Ballar, ko‘nikmalar va XP lar to‘liq server-side hisoblanadi. O‘quvchi brauzer orqali javoblarni ko‘rib ololmaydi yoki ballni soxtalashtira olmaydi.
              </p>
            </motion.div>

            <motion.div
              whileHover={{ y: -6 }}
              className="p-6 rounded-3xl bg-slate-900/80 border border-purple-500/20 hover:border-purple-400/60 transition-all backdrop-blur-xl shadow-lg"
            >
              <div className="w-12 h-12 rounded-2xl bg-purple-500/20 text-purple-400 flex items-center justify-center mb-4 border border-purple-500/30">
                <Users className="w-6 h-6" />
              </div>
              <h3 className="text-lg font-bold text-white mb-2">3 Kishi Kuchli Sinergiyasi</h3>
              <p className="text-xs text-slate-400 leading-relaxed">
                Tizim arxitekturasi va AI muhandisligi (O‘ktam), biznes strategiyasi va B2B hamkorlik (Abdurauf) hamda pedagogik metodika (Dildora) to‘liq uyg‘unlashgan.
              </p>
            </motion.div>
          </div>
        </section>

        {/* 6. SECTION 4: MILESTONES & MONETIZATSIYA (SLIDE 06 & 03 ASOSIDA) */}
        <section id="milestones-monetizatsiya" className="py-20 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-white/10">
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: '-80px' }}
            transition={{ duration: 0.6 }}
            className="text-center max-w-3xl mx-auto mb-16"
          >
            <span className="inline-flex items-center gap-1.5 px-3.5 py-1 rounded-full bg-emerald-500/15 text-emerald-300 border border-emerald-500/30 text-xs font-black tracking-widest uppercase shadow-[0_0_15px_rgba(16,185,129,0.25)]">
              <Rocket className="w-3.5 h-3.5 text-emerald-400" />
              4. ASOSIY BOSQICH: MILESTONES & MONETIZATSIYA
            </span>
            <h2 className="text-3xl sm:text-5xl font-black text-white mt-3 tracking-tight">
              Milestones — Maqsadlar va KPI
            </h2>
            <p className="text-slate-300 text-sm sm:text-base mt-4 max-w-2xl mx-auto leading-relaxed">
              <strong className="text-white">Hozir → 6 oy → 1 yil → 3 yil.</strong> Raqamlar konservativ prognoz asosida ishlab chiqilgan.
            </p>
          </motion.div>

          {/* VISUAL TIMELINE BAR (SLIDE 06 ASOSIDA) */}
          <div className="max-w-5xl mx-auto mb-10 p-6 sm:p-8 rounded-3xl bg-slate-900/90 border border-white/10 text-white shadow-2xl relative overflow-hidden backdrop-blur-2xl">
            <div className="text-xs font-mono font-bold text-slate-400 mb-6 flex items-center justify-between">
              <span className="flex items-center gap-2">
                <span className="w-2.5 h-2.5 rounded-full bg-rose-500 animate-pulse" />
                Vaqt O‘qi: Hozir → 6 oy → 1 yil → 3 yil
              </span>
              <span className="text-amber-400 text-[11px] font-bold">Konservativ Prognoz</span>
            </div>

            {/* Connecting Timeline Line */}
            <div className="hidden lg:block absolute left-12 right-12 top-[125px] h-1 bg-gradient-to-r from-rose-500 via-amber-500 via-blue-500 to-emerald-500 rounded-full" />

            {/* 4 Timeline Stage Cards */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 relative z-10">
              {/* STAGE 1: HOZIR */}
              <button
                onClick={() => setActiveRoadmapStage('now')}
                className={`p-4 rounded-2xl text-left border transition-all cursor-pointer flex flex-col justify-between ${
                  activeRoadmapStage === 'now'
                    ? 'bg-rose-950/80 border-rose-500 shadow-lg shadow-rose-950/50 scale-[1.02]'
                    : 'bg-slate-800/80 border-slate-700 hover:border-slate-500 text-slate-300'
                }`}
              >
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-xs font-black uppercase text-rose-400">1-BOSQICH</span>
                    <span className="w-3.5 h-3.5 rounded-full bg-rose-500 border-2 border-white shadow-sm" />
                  </div>
                  <h3 className="text-base font-black text-white">HOZIR</h3>
                  <div className="mt-3 space-y-1.5 text-[11px] text-slate-300 leading-snug">
                    <div className="flex items-start gap-1.5 font-medium">
                      <span className="text-rose-400">•</span> MVP + pilot bosqich
                    </div>
                    <div className="flex items-start gap-1.5 font-medium">
                      <span className="text-rose-400">•</span> Asosiy o‘rganishning moslashuvchan oqimi
                    </div>
                    <div className="flex items-start gap-1.5 font-medium">
                      <span className="text-rose-400">•</span> Dastlabki foydalanuvchilar
                    </div>
                  </div>
                </div>
                <div className="mt-4 pt-3 border-t border-white/10 text-[10px] text-rose-300 font-bold flex items-center justify-between">
                  <span>Jonli Ishlamoqda</span>
                  <span>Okt 2026</span>
                </div>
              </button>

              {/* STAGE 2: 6 OY */}
              <button
                onClick={() => setActiveRoadmapStage('6months')}
                className={`p-4 rounded-2xl text-left border transition-all cursor-pointer flex flex-col justify-between ${
                  activeRoadmapStage === '6months'
                    ? 'bg-amber-950/80 border-amber-500 shadow-lg shadow-amber-950/50 scale-[1.02]'
                    : 'bg-slate-800/80 border-slate-700 hover:border-slate-500 text-slate-300'
                }`}
              >
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-xs font-black uppercase text-amber-400">2-BOSQICH</span>
                    <span className="w-3.5 h-3.5 rounded-full bg-amber-500 border-2 border-white shadow-sm" />
                  </div>
                  <h3 className="text-base font-black text-white">6 OY</h3>
                  <div className="mt-3 space-y-1.5 text-[11px] text-slate-300 leading-snug">
                    <div className="flex items-start gap-1.5 font-bold text-amber-300">
                      <span>•</span> 500–700 pullik foydalanuvchi
                    </div>
                    <div className="flex items-start gap-1.5 font-medium">
                      <span className="text-amber-400">•</span> Mahsulotning bozorga mos kelishi (PMF)
                    </div>
                    <div className="flex items-start gap-1.5 font-medium">
                      <span className="text-amber-400">•</span> Takroriy mijozlarni jalb qilish
                    </div>
                    <div className="flex items-start gap-1.5 font-medium">
                      <span className="text-amber-400">•</span> Birinchi B2B pilot
                    </div>
                  </div>
                </div>
                <div className="mt-4 pt-3 border-t border-white/10 text-[10px] text-amber-300 font-bold flex items-center justify-between">
                  <span>Product-Market Fit</span>
                  <span>Apr 2027</span>
                </div>
              </button>

              {/* STAGE 3: 1 YIL */}
              <button
                onClick={() => setActiveRoadmapStage('1year')}
                className={`p-4 rounded-2xl text-left border transition-all cursor-pointer flex flex-col justify-between ${
                  activeRoadmapStage === '1year'
                    ? 'bg-blue-950/80 border-blue-500 shadow-lg shadow-blue-950/50 scale-[1.02]'
                    : 'bg-slate-800/80 border-slate-700 hover:border-slate-500 text-slate-300'
                }`}
              >
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-xs font-black uppercase text-blue-400">3-BOSQICH</span>
                    <span className="w-3.5 h-3.5 rounded-full bg-blue-500 border-2 border-white shadow-sm" />
                  </div>
                  <h3 className="text-base font-black text-white">1 YIL</h3>
                  <div className="mt-3 space-y-1.5 text-[11px] text-slate-300 leading-snug">
                    <div className="flex items-start gap-1.5 font-bold text-blue-300">
                      <span>•</span> 2 500 pullik foydalanuvchi
                    </div>
                    <div className="flex items-start gap-1.5 font-bold text-emerald-400">
                      <span>•</span> ≈ 638 mln so‘m gross revenue
                    </div>
                    <div className="flex items-start gap-1.5 font-bold text-cyan-300">
                      <span>•</span> Zararsizlik nuqtasi ≈ 10-oy
                    </div>
                  </div>
                </div>
                <div className="mt-4 pt-3 border-t border-white/10 text-[10px] text-blue-300 font-bold flex items-center justify-between">
                  <span>Break-Even (10-oy)</span>
                  <span>Okt 2027</span>
                </div>
              </button>

              {/* STAGE 4: 3 YIL */}
              <button
                onClick={() => setActiveRoadmapStage('3years')}
                className={`p-4 rounded-2xl text-left border transition-all cursor-pointer flex flex-col justify-between ${
                  activeRoadmapStage === '3years'
                    ? 'bg-emerald-950/80 border-emerald-500 shadow-lg shadow-emerald-950/50 scale-[1.02]'
                    : 'bg-slate-800/80 border-slate-700 hover:border-slate-500 text-slate-300'
                }`}
              >
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-xs font-black uppercase text-emerald-400">4-BOSQICH</span>
                    <span className="w-3.5 h-3.5 rounded-full bg-emerald-500 border-2 border-white shadow-sm" />
                  </div>
                  <h3 className="text-base font-black text-white">3 YIL</h3>
                  <div className="mt-3 space-y-1.5 text-[11px] text-slate-300 leading-snug">
                    <div className="flex items-start gap-1.5 font-medium">
                      <span className="text-emerald-400">•</span> O‘zbekiston bo‘ylab masshtab
                    </div>
                    <div className="flex items-start gap-1.5 font-medium">
                      <span className="text-emerald-400">•</span> B2B: maktab va o‘quv markazi
                    </div>
                    <div className="flex items-start gap-1.5 font-medium">
                      <span className="text-emerald-400">•</span> Yangi fanlar, regional expansion
                    </div>
                  </div>
                </div>
                <div className="mt-4 pt-3 border-t border-white/10 text-[10px] text-emerald-300 font-bold flex items-center justify-between">
                  <span>Respublika & Region</span>
                  <span>2029-yil</span>
                </div>
              </button>
            </div>

            {/* Footnote */}
            <div className="mt-6 pt-4 border-t border-white/10 flex flex-col sm:flex-row items-center justify-between gap-2 text-[11px] text-slate-400 italic">
              <span>* 1-yil raqamlari konservativ forecast; 3-yil ko‘rsatkichlari — target, fakt emas.</span>
              <span className="not-italic font-mono text-[10px] text-cyan-400 font-bold">
                Tugmalarni bosib har bir bosqichning batafsil rejasini oching ↑
              </span>
            </div>
          </div>

          {/* DETAILED STAGE EXPLORATION CARD */}
          <div className="p-8 sm:p-10 rounded-3xl bg-slate-900/90 border border-white/10 max-w-5xl mx-auto shadow-2xl mb-12 backdrop-blur-2xl">
            {activeRoadmapStage === 'now' && (
              <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="space-y-6">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-white/10 pb-4">
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="w-2.5 h-2.5 rounded-full bg-rose-500 animate-pulse" />
                      <h3 className="text-xl font-black text-white">
                        1-Bosqich: HOZIR (MVP + Pilot Bosqich)
                      </h3>
                    </div>
                    <p className="text-xs text-slate-400 mt-1 flex items-center gap-3">
                      <span className="flex items-center gap-1 font-semibold text-rose-300">
                        <Calendar className="w-3.5 h-3.5" /> 12-Sentabr – 11-Oktyabr 2026 (Pitch Day 3.0)
                      </span>
                      <span className="flex items-center gap-1 font-bold text-emerald-300 bg-emerald-500/15 px-2 py-0.5 rounded border border-emerald-500/30">
                        Asoschilar Mablag‘i
                      </span>
                    </p>
                  </div>
                  <span className="px-3.5 py-1.5 rounded-full bg-rose-500/20 text-rose-300 border border-rose-500/30 text-xs font-black self-start sm:self-auto">
                    100% Jonli Ishlamoqda
                  </span>
                </div>

                <p className="text-slate-300 text-sm leading-relaxed">
                  Platformaning dastlabki <strong>G‘oya (Idea)</strong> va <strong>Prototip (Prototype)</strong> bosqichlari to‘liq yakunlandi. Bugungi kunda BilimYo‘l Smart Edu to‘liq ishlayotgan <strong>MVP holatida</strong>: Web SPA (React 19) va Mobil (Flutter) ilovalari, adaptiv diagnostika, server-side anti-cheat scoring (PostgreSQL RPC) va Gemini 2.5 Flash bilan integratsiyalashgan Yo‘lchi AI mentori amalda sinovdan o‘tmoqda.
                </p>

                <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 pt-1">
                  <div className="p-4 rounded-2xl bg-slate-800/80 border border-white/10 space-y-1">
                    <div className="text-xs font-black text-white flex items-center gap-1.5">
                      <CheckCircle2 className="w-4 h-4 text-rose-400" /> MVP + Pilot
                    </div>
                    <p className="text-[11px] text-slate-400">
                      Matematika va Ingliz tili fanlari to‘liq integratsiyalangan, 152 ta avtotestlar bilan himoyalangan.
                    </p>
                  </div>

                  <div className="p-4 rounded-2xl bg-slate-800/80 border border-white/10 space-y-1">
                    <div className="text-xs font-black text-white flex items-center gap-1.5">
                      <CheckCircle2 className="w-4 h-4 text-rose-400" /> Moslashuvchan Oqim
                    </div>
                    <p className="text-[11px] text-slate-400">
                      Asosiy o‘rganishning moslashuvchan oqimi: diagnostika → bilim matritsasi (0-100%) → individual dars.
                    </p>
                  </div>

                  <div className="p-4 rounded-2xl bg-slate-800/80 border border-white/10 space-y-1">
                    <div className="text-xs font-black text-white flex items-center gap-1.5">
                      <CheckCircle2 className="w-4 h-4 text-rose-400" /> Dastlabki Foydalanuvchilar
                    </div>
                    <p className="text-[11px] text-slate-400">
                      Dastlabki o‘quvchilar va repetitorlar platformani test qilmoqda, haftalik fikr-mulohazalar yig‘ilmoqda.
                    </p>
                  </div>
                </div>
              </motion.div>
            )}

            {activeRoadmapStage === '6months' && (
              <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="space-y-6">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-white/10 pb-4">
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="w-2.5 h-2.5 rounded-full bg-amber-500 animate-pulse" />
                      <h3 className="text-xl font-black text-white">
                        2-Bosqich: 6 OY (Bozorga Moslik & Birinchi B2B Pilot)
                      </h3>
                    </div>
                    <p className="text-xs text-slate-400 mt-1 flex items-center gap-3">
                      <span className="flex items-center gap-1 font-semibold text-amber-300">
                        <Clock className="w-3.5 h-3.5" /> Muddat: 6 oy (Noyabr 2026 – Aprel 2027)
                      </span>
                      <span className="flex items-center gap-1 font-bold text-indigo-300 bg-indigo-500/15 px-2 py-0.5 rounded border border-indigo-500/30">
                        Pre-Seed Bosqichi
                      </span>
                    </p>
                  </div>
                  <span className="px-3.5 py-1.5 rounded-full bg-amber-500/20 text-amber-300 border border-amber-500/30 text-xs font-black self-start sm:self-auto">
                    Keyingi 6 Oylik Reja
                  </span>
                </div>

                <p className="text-slate-300 text-sm leading-relaxed">
                  Asosiy diqqat mahsulotning bozorga to‘liq mos kelishiga (<strong>Product-Market Fit</strong>) qaratiladi. B2C segmentida dastlabki <strong>500–700 nafar pullik faol obunachilar</strong> shakllantiriladi, o‘quvchilarning saqlanib qolish ko‘rsatkichi (Retention) oshiriladi va dastlabki B2B maktablar bilan pilot litsenziyalar yo‘lga qo‘yiladi.
                </p>

                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
                  <div className="p-4 rounded-2xl bg-amber-500/10 border border-amber-500/30 text-center">
                    <div className="text-xl sm:text-2xl font-black text-amber-300">500–700</div>
                    <div className="text-xs font-bold text-white mt-0.5">Pullik Foydalanuvchi</div>
                    <div className="text-[10px] text-slate-400">Oyiga 59 900 so‘m</div>
                  </div>

                  <div className="p-4 rounded-2xl bg-slate-800/80 border border-white/10 text-center">
                    <div className="text-xl sm:text-2xl font-black text-indigo-400">PMF</div>
                    <div className="text-xs font-bold text-white mt-0.5">Bozorga Mos Kelish</div>
                    <div className="text-[10px] text-slate-400">Haftalik o‘sish va tahlil</div>
                  </div>

                  <div className="p-4 rounded-2xl bg-slate-800/80 border border-white/10 text-center">
                    <div className="text-xl sm:text-2xl font-black text-emerald-400">Takroriy Jalb</div>
                    <div className="text-xs font-bold text-white mt-0.5">Retention & Streak</div>
                    <div className="text-[10px] text-slate-400">Muntazam ta’lim odati</div>
                  </div>

                  <div className="p-4 rounded-2xl bg-slate-800/80 border border-white/10 text-center">
                    <div className="text-xl sm:text-2xl font-black text-cyan-400">1-B2B Pilot</div>
                    <div className="text-xs font-bold text-white mt-0.5">Maktablar Hamkorligi</div>
                    <div className="text-[10px] text-slate-400">O‘qituvchilar paneli</div>
                  </div>
                </div>
              </motion.div>
            )}

            {activeRoadmapStage === '1year' && (
              <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="space-y-6">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-white/10 pb-4">
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="w-2.5 h-2.5 rounded-full bg-blue-500 animate-pulse" />
                      <h3 className="text-xl font-black text-white">
                        3-Bosqich: 1 YIL (Zararsizlik Nuqtasi & 638 Mln Gross Revenue)
                      </h3>
                    </div>
                    <p className="text-xs text-slate-400 mt-1 flex items-center gap-3">
                      <span className="flex items-center gap-1 font-semibold text-blue-300">
                        <Calendar className="w-3.5 h-3.5" /> Muddat: 12 oy (Oktabr 2027 gacha)
                      </span>
                      <span className="flex items-center gap-1 font-bold text-emerald-300 bg-emerald-500/15 px-2 py-0.5 rounded border border-emerald-500/30">
                        Konservativ Iqtisodiy Prognoz
                      </span>
                    </p>
                  </div>
                  <span className="px-3.5 py-1.5 rounded-full bg-blue-500/20 text-blue-300 border border-blue-500/30 text-xs font-black self-start sm:self-auto">
                    Zararsizlik: 10-oy
                  </span>
                </div>

                <p className="text-slate-300 text-sm leading-relaxed">
                  Konservativ moliyaviy model asosida 1-yil yakuniga borib platforma <strong>2 500 nafar faol pullik o‘quvchiga</strong> va yil bo‘yicha jami <strong>≈638 million so‘m gross revenue</strong>ga yetadi. Operatsion xarajatlar va daromadlar nisbati bo‘yicha <strong>zararsizlik nuqtasiga (Break-even) taxminan 10-oyda</strong> erishiladi.
                </p>

                <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                  <div className="p-5 rounded-2xl bg-blue-500/10 border border-blue-500/30 text-center">
                    <div className="text-2xl sm:text-3xl font-black text-blue-300">2 500</div>
                    <div className="text-xs font-bold text-white mt-1">Pullik Foydalanuvchi</div>
                    <div className="text-[11px] text-slate-400 mt-0.5">B2C oylik faol obuna</div>
                  </div>

                  <div className="p-5 rounded-2xl bg-emerald-500/10 border border-emerald-500/30 text-center">
                    <div className="text-2xl sm:text-3xl font-black text-emerald-300">≈ 638 Mln</div>
                    <div className="text-xs font-bold text-white mt-1">Gross Revenue (So‘m)</div>
                    <div className="text-[11px] text-slate-400 mt-0.5">Yillik yalpi tushum</div>
                  </div>

                  <div className="p-5 rounded-2xl bg-purple-500/10 border border-purple-500/30 text-center">
                    <div className="text-2xl sm:text-3xl font-black text-purple-300">10-oy</div>
                    <div className="text-xs font-bold text-white mt-1">Zararsizlik Nuqtasi</div>
                    <div className="text-[11px] text-slate-400 mt-0.5">O‘zini-o‘zi to‘liq qoplash</div>
                  </div>
                </div>
              </motion.div>
            )}

            {activeRoadmapStage === '3years' && (
              <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="space-y-6">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-white/10 pb-4">
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="w-2.5 h-2.5 rounded-full bg-emerald-500 animate-pulse" />
                      <h3 className="text-xl font-black text-white">
                        4-Bosqich: 3 YIL (Respublika Masshtabi & Regional Ekspansiya)
                      </h3>
                    </div>
                    <p className="text-xs text-slate-400 mt-1 flex items-center gap-3">
                      <span className="flex items-center gap-1 font-semibold text-emerald-300">
                        <Calendar className="w-3.5 h-3.5" /> Uzoq Muddatli Strategik Maqsad (Target)
                      </span>
                      <span className="flex items-center gap-1 text-slate-400 text-[11px]">
                        2028–2029 Yillar
                      </span>
                    </p>
                  </div>
                  <span className="px-3.5 py-1.5 rounded-full bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 text-xs font-black self-start sm:self-auto">
                    Kengayish Bosqichi
                  </span>
                </div>

                <p className="text-slate-300 text-sm leading-relaxed">
                  BilimYo‘l Smart Edu butun O‘zbekiston bo‘ylab maktablar, o‘quv markazlari va ota-onalar uchun yagona milliy adaptiv ta’lim standartiga aylanadi. B2B korporativ paketlar, yangi maktab fanlari va Markaziy Osiyo (Qozog‘iston, Qirg‘iziston) mintaqasiga lokalizatsiya orqali ekspansiya qilinadi.
                </p>

                <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                  <div className="p-4 rounded-2xl bg-emerald-500/10 border border-emerald-500/30 space-y-1">
                    <div className="text-xs font-black text-white flex items-center gap-1.5">
                      <Globe className="w-4 h-4 text-emerald-400" /> O‘zbekiston Bo‘ylab Masshtab
                    </div>
                    <p className="text-[11px] text-slate-400">
                      Barcha viloyatlar va tuman maktablari o‘quvchilariga yetib borish, keng qamrovli B2C auditoriya.
                    </p>
                  </div>

                  <div className="p-4 rounded-2xl bg-emerald-500/10 border border-emerald-500/30 space-y-1">
                    <div className="text-xs font-black text-white flex items-center gap-1.5">
                      <Briefcase className="w-4 h-4 text-emerald-400" /> B2B: Maktab & O‘quv Markazi
                    </div>
                    <p className="text-[11px] text-slate-400">
                      Maktab va xususiy o‘quv markazlari uchun o‘quvchilar bilimini avtomatik diagnostika qiluvchi SaaS obunasi.
                    </p>
                  </div>

                  <div className="p-4 rounded-2xl bg-emerald-500/10 border border-emerald-500/30 space-y-1">
                    <div className="text-xs font-black text-white flex items-center gap-1.5">
                      <Layers className="w-4 h-4 text-emerald-400" /> Yangi Fanlar & Regional
                    </div>
                    <p className="text-[11px] text-slate-400">
                      Fizika, Kimyo, Biologiya, IT fanlari qo‘shilishi hamda Markaziy Osiyo bozorlariga regional chiqish.
                    </p>
                  </div>
                </div>
              </motion.div>
            )}
          </div>

          {/* MONETIZATSIYA VA UNIT ECONOMICS BLOKI (SLIDE 03 ASOSIDA) */}
          <div className="max-w-5xl mx-auto p-8 sm:p-10 rounded-3xl bg-slate-900/90 border border-emerald-500/30 text-white shadow-[0_0_50px_-15px_rgba(16,185,129,0.3)] relative overflow-hidden backdrop-blur-2xl">
            <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-white/10 pb-6 mb-8">
              <div>
                <span className="text-emerald-400 text-xs font-black tracking-widest uppercase flex items-center gap-2">
                  <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" /> BIZNES VA DAROMAD MODELI
                </span>
                <h3 className="text-2xl sm:text-4xl font-black text-white mt-1">
                  Monetizatsiya va Unit Economics
                </h3>
                <p className="text-slate-300 text-xs sm:text-sm mt-1">
                  Freemium → Premium obuna. To‘lovchi: o‘quvchi va ota-ona (B2C).
                </p>
              </div>

              <div className="self-start md:self-auto">
                <span className="px-3.5 py-1.5 rounded-full bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 text-xs font-bold">
                  B2C + B2B SaaS Modeli
                </span>
              </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center">
              {/* Left Pricing Card (Slide 03 style) */}
              <div className="lg:col-span-5 p-6 sm:p-8 rounded-2xl bg-black/60 border-2 border-emerald-500/60 shadow-[0_0_30px_rgba(16,185,129,0.25)] text-center space-y-3 relative group">
                <div className="text-xs font-black tracking-wider uppercase text-emerald-400">
                  PREMIUM OBUNA
                </div>
                <div className="text-4xl sm:text-6xl font-black text-white tracking-tight">
                  59 900
                </div>
                <div className="text-xs text-slate-400 font-bold uppercase tracking-wider">
                  so‘m / oy
                </div>
                <div className="pt-3 border-t border-white/10 text-[11px] text-slate-300">
                  Oddiy repetitorning bitta darsi narxiga butun 1 oylik cheksiz shaxsiy repetitor va AI yo‘lchi.
                </div>
              </div>

              {/* Right Value Propositions (Slide 03 bullet items) */}
              <div className="lg:col-span-7 space-y-4">
                <div className="p-4 rounded-xl bg-white/5 border-l-4 border-emerald-500 border-r border-t border-b border-white/10 space-y-1 hover:bg-white/10 transition-colors">
                  <div className="text-xs font-bold text-emerald-400 uppercase">
                    Kim to‘laydi?
                  </div>
                  <div className="text-sm font-semibold text-white">
                    O‘quvchi va ota-ona (B2C)
                  </div>
                  <p className="text-[11px] text-slate-400">
                    Ota-onalar farzandining bilim darajasini real vaqtda ko‘rib, samarasiz repetitor xarajatlarini tejashadi.
                  </p>
                </div>

                <div className="p-4 rounded-xl bg-white/5 border-l-4 border-emerald-500 border-r border-t border-b border-white/10 space-y-1 hover:bg-white/10 transition-colors">
                  <div className="text-xs font-bold text-emerald-400 uppercase">
                    Nima uchun to‘laydi?
                  </div>
                  <div className="text-sm font-semibold text-white">
                    Individual learning path + AI tavsiyalar + chuqur analitika
                  </div>
                  <p className="text-[11px] text-slate-400">
                    Xatolarni tushuntiruvchi Yo‘lchi AI mentori, zaif nuqtalarni mustahkamlash va shaxsiy o‘quv rejasi uchun.
                  </p>
                </div>

                <div className="p-4 rounded-xl bg-white/5 border-l-4 border-emerald-500 border-r border-t border-b border-white/10 space-y-1 hover:bg-white/10 transition-colors">
                  <div className="text-xs font-bold text-emerald-400 uppercase">
                    Free (Bepul) Rejada nima bor?
                  </div>
                  <div className="text-sm font-semibold text-white">
                    Asosiy darslar va cheklangan mashqlar — konversiya kanali
                  </div>
                  <p className="text-[11px] text-slate-400">
                    Har bir yangi foydalanuvchi bepul diagnostika va dastlabki darslarni sinab ko‘rib, Premium rejaga oson konvertatsiya bo‘ladi.
                  </p>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* 7. SECTION 5: YECHIMNI QANDAY AMALGA OSHIRISHNI REJALASHTIRYAPSIZ? */}
        <section id="strategiya" className="py-20 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-white/10">
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: '-80px' }}
            transition={{ duration: 0.6 }}
            className="text-center max-w-3xl mx-auto mb-16"
          >
            <span className="inline-flex items-center gap-1.5 px-3.5 py-1 rounded-full bg-cyan-500/15 text-cyan-300 border border-cyan-500/30 text-xs font-black tracking-widest uppercase shadow-[0_0_15px_rgba(6,182,212,0.25)]">
              5. ASOSIY BOSQICH
            </span>
            <h2 className="text-3xl sm:text-5xl font-black text-white mt-3 tracking-tight">
              Yechimni Amalga Oshirish Strategiyasi
            </h2>
            <p className="text-slate-300 text-sm sm:text-base mt-4 max-w-2xl mx-auto leading-relaxed">
              Bosqichlar, texnologiyalar, AI vositalari va barqaror masshtablash infratuzilmasi.
            </p>
          </motion.div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <motion.div
              whileHover={{ y: -6 }}
              className="p-8 rounded-3xl bg-slate-900/80 border border-cyan-500/30 shadow-lg space-y-4 hover:border-cyan-400/80 transition-all backdrop-blur-xl"
            >
              <div className="w-12 h-12 rounded-2xl bg-cyan-500/20 text-cyan-400 flex items-center justify-center font-black text-xl border border-cyan-500/30">
                01
              </div>
              <h3 className="text-lg font-bold text-white">AI Arxitekturasi va Dvigateli</h3>
              <p className="text-xs text-slate-300 leading-relaxed">
                Google Gemini 2.5 Flash modeli Supabase Deno Edge Functions orqali ulangan. Har bir dars o‘quvchining 0-100% ko‘nikma balliga qarab dinamik prompt bilan generatsiya qilinadi.
              </p>
              <div className="pt-2 text-[11px] text-cyan-400 font-bold">
                Asboblar: Gemini Flash, Deno Edge, RLS
              </div>
            </motion.div>

            <motion.div
              whileHover={{ y: -6 }}
              className="p-8 rounded-3xl bg-slate-900/80 border border-indigo-500/30 shadow-lg space-y-4 hover:border-indigo-400/80 transition-all backdrop-blur-xl"
            >
              <div className="w-12 h-12 rounded-2xl bg-indigo-500/20 text-indigo-400 flex items-center justify-center font-black text-xl border border-indigo-500/30">
                02
              </div>
              <h3 className="text-lg font-bold text-white">Ko‘p Platformali Klient</h3>
              <p className="text-xs text-slate-300 leading-relaxed">
                Veb brauzerda React 19 va mobil telefonlarda Flutter orqali ishlaydi. O‘quvchi qayerda bo‘lishidan qat’i nazar o‘zining darslari, XP lari va Yo‘lchi AI bilan muloqotini davom ettira oladi.
              </p>
              <div className="pt-2 text-[11px] text-indigo-400 font-bold">
                Asboblar: Flutter, Riverpod, React 19, Tailwind
              </div>
            </motion.div>

            <motion.div
              whileHover={{ y: -6 }}
              className="p-8 rounded-3xl bg-slate-900/80 border border-emerald-500/30 shadow-lg space-y-4 hover:border-emerald-400/80 transition-all backdrop-blur-xl"
            >
              <div className="w-12 h-12 rounded-2xl bg-emerald-500/20 text-emerald-400 flex items-center justify-center font-black text-xl border border-emerald-500/30">
                03
              </div>
              <h3 className="text-lg font-bold text-white">Bozor va Monetizatsiya</h3>
              <p className="text-xs text-slate-300 leading-relaxed">
                B2C Freemium modeli: 59 900 so‘mlik obuna xarajatlari bitta repetitor darsining 10 dan bir qismiga teng. B2B modeli orqali xususiy va davlat maktablariga monitoring litsenziyasi sotiladi.
              </p>
              <div className="pt-2 text-[11px] text-emerald-400 font-bold">
                Asboblar: B2C Freemium, B2B SaaS, Payme/Click
              </div>
            </motion.div>
          </div>
        </section>

        {/* 8. SECTION 6: /DEMO SAHIFASI PREVIEW & CTA */}
        <section className="py-20 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-white/10">
          <motion.div
            initial={{ opacity: 0, scale: 0.96 }}
            whileInView={{ opacity: 1, scale: 1 }}
            viewport={{ once: true }}
            transition={{ duration: 0.7 }}
            className="p-8 sm:p-14 rounded-3xl bg-gradient-to-r from-cyan-900/80 via-indigo-900/80 to-blue-900/80 border border-cyan-400/30 shadow-[0_0_60px_-15px_rgba(6,182,212,0.4)] text-center max-w-4xl mx-auto space-y-6 text-white backdrop-blur-2xl relative overflow-hidden"
          >
            <div className="absolute top-0 right-0 w-64 h-64 bg-cyan-400/10 rounded-full blur-3xl pointer-events-none" />
            <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-white/10 text-cyan-300 text-xs font-black backdrop-blur-md border border-white/20">
              <Play className="w-3.5 h-3.5 fill-current text-cyan-400" />
              6-TALAB: /demo SAHIFASI TAYYOR
            </div>

            <h2 className="text-3xl sm:text-5xl font-black text-white tracking-tight">
              Jonli Demo Video va Interaktiv Prototip
            </h2>

            <p className="text-slate-200 text-sm sm:text-base max-w-2xl mx-auto leading-relaxed">
              Hakamlar va investorlar uchun platformaning to‘liq 1–5 daqiqalik dars jarayoni, diagnostikasi va ishlash mexanizmi aks etgan maxsus <strong>/demo</strong> sahifasi tayyorlandi.
            </p>

            <div className="flex flex-wrap items-center justify-center gap-4 pt-2">
              <Button
                variant="primary"
                size="lg"
                onClick={onNavigateDemo}
                className="bg-white hover:bg-slate-100 text-slate-950 font-black px-8 py-4 rounded-2xl shadow-2xl flex items-center gap-2 cursor-pointer transition-all transform hover:-translate-y-0.5"
              >
                /demo Sahifasiga O‘tish <ArrowRight className="w-4 h-4" />
              </Button>
            </div>
          </motion.div>
        </section>

        {/* 9. BONUS 1: INTERAKTIV AI-CHATBOT EMULATOR (SAVOL-JAVOB NAMUNALARI BILAN) */}
        <section id="ai-mentor" className="py-20 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-white/10">
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: '-80px' }}
            transition={{ duration: 0.6 }}
            className="text-center max-w-3xl mx-auto mb-12"
          >
            <span className="inline-flex items-center gap-1.5 px-3.5 py-1 rounded-full bg-emerald-500/15 text-emerald-300 border border-emerald-500/30 text-xs font-black tracking-widest uppercase shadow-[0_0_15px_rgba(16,185,129,0.25)]">
              QO‘SHIMCHA BONUS VAZIFA 1
            </span>
            <h2 className="text-3xl sm:text-5xl font-black text-white mt-3 tracking-tight">
              Savol-Javob Namunalari Bilan AI-Chatbot
            </h2>
            <p className="text-slate-300 text-sm sm:text-base mt-4 max-w-2xl mx-auto leading-relaxed">
              Yo‘lchi AI bilan hoziroq real vaqtda muloqot qilib ko‘ring yoki quyidagi namunaviy savollarni bosing.
            </p>
          </motion.div>

          <div className="max-w-3xl mx-auto rounded-3xl bg-slate-900/90 border border-cyan-500/30 overflow-hidden shadow-[0_0_50px_-15px_rgba(6,182,212,0.3)] backdrop-blur-2xl">
            {/* Chat Header */}
            <div className="p-4 bg-slate-950/80 border-b border-white/10 flex items-center justify-between">
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
            <div className="p-5 space-y-4 max-h-80 overflow-y-auto bg-slate-950/40">
              {chatMessages.map((msg, idx) => (
                <div
                  key={idx}
                  className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}
                >
                  <div
                    className={`max-w-[85%] p-3.5 rounded-2xl text-xs sm:text-sm leading-relaxed ${
                      msg.role === 'user'
                        ? 'bg-gradient-to-r from-cyan-600 to-blue-600 text-white font-medium rounded-br-none shadow-md'
                        : 'bg-slate-800/90 text-slate-100 rounded-bl-none border border-white/10 shadow-md'
                    }`}
                  >
                    {msg.text}
                    <div
                      className={`text-[9px] mt-1 text-right ${
                        msg.role === 'user' ? 'text-cyan-200' : 'text-slate-400'
                      }`}
                    >
                      {msg.time}
                    </div>
                  </div>
                </div>
              ))}

              {isBotThinking && (
                <div className="flex justify-start">
                  <div className="p-3 rounded-2xl bg-slate-800 border border-cyan-500/30 text-xs text-cyan-300 flex items-center gap-2 animate-pulse shadow-sm">
                    <Sparkles className="w-3.5 h-3.5 animate-spin text-cyan-400" /> Yo‘lchi AI tahlil qilmoqda...
                  </div>
                </div>
              )}
            </div>

            {/* Quick Sample Prompts */}
            <div className="p-3 bg-slate-950/60 border-t border-white/10">
              <div className="text-[11px] text-slate-400 font-bold mb-2">Namunaviy savollar (bir marta bosing):</div>
              <div className="flex flex-wrap gap-2">
                {samplePrompts.map((p, idx) => (
                  <button
                    key={idx}
                    onClick={() => handleSendQuestion(p.q)}
                    className="text-left text-[11px] px-3 py-1.5 rounded-xl bg-slate-800/80 hover:bg-slate-700/80 border border-white/10 text-slate-200 shadow-sm transition-colors cursor-pointer"
                  >
                    💡 {p.q}
                  </button>
                ))}
              </div>
            </div>

            {/* Chat Input */}
            <div className="p-3 bg-slate-950 border-t border-white/10 flex items-center gap-2">
              <input
                type="text"
                value={inputQuestion}
                onChange={(e) => setInputQuestion(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && handleSendQuestion()}
                placeholder="Yo‘lchi AI ga ixtiyoriy savol bering..."
                className="flex-1 bg-slate-900 border border-slate-700 rounded-xl px-4 py-2.5 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-cyan-500"
              />
              <button
                onClick={() => handleSendQuestion()}
                className="p-2.5 bg-gradient-to-r from-cyan-500 to-blue-600 hover:brightness-110 text-white rounded-xl font-bold transition-all cursor-pointer shadow-md"
              >
                <Send className="w-4 h-4" />
              </button>
            </div>
          </div>
        </section>

        {/* 10. REAL BACKEND CONTRACTS & EDGE FUNCTION ARCHITECTURE */}
        <section className="py-20 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-white/10">
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: '-80px' }}
            transition={{ duration: 0.6 }}
            className="text-center max-w-3xl mx-auto mb-12"
          >
            <span className="inline-flex items-center gap-1.5 px-3.5 py-1 rounded-full bg-indigo-500/15 text-indigo-300 border border-indigo-500/30 text-xs font-black tracking-widest uppercase shadow-[0_0_15px_rgba(99,102,241,0.25)]">
              <Terminal className="w-3.5 h-3.5 text-indigo-400" />
              XAVFSIZLIK VA ARXITEKTURA
            </span>
            <h2 className="text-3xl sm:text-5xl font-black text-white mt-3 tracking-tight">
              Supabase Edge Function va Server-Side Scoring
            </h2>
            <p className="text-slate-300 text-sm sm:text-base mt-4 max-w-2xl mx-auto leading-relaxed">
              BilimYo‘l Smart Edu ochiq kodli, server-side baholash va Gemini 2.5 Flash Edge Function himoyasiga ega.
            </p>
          </motion.div>

          <div className="max-w-4xl mx-auto rounded-3xl bg-slate-950 border border-white/15 overflow-hidden shadow-2xl backdrop-blur-xl">
            {/* API Tab switcher */}
            <div className="flex border-b border-white/10 bg-slate-900/90">
              <button
                onClick={() => setActiveApiTab('diagnostics')}
                className={`flex-1 py-3 px-4 text-xs font-bold transition-colors cursor-pointer ${
                  activeApiTab === 'diagnostics' ? 'bg-slate-950 text-cyan-400 border-b-2 border-cyan-500 font-black' : 'text-slate-400 hover:text-white'
                }`}
              >
                Edge Function: yolchi-tutor
              </button>
              <button
                onClick={() => setActiveApiTab('scoring')}
                className={`flex-1 py-3 px-4 text-xs font-bold transition-colors cursor-pointer ${
                  activeApiTab === 'scoring' ? 'bg-slate-950 text-cyan-400 border-b-2 border-cyan-500 font-black' : 'text-slate-400 hover:text-white'
                }`}
              >
                RPC: submit_answer_attempt()
              </button>
              <button
                onClick={() => setActiveApiTab('lessons')}
                className={`flex-1 py-3 px-4 text-xs font-bold transition-colors cursor-pointer ${
                  activeApiTab === 'lessons' ? 'bg-slate-950 text-cyan-400 border-b-2 border-cyan-500 font-black' : 'text-slate-400 hover:text-white'
                }`}
              >
                RLS: Anti-Cheat Siyosati
              </button>
            </div>

            {/* API Code & Payload */}
            <div className="p-6 font-mono text-xs space-y-4 bg-slate-950 text-slate-100">
              {activeApiTab === 'diagnostics' && (
                <>
                  <div className="text-slate-400 text-[11px]">
                    # Supabase Deno Edge Function — Gemini 2.5 Flash bilan dars/izoh generatsiyasi
                  </div>
                  <div className="p-4 rounded-xl bg-black/60 border border-slate-800 text-cyan-300 overflow-x-auto">
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
                  <div className="p-4 rounded-xl bg-black/60 border border-emerald-500/40 text-emerald-300 overflow-x-auto">
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
                  <div className="p-4 rounded-xl bg-black/60 border border-slate-800 text-amber-300 overflow-x-auto">
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
                  <div className="p-4 rounded-xl bg-black/60 border border-amber-500/40 text-amber-300 overflow-x-auto">
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
                  <div className="p-4 rounded-xl bg-black/60 border border-slate-800 text-purple-300 overflow-x-auto">
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
        <footer className="py-16 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-white/10 text-center space-y-6">
          <div className="flex items-center justify-center gap-2">
            <BilimYolLogo size="md" />
          </div>
          <p className="text-xs text-slate-400 max-w-xl mx-auto">
            BilimYo‘l Smart Edu — Pitch Day 3.0 (AIFU) ishtirokchisi. Barcha huquqlar himoyalangan © 2026.
          </p>
          <div className="flex flex-wrap items-center justify-center gap-6 text-xs font-bold text-cyan-400">
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
