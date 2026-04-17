#!/usr/bin/env bash
set -euo pipefail

step::cluster.delete.namespace::check() {
  local ns="${KUBEXM_HOST}"
  if [[ -z "${ns}" ]]; then
    return 1
  fi
  if kubectl get namespace "${ns}" &>/dev/null; then
    return 1
  fi
  return 0
}

step::cluster.delete.namespace::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  local ns="${KUBEXM_HOST}"
  if [[ -z "${ns}" ]]; then
    log::error "Missing namespace name for delete"
    return 1
  fi

  log::info "Deleting namespace: ${ns}"
  kubectl delete "namespace/${ns}" --grace-period=30 --timeout=60s >/dev/null 2>&1 || true
}

step::cluster.delete.namespace::rollback() { return 0; }

step::cluster.delete.namespace::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  local namespaces
  namespaces=$(kubectl get namespaces -o name 2>/dev/null | sed 's/namespace\\///g' | grep -v -E '^(kube-system|kube-public|kube-node-lease)$' || echo "")
  if [[ -z "${namespaces}" ]]; then
    return 0
  fi
  local out=""
  local ns
  for ns in ${namespaces}; do
    [[ -z "${ns}" ]] && continue
    out+="${ns} "
  done
  echo "${out}"
}
