#!/usr/bin/env bash
set -euo pipefail

# 配置依赖：统一在文件顶部加载
source "${KUBEXM_ROOT}/internal/logger/log.sh"
source "${KUBEXM_ROOT}/internal/config/config.sh"
source "${KUBEXM_ROOT}/internal/context/context.sh"
source "${KUBEXM_ROOT}/internal/utils/cert-rotation.sh"

certs::renew() {
  local cert_type="$1"
  shift
  local args=("$@")
  local cluster_name="${KUBEXM_CLUSTER_NAME:-}"
  local phase=""
  local need_confirm="false"
  local continue_from=""
  local arg
  for arg in "${args[@]}"; do
    case "${arg}" in
      --cluster=*)
        cluster_name="${arg#*=}"
        ;;
      --phase=*)
        phase="${arg#*=}"
        ;;
      --continue)
        continue_from="true"
        ;;
      --confirm)
        need_confirm="true"
        ;;
    esac
  done
  if [[ -z "${cluster_name}" ]]; then
    echo "missing required --cluster for renew certs" >&2
    return 2
  fi

  export KUBEXM_CLUSTER_NAME="${cluster_name}"
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  local deploy_type
  deploy_type=$(config::get_kubernetes_type)

  # If --continue is specified, resume from saved phase
  if [[ "${continue_from}" == "true" ]]; then
    continue_from=$(context::get "certs_renew_last_phase" || echo "")
    if [[ -n "${continue_from}" ]]; then
      phase="${continue_from}"
      log::info "Resuming from phase: ${phase}"
    else
      log::error "No previous phase found to continue from"
      return 1
    fi
  fi

  # If --phase is specified, execute only that phase
  if [[ -n "${phase}" ]]; then
    log::info "Executing phase ${phase} for ${cert_type} certificates"
    context::set "certs_renew_last_phase" "${phase}"
    context::set "certs_renew_cert_type" "${cert_type}"
    rotation::rotate_phase "${cluster_name}" "${cert_type}" "${deploy_type}" "${phase}" "${need_confirm}"
    return $?
  fi

  # Full rotation (all phases)
  rotation::rotate_all "${cluster_name}" "${cert_type}" "${deploy_type}" "${need_confirm}"
}
