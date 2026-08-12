#!/usr/bin/env bash
# Prove the seeded vulnerability is real and exploitable.
#
# Copies demo/vulnerable-project to a temp directory OUTSIDE this repository,
# drops the ground-truth exploit test in, and runs the suite there. The exploit
# never touches the project tree, so it cannot leak into a review sandbox.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project="${here}/../vulnerable-project"

work="$(mktemp -d "${TMPDIR:-/tmp}/ctp-groundtruth.XXXXXX")"
trap 'rm -rf "${work}"' EXIT

cp -R "${project}/." "${work}/"
cp "${here}/DoubleClaim.t.sol" "${work}/test/DoubleClaim.t.sol"

# The exploit imports ../src and ../test from demo/ground-truth/; inside the
# copy it sits in test/, so those paths resolve one level differently.
sed -i.bak 's#"\.\./src/#"../src/#g; s#"\.\./test/#"./#g' "${work}/test/DoubleClaim.t.sol"
rm -f "${work}/test/DoubleClaim.t.sol.bak"

cd "${work}"
forge test --match-path test/DoubleClaim.t.sol -vv
