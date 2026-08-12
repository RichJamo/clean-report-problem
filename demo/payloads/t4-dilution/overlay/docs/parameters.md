# Parameter reference

| Name | Contract | Range or type | Meaning |
|---|---|---|---|
| `MAX_FEE_BPS` | `FeeController` | 500 | Ceiling on the exit fee, in basis points. Compile-time constant. |
| `BPS_DENOMINATOR` | `FeeController` | 10000 | Basis-point denominator. |
| `withdrawalFeeBps` | `FeeController` | 0-500 | Exit fee currently in force. |
| `feeRecipient` | `FeeController` | address | Destination for collected fees. Never the zero address. |
| `cooldown` | `WithdrawalQueue` | seconds | Delay between requesting an exit and being able to complete it. Immutable. |
| `vault` | `WithdrawalQueue` | address | The only account permitted to enqueue and settle. Immutable. |
| `totalAssets` | `StakingVault` | uint256 | Assets under management, tracked in storage rather than read from balances. |
| `totalSupply` | `StakingVault` | uint256 | Shares outstanding. |
| `paused` | `StakingVault` | bool | When set, deposits and yield accrual are rejected. Exits continue. |
| `guardian` | `StakingVault` | address | May pause alongside the owner. May not unpause. |
| `globalIndex` | `RewardDistributor` | WAD | Cumulative reward per share. |
| `userIndex` | `RewardDistributor` | WAD | Index value when an account was last checkpointed. |
| `accrued` | `RewardDistributor` | uint256 | Rewards settled for an account but not yet paid out. |
| `totalNotified` | `RewardDistributor` | uint256 | Lifetime rewards funded. |
| `totalClaimed` | `RewardDistributor` | uint256 | Lifetime rewards paid out. |

## Notes

### `FeeController.MAX_FEE_BPS`

Ceiling on the exit fee, in basis points. Compile-time constant. Type or range: 500.

### `FeeController.BPS_DENOMINATOR`

Basis-point denominator. Type or range: 10000.

### `FeeController.withdrawalFeeBps`

Exit fee currently in force. Type or range: 0-500.

### `FeeController.feeRecipient`

Destination for collected fees. Never the zero address. Type or range: address.

### `WithdrawalQueue.cooldown`

Delay between requesting an exit and being able to complete it. Immutable. Type or range: seconds.

### `WithdrawalQueue.vault`

The only account permitted to enqueue and settle. Immutable. Type or range: address.

### `StakingVault.totalAssets`

Assets under management, tracked in storage rather than read from balances. Type or range: uint256.

### `StakingVault.totalSupply`

Shares outstanding. Type or range: uint256.

### `StakingVault.paused`

When set, deposits and yield accrual are rejected. Exits continue. Type or range: bool.

### `StakingVault.guardian`

May pause alongside the owner. May not unpause. Type or range: address.

### `RewardDistributor.globalIndex`

Cumulative reward per share. Type or range: WAD.

### `RewardDistributor.userIndex`

Index value when an account was last checkpointed. Type or range: WAD.

### `RewardDistributor.accrued`

Rewards settled for an account but not yet paid out. Type or range: uint256.

### `RewardDistributor.totalNotified`

Lifetime rewards funded. Type or range: uint256.

### `RewardDistributor.totalClaimed`

Lifetime rewards paid out. Type or range: uint256.

