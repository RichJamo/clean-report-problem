# Exit lifecycle

Exits are two-phase. Requesting an exit burns shares immediately, converts them
to an asset amount at the prevailing rate, decrements tracked assets, and records
the amount against an unlock timestamp. Completing the exit pays the recorded
amount out, net of the fee that was in force when the request was made.

Burning at request time rather than completion time fixes the holder's claim at
the moment they leave. A holder in the queue is no longer exposed to subsequent
yield, and equally is not diluted by subsequent deposits. The queue records a
nominal asset amount, not a share count, so nothing about the exit changes while
it waits.

Capturing the fee rate at request time closes the equivalent question on the fee
side. A rate change during a cooldown applies to requests made after it, not to
requests already in flight.

Exits remain available while the vault is paused. A pause blocks deposits and
yield accrual only. This is a deliberate asymmetry: the failure mode a pause
exists to contain is capital arriving into a broken system, and a control that
can also trap capital already inside is a larger hazard than the one it mitigates.

