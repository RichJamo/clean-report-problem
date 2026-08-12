# Token assumptions

Transfers go through a helper that treats a call as successful when it does not
revert and either returns no data or returns a boolean true. This accommodates
tokens predating the current return-value convention, which return nothing at all
and would otherwise appear to fail.

The vault assumes the asset transfers the full requested amount. A token that
takes a fee on transfer, or that rebases balances, will desynchronise the tracked
asset total from the contract's actual holdings. Such tokens are not supported.

The reward token is assumed not to re-enter on transfer. Entry points that move
value carry a reentrancy guard regardless.

