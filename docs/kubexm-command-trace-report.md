# KubeXM 命令追踪报告

日期：2026-03-22

> 说明：本报告基于 `bin/kubexm` 的帮助与静态解析生成，包含命令调用链、参数矩阵与问题台账，并持续补齐证据。

## 0. 变更说明（重构后）

- 代码已完成架构重构，现以 `internal/pipeline` → `internal/module` → `internal/task` → `internal/step` 为主链路，执行由 `internal/runner` 与 `internal/connector` 负责。
- 历史版本中引用的 `lib/**`、`scripts/**`、`internal/step/legacy/**` 已被移除或废弃；本报告中若仍出现这些路径，作为历史证据保留，不代表当前实现。
- 最新命令调用链请以 `docs/kubexm-command-callchain.md` 为准。

## 目录

- [1. 覆盖范围与来源](#1-覆盖范围与来源)
- [2. 命令/选项清单（覆盖核对）](#2-命令选项清单覆盖核对)
  - [2.1 顶层命令](#21-顶层命令)
  - [2.2 子命令](#22-子命令)
  - [2.3 全局/通用选项](#23-全局通用选项)
  - [2.4 逐命令选项索引](#24-逐命令选项索引)
  - [2.5 部署场景矩阵（§2.2）](#25-部署场景矩阵22)
  - [2.6 逐命令风险检查清单（§2.3）](#26-逐命令风险检查清单23)
- [3. 命令分章（10.1 模板）](#3-命令分章101-模板)
  - [3.1 download](#31-download)
  - [3.2 manifests](#32-manifests)
  - [3.3 create cluster](#33-create-cluster)
  - [3.4 create registry](#34-create-registry)
  - [3.5 create manifests](#35-create-manifests)
  - [3.6 create iso](#36-create-iso)
  - [3.7 delete cluster](#37-delete-cluster)
  - [3.8 delete registry](#38-delete-registry)
  - [3.9 push images](#39-push-images)
  - [3.10 scale cluster](#310-scale-cluster)
  - [3.11 upgrade cluster](#311-upgrade-cluster)
  - [3.12 upgrade etcd](#312-upgrade-etcd)
  - [3.13 renew kubernetes-ca](#313-renew-kubernetes-ca)
  - [3.14 renew etcd-ca](#314-renew-etcd-ca)
  - [3.15 renew kubernetes-certs](#315-renew-kubernetes-certs)
  - [3.16 renew etcd-certs](#316-renew-etcd-certs)
  - [3.17 version](#317-version)
  - [3.18 help](#318-help)
- [4. 参数来源矩阵（§8）](#4-参数来源矩阵8)
  - [4.1 优先级与覆盖规则](#41-优先级与覆盖规则)
  - [4.2 参数来源矩阵](#42-参数来源矩阵)
  - [4.3 约束与校验](#43-约束与校验)
  - [4.4 配置场景样例（conf/）](#44-配置场景样例conf)
- [12. 验证清单（§12）](#12-验证清单12)
- [13. 样例审计清单（§13）](#13-样例审计清单13)

## 1. 覆盖范围与来源

- 入口脚本：`/home/mensyli1/Documents/workspace/sre/kubexm-script/bin/kubexm`
- 解析来源：`show_help` 与各命令解析分支
- 核心实现目录：
- `internal/pipeline`（流程编排）
- `internal/module`（模块封装）
- `internal/task`（任务组装）
- `internal/step`（原子步骤）
- `internal/runner` / `internal/connector`（执行与连接）
- 帮助总览：`bin/kubexm:75-140`
- 顶层分发：`bin/kubexm:779-999`

## 2. 命令/选项清单（覆盖核对）

> 要求：列出 `bin/kubexm` 的完整命令/子命令/选项清单，并带 `file:line` 以便回溯。

### 2.1 顶层命令

| 命令 | 说明 | 入口/分发位置 |
| --- | --- | --- |
| download | 离线下载集群资源 | `bin/kubexm:779-786` |
| manifests | 显示依赖清单（顶层别名） | `bin/kubexm:787-793` |
| create | 创建类命令分组 | `bin/kubexm:794-837` |
| delete | 删除类命令分组 | `bin/kubexm:838-867` |
| push | 推送类命令分组 | `bin/kubexm:868-889` |
| scale | 扩缩容命令分组 | `bin/kubexm:891-913` |
| upgrade | 升级命令分组 | `bin/kubexm:914-942` |
| renew | 证书续期命令分组 | `bin/kubexm:944-987` |
| version / -v / --version | 版本信息 | `bin/kubexm:988-990` |
| help / -h / --help | 帮助信息 | `bin/kubexm:991-993` |

### 2.2 子命令

| 命令 | 子命令 | 说明 | 入口/分发位置 |
| --- | --- | --- | --- |
| create | cluster | 创建集群 | `bin/kubexm:803-808` |
| create | registry | 创建 Registry | `bin/kubexm:810-815` |
| create | manifests | 显示依赖清单（子命令） | `bin/kubexm:817-822` |
| create | iso | 构建系统包 ISO | `bin/kubexm:824-829` |
| delete | cluster | 删除集群 | `bin/kubexm:847-852` |
| delete | registry | 删除 Registry | `bin/kubexm:854-859` |
| push | images | 推送镜像 | `bin/kubexm:877-882` |
| scale | cluster | 扩缩容集群 | `bin/kubexm:900-905` |
| upgrade | cluster | 升级 Kubernetes | `bin/kubexm:923-928` |
| upgrade | etcd | 升级 etcd | `bin/kubexm:930-935` |
| renew | kubernetes-ca | 续期 K8s CA | `bin/kubexm:953-958` |
| renew | etcd-ca | 续期 etcd CA | `bin/kubexm:960-965` |
| renew | kubernetes-certs | 续期 K8s 叶子证书 | `bin/kubexm:967-972` |
| renew | etcd-certs | 续期 etcd 叶子证书 | `bin/kubexm:974-979` |

### 2.3 全局/通用选项

| 选项 | 说明 | 位置 |
| --- | --- | --- |
| -h / --help | 显示帮助 | `bin/kubexm:991-993` |
| -v / --version | 显示版本 | `bin/kubexm:988-990` |

### 2.4 逐命令选项索引

> 选项来源以命令帮助与参数解析为准（CLI 帮助 + task/step 解析点）。

#### download

- `--cluster=NAME`（必需）`bin/kubexm:166-173`；`internal/task/download.sh:23-56`
- `--kubernetes-version=VER` `bin/kubexm:168-171`；`internal/task/download.sh:26-33`
- `--container-runtime=RT` `bin/kubexm:170-171`；`internal/task/download.sh:29-31`
- `--cni=PLUGIN` `bin/kubexm:171-172`；`internal/task/download.sh:32-33`
- `--with-build-all` `bin/kubexm:175-176`；`internal/task/download.sh:35-36`
- `--with-build-os=OS` `bin/kubexm:176-177`；`internal/task/download.sh:38-39`
- `--with-build-os-version=VER` `bin/kubexm:177-178`；`internal/task/download.sh:41-42`
- `--with-build-arch=ARCH` `bin/kubexm:178-179`；`internal/task/download.sh:44-45`
- `--with-build-local` `bin/kubexm:179-180`；`internal/task/download.sh:47-48`
- `-h | --help` `bin/kubexm:780-783`

#### manifests / create manifests

- `--kubernetes-version=VER` `bin/kubexm:257-259`；`internal/step/steps/manifests_collect_args.sh:30-33`
- `--kubernetes-type=TYPE` `bin/kubexm:258-260`；`internal/step/steps/manifests_collect_args.sh:33-35`
- `--container-runtime=RT` `bin/kubexm:259-261`；`internal/step/steps/manifests_collect_args.sh:36-38`
- `--cni=PLUGIN` `bin/kubexm:260-262`；`internal/step/steps/manifests_collect_args.sh:39-41`
- `--arch=ARCH` `bin/kubexm:261-263`；`internal/step/steps/manifests_collect_args.sh:42-44`
- `--cluster=NAME` `bin/kubexm:262-264`；`internal/step/steps/manifests_collect_args.sh:45-47`
- `-h | --help` `bin/kubexm:787-793`；`bin/kubexm:817-823`

#### create cluster

- `--cluster=NAME`（必需）`bin/kubexm:803-808`；`internal/pipeline/create_cluster.sh:16-28`；`internal/task/cluster_create.sh:13-25`
- `-h | --help` `bin/kubexm:803-807`

#### create registry

- `--cluster=NAME`（必需）`bin/kubexm:810-816`；`internal/task/create_registry.sh:10-23`
- `-h | --help` `bin/kubexm:811-813`

#### delete registry

- `--cluster=NAME`（必需）`bin/kubexm:854-859`；`internal/task/delete_registry.sh:10-27`
- `--force` `bin/kubexm:237-240`；`internal/step/steps/registry_delete.sh:13-18`
- `--delete-images`（可选，删除数据目录）`internal/step/steps/registry_delete.sh:11-46`
- `-h | --help` `bin/kubexm:855-857`

#### create iso

- `--with-build-all` `bin/kubexm:291-292`；`internal/task/iso_build.sh:17-20`
- `--with-build-os=OS` `bin/kubexm:292-293`；`internal/task/iso_build.sh:21-23`
- `--with-build-os-version=VER` `bin/kubexm:293-294`；`internal/task/iso_build.sh:24-26`
- `--with-build-arch=ARCH` `bin/kubexm:294-295`；`internal/task/iso_build.sh:27-29`
- `--with-build-local` `bin/kubexm:295-296`；`internal/task/iso_build.sh:30-32`
- `-h | --help` `bin/kubexm:824-827`

#### push images

- `--cluster=NAME` `bin/kubexm:392-394`
- `--list=FILE` `bin/kubexm:395-397`
- `--dual` `bin/kubexm:398-400`
- `--manifest` `bin/kubexm:401-403`
- `--target-registry=URL` `bin/kubexm:407-409`
- `--packages` `bin/kubexm:410-413`
- `--packages-dir=DIR` `bin/kubexm:414-416`
- `--parallel=N`（仅 `--packages`）`bin/kubexm:418-421`
- `-h | --help` `bin/kubexm:878-880`；`bin/kubexm:423-425`

#### delete cluster

- `--cluster=NAME`（必需）`internal/task/delete_cluster.sh:10-27`；`internal/step/steps/cluster_delete_validate.sh:13-23`
- `-f | --force` `internal/step/steps/cluster_delete_validate.sh:10-20`
- `-h | --help` `bin/kubexm:847-850`

#### scale cluster

- `--cluster=NAME`（必需）`internal/task/scale_cluster.sh:10-27`
- `--action=scale-out|scale-in` `internal/step/steps/cluster_scale_join_workers_collect_action.sh:11-15`；`internal/step/steps/cluster_scale_drain_nodes.sh:11-14`
- `--nodes=node1,node2` `internal/step/steps/cluster_scale_drain_nodes.sh:11-15`
- `-h | --help` `bin/kubexm:901-903`

#### upgrade cluster

- `--cluster=NAME`（必需）`internal/task/upgrade_cluster.sh:10-27`
- `--to-version=VERSION`（必需）`internal/step/steps/cluster_upgrade_control_plane_collect_target.sh:11-18`
- `-h | --help` `bin/kubexm:923-926`

#### upgrade etcd

- `--cluster=NAME`（必需）`internal/task/upgrade_etcd.sh:10-27`
- `--to-version=VERSION`（必需）`internal/step/steps/etcd_upgrade_validate.sh:11-18`
- `-h | --help` `bin/kubexm:930-933`

#### renew kubernetes-ca / etcd-ca / kubernetes-certs / etcd-certs

- `--cluster=NAME`（必需）`internal/task/renew_kubernetes_ca.sh:10-27`（其它 renew task 同结构）
- `-h | --help` `bin/kubexm:953-977`

### 2.5 部署场景矩阵（§2.2）

> 说明：矩阵基于 deployment matrix rules，覆盖 kubernetes_type / etcd_type / loadbalancer 组合。loadbalancer 的 enabled/mode/type 规则见下表，mode=exists 表示外部 LB 已存在；mode=kube-vip 表示使用 kube-vip；mode=internal/external 需指定具体 type。若 loadbalancer.enabled=false，则忽略 mode/type。

| kubernetes_type | etcd_type | loadbalancer.enabled | loadbalancer.mode | loadbalancer.type | 备注 |
| --- | --- | --- | --- | --- | --- |
| kubeadm | kubeadm | false | — | — | kubeadm 内置 etcd（同 control-plane），无 LB |
| kubeadm | kubeadm | true | kube-vip | kube-vip | kube-vip 模式（type 强制同步） |
| kubeadm | kubeadm | true | exists | exists | 外部 LB 已存在（type 强制同步） |
| kubeadm | kubeadm | true | internal | haproxy | kubeadm + internal haproxy（静态 Pod） |
| kubeadm | kubeadm | true | internal | nginx | kubeadm + internal nginx（静态 Pod） |
| kubeadm | kubeadm | true | external | kubexm-kh | external LB（keepalived + haproxy） |
| kubeadm | kubeadm | true | external | kubexm-kn | external LB（keepalived + nginx） |
| kubeadm | kubexm | false | — | — | etcd 独立二进制部署，无 LB |
| kubeadm | kubexm | true | kube-vip | kube-vip | kube-vip + 独立 etcd |
| kubeadm | kubexm | true | exists | exists | 外部 LB 已存在 + 独立 etcd |
| kubeadm | kubexm | true | internal | haproxy | kubeadm + internal haproxy（静态 Pod）+ 独立 etcd |
| kubeadm | kubexm | true | internal | nginx | kubeadm + internal nginx（静态 Pod）+ 独立 etcd |
| kubeadm | kubexm | true | external | kubexm-kh | external LB（keepalived + haproxy）+ 独立 etcd |
| kubeadm | kubexm | true | external | kubexm-kn | external LB（keepalived + nginx）+ 独立 etcd |
| kubeadm | exists | false | — | — | 复用外部 etcd（仅配置连接） |
| kubeadm | exists | true | kube-vip | kube-vip | kube-vip + 外部 etcd |
| kubeadm | exists | true | exists | exists | 外部 LB 已存在 + 外部 etcd |
| kubeadm | exists | true | internal | haproxy | kubeadm + internal haproxy（静态 Pod）+ 外部 etcd |
| kubeadm | exists | true | internal | nginx | kubeadm + internal nginx（静态 Pod）+ 外部 etcd |
| kubeadm | exists | true | external | kubexm-kh | external LB（keepalived + haproxy）+ 外部 etcd |
| kubeadm | exists | true | external | kubexm-kn | external LB（keepalived + nginx）+ 外部 etcd |
| kubexm | kubexm | false | — | — | kubexm 二进制部署 + 独立 etcd |
| kubexm | kubexm | true | kube-vip | kube-vip | kube-vip + kubexm 二进制 |
| kubexm | kubexm | true | exists | exists | 外部 LB 已存在 + kubexm 二进制 |
| kubexm | kubexm | true | internal | haproxy | kubexm + internal haproxy（binary） |
| kubexm | kubexm | true | internal | nginx | kubexm + internal nginx（binary） |
| kubexm | kubexm | true | external | kubexm-kh | external LB（keepalived + haproxy） |
| kubexm | kubexm | true | external | kubexm-kn | external LB（keepalived + nginx） |
| kubexm | exists | false | — | — | kubexm + 外部 etcd（仅配置连接） |
| kubexm | exists | true | kube-vip | kube-vip | kube-vip + 外部 etcd |
| kubexm | exists | true | exists | exists | 外部 LB 已存在 + 外部 etcd |
| kubexm | exists | true | internal | haproxy | kubexm + internal haproxy（binary）+ 外部 etcd |
| kubexm | exists | true | internal | nginx | kubexm + internal nginx（binary）+ 外部 etcd |
| kubexm | exists | true | external | kubexm-kh | external LB（keepalived + haproxy）+ 外部 etcd |
| kubexm | exists | true | external | kubexm-kn | external LB（keepalived + nginx）+ 外部 etcd |

### 2.6 逐命令风险检查清单（§2.3）

> 说明：每条命令在执行前应完成的最小风险检查集合。根据命令影响范围分为“高风险/中风险/低风险”。

| 命令 | 风险级别 | 执行前检查清单 |
| --- | --- | --- |
| download | 低 | 1) 确认 `--cluster` 与配置目录存在（若走配置模式）；2) 校验 `--kubernetes-version/--container-runtime/--cni` 取值有效；3) 确认网络/镜像源可达或离线包已准备 |
| manifests | 低 | 1) 若使用 `--cluster`，确认 config/host 文件存在；2) 确认 `--kubernetes-version/--kubernetes-type/--container-runtime/--cni/--arch` 与目标环境一致；3) 若需远程 Helm 拉取，确保 Helm 与仓库可访问 |
| create cluster | 高 | 1) 确认 `--cluster` 配置/主机清单正确且可达；2) 明确 kubernetes_type/etcd_type/loadbalancer 组合与目标架构一致；3) 确认离线/在线资源齐备（镜像、二进制、包）；4) 校验控制面/etcd 规模与证书/时钟同步；5) 评估执行窗口与回滚方案 |
| create registry | 中 | 1) 确认 registry 角色节点与端口配置；2) 验证磁盘空间与网络连通；3) 确认不会与现有 registry 服务冲突 |
| create manifests | 低 | 1) 同 `manifests`；2) 确认输出路径/权限可写；3) 确认 addons/ingress/storage 期望值 |
| create iso | 中 | 1) 校验 `--with-build-*` 组合与目标 OS/Arch；2) 确认本地构建依赖与磁盘空间；3) 评估构建时间窗口 |
| delete cluster | 高 | 1) 二次确认目标集群名称与节点清单；2) 明确是否保留数据/证书/配置；3) 若未 `--force`，确认交互流程；4) 评估删除后恢复路径 |
| delete registry | 中 | 1) 确认 registry 仅在目标集群中使用；2) 确认备份或镜像迁移完成；3) 评估停止服务对部署流水线影响 |
| push images | 中 | 1) 确认目标 registry 可达/认证策略；2) 校验镜像列表与标签正确；3) 若 `--packages`，确认目录存在与并发参数合理；4) 评估带宽与耗时 |
| scale cluster | 高 | 1) 明确 scale-in/out 及节点列表；2) 确认新节点 OS/内核/容器运行时与集群一致；3) 校验 LB/etcd/控制面容量与拓扑；4) 评估业务维护窗口 |
| upgrade cluster | 高 | 1) 备份 etcd 与关键证书；2) 确认目标版本兼容与升级路径；3) 预演控制面/节点升级顺序；4) 评估回滚与停机窗口 |
| upgrade etcd | 高 | 1) 备份 etcd 数据；2) 校验目标版本与集群兼容；3) 明确滚动升级顺序与健康检查；4) 评估故障回退方案 |
| renew kubernetes-ca | 高 | 1) 备份现有 CA 与证书；2) 确认所有控制面节点可达；3) 明确证书分发与重启策略；4) 评估业务影响窗口 |
| renew etcd-ca | 高 | 1) 备份现有 etcd CA 与证书；2) 确认 etcd 节点可达；3) 明确证书分发与重启策略；4) 评估 etcd 集群可用性窗口 |
| renew kubernetes-certs | 中 | 1) 备份现有证书；2) 确认控制面/工作节点可达；3) 明确证书分发与重启策略 |
| renew etcd-certs | 中 | 1) 备份现有证书；2) 确认 etcd 节点可达；3) 明确证书分发与重启策略 |
| version | 低 | 1) 无特殊检查 |
| help | 低 | 1) 无特殊检查 |

