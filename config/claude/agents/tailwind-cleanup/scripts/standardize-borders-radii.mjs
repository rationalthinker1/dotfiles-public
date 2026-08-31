#!/usr/bin/env node
// standardize-borders-radii: border-[Npx], border-{tblr}-[Npx], rounded-[Npx].

import { bootstrap, collectFiles, summarize } from '../lib/script-runtime.mjs';
import { ARBITRARY_BORDER_WIDTH_PX, ARBITRARY_ROUNDED_PX } from '../lib/regex.mjs';

const { cfg, dry } = bootstrap();
const files = collectFiles(cfg);

const BORDER_WIDTHS = new Set((cfg.scales?.borderWidths?.px ?? []).map(String));
const RADIUS = cfg.scales?.radius?.px ?? {};

function transform(content) {
  // border-[Npx] / border-{t|b|l|r}-[Npx] → border-N / border-{dir}-N
  // ONLY if the width is in the registered set (others should require manual review).
  content = content.replace(ARBITRARY_BORDER_WIDTH_PX, (m, dir, v) => {
    if (!BORDER_WIDTHS.has(v)) return m;
    return dir ? `border-${dir}-${v}` : `border-${v}`;
  });
  // rounded-[Npx] → rounded-N
  content = content.replace(ARBITRARY_ROUNDED_PX, (m, v) => {
    const tok = RADIUS[v];
    return tok ? `rounded-${tok}` : m;
  });
  return content;
}

summarize('standardize:borders-radii', files, transform, { dry });
