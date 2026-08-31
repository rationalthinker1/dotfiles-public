#!/usr/bin/env node
// audit/arbitrary-classes.mjs
// Distribution scan over every `<prefix>-[<value>]` arbitrary Tailwind
// utility in the project. Emits a JSON + Markdown report with:
//   - total occurrences per prefix
//   - top values per prefix
//   - count of occurrences that already snap to a known scale (cleanup
//     candidates) vs. those that look parametric (calc(), clamp(), min(),
//     vh, ch, etc.)
//
// Inputs (via env): TW_CLEANUP_CONFIG, TW_CLEANUP_REPORTS_DIR, TW_CLEANUP_REPORT
// Exit codes: 0 always (audit only).

import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { bootstrap, collectFiles } from '../lib/script-runtime.mjs';
import { Report } from '../lib/report.mjs';

const { cfg } = bootstrap();
const files = collectFiles(cfg);

const PREFIX_VALUE_RE = /\b([a-z][a-z-]*[a-z])-\[([^\]]+)\]/g;

const PARAMETRIC_HINTS = ['calc(', 'min(', 'max(', 'clamp(', 'var(', 'vw', 'vh', 'svh', 'lvh', 'dvh', '%'];

function isParametric(v) {
  return PARAMETRIC_HINTS.some(h => v.includes(h));
}

// Count by prefix and by value.
const byPrefix = new Map();          // prefix -> { total, parametric, values: Map(value -> count) }

for (const path of files) {
  let src;
  try { src = readFileSync(path, 'utf8'); } catch { continue; }
  for (const m of src.matchAll(PREFIX_VALUE_RE)) {
    const prefix = m[1];
    const value = m[2];
    if (!byPrefix.has(prefix)) byPrefix.set(prefix, { total: 0, parametric: 0, values: new Map() });
    const entry = byPrefix.get(prefix);
    entry.total++;
    if (isParametric(value)) entry.parametric++;
    entry.values.set(value, (entry.values.get(value) ?? 0) + 1);
  }
}

const r = new Report({ title: 'Tailwind arbitrary-value audit', command: 'audit:arbitrary' });
r.setSummary({
  files_scanned: files.length,
  unique_prefixes: byPrefix.size,
  total_occurrences: [...byPrefix.values()].reduce((a, x) => a + x.total, 0),
  parametric_occurrences: [...byPrefix.values()].reduce((a, x) => a + x.parametric, 0),
});

// Sort prefixes by total descending.
const prefixes = [...byPrefix.entries()].sort((a, b) => b[1].total - a[1].total);

for (const [prefix, entry] of prefixes) {
  const section = r.addSection(`${prefix}-[…]  •  ${entry.total} total (${entry.parametric} parametric)`);
  const sortedValues = [...entry.values.entries()].sort((a, b) => b[1] - a[1]);
  for (const [value, count] of sortedValues) {
    r.addRow(section, {
      value,
      count,
      parametric: isParametric(value) ? 'yes' : '',
    });
  }
  r.addCount(prefix, entry.total);
}

const dir = process.env.TW_CLEANUP_REPORTS_DIR ?? resolve(cfg.__cwd, cfg.reports?.dir ?? 'tailwind-cleanup-reports');
const fmt = process.env.TW_CLEANUP_REPORT ?? 'both';
r.write(dir, 'arbitrary-classes', fmt);

console.log(`audit:arbitrary — ${r.summary.total_occurrences} arbitrary values across ${byPrefix.size} prefixes in ${files.length} files. Report: ${dir}/arbitrary-classes.{json,md}`);
