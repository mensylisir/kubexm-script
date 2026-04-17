#!/usr/bin/env bash
set -euo pipefail

step::cluster.distribute.tools::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/identity.sh"

  local node_name arch tools_dir
  node_name="$(identity::resolve_node_name)"
  arch="$(identity::resolve_arch "${node_name}")"
  tools_dir="${KUBEXM_ROOT}/packages/tools/common/${arch}"

  # Check if tools directory exists locally
  if [[ ! -d "${tools_dir}" ]]; then
    return 0  # no tools dir, skip
  fi

  # Check if at least one tool exists
  if [[ -z "$(ls -A "${tools_dir}" 2>/dev/null)" ]]; then
    return 0  # no tools, skip
  fi

  return 1  # have tools, need to distribute
}

step::cluster.distribute.tools::run() {
  local ctx="$1"
  shift
  local cluster_name="${KUBEXM_CLUSTER_NAME:-}"
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --cluster=*) cluster_name="${arg#*=}" ;;
    esac
  done
  if [[ -z "${cluster_name}" ]]; then
    echo "missing required --cluster for create cluster" >&2
    return 2
  fi
  export KUBEXM_CLUSTER_NAME="${cluster_name}"

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/utils/identity.sh"

  local node_name arch tools_dir
  node_name="$(identity::resolve_node_name)"
  arch="$(identity::resolve_arch "${node_name}")"
  tools_dir="${KUBEXM_ROOT}/packages/tools/common/${arch}"

  if [[ ! -d "${tools_dir}" ]]; then
    log::error "Missing tools directory: ${tools_dir}"
    return 1
  fi

  runner::remote_exec "mkdir -p /usr/local/bin"

  local tool_path tool_name
  for tool_path in "${tools_dir}"/*; do
    [[ -f "${tool_path}" ]] || continue
    tool_name="$(basename "${tool_path}")"
    runner::remote_copy_file "${tool_path}" "/usr/local/bin/${tool_name}"
    runner::remote_exec "chmod +x /usr/local/bin/${tool_name}"
  done

  log::info "Common tools distributed to ${KUBEXM_HOST} (${arch})"
}

step::cluster.distribute.tools::rollback() { return 0; }

step::cluster.distribute.tools::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_all_hosts
}
