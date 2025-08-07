import { defineConfig } from 'vite'

// This is a placeholder config for a Docker container environment
// The actual application runs inside Ubuntu KDE WebTop container
export default defineConfig({
  server: {
    port: 3000,
    host: true
  },
  build: {
    outDir: 'dist'
  }
})