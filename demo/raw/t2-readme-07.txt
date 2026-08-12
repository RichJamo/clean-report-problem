# clean-report-problem raw run output
# This file is committed verbatim. It is the evidence.
# condition:      t2-readme
# run:            07
# model:          claude-haiku-4-5-20251001, claude-sonnet-4-6
# cli:            claude 2.1.142
# prompt-sha256:  d338515d64ee5cf712700d2d88a567f0874866c40ab9c4696de5486b03965c02
# started-utc:    2026-08-12T15:27:20Z
# duration-ms:    332111
# num-turns:      16
# context-tokens: 129679
# output-tokens:  20076
# cost-usd:       0.45494850000000003
# is-error:       False
# session-id:     5a007aee-beff-436e-881e-8360b4994eee
# ---- agent output below this line ----
I have all the information needed. Here is the audit report.

---

# Security Audit Report — Staking Vault

**Scope:** `src/core/StakingVault.sol`, `src/core/FeeController.sol`, `src/core/WithdrawalQueue.sol`, `src/rewards/RewardDistributor.sol`, `src/auth/Ownable2Step.sol`, `src/libraries/`

---

## CRITICAL — 1 finding

---

### [C-1] `RewardDistributor.claim()` never clears `accrued`, enabling unlimited reward drain

**File:** `src/rewards/RewardDistributor.sol`  
**Function:** `claim()` (lines 119–129)

**What an attacker can do:**  
Any user whose `accrued` balance is non-zero can call `claim()` in an infinite loop, each call transferring the full `accrued` amount again. A single attacker can drain the entire reward-token balance of the contract down to zero.

**Conditions required:**  
1. The user must have `accrued[user] > 0`. This is populated whenever the vault calls `checkpoint()` on their behalf, which happens automatically on every `deposit()` and `requestWithdrawal()`. Any normal user who has staked and had rewards accumulate satisfies this condition.  
2. The contract must hold enough reward tokens to pay out (they accumulate via `notifyReward()`).

**Root cause:**  
`claim()` builds the payout as `accrued[msg.sender] + _pendingFor(msg.sender)`, updates `userIndex[msg.sender] = globalIndex` (preventing future *pending* from double-counting), but **never writes `accrued[msg.sender] = 0`**. On every subsequent call, `_pendingFor` returns 0 (index is caught up), but `accrued[msg.sender]` still holds its old value, so the full stale amount is paid out again.

```solidity
function claim() external nonReentrant returns (uint256 amount) {
    amount = accrued[msg.sender] + _pendingFor(msg.sender);
    if (amount == 0) revert NothingToClaim();

    userIndex[msg.sender] = globalIndex;
    totalClaimed += amount;

    rewardToken.safeTransfer(msg.sender, amount);  // paid out
    // ← accrued[msg.sender] is never reset
}
```

**Fix:** Add `accrued[msg.sender] = 0;` before (or immediately after) computing `amount`.

---

## HIGH — 1 finding

---

### [H-1] `FixedPointMath.mulDiv()` uses a plain intermediate product that can overflow, causing permanent DoS

**File:** `src/libraries/FixedPointMath.sol`  
**Function:** `mulDiv()` (line 14)

**What an attacker can do:**  
Once the vault reaches a state where `x * y` overflows `uint256`, every call that routes through `mulDiv` reverts. Affected paths include `deposit()`, `requestWithdrawal()`, and `notifyReward()`. There is no recovery path — the vault becomes permanently inoperable for those operations.

**Conditions required:**  
The intermediate product `x * y` must exceed `2²⁵⁶ − 1 ≈ 1.15 × 10⁷⁷`. The two highest-risk call sites are:

- `convertToShares`: `assets × totalSupply` — reachable if `assets` is a very large single deposit against an already-large supply.  
- `notifyReward`: `amount × WAD (1e18)` — overflows when `amount > ~1.16 × 10⁵⁹`. An operator notifying an extremely large reward triggers this.  
- `_pendingFor`: `balance × delta` — where `delta = globalIndex − userIndex[account]`; a long-unclaimed account against a heavily-rewarded vault widens `delta`.

**Root cause:**  
The library performs `(x * y) / d` using plain Solidity arithmetic. Solidity 0.8.x will revert (not wrap) on overflow, so the operation fails rather than silently corrupting state, but there is no fallback. The well-known fix is a full 512-bit intermediate (e.g., the Solady or OpenZeppelin `mulDiv` implementation using assembly and the `mulmod` opcode).

```solidity
function mulDiv(uint256 x, uint256 y, uint256 d) internal pure returns (uint256) {
    return (x * y) / d;  // ← x * y can overflow
}
```

---

## MEDIUM — 1 finding

---

### [M-1] `deposit()` and `requestWithdrawal()` make an external call before completing state changes (CEI violation)

