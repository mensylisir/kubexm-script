#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Image Push Module (Skopeo-based)
# ==============================================================================
# Image push and manifest management functions using Skopeo
# Supports: download, push, retag, dual-image, multi-arch manifest
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

# 获取项目根目录
KUBEXM_SCRIPT_ROOT="${KUBEXM_SCRIPT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
KUBEXM_ROOT="${KUBEXM_ROOT:-$KUBEXM_SCRIPT_ROOT}"

# 加载依赖 (如果存在)
if [[ -f "${KUBEXM_SCRIPT_ROOT}/internal/utils/utils.sh" ]]; then
    source "${KUBEXM_SCRIPT_ROOT}/internal/utils/utils.sh"
fi
if [[ -f "${KUBEXM_SCRIPT_ROOT}/internal/logger/log.sh" ]]; then
    source "${KUBEXM_SCRIPT_ROOT}/internal/logger/log.sh"
fi
if [[ -f "${KUBEXM_SCRIPT_ROOT}/internal/config/versions.sh" ]]; then
    source "${KUBEXM_SCRIPT_ROOT}/internal/config/versions.sh"
fi
if [[ -f "${KUBEXM_SCRIPT_ROOT}/internal/utils/image.sh" ]]; then
    source "${KUBEXM_SCRIPT_ROOT}/internal/utils/image.sh"
fi

# ==============================================================================
# 变量定义
# ==============================================================================

# 默认镜像列表文件
IMAGE_LIST_FILE="${KUBEXM_SCRIPT_ROOT}/etc/kubexm/images.txt"

# 默认OCI存储目录
OCI_STORAGE_DIR="${KUBEXM_SCRIPT_ROOT}/packages/images"

# Skopeo默认选项
SKOPEO_OPTS="--retry-times=3"
SKOPEO_SRC_TLS="--src-tls-verify=false"
SKOPEO_DEST_TLS="--dest-tls-verify=false"

# 使用Skopeo下载镜像到本地目录
# @param $1 源镜像地址
# @param $2 目标目录
# @param $3 目标镜像名称 (可选)
# @return 0 if success, 1 if failed
image_push::download() {
    local source_image="$1"
    local output_dir="$2"
    local target_name="${3:-}"

    log::info "下载镜像: $source_image"

    # 检查Skopeo是否可用
    if ! command -v skopeo &> /dev/null; then
        log::error "Skopeo未安装，请先安装Skopeo"
        return 1
    fi

    # 创建输出目录
    mkdir -p "$output_dir"

    # 确定目标镜像名称
    local image_name
    if [[ -n "$target_name" ]]; then
        image_name="$target_name"
    else
        # 提取镜像名称（移除registry和tag）
        image_name="${source_image##*/}"
        image_name="${image_name%:*}"
    fi

    # 使用Skopeo下载镜像到OCI目录格式
    local oci_dir="${output_dir}/${image_name}.oci"
    local -a copy_cmd=(skopeo copy --retry-times=3 --src-tls-verify=false)
    copy_cmd+=("docker://${source_image}" "oci:${oci_dir}")

    if "${copy_cmd[@]}" 2>&1 | tee /tmp/skopeo-download.log; then
        log::info "镜像下载成功: $source_image -> $oci_dir"
        return 0
    else
        log::error "镜像下载失败: $source_image"
        return 1
    fi
}

