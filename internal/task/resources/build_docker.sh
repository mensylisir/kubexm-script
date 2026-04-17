#!/bin/bash
# =============================================================================
# KubeXM Script - Docker Build Management
# =============================================================================
# Purpose: Build and manage Docker images for containerized package building
# Supports 26 operating systems with multi-architecture support (amd64/arm64)
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Script Root Detection
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBEXM_ROOT="${KUBEXM_ROOT:-$(cd "${SCRIPT_DIR}/../../.." && pwd)}"
KUBEXM_SCRIPT_ROOT="${KUBEXM_SCRIPT_ROOT:-${KUBEXM_ROOT}}"

# Source required libraries
source "${KUBEXM_SCRIPT_ROOT}/internal/logger/log.sh"
source "${KUBEXM_SCRIPT_ROOT}/internal/config/config.sh"

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------
CONTAINER_DIR="${KUBEXM_SCRIPT_ROOT}/containers"
IMAGE_PREFIX="kubexm/build"
DEFAULT_TAG="latest"

# OS definitions: name:base_image:version:pkg_manager
declare -a OS_LIST=(
  # RPM 系
  "centos7:centos:7:yum"
  "centos8:quay.io/centos/centos:stream8:dnf"
  "rocky8:rockylinux/rockylinux:8:dnf"
  "rocky9:rockylinux/rockylinux:9:dnf"
  "almalinux8:almalinux:8:dnf"
  "almalinux9:almalinux:9:dnf"
  "ubuntu20:ubuntu:20.04:apt"
  "ubuntu22:ubuntu:22.04:apt"
  "ubuntu24:ubuntu:24.04:apt"
  "debian10:debian:10:apt"
  "debian11:debian:11:apt"
  "debian12:debian:12:apt"
  "kylin10:registry.cn-hangzhou.aliyuncs.com/kylin-release:kylin-release-10:dnf"
  "openeuler22:openeuler/openeuler:22.03-lts:dnf"
  "uos20:registry.cn-hangzhou.aliyuncs.com/uniontech-release:uos20:dnf"
  "rhel7:registry.access.redhat.com/rhel7:7:yum"
  "rhel8:registry.access.redhat.com/rhel8:8:dnf"
  "rhel9:registry.access.redhat.com/ubi9:9:dnf"
  "ol8:oraclelinux:8:dnf"
  "ol9:oraclelinux:9:dnf"
  "anolis8:openanolis/anolisos:8:dnf"
  "anolis9:openanolis/anolisos:9:dnf"
  "fedora39:fedora:39:dnf"
  "fedora40:fedora:40:dnf"
  "fedora41:fedora:41:dnf"
  "fedora42:fedora:42:dnf"
)

# Architecture mapping
declare -A ARCH_MAP=(
  ["amd64"]="linux/amd64"
  ["arm64"]="linux/arm64"
  ["x86_64"]="linux/amd64"
  ["aarch64"]="linux/arm64"
)

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

# Parse OS info
# Entry format: name:base_image:version:pkg_manager
# Note: base_image may contain colons (e.g., quay.io/centos/centos, registry.cn-hangzhou.aliyuncs.com/...)
build::parse_os_info() {
  local os_info="$1"
  local field="$2"

  case "${field}" in
    name)
      echo "${os_info%%:*}"
      ;;
    base)
      # Extract everything between first colon and last colon
      # e.g. "rockylinux/rockylinux:8" from "rocky8:rockylinux/rockylinux:8:dnf"
      local base_part="${os_info#*:}"
      echo "${base_part%:*}"
      ;;
    version)
      # Extract the version field (second-to-last field)
      local base_part="${os_info#*:}"
      local remaining="${base_part%:*}"
      echo "${remaining##*:}"
      ;;
    manager) echo "${os_info##*:}" ;;
  esac
}

# Check if Dockerfile exists for OS
build::dockerfile_exists() {
  local os_name="$1"
  [[ -f "${CONTAINER_DIR}/Dockerfile.${os_name}" ]]
}

