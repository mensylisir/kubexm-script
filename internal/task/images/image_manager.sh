#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Image Management Module
# ==============================================================================
# Dynamic image list generation and management
# Supports: custom image lists, dual-image push, manifest generation
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

# 获取项目根目录
KUBEXM_SCRIPT_ROOT="${KUBEXM_SCRIPT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
KUBEXM_ROOT="${KUBEXM_ROOT:-$KUBEXM_SCRIPT_ROOT}"

# 加载核心模块
source "${KUBEXM_SCRIPT_ROOT}/internal/logger/log.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/defaults.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/config.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/versions.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/helm_manager.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/helm_bom.sh"

# ==============================================================================
# 变量定义
# ==============================================================================

# 默认镜像列表文件路径
DEFAULT_IMAGE_LIST="${KUBEXM_SCRIPT_ROOT}/etc/kubexm/images.txt"

# 镜像缓存目录
IMAGE_CACHE_DIR="${KUBEXM_SCRIPT_ROOT}/packages/images/cache"

# ==============================================================================
# 镜像列表生成
# ==============================================================================

# 根据Kubernetes版本和配置生成完整镜像列表
# @param $1 Kubernetes版本 (e.g., v1.32.4)
# @param $2 架构列表 (e.g., "amd64,arm64", 可选)
# @param $3 k8s类型 (kubeadm|kubexm, 可选，默认从配置读取)
# @param $4 etcd类型 (kubexm|kubeadm, 可选，默认从配置读取)
# @param $5 网络插件类型 (calico|flannel|cilium, 可选)
# @param $6 LoadBalancer启用 (true|false, 可选)
# @param $7 LoadBalancer模式 (external|internal, 可选)
# @param $8 LoadBalancer类型 (haproxy|nginx|kube-vip, 可选)
# @param $9 NodeLocalDNS启用 (true|false, 可选)
# @return 输出镜像列表到stdout
generate_core_images() {
    local k8s_version="$1"
    local arch_list="${2:-$(config::get_arch_list)}"
    local k8s_type="${3:-}"
    local etcd_type="${4:-}"
    local network_plugin="${5:-}"
    local lb_enabled="${6:-}"
    local lb_mode="${7:-}"
    local lb_type="${8:-}"
    local addon_nodelocaldns="${9:-false}"

    # 在子进程中重新加载版本数据 (关联数组无法导出)
    if [[ -f "${KUBEXM_SCRIPT_ROOT}/internal/config/versions.sh" ]]; then
        source "${KUBEXM_SCRIPT_ROOT}/internal/config/versions.sh" 2>/dev/null
    fi

    # 从配置读取未指定的参数
    if [[ -z "$k8s_type" ]]; then
        k8s_type=$(config::get_kubernetes_type)
    fi
    if [[ -z "$etcd_type" ]]; then
        etcd_type=$(config::get_etcd_type)
    fi
    if [[ -z "$network_plugin" ]]; then
        network_plugin=$(config::get_network_plugin)
    fi
    if [[ -z "$lb_enabled" ]]; then
        lb_enabled=$(config::get_loadbalancer_enabled)
    fi
    if [[ -z "$lb_mode" ]]; then
        lb_mode=$(config::get_loadbalancer_mode)
    fi
    if [[ -z "$lb_type" ]]; then
        lb_type=$(config::get_loadbalancer_type)
    fi

    local coredns_version=$(versions::get "coredns" "${k8s_version}")

    # kubexm模式：控制平面组件使用二进制部署，只返回 pause 和 coredns
    if [[ "$k8s_type" == "kubexm" ]]; then
        echo "registry.k8s.io/coredns/coredns:${coredns_version}"
        echo "registry.k8s.io/pause:3.10"
    else
        # kubeadm模式：返回所有控制平面镜像
        echo "registry.k8s.io/kube-apiserver:${k8s_version}"
        echo "registry.k8s.io/kube-controller-manager:${k8s_version}"
        echo "registry.k8s.io/kube-scheduler:${k8s_version}"
        echo "registry.k8s.io/kube-proxy:${k8s_version}"
        echo "registry.k8s.io/coredns/coredns:${coredns_version}"
        echo "registry.k8s.io/pause:3.10"

        # etcd镜像（仅在kubeadm模式时添加）
        if [[ "$etcd_type" == "kubeadm" ]]; then
            local etcd_version=$(versions::get "etcd" "${k8s_version}")
            if [[ -n "$etcd_version" ]]; then
                echo "registry.k8s.io/etcd:${etcd_version}-0"
            fi
        fi
    fi

    # CNI插件镜像
    generate_cni_images "${network_plugin}" "${k8s_version}"

    # LoadBalancer镜像（仅在 kubeadm + internal 模式下需要）
    if [[ "$k8s_type" == "kubeadm" && "$lb_enabled" == "true" && "$lb_mode" == "internal" ]]; then
        case "${lb_type}" in
            haproxy)
                local haproxy_version=$(versions::get "haproxy" "${k8s_version}" || defaults::get_haproxy_image_version)
                echo "docker.io/library/haproxy:${haproxy_version}-alpine"
                ;;
            nginx)
                local nginx_version=$(versions::get "nginx" "${k8s_version}" || defaults::get_nginx_image_version)
                echo "docker.io/library/nginx:${nginx_version}-alpine"
                ;;
        esac
        
        # # Keepalived镜像 (所有Internal模式都需要)
        # local keepalived_version=$(versions::get "keepalived" "${k8s_version}" || defaults::get_keepalived_image_version)
        # echo "docker.io/osixia/keepalived:${keepalived_version}"
    fi

    # Kube-VIP镜像
    if [[ "$lb_enabled" == "true" && "$lb_mode" == "kube-vip" ]]; then
        local kubevip_version=$(versions::get "kube-vip" "${k8s_version}" || defaults::get_kubevip_version)
        echo "ghcr.io/kube-vip/kube-vip:${kubevip_version}"
    fi


    # 动态分析其他已启用的 Addons
    image_manager::get_addon_images "$k8s_version"
}

