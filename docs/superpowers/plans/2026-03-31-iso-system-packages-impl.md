# System Packages ISO 增强实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 增强 kubexm ISO 构建系统，支持 26 个 OS，完善 DEB 依赖解析，实现 Host/Docker 双模式，构建 per-OS 独立 ISO。

**Architecture:**
- Phase 1: OS 列表修正 + 新增 16 个 Dockerfile（rhel/ol/anolis/fedora/ubuntu24/debian10/rhel9/rocky8/almalinux8）
- Phase 2: 扩展 defaults.sh ISO 包常量 + 智能推断逻辑
- Phase 3: 整合到 pipeline — 修改 iso_build_system_packages.sh + task::iso_build
- Phase 4: 端到端验证

**Tech Stack:** Bash, Docker, mkisofs/genisoimage/xorriso, dnf/yum/apt, createrepo, dpkg-scanpackages

---

## 文件变更总览

| 操作 | 文件 | 说明 |
|------|------|------|
| Modify | `internal/utils/resources/build_docker.sh` | 修正 OS 列表（uos20 → dnf），新增 16 个 OS |
| Create | `containers/Dockerfile.rocky8` | Rocky Linux 8 RPM |
| Create | `containers/Dockerfile.almalinux8` | AlmaLinux 8 RPM |
| Create | `containers/Dockerfile.rhel7` | RHEL 7 RPM |
| Create | `containers/Dockerfile.rhel8` | RHEL 8 RPM |
| Create | `containers/Dockerfile.rhel9` | RHEL 9 RPM |
| Create | `containers/Dockerfile.ol8` | Oracle Linux 8 RPM |
| Create | `containers/Dockerfile.ol9` | Oracle Linux 9 RPM |
| Create | `containers/Dockerfile.anolis8` | Anolis 8 RPM |
| Create | `containers/Dockerfile.anolis9` | Anolis 9 RPM |
| Create | `containers/Dockerfile.fedora39` | Fedora 39 RPM |
| Create | `containers/Dockerfile.fedora40` | Fedora 40 RPM |
| Create | `containers/Dockerfile.fedora41` | Fedora 41 RPM |
| Create | `containers/Dockerfile.fedora42` | Fedora 42 RPM |
| Create | `containers/Dockerfile.ubuntu24` | Ubuntu 24.04 DEB |
| Create | `containers/Dockerfile.debian10` | Debian 10 DEB |
| Modify | `containers/scripts/build-deb.sh` | 改进 DEB 依赖解析（递归展开） |
| Modify | `internal/config/defaults.sh` | 新增 ISO 专用包常量 + defaults::get_iso_packages |
| Modify | `internal/utils/resources/system_iso.sh` | 支持新 OS 列表 + per-OS ISO 输出 |
| Modify | `internal/task/infra/iso_build/main.sh` | 支持多值 --with-build-os/--with-build-arch |
| Modify | `internal/step/iso/iso_build_system_packages.sh` | 集成 per-OS ISO 构建 |
| Modify | `internal/config/defaults.sh` | 更新 DEFAULT_BUILD_OS_LIST |

---

## Task 1: 修正 OS 列表 + 新增 OS 定义

**Files:**
- Modify: `internal/utils/resources/build_docker.sh:30-44`

- [ ] **Step 1: 修正 OS_LIST 数组**

替换 `build_docker.sh` 第 30-44 行的 `OS_LIST` 数组，将 `uos20` 从 `debian:10:apt` 改为 `dnf` 系，并新增 16 个 OS：

```bash
# OS definitions: name:base_image:pkg_manager
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
```

> 注：kylin10 和 uos20 基础镜像使用阿里云镜像（需要用户自行替换或提供）。RHEL 用 UBI（Universal Base Image）替代官方镜像以避免订阅问题。

- [ ] **Step 2: 更新 parse_os_info 的 base 字段解析**

当前 `base` 解析为 `cut -d: -f2-3`，但新格式 `rockylinux/rockylinux:9` 有两个冒号。需要修改：

```bash
# Parse OS info
build::parse_os_info() {
  local os_info="$1"
  local field="$2"

  case "${field}" in
    name)    echo "${os_info%%:*}" ;;
    base)
      # Extract everything between first colon and last colon
      local base_part="${os_info#*:}"
      echo "${base_part%:*}"
      ;;
    manager) echo "${os_info##*:}" ;;
  esac
}
```

- [ ] **Step 3: 更新帮助文本和注释**

修改 `build_docker.sh` 中第 6 行注释 `"Supports 13 operating systems"` → `"Supports 26 operating systems"`，以及 help 信息中的 OS 列表。

