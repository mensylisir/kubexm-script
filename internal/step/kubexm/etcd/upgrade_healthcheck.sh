#!/usr/bin/env bash
set -euo pipefail

step::etcd.upgrade.healthcheck::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local node_name cert_dir
  node_name="$(context::get "etcd_upgrade_node_name" || true)"
  cert_dir="$(context::get "etcd_upgrade_cert_dir" || true)"

  if [[ -z "${node_name}" || -z "${cert_dir}" ]]; then
    return 1  # context not set, need to run
  fi

  # Check if etcd is already healthy
  if runner::remote_exec "ETCDCTL_API=3 etcdctl endpoint health --endpoints=https://127.0.0.1:2379 --cacert=${cert_dir}/ca.crt --cert=${cert_dir}/server.crt --key=${cert_dir}/server.key" 2>/dev/null; then
    return 0  # etcd is healthy, skip
  fi
  return 1  # etcd not healthy, need to check
}

step::etcd.upgrade.healthcheck::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local node_name cert_dir
  node_name="$(context::get "etcd_upgrade_node_name" || true)"
  cert_dir="$(context::get "etcd_upgrade_cert_dir" || true)"

  if runner::remote_exec "ETCDCTL_API=3 etcdctl endpoint health --endpoints=https://127.0.0.1:2379 --cacert=${cert_dir}/ca.crt --cert=${cert_dir}/server.crt --key=${cert_dir}/server.key"; then
    log::success "etcd on ${node_name} upgraded successfully"
  else
    log::error "etcd on ${node_name} upgrade failed"
    return 1
  fi
}

step::etcd.upgrade.healthcheck::rollback() { return 0; }

step::etcd.upgrade.healthcheck::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_etcd_with_fallback
}