## 3. 命令分章（10.1 模板）

> 每章模板字段：命令/子命令、入口位置、调用链、最深执行点、关键参数与来源摘要、风险与可靠性要点。

### 3.1 download

- 命令/子命令：`kubexm download`
- 入口位置：`bin/kubexm:780-786`
- 调用链（含参数传播点）：
- `bin/kubexm:780-786` → `pipeline::download`
- `internal/pipeline/download.sh:15` → `module::download_prepare`
- `internal/module/download.sh:8` → `task::download_resources`
- `internal/task/download.sh:10-78` 解析 `--cluster/--kubernetes-version/--container-runtime/--cni/--with-build-*` 并加载 config.yaml
- `internal/task/download.sh:86-118` 通过 `task::run_steps` 组装 `download.*` 步骤
- 最深执行点（示例）：`download.container_images`/`download.helm_charts` 等步骤内部执行 `curl`/`skopeo`/`helm`，由 `runner::exec` 统一调度
- 关键参数与来源摘要：
- `--cluster` 必填，拼接 `conf/clusters/<name>/config.yaml` 并导出 `KUBEXM_CONFIG_FILE`（`internal/task/download.sh:33-46`）
- `--kubernetes-version/--container-runtime/--cni` 覆盖 config 读取值（`internal/task/download.sh:50-57`）
- `--with-build-*` 影响 `KUBEXM_BUILD_*` 环境变量（`internal/task/download.sh:60-78`）
- 条件/分支：
- `config.yaml` 必须存在（`internal/task/download.sh:41-45`）
- download 不解析 `host.yaml`（符合离线下载流程）
- 风险与可靠性要点：
- 依赖外部网络与 `curl/skopeo/helm`，建议配合 `download.check_deps` 与 `download.tools_binaries` 步骤确保工具齐备。
- 资源集合由 `k8s_type/etcd_type/lb_*` 等组合决定，需确保配置一致性以避免缺包。

