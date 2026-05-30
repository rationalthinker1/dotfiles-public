// Config discovery, validation, and defaults.
//
// Config search order:
//   1. --config <path>   (CLI arg, absolute or relative to cwd)
//   2. ./tailwind-cleanup.config.json
//   3. ./tailwind-cleanup.config.js  (NOT YET — JSON only for now)
//
// Validation is intentionally light — we check for required top-level keys and
// types, surface a friendly error, and rely on JSON-Schema in schema/ for
// stricter docs / editor support.

import { existsSync, readFileSync } from 'node:fs';
import { isAbsolute, join, resolve } from 'node:path';

const REQUIRED_TOP_LEVEL = ['scan', 'scales'];

const DEFAULTS = {
  scan: {
    paths: ['src'],
    extensions: ['.tsx', '.ts'],
    excludeDirs: ['src/styles', 'node_modules', 'dist', '.git'],
    excludeFiles: ['routeTree.gen.ts'],
    css: { include: false, recipesOnly: true },
  },
  verify: { command: 'npm run build' },
  reports: { dir: 'tailwind-cleanup-reports' },
};

export class ConfigError extends Error {
  constructor(message) { super(message); this.name = 'ConfigError'; }
}

function deepMerge(base, over) {
  if (over === undefined || over === null) return base;
  if (typeof over !== 'object' || Array.isArray(over)) return over;
  const out = { ...base };
  for (const k of Object.keys(over)) {
    out[k] = (k in base && typeof base[k] === 'object' && !Array.isArray(base[k]))
      ? deepMerge(base[k] ?? {}, over[k])
      : over[k];
  }
  return out;
}

export function loadConfig(cwd, explicitPath) {
  const path = resolvePath(cwd, explicitPath);
  if (!path) {
    throw new ConfigError(
      `No tailwind-cleanup.config.json found in ${cwd}. Run \`tw-cleanup init\` to create one.`
    );
  }
  let raw;
  try {
    raw = JSON.parse(readFileSync(path, 'utf8'));
  } catch (e) {
    throw new ConfigError(`Failed to parse ${path}: ${e.message}`);
  }
  const cfg = deepMerge(DEFAULTS, raw);
  validate(cfg, path);
  cfg.__path = path;
  cfg.__cwd = cwd;
  return cfg;
}

function resolvePath(cwd, explicit) {
  if (explicit) {
    const p = isAbsolute(explicit) ? explicit : resolve(cwd, explicit);
    return existsSync(p) ? p : null;
  }
  const candidate = join(cwd, 'tailwind-cleanup.config.json');
  return existsSync(candidate) ? candidate : null;
}

function validate(cfg, path) {
  for (const key of REQUIRED_TOP_LEVEL) {
    if (!(key in cfg)) {
      throw new ConfigError(`${path}: missing required key "${key}"`);
    }
  }
  if (!Array.isArray(cfg.scan.paths) || cfg.scan.paths.length === 0) {
    throw new ConfigError(`${path}: scan.paths must be a non-empty array`);
  }
  if (cfg.scales && typeof cfg.scales !== 'object') {
    throw new ConfigError(`${path}: scales must be an object`);
  }
}

export function resolveReportsDir(cfg) {
  return resolve(cfg.__cwd, cfg.reports?.dir ?? DEFAULTS.reports.dir);
}

export function resolveScanRoots(cfg) {
  return cfg.scan.paths.map(p => resolve(cfg.__cwd, p));
}

export { DEFAULTS };
