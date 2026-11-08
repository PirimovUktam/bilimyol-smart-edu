// Isolated UI regression: all auth responses are test fixtures, never production responses.
import assert from 'node:assert/strict';
import { chromium } from 'playwright';

const app = new URL(process.env.E2E_APP_URL || 'http://127.0.0.1:5198');
assert(['localhost', '127.0.0.1'].includes(app.hostname), 'Only a local test server is allowed');
const browser = await chromium.launch({ headless: true });
const page = await browser.newPage();
let scenario = 'login';
let resendRequests = 0;
const json = (route, status, body) => route.fulfill({ status, contentType: 'application/json', headers: { 'x-supabase-api-version': '2024-01-01', 'access-control-expose-headers': 'x-supabase-api-version' }, body: JSON.stringify(body) });
await page.route('https://fonts.googleapis.com/**', route => route.abort());
await page.route('https://fonts.gstatic.com/**', route => route.abort());
await page.route('**/*.supabase.co/**', async route => {
  const path = new URL(route.request().url()).pathname;
  if (path.endsWith('/token')) return json(route, 400, { code: 'email_not_confirmed', msg: 'Email not confirmed' });
  if (path.endsWith('/resend')) { resendRequests++; return json(route, 429, { code: 'over_email_send_rate_limit', msg: 'email rate limit exceeded' }); }
  if (path.endsWith('/signup')) {
    if (scenario === 'signup-error') return json(route, 429, { code: 'over_email_send_rate_limit', msg: 'email rate limit exceeded' });
    return json(route, 200, { id: '00000000-0000-4000-8000-000000000001', aud: 'authenticated', email: 'qa@example.invalid', identities: [], app_metadata: {}, user_metadata: {}, created_at: new Date().toISOString() });
  }
  return json(route, 200, []);
});
const button = text => page.getByRole('button', { name: text, exact: true });
try {
  await page.goto(app.href, { waitUntil: 'domcontentloaded' });
  await page.locator('input[type="email"]').fill('qa@example.invalid');
  await page.locator('input[type="password"]').fill('test-fixture-only');
  await button('Kirish').click();
  await page.getByText(/Emailingiz hali tasdiqlanmagan/).waitFor();
  assert.equal(await page.locator('input[type="email"]').inputValue(), 'qa@example.invalid');
  await button('Tasdiqlash xatini qayta so‘rash').click();
  await page.getByText(/Hozir xat yuborilmadi/).waitFor();
  assert.equal(resendRequests, 1);
  assert(await page.getByRole('button', { name: /Qayta so‘rash:/ }).isDisabled());
  console.log('PASS login error survives loading; resend failure is shown with cooldown');

  scenario = 'signup-error';
  await button('Ro‘yxatdan o‘tish').click();
  const inputs = page.locator('form input');
  await inputs.nth(0).fill('QA');
  await inputs.nth(1).fill('Test');
  await page.locator('input[type="email"]').fill('qa@example.invalid');
  await page.locator('input[type="password"]').nth(0).fill('test-fixture-only');
  await page.locator('input[type="password"]').nth(1).fill('test-fixture-only');
  await button('Ro‘yxatdan o‘tish').click();
  await page.getByText(/Hozir xat yuborilmadi/).waitFor();
  assert.equal(await inputs.nth(0).inputValue(), 'QA');
  assert.equal(await page.locator('input[type="email"]').inputValue(), 'qa@example.invalid');
  console.log('PASS signup delivery failure retains form values and shows no success');

  scenario = 'signup-confirmation';
  await button('Ro‘yxatdan o‘tish').click();
  await button('Tasdiqlash xatini qayta so‘rash').waitFor();
  await page.getByText('qa@example.invalid', { exact: true }).waitFor();
  assert.equal(await page.locator('input[type="password"]').count(), 0);
  console.log('PASS pending email confirmation survives auth loading and offers resend');
} catch (error) {
  console.error(await page.locator('body').innerText());
  throw error;
} finally { await browser.close(); }