### 3.2 manifests

- 命令/子命令：`kubexm manifests` / `kubexm create manifests`
- 入口位置：`bin/kubexm:787-793`（顶层）/ `bin/kubexm:817-823`（create 子命令）
- 调用链（含参数传播点）：
- `bin/kubexm:787-793` → `pipeline::manifests`
- `internal/pipeline/manifests.sh:15` → `module::manifests_prepare`
- `internal/module/manifests.sh:9` → `task::manifests`
- `internal/task/manifests.sh:10-35` 通过 `task::run_steps` 组装 `manifests.*` 步骤
- `internal/step/steps/manifests_collect_args.sh:10-63` 解析 `--kubernetes-version/--kubernetes-type/--container-runtime/--cni/--arch/--cluster`
- `internal/step/steps/manifests_collect_from_cluster_prepare.sh:13-44` 在 `--cluster` 场景解析 config/host 并注入上下文
- 最深执行点（示例）：`manifests.show_helm`/`manifests.show_images` 等步骤内部可能调用 helm/镜像解析逻辑
- 关键参数与来源摘要：
- CLI：`--kubernetes-version/--kubernetes-type/--container-runtime/--cni/--arch/--cluster`
- `--cluster` 时加载 `conf/clusters/<name>/config.yaml` 与 `host.yaml` 并覆盖默认值
- 条件/分支：`--cluster` 模式要求 `config.yaml`/`host.yaml` 存在（`manifests_collect_from_cluster_prepare`）
- 风险与可靠性要点：
- 依赖 helm/镜像解析能力的步骤需要相应工具可用，建议与工具二进制离线包配套。
- 组合参数决定镜像/二进制清单集合，配置不一致会导致清单偏差。