# 获取所有已启用 Addon 的镜像（动态分析）
image_manager::get_addon_images() {
    local k8s_version="${1:-$(defaults::get_kubernetes_version)}"
    # 动态确定 ingress controller 类型
    local ingress_type
    if [[ -n "${KUBEXM_CONFIG_FILE:-}" ]]; then
        ingress_type=$(config::get_value "$KUBEXM_CONFIG_FILE" "spec.addons.ingress_controller.type" "nginx")
    else
        ingress_type=$(config::get_ingress_type)
    fi
    local ingress_addon="ingress-nginx:spec.addons.ingress_controller.enabled:ingress:packages/helm/ingress-nginx"
    if [[ "$ingress_type" == "traefik" ]]; then
        ingress_addon="traefik:spec.addons.ingress_controller.enabled:traefik:packages/helm/traefik"
    fi

    # 格式：addon_name:config_path:release_name:local_path
    local addon_map=(
        "metrics-server:spec.addons.metrics_server.enabled:metrics-server:packages/helm/metrics-server"
        "${ingress_addon}"
        "local-path-provisioner:spec.addons.storage.local_path_provisioner.enabled:local-path:packages/helm/local-path-provisioner"
        "cert-manager:spec.addons.cert_manager.enabled:cert-manager:packages/helm/cert-manager"
        "prometheus:spec.addons.monitoring.enabled:prometheus:packages/helm/prometheus"
        "grafana:spec.addons.monitoring.enabled:grafana:packages/helm/grafana"
        "kubernetes-dashboard:spec.addons.dashboard.enabled:kubernetes-dashboard:packages/helm/dashboard"
        "istio-base:spec.addons.istio.enabled:istio-base:packages/helm/istio-base"
        "istio-istiod:spec.addons.istio.enabled:istiod:packages/helm/istio-istiod"
        "external-dns:spec.addons.external_dns.enabled:external-dns:packages/helm/external-dns"
        "longhorn:spec.addons.longhorn.enabled:longhorn:packages/helm/longhorn"
        "openebs:spec.addons.openebs.enabled:openebs:packages/helm/openebs"
        "nodelocaldns:spec.addons.nodelocaldns.enabled:node-local-dns:packages/helm/node-local-dns"
    )

    for item in "${addon_map[@]}"; do
        IFS=':' read -r a_name a_conf a_rel a_path <<< "$item"
        
        local enabled
        if [[ -n "${KUBEXM_CONFIG_FILE:-}" ]]; then
            enabled=$(config::get_value "$KUBEXM_CONFIG_FILE" "$a_conf" "false" | tr '[:upper:]' '[:lower:]')
        else
            enabled=$(config::get "$a_conf" "false" | tr '[:upper:]' '[:lower:]')
        fi

        if [[ "$enabled" == "true" ]]; then
            local imgs
            imgs=$(helm_manager::extract_addon_images "$a_name" "$a_rel" "$a_path" "$k8s_version")
            if [[ -n "$imgs" ]]; then
                echo "$imgs"
            fi
        fi
    done
}

