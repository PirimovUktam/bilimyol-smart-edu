interface CircularProgressProps {
  value: number;
  label: string;
}

export function CircularProgress({ value, label }: CircularProgressProps) {
  const percent = Math.max(0, Math.min(100, Math.round(value)));
  return (
    <div
      role="progressbar"
      aria-label={label}
      aria-valuenow={percent}
      aria-valuemin={0}
      aria-valuemax={100}
      className="relative grid size-20 shrink-0 place-items-center"
    >
      <svg viewBox="0 0 80 80" aria-hidden="true" className="absolute inset-0 -rotate-90">
        <circle cx="40" cy="40" r="34" fill="none" stroke="currentColor" strokeWidth="6" className="text-muted" />
        <circle cx="40" cy="40" r="34" fill="none" stroke="currentColor" strokeWidth="6" strokeLinecap="round"
          pathLength="100" strokeDasharray={percent + ' 100'} className="text-brand" />
      </svg>
      <span className="font-display text-xl font-bold tabular-nums">{percent}%</span>
    </div>
  );
}
