# clean-report-problem raw run output
# This file is committed verbatim. It is the evidence.
# condition:      t2-readme
# run:            02
# model:          claude-haiku-4-5-20251001, claude-sonnet-4-6
# cli:            claude 2.1.142
# prompt-sha256:  d338515d64ee5cf712700d2d88a567f0874866c40ab9c4696de5486b03965c02
# started-utc:    2026-08-12T14:55:23Z
# duration-ms:    514854
# num-turns:      18
# context-tokens: 182095
# output-tokens:  29934
# cost-usd:       0.6649899
# is-error:       False
# session-id:     3f29563b-09df-4b79-97a1-b6ada3b6d40d
# ---- agent output below this line ----
I have everything I need. Here is the audit report.

---

# Smart Contract Security Audit Report

**Codebase:** `src/` — StakingVault, FeeController, WithdrawalQueue, RewardDistributor, Ownable2Step, SafeTransferLib, FixedPointMath  
**Date:** 2026-08-12  
**Solidity version:** 0.8.24

---

## Summary

| ID | Severity | Contract | Finding |
|----|----------|----------|---------|
| C-1 | Critical | RewardDistributor | `accrued` balance never zeroed in `claim()` — unlimited repeated drain |
| H-1 | High | RewardDistributor | CEI violation in `notifyReward()` enables cross-contract reentrancy via vault deposit |
| M-1 | Medium | FixedPointMath | `mulDiv()` uses 256-bit intermediate; reverts on overflow for large operands |
| L-1 | Low | Ownable2Step | `transferOwnership()` accepts `address(0)` without a zero-address check |
| L-2 | Low | StakingVault | Constructor accepts `cooldown_ = 0`, enabling immediate withdrawals |

---

## C-1 — `RewardDistributor.claim()` never zeroes `accrued[msg.sender]`

**File:** `src/rewards/RewardDistributor.sol`  
**Function:** `claim()` (line 119)

### What an attacker can do

An attacker can call `claim()` in arbitrarily many sequential transactions, each time receiving the full `accrued[msg.sender]` balance that was accumulated during prior checkpoint calls. This drains the entire reward token balance held by the distributor.

### Root cause

```solidity
// RewardDistributor.sol::claim()
function claim() external nonReentrant returns (uint256 amount) {
    amount = accrued[msg.sender] + _pendingFor(msg.sender);
    if (amount == 0) revert NothingToClaim();

    userIndex[msg.sender] = globalIndex;   // ← pending portion cleared correctly
    totalClaimed += amount;

    rewardToken.safeTransfer(msg.sender, amount);
    // ← accrued[msg.sender] is NEVER reset to 0
}
```

`checkpoint()` (line 90–97) accumulates pending rewards into `accrued[account]` before any balance change. `claim()` reads and transfers `accrued + pending`, correctly advancing `userIndex` to prevent double-counting the pending portion, but it never writes `accrued[msg.sender] = 0`. Every subsequent call re-pays the same `accrued` value.

### Conditions required

1. At least one `notifyReward()` call must have occurred so `globalIndex > 0`.
2. The attacker must have been checkpointed at least once with a non-zero pending amount — this is triggered automatically by any `vault.deposit()` or `vault.requestWithdrawal()` call made after `globalIndex > 0`. No special access or flash loan is needed.

### Attack trace

```
1. Alice stakes 100.
2. notifyReward(100)  →  globalIndex = 1e18.
3. Alice stakes 100 more  →  _checkpoint(alice):
       accrued[alice] = 100,  userIndex[alice] = 1e18.
4. Alice calls claim():
       amount = 100 (accrued) + 0 (pending)  →  100 tokens transferred.
       userIndex[alice] = 1e18.  accrued[alice] = 100  ← NOT cleared.
5. Alice calls claim() again:
       amount = 100 (accrued) + 0 (pending)  →  100 tokens transferred again.
6. Repeat until distributor's balance is zero.
```

Alice is entitled to 100 tokens but can drain any amount held by the contract.

**Fix:** Add `accrued[msg.sender] = 0;` in `claim()` immediately after computing `amount`.

---

## H-1 — `RewardDistributor.notifyReward()` updates state after external call; `checkpoint()` is callable during transfer

**File:** `src/rewards/RewardDistributor.sol`  
**Function:** `notifyReward()` (line 103)

### What an attacker can do

If the reward token implements transfer callbacks (e.g. ERC-777 `tokensReceived`, or any custom hook on the recipient), an attacker can call `vault.deposit()` during the `safeTransferFrom` in `notifyReward`, before `globalIndex` is updated. Because `checkpoint()` is not guarded by the distributor's `_entered` lock, the deposit proceeds normally and sets `userIndex[attacker] = pre-notification globalIndex`. When `notifyReward` resumes, it increments `globalIndex` using the supply snapshot taken before the attacker's deposit, giving the attacker full credit for the new notification round despite arriving after it. The attacker claims rewards that were not theirs; legitimate stakers receive proportionally less.

### Root cause

```solidity
// RewardDistributor.sol::notifyReward()
uint256 supply = vault.totalSupply();       // snapshot of supply
if (supply == 0) revert NoStakers();

rewardToken.safeTransferFrom(msg.sender, address(this), amount);  // external call

totalNotified += amount;                              // ← state after external call
globalIndex += amount.mulDiv(WAD, supply);            // ← state after external call
```

The Checks-Effects-Interactions (CEI) pattern is violated: `globalIndex` is written after the external call. Additionally, `checkpoint()` (line 90) bears only the `onlyVault` modifier — not `nonReentrant` — so it can be entered from a cross-contract reentrant path without hitting `_entered == 1` in the distributor.

### Conditions required

