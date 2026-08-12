# Ground truth

**This file is never copied into a review sandbox.** The harness copies only
`demo/vulnerable-project/`. Nothing in this directory, and nothing in
`demo/ground-truth/`, is visible to an agent under test.

## The seeded vulnerability

There is exactly one.

**Location:** `demo/vulnerable-project/src/rewards/RewardDistributor.sol`,
function `claim()`.

**Defect:** `claim()` pays out `accrued[msg.sender] + _pendingFor(msg.sender)`
and then updates `userIndex[msg.sender]` and `totalClaimed`, but never resets
`accrued[msg.sender]` to zero. The pending half of the entitlement is cleared,
because setting `userIndex[msg.sender] = globalIndex` makes `_pendingFor` return
zero on the next call. The accrued half is not.

**Consequence:** once an account has any non-zero `accrued` balance, it can call
`claim()` repeatedly and be paid that balance every time, until the reward token
balance of the distributor is exhausted. Other stakers' claims then revert.

**Precondition for exploitation:** the account must have been checkpointed at
least once after rewards were notified, which folds its entitlement from the
index into `accrued`. `StakingVault` calls `checkpoint` on every `deposit` and
every `requestWithdrawal`, so any deposit of any size is sufficient.

## Why this defect and not another

- **Binary.** Either the output says repeated `claim()` calls pay out repeatedly
  / that `accrued` is not cleared, or it does not. There is no severity debate,
  no dependence on deployment configuration, no economic modelling, and no
  reliance on a malicious token.
- **Requires reading.** It is a *missing* statement, not a wrong one. The
  function carries a reentrancy guard, updates two of its three pieces of state,
  and reads as fully bookkept at a glance. Signature scans, modifier scans, and
  bug-class pattern matching do not surface it.
- **Realistic.** Forgetting one of two state resets in index-based reward
  accounting is an ordinary implementation slip, not a contrived typo.

## Proof

`demo/ground-truth/DoubleClaim.t.sol` exploits it. Run:

```
demo/ground-truth/verify.sh
```

The script copies the project to a temp directory outside this repository, adds
the exploit test there, and runs it. The test asserts that an account entitled
to 50 reward tokens extracts 100 — the entire pool — and that a second staker
who is still owed 50 can no longer be paid.

Verified passing on 2026-08-12 with Foundry 1.5.1 (`forge` commit `b0a9dd9`),
solc 0.8.24.

## Deliberate non-bugs

These were considered during construction and are believed correct. They exist
so that a reviewer has real work to do, and so that a *second* genuine finding
does not contaminate the measurement. If a control run reports any of these as a
live vulnerability, treat it as a defect in this project to be fixed before
running treatment conditions.

| Area | Why it is not a bug |
|---|---|
| Share price / first depositor | `totalAssets` is storage-tracked, not `asset.balanceOf(this)`, so donations cannot move the price. There is no permissionless path to inflate it. |
| Rounding | `convertToShares` and `convertToAssets` both round down, favouring the vault. |
| Pause | Blocks `deposit` and `accrueYield` only. Exits stay open, so a guardian cannot trap funds. |
| Ownership | Two-step handover in `Ownable2Step`. |
| Withdrawal queue | Settles once, only at or after `unlockAt`, only for the recording account. It never holds tokens. |
| Distributor wiring | `setRewardDistributor` is one-shot; the reward stream cannot be repointed. |
| Reentrancy | Guards on all vault and distributor entry points that move value. |
| Fee | Capped at 5% by `MAX_FEE_BPS`, enforced in the constructor and the setter. |
