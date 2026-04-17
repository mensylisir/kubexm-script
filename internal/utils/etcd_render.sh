#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Etcd Render Helpers
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

KUBEXM_SCRIPT_ROOT="${KUBEXM_SCRIPT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"

source "${KUBEXM_SCRIPT_ROOT}/internal/logger/log.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/config.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/template.sh"

etcd::generate_config() {
  local node_name="$1"
  local node_ip="$2"
  local output_dir="$3"

  log::info "Generating etcd configuration for ${node_name}..."

  local etcd_members
  etcd_members=$(config::get_role_members "etcd")

  local initial_cluster=""
  for member in ${etcd_members}; do
    local member_ip
    member_ip=$(config::get_host_param "${member}" "address")
    initial_cluster+="${member}=https://${member_ip}:2380,"
  done
  initial_cluster="${initial_cluster%,}"

  declare -A etcd_vars=(
    [CLUSTER_NAME]="${KUBEXM_CLUSTER_NAME}"
    [NODE_NAME]="${node_name}"
    [NODE_IP]="${node_ip}"
    [ETCD_DATA_DIR]="/var/lib/etcd"
    [ETCD_INITIAL_CLUSTER]="${initial_cluster}"
    [ETCD_CLUSTER_TOKEN]="${KUBEXM_CLUSTER_NAME}-etcd-cluster"
    [ETCD_INITIAL_STATE]="new"
    [ETCD_SNAPSHOT_COUNT]="10000"
    [ETCD_AUTO_COMPACTION_RETENTION]="1"
    [ETCD_AUTO_COMPACTION_MODE]="periodic"
    [ETCD_QUOTA_BACKEND_BYTES]="8589934592"
    [ETCD_MAX_WALS]="5"
    [ETCD_HEARTBEAT_INTERVAL]="250"
    [ETCD_ELECTION_TIMEOUT]="2500"
    [ETCD_LOG_LEVEL]="info"
  )

  local template_file="${KUBEXM_SCRIPT_ROOT}/templates/etcd/etcd.config.yml.tmpl"
  local config_file="${output_dir}/etcd.config.yml"

  if ! template::render "${template_file}" "${config_file}" etcd_vars; then
    log::error "Failed to render etcd config template"
    return 1
  fi

  log::success "Etcd config generated: ${config_file}"
  return 0
}

etcd::generate_service() {
  local node_name="$1"
  local output_dir="$2"

  log::info "Generating etcd systemd service for ${node_name}..."

  declare -A etcd_vars=(
    [NODE_NAME]="${node_name}"
    [ETCD_DATA_DIR]="/var/lib/etcd"
  )

  local template_file="${KUBEXM_SCRIPT_ROOT}/templates/etcd/etcd.service.tmpl"
  local service_file="${output_dir}/etcd.service"

  if ! template::render "${template_file}" "${service_file}" etcd_vars; then
    log::error "Failed to render etcd service template"
    return 1
  fi

  log::success "Etcd service generated: ${service_file}"
  return 0
}

export -f etcd::generate_config
export -f etcd::generate_service
