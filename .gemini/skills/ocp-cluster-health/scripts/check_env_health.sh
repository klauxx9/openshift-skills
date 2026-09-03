#!/usr/bin/env bash
# ==============================================================================
# OpenShift Multi-Cluster Environment Health Checker (READ-ONLY)
# ==============================================================================
# Iterates through all clusters in a target environment (DEV, STAGING, PROD, DR, ALL)
# logs in using the credentials store, and audits cluster health in batch.
#
# Usage:
#   ./check_env_health.sh <environment_or_cluster_name>
#
# Examples:
#   ./check_env_health.sh dev
#   ./check_env_health.sh prod
#   ./check_env_health.sh all
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
CONFIG_DIR="${BASE_DIR}/.gemini/config"
LOGIN_SCRIPT="${BASE_DIR}/.gemini/scripts/oc-login.sh"
PARSER_SCRIPT="${BASE_DIR}/.gemini/scripts/parse_inventory.sh"

source "${BASE_DIR}/.gemini/scripts/utils.sh"

check_oc_installed

TARGET_ENV="${1:-dev}"

log_info "Discovering clusters for environment: ${C_BOLD}${TARGET_ENV}${C_RESET}..."
CLUSTERS_RAW=$("$PARSER_SCRIPT" "$CONFIG_DIR" get-env-clusters "$TARGET_ENV")

if [ -z "$CLUSTERS_RAW" ]; then
    log_error "No clusters found for environment '$TARGET_ENV'."
    log_info "Available environments: dev, staging, prod, dr, all"
    exit 1
fi

read -r -a CLUSTERS <<< "$CLUSTERS_RAW"
TOTAL_CLUSTERS=${#CLUSTERS[@]}

log_info "Found ${TOTAL_CLUSTERS} cluster(s) to audit: ${C_BOLD}${CLUSTERS[*]}${C_RESET}"
echo ""

# Multi-Cluster Audit Matrix Header
printf "${C_CYAN}${C_BOLD}====================================================================================================${C_RESET}\n"
printf "${C_CYAN}${C_BOLD}              OPENSHIFT MULTI-CLUSTER ENVIRONMENT HEALTH AUDIT (${TARGET_ENV^^})                   ${C_RESET}\n"
printf "${C_CYAN}${C_BOLD}====================================================================================================${C_RESET}\n"
printf "%-14s | %-10s | %-12s | %-12s | %-12s | %-12s | %s\n" "CLUSTER" "VERSION" "OPERATORS" "NODES" "MCPS" "CORE PODS" "OVERALL"
printf "%s\n" "----------------------------------------------------------------------------------------------------"

declare -a AUDIT_RESULTS=()

for cluster_id in "${CLUSTERS[@]}"; do
    printf "Auditing ${C_BOLD}%-12s${C_RESET}... " "$cluster_id"
    
    # 1. Login to cluster (redirect stdout to keep summary clean)
    if ! "$LOGIN_SCRIPT" "$cluster_id" >/dev/null 2>&1; then
        printf "${C_RED}AUTH FAILED${C_RESET}\n"
        AUDIT_RESULTS+=("${cluster_id}|N/A|AUTH_FAIL|AUTH_FAIL|AUTH_FAIL|AUTH_FAIL|FAILED")
        continue
    fi

    # 2. Cluster Version
    cv_status=$(oc get clusterversion version -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "Unknown")
    cv_version=$(oc get clusterversion version -o jsonpath='{.status.desired.version}' 2>/dev/null || echo "Unknown")

    # 3. Cluster Operators Degraded Check
    degraded_co_count=$(oc get co --no-headers 2>/dev/null | awk '$3 != "True" || $4 == "True" || $5 == "True"' | wc -l | tr -d ' ')
    if [ "$degraded_co_count" -eq 0 ]; then
        co_res="Healthy (0)"
    else
        co_res="Degraded (${degraded_co_count})"
    fi

    # 4. Unready Nodes Check
    unready_node_count=$(oc get nodes --no-headers 2>/dev/null | awk '$2 !~ /Ready/ || $2 ~ /NotReady/' | wc -l | tr -d ' ')
    total_node_count=$(oc get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [ "$unready_node_count" -eq 0 ]; then
        node_res="Ready (${total_node_count})"
    else
        node_res="Unready (${unready_node_count}/${total_node_count})"
    fi

    # 5. Degraded MCP Check
    degraded_mcp_count=$(oc get mcp --no-headers 2>/dev/null | awk '$5 == "True"' | wc -l | tr -d ' ' || echo "0")
    if [ "$degraded_mcp_count" -eq 0 ]; then
        mcp_res="Healthy"
    else
        mcp_res="Degraded (${degraded_mcp_count})"
    fi

    # 6. Failing Core Pods
    bad_core_pods=$(oc get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null | grep -E '^openshift-' | wc -l | tr -d ' ' || echo "0")
    if [ "$bad_core_pods" -eq 0 ]; then
        pod_res="Healthy (0)"
    else
        pod_res="Issues (${bad_core_pods})"
    fi

    # Overall State
    if [ "$degraded_co_count" -eq 0 ] && [ "$unready_node_count" -eq 0 ] && [ "$degraded_mcp_count" -eq 0 ]; then
        overall="${C_GREEN}HEALTHY${C_RESET}"
    else
        overall="${C_RED}DEGRADED${C_RESET}"
    fi

    printf "${C_GREEN}DONE${C_RESET}\n"
    AUDIT_RESULTS+=("${cluster_id}|${cv_version}|${co_res}|${node_res}|${mcp_res}|${pod_res}|${overall}")
done

echo ""
printf "${C_BOLD}Consolidated Environment Summary Report:${C_RESET}\n"
printf "%-14s | %-10s | %-12s | %-12s | %-12s | %-12s | %s\n" "CLUSTER" "VERSION" "OPERATORS" "NODES" "MCPS" "CORE PODS" "OVERALL"
printf "%s\n" "----------------------------------------------------------------------------------------------------"

for row in "${AUDIT_RESULTS[@]}"; do
    IFS='|' read -r r_id r_ver r_co r_nodes r_mcp r_pods r_overall <<< "$row"
    printf "%-14s | %-10s | %-12s | %-12s | %-12s | %-12s | %b\n" "$r_id" "$r_ver" "$r_co" "$r_nodes" "$r_mcp" "$r_pods" "$r_overall"
done

printf "${C_CYAN}====================================================================================================${C_RESET}\n"
log_success "Multi-cluster audit completed for environment: ${TARGET_ENV^^}"

