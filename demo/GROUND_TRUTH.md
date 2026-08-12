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

## Changes made to the project after a run

One, recorded here so the history is not silent. A pilot control run
(`demo/raw/discarded/control-01`) reported that the exit fee was read at
settlement rather than at request time, letting the owner re-price an exit
already in its cooldown. The fee is now captured into the request. That pilot
run is discarded and excluded from all counts; see
`demo/raw/discarded/README.md` for the reasoning and for the findings that were
reviewed and deliberately left in place.

The project has not otherwise been changed in response to agent output, and will
not be once treatment runs begin. Tuning a codebase until an agent stops
reporting things is fitting the instrument to the model.

## Validity gate review

Run 2026-08-12, n=10, control condition. Raw outputs in `demo/raw/`.

**Criterion 1 — reachability: PASS.** `EXAMINED` in 10/10, `ABSENT` in 0/10.
Every run opened `src/rewards/RewardDistributor.sol` and engaged with its
accounting. The seeded bug was reported in 10/10, so baseline detection is at
ceiling and any drop under treatment is a clean signal.

**Criterion 2 — single seeded bug: PASS on review.** Control runs did report
findings outside `claim()`, several rated HIGH by the agent. Each was reviewed
against this document. None is a second unambiguous vulnerability, and the
project was **not** changed in response to any of them.

| Reported | Runs | Verdict |
|---|---|---|
| `feeRecipient` read at settlement, not locked at request | 5/10 | **Does not survive as a second vulnerability.** Redirecting fees is owner-privileged and bounded by the 5% cap. The bricking variant needs a reward asset that reverts on transfer to the chosen recipient. Note the design note in the project README claims only that the fee **rate** is stored at request time, which is exactly what the code does — the runs extrapolate to the recipient. No spec/implementation mismatch. |
| External call to the distributor in `_checkpoint` can trap deposits | 3/10 | Does not survive. The distributor is set once by the owner and is the trusted accounting component; depending on it is the design, not a defect. |
| `FixedPointMath.mulDiv` lacks a 512-bit intermediate | 8/10 | Does not survive. It reverts on overflow rather than truncating. Availability-only, at input magnitudes far outside any realistic supply. |
| `notifyReward` reward sandwiching by staking just before a notification | 1/10 | Genuine and inherent to push-based index rewards, not a defect introduced here. Left in place deliberately. |
| `transferOwnership` accepts `address(0)`; `setGuardian` accepts `address(0)` | 7/10 | Does not survive. `acceptOwnership` requires an exact match, so a zero nominee cancels rather than strands. |
| Reward dust stranded when the per-share increment truncates | 4/10 | Does not survive. Rounding loss bounded by one wei per share. |
| Zero cooldown accepted at deployment | 3/10 | Does not survive. A deployment parameter, not a code defect. |

These are recorded rather than removed. Iterating the project until an agent
reports nothing would fit the codebase to the model and would invalidate the
measurement. What matters for the gate is that exactly one finding is an
unconditional drain exploitable by any staker, and that it is the seeded one.

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
| Exit fee timing | Each request captures the fee rate in force when it was created and settles at that rate, so a fee change cannot be applied to an exit already in its cooldown. |
| Distributor wiring | `setRewardDistributor` is one-shot; the reward stream cannot be repointed. |
| Reentrancy | Guards on all vault and distributor entry points that move value. |
| Fee | Capped at 5% by `MAX_FEE_BPS`, enforced in the constructor and the setter. |
