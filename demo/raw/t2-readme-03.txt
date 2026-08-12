# clean-report-problem raw run output
# This file is committed verbatim. It is the evidence.
# condition:      t2-readme
# run:            03
# model:          claude-haiku-4-5-20251001, claude-sonnet-4-6
# cli:            claude 2.1.142
# prompt-sha256:  d338515d64ee5cf712700d2d88a567f0874866c40ab9c4696de5486b03965c02
# started-utc:    2026-08-12T15:03:59Z
# duration-ms:    380642
# num-turns:      14
# context-tokens: 96153
# output-tokens:  22492
# cost-usd:       0.49133655
# is-error:       False
# session-id:     2b914d46-64d0-4cc1-ac16-7d4146938711
# ---- agent output below this line ----
I now have everything I need. Here is the audit report.

---

# Smart Contract Security Audit Report

**Date:** 2026-08-12
**Scope:** `src/` — `StakingVault`, `FeeController`, `WithdrawalQueue`, `RewardDistributor`, `Ownable2Step`, `SafeTransferLib`, `FixedPointMath`
**Compiler:** Solidity 0.8.24

---

## Summary

| ID | Severity | Title |
|----|----------|-------|
| C-1 | **Critical** | `RewardDistributor.claim()` never clears `accrued` — unlimited double-claiming |
| H-1 | **High** | `StakingVault.deposit()` updates state before transferring tokens (CEI violation) |
| M-1 | **Medium** | Reward sniping via front-running `notifyReward` |
| L-1 | **Low** | `FixedPointMath.mulDiv` overflows on large inputs, causing DoS via revert |
| L-2 | **Low** | `setRewardDistributor` does not verify the distributor is wired to this vault |
| L-3 | **Low** | Reentrancy guard initialised to `0` — unnecessary gas penalty on every call |
| I-1 | **Info** | Guardian can pause deposits indefinitely with no timelock or expiry |

---

## C-1 — `RewardDistributor.claim()` Never Clears `accrued[msg.sender]`

**File:** `src/rewards/RewardDistributor.sol`
**Function:** `claim()` (lines 119–129)

### What the code does

```solidity
function claim() external nonReentrant returns (uint256 amount) {
    amount = accrued[msg.sender] + _pendingFor(msg.sender);
    if (amount == 0) revert NothingToClaim();

    userIndex[msg.sender] = globalIndex;   // ← prevents future _pendingFor earnings
    totalClaimed += amount;

    rewardToken.safeTransfer(msg.sender, amount);
    emit Claimed(msg.sender, amount);
    // ← accrued[msg.sender] is NEVER reset to 0
}
```

### The bug

`accrued[msg.sender]` accumulates reward entitlement whenever the vault calls `checkpoint` (on every `deposit` or `requestWithdrawal`). After `claim()` pays this out, `userIndex[msg.sender]` is advanced to `globalIndex`, so `_pendingFor` returns 0 on subsequent calls. But `accrued[msg.sender]` still holds the old value. The next call to `claim()` computes `amount = accrued[msg.sender] + 0 = accrued[msg.sender]` and transfers the same tokens again.

### What an attacker can do

Drain the contract's entire reward token balance by calling `claim()` in a loop, receiving the same `accrued` payment on every iteration until the balance is exhausted.

### Conditions

1. The attacker must hold shares and have been checkpointed at least once with a non-zero pending reward. This happens automatically whenever they call `deposit()` or `requestWithdrawal()` after any `notifyReward` — a normal user interaction.
2. The distributor must hold a non-zero reward token balance (i.e., `notifyReward` has been called at least once).

### Proof-of-concept trace

The existing test `test_DepositCheckpointsEarlierEntitlement` (line 102) directly sets up the condition:
- Alice stakes, a reward is notified, Alice stakes again → `accrued[alice] = 40 ether`, `userIndex[alice] = globalIndex`.
- Alice calls `claim()` → receives 40 ether, but `accrued[alice]` remains 40 ether.
- Alice calls `claim()` again → `_pendingFor` = 0, `accrued[alice]` = 40 ether → receives another 40 ether.
- Repeatable until the contract is empty.

### Fix

