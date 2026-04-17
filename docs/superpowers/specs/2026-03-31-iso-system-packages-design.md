# System Packages ISO 构建系统增强设计

## 1. 概述

**目标：** 增强 kubexm-script 的 System Packages ISO 构建能力，支持更多操作系统（26 个 OS），完善 DEB 系依赖解析，实现 Host/Docker 双执行模式。

**范围：**
- 依赖收集（Dependency Resolve）
- 仓库构建（Repo Build）
- ISO 打包（ISO Package）

**不在范围内：**
- 全量 Kubernetes 安装 ISO（带 boot/kernel/initrd）
- 离线镜像打包（已有 `kubexm push images` 处理）

## 2. 整体架构

```
Config (config.yaml)
  ├── spec.iso.build.os_list: [...]
  ├── spec.iso.build.arch_list: [...]
  ├── spec.iso.build.mode: docker | host
  ├── spec.loadbalancer.*
  ├── spec.storage_addon: nfs-subdir | longhorn | ...
  └── spec.network.cni: calico | cilium | flannel

Task: task::infra::iso_build
  ├── Step: iso.check.deps           (检查 mkisofs/genisoimage/xorriso, Docker)
  ├── Step: deps.resolve              (读取 config → 组合包清单)
  ├── Step: packages.download         (Host/Docker 双模式)
  ├── Step: repo.build               (createrepo / dpkg-scanpackages)
  └── Step: iso.package              (mkisofs / genisoimage / xorriso)
```

### 调用链

- Pipeline → Module → Task → Step → Runner → Connector
- Task 只编排 Step，不跨层调用

## 3. OS 支持矩阵

### 3.1 RPM 系（20 个 OS）

| OS | 基础镜像 | 包管理器 |
|----|---------|---------|
| centos7 | centos:7 | yum |
| centos8 | quay.io/centos/centos:stream8 | dnf |
| rocky8 | rockylinux/rockylinux:8 | dnf |
| rocky9 | rockylinux/rockylinux:9 | dnf |
| almalinux8 | almalinux:8 | dnf |
| almalinux9 | almalinux:9 | dnf |
| kylin10 | 待定 | dnf |
| openeuler22 | openeuler/openeuler:22.03-lts | dnf |
| uos20 | 待定 | dnf |
| rhel7 | registry.access.redhat.com/rhel7 | yum |
| rhel8 | registry.access.redhat.com/rhel8 | dnf |
| rhel9 | registry.access.redhat.com/rhel9 | dnf |
| ol8 | oraclelinux:8 | dnf |
| ol9 | oraclelinux:9 | dnf |
| anolis8 | openanolis/anolisos:8 | dnf |
| anolis9 | openanolis/anolisos:9 | dnf |
| fedora39 | fedora:39 | dnf |
| fedora40 | fedora:40 | dnf |
| fedora41 | fedora:41 | dnf |
| fedora42 | fedora:42 | dnf |

### 3.2 DEB 系（6 个 OS）

| OS | 基础镜像 | 包管理器 |
|----|---------|---------|
| ubuntu20 | ubuntu:20.04 | apt |
| ubuntu22 | ubuntu:22.04 | apt |
| ubuntu24 | ubuntu:24.04 | apt |
| debian10 | debian:10 | apt |
| debian11 | debian:11 | apt |
| debian12 | debian:12 | apt |

## 4. 包清单设计

### 4.1 静态基础包（defaults.sh）

```bash
# 基础包（所有 OS 都需要）
KUBEXM_ISO_PKG_BASE=(
    curl wget tar gzip xz
    conntrack ethtool socat ebtables ipset ipvsadm
    iproute bash-completion openssl jq
)

# 按负载均衡类型
KUBEXM_ISO_PKG_HAPROXY=(haproxy)
KUBEXM_ISO_PKG_NGINX=(nginx)
KUBEXM_ISO_PKG_KEEPALIVED=(keepalived)

# 按存储 addon
KUBEXM_ISO_PKG_NFS=(nfs-utils nfs-client)
KUBEXM_ISO_PKG_ISCSI=(iscsi-initiator-utils lsscsi)

# 按 CNI
KUBEXM_ISO_PKG_CILIUM=(iproute mount targetcli)
KUBEXM_ISO_PKG_CALICO=(iproute)
KUBEXM_ISO_PKG_FLANNEL=(iproute)
```

