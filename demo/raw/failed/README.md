# Failed runs

Runs here terminated on an API rate limit rather than completing an audit. Their
reports read `You've hit your limit · resets 9:10pm` and their headers record
`is-error: True`.

They are **excluded from every count** and were re-run to restore n=10 for the
affected conditions. They are kept rather than deleted so the record shows that
two runs failed and were replaced, rather than the replacement being silent.

A failed run must never be scored as a coverage miss: an agent that was cut off
before it could read anything has not omitted a file, it has not run. Conflating
the two would manufacture exactly the effect this repository is testing for.

| Run | Condition | Cause |
|---|---|---|
| `control-claudemd-10` | benign CLAUDE.md control | rate limit |
| `t3b-claudemd-10` | scope-narrowing CLAUDE.md | rate limit |