# 获取所有已启用的 Addon 列表（供 manifests 流程使用）
# @return 输出已启用的 addon 条目到 stdout，每行格式: addon_name:config_path:release_name:local_path
image_manager::get_enabled_addons() {
    # 动态确定 ingress controller 类型
    local ingress_type
    if [[ -n "${KUBEXM_CONFIG_FILE:-}" ]]; then
        ingress_type=$(config::get_value "$KUBEXM_CONFIG_FILE" "spec.addons.ingress_controller.type" "nginx")
    else
        ingress_type=$(config::get_ingress_type)
    fi

    local ingress_addon="ingress-nginx:spec.addons.ingress_controller.enabled:ingress:packages/helm/ingress-nginx"
    if [[ "$ingress_type" == "traefik" ]]; then
        ingress_addon="traefik:spec.addons.ingress_controller.enabled:traefik:packages/helm/traefik"
    fi

    # 格式：addon_name:config_path:release_name:local_path
    local addon_map=(
        "metrics-server:spec.addons.metrics_server.enabled:metrics-server:packages/helm/metrics-server"
        "${ingress_addon}"
        "local-path-provisioner:spec.addons.storage.local_path_provisioner.enabled:local-path:packages/helm/local-path-provisioner"
        "cert-manager:spec.addons.cert_manager.enabled:cert-manager:packages/helm/cert-manager"
        "prometheus:spec.addons.monitoring.enabled:prometheus:packages/helm/prometheus"
        "grafana:spec.addons.monitoring.enabled:grafana:packages/helm/grafana"
        "kubernetes-dashboard:spec.addons.dashboard.enabled:kubernetes-dashboard:packages/helm/dashboard"
        "istio-base:spec.addons.istio.enabled:istio-base:packages/helm/istio-base"
        "istio-istiod:spec.addons.istio.enabled:istiod:packages/helm/istio-istiod"
        "external-dns:spec.addons.external_dns.enabled:external-dns:packages/helm/external-dns"
        "longhorn:spec.addons.longhorn.enabled:longhorn:packages/helm/longhorn"
        "openebs:spec.addons.openebs.enabled:openebs:packages/helm/openebs"
        "nodelocaldns:spec.addons.nodelocaldns.enabled:node-local-dns:packages/helm/node-local-dns"
    )

    for item in "${addon_map[@]}"; do
        IFS=':' read -r a_name a_conf a_rel a_path <<< "$item"
        
        local enabled
        if [[ -n "${KUBEXM_CONFIG_FILE:-}" ]]; then
            enabled=$(config::get_value "$KUBEXM_CONFIG_FILE" "$a_conf" "false" | tr '[:upper:]' '[:lower:]')
        else
            enabled=$(config::get "$a_conf" "false" | tr '[:upper:]' '[:lower:]')
        fi

        if [[ "$enabled" == "true" ]]; then
            echo "$item"
        fi
    done
}

