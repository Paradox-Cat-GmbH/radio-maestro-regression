#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const DEFAULT_EDIABAS_BIN = 'C:\\EC-Apps\\EDIABAS\\BIN';
const DEFAULT_ACTION_PAD = 'SET_PAD';
const DEFAULT_ACTION_WOHNEN = 'SET_WOHNEN';
const DEFAULT_ACTION_PARKING = 'SET_PARKING';
const DEFAULT_TOOL32_PRG = 'IPB_APP1.prg';
const DEFAULT_TOOL32_JOB = 'STEUERN_ROUTINE';
const DEFAULT_TOOL32_ARG_PAD = 'ARG;ZUSTAND_FAHRZEUG;STR;0x07';
const DEFAULT_TOOL32_ARG_WOHNEN = 'ARG;ZUSTAND_FAHRZEUG;STR;0x05';
const DEFAULT_TOOL32_ARG_PARKING = 'ARG;ZUSTAND_FAHRZEUG;STR;0x01';

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

function resolveTool64Cli(ediabasBin, explicitTool) {
  if (explicitTool) {
    if (fs.existsSync(explicitTool)) return explicitTool;
    throw new Error(`Tool executable not found: ${explicitTool}`);
  }
  const candidate = path.join(ediabasBin, 'Tool64Cli.exe');
  if (fs.existsSync(candidate)) return candidate;
  throw new Error(`Tool64Cli.exe not found in ${ediabasBin}. Install/point to Tool64 CLI or pass --tool64cli explicitly.`);
}

function resolveTool32(ediabasBin, explicitTool) {
  if (explicitTool) {
    if (fs.existsSync(explicitTool)) return explicitTool;
    throw new Error(`Tool executable not found: ${explicitTool}`);
  }
  const candidate = path.join(ediabasBin, 'tool32.exe');
  if (fs.existsSync(candidate)) return candidate;
  throw new Error(`tool32.exe not found in ${ediabasBin}. Install/point to Tool32 or pass --tool32 explicitly.`);
}

