#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Resource Validation Framework
# ==============================================================================
# Provides utilities for validating system resources across the cluster
# Can be used by pipelines, preflight checks, and capacity planning
# ==============================================================================

source "${KUBEXM_ROOT}/internal/logger/log.sh"
source "${KUBEXM_ROOT}/internal/config/config.sh"
source "${KUBEXM_ROOT}/internal/runner/runner.sh"

# Default minimum requirements
DEFAULT_MIN_CPU_CORES=2
DEFAULT_MIN_MEMORY_MB=2048
DEFAULT_MIN_DISK_GB=20
DEFAULT_MIN_ETCD_DISK_GB=10

# Control plane specific requirements
CONTROL_PLANE_MIN_CPU=2
CONTROL_PLANE_MIN_MEMORY=2048

# Worker node specific requirements
WORKER_MIN_CPU=1
WORKER_MIN_MEMORY=1024

# Etcd node specific requirements
ETCD_MIN_DISK=10

# ==============================================================================
# Public API Functions
# ==============================================================================

# Validate all nodes meet minimum resource requirements
# Usage: resource::validate_all_nodes [--cluster=name]
resource::validate_all_nodes() {
  local cluster_name=""

  # Parse arguments
  for arg in "$@"; do
    case "${arg}" in
      --cluster=*)
        cluster_name="${arg#*=}"
        ;;
    esac
  done

  if [[ -n "${cluster_name}" ]]; then
    export KUBEXM_CLUSTER_NAME="${cluster_name}"
  fi

  logger::info "Starting resource validation for all cluster nodes..."

  local all_nodes
  all_nodes=$(config::get_all_host_names 2>/dev/null || true)

  if [[ -z "${all_nodes}" ]]; then
    logger::error "No nodes found in cluster configuration"
    return 1
  fi

  local failed_nodes=0
  local total_nodes=0
  local validated_nodes=0

  while IFS= read -r node; do
    [[ -z "${node}" ]] && continue
    ((total_nodes++)) || true

    logger::info "Validating node: ${node}"

    local node_ip
    node_ip=$(config::get_host_param "${node}" "address" 2>/dev/null || true)

    if [[ -z "${node_ip}" ]]; then
      logger::warn "Cannot get IP for node ${node}, skipping"
      ((failed_nodes++)) || true
      continue
    fi

    export KUBEXM_HOST="${node_ip}"
    export KUBEXM_HOST_NAME="${node}"

    if _validate_node_resources "${node}"; then
      ((validated_nodes++)) || true
    else
      ((failed_nodes++)) || true
      logger::error "Node ${node} failed resource validation"
    fi
  done <<< "${all_nodes}"

  logger::info "Resource validation complete: ${validated_nodes}/${total_nodes} nodes passed"

  if [[ ${failed_nodes} -gt 0 ]]; then
    logger::error "${failed_nodes} node(s) failed resource validation"
    return 1
  fi

  logger::info "All nodes passed resource validation"
  return 0
}

# Validate a single node's resources
# Usage: resource::validate_node <node_name>
resource::validate_node() {
  local node_name="$1"

  local node_ip
  node_ip=$(config::get_host_param "${node_name}" "address" 2>/dev/null || true)

  if [[ -z "${node_ip}" ]]; then
    logger::error "Cannot get IP for node ${node_name}"
    return 1
  fi

  export KUBEXM_HOST="${node_ip}"
  export KUBEXM_HOST_NAME="${node_name}"

  _validate_node_resources "${node_name}"
}

