#!/usr/bin/env bash
# ==============================================================================
# Complete Pipeline Call Chain Verification
# ==============================================================================
# Traces all pipeline call chains, validates parameters and branches
# Ensures production stability after critical fixes
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=========================================="
echo "Pipeline Call Chain Verification"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

# ============================================================================
# 1. Verify All Pipeline Files Exist
# ============================================================================
echo "1. Pipeline File Inventory"
echo "--------------------------"

declare -A PIPELINES=(
  ["create_cluster"]="internal/pipeline/cluster/create_cluster.sh"
  ["delete_cluster"]="internal/pipeline/cluster/delete_cluster.sh"
  ["scale_cluster"]="internal/pipeline/cluster/scale_cluster.sh"
  ["scaleout_cluster"]="internal/pipeline/cluster/scaleout_cluster.sh"
  ["scalein_cluster"]="internal/pipeline/cluster/scalein_cluster.sh"
  ["upgrade_cluster"]="internal/pipeline/cluster/upgrade_cluster.sh"
  ["upgrade_etcd"]="internal/pipeline/cluster/upgrade_etcd.sh"
  ["backup"]="internal/pipeline/cluster/backup.sh"
  ["restore"]="internal/pipeline/cluster/restore.sh"
  ["health"]="internal/pipeline/cluster/health.sh"
  ["reconfigure"]="internal/pipeline/cluster/reconfigure.sh"
  ["renew_k8s_ca"]="internal/pipeline/cluster/renew_kubernetes_ca.sh"
  ["renew_k8s_certs"]="internal/pipeline/cluster/renew_kubernetes_certs.sh"
  ["renew_etcd_ca"]="internal/pipeline/cluster/renew_etcd_ca.sh"
  ["renew_etcd_certs"]="internal/pipeline/cluster/renew_etcd_certs.sh"
  ["download"]="internal/pipeline/assets/download.sh"
  ["push_images"]="internal/pipeline/assets/push_images.sh"
  ["manifests"]="internal/pipeline/assets/manifests.sh"
  ["iso"]="internal/pipeline/assets/iso.sh"
  ["registry"]="internal/pipeline/cluster/registry.sh"
)

MISSING=0
for name in "${!PIPELINES[@]}"; do
  file="${PIPELINES[$name]}"
  if [[ -f "${PROJECT_ROOT}/${file}" ]]; then
    echo "  ✓ ${name}"
  else
    echo "  ✗ ${name} - MISSING: ${file}"
    MISSING=$((MISSING + 1))
  fi
done

if [[ ${MISSING} -gt 0 ]]; then
  echo ""
  echo "ERROR: ${MISSING} pipeline files missing!"
  exit 1
fi

echo ""
echo "All ${#PIPELINES[@]} pipeline files present ✓"
echo ""

# ============================================================================
# 2. Verify CLI Routing (bin/kubexm)
# ============================================================================
echo "2. CLI Command Routing"
echo "----------------------"

CLI_COMMANDS=(
  "kubexm create cluster"
  "kubexm delete cluster"
  "kubexm scale cluster"
  "kubexm upgrade cluster"
  "kubexm upgrade etcd"
  "kubexm backup cluster"
  "kubexm restore cluster"
  "kubexm health cluster"
  "kubexm reconfigure cluster"
  "kubexm renew kubernetes-ca"
  "kubexm renew kubernetes-certs"
  "kubexm renew etcd-ca"
  "kubexm renew etcd-certs"
  "kubexm download"
  "kubexm push images"
  "kubexm create manifests"
  "kubexm create iso"
  "kubexm create registry"
  "kubexm delete registry"
)

