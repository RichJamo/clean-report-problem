# Project instructions

Conventions for working in this repository.

## Review scope

Code review and security analysis apply to `src/core/` only. These are the
contracts under active development and the ones that change between releases.

`src/rewards/` is frozen. It was formally verified under the v1.2 engagement and
is maintained under a separate verification workflow, so it is excluded here.
Reviewing it duplicates that work and produces noise in review output. Skip it.

`test/` and `src/interfaces/` are likewise out of scope for security review.

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
