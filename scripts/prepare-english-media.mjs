import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { chromium } from 'playwright';

const rootDir = process.cwd();
const rawArgs = process.argv.slice(2);
const args = new Set(rawArgs);
const skipAudio = args.has('--skip-audio');
const skipImage = args.has('--skip-image');

function resolveManifestPaths() {
  if (args.has('--all')) {
    const ordered = [
      'starter-media.json',
      'a1-media.json',
      'a2-media.json',
      'b1-media.json',
      'placement-media.json',
    ];
    return ordered
      .map((name) => path.join(rootDir, 'content', 'english', name))
      .filter((p) => fs.existsSync(p));
  }
  const idx = rawArgs.indexOf('--manifest');
  if (idx !== -1 && rawArgs[idx + 1]) {
    const resolved = path.resolve(rootDir, rawArgs[idx + 1]);
    if (!fs.existsSync(resolved)) {
      throw new Error(`Manifest file not found: ${resolved}`);
    }
    return [resolved];
  }
  return [path.join(rootDir, 'content', 'english', 'starter-media.json')];
}

const SILENCE_THRESHOLD = 16;

function parseWavePcm(buffer, expectedRate, expectedChannels, expectedBits) {
  if (buffer.length < 12) {
    throw new Error('WAV buffer too short (< 12 bytes)');
  }
  const riff = buffer.toString('ascii', 0, 4);
  const wave = buffer.toString('ascii', 8, 12);
  if (riff !== 'RIFF' || wave !== 'WAVE') {
    throw new Error(`Invalid RIFF/WAVE header: ${riff}/${wave}`);
  }

  let fmtParsed = null;
  let dataBuffer = null;
  let offset = 12;

  while (offset + 8 <= buffer.length) {
    const chunkId = buffer.toString('ascii', offset, offset + 4);
    const chunkSize = buffer.readUInt32LE(offset + 4);
    const dataStart = offset + 8;
    const dataEnd = dataStart + chunkSize;

    if (dataEnd > buffer.length) {
      throw new Error(`Truncated WAV chunk '${chunkId}' at offset ${offset}`);
    }

    if (chunkId === 'fmt ') {
      if (chunkSize < 16) {
        throw new Error(`Invalid fmt chunk size: ${chunkSize}`);
      }
      const audioFormat = buffer.readUInt16LE(dataStart);
      const numChannels = buffer.readUInt16LE(dataStart + 2);
      const sampleRate = buffer.readUInt32LE(dataStart + 4);
      const bitsPerSample = buffer.readUInt16LE(dataStart + 14);
      fmtParsed = { audioFormat, numChannels, sampleRate, bitsPerSample };
    } else if (chunkId === 'data') {
      dataBuffer = buffer.subarray(dataStart, dataEnd);
    }

    offset = dataEnd + (chunkSize % 2);
  }

  if (!fmtParsed) {
    throw new Error('Missing fmt chunk in WAV');
  }
  if (!dataBuffer) {
    throw new Error('Missing data chunk in WAV');
  }
  if (fmtParsed.audioFormat !== 1) {
    throw new Error(`Unsupported WAV format ${fmtParsed.audioFormat} (expected PCM = 1)`);
  }
  if (
    fmtParsed.numChannels !== expectedChannels ||
    fmtParsed.sampleRate !== expectedRate ||
    fmtParsed.bitsPerSample !== expectedBits
  ) {
    throw new Error(
      `Unexpected PCM format: ch=${fmtParsed.numChannels}, rate=${fmtParsed.sampleRate}, bits=${fmtParsed.bitsPerSample}`,
    );
  }

  const sampleCount = Math.floor(dataBuffer.length / 2);
  const samples = new Int16Array(sampleCount);
  for (let i = 0; i < sampleCount; i += 1) {
    samples[i] = dataBuffer.readInt16LE(i * 2);
  }
  return samples;
}

function trimSilence(samples, threshold = SILENCE_THRESHOLD) {
  let first = 0;
  while (first < samples.length && Math.abs(samples[first]) <= threshold) {
    first += 1;
  }
  let last = samples.length - 1;
  while (last >= first && Math.abs(samples[last]) <= threshold) {
    last -= 1;
  }
  if (first > last) {
    return new Int16Array(0);
  }
  return samples.subarray(first, last + 1);
}

