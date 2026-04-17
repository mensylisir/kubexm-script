#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Helm BOM (Bill of Materials)
# ==============================================================================
# Helm包管理工具
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

# 加载依赖
KUBEXM_SCRIPT_ROOT="${KUBEXM_SCRIPT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "${KUBEXM_SCRIPT_ROOT}/internal/logger/log.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/defaults.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/versions.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/common.sh"

#######################################
# 下载Helm Chart
# Arguments:
#   $1 - Chart名称
#   $2 - 版本
#   $3 - 仓库URL
#   $4 - 输出目录
# Returns:
#   0 成功, 1 失败
#######################################
utils::helm::bom::download_chart() {
  local chart_name="$1"
  local version="$2"
  local repo_url="$3"
  local output_dir="$4"

  log::info "Downloading Helm chart: $chart_name:$version from $repo_url"

  if ! utils::command_exists helm; then
    log::error "helm command not found"
    return 1
  fi

  # 如果 URL 以 .yaml 结尾，视为清单文件
  if [[ "$repo_url" =~ \.yaml$ ]]; then
    # 对于清单，chart_name 可能指的是输出文件名
    utils::download_file "$repo_url" "$output_dir/${chart_name}.yaml" && return 0
    return 1
  fi

  # 直接使用 helm pull --repo 下载，避免 helm repo add 污染本地配置
  if helm pull "$chart_name" --version "$version" --repo "$repo_url" -d "$output_dir" --untar >/dev/null 2>&1; then
    log::success "Chart downloaded: $output_dir/$chart_name"
    return 0
  else
    log::error "Failed to download chart: $chart_name:$version from $repo_url"
    return 1
  fi
}

#######################################
# 获取Helm Chart定义列表
# Returns:
#   Chart定义列表 (name:version:repo_url)
#######################################
utils::helm::bom::get_charts() {
  local k8s_version="${1:-$(defaults::get_kubernetes_version)}"

  # Declare as global so it can be accessed by get_chart_info
  charts=(
    "ingress-nginx:$(versions::get ingress-nginx "$k8s_version"):https://kubernetes.github.io/ingress-nginx"
    "metrics-server:$(versions::get metrics-server "$k8s_version"):https://kubernetes-sigs.github.io/metrics-server"
    "cert-manager:$(versions::get cert-manager "$k8s_version"):https://charts.jetstack.io"
    "external-dns:$(versions::get external-dns "$k8s_version"):https://kubernetes-sigs.github.io/external-dns"
    "istio-base:$(versions::get istio-base "$k8s_version"):https://istio-release.storage.googleapis.com/charts"
    "istio-istiod:$(versions::get istio-istiod "$k8s_version"):https://istio-release.storage.googleapis.com/charts"
    "prometheus:$(versions::get prometheus "$k8s_version"):https://prometheus-community.github.io/helm-charts"
    "grafana:$(versions::get grafana "$k8s_version"):https://grafana.github.io/helm-charts"
    "longhorn:$(versions::get longhorn "$k8s_version"):https://charts.longhorn.io"
    "openebs:$(versions::get openebs "$k8s_version"):https://openebs.github.io/charts"
    "local-path-provisioner:$(versions::get local-path-provisioner "$k8s_version"):https://charts.containeroo.ch"
    "kubernetes-dashboard:$(versions::get kubernetes-dashboard "$k8s_version"):https://kubernetes.github.io/dashboard/"
    "traefik:$(versions::get traefik "$k8s_version"):https://traefik.github.io/charts"
    "nodelocaldns:$(versions::get nodelocaldns "$k8s_version"):https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/addons/dns/nodelocaldns/nodelocaldns.yaml"
  )
  # Update local-path-provisioner URL if needed. 
  # Actually, local-path-provisioner is often just a yaml, but sometimes has a chart.
  # Let's check where it's usually from. 
  # The user snippet had: https://charts.jetstack.io ? No, it didn't say.
  # Let's use the ones I'm sure about.

  printf "%s\n" "${charts[@]}"
}

#######################################
# 获取指定Chart的信息
# Arguments:
#   $1 - Chart名称
# Returns:
#   version:repo_url 或 空
#######################################
utils::helm::bom::get_chart_info() {
  local target_name="$1"
  local k8s_version="${2:-$(defaults::get_kubernetes_version)}"
  local charts=$(utils::helm::bom::get_charts "$k8s_version")
  
  for chart_info in $charts; do
    IFS=':' read -r chart_name chart_version repo_url <<< "$chart_info"
    if [[ "$chart_name" == "$target_name" ]]; then
      echo "$chart_version:$repo_url"
      return 0
    fi
  done
  return 1
}

#######################################
# 下载常用Helm Charts
# Arguments:
#   $1 - 输出目录
#   $2 - Kubernetes版本（可选）
# Returns:
#   0 成功, 1 失败
#######################################
utils::helm::bom::download_common_charts() {
  local output_dir="$1"
  local k8s_version="${2:-$(defaults::get_kubernetes_version)}"

  log::info "Downloading common Helm charts..."

  utils::ensure_dir "$output_dir"

  local charts=($(utils::helm::bom::get_charts))

  local success=0
  for chart_info in "${charts[@]}"; do
    IFS=':' read -r chart_name chart_version repo_url <<< "$chart_info"

    if utils::helm::bom::download_chart "$chart_name" "$chart_version" "$repo_url" "$output_dir"; then
      ((success++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
    fi
  done

  if [[ $success -eq ${#charts[@]} ]]; then
    log::success "All charts downloaded successfully"
    return 0
  else
    log::error "Some charts failed to download ($success/${#charts[@]})"
    return 1
  fi
}

#######################################
# 生成Helm BOM
# Arguments:
#   $1 - 输出文件路径
#   $2 - Charts目录
# Returns:
#   0 成功, 1 失败
#######################################
utils::helm::bom::generate_bom() {
  local output_file="$1"
  local charts_dir="$2"

  log::info "Generating Helm BOM..."

  {
    echo "# Helm Chart Bill of Materials"
    echo "# Generated: $(date)"
    echo "# Charts Directory: $charts_dir"
    echo ""

    echo "# Downloaded Charts:"
    if [[ -d "$charts_dir" ]]; then
      for chart_dir in "$charts_dir"/*; do
        if [[ -d "$chart_dir" ]]; then
          local chart_name
          chart_name=$(basename "$chart_dir")

          # 读取Chart.yaml
          local chart_yaml="$chart_dir/Chart.yaml"
          if [[ -f "$chart_yaml" ]]; then
            local version
            version=$(grep '^version:' "$chart_yaml" 2>/dev/null | awk '{print $2}' || echo "unknown")
            local app_version
            app_version=$(grep '^appVersion:' "$chart_yaml" 2>/dev/null | awk '{print $2}' || echo "unknown")
            echo "  - $chart_name (Chart Version: $version, App Version: $app_version)"
          else
            echo "  - $chart_name"
          fi
        fi
      done
    else
      echo "  No charts directory found"
    fi

  } > "$output_file"

  log::success "Helm BOM generated: $output_file"
  return 0
}

# 导出函数
export -f utils::helm::bom::download_chart
export -f utils::helm::bom::get_charts
export -f utils::helm::bom::get_chart_info
export -f utils::helm::bom::download_common_charts
export -f utils::helm::bom::generate_bom
