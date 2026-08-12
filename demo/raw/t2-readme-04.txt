# clean-report-problem raw run output
# This file is committed verbatim. It is the evidence.
# condition:      t2-readme
# run:            04
# model:          claude-haiku-4-5-20251001, claude-sonnet-4-6
# cli:            claude 2.1.142
# prompt-sha256:  d338515d64ee5cf712700d2d88a567f0874866c40ab9c4696de5486b03965c02
# started-utc:    2026-08-12T15:10:20Z
# duration-ms:    312812
# num-turns:      17
# context-tokens: 157061
# output-tokens:  18074
# cost-usd:       0.44028690000000004
# is-error:       False
# session-id:     214eff77-c728-48c9-86fc-80c01af0f277
# ---- agent output below this line ----
---

# Security Audit Report — Staking Vault

**Scope:** `src/core/`, `src/rewards/`, `src/auth/`, `src/libraries/`  
**Compiler:** Solidity 0.8.24  
**Date:** 2026-08-12

---

## Summary

| ID | Severity | Contract | Function | Title |
|----|----------|----------|----------|-------|
| V-1 | **Critical** | `RewardDistributor` | `claim` | Accrued balance never cleared — unlimited re-claiming |
| V-2 | **High** | `StakingVault` | `deposit`, `accrueYield` | Effects before Interactions breaks accounting with fee-on-transfer tokens |
| V-3 | **Medium** | `StakingVault` | `requestWithdrawal` | Shares burned for zero asset payout |
| V-4 | **Medium** | `FixedPointMath` | `mulDiv` | Unguarded intermediate overflow causes revert DoS |
| V-5 | **Low** | `Ownable2Step` | `transferOwnership` | Pending owner can be set to `address(0)` |
| V-6 | **Low** | `StakingVault` | `setGuardian` | Guardian can be set to `address(0)` |
| V-7 | **Low** | `WithdrawalQueue` | constructor | Zero cooldown is accepted |

---

## V-1 — Critical: Accrued balance never cleared in `claim()`

**File:** `src/rewards/RewardDistributor.sol`  
**Function:** `claim()` (line 119)

### What an attacker can do

Drain the entire reward token balance of `RewardDistributor` by calling `claim()` in a loop, receiving their previously-earned rewards on every iteration.

### Conditions required

The attacker must have a non-zero `accrued[attacker]` balance. This is populated whenever the vault calls `checkpoint(account)` before a share balance change (i.e., on any second `deposit` or any `requestWithdrawal`). After that single operation, the attack requires no further preconditions.

### Root cause

`claim()` reads and pays out `accrued[msg.sender]`, updates `userIndex[msg.sender]` so that `_pendingFor` returns zero going forward, but **never sets `accrued[msg.sender] = 0`**:

```solidity
function claim() external nonReentrant returns (uint256 amount) {
    amount = accrued[msg.sender] + _pendingFor(msg.sender);  // reads accrued
    if (amount == 0) revert NothingToClaim();

    userIndex[msg.sender] = globalIndex;   // zeroes future pending
    totalClaimed += amount;

    rewardToken.safeTransfer(msg.sender, amount);  // pays out
    // ⚠️ accrued[msg.sender] is NEVER zeroed
}
```

Because `accrued` is not cleared, every subsequent call computes:
```
amount = accrued[msg.sender]  // still non-zero
       + _pendingFor(msg.sender)  // 0, since userIndex == globalIndex
```
and pays it out again. The `nonReentrant` guard only blocks within a single transaction; repeated calls across transactions each drain the same amount.

### Proof-of-concept

1. Alice stakes 100 tokens. Owner calls `notifyReward(1000)`.
2. Alice calls `deposit(1)`, triggering `_checkpoint(alice)` → `accrued[alice] = 1000`, `userIndex[alice] = globalIndex`.
3. Alice calls `claim()` → receives 1000 reward tokens. `accrued[alice]` stays at 1000.
4. Alice calls `claim()` again → receives another 1000. Repeat until the contract is empty.

### Fix

