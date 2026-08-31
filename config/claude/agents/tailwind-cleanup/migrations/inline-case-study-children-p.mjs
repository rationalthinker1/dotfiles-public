#!/usr/bin/env node
// Inline `mb-prose-2 last:mb-0` onto top-level <p> tags inside every
// <CaseStudy ...>…</CaseStudy> body in chapter files. Uses tag-balance
// tracking on the open/close <CaseStudy> elements.

import { readFileSync, writeFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

const DIR = '/home/razaf/Projects/electricity-voltage-concept/src/textbook';
const P_CLS = 'mb-prose-2 last:mb-0';

function rewrite(src) {
  // Find each <CaseStudy[\s\S]*?> (single open tag, possibly multi-line) and
  // its matching </CaseStudy>. Within the body, rewrite <p> to <p class…>.
  let out = '';
  let cursor = 0;
  // Match `<CaseStudy` followed by any chars (non-greedy) ending with `>` that
  // is not preceded by `/`. We need to skip over self-closing tags and the
  // wrapper <CaseStudies>. Use a careful regex.
  const re = /<CaseStudy(?![a-zA-Z])([^>]*?)>/g;
  let m;
  while ((m = re.exec(src)) !== null) {
    const headerEnd = m.index + m[0].length;
    // If header ends with `/>` it was self-closing; skip.
    if (m[0].endsWith('/>')) continue;
    // Find matching </CaseStudy> by tracking depth.
    let depth = 1;
    let i = headerEnd;
    while (i < src.length && depth > 0) {
      const openIdx = src.indexOf('<CaseStudy', i);
      const closeIdx = src.indexOf('</CaseStudy>', i);
      if (closeIdx === -1) { depth = -1; break; }
      // If openIdx exists and comes BEFORE closeIdx and is not </CaseStudy>
      if (openIdx !== -1 && openIdx < closeIdx) {
        // Check it's not <CaseStudies>
        const after = src.slice(openIdx + '<CaseStudy'.length, openIdx + '<CaseStudy'.length + 2);
        if (!/^[a-zA-Z]/.test(after)) {
          depth++;
          i = openIdx + 1;
          continue;
        }
        // It's <CaseStudies — skip
        i = openIdx + 1;
        continue;
      }
      depth--;
      i = closeIdx + '</CaseStudy>'.length;
    }
    if (depth !== 0) break;
    const closeStart = src.lastIndexOf('</CaseStudy>', i);
    out += src.slice(cursor, headerEnd);
    let body = src.slice(headerEnd, closeStart);
    body = body.replace(/<p>/g, `<p className="${P_CLS}">`);
    out += body;
    cursor = closeStart;
    re.lastIndex = closeStart;
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