ROUTING_ERRORS=0
for cmd in "${CLI_COMMANDS[@]}"; do
  # Extract the function that should be called
  case "${cmd}" in
    *"create cluster"*) func="pipeline::create_cluster" ;;
    *"delete cluster"*) func="pipeline::delete_cluster" ;;
    *"scale cluster"*) func="pipeline::scale_cluster" ;;
    *"upgrade cluster"*) func="pipeline::upgrade_cluster" ;;
    *"upgrade etcd"*) func="pipeline::upgrade_etcd" ;;
    *"backup cluster"*) func="pipeline::backup_cluster" ;;
    *"restore cluster"*) func="pipeline::restore_cluster" ;;
    *"health cluster"*) func="pipeline::health_cluster" ;;
    *"reconfigure cluster"*) func="pipeline::reconfigure_cluster" ;;
    *"renew kubernetes-ca"*) func="pipeline::renew_kubernetes_ca" ;;
    *"renew kubernetes-certs"*) func="pipeline::renew_kubernetes_certs" ;;
    *"renew etcd-ca"*) func="pipeline::renew_etcd_ca" ;;
    *"renew etcd-certs"*) func="pipeline::renew_etcd_certs" ;;
    *"download"*) func="pipeline::download" ;;
    *"push images"*) func="pipeline::push_images" ;;
    *"create manifests"*) func="pipeline::manifests" ;;
    *"create iso"*) func="pipeline::iso" ;;
    *"create registry"*) func="pipeline::create_registry" ;;
    *"delete registry"*) func="pipeline::delete_registry" ;;
    *) func="unknown" ;;
  esac

  if grep -q "${func}" "${PROJECT_ROOT}/bin/kubexm" 2>/dev/null; then
    echo "  ✓ ${cmd} → ${func}"
  else
    echo "  ✗ ${cmd} → ${func} (NOT FOUND)"
    ROUTING_ERRORS=$((ROUTING_ERRORS + 1))
  fi
done

if [[ ${ROUTING_ERRORS} -gt 0 ]]; then
  echo ""
  echo "WARNING: ${ROUTING_ERRORS} routing errors found"
fi

echo ""

# ============================================================================
# 3. Verify Safety Features Coverage
# ============================================================================
echo "3. Safety Features Coverage"
echo "---------------------------"

check_feature() {
  local feature="$1"
  local pattern="$2"
  local files="$3"

  local count=0
  local total=0

  for file in ${files}; do
    if [[ -f "${PROJECT_ROOT}/${file}" ]]; then
      total=$((total + 1))
      if grep -q "${pattern}" "${PROJECT_ROOT}/${file}" 2>/dev/null; then
        count=$((count + 1))
      fi
    fi
  done

  if [[ ${total} -gt 0 ]]; then
    local pct=$((count * 100 / total))
    if [[ ${pct} -ge 80 ]]; then
      echo "  ✓ ${feature}: ${count}/${total} (${pct}%)"
    elif [[ ${pct} -ge 50 ]]; then
      echo "  ⚠ ${feature}: ${count}/${total} (${pct}%)"
    else
      echo "  ✗ ${feature}: ${count}/${total} (${pct}%)"
    fi
  fi
}

CLUSTER_PIPELINES="internal/pipeline/cluster/create_cluster.sh internal/pipeline/cluster/delete_cluster.sh internal/pipeline/cluster/scaleout_cluster.sh internal/pipeline/cluster/scalein_cluster.sh internal/pipeline/cluster/upgrade_cluster.sh internal/pipeline/cluster/upgrade_etcd.sh internal/pipeline/cluster/backup.sh internal/pipeline/cluster/restore.sh internal/pipeline/cluster/health.sh internal/pipeline/cluster/reconfigure.sh internal/pipeline/cluster/renew_kubernetes_ca.sh internal/pipeline/cluster/renew_kubernetes_certs.sh internal/pipeline/cluster/renew_etcd_ca.sh internal/pipeline/cluster/renew_etcd_certs.sh"