- [ ] **Step 4: 提交**

```bash
git add internal/utils/resources/build_docker.sh
git commit -m "feat(iso): expand OS support to 26 OSes, fix uos20 as RPM"
```

---

## Task 2: 创建缺失的 Dockerfile（RPM 系）

**Files:**
- Create: `containers/Dockerfile.rocky8`
- Create: `containers/Dockerfile.almalinux8`
- Create: `containers/Dockerfile.rhel7`
- Create: `containers/Dockerfile.rhel8`
- Create: `containers/Dockerfile.rhel9`
- Create: `containers/Dockerfile.ol8`
- Create: `containers/Dockerfile.ol9`
- Create: `containers/Dockerfile.anolis8`
- Create: `containers/Dockerfile.anolis9`
- Create: `containers/Dockerfile.fedora39`
- Create: `containers/Dockerfile.fedora40`
- Create: `containers/Dockerfile.fedora41`
- Create: `containers/Dockerfile.fedora42`

RPM Dockerfile 统一模板（各 OS 仅换基础镜像）：

```dockerfile
FROM rockylinux:8
RUN dnf install -y dnf-plugins-core createrepo_c && dnf clean all
COPY containers/scripts/build-rpm.sh /build-rpm.sh
ENTRYPOINT ["/build-rpm.sh"]
```

- [ ] **Step 1: 创建 6 个 EL 系 Dockerfile（rocky8, almalinux8, rhel8/rhel9/ol8/ol9）**

使用 `rockylinux:8` 或 `rockylinux:9` 或 `oraclelinux:8/9` 或 `registry.access.redhat.com/ubi8/ubi9` 作为基础镜像。统一使用 `dnf`。

```dockerfile
# containers/Dockerfile.rocky8
FROM rockylinux/rockylinux:8
RUN dnf install -y dnf-plugins-core createrepo_c && dnf clean all
COPY containers/scripts/build-rpm.sh /build-rpm.sh
ENTRYPOINT ["/build-rpm.sh"]
```

```dockerfile
# containers/Dockerfile.almalinux8
FROM almalinux/almalinux:8
RUN dnf install -y dnf-plugins-core createrepo_c && dnf clean all
COPY containers/scripts/build-rpm.sh /build-rpm.sh
ENTRYPOINT ["/build-rpm.sh"]
```

```dockerfile
# containers/Dockerfile.rhel7
FROM registry.access.redhat.com/rhel7
RUN yum install -y yum-utils createrepo && yum clean all
COPY containers/scripts/build-rpm.sh /build-rpm.sh
ENTRYPOINT ["/build-rpm.sh"]
```

```dockerfile
# containers/Dockerfile.rhel8
FROM registry.access.redhat.com/ubi8
RUN dnf install -y dnf-plugins-core createrepo_c && dnf clean all
COPY containers/scripts/build-rpm.sh /build-rpm.sh
ENTRYPOINT ["/build-rpm.sh"]
```

```dockerfile
# containers/Dockerfile.rhel9
FROM registry.access.redhat.com/ubi9
RUN dnf install -y dnf-plugins-core createrepo_c && dnf clean all
COPY containers/scripts/build-rpm.sh /build-rpm.sh
ENTRYPOINT ["/build-rpm.sh"]
```

```dockerfile
# containers/Dockerfile.ol8
FROM oraclelinux:8
RUN dnf install -y dnf-plugins-core createrepo_c && dnf clean all
COPY containers/scripts/build-rpm.sh /build-rpm.sh
ENTRYPOINT ["/build-rpm.sh"]
```

```dockerfile
# containers/Dockerfile.ol9
FROM oraclelinux:9
RUN dnf install -y dnf-plugins-core createrepo_c && dnf clean all
COPY containers/scripts/build-rpm.sh /build-rpm.sh
ENTRYPOINT ["/build-rpm.sh"]
```

- [ ] **Step 2: 创建龙蜥 Dockerfile（anolis8, anolis9）**

```dockerfile
# containers/Dockerfile.anolis8
FROM openanolis/anolisos:8
RUN dnf install -y dnf-plugins-core createrepo_c && dnf clean all
COPY containers/scripts/build-rpm.sh /build-rpm.sh
ENTRYPOINT ["/build-rpm.sh"]
```

```dockerfile
# containers/Dockerfile.anolis9
FROM openanolis/anolisos:9
RUN dnf install -y dnf-plugins-core createrepo_c && dnf clean all
COPY containers/scripts/build-rpm.sh /build-rpm.sh
ENTRYPOINT ["/build-rpm.sh"]
```

