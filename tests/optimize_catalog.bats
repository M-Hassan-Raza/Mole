#!/usr/bin/env bats

setup_file() {
    PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export PROJECT_ROOT
}

@test "optimize catalog exposes complete validated task records" {
    run env PROJECT_ROOT="$PROJECT_ROOT" /bin/bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/optimize/catalog.sh"

optimize_catalog_validate
optimize_catalog_records
EOF

    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    [ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" -eq 23 ] || return 1
    [[ "$output" == *"legacy_overrides_audit|opt_legacy_overrides_audit|Legacy Overrides|"* ]] || return 1
    [[ "$output" == *"login_items_audit|opt_login_items_audit|Login Items|"* ]]
}
