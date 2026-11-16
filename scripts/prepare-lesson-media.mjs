import { mkdir, readFile, writeFile } from 'node:fs/promises';

const source = new URL('../content/math-pilot/addition-media.json', import.meta.url);
const output = new URL('../artifacts/math-pilot/media/', import.meta.url);
const lesson = JSON.parse(await readFile(source, 'utf8'));

const hasText = (value) => typeof value === 'string' && value.trim().length > 0;
if (lesson.lessonId !== 'lesson_math_starter' || !hasText(lesson.objective) ||
    lesson.language !== 'uz' || lesson.reviewStatus !== 'draft' ||
    !Number.isInteger(lesson.durationSeconds) || !Array.isArray(lesson.scenes) || !lesson.scenes.length) {
  throw new Error('Matematika media loyihasining asosiy ma’lumotlari noto‘g‘ri.');
}

let cursor = 0;
for (const scene of lesson.scenes) {
  if (scene.start !== cursor || !Number.isInteger(scene.end) || scene.end <= scene.start ||
      !hasText(scene.narration) || !hasText(scene.visual) || scene.narration.includes('-->')) {
    throw new Error('Storyboarddagi vaqt yoki matn noto‘g‘ri.');
  }
  cursor = scene.end;
}
if (cursor !== lesson.durationSeconds) throw new Error('Sahna va video davomiyligi mos kelmadi.');

const vttTime = (seconds) => new Date(seconds * 1000).toISOString().slice(11, 23);
const captions = lesson.scenes.map(({ start, end, narration }) =>
  `${vttTime(start)} --> ${vttTime(end)}\n${narration}`
);
await mkdir(output, { recursive: true });
await Promise.all([
  writeFile(new URL('addition.uz.vtt', output), 'WEBVTT\n\n' + captions.join('\n\n') + '\n'),
  writeFile(new URL('addition.uz.txt', output), lesson.scenes.map((scene) => scene.narration).join('\n\n') + '\n'),
]);
console.log(`${lesson.durationSeconds} soniyali loyiha uchun WebVTT va ovoz matni artifacts/math-pilot/media/ ichida tayyorlandi.`);