- [ ] **Step 3: 创建 Fedora 系列 Dockerfile（fedora39-42）**

Fedora 官方镜像不需要额外订阅，统一用 `fedora:NN`：

```dockerfile
# containers/Dockerfile.fedora39
FROM fedora:39
RUN dnf install -y dnf-plugins-core createrepo_c && dnf clean all
COPY containers/scripts/build-rpm.sh /build-rpm.sh
ENTRYPOINT ["/build-rpm.sh"]
```

（fedora40, fedora41, fedora42 同样模板，仅换版本号）

- [ ] **Step 4: 提交**

```bash
git add containers/Dockerfile.{rocky8,almalinux8,rhel7,rhel8,rhel9,ol8,ol9,anolis8,anolis9,fedora39,fedora40,fedora41,fedora42}
git commit -m "feat(iso): add 13 new RPM-based Dockerfiles for ISO building"
```

---

## Task 3: 创建缺失的 Dockerfile（DEB 系）

**Files:**
- Create: `containers/Dockerfile.ubuntu24`
- Create: `containers/Dockerfile.debian10`

- [ ] **Step 1: 创建 ubuntu24 Dockerfile**

DEB 系 Dockerfile 需要 `apt-utils`, `dpkg-dev`, `apt-rdepends`（用于依赖解析）：

```dockerfile
# containers/Dockerfile.ubuntu24
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y \
    apt-utils dpkg-dev apt-rdepends ca-certificates gnupg && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
COPY containers/scripts/build-deb.sh /build-deb.sh
ENTRYPOINT ["/build-deb.sh"]
```

- [ ] **Step 2: 创建 debian10 Dockerfile**

```dockerfile
# containers/Dockerfile.debian10
FROM debian:10
RUN apt-get update && apt-get install -y \
    apt-utils dpkg-dev apt-rdepends ca-certificates gnupg && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
COPY containers/scripts/build-deb.sh /build-deb.sh
ENTRYPOINT ["/build-deb.sh"]
```

- [ ] **Step 3: 更新 ubuntu22 Dockerfile（确保包含 apt-rdepends）**

读取现有 `Dockerfile.ubuntu22`，确认包含 `apt-rdepends`。如不包含则添加。

- [ ] **Step 4: 提交**

```bash
git add containers/Dockerfile.{ubuntu24,debian10}
git add containers/Dockerfile.ubuntu22  # if modified
git commit -m "feat(iso): add ubuntu24 and debian10 Dockerfiles, ensure apt-rdepends"
```

---

## Task 4: 改进 DEB 依赖解析

**Files:**
- Modify: `containers/scripts/build-deb.sh`

当前 `deb::get_dependencies()` 使用 `apt-rdepends` 递归获取依赖，但逻辑可改进以避免循环依赖和深度爆炸。

- [ ] **Step 1: 重写 deb::get_dependencies 使用递归 + visited 过滤**

替换 `build-deb.sh` 中的 `deb::get_dependencies` 函数：

```bash
# Get all dependencies for a package recursively, with circular dependency protection
deb::get_dependencies() {
  local package="$1"
  local visited="${2:-}"

  # Avoid circular dependencies
  if [[ " ${visited} " == *" ${package} "* ]]; then
    return
  fi
  visited="${visited} ${package}"

  # Get direct dependencies
  local deps
  deps=$(apt-cache depends --recurse --no-recommends --no-suggests \
    --no-conflicts --no-breaks --no-replaces --no-enhances \
    "${package}" 2>/dev/null | \
    grep "^Depends:" | awk '{print $2}' | sed 's/<.*>//g' | sort -u)

  for dep in ${deps}; do
    deb::get_dependencies_recursive "${dep}" "${visited}"
  done

  echo "${package}"
}

deb::get_dependencies_recursive() {
  local package="$1"
  local visited="$2"

  [[ " ${visited} " == *" ${package} "* ]] && return
  visited="${visited} ${package}"

  local deps
  deps=$(apt-cache depends --recurse --no-recommends \
    "${package}" 2>/dev/null | \
    grep "^Depends:" | awk '{print $2}' | sed 's/<.*>//g' | sort -u)

  for dep in ${deps}; do
    deb::get_dependencies_recursive "${dep}" "${visited}"
  done

  echo "${package}"
}
```

- [ ] **Step 2: 更新 download 函数使用改进的依赖解析**

替换 `deb::download_packages` 函数，改为先收集所有包再统一下载：

