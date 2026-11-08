import type { DailyActivitySummary } from '@/domain/repositories/ILearnerRepository';

const dayLabels = ['Yak', 'Dush', 'Sesh', 'Chor', 'Pay', 'Jum', 'Shan'];

export function WeeklyActivity({ days }: { days: DailyActivitySummary[] }) {
  const max = Math.max(...days.map((day) => day.activeMinutes), 1);
  const total = days.reduce((sum, day) => sum + day.activeMinutes, 0);
  return (
    <figure className="space-y-3">
      <figcaption className="text-sm text-slatefine">
        <strong className="font-display text-2xl text-ink">{total}</strong> daqiqa oxirgi {days.length} kunda
      </figcaption>
      <ol className={'grid min-h-28 ' + (days.length <= 7 ? 'gap-1.5 sm:gap-2' : 'gap-0.5 sm:gap-1')}
        style={{ gridTemplateColumns: 'repeat(' + Math.max(days.length, 1) + ',minmax(0,1fr))' }}
        aria-label="Kunlik o‘qish vaqti">
        {days.map(({ date, activeMinutes }, index) => {
          const label = days.length <= 7 ? dayLabels[new Date(date + 'T00:00:00Z').getUTCDay()] : date.slice(-2);
          return (
            <li key={date} className="flex min-w-0 flex-col justify-end gap-2 text-center"
              aria-label={date + ', ' + activeMinutes + ' daqiqa'} title={date + ' · ' + activeMinutes + ' daqiqa'}>
              <div aria-hidden="true" className="flex h-20 items-end overflow-hidden rounded-t-lg bg-sand">
                <div className="w-full rounded-t-lg bg-brand" style={{ height: (100 * activeMinutes / max) + '%' }} />
              </div>
              <span aria-hidden="true" className="h-4 truncate text-[11px] font-semibold text-slatefine">
                {(days.length <= 7 || index % 5 === 0) && label}
              </span>
            </li>
          );
        })}
      </ol>
      {total === 0 && <p className="text-xs text-slatefine">Mashg‘ulot vaqti qayd etilgach, grafik yangilanadi.</p>}
    </figure>
  );
}
