#!/usr/bin/env bats

setup_file() {
	PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
	export PROJECT_ROOT
}

@test "optimize outcomes record one result per task" {
	run env PROJECT_ROOT="$PROJECT_ROOT" /bin/bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/optimize/outcomes.sh"

optimize_outcomes_reset
optimize_task_start
optimize_task_result "$MOLE_OPTIMIZE_OUTCOME_APPLIED"
optimize_task_finish system_maintenance

[[ "$(optimize_outcome_count applied)" == "1" ]] || exit 1
[[ "$(optimize_outcome_count unchanged)" == "0" ]] || exit 1
[[ "$(optimize_outcome_total)" == "1" ]] || exit 1
EOF

	[[ "$status" -eq 0 ]] || { echo "$output"; return 1; }
}

@test "optimize outcomes reject invalid and duplicate task results" {
	run env PROJECT_ROOT="$PROJECT_ROOT" /bin/bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/optimize/outcomes.sh"

if optimize_task_result invented; then
    echo "invalid outcome accepted"
    exit 1
fi

optimize_task_result "$MOLE_OPTIMIZE_OUTCOME_UNCHANGED"
if optimize_task_result "$MOLE_OPTIMIZE_OUTCOME_APPLIED"; then
    echo "second task outcome accepted"
    exit 1
fi
EOF

	[[ "$status" -eq 0 ]] || { echo "$output"; return 1; }
	[[ "$output" == *"Invalid optimize task outcome: invented"* ]] || return 1
	[[ "$output" == *"Optimize task outcome is already set: unchanged"* ]] || return 1
}

@test "optimize outcomes reject missing and duplicate task records" {
	run env PROJECT_ROOT="$PROJECT_ROOT" /bin/bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/optimize/outcomes.sh"

if optimize_task_finish periodic_maintenance; then
    echo "missing task outcome accepted"
    exit 1
fi

optimize_task_result "$MOLE_OPTIMIZE_OUTCOME_UNAVAILABLE"
optimize_task_finish periodic_maintenance
optimize_task_result "$MOLE_OPTIMIZE_OUTCOME_UNCHANGED"
if optimize_task_finish periodic_maintenance; then
    echo "duplicate task record accepted"
    exit 1
fi
EOF

	[[ "$status" -eq 0 ]] || { echo "$output"; return 1; }
	[[ "$output" == *"Optimize task did not report an outcome: periodic_maintenance"* ]] || return 1
	[[ "$output" == *"Optimize task outcome is already recorded: periodic_maintenance"* ]] || return 1
}
