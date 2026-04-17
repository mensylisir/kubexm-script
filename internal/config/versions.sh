#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Version Management
# ==============================================================================
# Kubernetes版本与组件版本映射管理
# 根据Kubernetes版本动态获取对应组件版本
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

# ==============================================================================
# Kubernetes版本映射
# ==============================================================================

# Kubernetes版本支持的组件版本映射
if [[ -z "${K8S_SUPPORTED_VERSIONS+x}" ]]; then
declare -A K8S_SUPPORTED_VERSIONS=(
  [v1.24]="1.24.0"
  [v1.25]="1.25.0"
  [v1.26]="1.26.0"
  [v1.27]="1.27.0"
  [v1.28]="1.28.0"
  [v1.29]="1.29.0"
  [v1.30]="1.30.0"
  [v1.31]="1.31.0"
  [v1.32]="1.32.0"
  [v1.33]="1.33.0"
  [v1.34]="1.34.0"
  [v1.35]="1.35.0"
)
fi

# CNI插件版本映射 (每个Kubernetes版本对应的CNI插件版本)
if [[ -z "${CNI_VERSIONS+x}" ]]; then
declare -A CNI_VERSIONS=(
  [v1.24]="1.3.0"
  [v1.25]="1.3.0"
  [v1.26]="1.3.0"
  [v1.27]="1.4.0"
  [v1.28]="1.4.0"
  [v1.29]="1.4.0"
  [v1.30]="1.4.0"
  [v1.31]="1.4.0"
  [v1.32]="1.4.0"
  [v1.33]="1.4.0"
  [v1.34]="1.5.0"
  [v1.35]="1.5.0"
)
fi

# Containerd版本映射
if [[ -z "${CONTAINERD_VERSIONS+x}" ]]; then
declare -A CONTAINERD_VERSIONS=(
  [v1.24]="1.6.20"
  [v1.25]="1.6.20"
  [v1.26]="1.6.20"
  [v1.27]="1.7.2"
  [v1.28]="1.7.8"
  [v1.29]="1.7.13"
  [v1.30]="1.7.13"
  [v1.31]="1.7.13"
  [v1.32]="1.7.13"
  [v1.33]="1.7.14"
  [v1.34]="1.7.14"
  [v1.35]="1.7.15"
)
fi

# CRI-O版本映射
if [[ -z "${CRIO_VERSIONS+x}" ]]; then
declare -A CRIO_VERSIONS=(
  [v1.24]="1.24.0"
  [v1.25]="1.25.0"
  [v1.26]="1.26.0"
  [v1.27]="1.27.0"
  [v1.28]="1.28.0"
  [v1.29]="1.29.0"
  [v1.30]="1.30.0"
  [v1.31]="1.31.0"
  [v1.32]="1.32.0"
  [v1.33]="1.33.0"
  [v1.34]="1.34.0"
  [v1.35]="1.35.0"
)
fi

# Docker版本映射
if [[ -z "${DOCKER_VERSIONS+x}" ]]; then
declare -A DOCKER_VERSIONS=(
  [v1.24]="24.0.0"
  [v1.25]="24.0.0"
  [v1.26]="24.0.0"
  [v1.27]="24.0.2"
  [v1.28]="24.0.5"
  [v1.29]="24.0.7"
  [v1.30]="24.0.7"
  [v1.31]="24.0.7"
  [v1.32]="24.0.7"
  [v1.33]="24.0.9"
  [v1.34]="24.0.9"
  [v1.35]="24.0.9"
)
fi

# CRI-Dockerd版本映射
if [[ -z "${CRI_DOCKERD_VERSIONS+x}" ]]; then
declare -A CRI_DOCKERD_VERSIONS=(
  [v1.24]="0.3.0"
  [v1.25]="0.3.0"
  [v1.26]="0.3.0"
  [v1.27]="0.3.2"
  [v1.28]="0.3.3"
  [v1.29]="0.3.4"
  [v1.30]="0.3.6"
  [v1.31]="0.3.7"
  [v1.32]="0.3.9"
  [v1.33]="0.3.10"
  [v1.34]="0.3.10"
  [v1.35]="0.3.11"
)
fi

# Podman版本映射
if [[ -z "${PODMAN_VERSIONS+x}" ]]; then
declare -A PODMAN_VERSIONS=(
  [v1.24]="4.4.0"
  [v1.25]="4.4.0"
  [v1.26]="4.4.0"
  [v1.27]="4.5.0"
  [v1.28]="4.6.0"
  [v1.29]="4.7.0"
  [v1.30]="4.8.0"
  [v1.31]="4.9.0"
  [v1.32]="4.9.0"
  [v1.33]="5.0.0"
  [v1.34]="5.1.0"
  [v1.35]="5.2.0"
)
fi

