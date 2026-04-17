#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# LoadBalancer Module
# ==============================================================================
# 负载均衡模块，支持：
# - kube-vip
# - internal: haproxy static pod / nginx static pod / haproxy systemd / nginx systemd
# - external: kubexm-kh (keepalived+haproxy) / kubexm-kn (keepalived+nginx)
# ==============================================================================

source "${KUBEXM_ROOT}/internal/task/common.sh"
source "${KUBEXM_ROOT}/internal/task/network/lb/kube_vip.sh"
source "${KUBEXM_ROOT}/internal/task/network/lb/haproxy_static_pod.sh"
source "${KUBEXM_ROOT}/internal/task/network/lb/nginx_static_pod.sh"
source "${KUBEXM_ROOT}/internal/task/network/lb/haproxy_systemd.sh"
source "${KUBEXM_ROOT}/internal/task/network/lb/nginx_systemd.sh"
source "${KUBEXM_ROOT}/internal/task/network/lb/kubexm_kh.sh"
source "${KUBEXM_ROOT}/internal/task/network/lb/kubexm_kn.sh"
source "${KUBEXM_ROOT}/internal/task/network/lb/exists.sh"
source "${KUBEXM_ROOT}/internal/task/network/lb/restart.sh"

# -----------------------------------------------------------------------------
# 安装负载均衡（自动选择）
# -----------------------------------------------------------------------------
module::lb_install() {
  local ctx="$1"
  shift

  local lb_enabled lb_mode lb_type k8s_type
  lb_enabled=$(config::get_loadbalancer_enabled)
  if [[ "${lb_enabled}" != "true" ]]; then
    return 0
  fi

  lb_mode=$(config::get_loadbalancer_mode)
  lb_type=$(config::get_loadbalancer_type)
  k8s_type=$(config::get_kubernetes_type)

  case "${lb_mode}" in
    internal)
      if [[ "${k8s_type}" == "kubeadm" ]]; then
        # kubeadm 使用 static pod
        if [[ "${lb_type}" == "haproxy" ]]; then
          task::install_lb_haproxy_static_pod "${ctx}" "$@"
        else
          task::install_lb_nginx_static_pod "${ctx}" "$@"
        fi
      else
        # kubexm 使用 systemd
        if [[ "${lb_type}" == "haproxy" ]]; then
          task::install_lb_haproxy_systemd "${ctx}" "$@"
        else
          task::install_lb_nginx_systemd "${ctx}" "$@"
        fi
      fi
      ;;
    external)
      if [[ "${lb_type}" == "kubexm-kh" ]]; then
        task::install_lb_external_kubexm_kh "${ctx}" "$@"
      else
        task::install_lb_external_kubexm_kn "${ctx}" "$@"
      fi
      ;;
    kube-vip)
      task::install_kube_vip "${ctx}" "$@"
      ;;
    exists)
      task::install_lb_exists "${ctx}" "$@"
      ;;
    *)
      echo "Unsupported loadbalancer mode: ${lb_mode}" >&2
      return 1
      ;;
  esac
}

# -----------------------------------------------------------------------------
# 删除负载均衡
# -----------------------------------------------------------------------------
module::lb_delete() {
  local ctx="$1"
  shift

  local lb_enabled lb_mode lb_type k8s_type
  lb_enabled=$(config::get_loadbalancer_enabled)
  if [[ "${lb_enabled}" != "true" ]]; then
    return 0
  fi

  lb_mode=$(config::get_loadbalancer_mode)
  lb_type=$(config::get_loadbalancer_type)
  k8s_type=$(config::get_kubernetes_type)

  case "${lb_mode}" in
    internal)
      if [[ "${k8s_type}" == "kubeadm" ]]; then
        if [[ "${lb_type}" == "haproxy" ]]; then
          task::delete_lb_haproxy_static_pod "${ctx}" "$@"
        else
          task::delete_lb_nginx_static_pod "${ctx}" "$@"
        fi
      else
        if [[ "${lb_type}" == "haproxy" ]]; then
          task::delete_lb_haproxy_systemd "${ctx}" "$@"
        else
          task::delete_lb_nginx_systemd "${ctx}" "$@"
        fi
      fi
      ;;
    external)
      if [[ "${lb_type}" == "kubexm-kh" ]]; then
        task::delete_lb_external_kubexm_kh "${ctx}" "$@"
      else
        task::delete_lb_external_kubexm_kn "${ctx}" "$@"
      fi
      ;;
    kube-vip)
      task::delete_kube_vip "${ctx}" "$@"
      ;;
    exists)
      # exists 模式：LB 是外部的，无需删除，仅做清理本地状态（如有）
      logger::info "[Module:lb] Skipping LB deletion (mode=exists, external LB managed by user)"
      task::delete_lb_exists "${ctx}" "$@" || true
      ;;
  esac
}

# -----------------------------------------------------------------------------
# 仅重载配置（不重新安装）
# -----------------------------------------------------------------------------
module::lb_reload_config() {
  local ctx="$1"
  shift

  local lb_enabled lb_mode lb_type k8s_type
  lb_enabled=$(config::get_loadbalancer_enabled)
  if [[ "${lb_enabled}" != "true" ]]; then
    return 0
  fi

  lb_mode=$(config::get_loadbalancer_mode)
  lb_type=$(config::get_loadbalancer_type)
  k8s_type=$(config::get_kubernetes_type)

  case "${lb_mode}" in
    internal)
      if [[ "${k8s_type}" == "kubeadm" ]]; then
        # static pod 模式下删除 pod yaml 让 kubelet 自动重建
        logger::info "[Module:lb] Reloading static pod config (deleting pod manifests)..."
        if [[ "${lb_type}" == "haproxy" ]]; then
          task::delete_lb_haproxy_static_pod "${ctx}" "$@" || true
        else
          task::delete_lb_nginx_static_pod "${ctx}" "$@" || true
        fi
      else
        # systemd 模式下重启对应服务
        if [[ "${lb_type}" == "haproxy" ]]; then
          task::restart_haproxy "${ctx}" "$@"
        else
          task::restart_nginx "${ctx}" "$@"
        fi
      fi
      ;;
    external)
      # external 模式下根据 lb_type 重启对应的 LB + keepalived
      if [[ "${lb_type}" == "kubexm-kh" ]]; then
        task::restart_haproxy "${ctx}" "$@"
      else
        task::restart_nginx "${ctx}" "$@"
      fi
      task::restart_keepalived "${ctx}" "$@"
      ;;
    kube-vip)
      # kube-vip 模式下删除并重建 pod/daemonset
      logger::info "[Module:lb] Reloading kube-vip config (deleting and reapplying)..."
      task::delete_kube_vip "${ctx}" "$@" || true
      task::install_kube_vip "${ctx}" "$@"
      ;;
  esac
}

export -f module::lb_install
export -f module::lb_delete
export -f module::lb_reload_config

# Alias for compatibility
module::lb_reconfigure() {
  module::lb_reload_config "$@"
}

export -f module::lb_reconfigure