# 生成CNI插件镜像列表
# @param $1 CNI插件类型 (calico, flannel, cilium)
# @param $2 Kubernetes版本
# @return 输出CNI镜像列表到stdout
generate_cni_images() {
    local cni_plugin="$1"
    local k8s_version="$2"

    case "${cni_plugin}" in
        calico)
            local calico_version=$(versions::get "calico" "${k8s_version}")
            local calico_tag=$(versions::get_calico_tag "${calico_version}")
            echo "docker.io/calico/cni:${calico_tag}"
            echo "docker.io/calico/pod2daemon-flexvol:${calico_tag}"
            echo "docker.io/calico/node:${calico_tag}"
            echo "docker.io/calico/kube-controllers:${calico_tag}"
            echo "docker.io/calico/typha:${calico_tag}"
            ;;
        flannel)
            local flannel_version=$(versions::get "flannel" "${k8s_version}")
            echo "docker.io/flannel/flannel:${flannel_version}"
            ;;
        cilium)
            local cilium_version=$(versions::get "cilium" "${k8s_version}")
            echo "quay.io/cilium/cilium:${cilium_version}"
            echo "quay.io/cilium/operator-generic:${cilium_version}"
            ;;
        *)
            log::warn "未知的CNI插件: $cni_plugin"
            ;;
    esac
}

# 生成完整镜像列表（根据配置）
# @param $1 集群名称 (可选)
# @param $2 输出文件路径 (可选)
# @return 0 if success, 1 if failed
generate_image_list() {
    local cluster_name="${1:-}"
    local output_file="${2:-$DEFAULT_IMAGE_LIST}"

    log::info "生成镜像列表..."

    # 创建输出目录
    mkdir -p "$(dirname "$output_file")"

    # 如果指定了集群名称，从配置读取
    if [[ -n "$cluster_name" ]]; then
        local config_file="${KUBEXM_CONFIG_FILE}"
        if [[ -f "$config_file" ]]; then
            log::info "从配置文件生成镜像列表: $config_file"

            # 使用xmparser读取配置
            local xmparser_bin="${KUBEXM_ROOT}/bin/xmparser"

            if [[ -f "$xmparser_bin" ]]; then
                local k8s_version=$($xmparser_bin "$config_file" "spec.kubernetes.version" 2>/dev/null || defaults::get_kubernetes_version)
                local k8s_type=$($xmparser_bin "$config_file" "spec.kubernetes.type" 2>/dev/null || defaults::get_kubernetes_type)
                local cni_plugin=$($xmparser_bin "$config_file" "spec.network.plugin" 2>/dev/null || defaults::get_cni_plugin)
                local arch_list=$($xmparser_bin "$config_file" "spec.arch" 2>/dev/null | sed 's/\[//g; s/\]//g; s/ /,/g' || defaults::get_arch_list)
                local etcd_type=$($xmparser_bin "$config_file" "spec.etcd.type" 2>/dev/null || defaults::get_etcd_type)
                local lb_enabled=$($xmparser_bin "$config_file" "spec.loadbalancer.enabled" 2>/dev/null || defaults::get_loadbalancer_enabled)
                local lb_mode=$($xmparser_bin "$config_file" "spec.loadbalancer.mode" 2>/dev/null || echo "none")
                local lb_type=$($xmparser_bin "$config_file" "spec.loadbalancer.type" 2>/dev/null || defaults::get_loadbalancer_type)

                # 生成镜像列表
                {
                    echo "# Kubernetes镜像列表"
                    echo "# 集群: $cluster_name"
                    echo "# 生成时间: $(date)"
                    echo "# Kubernetes版本: $k8s_version"
                    echo "# K8s类型: $k8s_type"
                    echo "# CNI插件: $cni_plugin"
                    echo "# 架构: $arch_list"
                    echo "# etcd类型: $etcd_type"
                    echo "# LoadBalancer: ${lb_enabled}/${lb_mode}/${lb_type}"
                    echo ""

                    # 完整镜像列表（包含 K8s 核心镜像、CNI 镜像、LB 镜像）
                    generate_core_images "$k8s_version" "$arch_list" "$k8s_type" "$etcd_type" "$cni_plugin" "$lb_enabled" "$lb_mode" "$lb_type"
                    echo ""

                    # 附加组件（现在由 generate_core_images -> image_manager::get_addon_images 动态生成）
                    # 这里不再需要硬编码

                } > "$output_file"
            else
                log::error "xmparser未找到，使用默认配置"
                generate_default_image_list "$output_file" "$(defaults::get_kubernetes_version)"
            fi
        else
            log::error "配置文件不存在: $config_file"
            return 1
        fi
    else
        # 生成默认镜像列表
        generate_default_image_list "$output_file" "$(defaults::get_kubernetes_version)"
    fi

    log::success "镜像列表生成完成: $output_file"
    log::info "镜像总数: $(grep -v '^#' "$output_file" | grep -v '^$' | wc -l)"
    return 0
}

