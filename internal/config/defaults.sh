#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Default Configuration Management
# ==============================================================================
# 提供通用的默认值管理，供所有命令使用
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

# 加载依赖
KUBEXM_SCRIPT_ROOT="${KUBEXM_SCRIPT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "${KUBEXM_SCRIPT_ROOT}/internal/logger/log.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/versions.sh"

# ==============================================================================
# 默认值定义
# ==============================================================================

# Kubernetes默认版本
DEFAULT_KUBERNETES_VERSION="v1.32.4"

# 默认 ISO 卷标
DEFAULT_ISO_LABEL="kubexm"

# 默认部署类型
DEFAULT_KUBERNETES_TYPE="kubeadm"

# 默认容器运行时
DEFAULT_RUNTIME_TYPE="containerd"

# 默认CNI插件
DEFAULT_CNI_PLUGIN="calico"

# 默认架构列表
DEFAULT_ARCH_LIST="amd64,arm64"

# 默认构建OS列表（用于ISO构建）
DEFAULT_BUILD_OS_LIST="centos7,rocky9,almalinux9,ubuntu22,debian12"

# NodeLocalDNS启用状态
DEFAULT_NODELOCALDNS_ENABLED="true"

# ==============================================================================
# SSH和远程执行默认值
# ==============================================================================

# SSH默认用户
DEFAULT_SSH_USER="root"

# SSH默认端口
DEFAULT_SSH_PORT="22"

# 命令执行默认超时（秒）
DEFAULT_COMMAND_TIMEOUT="60"

# 节点等待超时（秒）
DEFAULT_NODE_WAIT_TIMEOUT="300"

# 健康检查超时（秒）
DEFAULT_HEALTH_CHECK_TIMEOUT="60"

# ==============================================================================
# 集群操作默认值
# ==============================================================================

# 扩缩容默认操作
DEFAULT_SCALE_ACTION="scale-out"

# 健康检查类型
DEFAULT_HEALTH_CHECK_TYPE="full"

# 默认单架构
DEFAULT_ARCH="amd64"

# 默认OS类型
DEFAULT_OS_TYPE="centos"

# 证书类型 (all, kubernetes, etcd)
DEFAULT_CERT_TYPE="all"

# 轮转阶段 (all, prepare, backup, generate, distribute, restart)
DEFAULT_ROTATION_PHASE="all"

# 证书续期操作 (renew, rotate, check)
DEFAULT_RENEW_ACTION="renew"

# ==============================================================================
# 系统预配置默认值
# ==============================================================================

# 系统时区
DEFAULT_SYSTEM_TIMEZONE="Asia/Shanghai"

# 系统语言
DEFAULT_SYSTEM_LOCALE="en_US.UTF-8"

# 防火墙默认配置
DEFAULT_FIREWALL_ENABLED="false"

# NTP服务器列表
DEFAULT_NTP_SERVERS="ntp.aliyun.com,time.cloudflare.com"

# ==============================================================================
# 网络配置默认值
# ==============================================================================

# Service CIDR
DEFAULT_SERVICE_CIDR="10.96.0.0/12"

# Pod CIDR
DEFAULT_POD_CIDR="10.244.0.0/16"

# Cluster CIDR (用于某些CNI插件，通常与Pod CIDR相同)
DEFAULT_CLUSTER_CIDR="10.244.0.0/16"

# Cluster DNS IP（自动计算：Service CIDR的第一个地址+10）
DEFAULT_CLUSTER_DNS_IP="10.96.0.10"

# 集群域名
DEFAULT_CLUSTER_DOMAIN="cluster.local"

# NodeLocalDNS IP
DEFAULT_NODELOCALDNS_IP="169.254.20.10"

defaults::get_nodelocaldns_ip() { echo "${DEFAULT_NODELOCALDNS_IP}"; }

# NodePort范围
DEFAULT_NODE_PORT_RANGE="30000-32767"

# API Server 端口
DEFAULT_API_SERVER_PORT="6443"

# 默认副本数
DEFAULT_REPLICAS="1"

# 强制操作 (force delete等)
DEFAULT_FORCE="false"

# Kubernetes集群名称 (用于kubeconfig)
DEFAULT_CLUSTER_NAME="kubernetes"

# ==============================================================================
# 负载均衡器默认值
# ==============================================================================

# 负载均衡器启用状态
DEFAULT_LOADBALANCER_ENABLED="false"

# 负载均衡器模式
DEFAULT_LOADBALANCER_MODE="internal"  # external | internal | kube-vip | exists

# 负载均衡器类型
# internal: haproxy|nginx; external: kubexm-kh|kubexm-kn; special: kube-vip|exists
DEFAULT_LOADBALANCER_TYPE="haproxy"

# VIP地址
DEFAULT_VIP_ADDRESS=""

# 负载均衡器网络接口
DEFAULT_LOADBALANCER_INTERFACE="eth0"

# HAProxy 镜像版本
DEFAULT_HAPROXY_IMAGE_VERSION="2.8"

# Nginx 镜像版本
DEFAULT_NGINX_IMAGE_VERSION="1.25"

# ==============================================================================
# Registry默认值
# ==============================================================================

# Registry启用状态
DEFAULT_REGISTRY_ENABLED="false"

# Registry主机地址
DEFAULT_REGISTRY_HOST=""

# Registry端口
DEFAULT_REGISTRY_PORT="5000"

# Registry数据目录
DEFAULT_REGISTRY_DATA_DIR="/var/lib/registry"

# Registry认证启用状态
DEFAULT_REGISTRY_AUTH_ENABLED="false"

# Registry TLS启用状态
DEFAULT_REGISTRY_TLS_ENABLED="false"

# Registry CA证书路径
DEFAULT_REGISTRY_CA_CERT=""

# Registry版本
DEFAULT_REGISTRY_VERSION="2.8.3"

# ==============================================================================
# 证书管理默认值
# ==============================================================================

# 证书有效期（天）
DEFAULT_CERT_VALIDITY_DAYS="3650"

# 证书续期提前天数
DEFAULT_CERT_RENEW_DAYS_BEFORE="30"

# 证书备份目录
DEFAULT_CERT_BACKUP_DIR="/var/lib/kubexm/certs-backup"

# ==============================================================================
# Etcd默认值
# ==============================================================================

