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
    title: '1. Kiriş va Platforma Missiyasi',
    timestamp: '00:00 - 00:11',
    secondsStart: 0,
    description: 'BilimYöl Smart Edu — bir xil darslik emas, har bir öquvçiga mos şaxsiy ta’lim yölidir.',
    screen: 'pitch',
    highlightBadge: 'Platforma Missiyasi',
  },
  {
    title: '2. Fan Tanlaş va Kurslar',
    timestamp: '00:11 - 00:21',
    secondsStart: 11,
    description: 'Matematika va Ingliz tili fanlari töliq integratsiya qilingan, har biri mustaqil ta’lim traektoriyasiga ega.',
    screen: 'course-selection',
    highlightBadge: 'Fan Tanlaş',
  },
  {
    title: '3. Şaxsiy Maqsadni Belgilaş',
    timestamp: '00:21 - 00:32',
    secondsStart: 21,
    description: 'Öquvçi öz sinfi va maqsadini tanlaydi: maktab dasturi, olimpiada yoki imtihonga tayyorgarlik.',
    screen: 'onboarding',
    highlightBadge: 'Onboarding & Profil',
  },
  {
    title: '4. Adaptiv Diagnostika Testi',
    timestamp: '00:32 - 00:43',
    secondsStart: 32,
    description: '8 ta aqlli diagnostika savoli orqali bilimdagi böşliqlar xolis skanerlanadi va boşlanğiç daraja aniqlanadi.',
    screen: 'placement',
    highlightBadge: 'Placement Test',
  },
  {
    title: '5. Könikmalar Xaritasi (Knowledge Map)',
    timestamp: '00:43 - 00:56',
    secondsStart: 43,
    description: 'Öquvçining barça mavzular böyiça könikmalari 0% dan 100% gaça interaktiv grafik matritsada namoyon böladi.',
    screen: 'knowledge-map',
    highlightBadge: 'Bilim Xaritasi',
  },
  {
    title: '6. Şaxsiy Öquv Yöli (Roadmap)',
    timestamp: '00:56 - 01:08',
    secondsStart: 56,
    description: 'Standart kitob ketma-ketligi emas, aynan şu öquvçi örganişi zarur bölgan darslar qadamma-qadam oçiladi.',
    screen: 'roadmap',
    highlightBadge: 'Adaptiv Yöl',
  },
  {
    title: '7. Interaktiv Nazariya va Tuşunça',
    timestamp: '01:08 - 01:18',
    secondsStart: 68,
    description: 'Boy nazariya, LaTeX formulalar va vizual tuşuntirişlar bilan qoidaning mohiyati anglatiladi.',
    screen: 'lesson',
    highlightBadge: 'Nazariya & Formula',
  },
  {
    title: '8. Amaliyot va Server-Side Scoring',
    timestamp: '01:18 - 01:30',
    secondsStart: 78,
    description: 'Javoblar PostgreSQL RPC orqali serverda xavfsiz tekşiriladi, anti-cheat ball soxtalaştirişni tösadi.',
    screen: 'lesson',
    highlightBadge: 'Amaliyot & Scoring',
  },
  {
    title: '9. Yölçi AI Pedagogik Mentori',
    timestamp: '01:30 - 01:42',
    secondsStart: 90,
    description: 'Xato bölganda Yölçi AI tayyor javobni bermasdan, tuşunişga yordam beradi va mustahkamlovçi maşq beradi.',
    screen: 'ai-tutor',
    highlightBadge: 'Yölçi AI & Gemini',
  },
  {
    title: '10. Öquvçi Daşboardi va Doimiy Rivojlaniş',
    timestamp: '01:42 - 01:53',
    secondsStart: 102,
    description: 'Boş sahifada kunlik darslar, töplangan XP, streak va özlaştiriş foizining yaxlit körinişi.',
    screen: 'dashboard',
    highlightBadge: 'Dashboard',
  },
  {
    title: '11. Özlaştiriş dinamikasi',
    timestamp: '01:53 - 02:03',
    secondsStart: 113,
    description: 'Öquvçi natijalari real vaqtda yangilanadi va şaxsiy rivojlaniş dinamikasida aks etadi.',
    screen: 'dashboard',
    highlightBadge: 'Progress',
  },
  {
    title: '12. Yakun (Pitch Day 3.0)',
    timestamp: '02:03 - 02:13',
    secondsStart: 123,
    description: 'BilimYöl Smart Edu: Darslik emas — şaxsiy ta’lim yöli. Har bir öquvçiga öz imkoniyatlarini oçiş uçun işonçli zanjir.',
    screen: 'pitch',
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
              setVideoError("Videoni ijro etişda xatolik yuz berdi. Iltimos quyidagi 'Alohida oynada oçiş' havolasidan foydalaning.");
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
    <div className="min-h-screen bg-slate-50 text-slate-900 selection:bg-path selection:text-white">
      {/* Background Decorative Mesh Gradients */}
      <div className="fixed inset-0 pointer-events-none overflow-hidden z-0">
        <div className="absolute -top-40 -left-40 w-96 h-96 bg-brand/50 rounded-full blur-[140px]" />
        <div className="absolute top-1/3 -right-40 w-[500px] h-[500px] bg-path/40 rounded-full blur-[160px]" />
        <div className="absolute bottom-10 left-1/4 w-[450px] h-[450px] bg-mint/30 rounded-full blur-[150px]" />
      </div>

      <div className="relative z-10 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-12">
        {/* TOP BAR */}
        <div className="flex flex-wrap items-center justify-between gap-4 pb-6 border-b border-slate-200">
          <div className="flex items-center gap-3">
            <BilimYolLogo size="md" />
            <span className="text-slate-400">/</span>
            <span className="text-xs font-black uppercase tracking-wider text-path bg-path/10 border border-path/25 px-2.5 py-1 rounded-xl">
              Demo Showcase (/demo)
            </span>
          </div>

          <div className="flex items-center gap-3">
            <button
              onClick={onNavigatePitch}
              className="text-xs font-bold text-slate-600 hover:text-slate-900 transition-colors cursor-pointer"
            >
              ← Pitch Day 3.0 Taqdimotiga Qaytiş
            </button>
            <Button
              variant="primary"
              size="sm"
              onClick={onNavigateCourses}
              className="bg-path hover:bg-path text-white font-black text-xs px-4 py-2 rounded-xl cursor-pointer shadow-sm"
            >
              Jonli Prototipni Oçiş <ArrowRight className="w-3.5 h-3.5" />
            </Button>
          </div>
        </div>

        {/* DEMO HERO HEADER */}
        <div className="text-center max-w-3xl mx-auto space-y-4">
          <div className="inline-flex items-center gap-2 px-3.5 py-1 rounded-full bg-brand/8 border border-brand/25 text-brand-dark text-xs font-bold">
            <Sparkles className="w-3.5 h-3.5 text-amber-500" />
            <span>Pitch Day 3.0 — 6-Talab: /demo Sahifasi</span>
          </div>

          <h1 className="text-3xl sm:text-5xl font-black text-slate-900 tracking-tight">
            BilimYöl Smart Edu Demo Videosi
          </h1>

          <p className="text-sm sm:text-base text-slate-600 leading-relaxed">
            Haqiqiy işlayotgan ilovadan 9:16 telefon ekranida yozib olingan 2 daqiqa 13 soniyalik professional ovozli video: diagnostikadan tortib to Yölçi AI orqali darsni mustahkamlaşgaça.
          </p>

          {/* Mode Switcher Tabs */}
          <div className="inline-flex p-1 rounded-2xl bg-slate-200/80 border border-slate-300">
            <button
              onClick={() => setPlayerMode('video')}
              className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                playerMode === 'video'
                  ? 'bg-path text-white shadow-md font-black'
                  : 'text-slate-700 hover:text-slate-900'
              }`}
            >
              <Video className="w-3.5 h-3.5" />
              <span>1. Haqiqiy MP4 Video Pleer (9:16 Ovozli)</span>
            </button>
            <button
              onClick={() => setPlayerMode('simulation')}
              className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                playerMode === 'simulation'
                  ? 'bg-brand text-white shadow-md font-black'
                  : 'text-slate-700 hover:text-slate-900'
              }`}
            >
              <Smartphone className="w-3.5 h-3.5" />
              <span>2. Interaktiv Qadamlar Simulyatori</span>
            </button>
          </div>
        </div>

        {/* 6.1. DEMO-VIDEO PLAYER CONTAINER */}
        <div className="rounded-3xl bg-white border border-slate-200 shadow-xl overflow-hidden">
          {/* Top Video Header Bar */}
          <div className="p-4 bg-slate-100/90 border-b border-slate-200 flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="flex gap-1.5">
                <span className="w-3 h-3 rounded-full bg-coral inline-block" />
                <span className="w-3 h-3 rounded-full bg-amber-500 inline-block" />
                <span className="w-3 h-3 rounded-full bg-mint inline-block" />
              </div>
              <span className="text-xs font-bold text-slate-800">
                BilimYöl Smart Edu — Haqiqiy Mahsulot Ekran Yozuvi (1080p Desktop • Özbekça Ovoz)
              </span>
            </div>

            <div className="flex items-center gap-2">
              <span className="px-2 py-0.5 rounded bg-path/15 text-path text-[10px] font-black border border-path/25">
                1920×1080 Full HD (16:9)
              </span>
              <a
                href="/videos/bilimyol-pitch-demo.mp4"
                download="bilimyol-pitch-demo.mp4"
                className="px-2.5 py-1 rounded bg-white hover:bg-slate-50 text-slate-700 border border-slate-200 text-[11px] font-bold flex items-center gap-1 transition-colors shadow-sm"
                title="Videoni yuklab oliş"
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
              <div className="w-full max-w-4xl rounded-2xl overflow-hidden shadow-2xl border-2 border-path/30 bg-black aspect-video relative group">
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
                    setVideoError('Video formatini avtomatik yuklaşda cheklov yuz berdi. Quyidagi havolalar orqali töğridan-töğri oçing.');
                  }}
                >
                  <source src="/videos/bilimyol-pitch-demo.mp4" type="video/mp4" />
                  <source src="/videos/bilimyol-pitch-demo.webm" type="video/webm" />
                  Sizning brauzeringiz HTML5 videoni qöllab-quvvatlamaydi.
                </video>

                {/* Big Center Play Overlay Button when paused */}
                {!isVideoPlaying && !videoError && (
                  <button
                    onClick={handleToggleVideoPlay}
                    className="absolute inset-0 m-auto w-20 h-20 rounded-full bg-path/95 hover:bg-path text-slate-950 flex items-center justify-center shadow-2xl shadow-path/50 transition-all hover:scale-110 cursor-pointer z-20 backdrop-blur-sm"
                    title="Videoni qöyiş"
                    aria-label="Videoni ijro etiş"
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
                        className="bg-path text-slate-950 font-bold text-xs"
                      >
                        <RefreshCw className="w-3.5 h-3.5 mr-1" /> Qayta uriniş
                      </Button>
                      <a
                        href="/videos/bilimyol-pitch-demo.mp4"
                        target="_blank"
                        rel="noreferrer"
                        className="px-3 py-1.5 rounded-xl bg-white/10 hover:bg-white/20 text-xs text-white font-bold inline-flex items-center gap-1"
                      >
                        Alohida oçiş ↗
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
                    className="px-4 py-2 rounded-xl bg-path hover:bg-path text-slate-950 font-black flex items-center gap-1.5 cursor-pointer shadow-md transition-all active:scale-95"
                  >
                    {isVideoPlaying ? (
                      <>
                        <Pause className="w-4 h-4 fill-current" />
                        <span>Töxtatiş</span>
                      </>
                    ) : (
                      <>
                        <Play className="w-4 h-4 fill-current" />
                        <span>▶ Videoni Qöyiş</span>
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
                    title="Boşidan ijro etiş"
                  >
                    <RotateCcw className="w-3.5 h-3.5" />
                    <span>Boşiga</span>
                  </button>
                </div>

                <div className="flex items-center gap-2 text-slate-400 text-[11px]">
                  <span className="flex items-center gap-1 text-path font-bold">
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
                    Yangi tabda oçiş ↗
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
                      className="w-full h-full p-8 flex flex-col justify-center items-center bg-gradient-to-br from-ink/70 via-slate-950 to-slate-900 text-center space-y-6"
                    >
                      <div className="w-16 h-16 rounded-2xl bg-path/20 text-path flex items-center justify-center shadow-lg">
                        <BookOpen className="w-8 h-8" />
                      </div>
                      <div className="space-y-2 max-w-lg">
                        <span className="text-xs text-path font-bold uppercase tracking-wider">
                          1-Qadam: Fan Tanlaş
                        </span>
                        <h3 className="text-2xl sm:text-3xl font-black text-white">
                          Matematika & Ingliz Tili Kurslari
                        </h3>
                        <p className="text-xs text-slate-300">
                          Öquvçi platformaga kirgaç, örganmoqçi bölgan fanini tanlaydi va öz maqsadini belgilaydi.
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
                      className="w-full h-full p-8 flex flex-col justify-center items-center bg-gradient-to-br from-ink/70 via-slate-950 to-slate-900 text-center space-y-6"
                    >
                      <div className="w-16 h-16 rounded-2xl bg-brand/20 text-path flex items-center justify-center shadow-lg">
                        <Compass className="w-8 h-8" />
                      </div>
                      <div className="space-y-2 max-w-lg">
                        <span className="text-xs text-path font-bold uppercase tracking-wider">
                          2-Qadam: Adaptiv Diagnostika
                        </span>
                        <h3 className="text-2xl sm:text-3xl font-black text-white">
                          8 Savol orqali Böşliqlarni Aniqlaş
                        </h3>
                        <p className="text-xs text-slate-300">
                          Standart test emas, har bir javobga qarab qiyinlik darajasi özgaruvçi aqlli placement test.
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
                      className="w-full h-full p-8 flex flex-col justify-center items-center bg-gradient-to-br from-ink/70 via-slate-950 to-slate-900 text-center space-y-6"
                    >
                      <div className="w-16 h-16 rounded-2xl bg-brand/20 text-path flex items-center justify-center shadow-lg">
                        <Zap className="w-8 h-8" />
                      </div>
                      <div className="space-y-2 max-w-lg">
                        <span className="text-xs text-path font-bold uppercase tracking-wider">
                          3-Qadam: Şaxsiy Ta’lim Yöli
                        </span>
                        <h3 className="text-2xl sm:text-3xl font-black text-white">
                          0-100% Könikmalar Xaritasi (Knowledge Map)
                        </h3>
                        <p className="text-xs text-slate-300">
                          Öquvçining zaif nuqtalari aniqlanib, bosqiçma-bosqiç özlaştiriş yöli tuziladi.
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
                      className="w-full h-full p-8 flex flex-col justify-center items-center bg-gradient-to-br from-path/70 via-slate-950 to-slate-900 text-center space-y-6"
                    >
                      <YolchiAIMascot size="lg" mood="explaining" />
                      <div className="space-y-2 max-w-lg">
                        <span className="text-xs text-path font-bold uppercase tracking-wider">
                          4-Qadam: Interaktiv Dars
                        </span>
                        <h3 className="text-2xl sm:text-3xl font-black text-white">
                          Nazariya, Misol va Amaliy Maşq
                        </h3>
                        <p className="text-xs text-slate-300">
                          Tuşunça beriladi, misollar körsatiladi va öquvçi javob yuborib özlaştirişni tekşiradi.
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
                      className="w-full h-full p-8 flex flex-col justify-center items-center bg-gradient-to-br from-mint/70 via-slate-950 to-slate-900 text-center space-y-6"
                    >
                      <div className="w-16 h-16 rounded-2xl bg-mint/20 text-mint flex items-center justify-center shadow-lg">
                        <ShieldCheck className="w-8 h-8" />
                      </div>
                      <div className="space-y-2 max-w-lg">
                        <span className="text-xs text-mint font-bold uppercase tracking-wider">
                          5-Qadam: Server-Side Scoring & Anti-Cheat
                        </span>
                        <h3 className="text-2xl sm:text-3xl font-black text-white">
                          Serverda Xolis Tekşiruv & +20 XP
                        </h3>
                        <p className="text-xs text-slate-300">
                          Javoblar server RPC orqali xolis tekşiriladi, ballar va XP xavfsiz hisoblanadi.
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
                      className="w-full h-full p-8 flex flex-col justify-center items-center bg-gradient-to-br from-ink/70 via-slate-950 to-slate-900 text-center space-y-6"
                    >
                      <div className="w-16 h-16 rounded-2xl bg-brand/20 text-path flex items-center justify-center shadow-lg">
                        <Bot className="w-8 h-8" />
                      </div>
                      <div className="space-y-2 max-w-lg">
                        <span className="text-xs text-path font-bold uppercase tracking-wider">
                          6-Qadam: Yölçi AI Mentori
                        </span>
                        <h3 className="text-2xl sm:text-3xl font-black text-white">
                          Xatolikni Pedagogik Tuşuntiriş
                        </h3>
                        <p className="text-xs text-slate-300">
                          Gemini 2.5 Flash bilan integratsiyalaşgan AI tayyor javobni emas, xatoning tub sababini tuşuntiradi.
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
                      className="w-full h-full p-8 flex flex-col justify-center items-center bg-gradient-to-br from-ink/70 via-slate-950 to-slate-900 text-center space-y-6"
                    >
                      <div className="w-16 h-16 rounded-2xl bg-amber-500/20 text-amber-400 flex items-center justify-center shadow-lg">
                        <Compass className="w-8 h-8" />
                      </div>
                      <div className="space-y-2 max-w-lg">
                        <span className="text-xs text-amber-400 font-bold uppercase tracking-wider">
                          2-Qadam: Öquv Maqsadi
                        </span>
                        <h3 className="text-2xl sm:text-3xl font-black text-white">
                          Sinf va Şaxsiy Maqsadni Tanlaş
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
                      className="w-full h-full p-8 flex flex-col justify-center items-center bg-gradient-to-br from-ink/70 via-slate-950 to-slate-900 text-center space-y-6"
                    >
                      <div className="w-16 h-16 rounded-2xl bg-brand/20 text-path flex items-center justify-center shadow-lg">
                        <Zap className="w-8 h-8" />
                      </div>
                      <div className="space-y-2 max-w-lg">
                        <span className="text-xs text-path font-bold uppercase tracking-wider">
                          4-Qadam: Könikmalar Xaritasi
                        </span>
                        <h3 className="text-2xl sm:text-3xl font-black text-white">
                          0-100% Bilim Matritsasi (Knowledge Map)
                        </h3>
                        <p className="text-xs text-slate-300">
                          Har bir mavzuning özlaştiriş foizi va zaif/kuchli nuqtalar aniq tahlil qilinadi.
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
                      className="w-full h-full p-8 flex flex-col justify-center items-center bg-gradient-to-br from-mint/70 via-slate-950 to-slate-900 text-center space-y-6"
                    >
                      <div className="w-16 h-16 rounded-2xl bg-mint/20 text-mint flex items-center justify-center shadow-lg">
                        <TrendingUp className="w-8 h-8" />
                      </div>
                      <div className="space-y-2 max-w-lg">
                        <span className="text-xs text-mint font-bold uppercase tracking-wider">
                          10-Qadam: Öquvçi Daşboardi
                        </span>
                        <h3 className="text-2xl sm:text-3xl font-black text-white">
                          Bilim Ösişi, Streak va Natijalar
                        </h3>
                        <p className="text-xs text-slate-300">
                          Har bir darsdan söng öquvçining bilim darajasi real vaqtda yangilanadi.
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
                      className="w-full h-full p-8 flex flex-col justify-center items-center bg-gradient-to-br from-ink/70 via-slate-950 to-slate-900 text-center space-y-6"
                    >
                      <div className="w-16 h-16 rounded-2xl bg-path/20 text-path flex items-center justify-center shadow-lg">
                        <Sparkles className="w-8 h-8 text-amber-300" />
                      </div>
                      <div className="space-y-2 max-w-lg">
                        <span className="text-xs text-path font-bold uppercase tracking-wider">
                          11-Qadam: Xulosa
                        </span>
                        <h3 className="text-2xl sm:text-3xl font-black text-white">
                          BilimYöl — Darslik emas, şaxsiy ta’lim yöli
                        </h3>
                        <p className="text-xs text-slate-300">
                          Pitch Day 3.0 uçun tayyorlangan milliy sun’iy intellekt ta’lim platformasi.
                        </p>
                      </div>
                    </motion.div>
                  )}
                </AnimatePresence>

                {/* Floating Chapter Badge */}
                <div className="absolute top-4 right-4 px-3 py-1 rounded-full bg-black/60 border border-white/10 text-path text-[11px] font-bold">
                  {currentChapter.highlightBadge}
                </div>
              </div>

              {/* Scrubber Controls */}
              <div className="p-4 bg-slate-50 border-t border-slate-200 space-y-3">
                <div className="space-y-1">
                  <div
                    className="w-full h-2.5 bg-slate-200 hover:h-3.5 rounded-full cursor-pointer relative transition-all"
                    onClick={(e) => {
                      const rect = e.currentTarget.getBoundingClientRect();
                      const clickX = e.clientX - rect.left;
                      const ratio = clickX / rect.width;
                      setCurrentSeconds(Math.floor(ratio * TOTAL_DURATION_SECONDS));
                    }}
                  >
                    <div
                      className="h-full bg-gradient-to-r from-path to-brand rounded-full relative"
                      style={{ width: `${(currentSeconds / TOTAL_DURATION_SECONDS) * 100}%` }}
                    >
                      <span className="absolute right-0 top-1/2 -translate-y-1/2 w-3.5 h-3.5 rounded-full bg-white shadow-md border border-slate-300" />
                    </div>
                  </div>

                  <div className="flex justify-between text-[11px] text-slate-500 font-mono">
                    <span>{formatTime(currentSeconds)}</span>
                    <span className="text-slate-800 font-bold">{currentChapter.title}</span>
                    <span>{formatTime(TOTAL_DURATION_SECONDS)}</span>
                  </div>
                </div>

                <div className="flex items-center justify-between pt-1">
                  <div className="flex items-center gap-3">
                    <button
                      onClick={() => setIsPlaying(!isPlaying)}
                      className="p-2.5 rounded-xl bg-path hover:bg-path text-white font-bold transition-all cursor-pointer shadow-sm"
                    >
                      {isPlaying ? <Pause className="w-4 h-4 fill-current" /> : <Play className="w-4 h-4 fill-current" />}
                    </button>

                    <button
                      onClick={() => {
                        setCurrentSeconds(0);
                        setActiveChapterIndex(0);
                        setIsPlaying(true);
                      }}
                      className="p-2.5 rounded-xl bg-white hover:bg-slate-100 text-slate-700 border border-slate-200 shadow-sm transition-colors cursor-pointer"
                      title="Qayta boşlaş"
                    >
                      <RotateCcw className="w-4 h-4" />
                    </button>

                    <button
                      onClick={() => setIsMuted(!isMuted)}
                      className="p-2.5 rounded-xl bg-white hover:bg-slate-100 text-slate-700 border border-slate-200 shadow-sm transition-colors cursor-pointer"
                    >
                      {isMuted ? <VolumeX className="w-4 h-4" /> : <Volume2 className="w-4 h-4" />}
                    </button>
                  </div>

                  <Button
                    variant="primary"
                    size="sm"
                    onClick={onNavigateCourses}
                    className="bg-path hover:bg-path text-white font-extrabold text-xs px-4 py-2 rounded-xl cursor-pointer shadow-sm"
                  >
                    ⚡ Bu Qadamni Jonli Sinaş
                  </Button>
                </div>
              </div>
            </div>
          )}
        </div>

        {/* CHAPTERS NAVIGATION CARDS */}
        <div className="space-y-3">
          <div className="text-xs font-bold text-slate-500 uppercase tracking-wider">
            Video Bölimlari va Vaqt Belgilari (Timeline)
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 xl:grid-cols-7 gap-2.5">
            {DEMO_CHAPTERS.map((ch, idx) => (
              <button
                key={idx}
                onClick={() => handleJumpToChapter(idx)}
                className={`p-3 rounded-2xl text-left border transition-all cursor-pointer flex flex-col justify-between ${
                  activeChapterIndex === idx
                    ? 'bg-path/10 border-path shadow-sm text-path'
                    : 'bg-white border-slate-200 hover:bg-slate-50 text-slate-700 shadow-sm'
                }`}
              >
                <div>
                  <span className="text-[10px] text-path font-bold block">{ch.timestamp}</span>
                  <h4 className="text-xs font-bold text-slate-900 mt-1 leading-tight">{ch.title}</h4>
                </div>
                <span className="text-[10px] text-slate-500 mt-2 block font-medium">
                  {activeChapterIndex === idx ? '▶ Faol' : 'Köriş →'}
                </span>
              </button>
            ))}
          </div>
        </div>

        {/* 6.2. DEMO-VIDEONING BATAFSIL TAVSIFI */}
        <section className="p-8 sm:p-10 rounded-3xl bg-white border border-slate-200 shadow-sm space-y-6">
          <div className="border-b border-slate-200 pb-4">
            <span className="text-path bg-path/10 border border-path/25 px-3 py-1 rounded-full text-xs font-black tracking-widest uppercase">
              6.2-TALAB: TAVSIF
            </span>
            <h2 className="text-2xl sm:text-3xl font-extrabold text-slate-900 mt-2">
              Demo-videoning Pedagogik va Texnologik Tavsifi
            </h2>
          </div>

          <div className="space-y-4 text-slate-700 text-sm sm:text-base leading-relaxed">
            <p>
              Uşbu demo-video <strong>BilimYöl Smart Edu</strong> platformasining haqiqiy arxitekturasi va öquvçi ta’lim traektoriyasini boşidan oxirigaça yaqqol namoyiş etadi:
            </p>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6 pt-2">
              <div className="p-5 rounded-2xl bg-slate-50 border border-slate-200 space-y-2">
                <h3 className="font-bold text-path flex items-center gap-2">
                  <Compass className="w-4 h-4 text-path" /> 1. Adaptiv Böşliqni Aniqlaş (00:00 - 00:55)
                </h3>
                <p className="text-xs text-slate-600 leading-relaxed">
                  Öquvçi fanni tanlaydi (Matematika yoki Ingliz tili). 8 ta adaptiv savoldan iborat placement test öquvçining xatolarini örganib, uning qaysi formulalarda oqsayotganini (masalan, Funksiyalar 38%) aniq bilim xaritasiga tuşiradi.
                </p>
              </div>

              <div className="p-5 rounded-2xl bg-slate-50 border border-slate-200 space-y-2">
                <h3 className="font-bold text-brand-dark flex items-center gap-2">
                  <Zap className="w-4 h-4 text-brand" /> 2. Şaxsiy Ta’lim Yöli & Dars (00:55 - 01:55)
                </h3>
                <p className="text-xs text-slate-600 leading-relaxed">
                  Öquvçiga standart kitobdagi barça mavzular emas, aynan uning böşliğiga mos qadamli yöl oçiladi. Dars nazariya, vizual modellar va amaliy maşqlar orqali bosqiçma-bosqiç özlaştiriladi.
                </p>
              </div>

              <div className="p-5 rounded-2xl bg-slate-50 border border-slate-200 space-y-2">
                <h3 className="font-bold text-mint flex items-center gap-2">
                  <ShieldCheck className="w-4 h-4 text-mint" /> 3. Server-Side Scoring & Anti-Cheat (01:55 - 02:25)
                </h3>
                <p className="text-xs text-slate-600 leading-relaxed">
                  Öquvçi brauzer konsoli orqali javoblarni köra olmaydi yoki XP ni soxtalaştira olmaydi. PostgreSQL RPC funksiyasi serverda javobni xolis tekşirib, xavfsiz ball beradi.
                </p>
              </div>

              <div className="p-5 rounded-2xl bg-slate-50 border border-slate-200 space-y-2">
                <h3 className="font-bold text-brand-dark flex items-center gap-2">
                  <Bot className="w-4 h-4 text-brand" /> 4. Yölçi AI & Natijalar (02:25 - 03:30)
                </h3>
                <p className="text-xs text-slate-600 leading-relaxed">
                  Supabase Edge Function orqali Google Gemini 2.5 Flash mentori xatolikning asl sababini pedagogik uslubda tuşuntiradi. Öquvçi paneli bilim darajasi ösganini real vaqtda aks ettiradi.
                </p>
              </div>
            </div>
          </div>
        </section>

        {/* 6.3. IŞLAYOTGAN PROTOTIP HAVOLALARI */}
        <section className="p-8 sm:p-12 rounded-3xl bg-gradient-to-r from-path via-brand to-brand text-white shadow-xl text-center space-y-6">
          <div className="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-white/20 text-white text-xs font-black backdrop-blur-md">
            <CheckCircle2 className="w-3.5 h-3.5" />
            6.3-TALAB: IŞLAYOTGAN PROTOTIP HAVOLASI
          </div>

          <h2 className="text-3xl sm:text-4xl font-extrabold text-white">
            Hozirning Özida Jonli Prototipni Sinab Köring
          </h2>

          <p className="text-path text-sm sm:text-base max-w-2xl mx-auto leading-relaxed">
            Hakamlar va investorlar töğridan-töğri brauzerda yoki mobil ilova orqali real ta’lim jarayonini öz közlari bilan sinab körişlari mumkin:
          </p>

          <div className="flex flex-wrap items-center justify-center gap-4 pt-2">
            <Button
              variant="primary"
              size="md"
              onClick={onNavigateCourses}
              className="bg-white hover:bg-slate-100 text-slate-950 font-black px-8 py-3.5 rounded-2xl shadow-xl flex items-center gap-3 cursor-pointer text-sm transition-all transform hover:-translate-y-0.5"
            >
              <Zap className="w-4 h-4 fill-current text-amber-500" />
              1. Fanni Tanlaş va Diagnostika (/courses)
            </Button>

            <Button
              variant="outline"
              size="md"
              onClick={onNavigateDashboard}
              className="bg-white/10 hover:bg-white/20 border border-white/30 text-white font-bold px-8 py-3.5 rounded-2xl flex items-center gap-3 cursor-pointer text-sm backdrop-blur-md"
            >
              <TrendingUp className="w-4 h-4 text-mint" />
              2. Öquvçi Daşboardini Köriş (/dashboard)
            </Button>

            <Button
              variant="outline"
              size="md"
              onClick={onNavigateAiTutor}
              className="bg-white/10 hover:bg-white/20 border border-white/30 text-white font-bold px-8 py-3.5 rounded-2xl flex items-center gap-3 cursor-pointer text-sm backdrop-blur-md"
            >
              <Bot className="w-4 h-4 text-path" />
              3. Yölçi AI Çatini Sinaş (/ai-tutor)
            </Button>

            <a
              href="https://github.com/pirimovuktam/bilimyol-smart-edu"
              target="_blank"
              rel="noreferrer"
              className="px-6 py-3.5 rounded-2xl bg-white/10 hover:bg-white/20 border border-white/30 text-white font-bold flex items-center gap-2 text-sm transition-colors backdrop-blur-md"
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