# Get resource summary for all nodes
# Usage: resource::get_cluster_summary [--cluster=name]
resource::get_cluster_summary() {
  local cluster_name=""

  for arg in "$@"; do
    case "${arg}" in
      --cluster=*)
        cluster_name="${arg#*=}"
        ;;
    esac
  done

  if [[ -n "${cluster_name}" ]]; then
    export KUBEXM_CLUSTER_NAME="${cluster_name}"
  fi

  echo "=== Cluster Resource Summary ==="
  echo ""

  local all_nodes
  all_nodes=$(config::get_all_host_names 2>/dev/null || true)

  if [[ -z "${all_nodes}" ]]; then
    echo "No nodes found"
    return 1
  fi

  printf "%-20s %-15s %-10s %-12s %-12s\n" "NODE" "ROLE" "CPU" "MEMORY" "DISK"
  printf "%-20s %-15s %-10s %-12s %-12s\n" "----" "----" "---" "------" "----"

  while IFS= read -r node; do
    [[ -z "${node}" ]] && continue

    local node_ip
    node_ip=$(config::get_host_param "${node}" "address" 2>/dev/null || true)

    if [[ -z "${node_ip}" ]]; then
      printf "%-20s %-15s %-10s %-12s %-12s\n" "${node}" "unknown" "-" "-" "-"
      continue
    fi

    export KUBEXM_HOST="${node_ip}"
    export KUBEXM_HOST_NAME="${node}"

    local role cpu memory disk
    role=$(_get_node_role "${node}")
    cpu=$(runner::remote_exec "nproc 2>/dev/null || grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo 0")
    local memory_kb
    memory_kb=$(runner::remote_exec "grep MemTotal /proc/meminfo | awk '{print \$2}' 2>/dev/null || echo 0")
    local memory_mb=$((memory_kb / 1024))
    local disk_kb
    disk_kb=$(runner::remote_exec "df -k /var/lib 2>/dev/null | tail -1 | awk '{print \$4}' || df -k / 2>/dev/null | tail -1 | awk '{print \$4}' || echo 0")
    local disk_gb=$((disk_kb / 1024 / 1024))

    printf "%-20s %-15s %-10s %-12s %-12s\n" "${node}" "${role}" "${cpu}c" "${memory_mb}MB" "${disk_gb}GB"
  done <<< "${all_nodes}"

  echo ""
  return 0
}

# Check if node meets minimum requirements
# Usage: resource::check_requirements <node_name>
resource::check_requirements() {
  local node_name="$1"
  shift

  local min_cpu="${MIN_CPU_CORES:-${DEFAULT_MIN_CPU_CORES}}"
  local min_memory="${MIN_MEMORY_MB:-${DEFAULT_MIN_MEMORY_MB}}"
  local min_disk="${MIN_DISK_GB:-${DEFAULT_MIN_DISK_GB}}"

  # Parse optional overrides
  for arg in "$@"; do
    case "${arg}" in
      --min-cpu=*) min_cpu="${arg#*=}" ;;
      --min-memory=*) min_memory="${arg#*=}" ;;
      --min-disk=*) min_disk="${arg#*=}" ;;
    esac
  done

  local node_ip
  node_ip=$(config::get_host_param "${node_name}" "address" 2>/dev/null || true)

  if [[ -z "${node_ip}" ]]; then
    logger::error "Cannot get IP for node ${node_name}"
    return 1
  fi

  export KUBEXM_HOST="${node_ip}"
  export KUBEXM_HOST_NAME="${node_name}"

  local result=0

  # Check CPU
  local cpu_cores
  cpu_cores=$(runner::remote_exec "nproc 2>/dev/null || grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo 0")
  if [[ ${cpu_cores} -lt ${min_cpu} ]]; then
    logger::error "Node ${node_name}: CPU ${cpu_cores}c < required ${min_cpu}c"
    result=1
  fi

  # Check Memory
  local memory_kb
  memory_kb=$(runner::remote_exec "grep MemTotal /proc/meminfo | awk '{print \$2}' 2>/dev/null || echo 0")
  local memory_mb=$((memory_kb / 1024))
  if [[ ${memory_mb} -lt ${min_memory} ]]; then
    logger::error "Node ${node_name}: Memory ${memory_mb}MB < required ${min_memory}MB"
    result=1
  fi

  # Check Disk
  local disk_kb
  disk_kb=$(runner::remote_exec "df -k /var/lib 2>/dev/null | tail -1 | awk '{print \$4}' || df -k / 2>/dev/null | tail -1 | awk '{print \$4}' || echo 0")
  local disk_gb=$((disk_kb / 1024 / 1024))
  if [[ ${disk_gb} -lt ${min_disk} ]]; then
    logger::error "Node ${node_name}: Disk ${disk_gb}GB < required ${min_disk}GB"
    result=1
  fi

  return ${result}
}

