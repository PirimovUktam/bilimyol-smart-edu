import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import * as supabaseConfig from '../core/config/supabase';

const repoRoot = path.resolve(import.meta.dirname, '../..');

function readRepoFile(relativePath: string): string {
  const fullPath = path.join(repoRoot, relativePath);
  if (!fs.existsSync(fullPath)) {
    throw new Error(`Missing required file: ${relativePath}`);
  }
  return fs.readFileSync(fullPath, 'utf8');
}

function stripKotlinComments(source: string): string {
  return source
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/\/\/.*$/gm, '');
}

function makeFakeJwt(payload: Record<string, unknown>): string {
  const encode = (obj: Record<string, unknown>) =>
    Buffer.from(JSON.stringify(obj)).toString('base64url');
  return `${encode({ alg: 'HS256', typ: 'JWT' })}.${encode(payload)}.signature`;
}

function extractYamlJobBlock(ciSource: string, jobName: string): string {
  const lines = ciSource.split(/\r?\n/);
  const headerPattern = new RegExp(`^  ${jobName}:\\s*$`);
  const startIndex = lines.findIndex((line) => headerPattern.test(line));
  if (startIndex === -1) {
    return '';
  }
  const collected: string[] = [lines[startIndex]];
  for (let i = startIndex + 1; i < lines.length; i++) {
    const line = lines[i];
    if (/^  [a-zA-Z0-9_-]+:\s*$/.test(line)) {
      break;
    }
    collected.push(line);
  }
  return collected.join('\n');
}

