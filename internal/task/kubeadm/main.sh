#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Cluster Task - Kubeadm Operations
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"

task::kubeadm_init_master() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "kubeadm.init.master:${KUBEXM_ROOT}/internal/step/kubernetes/kubeadm/init_master.sh"
}

task::kubeadm_init_external_etcd() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "kubeadm.init.external.etcd:${KUBEXM_ROOT}/internal/step/kubernetes/kubeadm/init_external_etcd.sh"
}

task::kubeadm_fetch_kubeconfig() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "kubeadm.fetch.kubeconfig:${KUBEXM_ROOT}/internal/step/kubernetes/kubeadm/fetch_kubeconfig.sh"
}

task::kubeadm_prepare_join() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "kubeadm.prepare.join:${KUBEXM_ROOT}/internal/step/kubernetes/kubeadm/prepare_join.sh"
}

task::kubeadm_join_master() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "kubeadm.join.master.load.params:${KUBEXM_ROOT}/internal/step/kubernetes/kubeadm/join_master_load_params.sh" \
    "kubeadm.join.master.collect.endpoint:${KUBEXM_ROOT}/internal/step/kubernetes/kubeadm/join_master_collect_endpoint.sh" \
    "kubeadm.join.master.collect.paths:${KUBEXM_ROOT}/internal/step/kubernetes/kubeadm/join_master_collect_paths.sh" \
    "kubeadm.join.master.render:${KUBEXM_ROOT}/internal/step/kubernetes/kubeadm/join_master_render.sh" \
    "kubeadm.join.master.copy.config:${KUBEXM_ROOT}/internal/step/kubernetes/kubeadm/join_master_copy_config.sh" \
    "kubeadm.join.master.run:${KUBEXM_ROOT}/internal/step/kubernetes/kubeadm/join_master_run.sh" \
    "kubeadm.join.master.copy.kubeconfig:${KUBEXM_ROOT}/internal/step/kubernetes/kubeadm/join_master_copy_kubeconfig.sh"
}

task::kubeadm_join_worker() {
  local ctx="$1"
  shift
  task::run_steps "${ctx}" "$@" -- \
    "kubeadm.join.worker.load.params:${KUBEXM_ROOT}/internal/step/kubernetes/kubeadm/join_worker_load_params.sh" \
    "kubeadm.join.worker.collect.endpoint:${KUBEXM_ROOT}/internal/step/kubernetes/kubeadm/join_worker_collect_endpoint.sh" \
    "kubeadm.join.worker.collect.paths:${KUBEXM_ROOT}/internal/step/kubernetes/kubeadm/join_worker_collect_paths.sh" \
    "kubeadm.join.worker.render:${KUBEXM_ROOT}/internal/step/kubernetes/kubeadm/join_worker_render.sh" \
    "kubeadm.join.worker.copy.config:${KUBEXM_ROOT}/internal/step/kubernetes/kubeadm/join_worker_copy_config.sh" \
    "kubeadm.join.worker.run:${KUBEXM_ROOT}/internal/step/kubernetes/kubeadm/join_worker_run.sh"
}

export -f task::kubeadm_init_master
export -f task::kubeadm_init_external_etcd
export -f task::kubeadm_fetch_kubeconfig
export -f task::kubeadm_prepare_join
export -f task::kubeadm_join_master
export -f task::kubeadm_join_worker
