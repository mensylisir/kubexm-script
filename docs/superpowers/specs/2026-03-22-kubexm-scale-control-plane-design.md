# Kubexm Scale Control-plane Enhancement Design

> **Date**: 2026-03-22
> **Status**: Draft

## 1. 背景

当前 `kubexm scale cluster` 命令只支持 worker 节点的 scale-out 和 scale-in。Control-plane 节点（master）的扩缩容尚未实现。

现有的 `kubeadm.join_master_*` steps 已存在于 `cluster_create.sh` 中，用于初始化后添加额外的 control-plane 节点，但 scale flow 未调用这些步骤。

## 2. 目标

扩展 `task::scale_cluster` 支持 **Control-plane 节点** 的 scale-out 和 scale-in：

- **Scale-out CP**: 新增 master 节点加入现有集群
- **Scale-in CP**: 从集群移除 master 节点并清理

## 3. Action 参数

扩展 `--action` 选项：

| Action | 行为 |
|--------|------|
| `scale-out` (默认) | 现有行为：添加 worker 节点 |
| `scale-in` | 现有行为：移除 worker 节点 |
| `scale-out-cp` | 新增：添加 control-plane 节点 |
| `scale-in-cp` | 新增：移除 control-plane 节点 |

## 4. 新增步骤

### 4.1 Scale-out CP Steps

| Step | 职责 | 复用 |
|------|------|------|
| `cluster.scale_cp_join_collect_action` | 解析 --action，识别 scale-out-cp | 类比 `cluster.scale_join_workers_collect_action` |
| `cluster.scale_cp_join_collect_node` | 收集待加入的 master 节点列表 | 类比 `cluster.scale_join_workers_collect_node` |
| `cluster.scale_cp_join_collect_command` | 生成 kubeadm join 命令 | 类比 `cluster.scale_join_workers_collect_command` |
| `cluster.scale_cp_join_exec` | 执行 kubeadm join master | 复用 `kubeadm.join_master_run` |

### 4.2 Scale-in CP Steps

| Step | 职责 | 复用 |
|------|------|------|
| `cluster.scale_cp_drain_nodes` | drain master 节点 | 扩展 `cluster.scale_drain_nodes` |
| `cluster.scale_cp_remove_nodes` | 从集群移除 master | 扩展 `cluster.scale_remove_nodes` |
| `cluster.scale_cp_stop_kubelet` | 停止 kubelet | 复用 `cluster.scale_stop_kubelet` |
| `cluster.scale_cp_kubeadm_reset` | kubeadm reset | 复用 `cluster.scale_kubeadm_reset` |
| `cluster.scale_cp_cleanup_dirs` | 清理目录 | 复用 `cluster.scale_cleanup_dirs` |

## 5. targets() 设计

### 5.1 Scale-out CP

```bash
# cluster.scale_cp_join_collect_node::targets()
# 返回：非首个 master 的所有 master IPs（不在当前集群中的）
local masters current_nodes nodes_to_join=""
masters=$(config::get_role_members 'control-plane')
current_nodes=$(kubectl get nodes -o name 2>/dev/null | sed 's/node\\///g' || echo "")
first=$(echo "${masters}" | awk '{print $1}')

for node in ${masters}; do
  [[ -z "${node}" || "${node}" == "${first}" ]] && continue
  if [[ ! "${current_nodes}" =~ ${node} ]]; then
    nodes_to_join="${nodes_to_join} ${node}"
  fi
done
```

### 5.2 Scale-in CP

```bash
# cluster.scale_cp_drain_nodes::targets()
# 返回：所有 master 节点 IPs（用户指定要移除的）
local masters=""
masters=$(config::get_role_members 'control-plane')
```

## 6. Task 注册

在 `task::scale_cluster` 中新增：

```bash
# Scale-out CP
"cluster.scale_cp_join_collect_action:${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_join_collect_action.sh" \
"cluster.scale_cp_join_collect_node:${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_join_collect_node.sh" \
"cluster.scale_cp_join_collect_command:${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_join_collect_command.sh" \
"cluster.scale_cp_join_exec:${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_join_exec.sh" \

# Scale-in CP
"cluster.scale_cp_drain_nodes:${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_drain_nodes.sh" \
"cluster.scale_cp_remove_nodes:${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_remove_nodes.sh" \
"cluster.scale_cp_stop_kubelet:${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_stop_kubelet.sh" \
"cluster.scale_cp_kubeadm_reset:${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_kubeadm_reset.sh" \
"cluster.scale_cp_cleanup_dirs:${KUBEXM_ROOT}/internal/step/steps/cluster_scale_cp_cleanup_dirs.sh" \
```

## 7. 执行顺序

### Scale-out CP Flow

```
cluster.scale_cp_join_collect_action   # 识别 action
  → cluster.scale_cp_join_collect_node   # 收集节点
    → cluster.scale_cp_join_collect_command # 生成命令
      → cluster.scale_cp_join_exec        # 执行 join
```

### Scale-in CP Flow

```
cluster.scale_cp_drain_nodes           # drain
  → cluster.scale_cp_remove_nodes       # remove from cluster
    → cluster.scale_cp_stop_kubelet     # stop kubelet
      → cluster.scale_cp_kubeadm_reset  # reset
        → cluster.scale_cp_cleanup_dirs # cleanup
```

## 8. Idempotency

- `check()` 返回 0 = 已满足（跳过），返回 1 = 需要执行
- Scale-out CP: 检查 master 节点是否已在集群中
- Scale-in CP: 检查 master 节点是否已不在集群中

## 9. 文件清单

### 新增文件

- `internal/step/steps/cluster_scale_cp_join_collect_action.sh`
- `internal/step/steps/cluster_scale_cp_join_collect_node.sh`
- `internal/step/steps/cluster_scale_cp_join_collect_command.sh`
- `internal/step/steps/cluster_scale_cp_join_exec.sh`
- `internal/step/steps/cluster_scale_cp_drain_nodes.sh`
- `internal/step/steps/cluster_scale_cp_remove_nodes.sh`
- `internal/step/steps/cluster_scale_cp_stop_kubelet.sh`
- `internal/step/steps/cluster_scale_cp_kubeadm_reset.sh`
- `internal/step/steps/cluster_scale_cp_cleanup_dirs.sh`

### 修改文件

- `internal/task/scale_cluster.sh` - 注册新步骤

## 10. 风险与约束

- **Etcd 节点约束**: 如果 etcd 类型为 `kubeadm` 且 etcd 与 control-plane 共节点，移除 master 节点可能影响 etcd 仲裁。需要在 `cluster.scale_cp_remove_nodes::check()` 中增加 etcd 安全检查。
- **LB 更新**: Scale-in CP 时需要更新 loadbalancer 配置（移除该 master IP）。
- **首个 master 不可移除**: 始终跳过首个 master 节点。
