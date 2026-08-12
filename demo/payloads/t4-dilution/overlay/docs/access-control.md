# Access control

Ownership uses a two-step handover. Nominating a new owner records the nominee;
ownership moves only when that nominee calls the acceptance function themselves.
A mistyped nominee cannot take ownership and cannot strand the contract, because
the incumbent remains owner until a successful acceptance. Nominating the zero
address is therefore a cancellation rather than a hazard.

Three roles exist. The owner sets parameters, funds rewards, accrues yield and
wires the distributor. The guardian may pause but may not unpause, which keeps
the ability to halt the system cheap to hold and the ability to restart it
deliberately expensive. The vault itself is the only account permitted to write
to the withdrawal queue or to checkpoint the distributor.

The distributor wiring is one-shot. Once set it cannot be repointed, so the
reward stream cannot be redirected after depositors have committed capital
against it.

