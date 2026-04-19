# KubeXM 测试方案、测试计划与测试用例文档

本文档详细描述了 KubeXM 集群部署与管理工具的测试方案、测试计划及具体的测试用例。测试覆盖了所有核心命令、参数分支以及相关的架构规范。

## 一、测试方案与策略

### 1.1 测试目标
- **功能正确性**：验证所有命令（download, create, delete, scale, upgrade, renew, backup, restore, health, reconfigure, push images）的功能符合设计预期。
- **参数与分支覆盖**：确保命令行中不同参数组合、在线/离线模式、单节点/多节点等分支处理正确无误。
- **架构规范一致性**：确认代码执行流程遵循 Pipeline -> Task -> Step 的层级结构，并且在配置解析、网络连接及依赖流转（BOM处理）等方面满足架构要求。
- **健壮性与异常处理**：在无权限、配置错误、网络异常、资源缺失等极端情况下，工具能够输出合理的错误信息，并正确执行清理与回退操作。

### 1.2 测试范围
- **CLI命令**：`kubexm` 支持的所有主命令与子命令及其组合参数。
- **工作流（Pipeline）**：创建集群、离线资源下载、容器镜像处理及扩缩容等全生命周期流程。
- **底层模块验证**：配置解析与校验 (`internal/config/config.sh`)、执行引擎与SSH交互 (`internal/connector/`) 以及任务组装 (`internal/task/`, `internal/step/`)。

### 1.3 测试环境要求
- **操作系统**：Rocky Linux 9 (代表RPM系) 和 Ubuntu 22.04 (代表DEB系)
- **网络环境**：
  - 在线环境：具备完全外部网络访问权限，用于测试在线部署和资源下载。
  - 离线环境：断开外部网络，仅能访问本地镜像源及已下载的资源包。
- **集群规模**：
  - 单节点（单机测试）
  - 多节点（1 Master + 2 Worker 架构）

---

## 二、测试计划

### 2.1 第一阶段：环境与基础命令测试（1天）
- 目标：确保工具的安装、环境初始化和基础命令（如 `version`, `help`）正常。
- 资源：单台在线测试机。

### 2.2 第二阶段：离线资源管理与BOM测试（2天）
- 目标：验证 `download`, `create iso`, `push images`, `create manifests` 流程。
- 内容：
  - 测试多种 OS 的 ISO 构建。
  - 测试下载各类依赖包与镜像，验证 BOM 清单生成的准确性。
  - 在单机环境构建并推送双架构镜像。

### 2.3 第三阶段：核心生命周期管理测试（3天）
- 目标：验证在线和离线模式下集群的生命周期（Create, Scale, Delete）。
- 内容：
  - 单节点与多节点集群在线创建。
  - 模拟离线环境部署本地 Registry 及推送镜像并进行离线创建。
  - 集群节点扩缩容 (`scale-out`, `scale-in`)。
  - 强制与优雅删除集群，并包含删除前备份机制的验证。

### 2.4 第四阶段：维护与升级操作测试（2天）
- 目标：验证版本更新、证书续期及灾备策略。
- 内容：
  - Kubernetes 组件与 etcd 版本升级。
  - CA 与叶子证书手动与自动续期 (`renew`)。
  - 集群数据的备份 (`backup`) 与恢复 (`restore`)。
  - 组件配置动态重载 (`reconfigure`) 与健康状态检查 (`health`)。

### 2.5 第五阶段：架构规范与异常场景测试（2天）
- 目标：确保底层逻辑健壮，并严格符合规范。
- 内容：
  - 验证配置文件 Schema 错误时的拦截及提示。
  - 模拟 SSH 断开、目标主机磁盘空间不足等异常执行环境。
  - 确保内部流程按 Pipeline -> Task -> Step 进行流转与日志记录。

---

## 三、测试用例详细设计

### 3.1 基础与辅助命令

#### TC-BASE-01: 查看版本信息
- **执行命令**：`kubexm version` 或 `kubexm -v`
- **预期结果**：输出当前版本信息，如 `kubexm version 0.1.0`。

#### TC-BASE-02: 查看帮助文档
- **执行命令**：`kubexm help` 或直接执行 `kubexm`
- **预期结果**：输出完整帮助信息，包含所有核心命令与用法示例。

#### TC-BASE-03: 生成依赖清单 (manifests)
- **执行命令**：`kubexm create manifests --kubernetes-version=v1.34.2 --kubernetes-type=kubexm`
- **预期结果**：能够正确解析版本和类型，并在控制台输出镜像、二进制及Helm等依赖清单。

### 3.2 离线资源下载与打包 (Download / ISO)

#### TC-DL-01: 下载集群资源 (默认配置)
- **执行命令**：`kubexm download --cluster=mycluster`
- **前置条件**：存在 `conf/clusters/mycluster/config.yaml`。
- **预期结果**：根据配置，自动下载所需依赖到 `.kubexm/downloads/` 或集群缓存目录，并生成完整的 OS, Binary, Image 和 Helm BOM。

#### TC-DL-02: 指定版本与运行时的资源下载
- **执行命令**：`kubexm download --cluster=mycluster --kubernetes-version=v1.27.2 --container-runtime=docker`
- **预期结果**：能够覆盖配置文件中定义的版本与运行时，下载指定版本的包，生成对应的 BOM。

