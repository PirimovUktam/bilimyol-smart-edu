import { spawn } from 'node:child_process';
import { once } from 'node:events';

const port = Number(process.env.E2E_PORT ?? '5199');
if (!Number.isInteger(port) || port < 1024 || port > 65535) throw new Error('Invalid E2E_PORT.');
process.env.VITE_SUPABASE_URL = '';
process.env.VITE_SUPABASE_ANON_KEY = '';
const { build, preview } = await import('vite');
const host = '127.0.0.1';
const outDir = 'dist-e2e';
const mode = 'e2e-offline';
await build({ mode, build: { outDir } });
const server = await preview({ mode, build: { outDir }, preview: { host, port, strictPort: true } });
try {
  const run = spawn(process.execPath, ['tests/e2e/journey.mjs'], {
    stdio: 'inherit',
    env: { ...process.env, BASE_URL: 'http://' + host + ':' + port },
  });
  const [exit] = await once(run, 'exit');
  process.exitCode = exit ?? 1;
} finally {
  server.httpServer.closeAllConnections?.();
  await new Promise((resolve) => server.httpServer.close(resolve));
}
