#!/usr/bin/env node
/**
 * Radio Regression Control Server (Host-side)
 * - Executes ADB commands on behalf of Maestro JS via HTTP.
 * - Writes evidence (dumpsys outputs + verdict JSON) under the run artifacts directory.
 *
 * No external deps. Windows-friendly.
 */
const http = require('http');
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

const HOST = process.env.MAESTRO_CONTROL_HOST || '127.0.0.1';
const PORT = parseInt(process.env.MAESTRO_CONTROL_PORT || '4567', 10);

// Resolve repo root from this file location: <repo>/scripts/control_server/server.js
const REPO_ROOT = path.resolve(__dirname, '..', '..');
const ADB_BAT = path.join(REPO_ROOT, 'scripts', 'adb.bat');

function nowStamp() {
  const d = new Date();
  const pad = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}${pad(d.getMonth()+1)}${pad(d.getDate())}_${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`;
}

function safeMkdir(p) {
  fs.mkdirSync(p, { recursive: true });
}

function writeFileIf(dir, name, content) {
  try {
    safeMkdir(dir);
    fs.writeFileSync(path.join(dir, name), content, { encoding: 'utf8' });
  } catch (e) {
    // best-effort; do not crash the server for logging failures
  }
}

function runAdb(args, timeoutMs = 25000) {
  return new Promise((resolve) => {
    // Prefer scripts/adb.bat (repo-local platform-tools), fallback to "adb" on PATH handled by adb.bat.
    const cmd = process.platform === 'win32' ? 'cmd.exe' : ADB_BAT;
    const cmdArgs = process.platform === 'win32'
      ? ['/c', ADB_BAT, ...args]
      : args;

    const child = spawn(cmd, cmdArgs, { cwd: REPO_ROOT, windowsHide: true });
    let stdout = '';
    let stderr = '';

    const killTimer = setTimeout(() => {
      try { child.kill('SIGKILL'); } catch (_) {}
    }, timeoutMs);

    child.stdout.on('data', (d) => { stdout += d.toString(); });
    child.stderr.on('data', (d) => { stderr += d.toString(); });

    child.on('close', (code) => {
      clearTimeout(killTimer);
      resolve({ code: code ?? 0, stdout, stderr });
    });
  });
}

function extractAudioPackages(dumpsysAudioText) {
  // dumpsys audio output often contains: "pack: com.example"
  const packs = [];
  const re = /pack:\s*([^\s]+)/g;
  let m;
  while ((m = re.exec(dumpsysAudioText)) !== null) {
    packs.push(m[1]);
  }
  // de-dup preserving order
  return [...new Set(packs)];
}

/**
 * Leandro-aligned parsing function concept:
 * Extracts session blocks for a given full_user from dumpsys media_session.
 * Returns an array of session block strings (best-effort).
 */
function func(dumpsysOutput, userId = -1) {
  const blocks = [];
  // Split by full_user stacks
  const stackRe = /Sessions Stack - full_user=(\d+)[\s\S]*?(?=Sessions Stack - full_user=|\Z)/g;
  let stack;
  while ((stack = stackRe.exec(dumpsysOutput)) !== null) {
    const uid = parseInt(stack[1], 10);
    const stackBody = stack[0];
    if (userId !== -1 && uid !== userId) continue;

    // Split stack into sessions (best-effort)
    const sessionRe = /(Session[^\n]*\n[\s\S]*?)(?=\nSession[^\n]*\n|\Z)/g;
    let s;
    let any = false;
    while ((s = sessionRe.exec(stackBody)) !== null) {
      any = true;
      blocks.push(s[1]);
    }
    if (!any) blocks.push(stackBody);
  }
  if (blocks.length === 0 && userId === -1) {
    // fallback: return whole output as a single block
    return [dumpsysOutput];
  }
  return blocks;
}

function analyzeMediaSession(dumpsysMediaSessionText, expectedPackage, userId) {
  const sessions = func(dumpsysMediaSessionText, userId);
  let pkgSeen = false;
  let activeSeen = false;
  let playingSeen = false;

  for (const s of sessions) {
    if (!s.includes(expectedPackage)) continue;
    pkgSeen = true;

    // Best-effort active detection
    if (/\bactive\s*=\s*true\b/i.test(s) || /\bisActive\s*=\s*true\b/i.test(s)) {
      activeSeen = true;
    }
    // Best-effort playing detection (Android PlaybackState.STATE_PLAYING == 3)
    if (/\bstate\s*=\s*3\b/.test(s) || /STATE_PLAYING/i.test(s) || /PlaybackState\s*\{[^\}]*state=3/i.test(s)) {
      playingSeen = true;
    }
    // Some builds omit explicit "active=true"; if we see playing, treat as active enough.
    if (playingSeen) activeSeen = true;
  }

  return {
    expectedPackage,
    pkgSeen,
    activeSeen,
    playingSeen,
    ok: pkgSeen && activeSeen && playingSeen
  };
}

async function handleRadioCheck(payload) {
  const deviceId = payload.deviceId || '';
  const pkg = payload.packageName || 'com.bmwgroup.apinext.tunermediaservice';
  const runDir = payload.runDir || '';
  const testId = payload.testId || 'unknown_test';
  const stamp = payload.stamp || nowStamp();

  const outDir = runDir
    ? path.join(runDir, 'backend', testId)
    : path.join(REPO_ROOT, 'artifacts', 'runs', stamp, 'backend', testId);

  // Collect dumps
  const audio = await runAdb(deviceId ? ['-s', deviceId, 'shell', 'dumpsys', 'audio'] : ['shell', 'dumpsys', 'audio']);
  const curUser = await runAdb(deviceId ? ['-s', deviceId, 'shell', 'am', 'get-current-user'] : ['shell', 'am', 'get-current-user']);
  const media = await runAdb(deviceId ? ['-s', deviceId, 'shell', 'dumpsys', 'media_session'] : ['shell', 'dumpsys', 'media_session']);

  writeFileIf(outDir, 'dumpsys_audio.txt', audio.stdout + (audio.stderr ? `\n\n[stderr]\n${audio.stderr}` : ''));
  writeFileIf(outDir, 'current_user.txt', curUser.stdout + (curUser.stderr ? `\n\n[stderr]\n${curUser.stderr}` : ''));
  writeFileIf(outDir, 'dumpsys_media_session.txt', media.stdout + (media.stderr ? `\n\n[stderr]\n${media.stderr}` : ''));

  const audioPacks = extractAudioPackages(audio.stdout);
  const hasFocus = audioPacks.includes(pkg);

  const userIdMatch = curUser.stdout.match(/(\d+)/);
  const userId = userIdMatch ? parseInt(userIdMatch[1], 10) : -1;

  const mediaAnalysis = analyzeMediaSession(media.stdout, pkg, userId);

  const verdict = {
    ok: Boolean(hasFocus && mediaAnalysis.ok),
    hasFocus,
    audioPackages: audioPacks,
    userId,
    mediaSession: mediaAnalysis,
    deviceId,
    stamp,
    outDir
  };

  writeFileIf(outDir, 'backend_verdict.json', JSON.stringify(verdict, null, 2));
  return verdict;
}

async function handleInject(payload, kind) {
  const deviceId = payload.deviceId || '';
  const runDir = payload.runDir || '';
  const testId = payload.testId || 'unknown_test';
  const stamp = payload.stamp || nowStamp();

  const outDir = runDir
    ? path.join(runDir, 'backend', testId)
    : path.join(REPO_ROOT, 'artifacts', 'runs', stamp, 'backend', testId);

  const target = payload.target || 'next'; // next|prev|mute|down|center (some are future)
  const results = [];

  const adbBase = deviceId ? ['-s', deviceId] : [];

  function push(res, label) {
    results.push({ label, code: res.code, stdout: res.stdout, stderr: res.stderr });
  }

  if (kind === 'swag') {
    // Leandro workaround: inject MFL_MEDIA (1014/1015) then keyevent media next/prev
    const r1 = await runAdb([...adbBase, 'shell', 'cmd', 'car_service', 'inject-custom-input', '-r', '0', '1014']);
    push(r1, 'inject-custom-input 1014');
    const r2 = await runAdb([...adbBase, 'shell', 'cmd', 'car_service', 'inject-custom-input', '-r', '0', '1015']);
    push(r2, 'inject-custom-input 1015');

    if (target === 'prev') {
      const r3 = await runAdb([...adbBase, 'shell', 'input', 'keyevent', 'KEYCODE_MEDIA_PREVIOUS']);
      push(r3, 'keyevent MEDIA_PREVIOUS');
    } else {
      const r3 = await runAdb([...adbBase, 'shell', 'input', 'keyevent', 'KEYCODE_MEDIA_NEXT']);
      push(r3, 'keyevent MEDIA_NEXT');
    }
  } else if (kind === 'bim') {
    // BIM hint: KEYCODE_MUTE then media next/prev
    const r0 = await runAdb([...adbBase, 'shell', 'input', 'keyevent', 'KEYCODE_MUTE']);
    push(r0, 'keyevent MUTE');

    // Then same workaround as SWAG
    const r1 = await runAdb([...adbBase, 'shell', 'cmd', 'car_service', 'inject-custom-input', '-r', '0', '1014']);
    push(r1, 'inject-custom-input 1014');
    const r2 = await runAdb([...adbBase, 'shell', 'cmd', 'car_service', 'inject-custom-input', '-r', '0', '1015']);
    push(r2, 'inject-custom-input 1015');

    if (target === 'prev') {
      const r3 = await runAdb([...adbBase, 'shell', 'input', 'keyevent', 'KEYCODE_MEDIA_PREVIOUS']);
      push(r3, 'keyevent MEDIA_PREVIOUS');
    } else {
      const r3 = await runAdb([...adbBase, 'shell', 'input', 'keyevent', 'KEYCODE_MEDIA_NEXT']);
      push(r3, 'keyevent MEDIA_NEXT');
    }
  } else if (kind === 'ehh') {
    const which = payload.which || 'cid'; // cid|phud
    const disabled = payload.disabled === true ? 'true' : 'false';
    const prop = which === 'phud'
      ? 'persist.vendor.com.bmwgroup.disable_phud_ehh'
      : 'persist.vendor.com.bmwgroup.disable_cid_ehh';
    const r = await runAdb([...adbBase, 'shell', 'setprop', prop, disabled]);
    push(r, `setprop ${prop} ${disabled}`);
  }

  // settle wait (host-side) to avoid flaky immediate verification
  await new Promise((r) => setTimeout(r, 900));

  const ok = results.every(r => (r.code ?? 0) === 0);

  writeFileIf(outDir, `action_${kind}_${target}.json`, JSON.stringify({ ok, kind, target, deviceId, stamp, results }, null, 2));
  return { ok, kind, target, deviceId, stamp, outDir };
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', (chunk) => { body += chunk.toString(); });
    req.on('end', () => {
      if (!body) return resolve({});
      try { resolve(JSON.parse(body)); } catch (e) { reject(e); }
    });
  });
}

function send(res, status, obj) {
  const data = JSON.stringify(obj);
  res.writeHead(status, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*'
  });
  res.end(data);
}

const server = http.createServer(async (req, res) => {
  // basic CORS
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type'
    });
    return res.end();
  }

  try {
    if (req.method === 'GET' && req.url === '/health') {
      return send(res, 200, { ok: true, host: HOST, port: PORT });
    }

    if (req.method === 'POST' && req.url === '/radio/check') {
      const payload = await readJson(req);
      const verdict = await handleRadioCheck(payload);
      return send(res, 200, verdict);
    }

    if (req.method === 'POST' && req.url === '/inject/swag') {
      const payload = await readJson(req);
      const r = await handleInject(payload, 'swag');
      return send(res, 200, r);
    }

    if (req.method === 'POST' && req.url === '/inject/bim') {
      const payload = await readJson(req);
      const r = await handleInject(payload, 'bim');
      return send(res, 200, r);
    }

    if (req.method === 'POST' && req.url === '/ehh/set') {
      const payload = await readJson(req);
      const r = await handleInject(payload, 'ehh');
      return send(res, 200, r);
    }

    return send(res, 404, { ok: false, error: 'not_found' });
  } catch (e) {
    return send(res, 500, { ok: false, error: String(e && e.message ? e.message : e) });
  }
});

server.listen(PORT, HOST, () => {
  // eslint-disable-next-line no-console
  console.log(`[radio-control-server] listening on http://${HOST}:${PORT}`);
  console.log(`[radio-control-server] repo root: ${REPO_ROOT}`);
});