# Conmon版本映射
if [[ -z "${CONMON_VERSIONS+x}" ]]; then
declare -A CONMON_VERSIONS=(
  [v1.24]="2.1.6"
  [v1.25]="2.1.6"
  [v1.26]="2.1.7"
  [v1.27]="2.1.8"
  [v1.28]="2.1.8"
  [v1.29]="2.1.9"
  [v1.30]="2.1.10"
  [v1.31]="2.1.10"
  [v1.32]="2.1.10"
  [v1.33]="2.1.11"
  [v1.34]="2.1.12"
  [v1.35]="2.1.12"
)
fi

# Runc版本映射
if [[ -z "${RUNC_VERSIONS+x}" ]]; then
declare -A RUNC_VERSIONS=(
  [v1.24]="1.1.5"
  [v1.25]="1.1.5"
  [v1.26]="1.1.5"
  [v1.27]="1.1.8"
  [v1.28]="1.1.9"
  [v1.29]="1.1.10"
  [v1.30]="1.1.10"
  [v1.31]="1.1.10"
  [v1.32]="1.1.12"
  [v1.33]="1.1.12"
  [v1.34]="1.1.12"
  [v1.35]="1.1.13"
)
fi

# Crictl版本映射
if [[ -z "${CRICTL_VERSIONS+x}" ]]; then
declare -A CRICTL_VERSIONS=(
  [v1.24]="1.25.0"
  [v1.25]="1.25.0"
  [v1.26]="1.26.0"
  [v1.27]="1.27.0"
  [v1.28]="1.27.0"
  [v1.29]="1.28.0"
  [v1.30]="1.28.0"
  [v1.31]="1.28.0"
  [v1.32]="1.28.0"
  [v1.33]="1.29.0"
  [v1.34]="1.29.0"
  [v1.35]="1.30.0"
)
fi

# Etcd版本映射 (Kubernetes版本对应的etcd二进制版本)
if [[ -z "${ETCD_VERSIONS+x}" ]]; then
declare -A ETCD_VERSIONS=(
  [v1.24]="3.5.6"
  [v1.25]="3.5.6"
  [v1.26]="3.5.8"
  [v1.27]="3.5.10"
  [v1.28]="3.5.10"
  [v1.29]="3.5.12"
  [v1.30]="3.5.12"
  [v1.31]="3.5.12"
  [v1.32]="3.5.13"
  [v1.33]="3.5.13"
  [v1.34]="3.5.15"
  [v1.35]="3.5.16"
)
fi

# Calico版本映射
if [[ -z "${CALICO_VERSIONS+x}" ]]; then
declare -A CALICO_VERSIONS=(
  [v1.24]="3.26.1"
  [v1.25]="3.26.1"
  [v1.26]="3.26.1"
  [v1.27]="3.27.0"
  [v1.28]="3.27.0"
  [v1.29]="3.27.2"
  [v1.30]="3.27.2"
  [v1.31]="3.27.2"
  [v1.32]="3.27.3"
  [v1.33]="3.27.3"
  [v1.34]="3.28.0"
  [v1.35]="3.28.1"
)
fi

# Flannel版本映射
if [[ -z "${FLANNEL_VERSIONS+x}" ]]; then
declare -A FLANNEL_VERSIONS=(
  [v1.24]="0.21.5"
  [v1.25]="0.21.5"
  [v1.26]="0.22.2"
  [v1.27]="0.23.0"
  [v1.28]="0.24.0"
  [v1.29]="0.24.0"
  [v1.30]="0.24.0"
  [v1.31]="0.24.0"
  [v1.32]="0.24.0"
  [v1.33]="0.24.0"
  [v1.34]="0.25.0"
  [v1.35]="0.25.1"
)
fi

# Cilium版本映射
if [[ -z "${CILIUM_VERSIONS+x}" ]]; then
declare -A CILIUM_VERSIONS=(
  [v1.24]="1.14.1"
  [v1.25]="1.14.2"
  [v1.26]="1.14.3"
  [v1.27]="1.14.5"
  [v1.28]="1.14.6"
  [v1.29]="1.15.1"
  [v1.30]="1.15.3"
  [v1.31]="1.15.4"
  [v1.32]="1.15.4"
  [v1.33]="1.15.5"
  [v1.34]="1.16.0"
  [v1.35]="1.16.1"
)
fi

