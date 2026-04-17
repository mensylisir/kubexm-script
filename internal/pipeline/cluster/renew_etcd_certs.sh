#!/usr/bin/env bash
set -euo pipefail

source "${KUBEXM_ROOT}/internal/loader.sh"
source "${KUBEXM_ROOT}/internal/module/preflight.sh"
source "${KUBEXM_ROOT}/internal/module/certs.sh"
source "${KUBEXM_ROOT}/internal/utils/pipeline.sh"

pipeline::renew_etcd_certs() {
  local ctx="$1"
  shift
  KUBEXM_PIPELINE_NAME="renew.etcd-certs"
  if [[ "${KUBEXM_DRY_RUN:-false}" == "true" ]]; then
    logger::info "DRY-RUN enabled: planning renew etcd-certs pipeline"
    return 0
  fi

  local cluster_name=""
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --cluster=*)
        cluster_name="${arg#*=}"
        ;;
    esac
  done
  if [[ -z "${cluster_name}" ]]; then
    logger::error "missing required --cluster for renew etcd-certs"
    return 2
  fi

  export KUBEXM_CLUSTER_NAME="${cluster_name}"
  
  # 强制更新配置文件路径（因为KUBEXM_CLUSTER_NAME刚刚设置）
  KUBEXM_CONFIG_FILE="${KUBEXM_CLUSTERS_DIR}/${KUBEXM_CLUSTER_NAME}/config.yaml"
  KUBEXM_HOST_FILE="${KUBEXM_CLUSTERS_DIR}/${KUBEXM_CLUSTER_NAME}/host.yaml"
  export KUBEXM_CONFIG_FILE KUBEXM_HOST_FILE
  parser::load_config
  parser::load_hosts
  config::validate_consistency || return 1

  KUBEXM_TOOL_CHECKS="jq yq xmjq xmyq"
  module::check_tools "${ctx}" "$@" || return $?

  # 获取集群锁 + 启动超时监控
  pipeline::start_timeout_watchdog
  pipeline::acquire_lock "${cluster_name}" 600 || { pipeline::stop_timeout_watchdog; return 1; }
  trap 'pipeline::release_lock "${cluster_name}"; pipeline::stop_timeout_watchdog' EXIT

  module::preflight_connectivity_strict "${ctx}" "$@" || return $?

  # Initialize progress tracking (1 step)
  pipeline::init_progress 1

  pipeline::step_start "CertRenew"
  logger::info "[Pipeline] Starting ETCD certs renewal..."
  module::certs_renew_and_restart_etcd "${ctx}" "$@" || { pipeline::step_fail "CertRenew"; return $?; }
  pipeline::step_complete "CertRenew"

  # 成功完成，清空回滚栈，释放锁
  pipeline::clear_rollback_stack
  pipeline::release_lock "${cluster_name}"
  pipeline::stop_timeout_watchdog
  trap - EXIT
  pipeline::summary
  logger::info "[Pipeline:renew_etcd_certs] ETCD certs renewed successfully!"
  return 0
}