#!/usr/bin/env bash
set -euo pipefail

step::kubernetes.apiserver.collect.audit.settings::check() { return 1; }

step::kubernetes.apiserver.collect.audit.settings::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"

  local audit_log_maxage audit_log_maxbackup audit_log_maxsize
  audit_log_maxage=$(config::get "spec.kubernetes.apiserver.audit.log_maxage" "30" 2>/dev/null || echo "30")
  audit_log_maxbackup=$(config::get "spec.kubernetes.apiserver.audit.log_maxbackup" "10" 2>/dev/null || echo "10")
  audit_log_maxsize=$(config::get "spec.kubernetes.apiserver.audit.log_maxsize" "100" 2>/dev/null || echo "100")

  context::set "kubernetes_apiserver_audit_log_maxage" "${audit_log_maxage}"
  context::set "kubernetes_apiserver_audit_log_maxbackup" "${audit_log_maxbackup}"
  context::set "kubernetes_apiserver_audit_log_maxsize" "${audit_log_maxsize}"
}

step::kubernetes.apiserver.collect.audit.settings::rollback() { return 0; }

step::kubernetes.apiserver.collect.audit.settings::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}
