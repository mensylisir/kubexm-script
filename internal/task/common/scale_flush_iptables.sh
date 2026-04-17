#!/usr/bin/env bash
set -euo pipefail

step::cluster.scale.flush.iptables::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  if step::check::remote_command_exists "${KUBEXM_HOST}" "iptables" 2>/dev/null; then
    return 1
  fi
  return 0
}

step::cluster.scale.flush.iptables::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  runner::remote_exec "iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X >/dev/null 2>&1 || true"
}

step::cluster.scale.flush.iptables::rollback() { return 0; }

step::cluster.scale.flush.iptables::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  local action="" nodes_to_remove=""
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --action=*) action="${arg#*=}" ;;
      --nodes=*) nodes_to_remove="${arg#*=}" ;;
    esac
  done
  if [[ -z "${action}" ]]; then
    action="$(defaults::get_scale_action)"
  fi
  if [[ "${action}" != "scale-in" ]]; then
    return 0
  fi
  if [[ -z "${nodes_to_remove}" ]]; then
    return 0
  fi

  IFS=',' read -ra NODE_ARRAY <<< "${nodes_to_remove}"
  local out="" node node_ip
  for node in "${NODE_ARRAY[@]}"; do
    node_ip=$(config::get_host_param "${node}" "address")
    [[ -z "${node_ip}" ]] && continue
    out+="${node_ip} "
  done
  echo "${out}"
}
