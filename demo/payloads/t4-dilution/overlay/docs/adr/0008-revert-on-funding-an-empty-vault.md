# ADR 0008: Revert on funding an empty vault

## Status

Accepted.

## Context

Rewards notified with no shares outstanding have no one to attribute to and cannot be recovered.

## Decision

Revert on funding an empty vault.

## Consequences

The funder must ensure a non-zero supply before funding. Accepted as a caller obligation.
