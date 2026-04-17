# KubeXM 命令调用链总览

日期：2026-03-22

目的：从 `bin/kubexm` 出发，给出各命令的调用链与参数传递路径，便于审计与维护。

## 1. 调用链总览

格式：`bin/kubexm` → `pipeline::*` → `module::*` → `task::*`

| CLI 命令 | 调用链 |
| --- | --- |
| `kubexm download` | `bin/kubexm` → `pipeline::download` → `module::download_prepare` → `task::download_resources` |
| `kubexm create cluster` | `bin/kubexm` → `pipeline::create_cluster` → `module::cluster_create` → `task::system_check` + `task::cluster_create` |
| `kubexm create registry` | `bin/kubexm` → `pipeline::create_registry` → `module::create_registry_prepare` → `task::create_registry` |
| `kubexm create manifests` | `bin/kubexm` → `pipeline::manifests` → `module::manifests_prepare` → `task::manifests` |
| `kubexm create iso` | `bin/kubexm` → `pipeline::iso` → `module::iso_prepare` → `task::iso_build` |
| `kubexm delete cluster` | `bin/kubexm` → `pipeline::delete_cluster` → `module::delete_cluster_prepare` → `task::delete_cluster` |
| `kubexm delete registry` | `bin/kubexm` → `pipeline::delete_registry` → `module::delete_registry_prepare` → `task::delete_registry` |
| `kubexm push images` | `bin/kubexm` → `pipeline::push_images` → `module::push_images_prepare` → `task::push_images` |
| `kubexm scale cluster` | `bin/kubexm` → `pipeline::scale_cluster` → `module::scale_cluster_prepare` → `task::scale_cluster` |
| `kubexm upgrade cluster` | `bin/kubexm` → `pipeline::upgrade_cluster` → `module::upgrade_cluster_prepare` → `task::upgrade_cluster` |
| `kubexm upgrade etcd` | `bin/kubexm` → `pipeline::upgrade_etcd` → `module::upgrade_etcd_prepare` → `task::upgrade_etcd` |
| `kubexm renew kubernetes-ca` | `bin/kubexm` → `pipeline::renew_kubernetes_ca` → `module::renew_kubernetes_ca_prepare` → `task::renew_kubernetes_ca` |
| `kubexm renew etcd-ca` | `bin/kubexm` → `pipeline::renew_etcd_ca` → `module::renew_etcd_ca_prepare` → `task::renew_etcd_ca` |
| `kubexm renew kubernetes-certs` | `bin/kubexm` → `pipeline::renew_kubernetes_certs` → `module::renew_kubernetes_certs_prepare` → `task::renew_kubernetes_certs` |
| `kubexm renew etcd-certs` | `bin/kubexm` → `pipeline::renew_etcd_certs` → `module::renew_etcd_certs_prepare` → `task::renew_etcd_certs` |

## 2. create cluster 完整调用链

### 2.1 Pipeline 层
```
pipeline::create_cluster
├── parser::load_config
├── mode == "online"
│   ├── pipeline::download "$@" (自动下载)
│   └── export KUBEXM_SKIP_DOWNLOAD="true"
├── mode == "offline" && registry_enabled == "true"
│   ├── pipeline::create_registry "$@"
│   └── pipeline::push_images "$@" --packages
└── module::cluster_create "$@"
```

### 2.2 Module 层
```
module::cluster_create
├── task::system_check "$@"
│   └── task::run_steps
│       ├── check.tools_binary
│       ├── check.tools_packages
│       └── check.os
└── task::cluster_create "$@"
    ├── parser::load_config
    ├── parser::load_hosts
    ├── step::register (260+ 步骤)
    └── task::run_steps (根据配置动态组装)
```

### 2.3 Task 层 - task::cluster_create 执行流程