# 生成默认镜像列表
# @param $1 输出文件路径
# @param $2 Kubernetes版本 (可选，默认使用 DEFAULT_KUBERNETES_VERSION)
generate_default_image_list() {
    local output_file="$1"
    local k8s_version="${2:-}"
    k8s_version="${k8s_version:-$(defaults::get_kubernetes_version)}"
    local gen_time="${3:-$(date)}"

    log::info "生成默认镜像列表 (Kubernetes: ${k8s_version})"

    cat > "$output_file" << EOF
# Kubernetes默认镜像列表
# 生成时间: ${gen_time}

# === 核心组件 ===
registry.k8s.io/kube-apiserver:${k8s_version}
registry.k8s.io/kube-controller-manager:${k8s_version}
registry.k8s.io/kube-scheduler:${k8s_version}
registry.k8s.io/kube-proxy:${k8s_version}
registry.k8s.io/coredns/coredns:v1.11.1
registry.k8s.io/pause:3.10
registry.k8s.io/etcd:3.5.13-0

# === CNI插件 (Calico) ===
docker.io/calico/cni:v3.27.0
docker.io/calico/pod2daemon-flexvol:v3.27.0
docker.io/calico/node:v3.27.0
docker.io/calico/kube-controllers:v3.27.0
docker.io/calico/typha:v3.27.0

# === 附加组件 ===
registry.k8s.io/ingress-nginx/controller:v1.8.1
registry.k8s.io/ingress-nginx/kube-webhook-certgen:v20231011-8b5c7b315
registry.k8s.io/metrics-server/metrics-server:v0.6.4
EOF
}

# ==============================================================================
# 镜像缓存管理
# ==============================================================================

# 检查镜像是否已缓存
# @param $1 镜像名称
# @param $2 架构 (可选)
# @return 0 if cached, 1 if not
is_image_cached() {
    local image="$1"
    local arch="${2:-$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')}"

    local cache_key=$(echo "$image" | tr "/" "_" | tr ":" "_")
    local cache_path="${IMAGE_CACHE_DIR}/${cache_key}-${arch}.oci"

    if [[ -d "$cache_path" ]]; then
        return 0
    else
        return 1
    fi
}

# 缓存镜像
# @param $1 镜像名称
# @param $2 架构 (可选)
# @return 0 if success, 1 if failed
cache_image() {
    local image="$1"
    local arch="${2:-$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')}"

    log::info "缓存镜像: $image ($arch)"

    local cache_key=$(echo "$image" | tr "/" "_" | tr ":" "_")
    local cache_path="${IMAGE_CACHE_DIR}/${cache_key}-${arch}.oci"

    mkdir -p "$IMAGE_CACHE_DIR"

    # 使用skopeo复制镜像到OCI格式
    if skopeo copy --override-arch="$arch" --retry-times=3 \
       docker://"$image" oci:"$cache_path" 2>/dev/null; then
        log::info "镜像已缓存: $cache_path"
        return 0
    else
        log::error "镜像缓存失败: $image ($arch)"
        return 1
    fi
}

# ==============================================================================
# 公共函数
# ==============================================================================

# 显示帮助信息
image_manager::show_help() {
    cat << EOF
KubeXM Image Manager

Usage: image_manager::function_name [arguments]

Available Functions:
  generate_core_images        Generate core Kubernetes images
  generate_cni_images         Generate CNI plugin images
  generate_image_list         Generate complete image list
  is_image_cached             Check if image is cached
  cache_image                 Cache an image locally

Examples:
  image_manager::generate_core_images "v1.32.4" "amd64,arm64"
  image_manager::generate_cni_images "calico" "v1.32.4"
  image_manager::generate_image_list "CLUSTER_NAME" "/tmp/images.txt"

EOF
}

# 如果直接执行此脚本，则显示帮助
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    image_manager::show_help
fi
