#!/usr/bin/env bash
# ==============================================================================
# OpenShift Skills Framework - Automated Test Suite Runner
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/.gemini/scripts/utils.sh"

echo ""
printf "${C_CYAN}${C_BOLD}====================================================================${C_RESET}\n"
printf "${C_CYAN}${C_BOLD}        RUNNING OPENSHIFT SKILLS AUTOMATED UNIT TESTS               ${C_RESET}\n"
printf "${C_CYAN}${C_BOLD}====================================================================${C_RESET}\n"

# Run unittest discovery
python3 -m unittest discover -s "${SCRIPT_DIR}/tests" -p "test_*.py" -v

echo ""
log_success "All unit tests completed successfully! Scaffolding is verified and healthy."

