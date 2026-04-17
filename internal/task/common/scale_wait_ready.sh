#!/usr/bin/env bash
set -euo pipefail

step::cluster.scale.wait.ready::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"
  local action=""
  action="$(defaults::get_scale_action)"
  if [[ "${action}" != "scale-out" ]]; then
    return 0  # not scale-out, skip
  fi
  return 1  # scale-out action, need to wait
}

step::cluster.scale.wait.ready::run() {
  local ctx="$1"
  shift
  local action=""
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --action=*) action="${arg#*=}" ;;
    esac
  done
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"

  if [[ -z "${action}" ]]; then
    action="$(defaults::get_scale_action)"
  fi
  if [[ "${action}" != "scale-out" ]]; then
    return 0
  fi

  local worker_nodes current_nodes nodes_to_join=""
  worker_nodes=$(config::get_role_members 'worker')
  current_nodes=$(kubectl get nodes -o name 2>/dev/null | sed 's/node\\///g' || echo "")

  local node
  for node in ${worker_nodes}; do
    if [[ ! "${current_nodes}" =~ ${node} ]]; then
      nodes_to_join="${nodes_to_join} ${node}"
    fi
  done

  if [[ -z "${nodes_to_join}" ]]; then
    return 0
  fi

  local timeout
  timeout="$(defaults::get_node_wait_timeout)"

  for node in ${nodes_to_join}; do
    log::info "Waiting for node ${node} to be ready..."
    local elapsed=0
    while [[ ${elapsed} -lt ${timeout} ]]; do
      local node_status
      node_status=$(kubectl get node "${node}" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
      if [[ "${node_status}" == "True" ]]; then
        log::info "Node ${node} is ready"
        break
      fi
      sleep 5
      elapsed=$((elapsed + 5))
      log::info "Waiting for node ${node}... (${elapsed}s/${timeout}s)"
    done
    if [[ ${elapsed} -ge ${timeout} ]]; then
      log::error "Timeout waiting for node ${node} to be ready"
      return 1
    fi
  done
}

step::cluster.scale.wait.ready::rollback() { return 0; }

step::cluster.scale.wait.ready::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