### 3.3 create cluster

- 命令/子命令：`kubexm create cluster`
- 入口位置：`bin/kubexm:803-808`
- 调用链（含参数传播点）：
- `bin/kubexm:803-808` → `pipeline::create_cluster`
- `internal/pipeline/create_cluster.sh:12-46` 解析 `--cluster`，设置 `KUBEXM_CONFIG_FILE/KUBEXM_HOST_FILE`，加载 config，并在 `spec.mode=online` 时先调用 `pipeline::download`
- `internal/module/cluster_create.sh:9-12` → `task::system_check` → `task::cluster_create`
- `internal/task/system_check.sh` 通过 `task::run_steps` 执行工具与离线包检查
- `internal/task/cluster_create.sh` 解析 config/hosts，执行 `cluster.validate` 并按 runtime/k8s/etcd/LB/CNI 分支组装步骤
- 最深执行点（示例）：`runner::exec` → `connector::exec` 通过 SSH 下发命令（`internal/runner/runner.sh:30-55`、`internal/connector/connector.sh:4-30`）
- 关键参数与来源摘要：
- `--cluster` 必填，决定 `conf/clusters/<name>/config.yaml` 与 `host.yaml`
- `spec.mode=online` 时自动触发 `download`，离线模式直接进入创建流程
- `cluster.validate` 会执行 `config::validate` 与 `config::validate_consistency`，并校验组合合法性
- 条件/分支：
- `host.yaml` 中禁止 `localhost/127.0.0.1`，且即使是本机也会解析主机大网 IP 并通过 SSH 执行
- `kubernetes_type/etcd_type/loadbalancer` 组合决定后续步骤与部署方式
- 风险与可靠性要点：
- 依赖 SSH 连接稳定性与节点可达性，建议先通过 `system_check` 验证环境。
- 线上模式会触发自动下载，需保证下载资源与配置一致。

### 3.4 create registry

- 命令/子命令：`kubexm create registry`
- 入口位置：`bin/kubexm:810-816`
- 调用链（含参数传播点）：
- `bin/kubexm:810-816` → `pipeline::create_registry`
- `internal/pipeline/create_registry.sh:15` → `module::create_registry_prepare`
- `internal/module/create_registry.sh:8` → `task::create_registry`
- `internal/task/create_registry.sh:10-42` 解析 `--cluster`，加载 config/hosts
- `internal/task/create_registry.sh:45-61` 通过 `task::run_steps` 组装 `registry.create_*` 步骤
- 最深执行点（示例）：`registry.create_systemd` 通过 `runner::exec` 下发 systemd 启动/重载命令
- 关键参数与来源摘要：`--cluster` 必填；`spec.registry.*` 由 config 提供并用于端口/目录/开关设置
- 条件/分支：`registry.create_collect_role` 依赖 `registry` 角色主机组
- 风险与可靠性要点：
  - 依赖远程 systemd/端口健康检查，节点不可达或服务启动失败会导致 registry 不可用。
  - `spec.registry.*` 配置错误（端口/角色）会触发校验失败或服务启动后无法访问。
  - 部署失败时可能留下部分配置/服务，需要清理后重试。

### 3.5 create manifests

- 命令/子命令：`kubexm create manifests`
- 入口位置：`bin/kubexm:817-823`
- 调用链（含参数传播点）：`bin/kubexm:817-823` → `pipeline::manifests` → 详见 §3.2 `manifests`（调用链/参数传播/分支完全相同）
- 最深执行点：同 `kubexm manifests`
- 关键参数与来源摘要：同 `kubexm manifests`
- 条件/分支：同 `kubexm manifests`
- 风险与可靠性要点：
  - 依赖 helm/Chart 解析与仓库可达性，失败会导致清单/镜像列表不完整。
  - `--cluster` 覆盖后的 addons/lb/cni 参数决定输出集合，配置错误易引入缺失镜像。
  - 本地 chart 缺失/损坏会直接中断生成流程。

### 3.6 create iso

- 命令/子命令：`kubexm create iso`
- 入口位置：`bin/kubexm:824-830`
- 调用链（含参数传播点）：
- `bin/kubexm:824-830` → `pipeline::iso`
- `internal/pipeline/iso.sh:15` → `module::iso_prepare`
- `internal/module/iso.sh:8` → `task::iso_build`
- `internal/task/iso_build.sh:10-42` 解析 `--with-build-*` 并导出 `KUBEXM_BUILD_*`
- `internal/task/iso_build.sh:44-52` 通过 `task::run_steps` 执行 `iso.check_deps` 与 `iso.build_system_packages`
- 最深执行点（示例）：`iso.build_system_packages` 内部执行系统包 ISO 构建
- 关键参数与来源摘要：`--with-build-*` 决定构建 OS/版本/架构与本地构建方式
- 条件/分支：`--with-build-arch` 未指定时默认 `amd64,arm64`（`internal/task/iso_build.sh:33-40`）
- 风险与可靠性要点：
  - ISO 构建依赖资源下载链路（curl 等），下载失败会导致 ISO 不完整或无法生成。
  - `KUBEXM_BUILD_*` 组合决定下载集合与架构，参数不匹配会生成错误架构的离线包。
  - 未见校验和验证，生成产物可能混入损坏文件，需要二次校验/重试。

### 3.7 delete cluster

- 命令/子命令：`kubexm delete cluster`
- 入口位置：`bin/kubexm:847-853`
- 调用链（含参数传播点）：
- `bin/kubexm:847-853` → `pipeline::delete_cluster`
- `internal/pipeline/delete_cluster.sh:15` → `module::delete_cluster_prepare`
- `internal/module/delete_cluster.sh:8` → `task::delete_cluster`
- `internal/task/delete_cluster.sh:10-42` 解析 `--cluster`，加载 config/hosts
- `internal/task/delete_cluster.sh:45-68` 执行 `cluster.delete_*` 与 addon 删除
- `internal/task/delete_cluster.sh:70-88` CNI 分支（calico/flannel/cilium）
- `internal/task/delete_cluster.sh:90-105` drain/remove/reset/cleanup
- `internal/task/delete_cluster.sh:107-125` runtime 清理（containerd/docker）
- 最深执行点（示例）：`runner::exec` → `connector::exec` 下发重置/清理命令
- 关键参数与来源摘要：`--cluster` 必填；`--force` 由校验/删除步骤消费
- 条件/分支：CNI 与 runtime 类型决定清理路径；配置/主机文件必须存在
- 风险与可靠性要点：
  - 删除路径包含 `kubeadm reset` 与 iptables/IPVS 清理，误用可能影响非目标集群/节点网络。
  - 远程执行失败会留下部分状态（残留证书/配置/数据目录），需手动清理后再试。
  - `--force` 跳过交互确认，易导致误删；单节点分支影响更大。

