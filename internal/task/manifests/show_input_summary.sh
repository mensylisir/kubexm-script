#!/usr/bin/env bash
set -euo pipefail

step::manifests.show.input.summary::check() { return 1; }

step::manifests.show.input.summary::run() {
  local ctx="$1"
  shift

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"

  local cluster_name
  cluster_name="$(context::get "manifests_cluster_name" || true)"

  if [[ -n "$cluster_name" ]]; then
    echo "✓ 成功从配置文件读取参数"
    config::show_summary
  else
    local k8s_version k8s_type etcd_type runtime cni arch
    k8s_version="$(context::get "manifests_k8s_version" || true)"
    k8s_type="$(context::get "manifests_k8s_type" || true)"
    etcd_type="$(context::get "manifests_etcd_type" || true)"
    runtime="$(context::get "manifests_runtime" || true)"
    cni="$(context::get "manifests_cni" || true)"
    arch="$(context::get "manifests_arch" || true)"

    echo "=== Kubernetes依赖清单 ==="
    echo "Kubernetes版本: $k8s_version"
    echo "部署类型: $k8s_type"
    echo "Etcd类型: $etcd_type"
    echo "容器运行时: $runtime"
    echo "CNI插件: $cni"
    echo "架构: $arch"
    echo
  fi
}

step::manifests.show.input.summary::rollback() { return 0; }

step::manifests.show.input.summary::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