#### TC-DL-03: 创建离线 ISO (多架构与多系统)
- **执行命令**：`kubexm create iso --with-build-os=rocky9 --with-build-arch=amd64`
- **预期结果**：启动相应的 Docker 构建流程，最终在输出目录生成包含离线源及安装脚本的 ISO 文件。

### 3.3 镜像推送与注册表管理 (Registry / Push Images)

#### TC-REG-01: 离线环境创建本地 Registry
- **执行命令**：`kubexm create registry --cluster=mycluster`
- **前置条件**：`config.yaml` 中启用 Registry 且 `host.yaml` 指定 registry 角色节点。
- **预期结果**：Registry 服务成功启动，通过 Pipeline 流程在指定节点完成部署及配置。

#### TC-REG-02: 离线环境推送镜像
- **执行命令**：`kubexm push images --cluster=mycluster --packages --parallel=8`
- **预期结果**：系统使用并发推送将 `packages/images/` 下的镜像列表推送到配置的 Registry，并支持双镜像逻辑（如果开启 `--dual`）。

#### TC-REG-03: 删除 Registry
- **执行命令**：`kubexm delete registry --cluster=mycluster --force`
- **预期结果**：无需人工确认，直接停止 Registry 服务并清理对应的镜像和配置。

### 3.4 集群生命周期管理 (Create / Delete)

#### TC-LC-01: 在线创建单节点集群
- **执行命令**：`kubexm create cluster --cluster=mycluster`
- **测试环境**：连接外网的单节点环境。
- **预期结果**：自动执行预检查、环境初始化、下载依赖及节点部署流程，最终 `kubectl get nodes` 显示节点处于 Ready 状态。

#### TC-LC-02: 离线多节点集群创建
- **执行命令**：拷贝离线 packages 后执行 `kubexm create cluster --cluster=mycluster`
- **前置条件**：无外网访问。
- **预期结果**：集群使用离线镜像和二进制包完成 1 Master + 2 Worker 节点部署，CNI 插件正常工作。

#### TC-LC-03: 删除集群及备份测试
- **执行命令**：`kubexm delete cluster --cluster=mycluster --backup=/tmp/etcd-backup`
- **预期结果**：删除集群前，在 `/tmp/etcd-backup` 中成功创建了 etcd 的快照文件，集群随后被安全移除。

### 3.5 扩缩容测试 (Scale)

#### TC-SCALE-01: 扩容工作节点 (Scale-out)
- **执行命令**：`kubexm scale cluster --cluster=mycluster --action=scale-out --role=worker --nodes=worker-3`
- **预期结果**：系统仅对新增节点 worker-3 执行初始化和加入集群的 Pipeline 流程，最终集群新增节点生效。

#### TC-SCALE-02: 缩容工作节点 (Scale-in)
- **执行命令**：`kubexm scale cluster --cluster=mycluster --action=scale-in --nodes=worker-2`
- **预期结果**：先对 worker-2 执行 drain 操作（驱逐Pod），随后移除该节点并清理配置。

### 3.6 升级与维护 (Upgrade / Renew / Health / Reconfigure)

#### TC-MAINT-01: 升级 Kubernetes
- **执行命令**：`kubexm upgrade cluster --cluster=mycluster --to-version=v1.33.0`
- **预期结果**：严格按照预检查 -> 控制面升级 -> Worker升级 -> Addons升级 的流程执行，中途无中断，升级后集群版本变更为 v1.33.0。

#### TC-MAINT-02: 升级 etcd
- **执行命令**：`kubexm upgrade etcd --cluster=mycluster --to-version=3.5.15`
- **预期结果**：实现 etcd 节点的滚动重启与镜像替换，数据未丢失，健康状态正常。

#### TC-MAINT-03: 续期集群证书
- **执行命令**：`kubexm renew kubernetes-certs --cluster=mycluster`
- **预期结果**：叶子证书失效期被重置，各组件读取新证书后自动生效或重启对应服务。

#### TC-MAINT-04: 检查集群健康状态
- **执行命令**：`kubexm health cluster --cluster=mycluster --check=all`
- **预期结果**：正确调用所有维度的健康检查任务，包括节点可用性、系统组件状态及网络插件的负载情况。

#### TC-MAINT-05: 重载运行时配置
- **执行命令**：`kubexm reconfigure cluster --cluster=mycluster --target=runtime`
- **预期结果**：修改 `config.yaml` 运行时参数后执行该命令，目标节点的 containerd 或 docker 配置更新并平滑重启。

### 3.7 架构与规范测试

#### TC-ARCH-01: YAML Schema 严格校验
- **测试场景**：手动在 `config.yaml` 中填入错误的组件版本号格式或不支持的参数。
- **预期结果**：Config 解析模块在 Pipeline 起点抛出明确的 Schema Error，并阻断后续执行，不造成破坏性动作。

#### TC-ARCH-02: 任务与步骤编排验证
- **测试场景**：查看执行日志，模拟某个中间 Step 执行失败（如 SSH 返回异常）。
- **预期结果**：日志明确标示失败的 Task 和 Step，流程安全中止且调用错误处理机制返回。

#### TC-ARCH-03: 执行引擎（Runner与SSH连接器）容错
- **测试场景**：集群某个节点临时网络不通。
- **预期结果**：SSH 连接器根据设定的重试策略重试，重试耗尽后优雅地抛出超时异常，退出且不导致脚本卡死。
