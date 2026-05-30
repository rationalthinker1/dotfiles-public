// File traversal. Returns absolute paths of every file under `root` whose
// extension is in `extensions`, skipping any directory whose basename is in
// `excludeDirs` (or whose path ends with one of those), and any file in
// `excludeFiles`. excludeDirs entries may be bare names ("styles", "node_modules")
// or path suffixes ("src/styles").

import { readdirSync, statSync } from 'node:fs';
import { join, basename } from 'node:path';

export function walk(root, opts = {}) {
  const {
    extensions = ['.tsx', '.ts'],
    excludeDirs = [],
    excludeFiles = [],
  } = opts;

  const extSet = new Set(extensions.map(e => e.startsWith('.') ? e : '.' + e));
  const fileDenySet = new Set(excludeFiles);
  const dirDenyExact = new Set();        // basename matches
  const dirDenySuffixes = [];            // path-suffix matches

  for (const d of excludeDirs) {
    if (d.includes('/') || d.includes('\\')) dirDenySuffixes.push(d.replace(/\\/g, '/'));
    else dirDenyExact.add(d);
  }

  const out = [];

  function shouldSkipDir(dirPath) {
    const base = basename(dirPath);
    if (dirDenyExact.has(base)) return true;
    const norm = dirPath.replace(/\\/g, '/');
    return dirDenySuffixes.some(suf => norm.endsWith(suf));
  }

  function walkInner(dir) {
    if (shouldSkipDir(dir)) return;
    let entries;
    try { entries = readdirSync(dir); }
    catch { return; }
    for (const name of entries) {
      const p = join(dir, name);
      let st;
      try { st = statSync(p); }
      catch { continue; }
      if (st.isDirectory()) {
        walkInner(p);
      } else {
        if (fileDenySet.has(name)) continue;
        const dot = name.lastIndexOf('.');
        const ext = dot >= 0 ? name.slice(dot) : '';
        if (extSet.has(ext)) out.push(p);
      }
    }
  }

  walkInner(root);
  return out;
}