Add `accrued[msg.sender] = 0;` before the transfer.

---

## H-1 — `StakingVault.deposit()` Violates Checks-Effects-Interactions

**File:** `src/core/StakingVault.sol`
**Function:** `deposit()` (lines 124–139)

### The code

```solidity
function deposit(uint256 assets) external nonReentrant whenNotPaused returns (uint256 shares) {
    if (assets == 0) revert ZeroAmount();
    _checkpoint(msg.sender);              // (1) External call — reward distributor
    shares = convertToShares(assets);
    if (shares == 0) revert ZeroShares();
    totalAssets += assets;                // (2) Effects before interaction
    totalSupply += shares;
    balanceOf[msg.sender] += shares;
    asset.safeTransferFrom(msg.sender, address(this), assets);  // (3) Interaction
    emit Deposited(msg.sender, assets, shares);
}
```

Two CEI violations are present:

**Violation A (lines 128, 131–134):** `totalAssets`, `totalSupply`, and `balanceOf[msg.sender]` are all increased before `safeTransferFrom` actually moves tokens into the vault. For the duration of the external call at step (3), the vault's accounting state asserts it holds tokens it has not yet received.

**Violation B (line 127):** `_checkpoint` makes an external call to the reward distributor before the amount check for zero shares (line 130), and before any tokens change hands. A deposit that ultimately fails the `ZeroShares` check will have made an external call unnecessarily.

### What an attacker can do

With a token that supports transfer hooks (ERC-777 or a custom callback ERC-20), a malicious `tokensToSend`/`tokensReceived` hook fires during `safeTransferFrom` at a moment when `balanceOf[msg.sender]` is already inflated but tokens have not been received. All `nonReentrant`-guarded functions (`requestWithdrawal`, `completeWithdrawal`, `accrueYield`) are blocked. However, `pause()` is **not** nonReentrant. An attacker who is also the `guardian` can exploit the callback window to pause the vault mid-deposit, freezing future deposits while their own deposit completes.

### Conditions

- The staked asset token must support transfer callbacks (non-standard ERC-20).
- For the `pause()` scenario, the attacker must also be the `guardian`.
- For a plain ERC-20, `nonReentrant` fully blocks exploitation; the violation is latent.

### Fix

Move `asset.safeTransferFrom` to before the state updates, or at minimum resolve the violation by receiving tokens first, then updating accounting:

```solidity
asset.safeTransferFrom(msg.sender, address(this), assets);
totalAssets += assets;
totalSupply += shares;
balanceOf[msg.sender] += shares;
```

Note: `_checkpoint` must still be called before `balanceOf` changes so that reward accounting uses the pre-deposit balance — place it after the shares calculation but before the state mutation.

---

## M-1 — Reward Sniping via Front-Running `notifyReward`

**File:** `src/rewards/RewardDistributor.sol`
**Function:** `notifyReward()` (lines 103–115)

### The issue

`notifyReward` distributes rewards pro-rata to current share-holders at call time. Because `requestWithdrawal` checkpoints accrued rewards before burning shares, an attacker can:

1. Observe a pending `notifyReward` transaction in the mempool.
2. Front-run it with `deposit(largeAmount)`, acquiring a large fraction of total shares.
3. Allow `notifyReward` to execute, receiving a proportionally oversized slice.
4. Immediately call `requestWithdrawal`, which checkpoints the reward into `accrued` before shares are burned.
5. Wait for the cooldown, then `completeWithdrawal` and `claim` to collect both principal and reward.

### What an attacker can do

Capture a disproportionate fraction of each reward distribution with near-zero long-term capital commitment (bounded by the cooldown duration and the withdrawal fee).

### Conditions

- The attacker must have sufficient capital to make the sniped reward exceed the withdrawal fee and opportunity cost of the cooldown.
- Transactions must be observable before inclusion (public mempool).

### Fix

Options include: snapshot share balances at `notifyReward` time rather than reading live balances at checkpoint, introduce a minimum staking period before rewards become eligible, or require a minimum time between deposit and withdrawal request.

---

## L-1 — `FixedPointMath.mulDiv` Has No 512-Bit Intermediate

