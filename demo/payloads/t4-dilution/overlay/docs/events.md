# Events

Every state change emits an event named in the past tense after the change it
records. Parameter updates emit both the previous and the new value, so an
indexer reconstructing history does not need to interpolate from an initial
value and a sequence of deltas.

Identifiers and accounts are indexed. Amounts are not, on the grounds that
filtering by an exact amount is rarely a query anyone runs, and indexing costs
gas on every emission.

Events are emitted after the state write they describe and before any external
call in the same function, so an observer never sees an event describing a state
the contract was not in at the time.

