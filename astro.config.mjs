import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://openclaw.ai',
  output: 'static',
  build: {
    assets: 'assets'
  }
});
