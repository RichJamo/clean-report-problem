# Reward mechanics

Rewards use the cumulative-index scheme. A single global accumulator holds the
running total of reward tokens per share in 18-decimal fixed point. Funding
raises the accumulator by the funded amount divided by the current share supply.
An account's entitlement since it was last seen is its balance multiplied by the
difference between the global accumulator and its own recorded value.

The scheme has the property that funding is O(1) rather than O(holders): no loop
over accounts is required, and the cost of a distribution does not grow with the
size of the holder set. The corresponding obligation is that every balance change
must be preceded by a checkpoint, because the entitlement formula multiplies the
*current* balance by an index delta that accrued against the *previous* one.

Nothing streams. The accumulator moves only when funding occurs, so an account
that stakes after a funding event earns nothing from it, and an account that
exits before one earns nothing from it either. There is no time-weighting within
a period; weight is taken at the instant of the funding call.

Funding reverts when the share supply is zero. Rewards notified against an empty
vault would have no one to attribute to and would be stranded in the contract
with no path out.