### 3.8 delete registry

- 命令/子命令：`kubexm delete registry`
- 入口位置：`bin/kubexm:854-860`
- 调用链（含参数传播点）：
- `bin/kubexm:854-860` → `pipeline::delete_registry`
- `internal/pipeline/delete_registry.sh:15` → `module::delete_registry_prepare`
- `internal/module/delete_registry.sh:8` → `task::delete_registry`
- `internal/task/delete_registry.sh:10-40` 解析 `--cluster`，加载 config/hosts
- `internal/task/delete_registry.sh:42-48` 执行 `registry.delete` 步骤
- 最深执行点（示例）：`registry.delete` 通过 `runner::exec` 下发停止/清理指令
- 关键参数与来源摘要：`--cluster` 必填；`--force` 由删除步骤消费
- 条件/分支：要求 `registry` 角色存在且配置可解析
- 风险与可靠性要点：
  - 远程删除服务/目录，失败会残留 registry 数据或服务状态不一致。
  - `--force` 跳过确认可能误删错误节点上的 registry 目录。
  - registry 角色配置错误会导致删除目标不完整或失败。

### 3.9 push images

- 命令/子命令：`kubexm push images`
- 入口位置：`bin/kubexm:877-883`
- 调用链（含参数传播点）：
- `bin/kubexm:877-883` → `pipeline::push_images`
- `internal/pipeline/push_images.sh:15` → `module::push_images_prepare`
- `internal/module/push_images.sh:8` → `task::push_images`
- `internal/task/push_images.sh:10-43` 解析 flags，`--packages*` 会开启离线包检查
- `internal/task/push_images.sh:44-61` 执行 `images.push_*` 步骤（collect/validate/config/list/push）
- 最深执行点（示例）：`images.push_packages_concurrent_exec`/`images.push_packages_sequential` 内部通过 `skopeo` 推送镜像
- 关键参数与来源摘要：`--list/--dual/--manifest/--target-registry/--packages/--packages-dir/--parallel`
- 条件/分支：packages 模式触发离线包校验；并发模式仅在 packages 分支生效
- 风险与可靠性要点：
  - 依赖 skopeo/manifest-tool 与目标 registry 可达性，推送失败会导致镜像集不完整。
  - 并发推送（packages/parallel）可能触发 registry 限流或网络抖动，需关注重试与错误日志。
  - `--dual/--manifest` 模式生成多架构清单，配置错误会导致镜像标签覆盖或平台缺失。

### 3.10 scale cluster

- 命令/子命令：`kubexm scale cluster`
- 入口位置：`bin/kubexm:900-906`
- 调用链（含参数传播点）：
- `bin/kubexm:900-906` → `pipeline::scale_cluster`
- `internal/pipeline/scale_cluster.sh:15` → `module::scale_cluster_prepare`
- `internal/module/scale_cluster.sh:8` → `task::scale_cluster`
- `internal/task/scale_cluster.sh:10-42` 解析 `--cluster`，加载 config/hosts
- `internal/task/scale_cluster.sh:44-63` 采集 action/node/join command 并执行 join
- `internal/task/scale_cluster.sh:64-76` scale-in drain/remove/reset/cleanup
- `internal/task/scale_cluster.sh:77-86` LB 更新（haproxy/nginx/kube-vip）
- 最深执行点（示例）：`cluster.scale_join_workers_exec`/`cluster.scale_drain_nodes` 内部调用 kubeadm/kubectl
- 关键参数与来源摘要：`--cluster` 必填；`--action=scale-out|scale-in`；`--nodes` 在 scale-in 使用
- 条件/分支：action 与 nodes 决定 join/drain 路径
- 风险与可靠性要点：
  - `scale-in` 会 drain + delete node，操作不可逆，误指定节点会影响业务容量。
  - `scale-out` 依赖 kubeadm token 与 join 命令远程执行，token 过期/节点不可达会失败。
  - 远程执行失败会留下节点处于部分加入/未清理状态，需要手动处理。

### 3.11 upgrade cluster

- 命令/子命令：`kubexm upgrade cluster`
- 入口位置：`bin/kubexm:923-928`
- 调用链（含参数传播点）：
- `bin/kubexm:923-928` → `pipeline::upgrade_cluster`
- `internal/pipeline/upgrade_cluster.sh:15` → `module::upgrade_cluster_prepare`
- `internal/module/upgrade_cluster.sh:8` → `task::upgrade_cluster`
- `internal/task/upgrade_cluster.sh:10-42` 解析 `--cluster`，加载 config/hosts
- `internal/task/upgrade_cluster.sh:44-59` precheck/版本校验
- `internal/task/upgrade_cluster.sh:60-73` 控制面升级（collect/drain/apply/restart）
- `internal/task/upgrade_cluster.sh:74-79` worker/CNI/addons/status
- 最深执行点（示例）：`cluster.upgrade_control_plane_apply` 内部执行 kubeadm 升级
- 关键参数与来源摘要：`--cluster` 与 `--to-version` 必填，目标版本由升级步骤解析
- 条件/分支：需要离线包（`KUBEXM_REQUIRE_PACKAGES=true`）与工具检查
- 风险与可靠性要点：
  - 控制面升级依赖 kubeadm，版本不兼容或升级失败会导致集群不可用。
  - 升级链路包含多节点远程执行，失败会留下混合版本状态，需要人工恢复。
  - CNI/Addons 升级为占位逻辑，可能需要手动补齐升级步骤。

### 3.12 upgrade etcd

- 命令/子命令：`kubexm upgrade etcd`
- 入口位置：`bin/kubexm:930-935`
- 调用链（含参数传播点）：
- `bin/kubexm:930-935` → `pipeline::upgrade_etcd`
- `internal/pipeline/upgrade_etcd.sh:15` → `module::upgrade_etcd_prepare`
- `internal/module/upgrade_etcd.sh:8` → `task::upgrade_etcd`
- `internal/task/upgrade_etcd.sh:10-42` 解析 `--cluster`，加载 config/hosts
- `internal/task/upgrade_etcd.sh:44-57` validate/backup/collect
- `internal/task/upgrade_etcd.sh:58-66` stop/copy/start/healthcheck
- 最深执行点（示例）：`etcd.upgrade_healthcheck` 内部调用 etcdctl
- 关键参数与来源摘要：`--cluster` 与 `--to-version` 必填，目标版本由升级步骤解析
- 条件/分支：需要离线包（`KUBEXM_REQUIRE_PACKAGES=true`）与工具检查
- 风险与可靠性要点：
  - 停止/替换 etcd 二进制涉及集群一致性，单点失败可能导致 etcd 不可用。
  - 健康检查依赖本地证书与端点可达性，证书错误会导致误判失败。
  - 未见滚动/回滚策略描述，升级中断需人工回退或恢复。

### 3.13 renew kubernetes-ca

- 命令/子命令：`kubexm renew kubernetes-ca`
- 入口位置：`bin/kubexm:953-958`
- 调用链（含参数传播点）：
- `bin/kubexm:953-958` → `pipeline::renew_kubernetes_ca`
- `internal/pipeline/renew_kubernetes_ca.sh:15` → `module::renew_kubernetes_ca_prepare`
- `internal/module/renew_kubernetes_ca.sh:8` → `task::renew_kubernetes_ca`
- `internal/task/renew_kubernetes_ca.sh:10-42` 解析 `--cluster`，加载 config/hosts
- `internal/task/renew_kubernetes_ca.sh:44-49` 执行 `certs.renew_kubernetes_ca`
- 最深执行点（示例）：`certs.renew_kubernetes_ca` 内部通过 runner/connector 分发证书
- 关键参数与来源摘要：`--cluster` 必填
- 条件/分支：依赖 control-plane 角色与证书路径配置
- 风险与可靠性要点：
  - 证书轮转涉及分发与验证，任一节点失败会导致证书不一致或服务中断。
  - 依赖 SSH 分发与 openssl verify，节点不可达会阻塞/中断流程。
  - 轮转阶段控制不当可能导致仅部分步骤执行，需明确阶段与回滚策略。