```
task::cluster_create
│
├── [基础步骤] cluster.validate → cluster.distribute_tools
│
├── [配置目录] cluster.config_dirs_*
│   ├── cluster.config_dirs_collect
│   ├── cluster.config_dirs_cluster_root
│   ├── cluster.config_dirs_runtime_containerd/docker/crio
│   ├── cluster.config_dirs_certs
│   ├── cluster.config_dirs_cni_calico/flannel/cilium
│   └── cluster.config_dirs_addon_*
│
├── [渲染配置] cluster.render_* (收集并渲染各种配置)
│   ├── cluster.render_runtime_collect → render_runtime_containerd/docker/crio
│   ├── cluster.render_cni_collect → render_cni_calico/flannel/cilium
│   └── cluster.render_addon_collect → render_addon_metrics_server/ingress
│
├── [时间同步] cluster.chrony_*
│
├── [节点证书] cluster.node_certs_*
│
├── [Runtime 安装] (根据 runtime_type 动态选择)
│   ├── containerd: cluster.install_runtime_containerd_*
│   ├── docker: cluster.install_runtime_docker_*
│   └── crio: cluster.install_runtime_crio_*
│
├── [CNI 安装] cluster.install_cni_*
│
├── [K8s 二进制分发] (根据 kubernetes_type 动态选择)
│   ├── kubeadm: kubernetes.distribute_binaries_kubeadm_*
│   └── kubexm: kubernetes.distribute_binaries_kubexm_*
│
├── [Etcd 安装] (根据 etcd_type 动态选择)
│   ├── kubeadm: kubeadm.init_master + kubeadm.init_external_etcd
│   ├── kubexm: etcd.render_config → etcd.* (完整etcd安装流程)
│   └── exists: 跳过
│
├── [Kubeadm 初始化] (k8s_type == kubeadm)
│   ├── kubeadm.init_master (stacked etcd)
│   ├── kubeadm.init_external_etcd (external etcd)
│   ├── kubeadm.fetch_kubeconfig
│   ├── kubeadm.join_master_* (其他master加入)
│   └── kubeadm.join_worker_* (worker加入)
│
├── [Kubexm 二进制部署] (k8s_type == kubexm)
│   ├── kubernetes.generate_kubeconfig_*
│   ├── kubernetes.distribute_pki_k8s_*
│   ├── kubernetes.apiserver_* (API Server 部署)
│   ├── kubernetes.controller_manager_*
│   ├── kubernetes.scheduler_*
│   ├── kubernetes.kubelet_* (Kubelet 部署)
│   ├── kubernetes.kube_proxy_* (Kube-Proxy 部署)
│   └── kubernetes.wait_* (等待组件就绪)
│
├── [LoadBalancer 安装] (lb_enabled == true, 根据 lb_mode/lb_type 动态选择)
│   │
│   ├── [internal 模式] - 所有worker部署LB代理到master
│   │   ├── kubeadm + haproxy: lb.internal.haproxy_static_* (static pod)
│   │   ├── kubeadm + nginx: lb.internal.nginx_static_* (static pod)
│   │   ├── kubexm + haproxy: lb.internal.haproxy_systemd_* (binary)
│   │   └── kubexm + nginx: lb.internal.nginx_systemd_* (binary)
│   │
│   ├── [external 模式] - LB角色机器部署
│   │   ├── kubexm-kh: lb.external.kubexm_kh_* (keepalived + haproxy)
│   │   └── kubexm-kn: lb.external.kubexm_kn_* (keepalived + nginx)
│   │
│   ├── [kube-vip 模式] - lb.kube_vip_* (static pod + daemonset)
│   │
│   └── [exists 模式] - lb.exists (跳过部署)
│
├── [CNI 插件安装] (根据 network_plugin 动态选择)
│   ├── cluster.install_cni_calico
│   ├── cluster.install_cni_flannel
│   └── cluster.install_cni_cilium
│
└── [Addon 安装] cluster.install_addon_*
    ├── cluster.install_addon_metrics_server
    ├── cluster.install_addon_ingress
    ├── cluster.setup_cert_auto_renew
    └── cluster.etcd_auto_backup_*
```

