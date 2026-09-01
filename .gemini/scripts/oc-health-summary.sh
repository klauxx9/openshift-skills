#!/usr/bin/env bash
# ==============================================================================
# OpenShift L1 Cluster Health Summary Tool (READ-ONLY)
# ==============================================================================
# Performs a non-invasive, fast health check of the currently connected cluster.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

check_cluster_health() {
    check_oc_installed

    echo ""
    printf "${C_CYAN}${C_BOLD}====================================================================${C_RESET}\n"
    printf "${C_CYAN}${C_BOLD}               OPENSHIFT CLUSTER HEALTH SUMMARY (L1)                ${C_RESET}\n"
    printf "${C_CYAN}${C_BOLD}====================================================================${C_RESET}\n"

    # Context info
    local server_url user_name current_project
    server_url=$(oc whoami --show-server 2>/dev/null || echo "Not Connected")
    user_name=$(oc whoami 2>/dev/null || echo "Unknown")
    current_project=$(oc project -q 2>/dev/null || echo "None")

    printf "  ${C_BOLD}Cluster API:${C_RESET}     %s\n" "$server_url"
    printf "  ${C_BOLD}User Context:${C_RESET}    %s\n" "$user_name"
    printf "  ${C_BOLD}Current Project:${C_RESET} %s\n" "$current_project"
    printf "${C_CYAN}--------------------------------------------------------------------${C_RESET}\n"

    if [ "$server_url" = "Not Connected" ]; then
        log_error "Not authenticated to any OpenShift cluster. Please run ./oc-login.sh first."
        exit 1
    fi

    # 1. Cluster Version & Upgrade Status
    log_info "1. Cluster Version Status:"
    oc get clusterversion --no-headers | awk '{printf "   Version: %s | Status: %s\n", $2, $3}' || log_warn "Unable to fetch clusterversion"

    # 2. Cluster Operators Status
    echo ""
    log_info "2. Checking Cluster Operators (CO)..."
    local degraded_cos
    degraded_cos=$(oc get co --no-headers | awk '$3 != "True" || $4 == "True" || $5 == "True" {print $1, "Available=" $3, "Progressing=" $4, "Degraded=" $5}' || true)
    
    if [ -z "$degraded_cos" ]; then
        log_success "All Cluster Operators are HEALTHY (Available=True, Progressing=False, Degraded=False)"
    else
        log_error "Unhealthy / Degraded Cluster Operators Detected:"
        echo "$degraded_cos" | while read -r line; do
            printf "   ${C_RED}✖ ${line}${C_RESET}\n"
        done
    fi

    # 3. Node Status
    echo ""
    log_info "3. Checking Node Status..."
    local unready_nodes
    unready_nodes=$(oc get nodes --no-headers | awk '$2 !~ /Ready/ || $2 ~ /NotReady/ {print $1, $2, $3}' || true)
    
    local total_nodes master_nodes worker_nodes
    total_nodes=$(oc get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
    master_nodes=$(oc get nodes -l node-role.kubernetes.io/master --no-headers 2>/dev/null | wc -l | tr -d ' ')
    worker_nodes=$(oc get nodes -l node-role.kubernetes.io/worker --no-headers 2>/dev/null | wc -l | tr -d ' ')

    printf "   Total Nodes: %s (Masters: %s, Workers: %s)\n" "$total_nodes" "$master_nodes" "$worker_nodes"
    
    if [ -z "$unready_nodes" ]; then
        log_success "All Nodes are in Ready state."
    else
        log_error "Nodes with Non-Ready status:"
        echo "$unready_nodes" | while read -r line; do
            printf "   ${C_RED}✖ ${line}${C_RESET}\n"
        done
    fi

    # 4. Machine Config Pools (MCP)
    echo ""
    log_info "4. Checking Machine Config Pools (MCP)..."
    local degraded_mcps
    degraded_mcps=$(oc get mcp --no-headers | awk '$3 == "True" || $4 == "True" || $5 == "True" {print $1, "Updated=" $3, "Updating=" $4, "Degraded=" $5}' || true)
    oc get mcp 2>/dev/null || log_warn "Could not read machine config pools (requires cluster-admin)."

    # 5. Non-Running Pods in Critical Core Namespaces
    echo ""
    log_info "5. Checking Core Infrastructure Pods (openshift-*)..."
    local bad_infra_pods
    bad_infra_pods=$(oc get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null | grep -E '^openshift-' | head -n 15 || true)
    
    if [ -z "$bad_infra_pods" ]; then
        log_success "No failing pods in core 'openshift-*' namespaces."
    else
        log_warn "Detected failing infrastructure pods:"
        echo "$bad_infra_pods" | while read -r line; do
            printf "   ${C_YELLOW}⚠ %s${C_RESET}\n" "$line"
        done
    fi

    # 6. Critical Warning Events
    echo ""
    log_info "6. Recent Warning Events (Last 10 Cluster Warnings)..."
    oc get events -A --field-selector type=Warning --sort-by='.lastTimestamp' 2>/dev/null | tail -n 10 || log_info "No warning events found."

    echo ""
    printf "${C_CYAN}====================================================================${C_RESET}\n"
    log_success "Health check complete. Use specific ocp-* skills for deeper diagnostics."
}

check_cluster_health "$@"