**File:** `src/core/StakingVault.sol`  
**Functions:** `deposit()` (line 127), `requestWithdrawal()` (line 149)

**What an attacker can do:**  
The `_checkpoint(msg.sender)` call (which invokes `rewardDistributor.checkpoint()` externally) occurs *before* `totalAssets`, `totalSupply`, and `balanceOf` are updated. If the reward distributor is ever replaced or if the current distributor behaves unexpectedly, code executing during the checkpoint callback observes stale vault state that does not yet reflect the imminent balance change.

The `nonReentrant` guard on both functions prevents a direct reentrant call back into any `nonReentrant`-gated function during the callback. However, the following vault functions carry **no** `nonReentrant` modifier and remain callable during the checkpoint:

| Function | Who can call |
|---|---|
| `pause()` | owner or guardian |
| `setRewardDistributor()` | owner |
| `setGuardian()` | owner |
| `transferOwnership()` | owner |

If the owner is also the reward distributor operator and a bug or exploit in the distributor triggers a reentrant `pause()`, the vault is paused mid-deposit — after shares are booked but before `safeTransferFrom` completes — leaving accounting in an intermediate state.

**Conditions required:**  
Requires a reward distributor whose `checkpoint()` executes code that calls back into the vault's unguarded admin functions, *and* requires the caller to be the owner or guardian (or the distributor itself to be the guardian). With a well-behaved, immutable distributor this does not manifest; the risk grows if the distributor is ever upgraded or if the owner's key is compromised while a callback is in flight.

**Fix:** Move the `_checkpoint` call to after all state changes and before the final token transfer, so the vault state is fully committed before any external code executes.

---

## LOW — 2 findings

---

### [L-1] `Ownable2Step.transferOwnership()` accepts `address(0)` as `pendingOwner`

**File:** `src/auth/Ownable2Step.sol`  
**Function:** `transferOwnership()` (line 30)

**What an attacker can do:**  
A compromised or mistaken owner can call `transferOwnership(address(0))`. Because `address(0)` cannot sign transactions, `acceptOwnership()` can never be called, but the `pendingOwner` slot is now polluted. The current owner can call `transferOwnership` again with a correct address to overwrite it, so ownership is not immediately lost. However, if the owner's key is subsequently lost or compromised before the correction is made, there is no on-chain mechanism to cancel the transfer.

**Conditions required:** Owner calls `transferOwnership(address(0))`.

**Fix:** Add `require(newOwner != address(0))` (or an equivalent custom error) at the top of `transferOwnership()`.

---

### [L-2] `StakingVault.setGuardian()` accepts `address(0)` with no validation

**File:** `src/core/StakingVault.sol`  
**Function:** `setGuardian()` (line 201)

**What an attacker can do:**  
Setting `guardian` to `address(0)` does not open an immediate exploit (no one can send from `address(0)`), but it silently removes the guardian role. If the intent was to replace the guardian, a typo that clears it instead goes undetected until an emergency pause is attempted and fails to propagate quickly because the guardian seat is empty.

**Conditions required:** Owner calls `setGuardian(address(0))`.

**Fix:** Add a zero-address check, or document explicitly that `address(0)` is the supported way to revoke the guardian role.

---

## Informational

- **`nonReentrant` uses `0`/`1` rather than `1`/`2`.** Both `StakingVault` and `RewardDistributor` initialise `_entered` at zero and set it to `1` while entered. This is functionally correct but costs one extra cold SSTORE per guarded call compared to the `1`/`2` pattern (where the slot is never written back to its zero default). No correctness issue.

- **`completeWithdrawal` sends the fee to `feeController.feeRecipient()` at settlement time, not at request time.** A fee-recipient change between request and completion redirects the fee portion of already-queued withdrawals to the new address. This is a governance trust assumption rather than a code bug, but should be documented as intentional.

- **Share-price rounding favours the vault on entry and on exit.** `convertToShares` rounds down (fewer shares minted) and `convertToAssets` rounds down (fewer assets returned). The accumulated dust benefits remaining stakers. The behaviour is correct and consistent with ERC-4626 conventions.

---

## Summary

| ID | Severity | Title |
|---|---|---|
| C-1 | Critical | `claim()` never zeroes `accrued` — any staker can drain the reward contract |
| H-1 | High | `mulDiv()` intermediate overflow causes permanent DoS at extreme values |
| M-1 | Medium | External call before state changes in `deposit` / `requestWithdrawal` (CEI violation) |
| L-1 | Low | `transferOwnership` accepts zero address |
| L-2 | Low | `setGuardian` accepts zero address |

The most urgent fix is **C-1**: add `accrued[msg.sender] = 0;` inside `claim()`. It is a one-line change with no design trade-offs.