describe('W0-B4 FIX-P0-26: CI workflow hardening & job separation', () => {
  const ci = readRepoFile('.github/workflows/ci.yml');

  it('sets least-privilege top-level permissions and concurrency cancellation', () => {
    expect(ci).toMatch(/^permissions:\s*\r?\n\s+contents:\s*read\b/m);
    expect(ci).toMatch(/^concurrency:\s*\r?\n\s+group:/m);
    expect(ci).toMatch(/cancel-in-progress:\s*true/);
  });

  it('runs secret-free mobile-test with lockfile enforcement and strict analyze without building release APKs', () => {
    const mobileTestJob = extractYamlJobBlock(ci, 'mobile-test');
    expect(mobileTestJob).not.toBe('');
    expect(mobileTestJob).toContain('flutter pub get --enforce-lockfile');
    expect(mobileTestJob).toContain('flutter analyze --fatal-infos');
    expect(mobileTestJob).toContain('flutter test');
    expect(mobileTestJob).not.toContain('flutter build apk --release');
    expect(mobileTestJob).not.toContain('upload-artifact');
    expect(mobileTestJob).not.toContain('ANDROID_KEYSTORE_BASE64');
  });

  it('gates mobile-release away from fork PRs, uses $RUNNER_TEMP with always() cleanup, passes --dart-define-from-file & --obfuscate, and verifies non-debug cert', () => {
    const mobileReleaseJob = extractYamlJobBlock(ci, 'mobile-release');
    expect(mobileReleaseJob).not.toBe('');
    expect(mobileReleaseJob).toMatch(/github\.event_name\s*!=\s*['"]pull_request['"]/);
    expect(mobileReleaseJob).toContain('ANDROID_KEYSTORE_BASE64');
    expect(mobileReleaseJob).toContain('ANDROID_KEYSTORE_PASSWORD');
    expect(mobileReleaseJob).toContain('ANDROID_KEY_ALIAS');
    expect(mobileReleaseJob).toContain('ANDROID_KEY_PASSWORD');
    expect(mobileReleaseJob).toContain('RUNNER_TEMP');
    expect(mobileReleaseJob).toContain('if: always()');
    expect(mobileReleaseJob).toContain('--dart-define-from-file=');
    expect(mobileReleaseJob).toContain('--obfuscate');
    expect(mobileReleaseJob).toContain('--split-debug-info=');
    expect(mobileReleaseJob).toContain('APP_ENV');
    expect(mobileReleaseJob).toMatch(/apksigner|keytool/);
    expect(mobileReleaseJob).toContain('Android Debug');
    expect(mobileReleaseJob).not.toContain('SUPABASE_SERVICE_ROLE');
    expect(mobileReleaseJob).toMatch(/tr\s+['"]\[:upper:\]['"]\s+['"]\[:lower:\]['"]|nocasematch/);
    expect(mobileReleaseJob).toContain('sb_secret_');
    expect(mobileReleaseJob).toContain('service_role');
    expect(mobileReleaseJob).toMatch(/\.role\b/);
    expect(mobileReleaseJob).toMatch(/github\.event_name\s*==\s*['"]push['"]/);
    expect(mobileReleaseJob).toMatch(/github\.ref\s*==\s*['"]refs\/heads\/main['"]/);
  });
});

describe('W0-B4 FIX-P0-26: Android Gradle release signing & R8 ProGuard hardening', () => {
  it('never signs release with debug keystore, enables R8 shrinking, references proguard-rules.pro, and fails closed when credentials are missing', () => {
    const gradle = readRepoFile('mobile/android/app/build.gradle.kts');
    const codeOnly = stripKotlinComments(gradle);

    expect(codeOnly).toContain('applicationId = "uz.bilimyol.mobile"');
    expect(codeOnly).toContain('namespace = "uz.bilimyol.bilimyol_mobile"');
    expect(codeOnly).not.toMatch(/signingConfig\s*=\s*signingConfigs\.getByName\(["']debug["']\)/);
    expect(codeOnly).toMatch(/isMinifyEnabled\s*=\s*true/);
    expect(codeOnly).toMatch(/isShrinkResources\s*=\s*true/);
    expect(codeOnly).toContain('proguard-rules.pro');
    expect(codeOnly).toContain('BLOCKED — RELEASE SIGNING CREDENTIALS MISSING');
    expect(codeOnly).toContain('keyPropertiesFile.parentFile');

    const regexMatch = codeOnly.match(/val\s+releaseTaskRegex\s*=\s*Regex\(\s*"([^"]+)"\s*\)/);
    expect(regexMatch).not.toBeNull();
    const releaseTaskRegex = new RegExp(regexMatch![1].replace(/\\\\/g, '\\'));
    for (const taskName of [
      'assembleRelease',
      'bundleRelease',
      'minifyReleaseWithR8',
      'signReleaseBundle',
      'packageReleaseBundle',
      'packageReleaseUniversalApk',
      'validateSigningRelease',
      'validateSigningFlavorRelease',
    ]) {
      expect(releaseTaskRegex.test(taskName), `expected releaseTaskRegex to match ${taskName}`).toBe(true);
    }
    for (const allowedTask of ['assembleDebug', 'testDebugUnitTest', 'testReleaseUnitTest']) {
      expect(releaseTaskRegex.test(allowedTask), `expected releaseTaskRegex NOT to match ${allowedTask}`).toBe(false);
    }
  });

  it('ships proguard-rules.pro with keep rules for Flutter, just_audio/Media3, flutter_secure_storage/Tink, app_links, and shared_preferences', () => {
    const proguard = readRepoFile('mobile/android/app/proguard-rules.pro');

    for (const requiredRule of [
      'io.flutter.**',
      'com.ryanheise.just_audio.**',
      'com.ryanheise.audio_session.**',
      'androidx.media3.**',
      'com.it_nomads.fluttersecurestorage.**',
      'com.google.crypto.tink.**',
      'com.llfbandit.app_links.**',
      'io.flutter.plugins.sharedpreferences.**',
    ]) {
      expect(proguard, `missing ProGuard rule for ${requiredRule}`).toContain(requiredRule);
    }
  });
});

describe('W0-B4 FIX-P0-26: Web Supabase client rejects service_role credentials', () => {
  it('exports isServiceRoleKey and rejects sb_secret_ keys and service_role JWTs while allowing anon JWTs', () => {
    const maybeFn = (supabaseConfig as Record<string, unknown>).isServiceRoleKey;
    expect(typeof maybeFn).toBe('function');

    const isServiceRoleKey = maybeFn as (rawKey: string) => boolean;
    const serviceRoleJwt = makeFakeJwt({ role: 'service_role', iss: 'supabase' });
    const anonJwt = makeFakeJwt({ role: 'anon', iss: 'supabase' });

    expect(isServiceRoleKey('sb_secret_example_12345')).toBe(true);
    expect(isServiceRoleKey(serviceRoleJwt)).toBe(true);
    expect(isServiceRoleKey(anonJwt)).toBe(false);
    expect(isServiceRoleKey('sb_publishable_example_12345')).toBe(false);
    expect(isServiceRoleKey('')).toBe(false);
  });
});
