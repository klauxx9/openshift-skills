#!/usr/bin/env bash
# ==============================================================================
# OpenShift Cluster Login Helper for L1 Operations
# ==============================================================================
# Usage:
#   ./oc-login.sh <cluster_alias_or_environment> [options]
#
# Examples:
#   ./oc-login.sh ocp-dev-01
#   ./oc-login.sh ocp-prd-01
#   ./oc-login.sh --list
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_DIR="${BASE_DIR}/.gemini/config"
PARSER_SCRIPT="${SCRIPT_DIR}/parse_inventory.sh"

source "${SCRIPT_DIR}/utils.sh"

list_available_clusters() {
    printf "${C_BOLD}Available OpenShift Clusters by Environment:${C_RESET}\n"
    "$PARSER_SCRIPT" "${CONFIG_DIR}" list
}

lookup_cluster_info() {
    local target="$1"
    "$PARSER_SCRIPT" "${CONFIG_DIR}" get-cluster "$target"
}

lookup_credentials() {
    local cluster_id="$1"
    "$PARSER_SCRIPT" "${CONFIG_DIR}" get-credentials "$cluster_id"
}

main() {
    if [ "$#" -eq 0 ] || [ "$1" = "--list" ] || [ "$1" = "-l" ]; then
        list_available_clusters
        echo ""
        log_info "To login to a cluster: ./oc-login.sh <cluster-id>"
        exit 0
    fi

    check_oc_installed

    local target_cluster="$1"
    log_info "Resolving cluster metadata for: ${C_BOLD}${target_cluster}${C_RESET}..."

    if ! cluster_info=$(lookup_cluster_info "$target_cluster"); then
        log_error "Cluster or environment '$target_cluster' not found in inventory."
        log_info "Run './oc-login.sh --list' to view available clusters."
        exit 1
    fi

    IFS='|' read -r c_id c_api c_auth c_env <<< "$cluster_info"
    log_info "Target Cluster: ${C_BOLD}${c_id}${C_RESET} (${c_env^^})"
    log_info "API Endpoint:   ${c_api}"

    # Lookup credentials
    IFS='|' read -r cred_type cred_user cred_pass cred_tok cred_insecure <<< "$(lookup_credentials "$c_id")"

    local extra_args=""
    if [ "$cred_insecure" = "True" ] || [ "$cred_insecure" = "true" ]; then
        extra_args="--insecure-skip-tls-verify=true"
    fi

    if [ "$cred_type" = "token" ] && [ -n "$cred_tok" ] && [[ "$cred_tok" != *"PLACEHOLDER"* ]]; then
        log_info "Authenticating using ServiceAccount / API Bearer Token..."
        oc login "$c_api" --token="$cred_tok" $extra_args >/dev/null 2>&1 || {
            log_error "Authentication failed with token. Please check credentials.local.yaml."
            exit 1
        }
    elif [ "$cred_type" = "password" ] && [ -n "$cred_user" ] && [ -n "$cred_pass" ] && [[ "$cred_pass" != *"CHANGE_ME"* ]]; then
        log_info "Authenticating as user: ${C_BOLD}${cred_user}${C_RESET}..."
        oc login "$c_api" -u "$cred_user" -p "$cred_pass" $extra_args >/dev/null 2>&1 || {
            log_error "Authentication failed for user '$cred_user'. Please check credentials."
            exit 1
        }
    else
        log_warn "No pre-configured credentials found in credentials.local.yaml. Launching interactive login:"
        oc login "$c_api" $extra_args
    fi

    log_success "Successfully authenticated to ${c_id}!"
    echo ""
    printf "${C_BOLD}Active Session Context:${C_RESET}\n"
    printf "  Server:   %s\n" "$(oc whoami --show-server 2>/dev/null || echo 'Unknown')"
    printf "  User:     %s\n" "$(oc whoami 2>/dev/null || echo 'Unknown')"
    printf "  Project:  %s\n" "$(oc project -q 2>/dev/null || echo 'default')"
}

main "$@"
