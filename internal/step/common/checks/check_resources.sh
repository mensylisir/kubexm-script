#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: check.resources
# System Resource Validation
# Validates minimum system requirements for Kubernetes cluster nodes
# ==============================================================================

source "${KUBEXM_ROOT}/internal/logger/log.sh"
source "${KUBEXM_ROOT}/internal/config/config.sh"
source "${KUBEXM_ROOT}/internal/runner/runner.sh"

# Minimum requirements (can be overridden via environment variables)
MIN_CPU_CORES="${KUBEXM_MIN_CPU_CORES:-2}"
MIN_MEMORY_MB="${KUBEXM_MIN_MEMORY_MB:-2048}"
MIN_DISK_GB="${KUBEXM_MIN_DISK_GB:-20}"
MIN_ETCD_DISK_GB="${KUBEXM_MIN_ETCD_DISK_GB:-10}"

# Control plane requirements (higher than workers)
MIN_CONTROL_PLANE_CPU="${KUBEXM_MIN_CONTROL_PLANE_CPU:-2}"
MIN_CONTROL_PLANE_MEMORY="${KUBEXM_MIN_CONTROL_PLANE_MEMORY:-2048}"

# Worker node requirements
MIN_WORKER_CPU="${KUBEXM_MIN_WORKER_CPU:-1}"
MIN_WORKER_MEMORY="${KUBEXM_MIN_WORKER_MEMORY:-1024}"

step::check.resources::check() {
  # Always run resource checks during preflight
  return 1
}

step::check.resources::run() {
  local ctx="$1"
  shift

  log::info "Checking system resources..."

  local node_name="${KUBEXM_HOST_NAME:-unknown}"
  local node_role=""
  local min_cpu="${MIN_CPU_CORES}"
  local min_memory="${MIN_MEMORY_MB}"
  local min_disk="${MIN_DISK_GB}"

  # Determine node role and adjust requirements
  if _is_control_plane_node "${node_name}"; then
    node_role="control-plane"
    min_cpu="${MIN_CONTROL_PLANE_CPU}"
    min_memory="${MIN_CONTROL_PLANE_MEMORY}"
    log::info "Validating control-plane node: ${node_name}"
  elif _is_etcd_node "${node_name}"; then
    node_role="etcd"
    min_disk="${MIN_ETCD_DISK_GB}"
    log::info "Validating etcd node: ${node_name}"
  elif _is_worker_node "${node_name}"; then
    node_role="worker"
    min_cpu="${MIN_WORKER_CPU}"
    min_memory="${MIN_WORKER_MEMORY}"
    log::info "Validating worker node: ${node_name}"
  else
    node_role="unknown"
    log::warn "Unknown node role for ${node_name}, using default requirements"
  fi

  # Check CPU cores
  _check_cpu "${min_cpu}" || return $?

  # Check memory
  _check_memory "${min_memory}" || return $?

  # Check disk space
  _check_disk "${min_disk}" || return $?

  log::info "Resource validation passed for ${node_name} (${node_role}): CPU>=${min_cpu}c, Memory>=${min_memory}MB, Disk>=${min_disk}GB"
  return 0
}

_check_cpu() {
  local required_cores="$1"
  local cpu_info
  cpu_info=$(runner::remote_exec "nproc 2>/dev/null || grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo 0")

  if [[ -z "${cpu_info}" || "${cpu_info}" == "0" ]]; then
    log::error "Failed to detect CPU cores on ${KUBEXM_HOST_NAME:-unknown}"
    return 1
  fi

  if [[ ${cpu_info} -lt ${required_cores} ]]; then
    log::error "Insufficient CPU cores on ${KUBEXM_HOST_NAME:-unknown}: has ${cpu_info}, requires >= ${required_cores}"
    return 1
  fi

  log::info "CPU check passed: ${cpu_info} cores (required: >= ${required_cores})"
  return 0
}

_check_memory() {
  local required_mb="$1"
  local memory_kb
  memory_kb=$(runner::remote_exec "grep MemTotal /proc/meminfo | awk '{print \$2}' 2>/dev/null || echo 0")

  if [[ -z "${memory_kb}" || "${memory_kb}" == "0" ]]; then
    log::error "Failed to detect memory on ${KUBEXM_HOST_NAME:-unknown}"
    return 1
  fi

  local memory_mb=$((memory_kb / 1024))

  if [[ ${memory_mb} -lt ${required_mb} ]]; then
    log::error "Insufficient memory on ${KUBEXM_HOST_NAME:-unknown}: has ${memory_mb}MB, requires >= ${required_mb}MB"
    return 1
  fi

  log::info "Memory check passed: ${memory_mb}MB (required: >= ${required_mb}MB)"
  return 0
}

_check_disk() {
  local required_gb="$1"
  # Check root filesystem or /var/lib (where container data typically lives)
  local disk_available_kb
  disk_available_kb=$(runner::remote_exec "df -k /var/lib 2>/dev/null | tail -1 | awk '{print \$4}' || df -k / 2>/dev/null | tail -1 | awk '{print \$4}' || echo 0")

  if [[ -z "${disk_available_kb}" || "${disk_available_kb}" == "0" ]]; then
    log::error "Failed to detect disk space on ${KUBEXM_HOST_NAME:-unknown}"
    return 1
  fi

  local disk_available_gb=$((disk_available_kb / 1024 / 1024))

  if [[ ${disk_available_gb} -lt ${required_gb} ]]; then
    log::error "Insufficient disk space on ${KUBEXM_HOST_NAME:-unknown}: has ${disk_available_gb}GB, requires >= ${required_gb}GB"
    return 1
  fi

  log::info "Disk space check passed: ${disk_available_gb}GB available (required: >= ${required_gb}GB)"
  return 0
}

_is_control_plane_node() {
  local node_name="$1"
  local control_plane_nodes
  control_plane_nodes=$(config::get_role_members 'control-plane' 2>/dev/null || true)
  echo "${control_plane_nodes}" | grep -qw "${node_name}"
}

_is_etcd_node() {
  local node_name="$1"
  local etcd_nodes
  etcd_nodes=$(config::get_role_members 'etcd' 2>/dev/null || config::get_role_members 'control-plane' 2>/dev/null || true)
  echo "${etcd_nodes}" | grep -qw "${node_name}"
}

_is_worker_node() {
  local node_name="$1"
  local worker_nodes
  worker_nodes=$(config::get_role_members 'worker' 2>/dev/null || true)
  echo "${worker_nodes}" | grep -qw "${node_name}"
}

step::check.resources::rollback() {
  return 0
}

step::check.resources::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  # Run on all nodes in the cluster
  local all_nodes
  all_nodes=$(config::get_all_host_names 2>/dev/null || true)

  if [[ -n "${all_nodes}" ]]; then
    while IFS= read -r node; do
      [[ -z "${node}" ]] && continue
      local node_ip
      node_ip=$(config::get_host_param "${node}" "address" 2>/dev/null || true)
      [[ -n "${node_ip}" ]] && echo "${node_ip}"
    done <<< "${all_nodes}"
  else
    runner::normalize_host ""
  fi
}
