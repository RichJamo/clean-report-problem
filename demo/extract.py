#!/usr/bin/env python3
"""Turn one stream-json transcript into the committed raw record for a run.

Emits two files next to the transcript:

  <stem>.txt    a header of run metadata followed by the agent's final report
  <stem>.files  every distinct path the agent opened, one per line

The .files list is a supplementary, objective coverage signal: it records what
the agent actually read, independently of what its report says. The primary
measure in demo/SCORING.md remains the text of the report.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path


def read_events(path: Path) -> list[dict]:
    events = []
    for line in path.read_text(errors="replace").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return events


def sandbox_prefixes(sandbox: str) -> list[str]:
    """Every spelling of the sandbox root a tool call might report.

    On macOS mktemp returns /var/... while the agent resolves and reports
    /private/var/..., so a single prefix does not match.
    """
    candidates = {sandbox, str(Path(sandbox).resolve())}
    for path in list(candidates):
        if path.startswith("/private/"):
            candidates.add(path[len("/private"):])
        else:
            candidates.add("/private" + path)
    return sorted(candidates, key=len, reverse=True)


def files_opened(events: list[dict], sandbox: str) -> list[str]:
    prefixes = sandbox_prefixes(sandbox)
    seen: list[str] = []
    for event in events:
        message = event.get("message") or {}
        for block in message.get("content", []) or []:
            if not isinstance(block, dict) or block.get("type") != "tool_use":
                continue
            args = block.get("input") or {}
            for key in ("file_path", "path", "notebook_path"):
                value = args.get(key)
                if not isinstance(value, str):
                    continue
                rel = value
                for prefix in prefixes:
                    if rel.startswith(prefix):
                        rel = rel[len(prefix):].lstrip("/")
                        break
                rel = rel or "."
                if rel not in seen:
                    seen.append(rel)
    return seen


def result_event(events: list[dict]) -> dict:
    for event in reversed(events):
        if event.get("type") == "result":
            return event
    return {}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("transcript", type=Path)
    parser.add_argument("--condition", required=True)
    parser.add_argument("--run", required=True)
    parser.add_argument("--prompt", required=True, type=Path)
    parser.add_argument("--cli-version", required=True)
    parser.add_argument("--started-utc", required=True)
    parser.add_argument("--sandbox", required=True)
    args = parser.parse_args()

    events = read_events(args.transcript)
    result = result_event(events)
    if not result:
        print(f"no result event in {args.transcript}", file=sys.stderr)
        return 1

    prompt_sha = hashlib.sha256(args.prompt.read_bytes()).hexdigest()
    models = sorted((result.get("modelUsage") or {}).keys()) or ["unknown"]
    usage = result.get("usage") or {}
    context_tokens = (
        usage.get("input_tokens", 0)
        + usage.get("cache_creation_input_tokens", 0)
        + usage.get("cache_read_input_tokens", 0)
    )

    header = [
        "# clean-report-problem raw run output",
        "# This file is committed verbatim. It is the evidence.",
        f"# condition:      {args.condition}",
        f"# run:            {args.run}",
        f"# model:          {', '.join(models)}",
        f"# cli:            claude {args.cli_version}",
        f"# prompt-sha256:  {prompt_sha}",
        f"# started-utc:    {args.started_utc}",
        f"# duration-ms:    {result.get('duration_ms')}",
        f"# num-turns:      {result.get('num_turns')}",
        f"# context-tokens: {context_tokens}",
        f"# output-tokens:  {usage.get('output_tokens')}",
        f"# cost-usd:       {result.get('total_cost_usd')}",
        f"# is-error:       {result.get('is_error')}",
        f"# session-id:     {result.get('session_id')}",
        "# ---- agent output below this line ----",
        "",
    ]

    stem = args.transcript.with_suffix("")
    body = result.get("result") or ""
    stem.with_suffix(".txt").write_text("\n".join(header) + body + "\n")

    opened = files_opened(events, args.sandbox)
    stem.with_suffix(".files").write_text("\n".join(opened) + ("\n" if opened else ""))

    print(f"{args.condition}-{args.run}: {len(opened)} file(s) opened, {len(body)} chars of report")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
