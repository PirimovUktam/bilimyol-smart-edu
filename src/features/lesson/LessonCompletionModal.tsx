import { ArrowRight, Trophy } from 'lucide-react';
import { Button } from '@/presentation/components/Button';
import { Modal } from '@/presentation/components/Modal';
import { Progress } from '@/presentation/components/Progress';

interface LessonCompletionModalProps {
  isOpen: boolean;
  correctCount: number;
  totalCount: number;
  lessonTitle: string;
  skill?: { name: string; score: number };
  onProceedToNext: () => void;
}

export function LessonCompletionModal({ isOpen, correctCount, totalCount, lessonTitle, skill, onProceedToNext }: LessonCompletionModalProps) {
  return (
    <Modal isOpen={isOpen} title="Dars yakunlandi" maxWidth="sm" showClose={false} dismissable={false}>
      <div className="space-y-4">
        <span className="grid size-12 place-items-center rounded-xl bg-amber-100 text-amber-800">
          <Trophy aria-hidden="true" className="size-6" />
        </span>
        <p className="break-words font-bold">{lessonTitle}</p>
        <p className="text-sm text-slatefine">{correctCount} / {totalCount} javob to‘g‘ri. Dars natijasi saqlandi.</p>
        {skill && <Progress value={skill.score} showLabel ariaLabel={skill.name} tone="emerald" />}
        <Button className="w-full" onClick={onProceedToNext} rightIcon={<ArrowRight aria-hidden="true" className="size-4" />}>
          Ta’lim yo‘liga o‘tish
        </Button>
      </div>
    </Modal>
  );
}