# Etcd类型
DEFAULT_ETCD_TYPE="kubeadm"  # kubeadm | kubexm | exists

# Etcd数据目录
DEFAULT_ETCD_DATA_DIR="/var/lib/etcd"

# Etcd备份启用状态
DEFAULT_ETCD_BACKUP_ENABLED="true"

# Etcd备份目录
DEFAULT_ETCD_BACKUP_DIR="/var/lib/kubexm/etcd-backup"

# Etcd备份保留天数
DEFAULT_ETCD_BACKUP_RETENTION_DAYS="7"

# Etcd备份定时任务启用状态
DEFAULT_ETCD_BACKUP_TIMER_ENABLED="true"

# ==============================================================================
# 容器运行时默认值
# ==============================================================================

# Docker启用cri-dockerd
DEFAULT_DOCKER_CRI_DOCKERD_ENABLED="false"

# CRIO conmon路径
DEFAULT_CRIO_CONMON_PATH=""

# 容器d最大并发数
DEFAULT_CONTAINERD_MAX_CONCURRENT_DOWNLOADS="10"

# ==============================================================================
# 存储默认值
# ==============================================================================

# 存储类型
DEFAULT_STORAGE_TYPE="none"  # none | nfs | iscsi | ceph | longhorn

# NFS服务器地址
DEFAULT_NFS_SERVER=""

# NFS服务器路径
DEFAULT_NFS_PATH=""

# ISCSI服务器地址
DEFAULT_ISCSI_SERVER=""

# ISCSI IQN
DEFAULT_ISCSI_IQN=""

# ==============================================================================
# CNI插件默认值
# ==============================================================================

# Calico版本
DEFAULT_CALICO_VERSION="v3.27.0"

# Flannel版本
DEFAULT_FLANNEL_VERSION="v0.24.0"

# Cilium版本
DEFAULT_CILIUM_VERSION="v1.14.5"

# --- Calico 详细默认配置 ---
DEFAULT_CALICO_NETWORK_MODE="VXLAN"
DEFAULT_CALICO_BLOCKSIZE="26"
DEFAULT_CALICO_MTU="auto"
DEFAULT_CALICO_IPIP_MODE="Never" # 禁用

# ==============================================================================
# 插件和扩展默认值
# ==============================================================================

# Ingress Controller类型
DEFAULT_INGRESS_TYPE="nginx"  # none | nginx | traefik | istio

# Ingress Controller版本 (generic fallback)
DEFAULT_INGRESS_GENERIC_VERSION="v1.9.4"

# Dashboard启用状态
DEFAULT_DASHBOARD_ENABLED="false"

# Dashboard版本
DEFAULT_DASHBOARD_VERSION="v7.0.5"

# 监控启用状态
DEFAULT_MONITORING_ENABLED="false"

# Prometheus版本
DEFAULT_PROMETHEUS_VERSION="v0.72.0"

# Grafana版本
DEFAULT_GRAFANA_VERSION="10.2.0"

# 日志系统启用状态
DEFAULT_LOGGING_ENABLED="false"

# Elasticsearch版本
DEFAULT_ELASTICSEARCH_VERSION="v8.11.0"

# Kibana版本
DEFAULT_KIBANA_VERSION="v8.11.0"

# --- Kube-Proxy 详细默认配置 ---
DEFAULT_KUBE_PROXY_MODE="ipvs"
DEFAULT_KUBE_PROXY_SCHEDULER="rr"
DEFAULT_KUBE_PROXY_STRICT_ARP="false"

# --- 存储 详细默认配置 ---
DEFAULT_STORAGE_TEMP="emptyDir"
DEFAULT_STORAGE_PERSISTENT="local-path-provisioner"

# --- 插件默认版本 ---
DEFAULT_COREDNS_VERSION="v1.11.1"
DEFAULT_METRICS_SERVER_VERSION="v0.7.1"
DEFAULT_INGRESS_NGINX_VERSION="v1.9.4"
DEFAULT_NODELOCALDNS_VERSION="v1.22.28"
DEFAULT_LOCAL_PATH_VERSION="v0.0.26"

# ==============================================================================
# 高级配置默认值
# ==============================================================================

# 自动扩缩容启用状态
DEFAULT_AUTOSCALER_ENABLED="false"

# 集群自动扩缩容最小节点数
DEFAULT_AUTOSCALER_MIN_NODES="2"

# 集群自动扩缩容最大节点数
DEFAULT_AUTOSCALER_MAX_NODES="10"

# Pod安全策略启用状态
DEFAULT_POD_SECURITY_POLICY_ENABLED="false"

# 网络策略启用状态
DEFAULT_NETWORK_POLICY_ENABLED="false"

# Pod中断预算启用状态
DEFAULT_POD_DISRUPTION_BUDGET_ENABLED="true"

# ==============================================================================
# 系统优化默认值
# ==============================================================================

# Sysctl IP转发
DEFAULT_SYSCTL_IP_FORWARD="1"

# Sysctl桥接过滤
DEFAULT_SYSCTL_BRIDGE_NF_CALL="1"

# Sysctl内存交换
DEFAULT_SYSCTL_SWAPPINESS="0"

# Sysctl邻居表阈值1
DEFAULT_SYSCTL_NEIGH_GC_THRESH1="4096"

# Sysctl邻居表阈值2
DEFAULT_SYSCTL_NEIGH_GC_THRESH2="8192"

# Sysctl邻居表阈值3
DEFAULT_SYSCTL_NEIGH_GC_THRESH3="65536"

# Sysctl连接追踪最大值
DEFAULT_SYSCTL_CONNTRACK_MAX="2097152"

# Sysctl文件句柄最大值
DEFAULT_SYSCTL_FILE_MAX="10000000"

# ==============================================================================
# 工具链默认值
# ==============================================================================

# crictl版本
DEFAULT_CRICTL_VERSION="v1.32.0"

# etcd版本
DEFAULT_ETCD_VERSION="3.5.13"

# runc版本
DEFAULT_RUNC_VERSION="1.1.12"

# containerd版本
DEFAULT_CONTAINERD_VERSION="1.7.13"

# CNI插件版本
DEFAULT_CNI_VERSION="1.4.0"

# Helm版本
DEFAULT_HELM_VERSION="3.13.2"

# Skopeo版本
DEFAULT_SKOPEO_VERSION="1.14.2"

# Conmon版本
DEFAULT_CONMON_VERSION="2.1.10"