# CoreDNS版本映射
if [[ -z "${COREDNS_VERSIONS+x}" ]]; then
declare -A COREDNS_VERSIONS=(
  [v1.24]="v1.10.1"
  [v1.25]="v1.10.1"
  [v1.26]="v1.10.1"
  [v1.27]="v1.11.1"
  [v1.28]="v1.11.1"
  [v1.29]="v1.11.1"
  [v1.30]="v1.11.1"
  [v1.31]="v1.11.1"
  [v1.32]="v1.11.1"
  [v1.33]="v1.11.3"
  [v1.34]="v1.11.3"
  [v1.35]="v1.11.3"
)
fi

# Helm版本映射
if [[ -z "${HELM_VERSIONS+x}" ]]; then
declare -A HELM_VERSIONS=(
  [v1.24]="3.11.3"
  [v1.25]="3.11.3"
  [v1.26]="3.12.0"
  [v1.27]="3.12.0"
  [v1.28]="3.12.2"
  [v1.29]="3.12.3"
  [v1.30]="3.12.3"
  [v1.31]="3.12.3"
  [v1.32]="3.13.1"
  [v1.33]="3.13.2"
  [v1.34]="3.14.0"
  [v1.35]="3.14.1"
)
fi

# NodeLocalDNS版本映射
if [[ -z "${NODELOCALDNS_VERSIONS+x}" ]]; then
declare -A NODELOCALDNS_VERSIONS=(
  [v1.24]="1.22.28"
  [v1.25]="1.22.28"
  [v1.26]="1.22.28"
  [v1.27]="1.22.28"
  [v1.28]="1.22.28"
  [v1.29]="1.22.28"
  [v1.30]="1.22.28"
  [v1.31]="1.22.28"
  [v1.32]="1.22.28"
  [v1.33]="1.22.28"
  [v1.34]="1.22.28"
  [v1.35]="1.22.28"
)
fi

# Metrics Server版本映射
if [[ -z "${METRICS_SERVER_VERSIONS+x}" ]]; then
declare -A METRICS_SERVER_VERSIONS=(
  [v1.24]="3.8.3"
  [v1.25]="3.8.3"
  [v1.26]="3.11.0"
  [v1.27]="3.11.0"
  [v1.28]="3.11.0"
  [v1.29]="3.11.0"
  [v1.30]="3.13.0"
  [v1.31]="3.13.0"
  [v1.32]="3.13.0"
  [v1.33]="3.13.0"
  [v1.34]="3.13.0"
  [v1.35]="3.13.0"
)
fi

# Ingress NGINX版本映射
if [[ -z "${INGRESS_NGINX_VERSIONS+x}" ]]; then
declare -A INGRESS_NGINX_VERSIONS=(
  [v1.24]="4.7.0"
  [v1.25]="4.7.0"
  [v1.26]="4.8.0"
  [v1.27]="4.8.0"
  [v1.28]="4.8.0"
  [v1.29]="4.9.0"
  [v1.30]="4.11.0"
  [v1.31]="4.11.0"
  [v1.32]="4.11.0"
  [v1.33]="4.11.0"
  [v1.34]="4.11.0"
  [v1.35]="4.11.0"
)
fi

# Traefik版本映射
if [[ -z "${TRAEFIK_VERSIONS+x}" ]]; then
declare -A TRAEFIK_VERSIONS=(
  [v1.24]="24.0.0"
  [v1.25]="24.0.0"
  [v1.26]="25.0.0"
  [v1.27]="25.0.0"
  [v1.28]="26.0.0"
  [v1.29]="26.0.0"
  [v1.30]="27.0.0"
  [v1.31]="27.0.0"
  [v1.32]="30.1.0"
  [v1.33]="30.1.0"
  [v1.34]="30.1.0"
  [v1.35]="30.1.0"
)
fi

# Cert Manager版本映射
if [[ -z "${CERT_MANAGER_VERSIONS+x}" ]]; then
declare -A CERT_MANAGER_VERSIONS=(
  [v1.24]="1.12.0"
  [v1.25]="1.12.0"
  [v1.26]="1.13.0"
  [v1.27]="1.13.0"
  [v1.28]="1.13.0"
  [v1.29]="1.14.0"
  [v1.30]="1.14.0"
  [v1.31]="1.14.0"
  [v1.32]="1.14.0"
  [v1.33]="1.15.0"
  [v1.34]="1.15.0"
  [v1.35]="1.15.0"
)
fi

# External DNS版本映射
if [[ -z "${EXTERNAL_DNS_VERSIONS+x}" ]]; then
declare -A EXTERNAL_DNS_VERSIONS=(
  [v1.24]="1.13.0"
  [v1.25]="1.13.0"
  [v1.26]="1.13.1"
  [v1.27]="1.13.1"
  [v1.28]="1.13.1"
  [v1.29]="1.14.0"
  [v1.30]="1.14.0"
  [v1.31]="1.14.0"
  [v1.32]="1.14.0"
  [v1.33]="1.14.0"
  [v1.34]="1.14.0"
  [v1.35]="1.14.0"
)
fi

