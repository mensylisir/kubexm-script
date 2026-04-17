# Kubexm 问题分析报告

日期：2026-03-22

## 1. 架构问题

### 1.1 Step 幂等性实现不完整

**问题描述**：大部分 Step 的 `check()` 函数直接返回 1（表示未满足，需要执行），没有实现真正的幂等性检查。

**影响**：每次运行都会执行操作，即使操作已经完成。

**示例** - `internal/step/steps/cluster_install_runtime_containerd_copy_binaries.sh`:
```bash
step::cluster.install_runtime_containerd_copy_binaries::check() { return 1; }
```

**建议**：实现真正的幂等性检查：
```bash
step::cluster.install_runtime_containerd_copy_binaries::check() {
    # 检查是否已安装
    if ssh::execute "${KUBEXM_HOST}" "command -v containerd >/dev/null 2>&1"; then
        return 0  # 已满足，跳过
    fi
    return 1  # 未满足，需要执行
}
```

### 1.2 策略验证缺少 kubexm-kubeadm 组合

**问题描述**：`domain::is_valid_strategy` 只允许以下组合：
- `kubeadm-kubeadm`
- `kubeadm-kubexm`
- `kubeadm-exists`
- `kubexm-kubexm`
- `kubexm-exists`

缺少 `kubexm-kubeadm` 组合（kubexm部署K8s + kubeadm管理etcd）。

**文件位置**：`internal/config/domain/rules/strategy_rules.sh:31-38`

**建议**：根据用户需求，应该支持所有 5x3 = 15 种组合。

## 2. 配置问题

### 2.1 命名不一致

**问题描述**：
- 用户记忆中使用 `kubexm_kh`（下划线）
- 代码中使用 `kubexm-kh`（中划线）

**文件位置**：
- `internal/config/domain/enums.sh:16` → `DOMAIN_LB_TYPES_EXTERNAL=("kubexm-kh" "kubexm-kn")`
- `internal/config/domain/normalize.sh:74-80` → 转换 `kubexm_kh` → `kubexm-kh`

**结论**：代码中有归一化处理，但需要确认配置文件中应使用哪种格式。

### 2.2 验证规则与实际实现可能冲突

**问题描述**：`strategy_rules.sh:87-88` 限制单节点集群不能启用负载均衡：
```bash
if [[ "${masters_count}" -eq 1 && "${lb_enabled}" == "true" ]]; then
    return 1  # 单节点启用LB会被拒绝
fi
```

但根据用户需求，`loadbalancer.mode=internal` 时 worker 节点连接本地 LB，这在单节点场景下可能是合理需求。

## 3. 离线化问题

### 3.1 工具依赖未完全离线化

**问题描述**：
- `download` 流程依赖 jq/yq/xmyq/xmjq 等工具
- Step 执行依赖 bash 内置工具和 SSH
- 没有明确的离线工具包清单

**建议**：
1. 创建 `${KUBEXM_ROOT}/bin/offline-tools/` 目录
2. 预编译所有需要的工具（jq, yq, xmyq, xmjq 等）
3. 在 `download` 流程中先检查工具可用性

### 3.2 xmyq/xmjq 工具不存在风险

**问题描述**：`internal/config/loader.sh` 使用 `xmyq` 解析 YAML：
```bash
xmyq_bin="${KUBEXM_ROOT:-${KUBEXM_SCRIPT_ROOT}}/bin/xmyq"
if [[ -x "${xmyq_bin}" ]]; then
    # 使用 xmyq
else
    # 回退到 grep/sed
fi
```

**风险**：回退解析能力有限，可能导致配置解析失败。

## 4. 安全性问题

### 4.1 SSH 密码认证未完全实现

**问题描述**：`internal/connector/ssh.sh` 虽然支持 ssh_password 参数，但在 `connector::_get_ssh_key` 中未处理密码获取逻辑。

**文件位置**：`internal/connector/connector.sh:38-46`

### 4.2 host.yaml 校验问题

**问题描述**：`config::loader::parse_hosts` 检查 localhost/127.0.0.1：
```bash
if [[ "${address}" == "localhost" || "${address}" == "127.0.0.1" ]]; then
    echo "Error: host ${host_name} uses forbidden address ${address}" >&2
    return 1
fi
```

但 `internal/config/config.sh` 中的默认值可能为空。

## 5. 执行流问题

### 5.1 create cluster 缺少完整错误处理

**问题描述**：`pipeline::create_cluster` 在 mode=offline 且 registry_enabled=true 时，连续调用 `pipeline::create_registry` 和 `pipeline::push_images`，但没有检查前面失败时是否继续执行。

