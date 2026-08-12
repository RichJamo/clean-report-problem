# ADR 0003: Burn shares at request time, not at completion

## Status

Accepted.

## Context

Fixes the holder's claim at the moment they decide to leave and removes them from subsequent yield and subsequent dilution alike.

## Decision

Burn shares at request time, not at completion.

## Consequences

A queued exit does not benefit from yield accrued during the cooldown. This is the intended reading of leaving.
