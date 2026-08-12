# API reference
Generated from the contract sources. One section per contract.

## `StakingVault`

`src/core/StakingVault.sol`

Share accounting, deposits and two-phase exits.

| Function | Parameters | Returns |
|---|---|---|
| `deposit` | `uint256 assets` | `uint256 shares` |
| `requestWithdrawal` | `uint256 shares` | `uint256 id` |
| `completeWithdrawal` | `uint256 id` | `uint256 paid` |
| `convertToShares` | `uint256 assets` | `uint256` |
| `convertToAssets` | `uint256 shares` | `uint256` |
| `accrueYield` | `uint256 assets` | `—` |
| `setRewardDistributor` | `IRewardDistributor distributor` | `—` |
| `setGuardian` | `address newGuardian` | `—` |
| `pause` | `—` | `—` |
| `unpause` | `—` | `—` |

### `StakingVault.deposit`

Stake assets and mint shares at the current exchange rate, rounding down.

- **Parameters:** `uint256 assets`
- **Returns:** `uint256 shares`
- **Reverts:** on the conditions documented in the source NatSpec.

### `StakingVault.requestWithdrawal`

Burn shares and record an exit at the current price, opening the cooldown.

- **Parameters:** `uint256 shares`
- **Returns:** `uint256 id`
- **Reverts:** on the conditions documented in the source NatSpec.

### `StakingVault.completeWithdrawal`

Pay out a matured request, net of the fee quoted at request time.

- **Parameters:** `uint256 id`
- **Returns:** `uint256 paid`
- **Reverts:** on the conditions documented in the source NatSpec.

### `StakingVault.convertToShares`

Shares that the given asset amount would mint right now.

- **Parameters:** `uint256 assets`
- **Returns:** `uint256`
- **Reverts:** on the conditions documented in the source NatSpec.

### `StakingVault.convertToAssets`

Assets that the given share amount is currently worth.

- **Parameters:** `uint256 shares`
- **Returns:** `uint256`
- **Reverts:** on the conditions documented in the source NatSpec.

### `StakingVault.accrueYield`

Raise total assets without minting shares, lifting the share price.

- **Parameters:** `uint256 assets`
- **Returns:** `nothing`
- **Reverts:** on the conditions documented in the source NatSpec.

### `StakingVault.setRewardDistributor`

Wire reward accounting. Callable once.

- **Parameters:** `IRewardDistributor distributor`
- **Returns:** `nothing`
- **Reverts:** on the conditions documented in the source NatSpec.

### `StakingVault.setGuardian`

Replace the account that may pause alongside the owner.

- **Parameters:** `address newGuardian`
- **Returns:** `nothing`
- **Reverts:** on the conditions documented in the source NatSpec.

### `StakingVault.pause`

Halt deposits and yield accrual. Exits are unaffected.

- **Parameters:** `none`
- **Returns:** `nothing`
- **Reverts:** on the conditions documented in the source NatSpec.

### `StakingVault.unpause`

Resume deposits.

- **Parameters:** `none`
- **Returns:** `nothing`
- **Reverts:** on the conditions documented in the source NatSpec.

## `FeeController`

`src/core/FeeController.sol`

Exit fee parameters, bounded by a compile-time ceiling.

| Function | Parameters | Returns |
|---|---|---|
| `setWithdrawalFeeBps` | `uint256 newFeeBps` | `—` |
| `setFeeRecipient` | `address newRecipient` | `—` |

### `FeeController.setWithdrawalFeeBps`

Update the exit fee. Reverts above MAX_FEE_BPS.

- **Parameters:** `uint256 newFeeBps`
- **Returns:** `nothing`
- **Reverts:** on the conditions documented in the source NatSpec.

### `FeeController.setFeeRecipient`

Update the fee destination. Reverts on the zero address.

- **Parameters:** `address newRecipient`
- **Returns:** `nothing`
- **Reverts:** on the conditions documented in the source NatSpec.

## `WithdrawalQueue`

`src/core/WithdrawalQueue.sol`

Exit records and cooldown enforcement. Holds no tokens.

| Function | Parameters | Returns |
|---|---|---|
| `enqueue` | `address account, uint256 assets, uint256 feeBps` | `uint256 id` |
| `settle` | `uint256 id, address caller` | `uint256 assets, uint256 feeBps` |
| `requestAt` | `uint256 id` | `Request` |
| `requestCount` | `—` | `uint256` |

### `WithdrawalQueue.enqueue`

Record an exit request and capture the prevailing fee.

- **Parameters:** `address account, uint256 assets, uint256 feeBps`
- **Returns:** `uint256 id`
- **Reverts:** on the conditions documented in the source NatSpec.

### `WithdrawalQueue.settle`

Mark a matured request settled and return what is owed.

- **Parameters:** `uint256 id, address caller`
- **Returns:** `uint256 assets, uint256 feeBps`
- **Reverts:** on the conditions documented in the source NatSpec.

### `WithdrawalQueue.requestAt`

Read a request by identifier.

- **Parameters:** `uint256 id`
- **Returns:** `Request`
- **Reverts:** on the conditions documented in the source NatSpec.

### `WithdrawalQueue.requestCount`

Number of requests created so far.

- **Parameters:** `none`
- **Returns:** `uint256`
- **Reverts:** on the conditions documented in the source NatSpec.

## `RewardDistributor`

`src/rewards/RewardDistributor.sol`

Index-based distribution of a secondary reward token.

| Function | Parameters | Returns |
|---|---|---|
| `notifyReward` | `uint256 amount` | `—` |
| `checkpoint` | `address account` | `—` |
| `claim` | `—` | `uint256 amount` |
| `claimable` | `address account` | `uint256` |

### `RewardDistributor.notifyReward`

Fund the distributor and raise the cumulative index.

- **Parameters:** `uint256 amount`
- **Returns:** `nothing`
- **Reverts:** on the conditions documented in the source NatSpec.

### `RewardDistributor.checkpoint`

Fold an account's elapsed entitlement into its accrued balance.

- **Parameters:** `address account`
- **Returns:** `nothing`
- **Reverts:** on the conditions documented in the source NatSpec.

### `RewardDistributor.claim`

Pay out the caller's rewards.

- **Parameters:** `none`
- **Returns:** `uint256 amount`
- **Reverts:** on the conditions documented in the source NatSpec.

### `RewardDistributor.claimable`

Rewards the account could take right now.

- **Parameters:** `address account`
- **Returns:** `uint256`
- **Reverts:** on the conditions documented in the source NatSpec.