**建议**：添加错误处理和回滚逻辑。

### 5.2 缺少 etcd_type=kubeadm 时的 kubexm 二进制 etcd 支持

**问题描述**：`task::cluster_create` 中 etcd 安装逻辑：
```bash
if [[ "${k8s_type}" == "kubeadm" ]]; then
    if [[ "${etcd_type}" == "kubeadm" ]]; then
        # kubeadm init master
    else
        if [[ "${etcd_type}" == "kubexm" ]]; then
            # 安装 kubexm etcd
        fi
        # kubeadm init external etcd
    fi
else
    if [[ "${etcd_type}" == "kubexm" ]]; then
        # 安装 kubexm etcd
    fi
    # kubexm 二进制部署
fi
```

缺少 `kubexm-kubeadm` 组合的支持。

## 6. 配置验证问题

### 6.1 缺少完整性验证

**问题描述**：`config::validate` 检查了 k8s_type, etcd_type, control-plane 组，但没有检查：
- worker 组是否存在
- 必要的角色组是否完整

### 6.2 缺少依赖验证

**问题描述**：没有验证以下依赖关系：
- `loadbalancer.mode=external` 需要 `loadbalancer` 角色组存在
- `registry.enable=true` 需要 `registry` 角色组存在
- `etcd.type=kubexm` 需要 `etcd` 角色组存在

## 7. Scale/Upgrade/Delete 流程分析

### 7.1 Scale Cluster
```
task::scale_cluster
├── check.tools_binary
├── check.tools_packages
├── cluster.scale_join_workers_* (扩缩容)
├── cluster.scale_wait_ready
├── cluster.scale_drain_nodes
├── cluster.scale_remove_nodes
├── cluster.scale_stop_kubelet
├── cluster.scale_kubeadm_reset
├── cluster.scale_cleanup_dirs
├── cluster.scale_flush_iptables
└── cluster.scale_update_lb_* (更新LB配置)
```

**问题**：Scale 流程只处理 worker 节点的扩缩容，不处理 master 节点。

### 7.2 Upgrade Etcd
```
task::upgrade_etcd
├── check.tools_binary
├── check.tools_packages
├── etcd.upgrade_validate
├── etcd.upgrade_backup
├── etcd.upgrade_collect
├── etcd.upgrade_stop
├── etcd.upgrade_copy_binaries
├── etcd.upgrade_start
└── etcd.upgrade_healthcheck
```

**注意**：Upgrade etcd 只处理 kubexm etcd（binary），不支持 kubeadm etcd。

### 7.3 Delete Cluster
```
task::delete_cluster
├── check.tools_binary
├── check.tools_packages
├── cluster.delete_validate
├── cluster.delete_namespace
├── cluster.wait_workloads_deleted
├── cluster.delete_addon_* (删除 addon)
├── cluster.delete_cni_* (删除 CNI)
├── cluster.delete_node_drain
├── cluster.delete_node
├── cluster.reset_kubeadm_cmd
├── cluster.reset_iptables
├── cluster.reset_ipvs
├── cluster.stop_kubelet
├── cluster.disable_kubelet
├── cluster.cleanup_k8s_dirs
├── cluster.cleanup_kubeconfig_*
└── cluster.cleanup_pki_* (清理证书目录)
```

**问题**：Delete 流程不区分 kubernetes_type（kubeadm vs kubexm）。

## 8. 证书管理分析

### 8.1 Certs Renewal
```
task::renew_kubernetes_certs
├── check.tools_binary
├── check.tools_packages
└── certs.renew_kubernetes_certs
    └── certs::renew "kubernetes"
        └── rotation::rotate_all

task::renew_etcd_certs
└── certs.renew_etcd_certs
    └── certs::renew "etcd"
        └── rotation::rotate_all
```

**问题**：
1. 只支持 `rotation::rotate_all`，不支持分阶段续期
2. 不支持 `kubeadm` 类型集群的证书续期

## 9. 建议修复优先级

### P0 (必须修复)
1. 补充 `kubexm-kubeadm` 策略组合（如果用户确实需要）
2. 实现 Step 真正的幂等性检查

### P1 (重要)
3. 完善工具离线化（jq/yq/xmyq/xmjq）
4. 补充配置依赖验证（角色组完整性）
5. 修复单节点 LB 验证规则
6. Scale 流程支持 master 节点扩缩容
7. Delete 流程区分 kubernetes_type

### P2 (改进)
8. 增强错误处理和回滚
9. 优化日志输出结构化
10. 添加执行进度追踪
11. 证书续期支持分阶段执行
