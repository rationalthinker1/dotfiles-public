#!/usr/bin/env python3

"""
Tailwind className similarity audit.

What it does:
- Searches React/TSX/JSX/Vue files for static className="..." and class="..." strings
- Also scans string literals inside className={...} / class={...} expressions, including clsx/cn calls
- Scans simple constants with CLASS in the name, e.g. INPUT_CLASS = "..."
- Splits class strings into Tailwind utility arrays
- Compares class arrays for:
  - exact utility overlap
  - near numeric similarity, e.g. text-[32px] ≈ text-[33px]
- Groups repeated / near-repeated patterns
- Outputs top extraction candidates for CSS utility consolidation

Usage:
  python className_duplicates.py /path/to/project
  python className_duplicates.py --format json --output className_duplicates_report.json
  python className_duplicates.py --format csv --output className_duplicates_report.csv
  python className_duplicates.py

Notes:
- This intentionally focuses on static strings and string-literal fragments.
- It does not execute JavaScript or fully parse template expressions.
"""

from __future__ import annotations

import argparse
import csv
import itertools
import json
import math
import re
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


# -----------------------------
# Config
# -----------------------------

FILE_EXTENSIONS = {
    ".tsx",
    ".ts",
    ".jsx",
    ".js",
    ".vue",
}

# Baseline ignores — directories never worth scanning regardless of project.
# Project-specific excludes (e.g. "src/styles") are merged in from the
# tailwind-cleanup.config.json at load time.
IGNORE_DIR_PARTS = {
    "node_modules",
    ".git",
    "dist",
    "build",
    ".next",
    "coverage",
}

# Path-substring blocklist. Populated from `scan.excludeDirs` in config when
# loaded via load_project_config(). Kept as a set for O(1) membership.
IGNORE_PATH_CONTAINS: set[str] = set()

MIN_SHARED_UTILITIES = 4
MIN_OCCURRENCES_ANYWHERE = 5
MIN_FILES_FOR_LONG_PATTERN = 3

# Numeric closeness tolerances.
# Example: text-[32px] and text-[33px] are considered similar.
ABS_NUMERIC_TOLERANCE = 2.0

# Percentage-based tolerance for larger values.
# Example: w-[240px] and w-[248px] are similar because 8px is ~3.3%.
REL_NUMERIC_TOLERANCE = 0.06

TOP_N = 25


# -----------------------------
# Data models
# -----------------------------

@dataclass(frozen=True)
class ClassOccurrence:
    file: str
    line: int
    raw: str
    utilities: tuple[str, ...]


@dataclass(frozen=True)
class UtilityMatch:
    a: str
    b: str
    canonical: str
    exact: bool


# -----------------------------
# Extraction
# -----------------------------

CLASS_ATTR_RE = re.compile(
    r"""
    (?P<attr>
        className
        |
        class
    )
    \s*=\s*
    (?P<quote>["'])
    (?P<value>.*?)
    (?P=quote)
    """,
    re.VERBOSE | re.DOTALL,
)

CLASS_EXPR_START_RE = re.compile(r"\b(?:className|class)\s*=\s*\{")

# Helper / variant calls whose string-literal arguments are class lists by
# definition. Matched at the call site; the scanner balances parens and pulls
# every string literal out of the call body. `tv` and `cva` configs can also
# carry non-class strings (variant names like 'md'); those get filtered later
# by the existing class-string heuristic.
HELPER_CALL_START_RE = re.compile(r"\b(clsx|cn|classnames|twMerge|tv|cva)\s*\(")

# tw`...` tagged template literal opener.
TW_TEMPLATE_START_RE = re.compile(r"\btw`")

CLASS_CONSTANT_RE = re.compile(
    r"""
    \b(?:const|let|var)\s+
    (?P<name>[A-Za-z0-9_$]*CLASS[A-Za-z0-9_$]*|[A-Za-z0-9_$]*Class[A-Za-z0-9_$]*)
    \s*=\s*
    (?P<quote>["'`])
    (?P<value>.*?)
    (?P=quote)
    """,
    re.VERBOSE | re.DOTALL,
)


