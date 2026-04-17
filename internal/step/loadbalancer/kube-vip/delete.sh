#!/usr/bin/env bash
set -euo pipefail

step::lb.kube.vip.delete::check() {
  # Check if kube-vip static pod exists
  if [[ -f "/etc/kubernetes/manifests/kube-vip.yaml" ]]; then
    return 1  # exists, need to delete
  fi
  # Check if kube-vip daemonset exists
  if kubectl get daemonset kube-vip-ds -n kube-system &>/dev/null; then
    return 1  # exists, need to delete
  fi
  return 0  # nothing to delete
}

step::lb.kube.vip.delete::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  log::info "Deleting kube-vip from ${KUBEXM_HOST}..."

  # Remove static pod if exists
  runner::remote_exec "rm -f /etc/kubernetes/manifests/kube-vip.yaml 2>/dev/null || true"

  # Delete daemonset if exists
  kubectl delete daemonset kube-vip-ds -n kube-system &>/dev/null || true

  log::info "Kube-vip deleted from ${KUBEXM_HOST}"
}

step::lb.kube.vip.delete::rollback() { return 0; }

step::lb.kube.vip.delete::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  local master_nodes out=""
  master_nodes=$(config::get_role_members 'control-plane')
  local node node_ip
  for node in ${master_nodes}; do
    node_ip=$(config::get_host_param "${node}" "address")
    [[ -z "${node_ip}" ]] && continue
    out+="${node_ip} "
  done
  echo "${out}"
}