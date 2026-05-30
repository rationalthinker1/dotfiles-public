#!/usr/bin/env node
// tw-cleanup — umbrella CLI dispatcher.
//
// Usage:
//   tw-cleanup <command> [options]
//
// See README.md or `tw-cleanup --help` for the full list.

import { copyFileSync, existsSync, readFileSync, writeFileSync, mkdirSync, appendFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { VERSION } from '../lib/version.mjs';

const TOOLKIT_DIR = fileURLToPath(new URL('..', import.meta.url));
const HELP = `tw-cleanup v${VERSION}

Usage:
  tw-cleanup <command> [options]

Commands:
  init                          Write tailwind-cleanup.config.json (from template),
                                add the report directory to .gitignore.

  audit:arbitrary               Scan project for arbitrary [bracket] utility values,
                                emit distribution report.
  audit:classes                 Per-file inventory of every Tailwind class string,
                                including those inside clsx/cn/twMerge/tv/cva/tw\`\`.
  audit:duplicates              Run the className duplicates clustering script.
  audit:all                     All three audits.

  standardize:typography        text + tracking + leading.
  standardize:spacing           m/p/gap/w/h + positioning + translate.
  standardize:borders-radii     border-width + rounded.
  standardize:colors            rgba slash-alpha + numeric color rename.
  standardize:misc              z + duration.
  standardize:breakpoints       max-/min-[Npx].
  standardize:all               All six, in canonical order.

  verify                        Runs verify.command from config (default: npm run build).
  version                       Print toolkit version.

Common flags:
  --dry                         No writes; print would-touch counts only.
  --report json|md|both         Report format (default: both).
  --paths a,b                   Override scan paths.
  --config <path>               Use a specific config file instead of cwd/tailwind-cleanup.config.json.
  -h, --help                    Show this help.
`;

function parseArgs(argv) {
  const out = { command: null, dry: false, report: 'both', paths: null, config: null, help: false, rest: [] };
  const args = argv.slice(2);
  if (args.length === 0 || args[0] === '-h' || args[0] === '--help') { out.help = true; return out; }
  out.command = args.shift();
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === '--dry') out.dry = true;
    else if (a === '-h' || a === '--help') out.help = true;
    else if (a === '--report') out.report = args[++i];
    else if (a === '--paths')  out.paths  = args[++i];
    else if (a === '--config') out.config = args[++i];
    else out.rest.push(a);
  }
  return out;
}

async function run() {
  const args = parseArgs(process.argv);
  if (args.help && !args.command) { console.log(HELP); process.exit(0); }

  if (args.command === 'version') { console.log(VERSION); process.exit(0); }
  if (args.command === 'init')    { return cmdInit(); }

  // Lazy import — commands that need a config will load lib/config.
  const { loadConfig, ConfigError, resolveReportsDir } = await import('../lib/config.mjs');

  let cfg;
  try {
    cfg = loadConfig(process.cwd(), args.config);
  } catch (e) {
    if (e instanceof ConfigError) {
      console.error(`tw-cleanup: ${e.message}`);
      process.exit(2);
    }
    throw e;
  }
  if (args.paths) cfg.scan.paths = args.paths.split(',').map(s => s.trim()).filter(Boolean);

  const ctx = { cfg, dry: args.dry, reportFormat: args.report, reportsDir: resolveReportsDir(cfg) };

  switch (args.command) {
    case 'audit:arbitrary': return cmdAudit('audit/arbitrary-classes.mjs', ctx);
    case 'audit:classes':   return cmdAudit('audit/class-strings.mjs', ctx);
    case 'audit:duplicates': return cmdAuditPy('audit/duplicates.py', ctx);
    case 'audit:all':
      cmdScript('audit/arbitrary-classes.mjs', ctx, { swallow: true });
      cmdScript('audit/class-strings.mjs', ctx, { swallow: true });
      cmdAuditPy('audit/duplicates.py', ctx);
      return;
    case 'standardize:typography':   return cmdScript('scripts/standardize-typography.mjs', ctx);
    case 'standardize:spacing':      return cmdScript('scripts/standardize-spacing.mjs', ctx);
    case 'standardize:borders-radii':return cmdScript('scripts/standardize-borders-radii.mjs', ctx);
    case 'standardize:colors':       return cmdScript('scripts/standardize-colors.mjs', ctx);
    case 'standardize:misc':         return cmdScript('scripts/standardize-misc.mjs', ctx);
    case 'standardize:breakpoints':  return cmdScript('scripts/standardize-breakpoints.mjs', ctx);
    case 'standardize:all': {
      // Canonical order: typography → spacing → breakpoints → borders-radii → colors → misc
      const order = [
        'scripts/standardize-typography.mjs',
        'scripts/standardize-spacing.mjs',
        'scripts/standardize-breakpoints.mjs',
        'scripts/standardize-borders-radii.mjs',
        'scripts/standardize-colors.mjs',
        'scripts/standardize-misc.mjs',
      ];
      let exitCode = 0;
      for (const s of order) {
        const code = cmdScript(s, ctx, { swallow: true });
        if (code === 2) { exitCode = 2; break; }
        if (code === 1) exitCode = 1;
      }
      process.exit(exitCode);
    }
    case 'verify': return cmdVerify(ctx);
    default:
      console.error(`tw-cleanup: unknown command "${args.command}"`);
      console.error(HELP);
      process.exit(2);
  }
}

