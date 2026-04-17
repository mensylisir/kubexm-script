#!/usr/bin/env bash
set -euo pipefail

step::cluster.scale.cleanup.dirs::check() {
  source "${KUBEXM_ROOT}/internal/step/common/checks.sh"
  # 如果节点不可达，跳过
  if ! step::check::host_reachable 5; then
    return 0
  fi
  if step::check::remote_dir_exists "${KUBEXM_HOST}" "/etc/kubernetes"; then
    return 1
  fi
  if step::check::remote_dir_exists "${KUBEXM_HOST}" "/var/lib/kubelet"; then
    return 1
  fi
  if step::check::remote_dir_exists "${KUBEXM_HOST}" "/var/lib/etcd"; then
    return 1
  fi
  if step::check::remote_dir_exists "${KUBEXM_HOST}" "/root/.kube"; then
    return 1
  fi
  return 0
}

step::cluster.scale.cleanup.dirs::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  runner::remote_exec "rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd ~/.kube >/dev/null 2>&1 || true"
}

step::cluster.scale.cleanup.dirs::rollback() { return 0; }

step::cluster.scale.cleanup.dirs::targets() {
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
