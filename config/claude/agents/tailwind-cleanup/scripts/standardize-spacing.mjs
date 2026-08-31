#!/usr/bin/env node
// standardize-spacing: m/p (axis & directional), gap, w/h, positioning,
// translate-x/y. All arbitrary px/rem/ch values → named tokens defined in
// config.scales.spacing.{rem,px,ch} and config.scales.gap.px.

import { bootstrap, collectFiles, summarize } from '../lib/script-runtime.mjs';
import {
  spacingPxRegex, spacingRemRegex,
  SHORT_SPACING_PX,
  ARBITRARY_GAP_PX, ARBITRARY_GAP_AXIS_PX,
  ARBITRARY_WH_PX, ARBITRARY_WH_CH,
  ARBITRARY_POS_PX,
} from '../lib/regex.mjs';

const { cfg, dry } = bootstrap();
const files = collectFiles(cfg);

const SPACING_REM = cfg.scales?.spacing?.rem ?? {};
const SPACING_PX  = cfg.scales?.spacing?.px ?? {};
const SPACING_CH  = cfg.scales?.spacing?.ch ?? {};
const SPACING_PX_TO_REM = cfg.snap?.px?.spacing ?? {};
const GAP_PX = cfg.scales?.gap?.px ?? {};

function transform(content) {
  // m/p[axis]-[Npx] → snap to rem → token (single-letter same)
  function pxSpacing(m, prefix, v) {
    const rem = SPACING_PX_TO_REM[v];
    if (!rem) return m;
    const tok = SPACING_REM[rem];
    return tok ? `${prefix}-${tok}` : `${prefix}-[${rem}]`;
  }
  content = content.replace(spacingPxRegex(), pxSpacing);
  content = content.replace(SHORT_SPACING_PX, pxSpacing);

  // m/p[axis]-[Nrem] → token
  content = content.replace(spacingRemRegex(), (m, prefix, v) => {
    const tok = SPACING_REM[v];
    return tok ? `${prefix}-${tok}` : m;
  });

  // gap-[Npx] → gap-{tok}, gap-{x|y}-[Npx] → gap-{axis}-{tok}
  content = content.replace(ARBITRARY_GAP_PX, (m, v) => {
    const tok = GAP_PX[v];
    return tok ? `gap-${tok}` : m;
  });
  content = content.replace(ARBITRARY_GAP_AXIS_PX, (m, axis, v) => {
    const tok = GAP_PX[v];
    return tok ? `gap-${axis}-${tok}` : m;
  });

  // w/h-[Npx] → use spacing.px scale directly (named pixel tokens like icon, panel, page)
  content = content.replace(ARBITRARY_WH_PX, (m, axis, v) => {
    const tok = SPACING_PX[v];
    return tok ? `${axis}-${tok}` : m;
  });
  // w/h-[Nch] → spacing.ch scale
  content = content.replace(ARBITRARY_WH_CH, (m, axis, v) => {
    const tok = SPACING_CH[v];
    return tok ? `${axis}-${tok}` : m;
  });

  // top/right/bottom/left-[Npx], translate-x/y-[Npx]
  content = content.replace(ARBITRARY_POS_PX, (m, prefix, v) => {
    const rem = SPACING_PX_TO_REM[v];
    if (!rem) return m;
    const tok = SPACING_REM[rem];
    return tok ? `${prefix}-${tok}` : `${prefix}-[${rem}]`;
  });

  return content;
}

summarize('standardize:spacing', files, transform, { dry });