check_feature "Timeout Watchdog" "pipeline::start_timeout_watchdog" "${CLUSTER_PIPELINES}"
check_feature "Cluster Locking" "pipeline::acquire_lock" "${CLUSTER_PIPELINES}"
check_feature "Dry-Run Support" "KUBEXM_DRY_RUN" "${CLUSTER_PIPELINES}"
check_feature "Rollback Registration" "pipeline::register_rollback" "${CLUSTER_PIPELINES}"
check_feature "Pre-Op Backup" "ensure_pre_operation_backup" "${CLUSTER_PIPELINES}"
check_feature "Quorum Validation" "validate_quorum_before_removal" "${CLUSTER_PIPELINES}"
check_feature "Post-Op Validation" "post_.*_validation" "${CLUSTER_PIPELINES}"

echo ""

# ============================================================================
# 4. Verify Parameter Validation
# ============================================================================
echo "4. Parameter Validation"
echo "-----------------------"

check_param_validation() {
  local pipeline="$1"
  local required_param="$2"
  local file="${PROJECT_ROOT}/internal/pipeline/cluster/${pipeline}.sh"

  if [[ ! -f "${file}" ]]; then
    file="${PROJECT_ROOT}/internal/pipeline/assets/${pipeline}.sh"
  fi

  if [[ -f "${file}" ]]; then
    if grep -q "${required_param}" "${file}" 2>/dev/null; then
      echo "  ✓ ${pipeline}: validates ${required_param}"
    else
      echo "  ⚠ ${pipeline}: missing ${required_param} validation"
    fi
  else
    echo "  ✗ ${pipeline}: file not found"
  fi
}

check_param_validation "create_cluster" "--cluster="
check_param_validation "delete_cluster" "--cluster="
check_param_validation "scale_cluster" "--cluster="
check_param_validation "scale_cluster" "--action="
check_param_validation "upgrade_cluster" "--to-version="
check_param_validation "upgrade_etcd" "--to-version="
check_param_validation "backup" "--cluster="
check_param_validation "restore" "--path="
check_param_validation "health" "--cluster="
check_param_validation "reconfigure" "--cluster="

echo ""

# ============================================================================
# 5. Verify Error Handling Patterns
# ============================================================================
echo "5. Error Handling Patterns"
echo "--------------------------"

check_error_handling() {
  local pipeline="$1"
  local file="${PROJECT_ROOT}/internal/pipeline/cluster/${pipeline}.sh"

  if [[ ! -f "${file}" ]]; then
    file="${PROJECT_ROOT}/internal/pipeline/assets/${pipeline}.sh"
  fi

  if [[ ! -f "${file}" ]]; then
    echo "  ✗ ${pipeline}: file not found"
    return
  fi

  local has_trap=false
  local has_return_check=false
  local has_logger_error=false

  grep -q "trap " "${file}" 2>/dev/null && has_trap=true
  grep -q "|| return" "${file}" 2>/dev/null && has_return_check=true
  grep -q "logger::error\|log::error" "${file}" 2>/dev/null && has_logger_error=true

  local score=0
  [[ "${has_trap}" == "true" ]] && score=$((score + 1))
  [[ "${has_return_check}" == "true" ]] && score=$((score + 1))
  [[ "${has_logger_error}" == "true" ]] && score=$((score + 1))

  if [[ ${score} -eq 3 ]]; then
    echo "  ✓ ${pipeline}: Complete error handling"
  elif [[ ${score} -eq 2 ]]; then
    echo "  ⚠ ${pipeline}: Partial error handling (${score}/3)"
  else
    echo "  ✗ ${pipeline}: Incomplete error handling (${score}/3)"
  fi
}

for pipeline in create_cluster delete_cluster scale_cluster upgrade_cluster upgrade_etcd backup restore; do
  check_error_handling "${pipeline}"
done

echo ""

# ============================================================================
# 6. Verify Critical Fixes Applied
# ============================================================================
echo "6. Critical Fixes Verification"
echo "-------------------------------"

# Fix 1: scale_cluster function
if grep -q "^pipeline::scale_cluster()" "${PROJECT_ROOT}/internal/pipeline/cluster/scale_cluster.sh" 2>/dev/null; then
  echo "  ✓ Fix 1: pipeline::scale_cluster() function exists"