### 4.2 Task 层智能推断

`task::infra::iso_build` 读取 config.yaml，推断需要哪些包：

```bash
iso_build::resolve_packages() {
    local pkgs=("${KUBEXM_ISO_PKG_BASE[@]}")

    # LB 推断
    [[ "${LB_TYPE}" == "haproxy" ]]     && pkgs+=("${KUBEXM_ISO_PKG_HAPROXY[@]}")
    [[ "${LB_TYPE}" == "nginx" ]]        && pkgs+=("${KUBEXM_ISO_PKG_NGINX[@]}")
    [[ "${LB_TYPE}" == kubexm_* ]]       && pkgs+=("${KUBEXM_ISO_PKG_KEEPALIVED[@]}")

    # Storage addon 推断
    [[ "${STORAGE_ADDON}" == "nfs-subdir-external"* ]] && pkgs+=("${KUBEXM_ISO_PKG_NFS[@]}")
    [[ "${STORAGE_ADDON}" == "longhorn" ]]  && pkgs+=("${KUBEXM_ISO_PKG_NFS[@]}" "${KUBEXM_ISO_PKG_ISCSI[@]}")

    # CNI 推断
    [[ "${CNI}" == "cilium" ]]  && pkgs+=("${KUBEXM_ISO_PKG_CILIUM[@]}")
    [[ "${CNI}" == "calico" ]]  && pkgs+=("${KUBEXM_ISO_PKG_CALICO[@]}")
    [[ "${CNI}" == "flannel" ]] && pkgs+=("${KUBEXM_ISO_PKG_FLANNEL[@]}")

    echo "${pkgs[@]}"
}
```

**关键原则：** Kubernetes 组件（kubelet/kubeadm/kubectl/kube-apiserver 等）和容器运行时（containerd/docker/crio）不走包管理器，全部使用离线二进制。

## 5. 依赖解析策略

### 5.1 RPM 系

使用 `dnf download --resolve` 或 `yumdownloader --resolve`，自动处理所有传递依赖。

```bash
dnf download --resolve --alldeps \
    --destdir /output/packages/ \
    --releasever=${OS_VERSION} \
    "${packages[@]}"
```

### 5.2 DEB 系

apt-get download 不自动处理依赖，需递归展开依赖树：

```bash
resolve_deps() {
    local pkg="$1"
    local visited="${2:-}"

    [[ " ${visited} " == *" ${pkg} "* ]] && return
    visited="${visited} ${pkg}"

    local deps=$(apt-cache depends --recurse --no-recommends \
        "${pkg}" 2>/dev/null | grep "^Depends:" | awk '{print $2}' | sed 's/<.*>//g')

    for dep in ${deps}; do
        resolve_deps "$dep" "$visited"
    done
    echo "$pkg"
}

all_deps=$(for pkg in "${packages[@]}"; do resolve_deps "$pkg"; done | sort -u)
installed=$(dpkg-query -W -f='${Package}\n' 2>/dev/null)
to_download=$(comm -23 <(echo "$all_deps") <(echo "$installed"))

for pkg in $to_download; do
    apt-get download "$pkg" -o Dir::Cache::Archives=/output/packages/
done
```

## 6. 执行模式

| 模式 | 触发条件 | 适用场景 |
|------|----------|----------|
| `host` | `--with-build-local` | 机器当前 OS = 目标 OS = 目标 arch |
| `docker` | 默认 | 跨 OS / 跨 arch 构建 |

Host 模式流程：

```
检测当前 OS → 检测当前 arch → dnf/yum/apt 下载 → createrepo/dpkg → mkisofs → ISO
```

Docker 模式流程：

```
为每个目标 OS 构建 builder 镜像 → 容器内下载依赖 → 构建 repo → 生成 ISO
```

## 7. 输出结构

每个 OS/arch 生成独立 ISO：

```
${KUBEXM_ROOT}/packages/iso/
├── centos7/
│   ├── amd64/
│   │   ├── packages/*.rpm
│   │   ├── repo/kubexm.repo
│   │   └── centos7-amd64.iso
│   └── arm64/centos7-arm64.iso
├── ubuntu22/
│   ├── amd64/
│   │   ├── packages/*.deb
│   │   ├── repo/kubexm.list
│   │   └── ubuntu22-amd64.iso
│   └── arm64/ubuntu22-arm64.iso
├── rocky9/amd64/rocky9-amd64.iso
├── debian12/amd64/debian12-amd64.iso
```

