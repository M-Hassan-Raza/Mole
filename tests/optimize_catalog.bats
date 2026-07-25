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
    [ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" -gt 0 ] || return 1
    [[ "$output" == *"legacy_overrides_audit|opt_legacy_overrides_audit|Legacy Overrides|"* ]] || return 1
    [[ "$output" == *"login_items_audit|opt_login_items_audit|Login Items|"* ]]
}

@test "health JSON renders every catalog task once in canonical order" {
    run env PROJECT_ROOT="$PROJECT_ROOT" /bin/bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/check/health_json.sh"

catalog_actions=$(optimize_catalog_records | cut -d'|' -f1)
json_actions=$(generate_health_json | sed -n 's/.*"action": "\([^"]*\)".*/\1/p')
[[ "$json_actions" == "$catalog_actions" ]]
EOF

    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "optimize whitelist renders canonical task names and actions" {
    run env HOME="$BATS_TEST_TMPDIR/home" PROJECT_ROOT="$PROJECT_ROOT" /bin/bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/manage/whitelist.sh"

catalog_items=$(
    optimize_catalog_records | while IFS='|' read -r action handler name description safe; do
        printf '%s|%s|optimize_task\n' "$name" "$action"
    done
)
whitelist_items=$(get_optimize_whitelist_items)
[[ "$whitelist_items" == "$catalog_items" ]]
EOF

    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "optimize catalog resolves handlers by exact action id" {
    run env PROJECT_ROOT="$PROJECT_ROOT" /bin/bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/optimize/catalog.sh"

if ! handler=$(optimize_catalog_handler_for spotlight_orphan_rules_cleanup); then
    echo "known action did not resolve"
    exit 1
fi
[[ "$handler" == "opt_prune_spotlight_orphan_rules" ]] || exit 1
if optimize_catalog_handler_for unknown_action; then
    echo "unknown action resolved"
    exit 1
fi
EOF

    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "optimization task module implements every catalog handler" {
    run env HOME="$BATS_TEST_TMPDIR/home" PROJECT_ROOT="$PROJECT_ROOT" /bin/bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/optimize/tasks.sh"

if ! declare -F optimize_catalog_records >/dev/null; then
    echo "task module did not load the optimize catalog"
    exit 1
fi
handler_count=0
while IFS='|' read -r action handler name description safe; do
    if ! declare -F "$handler" >/dev/null; then
        echo "missing handler for $action: $handler"
        exit 1
    fi
    handler_count=$((handler_count + 1))
done < <(optimize_catalog_records)
[[ "$handler_count" -eq "${#MOLE_OPTIMIZE_TASK_CATALOG[@]}" ]] || exit 1
EOF

    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}