```bash
deb::download_packages() {
  local package_list="$1"
  local output_dir="$2"
  local arch="${3:-amd64}"

  log::info "Downloading DEB packages to ${output_dir}"
  log::info "Architecture: ${arch}"

  mkdir -p "${output_dir}"
  cd "${output_dir}"

  # Update package cache
  log::info "Updating package cache..."
  apt-get update -qq

  # Collect all packages with dependencies
  log::info "Collecting packages and dependencies..."
  local all_packages=""
  local total_packages=0

  while IFS= read -r package || [[ -n "$package" ]]; do
    [[ -z "$package" || "$package" =~ ^# ]] && continue
    ((total_packages++))
    log::info "  [${total_packages}] ${package}"
    all_packages="${all_packages}$(deb::get_dependencies "${package}")"$' '
  done < "${package_list}"

  # Deduplicate
  local unique_packages
  unique_packages=$(echo "${all_packages}" | tr ' ' '\n' | sort -u | grep -v '^$')
  local unique_count
  unique_count=$(echo "${unique_packages}" | wc -l)
  log::info "Total unique packages to download: ${unique_count}"

  # Filter out already-installed packages
  local installed
  installed=$(dpkg-query -W -f='${Package}\n' 2>/dev/null | sort)
  local to_download
  to_download=$(comm -23 <(echo "${unique_packages}") <(echo "${installed}") | grep -v '^$')

  log::info "Packages to download (excluding installed): $(echo "${to_download}" | wc -l)"

  # Download
  local success_count=0
  local fail_count=0
  local download_count=0

  while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    ((download_count++))

    if apt-get download "${pkg}:${arch}" 2>/dev/null; then
      ((success_count++))
    elif apt-get download "${pkg}" 2>/dev/null; then
      ((success_count++))
    else
      ((fail_count++))
      log::warn "  ✗ Failed: ${pkg}"
    fi

    # Progress log every 10 packages
    [[ $((download_count % 10)) -eq 0 ]] && log::info "  Progress: ${download_count}/${unique_count}"
  done <<< "${to_download}"

  log::info "Download complete: ${success_count} succeeded, ${fail_count} failed"

  return 0
}
```

- [ ] **Step 3: 提交**

```bash
git add containers/scripts/build-deb.sh
git commit -m "feat(iso): improve DEB dependency resolution with recursive expansion and circular dependency protection"
```

---

## Task 5: 扩展 defaults.sh — ISO 专用包常量 + 智能推断

**Files:**
- Modify: `internal/config/defaults.sh`

- [ ] **Step 1: 新增 ISO 专用包常量（放在文件末尾，export 之前）**

在 `defaults.sh` 末尾（`export -f` 块之前）添加：

```bash
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
```

- [ ] **Step 2: 新增 defaults::get_iso_packages 函数**

在 `defaults.sh` 末尾添加：

```bash
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

# 导出新增函数
export -f defaults::get_iso_packages
```

- [ ] **Step 3: 更新 DEFAULT_BUILD_OS_LIST**

将 `defaults.sh` 中的 `DEFAULT_BUILD_OS_LIST` 从默认值改为更全面的列表：

```bash
DEFAULT_BUILD_OS_LIST="centos7,rocky9,almalinux9,ubuntu22,debian12"
```

（改为更实用的默认列表，不要 26 个全上）

- [ ] **Step 4: 提交**

```bash
git add internal/config/defaults.sh
git commit -m "feat(iso): add ISO package constants and defaults::get_iso_packages with intelligent inference"
```

---

## Task 6: 整合 pipeline — per-OS ISO 输出

**Files:**
- Modify: `internal/utils/resources/system_iso.sh`
- Modify: `internal/step/iso/iso_build_system_packages.sh`
- Modify: `internal/task/infra/iso_build/main.sh`

- [ ] **Step 1: 扩展 system_iso::parse_os 支持所有 26 个 OS**

替换 `system_iso.sh` 中的 `system_iso::parse_os` 函数：

```bash
system_iso::parse_os() {
  local os_id="$1"
  case "${os_id}" in
    centos7)  echo "centos" "7" ;;
    centos8)  echo "centos" "8" ;;
    rocky8)   echo "rocky" "8" ;;
    rocky9)   echo "rocky" "9" ;;
    almalinux8)  echo "almalinux" "8" ;;
    almalinux9)  echo "almalinux" "9" ;;
    ubuntu20) echo "ubuntu" "20.04" ;;
    ubuntu22) echo "ubuntu" "22.04" ;;
    ubuntu24) echo "ubuntu" "24.04" ;;
    debian10) echo "debian" "10" ;;
    debian11) echo "debian" "11" ;;
    debian12) echo "debian" "12" ;;
    uos20)    echo "uos" "20" ;;
    kylin10)  echo "kylin" "10" ;;
    openeuler22) echo "openeuler" "22" ;;
    rhel7)    echo "rhel" "7" ;;
    rhel8)    echo "rhel" "8" ;;
    rhel9)    echo "rhel" "9" ;;
    ol8)      echo "ol" "8" ;;
    ol9)      echo "ol" "9" ;;
    anolis8)  echo "anolis" "8" ;;
    anolis9)  echo "anolis" "9" ;;
    fedora39) echo "fedora" "39" ;;
    fedora40) echo "fedora" "40" ;;
    fedora41) echo "fedora" "41" ;;
    fedora42) echo "fedora" "42" ;;
    *)        echo "${os_id}" "" ;;
  esac
}
```

