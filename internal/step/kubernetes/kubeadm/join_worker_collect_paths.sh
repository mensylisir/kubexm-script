#!/usr/bin/env bash
set -euo pipefail

step::kubeadm.join.worker.collect.paths::check() { return 1; }

step::kubeadm.join.worker.collect.paths::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"

  local cluster_name
  cluster_name="$(context::get "kubeadm_join_worker_cluster_name" || true)"

  local node_name=""
  local node
  for node in $(config::get_all_host_names); do
    local node_ip
    node_ip=$(config::get_host_param "${node}" "address")
    if [[ "${node_ip}" == "${KUBEXM_HOST}" ]]; then
      node_name="${node}"
      break
    fi
  done
  if [[ -z "${node_name}" ]]; then
    node_name="${KUBEXM_HOST}"
  fi

  local packages_dir
  packages_dir="${KUBEXM_ROOT}/packages/${cluster_name}/${node_name}"
  mkdir -p "${packages_dir}"
  local local_config
  local_config="${packages_dir}/kubeadm-config.yaml"

  local template_file="${KUBEXM_ROOT}/templates/kubernetes/kubeadm/join-worker.yaml.tmpl"

  context::set "kubeadm_join_worker_node_name" "${node_name}"
  context::set "kubeadm_join_worker_node_ip" "${KUBEXM_HOST}"
  context::set "kubeadm_join_worker_local_config" "${local_config}"
  context::set "kubeadm_join_worker_template_file" "${template_file}"
}

step::kubeadm.join.worker.collect.paths::rollback() { return 0; }

step::kubeadm.join.worker.collect.paths::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_workers
}
