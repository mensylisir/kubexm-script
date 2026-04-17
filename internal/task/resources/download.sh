#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Download Phase
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

# 获取脚本目录
KUBEXM_SCRIPT_ROOT="${KUBEXM_SCRIPT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
KUBEXM_ROOT="${KUBEXM_ROOT:-$KUBEXM_SCRIPT_ROOT}"

# 加载核心模块
source "${KUBEXM_SCRIPT_ROOT}/internal/logger/log.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/config.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/defaults.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/versions.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/common.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/image_manager.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/helm_manager.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/resources/system_iso.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/resources/build_iso.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/utils/resources/build_docker.sh"

# ==============================================================================
# Checkpoint System (断点续传支持)
# ==============================================================================

# Checkpoint file location
DOWNLOAD_CHECKPOINT_FILE="${KUBEXM_DATA_DIR:-${PWD}/.kubexm}/.download_checkpoint"

#######################################
# 保存检查点
# Arguments:
#   $1 - 阶段名称
#   $2 - 完成状态 (done/failed)
#######################################
checkpoint::save() {
  local phase="$1"
  local status="${2:-done}"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  mkdir -p "$(dirname "${DOWNLOAD_CHECKPOINT_FILE}")"
  echo "${phase}|${status}|${timestamp}" >> "${DOWNLOAD_CHECKPOINT_FILE}"
  log::debug "Checkpoint saved: ${phase} = ${status}"
}

#######################################
# 检查阶段是否已完成
# Arguments:
#   $1 - 阶段名称
# Returns:
#   0 if completed successfully, 1 if not or failed
#######################################
checkpoint::is_done() {
  local phase="$1"

  if [[ ! -f "${DOWNLOAD_CHECKPOINT_FILE}" ]]; then
    return 1
  fi

  # 检查是否有成功完成的记录
  if grep -q "^${phase}|done|" "${DOWNLOAD_CHECKPOINT_FILE}"; then
    # 检查是否有后续的失败记录（如果有，需要重试）
    local last_status
    last_status=$(grep "^${phase}|" "${DOWNLOAD_CHECKPOINT_FILE}" | tail -1 | cut -d'|' -f2)
    if [[ "${last_status}" == "done" ]]; then
      return 0
    else
      log::info "Phase ${phase} previously failed, will retry"
      return 1
    fi
  fi
  return 1
}

#######################################
# 检查阶段是否失败
# Arguments:
#   $1 - 阶段名称
# Returns:
#   0 if failed, 1 if not
#######################################
checkpoint::is_failed() {
  local phase="$1"

  if [[ ! -f "${DOWNLOAD_CHECKPOINT_FILE}" ]]; then
    return 1
  fi

  local last_status
  last_status=$(grep "^${phase}|" "${DOWNLOAD_CHECKPOINT_FILE}" | tail -1 | cut -d'|' -f2)
  if [[ "${last_status}" == "failed" ]]; then
    return 0
  fi
  return 1
}

#######################################
# 获取最后完成的阶段
#######################################
checkpoint::get_last() {
  if [[ -f "${DOWNLOAD_CHECKPOINT_FILE}" ]]; then
    tail -1 "${DOWNLOAD_CHECKPOINT_FILE}" | cut -d'|' -f1
  fi
}

#######################################
# 清除检查点 (下载完成后调用)
#######################################
checkpoint::clear() {
  if [[ -f "${DOWNLOAD_CHECKPOINT_FILE}" ]]; then
    rm -f "${DOWNLOAD_CHECKPOINT_FILE}"
    log::info "Checkpoints cleared"
  fi
}

#######################################
# 显示检查点状态
#######################################
checkpoint::status() {
  if [[ -f "${DOWNLOAD_CHECKPOINT_FILE}" ]]; then
    log::info "Download checkpoint status:"
    local count=0
    while IFS='|' read -r phase status timestamp; do
      log::info "  ${phase}: ${status} (${timestamp})"
      ((count++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
    done < "${DOWNLOAD_CHECKPOINT_FILE}"
    log::info "Total completed phases: ${count}"
  else
    log::info "No checkpoint found - fresh download"
  fi
}

# ==============================================================================
# Download Context
# ==============================================================================

download::init_context() {
  : "${KUBEXM_ROOT:?KUBEXM_ROOT is required}"

  DOWNLOAD_DIR="${KUBEXM_DATA_DIR:-${PWD}/.kubexm}/downloads"
  DOWNLOAD_K8S_VERSION="${KUBEXM_KUBERNETES_VERSION:-$(defaults::get_kubernetes_version)}"
  DOWNLOAD_K8S_TYPE="${KUBEXM_KUBERNETES_TYPE:-$(defaults::get_kubernetes_type)}"
  DOWNLOAD_ETCD_TYPE="${KUBEXM_ETCD_TYPE:-$(defaults::get_etcd_type)}"
  DOWNLOAD_RUNTIME_TYPE="${KUBEXM_CONTAINER_RUNTIME:-$(defaults::get_runtime_type)}"
  DOWNLOAD_NETWORK_PLUGIN="${KUBEXM_CNI_PLUGIN:-$(defaults::get_cni_plugin)}"
  DOWNLOAD_ARCH_LIST="${KUBEXM_BUILD_ARCH:-$(defaults::get_arch_list)}"
  DOWNLOAD_ARCH_LIST="${DOWNLOAD_ARCH_LIST//,/ }"
  DOWNLOAD_LB_ENABLED="${KUBEXM_LB_ENABLED:-$(defaults::get_loadbalancer_enabled)}"
  DOWNLOAD_LB_MODE="${KUBEXM_LB_MODE:-$(defaults::get_loadbalancer_mode)}"
  DOWNLOAD_LB_TYPE="${KUBEXM_LB_TYPE:-$(defaults::get_loadbalancer_type)}"

  DOWNLOAD_CONTAINERD_VERSION="$(versions::get "containerd" "${DOWNLOAD_K8S_VERSION}")"
  DOWNLOAD_RUNC_VERSION="$(versions::get "runc" "${DOWNLOAD_K8S_VERSION}")"
  DOWNLOAD_CRICTL_VERSION="$(versions::get "crictl" "${DOWNLOAD_K8S_VERSION}")"
  DOWNLOAD_CNI_VERSION="$(versions::get "cni" "${DOWNLOAD_K8S_VERSION}")"
  DOWNLOAD_HELM_VERSION="$(versions::get "helm" "${DOWNLOAD_K8S_VERSION}")"
  DOWNLOAD_CALICO_VERSION="$(versions::get "calico" "${DOWNLOAD_K8S_VERSION}" 2>/dev/null || true)"

  DOWNLOAD_REGISTRY_ENABLED="$(config::get "spec.registry.enable" "false" 2>/dev/null || echo "false")"
  DOWNLOAD_REGISTRY_VERSION="$(config::get "spec.registry.version" "$(defaults::get_registry_version)" 2>/dev/null || defaults::get_registry_version)"

  DOWNLOAD_BUILD_ALL="${KUBEXM_BUILD_ALL:-false}"
  DOWNLOAD_BUILD_OS="${KUBEXM_BUILD_OS:-}"
  DOWNLOAD_BUILD_OS_VERSION="${KUBEXM_BUILD_OS_VERSION:-}"
  DOWNLOAD_BUILD_LOCAL="${KUBEXM_BUILD_LOCAL:-false}"
}

#######################################
# Ensure tool available (prefer packaged)
# Arguments:
#   $1 - tool name (skopeo/helm/...)
# Returns:
#   0 if available, 1 otherwise
#######################################
download::ensure_tool() {
  local tool="$1"

  if command -v "${tool}" >/dev/null 2>&1; then
    return 0
  fi

  local arch
  arch="$(utils::get_arch)"

  local tool_path=""
  case "${tool}" in
    skopeo|yq|jq|etcdctl)
      tool_path="${KUBEXM_ROOT}/packages/tools/common/${arch}/${tool}"
      ;;
    helm)
      local helm_version
      helm_version="${DOWNLOAD_HELM_VERSION:-$(versions::get "helm" "${DOWNLOAD_K8S_VERSION:-$(defaults::get_kubernetes_version)}")}"
      tool_path="${KUBEXM_ROOT}/packages/helm/${helm_version}/${arch}/helm"
      ;;
  esac

  if [[ -n "${tool_path}" && -f "${tool_path}" ]]; then
    chmod +x "${tool_path}" || true
    mkdir -p "${KUBEXM_ROOT}/bin"
    ln -sf "${tool_path}" "${KUBEXM_ROOT}/bin/${tool}"
    export PATH="${KUBEXM_ROOT}/bin:${KUBEXM_ROOT}/packages/tools/common/${arch}:${PATH}"
    return 0
  fi

  return 1
}

download::ensure_skopeo() { download::ensure_tool "skopeo"; }
download::ensure_helm() { download::ensure_tool "helm"; }

# 注意：旧的download-system-packages.sh已被废弃
# 现在使用 system_iso::build (Docker/本地构建系统包 ISO)



