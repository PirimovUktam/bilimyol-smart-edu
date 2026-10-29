/**
 * E2E runner for BilimYo'l Smart Edu.
 *
 * Builds a demo-mode bundle, serves it with `vite preview`, runs the core
 * learning-journey Playwright spec (`tests/e2e/journey.mjs`), then tears the
 * server down. Serving a prebuilt bundle (instead of a cold dev server) makes
 * the journey deterministic and fast in CI.
 *
 * If a server already answers at BASE_URL it is reused as-is.
 *
 * Usage:
 *   npm run test:e2e
 *   E2E_PORT=5200 npm run test:e2e
 */

import { spawn } from 'node:child_process';
import process from 'node:process';

const PORT = process.env.E2E_PORT || '5199';
const BASE_URL = process.env.BASE_URL || `http://localhost:${PORT}`;
const OUT_DIR = process.env.E2E_OUT_DIR || 'dist-e2e';
const isWin = process.platform === 'win32';

const isUp = async () => {
  try {
    const res = await fetch(BASE_URL);
    return res.ok;
  } catch {
    return false;
  }
};

let server = null;

if (!(await isUp())) {
  const command =
    `npx vite build --mode e2e-offline --outDir ${OUT_DIR}` +
    ` && npx vite preview --mode e2e-offline --outDir ${OUT_DIR} --port ${PORT} --strictPort`;
  server = spawn(command, { stdio: ['ignore', 'ignore', 'inherit'], shell: true });
}

const waitForServer = async (timeoutMs = 120000) => {
  const startedAt = Date.now();
  while (Date.now() - startedAt < timeoutMs) {
    if (await isUp()) return true;
    if (server && server.exitCode !== null) return false; // build/server failed
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  return false;
};

const shutdown = () =>
  new Promise((resolve) => {
    if (!server || server.exitCode !== null || server.killed) {
      resolve();
      return;
    }
    if (isWin) {
      const killer = spawn('taskkill', ['/pid', String(server.pid), '/t', '/f'], { stdio: 'ignore' });
      killer.on('exit', () => resolve());
      killer.on('error', () => resolve());
    } else {
      server.kill('SIGTERM');
      server.on('exit', () => resolve());
      setTimeout(resolve, 3000);
    }
  });

let exitCode = 1;
try {
  const ready = await waitForServer();
  if (!ready) {
    console.error(`[e2e] preview server did not become ready at ${BASE_URL}`);
    exitCode = 1;
  } else {
    const journey = spawn(process.execPath, ['tests/e2e/journey.mjs'], {
      stdio: 'inherit',
      env: { ...process.env, BASE_URL },
    });
    exitCode = await new Promise((resolve) => journey.on('exit', (code) => resolve(code ?? 1)));
  }
} finally {
  await shutdown();
}

process.exit(exitCode);
