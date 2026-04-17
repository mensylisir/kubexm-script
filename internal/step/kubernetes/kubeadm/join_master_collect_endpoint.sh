#!/usr/bin/env bash
set -euo pipefail

step::kubeadm.join.master.collect.endpoint::check() { return 1; }

step::kubeadm.join.master.collect.endpoint::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"

  local first_master_ip
  first_master_ip="$(context::get "kubeadm_join_master_first_master_ip" || true)"

  local apiserver_endpoint
  apiserver_endpoint=$(config::get_apiserver_endpoint)
  if [[ -z "${apiserver_endpoint}" ]]; then
    if [[ -n "${first_master_ip}" ]]; then
      apiserver_endpoint="${first_master_ip}:6443"
    fi
  fi

  local runtime_type cri_socket
  runtime_type=$(config::get_runtime_type 2>/dev/null || echo "containerd")
  case "${runtime_type}" in
    containerd) cri_socket="unix:///run/containerd/containerd.sock" ;;
    docker)     cri_socket="unix:///var/run/cri-dockerd.sock" ;;
    crio)       cri_socket="unix:///var/run/crio/crio.sock" ;;
    *)          cri_socket="unix:///run/containerd/containerd.sock" ;;
  esac

  context::set "kubeadm_join_master_apiserver_endpoint" "${apiserver_endpoint}"
  context::set "kubeadm_join_master_cri_socket" "${cri_socket}"
}

step::kubeadm.join.master.collect.endpoint::rollback() { return 0; }

step::kubeadm.join.master.collect.endpoint::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_role "control-plane"
}