def should_scan_file(path: Path) -> bool:
    if path.suffix not in FILE_EXTENSIONS:
        return False

    parts = set(path.parts)
    if parts & IGNORE_DIR_PARTS:
        return False

    normalized = str(path).replace("\\", "/")
    for ignored in IGNORE_PATH_CONTAINS:
        if ignored in normalized:
            return False

    return True


def iter_source_files(root: Path) -> Iterable[Path]:
    for path in root.rglob("*"):
        if path.is_file() and should_scan_file(path):
            yield path


def line_number_for_index(text: str, index: int) -> int:
    return text.count("\n", 0, index) + 1


def split_classes(class_string: str) -> tuple[str, ...]:
    return tuple(x.strip() for x in class_string.split() if x.strip())


def normalize_class_string(class_string: str) -> str:
    return " ".join(class_string.split())


def looks_like_class_string(value: str) -> bool:
    raw = normalize_class_string(value)

    if " " not in raw:
        return False

    if "${" in raw:
        return False

    utilities = split_classes(raw)

    if len(utilities) < 2:
        return False

    utility_like = 0
    for utility in utilities:
        if re.search(r"[:\[\]-]", utility) or utility in {
            "flex",
            "grid",
            "block",
            "inline-flex",
            "hidden",
            "relative",
            "absolute",
            "fixed",
            "sticky",
            "items-center",
            "justify-center",
            "rounded-full",
            "border",
            "uppercase",
            "italic",
        }:
            utility_like += 1

    return utility_like >= 2


def find_matching_brace(text: str, open_index: int) -> int | None:
    return find_matching_delim(text, open_index, "{", "}")


def find_matching_delim(text: str, open_index: int, open_char: str, close_char: str) -> int | None:
    """Find the matching close for a delimiter at open_index, ignoring delimiters
    that appear inside string / template-literal contents."""
    depth = 0
    quote: str | None = None
    escaped = False

    for index in range(open_index, len(text)):
        char = text[index]

        if quote:
            if escaped:
                escaped = False
                continue

            if char == "\\":
                escaped = True
                continue

            if char == quote:
                quote = None

            continue

        if char in "\"'`":
            quote = char
            continue

        if char == open_char:
            depth += 1
            continue

        if char == close_char:
            depth -= 1

            if depth == 0:
                return index

    return None


def find_matching_backtick(text: str, open_index: int) -> int | None:
    """Find the closing backtick of a template literal that starts at open_index.
    Skips ${...} interpolations so nested braces don't terminate the string."""
    if text[open_index] != "`":
        return None
    index = open_index + 1
    escaped = False
    while index < len(text):
        char = text[index]
        if escaped:
            escaped = False
            index += 1
            continue
        if char == "\\":
            escaped = True
            index += 1
            continue
        if char == "$" and index + 1 < len(text) and text[index + 1] == "{":
            close = find_matching_delim(text, index + 1, "{", "}")
            if close is None:
                return None
            index = close + 1
            continue
        if char == "`":
            return index
        index += 1
    return None


def iter_string_literals(text: str) -> Iterable[tuple[int, str]]:
    index = 0

    while index < len(text):
        quote = text[index]

        if quote not in "\"'`":
            index += 1
            continue

        start = index
        index += 1
        escaped = False
        value_chars: list[str] = []

        while index < len(text):
            char = text[index]

            if escaped:
                value_chars.append(char)
                escaped = False
                index += 1
                continue

            if char == "\\":
                escaped = True
                index += 1
                continue

            if char == quote:
                index += 1
                break

            value_chars.append(char)
            index += 1

        yield start, "".join(value_chars)


