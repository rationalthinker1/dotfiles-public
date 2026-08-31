#!/usr/bin/env node
// standardize-breakpoints: max-[Npx]:..., min-[Npx]:... → max-{token}, min-{token}.

import { bootstrap, collectFiles, summarize } from '../lib/script-runtime.mjs';
import { ARBITRARY_BREAKPOINT_PX } from '../lib/regex.mjs';

const { cfg, dry } = bootstrap();
const files = collectFiles(cfg);

const BP = cfg.scales?.breakpoints?.px ?? {};

function transform(content) {
  return content.replace(ARBITRARY_BREAKPOINT_PX, (m, dir, v) => {
    const tok = BP[v];
    return tok ? `${dir}-${tok}` : m;
  });
}

summarize('standardize:breakpoints', files, transform, { dry });