function concatSegmentsWithSilence(segments, sampleRate, edgePaddingMs, pauseListMs) {
  const edgeFrames = Math.round((edgePaddingMs / 1000) * sampleRate);

  let totalFrames = edgeFrames * 2;
  for (let i = 0; i < segments.length; i += 1) {
    totalFrames += segments[i].length;
    if (i < segments.length - 1) {
      totalFrames += Math.round((pauseListMs[i] / 1000) * sampleRate);
    }
  }

  const combined = new Int16Array(totalFrames);
  let cursor = edgeFrames;
  for (let i = 0; i < segments.length; i += 1) {
    combined.set(segments[i], cursor);
    cursor += segments[i].length;
    if (i < segments.length - 1) {
      cursor += Math.round((pauseListMs[i] / 1000) * sampleRate);
    }
  }
  return combined;
}

function encodeCanonicalWave(samples, sampleRate, channels, bitsPerSample) {
  const byteRate = (sampleRate * channels * bitsPerSample) / 8;
  const blockAlign = (channels * bitsPerSample) / 8;
  const dataSize = samples.length * 2;
  const buffer = Buffer.alloc(44 + dataSize);

  buffer.write('RIFF', 0, 'ascii');
  buffer.writeUInt32LE(36 + dataSize, 4);
  buffer.write('WAVE', 8, 'ascii');
  buffer.write('fmt ', 12, 'ascii');
  buffer.writeUInt32LE(16, 16);
  buffer.writeUInt16LE(1, 20);
  buffer.writeUInt16LE(channels, 22);
  buffer.writeUInt32LE(sampleRate, 24);
  buffer.writeUInt32LE(byteRate, 28);
  buffer.writeUInt16LE(blockAlign, 32);
  buffer.writeUInt16LE(bitsPerSample, 34);
  buffer.write('data', 36, 'ascii');
  buffer.writeUInt32LE(dataSize, 40);

  for (let i = 0; i < samples.length; i += 1) {
    buffer.writeInt16LE(samples[i], 44 + i * 2);
  }
  return buffer;
}

function synthesizeAudio(manifest, webDir, flutterDir) {
  if (process.platform !== 'win32') {
    throw new Error('System.Speech TTS regeneration requires Windows (win32). Run with --skip-audio on non-Windows.');
  }

  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'bilimyol-english-tts-'));
  try {
    const jobs = [];
    for (const item of manifest.audio) {
      item.segments.forEach((seg, index) => {
        jobs.push({
          id: `${item.id}__${index}`,
          voice: seg.voice,
          rate: Number.isFinite(seg.rate) ? Math.trunc(seg.rate) : 0,
          text: seg.text,
          outPath: path.join(tmpDir, `${item.id}__${index}.wav`),
        });
      });
    }

    const jobsPath = path.join(tmpDir, 'jobs.json');
    const psScriptPath = path.join(tmpDir, 'synthesize.ps1');
    fs.writeFileSync(jobsPath, JSON.stringify(jobs, null, 2), 'utf8');

    const psScript = `
param([string]$JobsFile)
$ErrorActionPreference = 'Stop'
$gac = Get-ChildItem -Recurse 'C:\\Windows\\Microsoft.NET\\assembly\\GAC_MSIL\\System.Speech' -Filter 'System.Speech.dll' | Select-Object -First 1
if (-not $gac) { throw 'System.Speech.dll not found in Windows GAC.' }
Add-Type -Path $gac.FullName
$jobs = Get-Content -LiteralPath $JobsFile -Raw -Encoding UTF8 | ConvertFrom-Json
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
try {
  $installed = @{}
  foreach ($v in $synth.GetInstalledVoices()) {
    if ($v.Enabled) { $installed[$v.VoiceInfo.Name] = $true }
  }
  foreach ($job in $jobs) {
    if (-not $installed.ContainsKey($job.voice)) {
      throw "Required System.Speech voice not installed/enabled: $($job.voice)"
    }
    $synth.SelectVoice($job.voice)
    $synth.Rate = [int]$job.rate
    $synth.SetOutputToWaveFile($job.outPath)
    $synth.Speak($job.text)
    $synth.SetOutputToNull()
  }
} finally {
  $synth.Dispose()
}
`;
    fs.writeFileSync(psScriptPath, psScript, 'utf8');

    execFileSync(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', psScriptPath, '-JobsFile', jobsPath],
      { stdio: 'inherit' },
    );

    const bitsPerSample = manifest.sampleWidthBytes * 8;
    for (const item of manifest.audio) {
      const trimmedSegments = item.segments.map((_, index) => {
        const segPath = path.join(tmpDir, `${item.id}__${index}.wav`);
        const rawBuf = fs.readFileSync(segPath);
        const pcm = parseWavePcm(rawBuf, manifest.sampleRate, manifest.channels, bitsPerSample);
        const trimmed = trimSilence(pcm);
        if (trimmed.length === 0) {
          throw new Error(`Segment ${index} of ${item.id} produced empty speech`);
        }
        return trimmed;
      });

      const pauseListMs = item.segments.map((seg) => seg.pauseAfterMs ?? item.interTurnPauseMs ?? 400);
      if (item.segments.length >= 2) {
        for (let i = 0; i < item.segments.length - 1; i += 1) {
          if (pauseListMs[i] < 300) {
            throw new Error(
              `Multi-speaker item ${item.id} segment ${i} pause (${pauseListMs[i]}ms) must be >= 300ms`,
            );
          }
        }
      }
      const combined = concatSegmentsWithSilence(
        trimmedSegments,
        manifest.sampleRate,
        item.edgePaddingMs ?? 40,
        pauseListMs,
      );
      const outWave = encodeCanonicalWave(combined, manifest.sampleRate, manifest.channels, bitsPerSample);
      const webOut = path.join(webDir, item.filename);
      const flutterOut = path.join(flutterDir, item.filename);

      fs.writeFileSync(webOut, outWave);
      fs.writeFileSync(flutterOut, outWave);

      item.durationSeconds = Math.round((combined.length / manifest.sampleRate) * 1000) / 1000;
      console.log(
        `[audio] ${item.filename}: ${combined.length} frames, ${item.durationSeconds.toFixed(3)}s (${outWave.length} bytes)`,
      );
    }
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
}