def add_occurrence(
    occurrences: list[ClassOccurrence],
    root: Path,
    path: Path,
    text: str,
    start: int,
    raw_value: str,
    seen: set[tuple[str, int]] | None = None,
) -> None:
    raw = normalize_class_string(raw_value)
    utilities = split_classes(raw)

    if len(utilities) < MIN_SHARED_UTILITIES:
        return

    # The same string literal can be reached by more than one opener
    # (a string inside clsx(...) inside className={...} is matched by both
    # passes). Dedupe on (file, byte offset) so clustering doesn't see the
    # same source location twice.
    rel_file = str(path.relative_to(root))
    key = (rel_file, start)
    if seen is not None:
        if key in seen:
            return
        seen.add(key)

    occurrences.append(
        ClassOccurrence(
            file=rel_file,
            line=line_number_for_index(text, start),
            raw=raw,
            utilities=utilities,
        )
    )


def extract_occurrences(root: Path) -> list[ClassOccurrence]:
    occurrences: list[ClassOccurrence] = []

    for path in iter_source_files(root):
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue

        seen: set[tuple[str, int]] = set()

        for match in CLASS_ATTR_RE.finditer(text):
            value_offset = match.start("value")
            add_occurrence(
                occurrences,
                root,
                path,
                text,
                value_offset,
                match.group("value"),
                seen,
            )

        for match in CLASS_CONSTANT_RE.finditer(text):
            add_occurrence(
                occurrences,
                root,
                path,
                text,
                match.start(),
                match.group("value"),
                seen,
            )

        for match in CLASS_EXPR_START_RE.finditer(text):
            open_index = text.find("{", match.start())
            close_index = find_matching_brace(text, open_index)

            if close_index is None:
                continue

            expression = text[open_index + 1 : close_index]
            expression_start = open_index + 1

            for literal_start, value in iter_string_literals(expression):
                if looks_like_class_string(value):
                    add_occurrence(
                        occurrences,
                        root,
                        path,
                        text,
                        expression_start + literal_start,
                        value,
                        seen,
                    )

        # Helper / variant calls: clsx(...), cn(...), classnames(...),
        # twMerge(...), tv(...), cva(...). Any string literal inside the call
        # body is treated as a class string (no looks_like_class_string gate),
        # because the context already guarantees class-ness. Filtering still
        # happens at add_occurrence via MIN_SHARED_UTILITIES.
        for match in HELPER_CALL_START_RE.finditer(text):
            paren_index = match.end() - 1
            close_index = find_matching_delim(text, paren_index, "(", ")")
            if close_index is None:
                continue

            body = text[paren_index + 1 : close_index]
            body_start = paren_index + 1

            for literal_start, value in iter_string_literals(body):
                add_occurrence(
                    occurrences,
                    root,
                    path,
                    text,
                    body_start + literal_start,
                    value,
                    seen,
                )

        # tw`...` tagged template literals. Static text between the backticks
        # is the class list. ${...} interpolations are skipped by
        # find_matching_backtick but their dynamic content is not extractable.
        for match in TW_TEMPLATE_START_RE.finditer(text):
            tick_index = match.end() - 1
            close_index = find_matching_backtick(text, tick_index)
            if close_index is None:
                continue
            raw_value = text[tick_index + 1 : close_index]
            # An interpolation leaves "${...}" verbatim in raw_value; let
            # looks_like_class_string filter that out via its `"${" in raw` rule.
            if looks_like_class_string(raw_value):
                add_occurrence(
                    occurrences,
                    root,
                    path,
                    text,
                    tick_index,
                    raw_value,
                    seen,
                )

    return occurrences


# -----------------------------
# Tailwind utility normalization
# -----------------------------

NUMERIC_BRACKET_RE = re.compile(
    r"""
    ^
    (?P<prefix>
        (?:[a-z0-9-]+:)*
        -?
        [a-zA-Z0-9_/.-]+-
    )
    \[
        (?P<number>-?\d+(?:\.\d+)?)
        (?P<unit>[a-zA-Z%]*)
    \]
    (?P<suffix>.*)
    $
    """,
    re.VERBOSE,
)