#######################################
# 下载 Helm chart 中的容器镜像
#######################################
download::download_helm_chart_images() {
  local charts_dir="$1"
  local output_dir="$2"

  # 检查 helm 和 skopeo 是否可用（优先使用已下载的离线二进制）
  if ! download::ensure_helm; then
    log::warn "  helm not available, skipping chart images"
    return 0
  fi

  if ! download::ensure_skopeo; then
    log::warn "  skopeo not available, skipping chart images"
    return 0
  fi

  log::info "Downloading Helm chart images..."

  for chart_dir in "${charts_dir}"/*/; do
    [[ ! -d "$chart_dir" ]] && continue
    local chart_name=$(basename "$chart_dir")
    log::info "  Processing chart: ${chart_name}"

    local image_count=0
    while IFS= read -r image; do
      [[ -z "$image" ]] && continue
      log::info "    Downloading image: ${image}"
      if download::download_single_image "$image" "${output_dir}"; then
        ((image_count++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
      fi
    done < <(helm_manager::extract_images "$chart_dir")

    if [[ ${image_count} -gt 0 ]]; then
      log::info "    Downloaded ${image_count} images from ${chart_name}"
    fi
  done
}

#######################################
# 下载单个容器镜像
#######################################
download::download_single_image() {
  local image="$1"
  local output_dir="$2"

  if ! download::ensure_skopeo; then
    log::error "Skopeo not available for image download"
    return 1
  fi

  # 清理镜像名用于目录名
  local image_name=$(echo "${image}" | tr '/' '_' | tr ':' '_')
  local image_dir="${output_dir}/${image_name}"

  # 检查镜像是否已存在且版本匹配
  if [[ -f "${image_dir}/manifest.json" ]]; then
    local expected_tag="${image##*:}"
    if [[ "${image_name}" == *"${expected_tag}"* ]]; then
      log::success "    ✓ ${image} already exists, skipping"
      download::record_image "${image}" "${output_dir}"
      return 0
    fi
  fi

  # 如果目录存在但不完整，删除它
  [[ -d "${image_dir}" ]] && rm -rf "${image_dir}"

  mkdir -p "${image_dir}"

  # 使用 skopeo 下载镜像 (带超时控制)
  if timeout 300 skopeo copy "docker://${image}" "dir:${image_dir}" 2>/dev/null; then
    log::success "    ✓ ${image} downloaded successfully"
    download::record_image "${image}" "${output_dir}"
    return 0
  else
    log::error "    ✗ Failed to download image ${image}"
    rm -rf "${image_dir}"
    return 1
  fi
}

#######################################
# 记录镜像清单（去重）
# Arguments:
#   $1 - 镜像地址
#   $2 - 输出目录（packages/images）
#######################################
download::record_image() {
  local image="$1"
  local output_dir="$2"
  local list_file="${output_dir}/images.list"
  if [[ -d "${output_dir}/images" ]]; then
    list_file="${output_dir}/images/images.list"
  fi

  mkdir -p "$(dirname "${list_file}")"
  if ! grep -Fxq "${image}" "${list_file}" 2>/dev/null; then
    echo "${image}" >> "${list_file}"
  fi
}

#######################################
# 从列表文件下载镜像
# Arguments:
#   $1 - 镜像列表文件路径
#   $2 - 输出目录
#######################################
download::download_images_from_list() {
  local list_file="$1"
  local output_dir="$2"

  if [[ ! -f "${list_file}" ]]; then
    log::warn "  Image list file not found: ${list_file}"
    return 0
  fi

  local total_images
  total_images=$(wc -l < "${list_file}")
  local current=0
  local success=0
  local failed=0

  log::info "  Downloading ${total_images} images from list..."

  while IFS= read -r image; do
    [[ -z "${image}" ]] && continue
    [[ "${image}" =~ ^# ]] && continue  # 跳过注释

    ((current++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e

    if download::download_single_image "${image}" "${output_dir}"; then
      ((success++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
    else
      ((failed++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
    fi
  done < "${list_file}"

  log::info "  Download complete: ${success} success, ${failed} failed"
}

#######################################
# 下载所有离线资源
#######################################
download::download_all() {
  local cluster_name="${1:-${KUBEXM_CLUSTER_NAME:-}}"
  log::info "=== Starting resource download for cluster: ${cluster_name} ==="

  # 注意：不再调用 config::load
  # 调用方应已设置必要的环境变量

  # 检查依赖
  if ! download::ensure_skopeo; then
    log::error "Skopeo未安装，这是下载镜像所必需的"
    return 1
  fi

  if ! command -v curl &> /dev/null; then
    log::error "curl未安装"
    return 1
  fi

  # 创建下载目录结构
  local download_dir="${KUBEXM_DATA_DIR:-${PWD}/.kubexm}/downloads"
  # 使用环境变量，提供安全的默认值回退
  local k8s_version="${KUBEXM_KUBERNETES_VERSION:-$(defaults::get_kubernetes_version)}"
  local k8s_type="${KUBEXM_KUBERNETES_TYPE:-$(defaults::get_kubernetes_type)}"
  local etcd_type="${KUBEXM_ETCD_TYPE:-$(defaults::get_etcd_type)}"
  local runtime_type="${KUBEXM_CONTAINER_RUNTIME:-$(defaults::get_runtime_type)}"
  local network_plugin="${KUBEXM_CNI_PLUGIN:-$(defaults::get_cni_plugin)}"
  local arch_list="${KUBEXM_BUILD_ARCH:-$(defaults::get_arch_list)}"
  local lb_enabled="${KUBEXM_LB_ENABLED:-$(defaults::get_loadbalancer_enabled)}"
  local lb_mode="${KUBEXM_LB_MODE:-$(defaults::get_loadbalancer_mode)}"
  local lb_type="${KUBEXM_LB_TYPE:-$(defaults::get_loadbalancer_type)}"

  # 将逗号分隔的架构列表转换为空格分隔（用于 for 循环）
  arch_list="${arch_list//,/ }"

  log::info "Creating package directory structure..."
  # 按照用户要求的结构组织包：packages/${component_name}/${component_version}/${arch}/
  # Kubernetes组件
  for arch in ${arch_list}; do
    log::info "  Creating: ${download_dir}/kubernetes/${k8s_version}/${arch}"
    mkdir -p "${download_dir}/kubernetes/${k8s_version}/${arch}"
  done


  # Containerd运行时
  local containerd_version
  containerd_version=$(versions::get "containerd" "${k8s_version}")
  for arch in ${arch_list}; do
    log::info "  Creating: ${download_dir}/containerd/${containerd_version}/${arch}"
    mkdir -p "${download_dir}/containerd/${containerd_version}/${arch}"
  done

  # Runc运行时
  local runc_version
  runc_version=$(versions::get "runc" "${k8s_version}")
  for arch in ${arch_list}; do
    log::info "  Creating: ${download_dir}/runc/${runc_version}/${arch}"
    mkdir -p "${download_dir}/runc/${runc_version}/${arch}"
  done

  # Crictl工具
  local crictl_version
  crictl_version=$(versions::get "crictl" "${k8s_version}")
  for arch in ${arch_list}; do
    log::info "  Creating: ${download_dir}/crictl/${crictl_version}/${arch}"
    mkdir -p "${download_dir}/crictl/${crictl_version}/${arch}"
  done

  # CNI插件
  local cni_version
  cni_version=$(versions::get "cni" "${k8s_version}")
  for arch in ${arch_list}; do
    log::info "  Creating: ${download_dir}/cni-plugins/${cni_version}/${arch}"
    mkdir -p "${download_dir}/cni-plugins/${cni_version}/${arch}"
  done

  # Calicoctl (如果使用 Calico)
  if [[ "${network_plugin}" == "calico" ]]; then
    local calicoctl_version
    calicoctl_version=$(versions::get "calico" "${k8s_version}")
    for arch in ${arch_list}; do
      log::info "  Creating: ${download_dir}/calicoctl/${calicoctl_version}/${arch}"
      mkdir -p "${download_dir}/calicoctl/${calicoctl_version}/${arch}"
    done
  fi

  log::info "  Creating: ${download_dir}/images"
  mkdir -p "${download_dir}/images"

  log::info "  Creating: ${download_dir}/helm"
  mkdir -p "${download_dir}/helm"

  log::info "  Creating: ${download_dir}/iso"
  mkdir -p "${download_dir}/iso"

  for arch in ${arch_list}; do
    log::info "  Creating: ${download_dir}/tools/common/${arch}"
    mkdir -p "${download_dir}/tools/common/${arch}"
  done

  # 显示检查点状态
  checkpoint::status

  # Phase: Common tools
  if checkpoint::is_done "tools_binaries"; then
    log::info "Skipping common tools (checkpoint exists)"
  else
    source "${KUBEXM_SCRIPT_ROOT}/internal/utils/common.sh"
    source "${KUBEXM_SCRIPT_ROOT}/internal/utils/binary_bom.sh"
    log::info "Downloading common tool binaries..."
    utils::binary::bom::download_common_tools "${arch_list}" "${download_dir}/tools"
    checkpoint::save "tools_binaries"
  fi

  # Phase: Kubernetes binaries
  if checkpoint::is_done "kubernetes_binaries"; then
    log::info "Skipping Kubernetes binaries (checkpoint exists)"
  else
    log::info "Downloading Kubernetes binaries (${k8s_type} mode)..."
    download::download_kubernetes_binaries "${download_dir}/kubernetes/${k8s_version}" "${k8s_version}" "${arch_list}" "${k8s_type}" "${etcd_type}"
    checkpoint::save "kubernetes_binaries"
  fi

  # Phase: CNI plugins
  if checkpoint::is_done "cni_plugins"; then
    log::info "Skipping CNI plugins (checkpoint exists)"
  else
    log::info "Downloading CNI plugins binaries..."
    for arch in ${arch_list}; do
      log::info "  Downloading CNI plugins for architecture: ${arch}"
      download::download_cni_binaries "${download_dir}/cni-plugins/${cni_version}/${arch}" "${k8s_version}" "${arch}"
    done
    checkpoint::save "cni_plugins"
  fi

  # Phase: Calicoctl (如果使用 Calico)
  if [[ "${network_plugin}" == "calico" ]]; then
    if checkpoint::is_done "calicoctl"; then
      log::info "Skipping calicoctl (checkpoint exists)"
    else
      local calicoctl_version
      calicoctl_version=$(versions::get "calico" "${k8s_version}")
      for arch in ${arch_list}; do
        log::info "  Downloading calicoctl for architecture: ${arch}"
        download::download_calicoctl_binary "${download_dir}/calicoctl/${calicoctl_version}/${arch}" "${k8s_version}" "${arch}"
      done
      checkpoint::save "calicoctl"
    fi
  fi

  # Phase: Container runtime
  if checkpoint::is_done "container_runtime"; then
    log::info "Skipping container runtime (checkpoint exists)"
  else
    log::info "Downloading container runtime binaries..."
    for arch in ${arch_list}; do
      log::info "  Downloading ${runtime_type} binaries for architecture: ${arch}"
      download::download_runtime_binaries \
        "${download_dir}/containerd/${containerd_version}/${arch}" \
        "${download_dir}/runc/${runc_version}/${arch}" \
        "${download_dir}/crictl/${crictl_version}/${arch}" \
        "${runtime_type}" "${k8s_version}" "${arch}"
    done
    checkpoint::save "container_runtime"
  fi

  # Phase: Helm binary
  if checkpoint::is_done "helm_binary"; then
    log::info "Skipping Helm binary (checkpoint exists)"
  else
    log::info "Downloading Helm binary..."
    local helm_version
    helm_version=$(versions::get "helm" "${k8s_version}")
    for arch in ${arch_list}; do
      log::info "  Downloading helm for architecture: ${arch}"
      download::download_helm_binary "${download_dir}/helm/${helm_version}/${arch}" "${k8s_version}" "${arch}"
    done
    checkpoint::save "helm_binary"
  fi

  # Phase: Registry binary
  local registry_enabled
  registry_enabled=$(config::get "spec.registry.enable" "false" 2>/dev/null || echo "false")
  if [[ "${registry_enabled}" == "true" ]]; then
    if checkpoint::is_done "registry_binary"; then
      log::info "Skipping registry binary (checkpoint exists)"
    else
      log::info "Registry is enabled, downloading registry binary..."
      local registry_version
      registry_version=$(config::get "spec.registry.version" "$(defaults::get_registry_version)" 2>/dev/null || defaults::get_registry_version)
      for arch in ${arch_list}; do
        log::info "  Downloading registry for architecture: ${arch}"
        download::download_registry_binary "${download_dir}/registry/${registry_version}/${arch}" "${registry_version}" "${arch}"
      done
      checkpoint::save "registry_binary"
    fi
  else
    log::info "Registry not enabled, skipping registry binary download"
  fi

  # Phase: Addon manifests
  if checkpoint::is_done "addon_manifests"; then
    log::info "Skipping addon manifests (checkpoint exists)"
  else
    log::info "Downloading addon manifests (CNI YAML)..."
    download::download_addon_manifests "${download_dir}" "${k8s_version}" "${network_plugin}"
    checkpoint::save "addon_manifests"
  fi

  # Phase: Container images (最耗时)
  if checkpoint::is_done "container_images"; then
    log::info "Skipping container images (checkpoint exists)"
  else
    log::info "Downloading container images..."
    download::download_container_images "${download_dir}/images" "${k8s_version}" "${network_plugin}" "${k8s_type}" "${etcd_type}" "${lb_enabled}" "${lb_mode}" "${lb_type}"
    checkpoint::save "container_images"
  fi

  # Phase: Helm charts
  if checkpoint::is_done "helm_charts"; then
    log::info "Skipping Helm charts (checkpoint exists)"
  else
    log::info "Downloading Helm charts..."
    download::download_helm_charts "${download_dir}/helm_packages"
    checkpoint::save "helm_charts"
  fi

  # Phase: Helm chart images
  if checkpoint::is_done "helm_chart_images"; then
    log::info "Skipping Helm chart images (checkpoint exists)"
  else
    log::info "Downloading Helm chart images..."
    download::download_helm_chart_images "${download_dir}/helm_packages" "${download_dir}/images"
    checkpoint::save "helm_chart_images"
  fi

  # 下载从 addon manifest 提取的镜像
  if [[ -f "${download_dir}/addon-images.list" ]]; then
    if checkpoint::is_done "addon_images"; then
      log::info "Skipping addon manifest images (checkpoint exists)"
    else
      log::info "Downloading addon manifest images..."
      download::download_images_from_list "${download_dir}/addon-images.list" "${download_dir}/images"
      checkpoint::save "addon_images"
    fi
  fi

  # 归档镜像清单（去重）
  local images_list="${download_dir}/images/images.list"
  if [[ -f "${images_list}" ]]; then
    sort -u "${images_list}" -o "${images_list}"
    log::info "Images list updated: ${images_list}"
  fi

  # 条件构建系统包 ISO - 简化逻辑
  local build_iso_params=""

  # 检查是否需要构建 ISO
  if [[ "${KUBEXM_BUILD_ALL:-false}" == "true" ]]; then
    build_iso_params="$(defaults::get_build_os_list)"
  elif [[ -n "${KUBEXM_BUILD_OS:-}${KUBEXM_BUILD_OS_VERSION:-}" ]]; then
    build_iso_params="${KUBEXM_BUILD_OS:-${KUBEXM_BUILD_OS_VERSION}}"
  fi

  # 执行 ISO 构建
  if [[ -n "$build_iso_params" ]]; then
    log::info "Building system packages ISO for: ${build_iso_params}"
    local first_arch=$(echo "${arch_list}" | cut -d',' -f1)
    local system_iso_base_dir="${download_dir}/iso"

    if system_iso::build_per_os "${system_iso_base_dir}" "${build_iso_params}" "${first_arch}" "${KUBEXM_BUILD_LOCAL:-false}"; then
      log::success "System packages ISO built successfully"
    else
      log::warn "System packages ISO build failed, continuing..."
    fi
  else
    log::info "Skipping system packages ISO build (use --with-build-os to enable)"
  fi

  log::info "Generating package manifest..."
  download::generate_package_manifest "${download_dir}" "${cluster_name}"

  # Check if offline build is enabled
  local offline_enabled="false"
  if config::get_offline_enabled 2>/dev/null | grep -q "true"; then
    offline_enabled="true"
  fi

  if [[ "${offline_enabled}" == "true" ]]; then
    log::info "Offline build enabled, building offline resources..."
    download::build_offline_resources "${download_dir}" "${cluster_name}"
  fi

  log::success "=== Resource download completed successfully ==="
  log::info "All resources downloaded to: ${download_dir}"
  return 0
}

#######################################
# 下载Kubernetes二进制文件
#######################################
download::download_kubernetes_binaries() {
  local output_dir="$1"
  local k8s_version="$2"
  local arch_list="$3"
  local k8s_type="${4:-$(defaults::get_kubernetes_type)}"
  local etcd_type="${5:-$(defaults::get_etcd_type)}"

  log::info "Downloading Kubernetes binaries version: ${k8s_version} (type: ${k8s_type}, etcd: ${etcd_type})"

  for arch in ${arch_list}; do
    log::info "Downloading for architecture: ${arch}"

    local arch_dir="${output_dir}/${arch}"
    mkdir -p "${arch_dir}"

    # 根据部署类型确定要下载的组件
    local components=()
    if [[ "${k8s_type}" == "kubeadm" ]]; then
      # kubeadm模式：只下载kubeadm, kubelet, kubectl（kube-proxy以容器部署）
      components=("kubeadm" "kubelet" "kubectl")
      log::info "  [Kubeadm mode] Downloading: kubeadm, kubelet, kubectl"
      log::info "  [Kubeadm mode] Skipping kube-proxy (deployed as DaemonSet)"
    elif [[ "${k8s_type}" == "kubexm" ]]; then
      # kubexm模式：下载所有控制平面组件
      components=("kube-apiserver" "kube-controller-manager" "kube-scheduler" "kubelet" "kubectl" "kube-proxy")
      log::info "  [Kubexm mode] Downloading all control plane components"
      log::info "  [Kubexm mode] Skipping kubeadm (not needed for binary deployment)"
    else
      log::error "Unknown Kubernetes deployment type: ${k8s_type}"
      return 1
    fi

    for component in "${components[@]}"; do
      log::info "  Downloading ${component} for ${arch}..."
      local output_file="${arch_dir}/${component}"
      local download_url
      download_url=$(versions::get_k8s_binary_url "${arch}" "${k8s_version}" "${component}")

      # 检查文件是否已存在
      if [[ -f "${output_file}" && -s "${output_file}" ]]; then
        # 通过路径中的版本信息判断（k8s_version 格式为 v1.32.0，组件路径包含这个版本）
        if [[ "${output_file}" == *"/${k8s_version}/"* ]] || \
           [[ "${output_file}" == *"${k8s_version#v}"* ]]; then
          log::success "  ✓ ${component} (${k8s_version}) already exists, skipping"
          continue
        else
          log::info "  ✓ Version mismatch, re-downloading..."
          rm -f "${output_file}"
        fi
      fi

      if curl -fL --connect-timeout 30 --max-time 600 "${download_url}" -o "${output_file}"; then
        chmod +x "${output_file}"
        log::success "  ✓ ${component} downloaded successfully"
      else
        log::error "  ✗ Failed to download ${component}"
        return 1
      fi
    done

    # 下载etcd服务器二进制（仅在external etcd模式下需要，即etcd_type为kubexm时）
    if [[ "${etcd_type}" == "kubexm" ]]; then
      log::info "  [External etcd mode] Downloading etcd server binaries..."

      # 获取etcd版本
      local etcd_version
      etcd_version=$(versions::get "etcd" "${k8s_version}") || {
        log::error "  Failed to get etcd version for ${k8s_version}"
        return 1
      }
      log::info "  Using etcd version: ${etcd_version}"

      # etcd 独立目录：packages/etcd/${etcd_version}/${arch}/
      # output_dir 是 ${download_dir}/kubernetes/${k8s_version}/${arch}，需要回退两层
      local etcd_dir="${output_dir}/../../etcd/${etcd_version}/${arch}"
      mkdir -p "${etcd_dir}"

      local etcd_url
      etcd_url=$(versions::get_etcd_url "${arch}" "${etcd_version}")
      local etcd_tar="${etcd_dir}/etcd-v${etcd_version}-linux-${arch}.tar.gz"
      local etcd_server="${etcd_dir}/etcd"
      local etcdctl="${etcd_dir}/etcdctl"
      local etcdutl="${etcd_dir}/etcdutl"

      # 检查是否需要下载（可靠的检查：文件存在且非空）
      local need_download=false
      if [[ ! -s "${etcd_server}" || ! -s "${etcdctl}" || ! -s "${etcdutl}" ]]; then
        need_download=true
      fi

      if [[ "${need_download}" == "true" ]]; then
        log::info "  Downloading etcd ${etcd_version}..."
        # 下载tar.gz
        if ! curl -fL --connect-timeout 30 --max-time 600 "${etcd_url}" -o "${etcd_tar}"; then
          log::error "  ✗ Failed to download etcd ${etcd_version}"
          return 1
        fi

        # 提取二进制文件
        log::info "  Extracting etcd binaries (etcd, etcdctl, etcdutl)..."
        tar -xzf "${etcd_tar}" -C "${etcd_dir}" --strip-components=1
        rm -f "${etcd_tar}"

        # 设置权限
        for binary in etcd etcdctl etcdutl; do
          if [[ -f "${etcd_dir}/${binary}" ]]; then
            chmod +x "${etcd_dir}/${binary}"
          fi
        done

        # 验证提取结果
        if [[ -s "${etcd_server}" && -s "${etcdctl}" && -s "${etcdutl}" ]]; then
          log::success "  ✓ etcd binaries (etcd, etcdctl, etcdutl) extracted successfully"
        else
          log::error "  ✗ Failed to extract etcd binaries"
          return 1
        fi
      else
        log::success "  ✓ etcd binaries (v${etcd_version}) already exist, skipping"
      fi
    fi
  done
}

#######################################
# 下载运行时二进制文件
#######################################
download::download_runtime_binaries() {
  local containerd_dir="$1"
  local runc_dir="$2"
  local crictl_dir="$3"
  local runtime_type="$4"
  local k8s_version="${5:-$(config::get_kubernetes_version)}"
  local arch="${6:-$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')}"

  log::info "Downloading ${runtime_type} binaries for Kubernetes ${k8s_version} (architecture: ${arch})..."

  case "${runtime_type}" in
    containerd)
      # 从版本管理系统获取版本
      local containerd_version
      containerd_version=$(versions::get "containerd" "${k8s_version}") || {
        log::error "Failed to get containerd version for ${k8s_version}"
        return 1
      }

      local crictl_version
      crictl_version=$(versions::get "crictl" "${k8s_version}") || {
        log::error "Failed to get crictl version for ${k8s_version}"
        return 1
      }

      local runc_version
      runc_version=$(versions::get "runc" "${k8s_version}") || {
        log::error "Failed to get runc version for ${k8s_version}"
        return 1
      }

      log::info "  Versions: containerd=${containerd_version}, crictl=${crictl_version}, runc=${runc_version}"

      # 下载containerd - 根据架构选择下载URL
      log::info "  Downloading containerd for ${arch}..."
      local containerd_url
      containerd_url=$(versions::get_containerd_url "${arch}" "${containerd_version}")

      # 检查containerd是否已存在且版本匹配
      if [[ -f "${containerd_dir}/containerd" && -s "${containerd_dir}/containerd" ]]; then
        # 通过路径中的版本信息判断
        if [[ "${containerd_dir}" == *"${containerd_version}"* ]]; then
          log::success "  ✓ containerd (v${containerd_version}) already exists, skipping"
        else
          log::info "  ✓ containerd version mismatch, re-downloading..."
          rm -f "${containerd_dir}/containerd"
          curl -fL --connect-timeout 30 --max-time 600 "${containerd_url}" -o "${containerd_dir}/containerd.tar.gz"
          tar -xzf "${containerd_dir}/containerd.tar.gz" -C "${containerd_dir}"
          mv "${containerd_dir}/bin"/* "${containerd_dir}/"
          rmdir "${containerd_dir}/bin"
          rm "${containerd_dir}/containerd.tar.gz"
          log::success "  ✓ containerd downloaded successfully"
        fi
      else
        curl -fL --connect-timeout 30 --max-time 600 "${containerd_url}" -o "${containerd_dir}/containerd.tar.gz"
        tar -xzf "${containerd_dir}/containerd.tar.gz" -C "${containerd_dir}"
        mv "${containerd_dir}/bin"/* "${containerd_dir}/"
        rmdir "${containerd_dir}/bin"
        rm "${containerd_dir}/containerd.tar.gz"
        log::success "  ✓ containerd downloaded successfully"
      fi

      # 下载crictl - 根据架构选择下载URL
      log::info "  Downloading crictl for ${arch}..."
      local crictl_url
      crictl_url=$(versions::get_crictl_url "${arch}" "${crictl_version}")

      if [[ -f "${crictl_dir}/crictl" && -s "${crictl_dir}/crictl" ]]; then
        if [[ "${crictl_dir}" == *"${crictl_version}"* ]]; then
          log::success "  ✓ crictl (v${crictl_version}) already exists, skipping"
        else
          log::info "  ✓ crictl version mismatch, re-downloading..."
          rm -f "${crictl_dir}/crictl"
          curl -fL --connect-timeout 30 --max-time 600 "${crictl_url}" -o "${crictl_dir}/crictl.tar.gz"
          tar -xzf "${crictl_dir}/crictl.tar.gz" -C "${crictl_dir}"
          rm "${crictl_dir}/crictl.tar.gz"
          log::success "  ✓ crictl downloaded successfully"
        fi
      else
        curl -fL --connect-timeout 30 --max-time 600 "${crictl_url}" -o "${crictl_dir}/crictl.tar.gz"
        tar -xzf "${crictl_dir}/crictl.tar.gz" -C "${crictl_dir}"
        rm "${crictl_dir}/crictl.tar.gz"
        log::success "  ✓ crictl downloaded successfully"
      fi

      # 下载runc - 根据架构选择下载URL
      log::info "  Downloading runc for ${arch}..."
      local runc_url
      runc_url=$(versions::get_runc_url "${arch}" "${runc_version}")

      if [[ -f "${runc_dir}/runc" && -s "${runc_dir}/runc" ]]; then
        if [[ "${runc_dir}" == *"${runc_version}"* ]]; then
          log::success "  ✓ runc (v${runc_version}) already exists, skipping"
        else
          log::info "  ✓ runc version mismatch, re-downloading..."
          rm -f "${runc_dir}/runc"
          curl -fL --connect-timeout 30 --max-time 600 "${runc_url}" -o "${runc_dir}/runc"
          chmod +x "${runc_dir}/runc"
          log::success "  ✓ runc downloaded successfully"
        fi
      else
        curl -fL --connect-timeout 30 --max-time 600 "${runc_url}" -o "${runc_dir}/runc"
        chmod +x "${runc_dir}/runc"
        log::success "  ✓ runc downloaded successfully"
      fi
      ;;
    docker)
      # 从版本管理系统获取版本
      local docker_version
      docker_version=$(versions::get "docker" "${k8s_version}") || {
        log::error "Failed to get docker version for ${k8s_version}"
        return 1
      }

      local cri_dockerd_version
      cri_dockerd_version=$(versions::get "cri_dockerd" "${k8s_version}") || {
        log::error "Failed to get cri-dockerd version for ${k8s_version}"
        return 1
      }

      local crictl_version
      crictl_version=$(versions::get "crictl" "${k8s_version}") || {
        log::error "Failed to get crictl version for ${k8s_version}"
        return 1
      }

      log::info "  Downloading docker (${docker_version}), cri-dockerd (${cri_dockerd_version}) and crictl (${crictl_version}) for ${arch}..."
      local docker_url
      docker_url=$(versions::get_docker_url "${arch}" "${docker_version}")
      local cri_dockerd_url
      cri_dockerd_url=$(versions::get_cri_dockerd_url "${arch}" "${cri_dockerd_version}")
      local crictl_url
      crictl_url=$(versions::get_crictl_url "${arch}" "${crictl_version}")

      mkdir -p "${containerd_dir}"

      # 检查docker是否已存在且版本匹配
      if [[ -f "${containerd_dir}/dockerd" && -s "${containerd_dir}/dockerd" ]]; then
        if [[ "${containerd_dir}" == *"${docker_version}"* ]]; then
          log::success "  ✓ docker (v${docker_version}) already exists, skipping"
        else
          log::info "  ✓ docker version mismatch, re-downloading..."
          rm -rf "${containerd_dir}/docker*"
          curl -fL --connect-timeout 30 --max-time 600 "${docker_url}" -o "${containerd_dir}/docker.tgz"
          tar -xzf "${containerd_dir}/docker.tgz" -C "${containerd_dir}"
          rm "${containerd_dir}/docker.tgz"
          log::success "  ✓ docker downloaded successfully"
        fi
      else
        curl -fL --connect-timeout 30 --max-time 600 "${docker_url}" -o "${containerd_dir}/docker.tgz"
        tar -xzf "${containerd_dir}/docker.tgz" -C "${containerd_dir}"
        rm "${containerd_dir}/docker.tgz"
        log::success "  ✓ docker downloaded successfully"
      fi

      # 下载cri-dockerd (Kubernetes 1.24+ 需要)
      log::info "  Downloading cri-dockerd for ${arch}..."
      if [[ -f "${containerd_dir}/cri-dockerd" && -s "${containerd_dir}/cri-dockerd" ]]; then
        if [[ "${containerd_dir}" == *"${cri_dockerd_version}"* ]]; then
          log::success "  ✓ cri-dockerd (v${cri_dockerd_version}) already exists, skipping"
        else
          log::info "  ✓ cri-dockerd version mismatch, re-downloading..."
          rm -f "${containerd_dir}/cri-dockerd"
          curl -fL --connect-timeout 30 --max-time 600 "${cri_dockerd_url}" -o "${containerd_dir}/cri-dockerd.tgz"
          tar -xzf "${containerd_dir}/cri-dockerd.tgz" -C "${containerd_dir}"
          rm "${containerd_dir}/cri-dockerd.tgz"
          log::success "  ✓ cri-dockerd downloaded successfully"
        fi
      else
        curl -fL --connect-timeout 30 --max-time 600 "${cri_dockerd_url}" -o "${containerd_dir}/cri-dockerd.tgz"
        tar -xzf "${containerd_dir}/cri-dockerd.tgz" -C "${containerd_dir}"
        rm "${containerd_dir}/cri-dockerd.tgz"
        log::success "  ✓ cri-dockerd downloaded successfully"
      fi

      # 下载crictl (Kubernetes CRI工具)
      log::info "  Downloading crictl for ${arch}..."
      if [[ -f "${crictl_dir}/crictl" && -s "${crictl_dir}/crictl" ]]; then
        if [[ "${crictl_dir}" == *"${crictl_version}"* ]]; then
          log::success "  ✓ crictl (v${crictl_version}) already exists, skipping"
        else
          log::info "  ✓ crictl version mismatch, re-downloading..."
          rm -f "${crictl_dir}/crictl"
          curl -fL --connect-timeout 30 --max-time 600 "${crictl_url}" -o "${crictl_dir}/crictl.tar.gz"
          tar -xzf "${crictl_dir}/crictl.tar.gz" -C "${crictl_dir}"
          rm "${crictl_dir}/crictl.tar.gz"
          log::success "  ✓ crictl downloaded successfully"
        fi
      else
        curl -fL --connect-timeout 30 --max-time 600 "${crictl_url}" -o "${crictl_dir}/crictl.tar.gz"
        tar -xzf "${crictl_dir}/crictl.tar.gz" -C "${crictl_dir}"
        rm "${crictl_dir}/crictl.tar.gz"
        log::success "  ✓ crictl downloaded successfully"
      fi
      ;;
    crio)
      # 从版本管理系统获取版本
      local crio_version
      crio_version=$(versions::get "crio" "${k8s_version}") || {
        log::error "Failed to get crio version for ${k8s_version}"
        return 1
      }

      local conmon_version
      conmon_version=$(versions::get "conmon" "${k8s_version}") || {
        log::error "Failed to get conmon version for ${k8s_version}"
        return 1
      }

      local runc_version
      runc_version=$(versions::get "runc" "${k8s_version}") || {
        log::error "Failed to get runc version for ${k8s_version}"
        return 1
      }

      local crictl_version
      crictl_version=$(versions::get "crictl" "${k8s_version}") || {
        log::error "Failed to get crictl version for ${k8s_version}"
        return 1
      }

      log::info "  Downloading cri-o (${crio_version}), conmon (${conmon_version}), runc (${runc_version}) and crictl (${crictl_version}) for ${arch}..."
      local crio_url
      crio_url=$(versions::get_crio_url "${arch}" "${crio_version}")
      local conmon_url
      conmon_url=$(versions::get_conmon_url "${arch}" "${conmon_version}")
      local runc_url
      runc_url=$(versions::get_runc_url "${arch}" "${runc_version}")
      local crictl_url
      crictl_url=$(versions::get_crictl_url "${arch}" "${crictl_version}")

      mkdir -p "${containerd_dir}"

      # 检查crio是否已存在且版本匹配
      if [[ -f "${containerd_dir}/crio" && -s "${containerd_dir}/crio" ]]; then
        if [[ "${containerd_dir}" == *"${crio_version}"* ]]; then
          log::success "  ✓ cri-o (v${crio_version}) already exists, skipping"
        else
          log::info "  ✓ cri-o version mismatch, re-downloading..."
          rm -rf "${containerd_dir}/crio"*
          curl -fL --connect-timeout 30 --max-time 600 "${crio_url}" -o "${containerd_dir}/crio.tar.gz"
          tar -xzf "${containerd_dir}/crio.tar.gz" -C "${containerd_dir}"
          rm "${containerd_dir}/crio.tar.gz"
          log::success "  ✓ cri-o downloaded successfully"
        fi
      else
        curl -fL --connect-timeout 30 --max-time 600 "${crio_url}" -o "${containerd_dir}/crio.tar.gz"
        tar -xzf "${containerd_dir}/crio.tar.gz" -C "${containerd_dir}"
        rm "${containerd_dir}/crio.tar.gz"
        log::success "  ✓ cri-o downloaded successfully"
      fi

      # 下载conmon (CRI-O 运行时需要)
      log::info "  Downloading conmon for ${arch}..."
      if [[ -f "${containerd_dir}/conmon" && -s "${containerd_dir}/conmon" ]]; then
        if [[ "${containerd_dir}" == *"${conmon_version}"* ]]; then
          log::success "  ✓ conmon (v${conmon_version}) already exists, skipping"
        else
          log::info "  ✓ conmon version mismatch, re-downloading..."
          rm -f "${containerd_dir}/conmon"
          curl -fL --connect-timeout 30 --max-time 600 "${conmon_url}" -o "${containerd_dir}/conmon"
          chmod +x "${containerd_dir}/conmon"
          log::success "  ✓ conmon downloaded successfully"
        fi
      else
        curl -fL --connect-timeout 30 --max-time 600 "${conmon_url}" -o "${containerd_dir}/conmon"
        chmod +x "${containerd_dir}/conmon"
        log::success "  ✓ conmon downloaded successfully"
      fi

      # 下载runc (CRI-O 需要)
      log::info "  Downloading runc for ${arch}..."
      if [[ -f "${runc_dir}/runc" && -s "${runc_dir}/runc" ]]; then
        if [[ "${runc_dir}" == *"${runc_version}"* ]]; then
          log::success "  ✓ runc (v${runc_version}) already exists, skipping"
        else
          log::info "  ✓ runc version mismatch, re-downloading..."
          rm -f "${runc_dir}/runc"
          curl -fL --connect-timeout 30 --max-time 600 "${runc_url}" -o "${runc_dir}/runc"
          chmod +x "${runc_dir}/runc"
          log::success "  ✓ runc downloaded successfully"
        fi
      else
        curl -fL --connect-timeout 30 --max-time 600 "${runc_url}" -o "${runc_dir}/runc"
        chmod +x "${runc_dir}/runc"
        log::success "  ✓ runc downloaded successfully"
      fi

      # 下载crictl (Kubernetes CRI工具)
      log::info "  Downloading crictl for ${arch}..."
      if [[ -f "${crictl_dir}/crictl" && -s "${crictl_dir}/crictl" ]]; then
        if [[ "${crictl_dir}" == *"${crictl_version}"* ]]; then
          log::success "  ✓ crictl (v${crictl_version}) already exists, skipping"
        else
          log::info "  ✓ crictl version mismatch, re-downloading..."
          rm -f "${crictl_dir}/crictl"
          curl -fL --connect-timeout 30 --max-time 600 "${crictl_url}" -o "${crictl_dir}/crictl.tar.gz"
          tar -xzf "${crictl_dir}/crictl.tar.gz" -C "${crictl_dir}"
          rm "${crictl_dir}/crictl.tar.gz"
          log::success "  ✓ crictl downloaded successfully"
        fi
      else
        curl -fL --connect-timeout 30 --max-time 600 "${crictl_url}" -o "${crictl_dir}/crictl.tar.gz"
        tar -xzf "${crictl_dir}/crictl.tar.gz" -C "${crictl_dir}"
        rm "${crictl_dir}/crictl.tar.gz"
        log::success "  ✓ crictl downloaded successfully"
      fi
      ;;
    *)
      log::warn "Runtime type ${runtime_type} not supported for binary download"
      ;;
  esac
}

#######################################
# 下载Helm二进制文件
#######################################
download::download_helm_binary() {
  local output_dir="$1"
  local k8s_version="$2"
  local arch="${3:-$(defaults::get_arch)}"

  # 从版本管理系统获取版本
  local helm_version
  helm_version=$(versions::get "helm" "${k8s_version}") || {
    log::error "Failed to get helm version for ${k8s_version}"
    return 1
  }

  log::info "Downloading helm binary for ${arch}..."

  local helm_url
  helm_url=$(versions::get_helm_url "${arch}" "${helm_version}")
  local helm_file="${output_dir}/helm"

  mkdir -p "${output_dir}"

  # 检查helm是否已存在且版本匹配
  if [[ -f "${helm_file}" && -s "${helm_file}" ]]; then
    if [[ "${output_dir}" == *"${helm_version}"* ]]; then
      log::success "  ✓ helm (v${helm_version}) already exists, skipping"
      return 0
    else
      log::info "  ✓ helm version mismatch, re-downloading..."
      rm -f "${helm_file}"
    fi
  fi

  if curl -fL --connect-timeout 30 --max-time 600 "${helm_url}" -o "${output_dir}/helm.tar.gz"; then
    tar -xzf "${output_dir}/helm.tar.gz" -C "${output_dir}"
    mv "${output_dir}/linux-${arch}/helm" "${output_dir}/helm"
    rm -rf "${output_dir}/linux-${arch}"
    rm "${output_dir}/helm.tar.gz"
    chmod +x "${output_dir}/helm"
    log::success "  ✓ helm (v${helm_version}) downloaded successfully"
  else
    log::error "  ✗ Failed to download helm"
    return 1
  fi
}

#######################################
# 下载Registry二进制文件
#######################################
download::download_registry_binary() {
  local output_dir="$1"
  local registry_version="${2:-$(defaults::get_registry_version)}"
  local arch="${3:-$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')}"

  log::info "Downloading registry binary (v${registry_version}) for ${arch}..."

  mkdir -p "${output_dir}"

  local registry_file="${output_dir}/registry"

  # 检查registry是否已存在且版本匹配
  if [[ -f "${registry_file}" && -s "${registry_file}" ]]; then
    if [[ "${output_dir}" == *"${registry_version}"* ]]; then
      log::success "  ✓ registry (v${registry_version}) already exists, skipping"
      return 0
    else
      log::info "  ✓ registry version mismatch, re-downloading..."
      rm -f "${registry_file}"
    fi
  fi

  # Docker Registry 官方二进制下载 URL
  # 格式: https://github.com/distribution/distribution/releases/download/v{version}/registry_{version}_linux_{arch}.tar.gz
  local registry_url="https://github.com/distribution/distribution/releases/download/v${registry_version}/registry_${registry_version}_linux_${arch}.tar.gz"

  if curl -fL --connect-timeout 30 --max-time 600 "${registry_url}" -o "${output_dir}/registry.tar.gz"; then
    tar -xzf "${output_dir}/registry.tar.gz" -C "${output_dir}"
    rm "${output_dir}/registry.tar.gz"
    chmod +x "${registry_file}"
    log::success "  ✓ registry (v${registry_version}) downloaded successfully"
  else
    # 备用下载方式 - 直接从 Docker Hub 提取
    log::warn "  Primary download failed, trying alternative method..."
    # 如果有 skopeo，可以从容器镜像中提取
    if command -v skopeo &>/dev/null && command -v tar &>/dev/null; then
      local temp_dir=$(mktemp -d)
      if skopeo copy "docker://registry:${registry_version}" "dir:${temp_dir}" 2>/dev/null; then
        # 从 OCI 目录提取 registry 二进制
        log::warn "  Extracting registry from container image..."
        # 这里简化处理，实际需要解析 manifest 并提取层
        log::error "  ✗ Failed to download registry binary"
        rm -rf "${temp_dir}"
        return 1
      fi
      rm -rf "${temp_dir}"
    else
      log::error "  ✗ Failed to download registry binary"
      return 1
    fi
  fi
}

#######################################
# 下载容器镜像
#######################################
download::download_container_images() {
  local output_dir="$1"
  local k8s_version="$2"
  local network_plugin="$3"
  local k8s_type="${4:-$(defaults::get_kubernetes_type)}"
  local etcd_type="${5:-$(defaults::get_etcd_type)}"
  local lb_enabled="${6:-$(defaults::get_loadbalancer_enabled)}"
  local lb_mode="${7:-$(defaults::get_loadbalancer_mode)}"
  local lb_type="${8:-$(defaults::get_loadbalancer_type)}"

  log::info "Downloading container images for Kubernetes ${k8s_version} (${k8s_type} mode, etcd: ${etcd_type})..."

  if ! download::ensure_skopeo; then
    log::error "Skopeo not available for image download"
    return 1
  fi

  # 从 image_manager.sh 获取完整镜像列表（包含 K8s 核心镜像、CNI 镜像、LB 镜像）
  local k8s_images=()
  while IFS= read -r image; do
    k8s_images+=("$image")
  done < <(generate_core_images "${k8s_version}" "" "${k8s_type}" "${etcd_type}" "${network_plugin}" "${lb_enabled}" "${lb_mode}" "${lb_type}")

  # kube-vip 镜像（由 generate_core_images 处理的是 internal LB，kube-vip 单独处理）
  local lb_images=()
  if [[ "${lb_mode}" == "kube-vip" ]]; then
    log::info "  Adding kube-vip images"
    lb_images+=("ghcr.io/kube-vip/kube-vip:v0.8.0")
  fi

  # 下载所有镜像（k8s_images 已包含 CNI 和 internal LB 镜像）
  local all_images=("${k8s_images[@]}" "${lb_images[@]}")

  log::info "Total images to download: ${#all_images[@]}"
  log::info "  K8s + CNI + LB images: ${#k8s_images[@]}"
  log::info "  Additional LB images: ${#lb_images[@]}"

  # 优先下载核心镜像 (失败立即终止)
  local core_patterns=("pause" "coredns" "etcd" "kube-apiserver" "kube-controller" "kube-scheduler" "kube-proxy")
  local core_images=()
  local other_images=()

  for image in "${all_images[@]}"; do
    local is_core=false
    for pattern in "${core_patterns[@]}"; do
      if [[ "${image}" == *"${pattern}"* ]]; then
        is_core=true
        break
      fi
    done
    if [[ "${is_core}" == "true" ]]; then
      core_images+=("${image}")
    else
      other_images+=("${image}")
    fi
  done

  log::info "  Core images (priority): ${#core_images[@]}"
  log::info "  Other images: ${#other_images[@]}"

  # 先下载核心镜像
  log::info "=== Downloading core images (priority) ==="
  for image in "${core_images[@]}"; do
    local image_name=$(echo "${image}" | tr '/' '_' | tr ':' '_')
    local image_dir="${output_dir}/${image_name}"

    if [[ -f "${image_dir}/manifest.json" ]]; then
      local expected_tag="${image##*:}"
      if [[ "${image_name}" == *"${expected_tag}"* ]]; then
        log::success "  ✓ ${image} already exists, skipping"
        download::record_image "${image}" "${output_dir}"
        continue
      fi
    fi

    [[ -d "${image_dir}" ]] && rm -rf "${image_dir}"

    log::info "  Downloading core image: ${image}"
    if timeout 300 skopeo copy "docker://${image}" "dir:${image_dir}"; then
      log::success "  ✓ ${image} downloaded successfully"
      download::record_image "${image}" "${output_dir}"
    else
      log::error "  ✗ CRITICAL: Failed to download core image ${image}"
      return 1
    fi
  done

  # 再下载其他镜像
  log::info "=== Downloading other images ==="
  for image in "${other_images[@]}"; do
    local image_name=$(echo "${image}" | tr '/' '_' | tr ':' '_')
    local image_dir="${output_dir}/${image_name}"

    if [[ -f "${image_dir}/manifest.json" ]]; then
      local expected_tag="${image##*:}"
      if [[ "${image_name}" == *"${expected_tag}"* ]]; then
        log::success "  ✓ ${image} already exists, skipping"
        download::record_image "${image}" "${output_dir}"
        continue
      fi
    fi

    [[ -d "${image_dir}" ]] && rm -rf "${image_dir}"

    log::info "  Downloading image: ${image}"
    if timeout 300 skopeo copy "docker://${image}" "dir:${image_dir}"; then
      log::success "  ✓ ${image} downloaded successfully"
      download::record_image "${image}" "${output_dir}"
    else
      log::error "  ✗ Failed to download image ${image}"
      return 1
    fi
  done
}

#######################################
# 下载Helm Charts
#######################################
download::download_helm_charts() {
  local output_dir="$1"

  log::info "Downloading Helm charts..."

  if ! download::ensure_helm; then
    log::warn "  helm not available, skipping chart download"
    return 0
  fi

  local xmyq_bin="${KUBEXM_ROOT}/bin/xmyq"
  local xmjq_bin="${KUBEXM_ROOT}/bin/xmjq"

  # 根据配置条件下载Charts
  local charts=()

  # 检查是否启用metrics-server
  if [[ "$(config::get_metrics_server_enabled)" == "true" ]]; then
    charts+=("metrics-server/metrics-server")
    helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ 2>/dev/null || true
    log::info "  Metrics-server enabled, will download"
  else
    log::info "  Metrics-server disabled, skipping"
  fi

  # 检查是否启用ingress-nginx
  if [[ "$(config::get_ingress_enabled)" == "true" ]]; then
    charts+=("ingress-nginx/ingress-nginx")
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
    log::info "  Ingress-nginx enabled, will download"
  else
    log::info "  Ingress-nginx disabled, skipping"
  fi

  # 如果有启用的charts，才更新仓库
  if [[ ${#charts[@]} -gt 0 ]]; then
    helm repo update
  else
    log::info "  No charts enabled, skipping helm repo update"
    return 0
  fi

  # 下载选中的Charts
  for chart in "${charts[@]}"; do
    local chart_name=$(echo "${chart}" | cut -d'/' -f2)
    local chart_dir="${output_dir}/${chart_name}"

    # 检查Chart是否已存在且版本匹配
    if [[ -f "${chart_dir}/Chart.yaml" ]]; then
      # 从 helm repo list 获取最新版本进行对比
      local cached_version=""
      if [[ -f "${output_dir}/${chart_name}-${chart_name}"*.tgz ]]; then
        # 找到缓存的tgz文件获取版本
        local tgz_file=$(ls "${output_dir}/${chart_name}-${chart_name}"*.tgz 2>/dev/null | head -1)
        if [[ -n "${tgz_file}" ]]; then
          # 尝试从Chart.yaml获取版本
          cached_version=$("${xmyq_bin:-xmyq}" ".version" "${chart_dir}/Chart.yaml" 2>/dev/null || echo "")
        fi
      fi

      # 获取最新版本
      local latest_version
      latest_version=$(helm search repo "${chart}" -o json 2>/dev/null | \
        "${xmjq_bin:-xmjq}" -r '.[0].version' 2>/dev/null || echo "")

      if [[ -n "${cached_version}" && -n "${latest_version}" && \
            "${cached_version}" == "${latest_version}" ]]; then
        log::success "  ✓ ${chart_name} (v${cached_version}) already exists, skipping"
        continue
      fi
      log::info "  ✓ Version mismatch (cached: ${cached_version:-?}, latest: ${latest_version:-?}), re-downloading..."
    fi

    # 如果目录存在但不完整或版本不对，删除它
    if [[ -d "${chart_dir}" ]]; then
      rm -rf "${chart_dir}"
      # 删除可能存在的旧tgz文件
      rm -f "${output_dir}/${chart_name}-${chart_name}"*.tgz
    fi

    log::info "  Downloading chart: ${chart}"
    if helm pull "${chart}" -d "${output_dir}" --untar; then
      log::success "  ✓ Chart ${chart_name} downloaded successfully"
    else
      log::error "  ✗ Failed to download chart ${chart}"
    fi
  done

  log::info "Total charts downloaded: ${#charts[@]}"
}

#######################################
# 下载 Addon Manifests (CNI YAML 等非 Helm 资源)
# 下载到 packages/${component}/${version}/ 目录
#######################################
download::download_addon_manifests() {
  local download_dir="$1"
  local k8s_version="$2"
  local network_plugin="$3"

  log::info "Downloading addon manifests..."

  # 下载 CNI YAML 文件
  case "${network_plugin}" in
    calico)
      local calico_version
      calico_version=$(versions::get "calico" "${k8s_version}")
      local target_dir="${download_dir}/calico/v${calico_version}"
      mkdir -p "${target_dir}"

      local calico_url
      calico_url=$(versions::get_calico_url "v${calico_version}")
      local calico_yaml="${target_dir}/calico.yaml"

      if [[ -f "${calico_yaml}" ]]; then
        log::success "  ✓ Calico manifest (v${calico_version}) already exists, skipping"
      else
        log::info "  Downloading Calico manifest v${calico_version}..."
        if curl -fL --connect-timeout 30 --max-time 600 "${calico_url}" -o "${calico_yaml}"; then
          log::success "  ✓ Calico manifest downloaded successfully"
          # 提取镜像到列表文件
          download::extract_images_from_yaml "${calico_yaml}" >> "${download_dir}/addon-images.list"
        else
          log::error "  ✗ Failed to download Calico manifest"
          return 1
        fi
      fi
      ;;
    flannel)
      local flannel_version
      flannel_version=$(versions::get "flannel" "${k8s_version}")
      local target_dir="${download_dir}/flannel/v${flannel_version}"
      mkdir -p "${target_dir}"

      local flannel_url
      flannel_url=$(versions::get_flannel_url "v${flannel_version}")
      local flannel_yaml="${target_dir}/kube-flannel.yaml"

      if [[ -f "${flannel_yaml}" ]]; then
        log::success "  ✓ Flannel manifest (v${flannel_version}) already exists, skipping"
      else
        log::info "  Downloading Flannel manifest v${flannel_version}..."
        if curl -fL --connect-timeout 30 --max-time 600 "${flannel_url}" -o "${flannel_yaml}"; then
          log::success "  ✓ Flannel manifest downloaded successfully"
          download::extract_images_from_yaml "${flannel_yaml}" >> "${download_dir}/addon-images.list"
        else
          log::error "  ✗ Failed to download Flannel manifest"
          return 1
        fi
      fi
      ;;
    cilium)
      log::info "  Cilium uses Helm chart, skipping YAML download"
      ;;
    *)
      log::warn "  Unknown network plugin: ${network_plugin}"
      ;;
  esac

  # CoreDNS 和 NodeLocalDNS 说明：
  # - 使用项目内置模板 (templates/addons/coredns/coredns.yaml.tmpl)
  # - 渲染在部署阶段进行，会渲染到 packages/{cluster}/{node}/ 目录
  # - 下载阶段不需要任何操作
  log::info "  CoreDNS/NodeLocalDNS: 使用内置模板，渲染在部署阶段进行"

  # 去重镜像列表
  if [[ -f "${download_dir}/addon-images.list" ]]; then
    sort -u "${download_dir}/addon-images.list" -o "${download_dir}/addon-images.list"
    local image_count
    image_count=$(wc -l < "${download_dir}/addon-images.list")
    log::info "  Extracted ${image_count} unique images from addon manifests"
  fi
}

#######################################
# 从 YAML 文件提取容器镜像
# 支持 image: 和 - image: 格式
#######################################
download::extract_images_from_yaml() {
  local yaml_file="$1"

  if [[ ! -f "${yaml_file}" ]]; then
    return 0
  fi

  # 提取 image: xxx 和 - image: xxx 格式的镜像
  grep -oE 'image:\s*[^[:space:]"]+' "${yaml_file}" 2>/dev/null | \
    sed 's/image:\s*//' | \
    tr -d '"' | \
    grep -v '^\$' | \
    sort -u
}
# 生成包清单
#######################################
download::generate_package_manifest() {
  local packages_dir="$1"
  local cluster_name="$2"

  log::info "Generating package manifest..."

  local manifest_file="${packages_dir}/manifest-${cluster_name}.yaml"
  local images_count
  local images_list="${packages_dir}/images/images.list"
  if [[ -f "${images_list}" ]]; then
    images_count=$(grep -v '^#' "${images_list}" | grep -v '^$' | wc -l)
  else
    images_count=$(find "${packages_dir}/images" -mindepth 1 -maxdepth 1 -type d | wc -l)
  fi

  cat > "${manifest_file}" << EOF
# KubeXM Package Manifest
# Cluster: ${cluster_name}
# Generated: $(date)

cluster: ${cluster_name}
generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

components:
  binaries:
    kubernetes:
      version: $(config::get_kubernetes_version)
      path: binaries/kubernetes/$(config::get_kubernetes_version)
    runtime:
      type: $(config::get_runtime_type)
      version: $(config::get_runtime_version)
      path: binaries/containerd/$(config::get_runtime_type)
    tools:
      path: tools/common

  images:
    path: images
    count: ${images_count}

  helm:
    path: helm
    charts:
$(find "${packages_dir}/helm" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sed 's/^/      - /')

  iso:
    path: iso

paths:
  work_dir: $(config::get_work_dir)
  cache_dir: $(config::get_cache_dir)

metadata:
  mode: $(config::get_mode)
  arch: $(config::get_arch_list)
  network_plugin: $(config::get_network_plugin)
EOF

  log::info "Package manifest generated: ${manifest_file}"
}

