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

function resolvePowerShellX86() {
  const windir = process.env.WINDIR || 'C:\\Windows';
  const x86Path = path.join(windir, 'SysWOW64', 'WindowsPowerShell', 'v1.0', 'powershell.exe');
  if (fs.existsSync(x86Path)) return x86Path;
  return 'powershell.exe';
}

function runPowerShell(scriptPath, args, timeoutSeconds) {
  return new Promise((resolve) => {
    const psExe = resolvePowerShellX86();
    const cmdArgs = [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      scriptPath,
      ...args,
    ];

    const child = spawn(psExe, cmdArgs, { windowsHide: true });
    let stdout = '';
    let stderr = '';
    let finished = false;

    const timer = setTimeout(() => {
      if (finished) return;
      try {
        child.kill('SIGKILL');
      } catch (_) {}
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

function parseBridgeJson(stdoutText) {
  const lines = (stdoutText || '').split(/\r?\n/).map((s) => s.trim()).filter(Boolean);
  for (let i = lines.length - 1; i >= 0; i -= 1) {
    const line = lines[i];
    if (!line.startsWith('{')) continue;
    try {
      return JSON.parse(line);
    } catch (_) {
      continue;
    }
  }
  return null;
}

async function runApiJob({
  bridgeScript,
  ediabasBin,
  ecu,
  job,
  jobParam,
  resultFilter,
  timeoutSeconds,
  ifh,
  deviceUnit,
  deviceApplication,
  configuration,
  outputFile,
}) {
  const logPath = path.resolve(outputFile);
  ensureDir(path.dirname(logPath));

  const args = [
    '-EdiabasBin', ediabasBin,
    '-Ecu', ecu,
    '-Job', job,
    '-JobParam', jobParam,
    '-ResultFilter', resultFilter,
    '-TimeoutSeconds', String(timeoutSeconds),
    '-Ifh', ifh,
    '-DeviceUnit', deviceUnit,
    '-DeviceApplication', deviceApplication,
    '-Configuration', configuration,
  ];

  const started = Date.now() / 1000;
  const result = await runPowerShell(bridgeScript, args, timeoutSeconds + 15);
  const ended = Date.now() / 1000;

  let text = `$ bridge=${bridgeScript}\n`;
  text += `$ args=${args.join(' ')}\n\n`;
  if (result.stdout) text += `[stdout]\n${result.stdout}\n`;
  if (result.stderr) text += `[stderr]\n${result.stderr}\n`;
  text += `\n[exit_code]=${result.returncode}\n`;
  fs.writeFileSync(logPath, text, 'utf8');

  const bridgeJson = parseBridgeJson(result.stdout);
  return {
    returncode: result.returncode,
    started_at: started,
    ended_at: ended,
    stdout: result.stdout,
    stderr: result.stderr,
    log_file: logPath,
    bridge_result: bridgeJson,
  };
}

async function runActionWithRetries(opts) {
  const {
    state,
    retries,
    outputDir,
    auditJsonl,
  } = opts;

  let last = null;
  for (let attempt = 1; attempt <= retries + 1; attempt += 1) {
    const logFile = path.join(outputDir, `${Math.floor(Date.now() / 1000)}_${state}_attempt${attempt}.log`);
    const result = await runApiJob({ ...opts, outputFile: logFile });

    const row = {
      state,
      ecu: opts.ecu,
      job: opts.job,
      job_param: opts.jobParam,
      returncode: result.returncode,
      log_file: result.log_file,
      started_at: result.started_at,
      ended_at: result.ended_at,
      attempt,
      engine: 'api32-bridge',
      bridge_result: result.bridge_result,
      stdout: result.stdout,
      stderr: result.stderr,
    };
    appendJsonl(auditJsonl, row);
    last = row;

    if (result.returncode === 0) return row;
    if (attempt < retries + 1) await sleep(1000);
  }
  return last;
}

async function diagnoseEnvironment(opts) {
  const outputDir = path.resolve(opts.outputDir);
  ensureDir(outputDir);
  const reportPath = path.join(outputDir, 'diagnose_report.txt');
  const bridgeScript = path.resolve(opts.bridgeScript);

  const lines = [];
  lines.push('EDIABAS API32 JS DIAGNOSE REPORT');
  lines.push(`timestamp=${new Date().toISOString().replace('T', ' ').slice(0, 19)}`);
  lines.push(`ediabas_bin=${opts.ediabasBin}`);
  lines.push(`bridge_script=${bridgeScript}`);
  lines.push(`powershell_x86=${resolvePowerShellX86()}`);
  lines.push(`node_arch=${process.arch}`);

  if (!fs.existsSync(bridgeScript)) {
    lines.push('bridge_exists=false');
    fs.writeFileSync(reportPath, `${lines.join('\n')}\n`, 'utf8');
    console.log(`OK: Diagnose report generated: ${reportPath}`);
    return 2;
  }

  lines.push('bridge_exists=true');
  if (!opts.probe) {
    fs.writeFileSync(reportPath, `${lines.join('\n')}\n`, 'utf8');
    console.log(`OK: Diagnose report generated: ${reportPath}`);
    return 0;
  }

  const probe = await runApiJob({
    bridgeScript,
    ediabasBin: opts.ediabasBin,
    ecu: opts.probeEcu,
    job: opts.probeJob,
    jobParam: opts.probeParam,
    resultFilter: opts.resultFilter,
    timeoutSeconds: opts.timeoutSeconds,
    ifh: opts.ifh,
    deviceUnit: opts.deviceUnit,
    deviceApplication: opts.deviceApplication,
    configuration: opts.configuration,
    outputFile: path.join(outputDir, 'diagnose_probe_job.log'),
  });

  lines.push(`probe_ecu=${opts.probeEcu}`);
  lines.push(`probe_job=${opts.probeJob}`);
  lines.push(`probe_param=${opts.probeParam}`);
  lines.push(`probe_rc=${probe.returncode}`);
  lines.push(`probe_log=${path.join(outputDir, 'diagnose_probe_job.log')}`);
  if (probe.bridge_result) {
    lines.push(`probe_bridge_ok=${probe.bridge_result.ok}`);
    lines.push(`probe_bridge_state=${probe.bridge_result.final_state}`);
    lines.push(`probe_bridge_error=${probe.bridge_result.error_text || ''}`);
  }

  fs.writeFileSync(reportPath, `${lines.join('\n')}\n`, 'utf8');
  console.log(`OK: Diagnose report generated: ${reportPath}`);
  return probe.returncode === 0 ? 0 : 2;
}

async function runStrCycle(opts) {
  const outputDir = path.resolve(opts.outputDir);
  const auditJsonl = path.join(outputDir, 'ediabas_str_audit.jsonl');
  const bridgeScript = path.resolve(opts.bridgeScript);
  ensureDir(outputDir);

  if (!fs.existsSync(bridgeScript)) {
    throw new Error(`Bridge script not found: ${bridgeScript}`);
  }

  const sequence = [
    ['PAD', opts.argPad, opts.settleSeconds],
    ['WOHNEN', opts.argWohnen, opts.settleSeconds],
    ['PARKING', opts.argParking, opts.settleSeconds],
    ['SLEEP', '', opts.strSeconds],
    ['WOHNEN', opts.argWohnen, opts.settleSeconds],
    ['PAD', opts.argPad, opts.settleSeconds],
  ];

  for (const [state, jobParam, waitSeconds] of sequence) {
    if (state === 'SLEEP') {
      appendJsonl(auditJsonl, { state, sleep_seconds: waitSeconds, timestamp: Date.now() / 1000 });
      await sleep(waitSeconds * 1000);
      continue;
    }

    const row = await runActionWithRetries({
      state,
      retries: opts.retries,
      outputDir,
      auditJsonl,
      bridgeScript,
      ediabasBin: opts.ediabasBin,
      ecu: opts.ecu,
      job: opts.job,
      jobParam,
      resultFilter: opts.resultFilter,
      timeoutSeconds: opts.timeoutSeconds,
      ifh: opts.ifh,
      deviceUnit: opts.deviceUnit,
      deviceApplication: opts.deviceApplication,
      configuration: opts.configuration,
    });

    if (!row || row.returncode !== 0) {
      const rc = row ? row.returncode : 1;
      const log = row ? row.log_file : 'n/a';
      console.error(`ERROR: Failed at state=${state} rc=${rc}. Log: ${log}`);
      return 2;
    }

    await sleep(waitSeconds * 1000);
  }

  console.log(`OK: STR cycle completed via API32 bridge. Artifacts: ${outputDir}`);
  return 0;
}

function printHelp() {
  const txt = [
    'Usage: node scripts/ediabas_str_cycle_api.js [options]',
    '',
    'Options:',
    '  --ediabas-bin <path>',
    '  --ecu <name>                       default: IPB_APP1',
    '  --job <name>                       default: STEUERN_ROUTINE',
    '  --arg-pad <arg>',
    '  --arg-wohnen <arg>',
    '  --arg-parking <arg>',
    '  --result-filter <filter>',
    '  --ifh <value>',
    '  --device-unit <value>',
    '  --device-application <value>',
    '  --configuration <value>',
    '  --settle-seconds <int>',
    '  --str-seconds <int>',
    '  --timeout-seconds <int>',
    '  --retries <int>',
    '  --output-dir <path>',
    '  --bridge-script <path>             default: scripts/ediabas_api32_job.ps1',
    '  --diagnose                         generate diagnose report and exit',
    '  --probe                            execute one probe job during diagnose',
    '  --probe-ecu <name>                 default: TMODE',
    '  --probe-job <name>                 default: INFO',
    '  --probe-param <param>              default: empty',
    '  --help, -h',
  ].join('\n');
  console.log(txt);
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
    ifh: '',
    deviceUnit: '',
    deviceApplication: '',
    configuration: '',
    settleSeconds: 2,
    strSeconds: 180,
    timeoutSeconds: 60,
    retries: 1,
    outputDir: path.resolve(path.join('artifacts', 'ediabas', `api32_str_cycle_${timestampCompact()}`)),
    bridgeScript: path.resolve(path.join('scripts', 'ediabas_api32_job.ps1')),
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
    '--ifh': 'ifh',
    '--device-unit': 'deviceUnit',
    '--device-application': 'deviceApplication',
    '--configuration': 'configuration',
    '--settle-seconds': 'settleSeconds',
    '--str-seconds': 'strSeconds',
    '--timeout-seconds': 'timeoutSeconds',
    '--retries': 'retries',
    '--output-dir': 'outputDir',
    '--bridge-script': 'bridgeScript',
    '--probe-ecu': 'probeEcu',
    '--probe-job': 'probeJob',
    '--probe-param': 'probeParam',
  };
  const numeric = new Set(['settleSeconds', 'strSeconds', 'timeoutSeconds', 'retries']);

  for (let i = 0; i < argv.length; i += 1) {
    const t = argv[i];
    if (t === '--help' || t === '-h') {
      printHelp();
      process.exit(0);
    }
    if (t === '--diagnose') {
      out.diagnose = true;
      continue;
    }
    if (t === '--probe') {
      out.probe = true;
      continue;
    }
    if (!(t in map)) {
      throw new Error(`Unknown argument: ${t}`);
    }
    const key = map[t];
    const v = argv[i + 1];
    if (v == null || v.startsWith('--')) {
      throw new Error(`Missing value for ${t}`);
    }
    i += 1;
    out[key] = numeric.has(key) ? Number(v) : v;
  }

  out.ediabasBin = path.resolve(out.ediabasBin);
  out.outputDir = path.resolve(out.outputDir);
  out.bridgeScript = path.resolve(out.bridgeScript);

  if (out.settleSeconds < 0 || out.strSeconds < 0 || out.timeoutSeconds <= 0 || out.retries < 0) {
    throw new Error('Invalid timing/retry values.');
  }
  return out;
}

(async function main() {
  try {
    const opts = parseArgs(process.argv.slice(2));
    if (!fs.existsSync(opts.ediabasBin)) {
      console.error(`ERROR: Invalid EDIABAS BIN directory: ${opts.ediabasBin}`);
      process.exit(2);
    }

    if (opts.diagnose) {
      const rc = await diagnoseEnvironment(opts);
      process.exit(rc);
    }

    const rc = await runStrCycle(opts);
    process.exit(rc);
  } catch (e) {
    console.error(`ERROR: ${e && e.message ? e.message : String(e)}`);
    process.exit(2);
  }
})();