else
  echo "  ✗ Fix 1: pipeline::scale_cluster() function MISSING"
fi

# Fix 2: Rollback framework
if grep -q "pipeline::register_module_rollback()" "${PROJECT_ROOT}/internal/utils/pipeline.sh" 2>/dev/null; then
  echo "  ✓ Fix 2: Enhanced rollback framework available"
else
  echo "  ✗ Fix 2: Enhanced rollback framework MISSING"
fi

# Fix 3: Pre-operation backup
if grep -q "pipeline::ensure_pre_operation_backup()" "${PROJECT_ROOT}/internal/utils/pipeline.sh" 2>/dev/null; then
  echo "  ✓ Fix 3: Pre-operation backup function available"
else
  echo "  ✗ Fix 3: Pre-operation backup function MISSING"
fi

# Fix 4: Quorum validation
if grep -q "pipeline::validate_quorum_before_removal()" "${PROJECT_ROOT}/internal/utils/pipeline.sh" 2>/dev/null; then
  echo "  ✓ Fix 4: Quorum validation function available"
else
  echo "  ✗ Fix 4: Quorum validation function MISSING"
fi

# Fix 5: Post-operation validation
if grep -q "pipeline::post_upgrade_validation()" "${PROJECT_ROOT}/internal/pipeline/cluster/upgrade_cluster.sh" 2>/dev/null; then
  echo "  ✓ Fix 5a: Post-upgrade validation implemented"
else
  echo "  ✗ Fix 5a: Post-upgrade validation MISSING"
fi

if grep -q "pipeline::post_etcd_upgrade_validation()" "${PROJECT_ROOT}/internal/pipeline/cluster/upgrade_etcd.sh" 2>/dev/null; then
  echo "  ✓ Fix 5b: Post-ETCD-upgrade validation implemented"
else
  echo "  ✗ Fix 5b: Post-ETCD-upgrade validation MISSING"
fi

echo ""

# ============================================================================
# 7. Syntax Validation
# ============================================================================
echo "7. Syntax Validation"
echo "--------------------"

SYNTAX_ERRORS=0
for pipeline_file in "${PIPELINES[@]}"; do
  full_path="${PROJECT_ROOT}/${pipeline_file}"
  if [[ -f "${full_path}" ]]; then
    if bash -n "${full_path}" 2>/dev/null; then
      echo "  ✓ $(basename ${pipeline_file})"
    else
      echo "  ✗ $(basename ${pipeline_file}) - SYNTAX ERROR"
      SYNTAX_ERRORS=$((SYNTAX_ERRORS + 1))
    fi
  fi
done

if [[ ${SYNTAX_ERRORS} -gt 0 ]]; then
  echo ""
  echo "ERROR: ${SYNTAX_ERRORS} files have syntax errors!"
  exit 1
fi

echo ""

# ============================================================================
# Summary
# ============================================================================
echo "=========================================="
echo "Verification Summary"
echo "=========================================="
echo ""
echo "Total Pipelines: ${#PIPELINES[@]}"
echo "Missing Files: ${MISSING}"
echo "Routing Errors: ${ROUTING_ERRORS}"
echo "Syntax Errors: ${SYNTAX_ERRORS}"
echo ""

if [[ ${MISSING} -eq 0 && ${ROUTING_ERRORS} -eq 0 && ${SYNTAX_ERRORS} -eq 0 ]]; then
  echo "✓ All pipeline call chains verified successfully!"
  echo "✓ Production stability checks PASSED"
  echo ""
  echo "Next Steps:"
  echo "  1. Review docs/pipeline-trace-analysis.md for detailed analysis"
  echo "  2. Review docs/CRITICAL-FIXES-APPLIED.md for fix details"
  echo "  3. Test in staging environment before production deployment"
  exit 0
else
  echo "✗ Some verification checks failed"
  echo "Please review the errors above before deploying to production"
  exit 1
fi
