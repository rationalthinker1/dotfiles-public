#!/usr/bin/env node
// Inline `mb-prose-1 last:mb-0` onto top-level <p> tags inside every
// <TryIt … answer={…}> expression in chapter files. Uses brace tracking to
// find each answer expression boundary so we only rewrite <p>s in scope.

import { readFileSync, writeFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

const DIR = '/home/razaf/Projects/electricity-voltage-concept/src/textbook';
const P_CLS = 'mb-prose-1 last:mb-0';

function rewrite(src) {
  let out = '';
  let cursor = 0;
  const re = /answer=\{/g;
  let m;
  while ((m = re.exec(src)) !== null) {
    const openIdx = m.index + m[0].length - 1;
    let depth = 1;
    let i = openIdx + 1;
    while (i < src.length && depth > 0) {
      const ch = src[i];
      if (ch === '{') depth++;
      else if (ch === '}') depth--;
      i++;
    }
    if (depth !== 0) break;
    const closeIdx = i - 1;
    out += src.slice(cursor, openIdx + 1);
    let body = src.slice(openIdx + 1, closeIdx);
    body = body.replace(/<p>/g, `<p className="${P_CLS}">`);
    out += body;
    cursor = closeIdx;
    re.lastIndex = closeIdx;
  }
  out += src.slice(cursor);
  return out;
}

const files = readdirSync(DIR).filter(f => /^Ch\d+\w*\.tsx$/.test(f));
let touched = 0;
for (const file of files) {
  const path = join(DIR, file);
  const before = readFileSync(path, 'utf8');
  const after = rewrite(before);
  if (after !== before) {
    writeFileSync(path, after);
    touched++;
    console.log('updated', file);
  }
}
console.log(`\nTouched ${touched} files of ${files.length} scanned.`);
