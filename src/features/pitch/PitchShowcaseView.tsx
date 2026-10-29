import React, { useState } from 'react';
import { motion, useScroll, useSpring } from 'framer-motion';
import confetti from 'canvas-confetti';
import {
  Sparkles,
  ArrowRight,
  Play,
  Users,
  Target,
  Layers,
  ShieldCheck,
  Terminal,
  Globe,
  Zap,
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
  Flame,
  Award,
  Info,
  ArrowUp,
} from 'lucide-react';
import { BilimYolLogo } from '@/presentation/components/BilimYolLogo';
import { YolchiAIMascot } from '@/presentation/components/YolchiAIMascot';

interface PitchShowcaseViewProps {
  onNavigateDemo: () => void;
  onNavigateApp: () => void;
  onNavigateAiTutor: () => void;
}

type RoadmapStage = 'now' | '6months' | '1year' | '3years';

export const PitchShowcaseView: React.FC<PitchShowcaseViewProps> = ({
  onNavigateDemo,
  onNavigateApp,
  onNavigateAiTutor,
}) => {
  // Top scroll progress bar
  const { scrollYProgress } = useScroll();
  const scaleX = useSpring(scrollYProgress, {
    stiffness: 120,
    damping: 30,
    restDelta: 0.001,
  });

  // Roadmap active stage (Slide 06)
  const [activeRoadmapStage, setActiveRoadmapStage] = useState<RoadmapStage>('now');

  // Interactive Chatbot Emulator state
  const [chatMessages, setChatMessages] = useState<Array<{ role: 'user' | 'assistant'; text: string; time: string }>>([
    {
      role: 'assistant',
      text: 'Assalomu alaykum! Men Yo‘lchi AI — sizning shaxsiy ta’lim yo‘lboshchingizman. Har qanday fan, formulalar yoki o‘quv qiyinchiliklari bo‘yicha savol bering!',
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

  const triggerCelebration = () => {
    try {
      confetti({
        particleCount: 70,
        spread: 80,
        origin: { y: 0.65 },
        colors: ['#0d9ad6', '#3550d6', '#069669', '#f59f00', '#dc2828'],
      });
    } catch {
      // safe fallback
    }
  };

  const scrollToSection = (id: string) => {
    const el = document.getElementById(id);
    if (el) {
      el.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  };

  return (
    <div className="min-h-screen bg-[#10151f] text-slate-100 selection:bg-path selection:text-white relative overflow-hidden font-sans">
      {/* 0. FIXED TOP SCROLL PROGRESS BAR (Glowing Laser Beam) */}
      <motion.div
        style={{ scaleX }}
        className="fixed top-0 left-0 right-0 h-1 bg-gradient-to-r from-path via-brand via-brand to-mint origin-left z-50 shadow-[0_0_16px_rgba(13,154,214,0.9)]"
      />

      {/* 0. DYNAMIC COSMIC BACKGROUND (Aurora Nebulas & Tech Grid) */}
      <div className="fixed inset-0 pointer-events-none overflow-hidden z-0">
        {/* Subtle Tech Dot Grid */}
        <div
          className="absolute inset-0 opacity-[0.14]"
          style={{
            backgroundImage: 'radial-gradient(rgba(255, 255, 255, 0.25) 1px, transparent 1px)',
            backgroundSize: '32px 32px',
          }}
        />

        {/* Floating Animated Ambient Glow Auroras */}
        <div className="absolute -top-32 left-1/4 w-[600px] h-[600px] bg-path/12 rounded-full blur-[160px] animate-pulse" />
        <div className="absolute top-1/3 -right-40 w-[650px] h-[650px] bg-brand/15 rounded-full blur-[180px]" />
        <div className="absolute top-2/3 -left-40 w-[550px] h-[550px] bg-mint/10 rounded-full blur-[170px]" />
        <div className="absolute -bottom-20 right-1/4 w-[600px] h-[600px] bg-brand/12 rounded-full blur-[180px]" />
      </div>

      <div className="relative z-10">
        {/* 1. TOP PITCH DAY 3.0 ANNOUNCEMENT BANNER */}
        <div className="bg-gradient-to-r from-ink via-slate-950 to-ink border-b border-white/10 py-2 px-4 text-center text-white backdrop-blur-md">
          <div className="max-w-7xl mx-auto flex flex-wrap items-center justify-between gap-3 text-xs">
            <div className="flex items-center gap-2 mx-auto sm:mx-0">
              <span className="inline-flex items-center gap-1.5 px-3 py-0.5 rounded-full bg-path text-slate-950 font-black tracking-wide uppercase text-[10px] shadow-sm">
                <Sparkles className="w-3 h-3 text-slate-950" /> PITCH DAY 3.0
              </span>
              <span className="text-slate-300 font-medium hidden sm:inline">
                AIFU • IT Park • Alibaba • Inno Technopark Saralash Bosqichi
              </span>
            </div>
            <div className="flex items-center gap-2 mx-auto sm:mx-0">
              <span className="text-mint font-bold flex items-center gap-1.5 text-[11px]">
                <span className="w-2 h-2 rounded-full bg-mint animate-ping inline-block" />
                1-Bosqich: Onlayn Saralash
              </span>
              <button
                onClick={() => {
                  triggerCelebration();
                  onNavigateDemo();
                }}
                className="text-path hover:text-path underline font-black cursor-pointer ml-1 text-[11px]"
              >
                /demo sahifasi →
              </button>
            </div>
          </div>
        </div>

        {/* 2. STICKY TOP NAVIGATION BAR (Clean, responsive, NO horizontal scrollbars) */}
        <div className="sticky top-0 z-40 bg-[#10151f]/90 backdrop-blur-2xl border-b border-white/10 px-4 sm:px-6 lg:px-8 py-3 shadow-2xl">
          <div className="max-w-7xl mx-auto flex items-center justify-between gap-4">
            <div className="flex items-center gap-3 shrink-0">
              <BilimYolLogo size="sm" showSubtitle={false} variant="dark" />
              <span className="hidden xl:inline-block text-[10px] font-mono font-bold text-path bg-path/70 border border-path/60 px-2 py-0.5 rounded-md">
                PITCH DAY 3.0
              </span>
            </div>

            <nav className="hidden md:flex items-center gap-1 lg:gap-2 text-[12px] font-bold text-slate-300">
              <button
                onClick={() => scrollToSection('problem-solution')}
                className="px-3 py-1.5 rounded-xl hover:bg-white/10 hover:text-white transition-all cursor-pointer flex items-center gap-1.5"
              >
                <Flame className="w-3.5 h-3.5 text-coral" /> Muammo & Yechim
              </button>
              <button
                onClick={() => scrollToSection('team-section')}
                className="px-3 py-1.5 rounded-xl hover:bg-white/10 hover:text-white transition-all cursor-pointer flex items-center gap-1.5"
              >
                <Users className="w-3.5 h-3.5 text-path" /> Jamoa
              </button>
              <button
                onClick={() => scrollToSection('milestones-section')}
                className="px-3 py-1.5 rounded-xl hover:bg-white/10 hover:text-white transition-all cursor-pointer flex items-center gap-1.5"
              >
                <Target className="w-3.5 h-3.5 text-path" /> Milestones
              </button>
              <button
                onClick={() => scrollToSection('monetization-section')}
                className="px-3 py-1.5 rounded-xl hover:bg-white/10 hover:text-mint transition-all cursor-pointer flex items-center gap-1.5 text-mint"
              >
                <DollarSign className="w-3.5 h-3.5" /> 59 900 so‘m
              </button>
              <button
                onClick={() => scrollToSection('tech-architecture')}
                className="hidden lg:flex px-3 py-1.5 rounded-xl hover:bg-white/10 hover:text-white transition-all cursor-pointer items-center gap-1.5"
              >
                <Terminal className="w-3.5 h-3.5 text-amber-400" /> Arxitektura
              </button>
              <button
                onClick={() => scrollToSection('ai-chatbot')}
                className="hidden xl:flex px-3 py-1.5 rounded-xl hover:bg-white/10 hover:text-white transition-all cursor-pointer items-center gap-1.5"
              >
                <Sparkles className="w-3.5 h-3.5 text-path" /> AI Bot
              </button>
            </nav>

            <div className="flex items-center gap-2 shrink-0">
              <button
                onClick={() => {
                  triggerCelebration();
                  onNavigateDemo();
                }}
                className="px-4 py-2 rounded-xl bg-gradient-to-r from-path to-brand hover:from-path hover:to-brand text-slate-950 font-black text-xs shadow-lg shadow-path/25 flex items-center gap-1.5 cursor-pointer transition-all hover:scale-105 active:scale-95"
              >
                <Play className="w-3.5 h-3.5 fill-current" /> Demo Video
              </button>
            </div>
          </div>
        </div>

        {/* 3. HERO SECTION */}
        <section className="pt-16 pb-24 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto text-center relative">
          <motion.div
            initial={{ opacity: 0, y: 24 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.7, ease: [0.16, 1, 0.3, 1] }}
            className="space-y-6 max-w-4xl mx-auto"
          >
            <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-path/70 border border-path/40 text-path text-xs font-bold shadow-[0_0_20px_rgba(13,154,214,0.25)] backdrop-blur-md">
              <Sparkles className="w-3.5 h-3.5 text-path animate-spin" style={{ animationDuration: '6s' }} />
              <span>O‘zbekiston EdTech Bozorida 1-Raqamli AI Ta’lim Ekotizimi</span>
            </div>

            <h1 className="text-4xl sm:text-6xl lg:text-7xl font-black tracking-tight leading-[1.08] text-white">
              BilimYo‘l Smart Edu
              <span className="block mt-2 text-2xl sm:text-4xl lg:text-5xl font-extrabold bg-gradient-to-r from-path via-path to-mint bg-clip-text text-transparent">
                Darslik emas — Shaxsiy Ta’lim Yo‘li
              </span>
            </h1>

            <p className="text-base sm:text-xl text-slate-300 font-normal max-w-3xl mx-auto leading-relaxed">
              Har bir o‘quvchi uchun <strong className="text-path font-bold">individual sun’iy intellekt repetitori</strong>, bilim bo‘shliqlarini aniqlaydigan adaptiv diagnostika va avtomatik tuziluvchi darslar oqimi.
            </p>

            {/* CTAs */}
            <div className="flex flex-wrap items-center justify-center gap-4 pt-4">
              <button
                onClick={() => {
                  triggerCelebration();
                  onNavigateDemo();
                }}
                className="px-8 py-4 rounded-2xl bg-gradient-to-r from-path via-brand to-brand hover:from-path hover:to-brand text-slate-950 font-black text-base shadow-[0_0_30px_rgba(13,154,214,0.4)] flex items-center gap-3 cursor-pointer transition-all transform hover:-translate-y-0.5 active:scale-[0.98]"
              >
                <Play className="w-5 h-5 fill-current text-slate-950" />
                <span className="text-slate-950 font-black">Demo Sahifasini Ko‘rish (/demo)</span>
              </button>

              <button
                onClick={() => {
                  triggerCelebration();
                  onNavigateApp();
                }}
                className="px-8 py-4 rounded-2xl bg-slate-900/90 hover:bg-slate-800 text-white font-bold text-base border-2 border-white/20 hover:border-path shadow-xl backdrop-blur-md flex items-center gap-2.5 transition-all transform hover:-translate-y-0.5 active:scale-[0.98] cursor-pointer"
              >
                <Zap className="w-5 h-5 text-amber-400 fill-amber-400/30" />
                <span className="text-white font-bold">Jonli Prototipni Ishga Tushirish</span>
              </button>
            </div>

            {/* Quick Metrics Bar (Futuristic HUD Counters) */}
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 pt-12 max-w-5xl mx-auto">
              <motion.div
                whileHover={{ y: -4, scale: 1.02 }}
                className="p-5 rounded-2xl bg-white/[0.04] border border-path/30 backdrop-blur-xl shadow-[0_0_25px_rgba(13,154,214,0.1)] text-left group"
              >
                <div className="text-xs font-mono font-bold text-path flex items-center justify-between">
                  <span>BOZOR AUDITORIYASI</span>
                  <Users className="w-3.5 h-3.5 text-path" />
                </div>
                <div className="text-3xl sm:text-4xl font-black text-white mt-1 group-hover:text-path transition-colors">
                  6.5M+
                </div>
                <div className="text-xs text-slate-400 mt-1 font-medium">Maktab o‘quvchilari (O‘zbekiston)</div>
              </motion.div>

              <motion.div
                whileHover={{ y: -4, scale: 1.02 }}
                className="p-5 rounded-2xl bg-white/[0.04] border border-mint/30 backdrop-blur-xl shadow-[0_0_25px_rgba(6,150,105,0.1)] text-left group"
              >
                <div className="text-xs font-mono font-bold text-mint flex items-center justify-between">
                  <span>METODIKA</span>
                  <CheckCircle2 className="w-3.5 h-3.5 text-mint" />
                </div>
                <div className="text-3xl sm:text-4xl font-black text-white mt-1 group-hover:text-mint transition-colors">
                  100%
                </div>
                <div className="text-xs text-slate-400 mt-1 font-medium">Adaptiv Diagnostika & Bilim Matritsasi</div>
              </motion.div>

              <motion.div
                whileHover={{ y: -4, scale: 1.02 }}
                className="p-5 rounded-2xl bg-white/[0.04] border border-brand/30 backdrop-blur-xl shadow-[0_0_25px_rgba(53,80,214,0.1)] text-left group"
              >
                <div className="text-xs font-mono font-bold text-path flex items-center justify-between">
                  <span>AI TEZLIK</span>
                  <Clock className="w-3.5 h-3.5 text-path" />
                </div>
                <div className="text-3xl sm:text-4xl font-black text-white mt-1 group-hover:text-path transition-colors">
                  &lt;1.5s
                </div>
                <div className="text-xs text-slate-400 mt-1 font-medium">Yo‘lchi AI Deno Edge Javob Vaqti</div>
              </motion.div>

              <motion.div
                whileHover={{ y: -4, scale: 1.02 }}
                className="p-5 rounded-2xl bg-white/[0.04] border border-brand/30 backdrop-blur-xl shadow-[0_0_25px_rgba(53,80,214,0.1)] text-left group"
              >
                <div className="text-xs font-mono font-bold text-path flex items-center justify-between">
                  <span>TAYYORLIK</span>
                  <Award className="w-3.5 h-3.5 text-path" />
                </div>
                <div className="text-3xl sm:text-4xl font-black text-white mt-1 group-hover:text-path transition-colors">
                  MVP
                </div>
                <div className="text-xs text-slate-400 mt-1 font-medium">React 19 & Flutter Mobile Ishlaydi</div>
              </motion.div>
            </div>
          </motion.div>
        </section>

        {/* 4. SECTION 1: MUAMMO → BIZNING YECHIM (CYBERNETIC COMPARISON) */}
        <section id="problem-solution" className="py-20 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto relative">
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: '-60px' }}
            transition={{ duration: 0.6 }}
            className="text-center max-w-3xl mx-auto mb-16"
          >
            <span className="text-path bg-path/80 px-3.5 py-1 rounded-full border border-path/30 text-xs font-mono font-bold tracking-widest uppercase shadow-[0_0_15px_rgba(13,154,214,0.2)]">
              1. ASOSIY BOSQICH • PITCH NUKLEUS
            </span>
            <h2 className="text-3xl sm:text-5xl font-black text-white mt-3 tracking-tight">
              Kritik Muammo <span className="text-slate-500 font-light">vs</span> Bizning Yechim
            </h2>
            <p className="text-slate-300 text-sm sm:text-base mt-3 max-w-2xl mx-auto">
              O‘zbekiston ta’lim tizimidagi eng og‘riqli tizimli bo‘shliqlarni sun’iy intellekt va adaptiv pedagogika orqali tubdan hal etamiz.
            </p>
          </motion.div>

          {/* Side-by-Side Neon Comparison Grid */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 items-stretch relative">
            {/* THE PROBLEM SIDE (Crimson Velvet Dark Glass) */}
            <motion.div
              initial={{ opacity: 0, x: -30 }}
              whileInView={{ opacity: 1, x: 0 }}
              viewport={{ once: true, margin: '-60px' }}
              transition={{ duration: 0.6 }}
              className="p-8 sm:p-10 rounded-3xl bg-gradient-to-b from-coral/35 via-slate-900/90 to-slate-950 border border-coral/30 backdrop-blur-2xl shadow-[0_0_50px_rgba(220,40,40,0.12)] relative overflow-hidden flex flex-col justify-between group"
            >
              {/* Corner ambient danger aura */}
              <div className="absolute top-0 right-0 w-44 h-44 bg-coral/10 rounded-full blur-3xl pointer-events-none" />

              <div>
                <div className="flex items-center gap-3.5 mb-8 pb-5 border-b border-coral/20">
                  <div className="w-12 h-12 rounded-2xl bg-coral/20 border border-coral/40 text-coral flex items-center justify-center font-black text-xl shadow-[0_0_20px_rgba(220,40,40,0.3)]">
                    ✕
                  </div>
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="w-2 h-2 rounded-full bg-coral animate-ping" />
                      <h3 className="text-2xl font-black text-white">Kritik Muammo</h3>
                    </div>
                    <p className="text-xs text-coral mt-0.5">An’anaviy ta’limdagi 4 ta tizimli bo‘shliq</p>
                  </div>
                </div>

                <div className="space-y-4">
                  {/* Problem Card 1 */}
                  <motion.div
                    whileHover={{ x: 6 }}
                    className="p-5 rounded-2xl bg-white/[0.03] border border-coral/20 hover:border-coral/50 hover:bg-coral/20 transition-all"
                  >
                    <div className="flex items-center gap-2.5 mb-1.5">
                      <span className="w-6 h-6 rounded-lg bg-coral/20 text-coral font-mono font-black text-xs flex items-center justify-center border border-coral/30">
                        01
                      </span>
                      <h4 className="font-bold text-sm text-white">35–40 talik ommaviy sinflar</h4>
                    </div>
                    <p className="text-xs text-slate-300 leading-relaxed pl-8">
                      An’anaviy 45 daqiqalik darsda har bir o‘quvchiga hatto 1 daqiqa ham individual vaqt ajratilmaydi. Barcha bolalar qobiliyatidan qat’i nazar bitta o‘rtacha sur’atda o‘qiydi.
                    </p>
                  </motion.div>

                  {/* Problem Card 2 */}
                  <motion.div
                    whileHover={{ x: 6 }}
                    className="p-5 rounded-2xl bg-white/[0.03] border border-coral/20 hover:border-coral/50 hover:bg-coral/20 transition-all"
                  >
                    <div className="flex items-center gap-2.5 mb-1.5">
                      <span className="w-6 h-6 rounded-lg bg-coral/20 text-coral font-mono font-black text-xs flex items-center justify-center border border-coral/30">
                        02
                      </span>
                      <h4 className="font-bold text-sm text-white">Qimmat repetitorlar (500K – 1.5M so‘m/oy)</h4>
                    </div>
                    <p className="text-xs text-slate-300 leading-relaxed pl-8">
                      Oilalar byudjetiga juda og‘ir moliyaviy yuk. Qishloq va tumanlarda esa ixtisoslashgan malakali mutaxassislar umuman yetishmaydi yoki topilmaydi.
                    </p>
                  </motion.div>

                  {/* Problem Card 3 */}
                  <motion.div
                    whileHover={{ x: 6 }}
                    className="p-5 rounded-2xl bg-white/[0.03] border border-coral/20 hover:border-coral/50 hover:bg-coral/20 transition-all"
                  >
                    <div className="flex items-center gap-2.5 mb-1.5">
                      <span className="w-6 h-6 rounded-lg bg-coral/20 text-coral font-mono font-black text-xs flex items-center justify-center border border-coral/30">
                        03
                      </span>
                      <h4 className="font-bold text-sm text-white">Quruq, tushunarsiz testlar</h4>
                    </div>
                    <p className="text-xs text-slate-300 leading-relaxed pl-8">
                      O‘quvchi xato qilganda nega xato qilganini pedagogik tushuntiradigan hech kim yo‘q. Faqat quruq "noto‘g‘ri" degan ball qo‘yilib, bolaning qiziqishi so‘nadi.
                    </p>
                  </motion.div>

                  {/* Problem Card 4 */}
                  <motion.div
                    whileHover={{ x: 6 }}
                    className="p-5 rounded-2xl bg-white/[0.03] border border-coral/20 hover:border-coral/50 hover:bg-coral/20 transition-all"
                  >
                    <div className="flex items-center gap-2.5 mb-1.5">
                      <span className="w-6 h-6 rounded-lg bg-coral/20 text-coral font-mono font-black text-xs flex items-center justify-center border border-coral/30">
                        04
                      </span>
                      <h4 className="font-bold text-sm text-white">Bilim bo‘shliqlarining yillar davomida to‘planishi</h4>
                    </div>
                    <p className="text-xs text-slate-300 leading-relaxed pl-8">
                      5-sinfda kasrlarni o‘zlashtirmagan o‘quvchi 8-sinfda algebra va geometriyani mutlaqo tushuna olmay qoladi va ta’limdan ortda qoladi.
                    </p>
                  </motion.div>
                </div>
              </div>

              <div className="mt-8 pt-4 border-t border-coral/20 flex items-center justify-between text-[11px] text-coral font-mono">
                <span>Natija: Past o‘zlashtirish & Ta’limiy tengsizlik</span>
                <span className="font-bold">An’anaviy Model</span>
              </div>
            </motion.div>

            {/* THE SOLUTION SIDE (Cyan-Emerald Hyper-Glass) */}
            <motion.div
              initial={{ opacity: 0, x: 30 }}
              whileInView={{ opacity: 1, x: 0 }}
              viewport={{ once: true, margin: '-60px' }}
              transition={{ duration: 0.6 }}
              className="p-8 sm:p-10 rounded-3xl bg-gradient-to-b from-path/40 via-slate-900/90 to-slate-950 border-2 border-path/40 backdrop-blur-2xl shadow-[0_0_60px_rgba(13,154,214,0.2)] relative overflow-hidden flex flex-col justify-between group"
            >
              {/* Luminous Top Accent Beam */}
              <div className="absolute top-0 left-0 right-0 h-[2px] bg-gradient-to-r from-transparent via-path to-transparent shadow-[0_0_20px_#0d9ad6]" />
              <div className="absolute top-0 right-0 w-44 h-44 bg-path/15 rounded-full blur-3xl pointer-events-none" />

              <div>
                <div className="flex items-center gap-3.5 mb-8 pb-5 border-b border-path/25">
                  <div className="w-12 h-12 rounded-2xl bg-path/20 border border-path/50 text-path flex items-center justify-center font-black text-xl shadow-[0_0_25px_rgba(13,154,214,0.35)]">
                    ✓
                  </div>
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="w-2 h-2 rounded-full bg-path animate-pulse" />
                      <h3 className="text-2xl font-black text-white">BilimYo‘l Yechimi</h3>
                    </div>
                    <p className="text-xs text-path mt-0.5">Sun’iy intellektga asoslangan shaxsiy ekotizim</p>
                  </div>
                </div>

                <div className="space-y-4">
                  {/* Solution Card 1 */}
                  <motion.div
                    whileHover={{ x: 6 }}
                    className="p-5 rounded-2xl bg-white/[0.04] border border-path/25 hover:border-path/60 hover:bg-path/20 transition-all shadow-sm"
                  >
                    <div className="flex items-center gap-2.5 mb-1.5">
                      <span className="w-6 h-6 rounded-lg bg-path/20 text-path font-mono font-black text-xs flex items-center justify-center border border-path/40">
                        01
                      </span>
                      <h4 className="font-bold text-sm text-white flex items-center gap-2">
                        100% Adaptiv Diagnostika
                        <span className="text-[10px] font-bold text-path bg-ink px-2 py-0.5 rounded border border-path">0–100% Shkala</span>
                      </h4>
                    </div>
                    <p className="text-xs text-slate-300 leading-relaxed pl-8">
                      8 ta dinamik moslashuvchan savol orqali o‘quvchining har bir ko‘nikmasi (Algebra, Tenglamalar, Funksiyalar, Lug‘at va h.k.) aniq xaritaga tushiriladi.
                    </p>
                  </motion.div>

                  {/* Solution Card 2 */}
                  <motion.div
                    whileHover={{ x: 6 }}
                    className="p-5 rounded-2xl bg-white/[0.04] border border-path/25 hover:border-path/60 hover:bg-path/20 transition-all shadow-sm"
                  >
                    <div className="flex items-center gap-2.5 mb-1.5">
                      <span className="w-6 h-6 rounded-lg bg-path/20 text-path font-mono font-black text-xs flex items-center justify-center border border-path/40">
                        02
                      </span>
                      <h4 className="font-bold text-sm text-white flex items-center gap-2">
                        "Yo‘lchi AI" Do‘stona Mentori
                        <span className="text-[10px] font-bold text-path bg-ink px-2 py-0.5 rounded border border-brand-dark">Gemini 2.5 Flash</span>
                      </h4>
                    </div>
                    <p className="text-xs text-slate-300 leading-relaxed pl-8">
                      Google Gemini 2.5 Flash modeli bolaga tayyor javobni emas, xatoning tub ildizini tushuntiradi va o‘z fikrlashini rivojlantirishga yo‘naltiradi.
                    </p>
                  </motion.div>

                  {/* Solution Card 3 */}
                  <motion.div
                    whileHover={{ x: 6 }}
                    className="p-5 rounded-2xl bg-white/[0.04] border border-path/25 hover:border-path/60 hover:bg-path/20 transition-all shadow-sm"
                  >
                    <div className="flex items-center gap-2.5 mb-1.5">
                      <span className="w-6 h-6 rounded-lg bg-path/20 text-path font-mono font-black text-xs flex items-center justify-center border border-path/40">
                        03
                      </span>
                      <h4 className="font-bold text-sm text-white">Individual 3 Qadamli Darslar</h4>
                    </div>
                    <p className="text-xs text-slate-300 leading-relaxed pl-8">
                      Zaif nuqta aniqlanishi bilanoq AI maxsus dars generatsiya qiladi: <strong>1) Tushuncha</strong>; <strong>2) Vizual model & Audio</strong>; <strong>3) Interaktiv mustahkamlash</strong>.
                    </p>
                  </motion.div>

                  {/* Solution Card 4 (Monetization highlighted) */}
                  <motion.div
                    whileHover={{ x: 6 }}
                    className="p-5 rounded-2xl bg-mint/30 border border-mint/40 hover:border-mint hover:bg-mint/40 transition-all shadow-[0_0_20px_rgba(6,150,105,0.15)]"
                  >
                    <div className="flex items-center gap-2.5 mb-1.5">
                      <span className="w-6 h-6 rounded-lg bg-mint/20 text-mint font-mono font-black text-xs flex items-center justify-center border border-mint/40">
                        04
                      </span>
                      <h4 className="font-bold text-sm text-white flex items-center gap-2">
                        Hamyonbop va Har Doim Yoningizda
                        <span className="text-[10px] font-black text-mint bg-mint/90 px-2 py-0.5 rounded-full border border-mint">
                          59 900 so‘m / oy
                        </span>
                      </h4>
                    </div>
                    <p className="text-xs text-slate-300 leading-relaxed pl-8">
                      Oddiy repetitorning bitta darsi narxiga butun 1 oylik cheksiz shaxsiy ta’lim. Web va Flutter Mobile orqali 24/7 ishlaydi.
                    </p>
                  </motion.div>
                </div>
              </div>

              <div className="mt-8 pt-4 border-t border-path/25 flex items-center justify-between text-[11px] text-path font-mono">
                <span>Natija: 100% Shaxsiylashtirilgan O‘sish</span>
                <span className="font-bold text-mint">BilimYo‘l Smart Edu</span>
              </div>
            </motion.div>
          </div>
        </section>

        {/* 5. SECTION 2: JAMOA (AXION TEAM — 3 ASOSIY USTUN) */}
        <section id="team-section" className="py-20 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-white/10 relative">
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: '-60px' }}
            transition={{ duration: 0.6 }}
            className="text-center max-w-3xl mx-auto mb-16"
          >
            <span className="text-path bg-ink/80 px-3.5 py-1 rounded-full border border-brand/30 text-xs font-mono font-bold tracking-widest uppercase shadow-[0_0_15px_rgba(53,80,214,0.2)]">
              2. ASOSIY BOSQICH • AXION JAMOA
            </span>
            <h2 className="text-3xl sm:text-5xl font-black text-white mt-3 tracking-tight">
              Bizning Jamoa — 3 Ta Asosiy Ustun
            </h2>
            <p className="text-slate-300 text-sm sm:text-base mt-3">
              Texnologik arxitektura, biznes o‘sish strategiyasi va pedagogik metodologiyani yagona maqsad atrofida birlashtirgan asoschilar jamoasi.
            </p>
          </motion.div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            {/* Member 1: Founder & Lead Developer */}
            <motion.div
              whileHover={{ y: -8, scale: 1.02 }}
              className="p-7 sm:p-8 rounded-3xl bg-slate-900/80 border-2 border-path/40 backdrop-blur-xl shadow-[0_0_40px_rgba(13,154,214,0.15)] flex flex-col justify-between group relative overflow-hidden"
            >
              <div className="absolute top-0 right-0 w-36 h-36 bg-path/10 rounded-full blur-2xl pointer-events-none" />
              <div>
                <div className="flex items-center gap-4 mb-5">
                  <div className="relative">
                    <img
                      src="/images/team/oktam_pirimov.jpg"
                      alt="Pirimov O‘ktam"
                      className="w-20 h-20 rounded-2xl object-cover ring-2 ring-path shadow-lg"
                    />
                    <span className="absolute -bottom-2 -right-2 px-2 py-0.5 rounded-full bg-path text-slate-950 text-[10px] font-black uppercase tracking-wider shadow-sm">
                      👑 Lead
                    </span>
                  </div>
                  <div>
                    <h3 className="text-xl font-bold text-white group-hover:text-path transition-colors">
                      Pirimov O‘ktam
                    </h3>
                    <p className="text-xs text-path font-bold mt-0.5">Founder & Lead Developer</p>
                    <span className="inline-block mt-1 text-[11px] text-slate-400">Arxitektura & Muhandislik</span>
                  </div>
                </div>

                <p className="text-xs text-slate-300 leading-relaxed">
                  BilimYo‘l ekotizimining asoschisi va bosh arxitektori. Web va Mobile ilovalar (React 19, Flutter), server-side anti-cheat scoring (PostgreSQL RPC) hamda Gemini AI (Yo‘lchi) Edge integratsiyasini to‘liq kod darajasida noldan yaratgan.
                </p>

                <div className="mt-5 pt-4 border-t border-white/10 space-y-2">
                  <div className="text-[11px] text-slate-400 font-bold uppercase tracking-wider">Asosiy Ko‘nikmalar:</div>
                  <div className="flex flex-wrap gap-1.5 text-[10px]">
                    <span className="px-2.5 py-1 rounded-lg bg-path/80 text-path border border-path font-semibold">Tizim Arxitekturasi</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-800 text-slate-300 border border-slate-700">React 19 & TypeScript</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-800 text-slate-300 border border-slate-700">Flutter 3.x (Mobile)</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-800 text-slate-300 border border-slate-700">PostgreSQL RPC & RLS</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-800 text-slate-300 border border-slate-700">Gemini AI / Deno Edge</span>
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
                    <ExternalLink className="w-3.5 h-3.5" /> GitHub
                  </a>
                  <a
                    href="https://t.me/pirimovuktam"
                    target="_blank"
                    rel="noreferrer"
                    className="text-path hover:underline flex items-center gap-1 font-bold"
                  >
                    <MessageSquare className="w-3.5 h-3.5" /> Telegram
                  </a>
                </div>
                <span className="text-[10px] text-mint font-mono font-bold bg-mint/80 px-2 py-0.5 rounded-md border border-mint">
                  152 Web • 48 Mob Tests
                </span>
              </div>
            </motion.div>

            {/* Member 2: Business & Growth Lead */}
            <motion.div
              whileHover={{ y: -8, scale: 1.02 }}
              className="p-7 sm:p-8 rounded-3xl bg-slate-900/80 border-2 border-brand/40 backdrop-blur-xl shadow-[0_0_40px_rgba(53,80,214,0.15)] flex flex-col justify-between group relative overflow-hidden"
            >
              <div className="absolute top-0 right-0 w-36 h-36 bg-brand/10 rounded-full blur-2xl pointer-events-none" />
              <div>
                <div className="flex items-center gap-4 mb-5">
                  <div className="relative">
                    <img
                      src="/images/team/abdurauf_normuminov.jpg"
                      alt="Abdurauf Normuminov"
                      className="w-20 h-20 rounded-2xl object-cover ring-2 ring-path shadow-lg"
                    />
                    <span className="absolute -bottom-2 -right-2 px-2 py-0.5 rounded-full bg-brand text-white text-[10px] font-black uppercase tracking-wider shadow-sm">
                      🚀 Growth
                    </span>
                  </div>
                  <div>
                    <h3 className="text-xl font-bold text-white group-hover:text-path transition-colors">
                      Abdurauf Normuminov
                    </h3>
                    <p className="text-xs text-path font-bold mt-0.5">Business & Growth Lead</p>
                    <span className="inline-block mt-1 text-[11px] text-slate-400">Bozor & Hamkorliklar</span>
                  </div>
                </div>

                <p className="text-xs text-slate-300 leading-relaxed">
                  Biznes modelni shakllantirish, bozorga chiqish (Go-To-Market) strategiyasi, maktablar va o‘quv markazlari bilan B2B hamkorlik hamda foydalanuvchilar oqimini (traction) kengaytirish rahbari.
                </p>

                <div className="mt-5 pt-4 border-t border-white/10 space-y-2">
                  <div className="text-[11px] text-slate-400 font-bold uppercase tracking-wider">Asosiy Ko‘nikmalar:</div>
                  <div className="flex flex-wrap gap-1.5 text-[10px]">
                    <span className="px-2.5 py-1 rounded-lg bg-ink/80 text-path border border-brand-dark font-semibold">EdTech GTM Strategiyasi</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-800 text-slate-300 border border-slate-700">B2B Maktablar Hamkorligi</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-800 text-slate-300 border border-slate-700">Unit Economics & Monetizatsiya</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-800 text-slate-300 border border-slate-700">Marketing Funnels</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-800 text-slate-300 border border-slate-700">Investor Relations</span>
                  </div>
                </div>
              </div>

              <div className="mt-6 flex items-center justify-between pt-4 border-t border-white/10 text-xs">
                <div className="flex items-center gap-2 text-path font-bold">
                  <TrendingUp className="w-3.5 h-3.5" />
                  <span>EdTech Growth Strategy</span>
                </div>
                <span className="text-[10px] text-path font-mono font-bold bg-ink/80 px-2 py-0.5 rounded-md border border-brand-dark">
                  B2B & B2C Focus
                </span>
              </div>
            </motion.div>

            {/* Member 3: Education & Product Lead */}
            <motion.div
              whileHover={{ y: -8, scale: 1.02 }}
              className="p-7 sm:p-8 rounded-3xl bg-slate-900/80 border-2 border-mint/40 backdrop-blur-xl shadow-[0_0_40px_rgba(6,150,105,0.15)] flex flex-col justify-between group relative overflow-hidden"
            >
              <div className="absolute top-0 right-0 w-36 h-36 bg-mint/10 rounded-full blur-2xl pointer-events-none" />
              <div>
                <div className="flex items-center gap-4 mb-5">
                  <div className="relative">
                    <img
                      src="/images/team/dildora_hamdamova.jpg"
                      alt="Hamdamova Dildora"
                      className="w-20 h-20 rounded-2xl object-cover ring-2 ring-mint shadow-lg"
                    />
                    <span className="absolute -bottom-2 -right-2 px-2 py-0.5 rounded-full bg-mint text-white text-[10px] font-black uppercase tracking-wider shadow-sm">
                      🎓 EdLead
                    </span>
                  </div>
                  <div>
                    <h3 className="text-xl font-bold text-white group-hover:text-mint transition-colors">
                      Hamdamova Dildora
                    </h3>
                    <p className="text-xs text-mint font-bold mt-0.5">Education & Product Lead</p>
                    <span className="inline-block mt-1 text-[11px] text-slate-400">Pedagogika & Mahsulot</span>
                  </div>
                </div>

                <p className="text-xs text-slate-300 leading-relaxed">
                  Pedagogik metodika va mahsulot arxitekturasi bo‘yicha yetakchi. Milliy ta’lim standartlari, Bloom taksonomiyasi va adaptiv diagnostika metodikasi bo‘yicha kurikulum rahbari.
                </p>

                <div className="mt-5 pt-4 border-t border-white/10 space-y-2">
                  <div className="text-[11px] text-slate-400 font-bold uppercase tracking-wider">Asosiy Ko‘nikmalar:</div>
                  <div className="flex flex-wrap gap-1.5 text-[10px]">
                    <span className="px-2.5 py-1 rounded-lg bg-mint/80 text-mint border border-mint font-semibold">Adaptiv Kurikulum</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-800 text-slate-300 border border-slate-700">Bloom Taksonomiyasi</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-800 text-slate-300 border border-slate-700">Diagnostik Metodika</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-800 text-slate-300 border border-slate-700">O‘quvchi UX & Psixologiyasi</span>
                    <span className="px-2.5 py-1 rounded-lg bg-slate-800 text-slate-300 border border-slate-700">Math & English Standartlar</span>
                  </div>
                </div>
              </div>

              <div className="mt-6 flex items-center justify-between pt-4 border-t border-white/10 text-xs">
                <div className="flex items-center gap-2 text-mint font-bold">
                  <Brain className="w-3.5 h-3.5" />
                  <span>Pedagogical Standards</span>
                </div>
                <span className="text-[10px] text-mint font-mono font-bold bg-mint/80 px-2 py-0.5 rounded-md border border-mint">
                  100% Moslik
                </span>
              </div>
            </motion.div>
          </div>

          {/* Technology Stack Carousel */}
          <div className="mt-12 p-6 rounded-3xl bg-slate-900/60 border border-white/10 backdrop-blur-xl flex flex-wrap items-center justify-center gap-2.5">
            <span className="text-xs text-slate-400 font-mono font-bold mr-2">TECH STACK:</span>
            {[
              'Google Gemini 2.5 Flash',
              'React 19',
              'TypeScript',
              'Flutter 3.x',
              'PostgreSQL RPC',
              'Row Level Security (RLS)',
              'Deno Edge Functions',
              'Tailwind CSS v4',
              'Vitest (152 Tests)',
              'Vite 8',
            ].map((tech) => (
              <span
                key={tech}
                className="px-3 py-1.5 rounded-xl bg-white/[0.04] border border-white/10 hover:border-path/50 text-xs font-semibold text-slate-300 hover:text-white transition-colors"
              >
                {tech}
              </span>
            ))}
          </div>
        </section>

        {/* 6. SECTION 3: NEGA AYNAN BIZNING JAMOA? (MVP USTUNLIGI) */}
        <section id="why-us-section" className="py-20 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-white/10 relative">
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: '-60px' }}
            transition={{ duration: 0.6 }}
            className="text-center max-w-3xl mx-auto mb-16"
          >
            <span className="text-path bg-path/80 px-3.5 py-1 rounded-full border border-path/30 text-xs font-mono font-bold tracking-widest uppercase shadow-[0_0_15px_rgba(13,154,214,0.2)]">
              3. ASOSIY BOSQICH • RAXOBATBARDOSH USTUNLIK
            </span>
            <h2 className="text-3xl sm:text-5xl font-black text-white mt-3 tracking-tight">
              Nima Uchun Aynan Bizning Jamoa?
            </h2>
            <p className="text-slate-300 text-sm sm:text-base mt-3">
              G‘oya va oddiy slaydlar bosqichidan o‘tib, real ishlayotgan mahsulotga ega ekanligimiz — bizning asosiy ustunligimizdir.
            </p>
          </motion.div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            <motion.div
              whileHover={{ y: -6 }}
              className="p-6 rounded-3xl bg-slate-900/70 border border-path/30 backdrop-blur-xl shadow-[0_0_30px_rgba(13,154,214,0.1)] transition-all"
            >
              <div className="w-12 h-12 rounded-2xl bg-path/20 text-path flex items-center justify-center mb-4 border border-path/40">
                <CheckCircle2 className="w-6 h-6" />
              </div>
              <h3 className="text-lg font-bold text-white mb-2">100% Ishlayotgan MVP</h3>
              <p className="text-xs text-slate-300 leading-relaxed">
                Biz quruq taqdimot bilan kelmadik. Web va Flutter Mobile ilovamiz to‘liq tayyor, testlar bilan qoplangan va jonli rejimda ishlaydi.
              </p>
            </motion.div>

            <motion.div
              whileHover={{ y: -6 }}
              className="p-6 rounded-3xl bg-slate-900/70 border border-brand/30 backdrop-blur-xl shadow-[0_0_30px_rgba(53,80,214,0.1)] transition-all"
            >
              <div className="w-12 h-12 rounded-2xl bg-brand/20 text-path flex items-center justify-center mb-4 border border-brand/40">
                <Brain className="w-6 h-6" />
              </div>
              <h3 className="text-lg font-bold text-white mb-2">Haqiqiy Pedagogik AI</h3>
              <p className="text-xs text-slate-300 leading-relaxed">
                Oddiy ChatGPT wrapper emas. Tizim bolaga tayyor javobni aytib dangasa qilmaydi, balki ko‘nikmalar grafigi bo‘yicha tushuntiradi.
              </p>
            </motion.div>

            <motion.div
              whileHover={{ y: -6 }}
              className="p-6 rounded-3xl bg-slate-900/70 border border-mint/30 backdrop-blur-xl shadow-[0_0_30px_rgba(6,150,105,0.1)] transition-all"
            >
              <div className="w-12 h-12 rounded-2xl bg-mint/20 text-mint flex items-center justify-center mb-4 border border-mint/40">
                <ShieldCheck className="w-6 h-6" />
              </div>
              <h3 className="text-lg font-bold text-white mb-2">Server Anti-Cheat Xavfsizligi</h3>
              <p className="text-xs text-slate-300 leading-relaxed">
                Ballar, ko‘nikmalar va XP lar to‘liq server-side hisoblanadi. O‘quvchi brauzer orqali javoblarni ko‘rib ololmaydi yoki ballni soxtalashtira olmaydi.
              </p>
            </motion.div>

            <motion.div
              whileHover={{ y: -6 }}
              className="p-6 rounded-3xl bg-slate-900/70 border border-brand/30 backdrop-blur-xl shadow-[0_0_30px_rgba(53,80,214,0.1)] transition-all"
            >
              <div className="w-12 h-12 rounded-2xl bg-brand/20 text-path flex items-center justify-center mb-4 border border-brand/40">
                <Users className="w-6 h-6" />
              </div>
              <h3 className="text-lg font-bold text-white mb-2">3 Kishi Kuchli Sinergiyasi</h3>
              <p className="text-xs text-slate-300 leading-relaxed">
                Tizim arxitekturasi va AI muhandisligi (O‘ktam), biznes strategiyasi va maktablar bilan B2B hamkorlik (Abdurauf) hamda milliy kurikulum metodikasi (Dildora) uyg‘unlashgan.
              </p>
            </motion.div>
          </div>
        </section>

        {/* 7. SECTION 4: MILESTONES — MAQSADLAR VA KPI (SLIDE 06) */}
        <section id="milestones-section" className="py-20 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-white/10 relative">
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: '-60px' }}
            transition={{ duration: 0.6 }}
            className="text-center max-w-3xl mx-auto mb-16"
          >
            <span className="text-amber-400 bg-amber-950/80 px-3.5 py-1 rounded-full border border-amber-500/30 text-xs font-mono font-bold tracking-widest uppercase shadow-[0_0_15px_rgba(245,159,0,0.2)]">
              4. ASOSIY BOSQICH • STRATEGIK XARITA
            </span>
            <h2 className="text-3xl sm:text-5xl font-black text-white mt-3 tracking-tight">
              Milestones — Maqsadlar va KPI
            </h2>
            <p className="text-slate-300 text-sm sm:text-base mt-3">
              <strong className="text-white">Hozir → 6 oy → 1 yil → 3 yil.</strong> Raqamlar konservativ prognoz asosida ishlab chiqilgan.
            </p>
          </motion.div>

          {/* VISUAL TIMELINE BAR (SLIDE 06 ASOSIDA) */}
          <div className="max-w-5xl mx-auto mb-10 p-6 sm:p-8 rounded-3xl bg-slate-900/90 border border-white/10 text-white shadow-2xl relative overflow-hidden backdrop-blur-2xl">
            <div className="text-xs font-mono font-bold text-slate-400 mb-6 flex items-center justify-between">
              <span className="flex items-center gap-2">
                <span className="w-2.5 h-2.5 rounded-full bg-coral animate-pulse" />
                Vaqt O‘qi: Hozir → 6 oy → 1 yil → 3 yil
              </span>
              <span className="text-amber-400 text-[11px] font-mono">Konservativ Prognoz</span>
            </div>

            {/* Connecting Timeline Line */}
            <div className="hidden lg:block absolute left-12 right-12 top-[125px] h-1 bg-gradient-to-r from-coral via-amber-500 via-brand to-mint rounded-full" />

            {/* 4 Timeline Stage Buttons */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 relative z-10">
              {/* STAGE 1: HOZIR */}
              <button
                onClick={() => setActiveRoadmapStage('now')}
                className={`p-4 rounded-2xl text-left border transition-all cursor-pointer flex flex-col justify-between ${
                  activeRoadmapStage === 'now'
                    ? 'bg-coral/80 border-coral shadow-lg shadow-coral/50 scale-[1.02]'
                    : 'bg-slate-800/80 border-slate-700 hover:border-slate-500 text-slate-300'
                }`}
              >
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-xs font-black uppercase text-coral">1-BOSQICH</span>
                    <span className="w-3.5 h-3.5 rounded-full bg-coral border-2 border-white shadow-sm" />
                  </div>
                  <h3 className="text-base font-black text-white">HOZIR</h3>
                  <div className="mt-3 space-y-1.5 text-[11px] text-slate-300 leading-snug">
                    <div className="flex items-start gap-1.5 font-medium">
                      <span className="text-coral">•</span> MVP + pilot bosqich
                    </div>
                    <div className="flex items-start gap-1.5 font-medium">
                      <span className="text-coral">•</span> Asosiy o‘rganishning moslashuvchan oqimi
                    </div>
                    <div className="flex items-start gap-1.5 font-medium">
                      <span className="text-coral">•</span> Dastlabki foydalanuvchilar
                    </div>
                  </div>
                </div>
                <div className="mt-4 pt-3 border-t border-white/10 text-[10px] text-coral font-bold flex items-center justify-between">
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
                    ? 'bg-ink/80 border-brand shadow-lg shadow-ink/50 scale-[1.02]'
                    : 'bg-slate-800/80 border-slate-700 hover:border-slate-500 text-slate-300'
                }`}
              >
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-xs font-black uppercase text-path">3-BOSQICH</span>
                    <span className="w-3.5 h-3.5 rounded-full bg-brand border-2 border-white shadow-sm" />
                  </div>
                  <h3 className="text-base font-black text-white">1 YIL</h3>
                  <div className="mt-3 space-y-1.5 text-[11px] text-slate-300 leading-snug">
                    <div className="flex items-start gap-1.5 font-bold text-path">
                      <span>•</span> 2 500 pullik foydalanuvchi
                    </div>
                    <div className="flex items-start gap-1.5 font-bold text-mint">
                      <span>•</span> ≈ 638 mln so‘m gross revenue
                    </div>
                    <div className="flex items-start gap-1.5 font-bold text-path">
                      <span>•</span> Zararsizlik nuqtasi ≈ 10-oy
                    </div>
                  </div>
                </div>
                <div className="mt-4 pt-3 border-t border-white/10 text-[10px] text-path font-bold flex items-center justify-between">
                  <span>Break-Even (10-oy)</span>
                  <span>Okt 2027</span>
                </div>
              </button>

              {/* STAGE 4: 3 YIL */}
              <button
                onClick={() => setActiveRoadmapStage('3years')}
                className={`p-4 rounded-2xl text-left border transition-all cursor-pointer flex flex-col justify-between ${
                  activeRoadmapStage === '3years'
                    ? 'bg-mint/80 border-mint shadow-lg shadow-mint/50 scale-[1.02]'
                    : 'bg-slate-800/80 border-slate-700 hover:border-slate-500 text-slate-300'
                }`}
              >
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-xs font-black uppercase text-mint">4-BOSQICH</span>
                    <span className="w-3.5 h-3.5 rounded-full bg-mint border-2 border-white shadow-sm" />
                  </div>
                  <h3 className="text-base font-black text-white">3 YIL</h3>
                  <div className="mt-3 space-y-1.5 text-[11px] text-slate-300 leading-snug">
                    <div className="flex items-start gap-1.5 font-medium">
                      <span className="text-mint">•</span> O‘zbekiston bo‘ylab masshtab
                    </div>
                    <div className="flex items-start gap-1.5 font-medium">
                      <span className="text-mint">•</span> B2B: maktab va o‘quv markazi
                    </div>
                    <div className="flex items-start gap-1.5 font-medium">
                      <span className="text-mint">•</span> Yangi fanlar, regional expansion
                    </div>
                  </div>
                </div>
                <div className="mt-4 pt-3 border-t border-white/10 text-[10px] text-mint font-bold flex items-center justify-between">
                  <span>Respublika & Region</span>
                  <span>2029-yil</span>
                </div>
              </button>
            </div>

            {/* Creative Footnote & Interactive Navigation Bar */}
            <div className="mt-8 pt-5 border-t border-white/10 flex flex-col lg:flex-row items-stretch lg:items-center justify-between gap-4">
              {/* Left Pill: Financial Forecast Disclaimer */}
              <div className="flex items-center gap-3 px-4 py-3 rounded-2xl bg-gradient-to-r from-slate-900/90 via-slate-800/80 to-amber-950/20 border border-slate-700/80 shadow-lg shadow-black/30 backdrop-blur-md group hover:border-amber-500/40 transition-all">
                <div className="w-8 h-8 rounded-xl bg-amber-500/15 border border-amber-500/30 flex items-center justify-center shrink-0 text-amber-400 shadow-sm shadow-amber-500/10 group-hover:scale-105 transition-transform">
                  <Info className="w-4 h-4" />
                </div>
                <div className="text-xs sm:text-sm text-slate-200 font-medium leading-relaxed">
                  <span className="text-amber-300 font-bold">1-yil raqamlari</span> — konservativ forecast;{' '}
                  <span className="text-path font-bold">3-yil ko‘rsatkichlari</span> — strategik target (fakt emas).
                </div>
              </div>

              {/* Right Pill: Interactive Stage Exploration Callout */}
              <div className="flex items-center justify-between sm:justify-start gap-3 px-4 py-3 rounded-2xl bg-gradient-to-r from-path/50 via-ink/40 to-ink/50 border border-path/40 shadow-lg shadow-path/30 backdrop-blur-md group hover:border-path transition-all">
                <div className="flex items-center gap-2.5 text-xs sm:text-sm font-bold text-path">
                  <span className="relative flex h-2.5 w-2.5">
                    <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-path opacity-75" />
                    <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-path" />
                  </span>
                  <span>Tugmalarni bosib, har bir bosqichning batafsil rejasini oching</span>
                </div>
                <div className="w-8 h-8 rounded-xl bg-path/20 border border-path/50 flex items-center justify-center shrink-0 text-path shadow-sm shadow-path/20 animate-bounce">
                  <ArrowUp className="w-4 h-4 stroke-[2.5]" />
                </div>
              </div>
            </div>
          </div>

          {/* DETAILED STAGE EXPLORATION CARD */}
          <div className="p-8 sm:p-10 rounded-3xl bg-slate-900/80 border border-white/10 max-w-5xl mx-auto shadow-2xl backdrop-blur-2xl mb-12">
            {activeRoadmapStage === 'now' && (
              <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="space-y-6">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-white/10 pb-4">
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="w-2.5 h-2.5 rounded-full bg-coral" />
                      <h3 className="text-xl font-black text-white">
                        1-Bosqich: HOZIR (MVP + Pilot Bosqich)
                      </h3>
                    </div>
                    <p className="text-xs text-slate-400 mt-1 flex items-center gap-3">
                      <span className="flex items-center gap-1 font-semibold text-coral">
                        <Calendar className="w-3.5 h-3.5" /> 12-Sentabr – 11-Oktyabr 2026 (Pitch Day 3.0)
                      </span>
                      <span className="flex items-center gap-1 font-bold text-mint bg-mint/80 px-2 py-0.5 rounded border border-mint">
                        <DollarSign className="w-3.5 h-3.5" /> Asoschilar Mablag‘i
                      </span>
                    </p>
                  </div>
                  <span className="px-3.5 py-1.5 rounded-full bg-coral/80 text-coral border border-coral text-xs font-black self-start sm:self-auto">
                    100% Jonli Ishlamoqda
                  </span>
                </div>

                <p className="text-slate-300 text-sm leading-relaxed">
                  Platformaning dastlabki <strong>G‘oya (Idea)</strong> va <strong>Prototip (Prototype)</strong> bosqichlari to‘liq muvaffaqiyatli yakunlandi. Bugungi kunda BilimYo‘l Smart Edu to‘liq ishlayotgan <strong>MVP holatida</strong>: Web SPA (React 19) va Mobil (Flutter) ilovalari, adaptiv diagnostika, server-side anti-cheat scoring (PostgreSQL RPC) va Gemini 2.5 Flash bilan integratsiyalashgan Yo‘lchi AI mentori amalda sinovdan o‘tmoqda.
                </p>

                <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 pt-1">
                  <div className="p-4 rounded-2xl bg-white/[0.03] border border-white/10 space-y-1">
                    <div className="text-xs font-black text-white flex items-center gap-1.5">
                      <CheckCircle2 className="w-4 h-4 text-coral" /> MVP + Pilot
                    </div>
                    <p className="text-[11px] text-slate-400">
                      Matematika va Ingliz tili fanlari to‘liq integratsiyalangan, 152 ta avtotestlar bilan himoyalangan.
                    </p>
                  </div>

                  <div className="p-4 rounded-2xl bg-white/[0.03] border border-white/10 space-y-1">
                    <div className="text-xs font-black text-white flex items-center gap-1.5">
                      <CheckCircle2 className="w-4 h-4 text-coral" /> Moslashuvchan Oqim
                    </div>
                    <p className="text-[11px] text-slate-400">
                      Asosiy o‘rganishning moslashuvchan oqimi: diagnostika → bilim matritsasi (0-100%) → individual dars.
                    </p>
                  </div>

                  <div className="p-4 rounded-2xl bg-white/[0.03] border border-white/10 space-y-1">
                    <div className="text-xs font-black text-white flex items-center gap-1.5">
                      <CheckCircle2 className="w-4 h-4 text-coral" /> Dastlabki Foydalanuvchilar
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
                      <span className="w-2.5 h-2.5 rounded-full bg-amber-500" />
                      <h3 className="text-xl font-black text-white">
                        2-Bosqich: 6 OY (Bozorga Moslik & Birinchi B2B Pilot)
                      </h3>
                    </div>
                    <p className="text-xs text-slate-400 mt-1 flex items-center gap-3">
                      <span className="flex items-center gap-1 font-semibold text-amber-300">
                        <Clock className="w-3.5 h-3.5" /> Muddat: 6 oy (Noyabr 2026 – Aprel 2027)
                      </span>
                      <span className="flex items-center gap-1 font-bold text-path bg-ink/80 px-2 py-0.5 rounded border border-brand-dark">
                        Pre-Seed Bosqichi
                      </span>
                    </p>
                  </div>
                  <span className="px-3.5 py-1.5 rounded-full bg-amber-950/80 text-amber-300 border border-amber-800 text-xs font-black self-start sm:self-auto">
                    Keyingi 6 Oylik Reja
                  </span>
                </div>

                <p className="text-slate-300 text-sm leading-relaxed">
                  Asosiy diqqat mahsulotning bozorga to‘liq mos kelishiga (<strong>Product-Market Fit</strong>) qaratiladi. B2C segmentida dastlabki <strong>500–700 nafar pullik faol obunachilar</strong> shakllantiriladi, o‘quvchilarning saqlanib qolish ko‘rsatkichi (Retention) oshiriladi va dastlabki B2B maktablar bilan pilot litsenziyalar yo‘lga qo‘yiladi.
                </p>

                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
                  <div className="p-4 rounded-2xl bg-amber-950/40 border border-amber-500/40 text-center">
                    <div className="text-xl sm:text-2xl font-black text-amber-300">500–700</div>
                    <div className="text-xs font-bold text-white mt-0.5">Pullik Foydalanuvchi</div>
                    <div className="text-[10px] text-slate-400">Oyiga 59 900 so‘m</div>
                  </div>

                  <div className="p-4 rounded-2xl bg-white/[0.03] border border-white/10 text-center">
                    <div className="text-xl sm:text-2xl font-black text-path">PMF</div>
                    <div className="text-xs font-bold text-white mt-0.5">Bozorga Mos Kelish</div>
                    <div className="text-[10px] text-slate-400">Haftalik o‘sish va tahlil</div>
                  </div>

                  <div className="p-4 rounded-2xl bg-white/[0.03] border border-white/10 text-center">
                    <div className="text-xl sm:text-2xl font-black text-mint">Takroriy Jalb</div>
                    <div className="text-xs font-bold text-white mt-0.5">Retention & Streak</div>
                    <div className="text-[10px] text-slate-400">Muntazam ta’lim odati</div>
                  </div>

                  <div className="p-4 rounded-2xl bg-white/[0.03] border border-white/10 text-center">
                    <div className="text-xl sm:text-2xl font-black text-path">1-B2B Pilot</div>
                    <div className="text-xs font-bold text-white mt-0.5">Maktablar Hamkorligi</div>
                    <div className="text-[10px] text-slate-400">O‘quvchi progressi</div>
                  </div>
                </div>
              </motion.div>
            )}

            {activeRoadmapStage === '1year' && (
              <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="space-y-6">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-white/10 pb-4">
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="w-2.5 h-2.5 rounded-full bg-brand" />
                      <h3 className="text-xl font-black text-white">
                        3-Bosqich: 1 YIL (Zararsizlik Nuqtasi & 638 Mln Gross Revenue)
                      </h3>
                    </div>
                    <p className="text-xs text-slate-400 mt-1 flex items-center gap-3">
                      <span className="flex items-center gap-1 font-semibold text-path">
                        <Calendar className="w-3.5 h-3.5" /> Muddat: 12 oy (Oktabr 2027 gacha)
                      </span>
                      <span className="flex items-center gap-1 font-bold text-mint bg-mint/80 px-2 py-0.5 rounded border border-mint">
                        Konservativ Iqtisodiy Prognoz
                      </span>
                    </p>
                  </div>
                  <span className="px-3.5 py-1.5 rounded-full bg-ink/80 text-path border border-brand-dark text-xs font-black self-start sm:self-auto">
                    Zararsizlik: 10-oy
                  </span>
                </div>

                <p className="text-slate-300 text-sm leading-relaxed">
                  Konservativ moliyaviy model asosida 1-yil yakuniga borib platforma <strong>2 500 nafar faol pullik o‘quvchiga</strong> va yil bo‘yicha jami <strong>≈638 million so‘m gross revenue</strong>ga yetadi. Operatsion xarajatlar va daromadlar nisbati bo‘yicha <strong>zararsizlik nuqtasiga (Break-even) taxminan 10-oyda</strong> erishiladi.
                </p>

                <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                  <div className="p-5 rounded-2xl bg-ink/40 border border-brand/40 text-center">
                    <div className="text-2xl sm:text-3xl font-black text-path">2 500</div>
                    <div className="text-xs font-bold text-white mt-1">Pullik Foydalanuvchi</div>
                    <div className="text-[11px] text-slate-400 mt-0.5">B2C oylik faol obuna</div>
                  </div>

                  <div className="p-5 rounded-2xl bg-mint/40 border border-mint/40 text-center">
                    <div className="text-2xl sm:text-3xl font-black text-mint">≈ 638 Mln</div>
                    <div className="text-xs font-bold text-white mt-1">Gross Revenue (So‘m)</div>
                    <div className="text-[11px] text-slate-400 mt-0.5">Yillik yalpi tushum</div>
                  </div>

                  <div className="p-5 rounded-2xl bg-ink/40 border border-brand/40 text-center">
                    <div className="text-2xl sm:text-3xl font-black text-path">10-oy</div>
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
                      <span className="w-2.5 h-2.5 rounded-full bg-mint" />
                      <h3 className="text-xl font-black text-white">
                        4-Bosqich: 3 YIL (Respublika Masshtabi & Regional Ekspansiya)
                      </h3>
                    </div>
                    <p className="text-xs text-slate-400 mt-1 flex items-center gap-3">
                      <span className="flex items-center gap-1 font-semibold text-mint">
                        <Calendar className="w-3.5 h-3.5" /> Uzoq Muddatli Strategik Maqsad (Target)
                      </span>
                      <span className="flex items-center gap-1 text-slate-400 text-[11px]">
                        2028–2029 Yillar
                      </span>
                    </p>
                  </div>
                  <span className="px-3.5 py-1.5 rounded-full bg-mint/80 text-mint border border-mint text-xs font-black self-start sm:self-auto">
                    Kengayish Bosqichi
                  </span>
                </div>

                <p className="text-slate-300 text-sm leading-relaxed">
                  BilimYo‘l Smart Edu butun O‘zbekiston bo‘ylab maktablar, o‘quv markazlari va o‘quvchilar uchun yagona milliy adaptiv ta’lim standartiga aylanadi. B2B korporativ paketlar, yangi maktab fanlari va Markaziy Osiyo mintaqasiga lokalizatsiya orqali ekspansiya qilinadi.
                </p>

                <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                  <div className="p-4 rounded-2xl bg-white/[0.03] border border-white/10 space-y-1">
                    <div className="text-xs font-black text-white flex items-center gap-1.5">
                      <Globe className="w-4 h-4 text-mint" /> O‘zbekiston Bo‘ylab Masshtab
                    </div>
                    <p className="text-[11px] text-slate-400">
                      Barcha viloyatlar va tuman maktablari o‘quvchilariga yetib borish, keng qamrovli B2C auditoriya.
                    </p>
                  </div>

                  <div className="p-4 rounded-2xl bg-white/[0.03] border border-white/10 space-y-1">
                    <div className="text-xs font-black text-white flex items-center gap-1.5">
                      <Briefcase className="w-4 h-4 text-mint" /> B2B: Maktab & O‘quv Markazi
                    </div>
                    <p className="text-[11px] text-slate-400">
                      Maktab va xususiy o‘quv markazlari uchun o‘quvchilar bilimini avtomatik diagnostika qiluvchi SaaS obunasi.
                    </p>
                  </div>

                  <div className="p-4 rounded-2xl bg-white/[0.03] border border-white/10 space-y-1">
                    <div className="text-xs font-black text-white flex items-center gap-1.5">
                      <Layers className="w-4 h-4 text-mint" /> Yangi Fanlar & Regional
                    </div>
                    <p className="text-[11px] text-slate-400">
                      Fizika, Kimyo, Biologiya, IT fanlari qo‘shilishi hamda Markaziy Osiyo bozorlariga regional chiqish.
                    </p>
                  </div>
                </div>
              </motion.div>
            )}
          </div>
        </section>

        {/* 8. SECTION 5: MONETIZATSIYA VA UNIT ECONOMICS (SLIDE 03 ASOSIDA) */}
        <section id="monetization-section" className="py-20 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-white/10 relative">
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: '-60px' }}
            transition={{ duration: 0.6 }}
            className="text-center max-w-3xl mx-auto mb-16"
          >
            <span className="text-mint bg-mint/80 px-3.5 py-1 rounded-full border border-mint/30 text-xs font-mono font-bold tracking-widest uppercase shadow-[0_0_15px_rgba(6,150,105,0.2)]">
              5. BIZNES MODEL • MONETIZATSIYA (SLIDE 03)
            </span>
            <h2 className="text-3xl sm:text-5xl font-black text-white mt-3 tracking-tight">
              Monetizatsiya va Unit Economics
            </h2>
            <p className="text-slate-300 text-sm sm:text-base mt-3">
              Freemium → Premium obuna. To‘lovchi: o‘quvchi va oilalar (B2C) hamda maktablar (B2B SaaS).
            </p>
          </motion.div>

          {/* Keynote-Grade Pricing Box */}
          <div className="max-w-5xl mx-auto p-8 sm:p-12 rounded-3xl bg-gradient-to-b from-slate-900 via-slate-950 to-black border-2 border-mint/40 text-white shadow-[0_0_60px_rgba(6,150,105,0.18)] relative overflow-hidden backdrop-blur-2xl">
            <div className="absolute top-0 right-0 w-64 h-64 bg-mint/10 rounded-full blur-3xl pointer-events-none" />

            <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-white/10 pb-6 mb-8">
              <div>
                <span className="text-mint text-xs font-mono font-bold tracking-widest uppercase flex items-center gap-2">
                  <span className="w-2 h-2 rounded-full bg-mint animate-pulse" /> BIZNES VA DAROMAD STRUKTURASI
                </span>
                <h3 className="text-2xl sm:text-3xl font-extrabold text-white mt-1">
                  B2C Freemium → Premium Obuna
                </h3>
              </div>
              <div className="self-start md:self-auto">
                <span className="px-4 py-1.5 rounded-full bg-mint/20 text-mint border border-mint/40 text-xs font-black">
                  B2C + B2B SaaS Modeli
                </span>
              </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-center">
              {/* Left Keynote Price Card */}
              <motion.div
                whileHover={{ scale: 1.02 }}
                className="lg:col-span-5 p-8 rounded-3xl bg-black/80 border-2 border-mint/70 shadow-[0_0_35px_rgba(6,150,105,0.25)] text-center space-y-3 relative group"
              >
                <div className="text-xs font-mono font-black tracking-widest uppercase text-mint">
                  PREMIUM OBUNA
                </div>
                <div className="text-5xl sm:text-6xl font-black text-white tracking-tight">
                  59 900
                </div>
                <div className="text-xs text-slate-400 font-bold uppercase tracking-wider">
                  so‘m / oy
                </div>
                <div className="pt-4 border-t border-white/10 text-xs text-slate-300 leading-relaxed">
                  Oddiy repetitorning bitta darsi narxiga butun 1 oylik cheksiz shaxsiy repetitor va Yo‘lchi AI mentori.
                </div>
                <div className="pt-2">
                  <span className="inline-block px-3 py-1 rounded-full bg-mint/80 border border-mint/50 text-[10px] text-mint font-bold">
                    Foydalanuvchilar uchun 10x arzonroq
                  </span>
                </div>
              </motion.div>

              {/* Right Value Propositions (Slide 03 bullet items) */}
              <div className="lg:col-span-7 space-y-4">
                <div className="p-4 sm:p-5 rounded-2xl bg-white/[0.03] border-l-4 border-mint border-r border-t border-b border-white/10 space-y-1">
                  <div className="text-xs font-mono font-bold text-mint uppercase">
                    Kim to‘laydi?
                  </div>
                  <div className="text-sm sm:text-base font-semibold text-white">
                    O‘quvchi va oilalar (B2C)
                  </div>
                  <p className="text-xs text-slate-400">
                    O‘quvchi bilim darajasini real vaqtda ko‘rib, samarasiz repetitor xarajatlarini tejaydi.
                  </p>
                </div>

                <div className="p-4 sm:p-5 rounded-2xl bg-white/[0.03] border-l-4 border-mint border-r border-t border-b border-white/10 space-y-1">
                  <div className="text-xs font-mono font-bold text-mint uppercase">
                    Nima uchun to‘laydi?
                  </div>
                  <div className="text-sm sm:text-base font-semibold text-white">
                    Individual learning path + AI tavsiyalar + chuqur analitika
                  </div>
                  <p className="text-xs text-slate-400">
                    Xatolarni tushuntiruvchi Yo‘lchi AI mentori, zaif nuqtalarni mustahkamlash va shaxsiy o‘quv rejasi uchun.
                  </p>
                </div>

                <div className="p-4 sm:p-5 rounded-2xl bg-white/[0.03] border-l-4 border-mint border-r border-t border-b border-white/10 space-y-1">
                  <div className="text-xs font-mono font-bold text-mint uppercase">
                    Free (Bepul) Rejada nima bor?
                  </div>
                  <div className="text-sm sm:text-base font-semibold text-white">
                    Asosiy darslar va cheklangan mashqlar — konversiya kanali
                  </div>
                  <p className="text-xs text-slate-400">
                    Har bir yangi foydalanuvchi bepul diagnostika va dastlabki darslarni sinab ko‘rib, Premium obunaga oson konvertatsiya bo‘ladi.
                  </p>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* 9. SECTION 6: TEXNOLOGIK ARXITEKTURA & INTERAKTIV KOD KONSOLE */}
        <section id="tech-architecture" className="py-20 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-white/10 relative">
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: '-60px' }}
            transition={{ duration: 0.6 }}
            className="text-center max-w-3xl mx-auto mb-16"
          >
            <span className="text-path bg-path/80 px-3.5 py-1 rounded-full border border-path/30 text-xs font-mono font-bold tracking-widest uppercase shadow-[0_0_15px_rgba(13,154,214,0.2)]">
              6. ASOSIY BOSQICH • TEXNOLOGIK CHUQURLIK
            </span>
            <h2 className="text-3xl sm:text-5xl font-black text-white mt-3 tracking-tight">
              Arxitektura va Jonli API Konsoli
            </h2>
            <p className="text-slate-300 text-sm sm:text-base mt-3">
              Hakamlar va texnik ekspertlar uchun tizimning server arxitekturasi va real Edge kod namunalari.
            </p>
          </motion.div>

          <div className="max-w-4xl mx-auto rounded-3xl bg-slate-950 border border-white/10 overflow-hidden shadow-2xl backdrop-blur-2xl">
            {/* Terminal Header */}
            <div className="p-4 bg-slate-900/90 border-b border-white/10 flex flex-wrap items-center justify-between gap-3">
              <div className="flex items-center gap-2">
                <span className="w-3 h-3 rounded-full bg-coral" />
                <span className="w-3 h-3 rounded-full bg-amber-500" />
                <span className="w-3 h-3 rounded-full bg-mint" />
                <span className="ml-2 font-mono text-xs text-slate-300 font-bold">bilimyol-core-api</span>
              </div>

              {/* API Tabs */}
              <div className="flex items-center gap-1.5 text-xs font-mono">
                <button
                  onClick={() => setActiveApiTab('diagnostics')}
                  className={`px-3 py-1 rounded-lg transition-all cursor-pointer ${
                    activeApiTab === 'diagnostics'
                      ? 'bg-path/20 text-path border border-path/50 font-bold'
                      : 'text-slate-400 hover:text-white'
                  }`}
                >
                  1. Diagnostika
                </button>
                <button
                  onClick={() => setActiveApiTab('lessons')}
                  className={`px-3 py-1 rounded-lg transition-all cursor-pointer ${
                    activeApiTab === 'lessons'
                      ? 'bg-brand/20 text-path border border-brand/50 font-bold'
                      : 'text-slate-400 hover:text-white'
                  }`}
                >
                  2. AI Generator
                </button>
                <button
                  onClick={() => setActiveApiTab('scoring')}
                  className={`px-3 py-1 rounded-lg transition-all cursor-pointer ${
                    activeApiTab === 'scoring'
                      ? 'bg-amber-500/20 text-amber-300 border border-amber-500/50 font-bold'
                      : 'text-slate-400 hover:text-white'
                  }`}
                >
                  3. Anti-Cheat RPC
                </button>
              </div>
            </div>

            {/* Terminal Body */}
            <div className="p-6 font-mono text-xs space-y-4">
              {activeApiTab === 'diagnostics' && (
                <>
                  <div className="text-slate-400 text-[11px]">
                    # Adaptiv Savol Tanlash Algoritmi (AdaptiveQuestionSelector.ts)
                  </div>
                  <div className="p-4 rounded-xl bg-black/60 border border-white/5 text-path overflow-x-auto">
                    <pre>{`// O‘quvchi javobiga qarab qiyinlik darajasi real vaqtda moslashadi