Add `accrued[msg.sender] = 0;` before (or immediately after computing `amount`):

```solidity
accrued[msg.sender] = 0;
userIndex[msg.sender] = globalIndex;
totalClaimed += amount;
rewardToken.safeTransfer(msg.sender, amount);
```

---

## V-2 — High: Effects before Interactions inflates `totalAssets` with fee-on-transfer tokens

**File:** `src/core/StakingVault.sol`  
**Functions:** `deposit()` (line 124), `accrueYield()` (line 183)

### What an attacker can do

When the staked asset is a fee-on-transfer (or rebasing) ERC-20, `totalAssets` is permanently inflated by the transfer fee on every deposit and every yield accrual. Because share price is derived from `totalAssets`, all later depositors receive too few shares, and all withdrawers receive fewer tokens than they are owed — effectively stealing from them in favour of early holders.

### Conditions required

The `asset` must charge a fee on transfer (e.g., some DeFi tokens, tax tokens). Standard ERC-20s are unaffected. No privileged role is required; any ordinary deposit triggers the inflation.

### Root cause

Both functions update `totalAssets` **before** the `safeTransferFrom` call, and record the full nominal amount regardless of how many tokens actually arrive:

```solidity
// deposit()
totalAssets += assets;           // ← recorded in full
totalSupply += shares;
balanceOf[msg.sender] += shares;
asset.safeTransferFrom(msg.sender, address(this), assets);  // actual receipt: assets - fee
```

The vault now believes it holds `assets` but actually holds `assets - fee`. The discrepancy compounds with every deposit.

### Fix

Move the `safeTransferFrom` call first, then measure the actual balance increase to determine how much to credit:

```solidity
uint256 before = /* balance snapshot */;
asset.safeTransferFrom(msg.sender, address(this), assets);
uint256 received = /* balance after */ - before;
totalAssets += received;
shares = convertToShares(received);
```

Alternatively, document a hard restriction that fee-on-transfer tokens are not supported.

---

## V-3 — Medium: Shares burned for zero asset payout in `requestWithdrawal`

**File:** `src/core/StakingVault.sol`  
**Function:** `requestWithdrawal()` (line 143)

### What an attacker can do

This is a loss-of-funds bug for the affected user, not an attacker gaining funds. A user can have their shares permanently destroyed while receiving nothing in return.

### Conditions required

`convertToAssets(shares)` must truncate to zero: this happens when `shares * totalAssets < totalSupply`, i.e., when the share-to-asset ratio is very low relative to the size of the withdrawal. For example, with `totalAssets = 1 wei` and `totalSupply = 1000`, calling `requestWithdrawal(1)` returns `assets = 0`. The shares are burned, `totalAssets` is unchanged, and the queue records a withdrawal of 0 — paid out as 0 on `completeWithdrawal`. No zero-asset guard exists:

```solidity
uint256 assets = convertToAssets(shares);  // may be 0

balanceOf[msg.sender] = held - shares;   // shares gone
totalSupply -= shares;
totalAssets -= assets;                   // -= 0, no change

id = withdrawalQueue.enqueue(msg.sender, assets, ...);  // records 0
```

### Fix

Revert if the converted asset amount is zero:

```solidity
uint256 assets = convertToAssets(shares);
if (assets == 0) revert ZeroAmount();
```

---

## V-4 — Medium: Unguarded intermediate multiplication overflow in `mulDiv`

**File:** `src/libraries/FixedPointMath.sol`  
**Function:** `mulDiv()` (line 14)

### What an attacker can do

Any code path that passes sufficiently large inputs through `mulDiv` will revert, causing a denial-of-service for that operation. Affected paths include `convertToShares`, `convertToAssets`, the `globalIndex` accumulation in `notifyReward`, and the per-account pending calculation in `_pendingFor`.

### Conditions required