# 使用Skopeo批量下载镜像
# @param $1 镜像列表文件
# @param $2 输出目录
# @return 0 if success, 1 if failed
image_push::batch_download() {
    local image_list_file="$1"
    local output_dir="$2"

    if [[ ! -f "$image_list_file" ]]; then
        log::error "镜像列表文件不存在: $image_list_file"
        return 1
    fi

    log::info "开始批量下载镜像到: $output_dir"
    log::info "镜像列表: $image_list_file"

    # 读取镜像列表
    local images
    images=$(grep -v '^#' "$image_list_file" | grep -v '^$')

    # 下载计数
    local success_count=0
    local fail_count=0

    # 下载每个镜像
    local image
    while IFS= read -r image; do
        if [[ -z "$image" ]]; then
            continue
        fi

        log::info "处理镜像: $image"

        if image_push::download "$image" "$output_dir"; then
            ((success_count++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
        else
            ((fail_count++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
        fi

    done <<< "$images"

    log::info "批量下载完成"
    log::info "成功: $success_count, 失败: $fail_count"

    if [[ $fail_count -eq 0 ]]; then
        log::info "所有镜像下载成功"
        return 0
    else
        log::error "$fail_count 个镜像下载失败"
        return 1
    fi
}

# 使用Skopeo从本地目录加载镜像到Registry
# @param $1 源目录（OCI格式）
# @param $2 目标镜像地址
# @return 0 if success, 1 if failed
image_push::load_from_oci() {
    local source_dir="$1"
    local target_image="$2"

    log::info "加载镜像: $source_dir -> $target_image"

    # 检查Skopeo是否可用
    if ! command -v skopeo &> /dev/null; then
        log::error "Skopeo未安装"
        return 1
    fi

    # 自动识别本地镜像目录格式（OCI/dir）
    local transport="oci"
    if [[ -f "${source_dir}/manifest.json" && ! -f "${source_dir}/oci-layout" && ! -f "${source_dir}/index.json" ]]; then
        transport="dir"
    fi

    # 使用Skopeo从本地目录复制到Registry
    local -a copy_cmd=(skopeo copy --retry-times=3 --dest-tls-verify=false)
    copy_cmd+=("${transport}:${source_dir}" "docker://${target_image}")

    if "${copy_cmd[@]}" 2>&1 | tee /tmp/skopeo-load.log; then
        log::info "镜像加载成功: $target_image"
        return 0
    else
        log::error "镜像加载失败: $target_image"
        return 1
    fi
}

# ==============================================================================
# 公共函数
# ==============================================================================

# 推送单个镜像（使用Skopeo）
# @param $1 源镜像地址
# @param $2 目标镜像地址
# @param $3 目标Registry地址 (可选)
# @return 0 if success, 1 if failed
image_push::single() {
    local source_image="$1"
    local target_image="$2"
    local target_registry="${3:-}"

    log::info "推送镜像: $source_image -> $target_image"

    # 检查Skopeo是否可用
    if ! command -v skopeo &> /dev/null; then
        log::error "Skopeo未安装，请先安装Skopeo"
        log::info "安装命令: curl -fsSL https://raw.githubusercontent.com/containers/skopeo/main/install.sh | sh"
        return 1
    fi

    # 使用Skopeo复制镜像
    # Skopeo可以处理多种传输协议：docker://, oci:, dir:, containers-storage:等
    local -a copy_cmd=(skopeo copy --retry-times=3
      --src-tls-verify=false
      --dest-tls-verify=false
      "docker://${source_image}" "docker://${target_image}")

    # 执行推送
    if "${copy_cmd[@]}" 2>&1 | tee /tmp/skopeo.log; then
        log::info "镜像推送成功: $target_image"
        return 0
    else
        log::error "镜像推送失败: $source_image -> $target_image"
        if [[ -f /tmp/skopeo.log ]]; then
            log::debug "错误日志:"
            cat /tmp/skopeo.log | head -20
        fi
        return 1
    fi
}

# 生成重命名镜像地址
# @param $1 原始镜像地址
# @param $2 目标Registry地址
# @param $3 项目/命名空间前缀 (可选)
# @return 重命名后的镜像地址
image_push::generate_renamed_image() {
    local source_image="$1"
    local target_registry="$2"
    local prefix="${3:-}"

    # 提取镜像名称和标签
    local image_name="${source_image##*/}"
    local image_tag="${image_name##*:}"
    if [[ "$image_name" == "$image_tag" ]]; then
        image_tag="latest"
    fi

    # 移除标签获取基础名称
    local base_name="${image_name%:*}"

    # 构建新镜像地址
    local renamed_image
    if [[ -n "$prefix" ]]; then
        renamed_image="${target_registry}/${prefix}/${base_name}:${image_tag}"
    else
        renamed_image="${target_registry}/${base_name}:${image_tag}"
    fi

    echo "$renamed_image"
}

#######################################
# 移除镜像地址中的Registry前缀（保留路径和标签）
# Arguments:
#   $1 - 完整镜像地址
# Returns:
#   镜像路径(去除registry)
#######################################
image_push::strip_registry() {
    local image="$1"
    local path="$image"

    if [[ "$image" == */* ]]; then
        local first="${image%%/*}"
        if [[ "$first" == *.* || "$first" == *:* || "$first" == "localhost" ]]; then
            path="${image#*/}"
        fi
    fi

    echo "$path"
}

# 推送双镜像（原始 + 重命名）
# @param $1 源镜像地址
# @param $2 目标Registry地址
# @param $3 项目前缀 (可选)
# @return 0 if success, 1 if failed
image_push::dual() {
    local source_image="$1"
    local target_registry="$2"
    local prefix="${3:-}"

    log::info "开始双镜像推送: $source_image"

    # 生成重命名镜像地址
    local renamed_image
    renamed_image=$(image_push::generate_renamed_image "$source_image" "$target_registry" "$prefix")

    # 推送原始镜像（保留路径，去除registry）
    local original_image_name
    original_image_name="$(image_push::strip_registry "$source_image")"

    if ! image_push::single "$source_image" "${target_registry}/${original_image_name}" "$target_registry"; then
        log::error "原始镜像推送失败"
        return 1
    fi

    # 推送重命名镜像
    if ! image_push::single "$source_image" "$renamed_image" "$target_registry"; then
        log::error "重命名镜像推送失败"
        return 1
    fi

    log::info "双镜像推送完成:"
    log::info "  原始镜像: ${target_registry}/${original_image_name}"
    log::info "  重命名镜像: $renamed_image"
    return 0
}

# 创建manifest
# @param $1 manifest名称
# @param $2 镜像列表
# @param $3 目标镜像地址 (可选)
# @return 0 if success, 1 if failed
image_push::manifest_create() {
    local manifest_name="$1"
    local image_list="$2"
    local target_image="${3:-}"

    log::info "创建manifest: $manifest_name"

    if ! command -v manifest-tool &> /dev/null; then
        log::error "manifest-tool 未安装，无法创建manifest"
        return 1
    fi

    # 如果指定了目标镜像，使用它；否则使用manifest名称
    local manifest_image="${manifest_name}"
    if [[ -n "$target_image" ]]; then
        manifest_image="$target_image"
    fi

    # 构建manifest命令
    local -a manifest_cmd=(manifest-tool push from-args)

    # 处理镜像列表
    local image
    while IFS= read -r image; do
        if [[ -n "$image" ]] && [[ "$image" != "#"* ]]; then
            manifest_cmd+=(--images "$image")
        fi
    done <<< "$image_list"

    # 推送manifest
    manifest_cmd+=(--template "$manifest_image")
    if "${manifest_cmd[@]}"; then
        log::info "Manifest创建成功: $manifest_image"
        return 0
    else
        log::error "Manifest创建失败"
        return 1
    fi
}

# 生成镜像列表
# @param $1 输出文件路径
# @param $2 镜像源列表 (可选)
# @return 0 if success, 1 if failed
image_push::generate_list() {
    local output_file="$1"
    local source_list="${2:-}"

    log::info "生成镜像列表: $output_file"

    # 创建输出目录
    mkdir -p "$(dirname "$output_file")"

    # 如果提供了源列表，复制并过滤
    if [[ -n "$source_list" ]] && [[ -f "$source_list" ]]; then
        grep -v '^#' "$source_list" | grep -v '^$' > "$output_file"
    else
        # 获取默认 Kubernetes 版本
        local k8s_version="v1.32"
        local k8s_patch
        k8s_patch=$(versions::get "kubernetes" "${k8s_version}")
        local coredns_version
        coredns_version=$(versions::get "coredns" "${k8s_version}")
        local etcd_version
        etcd_version=$(versions::get "etcd" "${k8s_version}")
        local containerd_version
        containerd_version=$(versions::get "containerd" "${k8s_version}")
        local calico_version
        calico_version=$(versions::get "calico" "${k8s_version}")
        local calico_tag
        calico_tag=$(versions::get_calico_tag "${calico_version}")

        # 生成默认镜像列表
        cat > "$output_file" << EOF
# Kubernetes Core Components
docker.io/library/kube-apiserver:${k8s_patch}
docker.io/library/kube-controller-manager:${k8s_patch}
docker.io/library/kube-scheduler:${k8s_patch}
docker.io/library/kube-proxy:${k8s_patch}
docker.io/library/coredns/coredns:${coredns_version}
docker.io/library/etcd:${etcd_version}

# Container Runtime
docker.io/library/containerd:${containerd_version}
docker.io/library/pause:3.9

# CNI Plugins
docker.io/calico/cni:${calico_tag}
docker.io/calico/node:${calico_tag}
docker.io/calico/pod2daemon-flexvol:${calico_tag}
docker.io/calico/typha:${calico_tag}
EOF
    fi

    log::info "镜像列表已生成: $output_file"
    log::info "镜像数量: $(grep -v '^#' "$output_file" | grep -v '^$' | wc -l)"
    return 0
}

# 批量推送镜像
# @param $1 镜像列表文件
# @param $2 目标Registry地址
# @param $3 是否启用双镜像推送 (可选: true/false)
# @param $4 是否启用manifest (可选: true/false)
# @return 0 if success, 1 if failed
image_push::batch() {
    local image_list_file="$1"
    local target_registry="$2"
    local enable_dual="${3:-false}"
    local enable_manifest="${4:-false}"

    if [[ ! -f "$image_list_file" ]]; then
        log::error "镜像列表文件不存在: $image_list_file"
        return 1
    fi

    log::info "开始批量推送镜像到: $target_registry"
    log::info "镜像列表: $image_list_file"
    log::info "双镜像模式: $enable_dual"
    log::info "Manifest模式: $enable_manifest"

    # 读取镜像列表
    local images
    images=$(grep -v '^#' "$image_list_file" | grep -v '^$')

    # 推送计数
    local success_count=0
    local fail_count=0

    # 推送每个镜像
    local image
    while IFS= read -r image; do
        if [[ -z "$image" ]]; then
            continue
        fi

        log::info "处理镜像: $image"

        if [[ "$enable_dual" == "true" ]]; then
            if image_push::dual "$image" "$target_registry"; then
                ((success_count++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
            else
                ((fail_count++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
            fi
        else
            local image_path
            image_path="$(image_push::strip_registry "$image")"
            local target_image="${target_registry}/${image_path}"
            if image_push::single "$image" "$target_image" "$target_registry"; then
                ((success_count++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
            else
                ((fail_count++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
            fi
        fi

    done <<< "$images"

    log::info "批量推送完成"
    log::info "成功: $success_count, 失败: $fail_count"

    # 如果启用manifest且有镜像成功推送，创建manifest
    if [[ "$enable_manifest" == "true" ]] && [[ $success_count -gt 0 ]]; then
        log::info "生成manifest..."

        # 收集成功推送的镜像（这里简化处理，实际应该记录成功推送的镜像）
        local manifest_images=""
        while IFS= read -r image; do
            if [[ -z "$image" ]]; then
                continue
            fi
            local image_path
            image_path="$(image_push::strip_registry "$image")"
            manifest_images+="${target_registry}/${image_path}"$'\n'
        done <<< "$images"

        if [[ -n "$manifest_images" ]]; then
            local manifest_name="${target_registry}/kubexm/manifests/latest"
            if image_push::manifest_create "$manifest_name" "$manifest_images" "$manifest_name"; then
                log::info "Manifest创建成功"
            else
                log::warn "Manifest创建失败"
            fi
        fi
    fi

    if [[ $fail_count -eq 0 ]]; then
        log::info "所有镜像推送成功"
        return 0
    else
        log::error "$fail_count 个镜像推送失败"
        return 1
    fi
}

# 从镜像列表文件推送（包装 batch）
# @param $1 镜像列表文件
# @param $2 目标Registry地址
# @param $3 是否启用双镜像推送
# @param $4 是否启用manifest
image_push::push_from_list() {
    image_push::batch "$@"
}

# 验证镜像推送
# @param $1 镜像地址
# @param $2 Registry地址 (可选)
# @return 0 if exists, 1 if not
image_push::verify() {
    local image="$1"
    local registry="${2:-}"

    log::debug "验证镜像: $image"

    # 尝试拉取镜像以验证
    local -a verify_cmd=(skopeo inspect)
    if [[ -n "$registry" ]]; then
        verify_cmd+=(--tls-verify=false)
    fi
    verify_cmd+=("docker://${image}")

    if "${verify_cmd[@]}" >/dev/null 2>&1; then
        log::debug "镜像验证成功: $image"
        return 0
    else
        log::debug "镜像验证失败: $image"
        return 1
    fi
}

# ==============================================================================
# 日志函数
# ==============================================================================

log::info() {
    echo -e "\033[32m[INFO]\033[0m $*"
}

log::warn() {
    echo -e "\033[33m[WARN]\033[0m $*"
}

log::error() {
    echo -e "\033[31m[ERROR]\033[0m $*" >&2
}

log::debug() {
    if [[ "${KUBEXM_DEBUG:-0}" == "1" ]]; then
        echo -e "\033[36m[DEBUG]\033[0m $*"
    fi
}

# ==============================================================================
# Skopeo 专用函数
# ==============================================================================

# 检查Skopeo是否安装
# @return 0 if installed, 1 if not
skopeo::check() {
    if ! command -v skopeo &> /dev/null; then
        log::error "Skopeo未安装，请先安装Skopeo"
        log::info "安装命令:"
        log::info "  CentOS/RHEL: yum install -y skopeo"
        log::info "  Ubuntu/Debian: apt install -y skopeo"
        log::info "  macOS: brew install skopeo"
        return 1
    fi
    return 0
}

# 使用Skopeo下载镜像到OCI目录格式
# @param $1 源镜像地址
# @param $2 目标目录
# @param $3 架构 (可选: amd64, arm64)
# @return 0 if success, 1 if failed
skopeo::download() {
    local source_image="$1"
    local output_dir="$2"
    local arch="${3:-}"

    skopeo::check || return 1

    # 创建输出目录
    mkdir -p "$output_dir"

    # 解析镜像名称
    local image_name="${source_image##*/}"
    image_name="${image_name%:*}"
    local image_tag="${source_image##*:}"
    [[ "$image_tag" == "$source_image" ]] && image_tag="latest"

    # 确定OCI目录路径
    local oci_dir="${output_dir}/${image_name}-${image_tag}"
    [[ -n "$arch" ]] && oci_dir="${oci_dir}-${arch}"

    log::info "下载镜像: $source_image -> $oci_dir"

    # 构建skopeo命令
    local -a cmd=(skopeo copy $SKOPEO_OPTS $SKOPEO_SRC_TLS)
    [[ -n "$arch" ]] && cmd+=(--override-arch "$arch")
    cmd+=("docker://${source_image}" "oci:${oci_dir}")

    if "${cmd[@]}" 2>&1; then
        log::info "镜像下载成功: $oci_dir"
        return 0
    else
        log::error "镜像下载失败: $source_image"
        return 1
    fi
}

# 使用Skopeo复制镜像 (docker to docker)
# @param $1 源镜像地址
# @param $2 目标镜像地址
# @return 0 if success, 1 if failed
skopeo::copy() {
    local src="$1"
    local dst="$2"

    skopeo::check || return 1

    log::info "复制镜像: $src -> $dst"

    local -a cmd=(skopeo copy $SKOPEO_OPTS $SKOPEO_SRC_TLS $SKOPEO_DEST_TLS)
    cmd+=("docker://${src}" "docker://${dst}")

    if "${cmd[@]}" 2>&1; then
        log::info "镜像复制成功: $dst"
        return 0
    else
        log::error "镜像复制失败: $src -> $dst"
        return 1
    fi
}

# 使用Skopeo从OCI目录推送到Registry
# @param $1 OCI目录路径
# @param $2 目标镜像地址
# @return 0 if success, 1 if failed
skopeo::push_from_oci() {
    local oci_dir="$1"
    local target="$2"

    skopeo::check || return 1

    if [[ ! -d "$oci_dir" ]]; then
        log::error "OCI目录不存在: $oci_dir"
        return 1
    fi

    log::info "推送镜像: $oci_dir -> $target"

    local -a cmd=(skopeo copy $SKOPEO_OPTS $SKOPEO_DEST_TLS)
    cmd+=("oci:${oci_dir}" "docker://${target}")

    if "${cmd[@]}" 2>&1; then
        log::info "镜像推送成功: $target"
        return 0
    else
        log::error "镜像推送失败: $target"
        return 1
    fi
}

# 使用Skopeo检查镜像信息
# @param $1 镜像地址
# @return 0 if exists, 1 if not
skopeo::inspect() {
    local image="$1"

    skopeo::check || return 1

    local -a cmd=(skopeo inspect $SKOPEO_DEST_TLS "docker://${image}")

    if "${cmd[@]}" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# 获取镜像digest
# @param $1 镜像地址
# @return digest string
skopeo::get_digest() {
    local image="$1"

    skopeo::check || return 1

    skopeo inspect $SKOPEO_DEST_TLS --format '{{.Digest}}' "docker://$image" 2>/dev/null
}

# ==============================================================================
# 多架构 Manifest 函数
# ==============================================================================

# 创建并推送多架构manifest (使用manifest-tool或buildah)
# @param $1 基础镜像名 (不含架构后缀)
# @param $2 目标Registry
# @param $3 架构列表 (逗号分隔, 如 "amd64,arm64")
# @return 0 if success, 1 if failed
manifest::create_and_push() {
    local base_image="$1"
    local registry="$2"
    local archs="${3:-amd64,arm64}"

    log::info "创建多架构manifest: $base_image"

    # 检查manifest-tool是否可用
    if command -v manifest-tool &> /dev/null; then
        manifest::create_with_manifest_tool "$base_image" "$registry" "$archs"
        return $?
    fi

    # 检查buildah是否可用
    if command -v buildah &> /dev/null; then
        manifest::create_with_buildah "$base_image" "$registry" "$archs"
        return $?
    fi

    # 检查podman是否可用
    if command -v podman &> /dev/null; then
        manifest::create_with_podman "$base_image" "$registry" "$archs"
        return $?
    fi

    log::error "无法创建manifest: 需要安装 manifest-tool, buildah 或 podman"
    return 1
}

# 使用manifest-tool创建manifest
manifest::create_with_manifest_tool() {
    local base_image="$1"
    local registry="$2"
    local archs="$3"

    log::info "使用manifest-tool创建manifest"

    # 构建参数
    local platforms=""
    IFS=',' read -ra ARCH_ARRAY <<< "$archs"
    for arch in "${ARCH_ARRAY[@]}"; do
        [[ -n "$platforms" ]] && platforms="$platforms,"
        platforms="${platforms}linux/${arch}"
    done

    local target="${registry}/${base_image}"
    local template="${registry}/${base_image}-ARCH"

    manifest-tool push from-args \
        --platforms "$platforms" \
        --template "$template" \
        --target "$target" \
        --ignore-missing

    return $?
}

# 使用buildah创建manifest
manifest::create_with_buildah() {
    local base_image="$1"
    local registry="$2"
    local archs="$3"

    log::info "使用buildah创建manifest"

    local manifest_name="${registry}/${base_image}"

    # 删除旧manifest
    buildah manifest rm "$manifest_name" 2>/dev/null || true

    # 创建新manifest
    buildah manifest create "$manifest_name"

    # 添加各架构镜像
    IFS=',' read -ra ARCH_ARRAY <<< "$archs"
    for arch in "${ARCH_ARRAY[@]}"; do
        local arch_image="${registry}/${base_image}-${arch}"
        if skopeo::inspect "$arch_image"; then
            buildah manifest add "$manifest_name" "docker://${arch_image}"
        else
            log::warn "镜像不存在，跳过: $arch_image"
        fi
    done

    # 推送manifest
    buildah manifest push --all "$manifest_name" "docker://${manifest_name}"

    return $?
}

# 使用podman创建manifest
manifest::create_with_podman() {
    local base_image="$1"
    local registry="$2"
    local archs="$3"

    log::info "使用podman创建manifest"

    local manifest_name="${registry}/${base_image}"

    # 删除旧manifest
    podman manifest rm "$manifest_name" 2>/dev/null || true

    # 创建新manifest
    podman manifest create "$manifest_name"

    # 添加各架构镜像
    IFS=',' read -ra ARCH_ARRAY <<< "$archs"
    for arch in "${ARCH_ARRAY[@]}"; do
        local arch_image="${registry}/${base_image}-${arch}"
        if skopeo::inspect "$arch_image"; then
            podman manifest add "$manifest_name" "docker://${arch_image}"
        else
            log::warn "镜像不存在，跳过: $arch_image"
        fi
    done

    # 推送manifest
    podman manifest push --all "$manifest_name" "docker://${manifest_name}"

    return $?
}

log::debug "Image push module (Skopeo-based) loaded successfully"
