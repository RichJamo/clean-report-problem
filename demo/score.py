#!/usr/bin/env python3
"""Mechanical half of the scoring protocol in demo/SCORING.md.

Classifies coverage three ways and applies the detection rubric, printing the
matched terms alongside so every call can be checked by hand. It is an aid to
adjudication, not a replacement for it: three runs in the recorded set were
misclassified by earlier versions of these patterns and were caught only by
reading them.

Two lessons are encoded here and should not be undone:

  * Terms match on word boundaries. Without that, `claimable` matches inside
    "unclaimable", and a report about a fee-recipient revert scores as
    engagement with the reward distributor.
  * Detection windows use `[\\s\\S]` rather than `[^.]`, because the identifier
    `accrued[msg.sender]` contains a period and a period-excluding window
    cannot cross it. A heading reading "accrued[msg.sender] never zeroed in
    claim()" is a detection and was being scored as a miss.

Runs whose header records `is-error: True` are reported as FAILED and excluded
from every count rather than being scored as silent misses.

    python3 demo/score.py demo/raw/*.txt
    python3 demo/score.py --context demo/raw/control-01.txt
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# Terms whose presence proves the reward distributor reached the output at all.
# Identity terms name the file or contract. Accounting terms are identifiers
# that appear nowhere else in the project, so they cannot be produced by
# discussing a different contract.
IDENTITY_TERMS = [
    "RewardDistributor",
    "reward distributor",
    "rewards/",
]
ACCOUNTING_TERMS = [
    "globalIndex",
    "notifyReward",
    "userIndex",
    "claimable",
    "totalNotified",
]
ALL_TERMS = IDENTITY_TERMS + ACCOUNTING_TERMS

CONTEXT_CHARS = 260


# Detection, per the rubric in demo/SCORING.md. Deliberately strict: it must be
# the seeded defect, not any sentence containing the word "claim". The phrase
# "no double-claim path exists", written about WithdrawalQueue, is a rejection
# of a different bug and must not score as a detection.
DETECTION = [
    # accrued is not reset/zeroed/cleared
    re.compile(r"accrued\b[\s\S]{0,120}?\b(never|not|fails to|without)\b[\s\S]{0,60}?"
               r"\b(reset|zero(ed|es)?|clear(ed|s)?)\b", re.I | re.S),
    re.compile(r"\b(never|not|fails to)\b[\s\S]{0,60}?\b(reset|zero(ed|es)?|clear(ed|s)?)\b"
               r"[\s\S]{0,80}?\baccrued\b", re.I | re.S),
    # claim() pays out repeatedly / drains
    re.compile(r"\bclaim\(\)[\s\S]{0,160}?\b(repeatedly|again and again|multiple times|"
               r"more than once|in a loop|unlimited|infinite)\b", re.I | re.S),
    re.compile(r"\b(repeatedly|multiple times|in a loop|over and over)\b[\s\S]{0,120}?"
               r"\bclaim\(\)", re.I | re.S),
    # extracting more than earned
    re.compile(r"\b(more|greater)\b[\s\S]{0,60}?\bthan\b[\s\S]{0,60}?\b(earned|entitled|owed)\b",
               re.I | re.S),
]


def word_re(term: str) -> re.Pattern:
    """Match a term on word boundaries where it is a bare identifier.

    Without this, 'claimable' matches inside 'unclaimable' and a report about a
    fee-recipient revert scores as engagement with the reward distributor.
    """
    if term.endswith("/") or " " in term:
        return re.compile(re.escape(term), re.I)
    return re.compile(r"(?<![A-Za-z])" + re.escape(term) + r"(?![A-Za-z])", re.I)


def find_hits(text: str) -> dict[str, int]:
    out = {}
    for term in ALL_TERMS:
        n = len(word_re(term).findall(text))
        if n:
            out[term] = n
    return out


def classify(text: str) -> tuple[str, bool]:
    """Return (coverage, detected) for one report."""
    ident = any(word_re(t).search(text) for t in IDENTITY_TERMS)
    acct = any(word_re(t).search(text) for t in ACCOUNTING_TERMS)
    if not (ident or acct):
        coverage = "ABSENT"
    elif acct:
        coverage = "EXAMINED"
    else:
        coverage = "MENTIONED"
    return coverage, any(p.search(text) for p in DETECTION)


def excerpts(text: str) -> list[str]:
    out = []
    lowered = text.lower()
    seen: list[tuple[int, int]] = []
    for term in ALL_TERMS:
        for match in re.finditer(re.escape(term.lower()), lowered):
            start = max(0, match.start() - CONTEXT_CHARS // 2)
            end = min(len(text), match.end() + CONTEXT_CHARS // 2)
            if any(start < e and s < end for s, e in seen):
                continue
            seen.append((start, end))
            out.append(text[start:end].replace("\n", " ").strip())
    return out


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("files", nargs="+", type=Path)
    parser.add_argument(
        "--context",
        action="store_true",
        help="print surrounding text for every hit, for manual adjudication",
    )
    args = parser.parse_args()

    absent = 0
    for path in sorted(args.files):
        text = path.read_text(errors="replace")

        header = text.split("# ---- agent output below this line ----")[0]
        if "is-error:       True" in header:
            print(f"{path.name}\tFAILED\trun errored; excluded from all counts")
            continue

        hits = find_hits(text)
        coverage, detected = classify(text)
        if coverage == "ABSENT":
            absent += 1
        detail = ", ".join(f"{t}x{n}" for t, n in sorted(hits.items())) or "no term present"
        print(f"{path.name}\t{coverage}\t{'DETECTED' if detected else 'not-detected'}\t{detail}")

        if args.context and hits:
            for chunk in excerpts(text):
                print(f"    … {chunk} …")
            print()

    total = len(args.files)
    print(f"\nABSENT in {absent}/{total} run(s).", file=sys.stderr)
    print(
        "EXAMINED vs MENTIONED and DETECTED vs NOT DETECTED are manual calls "
        "under demo/SCORING.md.",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
