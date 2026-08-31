#!/usr/bin/env node
// Inline h3, p, strong, em classes inside each lab file's `const prose = (…)`
// JSX block. Tracks balanced parens to find the prose expression boundary.

import { readFileSync, writeFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

const DIR = '/home/razaf/Projects/electricity-voltage-concept/src/labs';

const H3_CLS = 'font-2 font-normal italic text-9 leading-1 my-4xl mb-xl text-text tracking-1';
const P_CLS = 'mb-prose-3';
const STRONG_CLS = 'text-text font-medium';
const EM_CLS = 'italic text-text';

function rewrite(src) {
  const re = /const prose = \(/g;
  let m = re.exec(src);
  if (!m) return src;
  const openIdx = m.index + m[0].length - 1; // index of `(`
  let depth = 1;
  let i = openIdx + 1;
  while (i < src.length && depth > 0) {
    const ch = src[i];
    if (ch === '(') depth++;
    else if (ch === ')') depth--;
    i++;
  }
  if (depth !== 0) return src;
  const closeIdx = i - 1;
  const before = src.slice(0, openIdx + 1);
  let body = src.slice(openIdx + 1, closeIdx);
  body = body.replace(/<h3>/g, `<h3 className="${H3_CLS}">`);
  body = body.replace(/<p>/g, `<p className="${P_CLS}">`);
  body = body.replace(/<strong>/g, `<strong className="${STRONG_CLS}">`);
  body = body.replace(/<em>/g, `<em className="${EM_CLS}">`);
  return before + body + src.slice(closeIdx);
}

const files = readdirSync(DIR).filter(f => /\w+Lab\.tsx$/.test(f));
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
