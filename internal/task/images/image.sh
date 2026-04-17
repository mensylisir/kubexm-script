#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Image Manager
# ==============================================================================
# 管理Kubernetes镜像的下载、推送和存储
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

# 获取项目根目录
KUBEXM_SCRIPT_ROOT="${KUBEXM_SCRIPT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# 加载依赖
source "${KUBEXM_SCRIPT_ROOT}/internal/logger/log.sh"

# ==============================================================================
# 镜像管理
# ==============================================================================

#######################################
# 下载镜像
# Arguments:
#   $1 - 镜像列表文件
#   $2 - 目标目录
# Returns:
#   0 on success, 1 on failure
#######################################
image::pull_images() {
  local image_list_file="$1"
  local output_dir="$2"

  log::info "Pulling images from list: ${image_list_file}"

  if [[ ! -f "${image_list_file}" ]]; then
    log::error "Image list file not found: ${image_list_file}"
    return 1
  fi

  mkdir -p "${output_dir}"

  # 检查crictl命令
  if ! command -v crictl &>/dev/null; then
    log::error "crictl not found. Please install containerd."
    return 1
  fi

  local image_count=0
  local success_count=0
  local failed_count=0

  # 读取镜像列表并下载
  while IFS= read -r image; do
    # 跳过注释和空行
    [[ "$image" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${image// /}" ]] && continue

    ((image_count++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e

    log::info "[${image_count}] Pulling image: ${image}"

    # 下载镜像
    if crictl pull "${image}" >/dev/null 2>&1; then
      log::success "  ✓ Image pulled: ${image}"
      ((success_count++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
    else
      log::error "  ✗ Failed to pull image: ${image}"
      ((failed_count++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
    fi
  done < "${image_list_file}"

  log::info "Image pulling completed"
  log::info "  Total: ${image_count}"
  log::info "  Success: ${success_count}"
  log::info "  Failed: ${failed_count}"

  if [[ ${failed_count} -eq 0 ]]; then
    log::success "All images pulled successfully"
    return 0
  else
    log::error "Failed to pull ${failed_count} image(s)"
    return 1
  fi
}

#######################################
# 保存镜像到tar文件
# Arguments:
#   $1 - 镜像名称
#   $2 - 输出文件路径
# Returns:
#   0 on success, 1 on failure
#######################################
image::save_image() {
  local image_name="$1"
  local output_file="$2"

  log::info "Saving image: ${image_name} to ${output_file}"

  # 检查docker命令
  if ! command -v docker &>/dev/null; then
    log::error "docker not found. Please install Docker."
    return 1
  fi

  # 保存镜像
  if docker save "${image_name}" -o "${output_file}" >/dev/null 2>&1; then
    log::success "Image saved: ${output_file}"
    return 0
  else
    log::error "Failed to save image: ${image_name}"
    return 1
  fi
}

#######################################
# 加载镜像从tar文件
# Arguments:
#   $1 - 输入文件路径
# Returns:
#   0 on success, 1 on failure
#######################################
image::load_image() {
  local input_file="$1"

  log::info "Loading image from: ${input_file}"

  if [[ ! -f "${input_file}" ]]; then
    log::error "Image file not found: ${input_file}"
    return 1
  fi

  # 检查docker命令
  if ! command -v docker &>/dev/null; then
    log::error "docker not found. Please install Docker."
    return 1
  fi

  # 加载镜像
  if docker load -i "${input_file}" >/dev/null 2>&1; then
    log::success "Image loaded: ${input_file}"
    return 0
  else
    log::error "Failed to load image: ${input_file}"
    return 1
  fi
}

#######################################
# 推送镜像到私有registry
# Arguments:
#   $1 - 镜像名称
#   $2 - 私有registry地址
# Returns:
#   0 on success, 1 on failure
#######################################
image::push_image() {
  local image_name="$1"
  local registry="$2"

  log::info "Pushing image: ${image_name} to ${registry}"

  # 构建新的镜像名
  local new_image_name="${registry}/${image_name}"

  # 标记镜像
  if ! docker tag "${image_name}" "${new_image_name}"; then
    log::error "Failed to tag image: ${image_name}"
    return 1
  fi

  # 推送镜像
  if docker push "${new_image_name}" >/dev/null 2>&1; then
    log::success "Image pushed: ${new_image_name}"
    # 清理标记的镜像
    docker rmi "${new_image_name}" >/dev/null 2>&1
    return 0
  else
    log::error "Failed to push image: ${new_image_name}"
    # 清理标记的镜像
    docker rmi "${new_image_name}" >/dev/null 2>&1
    return 1
  fi
}

#######################################
# 从私有registry拉取镜像
# Arguments:
#   $1 - 镜像名称
#   $2 - 私有registry地址
# Returns:
#   0 on success, 1 on failure
#######################################
image::pull_from_registry() {
  local image_name="$1"
  local registry="$2"

  log::info "Pulling image: ${image_name} from ${registry}"

  # 构建新的镜像名
  local registry_image_name="${registry}/${image_name}"

  # 拉取镜像
  if docker pull "${registry_image_name}" >/dev/null 2>&1; then
    log::success "Image pulled: ${registry_image_name}"
    return 0
  else
    log::error "Failed to pull image: ${registry_image_name}"
    return 1
  fi
}

#######################################
# 生成镜像列表文件
# Arguments:
#   $1 - 输出文件路径
#   $2 - Kubernetes版本 (可选，默认使用 DEFAULT_KUBERNETES_VERSION)
# Returns:
#   0 on success, 1 on failure
#######################################
image::generate_image_list() {
  local output_file="$1"
  local k8s_version="${2:-${DEFAULT_KUBERNETES_VERSION:-v1.32.4}}"

  log::info "Generating image list: ${output_file} (Kubernetes: ${k8s_version})"

  # 定义默认镜像列表
  cat > "${output_file}" << EOF
# Kubernetes Core Components
registry.aliyuncs.com/google_containers/kube-apiserver:${k8s_version}
registry.aliyuncs.com/google_containers/kube-controller-manager:${k8s_version}
registry.aliyuncs.com/google_containers/kube-scheduler:${k8s_version}
registry.aliyuncs.com/google_containers/kube-proxy:${k8s_version}
registry.aliyuncs.com/google_containers/pause:3.10
registry.aliyuncs.com/google_containers/coredns:v1.11.1
registry.aliyuncs.com/google_containers/etcd:3.5.13-0

# CNI Plugins
calico/cni:v3.27.0
calico/node:v3.27.0
calico/pod2daemon-flexvol:v3.27.0
calico/kube-controllers:v3.27.0
calico/typha:v3.27.0

# Addons
registry.aliyuncs.com/google_containers/ingress-nginx-controller:v1.8.2
registry.aliyuncs.com/google_containers/metrics-server:v0.7.0
registry.aliyuncs.com/google_containers/local-path-provisioner:v0.0.24

# Storage
registry.aliyuncs.com/google_containers/nfs-subdir-external-provisioner:v4.0.2
EOF

  log::success "Image list generated: ${output_file}"
  return 0
}

#######################################
# 批量保存镜像
# Arguments:
#   $1 - 镜像列表文件
#   $2 - 输出目录
# Returns:
#   0 on success, 1 on failure
#######################################
image::save_images() {
  local image_list_file="$1"
  local output_dir="$2"

  log::info "Saving images from list: ${image_list_file}"

  if [[ ! -f "${image_list_file}" ]]; then
    log::error "Image list file not found: ${image_list_file}"
    return 1
  fi

  mkdir -p "${output_dir}"

  local image_count=0
  local success_count=0
  local failed_count=0

  # 读取镜像列表并保存
  while IFS= read -r image; do
    # 跳过注释和空行
    [[ "$image" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${image// /}" ]] && continue

    ((image_count++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e

    # 生成文件名
    local image_file
    image_file=$(echo "${image}" | sed 's/[\/:]/-/g')
    local output_file="${output_dir}/${image_file}.tar"

    log::info "[${image_count}] Saving image: ${image}"

    # 保存镜像
    if image::save_image "${image}" "${output_file}"; then
      ((success_count++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
    else
      ((failed_count++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
    fi
  done < "${image_list_file}"

  log::info "Image saving completed"
  log::info "  Total: ${image_count}"
  log::info "  Success: ${success_count}"
  log::info "  Failed: ${failed_count}"

  if [[ ${failed_count} -eq 0 ]]; then
    log::success "All images saved successfully"
    return 0
  else
    log::error "Failed to save ${failed_count} image(s)"
    return 1
  fi
}

#######################################
# 批量加载镜像
# Arguments:
#   $1 - 镜像目录
# Returns:
#   0 on success, 1 on failure
#######################################
image::load_images() {
  local images_dir="$1"

  log::info "Loading images from directory: ${images_dir}"

  if [[ ! -d "${images_dir}" ]]; then
    log::error "Images directory not found: ${images_dir}"
    return 1
  fi

  local image_count=0
  local success_count=0
  local failed_count=0

  # 查找所有tar文件并加载
  for tar_file in "${images_dir}"/*.tar; do
    if [[ -f "${tar_file}" ]]; then
      ((image_count++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e

      log::info "[${image_count}] Loading image: ${tar_file}"

      # 加载镜像
      if image::load_image "${tar_file}"; then
        ((success_count++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
      else
        ((failed_count++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
      fi
    fi
  done

  log::info "Image loading completed"
  log::info "  Total: ${image_count}"
  log::info "  Success: ${success_count}"
  log::info "  Failed: ${failed_count}"

  if [[ ${failed_count} -eq 0 ]]; then
    log::success "All images loaded successfully"
    return 0
  else
    log::error "Failed to load ${failed_count} image(s)"
    return 1
  fi
}

# 导出函数
export -f image::pull_images
export -f image::save_image
export -f image::load_image
export -f image::push_image
export -f image::pull_from_registry
export -f image::generate_image_list
export -f image::save_images
export -f image::load_images
