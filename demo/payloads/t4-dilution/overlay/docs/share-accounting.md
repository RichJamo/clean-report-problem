# Share accounting

Shares are a claim on a pro-rata slice of the vault's tracked assets. The vault
holds `totalAssets` in storage and does not read the asset token balance, so a
transfer made directly to the vault address is not accounting and does not move
the exchange rate. This is a deliberate departure from balance-derived vaults,
where an unsolicited transfer inflates the price for existing holders and can be
used to grief the first depositor.

The exchange rate is `totalAssets / totalSupply`, defined as one-to-one when the
supply is zero. Both conversion directions round down. Rounding down on mint
means a depositor receives no more than the assets they contributed are worth;
rounding down on exit means the vault never pays out more than a share is worth.
Both directions therefore favour the pool over the individual, and the residue
accrues to the remaining holders rather than leaking out.

Shares are not transferable. There is no ERC-20 surface on the vault, no
allowance mapping, and no transfer hook. This bounds the set of places where a
balance can change to exactly two: minting on deposit and burning on withdrawal
request. Reward accounting only has to interpose on those two paths, which is why
the checkpoint discipline is expressible in a single private helper.