# kube-vip版本
DEFAULT_KUBEVIP_VERSION="v0.8.0"

# kubeadm版本
DEFAULT_KUBEADM_VERSION="${DEFAULT_KUBERNETES_VERSION}"

# kubectl版本
DEFAULT_KUBECTL_VERSION="${DEFAULT_KUBERNETES_VERSION}"

# kubelet版本
DEFAULT_KUBELET_VERSION="${DEFAULT_KUBERNETES_VERSION}"

# ==============================================================================
# 获取默认值
# ==============================================================================

#######################################
# 获取默认Kubernetes版本
#######################################
defaults::get_kubernetes_version() {
  echo "${DEFAULT_KUBERNETES_VERSION}"
}

#######################################
# 获取默认Kubernetes部署类型
#######################################
defaults::get_kubernetes_type() {
  echo "${DEFAULT_KUBERNETES_TYPE}"
}

#######################################
# 获取默认容器运行时类型
#######################################
defaults::get_runtime_type() {
  echo "${DEFAULT_RUNTIME_TYPE}"
}

#######################################
# 获取默认CNI插件
#######################################
defaults::get_cni_plugin() {
  echo "${DEFAULT_CNI_PLUGIN}"
}

#######################################
# 获取默认架构列表
#######################################
defaults::get_arch_list() {
  echo "${DEFAULT_ARCH_LIST}"
}

#######################################
# 获取默认构建OS列表
#######################################
defaults::get_build_os_list() {
  echo "${DEFAULT_BUILD_OS_LIST}"
}

#######################################
# 获取默认值配置（用于manifests和create cluster）
# Arguments:
#   $1 - 集群名称（可选）
# Returns:
#   输出默认值配置到stdout
#######################################
defaults::get_default_config() {
  local cluster_name="${1:-}"

  cat << EOF
kubernetes:
  version: $(defaults::get_kubernetes_version)
  type: $(defaults::get_kubernetes_type)
runtime:
  type: $(defaults::get_runtime_type)
network:
  plugin: $(defaults::get_cni_plugin)
  service_cidr: $(defaults::get_service_cidr)
  pod_cidr: $(defaults::get_pod_cidr)
  cluster_dns_ip: $(defaults::get_cluster_dns_ip)
  cluster_domain: $(defaults::get_cluster_domain)
  node_port_range: $(defaults::get_node_port_range)
loadbalancer:
  enabled: $(defaults::get_loadbalancer_enabled)
  mode: $(defaults::get_loadbalancer_mode)
  type: $(defaults::get_loadbalancer_type)
  vip: $(defaults::get_vip_address)
  interface: $(defaults::get_loadbalancer_interface)
registry:
  enabled: $(defaults::get_registry_enabled)
  host: $(defaults::get_registry_host)
  port: $(defaults::get_registry_port)
  data_dir: $(defaults::get_registry_data_dir)
  auth_enabled: $(defaults::get_registry_auth_enabled)
  tls_enabled: $(defaults::get_registry_tls_enabled)
etcd:
  type: $(defaults::get_etcd_type)
  data_dir: $(defaults::get_etcd_data_dir)
  backup_enabled: $(defaults::get_etcd_backup_enabled)
  backup_dir: $(defaults::get_etcd_backup_dir)
  backup_retention_days: $(defaults::get_etcd_backup_retention_days)
  backup_timer_enabled: $(defaults::get_etcd_backup_timer_enabled)
certs:
  validity_days: $(defaults::get_cert_validity_days)
  renew_days_before: $(defaults::get_cert_renew_days_before)
  backup_dir: $(defaults::get_cert_backup_dir)
storage:
  type: $(defaults::get_storage_type)
  nfs_server: $(defaults::get_nfs_server)
  nfs_path: $(defaults::get_nfs_path)
  iscsi_server: $(defaults::get_iscsi_server)
  iscsi_iqn: $(defaults::get_iscsi_iqn)
addons:
  ingress:
    type: $(defaults::get_ingress_type)
    version: $(defaults::get_ingress_version)
  dashboard:
    enabled: $(defaults::get_dashboard_enabled)
    version: $(defaults::get_dashboard_version)
  monitoring:
    enabled: $(defaults::get_monitoring_enabled)
    prometheus_version: $(defaults::get_prometheus_version)
    grafana_version: $(defaults::get_grafana_version)
  logging:
    enabled: $(defaults::get_logging_enabled)
    elasticsearch_version: $(defaults::get_elasticsearch_version)
    kibana_version: $(defaults::get_kibana_version)
arch: $(defaults::get_arch_list)
EOF
}