function runCommand(cmd, args, cwd, timeoutSeconds) {
  return new Promise((resolve) => {
    const child = spawn(cmd, args, { cwd, windowsHide: true });
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

async function smokeTestCli(tool64cli, ediabasBin, timeoutSeconds) {
  const result = await runCommand(tool64cli, ['--help'], ediabasBin, timeoutSeconds);
  if (result.returncode !== 0) {
    throw new Error(`Tool64Cli --help failed (rc=${result.returncode}). stderr=${result.stderr}`);
  }
  return result;
}

function smokeTestTool32(tool32) {
  if (!fs.existsSync(tool32)) {
    throw new Error(`tool32 not found: ${tool32}`);
  }
}

async function runTool64Action({ tool64cli, ediabasBin, actionName, outputFile, timeoutSeconds }) {
  const logPath = path.resolve(outputFile);
  ensureDir(path.dirname(logPath));
  const started = Date.now() / 1000;
  const result = await runCommand(
    tool64cli,
    ['--actionName', actionName, '--outputFile', logPath, '--overwrite'],
    ediabasBin,
    timeoutSeconds,
  );
  const ended = Date.now() / 1000;

  return {
    state: '',
    action_name: actionName,
    returncode: result.returncode,
    log_file: logPath,
    started_at: started,
    ended_at: ended,
    stdout: result.stdout,
    stderr: result.stderr,
  };
}

async function runTool32Action({ tool32, ediabasBin, prgName, jobName, argument, outputFile, timeoutSeconds }) {
  const logPath = path.resolve(outputFile);
  ensureDir(path.dirname(logPath));
  const cmd = [prgName, jobName, argument];

  const started = Date.now() / 1000;
  const result = await runCommand(tool32, cmd, ediabasBin, timeoutSeconds);
  const ended = Date.now() / 1000;

  let text = `$ ${tool32} ${cmd.join(' ')}\n\n`;
  if (result.stdout) text += `[stdout]\n${result.stdout}\n`;
  if (result.stderr) text += `[stderr]\n${result.stderr}\n`;
  text += `\n[exit_code]=${result.returncode}\n`;
  fs.writeFileSync(logPath, text, 'utf8');

  return {
    state: '',
    action_name: `${jobName}:${argument}`,
    returncode: result.returncode,
    log_file: logPath,
    started_at: started,
    ended_at: ended,
    stdout: result.stdout,
    stderr: result.stderr,
  };
}

async function runActionWithRetries(params) {
  const {
    mode,
    ediabasBin,
    tool64cli,
    tool32,
    state,
    actionName,
    tool32Prg,
    tool32Job,
    tool32Argument,
    outputDir,
    timeoutSeconds,
    retries,
    auditJsonl,
  } = params;

  let lastStep = null;

  for (let attempt = 1; attempt <= retries + 1; attempt += 1) {
    const logFile = path.join(outputDir, `${Math.floor(Date.now() / 1000)}_${state}_attempt${attempt}.log`);
    let step;
    let engineUsed;

    if (mode === 'tool64cli') {
      step = await runTool64Action({ tool64cli, ediabasBin, actionName, outputFile: logFile, timeoutSeconds });
      engineUsed = 'tool64cli';
    } else if (mode === 'tool32') {
      step = await runTool32Action({
        tool32,
        ediabasBin,
        prgName: tool32Prg,
        jobName: tool32Job,
        argument: tool32Argument,
        outputFile: logFile,
        timeoutSeconds,
      });
      engineUsed = 'tool32';
    } else if (mode === 'auto') {
      if (tool64cli) {
        step = await runTool64Action({ tool64cli, ediabasBin, actionName, outputFile: logFile, timeoutSeconds });
        engineUsed = 'tool64cli';
        if (step.returncode !== 0 && tool32) {
          const fallbackLog = path.join(outputDir, `${Math.floor(Date.now() / 1000)}_${state}_attempt${attempt}_fallback_tool32.log`);
          step = await runTool32Action({
            tool32,
            ediabasBin,
            prgName: tool32Prg,
            jobName: tool32Job,
            argument: tool32Argument,
            outputFile: fallbackLog,
            timeoutSeconds,
          });
          engineUsed = 'tool32';
        }
      } else if (tool32) {
        step = await runTool32Action({
          tool32,
          ediabasBin,
          prgName: tool32Prg,
          jobName: tool32Job,
          argument: tool32Argument,
          outputFile: logFile,
          timeoutSeconds,
        });
        engineUsed = 'tool32';
      } else {
        throw new Error('Auto mode could not find Tool64Cli or tool32.');
      }
    } else {
      throw new Error(`Unsupported mode: ${mode}`);
    }

    step.state = state;
    appendJsonl(auditJsonl, { ...step, attempt, engine: engineUsed });
    lastStep = step;

    if (step.returncode === 0) return step;
    if (attempt < retries + 1) await sleep(1000);
  }

  return lastStep;
}

async function diagnoseEnvironment(opts) {
  const outputDir = path.resolve(opts.outputDir);
  ensureDir(outputDir);
  const reportPath = path.join(outputDir, 'diagnose_report.txt');
  const lines = [];

  lines.push('EDIABAS DIAGNOSE REPORT');
  lines.push(`timestamp=${new Date().toISOString().replace('T', ' ').slice(0, 19)}`);
  lines.push(`ediabas_bin=${opts.ediabasBin}`);
  lines.push(`mode=${opts.mode}`);

  let tool64cli = null;
  let tool32 = null;

  try {
    if (opts.mode === 'tool64cli' || opts.mode === 'auto') {
      tool64cli = resolveTool64Cli(opts.ediabasBin, opts.tool64cli);
      lines.push(`tool64cli=FOUND:${tool64cli}`);
    }
  } catch (e) {
    lines.push(`tool64cli=ERROR:${e.message || String(e)}`);
  }

  try {
    if (opts.mode === 'tool32' || opts.mode === 'auto') {
      tool32 = resolveTool32(opts.ediabasBin, opts.tool32);
      lines.push(`tool32=FOUND:${tool32}`);
    }
  } catch (e) {
    lines.push(`tool32=ERROR:${e.message || String(e)}`);
  }

  if (tool64cli) {
    const help = await runCommand(tool64cli, ['--help'], opts.ediabasBin, opts.timeoutSeconds);
    lines.push(`tool64cli_help_rc=${help.returncode}`);
    if (help.stdout) {
      lines.push('tool64cli_help_stdout_begin');
      lines.push(...help.stdout.split(/\r?\n/).slice(0, 40));
      lines.push('tool64cli_help_stdout_end');
    }
    if (help.stderr) {
      lines.push('tool64cli_help_stderr_begin');
      lines.push(...help.stderr.split(/\r?\n/).slice(0, 40));
      lines.push('tool64cli_help_stderr_end');
    }

    if (opts.probeAction) {
      const probeLog = path.join(outputDir, 'diagnose_probe_action.log');
      const probe = await runTool64Action({
        tool64cli,
        ediabasBin: opts.ediabasBin,
        actionName: opts.probeAction,
        outputFile: probeLog,
        timeoutSeconds: opts.timeoutSeconds,
      });
      lines.push(`tool64cli_probe_action=${opts.probeAction}`);
      lines.push(`tool64cli_probe_rc=${probe.returncode}`);
      lines.push(`tool64cli_probe_log=${probe.log_file}`);
      if (probe.stdout) {
        lines.push('tool64cli_probe_stdout_begin');
        lines.push(...probe.stdout.split(/\r?\n/).slice(0, 40));
        lines.push('tool64cli_probe_stdout_end');
      }
      if (probe.stderr) {
        lines.push('tool64cli_probe_stderr_begin');
        lines.push(...probe.stderr.split(/\r?\n/).slice(0, 40));
        lines.push('tool64cli_probe_stderr_end');
      }
    }
  }

  fs.writeFileSync(reportPath, `${lines.join('\n')}\n`, 'utf8');
  console.log(`OK: Diagnose report generated: ${reportPath}`);
  return 0;
}

async function runStrCycle(opts) {
  const outputDir = path.resolve(opts.outputDir);
  ensureDir(outputDir);
  const auditJsonl = path.join(outputDir, 'ediabas_str_audit.jsonl');

  let tool64cli = null;
  let tool32 = null;

  if (opts.mode === 'tool64cli' || opts.mode === 'auto') {
    try {
      tool64cli = resolveTool64Cli(opts.ediabasBin, opts.tool64cli);
    } catch (e) {
      if (opts.mode === 'tool64cli') throw e;
    }
  }

  if (opts.mode === 'tool32' || opts.mode === 'auto') {
    try {
      tool32 = resolveTool32(opts.ediabasBin, opts.tool32);
    } catch (e) {
      if (opts.mode === 'tool32') throw e;
    }
  }

  if (!opts.skipSmokeTest) {
    if (opts.mode === 'tool64cli') {
      await smokeTestCli(tool64cli, opts.ediabasBin, opts.timeoutSeconds);
    } else if (opts.mode === 'tool32') {
      smokeTestTool32(tool32);
    } else {
      if (tool64cli) {
        await smokeTestCli(tool64cli, opts.ediabasBin, opts.timeoutSeconds);
      } else if (tool32) {
        smokeTestTool32(tool32);
      } else {
        throw new Error('Auto mode could not find Tool64Cli or tool32.');
      }
    }
  }

  const sequence = [
    ['PAD', opts.actionPad, opts.tool32ArgPad, opts.settleSeconds],
    ['WOHNEN', opts.actionWohnen, opts.tool32ArgWohnen, opts.settleSeconds],
    ['PARKING', opts.actionParking, opts.tool32ArgParking, opts.settleSeconds],
    ['SLEEP', '', '', opts.strSeconds],
    ['WOHNEN', opts.actionWohnen, opts.tool32ArgWohnen, opts.settleSeconds],
    ['PAD', opts.actionPad, opts.tool32ArgPad, opts.settleSeconds],
  ];

  for (const [state, actionName, tool32Arg, waitSeconds] of sequence) {
    if (state === 'SLEEP') {
      appendJsonl(auditJsonl, { state, sleep_seconds: waitSeconds, timestamp: Date.now() / 1000 });
      await sleep(waitSeconds * 1000);
      continue;
    }

    const step = await runActionWithRetries({
      mode: opts.mode,
      ediabasBin: opts.ediabasBin,
      tool64cli,
      tool32,
      state,
      actionName,
      tool32Prg: opts.tool32Prg,
      tool32Job: opts.tool32Job,
      tool32Argument: tool32Arg,
      outputDir,
      timeoutSeconds: opts.timeoutSeconds,
      retries: opts.retries,
      auditJsonl,
    });

    if (!step || step.returncode !== 0) {
      const rc = step ? step.returncode : 1;
      const log = step ? step.log_file : 'n/a';
      console.error(`ERROR: Failed at state=${state} action=${actionName} rc=${rc}. Log: ${log}`);
      return 2;
    }

    await sleep(waitSeconds * 1000);
  }

  console.log(`OK: STR cycle completed. Artifacts: ${outputDir}`);
  return 0;
}

function parseArgs(argv) {
  const defaults = {
    ediabasBin: DEFAULT_EDIABAS_BIN,
    mode: 'auto',
    tool64cli: null,
    tool32: null,
    actionPad: DEFAULT_ACTION_PAD,
    actionWohnen: DEFAULT_ACTION_WOHNEN,
    actionParking: DEFAULT_ACTION_PARKING,
    tool32Prg: DEFAULT_TOOL32_PRG,
    tool32Job: DEFAULT_TOOL32_JOB,
    tool32ArgPad: DEFAULT_TOOL32_ARG_PAD,
    tool32ArgWohnen: DEFAULT_TOOL32_ARG_WOHNEN,
    tool32ArgParking: DEFAULT_TOOL32_ARG_PARKING,
    settleSeconds: 2,
    strSeconds: 180,
    timeoutSeconds: 60,
    retries: 1,
    outputDir: path.join('artifacts', 'ediabas', `str_cycle_${timestampCompact()}`),
    skipSmokeTest: false,
    diagnose: false,
    probeAction: null,
  };

  const map = {
    '--ediabas-bin': 'ediabasBin',
    '--mode': 'mode',
    '--tool64cli': 'tool64cli',
    '--tool32': 'tool32',
    '--action-pad': 'actionPad',
    '--action-wohnen': 'actionWohnen',
    '--action-parking': 'actionParking',
    '--tool32-prg': 'tool32Prg',
    '--tool32-job': 'tool32Job',
    '--tool32-arg-pad': 'tool32ArgPad',
    '--tool32-arg-wohnen': 'tool32ArgWohnen',
    '--tool32-arg-parking': 'tool32ArgParking',
    '--settle-seconds': 'settleSeconds',
    '--str-seconds': 'strSeconds',
    '--timeout-seconds': 'timeoutSeconds',
    '--retries': 'retries',
    '--output-dir': 'outputDir',
    '--probe-action': 'probeAction',
  };

  const numeric = new Set(['settleSeconds', 'strSeconds', 'timeoutSeconds', 'retries']);
  const boolFlags = {
    '--skip-smoke-test': 'skipSmokeTest',
    '--diagnose': 'diagnose',
  };

  const out = { ...defaults };

  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];

    if (token in boolFlags) {
      out[boolFlags[token]] = true;
      continue;
    }

    if (token in map) {
      const key = map[token];
      const value = argv[i + 1];
      if (value == null || value.startsWith('--')) {
        throw new Error(`Missing value for ${token}`);
      }
      i += 1;
      out[key] = numeric.has(key) ? Number(value) : value;
      continue;
    }

    if (token === '--help' || token === '-h') {
      printHelp();
      process.exit(0);
    }

    throw new Error(`Unknown argument: ${token}`);
  }

  if (!['auto', 'tool64cli', 'tool32'].includes(out.mode)) {
    throw new Error(`Invalid --mode: ${out.mode}`);
  }

  if (out.settleSeconds < 0 || out.strSeconds < 0 || out.timeoutSeconds <= 0 || out.retries < 0) {
    throw new Error('Invalid timing/retry values.');
  }

  out.ediabasBin = path.resolve(out.ediabasBin);
  out.outputDir = path.resolve(out.outputDir);
  return out;
}

function printHelp() {
  const txt = [
    'Usage: node scripts/ediabas_str_cycle.js [options]',
    '',
    'Options (parity with Python version):',
    '  --ediabas-bin <path>',
    '  --mode <auto|tool64cli|tool32>',
    '  --tool64cli <path>',
    '  --tool32 <path>',
    '  --action-pad <name>',
    '  --action-wohnen <name>',
    '  --action-parking <name>',
    '  --tool32-prg <name>',
    '  --tool32-job <name>',
    '  --tool32-arg-pad <arg>',
    '  --tool32-arg-wohnen <arg>',
    '  --tool32-arg-parking <arg>',
    '  --settle-seconds <int>',
    '  --str-seconds <int>',
    '  --timeout-seconds <int>',
    '  --retries <int>',
    '  --output-dir <path>',
    '  --skip-smoke-test',
    '  --diagnose',
    '  --probe-action <name>',
    '  --help, -h',
  ].join('\n');
  console.log(txt);
}

(async function main() {
  try {
    const opts = parseArgs(process.argv.slice(2));

    if (!fs.existsSync(opts.ediabasBin) || !fs.statSync(opts.ediabasBin).isDirectory()) {
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
