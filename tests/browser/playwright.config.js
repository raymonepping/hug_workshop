const { defineConfig } = require('@playwright/test');
module.exports = defineConfig({ testDir: '.', testMatch: '*.spec.js', workers: 1,
  use: { baseURL: process.env.WORKSHOP_FRONTEND || 'http://127.0.0.1:25173', headless: true },
  outputDir: '../../.workshop/browser-results', reporter: 'list' });
