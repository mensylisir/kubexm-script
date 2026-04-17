#!/usr/bin/env bash
set -euo pipefail

step::registry.create.collect.arch::check() { return 1; }

step::registry.create.collect.arch::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"

  local node_name
  node_name="$(context::get "registry_create_node_name" || true)"

  local arch
  arch=$(config::get_host_param "${node_name}" "arch")
  if [[ -z "${arch}" ]]; then
    arch=$(config::get_arch_list | awk -F',' '{print $1}')
  fi
  case "${arch}" in
    x86_64) arch="amd64" ;;
    aarch64) arch="arm64" ;;
  esac
  if [[ -z "${arch}" ]]; then
    log::error "Failed to resolve arch for ${node_name}"
    return 1
  fi

  context::set "registry_create_arch" "${arch}"
}

step::registry.create.collect.arch::rollback() { return 0; }

step::registry.create.collect.arch::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "registry"
}