#######################################
# 获取系统依赖包（根据条件）
# Arguments:
#   $1 - 操作系统类型 (centos7|centos8|centos9|rocky8|rocky9|alma8|alma9|ubuntu2004|ubuntu2204|ubuntu2404|debian12|uos20server|kylinv10sp3)
#   $2 - 容器运行时类型 (containerd|docker|crio|podman)
#   $3 - CNI类型 (calico|flannel|cilium)
#   $4 - 负载均衡器类型 (none|haproxy|nginx|keepalived|kube-vip)
#   $5 - 是否有外部存储 (true|false)
#   $6 - 是否有高可用 (true|false) - 默认false
# Returns:
#   系统包列表
#######################################
defaults::get_system_packages() {
  local os_type="${1:-centos7}"
  local runtime_type="${2:-containerd}"
  local cni_type="${3:-calico}"
  local lb_type="${4:-none}"
  local has_storage="${5:-false}"
  local has_ha="${6:-false}"
  local k8s_type="${7:-kubeadm}"
  local lb_mode="${8:-${lb_type}}"

  local packages=()

  # 基础系统包（所有OS都需要）
  packages+=("curl" "wget" "jq" "vim" "git" "fio" "tar" "gzip" "unzip" "expect" "sshpass" "bash-completion")

  # 容器运行时相关包
  case "$runtime_type" in
    containerd)
      packages+=("conntrack-tools" "ebtables" "ethtool" "skopeo")
      ;;
    docker)
      packages+=("conntrack-tools" "ebtables" "ethtool" "skopeo")
      ;;
    crio)
      packages+=("conntrack-tools" "ebtables" "ethtool" "skopeo" "fio" "sysbench")
      ;;
    podman)
      packages+=("conntrack-tools" "ebtables" "ethtool")
      ;;
  esac

  # CNI相关包
  case "$cni_type" in
    calico|flannel|cilium)
      packages+=("iproute2" "iptables")
      ;;
    kubeovn|hybridnet)
      packages+=("iproute2" "iptables")
      ;;
    multus)
      packages+=("iproute2" "iptables")
      ;;
  esac

  # 通用包（默认都需要）
  packages+=("chrony" "rsync" "ipvsadm"  "ipset" "socat" "htop")

  # 高可用负载均衡器包（仅在启用时安装）
  if [[ "$has_ha" == "true" ]]; then
    case "$lb_type" in
      haproxy)
        if [[ "$k8s_type" == "kubexm" ]]; then
          packages+=("haproxy")
        elif [[ "$k8s_type" == "kubeadm" ]]; then
          # 此时以静态pod的形式启动haproxy
          :
        fi
        ;;
      nginx)
        if [[ "$k8s_type" == "kubexm" ]]; then
          packages+=("nginx")
        elif [[ "$k8s_type" == "kubeadm" ]]; then
          # 此时以静态pod的形式启动nginx
          :
        fi
        ;;
      kubexm-kh)
        # External Keepalived + HAProxy
        packages+=("keepalived" "haproxy")
        ;;
      kubexm-kn)
        # External Keepalived + Nginx
        packages+=("keepalived" "nginx")
        ;;
      exists)
        # 用户提供了负载均衡，本程序无需部署
        :
        ;;
      kube-vip)
        # kube-vip runs as static pod, no system packages needed
        :
        ;;
    esac
  fi
  if [[ "$lb_mode" == "exists" ]]; then
          # 此时用户提供了负载均衡，本程序无需部署
          :
  fi

  # 存储包
  if [[ "$has_storage" == "true" ]]; then
    case "$os_type" in
      centos*|rocky*|alma*|kylin*|uos*)
        packages+=("nfs-utils" "iscsi-initiator-utils")
        ;;
      ubuntu*|debian*)
        packages+=("nfs-common" "open-iscsi")
        ;;
    esac
  fi

  # 输出包列表（去重）
  printf '%s\n' "${packages[@]}" | sort -u
}

#######################################
# 获取RPM包名
#######################################
defaults::get_rpm_package_name() {
  local pkg="$1"

  case "$pkg" in
    socat) echo "socat" ;;
    fio) echo "fio" ;;
    conntrack-tools) echo "conntrack-tools" ;;
    conntrack) echo "conntrack-tools" ;;
    ipset) echo "ipset" ;;
    ebtables) echo "ebtables" ;;
    ethtool) echo "ethtool" ;;
    ipvsadm) echo "ipvsadm" ;;
    open-iscsi) echo "iscsi-initiator-utils" ;;
    iscsi-initiator-utils) echo "iscsi-initiator-utils" ;;
    nfs) echo "nfs-utils" ;;
    nfs-utils) echo "nfs-utils" ;;
    nfs-common) echo "nfs-utils" ;;
    haproxy) echo "haproxy" ;;
    keepalived) echo "keepalived" ;;
    chrony) echo "chrony" ;;
    rsync) echo "rsync" ;;
    nginx) echo "nginx" ;;
    podman) echo "podman" ;;
    cri-o) echo "cri-o" ;;
    fio) echo "fio" ;;
    sysbench) echo "sysbench" ;;
    expect) echo "expect" ;;
    sshpass) echo "sshpass" ;;
    bash-completion) echo "bash-completion" ;;
    iproute2) echo "iproute2" ;;
    iptables) echo "iptables-services" ;;
    curl) echo "curl" ;;
    wget) echo "wget" ;;
    jq) echo "jq" ;;
    vim) echo "vim" ;;
    git) echo "git" ;;
    tar) echo "tar" ;;
    gzip) echo "gzip" ;;
    unzip) echo "unzip" ;;
    htop) echo "htop" ;;
    *) echo "$pkg" ;;
  esac
}

#######################################
# 获取DEB包名
#######################################
defaults::get_deb_package_name() {
  local pkg="$1"

  case "$pkg" in
    socat) echo "socat" ;;
    fio) echo "fio" ;;
    conntrack-tools) echo "conntrack" ;;
    conntrack) echo "conntrack" ;;
    ipset) echo "ipset" ;;
    ebtables) echo "ebtables" ;;
    ethtool) echo "ethtool" ;;
    ipvsadm) echo "ipvsadm" ;;
    open-iscsi) echo "open-iscsi" ;;
    iscsi-initiator-utils) echo "open-iscsi" ;;
    nfs) echo "nfs-common" ;;
    nfs-utils) echo "nfs-common" ;;
    nfs-common) echo "nfs-common" ;;
    haproxy) echo "haproxy" ;;
    keepalived) echo "keepalived" ;;
    chrony) echo "chrony" ;;
    rsync) echo "rsync" ;;
    nginx) echo "nginx" ;;
    podman) echo "podman" ;;
    cri-o) echo "cri-o" ;;
    fio) echo "fio" ;;
    sysbench) echo "sysbench" ;;
    expect) echo "expect" ;;
    sshpass) echo "sshpass" ;;
    bash-completion) echo "bash-completion" ;;
    iproute2) echo "iproute2" ;;
    iptables) echo "iptables" ;;
    software-properties-common) echo "software-properties-common" ;;
    apt-transport-https) echo "apt-transport-https" ;;
    ca-certificates) echo "ca-certificates" ;;
    gnupg) echo "gnupg" ;;
    lsb-release) echo "lsb-release" ;;
    curl) echo "curl" ;;
    wget) echo "wget" ;;
    jq) echo "jq" ;;
    vim) echo "vim" ;;
    git) echo "git" ;;
    tar) echo "tar" ;;
    gzip) echo "gzip" ;;
    unzip) echo "unzip" ;;
    htop) echo "htop" ;;
    *) echo "$pkg" ;;
  esac
}

