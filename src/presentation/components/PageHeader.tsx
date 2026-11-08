import type { ReactNode } from 'react';
import { Sparkles } from 'lucide-react';

interface PageHeaderProps {
  title: string;
  description?: string;
  eyebrow?: string;
  highlightWord?: string;
  action?: ReactNode;
}

function renderSplitHeading(title: string, highlightWord?: string) {
  if (highlightWord && title.includes(highlightWord)) {
    const idx = title.indexOf(highlightWord);
    const before = title.slice(0, idx);
    const after = title.slice(idx + highlightWord.length);
    return (
      <>
        {before}
        <span className="heading-accent">{highlightWord}</span>
        {after}
      </>
    );
  }
  const trimmed = title.trim();
  const lastSpace = trimmed.lastIndexOf(' ');
  if (lastSpace <= 0) {
    return title;
  }
  return (
    <>
      {trimmed.slice(0, lastSpace + 1)}
      <span className="heading-accent">{trimmed.slice(lastSpace + 1)}</span>
    </>
  );
}

export function PageHeader({ title, description, eyebrow, highlightWord, action }: PageHeaderProps) {
  return (
    <header className="fade-up flex flex-wrap items-end justify-between gap-4">
      <div className="min-w-0">
        {eyebrow && (
          <div className="mb-2.5">
            <span className="highlight">
              <Sparkles aria-hidden="true" className="size-3.5 shrink-0" />
              {eyebrow}
            </span>
          </div>
        )}
        <h1 className="heading break-words text-3xl leading-tight font-extrabold tracking-tight text-ink sm:text-4xl">
          {renderSplitHeading(title, highlightWord)}
        </h1>
        {description && (
          <p className="mt-2.5 max-w-2xl text-sm leading-relaxed text-slatefine sm:text-base">
            {description}
          </p>
        )}
      </div>
      {action && <div className="shrink-0">{action}</div>}
    </header>
  );
}