# Get image name for OS
build::get_image_name() {
  local os_name="$1"
  local tag="${2:-${DEFAULT_TAG}}"
  echo "${IMAGE_PREFIX}-${os_name}:${tag}"
}

# Check if Docker is available
build::check_docker() {
  if ! command -v docker &>/dev/null; then
    log::error "Docker is not installed or not in PATH"
    return 1
  fi

  if ! docker info &>/dev/null; then
    log::error "Docker daemon is not running or permission denied"
    return 1
  fi

  return 0
}

# Check if Docker Buildx is available
build::check_buildx() {
  if docker buildx version &>/dev/null; then
    return 0
  else
    log::warn "Docker Buildx not available, multi-arch builds disabled"
    return 1
  fi
}

# -----------------------------------------------------------------------------
# Core Build Functions
# -----------------------------------------------------------------------------

# Build single Docker image
build::build_image() {
  local os_name="$1"
  local tag="${2:-${DEFAULT_TAG}}"
  local arch="${3:-}"
  local no_cache="${4:-false}"

  local dockerfile="${CONTAINER_DIR}/Dockerfile.${os_name}"
  local image_name
  image_name=$(build::get_image_name "${os_name}" "${tag}")

  if [[ ! -f "${dockerfile}" ]]; then
    log::error "Dockerfile not found: ${dockerfile}"
    return 1
  fi

  log::info "Building image: ${image_name}"
  log::info "  Dockerfile: ${dockerfile}"
  [[ -n "${arch}" ]] && log::info "  Architecture: ${arch}"

  local build_args=()
  build_args+=("-f" "${dockerfile}")
  build_args+=("-t" "${image_name}")
  build_args+=("--label" "kubexm.os=${os_name}")
  build_args+=("--label" "kubexm.version=${tag}")
  build_args+=("--label" "kubexm.build-date=$(date -u +%Y-%m-%dT%H:%M:%SZ)")

  [[ "${no_cache}" == "true" ]] && build_args+=("--no-cache")

  # Add platform if specified
  if [[ -n "${arch}" ]]; then
    local platform="${ARCH_MAP[${arch}]:-linux/${arch}}"
    build_args+=("--platform" "${platform}")
  fi

  build_args+=("${CONTAINER_DIR}")

  if docker build "${build_args[@]}"; then
    log::info "  ✓ Image built successfully: ${image_name}"
    return 0
  else
    log::error "  ✗ Failed to build image: ${image_name}"
    return 1
  fi
}