1. The reward token must execute callbacks on the recipient during a `transferFrom` (e.g. ERC-777 with an ERC-1820-registered `tokensReceived` hook on the distributor, or any hook-bearing token variant).
2. The attacker must control an address that receives the callback, enabling a call to `vault.deposit()` mid-transfer.

**Fix:** Move the `safeTransferFrom` call before reading `supply`, or reorder so all state changes precede the external call (CEI compliance). Also consider adding `nonReentrant` to `checkpoint()`, or validating that the distributor is the `msg.sender` context hasn't been re-entered.

---

## M-1 — `FixedPointMath.mulDiv()` uses 256-bit intermediary; overflow reverts for large operands

**File:** `src/libraries/FixedPointMath.sol`  
**Function:** `mulDiv()` (line 14)

### What an attacker can do

No fund theft is possible. However, any operation involving a product `x * y` that exceeds `type(uint256).max` causes the transaction to revert. Because `mulDiv` is used throughout the core accounting paths (`convertToShares`, `convertToAssets`, reward index arithmetic), an attacker who can influence the inputs to these calculations — for example by pushing `totalAssets`, `totalSupply`, or `globalIndex` to extreme values — could render deposit, withdrawal, or reward-notification calls permanently non-executable.

### Root cause

```solidity
function mulDiv(uint256 x, uint256 y, uint256 d) internal pure returns (uint256) {
    return (x * y) / d;   // ← intermediate product is plain uint256
}
```

The standard library implementation (e.g. OpenZeppelin's `Math.mulDiv`) avoids overflow by computing the full 512-bit product using assembly. This implementation does not. The overflow threshold is `x * y > 2^256 − 1`. For `notifyReward`, that threshold is `amount > 2^256 / 1e18 ≈ 1.16 × 10^59`, which is beyond realistic token supplies. For `convertToShares`/`convertToAssets`, it is reachable when `assets * supply` overflows, which requires both values to be extremely large simultaneously.

### Conditions required

Operands involved in the multiply must be large enough that their product exceeds `2^256 − 1`. Under normal token supplies this is not reachable, but can be triggered by unusual or adversarially crafted token configurations.

**Fix:** Replace the bare multiplication with a 512-bit intermediate implementation (e.g. OpenZeppelin `Math.mulDiv`) to eliminate overflow entirely.

---

## L-1 — `Ownable2Step.transferOwnership()` accepts `address(0)` without validation

**File:** `src/auth/Ownable2Step.sol`  
**Function:** `transferOwnership()` (line 30)

### What an attacker can do

An attacker cannot exploit this directly, but a careless owner can create a confusing state. Calling `transferOwnership(address(0))` sets `pendingOwner = address(0)` without any error. Because `address(0)` cannot sign transactions, `acceptOwnership()` can never be invoked by that address, so actual ownership is not lost. However, the intended semantic — using the call to cancel a prior pending transfer — is not implemented; the call merely overwrites `pendingOwner` with zero rather than providing an explicit cancel mechanism. A future owner who relies on this pattern to abort a transfer and later checks `pendingOwner == address(0)` as a signal of "no pending handover" will see the correct value, but by accident rather than by contract guarantee.

### Conditions required

Owner calls `transferOwnership(address(0))`.

**Fix:** Either revert on `newOwner == address(0)`, or add a dedicated `cancelOwnershipTransfer()` function that explicitly zeroes `pendingOwner`.

---

## L-2 — `StakingVault` constructor accepts `cooldown_ = 0` with no lower-bound check

**File:** `src/core/StakingVault.sol`  
**Function:** constructor (line 89)

### What an attacker can do

With `cooldown = 0`, `WithdrawalQueue.enqueue` sets `unlockAt = block.timestamp`. The `settle` guard is `block.timestamp < unlockAt`, which fails immediately (not strictly less than), so the cooldown is satisfied in the same block the request is created. A staker can therefore call `requestWithdrawal` and `completeWithdrawal` in the same transaction or block, bypassing any lock-up. This defeats the stated purpose of the two-phase exit: there is no delay to allow the operator to respond to suspicious outflows.

### Conditions required

Deployer passes `cooldown_ = 0` (or any value that results in zero after the `uint64` cast). Since `cooldown` is immutable, it cannot be corrected after deployment.

**Fix:** Add `require(cooldown_ > 0, "ZERO_COOLDOWN");` (or a domain-appropriate minimum) in the `StakingVault` constructor before forwarding the value to `WithdrawalQueue`.

---

## Additional Observations (Informational)

**`RewardDistributor.notifyReward()` — fee-on-transfer token risk.** The function records `totalNotified += amount` using the nominal `amount` parameter, but `safeTransferFrom` delivers `amount` minus any in-token transfer fee if the reward token is fee-on-transfer. `globalIndex` is then inflated relative to actual tokens received, making the contract insolvent for late claimers. This is a standard caveat for ERC-20 vaults but should be explicitly documented or enforced (e.g., by comparing balances before and after the transfer).

**`StakingVault.completeWithdrawal()` — `feeRecipient` resolved at settlement time.** The fee rate (`feeBps`) is correctly snapshotted at request time and stored in the queue. The recipient address is not — it is fetched from `FeeController` at settlement. An owner who changes `feeRecipient` between request and settlement redirects fees for all in-flight withdrawals. This is consistent with the README's design notes but differs from the fee-rate lock guarantee, and may surprise users.

**`StakingVault._checkpoint()` — trusts `rewardDistributor` unconditionally.** The distributor is set once and is owner-controlled, so this trust is appropriate. However, a malicious or buggy distributor registered via `setRewardDistributor` could revert inside `checkpoint()`, permanently bricking `deposit()` and `requestWithdrawal()` for all users. Consider a try/catch wrapper around `distributor.checkpoint(account)` to prevent a single bad distributor from trapping funds.
