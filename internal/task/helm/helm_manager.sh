#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Helm Manager Module
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

# 获取项目根目录 (if not set)
KUBEXM_ROOT="${KUBEXM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

#######################################
# 从 Helm chart 或 YAML 清单提取容器镜像
# Arguments:
#   $1 - Release 名称 (仅用于 Helm)
#   $2 - Chart 路径或 YAML 文件路径
#   $@ - 其他 helm template 参数
# Returns:
#   镜像列表 (stdout)
#######################################
helm_manager::get_images() {
  local release_name="$1"
  local target_path="$2"
  shift 2

  # 情况 1: 如果是 YAML 文件，直接解析
  if [[ -f "$target_path" && ("$target_path" =~ \.yaml$ || "$target_path" =~ \.yml$) ]]; then
    helm_manager::_extract_images_from_stream < "$target_path"
    return 0
  fi

  # 情况 2: 如果是目录，作为 Helm Chart 处理
  if [[ -d "$target_path" ]]; then
    if ! command -v helm &>/dev/null; then
      return 1
    fi

    local rendered
    rendered=$(helm template "${release_name}" "${target_path}" "$@") || return 1
    echo "${rendered}" | helm_manager::_extract_images_from_stream
    return 0
  fi

  return 1
}

# 内部辅助：从 stdin 提取容器镜像列表
helm_manager::_extract_images_from_stream() {
  grep -E 'image:|repository:' \
    | sed -E 's/.*(image|repository):[[:space:]]*"?([^"]+)"?/\2/' \
    | sed "s/'//g" \
    | grep -v '^null$' \
    | grep -E '/|:' \
    | sort -u
}

#######################################
# 从 Helm chart 提取容器镜像 (路径版)
# Arguments:
#   $1 - chart目录路径
# Returns:
#   镜像列表 (stdout)
#######################################
helm_manager::extract_images() {
  local chart_dir="$1"

  # 检查 chart.yaml 是否存在
  [[ ! -f "${chart_dir}/Chart.yaml" ]] && return 1

  helm_manager::get_images "release" "${chart_dir}"
}

#######################################
# 提取 Addon 镜像 (支持本地/下载临时分析)
# Arguments:
#   $1 - Addon 名称 (如 metrics-server)
#   $2 - Release 名称 (如 metrics-server)
#   $3 - 相对 Chart 路径 (如 packages/helm/metrics-server)
# Returns:
#   镜像列表 (stdout)
#######################################
helm_manager::extract_addon_images() {
  local addon_name="$1"
  local release_name="$2"
  local relative_chart_path="$3"
  local k8s_version="${4:-$(defaults::get_kubernetes_version)}"
  
  # 确保依赖已加载
  if ! command -v utils::helm::bom::get_chart_info &>/dev/null; then
    local bom_script="${KUBEXM_ROOT}/internal/utils/helm_bom.sh"
    [[ -f "${bom_script}" ]] && source "${bom_script}"
  fi

  local target_dir="${KUBEXM_ROOT}/${relative_chart_path}"
  local local_item
  # 寻找本地已有的目录或文件
  local_item=$(ls -d "${target_dir}"/* 2>/dev/null | sort -V | tail -n1)

  if [[ -n "${local_item}" ]]; then
    # 已有本地资源，直接分析
    helm_manager::get_images "${release_name}" "${local_item}" 2>/dev/null
  else
    # 本地没有，尝试从 BOM 下载分析后删除
    if command -v utils::helm::bom::get_chart_info &>/dev/null; then
      local info
      info=$(utils::helm::bom::get_chart_info "${addon_name}" "${k8s_version}")
      if [[ -n "$info" ]]; then
        IFS=':' read -r version repo_url <<< "$info"
        
        local tmp_root="${KUBEXM_ROOT}/packages/helm/.tmp"
        mkdir -p "${tmp_root}"
        
        local dl_dir
        dl_dir=$(mktemp -d "${tmp_root}/${addon_name}_XXXXXX")

        if utils::helm::bom::download_chart "${addon_name}" "${version}" "${repo_url}" "${dl_dir}" >/dev/null 2>&1; then
           # download_chart 成功后，可能是个目录（Chart）或者单个下载的文件
           local item_path="${dl_dir}/${addon_name}"
           # 如果是 YAML，可能是 addon_name.yaml
           [[ ! -e "$item_path" ]] && item_path="${dl_dir}/${addon_name}.yaml"
           
           helm_manager::get_images "${release_name}" "${item_path}"
        fi
        
        # 清理
        rm -rf "${dl_dir}"
      fi
    fi
  fi
}