# Istio版本映射
if [[ -z "${ISTIO_VERSIONS+x}" ]]; then
declare -A ISTIO_VERSIONS=(
  [v1.24]="1.18.0"
  [v1.25]="1.18.0"
  [v1.26]="1.19.0"
  [v1.27]="1.19.0"
  [v1.28]="1.20.0"
  [v1.29]="1.20.0"
  [v1.30]="1.20.1"
  [v1.31]="1.20.1"
  [v1.32]="1.20.1"
  [v1.33]="1.21.0"
  [v1.34]="1.21.0"
  [v1.35]="1.21.0"
)
fi

# Prometheus版本映射
if [[ -z "${PROMETHEUS_VERSIONS+x}" ]]; then
declare -A PROMETHEUS_VERSIONS=(
  [v1.24]="25.0.0"
  [v1.25]="25.0.0"
  [v1.26]="25.8.0"
  [v1.27]="25.8.0"
  [v1.28]="25.8.2"
  [v1.29]="25.8.2"
  [v1.30]="25.8.2"
  [v1.31]="25.8.2"
  [v1.32]="25.8.2"
  [v1.33]="25.8.2"
  [v1.34]="25.8.2"
  [v1.35]="25.8.2"
)
fi

# Grafana版本映射
if [[ -z "${GRAFANA_VERSIONS+x}" ]]; then
declare -A GRAFANA_VERSIONS=(
  [v1.24]="6.58.0"
  [v1.25]="6.58.0"
  [v1.26]="6.58.4"
  [v1.27]="6.58.4"
  [v1.28]="6.58.4"
  [v1.29]="6.58.4"
  [v1.30]="6.58.4"
  [v1.31]="6.58.4"
  [v1.32]="6.58.4"
  [v1.33]="6.58.4"
  [v1.34]="6.58.4"
  [v1.35]="6.58.4"
)
fi

# Longhorn版本映射
if [[ -z "${LONGHORN_VERSIONS+x}" ]]; then
declare -A LONGHORN_VERSIONS=(
  [v1.24]="1.5.0"
  [v1.25]="1.5.0"
  [v1.26]="1.5.3"
  [v1.27]="1.5.3"
  [v1.28]="1.5.3"
  [v1.29]="1.5.3"
  [v1.30]="1.5.3"
  [v1.31]="1.5.3"
  [v1.32]="1.5.3"
  [v1.33]="1.5.3"
  [v1.34]="1.5.3"
  [v1.35]="1.5.3"
)
fi

# OpenEBS版本映射
if [[ -z "${OPENEBS_VERSIONS+x}" ]]; then
declare -A OPENEBS_VERSIONS=(
  [v1.24]="3.6.0"
  [v1.25]="3.6.0"
  [v1.26]="3.6.0"
  [v1.27]="3.6.0"
  [v1.28]="3.6.0"
  [v1.29]="3.6.0"
  [v1.30]="3.6.0"
  [v1.31]="3.6.0"
  [v1.32]="3.6.0"
  [v1.33]="3.6.0"
  [v1.34]="3.6.0"
  [v1.35]="3.6.0"
)
fi

# Local Path Provisioner版本映射
if [[ -z "${LOCAL_PATH_VERSIONS+x}" ]]; then
declare -A LOCAL_PATH_VERSIONS=(
  [v1.24]="0.0.24"
  [v1.25]="0.0.24"
  [v1.26]="0.0.26"
  [v1.27]="0.0.26"
  [v1.28]="0.0.26"
  [v1.29]="0.0.34"
  [v1.30]="0.0.34"
  [v1.31]="0.0.34"
  [v1.32]="0.0.34"
  [v1.33]="0.0.34"
  [v1.34]="0.0.34"
  [v1.35]="0.0.34"
)
fi

# Kubernetes Dashboard版本映射 (Helm Chart Version)
if [[ -z "${DASHBOARD_VERSIONS+x}" ]]; then
declare -A DASHBOARD_VERSIONS=(
  [v1.24]="6.0.8"
  [v1.25]="6.0.8"
  [v1.26]="6.0.8"
  [v1.27]="6.0.8"
  [v1.28]="6.0.8"
  [v1.29]="6.0.8"
  [v1.30]="6.0.8"
  [v1.31]="6.0.8"
  [v1.32]="6.0.8"
  [v1.33]="6.0.8"
  [v1.34]="6.0.8"
  [v1.35]="6.0.8"
)
fi