const nextQuestion = AdaptiveEngine.selectNextQuestion({
  currentSkillMastery: 42, // Foizda (0-100%)
  recentAttempts: ['correct', 'wrong', 'correct'],
  targetDifficulty: 'medium',
  excludedQuestionIds: ['q_math_01', 'q_math_02']
});

console.log('Keyingi optimal savol:', nextQuestion.id);`}</pre>
                  </div>
                  <div className="text-slate-400 text-[11px]">Server Response (JSON):</div>
                  <div className="p-4 rounded-xl bg-black/60 border border-path/40 text-mint overflow-x-auto">
                    <pre>{`{
  "status": "ready",
  "skill_id": "skill_math_functions",
  "recommended_difficulty": "medium",
  "reason": "O‘quvchi 'Tenglamalar' mavzusini 80% o‘zlashtirgan, endi 'Funksiyalar' ga o‘tildi.",
  "latency_ms": 48
}`}</pre>
                  </div>
                </>
              )}

              {activeApiTab === 'lessons' && (
                <>
                  <div className="text-slate-400 text-[11px]">
                    # Gemini 2.5 Flash bilan Dars Generatsiyasi (generate-lesson Edge Function)
                  </div>
                  <div className="p-4 rounded-xl bg-black/60 border border-white/5 text-path overflow-x-auto">
                    <pre>{`// Deno Edge Function: Google Gemini 2.5 Flash chaqiruvi