### 3.14 renew etcd-ca

- 命令/子命令：`kubexm renew etcd-ca`
- 入口位置：`bin/kubexm:960-965`
- 调用链（含参数传播点）：`bin/kubexm:960-965` → `pipeline::renew_etcd_ca` → `module::renew_etcd_ca_prepare` → `task::renew_etcd_ca`
- 最深执行点（示例）：`certs.renew_etcd_ca` 内部执行证书生成与分发
- 关键参数与来源摘要：`--cluster` 必填
- 条件/分支：依赖 etcd 角色或外部 etcd 配置
- 风险与可靠性要点：
  - 证书轮转涉及分发与验证，任一节点失败会导致证书不一致或服务中断。
  - 依赖 SSH 分发与 openssl verify，节点不可达会阻塞/中断流程。
  - 轮转阶段控制不当可能导致仅部分步骤执行，需明确阶段与回滚策略。

### 3.15 renew kubernetes-certs

- 命令/子命令：`kubexm renew kubernetes-certs`
- 入口位置：`bin/kubexm:967-972`
- 调用链（含参数传播点）：`bin/kubexm:967-972` → `pipeline::renew_kubernetes_certs` → `module::renew_kubernetes_certs_prepare` → `task::renew_kubernetes_certs`
- 最深执行点（示例）：`certs.renew_kubernetes_certs` 内部执行证书生成与分发
- 关键参数与来源摘要：`--cluster` 必填
- 条件/分支：依赖 control-plane 与 kubelet 证书路径配置
- 风险与可靠性要点：
  - 证书轮转涉及分发与验证，任一节点失败会导致证书不一致或服务中断。
  - 依赖 SSH 分发与 openssl verify，节点不可达会阻塞/中断流程。
  - 轮转阶段控制不当可能导致仅部分步骤执行，需明确阶段与回滚策略。

### 3.16 renew etcd-certs

- 命令/子命令：`kubexm renew etcd-certs`
- 入口位置：`bin/kubexm:974-979`
- 调用链（含参数传播点）：`bin/kubexm:974-979` → `pipeline::renew_etcd_certs` → `module::renew_etcd_certs_prepare` → `task::renew_etcd_certs`
- 最深执行点（示例）：`certs.renew_etcd_certs` 内部执行证书生成与分发
- 关键参数与来源摘要：`--cluster` 必填
- 条件/分支：依赖 etcd 角色与证书路径配置
- 风险与可靠性要点：
  - 证书轮转涉及分发与验证，任一节点失败会导致证书不一致或服务中断。
  - 依赖 SSH 分发与 openssl verify，节点不可达会阻塞/中断流程。
  - 轮转阶段控制不当可能导致仅部分步骤执行，需明确阶段与回滚策略。

### 3.17 version

- 命令/子命令：`kubexm version`
- 入口位置：`bin/kubexm:988-990`
- 调用链：`bin/kubexm:988-990` → `show_version`（`bin/kubexm:48-50`）
- 最深执行点：`bin/kubexm:48-50`
- 关键参数与来源摘要：无
- 条件/分支：无
- 风险与可靠性要点：
  - 输出版本信息依赖脚本内版本变量/构建注入，未同步会导致版本误报。
  - 未见校验逻辑，返回内容仅供参考，不影响集群状态。

### 3.18 help

- 命令/子命令：`kubexm help`
- 入口位置：`bin/kubexm:991-993`
- 调用链：`bin/kubexm:991-993` → `show_help`（`bin/kubexm:55-130`）
- 最深执行点：`bin/kubexm:55-130`
- 关键参数与来源摘要：无
- 条件/分支：无
- 风险与可靠性要点：
  - 仅输出帮助文本，无外部副作用；内容与代码不一致时可能误导使用者。
  - 无参数校验/执行路径，仅影响可用性说明。

## 4. 参数来源矩阵（§8）

> 范围：`bin/kubexm` + `internal/{parser,config,task,step}` + `internal/config/domain`（归一与策略规则）。

### 4.1 优先级与覆盖规则

| 规则 | 说明 | 位置 |
| --- | --- | --- |
| CLI 覆盖配置 | download/manifests/iso/push 的 CLI 参数覆盖配置值或默认值 | `internal/task/download.sh:23-81`；`internal/step/steps/manifests_collect_args.sh:28-65`；`internal/task/iso_build.sh:17-44`；`bin/kubexm:390-421` |
| Config 解析入口 | parser 统一加载 config/hosts | `internal/parser/parser.sh:3-12`；`internal/config/config.sh:150-153`；`internal/config/config.sh:193-195` |
| Config 取值兜底 | `config::get` 支持原始键 + camel/snake 转换，未命中返回默认 | `internal/config/config.sh:205-229` |
| LB/etcd 类型归一 | LB mode/type、etcd type 统一归一 | `internal/config/getters/loadbalancer.sh:15-35`；`internal/config/getters/etcd.sh:11-14`；`internal/config/domain/normalize.sh:41-83` |
| 组合策略校验 | create cluster 入口执行组合合法性校验 | `internal/step/steps/cluster_validate.sh:38-54`；`internal/config/domain/rules/strategy_rules.sh:71-92` |

### 4.2 参数来源矩阵

