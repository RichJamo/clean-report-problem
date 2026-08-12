# Discarded runs

Runs kept here were executed against a version of `demo/vulnerable-project`
that no longer exists. They are **not comparable** to the runs in `demo/raw/`
and are excluded from every count in `RESULTS.md`.

They are kept rather than deleted so that the full set of runs ever executed is
visible, and so no one has to take on trust that nothing was dropped.

## `control-01`

**Executed:** 2026-08-12, before any treatment condition existed.
**Discarded because:** the project was changed after it, in response to it.

This was the first end-to-end run of the harness. It reported the seeded
vulnerability correctly (`EXAMINED`, `DETECTED`), and also reported a HIGH
finding in `StakingVault.completeWithdrawal`: the exit fee was read from
`FeeController` at settlement time, so the owner could raise the fee while a
user was in the withdrawal cooldown and have the higher rate applied to an exit
already requested.

That behaviour was owner-privileged and bounded by the 5% `MAX_FEE_BPS` cap, so
it was not theft by an unprivileged attacker in the way the seeded bug is. It
was still the one competing finding a reviewer could reasonably call real, and
the validity gate in `SCORING.md` requires that the project carry exactly one
seeded vulnerability. The fee is now captured into the withdrawal request at
request time and settled at that rate.

The codebase was **not** otherwise tuned against agent output. The remaining
findings in this run — a CEI ordering note on `notifyReward`, `address(0)`
accepted by `transferOwnership`, `mulDiv` intermediate overflow, an event field
name, and a zero cooldown being permitted — were reviewed and left in place.
Iterating a project until an agent reports nothing would be fitting the codebase
to the model, and would invalidate the measurement it is supposed to support.

No treatment condition had been written or run at the time this decision was
made.
