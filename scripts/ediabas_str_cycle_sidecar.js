#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const DEFAULT_EDIABAS_BIN = 'C:\\EC-Apps\\EDIABAS\\BIN';
const DEFAULT_ECU = 'IPB_APP1';
const DEFAULT_JOB = 'STEUERN_ROUTINE';
const DEFAULT_ARG_PAD = 'ARG;ZUSTAND_FAHRZEUG;STR;0x07';
const DEFAULT_ARG_WOHNEN = 'ARG;ZUSTAND_FAHRZEUG;STR;0x05';
const DEFAULT_ARG_PARKING = 'ARG;ZUSTAND_FAHRZEUG;STR;0x01';

function timestampCompact() {
  const d = new Date();
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}_${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function appendJsonl(filePath, payload) {
  ensureDir(path.dirname(filePath));
  fs.appendFileSync(filePath, `${JSON.stringify(payload)}\n`, 'utf8');
}

function runProcess(cmd, args, timeoutSeconds) {
  return new Promise((resolve) => {
    const child = spawn(cmd, args, { windowsHide: true });
    let stdout = '';
    let stderr = '';
    let finished = false;

    const timer = setTimeout(() => {
      if (finished) return;
      try { child.kill('SIGKILL'); } catch (_) {}
    }, Math.max(1, timeoutSeconds) * 1000);

    child.stdout.on('data', (d) => { stdout += d.toString(); });
    child.stderr.on('data', (d) => { stderr += d.toString(); });

    child.on('close', (code) => {
      finished = true;
      clearTimeout(timer);
      resolve({ returncode: code == null ? 1 : code, stdout: stdout.trim(), stderr: stderr.trim() });
    });

    child.on('error', (err) => {
      finished = true;
      clearTimeout(timer);
      resolve({ returncode: 1, stdout: stdout.trim(), stderr: String(err && err.message ? err.message : err) });
    });
  });
}

function parseLastJson(text) {
  const lines = (text || '').split(/\r?\n/).map((s) => s.trim()).filter(Boolean);
  for (let i = lines.length - 1; i >= 0; i -= 1) {
    if (!lines[i].startsWith('{')) continue;
    try { return JSON.parse(lines[i]); } catch (_) { continue; }
  }
  return null;
}

async function runCliJob(opts) {
  const args = [
    opts.sidecarScript,
    'run-job',
    '--ecu', opts.ecu,
    '--job', opts.job,
    '--parameters', opts.parameters,
    '--result-filter', opts.resultFilter,
    '--config', opts.config,
    '--timeout-seconds', String(opts.timeoutSeconds),
  ];
  return runProcess(opts.sidecarPython, args, opts.timeoutSeconds + 10);
}

async function runHttpJob(opts) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), Math.max(1, opts.timeoutSeconds) * 1000);
  try {
    const response = await fetch(`${opts.sidecarUrl}/job`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        ecu: opts.ecu,
        job: opts.job,
        parameters: opts.parameters,
        result_filter: opts.resultFilter,
        config: opts.config,
        timeout_seconds: opts.timeoutSeconds,
      }),
      signal: ctrl.signal,
    });

    const text = await response.text();
    return {
      returncode: response.ok ? 0 : 1,
      stdout: text,
      stderr: '',
    };
  } catch (err) {
    return {
      returncode: 1,
      stdout: '',
      stderr: String(err && err.message ? err.message : err),
    };
  } finally {
    clearTimeout(timer);
  }
}

async function runSidecarJob(opts) {
  if (opts.sidecarMode === 'http') return runHttpJob(opts);
  if (opts.sidecarMode === 'cli') return runCliJob(opts);

  const httpTry = await runHttpJob(opts);
  if (httpTry.returncode === 0) return httpTry;
  return runCliJob(opts);
}