function cmdInit() {
  const cwd = process.cwd();
  const target = join(cwd, 'tailwind-cleanup.config.json');
  if (existsSync(target)) {
    console.error(`tw-cleanup init: ${target} already exists; refusing to overwrite.`);
    process.exit(2);
  }
  const src = join(TOOLKIT_DIR, 'templates', 'tailwind-cleanup.config.example.json');
  copyFileSync(src, target);
  console.log(`Wrote ${target}`);

  // Append to .gitignore
  const gi = join(cwd, '.gitignore');
  const line = 'tailwind-cleanup-reports/\n';
  if (existsSync(gi)) {
    const text = readFileSync(gi, 'utf8');
    if (!text.includes('tailwind-cleanup-reports')) {
      const sep = text.endsWith('\n') ? '' : '\n';
      appendFileSync(gi, sep + line);
      console.log(`Added "tailwind-cleanup-reports/" to .gitignore`);
    }
  } else {
    writeFileSync(gi, line);
    console.log(`Created .gitignore with "tailwind-cleanup-reports/"`);
  }

  console.log('\nNext: edit tailwind-cleanup.config.json to match your project, then run');
  console.log('  tw-cleanup audit:all');
}

function cmdScript(rel, ctx, { swallow = false } = {}) {
  const script = join(TOOLKIT_DIR, rel);
  const env = {
    ...process.env,
    TW_CLEANUP_CONFIG: ctx.cfg.__path,
    TW_CLEANUP_DRY:    ctx.dry ? '1' : '0',
    TW_CLEANUP_REPORT: ctx.reportFormat,
    TW_CLEANUP_REPORTS_DIR: ctx.reportsDir,
  };
  const result = spawnSync(process.execPath, [script], { stdio: 'inherit', env });
  if (swallow) return result.status ?? 0;
  process.exit(result.status ?? 0);
}

function cmdAudit(rel, ctx) { return cmdScript(rel, ctx); }

function cmdAuditPy(rel, ctx) {
  const script = join(TOOLKIT_DIR, rel);
  const env = {
    ...process.env,
    TW_CLEANUP_CONFIG: ctx.cfg.__path,
    TW_CLEANUP_REPORT: ctx.reportFormat,
    TW_CLEANUP_REPORTS_DIR: ctx.reportsDir,
  };
  const result = spawnSync('python3', [script], { stdio: 'inherit', env });
  if (result.status !== 0 && result.status !== 1) process.exit(result.status ?? 2);
  // Exit 0 even if findings reported; the agent reads the JSON.
}

function cmdVerify(ctx) {
  const cmd = ctx.cfg.verify?.command;
  if (!cmd) {
    console.error('tw-cleanup verify: no verify.command in config.');
    process.exit(2);
  }
  console.log(`tw-cleanup verify: ${cmd}`);
  const result = spawnSync(cmd, { stdio: 'inherit', shell: true });
  process.exit(result.status ?? 0);
}

run().catch(err => { console.error(err); process.exit(2); });