#######################################
# 下载CNI插件二进制文件
#######################################
download::download_cni_binaries() {
  local output_dir="$1"
  local k8s_version="$2"
  local arch="$3"

  log::info "Downloading CNI plugins binaries for Kubernetes ${k8s_version} (architecture: ${arch})..."

  # 获取CNI版本
  local cni_version
  cni_version=$(versions::get "cni" "${k8s_version}") || {
    log::error "Failed to get CNI version for ${k8s_version}"
    return 1
  }

  log::info "  Using CNI plugins version: ${cni_version}"

  # 获取下载URL
  local cni_url
  cni_url=$(versions::get_cni_download_url "${arch}" "${cni_version}")

  log::info "  Downloading CNI plugins for ${arch}..."
  mkdir -p "${output_dir}"

  # 检查CNI插件是否已存在且版本匹配
  # CNI插件直接解压到输出目录，包含 bridge, host-local 等二进制
  if [[ -f "${output_dir}/bridge" ]] || [[ -f "${output_dir}/host-local" ]]; then
    # 进一步验证版本是否匹配（通过路径中的版本号）
    if [[ "${output_dir}" == *"${cni_version}"* ]]; then
      log::success "  ✓ CNI plugins (v${cni_version}) already exist, skipping"
      return 0
    else
      log::info "  ✓ CNI plugins version mismatch, re-downloading..."
      rm -rf "${output_dir}"/* "${output_dir}/cni-plugins.tgz"
    fi
  fi

  # 清理可能残留的旧版本 tarball
  rm -f "${output_dir}/cni-plugins.tgz"

  # 下载CNI插件
  if curl -fL --connect-timeout 30 --max-time 600 "${cni_url}" -o "${output_dir}/cni-plugins.tgz"; then
    log::success "  ✓ CNI plugins downloaded successfully"
    # 解压到输出目录
    tar -xzf "${output_dir}/cni-plugins.tgz" -C "${output_dir}"
    rm "${output_dir}/cni-plugins.tgz"
    log::success "  ✓ CNI plugins extracted successfully"
  else
    log::error "  ✗ Failed to download CNI plugins"
    return 1
  fi
}

#######################################
# 下载 Calicoctl 二进制文件
#######################################
download::download_calicoctl_binary() {
  local output_dir="$1"
  local k8s_version="$2"
  local arch="$3"

  log::info "Downloading calicoctl binary for Kubernetes ${k8s_version} (architecture: ${arch})..."

  # 获取 Calico 版本
  local calico_version
  calico_version=$(versions::get "calico" "${k8s_version}") || {
    log::error "Failed to get Calico version for ${k8s_version}"
    return 1
  }

  log::info "  Using calicoctl version: ${calico_version}"

  # 获取下载 URL
  local calicoctl_url
  calicoctl_url=$(versions::get_calicoctl_url "${arch}" "${calico_version}")

  local calicoctl_file="${output_dir}/calicoctl"

  mkdir -p "${output_dir}"

  # 检查 calicoctl 是否已存在且版本匹配
  if [[ -f "${calicoctl_file}" && -s "${calicoctl_file}" ]]; then
    if [[ "${output_dir}" == *"${calico_version}"* ]]; then
      log::success "  ✓ calicoctl (v${calico_version}) already exists, skipping"
      return 0
    else
      log::info "  ✓ calicoctl version mismatch, re-downloading..."
      rm -f "${calicoctl_file}"
    fi
  fi

  # 下载 calicoctl
  log::info "  Downloading calicoctl for ${arch}..."
  if curl -fL --connect-timeout 30 --max-time 600 "${calicoctl_url}" -o "${calicoctl_file}"; then
    chmod +x "${calicoctl_file}"
    log::success "  ✓ calicoctl downloaded successfully"
  else
    log::error "  ✗ Failed to download calicoctl"
    return 1
  fi
}

#######################################
# 构建离线资源
#######################################
download::build_offline_resources() {
  local download_dir="$1"
  local cluster_name="$2"

  log::info "=== 开始构建离线资源 ==="

  local k8s_version=$(config::get_kubernetes_version)
  local arch_list=$(config::get_arch_list)

  # 构建Docker镜像（用于包构建）
  log::info "构建Docker镜像用于包构建..."
  if build::check_docker && build::build_all; then
    log::success "✓ Docker镜像构建成功"
  else
    log::warn "⚠ Docker镜像构建失败，跳过离线包构建"
    return 0
  fi

  # 构建系统包（支持多OS）- 使用Docker构建系统
  log::info "构建系统包..."
  local os_list="centos7,rocky9,ubuntu22"
  if config::get_offline_os_list 2>/dev/null | grep -q "."; then
    os_list=$(config::get_offline_os_list)
  fi

  log::info "目标操作系统列表: ${os_list}"
  local first_arch
  first_arch="$(echo "${arch_list}" | cut -d',' -f1)"
  local system_iso="${download_dir}/kubexm-system-packages.iso"
  system_iso::build "${system_iso}" "${os_list}" "${first_arch}" "${KUBEXM_BUILD_LOCAL:-false}" || log::warn "系统包构建失败"

  # 构建ISO镜像（为每个OS）
  log::info "构建ISO镜像..."
  IFS=',' read -ra os_array <<< "${os_list}"
  for os in "${os_array[@]}"; do
    local os_output="${download_dir}/iso/${os}/${k8s_version}"
    mkdir -p "${os_output}"

    log::info "为 ${os} 构建ISO..."
    iso::build_for_os "${os}" "${os_output}/kubexm-${os}-${k8s_version}.iso" "${k8s_version}" || \
      log::warn "${os} ISO构建失败"
  done

  # 构建优化的多架构ISO
  log::info "构建多架构ISO..."
  local multiarch_iso="${download_dir}/iso/kubexm-multiarch-${k8s_version}.iso"
  iso::build_multiarch "${multiarch_iso}" "${k8s_version}" "${download_dir}" || \
    log::warn "多架构ISO构建失败"

  # 生成离线安装脚本
  log::info "生成离线安装脚本..."
  mkdir -p "${download_dir}/install"
  if [[ -f "${KUBEXM_ROOT}/templates/install/install.sh" ]]; then
    cp "${KUBEXM_ROOT}/templates/install/install.sh" "${download_dir}/install/install.sh"
    chmod +x "${download_dir}/install/install.sh"
  fi
  cat > "${download_dir}/install-offline.sh" << 'EOF'
#!/bin/bash
# KubeXM 离线安装脚本
# 自动检测ISO文件并执行安装

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 查找ISO文件
find_iso() {
  local isos=(
    "/tmp/*.iso"
    "/mnt/*.iso"
    "$(pwd)/*.iso"
  )

  for pattern in "${isos[@]}"; do
    for iso in ${pattern}; do
      if [[ -f "${iso}" && "${iso}" =~ kubexm ]]; then
        echo "${iso}"
        return 0
      fi
    done
  done
  return 1
}

# 主安装流程
main() {
  local iso
  if ! iso=$(find_iso); then
    echo "错误: 未找到KubeXM ISO文件"
    echo "请将ISO文件放在 /tmp/ 或 /mnt/ 目录下"
    exit 1
  fi

  echo "找到ISO文件: ${iso}"
  echo "开始离线安装..."

  # 执行离线安装
  bash "${SCRIPT_DIR}/install/install.sh" full "${iso}"
}

main "$@"
EOF

  chmod +x "${download_dir}/install-offline.sh"

  # 生成安装文档
  cat > "${download_dir}/OFFLINE_INSTALL.md" << EOF
# KubeXM 离线安装指南

## 文件结构

\`\`\`
${download_dir}/
├── kubernetes/          # Kubernetes二进制文件
├── tools/               # 常用工具二进制 (jq/yq等)
├── images/              # 容器镜像
├── helm/                # Helm Charts
├── packages/            # 系统包（按OS分类）
│   ├── centos7/
│   ├── rocky9/
│   └── ubuntu22/
├── iso/                 # 可引导ISO文件
│   ├── kubexm-centos7-*.iso
│   ├── kubexm-rocky9-*.iso
│   └── kubexm-ubuntu22-*.iso
└── install-offline.sh   # 自动安装脚本
\`\`\`

## 安装方法

### 方法1: 自动安装（推荐）
\`\`\`bash
# 复制整个目录到目标机器
scp -r ${download_dir}/* user@target:/tmp/kubexm/

# 在目标机器上执行
ssh user@target
cd /tmp/kubexm
./install-offline.sh
\`\`\`

### 方法2: 手动安装
\`\`\`bash
# 1. 挂载ISO
sudo mount -o loop kubexm-*.iso /mnt

# 2. 运行安装脚本
sudo /mnt/install/install.sh

# 3. 卸载ISO
sudo umount /mnt
\`\`\`

## 支持的操作系统

- CentOS 7/8
- Rocky Linux 8/9
- AlmaLinux 8/9
- Ubuntu 20.04/22.04
- Debian 11/12
- UOS 20
- Kylin V10
- openEuler 22.03

## 系统要求

- 最小2GB内存
- 最小20GB磁盘空间
- 支持x86_64或arm64架构
- 网络连接（仅安装时需要）

## 部署场景

当前配置支持的部署场景：
- Kubernetes类型: $(config::get_kubernetes_type 2>/dev/null || echo "kubeadm")
- etcd类型: $(config::get_etcd_type 2>/dev/null || echo "kubeadm")
- 网络插件: $(config::get_network_plugin 2>/dev/null || echo "calico")
- 负载均衡: $(config::get_loadbalancer_type 2>/dev/null || echo "none")

生成时间: $(date '+%Y-%m-%d %H:%M:%S')
EOF

  log::success "=== 离线资源构建完成 ==="
  log::info "ISO文件位置: ${download_dir}/iso/"
  log::info "自动安装脚本: ${download_dir}/install-offline.sh"
  log::info "安装文档: ${download_dir}/OFFLINE_INSTALL.md"
}
