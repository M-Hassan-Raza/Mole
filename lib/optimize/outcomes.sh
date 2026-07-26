#!/bin/bash
# Canonical runtime outcomes for optimize tasks.

set -euo pipefail

if [[ -n "${MOLE_OPTIMIZE_OUTCOMES_LOADED:-}" ]]; then
    return 0
fi
readonly MOLE_OPTIMIZE_OUTCOMES_LOADED=1

readonly MOLE_OPTIMIZE_OUTCOME_APPLIED="applied"
readonly MOLE_OPTIMIZE_OUTCOME_UNCHANGED="unchanged"
readonly MOLE_OPTIMIZE_OUTCOME_SKIPPED="skipped"
readonly MOLE_OPTIMIZE_OUTCOME_UNAVAILABLE="unavailable"
readonly MOLE_OPTIMIZE_OUTCOME_FAILED="failed"
readonly -a MOLE_OPTIMIZE_OUTCOME_VALUES=(
    "$MOLE_OPTIMIZE_OUTCOME_APPLIED"
    "$MOLE_OPTIMIZE_OUTCOME_UNCHANGED"
    "$MOLE_OPTIMIZE_OUTCOME_SKIPPED"
    "$MOLE_OPTIMIZE_OUTCOME_UNAVAILABLE"
    "$MOLE_OPTIMIZE_OUTCOME_FAILED"
)

declare -a MOLE_OPTIMIZE_RESULT_ACTIONS=()
declare -a MOLE_OPTIMIZE_RESULT_OUTCOMES=()
MOLE_OPTIMIZE_TASK_ACTIVE=0
MOLE_OPTIMIZE_TASK_OUTCOME=""

_optimize_outcome_is_valid() {
    case "$1" in
        "$MOLE_OPTIMIZE_OUTCOME_APPLIED" | \
            "$MOLE_OPTIMIZE_OUTCOME_UNCHANGED" | \
            "$MOLE_OPTIMIZE_OUTCOME_SKIPPED" | \
            "$MOLE_OPTIMIZE_OUTCOME_UNAVAILABLE" | \
            "$MOLE_OPTIMIZE_OUTCOME_FAILED") return 0 ;;
        *) return 1 ;;
    esac
}

optimize_outcomes_reset() {
    MOLE_OPTIMIZE_RESULT_ACTIONS=()
    MOLE_OPTIMIZE_RESULT_OUTCOMES=()
    MOLE_OPTIMIZE_TASK_ACTIVE=0
    MOLE_OPTIMIZE_TASK_OUTCOME=""
}

optimize_task_start() {
    if [[ "$MOLE_OPTIMIZE_TASK_ACTIVE" == "1" ]]; then
        echo "Previous optimize task was not finished" >&2
        return 1
    fi
    MOLE_OPTIMIZE_TASK_ACTIVE=1
    MOLE_OPTIMIZE_TASK_OUTCOME=""
}

optimize_task_result() {
    local outcome="$1"

    if ! _optimize_outcome_is_valid "$outcome"; then
        echo "Invalid optimize task outcome: $outcome" >&2
        return 1
    fi
    if [[ "$MOLE_OPTIMIZE_TASK_ACTIVE" == "1" && -n "$MOLE_OPTIMIZE_TASK_OUTCOME" ]]; then
        echo "Optimize task outcome is already set: $MOLE_OPTIMIZE_TASK_OUTCOME" >&2
        return 1
    fi
    MOLE_OPTIMIZE_TASK_OUTCOME="$outcome"
}

optimize_task_finish() {
    local action="$1"

    if [[ "$MOLE_OPTIMIZE_TASK_ACTIVE" != "1" ]]; then
        echo "Optimize task was not started: $action" >&2
        return 1
    fi
    if [[ ! "$action" =~ ^[a-z0-9_]+$ ]]; then
        echo "Invalid optimize task action: $action" >&2
        return 1
    fi
    if [[ -z "$MOLE_OPTIMIZE_TASK_OUTCOME" ]]; then
        echo "Optimize task did not report an outcome: $action" >&2
        return 1
    fi

    local existing
    if [[ ${#MOLE_OPTIMIZE_RESULT_ACTIONS[@]} -gt 0 ]]; then
        for existing in "${MOLE_OPTIMIZE_RESULT_ACTIONS[@]}"; do
            if [[ "$existing" == "$action" ]]; then
                echo "Optimize task outcome is already recorded: $action" >&2
                return 1
            fi
        done
    fi

    MOLE_OPTIMIZE_RESULT_ACTIONS+=("$action")
    MOLE_OPTIMIZE_RESULT_OUTCOMES+=("$MOLE_OPTIMIZE_TASK_OUTCOME")
    MOLE_OPTIMIZE_TASK_ACTIVE=0
    MOLE_OPTIMIZE_TASK_OUTCOME=""
}

optimize_outcome_count() {
    local requested="$1"
    if ! _optimize_outcome_is_valid "$requested"; then
        echo "Invalid optimize task outcome: $requested" >&2
        return 1
    fi

    local count=0 outcome
    if [[ ${#MOLE_OPTIMIZE_RESULT_OUTCOMES[@]} -gt 0 ]]; then
        for outcome in "${MOLE_OPTIMIZE_RESULT_OUTCOMES[@]}"; do
            if [[ "$outcome" == "$requested" ]]; then
                count=$((count + 1))
            fi
        done
    fi
    printf '%s\n' "$count"
}

optimize_outcome_total() {
    printf '%s\n' "${#MOLE_OPTIMIZE_RESULT_ACTIONS[@]}"
}
