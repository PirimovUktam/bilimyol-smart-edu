import React, { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import {
  Map,
  CheckCircle2,
  Lock,
  Play,
  RotateCcw,
  ArrowRight,
  Clock,
  Zap,
  AlertTriangle,
  Compass,
} from 'lucide-react';
import { useCourseStore } from '@/app/store/useCourseStore';
import { useRoadmapStore } from '@/app/store/useRoadmapStore';
import { resolveContinuationLessonId, resolveRoadmapNodeLessonId } from '@/app/router/lessonResolution';
import { Button } from '@/presentation/components/Button';
import { Card } from '@/presentation/components/Card';
import { YolchiAIMascot } from '@/presentation/components/YolchiAIMascot';

interface RoadmapViewProps {
  onStartLesson: (lessonId: string) => void;
  onOpenKnowledgeMap: () => void;
}

export const RoadmapView: React.FC<RoadmapViewProps> = ({ onStartLesson, onOpenKnowledgeMap }) => {
  const { activeCourse } = useCourseStore();
  const { roadmap, loadRoadmap, selectNode, error } = useRoadmapStore();
  const [filterTab, setFilterTab] = useState<'all' | 'active' | 'completed'>('all');

  useEffect(() => {
    if (activeCourse) {
      loadRoadmap(activeCourse.id);
    }
  }, [activeCourse, loadRoadmap]);

  if (error) {
    return (
      <div className="min-h-[60vh] flex items-center justify-center px-4">
        <Card className="max-w-md w-full p-7 text-center border-coral/25 bg-rose-50/50 space-y-4">
          <AlertTriangle className="w-10 h-10 text-coral mx-auto" />
          <div>
            <h2 className="text-lg font-black text-slate-900">Ta’lim yo‘li yuklanmadi</h2>
            <p role="alert" className="text-sm text-slate-600 mt-1">{error}</p>
          </div>
          {activeCourse && (
            <Button variant="primary" onClick={() => void loadRoadmap(activeCourse.id)}>
              Qayta urinish
            </Button>
          )}
        </Card>
      </div>
    );
  }

  if (!roadmap || !activeCourse || roadmap.courseId !== activeCourse.id) {
    return (
      <div className="min-h-[60vh] flex items-center justify-center">
        <div className="w-10 h-10 border-4 border-brand border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  // Course-scoped fallback only: never falls back to another course's lesson.
  const courseScopedLessonId = resolveContinuationLessonId(activeCourse, roadmap);

  // Filter nodes based on selected filter tab
  const filteredNodes = roadmap.nodes.filter((node) => {
    if (filterTab === 'active') return node.status === 'available' || node.status === 'reinforcement';
    if (filterTab === 'completed') return node.status === 'completed';
    return true;
  });

  return (
    <div className="max-w-4xl mx-auto px-4 py-8 space-y-7">
      {/* 1. Header with View Toggle Pill */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-[#e4ddce]">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <span className="editorial-kicker">
              Ta’lim Yo‘li // Shaxsiy marshrut
            </span>
            <span className="font-mono text-xs font-bold text-slate-700 bg-white border border-[#e4ddce] px-2.5 py-0.5 rounded">
              {activeCourse.title}
            </span>
          </div>
          <h1 className="font-display text-2xl sm:text-3xl font-bold text-slate-900 tracking-tight">
            Mening Ta’lim Yo‘lim
          </h1>
          <p className="text-xs sm:text-sm text-slate-600 mt-1 font-medium">
            Bilim darajangizga moslashtirilgan individual bosqichlar xaritasi
          </p>
        </div>

        {/* View Switcher Toggle Pill */}
        <div className="flex items-center bg-white p-1 rounded-xl border border-[#e4ddce] self-start sm:self-auto shadow-2xs">
          <button
            onClick={onOpenKnowledgeMap}
            className="flex items-center gap-1.5 px-3.5 py-1.5 rounded-lg text-xs font-bold text-slate-600 hover:text-slate-900 hover:bg-[#f5efe4] transition-all cursor-pointer"
          >
            <Compass className="w-3.5 h-3.5" />
            <span>Bilim xaritasi</span>
          </button>
          <button
            className="flex items-center gap-1.5 px-3.5 py-1.5 rounded-lg text-xs font-bold bg-[#10151f] text-white shadow-2xs transition-all cursor-default"
          >
            <Map className="w-3.5 h-3.5 text-path" />
            <span>Roadmap</span>
          </button>
        </div>
      </div>

      {/* 2. Filter Pills */}
      <div className="flex items-center gap-2">
        <button
          onClick={() => setFilterTab('all')}
          className={`px-3.5 py-1.5 rounded-lg text-xs font-bold transition-all cursor-pointer ${
            filterTab === 'all'
              ? 'bg-[#10151f] text-white shadow-xs'
              : 'bg-white text-slate-700 border border-[#e4ddce] hover:bg-[#f5efe4]'
          }`}
        >
          Barchasi ({roadmap.nodes.length})
        </button>
        <button
          onClick={() => setFilterTab('active')}
          className={`px-3.5 py-1.5 rounded-lg text-xs font-bold transition-all cursor-pointer ${
            filterTab === 'active'
              ? 'bg-[#10151f] text-white shadow-xs'
              : 'bg-white text-slate-700 border border-[#e4ddce] hover:bg-[#f5efe4]'
          }`}
        >
          Faol bosqichlar
        </button>
        <button
          onClick={() => setFilterTab('completed')}
          className={`px-3.5 py-1.5 rounded-lg text-xs font-bold transition-all cursor-pointer ${
            filterTab === 'completed'
              ? 'bg-[#10151f] text-white shadow-xs'
              : 'bg-white text-slate-700 border border-[#e4ddce] hover:bg-[#f5efe4]'
          }`}
        >
          Tugallangan
        </button>
      </div>

      {/* 3. Node-based Gamified Learning Map — journey track */}
      <div className="relative pl-6 sm:pl-10 space-y-6 before:absolute before:left-[22px] sm:before:left-[38px] before:top-6 before:bottom-6 before:w-1 before:bg-[#e4ddce] before:rounded-full before:content-['']">
        {filteredNodes.map((node, index) => {
          const isCompleted = node.status === 'completed';
          const isReinforcement = node.isReinforcement || node.status === 'reinforcement';
          const isAvailable = node.status === 'available' || node.status === 'reinforcement';
          const targetLesson = resolveRoadmapNodeLessonId(node, courseScopedLessonId);

          return (
            <motion.div
              key={node.id}
              initial={{ opacity: 0, x: -16 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ duration: 0.25, delay: index * 0.05 }}
              className="relative"
            >
              {/* Node Icon on Connecting Track */}
              <div
                className={`absolute -left-[22px] sm:-left-[38px] top-6 -translate-x-1/2 w-8 h-8 sm:w-10 sm:h-10 rounded-full flex items-center justify-center z-10 transition-transform ${
                  isCompleted
                    ? 'bg-mint text-white shadow-sm ring-4 ring-mint/10'
                    : isReinforcement
                    ? 'bg-coral text-white shadow-sm ring-4 ring-coral/10 lab-pulse'
                    : isAvailable
                    ? 'bg-[#10151f] text-path shadow-md ring-4 ring-slate-200'
                    : 'bg-[#f5efe4] text-slate-400 border border-[#e4ddce] ring-4 ring-[#fbf9f4]'
                }`}
              >
                {isCompleted ? (
                  <CheckCircle2 className="w-4 h-4 sm:w-5 sm:h-5" />
                ) : isReinforcement ? (
                  <AlertTriangle className="w-4 h-4 sm:w-5 sm:h-5" />
                ) : isAvailable ? (
                  <Play className="w-3.5 h-3.5 sm:w-4 sm:h-4 fill-path translate-x-0.5" />
                ) : (
                  <Lock className="w-3.5 h-3.5 sm:w-4 sm:h-4" />
                )}
              </div>

              {/* Node Content Card */}
              <div
                className={`rounded-2xl p-5 sm:p-6 transition-all ${
                  isReinforcement
                    ? 'border-2 border-coral/30 bg-[#fff8f8] shadow-sm'
                    : isAvailable
                    ? 'border-2 border-[#10151f] bg-white shadow-md'
                    : isCompleted
                    ? 'border border-mint/25 bg-white shadow-2xs'
                    : 'border border-[#e4ddce] bg-[#fbf9f4] opacity-75'
                }`}
              >
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                  <div className="space-y-1.5 max-w-xl">
                    <div className="flex items-center gap-2">
                      <span className="font-mono text-[10px] font-bold uppercase tracking-wider text-slate-500">
                        {index + 1}-Bosqich
                      </span>
                      {isReinforcement && (
                        <span className="px-2 py-0.5 text-[10px] font-mono font-bold uppercase rounded bg-coral/10 text-coral border border-coral/25">
                          Mustahkamlash
                        </span>
                      )}
                      {isCompleted && (
                        <span className="px-2 py-0.5 text-[10px] font-mono font-bold uppercase rounded bg-mint/10 text-mint border border-mint/25">
                          Tugallangan
                        </span>
                      )}
                      {isAvailable && !isReinforcement && (
                        <span className="px-2 py-0.5 text-[10px] font-mono font-bold uppercase rounded bg-brand/8 text-brand-dark border border-brand/25">
                          Hozirgi Bosqich
                        </span>
                      )}
                    </div>

                    <h3 className="font-display text-lg font-bold text-slate-900">
                      {node.title}
                    </h3>
                    <p className="text-xs sm:text-sm text-slate-600 leading-relaxed font-medium">
                      {node.description}
                    </p>

                    <div className="flex items-center gap-4 pt-2 font-mono text-xs text-slate-500">
                      <span className="flex items-center gap-1">
                        <Clock className="w-3.5 h-3.5 text-slate-400" />
                        {node.estimatedMinutes || 15} daqiqa
                      </span>
                      <span className="flex items-center gap-1 text-amber-700 font-bold">
                        <Zap className="w-3.5 h-3.5 text-amber-500 fill-amber-500" />
                        XP mukofoti
                      </span>
                      {node.score !== undefined && (
                        <span className="text-brand font-bold">
                          O‘zlashtirish: {node.score}%
                        </span>
                      )}
                    </div>
                  </div>

                  {/* Action CTA */}
                  <div className="flex items-center gap-2 self-start sm:self-center shrink-0">
                    {isCompleted ? (
                      <Button
                        variant="outline"
                        size="sm"
                        disabled={!targetLesson}
                        onClick={() => {
                          if (!targetLesson) return;
                          selectNode(node);
                          onStartLesson(targetLesson);
                        }}
                        leftIcon={<RotateCcw className="w-3.5 h-3.5 text-slate-500" />}
                      >
                        {targetLesson ? 'Qayta ko‘rish' : 'Ko‘rib chiqish mavjud emas'}
                      </Button>
                    ) : isAvailable ? (
                      <button
                        onClick={() => {
                          if (!targetLesson) return;
                          selectNode(node);
                          onStartLesson(targetLesson);
                        }}
                        className={`px-5 py-2.5 rounded-xl font-bold text-xs sm:text-sm shadow-sm flex items-center gap-2 transition-all cursor-pointer ${
                          isReinforcement
                            ? 'bg-coral hover:bg-coral text-white shadow-rose-600/20'
                            : 'bg-[#10151f] hover:bg-[#2a3342] text-white'
                        }`}
                      >
                        <span>{isReinforcement ? 'Mustahkamlashni boshlash' : 'Darsni boshlash'}</span>
                        <ArrowRight className="w-4 h-4 text-path" />
                      </button>
                    ) : (
                      <div className="flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-[#f5efe4] border border-[#e4ddce] text-slate-400 font-mono text-xs font-bold">
                        <Lock className="w-3.5 h-3.5" />
                        <span>Qulflangan</span>
                      </div>
                    )}
                  </div>
                </div>
              </div>
            </motion.div>
          );
        })}
      </div>

      {/* Floating Bottom Card: Continue Learning */}
      <div className="editorial-ink-hero p-6 sm:p-7 rounded-2xl border border-white/10 text-white shadow-xl">
        <div className="flex flex-col sm:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-4">
            <YolchiAIMascot size="sm" mood="happy" />
            <div>
              <h4 className="font-display text-base font-bold text-white">
                Siz hozir yaxshi sur’atdasiz!
              </h4>
              <p className="text-xs text-slate-300 font-medium">
                Ketma-ketlikni saqlab qoling va darsni yakunlang.
              </p>
            </div>
          </div>

          <Button
            variant="primary"
            size="md"
            disabled={!courseScopedLessonId}
            onClick={() => {
              if (courseScopedLessonId) onStartLesson(courseScopedLessonId);
            }}
            rightIcon={<ArrowRight className="w-4 h-4 text-path" />}
            className="w-full sm:w-auto font-bold bg-white text-slate-950 hover:bg-slate-100 shadow-md"
          >
            {courseScopedLessonId ? 'Davom etish' : 'Dars mavjud emas'}
          </Button>
        </div>
      </div>
    </div>
  );
};
