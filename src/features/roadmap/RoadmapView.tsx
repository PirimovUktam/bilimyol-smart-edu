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
import { Badge } from '@/presentation/components/Badge';
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
        <Card className="max-w-md w-full p-7 text-center border-rose-200 bg-rose-50/50 space-y-4">
          <AlertTriangle className="w-10 h-10 text-rose-500 mx-auto" />
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
        <div className="w-10 h-10 border-4 border-indigo-600 border-t-transparent rounded-full animate-spin" />
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
      {/* 1. Header with View Toggle Pill (Reference 2 style: [Bilim xaritasi | Roadmap]) */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-slate-200">
        <div>
          <div className="flex items-center gap-2 mb-1.5">
            <Badge variant="blue" size="sm">
              <Map className="w-3.5 h-3.5 mr-1" />
              Ta’lim Yo‘li
            </Badge>
            <span className="text-xs font-semibold text-slate-500">
              {activeCourse.title}
            </span>
          </div>
          <h1 className="text-2xl sm:text-3xl font-black text-slate-900 tracking-tight">
            Mening Ta’lim Yo‘lim
          </h1>
          <p className="text-sm text-slate-600 mt-1">
            Bilim darajangizga moslashtirilgan individual bosqichlar xaritasi
          </p>
        </div>

        {/* Reference 2 View Switcher Toggle Pill */}
        <div className="flex items-center bg-slate-100 p-1.5 rounded-2xl border border-slate-200 self-start sm:self-auto">
          <button
            onClick={onOpenKnowledgeMap}
            className="flex items-center gap-1.5 px-4 py-2 rounded-xl text-xs font-bold text-slate-600 hover:text-slate-900 transition-all cursor-pointer"
          >
            <Compass className="w-3.5 h-3.5" />
            <span>Bilim xaritasi</span>
          </button>
          <button
            className="flex items-center gap-1.5 px-4 py-2 rounded-xl text-xs font-bold bg-white text-indigo-700 shadow-xs transition-all cursor-default"
          >
            <Map className="w-3.5 h-3.5 text-indigo-600" />
            <span>Roadmap</span>
          </button>
        </div>
      </div>

      {/* 2. Filter Pills (Reference 1: Barchasi, Faol, Tugallangan) */}
      <div className="flex items-center gap-2">
        <button
          onClick={() => setFilterTab('all')}
          className={`px-4 py-1.5 rounded-2xl text-xs font-bold transition-all cursor-pointer ${
            filterTab === 'all'
              ? 'bg-indigo-600 text-white shadow-md shadow-indigo-600/25'
              : 'bg-white text-slate-600 border border-slate-200 hover:bg-slate-50'
          }`}
        >
          Barchasi ({roadmap.nodes.length})
        </button>
        <button
          onClick={() => setFilterTab('active')}
          className={`px-4 py-1.5 rounded-2xl text-xs font-bold transition-all cursor-pointer ${
            filterTab === 'active'
              ? 'bg-indigo-600 text-white shadow-md shadow-indigo-600/25'
              : 'bg-white text-slate-600 border border-slate-200 hover:bg-slate-50'
          }`}
        >
          Faol bosqichlar
        </button>
        <button
          onClick={() => setFilterTab('completed')}
          className={`px-4 py-1.5 rounded-2xl text-xs font-bold transition-all cursor-pointer ${
            filterTab === 'completed'
              ? 'bg-indigo-600 text-white shadow-md shadow-indigo-600/25'
              : 'bg-white text-slate-600 border border-slate-200 hover:bg-slate-50'
          }`}
        >
          Tugallangan
        </button>
      </div>

      {/* 3. Node-based Gamified Learning Map (Reference 2 style) */}
      <div className="relative pl-6 sm:pl-10 space-y-7 before:absolute before:left-[22px] sm:before:left-[38px] before:top-6 before:bottom-6 before:w-1.5 before:bg-gradient-to-b before:from-emerald-500 before:via-indigo-600 before:to-slate-300 before:rounded-full">
        {filteredNodes.map((node, index) => {
          const isCompleted = node.status === 'completed';
          const isReinforcement = node.isReinforcement || node.status === 'reinforcement';
          const isAvailable = node.status === 'available' || node.status === 'reinforcement';
          const targetLesson = resolveRoadmapNodeLessonId(node, courseScopedLessonId);

          return (
            <motion.div
              key={node.id}
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ duration: 0.3, delay: index * 0.08 }}
              className="relative"
            >
              {/* Node Icon on Connecting Track */}
              <div
                className={`absolute -left-[22px] sm:-left-[38px] top-6 -translate-x-1/2 w-9 h-9 sm:w-11 sm:h-11 rounded-full flex items-center justify-center z-10 transition-transform ${
                  isCompleted
                    ? 'bg-emerald-500 text-white shadow-md shadow-emerald-500/30 ring-4 ring-white'
                    : isReinforcement
                    ? 'bg-gradient-to-tr from-rose-500 to-amber-500 text-white shadow-md shadow-rose-500/30 ring-4 ring-rose-100 animate-pulse'
                    : isAvailable
                    ? 'bg-gradient-to-tr from-indigo-600 to-cyan-500 text-white shadow-md shadow-indigo-500/30 ring-4 ring-indigo-100 pulse-glow'
                    : 'bg-slate-200 text-slate-400 ring-4 ring-white'
                }`}
              >
                {isCompleted ? (
                  <CheckCircle2 className="w-5 h-5 sm:w-6 sm:h-6" />
                ) : isReinforcement ? (
                  <AlertTriangle className="w-5 h-5 sm:w-6 sm:h-6" />
                ) : isAvailable ? (
                  <Play className="w-4 h-4 sm:w-5 sm:h-5 fill-white translate-x-0.5" />
                ) : (
                  <Lock className="w-4 h-4 sm:w-5 sm:h-5" />
                )}
              </div>

              {/* Node Content Card */}
              <Card
                variant={isAvailable ? 'interactive' : 'default'}
                className={`p-5 sm:p-6 transition-all ${
                  isReinforcement
                    ? 'border-2 border-rose-300 bg-gradient-to-br from-rose-50/70 via-white to-amber-50/50'
                    : isAvailable
                    ? 'border-2 border-indigo-400 bg-gradient-to-br from-indigo-50/50 via-white to-cyan-50/30 shadow-md'
                    : isCompleted
                    ? 'border-emerald-200 bg-white'
                    : 'opacity-75 bg-slate-50/80 border-slate-200'
                }`}
              >
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                  <div className="space-y-1.5 max-w-xl">
                    <div className="flex items-center gap-2">
                      <span className="text-[10px] font-black uppercase tracking-wider text-slate-500">
                        {index + 1}-Bosqich
                      </span>
                      {isReinforcement && (
                        <span className="px-2 py-0.5 text-[10px] font-black uppercase rounded-full bg-rose-100 text-rose-800 border border-rose-200">
                          Mustahkamlash
                        </span>
                      )}
                      {isCompleted && (
                        <span className="px-2 py-0.5 text-[10px] font-black uppercase rounded-full bg-emerald-100 text-emerald-800 border border-emerald-200">
                          Tugallangan (100%)
                        </span>
                      )}
                      {isAvailable && !isReinforcement && (
                        <span className="px-2 py-0.5 text-[10px] font-black uppercase rounded-full bg-indigo-100 text-indigo-800 border border-indigo-200">
                          Hozirgi Bosqich
                        </span>
                      )}
                    </div>

                    <h3 className="text-lg font-black text-slate-900">
                      {node.title}
                    </h3>
                    <p className="text-xs sm:text-sm text-slate-600 leading-relaxed font-medium">
                      {node.description}
                    </p>

                    <div className="flex items-center gap-4 pt-2 text-xs text-slate-500 font-semibold">
                      <span className="flex items-center gap-1">
                        <Clock className="w-3.5 h-3.5 text-slate-400" />
                        {node.estimatedMinutes || 15} daqiqa
                      </span>
                      <span className="flex items-center gap-1">
                        <Zap className="w-3.5 h-3.5 text-amber-500 fill-amber-500" />
                        +50 XP
                      </span>
                      {node.score !== undefined && (
                        <span className="text-indigo-600 font-bold">
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
                      <Button
                        variant={isReinforcement ? 'coral' : 'gradient'}
                        size="md"
                        onClick={() => {
                          if (!targetLesson) return;
                          selectNode(node);
                          onStartLesson(targetLesson);
                        }}
                        rightIcon={<ArrowRight className="w-4 h-4" />}
                        className="font-extrabold shadow-md"
                      >
                        {isReinforcement ? 'Mustahkamlashni boshlash' : 'Darsni boshlash'}
                      </Button>
                    ) : (
                      <div className="flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-slate-100 text-slate-400 text-xs font-bold">
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

      {/* Floating Bottom Card: Continue Learning (Reference 1 & 2) */}
      <Card variant="hero" className="p-6 sm:p-7">
        <div className="flex flex-col sm:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-4">
            <YolchiAIMascot size="sm" mood="happy" />
            <div>
              <h4 className="text-base font-black text-white">
                Siz hozir yaxshi sur’atdasiz!
              </h4>
              <p className="text-xs text-indigo-100 font-medium">
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
            className="w-full sm:w-auto font-black"
          >
            {courseScopedLessonId ? 'Davom etish' : 'Dars mavjud emas'}
          </Button>
        </div>
      </Card>
    </div>
  );
};