async function runActionWithRetries(opts) {
  let last = null;
  for (let attempt = 1; attempt <= opts.retries + 1; attempt += 1) {
    const logFile = path.join(opts.outputDir, `${Math.floor(Date.now() / 1000)}_${opts.state}_attempt${attempt}.log`);
    const started = Date.now() / 1000;
    const callResult = await runSidecarJob(opts);
    const ended = Date.now() / 1000;
    const parsed = parseLastJson(callResult.stdout);

    let text = `$ sidecar_mode=${opts.sidecarMode}\n`;
    text += `$ ecu=${opts.ecu} job=${opts.job} params=${opts.parameters}\n\n`;
    if (callResult.stdout) text += `[stdout]\n${callResult.stdout}\n`;
    if (callResult.stderr) text += `[stderr]\n${callResult.stderr}\n`;
    text += `\n[exit_code]=${callResult.returncode}\n`;
    fs.writeFileSync(logFile, text, 'utf8');

    const row = {
      state: opts.state,
      ecu: opts.ecu,
      job: opts.job,
      job_param: opts.parameters,
      returncode: callResult.returncode,
      log_file: logFile,
      started_at: started,
      ended_at: ended,
      attempt,
      engine: 'pydiabas-sidecar',
      sidecar_mode: opts.sidecarMode,
      sidecar_result: parsed,
      stdout: callResult.stdout,
      stderr: callResult.stderr,
    };
    appendJsonl(opts.auditJsonl, row);
    last = row;

    if (callResult.returncode === 0) return row;
    if (attempt < opts.retries + 1) await sleep(1000);
  }
  return last;
}

async function diagnose(opts) {
  ensureDir(opts.outputDir);
  const report = path.join(opts.outputDir, 'diagnose_report.txt');
  const lines = [];
  lines.push('EDIABAS PYDIABAS SIDECAR DIAGNOSE REPORT');
  lines.push(`timestamp=${new Date().toISOString().replace('T', ' ').slice(0, 19)}`);
  lines.push(`sidecar_mode=${opts.sidecarMode}`);
  lines.push(`sidecar_python=${opts.sidecarPython}`);
  lines.push(`sidecar_script=${opts.sidecarScript}`);
  lines.push(`sidecar_url=${opts.sidecarUrl}`);
  lines.push(`node_arch=${process.arch}`);

  if (opts.probe) {
    const probe = await runSidecarJob({
      ...opts,
      ecu: opts.probeEcu,
      job: opts.probeJob,
      parameters: opts.probeParam,
    });
    const parsed = parseLastJson(probe.stdout);
    lines.push(`probe_ecu=${opts.probeEcu}`);
    lines.push(`probe_job=${opts.probeJob}`);
    lines.push(`probe_rc=${probe.returncode}`);
    lines.push(`probe_ok=${parsed && parsed.ok === true}`);
    lines.push(`probe_error=${parsed && parsed.error ? parsed.error : ''}`);

    const probeLog = path.join(opts.outputDir, 'diagnose_probe.log');
    fs.writeFileSync(probeLog, `${probe.stdout}\n${probe.stderr}\n`, 'utf8');
    lines.push(`probe_log=${probeLog}`);

    fs.writeFileSync(report, `${lines.join('\n')}\n`, 'utf8');
    console.log(`OK: Diagnose report generated: ${report}`);
    return probe.returncode === 0 ? 0 : 2;
  }

  fs.writeFileSync(report, `${lines.join('\n')}\n`, 'utf8');
  console.log(`OK: Diagnose report generated: ${report}`);
  return 0;
}

