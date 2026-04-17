#!/usr/bin/env bash
set -euo pipefail

step::manifests.collect.args::check() { return 1; }

step::manifests.collect.args::run() {
  local ctx="$1"
  shift

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/config/defaults.sh"

  local k8s_version
  k8s_version=$(defaults::get_kubernetes_version)
  local k8s_type
  k8s_type=$(defaults::get_kubernetes_type)
  local etcd_type
  etcd_type=$(defaults::get_etcd_type)
  local runtime
  runtime=$(defaults::get_runtime_type)
  local cni
  cni=$(defaults::get_cni_plugin)
  local arch
  arch=$(defaults::get_arch_list)
  local cluster_name=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --kubernetes-version=*)
        k8s_version="${1#*=}"
        ;;
      --kubernetes-type=*)
        k8s_type="${1#*=}"
        ;;
      --container-runtime=*)
        runtime="${1#*=}"
        ;;
      --cni=*)
        cni="${1#*=}"
        ;;
      --arch=*)
        arch="${1#*=}"
        ;;
      --cluster=*)
        cluster_name="${1#*=}"
        ;;
      -h|--help)
        return 0
        ;;
      *)
        echo "未知参数: $1" >&2
        return 1
        ;;
    esac
    shift
  done

  context::set "manifests_cluster_name" "${cluster_name}"
  context::set "manifests_k8s_version" "${k8s_version}"
  context::set "manifests_k8s_type" "${k8s_type}"
  context::set "manifests_etcd_type" "${etcd_type}"
  context::set "manifests_runtime" "${runtime}"
  context::set "manifests_cni" "${cni}"
  context::set "manifests_arch" "${arch}"
}

step::manifests.collect.args::rollback() { return 0; }

step::manifests.collect.args::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
