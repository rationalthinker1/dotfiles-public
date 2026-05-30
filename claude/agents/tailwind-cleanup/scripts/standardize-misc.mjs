#!/usr/bin/env node
// standardize-misc: z-[N], duration-[Nms].

import { bootstrap, collectFiles, summarize } from '../lib/script-runtime.mjs';
import { ARBITRARY_Z, ARBITRARY_DURATION_MS } from '../lib/regex.mjs';

const { cfg, dry } = bootstrap();
const files = collectFiles(cfg);

const Z = cfg.scales?.z ?? {};
const DURATION_MS = cfg.scales?.duration?.ms ?? {};

function transform(content) {
  content = content.replace(ARBITRARY_Z, (m, v) => {
    const tok = Z[v];
    return tok ? `z-${tok}` : m;
  });
  content = content.replace(ARBITRARY_DURATION_MS, (m, v) => {
    const tok = DURATION_MS[v];
    return tok ? `duration-${tok}` : m;
  });
  return content;
}

summarize('standardize:misc', files, transform, { dry });