async function runStr(opts) {
  ensureDir(opts.outputDir);
  const auditJsonl = path.join(opts.outputDir, 'ediabas_str_audit.jsonl');

  const preJobs = [];
  if (opts.pre1Ecu && opts.pre1Job) {
    preJobs.push({
      name: 'PRE1',
      ecu: opts.pre1Ecu,
      job: opts.pre1Job,
      parameters: opts.pre1Arg,
      waitSeconds: opts.pre1WaitSeconds,
    });
  }
  if (opts.pre2Ecu && opts.pre2Job) {
    preJobs.push({
      name: 'PRE2',
      ecu: opts.pre2Ecu,
      job: opts.pre2Job,
      parameters: opts.pre2Arg,
      waitSeconds: opts.pre2WaitSeconds,
    });
  }

  for (const pre of preJobs) {
    const row = await runActionWithRetries({
      state: pre.name,
      parameters: pre.parameters,
      retries: opts.retries,
      auditJsonl,
      outputDir: opts.outputDir,
      sidecarMode: opts.sidecarMode,
      sidecarPython: opts.sidecarPython,
      sidecarScript: opts.sidecarScript,
      sidecarUrl: opts.sidecarUrl,
      ecu: pre.ecu,
      job: pre.job,
      resultFilter: opts.resultFilter,
      config: opts.config,
      timeoutSeconds: opts.timeoutSeconds,
    });

    if (!row || row.returncode !== 0) {
      console.error(`ERROR: Failed at state=${pre.name}. Log: ${row ? row.log_file : 'n/a'}`);
      return 2;
    }

    if (pre.waitSeconds > 0) {
      await sleep(pre.waitSeconds * 1000);
    }
  }

  const sequence = [];
  if (!opts.skipInitialPad) {
    sequence.push(['PAD', opts.argPad, opts.waitAfterPadInitialSeconds]);
  }
  sequence.push(['WOHNEN', opts.argWohnen, opts.waitAfterWohnenEnterSeconds]);
  sequence.push(['PARKING', opts.argParking, opts.waitAfterParkingCommandSeconds]);
  sequence.push(['SLEEP', '', opts.strSeconds]);
  sequence.push(['WOHNEN', opts.argWohnen, opts.waitAfterWohnenReturnSeconds]);
  sequence.push(['PAD', opts.argPad, opts.waitAfterPadReturnSeconds]);

  for (const [state, parameters, waitSeconds] of sequence) {
    if (state === 'SLEEP') {
      appendJsonl(auditJsonl, { state, sleep_seconds: waitSeconds, timestamp: Date.now() / 1000 });
      await sleep(waitSeconds * 1000);
      continue;
    }

    const row = await runActionWithRetries({
      state,
      parameters,
      retries: opts.retries,
      auditJsonl,
      outputDir: opts.outputDir,
      sidecarMode: opts.sidecarMode,
      sidecarPython: opts.sidecarPython,
      sidecarScript: opts.sidecarScript,
      sidecarUrl: opts.sidecarUrl,
      ecu: opts.ecu,
      job: opts.job,
      resultFilter: opts.resultFilter,
      config: opts.config,
      timeoutSeconds: opts.timeoutSeconds,
    });

    if (!row || row.returncode !== 0) {
      console.error(`ERROR: Failed at state=${state}. Log: ${row ? row.log_file : 'n/a'}`);
      return 2;
    }

    await sleep(waitSeconds * 1000);
  }

  console.log(`OK: STR cycle completed via pydiabas sidecar. Artifacts: ${opts.outputDir}`);
  return 0;
}

function printHelp() {
  console.log([
    'Usage: node scripts/ediabas_str_cycle_sidecar.js [options]',
    '',
    'Options:',
    '  --ediabas-bin <path>                 (reserved for parity/documentation)',
    '  --ecu <name>                         default: IPB_APP1',
    '  --job <name>                         default: STEUERN_ROUTINE',
    '  --arg-pad <arg>',
    '  --arg-wohnen <arg>',
    '  --arg-parking <arg>',
    '  --result-filter <filter>',
    '  --config <k=v;k2=v2>',
    '  --settle-seconds <int>',
    '  --str-seconds <int>',
    '  --timeout-seconds <int>',
    '  --retries <int>',
    '  --wait-after-pad-initial-seconds <int>',
    '  --wait-after-wohnen-enter-seconds <int>',
    '  --wait-after-parking-command-seconds <int>',
    '  --wait-after-wohnen-return-seconds <int>',
    '  --wait-after-pad-return-seconds <int>',
    '  --skip-initial-pad',
    '  --pre1-ecu <name>',
    '  --pre1-job <name>',
    '  --pre1-arg <arg>',
    '  --pre1-wait-seconds <int>',
    '  --pre2-ecu <name>',
    '  --pre2-job <name>',
    '  --pre2-arg <arg>',
    '  --pre2-wait-seconds <int>',
    '  --output-dir <path>',
    '  --sidecar-mode <auto|cli|http>',
    '  --sidecar-python <path>              env fallback: PYDIABAS_PYTHON32',
    '  --sidecar-script <path>              default: scripts/ediabas_pydiabas_sidecar.py',
    '  --sidecar-url <url>                  default: http://127.0.0.1:8777',
    '  --diagnose',
    '  --probe',
    '  --probe-ecu <name>                   default: TMODE',
    '  --probe-job <name>                   default: INFO',
    '  --probe-param <param>',
    '  --help, -h',
  ].join('\n'));
}

