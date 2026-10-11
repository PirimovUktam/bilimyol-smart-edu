import React, { useState, useEffect, useRef } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  Play,
  Pause,
  RotateCcw,
  Volume2,
  VolumeX,
  ArrowRight,
  Sparkles,
  CheckCircle2,
  Smartphone,
  Bot,
  Zap,
  BookOpen,
  Compass,
  TrendingUp,
  ShieldCheck,
  Video,
  Download,
  ExternalLink,
  AlertCircle,
  RefreshCw,
} from 'lucide-react';
import { Button } from '@/presentation/components/Button';
import { BilimYolLogo } from '@/presentation/components/BilimYolLogo';
import { YolchiAIMascot } from '@/presentation/components/YolchiAIMascot';

interface DemoShowcaseViewProps {
  onNavigateCourses: () => void;
  onNavigateDashboard: () => void;
  onNavigateAiTutor: () => void;
  onNavigatePitch: () => void;
}

const DEMO_CHAPTERS = [
  {
    title: '1. Kirish va Fan Tanlash',
    timestamp: '00:00 - 00:16',
    secondsStart: 0,
    description: 'O‘quvchi platformaga kiradi, Matematika yoki Ingliz tili fanini tanlaydi va o‘z maqsadini belgilaydi.',
    screen: 'course-selection',
    highlightBadge: 'Tanlov & Onboarding',
  },
  {
    title: '2. Shaxsiy Maqsadni Belgilash',
    timestamp: '00:16 - 00:29',
    secondsStart: 16,
    description: 'O‘quvchi o‘zining sinfi va maqsadini tanlaydi: maktab dasturi, olimpiada yoki imtihonga tayyorgarlik.',
    screen: 'onboarding',
    highlightBadge: 'O‘quv Maqsadi',
  },
  {
    title: '3. Adaptiv Diagnostika Testi',
    timestamp: '00:29 - 00:41',
    secondsStart: 29,
    description: '8 ta aqlli savol orqali barcha ko‘nikmalar xolis skanerlanadi va bilim darajasi aniqlanadi.',
    screen: 'placement',
    highlightBadge: 'Placement Test',
  },
  {
    title: '4. Ko‘nikmalar Xaritasi (Knowledge Map)',
    timestamp: '00:41 - 00:54',
    secondsStart: 41,
    description: '0-100% shkalada shakllantirilgan bilim xaritasi va o‘quvchining kuchli/zaif nuqtalari ochiladi.',
    screen: 'knowledge-map',
    highlightBadge: 'Knowledge Graph',
  },
  {
    title: '5. Shaxsiy O‘quv Traektoriyasi',
    timestamp: '00:54 - 01:06',
    secondsStart: 54,
    description: 'Standart kitob emas — aynan shu o‘quvchi o‘rganishi zarur bo‘lgan qadamli o‘quv yo‘li shakllanadi.',
    screen: 'roadmap',
    highlightBadge: 'Roadmap',
  },
  {
    title: '6. Interaktiv Dars (Nazariya & Misol)',
    timestamp: '01:06 - 01:17',
    secondsStart: 66,
    description: 'Nazariya, formulalar va ko‘rgazmali misollar bilan dars bosqichma-bosqich o‘zlashtiriladi.',
    screen: 'lesson',
    highlightBadge: 'Nazariya & Formula',
  },
  {
    title: '7. Amaliy Mashq va Test Yechish',
    timestamp: '01:17 - 01:27',
    secondsStart: 77,
    description: 'Nazariyadan so‘ng darhol interaktiv amaliyot boshlanadi va javob tekshirishga yuboriladi.',
    screen: 'lesson',
    highlightBadge: 'Amaliy Mashq',
  },
  {
    title: '8. Server-Side Scoring & Anti-Cheat',
    timestamp: '01:27 - 01:39',
    secondsStart: 87,
    description: 'Baholash PostgreSQL RPC orqali serverda mustaqil bajariladi. +20 XP beriladi va ballar yangilanadi.',
    screen: 'scoring',
    highlightBadge: 'Anti-Cheat Himoyasi',
  },
  {
    title: '9. Yo‘lchi AI Pedagogik Mentori',
    timestamp: '01:39 - 01:50',
    secondsStart: 99,
    description: 'Gemini bilan integratsiyalashgan Yo‘lchi AI xatolikni pedagogik tahlil qilib, to‘g‘ri fikrlashga yo‘naltiradi.',
    screen: 'ai-tutor',
    highlightBadge: 'Yo‘lchi AI & Gemini',
  },
  {
    title: '10. O‘quvchi Dashboardi va Natijalar',
    timestamp: '01:50 - 02:02',
    secondsStart: 110,
    description: 'O‘quvchi o‘sish ko‘rsatkichlarini, kundalik streak va yangi ochilgan darslarini o‘z panelida ko‘radi.',
    screen: 'dashboard',
    highlightBadge: 'O‘quvchi Dashboardi',
  },
  {
    title: '11. Yakun (Pitch Day 3.0)',
    timestamp: '02:02 - 02:13',
    secondsStart: 122,
    description: 'BilimYo‘l Smart Edu — darslik emas, shaxsiy ta’lim yo‘li. Bilim bilan o‘z yo‘lingizni toping.',
    screen: 'dashboard',
    highlightBadge: 'Pitch Day 3.0',
  },
];

const TOTAL_DURATION_SECONDS = 133; // 2 minutes 13 seconds (Exact voiceover length)

