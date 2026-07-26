#!/usr/bin/env bats

setup_file() {
	PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
	export PROJECT_ROOT

	TEST_HOME="$(mktemp -d "${BATS_TEST_DIRNAME}/tmp-optimize-probes.XXXXXX")"
	export TEST_HOME
}

teardown_file() {
	if [[ "$TEST_HOME" == "${BATS_TEST_DIRNAME}/tmp-optimize-probes."* ]]; then
		rm -rf "$TEST_HOME"
	fi
}

@test "system maintenance reports a failed Spotlight probe" {
	run env HOME="$TEST_HOME/system" PROJECT_ROOT="$PROJECT_ROOT" /bin/bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/optimize/tasks.sh"
unset MOLE_TEST_NO_AUTH MOLE_TEST_MODE
flush_dns_cache() { return 0; }
mdutil() { return 7; }

execute_optimization system_maintenance
[[ "$(optimize_outcome_count failed)" == "1" ]] || exit 1
EOF

	[[ "$status" -eq 0 ]] || { echo "$output"; return 1; }
	[[ "$output" == *"Failed to verify Spotlight index"* ]] || return 1
}

@test "Spotlight optimization reports a failed status probe" {
	run env HOME="$TEST_HOME/spotlight" PROJECT_ROOT="$PROJECT_ROOT" /bin/bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/optimize/tasks.sh"
run_with_timeout() { return 124; }

execute_optimization spotlight_index_optimize
[[ "$(optimize_outcome_count failed)" == "1" ]] || exit 1
EOF

	[[ "$status" -eq 0 ]] || { echo "$output"; return 1; }
	[[ "$output" == *"Failed to inspect Spotlight index (exit=124)"* ]] || return 1
}

@test "quarantine cleanup reports a failed row-count probe" {
	run env HOME="$TEST_HOME/quarantine" PROJECT_ROOT="$PROJECT_ROOT" /bin/bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/optimize/tasks.sh"
db="$HOME/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV2"
mkdir -p "$(dirname "$db")"
touch "$db"
sqlite3() { return 0; }
should_protect_path() { return 1; }
run_with_timeout() { return 7; }

execute_optimization quarantine_cleanup
[[ "$(optimize_outcome_count failed)" == "1" ]] || exit 1
EOF

	[[ "$status" -eq 0 ]] || { echo "$output"; return 1; }
	[[ "$output" == *"Failed to inspect quarantine database"* ]] || return 1
}

@test "login item audit reports a failed snapshot" {
	run env HOME="$TEST_HOME/login" PROJECT_ROOT="$PROJECT_ROOT" /bin/bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/optimize/tasks.sh"
unset MOLE_TEST_NO_AUTH MOLE_TEST_MODE
_login_items_snapshot() { return 7; }

execute_optimization login_items_audit
[[ "$(optimize_outcome_count failed)" == "1" ]] || exit 1
EOF

	[[ "$status" -eq 0 ]] || { echo "$output"; return 1; }
	[[ "$output" == *"Failed to inspect login items"* ]] || return 1
}

@test "notification cleanup reports a failed size probe" {
	run env HOME="$TEST_HOME/notification" PROJECT_ROOT="$PROJECT_ROOT" /bin/bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/optimize/tasks.sh"
getconf() { echo "$HOME/runtime"; }
db="$HOME/runtime/com.apple.notificationcenter/db2/db"
mkdir -p "$(dirname "$db")"
touch "$db"
opt_existing_file_size_kb_strict() { return 124; }

execute_optimization notification_cleanup
[[ "$(optimize_outcome_count failed)" == "1" ]] || exit 1
EOF

	[[ "$status" -eq 0 ]] || { echo "$output"; return 1; }
	[[ "$output" == *"Failed to inspect Notification Center database size"* ]] || return 1
}

@test "CoreDuet cleanup reports a failed size probe" {
	run env HOME="$TEST_HOME/coreduet-size" PROJECT_ROOT="$PROJECT_ROOT" /bin/bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/optimize/tasks.sh"
db="$HOME/Library/Application Support/Knowledge/knowledgeC.db"
mkdir -p "$(dirname "$db")"
touch "$db"
run_with_timeout() { return 124; }

execute_optimization coreduet_cleanup
[[ "$(optimize_outcome_count failed)" == "1" ]] || exit 1
EOF

	[[ "$status" -eq 0 ]] || { echo "$output"; return 1; }
	[[ "$output" == *"Failed to inspect Knowledge database size"* ]] || return 1
}

@test "Dock refresh reports failed touch and restart commands" {
	run env HOME="$TEST_HOME/dock" PROJECT_ROOT="$PROJECT_ROOT" /bin/bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/optimize/tasks.sh"
plist="$HOME/Library/Preferences/com.apple.dock.plist"
mkdir -p "$(dirname "$plist")"
command touch "$plist"
touch() { return 9; }
killall() { return 9; }

execute_optimization dock_refresh
[[ "$(optimize_outcome_count failed)" == "1" ]] || exit 1
[[ "$(optimize_outcome_count applied)" == "0" ]] || exit 1
EOF

	[[ "$status" -eq 0 ]] || { echo "$output"; return 1; }
	[[ "$output" == *"Dock refresh incomplete (2 operation(s) failed)"* ]] || return 1
	[[ "$output" != *"Dock refreshed"* ]] || return 1
}

@test "sudo-dependent maintenance is skipped when admin access is denied" {
	run env HOME="$TEST_HOME/admin" PROJECT_ROOT="$PROJECT_ROOT" MOLE_OPTIMIZE_SUDO_AVAILABLE=false /bin/bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/optimize/tasks.sh"
mdutil() { echo "UNEXPECTED_MDUTIL"; return 0; }

execute_optimization system_maintenance
execute_optimization network_optimization
[[ "$(optimize_outcome_count skipped)" == "2" ]] || exit 1
[[ "$(optimize_outcome_count failed)" == "0" ]] || exit 1
EOF

	[[ "$status" -eq 0 ]] || { echo "$output"; return 1; }
	[[ "$output" == *"admin access required"* ]] || return 1
	[[ "$output" != *"UNEXPECTED_MDUTIL"* ]] || return 1
}
