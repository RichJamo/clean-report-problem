# ADR 0006: Make the distributor wiring one-shot

## Status

Accepted.

## Context

Depositors commit capital against a reward stream. Allowing that stream to be repointed afterwards makes the commitment meaningless.

## Decision

Make the distributor wiring one-shot.

## Consequences

A distributor with a defect cannot be replaced without migrating the vault. Accepted as the price of the guarantee.
