#!/usr/bin/env bash

# ==============================================================================
# KubeXM Script - Binary BOM (Bill of Materials)
# ==============================================================================
# 二进制包管理工具
# 管理Kubernetes组件、容器运行时等二进制文件
# ==============================================================================

set -o errexit
set -o nounset
set -o pipefail

# 加载依赖
KUBEXM_SCRIPT_ROOT="${KUBEXM_SCRIPT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "${KUBEXM_SCRIPT_ROOT}/internal/logger/log.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/versions.sh"

#######################################
# 下载Kubernetes二进制文件
# Arguments:
#   $1 - Kubernetes版本
#   $2 - 架构列表 (如 "amd64 arm64")
#   $3 - 输出目录
# Returns:
#   0 成功, 1 失败
#######################################
utils::binary::bom::download_kubernetes_binaries() {
  local k8s_version="$1"
  local arch_list="$2"
  local output_dir="$3"

  log::info "Downloading Kubernetes binaries version: ${k8s_version}"

  if ! utils::command_exists curl; then
    log::error "curl command not found"
    return 1
  fi

  # Kubernetes组件列表
  local components=("kubeadm" "kubelet" "kubectl" "kube-proxy")

  for arch in ${arch_list}; do
    log::info "  Downloading for architecture: ${arch}"

    local arch_dir="${output_dir}/${k8s_version}/${arch}"
    mkdir -p "${arch_dir}"

    local download_url="https://dl.k8s.io/${k8s_version}/bin/linux/${arch}"

    for component in "${components[@]}"; do
      log::info "    Downloading ${component} for ${arch}..."

      local binary_file="${arch_dir}/${component}"

      if curl -fL "${download_url}/${component}" -o "${binary_file}"; then
        chmod +x "${binary_file}"

        # 验证二进制文件
        if [[ -f "${binary_file}" && -x "${binary_file}" ]]; then
          log::success "    ✓ ${component} downloaded successfully"
        else
          log::error "    ✗ Failed to download ${component}"
          return 1
        fi
      else
        log::error "    ✗ Failed to download ${component}"
        return 1
      fi
    done

    # 下载CNI插件二进制文件（如果需要）
    log::info "    Downloading CNI plugins for ${arch}..."
    local cni_arch_dir="${arch_dir}/cni"
    mkdir -p "${cni_arch_dir}"

    # 使用动态版本管理获取CNI版本
    local cni_version
    cni_version=$(versions::get "cni" "${k8s_version}") || {
      log::error "    Failed to get CNI version for ${k8s_version}"
      return 1
    }

    local cni_url
    cni_url=$(versions::get_cni_download_url "${arch}" "${cni_version}")

    curl -fL "${cni_url}" \
      -o "${arch_dir}/cni-plugins.tgz" || {
      log::warn "    Failed to download CNI plugins"
    }

    if [[ -f "${arch_dir}/cni-plugins.tgz" ]]; then
      tar -xzf "${arch_dir}/cni-plugins.tgz" -C "${cni_arch_dir}"
      rm "${arch_dir}/cni-plugins.tgz"
      log::success "    ✓ CNI plugins downloaded successfully"
    fi
  done

  log::success "Kubernetes binaries downloaded successfully"
  return 0
}

#######################################
# 下载容器运行时二进制文件
# Arguments:
#   $1 - 运行时类型 (containerd|docker|crio|podman)
#   $2 - 运行时版本
#   $3 - 输出目录
# Returns:
#   0 成功, 1 失败
#######################################
utils::binary::bom::download_runtime_binaries() {
  local runtime_type="$1"
  local runtime_version="$2"
  local output_dir="$3"

  log::info "Downloading ${runtime_type} binaries version: ${runtime_version}"

  if ! utils::command_exists curl; then
    log::error "curl command not found"
    return 1
  fi

  case "${runtime_type}" in
    containerd)
      utils::binary::bom::download_containerd_binaries "${runtime_version}" "${output_dir}"
      ;;
    docker)
      log::warn "Docker binary download not fully supported, use package manager instead"
      return 0
      ;;
    crio)
      utils::binary::bom::download_crio_binaries "${runtime_version}" "${output_dir}"
      ;;
    podman)
      utils::binary::bom::download_podman_binaries "${runtime_version}" "${output_dir}"
      ;;
    *)
      log::error "Unsupported runtime type: ${runtime_type}"
      return 1
      ;;
  esac
}

