#!/usr/bin/env bash
set -euo pipefail

step::cluster.install.runtime.crio.collect.versions::check() { return 1; }

step::cluster.install.runtime.crio.collect.versions::run() {
  local ctx="$1"
  shift
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/config/versions.sh"

  local k8s_version
  k8s_version=$(config::get_kubernetes_version)
  local containerd_version runc_version crictl_version
  containerd_version=$(versions::get "containerd" "${k8s_version}")
  runc_version=$(versions::get "runc" "${k8s_version}")
  crictl_version=$(versions::get "crictl" "${k8s_version}")

  context::set "runtime_crio_k8s_version" "${k8s_version}"
  context::set "runtime_crio_containerd_version" "${containerd_version}"
  context::set "runtime_crio_runc_version" "${runc_version}"
  context::set "runtime_crio_crictl_version" "${crictl_version}"
}

step::cluster.install.runtime.crio.collect.versions::rollback() { return 0; }

step::cluster.install.runtime.crio.collect.versions::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
