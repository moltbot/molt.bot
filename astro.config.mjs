import { defineConfig } from 'astro/config';
import react from '@astrojs/react';

export default defineConfig({
  site: 'https://clawd.bot',
  output: 'static',
  build: {
    assets: 'assets'
  },
  integrations: [react()]
});
