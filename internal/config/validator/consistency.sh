#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Config Validator (Consistency)
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

config::validator::validate_consistency() {
  local errors=0

  local registry_enabled
  registry_enabled=$(config::get_registry_enabled)
  local registry_nodes
  registry_nodes="$(config::get_role_members "registry")"

  if [[ "${registry_enabled}" == "true" ]] && [[ -z "${registry_nodes}" ]]; then
    log::error "配置不一致: config.yaml 中启用了 registry (spec.registry.enable: true)"
    log::error "           但 host.yaml 中未定义 registry 主机组"
    log::info  "解决方案: 在 host.yaml 中添加 registry 角色的主机，或在 config.yaml 中禁用 registry"
    ((errors++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
  fi

  if [[ "${registry_enabled}" != "true" ]] && [[ -n "${registry_nodes}" ]]; then
    log::error "配置不一致: host.yaml 中定义了 registry 主机组"
    log::error "           但 config.yaml 中未启用 registry (spec.registry.enable: false)"
    log::info  "解决方案: 在 config.yaml 中启用 registry，或从 host.yaml 中移除 registry 角色"
    ((errors++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
  fi

  local lb_mode lb_type
  lb_mode=$(config::get_loadbalancer_mode)
  lb_type=$(config::get_loadbalancer_type)
  local lb_nodes
  lb_nodes="$(config::get_role_members "loadbalancer")"

  local worker_nodes control_plane_nodes
  worker_nodes="$(config::get_role_members "worker")"
  control_plane_nodes="$(config::get_role_members "control-plane")"

  if [[ "${lb_mode}" == "external" ]] || [[ "${lb_type}" == "kubexm-kh" ]] || [[ "${lb_type}" == "kubexm-kn" ]]; then
    if [[ -z "${lb_nodes}" ]]; then
      log::error "配置不一致: config.yaml 中配置了外部负载均衡器"
      log::error "           (mode: ${lb_mode}, type: ${lb_type})"
      log::error "           但 host.yaml 中未定义 loadbalancer 主机组"
      log::info  "解决方案: 在 host.yaml 中添加 loadbalancer 角色的主机"
      log::info  "         或修改 config.yaml 使用 internal 模式"
      ((errors++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
    fi
  fi

  if [[ "${lb_mode}" == "internal" ]]; then
    if [[ -z "${worker_nodes}" ]]; then
      log::error "配置不一致: 启用了 internal 负载均衡，但 host.yaml 未定义 worker 主机组"
      log::info  "解决方案: 在 host.yaml 中添加 worker 角色主机，或切换为 external/kube-vip/exists"
      ((errors++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
    fi
    if [[ "${lb_type}" != "haproxy" && "${lb_type}" != "nginx" ]]; then
      log::error "配置不一致: internal 负载均衡仅支持 haproxy 或 nginx (当前: ${lb_type})"
      ((errors++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
    fi
  fi

  if [[ "${lb_mode}" == "external" ]]; then
    if [[ "${lb_type}" != "kubexm-kh" && "${lb_type}" != "kubexm-kn" ]]; then
      log::error "配置不一致: external 负载均衡仅支持 kubexm-kh 或 kubexm-kn (当前: ${lb_type})"
      ((errors++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
    fi
  fi

  if [[ "${lb_mode}" == "kube-vip" ]]; then
    if [[ -z "${control_plane_nodes}" ]]; then
      log::error "配置不一致: kube-vip 模式需要 control-plane 主机组"
      ((errors++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
    fi
  fi

  local ntp_servers
  ntp_servers=$(config::get_ntp_servers 2>/dev/null || echo "")
  if [[ -n "${ntp_servers}" ]]; then
    local ntp_nodes
    ntp_nodes="$(config::get_role_members "ntp")"

    local server
    for server in ${ntp_servers}; do
      local server_addr
      server_addr="$(config::get_host_param "${server}" "address" 2>/dev/null || echo "")"
      if [[ -n "${server_addr}" ]]; then
        if [[ ! " ${ntp_nodes} " =~ " ${server} " ]]; then
          log::warn "NTP 服务器 ${server} 是集群节点，但未分配 ntp 角色"
        fi
      fi
    done
  fi

  local etcd_type k8s_type
  etcd_type=$(config::get_etcd_type)
  k8s_type=$(config::get_kubernetes_type)

  # kubexm+kubeadm 组合不合法
  if [[ "${k8s_type}" == "kubexm" ]] && [[ "${etcd_type}" == "kubeadm" ]]; then
    log::error "不支持的组合: kubernetes.type=kubexm 与 etcd.type=kubeadm 不兼容"
    log::info  "kubeadm etcd 堆叠需要 kubeadm 安装 K8s。请将 kubernetes.type 改为 kubeadm，或 etcd.type 改为 kubexm/exists"
    ((errors++)) || true
  fi

  if [[ "${k8s_type}" == "kubexm" ]] && [[ "${etcd_type}" == "kubexm" ]]; then
    local etcd_nodes
    etcd_nodes="$(config::get_role_members "etcd")"

    if [[ -z "${etcd_nodes}" ]]; then
      log::warn "kubexm 二进制部署模式下建议在 host.yaml 中定义独立的 etcd 主机组"
    fi
  fi

  if [[ "${etcd_type}" == "exists" ]]; then
    local external_endpoints
    external_endpoints=$(config::get_etcd_external_endpoints 2>/dev/null || echo "")
    if [[ -z "${external_endpoints}" ]]; then
      log::error "配置不一致: etcd.type=exists 但未配置 spec.etcd.external_endpoints"
      log::info  "解决方案: 在 config.yaml 中设置 spec.etcd.external_endpoints (逗号分隔) 指向外部etcd"
      ((errors++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
    fi
  fi

  local service_cidr pod_cidr
  service_cidr=$(config::get_service_cidr 2>/dev/null || defaults::get_service_cidr)
  pod_cidr=$(config::get_pod_cidr 2>/dev/null || defaults::get_pod_cidr)

  if [[ "${service_cidr}" == "${pod_cidr}" ]]; then
    log::error "配置不一致: Service CIDR 和 Pod CIDR 相同: ${service_cidr}"
    log::info  "解决方案: 请使用不同的 CIDR 范围，例如 Service: 10.96.0.0/12, Pod: 10.244.0.0/16"
    ((errors++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
  fi

  local service_prefix pod_prefix
  service_prefix="${service_cidr%%.*}"
  pod_prefix="${pod_cidr%%.*}"
  if [[ "${service_prefix}" == "${pod_prefix}" ]]; then
    log::warn "Service CIDR (${service_cidr}) 和 Pod CIDR (${pod_cidr}) 使用相同的网络前缀，请确保无重叠"
  fi

  local mode
  mode=$(config::get_mode 2>/dev/null || echo "online")
  if [[ "${mode}" == "offline" ]] && [[ "${registry_enabled}" == "true" ]]; then
    local registry_host registry_port
    registry_host=$(config::get_registry_host 2>/dev/null || echo "")
    registry_port=$(config::get_registry_port 2>/dev/null || echo "5000")

    if [[ -n "${registry_host}" ]]; then
      log::info "检查 Registry 连通性: ${registry_host}:${registry_port}"
      if command -v nc &>/dev/null; then
        if ! timeout 5 nc -zv "${registry_host}" "${registry_port}" &>/dev/null; then
          log::warn "无法连接到 Registry ${registry_host}:${registry_port}"
          log::warn "离线部署时请确保 Registry 服务已启动"
        fi
      else
        log::debug "nc 命令不可用，跳过 Registry 连通性检查"
      fi
    fi
  fi

  if [[ ${errors} -gt 0 ]]; then
    log::error "配置校验失败: 共 ${errors} 个错误"
    return 1
  fi

  log::info "配置校验通过"
  return 0
}

export -f config::validator::validate_consistency