# 系统包版本映射
if [[ -z "${SYSTEM_PACKAGE_VERSIONS+x}" ]]; then
declare -A SYSTEM_PACKAGE_VERSIONS=(
  # LoadBalancer包版本
  [haproxy]="2.8"
  [nginx]="1.25"
  [keepalived]="2.3"
  [kube-vip]="0.8.0"
)
fi

# Skopeo版本映射 (用于镜像操作)
if [[ -z "${SKOPEO_VERSIONS+x}" ]]; then
declare -A SKOPEO_VERSIONS=(
  [v1.24]="1.13.0"
  [v1.25]="1.13.0"
  [v1.26]="1.13.1"
  [v1.27]="1.13.1"
  [v1.28]="1.14.0"
  [v1.29]="1.14.0"
  [v1.30]="1.14.1"
  [v1.31]="1.14.1"
  [v1.32]="1.14.2"
  [v1.33]="1.14.3"
  [v1.34]="1.15.0"
  [v1.35]="1.15.1"
)
fi

# ==============================================================================
# 版本获取函数
# ==============================================================================

#######################################
# 标准化Kubernetes版本号 (提取主版本)
# Arguments:
#   $1 - Kubernetes版本 (v1.32.4, v1.32, 1.32.4, 1.32 等)
# Returns:
#   主版本号 (v1.32)
#######################################
versions::normalize_k8s_version() {
  local k8s_version="$1"
  # 添加v前缀（如果不存在）
  if [[ ! "$k8s_version" =~ ^v ]]; then
    k8s_version="v${k8s_version}"
  fi
  # 提取主版本号 (v1.x.y -> v1.x)
  echo "${k8s_version}" | sed 's/^\(v[0-9]\+\.[0-9]\+\)\..*/\1/'
}

