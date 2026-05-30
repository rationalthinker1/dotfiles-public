// Shared boilerplate for scripts/*.mjs. Each script:
//   1. reads TW_CLEANUP_CONFIG env to find its config
//   2. calls walk() to find files
//   3. applies a content transform per file via runTransform()
//   4. prints "Touched N of M scanned"
//
// This module wraps that flow so each domain script stays small.

import { loadConfig, resolveScanRoots } from './config.mjs';
import { walk } from './walk.mjs';
import { runTransform, printSummary } from './transform.mjs';
import { scopeCssContent, applyInEditableRanges } from './css-guard.mjs';

export function bootstrap() {
  const configPath = process.env.TW_CLEANUP_CONFIG;
  if (!configPath) {
    console.error('Internal: TW_CLEANUP_CONFIG env var not set (must be invoked via tw-cleanup).');
    process.exit(2);
  }
  const cfg = loadConfig(process.cwd(), configPath);
  const dry = process.env.TW_CLEANUP_DRY === '1';
  return { cfg, dry };
}

export function collectFiles(cfg) {
  const roots = resolveScanRoots(cfg);
  const opts = {
    extensions: cfg.scan.extensions,
    excludeDirs: cfg.scan.excludeDirs,
    excludeFiles: cfg.scan.excludeFiles,
  };
  const files = [];
  for (const r of roots) files.push(...walk(r, opts));

  if (cfg.scan.css?.include) {
    const cssOpts = { ...opts, extensions: ['.css'] };
    // Allow CSS files inside excluded dirs (e.g. src/styles) ONLY if the user
    // explicitly opted in. The css-guard limits edits to recipe bodies.
    const cssDirs = roots.map(r => r); // same roots, but extensions=['.css']
    for (const r of cssDirs) files.push(...walk(r, { ...cssOpts, excludeDirs: cfg.scan.excludeDirs.filter(d => d !== 'src/styles') }));
  }

  return files;
}

// Wraps a transform so CSS files are guarded (only recipe regions edited).
export function makeGuardedTransform(rawTransform) {
  return function guarded(content, path) {
    if (!path.endsWith('.css')) return rawTransform(content, path);
    const { editableRanges } = scopeCssContent(content);
    return applyInEditableRanges(content, editableRanges, text => rawTransform(text, path));
  };
}

export function summarize(label, files, transformFn, opts = {}) {
  const dry = opts.dry ?? false;
  const guarded = makeGuardedTransform(transformFn);
  const result = runTransform({ files, transformFn: guarded, dry });
  printSummary({ label, ...result, dry });
  return result;
}