export const DemoShowcaseView: React.FC<DemoShowcaseViewProps> = ({
  onNavigateCourses,
  onNavigateDashboard,
  onNavigateAiTutor,
  onNavigatePitch,
}) => {
  // Player mode: real MP4 video or interactive simulation
  const [playerMode, setPlayerMode] = useState<'video' | 'simulation'>('video');

  // Video element ref and playback state
  const videoRef = useRef<HTMLVideoElement>(null);
  const [isVideoPlaying, setIsVideoPlaying] = useState(false);
  const [videoError, setVideoError] = useState<string | null>(null);

  // Simulation state
  const [isPlaying, setIsPlaying] = useState(true);
  const [currentSeconds, setCurrentSeconds] = useState(25);
  const [isMuted, setIsMuted] = useState(false);
  const [activeChapterIndex, setActiveChapterIndex] = useState(0);

  // Simulation timer
  useEffect(() => {
    let interval: NodeJS.Timeout | null = null;
    if (playerMode === 'simulation' && isPlaying) {
      interval = setInterval(() => {
        setCurrentSeconds((prev) => {
          if (prev >= TOTAL_DURATION_SECONDS) {
            return 0;
          }
          const next = prev + 1;
          const foundIndex = DEMO_CHAPTERS.findLastIndex((c) => next >= c.secondsStart);
          if (foundIndex !== -1 && foundIndex !== activeChapterIndex) {
            setActiveChapterIndex(foundIndex);
          }
          return next;
        });
      }, 1000);
    }
    return () => {
      if (interval) clearInterval(interval);
    };
  }, [playerMode, isPlaying, activeChapterIndex]);

  const formatTime = (secs: number) => {
    const m = Math.floor(secs / 60);
    const s = Math.floor(secs % 60);
    return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  };

  const currentChapter = DEMO_CHAPTERS[activeChapterIndex] || DEMO_CHAPTERS[0];

  const handleToggleVideoPlay = () => {
    if (!videoRef.current) return;
    if (videoRef.current.paused) {
      videoRef.current
        .play()
        .then(() => {
          setIsVideoPlaying(true);
          setVideoError(null);
        })
        .catch((err) => {
          console.warn('Video playback trigger:', err);
          // If browser blocked unmuted autoplay, try with muted
          if (videoRef.current) {
            videoRef.current.muted = true;
            videoRef.current.play().then(() => {
              setIsVideoPlaying(true);
              setVideoError(null);
            }).catch(() => {
              setVideoError("Videoni ijro etishda xatolik yuz berdi. Iltimos quyidagi 'Alohida oynada ochish' havolasidan foydalaning.");
            });
          }
        });
    } else {
      videoRef.current.pause();
      setIsVideoPlaying(false);
    }
  };

  const handleJumpToChapter = (idx: number) => {
    setActiveChapterIndex(idx);
    const targetSeconds = DEMO_CHAPTERS[idx].secondsStart;
    setCurrentSeconds(targetSeconds);

    if (playerMode === 'video' && videoRef.current) {
      videoRef.current.currentTime = targetSeconds;
      videoRef.current.play().then(() => {
        setIsVideoPlaying(true);
        setVideoError(null);
      }).catch(() => {});
    }
  };

  return (
    <div className="min-h-screen bg-[#0A0D14] text-white selection:bg-cyan-500 selection:text-black">
      {/* Background Decorative Mesh Gradients */}
      <div className="fixed inset-0 pointer-events-none overflow-hidden z-0">
        <div className="absolute -top-40 -left-40 w-96 h-96 bg-indigo-600/20 rounded-full blur-[140px]" />
        <div className="absolute top-1/3 -right-40 w-[500px] h-[500px] bg-cyan-500/15 rounded-full blur-[160px]" />
        <div className="absolute bottom-10 left-1/4 w-[450px] h-[450px] bg-emerald-500/10 rounded-full blur-[150px]" />
      </div>

      <div className="relative z-10 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-12">
        {/* TOP BAR */}
        <div className="flex flex-wrap items-center justify-between gap-4 pb-6 border-b border-white/10">
          <div className="flex items-center gap-3">
            <BilimYolLogo size="md" />
            <span className="text-slate-600">/</span>
            <span className="text-xs font-black uppercase tracking-wider text-cyan-400 bg-cyan-500/10 border border-cyan-500/20 px-2.5 py-1 rounded-xl">
              Demo Showcase (/demo)
            </span>
          </div>

          <div className="flex items-center gap-3">
            <button
              onClick={onNavigatePitch}
              className="text-xs font-bold text-slate-300 hover:text-white transition-colors cursor-pointer"
            >
              ← Pitch Day 3.0 Taqdimotiga Qaytish
            </button>
            <Button
              variant="primary"
              size="sm"
              onClick={onNavigateCourses}
              className="bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-black text-xs px-4 py-2 rounded-xl cursor-pointer"
            >
              Jonli Prototipni Ochish <ArrowRight className="w-3.5 h-3.5" />
            </Button>
          </div>
        </div>

        {/* DEMO HERO HEADER */}
        <div className="text-center max-w-3xl mx-auto space-y-4">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-indigo-500/10 border border-indigo-500/20 text-indigo-400 text-xs font-bold">
            <Sparkles className="w-3.5 h-3.5 text-amber-300" />
            <span>Pitch Day 3.0 — 6-Talab: /demo Sahifasi</span>
          </div>

          <h1 className="text-3xl sm:text-5xl font-black text-transparent bg-clip-text bg-gradient-to-r from-white via-slate-100 to-cyan-300">
            BilimYo‘l Smart Edu Demo Videosi
          </h1>

          <p className="text-sm sm:text-base text-slate-400">
            Haqiqiy ishlayotgan ilovadan 9:16 telefon ekranida yozib olingan 2 daqiqa 13 soniyalik professional ovozli video: diagnostikadan tortib to Yo‘lchi AI orqali darsni mustahkamlashgacha.
          </p>

          {/* Mode Switcher Tabs */}
          <div className="inline-flex p-1 rounded-2xl bg-white/5 border border-white/10 backdrop-blur-md">
            <button
              onClick={() => setPlayerMode('video')}
              className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                playerMode === 'video'
                  ? 'bg-cyan-500 text-slate-950 shadow-md font-black'
                  : 'text-slate-300 hover:text-white'
              }`}
            >
              <Video className="w-3.5 h-3.5" />
              <span>1. Haqiqiy MP4 Video Pleer (9:16 Ovozli)</span>
            </button>
            <button
              onClick={() => setPlayerMode('simulation')}
              className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                playerMode === 'simulation'
                  ? 'bg-indigo-600 text-white shadow-md font-black'
                  : 'text-slate-300 hover:text-white'
              }`}
            >
              <Smartphone className="w-3.5 h-3.5" />
              <span>2. Interaktiv Qadamlar Simulyatori</span>
            </button>
          </div>
        </div>

        {/* 6.1. DEMO-VIDEO PLAYER CONTAINER */}
        <div className="rounded-3xl bg-slate-900/90 border-2 border-cyan-500/30 shadow-2xl shadow-cyan-950/50 overflow-hidden backdrop-blur-xl">
          {/* Top Video Header Bar */}
          <div className="p-4 bg-slate-950/80 border-b border-white/10 flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="flex gap-1.5">
                <span className="w-3 h-3 rounded-full bg-rose-500/80 inline-block" />
                <span className="w-3 h-3 rounded-full bg-amber-500/80 inline-block" />
                <span className="w-3 h-3 rounded-full bg-emerald-500/80 inline-block" />
              </div>
              <span className="text-xs font-bold text-slate-300">
                BilimYo‘l Smart Edu — Haqiqiy Mahsulot Ekran Yozuvi (2:13 min • O‘zbekcha Ovoz)
              </span>
            </div>

            <div className="flex items-center gap-2">
              <span className="px-2 py-0.5 rounded bg-cyan-500/20 text-cyan-300 text-[10px] font-black border border-cyan-500/40">
                1080×1920 Full HD
              </span>
              <a
                href="/videos/bilimyol-pitch-demo.mp4"
                download="bilimyol-pitch-demo.mp4"
                className="px-2.5 py-1 rounded bg-white/10 hover:bg-white/20 text-slate-200 text-[11px] font-bold flex items-center gap-1 transition-colors"
                title="Videoni yuklab olish"
              >
                <Download className="w-3 h-3" />
                <span>MP4</span>
              </a>
            </div>
          </div>

          {/* MAIN PLAYER AREA */}
          {playerMode === 'video' ? (
            /* 1. Real Video Player with Dual MP4/WebM Fallback */
            <div className="w-full bg-black/90 p-4 sm:p-8 flex flex-col items-center justify-center">
              <div className="w-full max-w-[420px] rounded-3xl overflow-hidden shadow-2xl border-2 border-cyan-500/30 bg-black aspect-[9/16] max-h-[720px] relative group">
                <video
                  ref={videoRef}
                  poster="/videos/bilimyol-pitch-demo-poster.jpg"
                  controls
                  playsInline
                  preload="auto"
                  className="w-full h-full object-contain bg-black cursor-pointer"
                  onClick={handleToggleVideoPlay}
                  onPlay={() => {
                    setIsVideoPlaying(true);
                    setVideoError(null);
                  }}
                  onPause={() => setIsVideoPlaying(false)}
                  onError={() => {
                    setVideoError('Video formatini avtomatik yuklashda cheklov yuz berdi. Quyidagi havolalar orqali to‘g‘ridan-to‘g‘ri oching.');
                  }}
                >
                  <source src="/videos/bilimyol-pitch-demo.mp4" type="video/mp4" />
                  <source src="/videos/bilimyol-pitch-demo.webm" type="video/webm" />
                  Sizning brauzeringiz HTML5 videoni qo‘llab-quvvatlamaydi.
                </video>

                {/* Big Center Play Overlay Button when paused */}
                {!isVideoPlaying && !videoError && (
                  <button
                    onClick={handleToggleVideoPlay}
                    className="absolute inset-0 m-auto w-20 h-20 rounded-full bg-cyan-500/95 hover:bg-cyan-400 text-slate-950 flex items-center justify-center shadow-2xl shadow-cyan-500/50 transition-all hover:scale-110 cursor-pointer z-20 backdrop-blur-sm"
                    title="Videoni qo‘yish"
                    aria-label="Videoni ijro etish"
                  >
                    <Play className="w-9 h-9 fill-current ml-1" />
                  </button>
                )}

                {/* Error Banner Fallback if decoding error occurs */}
                {videoError && (
                  <div className="absolute inset-0 bg-slate-950/95 p-6 flex flex-col items-center justify-center text-center space-y-4 z-30">
                    <AlertCircle className="w-12 h-12 text-amber-400" />
                    <p className="text-xs text-slate-200 max-w-xs">{videoError}</p>
                    <div className="flex flex-wrap gap-2 justify-center">
                      <Button
                        size="sm"
                        variant="primary"
                        onClick={handleToggleVideoPlay}
                        className="bg-cyan-500 text-slate-950 font-bold text-xs"
                      >
                        <RefreshCw className="w-3.5 h-3.5 mr-1" /> Qayta urinish
                      </Button>
                      <a
                        href="/videos/bilimyol-pitch-demo.mp4"
                        target="_blank"
                        rel="noreferrer"
                        className="px-3 py-1.5 rounded-xl bg-white/10 hover:bg-white/20 text-xs text-white font-bold inline-flex items-center gap-1"
                      >
                        Alohida ochish ↗
                      </a>
                    </div>
                  </div>
                )}
              </div>

              {/* Direct Playback Action Bar */}
              <div className="w-full max-w-xl mt-4 p-3 rounded-2xl bg-white/5 border border-white/10 flex flex-wrap items-center justify-between gap-3 text-xs">
                <div className="flex items-center gap-2">
                  <button
                    onClick={handleToggleVideoPlay}
                    className="px-4 py-2 rounded-xl bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-black flex items-center gap-1.5 cursor-pointer shadow-md transition-all active:scale-95"
                  >
                    {isVideoPlaying ? (
                      <>
                        <Pause className="w-4 h-4 fill-current" />
                        <span>To‘xtatish</span>
                      </>
                    ) : (
                      <>
                        <Play className="w-4 h-4 fill-current" />
                        <span>▶ Videoni Qo‘yish</span>
                      </>
                    )}
                  </button>

                  <button
                    onClick={() => {
                      if (videoRef.current) {
                        videoRef.current.currentTime = 0;
                        videoRef.current.play().then(() => setIsVideoPlaying(true)).catch(() => {});
                      }
                    }}
                    className="px-3 py-2 rounded-xl bg-white/5 hover:bg-white/10 text-slate-200 font-bold flex items-center gap-1 cursor-pointer transition-colors"
                    title="Boshidan ijro etish"
                  >
                    <RotateCcw className="w-3.5 h-3.5" />
                    <span>Boshiga</span>
                  </button>
                </div>

                <div className="flex items-center gap-2 text-slate-400 text-[11px]">
                  <span className="flex items-center gap-1 text-cyan-300 font-bold">
                    <CheckCircle2 className="w-3.5 h-3.5" />
                    H.264 & WebM HD
                  </span>
                  <span>•</span>
                  <a
                    href="/videos/bilimyol-pitch-demo.mp4"
                    target="_blank"
                    rel="noreferrer"
                    className="hover:text-white underline text-slate-300 font-semibold"
                  >
                    Yangi tabda ochish ↗
                  </a>
                </div>
              </div>
            </div>
          ) : (
            /* 2. Interactive Chapter Simulation Player */
            <div>
              <div className="relative aspect-video max-h-[540px] w-full bg-black flex items-center justify-center overflow-hidden">
                <AnimatePresence mode="wait">
                  {currentChapter.screen === 'course-selection' && (
                    <motion.div
                      key="screen-1"
                      initial={{ opacity: 0, scale: 0.98 }}
                      animate={{ opacity: 1, scale: 1 }}
                      exit={{ opacity: 0, scale: 1.02 }}
                      transition={{ duration: 0.4 }}
                      className="w-full h-full p-8 flex flex-col justify-center items-center bg-gradient-to-br from-indigo-950/70 via-slate-950 to-slate-900 text-center space-y-6"
                    >
                      <div className="w-16 h-16 rounded-2xl bg-cyan-500/20 text-cyan-400 flex items-center justify-center shadow-lg">
                        <BookOpen className="w-8 h-8" />
                      </div>
                      <div className="space-y-2 max-w-lg">
                        <span className="text-xs text-cyan-400 font-bold uppercase tracking-wider">
                          1-Qadam: Fan Tanlash
                        </span>
                        <h3 className="text-2xl sm:text-3xl font-black text-white">
                          Matematika & Ingliz Tili Kurslari
                        </h3>
                        <p className="text-xs text-slate-300">
                          O‘quvchi platformaga kirgach, o‘rganmoqchi bo‘lgan fanini tanlaydi va o‘z maqsadini belgilaydi.
                        </p>
                      </div>
                    </motion.div>
                  )}

                  {currentChapter.screen === 'placement' && (
                    <motion.div
                      key="screen-2"
                      initial={{ opacity: 0, scale: 0.98 }}
                      animate={{ opacity: 1, scale: 1 }}
                      exit={{ opacity: 0, scale: 1.02 }}
                      transition={{ duration: 0.4 }}
                      className="w-full h-full p-8 flex flex-col justify-center items-center bg-gradient-to-br from-purple-950/70 via-slate-950 to-slate-900 text-center space-y-6"
                    >
                      <div className="w-16 h-16 rounded-2xl bg-purple-500/20 text-purple-400 flex items-center justify-center shadow-lg">
                        <Compass className="w-8 h-8" />
                      </div>
                      <div className="space-y-2 max-w-lg">
                        <span className="text-xs text-purple-400 font-bold uppercase tracking-wider">
                          2-Qadam: Adaptiv Diagnostika
                        </span>
                        <h3 className="text-2xl sm:text-3xl font-black text-white">
                          8 Savol orqali Bo‘shliqlarni Aniqlash
                        </h3>
                        <p className="text-xs text-slate-300">
                          Standart test emas, har bir javobga qarab qiyinlik darajasi o‘zgaruvchi aqlli placement test.
                        </p>
                      </div>
                    </motion.div>
                  )}

                  {currentChapter.screen === 'roadmap' && (
                    <motion.div
                      key="screen-3"
                      initial={{ opacity: 0, scale: 0.98 }}
                      animate={{ opacity: 1, scale: 1 }}
                      exit={{ opacity: 0, scale: 1.02 }}
                      transition={{ duration: 0.4 }}
                      className="w-full h-full p-8 flex flex-col justify-center items-center bg-gradient-to-br from-blue-950/70 via-slate-950 to-slate-900 text-center space-y-6"
                    >
                      <div className="w-16 h-16 rounded-2xl bg-blue-500/20 text-blue-400 flex items-center justify-center shadow-lg">
                        <Zap className="w-8 h-8" />
                      </div>
                      <div className="space-y-2 max-w-lg">
                        <span className="text-xs text-blue-400 font-bold uppercase tracking-wider">
                          3-Qadam: Shaxsiy Ta’lim Yo‘li
                        </span>
                        <h3 className="text-2xl sm:text-3xl font-black text-white">
                          0-100% Ko‘nikmalar Xaritasi (Knowledge Map)
                        </h3>
                        <p className="text-xs text-slate-300">
                          O‘quvchining zaif nuqtalari aniqlanib, bosqichma-bosqich o‘zlashtirish yo‘li tuziladi.
                        </p>
                      </div>
                    </motion.div>
                  )}

                  {currentChapter.screen === 'lesson' && (
                    <motion.div
                      key="screen-4"
                      initial={{ opacity: 0, scale: 0.98 }}
                      animate={{ opacity: 1, scale: 1 }}
                      exit={{ opacity: 0, scale: 1.02 }}
                      transition={{ duration: 0.4 }}
                      className="w-full h-full p-8 flex flex-col justify-center items-center bg-gradient-to-br from-cyan-950/70 via-slate-950 to-slate-900 text-center space-y-6"
                    >
                      <YolchiAIMascot size="lg" mood="explaining" />
                      <div className="space-y-2 max-w-lg">
                        <span className="text-xs text-cyan-400 font-bold uppercase tracking-wider">
                          4-Qadam: Interaktiv Dars
                        </span>
                        <h3 className="text-2xl sm:text-3xl font-black text-white">
                          Nazariya, Misol va Amaliy Mashq
                        </h3>
                        <p className="text-xs text-slate-300">
                          Tushuncha beriladi, misollar ko‘rsatiladi va o‘quvchi javob yuborib o‘zlashtirishni tekshiradi.
                        </p>
                      </div>
                    </motion.div>
                  )}

                  {currentChapter.screen === 'scoring' && (
                    <motion.div
                      key="screen-5"
                      initial={{ opacity: 0, scale: 0.98 }}
                      animate={{ opacity: 1, scale: 1 }}
                      exit={{ opacity: 0, scale: 1.02 }}
                      transition={{ duration: 0.4 }}
                      className="w-full h-full p-8 flex flex-col justify-center items-center bg-gradient-to-br from-emerald-950/70 via-slate-950 to-slate-900 text-center space-y-6"
                    >
                      <div className="w-16 h-16 rounded-2xl bg-emerald-500/20 text-emerald-400 flex items-center justify-center shadow-lg">
                        <ShieldCheck className="w-8 h-8" />
                      </div>
                      <div className="space-y-2 max-w-lg">
                        <span className="text-xs text-emerald-400 font-bold uppercase tracking-wider">
                          5-Qadam: Server-Side Scoring & Anti-Cheat
                        </span>
                        <h3 className="text-2xl sm:text-3xl font-black text-white">
                          Serverda Xolis Tekshiruv & +20 XP
                        </h3>
                        <p className="text-xs text-slate-300">
                          Javoblar server RPC orqali xolis tekshiriladi, ballar va XP xavfsiz hisoblanadi.
                        </p>
                      </div>
                    </motion.div>
                  )}

                  {currentChapter.screen === 'ai-tutor' && (
                    <motion.div
                      key="screen-6"
                      initial={{ opacity: 0, scale: 0.98 }}
                      animate={{ opacity: 1, scale: 1 }}
                      exit={{ opacity: 0, scale: 1.02 }}
                      transition={{ duration: 0.4 }}
                      className="w-full h-full p-8 flex flex-col justify-center items-center bg-gradient-to-br from-indigo-950/70 via-slate-950 to-slate-900 text-center space-y-6"
                    >
                      <div className="w-16 h-16 rounded-2xl bg-indigo-500/20 text-indigo-400 flex items-center justify-center shadow-lg">
                        <Bot className="w-8 h-8" />
                      </div>
                      <div className="space-y-2 max-w-lg">
                        <span className="text-xs text-indigo-400 font-bold uppercase tracking-wider">
                          6-Qadam: Yo‘lchi AI Mentori
                        </span>
                        <h3 className="text-2xl sm:text-3xl font-black text-white">
                          Xatolikni Pedagogik Tushuntirish
                        </h3>
                        <p className="text-xs text-slate-300">
                          Gemini 2.5 Flash bilan integratsiyalashgan AI tayyor javobni emas, xatoning tub sababini tushuntiradi.
                        </p>
                      </div>
                    </motion.div>
                  )}

                  {currentChapter.screen === 'onboarding' && (
                    <motion.div
                      key="screen-onboarding"
                      initial={{ opacity: 0, scale: 0.98 }}
                      animate={{ opacity: 1, scale: 1 }}
                      exit={{ opacity: 0, scale: 1.02 }}
                      transition={{ duration: 0.4 }}
                      className="w-full h-full p-8 flex flex-col justify-center items-center bg-gradient-to-br from-indigo-950/70 via-slate-950 to-slate-900 text-center space-y-6"
                    >
                      <div className="w-16 h-16 rounded-2xl bg-amber-500/20 text-amber-400 flex items-center justify-center shadow-lg">
                        <Compass className="w-8 h-8" />
                      </div>
                      <div className="space-y-2 max-w-lg">
                        <span className="text-xs text-amber-400 font-bold uppercase tracking-wider">
                          2-Qadam: O‘quv Maqsadi
                        </span>
                        <h3 className="text-2xl sm:text-3xl font-black text-white">
                          Sinf va Shaxsiy Maqsadni Tanlash
                        </h3>
                        <p className="text-xs text-slate-300">
                          Maktab dasturi, olimpiada yoki imtihonga tayyorgarlik darajasi tanlanadi.
                        </p>
                      </div>
                    </motion.div>
                  )}

                  {currentChapter.screen === 'knowledge-map' && (
                    <motion.div
                      key="screen-knowledge-map"
                      initial={{ opacity: 0, scale: 0.98 }}
                      animate={{ opacity: 1, scale: 1 }}
                      exit={{ opacity: 0, scale: 1.02 }}
                      transition={{ duration: 0.4 }}
                      className="w-full h-full p-8 flex flex-col justify-center items-center bg-gradient-to-br from-purple-950/70 via-slate-950 to-slate-900 text-center space-y-6"
                    >
                      <div className="w-16 h-16 rounded-2xl bg-purple-500/20 text-purple-400 flex items-center justify-center shadow-lg">
                        <Zap className="w-8 h-8" />
                      </div>
                      <div className="space-y-2 max-w-lg">
                        <span className="text-xs text-purple-400 font-bold uppercase tracking-wider">
                          4-Qadam: Ko‘nikmalar Xaritasi
                        </span>
                        <h3 className="text-2xl sm:text-3xl font-black text-white">
                          0-100% Bilim Matritsasi (Knowledge Map)
                        </h3>
                        <p className="text-xs text-slate-300">
                          Har bir mavzuning o‘zlashtirish foizi va zaif/kuchli nuqtalar aniq tahlil qilinadi.
                        </p>
                      </div>
                    </motion.div>
                  )}

                  {currentChapter.screen === 'dashboard' && (
                    <motion.div
                      key="screen-7"
                      initial={{ opacity: 0, scale: 0.98 }}
                      animate={{ opacity: 1, scale: 1 }}
                      exit={{ opacity: 0, scale: 1.02 }}
                      transition={{ duration: 0.4 }}
                      className="w-full h-full p-8 flex flex-col justify-center items-center bg-gradient-to-br from-emerald-950/70 via-slate-950 to-slate-900 text-center space-y-6"
                    >
                      <div className="w-16 h-16 rounded-2xl bg-emerald-500/20 text-emerald-400 flex items-center justify-center shadow-lg">
                        <TrendingUp className="w-8 h-8" />
                      </div>
                      <div className="space-y-2 max-w-lg">
                        <span className="text-xs text-emerald-400 font-bold uppercase tracking-wider">
                          10-Qadam: O‘quvchi Dashboardi
                        </span>
                        <h3 className="text-2xl sm:text-3xl font-black text-white">
                          Bilim O‘sishi, Streak va Natijalar
                        </h3>
                        <p className="text-xs text-slate-300">
                          Har bir darsdan so‘ng bilim darajasi real vaqtda yangilanadi va ota-onalar nazorat qila oladi.
                        </p>
                      </div>
                    </motion.div>
                  )}

                  {currentChapter.screen === 'pitch' && (
                    <motion.div
                      key="screen-pitch"
                      initial={{ opacity: 0, scale: 0.98 }}
                      animate={{ opacity: 1, scale: 1 }}
                      exit={{ opacity: 0, scale: 1.02 }}
                      transition={{ duration: 0.4 }}
                      className="w-full h-full p-8 flex flex-col justify-center items-center bg-gradient-to-br from-indigo-950/70 via-slate-950 to-slate-900 text-center space-y-6"
                    >
                      <div className="w-16 h-16 rounded-2xl bg-cyan-500/20 text-cyan-400 flex items-center justify-center shadow-lg">
                        <Sparkles className="w-8 h-8 text-amber-300" />
                      </div>
                      <div className="space-y-2 max-w-lg">
                        <span className="text-xs text-cyan-400 font-bold uppercase tracking-wider">
                          11-Qadam: Xulosa
                        </span>
                        <h3 className="text-2xl sm:text-3xl font-black text-white">
                          BilimYo‘l — Darslik emas, shaxsiy ta’lim yo‘li
                        </h3>
                        <p className="text-xs text-slate-300">
                          Pitch Day 3.0 uchun tayyorlangan milliy sun’iy intellekt ta’lim platformasi.
                        </p>
                      </div>
                    </motion.div>
                  )}
                </AnimatePresence>

                {/* Floating Chapter Badge */}
                <div className="absolute top-4 right-4 px-3 py-1 rounded-full bg-black/60 border border-white/10 text-cyan-400 text-[11px] font-bold">
                  {currentChapter.highlightBadge}
                </div>
              </div>

              {/* Scrubber Controls */}
              <div className="p-4 bg-slate-950/90 border-t border-white/10 space-y-3">
                <div className="space-y-1">
                  <div
                    className="w-full h-2.5 bg-white/10 hover:h-3.5 rounded-full cursor-pointer relative transition-all"
                    onClick={(e) => {
                      const rect = e.currentTarget.getBoundingClientRect();
                      const clickX = e.clientX - rect.left;
                      const ratio = clickX / rect.width;
                      setCurrentSeconds(Math.floor(ratio * TOTAL_DURATION_SECONDS));
                    }}
                  >
                    <div
                      className="h-full bg-gradient-to-r from-cyan-500 to-indigo-500 rounded-full relative"
                      style={{ width: `${(currentSeconds / TOTAL_DURATION_SECONDS) * 100}%` }}
                    >
                      <span className="absolute right-0 top-1/2 -translate-y-1/2 w-3.5 h-3.5 rounded-full bg-white shadow-md" />
                    </div>
                  </div>

                  <div className="flex justify-between text-[11px] text-slate-400 font-mono">
                    <span>{formatTime(currentSeconds)}</span>
                    <span className="text-slate-300 font-bold">{currentChapter.title}</span>
                    <span>{formatTime(TOTAL_DURATION_SECONDS)}</span>
                  </div>
                </div>

                <div className="flex items-center justify-between pt-1">
                  <div className="flex items-center gap-3">
                    <button
                      onClick={() => setIsPlaying(!isPlaying)}
                      className="p-2.5 rounded-xl bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-bold transition-all cursor-pointer"
                    >
                      {isPlaying ? <Pause className="w-4 h-4 fill-current" /> : <Play className="w-4 h-4 fill-current" />}
                    </button>

                    <button
                      onClick={() => {
                        setCurrentSeconds(0);
                        setActiveChapterIndex(0);
                        setIsPlaying(true);
                      }}
                      className="p-2.5 rounded-xl bg-white/5 hover:bg-white/10 text-slate-300 transition-colors cursor-pointer"
                      title="Qayta boshlash"
                    >
                      <RotateCcw className="w-4 h-4" />
                    </button>

                    <button
                      onClick={() => setIsMuted(!isMuted)}
                      className="p-2.5 rounded-xl bg-white/5 hover:bg-white/10 text-slate-300 transition-colors cursor-pointer"
                    >
                      {isMuted ? <VolumeX className="w-4 h-4" /> : <Volume2 className="w-4 h-4" />}
                    </button>
                  </div>

                  <Button
                    variant="primary"
                    size="sm"
                    onClick={onNavigateCourses}
                    className="bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-extrabold text-xs px-4 py-2 rounded-xl cursor-pointer"
                  >
                    ⚡ Bu Qadamni Jonli Sinash
                  </Button>
                </div>
              </div>
            </div>
          )}
        </div>

        {/* CHAPTERS NAVIGATION CARDS */}
        <div className="space-y-3">
          <div className="text-xs font-bold text-slate-400 uppercase tracking-wider">
            Video Bo‘limlari va Vaqt Belgilari (Timeline)
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 xl:grid-cols-7 gap-2.5">
            {DEMO_CHAPTERS.map((ch, idx) => (
              <button
                key={idx}
                onClick={() => handleJumpToChapter(idx)}
                className={`p-3 rounded-2xl text-left border transition-all cursor-pointer flex flex-col justify-between ${
                  activeChapterIndex === idx
                    ? 'bg-cyan-950/40 border-cyan-500/60 shadow-lg shadow-cyan-950/30'
                    : 'bg-white/[0.02] border-white/10 hover:bg-white/5 text-slate-400'
                }`}
              >
                <div>
                  <span className="text-[10px] text-cyan-400 font-bold block">{ch.timestamp}</span>
                  <h4 className="text-xs font-bold text-white mt-1 leading-tight">{ch.title}</h4>
                </div>
                <span className="text-[10px] text-slate-400 mt-2 block font-medium">
                  {activeChapterIndex === idx ? '▶ Faol' : 'Ko‘rish →'}
                </span>
              </button>
            ))}
          </div>
        </div>

        {/* 6.2. DEMO-VIDEONING BATAFSIL TAVSIFI */}
        <section className="p-8 sm:p-10 rounded-3xl bg-white/[0.03] border border-white/10 backdrop-blur-md space-y-6">
          <div className="border-b border-white/10 pb-4">
            <span className="text-cyan-400 text-xs font-black tracking-widest uppercase">6.2-TALAB: TAVSIF</span>
            <h2 className="text-2xl sm:text-3xl font-extrabold text-white mt-1">
              Demo-videoning Pedagogik va Texnologik Tavsifi
            </h2>
          </div>

          <div className="space-y-4 text-slate-300 text-sm sm:text-base leading-relaxed">
            <p>
              Ushbu demo-video <strong>BilimYo‘l Smart Edu</strong> platformasining haqiqiy arxitekturasi va o‘quvchi ta’lim traektoriyasini boshidan oxirigacha yaqqol namoyish etadi:
            </p>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6 pt-2">
              <div className="p-5 rounded-2xl bg-black/40 border border-white/5 space-y-2">
                <h3 className="font-bold text-cyan-400 flex items-center gap-2">
                  <Compass className="w-4 h-4" /> 1. Adaptiv Bo‘shliqni Aniqlash (00:00 - 00:55)
                </h3>
                <p className="text-xs text-slate-300 leading-relaxed">
                  O‘quvchi fanni tanlaydi (Matematika yoki Ingliz tili). 8 ta adaptiv savoldan iborat placement test o‘quvchining xatolarini o‘rganib, uning qaysi formulalarda oqsayotganini (masalan, Funksiyalar 38%) aniq bilim xaritasiga tushiradi.
                </p>
              </div>

              <div className="p-5 rounded-2xl bg-black/40 border border-white/5 space-y-2">
                <h3 className="font-bold text-indigo-400 flex items-center gap-2">
                  <Zap className="w-4 h-4" /> 2. Shaxsiy Ta’lim Yo‘li & Dars (00:55 - 01:55)
                </h3>
                <p className="text-xs text-slate-300 leading-relaxed">
                  O‘quvchiga standart kitobdagi barcha mavzular emas, aynan uning bo‘shlig‘iga mos qadamli yo‘l ochiladi. Dars nazariya, vizual modellar va amaliy mashqlar orqali bosqichma-bosqich o‘zlashtiriladi.
                </p>
              </div>

              <div className="p-5 rounded-2xl bg-black/40 border border-white/5 space-y-2">
                <h3 className="font-bold text-emerald-400 flex items-center gap-2">
                  <ShieldCheck className="w-4 h-4" /> 3. Server-Side Scoring & Anti-Cheat (01:55 - 02:25)
                </h3>
                <p className="text-xs text-slate-300 leading-relaxed">
                  O‘quvchi brauzer konsoli orqali javoblarni ko‘ra olmaydi yoki XP ni soxtalashtira olmaydi. PostgreSQL RPC funksiyasi serverda javobni xolis tekshirib, xavfsiz ball beradi.
                </p>
              </div>

              <div className="p-5 rounded-2xl bg-black/40 border border-white/5 space-y-2">
                <h3 className="font-bold text-purple-400 flex items-center gap-2">
                  <Bot className="w-4 h-4" /> 4. Yo‘lchi AI & Natijalar (02:25 - 03:30)
                </h3>
                <p className="text-xs text-slate-300 leading-relaxed">
                  Supabase Edge Function orqali Google Gemini 2.5 Flash mentori xatolikning asl sababini pedagogik uslubda tushuntiradi. O‘quvchi paneli bilim darajasi o‘sganini real vaqtda aks ettiradi.
                </p>
              </div>
            </div>
          </div>
        </section>

        {/* 6.3. ISHLAYOTGAN PROTOTIP HAVOLALARI */}
        <section className="p-8 sm:p-12 rounded-3xl bg-gradient-to-r from-cyan-950/40 via-blue-950/40 to-indigo-950/40 border-2 border-cyan-500/40 text-center space-y-6">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-cyan-400 text-slate-950 text-xs font-black">
            <CheckCircle2 className="w-3.5 h-3.5" />
            6.3-TALAB: ISHLAYOTGAN PROTOTIP HAVOLASI
          </div>

          <h2 className="text-3xl sm:text-4xl font-extrabold text-white">
            Hozirning O‘zida Jonli Prototipni Sinab Ko‘ring
          </h2>

          <p className="text-slate-300 text-sm sm:text-base max-w-2xl mx-auto">
            Hakamlar va investorlar to‘g‘ridan-to‘g‘ri brauzerda yoki mobil ilova orqali real ta’lim jarayonini o‘z ko‘zlari bilan sinab ko‘rishlari mumkin:
          </p>

          <div className="flex flex-wrap items-center justify-center gap-4 pt-2">
            <Button
              variant="primary"
              size="md"
              onClick={onNavigateCourses}
              className="bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-black px-8 py-3.5 rounded-2xl shadow-xl shadow-cyan-500/25 flex items-center gap-3 cursor-pointer text-sm"
            >
              <Zap className="w-4 h-4 fill-current" />
              1. Fanni Tanlash va Diagnostika (/courses)
            </Button>

            <Button
              variant="outline"
              size="md"
              onClick={onNavigateDashboard}
              className="bg-white/5 hover:bg-white/10 border-white/20 text-white font-bold px-8 py-3.5 rounded-2xl flex items-center gap-3 cursor-pointer text-sm backdrop-blur-md"
            >
              <TrendingUp className="w-4 h-4 text-emerald-400" />
              2. O‘quvchi Dashboardini Ko‘rish (/dashboard)
            </Button>

            <Button
              variant="outline"
              size="md"
              onClick={onNavigateAiTutor}
              className="bg-white/5 hover:bg-white/10 border-white/20 text-white font-bold px-8 py-3.5 rounded-2xl flex items-center gap-3 cursor-pointer text-sm backdrop-blur-md"
            >
              <Bot className="w-4 h-4 text-indigo-400" />
              3. Yo‘lchi AI Chatini Sinash (/ai-tutor)
            </Button>

            <a
              href="https://github.com/pirimovuktam/bilimyol-smart-edu"
              target="_blank"
              rel="noreferrer"
              className="px-6 py-3.5 rounded-2xl bg-white/5 hover:bg-white/10 border border-white/20 text-slate-300 hover:text-white font-bold flex items-center gap-2 text-sm transition-colors"
            >
              <ExternalLink className="w-4 h-4" />
              GitHub Repozitoriyasi (Open Source)
            </a>
          </div>
        </section>
      </div>
    </div>
  );
};
