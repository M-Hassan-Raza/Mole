#!/bin/bash
# Canonical optimization task metadata and handler ownership.

set -euo pipefail

if [[ -n "${MOLE_OPTIMIZE_CATALOG_LOADED:-}" ]]; then
    return 0
fi
readonly MOLE_OPTIMIZE_CATALOG_LOADED=1

# Record contract: action|handler|display name|description|safe
#
# Actions are stable identifiers used by the optimization whitelist. Handlers
# are trusted function names implemented in tasks.sh. Display metadata is also
# rendered into the health JSON contract, so callers must consume these records
# instead of maintaining parallel task lists.
readonly MOLE_OPTIMIZE_TASK_CATALOG=(
    'system_maintenance|opt_system_maintenance|DNS & Spotlight Check|Refresh DNS cache & verify Spotlight status|true'
    'cache_refresh|opt_cache_refresh|Finder Cache Refresh|Refresh QuickLook thumbnails & icon services cache|true'
    'saved_state_cleanup|opt_saved_state_cleanup|App State Cleanup|Remove old saved application states (30+ days)|true'
    'fix_broken_configs|opt_fix_broken_configs|Broken Config Repair|Fix corrupted preferences files|true'
    'network_optimization|opt_network_optimization|Network Cache Refresh|Optimize DNS cache & restart mDNSResponder|true'
    'sqlite_vacuum|opt_sqlite_vacuum|Database Optimization|Compress SQLite databases for Mail, Safari & Messages (skips if apps are running)|true'
    'launch_services_rebuild|opt_launch_services_rebuild|LaunchServices Repair|Repair "Open with" menu & file associations|true'
    'dock_refresh|opt_dock_refresh|Dock Refresh|Fix broken icons and visual glitches in the Dock|true'
    'prevent_network_dsstore|opt_prevent_network_dsstore|Prevent Finder .DS_Store|Set a persistent Finder preference to stop writing .DS_Store on SMB/AFP/NFS and USB volumes|true'
    'legacy_overrides_audit|opt_legacy_overrides_audit|Legacy Overrides|Remove hidden App Nap and disk-image verification overrides left by old tweak tools|true'
    'memory_pressure_relief|opt_memory_pressure_relief|Memory Optimization|Release inactive memory to improve system responsiveness|true'
    'network_stack_optimize|opt_network_stack_optimize|Network Stack Refresh|Flush routing table and ARP cache to resolve network issues|true'
    'disk_permissions_repair|opt_disk_permissions_repair|Permission Repair|Fix user directory permission issues|true'
    'spotlight_index_optimize|opt_spotlight_index_optimize|Spotlight Optimization|Rebuild index if search is slow (smart detection)|true'
    'spotlight_orphan_rules_cleanup|opt_prune_spotlight_orphan_rules|Spotlight Orphan Rules|Remove Spotlight search-rule entries for apps that are no longer installed|true'
    'periodic_maintenance|opt_periodic_maintenance|Periodic Maintenance|Run macOS daily/weekly/monthly maintenance scripts if stale|true'
    'shared_file_list_repair|opt_shared_file_list_repair|Shared File Lists|Repair corrupted Finder favorites and recent documents|true'
    'disk_verify|opt_disk_verify|Disk Health|Verify filesystem integrity|true'
    'login_items_audit|opt_login_items_audit|Login Items|Audit login items for broken entries|true'
    'quarantine_cleanup|opt_quarantine_cleanup|Quarantine Database Cleanup|Clear Gatekeeper download tracking history|true'
    'launch_agents_cleanup|opt_launch_agents_cleanup|Launch Agents Cleanup|Remove broken LaunchAgents whose binaries no longer exist|true'
    'notification_cleanup|opt_notification_cleanup|Notifications|Clean old delivered notifications to reduce database bloat|true'
    'coreduet_cleanup|opt_coreduet_cleanup|Usage Data|Clean old usage tracking data|true'
)

optimize_catalog_records() {
    printf '%s\n' "${MOLE_OPTIMIZE_TASK_CATALOG[@]}"
}

optimize_catalog_validate() {
    if [[ ${#MOLE_OPTIMIZE_TASK_CATALOG[@]} -eq 0 ]]; then
        echo "Optimize task catalog is empty" >&2
        return 1
    fi

    local seen_actions="|"
    local record action handler name description safe terminator
    for record in "${MOLE_OPTIMIZE_TASK_CATALOG[@]}"; do
        IFS='|' read -r action handler name description safe terminator <<< "$record|__end__"

        if [[ "$terminator" != "__end__" || -z "$name" || -z "$description" ]]; then
            echo "Invalid optimize task record: $record" >&2
            return 1
        fi
        if [[ ! "$action" =~ ^[a-z0-9_]+$ || ! "$handler" =~ ^opt_[a-z0-9_]+$ ]]; then
            echo "Invalid optimize task identity: $action|$handler" >&2
            return 1
        fi
        if [[ "$safe" != "true" && "$safe" != "false" ]]; then
            echo "Invalid optimize task safety value for $action: $safe" >&2
            return 1
        fi
        if [[ "$seen_actions" == *"|$action|"* ]]; then
            echo "Duplicate optimize task action: $action" >&2
            return 1
        fi
        seen_actions+="$action|"
    done
}
