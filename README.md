# KubeXM - Kubernetes集群部署和管理工具

一个功能完整的Kubernetes集群部署和管理工具，支持离线下载、创建集群、删除集群。

## 项目概述

KubeXM是一个全新的Kubernetes集群部署工具，采用模块化架构设计，支持离线下载、单节点集群创建和配置文件集群部署。

## 核心特性

### ✅ 已实现功能

1. **离线资源下载**
   - 下载Kubernetes二进制文件
   - 下载容器镜像
   - 下载操作系统包依赖
   - 下载Helm Charts
   - 生成资源清单（BOM）

2. **单节点集群创建**
   - 支持指定Kubernetes版本
   - 支持指定容器运行时（docker、containerd）
   - 自动系统优化和依赖安装
   - 自动安装CNI插件

3. **配置文件集群**
   - 支持YAML格式配置文件
   - 支持多节点集群部署

4. **包管理工具**
   - OS BOM（操作系统依赖包管理）
   - Binary BOM（二进制文件管理）
   - Image BOM（镜像管理）
   - Helm BOM（Helm包管理）

5. **系统优化**
   - 28项sysctl参数配置
   - 支持大规模集群（600节点）
   - 内核模块加载

## 目录结构

```
kubexm-script/
├── bin/
│   ├── kubexm                # CLI 入口
│   └── xmyq/xmjq/xmparser/...# 工具二进制
├── internal/
│   ├── pipeline/             # 全流程编排
│   ├── module/               # 模块封装
│   ├── task/                 # 任务组装
│   ├── step/                 # 原子步骤库
│   ├── runner/               # 执行引擎
│   ├── connector/            # SSH 连接封装
│   ├── config/               # 配置解析/校验
│   ├── parser/               # 解析入口
│   ├── logger/               # 日志系统
│   ├── context/              # 上下文管理
│   ├── errors/               # 错误处理
│   ├── cache/                # 缓存管理
│   └── utils/                # 通用工具集
├── conf/                     # 集群配置 (config.yaml/host.yaml)
├── packages/                 # 离线资源目录
├── templates/                # 模板中心
├── containers/               # OS 离线依赖容器构建
├── docs/                     # 设计/审计文档
└── tests/                    # 测试用例
```

## 快速开始

### 1. 下载集群资源（离线准备）

```bash
# 下载指定集群的所有资源（只需要 config.yaml，不需要 host.yaml）
./bin/kubexm download --cluster=mycluster

# 下载指定版本和运行时的资源
./bin/kubexm download --cluster=mycluster --kubernetes-version=v1.27.2 --container-runtime=docker

# 下载指定CNI的资源
./bin/kubexm download --cluster=mycluster --cni=cilium
```

### 2. 创建集群（离线/在线）

```bash
# 离线模式：先 download，拷贝 packages 到离线环境，再创建
./bin/kubexm download --cluster=mycluster
./bin/kubexm create cluster --cluster=mycluster

# 说明：若 config.yaml 中启用 registry (spec.registry.enable=true)，
# create cluster 将自动部署 registry 并从 packages 推送镜像
# 推送镜像使用 packages/images/images.list 作为清单

# 在线模式：create cluster 会自动执行 download + create
./bin/kubexm create cluster --cluster=mycluster
```

### 3. 删除集群

```bash
# 删除指定集群
./bin/kubexm delete cluster --cluster=mycluster

# 强制删除（不提示确认）
./bin/kubexm delete cluster --cluster=mycluster -f
```

## 支持的功能

### 容器运行时
- ✅ Docker
- ✅ containerd
- ✅ cri-o
- ✅ Podman

### CNI插件
- ✅ Calico v3.27.0
- ✅ Flannel v0.25.5
- ✅ Cilium v1.15.3
- ✅ Kube-OVN
- ✅ Hybridnet

### 操作系统
- ✅ CentOS 7/8/9
- ✅ Ubuntu 18.04/20.04/22.04
- ✅ Debian 10/11
- ✅ RHEL 8/9
- ✅ Rocky Linux 8/9
- ✅ AlmaLinux 8/9
- ✅ Oracle Linux 8
- ✅ Fedora 36/37/38
- ✅ UOS 20 Server
- ✅ Kylin V10 SP3

### 负载均衡器
- ✅ HAProxy + Keepalived
- ✅ Kube-VIP
- 🔄 Nginx + Keepalived

### 存储
- ✅ Local Path Provisioner
- ✅ NFS Subdir External Provisioner
- ✅ Longhorn
- ✅ OpenEBS

