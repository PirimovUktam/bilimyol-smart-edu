import { create } from 'zustand';
import { LearningPath, LearningPathNode } from '@/domain/entities/LearningPathNode';
import { inMemoryLessonRepository } from '@/data/repositories/InMemoryLessonRepository';
import { inMemoryLearnerRepository } from '@/data/repositories/InMemoryLearnerRepository';
import { GetRoadmapUseCase } from '@/domain/usecases/GetRoadmapUseCase';
import { SubmitReinforcementUseCase, ReinforcementResult } from '@/domain/usecases/SubmitReinforcementUseCase';
import { Question } from '@/domain/entities/Question';

interface RoadmapState {
  roadmap: LearningPath | null;
  selectedNode: LearningPathNode | null;
  isLoading: boolean;
  isUpdating: boolean;

  loadRoadmap: (courseId: string) => Promise<void>;
  selectNode: (node: LearningPathNode) => void;
  completeReinforcement: (
    courseId: string,
    skillId: string,
    reinforcementNodeId: string,
    reinforcementQuestion: Question,
    selectedIndex: number
  ) => Promise<ReinforcementResult>;
}

export const useRoadmapStore = create<RoadmapState>((set) => ({
  roadmap: null,
  selectedNode: null,
  isLoading: false,
  isUpdating: false,

  loadRoadmap: async (courseId: string) => {
    set({ isLoading: true });
    const useCase = new GetRoadmapUseCase(inMemoryLessonRepository, inMemoryLearnerRepository);
    const roadmap = await useCase.execute(courseId);
    const activeNode =
      roadmap.nodes.find((n) => n.status === 'reinforcement' || n.status === 'available') ||
      roadmap.nodes[0] ||
      null;

    set({
      roadmap,
      selectedNode: activeNode,
      isLoading: false,
    });
  },

  selectNode: (node) => {
    set({ selectedNode: node });
  },

  completeReinforcement: async (courseId, skillId, reinforcementNodeId, reinforcementQuestion, selectedIndex) => {
    set({ isUpdating: true });
    const useCase = new SubmitReinforcementUseCase(inMemoryLearnerRepository, inMemoryLessonRepository);
    const result = await useCase.execute(
      courseId,
      skillId,
      reinforcementNodeId,
      reinforcementQuestion,
      selectedIndex
    );

    if (result.isCorrect) {
      set({
        roadmap: result.updatedRoadmap,
        selectedNode: result.updatedRoadmap.nodes.find((n) => n.id === reinforcementNodeId) || null,
        isUpdating: false,
      });
    } else {
      set({ isUpdating: false });
    }

    return result;
  },
}));
