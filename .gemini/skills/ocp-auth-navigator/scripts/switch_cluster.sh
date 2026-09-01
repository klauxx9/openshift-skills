#!/usr/bin/env bash
# ==============================================================================
# OpenShift Cluster Switcher for L1 Operations
# ==============================================================================
# Usage:
#   ./switch_cluster.sh [cluster_alias]
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
LOGIN_SCRIPT="${BASE_DIR}/.gemini/scripts/oc-login.sh"

source "${BASE_DIR}/.gemini/scripts/utils.sh"

check_oc_installed

if [ "$#" -eq 0 ]; then
    log_info "No cluster specified. Displaying cluster directory:"
    "$LOGIN_SCRIPT" --list
    echo ""
    printf "${C_YELLOW}Enter Cluster ID to connect to: ${C_RESET}"
    read -r target
    if [ -n "$target" ]; then
        "$LOGIN_SCRIPT" "$target"
    fi
else
    "$LOGIN_SCRIPT" "$1"
fi

