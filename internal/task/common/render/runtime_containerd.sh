#!/usr/bin/env bash
set -euo pipefail

step::cluster.render.runtime.containerd::check() {
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local runtime_type nodes cluster_dir node
  runtime_type="$(context::get "runtime_type" || true)"
  if [[ "${runtime_type}" != "containerd" ]]; then
    return 0  # not containerd, skip
  fi
  nodes="$(context::get "runtime_nodes" || true)"
  cluster_dir="${KUBEXM_ROOT}/packages/${KUBEXM_CLUSTER_NAME}"
  for node in ${nodes}; do
    [[ -z "${node}" ]] && continue
    local node_dir="${cluster_dir}/${node}"
    if [[ ! -f "${node_dir}/containerd/config.toml" ]]; then
      return 1  # missing config, need to render
    fi
  done
  return 0  # all configs exist, skip
}

step::cluster.render.runtime.containerd::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  : "${KUBEXM_CLUSTER_NAME:?KUBEXM_CLUSTER_NAME is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  local runtime_type registry_addr registry_scheme nodes
  runtime_type="$(context::get "runtime_type" || true)"
  if [[ "${runtime_type}" != "containerd" ]]; then
    return 0
  fi

  registry_addr="$(context::get "runtime_registry_addr" || true)"
  registry_scheme="$(context::get "runtime_registry_scheme" || true)"
  nodes="$(context::get "runtime_nodes" || true)"

  local cluster_dir node
  cluster_dir="${KUBEXM_ROOT}/packages/${KUBEXM_CLUSTER_NAME}"
  for node in ${nodes}; do
    [[ -z "${node}" ]] && continue
    local node_dir="${cluster_dir}/${node}"
    mkdir -p "${node_dir}/containerd"
    printf '%s\n' \
"version = 2

[plugins.\"io.containerd.grpc.v1.cri\"]
  sandbox_image = \"${registry_addr}/pause:3.10\"

[plugins.\"io.containerd.grpc.v1.cri\".registry]
  [plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors]
    [plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"docker.io\"]
      endpoint = [\"${registry_scheme}://${registry_addr}\"]
    [plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"registry.k8s.io\"]
      endpoint = [\"${registry_scheme}://${registry_addr}\"]
    [plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"quay.io\"]
      endpoint = [\"${registry_scheme}://${registry_addr}\"]
    [plugins.\"io.containerd.grpc.v1.cri\".registry.mirrors.\"ghcr.io\"]
      endpoint = [\"${registry_scheme}://${registry_addr}\"]
  [plugins.\"io.containerd.grpc.v1.cri\".registry.configs.\"${registry_addr}\".tls]
    insecure_skip_verify = true" > "${node_dir}/containerd/config.toml"
    log::info "  Generated containerd config for ${node}"
  done
}

step::cluster.render.runtime.containerd::rollback() { return 0; }

step::cluster.render.runtime.containerd::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