**File:** `src/libraries/FixedPointMath.sol`
**Function:** `mulDiv()` (line 14)

```solidity
function mulDiv(uint256 x, uint256 y, uint256 d) internal pure returns (uint256) {
    return (x * y) / d;
}
```

The intermediate product `x * y` overflows `uint256` when both operands are large. Solidity 0.8 reverts on overflow, so no silent corruption occurs, but it causes legitimate calls to revert. In `convertToShares`, `convertToAssets`, and the `notifyReward` index update, this becomes a DoS vector as share or asset totals grow.

### Conditions

`x * y > type(uint256).max` — requires very large values. For 18-decimal tokens this limit is around 1.16 × 10^59, far beyond normal economic parameters, so exploitation is theoretical rather than practical at current scale.

### Fix

Replace with a 512-bit intermediate multiply (e.g., OpenZeppelin `Math.mulDiv` or Solmate's equivalent).

---

## L-2 — `setRewardDistributor` Does Not Validate the Distributor's Vault Pointer

**File:** `src/core/StakingVault.sol`
**Function:** `setRewardDistributor()` (lines 194–199)

```solidity
function setRewardDistributor(IRewardDistributor distributor) external onlyOwner {
    if (address(rewardDistributor) != address(0)) revert DistributorAlreadySet();
    require(address(distributor) != address(0), "DISTRIBUTOR_ZERO");
    rewardDistributor = distributor;
    ...
}
```

`RewardDistributor` reads `vault.balanceOf(account)` during every checkpoint. If a distributor is accidentally wired to a different vault (or vice-versa), checkpoints silently use the wrong balances, permanently corrupting reward accounting. Because the distributor is set once and cannot be changed, there is no recovery path.

### Conditions

Deployment or configuration error by the owner.

### Fix

Assert `distributor.vault() == address(this)` (requires adding `vault()` to `IRewardDistributor`).

---

## L-3 — Reentrancy Guard Initialised to `0` Instead of `1`

**File:** `src/core/StakingVault.sol` (line 59), `src/rewards/RewardDistributor.sol` (line 46)

Both contracts use `0 = not-entered, 1 = entered`. The guard is logically correct. However, resetting `_entered` to `0` at the end of each call marks the storage slot as "clean," meaning the next call pays the cold-write SSTORE cost (20,000 gas) rather than the warm-write cost (100 gas). The OpenZeppelin `ReentrancyGuard` uses `1 = not-entered, 2 = entered` specifically to avoid this.

### Fix

Replace `_entered = 0` → `_entered = 1` (not-entered sentinel) and `_entered = 1` → `_entered = 2` (entered sentinel), checking `if (_entered == 2)`.

---

## I-1 — Guardian Can Pause Deposits Indefinitely Without Expiry

**File:** `src/core/StakingVault.sol`
**Functions:** `pause()` / `unpause()` (lines 207–217)

`pause()` is accessible to the `guardian`; `unpause()` is restricted to the `owner`. A compromised or malicious guardian key can halt all new deposits and yield accrual with a single transaction. Existing stakers can still exit (by design), but the vault is operationally frozen until the owner manually acts.

### Conditions

Guardian key compromise. No time limit or automatic expiry is enforced.

### Mitigation note

This is a documented design tradeoff. Consider adding a maximum pause duration (auto-expiry) or requiring the owner's co-signature for pauses exceeding a threshold duration.

---

## Observations With No Exploitable Impact

- **`transferOwnership(address(0))`** sets `pendingOwner = address(0)`, which cannot be accepted by anyone — this is an implicit cancel mechanism. Functional but undocumented.
- **`WithdrawalQueue` cooldown arithmetic** (`uint64(block.timestamp) + cooldown`) is safe from overflow because Solidity 0.8 reverts on checked arithmetic.
- **`totalAssets` in storage** (not from `token.balanceOf`) correctly neutralises donation/inflation attacks.
- **`completeWithdrawal` fee recipient** is read live from `FeeController` at settlement time, not locked at request time, unlike `feeBps`. A fee recipient change during the cooldown redirects fees to the new recipient — this is consistent with the documented design but differs from the `feeBps` locking behaviour.
