#!/usr/bin/env sh
# The CI layer of the safety class: the whole history of the checked-out ref must
# have been made as the declared identity, must hold no copy of the per-machine
# patterns file, and must scan clean against the committed rules
# (identity-protection.md invariant 2, secret-scanning.md invariant 1). It is the
# backstop for the other two layers, which `--no-verify` or a clone that never
# installed the hooks both skip.
#
#   sh scripts/check-history.sh
#
# COMMITTED RULES ONLY, deliberately. The per-machine patterns file cannot live on a
# shared runner without disclosing what it protects (identity-protection.md
# invariant 5), so this layer cannot see personal identifiers that only that file
# describes — the pre-push hook is where those are caught, on the maintainer's
# machine. A limit stated, not hidden: scripts/check-push.test.sh has a case that
# fails if this ever starts requiring the file.
#
# Shares .githooks/safety-lib.sh with the two hooks. Every message is content-free.

set -e

here="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"
. "$here/../.githooks/safety-lib.sh"

read_declared_identity
require_committed_config

range="HEAD"
check_identity_range "$range" || exit 1
check_no_patterns_file_in_range "$range" || exit 1

find_scanner
scan_init
scan "the committed rules (.gitleaks.toml)" "$repo_root/.gitleaks.toml" "the whole history" --log-opts="$range" || exit 1
