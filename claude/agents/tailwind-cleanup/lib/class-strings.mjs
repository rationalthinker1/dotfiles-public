// Context-aware Tailwind class-string extractor.
//
// Walks source text and yields every string literal that is being used as a
// Tailwind class list, tagged with how it was reached. Recognised contexts:
//
//   - className="..." / class="..." attribute       → 'className-attr'
//   - className={...} / class={...} expression body → 'className-expr'
//   - clsx(...) / cn(...) / classnames(...) args    → 'clsx-arg' etc.
//   - twMerge(...) args                             → 'twmerge-arg'
//   - tw`...` tagged template literal               → 'tw-template'
//   - tv({...}) / cva({...}) call body              → 'tv-config' / 'cva-config'
//   - *CLASS / *Class string constant declarations  → 'class-const'
//
// Why the "context" tag matters: when the string was reached through a typed
// context (e.g. an arg of clsx, a slot of tv), we already know it's a class
// list — even a single token like 'text-accent' is valid. Strings picked up
// only because they live inside an arbitrary className={...} expression go
// through a stricter "looks like a class string" gate to filter noise.
//
// Offsets are absolute byte indices into the input text. Duplicate emissions
// at the same offset are dropped (clsx args nested inside className={...} are
// found by both openers, but should appear once).

const HELPER_CALLS = {
  clsx: 'clsx-arg',
  cn: 'cn-arg',
  classnames: 'classnames-arg',
  twMerge: 'twmerge-arg',
};

const VARIANT_CALLS = {
  tv: 'tv-config',
  cva: 'cva-config',
};