#######################################
# 根据集群配置计算系统包参数
# Arguments:
#   $1 - k8s类型 (kubeadm|kubexm)
#   $2 - etcd类型 (kubeadm|kubexm)
#   $3 - master数量
#   $4 - lb是否启用 (true|false)
#   $5 - lb模式 (none|internal|external|kube-vip)
#   $6 - lb类型 (none|haproxy|nginx|kubexm-kh|kubexm-kn)
# Returns:
#   输出: lb_type has_ha
#######################################
defaults::calculate_lb_params() {
  local k8s_type="$1"
  local etcd_type="$2"
  local master_count="$3"
  local lb_enabled="$4"
  local lb_mode="$5"
  local lb_type="$6"

  # 单节点集群：不启用LB，也不安装LB相关包
  if [[ "$master_count" -eq 1 ]]; then
    echo "none false"
    return 0
  fi

  # 多节点集群：根据LB配置决定
  if [[ "$lb_enabled" == "true" ]]; then
    case "$lb_mode" in
      internal)
        # Internal模式：所有worker节点安装LB
        case "$lb_type" in
          haproxy) echo "haproxy true" ;;
          nginx) echo "nginx true" ;;
          *) echo "none false" ;;
        esac
        ;;
      external)
        # External模式：loadbalancer节点安装LB
        case "$lb_type" in
          kubexm-kh) echo "haproxy true" ;;
          kubexm-kn) echo "nginx true" ;;
          *) echo "none false" ;;
        esac
        ;;
      kube-vip)
        # Kube-vip模式：所有master节点安装keepalived
        echo "keepalived true"
        ;;
      *)
        echo "none false"
        ;;
    esac
  else
    # 未启用LB
    echo "none false"
  fi
}

# ==============================================================================
# ISO 构建专用包常量
# ==============================================================================

# ISO 基础包（所有 OS 都需要）
KUBEXM_ISO_PKG_BASE=(
    curl wget tar gzip xz
    conntrack-tools ethtool socat ebtables ipset ipvsadm
    iproute2 bash-completion openssl jq vim git
)

# ISO LB 相关包
KUBEXM_ISO_PKG_HAPROXY=(haproxy)
KUBEXM_ISO_PKG_NGINX=(nginx)
KUBEXM_ISO_PKG_KEEPALIVED=(keepalived)

# ISO Storage addon 相关包
KUBEXM_ISO_PKG_NFS_RPM=(nfs-utils)
KUBEXM_ISO_PKG_NFS_DEB=(nfs-common)
KUBEXM_ISO_PKG_ISCSI_RPM=(iscsi-initiator-utils)
KUBEXM_ISO_PKG_ISCSI_DEB=(open-iscsi)

# ISO CNI 依赖包
KUBEXM_ISO_PKG_CILIUM_RPM=(iproute2)
KUBEXM_ISO_PKG_CILIUM_DEB=(iproute)

#######################################
# 获取 ISO 构建包列表（智能推断）
# Arguments:
#   $1 - OS 类型 (centos7|rocky9|ubuntu22|debian12|kylin10|uos20|anolis9|fedora42|...)
#   $2 - LB 类型 (none|haproxy|nginx|kubexm-kh|kubexm-kn|kube-vip)
#   $3 - Storage 类型 (none|nfs|nfs-subdir-external|longhorn|iscsi)
#   $4 - CNI 类型 (calico|flannel|cilium|...)
# Returns:
#   系统包列表（每行一个）
#######################################
defaults::get_iso_packages() {
  local os_type="${1:-centos7}"
  local lb_type="${2:-none}"
  local storage_type="${3:-none}"
  local cni_type="${4:-calico}"

  local packages=()

  # 基础包
  packages+=("${KUBEXM_ISO_PKG_BASE[@]}")

  # LB 包推断
  case "${lb_type}" in
    haproxy)     packages+=("${KUBEXM_ISO_PKG_HAPROXY[@]}") ;;
    nginx)       packages+=("${KUBEXM_ISO_PKG_NGINX[@]}") ;;
    kubexm-kh)   packages+=("${KUBEXM_ISO_PKG_HAPROXY[@]}" "${KUBEXM_ISO_PKG_KEEPALIVED[@]}") ;;
    kubexm-kn)   packages+=("${KUBEXM_ISO_PKG_NGINX[@]}" "${KUBEXM_ISO_PKG_KEEPALIVED[@]}") ;;
    kube-vip)    : ;;  # kube-vip 是 DaemonSet，不需要系统包
    exists|none) : ;;
  esac

  # Storage 包推断
  case "${storage_type}" in
    nfs|nfs-subdir-external|nfs-subdir-external-provisioner)
      case "${os_type}" in
        centos*|rocky*|almalinux*|rhel*|ol*|anolis*|fedora*|kylin*|openeuler*|uos*)
          packages+=("${KUBEXM_ISO_PKG_NFS_RPM[@]}")
          ;;
        ubuntu*|debian*)
          packages+=("${KUBEXM_ISO_PKG_NFS_DEB[@]}")
          ;;
      esac
      ;;
    longhorn)
      case "${os_type}" in
        centos*|rocky*|almalinux*|rhel*|ol*|anolis*|fedora*|kylin*|openeuler*|uos*)
          packages+=("${KUBEXM_ISO_PKG_NFS_RPM[@]}" "${KUBEXM_ISO_PKG_ISCSI_RPM[@]}")
          ;;
        ubuntu*|debian*)
          packages+=("${KUBEXM_ISO_PKG_NFS_DEB[@]}" "${KUBEXM_ISO_PKG_ISCSI_DEB[@]}")
          ;;
      esac
      ;;
    iscsi)
      case "${os_type}" in
        centos*|rocky*|almalinux*|rhel*|ol*|anolis*|fedora*|kylin*|openeuler*|uos*)
          packages+=("${KUBEXM_ISO_PKG_ISCSI_RPM[@]}")
          ;;
        ubuntu*|debian*)
          packages+=("${KUBEXM_ISO_PKG_ISCSI_DEB[@]}")
          ;;
      esac
      ;;
  esac

  # CNI 包推断
  case "${cni_type}" in
    cilium)
      case "${os_type}" in
        centos*|rocky*|almalinux*|rhel*|ol*|anolis*|fedora*|kylin*|openeuler*|uos*)
          packages+=("${KUBEXM_ISO_PKG_CILIUM_RPM[@]}")
          ;;
        ubuntu*|debian*)
          packages+=("${KUBEXM_ISO_PKG_CILIUM_DEB[@]}")
          ;;
      esac
      ;;
  esac

  # 去重输出
  printf '%s\n' "${packages[@]}" | sort -u
}

