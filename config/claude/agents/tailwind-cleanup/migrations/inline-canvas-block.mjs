#!/usr/bin/env node
// Inline `block w-full` onto every <canvas without an existing className.
// Targets src/textbook/demos/*.tsx and src/labs/*Lab.tsx + src/labs/**/*Canvas*.tsx
// Idempotent.

import { readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

const ROOT = '/home/razaf/Projects/electricity-voltage-concept/src';

function walk(dir, files = []) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    const st = statSync(p);
    if (st.isDirectory()) walk(p, files);
    else if (/\.tsx$/.test(name)) files.push(p);
  }
  return files;
}

const files = walk(ROOT).filter(p =>
  p.includes('/textbook/demos/') ||
  p.includes('/labs/') ||
  p.endsWith('Canvas.tsx') ||
  p.endsWith('CanvasEditor.tsx')
);

let touched = 0;
for (const path of files) {
  const before = readFileSync(path, 'utf8');
  // <canvas WITHOUT className=> add className="block w-full" right after `<canvas`
  // Match: `<canvas` followed by whitespace + attrs (not containing `className=`) up to `>` or `/>`.
  // Strategy: replace `<canvas\b(?![^>]*className=)` with `<canvas className="block w-full"`.
  const after = before.replace(
    /<canvas\b(?![^>]*\bclassName=)/g,
    '<canvas className="block w-full"',
  );
  if (after !== before) {
    writeFileSync(path, after);
    touched++;
    console.log('updated', path.replace(ROOT, 'src'));
  }
}
console.log(`\nTouched ${touched} files of ${files.length} scanned.`);