NUMERIC_STANDARD_RE = re.compile(
    r"""
    ^
    (?P<prefix>
        (?:[a-z0-9-]+:)*
        -?
        [a-zA-Z0-9_/.-]+-
    )
    (?P<number>-?\d+(?:\.\d+)?)
    (?P<suffix>
        (?:\/\d+)?
        .*
    )
    $
    """,
    re.VERBOSE,
)


def parse_numeric_utility(utility: str):
    """
    Parses utilities like:
      text-[32px]
      mt-[15px]
      rounded-[11px]
      w-64
      gap-2.5

    Returns:
      (family_prefix, number, unit, suffix)

    Or None if not numeric.
    """

    bracket = NUMERIC_BRACKET_RE.match(utility)
    if bracket:
        return (
            bracket.group("prefix"),
            float(bracket.group("number")),
            bracket.group("unit") or "",
            bracket.group("suffix") or "",
        )

    standard = NUMERIC_STANDARD_RE.match(utility)
    if standard:
        return (
            standard.group("prefix"),
            float(standard.group("number")),
            "",
            standard.group("suffix") or "",
        )

    return None


def numbers_are_close(a: float, b: float) -> bool:
    diff = abs(a - b)

    if diff <= ABS_NUMERIC_TOLERANCE:
        return True

    larger = max(abs(a), abs(b), 1.0)
    return diff / larger <= REL_NUMERIC_TOLERANCE


def utilities_are_similar(a: str, b: str) -> UtilityMatch | None:
    """
    Returns a UtilityMatch if utilities are exact or near-numeric variants.
    """

    if a == b:
        return UtilityMatch(a=a, b=b, canonical=a, exact=True)

    parsed_a = parse_numeric_utility(a)
    parsed_b = parse_numeric_utility(b)

    if not parsed_a or not parsed_b:
        return None

    prefix_a, number_a, unit_a, suffix_a = parsed_a
    prefix_b, number_b, unit_b, suffix_b = parsed_b

    # Must belong to same utility family.
    # text-[32px] can match text-[33px].
    # But text-[32px] should not match w-[32px].
    if prefix_a != prefix_b:
        return None

    # Units must match.
    # text-[2rem] should not match text-[32px].
    if unit_a != unit_b:
        return None

    # Suffix must match.
    # bg-red-500/20 should not be treated as same as bg-red-500/80.
    if suffix_a != suffix_b:
        return None

    if not numbers_are_close(number_a, number_b):
        return None

    canonical = f"{prefix_a}[~{round((number_a + number_b) / 2, 2)}{unit_a}]{suffix_a}"

    return UtilityMatch(a=a, b=b, canonical=canonical, exact=False)


# -----------------------------
# Similarity scoring
# -----------------------------

GENERIC_PATTERNS = {
    frozenset(["flex", "items-center"]),
    frozenset(["grid", "gap-4"]),
    frozenset(["text-sm", "font-medium"]),
    frozenset(["relative", "overflow-hidden"]),
}


def best_shared_utilities(
    left: tuple[str, ...],
    right: tuple[str, ...],
) -> list[UtilityMatch]:
    """
    Greedy matching between two class utility arrays.

    This avoids double-matching the same utility from the right side.
    """

    matches: list[UtilityMatch] = []
    used_right_indexes: set[int] = set()

    for a in left:
        best_index = None
        best_match = None

        for idx, b in enumerate(right):
            if idx in used_right_indexes:
                continue

            match = utilities_are_similar(a, b)
            if not match:
                continue

            # Prefer exact matches over numeric-near matches.
            if best_match is None or match.exact:
                best_index = idx
                best_match = match

            if match.exact:
                break

        if best_index is not None and best_match is not None:
            used_right_indexes.add(best_index)
            matches.append(best_match)

    return matches