# 导出函数
export -f defaults::get_kubernetes_version
export -f defaults::get_kubernetes_type
export -f defaults::get_runtime_type
export -f defaults::get_cni_plugin
export -f defaults::get_arch_list
export -f defaults::get_build_os_list
export -f defaults::get_default_config
export -f defaults::get_system_packages
export -f defaults::get_rpm_package_name
export -f defaults::get_deb_package_name
export -f defaults::calculate_lb_params

# ==============================================================================
# 系统预配置相关默认值函数
# ==============================================================================

defaults::get_system_timezone() { echo "${DEFAULT_SYSTEM_TIMEZONE}"; }
defaults::get_system_locale() { echo "${DEFAULT_SYSTEM_LOCALE}"; }
defaults::get_firewall_enabled() { echo "${DEFAULT_FIREWALL_ENABLED}"; }
defaults::get_ntp_servers() { echo "${DEFAULT_NTP_SERVERS}"; }

# ==============================================================================
# 网络配置默认值函数
# ==============================================================================

defaults::get_service_cidr() { echo "${DEFAULT_SERVICE_CIDR}"; }
defaults::get_pod_cidr() { echo "${DEFAULT_POD_CIDR}"; }
defaults::get_cluster_cidr() { echo "${DEFAULT_CLUSTER_CIDR}"; }
defaults::get_cluster_dns_ip() { echo "${DEFAULT_CLUSTER_DNS_IP}"; }
defaults::get_cluster_domain() { echo "${DEFAULT_CLUSTER_DOMAIN}"; }
defaults::get_node_port_range() { echo "${DEFAULT_NODE_PORT_RANGE}"; }

# ==============================================================================
# 负载均衡器默认值函数
# ==============================================================================

defaults::get_loadbalancer_enabled() { echo "${DEFAULT_LOADBALANCER_ENABLED}"; }
defaults::get_loadbalancer_mode() { echo "${DEFAULT_LOADBALANCER_MODE}"; }
defaults::get_loadbalancer_type() { echo "${DEFAULT_LOADBALANCER_TYPE}"; }
defaults::get_vip_address() { echo "${DEFAULT_VIP_ADDRESS}"; }
defaults::get_loadbalancer_interface() { echo "${DEFAULT_LOADBALANCER_INTERFACE}"; }

# ==============================================================================
# Registry默认值函数
# ==============================================================================

defaults::get_registry_enabled() { echo "${DEFAULT_REGISTRY_ENABLED}"; }
defaults::get_registry_host() { echo "${DEFAULT_REGISTRY_HOST}"; }
defaults::get_registry_port() { echo "${DEFAULT_REGISTRY_PORT}"; }
defaults::get_registry_data_dir() { echo "${DEFAULT_REGISTRY_DATA_DIR}"; }
defaults::get_registry_auth_enabled() { echo "${DEFAULT_REGISTRY_AUTH_ENABLED}"; }
defaults::get_registry_tls_enabled() { echo "${DEFAULT_REGISTRY_TLS_ENABLED}"; }
defaults::get_registry_ca_cert() { echo "${DEFAULT_REGISTRY_CA_CERT}"; }
defaults::get_registry_version() { echo "${DEFAULT_REGISTRY_VERSION}"; }

# ==============================================================================
# 证书管理默认值函数
# ==============================================================================

defaults::get_cert_validity_days() { echo "${DEFAULT_CERT_VALIDITY_DAYS}"; }
defaults::get_cert_renew_days_before() { echo "${DEFAULT_CERT_RENEW_DAYS_BEFORE}"; }
defaults::get_cert_backup_dir() { echo "${DEFAULT_CERT_BACKUP_DIR}"; }

# ==============================================================================
# Etcd默认值函数
# ==============================================================================

defaults::get_etcd_type() { echo "${DEFAULT_ETCD_TYPE}"; }
defaults::get_etcd_data_dir() { echo "${DEFAULT_ETCD_DATA_DIR}"; }
defaults::get_etcd_backup_enabled() { echo "${DEFAULT_ETCD_BACKUP_ENABLED}"; }
defaults::get_etcd_backup_dir() { echo "${DEFAULT_ETCD_BACKUP_DIR}"; }
defaults::get_log_retention_days() { echo "${DEFAULT_LOG_RETENTION_DAYS:-30}"; }
defaults::get_traefik_version() { echo "${DEFAULT_TRAEFIK_VERSION}"; }
defaults::get_etcd_backup_retention_days() { echo "${DEFAULT_ETCD_BACKUP_RETENTION_DAYS}"; }
defaults::get_etcd_backup_timer_enabled() { echo "${DEFAULT_ETCD_BACKUP_TIMER_ENABLED}"; }

# ==============================================================================
# 容器运行时默认值函数
# ==============================================================================

defaults::get_docker_cri_dockerd_enabled() { echo "${DEFAULT_DOCKER_CRI_DOCKERD_ENABLED}"; }
defaults::get_crio_conmon_path() { echo "${DEFAULT_CRIO_CONMON_PATH}"; }
defaults::get_containerd_max_concurrent_downloads() { echo "${DEFAULT_CONTAINERD_MAX_CONCURRENT_DOWNLOADS}"; }

# ==============================================================================
# SSH和远程执行默认值函数
# ==============================================================================

defaults::get_ssh_user() { echo "${DEFAULT_SSH_USER}"; }
defaults::get_ssh_port() { echo "${DEFAULT_SSH_PORT}"; }
defaults::get_command_timeout() { echo "${DEFAULT_COMMAND_TIMEOUT}"; }
defaults::get_node_wait_timeout() { echo "${DEFAULT_NODE_WAIT_TIMEOUT}"; }
defaults::get_health_check_timeout() { echo "${DEFAULT_HEALTH_CHECK_TIMEOUT}"; }

# ==============================================================================
# 集群操作默认值函数
# ==============================================================================

defaults::get_scale_action() { echo "${DEFAULT_SCALE_ACTION}"; }
defaults::get_health_check_type() { echo "${DEFAULT_HEALTH_CHECK_TYPE}"; }
defaults::get_arch() { echo "${DEFAULT_ARCH}"; }
defaults::get_os_type() { echo "${DEFAULT_OS_TYPE}"; }
defaults::get_cert_type() { echo "${DEFAULT_CERT_TYPE}"; }
defaults::get_rotation_phase() { echo "${DEFAULT_ROTATION_PHASE}"; }
defaults::get_renew_action() { echo "${DEFAULT_RENEW_ACTION}"; }
defaults::get_api_server_port() { echo "${DEFAULT_API_SERVER_PORT}"; }
defaults::get_replicas() { echo "${DEFAULT_REPLICAS}"; }
defaults::get_force() { echo "${DEFAULT_FORCE}"; }
defaults::get_cluster_name() { echo "${DEFAULT_CLUSTER_NAME}"; }