## 8. Docker Builder

### 8.1 Dockerfile 目录

`containers/` 目录下每个 OS 一个 Dockerfile：

```
containers/
├── Dockerfile.centos7
├── Dockerfile.rocky9
├── Dockerfile.almalinux9
├── Dockerfile.ubuntu22
├── Dockerfile.ubuntu24
├── Dockerfile.debian12
├── Dockerfile.rhel9
├── Dockerfile.ol9
├── Dockerfile.anolis9
├── Dockerfile.fedora42
├── Dockerfile.openeuler22
├── Dockerfile.uos20
├── Dockerfile.kylin10
└── scripts/
    ├── build-rpm.sh      (RPM 系通用)
    └── build-deb.sh      (DEB 系通用)
```

### 8.2 RPM Dockerfile 示例

```dockerfile
FROM rockylinux:9
RUN dnf install -y dnf-plugins-core createrepo_c && dnf clean all
COPY containers/scripts/build-rpm.sh /build-rpm.sh
ENTRYPOINT ["/build-rpm.sh"]
```

### 8.3 DEB Dockerfile 示例

```dockerfile
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y \
    apt-utils dpkg-dev apt-rdepends ca-certificates gnupg && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
COPY containers/scripts/build-deb.sh /build-deb.sh
ENTRYPOINT ["/build-deb.sh"]
```

## 9. 离线使用

ISO 制作完成后，在目标机器上使用：

### 9.1 RPM 系

```bash
mount /path/to/rocky9-amd64.iso /mnt -o loop
cat > /etc/yum.repos.d/kubexm-offline.repo <<EOF
[kubexm-offline]
name=KubeXM Offline Repository
baseurl=file:///mnt
enabled=1
gpgcheck=0
EOF
yum install -y haproxy keepalived ...
```

### 9.2 DEB 系

```bash
mount /path/to/ubuntu22-amd64.iso /mnt -o loop
echo "deb [trusted=yes] file:/mnt ./" > /etc/apt/sources.list.d/kubexm-offline.list
apt-get update
apt-get install -y haproxy keepalived ...
```

## 10. 校验机制

| 校验点 | 方法 |
|--------|------|
| 包完整性 | SHA256 checksum，每包校验 |
| Repo 可用性 | `createrepo --check` / `dpkg -O` 验证索引 |
| ISO 可用性 | `xorriso -indev ${iso} -check_media` |
| 安装测试（可选） | ISO mount 后 `rpm -q --test *.rpm` / `dpkg --dry-run *.deb` |

## 11. 实现任务

### Phase 1: 基础设施增强
1. 修正 `build_docker.sh` 中的 OS 列表（uos20 从 apt 改为 dnf）
2. 新增缺失 OS 的 Dockerfile（rhel/ol/anolis/fedora/ubuntu24/debian10）
3. 增强 `build-rpm.sh` 和 `build-deb.sh` 脚本（支持多架构、错误处理）
4. 新增 DEB 系依赖解析脚本（apt-rdepends 方案）

### Phase 2: 包清单与推断
5. 扩展 `defaults.sh` 增加 ISO 专用包常量
6. 新增 `task::infra::iso_build` 中的智能推断逻辑
7. 新增 Step `deps.resolve`（`step/iso/iso_resolve_deps.sh`）

### Phase 3: 流水线整合
8. 更新 `step/iso/iso_build_system_packages.sh` 支持 per-OS ISO 输出
9. 更新 `system_iso.sh` 支持新 OS 列表
10. 增强 `task::infra::iso_build/main.sh` 支持 --with-build-os/--with-build-arch 多值参数
11. 集成 checkpoint 机制（断点续传）

### Phase 4: 验证
12. 端到端测试（至少覆盖 rocky9/amd64 和 ubuntu22/amd64）
13. 跨架构测试（amd64 机器构建 arm64 ISO via QEMU）
14. 离线安装测试（挂载 ISO → 安装包 → 验证）

## 12. 已知约束

- RHEL 官方镜像需要 Red Hat 订阅才能 `dnf update`
- 部分国产 OS（kylin10, uos20）需要确认基础镜像来源
- apt-rdepends 对大型依赖树可能较慢，需优化或限制递归深度
- Docker Buildx 多架构构建需要在构建机器上配置 QEMU
