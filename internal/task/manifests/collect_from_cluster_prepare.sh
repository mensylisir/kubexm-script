#!/usr/bin/env bash
set -euo pipefail

step::manifests.collect.from.cluster.prepare::check() { return 1; }

step::manifests.collect.from.cluster.prepare::run() {
  local ctx="$1"
  shift

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"

  local cluster_name
  cluster_name="$(context::get "manifests_cluster_name" || true)"
  if [[ -z "$cluster_name" ]]; then
    return 0
  fi

  local config_file="${KUBEXM_CONFIG_FILE}"
  local host_file="${KUBEXM_HOST_FILE}"

  if [[ ! -f "$config_file" ]]; then
    echo "配置文件不存在: $config_file" >&2
    return 1
  fi

  if [[ ! -f "$host_file" ]]; then
    echo "主机文件不存在: $host_file" >&2
    return 1
  fi

  export KUBEXM_CONFIG_FILE="$config_file"
  export KUBEXM_HOST_FILE="$host_file"
  config::parse_config
  config::parse_hosts

  context::set "manifests_config_file" "${config_file}"
  context::set "manifests_host_file" "${host_file}"
}

step::manifests.collect.from.cluster.prepare::rollback() { return 0; }

step::manifests.collect.from.cluster.prepare::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
