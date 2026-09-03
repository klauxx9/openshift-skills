#!/usr/bin/env bash
# ==============================================================================
# OpenShift Multi-Cluster Resource & CRD Extractor (YAML to chat-artifacts/)
# ==============================================================================
# Extracts resources / CRDs in YAML format across single or multiple clusters.
# Output naming format: chat-artifacts/<resource-name>-<cluster-name>.yaml
#
# Usage:
#   ./export_resources.sh <cluster_id> <resource_type> [resource_name] [-n namespace]
#   ./export_resources.sh --env <env> <resource_type> [resource_name] [-n namespace]
#
# Examples:
#   ./export_resources.sh --env dev clusterlogforwarder
#   ./export_resources.sh --env prod ingresscontroller default -n openshift-ingress-operator
#   ./export_resources.sh ocp-dev-01 crd lokistacks.loki.grafana.com
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
CONFIG_DIR="${BASE_DIR}/.gemini/config"
LOGIN_SCRIPT="${BASE_DIR}/.gemini/scripts/oc-login.sh"
PARSER_SCRIPT="${BASE_DIR}/.gemini/scripts/parse_inventory.sh"
CHAT_ARTIFACTS_DIR="${BASE_DIR}/chat-artifacts"

source "${BASE_DIR}/.gemini/scripts/utils.sh"

check_oc_installed

mkdir -p "$CHAT_ARTIFACTS_DIR"

if [ "$#" -lt 2 ]; then
    log_error "Insufficient arguments."
    echo "Usage: $0 [--env <dev|staging|uat|prod|all> | <cluster_id>] <resource_type> [resource_name] [-n <namespace>]"
    exit 1
fi

TARGET_MODE="cluster"
TARGET_VAL="$1"
shift

if [ "$TARGET_VAL" = "--env" ] || [ "$TARGET_VAL" = "-e" ]; then
    TARGET_MODE="env"
    TARGET_VAL="$1"
    shift
fi

# Parse remaining arguments
RESOURCE_TYPE="$1"
shift

RESOURCE_NAME=""
NAMESPACE=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        *)
            if [ -z "$RESOURCE_NAME" ]; then
                RESOURCE_NAME="$1"
            fi
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

echo ""
printf "${C_CYAN}${C_BOLD}====================================================================================================${C_RESET}\n"
printf "${C_CYAN}${C_BOLD}                OPENSHIFT RESOURCE & CRD EXTRACTOR (YAML EXPORT)                                    ${C_RESET}\n"
printf "${C_CYAN}${C_BOLD}====================================================================================================${C_RESET}\n"
log_info "Target Clusters: ${C_BOLD}${CLUSTERS[*]}${C_RESET}"
log_info "Resource Type:   ${C_BOLD}${RESOURCE_TYPE}${C_RESET}"
[ -n "$RESOURCE_NAME" ] && log_info "Resource Name:   ${C_BOLD}${RESOURCE_NAME}${C_RESET}"
[ -n "$NAMESPACE" ] && log_info "Namespace:       ${C_BOLD}${NAMESPACE}${C_RESET}"
printf "${C_CYAN}----------------------------------------------------------------------------------------------------${C_RESET}\n"

declare -a EXPORT_RESULTS=()

NS_ARG=""
if [ -n "$NAMESPACE" ]; then
    NS_ARG="-n ${NAMESPACE}"
fi

