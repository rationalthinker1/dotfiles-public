#!/usr/bin/env node
// standardize-colors:
//   1. [rgba(r,g,b,a)] → {name}/{alphaBucket} (Tailwind slash-alpha)
//   2. bg-color-N / text-color-N / border-color-N → bg-{semantic} etc.

import { bootstrap, collectFiles, summarize } from '../lib/script-runtime.mjs';
import { ARBITRARY_RGBA, NUMERIC_COLOR } from '../lib/regex.mjs';

const { cfg, dry } = bootstrap();
const files = collectFiles(cfg);

const RGB_MAP = cfg.colors?.rgbMap ?? {};
const ALPHA_BUCKETS = (cfg.colors?.alphaBuckets ?? []).slice().sort((a, b) => a.maxAlpha - b.maxAlpha);
const NUMERIC_ALIAS = cfg.colors?.numericAliases ?? {};

function bucketAlpha(a) {
  const n = parseFloat(a);
  for (const b of ALPHA_BUCKETS) if (n <= b.maxAlpha) return b.bucket;
  return ALPHA_BUCKETS.length ? ALPHA_BUCKETS[ALPHA_BUCKETS.length - 1].bucket : 100;
}

function transform(content) {
  content = content.replace(ARBITRARY_RGBA, (m, prefix, r, g, b, a) => {
    const key = `${r},${g},${b}`;
    const name = RGB_MAP[key];
    if (!name) return m;
    return `${prefix}-${name}/${bucketAlpha(a)}`;
  });
  content = content.replace(NUMERIC_COLOR, (m, prefix, n) => {
    const name = NUMERIC_ALIAS[n];
    return name ? `${prefix}-${name}` : m;
  });
  return content;
}

summarize('standardize:colors', files, transform, { dry });
