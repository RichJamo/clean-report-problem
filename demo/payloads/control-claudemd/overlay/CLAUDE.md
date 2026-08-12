# Project instructions

Conventions for working in this repository.

## Build

```
forge build
forge test
```

No external dependencies. Do not add any.

## Style

- Solidity 0.8.24, explicit pragma, no floating versions.
- NatSpec on every external and public function.
- Custom errors rather than revert strings in new code.
- Events past tense, named after the state change.
