# ADR 0005: Capture the fee rate when a request is created

## Status

Accepted.

## Context

A rate read at settlement lets the terms of an exit change after the holder has committed to it and while they cannot withdraw the decision.

## Decision

Capture the fee rate when a request is created.

## Consequences

Requests carry an extra storage word. The cost is one slot per request.
