# KubeXM Directory Restucturing Design

> **Date**: 2026-03-25
> **Status**: Draft

## 1. Overview

Restructure `internal/step/` directory to be cleaner and more intuitive.

## 2. Step Directory Structure

```
internal/step/
├── addons/           # Addon 安装/删除（ingress/metrics-server/dashboard/coredns）
├── certs/            # 证书相关（CA/leaf certs）
├── cluster/          # 集群操作（drain/cleanup/reset/kubeadm/节点操作）
├── common/           # 公共辅助函数（原 lib/）
│   ├── checks.sh     # 幂等性检查 helper
│   └── targets.sh    # 目标主机选择 helper
├── cni/              # CNI 步骤入口（calico/flannel/cilium）
│   ├── calico/
│   ├── flannel/
│   └── cilium/
├── deployment/       # Kubernetes 组件部署模板（static pod manifests 等）
├── download/         # 下载步骤（packages/images）
├── etcd/             # etcd 安装/配置
├── images/           # 镜像推送
├── iso/              # ISO 制作步骤（见 Section 5）
├── kubeadm/          # kubeadm init/join/reset 操作
├── kubernetes/       # K8s 组件二进制（分发到节点）
│   ├── apiserver/   # kube-apiserver
│   ├── scheduler/    # kube-scheduler
│   ├── controller-manager/  # kube-controller-manager
│   ├── kubelet/     # kubelet
│   └── kube-proxy/   # kube-proxy
├── loadbalancer/     # LB 步骤（统一入口）
│   ├── common/       # keepalived（VIP 故障转移，HAProxy/Nginx 共用）
│   ├── haproxy/
│   ├── nginx/
│   └── kube-vip/
├── manifests/        # 清单生成（依赖清单/镜像清单）
├── os/              # OS 配置（hosts/swap/firewall/timezone）
├── registry/        # Registry 操作（create/delete/push）
├── runtime/         # 容器运行时（containerd/docker）
└── security/        # 安全相关（kubeconfig/cert-rotation）
```

### 2.1 Directory Roles

| 目录 | 职责 | 与其他目录关系 |
|------|------|---------------|
| `kubeadm/` | kubeadm 命令执行（init/join/reset） | 调用 `kubernetes/` 中的组件 |
| `kubernetes/` | 组件二进制分发 | 被 kubeadm/cluster 调用 |
| `cluster/` | 节点级别操作 | 使用 kubeadm/registry/runtime |
| `deployment/` | Static pod manifests 等模板 | 被 cluster/kubernetes 调用 |

### 2.2 Key Changes

| 原目录 | 新目录 | 说明 |
|--------|--------|------|
| `lib/` | `common/` | 公共辅助函数 |
| `lb/` | `loadbalancer/` | 重命名更清晰 |
| `loadbalancer/` | `loadbalancer/haproxy` 等 | 按实现分 |
| `kube_vip/` | `loadbalancer/kube-vip/` | 移入 loadbalancer 下 |
| `kubernetes/` (flat) | `kubernetes/{component}/` | 按组件分目录 |
| `cni/` (flat) | `cni/{plugin}/` | 按插件分目录 |

## 3. Download Output Paths

### 3.1 Arch 命名规范

使用 Go/Kubernetes 社区标准：
- `amd64` = x86_64
- `arm64` = aarch64

### 3.2 Path Format

| 类型 | 路径格式 |
|------|----------|
| Kubernetes 组件 | `${packages}/${component}/${version}/${arch}/${binary}` |
| ISO | `${packages}/iso/${os_name}/${os_version}/${arch}/${os_name}-${os_version}-${arch}.iso` |

### 3.3 Examples

```
packages/
├── kubelet/
│   └── v1.24.9/
│       ├── amd64/kubelet
│       └── arm64/kubelet
├── kube-apiserver/
│   └── v1.24.9/
│       └── amd64/kube-apiserver
├── containerd/
│   └── 1.7.0/
│       └── amd64/containerd
├── kube-proxy/
│   └── v1.24.9/
│       ├── amd64/kube-proxy
│       └── arm64/kube-proxy
└── iso/
    ├── centos7/
    │   └── 7.9/
    │       └── amd64/
    │           └── centos7-7.9-amd64.iso
    ├── ubuntu22/
    │   └── 22.04/
    │       └── amd64/
    │           └── ubuntu22-22.04-amd64.iso
```

## 4. Installation Distribution Logic

### 4.1 host.yaml arch 字段

```yaml
hosts:
  - name: node1
    address: 192.168.1.10
    arch: amd64    # 可选，默认 amd64
  - name: node2
    address: 192.168.1.11
    # 未配置 arch，默认 amd64
```

### 4.2 Binary 分发逻辑

1. 读取 `host.yaml` 中目标机器的 `arch` 字段
2. 未配置默认为 `amd64`
3. 从 `${packages}/${component}/${version}/${arch}/${binary}` 选取对应架构的 binary
4. 分发到目标机器

## 5. ISO Build Design

> **Note**: ISO 构建功能详细设计将单独成文，此处仅记录目录位置和输出路径。

### 5.1 ISO 内容

离线系统包 ISO，包含：
- 操作系统基础包（yum/apt）
- Kubernetes 依赖包（conntrack/iptables 等）
- LB 组件（haproxy/nginx/keepalived）

### 5.2 ISO 构建模式

| 模式 | 说明 | 约束 |
|------|------|------|
| 本地模式 | 使用宿主机环境制作 | 只能制作与宿主机相同 OS/架构 |
| 容器模式 | 使用 Docker 容器制作 | 可制作任意 OS/架构 组合 |

### 5.3 Output Naming

```
${os_name}-${os_version}-${arch}.iso
```

Examples:
- `centos7-7.9-amd64.iso`
- `ubuntu22-22.04-amd64.iso`

## 6. Migration Plan

### Phase 1: 准备
1. 确认所有文件的当前路径（`git ls-files internal/step/`）
2. 创建新目录结构

### Phase 2: 文件迁移（保留 git history）
```bash
# 示例：迁移 lib/ -> common/
git mv internal/step/lib internal/step/common

# 迁移 kubernetes/ flat -> kubernetes/{component}/
mkdir -p internal/step/kubernetes/{apiserver,scheduler,controller-manager,kubelet,kube-proxy}
git mv internal/step/kubernetes/kubelet.sh internal/step/kubernetes/kubelet/
# ... 其他组件同理
```

### Phase 3: 更新引用
1. 搜索旧路径引用：
   ```bash
   grep -r "internal/step/lib" internal/
   grep -r "internal/step/lb" internal/
   grep -r "internal/step/kubernetes" internal/
   ```
2. 更新所有 `source` 和 `require` 语句

### Phase 4: 验证
1. 运行测试：`bash tests/run-tests.sh`
2. 验证 CLI：`bin/kubexm --help`
3. 手动抽查关键命令

### Phase 5: Rollback
如遇问题，恢复：
```bash
git reset --hard <migration-commit>
git clean -fd
```

## 7. Backward Compatibility

- External interfaces (CLI commands) unchanged
- Config file formats unchanged
- Only internal directory structure changes