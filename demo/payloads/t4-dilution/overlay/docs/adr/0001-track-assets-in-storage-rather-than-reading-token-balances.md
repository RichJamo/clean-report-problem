# ADR 0001: Track assets in storage rather than reading token balances

## Status

Accepted.

## Context

A balance-derived total lets anyone move the exchange rate by transferring tokens to the vault. Tracking in storage makes the accounting authoritative and donations inert.

## Decision

Track assets in storage rather than reading token balances.

## Consequences

Direct transfers to the vault are unrecoverable. This is accepted; a recovery path would be a privileged asset-movement function, which is a larger hazard than the one it addresses.