#######################################
# 获取指定组件的版本
# Arguments:
#   $1 - 组件名称 (cni, containerd, crio, runc, crictl, etcd, calico, flannel, cilium, helm, metrics-server, ingress-nginx)
#   $2 - Kubernetes版本 (v1.24, v1.25, v1.32.4, 等，支持小版本)
# Returns:
#   组件版本号
#######################################
versions::get() {
  local component="$1"
  local k8s_version="$2"

  # 标准化版本号，支持小版本
  local normalized_version
  normalized_version=$(versions::normalize_k8s_version "$k8s_version")

  # 验证Kubernetes主版本是否支持（允许小版本）
  if [[ -z "${K8S_SUPPORTED_VERSIONS[$normalized_version]:-}" ]]; then
    # 尝试从用户输入提取主版本
    local input_version="$k8s_version"
    if [[ ! "$input_version" =~ ^v ]]; then
      input_version="v${input_version}"
    fi
    local input_major=$(echo "$input_version" | sed 's/^\(v[0-9]\+\.[0-9]\+\)\..*/\1/')
    if [[ -z "${K8S_SUPPORTED_VERSIONS[$input_major]:-}" ]]; then
      echo "WARNING: Unsupported Kubernetes version: $k8s_version (major: $input_major)" >&2
      # 不返回错误，使用输入的版本号继续
    fi
  fi

  # 根据组件类型返回对应版本（小版本使用对应主版本的组件版本）
  local component_version=""
  case "${component}" in
    cni) component_version="${CNI_VERSIONS[$normalized_version]:-}" ;;
    containerd) component_version="${CONTAINERD_VERSIONS[$normalized_version]:-}" ;;
    crio) component_version="${CRIO_VERSIONS[$normalized_version]:-}" ;;
    docker) component_version="${DOCKER_VERSIONS[$normalized_version]:-}" ;;
    cri_dockerd) component_version="${CRI_DOCKERD_VERSIONS[$normalized_version]:-}" ;;
    podman) component_version="${PODMAN_VERSIONS[$normalized_version]:-}" ;;
    conmon) component_version="${CONMON_VERSIONS[$normalized_version]:-}" ;;
    runc) component_version="${RUNC_VERSIONS[$normalized_version]:-}" ;;
    crictl) component_version="${CRICTL_VERSIONS[$normalized_version]:-}" ;;
    etcd) component_version="${ETCD_VERSIONS[$normalized_version]:-}" ;;
    calico) component_version="${CALICO_VERSIONS[$normalized_version]:-}" ;;
    flannel) component_version="${FLANNEL_VERSIONS[$normalized_version]:-}" ;;
    cilium) component_version="${CILIUM_VERSIONS[$normalized_version]:-}" ;;
    coredns) component_version="${COREDNS_VERSIONS[$normalized_version]:-}" ;;
    helm) component_version="${HELM_VERSIONS[$normalized_version]:-}" ;;
    metrics-server) component_version="${METRICS_SERVER_VERSIONS[$normalized_version]:-}" ;;
    ingress-nginx) component_version="${INGRESS_NGINX_VERSIONS[$normalized_version]:-}" ;;
    traefik) component_version="${TRAEFIK_VERSIONS[$normalized_version]:-}" ;;
    cert-manager) component_version="${CERT_MANAGER_VERSIONS[$normalized_version]:-}" ;;
    external-dns) component_version="${EXTERNAL_DNS_VERSIONS[$normalized_version]:-}" ;;
    istio-base) component_version="${ISTIO_VERSIONS[$normalized_version]:-}" ;;
    istio-istiod|istiod) component_version="${ISTIO_VERSIONS[$normalized_version]:-}" ;;
    prometheus) component_version="${PROMETHEUS_VERSIONS[$normalized_version]:-}" ;;
    grafana) component_version="${GRAFANA_VERSIONS[$normalized_version]:-}" ;;
    longhorn) component_version="${LONGHORN_VERSIONS[$normalized_version]:-}" ;;
    openebs) component_version="${OPENEBS_VERSIONS[$normalized_version]:-}" ;;
    local-path-provisioner) component_version="${LOCAL_PATH_VERSIONS[$normalized_version]:-}" ;;
    kubernetes-dashboard) component_version="${DASHBOARD_VERSIONS[$normalized_version]:-}" ;;
    nodelocaldns) component_version="${NODELOCALDNS_VERSIONS[$normalized_version]:-}" ;;
    skopeo) component_version="${SKOPEO_VERSIONS[$normalized_version]:-}" ;;
    # 系统包版本（不依赖Kubernetes版本）
    haproxy) component_version="${SYSTEM_PACKAGE_VERSIONS[haproxy]:-}" ;;
    nginx) component_version="${SYSTEM_PACKAGE_VERSIONS[nginx]:-}" ;;
    keepalived) component_version="${SYSTEM_PACKAGE_VERSIONS[keepalived]:-}" ;;
    kube-vip) component_version="${SYSTEM_PACKAGE_VERSIONS[kube-vip]:-}" ;;
    *)
      echo "ERROR: Unknown component: $component" >&2
      return 1
      ;;
  esac

  # 如果组件版本为空，尝试从输入版本提取主版本再试
  if [[ -z "$component_version" ]]; then
    local input_version="$k8s_version"
    if [[ ! "$input_version" =~ ^v ]]; then
      input_version="v${input_version}"
    fi
    local input_major=$(echo "$input_version" | sed 's/^\(v[0-9]\+\.[0-9]\+\)\..*/\1/')

    case "${component}" in
      cni) component_version="${CNI_VERSIONS[$input_major]:-}" ;;
      containerd) component_version="${CONTAINERD_VERSIONS[$input_major]:-}" ;;
      crio) component_version="${CRIO_VERSIONS[$input_major]:-}" ;;
      docker) component_version="${DOCKER_VERSIONS[$input_major]:-}" ;;
      cri_dockerd) component_version="${CRI_DOCKERD_VERSIONS[$input_major]:-}" ;;
      podman) component_version="${PODMAN_VERSIONS[$input_major]:-}" ;;
      conmon) component_version="${CONMON_VERSIONS[$input_major]:-}" ;;
      runc) component_version="${RUNC_VERSIONS[$input_major]:-}" ;;
      crictl) component_version="${CRICTL_VERSIONS[$input_major]:-}" ;;
      etcd) component_version="${ETCD_VERSIONS[$input_major]:-}" ;;
      calico) component_version="${CALICO_VERSIONS[$input_major]:-}" ;;
      flannel) component_version="${FLANNEL_VERSIONS[$input_major]:-}" ;;
      cilium) component_version="${CILIUM_VERSIONS[$input_major]:-}" ;;
      coredns) component_version="${COREDNS_VERSIONS[$input_major]:-}" ;;
      helm) component_version="${HELM_VERSIONS[$input_major]:-}" ;;
      metrics-server) component_version="${METRICS_SERVER_VERSIONS[$input_major]:-}" ;;
      ingress-nginx) component_version="${INGRESS_NGINX_VERSIONS[$input_major]:-}" ;;
      traefik) component_version="${TRAEFIK_VERSIONS[$input_major]:-}" ;;
      cert-manager) component_version="${CERT_MANAGER_VERSIONS[$input_major]:-}" ;;
      external-dns) component_version="${EXTERNAL_DNS_VERSIONS[$input_major]:-}" ;;
      istio-base) component_version="${ISTIO_VERSIONS[$input_major]:-}" ;;
      istio-istiod|istiod) component_version="${ISTIO_VERSIONS[$input_major]:-}" ;;
      prometheus) component_version="${PROMETHEUS_VERSIONS[$input_major]:-}" ;;
      grafana) component_version="${GRAFANA_VERSIONS[$input_major]:-}" ;;
      longhorn) component_version="${LONGHORN_VERSIONS[$input_major]:-}" ;;
      openebs) component_version="${OPENEBS_VERSIONS[$input_major]:-}" ;;
      local-path-provisioner) component_version="${LOCAL_PATH_VERSIONS[$input_major]:-}" ;;
      kubernetes-dashboard) component_version="${DASHBOARD_VERSIONS[$input_major]:-}" ;;
      nodelocaldns) component_version="${NODELOCALDNS_VERSIONS[$input_major]:-}" ;;
      skopeo) component_version="${SKOPEO_VERSIONS[$input_major]:-}" ;;
      # 系统包版本（不依赖Kubernetes版本）
      haproxy) component_version="${SYSTEM_PACKAGE_VERSIONS[haproxy]:-}" ;;
      nginx) component_version="${SYSTEM_PACKAGE_VERSIONS[nginx]:-}" ;;
      keepalived) component_version="${SYSTEM_PACKAGE_VERSIONS[keepalived]:-}" ;;
      kube-vip) component_version="${SYSTEM_PACKAGE_VERSIONS[kube-vip]:-}" ;;
    esac
  fi

  echo "$component_version"
}

