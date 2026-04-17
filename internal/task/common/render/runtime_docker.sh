#!/usr/bin/env bash
set -euo pipefail

step::cluster.render.runtime.docker::check() {
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local runtime_type nodes cluster_dir node
  runtime_type="$(context::get "runtime_type" || true)"
  if [[ "${runtime_type}" != "docker" ]]; then
    return 0  # not docker, skip
  fi
  nodes="$(context::get "runtime_nodes" || true)"
  cluster_dir="${KUBEXM_ROOT}/packages/${KUBEXM_CLUSTER_NAME}"
  for node in ${nodes}; do
    [[ -z "${node}" ]] && continue
    local node_dir="${cluster_dir}/${node}"
    if [[ ! -f "${node_dir}/docker/daemon.json" ]]; then
      return 1  # missing config, need to render
    fi
  done
  return 0  # all configs exist, skip
}

step::cluster.render.runtime.docker::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  : "${KUBEXM_CLUSTER_NAME:?KUBEXM_CLUSTER_NAME is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  local runtime_type registry_addr registry_scheme nodes
  runtime_type="$(context::get "runtime_type" || true)"
  if [[ "${runtime_type}" != "docker" ]]; then
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
    mkdir -p "${node_dir}/docker"
    printf '%s\n' \
"{
  \"insecure-registries\": [\"${registry_addr}\"],
  \"registry-mirrors\": [\"${registry_scheme}://${registry_addr}\"],
  \"exec-opts\": [\"native.cgroupdriver=systemd\"],
  \"log-driver\": \"json-file\",
  \"log-opts\": {
    \"max-size\": \"100m\",
    \"max-file\": \"5\"
  },
  \"storage-driver\": \"overlay2\"
}" > "${node_dir}/docker/daemon.json"
    log::info "  Generated docker config for ${node}"
  done
}

step::cluster.render.runtime.docker::rollback() { return 0; }

step::cluster.render.runtime.docker::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