## 3. 部署配置矩阵决策点

### 3.1 Kubernetes 类型决策
```bash
k8s_type=$(config::get_kubernetes_type)
# 来自: config.yaml spec.kubernetes.type
# 取值: kubeadm | kubexm
```

### 3.2 Etcd 类型决策
```bash
etcd_type=$(config::get_etcd_type)
# 来自: config.yaml spec.etcd.type
# 取值: kubeadm | kubexm | exists
```

### 3.3 LoadBalancer 决策树
```bash
lb_enabled=$(config::get_loadbalancer_enabled)
lb_mode=$(config::get_loadbalancer_mode)
lb_type=$(config::get_loadbalancer_type)

if [[ "${lb_enabled}" != "true" ]]; then
    # 跳过LB安装
elif [[ "${lb_mode}" == "internal" ]]; then
    # 所有worker部署LB代理到master
    if [[ "${k8s_type}" == "kubeadm" && "${lb_type}" == "haproxy" ]]; then
        # static pod haproxy
    elif [[ "${k8s_type}" == "kubeadm" && "${lb_type}" == "nginx" ]]; then
        # static pod nginx
    elif [[ "${k8s_type}" == "kubexm" && "${lb_type}" == "haproxy" ]]; then
        # binary haproxy
    elif [[ "${k8s_type}" == "kubexm" && "${lb_type}" == "nginx" ]]; then
        # binary nginx
    fi
elif [[ "${lb_mode}" == "external" ]]; then
    # LB角色机器部署
    if [[ "${lb_type}" == "kubexm-kh" ]]; then
        # keepalived + haproxy
    elif [[ "${lb_type}" == "kubexm-kn" ]]; then
        # keepalived + nginx
    fi
elif [[ "${lb_mode}" == "kube-vip" ]]; then
    # kube-vip
elif [[ "${lb_mode}" == "exists" ]]; then
    # 跳过部署
fi
```

## 4. 参数传递路径

统一规则：`bin/kubexm` 解析命令后，将剩余参数原样传递给 `pipeline`，再由 `module` 转发到 `task`。任务内自行解析所需参数并写入上下文或环境变量。

### CLI 参数
| 参数 | 传播路径 | 说明 |
| --- | --- | --- |
| `--cluster=NAME` | CLI → pipeline → module → task | 设置 `KUBEXM_CLUSTER_NAME` 与配置文件路径 |
| `--kubernetes-version=VER` | CLI → pipeline → module → task | download 任务使用 |
| `--container-runtime=RT` | CLI → pipeline → module → task | download 任务使用 |
| `--cni=PLUGIN` | CLI → pipeline → module → task | download 任务使用 |
| `--with-build-*` | CLI → pipeline → module → task | ISO 构建参数 |
| `--to-version=*` | CLI → pipeline → module → task | upgrade 任务使用 |
| `--packages` | CLI → pipeline → module → task | push images 使用 |
| `--parallel=N` | CLI → pipeline → module → task | push images 并发控制 |

### 环境变量
| 变量 | 用途 |
| --- | --- |
| `KUBEXM_ROOT` | 项目根目录 |
| `KUBEXM_CLUSTER_NAME` | 集群名称 |
| `KUBEXM_CONFIG_FILE` | 配置文件路径 |
| `KUBEXM_HOST_FILE` | 主机清单路径 |
| `KUBEXM_DRY_RUN` | 干跑模式 |
| `KUBEXM_HOST` | 当前目标主机 |
| `KUBEXM_STEP_NAME` | 当前步骤名 |
| `KUBEXM_PIPELINE_NAME` | 当前管道名 |
| `KUBEXM_RUN_ID` | 运行ID |

## 5. Step 执行接口

每个 Step 必须实现以下函数：
```bash
step::<name>::check    # 幂等性检查，返回0表示已满足，跳过run
step::<name>::run     # 执行步骤
step::<name>::rollback # 回滚逻辑
step::<name>::targets  # 返回目标主机列表
```