# ==============================================================================
# Internal Helper Functions
# ==============================================================================

_validate_node_resources() {
  local node_name="$1"
  local min_cpu="${DEFAULT_MIN_CPU_CORES}"
  local min_memory="${DEFAULT_MIN_MEMORY_MB}"
  local min_disk="${DEFAULT_MIN_DISK_GB}"

  # Determine node role and adjust requirements
  local role
  role=$(_get_node_role "${node_name}")

  case "${role}" in
    control-plane)
      min_cpu="${CONTROL_PLANE_MIN_CPU}"
      min_memory="${CONTROL_PLANE_MIN_MEMORY}"
      ;;
    etcd)
      min_disk="${ETCD_MIN_DISK}"
      ;;
    worker)
      min_cpu="${WORKER_MIN_CPU}"
      min_memory="${WORKER_MIN_MEMORY}"
      ;;
  esac

  # Run checks
  local result=0

  # Check CPU
  local cpu_cores
  cpu_cores=$(runner::remote_exec "nproc 2>/dev/null || grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo 0")
  if [[ ${cpu_cores} -lt ${min_cpu} ]]; then
    logger::error "Insufficient CPU on ${node_name}: has ${cpu_cores}c, requires >= ${min_cpu}c"
    result=1
  else
    logger::info "✓ CPU check passed: ${cpu_cores}c >= ${min_cpu}c"
  fi

  # Check Memory
  local memory_kb
  memory_kb=$(runner::remote_exec "grep MemTotal /proc/meminfo | awk '{print \$2}' 2>/dev/null || echo 0")
  local memory_mb=$((memory_kb / 1024))
  if [[ ${memory_mb} -lt ${min_memory} ]]; then
    logger::error "Insufficient memory on ${node_name}: has ${memory_mb}MB, requires >= ${min_memory}MB"
    result=1
  else
    logger::info "✓ Memory check passed: ${memory_mb}MB >= ${min_memory}MB"
  fi

  # Check Disk
  local disk_kb
  disk_kb=$(runner::remote_exec "df -k /var/lib 2>/dev/null | tail -1 | awk '{print \$4}' || df -k / 2>/dev/null | tail -1 | awk '{print \$4}' || echo 0")
  local disk_gb=$((disk_kb / 1024 / 1024))
  if [[ ${disk_gb} -lt ${min_disk} ]]; then
    logger::error "Insufficient disk on ${node_name}: has ${disk_gb}GB, requires >= ${min_disk}GB"
    result=1
  else
    logger::info "✓ Disk check passed: ${disk_gb}GB >= ${min_disk}GB"
  fi

  return ${result}
}

_get_node_role() {
  local node_name="$1"

  # Check if control-plane
  local cp_nodes
  cp_nodes=$(config::get_role_members 'control-plane' 2>/dev/null || true)
  if echo "${cp_nodes}" | grep -qw "${node_name}"; then
    echo "control-plane"
    return
  fi

  # Check if etcd (separate from control-plane)
  local etcd_nodes
  etcd_nodes=$(config::get_role_members 'etcd' 2>/dev/null || true)
  if echo "${etcd_nodes}" | grep -qw "${node_name}"; then
    echo "etcd"
    return
  fi

  # Check if worker
  local worker_nodes
  worker_nodes=$(config::get_role_members 'worker' 2>/dev/null || true)
  if echo "${worker_nodes}" | grep -qw "${node_name}"; then
    echo "worker"
    return
  fi

  echo "unknown"
}

export -f resource::validate_all_nodes
export -f resource::validate_node
export -f resource::get_cluster_summary
export -f resource::check_requirements