#######################################
# 下载Containerd二进制文件
# Arguments:
#   $1 - 版本
#   $2 - 输出目录
#   $3 - 架构 (默认amd64)
# Returns:
#   0 成功, 1 失败
#######################################
utils::binary::bom::download_containerd_binaries() {
  local version="$1"
  local output_dir="$2"
  local arch="${3:-$(defaults::get_arch)}"

  log::info "  Downloading containerd for ${arch}..."

  local containerd_url="https://github.com/containerd/containerd/releases/download/v${version}/containerd-${version}-linux-${arch}.tar.gz"
  local crictl_version
  crictl_version=$(versions::get "crictl" "${KUBEXM_K8S_VERSION:-$(defaults::get_kubernetes_version)}")
  local runc_version
  runc_version=$(versions::get "runc" "${KUBEXM_K8S_VERSION:-$(defaults::get_kubernetes_version)}")

  # 下载containerd
  local tmp_file="/tmp/containerd.tar.gz"
  if curl -fL "${containerd_url}" -o "${tmp_file}"; then
    tar -xzf "${tmp_file}" -C "${output_dir}"
    # 移动二进制文件到目标目录
    if [[ -d "${output_dir}/bin" ]]; then
      mv "${output_dir}/bin"/* "${output_dir}/" 2>/dev/null || true
      rmdir "${output_dir}/bin" 2>/dev/null || true
    fi
    rm "${tmp_file}"
    log::success "  ✓ containerd downloaded successfully"
  else
    log::error "  ✗ Failed to download containerd"
    return 1
  fi

  # 下载crictl
  log::info "  Downloading crictl..."
  local crictl_url="https://github.com/kubernetes-sigs/crictl/releases/download/v${crictl_version}/crictl-v${crictl_version}-linux-${arch}.tar.gz"
  local crictl_tmp="/tmp/crictl.tar.gz"

  if curl -fL "${crictl_url}" -o "${crictl_tmp}"; then
    tar -xzf "${crictl_tmp}" -C "${output_dir}"
    rm "${crictl_tmp}"
    log::success "  ✓ crictl downloaded successfully"
  else
    log::error "  ✗ Failed to download crictl"
    return 1
  fi

  # 下载runc
  log::info "  Downloading runc..."
  local runc_url="https://github.com/opencontainers/runc/releases/download/v${runc_version}/runc.${arch}"
  local runc_file="${output_dir}/runc"

  if curl -fL "${runc_url}" -o "${runc_file}"; then
    chmod +x "${runc_file}"
    log::success "  ✓ runc downloaded successfully"
  else
    log::error "  ✗ Failed to download runc"
    return 1
  fi

  return 0
}

#######################################
# 下载CRI-O二进制文件
# Arguments:
#   $1 - 版本
#   $2 - 输出目录
# Returns:
#   0 成功, 1 失败
#######################################
utils::binary::bom::download_crio_binaries() {
  local version="$1"
  local output_dir="$2"

  log::info "  Downloading CRI-O binaries..."

  # CRI-O通常通过包管理器安装，二进制下载较为复杂
  log::warn "  CRI-O binary download not fully supported, use package manager instead"
  return 0
}

#######################################
# 下载Podman二进制文件
# Arguments:
#   $1 - 版本
#   $2 - 输出目录
# Returns:
#   0 成功, 1 失败
#######################################
utils::binary::bom::download_podman_binaries() {
  local version="$1"
  local output_dir="$2"

  log::info "  Downloading Podman binaries..."

  # Podman通常通过包管理器安装
  log::warn "  Podman binary download not fully supported, use package manager instead"
  return 0
}

#######################################
# 下载Helm二进制文件
# Arguments:
#   $1 - Helm版本
#   $2 - 架构列表
#   $3 - 输出目录
# Returns:
#   0 成功, 1 失败
#######################################
utils::binary::bom::download_helm_binaries() {
  local helm_version="$1"
  local arch_list="$2"
  local output_dir="$3"

  log::info "Downloading Helm binaries version: ${helm_version}"

  if ! utils::command_exists curl; then
    log::error "curl command not found"
    return 1
  fi

  for arch in ${arch_list}; do
    log::info "  Downloading for architecture: ${arch}"

    local arch_dir="${output_dir}/${helm_version}/${arch}"
    mkdir -p "${arch_dir}"

    local binary_file="${arch_dir}/helm"
    local download_url="https://get.helm.sh/helm-v${helm_version}-linux-${arch}"

    if curl -fL "${download_url}" -o "${binary_file}"; then
      chmod +x "${binary_file}"

      # 验证二进制文件
      if "${binary_file}" version >/dev/null 2>&1; then
        log::success "  ✓ Helm downloaded successfully for ${arch}"
      else
        log::error "  ✗ Failed to verify helm binary"
        return 1
      fi
    else
      log::error "  ✗ Failed to download helm for ${arch}"
      return 1
    fi
  done

  log::success "Helm binaries downloaded successfully"
  return 0
}

#######################################
# 下载Skopeo二进制文件
# Arguments:
#   $1 - Skopeo版本
#   $2 - 架构列表
#   $3 - 输出目录
# Returns:
#   0 成功, 1 失败
#######################################
utils::binary::bom::download_skopeo_binaries() {
  local skopeo_version="$1"
  local arch_list="$2"
  local output_dir="$3"

  log::info "Downloading Skopeo binaries version: ${skopeo_version}"

  if ! utils::command_exists curl; then
    log::error "curl command not found"
    return 1
  fi

  for arch in ${arch_list}; do
    log::info "  Downloading for architecture: ${arch}"

    local arch_dir="${output_dir}/${skopeo_version}/${arch}"
    mkdir -p "${arch_dir}"

    local binary_file="${arch_dir}/skopeo"
    local download_url="https://github.com/containers/skopeo/releases/download/v${skopeo_version}/skopeo-linux-${arch}"

    if curl -fL "${download_url}" -o "${binary_file}"; then
      chmod +x "${binary_file}"

      # 验证二进制文件
      if "${binary_file}" --version >/dev/null 2>&1; then
        log::success "  ✓ Skopeo downloaded successfully for ${arch}"
      else
        log::error "  ✗ Failed to verify skopeo binary"
        return 1
      fi
    else
      log::error "  ✗ Failed to download skopeo for ${arch}"
      return 1
    fi
  done

  log::success "Skopeo binaries downloaded successfully"
  return 0
}

#######################################
# 下载Registry二进制文件
# Arguments:
#   $1 - Registry版本
#   $2 - 架构列表
#   $3 - 输出目录
# Returns:
#   0 成功, 1 失败
#######################################
utils::binary::bom::download_registry_binaries() {
  local registry_version="${1:-2.8.3}"
  local arch_list="${2:-amd64}"
  local output_dir="${3:-./binaries/registry}"

  log::info "Downloading Docker Registry binaries version: ${registry_version}"

  if ! utils::command_exists curl; then
    log::error "curl command not found"
    return 1
  fi

  for arch in ${arch_list}; do
    log::info "  Downloading for architecture: ${arch}"

    local arch_dir="${output_dir}/${registry_version}/${arch}"
    mkdir -p "${arch_dir}"

    local binary_file="${arch_dir}/registry"
    
    # Docker Registry 官方发布地址
    # 注意: Docker Registry 官方只提供容器镜像，二进制需要从源码编译
    # 这里使用 github release 的二进制文件
    local download_url="https://github.com/distribution/distribution/releases/download/v${registry_version}/registry_${registry_version}_linux_${arch}.tar.gz"

    log::info "  Downloading from: ${download_url}"

    local temp_file="${arch_dir}/registry.tar.gz"
    if curl -fL "${download_url}" -o "${temp_file}"; then
      # 解压二进制文件
      if tar -xzf "${temp_file}" -C "${arch_dir}" 2>/dev/null; then
        rm -f "${temp_file}"
        chmod +x "${binary_file}" 2>/dev/null || true

        # 验证二进制文件
        if [[ -f "${binary_file}" ]] && "${binary_file}" --version >/dev/null 2>&1; then
          log::success "  ✓ Registry downloaded successfully for ${arch}"
        else
          log::warn "  ⚠ Binary file exists but version check failed, may still be usable"
        fi
      else
        log::error "  ✗ Failed to extract registry archive"
        rm -f "${temp_file}"
        return 1
      fi
    else
      log::error "  ✗ Failed to download registry for ${arch}"
      return 1
    fi
  done

  log::success "Registry binaries downloaded successfully"
  return 0
}

#######################################
# 下载常用工具二进制文件
# Arguments:
#   $1 - 架构列表
#   $2 - 输出目录
# Returns:
#   0 成功, 1 失败
#######################################
utils::binary::bom::download_common_tools() {
  local arch_list="$1"
  local output_dir="$2"

  log::info "Downloading common tools binaries..."

  if ! utils::command_exists curl; then
    log::error "curl command not found"
    return 1
  fi

  # 工具列表: name:version:arch_pattern
  # 注意：架构将从配置文件中动态获取
  # jq目前只支持amd64，其他工具支持多架构
  local tools=(
    "yq:4.44.2:amd64,arm64"
    "jq:1.7.1:amd64"
    "etcdctl:3.5.13:amd64,arm64"
    "skopeo:1.14.2:amd64,arm64"
    "manifest-tool:2.1.9:amd64,arm64"
  )

  for tool_info in "${tools[@]}"; do
    IFS=':' read -r tool_name tool_version tool_arch_pattern <<< "$tool_info"

    # 处理多架构模式 (如: amd64,arm64)
    IFS=',' read -r -a supported_archs <<< "$tool_arch_pattern"

    for tool_arch in "${supported_archs[@]}"; do
      # 检查当前架构是否在需要下载的架构列表中
      if [[ "${arch_list}" == *"${tool_arch}"* ]]; then
        log::info "  Downloading ${tool_name} for ${tool_arch}..."

        local arch_dir="${output_dir}/common/${tool_arch}"
        mkdir -p "${arch_dir}"

        local binary_file="${arch_dir}/${tool_name}"
        local download_url=""

        case "${tool_name}" in
          yq)
            download_url="https://github.com/mikefarah/yq/releases/download/v${tool_version}/yq_linux_${tool_arch}"
            ;;
          jq)
            # jq 目前只支持 amd64，arm64需要从其他源或自己编译
            if [[ "${tool_arch}" == "amd64" ]]; then
              download_url="https://github.com/stedolan/jq/releases/download/jq-${tool_version}/jq-linux64"
            else
              # arm64或其他架构：使用jq的Release Asset（如果可用）
              # 或者跳过下载并警告
              log::warn "  ✗ ${tool_name} official release only supports amd64 for ${tool_arch}"
              log::warn "    For ${tool_arch}, you may need to build from source or use an alternative"
              continue
            fi
            ;;
          etcdctl)
            download_url="https://github.com/etcd-io/etcd/releases/download/v${tool_version}/etcd-v${tool_version}-linux-${tool_arch}"
            binary_file="${arch_dir}/etcdctl"
            ;;
          skopeo)
            download_url="https://github.com/containers/skopeo/releases/download/v${tool_version}/skopeo-linux-${tool_arch}"
            ;;
          manifest-tool)
            download_url="https://github.com/estesp/manifest-tool/releases/download/v${tool_version}/manifest-tool-linux-${tool_arch}"
            ;;
        esac

        if [[ -n "${download_url}" ]]; then
          if curl -fL "${download_url}" -o "${binary_file}"; then
            chmod +x "${binary_file}"
            log::success "  ✓ ${tool_name} (${tool_arch}) downloaded successfully"
          else
            log::warn "  ✗ Failed to download ${tool_name} (${tool_arch})"
          fi
        fi
      fi
    done
  done

  log::success "Common tools binaries downloaded"
  return 0
}

#######################################
# 生成二进制BOM文件
# Arguments:
#   $1 - 输出文件路径
#   $2 - 二进制目录
# Returns:
#   0 成功, 1 失败
#######################################
utils::binary::bom::generate_bom() {
  local output_file="$1"
  local binaries_dir="$2"

  log::info "Generating Binary BOM..."

  {
    echo "# Binary Bill of Materials"
    echo "# Generated: $(date)"
    echo "# Binaries Directory: $binaries_dir"
    echo ""

    echo "# Kubernetes Binaries"
    if [[ -d "${binaries_dir}/kubernetes" ]]; then
      for k8s_dir in "${binaries_dir}/kubernetes"/*; do
        if [[ -d "${k8s_dir}" ]]; then
          local k8s_version
          k8s_version=$(basename "${k8s_dir}")
          echo "  Version: ${k8s_version}"

          for arch_dir in "${k8s_dir}"/*; do
            if [[ -d "${arch_dir}" ]]; then
              local arch
              arch=$(basename "${arch_dir}")
              echo "    Architecture: ${arch}"

              for binary in "${arch_dir}"/{kubeadm,kubelet,kubectl,kube-proxy}; do
                if [[ -f "${binary}" ]]; then
                  local binary_name
                  binary_name=$(basename "${binary}")
                  echo "      - ${binary_name}"
                fi
              done

              # 检查CNI插件
              if [[ -d "${arch_dir}/cni" ]]; then
                echo "      - cni-plugins/"
              fi
            fi
          done
        fi
      done
    else
      echo "  No Kubernetes binaries found"
    fi
    echo ""

    echo "# Container Runtime Binaries"
    if [[ -d "${binaries_dir}/containerd" ]]; then
      for runtime_dir in "${binaries_dir}/containerd"/*; do
        if [[ -d "${runtime_dir}" ]]; then
          local runtime_version
          runtime_version=$(basename "${runtime_dir}")
          echo "  Containerd: ${runtime_version}"

          for binary in "${runtime_dir}"/{containerd,crictl,runc}; do
            if [[ -f "${binary}" ]]; then
              local binary_name
              binary_name=$(basename "${binary}")
              echo "    - ${binary_name}"
            fi
          done
        fi
      done
    else
      echo "  No container runtime binaries found"
    fi
    echo ""

    echo "# Helm Binaries"
    if [[ -d "${binaries_dir}/helm" ]]; then
      for helm_dir in "${binaries_dir}/helm"/*; do
        if [[ -d "${helm_dir}" ]]; then
          local helm_version
          helm_version=$(basename "${helm_dir}")
          echo "  Version: ${helm_version}"

          for arch_dir in "${helm_dir}"/*; do
            if [[ -d "${arch_dir}" ]]; then
              local arch
              arch=$(basename "${arch_dir}")
              echo "    - ${arch}/helm"
            fi
          done
        fi
      done
    else
      echo "  No Helm binaries found"
    fi
    echo ""

    echo "# Common Tools"
    if [[ -d "${binaries_dir}/common" ]]; then
      for arch_dir in "${binaries_dir}/common"/*; do
        if [[ -d "${arch_dir}" ]]; then
          local arch
          arch=$(basename "${arch_dir}")
          echo "  Architecture: ${arch}"

          for binary in "${arch_dir}"/*; do
            if [[ -f "${binary}" ]]; then
              local binary_name
              binary_name=$(basename "${binary}")
              echo "    - ${binary_name}"
            fi
          done
        fi
      done
    else
      echo "  No common tools found"
    fi

  } > "${output_file}"

  log::success "Binary BOM generated: ${output_file}"
  return 0
}

#######################################
# 验证二进制文件完整性
# Arguments:
#   $1 - 二进制目录
# Returns:
#   0 成功, 1 失败
#######################################
utils::binary::bom::verify_binaries() {
  local binaries_dir="$1"

  log::info "Verifying binary files..."

  local failed_verifications=()

  # 验证Kubernetes二进制文件
  if [[ -d "${binaries_dir}/kubernetes" ]]; then
    for k8s_dir in "${binaries_dir}/kubernetes"/*; do
      if [[ -d "${k8s_dir}" ]]; then
        for arch_dir in "${k8s_dir}"/*; do
          if [[ -d "${arch_dir}" ]]; then
            for binary in "${arch_dir}"/{kubeadm,kubelet,kubectl,kube-proxy}; do
              if [[ -f "${binary}" ]]; then
                if ! "${binary}" version >/dev/null 2>&1; then
                  failed_verifications+=("${binary}")
                fi
              fi
            done
          fi
        done
      fi
    done
  fi

  # 验证containerd
  if [[ -d "${binaries_dir}/containerd" ]]; then
    for runtime_dir in "${binaries_dir}/containerd"/*; do
      if [[ -f "${runtime_dir}/containerd" ]]; then
        if ! "${runtime_dir}/containerd" --version >/dev/null 2>&1; then
          failed_verifications+=("${runtime_dir}/containerd")
        fi
      fi
    done
  fi

  # 验证Helm
  if [[ -d "${binaries_dir}/helm" ]]; then
    for helm_dir in "${binaries_dir}/helm"/*; do
      for arch_dir in "${helm_dir}"/*; do
        if [[ -f "${arch_dir}/helm" ]]; then
          if ! "${arch_dir}/helm" version >/dev/null 2>&1; then
            failed_verifications+=("${arch_dir}/helm")
          fi
        fi
      done
    done
  fi

  # 检查验证结果
  if [[ ${#failed_verifications[@]} -eq 0 ]]; then
    log::success "All binary files verified successfully"
    return 0
  else
    log::error "Failed to verify binaries: ${failed_verifications[*]}"
    return 1
  fi
}

#######################################
# 获取运行时二进制文件信息
# Arguments:
#   $1 - 运行时类型 (docker, containerd, crio, podman)
#   $2 - Kubernetes版本
#   $3 - 架构列表 (如 "amd64 arm64" 或 "amd64,arm64")
# Returns:
#   输出运行时二进制文件信息到stdout
#######################################
utils::binary::bom::show_runtime_binaries() {
  local runtime_type="$1"
  local k8s_version="$2"
  local arch_list="$3"

  # 获取版本
  local runtime_version
  runtime_version=$(versions::get "$runtime_type" "$k8s_version") || runtime_version="latest"
  local crictl_version
  crictl_version=$(versions::get "crictl" "$k8s_version")
  local runc_version
  runc_version=$(versions::get "runc" "$k8s_version")
  local cri_dockerd_version
  cri_dockerd_version=$(versions::get "cri_dockerd" "$k8s_version")
  local conmon_version
  conmon_version=$(versions::get "conmon" "$k8s_version")

  # 处理 arch_list，可能包含逗号或空格分隔
  # 将逗号替换为空格以便循环
  local clean_arch_list=$(echo "$arch_list" | tr ',' ' ')

  for arch in ${clean_arch_list}; do
    echo "  [${arch}]"
    case "${runtime_type}" in
      docker)
        echo "    docker: $(versions::get_docker_url "${arch}" "${runtime_version}")"
        echo "    cri-dockerd: $(versions::get_cri_dockerd_url "${arch}" "${cri_dockerd_version}")"
        echo "    crictl: $(versions::get_crictl_url "${arch}" "${crictl_version}")"
        echo "    runc: $(versions::get_runc_url "${arch}" "${runc_version}")"
        ;;
      containerd)
        echo "    containerd: $(versions::get_containerd_url "${arch}" "${runtime_version}")"
        echo "    crictl: $(versions::get_crictl_url "${arch}" "${crictl_version}")"
        echo "    runc: $(versions::get_runc_url "${arch}" "${runc_version}")"
        ;;
      crio)
        echo "    cri-o: $(versions::get_crio_url "${arch}" "${runtime_version}")"
        echo "    conmon: $(versions::get_conmon_url "${arch}" "${conmon_version}")"
        echo "    runc: $(versions::get_runc_url "${arch}" "${runc_version}")"
        echo "    crictl: $(versions::get_crictl_url "${arch}" "${crictl_version}")"
        ;;
      podman)
        echo "    podman: https://github.com/containers/podman/releases/download/v${runtime_version}/podman-remote-static.tar.gz"
        echo "    conmon: $(versions::get_conmon_url "${arch}" "${conmon_version}")"
        echo "    runc: $(versions::get_runc_url "${arch}" "${runc_version}")"
        echo "    crictl: $(versions::get_crictl_url "${arch}" "${crictl_version}")"
        ;;
      *)
        log::error "Unsupported runtime type: ${runtime_type}"
        return 1
        ;;
    esac
  done
}

# 导出函数
export -f utils::binary::bom::download_kubernetes_binaries
export -f utils::binary::bom::download_runtime_binaries
export -f utils::binary::bom::download_containerd_binaries
export -f utils::binary::bom::download_crio_binaries
export -f utils::binary::bom::download_podman_binaries
export -f utils::binary::bom::download_helm_binaries
export -f utils::binary::bom::download_skopeo_binaries
export -f utils::binary::bom::download_registry_binaries
export -f utils::binary::bom::download_common_tools
export -f utils::binary::bom::generate_bom
export -f utils::binary::bom::verify_binaries
export -f utils::binary::bom::show_runtime_binaries