def similarity_score(
    left: tuple[str, ...],
    right: tuple[str, ...],
) -> tuple[float, list[UtilityMatch]]:
    matches = best_shared_utilities(left, right)

    if not matches:
        return 0.0, []

    smaller_len = min(len(left), len(right))
    score = len(matches) / smaller_len

    return score, matches


def utility_family(utility: str) -> str:
    parsed = parse_numeric_utility(utility)

    if parsed:
        prefix, _number, unit, suffix = parsed
        return f"numeric:{prefix}:{unit}:{suffix}"

    return f"literal:{utility}"


def occurrence_families(occurrence: ClassOccurrence) -> frozenset[str]:
    return frozenset(utility_family(utility) for utility in occurrence.utilities)


def looks_too_generic(shared: tuple[str, ...]) -> bool:
    shared_set = frozenset(shared)

    for generic in GENERIC_PATTERNS:
        if generic.issubset(shared_set) and len(shared_set) <= 3:
            return True

    if len(shared_set) < MIN_SHARED_UTILITIES:
        return True

    return False


# -----------------------------
# Candidate grouping
# -----------------------------

def canonical_pattern(matches: list[UtilityMatch]) -> tuple[str, ...]:
    """
    Exact utilities stay exact.
    Near numeric variants become a fuzzy canonical token.
    """

    return tuple(sorted(dict.fromkeys(match.canonical for match in matches)))


def dedupe_report_patterns(
    ranked: list[tuple[tuple[str, ...], list[ClassOccurrence]]],
) -> list[tuple[tuple[str, ...], list[ClassOccurrence]]]:
    selected: list[tuple[tuple[str, ...], list[ClassOccurrence]]] = []

    def compact_token(token: str) -> str:
        fuzzy = re.match(
            r"^(?P<prefix>.+-)\[~[-0-9.]+(?P<unit>[a-zA-Z%]*)\](?P<suffix>.*)$",
            token,
        )
        if fuzzy:
            return f"{fuzzy.group('prefix')}[~{fuzzy.group('unit')}]{fuzzy.group('suffix')}"

        parsed = parse_numeric_utility(token)
        if parsed:
            prefix, _number, unit, suffix = parsed
            return f"{prefix}[~{unit}]{suffix}"

        return token

    for pattern, items in ranked:
        pattern_set = {compact_token(token) for token in pattern}

        is_duplicate = False
        for selected_pattern, _ in selected:
            selected_set = {compact_token(token) for token in selected_pattern}
            overlap = len(pattern_set & selected_set)
            smaller = min(len(pattern_set), len(selected_set))

            if smaller and overlap / smaller >= 0.82:
                is_duplicate = True
                break

        if not is_duplicate:
            selected.append((pattern, items))

        if len(selected) >= TOP_N:
            break

    return selected


def find_candidate_patterns(
    occurrences: list[ClassOccurrence],
) -> dict[tuple[str, ...], list[ClassOccurrence]]:
    grouped: dict[tuple[str, ...], list[ClassOccurrence]] = defaultdict(list)
    family_cache = {occurrence: occurrence_families(occurrence) for occurrence in occurrences}

    for left, right in itertools.combinations(occurrences, 2):
        shared_families = family_cache[left] & family_cache[right]

        if len(shared_families) < MIN_SHARED_UTILITIES:
            continue

        score, matches = similarity_score(left.utilities, right.utilities)

        if score < 0.65:
            continue

        pattern = canonical_pattern(matches)

        if looks_too_generic(pattern):
            continue

        grouped[pattern].append(left)
        grouped[pattern].append(right)

    # Deduplicate occurrences per pattern.
    deduped: dict[tuple[str, ...], list[ClassOccurrence]] = {}

    for pattern, items in grouped.items():
        unique = {}
        for item in items:
            key = (item.file, item.line, item.raw)
            unique[key] = item

        deduped[pattern] = list(unique.values())

    # Apply thresholds.
    filtered: dict[tuple[str, ...], list[ClassOccurrence]] = {}

    for pattern, items in deduped.items():
        files = {x.file for x in items}
        occurrence_count = len(items)

        if occurrence_count >= MIN_OCCURRENCES_ANYWHERE:
            filtered[pattern] = items
            continue

        if len(pattern) >= 6 and len(files) >= MIN_FILES_FOR_LONG_PATTERN:
            filtered[pattern] = items
            continue

    return filtered


