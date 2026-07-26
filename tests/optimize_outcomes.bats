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