# ==============================================================================
# 存储默认值函数
# ==============================================================================

defaults::get_storage_type() { echo "${DEFAULT_STORAGE_TYPE}"; }
defaults::get_nfs_server() { echo "${DEFAULT_NFS_SERVER}"; }
defaults::get_nfs_path() { echo "${DEFAULT_NFS_PATH}"; }
defaults::get_iscsi_server() { echo "${DEFAULT_ISCSI_SERVER}"; }
defaults::get_iscsi_iqn() { echo "${DEFAULT_ISCSI_IQN}"; }

defaults::get_storage_temp() { echo "${DEFAULT_STORAGE_TEMP}"; }
defaults::get_storage_persistent() { echo "${DEFAULT_STORAGE_PERSISTENT}"; }

# ==============================================================================
# CNI插件默认值函数
# ==============================================================================

defaults::get_calico_version() { echo "${DEFAULT_CALICO_VERSION}"; }
defaults::get_flannel_version() { echo "${DEFAULT_FLANNEL_VERSION}"; }
defaults::get_cilium_version() { echo "${DEFAULT_CILIUM_VERSION}"; }

defaults::get_calico_network_mode() { echo "${DEFAULT_CALICO_NETWORK_MODE}"; }
defaults::get_calico_blocksize() { echo "${DEFAULT_CALICO_BLOCKSIZE}"; }
defaults::get_calico_mtu() { echo "${DEFAULT_CALICO_MTU}"; }
defaults::get_calico_ipip_mode() { echo "${DEFAULT_CALICO_IPIP_MODE}"; }

# ==============================================================================
# 插件和扩展默认值函数
# ==============================================================================

defaults::get_ingress_type() { echo "${DEFAULT_INGRESS_TYPE}"; }
defaults::get_ingress_version() { echo "${DEFAULT_INGRESS_GENERIC_VERSION}"; }
defaults::get_dashboard_enabled() { echo "${DEFAULT_DASHBOARD_ENABLED}"; }
defaults::get_dashboard_version() { echo "${DEFAULT_DASHBOARD_VERSION}"; }
defaults::get_monitoring_enabled() { echo "${DEFAULT_MONITORING_ENABLED}"; }
defaults::get_prometheus_version() { echo "${DEFAULT_PROMETHEUS_VERSION}"; }
defaults::get_grafana_version() { echo "${DEFAULT_GRAFANA_VERSION}"; }
defaults::get_logging_enabled() { echo "${DEFAULT_LOGGING_ENABLED}"; }
defaults::get_elasticsearch_version() { echo "${DEFAULT_ELASTICSEARCH_VERSION}"; }
defaults::get_kibana_version() { echo "${DEFAULT_KIBANA_VERSION}"; }

defaults::get_kube_proxy_mode() { echo "${DEFAULT_KUBE_PROXY_MODE}"; }
defaults::get_kube_proxy_scheduler() { echo "${DEFAULT_KUBE_PROXY_SCHEDULER}"; }
defaults::get_kube_proxy_strict_arp() { echo "${DEFAULT_KUBE_PROXY_STRICT_ARP}"; }

defaults::get_coredns_version() { echo "${DEFAULT_COREDNS_VERSION}"; }
defaults::get_nodelocaldns_enabled() { echo "${DEFAULT_NODELOCALDNS_ENABLED}"; }

# ==============================================================================
# 高级配置默认值函数
# ==============================================================================

defaults::get_autoscaler_enabled() { echo "${DEFAULT_AUTOSCALER_ENABLED}"; }
defaults::get_autoscaler_min_nodes() { echo "${DEFAULT_AUTOSCALER_MIN_NODES}"; }
defaults::get_autoscaler_max_nodes() { echo "${DEFAULT_AUTOSCALER_MAX_NODES}"; }
defaults::get_pod_security_policy_enabled() { echo "${DEFAULT_POD_SECURITY_POLICY_ENABLED}"; }
defaults::get_network_policy_enabled() { echo "${DEFAULT_NETWORK_POLICY_ENABLED}"; }
defaults::get_pod_disruption_budget_enabled() { echo "${DEFAULT_POD_DISRUPTION_BUDGET_ENABLED}"; }

# ==============================================================================
# 系统优化默认值函数
# ==============================================================================

defaults::get_sysctl_ip_forward() { echo "${DEFAULT_SYSCTL_IP_FORWARD}"; }
defaults::get_sysctl_bridge_nf_call() { echo "${DEFAULT_SYSCTL_BRIDGE_NF_CALL}"; }
defaults::get_sysctl_swappiness() { echo "${DEFAULT_SYSCTL_SWAPPINESS}"; }
defaults::get_sysctl_neigh_gc_thresh1() { echo "${DEFAULT_SYSCTL_NEIGH_GC_THRESH1}"; }
defaults::get_sysctl_neigh_gc_thresh2() { echo "${DEFAULT_SYSCTL_NEIGH_GC_THRESH2}"; }
defaults::get_sysctl_neigh_gc_thresh3() { echo "${DEFAULT_SYSCTL_NEIGH_GC_THRESH3}"; }
defaults::get_sysctl_conntrack_max() { echo "${DEFAULT_SYSCTL_CONNTRACK_MAX}"; }
defaults::get_sysctl_file_max() { echo "${DEFAULT_SYSCTL_FILE_MAX}"; }

# ==============================================================================
# 工具链默认值函数
# ==============================================================================