# -----------------------------
# Naming heuristics
# -----------------------------

def propose_name(pattern: tuple[str, ...]) -> str:
    joined = " ".join(pattern)

    if "uppercase" in pattern and "text-text-muted" in pattern and "font-3" in pattern:
        return ".eyebrow-muted"

    if "font-2" in pattern and "italic" in pattern:
        return ".title-display"

    if "font-1" in pattern and "leading-" in joined and "text-color" in joined:
        return ".body-copy"

    if "rounded-full" in pattern and "inline-flex" in pattern:
        if "uppercase" in pattern or "tracking" in joined:
            return ".pill-status"
        return ".chip-primary"

    if "border" in pattern and any("bg-" in x for x in pattern) and any("rounded" in x for x in pattern):
        return ".card-surface"

    if "fixed" in pattern or "absolute" in pattern:
        if "inset" in joined:
            return ".overlay-panel"
        return ".floating-panel"

    if "border-t" in pattern and ("justify-end" in pattern or "items-center" in pattern):
        return ".modal-footer"

    if "w-4" in pattern and "h-4" in pattern and "rounded-full" in pattern:
        return ".button-icon-close"

    if "text-" in joined and ("font-semibold" in pattern or "font-bold" in pattern):
        return ".title-section"

    if "mx-auto" in pattern and any(x.startswith("max-w-") for x in pattern):
        return ".container-page"

    if "hover:" in joined and ("px-" in joined or "py-" in joined):
        return ".nav-item"

    return ".utility-extracted-pattern"


# -----------------------------
# Reporting
# -----------------------------

def pattern_quality_score(pattern: tuple[str, ...], items: list[ClassOccurrence]) -> float:
    file_count = len({x.file for x in items})
    occurrence_count = len(items)
    length_score = len(pattern)
    return occurrence_count * 2 + file_count * 3 + length_score


def summarize_variants(
    pattern: tuple[str, ...],
    items: list[ClassOccurrence],
) -> list[str]:
    pattern_set = set(pattern)
    counter = Counter()

    for item in items:
        for utility in item.utilities:
            if utility not in pattern_set:
                counter[utility] += 1

    return [x for x, _ in counter.most_common(8)]


def rank_candidates(
    candidates: dict[tuple[str, ...], list[ClassOccurrence]],
) -> list[tuple[tuple[str, ...], list[ClassOccurrence]]]:
    ranked = sorted(
        candidates.items(),
        key=lambda x: pattern_quality_score(x[0], x[1]),
        reverse=True,
    )
    return dedupe_report_patterns(ranked)


def candidate_records(
    candidates: dict[tuple[str, ...], list[ClassOccurrence]],
) -> list[dict[str, object]]:
    records: list[dict[str, object]] = []

    for index, (pattern, items) in enumerate(rank_candidates(candidates), start=1):
        files = sorted({x.file for x in items})
        examples = items[:4]
        variants = summarize_variants(pattern, items)

        records.append(
            {
                "rank": index,
                "proposed_name": propose_name(pattern),
                "pattern": list(pattern),
                "pattern_text": " ".join(pattern),
                "occurrences": len(items),
                "file_count": len(files),
                "files": files,
                "examples": [
                    {
                        "file": item.file,
                        "line": item.line,
                        "raw": item.raw,
                    }
                    for item in examples
                ],
                "common_variant_utilities": variants,
                "quality_score": pattern_quality_score(pattern, items),
                "rationale": "Repeated long visual pattern with enough overlap to justify extracting into a reusable class.",
            }
        )

    return records


