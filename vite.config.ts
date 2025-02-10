import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
import { globbySync } from 'globby';
export default defineConfig({
  build: {
    rollupOptions: {
      input: ['index.html', 'facility.html', 'practice.html', 'delete.html', 'eula.html', 'children.html']
    },
    minify: true,
    sourcemap: false
  },
  esbuild: {
    drop: ['console', 'debugger'],
    target: 'es2015',
    legalComments: 'none'
  },
  plugins: [vue()],
  server: {
    port: 5100
  }
});
