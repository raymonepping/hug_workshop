const { test, expect } = require('@playwright/test');
test('real Vault unlock, private path denial, and responsive viewer', async ({ page, request }) => {
  await page.goto('/'); await expect(page.locator('#state')).toHaveText('Vault unlocked');
  await expect(page.locator('#items tr')).toHaveCount(32);
  await expect(page.locator('#reveal')).toHaveText('WEARETHEGUARDIANSOFOUROWNSYSTEMS');
  for (const path of ['/frontend.js', '/package.json', '/.env', '/node_modules/express/package.json']) expect((await request.get(path)).status()).toBe(404);
  await page.locator('#api').fill('http://r'); await expect(page.locator('#api')).toHaveValue('http://r');
  await page.setViewportSize({ width: 390, height: 844 });
  await expect(page.locator('#refresh')).toBeVisible();
  await page.screenshot({ path: '../../.workshop/viewer-mobile.png', fullPage: true });
});
test('baseline is explicit; lock/error clears old data; all fields are escaped', async ({ page }) => {
  let state = { ok: true, dbReady: true, mode: 'required', channel: 'vault-kv', unlocked: true, state: 'ready' };
  await page.route('**/health', route => route.fulfill({ json: state }));
  await page.route('**/api/items?*', route => route.fulfill({ json: { items: [{ id: '<img src=x onerror="window.exposed=1">', idx: '<b>unsafe</b>', title: '<script>bad</script>' }] } }));
  await page.goto('/'); await expect(page.locator('#items tr')).toHaveCount(1);
  await expect(page.locator('#items img')).toHaveCount(0); await expect(page.locator('#items b')).toHaveCount(0);
  expect(await page.evaluate(() => window.exposed)).toBeUndefined();
  state = { ...state, mode: 'baseline', channel: 'env', unlocked: false, state: 'baseline' };
  await page.locator('#refresh').click(); await expect(page.locator('#state')).toHaveText('Baseline connected'); await expect(page.locator('#reveal')).toBeHidden();
  state = { ...state, mode: 'required', channel: 'vault-kv', unlocked: false, state: 'vault_denied' };
  await page.locator('#refresh').click(); await expect(page.locator('#state')).toHaveText('Vault access denied'); await expect(page.locator('#items tr')).toHaveCount(0);
  state = { ...state, dbReady: false, state: 'db_unavailable' }; await page.locator('#refresh').click(); await expect(page.locator('#state')).toHaveText('Database unavailable');
  await page.route('**/health', route => route.abort()); await page.locator('#refresh').click(); await expect(page.locator('#state')).toHaveText('API unavailable'); await expect(page.locator('#items tr')).toHaveCount(0);
});
