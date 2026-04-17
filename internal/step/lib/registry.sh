#!/usr/bin/env bash
set -euo pipefail

declare -A KUBEXM_STEP_REGISTRY=()

# ==============================================================================
# Step Registration
# ==============================================================================

step::register() {
  local name="$1" path="$2"
  KUBEXM_STEP_REGISTRY["${name}"]="${path}"
}

step::load() {
  local name="$1" path
  path="${KUBEXM_STEP_REGISTRY["${name}"]-}"
  if [[ -z "${path}" || ! -f "${path}" ]]; then
    echo "step not registered: ${name}" >&2
    return 2
  fi
  source "${path}"
}

# ==============================================================================
# Auto-discovery: Register all steps from a directory
# ==============================================================================
# Usage: step::register_dir <group> <dir>
# Example: step::register_dir "cluster" "${KUBEXM_ROOT}/internal/step/cluster"
# Result: registers cluster_validate.sh as "cluster.validate", etc.

step::register_dir() {
  local group="$1"
  local dir="$2"

  if [[ ! -d "${dir}" ]]; then
    return 0
  fi

  for file in "${dir}"/*.sh; do
    [[ -f "${file}" ]] || continue
    local name
    name=$(basename "${file}" .sh)
    # Convert file_name.sh -> group.name (underscores to dots)
    # cluster_validate.sh + "cluster" -> cluster.validate
    local step_name="${group}.${name#${group}_}"
    step_name="${step_name//_/.}"
    step::register "${step_name}" "${file}"
  done
}

# ==============================================================================
# Batch registration for common groups
# ==============================================================================

step::register_all() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  local step_root="${KUBEXM_ROOT}/internal/step"

  # Cluster steps
  step::register_dir "cluster" "${step_root}/cluster"

  # Kubernetes component steps
  step::register_dir "kubernetes" "${step_root}/kubernetes"

  # etcd steps
  step::register_dir "etcd" "${step_root}/etcd"

  # Kubeadm steps (moved to kubernetes/kubeadm per directory restructure)
  step::register_dir "kubeadm" "${step_root}/kubernetes/kubeadm"

  # Load balancer steps (external)
  step::register_dir "lb.external.kubexm" "${step_root}/loadbalancer/external/kubexm-kh"
  step::register_dir "lb.external.kubexm" "${step_root}/loadbalancer/external/kubexm-kn"

  # Load balancer steps (internal)
  step::register_dir "lb.internal" "${step_root}/loadbalancer/internal/haproxy"
  step::register_dir "lb.internal" "${step_root}/loadbalancer/internal/nginx"

  # Load balancer steps (kube-vip)
  step::register_dir "lb.kube.vip" "${step_root}/loadbalancer/kube-vip"

  # Certificate steps
  step::register_dir "certs" "${step_root}/certs/renew"
  step::register_dir "certs" "${step_root}/certs/rotate"

  # Download steps
  step::register_dir "download" "${step_root}/download"

  # Registry steps
  step::register_dir "registry" "${step_root}/registry"

  # Images steps
  step::register_dir "images" "${step_root}/images"

  # Manifests steps
  step::register_dir "manifests" "${step_root}/manifests"

  # ISO steps
  step::register_dir "iso" "${step_root}/iso"

  # Check steps (in common/checks/)
  step::register_dir "check" "${step_root}/common/checks"

  # Runtime steps
  step::register_dir "runtime" "${step_root}/runtime"

  # CNI steps
  step::register_dir "cni" "${step_root}/network/cni"

  # Addons steps
  step::register_dir "addons" "${step_root}/addons"

  # OS steps
  step::register_dir "os" "${step_root}/os"
}

# ==============================================================================
# Query functions
# ==============================================================================

step::list() {
  local name
  for name in "${!KUBEXM_STEP_REGISTRY[@]}"; do
    echo "${name}"
  done | sort
}

step::count() {
  echo "${#KUBEXM_STEP_REGISTRY[@]}"
}

step::get_path() {
  local name="$1"
  echo "${KUBEXM_STEP_REGISTRY["${name}"]:-}"
}

# ==============================================================================
# Export functions
# ==============================================================================

export -f step::register
export -f step::load
export -f step::register_dir
export -f step::register_all
export -f step::list
export -f step::count
export -f step::get_path
