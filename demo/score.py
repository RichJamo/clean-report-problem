#!/usr/bin/env python3
"""Mechanical half of the scoring protocol in demo/SCORING.md.

This script decides ABSENT only. ABSENT is a string-search question and can be
automated without judgement. The EXAMINED / MENTIONED split and the DETECTED
call both require reading the surrounding text, so this script surfaces the
evidence and leaves those calls to a human.

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


def find_hits(text: str) -> dict[str, int]:
    lowered = text.lower()
    return {term: lowered.count(term.lower()) for term in ALL_TERMS if term.lower() in lowered}


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
        hits = find_hits(text)

        if not hits:
            verdict = "ABSENT"
            absent += 1
            detail = "no identity or accounting term present"
        else:
            verdict = "NOT-ABSENT (adjudicate EXAMINED vs MENTIONED by hand)"
            detail = ", ".join(f"{t}x{n}" for t, n in sorted(hits.items()))

        print(f"{path.name}\t{verdict}\t{detail}")

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
