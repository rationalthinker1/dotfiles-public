// Generic file-transform runner. Reads each file, applies `transformFn`,
// writes only when the result differs. Returns counts. Idempotent.

import { readFileSync, writeFileSync } from 'node:fs';
import { relative } from 'node:path';

export function runTransform({ files, transformFn, cwd = process.cwd(), dry = false, onChange }) {
  let scanned = 0;
  let touched = 0;
  const changedPaths = [];

  for (const path of files) {
    scanned++;
    let before;
    try { before = readFileSync(path, 'utf8'); }
    catch { continue; }
    const after = transformFn(before, path);
    if (typeof after !== 'string' || after === before) continue;
    touched++;
    const rel = relative(cwd, path);
    changedPaths.push(rel);
    if (!dry) writeFileSync(path, after);
    if (typeof onChange === 'function') onChange({ path, rel, before, after });
  }

  return { scanned, touched, changedPaths };
}

export function printSummary({ label, scanned, touched, dry }) {
  const verb = dry ? 'Would touch' : 'Touched';
  console.log(`${label}: ${verb} ${touched} of ${scanned} scanned${dry ? ' (dry run)' : ''}.`);
}
