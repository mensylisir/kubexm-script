#!/usr/bin/env bash
set -euo pipefail

step::cluster.upgrade.cni::check() { return 1; }

step::cluster.upgrade.cni::run() {
  local ctx="$1"
  shift

  local target_version=""
  local arg
  for arg in "$@"; do
    case "${arg}" in
      --to-version=*) target_version="${arg#*=}" ;;
    esac
  done
  if [[ -z "${target_version}" ]]; then
    echo "missing required --to-version for upgrade cluster" >&2
    return 2
  fi

  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/logger/log.sh"
  source "${KUBEXM_ROOT}/internal/config/config.sh"
  source "${KUBEXM_ROOT}/internal/context/context.sh"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"

  local plugin
  plugin=$(config::get_network_plugin)

  local need_reinstall="false"

  case "${plugin}" in
    calico)
      log::info "Upgrading Calico CNI to version ${target_version}..."
      local current_version
      current_version=$(kubectl get deployment calico-typha -n kube-system -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null | sed -E 's/.*://' | sed 's/^v//' | head -1 || echo "")
      if [[ -n "${current_version}" && "${current_version}" != "${target_version}" ]]; then
        log::info "Calico version changed: ${current_version} -> ${target_version}"
        need_reinstall="true"
      fi
      ;;
    flannel)
      log::info "Upgrading Flannel CNI to version ${target_version}..."
      local current_version
      current_version=$(kubectl get daemonset kube-flannel-ds -n kube-system -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null | sed -E 's/.*://' | sed 's/^v//' | head -1 || echo "")
      if [[ -n "${current_version}" && "${current_version}" != "${target_version}" ]]; then
        log::info "Flannel version changed: ${current_version} -> ${target_version}"
        need_reinstall="true"
      fi
      ;;
    cilium)
      log::info "Upgrading Cilium CNI to version ${target_version}..."
      local current_version
      current_version=$(kubectl get daemonset cilium -n kube-system -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null | sed -E 's/.*://' | sed 's/^v//' | head -1 || echo "")
      if [[ -n "${current_version}" && "${current_version}" != "${target_version}" ]]; then
        log::info "Cilium version changed: ${current_version} -> ${target_version}"
        need_reinstall="true"
      fi
      ;;
    *)
      log::warn "CNI plugin ${plugin} upgrade not fully supported, doing reconfigure only"
      need_reinstall="false"
      ;;
  esac

  # If version changed, reinstall CNI binaries on all nodes
  if [[ "${need_reinstall}" == "true" ]]; then
    log::info "CNI version changed, reinstalling CNI binaries..."
    task::run_steps "${ctx}" "$@" -- \
      "cluster.install.cni.collect.cluster.name:${KUBEXM_ROOT}/internal/task/cluster/cluster_install_cni_collect_cluster_name.sh" \
      "cluster.install.cni.collect.node.name:${KUBEXM_ROOT}/internal/task/cluster/cluster_install_cni_collect_node_name.sh" \
      "cluster.install.cni.collect.arch:${KUBEXM_ROOT}/internal/task/cluster/cluster_install_cni_collect_arch.sh" \
      "cluster.install.cni.collect.version:${KUBEXM_ROOT}/internal/task/cluster/cluster_install_cni_collect_version.sh" \
      "cluster.install.cni.copy.binaries:${KUBEXM_ROOT}/internal/task/cluster/cluster_install_cni_copy_binaries.sh"
  fi

  # Re-render CNI manifests
  log::info "Re-rendering CNI manifests for ${plugin}..."
  task::run_steps "${ctx}" "$@" -- \
    "cluster.render.cni.collect:${KUBEXM_ROOT}/internal/task/cluster/cluster_render_cni_collect.sh"

  case "${plugin}" in
    calico)
      task::run_steps "${ctx}" "$@" -- \
        "cluster.render.cni.calico:${KUBEXM_ROOT}/internal/task/cluster/cluster_render_cni_calico.sh"
      ;;
    flannel)
      task::run_steps "${ctx}" "$@" -- \
        "cluster.render.cni.flannel:${KUBEXM_ROOT}/internal/task/cluster/cluster_render_cni_flannel.sh"
      ;;
    cilium)
      task::run_steps "${ctx}" "$@" -- \
        "cluster.render.cni.cilium:${KUBEXM_ROOT}/internal/task/cluster/cluster_render_cni_cilium.sh"
      ;;
  esac

  # Apply CNI manifests
  log::info "Applying CNI manifests for ${plugin}..."
  task::cni_apply "${ctx}" "$@"

  log::info "CNI plugin ${plugin} upgraded successfully"
}

step::cluster.upgrade.cni::rollback() { return 0; }

step::cluster.upgrade.cni::targets() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"
  source "${KUBEXM_ROOT}/internal/runner/runner.sh"
  runner::normalize_host ""
}