# Build multiple images in parallel
build::build_images_parallel() {
  local os_list=("$@")
  local tag="${DEFAULT_TAG}"
  local max_parallel="${BUILD_PARALLEL:-4}"

  log::info "Building ${#os_list[@]} images (max parallel: ${max_parallel})"

  local pids=()
  local results=()
  local current=0

  for os_info in "${os_list[@]}"; do
    local os_name
    os_name=$(build::parse_os_info "${os_info}" "name")

    # Wait if max parallel reached
    while [[ ${#pids[@]} -ge ${max_parallel} ]]; do
      for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
          wait "${pids[$i]}" || results+=("${os_name}:failed")
          unset 'pids[i]'
        fi
      done
      pids=("${pids[@]}")
      sleep 0.5
    done

    # Start build in background
    (
      if build::build_image "${os_name}" "${tag}"; then
        exit 0
      else
        exit 1
      fi
    ) &
    pids+=($!)
    ((current++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e

    log::info "Started build ${current}/${#os_list[@]}: ${os_name}"
  done

  # Wait for remaining builds
  log::info "Waiting for remaining builds to complete..."
  for pid in "${pids[@]}"; do
    wait "${pid}" || true
  done

  log::info "All builds completed"
}

# Build all images
build::build_all() {
  local tag="${1:-${DEFAULT_TAG}}"
  local no_cache="${2:-false}"

  log::info "Building all Docker images"
  log::info "Tag: ${tag}, No-cache: ${no_cache}"

  local success_count=0
  local fail_count=0
  local failed_os=()

  for os_info in "${OS_LIST[@]}"; do
    local os_name
    os_name=$(build::parse_os_info "${os_info}" "name")

    if build::dockerfile_exists "${os_name}"; then
      if build::build_image "${os_name}" "${tag}" "" "${no_cache}"; then
        ((success_count++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
      else
        ((fail_count++)) || true  # ((expr)) returns exit 1 when expr==0; triggers errexit with set -e
        failed_os+=("${os_name}")
      fi
    else
      log::warn "Skipping ${os_name}: Dockerfile not found"
    fi
  done

  log::info "Build summary: ${success_count} succeeded, ${fail_count} failed"
  if [[ ${fail_count} -gt 0 ]]; then
    log::warn "Failed OS: ${failed_os[*]}"
    return 1
  fi

  return 0
}

# Build multi-arch image using buildx
build::build_multiarch() {
  local os_name="$1"
  local tag="${2:-${DEFAULT_TAG}}"
  local arches="${3:-amd64,arm64}"
  local push="${4:-false}"

  if ! build::check_buildx; then
    log::error "Docker Buildx required for multi-arch builds"
    return 1
  fi

  local dockerfile="${CONTAINER_DIR}/Dockerfile.${os_name}"
  local image_name
  image_name=$(build::get_image_name "${os_name}" "${tag}")

  if [[ ! -f "${dockerfile}" ]]; then
    log::error "Dockerfile not found: ${dockerfile}"
    return 1
  fi

  log::info "Building multi-arch image: ${image_name}"
  log::info "  Architectures: ${arches}"

  # Convert arch list to platform list
  local platforms=""
  IFS=',' read -ra arch_array <<< "${arches}"
  for arch in "${arch_array[@]}"; do
    local platform="${ARCH_MAP[${arch}]:-linux/${arch}}"
    [[ -n "${platforms}" ]] && platforms+=","
    platforms+="${platform}"
  done

  local build_args=()
  build_args+=("buildx" "build")
  build_args+=("-f" "${dockerfile}")
  build_args+=("-t" "${image_name}")
  build_args+=("--platform" "${platforms}")
  build_args+=("--label" "kubexm.os=${os_name}")
  build_args+=("--label" "kubexm.version=${tag}")
  build_args+=("--label" "kubexm.arch=${arches}")

  if [[ "${push}" == "true" ]]; then
    build_args+=("--push")
  else
    build_args+=("--load")
  fi

  build_args+=("${CONTAINER_DIR}")

  if docker "${build_args[@]}"; then
    log::info "  ✓ Multi-arch image built: ${image_name}"
    return 0
  else
    log::error "  ✗ Failed to build multi-arch image: ${image_name}"
    return 1
  fi
}

# -----------------------------------------------------------------------------
# Image Management Functions
# -----------------------------------------------------------------------------

# List built images
build::list_images() {
  log::info "Listing KubeXM build images:"
  docker images --filter "label=kubexm.os" --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
}

# Remove image
build::remove_image() {
  local os_name="$1"
  local tag="${2:-${DEFAULT_TAG}}"

  local image_name
  image_name=$(build::get_image_name "${os_name}" "${tag}")

  if docker rmi "${image_name}" 2>/dev/null; then
    log::info "Removed image: ${image_name}"
    return 0
  else
    log::warn "Image not found or could not be removed: ${image_name}"
    return 1
  fi
}

# Remove all images
build::remove_all_images() {
  log::info "Removing all KubeXM build images"

  local images
  images=$(docker images --filter "label=kubexm.os" -q)

  if [[ -z "${images}" ]]; then
    log::info "No KubeXM images found"
    return 0
  fi

  echo "${images}" | xargs docker rmi -f
  log::info "All KubeXM images removed"
}

# -----------------------------------------------------------------------------
# Container Execution Functions
# -----------------------------------------------------------------------------

# Run package build in container
build::run_package_build() {
  local os_name="$1"
  local package_list="$2"
  local output_dir="$3"
  local arch="${4:-$(defaults::get_arch)}"
  local tag="${5:-${DEFAULT_TAG}}"

  local image_name
  image_name=$(build::get_image_name "${os_name}" "${tag}")

  # Ensure image exists
  if ! docker image inspect "${image_name}" &>/dev/null; then
    log::warn "Image not found, building first: ${image_name}"
    build::build_image "${os_name}" "${tag}" || return 1
  fi

  log::info "Running package build in container"
  log::info "  Image: ${image_name}"
  log::info "  Package list: ${package_list}"
  log::info "  Output: ${output_dir}"
  log::info "  Architecture: ${arch}"

  mkdir -p "${output_dir}"

  # Determine build script based on package manager
  local pkg_manager=""
  for os_info in "${OS_LIST[@]}"; do
    local name
    name=$(build::parse_os_info "${os_info}" "name")
    if [[ "${name}" == "${os_name}" ]]; then
      pkg_manager=$(build::parse_os_info "${os_info}" "manager")
      break
    fi
  done

  local build_script=""
  case "${pkg_manager}" in
    yum|dnf) build_script="build-rpm.sh" ;;
    apt)     build_script="build-deb.sh" ;;
    *)
      log::error "Unknown package manager for ${os_name}"
      return 1
      ;;
  esac

  # Run container
  docker run --rm \
    -v "${package_list}:/build/package_list.txt:ro" \
    -v "${output_dir}:/build/output" \
    "${image_name}" \
    /build/${build_script} full /build/package_list.txt /build/output "${arch}"

  local exit_code=$?

  if [[ ${exit_code} -eq 0 ]]; then
    log::info "Package build completed successfully"
    log::info "Output directory: ${output_dir}"
  else
    log::error "Package build failed with exit code: ${exit_code}"
  fi

  return ${exit_code}
}

# Run shell in container
build::run_shell() {
  local os_name="$1"
  local tag="${2:-${DEFAULT_TAG}}"

  local image_name
  image_name=$(build::get_image_name "${os_name}" "${tag}")

  # Ensure image exists
  if ! docker image inspect "${image_name}" &>/dev/null; then
    log::warn "Image not found, building first: ${image_name}"
    build::build_image "${os_name}" "${tag}" || return 1
  fi

  log::info "Starting shell in container: ${image_name}"

  docker run --rm -it \
    -v "${KUBEXM_SCRIPT_ROOT}:/workspace:ro" \
    "${image_name}" \
    /bin/bash
}

# -----------------------------------------------------------------------------
# Status and Information Functions
# -----------------------------------------------------------------------------

# Show supported OS list
build::show_os_list() {
  log::info "Supported Operating Systems:"
  echo ""
  printf "%-15s %-40s %-10s\n" "OS Name" "Base Image" "Pkg Manager"
  printf "%-15s %-40s %-10s\n" "-------" "----------" "-----------"

  for os_info in "${OS_LIST[@]}"; do
    local os_name base_image pkg_manager
    os_name=$(build::parse_os_info "${os_info}" "name")
    base_image=$(build::parse_os_info "${os_info}" "base")
    pkg_manager=$(build::parse_os_info "${os_info}" "manager")

    local dockerfile_status=""
    if build::dockerfile_exists "${os_name}"; then
      dockerfile_status="✓"
    else
      dockerfile_status="✗"
    fi

    printf "%-15s %-40s %-10s %s\n" "${os_name}" "${base_image}" "${pkg_manager}" "${dockerfile_status}"
  done

  echo ""
  echo "✓ = Dockerfile exists, ✗ = Dockerfile missing"
}

# Show build status
build::show_status() {
  log::info "KubeXM Build System Status"
  echo ""

  # Docker status
  if build::check_docker; then
    echo "Docker: ✓ Available"
    docker version --format 'Docker Version: {{.Server.Version}}'
  else
    echo "Docker: ✗ Not available"
  fi

  # Buildx status
  if build::check_buildx; then
    echo "Buildx: ✓ Available"
  else
    echo "Buildx: ✗ Not available"
  fi

  echo ""

  # Image status
  log::info "Built Images:"
  build::list_images
}

# -----------------------------------------------------------------------------
# Main Entry Point
# -----------------------------------------------------------------------------
build::docker::main() {
  local action="${1:-}"
  shift || true

  case "${action}" in
    build)
      local os_name="${1:?OS name required (e.g., centos7, ubuntu22)}"
      local tag="${2:-${DEFAULT_TAG}}"
      local arch="${3:-}"
      local no_cache="${4:-false}"
      build::check_docker || return 1
      build::build_image "${os_name}" "${tag}" "${arch}" "${no_cache}"
      ;;
    build-all)
      local tag="${1:-${DEFAULT_TAG}}"
      local no_cache="${2:-false}"
      build::check_docker || return 1
      build::build_all "${tag}" "${no_cache}"
      ;;
    build-multiarch)
      local os_name="${1:?OS name required}"
      local tag="${2:-${DEFAULT_TAG}}"
      local arches="${3:-amd64,arm64}"
      local push="${4:-false}"
      build::check_docker || return 1
      build::build_multiarch "${os_name}" "${tag}" "${arches}" "${push}"
      ;;
    run)
      local os_name="${1:?OS name required}"
      local package_list="${2:?Package list file required}"
      local output_dir="${3:?Output directory required}"
      local arch="${4:-$(defaults::get_arch)}"
      build::check_docker || return 1
      build::run_package_build "${os_name}" "${package_list}" "${output_dir}" "${arch}"
      ;;
    shell)
      local os_name="${1:?OS name required}"
      local tag="${2:-${DEFAULT_TAG}}"
      build::check_docker || return 1
      build::run_shell "${os_name}" "${tag}"
      ;;
    list)
      build::check_docker || return 1
      build::list_images
      ;;
    remove)
      local os_name="${1:?OS name required}"
      local tag="${2:-${DEFAULT_TAG}}"
      build::check_docker || return 1
      build::remove_image "${os_name}" "${tag}"
      ;;
    remove-all)
      build::check_docker || return 1
      build::remove_all_images
      ;;
    os-list)
      build::show_os_list
      ;;
    status)
      build::show_status
      ;;
    help|--help|-h)
      cat << 'EOF'
