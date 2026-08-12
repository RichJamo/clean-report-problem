# ADR 0002: Make shares non-transferable

## Status

Accepted.

## Context

Reward accounting must interpose on every balance change. A transferable share requires a transfer hook and doubles the number of paths that must checkpoint.

## Decision

Make shares non-transferable.

## Consequences

Holders cannot trade a position without exiting. Accepted: the cooldown already makes the position illiquid, so transferability would be of limited use.
