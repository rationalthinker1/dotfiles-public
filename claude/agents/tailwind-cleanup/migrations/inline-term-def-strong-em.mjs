#!/usr/bin/env node
// Inline strong/em classes inside every <Term def={…}> expression in chapter
// files. Uses a brace-tracking scan to find the def expression boundary so we
// only rewrite tags inside the def, not elsewhere in the chapter.
//
// Idempotent — only rewrites tags that have no className attribute.

import { readFileSync, writeFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

const DIR = '/home/razaf/Projects/electricity-voltage-concept/src/textbook';

const STRONG_CLS = 'text-text font-medium';
const EM_CLS = 'italic text-text';

function rewriteRange(src) {
  // Find every `def={` in the source. For each, find matching `}` (brace
  // balanced). Rewrite the substring between the `{` and `}` (inclusive of
  // the def expression body, exclusive of the braces).
  let out = '';
  let cursor = 0;
  const re = /def=\{/g;
  let m;
  while ((m = re.exec(src)) !== null) {
    const openIdx = m.index + m[0].length - 1; // index of `{`
    // Find balanced close.
    let depth = 1;
    let i = openIdx + 1;
    while (i < src.length && depth > 0) {
      const ch = src[i];
      if (ch === '{') depth++;
      else if (ch === '}') depth--;
      i++;
    }
    if (depth !== 0) break; // unbalanced, bail
    const closeIdx = i - 1; // index of `}`
    // Append untouched prefix.
    out += src.slice(cursor, openIdx + 1);
    // Rewrite the def body.
    let body = src.slice(openIdx + 1, closeIdx);
    body = body.replace(/<strong>/g, `<strong className="${STRONG_CLS}">`);
    body = body.replace(/<em>/g, `<em className="${EM_CLS}">`);
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
  const after = rewriteRange(before);
  if (after !== before) {
    writeFileSync(path, after);
    touched++;
    console.log('updated', file);
  }
}
console.log(`\nTouched ${touched} files of ${files.length} scanned.`);
