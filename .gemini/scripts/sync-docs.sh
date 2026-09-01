#!/usr/bin/env bash
# ==============================================================================
# OpenShift 4.16 & Ecosystem Documentation Synchronizer
# ==============================================================================
# Clones or updates official upstream Red Hat OpenShift 4.16 documentation
# and related ecosystem components into the local 'doc/' directory.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DOC_DIR="${BASE_DIR}/doc"

source "${SCRIPT_DIR}/utils.sh"

OCP_BRANCH="enterprise-4.16"
RHACM_BRANCH="2.11_stage"

mkdir -p "$DOC_DIR"

sync_repo() {
    local name="$1"
    local repo_url="$2"
    local branch="$3"
    local target_dir="${DOC_DIR}/${name}"

    log_info "Synchronizing ${C_BOLD}${name}${C_RESET} (branch: ${branch})..."

    if [ -d "${target_dir}/.git" ]; then
        log_info "Repository exists. Fetching latest updates..."
        git -C "$target_dir" fetch --depth 1 origin "$branch"
        git -C "$target_dir" reset --hard "origin/${branch}"
        log_success "Updated ${name} to latest commit on ${branch}."
    else
        log_info "Cloning ${repo_url}..."
        git clone --depth 1 --branch "$branch" "$repo_url" "$target_dir"
        log_success "Successfully cloned ${name} (${branch})."
    fi
}

echo ""
printf "${C_CYAN}${C_BOLD}====================================================================${C_RESET}\n"
printf "${C_CYAN}${C_BOLD}      RED HAT OPENSHIFT 4.16 DOCUMENTATION SYNCHRONIZER             ${C_RESET}\n"
printf "${C_CYAN}${C_BOLD}====================================================================${C_RESET}\n"

# 1. OpenShift 4.16 Core Documentation (Includes Loki, Vector, NetObserv, ODF, Serverless, Service Mesh, Virt)
sync_repo "openshift-docs" "https://github.com/openshift/openshift-docs.git" "$OCP_BRANCH"

# 2. Red Hat Advanced Cluster Management (RHACM 2.11 for OCP 4.16)
sync_repo "rhacm-docs" "https://github.com/stolostron/rhacm-docs.git" "$RHACM_BRANCH"

echo ""
log_success "Documentation synchronization complete! Context is available under ${DOC_DIR}/"

