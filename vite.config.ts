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
  test: {
    globals: true,
    environment: 'node',
    // Ignore gitignored worktree copies (.claude/**) so counts reflect real tests only
    exclude: ['**/node_modules/**', '**/dist/**', '.claude/**', '**/.claude/**']
  }
})