def write_json_report(
    records: list[dict[str, object]],
    scanned_count: int,
    output_path: Path | None,
) -> None:
    payload = {
        "summary": {
            "scanned_static_class_strings": scanned_count,
            "candidate_count": len(records),
            "near_numeric_matching": True,
            "absolute_numeric_tolerance": ABS_NUMERIC_TOLERANCE,
            "relative_numeric_tolerance": REL_NUMERIC_TOLERANCE,
        },
        "candidates": records,
    }
    content = json.dumps(payload, indent=2)

    if output_path:
        output_path.write_text(content + "\n", encoding="utf-8")
    else:
        print(content)


def write_csv_report(
    records: list[dict[str, object]],
    output_path: Path | None,
) -> None:
    fieldnames = [
        "rank",
        "proposed_name",
        "pattern_text",
        "occurrences",
        "file_count",
        "files",
        "examples",
        "common_variant_utilities",
        "quality_score",
        "rationale",
    ]

    output_file = output_path.open("w", newline="", encoding="utf-8") if output_path else sys.stdout

    try:
        writer = csv.DictWriter(output_file, fieldnames=fieldnames)
        writer.writeheader()

        for record in records:
            writer.writerow(
                {
                    "rank": record["rank"],
                    "proposed_name": record["proposed_name"],
                    "pattern_text": record["pattern_text"],
                    "occurrences": record["occurrences"],
                    "file_count": record["file_count"],
                    "files": "; ".join(record["files"]),
                    "examples": "; ".join(
                        f"{example['file']}:{example['line']}"
                        for example in record["examples"]
                    ),
                    "common_variant_utilities": " ".join(record["common_variant_utilities"]),
                    "quality_score": record["quality_score"],
                    "rationale": record["rationale"],
                }
            )
    finally:
        if output_path:
            output_file.close()


def print_report(candidates: dict[tuple[str, ...], list[ClassOccurrence]]) -> None:
    ranked = rank_candidates(candidates)

    print("# Tailwind Class Extraction Candidates\n")

    if not ranked:
        print("No strong candidates found using the current thresholds.")
        return

    for index, (pattern, items) in enumerate(ranked, start=1):
        proposed_name = propose_name(pattern)
        files = sorted({x.file for x in items})
        examples = items[:4]
        variants = summarize_variants(pattern, items)

        print(f"## {index}. `{proposed_name}`\n")

        print("Pattern:")
        print("```text")
        print(" ".join(pattern))
        print("```\n")

        print(
            f"Approximate occurrences: {len(items)} occurrences across {len(files)} files\n"
        )

        print("Example call sites:")
        for item in examples:
            print(f"- `{item.file}:{item.line}`")
        print()

        if variants:
            print("Common variant utilities:")
            print("```text")
            print(" ".join(variants))
            print("```\n")

        print(
            "Rationale: repeated long visual pattern with enough overlap to justify extracting into a reusable `@apply` class.\n"
        )


# -----------------------------
# Main
# -----------------------------

