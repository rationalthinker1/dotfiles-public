// Shared regex factories. The patterns aren't config-driven (the syntax of
// Tailwind class strings is universal) — but matching is centralized here so
// regex tweaks happen in one place.

// `text-[0.625rem]` etc — captures the value inside brackets.
export const ARBITRARY_TEXT_REM = /\btext-\[(-?[\d.]+rem)\]/g;
export const ARBITRARY_TEXT_PX  = /\btext-\[(-?[\d.]+)px\]/g;

// Tracking: `tracking-[.05em]`, `tracking-[-.025em]`. Allows leading minus and
// optional leading zero.
export const ARBITRARY_TRACKING_EM = /\btracking-\[(-?\.?[\d.]+em)\]/g;

// Leading (line-height) — unitless decimals: `leading-[1.55]`.
export const ARBITRARY_LEADING = /\bleading-\[([\d.]+)\]/g;

// Duration: `duration-[120ms]`.
export const ARBITRARY_DURATION_MS = /\bduration-\[(\d+ms)\]/g;

// Z-index: `z-[999]`.
export const ARBITRARY_Z = /\bz-\[(\d+)\]/g;

// Border radius: `rounded-[12px]`.
export const ARBITRARY_ROUNDED_PX = /\brounded-\[(\d+)px\]/g;

// Border width: `border-l-[3px]`, `border-[6px]`.
export const ARBITRARY_BORDER_WIDTH_PX = /\bborder(?:-([tblr]))?-\[(\d+)px\]/g;

// Breakpoint variants: `max-[760px]:`, `min-[600px]:`.
export const ARBITRARY_BREAKPOINT_PX = /\b(max|min)-\[(\d+px)\]/g;

// rgba in class brackets: `bg-[rgba(91,174,248,.32)]`.
export const ARBITRARY_RGBA =
  /\b([a-z-]+)-\[rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\.\d+|\d+\.?\d*)\s*\)\]/g;

// Numeric color utilities: `bg-color-2`, `border-color-5`, `text-color-4`.
export const NUMERIC_COLOR = /\b([a-z]+)-color-([1-9])\b/g;

// Spacing axis/direction utilities with arbitrary px/rem values.
// `mx-[1rem]`, `mt-[14px]`, `px-[0.5rem]`, `pt-[2rem]`...
export function spacingPxRegex() {
  return /\b([mp][tblrxy])-\[(\d+(?:\.\d+)?)px\]/g;
}
export function spacingRemRegex() {
  return /\b([mp][tblrxy])-\[(-?[\d.]+rem)\]/g;
}

// Single-letter `p-[Npx]`, `m-[Npx]` (no axis/direction).
export const SHORT_SPACING_PX = /\b([mp])-\[(\d+)px\]/g;

// Gap utilities.
export const ARBITRARY_GAP_PX = /(?<![a-z-])gap-\[(\d+)px\]/g;
export const ARBITRARY_GAP_AXIS_PX = /\bgap-([xy])-\[(\d+)px\]/g;

// Width/height arbitrary px / ch.
export const ARBITRARY_WH_PX = /\b([wh])-\[(\d+)px\]/g;
export const ARBITRARY_WH_CH = /\b([wh])-\[(\d+)ch\]/g;

// Positioning utilities (top/right/bottom/left) and translate-x/y.
export const ARBITRARY_POS_PX =
  /\b(top|right|bottom|left|translate-[xy])-\[(\d+)px\]/g;