KubeXM Docker Build Management

Usage: build-docker.sh <action> [options]

Actions:
  build <os> [tag] [arch] [no-cache]    Build single Docker image
  build-all [tag] [no-cache]            Build all Docker images
  build-multiarch <os> [tag] [arches]   Build multi-arch image using buildx
  run <os> <pkg_list> <output> [arch]   Run package build in container
  shell <os> [tag]                      Start shell in container
  list                                  List built images
  remove <os> [tag]                     Remove image
  remove-all                            Remove all KubeXM images
  os-list                               Show supported OS list
  status                                Show build system status
  help                                  Show this help

Supported OS (26 total):
  # RPM
  centos7, centos8, rocky8, rocky9, almalinux8, almalinux9,
  openeuler22, uos20, kylin10, rhel7, rhel8, rhel9, ol8, ol9,
  anolis8, anolis9, fedora39, fedora40, fedora41, fedora42,
  # APT
  ubuntu20, ubuntu22, ubuntu24, debian10, debian11, debian12

Examples:
  # Build CentOS 7 image
  build-docker.sh build centos7

  # Build all images
  build-docker.sh build-all

  # Build multi-arch Ubuntu 22.04 image
  build-docker.sh build-multiarch ubuntu22 latest amd64,arm64

  # Run package build for CentOS 7
  build-docker.sh run centos7 /path/to/packages.txt /output/dir

  # Start shell in Rocky 9 container
  build-docker.sh shell rocky9

Environment Variables:
  KUBEXM_SCRIPT_ROOT     Script root directory
  BUILD_PARALLEL         Max parallel builds (default: 4)
  DEBUG                  Enable debug output (true/false)
EOF
      ;;
    *)
      log::error "Unknown action: ${action}"
      echo "Use 'build-docker.sh help' for usage information"
      return 1
      ;;
  esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  build::docker::main "$@"
fi
