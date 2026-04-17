# kubexm-script 架构重构：原子化执行流设计

目标：在现有 Bash 体系内，将所有命令链迁移到 Pipeline/Module/Task/Step 结构，保持配置中心不变并强制 SSH-only，确保在线/离线流程和离线工具/组件可用。

## 一、约束与行为
- 配置入口仅限 `conf/{cluster}/config.yaml + host.yaml`。
- SSH-only：禁止 localhost/127.0.0.1；如未显式指定主机列表，解析本机主 IP 后依然通过 SSH 访问。
- 在线模式：`create cluster` 自动触发 `download`。
- 离线模式：`download` 不校验 host.yaml；用户复制 packages 目录到离线环境后执行 `create cluster`。
- 所有运行工具（jq/yq/xmjq/xmyq 等）及部署组件必须可离线。

## 二、类型矩阵（作为依赖检查的权威来源）
- Kubernetes 类型：kubeadm | kubexm（二进制）。
- etcd 类型：kubeadm | kubexm（二进制） | exists（外部 etcd，跳过安装）。
- LoadBalancer：enabled/disabled。
  - enabled + mode=external：部署在 loadbalancer 角色机器。
    - type=kubexm-kh：keepalived + haproxy（外部）。
    - type=kubexm-kn：keepalived + nginx（外部）。
  - enabled + mode=internal：部署在所有 worker。
    - type=haproxy + k8s=kubeadm：静态 Pod 部署 haproxy。
    - type=haproxy + k8s=kubexm：二进制部署 haproxy。
    - type=nginx + k8s=kubeadm：静态 Pod 部署 nginx。
    - type=nginx + k8s=kubexm：二进制部署 nginx。
  - mode=kube-vip：使用 kube-vip 作为负载均衡。
  - mode=exists：已有负载均衡，跳过部署。

## 三、分层结构与职责
- CLI（bin/kubexm）：参数解析与路由，调用 Pipeline。
- Pipeline：流程编排（跨主机），只调用 Module。
- Module：业务域组合，只调用 Task。
- Task：步骤编排，只调用 Step。
- Step：原子操作，提供 targets/check/run/rollback，不直接调用 Connector。
- Runner：统一执行策略（check→run→check），处理中断/日志。
- Connector：SSH/传输封装（禁止 localhost/127）。

## 四、核心执行流
Entrypoint → Pipeline → Module → Task → Step → Runner → Connector

## 五、支撑体系（基础设施）
- Logger：分级日志 + JSON 输出 + 任务关联。
- Context：全局状态与取消信号传递。
- Parser：解析 config.yaml / host.yaml / SSH 凭据 / 目标主机。
- Conf：多源配置（YAML/Env/CLI）。
- Utils：通用工具函数。
- Errors：可恢复/致命错误区分。
- Containers：离线 OS 依赖的 Dockerfile 资产。
- Templates：模板中心。
- Cache：缓存中心。

## 六、重构目标
- 消除冗余，形成“一套 Step 库，多场景组装任务”。
- 强化原子性与幂等性（Step 内状态检查）。
- 组合优于继承：Pipeline 组装 Module，Module 组装 Task，Task 组装 Step。
- Step 严禁直接调用 Connector。

## 七、离线/在线与依赖校验
- download：不校验 host.yaml，仅生成 packages 目录。
- create cluster：在线模式先 download，离线模式直接使用已准备 packages。
- 依赖检查：根据配置动态判定所需二进制/镜像/系统包/Helm 资源是否齐全。
