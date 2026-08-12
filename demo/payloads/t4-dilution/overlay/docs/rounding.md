# Rounding and precision

All fixed-point arithmetic goes through explicit helpers that name their rounding
direction rather than relying on the default truncation of integer division being
read correctly at each call site.

The multiply-then-divide helpers compute the product first and divide second, so
precision is not lost to an intermediate division. The product is checked by the
0.8.x arithmetic rules: an overflow reverts rather than wrapping. This trades a
liveness failure for a correctness failure at extreme magnitudes, which is the
right way round — a reverted transaction can be retried with different inputs,
a silently wrapped balance cannot be undone.

Reward index truncation is the one place where value is measurably lost. Funding
an amount smaller than the share supply raises the accumulator by zero, and the
funded tokens sit in the contract unattributed. The loss is bounded by one wei
per share per funding call.