function parseArgs(argv) {
  const out = {
    ediabasBin: path.resolve(DEFAULT_EDIABAS_BIN),
    ecu: DEFAULT_ECU,
    job: DEFAULT_JOB,
    argPad: DEFAULT_ARG_PAD,
    argWohnen: DEFAULT_ARG_WOHNEN,
    argParking: DEFAULT_ARG_PARKING,
    resultFilter: '',
    config: '',
    settleSeconds: 2,
    strSeconds: 180,
    timeoutSeconds: 60,
    retries: 1,
    waitAfterPadInitialSeconds: 2,
    waitAfterWohnenEnterSeconds: 2,
    waitAfterParkingCommandSeconds: 0,
    waitAfterWohnenReturnSeconds: 2,
    waitAfterPadReturnSeconds: 2,
    skipInitialPad: false,
    pre1Ecu: '',
    pre1Job: '',
    pre1Arg: '',
    pre1WaitSeconds: 0,
    pre2Ecu: '',
    pre2Job: '',
    pre2Arg: '',
    pre2WaitSeconds: 0,
    outputDir: path.resolve(path.join('artifacts', 'ediabas', `pydiabas_str_cycle_${timestampCompact()}`)),
    sidecarMode: 'auto',
    sidecarPython: process.env.PYDIABAS_PYTHON32 || 'python',
    sidecarScript: path.resolve(path.join('scripts', 'ediabas_pydiabas_sidecar.py')),
    sidecarUrl: 'http://127.0.0.1:8777',
    diagnose: false,
    probe: false,
    probeEcu: 'TMODE',
    probeJob: 'INFO',
    probeParam: '',
  };

  const map = {
    '--ediabas-bin': 'ediabasBin',
    '--ecu': 'ecu',
    '--job': 'job',
    '--arg-pad': 'argPad',
    '--arg-wohnen': 'argWohnen',
    '--arg-parking': 'argParking',
    '--result-filter': 'resultFilter',
    '--config': 'config',
    '--settle-seconds': 'settleSeconds',
    '--str-seconds': 'strSeconds',
    '--timeout-seconds': 'timeoutSeconds',
    '--retries': 'retries',
    '--wait-after-pad-initial-seconds': 'waitAfterPadInitialSeconds',
    '--wait-after-wohnen-enter-seconds': 'waitAfterWohnenEnterSeconds',
    '--wait-after-parking-command-seconds': 'waitAfterParkingCommandSeconds',
    '--wait-after-wohnen-return-seconds': 'waitAfterWohnenReturnSeconds',
    '--wait-after-pad-return-seconds': 'waitAfterPadReturnSeconds',
    '--pre1-ecu': 'pre1Ecu',
    '--pre1-job': 'pre1Job',
    '--pre1-arg': 'pre1Arg',
    '--pre1-wait-seconds': 'pre1WaitSeconds',
    '--pre2-ecu': 'pre2Ecu',
    '--pre2-job': 'pre2Job',
    '--pre2-arg': 'pre2Arg',
    '--pre2-wait-seconds': 'pre2WaitSeconds',
    '--output-dir': 'outputDir',
    '--sidecar-mode': 'sidecarMode',
    '--sidecar-python': 'sidecarPython',
    '--sidecar-script': 'sidecarScript',
    '--sidecar-url': 'sidecarUrl',
    '--probe-ecu': 'probeEcu',
    '--probe-job': 'probeJob',
    '--probe-param': 'probeParam',
  };
  const numeric = new Set([
    'settleSeconds',
    'strSeconds',
    'timeoutSeconds',
    'retries',
    'waitAfterPadInitialSeconds',
    'waitAfterWohnenEnterSeconds',
    'waitAfterParkingCommandSeconds',
    'waitAfterWohnenReturnSeconds',
    'waitAfterPadReturnSeconds',
    'pre1WaitSeconds',
    'pre2WaitSeconds',
  ]);

  for (let i = 0; i < argv.length; i += 1) {
    const t = argv[i];
    if (t === '--help' || t === '-h') {
      printHelp();
      process.exit(0);
    }
    if (t === '--diagnose') { out.diagnose = true; continue; }
    if (t === '--probe') { out.probe = true; continue; }
    if (t === '--skip-initial-pad') { out.skipInitialPad = true; continue; }
    if (!(t in map)) throw new Error(`Unknown argument: ${t}`);
    const key = map[t];
    const value = argv[i + 1];
    if (value == null || value.startsWith('--')) throw new Error(`Missing value for ${t}`);
    i += 1;
    out[key] = numeric.has(key) ? Number(value) : value;
  }

  out.ediabasBin = path.resolve(out.ediabasBin);
  out.outputDir = path.resolve(out.outputDir);
  out.sidecarScript = path.resolve(out.sidecarScript);

  if (Number.isNaN(out.waitAfterPadInitialSeconds)) out.waitAfterPadInitialSeconds = out.settleSeconds;
  if (Number.isNaN(out.waitAfterWohnenEnterSeconds)) out.waitAfterWohnenEnterSeconds = out.settleSeconds;
  if (Number.isNaN(out.waitAfterParkingCommandSeconds)) out.waitAfterParkingCommandSeconds = 0;
  if (Number.isNaN(out.waitAfterWohnenReturnSeconds)) out.waitAfterWohnenReturnSeconds = out.settleSeconds;
  if (Number.isNaN(out.waitAfterPadReturnSeconds)) out.waitAfterPadReturnSeconds = out.settleSeconds;
  if (Number.isNaN(out.pre1WaitSeconds)) out.pre1WaitSeconds = 0;
  if (Number.isNaN(out.pre2WaitSeconds)) out.pre2WaitSeconds = 0;

  if (out.settleSeconds >= 0) {
    if (!('waitAfterPadInitialSeconds' in out) || out.waitAfterPadInitialSeconds == null) out.waitAfterPadInitialSeconds = out.settleSeconds;
    if (!('waitAfterWohnenEnterSeconds' in out) || out.waitAfterWohnenEnterSeconds == null) out.waitAfterWohnenEnterSeconds = out.settleSeconds;
    if (!('waitAfterWohnenReturnSeconds' in out) || out.waitAfterWohnenReturnSeconds == null) out.waitAfterWohnenReturnSeconds = out.settleSeconds;
    if (!('waitAfterPadReturnSeconds' in out) || out.waitAfterPadReturnSeconds == null) out.waitAfterPadReturnSeconds = out.settleSeconds;
  }

  if (!['auto', 'cli', 'http'].includes(out.sidecarMode)) throw new Error(`Invalid --sidecar-mode: ${out.sidecarMode}`);
  if (
    out.settleSeconds < 0 ||
    out.strSeconds < 0 ||
    out.timeoutSeconds <= 0 ||
    out.retries < 0 ||
    out.waitAfterPadInitialSeconds < 0 ||
    out.waitAfterWohnenEnterSeconds < 0 ||
    out.waitAfterParkingCommandSeconds < 0 ||
    out.waitAfterWohnenReturnSeconds < 0 ||
    out.waitAfterPadReturnSeconds < 0 ||
    out.pre1WaitSeconds < 0 ||
    out.pre2WaitSeconds < 0
  ) throw new Error('Invalid timing/retry values.');

  return out;
}

(async function main() {
  try {
    const opts = parseArgs(process.argv.slice(2));
    if (opts.diagnose) {
      process.exit(await diagnose(opts));
    }
    process.exit(await runStr(opts));
  } catch (e) {
    console.error(`ERROR: ${e && e.message ? e.message : String(e)}`);
    process.exit(2);
  }
})();
