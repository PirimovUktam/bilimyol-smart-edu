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
import { resolveContinuationLessonId } from '@/app/router/lessonResolution';
import { Button } from '@/presentation/components/Button';
import { Card } from '@/presentation/components/Card';
import { Badge } from '@/presentation/components/Badge';
import { YolchiAIMascot } from '@/presentation/components/YolchiAIMascot';

interface RoadmapViewProps {
  onStartLesson: (lessonId: string) => void;
  onOpenKnowledgeMap: () => void;
}

export const RoadmapView: React.FC<RoadmapViewProps> = ({ onStartLesson, onOpenKnowledgeMap }) => {
  const { activeCourse } = useCourseStore();
  const { roadmap, loadRoadmap, selectNode } = useRoadmapStore();
  const [filterTab, setFilterTab] = useState<'all' | 'active' | 'completed'>('all');

  useEffect(() => {
    if (activeCourse) {
      loadRoadmap(activeCourse.id);
    }
  }, [activeCourse, loadRoadmap]);

  if (!roadmap || !activeCourse || roadmap.courseId !== activeCourse.id) {
    return (
      <div className="min-h-[60vh] flex items-center justify-center">
        <div className="w-12 h-12 border-4 border-cyan-400 border-t-transparent rounded-full animate-spin" />
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
    <div className="max-w-4xl mx-auto px-4 py-8 space-y-7 relative">
      {/* 1. Header with View Toggle Pill */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-white/10">
        <div>
          <div className="flex items-center gap-2 mb-1.5">
            <Badge variant="cyan" size="sm">
              <Map className="w-3.5 h-3.5 mr-1" />
              Ta’lim Yo‘li
            </Badge>
            <span className="text-xs font-semibold text-slate-400">
              {activeCourse.title}
            </span>
          </div>
          <h1 className="text-2xl sm:text-4xl font-black text-white tracking-tight">
            Mening Ta’lim Yo‘lim
          </h1>
          <p className="text-sm text-slate-300 mt-1">
            Bilim darajangizga moslashtirilgan individual bosqichlar xaritasi
          </p>
        </div>

        {/* View Switcher Toggle Pill */}
        <div className="flex items-center bg-slate-900/90 p-1.5 rounded-2xl border border-white/10 self-start sm:self-auto backdrop-blur-xl">
          <button
            onClick={onOpenKnowledgeMap}
            className="flex items-center gap-1.5 px-4 py-2 rounded-xl text-xs font-bold text-slate-400 hover:text-white transition-all cursor-pointer"
          >
            <Compass className="w-3.5 h-3.5" />
            <span>Bilim xaritasi</span>
          </button>
          <button
            className="flex items-center gap-1.5 px-4 py-2 rounded-xl text-xs font-black bg-gradient-to-r from-cyan-500 to-indigo-600 text-white shadow-md shadow-indigo-600/30 transition-all cursor-default"
          >
            <Map className="w-3.5 h-3.5 text-white" />
            <span>Roadmap</span>
          </button>
        </div>
      </div>

      {/* 2. Filter Pills */}
      <div className="flex items-center gap-2">
        <button
          onClick={() => setFilterTab('all')}
          className={`px-4 py-1.5 rounded-2xl text-xs font-extrabold transition-all cursor-pointer ${
            filterTab === 'all'
              ? 'bg-gradient-to-r from-cyan-500 to-indigo-600 text-white shadow-[0_0_15px_rgba(6,182,212,0.3)]'
              : 'bg-slate-900/80 text-slate-400 border border-white/10 hover:text-white'
          }`}
        >
          Barchasi ({roadmap.nodes.length})
        </button>
        <button
          onClick={() => setFilterTab('active')}
          className={`px-4 py-1.5 rounded-2xl text-xs font-extrabold transition-all cursor-pointer ${
            filterTab === 'active'
              ? 'bg-gradient-to-r from-cyan-500 to-indigo-600 text-white shadow-[0_0_15px_rgba(6,182,212,0.3)]'
              : 'bg-slate-900/80 text-slate-400 border border-white/10 hover:text-white'
          }`}
        >
          Faol bosqichlar
        </button>
        <button
          onClick={() => setFilterTab('completed')}
          className={`px-4 py-1.5 rounded-2xl text-xs font-extrabold transition-all cursor-pointer ${
            filterTab === 'completed'
              ? 'bg-gradient-to-r from-cyan-500 to-indigo-600 text-white shadow-[0_0_15px_rgba(6,182,212,0.3)]'
              : 'bg-slate-900/80 text-slate-400 border border-white/10 hover:text-white'
          }`}
        >
          Tugallangan
        </button>
      </div>

      {/* 3. Node-based Gamified Learning Map */}
      <div className="relative pl-6 sm:pl-10 space-y-7 before:absolute before:left-[22px] sm:before:left-[38px] before:top-6 before:bottom-6 before:w-1.5 before:bg-gradient-to-b before:from-emerald-400 before:via-cyan-500 before:to-indigo-600 before:rounded-full before:shadow-[0_0_12px_rgba(6,182,212,0.6)]">
        {filteredNodes.map((node, index) => {
          const isCompleted = node.status === 'completed';
          const isReinforcement = node.isReinforcement || node.status === 'reinforcement';
          const isLocked = node.status === 'locked';
          const isAvailable = node.status === 'available' || node.status === 'reinforcement';
          const targetLesson = node.targetLessonId || courseScopedLessonId;

          return (
            <motion.div
              key={node.id}
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ duration: 0.35, delay: index * 0.08 }}
              className="relative"
            >
              {/* Node Icon on Connecting Track */}
              <div
                className={`absolute -left-[22px] sm:-left-[38px] top-6 -translate-x-1/2 w-9 h-9 sm:w-11 sm:h-11 rounded-full flex items-center justify-center z-10 transition-transform ${
                  isCompleted
                    ? 'bg-emerald-500 text-slate-950 shadow-[0_0_20px_rgba(16,185,129,0.5)] ring-4 ring-emerald-500/30'
                    : isReinforcement
                    ? 'bg-gradient-to-tr from-rose-500 to-amber-500 text-white shadow-[0_0_20px_rgba(244,63,94,0.5)] ring-4 ring-rose-500/30 animate-pulse'
                    : isAvailable
                    ? 'bg-gradient-to-tr from-cyan-400 to-blue-500 text-slate-950 shadow-[0_0_25px_rgba(6,182,212,0.6)] ring-4 ring-cyan-400/40 pulse-glow'
                    : 'bg-slate-800 text-slate-500 ring-4 ring-slate-800/40'
                }`}
              >
                {isCompleted ? (
                  <CheckCircle2 className="w-5 h-5 sm:w-6 sm:h-6" />
                ) : isReinforcement ? (
                  <AlertTriangle className="w-5 h-5 sm:w-6 sm:h-6" />
                ) : isAvailable ? (
                  <Play className="w-4 h-4 sm:w-5 sm:h-5 fill-slate-950 translate-x-0.5" />
                ) : (
                  <Lock className="w-4 h-4 sm:w-5 sm:h-5" />
                )}
              </div>

              {/* Node Content Card */}
              <Card
                className={`p-5 sm:p-6 transition-all duration-300 backdrop-blur-2xl ${
                  isReinforcement
                    ? 'border-2 border-rose-500/50 bg-slate-900/90 shadow-[0_0_30px_rgba(244,63,94,0.2)]'
                    : isAvailable
                    ? 'border-2 border-cyan-400/60 bg-slate-900/90 shadow-[0_0_35px_rgba(6,182,212,0.2)]'
                    : isCompleted
                    ? 'border-emerald-500/40 bg-slate-900/80 shadow-md'
                    : 'opacity-70 bg-slate-950/60 border-white/5'
                }`}
              >
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                  <div className="space-y-2 max-w-xl">
                    <div className="flex items-center gap-2">
                      <span className="text-[10px] font-black uppercase tracking-wider text-slate-400">
                        {index + 1}-Bosqich
                      </span>
                      {isReinforcement && (
                        <span className="px-2.5 py-0.5 text-[10px] font-black uppercase rounded-full bg-rose-950/80 text-rose-300 border border-rose-500/40 shadow-xs">
                          Mustahkamlash
                        </span>
                      )}
                      {isCompleted && (
                        <span className="px-2.5 py-0.5 text-[10px] font-black uppercase rounded-full bg-emerald-950/80 text-emerald-300 border border-emerald-500/40 shadow-xs">
                          Tugallangan (100%)
                        </span>
                      )}
                      {isAvailable && !isReinforcement && (
                        <span className="px-2.5 py-0.5 text-[10px] font-black uppercase rounded-full bg-cyan-950/80 text-cyan-300 border border-cyan-500/40 shadow-xs">
                          Hozirgi Bosqich
                        </span>
                      )}
                    </div>

                    <h3 className="text-lg sm:text-xl font-black text-white">
                      {node.title}
                    </h3>
                    <p className="text-xs sm:text-sm text-slate-300 leading-relaxed font-medium">
                      {node.description}
                    </p>

                    <div className="flex items-center gap-4 pt-2 text-xs text-slate-400 font-semibold">
                      <span className="flex items-center gap-1">
                        <Clock className="w-3.5 h-3.5 text-cyan-400" />
                        {node.estimatedMinutes || 15} daqiqa
                      </span>
                      <span className="flex items-center gap-1">
                        <Zap className="w-3.5 h-3.5 text-amber-400 fill-amber-400" />
                        +50 XP
                      </span>
                      {node.score !== undefined && (
                        <span className="text-cyan-400 font-bold">
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
                        onClick={() => {
                          if (!targetLesson) return;
                          selectNode(node);
                          onStartLesson(targetLesson);
                        }}
                        leftIcon={<RotateCcw className="w-3.5 h-3.5 text-slate-300" />}
                        className="bg-slate-800 text-slate-200 border-white/10 hover:bg-slate-700"
                      >
                        Qayta ko‘rish
                      </Button>
                    ) : isAvailable ? (
                      <Button
                        variant={isReinforcement ? 'coral' : 'gradient'}
                        size="md"
                        onClick={() => {
                          if (!targetLesson) return;
                          selectNode(node);
                          onStartLesson(targetLesson);
                        }}
                        rightIcon={<ArrowRight className="w-4 h-4" />}
                        className="font-black shadow-lg cursor-pointer"
                      >
                        {isReinforcement ? 'Mustahkamlashni boshlash' : 'Darsni boshlash'}
                      </Button>
                    ) : (
                      <div className="flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-slate-800/80 text-slate-400 text-xs font-bold border border-white/5">
                        <Lock className="w-3.5 h-3.5" />
                        <span>Bloklangan</span>
                      </div>
                    )}
                  </div>
                </div>
              </Card>
            </motion.div>
          );
        })}
      </div>

      {/* Floating Bottom Card */}
      <Card variant="hero" className="p-6 sm:p-7 bg-gradient-to-r from-indigo-950 via-purple-950 to-slate-900 border-2 border-indigo-500/40 shadow-2xl">
        <div className="flex flex-col sm:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-4">
            <YolchiAIMascot size="sm" mood="happy" variant="dark" />
            <div>
              <h4 className="text-base font-black text-white">
                Siz hozir ajoyib sur’atdasiz!
              </h4>
              <p className="text-xs text-slate-300 font-medium">
                Ketma-ketlikni saqlab qoling va darsni yakunlang.
              </p>
            </div>
          </div>

          <Button
            variant="cyan"
            size="md"
            disabled={!courseScopedLessonId}
            onClick={() => {
              if (courseScopedLessonId) onStartLesson(courseScopedLessonId);
            }}
            rightIcon={<ArrowRight className="w-4 h-4" />}
            className="w-full sm:w-auto font-black shadow-lg"
          >
            {courseScopedLessonId ? 'Davom etish' : 'Dars mavjud emas'}
          </Button>
        </div>
      </Card>
    </div>
  );
};
