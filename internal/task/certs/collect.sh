#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Certs Task - Certificate Collection
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

# 收集 Control Plane 证书
task::collect_cp_certs() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.node.certs.control.plane.collect:${KUBEXM_ROOT}/internal/task/common/node_certs_control_plane_collect.sh" \
    "cluster.node.certs.control.plane.generate:${KUBEXM_ROOT}/internal/task/common/node_certs_control_plane_generate.sh" \
    "cluster.node.certs.control.plane.etcd:${KUBEXM_ROOT}/internal/task/common/node_certs_control_plane_etcd.sh"
}

# 收集 Worker 证书
task::collect_worker_certs() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.node.certs.worker:${KUBEXM_ROOT}/internal/task/common/node_certs_worker.sh"
}

# 收集 etcd 证书
task::collect_etcd_certs() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "cluster.node.certs.etcd:${KUBEXM_ROOT}/internal/task/common/node_certs_etcd.sh"
}

export -f task::collect_cp_certs
export -f task::collect_worker_certs
export -f task::collect_etcd_certs