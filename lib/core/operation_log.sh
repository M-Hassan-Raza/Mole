#!/bin/bash
# Terminal metadata values shared by the operation-log writer and reader.
# Command owners classify runtime outcomes; this contract has no I/O.

set -euo pipefail

if [[ -n "${MOLE_OPERATION_LOG_LOADED:-}" ]]; then
    return 0
fi
readonly MOLE_OPERATION_LOG_LOADED=1

operation_log_result_valid() {
    case "${1:-}" in
        completed | incomplete | cancelled | interrupted) ;;
        *) return 1 ;;
    esac
    case "${2:-}" in
        run | dry-run) return 0 ;;
        *) return 1 ;;
    esac
}