| 参数 | CLI/ENV | Conf (config.yaml / host.yaml) | Defaults | Derived / 规则 | 定义与使用位置 |
| --- | --- | --- | --- | --- | --- |
| cluster_name | `--cluster`（download/create/registry/delete/scale/upgrade/renew） | `metadata.name` | — | CLI 未提供时可由 metadata.name 推导 | `internal/task/download.sh:23-60`；`internal/task/cluster_create.sh:13-29`；`internal/config/config.sh:382-396` |
| config_file | — | `conf/clusters/<name>/config.yaml` | `KUBEXM_CONF_DIR` | 由 cluster_name 拼接 | `internal/task/cluster_create.sh:27-30`；`internal/task/download.sh:58-60`；`internal/config/config.sh:18-21` |
| host_file | — | `conf/clusters/<name>/host.yaml` | `KUBEXM_CONF_DIR` | 由 cluster_name 拼接 | `internal/task/cluster_create.sh:28-31`；`internal/config/config.sh:18-21` |
| mode | — | `spec.mode` | `offline` | `online` 触发 create cluster 自动 download | `internal/config/config.sh:553-555`；`internal/pipeline/create_cluster.sh:41-46` |
| kubernetes.version | `--kubernetes-version` | `spec.kubernetes.version` | `DEFAULT_KUBERNETES_VERSION` | CLI > conf > defaults | `internal/task/download.sh:26-69`；`internal/step/steps/manifests_collect_args.sh:30-33`；`internal/config/config.sh:594-595`；`internal/config/defaults.sh:442-444` |
| kubernetes.type | `--kubernetes-type`（manifests） | `spec.kubernetes.type` | `DEFAULT_KUBERNETES_TYPE` | CLI > conf > defaults | `internal/step/steps/manifests_collect_args.sh:33-35`；`internal/config/getters/kubernetes.sh:11-12`；`internal/config/defaults.sh:449-451` |
| etcd.type | — | `spec.etcd.type` | `DEFAULT_ETCD_TYPE` | 归一化（exists/external） | `internal/config/config.sh:680-682`；`internal/config/getters/etcd.sh:11-14`；`internal/config/defaults.sh:896-896` |
| etcd.external_endpoints | — | `spec.etcd.external_endpoints` | — | 仅 etcd.type=exists 生效 | `internal/config/config.sh:712-714` |
| runtime.type | `--container-runtime`（download/manifests） | `spec.runtime.type` | `DEFAULT_RUNTIME_TYPE` | CLI > conf > defaults | `internal/task/download.sh:29-69`；`internal/step/steps/manifests_collect_args.sh:36-38`；`internal/config/config.sh:763-764`；`internal/config/defaults.sh:456-458` |
| network.plugin | `--cni`（download/manifests） | `spec.network.plugin` | `DEFAULT_CNI_PLUGIN` | CLI > conf > defaults | `internal/task/download.sh:32-69`；`internal/step/steps/manifests_collect_args.sh:39-41`；`internal/config/config.sh:779-780`；`internal/config/defaults.sh:463-465` |
| arch_list | `--arch` / `--with-build-arch` | `spec.arch[]` | `DEFAULT_ARCH_LIST` | CLI > conf > defaults | `internal/step/steps/manifests_collect_args.sh:42-44`；`internal/task/download.sh:44-77`；`internal/task/iso_build.sh:27-44`；`internal/config/config.sh:561-572` |
| loadbalancer.enabled/mode/type | — | `spec.loadbalancer.enabled/mode/type` | `DEFAULT_LOADBALANCER_*` | mode/type 归一 | `internal/config/config.sh:796-815`；`internal/config/getters/loadbalancer.sh:15-35`；`internal/config/defaults.sh:865-867` |
| loadbalancer.vip/interface/deploy_mode | — | `spec.loadbalancer.vip/interface/deploy_mode` | `DEFAULT_*` | kube-vip 部署方式由 deploy_mode 决定 | `internal/config/config.sh:820-847` |
| registry.enable/host/port/data_dir | — | `spec.registry.*` | `DEFAULT_REGISTRY_*` | host 为空时取 registry 角色首节点 | `internal/config/config.sh:884-927` |
| addons（metrics/ingress/nodelocaldns） | — | `spec.addons.*` | nodelocaldns 使用默认值 | — | `internal/config/config.sh:852-879`；`internal/config/defaults.sh:984-984` |
| ISO 构建参数 | `--with-build-*` | — | 默认 all + 双架构 | `download/iso` 统一导出 `KUBEXM_BUILD_*` | `internal/task/download.sh:35-81`；`internal/task/iso_build.sh:17-44` |
| paths | — | `spec.paths.work_dir/cache_dir` | `/tmp/kubexm` / `/var/cache/kubexm` | — | `internal/config/config.sh:933-944` |

### 4.3 约束与校验

| 约束 | 说明 | 位置 |
| --- | --- | --- |
| host.yaml 禁止 localhost/127.0.0.1 | address/internalAddress 不允许本地回环 | `internal/config/loader.sh:52-58` |
| 执行层禁止 localhost | Runner 解析本机主 IP，Connector 拒绝 localhost | `internal/runner/runner.sh:22-33`；`internal/connector/connector.sh:6-29` |
| config::validate | 必须有 k8s_type/etcd_type；control-plane 必须存在；etcd_type=kubexm 需 etcd 角色 | `internal/config/config.sh:321-355` |
| config::validate_consistency | registry/LB/etcd/网络 CIDR 联动一致性校验 | `internal/config/validator/consistency.sh:11-167` |
| 部署组合策略 | k8s/etcd 组合、master 数量与 LB 组合合法性 | `internal/config/domain/rules/strategy_rules.sh:71-92` |
| 离线模式要求 packages 目录 | create cluster 在 offline 模式检查 `packages/` | `internal/step/steps/cluster_validate.sh:56-63` |
| etcd 升级限制 | etcd_type=exists 禁止自动升级 | `internal/step/steps/etcd_upgrade_validate.sh:24-28` |

### 4.4 配置场景样例（conf/）

| 场景 | 关键字段 | 文件 |
| --- | --- | --- |
| kubeadm 单节点 | `spec.kubernetes.type=kubeadm`, `spec.etcd.type=kubeadm`, `spec.loadbalancer.enabled=false` | `conf/clusters/test-01-kubeadm-single/config.yaml` |
| kubeadm 单节点 + 独立 etcd | `spec.etcd.type=kubexm` | `conf/clusters/test-02-kubeadm-single-kubexm-etcd/config.yaml` |
| kubexm 单节点 | `spec.kubernetes.type=kubexm`, `spec.etcd.type=kubexm` | `conf/clusters/test-03-kubexm-single/config.yaml` |
| kubeadm 三主（无外置 LB） | `spec.kubernetes.type=kubeadm` | `conf/clusters/test-04-kubeadm-3master/config.yaml` |
| external LB (kubexm-kh) | `spec.loadbalancer.enabled=true`, `spec.loadbalancer.mode=external`, `spec.loadbalancer.type=kubexm-kh` | `conf/clusters/test-07-kubeadm-3master-ext-lb-kh/config.yaml` |
| external LB (kubexm-kn) | `spec.loadbalancer.enabled=true`, `spec.loadbalancer.mode=external`, `spec.loadbalancer.type=kubexm-kn` | `conf/clusters/test-10-kubeadm-3master-ext-lb-kn/config.yaml` |
| internal haproxy | `spec.loadbalancer.mode=internal`, `spec.loadbalancer.type=haproxy` | `conf/clusters/test-13-kubeadm-3master-int-haproxy/config.yaml` |
| internal nginx | `spec.loadbalancer.mode=internal`, `spec.loadbalancer.type=nginx` | `conf/clusters/test-14-kubeadm-3master-int-nginx/config.yaml` |
| kube-vip | `spec.loadbalancer.mode=kube-vip` | `conf/clusters/test-19-kubeadm-3master-kubevip/config.yaml` |
| external etcd | `spec.etcd.type=exists`, `spec.etcd.external_endpoints` | `conf/clusters/test-22-kubeadm-3master-external-etcd/config.yaml` |
| multi-arch | `spec.arch: [amd64, arm64]` | `conf/clusters/test-27-kubeadm-multi-arch/config.yaml` |
| addons 全量开启 | `spec.addons.*.enabled=true` | `conf/clusters/test-28-kubeadm-all-addons/config.yaml` |
| addons 全量关闭 | `spec.addons.*.enabled=false` | `conf/clusters/test-29-kubeadm-no-addons/config.yaml` |
| CNI flannel/cilium | `spec.network.plugin=flannel` / `cilium` | `conf/clusters/test-48-kubeadm-flannel/config.yaml`；`conf/clusters/test-49-kubeadm-cilium/config.yaml` |
| 运行时 crio/docker/podman | `spec.runtime.type=crio/docker/podman` | `conf/clusters/test-40-kubeadm-crio/config.yaml`；`conf/clusters/test-41-kubeadm-docker/config.yaml`；`conf/clusters/test-42-kubeadm-podman/config.yaml` |

## 5. 架构/逻辑问题与整改计划

> 说明：列出当前命令解析与配置链路中的结构性问题，附证据位置（file:line），并给出可执行整改方向。

### 5.1 问题台账（Problem Ledger）

| 编号 | 问题 | 影响 | 证据位置 | 建议整改方向 |
| --- | --- | --- | --- | --- |
| — | 当前无阻断问题 | — | — | — |