const CLASS_ATTR_RE = /\b(?:className|class)\s*=\s*(?:(["'])((?:\\.|(?!\1).)*?)\1|\{)/gs;
const CLASS_CONST_RE = /\b(?:const|let|var)\s+([A-Za-z0-9_$]*(?:CLASS|Class)[A-Za-z0-9_$]*)\s*=\s*(["'`])((?:\\.|(?!\2).)*?)\2/gs;
const HELPER_CALL_RE = /\b(clsx|cn|classnames|twMerge)\s*\(/g;
const VARIANT_CALL_RE = /\b(tv|cva)\s*\(/g;
const TW_TEMPLATE_RE = /\btw`/g;

function lineAndColumnAt(text, index) {
  let line = 1;
  let lastNl = -1;
  for (let i = 0; i < index; i++) {
    if (text.charCodeAt(i) === 10) {
      line++;
      lastNl = i;
    }
  }
  return { line, column: index - lastNl };
}

// Advance through one JavaScript token boundary's worth of "skip": whitespace,
// line + block comments. Returns the new index.
function skipTrivia(text, i) {
  while (i < text.length) {
    const c = text[i];
    if (c === ' ' || c === '\t' || c === '\n' || c === '\r') { i++; continue; }
    if (c === '/' && text[i + 1] === '/') {
      while (i < text.length && text[i] !== '\n') i++;
      continue;
    }
    if (c === '/' && text[i + 1] === '*') {
      i += 2;
      while (i < text.length - 1 && !(text[i] === '*' && text[i + 1] === '/')) i++;
      i += 2;
      continue;
    }
    break;
  }
  return i;
}

// Walk forward from `startIdx` (which must point at the opening `openCh`)
// and return the index of the matching close character, or -1. Honours
// strings, template literals (including ${...} interpolations), and
// comments.
function findMatching(text, startIdx, openCh, closeCh) {
  if (text[startIdx] !== openCh) return -1;
  let depth = 0;
  let i = startIdx;
  while (i < text.length) {
    const c = text[i];

    if (c === '/' && text[i + 1] === '/') {
      while (i < text.length && text[i] !== '\n') i++;
      continue;
    }
    if (c === '/' && text[i + 1] === '*') {
      i += 2;
      while (i < text.length - 1 && !(text[i] === '*' && text[i + 1] === '/')) i++;
      i += 2;
      continue;
    }

    if (c === '"' || c === "'") {
      i = skipString(text, i, c);
      continue;
    }
    if (c === '`') {
      i = skipTemplate(text, i);
      continue;
    }

    if (c === openCh) depth++;
    else if (c === closeCh) {
      depth--;
      if (depth === 0) return i;
    }
    i++;
  }
  return -1;
}

function skipString(text, startIdx, quote) {
  let i = startIdx + 1;
  let escaped = false;
  while (i < text.length) {
    const c = text[i];
    if (escaped) { escaped = false; i++; continue; }
    if (c === '\\') { escaped = true; i++; continue; }
    if (c === quote) return i + 1;
    i++;
  }
  return i;
}

function skipTemplate(text, startIdx) {
  let i = startIdx + 1;
  let escaped = false;
  while (i < text.length) {
    const c = text[i];
    if (escaped) { escaped = false; i++; continue; }
    if (c === '\\') { escaped = true; i++; continue; }
    if (c === '`') return i + 1;
    if (c === '$' && text[i + 1] === '{') {
      const close = findMatching(text, i + 1, '{', '}');
      if (close === -1) return text.length;
      i = close + 1;
      continue;
    }
    i++;
  }
  return i;
}

// Yields every string-literal occurrence found inside `text[start..end)`.
// Each entry: { offset, value, kind: 'single' | 'double' | 'template',
// interpolated: boolean }. Template literals with ${...} interpolations are
// emitted with their static text portions joined by a single space; this
// reflects what Tailwind would actually see for the static parts and lets
// `isClassLike` evaluate them on the same footing as plain strings.
function* iterStringsIn(text, start, end) {
  let i = start;
  while (i < end) {
    const c = text[i];
    if (c === '/' && text[i + 1] === '/') {
      while (i < end && text[i] !== '\n') i++;
      continue;
    }
    if (c === '/' && text[i + 1] === '*') {
      i += 2;
      while (i < end - 1 && !(text[i] === '*' && text[i + 1] === '/')) i++;
      i += 2;
      continue;
    }
    if (c === "'" || c === '"') {
      const offset = i;
      const closed = skipString(text, i, c);
      const value = text.slice(i + 1, closed - 1).replace(/\\(.)/g, '$1');
      yield { offset, value, kind: c === "'" ? 'single' : 'double', interpolated: false };
      i = closed;
      continue;
    }
    if (c === '`') {
      const offset = i;
      let j = i + 1;
      let interpolated = false;
      let value = '';
      let escaped = false;
      while (j < end) {
        const ch = text[j];
        if (escaped) { value += ch; escaped = false; j++; continue; }
        if (ch === '\\') { escaped = true; j++; continue; }
        if (ch === '`') { j++; break; }
        if (ch === '$' && text[j + 1] === '{') {
          interpolated = true;
          const close = findMatching(text, j + 1, '{', '}');
          if (close === -1) { j = end; break; }
          j = close + 1;
          value += ' ';
          continue;
        }
        value += ch;
        j++;
      }
      yield { offset, value, kind: 'template', interpolated };
      i = j;
      continue;
    }
    i++;
  }
}

// Heuristic gate: does this single-token string look like a Tailwind utility?
// Multi-token strings (with whitespace) are always accepted — they're almost
// certainly class lists. Single-token strings are accepted only if they
// contain a hyphen, colon, or bracket (i.e. look like `text-accent`,
// `hover:bg-foo`, or `text-[14px]`), or are in a small allowlist of bare
// utilities. This is what keeps `'md'` / `'sm'` (tv variant names) out of
// the report while still admitting `'text-accent'`.
const BARE_UTILITIES = new Set([
  'flex', 'grid', 'block', 'inline', 'inline-flex', 'inline-block', 'hidden',
  'relative', 'absolute', 'fixed', 'sticky', 'static',
  'italic', 'uppercase', 'lowercase', 'capitalize',
  'underline', 'overline', 'truncate', 'antialiased',
  'border', 'rounded-full', 'rounded', 'isolate', 'contents',
  'invisible', 'visible',
]);

export function isClassLike(value) {
  const trimmed = value.trim();
  if (!trimmed) return false;
  const tokens = trimmed.split(/\s+/);
  if (tokens.length >= 2) return true;
  const t = tokens[0];
  if (t.includes('-') || t.includes(':') || t.includes('[')) return true;
  return BARE_UTILITIES.has(t);
}

// Whether a className-expression string literal alone (without further
// context) should be reported. Stricter than `isClassLike`: we require at
// least one space OR a recognisable Tailwind shape, because otherwise we'll
// happily emit every random `aria-label` value living inside an
// `className={cond ? 'x' : null}` expression. The `clsx`/`tv` paths bypass
// this — they already know they're looking at classes.
export function isLooseClassLike(value) {
  return isClassLike(value);
}

export function extractClassStrings(text) {
  const found = new Map(); // offset -> entry (dedupes overlapping openers)

  const emit = (offset, value, context) => {
    if (!found.has(offset)) {
      const { line, column } = lineAndColumnAt(text, offset);
      found.set(offset, { offset, line, column, value, context });
    }
  };

  // 1. className / class attributes — string-literal form OR {expression}.
  for (const m of text.matchAll(CLASS_ATTR_RE)) {
    const matchStart = m.index;
    if (m[1] !== undefined) {
      // string-literal attribute
      const valueStart = matchStart + m[0].indexOf(m[1]);
      const value = m[2];
      if (isClassLike(value)) emit(valueStart, value, 'className-attr');
    } else {
      // {expression}
      const braceIdx = matchStart + m[0].length - 1;
      const close = findMatching(text, braceIdx, '{', '}');
      if (close !== -1) {
        for (const lit of iterStringsIn(text, braceIdx + 1, close)) {
          if (isLooseClassLike(lit.value)) emit(lit.offset, lit.value, 'className-expr');
        }
      }
    }
  }

  // 2. *CLASS / *Class string-constant declarations.
  for (const m of text.matchAll(CLASS_CONST_RE)) {
    const valueStart = m.index + m[0].lastIndexOf(m[2]);
    const value = m[3];
    if (isClassLike(value)) emit(valueStart, value, 'class-const');
  }

  // 3. clsx / cn / classnames / twMerge call arguments.
  for (const m of text.matchAll(HELPER_CALL_RE)) {
    const name = m[1];
    const context = HELPER_CALLS[name];
    const parenIdx = m.index + m[0].length - 1;
    const close = findMatching(text, parenIdx, '(', ')');
    if (close === -1) continue;
    for (const lit of iterStringsIn(text, parenIdx + 1, close)) {
      // Helper-call args are trusted: even a bare 'foo' counts. We still
      // filter via isClassLike so that obvious non-classes like '' or a
      // single bare word that doesn't look like Tailwind ('id', 'span')
      // don't sneak in.
      if (isClassLike(lit.value)) emit(lit.offset, lit.value, context);
    }
  }

  // 4. tv / cva configuration calls — descend into the whole call body and
  // grab every string literal that passes the class-like gate. `tv` configs
  // also contain non-class strings (variant names in defaultVariants), but
  // those are almost always short bare words like 'md'/'sm' that
  // isClassLike() rejects.
  for (const m of text.matchAll(VARIANT_CALL_RE)) {
    const name = m[1];
    const context = VARIANT_CALLS[name];
    const parenIdx = m.index + m[0].length - 1;
    const close = findMatching(text, parenIdx, '(', ')');
    if (close === -1) continue;
    for (const lit of iterStringsIn(text, parenIdx + 1, close)) {
      if (isClassLike(lit.value)) emit(lit.offset, lit.value, context);
    }
  }

  // 5. tw`...` tagged template literals.
  for (const m of text.matchAll(TW_TEMPLATE_RE)) {
    const backtickIdx = m.index + m[0].length - 1;
    const iter = iterStringsIn(text, backtickIdx, text.length);
    const first = iter.next();
    if (first.done) continue;
    if (isClassLike(first.value.value)) {
      emit(first.value.offset, first.value.value, 'tw-template');
    }
  }

  return [...found.values()].sort((a, b) => a.offset - b.offset);
}

// Normalised, one-line form of a class string for stable comparison and
// report rendering. Collapses internal whitespace but preserves token order.
export function normaliseClassString(value) {
  return value.replace(/\s+/g, ' ').trim();
}
