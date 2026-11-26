import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { fileURLToPath, URL } from 'url'

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    tailwindcss(),
    react()
  ],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url))
    }
  },
  build: {
    rolldownOptions: {
      output: {
        codeSplitting: {
          groups: [
            { name: 'vendor-react', test: /node_modules[\\/](react|react-dom|scheduler)[\\/]/, priority: 20 },
            { name: 'vendor-supabase', test: /node_modules[\\/]@supabase[\\/]/, priority: 15 },
            { name: 'vendor-motion', test: /node_modules[\\/]framer-motion[\\/]/, priority: 15 },
            { name: 'vendor-katex', test: /node_modules[\\/]katex[\\/]/, priority: 15 },
            { name: 'flashcards-meta', test: /src[\\/]data[\\/]datasources[\\/]english[\\/]flashcardSrsMeta\.ts/, priority: 18 },
            { name: 'flashcards-english-a1', test: /src[\\/]data[\\/]datasources[\\/]english[\\/]flashcardCatalog\.ts/, priority: 17 },
            { name: 'flashcards-english-a2b1', test: /src[\\/]data[\\/]datasources[\\/]english[\\/](flashcardCatalogA2B1|flashcards)\.ts/, priority: 16 },
            { name: 'demo-english-a1', test: /content[\\/]english[\\/]a1-curriculum\.json/, priority: 15 },
            { name: 'demo-english-a2', test: /content[\\/]english[\\/]a2-curriculum\.json/, priority: 15 },
            { name: 'demo-english-b1', test: /content[\\/]english[\\/]b1-curriculum\.json/, priority: 15 },
          ],
        },
      },
    },
  },
  test: {
    globals: true,
    environment: 'node',
    setupFiles: ['./src/test/setup.ts'],
    testTimeout: 15000,
    // Local snapshots and worktree copies are not part of this test suite.
    exclude: ['**/node_modules/**', '**/dist/**', 'artifacts/**', '.claude/**', '**/.claude/**', '.agents/**', '**/.agents/**']
  }
})