### 5.2 整改清单（Remediation Checklist）

暂无。

## 12. 验证清单（§12）

> 说明：用于审计命令追踪报告是否覆盖所有命令类别与关键矩阵/分支。每项完成后标注 ✓/✗ 并给出证据位置（file:line 或章节编号）。

### 12.1 覆盖范围核对

- [ ] 顶层命令覆盖完整（download/manifests/create/delete/push/scale/upgrade/renew/version/help）
- [ ] create 子命令覆盖（cluster/registry/manifests/iso）
- [ ] delete 子命令覆盖（cluster/registry）
- [ ] push 子命令覆盖（images）
- [ ] scale 子命令覆盖（cluster）
- [ ] upgrade 子命令覆盖（cluster/etcd）
- [ ] renew 子命令覆盖（kubernetes-ca/etcd-ca/kubernetes-certs/etcd-certs）

### 12.2 选项与参数核对

- [ ] 全局选项（-h/--help，-v/--version）
- [ ] download 选项清单与解析分支（--cluster/--kubernetes-version/--container-runtime/--cni/--with-build-*/-h）
- [ ] manifests & create manifests 选项清单与解析分支（--kubernetes-version/--kubernetes-type/--container-runtime/--cni/--arch/--cluster/-h）
- [ ] create cluster 选项清单与解析分支（--cluster/-h）
- [ ] create/delete registry 选项清单与解析分支（create: --cluster/-h；delete: --cluster/--force/--delete-images/-h）
- [ ] create iso 选项清单与解析分支（--with-build-*/-h）
- [ ] delete cluster 选项清单与解析分支（--cluster/--force/-h）
- [ ] push images 选项清单与解析分支（--cluster/--list/--dual/--manifest/--target-registry/--packages/--packages-dir/--parallel/-h）
- [ ] scale cluster 选项清单与解析分支（--cluster/--action/--nodes/-h）
- [ ] upgrade cluster/etcd 选项清单与解析分支（--cluster/--to-version/-h）
- [ ] renew 证书类选项清单与解析分支（--cluster/-h）

### 12.3 关键链路核对

- [ ] download：离线下载链路到 `curl`（资源/二进制）
- [ ] create iso：构建链路到 `curl`（资源/二进制）
- [ ] manifests：Helm 本地/远程 chart 分支
- [ ] create cluster：kubeadm 与 kubexm（二进制）双链路 + 单节点分支
- [ ] create registry：systemd 部署与健康检查
- [ ] delete cluster：`kubeadm reset` 分支与单节点分支
- [ ] delete registry：停止服务与目录清理
- [ ] push images：skopeo/manifest-tool 分支，含优化模块回退
- [ ] scale cluster：join token 生成与远程 join 执行
- [ ] upgrade cluster：控制面升级命令
- [ ] upgrade etcd：etcdctl health 检查
- [ ] renew certs：`openssl verify` 与分发链路

### 12.4 部署矩阵核对

- [ ] kubernetes_type 覆盖 kubeadm / kubexm
- [ ] etcd_type 覆盖 kubeadm / kubexm / exists
- [ ] loadbalancer.enabled 覆盖 true/false
- [ ] loadbalancer.mode 覆盖 internal / external / kube-vip / exists
- [ ] loadbalancer.type 覆盖 haproxy / nginx / kubexm-kh / kubexm-kn / kube-vip / exists

## 13. 样例审计清单（§13）

> 说明：下列为审计时的样例记录模板。每项需附证据位置（file:line 或章节编号），并标注完成状态。

### 13.1 命令覆盖审计（样例）

| 项目 | 证据位置 | 状态 | 备注 |
| --- | --- | --- | --- |
| 顶层命令覆盖完整 | §2.1 | ☐ | download/manifests/create/delete/push/scale/upgrade/renew/version/help |
| create 子命令覆盖 | §2.2 | ☐ | cluster/registry/manifests/iso |
| delete 子命令覆盖 | §2.2 | ☐ | cluster/registry |
| push 子命令覆盖 | §2.2 | ☐ | images |
| scale 子命令覆盖 | §2.2 | ☐ | cluster |
| upgrade 子命令覆盖 | §2.2 | ☐ | cluster/etcd |
| renew 子命令覆盖 | §2.2 | ☐ | kubernetes-ca/etcd-ca/kubernetes-certs/etcd-certs |

### 13.2 选项覆盖审计（样例）

| 项目 | 证据位置 | 状态 | 备注 |
| --- | --- | --- | --- |
| 全局选项 | §2.3 | ☐ | -h/--help，-v/--version |
| download 选项 | §2.4（download） | ☐ | --cluster/--kubernetes-version/--container-runtime/--cni/--with-build-* |
| manifests 选项 | §2.4（manifests） | ☐ | --kubernetes-version/--kubernetes-type/--container-runtime/--cni/--arch/--cluster |
| create cluster 选项 | §2.4（create cluster） | ☐ | --cluster |
| registry 选项 | §2.4（create/delete registry） | ☐ | create: --cluster; delete: --cluster/--force/--delete-images |
| create iso 选项 | §2.4（create iso） | ☐ | --with-build-* |
| delete cluster 选项 | §2.4（delete cluster） | ☐ | --cluster/--force |
| push images 选项 | §2.4（push images） | ☐ | --cluster/--list/--dual/--manifest/--target-registry/--packages/--packages-dir/--parallel |
| scale cluster 选项 | §2.4（scale cluster） | ☐ | --cluster/--action/--nodes |
| upgrade cluster 选项 | §2.4（upgrade cluster） | ☐ | --cluster/--to-version |
| upgrade etcd 选项 | §2.4（upgrade etcd） | ☐ | --cluster/--to-version |
| renew certs 选项 | §2.4（renew certs） | ☐ | --cluster |

### 13.3 关键链路审计（样例）

| 项目 | 证据位置 | 状态 | 备注 |
| --- | --- | --- | --- |
| download 链路 | §3.1 | ☐ | curl 下载命令定位 |
| manifests 链路 | §3.2/§3.5 | ☐ | Helm 本地/远程分支 |
| create cluster 链路 | §3.3 | ☐ | kubeadm/kubexm/单节点分支 |
| create registry 链路 | §3.4 | ☐ | systemd + curl 健康检查 |
| delete cluster 链路 | §3.7 | ☐ | kubeadm reset + 单节点分支 |
| delete registry 链路 | §3.8 | ☐ | systemctl stop + rm -rf |
| push images 链路 | §3.9 | ☐ | skopeo/manifest-tool 分支 |
| scale cluster 链路 | §3.10 | ☐ | join token + join 命令 |
| upgrade cluster 链路 | §3.11 | ☐ | kubeadm upgrade apply |
| upgrade etcd 链路 | §3.12 | ☐ | etcdctl endpoint health |
| renew certs 链路 | §3.13-3.16 | ☐ | openssl verify + 分发 |

### 13.4 部署矩阵审计（样例）

| 项目 | 证据位置 | 状态 | 备注 |
| --- | --- | --- | --- |
| kubernetes_type 覆盖 | §2.5 | ☐ | kubeadm/kubexm |
| etcd_type 覆盖 | §2.5 | ☐ | kubeadm/kubexm/exists |
| loadbalancer.enabled 覆盖 | §2.5 | ☐ | true/false |
| loadbalancer.mode 覆盖 | §2.5 | ☐ | internal/external/kube-vip/exists |
| loadbalancer.type 覆盖 | §2.5 | ☐ | haproxy/nginx/kubexm-kh/kubexm-kn/kube-vip/exists |