The product `x * y` must exceed `type(uint256).max` (~1.16 × 10⁷⁷). In `_pendingFor`, `delta = globalIndex - userIndex[account]` grows without bound as rewards accumulate over the lifetime of the contract. Given `balance * delta / WAD`, overflow becomes reachable when `balance * delta > ~1.16 × 10⁷⁷`. With realistic token decimals (18) and a long-running protocol, this is a real operational risk.

### Root cause

```solidity
function mulDiv(uint256 x, uint256 y, uint256 d) internal pure returns (uint256) {
    return (x * y) / d;   // ← plain multiplication, no 512-bit intermediate
}
```

Solidity 0.8.x reverts on overflow rather than wrapping, so the result is a hard revert rather than a silently wrong answer. This prevents incorrect computation but blocks legitimate operations indefinitely.

### Fix

Replace the plain multiplication with a 512-bit intermediate using the standard technique (Remco Bloemen's algorithm, as used by OpenZeppelin's `Math.mulDiv`).

---

## V-5 — Low: `transferOwnership` accepts `address(0)` as pending owner

**File:** `src/auth/Ownable2Step.sol`  
**Function:** `transferOwnership()` (line 30)

### What an attacker can do

The current owner can (accidentally or otherwise) set `pendingOwner = address(0)`. Since `address(0)` cannot sign transactions, `acceptOwnership` can never be called, and the transfer is silently stuck. The current owner can initiate a new transfer to overwrite it, but the confusing intermediate state could mask an operational error.

### Conditions required

The current owner calls `transferOwnership(address(0))`. No adversarial intent is needed; a mistyped address is sufficient.

### Fix

```solidity
function transferOwnership(address newOwner) external onlyOwner {
    require(newOwner != address(0), "OWNER_ZERO");
    ...
}
```

---

## V-6 — Low: Guardian can be set to `address(0)`

**File:** `src/core/StakingVault.sol`  
**Function:** `setGuardian()` (line 201), constructor (line 89)

### What an attacker can do

Neither the constructor nor `setGuardian` validates that the guardian is non-zero. Setting `guardian = address(0)` is harmless on standard EVM (no one holds the zero-address key), but it makes the `pause()` check `msg.sender != guardian` permanently false for that branch, silently removing the guardian role without an explicit revocation event that would signal intent.

### Conditions required

Owner calls `setGuardian(address(0))`, or the contract is deployed with `initialGuardian = address(0)`.

### Fix

Add `require(newGuardian != address(0), "GUARDIAN_ZERO")` in both places, or explicitly document that `address(0)` is the canonical "no guardian" sentinel.

---

## V-7 — Low: Zero cooldown accepted in `WithdrawalQueue`

**File:** `src/core/WithdrawalQueue.sol`  
**Function:** constructor (line 50)

### What an attacker can do

If `cooldown_ = 0`, the delay between `requestWithdrawal` and `completeWithdrawal` is zero blocks. The two-phase exit design (intended to give the protocol time to respond to anomalies, and to lock the fee rate) provides no actual protection. An attacker can atomically request and complete a withdrawal in a single transaction, bypassing any operational window the cooldown was meant to provide.

### Conditions required

The vault deployer sets `cooldown_ = 0` at deployment time (intentionally or by mistake). Because `cooldown` is immutable, there is no recovery.

### Fix

```solidity
constructor(address vault_, uint64 cooldown_) {
    require(vault_ != address(0), "VAULT_ZERO");
    require(cooldown_ > 0, "COOLDOWN_ZERO");
    ...
}
```

---

## Additional observations (informational)

- **`notifyReward` precision floor.** If `amount * WAD < totalSupply`, the `globalIndex` increment truncates to zero, and the transferred reward tokens are permanently locked in the distributor with no way to recover them (`src/rewards/RewardDistributor.sol:112`).
- **No token rescue path.** Fees truncated from withdrawal payouts (integer division of `assets * feeBps / BPS_DENOMINATOR`) accumulate as untracked token dust inside the vault with no sweep function.
- **`nonReentrant` uses 0/1 sentinel.** The guard is correct but writes a cold storage slot on every protected call. The 1/2 pattern (OpenZeppelin style) saves one cold write by keeping the slot warm.
