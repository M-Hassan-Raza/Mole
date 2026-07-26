#!/usr/bin/env bats

setup_file() {
	PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
	export PROJECT_ROOT

	TEST_HOME="$(mktemp -d "${BATS_TEST_DIRNAME}/tmp-optimize-summary.XXXXXX")"
	export TEST_HOME
}

teardown_file() {
	if [[ "$TEST_HOME" == "${BATS_TEST_DIRNAME}/tmp-optimize-summary."* ]]; then
		rm -rf "$TEST_HOME"
	fi
}

@test "optimize dry-run summary reports outcomes instead of catalog size" {
	run env HOME="$TEST_HOME" MOLE_TEST_NO_AUTH=1 "$PROJECT_ROOT/mole" optimize --dry-run

	[[ "$status" -eq 0 ]] || { echo "$output"; return 1; }
	[[ "$output" =~ Would\ apply\ [0-9]+\ optimizations ]] || return 1
	local applied_count="${BASH_REMATCH[0]#Would apply }"
	applied_count="${applied_count% optimizations}"
	[[ "$output" != *"Would apply 23 optimizations"* ]] || return 1
	[[ "$output" =~ [0-9]+\ unchanged ]] || return 1
	[[ "$output" =~ [0-9]+\ skipped ]] || return 1
	[[ "$output" != *"System fully optimized"* ]] || return 1

	run env HOME="$TEST_HOME" "$PROJECT_ROOT/mole" history --json
	[[ "$status" -eq 0 ]] || { echo "$output"; return 1; }
	[[ "$output" == *"\"items\": $applied_count"* ]] || return 1
}
