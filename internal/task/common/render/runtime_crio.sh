#!/usr/bin/env bash
set -euo pipefail

step::cluster.render.runtime.crio::check() {
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local runtime_type nodes cluster_dir node
  runtime_type="$(context::get "runtime_type" || true)"
  if [[ "${runtime_type}" != "crio" ]]; then
    return 0  # not crio, skip
  fi
  nodes="$(context::get "runtime_nodes" || true)"
  cluster_dir="${KUBEXM_ROOT}/packages/${KUBEXM_CLUSTER_NAME}"
  for node in ${nodes}; do
    [[ -z "${node}" ]] && continue
    local node_dir="${cluster_dir}/${node}"
    if [[ ! -f "${node_dir}/crio/config.conf" ]]; then
      return 1  # missing config, need to render
    fi
  done
  return 0  # all configs exist, skip
}

step::cluster.render.runtime.crio::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  : "${KUBEXM_CLUSTER_NAME:?KUBEXM_CLUSTER_NAME is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  local runtime_type registry_addr nodes
  runtime_type="$(context::get "runtime_type" || true)"
  if [[ "${runtime_type}" != "crio" ]]; then
    return 0
  fi

  registry_addr="$(context::get "runtime_registry_addr" || true)"
  nodes="$(context::get "runtime_nodes" || true)"

  local cluster_dir node
  cluster_dir="${KUBEXM_ROOT}/packages/${KUBEXM_CLUSTER_NAME}"
  for node in ${nodes}; do
    [[ -z "${node}" ]] && continue
    local node_dir="${cluster_dir}/${node}"
    mkdir -p "${node_dir}/crio"
    printf '%s\n' \
"# CRIO configuration for ${KUBEXM_CLUSTER_NAME}
[plugins.\"io.containerd.grpc.v1.cri\".registry]
  [plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors]
    [plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"docker.io\"]
      endpoint = [\"https://${registry_addr}\"]
    [plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"registry.k8s.io\"]
      endpoint = [\"https://${registry_addr}\"]
    [plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"quay.io\"]
      endpoint = [\"https://${registry_addr}\"]" > "${node_dir}/crio/config.conf"
    log::info "  Generated crio config for ${node}"
  done
}

step::cluster.render.runtime.crio::rollback() { return 0; }

step::cluster.render.runtime.crio::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}