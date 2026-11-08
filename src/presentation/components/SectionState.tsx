import { AlertCircle, BookOpen, LoaderCircle } from 'lucide-react';
import { Button } from './Button';

interface SectionStateProps {
  title: string;
  description?: string;
  kind?: 'loading' | 'error' | 'empty';
  onRetry?: () => void;
}

export function SectionState({ title, description, kind = 'empty', onRetry }: SectionStateProps) {
  const Icon = kind === 'loading' ? LoaderCircle : kind === 'error' ? AlertCircle : BookOpen;
  return (
    <div
      role={kind === 'error' ? 'alert' : 'status'}
      className="rounded-card border border-hairline bg-paper px-5 py-7 text-center"
    >
      <Icon aria-hidden="true" className={kind === 'loading'
        ? 'mx-auto mb-3 size-6 animate-spin text-brand motion-reduce:animate-none'
        : 'mx-auto mb-3 size-6 text-brand'} />
      <p className="font-bold text-ink">{title}</p>
      {description && <p className="mt-1 text-sm text-slatefine">{description}</p>}
      {onRetry && <Button type="button" variant="outline" className="mt-4" onClick={onRetry}>Qayta urinish</Button>}
    </div>
  );
}