for cluster_id in "${CLUSTERS[@]}"; do
    echo ""
    log_info "Connecting to Cluster: ${C_BOLD}${cluster_id}${C_RESET}..."
    
    # 1. Login
    if ! "$LOGIN_SCRIPT" "$cluster_id" >/dev/null 2>&1; then
        log_error "Failed to authenticate to ${cluster_id}. Skipping."
        EXPORT_RESULTS+=("${cluster_id}|${RESOURCE_TYPE}|N/A|AUTH_FAILED|${C_RED}FAILED${C_RESET}")
        continue
    fi

    # 2. Determine resources to export
    TARGET_NAMES=()
    if [ -n "$RESOURCE_NAME" ]; then
        TARGET_NAMES+=("$RESOURCE_NAME")
    else
        # Discover all items of this resource type in namespace or cluster-wide
        # shellcheck disable=SC2086
        DISCOVERED=$(oc get "$RESOURCE_TYPE" $NS_ARG -o jsonpath='{range .items[*]}{.metadata.name}{" "}{end}' 2>/dev/null || true)
        
        # If resource is a single object without .items (or CRD)
        if [ -z "$DISCOVERED" ]; then
            # Check if direct get works (single instance)
            # shellcheck disable=SC2086
            if oc get "$RESOURCE_TYPE" $NS_ARG >/dev/null 2>&1; then
                # shellcheck disable=SC2086
                single_name=$(oc get "$RESOURCE_TYPE" $NS_ARG -o jsonpath='{.metadata.name}' 2>/dev/null || echo "")
                if [ -n "$single_name" ]; then
                    TARGET_NAMES+=("$single_name")
                fi
            fi
        else
            read -r -a TARGET_NAMES <<< "$DISCOVERED"
        fi
    fi

    if [ ${#TARGET_NAMES[@]} -eq 0 ]; then
        log_warn "No instances of '${RESOURCE_TYPE}' found in ${cluster_id}."
        EXPORT_RESULTS+=("${cluster_id}|${RESOURCE_TYPE}|<none>|NO_RESOURCE_FOUND|${C_YELLOW}NOT_FOUND${C_RESET}")
        continue
    fi

    # 3. Export each instance to chat-artifacts/<resource-name>-<cluster-name>.yaml
    for res_item in "${TARGET_NAMES[@]}"; do
        # Sanitize filename (clean slashes)
        clean_res_name=$(basename "$res_item")
        artifact_filename="${clean_res_name}-${cluster_id}.yaml"
        artifact_filepath="${CHAT_ARTIFACTS_DIR}/${artifact_filename}"

        # shellcheck disable=SC2086
        if oc get "$RESOURCE_TYPE" "$res_item" $NS_ARG -o yaml > "$artifact_filepath" 2>/dev/null; then
            file_size=$(ls -lh "$artifact_filepath" | awk '{print $5}' 2>/dev/null || echo "OK")
            log_success "Exported YAML: ${C_BOLD}chat-artifacts/${artifact_filename}${C_RESET} (${file_size})"
            EXPORT_RESULTS+=("${cluster_id}|${RESOURCE_TYPE}|${res_item}|chat-artifacts/${artifact_filename} (${file_size})|${C_GREEN}SUCCESS${C_RESET}")
        else
            log_error "Failed to export YAML for ${res_item} on ${cluster_id}."
            EXPORT_RESULTS+=("${cluster_id}|${RESOURCE_TYPE}|${res_item}|EXPORT_FAILED|${C_RED}FAILED${C_RESET}")
        fi
    done
done

echo ""
printf "${C_CYAN}${C_BOLD}====================================================================================================${C_RESET}\n"
printf "${C_CYAN}${C_BOLD}                     RESOURCE EXTRACTION SUMMARY REPORT                                             ${C_RESET}\n"
printf "${C_CYAN}${C_BOLD}====================================================================================================${C_RESET}\n"
printf "%-14s | %-24s | %-20s | %-32s | %s\n" "CLUSTER" "KIND" "RESOURCE NAME" "OUTPUT FILE" "RESULT"
printf "%s\n" "----------------------------------------------------------------------------------------------------"

for row in "${EXPORT_RESULTS[@]}"; do
    IFS='|' read -r r_id r_kind r_name r_file r_res <<< "$row"
    printf "%-14s | %-24s | %-20s | %-32s | %b\n" "$r_id" "$r_kind" "$r_name" "$r_file" "$r_res"
done

printf "${C_CYAN}====================================================================================================${C_RESET}\n"
log_success "Resource extraction complete! Manifests are stored in 'chat-artifacts/'."