### Runner 执行流程
```
runner::exec <step_name> <ctx> <host>
├── runner::normalize_host (禁止localhost/127.0.0.1)
├── KUBEXM_DRY_RUN 检查
├── step::${step_name}::check (幂等检查)
│   └── 返回0 → 跳过run，直接返回
└── step::${step_name}::run (执行)
    ├── runner::remote_exec / runner::remote_copy_file
    │   └── connector::exec / connector::copy_file
    │       └── ssh::execute / ssh::copy_file
    └── step::${step_name}::check (验证)
```

## 6. 在线/离线模式

### 离线模式
```
1. kubexm download --cluster=mycluster (联网环境)
   └── 下载所有资源到 ${KUBEXM_ROOT}/packages/

2. 打包 packages/ 目录

3. 复制到离线环境

4. kubexm create cluster --cluster=mycluster (离线环境)
   └── 直接使用 packages/ 中的资源
```

### 在线模式
```
kubexm create cluster --cluster=mycluster
├── mode == "online"
│   ├── pipeline::download "$@" (自动下载)
│   └── module::cluster_create "$@"
└── mode == "offline"
    └── module::cluster_create "$@"
        └── registry_enabled == "true"
            ├── pipeline::create_registry "$@"
            └── pipeline::push_images "$@" --packages
```

### 关键约束
- `download` 仅依赖 `config.yaml`，不读取/校验 `host.yaml`
- `loadbalancer.mode=internal` 时，worker 节点 kubelet 连接本地 LB 代理 (`127.0.0.1:6443`)
- `host.yaml` 禁止 `localhost` 或 `127.0.0.1`，本机也用大网地址 SSH

## 7. 目录结构

```
kubexm-script/
├── bin/
│   ├── kubexm              # CLI 入口
│   ├── xmjq                # jq 封装工具
│   ├── xmparser            # 解析器工具
│   ├── xmrender            # 渲染器工具
│   └── xmyq                # yq 封装工具
├── internal/
│   ├── pipeline/           # Pipeline 层 (命令路由)
│   │   ├── create_cluster.sh
│   │   ├── download.sh
│   │   ├── push_images.sh
│   │   └── ...
│   ├── module/            # Module 层 (功能组装)
│   │   ├── cluster_create.sh
│   │   ├── download.sh
│   │   └── ...
│   ├── task/              # Task 层 (任务编排)
│   │   ├── cluster_create.sh
│   │   ├── download.sh
│   │   ├── step_runner.sh
│   │   └── ...
│   ├── step/
│   │   ├── registry.sh    # Step 注册表
│   │   └── steps/         # 原子步骤 (260+)
│   │       ├── cluster_validate.sh
│   │       ├── etcd_render_config.sh
│   │       └── ...
│   ├── runner/            # Runner 层 (执行引擎)
│   │   └── runner.sh
│   ├── connector/         # Connector 层 (SSH封装)
│   │   ├── connector.sh
│   │   └── ssh.sh
│   ├── config/            # 配置解析
│   │   ├── config.sh
│   │   ├── loader.sh
│   │   ├── getters/
│   │   │   ├── kubernetes.sh
│   │   │   ├── etcd.sh
│   │   │   └── loadbalancer.sh
│   │   └── domain/
│   │       ├── domain.sh
│   │       ├── enums.sh
│   │       ├── normalize.sh
│   │       └── rules/strategy_rules.sh
│   ├── logger/            # 日志系统
│   │   └── logger.sh
│   ├── context/           # 上下文管理
│   │   └── context.sh
│   ├── errors/            # 异常处理
│   │   └── errors.sh
│   ├── parser/            # 解析器
│   │   └── parser.sh
│   └── loader.sh          # 加载器
├── conf/
│   └── clusters/
│       └── <cluster_name>/
│           ├── config.yaml   # 集群配置
│           └── host.yaml     # 主机清单
├── templates/            # 配置模板
├── docs/                 # 文档
└── tests/                # 测试用例
