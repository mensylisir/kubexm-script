#!/usr/bin/env bash
# ==============================================================================
# Verification Script for Critical Pipeline Fixes
# ==============================================================================
# This script verifies that all critical fixes have been properly applied
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

PASS=0
FAIL=0
WARN=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_pass() {
  echo -e "${GREEN}✓ PASS${NC}: $1"
  ((PASS++))
}

check_fail() {
  echo -e "${RED}✗ FAIL${NC}: $1"
  ((FAIL++))
}

check_warn() {
  echo -e "${YELLOW}⚠ WARN${NC}: $1"
  ((WARN++))
}

echo "=========================================="
echo "Pipeline Fixes Verification"
echo "=========================================="
echo ""

# Fix 1: Check scale_cluster.sh exists and is sourced
echo "Fix 1: Scale Cluster Router"
echo "----------------------------"

if [[ -f "${PROJECT_ROOT}/internal/pipeline/cluster/scale_cluster.sh" ]]; then
  check_pass "scale_cluster.sh file exists"
else
  check_fail "scale_cluster.sh file missing"
fi

if grep -q "source.*scale_cluster.sh" "${PROJECT_ROOT}/bin/kubexm" 2>/dev/null; then
  check_pass "scale_cluster.sh is sourced in bin/kubexm"
else
  check_fail "scale_cluster.sh not sourced in bin/kubexm"
fi

if grep -q "pipeline::scale_cluster()" "${PROJECT_ROOT}/internal/pipeline/cluster/scale_cluster.sh" 2>/dev/null; then
  check_pass "pipeline::scale_cluster function defined"
else
  check_fail "pipeline::scale_cluster function not found"
fi

if grep -q "\-\-action=" "${PROJECT_ROOT}/bin/kubexm" 2>/dev/null; then
  check_pass "Help text updated with --action parameter"
else
  check_warn "Help text may need update for --action parameter"
fi

echo ""

# Fix 2: Check rollback framework enhancements
echo "Fix 2: Rollback Framework"
echo "-------------------------"

if grep -q "pipeline::register_module_rollback()" "${PROJECT_ROOT}/internal/utils/pipeline.sh" 2>/dev/null; then
  check_pass "register_module_rollback function added"
else
  check_fail "register_module_rollback function missing"
fi

if grep -q "export -f pipeline::register_module_rollback" "${PROJECT_ROOT}/internal/utils/pipeline.sh" 2>/dev/null; then
  check_pass "register_module_rollback exported"
else
  check_fail "register_module_rollback not exported"
fi

if grep -q "pipeline::register_rollback" "${PROJECT_ROOT}/internal/pipeline/cluster/upgrade_cluster.sh" 2>/dev/null; then
  check_pass "Rollback used in upgrade_cluster"
else
  check_warn "Rollback not yet used in upgrade_cluster"
fi

echo ""

# Fix 3: Check pre-operation backup
echo "Fix 3: Pre-Operation Backup"
echo "----------------------------"

if grep -q "pipeline::ensure_pre_operation_backup()" "${PROJECT_ROOT}/internal/utils/pipeline.sh" 2>/dev/null; then
  check_pass "ensure_pre_operation_backup function added"
else
  check_fail "ensure_pre_operation_backup function missing"
fi

if grep -q "export -f pipeline::ensure_pre_operation_backup" "${PROJECT_ROOT}/internal/utils/pipeline.sh" 2>/dev/null; then
  check_pass "ensure_pre_operation_backup exported"
else
  check_fail "ensure_pre_operation_backup not exported"
fi

if grep -q "pipeline::ensure_pre_operation_backup" "${PROJECT_ROOT}/internal/pipeline/cluster/upgrade_cluster.sh" 2>/dev/null; then
  check_pass "Backup used in upgrade_cluster"
else
  check_warn "Backup not yet used in upgrade_cluster"
fi

echo ""

# Fix 4: Check quorum validation
echo "Fix 4: Quorum Validation"
echo "------------------------"

if grep -q "pipeline::validate_quorum_before_removal()" "${PROJECT_ROOT}/internal/utils/pipeline.sh" 2>/dev/null; then
  check_pass "validate_quorum_before_removal function added"
else
  check_fail "validate_quorum_before_removal function missing"
fi

if grep -q "export -f pipeline::validate_quorum_before_removal" "${PROJECT_ROOT}/internal/utils/pipeline.sh" 2>/dev/null; then
  check_pass "validate_quorum_before_removal exported"
else
  check_fail "validate_quorum_before_removal not exported"
fi

if grep -q "pipeline::validate_quorum_before_removal" "${PROJECT_ROOT}/internal/pipeline/cluster/scalein_cluster.sh" 2>/dev/null; then
  check_pass "Quorum check used in scalein_cluster"
else
  check_warn "Quorum check not yet used in scalein_cluster"
fi

if grep -q "QUORUM VIOLATION" "${PROJECT_ROOT}/internal/utils/pipeline.sh" 2>/dev/null; then
  check_pass "Quorum violation error message present"
else
  check_fail "Quorum violation error message missing"
fi

echo ""

# Fix 5: Check post-operation validation
echo "Fix 5: Post-Operation Validation"
echo "---------------------------------"

if grep -q "pipeline::post_upgrade_validation()" "${PROJECT_ROOT}/internal/pipeline/cluster/upgrade_cluster.sh" 2>/dev/null; then
  check_pass "post_upgrade_validation function added to upgrade_cluster"
else
  check_fail "post_upgrade_validation function missing from upgrade_cluster"
fi

if grep -q "pipeline::post_etcd_upgrade_validation()" "${PROJECT_ROOT}/internal/pipeline/cluster/upgrade_etcd.sh" 2>/dev/null; then
  check_pass "post_etcd_upgrade_validation function added"
else
  check_fail "post_etcd_upgrade_validation function missing"
fi

if grep -q "PostUpgradeValidation" "${PROJECT_ROOT}/internal/pipeline/cluster/upgrade_cluster.sh" 2>/dev/null; then
  check_pass "Post-upgrade validation called in pipeline"
else
  check_fail "Post-upgrade validation not called in pipeline"
fi

echo ""

# Syntax checks
echo "Syntax Validation"
echo "-----------------"

for file in \
  "${PROJECT_ROOT}/internal/pipeline/cluster/scale_cluster.sh" \
  "${PROJECT_ROOT}/internal/utils/pipeline.sh" \
  "${PROJECT_ROOT}/internal/pipeline/cluster/upgrade_cluster.sh" \
  "${PROJECT_ROOT}/internal/pipeline/cluster/upgrade_etcd.sh" \
  "${PROJECT_ROOT}/internal/pipeline/cluster/scalein_cluster.sh" \
  "${PROJECT_ROOT}/bin/kubexm"; do

  if [[ -f "${file}" ]]; then
    if bash -n "${file}" 2>/dev/null; then
      check_pass "Syntax OK: $(basename ${file})"
    else
      check_fail "Syntax ERROR: $(basename ${file})"
    fi
  else
    check_fail "File not found: $(basename ${file})"
  fi
done

echo ""
echo "=========================================="
echo "Verification Summary"
echo "=========================================="
echo -e "${GREEN}Passed:   ${PASS}${NC}"
echo -e "${RED}Failed:   ${FAIL}${NC}"
echo -e "${YELLOW}Warnings: ${WARN}${NC}"
echo ""

if [[ ${FAIL} -eq 0 ]]; then
  echo -e "${GREEN}✓ All critical fixes verified successfully!${NC}"
  exit 0
else
  echo -e "${RED}✗ Some fixes failed verification. Please review.${NC}"
  exit 1
fi
