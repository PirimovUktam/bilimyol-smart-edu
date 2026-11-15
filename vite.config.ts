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
          ],
        },
      },
    },
  },
  test: {
    globals: true,
    environment: 'node',
    // Local snapshots and worktree copies are not part of this test suite.
    exclude: ['**/node_modules/**', '**/dist/**', 'artifacts/**', '.claude/**', '**/.claude/**']
  }
})
