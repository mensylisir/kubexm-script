#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Step: cni_apply
# 应用 CNI manifest（配置变更后重新应用）
# ==============================================================================


step::cni.apply::run() {
  local ctx="$1"; shift
  if [[ $# -gt 0 ]]; then local host="$1"; shift; else local host=""; fi
  set -- "${ctx}" "${host}" "$@"
  shift 2
  step::cni.apply "$@"
}

step::cni.apply() {
  local ctx="$1"
  local host="${2:-}"
  shift 2

  logger::info "[host=${host} step=cni.apply] Applying CNI manifest..."

  local kubeconfig
  kubeconfig="$(context::get kubeconfig_path)"
  local network_plugin
  network_plugin=$(config::get_network_plugin)

  case "${network_plugin}" in
    calico)
      local manifest_file="/etc/kubernetes/cni/calico/calico.yaml"
      kubectl --kubeconfig="${kubeconfig}" apply -f "${manifest_file}"
      ;;
    flannel)
      local manifest_file="/etc/kubernetes/cni/flannel/flannel.yaml"
      kubectl --kubeconfig="${kubeconfig}" apply -f "${manifest_file}"
      ;;
    cilium)
      local manifest_file="/etc/kubernetes/cni/cilium/cilium.yaml"
      kubectl --kubeconfig="${kubeconfig}" apply -f "${manifest_file}"
      ;;
    *)
      logger::error "[host=${host}] Unsupported CNI plugin: ${network_plugin}"
      return 1
      ;;
  esac

  logger::info "[host=${host} step=cni.apply] CNI manifest applied"
  return 0
}

step::cni.apply::check() {
  # kubectl apply is naturally idempotent; always re-apply to ensure CNI is configured.
  # TODO: could be improved with manifest hash comparison for true idempotency.
  return 1
}

step::cni.apply::rollback() { return 0; }

step::cni.apply::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/utils/targets.sh"
  targets::for_standard_collect
}