const response = await aiClient.models.generateContent({
  model: 'gemini-2.5-flash',
  contents: [
    { role: 'user', parts: [{ text: generateLessonPrompt(skill, currentScore) }] }
  ],
  config: {
    temperature: 0.3,
    responseMimeType: 'application/json',
    responseSchema: LessonJsonSchema
  }
});`}</pre>
                  </div>
                  <div className="text-slate-400 text-[11px]">Server Response (JSON):</div>
                  <div className="p-4 rounded-xl bg-black/60 border border-brand/40 text-path overflow-x-auto">
                    <pre>{`{
  "lesson_id": "gen_lesson_9210",
  "title": "Chiziqli Funksiyaning Grafik Modeli",
  "steps": [
    { "type": "concept", "summary": "y = kx + b formulasi burchak koeffitsienti bilan ishlaydi" },
    { "type": "visual", "interactive_model": "linear_graph_builder" },
    { "type": "reinforcement", "check_question": "k musbat bo‘lsa grafik qaysi choraklardan o‘tadi?" }
  ]
}`}</pre>
                  </div>
                </>
              )}

              {activeApiTab === 'scoring' && (
                <>
                  <div className="text-slate-400 text-[11px]">
                    # PostgreSQL RPC: submit_answer_attempt() — Server-side xolis scoring va Anti-Cheat
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
            </div>
          </div>
        </section>

        {/* 10. SECTION 7: INTERAKTIV AI-CHATBOT (SAVOL-JAVOB EMULATORI) */}
        <section id="ai-chatbot" className="py-20 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-white/10 relative">
          <motion.div
            initial={{ opacity: 0, y: 30 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true, margin: '-60px' }}
            transition={{ duration: 0.6 }}
            className="text-center max-w-3xl mx-auto mb-16"
          >
            <span className="text-mint bg-mint/80 px-3.5 py-1 rounded-full border border-mint/30 text-xs font-mono font-bold tracking-widest uppercase shadow-[0_0_15px_rgba(6,150,105,0.2)]">
              QO‘SHIMCHA BONUS VAZIFA • LIVE DEMO
            </span>
            <h2 className="text-3xl sm:text-5xl font-black text-white mt-3 tracking-tight">
              Yo‘lchi AI Bilan Jonli Muloqot
            </h2>
            <p className="text-slate-300 text-sm sm:text-base mt-3">
              Yo‘lchi AI bilan hoziroq real vaqtda sinab ko‘ring yoki quyidagi namunaviy savollarni bosing.
            </p>
          </motion.div>

          <div className="max-w-3xl mx-auto rounded-3xl bg-slate-900/90 border border-white/15 overflow-hidden shadow-2xl backdrop-blur-2xl">
            {/* Chat Header */}
            <div className="p-4 bg-slate-950/80 border-b border-white/10 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <YolchiAIMascot size="sm" mood="happy" />
                <div>
                  <h4 className="text-sm font-bold text-white flex items-center gap-2">
                    Yo‘lchi AI Mentori
                    <span className="w-2 h-2 rounded-full bg-mint animate-pulse" />
                  </h4>
                  <p className="text-[10px] text-slate-400">Google Gemini 2.5 Flash bilan integratsiyalashgan</p>
                </div>
              </div>
              <button
                onClick={onNavigateAiTutor}
                className="text-xs text-path hover:text-path underline font-bold flex items-center gap-1 cursor-pointer"
              >
                To‘liq ekranda ochish →
              </button>
            </div>

            {/* Chat Body */}
            <div className="p-5 space-y-4 max-h-80 overflow-y-auto bg-black/40">
              {chatMessages.map((msg, idx) => (
                <div
                  key={idx}
                  className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}
                >
                  <div
                    className={`max-w-[85%] p-4 rounded-2xl text-xs sm:text-sm leading-relaxed ${
                      msg.role === 'user'
                        ? 'bg-gradient-to-r from-path to-brand text-white font-medium rounded-br-none shadow-md'
                        : 'bg-slate-800/90 text-slate-200 rounded-bl-none border border-white/10 shadow-md'
                    }`}
                  >
                    {msg.text}
                    <div
                      className={`text-[9px] mt-1 text-right ${
                        msg.role === 'user' ? 'text-path' : 'text-slate-400'
                      }`}
                    >
                      {msg.time}
                    </div>
                  </div>
                </div>
              ))}

              {isBotThinking && (
                <div className="flex justify-start">
                  <div className="p-3 rounded-2xl bg-slate-800 border border-white/10 text-xs text-path flex items-center gap-2 animate-pulse shadow-md">
                    <Sparkles className="w-3.5 h-3.5 animate-spin" /> Yo‘lchi AI tahlil qilmoqda...
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
                    className="text-left text-[11px] px-3 py-1.5 rounded-xl bg-white/[0.04] hover:bg-white/10 border border-white/10 text-slate-300 hover:text-white shadow-sm transition-colors cursor-pointer"
                  >
                    💡 {p.q}
                  </button>
                ))}
              </div>
            </div>

            {/* Chat Input */}
            <div className="p-3 bg-slate-900 border-t border-white/10 flex items-center gap-2">
              <input
                type="text"
                value={inputQuestion}
                onChange={(e) => setInputQuestion(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && handleSendQuestion()}
                placeholder="Yo‘lchi AI ga ixtiyoriy savol bering..."
                className="flex-1 bg-black/50 border border-white/15 rounded-xl px-4 py-2.5 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-path focus:bg-black/70"
              />
              <button
                onClick={() => handleSendQuestion()}
                className="p-2.5 bg-gradient-to-r from-path to-brand hover:from-path hover:to-brand text-slate-950 rounded-xl font-bold transition-colors cursor-pointer shadow-md"
              >
                <Send className="w-4 h-4" />
              </button>
            </div>
          </div>
        </section>

        {/* 11. SECTION 8: /DEMO VIDEO CALLOUT & CTA */}
        <section id="demo-cta" className="py-20 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-white/10 relative">
          <motion.div
            whileHover={{ scale: 1.01 }}
            className="p-8 sm:p-14 rounded-3xl bg-gradient-to-r from-path/70 via-ink/70 to-ink/70 border-2 border-path/40 shadow-[0_0_80px_rgba(13,154,214,0.25)] text-center max-w-4xl mx-auto space-y-6 text-white backdrop-blur-2xl relative overflow-hidden"
          >
            <div className="absolute top-0 right-0 w-80 h-80 bg-path/10 rounded-full blur-3xl pointer-events-none" />

            <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-white/10 text-path text-xs font-black backdrop-blur-md border border-white/15">
              <Play className="w-3.5 h-3.5 fill-current" />
              6-TALAB: /demo SAHIFASI TAYYOR
            </div>

            <h2 className="text-3xl sm:text-5xl font-black text-white tracking-tight">
              Haqiqiy Ekran Yozuvi & Ovozli Demo Video
            </h2>

            <p className="text-slate-300 text-sm sm:text-base max-w-2xl mx-auto leading-relaxed">
              Hakamlar va investorlar uchun platformaning to‘liq 1–5 daqiqalik dars jarayoni, diagnostikasi va ishlash mexanizmi aks etgan maxsus <strong>/demo</strong> sahifasi tayyorlandi.
            </p>

            <div className="flex flex-wrap items-center justify-center gap-4 pt-4">
              <button
                onClick={() => {
                  triggerCelebration();
                  onNavigateDemo();
                }}
                className="px-8 py-4 rounded-2xl bg-white hover:bg-slate-100 text-slate-950 font-black text-base shadow-2xl flex items-center gap-2.5 cursor-pointer transition-all transform hover:-translate-y-0.5 active:scale-[0.98]"
              >
                <span className="text-slate-950 font-black">/demo Sahifasiga O‘tish</span>
                <ArrowRight className="w-4 h-4 text-slate-950" />
              </button>

              <button
                onClick={() => {
                  triggerCelebration();
                  onNavigateApp();
                }}
                className="px-8 py-4 rounded-2xl bg-slate-900/90 hover:bg-slate-800 text-white font-bold text-base border border-white/25 hover:border-path shadow-xl backdrop-blur-md flex items-center gap-2.5 transition-all transform hover:-translate-y-0.5 active:scale-[0.98] cursor-pointer"
              >
                <Zap className="w-4 h-4 text-amber-400 fill-amber-400/30" />
                <span className="text-white font-bold">Jonli Prototip</span>
              </button>
            </div>
          </motion.div>
        </section>

        {/* 12. FOOTER & FINAL CALL TO ACTION */}
        <footer className="py-14 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto border-t border-white/10 text-center space-y-4 text-slate-400">
          <div className="flex items-center justify-center gap-2">
            <BilimYolLogo size="md" variant="dark" />
          </div>
          <p className="text-xs text-slate-400 max-w-xl mx-auto">
            BilimYo‘l Smart Edu — Pitch Day 3.0 (AIFU) ishtirokchisi. Barcha huquqlar himoyalangan © 2026.
          </p>
          <div className="flex flex-wrap items-center justify-center gap-4 text-xs font-bold text-path">
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
