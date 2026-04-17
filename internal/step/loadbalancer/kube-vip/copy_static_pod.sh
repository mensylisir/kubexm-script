#!/usr/bin/env bash
set -euo pipefail

step::lb.kube.vip.copy.static.pod::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  if step::check::remote_file_exists "${KUBEXM_HOST}" "/etc/kubernetes/manifests/kube-vip.yaml"; then
    return 0  # already exists, skip
  fi
  return 1  # need to copy
}

step::lb.kube.vip.copy.static.pod::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local deploy_mode
  deploy_mode="$(context::get "lb_kube_vip_deploy_mode" || true)"
  if [[ "${deploy_mode}" != "static-pod" ]]; then
    return 0
  fi

  local pod_file
  pod_file="$(context::get "lb_kube_vip_static_pod_file" || true)"
  if [[ -z "${pod_file}" ]]; then
    return 1
  fi

  runner::remote_exec "mkdir -p /etc/kubernetes/manifests"
  runner::remote_copy_file "${pod_file}" "/etc/kubernetes/manifests/kube-vip.yaml"
}

step::lb.kube.vip.copy.static.pod::rollback() { return 0; }

step::lb.kube.vip.copy.static.pod::targets() {
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