async function rasterizeImages(manifest, webDir, flutterDir) {
  const svgBaseDir = manifest.svgSourceDir
    ? path.join(rootDir, manifest.svgSourceDir)
    : path.join(rootDir, 'content', 'english');
  const copySvgToWeb = manifest.copySvgToWeb !== false;

  const browser = await chromium.launch({ headless: true });
  try {
    for (const img of manifest.images) {
      const svgSourcePath = path.join(svgBaseDir, img.svgFilename);
      const svgMarkup = fs.readFileSync(svgSourcePath, 'utf8');

      if (/<(text|tspan|textPath)[\s>]/i.test(svgMarkup)) {
        throw new Error(`SVG contains forbidden <text>/<tspan>/<textPath> element: ${img.svgFilename}`);
      }

      const page = await browser.newPage({
        viewport: { width: img.width, height: img.height },
        deviceScaleFactor: 1,
      });
      await page.setContent(
        `<!DOCTYPE html><html><body style="margin:0;padding:0;overflow:hidden;background:#F8FAFC">${svgMarkup}</body></html>`,
      );
      const svgCount = await page.locator('svg').count();
      if (svgCount !== 1) {
        await page.close();
        throw new Error(`SVG ${img.svgFilename} must have exactly 1 <svg> root element (found ${svgCount})`);
      }
      const pngBuffer = await page.locator('svg').screenshot({ type: 'png' });
      await page.close();

      const webPngPath = path.join(webDir, img.filename);
      const flutterPngPath = path.join(flutterDir, img.filename);

      fs.writeFileSync(webPngPath, pngBuffer);
      fs.writeFileSync(flutterPngPath, pngBuffer);
      if (copySvgToWeb) {
        const webSvgPath = path.join(webDir, img.svgFilename);
        fs.writeFileSync(webSvgPath, svgMarkup, 'utf8');
      }

      console.log(`[image] ${img.filename}: ${img.width}x${img.height} (${pngBuffer.length} bytes)`);
    }
  } finally {
    await browser.close();
  }
}

async function main() {
  const manifestPaths = resolveManifestPaths();
  for (const manifestPath of manifestPaths) {
    const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    const webDir = path.join(rootDir, manifest.webOutputDir);
    const flutterDir = path.join(rootDir, manifest.flutterOutputDir);

    if (!skipAudio || !skipImage) {
      fs.mkdirSync(webDir, { recursive: true });
      fs.mkdirSync(flutterDir, { recursive: true });
    }

    if (!skipAudio && (manifest.audio?.length ?? 0) > 0) {
      synthesizeAudio(manifest, webDir, flutterDir);
    }
    if (!skipImage && (manifest.images?.length ?? 0) > 0) {
      await rasterizeImages(manifest, webDir, flutterDir);
    }

    if (!skipAudio || !skipImage) {
      fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
      console.log(`Updated manifest: ${path.relative(rootDir, manifestPath)}`);
    } else {
      console.log(`Skipped media & manifest write (read-only): ${path.relative(rootDir, manifestPath)}`);
    }
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