defaults::get_crictl_version() { echo "${DEFAULT_CRICTL_VERSION}"; }
defaults::get_etcd_version() { echo "${DEFAULT_ETCD_VERSION}"; }
defaults::get_runc_version() { echo "${DEFAULT_RUNC_VERSION}"; }
defaults::get_containerd_version() { echo "${DEFAULT_CONTAINERD_VERSION}"; }
defaults::get_cni_version() { echo "${DEFAULT_CNI_VERSION}"; }
defaults::get_helm_version() { echo "${DEFAULT_HELM_VERSION}"; }
defaults::get_metrics_server_version() { echo "${DEFAULT_METRICS_SERVER_VERSION}"; }
defaults::get_ingress_nginx_version() { echo "${DEFAULT_INGRESS_NGINX_VERSION}"; }
defaults::get_nodelocaldns_version() { echo "${DEFAULT_NODELOCALDNS_VERSION}"; }
defaults::get_local_path_version() { echo "${DEFAULT_LOCAL_PATH_VERSION}"; }
defaults::get_skopeo_version() { echo "${DEFAULT_SKOPEO_VERSION}"; }
defaults::get_conmon_version() { echo "${DEFAULT_CONMON_VERSION}"; }
defaults::get_kubevip_version() { echo "${DEFAULT_KUBEVIP_VERSION}"; }
defaults::get_kubeadm_version() { echo "${DEFAULT_KUBEADM_VERSION}"; }
defaults::get_kubectl_version() { echo "${DEFAULT_KUBECTL_VERSION}"; }
defaults::get_kubelet_version() { echo "${DEFAULT_KUBELET_VERSION}"; }
defaults::get_haproxy_image_version() { echo "${DEFAULT_HAPROXY_IMAGE_VERSION}"; }
defaults::get_nginx_image_version() { echo "${DEFAULT_NGINX_IMAGE_VERSION}"; }

# 导出所有新增函数
export -f defaults::get_system_timezone
export -f defaults::get_system_locale
export -f defaults::get_firewall_enabled
export -f defaults::get_ntp_servers
export -f defaults::get_service_cidr
export -f defaults::get_pod_cidr
export -f defaults::get_cluster_dns_ip
export -f defaults::get_cluster_domain
export -f defaults::get_node_port_range
export -f defaults::get_nodelocaldns_ip
export -f defaults::get_loadbalancer_enabled
export -f defaults::get_loadbalancer_mode
export -f defaults::get_loadbalancer_type
export -f defaults::get_vip_address
export -f defaults::get_loadbalancer_interface
export -f defaults::get_registry_enabled
export -f defaults::get_registry_host
export -f defaults::get_registry_port
export -f defaults::get_registry_data_dir
export -f defaults::get_registry_auth_enabled
export -f defaults::get_registry_tls_enabled
export -f defaults::get_registry_ca_cert
export -f defaults::get_registry_version
export -f defaults::get_cert_validity_days
export -f defaults::get_cert_renew_days_before
export -f defaults::get_cert_backup_dir
export -f defaults::get_etcd_type
export -f defaults::get_etcd_data_dir
export -f defaults::get_etcd_backup_enabled
export -f defaults::get_etcd_backup_dir
export -f defaults::get_etcd_backup_retention_days
export -f defaults::get_etcd_backup_timer_enabled
export -f defaults::get_docker_cri_dockerd_enabled
export -f defaults::get_crio_conmon_path
export -f defaults::get_containerd_max_concurrent_downloads
export -f defaults::get_storage_type
export -f defaults::get_nfs_server
export -f defaults::get_nfs_path
export -f defaults::get_iscsi_server
export -f defaults::get_iscsi_iqn
export -f defaults::get_calico_version
export -f defaults::get_flannel_version
export -f defaults::get_cilium_version
export -f defaults::get_ingress_type
export -f defaults::get_ingress_version
export -f defaults::get_nodelocaldns_version
export -f defaults::get_local_path_version
export -f defaults::get_dashboard_enabled
export -f defaults::get_dashboard_version
export -f defaults::get_monitoring_enabled
export -f defaults::get_prometheus_version
export -f defaults::get_grafana_version
export -f defaults::get_logging_enabled
export -f defaults::get_elasticsearch_version
export -f defaults::get_kibana_version
export -f defaults::get_autoscaler_enabled
export -f defaults::get_autoscaler_min_nodes
export -f defaults::get_autoscaler_max_nodes
export -f defaults::get_pod_security_policy_enabled
export -f defaults::get_network_policy_enabled
export -f defaults::get_pod_disruption_budget_enabled
export -f defaults::get_sysctl_ip_forward
export -f defaults::get_sysctl_bridge_nf_call
export -f defaults::get_sysctl_swappiness
export -f defaults::get_sysctl_neigh_gc_thresh1
export -f defaults::get_sysctl_neigh_gc_thresh2
export -f defaults::get_sysctl_neigh_gc_thresh3
export -f defaults::get_sysctl_conntrack_max
export -f defaults::get_sysctl_file_max
export -f defaults::get_crictl_version
export -f defaults::get_etcd_version
export -f defaults::get_runc_version
export -f defaults::get_containerd_version
export -f defaults::get_cni_version
export -f defaults::get_helm_version
export -f defaults::get_metrics_server_version
export -f defaults::get_ingress_nginx_version
export -f defaults::get_skopeo_version
export -f defaults::get_conmon_version
export -f defaults::get_kubevip_version
export -f defaults::get_kubeadm_version
export -f defaults::get_kubectl_version
export -f defaults::get_kubelet_version
export -f defaults::get_traefik_version
export -f defaults::get_haproxy_image_version
export -f defaults::get_nginx_image_version
export -f defaults::get_calico_network_mode
export -f defaults::get_calico_blocksize
export -f defaults::get_calico_mtu
export -f defaults::get_calico_ipip_mode
export -f defaults::get_kube_proxy_mode
export -f defaults::get_kube_proxy_scheduler

# ==============================================================================
# ISO 构建默认值
# ==============================================================================
DEFAULT_ISO_OS_NAME="rocky"
DEFAULT_ISO_OS_VERSION="9"
DEFAULT_ISO_ARCH="amd64"

defaults::get_iso_os_name() { echo "${DEFAULT_ISO_OS_NAME}"; }
defaults::get_iso_os_version() { echo "${DEFAULT_ISO_OS_VERSION}"; }
defaults::get_iso_arch() { echo "${DEFAULT_ISO_ARCH}"; }

export -f defaults::get_iso_os_name
export -f defaults::get_iso_os_version
export -f defaults::get_iso_arch
export -f defaults::get_kube_proxy_strict_arp
export -f defaults::get_storage_temp
export -f defaults::get_storage_persistent
export -f defaults::get_coredns_version
export -f defaults::get_nodelocaldns_enabled
export -f defaults::get_iso_packages
