#!/usr/bin/env bash
set -euo pipefail

step::lb.external.kubexm.kn.render.check.script::check() {
  local cluster_name="${KUBEXM_CLUSTER_NAME:-}"
  local node_name="${KUBEXM_HOST:-}"
  if [[ -z "${cluster_name}" || -z "${node_name}" ]]; then
    return 1
  fi
  local lb_dir="${KUBEXM_ROOT}/packages/${cluster_name}/${node_name}/loadbalancer/kubexm-kn"
  if [[ -f "${lb_dir}/check_nginx.sh" ]]; then
    return 0
  fi
  return 1
}

step::lb.external.kubexm.kn.render.check.script::run() {
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
  source "${KUBEXM_ROOT}/internal/config/config.sh"

  local node_name=""
  local node
  for node in $(config::get_all_host_names); do
    local node_ip
    node_ip=$(config::get_host_param "${node}" "address")
    if [[ "${node_ip}" == "${KUBEXM_HOST}" ]]; then
      node_name="${node}"
      break
    fi
  done
  if [[ -z "${node_name}" ]]; then
    node_name="${KUBEXM_HOST}"
  fi

  local lb_dir
  lb_dir="${KUBEXM_ROOT}/packages/${cluster_name}/${node_name}/loadbalancer/kubexm-kn"
  mkdir -p "${lb_dir}"

  cat > "${lb_dir}/check_nginx.sh" <<'EOF'
#!/bin/bash
if ! pgrep -x nginx > /dev/null; then
  exit 1
fi
if ! ss -tlnp | grep -q ":6443 "; then
  exit 1
fi
exit 0
EOF
}

step::lb.external.kubexm.kn.render.check.script::rollback() { return 0; }

step::lb.external.kubexm.kn.render.check.script::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "loadbalancer"
}