def load_project_config(config_path: Path) -> dict:
    """Load tailwind-cleanup.config.json and merge its scan.excludeDirs into the
    module-level IGNORE_PATH_CONTAINS set."""
    try:
        cfg = json.loads(config_path.read_text(encoding="utf-8"))
    except Exception as e:
        print(f"tw-cleanup duplicates: failed to read {config_path}: {e}",
              file=sys.stderr)
        return {}
    scan = cfg.get("scan", {}) or {}
    for d in scan.get("excludeDirs", []) or []:
        # Bare names go into IGNORE_DIR_PARTS; path-containing entries into IGNORE_PATH_CONTAINS.
        if "/" in d or "\\" in d:
            IGNORE_PATH_CONTAINS.add(d.replace("\\", "/"))
        else:
            IGNORE_DIR_PARTS.add(d)
    for f in scan.get("excludeFiles", []) or []:
        # We use IGNORE_PATH_CONTAINS for files too; a basename match is fine.
        IGNORE_PATH_CONTAINS.add(f)
    return cfg


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Audit repeated and near-repeated Tailwind className patterns.",
    )
    parser.add_argument(
        "root",
        nargs="?",
        default=None,
        help="Project root to scan. Defaults to TW_CLEANUP_CONFIG's directory, "
             "or the current directory.",
    )
    parser.add_argument(
        "--format",
        choices=("markdown", "json", "csv", "both"),
        default=None,
        help="Report format. Defaults to TW_CLEANUP_REPORT or 'markdown'.",
    )
    parser.add_argument(
        "--output",
        help="Optional output file. Defaults to TW_CLEANUP_REPORTS_DIR/duplicates.* "
             "or stdout.",
    )
    parser.add_argument(
        "--config",
        help="Path to tailwind-cleanup.config.json. Falls back to "
             "TW_CLEANUP_CONFIG env var, then cwd/tailwind-cleanup.config.json.",
    )
    args = parser.parse_args()

    # Resolve config: CLI > env > cwd.
    import os
    config_path_str = args.config or os.environ.get("TW_CLEANUP_CONFIG")
    cfg = {}
    if config_path_str:
        cp = Path(config_path_str).resolve()
        if cp.exists():
            cfg = load_project_config(cp)
    else:
        cwd_cfg = Path.cwd() / "tailwind-cleanup.config.json"
        if cwd_cfg.exists():
            cfg = load_project_config(cwd_cfg)

    # Resolve root: CLI > config-relative > cwd.
    if args.root:
        root = Path(args.root).resolve()
    elif config_path_str:
        root = Path(config_path_str).resolve().parent
    else:
        root = Path.cwd().resolve()

    if not root.exists():
        print(f"Path does not exist: {root}")
        return 1

    # Resolve format and output.
    fmt = args.format or os.environ.get("TW_CLEANUP_REPORT") or "markdown"
    reports_dir_env = os.environ.get("TW_CLEANUP_REPORTS_DIR")
    if args.output:
        output_path = Path(args.output).resolve()
    elif reports_dir_env:
        reports_dir = Path(reports_dir_env)
        reports_dir.mkdir(parents=True, exist_ok=True)
        output_path = reports_dir / "duplicates"   # extension added below
    else:
        output_path = None

    occurrences = extract_occurrences(root)

    print(f"Scanned static class strings: {len(occurrences)}\n", file=sys.stderr)

    candidates = find_candidate_patterns(occurrences)

    def write_one(format_name: str, base: Path | None) -> None:
        ext = {"markdown": ".md", "json": ".json", "csv": ".csv"}[format_name]
        target = base.with_suffix(ext) if base and base.suffix == "" else (
            base if base else None
        )
        # When base already carries a suffix, only emit if it matches.
        if target and target.suffix and target.suffix != ext:
            return
        if format_name == "json":
            write_json_report(candidate_records(candidates), len(occurrences), target)
        elif format_name == "csv":
            write_csv_report(candidate_records(candidates), target)
        else:
            if target:
                original_stdout = sys.stdout
                with target.open("w", encoding="utf-8") as output_file:
                    sys.stdout = output_file
                    try: print_report(candidates)
                    finally: sys.stdout = original_stdout
            else:
                print_report(candidates)

    if fmt == "both":
        write_one("markdown", output_path)
        write_one("json", output_path)
    else:
        write_one(fmt, output_path)

    if output_path:
        print(f"audit:duplicates — Report: {output_path.parent}/{output_path.stem}.* (fmt={fmt})",
              file=sys.stderr)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
