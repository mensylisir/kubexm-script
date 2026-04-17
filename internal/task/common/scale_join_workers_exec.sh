#!/usr/bin/env bash
set -euo pipefail

step::cluster.scale.join.workers.exec::check() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  local skip
  skip="$(context::get "cluster_scale_join_skip" || true)"
  if [[ "${skip}" == "true" ]]; then
    return 0  # skip is set, skip execution
  fi
  return 1  # need to execute join
}

step::cluster.scale.join.workers.exec::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local skip
  skip="$(context::get "cluster_scale_join_skip" || true)"
  if [[ "${skip}" == "true" ]]; then
    return 0
  fi

  local node_name join_command
  node_name="$(context::get "cluster_scale_join_node" || true)"
  join_command="$(context::get "cluster_scale_join_cmd" || true)"

  runner::remote_exec "${join_command}"
  log::info "Worker node ${node_name} joined successfully"
}

step::cluster.scale.join.workers.exec::rollback() { return 0; }

step::cluster.scale.join.workers.exec::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  local action=""
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --action=*) action="${arg#*=}" ;;
    esac
  done
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
  local IFS=$'\n'
  for node in ${worker_nodes}; do
    if [[ ! "${current_nodes}" =~ ${node} ]]; then
      nodes_to_join="${nodes_to_join} ${node}"
    fi
  done

  local out=""
  for node in ${nodes_to_join}; do
    local node_ip
    node_ip=$(config::get_host_param "${node}" "address")
    [[ -z "${node_ip}" ]] && continue
    out+="${node_ip} "
  done
  echo "${out}"
}
