#!/usr/bin/env bash
set -euo pipefail

step::cluster.upgrade.workers::check() { return 1; }

step::cluster.upgrade.workers::run() {
  local ctx="$1"
  shift
  local target_version=""
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --to-version=*) target_version="${arg#*=}" ;;
    esac
  done
  if [[ -z "${target_version}" ]]; then
    echo "missing required --to-version for upgrade cluster" >&2
    return 2
  fi

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local worker_nodes
  worker_nodes=$(kubectl get nodes -l node-role.kubernetes.io/worker -o name | sed 's/node\\///g' || echo "")
  if [[ -z "${worker_nodes}" ]]; then
    log::warn "No worker nodes found"
    return 0
  fi

  local node_name=""
  local node
  for node in ${worker_nodes}; do
    local node_ip
    node_ip=$(config::get_host_param "${node}" "address" 2>/dev/null || true)
    if [[ -n "${node_ip}" && "${node_ip}" == "${KUBEXM_HOST}" ]]; then
      node_name="${node}"
      break
    fi
  done
  [[ -z "${node_name}" ]] && node_name="${KUBEXM_HOST}"

  log::info "Upgrading worker node: ${node_name}"
  kubectl drain "${node_name}" --ignore-daemonsets --delete-emptydir-data --force || true
  runner::remote_exec "kubeadm upgrade node"
  runner::remote_exec "systemctl daemon-reload && systemctl restart kubelet"
  kubectl uncordon "${node_name}"
  log::info "Worker node ${node_name} upgraded"
}

step::cluster.upgrade.workers::rollback() { return 0; }

step::cluster.upgrade.workers::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  local worker_nodes out=""
  worker_nodes=$(kubectl get nodes -l node-role.kubernetes.io/worker -o name | sed 's/node\\///g' || echo "")
  local node node_ip
  for node in ${worker_nodes}; do
    node_ip=$(config::get_host_param "${node}" "address" 2>/dev/null || true)
    if [[ -z "${node_ip}" ]]; then
      node_ip=$(kubectl get node "${node}" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || true)
    fi
    [[ -z "${node_ip}" ]] && continue
    out+="${node_ip} "
  done
  echo "${out}"
}
