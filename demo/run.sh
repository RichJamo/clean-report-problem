#!/usr/bin/env bash
#
# Run the audit agent over one condition and commit the raw output.
#
#   demo/run.sh <condition> <count> [start-index]
#
#   demo/run.sh control 10        # runs control-01 .. control-10
#   demo/run.sh control 5 11      # runs control-11 .. control-15
#
# Each run gets a pristine copy of demo/vulnerable-project in a sandbox created
# OUTSIDE this repository, so the agent can never see GROUND_TRUTH.md,
# SCORING.md, the exploit test, or anything else about the experiment.
#
# The agent is isolated from the operator's personal Claude Code configuration:
#
#   --setting-sources ""       no user, project or local settings
#   --disable-slash-commands   no skills
#   --strict-mcp-config        no MCP servers
#   --tools "Read,Glob,Grep"   read-only; the agent cannot modify the project
#
# Verified by probe on 2026-08-12: with these flags the agent reports no user
# CLAUDE.md content, no Skill tool, and a tool list of exactly Glob, Grep, Read.
set -euo pipefail

MODEL="${MODEL:-sonnet}"

condition="${1:?usage: run.sh <condition> <count> [start-index]}"
count="${2:?usage: run.sh <condition> <count> [start-index]}"
start="${3:-1}"

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
demo="${repo}/demo"
project="${demo}/vulnerable-project"
payload="${demo}/payloads/${condition}"
prompt="${demo}/prompt.txt"
raw="${demo}/raw"

if [[ "${condition}" != "control" && ! -d "${payload}" ]]; then
  echo "no payload overlay at ${payload}" >&2
  exit 1
fi

mkdir -p "${raw}"
cli_version="$(claude --version | awk '{print $1}')"

for (( i = start; i < start + count; i++ )); do
  run="$(printf '%02d' "${i}")"
  stem="${raw}/${condition}-${run}"

  if [[ -e "${stem}.txt" ]]; then
    echo "${condition}-${run}: already recorded, skipping" >&2
    continue
  fi

  sandbox="$(mktemp -d "${TMPDIR:-/tmp}/ctp-sandbox.XXXXXX")"
  cp -R "${project}/." "${sandbox}/"
  rm -rf "${sandbox}/out" "${sandbox}/cache"

  # Treatment conditions apply their payload to the pristine copy. The project
  # tree in this repository is never modified.
  #
  #   payload.patch  modifies an existing file. Applied with `patch`, which
  #                  fails loudly if the project has drifted from what the
  #                  payload was written against — a stale payload must not
  #                  silently run as if it were the control.
  #   overlay/       new files the payload adds, copied in as-is.
  if [[ -f "${payload}/payload.patch" ]]; then
    ( cd "${sandbox}" && patch -p1 --batch --forward < "${payload}/payload.patch" ) >/dev/null || {
      echo "${condition}-${run}: payload.patch did not apply cleanly; aborting" >&2
      rm -rf "${sandbox}"
      exit 1
    }
  fi
  if [[ -d "${payload}/overlay" ]]; then
    cp -R "${payload}/overlay/." "${sandbox}/"
  fi
  if [[ "${condition}" != "control" ]] \
     && [[ ! -f "${payload}/payload.patch" ]] && [[ ! -d "${payload}/overlay" ]]; then
    echo "${condition}: payload directory has neither payload.patch nor overlay/" >&2
    exit 1
  fi

  started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "${condition}-${run}: starting (${started})" >&2

  (
    cd "${sandbox}"
    claude -p "$(cat "${prompt}")" \
      --model "${MODEL}" \
      --setting-sources "" \
      --disable-slash-commands \
      --strict-mcp-config \
      --tools "Read,Glob,Grep" \
      --allowed-tools "Read" "Glob" "Grep" \
      --no-session-persistence \
      --output-format stream-json \
      --verbose
  ) > "${stem}.jsonl" 2> "${stem}.stderr" || {
    echo "${condition}-${run}: agent exited non-zero; transcript kept" >&2
  }

  python3 "${demo}/extract.py" "${stem}.jsonl" \
    --condition "${condition}" \
    --run "${run}" \
    --prompt "${prompt}" \
    --cli-version "${cli_version}" \
    --started-utc "${started}" \
    --sandbox "${sandbox}"

  rm -rf "${sandbox}"
  [[ -s "${stem}.stderr" ]] || rm -f "${stem}.stderr"
done

echo "done: ${condition}" >&2
