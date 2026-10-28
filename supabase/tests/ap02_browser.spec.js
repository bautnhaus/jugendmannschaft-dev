import { test, expect } from '@playwright/test';

test('AP02 preview: login screen renders and empty login is rejected locally', async ({ page }) => {
  const pageErrors = [];
  page.on('pageerror', error => pageErrors.push(error.message));

  await page.goto('http://127.0.0.1:4173/index.html', { waitUntil: 'domcontentloaded' });

  await expect(page.locator('#loginView')).toBeVisible();
  await expect(page.locator('#loginEmail')).toBeVisible();
  await expect(page.locator('#loginPassword')).toBeVisible();

  // Do not submit credentials or modify Supabase data. Empty input should be
  // rejected locally before a network authentication request is made.
  await page.evaluate(() => window.login());
  await expect(page.locator('#loginMsg')).toContainText('Bitte E-Mail und Passwort eingeben.');

  expect(pageErrors, 'Unexpected uncaught browser errors').toEqual([]);
});
