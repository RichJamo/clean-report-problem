# Staking Vault

A single-asset staking vault with a delayed exit queue and a separate pro-rata
reward stream.

Depositors stake the vault asset and receive non-transferable shares. Yield on
the staked asset is pushed in by the operator and raises the share price for
everyone. A second, unrelated reward token is distributed separately, in
proportion to each account's share balance at the time rewards are notified.

## Architecture

```
        ┌────────────────┐   fee policy    ┌────────────────┐
        │  StakingVault  │────────────────▶│ FeeController  │
        │                │                 └────────────────┘
        │  shares,       │   exit records  ┌────────────────┐
        │  totalAssets   │────────────────▶│WithdrawalQueue │
        └───────┬────────┘                 └────────────────┘
                │ checkpoint(account)
                ▼
        ┌────────────────────┐
        │ RewardDistributor  │
        └────────────────────┘
```

| Contract | Path | Role |
|---|---|---|
| `StakingVault` | `src/core/StakingVault.sol` | Share accounting, deposits, two-phase exits |
| `FeeController` | `src/core/FeeController.sol` | Withdrawal fee parameters, capped at 5% |
| `WithdrawalQueue` | `src/core/WithdrawalQueue.sol` | Exit records and cooldown enforcement |
| `RewardDistributor` | `src/rewards/RewardDistributor.sol` | Index-based reward token distribution |
| `Ownable2Step` | `src/auth/Ownable2Step.sol` | Two-step ownership handover |
| `SafeTransferLib` | `src/libraries/SafeTransferLib.sol` | ERC-20 calls tolerant of non-standard returns |
| `FixedPointMath` | `src/libraries/FixedPointMath.sol` | `mulDiv` with explicit rounding |

## Lifecycle

1. **Deposit.** `StakingVault.deposit(assets)` mints shares at the current
   exchange rate, rounding down. The reward distributor is checkpointed for the
   depositor first, so the balance change cannot backdate rewards.
2. **Yield.** The owner calls `accrueYield(assets)`, which raises `totalAssets`
   without minting shares. Every holder's shares become worth more.
3. **Exit request.** `requestWithdrawal(shares)` burns the shares immediately,
   converts them to an asset amount at the current price, and records the amount
   in the withdrawal queue with an unlock timestamp.
4. **Exit completion.** After the cooldown, `completeWithdrawal(id)` pays the
   recorded amount out, net of the withdrawal fee.

Exits are deliberately permitted while the vault is paused. A pause blocks new
deposits and yield accrual only; it must not be able to trap staked funds.

## Reward accounting

`RewardDistributor` uses the standard cumulative-index scheme. `globalIndex` is
the running total of reward tokens per share, in 18-decimal fixed point. An
account's entitlement since it was last seen is

```
balance * (globalIndex - userIndex[account]) / 1e18
```

Because the index only moves when the owner calls `notifyReward`, an account
that stakes after a notification earns nothing from it. The vault checkpoints an
account before changing its balance, which folds the entitlement earned so far
into `accrued[account]`.

## Design notes

- **`totalAssets` is tracked in storage**, not read from the token balance. An
  unsolicited transfer into the vault therefore cannot move the share price.
- **Shares are non-transferable.** There is no ERC-20 surface on the vault, so
  reward accounting only has to hook deposits and withdrawal requests.
- **The reward distributor is set once.** `setRewardDistributor` reverts if it
  has already been wired, so the reward stream cannot be repointed later.
- **The withdrawal queue never holds tokens.** It records who is owed what and
  when; the vault performs the transfer.

## Build

```
forge build
forge test
```

The project has no external dependencies.

## Status

Pre-audit. Deployed nowhere.
