#!/usr/bin/env node
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const command = (args[0] || '').toLowerCase(); // start | stop | status
const hostIp = args[1] || '127.0.0.1';
const hostPort = args[2] || '3490';
const outputFile = args[3] || 'capture.dlt';
let captureIdArg = args[4] || 'default';
const dltBin = process.env.DLT_RECEIVE_BIN || 'dlt-receive';
if ((command === 'stop' || command === 'status') && args[4] === undefined && args[1]) {
  // allow shorthand: node dlt-capture.js stop IDCEVO
  captureIdArg = args[1];
}
const captureId = String(captureIdArg).replace(/[^a-zA-Z0-9_-]/g, '_');

const stateDir = path.join(__dirname, '.dlt');
const pidFile = path.join(stateDir, `dlt_capture_${captureId}.pid`);
const metaFile = path.join(stateDir, `dlt_capture_${captureId}.meta.json`);
const logFile = path.join(stateDir, `dlt_capture_${captureId}.log`);

function ensureStateDir() {
  if (!fs.existsSync(stateDir)) fs.mkdirSync(stateDir, { recursive: true });
}

function isRunning(pid) {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

function readPid() {
  if (!fs.existsSync(pidFile)) return null;
  const raw = fs.readFileSync(pidFile, 'utf8').trim();
  const pid = parseInt(raw, 10);
  return Number.isFinite(pid) ? pid : null;
}

function startCapture(ip, port, outFile) {
  ensureStateDir();

  const existingPid = readPid();
  if (existingPid && isRunning(existingPid)) {
    console.log(`Error: capture '${captureId}' already running (PID: ${existingPid})`);
    return 1;
  }

  if (existingPid && !isRunning(existingPid)) {
    try { fs.unlinkSync(pidFile); } catch {}
  }

  const absOut = path.isAbsolute(outFile) ? outFile : path.join(process.cwd(), outFile);
  const absDir = path.dirname(absOut);
  if (!fs.existsSync(absDir)) fs.mkdirSync(absDir, { recursive: true });

  console.log(`[${captureId}] Starting DLT capture from ${ip}:${port}`);
  console.log(`[${captureId}] Output: ${absOut}`);

  const spawnCwd = path.isAbsolute(dltBin) ? path.dirname(dltBin) : process.cwd();
  const logFd = fs.openSync(logFile, 'a');
  fs.appendFileSync(logFile, `\n[${new Date().toISOString()}] START ${dltBin} -p ${port} -o ${absOut} ${ip}\n`);

  const dltProcess = spawn(dltBin, ['-p', String(port), '-o', absOut, ip], {
    detached: true,
    stdio: ['ignore', logFd, logFd],
    windowsHide: true,
    cwd: spawnCwd,
  });

  if (!dltProcess.pid) {
    console.error(`[${captureId}] Failed to start '${dltBin}' (PID undefined). Install dlt-receive or set DLT_RECEIVE_BIN to full executable path.`);
    return 1;
  }

  fs.writeFileSync(pidFile, String(dltProcess.pid));
  fs.writeFileSync(metaFile, JSON.stringify({
    id: captureId,
    pid: dltProcess.pid,
    ip,
    port,
    output: absOut,
    log: logFile,
    startedAt: new Date().toISOString(),
  }, null, 2));

  dltProcess.unref();
  try { fs.closeSync(logFd); } catch {}
  console.log(`[${captureId}] Capture started (PID: ${dltProcess.pid})`);
  return 0;
}

function stopCapture() {
  const pid = readPid();
  if (!pid) {
    console.log(`[${captureId}] No active capture found.`);
    return 0;
  }

  try {
    process.kill(pid, 'SIGTERM');
  } catch (err) {
    try {
      spawn('taskkill', ['/PID', String(pid), '/T', '/F'], { stdio: 'ignore', windowsHide: true });
    } catch {}

    if (err.code !== 'ESRCH') {
      console.error(`[${captureId}] Error stopping process ${pid}: ${err.message}`);
      return 1;
    }
  }

  try { fs.unlinkSync(pidFile); } catch {}
  try { fs.unlinkSync(metaFile); } catch {}

  console.log(`[${captureId}] Capture stopped (PID: ${pid}).`);
  return 0;
}

function statusCapture() {
  const pid = readPid();
  const meta = fs.existsSync(metaFile) ? JSON.parse(fs.readFileSync(metaFile, 'utf8')) : null;
  if (!pid) {
    console.log(`[${captureId}] Status: stopped`);
    if (fs.existsSync(logFile)) {
      const lines = fs.readFileSync(logFile, 'utf8').split(/\r?\n/).filter(Boolean);
      const tail = lines.slice(-8).join('\n');
      if (tail) console.log(`[${captureId}] Last log:\n${tail}`);
    }
    return 0;
  }
  console.log(`[${captureId}] Status: ${isRunning(pid) ? 'running' : 'stale'}`);
  console.log(`[${captureId}] PID: ${pid}`);
  if (meta) console.log(`[${captureId}] Meta: ${JSON.stringify(meta)}`);
  return 0;
}

let code = 0;
if (command === 'start') {
  code = startCapture(hostIp, hostPort, outputFile);
} else if (command === 'stop') {
  code = stopCapture();
} else if (command === 'status') {
  code = statusCapture();
} else {
  console.log('Usage: node scripts/dlt-capture.js {start|stop|status} [IP] [PORT] [OUTPUT_FILE] [CAPTURE_ID]');
  code = 1;
}

process.exit(code);
