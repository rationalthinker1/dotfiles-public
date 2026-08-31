// CSS-mode safety. When transforms run over CSS files, only the bodies of
// `@apply` recipe blocks (inside `@layer components { ... }`) and `@utility`
// blocks should be rewritten. The `:root` and `@theme` blocks must never be
// modified — they're the source of truth for the design tokens.
//
// This module exposes scopeCssContent(): given CSS source, return an array of
// [start, end) ranges that are safe to rewrite. Transforms can call
// `applyInEditableRanges(source, ranges, transformFn)` to scope edits.

const PROTECTED_BLOCKS = /(?:^|\s)(?::root|@theme|@theme inline|:root\[data-theme="light"\])\s*\{/g;

export function scopeCssContent(source) {
  // Walk top-level blocks (brace-balanced). Mark a block as "protected" if its
  // header matches PROTECTED_BLOCKS; otherwise mark it editable. Bodies of
  // protected blocks are excluded from edits.

  const editableRanges = []; // [start, end)
  const len = source.length;

  let i = 0;
  let editStart = 0;

  while (i < len) {
    const braceOpen = source.indexOf('{', i);
    if (braceOpen < 0) {
      // No more blocks — rest of file is editable.
      editableRanges.push([editStart, len]);
      break;
    }

    // Look back from braceOpen to extract the block header, but only as far as
    // the previous top-level boundary (start of file or matching close brace).
    const headerStart = lastTopLevelBoundary(source, braceOpen);
    const header = source.slice(headerStart, braceOpen);

    const isProtected = /(^|\s)(:root|@theme|@theme inline|:root\[data-theme="light"\])\s*$/.test(header);

    // Find the matching close brace.
    const close = matchClose(source, braceOpen);
    if (close < 0) {
      // Unbalanced — bail out and treat rest as editable.
      editableRanges.push([editStart, len]);
      break;
    }

    if (isProtected) {
      // Editable range up to the start of the protected block.
      if (editStart < headerStart) editableRanges.push([editStart, headerStart]);
      editStart = close + 1;
      i = close + 1;
    } else {
      // Whole block (including nested children) is editable; recurse via the
      // simple approach of leaving editStart unchanged.
      i = close + 1;
    }
  }

  if (editStart < len) editableRanges.push([editStart, len]);

  return { editableRanges };
}

function lastTopLevelBoundary(source, before) {
  // Scan backwards for the nearest `;` or `}` at top level, or start of file.
  let depth = 0;
  for (let j = before - 1; j >= 0; j--) {
    const ch = source[j];
    if (ch === '}') depth++;
    else if (ch === '{') depth--;
    if (depth === 0 && (ch === ';' || ch === '}')) return j + 1;
  }
  return 0;
}

function matchClose(source, openIdx) {
  let depth = 1;
  for (let j = openIdx + 1; j < source.length; j++) {
    const ch = source[j];
    if (ch === '{') depth++;
    else if (ch === '}') {
      depth--;
      if (depth === 0) return j;
    }
  }
  return -1;
}

// Apply `transformFn(text)` only to editable regions; concatenate.
export function applyInEditableRanges(source, ranges, transformFn) {
  if (!ranges.length) return source;
  const out = [];
  let cursor = 0;
  for (const [s, e] of ranges) {
    if (cursor < s) out.push(source.slice(cursor, s));   // protected pass-through
    out.push(transformFn(source.slice(s, e)));
    cursor = e;
  }
  if (cursor < source.length) out.push(source.slice(cursor));
  return out.join('');
}
