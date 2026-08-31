#!/usr/bin/env node
// standardize-typography: text-[Nrem|Npx], tracking-[Vem], leading-[V]
// → text-N, tracking-N, leading-N (configurable scales).

import { bootstrap, collectFiles, summarize } from '../lib/script-runtime.mjs';
import {
  ARBITRARY_TEXT_REM, ARBITRARY_TEXT_PX,
  ARBITRARY_TRACKING_EM, ARBITRARY_LEADING,
} from '../lib/regex.mjs';

const { cfg, dry } = bootstrap();
const files = collectFiles(cfg);

const TEXT_TOKEN = cfg.scales?.text ?? {};
const TEXT_PX_TO_REM = cfg.snap?.px?.text ?? {};
const TRACKING_TOKEN = cfg.scales?.tracking ?? {};
const TRACKING_EM_SNAP = cfg.snap?.em?.tracking ?? {};
const LEADING_TOKEN = cfg.scales?.leading ?? {};
const LEADING_SNAP = cfg.snap?.unitless?.leading ?? {};

function transform(content) {
  // text-[Npx] → text-[Nrem] (snap) → text-N (token)
  content = content.replace(ARBITRARY_TEXT_PX, (m, v) => {
    const rem = TEXT_PX_TO_REM[v];
    if (!rem) return m;
    const tok = TEXT_TOKEN[rem];
    return tok ? `text-${tok}` : `text-[${rem}]`;
  });
  // text-[Nrem] → text-N
  content = content.replace(ARBITRARY_TEXT_REM, (m, v) => {
    const tok = TEXT_TOKEN[v];
    return tok ? `text-${tok}` : m;
  });
  // tracking-[Vem] → tracking-N (or tracking-normal)
  content = content.replace(ARBITRARY_TRACKING_EM, (m, v) => {
    const snapped = TRACKING_EM_SNAP[v] ?? v;
    if (snapped === 'normal') return 'tracking-normal';
    const tok = TRACKING_TOKEN[snapped];
    return tok ? `tracking-${tok}` : m;
  });
  // leading-[V] → leading-N
  content = content.replace(ARBITRARY_LEADING, (m, v) => {
    const snapped = LEADING_SNAP[v] ?? v;
    const tok = LEADING_TOKEN[snapped];
    return tok ? `leading-${tok}` : m;
  });
  return content;
}

summarize('standardize:typography', files, transform, { dry });
