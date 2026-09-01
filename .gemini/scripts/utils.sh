#!/usr/bin/env bash
# ==============================================================================
# OpenShift L1 Operations - Utility Helper Library
# ==============================================================================

set -euo pipefail

# ANSI Colors
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'
C_BOLD='\033[1m'

log_info() {
    printf "${C_CYAN}[INFO]${C_RESET} %s\n" "$*"
}

log_success() {
    printf "${C_GREEN}[SUCCESS]${C_RESET} %s\n" "$*"
}

log_warn() {
    printf "${C_YELLOW}[WARNING]${C_RESET} %s\n" "$*" >&2
}

log_error() {
    printf "${C_RED}[ERROR]${C_RESET} %s\n" "$*" >&2
}

log_mutation_alert() {
    printf "${C_RED}${C_BOLD}[MUTATION GUARDRAIL TRIGGERED]${C_RESET} %s\n" "$*" >&2
}

# ------------------------------------------------------------------------------
# Human-in-the-loop Mutation Guardrail
# ------------------------------------------------------------------------------
require_human_confirmation() {
    local action_desc="$1"
    local target_cluster="${2:-unknown}"
    local target_namespace="${3:-all}"
    local command_to_run="$4"

    echo ""
    printf "${C_RED}${C_BOLD}====================================================================${C_RESET}\n"
    printf "${C_RED}${C_BOLD} ⚠️  MUTATION APPROVAL REQUIRED (HUMAN-IN-THE-LOOP SAFETY POLICY)  ⚠️ ${C_RESET}\n"
    printf "${C_RED}${C_BOLD}====================================================================${C_RESET}\n"
    printf "  ${C_BOLD}Action:${C_RESET}        %s\n" "$action_desc"
    printf "  ${C_BOLD}Cluster:${C_RESET}       %s\n" "$target_cluster"
    printf "  ${C_BOLD}Namespace:${C_RESET}     %s\n" "$target_namespace"
    printf "  ${C_BOLD}Command:${C_RESET}       ${C_YELLOW}%s${C_RESET}\n" "$command_to_run"
    printf "${C_RED}${C_BOLD}--------------------------------------------------------------------${C_RESET}\n"
    printf "${C_YELLOW}Mutating operations are blocked by default. Do you want to proceed? [y/N]: ${C_RESET}"
    
    read -r response
    case "$response" in
        [yY][eE][sS]|[yY])
            log_info "Human operator approved execution. Proceeding..."
            return 0
            ;;
        *)
            log_warn "Execution cancelled by operator. No resources were modified."
            return 1
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Token Masking Output Filter
# ------------------------------------------------------------------------------
mask_secrets() {
    sed -E \
        -e 's/(token: *|--token=)(sha256~[A-Za-z0-9_-]{4})[A-Za-z0-9_-]+/\1\2****************/g' \
        -e 's/(password: *|--password=|-p )([^ ]{2})[^ ]+/\1\2********/g'
}

# ------------------------------------------------------------------------------
# Check oc CLI availability
# ------------------------------------------------------------------------------
check_oc_installed() {
    if ! command -v oc >/dev/null 2>&1; then
        log_error "The 'oc' (OpenShift CLI) client was not found in PATH."
        log_info "Please install the OpenShift CLI: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/"
        return 1
    fi
    return 0
}