## OS BOM功能

OS BOM（操作系统依赖包管理）是KubeXM的核心特性之一，可以根据不同的操作系统和运行时类型，自动生成和安装所需的依赖包。

### 支持的操作系统

**RPM系：**
- CentOS 7/8/9
- RHEL 8/9
- Rocky Linux 8/9
- AlmaLinux 8/9
- Oracle Linux 8
- Fedora 36/37/38
- UOS 20 Server
- Kylin V10 SP3

**DEB系：**
- Ubuntu 18.04/20.04/22.04
- Debian 10/11

### 依赖包分类

1. **基础系统包**
   - curl, wget, jq, htop, vim, git等

2. **Kubernetes依赖**
   - conntrack-tools, ebtables, ethtool

3. **容器运行时依赖**
   - docker/containerd/crio/podman相关包

4. **网络插件依赖**
   - iproute2, iptables, socat

5. **负载均衡器依赖**
   - haproxy, keepalived, nginx

6. **存储依赖**
   - nfs-common, iscsi相关包

7. **时序同步**
   - chrony, ntp

8. **Helm依赖**
   - gpg, gnupg-agent

## 使用示例

### 示例1：下载并创建集群

```bash
# 1. 下载集群资源
./bin/kubexm download --cluster=mycluster

# 2. 创建单节点集群
./bin/kubexm create cluster --kubernetes-version=v1.27.2 --container-runtime=docker

# 3. 验证集群
kubectl get nodes
kubectl get pods -A
```

### 示例2：使用配置文件

```bash
# 1. 创建配置文件
mkdir -p conf/clusters/mycluster

# 2. 编辑config.yaml和host.yaml

# 3. 创建集群
./bin/kubexm create cluster --cluster=mycluster

# 4. 删除集群
./bin/kubexm delete cluster --cluster=mycluster
```

## BOM文件说明

下载的资源目录包含以下BOM文件：

- **binary-bom.txt** - 二进制文件清单
- **image-bom.txt** - 镜像清单
- **os-bom.txt** - 操作系统包清单
- **manifest.txt** - 总体资源清单

每个BOM文件包含详细的组件信息、版本和下载路径。

## 系统要求

- Linux操作系统（支持列表见上）
- root权限或sudo权限
- 至少2GB内存
- 至少20GB磁盘空间
- 网络连接（用于下载资源）

## 注意事项

1. 创建/删除集群需要root权限
2. 单节点集群默认安装Calico CNI
3. 下载的资源可用于离线部署
4. 配置文件模式尚未完全实现（TODO）

## 许可证

MIT License

## 支持的功能

### CNI插件
- ✅ Calico v3.27.0
- ✅ Flannel v0.25.5
- ✅ Cilium v1.15.3

### Addons
- ✅ Metrics Server v0.7.0
- ✅ Ingress NGINX Controller v1.8.2
- ✅ CoreDNS v1.11.1
- ✅ Local Path Provisioner v0.0.24
- ✅ NFS Subdir External Provisioner v4.0.2

### 负载均衡器
- ✅ HAProxy 2.8.5
- ✅ Keepalived 3.3.1
- ✅ Kube-VIP 0.8.0
- 🔄 Nginx (计划中)

### 操作系统支持
- ✅ CentOS 7/8
- ✅ Ubuntu 18.04/20.04/22.04
- ✅ Debian 10/11
- ✅ RHEL 8
- ✅ Rocky Linux 8/9
- ✅ AlmaLinux 8/9
- ✅ Oracle Linux 8
- ✅ Fedora 36/37/38
- ✅ openSUSE Leap 15

## 离线部署

```bash
# 构建离线镜像
./bin/kubexm create iso --with-build-os=rocky9 --with-build-arch=amd64

# 使用ISO安装（生成的ISO内包含安装脚本）
# 在目标环境挂载ISO后执行其中的 install.sh
```

## 配置验证

所有配置都经过严格验证：
- YAML格式验证
- 配置文件Schema验证
- 网络连通性检查
- 节点角色验证

## 架构设计

### 模块化架构
- 每个组件独立模块
- 清晰的职责分离
- 易于扩展和维护

### 模板系统
- 基于envsubst的模板引擎
- 支持变量替换
- 模板继承和组合

### 配置管理
- YAML配置格式
- 类型安全
- 配置验证

## 贡献指南

欢迎提交Issue和Pull Request！

## 许可证

MIT License

## 联系方式

如有问题，请提交Issue。
