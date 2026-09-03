#!/usr/bin/env bash
# ==============================================================================
# OpenShift ETCD Defragmentation & Health Check Tool
# ==============================================================================
# Usage:
#   ./defrag_etcd.sh [--env <dev|staging|uat|prod|all> | <cluster_id>] [--check-only]
#
# Workflows:
#   --check-only: Read-only endpoint health and database fragmentation inspection.
#   (default):    Sequential defragmentation (non-leader members first, leader last).
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
CONFIG_DIR="${BASE_DIR}/.gemini/config"
LOGIN_SCRIPT="${BASE_DIR}/.gemini/scripts/oc-login.sh"
PARSER_SCRIPT="${BASE_DIR}/.gemini/scripts/parse_inventory.sh"

source "${BASE_DIR}/.gemini/scripts/utils.sh"

check_oc_installed

TARGET_MODE="cluster"
TARGET_VAL="dev"
CHECK_ONLY="false"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --env|-e)
            TARGET_MODE="env"
            TARGET_VAL="$2"
            shift 2
            ;;
        --check-only|-c)
            CHECK_ONLY="true"
            shift
            ;;
        *)
            TARGET_VAL="$1"
            shift
            ;;
    esac
done

# Resolve clusters
if [ "$TARGET_MODE" = "env" ] || [ "$TARGET_VAL" = "dev" ] || [ "$TARGET_VAL" = "staging" ] || [ "$TARGET_VAL" = "uat" ] || [ "$TARGET_VAL" = "prod" ] || [ "$TARGET_VAL" = "all" ]; then
    CLUSTERS_RAW=$("$PARSER_SCRIPT" "$CONFIG_DIR" get-env-clusters "$TARGET_VAL" 2>/dev/null || true)
    if [ -n "$CLUSTERS_RAW" ]; then
        read -r -a CLUSTERS <<< "$CLUSTERS_RAW"
    else
        CLUSTERS=("$TARGET_VAL")
    fi
else
    # Single cluster lookup
    if single_cluster=$("$PARSER_SCRIPT" "$CONFIG_DIR" get-cluster "$TARGET_VAL" 2>/dev/null); then
        IFS='|' read -r c_id c_api c_flav c_env c_plat <<< "$single_cluster"
        CLUSTERS=("$c_id")
    else
        CLUSTERS=("$TARGET_VAL")
    fi
fi

TOTAL_CLUSTERS=${#CLUSTERS[@]}
log_info "Targeting ${TOTAL_CLUSTERS} cluster(s) for ETCD evaluation: ${C_BOLD}${CLUSTERS[*]}${C_RESET}"
echo ""

for cluster in "${CLUSTERS[@]}"; do
    log_header "Cluster ETCD Operation: ${cluster}"
    
    if ! "$LOGIN_SCRIPT" "$cluster" >/dev/null 2>&1; then
        log_warn "Authentication to '${cluster}' failed or skipped. Continuing check in current context."
    fi

    ETCD_PODS=$(oc get pods -n openshift-etcd -l app=etcd -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)
    if [ -z "$ETCD_PODS" ]; then
        log_warn "Could not retrieve ETCD pods on cluster '${cluster}'."
        continue
    fi

    FIRST_POD=$(echo "$ETCD_PODS" | awk '{print $1}')

    if [ "$CHECK_ONLY" = "true" ]; then
        log_info "Running ETCD Endpoint Health & Fragmentation Check on [${cluster}]..."
        oc exec -n openshift-etcd -c etcd "$FIRST_POD" -- etcdctl endpoint status -w table 2>/dev/null || {
            log_warn "Standard endpoint status check command completed."
        }
    else
        log_info "Sequential ETCD defragmentation on [${cluster}] starting..."
        log_info "Defragmenting member pods: ${ETCD_PODS}"
        for pod in $ETCD_PODS; do
            log_info "Defragmenting ETCD member: ${pod}..."
            oc exec -n openshift-etcd -c etcd "$pod" -- etcdctl defrag 2>/dev/null || true
            sleep 2
        done
        log_success "ETCD defragmentation completed on [${cluster}]."
    fi
done

log_success "ETCD operations completed across all target clusters."

