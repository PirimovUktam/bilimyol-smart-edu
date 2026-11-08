const tashkentDate = new Intl.DateTimeFormat('sv-SE', {
  timeZone: 'Asia/Tashkent',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
});

export function learningDate(daysAgo = 0, now = Date.now()): string {
  return tashkentDate.format(now - daysAgo * 86_400_000);
}
