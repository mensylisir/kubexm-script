#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: addon_apply
# 应用 addon manifest（配置变更后重新应用）
# ==============================================================================


step::addon.apply() {
  local ctx="$1"
  local host="${2:-}"
  shift 2

  logger::info "[host=${host} step=addon.apply] Applying addon manifest..."

  local kubeconfig
  kubeconfig="$(context::get kubeconfig_path)"
  local addon_name="${3:-}"

  case "${addon_name}" in
    metrics-server)
      kubectl --kubeconfig="${kubeconfig}" apply -f /etc/kubernetes/addons/metrics-server/
      ;;
    ingress)
      kubectl --kubeconfig="${kubeconfig}" apply -f /etc/kubernetes/addons/ingress/
      ;;
    coredns)
      kubectl --kubeconfig="${kubeconfig}" apply -f /etc/kubernetes/addons/coredns/
      ;;
    *)
      logger::error "[host=${host}] Unknown addon: ${addon_name}"
      return 1
      ;;
  esac

  logger::info "[host=${host} step=addon.apply] Addon ${addon_name} applied"
  return 0
}

step::addon.apply::run() {
  step::addon.apply "$@"
}

step::addon.apply.metrics.server::run() {
  step::addon.apply "$@"
}

step::addon.apply.ingress::run() {
  step::addon.apply "$@"
}

step::addon.apply.coredns::run() {
  step::addon.apply "$@"
}

step::addon.apply::check() {
  # 配置变更后总是需要重新应用
  return 1
}

step::addon.apply.metrics.server::check() {
  # kubectl apply is idempotent; always run to ensure addon is applied.
  return 1
}

step::addon.apply.ingress::check() {
  # kubectl apply is idempotent; always run to ensure addon is applied.
  return 1
}

step::addon.apply.coredns::check() {
  # kubectl apply is idempotent; always run to ensure addon is applied.
  return 1
}

step::addon.apply::targets() {
  return 0
}

step::addon.apply.metrics.server::targets() {
  return 0
}

step::addon.apply.ingress::targets() {
  return 0
}

step::addon.apply.coredns::targets() {
  return 0
}

step::addon.apply::rollback() {
  return 0
}

step::addon.apply.metrics.server::rollback() {
  return 0
}

step::addon.apply.ingress::rollback() {
  return 0
}

step::addon.apply.coredns::rollback() {
  return 0
}