#######################################
# 获取CNI插件的下载URL
# Arguments:
#   $1 - 架构 (amd64, arm64)
#   $2 - CNI版本
# Returns:
#   下载URL
#######################################
versions::get_cni_download_url() {
  local arch="$1"
  local cni_version="$2"

  echo "https://github.com/containernetworking/plugins/releases/download/v${cni_version}/cni-plugins-linux-${arch}-v${cni_version}.tgz"
}

#######################################
# 获取Calico的下载URL
# Arguments:
#   $1 - Calico版本
# Returns:
#   下载URL
#######################################
versions::get_calico_url() {
  local calico_version="$1"
  echo "https://raw.githubusercontent.com/projectcalico/calico/${calico_version}/manifests/calico.yaml"
}

#######################################
# 获取 Calicoctl 下载 URL
# Arguments:
#   $1 - 架构 (amd64/arm64)
#   $2 - Calico版本
# Returns:
#   下载URL
#######################################
versions::get_calicoctl_url() {
  local arch="$1"
  local calico_version="$2"
  echo "https://github.com/projectcalico/calico/releases/download/v${calico_version}/calicoctl-linux-${arch}"
}

#######################################
# 获取Calico镜像标签
# Arguments:
#   $1 - Calico版本 (如 v3.27.0)
# Returns:
#   Docker镜像标签 (如 release-v3.27)
#######################################
versions::get_calico_tag() {
  local calico_version="$1"
  # 将版本号转换为 Docker 标签格式 (3.27.0 -> release-v3.27)
  echo "release-v${calico_version%.*}"
}

#######################################
# 获取Flannel的下载URL
# Arguments:
#   $1 - Flannel版本
# Returns:
#   下载URL
#######################################
versions::get_flannel_url() {
  local flannel_version="$1"
  echo "https://github.com/flannel-io/flannel/releases/download/${flannel_version}/kube-flannel.yml"
}

#######################################
# 获取 Containerd 下载 URL
#######################################
versions::get_containerd_url() {
  local arch="$1"
  local containerd_version="$2"
  echo "https://github.com/containerd/containerd/releases/download/v${containerd_version}/containerd-${containerd_version}-linux-${arch}.tar.gz"
}

#######################################
# 获取 CRI-O 下载 URL
#######################################
versions::get_crio_url() {
  local arch="$1"
  local crio_version="$2"
  echo "https://storage.googleapis.com/cri-o/artifacts/cri-o-${crio_version}.${arch}.tar.gz"
}

#######################################
# 获取 Docker 下载 URL
#######################################
versions::get_docker_url() {
  local arch="$1"
  local docker_version="$2"
  echo "https://download.docker.com/linux/static/stable/${arch}/docker-${docker_version}.tgz"
}

#######################################
# 获取 Runc 下载 URL
#######################################
versions::get_runc_url() {
  local arch="$1"
  local runc_version="$2"
  echo "https://github.com/opencontainers/runc/releases/download/v${runc_version}/runc.${arch}"
}

