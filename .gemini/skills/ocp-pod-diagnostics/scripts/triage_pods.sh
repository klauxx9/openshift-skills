#!/usr/bin/env bash
# ==============================================================================
# OpenShift L1 Pod Triage Tool (READ-ONLY)
# ==============================================================================
# Usage:
#   ./triage_pods.sh <namespace> [pod-name]
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
source "${BASE_DIR}/.gemini/scripts/utils.sh"

check_oc_installed

NAMESPACE="${1:-}"
POD_NAME="${2:-}"

if [ -z "$NAMESPACE" ]; then
    log_info "No namespace provided. Scanning for failing pods across all namespaces..."
    echo ""
    printf "%-35s | %-45s | %-15s | %s\n" "NAMESPACE" "POD NAME" "STATUS" "RESTARTS"
    printf "%s\n" "-----------------------------------------------------------------------------------------------------------------------"
    oc get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null | \
        awk '{printf "%-35s | %-45s | %-15s | %s\n", $1, $2, $4, $5}' || true
    echo ""
    log_info "To triage a specific namespace: ./triage_pods.sh <namespace>"
    exit 0
fi

log_info "Triaging namespace: ${C_BOLD}${NAMESPACE}${C_RESET}..."

if [ -z "$POD_NAME" ]; then
    log_info "Pods in namespace '${NAMESPACE}':"
    oc get pods -n "$NAMESPACE" -o wide
    echo ""
    
    # Check for restarting or non-running pods
    bad_pods=$(oc get pods -n "$NAMESPACE" --no-headers 2>/dev/null | awk '$3 != "Running" && $3 != "Completed" {print $1}')
    if [ -n "$bad_pods" ]; then
        log_warn "Detected troubled pods in ${NAMESPACE}:"
        echo "$bad_pods" | while read -r p; do
            printf " -> Inspecting pod: %s\n" "$p"
            oc describe pod "$p" -n "$NAMESPACE" | grep -E 'State:|Reason:|Exit Code:|Last State:|Message:|Events:' -A 5 || true
            echo "---"
        done
    else
        log_success "All pods in namespace '${NAMESPACE}' are in Running/Completed state."
    fi
    exit 0
fi

# Triage single specific pod
log_info "Detailed triage for Pod: ${C_BOLD}${POD_NAME}${C_RESET} in ${C_BOLD}${NAMESPACE}${C_RESET}"
echo ""

# 1. Pod Describe Summary
log_info "1. Pod Status & Conditions:"
oc get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{range .status.conditions[*]}{.type}{"="}{.status}{" (Reason: "}{.reason}{")\n"}{end}'
echo ""

# 2. Container States
log_info "2. Container Exit States:"
oc get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{range .status.containerStatuses[*]}{"Container: "}{.name}{"\n  Ready: "}{.ready}{"\n  Restarts: "}{.restartCount}{"\n  State: "}{.state}{"\n  LastState: "}{.lastState}{"\n\n"}{end}'

# 3. Pod Events
log_info "3. Recent Pod Events:"
oc describe pod "$POD_NAME" -n "$NAMESPACE" | awk '/Events:/{flag=1; next} flag' || true

# 4. Previous Logs
echo ""
log_info "4. Extracting Previous Crash Logs (Last 50 lines):"
for container in $(oc get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.containers[*].name}'); do
    printf "--- Container: %s (Previous Logs) ---\n" "$container"
    oc logs "$POD_NAME" -n "$NAMESPACE" -c "$container" --previous --tail=50 2>&1 || log_warn "No previous logs available for container $container."
done

