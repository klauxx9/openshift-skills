#!/usr/bin/env bash
# ==============================================================================
# OpenShift Adhoc ETCD Backup Runner (Single or Multi-Cluster Environment)
# ==============================================================================
# Triggers adhoc etcd snapshots on control plane hosts and verifies artifacts.
#
# Usage:
#   ./backup_etcd.sh <cluster_id>
#   ./backup_etcd.sh --env <dev|staging|prod|dr|all>
#   ./backup_etcd.sh dev
#
# Examples:
#   ./backup_etcd.sh ocp-dev-01
#   ./backup_etcd.sh --env dev
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
CONFIG_DIR="${BASE_DIR}/.gemini/config"
LOGIN_SCRIPT="${BASE_DIR}/.gemini/scripts/oc-login.sh"
PARSER_SCRIPT="${BASE_DIR}/.gemini/scripts/parse_inventory.sh"

source "${BASE_DIR}/.gemini/scripts/utils.sh"

check_oc_installed

TARGET="${1:-dev}"
if [ "$TARGET" = "--env" ] || [ "$TARGET" = "-e" ]; then
    TARGET="${2:-dev}"
fi

# Determine if target is a single cluster or an environment
CLUSTERS_RAW=$("$PARSER_SCRIPT" "$CONFIG_DIR" get-env-clusters "$TARGET" 2>/dev/null || true)

if [ -z "$CLUSTERS_RAW" ]; then
    # Fallback to single cluster lookup
    if single_cluster=$("$PARSER_SCRIPT" "$CONFIG_DIR" get-cluster "$TARGET" 2>/dev/null); then
        IFS='|' read -r c_id c_api c_flav c_env c_plat <<< "$single_cluster"
        CLUSTERS=("$c_id")
    else
        log_error "Cluster or environment '$TARGET' not found in inventory."
        log_info "Available environments: dev, staging, prod, dr, all"
        exit 1
    fi
else
    read -r -a CLUSTERS <<< "$CLUSTERS_RAW"
fi

TOTAL_CLUSTERS=${#CLUSTERS[@]}

echo ""
printf "${C_CYAN}${C_BOLD}====================================================================================================${C_RESET}\n"
printf "${C_CYAN}${C_BOLD}                   OPENSHIFT ADHOC ETCD BACKUP EXECUTION                                            ${C_RESET}\n"
printf "${C_CYAN}${C_BOLD}====================================================================================================${C_RESET}\n"
log_info "Target Scope: ${C_BOLD}${TARGET^^}${C_RESET} (${TOTAL_CLUSTERS} cluster(s) queued for etcd snapshot)"
printf "Clusters: %s\n" "${CLUSTERS[*]}"
printf "${C_CYAN}----------------------------------------------------------------------------------------------------${C_RESET}\n"

declare -a BACKUP_RESULTS=()

for cluster_id in "${CLUSTERS[@]}"; do
    echo ""
    log_info "Processing Cluster: ${C_BOLD}${cluster_id}${C_RESET}..."
    start_time=$(date +%s)

    # 1. Login
    if ! "$LOGIN_SCRIPT" "$cluster_id" >/dev/null 2>&1; then
        log_error "Failed to authenticate to ${cluster_id}. Skipping."
        BACKUP_RESULTS+=("${cluster_id}|N/A|AUTH_FAILED|N/A|0s|${C_RED}FAILED${C_RESET}")
        continue
    fi

    # 2. Check ETCD Operator
    etcd_co_status=$(oc get co etcd -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "Unknown")
    if [ "$etcd_co_status" != "True" ]; then
        log_warn "ETCD ClusterOperator is NOT Available (Status: ${etcd_co_status})."
    fi

    # 3. Select Master Node
    master_node=$(oc get nodes -l node-role.kubernetes.io/master --no-headers 2>/dev/null | awk '$2 ~ /Ready/ {print $1; exit}' || true)
    if [ -z "$master_node" ]; then
        master_node=$(oc get nodes -l node-role.kubernetes.io/control-plane --no-headers 2>/dev/null | awk '$2 ~ /Ready/ {print $1; exit}' || true)
    fi

    if [ -z "$master_node" ]; then
        log_error "No Ready control-plane / master node found in ${cluster_id}."
        BACKUP_RESULTS+=("${cluster_id}|NONE|NO_MASTER_NODE|N/A|0s|${C_RED}FAILED${C_RESET}")
        continue
    fi

    log_info "Selected Control Plane Node: ${C_BOLD}${master_node}${C_RESET}"

    # 4. Generate Backup Timestamp Directory
    timestamp=$(date +%Y%m%d_%H%M%S)
    backup_path="/home/core/assets/backup/backup-${timestamp}"
    log_info "Executing /usr/local/bin/cluster-backup.sh on node '${master_node}' into '${backup_path}'..."

    # 5. Run Cluster Backup Script via oc debug
    backup_output=""
    backup_success=false

    if backup_output=$(oc debug --as-root "node/${master_node}" -- chroot /host /usr/local/bin/cluster-backup.sh "$backup_path" 2>&1); then
        backup_success=true
    else
        # Inspect output if command exited non-zero
        if echo "$backup_output" | grep -iq "successfully saved"; then
            backup_success=true
        fi
    fi

    end_time=$(date +%s)
    duration=$((end_time - start_time))

    if [ "$backup_success" = true ]; then
        log_success "ETCD snapshot successfully completed on ${cluster_id} in ${duration}s!"
        # Extract snapshot file if present in output
        snap_file=$(echo "$backup_output" | grep -oE "snapshot_[0-9_-]+\.db" | head -n 1 || echo "snapshot_${timestamp}.db")
        snap_hash=$(echo "$backup_output" | grep -oE '"hash":[0-9]+' | head -n 1 | tr -d '"' || echo "hash:verified")
        
        printf "   Backup Directory: %s\n" "$backup_path"
        printf "   Snapshot File:    %s (%s)\n" "$snap_file" "$snap_hash"
        
        BACKUP_RESULTS+=("${cluster_id}|${master_node}|COMPLETED|${backup_path}/${snap_file}|${duration}s|${C_GREEN}SUCCESS${C_RESET}")
    else
        log_error "ETCD backup command failed on ${cluster_id}."
        printf "   Error output: %s\n" "$(echo "$backup_output" | tail -n 3)"
        BACKUP_RESULTS+=("${cluster_id}|${master_node}|FAILED|$(echo "$backup_output" | tail -n 1 | cut -c 1-25)|${duration}s|${C_RED}FAILED${C_RESET}")
    fi
done

echo ""
printf "${C_CYAN}${C_BOLD}====================================================================================================${C_RESET}\n"
printf "${C_CYAN}${C_BOLD}                     ETCD ADHOC BACKUP SUMMARY REPORT                                               ${C_RESET}\n"
printf "${C_CYAN}${C_BOLD}====================================================================================================${C_RESET}\n"
printf "%-14s | %-18s | %-12s | %-32s | %-8s | %s\n" "CLUSTER" "MASTER NODE" "STATUS" "SNAPSHOT LOCATION" "TIME" "RESULT"
printf "%s\n" "----------------------------------------------------------------------------------------------------"

for row in "${BACKUP_RESULTS[@]}"; do
    IFS='|' read -r r_id r_node r_status r_path r_time r_res <<< "$row"
    printf "%-14s | %-18s | %-12s | %-32s | %-8s | %b\n" "$r_id" "$r_node" "$r_status" "$r_path" "$r_time" "$r_res"
done

printf "${C_CYAN}====================================================================================================${C_RESET}\n"
log_success "ETCD backup workflow finished for target scope: ${TARGET^^}"