#######################################
# 获取 Crictl 下载 URL
#######################################
versions::get_crictl_url() {
  local arch="$1"
  local crictl_version="$2"
  echo "https://github.com/kubernetes-sigs/cri-tools/releases/download/v${crictl_version}/crictl-v${crictl_version}-linux-${arch}.tar.gz"
}

#######################################
# 获取 Helm 下载 URL
#######################################
versions::get_helm_url() {
  local arch="$1"
  local helm_version="$2"
  echo "https://get.helm.sh/helm-v${helm_version}-linux-${arch}.tar.gz"
}

#######################################
# 获取 Etcd 下载 URL
#######################################
versions::get_etcd_url() {
  local arch="$1"
  local etcd_version="$2"
  echo "https://github.com/etcd-io/etcd/releases/download/v${etcd_version}/etcd-v${etcd_version}-linux-${arch}.tar.gz"
}

#######################################
# 获取 Kubernetes 二进制下载 URL
#######################################
versions::get_k8s_binary_url() {
  local arch="$1"
  local k8s_version="$2"
  local component="$3"
  echo "https://dl.k8s.io/${k8s_version}/bin/linux/${arch}/${component}"
}

#######################################
# 获取 CRI-Dockerd 下载 URL
#######################################
versions::get_cri_dockerd_url() {
  local arch="$1"
  local cri_dockerd_version="$2"
  echo "https://github.com/Mirantis/cri-dockerd/releases/download/v${cri_dockerd_version}/cri-dockerd-${cri_dockerd_version}.linux-${arch}.tar.gz"
}

#######################################
# 获取 Conmon 下载 URL
#######################################
versions::get_conmon_url() {
  local arch="$1"
  local conmon_version="$2"
  echo "https://github.com/containers/conmon/releases/download/v${conmon_version}/conmon_${conmon_version}.${arch}"
}

#######################################
# 验证Kubernetes版本是否支持
# Arguments:
#   $1 - Kubernetes版本
# Returns:
#   0 支持, 1 不支持
#######################################
versions::validate_k8s_version() {
  local k8s_version="$1"

  if [[ -z "${K8S_SUPPORTED_VERSIONS[$k8s_version]:-}" ]]; then
    return 1
  fi

  return 0
}

#######################################
# 获取支持的Kubernetes版本列表
# Returns:
#   支持的版本列表 (空格分隔)
#######################################
versions::get_supported_versions() {
  echo "${!K8S_SUPPORTED_VERSIONS[@]}" | tr ' ' '\n' | sort -V
}

#######################################
# 显示版本映射信息
# Arguments:
#   $1 - Kubernetes版本
# Returns:
#   无 (输出到stdout)
#######################################
versions::show_version_mapping() {
  local k8s_version="$1"

  if ! versions::validate_k8s_version "$k8s_version"; then
    echo "ERROR: Unsupported Kubernetes version: $k8s_version" >&2
    return 1
  fi

  echo "Kubernetes Version: $k8s_version"
  echo "  CNI Plugins: $(versions::get "cni" "$k8s_version")"
  echo "  Containerd: $(versions::get "containerd" "$k8s_version")"
  echo "  CRI-O: $(versions::get "crio" "$k8s_version")"
  echo "  Runc: $(versions::get "runc" "$k8s_version")"
  echo "  Crictl: $(versions::get "crictl" "$k8s_version")"
  echo "  etcd: $(versions::get "etcd" "$k8s_version")"
  echo "  Calico: $(versions::get "calico" "$k8s_version")"
  echo "  Flannel: $(versions::get "flannel" "$k8s_version")"
  echo "  Cilium: $(versions::get "cilium" "$k8s_version")"
  echo "  Helm: $(versions::get "helm" "$k8s_version")"
  echo "  Metrics Server: $(versions::get "metrics-server" "$k8s_version")"
  echo "  Ingress NGINX: $(versions::get "ingress-nginx" "$k8s_version")"
}

# 导出函数
export -f versions::normalize_k8s_version
export -f versions::get
export -f versions::get_cni_download_url
export -f versions::get_calico_url
export -f versions::get_calicoctl_url
export -f versions::get_flannel_url
export -f versions::get_containerd_url
export -f versions::get_crio_url
export -f versions::get_docker_url
export -f versions::get_runc_url
export -f versions::get_crictl_url
export -f versions::get_helm_url
export -f versions::get_etcd_url
export -f versions::get_k8s_binary_url
export -f versions::get_cri_dockerd_url
export -f versions::get_conmon_url
export -f versions::validate_k8s_version
export -f versions::get_supported_versions
export -f versions::show_version_mapping