- [ ] **Step 2: 更新 system_iso::generate_repo_config 支持新增 OS**

在 `system_iso::generate_repo_config` 的 case 语句中添加对新 OS 的支持（centos*, rocky*, almalinux*, rhel*, ol*, anolis*, fedora*, kylin*, openeuler*, uos* → RPM repo；debian*, ubuntu* → DEB list）。

- [ ] **Step 3: 更新 step iso_build_system_packages.sh 调用 build_per_os**

修改 `step/iso/iso_build_system_packages.sh` 的 `run()` 函数，改为调用 `system_iso::build_per_os` 而非 `system_iso::build`，输出路径改为：

```bash
local output_base="${KUBEXM_ROOT}/packages/iso"
system_iso::build_per_os "${output_base}" "${build_iso_params}" "${first_arch}" "${KUBEXM_BUILD_LOCAL:-false}"
```

- [ ] **Step 4: 更新 task::iso_build 支持逗号分隔多值**

修改 `internal/task/infra/iso_build/main.sh` 中的 `_task::iso_parse_args`，支持 `--with-build-os=` 传入逗号分隔的多个 OS（如 `rocky9,ubuntu22,fedora42`）以及 `--with-build-arch=` 传入逗号分隔的多个架构（如 `amd64,arm64`）。每个 OS × 每个 arch 组合生成一个 ISO。

- [ ] **Step 5: 提交**

```bash
git add internal/utils/resources/system_iso.sh
git add internal/step/iso/iso_build_system_packages.sh
git add internal/task/infra/iso_build/main.sh
git commit -m "feat(iso): integrate per-OS ISO build pipeline with multi-OS multi-arch support"
```

---

## Task 7: 端到端测试

**Files:**
- Modify: `tests/cases/` (如有现有测试)

- [ ] **Step 1: 验证 rocky9 amd64 ISO 构建（Docker 模式）**

```bash
cd /home/mensyli1/Documents/workspace/sre/kubexm-script
./bin/kubexm create iso --with-build-os=rocky9 --with-build-arch=amd64
# 预期：生成 packages/iso/rocky/9/amd64/rocky-9-amd64.iso
ls -lh packages/iso/rocky/9/amd64/*.iso
```

- [ ] **Step 2: 验证 ubuntu22 amd64 ISO 构建（Docker 模式）**

```bash
./bin/kubexm create iso --with-build-os=ubuntu22 --with-build-arch=amd64
# 预期：生成 packages/iso/ubuntu/22.04/amd64/ubuntu-22.04-amd64.iso
ls -lh packages/iso/ubuntu/22.04/amd64/*.iso
```

- [ ] **Step 3: 验证 ISO checksum 校验**

```bash
sha256sum packages/iso/rocky/9/amd64/*.iso
cat packages/iso/rocky/9/amd64/*.iso.sha256  # 或手动比对
```

- [ ] **Step 4: 验证 ISO 内容结构**

```bash
mkdir /tmp/iso_test
mount packages/iso/rocky/9/amd64/*.iso /tmp/iso_test -o loop
ls /tmp/iso_test/
# 预期看到：rocky/ (目录结构)、repo/、install/、README.txt
umount /tmp/iso_test
```

- [ ] **Step 5: 提交测试**

```bash
git add tests/cases/  # 如有新增测试
git commit -m "test(iso): add e2e tests for per-OS ISO build"
```

---

## 实现顺序

1. Task 1 — 修正 OS 列表（先做，后续任务依赖）
2. Task 2 — 创建 13 个 RPM Dockerfile（可并行）
3. Task 3 — 创建 2 个 DEB Dockerfile（可并行）
4. Task 4 — 改进 DEB 依赖解析（依赖 Task 3 完成）
5. Task 5 — 扩展 defaults.sh（独立）
6. Task 6 — 整合 pipeline（依赖 Task 1, 5）
7. Task 7 — 端到端测试（依赖所有）
